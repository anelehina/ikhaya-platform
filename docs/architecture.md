# Architecture

ikhaya is a single home server run like a small production platform. Nothing listens on the home router: private access goes through a Tailscale mesh VPN, and public traffic (later phases) will arrive through an outbound Cloudflare Tunnel.

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
        end
        subgraph Docker["Docker Engine + Compose"]
            VW["Vaultwarden 1.37.4<br/>127.0.0.1:8080"]
        end
        SRV[("/srv/vaultwarden<br/>bind mount")]
    end

    GH["GitHub<br/>ikhaya-platform<br/>protected main, PRs only"]

    Dell --> TS
    Phone --> TS
    TS -->|"WireGuard"| Tailscaled
    TS -->|"SSH"| SSHD
    Tailscaled -->|"HTTPS proxy"| VW
    VW --> SRV
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
        SRV[("/srv")]
    end

    GH["GitHub<br/>Actions: build, test, scan"] --> GHCR["GHCR images"]
    Argo -->|"pulls desired state"| GH
    SRV -->|"restic, encrypted, nightly"| S3["AWS S3 backups"]
    Probe["AWS uptime probe"] --> CF
```

## Design principles

| Principle | How it shows up |
|---|---|
| No inbound ports | Admin access over Tailscale only; public traffic via an outbound tunnel |
| Least exposure | Container ports bound to `127.0.0.1`, published to the tailnet with `tailscale serve` |
| Everything in Git | Changes land through branches and pull requests on a protected `main` |
| Secrets never in Git | `.gitignore`, GitHub push protection, uncommitted `.env` files with committed `.env.example` |
| Data separate from code | All state under `/srv`, bind-mounted; containers are disposable |
| Pinned versions | Images pinned to exact tags; upgrades are reviewed pull requests |

## Roadmap

| Phase | Theme | Status |
|---|---|---|
| 0 | Foundations: hardened host, Tailscale, Git workflow, Docker, Vaultwarden | Done |
| 1 | Host as code (Ansible), AdGuard DNS, restic backups with tested restores | Next |
| 2 | k3s and public edge through Cloudflare Tunnel, Cloudflare in Terraform | Planned |
| 3 | CI/CD and GitOps: GitHub Actions, image scanning, Argo CD | Planned |
| 4 | Observability: Prometheus, Grafana, SLOs, alerting | Planned |
| 5 | Disaster recovery drills on AWS | Planned |
| 6 | Kubernetes security hardening | Planned |