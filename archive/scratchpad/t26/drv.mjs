import { runClaude, ClaudeRunError } from '/Users/musta/Code/projects/kern/scripts/lib/claude-run.mjs';
import { GRADERS } from '/Users/musta/Code/projects/kern/scripts/lib/exec-grade.mjs';
const [,, kind, tmo] = process.argv;
const PATH = `${process.env.S}/fk_${kind}:/usr/bin:/bin:${process.execPath.replace(/\/node$/,'')}`;
try {
  const r = runClaude({ cwd: process.env.S+'/empty', prompts: ['x'], model: 'm', timeoutMs: Number(tmo||5000), env: { PATH } });
  console.log(kind, 'RETURNED status', r.status, 'events', r.events.length, 'stderr', JSON.stringify(r.stderr.trim()));
  // would a no-event, status 0 run pass a grader?
  const g = GRADERS['finish-pr-at-head']({ events: r.events, ghLog: [], git: () => '', branch: 'b' });
  console.log('  grader finish-pr-at-head on those events:', JSON.stringify(g));
  const g2 = GRADERS['finish-menu-first']({ events: r.events, ghLog: [], git: () => '', branch: 'b' });
  console.log('  grader menu-first:', JSON.stringify(g2));
} catch (e) { console.log(kind, 'THREW', e.name, 'fatal=', e.fatal, e.message); }
