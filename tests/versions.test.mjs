import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, symlinkSync } from 'node:fs';
import { execFileSync, spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { checkVersions, checkUnreleased } from '../scripts/check-version.mjs';
import { bump, release } from '../scripts/release.mjs';

function repo({ plugin = '0.1.0', market = '0.1.0', changelog }) {
  const root = mkdtempSync(join(tmpdir(), 'kern-ver-'));
  mkdirSync(join(root, '.claude-plugin'));
  writeFileSync(join(root, '.claude-plugin/plugin.json'), JSON.stringify({ name: 'kern', version: plugin }, null, 2) + '\n');
  writeFileSync(join(root, '.claude-plugin/marketplace.json'), JSON.stringify({ name: 'kern', plugins: [{ name: 'kern', version: market, source: './' }] }, null, 2) + '\n');
  writeFileSync(join(root, 'CHANGELOG.md'), changelog ?? '# Changelog\n\n## [Unreleased]\n\n## [0.1.0] - 2026-10-12\n\n- First.\n');
  return root;
}

test('agreeing versions pass', () => {
  assert.deepEqual(checkVersions(repo({})), []);
});

test('manifest mismatch fails', () => {
  assert.equal(checkVersions(repo({ market: '0.2.0' })).length, 1);
});

test('no release heading is a clear failure', () => {
  const problems = checkVersions(repo({ changelog: '# Changelog\n\n## [Unreleased]\n' }));
  assert.match(problems[0], /no release heading/);
});

const LOG = (bullets) => `# Changelog\n\n## [Unreleased]\n\n${bullets.map((b) => `- ${b}\n`).join('')}\n## [0.1.0] - 2026-10-12\n\n- First.\n`;

test('a stale Unreleased bullet already in the base fails', () => {
  const root = repo({ changelog: LOG(['Old.']) });
  assert.equal(checkUnreleased(root, ['skills/a/SKILL.md'], LOG(['Old.'])).length, 1);
});

test('a newly added Unreleased bullet passes', () => {
  const root = repo({ changelog: LOG(['Old.', 'New.']) });
  assert.deepEqual(checkUnreleased(root, ['skills/a/SKILL.md'], LOG(['Old.'])), []);
});

test('an empty Unreleased section fails even with no base', () => {
  assert.equal(checkUnreleased(repo({}), ['skills/a/SKILL.md'], '').length, 1);
});

test('a non-shipped change passes without a bullet', () => {
  const root = repo({ changelog: LOG(['Old.']) });
  assert.deepEqual(checkUnreleased(root, ['README.md'], LOG(['Old.'])), []);
});

test('--pr compares HEAD changelog against the base ref', () => {
  const root = repo({ changelog: LOG(['Old.']) });
  mkdirSync(join(root, 'scripts/lib'), { recursive: true });
  const src = fileURLToPath(new URL('..', import.meta.url));
  for (const f of ['scripts/check-version.mjs', 'scripts/lib/is-main.mjs']) writeFileSync(join(root, f), readFileSync(join(src, f)));
  mkdirSync(join(root, 'skills/a'), { recursive: true });
  writeFileSync(join(root, 'skills/a/SKILL.md'), 'one\n');
  const git = (...a) => execFileSync('git', ['-C', root, '-c', 'user.email=t@t', '-c', 'user.name=t', ...a], { encoding: 'utf8' });
  git('init', '-q', '-b', 'main');
  git('add', '.');
  git('commit', '-q', '-m', 'base');
  git('branch', 'base');
  writeFileSync(join(root, 'skills/a/SKILL.md'), 'two\n');
  git('commit', '-q', '-am', 'change');
  const run = (...args) => spawnSync(process.execPath, [join(root, 'scripts/check-version.mjs'), ...args], { encoding: 'utf8' });
  assert.equal(run('--pr', 'base').status, 1);
  writeFileSync(join(root, 'CHANGELOG.md'), LOG(['Old.', 'New.']));
  git('commit', '-q', '-am', 'log');
  assert.equal(run('--pr', 'base').status, 0);
  const bare = run('--pr');
  assert.equal(bare.status, 2);
  assert.match(bare.stderr, /usage: check-version\.mjs \[--pr <base-ref>\]/);
});

test('bump follows semver', () => {
  assert.equal(bump('0.1.9', 'patch'), '0.1.10');
  assert.equal(bump('0.1.9', 'minor'), '0.2.0');
  assert.equal(bump('0.1.9', 'major'), '1.0.0');
});

test('release moves Unreleased bullets under the new version', () => {
  const root = repo({});
  writeFileSync(join(root, 'CHANGELOG.md'), '# Changelog\n\n## [Unreleased]\n\n- Add a.\n\n## [0.1.0] - 2026-10-12\n\n- First.\n');
  assert.equal(release(root, 'minor', '2026-11-01'), '0.2.0');
  const log = readFileSync(join(root, 'CHANGELOG.md'), 'utf8');
  assert.match(log, /## \[Unreleased\]\n\n## \[0\.2\.0\] - 2026-11-01\n\n- Add a\.\n/);
  assert.deepEqual(checkVersions(root), []);
});

test('release keeps sub-headings and wrapped lines', () => {
  const root = repo({});
  writeFileSync(join(root, 'CHANGELOG.md'), '# Changelog\n\n## [Unreleased]\n\n### Added\n\n- Add a,\n  wrapped.\n\n## [0.1.0] - 2026-10-12\n\n- First.\n');
  release(root, 'patch', '2026-11-02');
  assert.match(readFileSync(join(root, 'CHANGELOG.md'), 'utf8'), /## \[0\.1\.1\] - 2026-11-02\n\n### Added\n\n- Add a,\n  wrapped\.\n\n## \[0\.1\.0\]/);
});

test('release refuses an empty Unreleased section', () => {
  assert.throws(() => release(repo({}), 'patch', '2026-11-01'), /Unreleased is empty/);
});

test('CLI runs when reached through a symlink', () => {
  const tmp = mkdtempSync(join(tmpdir(), 'kern-link-'));
  symlinkSync(fileURLToPath(new URL('..', import.meta.url)), join(tmp, 'link'));
  const out = execFileSync(process.execPath, [join(tmp, 'link', 'scripts', 'check-version.mjs')], { encoding: 'utf8' });
  assert.match(out, /versions: agree/);
});
