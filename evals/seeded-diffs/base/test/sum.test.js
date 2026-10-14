import { sum } from '../src/sum.js';
test('sum', () => {
  expect(sum(1, 2)).toBe(3);
  expect(sum(0, 0)).toBe(0);
});
