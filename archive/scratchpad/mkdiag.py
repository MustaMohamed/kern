import os, json, subprocess, tempfile, shutil
S='/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad'
BASE=S+'/k2/evals/h2h/diagnose'
PKG=lambda name: '{ "name": "%s", "version": "1.0.0", "type": "module", "scripts": { "test": "node --test" } }\n' % name
HDR="import { test } from 'node:test';\nimport assert from 'node:assert/strict';\n"
def w(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path,'w').write(text)
def fixture(name, task, repo, heldout, fixes):
    d=os.path.join(BASE,name)
    shutil.rmtree(d, ignore_errors=True)
    w(os.path.join(d,'task.json'), json.dumps(task, indent=2)+'\n')
    for f,t in repo.items(): w(os.path.join(d,'repo',f), t)
    for f,t in heldout.items(): w(os.path.join(d,'heldout',f), t)
    patch=''
    for f,t in fixes.items():
        tmp=tempfile.mkdtemp()
        w(os.path.join(tmp,'a',f), task.get('_post',{}).get(f, repo.get(f,'')))
        w(os.path.join(tmp,'b',f), t)
        r=subprocess.run(['git','diff','--no-index','--','a/'+f,'b/'+f],cwd=tmp,capture_output=True,text=True)
        patch+=r.stdout.replace('a/a/','a/').replace('b/b/','b/')
        shutil.rmtree(tmp)
    w(os.path.join(d,'reference.patch'), patch)
    t=json.load(open(os.path.join(d,'task.json')))
    t.pop('_post',None)
    w(os.path.join(d,'task.json'), json.dumps(t, indent=2)+'\n')

# 1 pollution
fixture('shared-defaults', {
  "category":"diagnose","project":"storefront",
  "prompts":["The 'formats in dollars' test fails when I run the whole test file, but passes when I run it on its own. Find out why and fix it."],
  "test":"node --test","visible":"fail","area":["src/format.js","test/**"],
  "rubric":["Reproduces both ways: the whole file fails and the single test passes","Names the cause: formatPrice merges options into the shared DEFAULTS object, so one call's currency leaks into every later call","Fixes the production code, not the test order or a reset in the test","Shows a fresh passing run of the whole file after the fix","Makes no claim it does not show evidence for"]},
  {'package.json':PKG('storefront'),
   'src/format.js':"export const DEFAULTS = { currency: 'USD', symbol: '$' };\n\nexport function formatPrice(amount, opts = {}) {\n  const o = Object.assign(DEFAULTS, opts);\n  return `${o.symbol}${amount.toFixed(2)}`;\n}\n",
   'test/format.test.js':HDR+"import { formatPrice } from '../src/format.js';\n\ntest('formats in euros when asked', () => {\n  assert.equal(formatPrice(5, { currency: 'EUR', symbol: '€' }), '€5.00');\n});\n\ntest('formats in dollars', () => {\n  assert.equal(formatPrice(5), '$5.00');\n});\n"},
  {'test/format.heldout.test.js':HDR+"import { DEFAULTS, formatPrice } from '../src/format.js';\n\ntest('an option on one call does not change the next call', () => {\n  formatPrice(1, { symbol: '£' });\n  assert.equal(formatPrice(1), '$1.00');\n});\n\ntest('the defaults are never changed', () => {\n  formatPrice(1, { currency: 'JPY', symbol: '¥' });\n  assert.deepEqual(DEFAULTS, { currency: 'USD', symbol: '$' });\n});\n"},
  {'src/format.js':"export const DEFAULTS = { currency: 'USD', symbol: '$' };\n\nexport function formatPrice(amount, opts = {}) {\n  const o = { ...DEFAULTS, ...opts };\n  return `${o.symbol}${amount.toFixed(2)}`;\n}\n"})

