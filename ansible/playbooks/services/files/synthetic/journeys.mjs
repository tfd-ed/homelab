// The journeys. Each one is `{ env, name, run({ page, context, base, config }) }` and throws on
// failure. They check what a person would notice first (the page answers, shows something, is not
// the error page, the next step exists) and not wording or layout, so a copy edit never fails one.
import { firstChild } from './lib.mjs'

const ERROR_PAGE = '[data-testid="error-page"]'

async function visit(page, url, { minText = 150 } = {}) {
  const response = await page.goto(url, { waitUntil: 'domcontentloaded' })
  if (!response) throw new Error(`no response for ${url}`)
  if (response.status() >= 400) throw new Error(`${url} answered ${response.status()}`)
  // Pages with a long-lived connection never go idle: do not let that cost 20 s a journey.
  await page.waitForLoadState('networkidle', { timeout: 5_000 }).catch(() => {})
  if (await page.locator(ERROR_PAGE).count()) throw new Error(`${url} rendered the error page`)
  if (!(await page.title()).trim()) throw new Error(`${url} has no title`)
  const text = (await page.locator('body').innerText()).trim()
  if (text.length < minText) throw new Error(`${url} shows almost nothing (${text.length} characters)`)
}

/** The code of the first published course, from the public API (the academy page's cards are buttons, not links). */
async function firstCourseCode(context, apiBase) {
  if (!apiBase) throw new Error('no API address configured for the course journeys')
  const res = await context.request.get(`${apiBase}/courses/published`)
  if (res.status() !== 200) throw new Error(`/courses/published answered ${res.status()}`)
  const code = (await res.json())?.data?.[0]?.code
  if (typeof code !== 'string' || !code) throw new Error('no published course to open')
  return code
}

async function openCourse(page, context, base, apiBase) {
  const code = await firstCourseCode(context, apiBase)
  // No heading check: the course page's hero does not always have an h1. A real page is long, and
  // the error page (or a page that failed to load its course) is not.
  await visit(page, `${base}/courses/${encodeURIComponent(code)}`, { minText: 500 })
}

async function hrefs(page, selector) {
  return page.$$eval(selector, (els) => els.map((e) => e.getAttribute('href') ?? ''))
}

/** Opens the first item of a list page; `required` fails when the list is empty. */
async function openFirst(page, base, listPath, itemPrefix, { required }) {
  await visit(page, `${base}${listPath}`)
  const found = firstChild(await hrefs(page, `a[href^="${itemPrefix}"]`), itemPrefix)
  if (!found) {
    if (required) throw new Error(`${listPath} lists nothing to open`)
    return false
  }
  await visit(page, `${base}${found}`)
  if (!(await page.locator('h1').first().isVisible())) throw new Error(`${found} has no heading`)
  return true
}

/** Public pages, safe to run against production: no account, nothing written. */
export const publicJourneys = (env, base, apiBase) => [
  { env, name: 'home', run: async ({ page }) => visit(page, `${base}/`) },
  {
    env,
    name: 'academy',
    run: async ({ page, context }) => {
      await visit(page, `${base}/academy`)
      await firstCourseCode(context, apiBase) // the list the page shows comes from here
    },
  },
  { env, name: 'course-detail', run: async ({ page, context }) => openCourse(page, context, base, apiBase) },
  // A site with no article yet is fine: the list page itself must still work.
  { env, name: 'article', run: async ({ page }) => void (await openFirst(page, base, '/articles', '/articles/', { required: false })) },
  {
    env,
    name: 'certificate-verify',
    run: async ({ page }) => {
      await visit(page, `${base}/verify`)
      if (!(await page.locator('input').first().isVisible())) throw new Error('the verify page has no input')
    },
  },
  {
    env,
    name: 'health-ready',
    run: async ({ context }) => {
      const res = await context.request.get(`${base}/api/health/ready`)
      if (res.status() !== 200) throw new Error(`/api/health/ready answered ${res.status()}`)
    },
  },
]

/**
 * Signed-in journeys. They run on dev only: production has no password login (SSO only), and
 * `/auth/login-cookie` exists on dev and local. The account is a dedicated, low-privilege one.
 */
export const signedInJourneys = (env, base, apiBase, { username, password, admin }) => {
  const login = async (context) => {
    const res = await context.request.post(`${apiBase}/auth/login-cookie`, { data: { username, password } })
    if (res.status() >= 300) throw new Error(`login answered ${res.status()}`)
  }
  const inPortal = async (page, path) => {
    await visit(page, `${base}${path}`)
    if (!new URL(page.url()).pathname.startsWith('/portal')) throw new Error(`${path} sent the signed-in user away (${page.url()})`)
  }
  const journeys = [
    { env, name: 'login', run: async ({ context, page }) => { await login(context); await inPortal(page, '/portal') } },
    { env, name: 'open-course', run: async ({ context, page }) => { await login(context); await openCourse(page, context, base, apiBase) } },
    { env, name: 'enrollments', run: async ({ context, page }) => { await login(context); await inPortal(page, '/portal/courses') } },
  ]
  if (admin) {
    journeys.push({
      env,
      name: 'admin-page',
      run: async ({ context, page }) => {
        await login(context)
        await visit(page, `${base}/admin/users`)
        if (!new URL(page.url()).pathname.startsWith('/admin')) throw new Error(`the admin page sent the user away (${page.url()})`)
        await page.locator('table').first().waitFor({ state: 'visible', timeout: 15_000 })
      },
    })
  }
  return journeys
}
