# Task 23 review: self-review (a9ee546)

Spec verdict: issues
Quality verdict: needs-fixes

Controller rulings 1 to 4 were applied correctly: the investigator on `model.reviewer` gets one question plus two absolute paths and never the claim; the spec lane is `kern:task-reviewer` in `whole-branch` mode with the acceptance-line substitution sentence; `rebase first` has a checkable trigger; the cap is 6,400 and SKILL.md is 6,391. The problems are in the verdict step and the dropped Inputs rows.

## Critical

None.

## Important

### I1. `scope_threshold` default is gone, so step 9's `split` cannot be evaluated (dropped behaviour)
SKILL.md:20 (step 9) names `scope_threshold`. The Inputs table (SKILL.md:26-34) has no row, and the Inputs text says "unset takes the default".
- I ran `kern-get scope_threshold`: exit 3 (unset, no default given). `kern-detect scope_threshold`: exit 2, usage error (not a detectable key).
- Failure: a project that never set the key. The reader runs `kern-get`, gets exit 3, finds no default in the skill and no instruction to ask. It guesses a number or skips `split`. The 4-file default exists only in the spec table (spec line 97) and in sibling skills (define, plan, implement, execute-plan all restate it). Dropping it is a dropped behaviour, not a wording trim.
- Fix: restore the row `scope_threshold | 4 files` (about 30 bytes), or in step 9 write "`scope_threshold` (default 4)". Also say in the Inputs text that a key with no table default and exit 3 means ask.

`base_branch` and `lessons` are incomplete tables but not dropped behaviour. `base_branch` is named in step 1 and in the Inputs paragraph with the kern-detect fallback and the ask on double exit 3. `lessons` default is in step 10 ("unset: proposals stay in chat"). Note the general wording is also loose: `kern-get review.taxonomy` also exits 3 (I ran it), so "unset takes the default" only works because those rows carry defaults. Suggest "exit 3 takes the table default".

### I2. A probe exit 3 (inconclusive) can yield `ready`; the acceptance file says it must not
Step 9 `fix first` = "a failed check, an unresolved hit, a probe exit 1, or a finding in the two highest classes". Step 7 says probe exit 3 is "reported inconclusive, never as a pass" and only probe exit 2 is "a failed check". So a diff whose only issue is an inconclusive probe matches nothing in step 9 and falls to "Else `ready`".
- Contradicts `tests/skills/self-review.acceptance.md:11`: "A new guard test whose probe exits 3: ... the verdict is not `ready` on that test's account."
- The same hole exists for a skipped lane (`skip: built-in code-review not available`, `skip: no spec`). `references/claim-checks.md` says a check that did not run is failed, but that file scopes itself to the three scripts, so a reader cannot tell whether a skip line makes `fix first`. The acceptance file expects the other steps to run and implies no failure.
- Fix: step 9 `fix first` adds "a probe exit 3 or 2". State that a skip line is reported and does not by itself fail the verdict (or does; pick one and pin it).

### I3. Verdict has no outcome for "base not refreshed" when nothing else applies
Step 9: "Else `ready`, never with 'base not refreshed' reported." The four verdicts are the only ones. A clean diff, a failed fetch, no overlap detectable against the stale ref: `split`, `fix first`, `rebase first` do not apply and `ready` is withheld. Nothing is left to say; a reader picks one at random.
- Failure scenario: no remote, or offline. Step 1 asks (or parks under autopilot and goes on), everything passes, the reader reaches step 9 with no legal verdict.
- Fix: name the outcome. Simplest: failed fetch makes the rebase check unprovable, so the verdict is `rebase first` with the reason "base not refreshed", never rebasing here. Pin it in the test and the acceptance line (acceptance line 7 only says the report says "base not refreshed").
- Item 5 answer: the park/continue rule is consistent between step 1 and Stops (Stops says every stop parks with a default, and lists the failed fetch). It is stated only in Stops, not at step 1 where the reader acts; step 1 says "ask" alone. Acceptable given the shared Stops rule, but I3 is the real gap.

