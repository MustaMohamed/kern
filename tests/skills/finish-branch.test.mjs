// tests/skills/finish-branch.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readDoc, assertFrontmatter, h2s, steps, section, DEFER, assertHeadings, assertMaxBytes, assertContains } from '../helpers/md.mjs';

const SKILL = 'skills/finish-branch/SKILL.md';
const OPS = 'skills/finish-branch/references/branch-ops.md';
const PUSH = 'skills/finish-branch/references/push-and-pr.md';
const DISC = 'skills/finish-branch/references/discard.md';
const BODY = 'skills/finish-branch/references/pr-body.md';

// Each pin occurs exactly once in its file, so removing it fails the test. Pins are whole clauses,
// so a swapped condition or outcome inside one fails too.
function assertOnce(rel, needles) {
  assertContains(rel, needles);
  const { raw } = readDoc(rel);
  for (const n of needles) assert.equal(raw.split(n).length - 1, 1, `${rel}: pin occurs more than once: ${n}`);
}

function assertNoSubstitution(rel) {
  assert.ok(!readDoc(rel).raw.includes('$('), `${rel}: no command substitution in a prescribed command`);
}

test('finish-branch frontmatter', () => {
  assertFrontmatter(SKILL, {
    name: 'finish-branch',
    description: 'Finish a branch: verify, self-review, check base and size, then offer commit, push, draft PR or keep.',
    'disable-model-invocation': 'true',
    'allowed-tools': 'Bash(git rev-parse *), Bash(git symbolic-ref -q --short HEAD), Bash(gh pr list *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect *), Bash(gh pr checks *)',
  });
});

