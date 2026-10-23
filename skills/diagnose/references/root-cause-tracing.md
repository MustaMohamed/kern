# Root-cause tracing

A bug often shows up far from where it starts: the error is raised deep in the stack, but the bad value was made earlier. Fixing where the error appears treats a symptom. Trace back to the original trigger and fix there.

## Trace backward

1. Record the symptom exactly: the full error and stack.
2. Find the immediate cause: the line that directly produces the error.
3. Ask what called it, and with what value. Read the caller, not a guess about it.
4. Repeat one level up each time. Write each level as `caller -> callee (value)` so a wrong value is visible where it first appears.
5. Stop at the original trigger: the first place the value is wrong, not the last place it is used.

When a call chain is too long to read, or a test creates something unwanted and you do not know which one, instrument (below), or run `find-polluter.sh` (`flaky-and-async.md`).

## Instrument the boundaries

In a system with several components (CI, build, service, database), add one diagnostic line at each boundary before proposing any fix: what enters, what leaves, and which environment or config reached it. Run once, read where the value first goes wrong, then investigate only that component.

- Log before the risky operation, not after it fails.
- Include the value, the working directory, the relevant environment and the stack (`new Error().stack` or the language's equivalent); a secret only as set or unset, never its value.
- In tests, write to stderr; a logger may be silenced.
- Tag every line `[kern-dbg]` so cleanup is one `rg '\[kern-dbg\]'`.

## Fix at the source

The fix lands where the bad value is created, with a regression test at that seam, red before the fix. A symptom-point fix hides the bug for the next caller. When the value crossed several boundaries, a loud check at each is allowed after the root cause is fixed: see `defense-in-depth.md`.
