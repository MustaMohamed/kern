#!/usr/bin/env bats
# tests/scripts/claim-check.bats: claim-check fails closed, and the rules that decide a hit are pinned.
# The first two claim-check tests live in claim-probe.bats.

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  cd "$REPO"
}

# check FILE: claim-check on the intent-to-add diff of FILE, already written in the repo.
check() {
  git add -N "$1"
  git diff > "$TMP/c.diff"
  run --separate-stderr bash "$KERN_ROOT/scripts/claim-check" "$REPO" "$TMP/c.diff"
}

@test "a Latin-1 byte under a UTF-8 locale still yields every hit" {
  printf '// caf\351 note\n// see deadbee1cafe here\n// this handler is always called after init\n' > notes.js
  git add -N notes.js
  git diff > "$TMP/c.diff"
  run --separate-stderr env LC_ALL=en_US.UTF-8 bash "$KERN_ROOT/scripts/claim-check" "$REPO" "$TMP/c.diff"
  [ "$status" -eq 1 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = $'notes.js:2\tsha-unknown\tdeadbee1cafe' ]
  [[ "${lines[1]}" == $'notes.js:3\tabsolute-claim\t'* ]] || false
}

@test "an awk that aborts mid-diff exits 2 and prints no hit" {
  printf '// this handler is always called after init\n' > notes.js
  git add -N notes.js
  git diff > "$TMP/c.diff"
  mkdir -p "$TMP/stub"
  printf '#!/bin/sh\nprintf "notes.js\\t1\\tword\\t// always\\n"\necho "awk: towc: multibyte conversion failure" >&2\nexit 2\n' > "$TMP/stub/awk"
  chmod +x "$TMP/stub/awk"
  run --separate-stderr env PATH="$TMP/stub:$PATH" bash "$KERN_ROOT/scripts/claim-check" "$REPO" "$TMP/c.diff"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"claim-check: "* ]] || false
}

@test "input with no diff --git line exits 2: a name-status list, an empty file, a directory" {
  printf 'M\tsrc/a.js\n' > "$TMP/notdiff"
  run --separate-stderr bash "$KERN_ROOT/scripts/claim-check" "$REPO" "$TMP/notdiff"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"no diff --git"* ]] || false
  : > "$TMP/empty.diff"
  run --separate-stderr bash "$KERN_ROOT/scripts/claim-check" "$REPO" "$TMP/empty.diff"
  [ "$status" -eq 2 ]
  mkdir -p "$TMP/dir"
  run --separate-stderr bash "$KERN_ROOT/scripts/claim-check" "$REPO" "$TMP/dir"
  [ "$status" -eq 2 ]
}

@test "a 0x hex constant is not a commit id" {
  printf 'const MASK = 0xdeadbeef1;\nconst LOW = 0x0123abcd;\n' > mask.js
  check mask.js
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a number with no letter a-f is not a commit id" {
  printf 'const big = 12345678901;\nconst day = "20261022";\n' > nums.js
  check nums.js
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "an absolute word in code, not in a comment, is not a hit" {
  printf "const mode = 'always';\nif (never) return;\nlet impossible = false;\n" > words.js
  check words.js
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a CMakeLists.txt is code, not a doc: its comment's absolute word is a hit" {
  mkdir -p lib
  printf '# this target is always built first\n' > CMakeLists.txt
  printf '# never link this statically\n' > lib/CMakeLists.txt
  git add -N CMakeLists.txt lib/CMakeLists.txt
  git diff > "$TMP/c.diff"
  run --separate-stderr bash "$KERN_ROOT/scripts/claim-check" "$REPO" "$TMP/c.diff"
  [ "$status" -eq 1 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = $'CMakeLists.txt:1\tabsolute-claim\t# this target is always built first' ]
  [ "${lines[1]}" = $'lib/CMakeLists.txt:1\tabsolute-claim\t# never link this statically' ]
}

@test "a Markdown heading or bullet is not an absolute claim; a doc's unknown commit id still is" {
  printf '# Never commit secrets\n\n* always run the tests first\n\nFixed in deadbee1cafe.\n' > GUIDE.md
  check GUIDE.md
  [ "$status" -eq 1 ]
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = $'GUIDE.md:5\tsha-unknown\tdeadbee1cafe' ]
}

# clean_diff: a diff with no hit in $TMP/c.diff. numbered_spec: $TMP/spec.md with two lines, the first naming two states.
clean_diff() {
  printf 'const one = 1;\n' > clean.js
  git add -N clean.js
  git diff > "$TMP/c.diff"
}
numbered_spec() {
  printf '# Currency\n\n## Acceptance criteria\n\n1. Totals print. States: `USD`, `EUR`\n2. An unknown code throws.\n' > "$TMP/spec.md"
}
all_proofs() {
  printf '| Line | State | Evidence |\n|---|---|---|\n| 1 | `USD` | `npm test`: 2 passed |\n| 1 | `EUR` | `npm test`: 2 passed |\n| 2 | - | `npm test`: 2 passed |\n' > "$TMP/proofs.md"
}
# proofs SPEC PROOFS: claim-check with --spec on $TMP/c.diff.
proofs() {
  run --separate-stderr bash "$KERN_ROOT/scripts/claim-check" "$REPO" "$TMP/c.diff" --spec "$1" --proofs "$2"
}