test('finish-branch sections, steps and red flags', () => {
  const { body } = readDoc(SKILL);
  assert.deepEqual(h2s(body), ['## Steps', '## Inputs', '## Outputs', '## Stops and autopilot', '## Red flags']);
  const s = steps(body);
  assert.equal(s.length, 12);
  assert.equal(s[0], DEFER);
  assert.equal(s[1], '1. Consent: the user typed `/kern:finish-branch` or asked for a push, PR, release, tag or version bump in this session, or autopilot is on. Otherwise stop. Asked to tag a merged release: `references/release.md`, section After the merge, instead of steps 2 to 11.');
  assertOnce(SKILL, ['A failure no step handles stops the run: report its output.',
    '`Worktree:` path', 'ls -t <dir>/*/ledger.md', '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir ledgers`', 'Run `cd <wt>` as its own call', 'git rev-parse --path-format=absolute --git-dir --git-common-dir',
    '`git symbolic-ref -q --short HEAD` prints the branch; exit 1 means detached:',
    'git switch -c <name>', 'in the main checkout, stop: kern never switches its branch', 'A protected branch: stop',
    'git remote get-url origin', 'git fetch origin <base>', '"base not refreshed"', 'git rev-list --left-right --count <baseref>...HEAD',
    'behind above 0 is stale: offer a rebase per `references/branch-ops.md`.',
    '${CLAUDE_PLUGIN_ROOT}/skills/prove-it/SKILL.md', '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>`', 'Red, or `wt-snap` failing: stop (a red under autopilot: below).',
    '${CLAUDE_PLUGIN_ROOT}/skills/self-review/SKILL.md', 'skip: no-comments ships in M3', '`fix first`, `split` or no verdict: stop', '`rebase first`: handle it as step 3\'s stale base', '`ready`: go on.',
    'git diff --shortstat <merge-base> <tree>', 'untracked files count', 'or a count above `pr.max_lines`', 'propose a split alone, no menu before it is answered; stop on yes, go on on no.',
    '1 `commit`; 2 `commit and push`; 3 `commit, push and open a draft PR`; 4 `keep`.',
    'Ask for the reply in those words: G5, G1 and G2 read them as this prompt\'s consent, while a digit gives none',
    'Then report each review that ran and its result',
    'run `gh pr checks <n>` (`<n>`: the PR number from its URL) once, with no wait: report its output, or why it could not run.', 'Leave out 2 and 3 with no remote or `push.policy: deny`, and 3 with `pr.policy: deny`',
    'typed word `discard`, per `references/discard.md`',
    'nothing to commit', 'steps 2 to 6 of `${CLAUDE_PLUGIN_ROOT}/skills/commit/SKILL.md`', 'its stops stop this skill', 'its proof is its own, apart from step 4\'s',
    'offer a rebase step 3 put off', 'Option 1 ends with the short SHA.',
    'Dedup, before any push or PR: `references/push-and-pr.md`, section Dedup', '`references/branch-ops.md`, section Proven tree, then `references/push-and-pr.md`, section Push',
    'Draft PR, for option 3: `references/push-and-pr.md`, section PR', 'the worktree stays',
    'never through AskUserQuestion', 'A G1 or G2 prompt is the confirmation; a declined prompt or a denial stops',
    'an `autopilot ON:` reminder or a `kern mode:` line with `autopilot=on`', "else the kernel's \"Autopilot:\" line",
    'every kern ask is a denial', 'nothing is rebased or discarded, no teardown runs but the stale-check removal in `references/branch-ops.md`',
    'the menu resolves to option 3, or the highest option step 7 left: commit, then the dedup check, then the push and PR',
    'parked: <question>; default: <choice>; why: <one line>', 'a stale base or `rebase first`: no rebase; go on', 'A failed fetch: the last fetched ref.',
    'The size gate or a `split` on size alone: go on, Scope giving the size', 'Dedup: per its section.', 'Stray untracked files can park the finish at commit\'s "no files, no commit" default.',
    'Any other stop waits for a typed reply. Off the end path below, a failed proven-tree check means no push.',
    '"Tests passed earlier this session"', 'Only a PR at this head stops.', 'Only the typed word `discard` deletes work.',
    'The remote moved, unless this run rebased. Investigate; never a plain force.',
    "whose what opens with size and that quotes the user's one-PR answer settles it: name that answer, the ledger's count and this step's count, and go on.",
    'Never `git add` to count, not even `-N`.']);
  assertNoSubstitution(SKILL);
  // 6,594 since M2b Task 17 (raised from 6,400): a release on request, the tag-only route and the release branch, coverage AD24.
  // 6,960 since the pilot fix plan's Task 2: the size gate's measure and pr.size_command.
  // 7,200 since pilot fix plan 2's Task 1: step 6 takes execute-plan's ledger answer and never stages to count.
  // 7,650 since pilot fix plan 2's Task 2: step 7's replies in words, step 11's reviews and PR checks.
  // 7,700 since group A fix round 1: step 6 names the ledger's count and this step's count, and step 11 says where `<n>` comes from.
  // 8,100 since M3 part 1's Task 7: the bounded fix round and how it ends.
  // 8,450 since its fix round 1: a red step 4 takes a fix round, and the end path names the gates it passes.
  // 8,500 since Task 8's fix round 1: the end path's open-task case, and step 2's caller.
  // 8,625 since Task 14 and its fix round 1: step 4 takes the tree before the proof, and step 8 compares option 1's tree with it,
  // after a red-flag cut.
  // 8,770 since Task 15: step 4 cites a passed `test.full` on its exact tree.
  // 8,848 since paid round 1's fix: step 6 greps the ledgers before it proposes a split.
  // 8,870 since its round 2: no ledger is no line.
  // 9,077 since M3 part 2 project 1's Task 18, audit row L491: step 3 asks once which base when the work's plan or
  // ledger, or an upstream, names another, and autopilot takes `base_branch`.
  // 9,187 since its fix round 1: step 3 names the plan's `base:` line and a ledger `Decision:` line, never the
  // ledger's `Main:` or `Worktree:` branch, and a missing plan or ledger names none.
  // 9,265 since M3 part 2 project 1's final review fix (I2): the end path names run.md's stops on a defect the ticket demands
  // and on a change it does not name.
  // 9,453 since M3 part 2 project 2's Task 5: step 11's single checks read is skipped under a go, which follows autopilot's
  // `references/ci.md` after step 11, its class 4 rebase the only one autopilot makes.
  assertMaxBytes(SKILL, 9453);
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', ['| `finish-branch` | slash | M2a | at most 9,453 bytes,',
    "SKILL.md at most 9,453 bytes (9,265 until M3 part 2 project 2's Task 5: ",
    "Under a go, after step 11, the run follows autopilot's `references/ci.md` to `gh pr ready` or a stop, its class 4 rebase the only one autopilot makes (M3 part 2 project 2 Task 5)."]);
});

test('under a go, finish-branch hands the open draft to the CI loop after step 11', () => {
  // M3 part 2 project 2 Task 5: a person's run keeps step 11's single checks read; a go waits on CI in autopilot's
  // `references/ci.md`, whose class 4 rebase is the one exception to "nothing is rebased".
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[11].includes('and, but under a go, run `gh pr checks <n>`'), s[11]);
  assertOnce(SKILL, ['Under a go, after step 11, follow ${CLAUDE_PLUGIN_ROOT}/skills/autopilot/references/ci.md to `gh pr ready` or a stop. Its class 4 rebase is the only one autopilot makes.']);
  const auto = section(readDoc(SKILL).body, '## Stops and autopilot').split('\n');
  assert.ok(auto.indexOf('Under autopilot, stops, unblocking and the run report follow ${CLAUDE_PLUGIN_ROOT}/skills/autopilot/references/run.md.') < auto.findIndex((l) => l.startsWith('Under a go, after step 11,')), 'the go line follows the run.md pointer');
});

