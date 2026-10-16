# Task 10 report: G1 git safety

Status: DONE_WITH_CONCERNS

Commit: `e278b2d M1: add G1 git safety` (on `main`, not pushed).

## What I did

- Wrote `tests/hooks/g01-git.bats` and `hooks/guards/g01-git.sh` with the Write tool, transcribing the brief. Then I diffed both files against the brief's code blocks. Both match byte for byte, including the literal tabs in the `git_sub` field split.
- No change to `gitctx.sh` or any other file.

## TDD evidence

RED, guard file absent (`tests/run-bats tests/hooks/g01-git.bats`):

```
1..16
ok 1 status in the main checkout: no vote
not ok 2 switch in the main checkout asks, denied under autopilot
not ok 3 reset --hard, stash and clean in the main checkout ask
#   git reset --hard HEAD ->
ok 4 the same commands in a linked worktree: no vote
not ok 5 a chained or substituted main-checkout command is still seen
ok 6 stash list and clean -n are read-only: no vote
not ok 7 plain force push is denied in both modes
not ok 8 ... not ok 14 (each: expected ask/deny/allow, got no output)
ok 15 kern: off disables the guard
ok 16 unparseable input asks, and the reason names it
```

The failures are the expected ones: every case that expects a vote got none. The no-vote cases and the dispatcher's own fail-closed case passed.

GREEN, with the guard: `1..16`, 16 `ok`, no `not ok`.

Full suite, run once before committing:

- `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats`: `1..164`, 164 `ok`, exit 0.
- `node --test tests/*.test.mjs`: 46 pass, 0 fail.

Shellcheck 0.11.0: `shellcheck hooks/guards/g01-git.sh` and `shellcheck -x hooks/guards/g01-git.sh` both exit 0 with no output. `shellcheck -x hooks/pre-tool-use` also exits 0.

## Files changed

- `hooks/guards/g01-git.sh` (new)
- `tests/hooks/g01-git.bats` (new)

## Deviations

None. Every brief test passed against the brief's code as written. gitctx.sh's current behaviour did not break any brief test.

## Concerns: wrong allows found while self-reviewing

I probed edge cases with a scratch bats file outside the repo (`load` of `tests/helpers/common`, guard `g01`). The brief's tests pass, but these cases get a looser decision than the brief's rules state. I did not change the code. Each item gives the observed output and a minimal correction for the controller to decide on.

1. **A remote branch delete written as `:branch` is treated as a normal push.** `push_targets` strips the `:` and returns `feat`. The `--delete`/`-d` check reads only `$rest`, so the delete path never runs.
   - Autopilot, `git -C wt push origin :feat` gives `allow` ("autopilot push of the current branch feat").
   - Interactive with `push.policy: auto`, the same command gives `allow`.
   - Fix: in the `_shell_words` loop of `_g01_push`, set a delete flag for a word matching `:*` or `+:*`. Then send it to `_g01_destructive` the same way `--delete` is handled.

2. **The own-branch check passes for a ref that does not exist locally.** In `_g01_own_branch`, the line `authors=$(git log ... | sort -u) || return 1` takes its exit status from `sort`, so a failing `git log` gives empty authors, which counts as "own".
   - Autopilot plus `rebase.push: autopilot`, `git -C wt push --force-with-lease origin HEAD:someone-else` gives `allow` ("lease push of own branch someone-else").
   - Fix: run `git log` on its own (`authors=$(git -C "$1" log --format=%ae "origin/$base..$2") || return 1`), then sort. Also require `git rev-parse --verify -q "refs/heads/$2"`. A `src:dst` refspec also needs the source ref checked, not the destination name.

3. **The own-branch check ignores commits that exist only on the remote branch.** It reads `origin/<base>..<local branch>`. A force push drops the commits on `origin/<branch>` that the local branch lacks, and that range is never read.
   - Setup: another author's commit is pushed to `origin/feat`, the local `feat` is reset and recommitted by me, then fetched.
   - `--force-with-lease origin feat` gives `ask` interactively. Under autopilot with `rebase.push: autopilot` it gives `allow`.
   - The brief's rule says a branch with another author's commits is denied.
   - Fix: also collect authors of `origin/<base>..origin/<branch>` when that ref exists, and require every author to be `user.email`.

4. **Under autopilot, `push.policy: deny` is ignored.** With `push.policy: deny`, autopilot `git -C wt push -u origin feat` gives `allow`. The autopilot branch runs before `policy_for push` is read.
   - Design 8.1 D2 lists the autopilot push as allowed. Design line 540 says prose and settings only tighten. A user who set `deny` would expect no push.
   - Fix: read the policy first and vote deny on `deny` in both modes.

5. **Under autopilot, `git push --tags` is allowed as a push of the current branch.** It has no positional refspec, so `push_targets` returns the current branch, while git pushes every tag. `--follow-tags` behaves the same way.
   - Fix: treat `--tags` like a non-current target under autopilot (deny). In interactive mode, ask.

