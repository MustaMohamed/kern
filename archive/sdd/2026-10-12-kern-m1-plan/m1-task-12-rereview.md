### Spec Compliance

- ✅ I-1 `g06-secrets.sh:74` (`--text --no-relative`), and the scan uses `LC_ALL=C grep -a`. The `-diff`, `binary` and `diff.relative` cases deny.
- ✅ I-2 for G6, `_gh_file_ok` and G5. `_g06_git` at `g06-secrets.sh:85-89`. A worktree commit asks (`-a`, `--patc`, `--incl`, `--onl`, `--pathspec-fr=`, `.` all probed).
- ❌ I-2 says "log calls with --no-show-signature" for every guard. `g01-git.sh:385,388` (`_g01_own`) lacks the flag. This is pre-existing code. Details in Issues.
- ✅ I-3: the walk is bounded. With no tracking refs it walks everything; for another remote it asks.
- ✅ I-4: merges read with `--cc`, counting only `++` lines.
- ✅ M5, M6, M7, M8, M9, M13 and M15. M13 probed: `CDS-24650` is denied and `[CDS-2465]` passes.
- ✅ M11 for the listed forms. `command cd`, `\cd`, `'cd'` and `(cd …)` all ask.
- ⚠️ M12 covers the repo config only (Minor 1).
- ✅ M14 as specified, but the marker can be forged (Important 3).
- ❌ Aliases: the check fails open in two ways (Important 1 and 2).
- ✅ Round-2 deviations: kept deleted-file commits, `--no-replace-objects`, `log.showRoot=true`.
- ⚠️ This diff cannot show what Claude Code does when a hook overruns its timeout. That matters for the unbounded gpg run under G1 (Important 6).

### Strengths

- A single streamed walk under `with_timeout`; the patch is never held in a shell variable.
- The parser reads the column count from `@@@`, so the combined-diff counting is correct.
- `_g05_wide` now asks `rev-parse --show-prefix`, which handles case and `sub/..` robustly.
- The tests would fail if the logic broke: the marker file for gpg and fsmonitor, the forged diff inside a message, the evil merge both ways.

### Issues

**Important**

1. **Alias check fails open on the expansion's shape. Round-2-authored.** `g01-git.sh:184-193` splits on whitespace and skips only words starting with `-`. When a head does not resolve as an alias it returns 1, which means pass. Git's split_cmdline strips quotes and backslashes and accepts `-c k=v` in an alias. I verified with real git in a throwaway repo that `q1`, `q3` and `q7` commit.
   - Setup: `git config alias.q1 '"commit"'`, `alias.q3 'com\mit'`, `alias.q7 '-c user.name=Zed commit'`.
   - `hook $R "git q1 -m 'CDS-2465: x'"` gives `none`.
   - `hook $R "git q3 -m x"` gives `none`.
   - `hook $R "git q7 -m x"` gives `none`.
   - `hook $R "git -c alias.zz='\"commit\"' zz -m x"` gives `none`.
   - Under autopilot, `git q1 -am …` and `git q2 --force origin HEAD` (alias q2 = `'push'`) give `none`.
   - A secret in the worktree goes through G6 unseen.
   - Fix: fail closed. A non-builtin subcommand passes only when its expansion's head, after git-style unquoting and skipping `-c X`, `--config-env X` and `-C X`, is in `_G01_ALIAS_SKIP`. Anything else asks.

2. **Alias lookup reads config the command will not use. Round-2-authored.** The lookup always reads CWD, or `-C`, plus the hook's own HOME.
   - Probes, all `none` interactive and autopilot, with `O` holding `alias.ci=commit` and `$S/h3/.gitconfig` holding `ci = commit`:
     - `cd $O && git ci -m 'CDS-2465: x'`
     - `git --git-dir=$O/.git ci -m x`
     - `GIT_DIR=$O/.git git ci -m x`
     - `HOME=$S/h3 git ci -m x`
     - `XDG_CONFIG_HOME=$S/h3 git ci -m x`
     - `git -c include.path=$S/h3/.gitconfig ci -m x` (real git follows the include and commits)
   - Fix: after cd, `--git-dir` or `--work-tree`, with `GIT_DIR=`, `HOME=` or `XDG_CONFIG_HOME=`, or with `-c include*`, treat any non-builtin subcommand like `GIT_CONFIG_*` (`exp='!'`).

