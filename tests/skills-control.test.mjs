// mode and autopilot: frontmatter verbatim from skills spec B1 and B2, steps that never write state.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
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
