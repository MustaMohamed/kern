# Slicing

## Vertical slices

A slice is one behaviour end to end, small enough for one test cycle: test, minimal code, green, next. Build one path through the stack (storage, API, UI) per slice, so each slice leaves something that works. Writing all tests first and all code after tests imagined behaviour.

Order: riskiest slice first, so a dead end shows before the rest is built. When two sides develop apart, fix the contract (types, schema) as slice 0.

## Seams

A seam is the public boundary a test calls: a public function, an HTTP handler, a CLI entry, a component. List the seams before writing tests, prefer ones that already have tests, and give each a line on what it catches and what it misses. Do not test a private function or an internal collaborator.

## Scope discipline

Touch only what the task needs. Do not tidy adjacent code, change imports in files you are not editing, or add features that seem useful. A file outside the approved list pauses the work (D9). Record anything else you notice:

```
NOTICED BUT NOT TOUCHING:
- <path>: <what, one line>
```