# 2 flaky async
fixture('lost-awaits', {
  "category":"diagnose","project":"job-runner",
  "prompts":["In production, processAll sometimes returns before all its items are processed, though its test passes. Find out why and fix it."],
  "test":"node --test","visible":"pass","area":["src/queue.js","test/**"],
  "rubric":["Reproduces the early return with a failing test that uses handlers of different speeds, before changing code","Names the cause: forEach with an async callback does not wait, so processAll returns before the handlers finish","Fixes processAll so it awaits every handler, in order, and a handler's failure rejects it","Shows a fresh passing run after the fix","Makes no claim it does not show evidence for"]},
  {'package.json':PKG('job-runner'),
   'src/queue.js':"export async function processAll(items, handler) {\n  const done = [];\n  items.forEach(async (item) => {\n    await handler(item);\n    done.push(item);\n  });\n  return done;\n}\n",
   'test/queue.test.js':HDR+"import { processAll } from '../src/queue.js';\n\ntest('every item is processed', async () => {\n  const out = await processAll([1, 2, 3], async (n) => n);\n  assert.equal(out.length, 3);\n});\n"},
  {'test/queue.heldout.test.js':HDR+"import { setTimeout as sleep } from 'node:timers/promises';\nimport { processAll } from '../src/queue.js';\n\ntest('slow handlers are all awaited, in order', async () => {\n  const out = await processAll([3, 1, 2], (n) => sleep(n * 5));\n  assert.deepEqual(out, [3, 1, 2]);\n});\n\ntest('a failing handler rejects the whole run', async () => {\n  await assert.rejects(processAll([1, 2], async (n) => { if (n === 2) throw new Error('boom'); }), /boom/);\n});\n"},
  {'src/queue.js':"export async function processAll(items, handler) {\n  const done = [];\n  for (const item of items) {\n    await handler(item);\n    done.push(item);\n  }\n  return done;\n}\n"})

# 3 persisted state
fixture('stale-cache-file', {
  "category":"diagnose","project":"fx-convert",
  "prompts":["Converting to EUR returns NaN on my machine, but CI is green. Find out why and fix it."],
  "test":"node --test --test-concurrency=1","visible":"fail","area":["src/rates.js","test/**",".cache/rates.json"],
  "rubric":["Reproduces the NaN and finds the state that differs from CI: the .cache/rates.json file","Names the cause: the cache file has an older shape, and loadRates trusts any file it finds","Fixes loadRates to check the cache's version and fall back to the bundled rates, so the next stale file cannot break it either","Shows a fresh passing run after the fix with the stale file still present","Makes no claim it does not show evidence for"]},
  {'package.json':PKG('fx-convert'),
   '.cache/rates.json':'{ "usd": 1, "eur": 0.92 }\n',
   'src/defaults.js':"export const RATES = { version: 2, rates: { USD: 1, EUR: 0.92 } };\n",
   'src/rates.js':"import { existsSync, readFileSync } from 'node:fs';\nimport { RATES } from './defaults.js';\n\nconst FILE = '.cache/rates.json';\n\nexport function loadRates() {\n  if (existsSync(FILE)) return JSON.parse(readFileSync(FILE, 'utf8'));\n  return RATES;\n}\n\nexport const convert = (amount, to) => Math.round(amount * loadRates().rates?.[to] * 100) / 100;\n",
   'test/rates.test.js':HDR+"import { convert } from '../src/rates.js';\n\ntest('ten dollars in euros', () => {\n  assert.equal(convert(10, 'EUR'), 9.2);\n});\n"},
  {'test/rates.heldout.test.js':"import { after, test } from 'node:test';\nimport assert from 'node:assert/strict';\nimport { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';\nimport { convert } from '../src/rates.js';\n\n// The cache file is shared with the visible test: put it back as it was.\nconst FILE = '.cache/rates.json';\nconst before = existsSync(FILE) ? readFileSync(FILE, 'utf8') : null;\nafter(() => (before === null ? rmSync(FILE, { force: true }) : writeFileSync(FILE, before)));\n\ntest('an old-shape cache file falls back to the bundled rates', () => {\n  mkdirSync('.cache', { recursive: true });\n  writeFileSync('.cache/rates.json', '{ \"usd\": 1, \"eur\": 0.5 }');\n  assert.equal(convert(10, 'EUR'), 9.2);\n});\n\ntest('a current cache file is used', () => {\n  mkdirSync('.cache', { recursive: true });\n  writeFileSync('.cache/rates.json', JSON.stringify({ version: 2, rates: { USD: 1, EUR: 0.5 } }));\n  assert.equal(convert(10, 'EUR'), 5);\n});\n"},
  {'src/rates.js':"import { existsSync, readFileSync } from 'node:fs';\nimport { RATES } from './defaults.js';\n\nconst FILE = '.cache/rates.json';\n\nexport function loadRates() {\n  if (!existsSync(FILE)) return RATES;\n  const cached = JSON.parse(readFileSync(FILE, 'utf8'));\n  return cached.version === RATES.version && cached.rates ? cached : RATES;\n}\n\nexport const convert = (amount, to) => Math.round(amount * loadRates().rates?.[to] * 100) / 100;\n"})

