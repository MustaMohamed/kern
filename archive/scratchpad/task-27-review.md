# Task 27 review: scripts/recall-sessions (commit 457dd6b)

Spec verdict: issues. The output format matches the Produces line, and the brief's own scope cases (sibling slug, `<repo>-old`, `<repo>/sub`) are handled. It still leaks in two configurations and has two D6 holes.
Quality verdict: needs-fixes (2 Important on D6, 2 Important on scope, rest Minor).

Scratch: /private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t27/ (HOME was always a scratch dir; repo untouched).

## Critical

None.

## Important

### I1. `--days 08` / `--days 09` drops every prompt, exits 0, message has no prefix (D6)
scripts/recall-sessions:92. `$(( ... days * 86400 ...))` reads `08` as octal. Bash prints `line 92: 08: value too great for base`. The error unwinds the enclosing `if`, which `set -e` does not catch. The script carries on and prints the sessions only, exit 0, on bash 3.2.57 and 5.3. Reproduced: `--days 09 --topic floci` gives 3 session lines, 0 prompt lines, rc 0. `--days 010` gives an 8-day prompt window while `find -mtime -010` gives 10 days, so the two windows disagree.
Failure scenario: `recall-sessions --days 09 --topic x` silently loses all prompts, and the recall skill reports "no prompts".
Fix: `days=$((10#$days))` after the digit check (line 36), and drop the leading zeros before `-mtime`.

### I2. An unreadable `~/.claude`, `~/.claude/projects` or `history.jsonl` parent gives a clean empty answer (D6)
scripts/recall-sessions:59 (`[ -d ... ] || continue`) and 87 (`[ -e "$hist" ]`). With `chmod 000 ~/.claude/projects`, or with `~/.claude` itself unreadable, the script prints nothing and exits 0. A dangling `history.jsonl` symlink does the same for prompts. The header says only a missing path is not an error. These are existing-but-unreadable, and `[ -d ]` / `[ -e ]` cannot tell them apart from missing. The test at bats:12 covers only the transcript folder and the history file.
Fix: before the loop, `if [ -e "$projects" ] || [ -L "$projects" ]; then [ -r "$projects" ] && [ -x "$projects" ] || die "cannot read $projects"; fi`. Do the same for `~/.claude` (the parent of `$hist`). Alternatively, let the failing `ls`/`find` of `$projects` itself decide.

### I3. A shared or absolute `worktree.dir` leaks other projects' transcripts and prompts (scope)
scripts/recall-sessions:45-46, 58, 110.
- Transcripts: `$projects/$wt_slug*` is a prefix glob on a slug in which `/` and `-` look the same. With `worktree.dir: /tmp/shared-wts`, `wt_slug` is `-tmp-shared-wts-`, which also matches the folder for `/tmp/shared-wts-other/x`. Reproduced: both `-tmp-shared-wts-other` and `-tmp-shared-wts-projB` were listed.
- Prompts: `index(p, WT) == 1` takes every project under that dir. Reproduced: a prompt with project `/tmp/shared-wts/projB` was printed. This is the exact "other project's prompts" case the task forbids.
- Same glob problem with the default dir: `<main>/.claude/worktrees-foo` (or `worktrees.foo`) has slug `<main slug>--claude-worktrees-foo`. Reproduced: it was listed.
Likelihood: the default dir is safe except the odd sibling `worktrees-*` (very unlikely). A shared worktree dir such as `~/worktrees` is a documented setting (`worktree.dir`) and a common habit, so for those users it is likely, and every project's worktrees leak.
Fix: bound worktree scope by what the worktrees are, not by the dir. List `git worktree list --porcelain` under `$MAIN`, compute each worktree's slug, and match the exact folder. Use the same list for the prompt filter (project equals one of the worktree paths, or is under one). If a dir-prefix match is kept, require it to be inside `$MAIN` and say so in the header.

### I4. `worktree.dir` relative with `..` silently finds nothing
scripts/recall-sessions:45-46. `wt_dir` returns `$MAIN/../wts` unnormalized, so the slug and the prompt prefix never equal what Claude Code records (`/x/wts/name`). Result: no worktree sessions or prompts, no error. Miss, not leak.
Fix: normalize with `cd "$wt_root" && pwd -P` when the dir exists, and fall back to a dirname-resolved path. It is also fixed by the I3 fix if worktree paths come from git.

## Minor

### M1. Slug collisions: two paths sharing one slug share one folder (scope, low likelihood)
scripts/recall-sessions:43-44. `/x/a b`, `/x/a.b`, `/x/a_b` and `/x/a-b` all map to `-x-a-b`. Folder `$projects/$main_slug` then holds the other project's transcripts, and nothing in the script can tell them apart. Prompts are safe (exact project path). Likelihood is low (needs two checkouts whose paths differ only in punctuation). Fix, if wanted: read the first `"cwd":"..."` of each transcript and require it equal `$MAIN` or a worktree path (a `grep -m1` per file).
Not verified against Claude Code: how it slugs non-ASCII (the `tr` here replaces per byte, so `é` becomes `--`, where a JS `replace` would give `-`) and paths over ~200 chars (Claude Code may truncate and hash). Both would be silent misses. Cheap check: `ls ~/.claude/projects` for such a path.

