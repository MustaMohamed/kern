# Task 33 review: shell-snapshot aliases (770a9f8..bb74e68)

Reviewed commits dcbae15, 58a84b9 and bb74e68 on `main` against the brief, the report and the four rulings in progress.md. The repo was not edited and git state was not changed. All scratch work is under `scratchpad/t33r/`.

**Spec verdict: issues.** Ruling 1 chose union so that "no pre-task deny or ask can drop". That property does not hold. The alias record survives, but the expansion records are printed between it and the records that follow it, and they change the context those later records are judged in. Two statements in the shipped text are false as a result: CHANGELOG.md:7 says a forged snapshot "can only add asks and denies, never remove one", and docs/plans/contract.md:98 says "no vote the command got without aliases is lost". Everything else in the brief and the rulings is met: the files, the interfaces, the prefilters (G2, G3, G4, G13, G14 and G15), the trailing-space rule with a bound of 8, the M3 limits listed in the CHANGELOG, and the cost budget.

**Quality verdict: needs-fixes.** Critical 1 blocks. The hostile-value proof, the hex namespace, the zsh-parity claims, the gates and the mutations all hold up.

## Critical

### C1. An alias's expansion changes the context of the records after it, so union loosens votes, including on the real snapshot

**Where.** hooks/lib/gitctx.sh:160-170. git_words prints the alias record, then the expansion records right after it, then the command's later records. Several guards carry state from one record to the next, and an expansion record that runs `cd` changes that state for every original record after it:

- G1: `moved` at hooks/guards/g01-git.sh:60-61. The `dir` empty branch at :630 asks where the CWD judgement denied.
- G6: `moved` at hooks/guards/g06-secrets.sh:64. :100-101 then asks "could not scan" instead of running the scan that denies.
- G16: `in_sd` and `_G16_INCC` at hooks/guards/g16-state.sh:448-451. Any later `cd` clears them.

**Failure scenarios.** The base votes come from the 770a9f8 hook; the head votes come from bb74e68 with the same input. In every scenario, the original record and the records after it are identical between the two runs.

The user's real snapshot defines `grt='cd "$(git rev-parse --show-toplevel || echo .)"'`:

- `cd ~/.claude && grt && sed -i '' s/a/b/ settings.json`: interactive ask becomes none; autopilot deny becomes none. zsh really writes ~/.claude/settings.json here. ~/.claude is not a repo, so `git rev-parse` fails and `grt` runs `cd .`. I checked this with zsh in a scratch directory.
- `grt && git commit -m "feat: add creds"` with an AWS key staged in the worktree: interactive deny (G6, "possible secret") becomes ask (G6, "could not scan"). `grt` stays in the same repo, so the secret would be committed.
- `grt && git push --force-with-lease origin feat`, where feat holds another author's commit: interactive deny (G1, "may hold commits by other authors") becomes ask (G1, "unknown directory").

A forged snapshot, which the CHANGELOG says can never remove a vote, defines `ls='cd / && git log'` and `true='cd -; git status'`:

- `cd <sessions dir> && ls && echo x > foo`: deny becomes none, in both modes. The real `ls` does not move, so the write lands in kern's session state.
- `cd ~/.claude && ls && echo x > settings.json` and `cd ~/.claude && true && cp /tmp/x settings.local.json`: interactive ask becomes none; autopilot deny becomes none.
- `ls && git push --force-with-lease origin feat` and `true; git push --force-with-lease origin feat`: interactive deny becomes ask.

**Size.** The corpus is 103 commands, run in 2 modes, from 2 directories (main checkout and worktree), against 2 snapshots (real and hostile): 824 comparisons. 30 are looser (7 on the real snapshot), 122 are tighter and 0 are errors. Logs: `t33r/corpus-{real,hostile}-{main,wt}.log`.

**Not new.** Part of the root cause predates this task. G6 and G1 already turn a deny into an ask after any `cd`: `(cd .); git commit` with a staged key asks at base. G16 already clears `_G16_INCC` on a dynamic `cd "$(...)"`, so the literal form of the `grt` command gets no vote at base, even under autopilot (see Minor 6). This task lets an alias inject those `cd` records in front of commands that base judged correctly. That injection is the loosening.

**Fix.** Keep every original record, its order and its context exactly as base, and judge the expansion records after all of them. I prototyped this as `t33r/fixA`, a two-change diff in git_words:

```bash
  # With aliases loaded, the outermost call moves every expansion record (marked \036) after all of
  # the command's own records, so an expansion never changes the context its later records are read in.
  if [ -z "${_GW_IN-}" ] && [ -n "${KERN_ALIASES-}" ]; then
    _GW_IN=1 git_words "$1" | LC_ALL=C awk '/^\036/ { a[++n] = substr($0, 2); next } { print } END { for (i = 1; i <= n; i++) print a[i] }'
    return
  fi
  ...
      git_words "$ALIAS_EXP" | LC_ALL=C sed $'s/^/\036/'
```

