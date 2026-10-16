# M1 Task 8 report

Status: DONE

## What I did
Wrote tests/hooks/prompt-submit.bats, tests/hooks/payloads.bats and hooks/prompt-submit with the Write tool, transcribed from the brief. Overwrote the two untracked partial test files. Nothing was extracted from ~/.claude.

## TDD evidence
RED: `tests/run-bats tests/hooks/prompt-submit.bats tests/hooks/payloads.bats` before the hook existed: `bash .../hooks/prompt-submit` exited 127 (Command not found), BW01 warnings on every test.
GREEN after `chmod +x hooks/prompt-submit`: `1..17`, 17 ok, 0 not ok. Test 17 (pre-tool-use payload) skipped: "hooks/pre-tool-use arrives in Task 9".
Count: 12 prompt-submit + 5 payload = 17 (brief says 16; mcp_prompt test added by pre-flight ruling).
shellcheck hooks/prompt-submit: no findings, exit 0.

## Files changed
hooks/prompt-submit (new, executable), tests/hooks/prompt-submit.bats, tests/hooks/payloads.bats.

## Deviations / concerns
None. `<agent-message` is in KERN_WRAPPER_TAGS; the "wrapped prompts" test with a literal newline in the JSON string passes against the brief's code.

## Fix round 1
Changes: state.sh gains autopilot_denied_by (first denying layer, exit 1 if none), autopilot_on uses it; prompt-submit refuses `on` via it and names the file; render.sh autopilot_text uses it; envelope branch passes ALLOW_ON=0; `wrapped` now matches only at the start of TRIM (TRIM computed first), and a wrapped prompt skips switching but falls through to normal output.
Tests added (RED first: 7 failed: state 10, 11; prompt-submit 24, 25, 27, 28; session-start 37; the raw-submit test already passed): helper names user-level deny / exits 1; lower-layer deny refused; pasted envelope stays off; raw `/kern:autopilot on` turns on; later wrapper tag does not block "stop autopilot"; wrapped prompt under autopilot keeps state and prints `autopilot ON:`; session-start names $HOME/.claude/kern.yml.
Command: tests/run-bats state, prompt-submit, session-start, payloads .bats: 1..42, no not ok, 1 skip (Task 9). shellcheck on the three changed scripts clean.
