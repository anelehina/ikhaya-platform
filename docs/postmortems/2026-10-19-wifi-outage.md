# Postmortem: ikhaya offline for ~13 hours (silent Wi-Fi link failure)

**Date:** 2026-10-19 · **Severity:** Medium (private services only) · **Status:** Resolved

## Summary
ikhaya's Wi-Fi link failed silently while the host kept running. It first stopped sending, then stopped receiving, and the DHCP lease expired. The host lost its IP address and Tailscale connectivity, so all private services (SSH, Vaultwarden) were unreachable for about 13 hours. Nothing alerted; the outage was found when the vault wouldn't load.

## Impact
- SSH and Vaultwarden unavailable from 21:33 on 18 Oct to 10:31 on 19 Oct (~13 hours).
- No data loss. No public services affected (none exist yet).

## Timeline (SAST)
| Time | Event |
|---|---|
| 18 Oct 21:33 | First failure: Tailscale connectivity checks start failing (link degrading) |
| 18 Oct 21:33-22:15 | Half-alive link: router broadcasts still received, outbound failing |
| 18 Oct 22:05 | Tailscale control connection failing completely |
| 18 Oct ~22:15 | Router broadcasts stop arriving: link fully dead |
| 18 Oct 23:19 | `wlp2s0: DHCP lease lost`, renewal failed; no IP address |
| 19 Oct ~09:58 | Detected: password app and SSH time out from phone |
| 19 Oct 10:24 | Host confirmed running at the console; home Wi-Fi working for other devices |
| 19 Oct 10:30 | Clean restart (short power-button press); service restored 10:31 |

## Root cause
Wi-Fi power-saving was enabled on the Qualcomm Atheros QCA9377 adapter (`ath10k_pci` driver), which is known to be unreliable on Linux. The link degraded without any driver error, disconnect or reconnect being logged, which rules out a router reboot. DHCP renewal then failed and the host never recovered on its own.

## What went well
- Diagnosis from a phone over Termius in under 30 minutes.
- Previous-boot logs (`journalctl -b -1`) survived the restart and pinned down the timeline.
- A clean restart avoided any data risk.

## What went wrong
- No monitoring: ~13 hours undetected.
- No self-recovery from a dead Wi-Fi link.
- Password app was logged out, so there was no offline copy of the vault.

## Actions
| Action | Status |
|---|---|
| Disable Wi-Fi power-saving on every link-up (`networkd-dispatcher` hook, `ansible/files/50-wifi-powersave-off`) | Done, verified after reboot and after reconnect |
| Grafana Cloud + Grafana Alloy: host metrics and system logs shipped off-host (`ansible/files/config.alloy`, secrets kept outside Git) | Done |
| Alert "ikhaya is silent": no data for 5 minutes, email notification | Done |
| Outage drill (Wi-Fi down 15 min): alert fired after ~10 min, resolved within 1 min of recovery | Passed |
| Stay logged in to the Bitwarden app so the vault works offline | Done |
| Watch 7 days; if it recurs, move to a wired connection or add a network watchdog | Open |

## Detection, before and after
| | Before | After |
|---|---|---|
| Time to detect | ~12.5 hours (by chance) | ~10 minutes (automatic) |
| How | Password app failed | Email alert |