# kern M3 part 2, project 1: part 1 leftovers

Approved by the user, 2026-11-03 ("Approve both"). Part 2's overview is `docs/specs/2026-11-03-kern-m3-part2-overview.md`; its rules for every project apply here. Each item's evidence is in `docs/research/2026-10-31-m3-item-sort.md`, and an item below is named as its row there is. Lines marked "my call" are the designer's; the rest are the user's words or accepted playback.

## Intent

Part 1 closed with 33 items its paid check left open and one known limit, self-review skipping its proofs after `fix first`. On the user's "all should be fixed", project 1 closes them before part 2's features build on the same skills, graders and guards. It also lands the audit's M3 adopt rows and the user's carve-out for a project's own hook files.

## Goals

| # | Goal |
|---|---|
| 1 | Each of the 33 items closes by the contract below, pinned by a test, a lint or a grader row |
| 2 | `workflow-self-review-proofs` passes through a mechanism, not wording |
| 3 | A go commits a project's own files under `hooks/lib` and `hooks/guards` |
| 4 | 19 of the audit's 22 M3 adopt rows land, or are recorded as already closed; four clauses in the other 3 rows wait for project 2, as Audit adopt rows says |
| 5 | No gate falls under the overview's exit rule |

## Non-goals

- Projects 2 to 6.
- The 55 rows under the item sort's "Later". Where an adopt row and a Later row name the same finding, project 1 does the adopt row's take and the rest of the Later row stays (my call).
- Fixture 5, which the real round grades.
- A change to `pressure-prove-it-deadline`'s text before a round reads it.

## Anti-goals

- A wording-only fix for self-review's proofs: two wording rounds did not move it.
- A grader loosened to pass a case. The size ask is graded on the reply.
- A carve-out that reaches kern's own installed hook code or its session state.
- A measure loop past 3 rounds without the user's yes.

## User rulings, 2026-11-03

| Ruling | Words |
|---|---|
| All 33 items are fixed | "all should be fixed" |
| One paid check after the batch, at most 3 rounds | "shouldn't make the check after finishing a batch?", "3 rounds only, any more should with my approval" |
| A project's own hook files pass under a go | "Carve out all projects": only kern's installed hook code keeps the block |
| `pressure-prove-it-deadline` | "Watch it first": read it in the paid round before any text change |
| diagnose step 7's derived-data sentence | "Measure it" in the first round that runs h2h diagnose |
| The size ask | "The reply must carry it": the question the user sees names the measure and the source |
| U1's reach | "Yes, first builds too" |

## Paid round 1 rulings, 2026-11-04

The user's words on round 1's reds (tree 7057f41).

| Ruling | Words |
|---|---|
| Goal 2, `workflow-self-review-proofs` at 0 of 3, is fixed in this project | "Fix it in project 1" |
| The mechanism is a Stop hook: `hooks/stop` blocks a stop once when the turn's last read of the running kern's self-review has no `review-check` run after it, and project 2 extends it for autopilot's stop | "Stop hook (Recommended)" |
| `go-no-lint-draft`'s approval order and `go-block-reroute`'s fixture go to project 2 | "Carry to project 2 (Recommended)" |
| `go-required-check-stop`: commit's no-PR end names the red check as `fail` in the message body, cap 6,062 to 6,072 | "Take the fix (Recommended)" |
| Round 2 is a targeted rerun: it spends plan's grace and reruns the 3 voided exec cases, `go-required-check-stop` and h2h review | "Targeted rerun (Recommended)" |

The controller's rulings on round 2's fix review, 2026-11-04, scope the Stop hook. A read counts only after the user's last prompt, so a read in an earlier turn no longer blocks a later one. A Read, `cat`, `sed` or `head` counts only on the running kern's own `skills/self-review/SKILL.md`, under kern's root or `CLAUDE_PLUGIN_ROOT` resolved physically, and a Skill call naming `kern:self-review` or `self-review` still counts. A `grep -F -q` for `self-review`, on the transcript and then on the turn, allows with no parse when either lacks it. `kern: off` allowing the stop stands, and round 2's rerun reaches `workflow-self-review-proofs` and every case the hook reaches.

