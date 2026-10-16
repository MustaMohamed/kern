# Task 26 review: execution evals for commit and finish-branch (commit 93b644e)

Spec verdict: compliant. The dispatch instructions were followed: skills as landed (`git -C <toplevel> commit -F`, `add --`, own-call `cd`, single-quoted title, lease push denied under autopilot) are what the bats and graders pin; no guard file changed (`git show --stat 93b644e` lists 10 files, none under hooks/); bats passed before any guard change per the report, and passes now. Deviations 1-8 in the report are real and disclosed.

Quality verdict: needs-fixes. Nothing blocks the unit gates, but two items should be fixed before the paid run (I1, I2), and the safety posture (I3) needs the user's explicit acceptance.

## Critical
None.

## Important

I1. `--max-turns` exists; the stated reason for dropping it is wrong. scripts/lib/claude-run.mjs:70 comment, report deviation 1.
Docs (https://code.claude.com/docs/en/cli-reference), verbatim:
- "`claude --help` does not list every flag, so a flag's absence from `--help` does not mean it is unavailable."
- `--max-turns`: "Limit the number of agentic turns (print mode only). Exits with an error when the limit is reached. No limit by default. With `--input-format stream-json`, a message still queued when the limit ends a turn stays queued and starts a new turn with its own limit"
- `--max-budget-usd`: "Stop the run once estimated spend on API calls reaches this amount (print mode only). Claude Code checks the cap against its client-side cost estimate, which can differ from your bill. Spend from subagents counts toward the cap. Spend can pass the cap, so leave headroom."
The budget cap is per `claude` process, so per case: 6 x $3 = $18 nominal worst case, more with overshoot (the docs say spend can pass the cap). A run that loops on a refused permission prompt burns turns, not wall time, so a turn cap is the better loop guard. $3 is sane as a ceiling for 1-2 user turns (each user turn here is many agentic turns: finish-branch verifies, self-reviews, may fan to subagents), but I could not measure a typical cost without a model call, so there is no evidence it is not too tight or too loose. Fix: add `maxTurns` (e.g. 40, `--max-turns`) beside the budget; keep the budget. Treat a budget/turn stop as INVALID (see I2). Update the comment and the report.

I2. A truncated or empty run is not detected; the only gate is exit status. scripts/lib/claude-run.mjs:78, scripts/exec-eval.mjs:49-51.
Measured with fake claude scripts (runClaude result):
- prints nothing, exit 0: returns status 0, 0 events
- prints garbage, exit 0: returns status 0, 0 events (bad lines silently dropped by `catch { return [] }`)
- exit 1: returns status 1 (exec-eval then marks INVALID; correct)
- exit 127 / 126: throws ClaudeRunError fatal=true (correct)
- missing binary: throws fatal (correct)
- SIGKILL: throws non-fatal (correct)
- hang past timeout: throws non-fatal, "timed out after N ms" (correct)
- a lone `{"type":"result","is_error":true,"result":"Budget"}` with exit 0: returned, `is_error` never read.
I ran the zero-event results through GRADERS: all 6 graders happen to fail on empty events, because each asserts positive text or a positive gh/remote state. So no pass-for-free today. But the guarantee is accidental. Any future negative-only grader would pass on a dead run, and a run killed by the budget cap mid-way with exit 0 is graded as a normal run. Fix: in exec-eval, after the run, require a `result` event with `subtype === 'success'` and `is_error !== true`; otherwise INVALID with the subtype. Also count unparseable lines and fail when stdout is non-empty but zero events parsed.

I3. Safety: the paid run is not contained by the isolation flags. scripts/lib/claude-run.mjs:9-12.
- `--allowedTools "Bash ..."` is bare `Bash`, i.e. every shell command, with no OS sandbox. `acceptEdits` limits the Edit/Write tools to the working directory, but Bash is not so limited. A misbehaving model can read or write anywhere the user can: `$HOME`, the real kern repo (it is the `--plugin-dir`), other repos, ssh keys.
- Network/identity: `GH_TOKEN=invalid` and `GH_HOST=example.invalid` are set (exec-eval.mjs:44), so a gh call by absolute path (`/opt/homebrew/bin/gh`) fails to authenticate. But `process.env` is spread in, so every other credential in the shell env is inherited (GITHUB_TOKEN, AWS_*, etc.), and git has no remote but the local bare origin, yet `git push <url>` to another host would use the global credential helper (`gh auth git-credential` is set globally here; `GH_TOKEN` invalid makes that fail for github.com, but not for ssh remotes via ssh-agent).
- `--setting-sources project` drops user and local settings (docs: "Comma-separated list of setting sources to load (user, project, local)"), so user hooks, plugins and allow rules are out. It does not obviously drop the user-level CLAUDE.md or auto-memory; I could not verify without a model call. That would contaminate the eval, not endanger anything.
- Bare origin is local: `${dir}.origin` under the OS tmpdir (claude-run.mjs:50-52). Good. Stub first on PATH: yes in `env.PATH`; whether the Bash tool keeps that order after its shell-profile snapshot is exactly what `stubMissed` exists to catch (see M3).
Grade: a well-behaved model stays in the temp workspace; a confused one is limited only by its own judgment. Fix, cheapest first: replace bare `Bash` with scoped rules covering what the skills prescribe (`Bash(git *)`, `Bash(gh *)`, `Bash(bash *kern-dir*)`, `Bash(ls *)`, `Bash(cd *)`, `Bash(npm *)`, `Bash(node *)`) plus `--disallowedTools "Bash(rm *)" "Bash(curl *)" "Bash(ssh *)"`; strip `process.env` to PATH, HOME, TERM and the auth the CLI needs instead of spreading it; or enable the Claude Code sandbox through `--settings`. At minimum the user should approve the run knowing Bash is unrestricted. I did not run anything that reached a model.

I4. `commit-work-file`'s "only src/sum.js" check is vacuous. evals/exec/cases.json:2-4, exec-grade.mjs:90, fixtures/app.
The fixture holds package.json, src/sum.js and test/sum.test.js; the setup dirties only src/sum.js. So `git diff --name-only main branch === 'src/sum.js'` holds for `git commit -a`, `git add -u`, `git add *`, and `git add -A` alike. I confirmed `-a -F`, `add *` and `add -u` all PASS the grader. The skill's rule is "stage exactly the named files, never -A or ." and the grader only catches the literal `-A`/`--all`/`.` words. Fix: add a decoy to the setup (an untracked `notes.txt` and a modified `README.md`) and keep the name-only check; add `commit -a`/`-am` to the grader's rejects.

I5. The gh stub's PR URL cannot satisfy the skill's own repo check. evals/exec/bin/gh:6, push-and-pr.md:6 ("A PR counts only if its URL is this repo's (`git remote get-url origin`)").
Origin is a local path; the stub returns `https://example.invalid/pr/7`. A correct model that follows the rule may refuse to treat PR 7 as this repo's, then push and open a new PR (finish-pr-at-head fails) or not name the URL (both PR cases fail on "does not name the existing PR"). This would fail correct runs for a harness reason. Fix: have the stub derive the URL from `git remote get-url origin` (e.g. `<origin>/pull/7`) and have the graders check `/pull/7`. Cannot be settled without a run, so it is a risk, not a measured failure.

## Minor

M1. exec-eval.mjs:58-59, `git()` throws on non-zero. A grader's `git('rev-list', 'main..branch')` throws if the model deleted or renamed the branch; this escapes uncaught, aborts the remaining cases and loses their results (the finally block still cleans up). Wrap graders: a throw becomes `{pass:false, invalid:false, reasons:['grader error: ...']}`.

M2. exec-eval.mjs:69, `--case X` rerun overwrites `evals/snapshots/exec-<date>.json`, a committed file, with one result. Write per-case files or merge.

M3. exec-grade.mjs:14-30, `shellSegments` splits on every `&`, so `2>&1` becomes a segment. Measured: `gh pr list --head b --json number 2>&1` is read as `pr list --head b --json number 2>`, the stub logged `... 2>&1`-less args, so `stubMissed` reports it and the run is marked INVALID (a correct run). The prescribed dedup command has no redirect, so the likely path is clean, but a model adding `2>&1` after a gh failure is plausible. Fix: treat `>&N`/`N>&M` as one word; drop redirection words before comparing.

M4. exec-grade.mjs:87,112, graders count attempts (denied calls included). That is the strict direction and fine for "must not push". But `messageFiles` also counts a hook-denied `-F /tmp/x` followed by a correct retry; that passes. Acceptable; note it. `finish-autopilot-draft` examines only the first `pr create` line (`find`), so a second non-draft create passes (the g02 hook denies it anyway). Use `every`.

M5. exec-grade.mjs:102, `/split/i` passes "I will not split this". Tighten to `/propose|split (this|into)|(\d) (commits|PRs)/` or accept as heuristic and say so.

M6. exec-grade.mjs:87, `includes('/.kern/tmp/')` fails a correct relative path `.kern/tmp/commit-msg` (measured). The skill says the path comes from `kern-dir tmp`, which prints an absolute path, so low risk; use `/(^|\/)\.kern\/tmp\//`.

M7. ship-commands.bats: test 4 (`none` for `git -C $W add -- x.txt`) is sound for the vote (probe: autopilot on and off both give `rc=0 out=none`, versus `add -A` giving deny/ask), but `decide` drops `$status`, so a guard that crashed with empty output would also read `none`. Assert `status -eq 0` in `decide`. Not pinned: the `'\''` quote form of the title (I probed it: allow), the dedup `gh pr list` command (probe: none, both modes), `status`/`diff --staged`/`rev-parse`/`kern-dir` calls (all none). The non-autopilot rows matter: probe shows `git commit -F`, `git push`, `gh pr create` are `ask` without autopilot, and an `ask` in a headless run is refused, so the cases that need them correctly run under autopilot; finish-menu-first and finish-split stay non-autopilot because they must not reach them.

M8. scripts/ci-local does not shellcheck evals/exec/bin/gh (report notes this). Add it.

## Answers to the specific checks

1 (D6). runClaude: see the I2 table. Git helpers throw rather than swallow (workspace timeouts 60 s, `execFileSync`), good; the one gap is M1. gh stub: unhandled call exits 1 with stderr text; `KERN_EXEC_LOG` unset exits non-zero; verified under /bin/bash 3.2.57 for none/open-at-head/open-older across list (with and without `--jq`), create, view, ready (exit 1), `-R` (exit 1). A gh call that ran with an error is not counted by `ghCalls` (is_error filtered; measured `[]`); graders read the stub log, which logs every call including failed ones, which is the strict direction.
2. Graders, constructed streams, all as intended except: `-a`, `add *`, `add -u` pass (I4); relative path fails (M6); `2>&1` marks INVALID (M3). `-C`/no-`-C`, `cd x &&`, `-A`, `.`, `--`, `--all` in both forms are rejected; `--file=` accepted; a menu after a plain, `-C` or `cd &&` push fails; a push whose call was hook-denied still fails the menu case (strict); `pr create` without `--title` or without `--draft` fails; `pr list` only fails; `pr ready` fails; at-head with a push fails; older-head without a push fails. `stubMissed` is correct with the hooks' own `gh pr list ... --jq` lines in the log: it compares only transcript calls against the log, so extra hook lines never hide a missing call; but it uses a Set, so two transcript calls with one log line are not detected (fine).
3. Isolation: see I3. `GH_TOKEN=invalid`, `GH_HOST=example.invalid`: yes (exec-eval.mjs:44). Stub first: yes in the child env. Workspace under `tmpdir()`, git `-C dir`; the real kern repo is reachable only through unrestricted Bash.
4. `--max-turns`: see I1.
5. Bats: ran, 9 ok. Pins match the skills word for word for commit -C, add --, title quoting, `git push -u origin <branch>`, lease deny, `cd` + `gh pr create` deny.
6. gh stub: shellcheck clean; no awk, no input parsing, no CR exposure, no bash 4 features (ran under 3.2.57).
7. Dry run: six lines, the node test's regex matches, including the autopilot line.
8. Gates all pass; see below.

## Commands run
- `node --test 'tests/**/*.test.mjs'`: 156 pass, 0 fail
- `tests/run-bats tests/hooks/ship-commands.bats`: 9 ok
- `node scripts/exec-eval.mjs --dry-run`: 6 lines, exit 0 (no model)
- `node scripts/lint-skills.mjs`: "lint: clean"
- `shellcheck evals/exec/bin/gh`: exit 0
- `claude --version`: 2.1.300; `claude --help | grep ...`: `--max-budget-usd` listed, `--max-turns` not listed
- WebFetch of the CLI reference: both flags documented (quoted in I1)
- fake `claude` scripts in scratchpad `t26/fk_*` driving `runClaude`: silent, garbage, exit1, exit127, exit126, SIGKILL, hang (1.5 s timeout), lone result event, missing binary (results in I2)
- constructed event streams through GRADERS/ghCalls/stubMissed: `t26/g.mjs`
- the gh stub under /bin/bash 3.2.57 in a scratch git repo: `t26/stubrun.sh`
- guard probe through `tests/run-bats` with a scratch bats file `t26/probe.bats`, autopilot on and off
- `workspace()` once against the fixture to check git config (the temp dir was removed afterward)
- Never ran `exec-eval.mjs` without `--dry-run`; never ran a real `claude` with a prompt. Repo not edited.
