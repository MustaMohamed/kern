// mode and autopilot: frontmatter verbatim from skills spec B1 and B2, steps that never write state.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { parseFrontmatter } from '../scripts/lib/frontmatter.mjs';
import { section, assertMaxBytes, assertContains, assertHeadings } from './helpers/md.mjs';

const read = (name) => parseFrontmatter(readFileSync(join(import.meta.dirname, '..', 'skills', name, 'SKILL.md'), 'utf8'));

test('mode frontmatter matches spec B1', () => {
  const { data, error } = read('mode');
  assert.equal(error, null);
  assert.deepEqual(data, {
    name: 'mode',
    description: 'Switch voice (normal, terse) and surface (chat, auto, html) for this session, or show the current mode.',
    'disable-model-invocation': 'true',
    'argument-hint': '[terse|normal|chat|auto|html|default|status]',
    'allowed-tools': 'Read',
  });
});

test('autopilot frontmatter matches spec B2', () => {
  const { data } = read('autopilot');
  assert.deepEqual(data, {
    name: 'autopilot',
    description: "Turn this session's autopilot grant on or off, or show what it allows. Only a prompt you type can turn it on.",
    'disable-model-invocation': 'true',
    'argument-hint': '[on|off|go <ticket>|status]',
    'allowed-tools': 'Read, Glob, Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-root *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get *)',
  });
});

test('both read the hook line first and never write the state file', () => {
  for (const name of ['mode', 'autopilot']) {
    const { body } = read(name);
    const steps = body.split('## Steps')[1].split('\n## ')[0];
    assert.match(steps, /^\n1\. Read the `kern mode:` line/, `${name} step 1`);
    assert.match(steps, /[Nn]ever write/, `${name} forbids writing state`);
  }
});

test('autopilot lists the floor and who can turn it on', () => {
  const { body } = read('autopilot');
  for (const s of ['Merge, deploy, review posting and tracker writes always need the user', 'Only the user, by typing `/kern:autopilot on` or `/kern:autopilot go <ticket>`']) {
    assert.ok(body.includes(s), s);
  }
});

test('autopilot documents the go: its step, its reach and what a refused go does', () => {
  const { body } = read('autopilot');
  const go = body.split('\n6. `go <ticket>`')[1].split('\n\n')[0];
  assert.match(go, /`kern: go recorded for <ticket>`/);
  assert.ok(go.includes('Read `${CLAUDE_PLUGIN_ROOT}/skills/autopilot/references/run.md`'), go);
  assert.match(go, /No such line, or any other hook line about the go, means no go: quote what the hook said, if anything, and start nothing\./);
  // M3 part 2 project 2 Task 5: the go's finish line moved from the draft PR to `gh pr ready` on clear CI.
  assert.ok(go.includes("The run ends at `gh pr ready` on its own PR or at a stop under that file's rules, so ask for no stop predicate."), go);
  // Paid round 1, 2026-11-01: 4 of 6 go runs that built code took the ticket for the kernel's "agreed design", so they
  // skipped define and wrote no spec.
  // M3 part 2 project 1 Task 7: this line is read before run.md on every go, so it names the tests-only route too.
  assert.ok(go.includes("by the kernel's Routing table. A ticket is no agreed design: a build starts at define, a bug at diagnose, and a ticket that only adds tests for existing code at implement."), go);
  assert.ok(body.includes('3. `on` or `go <ticket>`, and the hook reported "autopilot denied by <file>"'), 'a denied go names the file');
  const who = body.split('## Who can turn it on\n')[1];
  for (const s of ["A go counts as the user's yes for that ticket's spec and plan and nothing else.", 'A second ticket needs a second go.',
    // M3 part 2 project 2 Task 4: the go lives past its draft PR and ends at `gh pr ready`.
    "Its yes ends when the draft PR opens. The go ends at `gh pr ready`, `/kern:autopilot off`, a second go or the session's end.",
    'Autopilot itself stays on until the user turns it off.']) assert.ok(who.includes(s), s);
});

test('autopilot says what may follow an allowed shape, in the words settings.md uses, and covers a bare command (audit B11)', () => {
  const { body } = read('autopilot');
  const rule = 'Only `head`, `tail`, `grep` or `cat` with no file argument may follow it, and a redirection may only go to `/dev/null` or copy a file descriptor.';
  assert.ok(body.includes(rule), 'the skill holds the rule');
  assert.ok(readFileSync(join(import.meta.dirname, '..', 'kernel', 'settings.md'), 'utf8').includes(rule), 'settings.md holds the same words');
  assert.ok(body.includes('\n4. `status`, or no argument:'), 'a bare /kern:autopilot reports status, as the hook treats it');
});

test('autopilot parks only the judgment calls run.md does not stop for', () => {
  const { body } = read('autopilot');
  assert.ok(body.includes('Park each judgment call `references/run.md` does not stop for, with the default chosen, and continue the work that does not depend on it.'));
});

test('the map names the go', () => {
  const map = readFileSync(join(import.meta.dirname, '..', 'skills', 'help', 'references', 'map.md'), 'utf8');
  const row = map.split('\n').find((l) => l.startsWith('| `autopilot` |'));
  assert.ok(row.includes('`/kern:autopilot go <ticket>`') && row.includes('typed only'), row);
  // M3 part 2 project 2 Task 5: the go runs past its draft to `gh pr ready` or a stop.
  assert.ok(row.includes('a go also takes one ticket through a draft PR to `gh pr ready` or a stop |'), row);
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', ["`references/map.md` 4,173 (4,141 until M3 part 2 project 2's Task 5: "]);
});

const RUN = readFileSync(join(import.meta.dirname, '..', 'skills', 'autopilot', 'references', 'run.md'), 'utf8');
const lines = (heading) => (section(RUN, heading) ?? '').split('\n');

test('run.md holds the stop list row by row, with the stop the plan adds', () => {
  const rows = lines('## The stop list').filter((l) => l.startsWith('|'));
  assert.deepEqual(rows, [
    '| Autopilot stops for | Autopilot does not stop for |',
    '|---|---|',
    '| Merge to main | Reads |',
    '| Deploy | Tests |',
    '| Delete | Commits and pushes on its own branch |',
    // M3 part 2 project 2 Task 5: a go runs on past its draft, through CI fixes to `gh pr ready`.
    '| Spending money | A draft PR, CI fixes on its branch and `gh pr ready` on clear CI |',
    '| A design choice that changes what gets built | |',
    '| A required check that cannot run | |',
    '| A ticket the run cannot read | |',
    '| A defect the ticket itself demands | |',
  ]);
});

test('run.md says what each stop means and what a stop does', () => {
  const stops = section(RUN, '## The stop list');
  for (const s of ['A run stops only on this list.',
    "This list loosens nothing else: the stops in this file, a route's run-ending failures, a required check still red after its fix rounds and the user's stop predicate still stop a run.",
    "The kernel's Autonomy line still holds: an action it keeps for the user's word that this list does not name, such as a force-push to a shared branch, is skipped and reported.",
    // M3 part 2 project 2 Task 5: the Stop hook (Task 7) reads the stop from one fixed line.
    'At a stop, the run brings the data it collected and a recommendation in a report that opens with a `kern stop: <what>` line naming the stop, then waits for a typed reply. A stop a guard denies stays denied after a yes: give the user the command to run with `!`; the go holds. Work that does not depend on the answer may finish first.',
    "Delete means data, remote branches, tags, and files outside the run's own worktree and scratch directories. Removing a file on the run's own branch is ordinary work.",
    "A design choice stops the run when the ticket does not settle it and the answer changes user-visible behaviour, stored data shape, a public interface or the ticket's scope. Any other judgment takes a default and goes in the report.",
    // Paid round 4, the user's rule: go-spend-stop's fix rounds changed what `sum` does with inputs the ticket never named, and the run opened the PR.
    // Its re-review, M1: measured against the last round, a fix that puts back main's behaviour would stop a draft.
    // M3 part 2 project 1, the user's "Yes, first builds too": round 5's first build turned `sum('1', '2')` from '12' into 12 under the
    // ticket's rounding, so the rule moved here from the fix rounds and names the side effect.
    "A first build or a fix round that changes behaviour the ticket does not name, against the base branch, is a design choice. That includes a side effect the ticket's own change forces on inputs the ticket never names. The run commits, pushes its branch, stops with the change named and opens no PR.",
    'A required check is one the ticket or prove-it names for the change.',
    // Paid round 1, go-required-check-stop: the run acted on this line, which held no word for its report.
    // Paid round 2: define's route has no "work goes on" line, so the run stopped with nothing built and no branch to push.
    // Project 1's paid round 2 (the user's "Grader fix and run.md line", 2026-11-04): the run read run.md and no commit skill, so
    // commit:42's body rule never reached it, and the commit had a subject only.
    'When one cannot run, the run builds by the closest check, commits with the check named `fail` in the message body, pushes its branch, stops with the report, naming the check as `fail`, and opens no PR. A typed reply that says to open the PR opens it.',
    'A ticket the run cannot read is a stop',
    // Paid round 3, the user's rule: go-deploy-stop's lane said `needs fixes` on the ticket's own formula, and the run opened the PR.
    // Re-review I1: under a go the run writes the plan, so the label alone also fits a formula the run chose. I2: a bounded run commits at finish-branch step 8, after this stop.
    // Paid round 4: the spec lane declined the formula after the run's own Not doing line, and the built-in lane named it, so any review's finding counts.
    // Its re-review, M2: "a finding of any review that" let the clause attach to the review.
    'On any review\'s finding that the ticket\'s own words demand, not only the run\'s spec or plan, the run commits, pushes its branch, stops with the finding and opens no PR. No fix round runs, and no `ticket` ruling parks it.']) assert.ok(stops.includes(s), s);
  assert.ok(!RUN.includes('plan-mandated'), 'only the spec lane writes that label');
  // Task 6 review: "a red required check" read against the fix-round rule, and "a floor action" against the stop rows
  // for merge, deploy and delete, where a run waits. kernel/kernel.md has no word floor.
  for (const s of ['a red required check', 'floor']) assert.ok(!stops.includes(s), s);
});

