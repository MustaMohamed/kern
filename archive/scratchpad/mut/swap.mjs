import { readFileSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
const R = process.argv[2];
const SK = 'skills/finish-branch/SKILL.md', OPS = 'skills/finish-branch/references/branch-ops.md', PUSH = 'skills/finish-branch/references/push-and-pr.md', DISC = 'skills/finish-branch/references/discard.md', PI = 'skills/prove-it/SKILL.md';
const muts = [
  // I4 clauses: removal and swap of each
  [SK, 'propose a split; stop on yes, go on on no.', ''],
  [SK, 'stop on yes, go on on no', 'go on on yes, stop on no'],
  [SK, 'behind above 0 is stale', ''],
  [SK, 'behind above 0 is stale', 'behind above 5 is stale'],
  [SK, 'Option 1 ends with the short SHA.', ''],
  [SK, 'Option 1 ends with the short SHA.', 'Option 1 goes on to step 9.'],
  [PUSH, 'An open PR at an older head: push, report its URL, and open no new PR.', ''],
  [PUSH, 'An open PR at an older head: push, report its URL', 'An open PR at an older head: report its URL'],
  [PUSH, 'and open no new PR', 'and open a new PR'],
  [OPS, 'If not, run `git rev-parse HEAD`', ''],
  [OPS, 'If not, run `git rev-parse HEAD`', 'If so, run `git rev-parse HEAD`'],
  [SK, '`ready`: go on.', ''],
  [SK, '`ready`: go on.', '`ready`: stop.'],
  // I2 and other load-bearing outcomes
  [OPS, 'only on yes; on no, go on', 'only on yes; on no, stop'],
  [OPS, 'else G1 denies that push, so go on stale', 'else rebase anyway'],
  [PUSH, 'G1 asks when every commit past the base is the user\'s, else denies', 'G1 allows it'],
  [PUSH, 'so use the lease push', 'so stop'],
  [PUSH, 'Never a plain force.', 'Force if the lease fails.'],
  [SK, 'never a plain force', 'force it'],
  [OPS, 'Red: no push.', 'Red: push anyway.'],
  [OPS, 'under autopilot too, then wt-new again', 'then stop'],
  [DISC, 'never under autopilot', 'also under autopilot'],
  [DISC, 'for the user to type with the `!` prefix', 'and run them'],
  [PUSH, 'push, but open no PR', 'open a PR anyway'],
  [SK, 'the menu resolves to option 3, or the highest option step 7 left: commit, then the dedup check', 'the menu resolves to option 3 after the dedup check'],
  [PI, 'unless this run is already inside commit or finish-branch (each reaches prove-it at its proof step), ', ''],
  [SK, 'Bash(gh pr list *)', 'Bash(gh pr list *), Bash(git rev-list *)'],
];
let killed = 0;
for (const [rel, a, b] of muts) {
  const p = `${R}/${rel}`, orig = readFileSync(p, 'utf8');
  if (!orig.includes(a)) { console.log('NO MATCH', rel, a); continue; }
  writeFileSync(p, orig.replace(a, b));
  const test = rel.startsWith('skills/prove-it') ? 'tests/skills/prove-it.test.mjs' : 'tests/skills/finish-branch.test.mjs';
  let failed = false;
  try { execFileSync('node', ['--test', test], { cwd: R, stdio: 'pipe' }); } catch { failed = true; }
  writeFileSync(p, orig);
  if (failed) killed++; else console.log('SURVIVED', rel, a, '->', b);
}
console.log(`swap and removal ${muts.length}, killed ${killed}`);
