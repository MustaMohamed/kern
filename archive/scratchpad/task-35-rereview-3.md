# Task 35 re-review 3: follow-up batch (76a08cb..2194d05)

Scoped to commits 1dc24f1 to 2194d05. I made no repo edits and sourced no snapshot. Scratch work is in `scratchpad/t33r/`:

| Tree | Commit |
| --- | --- |
| `b35` | 3c66863 |
| `h35c` | 76a08cb |
| `h35d` | 2194d05 |

## Summary

All six items are fixed.

- **P2, P3 and P4:** every form from re-review 2 now denies in both modes, where 3c66863 and 76a08cb gave none.
- **m2:** the P21h command takes 2.58 s on the full hook, against 2.01 s at 3c66863 and 23.15 s at 76a08cb.
- **m3:** the cap tests kill the cap mutations.
- **"Judge once" is exact.** Every directory-dependent path goes through `_g20_abs`, which sets `_G20_REL`. In practice it rarely fires, because the command word itself is a relative source word.

Corpora:

| Corpus | Against 3c66863 | Against 76a08cb |
| --- | --- | --- |
| Round-1 and attack (2,800) | 0 looser | 0 changed |
| Modifier (2,128) | 42 looser, only the read class | 0 changed |

Two things go to you:

1. **Two looser classes against 76a08cb beyond the four m1 read commands.** Both follow from m1's stated design, and both are exact and equal to 3c66863:
   - an absolute non-Markdown write past the cap;
   - any write after a plain absolute cd has reset the cap.

   By your rule they are Critical; I recommend extending the accepted class instead (section 5).
2. **The 1024 source limit still truncates silently.** It fails open past 1024 unique sources, as base did at 64 (Important I1).

P21h is flaky under heavy load, failing 2 of 5 runs at load 63 to 97.

**Verdict: APPROVED, conditional on your ruling on (1).** I1 and the P21h bound are follow-ups.

**A miss of mine in re-review 2.** The implementer found that 76a08cb gave none for `15 × nice cd; cp src.md dst.md`. Sixteen directories times the words pushed the CWD source past the old `head -n 64`. My re-review 2 tested the cap, but not the source truncation under a large set, and approved it. 2194d05 fixes it.

## 1. Status

| Item | Status | Where | Evidence (autopilot unless noted; base → head) |
| --- | --- | --- | --- |
| P2, quoted assignment or redirect | **ADDRESSED** | hooks/lib/gitctx.sh:514-515 (`!sw_q[k]`) | `cd <sd> && 'X=1' cd /tmp; echo x > foo`, also `X\=1` and `'2>/dev/null'`: none → deny in both modes. `'X=1' cd <dir>; cp src.md dst.md` (G20): none → deny. `X='a b' cd` is now maybe (deny), which is stricter; zsh moves there. |
| P3, G20 go-back and `builtin cd` | **ADDRESSED** | hooks/guards/g20-approval.sh:415 (builtin), :416-451 (go-back forms → `_G20_BACK`), :453 (popd), :669-680 (`_G20_SEEN` union) | none → deny in both modes for: `cd -`, `cd ~-`, `cd +1`, `cd -2`, `"$OLDPWD"`, `pushd X && popd`, `pushd X; pushd /tmp; popd; popd`, `cd X && cd Y && cd - && cd -`, `pushd` with no operand, `builtin cd`, `builtin pushd`. `cd && cp …` (HOME) stays none, which is correct. |
| P4, upper-case cd | **ADDRESSED** | hooks/guards/g16-state.sh:362-374 (`mixed`), :499 | `CD /tmp`, `Cd /tmp`, `PUSHD /tmp` in front of a sessions-dir write: none → deny in both modes. `cd ~/.claude && CD /tmp; sed … settings.json`: none → ask (interactive) or deny (autopilot). |
| m1, read past the cap | **ADDRESSED** | g20-approval.sh:255-263 (`_g20_target` past the cap), :682 (reset) | Five `if cd x` plus `ls notes.md`: deny → none. A relative write past the cap, and an absolute Markdown write past the cap, still deny. See section 5 for the two classes beyond the reads. |
| m2, cost | **ADDRESSED** | g20-approval.sh:597-690 (words read once, judge once) | Full hook, the P21h command (4 maybe cds, 110 Markdown writes), quiet: 3c66863 2.01 s, 76a08cb 23.15 s, 2194d05 **2.58 s** |
| m3, cap and cost tests | **ADDRESSED** | tests/hooks/g20-probes.bats P21g, P21h | Mutations r5, r6 and src fail P21g (section 8) |

## 2. "Judge once" (m2)

`_g20_seg` (g20-approval.sh:659) skips the other directories when the first judgement left `_G20_REL` at 0.

