STATUS: DONE (committed on main, all gates green)

SHA: 7c554e7 (BASE 2fbfc90)
Bytes: skills/recall/SKILL.md 7,179 (cap raised from 6,500 to 7,200 by the lead's allowance; all 7 gaps need text). references/transcripts.md 1,399 (cap 2,200).

Tests
- Failing first: `node --test tests/skills/recall.test.mjs` gave 9 failing of 9 (`skills/recall/SKILL.md exists`).
- Passing: recall test 9 of 9; full `node --test 'tests/**/*.test.mjs'`: pass 178, fail 0.

Gates
- lint-skills: `lint: clean`. Auto descriptions 522 of 1,500; auto plus agents 945 of 2,500 (lint prints no budget line; measured with loadModel).
- route-eval: passed, rank-1 rate 83% (baseline 0%).
- `claude plugin validate .`: passed.
- G18 check: ran the prescribed miner commands through hooks/pre-tool-use as `kern:investigator` (scratchpad bats): `grep -n T f | cut -c1-300`, `wc -c f`, `sed -n 12,40p f`, `sed -n 12p f | wc -c`, `sed -n 12p f | cut -c1-500`, `grep -c T f`. No G18 vote on any.

Mutations: 44 pinned strings in SKILL.md, each removed on a scratch copy; 44 killed, 0 survived. The test's `assertOnce` also fails any pin that occurs twice or zero times.

Gaps
1. `--topic <topic>` only when a topic was named; empty topic called a usage error.
2. WORK resolved read-only: `kern-get work_dir .kern` (prints value, tab, source) and, as a separate command, `git rev-parse --path-format=absolute --git-common-dir` whose parent is the main checkout. Test asserts the skill never mentions `scripts/kern-dir`. Missing WORK says "no kern working files". No `$(` anywhere (tested).
3. Exit actions: recall-sessions exit 1 or 2 is quoted, "transcripts" goes to Sources skipped, nothing is tagged from transcripts, live state continues. wt-audit non-zero exit or `unknown` bucket goes to Sources skipped with evidence. Tracker absent or erroring, gh missing, `gh auth status` failing: Sources skipped. A null result from a source that ran is a finding. The Stops section says no step asks a question.
4. Added `[unverified, <source> unavailable]` to the tag list; "a transcript alone never earns a stronger tag". Pinned. Step 7 sends no-remote, gh and tracker failures to it.
5. Step 5 dispatches `kern:investigator` on model `model.miner`, absolute paths from `session` lines, one question, return budget 15 lines per session. Commands named: `grep -n` topic (piped to `cut -c1-300`), `wc -c`, `sed -n <first>,<last>p`, and `sed -n <n>p <file>` piped to `wc -c` to measure one record. G18 is enough (verified above); nothing blocked, G18 untouched. If it ever blocks one, the skill says run it yourself.
6. `<wt>` is the path on the ledger's `Worktree:` line. A `<wt>` not in `git worktree list`, or a failing `wt-snap`, rules the tag out: `[unverified, worktree unavailable]`, saying the worktree is gone. A differing tree means tag by PR or branch.
7. Kept the intro sentence naming `wt-snap` as the one exception (adds git objects); Stops says "read-only, the same under autopilot; `wt-snap` is the one exception named above".

Deviations
- Red flags is a `| Thought | Reality |` table of 5 rows, not the brief's bullets: the C11 spec and every other skill use the table. Rows are short to fit the cap.
- Brief pin `model.miner` occurs in step 5 and the Inputs table, so the test pins `dispatch `kern:investigator` on model `model.miner`` instead. Likewise `[unverified, <source> unavailable]` is pinned only in the output contract; step 7 says "the unverified tag".
- Map row inserted after the last table row, not appended at file end (the brief's append would land after the "Close calls" list, outside the table).
- Added tests beyond the brief for gaps 2 to 7, a ledger-fixture test, and `$(`/`history.jsonl` absence checks. Step 4 text describes `session` and `prompt` line columns.
- Sources skipped line shortened to "naming each source that did not run" to meet the cap.

NOTICED BUT NOT TOUCHING
- The fixture ledger (copied from the brief) has no `Worktree:` line, so it cannot exercise `[verified, uncommitted]`.
- The brief's evals say "floci swap", a project name from the spec; the spec's own acceptance text uses it.
- investigator.md's G18 list omits `cut` and `jq`, which g18-readonly-agent.sh allows; the prose is narrower than the guard.
- lint-skills prints no budget line, so the budget has to be computed by hand.
- Brief says the ledger's "last `tree=`"; every Task line carries one, and a `Wave:`/`Worktree:` line has none, so "last" means last Task line of that work. The skill words it "that work's last `tree=`".

## Fix round 1

SHA: 5aa70ba. Bytes: SKILL.md 7,194 (cap 7,200), references/chat.md 1,326 (cap 2,000), transcripts.md 1,399.
Gates: full suite pass 180 fail 0; lint clean; route-eval passed, rank-1 83%; plugin validate passed.
- I1: `[verified, uncommitted]` needs last `tree=` equal to a fresh wt-snap AND the snapshot differing from `git -C <wt> rev-parse HEAD^{tree}`; equal means committed, tag by branch or PR.
- I2: step 5 restores "read the full transcript region, not a grep line or summary".
- I3: no `Worktree:` line, missing worktree or failing wt-snap: tag from branch or PR when a branch is known, else `[unverified, worktree unavailable]`; next move still from the incomplete ledger task.
- I4: chat mode moved to references/chat.md (step 9 points to it, count first). Restored from the source: user remembers only their last message, name things they know, say what is still running, nothing happened then say so and stop, say so instead of guessing, skip steps that changed nothing, name work you can do yourself in one line, link the detail and write the summary so the user can decide without opening it. Re-read the whole source: nothing else dropped (the plain-voice link is covered by the kernel's unslop). Chat pins and headings are in the test.
- I5: pinned the load-bearing survivors. Removal mutations on pins: 92 (SKILL 76, chat 16), 92 killed, 0 survived. Sentence-deletion run: SKILL 55 of 68 killed (survivors are the heading, table scaffolding, red-flag rows and the intro sentence); chat 16 of 16.
- M1: miner brief says G18 denies `>` even inside quotes; use `grep -F`, no redirection. Also added the M2 clause (exit 2 outside a git repository: no live state either, say so and stop).
- Left alone as ruled: map.md routed row, floci wording, absolute work_dir, bare-repo parent, investigator.md.
