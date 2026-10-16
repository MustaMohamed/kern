import { readFileSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
const kc = process.argv[2];
const test = readFileSync(`${kc}/tests/skills/recall.test.mjs`, 'utf8');
const arrays = [...test.matchAll(/assertOnce\(SKILL, (\[[\s\S]*?\])\);/g)].map((m) => eval(m[1]));
const needles = arrays.flat();
const orig = readFileSync(`${kc}/skills/recall/SKILL.md`, 'utf8');
let killed = 0; const survived = [];
for (const n of needles) {
  writeFileSync(`${kc}/skills/recall/SKILL.md`, orig.replace(n, ''));
  const r = spawnSync('node', ['--test', 'tests/skills/recall.test.mjs'], { cwd: kc, encoding: 'utf8' });
  if (r.status !== 0) killed++; else survived.push(n);
}
writeFileSync(`${kc}/skills/recall/SKILL.md`, orig);
console.log(`needles ${needles.length} killed ${killed} survived ${survived.length}`, survived);
