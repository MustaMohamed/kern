# M1 Task 12a report: wrapper long options, hidden git or gh

The implementer's Write to this file was refused by the harness ("Subagents should return findings as text"). The controller saved the report it returned inline, unchanged below.

Status: DONE_WITH_CONCERNS. Commit 7c50836 "M1: read wrapper long options; git or gh behind a wrapper asks".
Tests: bats 307/307 (3:43), node 46/46, shellcheck clean plain and -x on the 4 hooks; the 4 bats files have no new findings vs d87d2a3.
ls dispatcher time: 134-135 ms before, 134-135 ms after (n=40, twice). No new process: in an xtrace of `ls`, every new line is a builtin at subshell depth 0.
Allow probing: no new allow. Every allow is an exact proven shape, the same before and after. No false asks on the ordinary list.

## Files (exactly the brief's 8)

- hooks/lib/gitctx.sh: new cw_opt long options. cw reads NAME+=value, compares wrapper names in any case, and reads env --split-string, attached -S<line> and -[0iv]*S. git_words' wrapper gate and shell checks match in any case. Doc comments updated.
- hooks/guards/g01-git.sh: adds _G01_READ_ONLY (the brief's 19 names) and _g01_hidden. _g01_hidden runs for every record whose head is neither git nor gh. GIT_DIR+= and GIT_WORK_TREE+= now set `moved`.
- hooks/guards/g02-pr.sh: adds _G02_GROUPS and _g02_hidden. _g02_hidden runs when gh_sub prints nothing.
- hooks/guards/g05-commit.sh: _g05_env reads NAME+=value (also after export or declare) and compares wrapper names in any case. It takes value options from cw_opt; its duplicate `val` table is removed. _g05_split's gate now matches env and sudo in any case.
- Tests: gitctx.bats +2, g01-git.bats +4 (plus a g1q helper that escapes quotes and backslashes), g02-g04-gh.bats +2, g05-g06-commit.bats +1.

## Design

- Long options in cw_opt:
  - env: --chdir --unset --split-string --argv0
  - sudo: --user --group --host --prompt --chdir --role --type --close-from --other-user --command-timeout (+ --chroot, see D1)
  - nice: --adjustment
  `--opt v` takes the next word. `--opt=v` is one word and is skipped. --split-string's value is split like -S.
- G1 hidden git (_g01_hidden, plain bash over the words G1 already has, no process):
  1. Each later word whose basename is git (any case) is read past git's global options. The skip list was checked against real git 2.54: value options -C -c --git-dir --work-tree --namespace --config-env --attr-source --shallow-file (plus --super-prefix, as G1's own loop lists it), their = forms, --exec-path=, and the flags.
  2. If the next word is in _G01_GIT_CMDS (reused, not copied) and not in _G01_READ_ONLY, G1 asks "git inside <head> cannot be checked; run git directly", and denies under autopilot.
  3. Any other next word gets no vote. git exits 129 on an unknown global option (checked), so nothing runs.
- G2 hidden gh (_g02_hidden):
  1. When gh_sub prints nothing, the record is read with _cmd_words, at one process. This happens only when the text holds `gh`, or `g`, then a quote or backslash, then `h` (so g''h counts), and the first word is not git or gh.
  2. The head must be neither git nor gh. Each later gh word (any case) is read past -R/--repo and its value (also -R<v> and --repo=<v>).
  3. If the next word is in _G02_GROUPS, G2 asks, and denies under autopilot. _G02_GROUPS is every group in gh 2.100.0's `gh help` except browse, search and status. help and version are not listed there.
  4. gh aliases and extensions (co, stack) pass, as they do when called directly.

## Deviations (extensions beyond the brief's text)

- D1. sudo --chroot: the long form of -R. cw_opt already lists -R, and _g05_env already reads --chr as @cwd.
- D2. env -S read as attached or after flags: `env -S'git ...'`, `env --split-string='git ...'`, `env -iS 'git ...'` (flags -0 -i -v before S).
  - Each put the whole line in one word, so no guard saw the git. `env -iS 'git push --force origin main'` was none under autopilot at d87d2a3.
  - `-uS` still reads as -u S, and `env -iC sub ...` is unchanged, so the brief's ask expectation for it holds.
