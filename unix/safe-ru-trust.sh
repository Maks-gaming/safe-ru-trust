#!/usr/bin/env bash
# Safe RU Trust for Linux and macOS: safe-ru-trust.sh install|uninstall|update [--dry-run]
# Linux: per-user, browsers' NSS databases only. Never the system store: everything there is an unconstrained anchor,
# so the cross certificate would make the Mintsifry root fully trusted. macOS: System keychain, needs sudo.
set -euo pipefail
BASE=${SRT_BASE:-https://github.com/Maks-gaming/safe-ru-trust/releases/latest/download}
OS=$(uname -s)
if [ "$OS" = Darwin ]; then DEFAULT_DIR="/Library/Application Support/SafeRUTrust"; else DEFAULT_DIR="$HOME/.local/share/safe-ru-trust"; fi
DIR=${SRT_DIR:-$DEFAULT_DIR}
HERE=$(cd "$(dirname "$0")" && pwd)
NICK_ROOT="Safe RU Trust"; NICK_CROSS="Safe RU Trust cross"
PLIST=/Library/LaunchDaemons/io.github.maks-gaming.safe-ru-trust.plist

die(){ echo "REJECTED: $*" >&2; exit 1; }
name(){ openssl x509 -in "$1" -noout "-$2" -nameopt RFC2253 | sed "s/^$2= *//"; }
pubhash(){ openssl x509 -in "$1" -noout -pubkey | openssl dgst -sha256 | awk '{print $NF}'; }
sha(){ if command -v sha256sum >/dev/null; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }

domain_ok(){
  echo "$1" | LC_ALL=C grep -Eq '^[a-z0-9-]+(\.[a-z0-9-]+)+$' || die "domain not allowed (format): $1"
  case "$1" in gov.ru|com.ru|net.ru|org.ru|pp.ru|msk.ru|spb.ru|edu.ru|ac.ru|gov.su|com.su|net.su|org.su) die "domain not allowed (public suffix): $1";; esac
  case "$1" in *.ru|*.su|*.xn--p1ai|sberbank.com|vtb.com|tochka.com) ;; *) die "domain not allowed (zone): $1";; esac
}

assert_root(){
  local s; s=$(name "$1" subject)
  case "$s" in "CN=Safe RU Trust "*) ;; *) die "unexpected root subject: $s";; esac
  [ "$s" = "$(name "$1" issuer)" ] || die "root is not self-issued"
  local text; text=$(openssl x509 -in "$1" -noout -text)
  echo "$text" | grep -Eq 'X509v3 Name Constraints: *critical' || die "root has no critical name constraints"
  local block; block=$(echo "$text" | awk '/X509v3 Name Constraints/{f=1;next} f&&/X509v3|Signature Algorithm/{exit} f{gsub(/^ +| +$/,"");print}')
  local sec="" v4=0 v6=0 n=0 l
  while IFS= read -r l; do
    case "$l" in
      "") ;;
      Permitted:) sec=p;;
      Excluded:) sec=e;;
      DNS:*) [ "$sec" = p ] || die "unexpected DNS exclusion"; domain_ok "${l#DNS:}"; n=$((n+1));;
      IP:0.0.0.0/0.0.0.0) [ "$sec" = e ] || die "permitted subtree is not a DNS name"; v4=1;;
      IP:0:0:0:0:0:0:0:0/0:0:0:0:0:0:0:0|IP:::/::) [ "$sec" = e ] || die "permitted subtree is not a DNS name"; v6=1;;
      *) if [ "$sec" = p ]; then die "permitted subtree is not a DNS name"; else die "root does not exclude all IP addresses"; fi;;
    esac
  done <<EOF
$block
EOF
  [ "$n" -ge 1 ] || die "root permits nothing"
  [ "$v4$v6" = 11 ] || die "root does not exclude all IP addresses"
}

assert_cross(){ # cross root upstream
  [ "$(name "$1" subject)" = "$(name "$3" subject)" ] || die "cross subject differs from upstream"
  [ "$(pubhash "$1")" = "$(pubhash "$3")" ] || die "cross key differs from upstream"
  [ "$(name "$1" issuer)" = "$(name "$2" subject)" ] || die "cross is not issued by root"
}

