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

@test "a Markdown heading or bullet is not an absolute claim; a doc's unknown commit id still is" {
  printf '# Never commit secrets\n\n* always run the tests first\n\nFixed in deadbee1cafe.\n' > GUIDE.md
  check GUIDE.md
  [ "$status" -eq 1 ]
  [ "${#lines[@]}" -eq 1 ]
  [ "${lines[0]}" = $'GUIDE.md:5\tsha-unknown\tdeadbee1cafe' ]
}