Results on fixA:

- Same 824 comparisons: 0 looser, and the same 122 tighter.
- aliases.bats: 21/21.
- Full hook suite: 1..594, 594 ok, 0 not ok, EXIT=0 (`t33r/fixA-hooks.log`).

Trade-off: an expansion no longer sets state for the original records after it. For example, `gaa && git commit -m x` loses G6's "may be stale" reason, though the decision stays ask (interactive) and deny (autopilot), and base has the same blind spot.

Alternative: print the base records, then the whole command again with the expansions in place of their alias records. This keeps that ordering, but costs one more git_words pass per guard, and only for commands that hold an alias.

Gate the reorder on `KERN_ALIASES`, not on `KERN_ALIAS_TEXT`. G16 runs git_words on a lowercased command (g16-state.sh:360), which can find an alias the original-case text does not hold, and the marker must be stripped there too.

**Tests to add.** A property test in aliases.bats, using the existing `noalias_hook`: for each command in a corpus, the hook's decision rank (deny > ask > none > allow) with a hostile snapshot must be at least the rank `noalias_hook` gives, in both modes. The corpus should include the cases above: a staged secret, a lease branch with another author's commit, ~/.claude/settings.json, and the sessions dir. Then correct CHANGELOG.md:7 and contract.md:98.

## Important

### I1. The trailing-space bound fails open: nine `_` defeat it under autopilot on the real snapshot

**Where.** hooks/lib/aliases.sh:220, `while [ "$n" -lt 8 ]`.

**Failure.** With the real snapshot, `_ _ _ _ _ _ _ _ _ gpf! origin main` gets no vote in either mode; eight `_` get ask (interactive) and deny (autopilot). zsh has no such bound. I checked with a stand-in alias `_='nice '`: zsh expanded `gpf!` after 9 `_` and after 12 `n`. The ruling deferred chains deeper than 8 to M3, and the CHANGELOG lists that limit. I raise it again because it is an 18-character, deterministic autopilot bypass on the snapshot this user actually has, not a rare configuration.

**Fix.** Fail closed past the bound. When the next word after the 8th expansion is still an alias in the table, print a record G00 reads as unreadable (deny under autopilot), or ask. Alternatively, bound the loop by the number of words; each step consumes one word. bats test 21's `expect none "$w9"` pins the fail-open behaviour and would change.

### I2. A quoted assignment before an alias hides it: `X='' gpf! origin main` gets no vote under autopilot

**Where.** hooks/lib/aliases.sh:191. A word holding a quote or `$` ends the head-word search with `return 1`.

**Failure.** With the real snapshot, `X='' gpf! origin main` gets none in both modes. zsh expands the alias after `X='a b'`, `X=$(true)` and `X="q"` (all three checked). This limit is also ruled for M3 and listed. It is a 6-character autopilot bypass.

**Fix.** For a record whose prefix holds such an assignment, find the head word with the `_GW_AWK` splitter (`sw` plus the assignment test `cw` already applies). Or, once C1 is fixed, over-expand: an expansion appended after the original records can only add votes.

### I3. Out of scope, but predates this task and is serious: zsh precommand modifiers hide eval and here-doc shells under autopilot

At both 770a9f8 and bb74e68, under autopilot, in the worktree, these get no vote:

- `noglob eval 'git push --force origin main'`
- `nocorrect eval '...'`
- `repeat 1 eval '...'`
- `coproc eval '...'`
- `noglob sh <<EOF` with `git push --force origin main` in the body

`noglob zsh -c` is already denied by G00. See item 5 below for the fix. I recommend a separate task now, not M3.

## Minor

1. **Cost.** Medians of 30 to 40 runs, macOS bash 3.2, real snapshot (205 table entries):
   - `git status`: +18 to +28 ms, with the snapshot against without it.
   - `gst`: +40 to +49 ms against literal `git status` without a snapshot.
   - `git status && gp origin feat`: +50 to +54 ms against the literal command without a snapshot, and +8 to +17 ms against the literal command with one.

   The report's +13 ms is the second comparison. Measured from a hook with no aliases, an alias command sits at the 50 ms budget.
   - `aliases_load` alone: about 17 ms.
   - 10,000 aliases: `aliases_load` 567 ms; the hook on `git status` 723 ms against 125 ms (+598 ms). This matches the CHANGELOG's 0.6 s.

   Fix A adds about one awk process per guard's git_words call while aliases are loaded. Re-measure after it lands.