6. **`git branch` force-delete spellings other than `-D` and `--delete --force` get no vote.** `git branch -d -f feat`, `-df feat` and `--force -d feat` all give `none`.
   - Fix: check the words for a delete flag (`-d`, `--delete`, or a short cluster holding `d`) together with a force flag (`-f`, `--force`, or a cluster holding `f`). Any `-D` cluster also counts.

7. Minor: under autopilot a lease push is not limited to the current branch. `--force-with-lease origin other2`, where `other2` is a local own branch, gives `allow`. Design 8.3 says "only on the user's own branches in the current stack", so this may be intended. Flagging it for the controller.

Out of the brief's scope and not counted above: `git pull` and a mixed `git reset` in the main checkout get no vote. D3 does not list them.

---

# Fix round 1: G1 allows only a proven push shape

Status: DONE_WITH_CONCERNS

Commit: `79dea95 M1: G1 allows only a proven push shape` (on `main`, not pushed). Two files changed: `hooks/guards/g01-git.sh` and `tests/hooks/g01-git.bats`. `gitctx.sh` is unchanged.

## Changes, by ruling

1. **An allow needs a proven shape (`_g01_proven`).** G1 votes allow, either the autopilot current-branch push or `push.policy: auto`, only when every one of these holds:
   - `git_words` gives exactly one record;
   - the command holds no `$(` or backtick;
   - the record starts with `git `, and only `-C` options come before `push`;
   - every push token is in the safe set (`--set-upstream`, `--quiet`, `--verbose`, `--no-verify`, bare `--force-with-lease`), a refspec, or a quiet redirection;
   - the remote is listed by `git remote`, and that remote has no `push`, `mirror` or `receivepack` config;
   - there is at least one refspec, and each one pushes the current branch to itself.

   Any other push asks, or is denied under autopilot.
2. **Remote delete is a floor action.** `:x`, `-d`, `-du` and any unique prefix of `--delete` ask whatever `push.policy` says, and are denied under autopilot.
3. **Options are parsed as git parses them.** The new `_g01_opts TABLE WORDS...` (awk) takes its option tables from `git <cmd> -h` (git 2.54) for push, reset, branch, clean and `worktree remove`. It splits short clusters, resolves unique long prefixes and `--no-` forms, and marks unknown or ambiguous options. It reads the exact words from `_cmd_words` instead of re-splitting `git_sub`'s joined `rest`, which lost word boundaries. As a result these are seen: `--force-w`, `--mirr`, `--del`, `reset --har`, `branch -d -f`, `-df`, `--force -d`, `-qD`, `worktree remove --for`, and `clean -fdn` as a dry run.
4. **Lease pushes.**
   - `_g01_own` runs `git log` with no pipe, so a failure means not own.
   - It checks `origin/<base>..<src>`, and also `origin/<base>..refs/remotes/<remote>/<dst>` when that ref exists.
   - The remote must be listed by `git remote`.
   - The source and destination come from each refspec.
   - Under autopilot, `--force-with-lease=<ref>:<expect>` is denied, and the push must also be proven: current branch only, no other flags.
5. **cd before git.** `cd`, `pushd` or `popd` before the git record (including `builtin cd`) makes the directory unknown. Main-checkout operations then ask, or deny under autopilot, and a push never allows.
6. **Policy and other gaps.**
   - `push.policy` is read before any allow, and `deny` denies in both modes.
   - `--tags` and `--follow-tags`, and their prefixes, are outside the safe set, so they are never a current-branch push.
   - `gh -R o/r`, `--repo o/r` and `--repo=o/r` are skipped before matching `pr merge`.
   - `git pull` joins the main-checkout list.

## Additions beyond the rulings, all in the same class

- **`--git-dir` and `--work-tree` make the directory unknown,** in both the `=` form and the separate-word form, as `cd` does. So does a record holding `GIT_DIR=` or `GIT_WORK_TREE=`, such as an inline assignment or `export`. Before this, `git --git-dir $R/.git --work-tree $R reset --hard`, run from a linked worktree, got no vote: `git_sub` reads only `--git-dir=`, and the main-checkout test used the hook's cwd.
- **Words before `push` are an allow list, not a block list.** Only `git` followed by `-C` pairs counts as plain, so `env ...`, `GIT_*=`, `-c`, `--config-env`, `--exec-path=` and the other git global options all make a push unproven. `_g01_git_rec` walks git's global options itself, with a fuller table than `git_sub`.
- **Redirections in an allowed push must write no file.** Only `/dev/null` and fd copies such as `2>&1` pass. Without this, `git push -u origin feat >~/.bashrc` would be allowed.
- **A matching refspec (`:`) counts as `*`, which is protected.** Before, `push_targets` printed an empty target for it, so the brief's code cast no vote.
- `remote.<name>.receivepack` joins `push` and `mirror` in the config check, because it names a program that a push runs.

## Tests

The brief's 16 tests are unchanged and pass; none conflicted with the rulings. I added 13 tests (29 in all), each listing the reviewer's probe cases and mine through an `expect DECISION CMD...` helper:

- Autopilot denies reset, stash, clean, pull, merge, `branch -D`, `worktree remove --force` and `gh pr merge`.
- `pull` asks in the main checkout and gets no vote in a worktree.
- Prefixes and clusters.
- Remote delete in both modes, with `push.policy: auto`.
- `push.policy: deny` under autopilot.
- Autopilot plain shape: 4 allows and 20 denies.
- `push.policy: auto` plain shape.
- `remote.origin.push` and `mirror` config.
- Autopilot lease rules.
- Another author's commit that exists only on the remote branch.
- Lease to an unlisted remote.
- `cd`, `pushd`, `GIT_DIR=`, `--git-dir` and `--work-tree`.
- `gh -R`, `--repo` and `--repo=`.

RED, the new tests against e278b2d: `tests/run-bats tests/hooks/g01-git.bats` gave tests 1 to 16 `ok` and 17 to 29 `not ok`. Each failure was at the behaviour under test, for example:

```
not ok 20 a remote delete asks whatever push.policy says, and is denied under autopilot
# git -C .../wt push origin :feat -> {..."permissionDecision":"allow","permissionDecisionReason":"kern G1: push.policy auto: push feat"}
not ok 22 autopilot allows a push only in the plain shape
# git -C .../wt push -u origin feat && rm -rf /tmp/nothing-here -> {..."allow"..."autopilot push of the current branch feat"}
not ok 26 lease: another author's commit on the remote branch only is denied
# git -C .../wt push --force-with-lease origin feat -> {..."ask"..."force-with-lease push of feat"}
not ok 28 after cd, --git-dir or GIT_DIR the directory is unknown
# cd .../repo && git reset --hard HEAD ->
```

GREEN: `tests/run-bats tests/hooks/g01-git.bats` gave `1..29`, 29 `ok`.

Reviewer probe (`scratchpad/probe/g1-probe.bats`), rerun: every case that was an allow or a missing vote is now deny or ask, with the intended reason. One case still gets no vote: `git -C <worktree> pull origin main`, which is correct because the pull is in a linked worktree. The new output is in `scratchpad/probe/out.after-round1.txt`. I restored the reviewer's original `out.txt`, which the probe appends to, after my rerun.

Full suite, run once before committing:

- `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats`: `1..177`, 177 `ok`, exit 0.
- `node --test tests/*.test.mjs`: 46 pass, 0 fail.
- Shellcheck: `shellcheck hooks/guards/g01-git.sh` and `shellcheck -x hooks/guards/g01-git.sh` exit 0, as does `shellcheck -x hooks/pre-tool-use`.

Timing: one guard run on a push takes about 0.2 s (5 runs in about 1 s).

## Concerns

1. **The allowed shape is strict.** Under autopilot these are now denied: a push piped to `tail`, a push with no refspec, `git push origin` alone, `--dry-run`, `--force-if-includes` and `-o`, because they are outside the safe set the ruling names. The deny reason states the allowed form, so Claude can retry in that form. The controller should decide whether `--force-if-includes` should join the safe set next to the bare lease.
2. **Option tables are pinned to git 2.54.** If a later git adds an option that makes one of these prefixes ambiguous, git rejects the command, which fails safe. Mapping a prefix to a harmless option when git maps it to a dangerous one would need git to add that dangerous option under an existing prefix.
3. **Lease ownership uses `origin/<base>` as the floor whatever the remote.** That follows the ruling. A push to a second listed remote checks that remote's tracking ref, but measures it from origin's base.
4. **Not covered, and outside the rulings:**
   - `git branch -f <existing> <start>` and `-M`/`-C` onto an existing branch move or overwrite a branch without a vote.
   - Config set by an earlier Bash call is not checked: `core.hooksPath`, `push.followTags`, and `remote.<r>.url` pointing at a local path.
   - `xargs` and `find -exec` running git; `with_timeout` (deferred).

---

# Fix round 2: --no-verify is not in the safe set

Status: DONE

Commit: `1b85152` `M1: G1 treats a --no-verify push as unproven` (on `main`, not pushed).

## Change

- `hooks/guards/g01-git.sh`: removed `--no-verify` from the safe set in `_g01_push`, and the comment there now says why. A push carrying it is unproven, so it asks, or is denied under autopilot. The option tables still list `no-verify`, so `_g01_opts` parses it and does not mark it unknown.
- `tests/hooks/g01-git.bats`: new test `--no-verify skips the pre-push hook, so the push is never allowed`. It covers `push --no-verify origin feat` and `push -u --no-verify origin feat`: ask with `push.policy: auto`, deny under autopilot.

## Tests

RED, the new test against 79dea95:

```
not ok 30 --no-verify skips the pre-push hook, so the push is never allowed
# git -C .../wt push --no-verify origin feat -> {..."permissionDecision":"allow","permissionDecisionReason":"kern G1: push.policy auto: push feat"}
```

