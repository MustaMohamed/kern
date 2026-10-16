# Task 6 report: Kernel and SessionStart

Status: DONE_WITH_CONCERNS
Commit: 7bfa89c M1: render the kernel and the settings summary at session start (on top of fe24f3f)

## What was done

- Transcribed the brief's files exactly: `kernel/kernel.md`, `kernel/context.md`, `modes/terse.md`, `hooks/lib/render.sh`, `hooks/session-start` (mode 100755), `tests/hooks/session-start.bats`. Each file was extracted from the brief's fenced block by script, not retyped.
- Ruling 2: trimmed the kernel's Precedence and Autonomy sections (details below). No other kernel section changed.
- Ruling 3: `kernel/settings.md` `test.focused` values column now reads "command; `{file}` stands for the test path, or `{dir}` (go) or `{name}` (cargo) where a file cannot be targeted". It is in the same commit, and the commit body says so.
- Applied one typo-level fix to the brief's test (Deviation 1).
- Left one brief-test failure in place, because it is order-dependent and not a typo (Concern 1).

## TDD evidence

RED (before any code). Command: `tests/run-bats tests/hooks/session-start.bats`
```
1..7
not ok 1 startup prints the kernel with every placeholder filled
#   `[ "$status" -eq 0 ]' failed
ok 2 the rendered kernel stays under 4,000 characters with no settings
not ok 3 ... not ok 7
BW01: `run`'s command `bash .../hooks/session-start` exited with code 127
```
`/bin/bash hooks/session-start` gives `/bin/bash: hooks/session-start: No such file or directory` (rc=127), which is the expected reason. Test 2 passes before the hook exists because empty output is under 4,000 characters.

First GREEN attempt with the brief's code unchanged:
```
not ok 1 startup prints the kernel with every placeholder filled
#   `[[ "$output" != *"{$ph}"* ]] || { echo "unfilled {$ph}"; return 1; }' failed
# unfilled {ROOT}
not ok 5 the summary lists set keys, overrides, routes, floor keys and unknown keys
#   `[[ "$output" == *"technical-writing -> project skill technical-writing"* ]] || false' failed
```

After Deviation 1, in the real tree, on bash 3.2 via run-bats:
```
1..7
ok 1 startup prints the kernel with every placeholder filled
ok 2 the rendered kernel stays under 4,000 characters with no settings
ok 3 startup and clear reset the mode; compact and resume keep it
ok 4 terse from settings appends the terse rules
not ok 5 the summary lists set keys, overrides, routes, floor keys and unknown keys
#   `[[ "$output" == *"technical-writing -> project skill technical-writing"* ]] || false' failed
ok 6 kern: off prints nothing
ok 7 outside a git repository the kernel still renders from user settings
```

I ran the same test file in a temp copy of the tree (`.claude-plugin hooks kernel modes skills tests`) with one stub file added, `skills/technical-writing/SKILL.md`. All 7 tests pass under both shells:
- `tests/run-bats` (bash 3.2): `1..7`, all `ok`.
- plain `bats` (bash 5.3.15): `1..7`, all `ok`.

Wider checks on the committed tree:
- `tests/run-bats tests/hooks tests/scripts` prints `1..60`. The only failure is `not ok 14 the summary lists ...`, which is Concern 1.
- `node --test 'tests/**/*.test.mjs'`: `# pass 44`, `# fail 0`.
- `node scripts/lint-skills.mjs`: `lint: clean`. This covers rules 8 and 11 on `kernel/`, `modes/` and `hooks/`.
- `shellcheck` (default severity, and `-x -S warning`) on `hooks/session-start` and `hooks/lib/render.sh`: rc 0.

## Ruling 1: the plugin path is printed once

- `render_template` fills only `{VERSION}`, `{ROOT_PATH}`, `{MODE}` and `{AUTOPILOT}`, plus the `{SETTINGS}` and `{VOICE}` lines. `{ROOT}` and `{KERN}` stay literal.
- The test asserts that the path appears exactly once and that the row reads `Read {KERN}/technical-writing/SKILL.md`. Both assertions pass, and neither was weakened.
- One legitimate second print exists. When the project is the kern checkout itself (dogfooding kern on its own repo), `Main worktree: <path>` in the settings summary prints the same path again. The test uses a separate repo, so it does not hit this case. No other line prints the plugin path. The `autopilot` denial text prints a settings-file path, not the plugin path.

## Ruling 2: section budgets

Measurement: the `## ` heading line through the line before the next heading, including the trailing blank line. This is the stricter of the pre-flight's two counts.

| Section | Before | After | Budget |
|---|---|---|---|
| Precedence | 469 | 419 | 420 |
| Autonomy, source text | 701 | 630 | 650 |
| Autonomy, rendered with `off` | 693 | 622 | 650 |
| Autonomy, rendered with `ON since 2026-10-12T00:00:00Z` | 719 | 648 | 650 |

