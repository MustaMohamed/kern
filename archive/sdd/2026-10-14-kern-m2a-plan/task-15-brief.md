### Task 15: Lint rules 5, 9 and 16

**Files:**
- Modify: `scripts/lib/lint-rules.mjs` (append three entries to `RULES`), `tests/lint-rules.test.mjs` (append tests; give the M0 agent fixtures a `## Report` heading), `scripts/lint-exemptions.json`

**Interfaces:**
- Consumes (M0): `loadModel(root)` with `skills[] { name, dir, file, tier, data, body, error }`, `agents[] { name, file, data, body, error }`, `kernelText`; `err(rule, path, message)`; `rel(model, absPath)`; `walk(dir)` (module-internal); test helpers `repo`, `skill`, `lint`, `rules`.
- Produces:
  - Rule 5: a "Skill tool with `<name>`" reference in a skill, agent or the kernel names a kern auto skill (with or without `kern:`) or a built-in skill (`code-review`, `security-review`, `simplify`); every `${CLAUDE_PLUGIN_ROOT}/<path>` in an agent body exists (rule 4 covers skills).
  - Rule 9: an auto skill has a `## Steps` section; a slash skill has `## Steps` as its first H2, or carries a rule-9 exemption with a reason; an agent has an H2 starting `## Report`, `## Output`, `## Return` or `## Status`; a discipline skill (`prove-it`, `implement`, `diagnose`, `define`, `execute-plan`, `commit`, `finish-branch`) has a `## Red flags` H2 holding a `| Thought | Reality |` table of 2 to 6 rows (coverage gap 7, extended by the goal-0 review to define, execute-plan, commit and finish-branch). Path skills are left to M1's rule 6 for `## Steps`, so one defect is reported once.
  - Rule 16, contract drift (coverage gap 9): every `${CLAUDE_PLUGIN_ROOT}/scripts/<name>` a skill, agent or skill reference names has a `` | `<name>` | `` row in `docs/plans/contract.md`; every `WORK/<sub>` is listed there as `` `WORK/<sub>/` ``; every backticked ledger line (`Task N: ...`, `parked:`, `Decision:`, `Worktree:`, `Main:`, `Wave:`, `Applied:`, `Preflight:`) appears there verbatim. Silent when the contract file is absent.

- [ ] **Step 1: Give the existing agent fixtures an output section**

In `tests/lint-rules.test.mjs`, the two agent fixtures from M0 end their body with `body\n`. Change both bodies to `## Report\n\nbody\n` so they keep testing rules 2 and 3 only:

```js
  const agent = '---\nname: r\ndescription: d\npermissionMode: plan\n---\n## Report\n\nbody\n';
```

```js
  const agent = `---\nname: r\ndescription: ${'z'.repeat(151)}\n---\n## Report\n\nbody\n`;
```

- [ ] **Step 2: Write the failing tests**

Append to `tests/lint-rules.test.mjs`:

```js
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
});