test('the size gate greps the ledgers for the size decision before it proposes a split', () => {
  // Paid round 1, finish-size-decision: the run said "with no ledger" with the line on disk, because step 2's `ls -t` sits
  // inside a three-way choice. The form is the ledger's own: `Decision: size: one PR, "one PR", lines: 14`.
  const gate = steps(readDoc(SKILL).body)[6];
  // Re-review M2: with no ledger the glob matches nothing and grep exits 2, which line 10 would read as a stopping failure.
  const grep = gate.indexOf("run `grep -H '^Decision: [Ss]ize' <dir>/*/ledger.md` (`<dir>`: step 2's; no ledger is no line)");
  assert.ok(grep > 0, gate);
  assert.ok(grep < gate.indexOf('A `Decision:` line in the work\'s ledger'), gate);
  assert.ok(gate.indexOf('A `Decision:` line in the work\'s ledger') < gate.indexOf('Else propose a split alone'), gate);
});

test('under autopilot a `fix first` verdict starts a bounded fix round, and a run past the bound pushes and opens no PR', () => {
  const auto = section(readDoc(SKILL).body, '## Stops and autopilot');
  // Fix round 1, I2: run.md stops on a required check "still red after its fix rounds", so a red step 4 takes rounds too.
  for (const s of ['Under autopilot a red step 4, first pass or in a round, counts as `fix first`.',
    // Fix round 1, M4: a size `split` that hides a `fix first` is not a `split` on size alone.
    '`fix first`, or a size `split` that also reports it, starts a fix round, up to 3:',
    // A fix changes the tree, and step 6 sizes step 4's tree, so a round proves it again before the review.
    'fix the findings, then rerun step 4 and self-review in full.',
    // The first row of run.md's split table. The size row is a default, so it sits with the other defaults.
    'A `split` from a finding on a line the last round changed stops, and so does no verdict.',
    // Fix round 1, I1: the user's "Push allowed, and should Stop, PR should at least have a tested or verified the
    // changes". A red proof stopped commit and the Proven tree check, so the design's push never happened. M3 part 2 project 1's
    // final review, I2: run.md's demanded-defect and unnamed-change stops commit and push their branch as well.
    "The end path is a third round still `fix first`, a task still open at execute-plan's step 13, a required check that cannot run, or run.md's stop on a defect the ticket demands or on a change it does not name: the run commits its work, pushes its branch, reports each red or unrun check as `fail`, opens no PR and stops.",
    "A red or unrunnable proof stops neither commit's step 4 nor the Proven tree check there: the path claims nothing.",
    'A typed reply that says to open the PR opens it.']) assert.ok(auto.includes(s), s);
  assert.ok(!auto.includes('After the third round'), auto);
  assert.ok(!auto.includes('unrunnable proven-tree'), auto);
  // Fix round 1, I1: the push gate's own text names the end path, so a reader who follows step 10 there does not stop.
  // Fix round 2: wt-new exits non-zero when `worktree.setup` fails, so a check that cannot run lands on the other no-push
  // line. One sentence after both covers a red check and one that cannot run.
  const tree = section(readDoc(OPS).body, '## Proven tree');
  const end = "On finish-branch's end path neither no push holds: report `fail`, push.";
  assert.ok(tree.includes(`Red: no push. ${end}`), tree);
  assert.ok(tree.indexOf('Any other non-zero exit, or a refused remove: report its output and ask; no push.') < tree.indexOf(end), tree);
  assert.ok(steps(readDoc(SKILL).body)[5].includes('`fix first`, `split` or no verdict: stop with its report (autopilot: below).'));
  assertContains('skills/autopilot/references/run.md', ['| `split` from a finding on a line the last round changed |']);
});

test('option 1 compares its tree with step 4\'s and reports any difference as unproven (audit D13)', () => {
  // Option 1 pushes nothing, so step 10's check never proves the tree a step 8 rebase made. Task 14 review: nor one a commit
  // made: step 4 green on T, the proof wrote W, commit staged W, and only `verify.fast` ran on T plus W.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[8].includes('Then offer a rebase step 3 put off. A release,'), s[8]);
  assert.ok(s[8].endsWith("Option 1 ends with the short SHA. It compares `git rev-parse HEAD^{tree}` with step 4's tree and reports any difference, a rebase included, as unproven."), s[8]);
});

test('the proven tree is taken before the proof, and files the proof wrote are not proven (audit D14)', () => {
  // A snapshot after the proof counted what the proof wrote, so the Proven tree check saw no difference.
  const s4 = steps(readDoc(SKILL).body)[4];
  assert.ok(s4.startsWith('4. Record the proven tree with `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>`, then prove `test.full` here by following `${CLAUDE_PLUGIN_ROOT}/skills/prove-it/SKILL.md`; files the proof wrote are not proven.'), s4);
});

