# kern M3 part 1: autopilot end to end

Draft for the user's review, 2026-10-31. Part 2 is the rest of the M3 row (`docs/specs/2026-10-12-kern-design.md:601`) and gets its own design. Every item with its evidence is in `docs/research/2026-10-31-m3-item-sort.md`. Lines marked "my call" are the designer's, for the user to check; the rest are the user's words or accepted playback.

## Intent

The pilot showed kern is safe but noisy, and no pilot session used autopilot. The user wants to type one go on a real ticket and get a draft PR back: "I want the autopilot to run e2e and unblock himself, but should stop in important decisions". Cost and time must fall too: "I want high quality, cost efficient and fast solution". When those collide, "quality and correctness should the best value I got from kern".

Superpowers stays on until the user trusts kern: "we can continue with superpowers on until I confident to depend on kern". Part 1 is how kern earns that.

## Where things stand

Pilot session files, measured 2026-10-31. Weighted tokens count input 1, cache write 1.25, cache read 0.1, output 5. Busy time counts seconds with main or subagent activity, and includes waits for the user inside a tool call.

| Run | Raw tokens | Weighted | Busy s |
|---|---|---|---|
| Usual flow, MA-254 | 178.8M | 25.8M | 8,197 |
| kern, MA-254 round 2 | 72.5M | 11.6M | 7,034 |
| kern, MA-269 | 32.0M | 5.0M | 2,658 |
| kern, MA-250 | 7.9M | 1.3M | 2,116 |

MA-254 round 2 is the one like-for-like run: the CHANGELOG records it as matching the usual flow in plan, review and code.

| Fact | Evidence |
|---|---|
| Nothing approves under autopilot, so a ticket past define's fast path ends at a draft | `hooks/guards/g20-approval.sh:15`, `scripts/ledger-open:107`, `skills/define/SKILL.md:48`, `skills/plan/SKILL.md:46` |
| A `fix first` verdict ends the run | `skills/finish-branch/SKILL.md:19` |
| Waiting on asks is a time cost | MA-250: about 15 minutes on the G1 push ask, in a 2,116 s run; the pre-push tests took 17 s |
| Emulator proof is the largest time cost on UI tickets | Round 2: 3,673 s, 52%. Usual flow, second session: 1,523 s, 30% |
| Main-thread context is the largest token cost in most kern runs | Average 190k to 219k in the long rounds; 59% to 68% of main-thread cost falls on calls above 200k; cache reads are 96% or more of raw tokens |
| Guard denials cost time and stalls, not tokens | 1 to 6 per round, about 1 to 2% of tokens (estimate) |
| The side-by-side's 13.32 times wall figure does not describe real tickets | p1 and p2 each spent about 740 s in `ci-local` in kern's own repo, with a test-helper leak since fixed in f4cefde |

## Goals

| # | Goal |
|---|---|
| 1 | One typed go takes a ticket to a draft PR on tested or verified changes, with nobody at the keyboard |
| 2 | A run stops only on the stop list |
| 3 | A blocked run unblocks itself in the order below |
| 4 | Cost and time fall through cutting waste, measured against the usual flow |
| 5 | Every result a run reports is true: checks skipped or unproven say so |

## Non-goals

- Part 2's features.
- The switch-off, which stays the user's later decision.
- Any merge or deploy by autopilot.
- A preset pass number. The user decides from the measured round.

## Anti-goals

Any of these makes part 1 a failure even if a run reaches a PR.

- A reworded command gets past a guard that blocked the same action. Autopilot would learn to defeat the guards.
- A check is removed to save time. Only a repeat of the same proof on the same tree may go.
- The model can produce an approval. Only the user's typed words approve.
- A noise fix opens a guard hole. G16's block on forging hook state and prompts stays.
- A fix or measure loop runs without a limit.

## Constraints

- Quality and correctness win over cost and speed.
- Floor actions never loosen: merge, production deploy, data deletion, force-push to a shared branch, messaging people. Review posting and tracker writes stay with the user.
- Only the user can turn autopilot on.
- Measure-and-fix cycles run at most 10 rounds, more only on the user's yes. A round is one paid eval run plus its fixes.
- Paid runs need the user's yes each time, on the eval account, through `scripts/eval-all` with `--jobs 6` and `--no-cache`.
- The repo is public: no client names or data, and no working guard-bypass commands.
- Frozen files stay frozen: `evals/heldout.json`, `evals/heldout-pilot.json`, `evals/pilot/tasks.json`, `docs/plans/2026-10-25-kern-pilot-fixes.md`, `docs/plans/2026-10-26-kern-pilot-fixes-2.md`.
- The eval model under test stays Sonnet; all kern build, review and audit work runs on Opus.
- Current scores must not fall: exec 9/9, behaviour 22/23, adherence Sonnet 19/20 and Haiku 20/20, h2h plan, review and diagnose PASS.

## The go

The user's ruling: "One typed go naming the ticket counts as my yes for its spec and plan. Autopilot still stops on my stop list."