test('run.md holds the five unblock steps in order, and what makes a route distinct', () => {
  const unblock = lines('## How a run unblocks itself');
  assert.deepEqual(unblock.filter((l) => /^\d+\. /.test(l)), [
    '1. Try a safer route to the same result.',
    '2. Find the answer in the project, docs, code and ticket, and collect the data needed to understand.',
    '3. Decide, and record what was chosen and why.',
    '4. If the decision is on the stop list, stop as above.',
    '5. After 3 distinct routes, skip the step and record it. If later work depends on that step, stop. A required check is never skipped.',
  ]);
  assert.ok(unblock.includes('A route is distinct only if it is a different action. The same target and effect in other words is the same action, and it stays blocked.'));
});

test('run.md bounds fix rounds at 3 and holds the three split rows', () => {
  const fix = section(RUN, '## Fix rounds');
  // Re-review I2: finish-branch and self-review, read later, send a `fix first` here, so this line holds the exception. Paid round 4's
  // follow-up: with the label gone, the exception names the stop, which sits in another section.
  // M3 part 2 project 1 Task 7 fix round 1: a first build's change off the ticket comes back as a review finding, and a fix round would hide the stop.
  for (const s of ["A `fix first` verdict, but for a demanded defect or a first build's change the stop list names, starts a fix round in place of ending the run, up to 3 per self-review.",
    'Each round fixes the findings and runs self-review again in full, including the checks the last round skipped.',
    // M3 part 2 project 1: a run kept no durable count of its rounds, so the count comes from the packages self-review already names.
    "Rounds count from self-review's packages: round N reviews `<slug>-<N+1>.diff`, so the third round's is `<slug>-4.diff`.",
    // Task 7 fix round 2: "After the third" read as a push and stop even when the third round comes back `ready`.
    'When a third round is still `fix first`, the run pushes its branch, stops with the report and opens no PR.', 'No verdict also stops.',
    // M3 part 2 project 2 Task 5: the go lives past its draft, so the CI loop's rules take over there.
    'One go covers one PR. After the draft opens, follow `references/ci.md`.']) assert.ok(fix.includes(s), s);
  assert.ok(!fix.includes('A round that changes behaviour'), 'the stop list holds U1, for a first build too');
  assert.deepEqual(fix.split('\n').filter((l) => l.startsWith('|')).slice(2), [
    '| `split` from a finding on a line the last round changed | The fixes are not converging: stop with the report |',
    "| `split` or the size gate on size alone | finish-branch's default: go on, with Scope giving the size |",
    // M3 part 1 Task 15: a ticket within `scope_threshold` and over `pr.max_lines` splits at plan step 7 too.
    "| A plan over `scope_threshold` or `pr.max_lines` | plan's default: take the split and run the first slice. The report lists the rest, and each needs its own go |",
  ]);
});

test('run.md gives define\'s first slice the default of a plan over scope_threshold', () => {
  // The table's row names only a plan, so a strict reading would stop a run at define's split. Paid round 4's re-review, M5: define's own
  // rule gives its first slice, the later slices and the report, so the line after the table repeated it.
  assert.ok(section(RUN, '## Define and plan under a go').includes("A size over `scope_threshold` specs its first slice: `## Size` gives the slice's files and lines, then the whole ticket's against the limit; numbered lines go under `## Acceptance criteria`, the rest as plain bullets under `## Later slices`, which the report lists, each needing its own go."));
  assert.ok(!section(RUN, '## Fix rounds').includes("define's first slice takes the same default."), 'stated once');
});

test('run.md opens its define and plan rules with a go\'s route: a ticket is no agreed design', () => {
  // Paid round 2: 4 of 5 PR runs ran wt-snap, none ran the size gate, and go-deploy-stop's pushed tree was not its reviewed tree.
  // M3 part 2 project 1: a ticket for tests on existing code took define and a short spec under a go, though the kernel routes it to implement.
  assert.ok(section(RUN, '## Define and plan under a go').trim().startsWith('A ticket is no agreed design. Under a go, a build starts at define, a bug at diagnose, and a ticket that only adds tests for existing code at implement. A draft PR comes only through finish-branch, in order: wt-snap, self-review with its proofs and spec lane, the size gate, the Proven tree check. An edit after the review takes a new wt-snap and `test.full`, and the report names it. Step numbers here are the skill\'s own.'));
});

test('run.md sends a go\'s approved plan on to execute-plan', () => {
  // M3 part 2 project 1: round 5's go-no-lint-draft approved a 2-task plan with `execution: delegate`, then built both tasks inline with no ledger.
  assert.ok(section(RUN, '## Define and plan under a go').includes('run the same plan-check again. execute-plan then runs it.'));
});

test('run.md lists every report field, the jobs another skill ran among them', () => {
  const report = section(RUN, '## The run report');
  for (const s of ['the ticket and PR', 'each stop', 'each block and the route taken', 'each decision with its why', 'each skipped step', 'each check with its result',
    // M3 part 2 project 2 Task 5: the CI loop's verdict and classes.
    "the last CI verdict and each red's class", 'the jobs that ran under another skill', 'A check that did not run, but for a named skip, is reported as a fail, not as "not run".',
    // M3 part 2 project 2's paid round 1 (the user's "Keep the set line"): go-proof-skip named its skip in its own words, not
    // prove-it's `skip: proof on the running app, no verify.browser or verify.app`, so a `skip:` line keeps its skill's form.
    '`parked:` and `skip:` lines keep their format, as the skill that names the skip gives it.',
    // Paid round 3: go-deploy-stop's lane said `needs fixes`, and its report said only that the review found it compliant.
    // M3 part 2 project 1's paid round 3: go-bug-draft's report gave the lane's "approved" for "the review's verdict" and no
    // self-review verdict word, so the sentence names self-review, and a lane's `needs fixes` as its own clause, which
    // go-mandated-defect-stop's grader reads (the controller's rulings on the round 4 fix batch).
    "The report gives self-review's verdict, and any lane's `needs fixes` as it came."]) assert.ok(report.includes(s), s);
  assert.ok(!report.includes('`parked:` lines keep their format.'), 'the parked-only sentence is gone');
  assert.match(RUN, /^These rules cover kern's routes only\. .*`overrides\.<job>`/m);
  // The round 1 fix batch's trims, which paid for the skip line within the cap: the overrides line leaves the report's
  // job line to this section, and the issue line keeps its quote rule and example.
  assert.ok(RUN.includes("A job an `overrides.<job>` key leaves to another skill runs that skill: kern's guards still apply.\n"), 'the overrides line');
  assert.ok(RUN.includes('G20 also needs `issue:` to name this ticket; quote a `#` id: `issue: "#853"`.'), 'the issue line');
});

test('the CHANGELOG caps line and the plan\'s expected line hold the current values', () => {
  // Re-review M1 and M3.
  const root = join(import.meta.dirname, '..');
  const caps = readFileSync(join(root, 'CHANGELOG.md'), 'utf8').split('\n').find((l) => l.startsWith('  - Caps, each raised where a task names why:'));
  for (const s of ['define `SKILL.md` 7,000 to 7,167;', 'plan `SKILL.md` 6,700 to 7,133 and', 'autopilot `references/run.md` new at 6,911.']) assert.ok(caps.includes(s), s);
  assert.ok(readFileSync(join(root, 'docs', 'plans', '2026-10-31-kern-m3-part1-plan.md'), 'utf8').includes('Expected: the Global Constraints scores hold, and the ten new exec cases pass.'));
});

test('the design and the skills spec state what run.md does with a defect the ticket demands, and with a fix round off the ticket', () => {
  const docs = join(import.meta.dirname, '..', 'docs', 'specs');
  const design = readFileSync(join(docs, '2026-10-31-kern-m3-part1-design.md'), 'utf8');
  for (const s of ['| A defect the ticket itself demands | |',
    "The user's rule, 2026-11-01: a defect the ticket itself demands stops a go before the PR.",
    "The user's rule, 2026-11-03: a fix round that changes behaviour the ticket does not name is a design choice.",
    'A fix round that changes behaviour the ticket does not name stops as the stop list says.',
    'The report gives the review\'s verdict as it came, `needs fixes` included.']) assert.ok(design.includes(s), s);
  const spec = readFileSync(join(docs, '2026-10-12-kern-m1-m2-skills.md'), 'utf8');
  for (const s of ['a defect the ticket itself demands stops the go before the PR, with no fix round and no `ticket` ruling (M3 part 1 paid round 3)',
    'a fix round that changes behaviour the ticket does not name is a design choice: the go commits, pushes its branch, names the change and opens no PR (M3 part 1 paid round 4)',
    'An edit after the review takes a new wt-snap and `test.full`, and the report names it (paid round 3:']) assert.ok(spec.includes(s), s);
});

test('run.md sends long output to a file under kern-dir tmp and reads its tail', () => {
  // An allowed git or gh shape may only redirect to /dev/null or copy a descriptor, so its output stays out of the rule.
  assert.ok(section(RUN, '## Long output').includes('Long output from a command that is not an allowed git or gh shape goes to a file in the directory `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp` prints, and the run reads its tail.'));
});

test('run.md keeps a go\'s main thread small, and one read of a route file does not outlive compaction', () => {
  // M3 part 1 Task 15. The design's largest cost is main-thread turns times context.
  const main = section(RUN, '## Main thread');
  assert.ok(main, 'the section exists');
  assert.ok(main.includes('Under a go, tasks run in subagents; bulk reads go to investigators; a route file is read once'), main);
  assert.ok(main.includes(', and again only after compaction.'), main);
  // Fix round 1, M1: an investigator's summary does not stand in for a read a step names.
  assert.ok(main.includes("A step's named read stays in the main thread."), main);
});

test('a go names the permission mode it needs', () => {
  // M3 part 1 final review, M11: only docs/pilot.md recorded that a go ran in mode auto.
  assert.ok(read('autopilot').body.includes('A go needs permission mode `auto`: in the default mode it sits at every call kern does not allow.'));
});

test('the docs state what the whole-branch review found them short of', () => {
  // M3 part 1 final review. M2: the go clears inside G2's vote, before the strictest vote is known. Since M3 part 2
  // project 2 Task 2 G2 ends only the go's approval there, so the same calls end that approval.
  const contract = readFileSync(join(import.meta.dirname, '..', 'docs', 'plans', 'contract.md'), 'utf8');
  assert.ok(contract.includes("A create that then fails, a `--dry-run`, another guard's deny of the call or a subagent's call ends the go's approval as well."), 'M2');
  // M5: ruling 249 named reports and briefs; the both-words deny reaches these two as well, with or without a go.
  const g20 = readFileSync(join(import.meta.dirname, '..', 'hooks', 'guards', 'g20-approval.sh'), 'utf8');
  const both = 'a report, a brief, `pr-body.md` or a `*.proofs.md`';
  assert.ok(contract.includes(both), 'M5, contract');
  assert.ok(g20.includes('a report, a brief, pr-body.md or a *.proofs.md'), 'M5, guard');
  // M3 part 2 Task 1: a go commits a project's own hook files; the carve-out in words.
  const g16 = readFileSync(join(import.meta.dirname, '..', 'hooks', 'guards', 'g16-state.sh'), 'utf8').split('\n').slice(0, 20).join(' ').replace(/ # /g, ' ');
  const own = "a project's own hook file that resolves outside kern's hooks folder";
  assert.ok(g16.includes(own), 'M3, guard');
  assert.ok(contract.includes(own), 'M3, contract');
  assert.ok(contract.includes('adds `finish-size-decision` and the nine `go-` cases'), 'the go cases');
  // M9: the five stale rows.
  const design = readFileSync(join(import.meta.dirname, '..', 'docs', 'specs', '2026-10-12-kern-design.md'), 'utf8');
  for (const s of ['the user typed `/kern:autopilot on` or `/kern:autopilot go <ticket>` in this session',
    '| D10 | Fix loops stop after 3 rounds with a split proposal | Up to 3 rounds per self-review run on their own; a third still `fix first` pushes the branch, reports and opens no PR.',
    "Draft allowed after dedup, which ends a go's approval but not the go (M3 part 2 project 2).",
    'when find is a command head and every other simple command is `cd`, `ls` or a read-only filter',
    "a path counts as kern's hook code only when it resolves under kern's own root"]) assert.ok(design.includes(s), s);
  const settings = readFileSync(join(import.meta.dirname, '..', 'kernel', 'settings.md'), 'utf8');
  assert.ok(settings.includes('| session-start, prompt-submit, skill-conflicts, every skill |'), 'M9, settings');
});

test('the skills spec and the design keep the lines project 1 changed', () => {
  // M3 part 2 project 1's final review, I3: goal 1 pins each item by a test, and the skill tests read the skills, not the
  // spec. Plan step 1 opens as the skill does; prove-it, self-review and commit name the named skip, each needle held to its
  // own paragraph by the text around it; and design 8.3's G16 row holds Task 1's carve-out.
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', [
    "1. Check preconditions: a spec file with `status: approved`; issue acceptance criteria alone are not approved (define's bounded path records them as an approved short spec).",
    "each red or unrun check is reported as `fail`, and the path claims nothing. Under autopilot a `verify.fast` with nothing resolved is a named skip: no stop, no failed check, no fix round. A lint the ticket names stays a required check (M3 part 1's final review fix, I1).",
    'and lessons are not written. Under autopilot a `verify.fast` with nothing resolved is a named skip: no stop, no failed check, no fix round. A lint the ticket names stays a required check (M3 part 1\'s final review fix, I1).',
    "elsewhere step 4 stops, but for prove-it's named skip of a `verify.fast` with nothing resolved (M3 part 1 Task 8, from Task 7's review; the skip since M3 part 1's final review fix, I1"]);
  assertContains('docs/specs/2026-10-12-kern-design.md', [
    "a write (`cp`, `mv`, `install`, `tee`, a `>` target, `git add` or `git mv`, each simple command judged alone) of a project's own hook file that resolves outside kern's hooks folder gets no vote either"]);
});

