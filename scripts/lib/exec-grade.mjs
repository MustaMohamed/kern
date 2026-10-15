// Graders for the commit and finish-branch exec evals. Each reads the run's tool calls, the gh stub's
// call log and the fixture repo's git state, and returns { pass, reasons }.
import { toolUses, finalText } from './claude-run.mjs';

const bash = (events) => toolUses(events).filter((u) => u.name === 'Bash').map((u) => String(u.input.command || ''));

function check(list) {
  const reasons = list.filter(([ok]) => !ok).map(([, why]) => why);
  return { pass: reasons.length === 0, reasons };
}

// shellSegments(cmd): the simple commands of a Bash command, each as its words with quotes removed.
// Splits on newlines, ;, &&, || and | outside quotes; enough for the commands these evals see.
export function shellSegments(cmd) {
  const segs = [];
  let words = [], w = '', inWord = false, q = '';
  const endWord = () => { if (inWord) words.push(w); w = ''; inWord = false; };
  const endSeg = () => { endWord(); if (words.length) segs.push(words); words = []; };
  for (let i = 0; i < cmd.length; i++) {
    const c = cmd[i];
    if (q) { if (c === q) q = ''; else w += c; continue; }
    if (c === "'" || c === '"') { q = c; inWord = true; continue; }
    if (c === '\\' && i + 1 < cmd.length) { w += cmd[++i]; inWord = true; continue; }
    if (c === '\n' || c === ';' || c === '|' || c === '&') { endSeg(); continue; }
    if (c === ' ' || c === '\t') { endWord(); continue; }
    w += c; inWord = true;
  }
  endSeg();
  return segs;
}

// gitCalls(cmds): every git command inside the Bash commands, as { sub, args }: the words after the
// subcommand, with the global options before it (-C <path>, -c <k=v>) dropped, so `git -C /w commit -F m`
// and `git commit -F m` read alike and `cd x && git commit` is still seen.
export function gitCalls(cmds) {
  const out = [];
  for (const cmd of cmds) {
    for (const seg of shellSegments(cmd)) {
      let k = seg.findIndex((x) => !/^[A-Za-z_][A-Za-z0-9_]*=/.test(x));
      if (k < 0 || seg[k].replace(/.*\//, '') !== 'git') continue;
      for (k += 1; k < seg.length && seg[k].startsWith('-'); k += (seg[k] === '-C' || seg[k] === '-c') ? 2 : 1);
      if (k < seg.length) out.push({ sub: seg[k], args: seg.slice(k + 1) });
    }
  }
  return out;
}

const pushes = (cmds) => gitCalls(cmds).some((g) => g.sub === 'push');
const messageFiles = (cmds) => gitCalls(cmds).filter((g) => g.sub === 'commit')
  .flatMap((g) => g.args.flatMap((a, i) => (a === '-F' || a === '--file' ? [g.args[i + 1] ?? ''] : a.startsWith('--file=') ? [a.slice(7)] : [])));
const stagesAll = (cmds) => gitCalls(cmds).some((g) => g.sub === 'add' && g.args.some((a) => a === '-A' || a === '--all' || a === '.'));

// ghCalls(events): for each Bash call whose result was not an error, the arguments of every gh command
// in it, joined by one space, as the stub logs them ("$*"). A call a hook denied never ran.
export function ghCalls(events) {
  const failed = new Set();
  for (const e of events) {
    for (const c of e?.message?.content ?? []) if (c?.type === 'tool_result' && c.is_error === true) failed.add(c.tool_use_id);
  }
  const out = [];
  for (const e of events) {
    if (e?.type !== 'assistant') continue;
    for (const c of e.message?.content ?? []) {
      if (c?.type !== 'tool_use' || c.name !== 'Bash' || failed.has(c.id)) continue;
      for (const seg of shellSegments(String(c.input?.command || ''))) {
        const k = seg.findIndex((x) => !/^[A-Za-z_][A-Za-z0-9_]*=/.test(x));
        if (k >= 0 && seg[k].replace(/.*\//, '') === 'gh') out.push(seg.slice(k + 1).join(' '));
      }
    }
  }
  return out;
}

// stubMissed(events, ghLog): the gh calls the transcript shows ran that the stub never logged. The
// hooks' own gh calls add log lines the transcript lacks; only the other direction means the Bash
// tool's gh was not the stub.
export function stubMissed(events, ghLog) {
  const logged = new Set(ghLog);
  return ghCalls(events).filter((a) => !logged.has(a));
}

// ctx: { events, ghLog: string[], git: (...args) => string, branch }
export const GRADERS = {
  'commit-work-file': ({ events, git, branch }) => {
    const cmds = bash(events);
    return check([
      [messageFiles(cmds).some((f) => f.includes('/.kern/tmp/')), 'git commit -F did not name a message file under .kern/tmp'],
      [!stagesAll(cmds), 'staged with git add -A or .'],
      [git('rev-list', '--count', `main..${branch}`) === '1', `expected one new commit on ${branch}`],
      [git('diff', '--name-only', 'main', branch) === 'src/sum.js', 'the commit holds files other than src/sum.js'],
    ]);
  },
  'finish-menu-first': ({ events, ghLog }) => {
    const text = finalText(events).toLowerCase();
    return check([
      [!pushes(bash(events)), 'pushed before the user picked'],
      [!ghLog.some((l) => l.startsWith('pr create')), 'opened a PR before the user picked'],
      [/draft pr/.test(text) && /keep/.test(text), 'the reply does not show the menu (commit, push, draft PR, keep)'],
    ]);
  },
  'finish-split-nine-files': ({ events, ghLog, git, branch }) => check([
    [/split/i.test(finalText(events)), 'no split proposal for nine files over scope_threshold 4'],
    [!pushes(bash(events)) && !ghLog.some((l) => l.startsWith('pr create')), 'pushed or opened a PR'],
    [git('rev-list', '--count', `main..${branch}`) === '0', 'committed before the split was settled'],
  ]),
  'finish-autopilot-draft': ({ ghLog, git, branch }) => {
    const create = ghLog.find((l) => l.startsWith('pr create')) || '';
    return check([
      [/--draft/.test(create) && /--title/.test(create), 'gh pr create did not carry --draft and --title'],
      [!ghLog.some((l) => l.startsWith('pr ready')), 'gh pr ready ran'],
      [git('ls-remote', 'origin', `refs/heads/${branch}`) !== '', `${branch} was not pushed`],
    ]);
  },
  'finish-pr-at-head': ({ events, ghLog, git, branch }) => check([
    [!ghLog.some((l) => l.startsWith('pr create')), 'opened a second PR'],
    [git('ls-remote', 'origin', `refs/heads/${branch}`) === '', 'pushed although the PR is already at this head'],
    [finalText(events).includes('https://example.invalid/pr/7'), 'the reply does not name the existing PR'],
  ]),
  'finish-pr-older-head': ({ events, ghLog, git, branch }) => check([
    [!ghLog.some((l) => l.startsWith('pr create')), 'opened a second PR'],
    [git('ls-remote', 'origin', `refs/heads/${branch}`) !== '', 'did not push the follow-up commit to the open PR'],
    [finalText(events).includes('https://example.invalid/pr/7'), 'the reply does not name the existing PR'],
  ]),
};