GREEN:
- `tests/run-bats tests/hooks/g01-git.bats`: 30 `ok`, no `not ok`.
- Full suite `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats`: `1..178`, 178 `ok`, exit 0.
- `node --test tests/*.test.mjs`: 46 pass, 0 fail.
- Shellcheck on `hooks/guards/g01-git.sh`, with and without `-x`: exit 0.

---

# Fix round 3 (rider): filters, --dry-run, --force-if-includes, deny reasons

Status: DONE

Commit: `6c7d348 M1: G1 allows read-only filters after a push and names the fix` (on `main`, not pushed). Two files changed: `hooks/guards/g01-git.sh` and `tests/hooks/g01-git.bats`.

## Changes

1. **Read-only filters.** `_g01_proven` no longer requires a single record. The push must be the command's first record, and every later record must pass the new `_g01_filter`:
   - The record starts with `tail`, `head`, `grep` or `cat`. A wrapper or assignment fails.
   - Options come from that filter's closed table (`_G01_TAIL_OPTS`, `_G01_HEAD_OPTS`, `_G01_GREP_OPTS`, `_G01_CAT_OPTS`), parsed by `_g01_opts`. None of the listed options reads a file, so `grep -r` and `grep -f` fail.
   - head and tail also take `-NUM`, but not after `--`, where `-5` is a file name. A probe found this; it is pinned by `tail -- -5`.
   - Redirections must be quiet ones (`/dev/null` or an fd copy).
   - There is no file argument. grep may take one argument, its pattern, when no `-e` gives the pattern.

   The `$(` and backtick check still covers the whole command. A `bash -c` filter fails, because `git_words` emits the `bash -c` record itself.
2. **`--dry-run` and `--force-if-includes` join the safe set.** `--force-if-includes` still sets the lease path. It needs `rebase.push: autopilot` under autopilot, and it is denied when the branch, local or remote, holds another author's commits.
3. **Deny and ask reasons name the fix.**
   - A bare push (no refspec): `name the remote and branch: git push -u origin <current>`, filled in with the current branch. A bare lease push gives `git push --force-with-lease origin <current>`.
   - Any other unknown shape: ``kern allows only `git push [-u] <remote> <current-branch>` unattended``. A lease push gives the `--force-with-lease` form of the same sentence.
   - A push after cd, `--git-dir` or `--work-tree`: `run git -C <dir> push instead of cd, --git-dir or --work-tree`.

   These reasons apply to the autopilot deny and to the interactive ask, under any `push.policy`.

## Test changes against earlier rulings

These cases changed because the rider reverses them:

- `git push -u origin feat | tail -1` moved from deny to allow in "autopilot allows a push only in the plain shape".
- `--force-with-lease --force-if-includes origin feat` moved from deny to allow in "autopilot lease". `--force-with-lease -o ci.skip origin feat` replaces it as the non-safe-flag deny.

## New and changed tests (34 in all)

- **Filters:** 9 allows, including `2>&1 | tail -5`, `| head -3`, `| grep -i error`, `| grep -e a -e b`, `| cat -n`, a two-filter chain, and `| tail -5 >/dev/null`.
- **Filter denies (14):** a file argument to tail, cat or grep; `grep -e x file`; `grep -r`; `grep -f`; `tail >file`; `tee`; `sh`; `xargs`; `env tail`; `tail -- -5`; a filter before the push; `bash -c 'tail -5'`.
- **Filters under `push.policy: auto`:** allow for a filter, ask for `tee`.
- **`--dry-run`:** `-n` and `--dry-run -u` are allowed under autopilot.
- **`--force-if-includes` follows the lease rules:** denied under autopilot without `rebase.push`, allowed with it. Denied, alone and with a lease, when the remote branch holds another author's commit.
- **Reasons:** a bare `git push` and `push origin feat:other` each assert the exact fix text, both under autopilot (deny) and under `push.policy: auto` (ask).

RED, the new tests against 1b85152: 5 tests failed at the rider's behaviour, and 29 passed. Examples:

```
not ok 25 autopilot lease ... --force-with-lease --force-if-includes origin feat -> deny "autopilot lease push only as git [-C dir] push ..."
not ok 26 --force-if-includes follows the lease rules ... -> deny
not ok 32 an allowed push may pipe into ... push -u origin feat 2>&1 | tail -5 -> deny
not ok 33 --dry-run is a safe push option ... push -n origin feat -> deny
not ok 34 an unknown push shape names the fix in its reason
```

The first green run had one failure: `| tail -- -5` was allowed. The `--` fix above closed it.

GREEN:
- `tests/run-bats tests/hooks/g01-git.bats`: 34 `ok`.
- Full suite `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats`: `1..182`, 182 `ok`, exit 0.
- `node --test tests/*.test.mjs`: 46 pass, 0 fail.
- Shellcheck on `hooks/guards/g01-git.sh` with and without `-x`, and `-x` on `hooks/pre-tool-use`: exit 0.

## Notes

- `git_words` does not keep separators, so a filter may follow the push after `;` or `&&` as well as `|`. With options only and no file it can read only stdin and write only stdout, so the separator does not change what the command can do. A filter before the push is still denied.

