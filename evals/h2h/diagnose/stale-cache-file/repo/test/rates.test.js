import { test } from 'node:test';
import assert from 'node:assert/strict';
import { convert } from '../src/rates.js';

test('ten dollars in euros', () => {
  assert.equal(convert(10, 'EUR'), 9.2);
});
