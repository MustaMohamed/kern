# Task 12 report: Guard G18, the read-only investigator

Status: DONE_WITH_CONCERNS. Commit 139caac `M2: add guard G18 for the read-only investigator` on main, not pushed.

## Implemented

- `hooks/guards/g18-readonly-agent.sh` (new): `G18_AGENTS="kern:investigator"`, `g18_allowed`, `guard_g18`, plus a helper, `_g18_expands`. Votes `deny` only.
- `hooks/pre-tool-use`: `KERN_GUARD_IDS` now ends in `g18`.
- `tests/hooks/g18.bats` (new): the brief's 8 tests verbatim, plus 4 tests for the holes listed below.
- `docs/spikes/m1-payloads.md`: the brief's `G18 path: A ...` line, appended.
- `CHANGELOG.md`: the brief's line under `## [Unreleased]`.

The commit subject and the first body paragraph are the brief's. A second paragraph explains the hardening.

## Where the code goes beyond the brief, and why

The brief's code passed the brief's tests: 24 of 24 for g18 plus pre-tool-use, with shellcheck clean. Self-review then found 25 commands that the brief's code allowed, all of which write a file or run a program. All 25 are listed in the TDD section. Each shape below was confirmed to write or execute in a scratch directory, with macOS bash 3.2 and zsh, BSD sort, file 5.41, git 2.54 and rg 15.2. GNU sed 4.9 and GNU sort were confirmed in `kern-ci:task17`.

1. **Quotes and escapes.** The brief matched options against the raw text. As a result, `sort "-o" out.txt a.txt`, `find . '-delete'`, `find . -dele''te`, `git '-c' core.pager=sh log`, `rg '-z'` and `file '-C'` all got through. So did `sed -n 1p '-i' a.txt` and `sed -n 1p \-i a.txt`; in the image, GNU sed rewrote a.txt for the quoted form. The fix judges options on `_shell_words` output, which is the word list the shell passes with quotes and backslashes removed.
2. **Expansion.** `sort {-o,out.txt} a.txt`, `sed -n 1p {-i,a.txt}`, `sort ${x:--o} ...`, `echo -o; sort $_ ...`, `sort $'-o' ...` and the brief's own `"$p"` form all build an option at run time. The new `_g18_expands` denies a `$` or backtick outside single quotes, and any unquoted `{`. One exception remains allowed: a brace pair right after `@` with no `,` or `..` inside, such as git's `HEAD@{1}` or `@{u}`, which never expands. `sed -n '$p'` stays allowed because its `$` is single-quoted.
3. **Redirect boundaries.** The brief stripped `[0-9]*>&[0-9]` and `>/dev/null` with no check on what follows. So `cat a.txt >&1x` (bash and zsh write `1x`), `2>&1y` (zsh writes `1y`) and `>/dev/nullx` were allowed. The strips now require whitespace or the end of the text after the match, and `&>/dev/null` is stripped whole.
4. **Abbreviations and clusters of options the brief lists.**
   - `git grep --op=cat` and `git grep -nOcat` both ran the pager program. git grep accepts abbreviated long options, and `-O` takes an optional value inside a short-option cluster.
   - `sort --out=` wrote a file (BSD and GNU). `sort --co=` is accepted as `--compress-program`.
   - `file --comp -m m` and `file -bC -m m` wrote `.mgc` files.

   The checks added: `--op*` for git, `-[!-]*O*` for git grep, `--o*` and `--co*` for sort, `--co*` and `-*C*` for file. `git diff --outp` and `--ext-d` are rejected by git itself, since diff and log options take no abbreviations, so `--output*` needs no prefix rule.

Every addition only tightens. No command the brief allowed is newly denied, except forms that are themselves holes, such as `"$p"`. The brief also asked to check `sort -o`/`-uo` and `file -C`: it covers both, and both now also hold under quotes, clusters and abbreviations.

## Tests and results

- `tests/run-bats tests/hooks/g18.bats tests/hooks/pre-tool-use.bats`: 28 of 28 on macOS. The brief's expected 24 became 28 because of the 4 added tests.
- `tests/run-bats tests/hooks`: 462 of 462 on macOS.
- `tests/run-bats tests/scripts`: 188 of 188.
- `node --test 'tests/**/*.test.mjs'`: 74 pass, 0 fail.
- `node scripts/lint-skills.mjs`: clean.
- `bash tests/hook-shape.sh`: 8 cases passed.
- `shellcheck -x -S warning` and plain `shellcheck` on the guard: no output. `shellcheck -x -S warning` on `hooks/lib/*.sh`, `hooks/guards/*.sh` and `hooks/pre-tool-use`: no output.
- Ubuntu, in `kern-ci:task17` with the repo mounted read-only at /kern-repo (GNU sed 4.9, bash 5.2.21, git 2.43, bats 1.10): g18.bats 12 of 12.

## TDD evidence

1. The brief's tests ran before any guard existed: tests 3, 4, 5 and 7 failed (the deny tests), and so did test 8 (the dispatcher list). Tests 1, 2 and 6 passed. This is the RED the brief expects.
2. After the brief's guard and the id were added: 24 of 24.
3. The 4 hole tests were added while the brief's code was still in place: tests 4, 5 and 6 failed. A direct `g18_allowed` run printed ALLOW for all 25 hole commands.
4. After the fix, all 25 print DENY.
5. One test case was wrong: `'sed -n \"\$p\"'` reaches the shell as `"\$p"`, a literal `$` that is correctly allowed. It was corrected to `\"$p\"`. After that, 28 of 28.