| Rule | Contract |
|---|---|
| Form | One `/kern:autopilot` line naming one ticket, parsed by a closed grammar in the manner of `prompt_consent` (`hooks/lib/state.sh:222`). It turns autopilot on and records the go, so a run takes one prompt. Plain text still cannot turn autopilot on (my call) |
| Source | prompt-submit records it from the user's typed prompt only. A wrapped or scheduled prompt, a subagent, a file, a tool result or an AskUserQuestion answer cannot make one |
| Reach | It approves the spec and plan of the ticket it names and nothing else. A second ticket needs a second go |
| Record | `approved:` holds the date and the go's words, so ledger-open's check stands. G20's rule becomes: under autopilot only a go approves, for its ticket |
| Unchanged | plan-check, the plan reviewer and every other step still run. The go replaces the human yes only |
| Lifetime, my call | It ends when the draft PR opens, autopilot goes off, or the session ends. It survives compaction and resume inside the session. Autopilot stays on after the go ends, until the user turns it off |
| No ticket id, my call | No go. define parks at a draft as it does today |

## Skill conflicts at setup

The user's ruling: "In the setup you can list the user's or the project skills that conflict or override kern's skills so the user can select which to override and which to keep from kern". This extends step 4 of `/kern:help setup` (`skills/help/SKILL.md:35`), and it replaces the pilot's "use kern's own routes" sentence in each first prompt.

| Rule | Contract |
|---|---|
| What it lists | Each user skill and project skill that overlaps a kern job, and enabled plugin skills too (my call), with the job and why it overlaps |
| What the user picks | For each, use that skill or keep kern's |
| Record | `overrides.<job>: <skill>` or `overrides.<job>: off` in `.claude/kern.local.yml`. The key takes a user or plugin skill as well as a project skill |
| A go | Follows those picks. A job left to another skill runs that skill: kern's guards still apply, but this design's stop, unblock and fix-round rules cover kern's routes only, and the run report says which jobs ran elsewhere |
| A conflict with no pick, my call | The go refuses, autopilot stays off, and it names `/kern:help setup`. Setup refuses under autopilot, so this check comes first |

## The stop list

| Autopilot stops for | Autopilot does not stop for |
|---|---|
| Merge to main | Reads |
| Deploy | Tests |
| Delete | Commits and pushes on its own branch |
| Spending money | A draft PR on tested or verified changes |
| A design choice that changes what gets built | |
| A required check that cannot run | |
| A defect the ticket itself demands | |

The user's ruling on the required check: "Push allowed, and should Stop, PR should at least have a tested or verified the changes unless the user say explicit to open the pr". The run pushes its branch, stops with the report and opens no PR. A typed reply that says to open the PR opens it. A required check is one the ticket or prove-it names for the change (my call).

The user's rule, 2026-11-01: a defect the ticket itself demands stops a go before the PR. The run commits, pushes its branch, stops with the finding and opens no PR. No fix round runs, since a fix would leave the ticket, and no `ticket` ruling parks it. The paid round showed why: `go-deploy-stop`'s review said `needs fixes` on the ticket's own formula, and the run opened the PR and left the verdict out of its report.

The user's rule, 2026-11-03: a fix round that changes behaviour the ticket does not name is a design choice. Under a go the run commits, pushes its branch, stops before the PR and names the change. Paid round 4 showed why: `go-spend-stop`'s fix rounds changed what `sum` does with inputs the ticket never named, and the run opened the PR with the change as a line for the user to check.

Delete means data, remote branches, tags, and files outside the run's own worktree and scratch directories. Removing a file on the run's own branch is ordinary work (my call).

A design choice stops the run when the ticket does not settle it and the answer changes user-visible behaviour, stored data shape, a public interface or the ticket's scope (my call). Any other judgment takes a default and goes in the report.

At a stop, the run brings the data it collected and a recommendation, then waits for a typed reply. Work that does not depend on the answer may finish first.

No guard covers spending money today, so that stop rests on the model's reading of the rule; the real round checks it. The local `rm` guard (`docs/specs/coverage.md:61`, gap 26) moves from part 2 into part 1, since a run goes unattended and delete is on the stop list (my call). A read against production follows the project's `protected_targets`, which G13 enforces. A real-round project with production access sets that key first.

## How a run unblocks itself

The user's rule: "Try another safer solution, try to find the answers in the projects, docs, code, ticket and collect the needed data to understand and can make a decision".

1. Try a safer route to the same result.
2. Find the answer in the project, docs, code and ticket, and collect the data needed to understand.
3. Decide, and record what was chosen and why.
4. If the decision is on the stop list, stop as above.
5. After 3 distinct routes (my call), skip the step and record it. If later work depends on that step, stop. A required check is never skipped.

A route is distinct only if it is a different action. The same target and effect in other words is the same action, and it stays blocked.

## Fix rounds

