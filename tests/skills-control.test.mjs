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
    "the last CI verdict and each red's class", 'the jobs that ran under another skill', '`parked:` lines keep their format.', 'A check that did not run, but for a named skip, is reported as a fail, not as "not run".',
    // Paid round 3: go-deploy-stop's lane said `needs fixes`, and its report said only that the review found it compliant.
    // M3 part 2 project 1's paid round 3: go-bug-draft's report gave the lane's "approved" for "the review's verdict" and no
    // self-review verdict word, so the sentence names self-review, and a lane's `needs fixes` as its own clause, which
    // go-mandated-defect-stop's grader reads (the controller's rulings on the round 4 fix batch).
    "The report gives self-review's verdict, and any lane's `needs fixes` as it came."]) assert.ok(report.includes(s), s);
  assert.match(RUN, /^These rules cover kern's routes only\. .*`overrides\.<job>`/m);
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
    "until its draft PR opens; a plan under `WORK/plans` only once `WORK/reviews/plan-<slug>.md`, its review's saved reply, holds the line `Verdict: approve` and no line `Verdict: revise` (M3 part 2 project 2) |"]);
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

test('the design, the contract and autopilot keep a go marking its own PR ready and the typed lease', () => {
  // M3 part 2 project 2 Task 4: G2 marks a go's PR ready on clear CI and a passed review-check, or on the typed word, and
  // edits its body; G1 takes the typed lease; review-check writes the record G2 reads.
  assertContains('docs/specs/2026-10-12-kern-design.md', [
    'a commit, a push, a draft PR (which covers its push), a PR edit, a lease push after a rebase or `gh pr ready`, in the closed grammar of `prompt_consent`',
    // Fix round 1: the typed word lifts every deny of a go's ready but its shape and its open draft.
    "and lifts no deny but two under autopilot: G1's lease push of the user's own branch, and G2's `gh pr ready` on a live go's own open draft, over checks that are red, pending or unread, a review-check record that is missing or above the floor, and a PR head that is not HEAD.",
    "`--force-with-lease` only with `rebase.push: autopilot` or the user's typed rebase or sync; a go marks its own PR ready on clear CI and a passed review-check, and edits its body from a file (M3 part 2 project 2); everything else denied |",
    "A go's CI fix rounds stop the same way, up to 3 per go (M3 part 2 project 2) |",
    "only with `rebase.push: autopilot` or when the user's last typed prompt asks to rebase or sync (section 5.1; a bare yes is not one, M3 part 2 project 2), and only when every commit on it is the user's |",
    "Under a live go with its draft open, `gh pr ready` on that PR (no PR number, no `-R`) allowed when the user's last typed prompt says to mark it ready, or when the PR's head is HEAD, its checks read clear or none at the call and the review-check record for HEAD's tree ends `floor: none`; the allow ends the go.",
    '`gh pr edit --body-file <file>` alone on that PR allowed with no prompt, the file checked as on create (M3 part 2 project 2). Any other `gh pr edit`, non-draft, an attributed body file and any other `gh pr ready` denied |']);
  assertContains('docs/plans/contract.md', [
    'G5 (`commit`), G1 (`push`, and `lease` under autopilot) and G2 (`pr`, `pr-edit`, `pr-title`, `pr-body`, and `ready` under a live go) call it.',
    "- **Lease push under autopilot (M3 part 2 project 2, Task 4):** to an unprotected branch, G1 takes the lease from `rebase.push: autopilot` or, when that is not set, from `consent_for ... lease`",
    'Under autopilot `gh pr ready` and `gh pr edit` are denied but on a live go\'s own open draft (`_g02_go_ready`, `_g02_go_edit`;',
    'Its whole stdout also goes to the record `<kern-dir tmp>/review-check-<tree>.txt`, `<tree>` the full id of WT\'s whole working state as `wt-snap WT` takes it before any check runs',
    "so the go lives on through CI until G2 allows its `gh pr ready` (Task 4), `/kern:autopilot off`, a second go or the session's end",
    "- **G2 marks a go's PR ready and edits its body (M3 part 2 project 2, Task 4).**",
    "is a regular readable file whose last non-blank line, blanks trimmed, is `floor: none`: review-check prints its floor last, so a check's tail above it is not one.",
    'Each allow runs `state_set "$SID" "go=" "go_phase="`, which ends the go; `go_repo` and `autopilot` stay.',
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
  assertMaxBytes('skills/autopilot/references/run.md', 7518);
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', ['`references/run.md` at most 7,518 bytes (7,337 until M3 part 2 project 2\'s Task 5: ',
    '; 7,329 until the controller\'s second ruling on M3 part 2 project 1\'s round 4 fix batch: ']);
});

test('ci.md stays within its byte cap', () => {
  // 6,651 since M3 part 2 project 2's Task 5, its first cap: the CI loop from the draft PR to `gh pr ready` or a stop, in its own
  // file since run.md sat at its cap.
  assertMaxBytes('skills/autopilot/references/ci.md', 6651);
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', ['`references/ci.md` at most 6,651 bytes (new in M3 part 2 project 2\'s Task 5: ']);
});

test('the skills spec states the go past its draft, and the autopilot size it brought', () => {
  // M3 part 2 project 2 Task 5: autopilot has no cap test; its size sentence and step 6 move with the skill.
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', [
    'then take the ticket to a draft PR, and from there by `references/ci.md` to `gh pr ready` on its own PR or a stop (M3 part 2 project 2 Task 5).',
    'SKILL.md 6,121 bytes (6,106 until M3 part 2 project 2\'s Task 5: step 6\'s run ends at `gh pr ready` on its own PR, not at the draft; 5,651 until its Task 4: ',
    '| `autopilot` | slash | M1 | 6.1 KB built (+14.2 KB refs) |']);
});

const CI = 'skills/autopilot/references/ci.md';

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
    'A resolution that changes behaviour neither side names is a design choice: stop.',
    '`git push --force-with-lease origin <branch>`', 'A rebase is no CI round.',
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
