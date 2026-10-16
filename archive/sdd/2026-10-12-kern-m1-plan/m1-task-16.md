### Task 16: `help` skill and lint rule 6

**Files:**
- Create: `skills/help/SKILL.md`, `skills/help/references/map.md`, `skills/help/references/fix-a-run.md`, `skills/help/templates/kern.local.yml`
- Modify: `scripts/lib/lint-rules.mjs` (append rule 6 to `RULES`), `scripts/lint-exemptions.json`, `tests/lint-rules.test.mjs`
- Test: `tests/skills-help.test.mjs`

**Interfaces:**
- Consumes: `scripts/kern-detect`, `scripts/kern-get`, `kernel/settings.md`; M0's `RULES`, `err`, `rel`, `parseFrontmatter`, `loadModel` (`kernelText`, `skills[].data`).
- Produces: `/kern:help`, `/kern:help setup`, `/kern:help check`; the help map table (header `| Skill | Tier | Reached by | Job |`, first cell the skill name in backticks); lint rule 6: every `Read {KERN}/<skill>/SKILL.md` or `Read {ROOT}/<path>` row resolves, and the target's first H2 is `## Steps` followed by a numbered list; every skill whose frontmatter does not say `user-invocable: false` is in the map.

- [ ] **Step 1: Write the failing tests**

`tests/skills-help.test.mjs`:
```js
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
```

