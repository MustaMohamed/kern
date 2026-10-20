---
status: approved
spec: .kern/specs/export.md
issue: none
base: main; promotion: none
approved: 2026-10-12, "approved, go"
execution: delegate
commits: ask
---

**Goal:** `toCsv(rows)` in `src/export.js` turns rows into CSV text, so totals can leave the service without copying them by hand.

**Architecture:** One pure function with no dependency. The first row's keys make the header line and each row makes one line of values; a value holding a comma or a quote is quoted, and no rows give an empty string. The tests call it directly from `test/export.test.js`.

## Global Constraints

- Always: keep `npm test` green.
- Ask first: a new dependency.
- Never: change the `sum` signature.

## Review Focus

- An empty list: `Object.keys` of a missing first row throws, so Task 3 must return before reading it (Task 3).
- A row whose keys differ from the first row's: no test exercises it, and the header comes from the first row only (Task 1).
- A value holding a line break: the spec quotes only commas and quotes, so such a value is left unquoted (Task 2).

## Open questions

None.

## File map

| Path | Task | Responsibility |
|---|---|---|
| `src/export.js` | 1, 2, 3 | `toCsv(rows)` |
| `test/export.test.js` | 1, 2, 3 | tests for acceptance 1 to 3 |

### Task 1: toCsv for plain values

**Files:**
- Create: `src/export.js`
- Test: `test/export.test.js`

**Interfaces:**
- Consumes: none
- Produces: `toCsv(rows) -> string`

**Blocked by:** none

**Acceptance:** 1

- [ ] Step 1: Write the failing test: `toCsv([{ a: 1, b: 2 }])` equals `"a,b\n1,2\n"`.
- [ ] Step 2: Run it to verify it fails. Run: `npm test`. Expected: the export test fails, since `src/export.js` does not exist yet.
- [ ] Step 3: Implement `toCsv(rows) -> string` in `src/export.js`: the first row's keys joined by commas, then each row's values in that key order, every line ending in `\n`.
- [ ] Step 4: Run it to verify it passes. Run: `npm test`. Expected: `# fail 0`.

### Task 2: quoting

**Files:**
- Modify: `src/export.js`
- Test: `test/export.test.js`

**Interfaces:**
- Consumes: `toCsv` from Task 1
- Produces: none

**Blocked by:** Task 1

**Acceptance:** 2

- [ ] Step 1: Write the failing test: `toCsv([{ a: 'x,y', b: 'say "hi"' }])` equals `'a,b\n"x,y","say ""hi"""\n'`.
- [ ] Step 2: Run it to verify it fails. Run: `npm test`. Expected: one fail, the values printed unquoted.
- [ ] Step 3: Quote in `toCsv` in `src/export.js`: a value holding a comma or a quote is wrapped in quotes, each quote inside it doubled.
- [ ] Step 4: Run it to verify it passes. Run: `npm test`. Expected: `# fail 0`.

### Task 3: no rows

**Files:**
- Modify: `src/export.js`
- Test: `test/export.test.js`

**Interfaces:**
- Consumes: `toCsv` from Task 1
- Produces: none

**Blocked by:** Task 2

**Acceptance:** 3

- [ ] Step 1: Write the failing test: `toCsv([])` equals `""`.
- [ ] Step 2: Run it to verify it fails. Run: `npm test`. Expected: one fail, a TypeError from reading the keys of a first row that is not there.
- [ ] Step 3: In `toCsv` in `src/export.js`, return `""` for an empty list before reading the first row's keys.
- [ ] Step 4: Run it to verify it passes. Run: `npm test`. Expected: `# fail 0`.
