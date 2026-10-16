### Spec Compliance
- ✅ `skills/mode/SKILL.md` matches the brief character for character. Frontmatter has `disable-model-invocation: true` and `allowed-tools: Read`.
- ✅ `skills/autopilot/SKILL.md` matches the brief except for the two bullets at lines 28-29, which the Task 14 ruling authorises. Their text matches the ruling.
- ✅ `tests/skills-control.test.mjs` is identical to the brief. I ran it: 4/4 pass.
- ✅ Typed-only: `disable-model-invocation: true` stops the model invoking either skill. The hook enforces the rest. `hooks/prompt-submit:141,159-161` passes ALLOW_ON=1 only for an expansion of type `slash_command`, or a prompt that starts with `/kern:mode` or `/kern:autopilot`. Wrapped prompts (task-notification, scheduled-task, teammate-message) never switch anything (`wrapped`, line ~131). `<command-name>` replays get ALLOW_ON=0, so `on` is ignored.
- ⚠️ Ruling accuracy was checked below, not by running the hooks.

### Strengths
- The `-F` claim is true. `_g05_message` reads an absolute `-F` path. `_gh_file_ok` (`g02-pr.sh:242-255`) accepts a regular, non-symlink file under `<main>/<work_dir>/`. `scripts/kern-dir msg` prints exactly that kind of path.
- The `$( )`/backtick denial (`g05:261`, `g05:_g05_proven`) and the no-`cd`, no-wrapper claim (`_G05_RECS[0]` must start with `git `; `_G01_IDX = 1`) are correct.
- The `git add -A` claim is correct (`g05:169-187`), and so is the lease-push claim (`g01:601-610`).
- The `kern mode:` line format is `voice= surface= autopilot=` (`render.sh:39`). The denial notice is "kern: autopilot denied by <file>." (`prompt-submit:80`). Both match the skill.
- The Task 14 diff is two markdown files plus one test. The scope is small.

### Issues

**Important**
1. `skills/autopilot/SKILL.md:30` (plan-mandated) says "Push the current branch when it is not protected". This misleads. `_g01_proven` (`g01:483-493`) needs at least one refspec and a named remote, so G1 allows only `git push [-u] <remote> <current-branch>`. Bare `git push` and `git push origin` are denied under autopilot (`g01:622-623`), as is any push from a `cd`'d or wrapped call. The lease bullet at line 32 has the same gap: it needs `git push --force-with-lease <remote> <branch>`, and `--force-with-lease=<ref>:<expect>` is denied (`g01:603`). Fix: write the bullet as "Push with `git push [-u] <remote> <current-branch>`, naming both, when the branch is not protected", and say the lease form is also bare-option plus remote plus branch. A further bullet would exceed the ruling, so ask the controller to extend it or fold this into the existing bullet.
2. `skills/autopilot/SKILL.md:27` (plan-mandated) says "Commit when the message passes...". It omits a denial a user will hit. G5 allows a commit only on an unprotected branch (`g05:354`), and under autopilot a commit on `main`, `qa`, `uat` or `production` is denied (`g05:400`). It also allows only `-m`, `-F`, `-q` and `-v`, so `--amend`, `-a` and `--no-verify` are denied. Fix: add "on a non-protected branch, with only -m or -F" to the bullet.

**Minor**
3. `skills/autopilot/SKILL.md:23` asks `status` to report "since when" and the settings source. The `kern mode:` line carries only `voice`, `surface` and `autopilot`. The `since` value is printed only at session start (`session-start:32`, `autopilot_text`). In the skill's own words, the status reply cannot get it from "the line the hook injected this turn", and the skill's only tool is Read. Plan-mandated; name where to read it or drop it.
4. `skills/autopilot/SKILL.md:31` "Open a draft PR after the duplicate check" hides that G2 allows only `gh pr create --draft` alone, with `--title`, `--base`, `--fill` or a repo-file `--body-file`. It also hides that a merged or closed PR for the head is not allowed under autopilot (`g02:310`, ask becomes deny). Plan-mandated.
5. `skills/mode/SKILL.md:15` says "default and where it comes from", but nothing in the hook line gives the source. The model has to read the settings files itself. Plan-mandated, low impact.

### Assessment
**Task quality:** Approved. The brief and the ruling are transcribed exactly and the test passes, but the "Push the current branch" and "Commit" bullets understate how narrow G1 and G5 are, and the controller should decide whether to amend them (plan-mandated).
