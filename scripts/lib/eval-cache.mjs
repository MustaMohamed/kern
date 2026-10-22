// What an eval run keeps so it can be resumed, re-graded or skipped (the fast-runner work after Task 17a):
// - the manifest, run.json in the results dir: the runner and its resolved options, which --resume reads back;
// - one record per unit of work, <unit>.result.json beside the unit's transcripts: its cache key and what it
//   graded, which --resume and --regrade read;
// - the cache, evals/results/cache/<runner>/ (gitignored, as all of evals/results): each valid unit's record and
//   transcripts under its key, the hash of everything the unit's result depends on (unitKey). A later run whose
//   unit has the same key reuses that result instead of starting a session, unless --no-cache.
import { createHash } from 'node:crypto';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, renameSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { UsageError } from './args.mjs';
import { blobSha } from './case-inputs.mjs';

const sha256 = (s) => createHash('sha256').update(s).digest('hex');
const canonical = (v) => JSON.stringify(v, (_, x) => (x && typeof x === 'object' && !Array.isArray(x) ? Object.fromEntries(Object.keys(x).sort().map((k) => [k, x[k]])) : x));

// unitKey(parts): the cache key of a unit, a sha256 of its parts as canonical JSON (key order is no change).
export const unitKey = (parts) => sha256(canonical(parts));

// filesVersion(root, files, extra): a version of the code that runs and grades a unit, the hash of each named
// file's content (root-relative) and of extra (a grader model, say). A missing file throws.
export const filesVersion = (root, files, extra = {}) => unitKey({ files: files.map((f) => [f, blobSha(readFileSync(join(root, f)))]), extra });

const entryDir = (cache, key) => join(cache, key.slice(0, 2), key);

// cacheGet(cache, key): { record, files: { name: path } } for the entry under key, or null when there is none or
// its record does not parse.
export function cacheGet(cache, key) {
  const dir = entryDir(cache, key);
  let record;
  try { record = JSON.parse(readFileSync(join(dir, 'record.json'), 'utf8')); } catch { return null; }
  const files = Object.fromEntries(readdirSync(dir).filter((n) => n !== 'record.json').map((n) => [n, join(dir, n)]));
  return { record, files };
}

// cachePut(cache, key, record, files): the entry under key, record and a copy of each file ({ name: source path },
// a folder copied whole), replacing any earlier one. It is built in a temp folder and renamed into place, so a
// reader never sees half an entry. When another process put the same key between the remove and the rename, its
// entry stays.
export function cachePut(cache, key, record, files = {}) {
  mkdirSync(cache, { recursive: true });
  const tmp = mkdtempSync(join(cache, '.put-'));
  try {
    writeFileSync(join(tmp, 'record.json'), `${JSON.stringify(record, null, 2)}\n`);
    for (const [name, src] of Object.entries(files)) cpSync(src, join(tmp, name), { recursive: true, verbatimSymlinks: true });
    const dir = entryDir(cache, key);
    mkdirSync(join(dir, '..'), { recursive: true });
    rmSync(dir, { recursive: true, force: true });
    try { renameSync(tmp, dir); } catch (e) { if (!['ENOTEMPTY', 'EEXIST'].includes(e.code) || !existsSync(dir)) throw e; }
  } finally { rmSync(tmp, { recursive: true, force: true }); }
}

// writeRecord(dir, unit, record), readRecord(dir, unit): <dir>/<unit>.result.json; a missing or unreadable one
// reads as null.
export const writeRecord = (dir, unit, record) => {
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, `${unit}.result.json`), `${JSON.stringify(record, null, 2)}\n`);
};
export function readRecord(dir, unit) {
  try { return JSON.parse(readFileSync(join(dir, `${unit}.result.json`), 'utf8')); } catch { return null; }
}

// writeManifest(dir, manifest, name): <dir>/<name> (run.json by default), the run's runner and resolved options. h2h
// names its own run-<model>-<filter>.json, since runs of two categories may share a results dir.
export const writeManifest = (dir, manifest, name = 'run.json') => {
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, name), `${JSON.stringify(manifest, null, 2)}\n`);
};

