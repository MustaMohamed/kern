# CI loop

These rules run under a go only, after the draft PR opens and after each push. A person's run keeps finish-branch step 11's single `gh pr checks` read, with no wait.

run.md's stops and report hold here too; where one says the run opens no PR, the PR stays draft. Every stop keeps the PR draft and the go live. Its report opens with a `kern stop: <what>` line naming the stop and each check it concerns, such as `kern stop: class 2 red: deploy-preview`.

## Wait

Start `bash ${CLAUDE_PLUGIN_ROOT}/scripts/ci-wait <wt>` as a background command (the Bash tool's `run_in_background`), `<wt>` being the run's worktree. Read its verdict when it reports.

Never poll with turns: no `sleep`, no `gh pr checks` and no read of its output while it runs. With no other work left, end the turn; its exit brings the verdict back.

Its limit is `ci.wait_minutes`, default 45.

| Verdict | Exit | The run |
|---|---|---|
| `ci: clear`, or `ci: none` for a PR with no checks | 0 | Ready, below |
| `ci: red <names>` | 1 | Read each red, below |
| `ci: pending <names> (timeout <N>m)` | 3 | Stop: the report names each pending check and offers `leave it and mark the PR ready`. A typed reply to wait again starts the wait again |
| No verdict line | 2 | Stop with its stderr line: a usage error or a failed read |

## Read a red

1. `gh pr checks --json name,bucket,link`: a red's run id is the number after `/runs/` in its link.
2. `gh run view <id> --log-failed`, piped to `tail` or `grep` when long. A red with no `/runs/` link has no log: its name and link are the evidence.
3. `git diff origin/<base>...HEAD`, the PR's diff against its base, `<base>` as finish-branch step 3 set it.
4. Whether the branch is behind its base: `gh pr view --json mergeStateStatus` printing `BEHIND`, or behind above 0 in `git rev-list --left-right --count origin/<base>...HEAD` after `git fetch origin <base>`.
5. Sort the red into a class below. The run report gives the last CI verdict, and each red's class with the log line that shows it.

## Classes

| Class | Red | Under a go |
|---|---|---|
| 1 | The PR's change caused it | A CI fix round, below |
| 2 | External, the PR cannot fix it | Stop. The report names the check and why the PR cannot fix it, and offers `leave it and mark the PR ready`, which waives the red. After the user fixes the cause or reruns CI, a typed reply starts the wait again |
| 3 | External, the PR can fix it | Stop and ask whether to fix it here, in another PR, or ignore it, offering `fix it here`, `leave it and mark the PR ready` and `leave it`. `fix it here` runs a CI fix round; `leave it and mark the PR ready` waives the red; `leave it`, or another PR, keeps the red and the PR draft. The run opens no second PR |
| 4 | The branch is behind its base or out of sync | Rebase and lease-push, as Class 4 below says |
| 5 | Red in a file the PR touches, from code the PR did not change | Stop and ask, offering the same three replies as class 3. `fix it here` runs a CI fix round; `leave it and mark the PR ready` waives the red; otherwise the red stays and the PR stays draft |

An unclear red goes as class 2. A self-review `rebase first` goes as class 4.

With reds of several classes, class 1's fix round runs first; one stop then names every red that asks.

Offer each reply in its exact words: G1 reads `rebase and push`, and G2 `leave it and mark the PR ready`, as the user's consent. A bare yes, ok or go ahead gives no consent: ask again in the reply's words.

## Class 4

1. Ask first, as a stop: the report says the branch is behind `origin/<base>` and asks for the reply `rebase and push`. Skip the ask when `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-get rebase.push` gives `autopilot`, or this turn's typed prompt is one G1 reads as a rebase: `rebase and push`, or `rebase` or `sync` alone.
2. Run `git fetch origin <base>`, then `git rebase origin/<base>` in the run's worktree, in its own Bash call.
3. On conflicts, resolve them and prove the result. A resolution that changes behaviour neither side names is a design choice: run `git rebase --abort`, push nothing and stop.
4. Then run Every push, below, with `git push --force-with-lease origin <branch>` as its push. If G1 denies it, stop with `kern stop:` and G1's reason, and leave the body as it was. A rebase is no CI round.

A typed reply's consent holds for its prompt only, and only for the main thread's calls: run the rebase, Every push and the lease push in that turn, with no background wait between.

## CI fix rounds

- Up to 3 per go, counted apart from self-review's rounds.
- A round's number is one more than the highest `CI round: <N>` line in `git log --format=%b origin/<base>..HEAD`, or 1 with none.
- A round fixes the red, commits with `CI round: <N>` on its own line in the message body, then runs Every push.
- When the wait after round 3 is still red, stop: the branch is pushed and the PR stays draft. Round 4 never runs.

## Every push

Every push, each round's push included, runs these in order. The class 4 lease push runs them too, with step 5 before step 4:

1. `test.full` on the tree, by `${CLAUDE_PLUGIN_ROOT}/skills/prove-it/SKILL.md`.
2. Self-review in full on `<wt>`, by `${CLAUDE_PLUGIN_ROOT}/skills/self-review/SKILL.md`, its `review-check` run included.
3. Proof where prove-it says it applies, on this tree.
4. The body: write `<dir>/pr-body.md` again as `${CLAUDE_PLUGIN_ROOT}/skills/finish-branch/references/push-and-pr.md`, section PR, says, so its checks and proof lines match this tree. Then run `gh pr edit --body-file <dir>/pr-body.md` alone.
5. The push: `git push origin <branch>`; after a rebase, the lease push.
6. The wait, above.

A red step 1 or a `fix first` starts run.md's fix round: fix, commit, and run again from step 1. With P the highest package number before this push, round N reviews package P+N+1. When round 3's package, P+4, is still `fix first`, push, stop and keep the PR draft.

## Ready

Commit every change and leave no untracked file before each self-review: G2 reads review-check's record for `HEAD^{tree}`.

Run `gh pr ready` when all hold: the wait after the last push read `ci: clear` or `ci: none`; self-review's verdict on that pushed tree is `ready`, with its `review-check` run; proof is sent or its named skip reported; the body matches the pushed tree.

Run it bare, as its own Bash call from the main thread: exactly `gh pr ready`, with no PR number, `-R`, pipe, redirect or second command.

A `split` verdict on the pushed tree, the draft's own on size included, is a stop that asks split or one PR. A typed `one PR` settles size for this go, so a `split` on size alone then counts as `ready`.

A typed `leave it and mark the PR ready` lets G2 allow it for that prompt only, over any CI, review record or PR head, so the run marks it ready in the same turn.

G2's allow ends the go: end with the run report. On a deny, do once what its reason names, such as a push through Every push or a self-review; a second deny is a stop.