Append to `tests/lint-rules.test.mjs` (it reuses the file's `repo`, `skill`, `lint` and `rules` helpers and needs no new imports):

```js
// M1 rules: 6 (routes and help map), 7 (kernel size), 13 (settings keys), 15 (hook-shape fixtures).
const kernel = (rows) => `# kern {VERSION}\n\n## Routing\n| When | Route |\n|---|---|\n${rows.join('\n')}\n`;

test('rule 6: a route must exist and open with ## Steps', () => {
  const ok = lint({
    'kernel/kernel.md': kernel(['| Prose | Read {KERN}/tw/SKILL.md |', '| Phase ends | Read {ROOT}/kernel/context.md |']),
    'skills/tw/SKILL.md': skill('tw', 'description: d\ndisable-model-invocation: true'),
    'kernel/context.md': '# Context\n\n## Steps\n1. a\n',
  });
  assert.deepEqual(rules(ok), []);
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `node --test tests/skills-help.test.mjs tests/lint-rules.test.mjs`
Expected: FAIL; `ENOENT ... skills/help/SKILL.md`, and the rule 6 assertions that expect `[6]` get `[]`.

- [ ] **Step 3: Write `skills/help/SKILL.md`**

```markdown
---
name: help
description: "Map of kern: which skill fits, fixes for a run that went wrong, and help setup to write this project's settings."
disable-model-invocation: true
argument-hint: "[setup|check|<question>]"
allowed-tools: Read, Bash(git remote *), Bash(git symbolic-ref *), Bash(git log *), Bash(git for-each-ref *), Bash(git worktree list *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get *), Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect *)
---

# Help

The human-facing map of kern and the project setup. A message that asks for work is not a help question: hand it back to the kernel's routing.

## Steps
1. Pick the mode from the argument: `setup`, `check`, or a question. No argument and an unclear need: ask one multiple-choice question: set up this project, pick a skill, fix a run, or change kern itself.
2. Question mode: check the state that changes the answer and mention it only when it does: the kernel was injected this session and its version; which settings files exist; superpowers' SessionStart hook is still enabled (two routers); a second voice plugin injects rules; the mode and autopilot line.
3. Read the target skill before quoting it.
4. Answer from one section of `references/map.md` or `references/fix-a-run.md`. Give at most one example prompt and do not start the work.
5. `setup` and `check` follow their sections below.

## Setup
1. Explore read-only: `git remote -v`; `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-detect base_branch`; the same script for `branch.pattern`, `commit.convention`, `test.full`, `test.focused`, `typecheck`, `lint`, `build`, `tracker` and `pr.template`; CLAUDE.md and `.claude/rules/**`; `.claude/skills/*` and `.claude/commands/*` (jobs a project skill owns); connected tracker MCP tools; existing kern settings.
2. Present two lists: settled by detection (written only where detection guessed wrong) and needs a decision.
3. Ask one key group at a time, recommended answer first, skipping groups detection settled: tracker; conventions; check commands; review; risk (`autopilot`, `protected_targets`, `deploy.envs`, `never_commit`, `scope_threshold`, `shared_services`); `worktree.setup`.
4. Map project skills to kern jobs and show the map, for example `overrides.commit: commit`. Say that kern's guards still apply to project skills.
5. Show the full commented draft of `.claude/kern.local.yml`, built from `templates/kern.local.yml`. Let the user edit it. Write it only after an explicit yes, as one file at the main worktree root; a re-run updates it in place.
6. On the same yes, append to `$(git rev-parse --git-common-dir)/info/exclude` the lines `/.claude/kern.local.yml`, `/.kern/`, and `worktree.dir` when it is inside the repo and `git check-ignore -q` fails for it. Never edit `.gitignore` or any tracked file.
7. Offer `.claude/kern.yml` (shared, committed) only if the user wants team settings; committing it follows the normal commit rules. Offer user defaults (`mode.voice`, `mode.surface`, `kern_repo`) for `~/.claude/kern.yml` as a separate yes.
8. Print the status-line snippet from `references/fix-a-run.md`. Never write `settings.json`.

Under autopilot, setup refuses: nobody can confirm the draft. Setup makes no tracker writes.

## Check
Validate without writing anything: unknown keys and floor-action keys (the kernel's Project settings block lists both); `overrides.<job>` values that name a missing project skill; settings files that exist in a linked worktree but not at the main worktree root (`git worktree list`); missing exclude lines for `.claude/kern.local.yml` and `.kern/`. The key table is `${CLAUDE_PLUGIN_ROOT}/kernel/settings.md`.
```

- [ ] **Step 4: Write `skills/help/references/map.md`**

```markdown
# kern map

Installed skills only. Tier: `auto` skills load by description; `path` skills load through a kernel route or a slash command; `slash` skills load only when typed.

| Skill | Tier | Reached by | Job |
|---|---|---|---|
| `mode` | slash | `/kern:mode`, or "go terse", "html mode", "back to normal" | Switch voice and surface for this session |
| `autopilot` | slash | `/kern:autopilot on`, typed only | Grant this session commits, branch pushes and draft PRs without asking |
| `help` | slash | `/kern:help`, `/kern:help setup`, `/kern:help check` | This map, fixes for a run, and project settings |
| `technical-writing` | path | Kernel row "Prose others read", or `/kern:technical-writing` | Docs, PR bodies, issues and commit messages |
| `unslop` | slash | The kernel's Reply rule, technical-writing step 5, or `/kern:unslop` | Rules for prose others read |

## Close calls
- Writing a PR body: `technical-writing` (it applies `unslop`). Editing a reply's tone only: `unslop`.
- Terse chat but a full PR body: terse governs chat only; persisted text always follows `unslop`.
```

- [ ] **Step 5: Write `skills/help/references/fix-a-run.md`**

````markdown
# Fix a run

| Symptom | Check | Fix |
|---|---|---|
| No routing, no `kern mode:` line | The first context block of the session starts with `# kern <version>` | Run `claude --debug` and look for the kern SessionStart hook; bash must be on PATH; `kern: off` disables kern per project |
| Two routers answer | superpowers is enabled in this project | Set `"superpowers@claude-plugins-official": false` under `enabledPlugins` in `.claude/settings.local.json` |
| Two voices | Another plugin injects a terse voice at session start | Disable that plugin; kern's `terse` mode replaces it |
| `/kern:mode terse` did nothing | `/kern:mode status` shows the hook line | No line: hooks did not run (see the first row). A line with the old value: the word was not recognized |
| A guard asked or denied unexpectedly | The reason starts with `kern G<n>:` | Each guard's rule is in kern's design spec, section 8.3. A policy key (`commit.policy`, `push.policy`, `pr.policy`, `tracker.policy`, `review.post_policy`) changes ask to auto or deny; floor actions have no key |
| Settings ignored in a worktree | Settings live in the main checkout | Put `.claude/kern.local.yml` at the main worktree root (`bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-root`) |
| Autopilot refused | "autopilot denied by <file>" | That file sets `autopilot: denied`; only the user changes it |
| kern ignored a project rule | The rule tightens a default | Project rules tighten; only settings keys loosen. Add the key, or report the gap |

## Status line
A plugin cannot add a status line. Add this to your own `statusLine` command to show `[kern terse]`, `[kern html]` or `[kern autopilot]`:

```bash
sid=$(sed -n 's/.*"session_id":"\([A-Za-z0-9_-]*\)".*/\1/p'); f="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/kern-kern}/sessions/$sid.state"
[ -f "$f" ] && awk -F': ' '$1=="autopilot"&&$2=="on"{a=1} $1=="voice"&&$2=="terse"{t=1} $1=="surface"&&$2=="html"{h=1} END{if(a)printf "[kern autopilot] "; if(t)printf "[kern terse] "; if(h)printf "[kern html] "}' "$f"
```
````

- [ ] **Step 6: Write `skills/help/templates/kern.local.yml`**

```yaml
# kern settings for this project. Untracked: listed in .git/info/exclude by /kern:help setup.
# One `key: value` per line. Quote a value that ends in a space. Lists are comma-separated.
# Every key is documented in kern's kernel/settings.md. Delete lines you do not need.

# Repo
base_branch: main
# branch.pattern: {id}/{slug}
# branch.protected: main, production
# worktree.dir: .claude/worktrees
# worktree.setup: npm ci
# shared_services: postgres

# Checks (detected when unset; set only where detection is wrong)
# test.full: npm test
# test.focused: npm test -- {file}
# typecheck: npm run type-check
# lint: npm run lint
# build: npm run build
# verify.browser: node scripts/browser-check.mjs

# Git and PRs
# commit.convention: "^[A-Z]+-[0-9]+: "
# commit.attribution: none
# commit.policy: ask
# push.policy: ask
# pr.policy: ask
# rebase.push: ask

# Tracking
# tracker: linear
# tracker.first: false
# tracker.policy: ask

# Review
# review.taxonomy: blocker,should-fix,nit,pre-existing
# review.post_policy: ask

# Risk
# autopilot: allowed
# protected_targets: prod-db.internal
# deploy.envs: production
# never_commit: *.db, .env*
# scope_threshold: 4

# Modes
# mode.voice: normal
# mode.surface: auto

# Project skills that own a kern job (kern's guards still apply to them)
# overrides.commit: commit
# overrides.self-review: self-review
```

- [ ] **Step 7: Add rule 6 to `scripts/lib/lint-rules.mjs`**

Insert this entry into `RULES`, after the rule 11 entry and before the `];` that closes the array:

```js
  { id: 6, check(model) {
    const out = [];
    const rows = [...model.kernelText.matchAll(/^\|[^|\n]*\|\s*Read \{(KERN|ROOT)\}\/([^\s|]+)\s*\|\s*$/gm)];
    for (const m of rows) {
      const target = m[1] === 'KERN' ? join('skills', m[2]) : m[2];
      const file = join(model.root, target);
      if (!existsSync(file)) { out.push(err(6, 'kernel/kernel.md', `route ${target} does not exist`)); continue; }
      const body = parseFrontmatter(readFileSync(file, 'utf8')).body.replace(/\r\n/g, '\n');
      const firstH2 = body.split('\n').find((l) => l.startsWith('## '));
      if (firstH2 !== '## Steps') out.push(err(6, target, 'a route file must open with ## Steps'));
      else if (!/^## Steps\n+1\. /m.test(body)) out.push(err(6, target, '## Steps must open with a numbered list'));
    }
    const mapFile = join(model.root, 'skills', 'help', 'references', 'map.md');
    if (existsSync(mapFile)) {
      const listed = new Set([...readFileSync(mapFile, 'utf8').matchAll(/^\| `([a-z0-9-]+)` \|/gm)].map((m) => m[1]));
      for (const s of model.skills) {
        if (s.data['user-invocable'] === 'false') continue;
        if (!listed.has(s.name)) out.push(err(6, rel(model, s.file), `${s.name} is missing from skills/help/references/map.md`));
      }
    }
    return out;
  } },
```

- [ ] **Step 8: Exempt the M0 placeholder from the help map**

`scripts/lint-exemptions.json`:
```json
[
  { "rule": 6, "path": "skills/hello/SKILL.md", "reason": "M0 placeholder skill, removed in M2; it is not part of the help map." }
]
```

- [ ] **Step 9: Run the tests and lint to verify they pass**

Run: `node --test tests/skills-help.test.mjs tests/lint-rules.test.mjs && node scripts/lint-skills.mjs`
Expected: `# fail 0` for both; `lint: clean`.

- [ ] **Step 10: Commit**

```bash
git add -- skills/help tests/skills-help.test.mjs scripts/lib/lint-rules.mjs scripts/lint-exemptions.json tests/lint-rules.test.mjs
git commit -m "M1: add the help skill and lint rule 6" -m "help is the human index and the only writer of project settings, after a yes; rule 6 keeps every route resolvable and every skill on the map."
```

---

