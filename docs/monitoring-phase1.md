# Monitoring Phase 1 — request ids, structured logs, Loki

Observability plan, Phase 1 (`tfd-blog-next/docs/OBSERVABILITY_CONTROL_ROOM_PLAN.md`). Goal: given one request id, one query shows what every hop did with that request.

| Piece | Where | What it does |
|---|---|---|
| Loki 3.4 | monitoring VM (compose), LAN `:3100` | Stores logs: 14 days, `level=error` lines 30 days; label-light |
| Grafana datasource + **TFD Requests** dashboard | monitoring VM | Rates, errors, latency by route, top countries/devices, and a filterable request lookup |
| Alloy DaemonSet | K3s namespace `monitoring`, hostPort `12345` | Tails pod logs of `prod`, `dev`, `ingress-nginx`, `plausible` and ships them to Loki |
| Alloy on the gateway VM | `/opt/alloy` (compose) | Ships Nginx Proxy Manager's JSON access log |
| NPM custom nginx snippets | gateway VM, `/data/nginx/custom/` | JSON access log with `cfRay`; checked with `nginx -t` before reload, rolled back on failure |
| Log alerts | Prometheus rules `logging.yml` | Log shipping stalled, entries dropped, Loki rejecting logs |
| App changes | `tfd-api-next`, `tfd-blog-next` | Request id, JSON request line per request, `requestId` in API error bodies |
| Ingress JSON format | `tfd-api-next/k8s/ingress-configmap.yaml` | One JSON line per request with `requestId`, `cfRay`, status, timings |

## Labels and fields

Loki **labels** (indexed, few values): `namespace`, `app`, `env`, `level`.

| `app` | `env` | Source |
|---|---|---|
| `tfd-api`, `tfd-bot`, `tfd-pdf` | `prod` / `dev` | NestJS JSON logs |
| `tfd-blog` | `prod` / `dev` | Nuxt server request lines |
| `ingress-nginx` | `edge` | Ingress access log (serves prod and dev; use the `host` field) |
| `npm` | `edge` | Gateway access log (`cfRay`, no request id) |

Everything else is a JSON field: `requestId`, `cfRay`, `route`, `status`, `durationMs`, `userId`, `country`, `ip`, `device`, `errorClass`... Query with `| json`. Fields named `app`, `env`, `level` also exist inside the lines; Loki shows them as `app_extracted` and so on, which is harmless.

## Deploy order (cross-repo, important)

1. **tfd-api-next first.** Its CORS list must allow the new headers before any frontend sends them. The deploy also applies `k8s/ingress-configmap.yaml` (JSON ingress log, tighter `set-real-ip-from`).
2. **homelab-journey** (this repo): Loki, then the shippers.
3. **tfd-blog-next.** Optional afterwards: set `NUXT_PUBLIC_TRACE_HEADERS=true` in its manifest to send `x-client-route` from the browser (only once the API change is live in that environment).

```bash
cd ansible
set -a && . ./.env && set +a

# 2a. Loki + dashboard + new Prometheus jobs and rules (validates configs before restarting)
ansible-playbook playbooks/services/monitoring-setup.yml

# 2b. Alloy on the K3s workers
ansible-playbook playbooks/kubernetes/alloy-setup.yml

# 2c. Gateway: JSON access log + Alloy (proves itself end to end at the end of the play)
ansible-playbook playbooks/networking/gateway-logging-setup.yml
```

The monitoring playbook restarts the stack (a short gap in scraping). Existing Prometheus and Grafana data are kept.

Until 2b and 2c have run, `ScrapeTargetDown` fires for the `alloy-k8s` and `alloy-gateway` targets after three minutes. That is expected; run both playbooks straight after 2a.

## Verify (done when)

| Check | How | Expected |
|---|---|---|
| Targets | Prometheus `/targets` | `loki`, `alloy-k8s` (2 workers), `alloy-gateway` all UP |
| Loki labels | Grafana → Explore → Loki → label browser | `app`, `env`, `level`, `namespace` with the values above |
| Ingress format applied | `kubectl -n ingress-nginx logs deploy/ingress-nginx-controller --tail=3` | JSON lines |
| **One id, every hop** | `curl -sI https://api.tfdevs.com/health` and note `X-Request-Id`; then Explore: `{env=~".+"} \|= "<that id>"` | Lines from `ingress-nginx` and `tfd-api` (and `tfd-blog` for a page request) |
| **Browser path** | Open the site, copy a `cf-ray` from DevTools → Network → any API call; Explore `{env=~".+"} \|= "<cf-ray>"` | Lines from `npm`, `ingress-nginx` (and API if the request reached it) |
| Dashboard | Grafana → TFD Requests | Request counts, latency, routes, countries populate; *id* box filters the log panel |
| Error body id | `curl -s https://api.tfdevs.com/courses/not-an-id` | JSON body has `requestId` equal to the `X-Request-Id` header |
| Alert path | Stop the Alloy DaemonSet (`kubectl -n monitoring delete ds alloy`) for 20 min | `LogShippingStalledK8s` warning in Telegram; re-run `alloy-setup.yml` to recover |

