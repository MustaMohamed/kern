# Task 33 re-review 2: fix round 2 (bf1ebbb..90a9fb9)

Scoped to commits 222b21e (N1), dc9865d (N2) and 90a9fb9 (the cache). I made no repo edits, and sourced no snapshot and no cache. Scratch work is in `scratchpad/t33r/`; `head3` is the 90a9fb9 tree.

## Summary

N1 and N2 are fixed. The cache holds under attack.

- Warm or cold, no comparison gave a vote weaker than the no-alias base: 0 looser over 2,800 comparisons.
- No cache attack loosened a vote. The worst outcomes are:
  - a stale or forged cache that hides an alias, which returns that vote to the no-alias base;
  - a hook that hangs until the 20 s timeout blocks it.
- Warm `gst` is +42.5 to +43.4 ms over its literal, inside the 50 ms budget. Cold is +61 ms, paid once per new snapshot.

I have four Minor findings and no Critical or Important ones. **Verdict: APPROVED.**

## 1. Status

| Item | Status | Where | Evidence |
| --- | --- | --- | --- |
| N1, past-8 marker | **ADDRESSED** | hooks/lib/aliases.sh:330, `pre="$pre"'; $KERN_ALIAS_PAST_8 '` | See section 4 |
| N2, quotes inside `$( )` | **ADDRESSED** | hooks/lib/aliases.sh:125-128 (quote stack `QS[d]`) | 59 cases identical on BSD awk, mawk and gawk; hook votes below |
| Cost | **ADDRESSED (warm)**; cold over budget once per snapshot | hooks/lib/aliases.sh:168-227 | Warm `gst` +42.5 and +43.4 ms; cold `gst` +60.7 and +60.9 ms (section 5) |

## 2. The cache under attack

Scripts: `t33r/cacheatk.sh`, `t33r/cacheatk2.sh`, `t33r/cacheatk3.sh`; logs `t33r/cacheatk*.log`. Each attack ran against the real snapshot in a fresh state dir.

1. **Forged cache, valid first line, hostile entries.** The entries:
   - `ls` → `cd / && git log`, `true` → `cd -; git status`;
   - `gpf!` → `git status`, `git` → `git status`, `_` → `sudo `;
   - values holding `$(touch …)` and backticks;
   - invalid names `ZZ`, `6G`, `../x`, `61 62`, `_KA_61`.

   The table loaded exactly the 7 hex-named entries and skipped the 5 bad names. No marker file appeared. I then ran 8 commands in both modes:
   - the settings write after `cd ~/.claude && ls`;
   - the sessions-dir write after `ls`;
   - a lease push after `ls`;
   - a commit with a staged key after `true`;
   - `gpf!`, a literal force push, nine `_`, and `gst`.

   Every vote was the same as base or tighter. The forged `gpf!='git status'` and the missing `gst` hide those aliases, which leaves them at base (none), never below it.
2. **A first line naming another snapshot** is rebuilt: the header was rewritten to the snapshot actually read, and the table came back with 205 entries.
3. **CR in the key:** rebuilt. **NUL in the key:** rebuilt. **NUL inside a name:** bash drops or truncates at the byte, and the entry is skipped. That leaves an empty table: base votes, never below.
4. **4 MB cap** (hooks/lib/aliases.sh:186):
   - entries totalling exactly 4,194,304 bytes after the header: the last alias loads;
   - 4,194,305 bytes: the crossing alias is dropped.

   The cap counts whole lines, so it does not bound a single line. A valid header followed by one 64 MB line took 2.6 s in `aliases_load`. A line of a few hundred MB would reach the 20 s hook timeout, which fails closed (`onFailure: block`). See Minor m3.
5. **TOCTOU between the checks and the open** (:215). A FIFO swapped in after `[ -f ] && [ ! -L ]` would block the open until the hook timeout, failing closed. I ran 400 loads against a loop that renamed a FIFO and a valid copy over the cache in turn: 0 hangs, and all 400 loaded 205 entries. The window exists, but only as a DoS that fails closed.
6. **A symlink swapped in for the mktemp file** (:224-225). `mktemp` creates the file with O_EXCL, but `>"$tmp"` reopens it by name. A same-uid process that replaces the file with a symlink in between would make the hook write the table through that symlink. I ran 300 cold loads against a polling swap loop: the victim was untouched, and no stray tmp file was left. `_state_put` already uses the same pattern (hooks/lib/state.sh:55-57). See Minor m4.
7. **A state dir that is not ours.**
   - A read-only sessions dir holding a planted cache: the cache is read (one entry). There is no ownership check, so this is the same as a forged cache: base or tighter.
   - A read-only dir with no cache: the parse is used and nothing is written.
   - A symlinked state dir holding a valid cache with an extra alias: not read; the parse is used.
   - A symlinked cache pointing at a planted file: not read. The rebuild renames over the symlink, and the target is untouched.
