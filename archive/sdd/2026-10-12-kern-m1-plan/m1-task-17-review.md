### Spec Compliance

- ✅ Fixtures (8 dirs, expect.txt, long-settings yml), `tests/hook-shape.sh`, the three lint tests, rules 7/13/15, imports, ci.yml and ci-local match the brief character for character. Exceptions: the ruled rule 13 regex (`scripts/lib/lint-rules.mjs:92`) and the one extra test (`tests/lint-rules.test.mjs:343`). Both are covered by `Ruling: Task 17`.
- ✅ Step 6 reproduced: lint-rules 22 pass, 0 fail; `lint: clean`; `hook-shape: 8 cases passed`.
- ⚠️ I did not run bats, `ci-local` or the Linux container. The report is the only evidence for those.
- ⚠️ Shellcheck coverage: I listed every `*.sh` and `*.bash` outside `.upstream` and fixtures. The line covers `hooks/lib/*.sh`, `hooks/guards/*.sh`, the four extensionless hooks, the four `scripts/kern-*`, `hook-shape.sh`, `run-bats` and `common.bash`. `ci-local` and `fetch-upstream` stay on the older line. Nothing is uncovered, but a new `tests/helpers/*.bash` or `scripts/kern-*` is only caught if someone edits the line (see Minor).

### Strengths

- Rule 7 runs the real hooks in an isolated HOME and `CLAUDE_PLUGIN_DATA`, so it measures actual output rather than file sizes.
- The plugin root is normalised before measuring, which stops the CI checkout path from skewing the size.
- Rule 13 checks both directions: key read but not in the table, and table row naming a hook as reader but never read.
- CI order is sound. `run-bats` is used in both ci.yml and ci-local, and its bare-`[[ ]]` guard runs on Linux too. The 102 s hook suite is well inside GitHub limits. `-S warning` keeps SC2016 out of the exit code.

### Issues

**Critical:** none.

**Important**

1. `lint-rules.mjs:63-65`, rule 7 passes when `session-start` produces nothing. `hook()` returns `stdout || ''` and ignores the exit status, so a crashing or empty hook gives `kernel.length` 0, which is under both limits. Rule 7 then reports clean for a kernel it never measured. The subagent branch is safe because `JSON.parse('')` throws. Fix: if the session-start output is empty or the exit status is non-zero, push `err(7, 'hooks/session-start', 'no output')`. Plan-mandated. Add a test with a `hooks/session-start` that does `exit 1`.
2. `lint-rules.mjs:109-111`, rules 7 and 15 can be silently weakened together. Rule 7 guards the fixture copy with `existsSync`, and rule 15 checks only `expect.txt`. Deleting `long-settings/kern.local.yml` leaves 15 green, and rule 7 then measures the no-settings kernel (smaller), so it passes with the budget test gutted. Fix: in rule 15, also require `kern.local.yml` or `kern.yml` for every case except `no-settings`. Plan-mandated.

**Minor**

3. `lint-rules.mjs:64`, "Main worktree:" (`render.sh:65`) is not normalised. The repo sits under `os.tmpdir()`, so the size differs by roughly 35 to 50 chars between macOS and Linux CI. The margins are large (3,566 against the 4,000 warning, 5,242 against 9,000), so no change is needed now. If the margin shrinks, replace `repo` in `norm` with a fixed 50-char root. Same fix covers the 52-versus-50 root note. Plan-mandated.
4. `lint-rules.mjs:92-93`, rule 13 matches only literal or double-quoted key forms. A single-quoted key (`settings_get 'x'`) or `policy_for "$action"` is missed silently. No current reader uses either form, so this is a latent hole. Optional fix: widen to `["']?`, and flag any `policy_for` whose argument starts with `$`.
5. `hook-shape.sh:100-101`, the header says 1,200 but the check is 1,400 (raw JSON includes envelope). The `prompt-submit` output goes to `/dev/null` and is not JSON-checked, although the header promises it. Plan-mandated. Fix the comment to say 1,400, or add `json_ok` on prompt-submit output.
6. `lint-rules.mjs:56,74`, no try/finally around the tmpdir. A throw leaks a temp dir. Brief code. Low impact.
7. `ci.yml:18` and `ci-local:32`, the shellcheck file list is hand-enumerated, so new scripts are not checked until someone remembers to edit it. A glob such as `scripts/kern-*` and `tests/helpers/*.bash` would be safer. Plan-mandated.

### Implementer concerns, which to fix now

- Rule 7 normalised root (52 versus 50) and the "Main worktree:" OS difference: not now. Margins are ample (see 3).
- Header says 1,200, check is 1,400: fix the comment (5), trivial.
- tmpdir leak on throw: skip.
- arm64/apt versus the x64 runner: no action. The container run shows no Linux-only failure, and CI will be the real check.

### Assessment

**Task quality:** Needs fixes. Issues 1 and 2 let rule 7 pass a kernel it never measured or measured with the budget fixture removed. Both are short fixes with a test each. The rest is clean.
