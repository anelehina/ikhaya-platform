# Postmortem: 24-25 Oct 2026 power outages, the Wi-Fi race, and the first site drill

- **Status:** Resolved
- **Author:** Anele Hina
- **Related:** PR #12 (Wi-Fi race fix), PR #14 (site live), earlier postmortems `2026-10-19-wifi-outage.md` and `2026-10-22-isp-outage.md`

## Summary

Two outages on 24-25 October took ikhaya offline for about 8 hours and then about 17.5 hours. The first was a power cut that outlasted the laptop's battery; the second, starting 11 minutes after it booted again, was mainly the home internet not recovering after the power cut. The Grafana "ikhaya is silent" alert fired and cleared each time. After the restart, the read-only health check (`check.yml`) failed: Wi-Fi power-saving was back on, the setting behind the 19 October outage. The cause was a boot-time race between `networkd-dispatcher` and the kernel renaming the Wi-Fi card. It was fixed with a systemd drop-in plus a timer and proved with a reboot (PR #12).

On 31 October, after the resume site went live, a planned drill proved that the new external uptime check detects an outage of the public site and emails within minutes.

## Impact

- ikhaya, and everything on it (Vaultwarden over Tailscale, monitoring data), was unreachable during each outage.
- The resume site was not public yet, so no visitors were affected.
- No data was lost.

## Timeline (SAST)

From Grafana **Alerting → History** ("ikhaya is silent": Normal → Pending → Firing → Normal) and `journalctl --list-boots` on ikhaya.

| Time | Event |
|---|---|
| 24 Oct ~13:01 | Power cut. ikhaya stops sending metrics; the laptop keeps running on battery |
| 24 Oct 13:02:40 | Alert pending |
| 24 Oct 13:07:40 | Alert **firing**, email sent |
| 24 Oct 17:53:14 | Last journal entry of that boot: the battery runs out and the laptop goes off (about 4 h 50 min on battery) |
| 24 Oct 21:18:02 | Power back; ikhaya boots |
| 24 Oct 21:19:40 | Alert **resolved** (outage 1: about 8 h 17 min) |
| 24 Oct 21:22-21:23 | Short "Saturation" (CPU) warning while services start after boot; cleared by itself |
| 24 Oct 21:30:40 | Alert pending again, 11 minutes after recovery |
| 24 Oct 21:35:40 | Alert **firing** |
| 25 Oct 15:00:40 | Alert **resolved** (outage 2: about 17 h 30 min). The laptop did not reboot in between |
| 25 Oct | `check.yml` fails: Wi-Fi power-saving **on** since the 21:18 boot |
| 25 Oct 19:24 | Cause found (boot race); drop-in + timer added; **planned** reboot test (19:24:04 to 19:24:13) passes; PR #12 merged (`88ba032`) |

## Root cause

**Outage 1 (24 Oct, ~8 h):** a utility power cut, and there is no UPS. The laptop ran on battery for about 4 h 50 min while the router was down, then switched off at 17:53. It booted when power returned at 21:18.

**Outage 2 (24-25 Oct, ~17.5 h): mainly an upstream internet outage, not the Wi-Fi race.** The evidence from the journal of that boot:

- **21:31:30:** the Wi-Fi race happened. `networkd-dispatcher` ran the power-saving hook against `wlan0` and failed (`Interface "wlan0" not found`), so power-saving stayed on. But at the same second the Wi-Fi link connected, got its address and gateway, and Tailscale rebound to it.
- **21:45 to 14:58:** the router's multicast packets kept arriving (370 logged by UFW, against roughly 500 expected at one every ~2 minutes). So the Wi-Fi link to the router was up for most of the outage, yet no data reached Grafana: the router had no internet. This matches the 22 October provider outage, here most likely the line not recovering after the power cut.
- **About 4 hours without router messages** fall somewhere in that window, so the link or the router was also down for part of it. Exactly when is not pinned down.
- **14:56-14:57:** the Wi-Fi re-authenticated and reconnected; **14:58:39** Tailscale reached its relay again; **15:00:40** the alert resolved.

