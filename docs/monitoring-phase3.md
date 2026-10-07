# Monitoring, Phase 3: metrics depth and traces

Part of the observability plan (`tfd-blog-next/docs/OBSERVABILITY_CONTROL_ROOM_PLAN.md`, sections 6.3 and 6.5). Phase 1 gave you the logs of every request, Phase 2 the grouped errors. Phase 3 adds the two things that explain *why something is slow or failing*: **metrics** (rates, errors and durations per service, plus the databases) and **traces** (the path of one request through SSR, API, Redis and MongoDB).

## What runs where

```
 API / bot / SSR pods ---- /metrics (internal port 9464) ----> Alloy DaemonSet (on the same node)
                                                                  | remote write (with exemplars)
                                                                  v
 MongoDB / Redis exporters (database-vm) ----scrape----------> Prometheus (monitoring VM) <---- Tempo (span metrics, service graph)
 MinIO /minio/v2/metrics/cluster -----------scrape---------->      |
 ingress-nginx (optional) ---- Alloy ---------------------->      v
                                                                Grafana (TFD Services, TFD Datastores) --exemplar--> Tempo --span--> Loki

 API / bot / SSR pods ---- OTLP spans ----> alloy-traces (1 pod, tail sampling) ----> Tempo (monitoring VM, 7 days)
```

| Piece | Where | Notes |
|---|---|---|
| **Tempo** `2.8.2` | monitoring VM, docker compose | Single binary, local disk, 7 days. Memory soft limit 512 MiB. Its metrics generator writes span metrics and the service graph to Prometheus. Ports `3200` (query) and `4317` (OTLP/gRPC) on the LAN, no auth, like Loki. |
| **alloy-traces** | K3s `monitoring` namespace, 1 replica | Receives the spans and keeps **every trace with a server error or over 1 s, and 10 % of the rest**. One instance on purpose: tail sampling needs to see every span of a trace. |
| **Alloy DaemonSet** | K3s, every worker | New in this phase: scrapes pods annotated `prometheus.io/scrape: "true"` on its own node and writes to Prometheus with remote write. The metrics port is internal to the pod network; no ingress or Service routes to it. |
| **mongodb-exporter, redis-exporter** | database-vm | Next to the existing postgres-exporter. MongoDB gets a read-only `exporter` user. |
| **MinIO job** | Prometheus | Optional: needs a bearer token (below). |
| **ingress-nginx metrics** | K3s | Optional playbook; turns on the controller's own metrics. |
| **Prometheus** | monitoring VM | Now runs with `--web.enable-remote-write-receiver` and `--enable-feature=exemplar-storage`. |

New in Grafana: dashboards **TFD Services** (rate, errors, duration per service and route, latency heatmaps with trace links, runtime, realtime, notification outbox, service map) and **TFD Datastores**; a **Tempo** data source; click-through from a slow-request dot to its trace, from a trace to its log lines, from a log line (`traceId`) to its trace.

## Apply it (order matters)

Run these from `ansible/` after `set -a && . ./.env && set +a`.

1. **`.env`**: add `MONGO_EXPORTER_PASSWORD` (12+ letters and digits) from `.env.example`. `MINIO_PROMETHEUS_TOKEN` is optional (step 6).
2. **Exporters first**, so Prometheus has something to scrape when it learns about them:

   ```bash
   ansible-playbook playbooks/services/database-exporters-setup.yml
   ```

   It creates the MongoDB user `exporter` (roles `clusterMonitor` and `read` on `local`; the root password is read from the container, not passed in), starts `mongodb-exporter` (9216) and `redis-exporter` (9121), and checks that both reach their database.
3. **Monitoring VM**:

   ```bash
   ansible-playbook playbooks/services/monitoring-setup.yml
   ```

   Adds Tempo, the new Prometheus flags (the stack restarts: a short gap in graphs), the Tempo data source and trace links, the two dashboards and the new alert files `app.yml` and `datastores.yml`. It checks the Tempo and Prometheus configuration before it restarts anything.
4. **Cluster side** (needs step 3: it checks that Prometheus accepts remote writes and Tempo answers):

   ```bash
   ansible-playbook playbooks/kubernetes/alloy-setup.yml
   ```

   Rolls the Alloy DaemonSet (now with metrics scraping) and deploys `alloy-traces` with its Service `alloy-traces.monitoring.svc.cluster.local:4318`.
