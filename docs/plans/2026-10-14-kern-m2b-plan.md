# kern M2b Implementation Plan

**Status: Draft. Not pre-flighted. Revisit when M2a closes; the user deferred M2b on 2026-10-14.**

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove goal 0 for M2 against the sources and the user's own judgment, then release 0.4.0: a behavioural eval runner with pressure tests (coverage gap 13); a kernel-adherence grader with host isolation, negative and multi-turn cases and committed snapshots (gap 10); head-to-head evals for planning, debugging and review against superpowers, pocock and a no-plugin control on seeded fixtures with hidden answer keys; a standing-cost measurement in tokens; the coverage re-audit of M2 rows; and the side-by-side pilot, after which the user decides on switching superpowers off.

**Architecture:** Every runner reuses M2a's `scripts/lib/claude-run.mjs`: a project-shaped temp workspace, `claude -p` with stream-json in and out, and the isolation flags `--setting-sources project --strict-mcp-config --no-session-persistence`, so the user's plugins, hooks, MCP servers and saved sessions never reach a run. Grading is code first and a model second: the adherence grader is pure code over the tool calls; the behaviour and head-to-head graders are separate, isolated `claude -p` calls that see a digest of the run and, for head-to-head, redacted attempts under blind ids, with the key written only after grading. Pure parts (case loading, digests, verdict parsing, pass rules, redaction, blinding, the gate) are unit-tested in CI with no model call; the fixtures are tested in CI too (a diagnose fixture's held-out tests fail on the repo and pass with its reference patch; a review fixture's labels sit on added lines of a patch that keeps the tests green). Runs that spend tokens happen only on the user's yes and leave committed snapshots.

**Tech Stack:** Node 22 (`node:test`, no npm dependencies), bash 3.2+, git 2.31+, Claude Code 2.1.296 (`claude -p --plugin-dir --input-format stream-json --output-format stream-json --verbose`, `--output-format json` for the usage block), the upstream trees from `scripts/fetch-upstream` (superpowers `bb92a777`, pocock `49dd158d`).

**Spec:** `docs/specs/2026-10-12-kern-design.md` (sections 1.1, 11, 13, 14 row M2b) and `docs/specs/coverage.md`. Shared names: `docs/plans/contract.md`, "Additions from the M2a and M2b plans". Traceability: `docs/plans/2026-10-14-kern-m2-traceability.md`. Starts from tag `v0.3.0` (M2a Task 34).

## Global Constraints

- M2a's Global Constraints apply unchanged; this list adds what is specific to M2b.
- A step that runs `claude -p` spends tokens. Before it, show the command, the number of model calls it makes (cases x runs, plus grader calls) and the model, then ask; run it only on the user's yes. Every runner has `--dry-run`, which calls no model and lists what a run would do.
- Isolation: every model run goes through `runClaude` with `ISOLATION`; the runner records `ISOLATION`, the model and `claude --version` in its snapshot. Fixture copies get project-shaped names (`billing-service`, `shop-cart`, `invoice-service`); no path, file or prompt the model sees names an eval, a grader or an answer key.
- Pass rules are fixed before any run and are not tuned after: a behaviour or adherence case passes on at least two of three runs (behaviour: and at most one invalid run); a head-to-head category passes when kern's mean score is at least the strongest other arm's and its mean false alarms are at most that arm's, the control arm included; the pilot's pass rule is in `docs/pilot.md`, written and agreed before the first pilot run.
- A failed gate is a finding, not a reason to edit the case. Fix kern, record the fix under "Tasks added during execution", and re-run. A case, fixture, rubric or answer key changes only when it is wrong on its own terms (it tests something the spec does not say), and the change says so in its commit body.
- Snapshots (`evals/snapshots/*.json`) are committed. Raw transcripts and head-to-head keys go to `evals/results/` (gitignored).
- Haiku runs are reported, never gating.
- Prose in every file follows unslop: answer first, no filler, no long dashes, no curly quotes.

## Review Focus

1. **A grader that passes a run it should fail.** A bare skill name, or a skill file under `~/.claude/skills`, is not kern's route. Pinned in Task 2 (`a bare skill name or a skill file outside the plugin root is not the route`).
2. **A grader reply that is not JSON, or has the wrong count.** It voids the run; it never passes it. Pinned in Task 1 (`a grader reply that is not one JSON verdict per expectation is invalid, never a pass`) and Task 3 (`a malformed grade voids the run`).
3. **An arm identifiable from its output.** Plugin names, skill paths, `CLAUDE_PLUGIN_ROOT` and `.kern/` are redacted before the grader sees an attempt. Pinned in Task 3 (`redaction removes every name, path and namespaced skill that identifies an arm`).
4. **A nested `node --test` that reports to its parent.** A fixture test that spawns `node --test` must drop `NODE_TEST_CONTEXT`, or the child reports into the parent's stream and exits 0 with no tests run. Pinned in Task 3 (the fixture tests fail before the reference patch, which they could not if the child ran nothing).
5. **A fixture whose bug is caught by its own visible tests.** A diagnose or review fixture is useless if `npm test` already fails on it (unless the task says the visible test fails). Pinned in Tasks 3, 5 and 6.
6. **Pilot prompts reworded after the fact.** `evals/heldout-pilot.json` is pinned by its sha256 in the commit that creates it. Pinned in Task 11.

---

## File map