- `_G20_REL` is set by `_g20_abs` for every relative word (:239), and by the cd, pushd and popd arms.
- `_g20_abs` is the only directory-dependent resolver in G20. I checked every `_G20_DIR` use: `_g20_copy` builds `dest` and `dir` through `_g20_abs`, and git `-C` too.
- `_g20_target` checks the file on disk only at `_G20_P`, which is set by `_g20_abs`.
- Dynamic words, globs and brace expansions are skipped as sources at 3c66863 too, and never reach a directory-dependent check.

**Attack.** CWD holds an approved `t.md` and the set is {plain dir, CWD} after `noglob cd <plain dir>`, so only the second directory can deny. Each form denies:
- redirects: `>`, `>>`, `2>`, `&>`, `>|`;
- `tee t.md` and `tee -a ./t.md`;
- `cp`, `install` and `/bin/cp` onto `t.md`;
- `dd of=t.md`;
- `cat > t.md <<EOF`;
- `sed -i … t.md`;
- `/bin/echo x > t.md` and `/usr/bin/tee ./t.md`;
- `truncate -s 0 t.md`;
- `echo $(…) > t.md`.

All equal 3c66863 and 76a08cb (`t33r/rr3-once.txt`). `--opt=file` forms resolve through `_g20_target`, so they set `_G20_REL` too.

In practice "judge once" rarely fires. Every non-redirect word, the command name included, goes into `_G20_SRCW`, and the command name is relative (`cat`, `echo`), which sets `_G20_REL`. Only a record whose every word is absolute, an option, or dynamic is judged once, and such a record cannot depend on the directory. The m2 speed-up comes from reading the words once into arrays. A judge-once mutation (always return after the first directory) fails P21 to P21g, so the tests pin exactness.

## 3. The source list (1024)

Sources are deduplicated, then `head -n 1024` (:737). **Past 1024 unique sources it still truncates silently and fails open.**

