# Monitoring, Phase 2: error tracking (GlitchTip)

Part of the observability plan (`tfd-blog-next/docs/OBSERVABILITY_CONTROL_ROOM_PLAN.md`, section 6.1). Phase 1 gives you the logs of every request; Phase 2 turns an unexpected error into **one grouped issue** with its stack, release, environment and the same request id the logs use, and tells the ops Telegram group when a new one appears.

## What runs where

```
Browser --POST tfdevs.com/_t/events--> Nuxt pod --http--> glitchtip (K3s, namespace glitchtip) --> Postgres on database-vm
Nuxt pod (SSR errors) ----------------------http--------> glitchtip
API / bot pod (5xx errors) -----------------http--------> glitchtip
glitchtip --webhook (new issue)--> tfd-bot Service (in the cluster) --> Telegram ops group, "errors" topic
Admin (browser) --https://errors.tfdevs.com, Cloudflare Access SSO--> glitchtip UI
```

- **One pod**, `glitchtip/glitchtip:6` in `all_in_one` mode (web and background worker in one process), no Valkey (the task queue lives in Postgres), about 200 MB of memory. It is in K3s like Plausible, not on the monitoring VM, which is already busy with Loki.
- **Database**: `glitchtip_db` on the existing Postgres on `database-vm`. The nightly `pg_dumpall` backup from `database-setup.yml` covers it. Events are kept 30 days (`GLITCHTIP_RETENTION_DAYS`).
- **Uploads volume**: a 2 GB PVC (`glitchtip-uploads`) holds uploaded source maps. **Keep the PVC and the database together**: if the PVC is lost while the database is kept, new source-map uploads fail until the stale upload records are cleared. Losing both is harmless (CI re-uploads on the next deploy).
- **Only the UI is public** (`errors.tfdevs.com`, behind Cloudflare SSO). Events never use that hostname: browsers post to the site's own `/_t/events` and the servers use the in-cluster Service.

## Apply it (order matters)

1. **`tfdevs-infra`**, branch `feat/errors-phase2`: `terraform plan`, review, apply. Creates the DNS record, tunnel rule, NPM proxy host and Access application for `errors.tfdevs.com`, plus the narrow Access exception for source-map upload (see below).
2. **This repo**:

   ```bash
   cd ansible
   POSTGRES_PASSWORD=... GLITCHTIP_DB_PASSWORD=... GLITCHTIP_SECRET_KEY=$(openssl rand -hex 32) \
     ansible-playbook playbooks/services/glitchtip-setup.yml
   ```

   Keep `GLITCHTIP_SECRET_KEY` somewhere safe and use the same value every time you re-run: changing it logs everyone out and invalidates tokens. The play checks that the web app answers inside the cluster at the end. `GLITCHTIP_EMAIL_URL=smtp://user:pass@host:587` is optional; without it GlitchTip prints its emails (invitations, password resets) to the pod log (`kubectl -n glitchtip logs deploy/glitchtip`).
3. **Create your account.** Registration is open on the first run. Open `https://errors.tfdevs.com`, register, then **close registration** by re-running the play with `GLITCHTIP_REGISTRATION=False` (same other variables). Invite the other admins from the UI afterwards.
4. **In GlitchTip**: create the organisation with the slug **`tfd`** (the CI workflows use it) and four projects, platform JavaScript for the web ones and Node for the API ones. Use these names, they become the slugs the CI uses: `tfd-web-prod`, `tfd-web-dev`, `tfd-api-prod`, `tfd-api-dev`. Each project's settings page shows its DSN.
5. **Give the apps their DSN**, then deploy them (API first, as always):

   | Secret | Where | Value |
   |---|---|---|
   | `NUXT_PUBLIC_SENTRY_DSN` | `tfd-blog-next` `k8s/secrets.<env>.yaml` (SOPS) | The web project's DSN as shown: `https://<key>@errors.tfdevs.com/<id>` |
   | `SENTRY_DSN` | `tfd-api-next` `k8s/secrets.<env>.yaml` (SOPS) | The api project's DSN **with the host replaced by the in-cluster one**: `http://<key>@glitchtip.glitchtip.svc.cluster.local:8000/<id>` |
   | `OPS_WEBHOOK_KEY` | `tfd-api-next` `k8s/secrets.prod.yaml` | `openssl rand -hex 24` |
   | `TELEGRAM_OPS_ERRORS_THREAD_ID` | `tfd-api-next` `k8s/secrets.prod.yaml`, optional | Forum topic id for error alerts (see below) |

   Without a DSN a service simply does not report: nothing breaks. Edit SOPS files with `sops` as usual; the apps restart when the secret changes (Reloader).
6. **The alert** (prod projects; do the dev ones too if you want dev noise in Telegram): project, **Alerts**, **Add alert**: *1 event in 1 minute* (an alert for every new issue). Add recipient type **Webhook** with the URL

   `http://tfd-bot-service.prod.svc.cluster.local/ops/alerts/glitchtip?key=<OPS_WEBHOOK_KEY>`

   and set **Tags to add** to `requestId` and `route`. The URL points at the bot Service inside the cluster (GlitchTip is allowed to call private addresses, `GLITCHTIP_ALLOW_PRIVATE_IPS`); the bot's public ingress only routes the Telegram webhook, so this route is not reachable from the internet. The same URL with `dev` instead of `prod` works for the dev projects, with the dev `OPS_WEBHOOK_KEY`.
