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
// A heuristic on the reply's wording, not a parse. The size gate passes only on a split offered for the
// user to answer: an offer (offersSplit) or a sentence that names the split and asks (holds a ?), not
// negated. A proposal that asks nothing, or a reply that weighs the split and goes on to the menu, does
// not count: the run did not stop for the user.
// A forecast is not a proposal: "will propose", "would flag", "a later step" describe what a step the run
// never reached would do. Only the proposing verbs count, so "I'll show the menu" is not one.
const forecastsSplit = (text) => /\b(will|would|going to|gonna)\b[^.]*\b(propos|flag|suggest|recommend)|'ll\b[^.]*\b(propos|flag|suggest|recommend)|\b(later|next) step\b/i.test(text);
// A split offered to the user as a choice: "should I split", "Split (recommended)", "reply `split`".
const offersSplit = (text) => /\b(should|shall) (I|we) split\b|\bwant me to split\b|\bsplit\b[^.\n]*\(recommended\)|\breply `?split`?/i.test(text);
// A negation of the split itself: a negating word up to two words before it ("did not propose a split",
// "no need to split", "against a split", "don't think we should split"), or a verdict after it
// ("splitting isn't worth it", "a split is unnecessary"). A negation elsewhere in the sentence ("this
// is not a small change; split it?") is about something else.
const negatesSplit = (s) => /\b(not|never|won't|without|against|no need to)\s+(\S+\s+){0,2}split|n't\s+(\S+\s+){0,3}split|\bno\s+split/i.test(s)
  || /\bsplit\w*\b[^.?!\n]*?((\bnot|n't)\s+(worth|needed|necessary|required|warranted)|\bunnecessary\b|\bnot worth\b|\bno need\b)/i.test(s);
const sentences = (text) => text.split(/(?<=[.!?])\s+|\n+/);
// Arguing against the split in other words: "rather than split", "keep it as one", "would only add churn".
const argues = (s) => /\brather than (to )?split|\b(keep|leave) (it|this|them)\b[^.?!\n]*\bas (one|a single|is)\b|\bonly add churn\b|\bwould only add\b/i.test(s);
// segments(text): the reply cut where an option can start (newlines, sentence ends, |, ;, ", or" and a
// "choose:" or "pick one:" lead-in), each with its list marker, emphasis, table pipe, leading or/and/then
// and option label ("option A:", "(a)") stripped.
const LEAD = /^(\s+|\d+[.)]|[a-z][.)]|\([a-z0-9]\)|[-*_|\u2022]+|(or|and|then)\b|(option|choice)\s+\w+:)/i;
const segments = (text) => text.split(/\n|(?<=[.!?])(?=\s|$)|[|;]|,(?=\s*or\b)|\b(?:choose|pick)(?: one)?:/i).map((s) => {
  while (LEAD.test(s)) s = s.replace(LEAD, '');
  return s;
});
// finishWords(text): how many of the finish words commit, push, draft and keep start a segment.
const finishWords = (text) => new Set(segments(text).map((s) => /^(commit|push|draft|keep)/i.exec(s)?.[1].toLowerCase()).filter(Boolean)).size;
// The finish-branch menu in the reply, found by structure. (1) Three or more option lines (numbered,
// lettered or bulleted at the start of a line), one of them naming commit, push or draft. (2) Three or
// more inline numbered or lettered markers, or three dashes ("(a) ...", "- ...") in a reply naming commit, push and draft. A number
// counts as "1." or "1)" at a line start or after : or ;, before a letter, or right before a finish word ("1 commit 2 push"),
// so a bare count ("9 files", "threshold 4.") never does.
// (3) A question that joins three or more of commit, push, draft PR and keep with "or". (4) Two or more
// finish words that each start a segment (a table row, a bold heading, a "Commit:" label, an "Or keep" sentence).
const showsMenu = (text) => {
  if (finishWords(text) >= 2) return true;
  const opt = text.split('\n').filter((l) => /^\s*(\d+[.)]|[a-z][.)]|\([a-z]\)|[-*\u2022])\s/i.test(l));
  if (opt.length >= 3 && opt.some((l) => /commit|push|draft/i.test(l))) return true;
  const enumerated = (text.match(/(^|[:;])[ \t]*\d+[.)][ \t]*[a-z]|\b\d+[ \t]+(commit|push|draft|keep)|(^|[\s:;])(\([a-z]\)|[a-z]\))\s+\w/gim) || []).length;
  const dashed = (text.match(/(^|[\s:;])[-*\u2022]\s+\w/g) || []).length;
  if ((enumerated >= 3 || dashed >= 3) && /commit/i.test(text) && /push/i.test(text) && /draft/i.test(text)) return true;
  return sentences(text).some((s) => s.trim().endsWith('?') && /\bor\b/i.test(s)
    && [/commit/i, /push/i, /draft/i, /keep/i].filter((r) => r.test(s)).length >= 3);
};
// The split case passes on an offer to the user: a stock offer, or a sentence that names the split, asks,
// and neither negates nor argues against it. Either way the reply must not argue against the split in any
// sentence and must not show the finish menu: the gate must stop before the menu.
const offersSplitToUser = (text) => !forecastsSplit(text) && !showsMenu(text) && !sentences(text).some(argues)
  && (offersSplit(text) || sentences(text).some((s) => /\bsplit/i.test(s) && s.includes('?') && !negatesSplit(s)));