| Sources before `src.md` (CWD's approved `src.md`) | 3c66863 | 76a08cb | 2194d05 |
| --- | --- | --- | --- |
| 60 | deny | deny | deny |
| 1,020 | none (64 limit) | none | **deny** |
| 1,030 | none | none | **none** |
| 1,100 | none | none | **none** |

At 1,020 sources the head takes 0.42 s, against 1.28 s at base. See I1.

## 4. P3's `_G20_SEEN` and P4's `mixed`

**`_G20_SEEN`** is CWD plus every directory of every record's set (:669-690). Inside one command it covers what `cd -`, `cd -N`, `cd +N`, `~-` and nested popd can return to: the pushd stack in a fresh `zsh -c` starts empty.
- `cd -` as the first cd: zsh 5.9 stays put whether `OLDPWD` is set in the environment or not (checked), so CWD in SEEN is right.
- One gap: a directory dropped past the cap is never in SEEN. A `cd -` after a reset could return to one. But the reset is a plain absolute cd, so SEEN already holds at least 16 directories plus the new one, and the union crosses the cap again, which denies writes. Probe `… 5 × noglob cd x; cd /tmp; cd -; echo x > t.md` denies.

**`mixed`** is command-wide: any word, quotes removed, that lower-cases to cd, pushd or popd and is not already lower case.
- On ordinary commands with no cd the vote is unchanged (both modes): `git commit -m "fix CD"`, `ls CDROM`, `echo CD-ROM > notes.txt`, `cat …/settings.json # CD player`, `git log --grep CD -- …/settings.json`, and `cd docs && echo "PUSHD note" >> notes.md` (no G16 path).
- It does change the vote when a cd and a state or settings path share the command with such a word: `cd <sd> && cd /tmp && echo "burn a CD" > foo` and `cd ~/.claude && cd agents && echo CD && sed … settings.json` go from none to deny or ask. These are false positives in the strict direction only (Minor m1).

## 5. Corpora, and two looser classes for your ruling

Both trees read the same snapshot (`cmp2`), real, hostile and attack.

**Against 3c66863:**
- Round-1 and attack corpora (2,800): 0 looser, 16 tighter.
- Modifier corpus (2,128): 42 looser, all the read class (`<mod> cat <state>` across 14 modifier forms, `<mod> zsh -c 'echo hi'`); 136 tighter; 4 below unmodified (G1 `coproc cd` and `repeat 0 cd`, correct).

**Against 76a08cb:**
- Corpora: 0 changed in 4,928 comparisons.
- My cap probes (`rr3-cap.txt`, `rr3-cap3.txt`) show the expected m1 read rows going from deny to none: five `if cd x … ls notes.md`, five `noglob cd x; ls notes.md`, 16 distinct absolute `noglob cd; ls notes.md`, and five `noglob cd x; cat src.md`.

They also show **two looser classes beyond those reads.** Both follow from m1's design as written in `_g20_seg`'s comment, and both are exact:

1. **An absolute non-Markdown write past the cap.** `5 × noglob cd x; echo x > /tmp/out.txt; ls notes.md`: deny → none. G20 judges such a write only by the absolute path (`_g20_md` or `_g20_mdfile` on the file there), so the directory set does not matter. 3c66863 also gives none.
2. **Any write after a plain absolute cd resets the cap.** `5 × noglob cd x; cd /tmp; echo x > out.md`: deny → none. After `cd /tmp`, every directory maps to /tmp, so the set is complete with one member, and G20 judges /tmp/out.md exactly. 3c66863 also gives none.

By your rule ("only the four m1 read commands may be looser against 76a08cb") these are Critical. On substance, 76a08cb's denies here were its blanket cap deny, not a judgement, and 2194d05's votes are exact and equal to base. I recommend extending the accepted class to "m1 as designed: reads, absolute non-Markdown writes, and anything after a reset", not a fix.

The ordinary commands are unchanged against both bases.

Logs: `t33r/c35d-*`, `t33r/a35d-*`, `t33r/t35r4-*`.

## 6. P21h under load

Quiet (load 2.1), the test took 1.9 s three times out of three.

During my corpus runs, at load 46 to 97, it failed 2 of 5 (`took 10 s`). The passing runs took 12 to 13.6 s of wall time, bats included, so the hook itself sat near the 10 s line. The bound is flaky only under extreme load, the same class as the existing 10 KB UTF-8 test, which also failed under my load in re-review 2.

**Recommendation:** make it relative. Time the same 110 writes after four plain `cd`s in the same test, and assert maybe ≤ 3 × plain + 2 s. Or assert on the number of `_g20_seg1` calls, which `_G20_` state can count, instead of wall time.

## 7. Stop rule

Not triggered.
- The batch authored no loosening against 3c66863.
- Against 76a08cb, the only looser rows are m1's read class and the two exact classes in section 5.
- It fixed a 76a08cb loosening (the 64-source truncation under a large set) that my re-review 2 missed.

## Important

- **I1. The source list fails open past 1024 unique sources** (hooks/guards/g20-approval.sh:737). `cat a0 … a1029 src.md > dst.md`, with `src.md` holding `status: approved`, gets none in both modes at every commit. A command of about 5 KB, or 64 words across 16 directories, reaches it. Fix: when the deduplicated list is longer than 1024 and `_G20_WRITES` is 1, deny ("too many files to check"). That fails closed, as the cap now does.

## Minor

- **m1.** `mixed` is command-wide, so an upper-case `CD` in any message turns every cd in the command into a maybe. That gives stricter-only false positives when a cd and a state or settings path share the command (section 4). It could be per record: the record's original-case text.
- **m2.** P21h is load-flaky (section 6).
- **m3.** `_G20_SEEN` misses directories dropped past the cap. That is covered in practice, because the union re-crosses the cap and writes deny.

## 8. Gates

- **Full suite at 2194d05**, in the background, before any load (`t33r/hooks-t35f.log`, which I read): 1..626, 626 ok, 0 not ok, EXIT=0.
- **kern-ci:task17** (mawk 1.3.4 20240123, uid 1000, `git archive 2194d05`): gitctx, g16-state and g20-probes bats give 1..152, 152 ok.
- **shellcheck** `-x -S warning hooks/lib/*.sh hooks/guards/*.sh hooks/pre-tool-use`: no output, rc 0.
- **Mutations**, re-applied to 2194d05 from the implementer's r1 to r6 (their copies carry older tests), plus two of mine (`t33r/mut35d-*.log`). All 8 are killed:

  | Mutation | Failing tests |
  | --- | --- |
  | r1, `sw_q` ignored | g16 37, g20 82 |
  | r2, `mixed` never set | g16 38 |
  | r3, back ignored | P21f |
  | r4, builtin arm removed | P21f |
  | r5, deny everything past the cap | P21g |
  | r6, no cap | P21g |
  | judge-once always (mine) | P21 to P21g |
  | source limit back to 64 (mine) | P21g |

- **Probes:** `t33r/rr2probe.sh` with `rr3-once.txt`, `rr3-src.txt`, `rr3-p234.txt`, `rr3-mixed.txt`, `rr3-cap.txt` and `rr3-cap3.txt`; `t33r/rr3time.sh` with `rr3-time.txt` and `rr3-p21h.txt`.

## Verdict

**APPROVED, conditional on your ruling on the two m1 classes in section 5.** They are exact and equal to 3c66863. If you hold strictly to "only the four reads", they count as Critical by the letter, and the fix would be to keep 76a08cb's deny for every write past the cap. I recommend against that. I1 (fail closed past 1024 sources) and the P21h bound are follow-ups.