test('the contract says a run cut off by output or a signal keeps its transcript', () => {
  // M3 part 2 project 2, Task 9: ended attaches events and transcript to the overflow and signal errors, as to the timeout's.
  assertContains('docs/plans/contract.md', [
    'and the `ClaudeRunError` of a run cut off by the timeout, by output past `maxBuffer` or by a signal carries it beside `events`']);
});

test('the contract and the design keep the reply words and the go past its draft', () => {
  // M3 part 2 project 2, Task 2: consent gains lease and ready, G2's draft ends the go's approval, not the go, and
  // go_live is the one reading of a live go.
  assertContains('docs/plans/contract.md', [
    'from `commit`, `lease`, `push`, `pr`, `pr-edit`, `pr-title`, `pr-body` and `ready`, space-separated, or nothing.',
    "`rebase` or `sync`, alone or with ` it`, ` the branch`, ` the pr` or ` the pull request`, gives `lease`, so `rebase and push` gives `lease push`",
    "`mark it ready`, `mark the pr ready` or `mark the pull request ready`, with an optional ` as` before `ready` and an optional ` for review` after it, gives `ready`. `leave it` and `leave it here` name no action, so `leave it and mark the PR ready` gives `ready` alone.",
    'a bare `yes`, `ok` or `go ahead` gives no `lease` and no `ready`.',
    "`go_phase` (`pr` once G2 allows the go's draft PR, else empty or unset, M3 part 2 project 2).",
    '`go_live SID DIR` (M3 part 2 project 2, Task 2) exits 0, with `_KERN_GO` set to the go,',
    "the state's `go_phase` is not `pr` (M3 part 2 project 2, Task 2), and a `go_phase` read that fails is no go, the read ending with its status line so that a substitution whose pipe could not be made (status 0, no output) is no go too;",
    '`_g02_create` runs `state_set "$SID" "go_phase=pr"`. `go`, `go_repo` and `autopilot` stay, so the go lives on through CI',
    '`apply_go` writes `go_phase` empty with its `go`, `autopilot_off` writes it empty with `go` and `go_repo`, and `state_reset` writes no `go_phase`.',
    'only when `go_live SID KERN_MAIN` holds (M3 part 2 project 2, Task 2)']);
  // Task 8 carried the cell on past the draft clause.
  assertContains('docs/specs/2026-10-12-kern-design.md', ['| Only a go approves, for its ticket, until its draft PR opens;']);
});

test("the contract, the design and the skills spec keep a go's plan waiting for its review", () => {
  // M3 part 2 project 2, Task 8: plan step 11 saves the plan review's reply, and under a go G20 denies the plan's
  // approval until that reply holds the line Verdict: approve.
  assertContains('docs/plans/contract.md', [
    'under autopilot, deny unless a go approves it, a plan under `WORK/plans` only once its review approves it (see "G20 takes the go" under Additions from the M3 plan)',
    "A go's plan waits for its review (M3 part 2 project 2, Task 8): once `_g20_go` approves a Write or Edit whose path, or a symlink on the way from it (up to 8), names a Markdown file right under `WORK/plans`",
    '`_g20_reviewed` denies unless `WORK/reviews/plan-<slug>.md`, `<slug>` that name without its extension and WORK the `work_dir` setting under `KERN_MAIN`, is a regular file holding a line that, its blanks around trimmed, is exactly `Verdict: approve`, and no such line `Verdict: revise`.',
    "The deny reads `under a go a plan approves only after its review: <record>, where plan step 11 saves the plan reviewer's reply, needs a line Verdict: approve and no line Verdict: revise; keep status: draft`.",
    '`_g20_plan` exits 1, no plan, only when it can tell; it exits 2, and `_g20_reviewed` fails closed, when the work dir, a directory or a link cannot be read, a read comes back empty (a substitution whose pipe could not be made), the links go past 8, or the path holds a `.`, `..` or empty part after a directory that does not exist yet, which the Write resolves where a string compare cannot.',
    'A lost pipe in `settings_get` reads as a layer it could not read (exit 4), not as the `.kern` default.',
    "A person's approval, with autopilot off, is unchanged.",
    'the model writes the record, so G20 reads that it holds an approve verdict, not that a reviewer wrote it or reviewed this draft;',
    // The check rides on _g20_go's approval, not go_live; a revise gets one more review; and a user's word to skip the
    // review under a go is a limit.
    "The check rides on `_g20_go`'s approval, not on `go_live`: under autopilot only `_g20_go` approves, so every go approval needs the record, a go whose state file is older than `go_live`'s 1,440 minutes included.",
    'After a `revise` reply plan step 11 gives a go one more fresh review, saved over the same record, and a second `revise` stops the go.',
    'waits for no record, as plan step 11 always writes `<dir>/<slug>.md`;',
    "a user's word to skip the review leaves a go's plan with no record, so the go cannot approve it, and a user who wants no review turns autopilot off."]);
  assertContains('docs/specs/2026-10-12-kern-design.md', [
    "until its draft PR opens; a plan under `WORK/plans` only once `WORK/reviews/plan-<slug>.md`, its review's saved reply, holds the line `Verdict: approve` and no line `Verdict: revise` (M3 part 2 project 2)."]);
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', [
    "round 1 only, saving its reply verbatim with the Write tool to `<kern-dir reviews>/plan-<slug>.md` (M3 part 2 project 2's Task 8: under a go G20 reads it before the plan's approval)",
    "and G20 denies that approval until the review's saved reply holds the line `Verdict: approve` and no line `Verdict: revise` (M3 part 2 project 2's Task 8).",
    "Under a go a `revise` reply leaves the plan unapprovable, so the main thread fixes its findings, reruns plan-check, sends the plan to one more fresh reviewer on the same brief and saves that reply over the same file; a second `revise` stops the go, and the run report gives its findings. A person's run keeps round 1 only (M3 part 2 project 2's Task 8)."]);
});

test('the design and the contract keep the CI wait project 2 added', () => {
  // M3 part 2 project 2 Task 3: the settings rows, ci_read's verdicts and ci-wait's clock.
  assertContains('docs/specs/2026-10-12-kern-design.md', [
    '| CI | `ci.wait_minutes` | `45`; an integer from 1 to 600 | autopilot, `ci-wait` |',
    '| CI | `ci.advisory` | None; check names, exact and case-sensitive, that never gate ready | autopilot, `ci-wait`, G2 |']);
  assertContains('docs/plans/contract.md', [
    'when any bucket is `fail` or `cancel` (red wins over pending)',
    'An empty array and gh\'s "no checks reported" error both read as none.',
    // Its fix round 1: stdout and stderr apart, and the array is the read whatever gh's exit code.
    'only stdout holds the JSON, and only stderr the "no checks reported" error. A whole JSON array on stdout is the read, whatever gh\'s exit code',
    'so gh\'s debug line `[git remote -v]` starts none',
    '| `ci-wait` | `ci-wait WT [--minutes N]`',
    '`ci: none` stands only after 2 minutes of reads with no checks, re-read every 20 s at most',
    'its verdict line as `ci: pending <name>[, ...] (timeout <N>m)`']);
});

