#!/usr/bin/env bats
# tests/scripts/ledger.bats

bats_require_minimum_version 1.5.0
load ../helpers/wt
load ../helpers/common

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
  [ "$(sed -n 2p "$output/ledger.md")" = "Plan: $(git hash-object --no-filters -- "$TMP/Big Plan.md")" ]
  [ "$(sed -n 3p "$output/ledger.md")" = "Main: $REPO branch=main head=$(git rev-parse HEAD) status=$(git hash-object --stdin < /dev/null)" ]
  [ "$(wc -l < "$output/ledger.md")" -eq 3 ]
  for d in briefs reports reviews logs; do [ -d "$output/$d" ]; done
  [ -z "$(git status --porcelain)" ]
}

# Audit C-I5: a plan updated in place and approved again met its old ledger, whose complete lines then
# skipped changed or renumbered tasks.
@test "ledger-open refuses a ledger opened for the plan before it changed, and writes nothing" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  approved_plan "$TMP/a.md"
  dir=$(bash "$KERN_ROOT/scripts/ledger-open" "$TMP/a.md" "$TMP/l" 2> /dev/null)
  printf 'Task 1: complete tree=x\n' >> "$dir/ledger.md"
  before=$(cat "$dir/ledger.md")
  printf '%s\n' '' '### Task 2: Two' >> "$TMP/a.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/a.md" "$TMP/l"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [ "${stderr_lines[0]}" = "ledger-open: $TMP/l/ledger.md: the plan changed since this ledger opened; pass another DIR" ]
  # Review of P7, Important 2: execute-plan passes no DIR, so the refusal names a free one and the command.
  [ "${stderr_lines[1]}" = "ledger-open: rerun as: bash $KERN_ROOT/scripts/ledger-open $TMP/a.md $TMP/l-2" ]
  [ "${stderr_lines[2]}" = "ledger-open: that ledger starts empty: the completed tasks and the worktree of $TMP/l/ledger.md are not carried over, and stay where they are" ]
  [ "${#stderr_lines[@]}" -eq 3 ]
  [ "$(cat "$dir/ledger.md")" = "$before" ]
  [ ! -e "$TMP/l-2" ]
  rerun=${stderr_lines[1]#ledger-open: rerun as: }
  run --separate-stderr eval "$rerun"
  [ "$status" -eq 0 ]
  [ "$output" = "$TMP/l-2" ]
  [ "$(sed -n 2p "$TMP/l-2/ledger.md")" = "Plan: $(git hash-object --no-filters -- "$TMP/a.md")" ]
  [ "$(wc -l < "$TMP/l-2/ledger.md")" -eq 3 ]
}

@test "a refusal names the first DIR-<n> that holds no ledger dir and no worktree of that name" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  approved_plan "$TMP/a.md"; approved_plan "$TMP/b.md"
  bash "$KERN_ROOT/scripts/ledger-open" "$TMP/a.md" "$TMP/l" > /dev/null 2>&1
  mkdir -p "$TMP/l-2" .claude/worktrees/l-3
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/b.md" "$TMP/l/"
  [ "$status" -eq 2 ]
  [[ "${stderr_lines[0]}" == *"belongs to another plan ($TMP/a.md)"* ]] || false
  [ "${stderr_lines[1]}" = "ledger-open: rerun as: bash $KERN_ROOT/scripts/ledger-open $TMP/b.md $TMP/l-4" ]
  [[ "${stderr_lines[2]}" == *"the completed tasks and the worktree of $TMP/l/"*"ledger.md are not carried over"* ]] || false
  printf '%s\n' '' '### Task 2: Two' >> "$TMP/a.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/a.md" "$TMP/l"
  [ "$status" -eq 2 ]
  [ "${stderr_lines[1]}" = "ledger-open: rerun as: bash $KERN_ROOT/scripts/ledger-open $TMP/a.md $TMP/l-4" ]
}

@test "the rerun command quotes a plan path with a space" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  approved_plan "$TMP/Big Plan.md"
  bash "$KERN_ROOT/scripts/ledger-open" "$TMP/Big Plan.md" "$TMP/l" > /dev/null 2>&1
  printf '%s\n' '' '### Task 2: Two' >> "$TMP/Big Plan.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/Big Plan.md" "$TMP/l"
  [ "$status" -eq 2 ]
  rerun=${stderr_lines[1]#ledger-open: rerun as: }
  run --separate-stderr eval "$rerun"
  [ "$status" -eq 0 ]
  [ "$(head -n 1 "$TMP/l-2/ledger.md")" = "# kern ledger: $TMP/Big Plan.md" ]
}

