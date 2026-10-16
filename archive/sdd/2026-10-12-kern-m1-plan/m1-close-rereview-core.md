### Spec Compliance

Scope: d322e19..a2e0b90 (wave A), read against the "M1 fix wave A", "addendum" and "concerns" rulings. Probes ran under /bin/bash 3.2 and en_US.UTF-8, with all guards on unless a probe names fewer.

- ✅ **C1** (json.sh:84-99). The probe `git push --force origin main; git x\by` under autopilot now prints a deny that node's JSON.parse accepts. Two variants were also checked and parse: `\f` in place of `\b`, and `caffeinat\be git push`. /usr/bin/awk round-trips every byte from 1 to 127.
- ✅ **I1** (gitctx.sh:98-102). A quoted first word took 1.1 s at 1 KB, 13.9 s at 3 KB and 460 s at 10 KB. It now takes 0.21 s, 0.26 s and 0.52 s.
- ✅ **I2, first steps.**

  | Input | Before | Now |
  |---|---|---|
  | `ls` | 0.20 s | 0.12 s |
  | 200 × `echo` | 7.7 s | 2.2 s |
  | 200 × `git log` | 8.0 s | 2.3 s |
  | 200 × `gh pr view` | 10.7 s | 5.9 s |
  | 131-line `bash -c` | 10.7 s | 8.2 s |
  | 10 KB inline PR body | 1.1 s | 0.85 s |

  The rest goes to M2, as ruled. After a SIGTERM to a slow dispatcher, no descendant was still alive 6 s later.
- ✅ **I3** (settings.sh:52-101). In the probe and in the new test, a project-layer target no longer drops a user-layer target.
- ✅ **Ruled Minors.**
  - M1: g06:108-110 sets the budget start when the dispatcher sources the file.
  - M2: pre-tool-use:52-69 fails closed on a file that does not source and on a missing id.
  - M3: g16:160-164.
  - M4: gitctx:334 and g15:177.
  - M5: prompt-submit:185.
  - M7: common.bash:61-80. Also the inline-body timing test and the parse test.
- ✅ **Fuzz offenders.** crash00, crash05, crash10, crash15 and crash19, each wrapped with JSON.stringify as Claude Code does, give valid JSON. The decision is ask with autopilot off and deny with autopilot on.
- ⚠️ **mawk is untested.** The json_escape regex holds raw control bytes, and mawk is not installed here. CI's json.bats run on mawk will be the first test of it.

### Strengths

- **The gh prefilter is a superset of what G2, G3 and G4 caught before.** Pattern 2 (`*[Gg][\"\'\\]*[Hh]*`) matches every gh that is split only by quotes or backslashes, backslash-newline included. A gh built from a variable was missed before as well. G3's Skill branch still runs ahead of the prefilter. Nothing writes to `_GH_RECS` after `_gh_load`, so caching it on `_GH_CMD` is safe.
- **The G16 prefilter is a superset of the old `_g16_names` check.** The old check ran on lower-cased text, and its `$_G16_SD` match always ends in `sessions`. The glob gap was already there before this change (concern 2).
- **KERN_GUARD_IDS keeps the old run order.** Every guard file's last top-level command returns 0, so `. "$f" ||` does not flag a healthy file. Probed: `.` returns non-zero on a syntax error under both bash 3.2 and bash 5.
- **The union reads cleanly.** Brackets are dropped per layer. An empty higher value adds nothing. The default applies only when no layer sets the key. `list_has`, `_g06_paths` and G13's split each read the comma-joined value correctly.

### Issues

**Important**

- **scripts/kern-detect:97 (now called by G5, from 4da0a4f): `git log` runs without `--no-show-signature`.**
  - Probe: a repo with `log.showSignature=true` and signed history, `commit.convention` unset, and the command `git commit -m swap`.
  - The G5 hook ran the repo's `gpg.ssh.program` 12 times. Each "No signature" or "Good signature" line counted as a subject, so the 6 matching subjects fell to 50 %, below the 60 % threshold.
  - Detection failed, so G5 checked no convention: it asked instead of denying. Under autopilot the proven shape is allowed.
  - With `showSignature=false`, the same command was denied with "detected from git log", and the program did not run.
  - This breaks contract.md:102 and the rulings at progress.md lines 219 and 233: a guard's `git log` may not run a program that repo config names.
  - Fix: add `--no-show-signature` at kern-detect:97, plus a test pairing a signed commit with `log.showSignature=true`.

**Minor**

- **settings.sh:73-75: union values keep duplicates and layer order.** Example: a project sets `deploy.envs: qa, production` and the user sets `production`. The result is `qa, production, production`. The guards are unaffected. The M2 ship-check reads `deploy.envs` as the promotion path (spec line 338), so drop duplicates in settings_get, or record that the union is unordered.

### Assessment

**Task quality:** Needs fixes. C1, I1, I3 and every ruled Minor are closed, and the I2 first steps take effect. The one new defect is kern-detect's `git log` without `--no-show-signature`, now reachable from G5, and it needs only that one flag.
