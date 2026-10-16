# Task 35 review (3c66863..54ffc16)

Commits 885ad12 (G6 keeps scanning after a cd), edc409f (G16's dk rule) and 54ffc16 (the guards read through noglob, nocorrect, coproc and `repeat N`). I made no repo edits and sourced no snapshot. Scratch work is in `scratchpad/t33r/`: `b35` is 3c66863, `h35` is 54ffc16, and `fixT35` is my prototype fix.

**Spec verdict: issues.** The four bullets of the task text are met. But the commit adds `cmd_mod`, which is not in the task text, and it loosens G1, G5 and G20 for ordinary commands that hold no modifier at all (C1). That breaks the dispatch condition of 0 looser votes and no gained votes for ordinary commands. The implementer's corpus has no command of that shape, so it could not see it.

**Quality verdict: needs-fixes.** The fix for C1 is small and prototyped. The modifier read-through, G6 and G16 work otherwise hold up.

## Critical

### C1. `cmd_mod` matches a modifier word anywhere in the cd record, so a real cd stops counting as a move

**Where.** `cmd_mod` is at hooks/lib/gitctx.sh:460-468. It is used by:

- G1: hooks/guards/g01-git.sh:61-62
- G5: hooks/guards/g05-commit.sh:48
- G6: hooks/guards/g06-secrets.sh:67
- G20: hooks/guards/g20-approval.sh:404

`cmd_mod` strips quotes, then returns true when `noglob`, `nocorrect`, `coproc` or `repeat` is any whitespace-delimited word of the record, not only a word before the command name. It works per record, so `echo noglob; cd /tmp && …` is not affected. But any word inside the cd record itself counts:

- a redirection target: `2> noglob`, `> repeat`
- a here-string: `<<< nocorrect`
- a trailing comment: `# noglob`
- an assignment value with a space: `X=' noglob'`
- a directory literally named `repeat`

**Failure scenarios.** Base is 3c66863, head is 54ffc16, both with no snapshot. CWD is a linked worktree; the target is the main checkout or another directory.

| Command | Interactive | Autopilot |
| --- | --- | --- |
| `cd <main> 2> noglob && git clean -fdx` (G1, D3) | ask → **none** | deny → **none** |
| `cd <main> > repeat && git clean -fdx` | ask → none | deny → none |
| `X=' noglob' cd <main> && git clean -fdx` | ask → none | deny → none |
| `cd <main> <<< nocorrect && git reset --hard` | ask → none | deny → none |
| `cd <main> # noglob` then a newline and `git clean -fdx` | — | deny → none |
| `cd repeat && git clean -fdx`, where `./repeat` links to the main checkout | ask → none | deny → none |
| `cd <dir> 2> noglob && cp src.md dst.md`, `src.md` holding `status: approved` (G20) | deny → **none** | deny → **none** |
| `cd <dir> 2> noglob && git add notes.txt` (G5; same with `<<< repeat`) | ask → none | deny → none |
| `pushd <dir> >/dev/null 2>&1 <<< coproc; git add notes.txt` | — | deny → none |

zsh moves the shell in every one of these forms. I checked `2> noglob`, `# noglob`, `X=' noglob'` and `<<< nocorrect` with `zsh -f`, and `pwd` reports the target. None of these commands holds a modifier, so no "unmodified" vote exists that they could equal. This is a plain loosening against base.

G16 uses `cmd_mod` only to set `dk=0`, keeping its flags, so a false positive there is stricter and harmless. G6 still asks on the genuine moves it sees; under `cmd_mod` it loses that ask, and the decision only holds because G5 also asks or denies.

**Fix.** `cmd_mod` must be true only when `cw` skipped a modifier before the command word.

- Set `cw_mod = 1` where `cw` skips noglob, nocorrect, coproc or repeat; reset it in `cw_reset`.
- Make `cmd_mod` run `_GW_AWK` on the record and exit `!cw_mod`. Keep a cheap `case` prefilter, so the awk only runs for a cd record that holds one of the four words.

Prototype `t33r/fixT35` is 7 lines in gitctx.sh. With it:

- all nine forms above give the base vote again;
- `noglob cd`, `coproc cd` and `repeat 0 cd` keep the behaviour the new tests expect;
- the six changed bats files pass, 292/292.

Add these forms to `tests/hooks/g01-git.bats`, `g05-g06-commit.bats` and `g20-probes.bats` as must-not-change cases.

## Important

### I1. A genuine `noglob`, `nocorrect` or `repeat N` cd moves in zsh, but G1, G5, G6 and G20 treat it as staying (predates)

**Where.** The same `cmd_mod` call sites. The tests pin this: g01-git.bats "a cd behind noglob … leaves the directory known", g05-g06-commit.bats, and g20-probes.bats P21b. The g16-state.bats comment says "bash runs none of these words as a cd", but the Bash tool runs zsh.

`noglob cd X`, `nocorrect cd X` and `repeat 1 cd X` all move in zsh; I checked each. Only `coproc cd` and `repeat 0 cd` stay.

**Scenario.** `noglob cd <main> && git clean -fdx` from a worktree gets none in both modes, at base and at head, while `cd <main> && git clean -fdx` gets ask and deny. My corpus has 28 such rows: 14 modifier forms × 2 modes, all below the unmodified vote, none below base.

`cmd_mod` exists because G1's moved branch is not monotone. A moved lease push gets "unknown directory" (ask) where the CWD judgement gives deny for another author's commits. So counting a modifier cd as a move would loosen G1; treating it as staying keeps the base hole open.

**Fix.** Make G1 follow G6's new shape: when moved, still judge in CWD and keep its denies, then add the unknown-directory ask. After that, treat a modifier cd as a move in G1, G5 and G6, which is stricter and right for zsh. Keep `dk=0` in G16. Have G20 follow the cd as it would without the modifier. Otherwise, record it as a known limit with the zsh facts.

### I2. G16's dk rule keeps the flags an unknown target has now, not those it can return to (predates)

**Where.** hooks/guards/g16-state.sh:453-473.

An unknown target such as `cd -`, `cd ~-`, `cd +1` or `popd` can return to a directory seen earlier, whose flags a known cd has already cleared. Autopilot, base and head both give none:

- `cd <sessions> && cd /tmp && cd - && echo x > foo` (also `; cd -;`, `pushd /tmp && popd`, `cd ~-`, `cd +1`)
- `cd ~/.claude && cd /tmp && cd - && sed -i '' s/a/b/ settings.json`

zsh writes into the sessions dir or edits ~/.claude/settings.json.

**Fix.** Keep sticky flags, `in_sd_seen` and `incc_seen`, set whenever either flag is set. On an unknown target, set `in_sd |= in_sd_seen` and `INCC |= incc_seen`, and treat `popd` as a cd to an unknown target.

## Minor

- **m1. A relative cd is known for in_sd but clears INCC** (hooks/guards/g16-state.sh:469). `_g16_into` resolves a relative target against CWD, not the tracked directory. So `cd ~/.claude && cd agents && cd .. && sed -i '' s/a/b/ settings.json` gets none (base: none). in_sd already gains only on a relative target; do the same for INCC: `if _g16_into "$last"; then _G16_INCC=1; fi`.
- **m2. Other known-target cases that predate the change.** Each is equal to base:
  - a failing cd to a known target followed by `;`: `cd ~/.claude && cd /nonexistent; sed … settings.json`;
  - bash's `pushd -n`;
  - CDPATH;
  - a symlink to the sessions dir: G16 matches state by path text, so `cd <link-to-sessions> && echo x > foo` gets none.

  List them as limits.
- **m3. G6 scans CWD after a move** (hooks/guards/g06-secrets.sh:103-107), not the repo actually committed. Its "could not scan" ask stays on every genuine move, so it is never looser than base. A secret staged in CWD gives a deny even when the commit is elsewhere; that is stricter, and fine. The C1 false positives remove the ask; C1's fix restores it.

## Answers to the lead's checks

1. **The ruling on the 72 holds.** Each of the implementer's 72 looser rows equals the head vote of the same command without the modifier:
   - `noglob cat <state>` 24, `noglob ls ~/.claude` 12, `noglob cat settings.json` 12, `NOGLOB cat <state>` 12;
   - `noglob zsh -c 'echo hi'` 6, `noglob bash -c 'git status'` 6.

   My own modifier corpus (`t33r/t35atk-*.log`): 19 commands × 14 modifier forms × 2 modes × 2 agents = 1,064 rows. Result: 42 looser rows, all equal to the unmodified vote (`<mod> cat <state>`, `<mod> zsh -c 'echo hi'`); **0 looser and unequal**; 112 tighter; 28 below the unmodified vote but not below base (I1). C1 lies outside the ruling, because those commands hold no modifier.
2. **Part-1 attacks.**
   - Every repeat form reads through to the command: `repeat $N`, `repeat -1+2`, `repeat 1 repeat 1`, `repeat '1'`, `repeat 0`, which runs nothing in zsh, so it is stricter.
   - Chains read through: `sudo noglob`, `noglob sudo`, `env X=1 noglob`, `command noglob`, `noglob command`, `repeat 1 noglob nocorrect coproc`.
   - Under autopilot all of these deny: `echo $(noglob git push --force …)`, `eval 'noglob git push --force …'`, a here-doc `sh` running `noglob git push --force`, `x=$(repeat 2 git push --force …)`, and `noglob $(echo git) push`.
   - `echo noglob git push --force` is unchanged (ask, and deny under autopilot, through the hidden-git check).
   - **G18:** across 532 investigator rows, no vote got looser, and `noglob git log`, `repeat 1 git status` and the like still deny.
   - **cmd_mod's quote stripping:** it works per record, so `echo noglob; cd /tmp && git commit` is unaffected. But a quoted or unquoted modifier word anywhere in the cd record turns tracking off: C1.
3. **G6.** It never goes looser on a move it sees, because the ask stays and the scan only adds. It does scan CWD, which can be the wrong repo, so a secret in the moved-to repo is caught by the ask, not by the scan. Under the C1 false positives it loses the ask.
4. **G16 dk rule.**
   - Gains on unknown targets, autopilot, base none → head deny: `cd "$(pwd)"`, `cd -` with no earlier cd, `cd` alone, `cd ~user`, `cd a b`, `cd ..` from the sessions dir.
   - Same as base (deny): `cd -P .`, `cd -L .`, `popd`, and a symlink to `.claude`.
   - Gaps equal to base, which the rule's goal should cover: return to an earlier directory (I2) and relative cds for INCC (m1). Failing cds, `pushd -n`, CDPATH and a symlink to the sessions dir also stay as at base (m2).
   - No case went looser.
5. **Round-1 and attack corpora on 54ffc16 against 3c66863**, the same snapshot on both sides, real, hostile and attack: 1,400 comparisons, **0 looser**, 12 tighter. The tighter class is `nocorrect`, `repeat 2` or `coproc` before `git push --force` or `gpf!`, and `_ gpf! origin main` through the snapshot's `sudo='nocorrect sudo'`. Logs: `t33r/c35-*.log`, `t33r/a35-*.log`.

## Commands run

- `tests/run-bats tests/hooks` at 54ffc16 in the background, log `t33r/hooks-t35r.log`, which I read: 1..612, 612 ok, 0 not ok, EXIT=0.
- kern-ci:task17 (mawk 1.3.4 20240123, uid 1000, `git archive 54ffc16`), the six changed bats files (gitctx, g00-unproven, g01-git, g05-g06-commit, g16-state, g20-probes): 1..292, 292 ok.
- `shellcheck -x -S warning hooks/lib/*.sh hooks/guards/*.sh hooks/pre-tool-use`: no output, rc 0.
- Removal mutations (`t33r/mut35-*.log`), each run on its relevant changed bats files. All 6 are caught:

  | Mutation | Failing tests |
  | --- | --- |
  | keyword regex without the modifiers | 10, 55 |
  | `repeat` line removed | 10, 55 |
  | git_words prefilter without the modifiers | 10, 55 |
  | G6 `continue` restored | 48 |
  | G16 dk always 1 | 32, 33 |
  | `cmd_mod` always false | 73, 154, 214, 255 |

  The last one shows the tests pin `cmd_mod`'s intended behaviour, but none pins the C1 forms.
- Corpora: `t33r/runcorpus35.sh` and `t33r/runatk35.sh` (base and head on the same snapshot, through `cmp2` in `t33r/harness.sh`). Modifier corpus `t33r/t35atk.sh`. Targeted C1, G6, G16 and G20 probes: inline `cmp2` runs, quoted above.
- zsh 5.9 (`zsh -f`, scratch dir `t33r/zcd`): move checks on `2> noglob`, `# noglob`, `X=' noglob'`, `<<< nocorrect`, `noglob cd`, `nocorrect cd`, `repeat 1 cd` (all move), and `coproc cd`, `repeat 0 cd` (stay).
- Prototype `t33r/fixT35` (command-position `cmd_mod` through `cw_mod`): the C1 forms equal base, and the six changed bats files pass, 292/292. I did not run the full suite on it.