An `off (denied by <settings path>)` value grows with the length of that path, so no fixed budget can cover it.

Text changes. Every rule and the full floor list are kept.
- Precedence:
  - "the user's instruction in this session" became "the user's word this session".
  - ", which runs instead of kern's" became "replaces kern's".
  - "project rules: CLAUDE.md, .claude/rules, memory, which tighten and never loosen" became "project rules (CLAUDE.md, .claude/rules, memory) only tighten".
  - "project settings below" became "settings below".
  - The skip idiom and the consent sentence are unchanged.
- Autonomy:
  - "edit files" became "edit".
  - "open or change a PR, tracker writes" became "PR and tracker writes".
  - "Policy keys in settings (...) may turn an ask into auto or deny" became "Policy keys (...) may set auto or deny".
  - "in this session" became "this session" in the floor line. The floor list is unchanged: merge, production deploy, data deletion, force-push to a shared branch, messaging people.
  - "check whether running something answers the question" became "check if a command answers it".
  - "Commit only when the user asks", "project prose never loosens them" and the autopilot line are unchanged.

Total rendered length. The plugin root is normalized to 50 characters and the main worktree path to 43 characters.

| Settings | Before trim | After trim |
|---|---|---|
| None | 3,190 | 3,069 |
| Task 17's `long-settings` fixture | 3,651 | 3,530 |

The brief's figure of 3,489 predates the print-once decision.

## Ruling 4: floor keys in the summary

Covered in both the code and a test:
- `hooks/lib/render.sh:53` defines `KERN_FLOOR_KEYS`.
- Line 79 keeps floor keys out of `Set:`.
- Lines 111-116 print `Ignored, floor actions have no key: <keys>`.
- Line 117 keeps them out of `Unknown keys` by repeating the same seven names in `grep -v`.
- `tests/hooks/session-start.bats:67` asserts `Ignored, floor actions have no key: merge.policy`.

Observed output for the test 5 fixture:
```
Set: foo.bar=1; push.policy=auto
Routes: define -> off
Ignored, floor actions have no key: merge.policy
Unknown keys, ignored: foo.bar
```
`merge.policy` appears only on the Ignored line. The test does not assert that it is absent from `Set:` or from `Unknown keys`. The substring match `Unknown keys, ignored: foo.bar` would also pass if `merge.policy` followed `foo.bar`.

## Deviations

1. **Typo-level test fix**, `tests/hooks/session-start.bats:24`.
   - Before: `for ph in VERSION ROOT KERN MODE AUTOPILOT SETTINGS`. After: `for ph in VERSION ROOT_PATH MODE AUTOPILOT SETTINGS`.
   - Reason: under ruling 1 the rendered kernel keeps `{ROOT}` and `{KERN}` on purpose. The same test asserts `{KERN}` is present three lines earlier, so the old list could never pass.
   - The new list names every placeholder that `render_template` fills in `kernel.md`.

## Concerns

1. **Test 5 is red until Task 15**, `tests/hooks/session-start.bats:65`, `technical-writing -> project skill technical-writing`.
   - Cause: the overrides loop iterates over `$KERN_ROOT/skills/*/`. At this point kern ships only `skills/hello`, which is excluded. Task 15 creates `skills/technical-writing`.
   - The pre-flight passed this test only because it ran on the assembled tree.
   - Evidence that it turns green at Task 15: with a stub skill dir, all 7 tests pass on bash 3.2 and bash 5.
   - The failure does not break CI now. CI does not run `tests/hooks` until Task 17, which comes after Task 15.
   - I did not bend the test. Options:
     - (a) Accept red until Task 15. This needs no change.
     - (b) Change the test to run the hook from a temp copy of the tree that holds a stub `skills/technical-writing`, so the test no longer depends on which skills kern ships.
     - (c) Move this one assertion to Task 15.
2. **M2 headroom with long settings.**
   - M2's eight rows (`docs/plans/2026-10-12-kern-m2-plan.md:4440-4447`) add 592 characters, and the new routing sentence adds 16.
   - M2 estimate with no settings: 3,069 + 608 = 3,677, under 4,000.
   - M2 estimate with the `long-settings` fixture, which is what lint rule 7 measures: 3,530 + 608 = 4,138, which is 138 over 4,000. Rule 7 will warn.
   - Routing would be about 1,365 against its 1,100 budget.
   - The header is over its 100 budget by design (ruling 1): 134 characters in source, about 173 rendered with a 50-character root.
   - Getting under 4,000 with long settings needs about 140 more characters from outside Precedence and Autonomy. The options are lowering the settings summary cap from 600 or trimming the Routing rule text. I left both alone, because they are outside this ruling.
