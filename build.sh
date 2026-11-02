#!/usr/bin/env bash
# Собирает корень с name constraints и кросс-подпись корня Минцифры. Ключ живёт только в памяти этого запуска.
set -euo pipefail
cd "$(dirname "$0")"
VERSION=${1:?usage: build.sh <version>}
UP=upstream/russian_trusted_root_ca.pem
PIN='D2:6D:2D:02:31:B7:C3:9F:92:CC:73:85:12:BA:54:10:35:19:E4:40:5D:68:B5:BD:70:3E:97:88:CA:8E:CF:31'
[ "$(openssl x509 -in $UP -noout -fingerprint -sha256 | cut -d= -f2)" = "$PIN" ] || { echo "upstream fingerprint mismatch" >&2; exit 1; }
DAYS=$(( ( $(date -d "$(openssl x509 -in $UP -noout -enddate | cut -d= -f2)" +%s) - $(date +%s) ) / 86400 ))
# DNS constraints do not cover IP SANs, so all IPs are excluded.
NC=$(sed 's/^/permitted;DNS:/' domains.txt | paste -sd,),excluded\;IP:0.0.0.0/0.0.0.0,excluded\;IP:0:0:0:0:0:0:0:0/0:0:0:0:0:0:0:0
SKI=$(openssl x509 -in $UP -noout -ext subjectKeyIdentifier | tail -1 | tr -d ' ')
mkdir -p dist; T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -keyout "$T/k" -out dist/safe-ru-trust-root.crt -days "$DAYS" \
  -subj "/CN=Safe RU Trust $VERSION" -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -addext "nameConstraints=critical,$NC" 2>/dev/null
printf 'basicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign\nsubjectKeyIdentifier=%s\nauthorityKeyIdentifier=keyid\n' "$SKI" > "$T/ext"
openssl x509 -in $UP -CA dist/safe-ru-trust-root.crt -CAkey "$T/k" -set_serial "0x$(openssl rand -hex 8)" -days "$DAYS" -extfile "$T/ext" -out dist/safe-ru-trust-cross.crt 2>/dev/null
shred -u "$T/k"
cp $UP dist/upstream.crt
cp signer.crt dist/signer.crt
{ echo "serial=$(date -u +%Y%m%d%H%M)"; echo "version=$VERSION"
  echo "root_sha256=$(sha256sum dist/safe-ru-trust-root.crt | cut -d' ' -f1)"
  echo "cross_sha256=$(sha256sum dist/safe-ru-trust-cross.crt | cut -d' ' -f1)"; } > dist/manifest.txt
python3 ios/mobileconfig.py "$VERSION" dist/safe-ru-trust-root.crt dist/safe-ru-trust-cross.crt dist/safe-ru-trust.mobileconfig
./verify.sh dist/safe-ru-trust-root.crt dist/safe-ru-trust-cross.crt
