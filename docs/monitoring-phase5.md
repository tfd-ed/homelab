# Monitoring, Phase 5 (slices A, B and C): backups, deploys, web vitals, SSD wear, tunnel health, a second alert route, SLOs, synthetic journeys

Part of the observability plan (`tfd-blog-next/docs/OBSERVABILITY_CONTROL_ROOM_PLAN.md`, section 10, Phase 5). This runbook covers the pieces of slices A and B that live in this repo. Slice A is the first half (backups, deploy annotations); slice B starts at "Web vitals" below. The other two pieces (deploy markers and the Deployments page) are in `tfd-api-next` and `tfd-blog-next`; the fourth, the trusted client IP, was already done by the rate-limit work (see the plan).

| Item | What it adds | Where |
|---|---|---|
| 5.1.3 Backup age | The database VM's backup script publishes when each backup last succeeded and how big it was; four alerts watch it | `database-setup.yml`, `database-exporters-setup.yml`, `alerts/backup.yml`, `prometheus.yml.j2` |
| 5.1.1 Deploy annotations | A purple marker on the *TFD Services* dashboard at every deploy | `dashboards/tfd-services.json` |

## Backups

### What changed

`/opt/databases/backup.sh` (cron, 02:00, written by `playbooks/services/database-setup.yml`) used to run five jobs and print "Backup completed" whatever happened. A failed dump behind `| gzip` left a small valid-looking file. Now:

- Each job (`postgres`, `mongodb`, `redis`, `minio`) succeeds only if its command succeeded (`pipefail`) **and** wrote a non-empty file. A failed job's file is deleted, so a truncated dump never sits among the backups.
- The time and size of the last success of each job are kept in `/opt/databases/backups/.state/<job>`, so a failed night does not erase the memory of the last good one. The 7-day cleanup never touches them.
- After the jobs, the script writes `/var/lib/node_exporter/textfile_collector/db_backup.prom` (written aside and renamed). It exits 1 if any job failed, which shows in `/var/log/db-backup.log`.
- The Redis job now waits for `BGSAVE` to finish (`rdb_bgsave_in_progress:0`, `rdb_last_bgsave_status:ok`) before copying `dump.rdb`. The old version copied after a fixed 5 s sleep.

`playbooks/services/database-exporters-setup.yml` now also runs **node-exporter** on the database VM (port 9100) with the textfile collector on that directory. It runs on the bridge network with a published port, so the DOCKER-USER firewall of `networking/database-firewall.yml` filters it like the other exporters (9100 is in `db_firewall_exporter_ports`); the network collectors are off because they would describe the container. It also gives you host metrics for the VM (CPU, memory, disk) that did not exist before. `monitoring-setup.yml` scrapes it as job `node-exporter-database`, and `ScrapeTargetDown` covers it.

### MySQL was removed (2026-10-21)

The first night the new script ran, `BackupLastRunFailed` fired for `mysql`. The cause was not the script: `mysqldump` got `ERROR 1045: Access denied for user 'root'`, and so did the container's own `MYSQL_ROOT_PASSWORD`, because MySQL only reads that variable when its data directory is created and the stored root password was different. Going back through `/var/log/db-backup.log`, the same error had been there every night since at least 16 Oct, and the "backups" were 20-byte empty gzip files that the old script reported as completed. The instance held only MySQL's own schemas and no project referenced it, so it was removed rather than repaired: `database-setup.yml` no longer deploys it, no longer backs it up, and no longer opens port 3306 (also removed from `db_firewall_data_ports`); on a host that still has it, the playbook removes the container and the UFW rule. `/opt/databases/mysql/data` is left on disk (about 206 MB, empty instance); delete it by hand when you are sure. `MYSQL_ROOT_PASSWORD` is no longer used. Old `mysql_*.sql.gz` files age out under the 7-day cleanup, and the `mysql` series disappeared from `db_backup.prom` on the first script run after the change.

If a MySQL is ever needed again, create it with a password you record, and check the first backup by restoring it (the monthly restore test below).

### Metrics

| Metric | Labels | Meaning |
|---|---|---|
| `backup_last_success_timestamp_seconds` | `backup` | Unix time of the last good backup of that job |
| `backup_last_size_bytes` | `backup` | Size of that backup file |
| `backup_last_run_success` | `backup` | 1 if the most recent run of the job succeeded, else 0 |
| `backup_last_run_timestamp_seconds` | none | When the script last finished |

