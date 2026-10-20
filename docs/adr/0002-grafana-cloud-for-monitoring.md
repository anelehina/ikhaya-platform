# ADR 0002: Grafana Cloud for monitoring and alerting

**Status:** Accepted · **Date:** 2026-10-19

## Context
On 2026-10-18/19 ikhaya was offline for about 13 hours after a silent Wi-Fi failure, and nothing alerted ([postmortem](../postmortems/2026-10-19-wifi-outage.md)). The host is private (no inbound access), so an external service cannot probe it, and a monitor running on the host cannot report its own outage.

## Decision
Use the **Grafana Cloud free tier** with the **Grafana Alloy** agent on ikhaya:
- Alloy **pushes** host metrics (Prometheus format) and system logs (Loki) to Grafana Cloud. No inbound ports needed.
- A **"no data" alert** acts as a dead man's switch: if ikhaya stops reporting for 5 minutes, for any reason, an email is sent.
- The agent uses a **write-only** access token (metrics:write, logs:write) with a 1-year expiry; credentials live in a root-owned file outside Git.
- Stack hosted in the **EU (Ireland)** region for GDPR-level data protection and proximity.

## Alternatives considered
| Option | Why not |
|---|---|
| Self-hosted Prometheus + Grafana only | Dies with the host, so can't alert on a host outage. Planned later as the "inside" view |
| Datadog free tier | 1-day metric retention, no logs included |
| Splunk Free | No alerting, no authentication, heavy to run |
| Healthchecks.io heartbeat only | Detects outages but gives no metrics or logs for diagnosis |

## Consequences
- **Positive:** outages detected in about 10 minutes (validated by an outage drill: alert after ~10 min, resolved within 1 min); logs readable from anywhere, even when the host is down; industry-standard skills (PromQL, LogQL, Grafana alerting).
- **Negative:** monitoring data leaves the home network (mitigated: no secrets or application data sent; system logs only). Free-tier limits apply (10k series, 50 GB logs/month, 14-day retention).
- **Rule that follows:** secrets must never be typed on a command line, because `sudo` commands are recorded in the system journal, which is now shipped off-host.