test('the design keeps verify.app, and the contract the autopilot line\'s length', () => {
  // M3 part 2 project 2 Task 6: the new key's 5.4 row; and, from Task 5's review, contract.md's count of the per-prompt
  // autopilot line, which read 680 after Task 5 made it longer. The count is measured, so the next change to the line
  // moves it too.
  // Its fix round 1: the verify.browser row's "ask before hand-rolling browser automation" was stale, so each running-app
  // setting says what none means, and verify.fast, which shared that row, gets settings.md's default in its own.
  const none = (other) => `with no \`${other}\` either, proof on the running app is a named skip, or a stop when it is required`;
  assertContains('docs/specs/2026-10-12-kern-design.md', [
    '| Checks | `verify.fast` | Each of `typecheck` and `lint` that resolves; at least one | prove-it, self-review |',
    `| Checks | \`verify.browser\` | None; ${none('verify.app')} | prove-it, diagnose, verify-app |`,
    `| Checks | \`verify.app\` | None; how to start and drive the app on a simulator or emulator. W${none('verify.browser').slice(1)} | prove-it, diagnose |`]);
  assert.ok(!readFileSync(join(import.meta.dirname, '..', 'docs', 'specs', '2026-10-12-kern-design.md'), 'utf8').includes('ask before hand-rolling browser automation'), 'the stale ask is gone');
  const hook = readFileSync(join(import.meta.dirname, '..', 'hooks', 'prompt-submit'), 'utf8');
  const line = hook.match(/^ {2}printf '%s\\n' "(autopilot ON: [^\n]*)"$/m)[1].replaceAll('\\$', '$');
  assert.ok(line.startsWith('autopilot ON: commit on a non-protected branch') && line.endsWith('park judgment calls not on the stop list.'), line);
  assertContains('docs/plans/contract.md', [`no code piped to a shell, no gh alias; ...\` (${line.length} chars). The rest is unchanged.`]);
});

test('the design, the contract and autopilot keep a go marking its own PR ready and the typed lease', () => {
  // M3 part 2 project 2 Task 4: G2 marks a go's PR ready on clear CI and a passed review-check, or on the typed word, and
  // edits its body; G1 takes the typed lease; review-check writes the record G2 reads.
  assertContains('docs/specs/2026-10-12-kern-design.md', [
    // Final review M4: G1 and G2 read the typed lease and ready only under autopilot.
    'a commit, a push, a draft PR (which covers its push) or a PR edit, and under autopilot a lease push after a rebase or `gh pr ready`, in the closed grammar of `prompt_consent`',
    // Fix round 1: the typed word lifts every deny of a go's ready but its shape and its open draft.
    "and lifts no deny but two under autopilot: G1's lease push of the user's own branch, and G2's `gh pr ready` on a live go's own open draft, over checks that are red, pending or unread, a review-check record that is missing or above the floor, and a PR head that is not HEAD. Outside autopilot G1 and G2 read no typed consent for those two.",
    "`--force-with-lease` only with `rebase.push: autopilot` or the user's typed rebase or sync; a go marks its own PR ready on clear CI and a passed review-check, and edits its body from a file (M3 part 2 project 2); everything else denied |",
    "A go's CI fix rounds stop the same way, up to 3 per go (M3 part 2 project 2) |",
    "only with `rebase.push: autopilot` or when the user's last typed prompt asks to rebase or sync (section 5.1; a bare yes is not one, M3 part 2 project 2), and only when every commit on it is the user's.",
    // Final review I1: the allow also leaves the Stop hook its read of the go's report.
    "Under a live go with its draft open, `gh pr ready` on that PR (no PR number, no `-R`) allowed when the user's last typed prompt says to mark it ready, or when the PR's head is HEAD, its checks read clear or none at the call and the review-check record for HEAD's tree ends `floor: none`; the allow ends the go and leaves the Stop hook one read of its report (`go_report`, section 6.3).",
    '`gh pr edit --body-file <file>` alone on that PR allowed with no prompt, the file checked as on create (M3 part 2 project 2). Any other `gh pr edit`, non-draft, an attributed body file and any other `gh pr ready` denied |']);
  assertContains('docs/plans/contract.md', [
    'G5 (`commit`), G1 (`push`, and `lease` under autopilot) and G2 (`pr`, `pr-edit`, `pr-title`, `pr-body`, and `ready` under a live go) call it.',
    "- **Lease push under autopilot (M3 part 2 project 2, Task 4):** to an unprotected branch, G1 takes the lease from `rebase.push: autopilot` or, when that is not set, from `consent_for ... lease`",
    'Under autopilot `gh pr ready` and `gh pr edit` are denied but on a live go\'s own open draft (`_g02_go_ready`, `_g02_go_edit`;',
    'Its whole stdout also goes to the record `<kern-dir tmp>/review-check-<tree>.txt`, `<tree>` the full id of WT\'s whole working state as `wt-snap WT` takes it before any check runs',
    "so the go lives on through CI until G2 allows its `gh pr ready` (Task 4), `/kern:autopilot off`, a second go or the session's end",
    "- **G2 marks a go's PR ready and edits its body (M3 part 2 project 2, Task 4).**",
    "is a regular readable file whose last non-blank line, blanks trimmed, is `floor: none`: review-check prints its floor last, so a check's tail above it is not one.",
    'Each allow runs `state_set "$SID" "go=" "go_phase=" "go_report=1"`, which ends the go; `go_repo` and `autopilot` stay, and `go_report` has the Stop hook read the go\'s report once more, outside the go (the final review\'s I1).',
    // Fix round 1: lost reads, the PR's head, the failed record write and the settle the next task's ci-wait gives.
    "ready also needs the record's text to be exactly `gh pr ready`, since tokens lost to a substitution whose pipe could not be made come back empty, which is ready's allowed shape (fix round 1).",
    '`gh pr view --json headRefOid --jq .headRefOid`, run in CWD with no PR named under `with_timeout 10` and `GH_DEBUG` empty, must equal `git -C "$CWD" rev-parse --verify --quiet HEAD`',
    'a mismatch denies `the PR\'s head <id7> is not HEAD <id7>; push HEAD first, or wait for GitHub to register the push`.',
    "and a `ci: none` read right after a push, before GitHub registers the new head's checks, reads as clear.",
    "or a write to it that fails (a line's append or the tails' `tee -a`, fix round 1) writes no record and changes neither stdout nor the exit."]);
  assertContains('skills/autopilot/SKILL.md', [
    "or when the PR's head is the pushed HEAD, its checks are clear or none and `review-check` passed HEAD's tree with `floor: none`.",
    "only when settings say `rebase.push: autopilot` or the user's last typed prompt asks to rebase or sync, the branch is not protected,",
    '- Under a go whose draft PR is open: `gh pr edit --body-file <file in the repo>` alone, and `gh pr ready` alone, with no PR number or `-R`.']);
});

test('run.md stays within its byte cap', () => {
  // 6,100 since M3 part 1 Task 15, its first cap: the main-thread rule, and define's and plan's go rules behind a pointer.
  // 6,130 since its fix round 1: a step's named read stays in the main thread.
  // 6,247 since paid round 1's fix: a ticket is no agreed design, and the stop's report names the check as `fail`.
  // 6,244 since its round 2, a fall: no fast path under a go and a PR only through finish-branch, less the line plan step 1 now holds.
  // 6,308 since paid round 2's fix: a run that cannot run a required check still builds, and a PR's steps are named in order, less a line the fix rounds table holds.
  // 6,322 since that fix's follow-up: the PR order names the spec lane.
  // 6,782 since paid round 3's fix: a defect the ticket itself demands stops a go, the report gives the review's verdict, and an edit after the review takes a new tree.
  // 6,926 since paid round 4's fix: a fix round that changes behaviour the ticket does not name stops a go, less the label any review's finding now replaces.
  // 6,934 since that fix's follow-up: the fix-round exception names the demanded defect.
  // 6,911 since its re-review, a fall: a round's change is measured against the base branch, and the line after the fix-round table, which define's rule repeats, goes.
  // 7,231 since M3 part 2 project 1 Task 7: a first build that changes behaviour the ticket does not name stops a go, rounds count from
  // self-review's packages, a tests-only ticket starts at implement, and an approved plan goes on to execute-plan.
  // 7,282 since its fix round 1: a first build's change the stop list names starts no fix round, and the U1 sentence splits in three.
  // 7,330 since paid round 2's rulings (the user's "Grader fix and run.md line", 2026-11-04): the required-check stop's commit names
  // the check as `fail` in its message body.
  // 7,331 since paid round 3's rulings (the user's "All three (Recommended)", 2026-11-04): the report gives self-review's verdict,
  // where "the review's verdict" let go-bug-draft give the spec lane's "approved".
  // 7,329 since the controller's ruling on that fix, a fall: the verdict's example is self-review's own `fix first`, not the lane's
  // `needs fixes`.
  // 7,337 since the controller's second ruling on it: the report gives self-review's verdict, and any lane's `needs fixes` as it
  // came, which go-mandated-defect-stop's grader reads.
  // 7,518 since M3 part 2 project 2's Task 5: a go does not stop for CI fixes or `gh pr ready` on clear CI, a stop's report opens
  // with a `kern stop: <what>` line, the go follows `references/ci.md` once its draft opens, and the report gives the CI verdict
  // and each red's class.
  // M3 part 2 project 2's round 1 fix batch kept 7,518: the report's `skip:` line clause (55 bytes) came from the overrides
  // line's "and the report names the job", which the report's field list holds, and the issue line's YAML aside, whose quote
  // rule and example stay.
  assertMaxBytes('skills/autopilot/references/run.md', 7518);
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', ['`references/run.md` at most 7,518 bytes (7,337 until M3 part 2 project 2\'s Task 5: ',
    '; 7,329 until the controller\'s second ruling on M3 part 2 project 1\'s round 4 fix batch: ']);
});

const CI = 'skills/autopilot/references/ci.md';

