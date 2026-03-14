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
