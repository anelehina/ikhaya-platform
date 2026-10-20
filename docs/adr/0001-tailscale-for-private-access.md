# ADR 0001: Tailscale for all private access

**Status:** Accepted · **Date:** 2026-10-16

## Context
ikhaya is a home server behind a router I don't control. I can't open ports or set static leases. I need secure remote access to SSH and private services (password manager, later dashboards) from my laptop and phone, from any network.

## Decision
All private access goes through **Tailscale**, a WireGuard-based mesh VPN:
- SSH and private services are reachable only over the tailnet.
- UFW denies all inbound traffic except on the `tailscale0` interface (plus SSH from the home LAN as break-glass).
- Private web services are bound to `127.0.0.1` and published to the tailnet with `tailscale serve` (HTTPS, tailnet-only).
- Devices are addressed by MagicDNS name, not IP.
- Device key expiry is disabled for the server, laptop and phone, so nothing drops off the tailnet unexpectedly.

## Alternatives considered
| Option | Why not |
|---|---|
| Port forwarding on the router | No router access; exposes services to the internet |
| Self-hosted WireGuard | Needs an open port; more to maintain |
| Cloudflare Tunnel for private services | Better suited to public traffic; Tailscale gives device-level identity for admin access |

## Consequences
- **Positive:** zero inbound ports on the home network; encrypted access from anywhere; identity-based (only my logged-in devices).
- **Negative:** services are unreachable when Tailscale is off on a device, and some corporate networks (for example those with Fortinet firewalls) block Tailscale traffic. A personal hotspot is the agreed workaround; corporate controls are never bypassed.
- Public services (later phases) will use Cloudflare Tunnel instead, keeping public and private paths separate.
