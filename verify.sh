#!/usr/bin/env bash
# Проверка выпуска без доверия к автору: только публичные данные.
set -euo pipefail
cd "$(dirname "$0")"
R=${1:-dist/safe-ru-trust-root.crt}; C=${2:-dist/safe-ru-trust-cross.crt}; UP=upstream/russian_trusted_root_ca.pem
fail(){ echo "FAIL: $*" >&2; exit 1; }
openssl x509 -in "$R" -noout -ext nameConstraints | grep -q critical || fail "name constraints not critical"
A=$(openssl x509 -in "$R" -noout -ext nameConstraints | grep -oE 'DNS:[^ ]+' | cut -d: -f2 | sort)
[ "$A" = "$(sort domains.txt)" ] || fail "constraints differ from domains.txt"
X=$(openssl x509 -in "$R" -noout -ext nameConstraints | grep -oE 'IP:[^ ]+' | sort)
[ "$X" = "$(printf 'IP:0.0.0.0/0.0.0.0\nIP:0:0:0:0:0:0:0:0/0:0:0:0:0:0:0:0' | sort)" ] || fail "must exclude exactly all IPs"
grep -qvE '^[^.]+\.[^.]+' domains.txt && fail "bare TLD in domains.txt"
pub(){ openssl x509 -in "$1" -noout -pubkey | sha256sum; }
[ "$(pub "$C")" = "$(pub $UP)" ] || fail "cross key is not the Mintsifry root key"
[ "$(openssl x509 -in "$C" -noout -subject)" = "$(openssl x509 -in $UP -noout -subject)" ] || fail "cross subject differs"
openssl verify -CAfile "$R" "$C" >/dev/null || fail "cross is not signed by root"
D=$(dirname "$R")
if [ -f "$D/safe-ru-trust.mobileconfig" ]; then
  python3 - "$D/safe-ru-trust.mobileconfig" "$R" "$C" <<'PY' || fail "mobileconfig does not hold exactly these two certificates"
import plistlib, ssl, sys
want = sorted(ssl.PEM_cert_to_DER_cert(open(p).read()) for p in sys.argv[2:])
assert sorted(p["PayloadContent"] for p in plistlib.load(open(sys.argv[1], "rb"))["PayloadContent"]) == want
PY
fi
if [ -f "$D/manifest.sig" ]; then
  openssl dgst -sha256 -verify <(openssl x509 -in signer.crt -noout -pubkey) -signature "$D/manifest.sig" "$D/manifest.txt" >/dev/null || fail "bad manifest signature"
  grep -qx "root_sha256=$(sha256sum "$R" | cut -d' ' -f1)" "$D/manifest.txt" || fail "root hash not in manifest"
  grep -qx "cross_sha256=$(sha256sum "$C" | cut -d' ' -f1)" "$D/manifest.txt" || fail "cross hash not in manifest"
  echo "OK: manifest signed by $(openssl x509 -in signer.crt -noout -fingerprint -sha256)"
fi
echo "OK: $(wc -l < domains.txt) domains"
openssl x509 -in "$R" -noout -subject -fingerprint -sha256 -enddate
openssl x509 -in "$C" -noout -issuer -fingerprint -sha256
