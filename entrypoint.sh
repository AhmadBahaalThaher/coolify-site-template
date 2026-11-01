#!/bin/sh
# Writes /tmp/Caddyfile from the environment, then runs Caddy on :80 (TLS is Coolify's Traefik job).
#   SITE_MODE        static (default) | proxy
#   UPSTREAM         proxy mode: where requests go, e.g. http://100.108.111.44:8080
#   BASIC_AUTH_USER  set together with BASIC_AUTH_HASH to password-lock the whole site
#   BASIC_AUTH_HASH  bcrypt hash from: caddy hash-password --plaintext 'your password'
#   AUTH_REALM       prompt text, default "Restricted"
#   TRUST_PROXY      proxy networks allowed to set X-Forwarded-*, default: Docker/private ranges
set -eu
MODE="${SITE_MODE:-static}"
REALM="${AUTH_REALM:-Restricted}"
TRUST="${TRUST_PROXY:-10.0.0.0/8 172.16.0.0/12 192.168.0.0/16}"
F=/tmp/Caddyfile
{
  cat <<CADDY
{
	auto_https off
	admin off
	servers {
		trusted_proxies static $TRUST
	}
}
:80 {
	encode zstd gzip
	header {
		-Server
		X-Content-Type-Options nosniff
		Referrer-Policy no-referrer
		X-Frame-Options SAMEORIGIN
		Permissions-Policy "camera=(), microphone=(), geolocation=()"
	}
	handle /healthz {
		respond "ok" 200
	}
CADDY
  if [ -n "${BASIC_AUTH_USER:-}" ] && [ -n "${BASIC_AUTH_HASH:-}" ]; then
    cat <<CADDY
	@locked not path /healthz
	basic_auth @locked bcrypt "$REALM" {
		$BASIC_AUTH_USER $BASIC_AUTH_HASH
	}
CADDY
  fi
  if [ "$MODE" = "proxy" ]; then
    [ -n "${UPSTREAM:-}" ] || { echo "SITE_MODE=proxy needs UPSTREAM" >&2; exit 1; }
    # The portal's own Basic credentials never reach the upstream: an upstream that answers 401 with its
    # own challenge would otherwise make the browser re-prompt forever.
    cat <<CADDY
	reverse_proxy $UPSTREAM {
		header_up Host {host}
		header_up -Authorization
	}
CADDY
  else
    cat <<CADDY
	root * /srv/site
	file_server
CADDY
  fi
  echo "}"
} > "$F"
caddy validate --config "$F" --adapter caddyfile >/dev/null
exec caddy run --config "$F" --adapter caddyfile
