# Monitoring Phase 0 — alerts, probes, heartbeat

What this adds to the monitoring VM (observability plan, Phase 0, in `tfd-blog-next/docs/OBSERVABILITY_CONTROL_ROOM_PLAN.md`):

| Piece | Where | What it does |
|---|---|---|
| Alertmanager | monitoring VM (compose), loopback `:9093` | Groups, routes and sends alerts to Telegram; forwards `Watchdog` to the external heartbeat |
| Alert rules | `ansible/playbooks/services/files/monitoring/prometheus/alerts/baseline.yml` | 24 rules: meta, availability, hosts, Kubernetes, Postgres |
| blackbox-exporter | monitoring VM (compose), loopback `:9115` | Probes the public sites (through Cloudflare), every VM's SSH, database ports, ingress NodePort, registry |
| kube-state-metrics | K3s namespace `monitoring`, NodePort `30686` | Crash loops, unready pods, replica mismatches, OOM kills, NotReady nodes |
| Grafana hardening | monitoring VM | Admin password from the environment (no more `admin/admin`), sign-up and anonymous access off, Alertmanager datasource |
| Grafana behind Cloudflare Access | `tfdevs-infra` | `grafana.tfdevs.com` with SSO, so the Grafana login is a second factor, not the only one |
| Storage baseline | `playbooks/infrastructure/storage-baseline.yml` | Read-only NVMe wear, unsafe shutdowns, thin-pool use, backup jobs |

## 1. Prerequisites

1. **Telegram bot and chat id.** In BotFather create a bot (a dedicated one is recommended so a leaked alert token cannot read or post as your product bot). Add it to the ops group and make it an admin if the group is a forum. Get the numeric chat id (for a group it is negative, e.g. `-1001234567890`; `https://api.telegram.org/bot<token>/getUpdates` shows it after you post a message). The backend's `TELEGRAM_OPS_CHAT_ID` is the same group.
2. **External heartbeat.** See section 4. Strongly recommended: without it an outage of the homelab itself is silent.
3. **Environment variables** on the machine running Ansible, in `ansible/.env` (git-ignored, copy from `.env.example`):
   `GRAFANA_ADMIN_PASSWORD`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_OPS_CHAT_ID`, optionally `HEARTBEAT_URL`, `TELEGRAM_THREAD_CRITICAL`, `TELEGRAM_THREAD_WARNING`.
4. `node-exporter` on the K3s nodes (`playbooks/services/node-exporter-setup.yml`) if the `k8s-nodes` target is not already up.

## 2. Deploy order

```bash
cd ansible
set -a && . ./.env && set +a

# 0. (optional, read-only) record the storage baseline before adding stores
ansible-playbook playbooks/infrastructure/storage-baseline.yml --limit proxmox

# 1. kube-state-metrics in K3s
ansible-playbook playbooks/kubernetes/kube-state-metrics-setup.yml

# 2. monitoring stack (validates promtool + amtool BEFORE restarting anything)
ansible-playbook playbooks/services/monitoring-setup.yml

# 3. prove Telegram delivery once
ansible-playbook playbooks/services/monitoring-setup.yml -e send_test_alert=true
```

Then in `tfdevs-infra`: `terraform plan`, review, `terraform apply` for `grafana.tfdevs.com` (DNS, tunnel ingress, proxy host, Access application).

The playbook stops and restarts the stack (a few seconds without scraping). Prometheus data and Grafana data are kept.

## 3. Verify (done when)

| Check | How | Expected |
|---|---|---|
| Rules loaded | Prometheus `/rules` | 5 groups: meta, availability, hosts, kubernetes, databases (24 rules, no errors) |
| Targets healthy | Prometheus `/targets` | all `UP`; `k8s-nodes` and `kube-state-metrics` need steps 1 and the node-exporter prerequisite |
| Telegram works | `-e send_test_alert=true` | A silent warning message "Test alert" appears in the group |
| Pod alert | `kubectl -n prod delete pod <one tfd-api pod>` | No alert (a replacement starts within seconds). To test the alert path, scale a **dev** deployment to 0 for 25 minutes and expect `KubeDeploymentReplicasMismatchOther` |
| Probe alert | `docker stop blackbox-exporter` on the VM for 4 min | `ScrapeTargetDown` critical in Telegram; start it again and expect RESOLVED |
| Watchdog | Heartbeat service dashboard | Check shows "up", last ping within a minute |
| **Outage drill** | Disconnect the monitoring VM's network (or stop Alertmanager) for 5 minutes | The heartbeat service messages you, not Alertmanager |
| Grafana | `https://grafana.tfdevs.com` | Cloudflare Access SSO first, then the Grafana login with the new password; old `admin/admin` rejected |

## 4. External heartbeat (dead-man's switch)

Alertmanager sends the always-firing `Watchdog` alert to a URL every minute. A hosted service (for example a Healthchecks.io check with a 1-minute period and 3-minute grace) expects that ping and notifies **you** when it stops. It must live outside the homelab, otherwise a power or ISP outage silences it too.

1. Create the check, set period 1 minute, grace 3 minutes.
2. Add a notification channel there that does not depend on the homelab (Telegram DM to yourself, email, SMS).
3. Put the ping URL in `HEARTBEAT_URL` and re-run `monitoring-setup.yml`. The URL is stored in a root-owned, mode-0400 file mounted into Alertmanager, never in the config.