// openRun(path, runner): { m, dir, file } for --resume and --regrade. path is a manifest file, or a results dir holding
// run.json or exactly one run-*.json. A dir holding several runs, a missing or unreadable manifest, or another
// runner's, is a UsageError.
export function openRun(path, runner) {
  let file = path;
  const none = () => new UsageError(`${path} holds no run.json: it is not a results dir this runner wrote (or a run from before --resume and --regrade)`);
  let st;
  try { st = statSync(path); } catch { throw none(); }
  if (st.isDirectory()) {
    const runs = readdirSync(path).filter((n) => /^run(?:-.+)?\.json$/.test(n)).sort();
    if (!runs.length) throw none();
    if (runs.length > 1) throw new UsageError(`${path} holds ${runs.length} runs: pass one of ${runs.map((n) => join(path, n)).join(', ')}`);
    file = join(path, runs[0]);
  }
  let m;
  try { m = JSON.parse(readFileSync(file, 'utf8')); } catch (e) { throw new UsageError(`${file} is not JSON (${e.message})`); }
  if (m?.runner !== runner) throw new UsageError(`${file} was written by ${m?.runner ?? 'no runner'}, not ${runner}`);
  return { m, dir: dirname(file), file };
}
export const readManifest = (path, runner) => openRun(path, runner).m;

// lockedUpdate(file, update, { waitMs, staleMs }): file rewritten as update(text), text being its content or null when
// there is none, under <file>.lock, a folder mkdir makes only while no other process holds it, with the holder's pid in
// it (owner). So h2h runs of two categories at once, which share a results dir, both merge key.json and lose no key. The
// new text goes to a temp file renamed into place. A lock whose owner is dead, or older than staleMs (60 s), was left
// by a killed run: it is removed under <file>.lock.break, a second mkdir lock, and checked again there, so two waiters
// never both remove it (the second would remove the first's new lock). A live holder is waited for up to waitMs (30
// s), then it throws: the lock is held for a write of a few ms. An update that throws writes nothing and releases the
// lock.
const pidAlive = (pid) => { try { process.kill(pid, 0); return true; } catch (e) { return e.code === 'EPERM'; } };
const sleepMs = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
export function lockedUpdate(file, update, { waitMs = 30000, staleMs = 60000 } = {}) {
  const lock = `${file}.lock`;
  const brk = `${lock}.break`;
  const age = (p) => { try { return Date.now() - statSync(p).mtimeMs; } catch { return null; } };
  // left(): the lock is there and its holder is gone. An owner not written yet is a holder that has just taken it.
  const left = () => {
    const a = age(lock);
    if (a === null) return false;
    let pid = null;
    try { pid = Number(readFileSync(join(lock, 'owner'), 'utf8')) || null; } catch { pid = null; }
    return (pid !== null && !pidAlive(pid)) || a > staleMs;
  };
  const t0 = Date.now();
  for (;;) {
    try {
      mkdirSync(lock);
      writeFileSync(join(lock, 'owner'), String(process.pid));
      break;
    } catch (e) { if (e.code !== 'EEXIST') throw e; }
    if (left()) {
      try {
        mkdirSync(brk);
        try { if (left()) rmSync(lock, { recursive: true, force: true }); } finally { rmSync(brk, { recursive: true, force: true }); }
        continue;
      } catch (e) {
        if (e.code !== 'EEXIST') throw e;
        if ((age(brk) ?? 0) > staleMs) rmSync(brk, { recursive: true, force: true });
      }
    } else if (Date.now() - t0 > waitMs) throw new Error(`${lock} is held by another run for over ${waitMs / 1000} s`);
    sleepMs(10);
  }
  try {
    let text = null;
    try { text = readFileSync(file, 'utf8'); } catch (e) { if (e.code !== 'ENOENT') throw e; }
    const next = update(text);
    const tmp = `${file}.${process.pid}.tmp`;
    writeFileSync(tmp, next);
    renameSync(tmp, file);
  } finally { rmSync(lock, { recursive: true, force: true }); }
}

