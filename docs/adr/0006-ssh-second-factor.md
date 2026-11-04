# ADR 0006: A second factor for SSH

**Status:** Accepted · **Date:** 2026-11-04

## Context
SSH to ikhaya already needs a private key and is reachable only over the tailnet (plus a break-glass rule from the home LAN). A stolen or copied key, from a lost laptop or phone, would still be enough on its own. A second, independent factor closes that gap.

## Decision
- SSH requires **both** a key **and** a time-based one-time code (TOTP): `AuthenticationMethods publickey,keyboard-interactive`.
- Codes come from `pam_google_authenticator` via PAM. The SSH PAM stack no longer asks for the account password (`@include common-auth` disabled for `sshd` only); `sudo` and the local console are unchanged.
- The TOTP secret lives only in the user's home folder (mode 400) and the authenticator app. Emergency codes are kept in the password manager's recovery kit, never in Git.
- `host.yml` refuses to change SSH until the secret exists, validates every SSH config change with `sshd -t` before reloading, and keeps backups of the files it edits. `check.yml` asserts the result.

## Alternatives considered
| Option | Why not |
|---|---|
| Hardware security keys (`ed25519-sk`) | Strongest option, but needs a FIDO2 key for every device, and the phone SSH client doesn't support it |
| Tailscale SSH with check mode | Moves SSH authentication to Tailscale; keeps fewer layers on the host itself |
| Key only (status quo) | One stolen key is enough |

## Consequences
- **Positive:** a stolen key alone can't log in; the change is codified, validated and asserted.
- **Negative:** every new SSH connection asks for a code, including VS Code Remote-SSH reconnects. Losing the authenticator app means using an emergency code; losing both means the local console.
- Automation is unaffected: Ansible runs locally on ikhaya, and the scheduled health check doesn't use SSH.
