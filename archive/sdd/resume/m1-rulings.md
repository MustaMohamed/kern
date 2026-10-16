Pre-flight table: preflight.md (71 rows, 15 findings). Rulings:
Ruling: M1 F1 accepted — Task 6 test matches *"push.policy=auto"* (the Set: line also lists foo.bar) — cost if wrong: none.
Ruling: M1 F2 accepted — Task 4 expects 12 tests (5 kern-dir, 7 kern-detect) — cost if wrong: none.
Ruling: M1 F3 accepted — kern_env unsets CLAUDE_CODE_ENTRYPOINT so the reminder test does not depend on the caller — cost if wrong: none.
Ruling: M1 F4 accepted — Task 17 replaces `bats tests/scripts` with `tests/run-bats tests/scripts` in both ci-local and ci.yml — cost if wrong: none.
Ruling: M1 F5 accepted — one Global Constraint line explains pretty versus TAP bats counts instead of editing 13 lines — cost if wrong: none.
Ruling: M1 F6 accepted — Task 18 greps `^(1\.\.|not ok)` instead of tail -1 — cost if wrong: none.
Ruling: M1 F7 accepted — spike blocks re-set SPIKE with ${SPIKE:?} and L, so an empty SPIKE cannot reach rm -rf — cost if wrong: none.
Ruling: M1 F8 accepted — task-notification fixture greps wrapper tags; subagent PreToolUse fixture greps "agent_type" — cost if wrong: a fixture picks the wrong line, caught by the replay test.
Ruling: M1 F9 accepted — Task 6 implementer trims the kernel's Precedence section to at most 420 chars and Autonomy to at most 650 without dropping a rule, so M2's eight rows fit under 4,000 — cost if wrong: rule 7 warns in M2 and M2 trims instead.
Ruling: M1 F10 accepted — autopilot skill names WORK/ledgers and resolves it with kern-dir — cost if wrong: none.
Ruling: M1 F11 accepted — prompt-submit dispatches an expansion only when expansion_type is slash_command (spec B2); new test covers mcp_prompt — cost if wrong: none.
Ruling: M1 F12 no change — G2 denies an open duplicate PR and asks for a merged or closed one with the same head; the spec's "duplicate" reads as an open PR — cost if wrong: one extra prompt where a deny was meant.
Ruling: M1 F13 accepted — contract text updated for nested kern-dir names — cost if wrong: none.
Ruling: M1 F14 accepted — plan wording says Settings files: is always printed — cost if wrong: none.
Ruling: M1 F15 accepted — guard timing check allows 1 s (measured 0.41 s on bash 3.2) — cost if wrong: a slow guard passes the check.
