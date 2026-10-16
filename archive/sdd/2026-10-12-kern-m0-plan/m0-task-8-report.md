# Task 8 report: CI

Status: DONE

## What I did
- Wrote scripts/ci-local and .github/workflows/ci.yml verbatim from the brief.
- Ran scripts/ci-local locally: all steps passed.
- Committed 3bd64cd "M0: run lint, tests, routing evals and plugin validation in CI".
- Created private repo and pushed main: https://github.com/MustaMohamed/kern

## ci-local tail
Validating plugin manifest: /Users/musta/Code/projects/kern/.claude-plugin/plugin.json

✔ Validation passed
1..7
ok 1 clones at the pinned commit
ok 2 second run is a no-op
ok 3 missing commit exits 3 and removes the partial clone
ok 4 copy source is copied
ok 5 missing copy source exits 3
ok 6 a failing git source is not swallowed
ok 7 unknown key exits 2
ci-local: all steps passed

## CI runs
- 38226071050: success (first attempt, no fixes needed, including claude plugin validate)

## Files changed
.github/workflows/ci.yml, scripts/ci-local

## Concerns
- Annotations only: Node 20 action deprecation (checkout@v4, setup-node@v4 forced to Node 24); ubuntu-latest migrates to Ubuntu 26 on 2026-10-19.