### I4. `split` trigger differs from the plan and the spec, and part of it cannot be checked
Plan and spec line 647: "Split when a round fixes the previous round's fixes, or when fixing findings pushed the diff past `scope_threshold`." Implemented (SKILL.md:20): "more changed paths than `scope_threshold` that the spec or plan does not approve, or a finding in an earlier self-review round's fix."
- Second clause changes the meaning. The source rule (`minimal-change-discipline`, round N fixing round N-1) fires on growth that happens while fixing findings. The implementation fires on any first-round diff with more than 4 unapproved paths, with no findings fixed yet. That is the plan-size gate that belongs to plan and finish-branch (spec line 733), not a self-review split. It also never fires when the diff grew through fix rounds on paths a plan approved, which is exactly the planned trigger.
- First clause cannot be checked: the skill never says where earlier self-review rounds are recorded. A fresh session has no earlier round. "A finding in an earlier self-review round's fix" needs a stored prior package or verdict, and nothing in the skill writes one. Item 3 asked "is it right?": no.
- Also unspecified: "does not approve" needs a plan or spec file list; with no plan (spec-only or ad hoc work) the clause degrades to any file count over 4.
- Fix: restate as the plan: `split` when this round's package changes a path set in which more than `scope_threshold` paths were added since the previous round's package (name where it is saved: `kern-dir reviews` already stores the packages, so "the newest earlier package in `kern-dir reviews` for this branch" is checkable), or a finding lands in code an earlier round added. Say "no earlier package: first round, neither clause applies".

### I5. Order of verdict list vs definitions can mislead; precedence of `fix first` over `rebase first` hides information
Step 9 lists `ready`, `fix first`, `rebase first` or `split`, "the first that applies". Reading left to right, `ready` is first and always applies. The definitions are evaluated split, fix first, rebase first, else ready (`split` first). Yes, a reader can take the wrong order, and the pin `\`ready\`, \`fix first\`, \`rebase first\` or \`split\`` in the test locks the confusing list order.
- When both `fix first` and `rebase first` apply, `fix first` wins. The report then loses the rebase need; the user fixes, re-runs and gets `rebase first` next round. Worse, fixes made on a stale base can conflict.
- Fix: write the list in evaluation order, "`split`, `fix first`, `rebase first`, else `ready`, tested in that order", and add "when `fix first` wins, still list the rebase need in the report". Update the pin.

## Minor

### M1. `<test>` in step 7 is not producible as written (item 6)
SKILL.md:18: "`<test>` the step 2 `test.focused` command on one test". `kern-detect test.focused` prints a template with a placeholder (`npm test -- {file}`, `pytest {file}`, `go test ./{dir}`; I read the script). The skill never says to substitute the placeholder, and "on one test" is ambiguous between a test, a file and a directory. Probe runs it as argv, so a command with env vars, pipes or `cd` fails in the fork with the wrong signal. Fix: "`<test>`: the `test.focused` command with `{file}` or `{dir}` replaced by the one test file that covers the new guard, no shell syntax".

### M2. `probe --exclude-tests <package>.patch` reverses the whole branch, not the guard
The package is branch-wide (merge base to working tree). Reversing every non-test change makes almost any test fail, which can read as `fail-then-pass ok` for a test that does not touch the guard. `claim-checks.md` says it "proves a guard test fails without its guard", which overclaims for a branch-wide patch. The brief and spec prescribe this exact command, so it is not an implementer defect, but the skill should say to pick a patch limited to the guard's files, or word the claim as "fails without the branch's changes". Probe's own blocked-pattern check only catches compile errors, not assertion failures from a missing feature.

### M3. `probe --mutate` argument semantics unstated
`<file>` is relative to `<wt>`, `<line>` is the line in the working-tree file, and probe inverts only the first operator on that line (`===`, `!==`, `==`, `!=`, `<=`, `>=`, `&&`, `||`, then `<`, `>`, `true`, `false`). Probe exit 3 if there is none. The implementer noted the last part and left it out. A reader taking `<line>` from the diff hunk header (old numbering) mutates the wrong line. One clause fixes it: "file relative to `<wt>`, line from the working file".

### M4. wt-diff exit paths other than 2 and 3 have no action
Step 1 handles exits 3 and 2. wt-diff has `set -e` and can exit with a git status (128) when `git diff` or `wt-snap` fails; `--allow` is unused so exit 4 cannot occur. A reader who sees exit 128 and a missing package has no instruction. Step 2 does say "any other non-zero exit is a failed check"; step 1 needs "any other non-zero exit: stop and report". The stdout facts are right: line 1 package path, line 2 the tree id, lines 3 on the changed paths, `<package>.patch` beside the package. Verified against `scripts/wt-diff`.

### M5. "two highest classes" depends on taxonomy order
`review.taxonomy` is a configurable list. "The two highest" is only defined if the list is ordered high to low. State it. The spec lane returns Critical/Important/Minor; the mapping to taxonomy classes is not stated, so Spec findings may never reach `fix first`.

