### Task 7: The seeded-diff set for review checks

**Files:**
- Create: `evals/seeded-diffs/base/**` (seven files), `evals/seeded-diffs/<id>.diff` (twenty files), `evals/seeded-diffs/labels.json`, `scripts/seeded-diffs.mjs`
- Test: `tests/seeded-diffs.test.mjs`

**Interfaces:**
- Consumes: `scripts/floor-scan` (Task 5), `scripts/claim-check` (Task 6).
- Produces: `node scripts/seeded-diffs.mjs [--compare-addy]` runs floor-scan and claim-check on each labelled diff, prints one row per diff, `recall <class>: <found>/<seeded>` per class, and `seeded-diffs: <m> missed, <a> false alarms on <n> diffs`; exit 1 on any miss or false alarm. `--compare-addy` also runs addy's floor-guard reference (extracted from `.upstream/addy/skills/constraint-driven-development/references/floor-guard.md`) on each diff applied to the base, and prints its verdict next to kern's; it never changes the exit code. `labels.json`: `[{ "id": "<diff name>", "expect": ["<class>", ...] }]`, an empty `expect` for a decoy.

A planning-sandbox run of these diffs measured kern 12 of 12 seeded moves and 0 false alarms; addy's reference flagged 5 of the 12 and 4 of the 8 decoys (the reformatted and moved assertions, the renamed test, the doc TODO). Task 34 records the CI result; M2b's coverage re-audit cites it.

- [ ] **Step 1: Generate the base and the diffs**

Run this once from the repo root (it writes the files; it is not committed):

```bash
#!/usr/bin/env bash
# Writes evals/seeded-diffs/base/ and one <id>.diff per seeded move or decoy. Run once from the repo root.
set -euo pipefail
out=$PWD/evals/seeded-diffs
rm -rf "$out/base" "$out"/*.diff
mkdir -p "$out/base/src" "$out/base/test" "$out/base/.github/workflows"
b=$out/base
printf "import { sum } from '../src/sum.js';\ntest('sum', () => {\n  expect(sum(1, 2)).toBe(3);\n  expect(sum(0, 0)).toBe(0);\n});\n" > "$b/test/sum.test.js"
printf "test('old', () => {\n  expect(1).toBe(1);\n});\n" > "$b/test/old.test.js"
printf "export function sum(a, b) {\n  let i = 0;\n  --i;\n  return a + b;\n}\n" > "$b/src/sum.js"
printf '# Sum\n\nAdds two numbers.\n' > "$b/README.md"
printf "module.exports = {\n  coverageThreshold: { global: {\n    branches: 80,\n    lines: 90,\n  } },\n};\n" > "$b/jest.config.js"
printf '{\n  "compilerOptions": {\n    "strict": true\n  }\n}\n' > "$b/tsconfig.json"
printf 'jobs:\n  test:\n    steps:\n      - run: npm ci\n      - run: npm test\n' > "$b/.github/workflows/ci.yml"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# case ID: a fresh repo from base, the edit in the function body run in it, the staged diff saved as ID.diff.
case_() {
  local id=$1
  rm -rf "$work/r" && cp -R "$b" "$work/r"
  (cd "$work/r" && git init -q && git add -A && git -c user.email=s@example.com -c user.name=s commit -q -m base && "edit_$id" && git add -A && git diff --cached) > "$out/$id.diff"
}
# before FILE LINE NEW: insert NEW above the line equal to LINE. swap FILE LINE NEW: replace that line.
before() { awk -v at="$2" -v add="$3" '$0 == at { print add } { print }' "$1" > "$1.tmp" && mv "$1.tmp" "$1"; }
swap() { awk -v at="$2" -v to="$3" '$0 == at { print to; next } { print }' "$1" > "$1.tmp" && mv "$1.tmp" "$1"; }
R='  return a + b;'
edit_s01-skip() { printf "test.skip('later', () => {});\n" >> test/sum.test.js; }
edit_s02-assert-removed() { swap test/sum.test.js '  expect(sum(0, 0)).toBe(0);' ''; grep -v '^$' test/sum.test.js > t && mv t test/sum.test.js; }
edit_s03-test-deleted() { rm test/old.test.js; }
edit_s04-ts-ignore() { before src/sum.js "$R" '  // @ts-ignore'; }
edit_s05-as-any() { swap src/sum.js "$R" '  return (a as any) + b;'; }
edit_s06-empty-catch() { before src/sum.js "$R" '  try { check(a); } catch (e) {}'; }
edit_s07-debug() { before src/sum.js "$R" '  console.log(a, b);'; }
edit_s08-coverage-lowered() { swap jest.config.js '    branches: 80,' '    branches: 70,'; }
edit_s09-strict-off() { swap tsconfig.json '    "strict": true' '    "strict": false'; }
edit_s10-ci-nonblocking() { before .github/workflows/ci.yml '    steps:' '    continue-on-error: true'; }
edit_s11-unknown-sha() { before src/sum.js "$R" '  // fixed in deadbee1cafe'; }
edit_s12-absolute-claim() { before src/sum.js "$R" '  // sum is never called before init'; }
edit_d01-reformatted-assert() { swap test/sum.test.js '  expect(sum(1, 2)).toBe(3);' '  expect( sum(1, 2) ).toBe( 3 )'; }
edit_d02-renamed-test() { git mv test/old.test.js test/legacy.test.js; }
edit_d03-doc-todo() { printf 'TODO: document the overflow case.\n' >> README.md; }
edit_d04-hex-colour() { printf "export const colour = '#a1b2c3d4';\n" >> src/sum.js; }
edit_d05-uuid() { printf "export const id = '123e4567-e89b-12d3-a456-426614174000';\n" >> src/sum.js; }
edit_d06-moved-assert() { swap test/sum.test.js '  expect(sum(1, 2)).toBe(3);' '  expect(sum(0, 0)).toBe(0);'; awk 'NR == 4 { print "  expect(sum(1, 2)).toBe(3);"; next } { print }' test/sum.test.js > t && mv t test/sum.test.js; }
edit_d07-decrement() { swap src/sum.js '  --i;' '  ++i;'; }
edit_d08-threshold-raised() { swap jest.config.js '    lines: 90,' '    lines: 95,'; }
for id in s01-skip s02-assert-removed s03-test-deleted s04-ts-ignore s05-as-any s06-empty-catch s07-debug \
  s08-coverage-lowered s09-strict-off s10-ci-nonblocking s11-unknown-sha s12-absolute-claim \
  d01-reformatted-assert d02-renamed-test d03-doc-todo d04-hex-colour d05-uuid d06-moved-assert d07-decrement d08-threshold-raised; do
  case_ "$id"
done
```

