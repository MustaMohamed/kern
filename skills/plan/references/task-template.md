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

- [ ] Step 1: Write the failing test (the real test code).
- [ ] Step 2: Run it to verify it fails. Run: `<command>`. Expected: `<the failure and why>`.
- [ ] Step 3: Write the minimal implementation (the real code).
- [ ] Step 4: Run it to verify it passes. Run: `<command>`. Expected: `<pass line>`.
- [ ] Step 5: Run the checklist lines: one line per `checklists` item, each with its check.

No placeholders: no "TBD", no "add error handling", no "similar to Task N", no step that says what to do without showing it. `plan-check` fails a task without Files, Consumes and Produces, Blocked by, Acceptance, or a `Run:` and `Expected:` pair.