Optional second layer: an external HTTP check of `https://tfdevs.com` and `https://api.tfdevs.com/health` (the same service, or Cloudflare Health Checks / Notifications on the zone).

## 5. Alert catalogue and what to do

Severity: **critical** posts to the group and repeats hourly; **warning** posts silently and repeats every 4 hours. Probe alerts take their severity from the target (`prod` sites critical, `dev` warning).

### ScrapeTargetDown
Prometheus cannot reach a monitoring target. `k8s-nodes`: run `node-exporter-setup.yml`. `kube-state-metrics`: run `kube-state-metrics-setup.yml`, check `kubectl -n monitoring get pods`. `postgres`: check the exporter container on database-vm. `alertmanager` / `blackbox-exporter`: `docker-compose ps` and logs on the monitoring VM.

### PrometheusRuleEvaluationFailing
A rule errors at evaluation, so that alert may be silent. Open Prometheus `/rules`, find the red rule, fix the expression in `baseline.yml`.

### AlertmanagerNotificationsFailing
Alerts fire but cannot be delivered. Check the bot token file, the chat id, that the bot is still in the group, and outbound access to `api.telegram.org` from the monitoring VM. `docker logs alertmanager`.

### HttpProbeFailed
A public URL has failed for 2 minutes. The probe travels Cloudflare, tunnel, gateway, ingress, app. Triage from the edge inward: Cloudflare status and tunnel `HOMELAB_GATEWAY` health, gateway VM (`docker ps` for cloudflared and NPM), ingress (`kubectl -n ingress-nginx get pods`), then the app (`kubectl -n prod get pods`, logs). `https://api.tfdevs.com/health` is a liveness check today and does not prove the database works (readiness comes in Phase 3).

### HttpProbeSlow
Response above 3 s for 10 minutes. Look at CPU and memory alerts on the workers, database VM load, and recent deploys.

### TcpProbeFailed
A VM, port or service is unreachable from the monitoring VM. If many VMs fail together suspect the Proxmox host, the switch or power. One database port: check the container on database-vm. `ingress-nodeport` (`:30389` on worker-1): the ingress controller or worker-1 is down, which takes the whole site with it.

### TlsCertificateExpiringSoon / TlsCertificateExpiryImminent
The certificate presented for a public host expires in under 14 / 3 days. It is Cloudflare's edge certificate, which normally auto-renews; check the zone's SSL/TLS settings and any custom certificates.

### HostMemoryHigh / HostCpuHigh
Sustained pressure on a host. Check what runs there; the K3s workers have 10 GB each and the host has about 6 GB spare, so do not raise VM memory without freeing it elsewhere.

### HostDiskSpaceLow / HostDiskSpaceCritical / HostDiskWillFillIn24h
Free space under 15 % / 5 %, or projected to run out within a day. Find the growth (`du -xh --max-depth=1`, `docker system df`), prune images and logs, then fix the source.

### HostOomKillDetected
The kernel killed a process. See `dmesg -T | grep -i oom` and the VM's memory graph.

### KubeNodeNotReady
A K3s node is NotReady for 3 minutes. `kubectl get nodes`, `journalctl -u k3s-agent` (or `k3s`) on the node.

### KubePodCrashLooping
A container keeps restarting. `kubectl -n <ns> logs <pod> --previous`, `kubectl -n <ns> describe pod <pod>`. After a deploy, consider `kubectl rollout undo deployment/<name> -n prod`.

### KubePodNotReady
A pod has been Pending, Unknown or Failed. `kubectl -n <ns> describe pod <pod>` (events show scheduling, image pull and volume problems).

### KubeDeploymentReplicasMismatch
Fewer replicas available than desired for 10 minutes (prod) or 20 minutes (other). A normal rolling update (`maxUnavailable: 0`) finishes well inside that. `kubectl -n <ns> rollout status deployment/<name>`.

### KubeContainerOOMKilled
A container restarted after running out of memory. Raise its memory limit or find the leak.

### PostgresDown
The Postgres exporter reports the database is unreachable. Plausible depends on it. Check the container on database-vm.

## 6. Design notes

- **Alerts leave Prometheus only if rules and routes are valid.** The playbook runs `promtool check config` (which also checks the rule files) and `amtool check-config` (which checks templates and secret files) before restarting anything, so a typo cannot take down a working stack.
- **Probes are what users feel.** HTTP probes travel the real public path; TCP probes pinpoint which hop failed. The first alert answers "is it up", the second "where".
- **Secrets**: the Telegram token, heartbeat URL and Grafana password come from the environment, are written to root/nobody-only files, and never appear in compose files, configs or Ansible output (`no_log`).
- **Exposure**: Alertmanager (`9093`) and blackbox (`9115`) bind to loopback only. Prometheus `9090` and Grafana `3000` still listen on the LAN as before; Grafana is the one reachable from outside, through Cloudflare Access.
- **Not in Phase 0** (later phases): Loki and logs, application `/metrics`, Mongo and Redis exporters, `/health/ready`, SLO alerts, NVMe wear exporter, backup-age alert.

## 7. Rollback

`cd /opt/monitoring && docker-compose down`, restore the previous `docker-compose.yml` and `prometheus.yml` from git history of this repo, re-run the old playbook revision. Prometheus and Grafana data are untouched by this change. To remove kube-state-metrics: `kubectl delete namespace monitoring` and `kubectl delete clusterrole,clusterrolebinding kube-state-metrics`.
