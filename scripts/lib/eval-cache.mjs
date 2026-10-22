// What an eval run keeps so it can be resumed, re-graded or skipped (the fast-runner work after Task 17a):
// - the manifest, run.json in the results dir: the runner and its resolved options, which --resume reads back;
// - one record per unit of work, <unit>.result.json beside the unit's transcripts: its cache key and what it
//   graded, which --resume and --regrade read;
// - the cache, evals/results/cache/<runner>/ (gitignored, as all of evals/results): each valid unit's record and
//   transcripts under its key, the hash of everything the unit's result depends on (unitKey). A later run whose
//   unit has the same key reuses that result instead of starting a session, unless --no-cache.
import { createHash } from 'node:crypto';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
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
// reader never sees half an entry.
export function cachePut(cache, key, record, files = {}) {
  mkdirSync(cache, { recursive: true });
  const tmp = mkdtempSync(join(cache, '.put-'));
  try {
    writeFileSync(join(tmp, 'record.json'), `${JSON.stringify(record, null, 2)}\n`);
    for (const [name, src] of Object.entries(files)) cpSync(src, join(tmp, name), { recursive: true, verbatimSymlinks: true });
    const dir = entryDir(cache, key);
    mkdirSync(join(dir, '..'), { recursive: true });
    rmSync(dir, { recursive: true, force: true });
    renameSync(tmp, dir);
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

// writeManifest(dir, manifest), readManifest(dir, runner): <dir>/run.json, the run's runner and resolved options.
// Reading one that is missing, not JSON or another runner's is a UsageError.
export const writeManifest = (dir, manifest) => {
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, 'run.json'), `${JSON.stringify(manifest, null, 2)}\n`);
};
export function readManifest(dir, runner) {
  const f = join(dir, 'run.json');
  if (!existsSync(f)) throw new UsageError(`${dir} holds no run.json: it is not a results dir this runner wrote (or a run from before --resume and --regrade)`);
  let m;
  try { m = JSON.parse(readFileSync(f, 'utf8')); } catch (e) { throw new UsageError(`${f} is not JSON (${e.message})`); }
  if (m?.runner !== runner) throw new UsageError(`${f} was written by ${m?.runner ?? 'no runner'}, not ${runner}`);
  return m;
}
