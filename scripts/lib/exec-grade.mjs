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
// Redirections (2>&1, >/dev/null, > file) are dropped: they are not arguments.
export function shellSegments(cmd) {
  const segs = [];
  let words = [], w = '', inWord = false, q = '', quoted = false, skip = false;
  const endWord = () => {
    if (inWord) {
      if (skip) skip = false;
      else if (!quoted && /^(\d*|&)(>>?|<)/.test(w)) skip = /^(\d*|&)(>>?|<)$/.test(w);
      else words.push(w);
    }
    w = ''; inWord = false; quoted = false;
  };
  const endSeg = () => { endWord(); skip = false; if (words.length) segs.push(words); words = []; };
  for (let i = 0; i < cmd.length; i++) {
    const c = cmd[i];
    if (q) { if (c === q) q = ''; else w += c; continue; }
    if (c === "'" || c === '"') { q = c; inWord = true; quoted = true; continue; }
    if (c === '\\' && i + 1 < cmd.length) { w += cmd[++i]; inWord = true; continue; }
    if (c === '&' && (cmd[i - 1] === '>' || cmd[i + 1] === '>')) { w += c; inWord = true; continue; }
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
// Staging more than the named files: add -A, --all, -u, --update, . or a bare * (the shell expands it),
// or commit -a. The git state checks in the grader catch the same by outcome.
const stagesAll = (cmds) => gitCalls(cmds).some((g) => (g.sub === 'add' && g.args.some((a) => ['-A', '--all', '-u', '--update', '.', '*'].includes(a)))
  || (g.sub === 'commit' && g.args.some((a) => a === '--all' || /^-[a-zA-Z]*a[a-zA-Z]*$/.test(a))));
const PR7 = /\.origin\/pull\/7(\D|$)/;
// A heuristic on the reply's wording, not a parse: a split is proposed when the reply says so
// (propose/suggest/recommend/consider ... split, "split into", "split this") and does not negate it
// ("did not propose a split", "no split needed", "will not split", "no need to split").
const proposesSplit = (text) => !/\b(not|never|won't|without|no need to)\b[^.]*\bsplit|\bno\s+split/i.test(text)
  && /\b(propos|suggest|recommend|consider)\w*[^.]*\bsplit|\bsplit (this|it|the \w+|into)\b|\bsplitting\b|into (two|three|four|\d+|several|separate|smaller) (commits|prs|pull requests|branches)/i.test(text);

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
      [messageFiles(cmds).some((f) => /(^|\/)\.kern\/tmp\//.test(f)), 'git commit -F did not name a message file under .kern/tmp'],
      [!stagesAll(cmds), 'staged with git add -A or .'],
      [git('rev-list', '--count', `main..${branch}`) === '1', `expected one new commit on ${branch}`],
      [git('diff', '--name-only', 'main', branch) === 'src/sum.js', 'the commit holds files other than src/sum.js'],
      [['M README.md', '?? notes.txt'].every((l) => git('status', '--porcelain').split('\n').map((x) => x.trim()).includes(l)), 'a decoy (README.md edit, notes.txt) was committed or lost'],
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
    [proposesSplit(finalText(events)), 'no split proposal for nine files over scope_threshold 4'],
    [!pushes(bash(events)) && !ghLog.some((l) => l.startsWith('pr create')), 'pushed or opened a PR'],
    [git('rev-list', '--count', `main..${branch}`) === '0', 'committed before the split was settled'],
  ]),
  'finish-autopilot-draft': ({ ghLog, git, branch }) => {
    const creates = ghLog.filter((l) => l.startsWith('pr create'));
    return check([
      [creates.length > 0 && creates.every((c) => /--draft/.test(c) && /--title/.test(c)), 'gh pr create did not carry --draft and --title'],
      [!ghLog.some((l) => l.startsWith('pr ready')), 'gh pr ready ran'],
      [git('ls-remote', 'origin', `refs/heads/${branch}`) !== '', `${branch} was not pushed`],
    ]);
  },
  'finish-pr-at-head': ({ events, ghLog, git, branch }) => check([
    [!ghLog.some((l) => l.startsWith('pr create')), 'opened a second PR'],
    [git('ls-remote', 'origin', `refs/heads/${branch}`) === '', 'pushed although the PR is already at this head'],
    [PR7.test(finalText(events)), 'the reply does not name the existing PR'],
  ]),
  'finish-pr-older-head': ({ events, ghLog, git, branch }) => check([
    [!ghLog.some((l) => l.startsWith('pr create')), 'opened a second PR'],
    [git('ls-remote', 'origin', `refs/heads/${branch}`) !== '', 'did not push the follow-up commit to the open PR'],
    [PR7.test(finalText(events)), 'the reply does not name the existing PR'],
  ]),
};
