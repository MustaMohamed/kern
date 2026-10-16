// Lists case positives that miss rank 1 and held-out prompts with their top target.
import { join } from 'node:path';
import { readFileSync, readdirSync } from 'node:fs';
const root = process.argv[2];
const { targets } = await import(join(root, 'scripts/route-eval.mjs'));
const { buildCorpus, rank } = await import(join(root, 'scripts/lib/rank.mjs'));
const corpus = buildCorpus(targets(root));
const ownerOf = (n) => n.replace(/^row-/, '');
let pos = 0, hit = 0;
for (const f of readdirSync(join(root, 'evals/cases'))) {
  const d = JSON.parse(readFileSync(join(root, 'evals/cases', f), 'utf8'));
  const exp = f.replace(/\.json$/, '');
  for (const p of d.trigger.positive) {
    pos++;
    const r = rank(p.prompt, corpus);
    const i = r.findIndex((x) => ownerOf(x.name) === ownerOf(exp));
    if (i === 0) hit++; else console.log(`miss ${exp} #${i + 1}: "${p.prompt}" top: ${r.slice(0, 2).map((x) => `${x.name} ${x.score.toFixed(3)}`).join(', ')}`);
  }
}
console.log(`positives ${hit}/${pos}`);
const held = JSON.parse(readFileSync(join(root, 'evals/heldout.json'), 'utf8'));
let h = 0;
for (const x of held) {
  const r = rank(x.prompt, corpus);
  const ok = ownerOf(r[0].name) === x.owner && r[0].score > 0;
  if (ok) h++;
  console.log(`${ok ? 'HIT ' : 'miss'} ${x.owner}: top ${r[0].name} ${r[0].score.toFixed(3)} | "${x.prompt}"`);
}
console.log(`held-out ${h}/${held.length}`);
