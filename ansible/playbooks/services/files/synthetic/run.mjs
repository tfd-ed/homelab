// Runs every configured journey once and writes the result as node-exporter textfile metrics.
// Started every 10 minutes by a systemd timer (synthetic-setup.yml), in the Playwright container.
//
//   SYNTH_PROD_SITE      https://tfdevs.com            public journeys on production (skip when empty)
//   SYNTH_PROD_API       https://api.tfdevs.com        API of production, to find a published course (read only)
//   SYNTH_DEV_SITE       https://dev.tfdevs.com        public journeys on dev (skip when empty)
//   SYNTH_DEV_API        https://api-dev.tfdevs.com    API of dev, for the sign-in
//   SYNTH_DEV_USER/PASS  a dedicated dev account; the signed-in journeys are skipped without them
//   SYNTH_DEV_ADMIN      1 when that account may open /admin/users
//   SYNTH_METRICS_FILE   /textfile/synthetic.prom      SYNTH_STATE_FILE /state/state.json
//   SYNTH_ARTIFACTS_DIR  /artifacts                    screenshots of failed journeys (newest 50 kept)
import { chromium } from 'playwright'
import { mkdir, readdir, readFile, rename, stat, unlink, writeFile } from 'node:fs/promises'
import { join } from 'node:path'
import { JOURNEY_TIMEOUT_MS, USER_AGENT, artifactsToDelete, nextState, renderMetrics, stamp } from './lib.mjs'
import { publicJourneys, signedInJourneys } from './journeys.mjs'

const env = process.env
const metricsFile = env.SYNTH_METRICS_FILE || '/textfile/synthetic.prom'
const stateFile = env.SYNTH_STATE_FILE || '/state/state.json'
const artifactsDir = env.SYNTH_ARTIFACTS_DIR || '/artifacts'
const only = env.SYNTH_ONLY ? new Set(env.SYNTH_ONLY.split(',')) : undefined

const journeys = []
if (env.SYNTH_PROD_SITE) journeys.push(...publicJourneys('prod', env.SYNTH_PROD_SITE.replace(/\/$/, ''), env.SYNTH_PROD_API?.replace(/\/$/, '')))
if (env.SYNTH_DEV_SITE) {
  const base = env.SYNTH_DEV_SITE.replace(/\/$/, '')
  journeys.push(...publicJourneys('dev', base, env.SYNTH_DEV_API?.replace(/\/$/, '')))
  if (env.SYNTH_DEV_API && env.SYNTH_DEV_USER && env.SYNTH_DEV_PASS) {
    journeys.push(...signedInJourneys('dev', base, env.SYNTH_DEV_API.replace(/\/$/, ''), {
      username: env.SYNTH_DEV_USER,
      password: env.SYNTH_DEV_PASS,
      admin: env.SYNTH_DEV_ADMIN === '1',
    }))
  } else {
    console.log('signed-in journeys skipped: set SYNTH_DEV_API, SYNTH_DEV_USER and SYNTH_DEV_PASS')
  }
}
const selected = journeys.filter((j) => !only || only.has(`${j.env}/${j.name}`))
if (!selected.length) {
  console.error('no journey configured')
  process.exit(2)
}

await mkdir(artifactsDir, { recursive: true })
const browser = await chromium.launch()
const results = []
for (const journey of selected) {
  const context = await browser.newContext({ userAgent: USER_AGENT, viewport: { width: 1280, height: 800 }, locale: 'en-GB' })
  context.setDefaultTimeout(JOURNEY_TIMEOUT_MS)
  const page = await context.newPage()
  const started = performance.now()
  let ok = true
  try {
    await Promise.race([
      journey.run({ page, context }),
      new Promise((_, reject) => setTimeout(() => reject(new Error(`timed out after ${JOURNEY_TIMEOUT_MS / 1000} s`)), JOURNEY_TIMEOUT_MS)),
    ])
  } catch (err) {
    ok = false
    console.error(`FAIL ${journey.env}/${journey.name}: ${String(err.message).split('\n')[0]}`)
    await page.screenshot({ path: join(artifactsDir, `${stamp(new Date())}-${journey.env}-${journey.name}.png`), fullPage: true }).catch(() => {})
  }
  const seconds = (performance.now() - started) / 1000
  if (ok) console.log(`ok   ${journey.env}/${journey.name} ${seconds.toFixed(1)}s`)
  results.push({ env: journey.env, journey: journey.name, ok, seconds })
  await context.close()
}
await browser.close()

const now = Math.floor(Date.now() / 1000)
let previous = {}
try { previous = JSON.parse(await readFile(stateFile, 'utf8')) } catch { /* the first run has no state */ }
const state = nextState(previous, results, now)
await mkdir(join(stateFile, '..'), { recursive: true })
await writeFile(stateFile, JSON.stringify(state))

// Written aside and renamed: node-exporter must never read half a file.
await writeFile(`${metricsFile}.tmp`, renderMetrics(results, state, now))
await rename(`${metricsFile}.tmp`, metricsFile)

const files = await Promise.all((await readdir(artifactsDir)).filter((n) => n.endsWith('.png')).map(async (name) => ({ name, mtimeMs: (await stat(join(artifactsDir, name))).mtimeMs })))
await Promise.all(artifactsToDelete(files).map((name) => unlink(join(artifactsDir, name))))

process.exit(results.every((r) => r.ok) ? 0 : 1)