@test "ledger-open refuses a ledger with no Plan: line, which cannot show the plan is unchanged" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  approved_plan "$TMP/a.md"
  mkdir -p "$TMP/old"
  printf '# kern ledger: %s\nMain: %s branch=main status=x\n' "$TMP/a.md" "$REPO" > "$TMP/old/ledger.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/a.md" "$TMP/old"
  [ "$status" -eq 2 ]
  [[ "${stderr_lines[0]}" == *"$TMP/old/ledger.md has no Plan: line"*"pass another DIR"* ]] || false
  [ "${stderr_lines[1]}" = "ledger-open: rerun as: bash $KERN_ROOT/scripts/ledger-open $TMP/a.md $TMP/old-2" ]
  [ "$(ls -A "$TMP/old")" = ledger.md ]
}

@test "the recorded plan hash follows a symlinked plan's content" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  approved_plan "$TMP/real.md"
  ln -s real.md "$TMP/link.md"
  dir=$(bash "$KERN_ROOT/scripts/ledger-open" "$TMP/link.md" "$TMP/l" 2> /dev/null)
  [ "$(sed -n 2p "$dir/ledger.md")" = "Plan: $(git hash-object --no-filters -- "$TMP/real.md")" ]
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/link.md" "$TMP/l"
  [ "$status" -eq 0 ]
}

# Audit C-M2: Main: held no HEAD, so a commit on the main checkout during the run read main: unchanged.
@test "a commit on the main checkout reads main: changed" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  approved_plan "$TMP/a.md"
  dir=$(bash "$KERN_ROOT/scripts/ledger-open" "$TMP/a.md" "$TMP/l" 2> /dev/null)
  git commit --quiet --allow-empty -m second
  [ -z "$(git status --porcelain)" ]
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" --summary "$dir"
  [ "$status" -eq 1 ]
  [[ "${lines[0]}" == "main: changed; recorded $REPO branch=main head="*"; now $REPO branch=main head=$(git rev-parse HEAD) status="* ]] || false
}

# Audit C-M3: wt-new adds worktree.dir to info/exclude after Main: was recorded, so in a repo whose
# worktree dir already held untracked worktrees the run ended with a false main: changed.
@test "an untracked worktree dir gives no false main: changed once wt-new excludes it" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  mkdir -p .claude/worktrees/agent-x
  printf 'f\n' > .claude/worktrees/agent-x/f
  [ "$(git status --porcelain)" = '?? .claude/' ]
  approved_plan "$TMP/a.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/a.md" "$TMP/l"
  [ "$status" -eq 0 ]
  [ -z "$(git status --porcelain)" ]
  grep -qxF '/.claude/worktrees/' .git/info/exclude
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-new" p --base main
  [ "$status" -eq 0 ]
  [ "$output" = "$REPO/.claude/worktrees/p" ]
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" --summary "$TMP/l"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = 'main: unchanged' ]
}

@test "ledger-open leaves info/exclude alone when the worktree dir is absent or the plan is refused" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  approved_plan "$TMP/a.md"
  before=$(cat .git/info/exclude 2> /dev/null || true)
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/a.md" "$TMP/l"
  [ "$status" -eq 0 ]
  [ "$(cat .git/info/exclude 2> /dev/null || true)" = "$before" ]
  mkdir -p .claude/worktrees/agent-x
  printf 'f\n' > .claude/worktrees/agent-x/f
  approved_plan "$TMP/d.md" draft
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/d.md" "$TMP/fresh"
  [ "$status" -eq 2 ]
  [ "$(cat .git/info/exclude 2> /dev/null || true)" = "$before" ]
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

@test "ledger-open and plan-check take a go approval" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  printf '%s\n' '---' 'form: short' 'status: approved' 'issue: MA-254' 'approved: 2026-10-31, "/kern:autopilot go MA-254"' '---' '' \
    '## Problem' '' '## Constraints' '' '## Acceptance criteria' '' '1. Works.' '' '## Test seams' > "$TMP/spec.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/plan-check" "$TMP/spec.md"
  [ "$status" -eq 0 ] || { echo "plan-check spec: $output $stderr"; false; }
  printf '%s\n' '---' 'status: approved' 'spec: spec.md' 'issue: MA-254' 'approved: 2026-10-31, "/kern:autopilot go MA-254"' \
    'execution: delegate' 'commits: ask' '---' '' '## Global Constraints' '' '- Bash 3.2.' '' '## Review Focus' '' '1. Focus.' '' \
    '## File map' '' '### Task 1: One' '' '**Files:**' '- Create: `src/one.js`' '' '**Interfaces:**' '- Consumes: none' \
    '- Produces: none' '' '**Blocked by:** none' '' '**Acceptance:** 1' '' '- [ ] Step 1: Run: `node --test`. Expected: one failure.' \
    > "$TMP/go.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/plan-check" "$TMP/go.md"
  [ "$status" -eq 0 ] || { echo "plan-check: $output $stderr"; false; }
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/go.md" "$TMP/l"
  [ "$status" -eq 0 ] || { echo "ledger-open: $output $stderr"; false; }
  [ -f "$TMP/l/ledger.md" ]
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

