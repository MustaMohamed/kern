// tests/ci-local.test.mjs
// scripts/ci-local runs the Ubuntu CI job's steps, in the same order (audit F3), and ci.yml keeps its
// guards: actions pinned by SHA, a timeout on every job, one concurrency group, and the macOS job on
// demand and weekly.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const yml = readFileSync(new URL('../.github/workflows/ci.yml', import.meta.url), 'utf8');
const local = readFileSync(new URL('../scripts/ci-local', import.meta.url), 'utf8');

// jobs(text): { <job>: { keys, steps } } for ci.yml's layout: a job at two spaces, its keys at four, a
// step at six ("- "), step keys at eight, and the lines of a `run: |` block at ten.
function jobs(text) {
  const out = {};
  let job;
  let step;
  let block = null;
  for (const line of text.slice(text.indexOf('\njobs:\n') + 7).split('\n')) {
    if (block && (line === '' || line.startsWith(' '.repeat(10)))) {
      if (line) block.push(line.slice(10));
      continue;
    }
    block = null;
    let m;
    if ((m = line.match(/^ {2}([\w-]+):$/))) out[m[1]] = job = { keys: {}, steps: [] };
    else if ((m = line.match(/^ {4}([\w-]+):\s*(.*)$/))) job.keys[m[1]] = m[2];
    else if ((m = line.match(/^ {6}- ([\w-]+):\s*(.*)$/))) job.steps.push((step = { [m[1]]: m[2] }));
    else if ((m = line.match(/^ {8}([\w-]+):\s*(.*)$/))) {
      if (m[1] === 'run' && m[2] === '|') step.run = block = [];
      else step[m[1]] = m[2];
    }
  }
  return out;
}
const J = jobs(yml);
// The commands a job runs, but for its tool installs and the PR-only Unreleased check.
const commands = (job) => job.steps
  .filter((s) => s.run !== undefined && !/^Install /.test(s.name || '') && !/pull_request/.test(s.if || ''))
  .flatMap((s) => (Array.isArray(s.run) ? s.run : [s.run]));
// ci-local's commands: every line but the shebang, comments, set, cd, the Node check and the last echo.
const localCommands = local.split('\n').filter((l) => l && !/^(#|set |cd |node -e |echo )/.test(l));

test('ci-local runs the Ubuntu job\'s commands in the same order, shellcheck targets included', () => {
  assert.ok(localCommands.length >= 10, localCommands.join('\n'));
  assert.deepEqual(localCommands, commands(J.checks));
});

test('the macOS job runs only ci-local commands, with the bats files in parallel as on Ubuntu', () => {
  const mac = commands(J.macos);
  assert.deepEqual(mac.filter((c) => !localCommands.includes(c)), []);
  for (const c of ['tests/run-bats --jobs tests/scripts', 'tests/run-bats --jobs tests/hooks']) {
    assert.ok(mac.includes(c), c);
    assert.ok(localCommands.includes(c), c);
  }
});

test('every action is pinned by commit SHA, every job has a timeout, and one concurrency group holds the run', () => {
  const uses = Object.values(J).flatMap((j) => j.steps.map((s) => s.uses).filter(Boolean));
  assert.ok(uses.length >= 4);
  for (const u of uses) assert.match(u, /^[\w.-]+\/[\w.-]+@[0-9a-f]{40} # v\d+(\.\d+)*$/, u);
  assert.deepEqual(Object.keys(J).sort(), ['checks', 'install', 'macos']);
  for (const [name, j] of Object.entries(J)) assert.match(j.keys['timeout-minutes'] || '', /^\d+$/, name);
  assert.match(yml, /\nconcurrency:\n {2}group: ci-.+\n {2}cancel-in-progress: true\n/);
});

test('the Ubuntu jobs run on every push; the macOS job runs on workflow_dispatch and a weekly schedule', () => {
  const on = yml.slice(yml.indexOf('\non:\n'), yml.indexOf('\npermissions:'));
  assert.match(on, /\n {2}push:\n/);
  assert.match(on, /\n {2}workflow_dispatch:\n/);
  assert.match(on, /\n {2}schedule:\n {4}- cron: '\d+ \d+ \* \* [0-6]'\n/);
  assert.equal(J.checks.keys.if, undefined);
  assert.equal(J.install.keys.if, undefined);
  assert.equal(J.macos.keys.if, "github.event_name == 'workflow_dispatch' || github.event_name == 'schedule'");
});
