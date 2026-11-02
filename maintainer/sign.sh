#!/usr/bin/env bash
# Maintainer only: verifies a draft release, signs its manifest, publishes it.
# Usage: maintainer/sign.sh v2026.11
set -euo pipefail
cd "$(dirname "$0")/.."
TAG=$1 KEY=${SRT_KEY:-$HOME/.config/safe-ru-trust/release.key} R=Maks-gaming/safe-ru-trust
D=$(mktemp -d); trap 'rm -rf "$D"' EXIT
gh release download "$TAG" -R "$R" -D "$D"
./verify.sh "$D/safe-ru-trust-root.crt" "$D/safe-ru-trust-cross.crt"
openssl dgst -sha256 -sign "$KEY" -out "$D/manifest.sig" "$D/manifest.txt"
./verify.sh "$D/safe-ru-trust-root.crt" "$D/safe-ru-trust-cross.crt"
gh release upload "$TAG" "$D/manifest.sig" -R "$R"
gh release edit "$TAG" --draft=false --latest -R "$R"
