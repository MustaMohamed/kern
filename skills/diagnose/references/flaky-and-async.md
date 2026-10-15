# Flaky and async bugs

A flaky bug needs a higher reproduction rate before it can be diagnosed. A bug that fails half the time is debuggable; one that fails 1 in 100 is not yet.

## Raise the reproduction rate

Measure the rate, then raise it. Run the loop command N times and read the `loop-rate:` line:

`bash ${CLAUDE_PLUGIN_ROOT}/skills/diagnose/scripts/loop-rate.sh <n> -- <loop command>`

It prints `loop-rate: <red>/<N> red, median <seconds>s`. A run is red when the command exits non-zero. Raise the rate by looping the trigger 100 times, running copies in parallel, adding load, narrowing timing windows or injecting delays at the suspected race. Report the red count before the fix and after it; the same N both times.

## Wait for conditions, not time

A fixed sleep guesses at timing: it passes on a fast machine and fails under load. Poll for the condition itself.

1. Name the condition: an event arrived, a state is ready, a count reached, a file exists.
2. Poll it on a short interval (about 10 ms) and read fresh state inside the loop, never a value cached before it.
3. Always set a timeout, and fail with a message that names the condition and the time waited.
4. A fixed wait is right only when testing real timing (a debounce, a tick). Wait for the trigger first, then wait the known interval, and comment why.

## Test pollution

When a test leaves a file or directory behind and you do not know which test, bisect by running test files one at a time:

`bash ${CLAUDE_PLUGIN_ROOT}/skills/diagnose/scripts/find-polluter.sh POLLUTION_PATH TEST_GLOB -- TEST_CMD...`

Each test file is appended to `TEST_CMD`. The script prints `polluter: <file> creates <path>` and exits 1 at the first file that creates the path, and leaves the path in place; remove it before another run. It prints `no polluter found among <n> test files` and exits 0 when none does. Exit 2 means a usage error, no matching file, a missing test command, or a path that already exists.
