# Resume

Read this when the ledger already holds lines past `Main:`, and after compaction. Trust the ledger and the worktrees over memory. Steps 2 and 3 ran already: their lines are in the ledger, so rebuild only the todo list. For a task, r is 1 plus its review lines.

## Where to continue

The first case that holds, in this order:

1. No `Worktree:` line: step 5.
2. A task on a `Wave:` line has its `Task N: complete` line but no `Applied: Task N patch=<path>` line: step 11 for it, before the final review or any later task. A task a `parked:` line holds stays out, with every task blocked by it.
3. The first task in task order with no `Task N: complete` line, by its last line, `minor (deferred)` lines skipped:
   - none: step 6.
   - `Task N: start`: keep that tree as `tree-before`, with no second `task-start`. A snapshot still equal to it means nothing landed: dispatch again. A changed snapshot: review it at step 8 as round r.
   - a review that did not approve: write `Task N: fix round=<r> tree=<id>` with the reviewed tree and continue step 9; an r of 4 is past the cap, so stop with a split proposal.
   - `Task N: fix round=<r> tree=<id>`: resume that round; a fresh snapshot that differs from its tree is the round's `tree-after`.
   - an approving review: step 10.
4. Every task complete and applied: step 12.

A wave task resumes in the fork its `Wave:` line names. Never re-dispatch a completed task.

## Fix loop memory

Round r's findings are the reviewer's return saved as `<ledger dir>/reviews/task-N-r<r>.txt`. The next round gets that file. An implementer that cannot be reached (a new session, an agent that will not resume) is replaced by a fresh `kern:implementer` with the brief, the report and that file: the report file is the memory.
