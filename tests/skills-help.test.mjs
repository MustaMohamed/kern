// help: frontmatter from skills spec B3 (description quoted for YAML), setup writes only after a yes.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { parseFrontmatter } from '../scripts/lib/frontmatter.mjs';

const dir = join(import.meta.dirname, '..', 'skills', 'help');
const src = readFileSync(join(dir, 'SKILL.md'), 'utf8');
const { data, body } = parseFrontmatter(src);

test('help frontmatter matches spec B3, description quoted', () => {
  assert.match(src, /^description: "Map of kern: which skill fits/m);
  assert.equal(data.description, "Map of kern: which skill fits, fixes for a run that went wrong, and help setup to write this project's settings.");
  assert.equal(data['disable-model-invocation'], 'true');
  assert.equal(data['argument-hint'], '[setup|check|<question>]');
  assert.match(data['allowed-tools'], /Bash\(bash \$\{CLAUDE_PLUGIN_ROOT\}\/scripts\/kern-detect \*\)/);
});

test('setup writes only after an explicit yes and never touches tracked files', () => {
  const setup = body.split('## Setup')[1].split('\n## ')[0];
  assert.match(setup, /Write it only after an explicit yes/);
  assert.match(setup, /Never edit `\.gitignore` or any tracked file/);
  assert.match(body, /Under autopilot, setup refuses/);
});

test('the template parses as kern settings and every key in it is documented', () => {
  const table = readFileSync(join(dir, '..', '..', 'kernel', 'settings.md'), 'utf8');
  const tpl = readFileSync(join(dir, 'templates', 'kern.local.yml'), 'utf8');
  const keys = [...tpl.matchAll(/^#? ?([a-z_][a-z0-9_.-]*): /gm)].map((m) => m[1]).filter((k) => !['One', 'Every'].includes(k));
  assert.ok(keys.length > 20);
  for (const k of keys) {
    const family = k.startsWith('overrides.') ? 'overrides.<job>' : k;
    assert.ok(table.includes(`| \`${family}\` |`), `${k} is in kernel/settings.md`);
  }
});

test('check compares keys with kernel/settings.md and names the floor keys the hooks ignore', () => {
  const check = body.split('## Check')[1];
  assert.match(check, /kernel\/settings\.md/);
  assert.match(check, /Do not rely on the kernel's Project settings block/);
  const table = readFileSync(join(dir, '..', '..', 'kernel', 'settings.md'), 'utf8');
  const actions = table.match(/Floor actions have no key and never loosen: ([^.]+)\./)[1];
  assert.ok(check.includes(actions), 'Check names the floor actions as kernel/settings.md lists them');
  const render = readFileSync(join(dir, '..', '..', 'hooks', 'lib', 'render.sh'), 'utf8');
  const floor = render.match(/^KERN_FLOOR_KEYS="([^"]+)"/m)[1].split(' ').sort();
  const named = [...check.matchAll(/`([a-z_]+\.policy)`/g)].map((m) => m[1]).sort();
  assert.deepEqual(named, floor);
});

test('setup defers the work dir to kern-dir; allowed-tools covers its read-only calls', () => {
  const setup = body.split('## Setup')[1].split('\n## ')[0];
  assert.match(setup, /bash \$\{CLAUDE_PLUGIN_ROOT\}\/scripts\/kern-dir [a-z]/);
  assert.doesNotMatch(body, /\/\.kern\//);
  const tools = data['allowed-tools'].split(', ');
  for (const t of ['Bash(git rev-parse --git-common-dir)', 'Bash(git check-ignore -q *)', 'Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-root *)']) assert.ok(tools.includes(t), t);
  assert.ok(!tools.some((t) => t.includes('kern-dir')), 'kern-dir writes, so setup step 6 keeps its permission prompt');
});

test('the template sets no key: every line is a comment or blank', () => {
  const tpl = readFileSync(join(dir, 'templates', 'kern.local.yml'), 'utf8');
  assert.doesNotMatch(tpl, /^[^#\n]/m);
});

test('help allows only the exact git commands it prescribes, so no wildcard can add a write or a program run', () => {
  assert.equal(
    data['allowed-tools'],
    'Read, Bash(git remote -v), Bash(git rev-parse --git-common-dir), Bash(git check-ignore -q *), Bash(git worktree list), ' +
      'Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect *), ' +
      'Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-root *)',
  );
  const git = data['allowed-tools'].split(', ').filter((t) => t.startsWith('Bash(git '));
  // The only wildcard over git is check-ignore -q, whose options only read; no other git entry ends in *.
  assert.deepEqual(git.filter((t) => t.endsWith('*)')), ['Bash(git check-ignore -q *)']);
});

test('setup never derives scope_threshold from a line cap, and names the measure pr.max_lines counts', () => {
  // Pilot fix plan Task 3 (MA-254): setup recommended 12 files after saying the project's file count is uncapped.
  assert.ok(body.includes("`scope_threshold` counts files; `pr.max_lines` counts insertions plus deletions from `git diff --shortstat`, tests included. Never derive one from the other, or from a project's own line cap."));
  assert.ok(body.includes('offer `pr.size_command`, a command whose last printed number is that count.'));
  const tpl = readFileSync(join(dir, 'templates', 'kern.local.yml'), 'utf8');
  assert.ok(tpl.includes('# tracker.first: true\n') && tpl.includes('# pr.max_lines: 300\n') && tpl.includes('# pr.size_command: scripts/pr-size {base} {tree}\n'));
});
