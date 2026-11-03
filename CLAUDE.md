# Homelab Journey — Agent Instructions

Proxmox homelab (Terraform + Ansible + K3s). Not for heavy production: unstable power/internet in Cambodia. See `README.md` and `terraform/README.md`.

## Starting a session

Other Claude sessions may be using this checkout at the same time. A session therefore works on its **own branch in its own git worktree**, cut from a fresh `origin/master`, and never changes a checkout it did not create. Do this before the first edit and without waiting to be asked, unless the user is continuing a named branch or pull request (then use that branch's worktree, or create one for it).

1. `git fetch origin`.
2. `git worktree add ../worktrees/<repo>-<short-name> -b <type>/<short-name> origin/master` (`<type>` is `feat`, `fix`, `docs` or `chore`). Work, commit and push from that folder. Reuse the main checkout's `node_modules` with a symlink instead of installing again.
3. In the main checkout never run `git switch`, `checkout`, `pull`, `stash`, `reset` or `clean`, and never discard or overwrite files there: its uncommitted changes may be another session's work. Read it freely.
4. A dirty or stale main checkout can show files that are already merged as modified or untracked. Compare against `origin/master` (`git diff origin/master -- <file>`) before treating them as unfinished work.
5. Never commit to `master` directly; open a pull request to `master` (this repo has no `develop`). Remove the worktree (`git worktree remove`) once the pull request is merged.

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