---

# Fix round 4 (re-review round 2): symbolic-ref, expanded words, push config

Status: DONE_WITH_CONCERNS

Commit: `ee842f4 M1: G1 reads the branch by symbolic-ref and refuses expanded push words` (on `main`, not pushed). Five files changed: `hooks/guards/g01-git.sh`, `hooks/lib/gitctx.sh`, `tests/hooks/g01-git.bats`, `tests/hooks/gitctx.bats` and `docs/plans/contract.md`.

## Changes

1. **Same-named tag.** `current_branch` in `gitctx.sh` reads `git symbolic-ref -q HEAD` and strips `refs/heads/`. On a detached HEAD it prints nothing and exits 1; before, it printed `HEAD`. G1 already refused an empty current branch, and `push_targets` prints an empty target there; nothing else calls it. I also updated the contract line for `current_branch` in `docs/plans/contract.md` to say this. Drop that line if the contract is not mine to edit.
2. **Expansion in push words.**
   - `_g01_proven` refuses a push record holding `$`, `{` or `}`.
   - The current branch and the remote must consist of `_G01_NAME_CHARS`, which is `[A-Za-z0-9._/-]` written out letter by letter so that no locale's collation can widen it. I checked it on bash 3.2: `é`, space, `*` and `]` are refused.
   - Addition: `_g01_filter` refuses a filter record holding `$`, `{`, `}`, `*`, `?` or `[`. Without this, `| grep -e *` and `| grep {x,-r}` expand into file arguments. The cost is that a filter such as `grep 'error$'` is now refused.
3. **C3 pins.** Two tests:
   - `base_branch: nosuch` with `rebase.push: autopilot` and `push --force-with-lease origin feat` gives deny.
   - `push --force-with-lease origin other:feat`, where `other` holds a foreign commit, gives deny (interactive).

   I checked them against the reviewer's two mutants (copies in `scratchpad/g01mut`). The `| cat` mutant fails only the first test; the dst-as-src mutant fails only the second. Both pass at HEAD.
4. **Push config.** `remote.<n>.vcs`, `remote.<n>.pushurl` and any `url.<base>.pushInsteadOf` join push, mirror and receivepack: when set, the push is not proven. That is one `git config --get-regexp` with ERE alternation; I checked on git 2.54 that the alternation works and that keys come back lowercased (`pushinsteadof`). One test pins the receivepack arm and each new key, then checks the push is allowed again once the keys are removed.
5. **Minor.**
   - git and gh match in any case through `[Gg][Ii][Tt]` and `[Gg][Hh]`, as a bare word or after a path, without a fork. A record that does not start with lowercase `git ` is still not plain, so `GIT push` is never allowed.
   - The `val` branch stays. A test asserts its reason: `--force-with-lease=<ref>:<expect> under autopilot; use the bare option`. Without the branch, the odd-word path would deny with the generic reason.

## Tests

New tests, 44 in g01-git.bats:

- a tag named like the current branch: `push origin HEAD`, `-u origin @`, the same with no `-C`, a lease push of HEAD (deny), and an interactive push under `push.policy: auto` (ask);
- a tag named like a `branch.protected` branch;
- shell expansion in a push record: the three probes;
- expansion or a glob in a filter (my addition);
- remote and url config;
- the two C3 pins;
- case-insensitive git and gh;
- the reason for an explicit lease value.

One new test in gitctx.bats: `current_branch` past a same-named tag, and on a detached HEAD.

RED against 6c7d348 (all tests at that point): every new behaviour test failed; the C3 pins and the `val` reason passed, as pins should. Examples:

```
not ok 35 a tag named like the current branch does not hide it
# git -C .../repo push origin HEAD -> {..."allow","permissionDecisionReason":"kern G1: autopilot push of the current branch heads/main"}
not ok 37 shell expansion in a push record is never allowed
# git -C .../wt push origin main$X -> {..."allow"..."current branch main$X"}
not ok 38 shell expansion or a glob in a filter is never allowed
# ... | grep -e * -> allow
not ok 39 remote and url config that redirects a push makes it unproven
# (vcs arm) git -C .../wt push origin feat -> allow
not ok 42 git and gh are matched case-insensitively
# GIT push --force origin main ->
not ok 64 current_branch reads HEAD by symbolic-ref, past a tag of the same name
```

After the fix, I put the old `gitctx.sh` back into a copy of the tree. Both tag tests failed there at the tag step ("current branch heads/rel"), and both pass with the new one.

GREEN:

- `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats`: `1..192`, 192 `ok`, exit 0. That includes gitctx.bats.
- `node --test tests/*.test.mjs`: 46 pass, 0 fail.
- Shellcheck, with and without `-x`, on `g01-git.sh`, `gitctx.sh` and `pre-tool-use`: exit 0.

Reviewer attack probe, rerun against a copy so their `attack.txt` stays untouched (output in `scratchpad/g01probe/attack-r2.txt`). Every changed decision moved from allow or no vote to deny or ask. These are:

- A: the tag cases;
- B: the three expansion cases;
- C: `GIT` and `Git` push, and `GH` merge;
- H: pushurl, pushInsteadOf and vcs.

Still allowed, as intended:

- `push.recurseSubmodules`: earlier-call config, which you recorded as an accepted limit.
- `remote.Origin.push` with remote `origin`: config subsections are case-sensitive, so it configures a different remote.

## Concerns

1. **Pre-existing bug in `hooks/lib/settings.sh:152`, not fixed here.** `list_has` trims items with `sed 's/^[ \t]*//; s/[ \t]*$//'`. In BSD sed, `[ \t]` matches a space, a backslash or the letter t, so on macOS `feat` becomes `fea` and `test` becomes `es`.
   - Effect: `branch.protected: feat` protects nothing, and `deploy.envs: prod, test` drops `test`. I confirmed that `branch_protected feat` returns false with that setting. Linux GNU sed reads `\t` as a tab and is fine.
   - The brief's test asked for `branch.protected` with a tag `feat`. It uses `rel` instead, with a comment that names the bug.
   - I asked about fixing it in this round and got no answer before committing. Proposed fix: trim in bash with `${item#"${item%%[![:space:]]*}"}` and the matching suffix form, which also saves a fork per item, plus a settings.bats case for an item that starts and ends with t.
   - Also, the probe's `branch.protected: [feat]` is not a list in kern settings, which are comma-separated with no brackets, so `[feat]` protects nothing on any OS.
2. **The filter charset check is strict.** A common filter such as `grep 'error$'` is refused, and the autopilot run gets the deny reason and must retry without it.

---

# Fix round 4b: list_has in its own commit, then round 2 again

Status: DONE

Commits, on `main` and not pushed:

- `f2c704d M1: list_has trims whitespace in bash, not BSD sed`
- `f8427b0 M1: G1 reads the branch by symbolic-ref and refuses expanded push words`

## Commit order

The `list_has` fix had to land before the round-2 commit, so I undid that commit. `ee842f4` had not been pushed: `git branch -r --contains` was empty and the tree was clean. `git reset HEAD~1` (mixed) kept its changes in the working tree. I then committed the `list_has` fix on its own, and committed round 2 again with the same subject and body. `f8427b0` replaces `ee842f4`, which is still in the reflog, and so replaces the commit SHA in round 4 above. The round-2 content is unchanged except that the tag test uses `feat` again.

## list_has (`hooks/lib/settings.sh`)

- **Fix:** each item is trimmed with bash parameter expansion, `${item#"${item%%[![:space:]]*}"}` and the matching suffix form. This replaces `sed 's/^[ \t]*//; s/[ \t]*$//'`, and it removes one fork per item.
- **Test:** a new settings.bats test, `list_has keeps items that start or end with t, in branch.protected and deploy.envs`, checks these:
  - `feat` and `test` are found in `"feat, test"`;
  - an item with a trailing tab is trimmed;
  - `fea` and `es` are not found;
  - `branch_protected` is true for `feat` and `test` with `branch.protected: feat, test`, and again with `deploy.envs: test, feat` alone;
  - `fea` is not protected.
- **RED** against 6c7d348 with the sed version:

  ```
  not ok 1 list_has keeps items that start or end with t, in branch.protected and deploy.envs
  #   `list_has "feat, test" feat' failed
  ```

  GREEN: settings.bats gives 10 `ok`.
- **f2c704d on its own:** I ran it in a temporary detached worktree, without the uncommitted round-2 changes. The full suite (`tests/run-bats tests/hooks/*.bats tests/scripts/*.bats`) gave `1..183`, 183 `ok`, exit 0. I then removed the worktree and ran `git worktree prune`.
- **Shellcheck on settings.sh:** one SC2016 info note at line 97 (`sed -n 's/^| `\([^`]*\)` |.*/\1/p'`), which predates this change; HEAD's version gives the same note. My edit adds no new findings. The note is not in the CI shellcheck set (`scripts/ci-local` checks only `fetch-upstream` and `ci-local`).

## Sweep: `\t` inside a sed or grep pattern under `hooks/` and `scripts/`

I listed every line holding `\t` in those trees, other than `.mjs` files. Only one was a sed or grep pattern with `\t` in brackets: `hooks/lib/settings.sh:152`, fixed above. The rest are not affected:

- **awk regexes, where `\t` is a tab:**
  - `settings.sh:29, 33, 41, 44, 90, 92`;
  - `gitctx.sh:33, 46, 144, 145, 171, 179, 193`;
  - `g16-state.sh:133, 140`;
  - `json.sh:9, 23, 42`.
- **`printf` formats:** `settings.sh:118`, `gitctx.sh:331`, `scripts/kern-get:17`, `scripts/kern-detect:18`.
- **json.sh:88, sed with a literal tab:** the sed pattern is a literal tab from `$(printf '\t')`. The `\\t` is in the replacement, where a literal backslash-t is the intended output.
- **json.sh:95:** `tr -d ' \t\r\n'`, and `tr` reads `\t` as a tab.
- **render.sh:120:** `awk -F '\t'`.