### Alerts (`alerts/backup.yml`, tested in `tests/backup.test.yml`)

| Alert | Fires when | Severity |
|---|---|---|
| `BackupStale` | The last good backup of a job is older than 26 h (10 min pending) | critical |
| `BackupLastRunFailed` | The most recent run of a job failed (5 min) | warning |
| `BackupTooSmall` | The last file is under half its 7-day average (and the average is over 10 KB) | warning |
| `BackupMetricsMissing` | No `backup_last_run_timestamp_seconds` for 30 h (the exporter or the script is not publishing) | warning |

### Apply (in order)

```bash
cd ansible
set -a && . ./.env && set +a
ansible-playbook playbooks/services/database-setup.yml            # new backup.sh and the textfile directory
ansible-playbook playbooks/services/database-exporters-setup.yml  # node-exporter on the database VM
ansible-playbook playbooks/services/monitoring-setup.yml          # new scrape job and backup.yml
```

`database-setup.yml` re-applies the whole database setup (it is idempotent); read its output, because it also rewrites the compose file and the other tasks you already know.

Then run the script once by hand, so you do not wait for 02:00, and check:

```bash
ssh database 'sudo /opt/databases/backup.sh; echo exit=$?; cat /var/lib/node_exporter/textfile_collector/db_backup.prom'
curl -s http://192.168.100.205:9100/metrics | grep '^backup_'          # from the monitoring VM or a host the firewall allows
# Prometheus (http://192.168.100.220:9090): backup_last_success_timestamp_seconds, and Status > Rules shows the backup group
```

Expect five `backup_last_success_timestamp_seconds` lines and `backup_last_run_success` 1 for each job. If the database firewall is already **enforcing**, port 9100 is allowed to the monitoring VM only by `db_firewall_exporter_ports`; re-run `networking/database-firewall.yml` so the new port is in the chain.

### Monthly restore test (the other half of 5.1.3)

An alert proves a file exists; only a restore proves it works. Once a month, on a scratch machine (never on the database VM):

1. Copy the newest `postgres_*.sql.gz` and `mongodb_*.tar.gz` from `/opt/databases/backups` to the scratch machine.
2. Start empty containers (`postgres:16`, `mongo:8.2`) and restore: `gunzip -c postgres_*.sql.gz | docker exec -i pg psql -U postgres` and `mongorestore --archive` (extract the tarball first, then `mongorestore <dir>`).
3. Check a known count: for example the number of users in Mongo and the number of GlitchTip issues in Postgres match what the control room shows.
4. Write the date and the result at the bottom of this file.

| Date | Result |
|---|---|
| (none yet) | |

### Known limit: the backups are on the same VM

`/opt/databases/backups` is on the database VM's disk, which is on the same single NVMe as everything else. These alerts tell you the backups are being made; they do not protect against losing the VM or the SSD. Where an off-machine copy should go is open decision 10 in the plan. Until it is decided, copy the newest files off the machine by hand now and then.

## Deploy annotations

`dashboards/tfd-services.json` now has an annotation query *Deploys*. It reads the line the API's bot writes for every deploy marker (`ops.deploy service=tfd-api env=prod sha=a1b2c3d result=succeeded ...`, app `tfd-bot`, a Loki stream like any other) and draws a purple marker on every panel, titled `Deploy <service> <sha> (<result>)`. It follows the dashboard's *environment* variable.

Apply: the `ansible-playbook playbooks/services/monitoring-setup.yml` run above installs the TFD dashboards too (`monitoring-dashboards-setup.yml` is only for the community dashboards). Nothing else is needed: the markers appear once the first deploy reports (see `tfd-api-next/docs/OBSERVABILITY.md`, "Deploy markers"). The line stays in Loki for 14 days like any other log line; the Deployments page in the control room keeps a year.

How it was checked: the LogQL was run against a real Loki 3.4 with three pushed lines (a prod deploy, a dev deploy that failed, an unrelated line) and returned the `service`, `sha` and `result` labels for the two deploy lines only.

# Slice B