2. **Trailing tab.** hooks/lib/aliases.sh, the `ts = v ~ /[ \t]$/` check and its comments, treat a value ending in a tab as a trailing-space alias. zsh's rule is a space only: with `t=$'nice\t'`, zsh did not expand the next word. This is unreachable from Claude Code's snapshots, because zsh prints such a value as `$'...'`, which is skipped. Over-expansion is harmless after C1. Fix: say "ends in a space", and match `/ $/`.
3. **G16 lowercases first.** G16 runs git_words on the lowercased command (g16-state.sh:360), so its alias lookup can find an alias zsh would not run: `gbD` is looked up as `gbd`. This only adds records, so it is harmless after C1. Note it in the contract.
4. **Expansion where the alias is not defined.** Expansion also applies inside `bash -c`, `sh -c` and ssh remote command text, where the aliases are not defined. In the corpus, `bash -c 'gpf! origin main'` went from none to deny. This is the safe direction after C1. Note it.
5. **G6 asks after any cd (predates).** `(cd .); git commit -m x` with a staged key asks instead of denying. G6 could still scan CWD after a `cd` and keep its deny, then add the "could not scan" ask. This is the guard-level half of C1.
6. **G16 and dynamic cd (predates).** `cd ~/.claude && cd "$(git rev-parse --show-toplevel || echo .)" && sed -i '' s/a/b/ settings.json` gets no vote at base, even under autopilot: a dynamic `cd` clears `_G16_INCC` and `in_sd`. It should keep them, since the target is unknown. File it separately.

## The seven checks

1. **Never loosens: fails.** See C1. Other inputs I tried raised no other problem:
   - aliases shadowing `git`, `gh`, `cd`, `env`, `sudo`, `cat`, `echo`, `printf`, `export`, `tee`, `psql`, `npm`, `sed` and `cp`;
   - aliases named `if`, `time`, `nocorrect` and `repeat`;
   - an empty value, a redirection-only value (`r='>/dev/null '`), a 3 KB value and a line over 4096 bytes;
   - values ending in `&&`, `|` or `;`, and `;` or `&&` inside quotes;
   - `_KA_` variables in the environment;
   - mixes with `$( )`, eval, `bash -c`, pipes, `&&`, `||`, newlines and here-docs.

   Fix A clears all 30 looser cases.
2. **Never executes: passes.** I wrote 26 new hostile alias lines and 4 top-level lines that use:
   - zsh expansions: `${(e)$(...)}`, `${(e):-...}`, `$((...))`, `<(...)`, `>(...)`, `=(...)`, `${$(...)}`;
   - `~root/$(...)`, globs `/*/*$(...)*`, `!!`, backticks;
   - `eval` and `source` inside a value, a `core.fsmonitor=` value, `-C` into a repo whose config sets fsmonitor and hooksPath, and `GIT_DIR=$(...)`;
   - escaped `\$\(`, text after the closing quote, and NUL bytes inside and after a value;
   - alias names `*`, `[` and `?`.

   Top-level lines also used the zsh forms. I ran 140 hook runs over them (bash 3.2 and 5.3, both modes, 35 commands): the marker directory stayed empty, and the table loaded 22 of the entries, so the run was not vacuous. In aliases.sh no path sources, evals or substitutes snapshot text:
   - awk reads the snapshot on stdin;
   - `printf -v "_KA_$h" '%s' "$v"` uses `h` only after the hex check;
   - `${!h-}` and `${!v}` name only `_KA_<hex>`;
   - `printf -v "$2"` is only ever called with `v`;
   - the `printf -v c '%02x' "'$c"` input is one character from `_ALIAS_CHARS`;
   - `for h in ${!_KA_@}` expands names only;
   - git_words output is inserted into a here-doc and is not expanded again.