8. **Two hooks writing at once.** 20 cold hooks in parallel: all 20 gave deny. The final cache is byte-identical to a single build, and no tmp file was left.
9. **stat on BSD and GNU** (:174). macOS: `stat -f '%z %m'`. GNU coreutils 9.4 and busybox read `-f` as file-system mode and `'%z %m'` as a file name, exit 1, and fall through to `stat -c '%s %Y'`. Precision is whole seconds on both.

   Edge: if a file named `%z %m` exists in the hook's CWD, GNU `stat -f` exits 0 with file-system text. The key check rejects that (a non-digit), so there is no cache and only the cost changes.
10. **A snapshot edited in the same second at the same size, or with mtime put back by `touch`.** The warm cache then keeps the old table: `gx='git status --short'` edited to `gx='git push --force x'` gives none under autopilot, while a cold parse gives deny. That is equal to base, not below it. See Minor m2.

**Does a stale cache ever hide an alias the current snapshot defines?** Yes, in case 10, and with a forged cache. In every case the result is the no-alias base vote, never weaker.

## 3. Corpora on 90a9fb9, cold and warm

Cold means the cache is deleted before every hook run; warm means it persists.

| Corpus | Cache | Looser | Tighter | Errors |
| --- | --- | --- | --- | --- |
| Round-1 corpus (824) | warm | 0 | 126 | 0 |
| Round-1 corpus (824) | cold | 0 | 126 | 0 |
| Attack corpus (576) | warm | 0 | 22 | 0 |
| Attack corpus (576) | cold | 0 | 22 | 0 |

- Warm and cold give identical decisions row by row.
- Against f928642, the 824 rows are unchanged.
- The attack rows change only where N1 and N2 apply: `_` × 9, `X=$(printf "%s" a) gpf!` and `X=$(echo "(") gpf!` go from none to ask (interactive) or deny (autopilot).

Logs: `t33r/c3{warm,cold}-*.log` and `t33r/a3{warm,cold}-*.log`.

## 4. N1 and N2 checks

**N1, real snapshot, worktree:**

| Command | Interactive | Autopilot |
| --- | --- | --- |
| `_` × 8, then `gpf! origin main` | ask | deny |
| `_` × 9 | none | **deny** |
| `_` × 16 | none | **deny** |
| `w='watch '` × 9 | none | **deny** |
| `n='nice '` × 9 | none | **deny** |

Interactive none matches base and G00's contract.

**N2.** The head word in each case, and the autopilot vote:

| Command | Head word | Autopilot vote |
| --- | --- | --- |
| `X=$(printf "%s" a) gpf!` | `gpf!` | deny |
| `X=$(echo "(") gpf!` | `gpf!` | deny |
| `X=$(echo ")" ) gpf!` | `gpf!` | deny |
| `X=${Y:-"$(echo "}")"} gpf!` (`${ }` with nested quotes) | `gpf!` | deny |
| `X=${Y:-'"'} gpf!` | `gpf!` | deny |

Interactively the first two get ask, matching their literal forms. The others also give the right head word: `X=${Y:-"${Z:-"a b"}"}`, `X=$(a "$(b "c d")" e)` and `` X=$(a `b c` d) ``.

**Unbalanced quotes inside `$( )`** find no head word, which leaves the base vote. zsh rejects these too (`unmatched "`):
- `X=$(echo "a) gpf!`
- `X=$(echo 'a) gpf!`
- `` X=$(echo `a) gpf! ``
- `X="$(echo ")" gpf!`
- `X=$(echo $(echo "x)) gpf!`

