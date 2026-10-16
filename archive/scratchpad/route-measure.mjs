import { readFileSync } from 'node:fs';
import { buildCorpus, rank, similarity } from '/Users/musta/Code/projects/kern/scripts/lib/rank.mjs';
const K = '/Users/musta/Code/projects/kern';
const auto = {
  'prove-it': 'Use before saying work is done, fixed, passing or verified; before a commit, push or PR; and when a subagent reports success. Runs the proving command fresh, reads all output, checks each acceptance line, and labels other claims measured, inferred or guess.',
  recall: 'Use when starting or resuming work and state must be rebuilt first: "where did I leave off", "catch me up on X", "what remains", "I got lost in these PRs", a session after days away, or "recall chat" for this thread since my last message. Not for one named session.',
};
const rows = {
  define: 'New behaviour and no agreed spec', plan: 'Agreed spec, more than one step', 'execute-plan': 'Executing an agreed plan',
  implement: 'One bounded change with an agreed design', diagnose: 'Bug, failing test, unexpected output',
  'prove-it': 'About to say done, fixed or passing, commit, or open a PR', 'self-review': 'Review requested on your own diff, no PR yet',
  recall: 'Starting or resuming after a gap', 'technical-writing': 'Prose others read: PR body, issue, doc, commit message',
  context: 'Phase ends, or context is filling',
};
const distractors = JSON.parse(readFileSync(`${K}/evals/distractors.json`, 'utf8'));
const all = [
  ...Object.entries(auto).map(([name, text]) => ({ name, text, kind: 'skill' })),
  ...Object.entries(rows).map(([r, text]) => ({ name: `row-${r}`, text, kind: 'row' })),
  ...distractors.map((d) => ({ name: d.name, text: d.description, kind: 'distractor' })),
];
const corpus = buildCorpus(all);
const owner = (n) => n.replace(/^row-/, '');
const cases = JSON.parse(readFileSync(process.argv[2], 'utf8'));
let pos = 0, r1 = 0; const errors = [];
for (const [name, c] of Object.entries(cases)) {
  for (const p of c.pos) { pos++; const r = rank(p, corpus); const i = r.findIndex((x) => owner(x.name) === owner(name));
    if (i === 0 && r[0].score > 0) r1++;
    if (!r[i] || r[i].score === 0) errors.push(`${name}: no vocab "${p}"`); else if (i >= 3) errors.push(`${name}: #${i + 1} "${p}" top ${r.slice(0,3).map(x=>x.name).join(',')}`);
    else if (i > 0) console.log(`note ${name}: #${i+1} "${p}" top ${r[0].name}`); }
  for (const n of c.neg) { const r = rank(n, corpus); if (owner(r[0].name) === owner(name) && r[0].score > 0) errors.push(`${name}: #1 for negative "${n}"`); }
}
const owners = all.filter((t) => t.kind !== 'distractor');
for (let i = 0; i < owners.length; i++) for (let j = i + 1; j < all.length; j++) {
  const a = owners[i].name, b = all[j].name; if (owner(a) === owner(b)) continue;
  const s = similarity(a, b, corpus); if (s >= 0.5) console.log(`overlap ${a} ${b} ${(s*100).toFixed(0)}%`);
}
console.log(`case rank-1: ${Math.floor(r1 / pos * 100)}% (${r1}/${pos})`); for (const e of errors) console.log('error:', e);
if (process.argv[3]) {
  const held = JSON.parse(readFileSync(process.argv[3], 'utf8'));
  let h = 0; for (const x of held) { const r = rank(x.prompt, corpus); const ok = owner(r[0].name) === x.owner && r[0].score > 0; if (ok) h++; else console.log(`heldout miss: ${x.owner} <- "${x.prompt}" top ${r.slice(0,2).map(y=>y.name+' '+y.score.toFixed(2)).join(', ')}`); }
  console.log(`heldout rank-1: ${Math.floor(h / held.length * 100)}% (${h}/${held.length})`);
}
