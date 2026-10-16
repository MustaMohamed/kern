### Spec Compliance

Scope: be26d2f..2cee3e3, read against the rulings from "Ruling: M1 close code-review wave" onward. Every probe went through hooks/pre-tool-use on /bin/bash 3.2 and awk 20200816, under autopilot and interactively. The setup was a throwaway repo with a linked worktree, a second repo and a stub gh.

- ✅ **1** `-Ec`, `-c --`, `--rcfile f -c` and `sh -Cc` around a force push are denied in both modes. The merge and kubectl classes ask, or deny under autopilot. A protected-target ssh deletion is denied. Residual: Minor 9.
- ✅ **2** The `${ }` and `$[ ]` shapes now reach G1 and G13. I compared 31 here-doc shapes between bash 3.2 and git_words. No line that bash runs was hidden; six are over-read, the safe direction.
- ✅ **3** A `-C` push into another repo is denied under autopilot and asks interactively. A `-C` push into the worktree is still allowed, also through the /tmp symlink.
- ✅ **4, 5, 6, 12, 14, 15** Each got the ruled vote. gh aliases are caught behind env, command, `bash -c` and `--repo=`. For item 12, the last `--body-file` decides, as gh reads it.
- ✅ **7** `git add .env && git commit` asks with the stale-scan reason, and is denied under autopilot.
- ✅ **8** The named shapes are closed. ❌ Residuals: Important 3 and Minor 6.
- ✅ **9** `env -C`, `--chdir`, `-C<dir>`, `ENV`, `/usr/bin/env`, `env -u X -C` and `sudo -D` are closed. Residual: Minor 8.
- ✅ **10** A 700 KB Write takes 1.1 s in both modes. Residual: Minor 5.
- ❌ **11** None of 28 spellings in a committed kern.yml bypasses the rule. I tried key case, whitespace, `kern:off`, both quote kinds, split quotes, a comment, CR, a duplicate key in both orders, a flow map, a block scalar and a `!!str` tag. Each loosening value reads as unset or as ask. Still open: Important 1 and 4.
- ✅ **13** Closed, with residuals Important 2 and Minor 7. The accepted limits and the M2 `$((` misread are not counted.
- ✅ **Daily commands** 40 commands got no vote in both modes: npm, pnpm and yarn scripts, pytest, node scripts, git reads and fetch, gh pr list, view and checks, cat and jq on settings files, and a python here-doc. The expected exceptions: `git add -- a && git commit -m x` asks, and the M2 `$((` case is denied under autopilot.
- ✅ **Cost** `ls` takes 0.16 s and a 10 KB inline PR body 0.37 s. A 300-line script takes 3.5 s under autopilot, against 3.8 s at be26d2f.
- ⚠️ **Probe hygiene** One batch's here-doc ended early and its tail ran in my zsh: a python3 print, two `ls` reads and an rg search. Nothing was written.

### Strengths

- G0's dynamic-name check reaches through `sudo`, `timeout`, `time`, `command`, a `bash -c` body and a `$( )` script.
- `_settings_ignored` and every consumer compare exact values after the parser strips quotes and comments, so spelling cannot split them apart.

### Issues

**Important**

1. **settings.sh:59 (authored-by-wave): a tracked `.claude/kern.local.yml` is honoured as the untracked local file.**
   - Probe: a committed kern.local.yml set `kern: off`, and the user file set `protected_targets`. The protected-target ssh deletion went from deny to no decision in both modes.
   - On macOS, a committed `KERN.LOCAL.YML` acts the same.
   - The ruling says "the local untracked file", and kernel/settings.md:4,8 promise it. Item 11's attack works under another filename.
   - Fix: apply the committed-file rules when `git ls-files --error-unmatch` finds the file tracked. Add a test.
