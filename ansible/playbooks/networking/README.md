# Networking Playbooks

Network configuration, remote access, and tunnel setup.

## Playbooks

### cloudflare-tunnel-setup.yml
**Purpose:** Setup Cloudflare Tunnel for secure remote access to Proxmox  
**Target:** proxmox-host (192.168.100.50)  
**Usage:** `ansible-playbook playbooks/networking/cloudflare-tunnel-setup.yml`

**Installs:**
- Cloudflare cloudflared daemon
- Adds Cloudflare APT repository
- Configures system service

**Post-installation manual steps:**
```bash
# 1. Authenticate with Cloudflare
cloudflared tunnel login

# 2. Create tunnel
cloudflared tunnel create homelab-tunnel

# 3. Create config file
sudo nano /etc/cloudflared/config.yml

# 4. Route DNS
cloudflared tunnel route dns homelab-tunnel ssh.yourdomain.com

# 5. Start service
sudo systemctl enable --now cloudflared
```

**Use case:** Access homelab from coffee shops, work, or anywhere via Cloudflare's network.

---

### database-firewall.yml

Restricts who can reach the database VM's Docker-published ports (Mongo 27017, Redis 6379, Postgres 5432, exporters 9121/9187/9216). UFW cannot do this for Docker ports, so it uses the `DOCKER-USER` chain via a dedicated `DB-FIREWALL` chain and the `db-firewall` systemd unit.

- Allowed on the data ports: K3s nodes, monitoring VM, n8n VM, plus `db_firewall_extra_sources`. Exporter ports: monitoring VM only.
- Two steps. `db_firewall_mode=log` (default) only logs what it would block (`journalctl -k | grep "DBFW would-block"`); add every legitimate client to `db_firewall_extra_sources`, watch a few days, then re-run with `-e db_firewall_mode=enforce`.
- Established connections always pass, so changing the mode never cuts a live connection.
- Roll back: `-e db_firewall_state=absent`, or `sudo systemctl disable --now db-firewall` on the VM.

```bash
ansible-playbook playbooks/networking/database-firewall.yml --check --diff   # dry run
ansible-playbook playbooks/networking/database-firewall.yml                  # log only
ansible-playbook playbooks/networking/database-firewall.yml -e db_firewall_mode=enforce
```

### k3s-nodeport-firewall.yml

Only the gateway VM (and a few listed hosts) may open connections to the K3s ingress NodePorts (30389 http, 31943 https). Without it any LAN host can call the NodePort directly and choose its own `CF-Connecting-IP`, and with it its own rate-limit bucket: kube-proxy rewrites the source of NodePort packets, so the ingress cannot tell it from the gateway. Filtering in the `raw` table (before conntrack and NAT) sees the real source. Pod traffic and everything else on the node are untouched.

- Runs on every K3s node (`hosts: k8s`). Allowed: gateway VM, K3s nodes, monitoring VM (Prometheus `ingress-nodeport` probe on worker-1:30389), plus `np_firewall_extra_sources`. It refuses to run if the gateway is not allowed.
- Two steps. `np_firewall_mode=log` (default) only logs (`journalctl -k | grep "K3SNP would-block"`); add every legitimate client, watch several days, then `-e np_firewall_mode=enforce`. Roll out one node first (`--limit k8s-worker-1` receives the public traffic).
- Roll back with `-e np_firewall_state=absent`, or on a node `systemctl disable --now k3s-nodeport-firewall`.
- Background: `tfd-blog-next/docs/RATE_LIMIT_PROXY_INVESTIGATION_2026-10-17.md`.

### github-runner-setup.yml
**Purpose:** Setup GitHub Actions self-hosted runner (legacy/standalone)  
**Target:** Typically ci-cd VM  
**Usage:** `ansible-playbook playbooks/networking/github-runner-setup.yml`

**Note:** This is a legacy/alternative playbook. For full CI/CD setup, use:
- `../services/cicd-setup.yml` (comprehensive setup including registry, kubectl, helm)

**Installs:**
- GitHub Actions runner binary
- Runner user and permissions
- Docker access
- Service configuration

**When to use:**
- Standalone runner setup without CI/CD infrastructure
- Alternative to cicd-setup.yml for specific use cases

## Comparison: github-runner-setup.yml vs cicd-setup.yml

| Feature | github-runner-setup.yml | cicd-setup.yml |
|---------|------------------------|----------------|
| GitHub Actions Runner | ✅ | ✅ |
| Docker Registry | ❌ | ✅ (with Nginx proxy) |
| kubectl + helm | ❌ | ✅ |
| Build tools | Basic | Comprehensive |
| Registry hostname | ❌ | ✅ (registry.homelab.local) |
| Kubeconfig | Manual | Auto-configured |
| **Recommended** | Niche cases | **Production use** |

## Remote Access Options

Your homelab supports multiple remote access methods:

1. **Cloudflare Tunnel** (Zero Trust, recommended)
   - No open ports required
   - Built-in authentication
   - Free tier available
   - Playbook: `cloudflare-tunnel-setup.yml`

2. **VPN** (Traditional, not covered here)
   - WireGuard (fast, modern)
   - Tailscale (mesh VPN, easy)
   - OpenVPN (mature, widely supported)

3. **Port Forwarding** (Not recommended for security)
   - Direct port exposure
   - Requires firewall rules
   - Security risk if not properly configured

## Helper Scripts

```bash
# Cloudflare tunnel setup
./setup-cloudflare-tunnel.sh  # If available in root
```

## Security Best Practices

- ✅ Use Cloudflare Tunnel for remote access (avoid port forwarding)
- ✅ Enable Cloudflare Access for additional authentication
- ✅ Use strong authentication for services
- ✅ Keep cloudflared updated
- ✅ Monitor access logs
- ✅ Use VPN for internal services (database, monitoring)

## Related Documentation

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [GitHub Actions Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Main README](../../../README.md)
