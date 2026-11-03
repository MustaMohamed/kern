#!/usr/bin/env bats
# tests/scripts/review-check.bats: review-check runs self-review's deterministic pass in one call and prints
# the verdict floor. Settings go in the test HOME's ~/.claude/kern.yml, so the package holds only the change.

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  cd "$REPO"
  mkdir -p "$HOME/.claude" src
  printf 'export const sum = (a, b) => a + b;\n' > src/sum.js
}

# settings LINE...: the user's kern.yml, one `key: value` line per argument.
settings() { printf '%s\n' "$@" > "$HOME/.claude/kern.yml"; }

# package: the wt-diff package of the working tree against HEAD, in $PKG.
package() {
  PKG="$TMP/reviews/pkg-1.diff"
  bash "$KERN_ROOT/scripts/wt-diff" "$REPO" HEAD --out "$PKG" > /dev/null
}

# check ARG...: review-check on $REPO and $PKG.
check() { run --separate-stderr bash "$KERN_ROOT/scripts/review-check" "$REPO" "$PKG" "$@"; }

has() { printf '%s\n' "$output" | grep -qxF -- "$1" || { echo "no line '$1' in:"; echo "$output"; false; }; }

spec() { printf '# Sum\n\n## Acceptance criteria\n\n1. sum adds two numbers.\n' > "$TMP/spec.md"; }

@test "neither spec flag is a usage error" {
  settings 'verify.fast: true'
  package
  check
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"usage: review-check"* ]] || false
  [ -z "$output" ]
  spec
  check --spec "$TMP/spec.md" --no-spec
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"usage: review-check"* ]] || false
}

@test "a clean package with no spec" {
  settings 'verify.fast: true'
  package
  check --no-spec
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '%s\n' 'check: verify.fast: ok' 'check: floor-scan: ok' 'check: claim-check: ok' 'proofs: not due (no spec)' 'floor: none')" ]
}

@test "a spec with no proofs file fails" {
  settings 'verify.fast: true'
  package
  spec
  check --spec "$TMP/spec.md"
  [ "$status" -eq 1 ]
  has 'check: claim-check: hits'
  has 'proofs: checked'
  has '--- claim-check'
  has "no proofs file: $PKG.proofs.md"
  [ "${lines[${#lines[@]} - 1]}" = 'floor: fix first' ]
}

@test "a spec with every line proven passes" {
  settings 'verify.fast: true'
  package
  spec
  printf '| Line | State | Evidence |\n|---|---|---|\n| 1 | - | `node --test`: 1 passed |\n' > "$PKG.proofs.md"
  check --spec "$TMP/spec.md"
  [ "$status" -eq 0 ]
  has 'check: claim-check: ok'
  has 'proofs: checked'
  [ "${lines[${#lines[@]} - 1]}" = 'floor: none' ]
}

@test "a spec with no numbered acceptance line is n/a, not checked" {
  settings 'verify.fast: true'
  package
  printf '# Sum\n\n## Acceptance criteria\n\n- sum adds two numbers.\n' > "$TMP/issue.md"
  check --spec "$TMP/issue.md"
  [ "$status" -eq 0 ]
  has 'check: claim-check: ok'
  has 'proofs: n/a (no numbered acceptance lines)'
  [[ "$output" != *'proofs: checked'* ]] || false
  [ "${lines[${#lines[@]} - 1]}" = 'floor: none' ]
}

@test "a red verify.fast fails" {
  settings 'verify.fast: false'
  package
  check --no-spec
  [ "$status" -eq 1 ]
  has 'check: verify.fast: fail'
  has '--- verify.fast'
  [ "${lines[${#lines[@]} - 1]}" = 'floor: fix first' ]
}

@test "an unresolved verify.fast is a named skip only under --autopilot" {
  package
  check --no-spec --autopilot
  [ "$status" -eq 0 ]
  has 'check: verify.fast: skip (named)'
  [ "${lines[${#lines[@]} - 1]}" = 'floor: none' ]
  check --no-spec
  [ "$status" -eq 1 ]
  has 'check: verify.fast: unresolved'
  has '--- verify.fast'
  [ "${lines[${#lines[@]} - 1]}" = 'floor: fix first' ]
}

@test "a red focused test fails" {
  settings 'verify.fast: true' 'test.focused: sh {file}'
  mkdir -p test
  printf 'echo "sum: expected 3, got -1"\nexit 1\n' > test/sum.sh
  package
  check --no-spec --test test/sum.sh
  [ "$status" -eq 1 ]
  has 'check: test: fail'
  has '--- test'
  has 'sum: expected 3, got -1'
  [ "${lines[${#lines[@]} - 1]}" = 'floor: fix first' ]
}

@test "a floor-scan hit fails" {
  settings 'verify.fast: true'
  printf "export const sum = (a, b) => {\n  console.log('debug');\n  return a + b;\n};\n" > src/sum.js
  package
  check --no-spec
  [ "$status" -eq 1 ]
  has 'check: floor-scan: hits'
  has '--- floor-scan'
  [ "${lines[${#lines[@]} - 1]}" = 'floor: fix first' ]
}
