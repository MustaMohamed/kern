// Prints the top 5 targets for each prompt, as route-eval ranks them.
import { join } from 'node:path';
const root = process.argv[2];
const { targets } = await import(join(root, 'scripts/route-eval.mjs'));
const { buildCorpus, rank, tokenize } = await import(join(root, 'scripts/lib/rank.mjs'));
const corpus = buildCorpus(targets(root));
for (const p of process.argv.slice(3)) {
  const r = rank(p, corpus);
  console.log(`${JSON.stringify(p)} tokens=${tokenize(p).join(',')}`);
  console.log('   ' + r.slice(0, 5).map((x, i) => `#${i + 1} ${x.name} ${x.score.toFixed(3)}`).join(' | '));
}