7. **Telegram topic** (optional): in the ops group, create a topic "errors", send any message in it, and read its `message_thread_id` (forward the message to `@RawDataBot`, or open the topic link `t.me/c/<chat>/<thread>`). Put it in `TELEGRAM_OPS_ERRORS_THREAD_ID`. Unset, alerts go to the group's main thread.
8. **CI source maps** (optional but recommended): in GlitchTip, Profile, **Auth Tokens**, create a token with the scopes `project:read`, `project:releases`, `org:read`, and save it as the secret `GLITCHTIP_AUTH_TOKEN` in the GitHub environments `prod` and `dev` of `tfd-blog-next`. See "Source maps" below.

## Done when

- `curl -s -o /dev/null -w '%{http_code}\n' -X POST https://tfdevs.com/_t/events -d '{}'` prints **400** (the tunnel is alive and refusing junk; 404 means no DSN is configured).
- In the browser console of tfdevs.com:
  `document.querySelector('#__nuxt').__vue_app__.config.globalProperties.$nuxt.callHook('vue:error', new Error('GlitchTip smoke test'), null, 'manual')`
  creates an issue in `tfd-web-prod` within a minute, with release, environment and breadcrumbs, and the Telegram message arrives in the errors topic. (This tests the path; the stack of such a hand-made error is not from the bundle, so it is not a source-map test. For that, the next real error is the test: its frames show `app/...vue` file names and lines instead of `abc123.js:2:23747`.)
- Open any issue from a real failure: the `requestId` tag, searched in Grafana Explore (`{env="prod"} |= "<id>"`), finds the ingress, SSR and API lines for the same request.

## Source maps and the Cloudflare exception

The deploy workflows build the web image with source maps, upload them to GlitchTip, and ship an image without them. The CLI cannot send Cloudflare Access service-token headers and must talk to the address GlitchTip advertises, `https://errors.tfdevs.com`, so `tfdevs-infra` has a separate Access application (`errors_sourcemap_upload`) with a **bypass** policy for exactly two paths: `/api/0/organizations/tfd/chunk-upload` and `/api/0/organizations/tfd/artifactbundle`. GlitchTip still demands the API token on both. To turn the upload off, delete that resource and apply (or remove the `GLITCHTIP_AUTH_TOKEN` secret): deploys keep working, stack traces just stay minified. After applying, check the exception is exactly that narrow: `curl -s -o /dev/null -w '%{http_code}\n' https://errors.tfdevs.com/api/0/organizations/tfd/chunk-upload/` should return 401 (GlitchTip, no token), while `https://errors.tfdevs.com/` should still redirect to the Access login. If Access treats the path as an exact match rather than a prefix, the upload step logs 302 errors in the workflow; widen the two paths with a trailing `*`.

## Running it

- **Logs**: `kubectl -n glitchtip logs deploy/glitchtip`. **Restart**: `kubectl -n glitchtip rollout restart deploy/glitchtip` (a few seconds of downtime; apps keep running and drop reports meanwhile).
- **Health**: the generic Phase 0 alerts already cover this namespace (pod not ready, crash loop, replicas unavailable), at warning level.
- **Upgrade**: GlitchTip publishes major versions on https://glitchtip.com/blog/. The tag is `glitchtip_version` in `glitchtip-setup.yml` (currently `6`). Read the release notes, back up the database (`docker exec postgres pg_dump -U postgres glitchtip_db | gzip > ...` on `database-vm`), change the tag, re-run the play. Migrations run on start.
- **Disk**: errors are small. Check `du -sh` of the database (`SELECT pg_size_pretty(pg_database_size('glitchtip_db'));`) after a month; retention (`GLITCHTIP_RETENTION_DAYS`) is in the manifest template.
- **Rollback**: `kubectl delete namespace glitchtip` removes the pod, PVC and Service; the database stays on `database-vm` (drop it by hand if you want it gone). The apps keep working without it.

## Notes and limits

- **Not reported**: 4xx responses (the user's mistakes; they are in the request log), and errors a background job catches and logs itself (those are in Loki only). A browser that is offline cannot report anything.
- **Privacy**: reports carry the user id and role and never cookies, headers, bodies, query strings, IPs, emails or variable values (details in the two `docs/OBSERVABILITY.md` files). Source code lines around a frame are included.
- **`ALLOWED_HOSTS` warning** in the GlitchTip log is expected: the pod is reachable only through the ingress and its Service. Restricting it would break the Kubernetes probes, which use the pod IP as host.
- **GlitchTip's own beta CLI (`glitchtip-cli` 1.0.0) uploads source maps in a format GlitchTip 6 rejects.** The workflows use the official `sentry-cli` instead. Revisit when GlitchTip documents a fix.
- GlitchTip tracing, session replay, profiling and uptime monitoring are switched off or unused; traces come with Phase 3 through OpenTelemetry.
