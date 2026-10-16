---
status: draft
spec: WORK/specs/exp.md
issue: none
base: main; promotion: none
approved:
execution:
commits: ask
---

**Goal:** one sentence.

**Architecture:** two or three sentences.

## Global Constraints

The spec's Constraints lines (Always, Ask first, Never), verbatim, then one line each for other exact values the spec fixes. Every task's brief includes this section.

## Review Focus

Inputs or conditions the spec implies but no test exercises, most likely first, each naming the task whose test pins it.

## Open questions

Spike: branch spike-x at abc1234; library does X, evidence: output below.
parked: scope; default: split into two PRs; why: over threshold.

## File map

| Path | Task | Responsibility |
|---|---|---|

| `src/a.ts` | 1 | a |
| `src/b.ts` | 2 | b |
| `src/c.ts` | 3 | c |
### Task 1: t1

**Files:**
- Create: `src/f1.ts`
- Modify: `src/m1.ts:1-9`
- Test: `test/f1.test.ts`

**Interfaces:**
- Consumes: none
- Produces: `fn1(x: string): string`

**Blocked by:** none

**Acceptance:** 1

- [ ] Step 1: Write the failing test (the real test code).
- [ ] Step 2: Run it to verify it fails. Run: `npm test`. Expected: `fails`.
- [ ] Step 3: Write the minimal implementation (the real code).
- [ ] Step 4: Run it to verify it passes. Run: `npm test`. Expected: `ok`.
- [ ] Step 5: Run the checklist lines: one line per `checklists` item, each with its check.

### Task 2: t2

**Files:**
- Create: `src/f2.ts`
- Modify: `src/m2.ts:1-9`
- Test: `test/f2.test.ts`

**Interfaces:**
- Consumes: none
- Produces: `fn2(x: string): string`

**Blocked by:** none

**Acceptance:** 2

- [ ] Step 1: Write the failing test (the real test code).
- [ ] Step 2: Run it to verify it fails. Run: `npm test`. Expected: `fails`.
- [ ] Step 3: Write the minimal implementation (the real code).
- [ ] Step 4: Run it to verify it passes. Run: `npm test`. Expected: `ok`.
- [ ] Step 5: Run the checklist lines: one line per `checklists` item, each with its check.

### Task 3: t3

**Files:**
- Create: `src/f3.ts`
- Modify: `src/m3.ts:1-9`
- Test: `test/f3.test.ts`

**Interfaces:**
- Consumes: none
- Produces: `fn3(x: string): string`

**Blocked by:** Task 1

**Acceptance:** 3

- [ ] Step 1: Write the failing test (the real test code).
- [ ] Step 2: Run it to verify it fails. Run: `npm test`. Expected: `fails`.
- [ ] Step 3: Write the minimal implementation (the real code).
- [ ] Step 4: Run it to verify it passes. Run: `npm test`. Expected: `ok`.
- [ ] Step 5: Run the checklist lines: one line per `checklists` item, each with its check.

