### Task 5: Skill lint (rules 1, 2, 3, 4, 8, 10, 11)

**Files:**
- Create: `scripts/lib/frontmatter.mjs`, `scripts/lib/lint-rules.mjs`, `scripts/lint-skills.mjs`, `scripts/lint-exemptions.json`, `scripts/lint-names.txt`
- Test: `tests/lint-rules.test.mjs`

**Interfaces:**
- Consumes: `skills/*/SKILL.md`, `agents/*.md` (none yet).
- Produces (M1 and M2 add rules through these):
  - `parseFrontmatter(src: string) -> { data: Record<string,string>, body: string, error: string|null }`
  - `loadModel(root: string) -> { root, skills: Skill[], agents: Agent[], exemptions: Exemption[], shipped: string[], kernelText: string, cases: Record<string, object> }` where `Skill = { name, dir, file, tier: 'auto'|'path'|'slash', data, body, error }` (`data` is the parsed frontmatter; tier is `auto` without `disable-model-invocation: true`, `path` when `kernel/kernel.md` has a row reading `Read {KERN}/<name>/SKILL.md`, else `slash`), `Agent = { name, base, file, data, body, error }`, `Exemption = { rule: number, path: string, reason: string }`, `shipped` is every file under the shipped dirs (absolute paths), `kernelText` is `kernel/kernel.md` or `''`, and `cases` maps an `evals/cases/*.json` basename (no extension) to its parsed JSON or `{ parseError }`.
  - `RULES: Array<{ id: number, check(model) -> Finding[] }>` where `Finding = { rule: number, path: string, level: 'error'|'warn', message: string }`
  - `runLint(model) -> Finding[]` applies every rule, then drops findings matched by an exemption (same rule and path).
  - CLI `node scripts/lint-skills.mjs [root]` prints `<level> <path>: rule <n>: <message>` per finding and exits 1 when any error remains.
  - Adding a rule later: append `{ id, check }` to `RULES` in `lint-rules.mjs` and add tests to `tests/lint-rules.test.mjs`.

- [ ] **Step 1: Write the failing tests**

```js
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
  const f = lint({ 'skills/a/SKILL.md': skill('a', 'description: Use when x.', body) });
  delete process.env.KERN_LINT_NAMES;
  assert.deepEqual(rules(f), [8, 8]);
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
```

- [ ] **Step 2: Run them to verify they fail**

Run: `node --test tests/lint-rules.test.mjs`
Expected: FAIL with `Cannot find module '.../scripts/lib/frontmatter.mjs'`.

- [ ] **Step 3: Write `scripts/lib/frontmatter.mjs`**

```js
// Minimal frontmatter reader for kern files: single-line `key: value` pairs only.
export function parseFrontmatter(src) {
  const text = src.replace(/\r\n/g, '\n');
  const m = text.match(/^---\n([\s\S]*?)\n---[ \t]*(?:\n|$)/);
  if (!m) return { data: {}, body: text, error: 'no frontmatter block' };
  const data = {};
  for (const line of m[1].split('\n')) {
    if (!line.trim() || line.trimStart().startsWith('#')) continue;
    const kv = line.match(/^([A-Za-z][A-Za-z0-9_-]*):[ \t]*(.*)$/);
    if (!kv) return { data, body: text.slice(m[0].length), error: `unparsed frontmatter line (use single-line values): ${line}` };
    let value = kv[2].trim();
    if (value === '>' || value === '|' || value === '>-' || value === '|-') {
      return { data, body: text.slice(m[0].length), error: `key ${kv[1]} uses a block scalar; use single-line values` };
    }
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) value = value.slice(1, -1);
    data[kv[1]] = value;
  }
  return { data, body: text.slice(m[0].length), error: null };
}
```

- [ ] **Step 4: Write `scripts/lib/lint-rules.mjs`**

