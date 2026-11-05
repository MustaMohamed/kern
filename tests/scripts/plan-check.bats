#!/usr/bin/env bats
# tests/scripts/plan-check.bats
# Fixture plans are written one printf argument per line, so their headings stay out of column 0 of
# the kern plan that carries this file and task extractors reading that plan are not confused.

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  cd "$REPO"
  printf '%s\n' '---' 'status: approved' 'date: 2026-10-14' 'approved: 2026-10-14, "yes"' '---' '' \
    '## Acceptance criteria' '' '1. Parses a line.' '2. Stores it.' '3. Documents it.' > spec.md
  task() { # task N TITLE FILE CONSUMES PRODUCES BLOCKED ACCEPT
    printf '%s\n' "### Task $1: $2" '' '**Files:**' "- Create: \`$3\`" '' '**Interfaces:**' "- Consumes: $4" "- Produces: $5" '' \
      "**Blocked by:** $6" '' "**Acceptance:** $7" '' "- [ ] Step 1: Run: \`node --test\`. Expected: one failure." ''
  }
  {
    printf '%s\n' '---' 'status: approved' 'spec: spec.md' 'approved: 2026-10-14, "yes, delegate"' 'execution: delegate' 'commits: ask' '---' '' \
      '## Global Constraints' '' '- Node 22.' '' '## Review Focus' '' '1. Empty input; pinned in Task 1.' '' '## File map' '' '| Path | Task | Responsibility |' '|---|---|---|' ''
    task 1 Parser 'src/parse.js:1-20' none '`parse(text)`' none 1
    task 2 'Migration A' db/migrations/001_a.sql '`parse(text)`' '`table-a`' 'Task 1' 2
    task 3 'Migration B' db/migrations/002_b.sql none '`table-b`' 'Task 2' 2
    task 4 Docs docs/parse.md none '`docs`' none 3
  } > plan.md
}

pc() { run --separate-stderr bash "$KERN_ROOT/scripts/plan-check" "$@"; }
says() { printf '%s\n' "$output" | grep -qF -- "$1" || { echo "missing: $1"; echo "$output"; false; }; }

@test "a sound plan passes" {
  pc plan.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "--graph prints the overlap and the waves" {
  pc --graph plan.md
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = $'overlap\t2\t3\tmigrations' ]
  [ "${lines[1]}" = $'wave\t1\t1 4' ]
  [ "${lines[2]}" = $'wave\t2\t2' ]
  [ "${lines[3]}" = $'wave\t3\t3' ]
}

@test "--files prints a task's paths without line ranges" {
  pc --files plan.md 1
  [ "$status" -eq 0 ]
  [ "$output" = "src/parse.js" ]
}

@test "--files prints a trailing /** or /* as its directory" {
  sed -i.bak 's#^- Create: `docs/parse.md`$#- Create: `docs/**`, `tests/parse/*`#' plan.md
  pc --files plan.md 4
  [ "$status" -eq 0 ]
  [ "$output" = $'docs/\ntests/parse/' ]
}

@test "two tasks on one shared service must be ordered" {
  sed -i.bak 's/^\*\*Blocked by:\*\* Task 2$/**Blocked by:** none/' plan.md
  pc plan.md
  [ "$status" -eq 1 ]
  says "Task 2 and Task 3 share migrations, but Task 3 is not blocked by Task 2"
}

@test "a shared_services entry orders tasks that both mention it" {
  mkdir -p .claude
  printf 'shared_services: redis\n' > .claude/kern.local.yml
  sed -i.bak 's/^Docs$/Docs/; s#^- Create: `docs/parse.md`#- Create: `docs/parse.md` (flush redis)#; s#^- Create: `src/parse.js:1-20`#- Create: `src/parse.js:1-20` (redis cache)#' plan.md
  pc plan.md
  [ "$status" -eq 1 ]
  says "Task 1 and Task 4 share redis, but Task 4 is not blocked by Task 1"
}