2. **g00-unproven.sh:132 (authored-by-wave): G0 takes a `/dev/stdin`, `/dev/fd/N` or `/proc/self/fd/N` script operand as a script file.**
   - Probes: a fetch piped into `bash /dev/stdin`, `sh /dev/fd/0` or `bash -- /dev/stdin`, and a force push in a here-string fed to `bash /dev/stdin`. Under autopilot, none gets a vote.
   - bash 3.2 runs all three forms (checked with echo). The ruling keeps a shell that reads a pipe or here-string denied, and the `bash -s` form is denied.
   - Fix: when `cw_w[shc_op]` matches line 160's regex, judge it by `g0_src()`.
3. **g16-state.sh:907-916 (plan-mandated by the rider's list; be26d2f missed it too): git reads unless it runs one of ten listed subcommands.**
   - In both modes, `git mv <tracked file> .claude/kern.local.yml` gets no vote. So does `git rm` of a tracked `.claude/settings.json`, and so does `--output` or `-o` of git diff, log and archive.
   - Under autopilot, Claude can move a tracked `kern: off` file into place, and every guard is off from the next call. That is item 8's failure.
   - Fix: add mv, rm and clean, and count `--output` or `-o` as a write. Better: list the git subcommands that only read.
4. **gitctx.sh:487-507 (pre-existing): a committed `base_branch` removes main's protection.**
   - With `base_branch: zzz` committed, autopilot allows a commit on main and a push of main. Both are denied without it.
   - The key is outside the ruling, but this is item 11's threat. kernel/settings.md:8 now reads as though no other key needs the rule.
   - Fix: protect both the committed base_branch and origin/HEAD, or ignore it.

**Minor**

5. **json.sh:50 (authored-by-wave): the main loop still calls `substr(buf, i, 1)` outside strings.**
   - Mostly structural mcp__ input stays quadratic: 589 KB of numbers takes 6.2 s and 1.29 MB takes 27.6 s. The second passes the 20 s timeout, and the call is blocked.
   - Fix: `c = C[i]`, measured at 0.22 s where it was 5.6 s.
6. **g16-state.sh:731 (authored-by-wave; the rider left this limit for the re-review to judge): `_g16_pathy` also drops redirect targets and copy destinations.**
   - Under `<dir with a space>/.claude/`, a write to kern.local.yml or settings.local.json gets no vote. be26d2f asked.
   - Judged: not acceptable there. Apply the filter only to message-like operands.
7. **g00-unproven.sh:147 (authored-by-wave): G0 checks only the head for a run-time name.**
   - `$g` after xargs or `find -exec` gets no vote, and so does `source $x`, while `sudo $g` and `bash $f` are denied.
   - Fix: also check the word after xargs, `-exec`, `-execdir` and `-ok`, and source's operand.
8. **g05-commit.sh:134 via g01-git.sh:239 (pre-existing, inherited by item 9): `env -S "-C <dir> ..."` moves the directory unseen.**
   - macOS env honours it (checked with pwd).
   - From a worktree, a D3 reset in the main checkout gets no vote.
   - Fix: read `-S`'s value with cw_line first.
9. **gitctx.sh shc (pre-existing): zsh's `--emulate` takes a value, and shc reads it as valueless.**
   - `zsh --emulate sh -c '<script>'` is not unwrapped, and zsh 5.9 runs it.
   - Interactively, a force push inside it gets no G1 deny. Under autopilot, G0 denies it.
10. **g00-unproven.sh:188 and decide.sh:31 (authored-by-wave): the new guard reuses G0.**
    - contract.md:192 gives G0 to `fail_closed`, so "guard g00 did not load" and a G0 deny share one label.
    - Fix: give the new guard its own id.

### Assessment

**Task quality:** Needs fixes. Fourteen of the 15 items are closed for the scenarios they named, with no false asks on daily commands and no cost regression. Item 11 is still open through a tracked kern.local.yml and a committed base_branch. G0 and G16 each let one ruled shape pass under autopilot.
