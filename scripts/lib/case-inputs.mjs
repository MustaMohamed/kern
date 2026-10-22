// What each eval case reads, and the hash of it: the key the result cache uses and the test --changed
// applies. A case reads:
// - kern's core: every file the plugin copy holds outside skills/ (the kernel, hooks, scripts, agents,
//   modes, the manifest). Every session runs the hooks and gets the kernel, and any file there is one Read
//   away, so each counts for every case.
// - the frontmatter of every SKILL.md, which every session lists;
// - the whole folder of each skill the case routes to, and of each skill those folders name, by path
//   (skills/<name>/), as kern:<name>, or as a route to it ("route to implement", "routes to `plan`"), followed to
//   the end (skillClosure);
// - its fixtures and its own case entry.
// A file the plugin copy leaves out (COPY_OMITS) is no input, and another skill's body is none either. A
// file is hashed as git hashes a blob, with its mode, so a commit (git ls-tree) and the working tree compare
// alike, uncommitted and untracked files included.
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, lstatSync, readdirSync, readFileSync, readlinkSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { UsageError } from './args.mjs';
import { COPY_OMITS } from './run-record.mjs';

// blobSha(buf): git's blob id of buf (`git hash-object`).
export const blobSha = (buf) => createHash('sha1').update(`blob ${buf.length}\0`).update(buf).digest('hex');
const sha256 = (s) => createHash('sha256').update(s).digest('hex');
// canonical(v): v as JSON with every object's keys sorted, so key order is no change.
const canonical = (v) => JSON.stringify(v, (_, x) => (x && typeof x === 'object' && !Array.isArray(x) ? Object.fromEntries(Object.keys(x).sort().map((k) => [k, x[k]])) : x));
// JUNK: names no input holds: Finder's folder files, and git's own folder.
const JUNK = new Set(['.DS_Store', '.git']);

// walk(root, dir): [path, mode, sha] for each file under dir (root-relative, / separated), git's modes:
// 120000 a symlink (its target hashed), 100755 an executable file, 100644 any other.
function walk(root, dir) {
  const out = [];
  const visit = (abs) => {
    const st = lstatSync(abs);
    const rel = relative(root, abs).split(sep).join('/');
    if (st.isDirectory()) { for (const n of readdirSync(abs).sort()) if (!JUNK.has(n)) visit(join(abs, n)); return; }
    if (st.isSymbolicLink()) out.push([rel, '120000', blobSha(Buffer.from(readlinkSync(abs)))]);
    else if (st.isFile()) out.push([rel, st.mode & 0o111 ? '100755' : '100644', blobSha(readFileSync(abs))]);
  };
  if (existsSync(join(root, dir))) visit(join(root, dir));
  return out;
}

// treeSource(root, rev): the files of root's working tree on disk (rev null), or of commit rev (git ls-tree), as
// { root, rev, top(), list(prefix), text(path) }. list gives [path, mode, sha] for the file prefix or every file
// under the folder prefix, sorted; text gives a file's text, or null when it is not there.
export function treeSource(root, rev = null) {
  const memo = new Map();
  if (rev === null) {
    return { root, rev,
      top: () => readdirSync(root).filter((n) => !JUNK.has(n)).sort(),
      list: (prefix) => {
        const p = prefix.replace(/\/$/, '');
        if (!memo.has(p)) memo.set(p, walk(root, p));
        return memo.get(p);
      },
      text: (path) => { try { return readFileSync(join(root, path), 'utf8'); } catch { return null; } } };
  }
  const entries = execFileSync('git', ['-C', root, 'ls-tree', '-r', '-z', '--full-tree', rev], { encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 }).split('\0').filter(Boolean)
    .map((l) => { const [meta, path] = [l.slice(0, l.indexOf('\t')), l.slice(l.indexOf('\t') + 1)]; const [mode, , sha] = meta.split(' '); return [path, mode, sha]; })
    .filter(([path]) => !path.split('/').some((n) => JUNK.has(n)))
    .sort((a, b) => (a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0));
  const byPath = new Map(entries.map((e) => [e[0], e]));
  return { root, rev,
    top: () => [...new Set(entries.map(([p]) => p.split('/')[0]))].sort(),
    list: (prefix) => {
      const p = prefix.replace(/\/$/, '');
      return byPath.has(p) ? [byPath.get(p)] : entries.filter(([path]) => path.startsWith(`${p}/`));
    },
    text: (path) => {
      const e = byPath.get(path);
      if (!e) return null;
      if (!memo.has(path)) memo.set(path, execFileSync('git', ['-C', root, 'cat-file', 'blob', e[2]], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 }));
      return memo.get(path);
    } };
}

