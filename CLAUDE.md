# Homelab Journey — Agent Instructions

Proxmox homelab (Terraform + Ansible + K3s). Not for heavy production: unstable power/internet in Cambodia. See `README.md` and `terraform/README.md`.

## Related Repositories

This project is one of four sibling repos that together make up the platform. Each repo's agent instructions should know about the others; keep this section in sync across all four when paths or responsibilities change.

```
Client -> Cloudflare (DNS + Tunnel)   [tfdevs-infra]
       -> Gateway VM (Nginx Proxy Manager)   [tfdevs-infra proxy hosts, VM from homelab-journey]
       -> K3s Ingress   [homelab-journey]
       -> tfd-blog-next (SSR)  <->  tfd-api-next (API)
```

| Role | Repo | Path | Contents |
|---|---|---|---|
| Frontend | `tfd-blog-next` | `/Users/kimang/Documents/ProgrammingProjects/tfd-blog-next` | Nuxt SSR app (tfdevs.com, dev.tfdevs.com) |
| Backend | `tfd-api-next` | `/Users/kimang/Documents/ProgrammingProjects/tfd-api-next` | NestJS API (api.tfdevs.com, api-dev.tfdevs.com) |
| Infra (this repo) | `homelab-journey` | `/Users/kimang/Documents/ProgrammingProjects/homelab-journey` | Proxmox VMs (Terraform), Ansible playbooks, K3s cluster, monitoring, databases, MinIO, n8n |
| Cloud config | `tfdevs-infra` | `/Users/kimang/Documents/ProgrammingProjects/tfdevs-infra` | Terraform for Cloudflare DNS/Zero Trust tunnels and Nginx Proxy Manager proxy hosts (S3 state backend) |

When a task touches another repo's responsibility, read that repo (read-only investigation is always fine) before guessing, and follow **that repo's** own `CLAUDE.md` for any change made there. Look at:

- `tfd-blog-next` — the Nuxt SSR app that runs on the K3s cluster; its `k8s/` manifests and deploy workflows define what the cluster must provide.
- `tfd-api-next` — the NestJS API that runs on the K3s cluster and uses the database VM and MinIO; its `k8s/` manifests and `docker-compose.yml` list the services it needs.
- `tfdevs-infra` — Cloudflare DNS/tunnels and Nginx Proxy Manager host definitions that front the VMs and services provisioned here. Changing a VM IP or service port here usually requires updating the proxy hosts there.

Cross-repo changes: state clearly which repo needs which change, make them in dependency order (infra/cloud config -> backend -> frontend), and never commit to a sibling repo unless asked.
