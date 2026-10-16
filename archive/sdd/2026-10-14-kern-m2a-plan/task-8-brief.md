### Task 8: Ledger identity, briefs and task start

**Files:**
- Create: `scripts/ledger-open`, `scripts/task-brief`, `scripts/task-start`
- Test: `tests/scripts/ledger.bats`

**Interfaces:**
- Consumes: `kern-dir SUB` (M1); `kern_main_root` (M1).
- Produces:
  - `ledger-open PLAN [DIR]`: prints the ledger dir. DIR defaults to `WORK/ledgers/<slug>`, the plan file's basename lowercased with every run of other characters turned into `-`. Creates `DIR/ledger.md` with the lines `# kern ledger: <absolute plan path>` and `Main: <main root> branch=<name> status=<hash of git status --porcelain>`, and `briefs/`, `reports/`, `reviews/`, `logs/`. Exit 2 when the plan's frontmatter lacks `status: approved` or an `approved:` line with a date and double-quoted words, or when `DIR/ledger.md` names another plan (nothing is written then).
  - `ledger-open --summary DIR`: prints the ledger's `Decision:`, `parked:`, `Preflight:` and `Task N: minor (deferred):` lines in order, then `main: unchanged` (exit 0), or `main: changed; recorded <...>; now <...>` (exit 1).
  - `task-brief PLAN N LEDGER_DIR`: writes `LEDGER_DIR/briefs/task-N.md` holding a header line, the plan's `## Global Constraints` section and the task's section; prints that path; exit 0, 2 when the task is not found or on a usage error. Headings inside a fence are ignored.
  - `task-start LEDGER N TREE`: appends and prints `Task N: start tree=<id> at=<iso>`; exit 0, 2 when the ledger is missing or an argument is malformed.

- [ ] **Step 1: Write the failing tests**

```bash
#!/usr/bin/env bats
# tests/scripts/ledger.bats

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  PLAN="$TMP/plan.md"
  # One printf argument per line keeps the fixture's headings and fences out of column 0 of this plan,
  # so task extractors reading the plan itself are not confused.
  printf '%s\n' \
    '# Example plan' \
    '' \
    '## Global Constraints' \
    '' \
    '- Node 22.' \
    '' \
    '## Review Focus' \
    '' \
    '1. Empty input.' \
    '' \
    '### Task 1: First' \
    '' \
    'Do the first thing.' \
    '' \
    '```markdown' \
    '### Task 9: not a real task' \
    '```' \
    '' \
    'Still task 1.' \
    '' \
    '### Task 2: Second' \
    '' \
    'Do the second thing.' \
    '' \
    '## Self-review' \
    '' \
    'Not part of any task.' > "$PLAN"
  LEDGER_DIR="$TMP/ledger"
  mkdir -p "$LEDGER_DIR"
  LEDGER="$LEDGER_DIR/ledger.md"
  printf '# kern ledger: %s\n' "$PLAN" > "$LEDGER"
  TREE=$(printf '%040d' 0 | tr 0 a)
}

# approved_plan FILE [STATUS] [APPROVED]: a plan file with frontmatter.
approved_plan() {
  printf '%s\n' '---' "status: ${2-approved}" 'spec: none' "approved: ${3-2026-10-14, \"yes, go with delegate\"}" 'execution: delegate' 'commits: ask' '---' '' '### Task 1: One' > "$1"
}

@test "task-brief extracts one task plus the global constraints" {
  run bash "$KERN_ROOT/scripts/task-brief" "$PLAN" 2 "$LEDGER_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "$LEDGER_DIR/briefs/task-2.md" ]
  grep -q '^- Node 22\.$' "$output"
  grep -q '^### Task 2: Second$' "$output"
  [ "$(grep -c 'Task 1' "$output")" -eq 0 ]
  [ "$(grep -c 'Not part of any task' "$output")" -eq 0 ]
  [ "$(grep -c 'Empty input' "$output")" -eq 0 ]
}