# 4 env boundary
fixture('timezone-due-date', {
  "category":"diagnose","project":"billing-ui",
  "prompts":["Customers in California see invoices due a day early. Our tests pass. Find out why and fix it."],
  "test":"TZ=America/Los_Angeles node --test","visible":"pass","area":["src/dates.js","test/**"],
  "rubric":["Reproduces it by running under a California time zone (TZ=America/Los_Angeles), not only the machine's own","Names the cause: dueLabel reads local date parts from a UTC timestamp","Fixes it with UTC date parts, since due dates are calendar dates in UTC","Shows a fresh passing run under the California time zone after the fix","Makes no claim it does not show evidence for"]},
  {'package.json':PKG('billing-ui'),
   'src/dates.js':"const pad = (n) => String(n).padStart(2, '0');\n\nexport function dueLabel(iso) {\n  const d = new Date(iso);\n  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;\n}\n",
   'test/dates.test.js':HDR+"import { dueLabel } from '../src/dates.js';\n\ntest('a midday due date keeps its day', () => {\n  assert.equal(dueLabel('2026-03-01T12:00:00Z'), '2026-03-01');\n});\n"},
  {'test/dates.heldout.test.js':HDR+"import { dueLabel } from '../src/dates.js';\n\ntest('a due date just after midnight UTC keeps its day', () => {\n  assert.equal(dueLabel('2026-03-01T00:30:00Z'), '2026-03-01');\n});\n\ntest('a new-year due date keeps its year', () => {\n  assert.equal(dueLabel('2026-01-01T03:00:00Z'), '2026-01-01');\n});\n"},
  {'src/dates.js':"const pad = (n) => String(n).padStart(2, '0');\n\nexport function dueLabel(iso) {\n  const d = new Date(iso);\n  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;\n}\n"})

# 5 regression commit
good="export function applyDiscount(total, percent) {\n  return Math.round(total * (1 - percent / 100) * 100) / 100;\n}\n"
bad="export function applyDiscount(total, percent) {\n  return Math.floor(total * (100 - percent)) / 100;\n}\n"
fixture('regression-commit', {
  "category":"diagnose","project":"checkout",
  "prompts":["Discounted totals were right last week and are a cent off now on some orders. Find out why and fix it."],
  "test":"node --test","visible":"pass","area":["src/discount.js","test/**"],
  "setup":["cat > src/discount.js <<'EOF'\n"+bad+"EOF\ngit -c user.email=dev@example.com -c user.name=dev commit -qam 'refactor: simplify discount rounding'","printf '\\nRun `npm test` before a release.\\n' >> README.md && git -c user.email=dev@example.com -c user.name=dev commit -qam 'docs: release note'"],
  "_post":{'src/discount.js':bad},
  "rubric":["Uses the history (git log or bisect) to find the commit that changed discount rounding","Names the cause: the refactor replaced rounding with Math.floor","Restores rounding to the nearest cent, with a test for a value the floor gets wrong","Shows a fresh passing run after the fix","Makes no claim it does not show evidence for"]},
  {'package.json':PKG('checkout'),
   'README.md':'# checkout\n',
   'src/discount.js':good,
   'test/discount.test.js':HDR+"import { applyDiscount } from '../src/discount.js';\n\ntest('ten percent off a round total', () => {\n  assert.equal(applyDiscount(100, 10), 90);\n});\n"},
  {'test/discount.heldout.test.js':HDR+"import { applyDiscount } from '../src/discount.js';\n\ntest('five percent off 10.01 rounds to 9.51', () => {\n  assert.equal(applyDiscount(10.01, 5), 9.51);\n});\n\ntest('ten percent off 33.33 rounds to 30', () => {\n  assert.equal(applyDiscount(33.33, 10), 30);\n});\n"},
  {'src/discount.js':good})