| Item | What it adds | Where |
|---|---|---|
| 5.2.2 Web vitals | Alerts and a dashboard row for what real visitors measure in their browsers | `alerts/rum.yml`, `dashboards/tfd-services.json` |
| 5.5.1 SSD wear and capacity | node-exporter on the Proxmox host, NVMe SMART and LVM thin-pool metrics, and the alerts that read them; Prometheus, Loki and series-growth alerts | `infrastructure/proxmox-exporter-setup.yml`, `infrastructure/files/nvme-smart-metrics.py`, `alerts/capacity.yml` |
| 5.1.6 Tunnel metrics | cloudflared's own metrics on the gateway VM, and the Tunnel-degraded alert | `networking/cloudflared-metrics-setup.yml`, `alerts/tunnel.yml` |
| 5.5.2 A second route for critical alerts | ntfy and/or email beside Telegram | `templates/monitoring/alertmanager.yml.j2`, `monitoring-setup.yml` |

Apply order: the playbooks below first, then `monitoring-setup.yml` once (it scrapes the new jobs, loads the new rule files, installs the dashboard and the second route). Everything is safe to apply in any order; an alert simply stays quiet until its source exists.

## Web vitals

The browser measures LCP, INP, CLS and TTFB and the Nuxt server counts them (`tfd-blog-next/docs/OBSERVABILITY.md`, "Real-user performance"). Nothing to install here: Alloy already scrapes the pods' `/metrics`. Re-run `monitoring-setup.yml` for the rule file and the dashboard row (*TFD Services*, row *Real users*).

| Alert | Fires when | Severity |
|---|---|---|
| `WebVitalsLcpPoorMobile` | Phone LCP p75 over 4 s for 30 min, at least 30 reports in the window | warning |
| `WebVitalsInpPoorMobile` | Phone INP p75 over 500 ms, same rule | warning |
| `WebVitalsClsPoor` | CLS p75 over 0.25, same rule | warning |

They are warnings and prod-only on purpose: real-user numbers are noisy, and a quiet night has too few reports to judge, which is why every alert needs 30. Start by looking at the dashboard for a week to see what "normal" is for your visitors before trusting the thresholds. If the series are missing: check that the pods run with `NUXT_PUBLIC_WEB_VITALS=true` and `METRICS_PORT`, and that a phone browser can reach `POST /_t/vitals` (an ad-blocker can block it).

## SSD wear and capacity

Everything runs on one NVMe. Nothing measured it until now.

```bash
cd ansible
ansible-playbook playbooks/infrastructure/proxmox-exporter-setup.yml       # on the Proxmox host
ansible-playbook playbooks/services/monitoring-setup.yml                    # scrape job node-exporter-proxmox + capacity.yml
```

What the first playbook does on the host: installs `prometheus-node-exporter`, `smartmontools` and `python3`; turns on the textfile collector; installs `/usr/local/bin/nvme-smart-metrics.py` and a systemd timer (every 15 minutes, 2 minutes after boot). The script reads `smartctl -j -a /dev/nvme0` and `lvs` and writes `smart_nvme_*` and `lvm_thin_pool_*` into the collector. It changes nothing else. A second NVMe: `-e '{"nvme_devices":["/dev/nvme0","/dev/nvme1"]}'`. Port 9100 is open on the host's LAN address like node-exporter on the K3s nodes; if the Proxmox firewall is on, allow the monitoring VM (192.168.100.220) to reach it.

Check:

```bash
ssh proxmox 'systemctl status nvme-smart-metrics.timer --no-pager | head -5; cat /var/lib/node_exporter/textfile_collector/nvme_smart.prom | grep -v "^#"'
# Prometheus: smart_nvme_percentage_used, lvm_thin_pool_data_percent; /targets shows node-exporter-proxmox up
```

| Alert | Fires when | Severity |
|---|---|---|
| `NvmeWearHigh` / `NvmeWearCritical` | Percentage Used 70 or more / 90 or more (1 h) | warning / critical |
| `NvmeCriticalWarning` | The drive's critical-warning flags are not 0 | critical |
| `NvmeSpareLow` | Available spare under 20 % | warning |
| `NvmeMediaErrors` | New media and data integrity errors in a day | warning |
| `NvmeUnsafeShutdown` | The unsafe-shutdown counter moved in the last hour: a power cut | warning |
| `NvmeTemperatureHigh` | Over 70 C for 15 min | warning |
| `NvmeSmartMetricsStale` | The timer has not succeeded for 3 h | warning |
| `ThinPoolFilling` / `ThinPoolAlmostFull` | LVM thin pool data or metadata over 80 % / 90 % | warning / critical |
| `PrometheusStorageNearCap` | Prometheus at over 85 % of its 40 GB size cap | warning |
| `PrometheusSeriesGrowing` | Active series 50 % up on a week ago, over 20 000 | warning |
| `LokiIngestSurge` | Log ingest in the last hour over 3 times the 7-day average and 50 KB/s | warning |