## Paid round 2 rulings, 2026-11-04

The user's words on round 2's reds (tree b7bd1fb), before round 3, the project's last paid round, which measures all four changes.

| Ruling | Words |
|---|---|
| Exec reds: `checkFailNamed` also takes a check's name quoted with the ticket's own words when only the closing quote stands before `fail`, and run.md's required-check stop commits with the check named `fail` in the message body, cap 7,282 to 7,330 | "Grader fix and run.md line" |
| Round 3 measures the Stop hook: `ISOLATION` drops `--no-session-persistence`, and after each run the runner keeps the session's transcript beside the run's stream file, removes the session's folder under the eval config dir and records whether the hook blocked | "Measure the hook (Recommended)" |
| h2h review's decoy d3: self-review step 9 clears a wrapped test, a stricter assertion on the same value and an `assertion-removed` hit whose line an assertion as strict or stricter replaced, cap 9,199 to 9,325 | "Fix it now" |
| Behaviour's window for a targeted round: each case pools its last two rounds | "Per case (Recommended)" |

## Paid round 3 rulings, 2026-11-04

The user's words on round 3's reds (tree e7afc48).

| Ruling | Words |
|---|---|
| Exec's model-noise reds are ruled noise: `finish-split-nine-files`, `go-reaches-draft`, `go-no-lint-draft`'s plan and ledger rows and `go-required-check-stop`'s spec row, and the plan skip in both plan-path go runs is watched | "Rule noise, watch plan (Recommended)" |
| Three small fixes: run.md's report gives self-review's verdict, cap 7,330 to 7,331; the Stop hook's reason asks for the whole report again, its verdict from the `floor:` line; the hook's turn finder skips `api-request-blob` lines | "All three (Recommended)" |
| Round 4, past the project's 3 paid rounds, reruns h2h review alone: 3 runs of its 5 arms | "h2h review only, 15 runs (Recommended)" |

The controller's ruling on this batch: the four Stop hook Minors round 2's fix review deferred land with these fixes, since the batch changes `hooks/stop` anyway. A `stop_hook_active` that json.sh reads as malformed allows, a word of 1,024 bytes or more names no command, commit's size sentence quotes "Take the fix (Recommended)" in full, and a row pins a single-quoted path.

The controller's rulings on the batch's concerns, before its review: the hook's scan skips `api-request-blob` lines too, since an assistant blob copies a message's calls and could be written after a later call, and run.md's report names self-review's own `fix first` where it named the lane's `needs fixes`, cap 7,331 to 7,329. A second ruling restores the lane's word, which go-mandated-defect-stop's grader reads: the report gives self-review's verdict, and any lane's `needs fixes` as it came, cap 7,329 to 7,337.

## Guards and scripts

| Item | Contract |
|---|---|
| Staging a project's own hook file stops a go | A write, edit, copy, move or `git add` of a `hooks/lib/*.sh` or `hooks/guards/*.sh` file that does not resolve under `KERN_ROOT/hooks` gets no G16 vote in either mode. That holds in a kern checkout or worktree too, where `_g16_foreign` (`hooks/guards/g16-state.sh:1028`) asks today. The test is "under `KERN_ROOT/hooks`", not "under `KERN_ROOT`", so a go's worktree under the checkout kern runs from is a project path (my call). Running or sourcing a hook file outside `KERN_ROOT/hooks`, and any write or run of a hook entry file (`pre-tool-use`, `prompt-submit`, `session-start`, `subagent-start`), keep today's ask (my call): a copy of kern's hooks run by hand reaches the live session's state through `state_dir`'s fallback (`hooks/lib/state.sh:6`). The bats rows that pin an ask on running or sourcing stay. A path G16 cannot resolve keeps today's ask (my call). The forged-hook and state blocks stand. The header's "Open for part 2" note goes |
| Design 8.3's G16 row lacks the `git add` limit | The row states the carve-out and its limits |
| G16 has a second quote parser | G16 reads quotes through `git_words`'s parser; its own copy goes |
| A copy into `hooks/guards/` gets no vote | A copy or move into `$K/hooks/guards/` and a write to `hooks.json` under `KERN_ROOT` get G16's hook-file vote; tests pin denied forms and normal shapes only |
| A nested repository and thin contract rows | A test row for guard reads in a nested repository, and one for each `docs/plans/contract.md` line the final review named as thin |
| `wt-fork` leaves its fork on a failed include | Exit 2 from `wt_include` removes the fork, as exit 1 does |
| A failed substitution reads as no conflict | `hooks/prompt-submit:129` uses the sentinel idiom, so a failed `scripts/skill-conflicts` reads as an error |

