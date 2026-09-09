# Nexus Proxy

Your prompts normally get decrypted on the way to Nexus. This package stops
that: it encrypts them so only the **TEE** — the trusted execution environment
Nexus runs inside — can read them. Not us, not Dappnode, nobody in between.

It also checks that the TEE really is what it claims to be, automatically,
every time it connects. If that check fails it stops rather than sending your
prompts unprotected.

## Check it yourself

You don't have to take our word for it:

**[Open the verification page](http://nexus-proxy.dappnode.private:3301/verification)**

It shows whether the check passed right now, what was checked, and lets you
download the raw proof to verify independently. It never shows your prompts.

## Use it

Point any OpenAI-compatible app on this Dappnode at:

```text
Base URL: http://nexus-proxy.dappnode.private:3301/v1
API key:  your normal Nexus API key
```

Nothing else changes — same key, same models, same prices.

Some Dappnode apps have a **private mode** switch that does this for you.
Hermes Agent is one.

## Good to know

- **Auto Router (`nexus/auto`) does not work through the proxy yet.** Pick a
  specific model instead.
- **PII masking does not apply.** The masking service sits outside the TEE and
  the TEE is not allowed to reach it, so a key with PII masking on will not get
  masking here.
- **It fails closed.** If it cannot verify the TEE, requests stop working
  rather than quietly falling back to the unprotected path. That is deliberate.
- **Keep port 3301 internal.** Do not publish it to the internet.

## Learn more

The [README](https://github.com/dappnode/DNP_NEXUS_PROXY) covers exactly what
is and is not protected, how the trust policy follows signed Gateway releases,
and how to re-check the proof with independent tooling.