@test "a consumer must be blocked by its producer, and cannot come first" {
  sed -i.bak 's/^\*\*Blocked by:\*\* Task 1$/**Blocked by:** none/' plan.md
  pc plan.md
  says "Task 2 consumes \`parse\` from Task 1 but is not blocked by it"
  awk 'f == 0 && $0 == "- Consumes: none" { print "- Consumes: `table-b`"; f = 1; next } { print }' plan.md.bak > plan.md
  pc plan.md
  says "Task 1 consumes \`table-b\` before Task 3 produces it"
}

@test "a task blocked by a later task, a gap in numbering and a missing Run/Expected pair are errors" {
  sed -i.bak 's/^\*\*Blocked by:\*\* none$/**Blocked by:** Task 4/; s/^### Task 4: Docs$/### Task 5: Docs/' plan.md
  pc plan.md
  [ "$status" -eq 1 ]
  says "Task 1 is blocked by Task 4, which is not an earlier task"
  says "Task 5 is out of sequence; expected Task 4"
  printf '%s\n' '### Task 6: Bare' '' '**Files:**' '- Create: `x.txt`' > bare.md
  cat plan.md bare.md > plan2.md
  pc plan2.md
  says "Task 6: no Run: and Expected: pair"
  says "Task 6: no Blocked by line"
}

@test "an acceptance criterion no task covers is an error" {
  sed -i.bak 's/^\*\*Acceptance:\*\* 3$/**Acceptance:** 1/' plan.md
  pc plan.md
  says "acceptance criterion 3 of the spec is covered by no task"
}

@test "placeholders, an unapproved approval and a missing spec are errors" {
  sed -i.bak 's/^- Node 22\.$/- Node 22. TBD/; s/^approved: .*$/approved: yes/; s/^spec: spec.md$/spec: gone.md/' plan.md
  pc plan.md
  says "placeholder: - Node 22. TBD"
  says "status: approved needs approved: with the date and the user's quoted words"
  says "spec gone.md not found"
}

@test "a spec needs its sections and an approval with the user's words" {
  printf '%s\n' '---' 'status: approved' 'approved: 2026-10-14' '---' '## Problem' '## Acceptance criteria' '1. a' > s.md
  pc s.md
  [ "$status" -eq 1 ]
  says "missing section ## Constraints"
  says "status: approved needs approved: with the date and the user's quoted words"
  printf '%s\n' '---' 'status: draft' 'form: short' '---' '## Problem' '## Constraints' '- Always: x' '## Acceptance criteria' '1. a' '## Test seams' > short.md
  pc short.md
  [ "$status" -eq 0 ]
}

# M2b bfix2 S2 (bfix2-lane-A, Fix 3): in all 7 workflow-define-spec runs since 2026-10-20 that skipped define step 11's
# review, plan-check was the run's last tool call before it stopped; in all 8 that ran it, plan-check ran before the
# Agent call and again after the review's fixes. So a clean draft full-form spec gets the next step in that result.
NEXT="next: define step 11's spec review (one fresh reviewer subagent), unless it ran for this draft; before you ask for the yes. Only the user naming that review skips it."
full_spec() { # full_spec STATUS APPROVED: a full-form spec with every section the full form needs
  printf '%s\n' '---' "status: $1" 'form: full' 'date: 2026-10-24' "approved: $2" 'issue: none' '---' '' \
    '## Problem' '' 'A gap.' '' '## Intent' '## Constraints' '' '- Always: x' '- Ask first: y' '- Never: z' '' '## Assumptions' \
    '## Success criteria' '## Acceptance criteria' '' '1. a' '' '## Decisions' '## Compatibility' '## Authorization' '## Rollout' \
    '## Checklists' '## Test seams' '## Not doing' '## Open questions'
}

@test "a clean draft full-form spec exits 0 with one next: line for define step 11's review" {
  full_spec draft '(unset until an explicit yes)' > full.md
  pc full.md
  [ "$status" -eq 0 ]
  [ "$output" = "$NEXT" ]
  [ -z "$stderr" ]
  # plan-check checks a spec with no form: line as the full form, so it is one here too.
  grep -v '^form: ' full.md > noform.md
  pc noform.md
  [ "$status" -eq 0 ]
  [ "$output" = "$NEXT" ]
}