@test "a Task heading inside a fence is ignored" {
  run bash "$KERN_ROOT/scripts/task-brief" "$PLAN" 1 "$LEDGER_DIR"
  [ "$status" -eq 0 ]
  grep -q '^Still task 1\.$' "$output"
  grep -q '^### Task 9: not a real task$' "$output"
  run bash "$KERN_ROOT/scripts/task-brief" "$PLAN" 9 "$LEDGER_DIR"
  [ "$status" -eq 2 ]
}

@test "a missing task exits 2 and writes nothing" {
  run bash "$KERN_ROOT/scripts/task-brief" "$PLAN" 3 "$LEDGER_DIR"
  [ "$status" -eq 2 ]
  [ ! -e "$LEDGER_DIR/briefs/task-3.md" ]
}

@test "task-start appends a start line" {
  run bash "$KERN_ROOT/scripts/task-start" "$LEDGER" 1 "$TREE"
  [ "$status" -eq 0 ]
  [[ "$output" == "Task 1: start tree=$TREE at="* ]] || false
  [ "$(tail -n 1 "$LEDGER")" = "$output" ]
}

@test "task-start refuses a missing ledger and a short tree id" {
  run bash "$KERN_ROOT/scripts/task-start" "$TMP/none.md" 1 "$TREE"
  [ "$status" -eq 2 ]
  run bash "$KERN_ROOT/scripts/task-start" "$LEDGER" 1 abc123
  [ "$status" -eq 2 ]
}

@test "ledger-open creates the ledger with its identity and the main checkout's state" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  approved_plan "$TMP/Big Plan.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/Big Plan.md"
  [ "$status" -eq 0 ]
  [ "$output" = "$REPO/.kern/ledgers/big-plan" ]
  [ "$(head -n 1 "$output/ledger.md")" = "# kern ledger: $TMP/Big Plan.md" ]
  grep -q "^Main: $REPO branch=main status=[0-9a-f]\{40\}$" "$output/ledger.md"
  for d in briefs reports reviews logs; do [ -d "$output/$d" ]; done
  [ -z "$(git status --porcelain)" ]
}

@test "ledger-open reuses its own ledger and refuses another plan's" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  approved_plan "$TMP/a.md"; approved_plan "$TMP/b.md"
  dir=$(bash "$KERN_ROOT/scripts/ledger-open" "$TMP/a.md" "$TMP/l" 2> /dev/null)
  printf 'Task 1: start tree=x\n' >> "$dir/ledger.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/a.md" "$TMP/l"
  [ "$status" -eq 0 ]
  grep -q '^Task 1: start' "$TMP/l/ledger.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/b.md" "$TMP/l"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"belongs to another plan ($TMP/a.md)"* ]] || false
}

@test "ledger-open refuses a plan that is not approved, or approved without the user's words" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  approved_plan "$TMP/d.md" draft
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/d.md" "$TMP/l"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"status: draft"* ]] || false
  approved_plan "$TMP/n.md" approved "2026-10-14"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/n.md" "$TMP/l"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"quoted words"* ]] || false
  [ ! -e "$TMP/l/ledger.md" ]
}

@test "ledger-open --summary lists decisions, parked and deferred lines and checks the main checkout" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  approved_plan "$TMP/a.md"
  dir=$(bash "$KERN_ROOT/scripts/ledger-open" "$TMP/a.md" "$TMP/l" 2> /dev/null)
  printf '%s\n' 'Decision: one; why: x; cost if wrong: y' 'Task 1: review round=1 tree=t spec=compliant quality=approved' \
    'Task 1: minor (deferred): rename a helper' 'parked: q; default: d; why: w' >> "$dir/ledger.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" --summary "$dir"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'Decision: one; why: x; cost if wrong: y' ]
  [ "${lines[1]}" = 'Task 1: minor (deferred): rename a helper' ]
  [ "${lines[2]}" = 'parked: q; default: d; why: w' ]
  [ "${lines[3]}" = 'main: unchanged' ]
  printf 'x\n' > "$REPO/stray.txt"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" --summary "$dir"
  [ "$status" -eq 1 ]
  [[ "${lines[3]}" == 'main: changed; '* ]] || false
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run-bats tests/scripts/ledger.bats`
Expected: every test fails with `No such file or directory` for the scripts.

- [ ] **Step 3: Write `scripts/ledger-open`**

```bash
#!/usr/bin/env bash
# Open the execute-plan ledger for an approved plan, or check a ledger at the end of a run.
# Usage: ledger-open PLAN [DIR]    Prints the ledger dir. DIR defaults to WORK/ledgers/<plan slug>.
#        ledger-open --summary DIR Prints the Decision, parked, deferred-minor and Preflight lines, then
#                                  whether the main checkout's branch and status are as recorded.
# Exit 2: the plan is not approved (status: approved and an approved: line with a date and the user's
# quoted words), or DIR holds another plan's ledger. --summary exits 1 when the main checkout changed.
# Ledger identity adapted from superpowers subagent-driven-development/scripts/sdd-workspace (MIT).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
# shellcheck source=/dev/null
. "$here/../hooks/lib/settings.sh"

