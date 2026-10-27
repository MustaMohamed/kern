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

@test "States on a continuation line of a numbered line counts, up to the next numbered or blank line" {
  # Task 6 fix round 1, I2: a States: the parser could not read collapsed to the one state `-`.
  cat > cont.md <<'SPEC'
## Acceptance criteria

1. The form saves a transaction.
   States: `add`, `edit`. Handles: `testID=save`.
2. Rows show their label.
### Notes
States: `not an acceptance line`.

## Test seams
SPEC
  proofs '| 1 | - | `npm test`: 3 passed |' '| 2 | - | `npm test`: 3 passed |'
  run --separate-stderr bash "$KERN_ROOT/scripts/proof-check" cont.md proofs.md
  [ "$status" -eq 1 ]
  [ "${#lines[@]}" -eq 3 ]
  [ "${lines[0]}" = "unknown: proofs.md:3: line 1 state -" ]
  [ "${lines[1]}" = "unproven: 1 add" ]
  [ "${lines[2]}" = "unproven: 1 edit" ]
  proofs '| 1 | add | `./add.png` |' '| 1 | edit | `./edit.png` |' '| 2 | - | `npm test`: 3 passed |'
  run --separate-stderr bash "$KERN_ROOT/scripts/proof-check" cont.md proofs.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a States: with no backticked state exits 2 and names the line, on a numbered line or its continuation" {
  # Task 6 fix round 1, I2: `States: add, edit.` passed with a single `| 1 | - |` row.
  proofs '| 1 | - | `npm test`: 3 passed |' '| 2 | - | `npm test`: 3 passed |'
  printf '## Acceptance criteria\n\n1. The form saves. States: add, edit.\n' > bare.md
  run --separate-stderr bash "$KERN_ROOT/scripts/proof-check" bare.md proofs.md
  [ "$status" -eq 2 ]
  [ -z "$output" ]
  [ "$stderr" = "proof-check: bare.md:3: line 1 has States: with no backticked state" ]
  printf '## Acceptance criteria\n\n1. The form saves.\n2. Rows show their label.\n   States: rows reached by scrolling.\n' > bare2.md
  run --separate-stderr bash "$KERN_ROOT/scripts/proof-check" bare2.md proofs.md
  [ "$status" -eq 2 ]
  [ "$stderr" = "proof-check: bare2.md:5: line 2 has States: with no backticked state" ]
}

@test "evidence with no backticked span, or a placeholder with a trailing dot, proves nothing" {
  # Task 6 fix round 1, I3: the placeholder list matched whole cells only, so these each passed.
  proofs '| 1 | add | looks fine |' '| 1 | edit | None. |' '| 2 | rows reached by scrolling | not run |' '| 3 | - | `none`. |'
  run --separate-stderr bash "$KERN_ROOT/scripts/proof-check" spec.md proofs.md
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "no evidence: proofs.md:3" ]
  [ "${lines[1]}" = "no evidence: proofs.md:4" ]
  [ "${lines[2]}" = "no evidence: proofs.md:5" ]
  [ "${lines[3]}" = "no evidence: proofs.md:6" ]
  [ "${lines[4]}" = "unproven: 1 add" ]
  [ "${lines[7]}" = "unproven: 3 -" ]
}

@test "a backticked placeholder such as not run, skipped, pending or unproven proves nothing" {
  # Final review M2: `` `not run` `` had a backticked span, so it counted as evidence.
  proofs '| 1 | add | `not run` |' '| 1 | edit | `Skipped`. |' '| 2 | rows reached by scrolling | `pending` |' '| 3 | - | `unproven` |'
  run --separate-stderr bash "$KERN_ROOT/scripts/proof-check" spec.md proofs.md
  [ "$status" -eq 1 ]
  [ "${#lines[@]}" -eq 8 ]
  [ "${lines[0]}" = "no evidence: proofs.md:3" ]
  [ "${lines[1]}" = "no evidence: proofs.md:4" ]
  [ "${lines[2]}" = "no evidence: proofs.md:5" ]
  [ "${lines[3]}" = "no evidence: proofs.md:6" ]
  # A command that names a placeholder word is still evidence.
  proofs '| 1 | add | `npm test -- not run`: 2 passed |' '| 1 | edit | `./edit.png` |' '| 2 | rows reached by scrolling | `npm test -- pending`: 1 passed |' '| 3 | - | `npm test`: 12 passed |'
  run --separate-stderr bash "$KERN_ROOT/scripts/proof-check" spec.md proofs.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "evidence marked degraded: fails and leaves its state unproven" {
  proofs '| 1 | add | `./add.png` |' '| 1 | edit | `./edit.png` Degraded: the form drew empty |' '| 2 | rows reached by scrolling | `npm test -- rows`: 3 passed, not degraded |' '| 3 | - | `npm test`: 12 passed |'
  run --separate-stderr bash "$KERN_ROOT/scripts/proof-check" spec.md proofs.md
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "degraded: proofs.md:4: line 1 state edit" ]
  [ "${lines[1]}" = "unproven: 1 edit" ]
  [ "${#lines[@]}" -eq 2 ]
}