3. **A `\037` byte in a pushed message hides the rest of that message. Round-2-authored (M14).** At `g06-secrets.sh:104-107` the first `\037` ends message mode. The text after it on that line is dropped. Later lines then hit `nc < 1 { next }` and are skipped.
   - Probe: `git commit --allow-empty -m "$(printf 'CDS-2465: x\n\nnote\037 AKIAABCDEFGHIJKLMNOP\nAKIAQQQQQQQQQQQQQQQQ')"`, then `hook $R "git push -u origin CDS-2465/replace-minio" g06` gives `none`. The control repo without `\037` gives `deny … message:3 aws-access-key`.
   - All guards under autopilot give `allow`. G1 says "autopilot push of the current branch".
   - Round 1's separate message walk could only mislabel lines, not hide them.
   - Fix: read messages in their own walk (`log --format=%h%x00%B -z`, no patch) and drop `%B` from the patch walk. Any in-band terminator can be forged.

4. **`i18n.logOutputEncoding` hides pushed messages. Pre-existing.** It is the same "repo config hides content" class that I-1 and I-2 target.
   - Probe: `git config i18n.logOutputEncoding UTF-16` plus a commit whose body holds `AKIA…`. G6 alone gives `none`. All guards under autopilot give `allow`. The baseline gives `deny`.
   - Fix: add `-c i18n.logOutputEncoding=UTF-8` to `_g06_git`.

5. **A NUL earlier on a line hides a key. Pre-existing.** `--text` now shows the bytes, but macOS awk (20200816) truncates `$0` at NUL. I verified that awk drops the line and `grep -a` keeps it. Round 1 skipped binary files entirely.
   - Probe: `printf 'hdr\000\001 AKIAABCDEFGHIJKLMNOP\n' >blob.bin; git add blob.bin`.
   - `hook $R "git commit -m 'CDS-2465: x'" g06` gives `none`.
   - After committing it, the push gives `none` for G6 and `allow` for all guards under autopilot.
   - Fix: in `_g06_walk` (`g06-secrets.sh:150`), pipe through `tr '\000' '\001'` before `_g06_parse`.

6. **Named check: `_g01_own` (`g01-git.sh:385,388`) runs `git log` without `--no-show-signature`. Pre-existing; it breaks I-2's "every guard" wording.**
   - Probe: a branch tip with a `gpgsig` header, pushed, then `log.showSignature=true` and `gpg.program=$S/evil10`. Then `hook $R "git push --force-with-lease origin CDS-2465/replace-minio" g01`.
   - The baseline gives `ask`. With the config it gives `deny` ("may hold commits by other authors"), and the program ran once.
   - Without a gpg.program the decision is still `deny`: the gpg output lines reach `$a`, and `_g01_only` rejects them.
   - It cannot produce a wrong allow, because extra lines only fail `_g01_only`.
   - The harm:
     - Users who sign commits and set `log.showSignature` get every lease push denied, interactive and autopilot alike.
     - A program from repo config runs inside the hook with no timeout (⚠️ above).
   - Fix: add `--no-show-signature` to both calls.

**Minor**

1. **M12 does not cover the record's `-c` or `remote.<r>.mirror`. Partly pre-existing.**
   - `git -c push.default=matching push` and `git -c remote.origin.push='refs/heads/*:refs/heads/*' push` give G6 `none`, while an unpushed side branch holds a key.
   - `remote.origin.mirror=true` with `git push` gives the same.
   - Under autopilot G1 denies. Interactive gives G1 `ask "push CDS-2465/replace-minio"`, which names only the current branch.
   - Fix: read `_G05_CFG`, and walk `--branches --tags` under mirror.
2. **`env -C <dir> git commit` makes G6 scan CWD's index. Pre-existing.** It is missing from M11. Interactive gives G5 `ask "commit (message checks pass)"` and G6 `none`.
3. **False "could not scan" from a `GIT_DIR=` substring anywhere in a record. Round-2-authored.** It is matched at `g06-secrets.sh:41`. `git commit -m 'CDS-2465: stop exporting GIT_DIR=.git in ci'` asks, and under autopilot it is denied. Fix: match only on assignment words before the command or in an `export` record.
4. **The gitleaks second pass is not bounded. Round-2-authored.** At `g06-secrets.sh:217` only git runs under `with_timeout`. Bounded, a push can cost up to 16 s plus gitleaks' time.
5. **No test for the autopilot deny on "could not scan"** (`g05-g06-commit.bats:841`).

### Assessment

**Task quality:** Needs fixes. Round 2 lands most rulings cleanly, but it authored three Important gaps: the alias check fails open on the expansion's shape and on config it cannot see, and a forged `\037` hides pushed message text, which ends in an autopilot allow. It also leaves three pre-existing Importants (message encoding, NUL, `_g01_own`), each with a one-line fix.
