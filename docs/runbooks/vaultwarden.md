# Runbook: Vaultwarden

Self-hosted password manager (Bitwarden-compatible). Private to the tailnet only.

## Overview

| Item | Value |
|---|---|
| Image | `vaultwarden/server` (pinned tag in `compose/vaultwarden/compose.yaml`) |
| Listens on | `127.0.0.1:8080` (host only) |
| Exposed via | `tailscale serve` on HTTPS 443, tailnet only |
| Data | `/srv/vaultwarden` (bind mount, `chmod 700`) |
| Config | `compose/vaultwarden/.env` (not in Git, `chmod 600`); template in `.env.example` |
| Signups | Disabled; invitations disabled; admin panel not enabled |
| Monitoring | Host covered by the "ikhaya is silent" alert in Grafana Cloud |

All commands below run on ikhaya from the `compose/vaultwarden` folder of the repo clone.

## Health check

```bash
sudo docker compose ps                     # STATUS should be "Up"
curl -fsS http://127.0.0.1:8080/alive      # returns a timestamp if the app is healthy
tailscale serve status                     # shows HTTPS 443 proxying to 127.0.0.1:8080
```

## Logs

```bash
sudo docker compose logs --tail=100 vaultwarden
sudo docker compose logs -f vaultwarden    # follow live, Ctrl+C to stop
```

## Start, stop, restart

```bash
sudo docker compose up -d       # start (or apply config changes)
sudo docker compose stop        # stop, keep container
sudo docker compose restart     # restart
```

## Upgrade

Upgrades are a pull request, never `:latest`.

1. Read the release notes for the new version on GitHub (`dani-garcia/vaultwarden`).
2. Take a manual backup (below).
3. On a branch, change the image tag in `compose.yaml`; open a PR, squash and merge.
4. On ikhaya:
```bash
   git switch main && git pull
   sudo docker compose pull
   sudo docker compose up -d
```
5. Verify with the health check and by logging in from a client.
6. Remove the old image: `sudo docker image prune`.

**Rollback:** revert the PR, `git pull`, then `sudo docker compose up -d`. If the new version migrated the database, restore the backup from step 2.

## Manual backup

Until automated encrypted backups (restic) are in place:

```bash
sudo docker compose stop
sudo tar -czf ~/vaultwarden-$(date +%F).tar.gz -C /srv vaultwarden
sudo docker compose start
chmod 600 ~/vaultwarden-*.tar.gz
```

The archive contains the database and the server's private keys. Treat it as a secret. A copy on the same disk is not a backup; it only protects against bad upgrades.

Off-host safety net: a monthly **encrypted** vault export (`.json (Encrypted)`) from the web vault, stored in personal cloud storage.

## Restore

```bash
sudo docker compose stop
sudo mv /srv/vaultwarden /srv/vaultwarden.broken-$(date +%F)
sudo tar -xzf ~/vaultwarden-YYYY-MM-DD.tar.gz -C /srv
sudo chmod 700 /srv/vaultwarden
sudo docker compose up -d
```

Verify with the health check and a client login, then delete the `.broken` folder.

## Adding a user (rare)

1. Set `VW_SIGNUPS_ALLOWED=true` in `.env`, then `sudo docker compose up -d`.
2. Register the account from the web vault.
3. Set it back to `false`, then `sudo docker compose up -d`.
4. Confirm a new signup is refused.

## Troubleshooting

| Symptom | Likely cause | Check / fix |
|---|---|---|
| Client says "Unable to resolve host" | Tailscale off on the device, or URL typo | Turn Tailscale on; compare the server URL with `.env` |
| Browser gets 502 / connection refused | Container down | `sudo docker compose ps`, then logs |
| Container keeps restarting | Bad config or permissions on `/srv/vaultwarden` | Logs; `ls -ld /srv/vaultwarden` |
| Works on tailnet, but not after reboot | Docker or `tailscale serve` not started | `systemctl status docker`; `tailscale serve status` |
| Whole host unreachable | Network or power | Grafana alert should have fired; see the [Wi-Fi postmortem](../postmortems/2026-10-19-wifi-outage.md) |