- D3. Shell names in any case: git_words' gate, its eval/shell check, and _split_words' shellin lowercase the name.
  - `BASH -c "git push --force origin main"`, `ENV bash -c "..."` and a here-doc read by BASH were none under autopilot.
  - The gate spells each name with bracket classes, so a capitalised first word that is not a wrapper (such as Rscript) runs no extra process.
- D4. Three related fixes:
  - G1 `moved` now also matches *GIT_DIR+=* and *GIT_WORK_TREE+=*. So `GIT_DIR+=<main>/.git git reset --hard` asks "after cd, --git-dir or --work-tree".
  - The _g05_split gate now matches env and sudo in any case, so `ENV -C sub git commit` gives "could not scan".
  - Because _g05_env now uses cw_opt, `sudo --user root GIT_DIR=/x/.git git commit` finds the assignment. Before, it read `root` as the command word.

## TDD

- RED: `tests/run-bats -f '<9 new names>' <4 files>` gives 7 not ok, each for the expected reason. Examples: "no git push in: env --chdir sub git push origin main", "no git push in: X+=1 git push", "env --ch sub git push --force origin main -> (none)", "caffeinate gh pr merge 1 -> (none)", "want ask, got none for: GIT_DIR+=/x/.git git commit -m 'CDS-2465: x'". The 2 no-vote tests pass before, by design.
- Per item: a bats test stops at its first failing item, so every item also ran through the real dispatcher against an untouched copy of d87d2a3 (git archive) and against the change. Every behaviour-change item is none at d87d2a3 and ask or deny after:
  - G1 hidden rule, ask (deny under autopilot): env --ch sub / env -iC sub ... push --force.
  - G1 hidden rule, deny under autopilot: caffeinate -i, stdbuf -oL git commit -m x, xargs, find -exec \;, `echo git push`, caffeinate g''it, `caffeinate git -C x -c a=b --no-pager push`, builtin command git.
  - G1's own force-push deny, both modes: X+=1 / ENV / `Env --chdir=sub` ... push --force, BASH -c, ENV bash -c, env -iS.
  - G2 ask (deny under autopilot): caffeinate gh pr merge 1, gh -R o/r, g''h, `xargs GH pr merge`.
  - G6 "could not scan": GIT_DIR+=, export GIT_DIR+=, ENV GIT_DIR=, sudo --user root GIT_DIR=, ENV -C sub, Sudo -D.
  - gitctx: all 23 new commands go from none to push. The exception is `env -uS git push`, which is push both times; it pins that -uS is not read as -S.
- GREEN: 9/9. Full set: bats 1..307, 307 ok, rc 0. node 46 pass, 0 fail.

## Allow probing

- Setup: throwaway repos in the scratchpad (scratchpad/t12a/allow). Every probe ran through the dispatcher with all guards, before and after. No push or commit ran.
  - r1: main checkout plus worktree w1 on feat, with an own commit pushed; rebase.push: autopilot.
  - r5: on CDS-2465/replace-minio with the test convention and a clean file staged.
  - r2: on feat with b.md and a gh stub.
- The only allows, identical before and after, are these exact shapes:
  - autopilot: `git -C w1 push -u origin feat`, `... push origin feat >/dev/null 2>&1`, `... | grep git`, `git -C w1 push --force-with-lease origin feat`
  - autopilot: `git commit -m 'CDS-2465: x'` (and with `| grep git`)
  - autopilot: `gh pr create --draft --title x --body-file b.md`
  - the same push, commit and draft under push/commit/pr.policy: auto
- Each wrapped shape is deny under autopilot and ask under the auto policies. Most were none at d87d2a3:
  - push: ENV, Env, X+=1, GIT_DIR+=, caffeinate (-i), stdbuf, env --chdir w1 / --chdir=w1 / --ch / -iC, env --split-string "..." / ="...", env -S'...', sudo --user t, nice --adjustment 5, TIME, NOHUP, Command, BASH -c, ENV bash -c, xargs, find -exec, builtin command, g''it
  - after a push: | ENV cat, | caffeinate cat, | xargs echo, | grep git push
  - lease push: ENV, X+=1, caffeinate, env --chdir, env --split-string
  - commit: X+=1, ENV, Env --chdir=., caffeinate, stdbuf, env --chdir ., env -S, env --split-string, BASH -c, GIT_DIR+=, GIT_INDEX_FILE+=, nice --adjustment, sudo --user, xargs, TIME, | ENV cat
  - draft PR: ENV, X+=1, GH_REPO+=, caffeinate, env --chdir, env --split-string, BASH -c, xargs, | ENV cat, g''h