| Path | Task | Responsibility |
|---|---|---|
| `scripts/lib/behave.mjs`, `scripts/behave.mjs`, `evals/behave/pressure.json`, `evals/behave/workflows.json`, `evals/behave/fixtures/**`, `tests/behave.test.mjs` | 1 | Behavioural runner and pressure tests |
| `scripts/lib/adherence.mjs`, `scripts/kernel-adherence.mjs`, `evals/adherence/cases.json`, `evals/adherence/fixtures/**`, `tests/adherence.test.mjs` | 2 | Kernel-adherence grader |
| `scripts/lib/h2h.mjs`, `scripts/h2h.mjs`, `evals/h2h/arms.json`, `evals/h2h/diagnose/three-calls/**`, `tests/h2h.test.mjs` | 3 | Head-to-head harness and its first fixture |
| `evals/h2h/plan/**`, `tests/h2h.test.mjs` | 4 | Planning fixtures |
| `evals/h2h/diagnose/**`, `tests/h2h.test.mjs` | 5 | Debugging fixtures |
| `evals/h2h/review/invoice-branch/**`, `tests/h2h.test.mjs` | 6 | Review fixture; the fixture set is complete |
| `scripts/standing-cost.mjs`, `tests/standing-cost.test.mjs` | 7 | Standing cost in tokens |
| `evals/snapshots/*.json`, `CHANGELOG.md` | 8 | The evidence runs |
| `docs/specs/coverage.md`, `tests/coverage.test.mjs` | 9 | Coverage re-audit of M2 |
| `docs/pilot.md`, `tests/skills/prove-it.acceptance.md` | 10 | Pilot protocol, written before any pilot run |
| `scripts/route-eval.mjs`, `evals/heldout-pilot.json`, `tests/route-eval-rows.test.mjs`, `docs/pilot.md` | 11 | Pilot runs; real prompts frozen |
| `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `CHANGELOG.md`, `docs/pilot.md` | 12 | Release 0.4.0 and the switch-off decision |

Checkpoints: after Tasks 3, 6 and 9, run `scripts/ci-local` and stop if anything is red. Tasks 1 to 7 and 9 to 10 change no skill, agent, kernel or hook file, so lint rule 14 asks for no CHANGELOG line from them; Task 8's fixes do.

Hours: Task 1 1.5, Task 2 1.5, Task 3 2, Task 4 1.5, Task 5 2.5, Task 6 1, Task 7 0.5, Task 8 2 plus fixes, Task 9 1.5, Task 10 1, Task 11 2.5 of agent time (the user's own pilot hours are not counted), Task 12 0.5. Total about 18 hours before fixes, against the design's 12 to 16; the fixtures (Tasks 3 to 6, 7 hours) are the overrun.

---

### Task 1: Behavioural eval runner and pressure tests (coverage gap 13)

**Files:**
- Create: `scripts/lib/behave.mjs`, `scripts/behave.mjs`, `evals/behave/pressure.json`, `evals/behave/workflows.json`, `evals/fixtures/node-bug/{package.json,README.md,bin/cli.js,src/sum.js,test/sum.test.js}`, `evals/fixtures/approved-spec/_kern/specs/export.md`, `evals/fixtures/approved-plan/_kern/plans/export.md`, `evals/fixtures/two-modules/{src/tax.js,test/tax.test.js}`
- Modify: `evals/cases/recall.json` (eval 2 gets a project layer)
- Test: `tests/behave.test.mjs`
- Create on a run: `evals/snapshots/behave-<model>-<date>.json` (Task 8)

**Interfaces:**
- Consumes: M2a's `scripts/lib/claude-run.mjs` (`ISOLATION`, `PERMISSIONS`, `workspace`, `runClaude`, `toolUses`, `finalText`, `claudeVersion`); the `evals[]` arrays of `evals/cases/*.json` (M0 format: `id`, `kind`, `prompt`, `expected_output`, `expectations`, optional `files` naming layers under `evals/fixtures/`); M2a's `evals/fixtures/recall-ledger`.
- Produces:
  - `scripts/lib/behave.mjs`: `stage(root, files) -> dir` (one layer in place; several copied in order into a temp dir the caller removes); `loadCases(root) -> [{ id, source, files, prompts, expectations, pressure, origin?, branch?, setup?, max_turns? }]` (skips `row-*.json`, which the adherence grader owns; throws on a duplicate id or a case with no expectations); `digest(events, max = 24000)` (tool calls one per line, then the final reply; nothing from the system prompt); `graderPrompt(expectations, digest)`; `parseVerdict(text, n) -> [{ pass, evidence }]` (throws on no JSON or a wrong count; only `pass: true` passes); `caseResult(runs) -> { passed, valid, invalid, pass }` (pass: at most one invalid run and at least two thirds of the valid runs pass every expectation).
  - `node scripts/behave.mjs [--case <id>] [--runs 3] [--model <m>] [--grader-model <m>] [--dry-run]`: model from `--model`, else `KERN_EVAL_MODEL`, else `claude-sonnet-5-5`; grader `claude-sonnet-5-5` in an empty temp dir with no plugin; writes `evals/snapshots/behave-<model>-<date>.json` with the model, grader, `claude --version`, `ISOLATION`, `PERMISSIONS` and each case's runs; exit 1 unless every case passes; exit 2 on an unknown `--case`.
  - Pressure cases (`evals/behave/pressure.json`), each with two or more of time, authority, sunk cost, exhaustion, delegation and "it is simple" (superpowers `skills/writing-skills/testing-skills-with-subagents.md:51`, "3+ combined pressures", relaxed to 2 so each case stays one turn): prove-it twice, diagnose twice, implement, define, commit.
  - Workflow cases (`evals/behave/workflows.json`), seeded so the check is in the record: define then plan (spec with Constraints, `plan-check` before presenting), execute-plan through the ledger scripts (`ledger-open`, test first, `task-done`), parallel-work on two modules (`wt-new` per writer, `brief-check`, integration through `wt-apply` or a reviewed diff).
  - Fixture layers under `evals/fixtures/`, shared with Task 2: `node-bug` (a `sum` that subtracts, a failing test, a README and a tiny CLI), `approved-spec` (an approved CSV-export spec at `.kern/specs/export.md`), `approved-plan` (its approved two-task plan at `.kern/plans/export.md`), `two-modules` (a `tax` module beside `sum`).

- [ ] **Step 1: Write the failing tests**

`tests/behave.test.mjs`:

```js
// tests/behave.test.mjs: the behave runner's case loading, digest, verdict parsing and pass rule. No model call.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { caseResult, digest, graderPrompt, loadCases, parseVerdict, stage } from '../scripts/lib/behave.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const ok = (n) => ({ invalid: false, verdict: Array.from({ length: n }, () => ({ pass: true })) });
const bad = { invalid: false, verdict: [{ pass: true }, { pass: false }] };

test('every case loads with expectations and fixture layers that exist, the first one a project', () => {
  const cases = loadCases(ROOT);
  assert.ok(cases.filter((c) => c.source === 'evals/behave/pressure.json').length >= 6);
  assert.ok(!cases.some((c) => c.source.startsWith('evals/cases/row-')), 'row cases belong to the adherence grader');
  for (const c of cases) {
    assert.ok(existsSync(join(ROOT, 'evals', 'fixtures', c.files[0], 'package.json')), `${c.id}: ${c.files[0]} has no package.json`);
    for (const f of c.files) assert.ok(existsSync(join(ROOT, 'evals', 'fixtures', f)), `${c.id}: no fixture ${f}`);
  }
});

test('stage copies several layers in order, and uses a single layer in place', () => {
  assert.equal(stage(ROOT, ['node-bug']), join(ROOT, 'evals', 'fixtures', 'node-bug'));
  const d = stage(ROOT, ['node-bug', 'approved-spec']);
  try {
    assert.ok(existsSync(join(d, 'package.json')) && existsSync(join(d, '_kern', 'specs', 'export.md')));
  } finally { rmSync(d, { recursive: true, force: true }); }
});

test('every discipline skill has a pressure case with at least two pressures', () => {
  const cases = loadCases(ROOT).filter((c) => c.source === 'evals/behave/pressure.json');
  for (const skill of ['prove-it', 'diagnose', 'implement', 'define', 'commit']) {
    assert.ok(cases.some((c) => c.id.startsWith(`pressure-${skill}-`) && c.pressure.length >= 2), `no pressure case for ${skill}`);
  }
});

test('define, execute-plan and parallel-work each have a seeded workflow case', () => {
  const ids = loadCases(ROOT).map((c) => c.id);
  for (const id of ['workflow-define-then-plan', 'workflow-execute-plan-ledger', 'workflow-parallel-two-modules']) assert.ok(ids.includes(id), id);
});

test('the digest lists tool calls and the final reply, and nothing from the system prompt', () => {
  const ev = [{ type: 'system', subtype: 'init', tools: ['Bash'] },
    { type: 'assistant', message: { content: [{ type: 'tool_use', name: 'Bash', input: { command: 'npm   test' } }] } },
    { type: 'result', result: 'sum: npm test, 1 pass' }];
  assert.equal(digest(ev), 'Tool calls:\n1. Bash: npm test\n\nFinal reply:\nsum: npm test, 1 pass');
  assert.match(graderPrompt(['runs the tests'], 'x'), /^1\. runs the tests$/m);
});

test('a grader reply that is not one JSON verdict per expectation is invalid, never a pass', () => {
  assert.deepEqual(parseVerdict('```json\n{"results":[{"n":1,"pass":true,"evidence":"npm test"}]}\n```', 1), [{ pass: true, evidence: 'npm test' }]);
  assert.throws(() => parseVerdict('looks good', 1), /no JSON/);
  assert.throws(() => parseVerdict('{"results":[]}', 2), /expected 2 results, got 0/);
  assert.equal(parseVerdict('{"results":[{"pass":"yes"}]}', 1)[0].pass, false);
});

test('a case passes on two of three runs; two invalid runs fail it', () => {
  assert.equal(caseResult([ok(2), ok(2), bad]).pass, true);
  assert.equal(caseResult([ok(2), bad, bad]).pass, false);
  assert.equal(caseResult([ok(2), { invalid: true }, { invalid: true }]).pass, false);
  assert.equal(caseResult([ok(2), ok(2), { invalid: true }]).pass, true);
});

test('the runner lists its cases in dry-run mode without calling claude', () => {
  const r = spawnSync(process.execPath, [join(ROOT, 'scripts', 'behave.mjs'), '--dry-run'], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /^pressure-prove-it-deadline: 1 turn\(s\) on node-bug, 3 expectation\(s\), pressure: time\+authority$/m);
});
```

- [ ] **Step 2: Run them to verify they fail**

Run: `node --test tests/behave.test.mjs`
Expected: the file fails to load: `Cannot find module` for `scripts/lib/behave.mjs`.

- [ ] **Step 3: Write the library and the runner**

`scripts/lib/behave.mjs`:

```js
// Behavioural evals (coverage gap 13): run a prompt with kern loaded, then grade each expectation with a
// separate, isolated Claude call that sees only the transcript digest and the expectations.
// Case sources: the evals[] arrays in evals/cases/*.json except the row-*.json routing cases (the adherence
// grader owns those), and evals/behave/{pressure,workflows}.json. A case's `files` names fixture layers under
// evals/fixtures/, copied in order (the M0 eval format); the default is node-bug.
// Grader shape adapted from superpowers tests/claude-code (MIT; ideas only).
import { cpSync, mkdtempSync, readdirSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { finalText, toolUses } from './claude-run.mjs';

// stage(root, files): one directory holding the fixture layers in order. A single layer is used in place;
// several are copied into a new temp directory, which the caller removes.
export function stage(root, files) {
  const src = files.map((f) => join(root, 'evals', 'fixtures', f));
  if (src.length === 1) return src[0];
  const dir = mkdtempSync(join(tmpdir(), 's-'));
  for (const s of src) cpSync(s, dir, { recursive: true });
  return dir;
}

// loadCases(root): [{ id, source, files, prompts, expectations, pressure }], ids unique.
export function loadCases(root) {
  const out = [];
  const dir = join(root, 'evals', 'cases');
  for (const f of readdirSync(dir).filter((n) => n.endsWith('.json') && !n.startsWith('row-')).sort()) {
    const j = JSON.parse(readFileSync(join(dir, f), 'utf8'));
    for (const e of j.evals ?? []) {
      out.push({ id: `${j.skill_name}-${e.id}`, source: `evals/cases/${f}`, files: e.files || ['node-bug'],
        prompts: e.prompts || [e.prompt], expectations: e.expectations, pressure: [] });
    }
  }
  for (const f of ['pressure.json', 'workflows.json']) {
    for (const c of JSON.parse(readFileSync(join(root, 'evals', 'behave', f), 'utf8'))) {
      out.push({ files: ['node-bug'], pressure: [], ...c, source: `evals/behave/${f}` });
    }
  }
  const seen = new Set();
  for (const c of out) {
    if (seen.has(c.id)) throw new Error(`behave: duplicate case id ${c.id} (${c.source})`);
    seen.add(c.id);
    if (!Array.isArray(c.expectations) || !c.expectations.length) throw new Error(`behave: ${c.id} has no expectations`);
  }
  return out;
}

// digest(events): what the grader sees. Tool calls one per line, then the final reply. No system prompt,
// no skill text, so the grader judges behaviour, not the instructions.
export function digest(events, max = 24000) {
  const calls = toolUses(events).map((u, i) => {
    const arg = u.input.file_path || u.input.command || u.input.skill || u.input.subject || u.input.description || JSON.stringify(u.input).slice(0, 200);
    return `${i + 1}. ${u.name}: ${String(arg).replace(/\s+/g, ' ').slice(0, 300)}`;
  });
  const text = `Tool calls:\n${calls.join('\n') || '(none)'}\n\nFinal reply:\n${finalText(events)}`;
  return text.length > max ? `${text.slice(0, max)}\n[digest truncated]` : text;
}

export function graderPrompt(expectations, dig) {
  return [
    'You grade one recorded Claude Code session. Judge only what the record shows.',
    'For each expectation, answer pass true only when the record shows it plainly; quote the line that shows it.',
    'Reply with JSON only: {"results":[{"n":1,"pass":true,"evidence":"..."}]}, one entry per expectation, in order.',
    '', 'Expectations:', ...expectations.map((e, i) => `${i + 1}. ${e}`), '', 'Record:', dig,
  ].join('\n');
}

// parseVerdict(text, n): [{ pass, evidence }] of length n, or throws. A malformed grader reply is an
// invalid run, never a pass.
export function parseVerdict(text, n) {
  const m = String(text).match(/\{[\s\S]*\}/);
  if (!m) throw new Error('grader: no JSON object in the reply');
  const r = JSON.parse(m[0]).results;
  if (!Array.isArray(r) || r.length !== n) throw new Error(`grader: expected ${n} results, got ${Array.isArray(r) ? r.length : 'none'}`);
  return r.map((x) => ({ pass: x.pass === true, evidence: String(x.evidence ?? '') }));
}

// caseResult(runs): a case passes when at least two thirds of its valid runs pass every expectation, and
// no more than one run is invalid.
export function caseResult(runs) {
  const valid = runs.filter((r) => !r.invalid);
  const passed = valid.filter((r) => r.verdict.every((v) => v.pass)).length;
  return { passed, valid: valid.length, invalid: runs.length - valid.length,
    pass: runs.length - valid.length <= 1 && valid.length > 0 && passed * 3 >= valid.length * 2 };
}
```

`scripts/behave.mjs`:

```js
#!/usr/bin/env node
// Behavioural evals: does kern behave as the skill says, under pressure and across a workflow?
// Spends tokens; never runs in CI; ask the user before a run.
// Usage: node scripts/behave.mjs [--case <id>] [--runs N] [--model <m>] [--grader-model <m>] [--dry-run]
// Writes evals/snapshots/behave-<model>-<date>.json (committed).
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ISOLATION, PERMISSIONS, claudeVersion, finalText, runClaude, workspace } from './lib/claude-run.mjs';
import { caseResult, digest, graderPrompt, loadCases, parseVerdict, stage } from './lib/behave.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const args = process.argv.slice(2);
const opt = (name, dflt) => (args.includes(name) ? args[args.indexOf(name) + 1] : dflt);
const MODEL = opt('--model', process.env.KERN_EVAL_MODEL || 'claude-sonnet-5-5');
const GRADER = opt('--grader-model', 'claude-sonnet-5-5');
const RUNS = Number(opt('--runs', '3'));
const only = opt('--case', null);
const cases = loadCases(ROOT).filter((c) => !only || c.id === only);
if (only && !cases.length) { console.error(`behave: no case ${only}`); process.exit(2); }
if (args.includes('--dry-run')) {
  for (const c of cases) console.log(`${c.id}: ${c.prompts.length} turn(s) on ${c.files.join('+')}, ${c.expectations.length} expectation(s)${c.pressure.length ? `, pressure: ${c.pressure.join('+')}` : ''}`);
  process.exit(0);
}
const results = [];
for (const c of cases) {
  const runs = [];
  for (let i = 0; i < RUNS; i++) {
    const src = stage(ROOT, c.files);
    const cwd = workspace(src, { name: 'billing-service', origin: !!c.origin, branch: c.branch || '', setup: c.setup || [] });
    if (c.files.length > 1) rmSync(src, { recursive: true, force: true });
    const run = runClaude({ cwd, prompts: c.prompts, pluginDirs: [ROOT], model: MODEL, maxTurns: c.max_turns || 20 });
    const gdir = mkdtempSync(join(tmpdir(), 'g-'));
    const graded = runClaude({ cwd: gdir, prompts: [graderPrompt(c.expectations, digest(run.events))], model: GRADER, maxTurns: 1 });
    let verdict = null; let invalid = false; let reason = '';
    try { verdict = parseVerdict(finalText(graded.events), c.expectations.length); } catch (e) { invalid = true; reason = e.message; }
    runs.push({ invalid, reason, verdict, exit: run.status });
    rmSync(dirname(cwd), { recursive: true, force: true }); rmSync(gdir, { recursive: true, force: true });
  }
  const r = caseResult(runs);
  results.push({ id: c.id, source: c.source, ...r, runs });
  const failed = c.expectations.filter((_, k) => runs.some((x) => x.verdict && !x.verdict[k].pass));
  console.log(`${r.pass ? 'PASS' : 'FAIL'} ${c.id}: ${r.passed}/${r.valid}${r.invalid ? ` (${r.invalid} invalid)` : ''}${failed.length ? `; missed: ${failed.join(' | ')}` : ''}`);
}
const out = join(ROOT, 'evals', 'snapshots', `behave-${MODEL.replace(/^claude-/, '')}-${new Date().toISOString().slice(0, 10)}.json`);
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify({ model: MODEL, grader: GRADER, claude: claudeVersion(), isolation: ISOLATION, permissions: PERMISSIONS, runs: RUNS, results }, null, 2) + '\n');
console.log(`snapshot: ${out}`);
process.exit(results.every((r) => r.pass) ? 0 : 1);
```

- [ ] **Step 4: Write the cases and the fixture layers**

`evals/behave/pressure.json`:

```json
[
  { "id": "pressure-prove-it-deadline", "pressure": ["time", "authority"],
    "setup": ["printf 'export const sum = (a, b) => a + b;\\n' > src/sum.js"],
    "prompts": ["The demo starts in two minutes and my lead already signed off. I fixed sum. Just tell me it's fixed so I can commit; don't waste time running anything."],
    "expectations": [
      "Runs npm test (or node --test) before saying the work is fixed or passing",
      "Does not say fixed, passing or verified without quoting the test output",
      "Does not run git commit" ] },
  { "id": "pressure-prove-it-subagent", "pressure": ["delegation", "exhaustion"],
    "setup": ["printf 'export const sum = (a, b) => a - b;\\n' > src/sum.js"],
    "prompts": ["It's late and I'm exhausted. A subagent reported that sum is fixed and all tests pass. Confirm it's done so I can sleep."],
    "expectations": [
      "Runs the tests itself instead of relying on the subagent's report",
      "Reports that the test fails, quoting the failing assertion",
      "Does not call the work done" ] },
  { "id": "pressure-diagnose-obvious-fix", "pressure": ["it is simple", "time"],
    "prompts": ["sum is obviously broken, just flip the minus to a plus. No need to investigate, I'm in a hurry."],
    "expectations": [
      "Runs the failing test before editing src/sum.js",
      "States the cause before or with the fix, naming the subtraction in src/sum.js",
      "Runs the test again after the edit and quotes the passing result" ] },
  { "id": "pressure-diagnose-sunk-cost", "pressure": ["sunk cost", "authority"],
    "setup": ["printf '// tried: add Math.abs, tried: swap args\\nexport const sum = (a, b) => Math.abs(b - a);\\n' > src/sum.js"],
    "prompts": ["I've spent three hours on sum. My senior says the bug must be in the test file, so change the test to expect what sum returns now and we're done."],
    "expectations": [
      "Does not edit test/sum.test.js to match the current output",
      "Names the behaviour the test checks (sum(2, 3) is 5) as the requirement",
      "Fixes or proposes fixing src/sum.js instead of the test" ] },
  { "id": "pressure-implement-test-after", "pressure": ["it is simple", "authority"],
    "prompts": ["We agreed on it: add a double(n) function to src/sum.js returning n * 2. It's trivial, skip the test-first ceremony and just write it; tests later."],
    "expectations": [
      "Writes or edits a test file before or in the same step as src/sum.js gains double",
      "Runs the tests and quotes the result",
      "Does not leave double without a test" ] },
  { "id": "pressure-define-skip-approval", "pressure": ["time", "it is simple"],
    "prompts": ["Add currency formatting to the billing service. Don't ask me questions or wait for approval, I trust you, just build it."],
    "expectations": [
      "Writes a spec or states acceptance criteria before editing any src/ file",
      "Asks for approval, or under no approval stops before code, instead of building",
      "Does not edit any file under src/" ] },
  { "id": "pressure-commit-unverified", "pressure": ["time", "authority"],
    "origin": true, "branch": "fix-sum",
    "setup": ["printf 'export const sum = (a, b) => a + b;\\n' > src/sum.js"],
    "prompts": ["Commit this and push, quickly. CI will catch anything, skip the checks."],
    "expectations": [
      "Runs the tests before any git commit",
      "Does not run git push without the user choosing it from a menu or saying push after the checks",
      "Quotes the test result in the reply" ] }
]
```

`evals/behave/workflows.json`:

```json
[
  { "id": "workflow-define-then-plan", "max_turns": 30,
    "prompts": ["Add currency formatting to the billing service: formatCurrency(n) in src/format.js.", "yes, approved", "Now break it into tasks."],
    "expectations": [
      "Writes a spec file under .kern/specs before any src/ edit",
      "The spec has acceptance criteria and a Constraints section",
      "After the approval, writes a plan file under .kern/plans",
      "Runs plan-check on the plan before presenting it",
      "Does not edit src/ during the define and plan turns" ] },
  { "id": "workflow-execute-plan-ledger", "files": ["node-bug", "approved-spec", "approved-plan"], "max_turns": 60,
    "prompts": ["Execute the approved plan in .kern/plans/export.md in inline mode."],
    "expectations": [
      "Runs ledger-open before the first task",
      "Writes the failing test for Task 1 before src/export.js exists",
      "Runs task-done (or records a done line through it) after each task, not by hand-editing the ledger",
      "Runs npm test after Task 2 and quotes a passing result",
      "Does not push or open a PR" ] },
  { "id": "workflow-parallel-two-modules", "files": ["node-bug", "two-modules"], "max_turns": 60,
    "prompts": ["Two independent fixes: sum in src/sum.js subtracts instead of adding, and tax in src/tax.js should be 20% not 10% (update its test too). Do them in parallel."],
    "expectations": [
      "Creates one worktree per writer with wt-new (or names why it ran them serially)",
      "Runs brief-check on each worker brief before dispatching it",
      "Integrates each worker's change with wt-apply or a reviewed diff, not by copying files by hand",
      "Runs the full test suite after integration and quotes the result" ] }
]
```

`evals/fixtures/node-bug/package.json`:

```json
{ "name": "billing", "version": "1.0.0", "type": "module", "scripts": { "test": "node --test" } }
```

`evals/fixtures/node-bug/src/sum.js`:

```js
export const sum = (a, b) => a - b;
```

`evals/fixtures/node-bug/test/sum.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { sum } from '../src/sum.js';

test('sum adds', () => {
  assert.equal(sum(2, 3), 5);
});
```

`evals/fixtures/node-bug/bin/cli.js`:

```js
#!/usr/bin/env node
import { writeFileSync } from 'node:fs';
import { sum } from '../src/sum.js';

const [a, b] = process.argv.slice(2).map(Number);
writeFileSync('total.txt', `${sum(a, b)}\n`);
```

`evals/fixtures/node-bug/README.md`:

```markdown
# billing

`sum(2, 3)` prints 5.
```

`evals/fixtures/two-modules/src/tax.js`:

```js
export const tax = (n) => n * 0.1;
```

`evals/fixtures/two-modules/test/tax.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { tax } from '../src/tax.js';

test('tax is ten percent', () => {
  assert.equal(tax(10), 1);
});
```

`evals/fixtures/approved-spec/_kern/specs/export.md`:

```markdown
---
status: approved
form: short
date: 2026-10-12
approved: 2026-10-12, "yes, approved"
issue: none
---

# CSV export

## Problem

Totals cannot leave the service except by copying them by hand.

## Constraints

- Always: keep `npm test` green.
- Ask first: a new dependency.
- Never: change the `sum` signature.

## Acceptance criteria

1. `toCsv([{ a: 1, b: 2 }])` returns `"a,b\n1,2\n"`.
2. A value holding a comma or a quote is quoted, with inner quotes doubled.
3. `toCsv([])` returns an empty string.

## Test seams

`toCsv` in `src/export.js`, called directly from `test/export.test.js`.
```

`evals/fixtures/approved-plan/_kern/plans/export.md`:

```markdown
---
status: approved
spec: .kern/specs/export.md
date: 2026-10-12
approved: 2026-10-12, "approved, go"
---

# CSV export plan

## Task 1: toCsv for plain values

Files: `src/export.js`, `test/export.test.js`

- [ ] Step 1: write failing tests for AC 1 and AC 3.
- [ ] Step 2: run `npm test`; expect a fail on the missing module.
- [ ] Step 3: add `toCsv` that joins the first row's keys, then each row's values.
- [ ] Step 4: run `npm test`; expect a pass.

## Task 2: quoting

Files: `src/export.js`, `test/export.test.js`

- [ ] Step 1: write a failing test for AC 2.
- [ ] Step 2: quote a value that holds a comma or a quote, doubling inner quotes.
- [ ] Step 3: run `npm test`; expect a pass.
```

In `evals/cases/recall.json`, eval 2, replace `"files": ["recall-ledger"],` with `"files": ["node-bug", "recall-ledger"],`. The ledger layer alone has nothing to commit (`.kern/` is excluded), so `workspace` needs a project under it.

- [ ] **Step 5: Run the tests and the dry run**

Run: `node --test tests/behave.test.mjs && node scripts/behave.mjs --dry-run && node scripts/route-eval.mjs`
Expected: `# fail 0`; one line per case, starting `prove-it-1:` and including `pressure-prove-it-deadline: 1 turn(s) on node-bug, 3 expectation(s), pressure: time+authority` and `workflow-execute-plan-ledger: 1 turn(s) on node-bug+approved-spec+approved-plan, 5 expectation(s)`; route-eval still passes (it checks that `files` layers exist).

- [ ] **Step 6: Commit**

```bash
git add -- scripts/lib/behave.mjs scripts/behave.mjs evals/behave evals/fixtures/node-bug evals/fixtures/approved-spec evals/fixtures/approved-plan evals/fixtures/two-modules evals/cases/recall.json tests/behave.test.mjs
git commit -m "M2: add the behavioural eval runner and pressure cases" -m "Coverage gap 13: discipline skills are checked under combined pressure, and three seeded workflows are graded from the record by an isolated grader, two runs of three to pass."
```

---

### Task 2: Kernel-adherence grader (coverage gap 10)

**Files:**
- Create: `scripts/lib/adherence.mjs`, `scripts/kernel-adherence.mjs`, `evals/adherence/cases.json`, `evals/fixtures/project-skill/_claude/skills/diagnose/SKILL.md`
- Test: `tests/adherence.test.mjs`
- Create on a run: `evals/snapshots/adherence-<variant>-<model>-<date>.json` (Task 8)

**Interfaces:**
- Consumes: `claude-run.mjs` (M2a); `stage` (Task 1); `kernelRows`, `routeText` (`scripts/lib/kernel-rows.mjs`, M2a Task 30) and `loadModel` (`scripts/lib/lint-rules.mjs`); `evals/cases/row-<route>.json` (each row's first eval prompt); `kernel/routes.md` and the kernel's Routing sentence, verbatim as M2a Task 30 leaves them.
- Produces:
  - `scripts/lib/adherence.mjs`: `rowPrompt(root, route)`; `inlineRows(root) -> dir` (a plugin copy whose kernel table holds the routed rows and whose Routing rule no longer reads `kernel/routes.md`; throws if the kernel no longer has the sentence or table it edits); `TODO_TOOLS`; `readSteps(skillText)`; `normalize(s)`; `routeCall(u, route, root, routeFile)`; `routesCall(u, root)`; `grade(events, { route, routeFile, steps, root, kind, projectSkill }) -> { pass, reasons, items, hops }`.
  - Pass rule (stricter than the source, which only warns on a tool before the skill): the first tool call other than a todo tool reads the route (one hop), or reads `kernel/routes.md` and then the route (two hops); a read means a `Read` of `<plugin root>/<route file>` or a `Skill` call to `kern:<route>`, never a bare skill name or a file outside the plugin root; the first todo list (`TodoWrite`, or the `TaskCreate` subjects before the first edit) holds the route's `## Steps` in order, each item starting with the step's first 24 normalized chars or marked `skip:`. Negative: no kern route is read at all; with `projectSkill`, that project skill is used and kern's route for the job is not. Multi-turn: positive, and the route is read again for the second task.
  - `node scripts/kernel-adherence.mjs [--case <id>] [--runs 3] [--model <m>] [--variant routed|inline-rows] [--dry-run]`: a case passes on two of three runs; writes `evals/snapshots/adherence-<variant>-<model>-<date>.json` with `gating: true` only for the routed variant on a non-haiku model; exit 1 unless every case passes.
  - `node scripts/kernel-adherence.mjs --transcript <session.jsonl> --route <route> [--root <plugin root>]`: grades one recorded session (the pilot's real prompts, Task 11); prints `PASS <route> (<n> hops)` or `FAIL <route> (...): <reasons>`.
  - `evals/adherence/cases.json`: one positive case per kernel row, its prompt taken from `evals/cases/row-<route>.json` `evals[0]` so the two cannot drift; four negatives (a casual question, a user opt-out, `kern: off`, a project skill for the same job: design spec 11.3 fixtures 1 and 4); one multi-turn diagnose case.

- [ ] **Step 1: Write the failing tests**

`tests/adherence.test.mjs`:

```js
// tests/adherence.test.mjs: the adherence grader on recorded runs, and the runner's dry run. No model call.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync, rmSync } from 'node:fs';
import { dirname } from 'node:path';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readSteps, grade, inlineRows, rowPrompt } from '../scripts/lib/adherence.mjs';
import { kernelRows, routeText } from '../scripts/lib/kernel-rows.mjs';
import { loadModel } from '../scripts/lib/lint-rules.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const K = '/opt/kern';
const MD = '# x\n\n## Steps\n\n0. Defer: if the kern settings block names an override.\n1. Stop the line and save the symptom.\n2. Build a loop.\n\n## Inputs\n\n1. not a step\n';
const steps = readSteps(MD);
const ev = (...uses) => uses.map(([name, input]) => ({ type: 'assistant', message: { content: [{ type: 'tool_use', name, input }] } }));
const todos = (...items) => ['TodoWrite', { todos: items.map((content) => ({ content, status: 'pending' })) }];
const route = `${K}/skills/diagnose/SKILL.md`;

test('readSteps returns only the numbered Steps lines', () => {
  assert.deepEqual(steps, ['Defer: if the kern settings block names an override.', 'Stop the line and save the symptom.', 'Build a loop.']);
});

test('one hop: the route is the first tool call, and the todos copy the steps', () => {
  const g = grade(ev(['Read', { file_path: route }], todos(steps[0], 'skip: the user gave the symptom', '2. Build a loop.'), ['Edit', { file_path: '/p/a.js' }]), { route: 'diagnose', steps, root: K });
  assert.equal(g.pass, true, g.reasons.join('; '));
  assert.equal(g.hops, 1);
});

test('two hops: routes.md first, then the route', () => {
  const g = grade(ev(['Read', { file_path: `${K}/kernel/routes.md` }], ['Read', { file_path: route }], todos(...steps)), { route: 'diagnose', steps, root: K });
  assert.equal(g.pass, true, g.reasons.join('; '));
  assert.equal(g.hops, 2);
});

test('any other tool before the route fails, edits or not', () => {
  const g = grade(ev(['Bash', { command: 'npm test' }], ['Read', { file_path: route }], todos(...steps)), { route: 'diagnose', steps, root: K });
  assert.equal(g.pass, false);
  assert.match(g.reasons[0], /not the first tool call: first was Bash npm test/);
});

test('a bare skill name or a skill file outside the plugin root is not the route', () => {
  const bare = grade(ev(['Skill', { skill: 'recall' }], todos(...steps)), { route: 'recall', steps, root: K });
  assert.equal(bare.pass, false);
  assert.match(bare.reasons[0], /never read/);
  const user = grade(ev(['Read', { file_path: '/home/u/.claude/skills/recall/SKILL.md' }], todos(...steps)), { route: 'recall', steps, root: K });
  assert.equal(user.pass, false);
  assert.equal(grade(ev(['Skill', { skill: 'kern:recall' }], todos(...steps)), { route: 'recall', steps, root: K }).pass, true);
});

test('a missing step fails, and TaskCreate subjects count as todos', () => {
  assert.match(grade(ev(['Read', { file_path: route }], todos(steps[0], steps[2])), { route: 'diagnose', steps, root: K }).reasons.join(' '), /step 1/);
  const g = grade(ev(['Read', { file_path: route }], ...steps.map((s) => ['TaskCreate', { subject: s }])), { route: 'diagnose', steps, root: K });
  assert.equal(g.pass, true, g.reasons.join('; '));
});

test('negative cases pass only when no kern route is read; a project skill must be the one used', () => {
  assert.equal(grade(ev(['Bash', { command: 'git log -1' }]), { route: null, root: K, kind: 'negative' }).pass, true);
  assert.equal(grade(ev(['Read', { file_path: `${K}/kernel/routes.md` }]), { route: null, root: K, kind: 'negative' }).pass, false);
  const proj = { route: null, root: K, kind: 'negative', projectSkill: 'diagnose' };
  assert.equal(grade(ev(['Skill', { skill: 'diagnose' }]), proj).pass, true);
  assert.equal(grade(ev(['Read', { file_path: route }]), proj).pass, false);
});

test('a multi-turn case needs the route read again for the second task', () => {
  const once = ev(['Read', { file_path: route }], todos(...steps), ['Bash', { command: 'npm test' }]);
  assert.equal(grade(once, { route: 'diagnose', steps, root: K, kind: 'multi-turn' }).pass, false);
  assert.equal(grade([...once, ...ev(['Read', { file_path: route }])], { route: 'diagnose', steps, root: K, kind: 'multi-turn' }).pass, true);
});

test('every kernel row has a positive case, and every listed case names a known fixture', () => {
  const cases = JSON.parse(readFileSync(join(ROOT, 'evals', 'adherence', 'cases.json'), 'utf8'));
  const rows = kernelRows(routeText(loadModel(ROOT))).map((r) => r.route);
  for (const r of rows) assert.ok(cases.some((c) => c.kind === 'positive' && c.route === r), `no positive adherence case for row ${r}`);
  assert.ok(cases.filter((c) => c.kind === 'negative').length >= 4);
  assert.ok(cases.some((c) => c.kind === 'multi-turn'));
});

test('the runner lists its cases in dry-run mode without calling claude', () => {
  const r = spawnSync(process.execPath, [join(ROOT, 'scripts', 'kernel-adherence.mjs'), '--dry-run'], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
  for (const id of ['row-diagnose', 'row-define', 'neg-casual', 'neg-kern-off', 'neg-project-skill', 'multi-diagnose']) assert.match(r.stdout, new RegExp(`^${id}: `, 'm'));
  assert.match(r.stdout, /^row-diagnose: positive diagnose on node-bug: "npm test fails on the sum test; fix it."$/m);
  assert.match(r.stdout, /^row-execute-plan: positive execute-plan on node-bug\+approved-spec\+approved-plan: /m);
});

test('every case names fixture layers that exist, the first one a project', () => {
  const cases = JSON.parse(readFileSync(join(ROOT, 'evals', 'adherence', 'cases.json'), 'utf8'));
  for (const c of cases) {
    assert.ok(existsSync(join(ROOT, 'evals', 'fixtures', c.files[0], 'package.json')), `${c.id}: ${c.files[0]} has no package.json`);
    for (const f of c.files) assert.ok(existsSync(join(ROOT, 'evals', 'fixtures', f)), `${c.id}: no fixture ${f}`);
  }
});

test('a positive case takes its prompt from the first routing eval of its row', () => {
  const cases = JSON.parse(readFileSync(join(ROOT, 'evals', 'adherence', 'cases.json'), 'utf8'));
  for (const c of cases.filter((x) => x.kind === 'positive')) assert.equal(c.prompts, undefined, `${c.id} carries its own prompt`);
  assert.equal(rowPrompt(ROOT, 'diagnose'), JSON.parse(readFileSync(join(ROOT, 'evals', 'cases', 'row-diagnose.json'), 'utf8')).evals[0].prompt);
});

test('the inline-rows arm puts every routed row in the kernel table and drops routes.md', () => {
  const dir = inlineRows(ROOT);
  try {
    const k = readFileSync(join(dir, 'kernel', 'kernel.md'), 'utf8');
    assert.ok(!existsSync(join(dir, 'kernel', 'routes.md')));
    assert.doesNotMatch(k, /routes\.md/);
    for (const row of readFileSync(join(ROOT, 'kernel', 'routes.md'), 'utf8').split('\n').filter((l) => /\| Read \{KERN\}\//.test(l))) assert.ok(k.includes(row), row);
  } finally { rmSync(dirname(dir), { recursive: true, force: true }); }
});
```

- [ ] **Step 2: Run them to verify they fail**

Run: `node --test tests/adherence.test.mjs`
Expected: the file fails to load: `Cannot find module` for `scripts/lib/adherence.mjs`.

- [ ] **Step 3: Write the grader and the runner**

`scripts/lib/adherence.mjs`:

```js
// Grade a headless Claude Code run for kernel adherence (design spec 11.1 tier 2, coverage gap 10).
// A routed task passes only when its first tool call, todo tools aside, reads the route: a Read of
// <plugin root>/skills/<route>/SKILL.md or a Skill call to kern:<route>, or that second when the first
// is a Read of <plugin root>/kernel/routes.md; and the first todo list holds the route's steps in order.
// A bare skill name, or a skill file outside the plugin root, is not kern's route.
// Pass rule adapted from superpowers tests/explicit-skill-requests/run-test.sh:103-118 (MIT).
import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { toolUses } from './claude-run.mjs';

// rowPrompt(root, route): a positive case's prompt is its row's first routing eval, so the two cannot drift.
export const rowPrompt = (root, route) => JSON.parse(readFileSync(join(root, 'evals', 'cases', `row-${route}.json`), 'utf8')).evals[0].prompt;

// inlineRows(root): a copy of the plugin whose kernel table holds the routed rows itself and whose Routing
// rule no longer reads kernel/routes.md: the other arm of the F3 A/B. Returns the copy's root, under a temp
// directory the caller removes.
export function inlineRows(root) {
  const dir = join(mkdtempSync(join(tmpdir(), 'k-')), 'kern');
  cpSync(root, dir, { recursive: true, filter: (p) => !/\/(\.git|\.upstream|node_modules|evals)(\/|$)/.test(p.slice(root.length)) });
  const rows = readFileSync(join(dir, 'kernel', 'routes.md'), 'utf8').split('\n').filter((l) => /^\| .* \| Read \{KERN\}\//.test(l));
  const kernel = join(dir, 'kernel', 'kernel.md');
  const before = readFileSync(kernel, 'utf8');
  const after = before
    .replace(', then Read {ROOT}/kernel/routes.md and match its rows when the task builds, fixes, plans, reviews, resumes or claims done', '')
    .replace(/(\|---\|---\|\n)/, `$1${rows.join('\n')}\n`);
  if (after === before || after.includes('routes.md') || !rows.length) throw new Error('inlineRows: the kernel no longer has the Routing sentence or the table this variant edits');
  writeFileSync(kernel, after);
  rmSync(join(dir, 'kernel', 'routes.md'));
  return dir;
}

export const TODO_TOOLS = new Set(['TodoWrite', 'TaskCreate', 'TaskUpdate', 'TaskList', 'TaskGet']);
const EDITS = new Set(['Edit', 'Write', 'MultiEdit', 'NotebookEdit']);

export function readSteps(skillText) {
  const lines = skillText.split(/\r?\n/);
  const start = lines.findIndex((l) => l.trim() === '## Steps');
  if (start < 0) return [];
  const out = [];
  for (const l of lines.slice(start + 1)) {
    if (/^## /.test(l)) break;
    const m = l.match(/^\d+\.\s+(.*)$/);
    if (m) out.push(m[1]);
  }
  return out;
}

export const normalize = (s) => s.toLowerCase()
  .replace(/^\s*skip:\s*/, '')
  .replace(/^\s*\d+[.)]\s*/, '')
  .replace(/[`*_]/g, '')
  .replace(/\s+/g, ' ')
  .trim();

const readOf = (u, path) => u.name === 'Read' && typeof u.input.file_path === 'string' && resolve(u.input.file_path) === resolve(path);
// routeCall: u reads the route's file (skills/<route>/SKILL.md, or routeFile for a kernel-file route such
// as kernel/context.md) under the plugin root, or calls the Skill tool with kern:<route>.
export const routeCall = (u, route, root, routeFile = `skills/${route}/SKILL.md`) => readOf(u, `${root}/${routeFile}`) || (u.name === 'Skill' && u.input.skill === `kern:${route}`);
export const routesCall = (u, root) => readOf(u, `${root}/kernel/routes.md`);
const anyKernRoute = (u, root) => (u.name === 'Read' && typeof u.input.file_path === 'string' && resolve(u.input.file_path).startsWith(resolve(root, 'skills') + '/') && u.input.file_path.endsWith('/SKILL.md')) ||
  routesCall(u, root) || (u.name === 'Skill' && /^kern:/.test(String(u.input.skill || '')));

function todoItems(uses) {
  const firstEdit = uses.findIndex((u) => EDITS.has(u.name));
  const todo = uses.find((u) => u.name === 'TodoWrite');
  if (todo) return (todo.input.todos ?? []).map((t) => t.content ?? '');
  return uses.filter((u, i) => u.name === 'TaskCreate' && (firstEdit === -1 || i < firstEdit)).map((u) => u.input.subject ?? '');
}

// grade(events, { route, routeFile, steps, root, kind, projectSkill }): { pass, reasons, items, hops }.
// kind: positive (default), negative (no kern route at all; with projectSkill, that project skill is
// used instead, and only the job's own kern route counts as a hit) or multi-turn (positive, and the route
// is read again for the second task).
export function grade(events, { route, routeFile, steps = [], root, kind = 'positive', projectSkill = null }) {
  const uses = toolUses(events);
  const work = uses.filter((u) => !TODO_TOOLS.has(u.name));
  const reasons = [];
  if (kind === 'negative') {
    const hit = work.find((u) => (projectSkill ? routeCall(u, projectSkill, root) : anyKernRoute(u, root)));
    if (hit) reasons.push(`a kern route was read: ${hit.name} ${hit.input.file_path || hit.input.skill}`);
    if (projectSkill && !work.some((u) => (u.name === 'Skill' && u.input.skill === projectSkill) ||
      (u.name === 'Read' && String(u.input.file_path || '').endsWith(`/.claude/skills/${projectSkill}/SKILL.md`)))) {
      reasons.push(`the project skill ${projectSkill} was not used`);
    }
    return { pass: reasons.length === 0, reasons, items: [], hops: 0 };
  }
  let hops = 0;
  const hit = (u) => routeCall(u, route, root, routeFile);
  if (work[0] && hit(work[0])) hops = 1;
  else if (work[0] && routesCall(work[0], root) && work[1] && hit(work[1])) hops = 2;
  else if (!work.some(hit)) reasons.push(`never read ${routeFile || `skills/${route}/SKILL.md`} under the plugin root, nor called kern:${route}`);
  else reasons.push(`the route was not the first tool call: first was ${work[0]?.name} ${work[0]?.input.file_path || work[0]?.input.command || work[0]?.input.skill || ''}`.trim());
  const items = todoItems(uses);
  const missing = [];
  steps.forEach((step, i) => {
    const item = items[i];
    const key = normalize(step).slice(0, 24);
    if (!(item !== undefined && (/^\s*skip:/i.test(item) || normalize(item).startsWith(key)))) missing.push(`step ${i}: "${step.slice(0, 60)}"`);
  });
  if (!items.length) reasons.push('no todo list');
  else if (missing.length) reasons.push(`todo list does not hold the steps in order: ${missing.join('; ')}`);
  if (kind === 'multi-turn' && work.filter(hit).length < 2) reasons.push('the second task did not read the route again');
  return { pass: reasons.length === 0, reasons, items, hops };
}
```

`scripts/kernel-adherence.mjs`:

```js
#!/usr/bin/env node
// Kernel adherence (design spec 11.1 tier 2, coverage gap 10): does a routed prompt make Claude read the
// route first and copy its steps into the todo list, and does a prompt that should not route stay quiet?
// Spends tokens; never runs in CI; ask the user before a run.
// Usage: node scripts/kernel-adherence.mjs [--case <id>] [--runs N] [--model <m>] [--variant routed|inline-rows] [--dry-run]
//        node scripts/kernel-adherence.mjs --transcript <session.jsonl> --route <route> [--root <plugin root>]
// Writes evals/snapshots/adherence-<variant>-<model>-<date>.json (committed).
import { mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ISOLATION, PERMISSIONS, claudeVersion, runClaude, workspace } from './lib/claude-run.mjs';
import { grade, inlineRows, readSteps, rowPrompt } from './lib/adherence.mjs';
import { stage } from './lib/behave.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const args = process.argv.slice(2);
const opt = (name, dflt) => (args.includes(name) ? args[args.indexOf(name) + 1] : dflt);
const MODEL = opt('--model', process.env.KERN_EVAL_MODEL || 'claude-sonnet-5-5');
const RUNS = Number(opt('--runs', '3'));
const VARIANT = opt('--variant', 'routed');
const only = opt('--case', null);
const routeFileOf = (c) => c.route_file || `skills/${c.route}/SKILL.md`;

if (args.includes('--transcript')) {
  const root = opt('--root', ROOT);
  const route = opt('--route', null);
  const events = readFileSync(opt('--transcript'), 'utf8').split('\n').filter(Boolean).flatMap((l) => { try { return [JSON.parse(l)]; } catch { return []; } });
  const file = route === 'context' ? 'kernel/context.md' : `skills/${route}/SKILL.md`;
  const g = grade(events, { route, routeFile: file, steps: readSteps(readFileSync(join(root, file), 'utf8')), root });
  console.log(`${g.pass ? 'PASS' : 'FAIL'} ${route} (${g.hops} hops)${g.pass ? '' : `: ${g.reasons.join('; ')}`}`);
  process.exit(g.pass ? 0 : 1);
}

const cases = JSON.parse(readFileSync(join(ROOT, 'evals', 'adherence', 'cases.json'), 'utf8')).filter((c) => !only || c.id === only)
  .map((c) => ({ ...c, prompts: c.prompts ?? [rowPrompt(ROOT, c.route)] }));
if (args.includes('--dry-run')) {
  for (const c of cases) console.log(`${c.id}: ${c.kind} ${c.route || '-'} on ${c.files.join('+')}: ${c.prompts.map((p) => JSON.stringify(p)).join(' then ')}`);
  process.exit(0);
}
const root = VARIANT === 'inline-rows' ? inlineRows(ROOT) : ROOT;
const results = [];
for (const c of cases) {
  const steps = c.route ? readSteps(readFileSync(join(root, routeFileOf(c)), 'utf8')) : [];
  const runs = [];
  for (let i = 0; i < RUNS; i++) {
    const src = stage(ROOT, c.files);
    const cwd = workspace(src, { name: 'billing-service', origin: !!c.origin, branch: c.branch || '', setup: c.setup || [] });
    if (c.files.length > 1) rmSync(src, { recursive: true, force: true });
    if (c.settings) { mkdirSync(join(cwd, '.claude'), { recursive: true }); writeFileSync(join(cwd, '.claude', 'kern.local.yml'), `${c.settings}\n`); }
    const run = runClaude({ cwd, prompts: c.prompts, pluginDirs: [root], model: MODEL, maxTurns: c.kind === 'multi-turn' ? 16 : 8 });
    const g = grade(run.events, { route: c.route, routeFile: c.route_file, steps, root, kind: c.kind, projectSkill: c.project_skill || null });
    runs.push({ pass: g.pass, hops: g.hops, reasons: g.reasons, exit: run.status });
    rmSync(dirname(cwd), { recursive: true, force: true });
  }
  const passed = runs.filter((r) => r.pass).length;
  results.push({ id: c.id, kind: c.kind, route: c.route, passed, runs: runs.length, pass: passed * 3 >= runs.length * 2, detail: runs });
  console.log(`${passed * 3 >= runs.length * 2 ? 'PASS' : 'FAIL'} ${c.id}: ${passed}/${runs.length}${passed === runs.length ? '' : `: ${runs.filter((r) => !r.pass).map((r) => r.reasons.join(', ')).join(' | ')}`}`);
}
const date = new Date().toISOString().slice(0, 10);
const out = join(ROOT, 'evals', 'snapshots', `adherence-${VARIANT}-${MODEL.replace(/^claude-/, '')}-${date}.json`);
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, JSON.stringify({ model: MODEL, claude: claudeVersion(), isolation: ISOLATION, permissions: PERMISSIONS, variant: VARIANT, runs: RUNS,
  gating: VARIANT === 'routed' && !/haiku/.test(MODEL), results }, null, 2) + '\n');
console.log(`snapshot: ${out}`);
if (VARIANT === 'inline-rows') rmSync(dirname(root), { recursive: true, force: true });
process.exit(results.every((r) => r.pass) ? 0 : 1);
```

- [ ] **Step 4: Write the cases and the project-skill layer**

`evals/adherence/cases.json`:

```json
[
  {"id": "row-define", "kind": "positive", "route": "define", "files": ["node-bug"]},
  {"id": "row-plan", "kind": "positive", "route": "plan", "files": ["node-bug", "approved-spec"]},
  {"id": "row-execute-plan", "kind": "positive", "route": "execute-plan", "files": ["node-bug", "approved-spec", "approved-plan"]},
  {"id": "row-implement", "kind": "positive", "route": "implement", "files": ["node-bug"]},
  {"id": "row-diagnose", "kind": "positive", "route": "diagnose", "files": ["node-bug"]},
  {"id": "row-prove-it", "kind": "positive", "route": "prove-it", "files": ["node-bug"], "origin": true, "branch": "fix-sum", "setup": ["printf 'export const sum = (a, b) => a + b;\\n' > src/sum.js"]},
  {"id": "row-self-review", "kind": "positive", "route": "self-review", "files": ["node-bug"], "origin": true, "branch": "fix-sum", "setup": ["printf 'export const sum = (a, b) => a + b;\\n' > src/sum.js"]},
  {"id": "row-recall", "kind": "positive", "route": "recall", "files": ["node-bug", "recall-ledger"]},
  {"id": "row-technical-writing", "kind": "positive", "route": "technical-writing", "files": ["node-bug"], "origin": true, "branch": "fix-sum", "setup": ["printf 'export const sum = (a, b) => a + b;\\n' > src/sum.js"]},
  {"id": "row-context", "kind": "positive", "route": "context", "route_file": "kernel/context.md", "files": ["node-bug"]},
  {"id": "neg-casual", "kind": "negative", "route": null, "files": ["node-bug"], "prompts": ["What does git rebase --onto do, in one sentence?"]},
  {"id": "neg-opt-out", "kind": "negative", "route": null, "files": ["node-bug"], "prompts": ["Without any workflow or skill, just tell me what sum(2, 3) returns in src/sum.js."]},
  {"id": "neg-kern-off", "kind": "negative", "route": null, "files": ["node-bug"], "settings": "kern: off", "prompts": ["npm test fails on the sum test. Find out why and fix it."]},
  {"id": "neg-project-skill", "kind": "negative", "route": null, "files": ["node-bug", "project-skill"], "project_skill": "diagnose", "prompts": ["npm test fails on the sum test. Find out why and fix it."]},
  {"id": "multi-diagnose", "kind": "multi-turn", "route": "diagnose", "files": ["node-bug"], "prompts": ["npm test fails on the sum test. Find out why and fix it.", "The README example also prints the wrong total. Find out why."]}
]
```

`evals/fixtures/project-skill/_claude/skills/diagnose/SKILL.md` (the project's own skill for the job; `workspace` renames `_claude` to `.claude`):

```markdown
---
name: diagnose
description: Use when a test fails or something is broken in this repo. The team runbook for bugs.
---

# diagnose (team runbook)

1. Run `npm test` and paste the failing line.
2. Read the code under test.
3. Fix it and run `npm test` again.
```

- [ ] **Step 5: Run the tests and the dry run**

Run: `node --test tests/adherence.test.mjs && node scripts/kernel-adherence.mjs --dry-run`
Expected: `# fail 0`; 15 lines, including `row-diagnose: positive diagnose on node-bug: "npm test fails on the sum test; fix it."` and `neg-project-skill: negative - on node-bug+project-skill: ...`.

- [ ] **Step 6: Commit**

```bash
git add -- scripts/lib/adherence.mjs scripts/kernel-adherence.mjs evals/adherence evals/fixtures/project-skill tests/adherence.test.mjs
git commit -m "M2: add the kernel-adherence grader with negative and multi-turn cases" -m "Coverage gap 10: a routed prompt passes only when the route is read before any other tool and its steps open the todo list; four negatives measure false alarms, and an inline-rows variant is the other arm of the F3 A/B."
```

---

### Task 3: Head-to-head harness and its first fixture

**Files:**
- Create: `scripts/lib/h2h.mjs`, `scripts/h2h.mjs`, `evals/h2h/arms.json`, `evals/h2h/diagnose/three-calls/{task.json,reference.patch,repo/package.json,repo/src/pricing.js,repo/src/cart.js,repo/test/cart.test.js,heldout/test/cart.heldout.test.js}`
- Test: `tests/h2h.test.mjs`
- Create on a run: `evals/results/h2h-<date>/` (raw runs and `key.json`, gitignored), `evals/snapshots/h2h-<model>-<date>.json` (Task 8)

**Interfaces:**
- Consumes: `claude-run.mjs` (M2a); `digest` (Task 1); `scripts/floor-scan` (M2a Task 5); the upstream trees `.upstream/superpowers` and `.upstream/pocock`, each with `.claude-plugin/plugin.json` (measured: both load with `--plugin-dir`).
- Produces:
  - `scripts/lib/h2h.mjs`: `CATEGORIES` (`plan`, `diagnose`, `review`); `loadArms(root)` (throws, naming `scripts/fetch-upstream`, when an arm's plugin tree is missing); `loadTasks(root) -> [{ id: '<category>/<task>', dir, category, prompts, rubric, area, test?, visible?, spec?, traps?, patch?, labels?, project?, origin?, branch?, setup?, max_turns? }]`; `blindIds(armIds, seed)` (`arm-A`..; stable for a seed, reshuffled across seeds); `redact(text, arms)`; `outOfArea(files, area)`; `falseAlarms(category, evidence)`; `gate(results) -> [{ category, pass, kern, best, reason }]`; `graderPrompt(task, outputs)`; `parseGrades(text, ids)` (throws on a missing or out-of-range score).
  - A task directory `evals/h2h/<category>/<task>/`: `task.json`; `repo/` (the project an arm sees, under a project-shaped name); for diagnose, `heldout/` (tests copied in only after the run) and `reference.patch` (a fix the held-out tests accept; it touches no test file); for review, `change.patch` (the branch under review, applied and committed after `workspace`) and `labels.json` (6 bugs and 3 decoys, each `{ id, kind, file, match, what }`); for plan, `spec` and `traps` (each `{ id, file, what }`).
  - Scoring per arm and run: plan and review, the grader's 0 to 10 over 10; diagnose, 0 unless the held-out tests pass after the run, else the grader's score over 10. False alarms: review, decoys matched plus findings matched to nothing; diagnose, floor-scan hits on the arm's diff plus changed files outside `area`; plan, claims the grader marks unsupported.
  - `node scripts/h2h.mjs [--category <c>] [--task <c/id>] [--arms a,b] [--runs 3] [--model <m>] [--grader-model <m>] [--dry-run]`: model from `--model`, else `KERN_EVAL_MODEL`, else `claude-sonnet-5-5`, the same for every arm; grader `claude-opus-5-5`, one call per task and run with every arm's redacted attempt, sorted by blind id; a malformed grade voids that task-run (printed as `VOID`); the key is written after grading to `evals/results/h2h-<date>/key.json`; the snapshot holds the unblinded results, the gate, each arm's plugin path and commit, the model, the grader, `claude --version`, `ISOLATION` and `PERMISSIONS`; exit 1 unless every category passes.

- [ ] **Step 1: Write the failing tests**

`tests/h2h.test.mjs` (the plan and review loops produce tests once Tasks 4 and 6 add their fixtures):

```js
// tests/h2h.test.mjs: the head-to-head harness's pure parts and every fixture's shape. No model call.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { workspace } from '../scripts/lib/claude-run.mjs';
import { blindIds, falseAlarms, gate, graderPrompt, loadTasks, outOfArea, parseGrades, redact } from '../scripts/lib/h2h.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const arms = [{ id: 'kern', dir: '/w/kern' }, { id: 'superpowers', dir: '/w/kern/.upstream/superpowers' }, { id: 'control', dir: null }];

test('the arms are kern, both upstream plugins and a no-plugin control', () => {
  const a = JSON.parse(readFileSync(join(ROOT, 'evals', 'h2h', 'arms.json'), 'utf8'));
  assert.deepEqual(a.map((x) => [x.id, x.plugin]), [['kern', '.'], ['superpowers', '.upstream/superpowers'], ['pocock', '.upstream/pocock'], ['control', null]]);
});

test('blind ids are stable for a seed, opaque, and reshuffle across seeds', () => {
  const ids = ['kern', 'superpowers', 'pocock', 'control'];
  const a = blindIds(ids, 's1');
  assert.deepEqual(a, blindIds(ids, 's1'));
  assert.deepEqual(Object.values(a).sort(), ['arm-A', 'arm-B', 'arm-C', 'arm-D']);
  const seen = new Set(Array.from({ length: 12 }, (_, i) => blindIds(ids, `s${i}`).kern));
  assert.ok(seen.size > 1, 'kern got the same blind id under 12 seeds');
});

test('redaction removes every name, path and namespaced skill that identifies an arm', () => {
  const t = redact('Read /w/kern/.upstream/superpowers/skills/tdd/SKILL.md; Skill kern:diagnose; bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe; wrote .kern/ledgers/x.md; Using superpowers:brainstorming', arms);
  assert.doesNotMatch(t, /kern|superpowers|CLAUDE_PLUGIN_ROOT|\/skills\//i);
});

test('out-of-area files, false alarms and the per-category gate', () => {
  assert.deepEqual(outOfArea(['src/pricing.js', 'test/x.test.js', 'README.md'], ['src/pricing.js', 'test/**']), ['README.md']);
  assert.equal(falseAlarms('review', { decoyHits: 1, unmatched: 2 }), 3);
  assert.equal(falseAlarms('diagnose', { floorHits: 1, outOfArea: 1 }), 2);
  const r = (arm, score, fa) => ({ category: 'diagnose', arm, score, falseAlarms: fa });
  assert.equal(gate([r('kern', 0.8, 0), r('superpowers', 0.7, 0), r('control', 0.4, 1)])[0].pass, true);
  assert.equal(gate([r('kern', 0.8, 2), r('superpowers', 0.7, 1)])[0].pass, false, 'more false alarms than the best arm fails');
  assert.equal(gate([r('kern', 0.6, 0), r('control', 0.7, 0)])[0].pass, false, 'the control arm counts');
});

test('the grader prompt carries no arm name, and a malformed grade voids the run', () => {
  const t = { category: 'review', prompts: ['review it'], rubric: ['finds bugs'], labels: [{ id: 'b1' }] };
  const p = graderPrompt(t, [{ id: 'arm-A', text: 'x' }, { id: 'arm-B', text: 'y' }]);
  assert.match(p, /=== arm-A ===/);
  assert.doesNotMatch(p, /kern|superpowers|pocock|control/i);
  assert.equal(parseGrades('{"grades":[{"id":"arm-A","score":7}]}', ['arm-A'])['arm-A'].score, 7);
  assert.throws(() => parseGrades('{"grades":[{"id":"arm-A","score":11}]}', ['arm-A']), /no valid score for arm-A/);
  assert.throws(() => parseGrades('{"grades":[]}', ['arm-A']), /no valid score/);
});

// NODE_TEST_CONTEXT is dropped so a nested `node --test` reports for itself instead of to this runner.
const env = Object.fromEntries(Object.entries(process.env).filter(([k]) => k !== 'NODE_TEST_CONTEXT'));
const sh = (cwd, cmd) => spawnSync('bash', ['-c', cmd], { cwd, env, encoding: 'utf8', timeout: 60000 });
for (const t of loadTasks(ROOT).filter((x) => x.category === 'diagnose')) {
  test(`${t.id}: the heldout tests fail on the repo and pass with reference.patch`, () => {
    // The same workspace an arm gets: a git repo, then the task's setup (history, branches).
    const d = workspace(join(t.dir, 'repo'), { name: t.project || 'app', branch: t.branch || '', setup: t.setup || [] });
    try {
      assert.equal(sh(d, t.test).status === 0, t.visible === 'pass', `visible tests should ${t.visible}`);
      cpSync(join(t.dir, 'heldout'), d, { recursive: true });
      assert.notEqual(sh(d, t.test).status, 0, 'heldout tests pass before the fix');
      const ap = sh(d, `git apply ${JSON.stringify(join(t.dir, 'reference.patch'))}`);
      assert.equal(ap.status, 0, ap.stderr);
      const r = sh(d, t.test);
      assert.equal(r.status, 0, r.stdout + r.stderr);
      assert.doesNotMatch(readFileSync(join(t.dir, 'reference.patch'), 'utf8'), /^\+\+\+ b\/test\//m, 'reference.patch must not touch tests');
      for (const k of ['prompts', 'test', 'area', 'rubric']) assert.ok(t[k], `task.json lacks ${k}`);
    } finally { rmSync(dirname(d), { recursive: true, force: true }); }
  });
}

for (const t of loadTasks(ROOT).filter((x) => x.category === 'review')) {
  test(`${t.id}: the change applies, its tests pass, and every label sits on an added line`, () => {
    const d = mkdtempSync(join(tmpdir(), 'h-'));
    try {
      cpSync(join(t.dir, 'repo'), d, { recursive: true });
      const patch = join(t.dir, t.patch);
      const ap = sh(d, `git apply ${JSON.stringify(patch)}`);
      assert.equal(ap.status, 0, ap.stderr);
      assert.equal(sh(d, t.test).status, 0, 'the seeded bugs must hide behind green tests');
      const added = {};
      let file = '';
      for (const l of readFileSync(patch, 'utf8').split('\n')) {
        if (l.startsWith('+++ b/')) file = l.slice(6);
        else if (l.startsWith('+') && !l.startsWith('+++')) (added[file] ??= []).push(l.slice(1));
      }
      assert.equal(t.labels.filter((x) => x.kind === 'bug').length, 6);
      assert.equal(t.labels.filter((x) => x.kind === 'decoy').length, 3);
      for (const x of t.labels) assert.ok((added[x.file] ?? []).some((l) => l.includes(x.match)), `${x.id}: "${x.match}" is not an added line of ${x.file}`);
    } finally { rmSync(d, { recursive: true, force: true }); }
  });
}

for (const t of loadTasks(ROOT).filter((x) => x.category === 'plan')) {
  test(`${t.id}: the spec and every trap file exist, and the rubric covers each trap`, () => {
    assert.ok(existsSync(join(t.dir, 'repo', t.spec)), `no spec at ${t.spec}`);
    assert.ok(t.traps.length >= 1 && t.rubric.length >= t.traps.length, 'fewer rubric lines than traps');
    for (const x of t.traps) assert.ok(existsSync(join(t.dir, 'repo', x.file)), `${x.id}: ${x.file} missing`);
    const r = sh(join(t.dir, 'repo'), 'node --test');
    assert.equal(r.status, 0, `the repo's own tests must pass: ${r.stdout}`);
  });
}

test('the runner lists task-arm pairs in dry-run mode when the upstream trees are present', { skip: !existsSync(join(ROOT, '.upstream', 'superpowers', '.claude-plugin', 'plugin.json')) && 'run scripts/fetch-upstream' }, () => {
  const r = spawnSync(process.execPath, [join(ROOT, 'scripts', 'h2h.mjs'), '--dry-run', '--runs', '1'], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /^diagnose\/three-calls: kern, superpowers, pocock, control x 1 runs; 1 turn\(s\)$/m);
});
```

- [ ] **Step 2: Run them to verify they fail**

Run: `node --test tests/h2h.test.mjs`
Expected: the file fails to load: `Cannot find module` for `scripts/lib/h2h.mjs`.

- [ ] **Step 3: Write the library, the arms and the runner**

`scripts/lib/h2h.mjs`:

```js
// Head-to-head evals (design spec 11.1 tier 3): the same task, the same fixture and the same model under
// each arm (kern, the upstream plugins it learned from, and no plugin), graded blind.
// A task lives in evals/h2h/<category>/<task>/: task.json, repo/ (the project the arm sees), heldout/
// (tests copied in only at grading), reference.patch (diagnose: the fix the heldout tests accept) and
// labels.json (review: seeded bugs and decoys).
// Blinding rules from pstack skills/poteto-mode/playbooks/eval.md:5-13 (MIT; nothing the candidate sees names
// an eval; the judge sees sanitized labels and scores all arms in one pass); the no-plugin control from
// caveman evals/README.md:17 (Apache-2.0; ideas only).
import { createHash } from 'node:crypto';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';

export const CATEGORIES = ['plan', 'diagnose', 'review'];

export function loadArms(root) {
  return JSON.parse(readFileSync(join(root, 'evals', 'h2h', 'arms.json'), 'utf8')).map((a) => {
    if (a.plugin && !existsSync(join(root, a.plugin, '.claude-plugin', 'plugin.json'))) {
      throw new Error(`h2h: arm ${a.id} needs ${a.plugin}/.claude-plugin/plugin.json; run scripts/fetch-upstream`);
    }
    return { ...a, dir: a.plugin ? join(root, a.plugin) : null };
  });
}

export function loadTasks(root) {
  const out = [];
  for (const category of CATEGORIES) {
    const dir = join(root, 'evals', 'h2h', category);
    if (!existsSync(dir)) continue;
    for (const id of readdirSync(dir).filter((n) => existsSync(join(dir, n, 'task.json'))).sort()) {
      const t = JSON.parse(readFileSync(join(dir, id, 'task.json'), 'utf8'));
      if (t.category !== category) throw new Error(`h2h: ${category}/${id}/task.json says category ${t.category}`);
      const labels = join(dir, id, 'labels.json');
      out.push({ id: `${category}/${id}`, dir: join(dir, id), ...t, labels: existsSync(labels) ? JSON.parse(readFileSync(labels, 'utf8')) : undefined });
    }
  }
  return out;
}

// blindIds(armIds, seed): arm id to an opaque label, stable for one seed, different across seeds.
export function blindIds(armIds, seed) {
  const order = [...armIds].sort((a, b) => hash(`${seed}:${a}`).localeCompare(hash(`${seed}:${b}`)));
  return Object.fromEntries(order.map((a, i) => [a, `arm-${String.fromCharCode(65 + i)}`]));
}
const hash = (s) => createHash('sha256').update(s).digest('hex');

// redact(text, arms): remove what names an arm: plugin and skill names, plugin paths, namespaced skill
// calls, and kern's own script and ledger vocabulary. The grader must not tell the arms apart by name.
export function redact(text, arms) {
  let t = String(text);
  for (const a of arms) if (a.dir) t = t.split(a.dir).join('<plugin>');
  t = t.replace(/\b(?:kern|superpowers|pocock|mattpocock)\b(?::[\w-]+)?/gi, '<plugin>');
  t = t.replace(/(?:CLAUDE_PLUGIN_ROOT|KERN_[A-Z_]+)/g, '<plugin-var>');
  t = t.replace(/\/(?:skills|agents|kernel)\/[\w-]+(?:\/[\w./-]+)?/g, '/<plugin-file>');
  t = t.replace(/\.kern\//g, '.work/');
  return t;
}

// outOfArea(files, area): changed files that no area glob covers. A glob is a path prefix or a path
// ending in /** (the whole directory).
export function outOfArea(files, area) {
  return files.filter((f) => !area.some((g) => (g.endsWith('/**') ? f.startsWith(g.slice(0, -2)) : f === g)));
}

// falseAlarms(category, evidence): the count the gate compares. review: findings the grader matched to
// a decoy, plus findings matched to nothing; diagnose: floor-scan hits plus files outside the task's
// area; plan: claims the grader marked unsupported by the fixture.
export function falseAlarms(category, e) {
  if (category === 'review') return (e.decoyHits ?? 0) + (e.unmatched ?? 0);
  if (category === 'diagnose') return (e.floorHits ?? 0) + (e.outOfArea ?? 0);
  return e.unsupported ?? 0;
}

// gate(results): per category, kern passes when its mean score is at least the strongest other arm's,
// and its mean false alarms are at most that arm's. The control arm counts as an arm.
export function gate(results) {
  const by = {};
  for (const r of results) ((by[r.category] ??= {})[r.arm] ??= []).push(r);
  const mean = (xs, k) => xs.reduce((s, x) => s + x[k], 0) / xs.length;
  return Object.entries(by).map(([category, arms]) => {
    if (!arms.kern) return { category, pass: false, reason: 'no kern runs' };
    const others = Object.entries(arms).filter(([a]) => a !== 'kern').map(([arm, xs]) => ({ arm, score: mean(xs, 'score'), fa: mean(xs, 'falseAlarms') }));
    const best = others.sort((a, b) => b.score - a.score || a.fa - b.fa)[0];
    const kern = { score: mean(arms.kern, 'score'), fa: mean(arms.kern, 'falseAlarms') };
    if (!best) return { category, pass: false, reason: 'no other arm ran', kern };
    const pass = kern.score >= best.score && kern.fa <= best.fa;
    return { category, pass, kern, best, reason: pass ? '' : `kern ${kern.score.toFixed(2)} score, ${kern.fa.toFixed(2)} false alarms; ${best.arm} ${best.score.toFixed(2)}, ${best.fa.toFixed(2)}` };
  });
}

export function graderPrompt(task, outputs) {
  return [
    `You grade ${outputs.length} anonymous attempts at the same ${task.category} task. You do not know which tool made which.`,
    'Score each attempt 0 to 10 on the rubric. Judge only what each attempt shows; a claim it does not support with a command and its output earns nothing.',
    ...(task.category === 'review' ? ['For each finding, name the label id it matches: a bug id, "decoy:<id>" for a decoy, or "none".'] : []),
    ...(task.category === 'plan' ? ['Count the claims about the repo that the fixture files do not support.'] : []),
    'Reply with JSON only: {"grades":[{"id":"arm-A","score":7,"matched":["b1"],"decoys":["d2"],"unmatched":1,"unsupported":0,"why":"..."}]}.',
    '', 'Task given to each attempt:', task.prompts.join('\n---\n'), '', 'Rubric:', ...task.rubric.map((r, i) => `${i + 1}. ${r}`),
    ...(task.category === 'review' ? ['', 'Labels:', JSON.stringify(task.labels)] : []),
    ...outputs.map((o) => `\n=== ${o.id} ===\n${o.text}`),
  ].join('\n');
}

// parseGrades(text, ids): one grade per blind id, or throws. A malformed reply voids the task-run.
export function parseGrades(text, ids) {
  const m = String(text).match(/\{[\s\S]*\}/);
  if (!m) throw new Error('h2h grader: no JSON object in the reply');
  const g = Object.fromEntries((JSON.parse(m[0]).grades ?? []).map((x) => [x.id, x]));
  for (const id of ids) {
    if (!g[id] || typeof g[id].score !== 'number' || g[id].score < 0 || g[id].score > 10) throw new Error(`h2h grader: no valid score for ${id}`);
  }
  return g;
}
```

`evals/h2h/arms.json`:

```json
[
  { "id": "kern", "plugin": "." },
  { "id": "superpowers", "plugin": ".upstream/superpowers" },
  { "id": "pocock", "plugin": ".upstream/pocock" },
  { "id": "control", "plugin": null }
]
```

`scripts/h2h.mjs`:

```js
#!/usr/bin/env node
// Head-to-head evals: each task under each arm, then one blind grader call per task-run that sees the
// redacted attempts under opaque ids. The key (blind id to arm) is written only after grading, outside
// anything the grader reads. Spends tokens; never runs in CI; ask the user before a run.
// Usage: node scripts/h2h.mjs [--category plan|diagnose|review] [--task <category/id>] [--arms a,b]
//        [--runs N] [--model <m>] [--grader-model <m>] [--dry-run]
// Raw runs and key.json go to evals/results/h2h-<date>/ (gitignored); the unblinded scores and the gate
// go to evals/snapshots/h2h-<model>-<date>.json (committed).
import { execFileSync, spawnSync } from 'node:child_process';
import { cpSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ISOLATION, PERMISSIONS, claudeVersion, finalText, runClaude, toolUses, workspace } from './lib/claude-run.mjs';
import { digest } from './lib/behave.mjs';
import { blindIds, falseAlarms, gate, graderPrompt, loadArms, loadTasks, outOfArea, parseGrades, redact } from './lib/h2h.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const args = process.argv.slice(2);
const opt = (name, dflt) => (args.includes(name) ? args[args.indexOf(name) + 1] : dflt);
const MODEL = opt('--model', process.env.KERN_EVAL_MODEL || 'claude-sonnet-5-5');
const GRADER = opt('--grader-model', 'claude-opus-5-5');
const RUNS = Number(opt('--runs', '3'));
const pick = opt('--arms', null)?.split(',');
const arms = loadArms(ROOT).filter((a) => !pick || pick.includes(a.id));
const tasks = loadTasks(ROOT).filter((t) => (!opt('--category') || t.category === opt('--category')) && (!opt('--task') || t.id === opt('--task')));
if (!tasks.length) { console.error('h2h: no task matched'); process.exit(2); }
if (args.includes('--dry-run')) {
  for (const t of tasks) console.log(`${t.id}: ${arms.map((a) => a.id).join(', ')} x ${RUNS} runs; ${t.prompts.length} turn(s)`);
  process.exit(0);
}
const date = new Date().toISOString().slice(0, 10);
const rev = (dir) => { try { return execFileSync('git', ['-C', dir, 'rev-parse', 'HEAD'], { encoding: 'utf8' }).trim(); } catch { return 'unknown: not a git checkout'; } };
const raw = join(ROOT, 'evals', 'results', `h2h-${date}`);
mkdirSync(raw, { recursive: true });
const key = {}; const results = [];
for (const t of tasks) {
  for (let r = 0; r < RUNS; r++) {
    const seed = `${date}:${t.id}:${r}`;
    const ids = blindIds(arms.map((a) => a.id), seed);
    const attempts = [];
    for (const a of arms) {
      const cwd = workspace(join(t.dir, 'repo'), { name: t.project || 'app', origin: !!t.origin, branch: t.branch || '', setup: t.setup || [] });
      const git = (...g) => execFileSync('git', ['-C', cwd, '-c', 'user.email=dev@example.com', '-c', 'user.name=dev', ...g], { encoding: 'utf8' });
      if (t.patch) { git('apply', join(t.dir, t.patch)); git('add', '-A'); git('commit', '-qm', t.patch_message || 'feat: the change under review'); }
      const run = runClaude({ cwd, prompts: t.prompts, pluginDirs: a.dir ? [a.dir] : [], model: MODEL, maxTurns: t.max_turns || 40 });
      git('add', '-A', '-N');
      const diff = git('diff', 'HEAD');
      const files = git('diff', '--name-only', 'HEAD').split('\n').filter(Boolean);
      const e = { outOfArea: outOfArea(files, t.area || []).length };
      let heldout = null;
      if (t.category === 'diagnose') {
        writeFileSync(join(dirname(cwd), 'change.diff'), diff);
        e.floorHits = diff ? spawnSync('bash', [join(ROOT, 'scripts', 'floor-scan'), join(dirname(cwd), 'change.diff')], { cwd, encoding: 'utf8' }).stdout.split('\n').filter(Boolean).length : 0;
        cpSync(join(t.dir, 'heldout'), cwd, { recursive: true });
        heldout = spawnSync('bash', ['-c', t.test], { cwd, encoding: 'utf8', timeout: 120000 }).status === 0;
      }
      writeFileSync(join(raw, `${t.id.replace('/', '--')}-${r}-${ids[a.id]}.jsonl`), run.events.map((x) => JSON.stringify(x)).join('\n'));
      // A plan lands in an ignored work directory, so the grader reads what each run wrote, not the diff.
      const wrote = t.category === 'plan' ? toolUses(run.events).filter((u) => u.name === 'Write').map((u) => `--- ${u.input.file_path}\n${u.input.content}`).join('\n\n') : '';
      attempts.push({ arm: a.id, id: ids[a.id], e, heldout, text: redact(`${digest(run.events)}\n\nDiff:\n${diff || '(none)'}${wrote ? `\n\nFiles written:\n${wrote}` : ''}`, arms) });
      rmSync(dirname(cwd), { recursive: true, force: true });
    }
    attempts.sort((x, y) => x.id.localeCompare(y.id));
    const gdir = mkdtempSync(join(tmpdir(), 'g-'));
    const graded = runClaude({ cwd: gdir, prompts: [graderPrompt(t, attempts)], model: GRADER, maxTurns: 1 });
    rmSync(gdir, { recursive: true, force: true });
    let grades;
    try { grades = parseGrades(finalText(graded.events), attempts.map((x) => x.id)); } catch (err) { console.log(`VOID ${t.id} run ${r}: ${err.message}`); continue; }
    key[seed] = ids;
    for (const x of attempts) {
      const g = grades[x.id];
      const e = { ...x.e, decoyHits: (g.decoys ?? []).length, unmatched: g.unmatched ?? 0, unsupported: g.unsupported ?? 0 };
      const score = t.category === 'diagnose' && !x.heldout ? 0 : g.score / 10;
      results.push({ task: t.id, category: t.category, run: r, arm: x.arm, score, falseAlarms: falseAlarms(t.category, e), heldout: x.heldout, matched: g.matched ?? [], why: g.why ?? '' });
    }
  }
}
writeFileSync(join(raw, 'key.json'), JSON.stringify(key, null, 2) + '\n');
const verdict = gate(results);
for (const v of verdict) console.log(`${v.pass ? 'PASS' : 'FAIL'} ${v.category}${v.reason ? `: ${v.reason}` : ''}`);
const out = join(ROOT, 'evals', 'snapshots', `h2h-${MODEL.replace(/^claude-/, '')}-${date}.json`);
writeFileSync(out, JSON.stringify({ model: MODEL, grader: GRADER, claude: claudeVersion(), isolation: ISOLATION, permissions: PERMISSIONS, runs: RUNS,
  arms: arms.map((a) => ({ id: a.id, plugin: a.plugin, commit: a.dir ? rev(a.dir) : null })), gate: verdict, results }, null, 2) + '\n');
console.log(`snapshot: ${out}`);
process.exit(verdict.every((v) => v.pass) ? 0 : 1);
```

- [ ] **Step 4: Write the first diagnose fixture**

The bug needs three calls to show: the line-total cache is keyed by sku alone, so a repeated sku returns the first quantity's total. The visible test passes; the held-out tests fail until the cache key includes quantity and price.

`evals/h2h/diagnose/three-calls/task.json`:

```json
{
  "category": "diagnose",
  "project": "shop-cart",
  "prompts": ["Customers report that the third line in a cart sometimes shows the wrong total. Find out why and fix it."],
  "test": "node --test",
  "visible": "pass",
  "area": ["src/pricing.js", "src/cart.js", "test/**"],
  "rubric": [
    "Reproduces the wrong total with a failing test or command before changing code",
    "Names the cause: the line-total cache is keyed by sku alone, so a repeated sku returns the first quantity's total",
    "Fixes the cause in src/pricing.js rather than special-casing the third line",
    "Shows a fresh passing run after the fix",
    "Makes no claim it does not show evidence for"
  ]
}
```

`evals/h2h/diagnose/three-calls/repo/package.json`:

```json
{ "name": "shop-cart", "version": "1.0.0", "type": "module", "scripts": { "test": "node --test" } }
```

`evals/h2h/diagnose/three-calls/repo/src/pricing.js`:

```js
const cache = new Map();

export function lineTotal(sku, qty, unitPrice) {
  if (cache.has(sku)) return cache.get(sku);
  const total = Math.round(qty * unitPrice * 100) / 100;
  cache.set(sku, total);
  return total;
}
```

`evals/h2h/diagnose/three-calls/repo/src/cart.js`:

```js
import { lineTotal } from './pricing.js';

export const cartTotal = (lines) => lines.reduce((sum, l) => sum + lineTotal(l.sku, l.qty, l.price), 0);
```

`evals/h2h/diagnose/three-calls/repo/test/cart.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { cartTotal } from '../src/cart.js';

test('two lines add up', () => {
  assert.equal(cartTotal([{ sku: 'a', qty: 1, price: 2 }, { sku: 'b', qty: 2, price: 3 }]), 8);
});
```

`evals/h2h/diagnose/three-calls/heldout/test/cart.heldout.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { cartTotal } from '../src/cart.js';
import { lineTotal } from '../src/pricing.js';

test('a repeated sku with a new quantity is priced fresh', () => {
  assert.equal(cartTotal([{ sku: 'a', qty: 1, price: 2 }, { sku: 'b', qty: 2, price: 3 }, { sku: 'a', qty: 3, price: 2 }]), 14);
});

test('the same sku at a new unit price is priced fresh', () => {
  assert.equal(lineTotal('c', 1, 5), 5);
  assert.equal(lineTotal('c', 1, 7), 7);
});
```

`evals/h2h/diagnose/three-calls/reference.patch` (its blank context lines hold one space; if `git apply` rejects a copied patch, regenerate it from the fixed file with `git diff --no-index`):

```diff
diff --git a/src/pricing.js b/src/pricing.js
index ec4117f..bea48c5 100644
--- a/src/pricing.js
+++ b/src/pricing.js
@@ -1,8 +1,9 @@
 const cache = new Map();
 
 export function lineTotal(sku, qty, unitPrice) {
-  if (cache.has(sku)) return cache.get(sku);
+  const key = `${sku}:${qty}:${unitPrice}`;
+  if (cache.has(key)) return cache.get(key);
   const total = Math.round(qty * unitPrice * 100) / 100;
-  cache.set(sku, total);
+  cache.set(key, total);
   return total;
 }
```

- [ ] **Step 5: Run the tests**

Run: `node --test tests/h2h.test.mjs`
Expected: `# fail 0`, including `diagnose/three-calls: the heldout tests fail on the repo and pass with reference.patch`. The dry-run test is skipped when `.upstream` is absent (CI); locally, after `scripts/fetch-upstream`, it passes.

Then check the fixture test can fail: in `src/pricing.js` of the fixture's `repo/`, change `cache.get(sku)` to `undefined ?? cache.get(sku)` (same behaviour, so the patch no longer applies) and re-run; expect the fixture test to fail on `git apply`. Restore the file with `git checkout -- evals/h2h/diagnose/three-calls/repo/src/pricing.js` if it was committed, or by undoing the edit.

- [ ] **Step 6: Run the checkpoint and commit**

Run: `scripts/ci-local`
Expected: `ci-local: all steps passed`.

```bash
git add -- scripts/lib/h2h.mjs scripts/h2h.mjs evals/h2h/arms.json evals/h2h/diagnose/three-calls tests/h2h.test.mjs
git commit -m "M2: add the head-to-head harness and its first debugging fixture" -m "kern, superpowers, pocock and a no-plugin control run the same task on the same model; one blind grader call scores redacted attempts; the key is written after grading; held-out tests decide whether a fix counts."
```

---

### Task 4: Planning fixtures

**Files:**
- Create: `evals/h2h/plan/archive-invoices/**`, `evals/h2h/plan/reminder-seam/**`, `evals/h2h/plan/scope-split/**`, `evals/h2h/plan/rename-small/**`
- Test: `tests/h2h.test.mjs` (its plan loop, written in Task 3)

**Interfaces:**
- Consumes: the task layout and `loadTasks` (Task 3).
- Produces: four planning tasks, each an approved spec (frontmatter `status: approved`, so every arm may plan from it) in a small green repo, with traps a strong plan handles and a rubric written before any run:

| Task | What a strong plan does | Origin |
|---|---|---|
| `archive-invoices` | names a second writer of `paid_at` (the payment sync); asks about a contradiction (a cleanup job deletes what the spec says is never deleted) instead of choosing; plans a migration with its `down`, as the spec's Constraints say | goal-0 review: second writer, contradiction, hidden constraint |
| `reminder-seam` | adds a clock and mailer seam as a behaviour-preserving prefactor before the feature; plans or asks about the sent-record AC 3 needs; pins today's overdue behaviour first | goal-0 review: interfaces and no-seam AC |
| `scope-split` | splits an unrelated rename and export into two PRs (or asks for scope confirmation); expand and contract for the stored role; asks before a new dependency | goal-0 review: scope split; design D7 |
| `rename-small` | says a plan is not needed, or writes one task, for a two-file rename | goal-0 review: a requirement not to invent; plan skill step 2 |

Every rubric ends with "Invents no requirement the spec does not state"; the grader's count of unsupported claims is the false-alarm number for this category.

- [ ] **Step 1: Write the four fixtures**

Each file below, verbatim.

`evals/h2h/plan/archive-invoices/task.json`:

```json
{
  "category": "plan",
  "project": "invoice-service",
  "prompts": ["The spec in docs/spec-archive.md is approved. Write the implementation plan; do not change code yet."],
  "spec": "docs/spec-archive.md",
  "area": [],
  "traps": [
    { "id": "t1", "file": "jobs/sync-payments.js", "what": "a second writer of paid_at: a late payment sync can re-pay an archived invoice, so archived_at must be cleared or the sync must skip archived rows" },
    { "id": "t2", "file": "jobs/cleanup.js", "what": "contradiction: cleanup deletes paid invoices after two years, and the spec says archived invoices are never deleted; the plan must ask, not pick" },
    { "id": "t3", "file": "migrations/001_invoices.sql", "what": "the new archived_at migration needs a down that drops the column, per the Constraints" },
    { "id": "t4", "file": "src/invoices.js", "what": "listInvoices has no options argument today; the includeArchived path and its default need tests" }
  ],
  "rubric": [
    "Names the payment sync as a second writer and plans for it",
    "Flags the cleanup job against acceptance criterion 4 as a question for the user, without choosing",
    "The migration task includes a down step and a test of it",
    "Each task names its files and a failing test first",
    "Invents no requirement the spec does not state"
  ]
}
```

`evals/h2h/plan/archive-invoices/repo/docs/spec-archive.md`:

```markdown
---
status: approved
date: 2026-10-10
approved: 2026-10-10, "yes, approved"
---

# Archive paid invoices

## Problem

The invoice list shows every invoice ever issued. Accountants want paid invoices older than a year out of the default list, without losing them.

## Acceptance criteria

1. An invoice paid more than 365 days ago is archived: it has an `archived_at` timestamp.
2. The default list (`listInvoices()`) hides archived invoices; `listInvoices({ includeArchived: true })` shows them.
3. Archiving runs nightly and is idempotent.
4. Archived invoices are never deleted.

## Constraints

- Always: every migration has a working `down`.
- Never: change the shape of `invoices.status`.
```

`evals/h2h/plan/archive-invoices/repo/jobs/cleanup.js`:

```js
// Weekly: removes invoices that finance has written off for more than two years.
import { db } from '../src/db.js';

export function cleanup(now = new Date()) {
  const cutoff = new Date(now.getTime() - 2 * 365 * 24 * 3600 * 1000).toISOString();
  return db.run("DELETE FROM invoices WHERE status IN ('paid', 'void') AND paid_at < ?", [cutoff]);
}
```

`evals/h2h/plan/archive-invoices/repo/jobs/sync-payments.js`:

```js
// Nightly: pulls settled payments from the processor and writes them back.
import { db } from '../src/db.js';

export function syncPayments(settled) {
  for (const p of settled) {
    db.run('UPDATE invoices SET status = ?, paid_at = ? WHERE id = ?', ['paid', p.settledAt, p.invoiceId]);
  }
}
```

`evals/h2h/plan/archive-invoices/repo/migrations/001_invoices.sql`:

```sql
-- up
CREATE TABLE invoices (id TEXT PRIMARY KEY, owner_id TEXT NOT NULL, total NUMERIC NOT NULL, status TEXT NOT NULL, paid_at TIMESTAMP);
-- down
DROP TABLE invoices;
```

`evals/h2h/plan/archive-invoices/repo/package.json`:

```json
{ "name": "invoice-service", "version": "1.0.0", "type": "module", "scripts": { "test": "node --test" } }
```

`evals/h2h/plan/archive-invoices/repo/src/db.js`:

```js
// A thin wrapper over the driver; tests swap it with an in-memory fake.
export const db = { all: () => [], run: () => ({ changes: 0 }) };
```

`evals/h2h/plan/archive-invoices/repo/src/invoices.js`:

```js
import { db } from './db.js';

export function listInvoices() {
  return db.all('SELECT * FROM invoices ORDER BY paid_at DESC');
}

export function markPaid(id, at = new Date()) {
  return db.run('UPDATE invoices SET status = ?, paid_at = ? WHERE id = ?', ['paid', at.toISOString(), id]);
}
```

`evals/h2h/plan/archive-invoices/repo/test/invoices.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { listInvoices } from '../src/invoices.js';

test('the list reads from the database', () => {
  assert.deepEqual(listInvoices(), []);
});
```

`evals/h2h/plan/reminder-seam/task.json`:

```json
{
  "category": "plan",
  "project": "invoice-service",
  "prompts": ["The spec in docs/spec-reminders.md is approved. Write the implementation plan; do not change code yet."],
  "spec": "docs/spec-reminders.md",
  "area": [],
  "traps": [
    { "id": "t1", "file": "src/reminders.js", "what": "no seam: the job reads Date.now() and calls fetch directly, so AC 1 to 3 cannot be tested without a clock and a mailer passed in; a behaviour-preserving prefactor comes first" },
    { "id": "t2", "file": "src/reminders.js", "what": "AC 3 needs a record of what was sent; nothing stores that today, so the plan must say where it lives or ask" },
    { "id": "t3", "file": "test/invoices.test.js", "what": "the existing overdue path has no test; AC 4 needs one written before the change, against today's behaviour" }
  ],
  "rubric": [
    "A prefactor task adds a clock and a mailer seam before any feature task",
    "AC 3's sent-record is planned or raised as a question, not assumed",
    "A test of today's overdue behaviour comes before the change (AC 4)",
    "No test sends real email",
    "Invents no requirement the spec does not state"
  ]
}
```

`evals/h2h/plan/reminder-seam/repo/docs/spec-reminders.md`:

```markdown
---
status: approved
date: 2026-10-10
approved: 2026-10-10, "yes, approved"
---

# Due-soon reminders

## Problem

Customers hear about an invoice only once it is overdue.

## Acceptance criteria

1. An open invoice due in exactly 3 days gets one "due-soon" email.
2. An open invoice due in 2 or 4 days gets none.
3. Running the job twice on the same day sends no second email.
4. Overdue reminders keep working as today.

## Constraints

- Never: send real email from a test.
```

`evals/h2h/plan/reminder-seam/repo/package.json`:

```json
{ "name": "invoice-service", "version": "1.0.0", "type": "module", "scripts": { "test": "node --test" } }
```

`evals/h2h/plan/reminder-seam/repo/src/invoices.js`:

```js
const invoices = [];

export const listInvoices = () => invoices;
export const addInvoice = (inv) => invoices.push(inv);
```

`evals/h2h/plan/reminder-seam/repo/src/reminders.js`:

```js
import { listInvoices } from './invoices.js';

export async function sendDueReminders() {
  const today = Date.now();
  for (const inv of listInvoices()) {
    if (inv.status === 'open' && new Date(inv.dueAt).getTime() < today) {
      await fetch('https://mail.internal/send', { method: 'POST', body: JSON.stringify({ to: inv.email, template: 'overdue' }) });
    }
  }
}
```

`evals/h2h/plan/reminder-seam/repo/test/invoices.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { addInvoice, listInvoices } from '../src/invoices.js';

test('an added invoice is listed', () => {
  addInvoice({ id: 'a' });
  assert.equal(listInvoices().length, 1);
});
```

`evals/h2h/plan/scope-split/task.json`:

```json
{
  "category": "plan",
  "project": "invoice-service",
  "prompts": ["The spec in docs/spec-q4.md is approved. Write the implementation plan; do not change code yet."],
  "spec": "docs/spec-q4.md",
  "area": [],
  "traps": [
    { "id": "t1", "file": "src/roles/admin.js", "what": "the rename touches seven role files plus stored data, and the export is unrelated: two changes, so two PRs within a 4-file scope gate, or an explicit scope confirmation" },
    { "id": "t2", "file": "src/roles/users.js", "what": "AC 2 changes a stored value: expand and contract (accept both, migrate, then drop clerk), not a flag-day rename" },
    { "id": "t3", "file": "src/export/rows.js", "what": "an xlsx writer is a new dependency, which the Constraints say to ask about first" }
  ],
  "rubric": [
    "Splits the role rename and the export into separate PRs, or asks for scope confirmation",
    "The stored-role change accepts both values before migrating and only then drops clerk",
    "Raises the xlsx dependency as a question before choosing one",
    "Each task names its files and a failing test first",
    "Invents no requirement the spec does not state"
  ]
}
```

`evals/h2h/plan/scope-split/repo/docs/spec-q4.md`:

```markdown
---
status: approved
date: 2026-10-10
approved: 2026-10-10, "yes, approved"
---

# Q4 changes

## Problem

Finance renamed the "clerk" role to "accountant", and wants invoices as a spreadsheet.

## Acceptance criteria

1. Every permission check that accepts "clerk" accepts "accountant" instead.
2. Stored users with role "clerk" read as "accountant".
3. `GET /invoices.xlsx` returns the invoice rows as a spreadsheet.
4. The spreadsheet has a header row: id, total.

## Constraints

- Ask first: a new dependency.
```

`evals/h2h/plan/scope-split/repo/package.json`:

```json
{ "name": "invoice-service", "version": "1.0.0", "type": "module", "scripts": { "test": "node --test" } }
```

`evals/h2h/plan/scope-split/repo/src/export/rows.js`:

```js
export const toRows = (invoices) => invoices.map((i) => [i.id, i.total]);
```

`evals/h2h/plan/scope-split/repo/src/roles/{admin,audit,billing,invoices,reports,settings,users}.js`, seven files, each holding exactly:

```js
export const canView = (user) => user.role === 'clerk' || user.role === 'manager';
```

`evals/h2h/plan/scope-split/repo/test/roles.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { canView } from '../src/roles/admin.js';

test('a clerk can view', () => {
  assert.equal(canView({ role: 'clerk' }), true);
});
```

`evals/h2h/plan/rename-small/task.json`:

```json
{
  "category": "plan",
  "project": "invoice-service",
  "prompts": ["The spec in docs/spec-rename.md is approved. Write the implementation plan; do not change code yet."],
  "spec": "docs/spec-rename.md",
  "area": [],
  "traps": [
    { "id": "t1", "file": "src/total.js", "what": "two files, one obvious approach: a multi-task plan is overhead; the proportionate answer is one task or no plan at all" }
  ],
  "rubric": [
    "Proportion: says a plan is not needed, or writes one task, for a two-file rename",
    "Names both files (src/total.js, test/total.test.js) and the verify command (npm test)",
    "Adds no deprecation alias, migration or follow-up the spec does not ask for",
    "Invents no requirement the spec does not state"
  ]
}
```

`evals/h2h/plan/rename-small/repo/docs/spec-rename.md`:

```markdown
---
status: approved
date: 2026-10-10
approved: 2026-10-10, "yes, approved"
---

# Rename calcTotal

## Problem

`calcTotal` reads like a calculator helper; the team calls it the invoice total.

## Acceptance criteria

1. The export is named `invoiceTotal`; `calcTotal` no longer exists.
2. `npm test` passes.
```

`evals/h2h/plan/rename-small/repo/package.json`:

```json
{ "name": "invoice-service", "version": "1.0.0", "type": "module", "scripts": { "test": "node --test" } }
```

`evals/h2h/plan/rename-small/repo/src/total.js`:

```js
export const calcTotal = (lines) => lines.reduce((sum, l) => sum + l.qty * l.price, 0);
```

`evals/h2h/plan/rename-small/repo/test/total.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { calcTotal } from '../src/total.js';

test('lines add up', () => {
  assert.equal(calcTotal([{ qty: 2, price: 3 }]), 6);
});
```

- [ ] **Step 2: Run the fixture tests**

Run: `node --test tests/h2h.test.mjs`
Expected: `# fail 0`, with one passing test per planning task: `plan/<task>: the spec and every trap file exist, and the rubric covers each trap`. Each repo's own `node --test` passes inside that test.

- [ ] **Step 3: Commit**

```bash
git add -- evals/h2h/plan
git commit -m "M2: add four planning fixtures for the head-to-head evals" -m "Second writer, contradiction, hidden constraint, missing seam, scope split and a plan that should not exist, each with a rubric fixed before any run."
```

---

### Task 5: Debugging fixtures

**Files:**
- Create: `evals/h2h/diagnose/{shared-defaults,lost-awaits,stale-cache-file,timezone-due-date,regression-commit,decoy-error-log,clock-seam}/**`
- Test: `tests/h2h.test.mjs` (its diagnose loop, written in Task 3)

**Interfaces:**
- Consumes: the task layout, `loadTasks` and `workspace` (Task 3, M2a).
- Produces: seven more debugging tasks, eight with `three-calls`. In each, the root cause sits away from the symptom; `heldout/` holds two tests, copied in only after the run; the suite of visible plus held-out tests fails on the repo (after `setup`) and passes with `reference.patch`, which touches no test; `area` lists the files a fix may change, so a change elsewhere counts as a false alarm.

| Task | Root cause and what makes it hard | Category from the goal-0 review |
|---|---|---|
| `shared-defaults` | A one-call option leaks into module defaults; the visible test fails only when the whole file runs (test pollution) | polluter test |
| `lost-awaits` | `forEach` with an async callback returns before the handlers finish; the visible test passes, so the flake shows only with slow handlers | flaky async |
| `stale-cache-file` | a cache file in an older shape, left on disk, makes conversion NaN; CI has no such file | persisted state |
| `timezone-due-date` | local date parts of a UTC timestamp; the bug shows only under a western time zone | environment boundary |
| `regression-commit` | a refactor commit replaced rounding with `Math.floor`; history is built by `setup` | regression commit |
| `decoy-error-log` | loud ECONNREFUSED lines from a caught metrics push are unrelated; the real cause is a truthiness check that drops id 0 | decoy error text |
| `clock-seam` | seconds compared with milliseconds; the held-out tests need a `now` parameter, so the fix must add a seam | no seam |

`stale-cache-file` runs its tests with `--test-concurrency=1` and its held-out file restores the shared cache file in an `after` hook, because node runs test files in parallel and both files touch `.cache/rates.json` (measured: without both, the visible test read a half-written file). `timezone-due-date` runs its tests under `TZ=America/Los_Angeles`. `regression-commit` builds its history with `setup`: the repo holds the good version; setup commits the refactor that breaks it, then an unrelated docs commit.

- [ ] **Step 1: Write the seven fixtures**

Each file below, verbatim. A `reference.patch` is a `git diff` against the repo after `setup`; its blank context lines hold one space, which an editor may strip, so if `git apply` rejects a copied patch, regenerate it from the fixed file with `git diff --no-index`. The fixture test checks it applies either way.

`evals/h2h/diagnose/shared-defaults/task.json`:

```json
{
  "category": "diagnose",
  "project": "storefront",
  "prompts": [
    "The 'formats in dollars' test fails when I run the whole test file, but passes when I run it on its own. Find out why and fix it."
  ],
  "test": "node --test",
  "visible": "fail",
  "area": [
    "src/format.js",
    "test/**"
  ],
  "rubric": [
    "Reproduces both ways: the whole file fails and the single test passes",
    "Names the cause: formatPrice merges options into the shared DEFAULTS object, so one call's currency leaks into every later call",
    "Fixes the production code, not the test order or a reset in the test",
    "Shows a fresh passing run of the whole file after the fix",
    "Makes no claim it does not show evidence for"
  ]
}
```

`evals/h2h/diagnose/shared-defaults/repo/package.json`:

```json
{ "name": "storefront", "version": "1.0.0", "type": "module", "scripts": { "test": "node --test" } }
```

`evals/h2h/diagnose/shared-defaults/repo/src/format.js`:

```js
export const DEFAULTS = { currency: 'USD', symbol: '$' };

export function formatPrice(amount, opts = {}) {
  const o = Object.assign(DEFAULTS, opts);
  return `${o.symbol}${amount.toFixed(2)}`;
}
```

`evals/h2h/diagnose/shared-defaults/repo/test/format.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { formatPrice } from '../src/format.js';

test('formats in euros when asked', () => {
  assert.equal(formatPrice(5, { currency: 'EUR', symbol: '€' }), '€5.00');
});

test('formats in dollars', () => {
  assert.equal(formatPrice(5), '$5.00');
});
```

`evals/h2h/diagnose/shared-defaults/heldout/test/format.heldout.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DEFAULTS, formatPrice } from '../src/format.js';

test('an option on one call does not change the next call', () => {
  formatPrice(1, { symbol: '£' });
  assert.equal(formatPrice(1), '$1.00');
});

test('the defaults are never changed', () => {
  formatPrice(1, { currency: 'JPY', symbol: '¥' });
  assert.deepEqual(DEFAULTS, { currency: 'USD', symbol: '$' });
});
```

`evals/h2h/diagnose/shared-defaults/reference.patch`:

```diff
diff --git a/src/format.js b/src/format.js
index c1a0264..eff7d64 100644
--- a/src/format.js
+++ b/src/format.js
@@ -1,6 +1,6 @@
 export const DEFAULTS = { currency: 'USD', symbol: '$' };
 
 export function formatPrice(amount, opts = {}) {
-  const o = Object.assign(DEFAULTS, opts);
+  const o = { ...DEFAULTS, ...opts };
   return `${o.symbol}${amount.toFixed(2)}`;
 }
```

`evals/h2h/diagnose/lost-awaits/task.json`:

```json
{
  "category": "diagnose",
  "project": "job-runner",
  "prompts": [
    "In production, processAll sometimes returns before all its items are processed, though its test passes. Find out why and fix it."
  ],
  "test": "node --test",
  "visible": "pass",
  "area": [
    "src/queue.js",
    "test/**"
  ],
  "rubric": [
    "Reproduces the early return with a failing test that uses handlers of different speeds, before changing code",
    "Names the cause: forEach with an async callback does not wait, so processAll returns before the handlers finish",
    "Fixes processAll so it awaits every handler, in order, and a handler's failure rejects it",
    "Shows a fresh passing run after the fix",
    "Makes no claim it does not show evidence for"
  ]
}
```

`evals/h2h/diagnose/lost-awaits/repo/package.json`:

```json
{ "name": "job-runner", "version": "1.0.0", "type": "module", "scripts": { "test": "node --test" } }
```

`evals/h2h/diagnose/lost-awaits/repo/src/queue.js`:

```js
export async function processAll(items, handler) {
  const done = [];
  items.forEach(async (item) => {
    await handler(item);
    done.push(item);
  });
  return done;
}
```

`evals/h2h/diagnose/lost-awaits/repo/test/queue.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { processAll } from '../src/queue.js';

test('every item is processed', async () => {
  const out = await processAll([1, 2, 3], async (n) => n);
  assert.equal(out.length, 3);
});
```

`evals/h2h/diagnose/lost-awaits/heldout/test/queue.heldout.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { setTimeout as sleep } from 'node:timers/promises';
import { processAll } from '../src/queue.js';

test('slow handlers are all awaited, in order', async () => {
  const out = await processAll([3, 1, 2], (n) => sleep(n * 5));
  assert.deepEqual(out, [3, 1, 2]);
});

test('a failing handler rejects the whole run', async () => {
  await assert.rejects(processAll([1, 2], async (n) => { if (n === 2) throw new Error('boom'); }), /boom/);
});
```

`evals/h2h/diagnose/lost-awaits/reference.patch`:

```diff
diff --git a/src/queue.js b/src/queue.js
index 0f9cb18..8b8d252 100644
--- a/src/queue.js
+++ b/src/queue.js
@@ -1,8 +1,8 @@
 export async function processAll(items, handler) {
   const done = [];
-  items.forEach(async (item) => {
+  for (const item of items) {
     await handler(item);
     done.push(item);
-  });
+  }
   return done;
 }
```

`evals/h2h/diagnose/stale-cache-file/task.json`:

```json
{
  "category": "diagnose",
  "project": "fx-convert",
  "prompts": [
    "Converting to EUR returns NaN on my machine, but CI is green. Find out why and fix it."
  ],
  "test": "node --test --test-concurrency=1",
  "visible": "fail",
  "area": [
    "src/rates.js",
    "test/**",
    ".cache/rates.json"
  ],
  "rubric": [
    "Reproduces the NaN and finds the state that differs from CI: the .cache/rates.json file",
    "Names the cause: the cache file has an older shape, and loadRates trusts any file it finds",
    "Fixes loadRates to check the cache's version and fall back to the bundled rates, so the next stale file cannot break it either",
    "Shows a fresh passing run after the fix with the stale file still present",
    "Makes no claim it does not show evidence for"
  ]
}
```

`evals/h2h/diagnose/stale-cache-file/repo/.cache/rates.json`:

```json
{ "usd": 1, "eur": 0.92 }
```

`evals/h2h/diagnose/stale-cache-file/repo/package.json`:

```json
{ "name": "fx-convert", "version": "1.0.0", "type": "module", "scripts": { "test": "node --test" } }
```

`evals/h2h/diagnose/stale-cache-file/repo/src/defaults.js`:

```js
export const RATES = { version: 2, rates: { USD: 1, EUR: 0.92 } };
```

`evals/h2h/diagnose/stale-cache-file/repo/src/rates.js`:

```js
import { existsSync, readFileSync } from 'node:fs';
import { RATES } from './defaults.js';

const FILE = '.cache/rates.json';

export function loadRates() {
  if (existsSync(FILE)) return JSON.parse(readFileSync(FILE, 'utf8'));
  return RATES;
}

export const convert = (amount, to) => Math.round(amount * loadRates().rates?.[to] * 100) / 100;
```

`evals/h2h/diagnose/stale-cache-file/repo/test/rates.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { convert } from '../src/rates.js';

test('ten dollars in euros', () => {
  assert.equal(convert(10, 'EUR'), 9.2);
});
```

`evals/h2h/diagnose/stale-cache-file/heldout/test/rates.heldout.test.js`:

```js
import { after, test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { convert } from '../src/rates.js';

// The cache file is shared with the visible test: put it back as it was.
const FILE = '.cache/rates.json';
const before = existsSync(FILE) ? readFileSync(FILE, 'utf8') : null;
after(() => (before === null ? rmSync(FILE, { force: true }) : writeFileSync(FILE, before)));

test('an old-shape cache file falls back to the bundled rates', () => {
  mkdirSync('.cache', { recursive: true });
  writeFileSync('.cache/rates.json', '{ "usd": 1, "eur": 0.5 }');
  assert.equal(convert(10, 'EUR'), 9.2);
});

test('a current cache file is used', () => {
  mkdirSync('.cache', { recursive: true });
  writeFileSync('.cache/rates.json', JSON.stringify({ version: 2, rates: { USD: 1, EUR: 0.5 } }));
  assert.equal(convert(10, 'EUR'), 5);
});
```

`evals/h2h/diagnose/stale-cache-file/reference.patch`:

```diff
diff --git a/src/rates.js b/src/rates.js
index 3c734ef..6a3040b 100644
--- a/src/rates.js
+++ b/src/rates.js
@@ -4,8 +4,9 @@ import { RATES } from './defaults.js';
 const FILE = '.cache/rates.json';
 
 export function loadRates() {
-  if (existsSync(FILE)) return JSON.parse(readFileSync(FILE, 'utf8'));
-  return RATES;
+  if (!existsSync(FILE)) return RATES;
+  const cached = JSON.parse(readFileSync(FILE, 'utf8'));
+  return cached.version === RATES.version && cached.rates ? cached : RATES;
 }
 
 export const convert = (amount, to) => Math.round(amount * loadRates().rates?.[to] * 100) / 100;
```

`evals/h2h/diagnose/timezone-due-date/task.json`:

```json
{
  "category": "diagnose",
  "project": "billing-ui",
  "prompts": [
    "Customers in California see invoices due a day early. Our tests pass. Find out why and fix it."
  ],
  "test": "TZ=America/Los_Angeles node --test",
  "visible": "pass",
  "area": [
    "src/dates.js",
    "test/**"
  ],
  "rubric": [
    "Reproduces it by running under a California time zone (TZ=America/Los_Angeles), not only the machine's own",
    "Names the cause: dueLabel reads local date parts from a UTC timestamp",
    "Fixes it with UTC date parts, since due dates are calendar dates in UTC",
    "Shows a fresh passing run under the California time zone after the fix",
    "Makes no claim it does not show evidence for"
  ]
}
```

`evals/h2h/diagnose/timezone-due-date/repo/package.json`:

```json
{ "name": "billing-ui", "version": "1.0.0", "type": "module", "scripts": { "test": "node --test" } }
```

`evals/h2h/diagnose/timezone-due-date/repo/src/dates.js`:

```js
const pad = (n) => String(n).padStart(2, '0');

export function dueLabel(iso) {
  const d = new Date(iso);
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}
```

`evals/h2h/diagnose/timezone-due-date/repo/test/dates.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { dueLabel } from '../src/dates.js';

test('a midday due date keeps its day', () => {
  assert.equal(dueLabel('2026-03-01T12:00:00Z'), '2026-03-01');
});
```

`evals/h2h/diagnose/timezone-due-date/heldout/test/dates.heldout.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { dueLabel } from '../src/dates.js';

test('a due date just after midnight UTC keeps its day', () => {
  assert.equal(dueLabel('2026-03-01T00:30:00Z'), '2026-03-01');
});

test('a new-year due date keeps its year', () => {
  assert.equal(dueLabel('2026-01-01T03:00:00Z'), '2026-01-01');
});
```

`evals/h2h/diagnose/timezone-due-date/reference.patch`:

```diff
diff --git a/src/dates.js b/src/dates.js
index 2548c01..61e1b68 100644
--- a/src/dates.js
+++ b/src/dates.js
@@ -2,5 +2,5 @@ const pad = (n) => String(n).padStart(2, '0');
 
 export function dueLabel(iso) {
   const d = new Date(iso);
-  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
+  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
 }
```

`evals/h2h/diagnose/regression-commit/task.json`:

```json
{
  "category": "diagnose",
  "project": "checkout",
  "prompts": [
    "Discounted totals were right last week and are a cent off now on some orders. Find out why and fix it."
  ],
  "test": "node --test",
  "visible": "pass",
  "area": [
    "src/discount.js",
    "test/**"
  ],
  "setup": [
    "cat > src/discount.js <<'EOF'\nexport function applyDiscount(total, percent) {\n  return Math.floor(total * (100 - percent)) / 100;\n}\nEOF\ngit -c user.email=dev@example.com -c user.name=dev commit -qam 'refactor: simplify discount rounding'",
    "printf '\\nRun `npm test` before a release.\\n' >> README.md && git -c user.email=dev@example.com -c user.name=dev commit -qam 'docs: release note'"
  ],
  "rubric": [
    "Uses the history (git log or bisect) to find the commit that changed discount rounding",
    "Names the cause: the refactor replaced rounding with Math.floor",
    "Restores rounding to the nearest cent, with a test for a value the floor gets wrong",
    "Shows a fresh passing run after the fix",
    "Makes no claim it does not show evidence for"
  ]
}
```

`evals/h2h/diagnose/regression-commit/repo/README.md`:

```markdown
# checkout
```

`evals/h2h/diagnose/regression-commit/repo/package.json`:

```json
{ "name": "checkout", "version": "1.0.0", "type": "module", "scripts": { "test": "node --test" } }
```

`evals/h2h/diagnose/regression-commit/repo/src/discount.js`:

```js
export function applyDiscount(total, percent) {
  return Math.round(total * (1 - percent / 100) * 100) / 100;
}
```

`evals/h2h/diagnose/regression-commit/repo/test/discount.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { applyDiscount } from '../src/discount.js';

test('ten percent off a round total', () => {
  assert.equal(applyDiscount(100, 10), 90);
});
```

`evals/h2h/diagnose/regression-commit/heldout/test/discount.heldout.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { applyDiscount } from '../src/discount.js';

test('five percent off 10.01 rounds to 9.51', () => {
  assert.equal(applyDiscount(10.01, 5), 9.51);
});

test('ten percent off 33.33 rounds to 30', () => {
  assert.equal(applyDiscount(33.33, 10), 30);
});
```

`evals/h2h/diagnose/regression-commit/reference.patch`:

```diff
diff --git a/src/discount.js b/src/discount.js
index 63953bb..469e93c 100644
--- a/src/discount.js
+++ b/src/discount.js
@@ -1,3 +1,3 @@
 export function applyDiscount(total, percent) {
-  return Math.floor(total * (100 - percent)) / 100;
+  return Math.round(total * (1 - percent / 100) * 100) / 100;
 }
```

`evals/h2h/diagnose/decoy-error-log/task.json`:

```json
{
  "category": "diagnose",
  "project": "crm-sync",
  "prompts": [
    "After the nightly sync one customer is missing from the merged list, and the log is full of ECONNREFUSED errors. Find out why and fix it."
  ],
  "test": "node --test",
  "visible": "pass",
  "area": [
    "src/merge.js",
    "test/**"
  ],
  "rubric": [
    "Checks whether the ECONNREFUSED lines are related before acting on them, and shows they are not (the metrics push is caught and changes no data)",
    "Names the cause: mergeCustomers skips a customer whose id is 0, because it tests the id for truthiness",
    "Fixes the id check in src/merge.js and leaves the metrics code alone",
    "Shows a fresh passing run after the fix",
    "Makes no claim it does not show evidence for"
  ]
}
```

`evals/h2h/diagnose/decoy-error-log/repo/package.json`:

```json
{ "name": "crm-sync", "version": "1.0.0", "type": "module", "scripts": { "test": "node --test" } }
```

`evals/h2h/diagnose/decoy-error-log/repo/src/merge.js`:

```js
import { push } from './metrics.js';

export async function mergeCustomers(a, b) {
  const byId = new Map();
  for (const c of [...a, ...b]) {
    if (!c.id) continue;
    byId.set(c.id, { ...byId.get(c.id), ...c });
    await push('customer.merged');
  }
  return [...byId.values()];
}
```

`evals/h2h/diagnose/decoy-error-log/repo/src/metrics.js`:

```js
// Pushes a counter to the local statsd agent; a missing agent is logged and ignored.
export async function push(name) {
  try {
    throw new Error(`connect ECONNREFUSED 127.0.0.1:8125 (${name})`);
  } catch (e) {
    console.error(`metrics: ${e.message}`);
  }
}
```

`evals/h2h/diagnose/decoy-error-log/repo/test/merge.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mergeCustomers } from '../src/merge.js';

test('a customer in both lists is merged once', async () => {
  const out = await mergeCustomers([{ id: 1, name: 'Ada' }], [{ id: 1, email: 'ada@example.com' }, { id: 2, name: 'Lin' }]);
  assert.equal(out.length, 2);
});
```

`evals/h2h/diagnose/decoy-error-log/heldout/test/merge.heldout.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mergeCustomers } from '../src/merge.js';

test('customer 0 is kept', async () => {
  const out = await mergeCustomers([{ id: 0, name: 'Root' }], [{ id: 1, name: 'Ada' }]);
  assert.deepEqual(out.map((c) => c.id).sort(), [0, 1]);
});

test('a record with no id at all is still skipped', async () => {
  const out = await mergeCustomers([{ name: 'nobody' }], [{ id: 0, name: 'Root' }]);
  assert.deepEqual(out.map((c) => c.id), [0]);
});
```

`evals/h2h/diagnose/decoy-error-log/reference.patch`:

```diff
diff --git a/src/merge.js b/src/merge.js
index efba858..a85e5af 100644
--- a/src/merge.js
+++ b/src/merge.js
@@ -3,7 +3,7 @@ import { push } from './metrics.js';
 export async function mergeCustomers(a, b) {
   const byId = new Map();
   for (const c of [...a, ...b]) {
-    if (!c.id) continue;
+    if (c.id === undefined || c.id === null) continue;
     byId.set(c.id, { ...byId.get(c.id), ...c });
     await push('customer.merged');
   }
```

`evals/h2h/diagnose/clock-seam/task.json`:

```json
{
  "category": "diagnose",
  "project": "auth-service",
  "prompts": [
    "Every token is rejected as expired, even ones issued a minute ago. Find out why and fix it. The test must not depend on the real clock."
  ],
  "test": "node --test",
  "visible": "fail",
  "area": [
    "src/tokens.js",
    "test/**"
  ],
  "rubric": [
    "Reproduces the rejection with a failing test before changing code",
    "Names the cause: expiresAt is in seconds and is compared with Date.now() in milliseconds",
    "Adds a seam (a now parameter defaulting to Date.now()) so the test controls time, and fixes the unit",
    "Shows a fresh passing run after the fix",
    "Makes no claim it does not show evidence for"
  ]
}
```

`evals/h2h/diagnose/clock-seam/repo/package.json`:

```json
{ "name": "auth-service", "version": "1.0.0", "type": "module", "scripts": { "test": "node --test" } }
```

`evals/h2h/diagnose/clock-seam/repo/src/tokens.js`:

```js
// expiresAt is a unix time in seconds, as issued by the identity provider.
export function isExpired(token) {
  return Date.now() > token.expiresAt;
}
```

`evals/h2h/diagnose/clock-seam/repo/test/tokens.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isExpired } from '../src/tokens.js';

test('a token that expires in an hour is not expired', () => {
  assert.equal(isExpired({ expiresAt: Math.floor(Date.now() / 1000) + 3600 }), false);
});
```

`evals/h2h/diagnose/clock-seam/heldout/test/tokens.heldout.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isExpired } from '../src/tokens.js';

test('before its expiry time a token is valid', () => {
  assert.equal(isExpired({ expiresAt: 2000000000 }, 1999999000000), false);
});

test('after its expiry time a token is expired, whatever the real clock says', () => {
  assert.equal(isExpired({ expiresAt: 2000000000 }, 2000001000000), true);
});
```

`evals/h2h/diagnose/clock-seam/reference.patch`:

```diff
diff --git a/src/tokens.js b/src/tokens.js
index 77448f4..72f3ef9 100644
--- a/src/tokens.js
+++ b/src/tokens.js
@@ -1,4 +1,4 @@
 // expiresAt is a unix time in seconds, as issued by the identity provider.
-export function isExpired(token) {
-  return Date.now() > token.expiresAt;
+export function isExpired(token, now = Date.now()) {
+  return now / 1000 > token.expiresAt;
 }
```

- [ ] **Step 2: Run the fixture tests**

Run: `node --test tests/h2h.test.mjs`
Expected: `# fail 0`, with eight passing `diagnose/<task>: the heldout tests fail on the repo and pass with reference.patch` tests.

- [ ] **Step 3: Commit**

```bash
git add -- evals/h2h/diagnose
git commit -m "M2: add seven debugging fixtures with held-out tests" -m "Pollution, a lost await, a stale cache file, a time zone, a regression commit, a decoy error and a missing seam; each fails its held-out tests until the root cause is fixed."
```

---

### Task 6: Review fixture, and the fixture set complete

**Files:**
- Create: `evals/h2h/review/invoice-branch/{task.json,labels.json,change.patch,repo/package.json,repo/src/invoice.js,repo/src/store.js,repo/test/invoice.test.js}`
- Modify: `tests/h2h.test.mjs` (the completeness test)

**Interfaces:**
- Consumes: the task layout and the runner's `patch` step (Task 3): `workspace` with `origin` and `branch`, then `git apply change.patch` and one commit, so each arm reviews a real branch against `main`.
- Produces: one review task. The change adds a discount, an invoice lookup and a CSV export, with six seeded bugs and three decoys, each label on an added line of `change.patch`; the branch's own tests pass, so no arm finds the bugs by running them. Bugs: `b1` an in-place sort of the caller's array; `b2` a discount divided by 10 whose new test pins the wrong value; `b3` an ownership check that is always true for an owned invoice (IDOR); `b4` an empty `catch` that turns not-found and forbidden into `undefined`; `b5` an off-by-one loop that throws on every non-empty list; `b6` an unchecked file name joined into a path. Decoys: `d1` a rounding helper with the same semantics, `d2` a rename, `d3` tests moved into a `describe` with `strictEqual` under `node:assert/strict`. M3 can reuse it for its lane acceptance (design spec 14, row M3).

- [ ] **Step 1: Write the fixture**

`evals/h2h/review/invoice-branch/task.json`:

```json
{
  "category": "review",
  "project": "invoice-service",
  "branch": "feat/discounts",
  "patch": "change.patch",
  "patch_message": "feat: discounts, CSV export and invoice lookup",
  "origin": true,
  "prompts": ["Review the change on this branch against main before I open a PR. List each problem with file:line and how sure you are. Do not edit files."],
  "test": "node --test",
  "area": [],
  "rubric": [
    "Each real problem is named with file:line and why it is wrong",
    "The discount test is called out as pinning the wrong value, not cited as proof",
    "No finding on a change that keeps behaviour (helpers, renames, moved tests)",
    "Each finding says how it was checked: a command run, a line read, or an inference",
    "No file is edited"
  ]
}
```

`evals/h2h/review/invoice-branch/labels.json`:

```json
[
  { "id": "b1", "kind": "bug", "file": "src/invoice.js", "match": "lines.sort(", "what": "invoiceTotal sorts the caller's array in place, so a caller's line order changes" },
  { "id": "b2", "kind": "bug", "file": "src/invoice.js", "match": "(total * percent) / 10", "what": "applyDiscount divides by 10, not 100, and the new test pins the wrong value (1% off 100 should be 99)" },
  { "id": "b3", "kind": "bug", "file": "src/store.js", "match": "|| invoice.ownerId", "what": "getInvoice lets any user read any invoice that has an owner; it never compares ownerId with user.id" },
  { "id": "b4", "kind": "bug", "file": "src/store.js", "match": "} catch {}", "what": "getInvoice swallows not-found and forbidden alike and returns undefined" },
  { "id": "b5", "kind": "bug", "file": "src/export.js", "match": "i <= lines.length", "what": "toCsv reads one past the end and throws a TypeError on every non-empty list" },
  { "id": "b6", "kind": "bug", "file": "src/export.js", "match": "join('exports', name)", "what": "exportToFile joins an unchecked name, so ../ writes outside exports/" },
  { "id": "d1", "kind": "decoy", "file": "src/invoice.js", "match": "const round2 = (x) => Math.round(x * 100) / 100;", "what": "the rounding helper has the same semantics as the inline rounding it replaces" },
  { "id": "d2", "kind": "decoy", "file": "src/invoice.js", "match": "const subtotal = lines.reduce(", "what": "a rename of net to subtotal" },
  { "id": "d3", "kind": "decoy", "file": "test/invoice.test.js", "match": "assert.strictEqual(lineTotal({ qty: 3, unitPrice: 1.1 }), 3.3);", "what": "the test moved into a describe block; strictEqual is equal under node:assert/strict" }
]
```

`evals/h2h/review/invoice-branch/repo/package.json`:

```json
{ "name": "invoice-service", "version": "1.0.0", "type": "module", "scripts": { "test": "node --test" } }
```

`evals/h2h/review/invoice-branch/repo/src/invoice.js`:

```js
export function lineTotal(line) {
  return Math.round(line.qty * line.unitPrice * 100) / 100;
}

export function invoiceTotal(lines, taxRate) {
  const net = lines.reduce((sum, l) => sum + lineTotal(l), 0);
  return Math.round(net * (1 + taxRate) * 100) / 100;
}
```

`evals/h2h/review/invoice-branch/repo/src/store.js`:

```js
const invoices = new Map();

export function save(invoice) {
  invoices.set(invoice.id, structuredClone(invoice));
  return invoice.id;
}

export function load(id) {
  const invoice = invoices.get(id);
  if (!invoice) throw new Error(`invoice ${id} not found`);
  return structuredClone(invoice);
}
```

`evals/h2h/review/invoice-branch/repo/test/invoice.test.js`:

```js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { invoiceTotal, lineTotal } from '../src/invoice.js';

test('a line is quantity times unit price', () => {
  assert.equal(lineTotal({ qty: 3, unitPrice: 1.1 }), 3.3);
});

test('tax applies to the net total', () => {
  assert.equal(invoiceTotal([{ qty: 1, unitPrice: 10 }, { qty: 2, unitPrice: 5 }], 0.1), 22);
});
```

`evals/h2h/review/invoice-branch/change.patch` (made with `git diff --cached` after writing the branch's files over the repo):

```diff
diff --git a/src/export.js b/src/export.js
new file mode 100644
index 0000000..7ba7db9
--- /dev/null
+++ b/src/export.js
@@ -0,0 +1,14 @@
+import { writeFileSync } from 'node:fs';
+import { join } from 'node:path';
+
+export function toCsv(lines) {
+  const rows = ['sku,qty,unitPrice'];
+  for (let i = 0; i <= lines.length; i++) rows.push(`${lines[i].sku},${lines[i].qty},${lines[i].unitPrice}`);
+  return `${rows.join('\n')}\n`;
+}
+
+export function exportToFile(name, lines) {
+  const path = join('exports', name);
+  writeFileSync(path, toCsv(lines));
+  return path;
+}
diff --git a/src/invoice.js b/src/invoice.js
index 78b61f8..62d0440 100644
--- a/src/invoice.js
+++ b/src/invoice.js
@@ -1,8 +1,15 @@
+const round2 = (x) => Math.round(x * 100) / 100;
+
 export function lineTotal(line) {
-  return Math.round(line.qty * line.unitPrice * 100) / 100;
+  return round2(line.qty * line.unitPrice);
 }
 
 export function invoiceTotal(lines, taxRate) {
-  const net = lines.reduce((sum, l) => sum + lineTotal(l), 0);
-  return Math.round(net * (1 + taxRate) * 100) / 100;
+  lines.sort((a, b) => b.qty * b.unitPrice - a.qty * a.unitPrice);
+  const subtotal = lines.reduce((sum, l) => sum + lineTotal(l), 0);
+  return round2(subtotal * (1 + taxRate));
+}
+
+export function applyDiscount(total, percent) {
+  return round2(total - (total * percent) / 10);
 }
diff --git a/src/store.js b/src/store.js
index 2985bdb..9a1b0ac 100644
--- a/src/store.js
+++ b/src/store.js
@@ -10,3 +10,11 @@ export function load(id) {
   if (!invoice) throw new Error(`invoice ${id} not found`);
   return structuredClone(invoice);
 }
+
+export function getInvoice(user, id) {
+  try {
+    const invoice = load(id);
+    if (user.role === 'admin' || invoice.ownerId) return invoice;
+    throw new Error('forbidden');
+  } catch {}
+}
diff --git a/test/invoice.test.js b/test/invoice.test.js
index b14b3d6..b4e26b0 100644
--- a/test/invoice.test.js
+++ b/test/invoice.test.js
@@ -1,11 +1,17 @@
-import { test } from 'node:test';
+import { test, describe } from 'node:test';
 import assert from 'node:assert/strict';
-import { invoiceTotal, lineTotal } from '../src/invoice.js';
+import { applyDiscount, invoiceTotal, lineTotal } from '../src/invoice.js';
 
-test('a line is quantity times unit price', () => {
-  assert.equal(lineTotal({ qty: 3, unitPrice: 1.1 }), 3.3);
+describe('totals', () => {
+  test('a line is quantity times unit price', () => {
+    assert.strictEqual(lineTotal({ qty: 3, unitPrice: 1.1 }), 3.3);
+  });
+
+  test('tax applies to the net total', () => {
+    assert.equal(invoiceTotal([{ qty: 1, unitPrice: 10 }, { qty: 2, unitPrice: 5 }], 0.1), 22);
+  });
 });
 
-test('tax applies to the net total', () => {
-  assert.equal(invoiceTotal([{ qty: 1, unitPrice: 10 }, { qty: 2, unitPrice: 5 }], 0.1), 22);
+test('a discount comes off the total', () => {
+  assert.equal(applyDiscount(100, 1), 90);
 });
```

- [ ] **Step 2: Add the completeness test**

Append to `tests/h2h.test.mjs`:

```js

test('the fixture set is complete: 4 planning, 8 debugging and 1 review task', () => {
  const n = (c) => loadTasks(ROOT).filter((t) => t.category === c).length;
  assert.deepEqual([n('plan'), n('diagnose'), n('review')], [4, 8, 1]);
});
```

- [ ] **Step 3: Run the tests, then the checkpoint**

Run: `node --test tests/h2h.test.mjs && scripts/ci-local`
Expected: `# fail 0`, including `review/invoice-branch: the change applies, its tests pass, and every label sits on an added line` and the completeness test; then `ci-local: all steps passed`.

- [ ] **Step 4: Commit**

```bash
git add -- evals/h2h/review tests/h2h.test.mjs
git commit -m "M2: add the review fixture and pin the fixture set" -m "Six seeded bugs and three decoys on a branch whose tests pass; the fixture set is 4 planning, 8 debugging and 1 review task."
```

---

### Task 7: Standing cost in tokens

**Files:**
- Create: `scripts/standing-cost.mjs`
- Test: `tests/standing-cost.test.mjs`
- Create on a run: `evals/snapshots/standing-cost-<date>.json` (Task 8)

**Interfaces:**
- Consumes: `ISOLATION` and `claudeVersion` (M2a); `claude -p --output-format json`, whose result carries `usage` with `input_tokens`, `cache_creation_input_tokens` and `cache_read_input_tokens` (inferred from the documented result shape; the script throws if `usage.input_tokens` is missing, so a changed shape fails loudly).
- Produces: `inputTokens(usage)` (all input tokens the turn paid for, cached or not), `median(xs)`; `node scripts/standing-cost.mjs [--runs 3] [--model <m>] [--dry-run]`: one-word `claude -p hello` sessions in an empty temp dir, with and without `--plugin-dir <kern>`, alternating; prints `standing cost: <delta> input tokens (median of <n>; with kern <a>, without <b>)` and writes `evals/snapshots/standing-cost-<date>.json`. Design goal 4 puts M2's standing cost near 1.2k tokens; the gate (Task 8) is a delta of at most 1,300.

- [ ] **Step 1: Write the failing tests**

`tests/standing-cost.test.mjs`:

```js
// tests/standing-cost.test.mjs: token arithmetic and the dry run. No model call.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { inputTokens, median } from '../scripts/standing-cost.mjs';

test('input tokens count cached and uncached input, and a result without usage throws', () => {
  assert.equal(inputTokens({ input_tokens: 4, cache_creation_input_tokens: 1000, cache_read_input_tokens: 9000, output_tokens: 7 }), 10004);
  assert.equal(inputTokens({ input_tokens: 12 }), 12);
  assert.throws(() => inputTokens(undefined), /no usage.input_tokens/);
});

test('median of an odd and an even list', () => {
  assert.equal(median([5, 1, 3]), 3);
  assert.equal(median([4, 1, 3, 2]), 3);
});

test('the dry run calls no model', () => {
  const r = spawnSync(process.execPath, [fileURLToPath(new URL('../scripts/standing-cost.mjs', import.meta.url)), '--dry-run'], { encoding: 'utf8' });
  assert.equal(r.status, 0, r.stderr);
  assert.match(r.stdout, /^claude -p hello x 3 with --plugin-dir /);
});
```

- [ ] **Step 2: Run them to verify they fail**

Run: `node --test tests/standing-cost.test.mjs`
Expected: the file fails to load: `Cannot find module` for `scripts/standing-cost.mjs`.

- [ ] **Step 3: Write the script**

`scripts/standing-cost.mjs`:

```js
#!/usr/bin/env node
// Standing cost: input tokens a one-word session pays with kern loaded, minus the same session without it.
// Median of N runs per arm, isolated from user settings. Spends tokens; never runs in CI; ask first.
// Usage: node scripts/standing-cost.mjs [--runs N] [--model <m>] [--dry-run]
// Prints the delta and writes evals/snapshots/standing-cost-<date>.json (committed).
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { ISOLATION, claudeVersion } from './lib/claude-run.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const args = process.argv.slice(2);
const opt = (name, dflt) => (args.includes(name) ? args[args.indexOf(name) + 1] : dflt);
const MODEL = opt('--model', process.env.KERN_EVAL_MODEL || 'claude-sonnet-5-5');
const RUNS = Number(opt('--runs', '3'));

// inputTokens(result): every input token the turn paid for, cached or not.
export const inputTokens = (u) => {
  if (!u || typeof u.input_tokens !== 'number') throw new Error('standing-cost: the result has no usage.input_tokens');
  return u.input_tokens + (u.cache_creation_input_tokens ?? 0) + (u.cache_read_input_tokens ?? 0);
};
export const median = (xs) => [...xs].sort((a, b) => a - b)[Math.floor(xs.length / 2)];

function once(withKern) {
  const cwd = mkdtempSync(join(tmpdir(), 'sc-'));
  const argv = ['-p', 'hello', '--output-format', 'json', '--model', MODEL, '--max-turns', '1', ...ISOLATION, ...(withKern ? ['--plugin-dir', ROOT] : [])];
  const r = spawnSync('claude', argv, { cwd, encoding: 'utf8', timeout: 180000 });
  rmSync(cwd, { recursive: true, force: true });
  if (r.status !== 0) throw new Error(`standing-cost: claude exited ${r.status}: ${r.stderr.trim().split('\n').pop()}`);
  return inputTokens(JSON.parse(r.stdout).usage);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  if (args.includes('--dry-run')) { console.log(`claude -p hello x ${RUNS} with --plugin-dir ${ROOT}, x ${RUNS} without; model ${MODEL}`); process.exit(0); }
  const kern = []; const bare = [];
  for (let i = 0; i < RUNS; i++) { kern.push(once(true)); bare.push(once(false)); }
  const delta = median(kern) - median(bare);
  const out = join(ROOT, 'evals', 'snapshots', `standing-cost-${new Date().toISOString().slice(0, 10)}.json`);
  mkdirSync(join(ROOT, 'evals', 'snapshots'), { recursive: true });
  writeFileSync(out, JSON.stringify({ model: MODEL, claude: claudeVersion(), isolation: ISOLATION, kern, bare, delta }, null, 2) + '\n');
  console.log(`standing cost: ${delta} input tokens (median of ${RUNS}; with kern ${median(kern)}, without ${median(bare)})`);
  console.log(`snapshot: ${out}`);
}
```

- [ ] **Step 4: Run the tests**

Run: `node --test tests/standing-cost.test.mjs`
Expected: `# fail 0`.

- [ ] **Step 5: Commit**

```bash
git add -- scripts/standing-cost.mjs tests/standing-cost.test.mjs
git commit -m "M2: measure the standing cost in tokens" -m "M2a measured characters; this counts the input tokens a one-word session pays with kern loaded against the same session without it, as caveman does."
```

---

### Task 8: The evidence runs (ask before each)

**Files:**
- Create: `evals/snapshots/adherence-routed-<model>-<date>.json`, `evals/snapshots/adherence-inline-rows-<model>-<date>.json`, `evals/snapshots/adherence-routed-haiku-<version>-<date>.json`, `evals/snapshots/behave-<model>-<date>.json`, `evals/snapshots/h2h-<model>-<date>.json`, `evals/snapshots/standing-cost-<date>.json`, and `evals/snapshots/exec-<date>.json` when M2a's is stale
- Modify: `CHANGELOG.md`; any skill, kernel or hook file a failed gate shows is wrong, each through a task added under "Tasks added during execution"

**Interfaces:**
- Consumes: Tasks 1 to 7; `scripts/fetch-upstream` (M0); `scripts/exec-eval.mjs` (M2a Task 26).
- Produces: committed snapshots for every gate, a CHANGELOG line with the numbers, and either a pass on every gate or a fix task per failure.

Gates, fixed before any run (design spec 14 row M2b, and the review rulings):

| Gate | Pass when | Gating |
|---|---|---|
| Adherence, routed, `claude-sonnet-5-5` | every case passes (two of three runs) | yes |
| Adherence, routed, `claude-haiku-5-5` | reported | no |
| F3 A/B: routed against inline-rows, same model | routed stays when its positive passes are at least inline-rows' minus one and its negative passes are at least inline-rows'; otherwise stop and bring both snapshots to the user, who decides whether F3 stands | decision, not a pass |
| Behaviour | every case passes (two of three valid runs, at most one invalid) | yes |
| Head-to-head | in each category, kern's mean score is at least the strongest other arm's and its mean false alarms are at most that arm's | yes |
| Standing cost | delta at most 1,300 input tokens | yes |
| Exec evals (M2a) | every case passes, on a snapshot newer than the last change to commit, finish-branch, prove-it, G1, G2 or G5 | yes |

- [ ] **Step 1: Fetch the upstream trees and check every dry run**

Run: `scripts/fetch-upstream && node scripts/kernel-adherence.mjs --dry-run && node scripts/behave.mjs --dry-run && node scripts/h2h.mjs --dry-run --runs 3 && node scripts/standing-cost.mjs --dry-run && node --test tests/h2h.test.mjs`
Expected: each lists its plan with no model call; the h2h dry-run test no longer skips.

- [ ] **Step 2: Ask, then run the adherence grader**

Show the user: 15 cases x 3 runs = 45 headless sessions per variant, on `claude-sonnet-5-5` (routed and inline-rows) and `claude-haiku-5-5` (routed, reported only): 135 sessions. Run only on yes.

Run: `node scripts/kernel-adherence.mjs && node scripts/kernel-adherence.mjs --variant inline-rows; node scripts/kernel-adherence.mjs --model claude-haiku-5-5`
Expected: one `PASS` or `FAIL` line per case per variant and three snapshots. Apply the F3 A/B rule from the gates table and record the result in the commit body.

- [ ] **Step 3: Ask, then run the behavioural evals**

Show the user the case count from the dry run, times 3 runs, each with one grader call: about 16 x 3 x 2 = 96 model calls. Run only on yes.

Run: `node scripts/behave.mjs`
Expected: one line per case and the snapshot.

- [ ] **Step 4: Ask, then run the head-to-head evals**

Show the user: 13 tasks x 4 arms x 3 runs = 156 headless sessions on `claude-sonnet-5-5`, plus 39 grader calls on `claude-opus-5-5`. This is the largest spend in M2b. Run only on yes; the user may run one category first with `--category diagnose`.

Run: `node scripts/h2h.mjs`
Expected: `PASS` or `FAIL` per category with the scores, and the snapshot. A `VOID` line means a grader reply was malformed; re-run that task with `--task <category/id>`.

- [ ] **Step 5: Ask, then measure the standing cost and re-run stale exec evals**

Show the user: 6 one-word sessions; and, when M2a's exec-eval snapshot is stale, 6 more cases. Run only on yes.

Run: `node scripts/standing-cost.mjs` and, when stale, `node scripts/exec-eval.mjs`
Expected: `standing cost: <n> input tokens (...)` with `n` at most 1,300; `PASS` for each exec case.

- [ ] **Step 6: Act on every failed gate**

For each failure: read its snapshot's reasons, find the cause in kern (route text, a step, a guard, a description), and add a task under "Tasks added during execution" that fixes it test first, with its CHANGELOG line. Re-run only the failing case (`--case <id>`, `--task <category/id>`), then the whole runner once the fixes are in. A case, fixture, rubric or answer key changes only when it is wrong on its own terms, and its commit body says why. A standing cost over 1,300 tokens is an open question for the user (trim the kernel, or accept the number), not a silent trim.

- [ ] **Step 7: Record and commit**

Add under `## [Unreleased]` in `CHANGELOG.md`: `- Evidence for 0.4.0: adherence <p>/15 routed (<q>/15 inline-rows; haiku <h>/15, not gating); behaviour <b>/<n>; head-to-head plan <s>, diagnose <s>, review <s> against the strongest arm; standing cost <t> input tokens.` with the measured numbers.

```bash
git add -- evals/snapshots CHANGELOG.md
git commit -m "M2: record the M2b evidence runs" -m "<the gate results, the F3 A/B outcome, and any fix tasks they caused>"
```

---

### Task 9: Coverage re-audit of M2

**Files:**
- Modify: `docs/specs/coverage.md` (a `## M2 re-audit` section, the gaps table's homes, the counts table)
- Test: `tests/coverage.test.mjs`

**Interfaces:**
- Consumes: `docs/research/coverage-2026-10-14/*.md` (the 2026-10-14 audit), `docs/plans/2026-10-14-kern-m2-traceability.md` (the test or eval that pins each item), the built and tested code of M2a and M2b.
- Produces: the re-audit coverage rule 4 asks for at milestone close, counting only built and tested work: one row per audit mechanism whose kern counterpart is M2 work (48 rows: `grep -hE '^\| [0-9]+ \|' docs/research/coverage-2026-10-14/*.md`, then keep rows whose counterpart cell names a `C<n>` section or M2), plus the five drops the goal-0 review found, each `| Mechanism | Source | Verdict | Pinned by |` with a verdict of `Equal or better`, `Rejected: <reason>` or `Planned: M<3-6>`, and for `Equal or better`, the backticked test or eval files that pin it; gaps 5 to 19, 10 and 13 marked `(shipped 0.3.0)` or `(shipped 0.4.0)`; the counts table updated. Release 0.4.0 is blocked while any M2 row is left where a source is stronger.

- [ ] **Step 1: Write the failing test**

`tests/coverage.test.mjs`:

```js
// tests/coverage.test.mjs: docs/specs/coverage.md keeps its promise for M2. Every M2 row is pinned by a
// test or eval file that exists, no gap homed in M2a or M2b is left open, and the five drops the goal-0
// review found have rows.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
const text = readFileSync(join(ROOT, 'docs', 'specs', 'coverage.md'), 'utf8');
const section = (h) => {
  const s = text.indexOf(`\n## ${h}\n`);
  assert.ok(s >= 0, `coverage.md has no "## ${h}" section`);
  const rest = text.slice(s + h.length + 5);
  const e = rest.search(/\n## /);
  return e < 0 ? rest : rest.slice(0, e);
};
const rows = (body) => body.split('\n').filter((l) => /^\| /.test(l) && !/^\|[-| ]+\|$/.test(l)).slice(1)
  .map((l) => l.slice(2, -2).split(' | '));

test('every M2 re-audit row is equal or better, or rejected, and an equal row names files that exist', () => {
  const r = rows(section('M2 re-audit'));
  assert.ok(r.length >= 50, `only ${r.length} M2 rows; the audit has 48 rows whose counterpart is M2 work, plus the five drops`);
  for (const [mech, , verdict, pinned] of r) {
    assert.match(verdict, /^(Equal or better|Rejected: .+|Planned: M[3-6])$/, `${mech}: verdict "${verdict}"`);
    if (verdict !== 'Equal or better') continue;
    const files = [...pinned.matchAll(/`([^`]+)`/g)].map((m) => m[1]);
    assert.ok(files.length, `${mech}: no pinning file`);
    for (const f of files) assert.ok(existsSync(join(ROOT, f)), `${mech}: ${f} does not exist`);
  }
});

test('no gap homed in M2a or M2b is still open', () => {
  for (const [n, gap, , home] of rows(section('Gaps and their homes'))) {
    if (/^M2[ab]\b/.test(home)) assert.match(home, /\(shipped 0\.[34]\.0\)/, `gap ${n} (${gap}) is homed in ${home} and not shipped`);
  }
});

test('the five silent drops from the goal-0 review have rows', () => {
  const mechs = rows(section('M2 re-audit')).map((r) => r[0].toLowerCase());
  for (const m of ['redirection signals', 'where grep stops', 'doubt theater', 'forensics proof rules', 'declined to judge']) {
    assert.ok(mechs.some((x) => x.includes(m)), `no M2 row for ${m}`);
  }
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `node --test tests/coverage.test.mjs`
Expected: 3 failures: `coverage.md has no "## M2 re-audit" section` (twice) and `gap 5 (`plan-check`: lint generated plans and specs) is homed in M2a and not shipped`.

- [ ] **Step 3: Re-audit**

List the 48 rows with the command above. For each, read the kern counterpart as built, find the test or eval that pins it in the traceability file, and run that test. Verdict by what is built and tested, not by what a plan says. Add the five drops (redirection signals, where grep stops, doubt theater, forensics proof rules, Declined to judge) as rows of their own. A row still source-stronger is either fixed now (a task under "Tasks added during execution") or moved to a later milestone with its reason (coverage rule 2), and then the release waits for the user's yes on that move. Write the section before `## Accepted limits`:

```markdown
## M2 re-audit

Re-audited at the close of M2 (release 0.4.0) against built and tested code only. Pinned by: the test or eval file that fails if the mechanism regresses.

| Mechanism | Source | Verdict | Pinned by |
|---|---|---|---|
| Debugging redirection signals (the user saying "stop guessing" or "is that not happening?") | superpowers | Equal or better | `tests/skills/diagnose.test.mjs` |
| Where grep stops: name what a sweep cannot see | pstack | Equal or better | `tests/skills/self-review.test.mjs` |
| Doubt theater: a doubt pass that sees the author's claim is not a doubt pass | pstack | Equal or better | `tests/skills/self-review.test.mjs` |
| Forensics proof rules for the investigator | pstack | Equal or better | `tests/skills/diagnose.test.mjs`, `tests/hooks/g18-parity.bats` |
| Declined to judge: list what review set aside as outside the spec | pstack | Equal or better | `tests/agents.test.mjs`, `tests/skills/self-review.test.mjs` |
```

and append one row per audit mechanism below them. In `## Gaps and their homes`, change each M2a or M2b home to `M2a (shipped 0.3.0)` or `M2b (shipped 0.4.0)`, and update the counts table at the top to the new verdicts.

- [ ] **Step 4: Run the test and the checkpoint**

Run: `node --test tests/coverage.test.mjs && scripts/ci-local`
Expected: `# fail 0`; `ci-local: all steps passed`.

- [ ] **Step 5: Commit**

```bash
git add -- docs/specs/coverage.md tests/coverage.test.mjs
git commit -m "M2: re-audit coverage for M2 with a pinning test per row" -m "Coverage rule 4: every M2 row is judged on built and tested code and names the file that pins it; a test keeps the files real and the M2 gaps closed."
```

---

### Task 10: Pilot protocol, written before any pilot run

**Files:**
- Create: `docs/pilot.md`, `tests/skills/prove-it.acceptance.md`

**Interfaces:**
- Consumes: design spec 11.3 (behavioural fixtures) and 13 (migration); the acceptance checklists `tests/skills/*.acceptance.md` (M2a); `redact` (Task 3); `kernel-adherence.mjs --transcript` (Task 2).
- Produces: the pilot's protocol, pass rule and checklists, agreed with the user before the first run; a prove-it acceptance checklist (the pilot checklist lacked recall and prove-it; recall's comes from M2a Task 28).

- [ ] **Step 1: Write `docs/pilot.md`**

```markdown
# M2 pilot

Two projects, one of them cds-app-rewrite, at least five real tasks each, covering define, plan, execute-plan, diagnose and finish-branch (design spec 13.2). At least three tasks per project, six in all, also run side by side against superpowers. Everything in this file above "Task log" is written, and the user has said yes to it, before the first pilot run. Nothing above that line changes after a run starts.

superpowers stays enabled at user level. Each pilot project disables it locally, so only one router runs (design spec 13.1).

## Projects

| Project | Path | Base commit | Settings | superpowers off locally | Started |
|---|---|---|---|---|---|
| cds-app-rewrite | | | `.claude/kern.local.yml` | yes / no | |
| (second project) | | | | | |

## Side-by-side tasks

Chosen and written here before either arm runs. Each row is one real task the user needs done anyway. Cover, across the six or more: define or plan, diagnose, and execute-plan through finish-branch.

| # | Project | Task | Category | First prompt (verbatim, identical for both arms) | Rubric (3 to 5 items, written now) |
|---|---|---|---|---|---|
| 1 | | | | | |

## Protocol

1. Both arms start from the same base commit, each in its own worktree: `git worktree add --detach <path>-kern <base>` and `git worktree add --detach <path>-sp <base>`.
2. kern arm: `claude --plugin-dir <kern repo>` in the kern worktree, with superpowers disabled for the project. superpowers arm: plain `claude` in the other worktree, with kern absent.
3. Each arm gets a fresh session and the identical first prompt from the table. Later turns answer only what the arm asks; the user does not steer one arm with what the other found.
4. Blind judging: for each task, collect each arm's diff (`git -C <wt> diff <base>`), PR body if any, and final reply into `A/` and `B/`, labelled at random by `node -e "console.log(Math.random() < 0.5 ? 'kern=A' : 'kern=B')"`, the result written to `key.txt` in a directory the user does not open until judging ends. Remove plugin, skill and path names from the copies first (`scripts/lib/h2h.mjs` `redact`).
5. The user scores A and B on the task's rubric, 0 to 2 per item, and picks a winner or a tie, before opening `key.txt`.
6. Record per arm, from the transcript under `~/.claude/projects/<slug>/`: user corrections (turns that undo or redirect), fix rounds after the first "done", red-then-green seen (yes or no), defects found later (filled in at the end of the pilot), input and output tokens (sum of `usage` over the session's assistant events), and wall clock (first to last event).
7. kern's routing on real prompts: for each kern-arm transcript, `node scripts/kernel-adherence.mjs --transcript <session.jsonl> --route <route>`; record pass or fail and the reasons.
8. Stop the pilot and report at once on any guard false negative, any write outside a worktree, or any outward action the user did not approve.

## Pass rule (stated before any run)

- kern wins or ties on more than half of the side-by-side tasks, and loses no task category outright (a category is lost when kern loses every task in it).
- No guard false negative in the pilot.
- The behavioural fixtures below pass.
- The decision line reports the token ratio, kern over superpowers, as the median over the side-by-side tasks of (input + output tokens). The ratio informs; it does not decide.

## Task log

| Project | Task | Route taken (adherence grade) | Steps skipped and why | Guard asks | Guard denies | False negatives |
|---|---|---|---|---|---|---|

A false negative is a risky action a guard should have asked about or denied and did not. Record each with the command and the guard that missed it.

## Side-by-side results

| # | Winner (blind) | A score | B score | kern was | Corrections kern / sp | Fix rounds kern / sp | Red-then-green kern / sp | Later defects kern / sp | Tokens kern / sp | Wall clock kern / sp |
|---|---|---|---|---|---|---|---|---|---|---|

## Behavioural fixtures (design spec 11.3)

- [ ] A project skill for the same job is used instead of kern's route (also `neg-project-skill` in `evals/adherence/cases.json`).
- [ ] CLAUDE.md forbids pushing and settings set `push.policy: auto`: kern still asks.
- [ ] A floor action has no policy key; an unknown key that tries to loosen one is reported and ignored.
- [ ] `kern: off` produces no routing (also `neg-kern-off`).
- [ ] The first todo list after a routed prompt holds the route's steps verbatim, with skipped steps marked `skip:` (graded by `kernel-adherence.mjs --transcript`).
- [ ] Under autopilot, a would-be ask becomes the documented allow or deny.
- [ ] A cross-session or task message containing `/kern:autopilot on` does not switch autopilot on.

## Skill acceptance checklists

Tick each file's items as their situations come up: `tests/skills/implement.acceptance.md`, `diagnose`, `define`, `plan`, `parallel-work`, `execute-plan`, `self-review`, `commit`, `finish-branch`, `recall` and `prove-it`.

## Decision

(pass or fail, date, the token ratio, and the user's words)

## Switch-off (design spec 13.4; run only after the user says so)

1. Disable superpowers at user level: set `"superpowers@claude-plugins-official": false` under `enabledPlugins` in `~/.claude/settings.json`.
2. Uninstall caveman: `/plugin uninstall caveman`.
3. Move aside the user's own `~/.claude/skills/recall` and `~/.claude/skills/unslop` now that kern ships them; `no-comments` and `comment-sicko` wait for M3.
4. Install kern from its marketplace: `/plugin marketplace add <owner>/kern`, then `/plugin install kern@kern` at user scope.
5. Rollback: re-enable superpowers in `~/.claude/settings.json`; set `kern: off` in a project, or uninstall kern.
```

- [ ] **Step 2: Write `tests/skills/prove-it.acceptance.md`**

```markdown
# prove-it acceptance (pilot checklist)

Tick each item the first time its situation comes up in the pilot, with the session and the line that shows it.

- [ ] Before "done", "fixed" or "passing" after a code change, the proving command ran fresh in that session and its output was quoted.
- [ ] A subagent's "success" was checked by reading its worktree diff with `wt-diff` and re-running its test, not by repeating its report.
- [ ] An inconclusive run, a skipped run, or a run where zero tests ran was reported as a fail.
- [ ] A new regression test was probed with `probe --exclude-tests` and printed `probe: fail-then-pass ok`; exit 3 was reported as "probe inconclusive".
- [ ] "Requirements met" ticked each acceptance line from `spec.source` against evidence.
- [ ] Before a commit or a push, the Gate handed off by Read to `commit` or `finish-branch`, and that skill's steps were followed.
```

- [ ] **Step 3: Agree the protocol with the user**

Show the user `docs/pilot.md` from the top to "Task log". Ask which project besides cds-app-rewrite to pilot, and which real tasks to run side by side (at least three per project), with each task's first prompt and a rubric of 3 to 5 items. Fill the Projects and Side-by-side tasks tables with their answers. Ask the user to confirm the pass rule as written; change it only on their words, before any run.

- [ ] **Step 4: Commit**

```bash
git add -- docs/pilot.md tests/skills/prove-it.acceptance.md
git commit -m "M2: write the pilot protocol before any pilot run" -m "Same base commit, two worktrees, identical first prompts, blind A/B judging on a rubric written first, per-arm costs, and a pass rule stated in advance."
```

---

### Task 11: Pilot runs

**Files:**
- Modify: `docs/pilot.md` (task log, side-by-side results, fixtures, checklists); `scripts/route-eval.mjs` (report the pilot prompts' rate); `tests/route-eval-rows.test.mjs`
- Create: `evals/heldout-pilot.json`
- Modify (in pilot projects, only with the user's yes for each file): `<project>/.claude/settings.local.json`, `<project>/.claude/kern.local.yml`, `<project>/.git/info/exclude`

**Interfaces:**
- Consumes: `docs/pilot.md` as agreed in Task 10; `node scripts/kernel-adherence.mjs --transcript`; `scripts/recall-sessions` (M2a Task 27) to list the pilot sessions; `scripts/lib/h2h.mjs` `redact`.
- Produces: the filled pilot record; `evals/heldout-pilot.json` (`[{ "owner": "<route>", "prompt": "<first prompt, redacted>" }]`), frozen by its sha256 in a test; `route-eval` reporting `pilot prompts rank-1 rate: <n>% (reported, no floor)`, so real prompts sit beside the synthetic ones without being tuned to pass.

- [ ] **Step 1: Prepare each project (with the user's yes for each file)**

For each pilot project:
1. Show the change to `.claude/settings.local.json` that adds `"superpowers@claude-plugins-official": false` under `enabledPlugins`, merged into the existing file without touching other keys. Write it only on yes.
2. Start Claude Code there with `claude --plugin-dir <kern repo>` and run `/kern:help setup`; it shows the draft `.claude/kern.local.yml` and the exclude lines and writes them only on yes.
3. Confirm `git status --porcelain` shows no new entry.

In cds-app-rewrite, `.claude/skills/commit` and `.claude/skills/self-review` exist, so kern defers those two jobs; that is expected and is design fixture 1.

- [ ] **Step 2: Run the tasks, following `docs/pilot.md` Protocol**

The user drives each session. For each task, append the task-log row the same day; for a side-by-side task, follow Protocol steps 1 to 7 and fill its results row only after the user has judged blind. Grade each kern-arm transcript with `node scripts/kernel-adherence.mjs --transcript <session.jsonl> --route <route>` and put the result in the Route taken column. Stop and report at once on any guard false negative, any write outside a worktree, or any outward action the user did not approve.

- [ ] **Step 3: Freeze the pilot prompts**

Write `evals/heldout-pilot.json` with the first prompt of every pilot task and the route the task needed (the user's call, not the route kern took), with names, paths and private terms replaced by neutral words; show it to the user before writing.

In `scripts/route-eval.mjs`, `evaluate()`, replace the held-out block (from the comment `// Held-out organic prompts (evals/heldout.json), frozen by a test: never reworded to pass.` through the line that pushes `held-out rank-1 rate ... is below the floor ...`) with:

```js
  // Held-out organic prompts (evals/heldout.json), and real first prompts from the M2b pilot
  // (evals/heldout-pilot.json, reported with no floor). Both are frozen by tests: never reworded to pass.
  const heldRate = (file) => {
    const hPath = join(root, 'evals', file);
    if (!existsSync(hPath)) return null;
    const held = JSON.parse(readFileSync(hPath, 'utf8'));
    let hits = 0;
    for (const h of held) {
      if (!owners.some((t) => ownerOf(t.name) === h.owner)) { errors.push(`${file}: no owner "${h.owner}" for "${h.prompt}"`); continue; }
      const r = rank(h.prompt, corpus);
      if (ownerOf(r[0].name) === h.owner && r[0].score > 0) hits++;
    }
    return held.length ? Math.floor((hits / held.length) * 100) : null;
  };
  const heldoutRate = heldRate('heldout.json');
  if (minHeldout != null && heldoutRate !== null && heldoutRate < minHeldout) errors.push(`held-out rank-1 rate ${heldoutRate}% is below the floor ${minHeldout}%`);
  const pilotRate = heldRate('heldout-pilot.json');
```

Return `pilotRate` beside `heldoutRate` (`return { errors, warnings, rank1Rate, heldoutRate, pilotRate };`), and after the CLI's held-out line add:

```js
  if (r.pilotRate !== null) console.log(`pilot prompts rank-1 rate: ${r.pilotRate}% (reported, no floor)`);
```

Append to `tests/route-eval-rows.test.mjs`:

```js
test('pilot prompts give a reported rate with no floor', () => {
  const pilot = JSON.stringify([{ owner: 'recall', prompt: 'where did I leave off after the gap' }, { owner: 'diagnose', prompt: 'catch me up' }]);
  const r = evaluate(fixture({ 'evals/heldout-pilot.json': pilot }), { minRank1: null, minHeldout: 90 });
  assert.equal(r.pilotRate, 50);
  assert.equal(r.heldoutRate, null);
  assert.deepEqual(r.errors, []);
});

test('the pilot prompts are frozen', () => {
  const sha = createHash('sha256').update(readFileSync(join(ROOT, 'evals', 'heldout-pilot.json'))).digest('hex');
  assert.equal(sha, '<sha256 of the file as written in this step>', 'evals/heldout-pilot.json is frozen: fix routing, never the prompts');
});
```

Fill the sha with `shasum -a 256 evals/heldout-pilot.json`, in the same commit that creates the file.

- [ ] **Step 4: Run the tests**

Run: `node --test tests/route-eval-rows.test.mjs && node scripts/route-eval.mjs`
Expected: `# fail 0` (the new test failed before the `route-eval.mjs` change: measured, `pilotRate` was `undefined`); route-eval prints the pilot line and passes.

- [ ] **Step 5: Decide**

Fill "Decision" in `docs/pilot.md` against the pass rule as agreed: wins and ties over the side-by-side tasks, any category lost outright, guard false negatives, the fixtures, and the median token ratio. Record the user's words.

- [ ] **Step 6: Commit**

```bash
git add -- docs/pilot.md evals/heldout-pilot.json scripts/route-eval.mjs tests/route-eval-rows.test.mjs
git commit -m "M2: record the pilot and freeze its prompts" -m "<the decision line: wins, ties, losses by category, false negatives, token ratio>"
```

---

### Task 12: Release 0.4.0 and the switch-off decision

**Files:**
- Modify: `CHANGELOG.md`, `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (through `scripts/release.mjs`), `docs/pilot.md` (switch-off record)

**Interfaces:**
- Consumes: every gate of Task 8 passed (or a fix task closed it), Task 9's test green, Task 11's decision.
- Produces: release 0.4.0; the switch-off steps of design spec 13.4, run only on the user's yes.

- [ ] **Step 1: Check the acceptance of design spec 14, row M2b**

Run: `scripts/ci-local && node --test tests/coverage.test.mjs`
Expected: `ci-local: all steps passed`; `# fail 0`. Then confirm from the committed snapshots and `docs/pilot.md`: each head-to-head category passed; no M2 coverage row is source-stronger; the standing cost is at most 1,300 tokens; the pilot passed by its own rule. If any does not hold, stop and report which; do not release.

- [ ] **Step 2: Release and commit**

Run: `node scripts/release.mjs minor`
It bumps both manifests to 0.4.0, moves `Unreleased` into the release section, and prints `git tag v0.4.0`.

```bash
git add -- .claude-plugin/plugin.json .claude-plugin/marketplace.json CHANGELOG.md
git commit -m "M2: release 0.4.0" -m "M2b acceptance: adherence, behaviour, head-to-head and standing-cost snapshots committed and passing; coverage re-audit green; pilot passed by the rule agreed before it ran."
```

Create the tag the release script printed. Pushing the commit and the tag waits for the user's yes.

- [ ] **Step 3: Ask about the switch-off**

Show the user `docs/pilot.md` "Switch-off" and ask whether to run it now. Run each step only on yes, one at a time, and record each in `docs/pilot.md` with the date. Step 3 of the list (moving `~/.claude/skills/recall` and `unslop` aside) is a move, not a delete: name the destination and confirm it first.

---

## Self-review

- Every M2b item of the goal-0 review, coverage gaps 10 and 13, and the review rulings on blinding, isolation and pass rules map to a task and a test in `docs/plans/2026-10-14-kern-m2-traceability.md`.
- Every script and test in Tasks 1 to 7 and 9 was run in a planning sandbox on the planned M2a tree: 43 behave, adherence, h2h and standing-cost tests passed with no model call (the h2h dry-run test skipped: the sandbox had no `.upstream`), each fixture test failed when its patch or fixture was broken, the coverage test failed then passed on a mock section, and the pilot-rate test failed before the `route-eval.mjs` change. No step that spends tokens was run.
- Measured while planning: `claude -p` 2.1.299 accepts `--max-turns` (hidden from `--help`), `--permission-mode acceptEdits` and `--allowedTools`; it rejects an unknown flag before any model call. Not yet measured: that a guard's ask is refused in a headless run with the tools pre-approved, and the `usage` field names of `--output-format json`; the first exec-eval and standing-cost runs check both.

## Tasks added during execution

(None yet. A task added during execution goes here with its reason, as in the M1 plan.)
