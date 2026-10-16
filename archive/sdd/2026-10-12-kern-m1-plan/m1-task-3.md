### Task 3: Settings layer and key table

**Files:**
- Create: `hooks/lib/settings.sh`, `kernel/settings.md`, `scripts/kern-get`
- Test: `tests/hooks/settings.bats`

**Interfaces:**
- Consumes: `tests/helpers/common.bash` (Task 2).
- Produces: `kern_main_root [DIR]` (exit 2 not a repo), `settings_get KEY [DEFAULT]` (exit 3 unset), `settings_source KEY` (file or `default`), `settings_keys FILE`, `settings_known_keys`, `settings_unknown_keys` (`file<TAB>key`), `policy_for commit|push|pr|tracker|review.post` (`ask|auto|deny`), `kern_enabled`, `list_has LIST ITEM`, internal `_settings_files`. Needs `KERN_ROOT`; uses `KERN_MAIN` when set, else `CWD`, else `PWD`. CLI `bash scripts/kern-get KEY [DEFAULT]` prints `value<TAB>source`. `kernel/settings.md`: one table row per key, first cell the key in backticks, last cell "Read by".

- [ ] **Step 1: Write the failing test**

`tests/hooks/settings.bats`:
```bash
#!/usr/bin/env bats
# hooks/lib/settings.sh and scripts/kern-get: layering, comments, quotes, worktrees, policies.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  mkdir -p "$R/.claude"
  RP=$(cd "$R" && pwd -P)
  export KERN_ROOT
  KERN_ROOT="$(kern_root)"
  # shellcheck source=hooks/lib/settings.sh
  . "$KERN_ROOT/hooks/lib/settings.sh"
}

@test "local beats shared beats user; default when unset; 3 with no default" {
  printf 'push.policy: auto\n' >"$R/.claude/kern.local.yml"
  printf 'push.policy: deny\nbase_branch: develop\n' >"$R/.claude/kern.yml"
  printf 'base_branch: trunk\nmode.voice: terse\n' >"$HOME/.claude/kern.yml"
  [ "$(settings_get push.policy)" = auto ]
  [ "$(settings_get base_branch)" = develop ]
  [ "$(settings_get mode.voice)" = terse ]
  [ "$(settings_get nope dflt)" = dflt ]
  run settings_get nope
  [ "$status" -eq 3 ]
  [ "$(settings_source base_branch)" = "$RP/.claude/kern.yml" ]
  [ "$(settings_source nope)" = default ]
}

@test "comments, quotes, colons and hashes inside values" {
  cat >"$R/.claude/kern.local.yml" <<'YML'
# comment line
commit.convention: "^CDS-[0-9]+: "   # keeps the trailing space
review.taxonomy: 'Bug,Suggestion # not a comment,Nit'
deploy.proof: http://host/x#frag
YML
  [ "$(settings_get commit.convention)" = '^CDS-[0-9]+: ' ]
  [ "$(settings_get review.taxonomy)" = 'Bug,Suggestion # not a comment,Nit' ]
  [ "$(settings_get deploy.proof)" = 'http://host/x#frag' ]
}

@test "CRLF settings files read the same" {
  printf 'push.policy: auto\r\n' >"$R/.claude/kern.local.yml"
  [ "$(settings_get push.policy)" = auto ]
}

@test "a linked worktree reads the main checkout's untracked settings" {
  printf 'push.policy: auto\n' >"$R/.claude/kern.local.yml"
  git -C "$R" worktree add -q -b wt "$BATS_TEST_TMPDIR/wt"
  cd "$BATS_TEST_TMPDIR/wt"
  run bash "$KERN_ROOT/scripts/kern-get" push.policy
  [ "$status" -eq 0 ]
  [ "$output" = "auto	$RP/.claude/kern.local.yml" ]
}

@test "kern-get prints value and source; exit 3 when unset" {
  cd "$R"
  run bash "$KERN_ROOT/scripts/kern-get" work_dir .kern
  [ "$output" = ".kern	default" ]
  run bash "$KERN_ROOT/scripts/kern-get" nope
  [ "$status" -eq 3 ]
}

@test "policy_for maps values; draft-after-approval and junk read as ask" {
  printf 'pr.policy: draft-after-approval\npush.policy: auto\ncommit.policy: banana\nreview.post_policy: deny\n' >"$R/.claude/kern.local.yml"
  [ "$(policy_for pr)" = ask ]
  [ "$(policy_for push)" = auto ]
  [ "$(policy_for commit)" = ask ]
  [ "$(policy_for review.post)" = deny ]
  [ "$(policy_for tracker)" = ask ]
}

@test "unknown keys are listed; families such as overrides.<job> are known" {
  printf 'overrides.commit: commit\nfoo.bar: 1\npush.policy: ask\n' >"$R/.claude/kern.local.yml"
  run settings_unknown_keys
  [ "$output" = "$RP/.claude/kern.local.yml	foo.bar" ]
}

@test "kern: off disables; list_has trims" {
  printf 'kern: off\n' >"$R/.claude/kern.local.yml"
  run kern_enabled
  [ "$status" -eq 1 ]
  list_has "a, b ,c" b
  run list_has "a,b" z
  [ "$status" -eq 1 ]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run-bats tests/hooks/settings.bats`