test('one passed test.full stands for its exact tree, in each step that would run it again', () => {
  // M3 part 1 Task 15: the design's "Full suite twice on one tree". The hard limit is the plan's: only a repeat of the same
  // proof on the same tree may go, so a run on any other tree stays.
  const rule = 'A `test.full` that passed on tree `<id>` in this run stands for that tree; a step that would rerun it on that tree cites the run. Runs on other trees stay.';
  const f = steps(readDoc(SKILL).body);
  assert.ok(f[4].includes(`files the proof wrote are not proven. ${rule} Red, or \`wt-snap\` failing: stop`), f[4]);
  assert.ok(steps(readDoc('skills/execute-plan/SKILL.md').body)[11].includes(rule));
  const imp = steps(readDoc('skills/implement/SKILL.md').body)[11];
  assert.ok(imp.includes(rule), imp);
  // `<id>` is taken before the run: a snapshot after it would count what the run wrote.
  assert.ok(imp.indexOf('take `<id>` with `wt-snap <wt>`') < imp.indexOf('run `test.full`'), imp);
  assert.ok(imp.indexOf('take `<id>` with `wt-snap <wt>`') >= 0, imp);
  const agent = readDoc('agents/implementer.md').body.split('\n').find((l) => l.startsWith('4. Method:')) ?? '';
  assert.ok(agent.includes(`run the full suite once at the end. ${rule}`), agent);
  // Fix round 1, I2: `<id>` in the report field had no reader, and a subagent's report is no such run.
  assertContains('agents/implementer.md', ['the full-suite command and its summary line;']);
  // The red flag and prove-it's rule still hold: a run proves only the tree it ran on, and a report is a claim.
  assertContains(SKILL, ['| "Tests passed earlier this session" | A run proves only the tree it ran on.']);
  assertContains('skills/prove-it/references/evidence.md', ['`<id>` is from `wt-snap` before that run; the citing step\'s `wt-snap` must match it.', "A subagent's report is no such run."]);
});

test('a cited test.full has a log a reader can check, and without it the run happens again', () => {
  // M3 part 1 Task 15 fix round 1, I2: the skip rested on memory. The log is the record, with no new ledger line.
  const e = readDoc('skills/prove-it/references/evidence.md').raw;
  for (const n of ["The main session saves that run's output as `test-full-<id>.log` under `kern-dir tmp`;", 'a citing step writes `skip: test.full, passed on <id>: <log>, <summary line>`.',
    // Fix round 2, N1: the log is keyed on the tree only and `kern-dir tmp` is never cleaned, so an old run's log would pass.
    'No log this session saved, or no passing summary line in it: rerun.']) assert.ok(e.includes(n), n);
  // execute-plan saves its run by a pointer, and finish-branch step 4 reaches the rule through prove-it, whose step 3 names the file.
  // Fix round 2, N6: the save happens during the run, so a cut-off call leaves its output too.
  const save = 'saving its output as `${CLAUDE_PLUGIN_ROOT}/skills/prove-it/references/evidence.md` says';
  assert.ok(steps(readDoc('skills/execute-plan/SKILL.md').body)[11].includes(`run \`test.full\` there, ${save}; red: stop.`));
  // Fix round 1, ruled in: a kernel-row run goes from implement to finish-branch, so its run saves the log too. Fix round 2, N2:
  // every worker follows implement too, and a worker's log in the main session's `kern-dir tmp` could stand at step 4.
  const imp = steps(readDoc('skills/implement/SKILL.md').body)[11];
  assert.ok(imp.includes(`run \`test.full\` (main session only: ${save}), and name every red test`), imp);
  assert.ok(steps(readDoc(SKILL).body)[4].includes('by following `${CLAUDE_PLUGIN_ROOT}/skills/prove-it/SKILL.md`'));
  assert.ok(steps(readDoc('skills/prove-it/SKILL.md').body)[3].includes('`references/evidence.md` says when a passed `test.full` stands.'));
});

test('under autopilot a stop waits for a typed reply, and only a judgment call that takes a default parks', () => {
  // Task 6 review: this route said a stop parks and run.md says a stop waits.
  const auto = section(readDoc(SKILL).body, '## Stops and autopilot');
  assert.ok(auto.includes('A judgment call parks as `parked: <question>; default: <choice>; why: <one line>`.'), auto);
  assert.ok(!auto.includes('A stop parks'), auto);
  assert.ok(!auto.includes('ends the run'), auto);
});

test('branch-ops reference: rebase and the proven-tree check', () => {
  assertHeadings(OPS, ['# Branch operations', '## Rebase', '## Proven tree']);
  assertOnce(OPS, ['Under autopilot only the Proven tree check runs, without its teardown; its removal of an earlier run\'s check path is not a teardown.',
    'If `git rev-parse --verify --quiet origin/<branch>` prints a SHA, the branch is published', 'warn that a rebase rewrites published commits and needs the lease push in `push-and-pr.md`',
    'offer it only if `git log --format=%ae <baseref>..HEAD origin/<branch>` prints only `git config user.email`; else G1 denies that push, so go on stale.',
    'Run `git rebase <baseref>` only on yes; on no, go on.', 'git refuses a rebase over uncommitted changes: offer it again after step 8\'s commit; refused again, go on.',
    'A rebase stopped by a conflict: run `git rebase --abort`, report the conflicting paths, and stop.',
    'After a rebase in step 3 or 5, rerun from step 4; after one in step 8, the check below proves the new tree (options 2 and 3).',
    '`git rev-parse HEAD^{tree}` must equal the tree from finish-branch step 4; commit\'s own proof is separate.',
    'If not, run `git rev-parse HEAD`, then', 'wt-new <slug>-check-<sha7> --detach --base <HEAD sha>', '`<sha7>`: the SHA\'s first 7 characters',
    'Exit 2 with `path exists` means an earlier run left that check: run plain `git worktree remove <path>`, under autopilot too, then wt-new again.',
    'Any other non-zero exit, or a refused remove: report its output and ask; no push.',
    'then `cd <wt>`', 'Red: no push.', 'If wt-new said `worktree.setup` is unset, a red may be the environment: check that before blaming the commit',
    'Then propose plain `git worktree remove <check>`, never `--force`, and run it on yes; a refusal keeps it, reported.']);
  assertNoSubstitution(OPS);
  // 2,450 since M3 part 1's Task 7 fix round 2: the end path passes both of the Proven tree check's no-push lines.
  assertMaxBytes(OPS, 2450);
});