### M6. claim-checks.md is not the verbatim contract text
The brief gives the file as "Full text". `diff` against the brief's block shows three edits, all in the exit-handling sentences: floor-scan adds "Exit 2 means the input is not a diff: a failed check" and rewords "at least one hit"; claim-check adds "Exit 1 means hits ... Any other non-zero exit is a failed check"; probe adds "the patch's test files", exit 1/2/3 sentences, and drops "`inconclusive` is reported as such" in favour of "Exit 3 is inconclusive and reported as such, never as a pass". All three match the scripts (floor-scan exit 0/1/2, claim-check 0/1/2, probe 0/1/3/2), and the file is 1,590 of 1,700. The edits are improvements, but the brief called the text verbatim. Record the deviation in the plan so later tasks that quote the file do not diff against the old text. No action on the skill.

### M7. Upstream losses are small
blast-radius.md vs `.upstream/pstack/.../blast-radius/SKILL.md`: the ladder, "find the one fact", where grep stops, risks/cleared and the "before you merge" output are all present. Lost: "never make up a caller or an API", "paste what happened" for the proving script, and the leading "what it does" output item. None is a gate; the first is worth one sentence. doubt-cycle.md vs `.upstream/addy/.../doubt-driven-development/SKILL.md`: contract-only handoff, the four classes in precedence order, doubt theater signal, three-cycle bound and "too big goes back to be split" are all kept. Lost: the adversarial prompt wording ("assume the author is overconfident ... state explicitly that you cannot find any") reduced to "find faults, not validate", and "stop on the user's ship it". The cross-model escalation is intentionally absent. Low impact.

### M8. Doubt theater stop has no autopilot form
doubt-cycle.md says "Stop and tell the user". Under autopilot, Stops says stops park as `parked: ...`. The reference does not say it parks. Minor, since Stops covers "a stop".

### M9. Pins do not cover the verdict definitions
Removal mutations on a scratch copy of HEAD (details below): the step 9 trigger text can be removed without a test failing. Missed: "the first that applies", "scope_threshold", "two highest classes", "Else `ready`", "a finding in an earlier self-review round", "`split`: more changed paths", "unresolved hit". These are exactly the lines I1 to I5 are about. Add pins for each definition, the evaluation order sentence and the Inputs row.

## Checks against the brief's seven items

1. Dropped rows: `scope_threshold` is a dropped behaviour (I1); `base_branch` and `lessons` are covered in text.
2. Order: yes, a reader can take the wrong order; `fix first` beats `rebase first` (I5).
3. Triggers: `split` differs and is partly unverifiable (I4); `fix first` is reasonable but misses probe exit 3 and skip lines (I2).
4. Script exits: floor-scan 0/1/2, claim-check 0/1/2, probe 0/1/2/3 and wt-diff 0/2/3 are all stated correctly. Gaps: probe exit 3 maps to no verdict (I2), wt-diff other exits (M4). No failure path reads as success except I2.
5. Autopilot fetch: consistent; the hole is the missing verdict (I3).
6. `<test>`: not producible as written (M1).
7. References: no gate lost (M6, M7).
8. Gates: all green (below).

## Cap note
SKILL.md is 6,391 of 6,400. I1 to I5 need roughly 250 to 400 more bytes. Do not drop behaviour to fit: raise the cap again in the spec (line 21 and C8 section 8) with the reason, as was done in f0d684e. Dropping the Outputs sentence about visual pages is not available either, since the test pins it.

## Commands run (read-only; scratch copy under t23/)
- `node --test 'tests/**/*.test.mjs'`: tests 132, pass 132, fail 0.
- `node scripts/lint-skills.mjs`: `lint: clean`.
- `node scripts/route-eval.mjs`: `route-eval: passed` (rank-1 rate 66%, baseline 0%).
- `wc -c skills/self-review/SKILL.md`: 6391.
- `kern-get scope_threshold|lessons|base_branch|review.taxonomy`: exit 3 each. `kern-detect scope_threshold`: exit 2. `kern-detect base_branch`: `main`, exit 0.
- `diff` of the brief's claim-checks block against `skills/self-review/references/claim-checks.md`: three changed lines (M6).
- Removal-mutation sample on a `git archive` copy of HEAD in `/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t23/copy`, 24 needles removed from SKILL.md, each followed by `node --test tests/skills/self-review.test.mjs`: 17 caught, 7 missed (M9). Caught included the fetch, wt-diff exit 3, probe exit handling, `never rebases`, the `parked:` format, `--comment` ban, investigator dispatch and question, `lessons are not written`, `never guess a command`.
- Side effect to disclose: running `bash scripts/kern-dir tmp` in the kern repo created `.kern/tmp` and appended `/.kern/` to `.git/info/exclude`. I removed both. `git status --short` is clean and the exclude file ends as before.
