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
  for (const t of ['Bash(git rev-parse --git-common-dir)', 'Bash(git check-ignore -q *)', 'Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-root *)', 'Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/skill-conflicts *)']) assert.ok(tools.includes(t), t);
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
      'Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-root *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/skill-conflicts *)',
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

test('setup step 4 lists each skill that overlaps a job and records the pick', () => {
  const setup = body.split('## Setup')[1].split('\n## ')[0];
  const step = setup.split('\n4. ')[1].split('\n5. ')[0];
  for (const s of ['bash ${CLAUDE_PLUGIN_ROOT}/scripts/skill-conflicts', 'superpowers', 'plugin', "use that skill or keep kern's", 'recommended answer first', 'overrides.<job>: <skill>', 'overrides.<job>: off', "A job takes one pick: when several skills overlap it, ask which one or keep kern's.", "kern's guards still apply", "kern's routes only"]) assert.ok(step.includes(s), s);
  assert.doesNotMatch(body, /missing project skill/, 'check takes the user and plugin skills an override may name');
  const tpl = readFileSync(join(dir, 'templates', 'kern.local.yml'), 'utf8');
  assert.ok(tpl.includes('project, user or plugin skill') && tpl.includes('# overrides.define: off\n'));
  const table = readFileSync(join(dir, '..', '..', 'kernel', 'settings.md'), 'utf8');
  assert.ok(table.includes('| skill name, or `off` for no override'));
  assert.ok(table.includes('the same-name match is off | session-start, prompt-submit, skill-conflicts, every skill |'));
});

test('the status-line snippet reads the config dir, spaced keys and stdin with a timeout', async () => {
  // M3 part 2 project 1 Task 18, audit row L480, after caveman's statusline: CLAUDE_CONFIG_DIR moves the plugin
  // data dir, Claude Code may space its JSON keys, and a stdin pipe that never closes must not wedge the bar.
  const fix = readFileSync(join(dir, 'references', 'fix-a-run.md'), 'utf8');
  const snippet = fix.split('\n```bash\n')[1].split('\n```')[0];
  assert.ok(snippet.includes('${CLAUDE_PLUGIN_DATA:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/data/kern-kern}'), snippet);
  assert.match(snippet, /\bread -r -d '' -t 1 /);
  const { spawn } = await import('node:child_process');
  const { mkdtempSync, mkdirSync, writeFileSync, rmSync } = await import('node:fs');
  const { tmpdir } = await import('node:os');
  const cfg = mkdtempSync(join(tmpdir(), 'kern-statusline-'));
  try {
    mkdirSync(join(cfg, 'plugins', 'data', 'kern-kern', 'sessions'), { recursive: true });
    writeFileSync(join(cfg, 'plugins', 'data', 'kern-kern', 'sessions', 'abc-1.state'), 'autopilot: on\nvoice: terse\n');
    const env = { PATH: process.env.PATH, HOME: join(cfg, 'nohome'), CLAUDE_CONFIG_DIR: cfg };
    const run = (input) => new Promise((resolve) => {
      const child = spawn('bash', ['-c', snippet], { env });
      let out = '';
      const t0 = Date.now();
      child.stdout.on('data', (d) => { out += d; });
      // A snippet that reads stdin with no timeout would wait forever here; the kill turns that into a failure.
      const kill = setTimeout(() => child.kill(), 5000);
      child.on('close', () => { clearTimeout(kill); child.stdin.destroy(); resolve({ out, ms: Date.now() - t0 }); });
      if (input !== null) child.stdin.end(input);
    });
    const spaced = await run('{\n  "session_id" : "abc-1",\n  "cwd" : "/w"\n}\n');
    assert.equal(spaced.out, '[kern autopilot] [kern terse] ', 'a spaced "session_id" : " key under CLAUDE_CONFIG_DIR');
    assert.equal((await run('{"session_id":"abc-1"}')).out, '[kern autopilot] [kern terse] ', 'the compact form still reads');
    const open = await run(null);
    assert.equal(open.out, '', 'stdin that never closes prints nothing');
    assert.ok(open.ms < 5000, `the read times out: ${open.ms} ms`);
  } finally {
    rmSync(cfg, { recursive: true, force: true });
  }
});

test('every map row names its nearest sibling skill and where the line falls', () => {
  // M3 part 2 project 1 Task 18, audit row L481, after pocock's writing-docs: a trigger boundary against the
  // nearest sibling, "for <X> instead, use <sibling>".
  const map = readFileSync(join(dir, 'references', 'map.md'), 'utf8');
  assert.ok(map.includes('\n| Skill | Tier | Reached by | Job | Nearest sibling |\n|---|---|---|---|---|\n'), 'the header names the column');
  const rows = map.split('\n').filter((l) => /^\| `[a-z0-9-]+` \|/.test(l)).map((l) => l.split(' | '));
  const names = rows.map((c) => c[0].slice(3, -1));
  assert.ok(rows.length >= 16, `${rows.length} rows`);
  for (const c of rows) {
    assert.equal(c.length, 5, c.join(' | '));
    const m = c[4].match(/^`([a-z0-9-]+)` when (.+) \|$/);
    assert.ok(m, `the last cell names a sibling and when: ${c.join(' | ')}`);
    assert.ok(names.includes(m[1]) && m[1] !== c[0].slice(3, -1), `${m[1]} is another skill in the map`);
  }
});