Expected: FAIL with `hooks/lib/settings.sh: No such file or directory`.

- [ ] **Step 3: Write `hooks/lib/settings.sh`**

```bash
# shellcheck shell=bash
# kern settings: layered flat `key: value` files resolved from the main worktree root.
# Needs KERN_ROOT (plugin root). Uses KERN_MAIN when set, else resolves it from CWD (or PWD).

# kern_main_root [dir]: the main worktree root (first `worktree` line of the porcelain list).
kern_main_root() {
  local dir="${1:-${CWD:-$PWD}}" line
  line=$(git -C "$dir" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p' | head -n 1)
  [ -n "$line" ] || return 2
  printf '%s\n' "$line"
}

# _settings_files: the settings files in precedence order, one per line (existing or not).
_settings_files() {
  local main="${KERN_MAIN-}"
  if [ -z "$main" ]; then main=$(kern_main_root "${CWD:-$PWD}" 2>/dev/null) || main=""; fi
  if [ -n "$main" ]; then
    printf '%s\n' "$main/.claude/kern.local.yml" "$main/.claude/kern.yml"
  fi
  printf '%s\n' "$HOME/.claude/kern.yml"
}

# _settings_lookup FILE KEY: prints the value of KEY in FILE (last occurrence wins). Exit 1 absent.
_settings_lookup() {
  LC_ALL=C awk -v key="$2" -v sq="'" '
    {
      line = $0
      sub(/\r$/, "", line)
      if (line ~ /^[ \t]*#/ || line ~ /^[ \t]*$/) next
      p = index(line, ":")
      if (p == 0) next
      k = substr(line, 1, p - 1)
      gsub(/^[ \t]+|[ \t]+$/, "", k)
      if (k != key) next
      v = substr(line, p + 1)
      out = ""; q = ""; m = length(v)
      for (i = 1; i <= m; i++) {
        c = substr(v, i, 1)
        if (q == "" && (c == "\"" || c == sq)) q = c
        else if (q != "" && c == q) q = ""
        else if (q == "" && c == "#" && (i == 1 || substr(v, i - 1, 1) ~ /[ \t]/)) break
        out = out c
      }
      gsub(/^[ \t]+|[ \t]+$/, "", out)
      f = substr(out, 1, 1); l = substr(out, length(out), 1)
      if (length(out) >= 2 && f == l && (f == "\"" || f == sq)) out = substr(out, 2, length(out) - 2)
      val = out; found = 1
    }
    END { if (found) { print val; exit 0 } exit 1 }' "$1"
}

# settings_get KEY [DEFAULT]: prints the resolved value. Exit 0 found or defaulted, 3 unset.
settings_get() {
  local f v
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    if v=$(_settings_lookup "$f" "$1"); then
      printf '%s\n' "$v"
      return 0
    fi
  done <<EOT
$(_settings_files)
EOT
  if [ $# -ge 2 ]; then
    printf '%s\n' "$2"
    return 0
  fi
  return 3
}

# settings_source KEY: prints the file that sets KEY, or `default`. Exit 0 always.
settings_source() {
  local f
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    if _settings_lookup "$f" "$1" >/dev/null; then
      printf '%s\n' "$f"
      return 0
    fi
  done <<EOT
$(_settings_files)
EOT
  printf 'default\n'
}

# settings_keys FILE: every key set in FILE, one per line.
settings_keys() {
  LC_ALL=C awk '
    { line = $0; sub(/\r$/, "", line) }
    line ~ /^[ \t]*#/ || line ~ /^[ \t]*$/ { next }
    { p = index(line, ":"); if (p == 0) next
      k = substr(line, 1, p - 1); gsub(/^[ \t]+|[ \t]+$/, "", k); print k }' "$1" | sort -u
}

# settings_known_keys: the key column of kernel/settings.md, one per line. A `<...>` part is a wildcard.
settings_known_keys() {
  sed -n 's/^| `\([^`]*\)` |.*/\1/p' "$KERN_ROOT/kernel/settings.md"
}

# settings_unknown_keys: `file<TAB>key` for every key that kernel/settings.md does not list.
settings_unknown_keys() {
  local f k known pat ok
  known=$(settings_known_keys)
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    while IFS= read -r k; do
      [ -n "$k" ] || continue
      ok=1
      while IFS= read -r pat; do
        case "$pat" in
          *'<'*'>'*) case "$k" in "${pat%%<*}"?*) ok=0 ;; esac ;;
          *) [ "$k" = "$pat" ] && ok=0 ;;
        esac
        [ "$ok" = 0 ] && break
      done <<EOT
