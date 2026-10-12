// tests/lint-rules.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { parseFrontmatter } from '../scripts/lib/frontmatter.mjs';
import { loadModel, runLint } from '../scripts/lib/lint-rules.mjs';

function repo(files) {
  const root = mkdtempSync(join(tmpdir(), 'kern-lint-'));
  for (const [p, content] of Object.entries(files)) {
    mkdirSync(join(root, p, '..'), { recursive: true });
    writeFileSync(join(root, p), content);
  }
  return root;
}
const skill = (name, fm, body = '\n# x\n\n## Steps\n\n1. a\n') => `---\nname: ${name}\n${fm}\n---\n${body}`;
const lint = (files) => runLint(loadModel(repo(files)));
const rules = (findings) => findings.filter((f) => f.level === 'error').map((f) => f.rule);

test('parses CRLF frontmatter', () => {
  const r = parseFrontmatter('---\r\nname: a\r\ndescription: Use when x.\r\n---\r\nbody');
  assert.equal(r.error, null);
  assert.equal(r.data.name, 'a');
  assert.equal(r.body.trim(), 'body');
});

test('strips quotes and keeps colons in values', () => {
  const r = parseFrontmatter('---\nname: a\ndescription: "Use when: x happens"\n---\n');
  assert.equal(r.data.description, 'Use when: x happens');
});

test('block scalars are an error', () => {
  const r = parseFrontmatter('---\nname: a\ndescription: >\n  folded\n---\n');
  assert.match(r.error, /single-line/);
});

test('tiers: auto, path when a kernel row routes to it, else slash', () => {
  const manual = 'description: d\ndisable-model-invocation: true';
  const root = repo({
    'skills/a/SKILL.md': skill('a', 'description: Use when x.'),
    'skills/p/SKILL.md': skill('p', manual),
    'skills/s/SKILL.md': skill('s', manual),
    'kernel/kernel.md': '| New behaviour | Read {KERN}/p/SKILL.md |\n',
  });
  const tiers = Object.fromEntries(loadModel(root).skills.map((x) => [x.name, x.tier]));
  assert.deepEqual(tiers, { a: 'auto', p: 'path', s: 'slash' });
});

test('a clean auto skill passes', () => {
  assert.deepEqual(lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x happens.') }), []);
});

test('rule 1: missing frontmatter, name mismatch, non-kebab dir', () => {
  assert.deepEqual(rules(lint({ 'skills/a/SKILL.md': '# no frontmatter' })), [1]);
  assert.deepEqual(rules(lint({ 'skills/a/SKILL.md': skill('b', 'description: Use when x.') })), [1]);
  assert.deepEqual(rules(lint({ 'skills/Bad_Dir/SKILL.md': skill('Bad_Dir', 'description: Use when x.') })), [1]);
});

test('rule 2: unknown skill key and ignored plugin-agent keys', () => {
  assert.deepEqual(rules(lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.\ncolour: red') })), [2]);
  const agent = '---\nname: r\ndescription: d\npermissionMode: plan\n---\nbody\n';
  assert.deepEqual(rules(lint({ 'agents/r.md': agent })), [2]);
});

test('rule 3: auto limit and trigger, manual limit, agent limit, totals', () => {
  const long = 'Use when ' + 'x'.repeat(300);
  assert.deepEqual(rules(lint({ 'skills/a/SKILL.md': skill('a', `description: ${long}`) })), [3]);
  assert.deepEqual(rules(lint({ 'skills/a/SKILL.md': skill('a', 'description: Does things.') })), [3]);
  const manual = `description: ${'y'.repeat(121)}\ndisable-model-invocation: true`;
  assert.deepEqual(rules(lint({ 'skills/a/SKILL.md': skill('a', manual) })), [3]);
  const agent = `---\nname: r\ndescription: ${'z'.repeat(151)}\n---\nbody\n`;
  assert.deepEqual(rules(lint({ 'agents/r.md': agent })), [3]);
  const files = {};
  for (let i = 0; i < 6; i++) files[`skills/s${i}/SKILL.md`] = skill(`s${i}`, `description: Use when ${'w'.repeat(280)}`);
  assert.ok(rules(lint(files)).includes(3), 'auto total over 1,500');
});

test('rule 4: referenced files must exist', () => {
  const body = '\n## Steps\n\n1. Read `references/missing.md` and `${CLAUDE_PLUGIN_ROOT}/kernel/none.md`.\n';
  const f = lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.', body) });
  assert.deepEqual(rules(f), [4, 4]);
});

test('rule 8: machine paths and listed names in shipped files', () => {
  process.env.KERN_LINT_NAMES = 'Zebediah';
  const body = '\n## Steps\n\n1. Open /Users/someone/x and ask Zebediah.\n';
  try {
    const f = lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.', body) });
    assert.deepEqual(rules(f), [8, 8]);
  } finally {
    delete process.env.KERN_LINT_NAMES;
  }
});

test('rule 8: names come from scripts/lint-names.txt, comments ignored', () => {
  const body = '\n## Steps\n\n1. Ask Zebediah.\n';
  const f = lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.', body), 'scripts/lint-names.txt': '# personal names\nZebediah\n' });
  assert.deepEqual(rules(f), [8]);
  const g = lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.', body), 'scripts/lint-names.txt': '# Zebediah\n' });
  assert.deepEqual(rules(g), []);
});

test('rule 10: exemption needs a reason, and suppresses its finding', () => {
  const bad = { 'skills/a/SKILL.md': skill('a', 'description: Does things.'), 'scripts/lint-exemptions.json': '[{"rule":3,"path":"skills/a/SKILL.md","reason":""}]' };
  assert.deepEqual(rules(lint(bad)), [3, 10], 'an exemption without a reason suppresses nothing');
  const ok = { ...bad, 'scripts/lint-exemptions.json': '[{"rule":3,"path":"skills/a/SKILL.md","reason":"fixture"}]' };
  assert.deepEqual(rules(lint(ok)), []);
});

test('rule 11: long dashes and curly quotes', () => {
  const body = '\n## Steps\n\n1. Do this — then “that”.\n';
  assert.deepEqual(rules(lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.', body) })), [11, 11]);
});

test('rule 11: scans any non-binary shipped file, skips binaries', () => {
  assert.deepEqual(rules(lint({ 'hooks/lib/x.mjs': '// a — b\n' })), [11]);
  const f = lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.'), 'skills/a/logo.png': 'a — b' });
  assert.deepEqual(rules(f), []);
});

test('rule 4: existing references pass, repo-root fallback, anchors and ./', () => {
  const ok = '\n## Steps\n\n1. Read `references/ok.md` and `${CLAUDE_PLUGIN_ROOT}/kernel/k.md`.\n';
  assert.deepEqual(lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.', ok), 'skills/a/references/ok.md': 'x', 'kernel/k.md': 'x' }), []);
  const root = '\n## Steps\n\n1. Run `scripts/tool`.\n';
  assert.deepEqual(lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.', root), 'scripts/tool': 'x' }), []);
  const anchors = '\n## Steps\n\n1. See `references/ok.md#part`, `./references/ok.md` and [x](references/ok.md#x).\n';
  assert.deepEqual(lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.', anchors), 'skills/a/references/ok.md': 'x' }), []);
  const bad = '\n## Steps\n\n1. See `references/missing.md#part`.\n';
  assert.deepEqual(rules(lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.', bad) })), [4]);
});
