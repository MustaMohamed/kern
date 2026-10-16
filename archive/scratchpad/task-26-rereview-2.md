# Task 26 re-review, fix round 2 (be6ae75..aa74dc5)

Verdict: APPROVED (no Critical, no Important; three Minor).

## 1. Status
- N1 ADDRESSED. scripts/lib/claude-run.mjs:16-30: exact names plus prefixes `LC_` and `KERN_EXEC_` only.
- N2 ADDRESSED. scripts/lib/exec-run.mjs:24-25 (`exitCode`), :29-43 (`runEval`: one return for every non-dry run, snapshot only when not `only`); scripts/exec-eval.mjs:73-76.
- N4 ADDRESSED. scripts/lib/exec-run.mjs:9-22 (`parseArgs`), scripts/exec-eval.mjs:22-27 (exit 2 before anything runs).
- N3 PARTIAL, acceptable as a heuristic. scripts/lib/exec-grade.mjs:68-71. Negations are rejected, "consider ... split" and bare "splitting" are accepted. One new false-fail (M1).

## 2. N1 env check
Parent exported: CLAUDE_CODE_MESSAGING_TOKEN, _SOCKET, SESSION_ID, BRIDGE_SESSION_ID, CHILD_SESSION, EXPERIMENTAL_AGENT_TEAMS, ENTRYPOINT, EXECPATH, VERSION, SESSION_ATTENDED, MAX_OUTPUT_TOKENS, CLAUDECODE, CLAUDE_PID, CLAUDE_EFFORT, decoys CLAUDE_X and ANTHROPIC_FOO, AWS_SECRET_ACCESS_KEY, GITHUB_TOKEN, GH_TOKEN, SSH_AUTH_SOCK, KERN_OTHER, and the allowed names.
`childEnv` result: ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN ANTHROPIC_BASE_URL CLAUDE_CODE_OAUTH_TOKEN CLAUDE_CODE_USE_BEDROCK CLAUDE_CODE_USE_VERTEX CLAUDE_CONFIG_DIR HOME KERN_EXEC_FOO KERN_EXEC_LOG LANG LC_ALL LC_X LOGNAME PATH SHELL TERM TMPDIR USER.
None of the session names, decoys, AWS/GITHUB/GH tokens, SSH_AUTH_SOCK or KERN_OTHER reached the child. `claude auth status --text` under only HOME, USER, LOGNAME, SHELL, TMPDIR, LANG, TERM, PATH still reports "Claude Team account" with the login. Note: the child still holds any ANTHROPIC_API_KEY/OAUTH token the user exported, readable by the model; that is by design for those who authenticate that way.

## 3. N2 / N4 exit codes
Driven by running scripts/exec-eval.mjs from a scratch copy of the repo (the repo's evals/snapshots untouched; `git status` clean) with `env -i`, PATH holding only a fake `claude`, a node copy, /usr/bin:/bin. The fake prints a menu result (menu), a success result with no menu (nomenu) or exits 1 (invalid), chosen via KERN_EXEC_FAKE. The real claude is not on that PATH; no model was reached.

| invocation | exit | snapshot written |
|---|---|---|
| `--case finish-menu-first` (PASS) | 0 | no |
| `--case finish-menu-first` (FAIL: no menu) | 1 | no |
| `--case finish-menu-first` (INVALID: claude exit 1) | 1 | no |
| full run (menu fake: 1 PASS, 5 FAIL) | 1 | yes |
| full run (all INVALID) | 1 | yes |
| `--case` (no value) | 2 | no, nothing ran |
| `--case --dry-run` | 2 | no |
| `--case nosuch` | 2 | no |
| `--bogus` | 2 | no |
| extra positional `extra` | 2 | no |
| `--case=finish-menu-first` | 2 | no |
| `--dry-run` | 0 | no |
| `--case finish-menu-first --dry-run` | 0 | no |
The all-pass full run cannot be produced with one fake claude; the exit computation is `exitCode`, covered by the new tests (169 pass).

## 4. Behaviour preserved by the move to exec-run.mjs
- Dry run: same six lines in the same order and format, no workspace created, exit 0.
- INVALID handling: non-fatal ClaudeRunError still returns `{pass:false, invalid:true, exit:null}`; fatal still propagates (uncaught: node exits 1, no snapshot, workspace cleaned by `finally`). runProblem precedes the stubMissed check, then the grader in try/catch, unchanged (exec-eval.mjs:47-59 is the old code moved verbatim).
- stubMissed wiring unchanged.
- A change: an unknown case id used to throw an Error; it is now a usage error with exit 2 and a case list. Intended.

## 5. Stop rule
Round 2 authored no defect in round 1's code that rises to Important. The only round-2-authored issue is M1, in the heuristic that round 1 had also touched, and it is a false-fail, not a false-pass.

## 6. Minor
M1. exec-grade.mjs:69, the negation `\b(not|never|...)\b[^.]*\bsplit` spans the whole sentence, so a correct reply "Nine files is not a small change, so I suggest splitting it into two PRs." is rejected (measured false). The earlier-ordering ones pass ("This change is not small: ... I propose a split." passes only because a period sits between). Limit the negation to a few words before "split" (`(not|never|won't|without|no need to)\s+(\w+\s+){0,2}split`). Low cost either way: a false fail makes the case FAIL visibly, not pass.
M2. A full run in which every case is INVALID still writes `evals/snapshots/exec-<date>.json`, replacing a same-day good snapshot (`writeSnapshot` in exec-eval.mjs:66-71). Skip the snapshot when any case is INVALID, or when none ran valid.
M3. `claudeVersion()` inside `writeSnapshot` throws after all cases ran if claude vanished, discarding results; call it once before the loop.

## 7. Gates
- `node --test 'tests/**/*.test.mjs'`: 169 pass, 0 fail
- `tests/run-bats tests/hooks/ship-commands.bats`: 9 ok
- `node scripts/exec-eval.mjs --dry-run`: 6 lines, exit 0
- also: `claude auth status --text` with the exact env (local, no model); scratch `t26/sp.mjs` for the split phrasing; scratch copy `t26/kcopy` plus fake `t26/fk_runner/claude`. Never ran exec-eval against a real claude, never ran `claude -p`. Repo untouched.

## Paid run
Safe to offer: the session credentials no longer reach the model and a failed or invalid case can no longer exit 0; tell the user that Bash is still unrestricted within their own rights and that the budget is up to 6 x $3 plus overshoot.

Verdict: APPROVED