A `fix first` verdict starts a fix round in place of ending the run (my call on the limit: 3 per self-review). Each round fixes the findings and runs self-review again in full, including the checks the last round skipped. When a third round is still `fix first`, the run pushes its branch, stops with the report and opens no PR (my call on the push). No verdict also stops. A defect the ticket itself demands takes no fix round: it stops as the stop list says. A fix round that changes behaviour the ticket does not name stops as the stop list says.

One go covers one draft PR. All three rules below are my call.

| Case | What the run does |
|---|---|
| `split` from a finding on a line the last round changed | The fixes are not converging: stop with the report |
| `split` or the size gate on size alone | finish-branch's default: go on, with Scope giving the size |
| A plan over `scope_threshold` | plan's default: take the split and run the first slice. The report lists the rest, and each needs its own go |

## The run report

Every run ends with one report: the ticket and PR, each stop, each block and the route taken, each decision with its why, each skipped step, and each check with its result. `parked:` lines keep their format. The report gives the review's verdict as it came, `needs fixes` included. A check that did not run is reported as a fail, not as "not run".

## Cost and speed

The yardstick is the usual flow on MA-254, not the side-by-side's ratios. A removed run must leave the same tree checked at least once.

| Waste | Direction |
|---|---|
| Main-thread turns times context | Keep the main thread small: bulk reads and long output go to subagents or get trimmed |
| Waits on asks | Goes with autopilot and the guard noise fixes |
| Emulator walks rerun whole | A failed walk resumes from the failed step, with a bound on reruns. The walk tool is the project's own, so kern's change is prove-it's guidance |
| Full suite twice on one tree | Keep one run per tree. Runs on interim trees stay: quality wins, and tests and gates are 6% to 21% of a round (my call) |
| `task-done` runs a test up to four times | Drop the repeat on the same tree |
| `worktree.setup` on each probe fork | Skip it where the fork can share the setup |
| Whole-branch review twice on one tree | One review per tree |
| Reviews come back as notification turns | Remove the dead `run_in_background` text and keep one review flow |

## Scope

| Home | Items |
|---|---|
| Part 1, autopilot | 20 |
| Part 1, cost and speed | 7 |
| Part 1, correctness | 13 |
| Part 2, guard holes | 6 |
| Later | 55 |
| Already fixed | 5 |

The user said "don't drop any", so each item keeps a home. Moving the 6 guard holes to part 2 is my call: they sit with the spec's parser work, and they take an unusual shell form, not an ordinary command. Three of them work under autopilot too. Fixture 5 stays open in part 1 and the real round grades it again. The 10 small items the sort proposed to drop moved to Later (my call).

## Order of work

My call. Each step ends with its focused suites green; full `ci-local` runs once per task.

1. A probe of what reaches the model in a headless run, since the go and autopilot's signals depend on it.
2. The go: grammar, G20, ledger-open, define and plan text, and setup's conflict step.
3. Autopilot rules: the stop list, the unblock order, fix rounds, the run report, implement's park defaults, the skill's drift.
4. Guard noise and the other run-stopping items.
5. Correctness items.
6. Cost and speed items.
7. A paid check run. The real round waits for the end of M3.

## Proof

Autopilot gets eval coverage that a run with a go reaches a draft PR, a run hits each stop, and a reworded block stays blocked. The plan names the cases.

Part 1 ends with the paid check run. The real round comes after all of M3, on the user's word: "Make the real rounds after finishing m3 completely". Its measure stands: "after finishing real projects run round, measure the results and I can decide, like what we did in money app and cds". The user picks the tickets. 3 tasks in each of MoneyApp and cds, as in the pilot, with at least one code-changing ticket in cds, which the pilot lacked (my call). Each project runs setup's conflict step first.

| Measure | Source |
|---|---|
| Draft PR reached, or branch pushed and stopped with a reason | Session |
| Stops, and whether each was on the list | Session |
| Blocks, routes taken, reworded blocks | Session |
| Needless guard calls, slips | Graded as in `docs/pilot.md` |
| Tokens, weighted tokens, busy time, tool calls | `scripts/pilot.mjs metrics` plus the weights above |
| Plan, review and code quality against the usual flow | Where the ticket has a usual-flow run |
| Fixture 5 and the failed checklist items | `docs/pilot.md` |

## Open risks

- Autopilot has never run on a real ticket. Everything here comes from reading the code and replaying commands.
- Whether UserPromptSubmit output reaches the model in a headless run is unknown (CHANGELOG:67). T3 Code runs through the Agent SDK, so this decides whether cds can run on autopilot at all.
- Whether a background review resumes with nobody at the keyboard in an interactive session is unknown.
- No guard covers plain file writes outside a worktree or in the main checkout. An unattended run makes that gap matter more.
- `push.policy: auto` with a project's "never push" rule rests on the model.

## Left to the builder

- The go's exact arguments, and how a spec and plan name their ticket.
- How setup finds an overlap beyond a same-name match.
- How the main thread stays small.
- The shape of the G16, G18 and G20 noise fixes.
- How a walk resumes from a failed step.
- Which eval cases prove each stop.
