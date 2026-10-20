Status: DONE

# Task 3: no rows

What I did: `toCsv` in `src/export.js` now returns an empty string when there are no rows, and `test/export.test.js` has a test for acceptance 3.

RED: `npm test`

```
not ok 3 - toCsv of no rows is an empty string
  error: 'Cannot convert undefined or null to object'
# pass 3
# fail 1
```

GREEN: `npm test`

```
# pass 4
# fail 0
```

Full suite: `npm test`: `# pass 4`, `# fail 0`.

Files changed: `src/export.js`, `test/export.test.js`.

Concerns: none.
