// Graders for the commit and finish-branch exec evals. Each reads the run's tool calls, the gh stub's
// call log and the fixture repo's git state, and returns { pass, reasons }.
import { toolUses, finalText } from './claude-run.mjs';

const bash = (events) => toolUses(events).filter((u) => u.name === 'Bash').map((u) => String(u.input.command || ''));
// ranBash(events): the Bash commands whose tool result was not an error, as ghCalls reads them: a call that
// failed, or that a hook denied, did nothing (Task 17a, G7).
const ranBash = (events) => {
  const failed = new Set(events.flatMap((e) => (e?.message?.content ?? []).filter((c) => c?.type === 'tool_result' && c.is_error === true).map((c) => c.tool_use_id)));
  return events.flatMap((e) => (e?.type === 'assistant' ? (e.message?.content ?? []) : []))
    .filter((c) => c?.type === 'tool_use' && c.name === 'Bash' && !failed.has(c.id)).map((c) => String(c.input?.command || ''));
};

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
  return cmds.flatMap((cmd) => shellSegments(cmd).map(gitOf).filter(Boolean));
}
// commandHead(seg): the index of a simple command's name, past leading assignments; -1 when there is none.
const commandHead = (seg) => seg.findIndex((x) => !/^[A-Za-z_][A-Za-z0-9_]*=/.test(x));
// gitOf(seg): one simple command as { sub, args } when it runs git, else null.
const gitOf = (seg) => {
  let k = commandHead(seg);
  if (k < 0 || seg[k].replace(/.*\//, '') !== 'git') return null;
  for (k += 1; k < seg.length && seg[k].startsWith('-'); k += (seg[k] === '-C' || seg[k] === '-c') ? 2 : 1);
  return k < seg.length ? { sub: seg[k], args: seg.slice(k + 1) } : null;
};

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
// A split offered to the user as a choice: "should I split", "Split (recommended)", "reply `split`", or a
// yes/no choice tied to the split: a "(yes/no)", or a `yes:` and a `no:` that each open a line or a
// segment, where a sentence proposes the split ("**Proposed split**", "I propose splitting"), the
// "(yes/no)" sentence names it, or the yes: option does ("- **yes:** I stop here and you split the work.",
// the 2026-10-20 reply), none of them negated. A yes/no beside a split the reply calls harmless, or about
// something else, is no offer (Task 16h review, I1).
const YES_NO = /\((?:yes\s*\/\s*no|y\/n)\)/i;
const answer = (word) => (s) => new RegExp(`^${word}(?:\\*\\*|__)?\\s*(?::|\\)|\\s[-\\u2013\\u2014]\\s)`, 'i').test(s);
const yesNoChoice = (text) => YES_NO.test(text) || (segments(text).some(answer('yes')) && segments(text).some(answer('no')));
const proposes = (s) => /\b(propos|recommend|suggest)\w*\b[^.?!\n]*\bsplit/i.test(s);
const offersSplit = (text) => /\b(should|shall) (I|we) split\b|\bwant me to split\b|\bsplit\b[^.\n]*\(recommended\)|\breply `?split`?/i.test(text)
  || (yesNoChoice(text) && (sentences(text).some((s) => !negatesSplit(s) && (proposes(s) || (YES_NO.test(s) && /\bsplit/i.test(s))))
    || segments(text).some((s) => answer('yes')(s) && /\bsplit/i.test(s) && !negatesSplit(s))));
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
// A part of a proposed split, not a finish option: "Commit 1: src/sum.js alone", "Commit 2 or a separate branch".
const SPLIT_PART = /^commit\s+\d/i;
// finishStarts(list): how many of the finish words commit, push, draft and keep open one of the strings,
// a split part aside.
const finishStarts = (list) => new Set(list.filter((s) => !SPLIT_PART.test(s)).map((s) => /^(commit|push|draft|keep)/i.exec(s)?.[1].toLowerCase()).filter(Boolean)).size;
// A line of the split choice itself, not a finish option: its yes or no option ("yes:", "No split:",
// "Split (recommended):") or a split part ("Commit 1:"), once its marker and emphasis are stripped.
const choiceLine = (l) => { const s = segments(l)[0] ?? ''; return /^(yes|no|(no\s+)?split)\b/i.test(s) || SPLIT_PART.test(s); };
const ENUMERATED = /(^|[:;])[ \t]*\d+[.)][ \t]*[a-z]|\b\d+[ \t]+(commit|push|draft|keep)|(^|[\s:;])(\([a-z]\)|[a-z]\))\s+\w/gim;
const markers = (block) => (block.match(ENUMERATED) || []).length;
const namesFinish = (block) => /commit/i.test(block) && /push/i.test(block) && /draft/i.test(block);
// The finish-branch menu in the reply, found by structure.
// (1) Two or more distinct finish words that each start a segment: an option line (numbered, lettered or
// bulleted), a table row, a bold heading, a "Commit:" label, an "Or keep" sentence. A split's own
// "Commit 1" and "Commit 2" bullets are parts, not options, and a "no:" line that describes the menu
// opens with no finish word (2026-10-20).
// (2) In one paragraph, three or more inline numbered or lettered markers, or three dashes ("(a) ...",
// "- ..."), and the words commit, push and draft. A number counts as "1." or "1)" at a line start or after
// : or ;, before a letter, or right before a finish word ("1 commit 2 push"), so a bare count ("9 files",
// "threshold 4.") never does.
// (3) Across paragraphs, the lines that hold numbered or lettered markers, the split choice's own lines
// aside, hold three or more of them and the words commit, push and draft.
// (4) Three or more numbered or lettered option lines, the split choice's own lines aside, that name two
// or more distinct finish words as whole words ("1. Save it as one local commit", "3. Open a draft pull
// request"). Bullets are left to (1) and (2), so a status bullet such as "nothing committed" is no option.
// (3) and (4) catch the menus 71d22a2's rule caught (Task 16h review, M1).
// (5) A question that joins three or more of commit, push, draft PR and keep with "or".
const showsMenu = (text) => {
  if (finishStarts(segments(text)) >= 2) return true;
  const dashed = (block) => (block.match(/(^|[\s:;])[-*\u2022]\s+\w/g) || []).length;
  if (text.split(/\n[^\S\n]*\n/).some((b) => (markers(b) >= 3 || dashed(b) >= 3) && namesFinish(b))) return true;
  const lines = text.split('\n').filter((l) => !choiceLine(l));
  const marked = lines.filter((l) => markers(l) > 0).join('\n');
  if (markers(marked) >= 3 && namesFinish(marked)) return true;
  const options = lines.filter((l) => /^\s*(\d+[.)]|[a-z][.)]|\([a-z]\))\s/i.test(l));
  if (options.length >= 3 && new Set(options.flatMap((l) => l.match(/\b(commit|push|draft|keep)\b/gi) || []).map((w) => w.toLowerCase())).size >= 2) return true;
  return sentences(text).some((s) => s.trim().endsWith('?') && /\bor\b/i.test(s)
    && [/commit/i, /push/i, /draft/i, /keep/i].filter((r) => r.test(s)).length >= 3);
};
// The split case passes on an offer to the user: a stock offer, or a sentence that names the split, asks,
// and neither negates nor argues against it. Either way the reply must not argue against the split in any
// sentence and must not show the finish menu: the gate must stop before the menu.
const offersSplitToUser = (text) => !forecastsSplit(text) && !showsMenu(text) && !sentences(text).some(argues)
  && (offersSplit(text) || sentences(text).some((s) => /\bsplit/i.test(s) && s.includes('?') && !negatesSplit(s)));

