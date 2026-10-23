// mode and autopilot: frontmatter verbatim from skills spec B1 and B2, steps that never write state.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { parseFrontmatter } from '../scripts/lib/frontmatter.mjs';

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
    'argument-hint': '[on|off|status]',
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
  for (const s of ['Merge, deploy, review posting and tracker writes always need the user', 'Only the user, by typing `/kern:autopilot on`']) {
    assert.ok(body.includes(s), s);
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
