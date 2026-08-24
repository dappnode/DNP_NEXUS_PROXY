# Nexus Local Proxy for DAppNode

This DAppNode package runs one shared Nexus proxy for OpenAI-compatible
applications installed on the same DAppNode. The proxy verifies fresh AWS
Nitro attestation against an independently pinned policy and encrypts chat
request and response bodies with EHBP before they cross Cloudflare.

## Client configuration

Configure DAppNode applications with:

```text
Base URL: http://nexus-local-proxy.dappnode.private:3301/v1
API key:  the application's normal Nexus API key
API:      OpenAI Chat Completions
```

The API key remains in the normal `Authorization: Bearer ...` header. The
proxy does not store it and does not automatically retry inference requests.

Applications may declare the package dependency once and then receive proxy
and trust-policy updates independently:

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
only verification evidence and per request identifiers, timing and sizes, and
holds them in memory: nothing is written to disk and history starts empty after
a restart. Because it is served on the proxy port, anything on the DAppNode
internal network can read this metadata. Add `--verification-ui=false` to the
service command to remove the page and its API.

## Security boundary

Callers trust the DAppNode host, this package, and the DAppNode internal
network. The caller-to-proxy hop is ordinary HTTP and is outside EHBP. From
this local proxy to the measured Nexus Gateway process inside AWS Nitro
Enclaves, prompt and completion bodies are encrypted and integrity-protected.

EHBP does not hide the HTTP method, path, headers, body length, frame sizes,
timing, or bearer API key. This package does not extend the claim to a
downstream inference provider. Do not publish container port 3301 to the host
or Internet.

## Current pin

This package pins:

- SDK commit `7ecb47b27122d41f010d33811236328e7ce3af17` (`main`).
- Gateway release `v0.1.57`, source revision `bda15a3549b7a9fbb37004281852079e9013f73b`.
- The PCR values in `nexus-gateway-policy.json`.
- Gateway origin `https://nexus-api-tee.dappnode.com`.

The trust policy must always describe a Gateway release actually deployed at
that origin. It is fail-closed: if no pinned release matches the running
enclave, the proxy refuses to start. Take measurements from the signed release
record rather than from the live attestation endpoint.

`releases` accepts several entries, so a Gateway can be rolled out without
installed proxies failing closed in between. Publish a policy listing both the
outgoing and incoming release, let it reach nodes, deploy the Gateway, then
publish a policy listing only the new release.

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
