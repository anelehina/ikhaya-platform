# Runbook: resume site (anelehina.com)

What to do when the resume site alerts, and how to release a new version.

## How it works

```
Browser ──HTTPS──▶ Cloudflare edge ──tunnel (dialled out by ikhaya)──▶ cloudflared ──HTTP, Docker network "edge"──▶ resume-site (nginx :8080)
```

| Part | Where |
|---|---|
| Site source | private repo `resume-site` (static HTML/CSS, `nginx.conf`, `Dockerfile`) |
| Site container | `compose/resume-site/compose.yaml`, image `resume-site:vN` built on ikhaya |
| Tunnel connector | `compose/cloudflared/compose.yaml`; token in `compose/cloudflared/.env` (600, never committed) |
| Routes and DNS | Cloudflare dashboard: Networking → Tunnels → `ikhaya` → Routes (`anelehina.com`, `www`) |
| TLS | Cloudflare managed Universal certificate; nothing on ikhaya holds a certificate |
| Health endpoint | `https://anelehina.com/healthz` returns `ok` |
| Monitoring | Grafana Synthetic Monitoring check `resume-site` (Cape Town + London, every 2 min); host alert "ikhaya is silent" |

## Alerts

| Alert | Means | Go to |
|---|---|---|
| `ProbeFailedExecutionsTooHigh` (4 of 10 failed in 10 min) | Visitors can't load the site | [Site down](#site-down) |
| TLS certificate expires in under 14 days | Cloudflare's auto-renewal has not happened | [Certificate](#certificate-expiring) |
| "ikhaya is silent" at the same time | The whole server or its internet is down, not just the site | The host first: see the earlier postmortems in `docs/postmortems/` |

## Site down

Work from the outside in. Each step narrows where the break is.

1. **Is ikhaya itself up?** If "ikhaya is silent" is also firing, the site is not the problem: the server, its Wi-Fi, the router or the internet is. Fix that first.
2. **What does a visitor get?**
   ```bash
   curl -sI https://anelehina.com/healthz | head -3
   ```
   | Result | Meaning | Next |
   |---|---|---|
   | `200` | Working now (it recovered, or it was a probe-side blip) | Check Grafana; note it |
   | `502` | The tunnel is up, but nothing answers behind it | Step 3 (site container) |
   | `530` or a Cloudflare error 1033 page | Cloudflare can't find a running tunnel | Step 4 (cloudflared) |
   | No answer, DNS error | DNS or Cloudflare itself | Step 5 |
3. **Site container:**
   ```bash
   cd ~/ikhaya-platform/compose/resume-site
   sudo docker compose ps
   sudo docker compose logs --tail=30
   ```
   Not running or unhealthy: `sudo docker compose up -d`, then repeat step 2.
4. **Tunnel connector:**
   ```bash
   cd ~/ikhaya-platform/compose/cloudflared
   sudo docker compose ps
   sudo docker compose logs --tail=40 cloudflared | grep -iE 'registered|error|token'
   ```
   - Healthy: `Registered tunnel connection ... location=jnb...` lines.
   - `Provided Tunnel token is not valid`: the token in `.env` is wrong or was rotated. Copy the token from the Cloudflare tunnel page ("Run tunnel with Docker"), edit `.env` with `nano` (never paste it on the command line), then `sudo docker compose up -d --force-recreate`.
   - Not running: `sudo docker compose up -d`.
   - Both containers must be on the `edge` network: `sudo docker network inspect edge --format '{{range .Containers}}{{.Name}} {{end}}'` should list `cloudflared` and `resume-site`.
5. **Cloudflare:** check the tunnel shows **Healthy** in the dashboard, that both routes still point to `http://resume-site:8080`, and DNS has the two Tunnel records. Check [cloudflarestatus.com](https://www.cloudflarestatus.com).
6. **Confirm the fix** with step 2 and wait for the check to turn green and the "Resolved" email.

## Certificate expiring

Nothing to renew on ikhaya. In Cloudflare: anelehina.com → SSL/TLS → Edge Certificates. The Universal certificate should show **Active** and a new expiry date. If it is stuck, check the SSL/TLS mode is not Off and contact Cloudflare support.

## Release a new version

1. PR in `resume-site`. If `styles.css` or `theme.js` changed, bump `?v=N` in `site/index.html` to match the new image tag.
2. On ikhaya, after merging:
   ```bash
   cd ~/resume-site && git switch main && git pull
   sudo docker build -t resume-site:vN .
   cd ~/ikhaya-platform/compose/resume-site
   sed -i 's/image: resume-site:vOLD/image: resume-site:vN/' compose.yaml && grep image compose.yaml
   sudo docker compose up -d
   curl -s https://anelehina.com/healthz
   ```
3. Hard-refresh the site and check it. If the old CSS still shows, purge the Cloudflare cache (Caching → Configuration → Purge Everything).
4. PR in `ikhaya-platform` for the tag bump.

**Rollback:** set `compose.yaml` back to the previous tag (the old image is still on ikhaya: `sudo docker image ls resume-site`), `sudo docker compose up -d`, then fix forward with a PR.

## Drill

Proves the alert still reaches a person. Takes about 12 minutes of downtime; do it late at night.

```bash
cd ~/ikhaya-platform/compose/resume-site
date '+%H:%M:%S drill start'; sudo docker compose stop
# wait for the alert email (about 6 minutes)
date '+%H:%M:%S restore'; sudo docker compose start
curl -s https://anelehina.com/healthz
```

Last drill: 31 Oct 2026, outage to email in about 6 minutes (`docs/postmortems/2026-10-24-power-outages.md`).
