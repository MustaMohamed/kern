# Task 22 re-review, fix round 1 (e68bdb8..df11156)

Scope: commits 8738c9e (task-done) and df11156 (execute-plan) only. The kern tree was left untouched: `git status --short` is empty.

Checks:
- `tests/run-bats tests/scripts/task-done.bats`: 22/22 ok, test 22 is the new inconclusive case, no `not ok`.
- `node --test 'tests/**/*.test.mjs'`: 126/126.
- `lint: clean`; `route-eval: passed`.
- Sizes: SKILL.md 11,979/12,000; ledger-format.md 2,467/2,600; resume.md 1,772/2,500.
- Removal mutations: 12 of 12 killed. These covered 4 resume.md lines, the 6 earlier survivors under their new wording, the 126/127 line and the remake line.

## Earlier findings

| Finding | Status | Where | Evidence |
|---|---|---|---|
| Critical 1: an inconclusive probe closes the task | ADDRESSED | scripts/task-done:81; SKILL.md:29; contract.md:159 | walk/p1 (ignored file missing in the fork): exit 3, `task-done: the probe is inconclusive ...; not recorded`, 0 complete lines. walk/st (stale round-1 patch): exit 3, 0 complete lines. With the remade package (missing export `mul`), the named-case rerun `--no-probe "probe inconclusive: <reason>"` exits 0. It writes `probe=skipped (probe inconclusive: ...)`, which matches contract.md:188 by regex. |
| Important 1: resume ignores `Applied:` | ADDRESSED | resume.md:10 | In the wave ledger, Task 2 is complete with 0 `Applied:` lines, so case 2 sends it to step 11. wt-apply prints `applied`, and final.diff then lists `src/a.js` and `src/b.js`. Before the fix it listed `src/a.js` only. |
| Important 2: a fix loop cannot be resumed | ADDRESSED | SKILL.md:27-28; resume.md:13-15, 23 | Step 8 saves the reviewer's return to `reviews/task-N-r<r>.txt` before task-review. Rounds 2 and 3 pass that file, and the fresh-implementer fallback is restored. Resume covers a non-approving review last and a changed start tree. Writing the `.txt` gets no vote from the hooks, in either mode, even when it holds "approved". |
| Important 3: ledger lines can be forged | ADDRESSED as ruled | SKILL.md:12; ledger-format.md:23 | Both files now say only the scripts write start, review, minor and complete lines. The limit and the M3 guard are named. An Edit appending a forged complete line still gets no vote in either mode, which is the stated limit. |
| Minor 1: baseline artifact in final package | ADDRESSED | SKILL.md:21 | `base-tree` is now taken after the baseline. Rerun: the baseline writes `test-output.log`, and the final wt-diff then exits 3 (empty). |
| Minor 2: round cap is a label | ADDRESSED | SKILL.md:27; resume.md:3 | r = 1 + the task's review lines. The overstated "task-review refuses one" is gone. |
| Minor 3: exit 4 follow-up | ADDRESSED | SKILL.md:27 | A yes appends the path to `.files` with a Decision line, and the printf append gets no vote. A no goes back to the implementer. |
| Minor 4: 126/127 and post-round-3 | ADDRESSED | SKILL.md:29 | |
| Minor 5: duplicate Preflight lines | ADDRESSED, over-applied | SKILL.md:18-19; resume.md:3 | See new Important A. |
| Minor 6: compound `Run:` | ADDRESSED | SKILL.md:29 | `-- bash <kern-dir tmp script>` gets no vote in either mode. |
| Minor 7: unpinned lines | ADDRESSED | test | All 6 earlier survivors are now killed. |
| Minor 8: red flag lost "adjudicate only at the cap" | ADDRESSED, with a nit | SKILL.md:60 | See Minor c. |
| Minor 9: step 12 names | ADDRESSED | SKILL.md:31 | `kern:implementer`, the re-review on `model.final_review`, FROM `final.diff`'s second line. |

## Points the lead asked about

- **resume.md, case by case.**
  - Cases 1-4 and the started, non-approving, fix-round and approving sub-cases are true, and each routes to a step whose own stop, ask or park applies.
  - Case 1 with a worktree but no `Worktree:` line ends in step 5's wt-new exit 2 ("path exists"), which asks.
  - Case 2 ends in wt-apply, whose conflict stops the run.
  - An r of 4 stops with the split proposal.
  - One preamble claim is untrue (Important A). Minors a, b and e are incomplete edges.
- **ledger-format.md.** 2,467 of 2,600 bytes. Line 18 matches contract.md:188 exactly: `probe=<ok or skipped (reason)>`.
- **contract.md:159.** Matches task-done:76-82: 3 means inconclusive with nothing written, and otherwise CMD's own code with `command exited <n>`. task-done.bats covers two inconclusive causes (test files only; a stale patch), and both write nothing.
- **Removed Stops list and intro line.**
  - Every stop is still stated in its own step:
    - 1: ledger-open exit 2.
    - 2: a plan defect.
    - 3: a conflict.
    - 5: wt-new exit 2, kern-get exit 3, a red baseline.
    - 6: wt-fork, exit 2.
    - 7: NEEDS_CONTEXT, a split.
    - 8: exit 4.
    - 9: the cap.
    - 10: 126/127, inconclusive, a probe error.
    - 11: a conflict, a red test.full.
  - "Ask at each stop ... never through AskUserQuestion" still covers them all.
  - The serial/fork line is carried by steps 4 and 6.
  - One behaviour did leave the reading path: the batch rule's ledger half moved into ledger-format.md, which SKILL.md no longer names (Minor d).