@test "ledger-open refuses an unclosed frontmatter and writes nothing" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  printf '%s\n' '---' 'status: approved' 'approved: 2026-10-14, "x"' '' '### Task 1: One' > "$TMP/u.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/u.md" "$TMP/fresh"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"$TMP/u.md: frontmatter not closed"* ]] || false
  [ ! -e "$TMP/fresh" ]
}

@test "ledger-open refuses a plan or a spec: line that is not a Markdown name, and writes nothing" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  # G20 guards Markdown files only, so a plan.txt can carry an approval nobody gave.
  approved_plan "$TMP/plan.txt" approved '2026-10-14, "ship it"'
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/plan.txt" "$TMP/fresh"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"$TMP/plan.txt is not a Markdown file"* ]] || false
  [ ! -e "$TMP/fresh" ]
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/plan.txt"
  [ "$status" -eq 2 ]
  [ ! -e "$REPO/.kern/ledgers/plan" ]
  ln -s plan.txt "$TMP/link.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/link.md" "$TMP/fresh"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"plan.txt is not a Markdown file"* ]] || false
  [ ! -e "$TMP/fresh" ]
  printf '%s\n' '---' 'status: approved' 'spec: WORK/specs/export.txt' 'approved: 2026-10-14, "yes"' 'execution: delegate' \
    'commits: ask' '---' > "$TMP/s.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/s.md" "$TMP/fresh"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"spec: WORK/specs/export.txt is not a Markdown file"* ]] || false
  [ ! -e "$TMP/fresh" ]
}

@test "ledger-open takes a Markdown name in any case, and spec: none" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  approved_plan "$TMP/Upper.MD"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/Upper.MD"
  [ "$status" -eq 0 ]
  [ "$output" = "$REPO/.kern/ledgers/upper" ]
  printf '%s\n' '---' 'status: approved' 'spec: WORK/specs/export.Markdown' 'approved: 2026-10-14, "yes"' \
    'execution: delegate' 'commits: ask' '---' > "$TMP/s.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/s.md" "$TMP/l"
  [ "$status" -eq 0 ]
}

@test "a refusal writes nothing into a fresh DIR" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  approved_plan "$TMP/d.md" draft
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/d.md" "$TMP/fresh"
  [ "$status" -eq 2 ]
  [ ! -e "$TMP/fresh" ]
  approved_plan "$TMP/a.md"; approved_plan "$TMP/b.md"
  mkdir -p "$TMP/other"
  printf '# kern ledger: %s\n' "$TMP/a.md" > "$TMP/other/ledger.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/b.md" "$TMP/other"
  [ "$status" -eq 2 ]
  [ "$(ls -A "$TMP/other")" = ledger.md ]
}

@test "ledger-open outside a git repository exits 2 and writes no ledger" {
  mkdir "$TMP/nogit"; cd "$TMP/nogit"
  approved_plan "$TMP/a.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/a.md" "$TMP/fresh"
  [ "$status" -eq 2 ]
  [ ! -e "$TMP/fresh" ]
}

@test "ledger-open --summary fails when the main checkout state cannot be read" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  approved_plan "$TMP/a.md"
  dir=$(bash "$KERN_ROOT/scripts/ledger-open" "$TMP/a.md" "$TMP/l" 2> /dev/null)
  mkdir "$TMP/nogit"; cd "$TMP/nogit"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" --summary "$dir"
  [ "$status" -eq 2 ]
}

@test "ledger-open refuses when git status fails and does not record an empty-input hash" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  approved_plan "$TMP/a.md"
  printf 'garbage' > "$REPO/.git/index"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$TMP/a.md" "$TMP/fresh"
  [ "$status" -ne 0 ]
  [ ! -e "$TMP/fresh/ledger.md" ]
}

