# Task template

Every task is the smallest unit with its own test cycle that a reviewer could reject on its own.

### Task N: <name>

**Files:**
- Create: `exact/path`
- Modify: `exact/path:start-end`
- Test: `exact/test/path`

**Interfaces:**
- Consumes: names and signatures this task uses from earlier tasks.
- Produces: names, parameters and return types later tasks rely on.

**Blocked by:** Task numbers, or none.

**Acceptance:** the spec's acceptance lines this task satisfies, as a leading list of numbers or ranges such as `1, 3-4` (plan-check parses only that list; a value with no leading list is an error).

- [ ] Step 1: Write the failing test: its name and assertions as code, with the spec's exact values.
- [ ] Step 2: Run it to verify it fails. Run: `<command>`. Expected: `<the failure and why>`.
- [ ] Step 3: Implement `name(params) -> result` in `exact/path`: one line on the approach where the signature and the test leave a choice; a code block only for an algorithm they do not determine, or for exact text the spec fixes.
- [ ] Step 4: Run it to verify it passes. Run: `<command>`. Expected: `<pass line>`.
- [ ] Step 5: Run the checklist lines: one line per `checklists` item, each with its check.

A step lets the executor write exactly one reasonable thing: unambiguous, not complete. A plan records the decisions the executor cannot make alone (files, names and signatures, the spec's values, the tests); a plan longer than the code it describes has written the code instead. Proportion: compare the plan with the spec; one several times longer, or mostly code blocks, trades bodies for signatures, test names and assertions.

No placeholders: no "TBD", no "add error handling", no "similar to Task N", no step that leaves a decision open. `plan-check` fails a task without Files, Consumes and Produces, Blocked by, Acceptance, or a `Run:` and `Expected:` pair.
