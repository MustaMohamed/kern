import { runClaude, runProblem, ClaudeRunError } from '/Users/musta/Code/projects/kern/scripts/lib/claude-run.mjs';
import { mkdtempSync, symlinkSync, mkdirSync, readFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const S = process.env.S;
const cwd = join(mkdtempSync(join(tmpdir(), 'w-')), 'app'); mkdirSync(cwd);
const kinds = process.argv.slice(2);
for (const k of kinds) {
  const t = k === 'hang' ? 1500 : 5000;
  try {
    const r = runClaude({ cwd, prompts: ['x'], model: 'm', timeoutMs: t, env: { PATH: `${S}/fk_${k}:/usr/bin:/bin`, ENVOUT: `${S}/envout` } });
    const p = runProblem(r);
    console.log(k.padEnd(18), p ? `INVALID: ${p}` : 'GRADEABLE');
  } catch (e) { console.log(k.padEnd(18), e instanceof ClaudeRunError ? (e.fatal ? 'FATAL: ' : 'INVALID(non-fatal): ') + e.message : 'THROW ' + e.message); }
}
