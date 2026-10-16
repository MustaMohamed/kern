import { runClaude } from '/Users/musta/Code/projects/kern/scripts/lib/claude-run.mjs';
import { mkdtempSync, symlinkSync, mkdirSync, realpathSync } from 'node:fs';
import { tmpdir, homedir } from 'node:os';
import { join } from 'node:path';
const t = realpathSync(tmpdir()); const base = mkdtempSync(join(tmpdir(), 'c-'));
mkdirSync(join(base, 'ok')); symlinkSync(homedir(), join(base, 'link')); symlinkSync('/', join(base, 'root'));
const cases = { 'tmpdir itself': tmpdir(), 'home': homedir(), 'kern repo': '/Users/musta/Code/projects/kern', 'symlink->home': join(base, 'link'), 'symlink->/': join(base, 'root'), 'dotdot escape': join(base, 'ok', '..', '..', '..', '..', '..'), 'dotdot inside': join(base, 'ok', '..', 'ok'), 'nonexistent': join(base, 'nope'), 'sibling-prefix': t + '-evil', 'ok': join(base, 'ok') };
for (const [k, cwd] of Object.entries(cases)) {
  try { runClaude({ cwd, prompts: ['x'], model: 'm', timeoutMs: 1000, env: { PATH: '/nonexistent' } }); console.log(k.padEnd(16), 'unexpectedly ran'); }
  catch (e) { console.log(k.padEnd(16), (/not under|not usable/.test(e.message) ? 'REFUSED ' : 'PASSED CHECK -> ') + e.message.slice(0, 70)); }
}
