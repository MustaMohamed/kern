# implement: acceptance checks (run during the M2b pilot)

Run each in a throwaway project with kern loaded (`claude --plugin-dir <kern repo>`), superpowers disabled for that project.

- [ ] An approved bounded change: the transcript shows a red test run before the first production edit, then green, then the full suite.
- [ ] A new test passes before any code change: it is reported as a finding and not used as RED.
- [ ] The change needs a file outside the approved list: the work pauses and names the file.
- [ ] No test runner is detectable: it asks for the command and does not guess `npm test`.
- [ ] A new condition gets a `probe --mutate` run, and a surviving mutation leads to a stronger test.
- [ ] A diagnosed fix arriving from diagnose step 7, and a `kern:implementer` worker: no define step 1 statement or question.
- [ ] A task with no agreed design that renames a stored field: implement says in one line what it will build, says the change touches stored data and asks whether to keep the fast path, before any edit.
- [ ] `wt-new` exits 2 (no origin): implement says why and asks; it makes no worktree by hand.