test('ci.md stays within its byte cap', () => {
  // 6,651 since M3 part 2 project 2's Task 5, its first cap: the CI loop from the draft PR to `gh pr ready` or a stop, in its own
  // file since run.md sat at its cap.
  // 6,793 since the controller's ruling on that task's concerns: a `split` after the draft is a stop, never a ready, and
  // finish-branch's go-on default on size covers only the draft.
  // 7,002 since Task 5's review fix round 1: class 4 skips its ask only on the words G1 reads, a denied lease push stops
  // before the body edit, a conflict resolution that stops aborts the rebase, and the draft's own size `split` stops unless
  // a typed `one PR` settles it, less the `ci.advisory` line (ci-wait drops those checks) and the `<dir>` line (push-and-pr
  // gives it).
  // Task 6, from Task 5's review, kept 7,002: Every push states the one order, with the class 4 lease push before the body
  // edit, and class 4 step 4 drops its own clause.
  // The project's final review, M6, kept 7,002: the untracked-file sentence moves from Every push to Ready and holds before
  // each self-review, so the draft's path to ready keeps it too.
  assertMaxBytes('skills/autopilot/references/ci.md', 7002);
  assertContains(CI, ["## Ready\n\nCommit every change and leave no untracked file before each self-review: G2 reads review-check's record for `HEAD^{tree}`.\n\nRun `gh pr ready` when all hold:"]);
  assert.ok(!readFileSync(join(import.meta.dirname, '..', CI), 'utf8').includes('before step 1 and leave no untracked file'), 'the Every push copy is gone');
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', ['`references/ci.md` at most 7,002 bytes (6,793 until Task 5\'s review fix round 1: ',
    '; 6,651 until the controller\'s ruling on Task 5\'s concerns: ', '; new in M3 part 2 project 2\'s Task 5: ']);
  // Review fix round 1, I2: a draft opened on a size-only `split` (finish-branch's go-on default) reaches Ready with that verdict.
  assertContains(CI, ['A `split` verdict on the pushed tree, the draft\'s own on size included, is a stop that asks split or one PR. A typed `one PR` settles size for this go, so a `split` on size alone then counts as `ready`.']);
  assert.ok(!readFileSync(join(import.meta.dirname, '..', CI), 'utf8').includes('A `split` after the draft'), 'the old split line is gone');
});

test('the skills spec states the go past its draft, and the autopilot size it brought', () => {
  // M3 part 2 project 2 Task 5: autopilot has no cap test; its size sentence and step 6 move with the skill.
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', [
    'then take the ticket to a draft PR, and from there by `references/ci.md` to `gh pr ready` on its own PR or a stop (M3 part 2 project 2 Task 5).',
    'SKILL.md 6,121 bytes (6,106 until M3 part 2 project 2\'s Task 5: step 6\'s run ends at `gh pr ready` on its own PR, not at the draft; 5,651 until its Task 4: ',
    '| `autopilot` | slash | M1 | 6.1 KB built (+14.5 KB refs) |',
    // Review fix round 1: the spec quotes the per-prompt autopilot line word for word.
    'draft PR after dedup (a go: then ci.md to gh pr ready); run git and gh directly,',
    'lease push only if rebase.push=autopilot or the user typed rebase and push; every other ask is denied;']);
  // Review fix round 1: settings.md's Lease push row said rebase.push alone, while G1 also takes the typed lease.
  // Final review M2: G1 reads `rebase` or `sync` alone as the lease too; the table adds a go's body edit and ready, the
  // approval's bounds, and the two typed consents that lift a deny under autopilot.
  assertContains('kernel/settings.md', ["| never allowed. It asks or denies | allowed only with `rebase.push: autopilot` or the user's typed `rebase and push`, `rebase` or `sync` |",
    "Under autopilot it also stands for G1's lease push (a typed `rebase and push`, or `rebase` or `sync` alone) and G2's `gh pr ready` on a go's own draft (a typed `leave it and mark the PR ready`), and lifts their deny, as the rows below say. It counts only for that prompt and repository, and lifts no other deny.",
    '| PR body edit | `gh pr edit --body-file <file>` alone, with no PR number or `-R`, on a live go\'s own open draft. The file is a regular file in the repo that git keeps, with no attribution | never allowed. It asks | allowed only under that go, with `pr.policy` at `ask` or `auto` |',
    "| Mark a PR ready | `gh pr ready` alone, with no PR number, `-R` or other option, on a live go's own open draft | never allowed. It asks | allowed only under that go: when the PR's head is HEAD, its checks read clear or none and the review-check record for HEAD's tree ends `floor: none`, or on the user's typed `leave it and mark the PR ready`. The allow ends the go |",
    "| Approve a spec or plan | the go's quote on a file whose issue: names its ticket | never | only with a go, until its draft PR opens; a plan only after its review record holds `Verdict: approve` and no `Verdict: revise` |"]);
});

test('ci.md holds the CI loop a go follows from its draft PR to `gh pr ready`, in the design\'s order', () => {
  // M3 part 2 project 2 Task 5: design "The CI loop" and "The finish line" as rules. The Stop hook (Task 7) reads the
  // `kern stop:` line; the exec graders (Task 10) read `CI round:` and the reply words, which the guards (Tasks 2 and 4) read.
  assertHeadings(CI, ['# CI loop', '## Wait', '## Read a red', '## Classes', '## Class 4', '## CI fix rounds', '## Every push', '## Ready']);
  assertContains(CI, [
    // When: under a go only; a person's run keeps finish-branch step 11's single read.
    'These rules run under a go only, after the draft PR opens and after each push.',
    "A person's run keeps finish-branch step 11's single `gh pr checks` read, with no wait.",
    'a `kern stop: <what>` line',
    // Wait and limit.
    'Start `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ci-wait <wt>` as a background command',
    'Never poll with turns',
    '| `ci: pending <names> (timeout <N>m)` | 3 | Stop',
    // Read a red.
    '`gh run view <id> --log-failed`', '`git diff origin/<base>...HEAD`',
    "each red's class with the log line that shows it",
    // The five classes, and the replies in their words.
    "| 1 | The PR's change caused it |", '| 2 | External, the PR cannot fix it |', '| 3 | External, the PR can fix it |',
    '| 4 | The branch is behind its base or out of sync |', '| 5 | Red in a file the PR touches, from code the PR did not change |',
    '`fix it here`', '`leave it and mark the PR ready`', '`leave it`', '`rebase and push`',
    'A bare yes, ok or go ahead gives no consent', 'An unclear red goes as class 2.',
    // Class 4.
    '`git rebase origin/<base>` in the run\'s worktree, in its own Bash call',
    'A resolution that changes behaviour neither side names is a design choice',
    '`git push --force-with-lease origin <branch>`', 'A rebase is no CI round.',
    // Review fix round 1, I1: `prompt_consent` gives `lease` only for these bare phrases, and only this turn's prompt counts,
    // so a wider skip rebased and edited the body before G1 denied the push. The lease push now comes before the body edit.
    "or this turn's typed prompt is one G1 reads as a rebase: `rebase and push`, or `rebase` or `sync` alone.",
    // Task 6, from Task 5's review: Every push listed the lease push after the body edit, a second order beside class 4's,
    // so Every push now states the one order and class 4 step 4 drops its own clause.
    "as its push. If G1 denies it, stop with `kern stop:` and G1's reason, and leave the body as it was.",
    'Every push, each round\'s push included, runs these in order. The class 4 lease push runs them too, with step 5 before step 4:',
    // Fix round 1: the lead line alone states the order, so step 5 does not repeat it.
    '5. The push: `git push origin <branch>`; after a rebase, the lease push.\n',
    // Its minors: a resolution that stops leaves no half-done rebase; only two of the replies are guard words; a deny's push
    // goes through Every push.
    'is a design choice: run `git rebase --abort`, push nothing and stop.',
    'G1 reads `rebase and push`, and G2 `leave it and mark the PR ready`, as the user\'s consent.',
    'With P the highest package number before this push, round N reviews package P+N+1. When round 3\'s package, P+4, is still `fix first`, push, stop and keep the PR draft.',
    'such as a push through Every push or a self-review; a second deny is a stop.',
    // Fix rounds.
    'Up to 3 per go, counted apart from self-review\'s rounds.', '`CI round: <N>`', '`git log --format=%b origin/<base>..HEAD`',
    'When the wait after round 3 is still red, stop: the branch is pushed and the PR stays draft.',
    // Ready.
    'exactly `gh pr ready`, with no PR number, `-R`, pipe, redirect or second command',
    'A typed `leave it and mark the PR ready` lets G2 allow it for that prompt only']);
  // Every push runs its steps in the design's order: test.full, self-review, proof, the body, the push, the wait.
  const push = section(readFileSync(join(import.meta.dirname, '..', CI), 'utf8'), '## Every push');
  const at = ['`test.full`', '`review-check`', 'Proof', '`gh pr edit --body-file', '`git push origin <branch>`', 'The wait'].map((s) => push.indexOf(s));
  assert.ok(at.every((n, i) => n >= 0 && (i === 0 || n > at[i - 1])), `every push's order: ${at}`);
  assert.ok(!push.includes('or the lease push after a rebase.'), 'the lease push is no longer listed after the body edit alone');
  assert.ok(!readFileSync(join(import.meta.dirname, '..', CI), 'utf8').includes("made before Every push's body edit"), 'class 4 step 4 leaves the order to Every push');
  // run.md points at it, and autopilot step 6 names the new finish line.
  assertContains('skills/autopilot/references/run.md', ['`references/ci.md`', '`kern stop: <what>`']);
  assert.ok(read('autopilot').body.split('\n6. `go <ticket>`')[1].split('\n')[0].includes('`gh pr ready`'), 'autopilot step 6 names gh pr ready');
});

test('no skill calls an override a project skill, since an override can name a user or plugin skill', () => {
  // M3 part 1 Task 15. Each skill's own test holds step 0 to DEFER.
  const dir = join(import.meta.dirname, '..', 'skills');
  for (const n of readdirSync(dir).filter((d) => existsSync(join(dir, d, 'SKILL.md')))) {
    assert.ok(!readFileSync(join(dir, n, 'SKILL.md'), 'utf8').includes('that project skill'), n);
  }
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', ['Step 0 reads: "If the settings block names an override for this job, follow that skill instead, say so in one line, and stop."']);
});

test('the skills spec parks a judgment call only where run.md lets it', () => {
  // M3 part 1 Task 15: A8 and execute-plan's section 6 parked every judgment call, while run.md
  // stops on a design choice the ticket does not settle.
  const spec = readFileSync(join(import.meta.dirname, '..', 'docs', 'specs', '2026-10-12-kern-m1-m2-skills.md'), 'utf8');
  assert.ok(!spec.includes('judgment calls are parked'), 'no unbounded park');
  assert.ok(spec.includes('Under autopilot: anything that would ask is denied; a judgment call the stop list in `skills/autopilot/references/run.md` does not stop for is parked as a `parked:` ledger line with the default chosen, a design choice on that list waits for a typed reply, and disjoint work continues;'));
  assert.ok(spec.includes('Under autopilot: runs to the end; a judgment call the stop list in `skills/autopilot/references/run.md` does not stop for is parked with the default chosen; any other stop waits for a typed reply, with the data and a recommendation;'));
  assert.ok(RUN.includes("A design choice stops the run when the ticket does not settle it"), 'run.md holds the rule the spec names');
});