### M2. Prompt with no `sessionId` shifts columns (format)
scripts/recall-sessions:124 and 121. An empty `sessionId` gives `ts<TAB><TAB>text`. `read` with `IFS=$TAB` treats tabs as whitespace and collapses them, so the output was `prompt<TAB>iso<TAB>floci nosession<TAB>`: the text sits in the session column and the text column is empty. Task 28 parses this. Older history entries may have no `sessionId`.
Fix: emit `-` for an empty id in awk (and document it), or split with parameter expansion instead of `read`.

### M3. Silent exits with no `recall-sessions:` prefix
scripts/recall-sessions:44 (`tr`) and 74 (`basename`). A failing `tr` or `basename` exits 1 with empty stderr (reproduced with PATH shims). It is nonzero and prints nothing on stdout, but it breaks the "must print `recall-sessions:`" rule. `git` exit 127 reads as "not a git repository", exit 2, from `kern_main_root`, which is existing M1 code and out of scope here.
Fix: `main_slug=$(slug "$MAIN") || die "..."`; the same for `basename`.

### M4. `wc` or `sort` that exits 0 with no output passes silently
scripts/recall-sessions:67-69, 79. With a `wc` shim that prints nothing and exits 0, the `case` check passes because `$epoch` is non-empty. The line goes out with an empty bytes field. A `sort` that prints nothing and exits 0 drops every session. Contrived, but it is the "broken command must not give a clean answer" class.
Fix: `case "$bytes" in '' | *[!0-9]*)`, and compare the sorted line count with the record count.

### M5. Quadratic `field()` on long displays
scripts/recall-sessions:96-110. Each escape does `rest = substr(rest, j + 2)`, which copies the tail. A display with 100k `\n` took 2.0 s. At 1M escapes it would take minutes. Pasted text is normally in `pastedContents`, so likelihood is low. Fix: stop after 120 output bytes for `display` (a length cap argument), or walk with an index instead of re-slicing.

### M6. `"project": "..."` (space after the colon) and a trailing-slash project are skipped
scripts/recall-sessions:97-99, 111. The key match needs `"project":"` exactly. Claude Code writes compact JSON, so low likelihood. It skips (miss, never a leak). Reproduced for the spaced key. State in the header, or accept `"project"[ ]*:[ ]*"` with a manual scan.

### M7. Prompts come out in file order, with no cap
Prompts are oldest first (history file order) while sessions are newest first, and there is no limit. A common topic prints every match in the window. Task 28 reads the prompts as given. Nothing says the order matters, but the header says "newest first" only for sessions, so it is correct as written. `%.0f` of `ts / 1000` rounds half-even, not floor, so a prompt can show one second late. Harmless at minute resolution.

### M8. Tests do not pin several guards (mutation results below)
tests/scripts/recall-sessions.bats. The CR test cannot fail: `field()` stops at the closing quote, so a trailing `\r` never reaches a value and the `sub(/\r$/, "")` at line 112 is dead. Either drop the strip, or put the CR where it matters. There is no test that removes `die` on `wc`, `sort`, `awk` or `date`, no `--days 08` test, no empty-`sessionId` test, and no test of a shared worktree dir or a `\u` escape (the header documents it as left as typed; I checked by hand and it is).

## Scope attack results

| Attack | Result |
| --- | --- |
| `<slug>-old` sibling folder | Not listed (exact folder for main; glob only on the `--claude-worktrees-` stem). |
| `<slug>x` | Not listed. |
| Prompt project `<repo>-old`, `<repo>/sub`, `<repo>/` | Excluded (exact MAIN match; `/` suffix is a miss). |
| Two paths with the same slug (space, dot, underscore) | Transcripts leak, prompts do not. M1, low likelihood. |
| Symlinked repo path | MAIN comes from `git worktree list`, which printed the realpath: running from a symlink found the sessions. Whether Claude Code records the realpath for a symlinked launch directory is unverified. If it records the symlink, the result is a silent miss, not a leak. |
| `project` with a trailing slash | Excluded, a miss. |
| Worktree dir that is a prefix of another path (`worktrees-foo`) | Transcripts leak (reproduced); prompts do not, because `WT` ends in `/`. |
| Worktree dir shared by projects (`/tmp/shared-wts`) | Transcripts and prompts leak (reproduced). I3. |
| `"project":"<MAIN>"` text inside a display or `pastedContents` | Not matched: quotes inside values are always `\"`. |

## D6 results (PATH shims, scratch HOME)

