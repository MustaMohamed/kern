### Task 12a: Wrapper long options and hidden git or gh (added by the Task 12 review)

Task 12's implementer found that `env --chdir sub git push --force origin main` reads `sub` as the command. No guard sees the git, so the vote is none; under autopilot the push runs. Task 9a's wrapper tables hold short options only, and any wrapper kern does not know (caffeinate, stdbuf, xargs, find -exec) hides git the same way. This task adds the common long options, and a fail-closed rule for git or gh that appears later in a command whose head is something else. It has no code in the plan: you design the change, test first.

**Files:**
- Modify: `hooks/lib/gitctx.sh`, `hooks/guards/g01-git.sh`, `hooks/guards/g02-pr.sh`, `hooks/guards/g05-commit.sh`
- Test: `tests/hooks/gitctx.bats`, `tests/hooks/g01-git.bats`, `tests/hooks/g02-g04-gh.bats`, `tests/hooks/g05-g06-commit.bats`

**Read first:** `hooks/lib/gitctx.sh` (`_GW_AWK`, `cw`, `_cmd_words`, `git_sub`, `gh_sub`, `git_words`), the start of `guard_g01` and `guard_g02`, `tests/helpers/common.bash`, and in `docs/plans/contract.md` the lines for `gitctx.sh`, `git_sub` and `gh_sub`. The own-command list Task 12 added (git 2.54 builtins plus main, 172 names) is reused here.

**Ground rules:**
- Bash 3.2: no `${x,,}`, no `mapfile`, no associative arrays in bash (awk arrays are fine), no `;&`.
- Every existing test keeps passing. The dispatcher on `ls` stays within 10 ms of today (about 130 ms with all guards); a command whose text holds neither `git` nor `gh` runs no new process.
- No guard may vote allow because of this task. The new rule only asks, and denies under autopilot.

**Scope:**

1. **Long options that take a value.** Add them to `cw_opt`, read as `--opt value`; `--opt=value` is already one word.
   - env: `--chdir`, `--unset`, `--split-string` (read like `-S`: its value is a command line), `--argv0`.
   - sudo: `--user`, `--group`, `--host`, `--prompt`, `--chdir`, `--role`, `--type`, `--close-from`, `--other-user`, `--command-timeout`.
   - nice: `--adjustment`.
   - timeout already has `--signal` and `--kill-after`.

2. **Hidden git or gh: fail closed.**
   - Applies to a simple command whose head (per `_cmd_words`) is neither git nor gh.
   - If a later word has the basename `git`, skip git's global options after it. When the next word is one of git's own commands outside a read-only set, G1 asks (deny under autopilot): "git inside <head> cannot be checked; run git directly".
     - Read-only set: status, log, diff, show, rev-parse, ls-files, ls-remote, blame, describe, grep, help, version, cat-file, shortlog, for-each-ref, merge-base, name-rev, count-objects, var.
   - If a later word has the basename `gh` (any case) and the next word, after `-R`/`--repo` and its value, is a gh command group other than `help`, `version`, `status`, `browse` or `search`, G2 asks (deny under autopilot) with the same reason for gh.
   - This covers unknown wrappers, option clusters (`env -iC sub git ...`), GNU long-option prefixes (`env --ch sub git ...`), `xargs git ...` and `find ... -exec git ...`.
   - It does not cover git inside a quoted script for an interpreter, a variable, or a here-doc body; those stay out of scope.
   - Quoted text stays one word: `grep -rn "git push" docs` has no word `git`.

3. **Append assignments and upper-case wrappers (added by the Task 12 round-3 review).**
   - `_cmd_words` and G5's `_g05_env` read `NAME+=value` as an assignment, as they read `NAME=value`. Bash 3.2 runs `GIT_DIR+=x cmd` with `GIT_DIR=x` set for cmd.
   - Wrapper basenames compare case-insensitively, since macOS's file system runs `ENV`, `Env` and `SUDO` as env and sudo.

**Tests (each must fail before your change where it is a behaviour change):**
- gitctx.bats: `git_sub` finds git in `env --chdir sub git push origin main`, `env --unset X git push`, `env --split-string "git push origin main"`, `sudo --user root git push`, `sudo --chdir /tmp git push`, `nice --adjustment 5 git push`.
- g01-git.bats, deny under autopilot (and ask without it, for the first two):
  - `env --ch sub git push --force origin main`
  - `env -iC sub git push --force origin main`
  - `caffeinate -i git push --force origin main`
  - `stdbuf -oL git commit -m x`
  - `echo main | xargs git push --force origin`
  - `find . -maxdepth 0 -exec git push --force origin main \;`
- g01-git.bats, no vote: `brew install git`, `which git`, `apt-get install git curl`, `man git`, `grep -rn "git push" docs`, `echo "git push"`, `xargs git status`, `git status`.
- g01-git.bats, ask (a documented cost): `echo git push`.
- g01-git.bats, deny under autopilot through the proper G1 check, not the hidden rule: `X+=1 git push --force origin main`, `ENV git push --force origin main`, `Env --chdir=sub git push --force origin main`.
- g05-g06-commit.bats: `GIT_DIR+=/x/.git git commit -m 'CDS-2465: x'` gets "could not scan" from G6.
- g02-g04-gh.bats: `caffeinate gh pr merge 1` is denied under autopilot; `brew upgrade gh` and `which gh` get no vote.
- The `ls` timing case: report the dispatcher time on `ls` before and after.

**Commit:**
```bash
git add -- hooks/lib/gitctx.sh hooks/guards/g01-git.sh hooks/guards/g02-pr.sh hooks/guards/g05-commit.sh tests/hooks/gitctx.bats tests/hooks/g01-git.bats tests/hooks/g02-g04-gh.bats tests/hooks/g05-g06-commit.bats
git commit -m "M1: read wrapper long options; git or gh behind a wrapper asks" -m "env --chdir and similar long options take a value, and git or gh that appears later in another command asks, since kern cannot tell what that command will run."
```

Run the whole suite once before committing: `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats` and `node --test tests/*.test.mjs`.
