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
