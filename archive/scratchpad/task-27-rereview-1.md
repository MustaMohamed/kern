# Task 27 re-review, fix round 1 (457dd6b..2fbfc90)

Scratch: .../scratchpad/t27b (fixtures), .../scratchpad/t27/kcopy2 (mutation copy). HOME was always a scratch dir; the repo is untouched.

## 1. Round-0 findings

| ID | Status | Where | Note |
| --- | --- | --- | --- |
| I1 days octal | ADDRESSED | scripts/recall-sessions:47-49 | Leading zeros stripped before arithmetic and find. Bats 14 pins it. |
| I2 unreadable is not missing | ADDRESSED | :58-67, :143-144 | See section 3. |
| I3 shared or sibling worktree dir | ADDRESSED for every case the I3 text named, one inside-MAIN residual (N1) | :77-100, :148-180 | See section 2. |
| I4 relative `..` dir | ADDRESSED | :81-87 and git list | A linked worktree under `../wts` is found through git's exact path; the dir is resolved with `pwd -P` before it is used as a prefix. |
| M1 slug collision | PARTIAL, accepted | header :22-24 | Documented. The leak remains by design. |
| M2 empty sessionId | ADDRESSED | :178 | `-` is printed, so the columns hold. |
| M3 tr / basename silent | ADDRESSED | :91, :120 | `tr` failure dies with a prefix; `basename` replaced by parameter expansion. |
| M4 wc / sort exit 0 with nothing | ADDRESSED | :118, :133, :140 | Size check, empty-sort check, count check. |
| M5 quadratic `field()` | OPEN | :151-166 | Not touched, as stated. 100k escapes took 2 s. |
| M6 spaced key | PARTIAL | header :26-27 | Documented as a limit; the miss stays. |
| M7 prompt order / rounding | PARTIAL | header :7-8 | Order is documented. `%.0f` half-even rounding is unchanged. Harmless at minute resolution. |
| M8 dead CR strip | ADDRESSED | removed | The CR test stays as documentation. |

## 2. I3 re-attack

Leak cases rerun:
- Shared absolute `worktree.dir` holding another project's folder and prompt (`<B>/shared/projB`, prompt for it, `<B>/shared-other/x`): output was main only. No leak.
- `<main>/.claude/worktrees-foo` with the default dir: STILL LISTED (N1 below). Prompt for it excluded.

New design attacks:
- A worktree path with a space, a non-ASCII `é`, a locked worktree and a prunable worktree: all four transcripts and prompts included; none dropped.
- Running from inside a linked worktree: MAIN is still the main checkout; identical output to running from the main checkout.
- `worktree.dir` equal to MAIN (with and without a trailing slash): no prefix (not strictly inside), exact list only; no leak.
- `worktree.dir` as a symlink inside MAIN pointing outside: resolved with `pwd -P`, so no prefix. No leak.
- `worktree.dir` as a symlink outside pointing inside MAIN: prefix taken on the physical path. Fine (inside MAIN).
- Relative `../shared` (outside MAIN): no prefix.
- `worktree.dir: .claude` (inside MAIN, wider than the worktree dir): takes the whole `.claude` slug prefix. All inside the main checkout, so not another project. Accepted by design.
- Bare main repo: runs, prints nothing, no leak.

No other project's data leaked in any case.

### N1 (Minor). The inside-MAIN prefix glob still matches `<main>/.claude/worktrees-foo`
scripts/recall-sessions:96-100. The slug of `<main>/.claude/worktrees/` is `<main slug>--claude-worktrees-`, and the glob `slug*` also matches the folder for `<main>/.claude/worktrees-foo` or `worktrees.foo`. Reproduced (listed as `foo`). Because the dir lies inside the main checkout, this is a path inside the same repo's own tree, not another project, so I grade it Minor, not Important. Fix if wanted: accept a prefix folder only when its first transcript line's `cwd` is under `$WTP`, or document it.

### N2 (Minor). A worktree path containing a newline is truncated
scripts/recall-sessions:78. Git 2.54 prints the raw newline in `--porcelain`; `sed 's/^worktree //p'` then keeps only the first line (`.../wt`, not `.../wt\nnl`). The real worktree is missed, and the truncated path is matched exactly (it would take a project that lives at that exact truncated path). Absurd path; likelihood negligible. Fix: `git worktree list --porcelain -z` (git 2.36+) if the minimum git allows, or accept and document.

