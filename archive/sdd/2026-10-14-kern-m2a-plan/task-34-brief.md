### Task 34: CI for M2a and release 0.3.0

**Files:**
- Create: `tests/scripts/no-commit-review.bats`
- Modify: `scripts/ci-local`, `.github/workflows/ci.yml`, `CHANGELOG.md`, `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (through `scripts/release.mjs`)

**Interfaces:**
- Consumes: everything above; M0's `scripts/release.mjs <major|minor|patch>`; addy's CI shape (`.upstream/addy/.github/workflows/test-plugin-install.yml:70-90` for the macOS leg, `:148-170` for the install test).
- Produces: CI that shellchecks every bash script by glob (`-x -S warning`), runs the bats and node suites on macOS too (bash 3.2, BSD awk) as well as on Ubuntu (bash 5, mawk), and installs kern from its own marketplace as a smoke test; an end-to-end test that a task can be opened, changed, packaged, reviewed and closed with no commit; release 0.3.0.

- [ ] **Step 1: Write the end-to-end test**

```bash
#!/usr/bin/env bats
# tests/scripts/no-commit-review.bats: one task through ledger-open, review and task-done --probe, with no
# commit anywhere and the main checkout unchanged.

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  cd "$REPO"
  printf 'exit 0\n' > check.sh
  git add check.sh && git commit --quiet -m check && git push --quiet origin main
  printf '%s\n' '---' 'status: approved' 'spec: none' 'approved: 2026-10-14, "yes, delegate"' 'execution: delegate' 'commits: ask' '---' > "$TMP/plan.md"
}

@test "a task is opened, changed, packaged, reviewed and closed without a commit" {
  main_branch=$(git rev-parse --abbrev-ref HEAD)
  main_status=$(git status --porcelain | git hash-object --stdin)
  dir=$(bash "$KERN_ROOT/scripts/ledger-open" "$TMP/plan.md" 2> /dev/null)
  wt=$(bash "$KERN_ROOT/scripts/wt-new" plan-x 2> /dev/null)
  head_before=$(git -C "$wt" rev-parse HEAD)
  before=$(bash "$KERN_ROOT/scripts/wt-snap" "$wt")
  bash "$KERN_ROOT/scripts/task-start" "$dir/ledger.md" 1 "$before" > /dev/null
  printf '[ "$1" -ge 0 ]\n' > "$wt/check.sh"
  mkdir -p "$wt/test"
  printf 'sh check.sh -1 && exit 1\necho guarded\n' > "$wt/test/check_test.sh"
  after=$(bash "$KERN_ROOT/scripts/wt-snap" "$wt")
  printf 'check.sh\ntest/\n' > "$dir/briefs/task-1.files"
  run --separate-stderr bash "$KERN_ROOT/scripts/wt-diff" "$wt" "$before" "$after" --out "$dir/reviews/task-1.diff" --allow-file "$dir/briefs/task-1.files"
  [ "$status" -eq 0 ]
  grep -q '^+\[ "\$1" -ge 0 \]$' "$dir/reviews/task-1.diff"
  bash "$KERN_ROOT/scripts/task-review" "$dir/ledger.md" 1 "$after" 1 compliant approved > /dev/null
  run --separate-stderr bash "$KERN_ROOT/scripts/task-done" "$dir/ledger.md" 1 "$wt" "$after" --probe "$dir/reviews/task-1.diff.patch" -- sh test/check_test.sh
  [ "$status" -eq 0 ]
  grep -q "^Task 1: complete tree=$after test=sh test/check_test.sh exit=0 review=approved probe=ok last=guarded$" "$dir/ledger.md"
  [ "$(git -C "$wt" rev-parse HEAD)" = "$head_before" ]
  [ "$(git rev-parse --abbrev-ref HEAD)" = "$main_branch" ]
  [ "$(git status --porcelain | git hash-object --stdin)" = "$main_status" ]
  run --separate-stderr bash "$KERN_ROOT/scripts/ledger-open" --summary "$dir"
  [ "$status" -eq 0 ]
  [ "${lines[${#lines[@]}-1]}" = "main: unchanged" ]
}
```

- [ ] **Step 2: Run it**

Run: `tests/run-bats tests/scripts/no-commit-review.bats`
Expected: `1 test, 0 failures` (it exercises Tasks 1, 2, 6, 8 and 9 together; a failure here means one of them regressed).

- [ ] **Step 3: Extend `scripts/ci-local`**

Insert before the final `echo "ci-local: all steps passed"` line:

```bash
find scripts skills evals/exec/bin -type f \( -name '*.sh' -o ! -name '*.*' \) -print0 | xargs -0 shellcheck -x -S warning
node scripts/seeded-diffs.mjs
```

The bats lines from M0 and M1 (`tests/run-bats tests/scripts`, `tests/run-bats tests/hooks`) already pick up the new `.bats` files, and `node --test 'tests/**/*.test.mjs'` picks up the new Node tests, `tests/skills/*.test.mjs` included.

- [ ] **Step 4: Extend `.github/workflows/ci.yml`**

Append to the `checks` job, after the last existing step:

```yaml
      - name: Shellcheck every bash script
        run: find scripts skills evals/exec/bin -type f \( -name '*.sh' -o ! -name '*.*' \) -print0 | xargs -0 shellcheck -x -S warning
      - name: Seeded-diff set
        run: node scripts/seeded-diffs.mjs
```

Then add two jobs at the end of the file, under `jobs:`:

```yaml
  macos:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: actions/setup-node@v4
        with:
          node-version: '22'
      - name: Install bats and shellcheck
        run: brew install bats-core shellcheck
      - name: Unit tests
        run: node --test 'tests/**/*.test.mjs'
      - name: Lint skills
        run: node scripts/lint-skills.mjs
      - name: Routing evals
        run: node scripts/route-eval.mjs
      - name: Script tests under /bin/bash 3.2 and BSD awk
        run: tests/run-bats tests/scripts
      - name: Hook tests under /bin/bash 3.2
        run: tests/run-bats tests/hooks
      - name: Hook shape over fixture projects
        run: bash tests/hook-shape.sh
  install:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Claude Code
        run: npm install -g @anthropic-ai/claude-code@2.1.296
      - name: Add the repo as a marketplace
        run: claude plugin marketplace add ./
      - name: List marketplaces
        run: claude plugin marketplace list
      - name: Install kern
        run: claude plugin install kern@kern --scope user
