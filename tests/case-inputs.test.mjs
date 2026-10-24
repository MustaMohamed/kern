// tests/case-inputs.test.mjs: what each eval case reads (scripts/lib/case-inputs.mjs), the input hash the cache
// keys on and the --changed selection, on a small kern-shaped git repo.
import { after, test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { chmodSync, cpSync, mkdirSync, mkdtempSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { blobSha, caseInputs, changedCases, dirHash, rangeSources, skillClosure, skillHashes, touchedSkills, treeSource } from '../scripts/lib/case-inputs.mjs';

const made = [];
after(() => { for (const d of made) rmSync(d, { recursive: true, force: true }); });
const skill = (name, body = '', description = `${name} things`) => `---\nname: ${name}\ndescription: "${description}"\n---\n\n# ${name}\n${body}\n`;
const FILES = {
  'kernel/kernel.md': '# kern\n| Bug | Read {KERN}/diagnose/SKILL.md |\n',
  'hooks/session-start': '#!/bin/sh\necho kernel\n',
  'scripts/kern-get': '#!/bin/sh\necho value\n',
  'scripts/behave.mjs': '// an eval runner: not in the plugin copy\n',
  'README.md': 'kern\n',
  'skills/diagnose/SKILL.md': skill('diagnose', 'Prove it per `${CLAUDE_PLUGIN_ROOT}/skills/prove-it/SKILL.md`. See `references/loop.md`.'),
  'skills/diagnose/references/loop.md': 'loop\n',
  'skills/prove-it/SKILL.md': skill('prove-it', 'Run the tests.'),
  'skills/recall/SKILL.md': skill('recall', 'Read the ledger, then run kern:diagnose if a test fails.'),
  'skills/plan/SKILL.md': skill('plan', 'Write tasks.'),
  'docs/notes.md': 'not shipped\n',
  'tests/x.test.mjs': '// not shipped\n',
  'evals/fixtures/node-bug/src/sum.js': 'export const sum = (a, b) => a - b;\n',
  'evals/fixtures/other/a.txt': 'a\n',
  'evals/behave/pressure.json': JSON.stringify([{ id: 'p-diagnose', prompts: ['fix it'], skills: ['diagnose'] }, { id: 'p-plan', prompts: ['plan it'], skills: ['plan'] }], null, 2),
};
const write = (root, files) => {
  for (const [p, body] of Object.entries(files)) {
    if (body === null) { rmSync(join(root, p), { force: true }); continue; }
    mkdirSync(dirname(join(root, p)), { recursive: true });
    writeFileSync(join(root, p), body);
  }
};
const git = (root, ...a) => execFileSync('git', ['-C', root, '-c', 'user.email=t@example.com', '-c', 'user.name=t', ...a], { encoding: 'utf8' }).trim();
const repo = () => {
  const root = mkdtempSync(join(tmpdir(), 'ci-'));
  made.push(root);
  write(root, FILES);
  chmodSync(join(root, 'hooks', 'session-start'), 0o755);
  git(root, 'init', '-q', '-b', 'main');
  git(root, 'add', '-A');
  git(root, 'commit', '-qm', 'base');
  return root;
};
const pick = (id) => (json) => json.find((c) => c.id === id);
const parts = (id, skills, fixture = 'node-bug') => ({ skills, entries: [{ file: 'evals/behave/pressure.json', pick: pick(id) }], paths: [`evals/fixtures/${fixture}/`] });
const hashOf = (root, p) => caseInputs(treeSource(root), p).hash;

test('blobSha is git\'s blob id, so the working tree and a commit hash a file alike', () => {
  const root = repo();
  assert.equal(blobSha(Buffer.from('kern\n')), git(root, 'hash-object', 'README.md'));
});

test('skillClosure adds each skill a skill\'s files name, by path or as kern:<name>, and nothing else', () => {
  const src = treeSource(repo());
  assert.deepEqual(skillClosure(src, ['diagnose']), ['diagnose', 'prove-it']);
  assert.deepEqual(skillClosure(src, ['recall']), ['diagnose', 'prove-it', 'recall']);
  assert.deepEqual(skillClosure(src, ['plan']), ['plan']);
  assert.throws(() => skillClosure(src, ['no-such-skill']), /no skill no-such-skill under skills\//);
});

test('a case\'s hash moves with the kern core, its skills and their references, every skill\'s frontmatter, its fixture and its own entry', () => {
  const root = repo();
  const p = parts('p-diagnose', ['diagnose']);
  const base = hashOf(root, p);
  assert.match(base, /^[0-9a-f]{64}$/);
  const moves = (files, why) => {
    const keep = Object.fromEntries(Object.keys(files).map((f) => [f, FILES[f] ?? null]));
    write(root, files);
    assert.notEqual(hashOf(root, p), base, why);
    write(root, keep);
    assert.equal(hashOf(root, p), base, `undoing ${why} restores the hash`);
  };
  const stays = (files, why) => {
    write(root, files);
    assert.equal(hashOf(root, p), base, why);
    write(root, Object.fromEntries(Object.keys(files).map((f) => [f, FILES[f] ?? null])));
  };
  moves({ 'kernel/kernel.md': '# kern\nchanged\n' }, 'the kernel');
  moves({ 'hooks/lib/new.sh': 'x\n' }, 'a new hook file');
  moves({ 'README.md': 'kern 2\n' }, 'a top-level file the plugin copy holds');
  moves({ 'skills/diagnose/references/loop.md': 'loop 2\n' }, 'a reference of its skill');
  moves({ 'skills/prove-it/SKILL.md': skill('prove-it', 'Run the full suite.') }, 'the body of a skill its skill names');
  moves({ 'skills/plan/SKILL.md': skill('plan', 'Write tasks.', 'plan many things') }, 'another skill\'s description, which every session lists');
  moves({ 'evals/fixtures/node-bug/src/sum.js': 'export const sum = (a, b) => a + b;\n' }, 'its fixture');
  moves({ 'evals/fixtures/node-bug/src/new.js': 'x\n' }, 'a new file in its fixture');
  moves({ 'evals/behave/pressure.json': JSON.stringify([{ id: 'p-diagnose', prompts: ['fix it now'], skills: ['diagnose'] }, { id: 'p-plan', prompts: ['plan it'], skills: ['plan'] }]) }, 'its own case text');
  stays({ 'skills/plan/SKILL.md': skill('plan', 'Write many tasks.') }, 'the body of a skill it never reaches');
  stays({ 'evals/behave/pressure.json': JSON.stringify([{ skills: ['diagnose'], prompts: ['fix it'], id: 'p-diagnose' }, { id: 'p-plan', prompts: ['plan it now'], skills: ['plan'] }]) }, 'another case\'s text, or its own keys reordered');
  stays({ 'evals/fixtures/other/a.txt': 'b\n' }, 'another fixture');
  stays({ 'docs/notes.md': 'x\n', 'tests/x.test.mjs': 'x\n', 'scripts/behave.mjs': '// changed\n' }, 'files the plugin copy leaves out');
  chmodSync(join(root, 'hooks', 'session-start'), 0o644);
  assert.notEqual(hashOf(root, p), base, 'a hook that lost its exec bit');
  chmodSync(join(root, 'hooks', 'session-start'), 0o755);
});

test('the hash of a commit equals the hash of the same files on disk, and the kern files can come from another tree', () => {
  const root = repo();
  const p = parts('p-diagnose', ['diagnose']);
  assert.equal(caseInputs(treeSource(root, 'HEAD'), p).hash, hashOf(root, p));
  const other = repo();
  write(other, { 'skills/diagnose/references/loop.md': 'another tree\n' });
  const evals = treeSource(root);
  assert.notEqual(caseInputs(evals, p, treeSource(other)).hash, caseInputs(evals, p).hash);
  write(other, { 'evals/fixtures/node-bug/src/sum.js': 'changed in the other tree only\n', 'skills/diagnose/references/loop.md': FILES['skills/diagnose/references/loop.md'] });
  assert.equal(caseInputs(evals, p, treeSource(other)).hash, caseInputs(evals, p).hash, 'only kern files come from the kern tree');
});

test('a missing case entry or fixture hashes as absent, never as an error', () => {
  const root = repo();
  const gone = caseInputs(treeSource(root), parts('p-none', ['plan'], 'none'));
  assert.match(gone.hash, /^[0-9a-f]{64}$/);
  assert.notEqual(gone.hash, hashOf(root, parts('p-plan', ['plan'], 'none')));
});

test('dirHash hashes any folder, symlinks resolved as their target text, .git left out', () => {
  const root = repo();
  const a = dirHash(join(root, 'skills'));
  write(root, { 'skills/plan/SKILL.md': skill('plan', 'more') });
  assert.notEqual(dirHash(join(root, 'skills')), a);
  const b = dirHash(root);
  git(root, 'commit', '-qam', 'another');
  assert.equal(dirHash(root), b, '.git is not part of a plugin\'s content');
});

test('rangeSources reads A..B, A...B and a lone rev (that rev against the working tree), and refuses an unknown rev', () => {
  const root = repo();
  const first = git(root, 'rev-parse', 'HEAD');
  write(root, { 'skills/plan/SKILL.md': skill('plan', 'Write fewer tasks.') });
  git(root, 'commit', '-qam', 'plan body');
  write(root, { 'skills/prove-it/SKILL.md': skill('prove-it', 'Uncommitted change.') });
  const cases = [{ id: 'p-diagnose', skills: ['diagnose'] }, { id: 'p-plan', skills: ['plan'] }];
  const of = (c) => parts(c.id, c.skills);
  const ids = (range) => { const { before, after: to } = rangeSources(root, range); return changedCases(cases, of, before, to).map((c) => c.id); };
  assert.deepEqual(ids(`${first}..HEAD`), ['p-plan'], 'the commit changed only plan\'s body');
  assert.deepEqual(ids(`${first}..`), ['p-plan'], 'an empty side is HEAD');
  assert.deepEqual(ids(`${first}...HEAD`), ['p-plan']);
  assert.deepEqual(ids('HEAD'), ['p-diagnose'], 'a lone rev compares it with the working tree, uncommitted files included');
  assert.deepEqual(ids(first), ['p-diagnose', 'p-plan']);
  write(root, { 'evals/fixtures/node-bug/untracked.js': 'new\n', 'skills/prove-it/SKILL.md': FILES['skills/prove-it/SKILL.md'] });
  assert.deepEqual(ids('HEAD'), ['p-diagnose', 'p-plan'], 'an untracked fixture file counts');
  for (const bad of ['nope', 'nope..HEAD', `${first}..nope`, '']) assert.throws(() => rangeSources(root, bad), /--changed: /, bad);
});

test('skillClosure follows a skill that routes to another by its bare name, as define and plan do', () => {
  const root = repo();
  write(root, { 'skills/define/SKILL.md': skill('define', 'A quick change: route to implement. An agreed spec routes to `plan`.'), 'skills/implement/SKILL.md': skill('implement', 'Build it.') });
  assert.deepEqual(skillClosure(treeSource(root), ['define']), ['define', 'implement', 'plan']);
});

test('define\'s own files name implement in a form the closure sees, not only through plan', () => {
  // M2b bfix K review, Minor 5: define step 1 ends "Then Read implement's SKILL.md.", which matches no closure
  // pattern (skills/<n>/, kern:<n>, "route(s|d) to <n>"). Only step 9's "The kernel then routes to implement." names
  // implement directly; plan's step 1 names it too, so the real closure would keep implement if step 9 lost it. Here
  // define's real folder sits beside a stub of every other kern skill, so implement must come from define itself.
  const top = join(dirname(fileURLToPath(import.meta.url)), '..');
  const root = repo();
  rmSync(join(root, 'skills'), { recursive: true, force: true });
  cpSync(join(top, 'skills', 'define'), join(root, 'skills', 'define'), { recursive: true });
  write(root, Object.fromEntries(readdirSync(join(top, 'skills')).filter((n) => n !== 'define').map((n) => [`skills/${n}/SKILL.md`, skill(n)])));
  assert.ok(skillClosure(treeSource(root), ['define']).includes('implement'), JSON.stringify(skillClosure(treeSource(root), ['define'])));
});

test('touchedSkills names each kern skill a run\'s tool calls read or called, and skillHashes gives each skill\'s hash', () => {
  const src = treeSource(repo());
  const call = (name, input) => ({ type: 'assistant', message: { content: [{ type: 'tool_use', id: 't', name, input }] } });
  const events = [call('Read', { file_path: '/tmp/p/kern/skills/plan/SKILL.md' }), call('Bash', { command: 'cat /tmp/p/kern/skills/recall/references/x.md' }),
    call('Skill', { skill: 'kern:prove-it' }), call('Read', { file_path: '/tmp/w/app/skills/none-such/SKILL.md' }), { type: 'user', message: { content: [{ type: 'tool_result', content: 'skills/diagnose/ in a result' }] } }];
  assert.deepEqual(touchedSkills(events, skillHashes(src)), ['plan', 'prove-it', 'recall']);
  const h = skillHashes(src);
  assert.match(h.get('plan'), /^[0-9a-f]{64}$/);
  assert.notEqual(h.get('plan'), h.get('recall'));
});

test('touchedSkills counts every way a run reaches a skill, and a search of the skills folder or the plugin root touches them all', () => {
  const hashes = skillHashes(treeSource(repo()));
  const call = (name, input) => ({ type: 'assistant', message: { content: [{ type: 'tool_use', id: 't', name, input }] } });
  const one = (name, input, roots = []) => touchedSkills([call(name, input)], hashes, roots);
  assert.deepEqual(one('Grep', { pattern: 'spec', path: '/tmp/p/kern/skills/plan' }), ['plan'], 'a folder named without its slash');
  assert.deepEqual(one('Bash', { command: 'grep -rn spec /tmp/p/kern/skills/plan' }), ['plan']);
  assert.deepEqual(one('SlashCommand', { command: '/kern:plan' }), ['plan']);
  assert.deepEqual(one('Skill', { skill: 'plan' }), ['plan'], 'a bare skill name');
  assert.deepEqual(one('Grep', { pattern: 'x', path: '/tmp/p/kern/skills/plan-old' }), [], 'another name that starts with one');
  const all = [...hashes.keys()].sort();
  assert.deepEqual(one('Grep', { pattern: 'x', path: '/tmp/p/kern/skills' }), all);
  assert.deepEqual(one('Glob', { pattern: 'skills/**/SKILL.md', path: '/tmp/p/kern' }), all);
  assert.deepEqual(one('Bash', { command: 'grep -rn x /private/tmp/p/kern | head' }, ['/tmp/p/kern']), all, 'the plugin root, either spelling');
  assert.deepEqual(one('Read', { file_path: '/tmp/p/kern/kernel/kernel.md' }, ['/tmp/p/kern']), [], 'a file under the root that is no skill');
});
