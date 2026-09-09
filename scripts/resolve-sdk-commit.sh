#!/bin/sh
# Resolve dappnode-nexus-sdk to the commit this build will use, and write it
# into the manifest and compose so the published package records its own
# provenance.
#
# This value is an output, not an input. Nothing verifies the proxy image
# against it -- the package is trusted because Dappnode published it onchain --
# so hand-maintaining a pin bought a record that CI can produce for free, at
# the cost of a bump PR for every SDK change.
#
# The Dockerfile still requires a full 40-character commit SHA and re-checks it
# after fetching, so the build remains content-addressed. Only who supplies the
# value changed.
set -eu

REPO="${SDK_REPO:-https://github.com/dappnode/dappnode-nexus-sdk.git}"
REF="${SDK_REF:-main}"

COMMIT="$(git ls-remote "$REPO" "refs/heads/$REF" | cut -f1)"
if ! printf '%s' "$COMMIT" | grep -Eq '^[0-9a-f]{40}$'; then
  echo "could not resolve $REPO $REF to a commit (got: '$COMMIT')" >&2
  exit 1
fi

echo "SDK $REF resolves to $COMMIT"

# Both files carry it: the manifest is what the published package shows, the
# compose build-arg is what the image is actually built from.
tmp="$(mktemp)"
sed -E "s/\"upstreamVersion\": \"[0-9a-f]{40}\"/\"upstreamVersion\": \"$COMMIT\"/" \
  dappnode_package.json > "$tmp" && mv "$tmp" dappnode_package.json
tmp="$(mktemp)"
sed -E "s/UPSTREAM_VERSION: [0-9a-f]{40}/UPSTREAM_VERSION: $COMMIT/" \
  docker-compose.yml > "$tmp" && mv "$tmp" docker-compose.yml

grep -q "$COMMIT" dappnode_package.json && grep -q "$COMMIT" docker-compose.yml \
  || { echo "failed to stamp the resolved commit" >&2; exit 1; }
