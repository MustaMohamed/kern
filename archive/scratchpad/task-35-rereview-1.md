# Task 35 re-review 1: fix round 1 (54ffc16..f0b4a3e)

Scoped to commits 97967e5 to f0b4a3e. I made no repo edits and sourced no snapshot. Scratch work is in `scratchpad/t33r/`:

| Tree | Commit |
| --- | --- |
| `b35` | 3c66863 |
| `h35` | 54ffc16 |
| `h35b` | f0b4a3e |

## Summary

These parts are fixed, and none of them makes any vote weaker:

- **C1:** `cmd_mod` reads only the modifiers before the command name.
- **G1 is monotone:** after a move, the vote never drops below the CWD judgement.
- **I2:** the sticky seen flags and the `popd` arm.
- **m1:** the cdir text tracking.

One part makes votes weaker, and is new this round: "a cd behind noglob, nocorrect or repeat N moves". It is applied by G16 and G20 to compositions in which zsh does not run the cd in the shell at all:

- `noglob time cd`
- `noglob ! cd`
- an external wrapper on either side of a modifier: `nice noglob cd`, `sudo noglob cd`, `noglob env cd`, `noglob command cd`

Each of these goes from deny to none, against both 54ffc16 and 3c66863. That breaks the premise of the accepted class: these commands do get the vote of their unmodified form, but zsh does not move for them. **Verdict: NEEDS-FIXES.** The stop rule applies (section 6).

## 1. Status

| Item | Status | Where |
| --- | --- | --- |
| C1, a modifier word anywhere in the cd record | **ADDRESSED** | hooks/lib/gitctx.sh:150-162 (`cw_mod` set only before the command name), :484-492 (`cmd_mod` runs `cw`) |
| I1, a modifier cd moves | **PARTIAL** | G1 monotone: hooks/guards/g01-git.sh:170-208 and :643. The plain modifier forms are fixed. The compositions in N1 are not: G16 (g16-state.sh:470-471) and G20 (g20-approval.sh:405-406) follow them as moves. |
| I2, go-back forms | **ADDRESSED** | hooks/guards/g16-state.sh:487-498 (`sd_seen`, `cc_seen`, the popd arm) |
| m1, relative cd and INCC | **ADDRESSED (accepted deviation)** | hooks/guards/g16-state.sh:474-485 (cdir via `_g16_tidy`). Remaining gap: m-c. |
| m2, other known-target limits | **ADDRESSED** (documented) | The CHANGELOG lists failing cds, `pushd -n`, CDPATH and a symlink to the sessions dir |

Evidence for each status:

- **C1:** all nine G1 forms (`2> noglob`, `> repeat`, `X=' noglob'`, `<<< nocorrect`, `# noglob`, `cd repeat`, `pushd … <<< coproc`), plus the G20 approval copy and G5 `git add` forms, give 3c66863's vote again in both modes.
- **I1:** the modifier corpus has 4 below-unmodified rows, down from 28. All 4 are `coproc cd` and `repeat 0 cd`, which zsh does not move.
- **I2:** all of these now deny under autopilot:
  - `cd -`, `cd ~-`, `cd +1` and `pushd /tmp && popd` back into the sessions dir;
  - `cd -`, `cd ~-` and `popd` back into ~/.claude.

## 2. Critical

### N1. "A modifier cd moves" also covers compositions zsh does not move for; G16 and G20 lose their votes

**Where.** In `cw` (hooks/lib/gitctx.sh:150-162):
- after `noglob`, `time` is still taken as the wrapper and `!` as a keyword;
- an external wrapper (command, env, exec, nice, nohup, sudo, timeout) before or after a modifier leaves `cw_mod = 1`, so `cmd_mod` returns 1 ("moves").

G16 (g16-state.sh:470-471) and G20 (g20-approval.sh:405-406) then follow the cd as a move.

**zsh 5.9** (`zsh -f`, `eval`, `pwd` afterwards). Each of these **stays** in the starting directory:
- `noglob time cd ../x`: time is external after noglob;
- `noglob ! cd ../x`: `!` is not found after noglob;
- `noglob command cd ../x` and `command noglob cd ../x`;
- `nice noglob cd ../x`, `env noglob cd ../x` and `noglob env cd ../x`;
- `sudo -n noglob cd ../x` and `timeout 5 noglob cd ../x`.

**Failure scenarios.** Autopilot, worktree CWD. All are looser against both 3c66863 and 54ffc16; each write lands in the protected directory:

- `cd <sessions> && noglob time cd /tmp; echo x > foo`: deny → none
- `cd <sessions> && noglob ! cd /tmp; echo x > foo`: deny → none
- `cd <sessions> && nice noglob cd /tmp; echo x > foo`: deny → none. The same holds for `noglob nice`, `sudo noglob`, `env noglob`, `noglob env`, `timeout 5 noglob`, `noglob command` and `command noglob`.
- `cd ~/.claude && noglob time cd /tmp; sed -i '' s/a/b/ settings.json`: deny → none. The same holds for `noglob ! cd`.
- G20: `noglob time cd /tmp; cp src.md dst.md`, where `src.md` in CWD holds `status: approved`: deny → none. The same holds for `noglob ! cd`.

These match the kern vote of the unmodified command, so they fall inside the letter of the accepted class, but not its premise.
- `time cd` does move in zsh. `noglob time cd` does not, because noglob makes `time` an external command.
- For the wrapper forms, the unmodified vote is itself wrong, a fault that predates this task (see Important P1).

The genuinely accepted rows behave as zsh does: `nocorrect cd`, `repeat 1 time cd`, `nocorrect noglob cd`.

**Fix, either of two:**

- **Narrow.** In `cw`, when `cw_rw` is set, any reserved word (`time`, `!`, …) sets `cw_mod = 3`. An external wrapper before the command name sets `cw_mod` to at least 2 ("maybe"), so G16 and G20 keep, and G1, G5 and G6 count a move, as at base. Add the forms above as tests.
- **Conservative, which I recommend after two rounds.** G16 and G20 treat every cd behind a modifier or a wrapper as "maybe" (keep). Only G1, G5 and G6 count it as a move. That removes N1 and P1 for G16 and G20. It also turns the 28 accepted rows back into denies, which is stricter for `nocorrect cd /tmp; echo x > foo`, where zsh does move.

## 3. Important

### P1. A cd through an external wrapper never moves in zsh, but G16 and G20 follow it (predates)

**Where.** `cw` skips command, env, nice, nohup, sudo and timeout (hooks/lib/gitctx.sh:162) and returns `cd` as the command. zsh runs `/usr/bin/cd` in a child: `command cd ../x`, `nice cd ../x`, `env cd ../x`, `nohup cd ../x` and `timeout 5 cd ../x` all stay.

**Scenario.** These get none under autopilot at 3c66863, 54ffc16 and f0b4a3e alike:
- `cd <sessions> && nice cd /tmp; echo x > foo`, and the same with `env`, `nohup`, `timeout 5` or `command`;
- `cd ~/.claude && command cd /tmp; sed -i '' s/a/b/ settings.json`;
- `command cd /tmp; cp src.md dst.md` (G20).

**Fix.** The same `cw_mod = 2` for an external wrapper in front of the command, as in N1.

## 4. Minor

- **m-a. `nocorrect nocorrect cd` moves in zsh, but `cw_rw` makes it "stays".** G1, G5 and G6 then do not count the move. That is equal to both bases; G16 is stricter. Fix: a `nocorrect` after `nocorrect` should not set 3.
- **m-b. `builtin noglob cd` moves in zsh.** G1's builtin arm (g01-git.sh:62) reads `w[1]=noglob` and sees no cd. Equal to the bases.
- **m-c. A known relative target is resolved against CWD, not cdir** (g16-state.sh:484, `_g16_into "$last"`). So `cd <dir> && cd link-to-claude && sed -i '' s/a/b/ settings.json` gets none, equal to base. Fix: when dk is 1, resolve `_g16_physical "$cdir"`.
- **m-d. With a symlinked CWD, `cd -P ..` goes to the physical parent**, which the text tracking cannot see. Equal to base. List it with m2.

## 5. The lead's checks

1. **The tri-state against zsh 5.9.**
   - These match zsh:
     - `'noglob'`, `\noglob` and `no''glob` move: noglob is a builtin, so quoting does not stop it, and kern ignores `cw_q` for noglob.
     - `'nocorrect'`, `no''correct`, `'coproc'` and `'repeat' 1` stay.
     - `noglob noglob`, `nocorrect noglob`, `repeat 1 noglob` and `repeat 1 nocorrect` move.
     - `noglob nocorrect`, `noglob repeat 1`, `noglob coproc` and `repeat 1 coproc` stay.
     - `repeat $N` is maybe in kern; zsh moves for N=1 and stays for N=0.
     - `repeat 01` moves; `repeat -0` stays.
     - `repeat 1+1` and `repeat ' 1'` are maybe in kern; zsh moves.
     - `time noglob`, `! noglob`, `X=1 noglob` and `noglob -` move.
   - These do not match: `nocorrect nocorrect` (m-a), `builtin noglob` (m-b), and the N1 compositions.
2. **The modifier corpus on f0b4a3e against 3c66863** (1,064 rows: 19 commands × 14 forms × 2 modes × main and investigator):
   - 42 looser, all equal to the unmodified vote (`<mod> cat <state>`, `<mod> zsh -c 'echo hi'`);
   - 0 looser and unequal;
   - 136 tighter;
   - 4 below the unmodified vote (coproc and repeat 0, correct).

   The corpus has no N1 compositions in front of a write, which is why it does not show them.
