### Task 10: `brief-check`, complete briefs before a spawn

**Files:**
- Create: `scripts/brief-check`
- Test: `tests/scripts/brief-check.bats`

**Interfaces:**
- Consumes: the brief fields of `skills/parallel-work/references/brief-template.md` (Task 21 writes the template; the field names are fixed here).
- Produces: `brief-check FILE`: prints `brief-check: ok` (exit 0), or one line per problem (`missing: <FIELD>`, `empty: <FIELD>`, `placeholder: <FIELD>`, `VERIFY must start with the wt-check entry check`) with exit 1; usage exit 2. `placeholder` means the field's text is still the brief template's placeholder (pre-flight 2 #4: the unfilled template passed); FORBIDDEN's text is meant to be kept and is not checked. The placeholder texts are fixed here, and Task 21's test runs brief-check on the unfilled template. Fields: GOAL, SCOPE, CONTEXT, ACCEPTANCE, VERIFY, TIMEBOX, FORBIDDEN, REPORT, STANDING, each a line that starts with its label and holds text after it or on the next indented lines.

- [ ] **Step 1: Write the failing tests**

```bash
#!/usr/bin/env bats
# tests/scripts/brief-check.bats

bats_require_minimum_version 1.5.0

setup() {
  KERN_ROOT=$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)
  B="$BATS_TEST_TMPDIR/brief.md"
  printf '%s\n' \
    'GOAL        Make sum() reject strings.' \
    'SCOPE       write src/sum.js and test/sum.test.js only; worktree /w/a; base origin/main' \
    'CONTEXT     src/sum.js:1-10' \
    'ACCEPTANCE  sum("1", 2) throws a TypeError' \
    'VERIFY      bash /k/scripts/wt-check /w/a origin/main' \
    '            npm test -- test/sum.test.js' \
    'TIMEBOX     20 minutes' \
    'FORBIDDEN   commit, push, writes outside SCOPE' \
    'REPORT      status line, files, commands with results, report at /w/a.report.md' \
    'STANDING    the standing orders, pasted' > "$B"
}

@test "a complete brief passes, including a field continued on indented lines" {
  run --separate-stderr bash "$KERN_ROOT/scripts/brief-check" "$B"
  [ "$status" -eq 0 ]
  [ "$output" = "brief-check: ok" ]
}

@test "a missing field and an empty field are each named" {
  sed -i.bak -e '/^TIMEBOX/d' -e 's/^REPORT .*/REPORT/' "$B"
  run --separate-stderr bash "$KERN_ROOT/scripts/brief-check" "$B"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "missing: TIMEBOX" ]
  [ "${lines[1]}" = "empty: REPORT" ]
}

@test "VERIFY must start with the entry check" {
  sed -i.bak 's#^VERIFY .*#VERIFY      npm test#' "$B"
  run --separate-stderr bash "$KERN_ROOT/scripts/brief-check" "$B"
  [ "$status" -eq 1 ]
  [ "$output" = "VERIFY must start with the wt-check entry check" ]
}

@test "a field whose text is on the next indented line counts" {
  sed -i.bak 's/^GOAL .*/GOAL/' "$B"
  sed -i.bak '/^GOAL$/a\
            Make sum() reject strings.
' "$B"
  run --separate-stderr bash "$KERN_ROOT/scripts/brief-check" "$B"
  [ "$status" -eq 0 ]
}

@test "a label inside a word does not count, and an unreadable file exits 2" {
  printf 'GOALS are set\n' > "$BATS_TEST_TMPDIR/x.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/brief-check" "$BATS_TEST_TMPDIR/x.md"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "missing: GOAL" ]
  run --separate-stderr bash "$KERN_ROOT/scripts/brief-check" "$BATS_TEST_TMPDIR/none.md"
  [ "$status" -eq 2 ]
}

@test "a field still holding the template placeholder is not filled in" {
  sed 's/^GOAL .*/GOAL        one sentence; the outcome, runnable by someone with no chat access/' "$B" > "$BATS_TEST_TMPDIR/ph.md"
  run --separate-stderr bash "$KERN_ROOT/scripts/brief-check" "$BATS_TEST_TMPDIR/ph.md"
  [ "$status" -eq 1 ]
  [ "$output" = "placeholder: GOAL" ]
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run-bats tests/scripts/brief-check.bats`
Expected: every test fails; `scripts/brief-check: No such file or directory`.

- [ ] **Step 3: Write `scripts/brief-check`**

```bash
#!/usr/bin/env bash
# Refuse a worker brief that is missing a field, so parallel-work spawns only complete briefs.
# Usage: brief-check FILE    Prints "brief-check: ok" (exit 0) or one line per problem (exit 1); usage exit 2.
# A field is a line that starts with its label (GOAL, SCOPE, CONTEXT, ACCEPTANCE, VERIFY, TIMEBOX,
# FORBIDDEN, REPORT, STANDING) and holds text after it, or whose next indented lines do. VERIFY's first
# command is the wt-check entry check. A field whose text is still the placeholder from
# skills/parallel-work/references/brief-template.md is not filled in (FORBIDDEN's text is meant to be
# kept, so it is not checked).
# Field list adapted from pstack poteto-mode playbooks/orchestrate.md (MIT).
set -euo pipefail
[ $# -eq 1 ] || { echo "usage: brief-check FILE" >&2; exit 2; }
[ -r "$1" ] || { echo "brief-check: cannot read $1" >&2; exit 2; }
awk '
  BEGIN {
    n = split("GOAL SCOPE CONTEXT ACCEPTANCE VERIFY TIMEBOX FORBIDDEN REPORT STANDING", L, " ")
    ph["GOAL"] = "one sentence; the outcome, runnable by someone with no chat access"
    ph["SCOPE"] = "paths this worker may write; paths it may not; its worktree path and base ref"
    ph["CONTEXT"] = "file pointers; upstream reports pasted in full when this unit depends on them"
    ph["ACCEPTANCE"] = "checkable criteria, one per line"
    ph["VERIFY"] = "exact commands, starting with wt-check <wt> <base-ref>, then the focused baseline"
    ph["TIMEBOX"] = "rough cap; on expiry return partial findings and stop"
    ph["REPORT"] = "status line, files, commands run with results, deviations, report file path"
    ph["STANDING"] = "the standing orders below, pasted verbatim"
  }
  /^[ \t]*```/ { next }
  {
    for (i = 1; i <= n; i++) {
      if (index($0, L[i]) == 1 && (length($0) == length(L[i]) || substr($0, length(L[i]) + 1, 1) ~ /[ \t:]/)) {
        cur = L[i]; seen[cur] = 1
        rest = substr($0, length(L[i]) + 1); sub(/^[ \t:]+/, "", rest)
        if (rest != "") { text[cur] = rest; first[cur] = rest }
        next
      }
    }
    if (cur != "" && $0 ~ /^[ \t]+[^ \t]/) {
      line = $0; sub(/^[ \t]+/, "", line)
      if (first[cur] == "") first[cur] = line
      text[cur] = text[cur] " " line
      next
    }
    cur = ""
  }
  END {
    for (i = 1; i <= n; i++) {
      if (!seen[L[i]]) { print "missing: " L[i]; bad = 1 }
      else if (text[L[i]] == "") { print "empty: " L[i]; bad = 1 }
      else if ((L[i] in ph) && text[L[i]] == ph[L[i]]) { print "placeholder: " L[i]; bad = 1 }
    }
    if (seen["VERIFY"] && text["VERIFY"] != "" && first["VERIFY"] !~ /wt-check/) { print "VERIFY must start with the wt-check entry check"; bad = 1 }
    if (!bad) print "brief-check: ok"
    exit bad
  }' "$1"
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `chmod +x scripts/brief-check && tests/run-bats tests/scripts/brief-check.bats && shellcheck scripts/brief-check`
Expected: `6 tests, 0 failures`; shellcheck prints nothing.

- [ ] **Step 5: Commit**

```bash
git add -- scripts/brief-check tests/scripts/brief-check.bats
git commit -m "M2: add brief-check" -m "A missing brief field means do not spawn; checking it in code turns that rule from prose into an exit code."
```

---

