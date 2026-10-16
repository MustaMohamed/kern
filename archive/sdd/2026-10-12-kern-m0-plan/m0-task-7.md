### Task 7: Routing evals (tier 1)

**Files:**
- Create: `scripts/lib/rank.mjs` (ported), `scripts/route-eval.mjs`, `evals/cases/hello.json`, `evals/distractors.json`, `evals/baseline.json`, `evals/fixtures/hello/README.md`
- Test: `tests/route-eval.test.mjs`
- Modify: `NOTICE` (file map line)

**Interfaces:**
- Consumes: `loadModel(root)` from Task 5 (auto skills are `tier === 'auto'`); `isMain(import.meta.url)` from `scripts/lib/is-main.mjs` (Task 6 fix round: compares real paths so a symlinked path still runs the CLI).
- Produces:
  - `rank.mjs`: `tokenize(text) -> string[]`, `buildCorpus(docs: {name, text}[]) -> Corpus`, `rank(prompt, corpus) -> {name, score}[]` (descending), `similarity(nameA, nameB, corpus) -> number`.
  - `route-eval.mjs`: `targets(root) -> {name, text, kind: 'skill'|'distractor'}[]`, owners first and distractors last (M2 adds `kind: 'row'` for kernel rows, placed before the distractors), `evaluate(root, { minRank1 }) -> { errors: string[], warnings: string[], rank1Rate: number|null }`; CLI `node scripts/route-eval.mjs [--update-baseline]` exits 1 on any error.
  - Case file shape (addy's): `{ "skill_name": "<name>", "trigger": { "positive": [{ "prompt", "top_k" }], "negative": [{ "prompt", "owner"? }] }, "evals": [{ "id", "kind": "execution"|"dialogue", "prompt", "expected_output", "expectations": [], "files"? }] }`.
  - `evals/baseline.json`: `{ "min_rank1": <integer percent> }`; the run fails below it; `--update-baseline` raises it to the current rate and never lowers it.

- [ ] **Step 1: Write the failing tests**

```js
// tests/route-eval.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { buildCorpus, rank } from '../scripts/lib/rank.mjs';
import { evaluate } from '../scripts/route-eval.mjs';

const skill = (name, desc) => `---\nname: ${name}\ndescription: ${desc}\n---\n\n## Steps\n\n1. a\n`;
function repo(files) {
  const root = mkdtempSync(join(tmpdir(), 'kern-eval-'));
  for (const [p, c] of Object.entries(files)) {
    mkdirSync(join(root, p, '..'), { recursive: true });
    writeFileSync(join(root, p), typeof c === 'string' ? c : JSON.stringify(c));
  }
  return root;
}
const caseFile = (name, positive, negative) => ({
  skill_name: name,
  trigger: { positive: positive.map((prompt) => ({ prompt, top_k: 3 })), negative: negative.map((prompt) => ({ prompt })) },
  evals: [{ id: 1, kind: 'dialogue', prompt: 'x', expected_output: 'y', expectations: ['z'] }],
});

test('rank orders by shared vocabulary', () => {
  const c = buildCorpus([{ name: 'tests', text: 'run failing tests suite' }, { name: 'deploy', text: 'deploy release production' }]);
  assert.equal(rank('my tests are failing', c)[0].name, 'tests');
});

test('zero-score prompt is an error, not a crash', () => {
  const root = repo({
    'skills/a/SKILL.md': skill('a', 'Use when greeting kern hello'),
    'evals/cases/a.json': caseFile('a', ['hello kern', 'greeting kern', 'qqq zzz'], ['deploy prod', 'weather today']),
    'evals/distractors.json': [],
    'evals/baseline.json': { min_rank1: 0 },
  });
  const r = evaluate(root, { minRank1: 0 });
  assert.equal(r.errors.length, 1);
  assert.match(r.errors[0], /shares no vocabulary/);
});

test('auto skill without a case file is an error', () => {
  const root = repo({ 'skills/a/SKILL.md': skill('a', 'Use when greeting kern'), 'evals/distractors.json': [], 'evals/baseline.json': { min_rank1: 0 } });
  assert.match(evaluate(root, { minRank1: 0 }).errors[0], /no eval case file/);
});

test('below minimums is an error', () => {
  const root = repo({
    'skills/a/SKILL.md': skill('a', 'Use when greeting kern hello'),
    'evals/cases/a.json': caseFile('a', ['hello kern'], ['deploy prod']),
    'evals/distractors.json': [],
    'evals/baseline.json': { min_rank1: 0 },
  });
  assert.ok(evaluate(root, { minRank1: 0 }).errors.some((e) => /below required minimums/.test(e)));
});

test('a distractor that outranks the skill fails the positive', () => {
  const root = repo({
    'skills/a/SKILL.md': skill('a', 'Use when greeting kern hello or showing a plan'),
    'evals/cases/a.json': { ...caseFile('a', [], []), trigger: { positive: [{ prompt: 'write a plan for tasks', top_k: 1 }, { prompt: 'hello kern', top_k: 3 }, { prompt: 'greeting kern', top_k: 3 }], negative: [{ prompt: 'deploy prod' }, { prompt: 'weather today' }] } },
    'evals/distractors.json': [{ name: 'writing-plans', description: 'Use when writing a plan for multi-step tasks' }],
    'evals/baseline.json': { min_rank1: 0 },
  });
  const errors = evaluate(root, { minRank1: 0 }).errors;
  assert.ok(errors.some((e) => /positive prompt ranked #2/.test(e)), errors.join('\n'));
});
  assert.ok(evaluate(root, { minRank1: 0 }).errors.some((e) => /positive prompt ranked/.test(e) || /shares no vocabulary/.test(e)));
});

test('rank-1 rate below the baseline fails', () => {
  const root = repo({
    'skills/a/SKILL.md': skill('a', 'Use when greeting kern hello'),
    'evals/cases/a.json': caseFile('a', ['hello kern', 'greeting kern', 'kern hello there'], ['deploy prod', 'weather today']),
    'evals/distractors.json': [],
    'evals/baseline.json': { min_rank1: 100 },
  });
  assert.deepEqual(evaluate(root, { minRank1: 100 }).errors, []);
  assert.equal(evaluate(root, { minRank1: 101 }).errors.length, 1);
});
```

- [ ] **Step 2: Run them to verify they fail**

Run: `node --test tests/route-eval.test.mjs`
Expected: FAIL with `Cannot find module '.../scripts/lib/rank.mjs'`.

- [ ] **Step 3: Port the ranking functions into `scripts/lib/rank.mjs`**

Port `STOP`, `stem`, `tokenize`, `termFreq` (lines 62-102) and `vec`, `cosine` (lines 121-139) verbatim from `.upstream/addy/scripts/run-evals.js`, converted to ESM `export`s. Skip lines 104-119: addy's `buildCorpus` takes skills, and kern's version below takes `{name, text}` documents.

```js
// Adapted from addyosmani/agent-skills scripts/run-evals.js (MIT): the tier 2 text pipeline.

// <lines 62-102 and 121-139 of .upstream/addy/scripts/run-evals.js go here unchanged except `function` becomes `export function` for tokenize, termFreq, vec, cosine>

export function buildCorpus(docs) {
  const map = new Map();
  for (const d of docs) {
    const nameTokens = tokenize(d.name.replace(/-/g, ' '));
    map.set(d.name, termFreq([...nameTokens, ...nameTokens, ...tokenize(d.text)]));
  }
  const df = new Map();
  for (const tf of map.values()) for (const term of tf.keys()) df.set(term, (df.get(term) || 0) + 1);
  const n = map.size;
  const idf = (term) => Math.log(1 + n / (1 + (df.get(term) || 0)));
  return { docs: map, idf };
}

export function rank(prompt, corpus) {
  const pv = vec(termFreq(tokenize(prompt)), corpus.idf);
  const scores = [];
  for (const [name, tf] of corpus.docs) scores.push({ name, score: cosine(pv, vec(tf, corpus.idf)) });
  scores.sort((a, b) => b.score - a.score);
  return scores;
}

export function similarity(a, b, corpus) {
  return cosine(vec(corpus.docs.get(a), corpus.idf), vec(corpus.docs.get(b), corpus.idf));
}
```

The angle-bracket comment is an executor instruction: replace it with the copied lines. Check: `grep -c 'export function' scripts/lib/rank.mjs` prints `7` (tokenize, termFreq, vec, cosine, buildCorpus, rank, similarity), and the tokenizer check `[ 'conflict', 'branch' ]` when given `'conflicts branching'`; run it as `node -e "import('./scripts/lib/rank.mjs').then(m => console.log(m.tokenize('conflicts branching')))"`.

- [ ] **Step 4: Write `scripts/route-eval.mjs`**

```js
#!/usr/bin/env node
// Tier 1 routing evals (design spec 11.1). Adapted from addyosmani/agent-skills scripts/run-evals.js (MIT), deterministic tier only.
import { readFileSync, writeFileSync, readdirSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { isMain } from './lib/is-main.mjs';
import { loadModel } from './lib/lint-rules.mjs';
import { buildCorpus, rank, similarity } from './lib/rank.mjs';

const MIN_POSITIVE = 3;
const MIN_NEGATIVE = 2;
const MIN_EVALS = 1;
const COLLISION_WARN = 0.5;
const COLLISION_ERROR = 0.75;

export function targets(root) {
  const skills = loadModel(root).skills.filter((s) => s.tier === 'auto' && s.data.description)
    .map((s) => ({ name: s.name, text: s.data.description, kind: 'skill' }));
  const dPath = join(root, 'evals', 'distractors.json');
  const distractors = existsSync(dPath) ? JSON.parse(readFileSync(dPath, 'utf8')).map((d) => ({ name: d.name, text: d.description, kind: 'distractor' })) : [];
  return [...skills, ...distractors];
}

function loadCases(root) {
  const dir = join(root, 'evals', 'cases');
  if (!existsSync(dir)) return [];
  return readdirSync(dir).filter((f) => f.endsWith('.json')).map((f) => {
    try { return { file: f, data: JSON.parse(readFileSync(join(dir, f), 'utf8')) }; }
    catch (e) { return { file: f, parseError: e.message }; }
  });
}

export function evaluate(root, { minRank1 }) {
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
      const idx = r.findIndex((x) => x.name === expected);
      const hit = r[idx];
      if (idx === 0 && hit.score > 0) rank1++;
      if (!hit || hit.score === 0) errors.push(`${expected}: description shares no vocabulary with "${p.prompt}"`);
      else if (idx >= topK) errors.push(`${expected}: positive prompt ranked #${idx + 1} (need top ${topK}): "${p.prompt}"; top: ${r.slice(0, 3).map((x) => `${x.name} ${x.score.toFixed(2)}`).join(', ')}`);
    }
    for (const n of d.trigger?.negative || []) {
      const r = rank(n.prompt, corpus);
      if (r[0].name === expected && r[0].score > 0) errors.push(`${expected}: ranked #1 for negative prompt "${n.prompt}"`);
      if (n.owner) {
        if (!names.has(n.owner)) errors.push(`${c.file}: negative names unknown owner "${n.owner}"`);
        else {
          const oi = r.findIndex((x) => x.name === n.owner);
          const si = r.findIndex((x) => x.name === expected);
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
      const sim = similarity(a, b, corpus);
      if (sim >= COLLISION_ERROR) errors.push(`collision: ${a} and ${b} are ${(sim * 100).toFixed(0)}% similar`);
      else if (sim >= COLLISION_WARN) warnings.push(`overlap: ${a} and ${b} are ${(sim * 100).toFixed(0)}% similar`);
    }
  }

  const rank1Rate = positives ? Math.floor((rank1 / positives) * 100) : null;
  if (minRank1 !== null && rank1Rate !== null && rank1Rate < minRank1) errors.push(`rank-1 rate ${rank1Rate}% is below the baseline ${minRank1}%`);
  return { errors, warnings, rank1Rate };
}

if (isMain(import.meta.url)) {
  const root = fileURLToPath(new URL('..', import.meta.url));
  const basePath = join(root, 'evals', 'baseline.json');
  const baseline = JSON.parse(readFileSync(basePath, 'utf8'));
  const r = evaluate(root, { minRank1: baseline.min_rank1 });
  for (const w of r.warnings) console.log(`warn: ${w}`);
  for (const e of r.errors) console.log(`error: ${e}`);
  console.log(`rank-1 rate: ${r.rank1Rate ?? 'n/a'}% (baseline ${baseline.min_rank1}%)`);
  if (process.argv.includes('--update-baseline') && !r.errors.length && r.rank1Rate !== null && r.rank1Rate > baseline.min_rank1) {
    writeFileSync(basePath, JSON.stringify({ min_rank1: r.rank1Rate }, null, 2) + '\n');
    console.log(`baseline raised to ${r.rank1Rate}%`);
  }
  console.log(r.errors.length ? 'route-eval: FAILED' : 'route-eval: passed');
  process.exit(r.errors.length ? 1 : 0);
}
```

- [ ] **Step 5: Write the eval data**

`evals/cases/hello.json`:
```json
{
  "skill_name": "hello",
  "trigger": {
    "positive": [
      { "prompt": "hello kern", "top_k": 3 },
      { "prompt": "is kern installed?", "top_k": 3 },
      { "prompt": "say hello and tell me the kern version", "top_k": 3 }
    ],
    "negative": [
      { "prompt": "write an implementation plan for the export feature", "owner": "writing-plans" },
      { "prompt": "this test fails with a null pointer, find the cause", "owner": "systematic-debugging" }
    ]
  },
  "evals": [
    {
      "id": 1,
      "kind": "dialogue",
      "prompt": "hello kern",
      "expected_output": "One line naming the installed kern version",
      "expectations": ["Reply names the version from plugin.json", "Reply is one line"]
    }
  ]
}
```

`evals/distractors.json` (third-party skills likely to sit beside kern; descriptions shortened from superpowers 6.4.1):
```json
[
  { "name": "writing-plans", "description": "Use when you have a spec or requirements for a multi-step task, before touching code" },
  { "name": "systematic-debugging", "description": "Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes" },
  { "name": "brainstorming", "description": "Use before any creative work: creating features, building components, adding functionality" },
  { "name": "verification-before-completion", "description": "Use when about to claim work is complete, fixed, or passing, before committing or creating PRs" }
]
```

Before writing it, check each description against `.upstream/superpowers/skills/<name>/SKILL.md` and use the upstream description's first clause verbatim. Append three lines under `## File map` in NOTICE:
```text
- evals/distractors.json: superpowers skills/*/SKILL.md descriptions (first clauses)
- scripts/lib/rank.mjs: addy scripts/run-evals.js lines 62-102 and 121-139
- scripts/route-eval.mjs: addy scripts/run-evals.js runDeterministic (adapted)
```

`evals/baseline.json`:
```json
{ "min_rank1": 0 }
```

`evals/fixtures/hello/README.md`:
```markdown
Fixture directory for execution evals. Dialogue evals need no files.
```

- [ ] **Step 6: Run the tests and the real eval**

Run: `node --test tests/route-eval.test.mjs && node scripts/route-eval.mjs`
Expected: `# fail 0`; then `route-eval: passed`. Leave `evals/baseline.json` at 0: a one-skill placeholder corpus would set a floor that M2 cannot hold once `hello` is gone; M2 raises it with `--update-baseline` after its real auto skills land. If a hello positive ranks below a distractor, reword the hello description (keep it under 300 chars and the trigger phrase) rather than the prompt.

- [ ] **Step 7: Commit**

```bash
git add -- scripts/lib/rank.mjs scripts/route-eval.mjs evals tests/route-eval.test.mjs NOTICE
git commit -m "M0: add tier 1 routing evals with distractors and a rank-1 floor" -m "Descriptions are scored against real neighbouring skills, and the floor only rises."
```

---

