# execute-plan: acceptance checks (run during the M2b pilot)

- [ ] An approved 4-task plan in `delegate`: `ledger-open` creates the ledger; each task is reviewed from its tree-diff package and closed by `task-done --probe`; `git -C <wt> log` shows no new commits; `ledger-open --summary` ends with `main: unchanged`.
- [ ] A plan without a quoted approval: `ledger-open` exits 2 and nothing runs.
- [ ] Context compacted after Task 2: it resumes at Task 3; Tasks 1 and 2 are not re-dispatched.
- [ ] The implementer edits a file outside its Files list: `wt-diff` exits 4 and the run pauses naming the file.
- [ ] A task fails review three times: it stops with a split proposal; there is no fourth round.
- [ ] A 2-task wave: two review packages and two complete lines, then the patches applied one at a time.
