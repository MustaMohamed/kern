# Run rules

Every autopilot run follows this file: when it stops, how it unblocks itself, how fix rounds end and what it reports.

These rules cover kern's routes only. A job an `overrides.<job>` key leaves to another skill runs that skill: kern's guards still apply, and the report names the job.

## The stop list

| Autopilot stops for | Autopilot does not stop for |
|---|---|
| Merge to main | Reads |
| Deploy | Tests |
| Delete | Commits and pushes on its own branch |
| Spending money | A draft PR on tested or verified changes |
| A design choice that changes what gets built | |
| A required check that cannot run | |
| A ticket the run cannot read | |

A run stops only on this list. At a stop, the run brings the data it collected and a recommendation, then waits for a typed reply. Work that does not depend on the answer may finish first.

This list loosens nothing else: the stops in this file, a route's run-ending failures, a required check still red after its fix rounds and the user's stop predicate still stop a run. The kernel's Autonomy line still holds: an action it keeps for the user's word that this list does not name, such as a force-push to a shared branch, is skipped and reported.

Delete means data, remote branches, tags, and files outside the run's own worktree and scratch directories. Removing a file on the run's own branch is ordinary work.

A design choice stops the run when the ticket does not settle it and the answer changes user-visible behaviour, stored data shape, a public interface or the ticket's scope. Any other judgment takes a default and goes in the report.

A required check is one the ticket or prove-it names for the change. When one cannot run, the run pushes its branch, stops with the report and opens no PR. A typed reply that says to open the PR opens it.

A ticket the run cannot read is a stop: nothing else settles what to build, so the run reports each way it tried.

No guard covers spending money, so this rule alone holds it. A read against production follows the project's `protected_targets`.

## How a run unblocks itself

1. Try a safer route to the same result.
2. Find the answer in the project, docs, code and ticket, and collect the data needed to understand.
3. Decide, and record what was chosen and why.
4. If the decision is on the stop list, stop as above.
5. After 3 distinct routes, skip the step and record it. If later work depends on that step, stop. A required check is never skipped.

A route is distinct only if it is a different action. The same target and effect in other words is the same action, and it stays blocked.

## Fix rounds

A `fix first` verdict starts a fix round in place of ending the run, up to 3 per self-review. Each round fixes the findings and runs self-review again in full, including the checks the last round skipped. When a third round is still `fix first`, the run pushes its branch, stops with the report and opens no PR. No verdict also stops.

One go covers one draft PR.

| Case | What the run does |
|---|---|
| `split` from a finding on a line the last round changed | The fixes are not converging: stop with the report |
| `split` or the size gate on size alone | finish-branch's default: go on, with Scope giving the size |
| A plan over `scope_threshold` | plan's default: take the split and run the first slice. The report lists the rest, and each needs its own go |

## The run report

Every run ends with one report: the ticket and PR, each stop, each block and the route taken, each decision with its why, each skipped step, each check with its result, and the jobs that ran under another skill. `parked:` lines keep their format. A check that did not run is reported as a fail, not as "not run".

## Long output

Long output from a command that is not an allowed git or gh shape goes to a file in the directory `bash ${CLAUDE_PLUGIN_ROOT}/scripts/kern-dir tmp` prints, and the run reads its tail.
