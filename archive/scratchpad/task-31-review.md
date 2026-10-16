# Task 31 review: hardened git in hooks (acd390f, b562f2a on cecdaef)

Spec verdict: compliant.
Quality verdict: approved. No Critical or Important findings; four Minor.

## Item 1: vector coverage

Reran `vectors.sh` on archives of cecdaef and b562f2a, in direct and include modes (scratch: `scratchpad/t31r/v-{before,after}-{direct,include}`).
- Before: `fsmonitor` marker ran in 11 of 14 steps (session-start, 3 commits, 3 pushes, `gh pr create`, 3 autopilot steps). subagent-start, prompt-submit and `gh pr review` read no loosening value in that fixture.
- After: no marker ran in any step, in either mode. Same result as the report.

Git-call census: grepped `hooks/`, `hooks/lib`, `hooks/guards`, `scripts/` for every `git` call, and checked what the hooks run (kern-detect via G5, `gh` in G2/G3, `gitleaks stdin` in G6). The census equals the report's table. Calls I found that the table lists only in grouped form:
- `settings.sh:8` worktree list, `gitctx.sh:473/483/494/506`, `g01-git.sh:458-475,569-579`: no index read, no worktree read.
- `g02:329`, `g05:233,240`, `g06:136` each carry `-c core.fsmonitor=false`. G6 also passes `--no-ext-diff --no-textconv`; G5/G1/kern-detect `log` use `--no-show-signature`.
- kern-detect `for-each-ref` (`:81`) and `remote get-url` (`:150`) are not reached from any hook (only `commit.convention` is), and neither runs a vector anyway.
- `scripts/kern-dir`, `kern-root`, `wt-snap` call git but no hook runs them.

Result: `settings.sh:84 ls-files -s` is the only hook git call that reaches a program, and it is the only index read without its own `-c core.fsmonitor=false`. No call is missing from the table.
- `git status` and `git diff` without options: no hook runs either.
- gh's own git children: in my run `gh pr list` made no git call on the scratch fixture (stub-token, offline), so I could not re-observe them. Environment inheritance by child processes is plain process semantics, so I rely on the report's `ghtrace` run for the call list and found nothing contradicting it.

### Minor 1: gitleaks reads a repo-controlled config (out of scope, unverified)
`hooks/guards/g06-secrets.sh:275` runs `gitleaks stdin` with the hook's cwd (the project). gitleaks looks for `.gitleaks.toml` in its source dir by default; a repo config with a global allowlist would blind the second G6 leg. This runs no program, so it is outside Task 31's brief, and gitleaks is not installed here, so I did not test it. Fix, if confirmed: pass `--config` pointing at a kern-owned file, or `GITLEAKS_CONFIG`. File for the M2a close triage.

## Item 2: append logic

All four hooks carry the identical 3-line block (md5 of the three lines after `export KERN_ROOT` equal in all four; test 3 pins it).

I ran the block under bash 5.3 and checked git's reaction (`git config` in /tmp):

