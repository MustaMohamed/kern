// tests/lint-rules.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readdirSync, readFileSync } from 'node:fs';
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

// M1 rules: 6 (routes and help map), 7 (kernel size), 13 (settings keys), 15 (hook-shape fixtures).
const kernel = (rows) => `# kern {VERSION}\n\n## Routing\n| When | Route |\n|---|---|\n${rows.join('\n')}\n`;

test('rule 6: a route must exist and open with ## Steps', () => {
  const ok = lint({
    'kernel/kernel.md': kernel(['| Prose | Read {KERN}/tw/SKILL.md |', '| Phase ends | Read {ROOT}/kernel/context.md |']),
    'skills/tw/SKILL.md': skill('tw', 'description: d\ndisable-model-invocation: true'),
    'kernel/context.md': '# Context\n\n## Steps\n1. a\n',
  });
  assert.deepEqual(rules(ok), []);
  const zero = lint({
    'kernel/kernel.md': kernel(['| Prose | Read {KERN}/tw/SKILL.md |']),
    'skills/tw/SKILL.md': skill('tw', 'description: d\ndisable-model-invocation: true', '\n# tw\n\n## Steps\n\n0. Defer\n1. a\n'),
  });
  assert.deepEqual(rules(zero), [], 'a ## Steps list may start at 0.');
  const missing = lint({ 'kernel/kernel.md': kernel(['| Prose | Read {KERN}/nope/SKILL.md |']) });
  assert.deepEqual(rules(missing), [6]);
  const noSteps = lint({
    'kernel/kernel.md': kernel(['| Prose | Read {KERN}/tw/SKILL.md |']),
    'skills/tw/SKILL.md': skill('tw', 'description: d\ndisable-model-invocation: true', '\n# tw\n\n## Rules\n\n1. a\n'),
  });
  assert.deepEqual(rules(noSteps), [6]);
});

test('rule 6: every user-reachable skill is in the help map', () => {
  const map = '| Skill | Tier | Reached by | Job |\n|---|---|---|---|\n| `help` | slash | /kern:help | map |\n';
  const files = {
    'skills/help/SKILL.md': skill('help', 'description: d\ndisable-model-invocation: true'),
    'skills/help/references/map.md': map,
    'skills/mode/SKILL.md': skill('mode', 'description: d\ndisable-model-invocation: true'),
  };
  assert.deepEqual(rules(lint(files)), [6]);
  files['skills/help/references/map.md'] = map + '| `mode` | slash | /kern:mode | voice |\n';
  assert.deepEqual(rules(lint(files)), []);
});

test('rule 6: a route row in another form, or ## Steps without a numbered list, is an error', () => {
  const tw = { 'skills/tw/SKILL.md': skill('tw', 'description: d\ndisable-model-invocation: true') };
  const ticks = lint({ ...tw, 'kernel/kernel.md': kernel(['| Prose | Read `{KERN}/tw/SKILL.md` |']) });
  assert.deepEqual(rules(ticks), [6]);
  assert.match(ticks[0].message, /bare/);
  const trailing = lint({ 'kernel/kernel.md': kernel(['| Prose | Read {KERN}/nope/SKILL.md, then x |']) });
  assert.deepEqual(rules(trailing), [6]);
  assert.match(trailing[0].message, /bare/);
  const bullets = lint({
    'kernel/kernel.md': kernel(['| Prose | Read {KERN}/tw/SKILL.md |']),
    'skills/tw/SKILL.md': skill('tw', 'description: d\ndisable-model-invocation: true', '\n# tw\n\n## Steps\n\n- a\n'),
  });
  assert.deepEqual(rules(bullets), [6]);
  assert.match(bullets[0].message, /numbered list/);
});

test('rule 7: an oversized rendered kernel is an error; the real kernel passes', () => {
  const big = '#!/usr/bin/env bash\nhead -c 9500 /dev/zero | tr "\\0" x\n';
  const sub = '#!/usr/bin/env bash\nprintf \'{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"k"}}\'\n';
  assert.deepEqual(rules(lint({ 'hooks/session-start': big, 'hooks/subagent-start': sub })).filter((r) => r === 7), [7]);
  const real = runLint(loadModel(join(import.meta.dirname, '..'))).filter((f) => f.rule === 7 && f.level === 'error');
  assert.deepEqual(real, []);
});

test('rule 13: hooks and the settings table agree', () => {
  const table = '| Key | Default | Values | Read by |\n|---|---|---|---|\n| `push.policy` | `ask` | x | pre-tool-use (G1) |\n| `overrides.<job>` | none | x | session-start |\n';
  const hook = '#!/usr/bin/env bash\npolicy_for push\nsettings_get "overrides.$job" ""\n';
  assert.deepEqual(rules(lint({ 'kernel/settings.md': table, 'hooks/x': hook })), []);
  assert.deepEqual(rules(lint({ 'kernel/settings.md': table, 'hooks/x': hook + 'settings_get banana.key\n' })), [13]);
  assert.deepEqual(rules(lint({ 'kernel/settings.md': table + '| `orphan.key` | x | x | prompt-submit |\n', 'hooks/x': hook })), [13]);
});

