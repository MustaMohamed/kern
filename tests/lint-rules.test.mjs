// tests/lint-rules.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { cpSync, mkdtempSync, mkdirSync, writeFileSync, readdirSync, readFileSync, rmSync, symlinkSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { parseFrontmatter } from '../scripts/lib/frontmatter.mjs';
import { fileURLToPath } from 'node:url';
import { RULE7_REPO_LEN, fixedLengthRepo, loadModel, runLint } from '../scripts/lib/lint-rules.mjs';

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
  const agent = '---\nname: r\ndescription: d\npermissionMode: plan\n---\n## Report\n\nbody\n';
  assert.deepEqual(rules(lint({ 'agents/r.md': agent })), [2]);
});

test('rule 3: auto limit and trigger, manual limit, agent limit, totals', () => {
  const long = 'Use when ' + 'x'.repeat(300);
  assert.deepEqual(rules(lint({ 'skills/a/SKILL.md': skill('a', `description: ${long}`) })), [3]);
  assert.deepEqual(rules(lint({ 'skills/a/SKILL.md': skill('a', 'description: Does things.') })), [3]);
  const manual = `description: ${'y'.repeat(121)}\ndisable-model-invocation: true`;
  assert.deepEqual(rules(lint({ 'skills/a/SKILL.md': skill('a', manual) })), [3]);
  const agent = `---\nname: r\ndescription: ${'z'.repeat(151)}\n---\n## Report\n\nbody\n`;
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
// A stand-in session-start prints the header line rule 7 requires (builtins only); LONG is the fixture rule 7 copies in.
const HEADER = 'printf "In kern files read by path, \\${CLAUDE_PLUGIN_ROOT} means %s.\\n" "${0%/hooks/*}"\n';
const LONG = { 'tests/fixtures/projects/long-settings/kern.local.yml': 'mode.voice: normal\n' };

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
  assert.ok(lint({ 'hooks/session-start': big, 'hooks/subagent-start': sub }).some((f) => f.rule === 7 && f.level === 'error' && /limit 9,000/.test(f.message)));
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

test('rule 13: _settings_read of a literal key is a read, as _settings_lookup is', () => {
  const table = '| Key | Default | Values | Read by |\n|---|---|---|---|\n| `autopilot` | `allowed` | x | prompt-submit |\n';
  assert.deepEqual(rules(lint({ 'kernel/settings.md': table, 'hooks/x': '#!/usr/bin/env bash\n_settings_read "$f" autopilot\n' })), []);
  assert.deepEqual(rules(lint({ 'kernel/settings.md': table, 'hooks/x': '#!/usr/bin/env bash\n_settings_read "$f" autopilot\n_settings_read "$f" banana.key\n' })), [13]);
});

test('rule 7: a session-start that fails or prints nothing is an error', () => {
  const sub = '#!/usr/bin/env bash\nprintf \'{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"k"}}\'\n';
  for (const start of ['#!/usr/bin/env bash\necho kernel\nexit 1\n', '#!/usr/bin/env bash\nexit 0\n']) {
    const f = lint({ 'hooks/session-start': start, 'hooks/subagent-start': sub, ...LONG }).filter((x) => x.rule === 7 && x.level === 'error');
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

// M2a rules: 5 (Skill-tool and agent Read paths), 9 (required sections and Red flags), 16 (contract drift).
const manual = (desc = 'd') => `description: ${desc}\ndisable-model-invocation: true`;
const agentDoc = (body) => `---\nname: r\ndescription: d\n---\n${body}`;
const flags = (n) => `\n## Red flags\n\n| Thought | Reality |\n|---|---|\n${Array.from({ length: n }, (_, i) => `| t${i} | r${i} |`).join('\n')}\n`;

test('rule 5: Skill tool references name auto or built-in skills', () => {
  const caller = (target) => skill('c', manual(), `\n# c\n\n## Steps\n\n1. Call the Skill tool with \`${target}\`.\n`);
  assert.deepEqual(rules(lint({ 'skills/c/SKILL.md': caller('nope') })), [5]);
  assert.deepEqual(rules(lint({ 'skills/c/SKILL.md': caller('code-review') })), []);
  assert.deepEqual(rules(lint({ 'skills/c/SKILL.md': caller('kern:a'), 'skills/a/SKILL.md': skill('a', 'description: Use when x.') })), []);
  assert.deepEqual(rules(lint({ 'skills/c/SKILL.md': caller('p'), 'skills/p/SKILL.md': skill('p', manual()) })), [5]);
});

test('rule 5: the kernel and agents are scanned, fenced blocks included', () => {
  assert.deepEqual(rules(lint({ 'kernel/kernel.md': 'Use the Skill tool with `nope`.\n' })), [5]);
  const fenced = '\n# c\n\n## Steps\n\n1. a\n\n```\nSkill tool with `nope`\n```\n';
  assert.deepEqual(rules(lint({ 'skills/c/SKILL.md': skill('c', manual(), fenced) })), [5]);
  const fencedAgent = '## Report\n\n```\nRead ${CLAUDE_PLUGIN_ROOT}/skills/missing/SKILL.md\n```\n';
  assert.deepEqual(rules(lint({ 'agents/r.md': agentDoc(fencedAgent) })), [5]);
  assert.deepEqual(rules(lint({ 'agents/r.md': agentDoc('## Report\n\nSkill tool with `nope`\n') })), [5]);
});

test('rule 5: agent Read paths resolve', () => {
  const body = '## Report\n\nRead `${CLAUDE_PLUGIN_ROOT}/skills/missing/SKILL.md`.\n';
  assert.deepEqual(rules(lint({ 'agents/r.md': agentDoc(body) })), [5]);
  const ok = { 'agents/r.md': agentDoc('## Report\n\nRead `${CLAUDE_PLUGIN_ROOT}/skills/a/SKILL.md`.\n'), 'skills/a/SKILL.md': skill('a', 'description: Use when x.') };
  assert.deepEqual(rules(lint(ok)), []);
});

test('rule 9: auto skills need Steps; slash skills need Steps first', () => {
  assert.deepEqual(rules(lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.', '\n# a\n\n## Notes\n\nx\n') })), [9]);
  assert.deepEqual(rules(lint({ 'skills/s/SKILL.md': skill('s', manual(), '\n# s\n\n## Inputs\n\nx\n\n## Steps\n\n1. a\n') })), [9]);
  assert.deepEqual(rules(lint({ 'skills/s/SKILL.md': skill('s', manual(), '\n# s\n\nRules only.\n') })), [9]);
  assert.deepEqual(rules(lint({ 'skills/s/SKILL.md': skill('s', manual()) })), []);
});

test('rule 9: Steps must be an H2 outside a fence and not a longer heading', () => {
  const fenced = '\n# a\n\n```md\n## Steps\n```\n';
  assert.deepEqual(rules(lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.', fenced) })), [9]);
  const tilde = '\n# a\n\n~~~\n## Steps\n~~~\n';
  assert.deepEqual(rules(lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.', tilde) })), [9]);
  assert.deepEqual(rules(lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.', '\n# a\n\n## Steps and more\n\n1. a\n') })), [9]);
  assert.deepEqual(rules(lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.', '\n# a\n\n### Steps\n\n1. a\n') })), [9]);
});

test('rule 9: an unclosed fence is reported, not read as a pass', () => {
  const body = '\n# a\n\n## Steps\n\n1. a\n\n```\nnever closed\n';
  const f = lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.', body) }).filter((x) => x.rule === 9);
  assert.equal(f.length, 1);
  assert.match(f[0].message, /unclosed code fence/);
});

test('rule 9: CRLF files are read like LF files', () => {
  const crlf = (t) => t.replace(/\n/g, '\r\n');
  assert.deepEqual(rules(lint({ 'skills/s/SKILL.md': crlf(skill('s', manual())) })), []);
  assert.deepEqual(rules(lint({ 'skills/s/SKILL.md': crlf(skill('s', manual(), '\n# s\n\n## Inputs\n\nx\n\n## Steps\n\n1. a\n')) })), [9]);
  assert.deepEqual(rules(lint({ 'agents/r.md': crlf(agentDoc('## Report\n\nbody\n')) })), []);
  const body = `\n# implement\n\n## Steps\n\n1. a\n${flags(3)}`;
  assert.deepEqual(rules(lint({ 'skills/implement/SKILL.md': crlf(skill('implement', manual(), body)) })), []);
});

test('rule 9: a slash skill without Steps passes with an exemption', () => {
  const files = {
    'skills/s/SKILL.md': skill('s', manual(), '\n# s\n\nRules only.\n'),
    'scripts/lint-exemptions.json': '[{"rule":9,"path":"skills/s/SKILL.md","reason":"rule document, not a procedure"}]',
  };
  assert.deepEqual(rules(lint(files)), []);
});

test('rule 9: agents need an output contract section', () => {
  assert.deepEqual(rules(lint({ 'agents/r.md': agentDoc('Just do it.\n') })), [9]);
  assert.deepEqual(rules(lint({ 'agents/r.md': agentDoc('## Output\n\nVerdict first.\n') })), []);
  assert.deepEqual(rules(lint({ 'agents/r.md': agentDoc('```\n## Report\n```\n') })), [9]);
  assert.deepEqual(rules(lint({ 'agents/r.md': agentDoc('## Reports\n\nx\n') })), [9]);
});

test('rule 9: a discipline skill needs a Red flags table of 2 to 6 rows', () => {
  const body = (extra) => `\n# implement\n\n## Steps\n\n1. a\n${extra}`;
  assert.deepEqual(rules(lint({ 'skills/implement/SKILL.md': skill('implement', manual(), body('')) })), [9]);
  assert.deepEqual(rules(lint({ 'skills/implement/SKILL.md': skill('implement', manual(), body(flags(1))) })), [9]);
  assert.deepEqual(rules(lint({ 'skills/implement/SKILL.md': skill('implement', manual(), body(flags(7))) })), [9]);
  assert.deepEqual(rules(lint({ 'skills/implement/SKILL.md': skill('implement', manual(), body(flags(2))) })), []);
  assert.deepEqual(rules(lint({ 'skills/implement/SKILL.md': skill('implement', manual(), body(flags(6))) })), []);
  assert.deepEqual(rules(lint({ 'skills/implement/SKILL.md': skill('implement', manual(), body(flags(3))) })), []);
  assert.deepEqual(rules(lint({ 'skills/other/SKILL.md': skill('other', manual(), body('')) })), [], 'only discipline skills need the table');
});

test('rule 9: Red flags must be a real H2 with the Thought | Reality header', () => {
  const body = (extra) => `\n# implement\n\n## Steps\n\n1. a\n${extra}`;
  const run = (extra) => rules(lint({ 'skills/implement/SKILL.md': skill('implement', manual(), body(extra)) }));
  assert.deepEqual(run(`\n\`\`\`md${flags(3)}\`\`\`\n`), [9], 'a fenced table does not count');
  assert.deepEqual(run(flags(3).replace('## Red flags', '## Red flags and more')), [9], 'a longer heading does not count');
  assert.deepEqual(run(flags(3).replace('## Red flags', '### Red flags')), [9], 'an H3 does not count');
  assert.deepEqual(run(flags(3).replace('| Thought | Reality |', '| Excuse | Truth |')), [9], 'wrong header');
  assert.deepEqual(run(flags(3).replace('|---|---|\n', '')), [9], 'no separator row');
  assert.deepEqual(run(`${flags(1)}\n## Other\n\n| a | b |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |\n`), [9], 'rows after the next H2 do not count');
});

test('rule 16: scripts, WORK folders and ledger lines a skill names have a producer in the contract', () => {
  const contract = '| `wt-snap` | x |\n- `WORK/plans/`\n- `Task N: start tree=<id> at=<iso>`\n';
  const body = (s) => `\n# c\n\n## Steps\n\n1. ${s}\n`;
  const ok = body('Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-snap <wt>` and read WORK/plans; then `Task N: start tree=<id> at=<iso>`.');
  assert.deepEqual(rules(lint({ 'docs/plans/contract.md': contract, 'skills/c/SKILL.md': skill('c', manual(), ok), 'scripts/wt-snap': '' })), []);
  const bad = body('Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/wt-gone <wt>`, read WORK/drafts and write `Task N: done`.');
  const f = lint({ 'docs/plans/contract.md': contract, 'skills/c/SKILL.md': skill('c', manual(), bad), 'scripts/wt-gone': '' }).filter((x) => x.rule === 16);
  assert.deepEqual(f.map((x) => x.message.split(':')[0]), ['scripts/wt-gone', 'WORK/drafts', 'Task N']);
});

test('rule 16: a ledger line spelled `Task <N>` is looked up as `Task N`', () => {
  const contract = '- `Task N: start tree=<id> at=<iso>`\n- `Task N: complete`\n';
  const run = (text) => lint({ 'docs/plans/contract.md': contract, 'skills/c/SKILL.md': skill('c', manual(), `\n# c\n\n## Steps\n\n1. ${text}\n`) }).filter((x) => x.rule === 16).map((x) => x.message.split(':').slice(0, 2).join(':'));
  assert.deepEqual(run('Write `Task <N>: start tree=<id> at=<iso>` and find a `Task <N>: complete` line.'), []);
  assert.deepEqual(run('Write `Task <N>: done tree=<id>`.'), ['Task <N>: done tree=<id>'], 'drift in the angle-bracket spelling is caught');
  assert.deepEqual(run('Find a `Task <N>: complete tree=<id> ...` line.'), ['Task <N>: complete tree=<id> ...']);
});

test('rule 16: silent without a contract file; agents, references, CRLF handled; fenced blocks are read', () => {
  const body = '\n# c\n\n## Steps\n\n1. Read WORK/drafts.\n';
  assert.deepEqual(rules(lint({ 'skills/c/SKILL.md': skill('c', manual(), body) })), []);
  const contract = '- `WORK/plans/`\n';
  const run = (files) => lint({ 'docs/plans/contract.md': contract, ...files }).filter((x) => x.rule === 16).map((x) => x.path);
  assert.deepEqual(run({ 'agents/r.md': agentDoc('## Report\n\nRead WORK/drafts.\n') }), ['agents/r.md']);
  assert.deepEqual(run({ 'skills/c/SKILL.md': skill('c', manual()), 'skills/c/references/x.md': 'Read WORK/drafts.\n' }), ['skills/c/references/x.md']);
  const crlfContract = contract.replace(/\n/g, '\r\n');
  const crlfSkill = skill('c', manual(), '\n# c\n\n## Steps\n\n1. Read WORK/plans and `Task N: start`.\n').replace(/\n/g, '\r\n');
  assert.deepEqual(lint({ 'docs/plans/contract.md': crlfContract + '- `Task N: start`\r\n', 'skills/c/SKILL.md': crlfSkill }).filter((x) => x.rule === 16), []);
  const fenced = '\n# c\n\n## Steps\n\n1. a\n\n```\nRead WORK/drafts and `Task N: done`\n```\n';
  assert.deepEqual(run({ 'skills/c/SKILL.md': skill('c', manual(), fenced) }), ['skills/c/SKILL.md', 'skills/c/SKILL.md'], 'WORK folder and ledger line');
  const fencedScript = '\n# c\n\n## Steps\n\n1. a\n\n```bash\nbash ${CLAUDE_PLUGIN_ROOT}/scripts/x\n```\n';
  assert.deepEqual(run({ 'skills/c/SKILL.md': skill('c', manual(), fencedScript), 'scripts/x': '' }), ['skills/c/SKILL.md']);
});

// Fence parser (scanMarkdown), pinned through rule 9: it reads headings outside fences only.
test('fence parser: a fence closed by the other marker stays open and is reported', () => {
  const f = lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.', '\n# a\n\n## Steps\n\n1. a\n\n```\nx\n~~~\n') }).filter((x) => x.rule === 9);
  assert.equal(f.length, 1);
  assert.match(f[0].message, /unclosed code fence/);
});

test('fence parser: a longer fence holds a shorter fence line', () => {
  const run = (body) => rules(lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.', body) }));
  assert.deepEqual(run('\n# a\n\n````\n```\n````\n\n## Steps\n\n1. a\n'), []);
  assert.deepEqual(run('\n# a\n\n````\n```\n## Steps\n````\n'), [9], 'the heading inside the long fence is hidden');
});

test('fence parser: an opener indented 0 to 3 spaces counts, 4 does not', () => {
  const run = (open) => rules(lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.', `\n# a\n\n${open}\n## Steps\n\n1. a\n${open}\n`) }));
  assert.deepEqual(run('```'), [9]);
  assert.deepEqual(run('   ```'), [9]);
  assert.deepEqual(run('    ```'), [], 'a 4-space indent is code, not a fence');
});

test('rule 16: a script name is read whole, dots, slashes and underscores included', () => {
  const body = (name) => `\n# c\n\n## Steps\n\n1. Run \`bash \${CLAUDE_PLUGIN_ROOT}/scripts/${name}\`.\n`;
  const run = (contract, name) => lint({ 'docs/plans/contract.md': contract, 'skills/c/SKILL.md': skill('c', manual(), body(name)) }).filter((x) => x.rule === 16).map((x) => x.message.split(':')[0]);
  assert.deepEqual(run('| `lint-skills.mjs` | x |\n', 'lint-skills.mjs'), []);
  assert.deepEqual(run('| `lint-skills` | x |\n', 'lint-skills.mjs'), ['scripts/lint-skills.mjs']);
  assert.deepEqual(run('| `wt-snap` | x |\n', 'lib/wt-common.sh'), ['scripts/lib/wt-common.sh']);
  assert.deepEqual(run('| `foo_bar` | x |\n', 'foo_bar'), []);
  assert.deepEqual(run('| `foo` | x |\n', 'foo_bar'), ['scripts/foo_bar']);
  assert.deepEqual(run('| `wt-snap` | x |\n', 'wt-snap.'), [], 'trailing sentence punctuation is not part of the name');
});

test('rule 16: a WORK folder is read whole, in any case', () => {
  const run = (text) => lint({ 'docs/plans/contract.md': '- `WORK/spec/`\n- `WORK/plans/`\n', 'skills/c/SKILL.md': skill('c', manual(), `\n# c\n\n## Steps\n\n1. ${text}\n`) }).filter((x) => x.rule === 16).map((x) => x.message.split(':')[0]);
  assert.deepEqual(run('Write WORK/spec-2/x.'), ['WORK/spec-2']);
  assert.deepEqual(run('Write WORK/Plan.'), ['WORK/Plan']);
  assert.deepEqual(run('Write WORK/spec/x.md and WORK/plans.'), []);
});

// Homebrew bash 5.3.15 segfaults now and then when a subshell undoes a locale change while neither LANG
// nor LC_ALL is set (Tasks 16l and 16m).
test('rule 17: each locale change bash must undo, in a hook file, is an error', () => {
  const bad = [
    'f() { local LC_ALL; }',
    'f() { local LC_ALL=C; }',
    'f() { local x LANG=C; }',
    'f() { declare LC_CTYPE=C; }',
    'LC_ALL=C awk 1 f',
    'x=$(LC_ALL=C awk 1 f 2>/dev/null)',
    'printf x | LC_ALL=C tr a b',
    'v="$(printf x | LC_ALL=C tr a b)"',
    'K="${K-}" FOO="a b" LC_ALL=C awk 1 f',
    'LC_ALL=C FOO=1 awk 1 f',
    'LC_ALL=C \\\n  awk 1 f',
    'if LC_ALL=C grep -q x f; then :; fi',
    'case $x in a) LC_ALL=C sed 1q f ;; esac',
    'LANG=C sort f',
    'LC_ALL=C env awk 1 f',
  ];
  for (const line of bad) {
    const found = lint({ 'hooks/lib/x.sh': `# shellcheck shell=bash\n${line}\n` }).filter((f) => f.rule === 17);
    assert.equal(found.length, 1, line);
    assert.equal(found[0].path, 'hooks/lib/x.sh');
    assert.match(found[0].message, /^line 2: (local [A-Z_]+, which bash undoes at the function's return|[A-Z_]+= before a command, which bash undoes after it), and bash 5\.3 can crash undoing it while LANG and LC_ALL are unset; use env LC_ALL=C <command>$/, line);
  }
});

test('rule 17: env, plain and exported assignments, comments and quoted text are not locale changes bash undoes', () => {
  const good = [
    'env LC_ALL=C awk 1 f',
    'x=$(FOO=1 env LC_ALL=C awk 1 f 2>/dev/null)',
    'printf x | env LC_ALL=C tr a b',
    '[ -n "${LANG-}${LC_ALL-}" ] || export LANG=C',
    'LC_ALL=C',
    'LC_ALL=C; awk 1 f',
    'LC_ALL=C FOO=1',
    'f() { local saved=$LANG; }',
    '# local LC_ALL=C makes bash undo it, and so does LC_ALL=C awk',
    'echo "LC_ALL=C awk is not run here" \'local LC_ALL\'',
    'echo ${x:-LC_ALL=C awk}',
  ];
  for (const line of good) assert.deepEqual(rules(lint({ 'hooks/lib/x.sh': `# shellcheck shell=bash\n${line}\n` })), [], line);
});

test('rule 17 reads the scripts a hook names, and an exemption with a reason covers a site', () => {
  const s = '#!/usr/bin/env bash\nLC_ALL=C awk 1 f\n';
  const hook = '#!/usr/bin/env bash\nbash "$KERN_ROOT/scripts/kern-detect" a\nawk -f "$KERN_ROOT/scripts/lib/f.awk" x\n';
  const files = { 'hooks/x': hook, 'scripts/kern-detect': s, 'scripts/other': s, 'scripts/lib/f.awk': 'LC_ALL=C x\n' };
  assert.deepEqual(lint(files).filter((f) => f.rule === 17).map((f) => f.path), ['scripts/kern-detect']);
  const exempt = { ...files, 'scripts/lint-exemptions.json': '[{"rule":17,"path":"scripts/kern-detect","reason":"runs in the main shell only"}]' };
  assert.deepEqual(rules(lint(exempt)), []);
});

// Since Task 16d every route row is in the kernel table; M2a's kernel/routes.md is gone.
test('rule 6: the kernel table\'s rows resolve, and rows left in kernel/routes.md are an error', () => {
  const files = {
    'kernel/kernel.md': kernel(['| Bug | Read {KERN}/d/SKILL.md |', '| Prose | Read {KERN}/tw/SKILL.md |']),
    'skills/tw/SKILL.md': skill('tw', manual()),
    'skills/d/SKILL.md': skill('d', manual()),
  };
  assert.deepEqual(rules(lint(files)), []);
  assert.equal(loadModel(repo(files)).skills.find((s) => s.name === 'd').tier, 'path', 'a skill a kernel row routes to is a path skill');
  assert.deepEqual(rules(lint({ ...files, 'kernel/kernel.md': kernel(['| Bug | Read {KERN}/gone/SKILL.md |']) })), [6]);
  const left = { ...files, 'kernel/kernel.md': kernel(['| Prose | Read {KERN}/tw/SKILL.md |']), 'kernel/routes.md': '| Bug | Read {KERN}/d/SKILL.md |\n' };
  const f = lint(left);
  assert.deepEqual(rules(f), [6]);
  assert.equal(f[0].message, 'kernel/routes.md holds route rows, which no session reads; move them into the kernel table');
  assert.equal(loadModel(repo(left)).skills.find((s) => s.name === 'd').tier, 'slash', 'a row left in routes.md routes nothing');
});

test('rule 7: the route rows count in the standing cost, which has a combined budget', () => {
  // The real hooks render the kernel, rows and all: every session reads them, so a long table fails the budget.
  const head = 'In kern files read by path, ${CLAUDE_PLUGIN_ROOT} means {ROOT}.\n';
  const fixture = (n) => {
    const root = repo({ 'kernel/kernel.md': head + kernel(Array.from({ length: n }, (_, i) => `| Row ${i} ${'w'.repeat(100)} | Read {KERN}/tw/SKILL.md |`)), 'skills/tw/SKILL.md': skill('tw', manual()), ...LONG });
    for (const d of ['hooks', 'modes', '.claude-plugin', 'kernel/kernel-subagent.md']) cpSync(join(import.meta.dirname, '..', d), join(root, d), { recursive: true });
    return runLint(loadModel(root)).filter((x) => x.rule === 7 && x.level === 'error');
  };
  assert.deepEqual(fixture(2), []);
  assert.ok(fixture(50).some((x) => /^standing cost \d+ chars \(kernel with no settings \d+, /.test(x.message)), JSON.stringify(fixture(50)));
  const sub = '#!/usr/bin/env bash\nprintf \'{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"k"}}\'\n';
  const start = (n) => `#!/usr/bin/env bash\n${HEADER}head -c ${n} /dev/zero | tr "\\0" x\n`;
  const desc = `description: Use when ${'w'.repeat(280)}.`;
  const files = (n) => ({ 'hooks/session-start': start(n), 'hooks/subagent-start': sub, 'skills/a/SKILL.md': skill('a', desc), ...LONG });
  assert.deepEqual(rules(lint(files(5858))).filter((r) => r === 7), []);
  const big = lint(files(5878)).filter((f) => f.rule === 7 && f.level === 'error');
  assert.equal(big.length, 1);
  assert.match(big[0].message, /^standing cost 6278 chars/);
});


const caseJson = (name, p = 3, n = 2, e = 1) => JSON.stringify({
  skill_name: name,
  trigger: { positive: Array.from({ length: p }, (_, i) => ({ prompt: `p${i}` })), negative: Array.from({ length: n }, (_, i) => ({ prompt: `n${i}` })) },
  evals: Array.from({ length: e }, (_, i) => ({ id: i + 1, kind: 'dialogue', prompt: 'x', expected_output: 'y', expectations: ['z'] })),
});

test('rule 12: auto skills and kernel rows need eval cases once evals/cases exists', () => {
  const base = { 'skills/a/SKILL.md': skill('a', 'description: Use when x.') };
  assert.deepEqual(rules(lint(base)), [], 'no evals/cases folder: rule 12 is silent');
  assert.deepEqual(rules(lint({ ...base, 'evals/cases/other.json': caseJson('other') })), [12]);
  assert.deepEqual(rules(lint({ ...base, 'evals/cases/a.json': caseJson('a', 2) })), [12]);
  assert.deepEqual(rules(lint({ ...base, 'evals/cases/a.json': caseJson('a') })), []);
  const routed = { ...base, 'evals/cases/a.json': caseJson('a'), 'kernel/kernel.md': '| Bug | Read {KERN}/d/SKILL.md |\n', 'skills/d/SKILL.md': skill('d', 'description: d\ndisable-model-invocation: true') };
  assert.deepEqual(rules(lint(routed)), [12]);
  assert.deepEqual(rules(lint({ ...routed, 'evals/cases/row-d.json': caseJson('row-d') })), []);
});

test('rule 7: a session-start that fails without project settings is an error, not a low standing cost', () => {
  const sub = '#!/usr/bin/env bash\nprintf \'{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"k"}}\'\n';
  const once = `#!/usr/bin/env bash\nmkdir -p "$CLAUDE_PLUGIN_DATA"\n[ -e "$CLAUDE_PLUGIN_DATA/ran" ] && exit 1\ntouch "$CLAUDE_PLUGIN_DATA/ran"\n${HEADER}`;
  const f = lint({ 'hooks/session-start': once, 'hooks/subagent-start': sub, ...LONG }).filter((x) => x.rule === 7 && x.level === 'error');
  assert.equal(f.length, 1);
  assert.match(f[0].message, /standing cost was not measured/);
});

test('rule 12: a case file that is not valid JSON is an error', () => {
  const f = lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.'), 'evals/cases/a.json': '{' });
  assert.deepEqual(rules(f), [12]);
  assert.match(f[0].message, /^evals\/cases\/a\.json is not valid JSON: /);
});

test('rule 12: a model-graded negative does not count toward the minimum of 2', () => {
  const base = { 'skills/a/SKILL.md': skill('a', 'description: Use when x.') };
  const withNegatives = (negative) => JSON.stringify({ ...JSON.parse(caseJson('a')), trigger: { positive: [{ prompt: 'p0' }, { prompt: 'p1' }, { prompt: 'p2' }], negative } });
  assert.deepEqual(rules(lint({ ...base, 'evals/cases/a.json': withNegatives([{ prompt: 'n0' }, { prompt: 'n1', grader: 'model' }]) })), [12]);
  assert.deepEqual(rules(lint({ ...base, 'evals/cases/a.json': withNegatives([{ prompt: 'n0' }, { prompt: 'n1' }, { prompt: 'n2', grader: 'model' }]) })), []);
});

// Fix round 1: rule 7 reads only a real render, and rules 6 and 12 close the gaps the review found.
const SUB = '#!/usr/bin/env bash\nprintf \'{"hookSpecificOutput":{"hookEventName":"SubagentStart","additionalContext":"k"}}\'\n';

test('rule 7: a render without the kernel header line is an error, not a low standing cost', () => {
  const broken = '#!/usr/bin/env bash\necho "kern did not load: hooks/lib/render.sh is missing or broken; reinstall kern"\n';
  const f = lint({ 'hooks/session-start': broken, 'hooks/subagent-start': SUB, ...LONG }).filter((x) => x.rule === 7 && x.level === 'error');
  assert.deepEqual(f.map((x) => x.path), ['hooks/session-start']);
  assert.match(f[0].message, /no "\$\{CLAUDE_PLUGIN_ROOT\} means <root>\." header line, so the kernel was not measured$/);
  assert.deepEqual(lint({ 'hooks/session-start': `#!/usr/bin/env bash\n${HEADER}`, 'hooks/subagent-start': SUB, ...LONG }).filter((x) => x.rule === 7), []);
  const exit3 = lint({ 'hooks/session-start': `#!/usr/bin/env bash\n${HEADER}exit 3\n`, 'hooks/subagent-start': SUB, ...LONG }).filter((x) => x.rule === 7 && x.level === 'error');
  assert.equal(exit3.length, 1, 'a header with a non-zero exit is not a render');
  assert.match(exit3[0].message, /^exited 3 with \d+ chars of output, so the kernel was not measured$/);
});

test('rule 7: a missing long-settings fixture is an error', () => {
  const f = lint({ 'hooks/session-start': `#!/usr/bin/env bash\n${HEADER}`, 'hooks/subagent-start': SUB }).filter((x) => x.rule === 7 && x.level === 'error');
  assert.deepEqual(f.map((x) => x.path), ['tests/fixtures/projects/long-settings']);
});

test('rule 7: a git init that fails is an error', () => {
  const bin = mkdtempSync(join(tmpdir(), 'kern-lint-bin-'));
  symlinkSync(spawnSync('bash', ['-c', 'command -v bash'], { encoding: 'utf8' }).stdout.trim(), join(bin, 'bash'));
  const saved = process.env.PATH;
  process.env.PATH = bin;
  try {
    const f = lint({ 'hooks/session-start': `#!/usr/bin/env bash\n${HEADER}`, 'hooks/subagent-start': SUB, ...LONG }).filter((x) => x.rule === 7 && x.level === 'error');
    assert.ok(f.some((x) => /^git init exited /.test(x.message)), JSON.stringify(f));
  } finally {
    process.env.PATH = saved;
  }
});

test('rule 6: a row that routes to kernel/routes.md is an error', () => {
  const f = lint({ 'kernel/kernel.md': kernel(['| More | Read {ROOT}/kernel/routes.md |']), 'kernel/routes.md': '# routes\n' });
  assert.deepEqual(rules(f), [6]);
  assert.equal(f[0].message, 'kernel/routes.md is not a route: route rows live in the kernel table');
});

test('rule 12: a positive that carries the grader flag is an error', () => {
  const base = { 'skills/a/SKILL.md': skill('a', 'description: Use when x.') };
  const flagged = JSON.stringify({ ...JSON.parse(caseJson('a')), trigger: { positive: [{ prompt: 'p0' }, { prompt: 'p1' }, { prompt: 'p2', grader: 'model' }], negative: [{ prompt: 'n0' }, { prompt: 'n1' }] } });
  const f = lint({ ...base, 'evals/cases/a.json': flagged });
  assert.deepEqual(rules(f), [12]);
  assert.match(f[0].message, /positive.*"grader"/);
});

test('tiers: a Read in prose, not in a row, does not make a path skill', () => {
  const root = repo({ 'kernel/kernel.md': 'Then Read {KERN}/d/SKILL.md first.\n', 'skills/d/SKILL.md': skill('d', manual()) });
  assert.equal(loadModel(root).skills.find((s) => s.name === 'd').tier, 'slash');
});

test('rule 5: the kernel is scanned for Skill tool references', () => {
  assert.deepEqual(rules(lint({ 'kernel/kernel.md': 'Use the Skill tool with `nope`.\n' })), [5]);
});

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');

test('rule 7 renders from a repo path of one fixed length, so the temp dir does not move the measurement', () => {
  const short = mkdtempSync('/tmp/k-');
  const long = mkdtempSync(join(tmpdir(), 'kern-rule7-longer-temp-dir-name-'));
  try {
    for (const t of [short, long]) assert.equal(fixedLengthRepo(t).length, RULE7_REPO_LEN, t);
    const lint = (dir) => spawnSync(process.execPath, [join(ROOT, 'scripts', 'lint-skills.mjs')], { encoding: 'utf8', env: { ...process.env, TMPDIR: dir } }).stdout;
    assert.equal(lint(short), lint(long));
  } finally { rmSync(short, { recursive: true, force: true }); rmSync(long, { recursive: true, force: true }); }
});