Conclusion: the race was real and is fixed (PR #12), but the evidence does not show it caused this outage. The power cut's aftermath upstream did.

**The Wi-Fi race:** at boot the Wi-Fi card appears as `wlan0`, and udev then renames it to `wlp2s0`. On this boot `networkd-dispatcher` started before the rename, so the hook that turns power-saving off targeted `wlan0`, a name that no longer existed. Power-saving stayed on. It only happens when the timing goes the wrong way, which is why it hid since 19 October.

## Detection

- **Outages:** the "ikhaya is silent" dead man's switch (no metrics for 5 minutes), by email. Detected in minutes, compared with 12.5 hours on 19 October.
- **Wi-Fi race:** `check.yml`, run by hand after the restart. Nothing alerted on it automatically.

## Resolution

- `ansible/files/networkd-dispatcher-after-wifi.conf`: a drop-in that makes `networkd-dispatcher` start only after `sys-subsystem-net-devices-wlp2s0.device` exists (`After=` and `Wants=`).
- `wifi-powersave-off.service` and `.timer`: re-apply power-saving off 1 minute after boot, then every 5 minutes, as a safety net.
- Both are installed by `host.yml` and asserted by `check.yml`.
- Proof: a reboot showed power-saving off and zero `wlan0` errors in the journal.

## The 31 Oct drill: external uptime check

A Grafana Synthetic Monitoring HTTP check now probes `https://anelehina.com/healthz` from Cape Town and London every 2 minutes. It expects `200`, HTTPS, and a body starting with `ok`. It alerts when 4 of 10 runs fail within 10 minutes, and when the certificate has fewer than 14 days left. Alerts route to email (`namespace = synthetic_monitoring` policy).

| Time | Event |
|---|---|
| about 22:41 | `docker compose stop` on `resume-site` (drill start) |
| about 22:42 | First failed run; both probes (Cape Town and London) report errors |
| 22:47 | Alert email received: "ProbeFailedExecutionsTooHigh [10m] ... has failed 4 times in the last 10m" |
| 22:48:26 | `docker compose start` (restore); `curl https://anelehina.com/healthz` returns `ok` at once |
| 22:57 | Checks green again; "Resolved" email received (failures aged out of the 10-minute window; about 9 minutes after the restore) |

Result: about **6 minutes** from outage to email, and the site served again within seconds of the restart, and the alert cleared about 9 minutes later. The probes also gave a baseline: Cape Town about 200 ms, London about 540 ms, and most of each request is "processing" (the trip through the tunnel to the laptop), not TLS or DNS.

## What went well

- The dead man's switch caught both power outages, as it caught the 22 October provider outage.
- ikhaya recovered without a manual restart.
- Running `check.yml` after an unusual event found a silent regression before it caused an outage.
- The fix went through a PR with a reboot test, the same as any other change.

## What went wrong

- No UPS: a power cut takes ikhaya and/or the router down.
- The original 19 October fix assumed the interface name was always ready; it was not tested against boot ordering.
- `check.yml` only runs when started by hand, so a drift like this could sit unnoticed.

## Action items

| Action | Status |
|---|---|
| Fix the boot race (drop-in) and add a timer safety net | Done (PR #12) |
| External uptime and certificate check for the public site, with a drill | Done (31 Oct) |
| UPS for the router (keeps the network up through short cuts; would not fix a provider outage) | Open |
| Check the laptop battery's health (it did not ride out the 24 Oct cut) | Open |
| Run `check.yml` on a schedule and alert on failure | Open |
| Short runbook `docs/runbooks/resume-site.md`, linked from the check's alerts | Open |

## Lessons

- A fix that works on one boot can fail on the next; boot ordering needs to be stated, not assumed.
- Check the evidence before naming a cause. The race was the obvious suspect for outage 2; the journal showed the link was up and the internet was not.
- Run the health check after every unusual event, not only after changes.
- Fix the cause, then add a safety net for the causes you have not thought of.
- An alert only counts once a drill has proved it reaches a person.