test('discard reference', () => {
  assertHeadings(DISC, ['# Discard']);
  assertOnce(DISC, ['Only on the typed word `discard`, never under autopilot.', 'In the main checkout, discard stops',
    '`git worktree remove --force` never runs here', 'the first needing a `wt-apply`',
    'status --porcelain -uall --ignored', 'a remove deletes ignored files too', 'git log --oneline <baseref>..HEAD',
    'Run `git worktree remove <wt>`, then `git branch -D <branch>` (G1 asks), then `git worktree prune`', 'A refused remove stops; the worktree and branch stay.',
    'print `git worktree remove --force <wt>` and `git branch -D <branch>` for the user to type with the `!` prefix', 'remote branches and PRs stay']);
  assertNoSubstitution(DISC);
  assertMaxBytes(DISC, 2400);
});

test('push-and-pr reference: dedup, push, PR', () => {
  assertHeadings(PUSH, ['# Push and PR', '## Dedup', '## Push', '## PR']);
  assertOnce(PUSH, ['no `cd`, wrapper or expansion',
    'gh pr list --head <branch> --state all --json number,state,headRefOid,url', 'whatever `pr.dedup` says',
    'A PR counts only if its URL is this repo\'s (`git remote get-url origin`); check before reporting it.',
    'whose `headRefOid` is `git rev-parse HEAD`, in any state: report its URL and stop', 'An open PR at an older head: push, report its URL, and open no new PR.',
    'Only merged or closed PRs: push, then ask before a new PR', 'Autopilot parks with no PR', 'gh missing, logged out or failing: report its output; push, but open no PR.',
    'git push -u origin <branch>', 'Under `push.policy: ask` G1 asks', 'under `auto` or autopilot it allows this shape', '`deny` denies every push',
    'After this run\'s rebase of a published branch, push with `git push --force-with-lease origin <branch>` instead, as its own call',
    // M3 part 2 project 2 Task 5: a go's CI loop rebases and lease-pushes on a class 4 red, and marks the PR ready.
    'G1 asks when every commit past the base is the user\'s, else denies', 'Autopilot rebases and lease-pushes only in a go\'s CI loop.',
    'never `--no-verify`', 'A plain push rejected right after this run\'s rebase is that rebase: it rewrote published commits, so use the lease push.',
    'Any other rejection means the remote moved', 'git log --oneline HEAD..origin/<branch>', 'Never a plain force.',
    '`bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp`', '(exit 2: stop)', 'else `references/pr-body.md`',
    "gh pr create --draft --title '<subject per commit.convention>' --base <base> --body-file <dir>/pr-body.md",
    'no terminal can prompt for one', "write each `'` in it as `'\\''`",
    'A subject with a backtick, or a `$` before `(`, is reworded for the title without them',
    '`pr.policy` meets G2 as `push.policy` meets G1', 'only this draft shape, for a branch with no PR', '`gh pr ready` runs only in a go\'s CI loop',
    'say the branch is pushed and stop', 'never retry another shape']);
  // M2b Task 17 (P69 review, M1): a `pr.template` body still names a kept lowered bar, and autopilot's stale base,
  // under Merge danger. The cap rose from 2,400 by the 41 bytes left after cutting the title rule's ": G2 cannot check
  // those" (the spec's section 8 gives that reason).
  const pr = section(readDoc(PUSH).body, '## PR');
  const danger = 'A `pr.template` body still gets pr-body.md\'s Merge danger lines.';
  assertOnce(PUSH, [danger]);
  assert.ok(pr.indexOf('Write the body from `pr.template`, else `references/pr-body.md`') < pr.indexOf(danger) && pr.indexOf(danger) < pr.indexOf('gh pr create'), 'the clause sits with the body, before the gh command');
  assertNoSubstitution(PUSH);
  // 2,467 since M3 part 2 project 2's Task 5: autopilot rebases, lease-pushes and runs `gh pr ready` only in a go's CI loop.
  assertMaxBytes(PUSH, 2467);
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', ["`push-and-pr.md` at most 2,467 (2,441 until M3 part 2 project 2's Task 5: "]);
});