## Self-review

- **Ways a read-only-looking command could write or run code:**
  - Redirects: denied. Only `N>&M` and `/dev/null` targets are stripped, and only when they end their word.
  - `-o` and `--output`: denied as described above.
  - Pagers: `git grep -O` and its abbreviations are denied. A `-p`/`--paginate` pager only starts on a TTY and comes from the user's own config.
  - Editors, xargs, `sh -c`, eval, wrappers and `VAR=` prefixes: not on the allowlist, so they are denied.
  - `find`: `-delete`, `-exec*`, `-ok*`, `-fprint*` and `-fls` are matched as whole words after quote removal.
  - `git -c` and `--config-env` are denied. `git grep -O` is covered above.
  - Substitutions: `$( )`, backticks and `<( )` are denied. `git_words` also splits their bodies out, and zsh `=( )` and glob qualifiers split into records whose first word is not on the allowlist.
- **Interfaces:**
  - `g18_allowed` still takes one simple command and needs only the libraries that Task 18's parity test sources (json, settings, state, decide, gitctx).
  - Task 18's sample commands pass: `rg -n 'ERROR|WARN' app.log`, `sed -n 1,20p`, `sed -n 1200,1260p app.log` and `sort -rn counts.txt`.
- **bash 3.2:** tests ran under /bin/bash 3.2 through run-bats. The guard uses no arrays, no `${x,,}` and no `local -`.

## Concerns

1. **`rg --hostname-bin=PROG` runs PROG.** With `--hyperlink-format='{host}...' --color=always`, rg 15.2 ran a repo-local `./h.sh` and the script wrote a file. This was confirmed in a scratch directory. It is code execution through an allowlisted command, and the brief does not list it, so it was not added, per your instruction. Proposed fix: in the rg branch, add `--hostname-bin*` to the deny case, plus a test.
2. **`file -z`/`-Z` (`--uncompress`) runs decompressor programs from PATH**, the same reason the brief gives for denying `rg -z`. The brief does not list it, so it was not added. Proposed fix: add `-*z*`/`-*Z*` and `--un*` to the file branch.
3. **Accepted limits, not fixed:**
   - An unquoted glob can expand to a pre-existing file whose name looks like an option, such as a file named `-i` with `sed -n 1p *`. The agent cannot create such a file.
   - `git -C`/`--git-dir` pointed at a repo whose own `.git/config` sets `core.fsmonitor` or `diff.external` runs that repo's program.
   - `git diff` and `git describe --dirty` may refresh `.git/index`, which is git's own stat cache.
   - `sort -T` writes temp files that it then deletes.
4. **Brief deviation.** The guard is not the brief's code verbatim. Its structure, deny list, allowlist and reason text are the brief's. Option checks now run on shell words, and the expansion check, redirect boundaries, abbreviations and clusters are additions. The changes are listed above so a reviewer can judge them against the brief.
5. **Spike line placement.** Appended as the brief says, the line follows the "Other observations" paragraph with no blank line, so it renders as part of that paragraph. The file is a line log, and "one line" was kept.

## Fix report: rg --hostname-bin and file -z (lead ruling)

Commit 5d6d51a `M2: G18 denies rg --hostname-bin and file -z`. It touches `hooks/guards/g18-readonly-agent.sh` and `tests/hooks/g18.bats` only. There is no new CHANGELOG line: the existing G18 line covers the change, and lint is clean.

- **rg branch:** `--hostname-bin*` is now denied. That covers `=PROG` and a separate `PROG` argument, and it also holds when the word is quoted, because options are judged on shell words. rg takes no abbreviations: `--pr` was rejected as an unrecognized flag.
- **file branch:**
  - `-z` and `-Z` are denied anywhere in a short-option cluster: `-*z*` and `-*Z*`, for example `-bz` and `-bZ`.
  - Every `--u*` word is denied. On file 5.41, `--unc`, `--uncomp` and `--u` are ambiguous, but `--uncompress-n` was accepted. Only `--uncompress` and `--uncompress-noreport` start with `--u`.
- **TDD:** a new test, "an option that runs a program is denied: rg --hostname-bin, file -z and -Z", has 10 commands. RED: the test failed at its first case, and a direct `g18_allowed` run printed ALLOW for all 10. GREEN: all 10 print DENY, while `file a.txt`, `file -b a.txt` and `rg -n foo src` still print ALLOW.
- **Results:**
  - g18.bats: 13 of 13 on macOS (bash 3.2 through run-bats), and 13 of 13 in `kern-ci:task17` (Ubuntu, GNU sed 4.9).
  - `tests/run-bats tests/hooks`: 463 of 463.
  - shellcheck: clean on the guard, both plain and `-x -S warning`, and on `hooks/lib/*.sh`, `hooks/guards/*.sh` and `hooks/pre-tool-use`.
- **Accepted limits:** unchanged from the report above (globs that match an existing option-named file, `git -C` into a repo with a program in its config, git refreshing the index).