// kern(src): the plugin files of src (what pluginCopy copies), and what is read from them, memoized on src.
const OMIT_TOP = new Set(COPY_OMITS.top);
const OMIT_PATH = new Set(COPY_OMITS.paths);
const FRONTMATTER = /^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/;
function kern(src) {
  if (src.kern) return src.kern;
  const files = src.top().filter((t) => !OMIT_TOP.has(t)).flatMap((t) => src.list(t)).filter(([p]) => !OMIT_PATH.has(p));
  const skillFiles = new Map();
  for (const f of files) {
    const m = f[0].match(/^skills\/([^/]+)\//);
    if (!m) continue;
    if (!skillFiles.has(m[1])) skillFiles.set(m[1], []);
    skillFiles.get(m[1]).push(f);
  }
  const names = [...skillFiles.keys()].sort();
  const front = names.map((n) => [n, (src.text(`skills/${n}/SKILL.md`) ?? '').match(FRONTMATTER)?.[1] ?? '']);
  const refs = new Map();
  const named = (s) => {
    if (!refs.has(s)) {
      const text = skillFiles.get(s).map(([p]) => src.text(p) ?? '').filter((t) => !t.includes('\0')).join('\n');
      refs.set(s, names.filter((n) => n !== s && (text.includes(`skills/${n}/`) || new RegExp(`\\bkern:${n}(?![\\w-])|\\broute[sd]? to \`?${n}(?![\\w-])`, 'i').test(text))));
    }
    return refs.get(s);
  };
  src.kern = { names, skillFiles, named, hashes: new Map(names.map((n) => [n, sha256(JSON.stringify(skillFiles.get(n)))])),
    core: sha256(JSON.stringify(files.filter(([p]) => !p.startsWith('skills/')))),
    front: sha256(JSON.stringify(front)) };
  return src.kern;
}

// skillClosure(src, skills): skills, and every skill their folders name, followed to the end, sorted. A
// skill src does not hold throws.
export function skillClosure(src, skills) {
  const k = kern(src);
  const seen = new Set();
  const todo = [...skills];
  while (todo.length) {
    const s = todo.pop();
    if (seen.has(s)) continue;
    if (!k.skillFiles.has(s)) throw new Error(`case-inputs: no skill ${s} under skills/ in ${src.root}${src.rev ? ` at ${src.rev}` : ''}`);
    seen.add(s);
    todo.push(...k.named(s));
  }
  return [...seen].sort();
}

// caseInputs(src, { skills, entries, paths }, kernSrc): { hash, skills } for a case. skills are the kern skills it
// routes to (skills shows their closure); entries [{ file, pick }] the JSON files that hold its case text, pick
// finding its entry in the parsed file (a missing file or entry hashes as absent); paths the files or folders it
// copies (its fixtures). kern files come from kernSrc, by default src (adherence's --plugin names another tree).
export function caseInputs(src, { skills = [], entries = [], paths = [] }, kernSrc = src) {
  const k = kern(kernSrc);
  const closure = skillClosure(kernSrc, skills);
  const entry = ({ file, pick }) => {
    const text = src.text(file);
    if (text === null) return null;
    let found;
    try { found = pick(JSON.parse(text)); } catch { return `unreadable ${blobSha(Buffer.from(text))}`; }
    return found === undefined ? null : sha256(canonical(found));
  };
  const parts = { core: k.core, front: k.front,
    skills: closure.map((s) => [s, k.hashes.get(s)]),
    entries: entries.map((e) => [e.file, entry(e)]),
    paths: paths.map((p) => [p, sha256(JSON.stringify(src.list(p)))]) };
  return { hash: sha256(JSON.stringify(parts)), skills: closure };
}

// skillHashes(src): each kern skill's name to the hash of its folder's files.
export const skillHashes = (src) => kern(src).hashes;

// touchedSkills(events, hashes, roots): the kern skills (hashes' names) a run's tool calls read or called, sorted. A
// call reaches a skill when its input names skills/<name> (a Read, a Bash grep, a Grep path), kern:<name> (a Skill or
// slash command), or <name> as a Skill call's whole skill. One that names the skills folder itself, or a plugin root in
// roots, can read any skill, so it touches them all. /private/var and /var name one folder on macOS. A routing the
// static closure misses (the kernel sending a plan task to define) shows here, so a cached run stays valid only while
// every skill it touched is unchanged (eval-cache.mjs unitStore's fresh).
const unprivate = (s) => s.replace(/\/private(?=\/)/g, '');
const escapeRe = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
export function touchedSkills(events, hashes, roots = []) {
  const names = [...hashes.keys()];
  const end = '(?=["\'\\s*|;&)]|$)';
  const whole = new RegExp([`(?:^|[^\\w.-])skills/?${end}`, ...roots.map((r) => `${escapeRe(unprivate(r))}/?${end}`)].join('|'));
  const named = new Map(names.map((n) => [n, new RegExp(`skills/${escapeRe(n)}(?![\\w-])|\\bkern:${escapeRe(n)}(?![\\w-])`)]));
  const seen = new Set();
  for (const e of events) {
    if (e?.type !== 'assistant') continue;
    for (const c of e.message?.content ?? []) {
      if (c?.type !== 'tool_use') continue;
      const input = unprivate(JSON.stringify(c.input ?? {}));
      if (whole.test(input)) return [...names].sort();
      for (const n of names) if (named.get(n).test(input) || (c.name === 'Skill' && c.input?.skill === n)) seen.add(n);
    }
  }
  return [...seen].sort();
}

// dirHash(dir, omit): the hash of every file under dir, .git and each top-level name in omit left out: another
// plugin's content, or an h2h task's folder without its answer key, for h2h.
export const dirHash = (dir, omit = []) => sha256(JSON.stringify(walk(dir, '').filter(([p]) => !omit.some((n) => p === n || p.startsWith(`${n}/`)))));

// rangeSources(root, range): { before, after } for --changed <range>: A..B the two commits (an empty side is
// HEAD), A...B their merge base and B, and a lone rev that commit and the working tree, as `git diff <rev>`
// compares, untracked files included. An unknown rev is a UsageError.
export function rangeSources(root, range) {
  const commit = (rev) => {
    try { return execFileSync('git', ['-C', root, 'rev-parse', '--verify', '--quiet', `${rev || 'HEAD'}^{commit}`], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim(); } catch {
      throw new UsageError(`--changed: ${rev} is not a commit in ${root}`);
    }
  };
  if (!range) throw new UsageError('--changed: needs a git range, such as HEAD~1..HEAD, main... or HEAD');
  const three = range.indexOf('...');
  if (three >= 0) {
    const [a, b] = [commit(range.slice(0, three)), commit(range.slice(three + 3))];
    const base = execFileSync('git', ['-C', root, 'merge-base', a, b], { encoding: 'utf8' }).trim();
    return { before: treeSource(root, base), after: treeSource(root, b) };
  }
  const two = range.indexOf('..');
  if (two >= 0) return { before: treeSource(root, commit(range.slice(0, two))), after: treeSource(root, commit(range.slice(two + 2))) };
  return { before: treeSource(root, commit(range)), after: treeSource(root) };
}

// changedCases(cases, partsOf, before, after): the cases whose input hash differs between the two sources; partsOf(c)
// gives a case's { skills, entries, paths }. A case whose skill one side lacks counts as changed.
export function changedCases(cases, partsOf, before, after) {
  const hash = (src, c) => { try { return caseInputs(src, partsOf(c)).hash; } catch { return null; } };
  return cases.filter((c) => { const a = hash(before, c); return a === null || a !== hash(after, c); });
}