// unitStore({ raw, cache, from, noCache, resume, limit }): { unit({ name, key, files, work, priority, fresh }), stale(name,
// key, fresh) } for one run whose results dir is raw. unit gives the unit's record, with how it was got: 'resume',
// 'cache' or 'ran'. fresh(record), when given, must also hold for a record to be reused: a run's record names the kern
// skills it touched (case-inputs.mjs touchedSkills), and one of them that changed since makes it stale. stale says
// whether raw holds a valid record for the unit that --resume would not keep, for a runner to say so before it spends.
// - resume (--resume): raw's own record for the unit, kept as it is when it is valid and has this key; a record
//   whose key differs is stale, since the unit's inputs changed after it ran.
// - Else, unless noCache, a cache entry under key: its record, marked cached ({ from, at } of the run that made
//   it), and its files copied into raw, each replacing any file of that name there (a git object is read-only).
// - Else work(), in a slot of limit (pool.mjs) at priority when limit is given, so only work that runs holds one. It
//   writes the unit's files into raw and returns its record ({ valid, ... }); seconds, the time it ran, is added,
//   and a valid record is cached with the files named in files, which must then be in raw: each a name, or a pair
//   [name in the cache, name in raw] for a file whose name changes from run to run (h2h's blind ids). from names
//   this run in the cache entries it writes.
// Every record is written to raw as <name>.result.json with its key, so --resume and --regrade can read it; one that
// ran is written, and cached, before its slot is handed on.
export function unitStore({ raw, cache, from, noCache = false, resume = false, limit = null }) {
  return {
    stale(name, key, fresh = () => true) {
      const r = readRecord(raw, name);
      return !!r?.valid && (r.key !== key || !fresh(r));
    },
    async unit({ name, key, files = [], work, priority = 0, fresh = () => true }) {
      const pairs = files.map((f) => (Array.isArray(f) ? f : [f, f]));
      if (resume) {
        const r = readRecord(raw, name);
        if (r?.valid && r.key === key && fresh(r)) return { ...r, how: 'resume' };
      }
      const hit = noCache ? null : cacheGet(cache, key);
      if (hit?.record?.valid && fresh(hit.record)) {
        const rawName = new Map(pairs);
        for (const [n, p] of Object.entries(hit.files)) {
          const to = join(raw, rawName.get(n) ?? n);
          rmSync(to, { recursive: true, force: true });
          cpSync(p, to, { recursive: true, verbatimSymlinks: true });
        }
        const r = { ...hit.record, key };
        writeRecord(raw, name, r);
        return { ...r, how: 'cache' };
      }
      const ran = async () => {
        const t0 = Date.now();
        const r = { ...(await work()), key, seconds: Math.round((Date.now() - t0) / 100) / 10 };
        writeRecord(raw, name, r);
        if (r.valid) {
          const kept = Object.fromEntries(pairs.filter(([, f]) => existsSync(join(raw, f))).map(([c, f]) => [c, join(raw, f)]));
          cachePut(cache, key, { ...r, cached: { from, at: new Date().toISOString() } }, kept);
        }
        return { ...r, how: 'ran' };
      };
      return limit ? limit.run(ran, { priority }) : ran();
    },
  };
}

// timeStamp(now): the UTC time of day, HHMMSS, that names a --quick or --changed run's results dir, or a regrade file.
export const timeStamp = (now) => now.toISOString().slice(11, 19).replace(/:/g, '');

// reuseNote(units): how many of a case's units were reused, as the case's log line ends: ' (2 cached)', ' (1 cached,
// 1 kept from the resumed run)', or '' when every one ran.
export function reuseNote(units) {
  const n = (how) => units.filter((u) => u.how === how).length;
  const parts = [n('cache') && `${n('cache')} cached`, n('resume') && `${n('resume')} kept from the resumed run`].filter(Boolean);
  return parts.length ? ` (${parts.join(', ')})` : '';
}

// roundLine(units, ms, jobs): the line a runner prints after its last unit: the wall time, the sessions run and the
// units reused.
export function roundLine(units, ms, jobs) {
  const n = (how) => units.filter((u) => u.how === how).length;
  const s = Math.round(ms / 1000);
  const reused = n('cache') + n('resume');
  const from = [n('cache') && `${n('cache')} from the cache`, n('resume') && `${n('resume')} kept from the resumed run`].filter(Boolean).join(', ');
  return `round: ${Math.floor(s / 60)}m${String(s % 60).padStart(2, '0')}s wall; ${n('ran')} session(s) run, ${reused} reused${from ? ` (${from})` : ''}; --jobs ${jobs}`;
}
