# Task 19 report: define

SHA: see `git log -1` (commit "M2: add the define skill"). RED: 3 failing, "skills/define/SKILL.md exists". GREEN: define test 3/3; full suite 108/108; lint clean; route-eval passed; plugin validate passed.
G20 replay (8 bats cases, scratch file): template Edit with quoted yes passes; invented quote, "sounds good", draft touched after the yes, autopilot all deny; parked status passes untouched; bounded Write passes with a quoted yes and denies with an invented one.
Plan-check: template full draft, short draft, short approved sample all exit 0.

Deviations from the brief:
1. Every approval is a typed chat reply, never AskUserQuestion (Task 14 ruling); stated in steps 9 and 10 and the Standing gate.
2. Step 9 writes the spec only after the yes, as a new file (G20 needs a draft older than the message or no draft).
3. Step 10: no touch of the file after the user's message except the one approval Edit. Template says the Edit spans `status: draft` through `approved:`.
4. Spec path comes from `kern-dir specs`; tracker from `kern-get`/`kern-detect`, ask on exit 3; spike `wt-new` exit 2 means ask; spike probe dir `WORK/tmp`.
5. Autopilot parked lines go in the spec's Open questions and the reply, since no ledger exists at define time (the brief said a ledger line).
6. Spec review runs on `model.reviewer` (default sonnet) in a general-purpose subagent.
7. G20 limit stated: quote is one whole line under 500 chars.
8. Template approved placeholder shortened to `approved: (unset until an explicit yes)`.
9. The brief's pocock grilling:28 source path does not exist; the "never ask a fact the repo can answer" sentence kept as written.
Concerns: kernel/routes.md does not exist yet, so the map row's "Routed row" wording is forward-looking (same as implement and diagnose rows). SKILL.md is 6498 of 6500 bytes.

## Fix round 1
- map.md: define row moved into the table after diagnose.
- Tests now pin the AskUserQuestion rule at both gates (counted twice), the step-back floor, `Verdict: approve | revise`, the calibration line, "approved before any module spec", every-path-parks, the post-yes no-touch rule, the plan-check rerun, the absolute reviewer path and the spec-system frontmatter line. On a scratch copy, removing each one fails the test (1 failure each; baseline 0).
- Step 10: the file stays untouched only after the user's yes message (revision after feedback is allowed); reviewer brief given as an absolute `${CLAUDE_PLUGIN_ROOT}` path; plan-check runs again after the approval edit.
- Restored "dispatched in one message", "A question that depends on an open one waits a round", and the gave-up line in interview.md.
- Autopilot: every path parks; autopilot is on when the kernel's "Autopilot:" line (kernel.md line 28, rendered by hooks/lib/render.sh autopilot_text) reads ON and the mode line says `autopilot=on`.
- A project spec system still carries `status` and `approved` frontmatter.
- kernel/settings.md: `model.reviewer` read-by now lists define.
- SKILL.md 6491 of 6500 bytes; the cap is unchanged.

## Fix round 2
- Autopilot rule: on per the latest kern signal (an `autopilot ON:` reminder or a `kern mode:` line with `autopilot=on`), else the kernel's Autopilot line; a turn with no mode line changes nothing. Pins updated; the new pins fail against the round-1 AND text on a scratch copy.
- SKILL.md 6499 of 6500. Not restored: the `work_dir` Inputs row (about 40 bytes) and "with a build order" in step 4 (16 bytes); neither fits without dropping something else.