3. **Variable namespace: passes.**
   - Names map one to one: `a-b`, `a_b`, `a.b`, `a+b`, `a:b`, `a@b`, `-`, `_`, `.`, `+`, `:`, `@`, `%` and `2d` gave 14 distinct variables (for example `_KA_612d62` and `_KA_615f62`), and each lookup returned its own value under bash 3.2 and 5.3.
   - The awk HX set (33 to 126 less `"` `/` `\` `$` backtick `=` `'`) equals `_ALIAS_CHARS`.
   - No other hook variable starts with `_KA_`.
   - A preset `_KA_7a` and `KERN_ALIASES=x` are cleared.
   - A name with a quote or `é` is skipped on both sides.
4. **Trailing-space rule: matches zsh except the bound (I1) and the tab (Minor 2).** zsh 5.9 checks, using `eval` as the Bash tool does:
   - `_ X=1 gpf!` and `_ 'gpf!'` do not expand, the same as kern.
   - A chain of three trailing-space aliases (`nice `, `nohup `, `env `) expands, the same as kern.
   - `X=1 _ gpf!` expands, the same as kern.
   - `_ 2>/dev/null gpf!`, `_ >/dev/null gpf!` and `_ nocorrect gpf!` do not expand, the same as kern.
   - `nocorrect`, `repeat 1` and `time` expand; `noglob`, `command`, `builtin`, `exec` and `-` do not. This matches the contract.
   - A trailing tab does not expand; kern would.
   - 9 and 12 levels expand in zsh; kern stops after 8. Bats test 21 covers 8 and 9.
5. **nocorrect gap: recommend out of this task, as a separate task now.** It is not one line. It needs three changes:
   - add `nocorrect|noglob|coproc` to the keyword regex in `cw` (hooks/lib/gitctx.sh:130);
   - add `if (x == "repeat") { cw_wrap = ""; cw_dur = 1; return }` for the count;
   - add the four words to git_words' wrapper prefilter (hooks/lib/gitctx.sh:190), or `noglob eval` is still not unwrapped.

   I ran the prototype `t33r/fix5` on 30 modifier commands × 2 modes × 2 directories against head:
   - 28 tighter, including `_ gpf! origin main` on the real snapshot (now deny, as for literal `sudo git push --force`) and every I3 bypass (now deny);
   - 4 changed the other way: G16 `noglob cat <state file>` went from deny to none, which is what plain `cat` gets;
   - 0 G18 changes; the investigator still denies `noglob git log`;
   - no new allow, because G1 and G5 need a record that starts with `git `.

   It changes `_GW_AWK`, which all 13 guards read, and changes a G16 vote. It deserves its own corpus and bats cases outside Task 33. I did not run the full suite on fix5; whoever implements it should.
6. **Cost: inside the budget, marginal.** See Minor 1. The 10,000-alias case adds about 0.6 s per Bash call.
7. **Gates: all pass at bb74e68** (listed below). Every removal mutation is caught.

## Commands run and results

- `tests/run-bats tests/hooks/aliases.bats` (macOS, /bin/bash 3.2, BSD awk 20200816): 1..21, 21 ok.
- `tests/run-bats tests/hooks`, in the background, log at `scratchpad/hooks-t33r.log`: 1..594, 594 ok, 0 not ok, EXIT=0.
- `shellcheck -x -S warning hooks/lib/*.sh hooks/guards/*.sh hooks/pre-tool-use` (0.11.0): no output, rc 0.
- `node --test 'tests/**/*.test.mjs'`: 215 tests, 215 pass, 0 fail.
- kern-ci:task17 (Ubuntu, bash 5.2.21, mawk 1.3.4 20240123, `-u 1000:1000 -e HOME=/tmp`, `git archive bb74e68` copied into /tmp/k): `tests/run-bats tests/hooks/aliases.bats` gave 21/21 ok.
- Removal mutations, aliases.bats on each mutated copy (`t33r/mut-*.log`). Every one fails:

  | Mutation | Failing tests |
  | --- | --- |
  | union to replace | 12, 13, 20 |
  | lossy hex (non-alnum to `5f`) | 14 |
  | no `_KA_` reset | 19 |
  | next-word loop removed | 21 |
  | bound 8 to 9 | 21 |
  | `KERN_ALIAS_TEXT` line removed | 20 |
  | G2 prefilter reverted | 20 |
  | G3 prefilter reverted | 20 |
  | G4 prefilter reverted | 20 |
  | G13 prefilter reverted | 20 |
  | G14 prefilter reverted | 20 |
  | G15 prefilter reverted | 20 |

- Differential corpus (`t33r/harness.sh`, `t33r/runcorpus.sh`, `t33r/corpus.txt`): 103 commands × 2 modes × 2 directories × 2 snapshots, base 770a9f8 against head bb74e68. 30 looser, 122 tighter, 0 errors. Against fix A (`t33r/runcorpusA.sh`): 0 looser, 122 tighter.
- `t33r/fixA`: aliases.bats 21/21; full suite 1..594, 594 ok, 0 not ok, EXIT=0 (`t33r/fixA-hooks.log`).
- Hostile-value exec proof (`t33r/exec-snap.sh`, 140 runs): marker directory empty.
- zsh 5.9 probes (`t33r/zt.zsh`, `zsh -f`, aliases defined by hand, the snapshot never sourced): results as in check 4. The `grt` write in a non-repo `.claude`: the file was written.
- Cost (`t33r/bench.py`, medians of 30 to 40 runs): as in Minor 1.
- Real snapshot: copied from `~/.claude/shell-snapshots/snapshot-zsh-1792072549515-0umb42.sh` (248 alias lines), read as text only.
