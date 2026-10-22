// tests/pool.test.mjs: the session pool every eval runner shares (scripts/lib/pool.mjs).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { limiter, ordered } from '../scripts/lib/pool.mjs';

const tick = (ms = 0) => new Promise((r) => setTimeout(r, ms));
// gate(): a promise and the function that settles it, so a test decides when a job ends.
const gate = () => {
  let open;
  const p = new Promise((r) => { open = r; });
  return { p, open };
};

test('limiter runs at most n jobs at once, starts them in the order given, and hands back each result', async () => {
  const limit = limiter(2);
  const gates = [0, 1, 2, 3].map(gate);
  const started = [];
  let now = 0; let most = 0;
  const jobs = gates.map((g, i) => limit.run(async () => {
    started.push(i); now += 1; most = Math.max(most, now);
    await g.p;
    now -= 1;
    return `job ${i}`;
  }));
  await tick();
  assert.deepEqual(started, [0, 1], 'two run, two wait');
  gates[1].open(); await tick();
  assert.deepEqual(started, [0, 1, 2], 'a freed slot goes to the next in line');
  gates[0].open(); gates[2].open(); gates[3].open();
  assert.deepEqual(await Promise.all(jobs), ['job 0', 'job 1', 'job 2', 'job 3']);
  assert.equal(most, 2);
});

test('limiter: a job given a higher priority starts before the ones already waiting', async () => {
  const limit = limiter(1);
  const first = gate();
  const order = [];
  const jobs = [limit.run(async () => { order.push('arm 0'); await first.p; })];
  jobs.push(limit.run(async () => { order.push('arm 1'); }));
  jobs.push(limit.run(async () => { order.push('arm 2'); }));
  jobs.push(limit.run(async () => { order.push('grader'); }, { priority: 1 }));
  await tick();
  first.open();
  await Promise.all(jobs);
  assert.deepEqual(order, ['arm 0', 'grader', 'arm 1', 'arm 2']);
});

test('limiter: a job that throws frees its slot and rejects only its own promise', async () => {
  const limit = limiter(1);
  const bad = limit.run(async () => { throw new Error('one run failed'); });
  const good = limit.run(async () => 'next');
  await assert.rejects(bad, /one run failed/);
  assert.equal(await good, 'next');
});

test('limiter: close(err) rejects every waiting job with err, lets running ones finish, and refuses new ones', async () => {
  const limit = limiter(1);
  const running = gate();
  const ran = [];
  const a = limit.run(async () => { await running.p; ran.push('a'); return 'a'; });
  const b = limit.run(async () => { ran.push('b'); });
  await tick();
  const fatal = Object.assign(new Error('claude stopped at a usage limit'), { fatal: true });
  limit.close(fatal);
  await assert.rejects(b, (e) => e === fatal);
  await assert.rejects(limit.run(async () => ran.push('c')), (e) => e === fatal);
  running.open();
  assert.equal(await a, 'a');
  assert.deepEqual(ran, ['a'], 'the waiting job never started');
});

test('limiter needs a whole number of slots of at least 1', () => {
  for (const n of [0, -1, 1.5, NaN, '2']) assert.throws(() => limiter(n), /limiter needs a whole number of at least 1/);
});

test('ordered emits each index in order, as soon as every earlier one is done', () => {
  const out = [];
  const done = ordered(4, (i, v) => out.push([i, v]));
  done(2, 'c');
  assert.deepEqual(out, []);
  done(0, 'a');
  assert.deepEqual(out, [[0, 'a']]);
  done(1, 'b');
  assert.deepEqual(out, [[0, 'a'], [1, 'b'], [2, 'c']]);
  done(3, 'd');
  assert.deepEqual(out.map(([i]) => i), [0, 1, 2, 3]);
  assert.throws(() => done(3, 'again'), /ordered: index 3 done twice/);
});
