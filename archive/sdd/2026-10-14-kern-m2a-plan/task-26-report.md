STATUS: DONE. Steps 1-7, 9, 10 complete. Step 8 NOT run (no `claude -p` call made; user decides).

SHA: 93b644e  M2: add execution evals for commit and finish-branch (no evals/snapshots)

Node tests
- failing (exec-grade.mjs absent): `Cannot find module .../scripts/lib/exec-grade.mjs`, pass 0 fail 1
- passing: tests/exec-eval.test.mjs 14 pass 0 fail; full `node --test 'tests/**/*.test.mjs'`: 156 pass 0 fail

Bats (tests/hooks/ship-commands.bats): 9 ok, passed before any guard change. No skill-prescribed shape is denied.
Lease push deny reason: "kern G1: lease push under autopilot needs rebase.push: autopilot".

Dry run: six lines, one per case (commit-work-file, finish-menu-first, finish-split-nine-files, finish-autopilot-draft, finish-pr-at-head, finish-pr-older-head).
Gates: lint-skills "lint: clean"; `claude plugin validate .` passed; ci-local last line `ci-local: all steps passed` (read from the log file).

Deviations
1. `--max-turns` is not in `claude --help` (2.1.300) and cannot be checked without a model call. runClaude takes `maxBudgetUsd` (default 3, `--max-budget-usd`, documented, print-only) instead of maxTurns.
2. runClaude throws ClaudeRunError: fatal for missing binary, 126, 127, spawn error; non-fatal for timeout or signal. Non-zero exit is returned, and exec-eval marks the case INVALID/failed. Fatal errors stop the run; non-fatal ones fail only that case.
3. workspace() and the runner's git helper use timeouts and throw on failure (plan swallowed errors with catch returning '').
4. Graders: new `gitCalls` (shellSegments-based, drops `-C <p>`/`-c k=v`). commit-work-file checks -F path contains `/.kern/tmp/` via segments (also --file), rejects -A/--all/. in add (any form). Push checks in the finish graders use it too.
5. gh stub: unknown calls print to stderr and exit 1 (plan exited 0). Shellcheck clean.
6. Removed plan's source/personal-name comments (caveman/Apache, addy) per the no-source-tags rule.
7. Extra tests: -C forms for commit and push graders, runClaude failure handling via a stand-in `claude` script on PATH, gh stub behaviour.
8. Bats: `git -C $W add -- x.txt` pinned as `none` (decision_of supports it cleanly). Plain `git commit -F` kept (allowed).
9. Helpers checked: make_repo, kern_env, kern_root, set_autopilot, run_guard, bash_payload, decision_of exist as the plan uses them. Flags in ISOLATION and PERMISSIONS and `--input-format stream-json` exist in --help.

NOTICED BUT NOT TOUCHING
- scripts/ci-local shellchecks no evals/exec/bin/gh (I ran shellcheck on it by hand).
- ci-local does not shellcheck *.bats.
- lint-rules.mjs matches long dashes by regex literal (pre-existing, expected).

## Fix round 1

SHA: be6ae75  M2: exec-eval counts only a successful run and keeps credentials out
Gates: node tests 164/164; ship-commands.bats 9/9; dry run 6 lines; lint clean; shellcheck gh clean; ci-local last line `ci-local: all steps passed` (ci-local-t26b.log).

- I1: runClaude passes `--max-turns` (default 12; exec-eval uses 30) and `--max-budget-usd` (3).
- I2: `runProblem(run)`: non-zero exit, non-JSON lines, no events, no result event, or a result that is not `subtype: success` or has `is_error` makes the case INVALID, never graded. Tested with fake claude scripts that exit 0.
- I3: `childEnv` allowlist (PATH, HOME, USER, LOGNAME, SHELL, TMPDIR, LANG, LC_*, TERM, ANTHROPIC_*, CLAUDE_CODE_*, plus the caller's extras: stub PATH, KERN_EXEC_*, GH_TOKEN=invalid, GH_HOST). The runner refuses a cwd that is not strictly under realpath(os.tmpdir()). Both tested. Bash stays unrestricted.
- I4: fixture README.md; the commit case adds untracked notes.txt and a README.md edit. Grader needs name-only diff == src/sum.js and both decoys still uncommitted; also rejects add -u/--update/*, commit -a/-am. Tests for commit -a, add -u, add * and the outcome check.
- I5: stub URLs are `file://<git remote get-url origin>/pull/<n>`, so the URL visibly contains the origin path the skill compares against and is a valid URL. Graders match `.origin/pull/7`. The stub exits 1 without an origin rather than inventing a URL.
- Minor: grader exceptions mark the case INVALID and the run continues; `--case` writes no snapshot; redirections are dropped in shellSegments (quoted `>` kept); every `pr create` is checked; split needs a proposal (negations rejected, heuristic); relative `.kern/tmp` accepted; bats `decide` prints `crash:<status>` on a non-zero guard exit; ci-local shellchecks evals/exec/bin/gh.
- Not unit-tested: the exec-eval grader-exception path and the per-case snapshot skip (both in the script's main flow).

## Fix round 2

SHA: aa74dc5
Gates: node tests 169/169, ship-commands.bats 9/9, dry run 6 lines, lint clean. ci-local skipped (no shell file or ci-local touched).

- N1: childEnv now takes exact names only (PATH, HOME, USER, LOGNAME, SHELL, TMPDIR, LANG, TERM, ANTHROPIC_API_KEY/AUTH_TOKEN/BASE_URL, CLAUDE_CODE_OAUTH_TOKEN/USE_BEDROCK/USE_VERTEX, CLAUDE_CONFIG_DIR) plus the LC_ and KERN_EXEC_ prefixes; the caller's extras (stub PATH, GH_TOKEN=invalid, GH_HOST) go on top. Test sets every session name (MESSAGING_TOKEN/SOCKET, SESSION_ID, BRIDGE_SESSION_ID, CHILD_SESSION, EXPERIMENTAL_AGENT_TEAMS, ENTRYPOINT, EXECPATH and prefix lookalikes) and asserts each is absent and the key set is exactly the wanted list.
  `claude auth status --text` with exactly childEnv(process.env) (keys: HOME LANG LC_CTYPE LOGNAME PATH SHELL TERM TMPDIR USER): exit 0, "Login method: Claude Team account". Login still found; the list was not widened.
- N2: control flow moved to scripts/lib/exec-run.mjs (parseArgs, exitCode, runEval); exec-eval.mjs calls process.exit(runEval(...)) once. Exit is 0 only when at least one case ran and all that ran passed, for full and --case runs. Tested with an injected runCase (no claude): full pass/fail, --case pass/fail, empty, invalid; snapshot only on a full run.
- N4: --case with no value, a flag as its value, an unknown id or any unknown argument is a usage error, exit 2, nothing runs. Tested in-process and by spawning the script.
- N3: split grader rejects negations ("did not propose a split", "no split needed", "no need to split", "will not split", "never split") and accepts "propose splitting", "Split into two PRs?", "Consider splitting into smaller PRs", "I recommend a split". Still a heuristic, said in its comment.