// resultText(c): a tool result's text, whether its content is a string or a list of text blocks.
const resultText = (c) => typeof c?.content === 'string' ? c.content : (Array.isArray(c?.content) ? c.content.map((x) => x?.text ?? '').join('\n') : '');
// chainParts(command): the parts of a chained Bash command, split on newlines, `;` and `&&` outside quotes
// and parentheses (a `|`, `||` or `$( )` stays inside its part).
export const chainParts = (command) => {
  const parts = [];
  let cur = '', q = '', depth = 0;
  const end = () => { if (cur.trim()) parts.push(cur.trim()); cur = ''; };
  for (let i = 0; i < command.length; i++) {
    const c = command[i];
    if (q) { cur += c; if (c === q) q = ''; else if (c === '\\' && q === '"') cur += command[++i] ?? ''; continue; }
    if (c === "'" || c === '"') { q = c; cur += c; continue; }
    if (c === '\\') { cur += c + (command[++i] ?? ''); continue; }
    if (c === '(' || c === '{') depth++;
    else if (c === ')' || c === '}') depth = Math.max(0, depth - 1);
    if (depth === 0 && (c === ';' || c === '\n')) { end(); continue; }
    if (depth === 0 && c === '&' && command[i + 1] === '&') { end(); i++; continue; }
    cur += c;
  }
  end();
  return parts;
};
// echoLabel(part): an `echo <label>=<value>` part as { label, live }: label is the text up to and with `=`
// ("rc=", "snap rc="), live is true when the value is `$?` (or `${?}`), false for a literal number; null for any other part.
const echoLabel = (part) => {
  const m = /^echo\s+(?:-\w+\s+)*(["']?)([^"'$]*=)\s*(\$\{?\?\}?|-?\d+)\1\s*$/.exec(part);
  return m ? { label: m[2].trimEnd(), live: m[3][0] === '$' } : null;
};
// hasPipe(part): an unquoted `|` that is not half of `||`; the part's `$?` is then its last command's.
const hasPipe = (part) => {
  let q = '';
  for (let i = 0; i < part.length; i++) {
    const c = part[i];
    if (q) { if (c === q) q = ''; else if (c === '\\' && q === '"') i++; continue; }
    if (c === "'" || c === '"') q = c;
    else if (c === '\\') i++;
    else if (c === '|') { if (part[i + 1] === '|') i++; else return true; }
  }
  return false;
};
// partResults(command, output, errored): each part of a chained command as { command, ok, marked }. Each echo that
// prints `<label>=` consumes the next printed `<label>=N` in the output, in order; a part followed by an echo of `$?`
// is ok when that printed N is 0, so a literal echo or an earlier line cannot stand in for it, and marked is true.
// When a label's echoes and printed lines differ in number, or the part is a pipeline with no earlier
// `set ... pipefail`, or no echo of `$?` follows, the part keeps the old reading, ok when the call did not
// error, and marked is false.
const partResults = (command, output, errored) => {
  const parts = chainParts(command);
  const echoes = parts.map(echoLabel);
  const printed = new Map(), used = new Map();
  const lines = (label) => {
    if (!printed.has(label)) {
      const re = new RegExp(`(?:^|[^\\w])${label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/\s+/g, '\\s+')}\\s*(-?\\d+)`, 'g');
      printed.set(label, [...output.matchAll(re)].map((m) => m[1]));
    }
    return printed.get(label);
  };
  const echoCount = (label) => echoes.filter((e) => e?.label === label).length;
  const pipefail = (i) => parts.slice(0, i).some((p) => /^set\s+(-\w+\s+)+pipefail\b/.test(p));
  const nth = new Map();
  const at = parts.map((_, i) => {
    const e = echoes[i];
    if (!e) return null;
    const n = nth.get(e.label) ?? 0;
    nth.set(e.label, n + 1);
    return lines(e.label).length === echoCount(e.label) ? lines(e.label)[n] : null;
  });
  return parts.map((part, i) => {
    const next = echoes[i + 1];
    const value = next?.live && !echoes[i] ? at[i + 1] : null;
    if (value === null || value === undefined || (hasPipe(part) && !pipefail(i))) return { command: part, ok: !errored, marked: false };
    return { command: part, ok: value === '0', marked: true };
  });
};

// bashRuns(events): every Bash call in order, as { command, ok, parts, output }; ok is true only when its
// tool result came back and was not an error. parts reads each part of a chained command by its own printed
// exit code (partResults), so a later part that failed does not hide an earlier one that printed `rc=0`.
// output is the result's text ('' when none came back).
export function bashRuns(events) {
  const errored = new Map(), text = new Map();
  for (const e of events) for (const c of e?.message?.content ?? []) if (c?.type === 'tool_result') { errored.set(c.tool_use_id, c.is_error === true); text.set(c.tool_use_id, resultText(c)); }
  const out = [];
  for (const e of events) {
    if (e?.type !== 'assistant') continue;
    for (const c of e.message?.content ?? []) {
      if (c?.type !== 'tool_use' || c.name !== 'Bash') continue;
      const command = String(c.input?.command || '');
      const ok = errored.has(c.id) && !errored.get(c.id);
      out.push({ command, ok, parts: errored.has(c.id) ? partResults(command, text.get(c.id) ?? '', errored.get(c.id)) : [], output: text.get(c.id) ?? '' });
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
const SUMMARY_LINE = /\b\d+ files? changed\b/;
const NUMSTAT_ROW = /^(\d+|-)\t(\d+|-)\t\S/m;
const STAT_FLAG = (a) => a === '--stat' || a === '--shortstat' || a.startsWith('--stat=');
// statPrinters(command): which commands of a Bash call can print a stat line. summary: how many print an
// `N files changed` line, at most one each: a git command with --stat or --shortstat, git commit, merge,
// pull, cherry-pick or revert, and an echo or printf of such a line. numstat: how many print numstat rows
// (git with --numstat, or an echo or printf with a tab). many: a git log, show or whatchanged with a stat
// flag, or a git stash show, which print a line per commit, so lines cannot be counted against commands.
const statPrinters = (command) => {
  const out = { summary: 0, numstat: 0, many: false };
  for (const seg of shellSegments(command)) {
    const k = commandHead(seg);
    if (k >= 0 && ['echo', 'printf'].includes(seg[k].replace(/.*\//, ''))) {
      const text = seg.slice(k + 1).join(' ');
      if (SUMMARY_LINE.test(text)) out.summary += 1;
      if (/\t|\\t/.test(text)) out.numstat += 1;
      continue;
    }
    const g = gitOf(seg);
    if (!g) continue;
    const stat = g.args.some(STAT_FLAG), numstat = g.args.includes('--numstat');
    const stashShow = g.sub === 'stash' && g.args[0] === 'show';
    if ((['log', 'show', 'whatchanged'].includes(g.sub) && (stat || numstat)) || stashShow) out.many = true;
    if (stat || ['commit', 'merge', 'pull', 'cherry-pick', 'revert'].includes(g.sub)) out.summary += 1;
    if (numstat) out.numstat += 1;
  }
  return out;
};
// statPrinted(g, command, output): in a call that errored, output holds the stat line of its part git diff g.
// Output is not split by part, so lines are counted against the commands that print them: for --numstat,
// a numstat row and no other command that prints rows; else at least as many `N files changed` lines as
// commands that print one. A git log or show with a stat flag prints any number of lines, so no line counts.
const statPrinted = (g, command, output) => {
  const p = statPrinters(command);
  if (p.many) return false;
  if (g.args.includes('--numstat')) return p.numstat === 1 && NUMSTAT_ROW.test(output);
  return (output.match(new RegExp(SUMMARY_LINE.source, 'g')) || []).length >= p.summary;
};
// sizeGateRan(events, git): finish-branch step 6 ran: a stat diff over two revisions (statOverRange)
// after a test command that went green. It counts in a call that succeeded, or as a part of a call that
// errored (another part failed) when its own printed exit marker is not non-zero and the call's output
// holds its stat line (statPrinted): on 2026-10-20 the gate ran in a chained call whose last part exited 2.
// git, the fixture repo's git, settles a word that could be a path or a revision. Self-review's wt-diff is
// not counted: every finish run runs it in step 5, so it cannot show that step 6 ran.
export function sizeGateRan(events, git) {
  const runs = bashRuns(events);
  const green = runs.findIndex((r) => r.ok && TEST_CMD.test(r.command));
  const gate = (command, printed) => gitCalls([command]).some((g) => statOverRange(g, git) && printed(g));
  return green >= 0 && runs.slice(green + 1).some((r) => (r.ok ? gate(r.command, () => true)
    : r.parts.some((p) => !(p.marked && !p.ok) && gate(p.command, (g) => statPrinted(g, r.command, r.output)))));
}
// reviewRan(events): finish-branch steps 4 and 5 ran: a wt-snap call and a self-review package (wt-diff
// with --out), both succeeding.
export function reviewRan(events) {
  const runs = bashRuns(events);
  const partRan = (re) => runs.some((r) => r.parts.some((p) => p.ok && re.test(p.command)));
  return partRan(/\bwt-snap\b/) && partRan(/\bwt-diff\b[^;&|]*\s--out\b/);
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
      [messageFiles(ranBash(events)).some((f) => /(^|\/)\.kern\/tmp\//.test(f)), 'git commit -F did not name a message file under .kern/tmp'],
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
      // --fill takes the body from the commits, whose attribution G5 judges; any other create logs its body.
      [creates.every((c) => /--fill/.test(c)) || ghLog.some((l) => l.startsWith('body: ')), 'the PR body was not logged, so its attribution cannot be checked'],
      [!ghLog.some((l) => l.startsWith('body: ') && ATTRIBUTION.test(l)), 'the PR body carries an attribution line under commit.attribution: none'],
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