`smart_nvme_data_written_bytes_total` is the one to graph: `rate(smart_nvme_data_written_bytes_total[1d])` is the daily write rate. Compare it with the drive's rated endurance (TBW) from the Phase 0 baseline to see how many years are left; `NvmeWearHigh` is the backstop. An unsafe shutdown after a power cut is the early reason to buy the UPS (open decision 9).

Existing host alerts (`HostMemoryHigh`, `HostDiskSpaceLow`, `HostDiskWillFillIn24h`) start covering the Proxmox host as soon as it is scraped. The host has 62 of its 64 GB allocated to VMs, so watch `HostMemoryHigh` there.

## Tunnel metrics

cloudflared on the gateway VM publishes its own metrics once `TUNNEL_METRICS` is set. **This restarts cloudflared, which drops the tunnel for a few seconds and every public site with it: run it at a quiet time.**

```bash
cd ansible
ansible-playbook playbooks/networking/cloudflared-metrics-setup.yml
ansible-playbook playbooks/services/monitoring-setup.yml
```

The playbook adds a systemd drop-in (`/etc/systemd/system/cloudflared.service.d/metrics.conf`) with `TUNNEL_METRICS=<gateway IP>:20241` and restarts the unit only when the drop-in changed. It works for a token-run tunnel and a `config.yml` one alike. If cloudflared is not a systemd unit named `cloudflared` on that VM (a container, say) the playbook stops with the exact variable to set. Prometheus scrapes it as job `cloudflared`.

| Alert | Fires when | Severity |
|---|---|---|
| `TunnelDegraded` | `cloudflared_tunnel_ha_connections` under 2 for 5 min (normally 4) | critical |
| `TunnelRequestErrors` | Over 5 % of requests fail between the tunnel and the origin for 10 min, with real traffic | warning |

The HTTP probes already catch a total outage from outside; these catch the half-broken cases. The metric names were taken from cloudflared's documentation and not checked against your running version: after applying, open `http://<gateway IP>:20241/metrics` and confirm `cloudflared_tunnel_ha_connections`, `cloudflared_tunnel_total_requests` and `cloudflared_tunnel_request_errors` exist; if one is named differently, fix `alerts/tunnel.yml` and its test.

## A second route for critical alerts

If Telegram is unreachable, a critical alert reaches nobody. Alertmanager can now send every critical alert to a second place **as well**, so a failure of either does not hide it. Warnings stay Telegram-only.

Set either or both in `ansible/.env` (see `.env.example`) and re-run `monitoring-setup.yml`:

| Variable | Meaning |
|---|---|
| `NTFY_URL` | A topic URL, for example `https://ntfy.sh/tfd-ops-<a long random string>`. On the public ntfy.sh the **topic name is the secret**: make it long and random, and subscribe to it in the ntfy phone app. `NTFY_TOKEN` is optional (a protected or self-hosted server). |
| `ALERT_EMAIL_TO`, `SMTP_SMARTHOST` (host:port), `SMTP_FROM`, optional `SMTP_USERNAME` and `SMTP_PASSWORD` | Email. All of the first three are needed. |

The ntfy message is built by ntfy from Alertmanager's webhook body (its templating): title `FIRING: <alertname>`, one line per alert with its summary, urgent priority, and a link to the control room's Alerts page. Secrets are written to files on the VM (mode 0400), never into the config.

With neither set the playbook prints a warning and critical alerts go to Telegram only. To test: from the control room Alerts page, **Test critical** (needs `MANAGE_OPS_ALERTS`); both Telegram's critical topic and your ntfy or email should receive `ControlRoomTest`, and the resolved message two minutes later.

How it was checked: the configuration was rendered for all four combinations (none, ntfy, ntfy with token plus email, email) and passed `amtool check-config`; `amtool config routes test` shows a critical alert reaching `telegram-critical,critical-backup` and a warning only `telegram-warning`; and with a real Alertmanager and ntfy, a critical alert was delivered to ntfy (urgent priority, grouped message) while Telegram was unreachable.

## Slice B: how it was checked

