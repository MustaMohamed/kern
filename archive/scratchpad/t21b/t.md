GOAL        one sentence; the outcome, runnable by someone with no chat access
SCOPE       paths this worker may write; paths it may not; its worktree path and base ref
            a directory entry ends in /, a prefix in *; wt-diff --allow reads these
CONTEXT     file pointers; upstream reports pasted in full when this unit depends on them
ACCEPTANCE  checkable criteria, one per line
VERIFY      exact commands, starting with wt-check <wt> <base-ref>, then the focused baseline
TIMEBOX     rough cap; on expiry return partial findings and stop
FORBIDDEN   commit, push, checkout, switch, reset, stash, clean, rebase, force anything, writes outside SCOPE, tracker or chat writes
REPORT      status line, files, commands run with results, deviations, report file path
STANDING    the standing orders below, pasted verbatim
