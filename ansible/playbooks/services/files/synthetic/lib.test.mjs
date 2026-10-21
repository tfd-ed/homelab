import test from 'node:test'
import assert from 'node:assert/strict'
import { artifactsToDelete, firstChild, keyOf, nextState, renderMetrics, stamp, USER_AGENT } from './lib.mjs'

const r = (env, journey, ok, seconds = 1.5) => ({ env, journey, ok, seconds })

test('a failure counts up, a pass resets, and the last success is kept through failures', () => {
  let s = nextState({}, [r('prod', 'home', true)], 100)
  assert.deepEqual(s[keyOf('prod', 'home')], { consecutiveFailures: 0, lastSuccess: 100 })
  s = nextState(s, [r('prod', 'home', false)], 700)
  s = nextState(s, [r('prod', 'home', false)], 1300)
  assert.deepEqual(s[keyOf('prod', 'home')], { consecutiveFailures: 2, lastSuccess: 100 })
  s = nextState(s, [r('prod', 'home', true)], 1900)
  assert.deepEqual(s[keyOf('prod', 'home')], { consecutiveFailures: 0, lastSuccess: 1900 })
})

test('journeys are tracked by environment and name, and one that did not run leaves the state', () => {
  const before = { 'dev/login': { consecutiveFailures: 3, lastSuccess: 5 }, 'prod/home': { consecutiveFailures: 1, lastSuccess: 9 } }
  const s = nextState(before, [r('prod', 'home', false)], 1000)
  assert.deepEqual(Object.keys(s), ['prod/home'])
  assert.equal(s['prod/home'].consecutiveFailures, 2)
})

test('a first-ever failure has no last success', () => {
  const s = nextState(undefined, [r('prod', 'home', false)], 50)
  assert.deepEqual(s['prod/home'], { consecutiveFailures: 1, lastSuccess: 0 })
})

test('the metrics are valid exposition text with one series per journey', () => {
  const results = [r("prod", "home", true, 1.2346), r('dev', 'login', false, 30)]
  const text = renderMetrics(results, nextState({}, results, 1000), 1000)
  assert.match(text, /^synthetic_success\{journey="home",env="prod"\} 1$/m)
  assert.match(text, /^synthetic_success\{journey="login",env="dev"\} 0$/m)
  assert.match(text, /^synthetic_duration_seconds\{journey="home",env="prod"\} 1\.235$/m)
  assert.match(text, /^synthetic_consecutive_failures\{journey="login",env="dev"\} 1$/m)
  assert.match(text, /^synthetic_last_success_timestamp_seconds\{journey="login",env="dev"\} 0$/m)
  assert.match(text, /^synthetic_last_run_timestamp_seconds 1000$/m)
  assert.ok(text.endsWith('\n'))
  for (const line of text.trim().split('\n')) assert.match(line, /^(#|[a-z_]+(\{[^}]*\})? [\d.e+-]+$)/)
})

test('label values are escaped', () => {
  const results = [r('prod', 'a"b\\c', true)]
  assert.match(renderMetrics(results, nextState({}, results, 1), 1), /journey="a\\"b\\\\c"/)
})

test('only the newest screenshots are kept', () => {
  const files = Array.from({ length: 5 }, (_, i) => ({ name: `f${i}.png`, mtimeMs: i }))
  assert.deepEqual(artifactsToDelete(files, 3), ['f1.png', 'f0.png'])
  assert.deepEqual(artifactsToDelete(files, 10), [])
})

test('the file stamp has no colon and no milliseconds', () => {
  assert.equal(stamp(new Date('2026-10-21T09:30:05.123Z')), '20261021T093005Z')
})

test('the first child link of a list ignores the list itself, nested paths and queries', () => {
  const links = ['/courses', '/courses/', '/courses/a/b', '/courses/x?page=2', 'https://tfdevs.com/courses/ON-AFD-B-26', '/courses/other']
  assert.equal(firstChild(links, '/courses/'), '/courses/ON-AFD-B-26')
  assert.equal(firstChild(['/courses'], '/courses/'), undefined)
})

test('the User-Agent carries the token the site and the API recognise', () => {
  assert.match(USER_AGENT, /TFD-Synthetic\/1\.0$/)
  assert.ok(!/headless/i.test(USER_AGENT))
})
