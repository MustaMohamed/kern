import { test } from 'node:test';
import assert from 'node:assert/strict';
import { dueLabel } from '../src/dates.js';

test('a midday due date keeps its day', () => {
  assert.equal(dueLabel('2026-03-01T12:00:00Z'), '2026-03-01');
});