| Case | rc | stdout | stderr |
| --- | --- | --- | --- |
| unreadable transcript folder (bats 12) | 1 | empty | `recall-sessions: cannot read` |
| unreadable history | 1 | empty | `recall-sessions:` |
| `date` exit 1 / exit 127 | 1 | empty | `recall-sessions: cannot read the mtime of ...` |
| `date` fails only for `+%s` | 1 | empty | `recall-sessions: date failed` |
| `date -r` prints nothing, exit 0 | 1 | empty | `empty mtime` |
| `wc` exit 1 / prints `abc` | 1 | empty | `recall-sessions:` |
| `find` exit 1 / 127 | 1 | empty | `recall-sessions: cannot read <dir>` |
| `sort` exit 1 | 1 | empty | `sort failed` |
| `awk` exit 3 / 127 | 1 | empty | `cannot read <hist>` (wrong noun, right exit) |
| `tr` / `basename` exit 1 | 1 | empty | none (M3) |
| `wc` or `sort` exit 0, no output | 0 | partial | none (M4) |
| missing `~/.claude` | 0 | empty | none (correct) |
| unreadable `~/.claude/projects` or `~/.claude` | 0 | empty | none (I2) |
| `--days 09 --topic x` | 0 | sessions only | bash arithmetic error (I1) |

## Portability

- awk: no dynamic regex (`index()` for keys and topic), so the mawk `"\\\""` problem does not arise. `match(rest, /["\\]/)` is a literal bracket expression, fine on all three. `substr` is never called with 0 or negative values (`j - 1 >= 0`; `substr(x, 1, 0)` is empty). `RSTART + 12` matches the 12-character `"timestamp":`. `tolower` runs under `LC_ALL=C`. `ENVIRON` is used instead of `-v`, so backslashes are not re-interpreted. `%.0f` instead of `%d` is right for mawk. I ran BSD awk 20200816 only; gawk and mawk are not installed. By reading, nothing breaks on ubuntu gawk.
- GNU date: `date -d @0 +%s` succeeds on GNU, so `iso_at` uses `-d "@S"`. On BSD `-d` is rejected, so it falls to `-r S`. The branch is chosen once (line 50). `date -r FILE` is `--reference=FILE` in GNU coreutils, which prints the file's mtime, so both calls at 63-64 are fine on ubuntu. Not run on GNU.
- `sort -t TAB -k1,1nr -k3,3`, `find -maxdepth 1 -type f -mtime -N`, `wc -c < f`, `tr -c 'A-Za-z0-9' '-'`: all fine on GNU. Tests: `touch -t`, `date -v-2d || date -d '2 days ago'` fine. The `chmod 000` tests skip as root; GitHub runners are not root.
- bash 3.2: ran under /bin/bash 3.2.57 via run-bats. `${bytes//[[:space:]]/}` is fine. The I1 arithmetic bug is the same on 3.2 and 5.3.
- No locale ranges: `A-Za-z0-9` is passed to `tr` under `LC_ALL=C`; `[[:space:]]` is a class.

## JSON field extraction (adversarial lines)

All of these ran without a crash or hang (the 3 MB line took about 0.1 s): `\"` before and after the topic, `\\"` at the end of display, `\\\"`, keys reordered, display text carrying `"project":"<MAIN>"`, `"sessionId":"EVIL"` and `"timestamp":999...` (all escaped, so never matched), `"display"` inside `pastedContents`, a lone `"`, an unterminated display, a line with no project (skipped), and a line with no timestamp (skipped). Wrong-field matches and other-project prompts: none. Misses: spaced key (M6). Format defect: empty `sessionId` (M2).

## Output format

`session<TAB>YYYY-MM-DDTHH:MM<TAB>id<TAB>bytes<TAB>path`, newest first with id as the tie-break; then `prompt<TAB>iso<TAB>sid<TAB>text<=120 bytes`. This is what the Produces line says and what Task 28's text expects (it reads `session` and `prompt` lines and never touches history.jsonl). One edge: the 120-byte cut can split a UTF-8 character (documented in the header).

## Mutation runs (scratch copy of the repo, original script restored after each)

| Mutation | Result |
| --- | --- |
| main slug exact folder becomes `*` prefix glob | killed (tests 1, 2, 3) |
| worktree prefix `WT` becomes `MAIN` prefix | killed (test 5) |
| drop the worktree prefix branch | killed (test 6) |
| exact `p != MAIN` becomes a prefix check | killed (test 5) |
| mtime window `-$days` becomes `-3650` | killed (test 1) |
| CR strip removed | SURVIVED (M8) |
| `die` after `find` removed | killed (test 12) |
| `die` after `wc` removed | SURVIVED (M8) |
| `die` after `sort` removed | SURVIVED (M8) |
| `die` after `awk` removed | SURVIVED (M8) |
| `-k1,1nr` becomes `-k1,1n` | killed |
| `-maxdepth 1` becomes 3 | killed |
| `die "cannot read $hist"` after the `-r` test removed | SURVIVED (equivalent: awk's own failure dies) |

## Commands run

- `tests/run-bats tests/scripts/recall-sessions.bats`: 16 of 16 ok.
- `shellcheck scripts/recall-sessions`: no output, rc 0.
- Scratch-HOME runs for the scope, D6 and JSON cases above (the script, PATH shims, fixture history lines, a 3 MB line, 100k escapes).
- `git status` in /Users/musta/Code/projects/kern: unchanged by me.
