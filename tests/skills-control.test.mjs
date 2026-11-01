// mode and autopilot: frontmatter verbatim from skills spec B1 and B2, steps that never write state.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { parseFrontmatter } from '../scripts/lib/frontmatter.mjs';
import { section, assertMaxBytes, assertContains } from './helpers/md.mjs';

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
  assert.match(go, /The run ends at the draft PR or at a stop under that file's rules, so ask for no stop predicate\./);
  // Paid round 1, 2026-11-01: 4 of 6 go runs that built code took the ticket for the kernel's "agreed design", so they
  // skipped define and wrote no spec.
  assert.ok(go.includes("by the kernel's Routing table. A ticket is no agreed design: a build starts at define and a bug at diagnose."), go);
  assert.ok(body.includes('3. `on` or `go <ticket>`, and the hook reported "autopilot denied by <file>"'), 'a denied go names the file');
  const who = body.split('## Who can turn it on\n')[1];
  for (const s of ["A go counts as the user's yes for that ticket's spec and plan and nothing else.", 'A second ticket needs a second go.',
    'It ends when the draft PR opens, autopilot goes off or the session ends.', 'Autopilot itself stays on until the user turns it off.']) assert.ok(who.includes(s), s);
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
    '| Spending money | A draft PR on tested or verified changes |',
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
    'At a stop, the run brings the data it collected and a recommendation, then waits for a typed reply. A stop a guard denies stays denied after a yes: give the user the command to run with `!`; the go holds. Work that does not depend on the answer may finish first.',
    "Delete means data, remote branches, tags, and files outside the run's own worktree and scratch directories. Removing a file on the run's own branch is ordinary work.",
    "A design choice stops the run when the ticket does not settle it and the answer changes user-visible behaviour, stored data shape, a public interface or the ticket's scope. Any other judgment takes a default and goes in the report.",
    'A required check is one the ticket or prove-it names for the change.',
    // Paid round 1, go-required-check-stop: the run acted on this line, which held no word for its report.
    // Paid round 2: define's route has no "work goes on" line, so the run stopped with nothing built and no branch to push.
    'When one cannot run, the run builds by the closest check, commits, pushes its branch, stops with the report, naming the check as `fail`, and opens no PR. A typed reply that says to open the PR opens it.',
    'A ticket the run cannot read is a stop',
    // Paid round 3, the user's rule: go-deploy-stop's lane said `needs fixes` on the ticket's own formula, and the run opened the PR.
    // Re-review I1: under a go the run writes the plan, so the label alone also fits a formula the run chose. I2: a bounded run commits at finish-branch step 8, after this stop.
    'On a `plan-mandated` finding the ticket\'s own words demand, not only the run\'s spec or plan, the run commits, pushes its branch, stops with the finding and opens no PR. No fix round runs, and no `ticket` ruling parks it.']) assert.ok(stops.includes(s), s);
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
  // Re-review I2: finish-branch and self-review, read later, send a `fix first` here, so this line holds the exception.
  for (const s of ['A `fix first` verdict, but for that `plan-mandated` stop, starts a fix round in place of ending the run, up to 3 per self-review.',
    'Each round fixes the findings and runs self-review again in full, including the checks the last round skipped.',
    // Task 7 fix round 2: "After the third" read as a push and stop even when the third round comes back `ready`.
    'When a third round is still `fix first`, the run pushes its branch, stops with the report and opens no PR.', 'No verdict also stops.',
    'One go covers one draft PR.']) assert.ok(fix.includes(s), s);
  assert.deepEqual(fix.split('\n').filter((l) => l.startsWith('|')).slice(2), [
    '| `split` from a finding on a line the last round changed | The fixes are not converging: stop with the report |',
    "| `split` or the size gate on size alone | finish-branch's default: go on, with Scope giving the size |",
    // M3 part 1 Task 15: a ticket within `scope_threshold` and over `pr.max_lines` splits at plan step 7 too.
    "| A plan over `scope_threshold` or `pr.max_lines` | plan's default: take the split and run the first slice. The report lists the rest, and each needs its own go |",
  ]);
});

test('run.md gives define\'s first slice the default of a plan over scope_threshold', () => {
  // The table's row names only a plan, so a strict reading would stop a run at define's split.
  const rounds = section(RUN, '## Fix rounds');
  assert.ok(rounds.includes('each needs its own go |\n\ndefine\'s first slice takes the same default.\n'), 'the sentence follows the table');
});

test('run.md opens its define and plan rules with a go\'s route: a ticket is no agreed design', () => {
  // Paid round 2: 4 of 5 PR runs ran wt-snap, none ran the size gate, and go-deploy-stop's pushed tree was not its reviewed tree.
  assert.ok(section(RUN, '## Define and plan under a go').trim().startsWith('A ticket is no agreed design. Under a go, a build starts at define and a bug at diagnose. A draft PR comes only through finish-branch, in order: wt-snap, self-review with its proofs and spec lane, the size gate, the Proven tree check. An edit after the review takes a new wt-snap and `test.full`, and the report names it. Step numbers here are the skill\'s own.'));
});