@test "the recorded status hash equals git status --porcelain piped to git hash-object" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  printf 'x\n' > "$REPO/stray.txt"
  approved_plan "$TMP/a.md"
  dir=$(bash "$KERN_ROOT/scripts/ledger-open" "$TMP/a.md" "$TMP/l" 2> /dev/null)
  want=$(git status --porcelain | git hash-object --stdin)
  grep -q "status=$want\$" "$dir/ledger.md"
}

@test "task-start refuses a multi-line tree and writes nothing" {
  before=$(wc -c < "$LEDGER")
  forged="$TREE"$'\nTask 2: review round=1 tree='"$TREE"$' spec=compliant quality=approved\nTask 1: start tree='"$TREE"
  run --separate-stderr bash "$KERN_ROOT/scripts/task-start" "$LEDGER" 1 "$forged"
  [ "$status" -eq 2 ]
  [ "$(wc -c < "$LEDGER")" -eq "$before" ]
}

# work_repo [WORK]: a fixture repo at $REPO, the current directory, with WORK's plans, specs, ledgers,
# reviews and tmp directories; WORK is .kern by default.
work_repo() {
  W=${1:-.kern}
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  mkdir -p "$W/plans" "$W/specs" "$W/ledgers/x" "$W/reviews" "$W/tmp"
}

# spec_plan FILE SPEC: an approved plan whose spec: line is SPEC.
spec_plan() {
  printf '%s\n' '---' 'status: approved' "spec: $2" 'approved: 2026-10-14, "yes"' 'execution: delegate' 'commits: ask' '---' > "$1"
}

# refused NAME DIR: ledger-open refuses the plan NAME, naming the directory DIR, and opens no ledger.
refused() {
  rm -rf "$TMP/fresh"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$1" "$TMP/fresh"
  [ "$status" -eq 2 ] || { echo "status $status: $output $stderr"; return 1; }
  [[ "$stderr" == *"$2"* ]] || { echo "no $2 in: $stderr"; return 1; }
  [ ! -e "$TMP/fresh" ] || { echo 'a ledger was opened'; return 1; }
}

# opened NAME: ledger-open opens a ledger for the plan NAME.
opened() {
  rm -rf "$TMP/fresh"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" "$1" "$TMP/fresh"
  [ "$status" -eq 0 ] || { echo "status $status: $output $stderr"; return 1; }
}

@test "ledger-open refuses a plan under WORK/tmp, WORK/reviews or WORK/ledgers, naming the directory" {
  work_repo
  for d in tmp reviews ledgers/x; do
    approved_plan ".kern/$d/p.md"
    refused ".kern/$d/p.md" "$REPO/.kern/${d%/x}"
  done
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" .kern/tmp/p.md
  [ "$status" -eq 2 ]
  [ ! -e .kern/ledgers/p ]
}

@test "ledger-open refuses a plan whose spec: is under a working directory" {
  work_repo
  mkdir -p docs
  for s in .kern/reviews/s.md WORK/reviews/s.md WORK/tmp/s.md WORK/ledgers/x/s.md ../reviews/s.md "$REPO/.kern/tmp/s.md" \
    WORK/specs/../tmp/s.md .kern/reviews/gone/s.md; do
    spec_plan .kern/plans/p.md "$s"
    refused .kern/plans/p.md "$REPO/.kern/"
    [[ "$stderr" == *"spec: $s"* ]] || { echo "$s: $stderr"; return 1; }
  done
}

@test "ledger-open takes a plan and spec in their own directories" {
  work_repo
  mkdir -p docs/specs docs/tmp
  for s in WORK/specs/s.md .kern/specs/s.md docs/specs/s.md ../specs/s.md docs/tmp/s.md; do
    spec_plan .kern/plans/p.md "$s"
    opened .kern/plans/p.md
  done
}

@test "ledger-open refuses a symlink under WORK/tmp that points out" {
  work_repo
  approved_plan .kern/plans/p.md
  ln -s ../plans/p.md .kern/tmp/link.md
  refused .kern/tmp/link.md "$REPO/.kern/tmp"
  approved_plan "$TMP/out.md"
  ln -s "$TMP/out.md" .kern/tmp/out.md
  refused .kern/tmp/out.md "$REPO/.kern/tmp"
}