## 3. I2 matrix (all rc/stdout/stderr checked)

Dies with rc 1, empty stdout, `recall-sessions:` on stderr: `~/.claude/projects` at modes 000, 444, 044, 111, 222 (the 111 and 044 cases are the missing-read / missing-execute-bit cases); `~/.claude` at 000, 444, 111; history at 000, 222, 111; `$HOME` at 000; history that is a directory; a dangling history symlink; a dangling `projects` symlink; the main transcript folder and a linked worktree's folder at 000, 444, 222, 044 (find fails, then `die`); an unreadable transcript file (wc redirect fails, then `die`).
Correct and clean: history at 444 (readable) gives output, rc 0; `history.jsonl` missing gives sessions only, rc 0; `~/.claude` missing gives empty, rc 0; `projects` missing gives empty, rc 0.
No hole found.

## 4. Portability (by reading; BSD awk only was run)

- `split(ENVIRON["WTS"], W, "\n")`: a one-character literal separator, not a regex special, in gawk, mawk and BSD awk. An empty WTS gives 0 elements on all three. Called in BEGIN, so it runs once. gawk and mawk both treat it the same. OK on ubuntu.
- `ENVIRON` for WTS, WTP, MAIN, TOPIC, SINCE: no `-v` backslash processing. OK. `p == W[i]` is a string comparison of strings from the same source; `ENVIRON["WTP"] != ""` guards the prefix branch.
- Loop variable `i` in the main rule is global, and `field()` declares its own `i` local, so there is no clash. No new construct beyond round 0 differs between the three awks.
- Nothing else new needs GNU-specific handling: `pwd -P`, `cd --`, `CDPATH=''` are POSIX.

## 5. Mutations (kcopy2; 26 run, original script restored after)

Killed (test numbers in parentheses): main slug exact to prefix (9 tests), worktree prompt exact to prefix (5, 18), main-only prompt (18, 20), inside-MAIN check removed (19, 20), mtime window (5 tests), git worktree list replaced by MAIN (18, 20), die after find (12), die after sort (23), empty-sort guard (23), sort count guard (24), die after awk (26), `need_dir projects` (15), `need_dir ~/.claude` (15), history `-L` test (16), leading-zero strip (14), dedup of folders (25), empty-sessionId dash (17).
Survived, with the reason (all four are shadowed by a second guard, so no wrong output is reachable, but the guard itself is untested):
- `die` after `wc`: the following `case "$bytes"` size check still dies.
- `die` after `slug` in the loop: with a `tr` shim the earlier `wt_dir` call fails first (line 81), so line 91 is never reached by the test.
- `die` after `git worktree list`: the next line `[ -n "$wts" ] || die` still dies.
- `[ -f "$hist" ]` part of the history check: a directory still fails inside awk, which dies.
- `[ -x "$1" ]` in `need_dir`: REAL test gap. Without it, `projects` at mode 444 (readable, not traversable) makes `[ -d "$projects/<slug>" ]` false and the script prints nothing with rc 0. I confirmed the current code is right (it dies), but no bats test pins the execute bit.

Round 0's mutation gap (CR strip, `die` after `wc`, `sort`, `awk`) is closed.

## 6. New defects authored by this round in round 0's code

None. The changed areas (days handling, the folder list, the prompt filter, the sort guards) each behave as before for the cases round 0 handled, and the new guards have no false positive in the matrix above. N1 is a leftover of round 0's glob, not a new defect. The test gap on the execute bit is Minor.

## 7. Gates

- `tests/run-bats tests/scripts/recall-sessions.bats`: 30 of 30 ok.
- `shellcheck scripts/recall-sessions`: no output, rc 0.
- `git status` in /Users/musta/Code/projects/kern: unchanged by me.

## Verdict: APPROVED

No Critical or Important finding remains. Minor, optional: N1 (the inside-MAIN glob matching `worktrees-foo`), N2 (a newline in a worktree path), the untested execute-bit guard (`need_dir`, :62), and the still-open quadratic `field()` (M5).