```js
// kern lint rules (design spec 11.2). Pure checks over a loaded model; the CLI is scripts/lint-skills.mjs.
// Rule set informed by addyosmani/agent-skills scripts/lib/skill-lint.js (MIT); the code is written for kern.
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';
import { parseFrontmatter } from './frontmatter.mjs';

export const SKILL_KEYS = new Set(['name', 'description', 'when_to_use', 'argument-hint', 'arguments', 'disable-model-invocation', 'user-invocable', 'allowed-tools', 'disallowed-tools', 'model', 'effort', 'context', 'agent', 'background', 'hooks', 'paths', 'shell', 'metadata', 'license', 'compatibility']);
export const AGENT_KEYS = new Set(['name', 'description', 'tools', 'disallowedTools', 'model', 'effort', 'color', 'maxTurns', 'skills', 'memory', 'background', 'isolation']);
export const AGENT_KEYS_IGNORED_IN_PLUGINS = new Set(['permissionMode', 'hooks', 'mcpServers', 'initialPrompt']);
export const SHIPPED_DIRS = ['skills', 'agents', 'kernel', 'modes', 'hooks'];
export const LIMITS = { auto: 300, manual: 120, agent: 150, autoTotal: 1500, autoPlusAgents: 2500 };
const KEBAB = /^[a-z0-9]+(-[a-z0-9]+)*$/;
const TRIGGER = /\buse (this )?when\b|\buse (before|after|during)\b/i;
const MACHINE_PATH = /(\/Users\/[A-Za-z]|\/home\/[a-z]|[A-Z]:\\Users\\|~\/Code\/)/;
const LONG_DASH = /[–—]/g;
const CURLY = /[‘’“”]/g;

export const rel = (model, p) => relative(model.root, p);

function walk(dir) {
  if (!existsSync(dir)) return [];
  const out = [];
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) out.push(...walk(p));
    else out.push(p);
  }
  return out;
}

export function loadModel(root) {
  const skills = [];
  const skillsDir = join(root, 'skills');
  if (existsSync(skillsDir)) {
    for (const dir of readdirSync(skillsDir)) {
      const file = join(skillsDir, dir, 'SKILL.md');
      if (!existsSync(file)) continue;
      const fm = parseFrontmatter(readFileSync(file, 'utf8'));
      skills.push({ name: fm.data.name, dir, file, data: fm.data, body: fm.body, error: fm.error });
    }
  }
  const kernelPath = join(root, 'kernel', 'kernel.md');
  const kernelText = existsSync(kernelPath) ? readFileSync(kernelPath, 'utf8') : '';
  const routed = new Set([...kernelText.matchAll(/Read \{KERN\}\/([a-z0-9-]+)\/SKILL\.md/g)].map((m) => m[1]));
  for (const s of skills) s.tier = s.data['disable-model-invocation'] !== 'true' ? 'auto' : routed.has(s.name) ? 'path' : 'slash';
  const cases = {};
  const casesDir = join(root, 'evals', 'cases');
  if (existsSync(casesDir)) {
    for (const f of readdirSync(casesDir).filter((n) => n.endsWith('.json'))) {
      try { cases[f.replace(/\.json$/, '')] = JSON.parse(readFileSync(join(casesDir, f), 'utf8')); }
      catch (e) { cases[f.replace(/\.json$/, '')] = { parseError: e.message }; }
    }
  }
  const agents = [];
  const agentsDir = join(root, 'agents');
  if (existsSync(agentsDir)) {
    for (const f of readdirSync(agentsDir).filter((n) => n.endsWith('.md'))) {
      const file = join(agentsDir, f);
      const fm = parseFrontmatter(readFileSync(file, 'utf8'));
      agents.push({ name: fm.data.name, base: f.replace(/\.md$/, ''), file, data: fm.data, body: fm.body, error: fm.error });
    }
  }
  const exFile = join(root, 'scripts', 'lint-exemptions.json');
  const exemptions = existsSync(exFile) ? JSON.parse(readFileSync(exFile, 'utf8')) : [];
  const shipped = SHIPPED_DIRS.flatMap((d) => walk(join(root, d)));
  return { root, skills, agents, exemptions, shipped, kernelText, cases };
}

export const err = (rule, path, message) => ({ rule, path, level: 'error', message });
export const warn = (rule, path, message) => ({ rule, path, level: 'warn', message });

export const RULES = [
  { id: 1, check(model) {
    const out = [];
    for (const s of model.skills) {
      const p = rel(model, s.file);
      if (s.error) { out.push(err(1, p, s.error)); continue; }
      if (!KEBAB.test(s.dir)) out.push(err(1, p, `directory ${s.dir} is not kebab case`));
      else if (s.name !== s.dir) out.push(err(1, p, `name ${s.name} does not equal directory ${s.dir}`));
    }
    for (const a of model.agents) {
      const p = rel(model, a.file);
      if (a.error) { out.push(err(1, p, a.error)); continue; }
      if (a.name !== a.base) out.push(err(1, p, `name ${a.name} does not equal file name ${a.base}`));
    }
    return out;
  } },
  { id: 2, check(model) {
    const out = [];
    for (const s of model.skills) {
      for (const k of Object.keys(s.data)) if (!SKILL_KEYS.has(k)) out.push(err(2, rel(model, s.file), `unknown frontmatter key ${k}`));
    }
    for (const a of model.agents) {
      for (const k of Object.keys(a.data)) {
        if (AGENT_KEYS_IGNORED_IN_PLUGINS.has(k)) out.push(err(2, rel(model, a.file), `${k} is ignored for plugin agents; use tools, disallowedTools and kern guards`));
        else if (!AGENT_KEYS.has(k)) out.push(err(2, rel(model, a.file), `unknown agent key ${k}`));
      }
    }
    return out;
  } },
  { id: 3, check(model) {
    const out = [];
    let autoTotal = 0;
    let agentTotal = 0;
    for (const s of model.skills) {
      if (s.error) continue;
      const d = s.data.description || '';
      const p = rel(model, s.file);
      if (!d) { out.push(err(3, p, 'description missing')); continue; }
      if (s.tier === 'auto') {
        autoTotal += d.length;
        if (d.length > LIMITS.auto) out.push(err(3, p, `auto description ${d.length} chars, limit ${LIMITS.auto}`));
        if (!TRIGGER.test(d)) out.push(err(3, p, 'auto description needs a trigger such as "Use when" or "Use before"'));
      } else if (d.length > LIMITS.manual) out.push(err(3, p, `description ${d.length} chars, limit ${LIMITS.manual}`));
    }
    for (const a of model.agents) {
      const d = a.data.description || '';
      agentTotal += d.length;
      if (d.length > LIMITS.agent) out.push(err(3, rel(model, a.file), `agent description ${d.length} chars, limit ${LIMITS.agent}`));
    }
    if (autoTotal > LIMITS.autoTotal) out.push(err(3, 'skills', `auto descriptions total ${autoTotal} chars, limit ${LIMITS.autoTotal}`));
    if (autoTotal + agentTotal > LIMITS.autoPlusAgents) out.push(err(3, 'skills', `auto plus agent descriptions total ${autoTotal + agentTotal} chars, limit ${LIMITS.autoPlusAgents}`));
    return out;
  } },
  { id: 4, check(model) {
    const out = [];
    for (const s of model.skills) {
      const p = rel(model, s.file);
      const local = [...s.body.matchAll(/`((?:references|templates|scripts|prompts)\/[\w./-]+)`|\]\(((?:references|templates|scripts|prompts)\/[\w./-]+)\)/g)].map((m) => m[1] || m[2]);
      for (const r of local) if (!existsSync(join(model.root, 'skills', s.dir, r))) out.push(err(4, p, `referenced file missing: ${r}`));
      const rooted = [...s.body.matchAll(/\$\{CLAUDE_PLUGIN_ROOT\}\/([\w./-]+)/g)].map((m) => m[1].replace(/[.,;:]+$/, ''));
      for (const r of rooted) if (!existsSync(join(model.root, r))) out.push(err(4, p, `referenced file missing: \${CLAUDE_PLUGIN_ROOT}/${r}`));
    }
    return out;
  } },
  { id: 8, check(model) {
    const out = [];
    const names = (process.env.KERN_LINT_NAMES || '').split(',').map((n) => n.trim()).filter(Boolean);
    for (const f of ['.lint-names', 'scripts/lint-names.txt']) {
      const namesFile = join(model.root, f);
      if (existsSync(namesFile)) names.push(...readFileSync(namesFile, 'utf8').split('\n').map((n) => n.trim()).filter((n) => n && !n.startsWith('#')));
    }
    const nameRes = names.map((n) => new RegExp(`\\b${n.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i'));
    for (const f of model.shipped) {
      const text = readFileSync(f, 'utf8');
      const p = rel(model, f);
      if (MACHINE_PATH.test(text)) out.push(err(8, p, 'machine-specific path'));
      for (const re of nameRes) if (re.test(text)) out.push(err(8, p, `personal name matches ${re.source}`));
    }
    return out;
  } },
  { id: 10, check(model) {
    return model.exemptions.filter((e) => !e.reason || !String(e.reason).trim()).map((e) => err(10, 'scripts/lint-exemptions.json', `exemption for rule ${e.rule} on ${e.path} has no reason`));
  } },
  { id: 11, check(model) {
    const out = [];
    const files = [...model.shipped, join(model.root, 'README.md'), join(model.root, 'CHANGELOG.md')].filter((f) => existsSync(f) && /\.(md|sh|json|yml)$|\/hooks\/[a-z-]+$/.test(f));
    for (const f of files) {
      const text = readFileSync(f, 'utf8');
      const p = rel(model, f);
      if ((text.match(LONG_DASH) || []).length) out.push(err(11, p, 'long dash; use a period or a comma'));
      if ((text.match(CURLY) || []).length) out.push(err(11, p, 'curly quotes; use straight quotes'));
    }
    return out;
  } },
];