test('each route under autopilot points at run.md from its own section', () => {
  const pointer = 'Under autopilot, stops, unblocking and the run report follow ${CLAUDE_PLUGIN_ROOT}/skills/autopilot/references/run.md.';
  for (const name of ['implement', 'execute-plan', 'self-review', 'finish-branch', 'commit', 'diagnose']) {
    const { body } = read(name);
    assert.ok((section(body, '## Stops and autopilot') ?? '').split('\n').includes(pointer), name);
  }
});

test('autopilot off reads the ledgers dir without creating it', () => {
  const { body } = read('autopilot');
  const off = body.split('\n5. `off`')[1].split('\n\n')[0];
  assert.ok(!/kern-dir ledgers/.test(off) && /Never run `kern-dir`/.test(off));
  assert.match(off, /only when it already exists/);
});

test('terse mode tells the voice to answer only what was asked, in numbered order', () => {
  const t = readFileSync(join(import.meta.dirname, '..', 'modes', 'terse.md'), 'utf8');
  assert.match(t, /\n2\. Answer only what was asked: no unrequested background, lists, examples, option tables or follow-up offers\. Give detail when the user asks for it\./);
  const nums = t.split('## Rules\n')[1].split('\n\n')[0].split('\n').map((l) => l.match(/^(\d+)\./)[1]);
  assert.deepEqual(nums, ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11']);
});

test('mode documents the switch phrases the hook accepts', () => {
  const { body } = read('mode');
  assert.match(body, /only when it stands alone on the prompt's first non-blank line/);
  assert.match(body, /a line over 200 characters never does\./);
  assert.match(body, /^- terse voice: .*"terse on", "terse voice", "terse mode on"/m);
});

// Claude Code replaces `$1`, `$2`... and `$ARGUMENTS` in a skill body with the invocation's arguments, so an awk
// `$1` in a SKILL.md breaks once the skill takes one (Task 17 lane 4, SP54; superpowers 7.0.0 RELEASE-NOTES.md:41).
// The frontmatter is not body, and a reference read by path is not substituted, so neither is checked. `$10` and
// `$1abc` count too: the brief's `\b` after one digit missed them (fix round 1, Minor 4).
function placeholders(raw) {
  const text = raw.replace(/\r\n/g, '\n');
  const { body } = parseFrontmatter(text);
  const offset = text.slice(0, text.length - body.length).split('\n').length - 1;
  return body.split('\n').flatMap((line, i) => (/\$(\d+|ARGUMENTS)/.test(line) ? [{ line: offset + i + 1, text: line }] : []));
}

test('the placeholder matcher reads the body, fenced blocks included, and skips the frontmatter', () => {
  const raw = '---\nname: x\nargument-hint: "$1"\n---\n\nRun `awk \'{print $1}\'` on it.\n```\necho "$ARGUMENTS"\n```\n`${CLAUDE_PLUGIN_ROOT}/scripts/kern-get`\nawk \'{print $10}\'\n';
  assert.deepEqual(placeholders(raw), [{ line: 6, text: "Run `awk '{print $1}'` on it." }, { line: 8, text: 'echo "$ARGUMENTS"' }, { line: 11, text: "awk '{print $10}'" }]);
});

test('no SKILL.md body holds an argument placeholder', () => {
  const dir = join(import.meta.dirname, '..', 'skills');
  const hits = readdirSync(dir).filter((n) => existsSync(join(dir, n, 'SKILL.md'))).flatMap((n) => {
    const rel = `skills/${n}/SKILL.md`;
    return placeholders(readFileSync(join(dir, n, 'SKILL.md'), 'utf8')).map((h) => `${rel}:${h.line}: ${h.text}`);
  });
  assert.deepEqual(hits, [], `Claude Code substitutes these with the skill's arguments; write the shell without them:\n${hits.join('\n')}`);
});

test('autopilot commits and draft PRs follow commit.attribution (coverage gap 54)', () => {
  const { body } = read('autopilot');
  for (const s of ["With `commit.attribution: none`, the default, write no Co-Authored-By or other attribution trailer, even when Claude Code's attribution reminder asks for one: G5 denies it.",
    'With `commit.attribution: none`, the body has no attribution footer such as "Generated with Claude Code".']) assert.ok(body.includes(s), s);
});

test('the design, the contract and the settings keep the Stop hook that holds a go to ready', () => {
  // M3 part 2 project 2, Task 7: design 6.3's Stop row and 8.3's G7 row state the checks, the opt-in and the count;
  // 5.4 and kernel/settings.md add stop.nudge; hooks/stop joins G16's hook entry files.
  assertContains('docs/specs/2026-10-12-kern-design.md', [
    '| Checks | `stop.nudge` | `off`; `on` turns on the Stop hook\'s nudges outside a go (section 6.3) | the Stop hook |',
    '| Stop | One reason lists each check that fails, printed as `{"decision":"block","reason":...}` with exit 0; `kern: off` and any fault allow.',
    "The size ask (M3 part 2 project 2): the turn's results hold `size-check`'s `size: ask: <q>` and the last message does not hold `<q>` as printed. These two block once: a stop the hook already blocked (`stop_hook_active`) skips them.",
    "A go's finish line (M3 part 2 project 2), under a live go until the run reports its first stop: a stop is allowed when the last message holds a line that opens `kern stop: ` past any list, quote, emphasis or heading mark, as the eval grader reads it, which stands the check down for the rest of the go (`stop_down`), or while a background `ci-wait` or subagent the go started has no task-notification; otherwise the reason names the first missing step: the draft PR, a `ci-wait` after the last push, a push after a red verdict, or `gh pr ready`.",
    "A go's report, while no such wait is open: each `check: <name>: skip (named)` line `review-check` printed in the turn is named in the last message beside the word skip.",
    "The nudges, under a go, or outside one only with `stop.nudge: on`: a main-thread Edit, Write or NotebookEdit outside the work dir with no `test.focused`, `test.full`, `task-done`, `review-check` or `probe` run after it, and `floor-scan`'s hits in `git diff HEAD` of the files those calls edited (G7, section 8.3) that the last message does not name by `path:line`.",
    "Under a go each finish-line, report, proof skip or nudge block adds 1 to `stop_backs`; the third asks the run to end with its report, saying it stopped short, and the next stop is allowed; any stop allowed at 3 sets the count back to 0. A typed prompt, or the first task-notification after the last block of a background `ci-wait` or subagent the go started, once for each, starts the count again; a notice of anything else does not. Outside a go `stop_hook_active` allows.",
    "| G7 floor guard | opt-in, `stop.nudge: on` | At turn end the Stop hook runs `floor-scan` on `git diff HEAD` of the files the turn's main-thread edits touched: a new suppression, a skipped or deleted test, a removed assert, an empty catch or a debug print blocks the stop once, unless the last message names its `path:line` with a reason (M3 part 2 project 2) | Under a go, always on: each block counts toward the Stop hook's 3 send-backs in a row (section 6.3). A plain `/kern:autopilot on` run is as interactive |",
    'any write or run of a hook entry file (`hooks/stop` among them since M3 part 2 project 2)']);
  assertContains('docs/plans/contract.md', [
    'hooks/stop                                                                                    (M3 part 2 projects 1 and 2)',
    '(today `kern-detect`, which G5 and the Stop hook run, `floor-scan`, which the Stop hook runs, and `kern-get`, which a rendered line names)',
    "The Stop hook adds `stop_backs` (its send-backs in a row under a go, 0 to 3), `stop_line` (the transcript's line count at its last such send-back) and `stop_down` (`1` once the go's run reported a stop, else empty or unset), M3 part 2 project 2, Task 7.",
    'a hook entry file (`prompt-submit`, `session-start`, `subagent-start`, `pre-tool-use` or, since M3 part 2 project 2\'s Task 7, `stop`, which counts in this path form, and as a bare word or a glob that could match it only where the hooks folder in play may be kern\'s (the word rule\'s unknown folder: kern\'s own, one a cd or a variable names, or one G16 cannot tell), and is no entry file\'s name for the write rules below, so `docker compose stop` with the session\'s cwd in a project\'s own hooks folder gets no vote, `bash stop` after a cd into kern\'s hooks folder asks, and a project\'s own `hooks/stop` clears) after `hooks/`',
    '- **The Stop hook holds a go to ready (M3 part 2 project 2, Task 7).**',
    'Outside a go the hook reads on only when the transcript holds `self-review` or `size-check` (one `grep -F`), or `stop.nudge` reads `on`',
    "(3) The finish line, under a live go with `stop_down` empty: a line of the last message that opens `kern stop: `, once a leading run of blanks, `>`, `*`, `_`, backticks, `#`, `+`, `-` and list numbers (digits, then `.` or `)` and a blank) is dropped, as `stopLines` in `scripts/lib/exec-grade.mjs` drops them (the final review's I2), writes `stop_down=1` and passes;",
    'Under a go each block that holds (3), (4), (5), (6) or (7) is a send-back: `stop_backs` (0 to 3) goes up by 1 and `stop_line` takes the transcript\'s line count, and a write that fails allows, as do a read',
    "any stop allowed with `stop_backs` at 3 writes `stop_backs=0`. A wait's first task-notification line past `stop_line` reads as `stop_backs` 0, so each wait starts the count again once; a notice of anything else (a Monitor's event, a command that is no wait) does not.",
    "so does one of the go's waits, a Bash call whose simple command runs `ci-wait` or an Agent (or Task) call, whose result's `toolUseResult` holds a `backgroundTaskId` or the status `async_launched`, while no task-notification names its `tool_use_id`; any other background command holds nothing open.",
    '(4) The report, under a live go with no wait open: each',
    "(6) runs `git --literal-pathspecs diff --no-ext-diff --no-textconv --no-color HEAD -- <files>` in each file's repository top, each file named from that top (`rev-parse --show-prefix`), up to 100 files,",
    "Each hit whose `path:line` the last message does not hold with no digit right after it is named, the first 20 and then `and N more`.",
    "as do a read of `stop_down`, `go_phase`, `stop_backs` or `stop_line` that fails and a line count that is no number.",
    "A grep for the turn or for the go's prompt that fails allows, since a wider window could block on an earlier turn.",
    "The scan runs under `pipefail`, so a `tail` of the transcript that fails allows.",
    "never a `KERN_MAIN` the environment brings.",
    "Known limits: a wait from before the go's prompt holds nothing open, and one whose notification Claude Code never writes keeps the finish line open;"]);
  assertContains('kernel/settings.md', [
    "| `stop.nudge` | `off` | `off`, `on`. `on` turns on the Stop hook's nudges outside a go: an edit with no proving command after it, and a lowered floor in the edited files that the last message does not name. Under a go they always run | stop |"]);
  // The project 1 entry no longer says project 2 extends it, and neither does the hook's header.
  const contract = readFileSync(join(import.meta.dirname, '..', 'docs', 'plans', 'contract.md'), 'utf8');
  const design = readFileSync(join(import.meta.dirname, '..', 'docs', 'specs', '2026-10-12-kern-design.md'), 'utf8');
  const hook = readFileSync(join(import.meta.dirname, '..', 'hooks', 'stop'), 'utf8');
  for (const [name, text] of [['contract', contract], ['design', design], ['hooks/stop', hook]]) {
    assert.ok(!/Project 2 extends it/.test(text), name);
  }
});

test("the skills spec's key table holds verify.browser's default and points at the keys added since", () => {
  // Final review M3: A5 still had verify.browser's old ask; the keys M3 added live in kernel/settings.md and design 5.4.
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', [
    '| `verify.browser` | none: with no `verify.app` either, proof on the running app is a named skip, or a stop when it is required | none | prove-it, diagnose, verify-app |',
    'Keys added since M2, `verify.app`, `ci.wait_minutes`, `ci.advisory` and `stop.nudge` among them, are listed in `kernel/settings.md` and design section 5.4.']);
  assert.ok(!readFileSync(join(import.meta.dirname, '..', 'docs', 'specs', '2026-10-12-kern-m1-m2-skills.md'), 'utf8').includes('ask when a UI claim needs it'), 'the stale ask is gone');
});