```

On Ubuntu `awk` is mawk and on macOS it is BSD awk, so floor-scan, plan-check, brief-check and the hook libraries are tested under both (pre-flight: "the mawk claim is unverified" until this job runs).

- [ ] **Step 5: Run the full local suite**

Run: `scripts/ci-local`
Expected: last line `ci-local: all steps passed`.

- [ ] **Step 6: Run the execution evals on the release tree**

Run them every time, not only when a snapshot looks stale: Tasks 30 to 33 change `hooks/pre-tool-use`, `hooks/lib/*.sh` (alias expansion in `git_words`), `hooks/prompt-submit` and the kernel's routing, none of which a file list for staleness named (pre-flight 2 #7). The run spends tokens: ask the user and run it only on yes.
Run: `node scripts/exec-eval.mjs`
Expected: `PASS` for each case and a new `evals/snapshots/exec-<date>.json`. An `INVALID` line means the Bash tool did not see the gh stub; fix the environment and run again. M2a's acceptance (design spec 14) needs this passing snapshot; without the user's yes, report that acceptance is not yet met instead of releasing.

- [ ] **Step 7: Check M2a's acceptance (design spec 14, row M2a)**

Each item is checked inside M2a; none waits on M2b.

1. Each skill's unit tests and the execution tests pass: Step 5's `scripts/ci-local`, and the passing `evals/snapshots/exec-<date>.json` that Step 6 wrote on this tree, with commit and finish-branch run against the gh stub.
2. Per-task review works with no commits, and `task-done` refuses an unreviewed tree: `tests/scripts/no-commit-review.bats` (Step 1) and `tests/scripts/task-done.bats`.
3. floor-scan and the seeded-diff set pass in CI: `tests/scripts/floor-scan.bats` and `tests/seeded-diffs.test.mjs`, in the CI run on the release commit's PR. That first CI run also confirms what no planning run could (pre-flight 2 #16): `loop-rate.sh` finds `/usr/bin/time` on Ubuntu, the install job adds and installs the marketplace without auth, and the awk scripts pass under mawk. A failure there is fixed before the release, not waived.
4. Shell-snapshot aliases are judged as their expansion: `tests/hooks/aliases.bats`.
5. Release 0.3.0: Step 8.

Not part of M2a's acceptance, and not waited on: the `tests/skills/*.acceptance.md` checklists, which the M2b pilot ticks, and M2b's behavioural, adherence, head-to-head and token measurements. If an item above fails, stop and report it; do not release.

- [ ] **Step 8: Release and commit**

Add under `## [Unreleased]` in `CHANGELOG.md`: `- Standing cost at 0.3.0, measured in chars: kernel 3,487 with no settings (3,926 with the longest fixture), auto descriptions 522, agent descriptions 423, total 4,432; kernel/routes.md 759 per routed task. M2b measures it in tokens.`
Run: `node scripts/release.mjs minor`
It bumps both manifests to 0.3.0 and moves `Unreleased` into the new release section, then prints `git tag v0.3.0`.

```bash
git add -- tests/scripts/no-commit-review.bats scripts/ci-local .github/workflows/ci.yml .claude-plugin/plugin.json .claude-plugin/marketplace.json CHANGELOG.md
git commit -m "M2: CI on macOS, an install smoke test, and release 0.3.0" -m "M2a acceptance: unit, script, hook, seeded-diff, routing and execution evals green, with the committed exec-eval snapshot; bash 3.2 and BSD awk now run in CI, not only in ci-local."
```

If Step 6 ran, add `evals/snapshots` to the `git add` line. Create the tag the release script printed. Pushing the commit and the tag waits for the user's yes. M2b (`docs/plans/2026-10-14-kern-m2b-plan.md`) starts from this tag.

---

## Self-review

- Every pre-flight finding, coverage gap 5 to 19 except 10 and 13, the 0.2.1 minors, F3 and the M2a items of the goal-0 review map to a task and a test in `docs/plans/2026-10-14-kern-m2-traceability.md`.
- Pre-flight F2 (rule 6 and `0.` steps) was applied in M1 and is not repeated; F4 (`2>&1` split on `&`) no longer reproduces, because M1's `_split_words` skips an `&` after `>` (measured), and Task 12's test pins it.
- Every script in this plan was run in a planning sandbox against the current M1 and 0.2.1 code: after the pre-flight fix pass, the whole hook suite (504 tests) and script suite (154 tests) passed on /bin/bash 3.2, the changed suites passed on Ubuntu (kern-ci, GNU sed and find, mawk; 89 tests), every new node test passed, an existing node test that Task 29 would have broken is now updated in Task 29, shellcheck at warning level printed nothing, and the simulated M2a tree linted clean with route-eval passing at 88% and 36%.

## Tasks added during execution

(None yet. A task added during execution goes here with its reason, as in the M1 plan.)
