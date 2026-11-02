#!/usr/bin/env bash
# Usage: test/run.sh <fixtures dir>. Same cases as run.ps1 for unix/safe-ru-trust.sh, validation only.
F=$1; S="$(dirname "$0")/../unix/safe-ru-trust.sh"; bad=0
while read -r c want; do
  d=$(mktemp -d); cp "$F/signer.crt" "$F/upstream.crt" "$d"; echo 202601010000 > "$d/serial.txt"
  o=$(SRT_BASE="$F/$c" SRT_DIR="$d" bash "$S" update --dry-run 2>&1 || true)
  if echo "$o" | grep -qF "$want"; then r=ok; else r=FAIL; bad=$((bad+1)); fi
  printf '%-5s %-22s %s\n' "$r" "$c" "$o"; rm -rf "$d"
done <<'T'
good valid
rollback no update
no_constraints no critical name
not_critical no critical name
foreign zone
public_suffix public suffix
bare_tld format
dot_tld format
no_ip_exclusion exclude all IP
partial_ip_exclusion exclude all IP
ip_permitted not a DNS
wrong_cross_key cross key
bad_signature bad manifest
hash_mismatch hash mismatch
T
echo "failures: $bad"; exit $bad