I also checked the same files for other GNU-only escapes in sed or grep patterns (`\s \S \w \W \d \b \B \+ \? \| \< \>`). There are none.

## Tag test

`a tag named like a branch.protected branch does not hide it` uses `branch.protected: feat` and `git tag feat` again, and the workaround comment is gone. It passes. With the old `current_branch` put back in a copy of the tree, it fails at the tag step (`... -> allow ... current branch heads/feat`).

## Full suite after f8427b0

- `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats`: `1..193`, 193 `ok`, exit 0.
- `node --test tests/*.test.mjs`: 46 pass, 0 fail.
- Shellcheck, with and without `-x`, on `g01-git.sh`, `gitctx.sh` and `pre-tool-use`: exit 0.

Concern 1 of round 4 (`list_has`) is resolved. Concerns 2 and 3 of round 4 stand.

---

# Fix round 5 (closing rider): glob words, push URL, detached HEAD, YAML lists

Status: DONE_WITH_CONCERNS

Commit: `0e1191e M1: G1 refuses glob words and checks the push URL the remote uses` (on `main`, not pushed). Four files changed: `hooks/guards/g01-git.sh`, `hooks/lib/settings.sh`, `tests/hooks/g01-git.bats` and `tests/hooks/settings.bats`.

## Changes

1. **Pins.**
   - Test 37 gains the `T/w$X` case: a worktree on branch `g` sits in a dir literally named `w$X`, and `git -C T/w\$X push origin g` gives deny.
   - A new test pins each name check on its own. Branch `fe!at` (`git push origin fe!at`) pins the branch-name check. Remote `o!x`, added with `git remote add`, pins the remote-name check: `git push o!x feat` gives deny. So a case where the remote check alone decides does exist. `!` is valid in a ref and a remote name, is never expanded by a non-interactive shell, and is not refused by the record check.
2. **Glob characters.**
   - The push record also refuses `*`, `?`, `[` and `~`.
   - The comment above `_g01_proven` now lists all seven characters and describes the push-URL check.
   - New test: `x1` has a pushurl and `x[1]` is a clone, both on `feat2`, and `git -C T/x[1] push origin feat2` gives deny. A worktree in a dir literally named `~` under the cwd gives `git -C ~ push origin t2`, which also gives deny.
3. **Push URL.**
   - The pushurl and `url.*` config arms are gone. `_g01_proven` now requires `git remote get-url --push --all <remote>` to equal `git config --get-all remote.<remote>.url`, and that value to be non-empty.
   - The push, mirror, receivepack and vcs arms stay.
   - Tests:
     - an unrelated global `url.git@github.com:.pushInsteadOf https://github.com/` still allows;
     - `url.<else>.insteadOf <remote url>` gives deny (the new case);
     - pushurl and a pushInsteadOf that matches the remote still deny (the existing test).
   - `--all` on both sides compares every push URL, so a remote with two `url` values is allowed only when neither is rewritten.
4. **Detached HEAD.** When `current_branch` fails:
   - `fix` is `HEAD is detached; check out a branch first`;
   - an implicit target, or a `HEAD`/`@` destination, reads `HEAD` instead of an empty string;
   - the protected-branch reasons and the lease reasons that do not use `fix` get `; HEAD is detached; check out a branch first` appended.

   The broken reasons the probe showed are gone: `push ; name the remote and branch: git push -u origin `, `force-with-lease push of `, and ` may hold commits...`. Decisions are unchanged. The test covers `push`, `push origin HEAD` and `push --force-with-lease origin HEAD` interactively (ask), and `push`, `push origin HEAD` and `push --force-with-lease` under autopilot with `rebase.push: autopilot` (deny). Each asserts the detached text.
5. **YAML flow lists.** `list_has` trims the whole list and drops one pair of brackets around it, so `branch.protected: [feat]` protects `feat`. The settings.bats test checks:
   - `list_has "[feat]" feat`;
   - `list_has "[ feat, test ]" test`;
   - that `[feat]` itself is not an item;
   - that `branch_protected feat` is true with `branch.protected: [feat]`.

## Tests

RED against f8427b0, after adding the tests: 4 failures at the new behaviour, and the two pin tests (37, 38) passed, as pins should.

```
not ok 39 a glob or ~ in a push record is never allowed
# git -C .../x[1] push origin feat2 -> {..."allow"..."autopilot push of the current branch feat2"}
not ok 46 a push URL rewritten for this remote is unproven; an unrelated rewrite is not
# git -C .../wt push origin feat -> {..."deny"...}      (the unrelated global pushInsteadOf case)
not ok 47 a detached HEAD names itself in the reason
# git -C .../wt push -> {..."ask","permissionDecisionReason":"kern G1: push ; name the remote and branch: git push -u origin "}
not ok 57 list_has reads a YAML flow list in brackets
```

GREEN: g01-git.bats and settings.bats give 58 `ok`.

Mutants (copies in `scratchpad/g01mut2`). Each check was removed on its own:

| Check removed | Fails | Case that turns into allow |
|---|---|---|
| record check | 37 and 39 | `-C T/w$X`, `-C T/x[1]` |
| branch-name check | 38 | `fe!at` |
| remote-name check | 38 | `o!x` |
| glob characters only (back to `$ { }`) | 39 | `x[1]` |
| `~` only | 39 | `-C ~` |
| push-URL compare | 41 and 46 | pushurl, insteadOf |

Full suite:

- `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats`: `1..198`, 198 `ok`, exit 0.
- `node --test tests/*.test.mjs`: 46 pass, 0 fail.
- Shellcheck:
  - `g01-git.sh`, with and without `-x`: exit 0.
  - `-x` on `gitctx.sh` and `pre-tool-use`: exit 0.
  - `settings.sh`: only the SC2016 info note at line 97, which predates this work.

## Concerns: new finding, not fixed

**A trailing comment hides a command from G1 (Important; pre-existing since the brief's code).**

`_split_words` skips separators inside a top-level comment but keeps the comment text in the record, and `_cmd_words` reads `#x` as a word. Probe in the main checkout (`scratchpad/g01probe/comment.bats`):

```
autopilot on
deny  | git clean -fd
none  | git clean -fd # -n
none  | git clean -fdx # --dry-run
deny  | git merge main
none  | git merge main # --abort
```

The shell drops the comment, so git runs `clean -fd` and `merge main`, while G1 reads the `-n`, `--dry-run` or `--abort` from the comment and casts no vote. Comment words can only add words, so every other G1 rule becomes stricter, not looser. The holes are the three exemptions: clean's dry-run, merge's `--abort`, and stash's `list`/`show`, which is already safe because the comment comes after it.

Proposed fix, in gitctx.sh (not authorized this round): in `sw()`, an unquoted `#` at the start of a word ends the words, as in POSIX shell. That covers `_shell_words`, `_cmd_words` and every guard. A G1-only workaround (dropping words after a `#` word) would be wrong, because `_cmd_words` has already removed quotes, so a quoted `'#'` argument would also cut later words such as `--force`.

A related note: the existing case `git -C $W push -u origin feat # \$(true)` is denied by the extra comment words, so it does not pin the `$(` check on its own. The record check (`$`) also catches it.

---

# Fix round 6: a word that starts with an unquoted # ends the shell words

Status: DONE

Commit: `e711e33 M1: a word that starts with an unquoted # ends the shell words` (on `main`, not pushed). Three files changed: `hooks/lib/gitctx.sh`, `tests/hooks/gitctx.bats` and `tests/hooks/g01-git.bats`.

## Change

`sw()` in `_GW_AWK` is the only change in gitctx.sh. When an unquoted, unescaped `#` starts a word (no character of the word read yet), sw skips to the next newline (`\n` or the record's `\037`) and goes on from there. The comment's words are dropped, as bash drops them.

For a one-line command, that ends the words. Across a newline inside `$( )`, scanning resumes after the newline, as in bash, so a word after that newline (such as a `--force`) still reaches the guards.

`_shell_words`, `_cmd_words` and `shellin()` all share `sw()`, so every guard gets the fix.

## Tests

- **gitctx.bats, helper `words_are STR WORD...`:**
  - `a word that starts with an unquoted # is a comment to the newline`:
    - `git status # note` gives `git status`;
    - `git clean -fd # -n` gives `git clean -fd`;
    - `a # b` then `c` on a new line gives `a c`;
    - `_cmd_words 'git status # note'` gives `git status`.
  - `a # inside a word, quoted or escaped is kept`: `echo a#b`, `echo ${#x}`, `echo $#`, `echo '#x'`, `echo "#x"`, `echo \#x` and `git log --format=%h#%s` keep their words.
- **g01-git.bats:** `a trailing comment does not hide a command`. `git clean -fd # -n`, `git clean -fdx # --dry-run` and `git merge main # --abort` in the main checkout ask, and are denied under autopilot.

RED against 0e1191e, with the tests added:

```
not ok 24 _shell_words: a word that starts with an unquoted # is a comment to the newline
# git status # note -> git
not ok 79 a trailing comment does not hide a command
# git clean -fd # -n ->
```

The keep-the-`#` test passed before the change, as a no-regression test should.

GREEN:

- `tests/run-bats tests/hooks/gitctx.bats tests/hooks/g01-git.bats`: 79 `ok` (31 + 48), no `not ok`.
- Full suite `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats`: `1..201`, 201 `ok`, exit 0, 89 s.
- `node --test tests/*.test.mjs`: 46 pass, 0 fail.
- Shellcheck, with and without `-x`, on `hooks/lib/gitctx.sh` and `hooks/guards/g01-git.sh`, and `-x` on `hooks/pre-tool-use`: exit 0.

## Note

The earlier focused run looked slow because one command ran both files twice and went past the 120 s tool limit. It was not hung: it finished with 79 `ok` and no failures. Your run (6 s and 36 s per file) and my full run (89 s) agree.
