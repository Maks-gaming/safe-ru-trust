#!/usr/bin/env bash
# Builds signed update bundles, good and malicious, with a throwaway signer. Then run test/run.ps1 on Windows.
set -euo pipefail
cd "$(dirname "$0")/.."; OUT=${1:?out dir}; rm -rf "$OUT"; mkdir -p "$OUT"
UP=upstream/russian_trusted_root_ca.pem; SKI=$(openssl x509 -in $UP -noout -ext subjectKeyIdentifier | tail -1 | tr -d ' ')
openssl req -x509 -newkey rsa:3072 -nodes -keyout "$OUT/s.key" -subj '/CN=test signer' -days 2 -out "$OUT/signer.crt" 2>/dev/null
openssl genrsa -out "$OUT/other.key" 3072 2>/dev/null
cp $UP "$OUT/upstream.crt"
IPS='excluded;IP:0.0.0.0/0.0.0.0,excluded;IP:0:0:0:0:0:0:0:0/0:0:0:0:0:0:0:0'
# case serial nc_ext [upstream-for-cross]
mk(){ d="$OUT/$1"; mkdir -p "$d"; k="$d/k"
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -keyout "$k" -out "$d/safe-ru-trust-root.crt" -days 2 -subj "/CN=Safe RU Trust t-$1" \
    -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" ${3:+-addext "$3"} 2>/dev/null
  printf 'basicConstraints=critical,CA:TRUE\nkeyUsage=critical,keyCertSign,cRLSign\nsubjectKeyIdentifier=%s\nauthorityKeyIdentifier=keyid\n' "$SKI" > "$d/e"
  openssl x509 -in "${4:-$UP}" -CA "$d/safe-ru-trust-root.crt" -CAkey "$k" -set_serial 7 -days 2 -extfile "$d/e" -out "$d/safe-ru-trust-cross.crt" 2>/dev/null
  { echo "serial=$2"; echo "version=t-$1"; echo "root_sha256=$(sha256sum "$d/safe-ru-trust-root.crt"|cut -d' ' -f1)"; echo "cross_sha256=$(sha256sum "$d/safe-ru-trust-cross.crt"|cut -d' ' -f1)"; } > "$d/manifest.txt"
  openssl dgst -sha256 -sign "$OUT/s.key" -out "$d/manifest.sig" "$d/manifest.txt"; rm -f "$k" "$d/e"; }
OK="nameConstraints=critical,permitted;DNS:rzd.ru,permitted;DNS:sberbank.com,$IPS"
mk good 202701010000 "$OK"
mk rollback 202001010000 "$OK"
mk no_constraints 202701010000 ""
mk not_critical 202701010000 "nameConstraints=permitted;DNS:rzd.ru,$IPS"
mk foreign 202701010000 "nameConstraints=critical,permitted;DNS:google.com,$IPS"
mk public_suffix 202701010000 "nameConstraints=critical,permitted;DNS:gov.ru,$IPS"
mk bare_tld 202701010000 "nameConstraints=critical,permitted;DNS:ru,$IPS"
mk dot_tld 202701010000 "nameConstraints=critical,permitted;DNS:.ru,$IPS"
mk no_ip_exclusion 202701010000 "nameConstraints=critical,permitted;DNS:rzd.ru"
mk partial_ip_exclusion 202701010000 "nameConstraints=critical,permitted;DNS:rzd.ru,excluded;IP:1.2.3.0/255.255.255.0,excluded;IP:0:0:0:0:0:0:0:0/0:0:0:0:0:0:0:0"
mk ip_permitted 202701010000 "nameConstraints=critical,permitted;DNS:rzd.ru,permitted;IP:1.2.3.0/255.255.255.0,$IPS"
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -keyout /dev/null -subj "$(openssl x509 -in $UP -noout -subject -nameopt RFC2253 | sed 's/^subject=//; s/^/\//; s/,/\//g' | awk -F/ '{print "/"$4"/"$3"/"$2}')" -days 2 -out "$OUT/fakeup.pem" 2>/dev/null
mk wrong_cross_key 202701010000 "$OK" "$OUT/fakeup.pem"
cp -r "$OUT/good" "$OUT/bad_signature"; openssl dgst -sha256 -sign "$OUT/other.key" -out "$OUT/bad_signature/manifest.sig" "$OUT/bad_signature/manifest.txt"
cp -r "$OUT/good" "$OUT/hash_mismatch"; cp "$OUT/foreign/safe-ru-trust-root.crt" "$OUT/hash_mismatch/"
rm -f "$OUT/s.key" "$OUT/other.key" "$OUT/fakeup.pem"
