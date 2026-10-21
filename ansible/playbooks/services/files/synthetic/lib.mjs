// Pure helpers of the synthetic runner: no browser, no network, so they are unit tested
// (lib.test.mjs) and the browser part stays thin.

/** Every request of a journey carries this, so the site, the API and the logs can tell it from a visitor. */
export const SYNTHETIC_UA_TOKEN = 'TFD-Synthetic/1.0'
export const USER_AGENT = `Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 ${SYNTHETIC_UA_TOKEN}`

/** Seconds a journey may take before it counts as failed. */
export const JOURNEY_TIMEOUT_MS = 45_000

/** `env/journey` key of the state file. */
export const keyOf = (env, journey) => `${env}/${journey}`

/**
 * What the last run decided, given what came before. `results` are `{ env, journey, ok, seconds }`;
 * `previous` is the old state (`{ "prod/home": { consecutiveFailures: 2, lastSuccess: 1700000000 } }`).
 * A journey that did not run this time (no credentials, say) keeps nothing: it leaves the file.
 */
export function nextState(previous, results, nowSeconds) {
  const state = {}
  for (const r of results) {
    const before = previous?.[keyOf(r.env, r.journey)]
    state[keyOf(r.env, r.journey)] = {
      consecutiveFailures: r.ok ? 0 : (before?.consecutiveFailures ?? 0) + 1,
      lastSuccess: r.ok ? nowSeconds : before?.lastSuccess ?? 0,
    }
  }
  return state
}

const esc = (v) => String(v).replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n')
const labels = (r) => `{journey="${esc(r.journey)}",env="${esc(r.env)}"}`

/** The node-exporter textfile body. `state` is the one `nextState` returned. */
export function renderMetrics(results, state, nowSeconds) {
  const lines = []
  const family = (name, help, type = 'gauge') => lines.push(`# HELP ${name} ${help}`, `# TYPE ${name} ${type}`)

  family('synthetic_success', '1 if the journey passed in its most recent run, else 0')
  for (const r of results) lines.push(`synthetic_success${labels(r)} ${r.ok ? 1 : 0}`)

  family('synthetic_duration_seconds', 'How long the most recent run of the journey took')
  for (const r of results) lines.push(`synthetic_duration_seconds${labels(r)} ${r.seconds.toFixed(3)}`)

  family('synthetic_consecutive_failures', 'Runs in a row that failed (0 after a pass)')
  for (const r of results) lines.push(`synthetic_consecutive_failures${labels(r)} ${state[keyOf(r.env, r.journey)].consecutiveFailures}`)

  family('synthetic_last_success_timestamp_seconds', 'Unix time of the last pass (0 if it never passed)')
  for (const r of results) lines.push(`synthetic_last_success_timestamp_seconds${labels(r)} ${state[keyOf(r.env, r.journey)].lastSuccess}`)

  family('synthetic_last_run_timestamp_seconds', 'When the runner last finished, for any journey')
  lines.push(`synthetic_last_run_timestamp_seconds ${nowSeconds}`)
  return lines.join('\n') + '\n'
}

/** Old screenshots go first; at most `keep` stay. `files` are `{ name, mtimeMs }`. */
export function artifactsToDelete(files, keep = 50) {
  return [...files].sort((a, b) => b.mtimeMs - a.mtimeMs).slice(keep).map((f) => f.name)
}

/** A file-name-safe stamp such as `20261021T093000Z`. */
export const stamp = (date) => date.toISOString().replace(/[-:]/g, '').replace(/\.\d+Z$/, 'Z')

/** First `href` in `hrefs` that is exactly `<prefix><one segment>` (no query, no trailing slash). */
export function firstChild(hrefs, prefix) {
  const re = new RegExp(`^${prefix.replace(/[.*+?^${}()|[\]\\/]/g, '\\$&')}[^/?#]+$`)
  return hrefs.map((h) => h.replace(/^https?:\/\/[^/]+/, '')).find((h) => re.test(h))
}