5. **Deploy the apps** (API first, then the frontend, as always): their manifests carry the scrape annotations, `METRICS_PORT`, the OTLP endpoint and, for the API, the new `/health/live` and `/health/ready` probes. Until they are deployed, `AppMetricsMissing` fires after 15 minutes: expected.
6. **MinIO metrics (optional).** MinIO's endpoint needs a token. On the machine where you have `mc`:

   ```bash
   mc alias set tfd http://192.168.100.206:9000 <MINIO_ROOT_USER> <MINIO_ROOT_PASSWORD>
   mc admin prometheus generate tfd cluster      # prints a prometheus.yml snippet with bearer_token
   ```

   Put the `bearer_token` value in `MINIO_PROMETHEUS_TOKEN` and re-run `monitoring-setup.yml`: the `minio` job then appears. It lands in a root-only file on the VM (never in the config). Leave it empty to skip MinIO. Use the address of the MinIO that the API really uses (`minio_metrics_target` in `monitoring-setup.yml`).
7. **ingress-nginx metrics (optional):** `ansible-playbook playbooks/kubernetes/ingress-metrics-setup.yml`. It turns on the controller's metrics and annotates its pod; the single controller pod is replaced with the new pod started first, so traffic keeps flowing.

## Done when

- Prometheus `/targets`: `mongodb`, `redis`, `tempo` UP; `/graph` shows `up{job=~"tfd-api|tfd-blog|tfd-bot"}` with `env`, `pod` and `namespace` labels.
- **TFD Services** shows requests/s and latency for the API and SSR. On the *latency distribution* heatmap, pink dots (exemplars) appear for slow or failed requests; clicking one opens the trace.
- A page view that calls the API produces **one trace across services**: Grafana, Explore, Tempo, search `service.name = tfd-blog`: the waterfall is `GET /verify/:code` (SSR), the call to the API, the API's handler, `redis-EVAL` (rate limiting) and `find certificates` (MongoDB, with the filter masked). The span `tfd.request_id` is the reference shown on the error page, so a trace can be searched by it (`{ span.tfd.request_id = "<id>" }`).
- From that trace, *Logs for this span* shows the log lines carrying the same `traceId`. From a log line in *TFD Requests*, the `traceId` link opens the trace.
- **The headline check**: pick a slow request on the heatmap, open its trace, find the slow span (a Redis or MongoDB call), and from the trace jump to its log lines.

## What the apps expose

- `GET /health/live`, `GET /health/ready` on the API: liveness never touches a dependency; readiness is 503 only when MongoDB is down (Redis or MinIO down is `degraded`, still in rotation, but alerted). The SSR app has `GET /api/health/ready`, which also asks the API; Kubernetes keeps using `/api/health` so an API outage shows the error page instead of removing every SSR pod.
- Metrics (port 9464, `/metrics`): `http_server_duration_seconds{method,route,status_class}`, `http_server_responses_total{status}`, `tfd_dependency_up{dependency}`, `tfd_realtime_*`, `tfd_notification_outbox{status}`, `process_*`, `nodejs_*`. Labels are route templates and fixed words only. Details: the "Metrics, health probes and traces" section of `tfd-api-next/docs/OBSERVABILITY.md` and "Metrics and traces" in `tfd-blog-next/docs/OBSERVABILITY.md`.
- Traces never carry query strings, client addresses, user agents, ids from a path, Mongo filter values, or Redis keys and values. The PDF renderer is not instrumented on purpose.

## Alerts added

`app.yml` (application symptoms), `datastores.yml`. Tested with `promtool test rules`, from `files/monitoring/prometheus/`:
`docker run --rm --entrypoint promtool -v "$PWD:/w" prom/prometheus:v2.48.1 test rules /w/tests/app.test.yml`. Thresholds are a first guess: tune them after two weeks of real data.

### AppHighErrorRate
More than 2 % of prod responses were 5xx for 5 minutes with real traffic (at least about 15 requests). Order of investigation: TFD Services (which route, since when), GlitchTip (the error and its stack), then the traces (Tempo, `status = error`) for the timing.

### ApiLatencyHigh
p95 above 1.5 s for the API (2 s for SSR) for 10 minutes. The latency heatmap has exemplars: open a slow trace and read which span is long. A long `redis-EVAL` means Redis or the network to it; a long `find ...` means a slow MongoDB query.

### AppMetricsMissing
No application series at all for 15 minutes (`AppMetricsEndpointDown` is one pod not answering). Check `kubectl -n monitoring logs ds/alloy` for remote write errors, that Prometheus runs with `--web.enable-remote-write-receiver` (`docker inspect prometheus`), and that the pods have the `prometheus.io/*` annotations and `METRICS_PORT`.