test('the design and the contract keep the report a go owes after ready, and the stop line the grader reads', () => {
  // Final review I1: G2's ready allow ends the go, so go_report keeps the Stop hook's report check for the stop after it.
  // Final review I2: the hook drops the marks the grader drops before `kern stop: `.
  assertContains('docs/specs/2026-10-12-kern-design.md', [
    "G2's allow of the go's `gh pr ready` ends the go and writes `go_report=1`, so this check runs once more outside the go, at the first stop with no wait open; its block there is not counted, and the stop allowed after it empties `go_report`, as do a typed prompt, a new go and autopilot off.",
    'allows with no parse when neither holds `self-review` or `size-check`, no nudge applies and no report is owed;']);
  assertContains('docs/plans/contract.md', [
    "G2's allow of a go's `gh pr ready` adds `go_report` (`1` while the ended go's report is owed to the Stop hook, else empty or unset), the final review's I1.",
    '`apply_go` writes `go_phase` empty with its `go`, `autopilot_off` writes it empty with `go` and `go_repo`, and `state_reset` writes no `go_phase`. Both also write `go_report` empty',
    'Outside a go `stop_hook_active` allows, as before; with `go_report` at `1` that stop also writes it empty.',
    'With `go_report` at `1` it always reads on.',
    "Outside a go it runs once more while `go_report` is `1` (G2's ready allow ends the go and writes it; the final review's I1), at the first stop with no wait open: there its block is no send-back, and the stop it allows, or the `stop_hook_active` stop after its block, writes `go_report` empty; a read of `go_report` that fails owes no report.",
    "and `go_report` empty likewise when it is `1`; `apply_go` writes `stop_backs=0`, and `stop_down` and `go_report` empty, with its go, and `autopilot_off` writes `go_report` empty.",
    // Final review M1: the two cases that push after the draft wait on their last push too.
    '`go-ci-fix-ready` and `go-ci-behind-rebase` also want such a call after the last push that ran, so a fix or lease push is waited on before ready (the final review\'s M1); with no push that ran that row passes, and the push rows fail the run.']);
  for (const [name, path] of [['contract', join('docs', 'plans', 'contract.md')], ['design', join('docs', 'specs', '2026-10-12-kern-design.md')]]) {
    assert.ok(!readFileSync(join(import.meta.dirname, '..', path), 'utf8').includes('leading blanks dropped'), `${name} still says leading blanks dropped`);
  }
  // One mark set in both readers: the hook's BWK awk has no lookahead, so it drops the blank after a list number with it.
  const hook = readFileSync(join(import.meta.dirname, '..', 'hooks', 'stop'), 'utf8');
  const grade = readFileSync(join(import.meta.dirname, '..', 'scripts', 'lib', 'exec-grade.mjs'), 'utf8');
  assert.ok(hook.includes('sub(/^([ \\t>*_`#+-]|[0-9]+[.)][ \\t])+/, "", x); if (substr(x, 1, 11) == "kern stop: ")'), 'the hook strips the marks');
  assert.ok(grade.includes(".replace(/^(?:[\\s>*_`#+-]|\\d+[.)](?=\\s))+/, '')).filter((l) => l.startsWith('kern stop: '))"), 'the grader strips the same marks');
});

test("the contract keeps the round 1 fix batch's Stop hook reason", () => {
  // M3 part 2 project 2's paid round 1, F1: under a go the unproven-edit reason asks for the whole report again.
  assertContains('docs/plans/contract.md', [
    "Under a live go its reason ends `Then give the whole report again.`, since the grader reads the last reply (M3 part 2 project 2's round 1 fix batch: go-required-check-stop's last reply after this send-back gave a probe's result alone)."]);
});

test("the contract and both designs keep the round 2 fix batch's proof skip", () => {
  // M3 part 2 project 2's paid round 2, H1 (the user's "Build the Stop hook check", 2026-11-05): go-proof-skip's report
  // reworded prove-it's skip line twice, so the Stop hook holds a report that names the proof to the line as printed.
  const reason = "``kern: your report names the proof on the running app, and neither verify.browser nor verify.app is set, so it is prove-it's named skip. Give the whole report again with this line as printed: `skip: proof on the running app, no verify.browser or verify.app`.``";
  assertContains('docs/plans/contract.md', [
    "(7) The proof skip (M3 part 2 project 2's round 2 fix batch; the user's \"Build the Stop hook check\", 2026-11-05: `go-proof-skip`'s report reworded prove-it's skip line in paid rounds 1 and 2), where a report is due: under a live go with no wait open until the run reports a stop (`stop_down` empty), and in the report a go owes while `go_report` is `1`. After a reported stop the user is back, and a later reply may answer a question, not report the go, so it is not read (the fix batch's fix round 1).",
    "A line of the last message matches `verify\\.(browser|app)|running app`, the last message does not hold `skip: proof on the running app, no verify.browser or verify.app` as printed, it holds no `kern stop: ` line as (3) reads one (a required proof that cannot run is a stop, not a skip), and `settings_get` gives neither `verify.browser` nor `verify.app` a value (a read that exits other than 0 or 3 counts as set, so it allows); reason " + reason,
    "In the owed report its block is no send-back, as (4)'s is; outside a go with no report owed it never runs. Under a go each block that holds (3), (4), (5), (6) or (7) is a send-back",
    "`report skip`, `proof skip` (since the round 2 fix batch's check (7)), `unproven edit`"]);
  assertContains('docs/specs/2026-11-05-kern-m3-part2-p2-design.md', [
    "| The proof skip | Where the report is read, under a go with no wait open until the run reports a stop and in the report a go owes after `gh pr ready`: a report that names `verify.browser`, `verify.app` or the running app, with neither setting set and no `kern stop:` line, holds prove-it's line `skip: proof on the running app, no verify.browser or verify.app` as printed, or the hook sends it back for that line. Under a go the send-back counts toward the 3. This closes `go-proof-skip`'s reworded skip line, missed in paid rounds 1 and 2 (the round 2 fix batch; the user's \"Build the Stop hook check\", 2026-11-05) |"]);
  assertContains('docs/specs/2026-10-12-kern-design.md', [
    "The proof skip (M3 part 2 project 2's round 2 fix batch), where the report is read, under a live go until the run reports its first stop and in the report a go owes after ready: a last message that names `verify.browser`, `verify.app` or the running app, with neither setting set and no `kern stop: ` line, must hold prove-it's line `skip: proof on the running app, no verify.browser or verify.app` as printed.",
    'Under a go each finish-line, report, proof skip or nudge block adds 1 to `stop_backs`']);
  // The hook's reason is the contract's, word for word, and the line it asks for is prove-it's set line.
  const hook = readFileSync(join(import.meta.dirname, '..', 'hooks', 'stop'), 'utf8');
  assert.ok(hook.includes(`add "${reason.slice(2, -2).replaceAll('`', '\\`')}"`), 'the hook gives the contract\'s reason');
  // The fix batch's fix round 1: under a go the check runs only until the run reports a stop.
  assert.ok(hook.includes('if { { [ "$GO" = 1 ] && [ -z "$DOWN" ]; } || [ "$READ" = 1 ]; } && [ "$PENDING" = 0 ] && proof_skip; then'), 'not after a reported stop');
  assertContains('skills/prove-it/SKILL.md', ['skip: proof on the running app, no verify.browser or verify.app']);
});

