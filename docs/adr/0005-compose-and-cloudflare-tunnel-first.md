# 0005: Docker Compose and a Cloudflare Tunnel before k3s

- Status: Accepted
- Date: 2026-10-31

## Context
The resume site needed to be public by the end of October. The long-term plan
is k3s, but building a cluster first would delay launch by weeks. ikhaya sits
on a home connection: no static IP, and opening router ports would expose the
home network.

## Decision
- Run the site with Docker Compose, using the same hardened container
  (non-root nginx, read-only filesystem, all capabilities dropped,
  no-new-privileges, healthcheck, pinned tags).
- Publish it through a Cloudflare Tunnel. `cloudflared` runs as a container,
  dials out to Cloudflare, and reaches the site over a private Docker network
  (`edge`). No inbound ports are opened on the router or the host.
- TLS terminates at Cloudflare with a managed, auto-renewing certificate.
  Always Use HTTPS, HSTS (starting at 1 month, no preload), minimum TLS 1.2,
  and DNSSEC are on.
- The tunnel token lives only in an untracked `.env` (mode 600). It is never
  committed or passed on the command line.

## Consequences
- Good: live in a day; home IP never appears in DNS; no certificates to renew
  on the server; the containers move to k3s unchanged later.
- Good: two tunnel connections to separate Johannesburg data centres.
- Trade-off: Cloudflare is now in the path. If Cloudflare or the tunnel is
  down, so is the site. Monitored by an uptime and certificate-expiry check.
- Trade-off: routes are configured in the dashboard, not in Git. Revisit with
  Terraform when the Cloudflare provider is added.

## Alternatives considered
- Port forwarding plus certbot: exposes the home IP and network, and needs
  certificate renewals on the host.
- k3s first: correct end state, but blocks the launch date.
- Tailscale Funnel: works, but ties the public site to the tailnet.