test('PR body template', () => {
  assertHeadings(BODY, ['# PR body', '## Why', '## What changed', '## Scope', '## Tradeoffs', '## Merge danger', '## Verification']);
  assertContains(BODY, ['drop a section with nothing to say', 'about 40 lines', 'smallest useful view', 'Screenshots first']);
  // M2b Task 17, coverage P69: a lowered bar self-review kept had no line in the body, so no reviewer saw it; only
  // the user's typed yes keeps one (tests/skills/self-review.test.mjs).
  const danger = section(readDoc(BODY).body, '## Merge danger');
  assert.ok(danger.includes('Name each `bar-lowered` change self-review kept, with the user\'s yes for it.'), danger);
  assertMaxBytes(BODY, 2000);
});

test('finish-branch reads the branch with symbolic-ref, where exit 1 means a detached HEAD', () => {
  assert.ok(!readDoc(SKILL).raw.includes('--abbrev-ref'), 'no rev-parse --abbrev-ref');
});

test('finish-branch: the size command runs every time, since its line count is what pr.max_lines reads', () => {
  const s = steps(readDoc(SKILL).body);
  assert.match(s[6], /^6\. Size gate: `git merge-base HEAD <baseref>`, then `git diff --shortstat <merge-base> <tree>` \(step 4's tree, so untracked files count\)\. Always run it, even after self-review listed the files: `pr\.max_lines` reads its line count\. /);
});

test('the PR body follows commit.attribution, a pr.template body too (coverage gap 54, audit D5)', () => {
  const rule = 'With `commit.attribution: none` (the default) neither body has a "Generated with Claude Code" footer or Co-Authored-By line, even if Claude Code asks: G2 denies one.';
  assertOnce(PUSH, [rule]);
  // The PR section names both bodies before the gh command, so a model writing from pr.template reads it.
  const pr = section(readDoc(PUSH).body, '## PR');
  assert.ok(pr.indexOf('Write the body from `pr.template`, else `references/pr-body.md`') < pr.indexOf(rule), 'the rule follows the sentence naming both bodies');
  assert.ok(pr.indexOf(rule) < pr.indexOf('gh pr create'), 'the rule comes before the gh command');
  assert.ok(!readDoc(BODY).raw.includes('attribution'), 'pr-body.md no longer holds the rule: only the no-template path read it there');
  assertContains('kernel/settings.md', ["Governs commit trailers and a PR body's attribution footer | pre-tool-use G2, G5, commit, finish-branch, autopilot |"]);
});

// Coverage AD24 (M2b Task 17, lane 4): addy's git-workflow-and-versioning versions anything with consumers by
// semver, makes an annotated tag the version's source of truth and writes the changelog for humans. kern
// cuts a release in finish-branch, where it already commits and pushes, and only when the user asks. Controller
// ruling (Task 17, before review): the tag goes only on a commit already on the base branch, never on a branch
// commit that a squash or rebase merge would replace, so the branch run stops at the release commit and a later
// tag-only request tags the commit it finds on the base.
const RELEASE = 'skills/finish-branch/references/release.md';

test('release reference: the project tooling first, a confirmed semver bump, a changelog for humans, one release commit, and the wait for the merge (coverage AD24)', () => {
  assertHeadings(RELEASE, ['# Release', '## On the branch', '## After the merge']);
  assertOnce(RELEASE, [
    // 1. The project's own tooling wins.
    "the project's own release tooling wins: a release script, changesets, semantic-release, or a release section in CONTRIBUTING or the README.",
    'Follow it, say which, and fill only its gaps; the confirm, the wait and the ask still hold.',
    // 2. The bump, by semver from the base's last tag (a stale branch would read an older one), confirmed by the
    // user; review M1 and M2: the first release has a number; review I2a, addy :284: unsure means breaking.
    '`git describe --tags --abbrev=0 <baseref>` gives the last tag, `git log --oneline <tag>..HEAD` the changes.',
    "No tag: a first release of every commit, numbered as the manifest says, else 0.1.0 or 1.0.0, the user's pick.",
    'a breaking change is major, a new feature minor, fixes only patch; below 1.0.0 a breaking change bumps minor; unsure whether it breaks: it does.',
    'State the bump with the change that sets it', 'the user confirms the number before anything is written',
    // 3. The changelog, for humans; review I2b, addy :311: an Unreleased section becomes the entry; review M6,
    // addy :299: all six groups.
    'Changelog, for humans: one dated entry under the version', 'an Unreleased section becomes it.',
    "Keep a Changelog's Added, Changed, Deprecated, Removed, Fixed, Security.",
    'breaking changes first, each with its migration step', 'never a commit-log dump',
    // 4. One release commit; review M6, addy :295: a version the tag sets stays as it is.
    'the version in every manifest that carries one (a placeholder the tag sets stays), plus the changelog entry',
    'one release commit', 'its subject naming the version',
    // 5. The tag never lands on a branch commit.
    'Wait: the release stops here, under any option.',
    'Never tag a branch commit: a squash or rebase merge replaces it.',
    "Report that the tag waits for the merge, with After the merge's commands filled in but for `<sha>`."]);
  // The branch steps tag nothing and push nothing: no tag command, no tag push.
  const branch = section(readDoc(RELEASE).body, '## On the branch');
  for (const cmd of ['git tag', 'git push']) assert.ok(!branch.includes(cmd), `On the branch holds no ${cmd}`);
  assert.ok(!/describe --tags --abbrev=0`/.test(branch), 'the describe reads the base, not the branch');
  // A release needs the user's number and an asked push, so autopilot parks all of it.
  assertOnce(RELEASE, ["Under autopilot none of this runs; it parks (why: the number and the tag push are the user's call)."]);
  const at = ['1. Tooling:', '2. Bump:', '3. Changelog,', '4. Commit:', '5. Wait:'].map((n) => branch.indexOf(n));
  assert.ok(at.every((i, k) => i >= 0 && (k === 0 || i > at[k - 1])), `branch steps in order: ${at}`);
  assertNoSubstitution(RELEASE);
  // 2,897 since review fix round 1 (raised from 2,400): the After the merge section and the review's fixes.
  assertMaxBytes(RELEASE, 2897);
});

test('release reference, After the merge: a tag-only request finds the release commit on the base by its subject, tags that SHA and asks the push (coverage AD24)', () => {
  const after = section(readDoc(RELEASE).body, '## After the merge');
  const pins = ['For a request to tag a merged release, in place of finish-branch steps 2 to 11.',
    // Review M4: tooling or CI that tags owns the tag.
    'Tooling or CI that tags wins: say so and stop.',
    // 1. The base, refreshed.
    '`git fetch origin <base>`, `<baseref>` being `origin/<base>`; with no remote, local `<base>`.',
    // 2. Found by subject, since a squash changes the SHA. Review I1: the oldest match, not the newest, since a later
    // commit (a stacked squash body) can carry the same subject; review M7: the subject quoted for the shell.
    'Find the release commit by its subject, since a squash changes the SHA:',
    "the first line of `git log --reverse -F --grep='<subject>' --format=%H <baseref>`, each `'` in the subject as `'\\''`.",
    // Review I1: the commit that set the version: it holds <x.y.z> and its parent does not.
    'Each version file (manifests, else the changelog) must hold `<x.y.z>` at `<sha>` and not at `<sha>^`.',
    'None found, or a mismatch: stop and report.',
    // Review M5: commits after the release commit are outside the tag; say which.
    'Name what the tag leaves out: `git log --oneline <sha>..<baseref>`.',
    // 3. The annotated tag on that SHA: no checkout, no branch switch; the source of truth, never moved.
    'git tag -a v<x.y.z> <sha> -m "<x.y.z>: <one line>"', 'never a lightweight tag', 'the line holds no `"`, `$` or backtick',
    "The SHA needs no checkout: kern never switches the main checkout's branch.",
    "The tag is the version's source of truth.", 'Never move or reuse a pushed tag; a bad release gets the next patch.',
    // 4. The asked push, never --tags; G1 asks under auto too (probed from a worktree and the main checkout).
    'pushing the tag publishes it, so it is asked like any push', '`git push origin v<x.y.z>` as its own call, never `--tags`.',
    'G1 asks for it even under `push.policy: auto`: that prompt is the ask.',
    // Review M3: with no remote there is no push; the tag stays local.
    'Declined, or with no remote, the tag stays local: report it.', 'Rejected: the remote has that tag; stop and report, never force it.'];
  for (const p of pins) assert.ok(after.includes(p), `After the merge must contain: ${p}`);
  assertOnce(RELEASE, pins);
  // `-1` limits before `--reverse` reverses, so it would give the newest match again (review I1).
  assert.ok(!/git log -1\b/.test(after), 'no git log -1 in the find');
  const at = ['1. Base:', '2. Find', '3. Tag:', '4. Push:'].map((n) => after.indexOf(n));
  assert.ok(at.every((i, k) => i >= 0 && (k === 0 || i > at[k - 1])), `after-merge steps in order: ${at}`);
});

test('branch-ops reference: a release asked on a protected branch gets a release branch (review I3, coverage AD24)', () => {
  assertHeadings(OPS, ['# Branch operations', '## Rebase', '## Proven tree', '## Release branch']);
  const rb = section(readDoc(OPS).body, '## Release branch');
  const pins = ['For a release asked on a protected branch, such as `<base>` (step 2 stops there): offer a release branch;',
    'on yes run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-new release`, `--base <sha>` of local `<base>` with no remote,',
    'then `cd` to the path it prints, as its own call.',
    // Self-review stops on an empty diff, so the release commit comes before step 2's run in the release branch.
    'There cut the release commit per `release.md`, section On the branch, then run finish-branch from step 2: step 5 reviews that commit, and step 8 has no release left.'];
  for (const p of pins) assert.ok(rb.includes(p), `Release branch must contain: ${p}`);
  assertOnce(OPS, pins);
  assertMaxBytes(OPS, 2450);
});

test('finish-branch: a release only when asked, after the commit; its tag only after the merge, by a tag-only request (coverage AD24)', () => {
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[1].includes('asked for a push, PR, release, tag or version bump in this session'), s[1]);
  const route = 'Asked to tag a merged release: `references/release.md`, section After the merge, instead of steps 2 to 11.';
  assert.ok(s[1].endsWith(`Otherwise stop. ${route}`), s[1]);
  const rel = 'A release, if asked: `references/release.md`.';
  // Review I3: a release of work already on the base would stop at step 2's protected branch with no way on.
  const relBranch = 'A protected branch: stop; ask which worktree; for a release, offer a release branch per `references/branch-ops.md`.';
  assertOnce(SKILL, [route, rel, relBranch]);
  assert.ok(s[2].endsWith(relBranch), s[2]);
  assert.ok(s[8].startsWith('8. Commit, for options 1 to 3:'), s[8]);
  assert.ok(s[8].indexOf('steps 2 to 6 of') < s[8].indexOf(rel) && s[8].indexOf(rel) < s[8].indexOf('Option 1 ends with the short SHA.'), 'the release follows the commit, in step 8');
  // No tag push in the branch run: step 10 pushes the branch only.
  assert.equal(s[10], '10. Push, for options 2 and 3: `references/branch-ops.md`, section Proven tree, then `references/push-and-pr.md`, section Push.');
  assert.ok(!/\btag\b/.test(s.slice(2).join('\n')), 'steps 2 to 11 name no tag');
  // Review M9: the outputs name the release.
  assert.equal(section(readDoc(SKILL).body, '## Outputs').trim(), 'A commit, push or draft PR, per the choice, or a release; a chat report: SHA, branch, PR URL, the reviews that ran, the PR checks, `<wt>`, the tag or its wait.');
  assertContains('tests/skills/finish-branch.acceptance.md', ['Asked for a release: the bump is stated with the change that sets it',
    'Asked to tag a merged release: the oldest commit on the base carrying the release subject',
    'Asked for a release on the base branch itself: a release branch is offered']);
  assertContains('skills/help/references/map.md', ["| `finish-branch` | slash | /kern:finish-branch; prove-it's gate for a push, PR or release | Verify, review, then commit, push, draft PR or keep; a release on request, tagged after the merge |"]);
});

test('finish-branch: the size gate names its measure, and pr.size_command replaces the shortstat count', () => {
  // Pilot fix plan Task 2 (MA-254): kern counted 641 insertions plus deletions with tests against the project's 317
  // added lines outside tests, and said neither measure.
  const s = steps(readDoc(SKILL).body);
  assert.ok(s[6].includes('The count is insertions plus deletions in every changed file, tests included; with `pr.size_command` set, run it in `<wt>` with `{base}` as `<merge-base>` and `{tree}` as `<tree>`'), s[6]);
  assert.ok(s[6].includes('(it fails or prints none: say so, keep the shortstat count). Name the count you compare, as `lines: <n> (<measure>)`.'), s[6]);
  assertContains(SKILL, ['| `scope_threshold`, `pr.max_lines`, `pr.size_command` | 4 files; 300 lines; none |']);
  assertContains('kernel/settings.md', ['| `pr.size_command` | none |', 'insertions plus deletions from `git diff --shortstat`, tests included']);
  assertContains('kernel/settings.md', ['tests included, or `pr.size_command`\'s count | plan, execute-plan, finish-branch, help |', '| execute-plan, finish-branch, help |']);
});

test('step 3 asks once which base when the plan, the ledger or an upstream names another; autopilot takes base_branch', () => {
  // M3 part 2 project 1 Task 18, audit row L491, after superpowers' finishing-a-development-branch Step 3: merging
  // into the wrong base is expensive to undo. A branch's own `origin/<branch>` names no other base, and no upstream
  // is no failure, so line 10 does not stop the run. `--abbrev-ref` stays out of this file (the symbolic-ref test above).
  // Fix round 1: no ledger line names a base but a `Decision:` line; the `Main:` line's branch is the main checkout's,
  // as recall step 7 found, so step 3 names its sources and rules those two out. A plan file the ledger names may be
  // gone (finish-size-decision's is), and a missing file names no base, so line 10 does not stop the run there either.
  const three = steps(readDoc(SKILL).body)[3];
  assert.ok(three.startsWith('3. Base: `<base>` is `base_branch`; when the plan\'s `base:` line, a ledger `Decision:` line or an upstream other than `origin/<branch>` (`git rev-parse --symbolic-full-name @{u}`; failing: none) names another, never the ledger\'s `Main:` or `Worktree:` branch, ask once which base; a missing plan or ledger names none. '), three);
  assert.ok(!three.includes("the work's plan or ledger"), 'the ledger as a whole is no base source');
  const auto = section(readDoc(SKILL).body, '## Stops and autopilot');
  assert.ok(auto.includes('A failed fetch: the last fetched ref. Another base named: `base_branch`.'), auto);
  assert.ok(auto.includes('A judgment call parks as `parked: <question>; default: <choice>; why: <one line>`. Defaults:'), 'the default is a parked judgment call');
});
