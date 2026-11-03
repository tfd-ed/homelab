# Flood of requests on the API

**Alert:** `ThrottlingSpike` (the API answers 429 to more than 1 request a second for 10 minutes). **Type:** abuse, SEV3. SEV2 if the SLO burn alerts fire too.

A 429 means the rate limiter is doing its job. The question is whether the flood is hurting real visitors (latency, 5xx) and whether it is one broken client or many sources.

## First five minutes

1. Open the incident (`/admin/ops/incidents`) and **Acknowledge**.
2. Look at the damage first: Overview (`/admin/ops`) for the API error ratio and p95, Reliability (`/admin/ops/reliability`) for the SLO burn. If real visitors are hurt, treat it as SEV2.
3. Find who and what. In Grafana Explore (Loki) run
   `sum by (ip) (count_over_time({app="tfd-api"} | json | status = 429 [10m]))`, then the same with `by (route)`, `by (country)`. The Requests page (`/admin/ops/requests`, filter by status class 4xx and a route or an IP) shows individual lines.
4. Decide what it is:
   - **One IP or a few, same route, same user agent:** a looping client or a scraper. Go to step 5.
   - **Many IPs, one route:** a distributed flood or a bug in our own frontend after a deploy. Check the Deployments page; if a deploy finished just before, see [bad-deploy.md](bad-deploy.md).
   - **Our own address** (the SSR pods or the monitoring probes) in the top list: a bug on our side, not an attack. Do not block it; find what is looping.
5. Block a source: Cloudflare dashboard, the zone, **Security**, **WAF**, **Tools**, **IP Access Rules**: add the IP with action **Block** and a note with the date and the incident. (Menu names change; look for "IP Access Rules".) Before blocking, look at the user agents and paths: an office or a school can share one public IP, and a block takes a whole classroom off the site.
6. Tighten the route if the sources keep changing: lower the `@Throttle` limit on that handler in `tfd-next-api`, through a pull request (the three tiers are 10 per second, 120 per minute and 600 per 15 minutes, see `src/config/throttler.config.ts`). A deploy needs a merged pull request, so this takes minutes, not seconds.

## Then

- Watch the 429 rate fall in Grafana; the alert resolves 10 minutes after it stops.
- If it is a real attack and Cloudflare is overloaded, the zone-wide switch is **Security**, **Settings**, **Security level** or the **Under Attack** mode. It challenges every visitor, so it costs real users too: turn it off when the flood ends.

## Do not

- Do not turn the rate limiter off or raise its limits to make the alert go away.
- Do not add custom rules in the Cloudflare dashboard (they conflict with the Terraform-managed ruleset, see the [README](README.md)).
- Do not block Cloudflare or our own addresses.

## Afterwards

- **Remove the IP Access Rules** you added when the flood is over: they do not expire.
- Resolve the incident. A write-up is required if it was SEV2 or worse; otherwise note the cause in the incident's owner field.
- If one route needed a stricter limit, that change is the follow-up action.
