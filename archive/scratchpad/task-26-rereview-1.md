# Task 26 re-review, fix round 1 (93b644e..be6ae75)

Verdict: NEEDS-FIXES (one Important, three Minor; all small). No Critical.

## 1. Status of the earlier findings
- I1 ADDRESSED. scripts/lib/claude-run.mjs:70,77 (`--max-turns` default 12, `--max-budget-usd` 3); scripts/exec-eval.mjs:36 sets 30 per case. Worst case is still 6 x $3 plus overshoot.
- I2 ADDRESSED. claude-run.mjs:93-104 `runProblem`, used at exec-eval.mjs:49-50. Matrix in section 2.
- I3 PARTIAL, as ruled. Env allowlist (claude-run.mjs:18-25) and strict cwd check (claude-run.mjs:72-75) work. Bash is still bare and unrestricted, which the ruling accepts and the controller must tell the user. New leak in the allowlist: N1.
- I4 ADDRESSED. exec-grade.mjs:60-66 (stagesAll), :102-106 (decoy state check), cases.json:2-4, fixtures README.md. See section 4.
- I5 ADDRESSED. evals/exec/bin/gh:4-12,21-22; exec-grade.mjs:65 (PR7). See section 5.
- M1 grader throw aborts run: ADDRESSED, exec-eval.mjs:53-54 (see section 6; grader error is INVALID, arguably should be FAIL, nit).
- M2 snapshot overwrite: PARTIAL. exec-eval.mjs:64-65 skips the snapshot on `--case`, but that branch also loses the exit code (N2).
- M3 `2>&1`: ADDRESSED. exec-grade.mjs:12-34. Checked: `2>&1`, `>/dev/null 2>&1`, `> f`, `2> f`, `&> f`, quoted `"a > b"` kept, `--json a>b` kept; `stubMissed` on a `2>&1` call now returns [].
- M4 first-create only: ADDRESSED, exec-grade.mjs:123-125 (`every`).
- M5 split regex: PARTIAL. `proposesSplit` (exec-grade.mjs:67-68) rejects "I will not split this", "no need to split". Residual: see N3.
- M6 relative `.kern/tmp`: ADDRESSED, exec-grade.mjs:102. `git commit -F .kern/tmp/commit-msg` now passes.
- M7 bats `decide`: ADDRESSED, ship-commands.bats:32-36 prints `crash:<status>`.
- M8 ci-local shellcheck: ADDRESSED, scripts/ci-local:13.

## 2. Fake-claude matrix (runClaude + runProblem; the case runner's decision is exactly runProblem plus the catch at exec-eval.mjs:39-44)
I did not run exec-eval itself (hard limit); the matrix drives the same functions.
- nothing, exit 0: INVALID "claude printed no events"
- garbage lines, exit 0: INVALID "2 line(s) of stdout were not JSON"
- result subtype error_max_turns, is_error true, exit 0: INVALID
- result subtype error_max_budget_usd, is_error false, exit 0: INVALID
- result subtype success but is_error true: INVALID
- result with no subtype: INVALID
- assistant event only, no result: INVALID "no result event: the run was cut off"
- good result then a garbage line: INVALID (stricter than needed; acceptable)
- good result but exit 1: INVALID
- exit 1: INVALID
- exit 127, exit 126: FATAL (run stops)
- SIGKILL: INVALID, non-fatal
- hang past timeout (1.5 s): INVALID, non-fatal
- good: assistant text + result success: GRADEABLE (the only one)