### DependencyUnreachable
`MongoUnreachableFromApi`, `RedisUnreachableFromApi`, `MinioUnreachableFromApi`, `ApiUnreachableFromSsr`, `DependencySlow`: the pods' own readiness check cannot reach a dependency. Find out whether it is the dependency (the `*Down` alerts and TFD Datastores) or only the network from the cluster. **A Redis outage makes API requests hang** (rate limiting waits for it): this is why `RedisUnreachableFromApi` is critical although the pod stays in rotation.

### NodeEventLoopLagging
The Node.js event loop is blocked (p99 over 0.5 s for 10 minutes): CPU-bound work or a memory squeeze. Check the pod's CPU and memory on TFD Services.

### AppMemoryNearLimit
RSS above 90 % of the container limit for 10 minutes; an OOM kill follows. Raise the limit in `k8s/prod/*.yaml` (the API went from 256 to 320 MiB in this phase to leave room for the instrumentation) or find the leak.

### NotificationOutboxStuck
A due Telegram notification has waited over 15 minutes, or failed rows keep growing (`NotificationsFailing`). The dispatcher in `tfd-bot` is stuck or Telegram rejects the messages: `kubectl -n prod logs deploy/tfd-bot-prod`, and the ops group for the dispatcher's own alerts.

### RealtimePublishFailing
Publishes to Redis keep failing (or `RealtimeHandshakeRejectionsSpike`: websocket handshakes are refused in bulk). Check Redis; after a deploy, check auth.

### ThrottlingSpike
Rate limiting answers 429 to over 1 request per second for 10 minutes, or logins fail at over 0.5 per second (`LoginFailureSpike`): a client bug looping, a scraper or credential stuffing. Loki: `{app="tfd-api"} | json | status = 429` shows routes and countries.

### TraceCollectorDroppingSpans
`alloy-traces` drops spans or cannot reach Tempo. `kubectl -n monitoring logs deploy/alloy-traces`, `docker logs tempo` on the monitoring VM. Tracing is best effort: nothing in the apps is affected.

### Datastores
`MongoDown`, `MongoConnectionsHigh`, `RedisDown`, `RedisMemoryHigh`, `RedisEvictingKeys`, `MinioDown`, `MinioDriveOffline`. `docker ps` and `docker logs <name>` on database-vm (MinIO: minio-vm). Not alerted: MongoDB replication lag (it is a single node, not a replica set) and backup age (planned for Phase 5).

## Running it

- **Memory on the monitoring VM** (6 GB): Prometheus, Loki (768 MiB soft limit), Tempo (512 MiB soft limit), Grafana, Alertmanager. After a week, check `docker stats --no-stream` and `free -m`; the plan (section 4.2) recommended 8 GB for the full stack. If it swaps, resize the VM.
- **Disk:** Tempo keeps 7 days under `/opt/monitoring/tempo/data`, small because most traces are dropped by the collector. Check `du -sh` after a week. Prometheus gains the app series; watch `prometheus_tsdb_head_series` (expect a few thousand more).
- **Sampling:** edit `alloy-traces.alloy` (`sampling_percentage`, `threshold_ms`) and re-run `alloy-setup.yml`; the collector pod rolls on the changed config.
- **Turn tracing off for one app:** remove `OTEL_EXPORTER_OTLP_ENDPOINT` from its deployment. Metrics off: remove `METRICS_PORT`.
- **Rollback:** the apps work without any of it. Remove the annotations, or just stop the collector (`kubectl -n monitoring delete deploy alloy-traces`); spans are then dropped silently.

## Notes and limits

- **SSR tracing is hand-made.** The Nuxt server's output is ESM and `http` is already loaded when plugins run, so the usual auto-instrumentation cannot attach. The access-log middleware starts the server span itself and outgoing `fetch` to the API is instrumented through `diagnostics_channel`. It was tested end to end on a built server (one trace across SSR, API, Redis and MongoDB), but a Nuxt or Nitro major upgrade is the moment to re-check it.
- **Browser tracing is not done.** Traces start at the Nuxt server (or the API for direct calls). Browser errors are linked to the API's own report through the request id (Phase 2).
- **GlitchTip links:** server error reports carry the `traceId` tag, so an error opens its trace.
- Exemplars are only attached to slow (over 1 s) and failed requests, because the collector always keeps those traces; a link on a fast request could point at a trace that was sampled out.
- Cloudflare-cached pages never reach the origin, so they are in Cloudflare analytics, not here (unchanged since Phase 1).