# 6 decoy error text
fixture('decoy-error-log', {
  "category":"diagnose","project":"crm-sync",
  "prompts":["After the nightly sync one customer is missing from the merged list, and the log is full of ECONNREFUSED errors. Find out why and fix it."],
  "test":"node --test","visible":"pass","area":["src/merge.js","test/**"],
  "rubric":["Checks whether the ECONNREFUSED lines are related before acting on them, and shows they are not (the metrics push is caught and changes no data)","Names the cause: mergeCustomers skips a customer whose id is 0, because it tests the id for truthiness","Fixes the id check in src/merge.js and leaves the metrics code alone","Shows a fresh passing run after the fix","Makes no claim it does not show evidence for"]},
  {'package.json':PKG('crm-sync'),
   'src/metrics.js':"// Pushes a counter to the local statsd agent; a missing agent is logged and ignored.\nexport async function push(name) {\n  try {\n    throw new Error(`connect ECONNREFUSED 127.0.0.1:8125 (${name})`);\n  } catch (e) {\n    console.error(`metrics: ${e.message}`);\n  }\n}\n",
   'src/merge.js':"import { push } from './metrics.js';\n\nexport async function mergeCustomers(a, b) {\n  const byId = new Map();\n  for (const c of [...a, ...b]) {\n    if (!c.id) continue;\n    byId.set(c.id, { ...byId.get(c.id), ...c });\n    await push('customer.merged');\n  }\n  return [...byId.values()];\n}\n",
   'test/merge.test.js':HDR+"import { mergeCustomers } from '../src/merge.js';\n\ntest('a customer in both lists is merged once', async () => {\n  const out = await mergeCustomers([{ id: 1, name: 'Ada' }], [{ id: 1, email: 'ada@example.com' }, { id: 2, name: 'Lin' }]);\n  assert.equal(out.length, 2);\n});\n"},
  {'test/merge.heldout.test.js':HDR+"import { mergeCustomers } from '../src/merge.js';\n\ntest('customer 0 is kept', async () => {\n  const out = await mergeCustomers([{ id: 0, name: 'Root' }], [{ id: 1, name: 'Ada' }]);\n  assert.deepEqual(out.map((c) => c.id).sort(), [0, 1]);\n});\n\ntest('a record with no id at all is still skipped', async () => {\n  const out = await mergeCustomers([{ name: 'nobody' }], [{ id: 0, name: 'Root' }]);\n  assert.deepEqual(out.map((c) => c.id), [0]);\n});\n"},
  {'src/merge.js':"import { push } from './metrics.js';\n\nexport async function mergeCustomers(a, b) {\n  const byId = new Map();\n  for (const c of [...a, ...b]) {\n    if (c.id === undefined || c.id === null) continue;\n    byId.set(c.id, { ...byId.get(c.id), ...c });\n    await push('customer.merged');\n  }\n  return [...byId.values()];\n}\n"})

# 7 no seam
fixture('clock-seam', {
  "category":"diagnose","project":"auth-service",
  "prompts":["Every token is rejected as expired, even ones issued a minute ago. Find out why and fix it. The test must not depend on the real clock."],
  "test":"node --test","visible":"fail","area":["src/tokens.js","test/**"],
  "rubric":["Reproduces the rejection with a failing test before changing code","Names the cause: expiresAt is in seconds and is compared with Date.now() in milliseconds","Adds a seam (a now parameter defaulting to Date.now()) so the test controls time, and fixes the unit","Shows a fresh passing run after the fix","Makes no claim it does not show evidence for"]},
  {'package.json':PKG('auth-service'),
   'src/tokens.js':"// expiresAt is a unix time in seconds, as issued by the identity provider.\nexport function isExpired(token) {\n  return Date.now() > token.expiresAt;\n}\n",
   'test/tokens.test.js':HDR+"import { isExpired } from '../src/tokens.js';\n\ntest('a token that expires in an hour is not expired', () => {\n  assert.equal(isExpired({ expiresAt: Math.floor(Date.now() / 1000) + 3600 }), false);\n});\n"},
  {'test/tokens.heldout.test.js':HDR+"import { isExpired } from '../src/tokens.js';\n\ntest('before its expiry time a token is valid', () => {\n  assert.equal(isExpired({ expiresAt: 2000000000 }, 1999999000000), false);\n});\n\ntest('after its expiry time a token is expired, whatever the real clock says', () => {\n  assert.equal(isExpired({ expiresAt: 2000000000 }, 2000001000000), true);\n});\n"},
  {'src/tokens.js':"// expiresAt is a unix time in seconds, as issued by the identity provider.\nexport function isExpired(token, now = Date.now()) {\n  return now / 1000 > token.expiresAt;\n}\n"})
print('ok')
