# diagnose: acceptance checks (run during the M2b pilot)

- [ ] "The export endpoint returns 500 on empty filters": a command reproducing the 500 runs before any theory; the fix arrives with a test that was red first, and `probe` prints `probe: fail-then-pass ok` for it.
- [ ] A flaky test: `loop-rate.sh` runs N times and reports the red count before and after the fix.
- [ ] A bug that shows only on production data: read-only queries through the project's evidence agent; no writes and no instrumentation in production.
- [ ] The third fix fails: it stops and raises the design question.
- [ ] The user says "stop guessing": it goes back to the loop step.
