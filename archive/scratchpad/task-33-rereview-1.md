# Task 33 re-review 1: redesign f928642 (9994ce0..f928642)

Scoped to that diff, against my first review (task-33-review.md). I made no repo edits and no git state changes, and sourced no snapshot. Scratch work is in `scratchpad/t33r/`. Tree copies: `head2` is f928642, `head` is bb74e68, `base` is 770a9f8.

## Summary

The invariant holds. The command's own records come first and unchanged, and the expansions go after all of them. No input I tried made a vote weaker than the no-alias base:

- the 824-comparison corpus: 0 looser;
- 576 new hostile comparisons with tabs, raw `\036`, newline-tab, tab-led expansion text, nested `$( )`, backticks, eval, `bash -c` and G16's lowercased pass: 0 looser.

C1 is fixed.

Two Important findings are left. Both are gaps in this round's new code, and both fail open the way base does, never looser:

- **I1 is open on the user's real snapshot.** The `$KERN_ALIAS_PAST_8` marker never becomes the command name when the trailing-space alias expands through `nocorrect`, which is exactly the user's `_` → `sudo` → `nocorrect sudo`.
- **I2's head-word parser loses its quote state inside `$( )`.** `X=$(printf "%s" a) gpf! origin main` still gets no vote under autopilot.

Each has a small fix, prototyped below.

## Status of round-1 findings

| Finding | Status | Where | Evidence |
| --- | --- | --- | --- |
| C1, expansion changes later context | **ADDRESSED** | hooks/lib/gitctx.sh:10, :167-170, :180 | Corpus 824/0 looser; attack corpus 576/0 looser; tests 23 and 24; mutations below |
| I1, trailing-space bound fails open | **PARTIAL** | hooks/lib/aliases.sh:283-287 | Real snapshot: `_ _ _ _ _ _ _ _ _ gpf! origin main` gets none in both modes (see N1) |
| I2, quoted assignment hides the alias | **PARTIAL** | hooks/lib/aliases.sh:109-139, :235-246 | `X=''`, `X='a b'` and `X=$(true)` now deny; `X=$(printf "%s" a) gpf!` and `X=$(echo "(") gpf!` still get none (see N2) |
| I3, modifiers hide eval (predates) | OPEN, out of scope | hooks/lib/gitctx.sh:130 and :190 | Unchanged; planned as Task 35 per 9994ce0 |
| Minor 1, cost | See section 5 | — | — |
| Minor 2, trailing tab | **ADDRESSED** | hooks/lib/aliases.sh:86 and :93 (`/ $/`) | Test 21 now covers `t='nice<TAB>'` against the no-alias hook |
| Minor 3, G16 lowercased lookup | **ADDRESSED** | contract.md (Accepted limits), harmless under the invariant | Attack cases `GRT`, `GrT` and `LS` ahead of a settings write: same votes as base |
| Minor 4, expansion inside `bash -c` and ssh | **ADDRESSED** | contract.md (Accepted limits) | Attack case `bash -c grt` ahead of a settings write: same as base |

## 1. The invariant under attack

**Reorder.** The outermost call (hooks/lib/gitctx.sh:167-170) runs the inner git_words with `_GW_IN=1`. It prints lines that do not start with a tab, then the stripped tab-marked lines. The inner call marks expansion output with `sed $'s/^/\t/'` (:180).

**Why a tab instead of `\036`: the reasoning is correct.** Every line that reaches the outermost awk is one of two things:

- a record printed by `printf '%s\n' "$seg"`;
- a line of the `sed`-marked expansion output.

Every `seg` comes from `_split_words`' `emit()`, which trims `[ \t\n]` at both ends and turns inner newlines into `\037`. That holds for the top level, for `$( )` bodies (`_subst_bodies` joins lines with spaces before re-splitting) and for eval and `sh -c` scripts (re-split by `_split_words`). No record can start with a tab.

`emit()` does not trim `\036`, so with a `\036` mark a record starting with that byte would have been moved. My attack cases `\036cd ~/.claude && grt && sed ... settings.json`, `\036grt && git commit ...` and `cd <sessions> && \036ls && echo x > foo` give the same vote as base.

`unset _GW_IN _GW_NOALIAS` at source time (:10) closes the environment route.