@test "an approved spec, a short-form spec, a parked draft and a plan print no next: line" {
  full_spec approved '2026-10-24, "yes"' > ok.md
  pc ok.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  printf '%s\n' '---' 'status: draft' 'form: short' '---' '## Problem' '## Constraints' '- Always: x' '## Acceptance criteria' '1. a' '## Test seams' > short.md
  pc short.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  full_spec 'draft (parked under autopilot)' '(unset until an explicit yes)' > parked.md
  pc parked.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  sed 's/^status: approved$/status: draft/' plan.md > draft-plan.md
  pc draft-plan.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a draft full-form spec with a problem prints only the problem and exits 1" {
  full_spec draft '(unset until an explicit yes)' | grep -v '^## Rollout$' > bad.md
  pc bad.md
  [ "$status" -eq 1 ]
  [ "$output" = "bad.md:1: missing section ## Rollout" ]
}

# M3 part 2 project 2's paid round 1: go-no-lint-draft's approved short spec read "Files: 4 (...). Next: implement." in 3
# rounds running, and the run built with no plan. define step 9 sends a bounded spec over 2 files to plan, so a clean
# approved short spec whose `## Size` Files count is over 2 gets that next step in plan-check's result.
PLAN_NEXT='next: plan (define step 9: over 2 files)'
short_spec() { # short_spec STATUS SIZE_LINE...: a short-form spec, its ## Size section holding SIZE_LINE...
  local st=$1
  shift
  printf '%s\n' '---' "status: $st" 'form: short' 'date: 2026-11-05' 'issue: "#7"' 'approved: 2026-11-05, "/kern:autopilot go 7"' '---' '' \
    '## Problem' '' 'Files: 9 named in the ticket, which the Size count does not read.' '' '## Size' '' "$@" '' \
    '## Constraints' '' '- Always: x' '' '## Acceptance criteria' '' '1. a' '' '## Test seams' '' '## Not doing'
}

@test "a clean approved short spec over 2 files prints one next: line for plan" {
  short_spec approved 'Files: 4 (src/sum.js, src/tax.js, test/sum.test.js, test/tax.test.js). Lines: about 20 changed. Next: implement.' > four.md
  pc four.md
  [ "$status" -eq 0 ]
  [ "$output" = "$PLAN_NEXT" ]
  [ -z "$stderr" ]
  # The first Files: line of the section counts, its paths after a comma or on a bullet as runs write them.
  short_spec approved 'Files: 3, `src/format.js`, `bin/cli.js`, `test/format.test.js`. Lines: about 30 changed.' 'Files: 1 in the later slices.' > three.md
  pc three.md
  [ "$status" -eq 0 ]
  [ "$output" = "$PLAN_NEXT" ]
  short_spec approved '- **Files:** 3' > bullet.md
  pc bullet.md
  [ "$output" = "$PLAN_NEXT" ]
}

@test "an approved short spec of exactly 2 files, or with no Files count, prints no next: line" {
  short_spec approved 'Files: 2 (src/sum.js, test/sum.test.js). Lines: about 10 changed.' > two.md
  pc two.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  # A Files count outside ## Size, as in the Problem section here, is not read.
  short_spec approved 'Lines: about 10 changed.' > none.md
  pc none.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a draft or full-form spec over 2 files, and a short spec with a problem, print no plan line" {
  short_spec draft 'Files: 4 (src/sum.js, src/tax.js, test/sum.test.js, test/tax.test.js).' > draft.md
  pc draft.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  { full_spec approved '2026-11-05, "yes"'; printf '%s\n' '## Size' 'Files: 4 (a, b, c, d).'; } > full.md
  pc full.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  short_spec approved 'Files: 4 (a, b, c, d).' | grep -v '^## Test seams$' > bad.md
  pc bad.md
  [ "$status" -eq 1 ]
  [ "$output" = "bad.md:1: missing section ## Test seams" ]
}

@test "usage errors exit 2" {
  pc
  [ "$status" -eq 2 ]
  pc --files plan.md x
  [ "$status" -eq 2 ]
  pc none.md
  [ "$status" -eq 2 ]
}