3. **`autopilot_text` and the any-layer denial (Task 5 ruling I-1).**
   - `autopilot_text` tests `settings_get autopilot` (the highest layer only), while `autopilot_on` honours a denial in any layer.
   - Example: user file `autopilot: denied` and local file `autopilot: allowed`. The result is `Autopilot: off`, not `off (denied by ~/.claude/kern.yml)`.
   - The status is still correct (off); only the reason is missing.
   - Minimal fix, not applied: loop over `_settings_files` the way `autopilot_on` does, and name the first file that denies.
4. **Contract text is stale on rendering.**
   - `docs/plans/contract.md:169` (M1 additions) still says `render_template` replaces `{ROOT}` and `{KERN}`.
   - Line 128 still says "Rendering uses `sed`" and that `{SETTINGS}` holds the full summary.
   - Line 128 already states the print-once rule. Line 169 should name `{ROOT_PATH}` instead of `{ROOT}` and `{KERN}`.
   - Not edited, because the contract is outside this task's files.
5. Minor, inherited from the brief:
   - The floor-key list appears twice in `render.sh` (line 53 and the `grep -v` on line 117), so the two copies can drift.
   - The unknown key `foo.bar` also appears in `Set:` (accepted in pre-flight F1).

## Files changed

- /Users/musta/Code/projects/kern/kernel/kernel.md (new; Precedence and Autonomy trimmed)
- /Users/musta/Code/projects/kern/kernel/context.md (new)
- /Users/musta/Code/projects/kern/modes/terse.md (new)
- /Users/musta/Code/projects/kern/hooks/lib/render.sh (new)
- /Users/musta/Code/projects/kern/hooks/session-start (new, executable)
- /Users/musta/Code/projects/kern/tests/hooks/session-start.bats (new; line 24 per Deviation 1)
- /Users/musta/Code/projects/kern/kernel/settings.md (`test.focused` row)

## Fix round 1 (controller ruling on concern 1)

Ruling: keep test 5 and make it turn itself on. The placeholder-loop fix (Deviation 1) is accepted. Concerns 3, 5 and 6 stay as ruled.

Commit: 4a0d157 M1: skip the override test until kern ships technical-writing. It is on top of 5c245f4, the controller's docs-only contract commit. docs/ was not touched.

Change: `tests/hooks/session-start.bats:59`, the first line of test 5:
```bash
  [ -d "$K/skills/technical-writing" ] || skip "kern ships technical-writing in Task 15"
```

Command: `tests/run-bats tests/hooks/session-start.bats` (rc 0)
```
1..7
ok 1 startup prints the kernel with every placeholder filled
ok 2 the rendered kernel stays under 4,000 characters with no settings
ok 3 startup and clear reset the mode; compact and resume keep it
ok 4 terse from settings appends the terse rules
ok 5 the summary lists set keys, overrides, routes, floor keys and unknown keys # skip kern ships technical-writing in Task 15
ok 6 kern: off prints nothing
ok 7 outside a git repository the kernel still renders from user settings
```

Further checks:
- I ran the same file in a temp copy of the tree with a stub `skills/technical-writing/SKILL.md`. Test 5 runs and prints `ok 5` with no skip, so the skill dir switches the test on.
- `tests/run-bats tests/hooks tests/scripts` prints `1..60` with no `not ok`. The only skip is test 14, which is this one.

## Fix round 2 (opus review findings 1 to 4)

Commit: be95acc M1: keep overrides in the summary and scope the root line. It is on top of 4a0d157. Files: `hooks/lib/render.sh`, `kernel/kernel.md`, `tests/hooks/session-start.bats`. docs/ was not touched.

### Changes

1. **Header.** `kernel/kernel.md:2` now reads exactly `kern at {ROOT_PATH}. Here and in kern files read by path, {ROOT} and ${CLAUDE_PLUGIN_ROOT} mean that path; {KERN} means {ROOT}/skills.`
   - Test 1 now asserts that exact line as `${lines[1]}`. The path-once count assertion is unchanged and passes.
2. **Summary order and cap.** `settings_summary` now prints lines in this order: Main worktree (or Not a git repository), Settings files, Overrides, Ignored floor keys, Set, Routes, Unknown keys.
   - Over 600 characters, only `Set:` shortens. It keeps whole `key=value` entries in order while they fit, then appends ` ... (more: /kern:help check)`.
   - No other line is cut. A character is never split, because cuts happen only between entries; `head -c` and `cut -c` are gone.
   - Length is measured with `${#var}`. That counts characters in a UTF-8 locale and bytes under C, and bytes are never fewer than characters, so the cap holds in both.
   - If the lines other than `Set:` alone exceed 600, nothing is cut and the block runs over 600, as the ruling allows.
