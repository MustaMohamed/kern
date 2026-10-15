# Defense in depth

After the root cause is fixed, a bad value that crossed several boundaries can get a loud check at each one it crossed. One check can be bypassed by another code path, a refactor or a mock.

## When a guard belongs

Only after the source fix and its regression test. A guard is not the fix, and it never replaces tracing the value to where it was made. Add one at a boundary the trace actually crossed, never one on a hunch.

## Four layers

1. Entry point: reject invalid input where it enters (empty, missing, wrong type).
2. Business rule: check that the value makes sense for this operation.
3. Environment: refuse a dangerous operation in a context where it must not run (for example a destructive call outside a temp directory in tests).
4. Debug instrumentation: capture the value and stack before the risky call, tagged `[kern-dbg]` and removed in cleanup.

Use the layers the trace crossed; a layer that no bad value passed through needs no check.

## Loud, never silent

Every check throws or fails with the value and where it came from. It never substitutes a default, skips the operation or logs and continues (kern's D6). A fallback that keeps an adjacent case working is a compatibility net: do not add one; redesign.

## Prove each layer

Each layer gets a test that is red without it. Try to bypass layer 1 and see layer 2 catch the value. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/probe --exclude-tests <wt> <change.patch> -- <test command>` and expect `probe: fail-then-pass ok` for the change that adds the layer.