nss_dbs(){
  mkdir -p "$HOME/.pki/nssdb"
  [ -f "$HOME/.pki/nssdb/cert9.db" ] || certutil -N -d "sql:$HOME/.pki/nssdb" --empty-password
  echo "$HOME/.pki/nssdb"
  # Firefox and its forks move profiles between versions, so look for the database itself.
  find "$HOME/.mozilla" "$HOME/.config/mozilla" "$HOME/.librewolf" "$HOME/.config/librewolf" "$HOME/.zen" "$HOME/.floorp" "$HOME/.waterfox" \
       "$HOME/snap" "$HOME/.var/app" -maxdepth 7 -name cert9.db -exec dirname {} \; 2>/dev/null || true
}

apply_certs(){ # root cross
  if [ "$OS" = Darwin ]; then
    remove_certs
    security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain "$1"
    security add-certificates -k /Library/Keychains/System.keychain "$2"
    defaults write /Library/Preferences/org.mozilla.firefox EnterprisePoliciesEnabled -bool TRUE
    defaults write /Library/Preferences/org.mozilla.firefox Certificates__ImportEnterpriseRoots -bool TRUE
  else
    command -v certutil >/dev/null || die "certutil not found: install libnss3-tools (Debian/Ubuntu), nss-tools (Fedora) or nss (Arch)"
    remove_certs
    nss_dbs | while IFS= read -r db; do
      certutil -A -d "sql:$db" -n "$NICK_ROOT" -t "C,," -i "$1"
      certutil -A -d "sql:$db" -n "$NICK_CROSS" -t ",," -i "$2"
    done
  fi
}

