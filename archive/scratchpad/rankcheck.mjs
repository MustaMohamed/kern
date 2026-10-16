import { readFileSync } from 'node:fs';
const root = process.argv[2];
const src = readFileSync(`${root}/scripts/route-eval.mjs`, 'utf8');
console.log(src.split('\n').filter(l => /import|corpus\s*=|buildCorpus|loadCorpus/.test(l)).slice(0, 8).join('\n'));
