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
  assert.ok(r.length >= 60, `only ${r.length} M2 rows; the 2026-10-17 audit alone has 117 candidate rows whose counterpart is M2 work`);
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
    if (/^M2[ab]\b/.test(home)) assert.match(home, /\(shipped (?:in )?0\.[34]\.0\)/, `gap ${n} (${gap}) is homed in ${home} and not shipped`);
  }
});

test('every gap homed in M2b has its own re-audit row', () => {
  const mechs = rows(section('M2 re-audit')).map((r) => r[0]);
  for (const n of [10, 13, 35, 36, 37, 38, 39, 41, 42, 43, 45, 46, 47, 48, 49, 50, 51, 52, 54]) {
    assert.ok(mechs.some((m) => m.endsWith(`(gap ${n})`)), `no M2 re-audit row for gap ${n}`);
  }
});

test('the five silent drops from the goal-0 review have rows', () => {
  const mechs = rows(section('M2 re-audit')).map((r) => r[0].toLowerCase());
  for (const m of ['redirection signals', 'where grep stops', 'doubt theater', 'forensics proof rules', 'declined to judge']) {
    assert.ok(mechs.some((x) => x.includes(m)), `no M2 row for ${m}`);
  }
});