## Finding things (Grafana → Explore → Loki)

```logql
{env=~".+"} |= "7f3a9c1e5b2d4e6f8a0b1c2d3e4f5a6b"                          # every line for one request id
{env=~".+"} |= "8a1b2c3d4e5f6a7b-SIN"                                      # by cf-ray (includes the gateway)
{app="tfd-api", env="prod"} | json | type="request" | status >= 500        # API server errors
{app="tfd-api"} | json | type="request" | route="/enrollments" | durationMs > 1000
sum by (route) (count_over_time({app="tfd-api", env="prod"} | json | type="request" [1h]))
{app="ingress-nginx"} | json | host="api.tfdevs.com" | status >= 500
```

## Alerts added

### LogShippingStalledK8s / LogShippingStalledGateway
No log lines reached Loki for 15 minutes. Blackbox probes alone generate ingress and gateway lines every minute, so silence means the pipeline is broken. K8s: `kubectl -n monitoring get pods -l app.kubernetes.io/name=alloy`, `kubectl -n monitoring logs ds/alloy`. Gateway: `docker logs alloy` and `tail /opt/nginx-proxy-manager/data/logs/tfd_access.log`. Both: is Loki up (`docker logs loki`, `curl http://192.168.100.220:3100/ready`)?

### LogEntriesDropped
Alloy gave up delivering lines. Usually Loki was down or overloaded for a while; check Loki memory and disk.

### LokiRejectingLogs
Loki discards lines: `ingestion_rate_limit_exceeded` / `per_stream_rate_limit` (a chatty pod; check its log level) or `greater_than_max_sample_age` (lines older than 7 days). Limits are in `files/monitoring/loki/loki-config.yml`.

Expect this alert and a burst of `HTTP status 400 ... timestamp too old` / `entry too far behind` errors in `kubectl -n monitoring logs ds/alloy` **once, right after the first Alloy start**: Alloy reads the log files that already exist on each worker from the beginning, and Loki refuses lines older than 7 days or far behind the newest line of the stream. Those lines are old backlog and are dropped on purpose. It stops by itself once the backlog is read (positions are then saved); if the errors keep coming 10 minutes later, treat it as real.

## Notes and limits

- **Loki is unauthenticated on the LAN** (`:3100`), like Prometheus and node-exporter. Anyone on the LAN can read or write logs. Do not publish it through the tunnel or the gateway. Grafana (behind Cloudflare Access) is the human way in.
- **Retention**: 14 days, `level=error` 30 days, enforced by the Loki compactor. Total volume is unknown until you have a week of data: check `du -sh /opt/monitoring/loki/data` and Loki's own metrics after a week and adjust (see plan section 4.3).
- **Memory**: Loki runs with a 768 MiB soft limit (`GOMEMLIMIT`). The monitoring VM has 6 GB shared with Prometheus and Grafana. If it swaps, resize the VM (plan section 4.2).
- **What is not logged by design**: query strings, request bodies, cookies, `Authorization`, emails. The ingress and gateway log `$uri` (no query string).
- **Cached pages** served by Cloudflare never reach the origin, so they appear in Cloudflare analytics, not here.
- **Gateway log source**: the NPM snippets use `server_proxy.conf` and `http_top.conf` in `/data/nginx/custom/`, the documented hooks. If a future NPM release stops including `server_proxy.conf`, the play's final check fails with "access log stayed empty"; `nginx -t` still passes and nothing breaks, you just lose the gateway hop.
- **Pod log positions** are kept on each worker in `/var/lib/alloy`, so Alloy restarts do not re-ship or lose lines.
- **Control-plane node** is not scraped for logs: it is tainted for system pods and runs no application pods.

## Rollback

- Alloy on K3s: `kubectl delete namespace monitoring` also removes kube-state-metrics; to remove only Alloy: `kubectl -n monitoring delete ds alloy cm alloy-config` and `kubectl delete clusterrole,clusterrolebinding alloy`.
- Gateway: `rm /opt/nginx-proxy-manager/data/nginx/custom/{http_top,server_proxy}.conf && docker exec nginx-proxy-manager nginx -s reload`; `cd /opt/alloy && docker compose down`.
- Loki: `cd /opt/monitoring && docker-compose stop loki` (apps are unaffected; logs simply stop being searchable).
- Ingress format: re-apply the previous `k8s/ingress-configmap.yaml` from git history.