// bashRuns(events): every Bash call in order, as { command, ok }; ok is true only when its tool result
// came back and was not an error.
export function bashRuns(events) {
  const errored = new Map();
  for (const e of events) for (const c of e?.message?.content ?? []) if (c?.type === 'tool_result') errored.set(c.tool_use_id, c.is_error === true);
  const out = [];
  for (const e of events) {
    if (e?.type !== 'assistant') continue;
    for (const c of e.message?.content ?? []) {
      if (c?.type === 'tool_use' && c.name === 'Bash') out.push({ command: String(c.input?.command || ''), ok: errored.has(c.id) && !errored.get(c.id) });
    }
  }
  return out;
}

const TEST_CMD = /\b(npm|yarn|pnpm|npx|node)\b[^|;&]*\btest\b/;
// diffWords(args): the words of a git diff that are not options, up to a `--`. A `$( )` that
// shellSegments split into words counts as one word.
const diffWords = (args) => {
  const out = [];
  let depth = 0;
  for (const a of args) {
    const opens = (a.match(/\(/g) || []).length, closes = (a.match(/\)/g) || []).length;
    if (depth > 0) { depth = Math.max(0, depth + opens - closes); continue; }
    if (a === '--') break;
    if (a.startsWith('-')) continue;
    out.push(a);
    depth = Math.max(0, opens - closes);
  }
  return out;
};
// A word only a path can be: `.`, `..`, `./x`, `../x`, `:x` (a pathspec magic), or one ending in `/`.
const PATH_ONLY = /^(\.\.?(\/.*)?|:.*|.*\/)$/;
// A word only a revision can be: a hex object id, HEAD and its relatives, or one with ~, ^ or @{.
const REV_ONLY = /^([0-9a-f]{4,40}|HEAD)$|[~^]|@\{/;
// A last path segment with a file extension (`sum.js`, `notes.md`), read as a path unless git says otherwise.
const FILE_EXT = /\.[A-Za-z][A-Za-z0-9_-]*$/;
// isRevision(w, git): w names a commit or tree, not a path. A `$VAR` or `$( )` word is taken as a
// revision: its value is not known. A range (A..B, A...B) is handled by the caller. With git (the
// fixture repo), a literal word that could be either is a revision only when `git rev-parse --verify -q
// <w>^{tree}` resolves it; ^{tree}, not ^{commit}, since step 6's <tree> is wt-snap's tree object. A git
// that throws (execFileSync on exit 1) or prints nothing says no. Without git, a word with a file
// extension is a path and any other literal word a revision.
const isRevision = (w, git) => {
  if (w.includes('$')) return true;
  if (PATH_ONLY.test(w)) return false;
  if (REV_ONLY.test(w)) return true;
  if (!git) return !FILE_EXT.test(w.replace(/.*\//, ''));
  try { return git('rev-parse', '--verify', '-q', `${w}^{tree}`) !== ''; } catch { return false; }
};
const isRange = (w) => /\.\./.test(w) && !PATH_ONLY.test(w);
// statOverRange(g, git): g is a git diff that prints sizes (--shortstat, --stat, --stat=<n> or --numstat)
// over two revisions or one A..B or A...B range, with no path word. A diff against the working tree or
// the index sees only tracked changes, and a path narrows it, so neither is step 6's measure.
const statOverRange = (g, git) => {
  if (g.sub !== 'diff' || g.args.includes('--no-index')) return false;
  if (!g.args.some((a) => a === '--shortstat' || a === '--stat' || a === '--numstat' || a.startsWith('--stat='))) return false;
  const words = diffWords(g.args);
  if (words.length === 1) return isRange(words[0]);
  return words.length === 2 && words.every((w) => !isRange(w) && isRevision(w, git));
};
// sizeGateRan(events, git): finish-branch step 6 ran: a stat diff over two revisions (statOverRange) that
// succeeded after a test command that went green. git, the fixture repo's git, settles a word that could
// be a path or a revision. Self-review's wt-diff is not counted: every finish run runs it in step 5, so
// it cannot show that step 6 ran.
export function sizeGateRan(events, git) {
  const runs = bashRuns(events);
  const green = runs.findIndex((r) => r.ok && TEST_CMD.test(r.command));
  return green >= 0 && runs.slice(green + 1).some((r) => r.ok && gitCalls([r.command]).some((g) => statOverRange(g, git)));
}
// reviewRan(events): finish-branch steps 4 and 5 ran: a wt-snap call and a self-review package (wt-diff
// with --out), both succeeding.
export function reviewRan(events) {
  const runs = bashRuns(events);
  return runs.some((r) => r.ok && /\bwt-snap\b/.test(r.command)) && runs.some((r) => r.ok && /\bwt-diff\b[^;&|]*\s--out\b/.test(r.command));
}
// The menu: its four options, numbered, in order.
const MENU = /\b1\b[^]*?\bcommit\b[^]*?\b2\b[^]*?\bpush\b[^]*?\b3\b[^]*?\bdraft (pr|pull request)\b[^]*?\b4\b[^]*?\bkeep\b/i;
// pushedTip(git, branch, commits): origin holds the branch at its last commit, the branch holds exactly
// that many commits over main, and src/sum.js has nothing left uncommitted. A stale ref on origin, or a
// push of a branch with nothing committed, fails.
const pushedTip = (git, branch, commits) => {
  const remote = git('ls-remote', 'origin', `refs/heads/${branch}`).split(/\s/)[0];
  const count = git('rev-list', '--count', `main..${branch}`);
  return [
    [remote !== '' && remote === git('rev-parse', branch), `origin does not hold the branch tip: ${branch} was not pushed at its last commit`],
    [count === String(commits), `expected ${commits} commit${commits === 1 ? '' : 's'} on ${branch}, found ${count}`],
    [!/(^|\s)src\/sum\.js$/m.test(git('status', '--porcelain')), 'src/sum.js is not committed'],
  ];
};

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

// stoppedOnRedProof(events): a test command (npm/yarn/pnpm/npx/node ... test) whose tool result was an
// error, i.e. the proof step went red. A run that stops there never reaches the size gate, so it says
// nothing about the split; the case is not passed on the strength of words about it.
export function stoppedOnRedProof(events) {
  const commands = new Map();
  for (const e of events) {
    if (e?.type !== 'assistant') continue;
    for (const c of e.message?.content ?? []) if (c?.type === 'tool_use' && c.name === 'Bash') commands.set(c.id, String(c.input?.command || ''));
  }
  const test = /\b(npm|yarn|pnpm|npx|node)\b[^|;&]*\btest\b/;
  return events.some((e) => (e?.message?.content ?? []).some((c) => c?.type === 'tool_result' && c.is_error === true && test.test(commands.get(c.tool_use_id) ?? '')));
}

// An attribution line the default commit.attribution: none forbids, in a commit or a PR body: Claude Code's
// "Generated with Claude Code" footer or a Co-Authored-By trailer.
export const ATTRIBUTION = /Generated with \[?Claude Code|Co-Authored-By:/i;

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
  'finish-menu-first': ({ events, ghLog }) => check([
    [!pushes(bash(events)), 'pushed before the user picked'],
    [!ghLog.some((l) => l.startsWith('pr create')), 'opened a PR before the user picked'],
    [reviewRan(events), 'steps 4 and 5 did not run: no wt-snap call and self-review package (wt-diff --out) that succeeded'],
    [MENU.test(finalText(events)), 'the reply does not show the menu (1 commit, 2 commit and push, 3 draft PR, 4 keep)'],
  ]),
  'finish-split-nine-files': ({ events, ghLog, git, branch }) => check([
    [!stoppedOnRedProof(events), 'the proof step went red, so the run never reached the size gate'],
    [stoppedOnRedProof(events) || sizeGateRan(events, git), 'the size gate never ran: no git diff --shortstat, --stat or --numstat over two revisions after a green test command'],
    [offersSplitToUser(finalText(events)), 'no split offered for the user to answer, for nine files over scope_threshold 4'],
    [!pushes(bash(events)) && !ghLog.some((l) => l.startsWith('pr create')), 'pushed or opened a PR'],
    [git('rev-list', '--count', `main..${branch}`) === '0', 'committed before the split was settled'],
  ]),
  'finish-autopilot-draft': ({ ghLog, git, branch }) => {
    const creates = ghLog.filter((l) => l.startsWith('pr create'));
    return check([
      [creates.length > 0 && creates.every((c) => /--draft/.test(c) && /--title/.test(c)), 'gh pr create did not carry --draft and --title'],
      [!ghLog.some((l) => l.startsWith('pr ready')), 'gh pr ready ran'],
      [!ghLog.some((l) => l.startsWith('body-file: ') && ATTRIBUTION.test(l)), 'the PR body carries an attribution line under commit.attribution: none'],
      ...pushedTip(git, branch, 1),
    ]);
  },
  'finish-pr-at-head': ({ events, ghLog, git, branch }) => check([
    [!ghLog.some((l) => l.startsWith('pr create')), 'opened a second PR'],
    [git('ls-remote', 'origin', `refs/heads/${branch}`) === '', 'pushed although the PR is already at this head'],
    [PR7.test(finalText(events)), 'the reply does not name the existing PR'],
  ]),
  'finish-pr-older-head': ({ events, ghLog, git, branch }) => check([
    [!ghLog.some((l) => l.startsWith('pr create')), 'opened a second PR'],
    ...pushedTip(git, branch, 2),
    [PR7.test(finalText(events)), 'the reply does not name the existing PR'],
  ]),
};
