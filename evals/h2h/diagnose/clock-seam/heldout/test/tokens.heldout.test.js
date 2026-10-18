import { test } from 'node:test';
import assert from 'node:assert/strict';
import { isExpired } from '../src/tokens.js';

test('before its expiry time a token is valid', () => {
  assert.equal(isExpired({ expiresAt: 2000000000 }, 1999999000000), false);
});

test('after its expiry time a token is expired, whatever the real clock says', () => {
  assert.equal(isExpired({ expiresAt: 2000000000 }, 2000001000000), true);
});
