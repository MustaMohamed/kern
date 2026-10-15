# implement: acceptance checks (run during the M2b pilot)

Run each in a throwaway project with kern loaded (`claude --plugin-dir <kern repo>`), superpowers disabled for that project.

- [ ] An approved bounded change: the transcript shows a red test run before the first production edit, then green, then the full suite.
- [ ] A new test passes before any code change: it is reported as a finding and not used as RED.
- [ ] The change needs a file outside the approved list: the work pauses and names the file.
- [ ] No test runner is detectable: it asks for the command and does not guess `npm test`.
- [ ] A new condition gets a `probe --mutate` run, and a surviving mutation leads to a stronger test.
