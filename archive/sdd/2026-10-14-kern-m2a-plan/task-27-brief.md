### Task 27: `recall-sessions`, this project's sessions only

**Files:**
- Create: `scripts/recall-sessions`
- Test: `tests/scripts/recall-sessions.bats`

**Interfaces:**
- Consumes: `kern_main_root` (M1), `wt_dir` (Task 1); Claude Code's transcript folders `~/.claude/projects/<slug>/` (the slug is the path with every character outside A-Z, a-z and 0-9 turned into `-`, so a kern worktree's folder is `<main slug>--claude-worktrees-<name>`) and its prompt index `~/.claude/history.jsonl` (fields `display`, `timestamp` in ms, `project`, `sessionId`).
- Produces: `recall-sessions [--days N] [--topic TEXT]`: `session<TAB><iso mtime><TAB><session id><TAB><bytes><TAB><path>` lines for top-level transcripts of the main worktree and its worktrees modified in the last N days (default 7), newest first; with `--topic`, then `prompt<TAB><iso time><TAB><session id><TAB><first 120 chars>` lines for prompts whose `project` is the main worktree or one of its worktrees and whose text holds TEXT (any case). It never reads another project's transcripts or prompts, and writes nothing. Exit 0; 2 on a usage error or outside a git repository.

- [ ] **Step 1: Write the failing tests**

```bash
#!/usr/bin/env bats
# tests/scripts/recall-sessions.bats

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  cd "$REPO"
  slug=$(printf '%s' "$REPO" | LC_ALL=C tr -c 'A-Za-z0-9' '-')
  P="$HOME/.claude/projects"
  mkdir -p "$P/$slug/subagents" "$P/$slug--claude-worktrees-feat-a" "$P/-other-project"
  printf 'x\n' > "$P/$slug/old.jsonl"; touch -t 202001010000 "$P/$slug/old.jsonl"
  printf 'xx\n' > "$P/$slug/a.jsonl"; touch -t "$(date -v-2d +%Y%m%d%H%M 2> /dev/null || date -d '2 days ago' +%Y%m%d%H%M)" "$P/$slug/a.jsonl"
  printf 'xxx\n' > "$P/$slug/b.jsonl"
  printf 'w\n' > "$P/$slug--claude-worktrees-feat-a/w.jsonl"; touch -t "$(date -v-1d +%Y%m%d%H%M 2> /dev/null || date -d '1 day ago' +%Y%m%d%H%M)" "$P/$slug--claude-worktrees-feat-a/w.jsonl"
  printf 's\n' > "$P/$slug/subagents/child.jsonl"
  printf 'o\n' > "$P/-other-project/o.jsonl"
  now=$(( $(date +%s) * 1000 ))
  {
    printf '{"display":"floci swap: where are we","pastedContents":{},"timestamp":%s,"project":"%s","sessionId":"b"}\n' "$now" "$REPO"
    printf '{"display":"floci in the other repo","pastedContents":{},"timestamp":%s,"project":"/elsewhere","sessionId":"o"}\n' "$now"
    printf '{"display":"unrelated","pastedContents":{},"timestamp":%s,"project":"%s","sessionId":"a"}\n' "$now" "$REPO"
  } > "$HOME/.claude/history.jsonl"
}

@test "this project's sessions, newest first, worktree sessions included, children and old ones skipped" {
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
  [[ "${lines[0]}" == session$'\t'*$'\t'b$'\t'4$'\t'*"/b.jsonl" ]] || false
  [[ "${lines[1]}" == session$'\t'*$'\t'w$'\t'* ]] || false
  [[ "${lines[2]}" == session$'\t'*$'\t'a$'\t'* ]] || false
  [[ "$output" != *other-project* ]] || false
}

@test "--days widens the window" {
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --days 3650
  [ "${#lines[@]}" -eq 4 ]
}

@test "--topic adds this project's matching prompts only" {
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --topic FLOCI
  [ "$(printf '%s\n' "$output" | grep -c '^prompt')" -eq 1 ]
  [[ "$output" == *$'prompt\t'*$'\tb\tfloci swap: where are we'* ]] || false
}

@test "a bad option exits 2" {
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --days soon
  [ "$status" -eq 2 ]
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run-bats tests/scripts/recall-sessions.bats`
Expected: every test fails; `scripts/recall-sessions: No such file or directory`.

- [ ] **Step 3: Write `scripts/recall-sessions`**