test('rule 9: a discipline skill needs a Red flags table of 2 to 6 rows', () => {
  const body = (extra) => `\n# implement\n\n## Steps\n\n1. a\n${extra}`;
  assert.deepEqual(rules(lint({ 'skills/implement/SKILL.md': skill('implement', manual(), body('')) })), [9]);
  assert.deepEqual(rules(lint({ 'skills/implement/SKILL.md': skill('implement', manual(), body(flags(1))) })), [9]);
  assert.deepEqual(rules(lint({ 'skills/implement/SKILL.md': skill('implement', manual(), body(flags(7))) })), [9]);
  assert.deepEqual(rules(lint({ 'skills/implement/SKILL.md': skill('implement', manual(), body(flags(3))) })), []);
  assert.deepEqual(rules(lint({ 'skills/other/SKILL.md': skill('other', manual(), body('')) })), [], 'only discipline skills need the table');
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
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `node --test tests/lint-rules.test.mjs`
Expected: six of the seven new tests fail (rules 5, 9 and 16 report nothing yet) and one passes already (measured by the pre-flight); the M0 and M1 tests still pass.

- [ ] **Step 4: Append the rules to `RULES` in `scripts/lib/lint-rules.mjs`**

Insert these entries before the closing `];` of `RULES`:

```js
  { id: 5, check(model) {
    const BUILTIN_SKILLS = new Set(['code-review', 'security-review', 'simplify']);
    const out = [];
    const auto = new Set(model.skills.filter((s) => s.tier === 'auto').map((s) => s.name));
    const docs = [...model.skills, ...model.agents].filter((d) => !d.error).map((d) => ({ file: d.file, body: d.body }));
    if (model.kernelText) docs.push({ file: join(model.root, 'kernel', 'kernel.md'), body: model.kernelText });
    for (const d of docs) {
      for (const m of d.body.matchAll(/Skill tool with `([a-z0-9:-]+)`/g)) {
        const name = m[1].replace(/^kern:/, '');
        if (!auto.has(name) && !BUILTIN_SKILLS.has(name)) {
          out.push(err(5, rel(model, d.file), `Skill tool reference "${m[1]}" names neither a kern auto skill nor a built-in skill; path and slash skills are reached by Read or typed by the user`));
        }
      }
    }
    for (const a of model.agents.filter((x) => !x.error)) {
      for (const m of a.body.matchAll(/\$\{CLAUDE_PLUGIN_ROOT\}\/([\w./-]+)/g)) {
        const r = m[1].replace(/[.,;:]+$/, '');
        if (!existsSync(join(model.root, r))) out.push(err(5, rel(model, a.file), `Read path does not resolve: \${CLAUDE_PLUGIN_ROOT}/${r}`));
      }
    }
    return out;
  } },
  { id: 9, check(model) {
    // Discipline skills carry a ## Red flags table of 2 to 6 rows: the thought that skips a step, and why
    // it is wrong (design gap 7, the goal-0 review).
    const DISCIPLINE = new Set(['prove-it', 'implement', 'diagnose', 'define', 'execute-plan', 'commit', 'finish-branch']);
    const out = [];
    const h2 = (body) => {
      let fence = false;
      return body.split('\n').filter((l) => {
        if (/^\s{0,3}(```|~~~)/.test(l)) { fence = !fence; return false; }
        return !fence && /^## /.test(l);
      }).map((l) => l.trim());
    };
    const section = (body, heading) => {
      const lines = body.split('\n');
      const i = lines.findIndex((l) => l.trim() === heading);
      if (i < 0) return '';
      const rest = [];
      for (const l of lines.slice(i + 1)) { if (/^## /.test(l)) break; rest.push(l); }
      return rest.join('\n');
    };
    for (const s of model.skills.filter((x) => !x.error)) {
      const heads = h2(s.body);
      const p = rel(model, s.file);
      if (DISCIPLINE.has(s.name)) {
        const rows = section(s.body, '## Red flags').split('\n').filter((l) => /^\|/.test(l));
        if (!heads.includes('## Red flags')) out.push(err(9, p, 'discipline skill has no "## Red flags" section'));
        else if (rows[0]?.replace(/\s/g, '') !== '|Thought|Reality|' || rows.length - 2 < 2 || rows.length - 2 > 6) out.push(err(9, p, '"## Red flags" needs a | Thought | Reality | table of 2 to 6 rows'));
      }
      if (s.tier === 'path') continue; // rule 6 (M1) checks that route files open with ## Steps
      if (s.tier === 'auto') {
        if (!heads.includes('## Steps')) out.push(err(9, p, 'auto skill has no "## Steps" section'));
      } else if (heads[0] !== '## Steps') {
        out.push(err(9, p, heads.includes('## Steps') ? '"## Steps" must be the first H2 of a slash skill' : 'slash skill has no "## Steps" section; add one or record a rule-9 exemption with a reason'));
      }
    }
    for (const a of model.agents.filter((x) => !x.error)) {
      if (!h2(a.body).some((h) => /^## (Report|Output|Return|Status)\b/.test(h))) {
        out.push(err(9, rel(model, a.file), 'agent has no output contract section (## Report, ## Output, ## Return or ## Status)'));
      }
    }
    return out;
  } },
  { id: 16, check(model) {
    // Contract drift: every script, WORK subfolder and ledger line a shipped skill or agent names has its
    // producer in docs/plans/contract.md (adapted from addy scripts/validate-artifact-paths.js, MIT).
    const cf = join(model.root, 'docs', 'plans', 'contract.md');
    if (!existsSync(cf)) return [];
    const contract = readFileSync(cf, 'utf8');
    const out = [];
    const files = [...model.skills, ...model.agents].filter((d) => !d.error).map((d) => d.file);
    for (const s of model.skills) files.push(...walk(join(model.root, 'skills', s.dir, 'references')).filter((f) => f.endsWith('.md')));
    const seen = new Set();
    for (const f of files) {
      const text = readFileSync(f, 'utf8');
      const p = rel(model, f);
      const flag = (token, why) => { if (!seen.has(`${p}\0${token}`)) { seen.add(`${p}\0${token}`); out.push(err(16, p, `${token}: ${why}`)); } };
      for (const m of text.matchAll(/\$\{CLAUDE_PLUGIN_ROOT\}\/scripts\/([a-z0-9-]+)/g)) {
        if (!contract.includes(`| \`${m[1]}\` |`)) flag(`scripts/${m[1]}`, 'no row in the Scripts table of docs/plans/contract.md');
      }
      for (const m of text.matchAll(/\bWORK\/([a-z]+)/g)) {
        if (!contract.includes(`\`WORK/${m[1]}/\``)) flag(`WORK/${m[1]}`, 'not listed under "Working directory" in docs/plans/contract.md');
      }
      for (const m of text.matchAll(/`((?:Task N|parked|Decision|Worktree|Main|Wave|Applied|Preflight):[^`]*)`/g)) {
        if (!contract.includes(`\`${m[1]}\``)) flag(m[1], 'ledger line format not in docs/plans/contract.md');
      }
    }
    return out;
  } },
```

`join`, `existsSync`, `readFileSync` and `walk` are already in `lint-rules.mjs` (rules 4 and 8 use them).

- [ ] **Step 5: Run the tests, then lint the real tree**

Run: `node --test tests/lint-rules.test.mjs && node scripts/lint-skills.mjs`
Expected: `# fail 0`. Lint then reports rule 9 on `skills/unslop/SKILL.md` (a rule document with no procedure); add `{"rule": 9, "path": "skills/unslop/SKILL.md", "reason": "rule document read by technical-writing; it has no procedure"}` to `scripts/lint-exemptions.json`. Rule 16 passes because `docs/plans/contract.md` lists `WORK/ledgers/` and `parked:`, which `skills/autopilot/SKILL.md` names. Re-run `node scripts/lint-skills.mjs` until it prints no errors.

- [ ] **Step 6: Commit**

```bash
git add -- scripts/lib/lint-rules.mjs tests/lint-rules.test.mjs scripts/lint-exemptions.json
git commit -m "M2: add lint rules 5, 9 and 16" -m "Path skills are reached by Read, so a Skill-tool reference to one fails at runtime; discipline skills need their Red flags; and a token a skill reads must have a producer in the contract."
```

- [ ] **Step 7: Checkpoint**

Run: `scripts/ci-local`
Expected: last line `ci-local: all steps passed`.

---