**Across the three awks:** 59 cases (round 1's 43 plus 16 new) print identical output on BSD awk 20200816, mawk 1.3.4 20240123 (kern-ci) and gawk 5.3.2 (a throwaway alpine container). The slowest case takes 0.19 s (20,000 assignments). No case ran anything or hung.

## 5. Cost

Method: `t33r/bench3.py`, 40 interleaved rounds, run twice. macOS /bin/bash 3.2, real snapshot, worktree CWD. Load average 2.97 → 2.79, then 2.89 → 2.53. Medians, run 1 then run 2:

| Command | Hook with no aliases | Warm cache | Cold cache |
| --- | --- | --- | --- |
| `git status` | 116.2 / 116.0 | 134.4 / 134.2 (**+18.2**) | 153.3 / 153.2 (+37.1) |
| `gst` against literal `git status` | 115.6 / 116.5 | 159.0 / 159.0 (**+43.4 / +42.5**) | 176.5 / 177.2 (+60.9 / +60.7) |
| `gp origin feat` against literal `git push origin feat` | 274.6 / 274.5 | 293.9 / 294.8 (+19.3 / +20.3) | — |

Interquartile ranges stayed within ±2 ms of each median.

Warm `gst` is under the 50 ms budget. Cold is over, but it is paid once per new snapshot path, and Claude Code writes one snapshot per process.

## 6. Stop rule

This round authored no defect in earlier rounds' code.

- N1 changes one line of round 2's marker. N2 replaces round 2's four depth lines.
- The cache sits in front of the parse and feeds the same `_alias_table` loop the parse uses. Before this round that loop was inline in `aliases_load`, and it is unchanged apart from the 4 MB cap.
- Round 1's 824-row corpus is unchanged against f928642. The attack corpus changes only toward tighter, as intended.

One gap is in this round's own code: m1, the untested read-side symlink check.

## Minor findings

- **m1. The read-side symlink refusal is untested** (hooks/lib/aliases.sh:215). Removing `[ ! -L "$cache" ] && [ ! -L "$dir" ]` from the read condition passes all 30 tests. Test 30's symlinked cache points at a file whose first line does not match, so it is rebuilt either way. The behaviour is correct: attack 7 showed neither a symlinked cache nor a symlinked dir holding a valid planted cache is read. Fix: in test 30, point the symlinked cache, and a cache inside the symlinked dir, at a file with a valid first line plus an extra alias (`zz` → `git push --force`), and assert `zz origin main` gets no vote.
- **m2. The key cannot see a same-size edit whose mtime is put back** (hooks/lib/aliases.sh:174). Such an edit, or one inside the same second, keeps the old table. Votes drop at most to the no-alias base, and anything that can write the snapshot folder can already do that by writing a newer snapshot. Fix: add ctime and inode to the key: `stat -f '%z %m %c %i'` / `stat -c '%s %Y %Z %i'`. ctime cannot be set with `touch`; my check showed it change while mtime and size were restored. Same-second edits remain.
- **m3. One long cache line is unbounded.** The 4 MB cap (:186) counts whole lines, so one 64 MB line costs 2.6 s, and a larger one reaches the hook timeout. That fails closed, so it is a DoS. Fix: refuse a cache over 4 MB plus the header before reading it. `_alias_key "$cache"` already gives the size.
- **m4. mktemp is followed by a reopen by name** (:224-225, the same pattern as state.sh:55-57). A same-uid process that swaps the tmp file for a symlink between `mktemp` and `>"$tmp"` makes the hook write through it. That is not an escalation: the model can already write any user file through a variable path, an accepted G16 limit. Fix both writers in one place: write under `set -C` (noclobber) to a random name not yet created, so the one open uses O_EXCL and fails on any symlink that already exists.

## 7. Gates

- `tests/run-bats tests/hooks/aliases.bats` at 90a9fb9 (macOS, /bin/bash 3.2, BSD awk): 1..30, 30 ok.
- `tests/run-bats tests/hooks` in the background, log `t33r/hooks-t33rr2.log`, which I read: 1..603, 603 ok, 0 not ok, EXIT=0.
- kern-ci:task17 (Ubuntu, bash 5.2.21, mawk 1.3.4 20240123, GNU stat 9.4, `-u 1000:1000 -e HOME=/tmp`, `git archive 90a9fb9`): aliases.bats 1..30, 30 ok. Tests 27 and 28 pass there, so the cache works with GNU stat.
- `shellcheck -x -S warning hooks/lib/*.sh hooks/guards/*.sh hooks/pre-tool-use`: no output, rc 0.
- Removal mutations, aliases.bats on each mutated copy (`t33r/mut3-*.log`):

  | Mutation | Result |
  | --- | --- |
  | key check removed (any first line accepted) | fails 20, 28 |
  | data-only read replaced by sourcing the cache (`. /dev/stdin`) | fails 15, 24, 27, 29 |
  | data-only read replaced by `eval` with no hex check | fails 27 of 30 tests |
  | rename replaced by writing the cache in place | fails 30 |
  | write-side symlink refusal removed | fails 30 |
  | **read-side symlink refusal removed** | **all 30 pass** (m1) |

## Verdict

**APPROVED.**

N1, N2 and the warm cost are fixed. The cache is read as data, and no attack made any vote weaker than the no-alias base. m1 to m4 are Minor and can go to the M2a-close triage. m1 is a one-test change worth doing first, since the contract states the property it would pin.
