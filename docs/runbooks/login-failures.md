# Failed sign-in attempts

**Alert:** `LoginFailureSpike` (4xx answers on `/auth/login*` above 0.5 a second for 10 minutes). **Type:** abuse, SEV3.

**The important fact:** in production there is **no password sign-in** (SSO only). `POST /auth/login` and `/auth/login-cookie` answer 404 there, and the API refuses to start with password auth enabled outside dev. So bots guessing passwords cannot succeed; they are probing an endpoint that does not exist. What this alert can still mean is a broken sign-in flow after a deploy, or a scan that precedes something worse.

## First five minutes

1. Open the incident and **Acknowledge**.
2. Open the Requests page (`/admin/ops/requests`), route `/auth/login`, last hour. Look at the **status**:
   - **404 from a few IPs or countries:** scanners and credential-stuffing tools hitting a missing endpoint. Harmless; go to step 4.
   - **401 or 400 for ordinary users, or any 5xx:** sign-in is broken for real people. Check the Deployments page: if a deploy finished just before, see [bad-deploy.md](bad-deploy.md). Also check Google's status ([third-party-outage.md](third-party-outage.md)).
3. Check nothing got in: the alerts `PasswordAccountCreatedInProd` and `AccountCreationSurge` must be quiet. If either is firing, stop and open [password-account-in-prod.md](password-account-in-prod.md).
4. If the volume keeps up, block the top sources as in step 5 of [api-flood.md](api-flood.md) (Cloudflare **IP Access Rules**). The zone already has a brake on `/auth/*` (30 requests per 10 seconds per IP and data centre); look in Cloudflare **Security**, **Events** to see it working.
5. Confirm the endpoints are still absent: `curl -s -o /dev/null -w '%{http_code}\n' -X POST https://api.tfdevs.com/auth/login` must not be 200 or 401. A 401 would mean password auth is on; treat that as the password-account runbook.

## Then

- If, against all of the above, an account did sign in that should not have: remove its ability to refresh. On the database VM, `docker exec -it mongodb mongosh -u admin --authenticationDatabase admin`, then in the prod database (`tfd-api-db-prod`): `db.users.updateOne({_id: ObjectId("<id>")}, {$unset: {refreshToken: ""}})`. Its current access token stays valid until it expires, so also restart the API pods: `kubectl -n prod rollout restart deployment/tfd-api-prod`.

## Do not

- Do not enable password sign-in to "test" something in prod.

## Afterwards

Resolve the incident. No write-up is needed for a 404 scan; note the date and the top sources in the owner field if it repeats, because a repeat is a reason to put a WAF rule into `waf_api.tf`.