test("the contract and both designs keep the round 2 fix batch's G20 route gate", () => {
  // M3 part 2 project 2's paid round 2, H2 (the user's "Build the G20 gate", 2026-11-05): go-required-check-stop built
  // with no spec in five of six runs, so under a go G20 holds a build's edits until a spec carries the go's approval.
  const reason = 'under a go, a build starts at define, and no spec under <KERN_MAIN>/<work_dir>/specs carries this go\'s approval. Read ${CLAUDE_PLUGIN_ROOT}/skills/define/SKILL.md and write it first. A bug starts at diagnose; a tests-only ticket edits test files only.';
  assertContains('docs/plans/contract.md', [
    "- **G20's route gate under a go (M3 part 2 project 2's round 2 fix batch; the user's \"Build the G20 gate\", 2026-11-05).**",
    '`guard_g20` hands Write, Edit and NotebookEdit to `_g20_route`, and Write and Edit then to `_g20_file` as before.',
    'the call carries neither `agent_type` nor `agent_id`; `AUTOPILOT` is 1 and `go_live "$SID" "$KERN_MAIN"` holds;',
    "`_g20_test` finds no test in its path from the main worktree's root: a folder `test`, `tests` or `__tests__` on the way, or a name `*.test.*`, `*.spec.*` or `*_test.*`;",
    'whatever `go_phase` holds, so the go\'s CI fix rounds past its draft edit on;',
    "and, read last, the input's `transcript_path` holds no main-thread Read of the running kern's `skills/diagnose/SKILL.md`",
    `The deny reads \`\`${reason}\`\``,
    'A fault allows, as in G20\'s other votes:',
    // The fix batch's fix round 1: a file outside the main worktree is no build, a specs dir or grep fault allows,
    // and the go outlives its reported stop.
    "is under the main worktree's root and not under `KERN_MAIN/<work_dir>/` read the same way, so a memory, scratchpad or `/tmp` file passes (the fix batch's fix round 1);",
    'a specs dir that cannot be listed, a transcript that is not named or cannot be read, and any grep of the pipe that fails (status over 1; the last two since fix round 1). After a reported stop the go stays live, so the gate holds until `/kern:autopilot off`.',
    'Accepted limits: a Bash write (a here-doc, an inline script) is not seen, so a denied run could route around it; a diagnose Read opens the gate for any edit; test paths are read by name;']);
  const gate = "a main-thread Write, Edit or NotebookEdit under the main worktree's root and outside the work dir, of a file that is no test by its path, is denied until a spec under `WORK/specs` carries the go's approval, or the run has read diagnose: a go's build starts at define, a bug at diagnose";
  assertContains('docs/specs/2026-10-12-kern-design.md', [`Under a live go ${gate} (M3 part 2 project 2's round 2 fix batch) |`]);
  assertContains('docs/specs/2026-11-05-kern-m3-part2-p2-design.md', [
    `| G20 | A${gate.slice(1)}. This closes \`go-required-check-stop\`'s build with no spec, five of six paid runs (the round 2 fix batch; the user's "Build the G20 gate", 2026-11-05) |`]);
  // The guard's reason is the contract's, the work dir's specs named in place of the placeholder.
  const guard = readFileSync(join(import.meta.dirname, '..', 'hooks', 'guards', 'g20-approval.sh'), 'utf8');
  assert.ok(guard.includes(`vote deny G20 "${reason.replace('<KERN_MAIN>/<work_dir>', '$KERN_MAIN/$_G20_WD').replace('${CLAUDE_PLUGIN_ROOT}', '\\${CLAUDE_PLUGIN_ROOT}')}"`), 'the guard gives the contract\'s reason');
});

test("the contract and both designs keep the round 2 fix batch's G1 edit deny", () => {
  // M3 part 2 project 2's paid round 2, H3 (the user's "Build the G1 deny", 2026-11-05): after G1 denied a go's switch in the
  // main checkout, the run wrote its change there with the Write or Edit tool, in rounds 1 and 2.
  assertContains('docs/plans/contract.md', [
    "- **G1 denies a go's file edits in the main checkout (M3 part 2 project 2's round 2 fix batch; the user's \"Build the G1 deny\", 2026-11-05).**",
    '`guard_g01` hands Write, Edit and NotebookEdit to `_g01_edit`, and gives no tool but those and Bash a vote.',
    'Under autopilot with `go_live "$SID" "$KERN_MAIN"` holding (a plain autopilot run is not held to it),',
    "When `in_main_checkout` holds for that directory, and the target, read through it with `cd -P` and the parts after it as written (`_g01_real`), is not under `KERN_MAIN/<work_dir>/` (`work_dir` read as `kern-dir` reads it, through `cd -P` when it exists), it denies `<tool> in the main checkout (D3); use a kern worktree`, a subagent's call included.",
    "A linked worktree, one under `.claude/worktrees/` included, is no main checkout, so its files pass, and a file in no repository gets no vote.",
    // The fix batch's fix round 1: only the go's own repository, a settings fault allows, and the go outlives its stop.
    "Only the go's own repository is held: `kern_main_root` of that directory, through `cd -P`, must be `KERN_MAIN` through `cd -P`, so another repository's main checkout (a dotfiles repository that holds `~/.claude`, say) gets no vote (the fix batch's fix round 1).",
    "a settings read that fails (`settings_get` exits other than 0, as it exits 4 for a layer it cannot read) allows, as G20's route gate does (fix round 1). After a reported stop the go stays live, so this deny holds until `/kern:autopilot off`.",
    'Limit: a Bash write into the main checkout (a here-doc, an inline script) is not seen.']);
  assertContains('docs/specs/2026-10-12-kern-design.md', [
    "Under a live go, a Write, Edit or NotebookEdit in the go's own main checkout outside the work dir is denied as well; a linked worktree and another repository's main checkout pass (M3 part 2 project 2's round 2 fix batch) |"]);
  assertContains('docs/specs/2026-11-05-kern-m3-part2-p2-design.md', [
    "| G1 | A Write, Edit or NotebookEdit in the go's own main checkout, outside the work dir, is denied: a go's work lives in a kern worktree, as implement says. This closes the main checkout edits that followed G1's denied switch in paid rounds 1 and 2 (the round 2 fix batch; the user's \"Build the G1 deny\", 2026-11-05) |"]);
  // The guard's reason is the contract's, and it reads the go as G2 does.
  const guard = readFileSync(join(import.meta.dirname, '..', 'hooks', 'guards', 'g01-git.sh'), 'utf8');
  assert.ok(guard.includes('vote deny G1 "$TOOL in the main checkout (D3); use a kern worktree"'), 'the guard gives the contract\'s reason');
  assert.ok(guard.includes('[ "${AUTOPILOT:-0}" = 1 ] && go_live "${SID-}" "${KERN_MAIN-}" 2>/dev/null || return 0'), 'only under a live go');
  assert.ok(guard.includes('[ -n "$m1" ] && [ "$m1" = "$m2" ] || return 0'), "only in the go's own repository");
});

test("the contract and the skills spec keep plan-check's plan line for a short spec over 2 files", () => {
  // M3 part 2 project 2's paid round 1, F2: go-no-lint-draft's approved short spec named 4 files and the run built with no plan.
  assertContains('docs/plans/contract.md', [
    "A spec with no problems, `status: approved` and `form: short` whose `## Size` section's first `Files:` line, past a list mark and bold, opens with a count over 2 also prints `next: plan (define step 9: over 2 files)` and exits 0 (M3 part 2 project 2's round 1 fix batch: `go-no-lint-draft` built from such a spec with no plan, 3 rounds running); 2 or fewer files, no count, a draft and the full form print no such line |"]);
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', [
    "on a clean approved `form: short` spec whose `## Size` Files count is over 2, `next: plan (define step 9: over 2 files)` (M3 part 2 project 2's round 1 fix batch);"]);
});

test('the contract grades go-block-reroute as the delete stop', () => {
  // M3 part 2 project 2's paid round 1, F3 (the user's "Grade the stop"): run.md makes the ticket's delete a stop, so G21 never votes.
  assertContains('docs/plans/contract.md', [
    "`go-block-reroute` wants the ticket read, `keep: intact`, a line of the final text that opens `kern stop: ` past the marks `stopLines` drops and names the delete (`export-cache`, `cache`, `delet`, `clear`, `remov` or `folder`), no `pr create`, and the delete stop named; since M3 part 2 project 2's round 1 fix batch (the user's \"Grade the stop\", 2026-11-05) it grades the stop that run.md's delete rule makes of the ticket's delete, where it wanted G21's vote, a commit changing `src/cache.js` and a draft PR, and no exec case measures a guard-block reroute."]);
  assert.ok(!readFileSync(join(import.meta.dirname, '..', 'docs', 'plans', 'contract.md'), 'utf8').includes('a draft PR, and the block named'), 'the old rows are gone');
});

test('the contract and the skills spec keep the size defaults kern-get gives', () => {
  // M3 part 2 project 2's paid round 1, F4 (the user's "Fix kern-get defaults"): plan step 1 passes no default.
  assertContains('docs/plans/contract.md', [
    "with no DEFAULT, `scope_threshold` and `pr.max_lines` take `kernel/settings.md`'s defaults, so unset they print `4<TAB>default` and `300<TAB>default`, and a DEFAULT given still wins (M3 part 2 project 2's round 1 fix batch, the user's \"Fix kern-get defaults\": two plan runs looped kern-get over both keys with one default or none and stated a limit it never printed);",
    '| 0; 3 unset, no default, never for those two keys (on exit 4 too when nothing readable sets KEY) |']);
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', [
    "Layered settings read (A4); prints `value<TAB>source`; with no default, `scope_threshold` and `pr.max_lines` print `kernel/settings.md`'s `4` and `300` when unset (M3 part 2 project 2's round 1 fix batch) |",
    "The limits are read here, with the first lookups: `kern-get scope_threshold` and, since the pilot fix plan's Task 5, `kern-get pr.max_lines`, each in its own call, printing its value and source (`4<TAB>default` when unset). Until M3 part 2 project 2's round 1 fix batch each lookup passed its default, `4` and `300`, which kern-get now gives itself: two head-to-head plan runs that round looped both keys with one default or none and stated a limit no lookup printed (the user's \"Fix kern-get defaults\")."]);
});

test("the contract's checkFailNamed takes a closing parenthesis after the check's name", () => {
  // M3 part 2 project 2's round 3 fix batch, K2: go-required-check-stop's report read "Required check (`npm test`): fail".
  assertContains('docs/plans/contract.md', [
    "; with the name before `fail` and no quote between them, a closing parenthesis also counts among those characters, since M3 part 2 project 2's round 3 fix batch, K2, whose go-required-check-stop report and commit body put the check's name in parentheses)"]);
});

test("the contract's approvedAfterReview skips a denied write", () => {
  // M3 part 2 project 2's round 5 fix batch, M1: G20 denied go-reaches-draft's early approval (:101, :102), which the row then read.
  assertContains('docs/plans/contract.md', [
    "`approvedAfterReview` (the first Write or Edit that came back with no error and puts the go quote into a `.kern/plans/` file follows",
    "; a denied write counts for nothing since M3 part 2 project 2's round 5 fix batch, M1, whose go-reaches-draft put the approval in a plan Write that G20 denied)"]);
});