- Why no allow can appear: every allow path needs the first record to start with the literal text `git ` or `gh `. _cmd_words reads such a record exactly as before, and the hidden rules vote only ask or deny.
- False asks: none, all guards, autopilot on, for: ls, npm test, brew install git, grep -rn "git push" docs, echo "use gh pr create", git status, gh pr list, which git/gh, brew upgrade gh, apt-get install git curl, man git, xargs git status, ps aux | grep git, grep -rn git --include=*.sh ., rg git -t sh, command -v git, type gh, git log --oneline | head -5, npm i -D git-cz, cat .github/workflows/ci.yml, echo git. The first seven also give none with autopilot off.

## Concerns

- C1. A git alias behind a wrapper gets no vote, so it runs under autopilot:
  - `caffeinate git -c alias.p=push p --force origin main`
  - after `git config alias.pf 'push --force'` (no vote), `caffeinate git pf origin main`
  The brief asks only when the next word is one of git's own commands; a direct `git pf` asks through _g01_foreign. Two options for a ruling:
  (a) Ask when a -c or --config-env value before the word sets alias.*. This closes the one-command form with no realistic false ask; a configured alias stays open.
  (b) Ask for any word after a hidden git that is not one of git's own commands, as _g01_foreign does. This closes both, but `apt-get install git curl`, `grep git README.md` and `grep -r git .` would ask.
  Not changed.
- C2. Accepted costs, confirmed by probe:
  - `echo git push`, `man git push`, `ssh host git pull` and `eval git push ...` ask (deny under autopilot). The eval case also carries G1's normal reason.
  - `caffeinate git --foo push` gets none; git rejects the option and runs nothing.
  - The reason names the _cmd_words head, so `env --ch sub git ...` says "git inside sub".
- C3. Still open, out of scope, already there before this task:
  - `$'\x67'it push --force origin main` is none under autopilot, because sw does not decode ANSI-C quoting (the expansion class).
  - env -S lines split on blanks only, so quotes inside them stay part of the words. G5 then reads a wrong subject and denies.
  - env -C/--chdir and sudo -D still leave G1's directory at CWD (the M11 list).
- Contract: docs/plans/contract.md is not in this task's file list and is unchanged. Its gitctx line and its _G01_GIT_CMDS paragraph could name _g01_hidden/_G01_READ_ONLY, _g02_hidden/_G02_GROUPS, NAME+=value, wrappers in any case and the long options.

Scratch harness (not in the repo), under /private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t12a/: probe.sh, table.sh, allowtable.sh, setup-allow.sh, subs.sh, subs2.sh, time-ls.sh, trace.sh, base/ (the d87d2a3 copy).

## Fix round 1 (C1 option (a)): 79bb928

Commit 79bb928 "M1: git behind a wrapper asks when -c or --config-env sets an alias". Paths: hooks/guards/g01-git.sh, tests/hooks/g01-git.bats. g01-git.bats 53/53; shellcheck plain and -x clean.

- _g01_hidden sets `al=1` when a `-c <v>` or `--config-env <v>` value matches `[Aa][Ll][Ii][Aa][Ss].*`, or on an attached `--config-env=alias.*` in any case; it then asks (deny under autopilot) whatever word follows, or when none follows. Other global options are skipped as before; with `al=0` the own-command and read-only checks run unchanged. The comment names the rule and the open configured-alias limit.
- Real git 2.54: `-c ALIAS.zz=version zz`, `--config-env=alias.zz=P zz` and `--config-env Alias.zz=P zz` run the alias; `-calias.zz=version` is "unknown option", so the attached `-c` form is not read.
- Test "git behind a command that sets an alias with -c or --config-env asks, whatever word follows": asks for `caffeinate git -c alias.p=push p --force origin main`; denied under autopilot for that, `caffeinate git -c ALIAS.p=push p`, `caffeinate git --config-env=alias.p=V p`, `caffeinate git --no-pager --config-env Alias.p=V p`, `xargs git -c alias.s=status s`; none for `caffeinate git -c color.ui=never log -1`, `caffeinate git -c core.x=alias.y status`, `caffeinate git --config-env=core.x=V status`.
- RED: the test failed at its first assertion (ask expected, none given). Against a copy of 7c50836 every ask/deny item went from none to ask or deny; no-regression items stay none; `brew install git curl` stays none.

