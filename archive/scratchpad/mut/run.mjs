import { readFileSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
const R = process.argv[2], pins = readFileSync(process.argv[3], 'utf8').trim().split('\n').map((l) => JSON.parse(l));
let killed = 0, survived = [], twice = [];
for (const [rel, n] of pins) {
  const p = `${R}/${rel}`, orig = readFileSync(p, 'utf8');
  const count = orig.split(n).length - 1;
  if (count !== 1) twice.push([rel, n, count]);
  const i = orig.indexOf(n);
  writeFileSync(p, orig.slice(0, i) + orig.slice(i + n.length));
  const test = rel.startsWith('skills/prove-it') ? 'tests/skills/prove-it.test.mjs' : 'tests/skills/finish-branch.test.mjs';
  let failed = false;
  try { execFileSync('node', ['--test', test], { cwd: R, stdio: 'pipe' }); } catch { failed = true; }
  writeFileSync(p, orig);
  if (failed) killed++; else survived.push([rel, n]);
}
console.log(`pins ${pins.length}, killed ${killed}, survived ${survived.length}`);
for (const s of survived) console.log('SURVIVED', JSON.stringify(s));
for (const t of twice) console.log('NOT ONCE', JSON.stringify(t));
