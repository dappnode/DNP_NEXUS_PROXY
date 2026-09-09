# Nexus Proxy

Encrypts your Nexus prompts so only the **TEE** — the trusted execution
environment Nexus runs inside — can read them. Not us, not Dappnode, nobody in
between. It verifies the TEE automatically on every connection.

## Use it

```text
Base URL: http://nexus-proxy.dappnode.private:3301/v1
API key:  your normal Nexus API key
```

Same key, same models, same prices. Some Dappnode apps have a **private mode**
switch that does this for you — Hermes Agent is one.

For the whole path, pick a model whose id starts with **`private/`**. Those run
inside a TEE too, so your prompt stays encrypted from this proxy to Nexus and
from Nexus to the model.

## Check it yourself

```text
http://nexus-proxy.dappnode.private:3301/verification
```

What was checked, right now, plus the raw proof to verify with independent
tooling. It never shows your prompts.

## Good to know

- Auto Router (`nexus/auto`) and PII masking do not work through the proxy.
  Pick a specific model.
- If the TEE cannot be verified, requests stop. That is deliberate.
- Keep port 3301 on the internal network.

---

# Reference

## Scope

Encrypted: prompt and reply bodies, from this proxy to the verified Gateway
inside the TEE.

With a **`private/`** model, that continues past Nexus: the Gateway reaches
those models over an attested, encrypted transport that fails closed, so the
prompt is protected end to end.

Outside that: the hop from your app to this proxy (ordinary HTTP on the
Dappnode internal network) and request metadata — method, path, headers, sizes,
timing and your bearer key.

## Endpoints

| Route | Encrypted | Notes |
|---|---|---|
| `POST /v1/chat/completions` | yes | Streaming supported |
| `GET /v1/models` | no | Public catalog |
| `GET /healthz` | n/a | Readiness |
| `GET /verification` | n/a | The page above |

The catalog is public, unauthenticated data with no prompt or credential in it,
so it goes over ordinary TLS and the `Authorization` header is not forwarded.
Those requests are not counted on the verification page. `--model-catalog=false`
removes the route.

## Verification history

No prompt or reply content, ever — only verification evidence and per-request
identifiers, timing and sizes. The on-disk format cannot express a prompt.

Stored on the `verification_state` volume at
`/var/lib/nexus-proxy/verification.json`, so it survives restarts and is in
package backups. Anything on the Dappnode internal network can read it.
`--verification-ui=false` removes the page and its API; dropping `--state-file`
keeps history in memory only.

## Trust policy

Measurements are derived from the most recent Gateway releases, each signed
during the Gateway release workflow with a Sigstore certificate issued to that
workflow's GitHub identity. Only that exact identity is accepted, so the
download is not trusted — GitHub is a CDN here, and a swapped release is
rejected.

A new Gateway is picked up **on first contact**, not on a timer: a release the
policy has never seen is what a new deployment looks like, so the proxy
re-derives and verifies within the same request. Nothing needs pushing to the
node, which matters behind NAT. An hourly refresh is a backstop.

Fail-closed: if neither the network nor the cache produces a verified policy,
the proxy refuses to start. `--trust-policy-cache` keeps the signed material on
the `verification_state` volume and every signature is re-verified on load.

Pinned here: the SDK commit (`UPSTREAM_VERSION`), the Gateway origin
`https://nexus-api-tee.dappnode.com`, and the release-workflow signing identity
(compiled into the SDK).

Needs outbound HTTPS to `api.github.com` and `objects.githubusercontent.com` at
startup, on meeting an unknown release, and hourly. Without them it starts only
if the cache already holds a verified policy.

## Dependency

```json
{ "dependencies": { "nexus-proxy.dnp.dappnode.eth": "^0.1.0" } }
```

## Build

```sh
docker compose build
```

Builds the SDK from a pinned commit, verifies the checked-out revision, and
runs unprivileged in a minimal image. `dappnode-nexus-sdk` is public, so no
credentials are needed.
