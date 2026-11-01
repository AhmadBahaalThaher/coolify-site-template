#!/bin/sh
# Writes /tmp/Caddyfile from the environment, then runs Caddy on :80 (TLS is Coolify's Traefik job).
#   SITE_MODE        static (default) | proxy
#   UPSTREAM         proxy mode: where requests go, e.g. http://100.108.111.44:8080
#   BASIC_AUTH_USER  set together with BASIC_AUTH_HASH to password-lock the whole site
#   BASIC_AUTH_HASH  bcrypt hash from: caddy hash-password --plaintext 'your password'
#   AUTH_REALM       prompt text, default "Restricted"
#   TRUST_PROXY      CIDR of the proxy in front (Coolify's Traefik network), default 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
set -eu
MODE="${SITE_MODE:-static}"
REALM="${AUTH_REALM:-Restricted}"
TRUST="${TRUST_PROXY:-10.0.0.0/8 172.16.0.0/12 192.168.0.0/16}"
F=/tmp/Caddyfile
{
  echo '{'
  echo '  auto_https off'
  echo '  admin off'
  echo "  servers { trusted_proxies static $TRUST }"
  echo '}'
  echo ':80 {'
  echo '  encode zstd gzip'
  echo '  header { -Server; X-Content-Type-Options nosniff; Referrer-Policy no-referrer; X-Frame-Options SAMEORIGIN; Permissions-Policy "camera=(), microphone=(), geolocation=()" }'
  echo '  handle /healthz { respond "ok" 200 }'
  if [ -n "${BASIC_AUTH_USER:-}" ] && [ -n "${BASIC_AUTH_HASH:-}" ]; then
    echo "  @locked not path /healthz"
    echo "  basic_auth @locked bcrypt \"$REALM\" { $BASIC_AUTH_USER $BASIC_AUTH_HASH }"
  fi
  if [ "$MODE" = "proxy" ]; then
    [ -n "${UPSTREAM:-}" ] || { echo "SITE_MODE=proxy needs UPSTREAM" >&2; exit 1; }
    echo "  reverse_proxy $UPSTREAM {"
    echo '    header_up Host {host}'
    echo '    header_up X-Forwarded-Proto {header.X-Forwarded-Proto}'
    echo '  }'
  else
    echo '  root * /srv/site'
    echo '  file_server'
  fi
  echo '}'
} > "$F"
caddy validate --config "$F" --adapter caddyfile >/dev/null
exec caddy run --config "$F" --adapter caddyfile