- **Lost "(G20)" and "as nothing approves a plan".** Harmless. The rule itself, "When on, steps 1 and 2 and a failed `wt-new` still end the run", is intact and pinned. The phrases only gave the reason, and G20 enforces it independently.
- **Step 10 exits.** Each exit has an action:
  - 0: the complete line is written, then the autopilot commit or the next task.
  - 1: implementer, or after round 3 the split proposal.
  - 2: a changed or unapproved tree means review it; a probe error means stop. `command exited 2` goes to the implementer by its text.
  - 3: a named case reruns with `--no-probe`; any other stops and asks. `command exited 3` goes to the implementer by its text.
  - 126/127: stop.
  - Overlap: a CMD exit of 1, 2 or 3 shares its code with a script exit. The skill branches on the message text, so this is safe. A controller that keys on code 3 still lands in "stop and ask", because there is no probe reason to match a named case.

## New findings

### Important A: resume skips step 3's stop and step 2's lint on every resumed invocation

`SKILL.md:18-19` (steps 2 and 3, "Once") and `resume.md:3` ("Steps 2 and 3 ran already: their lines are in the ledger, so rebuild only the todo list"). The fix for Minor 5 made the read-only checks once-only, not only the ledger writes.

Reproduction, by applying resume.md to a ledger:
1. The ledger holds the header, `Main:` and one `Preflight:` line. Step 2 wrote the line, then step 3 stopped to ask about a spec conflict, interactively.
2. On the next invocation, resume.md applies, because there are lines past `Main:`. Its preamble says steps 2 and 3 ran, and case 1 goes to step 5.

Three things are lost:
- The conflict question is never asked again. Nothing in the ledger records it or its answer, so a D5 stop is skipped silently. Before this diff, step 3 ran on every invocation.
- plan-check does not run again. That includes a plan whose body was edited to answer the question, since G20 lets body edits through. In step mode, this means every invocation after Task 1.
- The wave rows from `--graph` are never written to the ledger. "Rebuild only the todo list" therefore loses step 4's grouping, and a resumed delegate run goes all-serial. That is safe, but it is not the plan's execution.

Expected:
- `plan-check` and `--graph` run on every invocation; they are read-only.
- Only the `Preflight:` and `Decision:` writes are once.
- A step-3 question the user answered is recorded as a `Decision:` line.
- On resume, any step-3 conflict with no such line is asked again.

## Minor (new, in this diff)

a. `resume.md:13` and `:15`: a changed snapshot after a `start` or `fix round` line goes straight to review. After compaction in the same session, a background wave worker may still be writing. In step or inline mode, a half-done change is reviewed as a full round. task-done's tree check means nothing closes wrongly, but a round of the 3 is spent. Say: an implementer still running is waited for; in step or inline mode, finish the change first.

b. `resume.md:17` (case 4) sends every resume after the tasks to step 12. Neither the final review's return nor the final fix is recorded, so a resume during or after step 12 runs a second whole-branch review and possibly a second fix wave. That is against step 12's "one fix subagent ... one re-review". Save the final review's return as `reviews/final-r1.txt`, and add a line or case for it.

c. `SKILL.md:60`: "Adjudicate only at the cap, in a Decision line". In kern, the cap does not adjudicate: step 9 stops and escalates with a split proposal. Make the row say the finding goes into the split proposal at the cap. As written, it reads as permission to rule on a finding at round 3.

d. SKILL.md no longer names `references/ledger-format.md` anywhere. Step 1's pointer now goes to resume.md, and neither resume.md nor any step links it. Three things in it are now unreachable on a run:
   - the batch sentence moved from step 4 ("the scripts still write each task's lines");
   - the `Decision:` and `Preflight:` formats;
   - the printf/Edit append rule.

   task-done's "has no review line" refusal limits the batch impact. Add "Line formats: `references/ledger-format.md`" to step 1. SKILL.md has 21 bytes free, so trim elsewhere.

e. `SKILL.md:21`: with the baseline now before the `Worktree:` line, a red-baseline stop leaves a worktree and a branch that the ledger does not record. The next invocation hits wt-new exit 2 ("path exists" or "branch exists") and asks, with no instruction to reuse that worktree. This ends in an ask, so it is safe. A one-clause fix: on a red-baseline stop, write the `Worktree:` line first, or reuse the existing worktree when resuming.

## Verdict

NEEDS-FIXES. The Critical and Important 1-3 are fixed and verified by rerunning the probes. Important A is new, introduced by the "Once" wording of the Minor 5 fix. Minors a-e are not blocking.
