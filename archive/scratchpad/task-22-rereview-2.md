# Task 22 re-review, fix round 2 (df11156..5232640)

Scope: commit 5232640 only. Settled items are not re-reported. The kern tree is untouched: `git status --short` is empty.

## Checks

| Check | Result |
|---|---|
| `node --test 'tests/**/*.test.mjs'` | 127/127 |
| Lint | `lint: clean` |
| Route-eval | `route-eval: passed` |
| `SKILL.md` | 12,229 of 12,400 bytes |
| `resume.md` | 2,116 of 2,500 bytes |
| `ledger-format.md` | 2,467 of 2,600 bytes |

Removal and reintroduction mutations: 8 of 8 killed. They cover:
- the wave rows coming from this run;
- the REPORT status line;
- `Once` reintroduced in step 2;
- add-only-missing;
- the step 3 answer recorded as a `Decision:` line;
- "parked once";
- "step and inline: finish the change first";
- the step 1 pointer to `ledger-format.md`.

`brief-check` passes a brief whose REPORT holds the new status-line clause.

## 1. Important A: ADDRESSED

Changed lines: `SKILL.md:18-19` and `resume.md:3`.

Repro, reading `resume.md` literally against a ledger that holds only the header, `Main:` and one `Preflight:` line (step 3 had stopped to ask):
- ledger-open exits 0. There is 1 line past `Main:`, so `resume.md` applies.
- Steps 2 and 3 run again:
  - plan-check exits 0.
  - `--graph` prints `overlap 1 2 src/sum.js`, `wave 1 1`, `wave 2 2`.
  - The identical `Preflight:` line is present, so it is not added.
  - There are 0 `Decision:` lines, so the conflict is asked again (`resume.md:3`, `SKILL.md:19`).
- Case 1 then continues at step 5.

Other paths:
- **Step mode after Task 1:** step 2 now runs every invocation, so plan-check reruns on each task.
- **Resumed delegate run:** `--graph` on the wave plan prints `wave 1 1 2`, and `SKILL.md:18` says "this run's `wave` rows feed step 4". The waves are kept.

## 2. Minors a, c, d

- **a: ADDRESSED, with caveats** (`resume.md:13,15`; `SKILL.md:25`). The status-line requirement is new: neither contract already says it.
  - `agents/implementer.md:29-38` puts `Status:` in the return message, and its report-file contents list no status line.
  - `brief-template.md:16`'s REPORT field lists "status line" among what the worker returns, not what the file holds.
  - It does not conflict with either. Implementer rule 8, "append a section `Fix round N`" (`agents/implementer.md:25`), fits "each round opening with its `Status:` line".
  - Two caveats, both Minor (see b and c below): the agent file, the stronger contract, still does not require it, and a missing line fails safe (wait or resume). The rule also still routes any `Status:` value to step 8.
- **c: ADDRESSED** (`SKILL.md:60`). "Argue it in the re-review. At the cap, the split proposal names it." matches step 9.
- **d: ADDRESSED** (`SKILL.md:17`). Step 1 now has "Line formats and how to append them: `references/ledger-format.md`."

## 3. Is "add only when the ledger lacks that exact line" workable?

Yes for identical lines. It does not stop a reworded duplicate.

Probe: on the same ledger, a rerun whose ruling reads `run serially; Task 2 waits for Task 1` instead of `serial, Task 2 after Task 1` is absent by `grep -Fx`, so it is added. `ledger-open --summary` then lists two `Preflight:` lines for one overlap.

The same applies elsewhere:
- **`Decision:` lines for mechanical calls:** these are re-derived on every invocation, so in step mode a plan of N tasks can collect up to N wordings of each call.
- **`parked:` lines under autopilot:** "parked once" (`resume.md:3`) holds only when the question is worded the same.
- **The re-ask test:** "no `Decision:` line" is semantic, so a controller that applies the exact-line rule to it re-asks a question the user already answered.

Does it matter? Not for correctness:
- Execution order comes from `--graph` and `Blocked by`, not from ruling text.
- `resume.md` case 2's "a task a `parked:` line holds stays out" reads the same with duplicates.

The cost is report noise, and possibly two contradictory rulings for one overlap, in `--summary` and step 13. Minor. Smallest fix: match on the line's identity part, not the whole line:
- `Preflight: Task A x Task B: <shared>:`
- `Decision: <what>;`
- `parked: <question>;`

Then reuse the existing ruling rather than ruling again.

## 4. Behaviour lost or stop dropped, df11156 to 5232640

None found.
- Step 2: "stop before Task 1" became "stop before any task". On a resume this means before the next task, which is correct.
- Step 3 lost "before Task 1". On a fresh run, step 3 still precedes every task, and the stop ("stop and ask") is intact. Under autopilot it parks per the Stops paragraph.
- Every other step-level stop is unchanged.
- The `resume.md` cases are unchanged apart from the two status-line qualifiers.
- The test asserts that steps 2-3 hold no `Once` and that `resume.md` holds neither "ran already" nor "rebuild only the todo list".

## 5. New Critical or Important; the stop rule

No new Critical or Important finding.

Stop rule: round 2 does not author a defect in round 1's code at Important level. The reworded-duplicate gap in item 3 partly reopens Minor 5, the symptom round 1's `Once` was meant to stop. It stays Minor because it affects only report text.

## New Minor (for triage)

a. **Ledger meaning column out of date** (`ledger-format.md:13`). It still defines `Decision:` as "a mechanical call made without the user". Step 3 (`SKILL.md:19`) now records the user's answers as `Decision:` lines, and exit 4's yes has done so since round 1. Change the meaning to "a call made, by the user or mechanically".

b. **Any `Status:` routes to review** (`resume.md:13,15`). A stopped implementer's `Status:` sends a changed snapshot to step 8 whatever its value. A `NEEDS_CONTEXT` or `BLOCKED` report on resume is therefore reviewed as a round, skipping step 7's answer, tier-up or split. Round 1's text had the same route ("review it at step 8"), so this is not authored by round 2. Route it to step 7 with that status: DONE goes on to step 8.

c. **Status line contract and round numbering** (`agents/implementer.md`). Add "each round of the report opens with its `Status:` line" there in a later task, so the requirement does not live only in the brief. Rule 8's `Fix round N` numbering can also differ from the ledger's r: the first fix is ledger round 2. Say "fix round N as the controller numbers it".

d. **Duplicates from the exact-line rule** (item 3). Match on the identity prefix.

## Verdict

APPROVED. Important A is addressed and verified by replaying the repro. Minors a, c and d from round 1 have landed. No new Critical or Important finding. Minors a-d above go to triage.
