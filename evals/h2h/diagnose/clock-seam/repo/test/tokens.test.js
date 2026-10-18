import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isExpired } from '../src/tokens.js';

test('a token that expires in an hour is not expired', () => {
  assert.equal(isExpired({ expiresAt: Math.floor(Date.now() / 1000) + 3600 }), false);
});