## 3. I3
Env the child receives, parent exporting AWS_SECRET_ACCESS_KEY, GITHUB_TOKEN, GH_TOKEN, NPM_TOKEN, ANTHROPIC_API_KEY, CLAUDE_CODE_OAUTH_TOKEN, CLAUDE_CONFIG_DIR, HTTPS_PROXY, and running inside this Claude Code session:
`ANTHROPIC_API_KEY CLAUDE_CODE_BRIDGE_SESSION_ID CLAUDE_CODE_CHILD_SESSION CLAUDE_CODE_ENTRYPOINT CLAUDE_CODE_EXECPATH CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS CLAUDE_CODE_MAX_OUTPUT_TOKENS CLAUDE_CODE_MESSAGING_SOCKET CLAUDE_CODE_MESSAGING_TOKEN CLAUDE_CODE_OAUTH_TOKEN CLAUDE_CODE_SESSION_ATTENDED CLAUDE_CODE_SESSION_ID CLAUDE_CODE_VERSION ENVOUT HOME LANG LC_CTYPE LOGNAME PATH PWD SHELL SHLVL TERM TMPDIR USER _`
- AWS_SECRET_ACCESS_KEY, GITHUB_TOKEN, GH_TOKEN, NPM_TOKEN: not passed. Good.
- Auth on macOS: `claude auth status --text` run with exactly `childEnv(process.env)` still reports "Login method: Claude Team account", so HOME/USER/LOGNAME carry the keychain/config login. No auth gap for this user's setup. Not carried: CLAUDE_CONFIG_DIR (does not match `^CLAUDE_CODE_`), HTTPS_PROXY, NODE_EXTRA_CA_CERTS, AWS_* for Bedrock. Irrelevant to this machine; the run fails loudly (INVALID) rather than silently on a user who needs them.
- cwd check, strict: refused tmpdir itself, $HOME, the kern repo, a symlink under tmpdir pointing to $HOME, a symlink to `/`, a `..` chain escaping to /private/var/folders, a nonexistent path, and a sibling-prefix path (`<tmp>-evil`). Allowed: a real dir under tmpdir and `x/../x` inside it. Realpath is taken before the prefix test with `root + sep`, so symlinks and `..` cannot pass. The check covers cwd only: Bash can still `cd` out (accepted).

N1 (Important). `^CLAUDE_CODE_` passes the parent session's own plumbing when exec-eval is started from inside Claude Code (its normal use): CLAUDE_CODE_MESSAGING_TOKEN and _SOCKET, CLAUDE_CODE_SESSION_ID, CLAUDE_CODE_BRIDGE_SESSION_ID, CLAUDE_CODE_CHILD_SESSION, CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS, CLAUDE_CODE_ENTRYPOINT, CLAUDE_CODE_EXECPATH. The messaging token is a credential for this live session's socket, readable by the model through `env` in a run with unrestricted Bash; the session id and CHILD_SESSION/AGENT_TEAMS can also make the eval child behave as a child of the parent session, which skews what is being measured. Fix, claude-run.mjs:18: replace `^CLAUDE_CODE_` with the names an auth/config setup needs (`CLAUDE_CODE_OAUTH_TOKEN`, `CLAUDE_CODE_USE_*`, `CLAUDE_CODE_API_KEY_HELPER*`) or deny `MESSAGING|SESSION|BRIDGE|CHILD_SESSION|EXPERIMENTAL|ENTRYPOINT|EXECPATH`; add a test that a parent holding `CLAUDE_CODE_MESSAGING_TOKEN` does not pass it. (ANTHROPIC_API_KEY, if the user has one, is exposed to the model by design.)

## 4. I4 grader inputs (git state emulated: naive commands also change the outcome)
- correct (`git -C w add -- src/sum.js`, `git -C w commit -F <.kern/tmp>`): PASS; same with `2>&1`: PASS; relative -F: PASS
- `commit -a -F`: FAIL (command check); with outcome README committed: FAIL (name-only and decoy checks)
- `commit -aF <msg>`: FAIL
- `add -u`, `add --update`, `add *`, `add -A`, `add .`, `commit --all`: FAIL each by the command check; with only the outcome (no command visible): FAIL by name-only and decoy checks
- `add src/`: PASS (correct; stages only src)
- `commit -m "fix a" -F` and `commit --amend -F`: PASS (the `-a` regex does not misfire on message text or `--amend`)
Decoys: setup appends to README.md and writes notes.txt, so `M README.md` and `?? notes.txt` must remain; the check trims leading space (git() trims the first line).