## Run rules and skills

| Item | Contract |
|---|---|
| define step 9's threshold clause | Delete ", whatever `scope_threshold` allows" in both places at `skills/define/SKILL.md:23` |
| A go builds an approved plan inline | After "run the same plan-check again." at `skills/autopilot/references/run.md:62`, add " execute-plan then runs it." |
| A go's bug route and its case | Under a go, when no approved spec exists, self-review writes the ticket's requirements as numbered lines under `## Acceptance criteria` in a file under `kern-dir tmp`, and that file is the spec for the proofs and the spec lane (my call). A bare ticket would give `proof-check: n/a`, which `scripts/claim-check:89-92` passes, so the PR would carry no proofs. An exec case runs a bug ticket under a go, and `prProved` (`scripts/lib/exec-grade.mjs:411`) gates on that file as it does on a `.kern/specs` file |
| A tests-only ticket writes a short spec under a go | Under a go, a ticket that only adds tests for existing code takes the kernel's implement row, with no define and no spec; self-review takes the ticket as the spec as above (my call) |
| execute-plan stops with no `test.full` under a go | Under a go, execute-plan builds by the closest check, as implement does today, then commits, pushes its branch, names `test.full` as `fail`, stops and opens no PR. A person's run still asks (my call, from part 1's "Push allowed, and should Stop") |
| A first build changes behaviour the ticket does not name | U1 covers a first build: a change of behaviour the ticket does not name, against the base branch, stops the go before the PR. The run commits, pushes its branch, names the change and opens no PR. A side effect the ticket's own change forces counts when it changes what the code does for inputs the ticket never names: round 5's `sum('1', '2')` turning from `'12'` into `12` under the ticket's rounding is the example the user ruled on |
| The go fixtures under the wider U1 | Six go cases share a "round sum to two decimals" ticket whose rounding has that side effect: `go-reaches-draft`, `go-no-lint-draft`, `go-required-check-stop`, `go-merge-stop`, `go-spend-stop`, `go-mandated-defect-stop`. Their fixture changes so the ticket changes no behaviour it does not name, and each case keeps testing what it tests today. Only the new U1 case keeps the side effect (my call) |
| Fix rounds keep no durable count | Fix-round packages are named `<slug>-<N>.diff`, and run.md's Fix rounds counts rounds from those names |
| The spec lane grades a plan-mandated defect Minor | Find where the lane's prompt loses `agents/task-reviewer.md:29`'s severity and fix it there |
| Self-review skips checks after `fix first` | Step 9's verdict comes out of one script that runs step 2's deterministic pass itself on the package's tree, `claim-check --spec --proofs` included when a spec exists, and prints the failed checks with the verdict floor. A `fix first` therefore always arrives with its proofs run, and a missing proofs file is a failed check. The report pastes the script's output. The shape is my call; the script's name is the builder's |
| The size-breach grader's reading | The question the user sees carries the line count, its measure, the limit and the limit's source. `scripts/size-check:71` already prints that question and runs paraphrase it, so the fix is a mechanism, not a wording change. The mechanism is the builder's; a check that only a Stop hook could make waits for project 2, and the case stays a known limit until then |

## Graders and fixtures