remove_certs(){
  if [ "$OS" = Darwin ]; then
    local h
    for h in $(security find-certificate -a -Z -c "Safe RU Trust" /Library/Keychains/System.keychain 2>/dev/null | awk '/SHA-1/{print $NF}'); do
      security delete-certificate -t -Z "$h" /Library/Keychains/System.keychain || true
    done
    # Only our cross: a plain Mintsifry root, if the user installed one, stays.
    local t; t=$(mktemp -d)
    security find-certificate -a -p -c "Russian Trusted Root CA" /Library/Keychains/System.keychain 2>/dev/null | awk -v d="$t" '/BEGIN CERT/{n++} {print > (d "/" n ".pem")}'
    for h in "$t"/*.pem; do
      [ -f "$h" ] || continue
      if openssl x509 -in "$h" -noout -issuer | grep -q "Safe RU Trust"; then
        security delete-certificate -Z "$(openssl x509 -in "$h" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d :)" /Library/Keychains/System.keychain || true
      fi
    done
    rm -rf "$t"
  else
    nss_dbs | while IFS= read -r db; do
      certutil -D -d "sql:$db" -n "$NICK_CROSS" 2>/dev/null || true
      certutil -D -d "sql:$db" -n "$NICK_ROOT" 2>/dev/null || true
    done
  fi
}

cmd_update(){
  local dry=${1:-} f
  t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
  for f in manifest.txt manifest.sig safe-ru-trust-root.crt safe-ru-trust-cross.crt; do
    case "$BASE" in https://*) curl -fsSL --max-time 60 -o "$t/$f" "$BASE/$f" || die "download failed: $f";; *) cp "$BASE/$f" "$t/$f";; esac
  done
  openssl x509 -in "$DIR/signer.crt" -noout -pubkey > "$t/signer.pub"
  openssl dgst -sha256 -verify "$t/signer.pub" -signature "$t/manifest.sig" "$t/manifest.txt" >/dev/null 2>&1 || die "bad manifest signature"
  local serial version have
  serial=$(sed -n 's/^serial=//p' "$t/manifest.txt"); version=$(sed -n 's/^version=//p' "$t/manifest.txt")
  echo "$serial" | grep -Eq '^[0-9]{12}$' || die "bad serial"
  have=$(cat "$DIR/serial.txt" 2>/dev/null || echo 0)
  if [ "$serial" -le "$have" ]; then echo "no update ($serial <= $have)"; return 0; fi
  grep -qx "root_sha256=$(sha "$t/safe-ru-trust-root.crt")" "$t/manifest.txt" || die "hash mismatch: safe-ru-trust-root.crt"
  grep -qx "cross_sha256=$(sha "$t/safe-ru-trust-cross.crt")" "$t/manifest.txt" || die "hash mismatch: safe-ru-trust-cross.crt"
  assert_root "$t/safe-ru-trust-root.crt"
  assert_cross "$t/safe-ru-trust-cross.crt" "$t/safe-ru-trust-root.crt" "$DIR/upstream.crt"
  if [ "$dry" = --dry-run ]; then echo "valid $version ($serial)"; return 0; fi
  apply_certs "$t/safe-ru-trust-root.crt" "$t/safe-ru-trust-cross.crt"
  echo "$serial" > "$DIR/serial.txt"
  echo "updated to $version ($serial)"
}

schedule(){
  if [ "$OS" = Darwin ]; then
    cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>io.github.maks-gaming.safe-ru-trust</string>
<key>ProgramArguments</key><array><string>/bin/bash</string><string>$DIR/safe-ru-trust.sh</string><string>update</string></array>
<key>StartInterval</key><integer>86400</integer>
<key>RunAtLoad</key><true/>
</dict></plist>
EOF
    launchctl unload "$PLIST" 2>/dev/null || true; launchctl load "$PLIST"; echo "Daily updates enabled."
  elif command -v systemctl >/dev/null && systemctl --user show-environment >/dev/null 2>&1; then
    local u="$HOME/.config/systemd/user"; mkdir -p "$u"
    printf '[Unit]\nDescription=Safe RU Trust update\nWants=network-online.target\n[Service]\nType=oneshot\nExecStart=/usr/bin/env bash "%s/safe-ru-trust.sh" update\n' "$DIR" > "$u/safe-ru-trust.service"
    printf '[Unit]\nDescription=Daily Safe RU Trust update\n[Timer]\nOnCalendar=daily\nRandomizedDelaySec=4h\nPersistent=true\n[Install]\nWantedBy=timers.target\n' > "$u/safe-ru-trust.timer"
    systemctl --user daemon-reload; systemctl --user enable --now safe-ru-trust.timer >/dev/null; echo "Daily updates enabled."
  else
    echo "No systemd user session: add to cron yourself: 0 12 * * * bash \"$DIR/safe-ru-trust.sh\" update"
  fi
}

cmd_install(){
  [ "$OS" != Darwin ] || [ "$(id -u)" = 0 ] || die "on macOS run with sudo"
  assert_root "$HERE/safe-ru-trust-root.crt"
  assert_cross "$HERE/safe-ru-trust-cross.crt" "$HERE/safe-ru-trust-root.crt" "$HERE/upstream.crt"
  mkdir -p "$DIR"
  apply_certs "$HERE/safe-ru-trust-root.crt" "$HERE/safe-ru-trust-cross.crt"
  cp "$HERE/safe-ru-trust.sh" "$HERE/signer.crt" "$HERE/upstream.crt" "$DIR/"
  sed -n 's/^serial=//p' "$HERE/manifest.txt" > "$DIR/serial.txt"
  schedule
  echo "Installed. Restart your browser if it is open."
}

cmd_uninstall(){
  [ "$OS" != Darwin ] || [ "$(id -u)" = 0 ] || die "on macOS run with sudo"
  if [ "$OS" = Darwin ]; then
    launchctl unload "$PLIST" 2>/dev/null || true; rm -f "$PLIST"
    # ponytail: drops the policy even if someone else set it; we do not track who did
    defaults delete /Library/Preferences/org.mozilla.firefox Certificates__ImportEnterpriseRoots 2>/dev/null || true
  elif command -v systemctl >/dev/null; then
    systemctl --user disable --now safe-ru-trust.timer 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/safe-ru-trust.service" "$HOME/.config/systemd/user/safe-ru-trust.timer"
  fi
  remove_certs; rm -rf "$DIR"; echo "Removed."
}

case "${1:-}" in
  install) cmd_install;;
  uninstall) cmd_uninstall;;
  update) cmd_update "${2:-}";;
  *) echo "usage: $0 install|uninstall|update [--dry-run]" >&2; exit 2;;
esac
