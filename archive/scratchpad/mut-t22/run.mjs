// Mutation check: remove each pinned string from its scope on a scratch copy; the test must fail.
import { readFileSync, writeFileSync, mkdirSync, cpSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
const K = process.argv[2], W = process.argv[3];
const copy = () => {
  rmSync(W, { recursive: true, force: true });
  for (const p of ['tests/helpers/md.mjs', 'scripts/lib/frontmatter.mjs', 'skills/execute-plan', 'tests/skills/execute-plan.test.mjs']) {
    mkdirSync(join(W, p, '..'), { recursive: true });
    cpSync(join(K, p), join(W, p), { recursive: true });
  }
};
const run = () => spawnSync('node', ['--test', join(W, 'tests/skills/execute-plan.test.mjs')], { encoding: 'utf8' }).status;
const testSrc = readFileSync(join(K, 'tests/skills/execute-plan.test.mjs'), 'utf8');
const at = testSrc.indexOf('export const PINS = {');
const block = testSrc.slice(at + 'export const PINS = '.length, testSrc.indexOf('\n};\n', at) + 2);
const PINS = new Function(`return ${block}`)();
const files = { skill: 'skills/execute-plan/SKILL.md', ledger: 'skills/execute-plan/references/ledger-format.md', resume: 'skills/execute-plan/references/resume.md' };
const src0 = Object.fromEntries(Object.entries(files).map(([k, p]) => [k, readFileSync(join(K, p), 'utf8')]));
const fileOf = (k) => (k === 'ledger' || k === 'resume' ? k : 'skill');
function scope(k, text) {
  const spans = []; let off = 0;
  for (const l of text.split('\n')) { spans.push([off, off + l.length, l]); off += l.length + 1; }
  const find = (pred) => { const x = spans.find(([, , l]) => pred(l)); return x ? [x[0], x[1]] : null; };
  if (k === 'intro') return [0, text.indexOf('## Steps')];
  if (k === 'stops') return [text.indexOf('## Stops and autopilot'), text.indexOf('## Red flags')];
  if (k === 'ledger' || k === 'resume') return [0, text.length];
  if (['step', 'inline', 'delegate'].includes(k)) return find((l) => l.startsWith(`   - \`${k}\``));
  return find((l) => l.startsWith(`${k}. `));
}
const tryFile = (f, content) => { copy(); writeFileSync(join(W, files[f]), content); return run(); };
let total = 0; const survived = [];
copy(); if (run() !== 0) { console.log('baseline fails on the copy'); process.exit(2); }
for (const [k, needles] of Object.entries(PINS)) {
  for (const n of needles) {
    total++;
    const f = fileOf(k), src = src0[f];
    const [a, b] = scope(k, src); const i = src.indexOf(n, a);
    if (i < 0 || i + n.length > b) { survived.push(`${k}: not found in scope: ${n}`); continue; }
    if (tryFile(f, src.slice(0, i) + src.slice(i + n.length)) === 0) survived.push(`${k}: ${n}`);
  }
}
const swaps = [
  ['delegate', 'Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/brief-check` on it; ', ' Pass no `isolation` parameter'],
  ['6', '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-start <ledger> <N> <tree-before>`', '`plan-check --files'],
  ['8', '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-review <ledger>', 'Dispatch `kern:task-reviewer`'],
  ['8', "Save its return as `<ledger dir>/reviews/task-N-r<r>.txt`, r = 1 + the task's review lines.", 'Dispatch `kern:task-reviewer`'],
  ['11', 'writing `Applied: Task N patch=<path>` after each `applied`', 'Apply each worker'],
  ['5', 'Then write `Worktree: <path> branch=<name> base-tree=<id>`, the id from `wt-snap`.', 'Exit 2: say why and ask.'],
];
for (const [k, piece, before] of swaps) {
  total++;
  const s = src0.skill; const [a] = scope(k, s); const i = s.indexOf(piece, a);
  let m = s.slice(0, i) + s.slice(i + piece.length);
  const j = m.indexOf(before, a); m = m.slice(0, j) + ' ' + piece + ' ' + m.slice(j);
  if (tryFile('skill', m) === 0) survived.push(`order ${k}: ${piece}`);
}
// Reintroduce the round-1 wording that made the checks once-only.
const reintro = [
  ['skill', 'Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <plan>`', 'Once, run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/plan-check <plan>`'],
  ['skill', 'A spec or scope conflict the graph does not show: stop and ask;', 'Once: a spec or scope conflict the graph does not show: stop and ask;'],
  ['resume', 'Steps 2 and 3 run again on every invocation and add only the lines the ledger lacks', 'Steps 2 and 3 ran already: rebuild only the todo list, and add only the lines the ledger lacks'],
];
for (const [f, from, to] of reintro) {
  total++;
  if (!src0[f].includes(from)) { survived.push(`reintro: not found: ${from}`); continue; }
  if (tryFile(f, src0[f].replace(from, to)) === 0) survived.push(`reintro: ${to}`);
}
console.log(`mutations: ${total}, survived: ${survived.length}`);
for (const x of survived) console.log('  survived: ' + x);
rmSync(W, { recursive: true, force: true });
