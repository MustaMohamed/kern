# Standing rules for kern implementers (read after your brief)

- Repo: /Users/musta/Code/projects/kern. Work only there (plus temp dirs). Never touch any other repo.
- Run every command with `export PATH="$HOME/.volta/bin:$HOME/.local/bin:$PATH"` first (Volta node 22 must win over /usr/local/bin/node v18; bats 1.14.0 and shellcheck 0.11.0 are in ~/.local/bin).
- Run bats through `tests/run-bats <files>` (it puts macOS /bin/bash 3.2 first, the bash hooks meet). Every `[[ ]]` assertion in a .bats file ends with `|| false`; run-bats refuses a bare one. Scripts and hooks must run on bash 3.2.
- Expected bats counts in briefs are in the terminal format (`N tests, 0 failures`); piped output shows `1..N` and N `ok` lines.
- Transcribe the brief's code exactly. Test first: show RED for the expected reason, then GREEN. If a brief test fails against the brief's code, do not bend the test: report DONE_WITH_CONCERNS naming the test, the output and your minimal correction (apply it only when it is a typo-level fix of the plan, and say so).
- While iterating run the focused test; run the task's full test set once before committing.
- Commit exactly as the brief says: `git add -- <named paths>` (never -A), subject `M<n>: ...` (72 chars or fewer), no attribution trailers. Do not push.
- Never dispatch subagents or reviewers. Review is the controller's job.
- If a requirement is unclear, stop and report NEEDS_CONTEXT with specifics. If you cannot finish, report BLOCKED with what you tried.
- Self-review before reporting: everything in the brief is done, nothing extra, tests check behaviour, output pristine.
- Report: write the full report to the report path the controller gives (what you did, TDD evidence with commands and output, files changed, deviations, concerns). Then reply with ONLY (under 15 lines): Status (DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT), commits (short SHA + subject), one-line test summary, concerns, report path.
- Fix rounds: when resumed with findings, fix them test first, re-run the covering tests, append a fix report (changes, tests, command, output) to the same report file, and reply with the same short contract.