## Fix round 2: 2674f1a

Commit 2674f1a "M1: hidden git asks on any same-command config; gh group aliases ask". Paths: hooks/guards/g01-git.sh, hooks/guards/g02-pr.sh, tests/hooks/g01-git.bats, tests/hooks/g02-g04-gh.bats. g01 and g02-g04 87/87; shellcheck plain and -x clean.

- _g01_hidden: `al` resets at each hidden git word and becomes 1 when `-c <v>`, `--config-env <v>` or `--config-env=<v>` appears among its global options (any key), or when the whole command text (`_G01_CMD`) holds `GIT_CONFIG` (covers an earlier `export ...;` record). With al=1 the hidden git asks (deny under autopilot) whatever follows. The alias.* value checks and `--config-env=*` in the flag list are removed.
- _G02_GROUPS adds cs, skills, agent-tasks, agent, agents, at, extensions, ext, rs (the 9 aliases `gh help <group>` lists for gh 2.100.0; no other group has one).
- Tests: the C1 test is rewritten ("git behind a command with -c, --config-env or GIT_CONFIG in the command asks, whatever word follows"); `caffeinate git -c color.ui=never log -1` is now an ask as ruled; the five review probes plus the export form deny under autopilot; none for `caffeinate git --no-pager log -1`, `echo GIT_CONFIG_COUNT=1`, `GIT_CONFIG_COUNT=0 git status`. New G2 test: the 9 gh group aliases behind another command ask, deny under autopilot.
- RED: both tests failed at their first new assertion. Against a copy of 79bb928 every probe went from none to deny under autopilot; `brew install git curl`, direct `git -c color.ui=never log -1`, `caffeinate gh status` and `brew upgrade gh` stay none.

## Fix round 3: b24a8f8

Commit b24a8f8 "M1: hidden git reads GIT_CONFIG from parsed assignments, not raw text". Paths: hooks/guards/g01-git.sh, tests/hooks/g01-git.bats. g01-git.bats 54/54; shellcheck clean; ls 133 ms avg (n=20).

- The raw `_G01_CMD` GIT_CONFIG substring check is removed. G1 calls `_g01_hidden "$rec" "${w[@]}"`; `_g01_config_set RECORD` exits 0 when G5's `_g05_env` on the hidden git's own record prints a `GIT_CONFIG*` or `+GIT_CONFIG*` line (assignment before the command, after env and the other wrappers, `NAME+=value`), or any record in `_G01_RECS` prints a `+GIT_CONFIG*` line (export, `declare -x`, `typeset -x`, behind wrappers or not, and a record of assignments only). Quotes and escapes are already removed; an argument is never read as an assignment.
- Cost: only records holding `=` are read; the all-records scan runs once per command (`_G01_CONF`, reset in guard_g01), only when a hidden git has a next word the own-command rule does not already ask for. Fails closed if _g05_env did not load.
- A hidden git with no word after it returns with no vote before any check. The `-c`/`--config-env` part of round 2 is unchanged.
- Superset (accepted): a record of assignments only (`GIT_CONFIG_PARAMETERS=x; caffeinate git log -1`) also counts, the same reading G6 uses.
- Test "GIT_CONFIG counts only as an assignment in the parsed records; a git with no word after it gets no vote": the five review examples and two more get none; `git -C <wt> commit -m 'CDS-2465: read GIT_CONFIG_COUNT' | grep git` is allowed again under autopilot; the eval and `bash -c` probes, `env GIT_CONFIG_GLOBAL=...`, `GIT_CONFIG_COUNT+=1`, `command export ...`, `declare -x ...; xargs git p` and the assignments-only record deny under autopilot. RED: failed at `echo $GIT_CONFIG_GLOBAL; which git` (deny). All 11 round-2 deny cases still deny.