- `promtool test rules` for `rum.yml`, `capacity.yml` (plus `capacity-loki.test.yml`, which needs a coarser step) and `tunnel.yml`, and the earlier files still pass.
- `nvme-smart-metrics.py`: 9 unit tests (`python3 -m unittest -v test_nvme_smart_metrics` in `infrastructure/files/`), a run against a fake `smartctl` and `lvs`, and `promtool check metrics` on its output. Not run against a real NVMe: do that first (`ssh proxmox sudo /usr/local/bin/nvme-smart-metrics.py`, then look at the file).
- The dashboard JSON was loaded by a real Grafana 10.2.3.
- `ansible-playbook --syntax-check` for both new playbooks. They have **not** been run against the real hosts.

# Slice C

| Item | What it adds | Where |
|---|---|---|
| 5.1.5 SLOs and burn-rate alerts | Three objectives with a 30-day error budget, and alerts that fire on how fast the budget is spent instead of on a bare threshold | `prometheus/slo/slos.sloth.yml` (source), `alerts/slo.yml` (generated), `tests/slo.test.yml` |
| 5.2.1 Synthetic journeys | A headless browser on the ci-cd VM walks the site every 10 minutes and publishes pass/fail and timing | `services/synthetic-setup.yml`, `services/files/synthetic/`, `alerts/synthetic.yml`, `tests/synthetic.test.yml` |

Apply order: `synthetic-setup.yml` first (it also installs node-exporter on the ci-cd VM), then `monitoring-setup.yml` once (new scrape job `node-exporter-ci`, `alerts/slo.yml`, `alerts/synthetic.yml`), then `tfd-api-next`, then `tfd-blog-next`, dev before prod. The SLOs work without the apps being deployed (they read series that already exist); the synthetic user agent is only recognised, and kept out of the traffic figures, once the API and the site are deployed.

## SLOs