export function runLint(model) {
  const findings = RULES.flatMap((r) => r.check(model));
  const valid = model.exemptions.filter((e) => e.reason && String(e.reason).trim());
  return findings.filter((f) => f.rule === 10 || !valid.some((e) => e.rule === f.rule && e.path === f.path));
}

```

- [ ] **Step 5: Write `scripts/lint-skills.mjs` and `scripts/lint-exemptions.json`**

```js
#!/usr/bin/env node
// CLI over scripts/lib/lint-rules.mjs. Exit 1 when any error remains.
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { loadModel, runLint } from './lib/lint-rules.mjs';

const root = resolve(process.argv[2] || fileURLToPath(new URL('..', import.meta.url)));
const findings = runLint(loadModel(root));
for (const f of findings) console.log(`${f.level} ${f.path}: rule ${f.rule}: ${f.message}`);
const errors = findings.filter((f) => f.level === 'error').length;
console.log(errors ? `lint: ${errors} error(s)` : 'lint: clean');
process.exit(errors ? 1 : 0);
```

`scripts/lint-exemptions.json`:
```json
[]
```

`scripts/lint-names.txt` (tracked, so CI checks names too; `.lint-names` stays for local additions):
```text
# Personal names and handles that must not appear in shipped files (lint rule 8).
Mustafa
Mohamed
MustaMohamed
musta
heyinfinito
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `node --test tests/lint-rules.test.mjs && node scripts/lint-skills.mjs`
Expected: `# fail 0`; then `lint: clean` on the real repo.

- [ ] **Step 7: Commit**

```bash
git add -- scripts/lib/frontmatter.mjs scripts/lib/lint-rules.mjs scripts/lint-skills.mjs scripts/lint-exemptions.json scripts/lint-names.txt tests/lint-rules.test.mjs
git commit -m "M0: add skill lint rules 1, 2, 3, 4, 8, 10 and 11" -m "Description budgets and plugin-agent keys are checked mechanically so later milestones cannot drift past them."
```

---

