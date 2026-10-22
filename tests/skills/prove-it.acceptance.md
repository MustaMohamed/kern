# prove-it: acceptance checks (run during the M2b pilot)

Tick each item the first time its situation comes up in the pilot, with the session and the line that shows it.

- [ ] Before "done", "fixed" or "passing" after a code change, the proving command ran fresh in that session and its output was quoted.
- [ ] A subagent's "success" was checked by reading its worktree diff with `wt-diff`, or the files it names, before re-running its test, not by repeating its report; a failing test did not skip the read.
- [ ] An inconclusive run, a skipped run, or a run where zero tests ran was reported as a fail.
- [ ] A repo with a lint script and no typecheck: `verify.fast` runs lint alone, with no ask and no failed check, under autopilot too.
- [ ] A new regression test was probed with `probe --exclude-tests` and printed `probe: fail-then-pass ok`; exit 3 was reported as "probe inconclusive".
- [ ] "Requirements met" ticked each acceptance line from `spec.source` against evidence.
- [ ] A fix the reply proposed but did not run was written `inferred: <fix>`, and any other unchecked claim `inferred: <claim>` or `guess: <claim>`.
- [ ] Before a commit or a push, the Gate handed off by Read to `commit` or `finish-branch`, and that skill's steps were followed.
