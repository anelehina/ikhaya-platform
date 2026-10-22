# Incident: home internet outage, 2026-10-22

**Severity:** Low (home lab; private services unreachable remotely) · **Duration:** about 14 h 20 min · **Status:** Resolved

## Summary
The home internet connection failed just before midnight and returned at about 14:21. ikhaya stayed powered on and connected to the home Wi-Fi throughout, but could not reach the internet, so Tailscale, Vaultwarden (remotely) and monitoring were unavailable. The "ikhaya is silent" alert fired within about 7 minutes. When the internet returned, ikhaya recovered automatically. No action was needed on the server.

## Timeline (SAST)
| Time | Event |
|---|---|
| ~00:00 | Home internet stops (provider issue). Wi-Fi stays up, with no route to the internet |
| 00:02:40 | Alert pending: no data from ikhaya |
| 00:07:40 | Alert firing, email sent |
| 08:16:17 | ikhaya loses the Wi-Fi link briefly (`Lost carrier`), likely a router restart |
| 08:16:54 | Link back and DHCP lease renewed, automatically (37 s) |
| ~14:21 | Internet restored by the provider |
| 14:22:40 | Alert resolved: ikhaya reporting again |

## Root cause
Outside the platform: the internet service provider's connection was down. Other home devices had Wi-Fi but no internet.

## What went well
- **Detection in about 7 minutes**, unattended, overnight (on 2026-10-19: about 12.5 hours, noticed by chance).
- **Automatic recovery.** No reboot (the same boot since 2026-10-19 18:34), and the Wi-Fi link recovered on its own after a brief drop. On 2026-10-19 the link never returned without a restart; the power-saving fix held.
- The read-only health check (`ansible/check.yml`) confirmed a clean state afterwards: `ok=13 failed=0`.

## What didn't go well
- From outside, an internet outage at home looks the same as a dead server. The alert answers "can I reach ikhaya?", not "why not?". Diagnosis needed the server's own logs afterwards.
- Remote access to Vaultwarden was unavailable for the whole outage; access relied on the phone app's cached vault.

## Action items
| Action | Status |
|---|---|
| None required on the server; no configuration change | - |
| Keep the phone's Bitwarden app logged in so the cached vault works offline | Already in place since 2026-10-19 |
| Consider a router UPS for load-shedding (see master plan sizing) | Optional |

## Comparison with 2026-10-19
| | 2026-10-19 (Wi-Fi power-saving) | 2026-10-22 (provider outage) |
|---|---|---|
| Time to detect | about 12.5 hours | about 7 minutes |
| Recovery | Manual restart | Automatic |
| Cause inside the platform? | Yes, fixed | No |