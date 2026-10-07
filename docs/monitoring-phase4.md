# Monitoring, Phase 4: what the control room needs from the monitoring VM

Part of the observability plan (`tfd-blog-next/docs/OBSERVABILITY_CONTROL_ROOM_PLAN.md`, sections 7 and 8). Phase 4 is the admin UI at `/admin/ops` and the `/ops` API behind it, both in the application repos. The monitoring VM needs two small things, both in `playbooks/services/monitoring-setup.yml`.

## What changes here

| Change | Why |
|---|---|
| **Alertmanager is published on the LAN** (`9093:9093`, was `127.0.0.1:9093`) | The API pods read the firing alerts and create or end silences for the control room. Loki (`3100`) and Prometheus (`9090`) were already on the LAN. |
| **Alert messages end with an "Open in control room" link** to `<site>/admin/ops/alerts` | One tap from the Telegram message to the alert, with a Silence button. The origin is `CONTROL_ROOM_URL` (default `https://tfdevs.com`); the link is its own template file (`links.tmpl`) so `telegram.tmpl` stays a verbatim copy. |

Nothing else changes: no new container, no new rule, no change to routing, grouping or the heartbeat.

## Apply

```bash
cd ansible
set -a && . ./.env && set +a
ansible-playbook playbooks/services/monitoring-setup.yml
```

The play validates the Alertmanager configuration and templates with `amtool` before it restarts anything, and recreates the Alertmanager container to pick up the new port. Pending notifications are kept (the data directory is a volume); a one-minute gap in delivery is possible during the restart. `-e send_test_alert=true` sends one message, which now has the link.

Then give the API its addresses (secret `tfd-api-secrets`, SOPS, `tfd-api-next/k8s/secrets-example.yaml` lists every key): `LOKI_URL=http://192.168.100.220:3100`, `PROMETHEUS_URL=http://192.168.100.220:9090`, `ALERTMANAGER_URL=http://192.168.100.220:9093`, and the GlitchTip ones. Both the `tfd-api` and the `tfd-bot` pods read them (the bot answers `/status`, `/alerts`, `/incidents` and `/silence` in the ops group).

## Check

| Check | Expected |
|---|---|
| From a K3s worker: `curl -s http://192.168.100.220:9093/api/v2/status` | JSON with the cluster status |
| From a machine **outside** the LAN: nothing answers on `9093`, `9090` or `3100` | There is no tunnel route or proxy host for them; keep it that way |
| `amtool` check in the play output | `SUCCESS` |
| Send a test alert, or wait for a real one | The Telegram message ends with **Open in control room** |
| `/admin/ops/alerts` | The firing alerts; **Silence** creates a silence that Alertmanager lists at `:9093/#/silences` |

## Security

- **Alertmanager, Prometheus and Loki are unauthenticated on the LAN.** Anyone on the LAN can read logs, read metrics, and, through Alertmanager's API, **silence alerts**. That is the same trust level as the existing Prometheus and node-exporter ports, and the reason none of them may be published through Cloudflare or the gateway. If the LAN is ever shared with other devices, restrict `9093` to the K3s workers (host firewall on the monitoring VM) first.
- The control room never forwards a query to these services: the API builds every LogQL and PromQL expression itself from validated fields, and silences are exact-match only. The browser never reaches them.
- A silence made from the control room or Telegram records who made it and why; both show on the Alerts page.

## Roll back

Set the port back to `"127.0.0.1:9093:9093"` and re-run the play. The control room then shows "Alertmanager is not reachable" on the Alerts page and in the overview; everything else keeps working, and Telegram alerts are unaffected (Alertmanager sends them itself). To drop only the link, delete `links.tmpl` content's link text (the template must stay defined, possibly empty).