| Item | Contract |
|---|---|
| U1 has no grader row | One new go case whose build changes behaviour the ticket does not name, graded as a stop before the PR. Only that case's grader passes a U1 stop; the draft cases still want a draft PR (my call) |
| The size-breach grader | `evals/behave/workflows.json:81` expectation 2 is read from the reply only |
| The `tax` test gap | A fixture test that only the right rounding passes |
| `go-block-reroute` meets no block | A fixture whose safer route exists, so a guard blocks the run and a reworded route is tried |
| `ends`' middle cut hides plan-check output | A `CHECKS` row reads plan-check from the events, as `ledger: Task N: complete` does for task-done |
| Reports leave out self-review's verdict | A grader row on the report's verdict |
| A go writes a plan's approval before its review | A grader row on the order |
| A required-check stop wrote no spec | A spec row on that case's grader |
| A go edited the main checkout | A grader row for edits outside the run's worktree under a go |
| `reviewOpen` fails an honest reject | `reviewOpen` accepts a finding ruled `reject: <citation>` |
| G6 and G8 read printed text | These are the exec graders' G6 and G8 checks in `scripts/lib/exec-grade.mjs`, not the guards. G8 wants `fail` beside the check's name; G6 also takes a tree a later call shows |
| No grader reads a required-check stop's commit body | A grader row on the commit body naming the red check |
| No grader reads a named skip | A grader row on the report's skip line |
| The h2h review grader docks the review package | The review grader's prompt says a package under `.kern/reviews` is no edit |
| A wakeup past the timeout voids a run | The eval runners deny `ScheduleWakeup` (my call, over counting the run as its last result) |
| The spec lane grades a plan-mandated defect Minor | A grader row on the lane's severity for a plan-mandated defect |

## Measured, not changed

| Item | Contract |
|---|---|
| `pressure-prove-it-deadline` misses its line | The paid round reads it. If it falls again with kern's bytes to the case unchanged, it goes to the user with the runs; no text change before that |
| The stale-cache class in h2h diagnose | The paid round runs h2h diagnose and reads step 7's sentence. If the empty `catch {}` recurs, step 7's fallback is tied to "Add no silencing guard" and the next round measures that |

## Docs

| Item | Contract |
|---|---|
| Skills spec line 369 against plan step 1 | `docs/specs/2026-10-12-kern-m1-m2-skills.md:369` matches `skills/plan/SKILL.md:15` |
| The skills spec names no skip under autopilot | Lines 626, 670 and 717 carry the named skip the skills now give |

## Audit adopt rows

The 22 rows of `docs/research/opus-audit-2026-10-22.md` section 5 whose When column says M3 land as their Take column says. Each is checked at HEAD first: part 1 closed some P16 and P19 findings, and a row a part 1 task closed is recorded with its commit, not rebuilt. diagnose's `[kern-dbg]` tag and its back-edge to step 5 are already at HEAD.

Four clauses, in rows L482, L488 and L489, change text the paid round must read unchanged: prove-it:21 with the kernel Evidence line, prove-it step 7's "Never hand the user a check you can run", and diagnose's "tighten the loop" and "a perf baseline first". `pressure-prove-it-deadline` loads prove-it and the kernel, and h2h diagnose reads step 7. These four land after project 1's paid check, as the first task of project 2's batch, and project 2's round measures them (my call). L482's third clause, a failed fix going back with its count, is already at HEAD. The other 19 rows land in project 1. A raised cap names its row.

## Proof

| Step | Contract |
|---|---|
| Per task | Focused suites green; full `ci-local` once before the task merges |
| Paid check | One full round after the batch, on the user's yes, under the overview's rules. It also reads the two "measured" items above |
| Gates | The overview's exit rule. New grader rows gate from the round they first run in; a case a new row turns red in its first round goes to the user, not into a fix loop |
| Limit | 3 rounds; a fourth only on the user's yes |

## Order of work

My call. Guards and scripts first, since the carve-out changes what a go may commit. Then run rules and skills, then graders and fixtures, then docs and the adopt rows, then the paid check. Each task ends with its focused suites green.

## Open risks

- The self-review script changes the step most behaviour cases pass through; a regression there shows only in the paid round.
- The size ask may need project 2's Stop hook, which leaves one known limit open across a project.
- New grader rows can turn green cases red. That is the point of them, and the round's triage must tell a real miss from a grader fault.

## Left to the builder

- The self-review verdict script's name, arguments and output format.
- The size ask's mechanism, within the contract above.
- Which fixture shape gives `go-block-reroute` a safer route and the `tax` test its one right rounding.
- How each grader row reads its evidence.
- How the 22 adopt rows group into tasks.
