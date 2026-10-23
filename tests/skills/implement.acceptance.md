# implement: acceptance checks (run during the M2b pilot)

Run each in a throwaway project with kern loaded (`claude --plugin-dir <kern repo>`), superpowers disabled for that project.

- [ ] An approved bounded change: the transcript shows a red test run before the first production edit, then green, then the full suite.
- [ ] A new test passes before any code change: it is reported as a finding and not used as RED, unless the tests were asked for on existing code. Then each one's RED is a caught `probe --mutate` of the line it covers, no production code changes, and one that fails on the unchanged code stops the run: the failure is shown with the question whether it is a bug for diagnose or the behaviour to pin.
- [ ] The change needs a file outside the approved list: the work pauses and names the file.
- [ ] No test runner is detectable: it asks for the command and does not guess `npm test`.
- [ ] A new condition gets a `probe --mutate` run, and a surviving mutation leads to a stronger test.
- [ ] A diagnosed fix arriving from diagnose step 7, and a `kern:implementer` worker: no `Building:` line and no entry-check question.
- [ ] A task with no agreed design that renames a stored field: implement says its `Building:` line right after its SKILL.md is read and before the next tool call; following that line and before any edit, it says the change touches stored data and asks whether to keep the fast path.
- [ ] `wt-new` exits 2 (no origin): implement says why and asks; it makes no worktree by hand.
- [ ] "Quick and clear: add a double(n) export with a test" reaching implement with no agreed design: step 1 says `Building: <what>. My choices: <each>.` right after implement's SKILL.md is read and before the next tool call, restates before the first edit a choice a later read changes, and asks nothing, since a new export is not a public API change; an earlier line that names no choice, such as "this takes the fast path", does not exempt the task.
