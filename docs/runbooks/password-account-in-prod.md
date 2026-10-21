# A password account was created in production

**Alert:** `PasswordAccountCreatedInProd` (the API counted an account created with a password). **Type:** security, **SEV1** until cleared. A write-up is always required.

Production is SSO only. A password account means the door that was closed on 2026-10-16 is open again, or something is writing users some other way. Background and the full story: `tfd-blog-next/docs/SECURITY_INCIDENT_PASSWORD_REGISTRATION_2026-10-16.md`.

## First five minutes

1. Open the incident and **Acknowledge**. Do not announce it anywhere public yet.
2. **Preserve the evidence before changing anything.** In the Requests page (`/admin/ops/requests`), route `/auth/register` or `POST /users`, last 24 hours: note the time, the IPs and the request ids (`/admin/ops/reference/<id>` shows every line for one). Copy them into the write-up (**Copy write-up** on the incident page).
3. Find the account. On the database VM: `docker exec -it mongodb mongosh -u admin --authenticationDatabase admin`, then
   `use tfd-api-db-prod`
   `db.users.find({password: {$exists: true}}, {username: 1, email: 1, roleId: 1, createdAt: 1, refreshToken: 1})`
   (the projection leaves the hash out; do not print it). The Admin's own password may still be there if it has not been removed yet; look for accounts created in the last day.
4. **Lock it.** Remove what lets it sign in and refresh: `db.users.updateOne({_id: ObjectId("<id>")}, {$unset: {password: "", refreshToken: ""}})`. An access token already issued works until it expires, and the API may keep the user in memory, so restart the API: `kubectl -n prod rollout restart deployment/tfd-api-prod`.
5. **Close the door.** Check all three, in this order:
   - The edge still blocks registration: `curl -s -o /dev/null -w '%{http_code}\n' -X POST https://api.tfdevs.com/auth/register` must be 403 (Cloudflare) or 404, never 201. The rule is "Block self-registration" in `tfdevs-infra/modules/cloudflare/waf_api.tf`; confirm it is enabled in Cloudflare **Security**, **WAF**.
   - `kubectl -n prod get deploy tfd-api-prod -o yaml | grep -i -E 'PASSWORD_AUTH|APP_ENV'`: `PASSWORD_AUTH_ENABLED` must not be `true` and `APP_ENV` must be `prod`. The API refuses to start with password auth on outside dev, so a running pod that disagrees means the deployment or the secret was changed.
   - `kubectl -n prod rollout history deployment/tfd-api-prod`: was there a deploy at the time of the first request?
6. Check what the account touched, before anyone deletes it: search the collections that reference users (enrollments, exam attempts, certificates, notifications; the 2026-10-16 investigation counted 19) for its `_id`.

## Then

- When the evidence is saved and nothing references the account, hard-delete it: `db.users.deleteOne({_id: ObjectId("<id>")})`. Delete is irreversible; the evidence file is your record.
- Find how it happened (a deploy that re-enabled a route, a changed secret, a second write path) and fix that through a pull request.
- Rotate anything the account could have reached if it had a role above `Student`.

## Do not

- Do not delete the account before the evidence is saved.
- Do not "fix" it by turning password auth on in prod to get at the account.
- Do not leave the incident unresolved without a write-up: this one is always documented.

## Afterwards

Resolve, then write it up in `tfd-blog-next/docs/incidents/` (**Copy write-up** gives you the draft with the timeline filled in). Add the cause to the alert's description if it was something the alert could have said.