3. **G1 monotone.** No vote went looser. Interactive, worktree, feat holding another author's commit:

   | Command | 3c66863 / 54ffc16 | f0b4a3e |
   | --- | --- | --- |
   | `cd <other repo> && git push --force-with-lease origin feat` | ask | deny |
   | the same after `cd /tmp;` | ask | deny |
   | `env -C <other> git push --force-with-lease …` | ask | deny |
   | `cd <other> && git -C <wt> push …` | ask | deny |
   | `--git-dir` and `--work-tree` | ask | ask (alt cleared, as intended) |
   | `git push -u origin feat` under push.policy auto | allow | allow |
   | `cd . && git push -u origin feat` | ask | ask (alt judges with plain 0, never an allow) |
   | autopilot, every form | deny | deny |

   `_G01_ALT` is set right before every `_g01_git` call and read only when the directory is unknown, so it is never stale.
4. **G16 cdir and the sticky flags.** No case went looser. Under autopilot, from none to deny:
   - `cd .claude/agents && cd ..`
   - `cd ~/.claude && cd agents && cd ..`
   - `cd ~/ && cd .claude/agents && cd ../`
   - `cd ~/.claude && cd ~-`
   - `cd <sd> && cd .. && cd sessions`
   - `cd <sd>/.. && cd sessions`
   - `cd <sd> && cd ..`
   - every go-back form

   Same as base (deny): `//`, `/.`, `../../.claude`, `cd -P agents/..`, an upper-case path (G16 lower-cases), and an absolute symlink to `.claude`.

   Still none, as at base: a failing cd followed by `;` (m2), a relative cd into a symlink (m-c), and a symlinked CWD with `cd -P ..` (m-d). A known cd's flags are right everywhere I tried, apart from m-c.
5. **Corpora** (`cmp2`, both trees on the same snapshot; real, hostile and attack):

   | Pair | Comparisons | Looser | Tighter |
   | --- | --- | --- | --- |
   | 54ffc16 → f0b4a3e | 1,400 | 0 | 4 (G1 lease after `cd`) |
   | 3c66863 → f0b4a3e | 1,400 | 0 | 16 |

   Logs: `t33r/c35b-*.log` and `t33r/a35b-*.log`.

## 6. Stop rule

**Triggered.** This round made round 0's behaviour looser, and that is not in the accepted class. Round 0 (54ffc16) kept G16's flags and G20's directory for every cd behind a modifier word. Round 1 makes G16 and G20 follow such a cd whenever `cw_mod` is 1, and `cw` models zsh's grammar incompletely (N1).

I recommend a split:
- Land C1 (97967e5), the G1 monotone part of bc07e9d, the sticky flags and popd (a37e368), cdir (28b8f47), the CHANGELOG (6f2873f) and f0b4a3e. Each of those is verified to make no vote looser.
- Hold "a modifier cd moves in G16 and G20" until `cw` models reserved words after noglob and external wrappers, each with its own zsh-checked corpus. Or take the conservative variant of the N1 fix now.

## 7. Gates

- Full suite at f0b4a3e in the background (`t33r/hooks-t35rr.log`, which I read): 1..618, 618 ok, 0 not ok, EXIT=0.
- kern-ci:task17 (mawk 1.3.4 20240123, uid 1000, `git archive f0b4a3e`): gitctx, g01-git, g05-g06-commit, g16-state and g20-probes bats give 1..285, 285 ok.
- `shellcheck -x -S warning hooks/lib/*.sh hooks/guards/*.sh hooks/pre-tool-use`: no output, rc 0.
- Removal mutations (`t33r/mut35b-*.log`). All 6 are caught:

  | Mutation | Failing tests |
  | --- | --- |
  | `_G01_ALT` judgement removed | g01 30 |
  | `sd_seen` dropped | g16 34 |
  | popd arm removed | g16 34 |
  | cdir `*/.claude` arm removed | g16 33 |
  | `cw_q` ignored | g16 35 |
  | repeat ≤ 0 literal rule removed | 35, 101, 160, 217 |

- Probes: `t33r/rr1probe*.sh` with `rr1c1.txt`, `rr1c1b.txt`, `rr1g16.txt`, `rr1probe2.txt` and `rr1probe3.txt`; `t33r/rr1g1.sh`; `t33r/rr1g16b.sh`; zsh 5.9 directory probes in `t33r/zcd2`.

## Verdict

**NEEDS-FIXES.** N1 is Critical: G16 and G20 lose a deny on writes into the sessions dir, ~/.claude/settings.json and approved Markdown, through `noglob time cd`, `noglob ! cd` and wrapper compositions. zsh does not move for any of them. Everything else in the round holds.
