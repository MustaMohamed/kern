# kern M3 part 2, project 2: autopilot to ready

Approved by the user, 2026-11-05 ("Approve design"). Part 2's overview is `docs/specs/2026-11-03-kern-m3-part2-overview.md`; its rules for every project and its project 2 rulings apply here. Project 1's design is `docs/specs/2026-11-03-kern-m3-part2-p1-design.md`. Lines marked "my call" are the designer's; the rest are the user's words or accepted playback.

## Intent

A go ends today when its draft PR opens. The overview moves the finish line to a PR whose CI is green, marked ready: "the autopilot should finish the work until the PR is ready without CI issue". Project 2 builds the CI loop that gets there, proof on the running app when a change needs it, and a Stop hook that holds a go to the finish line. Its first task lands the four audit clauses project 1 held back, and it closes or measures the items project 1's paid check carried here.

## Goals

| # | Goal |
|---|---|
| 1 | A go ends at `gh pr ready` on its own PR, or at a reported stop |
| 2 | Each CI red goes into one of the user's five classes and gets that class's handling |
| 3 | A change that needs proof on the running app gets screenshots, a video or a GIF, sent to the chat; with no setting, a named skip |
| 4 | The Stop hook holds a go to goal 1, with at most 3 send-backs in a row |
| 5 | Turn-end nudges for unproven edits and lowered floors: opt-in outside a go, a send-back under one |
| 6 | The four audit clauses land first; each carried item closes or is measured |
| 7 | No gate falls under the overview's exit rule |

## Non-goals

- Watching a ready PR, review threads, CI flake classes and stacks: project 3.
- Holding a plain `/kern:autopilot on` run to its stop predicate. The user: "it's in text so I can't define it", "go runs only".
- A rule for one project's red, such as a version bump after a release: "the version bump can't be a general rule, because not all the projects have this".
- Opening a second PR when the user sends a class 3 red to another PR. The run records the answer and leaves the red (my call).
- The run rerunning CI itself. The user reruns it or fixes the cause outside the PR, then replies (my call, from the class 2 ruling).
- A CI loop outside a go. A person's finish-branch keeps today's single `gh pr checks` read (my call).
- Merge and deploy, as in part 1.

## Anti-goals

- A PR marked ready while a gating check is red and the user never waived it.
- A rebase or lease push the user did not approve, by a typed word or the project's settings.
- Model turns that poll CI. The wait is one background command.
- A Stop hook that traps a session: every fault and `kern: off` allow the stop.
- New noise in a person's session by default.

## User rulings, 2026-11-05

| Ruling | Words |
|---|---|
| Which reds the run fixes | "The reds related to the PR changes, but if it's and external checks in the CI and can't be fixed in the PR leave it and inform the user" |
| The five classes | "1. red because of the PR (should fix) 2. red external the PR can't fix (shouldn't fix) 3. red external the PR can fix (should fix after user approval if not approved leave it, might be out of PR scope then user design to solve in this PR or in another PR or ignore) 4. red because the PR is outdated or not in sync (should fix) 5. red because of changes in files PR touches but not related to the PR changes (should fix with approval, if not approved leave it)" |
| A class 2 red | "keep draft and inform me, maybe and can fix it externally or rerun the CI" |
| How class 4 syncs | "rebase and force-push with lease" |
| When class 4 asks | "I think the user should be informed before rebase and force push on outdated branch but if the user already approved or asked to rebase and push or sync the PR should do automatically" |
| Where proof goes | "the chat" |
| Video | "the video if for things changes over time and needs to be noticed (can be GIF too) or when the user asks for a video during the verification steps or record the whole flow" |
| No setting for the app | "should skip and tell the user without blocking the work, except for the skills that should enforce verification like verification skills or proof it works and so" |
| Stop hook scope | "go runs only" |
| Send-backs before the turn ends | "ok 3" |
| CI wait limit: 45 minutes, a project setting | "yes agree" |
| Nudges outside a go | "Opt-in (Recommended)" |
| The PR body after a fix | "should update the body" |
| Rebase conflicts | "resolve and prove" |
| A PR with no CI | "mark as ready" |

The user accepted four playbacks with "good": the CI loop, proof, the Stop hook and the rest. Their guesses stand as accepted: the go holds while a stop waits; a typed "rebase", "push" or "sync", or `rebase.push: autopilot`, is the approval class 4 needs; each fix or rebase reruns `test.full` and self-review before its push; CI fix rounds cap at 3; the classes are general, the run sorts each red from its log and the diff, and a project may name checks that never gate; the go's finish line counts a running CI watch as waiting; the hook also checks the size ask and, under a go, the report's skip lines.

## The finish line