@test "a CRLF plan lints like an LF plan, and still fails when it is bad" {
  sed 's/$/\r/' plan.md > crlf.md
  pc crlf.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  pc --graph crlf.md
  [ "${lines[1]}" = $'wave\t1\t1 4' ]
  sed -i.bak 's/^- Node 22\.\r$/- Node 22. TBD\r/' crlf.md
  pc crlf.md
  [ "$status" -eq 1 ]
  says "placeholder: - Node 22. TBD"
}

@test "a shared_services entry matches a whole word, not a longer word" {
  mkdir -p .claude
  printf 'shared_services: redis\n' > .claude/kern.local.yml
  sed -i.bak 's#^- Create: `docs/parse.md`#- Create: `docs/parse.md` (redistribute the docs)#; s#^- Create: `src/parse.js:1-20`#- Create: `src/parse.js:1-20` (redis cache)#' plan.md
  pc plan.md
  [ "$status" -eq 0 ]
}

@test "a spec with no acceptance criteria, or a spec: that is not a .md file, is an error" {
  printf '%s\n' '---' 'status: draft' '---' '## Acceptance criteria' '' 'none yet' > spec.md
  pc plan.md
  [ "$status" -eq 1 ]
  says "spec spec.md lists no numbered acceptance criteria"
  sed -i.bak 's/^spec: spec.md$/spec: spec/' plan.md
  pc plan.md
  says "spec: must name a .md file"
}

@test "an unclosed frontmatter is an error" {
  printf '%s\n' '---' 'status: draft' '## Problem' > open.md
  pc open.md
  [ "$status" -eq 1 ]
  says "frontmatter is not closed"
}

@test "--graph and --files refuse a spec, and --files refuses a missing task" {
  pc --graph spec.md
  [ "$status" -eq 2 ]
  pc --files plan.md 9
  [ "$status" -eq 2 ]
}

@test "a directory path overlaps a path inside it, and a longer name does not" {
  sed -i.bak 's#^- Create: `src/parse.js:1-20`#- Create: `docs/**`#' plan.md
  pc plan.md
  [ "$status" -eq 1 ]
  says "Task 1 and Task 4 share docs/, but Task 4 is not blocked by Task 1"
  sed -i.bak 's#^- Create: `docs/parse.md`#- Create: `doc.md`#' plan.md
  pc plan.md
  [ "$status" -eq 0 ]
}

@test "--graph keeps a directory and a file inside it out of one wave" {
  sed -i.bak 's#^- Create: `src/parse.js:1-20`#- Create: `docs/**`#' plan.md
  sed -i.bak '/^### Task 4:/,$ s/^\*\*Blocked by:\*\* none$/**Blocked by:** Task 1/' plan.md
  pc --graph plan.md
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = $'overlap\t1\t4\tdocs/' ]
  [ "${lines[2]}" = $'wave\t1\t1' ]
  [ "${lines[3]}" = $'wave\t2\t2 4' ]
}

@test "an Acceptance line with no leading number list is an error" {
  sed -i.bak '/^### Task 4:/,$ s/^\*\*Acceptance:\*\* 3$/**Acceptance:** responds within 2 seconds, covers 1/' plan.md
  pc plan.md
  [ "$status" -eq 1 ]
  says "Task 4: Acceptance names no criterion number"
}