The source is `prometheus/slo/slos.sloth.yml`. The rules in `alerts/slo.yml` are **generated** by [Sloth](https://sloth.dev) and committed as plain YAML, so nothing new runs on the monitoring VM. After editing the spec:

```bash
cd ansible/playbooks/services/files/monitoring/prometheus
slo/generate.sh          # needs Docker; runs Sloth, then promtool check rules
docker run --rm --entrypoint promtool -v "$PWD:/w" prom/prometheus:v2.48.1 test rules /w/tests/slo.test.yml
```

| SLO | Good means | Target | SLI query |
|---|---|---|---|
| `site-available` | the Blackbox probe of `tfdevs.com` succeeds | 99.5 % | `probe_success{probe="site", env="prod"}` |
| `api-available` | the response is not 5xx, on routes that exist | 99.5 % | `http_server_duration_seconds_count`, `route!="unmatched"`, `traffic!="synthetic"` |
| `api-fast` | the response takes under 1 second | 95 % | the `le="1"` bucket over the count, same filters |

The targets are first guesses from the plan: look at the numbers on the control room's **Reliability** page after a month and tune them (edit the spec, regenerate). 99.5 % is about 3.6 hours of failure in 30 days.

Each SLO gets recording rules (`slo:sli_error:ratio_rate5m` up to `ratio_rate30d`, `slo:period_error_budget_remaining:ratio`, `slo:objective:ratio`) and two alerts named `SiteAvailabilitySloBurn`, `ApiAvailabilitySloBurn` and `ApiLatencySloBurn`, each with a **page** and a **ticket** form, told apart by the label `sloth_severity`:

| Form | Severity | Fires when the budget would be gone in about | Windows (both must burn) |
|---|---|---|---|
| page | `critical` | 2 days (14.4x) | 1 h and 5 min |
| page | `critical` | 5 days (6x) | 6 h and 30 min |
| ticket | `warning` | 10 days (3x) | 1 day and 2 h |
| ticket | `warning` | 30 days (1x) | 3 days and 6 h |

Requiring the short window as well as the long one is what stops a blip from paging: a 3-minute outage after days of health does nothing (`tests/slo.test.yml`).

**What changed in the old alerts.** `AppHighErrorRate` now watches the web app's page renders only (`tfd-blog`), and `ApiLatencyHigh` is gone: the API's 5xx rate and latency are the SLO burn alerts above. `SsrLatencyHigh` is unchanged. The API series carry a new label `traffic` (`visitor` or `synthetic`); `traffic!="synthetic"` also matches the old series that have no label, so the rules work before and after the API is deployed.

**Reading the 30-day figures.** Prometheus keeps 30 days, so the figure needs a full month of data to be exact. Until then it is computed from what exists (the control room says "about N days of data so far"). The first week's numbers are noisy: do not tune anything from them.

## Synthetic journeys

`services/files/synthetic/` is a small Playwright program, run by `synthetic.timer` on the ci-cd VM every 10 minutes inside the pinned `mcr.microsoft.com/playwright:v1.49.1-noble` image (1 GB memory limit). Each journey gets a fresh browser context and 45 seconds, and sends the User-Agent token `TFD-Synthetic/1.0`; the site and the API count that as `traffic="synthetic"` and `device=synthetic`, so the journeys stay out of the Overview, the web vitals and the SLOs.

| Environment | Journey | Passes when |
|---|---|---|
| prod, dev | `home` | the page answers, has a title, shows content and is not the error page |
| prod, dev | `courses`, `course-detail` | the list has a course, and opening the first one shows its heading |
| prod, dev | `article` | the article list works; the first article opens if there is one |
| prod, dev | `certificate-verify` | the verify page has its input |
| prod, dev | `health-ready` | `/api/health/ready` answers 200 |
| dev only | `login`, `open-course`, `enrollments` | sign-in through `/auth/login-cookie` works, and `/portal` and `/portal/courses` stay open |
| dev only | `admin-page` | `/admin/users` shows its table (only with `SYNTHETIC_DEV_ADMIN=1`) |

They check what a person notices first, not wording, so a copy change never fails one. **Production runs public journeys only**, because production has no password login. The signed-in journeys need a dedicated low-privilege account on **dev** (never an administrator's): put `SYNTHETIC_DEV_USER` and `SYNTHETIC_DEV_PASS` in `ansible/.env` before the playbook; without them they are skipped.

```bash
cd ansible && set -a && . ./.env && set +a
ansible-playbook playbooks/services/synthetic-setup.yml      # runner, timer, node-exporter :9100, runs once
ansible-playbook playbooks/services/monitoring-setup.yml     # scrape job node-exporter-ci, alerts/synthetic.yml
ssh ci-cd 'journalctl -u synthetic -n 30 --no-pager; ls /opt/synthetic/artifacts'
```

Results are textfile metrics (`synthetic_success`, `synthetic_duration_seconds`, `synthetic_consecutive_failures`, `synthetic_last_success_timestamp_seconds`, `synthetic_last_run_timestamp_seconds`). A screenshot of every failure is kept in `/opt/synthetic/artifacts` (newest 50).

| Alert | Fires when | Severity |
|---|---|---|
| `SyntheticJourneyFailing` | a journey failed 2 runs in a row (20 min) | warning |
| `SyntheticProdJourneyDown` | a production journey failed 4 runs in a row (40 min) | critical |
| `SyntheticRunsStale` | the last result is over 40 min old (the runner stopped but node-exporter still serves the file) | warning |
| `SyntheticMetricsMissing` | nothing published for an hour (not installed, or not scraped) | warning |

One failed run alerts nobody: a page can fail once for a reason nobody needs to know. If a journey fails for a real reason, the screenshot and `journalctl -u synthetic` say which step. If one flaps, fix the journey (`journeys.mjs`) rather than raising the thresholds.

**Not verified on the real hosts.** The runner was tested in the Playwright image against a stand-in site (passes, failures, the error-page marker, state and metrics file), and the alerts with promtool. It has not run against tfdevs.com, and the dev sign-in has not run at all: the first thing to check after applying is `journalctl -u synthetic`, and that a login cookie set by the API on `api-dev.tfdevs.com` is accepted by `dev.tfdevs.com` (same cookie domain).

## Slice C: how it was checked

- `slo/generate.sh` (Sloth v0.11.0, then `promtool check rules`: 51 rules); `tests/slo.test.yml` and `tests/synthetic.test.yml` pass, and so do all the older test files (`app.test.yml` was cut down to the SSR error alert).
- The recording rules were loaded by a real Prometheus 2.48.1 scraping a synthetic exporter: the error ratio came out as expected (visitor 5xx only, synthetic requests and unknown URLs left out) and `tfd-api-next`'s queries read it.
- `files/synthetic`: 9 unit tests (`node --test`), and a run of `run.mjs` in the Playwright container against a stand-in site, with pages broken on purpose (failure counted, screenshot saved, metrics file valid).
- `ansible-playbook --syntax-check synthetic-setup.yml`, and a `--check` run against the ci-cd VM (stops at the timer, which does not exist yet). It has **not** been applied.
