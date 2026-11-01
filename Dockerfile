# Coolify website template: Caddy serving a static site or proxying an upstream, with optional password lock.
# Build pack in Coolify: Dockerfile. Port: 80. Everything else comes from environment variables (see README).
FROM caddy:2-alpine
COPY entrypoint.sh /entrypoint.sh
COPY site /srv/site
RUN chmod +x /entrypoint.sh && adduser -D -H -u 10001 web && chown -R web /srv/site /config /data
USER web
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://127.0.0.1:80/healthz >/dev/null || exit 1
ENTRYPOINT ["/entrypoint.sh"]
