# Nexus Local Proxy for DAppNode

Private, OpenAI-compatible access to Nexus for applications on your DAppNode.

This package runs a shared local instance of the DAppNode Nexus SDK for
applications installed on the same DAppNode. It verifies the Nexus Gateway
before accepting traffic and protects prompt and response bodies on their way
to and from Nexus.

## Connect an application

After installing **Nexus Local Proxy**, configure applications on the same
DAppNode with:

```text
Base URL: http://nexus-local-proxy.dappnode.private:3301/v1
API key:  your Nexus API key
API:      OpenAI Chat Completions
```

Create and manage API keys at
[nexus.dappnode.com](https://nexus.dappnode.com). Applications can use
`POST /v1/chat/completions` for regular or streaming responses and
`GET /v1/models` to list the available models.

An application can declare the package as a dependency:

```json
{
  "dependencies": {
    "nexus-local-proxy.dnp.dappnode.eth": "^0.2.0"
  }
}
```

## Check your privacy connection

Open the local verification page:

```text
http://nexus-local-proxy.dappnode.private:3301/verification
```

It shows whether the Nexus service passed verification and which protected
connection handled each recent request. Verification evidence and request
metadata can be kept across package restarts; prompts and responses are never
part of that history.

## What is protected

- Prompt and response bodies are encrypted between this package and the
  verified Nexus confidential service.
- The package refuses to accept traffic when it cannot verify that service.
- Prompt and response content is not written to verification history or logs.

The DAppNode host and internal network remain trusted. Request metadata,
including headers, sizes, and timing, is outside the body-encryption boundary.
The protection does not extend beyond Nexus to a downstream model provider.
Port `3301` must remain private to the DAppNode network.

## Development

The package builds the Nexus SDK from the exact public commit set in
`UPSTREAM_VERSION`:

```sh
docker compose build
```

## License

This package is licensed under the [MIT License](LICENSE). The bundled DAppNode
Nexus SDK is licensed under Apache-2.0; dependency notices are in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