Then check: `ls evals/seeded-diffs/*.diff | wc -l` prints `20`.

- [ ] **Step 2: Write `evals/seeded-diffs/labels.json`**

```json
[
  { "id": "s01-skip", "expect": ["test-made-easier"] },
  { "id": "s02-assert-removed", "expect": ["assertion-removed"] },
  { "id": "s03-test-deleted", "expect": ["test-deleted"] },
  { "id": "s04-ts-ignore", "expect": ["silenced-checker"] },
  { "id": "s05-as-any", "expect": ["silenced-checker"] },
  { "id": "s06-empty-catch", "expect": ["unfinished-work"] },
  { "id": "s07-debug", "expect": ["debug-print"] },
  { "id": "s08-coverage-lowered", "expect": ["bar-lowered"] },
  { "id": "s09-strict-off", "expect": ["bar-lowered"] },
  { "id": "s10-ci-nonblocking", "expect": ["bar-lowered"] },
  { "id": "s11-unknown-sha", "expect": ["sha-unknown"] },
  { "id": "s12-absolute-claim", "expect": ["absolute-claim"] },
  { "id": "d01-reformatted-assert", "expect": [] },
  { "id": "d02-renamed-test", "expect": [] },
  { "id": "d03-doc-todo", "expect": [] },
  { "id": "d04-hex-colour", "expect": [] },
  { "id": "d05-uuid", "expect": [] },
  { "id": "d06-moved-assert", "expect": [] },
  { "id": "d07-decrement", "expect": [] },
  { "id": "d08-threshold-raised", "expect": [] }
]
```

- [ ] **Step 3: Write the failing test**

```js
// tests/seeded-diffs.test.mjs: the review seeded-diff set runs in CI with no miss and no false alarm.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const DIR = fileURLToPath(new URL('../evals/seeded-diffs/', import.meta.url));

test('every labelled diff exists, and there are 12 seeded moves and 8 decoys', () => {
  const labels = JSON.parse(readFileSync(`${DIR}labels.json`, 'utf8'));
  const diffs = readdirSync(DIR).filter((f) => f.endsWith('.diff')).map((f) => f.replace(/\.diff$/, '')).sort();
  assert.deepEqual(labels.map((l) => l.id).sort(), diffs);
  assert.equal(labels.filter((l) => l.expect.length).length, 12);
  assert.equal(labels.filter((l) => !l.expect.length).length, 8);
});

test('floor-scan and claim-check find every seeded move and no decoy', () => {
  const r = spawnSync(process.execPath, [fileURLToPath(new URL('../scripts/seeded-diffs.mjs', import.meta.url))], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stdout + r.stderr);
  assert.match(r.stdout, /^seeded-diffs: 0 missed, 0 false alarms on 20 diffs$/m);
});
```

- [ ] **Step 4: Run it to verify it fails**

Run: `node --test tests/seeded-diffs.test.mjs`
Expected: the second test fails; `Cannot find module '.../scripts/seeded-diffs.mjs'` in its output.

- [ ] **Step 5: Write `scripts/seeded-diffs.mjs`**

