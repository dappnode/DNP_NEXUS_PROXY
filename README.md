# Nexus Local Proxy for DAppNode

This DAppNode package runs one shared Nexus proxy for OpenAI-compatible
applications installed on the same DAppNode. The proxy verifies fresh AWS
Nitro attestation against measurements it takes from signed Gateway releases,
and encrypts chat request and response bodies with EHBP before they cross
Cloudflare.

## Client configuration

Configure DAppNode applications with:

```text
Base URL: http://nexus-local-proxy.dappnode.private:3301/v1
API key:  the application's normal Nexus API key
API:      OpenAI Chat Completions
```

The API key remains in the normal `Authorization: Bearer ...` header. The
proxy does not store it and does not automatically retry inference requests.

Applications may declare the package dependency once. They then follow Gateway
releases automatically, without either the application or this package being
republished:

```json
{
  "dependencies": {
    "nexus-local-proxy.dnp.dappnode.eth": "^0.1.0"
  }
}
```

`POST /v1/chat/completions` and `GET /v1/models` are OpenAI-compatible, so an
application that lists models against its configured base URL works without a
second endpoint. `GET /healthz` reports whether the local proxy is ready.

The model catalog is the one route here that is **not** confidential. It is
public, unauthenticated, cacheable data with no prompt, completion or
credential in it, so the proxy passes it through over ordinary TLS rather than
over EHBP, and does not forward the caller's `Authorization` header. These
requests are not counted on the verification page, because nothing about them
crossed the attested channel. Add `--model-catalog=false` to the service
command to remove the route.

## Privacy verification page

The package serves a page showing whether the Gateway is currently verified and
what was checked:

```text
http://nexus-local-proxy.dappnode.private:3301/verification
```

It reports the verdict in plain language, lists the checks the proxy performed
before it would encrypt anything, shows the enclave measurements and attested
key, and lists recent requests with the attested key each one was encrypted to.
From there the raw COSE_Sign1 attestation document and its signed manifest can
be downloaded and re-checked with an independent AWS Nitro verifier.

The page shows no prompt or completion content. The ledger behind it records
only verification evidence and per request identifiers, timing and sizes. That
history is written to the `verification_state` volume at
`/var/lib/nexus-proxy/verification.json`, so it survives a restart and is
included in package backups. The on-disk format cannot express a prompt or a
completion. Because the page is served on the proxy port, anything on the
DAppNode internal network can read this metadata. Add `--verification-ui=false`
to the service command to remove the page and its API, or drop `--state-file`
from the service command to keep history in memory only.

## Security boundary

Callers trust the DAppNode host, this package, and the DAppNode internal
network. The caller-to-proxy hop is ordinary HTTP and is outside EHBP. From
this local proxy to the measured Nexus Gateway process inside AWS Nitro
Enclaves, prompt and completion bodies are encrypted and integrity-protected.

EHBP does not hide the HTTP method, path, headers, body length, frame sizes,
timing, or bearer API key. This package does not extend the claim to a
downstream inference provider. Do not publish container port 3301 to the host
or Internet.

## Trust policy

This package no longer ships enclave measurements. The proxy derives them from
the most recent Gateway releases, each signed during the Gateway release
workflow with a Sigstore certificate issued to that workflow's GitHub identity.
Only a signature from that exact identity is accepted, so the download is not
trusted: GitHub is a CDN here, and a swapped or edited release is rejected
rather than believed.

This is why the package no longer has to be republished for every Gateway
release, and why an installed proxy can no longer be left stranded on
measurements that predate the deployed enclave.

What the proxy checks has not changed. The measurements are still compared
against the enclave's live attestation exactly as before, and the
body-encryption contract is compiled into the SDK: a signed release may say
which build to trust, never what protection that build owes the caller.

A newly deployed Gateway is picked up on first contact rather than on a timer.
A release the current policy has never heard of is precisely what a new
deployment looks like, so the proxy re-derives its policy and verifies again
within the same request. Nothing needs to be pushed to the node, which matters
because DAppNodes sit behind NAT. An hourly background refresh is a backstop on
top of that.

It stays fail-closed. If neither the network nor the cache produces a verified
policy, the proxy refuses to start rather than falling back to something older.

`--trust-policy-cache` keeps the signed material from the last successful fetch
on the `verification_state` volume, so a node that restarts without a network
rebuilds the same policy. Every signature is re-verified on load.

This package pins:

- SDK commit, as `UPSTREAM_VERSION` in `docker-compose.yml` and
  `dappnode_package.json`.
- Gateway origin `https://nexus-api-tee.dappnode.com`.
- The Gateway release-workflow signing identity, compiled into the SDK.

### Network requirement

The proxy needs outbound HTTPS to `api.github.com` and
`objects.githubusercontent.com` at startup, on meeting an unknown Gateway
release, and hourly. A node that cannot reach them starts only if its cache
already holds a verified policy.

## Build

```sh
NEXUS_SDK_TOKEN="$(gh auth token)" docker compose build
```

The image builds the SDK from a full Git commit, verifies the checked-out
revision matches, and runs as an unprivileged user in a minimal runtime image.

`NEXUS_SDK_TOKEN` must hold a token with read access to the private
`dappnode-nexus-sdk` repository. `docker-compose.yml` passes it to the build as
a BuildKit secret, so it never reaches an image layer. In CI it comes from the
`NEXUS_SDK_TOKEN` repository secret; the default `GITHUB_TOKEN` cannot be used
because it is scoped to this repository only.

Remove the secret, the `secrets:` blocks in `docker-compose.yml`, and this
section once the SDK repository is public: the Dockerfile already falls back to
an unauthenticated fetch when no secret is supplied.