| Item | Contract |
|---|---|
| Ready | `gh pr ready` on the go's own PR when all hold: CI is clear; self-review's verdict on the pushed tree is `ready`, with its `review-check` run; proof is sent or a named skip is reported; the PR body matches the pushed tree |
| CI clear | Every check on the PR's head passed, but those `ci.advisory` names. A PR with no checks counts as clear ("mark as ready") |
| Waived | A red the user leaves is waived only by a typed reply in the words G2 reads, such as `leave it and mark the PR ready`; G2 then allows `gh pr ready` on that prompt's consent. Each stop that can end in a waiver offers that reply in those words, as finish-branch step 7 does, and a bare yes gives no consent. No waiver is stored (my call) |
| The go's life | The go holds from the draft PR until `gh pr ready`, `/kern:autopilot off`, a second go or the session's end. Its approval of specs and plans ends when the draft PR opens (my call), so a CI fix approves nothing |
| At a stop | The PR stays draft, the go holds, and a typed reply picks the run up again, as run.md's stops do today. After the run reports its first stop, the Stop hook's finish-line check stands down for the rest of the go: the user is back, and a later turn may be an unrelated question (my call) |
| Self-review | "self review should be as today and run the mandatory check before opening a PR" (overview); it runs again before every later push |

## The CI loop

Under a go only. After the draft PR opens and after each push, the run waits for CI and sorts each red.

| Step | Contract |
|---|---|
| Wait | One kern script waits on `gh pr checks --watch` with the time limit and prints one line per check and a verdict line. The run starts it as a background command, so no model turn polls (my call; the script's name and output are the builder's) |
| Limit | `ci.wait_minutes`, default 45. Past it the run stops, the PR stays draft, and the report names each pending check |
| Read a red | The failed job's log and the PR's diff against its base. The report gives each red's class with the log line that shows it |
| Unclear class | A red the run cannot place goes as class 2 (my call) |

| Class | Red | Under a go |
|---|---|---|
| 1 | The PR's change caused it | A CI fix round: fix, `test.full`, self-review in full, proof where it applies, update the body, push, wait |
| 2 | External, the PR cannot fix it | Stop: PR stays draft, the report names the check and why the PR cannot fix it. A typed reply after the user fixes the cause or reruns CI starts the wait again; `leave it and mark the PR ready` waives it |
| 3 | External, the PR can fix it | Stop and ask whether to fix it here, in another PR, or ignore it, offering the replies `fix it here`, `leave it and mark the PR ready` and `leave it` (my call on the words). The first runs a CI fix round, the second waives the red, the third keeps the PR draft |
| 4 | The branch is behind its base or out of sync | Tell the user and ask for the reply `rebase and push`, the words G1 reads; a bare yes gives no consent (my call). Then rebase onto `origin/<base>` and lease-push. No ask when the user already gave the word: `rebase.push: autopilot`, or a last typed prompt that asks to rebase, push or sync. Conflicts: resolve and prove. A resolution that changes behaviour neither side names is a design choice and stops the run (my call, from run.md) |
| 5 | Red in a file the PR touches, from code the PR did not change | Stop and ask, offering the same three replies as class 3. `fix it here` runs a CI fix round; otherwise the red stays, and the PR stays draft unless the reply waives it |

| Item | Contract |
|---|---|
| Fix rounds | CI fix rounds count apart from self-review's rounds, up to 3 per go. A third round still red pushes, stops with the report and keeps the PR draft. A rebase is no fix round (my call) |
| Every push | `test.full` on the tree, self-review with its `review-check` run, proof where it applies, then `gh pr edit --body-file` so the body's checks and proof lines match ("should update the body") |
| A person's run | finish-branch keeps step 11's single `gh pr checks` read with no wait |

## Proof on the running app

| Item | Contract |
|---|---|
| When | A change to what someone sees or does on a screen: screenshots of the changed screens |
| Video or GIF | Something that changes over time and needs to be noticed, or when the ticket's verification steps or the user ask for a video or a recording of the whole flow |
| Where | The chat. In the desktop app the run sends the files with its `SendUserFile` tool; elsewhere the report lists their paths under `kern-dir tmp`. The PR body says in text what was checked, with no images |
| How | Only through a project setting: `verify.browser` for a web app, as today, and a new `verify.app` for a simulator or emulator (my call on the name). With neither, the run skips the proof, names the skip in its report and goes on |
| Required | When the ticket or a verification step names the check, or prove-it proves "UI works", the check is required. A required check that cannot run stops the run, as run.md says today |
| Tree | On the tree being pushed, after `test.full` and before the draft PR opens. A later fix moves the tree, so the proof runs again before that push, as the emulator walk's rule in `skills/prove-it/references/evidence.md` says |

## The Stop hook

`hooks/stop` keeps project 1's self-review check for every session. Project 2 adds three checks; one reason lists every check that fails (my call).

