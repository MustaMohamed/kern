import { readFileSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
const R = process.argv[2];
const muts = [
  ['skills/finish-branch/SKILL.md', 'Bash(git status *), ', 'Bash(git status *), Bash(git fetch *), '],
  ['skills/finish-branch/SKILL.md', '9. Dedup, before any push or PR: `references/push-and-pr.md`, section Dedup.\n', ''],
  ['skills/finish-branch/SKILL.md', 'or autopilot is on. Otherwise stop.', 'or autopilot is on.'],
  ['skills/finish-branch/SKILL.md', 'A failure no step handles', 'A failure $(x) no step handles'],
  ['skills/finish-branch/references/push-and-pr.md', '## Push\n', '## Pushing\n'],
  ['skills/finish-branch/references/discard.md', '# Discard\n', ''],
  ['skills/finish-branch/references/branch-ops.md', 'Under autopilot only the check runs', 'Under autopilot only the check runs $(x)'],
  ['skills/finish-branch/references/push-and-pr.md', 'whatever `pr.dedup` says', 'whatever `pr.dedup` says $(x)'],
  ['skills/finish-branch/SKILL.md', 'Only a PR at this head stops.', 'Only a PR at this head stops. Only a PR at this head stops.'],
  ['skills/finish-branch/SKILL.md', '## Outputs\n', '## Output\n'],
];
let killed = 0;
for (const [rel, a, b] of muts) {
  const p = `${R}/${rel}`, orig = readFileSync(p, 'utf8');
  if (!orig.includes(a)) { console.log('NO MATCH', a); continue; }
  writeFileSync(p, orig.replace(a, b));
  let failed = false;
  try { execFileSync('node', ['--test', 'tests/skills/finish-branch.test.mjs'], { cwd: R, stdio: 'pipe' }); } catch { failed = true; }
  writeFileSync(p, orig);
  if (failed) killed++; else console.log('SURVIVED', rel, a);
}
console.log(`structural ${muts.length}, killed ${killed}`);
