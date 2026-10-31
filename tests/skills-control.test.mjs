// mode and autopilot: frontmatter verbatim from skills spec B1 and B2, steps that never write state.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { parseFrontmatter } from '../scripts/lib/frontmatter.mjs';
import { section } from './helpers/md.mjs';

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
  assert.match(go, /Any other hook line about the go means no go: quote it and start nothing\./);
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
  ]);
});

test('run.md says what each stop means and what a stop does', () => {
  const stops = section(RUN, '## The stop list');
  for (const s of ['A run stops only on this list.',
    'At a stop, the run brings the data it collected and a recommendation, then waits for a typed reply. Work that does not depend on the answer may finish first.',
    "Delete means data, remote branches, tags, and files outside the run's own worktree and scratch directories. Removing a file on the run's own branch is ordinary work.",
    "A design choice stops the run when the ticket does not settle it and the answer changes user-visible behaviour, stored data shape, a public interface or the ticket's scope. Any other judgment takes a default and goes in the report.",
    'A required check is one the ticket or prove-it names for the change.',
    'When one cannot run, the run pushes its branch, stops with the report and opens no PR. A typed reply that says to open the PR opens it.',
    'A ticket the run cannot read is a stop']) assert.ok(stops.includes(s), s);
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
  for (const s of ['A `fix first` verdict starts a fix round in place of ending the run, up to 3 per self-review.',
    'Each round fixes the findings and runs self-review again in full, including the checks the last round skipped.',
    'After the third, the run pushes its branch, stops with the report and opens no PR.', 'No verdict also stops.',
    'One go covers one draft PR.']) assert.ok(fix.includes(s), s);
  assert.deepEqual(fix.split('\n').filter((l) => l.startsWith('|')).slice(2), [
    '| `split` from a finding on a line the last round changed | The fixes are not converging: stop with the report |',
    "| `split` or the size gate on size alone | finish-branch's default: go on, with Scope giving the size |",
    "| A plan over `scope_threshold` | plan's default: take the split and run the first slice. The report lists the rest, and each needs its own go |",
  ]);
});

test('run.md lists every report field, the jobs another skill ran among them', () => {
  const report = section(RUN, '## The run report');
  for (const s of ['the ticket and PR', 'each stop', 'each block and the route taken', 'each decision with its why', 'each skipped step', 'each check with its result',
    'the jobs that ran under another skill', '`parked:` lines keep their format.', 'A check that did not run is reported as a fail, not as "not run".']) assert.ok(report.includes(s), s);
  assert.match(RUN, /^These rules cover kern's routes only\. .*`overrides\.<job>`/m);
});

test('run.md sends long output to a file under kern-dir tmp and reads its tail', () => {
  assert.ok(section(RUN, '## Long output').includes('Long output goes to a file in the directory `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp` prints, and the run reads its tail.'));
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
