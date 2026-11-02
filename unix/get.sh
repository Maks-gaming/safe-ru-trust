#!/bin/sh
# One-line install of the latest release on Linux or macOS:
# curl -fsSL https://raw.githubusercontent.com/Maks-gaming/safe-ru-trust/main/unix/get.sh | sh
set -e
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
curl -fsSL https://github.com/Maks-gaming/safe-ru-trust/releases/latest/download/safe-ru-trust-unix.tar.gz | tar xz -C "$d"
if [ "$(uname)" = Darwin ]; then sudo bash "$d/safe-ru-trust.sh" install; else bash "$d/safe-ru-trust.sh" install; fi