test('run.md lists every report field, the jobs another skill ran among them', () => {
  const report = section(RUN, '## The run report');
  for (const s of ['the ticket and PR', 'each stop', 'each block and the route taken', 'each decision with its why', 'each skipped step', 'each check with its result',
    'the jobs that ran under another skill', '`parked:` lines keep their format.', 'A check that did not run, but for a named skip, is reported as a fail, not as "not run".',
    // Paid round 3: go-deploy-stop's lane said `needs fixes`, and its report said only that the review found it compliant.
    "The report gives the review's verdict as it came, `needs fixes` included."]) assert.ok(report.includes(s), s);
  assert.match(RUN, /^These rules cover kern's routes only\. .*`overrides\.<job>`/m);
});

test('the CHANGELOG caps line and the plan\'s expected line hold round 3\'s values', () => {
  // Re-review M1 and M3.
  const root = join(import.meta.dirname, '..');
  const caps = readFileSync(join(root, 'CHANGELOG.md'), 'utf8').split('\n').find((l) => l.startsWith('  - Caps, each raised where a task names why:'));
  for (const s of ['define `SKILL.md` 7,000 to 7,167;', 'plan `SKILL.md` 6,700 to 7,133 and', 'autopilot `references/run.md` new at 6,782.']) assert.ok(caps.includes(s), s);
  assert.ok(readFileSync(join(root, 'docs', 'plans', '2026-10-31-kern-m3-part1-plan.md'), 'utf8').includes('Expected: the Global Constraints scores hold, and the ten new exec cases pass.'));
});

test('the design and the skills spec state what run.md does with a defect the ticket demands', () => {
  const docs = join(import.meta.dirname, '..', 'docs', 'specs');
  const design = readFileSync(join(docs, '2026-10-31-kern-m3-part1-design.md'), 'utf8');
  for (const s of ['| A defect the ticket itself demands | |',
    "The user's rule, 2026-11-01: a defect the ticket itself demands stops a go before the PR.",
    'The report gives the review\'s verdict as it came, `needs fixes` included.']) assert.ok(design.includes(s), s);
  const spec = readFileSync(join(docs, '2026-10-12-kern-m1-m2-skills.md'), 'utf8');
  for (const s of ['a defect the ticket itself demands stops the go before the PR, with no fix round and no `ticket` ruling (M3 part 1 paid round 3)',
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
  // M3 part 1 final review. M2: the go clears inside G2's vote, before the strictest vote is known.
  const contract = readFileSync(join(import.meta.dirname, '..', 'docs', 'plans', 'contract.md'), 'utf8');
  assert.ok(contract.includes("A create that then fails, a `--dry-run`, another guard's deny of the call or a subagent's call ends the go as well: the go only gates approval."), 'M2');
  // M5: ruling 249 named reports and briefs; the both-words deny reaches these two as well, with or without a go.
  const g20 = readFileSync(join(import.meta.dirname, '..', 'hooks', 'guards', 'g20-approval.sh'), 'utf8');
  const both = 'a report, a brief, `pr-body.md` or a `*.proofs.md`';
  assert.ok(contract.includes(both), 'M5, contract');
  assert.ok(g20.includes('a report, a brief, pr-body.md or a *.proofs.md'), 'M5, guard');
  // M3 stays open: the limit in words, for part 2.
  const g16 = readFileSync(join(import.meta.dirname, '..', 'hooks', 'guards', 'g16-state.sh'), 'utf8').split('\n').slice(0, 20).join(' ').replace(/ # /g, ' ');
  assert.ok(g16.includes("a project's own shell file under hooks/lib or hooks/guards named by a command that does not only read"), 'M3, guard');
  assert.ok(contract.includes("a project's own shell file under `hooks/lib` or `hooks/guards` named by a command that does not only read"), 'M3, contract');
  assert.ok(contract.includes('adds `finish-size-decision` and the nine `go-` cases'), 'the go cases');
  // M9: the five stale rows.
  const design = readFileSync(join(import.meta.dirname, '..', 'docs', 'specs', '2026-10-12-kern-design.md'), 'utf8');
  for (const s of ['the user typed `/kern:autopilot on` or `/kern:autopilot go <ticket>` in this session',
    '| D10 | Fix loops stop after 3 rounds with a split proposal | Up to 3 rounds per self-review run on their own; a third still `fix first` pushes the branch, reports and opens no PR |',
    'Draft allowed after dedup, which ends a go;',
    'when find is a command head and every other simple command is `cd`, `ls` or a read-only filter',
    "a path counts as kern's hook code only when it resolves under kern's own root"]) assert.ok(design.includes(s), s);
  const settings = readFileSync(join(import.meta.dirname, '..', 'kernel', 'settings.md'), 'utf8');
  assert.ok(settings.includes('| session-start, prompt-submit, skill-conflicts, every skill |'), 'M9, settings');
});

test('run.md stays within its byte cap', () => {
  // 6,100 since M3 part 1 Task 15, its first cap: the main-thread rule, and define's and plan's go rules behind a pointer.
  // 6,130 since its fix round 1: a step's named read stays in the main thread.
  // 6,247 since paid round 1's fix: a ticket is no agreed design, and the stop's report names the check as `fail`.
  // 6,244 since its round 2, a fall: no fast path under a go and a PR only through finish-branch, less the line plan step 1 now holds.
  // 6,308 since paid round 2's fix: a run that cannot run a required check still builds, and a PR's steps are named in order, less a line the fix rounds table holds.
  // 6,322 since that fix's follow-up: the PR order names the spec lane.
  // 6,782 since paid round 3's fix: a defect the ticket itself demands stops a go, the report gives the review's verdict, and an edit after the review takes a new tree.
  assertMaxBytes('skills/autopilot/references/run.md', 6782);
  assertContains('docs/specs/2026-10-12-kern-m1-m2-skills.md', ['`references/run.md` at most 6,782 bytes (6,322 until M3 part 1 paid round 3\'s fix']);
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