@test "ledger-open refuses a plan outside that points in" {
  work_repo
  approved_plan .kern/tmp/p.md
  ln -s ../tmp/p.md .kern/plans/link.md
  refused .kern/plans/link.md "$REPO/.kern/tmp"
  ln -s "$REPO/.kern/tmp/p.md" "$TMP/out.md"
  refused "$TMP/out.md" "$REPO/.kern/tmp"
  ln -s ../tmp .kern/plans/dir
  refused .kern/plans/dir/p.md "$REPO/.kern/tmp"
  ln -s plans/link.md .kern/two.md
  refused .kern/two.md "$REPO/.kern/tmp"
}

@test "ledger-open refuses a spec: that points in" {
  work_repo
  printf '# s\n' > .kern/tmp/s.md
  ln -s ../tmp/s.md .kern/specs/link.md
  spec_plan .kern/plans/p.md WORK/specs/link.md
  refused .kern/plans/p.md "$REPO/.kern/tmp"
}

@test "ledger-open reads .. in the path as the file system does" {
  work_repo
  approved_plan .kern/tmp/p.md
  refused .kern/plans/../tmp/p.md "$REPO/.kern/tmp"
  approved_plan .kern/plans/q.md
  opened .kern/tmp/../plans/q.md
  # .. after a symlink leaves the directory the symlink reaches, not the one that holds the symlink.
  mkdir .kern/tmp/sub
  ln -s ../tmp/sub .kern/plans/dir
  refused .kern/plans/dir/../p.md "$REPO/.kern/tmp"
}

@test "ledger-open refuses a plan past 8 symlinks" {
  work_repo
  approved_plan .kern/plans/p.md
  prev=p.md
  for i in 1 2 3 4 5 6 7 8; do
    ln -s "$prev" ".kern/plans/l$i.md"
    prev=l$i.md
  done
  opened .kern/plans/l8.md
  ln -s l8.md .kern/plans/l9.md
  refused .kern/plans/l9.md 'more than 8 symlinks'
}

@test "ledger-open reads the working directories from work_dir" {
  work_repo .work
  mkdir -p .claude .kern/tmp
  printf 'work_dir: .work\n' > .claude/kern.local.yml
  approved_plan .work/tmp/p.md
  refused .work/tmp/p.md "$REPO/.work/tmp"
  approved_plan .kern/tmp/p.md
  opened .kern/tmp/p.md
  spec_plan .kern/tmp/s.md WORK/reviews/s.md
  refused .kern/tmp/s.md "$REPO/.work/reviews"
}

@test "ledger-open exits 2 when a settings file that could set work_dir cannot be read" {
  work_repo
  mkdir -p .claude
  printf 'work_dir: .work\n' > .claude/kern.local.yml
  approved_plan .kern/plans/p.md
  read_fails awk "$REPO/.claude/kern.local.yml"
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" .kern/plans/p.md "$TMP/fresh"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *'ledger-open: work_dir is unknown: '*'kern.local.yml could not be read'* ]] || false
  [ ! -e "$TMP/fresh" ]
}

@test "ledger-open reads a work dir that is a symlink where it lands" {
  REPO="$TMP/repo"; make_fixture "$REPO"; cd "$REPO"
  mkdir -p "$TMP/real/tmp"
  ln -s "$TMP/real" .kern
  approved_plan .kern/tmp/p.md
  refused .kern/tmp/p.md "$TMP/real/tmp"
}

@test "ledger-open refuses a plan under the working directories of the repository that holds it" {
  work_repo
  approved_plan .kern/tmp/p.md
  make_fixture "$TMP/other"
  cd "$TMP/other"
  refused "$REPO/.kern/tmp/p.md" "$REPO/.kern/tmp"
}

@test "ledger-open takes a linked worktree's own .kern/tmp, which is not WORK" {
  work_repo
  git worktree add -q -b t "$TMP/wt" 2> /dev/null
  mkdir -p "$TMP/wt/.kern/tmp"
  approved_plan "$TMP/wt/.kern/tmp/p.md"
  cd "$TMP/wt"
  opened .kern/tmp/p.md
  approved_plan "$REPO/.kern/tmp/p.md"
  refused "$REPO/.kern/tmp/p.md" "$REPO/.kern/tmp"
}

@test "ledger-open reads a directory named in another case as the file system does" {
  work_repo
  [ -d .kern/TMP ] || skip 'the file system tells case apart'
  approved_plan .kern/tmp/p.md
  refused .kern/TMP/p.md "$REPO/.kern/tmp"
}

@test "a name beside a working directory opens" {
  work_repo
  mkdir -p .kern/tmp2 .kern/plans/tmp
  for f in .kern/tmp2/p.md .kern/plans/tmp/p.md .kern/tmp.md; do
    approved_plan "$f"
    opened "$f"
  done
}
