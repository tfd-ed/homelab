# Runbooks

One short page for each kind of incident that cannot wait for a pull request. Each starts with **the first five minutes** as numbered steps: do those in order, then read the rest.

They are written for one operator with `kubectl`, SSH to the VMs and the control room (`/admin/ops`). Nothing here needs a model or an agent. The incident desk (`/admin/ops/incidents`) links each incident to its runbook through the alert's `runbook` annotation.

| Runbook | Alerts and signals | Type, usual severity |
|---|---|---|
| [api-flood.md](api-flood.md) | `ThrottlingSpike` | abuse, SEV3 |
| [login-failures.md](login-failures.md) | `LoginFailureSpike` | abuse, SEV3 |
| [password-account-in-prod.md](password-account-in-prod.md) | `PasswordAccountCreatedInProd` | security, SEV1 |
| [bad-deploy.md](bad-deploy.md) | Deployments page verdict **More errors**, `AppHighErrorRate` right after a deploy | regression, SEV2 |
| [third-party-outage.md](third-party-outage.md) | sign-in, payment, Telegram, Cloudflare or GitHub failing | dependency, SEV2 or SEV3 |
| [backup-stale.md](backup-stale.md) | `BackupStale`, `BackupLastRunFailed`, `BackupTooSmall` | data, SEV2 |

## How to use one

1. Open the incident in the control room and press **Acknowledge**. That starts the clock and tells the next person it has an owner.
2. Do the first five minutes. Write down what you did and when; the write-up needs it.
3. When it is calm, resolve the incident. For SEV1 and SEV2, and for every security and data incident, press **Copy write-up** on the incident page and fill it in (`tfd-blog-next/docs/incidents/`).

## Writing a new one

Same shape: *When*, *First five minutes* (numbered, at most seven), *Then*, *Do not*, *Afterwards*. Link it from the alert's `runbook` annotation as `homelab-journey/docs/runbooks/<name>.md` and add it to the table above. The classification table of the API (`tfd-next-api`, `classification.table.ts`) decides the type and severity; this folder decides what a person does.

## Cloudflare note

The zone's custom rules and the rate limit are managed by Terraform in `tfdevs-infra` (`modules/cloudflare/waf_api.tf`), and a zone can have only one ruleset per phase. In an emergency **do not add custom rules in the dashboard**: they would fight the Terraform ruleset. Use **IP Access Rules** (a separate list, see api-flood.md) for a quick block, and put anything lasting into `waf_api.tf` through a pull request.