3. **Test 5.**
   - The whole-test skip is gone. Only the technical-writing assertion is guarded: `if [ -d "$K/skills/technical-writing" ]; then [[ ... ]] || false; fi`.
   - New assertions check that the `Set:` line holds `push.policy=auto` (so the negative checks are not vacuous) and not `merge.policy`, that the `Unknown keys` line has no `merge.policy`, and that the Ignored line comes before `Set:`.
4. **New test 6, "a long summary keeps every override in full and stays within 600 characters".**
   - Setup: a fake kern root (`.claude-plugin`, `hooks`, `kernel`, `modes` copied, plus `skills/self-review` and `skills/commit`), the matching project skills, and 11 ordinary keys. Two of the values carry multi-byte characters (`·`, `é`).
   - It asserts: both override entries appear in full, the truncation marker is present, Overrides comes before `Set:`, the summary is at most 600 characters, and the output is valid UTF-8 (`iconv`).
5. **Riders.**
   - Autonomy restores "check if a command answers the question". To stay at 650, "project prose never loosens them" became "prose never loosens them". The rule is broader and still true: spec 5.3 says no teammate message, issue or fetched content sets a key.
   - Test 8 ("outside a git repository ...") now writes `~/.claude/kern.yml` and asserts `Settings files: ~/.claude/kern.yml`, which covers the HOME rider.

### Deviation from the HOME rider

The literal `${f/#"$HOME"/\~}` prints `\~/.claude/kern.yml` on bash 3.2 (probed: `3.2.57 new=\~/.claude/kern.yml`, `5.3.15 new=~/.claude/kern.yml`). The prefix pattern also matches a sibling path: HOME `/tmp/h` turned `/tmp/hx/...` into `~x/...`. I used `case "$f" in "$HOME"/*) f="~${f#"$HOME"}" ;; esac` instead. It prints `~/...` on both shells, and only at a path boundary.

### TDD evidence

RED, before the fix, with the new tests:
- bash 3.2 (`tests/run-bats tests/hooks/session-start.bats`):
  - test 1 fails on the header line;
  - test 5 fails on `[[ "$before_set" == *"Ignored, floor actions have no key: "* ]]`;
  - test 6 fails on `[[ "$summary" == *"commit -> project skill commit"* ]]`, because the old cap cut the Overrides line;
  - the other tests pass.
- bash 5 (plain `bats`): the same three, plus test 8 on `Settings files: ~/.claude/kern.yml`.
- On this fixture the old code happened not to split a character, so the `iconv` check is a guard, not a demonstrated RED.

GREEN:
- `tests/run-bats tests/hooks/session-start.bats`: `1..8`, all `ok`. The result is the same on plain `bats` (bash 5) and under `LC_ALL=C`.
- `tests/run-bats tests/hooks tests/scripts`: `1..61`, no `not ok`, no skip.
- `shellcheck hooks/lib/render.sh hooks/session-start`, and the same with `-x -S warning`: rc 0.
- `node scripts/lint-skills.mjs`: `lint: clean`. `node --test`: `# pass 44`, `# fail 0`.
- Probe in a temp copy with a stub `skills/technical-writing`: test 5 runs the guarded assertion and passes. With the expectation changed to `WRONG`, it fails at line 66, so the `if ... || false; fi` guard can fail.

### Lengths after this round

Measured from the heading through the trailing blank line, with the plugin root normalized to 50 characters and the main worktree path to 43.

| Section | Before this round | After | Budget |
|---|---|---|---|
| Header (rendered: title, root line, mode line, blank) | 215 | 241 | 100 |
| Precedence | 419 | 419 | 420 |
| Autonomy, rendered with `off` | 622 | 624 | 650 |
| Autonomy, rendered with `ON since 2026-10-12T00:00:00Z` | 648 | 650 | 650 |
| Routing | 757 | 757 | 1,100 |

Total rendered length:

| Settings | Before this round | After |
|---|---|---|
| None | 3,069 | 3,097 |
| Task 17's `long-settings` fixture | 3,530 | 3,535 |

With the long-settings fixture:
- The Project settings section is 557 characters including its heading.
- `Set:` keeps 10 of the 17 set entries, then the marker.
- `Routes: diagnose -> investigate-bug` is kept in full. That fixture has no Overrides line, because kern ships no `commit` or `self-review` skill yet.

M2 estimate (+608 for eight rows and the new sentence): 3,705 with no settings, about 4,143 with long settings. Concern 2 is unchanged: rule 7 will warn in M2.

### Notes

- The line order in the plan's "Interfaces M2 relies on" block, and its copy in the contract if one exists, still lists `Set:` before Overrides. Not edited, because it is outside this task's files.