| Check | Contract |
|---|---|
| A go's finish line | Under a live go with no stop reported yet, a stop is allowed when G2 allowed `gh pr ready`, when the turn's last message reports a stop on a fixed line the run writes, or while a background task the run started, the CI wait or a subagent, has not reported back (my call: under a go, tasks run in background subagents, and the main thread ends its turn to wait). Otherwise the hook sends the run back with a reason that names what is missing: the draft, the CI wait, an unhandled red, a push after a fix, or `gh pr ready` |
| Send-backs | At most 3 in a row ("ok 3"). The third reason asks the run to end with its report, saying it stopped short; the next stop is allowed. A user's prompt or a background task's report resets the count (my call) |
| A go's report | Each skip line `review-check` printed in the turn is named in the report. This closes `go-no-lint-draft`'s missing `verify.fast` skip line |
| The proof skip | Where the report is read, under a go with no wait open until the run reports a stop and in the report a go owes after `gh pr ready`: a report that names `verify.browser`, `verify.app` or the running app, with neither setting set and no `kern stop:` line, holds prove-it's line `skip: proof on the running app, no verify.browser or verify.app` as printed, or the hook sends it back for that line. Under a go the send-back counts toward the 3. This closes `go-proof-skip`'s reworded skip line, missed in paid rounds 1 and 2 (the round 2 fix batch; the user's "Build the Stop hook check", 2026-11-05) |
| The size ask | When the turn ran `scripts/size-check` and it printed a `size: ask:` line, the turn's last message carries that line as printed, or the hook blocks once. This closes the size-ask known limit |
| Nudges | Unproven edits: a main-thread Edit, Write or NotebookEdit after which the turn ran no proving command (gap 21). A lowered floor: `floor-scan` finds a new suppression, a skipped or deleted test, a removed assert, an empty catch or a debug print in the diff those calls made (G7, design 8.3). A proving command after the last edit clears the first; the turn's last message naming each hit with its reason clears the second. Subagents' work is left to `task-done` and `review-check` (my call). Outside a go they run only with `stop.nudge: on`, once per turn. Under a go they always run, and a send-back counts toward the 3 |
| Faults | Every fault and `kern: off` allow the stop, as today |

## Guards under a go

| Guard | Change |
|---|---|
| G2 | `gh pr ready` on the go's own PR is allowed when CI is clear, read at the call, or the user's last typed prompt says to mark it ready; otherwise denied. It ends the go. A person's run keeps today's ask |
| G2 | `gh pr edit --body-file` on the go's own PR, with the body file checked as `gh pr create`'s is, is allowed; every other `gh pr edit` option stays denied |
| G2 | A draft PR no longer ends the go; it ends the go's approval power |
| G1 | A lease push of the go's branch is allowed with `rebase.push: autopilot`, as today, or when the user's last typed prompt asks to rebase, push or sync. Every commit on the branch past the base must still be the user's |
| G1 | A Write, Edit or NotebookEdit in the go's own main checkout, outside the work dir, is denied: a go's work lives in a kern worktree, as implement says. This closes the main checkout edits that followed G1's denied switch in paid rounds 1 and 2 (the round 2 fix batch; the user's "Build the G1 deny", 2026-11-05) |
| Self-review's half of ready | A mechanism, guard or hook, keeps `gh pr ready` off a tree self-review did not pass (the builder's choice) |
| G20 | A main-thread Write, Edit or NotebookEdit under the main worktree's root and outside the work dir, of a file that is no test by its path, is denied until a spec under `WORK/specs` carries the go's approval, or the run has read diagnose: a go's build starts at define, a bug at diagnose. This closes `go-required-check-stop`'s build with no spec, five of six paid runs (the round 2 fix batch; the user's "Build the G20 gate", 2026-11-05). The same gate denies a main-thread commit that takes such a file, staged or, with `-a`, tracked, whatever wrote it, since round 7's `go-required-check-stop` wrote its build by a shell redirect, which the gate does not see, and committed it (the round 7 fix batch; the user's "Both fixes, then round 8 (Recommended)", 2026-11-05) |

Semver: each change above loosens a default, a MAJOR change under design section 12, decided at the next release bump; kern is at 0.x.

## Settings

| Key | Default | Read by |
|---|---|---|
| `ci.wait_minutes` | `45` | the CI wait |
| `ci.advisory` | none; check names that never gate ready | the CI loop, G2 |
| `verify.app` | none; how to start and drive the app on a simulator or emulator | prove-it, the proof step |
| `stop.nudge` | `off`; `on` turns on the nudges outside a go | `hooks/stop` |

Key names are my call.

## First task: the audit's four clauses

From `docs/research/opus-audit-2026-10-22.md` section 5, as project 1's design, Audit adopt rows, held them. Each lands as its Take column says, and project 2's paid round measures it.

| Row | Clause |
|---|---|
| L482 | diagnose: "tighten the loop" and "a perf baseline first" |
| L488 | `skills/prove-it/SKILL.md:21` and the kernel's Evidence line: the gate covers any word that implies done, fixed or passing |
| L489 | prove-it step 7: never hand the user a check you can run |

A raised cap names its row.

## Carried from project 1

| Item | Contract |
|---|---|
| `go-block-reroute` meets no guard | A fixture where the run tries a delete that G21 judges outside the worktree before any stop-list read catches it, so G21 votes and a reworded route is tried. Paid round 1 met run.md's stop on the new fixture before any delete, so on the user's "Grade the stop (Recommended)" the case grades that stop since the round 1 fix batch, and no exec case measures a guard-block reroute |
| `go-no-lint-draft` approves its plan before the plan review | A mechanism, not wording, keeps the approval lines out of a plan before its review |
| `go-no-lint-draft`'s report names no `verify.fast` skip | The Stop hook's report check above |
| The plan skip | Paid round 1 reads whether plan-path go runs write a plan and a ledger. A fall goes to the user |
| run.md:68's report verdict | Paid round 1 reads `go-bug-draft`'s report for self-review's verdict |
| The eval runner loses a transcript on output overflow or a signal | The runner keeps the transcript in both cases |
| `recall-sessions` sees other runs' sessions in a parallel round | Each run's `recall-sessions` lists only that run's sessions |

## Evals

The exec `gh` stand-in (`evals/exec/bin/gh`) grows a scripted CI: checks that stay pending, go red, or pass after a push, a failed job's log, `gh pr ready` and `gh pr edit`. New go cases, one behaviour each (my call on the set; the builder may merge cases that share a fixture):

| Case | Wants |
|---|---|
| Class 1 | Fix, push, green, `gh pr ready` |
| Class 2 | No fix, PR draft, a stop naming the check |
| Class 3 | A stop asking here, another PR or ignore |
| Class 4, no approval | A stop before any rebase |
| Class 4, `rebase.push: autopilot` | Rebase, lease push, green, ready |
| Class 5 | A stop asking for approval |
| No CI | `gh pr ready` after self-review |
| CI timeout | A stop naming the pending check, with a short `ci.wait_minutes` |
| Proof skip | A screen change with no `verify.browser` or `verify.app`: the named skip, then ready |

Each go case records `stopBlocked`. The Stop hook's checks get bats rows on recorded transcripts. The plan states a round's expected cost before the first paid round.

## Proof

| Step | Contract |
|---|---|
| Per task | Focused suites green; full `scripts/ci-local` once before the task merges |
| Paid check | One round after the batch, on the user's yes, under the overview's rules. It also reads the carried items marked "paid round 1" and the four audit clauses |
| Gates | The overview's exit rule. New grader rows gate from the round they first run in; a case a new row turns red in its first round goes to the user, not into a fix loop |
| Limit | 3 rounds; a fourth only on the user's yes |

## Order of work

My call. The audit clauses first, by the brief. Then the guards and the go's life, since every later step runs under them. Then the CI wait and the CI loop's text, then proof, then the Stop hook, which reads what the loop writes. Then the carried items and the eval runner, then the `gh` stand-in and the cases, then the docs, then the paid check. Each task ends with its focused suites green.

## Docs

Design 5.4 gets the four keys, 6.3's Stop row the new checks, 8.1's D2 and D10 rows and 8.3's G1, G2 and G7 rows the changes above. The skills spec, CHANGELOG and coverage gaps 20 and 21 follow. A test pins each changed line, as in project 1.

## Open risks

- Exec runs are headless. Whether `claude -p` waits for a background command is unverified; the builder checks it before a case depends on it. With the stand-in a foreground wait fits the Bash tool's limit.
- The run sorts reds by judgment. A class 1 read on an external red spends a fix round; the cap of 3 bounds it.
- G2 reads CI over the network at the call, as it already does for the dedup check.
- A rebase rewrites pushed history. The lease, the approval and the user's-commits rule bound it. A project with signed commits re-signs through the user's own git config; kern signs nothing.
- `skills/autopilot/references/run.md` sits at its 7,337-byte cap, so the CI loop likely needs its own reference file.
- Nine new exec cases raise a round's cost.

## Left to the builder

- The CI wait script's name, arguments and output.
- How G2 reads CI, and the mechanism for self-review's half of ready.
- The stop line's format, how the hook sees a running CI wait, and where the send-back count lives.
- How `verify.app` starts and drives each surface and takes its captures.
- How the run tells a PR with no checks from one whose checks have not registered yet.
- The approval-order mechanism, the `go-block-reroute` fixture and the case fixtures.
- Which file holds the CI loop's text.
