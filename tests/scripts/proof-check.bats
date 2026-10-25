#!/usr/bin/env bats
# tests/scripts/proof-check.bats: one proof per acceptance line and per state it names; fails closed.

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  cd "$TMP"
  cat > spec.md <<'SPEC'
---
status: approved
---
## Acceptance criteria

1. The form saves a transaction. States: `add`, `edit`. Handles: `testID=save`.
2. Rows below the fold show their label. States: `rows reached by scrolling`.
3. `npm test` passes.

## Test seams
SPEC
  : > add.png
  : > edit.png
}

# proofs ROW...: proofs.md, a header and divider, then one table row per ROW.
proofs() {
  { printf '| Line | State | Evidence |\n|---|---|---|\n'; printf '%s\n' "$@"; } > proofs.md
}

@test "every line and named state with evidence passes; a line with no States needs one row" {
  proofs '| 1 | add | `./add.png` |' '| 1 | `Edit` | `./edit.png` |' '| 2 | rows reached by scrolling | `npm test -- rows`: 3 passed |' '| 3 | - | `npm test`: 12 passed |'
  run --separate-stderr bash "$KERN_ROOT/scripts/proof-check" spec.md proofs.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a missing state, an empty proof, a missing file and a row for nothing each fail" {
  rm edit.png
  proofs '| 1 | add | `./add.png` |' '| 1 | edit | `./edit.png` |' '| 2 | rows reached by scrolling | none |' '| 4 | - | `npm test` |'
  run --separate-stderr bash "$KERN_ROOT/scripts/proof-check" spec.md proofs.md
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "missing file: proofs.md:4: ./edit.png" ]
  [ "${lines[1]}" = "no evidence: proofs.md:5" ]
  [ "${lines[2]}" = "unknown: proofs.md:6: line 4 state -" ]
  [ "${lines[3]}" = "unproven: 1 edit" ]
  [ "${lines[4]}" = "unproven: 2 rows reached by scrolling" ]
  [ "${lines[5]}" = "unproven: 3 -" ]
}

@test "evidence text never reaches a command line" {
  proofs '| 1 | add | `/$(touch${IFS}pwned)` |'
  run --separate-stderr bash "$KERN_ROOT/scripts/proof-check" spec.md proofs.md
  [ "$status" -eq 1 ]
  [ ! -e pwned ]
}

@test "a usage error, an unreadable file or a spec with no numbered acceptance line exits 2" {
  proofs '| 1 | add | `./add.png` |'
  run --separate-stderr bash "$KERN_ROOT/scripts/proof-check" spec.md
  [ "$status" -eq 2 ]
  run --separate-stderr bash "$KERN_ROOT/scripts/proof-check" nope.md proofs.md
  [ "$status" -eq 2 ]
  printf '## Problem\n\nx\n' > empty.md
  run --separate-stderr bash "$KERN_ROOT/scripts/proof-check" empty.md proofs.md
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"no numbered line under ## Acceptance criteria"* ]] || false
}
