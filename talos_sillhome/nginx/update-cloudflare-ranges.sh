#!/usr/bin/env bash
# Refresh the Cloudflare edge ranges used by nginx for sillhome.com, safely.
# Writes the two files that must stay in sync:
#   cloudflare-realip.conf   set_real_ip_from ... + real_ip_header CF-Connecting-IP   (visitor address)
#   cloudflare-allow.conf    geo $realip_remote_addr $from_cloudflare { ... }           (origin lock, 403 for everyone else)
# Why this exists: if Cloudflare adds a range and the lock is stale, real visitors get 403; if the lists drift apart,
# rate limits count Cloudflare addresses. Run it from cron/systemd weekly on the nginx VM.
#
# Safety: downloads to a temp dir, validates (CIDR syntax, enough ranges), installs only if the content changed,
# runs `nginx -t`, reloads, and puts the previous files back if the test fails. Exit 0 = ok or unchanged, 1 = failed.
# Usage (as root on the nginx VM):  ./update-cloudflare-ranges.sh
#   NGINX_CONF_DIR=/etc/nginx/conf.d  RELOAD_CMD="nginx -s reload"  LAN_CIDR=10.0.0.0/24  TEST_ONLY=1 (write to ./out, no nginx)
set -euo pipefail

DIR="${NGINX_CONF_DIR:-/etc/nginx/conf.d}"
LAN="${LAN_CIDR:-10.0.0.0/24}"
RELOAD="${RELOAD_CMD:-nginx -s reload}"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
[ -n "${TEST_ONLY:-}" ] && DIR="$PWD/out" && mkdir -p "$DIR"

curl -fsS --max-time 20 https://www.cloudflare.com/ips-v4 -o "$TMP/v4"
curl -fsS --max-time 20 https://www.cloudflare.com/ips-v6 -o "$TMP/v6"
# a trailing newline is not guaranteed
for f in v4 v6; do [ "$(tail -c1 "$TMP/$f" | wc -l)" -eq 1 ] || echo >> "$TMP/$f"; done

ok4='^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$'
ok6='^[0-9a-fA-F:]+/[0-9]{1,3}$'
grep -qvE "$ok4" "$TMP/v4" && { echo "unexpected line in ips-v4, refusing to update" >&2; exit 1; }
grep -qvE "$ok6" "$TMP/v6" && { echo "unexpected line in ips-v6, refusing to update" >&2; exit 1; }
[ "$(wc -l < "$TMP/v4")" -ge 8 ] && [ "$(wc -l < "$TMP/v6")" -ge 3 ] || { echo "too few ranges (v4=$(wc -l < "$TMP/v4"), v6=$(wc -l < "$TMP/v6")), refusing to update" >&2; exit 1; }

STAMP="$(date +%F)"
{
  echo "# Cloudflare edge ranges, generated $STAMP by update-cloudflare-ranges.sh from https://www.cloudflare.com/ips-v4 and ips-v6."
  while read -r r; do [ -n "$r" ] && echo "set_real_ip_from $r;"; done < <(cat "$TMP/v4" "$TMP/v6")
  echo "real_ip_header CF-Connecting-IP;"
  echo "real_ip_recursive off;"
} > "$TMP/cloudflare-realip.conf"
{
  echo "# Only Cloudflare (and the LAN) may reach sillhome.com on 443; everyone else gets 403 (see sillhome.com.conf)."
  echo "# Generated $STAMP by update-cloudflare-ranges.sh. Same ranges as cloudflare-realip.conf. Do not edit by hand."
  echo "geo \$realip_remote_addr \$from_cloudflare {"
  echo "    default 0;"
  while read -r r; do [ -n "$r" ] && echo "    $r 1;"; done < <(cat "$TMP/v4" "$TMP/v6")
  echo "    $LAN 1;      # LAN (hairpin / local tests)"
  echo "    127.0.0.1 1;"
  echo "}"
} > "$TMP/cloudflare-allow.conf"

# ignore the generated-on date when comparing, so an unchanged list does not trigger a reload
strip() { grep -v '^# ' "$1" 2>/dev/null || true; }
changed=0
for f in cloudflare-realip.conf cloudflare-allow.conf; do
  if ! diff -q <(strip "$TMP/$f") <(strip "$DIR/$f") >/dev/null 2>&1; then changed=1; fi
done
if [ "$changed" -eq 0 ]; then echo "Cloudflare ranges unchanged ($(wc -l < "$TMP/v4") v4, $(wc -l < "$TMP/v6") v6)"; exit 0; fi

for f in cloudflare-realip.conf cloudflare-allow.conf; do [ -f "$DIR/$f" ] && cp -p "$DIR/$f" "$TMP/$f.prev"; done
install -m 644 "$TMP/cloudflare-realip.conf" "$TMP/cloudflare-allow.conf" "$DIR/"
if [ -n "${TEST_ONLY:-}" ]; then echo "TEST_ONLY: wrote new files to $DIR"; exit 0; fi
if nginx -t 2>"$TMP/nginx.err"; then
  $RELOAD
  echo "Cloudflare ranges updated and nginx reloaded ($(wc -l < "$TMP/v4") v4, $(wc -l < "$TMP/v6") v6)"
else
  cat "$TMP/nginx.err" >&2
  for f in cloudflare-realip.conf cloudflare-allow.conf; do [ -f "$TMP/$f.prev" ] && cp -p "$TMP/$f.prev" "$DIR/$f"; done
  echo "nginx -t failed: previous files restored, nothing reloaded" >&2
  exit 1
fi