@test "with no --spec the diff check is all that runs, and a clean diff prints nothing" {
  clean_diff
  run --separate-stderr bash "$KERN_ROOT/scripts/claim-check" "$REPO" "$TMP/c.diff"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "--spec: a table that proves every line and state exits 0 and prints nothing" {
  clean_diff; numbered_spec; all_proofs
  proofs "$TMP/spec.md" "$TMP/proofs.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "--spec: a line with no proof prints proof-check's line and exits 1" {
  clean_diff; numbered_spec; all_proofs
  sed -i.bak '/^| 2 /d' "$TMP/proofs.md"
  proofs "$TMP/spec.md" "$TMP/proofs.md"
  [ "$status" -eq 1 ]
  [ "$output" = "unproven: 2 -" ]
}

@test "--spec: evidence reading not run proves nothing" {
  clean_diff; numbered_spec; all_proofs
  sed -i.bak 's/^| 2 .*/| 2 | - | `not run` |/' "$TMP/proofs.md"
  proofs "$TMP/spec.md" "$TMP/proofs.md"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "no evidence: $TMP/proofs.md:5" ]
  [ "${lines[1]}" = "unproven: 2 -" ]
}

@test "--spec: no proofs file is a hit and exit 1, and every line it leaves unproven is listed" {
  clean_diff; numbered_spec
  proofs "$TMP/spec.md" "$TMP/none.md"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "no proofs file: $TMP/none.md" ]
  [ "${lines[1]}" = "unproven: 1 usd" ]
  [ "${lines[2]}" = "unproven: 1 eur" ]
  [ "${lines[3]}" = "unproven: 2 -" ]
  mkdir "$TMP/adir"
  proofs "$TMP/spec.md" "$TMP/adir"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "no proofs file: $TMP/adir" ]
}

@test "--spec: a spec with no numbered acceptance lines prints the n/a line and exits 0, proofs file or not" {
  clean_diff; all_proofs
  printf '# Issue\n\n1. A numbered line outside the section.\n\n## Acceptance criteria\n\nTotals print.\n' > "$TMP/issue.md"
  proofs "$TMP/issue.md" "$TMP/none.md"
  [ "$status" -eq 0 ]
  [ "$output" = "proof-check: n/a ($TMP/issue.md has no numbered acceptance lines)" ]
  [ -z "$stderr" ]
  proofs "$TMP/issue.md" "$TMP/proofs.md"
  [ "$status" -eq 0 ]
  [ "$output" = "proof-check: n/a ($TMP/issue.md has no numbered acceptance lines)" ]
}

@test "--spec: the proof pass follows the hits, and hits exit 1 with a clean table or an n/a spec" {
  numbered_spec; all_proofs
  printf '// this handler is always called after init\n' > notes.js
  git add -N notes.js
  git diff > "$TMP/c.diff"
  proofs "$TMP/spec.md" "$TMP/proofs.md"
  [ "$status" -eq 1 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "${lines[0]}" == $'notes.js:1\tabsolute-claim\t'* ]] || false
  sed -i.bak '/^| 2 /d' "$TMP/proofs.md"
  proofs "$TMP/spec.md" "$TMP/proofs.md"
  [ "$status" -eq 1 ]
  [[ "${lines[0]}" == $'notes.js:1\tabsolute-claim\t'* ]] || false
  [ "${lines[1]}" = "unproven: 2 -" ]
  printf '# Issue\n' > "$TMP/issue.md"
  proofs "$TMP/issue.md" "$TMP/proofs.md"
  [ "$status" -eq 1 ]
  [[ "${lines[0]}" == $'notes.js:1\tabsolute-claim\t'* ]] || false
  [ "${lines[1]}" = "proof-check: n/a ($TMP/issue.md has no numbered acceptance lines)" ]
}

@test "--spec: a proof-check that cannot finish exits 2 with its reason, so it never reads as n/a" {
  clean_diff; all_proofs
  printf '## Acceptance criteria\n\n1. Totals print. States: USD\n' > "$TMP/bad.md"
  proofs "$TMP/bad.md" "$TMP/proofs.md"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [[ "$stderr" == *"has States: with no backticked state"* ]] || false
}

@test "--spec: a proof-check that is not there exits 2" {
  clean_diff; numbered_spec; all_proofs
  mkdir -p "$TMP/lone"
  cp "$KERN_ROOT/scripts/claim-check" "$TMP/lone/claim-check"
  run --separate-stderr bash "$TMP/lone/claim-check" "$REPO" "$TMP/c.diff" --spec "$TMP/spec.md" --proofs "$TMP/proofs.md"
  [ "$status" -eq 2 ]
  [ -z "$output" ]
}

@test "--spec: a missing spec or a directory exits 2" {
  clean_diff; all_proofs
  proofs "$TMP/none.md" "$TMP/proofs.md"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"claim-check: cannot read $TMP/none.md"* ]] || false
  mkdir "$TMP/adir"
  proofs "$TMP/adir" "$TMP/proofs.md"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"claim-check: cannot read $TMP/adir"* ]] || false
}

@test "--spec and --proofs come together and in that order; anything else is a usage error" {
  clean_diff; numbered_spec; all_proofs
  run --separate-stderr bash "$KERN_ROOT/scripts/claim-check" "$REPO" "$TMP/c.diff" --spec "$TMP/spec.md"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"usage: claim-check WT DIFF_FILE [--spec SPEC --proofs FILE]"* ]] || false
  run --separate-stderr bash "$KERN_ROOT/scripts/claim-check" "$REPO" "$TMP/c.diff" --proofs "$TMP/proofs.md" --spec "$TMP/spec.md"
  [ "$status" -eq 2 ]
  run --separate-stderr bash "$KERN_ROOT/scripts/claim-check" "$REPO" "$TMP/c.diff" --spec "$TMP/spec.md" --proofs "$TMP/proofs.md" extra
  [ "$status" -eq 2 ]
}
