# 0.2.1 implementer report (part 1)

Commits: ae69859 P1 (PreToolUse asks when a hook library cannot load), 9adafbe P2 (no mode line or terse reminder on scheduled prompts), d24d82d P3 (session-start removes state files idle for 30 days), 6067560 P4 (more natural-language voice switches, with a phrase corpus). On top of e4032c8; no shared files.
P1: each library sourced with `|| no_lib <name>`, then `declare -F` for the plan's nine functions grouped by library; no_lib prints ask, or deny when stdin matches "permission_mode"[[:space:]]*:[[:space:]]*"bypassPermissions"; reason "kern G0: hook library <name> did not load; reinstall kern"; exit 0.
P2: `<scheduled-task` sets SCHEDULED=1; no mode line or terse reminder; under autopilot only the autopilot ON line.
P3: find "$STATE_DIR" -maxdepth 1 -type f \( -name '*.state' -o -name '.state.*' \) -mtime +30 ! -name "$SID.state" -delete; skipped when the state dir is a symlink.
P4: phrases added to natural() and _nl_ok; off patterns first; bare terse only as the whole line; trailing then go/stop terse. Corpus tests/fixtures/mode-activation/cases.json: 73 cases (23 on, 22 off, 28 none), 5 known_failing.
Counts (bash 3.2 and 5): pre-tool-use 11 -> 13; prompt-submit 18 -> 23; session-start 10 -> 16; subagent-start 2 -> 3; state 11. shellcheck -S warning clean; node 71/71; lint clean; hook-shape 8.
Fail-before: P1 tests 9 and 10 failed (json.sh missing gave ask with empty reason; missing function gave empty stdout). The three settings.sh-missing tests for the other hooks passed before (they already exit 0 silently). P2 tests 19 and 20 failed as expected.

# part 2
P3 fail-before: test 11 (old state file removed). Mutation checks: dropping `! -name "$SID.state"` or the symlink check fails the matching keep-test (symlink test uses a logging find shim).
P4 fail-before: the 22 new phrases; the stale-list check fired on "fix the bug, and do not then go terse" before the trailing clause existed.
known_failing: activate terse mode; turn off terse mode; disable terse mode; switch to normal mode (all " mode" variants fail _nl_ok's suffix); "fix the bug, and do not then go terse" switches on (mid-line negation unseen by the trailing clause) — a false switch.
Deviations: spec 8.4 rule 4 adds "Without its libraries it cannot read autopilot, so it denies under bypassPermissions instead"; bypass match allows space before the colon; settings-missing tests live in each hook's bats; scheduled + autopilot prints only the autopilot line; extra P3 tests (maxdepth, name filter, read-only dir, find shim); none cases run from both voices; trailing clause accepts final . or !, first line right-trimmed; skills/mode/SKILL.md phrase list and a NOTICE corpus line (idea only, three prompts reworded).
Found, not fixed: the need check covers only dispatcher functions, so a lib missing a guard helper (git_words) gives that guard command-not-found and maybe no vote; with settings.sh missing the other three hooks drop kern silently; quit terse mode does not switch; two pre-existing SC2016 infos (json.sh:9, settings.sh:164).
