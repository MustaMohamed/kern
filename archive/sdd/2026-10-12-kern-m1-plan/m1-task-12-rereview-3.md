### Spec Compliance

Every round-2 probe now passes. All were re-run on f0b8a8f, all guards, with the decision shown as interactive / autopilot:

- Aliases. `q1`, `q3`, `q7` and `-c alias.zz='"commit"'` give ask / deny. So do the six config-context probes: `cd`, `--git-dir`, `GIT_DIR=`, `HOME=`, `XDG_CONFIG_HOME=` and `-c include.path`.
- `\037` message, UTF-16 `i18n.logOutputEncoding`, and the NUL blob on commit and on push: each gives deny under autopilot.
- `_g01_own` with `log.showSignature` and `gpg.program`: ask, and the marker never runs.
- `-c push.default=matching push`, `-c remote.origin.push=… push` and a mirror remote: ask "could not scan" / deny.
- `env -C <dir> git commit`: ask "could not scan".
- The `GIT_DIR=` message: G6 casts no vote, and all guards allow it under autopilot.
- A hanging gitleaks: ask "did not finish" after 8 s on commit and 9 s on push.

Status by ruling:

- ✅ Alias rule, static list (`g01-git.sh:136-163`). No config is read.
- ✅ Separate message walk (`g06-secrets.sh:151`, `:371`). Both walks run under `with_timeout`.
- ✅ I-4/I-5/I-6: `-c i18n.logOutputEncoding=UTF-8`, `tr '\000' '\001'`, and `--no-show-signature` in `_g01_own`.
- ✅ Minors 1-5 and the round-3 deviations.
- ✅ Time budget. My worst case was `git commit … && git push …` with every `git log` and gitleaks hanging. The hook returned in 14 s, inside the 20 s timeout.
- ✅ bash 3.2. Every probe ran under /bin/bash 3.2 with no breakage.
- ⚠️ Version skew in the static list cannot be tested here: this machine has only Apple Git 2.54 (Minor 4).

### Strengths

- The fail-closed list ends the alias whack-a-mole. It reads no config, so nothing can steer it.
- The message walk is sound. Each case below was probed:
  - empty messages around a key → deny;
  - forged `\001`/hex records → deny, mislabelled only;
  - a merge message → deny;
  - a merge already pushed → none;
  - hex-only messages → none.
- Ordinary commands get no vote:
  - git: `status`, `log`, `diff`, `diff --cached`, `show`, `branch`, `fetch`, `stash list`, `worktree list`, `remote -v`, `rev-parse`, `ls-files`, `version`, `help commit`, bare `git`, `config --get`, `tag`, `describe`, `blame`, `grep`, `shortlog`, `reflog`, `cherry`, `restore`, `range-diff`, `maintenance`, `sparse-checkout`, `--no-pager log`, `-P diff`, `-C dir status`;
  - non-git: `ls`, `HOME=/tmp ls`, `FOO=1 npm test`, `export PATH=…`, `env | grep GIT`, `echo GIT_DIR=x`, `gh pr list`.
- A plain `commit -m` and a push of the current branch still ask interactively and are allowed under autopilot.

### Issues

**Important**

1. **Pre-existing, in gitctx and outside this diff: two command shapes hide git from every guard.**
   - **Append assignments.** `_cmd_words` does not read `VAR+=value` as an assignment. Bash 3.2 runs `GIT_DIR+=x cmd` with `GIT_DIR=x`.
     - `hook $R "X+=1 git push --force origin main"` under autopilot gives `none`.
     - `GIT_DIR+=$O/.git git commit …` (key staged in `O`) gives `none`.
   - **Upper-case wrapper names.** macOS's file system is case-insensitive, so `ENV -C /tmp pwd` runs env. The guards do not read `ENV` as env.
     - `hook $R "ENV git push --force origin main"` under autopilot gives `none`.
     - `ENV -C $O git commit …`, `Env --chdir=…` and `SUDO -D …` all give `none`.
   - This is the same class as Task 12a. Fold it in: accept `+=` in `_cmd_words` and in `_g05_env` (`g05-commit.sh:133,138`), and compare wrapper basenames case-insensitively.

**Minor**

1. **Round-3-authored: `git --version`, `git -h` and `git --help` ask, and are denied under autopilot.** G1's option loop breaks on an option it does not know, and `_g01_foreign` (`g01-git.sh:127-128`) then reads `--version` as a subcommand. Round 2 skipped `-*`.
   - `hook $R "git --version"` gives `ask` / `deny` ("git --version is not one of git's own commands").
   - Fix: `case "$2" in -*) return 1 ;; esac` in `_g01_foreign`. This is safe because every global option that continues to a subcommand is already consumed by the loop. Add `git --version` to the no-regression test.
2. **Round-3-authored: `command export GIT_DIR=…; git commit` is no longer "could not scan".** `_g05_env` treats `command` as a wrapper. The next word, `export`, then ends the scan as a plain command, so `+GIT_DIR` is never printed. Bash 3.2 does run `command export`; verified.
   - G6 gives `none`. Interactive gives only G5's `ask "commit (message checks pass)"`, while the commit lands in the other repo with its key. Round 2 asked here, through its substring check.
   - Under autopilot, G5 denies the shape.
   - Fix: after a wrapper, treat `export`, `declare` and `typeset` as the first word.
3. **Round-3-authored: gitleaks no longer reads pushed messages.** `_g06_finish` (`g06-secrets.sh:372`) gets the patch walk's `args`, which uses `--format=`. In round 2 the single walk carried `%B`.
   - Fix: give gitleaks the message walk too, inside the same budget.
4. **Plan-mandated: the static list is Apple Git 2.54's.** Git resolves a command name in this order: builtin, then an exec-path or PATH program, then an alias. So a listed name that is not a command on the running git falls through to an alias of that name, and every guard votes none. Examples:
   - names newer than the user's git, such as `replay`, `backfill`, `diff-pairs`, `last-modified`, `repo` and `history`;
   - `credential-osxkeychain` on Linux;
   - `send-email`, which distributions package separately.
   
   Allow paths are unaffected: only the builtins `commit` and `push` are ever allowed. Fix: keep exec-path names and recent builtins off the list, or read `git --list-cmds=builtins` once per hook run, which reads no aliases.
5. **Pre-existing: git's `%B` stops at a NUL.** A key after a NUL in a message is pushed but never printed by `git log`.
   - Probe: a commit built with `hash-object -t commit --literally`, its message `head\0 AKIA… tail`, then a push. G6 gives `none`.
   - Building it needs plumbing; `git commit` refuses a NUL.
   - Fix: read raw commit objects (`git cat-file --batch`) for the message walk.

### Assessment

**Task quality:** Approved. Every round-2 finding is closed, nothing round 3 authored reaches a wrong allow, and its three authored defects are Minor: one false deny, one lost "could not scan" behind a G5 ask, and lost gitleaks coverage of messages. The one Important finding is pre-existing gitctx parsing that belongs in Task 12a.
