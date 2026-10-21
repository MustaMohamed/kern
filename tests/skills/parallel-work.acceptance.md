# parallel-work: acceptance checks (run during the M2b pilot)

- [ ] Three disjoint tasks: three forks, one message with three background agents, patches applied one by one, the full suite once in the integration worktree.
- [ ] Two tasks both touching `db/migrations`: they run serially, and the report says why.
- [ ] Two one-line fixes the user asks to run in parallel: a worktree and a worker each; their size is not given as a reason to run them inline.
- [ ] A worker returns no test output: it is respawned once, then reported as a gap.
- [ ] A brief without a TIMEBOX line: brief-check refuses it and nothing is spawned.
- [ ] An implementer returns DONE_WITH_CONCERNS: the table shows ISSUES with the concern.
