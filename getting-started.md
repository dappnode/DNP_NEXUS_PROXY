# Nexus Proxy

Encrypts your Nexus prompts so only the **TEE** — the trusted execution
environment Nexus runs inside — can read them. Not us, not Dappnode, nobody in
between.

It verifies the TEE automatically on every connection.

## Check it yourself

**[Open the verification page](http://nexus-proxy.dappnode.private:3301/verification)**
— what was checked, right now, plus the raw proof to verify independently. It
never shows your prompts.

## Use it

Point any OpenAI-compatible app on this Dappnode at:

```text
Base URL: http://nexus-proxy.dappnode.private:3301/v1
API key:  your normal Nexus API key
```

Same key, same models, same prices. Some apps have a **private mode** switch
that does this for you — Hermes Agent is one.

## Good to know

- Auto Router (`nexus/auto`) and PII masking do not work through the proxy.
  Pick a specific model.
- If the TEE cannot be verified, requests stop. That is deliberate.
- Keep port 3301 on the internal network.

[Full documentation](https://github.com/dappnode/DNP_NEXUS_PROXY#readme)
