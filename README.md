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

Only `POST /v1/chat/completions` is OpenAI-compatible today. Applications
should continue to obtain model metadata from
`https://nexus-api.dappnode.com/v1/models`. `GET /healthz` reports whether the
local proxy is ready.

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

## Current staging pin

This initial package is for the existing EHBP staging stack. It pins:

- SDK base commit `f98b551edb76390d7c7c5617754e9868f4306d10` plus the local DAppNode listener patch in `patches/`.
- Gateway source revision `b9afcee715ee35700b6ff1fc94445c75c191a1d1`.
- The PCR values in `nexus-gateway-policy.json`.
- Gateway origin `https://nexus-api-tee.dappnode.com`.

The listener patch is temporary. Once the corresponding SDK change is in the
SDK repository, update `UPSTREAM_VERSION` and remove the patch application
from the Dockerfile. Before a production release, replace the staging policy
with measurements independently obtained from the merged Gateway release.

## Build

```sh
NEXUS_GITHUB_TOKEN="$(gh auth token)" docker build \
  --secret id=github_token,env=NEXUS_GITHUB_TOKEN \
  --build-arg UPSTREAM_VERSION=f98b551edb76390d7c7c5617754e9868f4306d10 \
  -t nexus-local-proxy:dev .
```

The image builds the SDK from a full Git commit, applies the reviewed local
patch, and runs as an unprivileged user in a minimal runtime image. The
BuildKit secret is temporarily required because the SDK repository is private;
it is not stored in an image layer. Remove this requirement once a public SDK
source release or proxy image exists.