test('rule 15: hook-shape fixtures and runner exist once hooks exist', () => {
  assert.ok(rules(lint({ 'hooks/session-start': '#!/usr/bin/env bash\n' })).includes(15));
  const real = runLint(loadModel(join(import.meta.dirname, '..'))).filter((f) => f.rule === 15);
  assert.deepEqual(real, []);
});

test('rule 13: _settings_lookup of a literal key is a read; the generic "$1" form is not', () => {
  const table = '| Key | Default | Values | Read by |\n|---|---|---|---|\n| `autopilot` | `allowed` | x | prompt-submit |\n';
  assert.deepEqual(rules(lint({ 'kernel/settings.md': table, 'hooks/x': '#!/usr/bin/env bash\n_settings_lookup "$f" autopilot\n' })), []);
  const generic = lint({ 'kernel/settings.md': table, 'hooks/x': '#!/usr/bin/env bash\n_settings_lookup "$f" "$1"\n' });
  assert.deepEqual(rules(generic), [13]);
  assert.match(generic[0].message, /^autopilot names a hook or kern script as reader, but none reads it$/);
});

test('rule 7: a session-start that fails or prints nothing is an error', () => {
  const sub = '#!/usr/bin/env bash\nprintf \'{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"k"}}\'\n';
  for (const start of ['#!/usr/bin/env bash\necho kernel\nexit 1\n', '#!/usr/bin/env bash\nexit 0\n']) {
    const f = lint({ 'hooks/session-start': start, 'hooks/subagent-start': sub }).filter((x) => x.rule === 7 && x.level === 'error');
    assert.deepEqual(f.map((x) => x.path), ['hooks/session-start']);
  }
});

test('rule 7: its temp directory is removed when a check throws', () => {
  const root = repo({ 'hooks/session-start': '#!/usr/bin/env bash\necho k\n', 'tests/fixtures/projects/long-settings/kern.local.yml/x': 'not a file' });
  const saved = process.env.TMPDIR;
  process.env.TMPDIR = mkdtempSync(join(tmpdir(), 'kern-lint-tmp-'));
  try {
    assert.throws(() => runLint(loadModel(root)));
    assert.deepEqual(readdirSync(process.env.TMPDIR), []);
  } finally {
    if (saved === undefined) delete process.env.TMPDIR;
    else process.env.TMPDIR = saved;
  }
});

test('rule 13: single-quoted keys are reads; a policy_for with a variable is an error', () => {
  const table = '| Key | Default | Values | Read by |\n|---|---|---|---|\n| `orphan.key` | x | x | prompt-submit |\n';
  assert.deepEqual(rules(lint({ 'kernel/settings.md': table, 'hooks/x': "#!/usr/bin/env bash\nsettings_get 'orphan.key'\n" })), []);
  assert.deepEqual(rules(lint({ 'kernel/settings.md': table, 'hooks/x': "#!/usr/bin/env bash\nsettings_get 'orphan.key'\nsettings_get 'banana.key'\n" })), [13]);
  const dyn = lint({ 'kernel/settings.md': table, 'hooks/x': '#!/usr/bin/env bash\nsettings_get orphan.key\npolicy_for "$action"\n' });
  assert.deepEqual(rules(dyn), [13]);
  assert.equal(dyn[0].path, 'hooks/x');
});

test("rule 13: a hook's need list names functions, so it reads no settings key", () => {
  const table = '| Key | Default | Values | Read by |\n|---|---|---|---|\n| `orphan.key` | x | x | prompt-submit |\n';
  const hook = '#!/usr/bin/env bash\nsettings_get orphan.key\nneed settings.sh settings_get settings_source policy_for kern_enabled\n';
  assert.deepEqual(rules(lint({ 'kernel/settings.md': table, 'hooks/x': hook })), []);
});

test('rule 15: every fixture case but no-settings carries a settings file', () => {
  const dir = join(import.meta.dirname, 'fixtures', 'projects');
  const files = { 'hooks/session-start': '#!/usr/bin/env bash\n', 'tests/hook-shape.sh': '#!/usr/bin/env bash\n' };
  for (const c of readdirSync(dir)) for (const f of readdirSync(join(dir, c))) files[`tests/fixtures/projects/${c}/${f}`] = readFileSync(join(dir, c, f), 'utf8');
  const only15 = () => rules(lint(files)).filter((r) => r === 15);
  assert.deepEqual(only15(), []);
  delete files['tests/fixtures/projects/long-settings/kern.local.yml'];
  assert.deepEqual(only15(), [15]);
});
