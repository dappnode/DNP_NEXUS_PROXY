# syntax=docker/dockerfile:1.7

ARG GO_IMAGE=golang:1.26.4-alpine@sha256:3ad57304ad93bbec8548a0437ad9e06a455660655d9af011d58b993f6f615648
ARG RUNTIME_IMAGE=gcr.io/distroless/static-debian12:nonroot@sha256:1b7b9f0f0e0a1d2155f531db587cc48ec26aaf97ab64364225f5bf18a054e66a

FROM ${GO_IMAGE} AS build

ARG UPSTREAM_VERSION
RUN test -n "${UPSTREAM_VERSION}" \
    && test "$(printf '%s' "${UPSTREAM_VERSION}" | wc -c)" -eq 40 \
    && printf '%s' "${UPSTREAM_VERSION}" | grep -Eq '^[0-9a-f]{40}$'

RUN apk add --no-cache ca-certificates git

WORKDIR /src
RUN git init \
    && git remote add origin https://github.com/dappnode/dappnode-nexus-sdk.git
RUN --mount=type=secret,id=github_token \
    if test -s /run/secrets/github_token; then \
      auth_header="$(printf 'x-access-token:%s' "$(cat /run/secrets/github_token)" | base64 | tr -d '\n')"; \
      git -c http.extraHeader="Authorization: Basic ${auth_header}" fetch --depth=1 origin "${UPSTREAM_VERSION}"; \
    else \
      git fetch --depth=1 origin "${UPSTREAM_VERSION}"; \
    fi \
    && git checkout --detach FETCH_HEAD \
    && test "$(git rev-parse HEAD)" = "${UPSTREAM_VERSION}"

RUN go mod download \
    && go mod verify \
    && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/nexus-proxy ./cmd/nexus-proxy

# Docker seeds a fresh named volume from the image path it is mounted over,
# ownership included. Creating the state directory here as nonroot is what lets
# the distroless runtime (which has no shell to chown with) write to it.
RUN mkdir -p /out/state && chown 65532:65532 /out/state

COPY cmd/healthcheck/main.go /tmp/healthcheck.go
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/nexus-proxy-healthcheck /tmp/healthcheck.go

FROM ${RUNTIME_IMAGE}

COPY --from=build /out/nexus-proxy /usr/local/bin/nexus-proxy
COPY --from=build /out/nexus-proxy-healthcheck /usr/local/bin/nexus-proxy-healthcheck
COPY --from=build --chown=nonroot:nonroot /out/state /var/lib/nexus-proxy
COPY nexus-gateway-policy.json /etc/nexus/nexus-gateway-policy.json
COPY THIRD_PARTY_NOTICES.md /usr/share/doc/nexus-local-proxy/THIRD_PARTY_NOTICES.md

USER nonroot:nonroot
EXPOSE 3301

ENTRYPOINT ["/usr/local/bin/nexus-proxy"]
