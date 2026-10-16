import { readFileSync, writeFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
const kc = process.argv[2];
const test = readFileSync(`${kc}/tests/skills/recall.test.mjs`, 'utf8');
const groups = [['skills/recall/SKILL.md','SKILL'],['skills/recall/references/chat.md','CHAT']];
let total=0, killed=0; const surv=[];
for (const [file,v] of groups) {
  const needles = [...test.matchAll(new RegExp(`assertOnce\\(${v}, (\\[[\\s\\S]*?\\])\\);`,'g'))].map(m=>eval(m[1])).flat();
  const orig = readFileSync(`${kc}/${file}`,'utf8');
  for (const n of needles) { total++;
    writeFileSync(`${kc}/${file}`, orig.replace(n,''));
    const r = spawnSync('node',['--test','tests/skills/recall.test.mjs'],{cwd:kc,encoding:'utf8'});
    if (r.status!==0) killed++; else surv.push(n);
  }
  writeFileSync(`${kc}/${file}`, orig);
}
console.log('pins',total,'killed',killed,'survived',surv.length,surv);
