import { readFileSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
const kc = process.argv[2], rel = process.argv[3];
const orig = readFileSync(`${kc}/${rel}`, 'utf8');
const body = orig.replace(/^---[\s\S]*?\n---\n/, '');
const sents = [];
for (const line of body.split('\n')) {
  if (!line.trim() || line.startsWith('#') || line.startsWith('|---')) continue;
  const m = line.split(/(?<=[.:;])\s+(?=[A-Z`"(\[])/);
  for (const x of m) if (x.trim().length > 12) sents.push(x);
}
const surv = []; let killed = 0;
for (const x of sents) {
  if (orig.split(x).length !== 2) continue;
  writeFileSync(`${kc}/${rel}`, orig.replace(x, ''));
  const r = spawnSync('node', ['--test', 'tests/skills/recall.test.mjs'], { cwd: kc, encoding: 'utf8' });
  if (r.status !== 0) killed++; else surv.push(x);
}
writeFileSync(`${kc}/${rel}`, orig);
console.log(rel, 'total', sents.length, 'killed', killed, 'survived', surv.length);
for (const x of surv) console.log(' -', x.slice(0, 140));
