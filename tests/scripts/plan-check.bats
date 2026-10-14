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
