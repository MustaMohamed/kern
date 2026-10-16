### Task 17: Lint rules 7, 13 and 15, hook-shape fixtures, CI

**Files:**
- Create: `tests/fixtures/projects/{no-settings,shared-only,local-only,both,kern-off,floor-policy-key,unknown-key,long-settings}/` (`expect.txt` plus `kern.local.yml` and/or `kern.yml`), `tests/hook-shape.sh`
- Modify: `scripts/lib/lint-rules.mjs` (imports, rules 7, 13, 15), `tests/lint-rules.test.mjs`, `.github/workflows/ci.yml`, `scripts/ci-local`

**Interfaces:**
- Consumes: every hook; `kernel/settings.md`; M0 lint helpers `walk`, `err`, `warn`, `rel`.
- Produces: rule 7 (rendered kernel over 4,000 chars with the `long-settings` fixture is a warning; kernel plus terse rules over 9,000 is an error; subagent context plus the terse line over 1,200 is an error; paths are measured with a 50-character root); rule 13 (every key a hook or `scripts/kern-*` reads is in the table, and every table row that names a hook or kern script as reader is read by one); rule 15 (the eight fixture cases and `tests/hook-shape.sh` exist once hooks exist). `tests/hook-shape.sh` runs all four hooks over each fixture.

- [ ] **Step 1: Write the fixtures**

```bash
F=tests/fixtures/projects
mkdir -p $F/no-settings $F/shared-only $F/local-only $F/both $F/kern-off $F/floor-policy-key $F/unknown-key $F/long-settings
printf 'Settings files: none; defaults apply\nkern mode: voice=normal surface=auto autopilot=off\n' >$F/no-settings/expect.txt
printf 'push.policy: deny\n' >$F/shared-only/kern.yml
printf 'Settings files: .claude/kern.yml\nSet: push.policy=deny\n' >$F/shared-only/expect.txt
printf 'base_branch: develop\n' >$F/local-only/kern.local.yml
printf 'Settings files: .claude/kern.local.yml\nSet: base_branch=develop\n' >$F/local-only/expect.txt
printf 'push.policy: auto\n' >$F/both/kern.local.yml
printf 'push.policy: deny\nmode.voice: terse\n' >$F/both/kern.yml
printf 'Settings files: .claude/kern.local.yml, .claude/kern.yml\npush.policy=auto\nmode.voice=terse\n# kern terse voice\n' >$F/both/expect.txt
printf 'kern: off\n' >$F/kern-off/kern.local.yml
printf '<empty>\n' >$F/kern-off/expect.txt
printf 'merge.policy: auto\npush.policy: auto\n' >$F/floor-policy-key/kern.local.yml
printf 'Ignored, floor actions have no key: merge.policy\nSet: push.policy=auto\n' >$F/floor-policy-key/expect.txt
printf 'banana: 1\n' >$F/unknown-key/kern.local.yml
printf 'Unknown keys, ignored: banana\n' >$F/unknown-key/expect.txt
printf '(more: /kern:help check)\n' >$F/long-settings/expect.txt
```

`tests/fixtures/projects/long-settings/kern.local.yml`:
```yaml
base_branch: main
branch.pattern: {id}/{slug}
branch.protected: main, qa, uat, production
deploy.envs: qa, uat, production
worktree.setup: ln -s ../node_modules node_modules && cp ../.env .env
shared_services: postgres, minio, localstack, cognito
test.full: npm test --prefix cds-api && npm test --prefix cds-web
test.focused: npx jest {file}
typecheck: npx tsc --noEmit -p cds-api && npx tsc --noEmit -p cds-web
lint: npm run lint
verify.browser: node scripts/cds-session.mjs --env local --probe /dashboard
commit.convention: "^CDS-[0-9]+: "
tracker: linear
tracker.first: true
review.taxonomy: Bug,Suggestion,Nit
protected_targets: v1-prod-host, prod-db.internal, 10.0.0.12
never_commit: migration-dashboard/data/migration_dashboard.db, .env*, *.pem
scope_threshold: 4
overrides.commit: commit
overrides.self-review: self-review
route.diagnose: investigate-bug
```