## 5. I5
- Stub cwd: it runs `git remote get-url origin` in the caller's cwd, `|| origin=` so a missing origin never aborts at the top. Only `pr create` and `pr view` exit 1 without an origin (clear stderr). The hooks call only `gh pr list ... --jq` via `cd "$CWD" && gh` (g02-pr.sh:336), which never builds a URL, so a hook call cannot hit the exit-1 path and dedup is unaffected. A model that `cd`s outside the repo and runs `gh pr create` gets exit 1: a visible failure, not a silent pass.
- Matchers: stub prints `file://<dir>.origin/pull/<n>` (dir ends `invoice-app`). PR7 `/\.origin\/pull\/7(\D|$)/` accepts the exact string, with trailing period, in `<>` and in markdown; rejects `/pull/70`, `/pull/8` and the old `https://example.invalid/pr/7`. `pr create` prints `file://.../pull/8` plus newline (verified from the script: printf then echo).

## 6. Untested paths, by reading
- Grader exception (exec-eval.mjs:53-54): correct. The throw is caught per case, the case becomes INVALID with "grader error: ...", the loop continues, the finally block still removes the workspace. Nit: a git failure after the model deleted the branch is a FAIL of the skill, not an invalid harness; INVALID hides it. Acceptable.
- Per-case snapshot skip (exec-eval.mjs:64-65): the skip is right, but N2 below.

N2 (Important). `--case X` run always exits 0. The only `process.exit(... every pass ? 0 : 1)` is inside `if (!dryRun && !only)` (exec-eval.mjs:65-70). A single-case run with FAIL or INVALID returns 0, so a wrapper or CI step reads it as a pass. This is the D6 shape (a failure read as success), introduced by the snapshot-skip change. Fix: compute `const ok = results.length > 0 && results.every(r => r.pass)` and `process.exit(ok ? 0 : 1)` for any non-dry run, after the snapshot branch. Add a test that spawns exec-eval with a fake `claude` first on PATH... which the hard limit forbids here, so test the exit decision as a small exported function instead.

## 7. Minor
N3. `proposesSplit` residuals (measured): "I did not propose a split" passes (negation list lacks "not propose"); "Consider splitting into smaller PRs" and "Nine files: split or keep?" fail a plausible correct reply. The skill says "propose a split", so "propose/suggest/recommend ... split" is the likely wording and the heuristic is acceptable; state in the grader comment that it is a heuristic (it is).
N4. `--case` as the last argument (no value) makes `only` undefined, which `!only` treats as "all cases": a paid full run. exec-eval.mjs:18. Throw when the value is missing.
N5. A good result line followed by one garbage line makes the case INVALID (claude-run.mjs:98). Stricter than needed but safe; fine.

## 8. Gates
- `node --test 'tests/**/*.test.mjs'`: 164 pass, 0 fail
- `tests/run-bats tests/hooks/ship-commands.bats`: 9 ok
- `node scripts/exec-eval.mjs --dry-run`: 6 lines, rc 0
- `shellcheck evals/exec/bin/gh`: rc 0
- `node scripts/lint-skills.mjs`: "lint: clean"
- Also: `claude auth status --text` with the filtered env (local, no model call); scratch drivers `t26/m2.mjs`, `t26/tmpchk.mjs`, `t26/g2.mjs`, fake claude scripts `t26/fk_*`. Never ran exec-eval without --dry-run, never ran claude with a prompt. Repo untouched.

## Paid-run safety
Not yet: fix N1 (the live session's messaging token reaches a model with unrestricted Bash) and N2 (a failing --case run exits 0), then it is safe to offer with the user told that Bash is unrestricted within their own rights.

Verdict: NEEDS-FIXES
