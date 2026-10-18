import { test } from 'node:test';
import assert from 'node:assert/strict';
import { dueLabel } from '../src/dates.js';

test('a due date just after midnight UTC keeps its day', () => {
  assert.equal(dueLabel('2026-03-01T00:30:00Z'), '2026-03-01');
});

test('a new-year due date keeps its year', () => {
  assert.equal(dueLabel('2026-01-01T03:00:00Z'), '2026-01-01');
});
