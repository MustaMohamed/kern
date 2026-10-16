STATUS: DONE_WITH_DEVIATIONS. Hooks harden git by appending to the environment's config pairs, not by overwriting them; one test was added and two SubagentStart tests were strengthened. Rulings are needed on the git-version handling (item 3).

# Task 31 report: hardened git in hooks, SubagentStart tests

- Commit: `acd390f57e419aa3bf6ab362bc54ce626caffe72` on `main`. The base is cecdaef, and the branch was checked before the first edit and again before the commit. The commit is unsigned, like its parent; this repo does not set `commit.gpgsign`.
- Files: `hooks/session-start`, `hooks/subagent-start`, `hooks/prompt-submit`, `hooks/pre-tool-use`, `tests/hooks/git-hardening.bats` (new), `tests/hooks/subagent-start.bats`, `CHANGELOG.md`.

## Gates

### Red (hooks unchanged, final tests)

```
1..11
ok 1 the fixture's fsmonitor program runs for a plain git call
not ok 2 session-start runs git without the repo's fsmonitor program
#   `[ ! -f "$M" ]' failed
not ok 3 every hook exports the hardened git config right after KERN_ROOT, before it runs git
# session-start does not harden git right after KERN_ROOT
not ok 4 every git a hook runs, its children's too, gets both pairs after the environment's own
# GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=kern.test GIT_CONFIG_VALUE_0=kept :: -C .../repo worktree list --porcelain
# GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=kern.test GIT_CONFIG_VALUE_0=kept :: -C .../repo ls-files -s -- :(icase).claude
# GIT_CONFIG_COUNT=1 ... :: -C .../repo log --no-show-signature --format=%s -30 origin/main
# GIT_CONFIG_COUNT=1 ... :: -C .../repo --no-replace-objects ... diff --cached ... --diff-filter=d
# (12 calls listed, none with the pairs)
ok 5 valid SubagentStart JSON under 1,200 characters
ok 6 terse voice reaches the subagent
ok 7 with settings.sh missing, subagent-start exits 0 and prints nothing or valid JSON
ok 8 subagent returns skip preamble, praise and closing offers, and no agent is told to write a bulk file
ok 9 normal voice adds no terse line
ok 10 kern: off prints nothing
ok 11 a bad session id falls back to the settings voice
```

Tests 2 to 4 fail for the expected reasons. The control test and the three SubagentStart tests pass.

### Green

```
1..11
ok 1 the fixture's fsmonitor program runs for a plain git call
ok 2 session-start runs git without the repo's fsmonitor program
ok 3 every hook exports the hardened git config right after KERN_ROOT, before it runs git
ok 4 every git a hook runs, its children's too, gets both pairs after the environment's own
ok 5 valid SubagentStart JSON under 1,200 characters
ok 6 terse voice reaches the subagent
ok 7 with settings.sh missing, subagent-start exits 0 and prints nothing or valid JSON
ok 8 subagent returns skip preamble, praise and closing offers, and no agent is told to write a bulk file
ok 9 normal voice adds no terse line
ok 10 kern: off prints nothing
ok 11 a bad session id falls back to the settings voice
```

### Hook suite: `tests/run-bats tests/hooks` (log: `/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/hooks-t31.log`)

```
1..566
...
ok 564 normal voice adds no terse line
ok 565 kern: off prints nothing
ok 566 a bad session id falls back to the settings voice
exit=0
```

566 ok, 0 not ok. This run came before the final comment rewording (deviation 4). After the rewording, the two target files, shellcheck and the node tests were run again and passed. The rewording changes comment lines only.

### Other gates

- `shellcheck -x -S warning hooks/session-start hooks/subagent-start hooks/prompt-submit hooks/pre-tool-use` printed nothing (rc 0).
- `node --test 'tests/**/*.test.mjs'`: 213 tests, 213 pass, 0 fail.
- The code is bash 3.2 compatible. I ran the block under `/bin/bash` 3.2.57, under `POSIXLY_CORRECT` (it runs before `set +o posix`), and under `set -u`, with these `GIT_CONFIG_COUNT` values: unset, empty, `abc`, `1x`, `-1`, `0` and `007`. The only character class in the block is `[!0-9]`; there are no letter ranges.

## The change

This block sits right after `export KERN_ROOT` in each of the four hooks:

```bash
case "${GIT_CONFIG_COUNT-}" in "" | *[!0-9]*) KERN_GC=0 ;; *) KERN_GC=$((10#$GIT_CONFIG_COUNT)) ;; esac
export GIT_CONFIG_COUNT=$((KERN_GC + 2)) "GIT_CONFIG_KEY_$KERN_GC=core.fsmonitor" "GIT_CONFIG_VALUE_$KERN_GC=false" \
  "GIT_CONFIG_KEY_$((KERN_GC + 1))=core.hooksPath" "GIT_CONFIG_VALUE_$((KERN_GC + 1))=/dev/null"
```

## 1. Git calls and execution vectors

### Every git call the hooks make

I measured each call with stdout to a pipe, as in a hook, against a scratch repo whose own config names a marker program for every vector below (`percall.sh`). "Before" means without the export; "after" means with it.

| # | Call (as kern spells it) | Site | Hook | Before | After |
|---|---|---|---|---|---|
| 1 | `git -C <dir> worktree list --porcelain` | `hooks/lib/settings.sh:8` (`kern_main_root`) | all four, kern-detect | none | none |
| 2 | `git -C <main> ls-files -s -- ':(icase).claude'` | `settings.sh:84` (`_settings_local_ok`), only when a loosening value is read | all four | **core.fsmonitor** | none |
| 3 | `rev-parse --show-toplevel` | `hooks/lib/gitctx.sh:473` | pre-tool-use | none | none |
| 4 | `symbolic-ref -q HEAD` | `gitctx.sh:483` | pre-tool-use | none | none |
| 5 | `symbolic-ref --short refs/remotes/origin/HEAD` | `gitctx.sh:494`, `:506`; `scripts/kern-detect:26` | pre-tool-use | none | none |
| 6 | `remote` | `hooks/guards/g01-git.sh:458`, `:569` | pre-tool-use | none | none |
| 7 | `config user.email` | `g01-git.sh:459`, `:473` | pre-tool-use | none | none |
| 8 | `log --no-show-signature --format=%ae <range>` | `g01-git.sh:461`, `:464`, `:475` | pre-tool-use | none | none |
| 9 | `rev-parse --verify -q refs/remotes/<r>/<b>` | `g01-git.sh:463`, `:474` | pre-tool-use | none | none |
| 10 | `config --get-regexp '^remote\..*\.(push\|mirror\|receivepack\|vcs)$'`, `config --get-all remote.<r>.url`, `remote get-url --push --all <r>` | `g01-git.sh:575-579` | pre-tool-use | none | none |
| 11 | `-c core.fsmonitor=false check-ignore -q -- <f>` | `hooks/guards/g02-pr.sh:329` | pre-tool-use | none (fsmonitor without its `-c`) | none |
| 12 | `-c core.fsmonitor=false rev-parse --show-prefix` | `hooks/guards/g05-commit.sh:233` | pre-tool-use | none | none |
| 13 | `-c core.fsmonitor=false log -1 --no-show-signature --no-color --format=%B --end-of-options <ref> --` | `g05-commit.sh:240` | pre-tool-use | none | none |
| 14 | kern-detect `commit.convention` (a child, `g05-commit.sh:307`): #1, #5, `rev-parse -q --verify <ref>`, `log --no-show-signature --format=%s -30 <ref>` | `scripts/kern-detect:14,26,96,98` | pre-tool-use | none | none |
| 15 | G6 `_g06_git` (`--no-replace-objects -c color.ui=never -c core.fsmonitor=false -c core.quotePath=false -c log.showRoot=true -c i18n.logOutputEncoding=UTF-8`): `diff --cached` and `log -p --cc`, both with `--text --no-relative --no-color --no-ext-diff --no-textconv`; `log -z --format=%h%x00%B`; `config` (pushRemote, pushDefault, remote, mirror, push.default, remote.<r>.push); `rev-parse --verify -q`; `remote`; `for-each-ref --count=1` | `hooks/guards/g06-secrets.sh:136`, used at `:326-414` | pre-tool-use | none | none |
| 16 | gh's own git children, for `gh pr list` (`g02-pr.sh:336`) and `gh api user` / `gh pr view` (`g03-review.sh:122-123`): `remote -v`, `config --get-regexp ^remote\..*\.gh-resolved$`, `symbolic-ref --quiet HEAD`, `config --get-regexp ^branch\.<b>\.(remote\|merge\|pushremote\|gh-merge-base)$`, `rev-parse --symbolic-full-name <b>@{push}`, `config push.default`, `config remote.pushDefault` | traced with a `git` wrapper on PATH around `/opt/homebrew/bin/gh` | pre-tool-use | none | none |

`gitleaks stdin` (`g06-secrets.sh:275`) runs no git; it reads the walk on its stdin.

For contrast, these calls kern does not make all reached vectors in the same repo:
- `git status`: fsmonitor, filter clean, and hook-post-index-change.
- `git diff`: fsmonitor.
- `git fetch`: fsmonitor and uploadpack.
- `git ls-remote`: uploadpack.
- `diff --cached` without G6's options: clean, smudge, the diff driver's command, and fsmonitor.
- `log -p` without them: smudge and textconv.
- `log` without `--no-show-signature` on a signed commit: gpg.
- `check-ignore` without its `-c`: fsmonitor.

So kern's existing per-call options are load-bearing, and they hold.

### Vectors

| Vector | Runs on | Reached by a kern call? |
|---|---|---|
| `core.fsmonitor` | index reads that refresh | **Yes:** #2 `ls-files -s`, in all four hooks whenever a loosening value is read (`kern: off`, `*.policy: auto`, `review.post_policy: auto`, `rebase.push: autopilot`). #11 to #15 already pass `-c core.fsmonitor=false`. **Fixed (in scope).** |
| `core.hooksPath`, `.git/hooks` | commands that write the index, refs or commits (`status` fired post-index-change) | No. None of 29 hook names fired from any kern call. This is defence in depth. **Fixed (in scope).** |
| `filter.<d>.clean`, `smudge`, `process` (via `.gitattributes`) | worktree hashing, checkout, temp files for an external diff or textconv | No. kern reads no worktree content, and G6 reads patches with `--no-ext-diff --no-textconv`. |
| `diff.<d>.textconv`, `diff.<d>.command`, `diff.external` | `diff`, `log -p` | No. G6 is the only caller that makes patches, and it passes `--no-ext-diff --no-textconv`. |
| `core.pager`, `pager.<cmd>` | only when stdout is a tty | No. Claude Code reads hook stdout, so it is a pipe. With a tty (`script(1)`), the pager ran for check-ignore, log, remote, for-each-ref and worktree. Of kern's calls, only #11 inherits the hook's stdout; every other call goes to `$( )`, a pipe or `/dev/null`. See NOTICED 2. |
| `core.sshCommand`, `core.gitProxy`, `core.askPass`, `credential.helper`, `remote.<r>.uploadpack`, `receivepack`, `vcs`, `protocol.*` | transport (fetch, push, ls-remote) | No. Neither kern nor gh's children (#16) use transport. kern reads `receivepack` as config text only. |
| `core.editor`, `sequence.editor` | commands that open an editor | No. |
| `gpg.program`, `gpg.ssh.program` with `log.showSignature` or `%G?` | `log` on a signed commit | No. Every kern `log` passes `--no-show-signature` and uses no `%G` format. gpg ran without the flag and did not run with it. |
| `merge.<d>.driver`, `core.alternateRefsCommand` | merge, fetch/receive negotiation | No. |
| `include.path`, `includeIf` | pull in another config file; they run nothing themselves | With every vector moved into an included file, unchanged kern ran fsmonitor in the same 11 of 14 harness steps, and the change ran none. Command-line scope (`GIT_CONFIG_COUNT`) outranks included values. |
| `trailer.<t>.command` (static check only, not measured) | `interpret-trailers`, `commit --trailer` | No. kern runs neither. |

The hooks reach only fsmonitor and hooksPath, and the brief covers both, so I propose no extra config pair.

Harness (`vectors.sh`): 14 hook runs covering session-start, subagent-start, prompt-submit, and pre-tool-use for `commit -m`, `commit --amend --no-edit`, `commit -F`, three push shapes, `gh pr create --draft`, `gh pr review`, and autopilot commit, push and PR. Settings-loosening values were present.
- Unchanged kern: fsmonitor ran in 11 of 14 runs. subagent-start, prompt-submit and pr-review read no loosening value in that fixture.
- The change: no marker ran in any run.
- All 13 pre-tool-use and subagent-start outputs are byte-identical before and after. The session-start output differs only in the kern path it prints.

## 2. Overwrite or append: append

**What overwrite does.** The brief's export sets `GIT_CONFIG_COUNT=2` and replaces `KEY_0`/`VALUE_0` and `KEY_1`/`VALUE_1`. Any pairs the user's environment already holds are dropped for kern's children only. Pairs at index 2 and above stay in the environment, but git ignores them. kern's own calls still run, but they then read a different config from the one the user's real command reads: Claude's Bash tool inherits the same environment, and the hook's export never reaches it.

**That gap can loosen kern.** Two reproductions (`overwrite.sh`) compare unchanged kern, the brief's overwrite line and this commit's append:

| Case | Unchanged | Overwrite (brief) | Append (commit) |
|---|---|---|---|
| A. The environment holds `push.default=matching`. A real `git push --dry-run` sends `other -> other`, whose new commit holds an AWS key. Command: `git push`. | deny: `G6: possible secret ... conf.txt:1 aws-access-key` | **ask**: `G1: push feat; name the remote and branch` (no secret named) | deny, same as unchanged |
| B. The environment holds `safe.directory=*`, as in a container whose checkout another uid owns (simulated with `GIT_TEST_ASSUME_DIFFERENT_OWNER=1`). The project `kern.yml` sets `never_commit: secret.txt`, and the file is staged. Command: `git commit -m x`. | deny: `G6: never_commit paths staged: secret.txt` | **ask**: `G6: secret scan did not finish (exit 129)`. kern's git fails "dubious ownership", so the project settings are not read. | deny, same as unchanged |

In both cases overwrite turns a deny into an ask, while the user's own command would run normally. G6 already treats `push.default=matching` set by environment config as relevant: `g05-g06-commit.bats:889` asks "could not scan" when a command sets it. An ambient pair matters in the same way. So the user's environment config can change what kern must check, and dropping it is not neutral.

**Append.** kern's two pairs go at index n and n+1, where n is the existing count, so the user's pairs still apply. For `core.fsmonitor` and `core.hooksPath`, kern's pairs come later and win.
- A count that is not a plain number is treated as 0, which overwrites. git itself rejects such a count ("bogus count"), so the user's own git already fails in that environment.
- `10#` makes a value with leading zeros parse as decimal, as git's `strtoul(..., 10)` does.
- A numeric count with a missing `KEY_i` makes kern's git fail the way the user's git fails. kern and the real command stay in step.
- Test 4 pins the order: with `kern.test=kept` in the environment, every recorded git call carries `COUNT=3` and `kern.test`, then fsmonitor, then hooksPath. The recorded calls include kern-detect's `log` and G6's `diff --cached`.

**Out of reach.** `GIT_CONFIG_PARAMETERS`, which `git -c` sets, is read after `GIT_CONFIG_COUNT`, so a `core.fsmonitor` placed there by the user's environment still wins. That is user scope, not repository scope, like the user's global config.

## 3. Git version

- **What kern already requires.** No git minimum is stated in the README, the design spec, `hooks/lib` or `kernel/`. Only the M2a plan's Interfaces line says "git 2.31+". Some code already depends on a newer git without saying so:
  - G5 uses `--end-of-options` (git 2.24+). On older git, `_g05_log` fails, the message reads as unreadable, and G5 asks, so it fails closed.
  - The tests use `git init -b` (2.28+).
  - The option tables are taken from git 2.54.
- **What happens on older git.** I did not measure this; only git 2.54 is installed here. The source is git's 2.31.0 release notes, which introduced `GIT_CONFIG_COUNT`, `GIT_CONFIG_KEY_<n>` and `GIT_CONFIG_VALUE_<n>`. Before 2.31, git does not know these variables and ignores them without an error.
  - `core.fsmonitor` has existed since git 2.16. So on git 2.16 to 2.30, call #2 (`ls-files -s`) still runs a repository's fsmonitor program, silently.
  - G2, G5 and G6 keep their own `-c core.fsmonitor=false` on any version, so the exposure on old git is exactly what it was before this task.
  - The append code is harmless there.
  - Distributions still shipping such a git, from memory and not checked: Debian 11 (2.30.2) and Ubuntu 20.04 (2.25.1).
- **Proposal, for your ruling:**
  1. Smallest honest change: one README Install line, "Needs git 2.31 or later", and "(git 2.31 or later)" appended to this task's CHANGELOG line. Without it, the CHANGELOG line claims the protection unconditionally.
  2. The D6-consistent addition: session-start prints one context line when `git version` is below 2.31, for example "kern: git X is older than 2.31; hook git calls still read the repository's fsmonitor and hooks config". That costs one extra git call per session start, never per tool call, and about 5 lines.
  3. Not recommended: also export the legacy `GIT_CONFIG_PARAMETERS`, which every git reads. git documents it as internal, and git reads it after `GIT_CONFIG_COUNT`, so it would also override the user's own pairs.

  I implemented none of these.

## 4. SubagentStart tests

The three brief tests passed before the change (red run, tests 9 to 11). Mutation checks on a scratch copy showed that two of them passed for the wrong reason:

| Mutation | Brief's test | Result | After strengthening |
|---|---|---|---|
| M1: `state_file` accepts any id (`'') return 2` only) | a bad session id falls back to the settings voice | **still ok**: no file exists at `sessions/../x.state`, and subagent-start never writes state, so `! -e x.state` holds anyway | not ok |
| M2: subagent-start ignores session state | normal voice adds no terse line | **still ok**: the default voice is normal anyway (only "terse voice reaches the subagent" caught it) | not ok |
| M3: `kern_enabled \|\| exit 0` removed | kern: off prints nothing | not ok (right reason) | not ok |

The strengthening:
- **normal voice**: the settings now say `mode.voice: terse`, so the session's `normal` has to win.
- **bad session id**: a `$CLAUDE_PLUGIN_DATA/x.state` file with `voice: normal` is planted (with `sessions/` present), so an id that was not rejected would read it. The `! -e x.state` assertion became "the planted file is unchanged".

The unmutated tree passes all of them.

## Reproductions

All files are in `/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t31/`:
- `vectors.sh KERN_DIR OUT [include]`: the vector repo plus 14 hook runs. Results are in `v-before`, `v-before-inc`, `v-after` and `v-after-inc`.
- `percall.sh FIXTURE`: each git call as kern spells it, then the same calls without kern's options, then calls kern does not make.
- `overwrite.sh KERN_DIR OUT`: cases A and B. `k-before` is cecdaef, and `k-overwrite` is cecdaef plus the brief's line.
- `mut-M1`, `mut-M2`, `mut-M3`: the mutation copies.

## Deviations

1. **Append, not overwrite** (item 2). The export has a different form from the brief's line. Brief test 3 now checks the three code lines that follow `export KERN_ROOT`, comments aside, instead of grepping one line. That still pins the placement before any library or git call.
2. **Added test 4**, "every git a hook runs, its children's too, gets both pairs after the environment's own". A `git` wrapper on PATH records the `GIT_CONFIG_*` variables of every git call that the four hooks and kern-detect make. The test asserts that each call carries the environment's pair followed by kern's two pairs. It also asserts that the record covers `ls-files -s`, G6's `diff --cached` and kern-detect's `log`.
3. **Two SubagentStart tests strengthened** (item 4, with the mutation evidence above).
4. **Comment wording**: "a repository's own config" instead of the brief's "a cloned repo's config". A plain `git clone` never copies the remote's config, hooks or index. The real source is a `.git` the user did not create, such as an unpacked archive or a shared directory, or one that an earlier process edited. The block also has two more comment lines, on append and on `KERN_GC`.
5. The commit message and CHANGELOG line are verbatim from the brief.

## NOTICED BUT NOT TOUCHING

1. **Scripts run outside a hook are not hardened.** In the vector repo, `bash scripts/kern-get push.policy` ran the fsmonitor program; session-start's settings summary tells the model to run kern-get. This is no worse than any `git status` the agent runs through Bash, which kern cannot cover, but it is a kern script reaching the vector.
2. **G2's `check-ignore` writes to the hook's own stdout** (`g02-pr.sh:329`). If someone runs `hooks/pre-tool-use` by hand in a terminal, `pager.check-ignore` would run. Claude Code never gives a hook a tty. A config pair cannot fix this; `--no-pager` on that call, or `GIT_PAGER=cat`, would.
3. **`GIT_CONFIG_PARAMETERS` in the user's environment outranks kern's pairs.** This is user scope (see item 2).
4. **`_settings_local_ok` treats a failing `git ls-files` as "untracked".** The pipeline's status is awk's, and awk exits 0 on empty input. Only someone who controls `.git` can reach this, and that person can simply leave the file untracked, so it adds no exposure. It is a silent fallback by D6's wording.
5. **No git minimum is documented** anywhere, although G5 already needs 2.24 and the tests need 2.28 (item 3).

---

# Follow-up: rulings on items 2 to 4 (commit `b562f2a355eafa6858e53c26d31a326716227f2b`)

STATUS: DONE. Rulings: append accepted; item 3 (a) and (b) applied; item 4 fixes accepted; NOTICED items deferred to the M2a close triage.

- Commit: `b562f2a` "M2: session-start says when git is too old for the hook hardening", on `main` after `acd390f`. It touches `hooks/session-start`, `tests/hooks/session-start.bats`, `README.md` and `CHANGELOG.md`. No shared hook lib was touched, so the full hook suite was not rerun.
- (a) `README.md` had no requirements list, so the Install section now opens with "Needs git 2.31 or later." The CHANGELOG line now reads: "Hooks run git with no fsmonitor program and no repo hooks (git 2.31 or later). With an older git, or one whose version cannot be read, session-start says so in one line."
- (b) `git_note` in `hooks/session-start` runs right after the kernel renders, before the terse rules.
  - It makes one call, `out=$(git version 2>/dev/null) || out=""`, so a failing git cannot trip `set -e`.
  - It keeps only the first line and parses major and minor with `case` and parameter expansion (bash 3.2). It accepts only `git version <digits>.<digits>...`, with at most 4 digits in each part.
  - A git below 2.31 prints: `kern: git 2.30 is older than 2.31, so git ignores kern's GIT_CONFIG_* hardening and a repository's fsmonitor program can run on kern's index reads; install git 2.31 or later.`
  - A failing or unparsable `git version` prints: `kern: git version failed or printed no version, so git may ignore kern's GIT_CONFIG_* hardening and a repository's fsmonitor program may run on kern's index reads; install git 2.31 or later.`
  - Git 2.31 or later prints nothing.
- Tests use a stub `git` first on PATH that answers `version` and hands every other call to the real git.
  - These warn exactly once: `2.30.9`; exit 1 with no output; valid output with exit 3; `not a version`; `git version x.31`.
  - These print nothing: `2.31.0`, `2.54`, `2.54.0 (Apple Git-157)`, `3.0.1`.
  - The warning test also asserts that the kernel still renders, and that the normalized output stays at or under the 4,000-character budget.
  - Measured: 3,542 characters with real git 2.54 and no line; 3,717 with the 2.30 line; 3,733 with the failure line.
  - Lint rule 7's 9,000 cap measures with real git, so it is unaffected; node tests are 213/213.
- Red: the new warning test failed (no hardening line was printed), and the no-warning test passed.
- Mutations, each caught on a scratch copy:
  - threshold changed to 30: test 20 fails (2.30.9 gives 0 lines);
  - a failing `git version` returns silently: test 20 fails;
  - unparsable output returns silently: test 20 fails;
  - every parsed version warns: test 21 fails.
- Gates:
  - `tests/run-bats tests/hooks/session-start.bats tests/hooks/git-hardening.bats`: 25/25 ok.
  - `shellcheck -x -S warning hooks/session-start`: clean.
  - `node --test 'tests/**/*.test.mjs'`: 213 pass, 0 fail.
- Shell patterns: the version parse uses `[0-9]` and `[!0-9]` digit ranges, as `gitctx.sh:530-532` and `g01-git.sh:437` already do. It has no letter ranges.