$known
EOT
      [ "$ok" = 1 ] && printf '%s\t%s\n' "$f" "$k"
    done <<EOT
$(settings_keys "$f")
EOT
  done <<EOT
$(_settings_files)
EOT
}

# policy_for ACTION: ask|auto|deny for commit, push, pr, tracker or review.post.
policy_for() {
  local key v
  case "$1" in
    review.post) key=review.post_policy ;;
    *) key="$1.policy" ;;
  esac
  v=$(settings_get "$key" ask)
  case "$v" in
    auto|deny) printf '%s\n' "$v" ;;
    *) printf 'ask\n' ;;
  esac
}

# kern_enabled: exit 0 unless the resolved `kern` key is `off`.
kern_enabled() {
  [ "$(settings_get kern on)" != off ]
}

# list_has LIST ITEM: exit 0 when the comma-separated LIST contains ITEM (whitespace trimmed).
list_has() {
  local rest="$1," item
  while [ -n "$rest" ]; do
    item=${rest%%,*}; rest=${rest#*,}
    item=$(printf '%s' "$item" | sed 's/^[ \t]*//; s/[ \t]*$//')
    [ -n "$item" ] && [ "$item" = "$2" ] && return 0
  done
  return 1
}
```

- [ ] **Step 4: Write `kernel/settings.md`**

```markdown
# kern settings

Files, highest first: `.claude/kern.local.yml` (untracked, the default per-project file), `.claude/kern.yml` (shared, committed only if a team wants it), `~/.claude/kern.yml` (user defaults). Project files are read from the main worktree root. Above all files: the user's instruction in this session, then a project skill that owns the job, then project rules (CLAUDE.md, `.claude/rules`, memory), which may tighten and never loosen.

Format: one `key: value` per line. `#` starts a comment at line start or after whitespace outside quotes. Surrounding quotes are stripped; quote a value that ends in a space. Lists are comma-separated. A key with `<...>` in this table stands for a family, such as `overrides.commit`.

Policy keys take `ask` (default), `auto` or `deny`. Floor actions have no key and never loosen: merge, production deploy, data deletion, force-push to a shared branch, messaging people. A key that names a floor action is reported and ignored.

| Key | Default | Values | Read by |
|---|---|---|---|
| `kern` | `on` | `on`, `off` (no routing, no guards in this project) | session-start, subagent-start, prompt-submit, pre-tool-use |
| `kern_repo` | none | path to the kern clone (user file only) | help |
| `work_dir` | `.kern` | relative directory at the main worktree root | kern-dir, all skills |
| `mode.voice` | `normal` | `normal`, `terse` | session-start, prompt-submit, subagent-start |
| `mode.surface` | `auto` | `chat`, `auto`, `html` | session-start, prompt-submit |
| `autopilot` | `allowed` | `allowed`, `denied` | prompt-submit, pre-tool-use (G1, G2, G5, G14, G15) |
| `base_branch` | detected from `refs/remotes/origin/HEAD` | branch name | pre-tool-use (G1, G6), kern-detect, plan, finish-branch |
| `branch.pattern` | detected | pattern with `{id}` and `{slug}` | kern-detect, execute-plan, wt-new |
| `branch.protected` | `base_branch` plus `deploy.envs` | comma list | pre-tool-use (G1), commit, finish-branch |
| `deploy.envs` | none | comma list of deploy branches | pre-tool-use (G1, G15), finish-branch, ship-check |
| `deploy.proof` | none | command or URL that proves a deploy | ship-check |
| `worktree.dir` | `.claude/worktrees` | directory under the main worktree root | wt-new, execute-plan, parallel-work |
| `worktree.setup` | none; `.worktreeinclude` honoured | shell command run in a new worktree | wt-new |
| `shared_services` | none: migrations and DB-backed tests overlap | comma list | plan, execute-plan, parallel-work |
| `parallel.max` | `3` | integer | parallel-work |
| `scope_threshold` | `4` | files per change before a pause | define, plan, implement, self-review, finish-branch |
| `pr.max_lines` | `300` | changed lines before a split is proposed | finish-branch |
| `test.focused` | detected | command; `{file}` stands for the test path | kern-detect, implement, diagnose, prove-it |
| `test.full` | detected | command | kern-detect, implement, prove-it, finish-branch |
| `typecheck` | detected | command | kern-detect, implement, prove-it |
| `lint` | detected | command | kern-detect, prove-it |
| `build` | detected | command | kern-detect, prove-it |
| `verify.fast` | `typecheck` then `lint` | command | self-review, prove-it |
| `verify.browser` | none: ask when a UI claim needs it | command | prove-it, diagnose, verify-app |
| `generated_artifacts` | none | comma list of `trigger-glob=command` | implement, prove-it, self-review |
| `checklists` | existing data and consumers; authorization scope; persisted-shape change | comma list | define, plan |
| `tracker` | detected | `none`, `github`, `gitlab`, `linear`, `jira`, or another name | kern-detect, define, plan, recall, triage |
| `tracker.first` | `false` | `true`, `false` | define, plan |
| `tracker.policy` | `ask` | `ask`, `auto`, `deny` | pre-tool-use (G14) |
| `mcp.write_servers` | none | comma list of extra MCP server names treated as trackers | pre-tool-use (G14) |
| `spec.source` | linked issue, PR body, `.kern/specs` | path or `issue` | prove-it, pr-review |
| `commit.convention` | detected from `git log` | extended regular expression for the subject | pre-tool-use (G5), kern-detect, commit |
| `commit.id_from_branch` | `[A-Z][A-Z0-9]+-[0-9]+` | extended regular expression | pre-tool-use (G5), commit |
| `commit.attribution` | `none` | `none`, `allowed` | pre-tool-use (G5), commit |
| `commit.policy` | `ask` | `ask`, `auto`, `deny` | pre-tool-use (G5), commit |
| `push.policy` | `ask` | `ask`, `auto`, `deny` | pre-tool-use (G1), finish-branch |
| `pr.policy` | `draft-after-approval` (read as `ask`) | `ask`, `auto`, `deny`; PRs are always drafts | pre-tool-use (G2), finish-branch |
| `pr.dedup` | `on` | `on` (G2 always checks) | finish-branch |
| `pr.template` | detected | path | kern-detect, finish-branch |
| `rebase.push` | `ask` | `ask`, `autopilot` | pre-tool-use (G1), take-feedback |
| `stack.tool` | detected | `gh-stack`, `git`, `none` | take-feedback, finish-branch |
| `protected_targets` | none | comma list of hosts, DSN fragments or profiles | pre-tool-use (G13), diagnose |
| `evidence_agents` | none | comma list of project agents for read-only data | diagnose |
| `never_commit` | none | comma list of path globs | pre-tool-use (G6), commit |
| `review.rules` | CLAUDE.md, `.claude/rules/**`, CONTRIBUTING.md | comma list of paths | self-review, execute-plan, pr-review |
| `review.taxonomy` | `blocker,should-fix,nit,pre-existing` | comma list of labels | pre-tool-use (G3), self-review, pr-review |
| `review.post_policy` | `ask` | `ask`, `auto`, `deny` | pre-tool-use (G3) |
| `review.rounds` | `fanout-first-then-single` | `fanout-first-then-single`, `single` | pr-review |
| `review.sensitive_paths` | auth, permission, migration and secret paths by name | comma list of globs | pr-review |
| `review.builtin` | `on` | `on`, `off` | self-review, pr-review |
| `review.builtin.self_effort` | `low` | `low`, `medium`, `high` | self-review |
| `review.builtin.effort` | `high` | `low`, `medium`, `high`, `xhigh`, `max` | pr-review |
| `review.builtin.delta_effort` | `medium` | as above | pr-review |
| `review.builtin.max_findings` | `15` | integer or `all` | self-review, pr-review |
| `review.builtin.security` | `off` | `on`, `off` | pr-review |
| `security.rules` | project prose | comma list of paths | pr-review |
| `lessons` | none: proposals stay in chat | path | self-review, retro, correct |
| `rule_bar` | 3 occurrences or 1 severe incident; 2 for a mechanism | text | retro, correct |
| `model.implementer` | `sonnet` | model alias | execute-plan, parallel-work |
| `model.reviewer` | `sonnet` | model alias | execute-plan |
| `model.final_review` | `opus` | model alias | execute-plan |
| `model.investigator` | `sonnet` | model alias | define, plan, diagnose |
| `model.miner` | `haiku` | model alias | recall |
| `workflow_records` | none | comma list of paths or tools with run records | recall |
| `stack` | detected | text | architect, build-ui, implement |
| `overrides.<job>` | none; a same-name project skill is found by session-start | project skill name, or `off` | session-start, every skill |
| `route.<name>` | none | project skill name, or `off` | session-start |
```

- [ ] **Step 5: Write `scripts/kern-get`**

```bash
#!/usr/bin/env bash
# Layered settings read. Prints `value<TAB>source`; exit 3 when unset and no default is given.
set -euo pipefail
KERN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export KERN_ROOT
# shellcheck source=hooks/lib/settings.sh
. "$KERN_ROOT/hooks/lib/settings.sh"
[ $# -ge 1 ] || { echo "usage: kern-get KEY [DEFAULT]" >&2; exit 2; }
CWD="$PWD"
KERN_MAIN=$(kern_main_root "$CWD" 2>/dev/null) || KERN_MAIN=""
export CWD KERN_MAIN
if [ $# -ge 2 ]; then
  value=$(settings_get "$1" "$2")
else
  value=$(settings_get "$1") || exit 3
fi
printf '%s\t%s\n' "$value" "$(settings_source "$1")"
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `chmod +x scripts/kern-get && tests/run-bats tests/hooks/settings.bats`
Expected: `8 tests, 0 failures`.

- [ ] **Step 7: Commit**

```bash
git add -- hooks/lib/settings.sh kernel/settings.md scripts/kern-get tests/hooks/settings.bats
git commit -m "M1: add the layered settings reader and the key table" -m "Hooks and skills read one resolver from the main worktree root, so a linked worktree sees the same untracked settings."
```

---