@test "an Acceptance range covers every number in it" {
  sed -i.bak 's/^\*\*Acceptance:\*\* 2$/**Acceptance:** 1/; s/^\*\*Acceptance:\*\* 3$/**Acceptance:** 1-3/' plan.md
  pc plan.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# slice_spec LINE...: a short approved spec under a go, with LINE... from its acceptance list on.
slice_spec() {
  printf '%s\n' '---' 'status: approved' 'form: short' 'date: 2026-10-31' 'issue: MA-1' 'approved: 2026-10-31, "/kern:autopilot go MA-1"' '---' \
    '## Problem' '## Constraints' '- Always: x' '## Acceptance criteria' '' "$@" '## Test seams' > spec.md
}

@test "a first-slice plan passes when the spec moved its later lines to ## Later slices" {
  # Under a go the split happens in the spec, so plan-check and proof-check count the slice unchanged.
  slice_spec '1. Parses a line.' '' '## Later slices' '' '- Stores it.' '- Documents it.' ''
  pc spec.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  sed -i.bak '/^### Task 2:/,$d' plan.md
  pc plan.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a line still under the acceptance heading fails when no task covers it, whatever else the spec holds" {
  sed -i.bak '/^### Task 2:/,$d' plan.md
  pc plan.md
  [ "$status" -eq 1 ]
  says "acceptance criterion 2 of the spec is covered by no task"
  says "acceptance criterion 3 of the spec is covered by no task"
  slice_spec '1. Parses a line.' '2. Stores it.' '' '## Later slices' '' '- Documents it.' ''
  pc plan.md
  [ "$status" -eq 1 ]
  says "acceptance criterion 2 of the spec is covered by no task"
}

@test "only the leading Acceptance list counts, not numbers in the prose after it" {
  sed -i.bak 's/^\*\*Acceptance:\*\* 2$/**Acceptance:** 1/; s/^\*\*Acceptance:\*\* 3$/**Acceptance:** 1, 3 - prose with 2 in it/' plan.md
  pc plan.md
  [ "$status" -eq 1 ]
  says "acceptance criterion 2 of the spec is covered by no task"
}

@test "an unclosed code fence is an error at its opening line" {
  n=$(wc -l < plan.md)
  printf '%s\n' '```' 'text' >> plan.md
  pc plan.md
  [ "$status" -eq 1 ]
  says "plan.md:$((n + 1)): fence not closed"
}

@test "redis-cli counts as using the redis service" {
  mkdir -p .claude
  printf 'shared_services: redis\n' > .claude/kern.local.yml
  sed -i.bak 's#^- Create: `docs/parse.md`#- Create: `docs/parse.md` (run redis-cli flush)#; s#^- Create: `src/parse.js:1-20`#- Create: `src/parse.js:1-20` (redis cache)#' plan.md
  pc plan.md
  [ "$status" -eq 1 ]
  says "Task 1 and Task 4 share redis, but Task 4 is not blocked by Task 1"
}

@test "a backticked none is not an interface name" {
  sed -i.bak '0,/^- Consumes: none$/ s//- Consumes: `none`/; s/^- Produces: `table-b`$/- Produces: `none`/' plan.md
  pc plan.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a tilde fence holding a backtick line closes on its tildes, as CommonMark reads it" {
  printf '%s\n' '~~~markdown' '```' 'quoted text' '~~~' '' >> plan.md
  pc plan.md
  [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "a four-backtick fence holding a three-backtick block is one fence, so its TBD is not prose" {
  printf '%s\n' '````markdown' '```' 'TBD' '```' '````' '' >> plan.md
  pc plan.md
  [ "$status" -eq 0 ] || { echo "$output"; false; }
}

@test "a closer with an info string, or of the other character, does not close a fence" {
  n=$(wc -l < plan.md)
  printf '%s\n' '```' 'text' '```js' '~~~' 'more' >> plan.md
  pc plan.md
  [ "$status" -eq 1 ]
  says "plan.md:$((n + 1)): fence not closed"
}

@test "plan-check refuses a glob in Files" {
  sed -i.bak 's#^- Create: `src/parse.js:1-20`$#- Create: `src/*.js`#' plan.md
  pc plan.md
  [ "$status" -eq 1 ]
  says 'plan.md:'
  says 'Task 1: Files entry src/*.js is a glob'
  sed -i.bak 's#^- Create: `src/\*\.js`$#- Create: `src/**/parse.js`#' plan.md
  pc plan.md
  [ "$status" -eq 1 ]
  says 'Task 1: Files entry src/**/parse.js is a glob'
  sed -i.bak 's#^- Create: `src/\*\*/parse.js`$#- Create: `src/parse?.js`#' plan.md
  pc plan.md
  [ "$status" -eq 1 ]
  says 'Task 1: Files entry src/parse?.js is a glob'
  sed -i.bak 's#^- Create: `src/parse?.js`$#- Create: `src/{a,b}.js`#' plan.md
  pc plan.md
  [ "$status" -eq 1 ]
  says 'Task 1: Files entry src/{a,b}.js is a glob'
}

@test "plan-check takes a path, a line range, a directory form, a route segment and a brace with no list" {
  for entry in 'src/a.js' 'src/a.js:3-9' 'src/*' 'src/**' 'app/[id]/page.tsx' 'src/{id}/a.js' 'src/a,b.js'; do
    cp plan.md "plan-$$.md"
    sed -i.bak "s#^- Create: \`src/parse.js:1-20\`\$#- Create: \`$entry\`#" "plan-$$.md"
    pc "plan-$$.md"
    [ "$status" -eq 0 ] || { echo "refused: $entry: $output"; false; }
  done
}

# M3 part 2 project 1 Task 18, audit row L494, after addy's planning-and-task-breakdown: a task whose Files exceed
# scope_threshold makes a PR over it, so lint mode warns, and plan step 7's stop settles it. The warning never
# changes the exit, and --graph and --files print none, since their output is read by scripts.
five_files() {
  sed -i.bak 's#^- Create: `src/parse.js:1-20`$#- Create: `src/parse.js:1-20`, `src/a.js`, `src/b.js`\
- Test: `test/parse.test.js`, `test/a.test.js`#' plan.md
}

@test "a task with more files than scope_threshold gets a warn: line and keeps exit 0" {
  mkdir -p .claude
  printf 'scope_threshold: 4\n' > .claude/kern.local.yml
  five_files
  pc plan.md
  [ "$status" -eq 0 ]
  [ "$output" = "plan-check: warn: Task 1 lists 5 files, over scope_threshold 4" ]
  [ -z "$stderr" ]
}

@test "the warn: line reads scope_threshold from settings and defaults to 4" {
  pc plan.md
  [ -z "$output" ]
  five_files
  pc plan.md
  [ "$status" -eq 0 ]
  [ "$output" = "plan-check: warn: Task 1 lists 5 files, over scope_threshold 4" ]
  mkdir -p .claude
  printf 'scope_threshold: 5\n' > .claude/kern.local.yml
  pc plan.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  printf 'scope_threshold: 1\n' > .claude/kern.local.yml
  pc plan.md
  [ "$status" -eq 0 ]
  [ "$output" = "plan-check: warn: Task 1 lists 5 files, over scope_threshold 1" ]
  printf 'scope_threshold: four\n' > .claude/kern.local.yml
  pc plan.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a path named twice counts once, and a bare line range counts as no file" {
  sed -i.bak 's#^- Create: `src/parse.js:1-20`$#- Modify: `src/parse.js:1-20`, `:40-52`, `src/a.js`, `src/b.js`\
- Test: `src/parse.js:60`, `src/c.js`#' plan.md
  pc plan.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  sed -i.bak 's#^- Test: `src/parse.js:60`, `src/c.js`$#- Test: `src/parse.js:60`, `src/c.js`, `src/d.js`#' plan.md
  pc plan.md
  [ "$output" = "plan-check: warn: Task 1 lists 5 files, over scope_threshold 4" ]
}

@test "the warn: line leaves a failing exit failing, and --graph and --files print none" {
  five_files
  pc --graph plan.md
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = $'overlap\t2\t3\tmigrations' ]
  [[ "$output" != *warn* ]] || false
  pc --files plan.md 1
  [ "$status" -eq 0 ]
  [ "$output" = $'src/parse.js\nsrc/a.js\nsrc/b.js\ntest/parse.test.js\ntest/a.test.js' ]
  sed -i.bak 's/^\*\*Acceptance:\*\* 3$/**Acceptance:** 1/' plan.md
  pc plan.md
  [ "$status" -eq 1 ]
  says "acceptance criterion 3 of the spec is covered by no task"
  says "plan-check: warn: Task 1 lists 5 files, over scope_threshold 4"
}
