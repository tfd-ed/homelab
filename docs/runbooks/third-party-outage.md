# A third party is failing

**Type:** dependency, SEV2 if sign-in or payment is affected, otherwise SEV3. There is no single alert for this: you notice it as a failing synthetic journey (`SyntheticProdJourneyDown`), a spike of errors on one route, a Telegram bot that stops answering, or a student telling you. Work out *which* provider first.

| What is broken | Provider | Where it shows | Status page |
|---|---|---|---|
| Sign-in with Google | Google (OAuth) | the `login` journey fails, errors on `/auth/google/callback` | https://www.google.com/appsstatus/dashboard/ |
| The site, the API, DNS, the tunnel | Cloudflare | `HttpProbeFailed`, `TunnelDegraded`, everything at once | https://www.cloudflarestatus.com |
| Paying by KHQR | Cutluy | errors on the payment checkout and webhook routes, students cannot pay | no public page known: test the API from your side and ask the provider |
| Telegram notifications and the ops group | Telegram | the bot logs `Telegram bot init failed` or send errors, `NotificationsFailing` | no official page: check the bot log and try the bot by hand |
| Deploys | GitHub | a deploy workflow fails or never starts | https://www.githubstatus.com |
| Meet and Calendar links | Google | session creation fails | the Google page above |

## First five minutes

1. Open the incident and **Acknowledge**.
2. Confirm it is them and not us: read the provider's status page from the table; then from the API logs (`/admin/ops/requests`, the failing route, the error text) check that the failure is the call out, not our own code. If a deploy finished just before, rule it out with [bad-deploy.md](bad-deploy.md) first.
3. Say what is affected, in one line, to the people who need to know: students (class Telegram groups, if Telegram itself is up) or whoever runs support. Do not promise a time.
4. Stop our side making it worse, only if it is: a failing provider with a retry loop in our code. The bot's switches are `TELEGRAM_BOT_ENABLED` and `TELEGRAM_USERBOT_ENABLED` in the API secret (`tfd-api-secrets`, edited with SOPS and applied by a redeploy). Use them only if the bot is flooding a failing Telegram API; there is no switch for payments or sign-in.
5. If payments are down and a student's installment falls due, **extend the due date** for those students from the admin (Enrollments, the extend-installment action) so nobody is locked out of content because a provider failed. See `tfd-blog-next/docs/POSTPONE_AND_INSTALLMENT_PLAN.md`.

## Then

- Re-check the provider's page every 15 minutes and keep the incident open; there is nothing to fix on our side.
- When it recovers, test the real path once: sign in with Google, open a checkout, send a bot message. Resolve only after that.

## Do not

- Do not roll back a deploy for a provider's outage.
- Do not change secrets or rotate keys because a provider is down.
- Do not edit Cloudflare, DNS or the tunnel while Cloudflare itself is the problem.

## Afterwards

Resolve the incident. A SEV2 needs a short write-up; record how long it lasted, what students saw and whether a switch or a notice would have helped. If you found yourself wishing for a switch (payments, sign-in), that is a follow-up action.