# main_state: "<main root> branch=<name> status=<hash of git status --porcelain>".
main_state() {
  local m b
  m=$(kern_main_root "$PWD") || { echo "ledger-open: not a git repository" >&2; exit 2; }
  b=$(git -C "$m" symbolic-ref -q --short HEAD 2> /dev/null) || b='(detached)'
  printf '%s branch=%s status=%s\n' "$m" "$b" \
    "$(git --no-optional-locks -C "$m" status --porcelain | git hash-object --stdin)"
}

if [ "${1-}" = --summary ]; then
  [ $# -eq 2 ] && [ -f "$2/ledger.md" ] || { echo "usage: ledger-open --summary DIR (DIR holds ledger.md)" >&2; exit 2; }
  grep -E '^(Decision:|parked:|Preflight:|Task [0-9]+: minor \(deferred\):)' "$2/ledger.md" || true
  rec=$(sed -n 's/^Main: //p' "$2/ledger.md" | head -n 1)
  now=$(main_state)
  if [ "$rec" = "$now" ]; then
    echo "main: unchanged"
    exit 0
  fi
  echo "main: changed; recorded $rec; now $now"
  exit 1
fi

[ $# -ge 1 ] && [ $# -le 2 ] || { echo "usage: ledger-open PLAN [DIR] | ledger-open --summary DIR" >&2; exit 2; }
plan=$1
[ -f "$plan" ] || { echo "ledger-open: no such plan: $plan" >&2; exit 2; }
plan=$(cd "$(dirname "$plan")" && pwd -P)/$(basename "$plan")
# The frontmatter is the block between a first line of --- and the next ---.
fm=$(awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } NR > 1 { print }' "$plan")
status=$(printf '%s\n' "$fm" | sed -n 's/^status:[[:space:]]*//p' | head -n 1)
approved=$(printf '%s\n' "$fm" | sed -n 's/^approved:[[:space:]]*//p' | head -n 1)
[ "$status" = approved ] || { echo "ledger-open: $plan has status: ${status:-none}; execute-plan runs only an approved plan" >&2; exit 2; }
printf '%s' "$approved" | grep -Eq '[0-9]{4}-[0-9]{2}-[0-9]{2}.*"[^"]+"' ||
  { echo "ledger-open: $plan has no approved: line with a date and the user's quoted words" >&2; exit 2; }

if [ $# -eq 2 ]; then
  dir=$2
else
  slug=$(basename "$plan" .md | tr '[:upper:]' '[:lower:]' | LC_ALL=C sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//')
  [ -n "$slug" ] || { echo "ledger-open: cannot make a ledger name from $plan" >&2; exit 2; }
  dir=$(bash "$here/kern-dir" "ledgers/$slug")
fi
mkdir -p "$dir/briefs" "$dir/reports" "$dir/reviews" "$dir/logs"
ledger="$dir/ledger.md"
if [ -f "$ledger" ]; then
  head=$(head -n 1 "$ledger")
  if [ "$head" != "# kern ledger: $plan" ]; then
    echo "ledger-open: $ledger belongs to another plan (${head#\# kern ledger: }); leave it and pass another DIR" >&2
    exit 2
  fi
else
  printf '# kern ledger: %s\nMain: %s\n' "$plan" "$(main_state)" > "$ledger"
fi
printf '%s\n' "$dir"
```

- [ ] **Step 4: Write `scripts/task-brief`**

```bash
#!/usr/bin/env bash
# Extract one task, plus the plan's Global Constraints, into LEDGER_DIR/briefs/task-N.md.
# Usage: task-brief PLAN N LEDGER_DIR    Prints the brief path. Exit 2 when the task is not found.
# Adapted from superpowers subagent-driven-development/scripts/task-brief (MIT).
set -euo pipefail
[ $# -eq 3 ] || { echo "usage: task-brief PLAN N LEDGER_DIR" >&2; exit 2; }
plan=$1 n=$2 ledger_dir=$3
[ -f "$plan" ] || { echo "task-brief: no such plan: $plan" >&2; exit 2; }
case "$n" in ''|*[!0-9]*) echo "task-brief: N must be a number: $n" >&2; exit 2 ;; esac

task=$(awk -v n="$n" '
  /^[`][`][`]|^~~~/ { fence = !fence; if (intask) print; next }
  fence { if (intask) print; next }
  /^#+[ \t]/ {
    match($0, /^#+/); lvl = RLENGTH
    if ($0 ~ /^#+[ \t]+Task[ \t]+[0-9]+/) {
      intask = ($0 ~ ("^#+[ \t]+Task[ \t]+" n "([^0-9]|$)")); tlvl = lvl
    } else if (intask && lvl <= tlvl) {
      intask = 0
    }
  }
  intask { print }
' "$plan")
[ -n "$task" ] || { echo "task-brief: no heading 'Task $n' in $plan" >&2; exit 2; }

constraints=$(awk '
  /^[`][`][`]|^~~~/ { fence = !fence }
  !fence && /^## / { gc = ($0 ~ /^## Global Constraints/) }
  gc { print }
' "$plan")

mkdir -p "$ledger_dir/briefs"
out="$ledger_dir/briefs/task-$n.md"
plan_abs=$(cd "$(dirname "$plan")" && pwd -P)/$(basename "$plan")
{
  printf '# Brief: Task %s\n\nPlan: %s\n\n' "$n" "$plan_abs"
  if [ -n "$constraints" ]; then printf '%s\n\n' "$constraints"; fi
  printf '%s\n' "$task"
} > "$out"
printf '%s\n' "$out"
```

- [ ] **Step 5: Write `scripts/task-start`**

```bash
#!/usr/bin/env bash
# Record the start of a task in an execute-plan ledger.
# Usage: task-start LEDGER N TREE    Appends and prints: Task N: start tree=<id> at=<iso>
set -euo pipefail
[ $# -eq 3 ] || { echo "usage: task-start LEDGER N TREE" >&2; exit 2; }
ledger=$1 n=$2 tree=$3
[ -f "$ledger" ] || { echo "task-start: no ledger at $ledger; write its header line first" >&2; exit 2; }
case "$n" in ''|*[!0-9]*) echo "task-start: N must be a number: $n" >&2; exit 2 ;; esac
printf '%s' "$tree" | grep -Eq '^[0-9a-f]{40}([0-9a-f]{24})?$' ||
  { echo "task-start: TREE must be a full object id: $tree" >&2; exit 2; }
line="Task $n: start tree=$tree at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf '%s\n' "$line" >> "$ledger"
printf '%s\n' "$line"
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `chmod +x scripts/ledger-open scripts/task-brief scripts/task-start && tests/run-bats tests/scripts/ledger.bats && shellcheck scripts/ledger-open scripts/task-brief scripts/task-start`
Expected: `9 tests, 0 failures`; shellcheck prints nothing.

- [ ] **Step 7: Commit**

```bash
git add -- scripts/ledger-open scripts/task-brief scripts/task-start tests/scripts/ledger.bats
git commit -m "M2: add ledger-open, task-brief and task-start" -m "A ledger opens only for an approved plan and only for its own plan, so a stale ledger is never read as progress; the main checkout's state is recorded for the final check."
```

---