- [ ] **Step 2: Write `tests/hook-shape.sh`**

```bash
#!/usr/bin/env bash
# Runs every hook over the fixture projects in tests/fixtures/projects (lint rule 15).
# Per case: SessionStart output holds each line of expect.txt (or is empty for <empty>);
# SubagentStart prints valid JSON within 1,200 characters; UserPromptSubmit and PreToolUse
# exit 0 and print nothing or valid JSON.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail=0
cases=0

json_ok() {
  node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{if(!s.trim())process.exit(0);JSON.parse(s)})'
}

for dir in "$ROOT"/tests/fixtures/projects/*/; do
  name=$(basename "$dir")
  cases=$((cases + 1))
  repo="$TMP/$name/repo"
  mkdir -p "$repo/.claude" "$TMP/$name/home/.claude"
  git init -q "$repo"
  for f in kern.local.yml kern.yml; do
    [ -f "$dir/$f" ] && cp "$dir/$f" "$repo/.claude/$f"
  done
  export HOME="$TMP/$name/home" CLAUDE_PLUGIN_DATA="$TMP/$name/data"
  base="\"session_id\":\"shape-$name\",\"cwd\":\"$repo\""
  out=$(printf '{%s,"hook_event_name":"SessionStart","source":"startup"}' "$base" | bash "$ROOT/hooks/session-start")
  while IFS= read -r want; do
    [ -n "$want" ] || continue
    if [ "$want" = "<empty>" ]; then
      [ -z "$out" ] || { echo "FAIL $name: expected no output"; fail=1; }
    elif [[ "$out" != *"$want"* ]]; then
      echo "FAIL $name: missing: $want"
      fail=1
    fi
  done <"$dir/expect.txt"
  sub=$(printf '{%s,"hook_event_name":"SubagentStart","agent_id":"a","agent_type":"Explore"}' "$base" | bash "$ROOT/hooks/subagent-start")
  printf '%s' "$sub" | json_ok || { echo "FAIL $name: SubagentStart output is not JSON"; fail=1; }
  [ "${#sub}" -le 1400 ] || { echo "FAIL $name: SubagentStart output ${#sub} chars"; fail=1; }
  printf '{%s,"hook_event_name":"UserPromptSubmit","prompt":"hello"}' "$base" | bash "$ROOT/hooks/prompt-submit" >/dev/null ||
    { echo "FAIL $name: prompt-submit exited non-zero"; fail=1; }
  pre=$(printf '{%s,"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git status"}}' "$base" | bash "$ROOT/hooks/pre-tool-use")
  printf '%s' "$pre" | json_ok || { echo "FAIL $name: PreToolUse output is not JSON"; fail=1; }
done
[ "$fail" = 0 ] || exit 1
echo "hook-shape: $cases cases passed"
```

- [ ] **Step 3: Write the failing lint tests**

Append to `tests/lint-rules.test.mjs`:

```js
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
```

- [ ] **Step 4: Run them to verify they fail**

Run: `node --test tests/lint-rules.test.mjs`
Expected: FAIL in the rule 7, 13 and 15 tests (no rule reports those ids).

- [ ] **Step 5: Add the rules**

Replace the first two import lines of `scripts/lib/lint-rules.mjs` with:

```js
import { readFileSync, readdirSync, existsSync, statSync, mkdtempSync, mkdirSync, copyFileSync, rmSync } from 'node:fs';
import { join, relative } from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';
```

Then insert these entries into `RULES`, after rule 6 and before the closing `];`:

