#!/usr/bin/env bash
# Проверка выпуска без доверия к автору: только публичные данные.
set -euo pipefail
cd "$(dirname "$0")"
R=${1:-dist/safe-ru-trust-root.crt}; C=${2:-dist/safe-ru-trust-cross.crt}; UP=upstream/russian_trusted_root_ca.pem
fail(){ echo "FAIL: $*" >&2; exit 1; }
openssl x509 -in "$R" -noout -ext nameConstraints | grep -q critical || fail "name constraints not critical"
A=$(openssl x509 -in "$R" -noout -ext nameConstraints | grep -oE 'DNS:[^ ]+' | cut -d: -f2 | sort)
[ "$A" = "$(sort domains.txt)" ] || fail "constraints differ from domains.txt"
openssl x509 -in "$R" -noout -ext nameConstraints | grep -q 'Excluded' && fail "unexpected excluded subtree"
grep -qvE '^[^.]+\.[^.]+' domains.txt && fail "bare TLD in domains.txt"
pub(){ openssl x509 -in "$1" -noout -pubkey | sha256sum; }
[ "$(pub "$C")" = "$(pub $UP)" ] || fail "cross key is not the Mintsifry root key"
[ "$(openssl x509 -in "$C" -noout -subject)" = "$(openssl x509 -in $UP -noout -subject)" ] || fail "cross subject differs"
openssl verify -CAfile "$R" "$C" >/dev/null || fail "cross is not signed by root"
echo "OK: $(wc -l < domains.txt) domains"
openssl x509 -in "$R" -noout -subject -fingerprint -sha256 -enddate
openssl x509 -in "$C" -noout -issuer -fingerprint -sha256
