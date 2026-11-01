# Coolify website template

One container, no build step, no npm. Caddy serves the files in `site/`, or proxies another service, and can lock the whole site behind a username and password. TLS, domains and deploys are Coolify's job.

## Use it for a new site

1. GitHub: **Use this template** → new repository. Put your site in `site/`.
2. Coolify: project → **+ New resource** → your repository → build pack **Dockerfile**, port **80**.
3. Set the domain (Coolify issues the certificate). Deploy.

## Environment variables (Coolify → Environment Variables)

| Variable | Meaning |
|---|---|
| `SITE_MODE` | `static` (default) serves `site/`; `proxy` forwards everything to `UPSTREAM` |
| `UPSTREAM` | proxy mode target, for example `http://100.108.111.44:8080` (a Tailscale IP works if the Coolify server is on the tailnet) |
| `BASIC_AUTH_USER` | with `BASIC_AUTH_HASH`, locks the site. Leave both empty for a public site |
| `BASIC_AUTH_HASH` | bcrypt hash. Make it with `docker run --rm caddy:2-alpine caddy hash-password --plaintext 'your password'` and paste the hash, never the password. Mark the variable as a secret in Coolify |
| `AUTH_REALM` | text of the login prompt |

`/healthz` always answers `ok` without a password, so Coolify's health check keeps working.

## What you get

- Security headers, compression, non-root process, health check.
- Proxy mode keeps the browser's `Host` and `X-Forwarded-Proto`, so upstreams behind it (Hermes Agent's dashboard, for one) see the real public URL. WebSockets pass through.
- Nothing secret in the repository. Passwords live only as hashes in Coolify's environment.

## Local test

```bash
docker build -t site . && docker run --rm -p 8088:80 -e BASIC_AUTH_USER=me -e BASIC_AUTH_HASH="$(docker run --rm caddy:2-alpine caddy hash-password --plaintext test1234)" site
```

Then open http://localhost:8088 and log in with `me` / `test1234`.
