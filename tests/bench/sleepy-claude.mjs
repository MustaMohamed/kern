// tests/bench/sleepy-claude.mjs: a stand-in claude for timing the eval runners (eval-speed.mjs), never a real one. It
// answers `--version`, and otherwise reads stream-json turns on stdin and answers each after a sleep: 1 to 20 s for a
// session's turn, 1 to 3 s for a grader's, picked from a hash of the prompt so every round sleeps alike. It prints what
// the runners check: kern's SessionStart (the kernel when a --plugin-dir holds kernel/kernel.md), an init event that
// lists each --plugin-dir, and a result per turn; a grader prompt gets a reply in the shape its runner reads.
// SLEEPY_SCALE multiplies every sleep (default 1).
import { createHash } from 'node:crypto';
import { existsSync } from 'node:fs';
import { basename } from 'node:path';

const argv = process.argv.slice(2);
if (argv[0] === '--version') {
  console.log('9.9.9 (sleepy stand-in)');
  process.exit(0);
}
const scale = Number(process.env.SLEEPY_SCALE || 1);
const dirs = argv.flatMap((a, i) => (a === '--plugin-dir' ? [argv[i + 1]] : []));
const kern = dirs.some((d) => existsSync(`${d}/kernel/kernel.md`));
const out = (o) => process.stdout.write(`${JSON.stringify(o)}\n`);
const pick = (s, n) => parseInt(createHash('sha256').update(s).digest('hex').slice(0, 8), 16) % n;

// reply(prompt): a grader reply that parses: behave's verdicts, one per expectation, or h2h's grades, one per blind id.
const reply = (prompt) => {
  if (prompt.includes('\nExpectations:\n')) {
    const n = prompt.split('\nExpectations:\n')[1].split('\n\nRecord:')[0].split('\n').length;
    return JSON.stringify({ results: Array.from({ length: n }, (_, i) => ({ n: i + 1, pass: true, evidence: 'stand-in' })) });
  }
  const category = prompt.match(/attempts at the same (\w+) task/)?.[1];
  const fields = { plan: { unsupported: 0 }, review: { matched: [], decoys: [], unmatched: 0 } }[category] ?? {};
  const ids = [...prompt.matchAll(/^=== (arm-[A-Z]) ===$/gm)].map((m) => m[1]);
  return JSON.stringify({ grades: ids.map((id) => ({ id, score: 5, why: 'stand-in', ...fields })) });
};

let started = false;
let pending = 0;
let ended = false;
let buf = '';
const turn = (line) => {
  let text;
  try { text = JSON.parse(line).message.content[0].text; } catch { return; }
  if (!started) {
    started = true;
    out({ type: 'system', subtype: 'hook_response', hook_event: 'SessionStart', outcome: 'success', exit_code: 0, output: kern ? '# kern 9.9.9 (sleepy stand-in)\n' : '' });
    out({ type: 'system', subtype: 'init', session_id: `s${process.pid}`, cwd: process.cwd(), plugins: dirs.map((d) => ({ name: basename(d), path: d })) });
  }
  const grader = text.startsWith('You grade');
  const secs = grader ? 1 + pick(text, 3) : 1 + pick(text, 20);
  pending += 1;
  setTimeout(() => {
    const said = grader ? reply(text) : 'done';
    out({ type: 'assistant', message: { model: 'stand-in', content: [{ type: 'text', text: said }] } });
    out({ type: 'result', subtype: 'success', is_error: false, result: said });
    pending -= 1;
    if (ended && !pending) process.exit(0);
  }, secs * 1000 * scale);
};
process.stdin.on('data', (d) => {
  buf += d;
  for (let i; (i = buf.indexOf('\n')) >= 0; buf = buf.slice(i + 1)) turn(buf.slice(0, i));
});
process.stdin.on('end', () => { ended = true; if (!pending) process.exit(0); });