**Attack corpus** (`t33r/atk/`, `t33r/runatk.sh`). 48 commands × 2 modes × 2 directories × 3 snapshots = 576 comparisons against base:

- `real`: the user's snapshot.
- `hostile`: round 1's shadowing table.
- `attack` (`t33r/attack-snap.sh`): it adds:
  - `tb='git status;<TAB>cd /'`
  - `tl='<TAB>git status; cd /'`
  - `tc='git status<TAB>&& cd /'`
  - `cdx='cd /; git status'`
  - `sub='git status $(cd /)'`
  - `ls='cd / && git log'`
  - `true='cd -; git status'`

The command forms:

- a leading tab;
- tabs as separators;
- newline-then-tab;
- raw `\036` before or inside a record, and at the start of the command;
- `$(grt)`, `$(grt; ls)`, `$(echo $(grt))` and `` `grt` ``;
- `eval grt` and `eval 'grt; ls'`;
- `bash -c grt`;
- `GRT`, `GrT` and `LS` (G16's lowercased pass);
- `cat <<-EOF` with tab-led body lines, plain and piped into `sh`.

Each was put ahead of:

- a `~/.claude/settings.json` write;
- a write in the sessions dir;
- a commit with a staged AWS key;
- a lease push of a branch holding another author's commit.

**Result: 572 same, 4 tighter, 0 looser, 0 errors** (`t33r/atk-*.log`). The 4 tighter rows are nine `_` under autopilot on the hostile and attack tables, where `sudo` is not aliased to `nocorrect`.

**Round-1 corpus** on f928642 (`t33r/corpus2-*.log`): 0 looser, 126 tighter, 0 errors. A verdict-by-verdict diff against bb74e68 shows exactly two kinds of change: the 30 former looser rows, now equal to base, and 4 new tighter rows (`X='a b' gpf!`). No vote that round 1 produced got weaker.

## 2. N1 (Important): `$KERN_ALIAS_PAST_8` is not the command name when the expansion runs through a word G00 does not skip

**Where.** hooks/lib/aliases.sh:283-287 appends the marker to the same record as the expansion. G00 judges only the command name, and `_GW_AWK`'s `cw` skips only its known keywords and wrappers. `nocorrect` is not one of them (hooks/lib/gitctx.sh:130).

**Failure, user's real snapshot** (`_='sudo '`, `sudo='nocorrect sudo'`):

```
_ _ _ _ _ _ _ _ _ gpf! origin main
→ nocorrect sudo nocorrect sudo … nocorrect sudo $KERN_ALIAS_PAST_8  gpf! origin main
```

The command name is `nocorrect`, so G00 sees nothing, and G1's hidden-git scan finds no git word. The result is none in both modes; 16 `_` give the same. zsh runs `git push --force`. The same happens for any trailing-space alias whose expansion starts with a word `cw` does not skip: `w='watch '` × 9 gets none under autopilot.

Test 21 passes only because it uses `n='nice '`, which `cw` skips. The CHANGELOG ("past 8 such words, a word that is still an alias is denied under autopilot") and the contract ("becomes the command name") overstate it.

**Fix.** One change at aliases.sh:285: give the marker a record of its own.

```bash
      pre="$pre"'; $KERN_ALIAS_PAST_8 '
```

A record that starts with a run-time name is denied by G00 whatever came before it. Expansions only add votes, so the split is harmless. Prototype `t33r/fixI1` gives deny under autopilot for:

- the real snapshot's 9 and 12 `_`;
- `n` × 9;
- `w` × 9;
- `timeout 5 ` × 9, `env -u X ` × 9 and `sudo -u root ` × 9 (all three already deny at head2).

Interactive stays none, as before. Add the real-snapshot shape to test 21: `_='sudo '` with `sudo='nocorrect sudo'`, as the property test's omz table already holds.

**Can the marker be resolved or slip past G00 otherwise?**

- It is literal text and is never evaluated.
- A snapshot cannot define it, since alias names with `$` are skipped.
- A command that writes `$KERN_ALIAS_PAST_8` itself only adds a G00 deny.
- Wrappers that take a value (`timeout 5`, `env -u X`, `sudo -u root`) do not swallow it.

The slip in N1 is the only one I found.

**Interactive none.** That matches what G00 gives any run-time name interactively, and base gives none for these commands, so it is not a loosening. The ruling asked for fail-closed. An interactive ask would honour that more literally, and cheaply, by having G1's `_g01_hidden` path or G00 vote ask on the marker. That is the controller's call; I would accept none given G00's contract.

## 3. N2 (Important): `_ALIAS_HEAD_AWK` loses the quote state inside `$( )`

**Where.** hooks/lib/aliases.sh:123-126:

- the parenthesis count runs before the double-quote state;
- a `"` opened inside `$( )` can never close while `d > 0`: `if (c == "\"" && !d)`.

**Failure** (real snapshot, both modes, zsh expands each):

| Command | Result |
| --- | --- |
| `X=$(printf "%s" a) gpf! origin main` | none: the quote opened inside never closes, and the word swallows the rest |
| `X=$(echo "(") gpf! origin main` | none |
| `X=$(echo ")" ) gpf! origin main` | the head word is read as `)`; the hook still denies, through another path |

**Fix.** Keep the quote state per depth. Prototype `t33r/head-awk-fix.awk`:

```awk
      if (c == "$" && (C[i + 1] == "(" || C[i + 1] == "{")) { QS[++d] = q; q = ""; i++; continue }
      if (q == "\"") { if (c == "\"") q = ""; continue }
      if (d && (c == "(" || c == "{")) { QS[++d] = ""; continue }
      if (d && (c == ")" || c == "}")) { q = QS[d--]; continue }
```

It gives the right head word for all three cases above and for:

- `X="$(echo "a b")"`
- `X=$(a "$(b "c d")" e)`
- `X=${Y:-"}"}`
- `` X=$(a `b c` d) ``

On the existing 43 cases it differs only on `X=$(echo ")" )`, where it fixes the head word. Add these forms to test 22.

**Robustness.** The awk only prints and has no `system()`, `getline` or output redirection. Every outer pass consumes at least one character, so it always ends.

I ran 43 cases on BSD awk 20200816, mawk 1.3.4 20240123 (kern-ci) and gawk 5.3.2 (a throwaway alpine container):

- unbalanced `'`, `"`, `$(`, `${` and backtick;
- `$( )` holding `;`, `$(( ))`, nested `${ }`, `$'…'`;
- `\037` in a word, a trailing backslash;
- 5,000 unclosed `$(`;
- a 200 KB assignment;
- 20,000 assignments;
- a `$(touch …)` head word.

All three awks print identical output. Every case finishes under 1 s, and no marker file appeared (`t33r/hawk-*.log`). A wrong split can only add or miss an appended expansion.

## 4. Stop rule

This round authored no defect in round-1 code. It changed git_words, the alias_expand loop and the `ts` rule. Across the 824 comparisons, the only verdict changes against bb74e68 are the 30 fixes and 4 new tighter rows.

N1 and N2 are gaps in this round's own new code (the past-8 marker and `_ALIAS_HEAD_AWK`). Both fail the same way base does, never looser.

The C1 redesign is independent of both. If another round is needed, land C1 as it stands and fix N1 and N2 in a small follow-up, rather than letting a third round grow this diff.

## 5. Cost

**Load average.** The machine was not quiet: a clang build and an Android emulator were running.

- Run 1 started at 4.40 and rose to 9.62.
- I waited until the 1-minute average dropped under 4.
- Run 2 went from 3.87 to 3.98.

Method: `t33r/bench2.py`, 40 interleaved rounds (a random config order each round), macOS /bin/bash 3.2, real snapshot (205 table entries), worktree CWD. "Without aliases" means f928642 with no snapshot.

Run 2, the quieter one, with run 1 in brackets:

| Command | Without aliases | With aliases | Added |
| --- | --- | --- | --- |
| `git status` (no alias) | 140.1 ms | 167.1 ms | **+27.0** (+33.0) |
| `gst` against literal `git status` | 139.6 ms | 195.6 ms | **+56.0** (+65.6) |
| `gp origin feat` against literal `git push origin feat` | 336.3 ms | 358.9 ms | **+22.6** (+20.8) |

Against bb74e68 with the same snapshot, the redesign adds +0.2 ms (+8.8) on `git status` and +8.2 ms (+2.9) on `gp origin feat`.

**Verdict: over budget.** The alias command `gst` adds 56 ms against the hook with no aliases. `gp` shows less only because its push is not the first record, so `_g01_proven` returns before its git calls, which offsets the overhead. `gst` is the clean measure.

Breakdown (20 calls each, in one shell):

| Step | Time |
| --- | --- |
| `aliases_load` | 18.8 ms |
| `alias_text gst` | 11.0 ms |
| `git_words gst` with the table | 9.7 ms |
| `git_words "git status"` without it | 4.8 ms |

So each guard's git_words call costs +4.9 ms with aliases, about 13 calls per hook.

**Cache.** Under the plan's rule a cache is due, but it buys little: at most `aliases_load`'s ~19 ms, minus the cost of reading the cache. That takes `gst` to about +40 to +45 ms. The larger lever is memoizing git_words per command in the dispatcher, which every guard recomputes today. That helps every command and is a separate task.

**Is a cache safe?** It can be, under three conditions:

- It is parsed as data, with exactly `aliases_load`'s loop: `IFS=$'\t' read -r h v`, the hex check on `h`, then `printf -v "_KA_$h" '%s' "$v"`.
- It is never `source`d, never `declare -p`'d into the shell and never `eval`'d.
- Its size is capped like the snapshot's 4 MB.

Then a forged cache equals a forged snapshot. Under the invariant it can only add appended expansions, so only add votes and cost; a hook timeout fails closed through `onFailure: block`. A forged empty cache disables alias judging, which returns votes to the no-alias base. A forged newer snapshot can do the same today, which is a listed limit. G16 already denies tool writes to the state dir, so the cache is harder to forge than the snapshot folder. Keying on path, size and mtime is enough.

## 6. Gates

- `tests/run-bats tests/hooks/aliases.bats` at f928642 (macOS, /bin/bash 3.2, BSD awk): 1..24, 24 ok.
- `tests/run-bats tests/hooks` in the background, log `t33r/hooks-t33rr.log`, which I read: 1..597, 597 ok, 0 not ok, EXIT=0.
- `shellcheck -x -S warning hooks/lib/*.sh hooks/guards/*.sh hooks/pre-tool-use`: no output, rc 0.
- kern-ci:task17 (Ubuntu, bash 5.2.21, mawk 1.3.4 20240123, `-u 1000:1000 -e HOME=/tmp`, `git archive f928642`): aliases.bats 1..24, 24 ok. The Docker daemon was down from about 01:46 to 01:55; this ran after it came back.
- Removal mutations, aliases.bats on each mutated copy (`t33r/mut2-*.log`). Each one fails:

  | Mutation | Failing tests |
  | --- | --- |
  | reorder block removed | 23, 24 |
  | tab mark removed (expansions inline again) | 23, 24 |
  | past-8 block removed | 21 |
  | I2 branch reduced to `return 1` | 22 |

- Corpus on f928642: 824 comparisons, 0 looser, 126 tighter, 0 errors. Attack corpus: 576 comparisons, 0 looser, 4 tighter, 0 errors.
- `_ALIAS_HEAD_AWK`: 43 cases, identical output on BSD awk, mawk and gawk 5.3.2; all under 1 s; no marker file.
- Prototype `t33r/fixN12`, the N1 one-line change plus the N2 quote stack: aliases.bats 24/24. The real snapshot's nine `_`, `X=$(printf "%s" a) gpf!` and `X=$(echo "(") gpf!` all deny under autopilot. I did not run the full suite or the corpus on it.

## Verdict

**NEEDS-FIXES.**

C1 is fixed, and the invariant held against everything I tried. Keep the redesign as it is.

Before approval:

- **N1** (aliases.sh:285): put `$KERN_ALIAS_PAST_8` in its own record, and add the real-snapshot shape (`sudo='nocorrect sudo'`) to test 21. Otherwise I1's fail-closed ruling does not hold for the snapshot that motivated it. Then correct the CHANGELOG and contract wording.
- **N2** (aliases.sh:123-126): keep a quote stack per `$( )` depth, and add `X=$(printf "%s" a) gpf!` and `X=$(echo "(") gpf!` to test 22.

On cost, report the +56 ms to the controller. The cache the plan's rule calls for buys about 14 ms, and memoizing git_words is the real fix, so whether to cache now or take a memoization task is the controller's decision. Both N1 and N2 are small and fail the way base does, never looser, so they can land as a follow-up commit without reopening C1.
