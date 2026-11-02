#!/bin/sh
# One-line install of the latest release on Linux or macOS:
# curl -fsSL https://github.com/Maks-gaming/safe-ru-trust/releases/latest/download/get.sh | sh
set -e
# Wrapped in a function so the shell has read the whole script before anything can touch stdin.
main() {
  if [ "$(uname)" = Darwin ]; then run=sudo; else
    run=
    [ -z "${SUDO_USER:-}" ] || { echo "Run without sudo: certificates go to your own browser profile. sudo is asked only to install certutil." >&2; exit 1; }
    if ! command -v certutil >/dev/null; then
      if command -v apt-get >/dev/null; then sudo apt-get install -y libnss3-tools
      elif command -v dnf >/dev/null; then sudo dnf install -y nss-tools
      elif command -v pacman >/dev/null; then sudo pacman -S --noconfirm nss
      elif command -v zypper >/dev/null; then sudo zypper install -y mozilla-nss-tools
      fi
    fi
  fi
  d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
  curl -fsSL https://github.com/Maks-gaming/safe-ru-trust/releases/latest/download/safe-ru-trust-unix.tar.gz | tar xz -C "$d"
  $run bash "$d/safe-ru-trust.sh" install
}
main </dev/null
