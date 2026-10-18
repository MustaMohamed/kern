import { test } from 'node:test';
import assert from 'node:assert/strict';
import { canView } from '../src/roles/admin.js';

test('a clerk can view', () => {
  assert.equal(canView({ role: 'clerk' }), true);
});
