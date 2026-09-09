# Nexus Proxy

Your prompts normally get decrypted on the way to Nexus. This Dappnode package
stops that: it encrypts them so only the **TEE** — the trusted execution
environment Nexus runs inside — can read them. Not us, not Dappnode, nobody in
between.

It also checks that the TEE really is what it claims to be, automatically, on
every connection. If that check fails it stops rather than sending your prompts
unprotected.

## Use it

Point any OpenAI-compatible app on this Dappnode at:

```text
Base URL: http://nexus-proxy.dappnode.private:3301/v1
API key:  your normal Nexus API key
```

Same key, same models, same prices. Some Dappnode apps have a **private mode**
switch that does this for you — Hermes Agent is one.

## Check it yourself

```text
http://nexus-proxy.dappnode.private:3301/verification
```

The page shows whether the check passed right now, what was checked, and lets
you download the raw proof so you can verify it with independent tooling. It
never shows your prompts.

## Good to know

- **Auto Router (`nexus/auto`) does not work through the proxy yet.** Pick a
  specific model instead.
- **PII masking does not apply.** The masking service runs outside the TEE and
  the TEE is not allowed to reach it, so a key with masking enabled will not
  get masking here.
- **It fails closed.** If the TEE cannot be verified, requests stop rather than
  quietly falling back to the unprotected path.
- **Keep port 3301 internal.** Do not publish it to the host or the internet.

---

# Learn more

Everything below is detail. The four points above are the whole story for most
people.

## What is and is not protected

Protected: the contents of your prompts and the model's replies, from this
proxy to the verified Nexus Gateway inside the TEE.

Not protected:

- **The hop from your app to this proxy.** That is ordinary HTTP on the
  Dappnode internal network. You are trusting the Dappnode host, this package,
  and that network.
- **Metadata.** Request method, path, headers, body length, timing and your
  bearer API key are all still visible to the network in front of Nexus.
- **What the model provider does afterwards.** This package makes no claim
  about a downstream inference provider.

## Endpoints

| Route | Confidential | Notes |
|---|---|---|
| `POST /v1/chat/completions` | yes | Streaming supported |
| `GET /v1/models` | no | Public catalog, see below |
| `GET /healthz` | n/a | Readiness |
| `GET /verification` | n/a | The page above |

The model catalog is the one route that is deliberately **not** confidential.
It is public, unauthenticated, cacheable data with no prompt, completion or
credential in it, so the proxy passes it through over ordinary TLS and does not
forward your `Authorization` header. Those requests are not counted on the
verification page, because nothing about them crossed the protected channel.
Add `--model-catalog=false` to remove the route.

## What the verification page records

No prompt or completion content, ever. The ledger holds verification evidence
plus per-request identifiers, timing and sizes. The on-disk format cannot
express a prompt or a reply.

History is written to the `verification_state` volume at
`/var/lib/nexus-proxy/verification.json`, so it survives restarts and is
included in package backups. Because the page is served on the proxy port,
anything on the Dappnode internal network can read this metadata. Add
`--verification-ui=false` to remove the page and its API, or drop
`--state-file` to keep history in memory only.

## How the proxy knows what to trust

It does not ship a fixed list of measurements. It derives them from the most
recent Gateway releases, each signed during the Gateway release workflow with a
Sigstore certificate issued to that workflow's GitHub identity. Only a
signature from that exact identity is accepted, so the download itself is not
trusted: GitHub is a CDN here, and a swapped or edited release is rejected
rather than believed.

That is why this package no longer has to be republished for every Gateway
release, and why an installed proxy can no longer be stranded on measurements
that predate the deployed TEE.

What gets checked has not changed. Measurements are still compared against the
TEE's live attestation, and the body-encryption contract is compiled into the
SDK: a signed release may say which build to trust, never what protection that
build owes you.

A newly deployed Gateway is picked up **on first contact**, not on a timer. A
release the current policy has never heard of is exactly what a new deployment
looks like, so the proxy re-derives its policy and verifies again within the
same request. Nothing has to be pushed to the node, which matters because
Dappnodes sit behind NAT. An hourly background refresh is a backstop on top.

If neither the network nor the cache produces a verified policy, the proxy
refuses to start rather than falling back to something older.
`--trust-policy-cache` keeps the signed material from the last successful fetch
on the `verification_state` volume, and every signature is re-verified on load,
so a tampered cache is rejected rather than believed.

This package pins the SDK commit (`UPSTREAM_VERSION` in `docker-compose.yml`
and `dappnode_package.json`), the Gateway origin
`https://nexus-api-tee.dappnode.com`, and the Gateway release-workflow signing
identity, which is compiled into the SDK.

### Network requirement

Outbound HTTPS to `api.github.com` and `objects.githubusercontent.com` at
startup, on meeting an unknown Gateway release, and hourly. A node that cannot
reach them starts only if its cache already holds a verified policy.

## Declaring the dependency

Applications can declare the package once and then follow Gateway releases
automatically, without either the application or this package being
republished:

```json
{
  "dependencies": {
    "nexus-proxy.dnp.dappnode.eth": "^0.1.0"
  }
}
```

## Build

```sh
docker compose build
```

The image builds the SDK from a full Git commit, verifies the checked-out
revision matches, and runs as an unprivileged user in a minimal runtime image.
`dappnode-nexus-sdk` is public, so no credentials are needed.
