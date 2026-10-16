### Task 30: The routed file, kernel rows, row evals and lint rules 6, 7 and 12

**Files:**
- Create: `kernel/routes.md`, `scripts/lib/kernel-rows.mjs`, `evals/cases/row-define.json`, `row-plan.json`, `row-execute-plan.json`, `row-implement.json`, `row-diagnose.json`, `row-prove-it.json`, `row-self-review.json`, `row-recall.json`, `row-technical-writing.json`, `row-context.json` (all under `evals/cases/`), `evals/heldout.json`, `evals/floors.json`
- Modify: `kernel/kernel.md` (the Routing rule), `scripts/route-eval.mjs`, `scripts/lib/lint-rules.mjs` (`loadModel`, rules 5, 6 and 7; append rule 12), `tests/lint-rules.test.mjs`, `skills/help/references/map.md` (its intro line), `evals/baseline.json`, `CHANGELOG.md`
- Test: `tests/route-eval-rows.test.mjs`, `tests/lint-rules.test.mjs`

**Interfaces:**
- Consumes (M0): `targets(root)`, `evaluate(root, { minRank1 })`, `loadModel`, `err`, `warn`, `rel`; (M1) the routing table in `kernel/kernel.md` with rows for `technical-writing` and `context`, the rule 6 regex that accepts a `0.` first step (pre-flight F2, already in M1), rule 7's two renders.
- Produces:
  - `kernel/routes.md` (pre-flight F3, the user's decision "move rows out"): M2's eight rows, read by the model per routed task, never rendered into the session. The kernel's Routing rule names it and keeps M1's two rows. Measured on the planned tree: the kernel renders to 3,487 chars with no settings and 3,926 with the longest fixture; `routes.md` is 759 chars.
  - `kernelRows(text)` and `routeText(model)` in `scripts/lib/kernel-rows.mjs`; `loadModel(...).routesText`; a skill routed from either file is a path skill.
  - Route-eval owners `row-<route>` for the rows of both files, with `kind: 'row'`, placed after skills and before distractors; `ownerOf(name)` treats `row-x` and `x` as one owner; `heldoutRate` for `evals/heldout.json`; fixed floors from `evals/floors.json` (`rank1` 85 for case positives, measured 88 on the planned tree; `heldout_rank1` 32 for the frozen held-out set, measured 36, which shows the description and row text ranker is a weak proxy for the model's routing that M2b measures directly).
  - Lint rule 6 reads both files and fails when `routes.md` has rows the kernel never names; rule 7 caps `routes.md` at 1,500 chars and the standing cost (kernel with no settings plus auto and agent descriptions) at 4,800; rule 12: once `evals/cases/` exists, every auto skill has `evals/cases/<name>.json` and every row of both files has `evals/cases/row-<route>.json`, each with at least 3 positive, 2 negative and 1 behavioural case.
  - The design's combined row "Executing an agreed plan; or one bounded change" becomes two rows, because the row format routes to one skill.

- [ ] **Step 1: Write the failing tests**

```js
// tests/route-eval-rows.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { targets, evaluate } from '../scripts/route-eval.mjs';
import { kernelRows } from '../scripts/lib/kernel-rows.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url));

function repo(files) {
  const root = mkdtempSync(join(tmpdir(), 'kern-rows-'));
  for (const [p, content] of Object.entries(files)) {
    mkdirSync(join(root, p, '..'), { recursive: true });
    writeFileSync(join(root, p), content);
  }
  return root;
}
const autoSkill = (name, desc) => `---\nname: ${name}\ndescription: ${desc}\n---\n\n# ${name}\n\n## Steps\n\n1. a\n`;
const pathSkill = (name) => `---\nname: ${name}\ndescription: d\ndisable-model-invocation: true\n---\n\n# ${name}\n\n## Steps\n\n1. a\n`;
const cases = (name, pos, neg) => JSON.stringify({
  skill_name: name,
  trigger: { positive: pos.map((prompt) => ({ prompt, top_k: 3 })), negative: neg.map((prompt) => ({ prompt })) },
  evals: [{ id: 1, kind: 'dialogue', prompt: 'x', expected_output: 'y', expectations: ['z'] }],
});
const KERNEL = [
  '| Observable trigger | Route |',
  '|---|---|',
  '| Phase ends, or context is filling | Read {ROOT}/kernel/context.md |',
  '',
  'Then Read {ROOT}/kernel/routes.md. Several matches: define and diagnose before build.',
].join('\n');
const ROUTES = [
  '| Observable trigger | Route |',
  '|---|---|',
  '| Bug, failing test, unexpected output, crash or error | Read {KERN}/diagnose/SKILL.md |',
  '| Starting or resuming after a gap | Read {KERN}/recall/SKILL.md |',
].join('\n');

function fixture(extra = {}) {
  return repo({
    'kernel/kernel.md': KERNEL,
    'kernel/routes.md': ROUTES,
    'skills/diagnose/SKILL.md': pathSkill('diagnose'),
    'skills/recall/SKILL.md': autoSkill('recall', 'Use when starting or resuming work after a gap and state must be rebuilt: where did I leave off, catch me up.'),
    'evals/cases/recall.json': cases('recall', ['where did I leave off yesterday', 'catch me up on the work', 'resuming after a long gap'], ['fix this crash', 'rename a variable']),
    'evals/cases/row-recall.json': cases('row-recall', ['resuming after a gap in the work', 'starting again after a gap', 'where did I leave off after the gap'], ['fix this crash', 'rename a variable']),
    'evals/cases/row-diagnose.json': cases('row-diagnose', ['the test is failing with an error', 'unexpected output from the bug', 'a crash with an error on startup'], ['catch me up', 'where did I leave off']),
    'evals/cases/row-context.json': cases('row-context', ['the context is filling up', 'this phase ends now', 'context is filling, what next'], ['fix this crash', 'catch me up']),
    ...extra,
  });
}

test('kernelRows parses skill and kernel-file routes and skips other lines', () => {
  assert.deepEqual(kernelRows(`${KERNEL}\n${ROUTES}`), [
    { when: 'Phase ends, or context is filling', route: 'context' },
    { when: 'Bug, failing test, unexpected output, crash or error', route: 'diagnose' },
    { when: 'Starting or resuming after a gap', route: 'recall' },
  ]);
  assert.deepEqual(kernelRows(''), []);
});

test('targets add the rows of both files after skills and before distractors', () => {
  const root = fixture({ 'evals/distractors.json': JSON.stringify([{ name: 'other', description: 'Something else entirely' }]) });
  assert.deepEqual(targets(root).map((t) => `${t.kind}:${t.name}`), ['skill:recall', 'row:row-context', 'row:row-diagnose', 'row:row-recall', 'distractor:other']);
});

test('a row and its own skill count as one owner', () => {
  const r = evaluate(fixture(), { minRank1: null });
  assert.deepEqual(r.errors, []);
  assert.equal(r.rank1Rate, 100);
});

test('a routed row without a case file is an error', () => {
  const root = fixture();
  rmSync(join(root, 'evals/cases/row-diagnose.json'));
  const r = evaluate(root, { minRank1: null });
  assert.ok(r.errors.some((e) => e.startsWith('row-diagnose: no eval case file')), JSON.stringify(r.errors));
});

test('held-out prompts give their own rate, held to their own floor', () => {
  const held = JSON.stringify([{ owner: 'recall', prompt: 'where did I leave off after the gap' }, { owner: 'diagnose', prompt: 'catch me up' }]);
  const r = evaluate(fixture({ 'evals/heldout.json': held }), { minRank1: null, minHeldout: 60 });
  assert.equal(r.heldoutRate, 50);
  assert.ok(r.errors.some((e) => e.startsWith('held-out rank-1 rate 50% is below the floor 60%')), JSON.stringify(r.errors));
});

test('the fixed floors and the frozen held-out set are pinned', () => {
  assert.deepEqual(JSON.parse(readFileSync(join(ROOT, 'evals', 'floors.json'), 'utf8')), { rank1: 85, heldout_rank1: 32 });
  const sha = createHash('sha256').update(readFileSync(join(ROOT, 'evals', 'heldout.json'))).digest('hex');
  assert.equal(sha, '9b5cb8271f50835c162805b42066d90206bd46ffd7b0af280992b3d5af2a54c0', 'evals/heldout.json is frozen: fix routing, never the prompts');
});
```

In `tests/lint-rules.test.mjs`, the M1 test "rule 7: an oversized rendered kernel is an error; the real kernel passes" now also meets the standing-cost error. Replace its first assertion with:

```js
  assert.ok(lint({ 'hooks/session-start': big, 'hooks/subagent-start': sub }).some((f) => f.rule === 7 && f.level === 'error' && /limit 9,000/.test(f.message)));
```

Append to `tests/lint-rules.test.mjs`:

```js
// M2a rules 6, 7 and 12 read kernel/routes.md.
test('rule 6: rows in kernel/routes.md resolve, and the kernel must name the routed file', () => {
  const files = {
    'kernel/kernel.md': kernel(['| Prose | Read {KERN}/tw/SKILL.md |']) + 'Then Read {ROOT}/kernel/routes.md.\n',
    'kernel/routes.md': '| Bug | Read {KERN}/d/SKILL.md |\n',
    'skills/tw/SKILL.md': skill('tw', manual()),
    'skills/d/SKILL.md': skill('d', manual()),
  };
  assert.deepEqual(rules(lint(files)), []);
  assert.equal(loadModel(repo(files)).skills.find((s) => s.name === 'd').tier, 'path', 'a skill routed from routes.md is a path skill');
  assert.deepEqual(rules(lint({ ...files, 'kernel/kernel.md': kernel(['| Prose | Read {KERN}/tw/SKILL.md |']) })), [6]);
  assert.deepEqual(rules(lint({ ...files, 'kernel/routes.md': '| Bug | Read {KERN}/gone/SKILL.md |\n' })), [6]);
});

test('rule 7: the routed file has its own cap, and the standing cost has a combined budget', () => {
  assert.deepEqual(rules(lint({ 'kernel/routes.md': `| x | Read {KERN}/a/SKILL.md |\n${'y'.repeat(1500)}` })).filter((r) => r === 7), [7]);
  const sub = '#!/usr/bin/env bash\nprintf \'{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"k"}}\'\n';
  const start = (n) => `#!/usr/bin/env bash\nhead -c ${n} /dev/zero | tr "\\0" x\n`;
  const desc = `description: Use when ${'w'.repeat(280)}.`;
  const files = (n) => ({ 'hooks/session-start': start(n), 'hooks/subagent-start': sub, 'skills/a/SKILL.md': skill('a', desc) });
  assert.deepEqual(rules(lint(files(4400))).filter((r) => r === 7), []);
  const big = lint(files(4600)).filter((f) => f.rule === 7 && f.level === 'error');
  assert.equal(big.length, 1);
  assert.match(big[0].message, /^standing cost 48\d\d chars/);
});


const caseJson = (name, p = 3, n = 2, e = 1) => JSON.stringify({
  skill_name: name,
  trigger: { positive: Array.from({ length: p }, (_, i) => ({ prompt: `p${i}` })), negative: Array.from({ length: n }, (_, i) => ({ prompt: `n${i}` })) },
  evals: Array.from({ length: e }, (_, i) => ({ id: i + 1, kind: 'dialogue', prompt: 'x', expected_output: 'y', expectations: ['z'] })),
});

test('rule 12: auto skills and the rows of both kernel files need eval cases once evals/cases exists', () => {
  const base = { 'skills/a/SKILL.md': skill('a', 'description: Use when x.') };
  assert.deepEqual(rules(lint(base)), [], 'no evals/cases folder: rule 12 is silent');
  assert.deepEqual(rules(lint({ ...base, 'evals/cases/other.json': caseJson('other') })), [12]);
  assert.deepEqual(rules(lint({ ...base, 'evals/cases/a.json': caseJson('a', 2) })), [12]);
  assert.deepEqual(rules(lint({ ...base, 'evals/cases/a.json': caseJson('a') })), []);
  const routed = { ...base, 'evals/cases/a.json': caseJson('a'), 'kernel/kernel.md': 'Then Read {ROOT}/kernel/routes.md.\n', 'kernel/routes.md': '| Bug | Read {KERN}/d/SKILL.md |\n', 'skills/d/SKILL.md': skill('d', 'description: d\ndisable-model-invocation: true') };
  assert.deepEqual(rules(lint(routed)), [12]);
  assert.deepEqual(rules(lint({ ...routed, 'evals/cases/row-d.json': caseJson('row-d') })), []);
});
```

- [ ] **Step 2: Run them to verify they fail**

Run: `node --test tests/route-eval-rows.test.mjs tests/lint-rules.test.mjs`
Expected: `Cannot find module '.../scripts/lib/kernel-rows.mjs'` for the rows file; the new rule 6, 7 and 12 tests fail (rule 6 does not read `routes.md`, rule 7 has no routed-file cap or standing-cost check, rule 12 reports nothing).

- [ ] **Step 3: Write `scripts/lib/kernel-rows.mjs`**

```js
// Kernel routing rows: "| <when> | Read {KERN}/<skill>/SKILL.md |" or "| <when> | Read {ROOT}/kernel/<name>.md |".
// The rows live in kernel/kernel.md and in kernel/routes.md, the routed file the kernel points to.
export function kernelRows(text) {
  const rows = [];
  for (const line of (text || '').split(/\r?\n/)) {
    const m = line.match(/^\|\s*(.+?)\s*\|\s*(.+?)\s*\|\s*$/);
    if (!m) continue;
    const target = m[2].match(/\{KERN\}\/([a-z0-9-]+)\/SKILL\.md/) || m[2].match(/kernel\/([a-z0-9-]+)\.md/);
    if (target) rows.push({ when: m[1], route: target[1] });
  }
  return rows;
}

// routeText(model): the kernel and its routed file, joined; every check that reads rows reads this.
export const routeText = (model) => `${model.kernelText}\n${model.routesText || ''}`;
```

- [ ] **Step 4: Replace `scripts/route-eval.mjs`**

Full file (the M0 file with the rows, `ownerOf`, the held-out set and the fixed floors):

```js
#!/usr/bin/env node
// Tier 1 routing evals (design spec 11.1). Adapted from addyosmani/agent-skills scripts/run-evals.js (MIT), deterministic tier only.
import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { isMain } from './lib/is-main.mjs';
import { loadModel } from './lib/lint-rules.mjs';
import { buildCorpus, rank, similarity } from './lib/rank.mjs';
import { kernelRows, routeText } from './lib/kernel-rows.mjs';

const MIN_POSITIVE = 3;
const MIN_NEGATIVE = 2;
const MIN_EVALS = 1;
const COLLISION_WARN = 0.5;
const COLLISION_ERROR = 0.75;

export function targets(root) {
  const model = loadModel(root);
  const skills = model.skills.filter((s) => s.tier === 'auto' && s.data.description)
    .map((s) => ({ name: s.name, text: s.data.description, kind: 'skill' }));
  const rows = kernelRows(routeText(model)).map((r) => ({ name: `row-${r.route}`, text: r.when, kind: 'row' }));
  const dPath = join(root, 'evals', 'distractors.json');
  const distractors = existsSync(dPath) ? JSON.parse(readFileSync(dPath, 'utf8')).map((d) => ({ name: d.name, text: d.description, kind: 'distractor' })) : [];
  return [...skills, ...rows, ...distractors];
}

// A kernel row and the skill it routes to are one owner: either ranking first is a hit.
const ownerOf = (name) => name.replace(/^row-/, '');

function loadCases(root) {
  const dir = join(root, 'evals', 'cases');
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter((f) => f.endsWith('.json')).map((f) => {
    try { return { file: f, data: JSON.parse(readFileSync(join(dir, f), 'utf8')) }; }
    catch (e) { return { file: f, parseError: e.message }; }
  });
}

export function evaluate(root, { minRank1, minHeldout = null }) {
  const all = targets(root);
  const owners = all.filter((t) => t.kind !== 'distractor');
  const corpus = buildCorpus(all);
  const names = new Set(all.map((t) => t.name));
  const cases = loadCases(root);
  const errors = [];
  const warnings = [];
  let positives = 0;
  let rank1 = 0;

  for (const t of owners) if (!cases.some((c) => c.file === `${t.name}.json`)) errors.push(`${t.name}: no eval case file (evals/cases/${t.name}.json)`);

  for (const c of cases) {
    if (c.parseError) { errors.push(`${c.file}: invalid JSON: ${c.parseError}`); continue; }
    const d = c.data;
    const expected = c.file.replace(/\.json$/, '');
    if (d.skill_name !== expected) errors.push(`${c.file}: skill_name "${d.skill_name}" does not match the file name`);
    if (!owners.some((t) => t.name === expected)) { errors.push(`${c.file}: no such auto skill or kernel row`); continue; }
    for (const ev of d.evals || []) {
      const ok = Number.isInteger(ev.id) && typeof ev.prompt === 'string' && typeof ev.expected_output === 'string' && Array.isArray(ev.expectations) && ev.expectations.length > 0;
      if (!ok) errors.push(`${c.file}: eval id=${ev.id} does not match the evals schema`);
      const kind = ev.kind || 'execution';
      if (!['execution', 'dialogue'].includes(kind)) errors.push(`${c.file}: eval id=${ev.id} has unknown kind "${kind}"`);
      if (kind === 'execution' && !(Array.isArray(ev.files) && ev.files.length)) errors.push(`${c.file}: eval id=${ev.id} needs files[]`);
      for (const f of ev.files || []) if (!existsSync(join(root, 'evals', 'fixtures', f))) errors.push(`${c.file}: eval id=${ev.id} fixture not found: evals/fixtures/${f}`);
    }
    for (const p of d.trigger?.positive || []) {
      positives++;
      const topK = p.top_k || 3;
      const r = rank(p.prompt, corpus);
      const idx = r.findIndex((x) => ownerOf(x.name) === ownerOf(expected));
      const hit = r[idx];
      if (idx === 0 && hit.score > 0) rank1++;
      if (!hit || hit.score === 0) errors.push(`${expected}: description shares no vocabulary with "${p.prompt}"`);
      else if (idx >= topK) errors.push(`${expected}: positive prompt ranked #${idx + 1} (need top ${topK}): "${p.prompt}"; top: ${r.slice(0, 3).map((x) => `${x.name} ${x.score.toFixed(2)}`).join(', ')}`);
    }
    for (const n of d.trigger?.negative || []) {
      const r = rank(n.prompt, corpus);
      if (ownerOf(r[0].name) === ownerOf(expected) && r[0].score > 0) errors.push(`${expected}: ranked #1 for negative prompt "${n.prompt}"`);
      if (n.owner) {
        if (!names.has(n.owner)) errors.push(`${c.file}: negative names unknown owner "${n.owner}"`);
        else {
          const oi = r.findIndex((x) => x.name === n.owner);
          const si = r.findIndex((x) => ownerOf(x.name) === ownerOf(expected));
          if (r[oi].score === 0 || oi > si) errors.push(`${expected}: owner ${n.owner} does not outrank it for "${n.prompt}"`);
        }
      }
    }
    const pc = (d.trigger?.positive || []).length;
    const nc = (d.trigger?.negative || []).length;
    const ec = (d.evals || []).length;
    if (pc < MIN_POSITIVE || nc < MIN_NEGATIVE || ec < MIN_EVALS) errors.push(`${expected}: below required minimums (${pc}/${nc}/${ec}; need ${MIN_POSITIVE}/${MIN_NEGATIVE}/${MIN_EVALS})`);
  }

  // targets() puts owners first and distractors last, so all[i] === owners[i] for i < owners.length.
  for (let i = 0; i < owners.length; i++) {
    for (let j = i + 1; j < all.length; j++) {
      const a = owners[i].name;
      const b = all[j].name;
      if (ownerOf(a) === ownerOf(b)) continue;
      const sim = similarity(a, b, corpus);
      if (sim >= COLLISION_ERROR) errors.push(`collision: ${a} and ${b} are ${(sim * 100).toFixed(0)}% similar`);
      else if (sim >= COLLISION_WARN) warnings.push(`overlap: ${a} and ${b} are ${(sim * 100).toFixed(0)}% similar`);
    }
  }

  const rank1Rate = positives ? Math.floor((rank1 / positives) * 100) : null;
  if (minRank1 !== null && rank1Rate !== null && rank1Rate < minRank1) errors.push(`rank-1 rate ${rank1Rate}% is below the floor ${minRank1}%`);

  // Held-out organic prompts (evals/heldout.json), frozen by a test: never reworded to pass.
  let heldoutRate = null;
  const hPath = join(root, 'evals', 'heldout.json');
  if (existsSync(hPath)) {
    const held = JSON.parse(readFileSync(hPath, 'utf8'));
    let hits = 0;
    for (const h of held) {
      if (!owners.some((t) => ownerOf(t.name) === h.owner)) { errors.push(`heldout: no owner "${h.owner}" for "${h.prompt}"`); continue; }
      const r = rank(h.prompt, corpus);
      if (ownerOf(r[0].name) === h.owner && r[0].score > 0) hits++;
    }
    heldoutRate = held.length ? Math.floor((hits / held.length) * 100) : null;
    if (minHeldout != null && heldoutRate !== null && heldoutRate < minHeldout) errors.push(`held-out rank-1 rate ${heldoutRate}% is below the floor ${minHeldout}%`);
  }
  return { errors, warnings, rank1Rate, heldoutRate };
}

if (isMain(import.meta.url)) {
  const root = fileURLToPath(new URL('..', import.meta.url));
  const basePath = join(root, 'evals', 'baseline.json');
  const baseline = JSON.parse(readFileSync(basePath, 'utf8'));
  // evals/floors.json holds fixed floors a test pins; the baseline only rises above them.
  const fPath = join(root, 'evals', 'floors.json');
  const floors = existsSync(fPath) ? JSON.parse(readFileSync(fPath, 'utf8')) : { rank1: 0, heldout_rank1: null };
  const minRank1 = Math.max(baseline.min_rank1, floors.rank1);
  const r = evaluate(root, { minRank1, minHeldout: floors.heldout_rank1 });
  for (const w of r.warnings) console.log(`warn: ${w}`);
  for (const e of r.errors) console.log(`error: ${e}`);
  console.log(`rank-1 rate: ${r.rank1Rate ?? 'n/a'}% (baseline ${baseline.min_rank1}%, fixed floor ${floors.rank1}%)`);
  if (r.heldoutRate !== null) console.log(`held-out rank-1 rate: ${r.heldoutRate}% (fixed floor ${floors.heldout_rank1}%)`);
  if (process.argv.includes('--update-baseline') && !r.errors.length && r.rank1Rate !== null && r.rank1Rate > baseline.min_rank1) {
    writeFileSync(basePath, JSON.stringify({ min_rank1: r.rank1Rate }, null, 2) + '\n');
    console.log(`baseline raised to ${r.rank1Rate}%`);
  }
  console.log(r.errors.length ? 'route-eval: FAILED' : 'route-eval: passed');
  process.exit(r.errors.length ? 1 : 0);
}
```

- [ ] **Step 5: Change `scripts/lib/lint-rules.mjs`**

Add the import under the `parseFrontmatter` import:

```js
import { kernelRows } from './kernel-rows.mjs';
```

In `loadModel`, replace the three lines that set `kernelPath`, set `kernelText` and build `routed` with (replacing only two leaves a second `const kernelPath`, a SyntaxError):

```js
  const kernelPath = join(root, 'kernel', 'kernel.md');
  const kernelText = existsSync(kernelPath) ? readFileSync(kernelPath, 'utf8') : '';
  const routesPath = join(root, 'kernel', 'routes.md');
  const routesText = existsSync(routesPath) ? readFileSync(routesPath, 'utf8') : '';
  const routed = new Set([...`${kernelText}\n${routesText}`.matchAll(/Read \{KERN\}\/([a-z0-9-]+)\/SKILL\.md/g)].map((m) => m[1]));
```

and return `routesText` too: `return { root, skills, agents, exemptions, shipped, kernelText, routesText, cases };`.

In rule 5, after the line that pushes the kernel text into `docs`, add:

```js
    if (model.routesText) docs.push({ file: join(model.root, 'kernel', 'routes.md'), body: model.routesText });
```

In rule 6, replace everything from `{ id: 6, check(model) {` up to the line `const mapFile = join(model.root, 'skills', 'help', 'references', 'map.md');` with:

```js
  { id: 6, check(model) {
    const out = [];
    const sources = [['kernel/kernel.md', model.kernelText], ['kernel/routes.md', model.routesText]];
    if (kernelRows(model.routesText).length && !model.kernelText.includes('{ROOT}/kernel/routes.md')) {
      out.push(err(6, 'kernel/kernel.md', 'kernel/routes.md holds route rows, but the kernel never names {ROOT}/kernel/routes.md, so no route there is reached'));
    }
    for (const [src, text] of sources) for (const line of text.split('\n')) {
      if (!line.trimStart().startsWith('|') || !/\{(KERN|ROOT)\}\//.test(line)) continue;
      const m = line.match(/^\|[^|\n]*\|\s*Read \{(KERN|ROOT)\}\/([^\s|]+)\s*\|\s*$/);
      if (!m) { out.push(err(6, src, `a route row must end in a bare Read {KERN}/<path> or Read {ROOT}/<path> cell: ${line.trim()}`)); continue; }
      const target = m[1] === 'KERN' ? join('skills', m[2]) : m[2];
      if (target === 'kernel/routes.md') { out.push(err(6, src, 'kernel/routes.md is named in the Routing rule, not routed by a row')); continue; }
      const file = join(model.root, target);
      if (!existsSync(file)) { out.push(err(6, src, `route ${target} does not exist`)); continue; }
      const body = parseFrontmatter(readFileSync(file, 'utf8')).body.replace(/\r\n/g, '\n');
      const firstH2 = body.split('\n').find((l) => l.startsWith('## '));
      if (firstH2 !== '## Steps') out.push(err(6, target, 'a route file must open with ## Steps'));
      else if (!/^## Steps\n+\d+\. /m.test(body)) out.push(err(6, target, '## Steps must open with a numbered list'));
    }
```

In rule 7, replace everything from `{ id: 7, check(model) {` up to the line `const sub = hook('subagent-start', ...` with:

```js
  { id: 7, check(model) {
    const out = [];
    if (model.routesText.length > 1500) out.push(err(7, 'kernel/routes.md', `routed file ${model.routesText.length} chars, limit 1,500; every routed task reads it`));
    if (!existsSync(join(model.root, 'hooks', 'session-start'))) return out;
    const tmp = mkdtempSync(join(tmpdir(), 'kern-rule7-'));
    try {
      const repo = join(tmp, 'repo');
      mkdirSync(join(repo, '.claude'), { recursive: true });
      spawnSync('git', ['init', '-q', repo]);
      const fixture = join(model.root, 'tests', 'fixtures', 'projects', 'long-settings');
      for (const f of ['kern.local.yml', 'kern.yml']) if (existsSync(join(fixture, f))) copyFileSync(join(fixture, f), join(repo, '.claude', f));
      const env = { ...process.env, HOME: join(tmp, 'home'), CLAUDE_PLUGIN_DATA: join(tmp, 'data') };
      const run = (name, payload) => spawnSync('bash', [join(model.root, 'hooks', name)], { input: JSON.stringify(payload), env, encoding: 'utf8' });
      const hook = (name, payload) => run(name, payload).stdout || '';
      const norm = (s) => s.split(model.root).join('/Users/someone/.claude/plugins/cache/kern/kern/0.1.0');
      const start = run('session-start', { session_id: 'lint', source: 'startup', cwd: repo, hook_event_name: 'SessionStart' });
      if (start.status !== 0 || !(start.stdout || '').trim()) out.push(err(7, 'hooks/session-start', `exited ${start.status} with ${(start.stdout || '').length} chars of output, so the kernel was not measured`));
      const kernel = norm(start.stdout || '');
      const terse = existsSync(join(model.root, 'modes', 'terse.md')) ? readFileSync(join(model.root, 'modes', 'terse.md'), 'utf8').length : 0;
      if (kernel.length > 4000) out.push(warn(7, 'kernel/kernel.md', `rendered kernel ${kernel.length} chars with the longest fixture settings, target 4,000`));
      if (kernel.length + terse > 9000) out.push(err(7, 'kernel/kernel.md', `rendered kernel plus terse rules ${kernel.length + terse} chars, limit 9,000`));
      // Standing cost (design goal 4): the kernel with no project settings, plus every auto skill and agent
      // description, the text every session carries.
      for (const f of ['kern.local.yml', 'kern.yml']) rmSync(join(repo, '.claude', f), { force: true });
      const bare = norm(run('session-start', { session_id: 'lint', source: 'startup', cwd: repo, hook_event_name: 'SessionStart' }).stdout || '');
      const desc = [...model.skills.filter((s) => !s.error && s.tier === 'auto'), ...model.agents.filter((a) => !a.error)].reduce((n, d) => n + (d.data.description || '').length, 0);
      if (bare.length + desc > 4800) out.push(err(7, 'kernel/kernel.md', `standing cost ${bare.length + desc} chars (kernel with no settings ${bare.length}, auto and agent descriptions ${desc}), limit 4,800`));
```

Append rule 12 to `RULES`, before the closing `];`:

```js
  { id: 12, check(model) {
    if (!existsSync(join(model.root, 'evals', 'cases'))) return [];
    const out = [];
    const need = (key, path) => {
      const c = model.cases[key];
      if (!c) { out.push(err(12, path, `no eval cases: evals/cases/${key}.json`)); return; }
      if (c.parseError) return;
      const pc = c.trigger?.positive?.length ?? 0;
      const nc = c.trigger?.negative?.length ?? 0;
      const ec = c.evals?.length ?? 0;
      if (pc < 3 || nc < 2 || ec < 1) out.push(err(12, path, `evals/cases/${key}.json has ${pc} positive, ${nc} negative, ${ec} behavioural; needs 3, 2, 1`));
    };
    for (const s of model.skills.filter((x) => !x.error && x.tier === 'auto')) need(s.name, rel(model, s.file));
    for (const [src, text] of [['kernel/kernel.md', model.kernelText], ['kernel/routes.md', model.routesText]]) {
      for (const r of kernelRows(text)) need(`row-${r.route}`, src);
    }
    return out;
  } },
```

`rmSync` is already imported (rule 7 used it before).

- [ ] **Step 6: Run the tests to verify they pass**

Run: `node --test tests/route-eval-rows.test.mjs tests/lint-rules.test.mjs tests/route-eval.test.mjs`
Expected: every test passes except `the fixed floors and the frozen held-out set are pinned`, which fails with ENOENT until Step 8 writes `evals/floors.json` and `evals/heldout.json`; Step 9 runs it again.

- [ ] **Step 7: Move the routing rows**

In `kernel/kernel.md`, in the Routing section, replace `match the task against the table. A casual turn` with:

```markdown
match the task against the table below, then Read {ROOT}/kernel/routes.md and match its rows when the task builds, fixes, plans, reviews, resumes or claims done. A casual turn
```

and replace M1's sentence `Non-trivial work with no match: write a short plan as a todo list first.` with the design spec's text (pre-flight F11):

```markdown
Several matches: define and diagnose before build. Non-trivial work with no match: plan.
```

Check: `grep -c 'Non-trivial work with no match' kernel/kernel.md` prints `1`, and `grep -c 'Several matches' kernel/kernel.md` prints `1`.

Write `kernel/routes.md`:

```markdown
# kern routes

The kernel's Routing rule reads this table after its own. {KERN} is {ROOT}/skills, as the kernel header says.

| Observable trigger | Route |
|---|---|
| New behaviour and no agreed spec | Read {KERN}/define/SKILL.md |
| Agreed spec, more than one step | Read {KERN}/plan/SKILL.md |
| Executing an agreed plan | Read {KERN}/execute-plan/SKILL.md |
| One bounded change with an agreed design | Read {KERN}/implement/SKILL.md |
| Bug, failing test, unexpected output | Read {KERN}/diagnose/SKILL.md |
| About to say done, fixed or passing, commit, or open a PR | Read {KERN}/prove-it/SKILL.md |
| Review requested on your own diff, no PR yet | Read {KERN}/self-review/SKILL.md |
| Starting or resuming after a gap | Read {KERN}/recall/SKILL.md |
```

In `skills/help/references/map.md`, change "A `path` skill loads through a kernel Routing row, or when typed." to "A `path` skill loads through a kernel Routing row, in `kernel/kernel.md` or `kernel/routes.md`, or when typed."

- [ ] **Step 8: Write the ten row case files, the held-out set and the floors**

Run this once from the repo root (it writes the files; it is not committed). The row-define positives use the row's own words (pre-flight F7); the prove-it and recall expectations name the hand-off and the Skill call.

```bash
node --input-type=module <<'NODE'
import { writeFileSync } from 'node:fs';
const rows = {
  define: [['New behaviour: a CSV export on the reports page, no spec yet', 'We need new behaviour for archiving old projects and nothing is specced yet', 'We want new behaviour for team invites and there is no agreed spec'], ['The test suite fails on main since this morning', 'Where did I leave off yesterday?'], 'Add rate limiting to the public API.', ['Reads kernel/routes.md, then skills/define/SKILL.md, before any other tool', 'States the class: spike, bounded or architectural', 'Writes no code before an explicit yes']],
  plan: [['The spec is agreed, break it into steps', 'Spec approved; we need a multi-step plan for the migration', 'Turn the agreed spec into ordered tasks'], ['Fix the typo in the README', 'Why does this test fail?'], 'The spec in .kern/specs/export.md is approved. Plan it.', ['Reads skills/plan/SKILL.md first', 'Checks the spec status before writing', 'Writes the plan with status: draft and stops for approval']],
  'execute-plan': [['Execute the agreed plan in .kern/plans/export.md', 'Start executing the approved plan task by task', 'Run the plan we agreed on'], ['What does this function return?', 'Rename this variable'], 'Execute .kern/plans/export.md in delegate mode.', ['Reads skills/execute-plan/SKILL.md first', 'Runs ledger-open before any task', 'Creates the ledger before dispatching']],
  implement: [['Make the bounded change we agreed: add the retry flag', 'Implement the agreed design for this one-file change', 'Go ahead with the small change we designed'], ['Where did I leave off?', 'Explain this stack trace'], 'The design for a --dry-run flag is agreed; implement it.', ['Reads skills/implement/SKILL.md first', 'Runs a failing test before the first production edit', 'Does not commit']],
  diagnose: [['This test is failing and I do not know why', 'There is a bug: the export returns unexpected output', 'Users report a bug where totals are wrong'], ['Add a new settings page', 'Write the PR description'], 'npm test fails on the sum test; fix it.', ['Reads skills/diagnose/SKILL.md first', 'Runs the failing command before stating a hypothesis', 'Adds a regression test that was red before the fix']],
  'prove-it': [['Is it fixed? Are the tests passing now?', 'We are done, commit it and open a PR', 'Say it is done once it passes'], ['Design a new caching layer', 'Catch me up on yesterday'], 'I think the bug is fixed, open a PR.', ['Runs the proving command before claiming', 'Quotes the exit code or failure count', 'Reads skills/finish-branch/SKILL.md before any push or PR']],
  'self-review': [['Review my diff before I open a PR', 'Review my own changes before the PR', 'Self-review this diff, there is no PR yet'], ['Fix the failing login test', 'Where did I leave off?'], 'Review my changes before I open the PR.', ['Reads skills/self-review/SKILL.md', 'Runs floor-scan and claim-check on the package', 'Ends with one verdict: ready, fix first, rebase first or split']],
  recall: [['Resuming after a two-week gap, where are we?', 'Starting again after a gap, catch me up', 'I am back after a gap; resume where we stopped'], ['Fix the failing test', 'Add a CSV export'], 'I am back after a week away. Where did I leave off?', ['Calls the kern:recall skill or Reads its SKILL.md', 'States the scope back', 'Writes no file']],
  'technical-writing': [['Write the PR body for this change', 'Draft the issue text for this bug', 'Write the doc for the new settings file'], ['Fix the failing test', 'Where did I leave off?'], 'Write the PR description for this branch.', ['Reads skills/technical-writing/SKILL.md', 'Leads with why', 'Uses no long dashes and no filler']],
  context: [['The context is filling up, what should we do?', 'This phase ends here, wrap up the context', 'We finished the phase; compact or clear?'], ['Add a CSV export', 'Fix the failing test'], 'The context is nearly full and the plan phase just ended.', ['Reads kernel/context.md', 'Proposes clear or compact only at the phase boundary', 'Sends bulk reads to subagents']],
};
for (const [route, [pos, neg, prompt, expectations]] of Object.entries(rows)) {
  const name = `row-${route}`;
  const data = {
    skill_name: name,
    trigger: { positive: pos.map((p) => ({ prompt: p, top_k: 3 })), negative: neg.map((p) => ({ prompt: p })) },
    evals: [{ id: 1, kind: 'dialogue', prompt, expected_output: `Routes to ${route} first and follows its steps.`, expectations }],
  };
  writeFileSync(`evals/cases/${name}.json`, JSON.stringify(data, null, 2) + '\n');
}
NODE
```

Write `evals/heldout.json` exactly as below, ending with a newline; the test pins the sha256 of that text (`9b5cb82...` with the trailing newline, `ac45620...` without). These are organic prompts written in the user's words, not the rows' words. They are never reworded; a miss is fixed in a row's or a description's text, and M2b adds the pilot's real prompts as a second frozen file.

```json
[
  { "owner": "define", "prompt": "Users keep asking for a dark mode toggle in settings. Can we add one?" },
  { "owner": "define", "prompt": "I want the dashboard to show weekly totals per team. How should that work?" },
  { "owner": "define", "prompt": "Let's add SSO login with Google for the admin panel." },
  { "owner": "plan", "prompt": "The billing spec is signed off. Break it down into tasks I can hand out." },
  { "owner": "plan", "prompt": "We agreed on the design doc for the importer rewrite. What's the order of work?" },
  { "owner": "plan", "prompt": "Spec for the audit log is approved, write up the implementation plan." },
  { "owner": "execute-plan", "prompt": "Go ahead and start on the plan in .kern/plans/audit-log.md." },
  { "owner": "execute-plan", "prompt": "Pick up the approved plan and work through the tasks." },
  { "owner": "implement", "prompt": "Add a --verbose flag to the CLI like we discussed." },
  { "owner": "implement", "prompt": "Rename the getUser helper to fetchUser across the two files." },
  { "owner": "implement", "prompt": "Change the retry count from 3 to 5 in the http client, as agreed." },
  { "owner": "diagnose", "prompt": "npm test is red on main, the date parser tests started failing today." },
  { "owner": "diagnose", "prompt": "The export endpoint returns a 500 when the filter list is empty. Why?" },
  { "owner": "diagnose", "prompt": "Totals on the invoice page are off by a cent for some orders." },
  { "owner": "prove-it", "prompt": "Ok I think we're done here, can you push it?" },
  { "owner": "prove-it", "prompt": "The agent says the migration task passed. Is it really finished?" },
  { "owner": "prove-it", "prompt": "Is the build green now after your change?" },
  { "owner": "self-review", "prompt": "Before I put this up for review, look over my changes." },
  { "owner": "self-review", "prompt": "Can you check my branch for problems before I open the pull request?" },
  { "owner": "recall", "prompt": "Back from vacation. What was I in the middle of?" },
  { "owner": "recall", "prompt": "What's the state of the floci work, what's left to do?" },
  { "owner": "recall", "prompt": "I lost track of which PRs are still open for the release." },
  { "owner": "technical-writing", "prompt": "Write up the description for this pull request." },
  { "owner": "technical-writing", "prompt": "Draft release notes for the 0.3.0 changes." },
  { "owner": "context", "prompt": "We're almost out of context, should I compact now?" }
]
```

Write `evals/floors.json`:

```json
{ "rank1": 85, "heldout_rank1": 32 }
```

- [ ] **Step 9: Run lint, routing evals and the size checks**

Run: `node scripts/lint-skills.mjs && node scripts/route-eval.mjs && node --test 'tests/**/*.test.mjs' && tests/run-bats tests/hooks/session-start.bats`
Expected: no lint errors (rule 6 resolves every row of both files; rule 7 sees the kernel at 3,926 chars with the longest settings, `routes.md` at 759 and a standing cost of 4,432; rule 12 finds every case file); `rank-1 rate: 88% (baseline 0%, fixed floor 85%)`, `held-out rank-1 rate: 36% (fixed floor 32%)`, `route-eval: passed`; `# fail 0`; the session-start tests pass, the under-4,000 one included. If a case positive ranks outside the top 3, reword that case prompt toward the row's words; never touch `evals/heldout.json` or `evals/floors.json`. Then run `node scripts/route-eval.mjs --update-baseline` and keep the raised baseline.

- [ ] **Step 10: Update the changelog and commit**

Add under `## [Unreleased]`: `- Kernel: M2's routes live in kernel/routes.md, which the Routing rule points to, for define, plan, execute-plan, implement, diagnose, prove-it, self-review and recall; routing evals with fixed floors and a frozen held-out set; lint rule 12 and a standing-cost budget.`

```bash
git add -- kernel/kernel.md kernel/routes.md scripts/lib/kernel-rows.mjs scripts/route-eval.mjs scripts/lib/lint-rules.mjs tests/route-eval-rows.test.mjs tests/lint-rules.test.mjs evals/cases evals/heldout.json evals/floors.json evals/baseline.json skills/help/references/map.md CHANGELOG.md
git commit -m "M2: route the M2 skills through kernel/routes.md and evaluate the rows" -m "Eight more rows in the kernel would have pushed it past 4,000 chars; a routed file costs one Read per routed task instead. Fixed floors and a frozen held-out set keep the routing evals from being tuned to pass."
```

- [ ] **Step 11: Checkpoint**

Run: `scripts/ci-local`
Expected: last line `ci-local: all steps passed`.

---

