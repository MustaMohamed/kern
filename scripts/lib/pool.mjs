// The session pool every eval runner shares (--jobs N). A paid round ran one session at a time: behave
// did 51 sessions in 28 minutes, each waiting on the last. limiter(n) bounds how many sessions run at once;
// ordered() hands results back in case order, so logs and snapshots read the same whatever finishes first.

// limiter(n): { run(fn, { priority }), close(err) }. run queues fn and returns its promise; at most n fns
// run at once. A free slot goes to the highest priority waiting, then to the one queued first: a grader
// call (priority 1) need not wait behind every arm session queued after its own arms. A fn that throws
// frees its slot and rejects only its own promise. close(err), after a fatal error, rejects every waiting
// fn and every later run with err; running ones finish.
export function limiter(n) {
  if (!Number.isInteger(n) || n < 1) throw new TypeError(`limiter needs a whole number of at least 1, got ${n}`);
  const waiting = [];
  let active = 0;
  let closed = null;
  let seq = 0;
  const next = () => {
    while (active < n && waiting.length) {
      let best = 0;
      for (let i = 1; i < waiting.length; i++) {
        const [w, b] = [waiting[i], waiting[best]];
        if (w.priority > b.priority || (w.priority === b.priority && w.seq < b.seq)) best = i;
      }
      const job = waiting.splice(best, 1)[0];
      active += 1;
      Promise.resolve().then(job.fn).then(job.resolve, job.reject).finally(() => { active -= 1; next(); });
    }
  };
  return {
    run(fn, { priority = 0 } = {}) {
      if (closed) return Promise.reject(closed);
      return new Promise((resolve, reject) => {
        waiting.push({ fn, priority, seq: seq++, resolve, reject });
        next();
      });
    },
    close(err) {
      closed = err;
      for (const job of waiting.splice(0)) job.reject(err);
    },
  };
}

// ordered(count, emit): done(i, value), to call once per index 0..count-1 in any order. emit(i, value)
// runs in index order, each as soon as every earlier index is done. An index done twice throws.
export function ordered(count, emit) {
  const held = new Map();
  let at = 0;
  return (i, value) => {
    if (i < at || held.has(i)) throw new Error(`ordered: index ${i} done twice`);
    held.set(i, value);
    while (at < count && held.has(at)) {
      const v = held.get(at);
      held.delete(at);
      emit(at, v);
      at += 1;
    }
  };
}