```js
#!/usr/bin/env node
// The review seeded-diff set: run floor-scan and claim-check on each labelled diff in evals/seeded-diffs/
// and report per-class recall and false alarms. Exit 1 on any miss or false alarm.
// Usage: node scripts/seeded-diffs.mjs [--compare-addy]
// --compare-addy also runs addy's floor-guard reference (from .upstream/addy) on each diff and prints its
// verdict next to kern's; it never changes the exit code.
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = fileURLToPath(new URL('..', import.meta.url));
const DIR = join(ROOT, 'evals', 'seeded-diffs');
const labels = JSON.parse(readFileSync(join(DIR, 'labels.json'), 'utf8'));
const tmp = mkdtempSync(join(tmpdir(), 'seeded-'));
const git = (cwd, ...a) => spawnSync('git', ['-C', cwd, '-c', 'user.email=s@example.com', '-c', 'user.name=s', ...a], { encoding: 'utf8' });

// A repo at the base, so claim-check can ask which commit ids exist and addy's guard can diff.
function baseRepo(name) {
  const r = join(tmp, name);
  cpSync(join(DIR, 'base'), r, { recursive: true });
  git(r, 'init', '-q');
  git(r, 'add', '-A');
  git(r, 'commit', '-q', '-m', 'base');
  return r;
}

const classes = (out) => out.split('\n').filter(Boolean).map((l) => l.split('\t')[1]);
const wt = baseRepo('wt');
const rows = [];
const stats = {};
let misses = 0;
let alarms = 0;
for (const { id, expect } of labels) {
  const diff = join(DIR, `${id}.diff`);
  const fs = spawnSync('bash', [join(ROOT, 'scripts', 'floor-scan'), diff], { cwd: wt, encoding: 'utf8' });
  const cc = spawnSync('bash', [join(ROOT, 'scripts', 'claim-check'), wt, diff], { encoding: 'utf8' });
  if (fs.status === 2 || cc.status === 2) { console.log(`error: ${id}: ${fs.stderr}${cc.stderr}`); misses++; continue; }
  const got = new Set([...classes(fs.stdout), ...classes(cc.stdout)]);
  for (const c of expect) {
    stats[c] ??= { seeded: 0, found: 0 };
    stats[c].seeded++;
    if (got.has(c)) stats[c].found++;
    else { misses++; console.log(`miss: ${id} expected ${c}`); }
  }
  for (const c of got) if (!expect.includes(c)) { alarms++; console.log(`false alarm: ${id} reported ${c}`); }
  rows.push({ id, expect: expect.join(',') || 'decoy', got: [...got].join(',') || 'clean' });
}

if (process.argv.includes('--compare-addy')) {
  const ref = join(ROOT, '.upstream', 'addy', 'skills', 'constraint-driven-development', 'references', 'floor-guard.md');
  if (!existsSync(ref)) console.log('compare-addy: .upstream/addy is missing; run scripts/fetch-upstream');
  else {
    const md = readFileSync(ref, 'utf8');
    const code = md.slice(md.indexOf('```js\n') + 6, md.indexOf('\n```', md.indexOf('```js\n')));
    const guard = join(tmp, 'floor-guard.mjs');
    writeFileSync(guard, code);
    for (const row of rows) {
      const r = baseRepo(`addy-${row.id}`);
      git(r, 'apply', join(DIR, `${row.id}.diff`));
      const a = spawnSync(process.execPath, [guard, '--base', 'HEAD'], { cwd: r, encoding: 'utf8' });
      row.addy = a.status === 1 ? 'hit' : a.status === 0 ? 'clean' : `error ${a.status}`;
    }
  }
}

for (const r of rows) console.log(`${r.id}\texpect ${r.expect}\tkern ${r.got}${r.addy ? `\taddy ${r.addy}` : ''}`);
for (const [c, s] of Object.entries(stats)) console.log(`recall ${c}: ${s.found}/${s.seeded}`);
console.log(`seeded-diffs: ${misses} missed, ${alarms} false alarms on ${labels.length} diffs`);
rmSync(tmp, { recursive: true, force: true });
process.exit(misses || alarms ? 1 : 0);
```

- [ ] **Step 6: Run it to verify it passes**

Run: `node --test tests/seeded-diffs.test.mjs && node scripts/seeded-diffs.mjs | tail -n 1`
Expected: `# fail 0`; `seeded-diffs: 0 missed, 0 false alarms on 20 diffs`. A miss means floor-scan or claim-check regressed: fix the script, never the label.

- [ ] **Step 7: Commit**

```bash
git add -- evals/seeded-diffs scripts/seeded-diffs.mjs tests/seeded-diffs.test.mjs
git commit -m "M2: add the seeded-diff set for review checks" -m "Per-class recall and a false-alarm count on labelled diffs make the review checks measurable in CI, and comparable with addy's floor guard on demand."
```

- [ ] **Step 8: Checkpoint**

Run: `scripts/ci-local`
Expected: last line `ci-local: all steps passed`.

---

