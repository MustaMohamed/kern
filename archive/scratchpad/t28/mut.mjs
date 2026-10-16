import { readFileSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
const dir = process.argv[2];
const f = dir + '/skills/recall/SKILL.md';
const orig = readFileSync(f, 'utf8');
// units: sentences within lines (split after ". " or ": " not needed) 
const units = [];
const lines = orig.split('\n');
lines.forEach((ln, i) => { if (!/^\d+\.|^- |^\|/.test(ln) && !ln.trim()) return;
  const parts = ln.split(/(?<=[.;]) (?=[A-Z`\[\x27"])/); if (parts.length > 1) parts.forEach(p => units.push([i, p])); });
let surv = [];
for (const [i, p] of units) {
  const ln = lines[i]; const out = ln.replace(' ' + p, '').replace(p + ' ', '');
  if (out === ln) continue;
  const nl = lines.slice(); nl[i] = out; writeFileSync(f, nl.join('\n'));
  const r = spawnSync('node', ['--test', dir + '/tests/skills/recall.test.mjs'], { cwd: dir });
  if (r.status === 0) surv.push(p);
}
writeFileSync(f, orig);
console.log('units', units.length, 'survivors', surv.length); surv.forEach(s => console.log('- ' + s.slice(0, 140)));
