STATUS: DONE (all gates green; GNU date and mawk paths not run, see below)

SHA: 457dd6b (commit "M2: add recall-sessions", on main, base aa74dc5)

## Bats
Failing first (script absent): every test failed, exit 127 "Command not found".
Passing: `tests/run-bats tests/scripts/recall-sessions.bats` gave `1..16`, ok 1-16, no failures. (One interim run had 4 failures from my own bug: an empty-topic check that also fired when --topic was absent; fixed.)

## Other gates
- `shellcheck scripts/recall-sessions`: no output, exit 0.
- `node --test 'tests/**/*.test.mjs'`: 169 pass, 0 fail.
- `node scripts/lint-skills.mjs`: clean.
- wt_test_env sets HOME to $TMP/home, so tests never read the real ~/.claude (confirmed in tests/helpers/wt.bash).

## Deviations from the draft
1. No `find 2>/dev/null` and no `for ... done | while` pipelines. Each find runs as `x=$(find ...) || die`, and loops read from heredocs over captured variables, so failures reach `set -e`. Unreadable folder gives `recall-sessions: cannot read <dir>`, exit 1. Output is built in a variable and printed once at the end, so a failure prints nothing.
2. `date`, `wc`, `sort` failures and empty/non-numeric results die with a message; no blank fields.
3. Dates: file mtime uses `date -r FILE` (BSD and GNU). Epoch seconds to iso use a helper chosen once by probing `date -d @0`: GNU `-d @S`, else BSD `-r S`. The draft's try-one-then-the-other fallback could hide a real error.
4. No `stat`.
5. awk `field()` rewritten as a scanner that stops at the first unescaped quote. It unescapes `\"`, `\\`, `\/`; `\n \t \r` become a space (so output stays one tab-separated line); `\uXXXX` is left as typed. Trailing `\r` stripped per line.
6. Prompt times are formatted with `%.0f`, not `%d`.
7. `--topic ''` is a usage error (exit 2). `--days` longer than 6 digits is a usage error (avoids arithmetic overflow).
8. `wt_dir` result is captured once with a `die` check and reused.
9. Header documents: empty-is-truth for missing projects/history, the subdirectory-session limit, the awk/JSON limits, byte/ASCII-only caveats, exit codes.
10. Added bats cases: sibling `<slug>-old` folder never listed; prompt from `<REPO>-old` and `<REPO>/sub` excluded; worktree prompt included; `\"` before the topic; display ending in `\\`; CRLF line; old prompt outside window; missing ~/.claude gives empty exit 0; unreadable folder and unreadable history die (skipped as root); empty topic; outside a repo.
Output format unchanged from the brief's Produces line.

## Could not test
- GNU `date` (`-d @S`, `date -r FILE`): this machine is macOS. Reasoned from the GNU docs; the probe `date -d @0` fails here ("illegal option -- d"), which selects the BSD branch that the tests exercise. The GNU branch is untested.
- mawk and gawk: neither installed, Docker down. Only BSD awk 20200816 ran. The awk uses no intervals, no gensub, no locale ranges, only index/substr/match/tolower/ENVIRON/sub/printf. mawk 1.3.3 `%d` caps at 2^31; the script uses `%.0f`.
- bash 3.2: run-bats puts /bin/bash 3.2.57 first on PATH, so the tests did run on it.

## NOTICED BUT NOT TOUCHING
- `-mtime -N` counts 24h units; `--days 1` means under 24 hours, matching the draft.
- Prompt text is cut at 120 bytes, which can split a UTF-8 character (LC_ALL=C by design; stated in header).
- `kern_main_root` swallows git's stderr; not touched.
- wt-snap has no bats file named tests/scripts/wt-snap.bats (it is wt-snap-diff.bats); house style taken from the other scripts.

## Fix round 1
Commit: SHA below, amended once to add two tests (message "M2: recall-sessions takes worktrees from git and fails loudly on unreadable records").
Gates: bats 30 of 30 ok; shellcheck clean; node --test 169 pass.

- I1: leading zeros stripped from --days before arithmetic and find (`08`, `09` now decimal); bats case for `--days 08` and `09` with --topic.
- I2: HOME, ~/.claude and ~/.claude/projects must be readable when they exist (or are symlinks); history must be a readable regular file when it exists or is a symlink (dangling link dies). Missing stays empty, exit 0. Bats cases (skipped as root).
- I3/I4: worktrees come from `git worktree list --porcelain`; transcript folder slug must equal each path's slug, prompt project must equal the path. The worktree.dir prefix (slug glob and path prefix) applies only when worktree.dir exists and, resolved with `pwd -P`, lies inside MAIN; otherwise exact list only. Duplicates across exact and glob folders are skipped. Header states the accepted limits. Bats: shared absolute dir, relative `../wts` dir with a real linked worktree, linked worktree outside MAIN, missing dir adds no prefix, linked worktree inside dir listed once. Fixture now creates `$REPO/.claude/worktrees`.
- Minors: empty sessionId prints `-` (bats); `slug` and the id extraction no longer hide failures (basename dropped for parameter expansion); empty or non-numeric wc output dies; empty or short sort output dies (found a real bug: empty sort printed one junk session line); CR strip removed as dead code (the CR test stays as documentation); PATH-shim tests for wc, sort (fail, empty, short), awk and tr; header states the shared-slug limit and the compact-key limit.
- Not touched: quadratic `field()`.

Mutation re-run (removal mutations, one at a time): 22 run, 22 killed. Initial pass of 20 left two survivors (sort count guard, dedup of folders); two tests added, both now killed.
Killed: main-slug exact->prefix (8 failing), prompt exact->prefix, drop wt prefix, prefix without inside-MAIN check, mtime window, die after find, die after wc, wc size check, die after sort, sort empty guard, sort count guard, die after awk, die after slug, leading zeros, projects check, ~/.claude check, HOME check, history -L, sid dash, dedup seen.
Still untested: GNU date, mawk/gawk (unchanged). New awk code uses split() with a "\n" separator and ENVIRON; reasoned portable, run on BSD awk only.