```bash
#!/usr/bin/env bash
# List this project's Claude Code sessions for recall: the main worktree's transcripts and its kern
# worktrees', newest first, inside a window; with --topic, also this project's prompts that name the
# topic. Never reads another project's transcripts or prompts. Read-only.
# Usage: recall-sessions [--days N] [--topic TEXT]
# Output: session<TAB><iso mtime><TAB><session id><TAB><bytes><TAB><path>, newest first; the newest is
# usually the session running now. Then, with --topic: prompt<TAB><iso time><TAB><session id><TAB><text>.
# Adapted from the user's recall skill, "Where the records are" (MIT, local copy).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
# shellcheck source=/dev/null
. "$here/../hooks/lib/settings.sh"
# shellcheck source=/dev/null
. "$here/lib/wt-common.sh"
usage() { echo "usage: recall-sessions [--days N] [--topic TEXT]" >&2; exit 2; }
days=7 topic=''
while [ $# -gt 0 ]; do
  case "$1" in
    --days) [ $# -ge 2 ] || usage; days=$2; shift 2 ;;
    --topic) [ $# -ge 2 ] || usage; topic=$2; shift 2 ;;
    *) usage ;;
  esac
done
case "$days" in '' | *[!0-9]*) usage ;; esac
MAIN=$(kern_main_root "$PWD") || { echo "recall-sessions: not a git repository" >&2; exit 2; }
export KERN_MAIN="$MAIN"
projects="$HOME/.claude/projects"
# Claude Code names a project's transcript folder after its path, every character outside A-Z, a-z and
# 0-9 turned into -.
slug() { printf '%s' "$1" | LC_ALL=C tr -c 'A-Za-z0-9' '-'; }
main_slug=$(slug "$MAIN")
wt_slug=$(slug "$(wt_dir)/")

for d in "$projects/$main_slug" "$projects/$wt_slug"*; do
  [ -d "$d" ] || continue
  # Top-level transcripts only: subagents/, tool-results/ and workflows/ hold a session's children.
  find "$d" -maxdepth 1 -type f -name '*.jsonl' -mtime "-$days" 2> /dev/null
done | while IFS= read -r f; do
  printf '%s\t%s\n' "$(date -r "$f" +%s)" "$f"
done | sort -rn | while IFS="$(printf '\t')" read -r _ f; do
  printf 'session\t%s\t%s\t%s\t%s\n' "$(date -r "$f" +%Y-%m-%dT%H:%M)" "$(basename "$f" .jsonl)" "$(wc -c < "$f" | tr -d ' ')" "$f"
done

[ -n "$topic" ] || exit 0
hist="$HOME/.claude/history.jsonl"
[ -f "$hist" ] || exit 0
since=$(( ($(date +%s) - days * 86400) * 1000 ))
MAIN=$MAIN WT="$(wt_dir)/" TOPIC=$topic SINCE=$since LC_ALL=C awk '
  function field(k,   s) {
    if (!match($0, "\"" k "\":\"[^\"]*\"")) return ""
    s = substr($0, RSTART, RLENGTH); sub("^\"" k "\":\"", "", s); sub(/"$/, "", s); return s
  }
  {
    p = field("project")
    if (p != ENVIRON["MAIN"] && index(p, ENVIRON["WT"]) != 1) next
    if (!match($0, /"timestamp":[0-9]+/)) next
    ts = substr($0, RSTART + 12, RLENGTH - 12) + 0
    if (ts < ENVIRON["SINCE"] + 0) next
    d = field("display")
    if (index(tolower(d), tolower(ENVIRON["TOPIC"])) == 0) next
    printf "prompt\t%d\t%s\t%s\n", ts / 1000, field("sessionId"), substr(d, 1, 120)
  }' "$hist" | while IFS="$(printf '\t')" read -r kind ts sid text; do
  printf '%s\t%s\t%s\t%s\n' "$kind" "$(date -r "$ts" +%Y-%m-%dT%H:%M 2> /dev/null || date -d "@$ts" +%Y-%m-%dT%H:%M)" "$sid" "$text"
done
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `chmod +x scripts/recall-sessions && tests/run-bats tests/scripts/recall-sessions.bats && shellcheck scripts/recall-sessions`
Expected: `4 tests, 0 failures`; shellcheck prints nothing.

- [ ] **Step 5: Commit**

```bash
git add -- scripts/recall-sessions tests/scripts/recall-sessions.bats
git commit -m "M2: add recall-sessions" -m "recall grepped the global prompt index, which holds every project's prompts; filtering by the project field in code keeps recall inside the workspace it was asked about."
```

---

