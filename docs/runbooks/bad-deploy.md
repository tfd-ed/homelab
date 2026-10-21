# A deploy made things worse

**Signal:** the Deployments page (`/admin/ops/deployments`) shows the verdict **More errors** for the newest deploy, or `AppHighErrorRate` / an SLO burn alert starts right after a deploy finished. **Type:** regression, SEV2 (SEV1 if sign-in, enrollment or payment is down).

The Deployments page compares the 5xx share of the service in the 30 minutes before and after the deploy. It is a hint, not proof: read the errors before you act.

## First five minutes

1. Open the incident (or the Deployments page) and **Acknowledge**. Note which service it is: **web** (`tfd-blog`) or **API** (`tfd-api`, which also ships the bot and the PDF service).
2. Confirm it is the deploy: Overview (`/admin/ops`) and the Requests page (status class 5xx, last hour). Did the errors start within minutes of the deploy time, and are they on routes that changed? If the errors are 429s, it is a flood instead ([api-flood.md](api-flood.md)).
3. Find the **previous good deploy** of the same service on the Deployments page (the row below the failing one) and note its sha.
4. **Roll back by hand.** The old pods are still known to Kubernetes (`revisionHistoryLimit` keeps the last three):
   - Web: `kubectl -n prod rollout undo deployment/tfd-blog-prod`
   - API: a deploy updates `tfd-api-prod`, `tfd-bot-prod` and `tfd-pdf-prod` to the same image, so undo all three: `kubectl -n prod rollout undo deployment/tfd-api-prod`, then `tfd-bot-prod`, then `tfd-pdf-prod`.
   - To go to a specific build instead of the previous one: `kubectl -n prod set image deployment/tfd-api-prod tfd-api=registry.homelab.local/tfd-api:prod-<sha>` (web: container `tfd-blog` and image `registry.homelab.local/tfd-blog:prod-<sha>`; the bot container is `tfd-bot` and the PDF one `tfd-pdf`, both with the same API image).
5. Watch it come back: `kubectl -n prod rollout status deployment/tfd-api-prod`, then the 5xx share on the Overview page for five minutes.
6. Say so in the incident (owner, and a line in the write-up draft): "rolled back to `<sha>` at `<time>`".

## Then

- The rollback is temporary: the next deploy puts the broken code back. **Fix forward through a pull request**, which is also what the deploy guard requires (a deploy only runs for a merged pull request). The fastest is a revert of the offending merge commit: `git revert -m 1 <merge sha>` on a branch, open the pull request, merge it into `develop`, check dev, then promote to `master`. (When the fix agent exists, plan phase 6, it may propose the roll-forward as a draft pull request. A person still merges.)
- If the deploy changed data (a migration-like script, a backfill), a code rollback does not undo it. Look before you assume.
- Do not re-run the failed deploy workflow to "try again".

## Do not

- Do not push to `master` or `develop` directly (branch protection rejects it, and the deploy guard would refuse the deploy anyway).
- Do not roll back the database: nothing in the code needs it, and a restore loses everything written since.
- Do not roll back a deploy that is not the cause because the verdict said so; read the errors.

## Afterwards

Resolve the incident, write it up if it was SEV1 or SEV2 (**Copy write-up** fills in the deploy as part of the timeline), and add a test that would have caught it to the revert's replacement.