| GIT_CONFIG_COUNT | KERN_GC | result |
|---|---|---|
| unset, "", abc, "-1", "0x10", " 1", "1 ", "1\n2" | 0 | kern pairs at 0,1; git works |
| 007 | 7 | git: "missing config key GIT_CONFIG_KEY_0", rc 128 (user's git is broken too) |
| 3, only KEY_0 set (gaps) | 3 | kern's pairs at 3,4; keys 1,2 missing; git rc 128 on every kern call |
| 99999999999999999999 | 7766279631452241919 | wraps in bash; COUNT stays positive; git "too many entries", rc 128 |
| 9223372036854775807 | INT_MAX | COUNT wraps negative, `export "GIT_CONFIG_KEY_-9223372036854775808=..."` prints "not a valid identifier", rc 1 |
| 18446744073709551617 | 1 | wraps to 1; kern pairs at 1,2; works if the env has KEY_0 |

Gap case, decisions (`pre-tool-use` on the 14-step fixture, autopilot off):
- `git commit -m x`: none = allow; gap = **ask** "G6: secret scan did not finish (exit 128)".
- `git push origin feat`, `git push`: ask in both; the gap text blames "-C names another repository" because the G1 helper fails; it reads wrong but the decision is safe.
- Huge count: same as gap.
So a broken count fails closed (ask), consistent with D6, and the user's own git fails in the same environment. Not a regression versus unchanged kern (git failed there too). Overwrite would instead have let kern's calls succeed while the user's would not; append is the right call.

### Minor 2: huge counts wrap, one wrap is fatal under POSIX mode
`GIT_CONFIG_COUNT` of 19+ digits wraps in bash arithmetic. The INT_MAX-range case makes `export` fail on `GIT_CONFIG_KEY_-...`. Under `POSIXLY_CORRECT=1` on bash 5.3 that failure of a special builtin **exits the hook** with rc 1 (`/bin/bash` 3.2 survives, rc 0). The report tested POSIXLY_CORRECT only with small counts. Effect: needs a hostile or broken user environment, not a repo; PreToolUse then emits no decision. The 18446744073709551617 case wraps to KERN_GC=1, harmless but wrong. Fix: treat more than 9 digits as bogus in the case pattern: `"" | *[!0-9]* | ??????????*) KERN_GC=0 ;;`. Update `HARDEN` in `tests/hooks/git-hardening.bats` and the four hooks together.

## Item 3: git_note

Ran `hooks/session-start` against a stub `git` first on PATH (answers `version`, `exec`s the real git otherwise). All cases rc 0, stderr empty, exactly one `git version` call each, warning on stdout as plain text. session-start prints plain stdout by design (not JSON), so there is no JSON to break; nothing prints outside the hook's normal stdout. No `set -e` in any hook; `git_note` ends `return 0` and the failing `git version` is guarded by `|| out=""`.

| stub output / rc | result |
|---|---|
| 2.30.9 / 0 | warn "git 2.30 is older than 2.31" |
| 2.31.0, 2.31, 2.54, 2.54.0 (Apple Git-157), 3.0.1, 10.0, 2.031.0, 2.31.0-rc0, 2.9999.0 | silent |
| "" / 1, 2.10 / 1, 2.30 / 5, garbage, "", `v2.30.0`, `git version v2.30.0`, 2.99999.0 | warn "failed or printed no version" |
| 2.30.9 then a second line | warn "2.30" (first line only) |
| second line first, then `git version 2.30.9` | failure warning (first line is not a version) |
| 1.9.9, 2.30rc1, 2.30.0.windows.1 | warn old-git |
| 02.30.1 | warn "git 02.30" (cosmetic) |

Budget: in my fixture (long scratch path) 3,721 characters with no line, 3,896 with the old-git line, 3,912 with the failure line. The bats test replaces `$K` with a realistic plugin path and asserts at most 4,000; it passes. Report's 3,733 is for a short path. The warning adds at most 191 characters, only when git is old or broken.

### Minor 3: `core.fsmonitor=false` before git 2.36 is a hook name (from memory, not verified)
Only git 2.54 is installed, so I could not test. I recall that before the builtin fsmonitor daemon (2.36) the value was always a program path, so on git 2.31 to 2.35 `false` would run `false` found on PATH, not a repo file; the pair is therefore harmless but not a no-op there. The existing `-c core.fsmonitor=false` in G2/G5/G6 behaves identically. If it matters, state "git 2.36 or later" in README, CHANGELOG and the warning; otherwise leave it. No action needed for security.

## Item 4: test strength

Mutations on copies of b562f2a (`scratchpad/t31r/mm-*`), each run against the named bats files:

| Mutation | Result |
|---|---|
| N1 threshold `-lt 31` to `-lt 30` | not ok 20 |
| N2 failing `git version` returns silently | not ok 20 |
| N3 unparsable output returns silently | not ok 20 |
| N4 any 2.x warns | not ok 21, plus session-start test 6 |
| M1 `state_file` accepts any id | not ok 7 (bad session id) |
| M2 subagent-start ignores session state | not ok 2 and not ok 5 |
| M3 `kern_enabled \|\| exit 0` removed | not ok 6 |
| H1 hook exports COUNT=0 | not ok 3 and 4 |
| H2 append becomes overwrite (KERN_GC=0) | not ok 3 and 4 |

All caught; the two brief tests that passed for the wrong reason (M1, M2) now fail under their mutation. (An H3 typo mutation of the hooksPath value did not apply because the value sits in a separate assignment; test 4 pins both values, so I did not pursue it.)

## Item 5: README, CHANGELOG, comments

- README "Needs git 2.31 or later." is accurate for `GIT_CONFIG_COUNT`; see Minor 3 on fsmonitor.
- CHANGELOG line matches behavior (older git or unreadable version gives one line).
- "a repository's own config" is accurate and better than the brief's "cloned repo's config".

### Minor 4: kern's other scripts are not hardened (known, reported)
`scripts/kern-get` run via session-start's settings summary reached the vector in the report's NOTICED 1; `kern-dir` and `kern-root` call git too. Not hooks, so within the brief; the deferral to M2a close is fine. Fix then: put the same three-line block at the top of those scripts, or have `scripts/lib` source it.

## Item 6: gates

- `tests/run-bats tests/hooks/git-hardening.bats tests/hooks/subagent-start.bats tests/hooks/session-start.bats`: all ok (git-hardening 4, subagent-start 7, session-start 32), 0 not ok.
- `shellcheck -x -S warning hooks/session-start hooks/subagent-start hooks/prompt-submit hooks/pre-tool-use`: no output, rc 0.
- `node --test 'tests/**/*.test.mjs'`: 213 tests, 213 pass, 0 fail.
- Full `tests/run-bats tests/hooks` (log: `scratchpad/hooks-t31r.log`, read by me): plan 1..568, 568 ok, 0 not ok, `exit=0`.

## Commands run (summary)
- Greps over hooks/ and scripts/ for git, gh and gitleaks calls; read diff, brief, report, progress.
- `vectors.sh` x4 (before/after, direct/include): 11 of 14 versus 0 of 14 markers, same in include mode.
- Block edge-value matrix under bash 5.3 and /bin/bash 3.2 (table in item 2); POSIXLY_CORRECT run with INT_MAX count.
- `pre-tool-use` decisions for three commands under none, gap, bogus and huge counts.
- 23 stub-git `session-start` runs (item 3).
- 9 mutation runs (item 4); the three gate commands; the full hook suite.
