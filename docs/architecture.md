# Architecture

ikhaya is a single home server run like a small production platform. Nothing listens on the home router: private access goes through a Tailscale mesh VPN, monitoring data is pushed out to Grafana Cloud, and public traffic (later phases) will arrive through an outbound Cloudflare Tunnel.

## Current state

```mermaid
flowchart LR
    subgraph Devices["My devices"]
        Dell["Workstation<br/>VS Code Remote-SSH"]
        Phone["Phone<br/>Termius + Bitwarden"]
    end

    TS["Tailscale tailnet<br/>WireGuard mesh, MagicDNS,<br/>HTTPS certificates"]

    subgraph Ikhaya["ikhaya - Ubuntu Server 26.04"]
        direction TB
        subgraph Host["Host layer"]
            Tailscaled["tailscaled<br/>serve :443"]
            SSHD["sshd<br/>keys only, no root"]
            UFW["UFW<br/>deny inbound,<br/>allow tailscale0"]
            Alloy["Grafana Alloy<br/>metrics + journal"]
        end
        subgraph Docker["Docker Engine + Compose"]
            VW["Vaultwarden<br/>127.0.0.1:8080"]
        end
        SRV[("/srv/vaultwarden<br/>bind mount")]
    end

    subgraph GC["Grafana Cloud (EU)"]
        Prom["Prometheus<br/>metrics"]
        Loki["Loki<br/>logs"]
        Alert["Alert: no data 5 min"]
    end

    GH["GitHub<br/>ikhaya-platform<br/>protected main, PRs only"]
    Email["Email alert"]

    Dell --> TS
    Phone --> TS
    TS -->|"WireGuard"| Tailscaled
    TS -->|"SSH"| SSHD
    Tailscaled -->|"HTTPS proxy"| VW
    VW --> SRV
    Alloy -->|"push, write-only token"| Prom
    Alloy -->|"push"| Loki
    Prom --> Alert --> Email
    Ikhaya -->|"git over SSH"| GH
```

## Target state (later phases)

```mermaid
flowchart LR
    Visitors["Internet visitors"] --> CF["Cloudflare<br/>DNS, TLS, WAF, geo rules"]
    CF <-.->|"outbound tunnel"| CFD["cloudflared"]

    subgraph Ikhaya["ikhaya"]
        subgraph K3s["k3s"]
            Argo["Argo CD"]
            CFD
            Resume["Resume site"]
            Funnel["Funnel"]
        end
        subgraph Compose["Docker Compose"]
            VW["Vaultwarden"]
            AG["AdGuard Home"]
        end
        Alloy["Grafana Alloy"]
        SRV[("/srv")]
    end

    GH["GitHub<br/>Actions: build, test, scan"] --> GHCR["GHCR images"]
    Argo -->|"pulls desired state"| GH
    SRV -->|"restic, encrypted, nightly"| S3["AWS S3 backups"]
    Alloy -->|"metrics, logs"| GC["Grafana Cloud<br/>dashboards, SLOs, alerts"]
```

## Design principles

| Principle | How it shows up |
|---|---|
| No inbound ports | Admin access over Tailscale only; monitoring pushes out; public traffic via an outbound tunnel |
| Least exposure | Container ports bound to `127.0.0.1`, published to the tailnet with `tailscale serve` |
| Least privilege | Monitoring token can only write data; root never used day to day |
| Everything in Git | Changes land through branches and pull requests on a protected `main` |
| Secrets never in Git | `.gitignore`, push protection, uncommitted `.env` files and root-owned credential files |
| Data separate from code | All state under `/srv`, bind-mounted; containers are disposable |
| Pinned versions | Images pinned to exact tags; upgrades are reviewed pull requests |
| Prove it, don't assume it | Fixes verified after reboot; alerts tested with outage drills |

## Operations

| Area | Where |
|---|---|
| Decisions | [Architecture Decision Records](adr/) |
| Incidents | [Postmortems](postmortems/), starting with the [2026-10-19 Wi-Fi outage](postmortems/2026-10-19-wifi-outage.md) |
| Monitoring | Grafana Cloud: host metrics, system logs, "ikhaya is silent" alert (~10 min detection, drill-tested) |

## Roadmap

| Phase | Theme | Status |
|---|---|---|
| 0 | Foundations: hardened host, Tailscale, Git workflow, Docker, Vaultwarden | Done |
| 1 | Host as code (Ansible), AdGuard DNS, restic backups with tested restores | In progress |
| 2 | k3s and public edge through Cloudflare Tunnel, Cloudflare in Terraform | Planned |
| 3 | CI/CD and GitOps: GitHub Actions, image scanning, Argo CD | Planned |
| 4 | Observability: Grafana Cloud foundation **live**; dashboards, SLOs and service checks next | Started |
| 5 | Disaster recovery drills on AWS | Planned |
| 6 | Kubernetes security hardening | Planned |
