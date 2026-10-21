# ADR 0003: Ansible for host configuration, checks before changes

**Status:** Accepted · **Date:** 2026-10-21

## Context
ikhaya was configured by hand in Phase 0: SSH hardening, UFW, Docker, the Wi-Fi power-saving hook, the Alloy agent. Hand-built servers drift and can't be rebuilt reliably. Phase 1 makes the host reproducible from Git. There is one host, and it runs its own tooling.

## Decision
Use **Ansible** to describe and later manage the host:
- **ikhaya manages itself** with `ansible_connection=local`. No SSH keys or open ports are needed for Ansible. A second host would only need a new inventory line.
- **Checks before changes.** The first playbook (`check.yml`) is read-only: it asserts UFW, SSH hardening, Wi-Fi power-saving, core services and Vaultwarden health, and changes nothing. Playbooks that change the host come next, run with `--check --diff` first.
- **Privilege escalation through `sudo.ws`.** Ubuntu 26.04's default sudo is **sudo-rs**, which wraps Ansible's become prompt, so Ansible times out waiting for it. `become_exe = sudo.ws` uses the classic sudo shipped alongside. The become password is entered at a prompt (`-K`), never on the command line.
- Ansible comes from **Ubuntu's repository** (core 2.20.1), patched with the rest of the system.

## Alternatives considered
| Option | Why not |
|---|---|
| Shell scripts | Not idempotent; no built-in check mode or clear report of what changed |
| Ansible over SSH to itself | Extra keys and SSH config for no benefit on a single host |
| Passwordless sudo for Ansible | Removes a security layer to save typing one password |
| Ansible from pip / pipx | Newer, but outside Ubuntu's security updates; not needed yet |

## Consequences
- **Positive:** one command (`ansible-playbook check.yml -K`) proves the host matches its intended state; used as the after-update test on 2026-10-21 (23 packages upgraded, `failed=0`). Drift becomes visible, and the playbooks become the rebuild instructions.
- **Negative:** a password prompt on every run (acceptable for manual runs; scheduled runs will need a different approach later). The `sudo.ws` workaround should be revisited when Ansible handles sudo-rs prompts natively.