```js
  { id: 7, check(model) {
    if (!existsSync(join(model.root, 'hooks', 'session-start'))) return [];
    const out = [];
    const tmp = mkdtempSync(join(tmpdir(), 'kern-rule7-'));
    const repo = join(tmp, 'repo');
    mkdirSync(join(repo, '.claude'), { recursive: true });
    spawnSync('git', ['init', '-q', repo]);
    const fixture = join(model.root, 'tests', 'fixtures', 'projects', 'long-settings');
    for (const f of ['kern.local.yml', 'kern.yml']) if (existsSync(join(fixture, f))) copyFileSync(join(fixture, f), join(repo, '.claude', f));
    const env = { ...process.env, HOME: join(tmp, 'home'), CLAUDE_PLUGIN_DATA: join(tmp, 'data') };
    const hook = (name, payload) => spawnSync('bash', [join(model.root, 'hooks', name)], { input: JSON.stringify(payload), env, encoding: 'utf8' }).stdout || '';
    const norm = (s) => s.split(model.root).join('/Users/someone/.claude/plugins/cache/kern/kern/0.1.0');
    const kernel = norm(hook('session-start', { session_id: 'lint', source: 'startup', cwd: repo, hook_event_name: 'SessionStart' }));
    const terse = existsSync(join(model.root, 'modes', 'terse.md')) ? readFileSync(join(model.root, 'modes', 'terse.md'), 'utf8').length : 0;
    if (kernel.length > 4000) out.push(warn(7, 'kernel/kernel.md', `rendered kernel ${kernel.length} chars with the longest fixture settings, target 4,000`));
    if (kernel.length + terse > 9000) out.push(err(7, 'kernel/kernel.md', `rendered kernel plus terse rules ${kernel.length + terse} chars, limit 9,000`));
    const sub = hook('subagent-start', { session_id: 'lint', cwd: repo, hook_event_name: 'SubagentStart', agent_id: 'a', agent_type: 'Explore' });
    let ctx = '';
    try { ctx = norm(JSON.parse(sub).hookSpecificOutput.additionalContext); } catch { out.push(err(7, 'hooks/subagent-start', 'output is not SubagentStart JSON')); }
    const terseSub = existsSync(join(model.root, 'modes', 'terse-subagent.md')) ? readFileSync(join(model.root, 'modes', 'terse-subagent.md'), 'utf8').length : 0;
    if (ctx.length + terseSub > 1200) out.push(err(7, 'kernel/kernel-subagent.md', `subagent kernel with terse voice ${ctx.length + terseSub} chars, limit 1,200`));
    rmSync(tmp, { recursive: true, force: true });
    return out;
  } },
  { id: 13, check(model) {
    const table = join(model.root, 'kernel', 'settings.md');
    if (!existsSync(table)) return [];
    const out = [];
    const rows = readFileSync(table, 'utf8').split('\n').filter((l) => /^\| `/.test(l)).map((l) => {
      const cells = l.split('|').slice(1, -1).map((c) => c.trim());
      return { key: cells[0].replace(/`/g, ''), readBy: cells[cells.length - 1] };
    });
    const prefix = (k) => (k.includes('<') ? k.slice(0, k.indexOf('<')) : null);
    const known = (k) => rows.some((r) => r.key === k || (prefix(r.key) && k.startsWith(prefix(r.key))));
    const code = [...walk(join(model.root, 'hooks')), ...walk(join(model.root, 'scripts')).filter((f) => /\/kern-[a-z]+$/.test(f))]
      .map((f) => ({ f, text: readFileSync(f, 'utf8') }));
    const read = new Map();
    const add = (k, f) => { if (!read.has(k)) read.set(k, f); };
    for (const { f, text } of code) {
      for (const m of text.matchAll(/settings_(?:get|source)\s+"?([a-z_][a-z0-9_.]*)/g)) add(m[1], f);
      for (const m of text.matchAll(/policy_for\s+"?([a-z][a-z.]*)/g)) if (m[1] !== 'ACTION') add(m[1] === 'review.post' ? 'review.post_policy' : `${m[1]}.policy`, f);
      if (f.endsWith('/kern-detect')) for (const m of text.matchAll(/^ {2}([a-z_.]+)\)$/gm)) add(m[1], f);
    }
    for (const [k, f] of read) if (!known(k)) out.push(err(13, rel(model, f), `reads settings key ${k}, which kernel/settings.md does not list`));
    const hookReader = /session-start|subagent-start|prompt-submit|pre-tool-use|kern-detect|kern-dir|kern-get/;
    const allCode = code.map((c) => c.text).join('\n');
    for (const r of rows) {
      if (!hookReader.test(r.readBy)) continue;
      const ok = prefix(r.key) ? allCode.includes(prefix(r.key)) : read.has(r.key);
      if (!ok) out.push(err(13, 'kernel/settings.md', `${r.key} names a hook or kern script as reader, but none reads it`));
    }
    return out;
  } },
  { id: 15, check(model) {
    if (!existsSync(join(model.root, 'hooks', 'session-start'))) return [];
    const out = [];
    for (const c of ['no-settings', 'shared-only', 'local-only', 'both', 'kern-off', 'floor-policy-key', 'unknown-key', 'long-settings']) {
      if (!existsSync(join(model.root, 'tests', 'fixtures', 'projects', c, 'expect.txt'))) out.push(err(15, `tests/fixtures/projects/${c}`, 'hook-shape fixture has no expect.txt'));
    }
    if (!existsSync(join(model.root, 'tests', 'hook-shape.sh'))) out.push(err(15, 'tests/hook-shape.sh', 'hook-shape runner missing'));
    return out;
  } },
```

- [ ] **Step 6: Run the hook-shape script, the tests and lint**

Run: `chmod +x tests/hook-shape.sh && bash tests/hook-shape.sh && node --test tests/lint-rules.test.mjs && node scripts/lint-skills.mjs`
Expected: `hook-shape: 8 cases passed`; `# fail 0`; `lint: clean` with no rule 7 warning.

- [ ] **Step 7: Extend CI and `scripts/ci-local`**

Append to the steps of job `checks` in `.github/workflows/ci.yml`, after the existing `Shellcheck` step:

```yaml
      - name: Hook tests
        run: tests/run-bats tests/hooks
      - name: Hook shape over fixture projects
        run: bash tests/hook-shape.sh
      - name: Shellcheck hooks and kern scripts
        run: shellcheck -x -S warning hooks/lib/*.sh hooks/guards/*.sh hooks/session-start hooks/subagent-start hooks/prompt-submit hooks/pre-tool-use scripts/kern-root scripts/kern-get scripts/kern-dir scripts/kern-detect tests/hook-shape.sh tests/run-bats tests/helpers/common.bash
```

In `scripts/ci-local` and in the `Script tests` step of `.github/workflows/ci.yml`, replace `bats tests/scripts` with `tests/run-bats tests/scripts`. Then, in `scripts/ci-local`, insert before the final `echo` line:

```bash
tests/run-bats tests/hooks
bash tests/hook-shape.sh
shellcheck -x -S warning hooks/lib/*.sh hooks/guards/*.sh hooks/session-start hooks/subagent-start hooks/prompt-submit hooks/pre-tool-use scripts/kern-root scripts/kern-get scripts/kern-dir scripts/kern-detect tests/hook-shape.sh tests/run-bats tests/helpers/common.bash
```

`-S warning` keeps shellcheck's informational notes (single quotes around awk programs) out of the exit code.

- [ ] **Step 8: Run the whole local CI**

Run: `scripts/ci-local`
Expected: last line `ci-local: all steps passed`.

- [ ] **Step 9: Commit**

```bash
git add -- tests/fixtures/projects tests/hook-shape.sh scripts/lib/lint-rules.mjs tests/lint-rules.test.mjs .github/workflows/ci.yml scripts/ci-local
git commit -m "M1: check kernel size, settings keys and hook shape in CI" -m "The kernel's budget, the key table and every hook's output shape are mechanical facts; CI checks them on every push."
```

---

