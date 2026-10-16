### Spec Compliance
- ✅ Files, test files, SKILL.md, map.md, fix-a-run.md, template and rule 6 body match the brief. Only the three reported deviations differ: `\d+\.` at `scripts/lib/lint-rules.mjs:~181` (covered by the Ruling), the `0.` case at `tests/lint-rules.test.mjs:~141`, and the two protected_targets comment lines at `skills/help/templates/kern.local.yml:~42`.
- ✅ Ran `node --test tests/skills-help.test.mjs tests/lint-rules.test.mjs`: 20 pass, 0 fail. `node scripts/lint-skills.mjs`: `lint: clean`.
- ✅ Map header and first-cell backtick format match the brief. `hello` is exempted in `scripts/lint-exemptions.json`.
- ⚠️ The Ruling line in progress.md is cut off at the regex because the literal newline in `/^## Steps\n+\d+\. /m` splits the line. The code does what the Ruling says.

### Strengths
- Setup follows the brief: read-only exploration, a yes before any write, exclude lines only, autopilot refusal. Pinned by tests.
- Template `protected_targets` comment matches `kernel/settings.md` (exact host, host:port, sqlite path, aliases, tunnel host:port) and G13's "proven reads only".
- Detect keys, `kern-get`, the `kern G<n>:` reason prefix (`hooks/lib/decide.sh:48`), `autopilot denied by`, the state-file path and `key: value` format (`hooks/lib/state.sh`) all match the help text. The status-line snippet agrees with `state.sh`.

### Issues
**Critical:** none.

**Important**
1. `scripts/lib/lint-rules.mjs:~170` (plan-mandated). The route-row regex requires `Read {X}/path |` to end the row. A row that does not match is skipped silently. Probed:
   - ``| P | Read `{KERN}/nope/SKILL.md` |`` finds 0 routes.
   - `| P | Read {KERN}/nope/SKILL.md, then x |` finds 0 routes.
   - Only the bare form is checked. A broken target written either way passes rule 6.
   Fix: collect every `Read {KERN|ROOT}/` occurrence in the Routing table. Or error when a Routing row contains `{KERN}` or `{ROOT}` but does not match. Add a test for it.
2. `skills/help/SKILL.md:~29`, Check section (plan-mandated). It tells the user to take unknown and floor keys from "the kernel's Project settings block". That block is capped at 600 chars (`hooks/lib/render.sh:56`) and ends with "(more: /kern:help check)". So `/kern:help check` points back at a list that may be cut, and it is the only place the full list was meant to come from. The unknown-key helper `settings_unknown_keys` (`hooks/lib/settings.sh:101`) has no script, and `allowed-tools` lists none. Check therefore relies on the model comparing keys by hand. Fix: say to Read each settings file and compare its keys with the `kernel/settings.md` table. Name the floor keys (`merge.policy`, `deploy.policy`, `production.policy`, `force_push.policy`, `delete.policy`, `message.policy`, `messaging.policy`). Or ship a small `kern-check` script.

**Minor**
1. `skills/help/SKILL.md:3` (plan-mandated). `allowed-tools` omits `git rev-parse` and `git check-ignore`, which setup step 6 uses. It also omits `scripts/kern-root`, which fix-a-run row 6 names. Each prompts the user. Writes use Write or Edit, which `allowed-tools` does not grant either. That is acceptable at a yes gate, but say so.
2. `skills/help/SKILL.md:~25`. Setup step 6 hardcodes `/.kern/`, but `work_dir` is configurable and `scripts/kern-dir` already adds the exclude line. Use `work_dir`'s value, or defer to `kern-dir`.
3. `skills/help/templates/kern.local.yml:~7`. `base_branch: main` is uncommented, so a draft built from the template overrides detection, against the "written only where detection guessed wrong" rule in setup step 2. Comment it out or build from the detected value.
4. `skills/help/references/map.md:3`. The tier text says `slash` loads only when typed, but `unslop` is `slash` and its "Reached by" cell names the kernel's Reply rule. `auto` is defined and unused. Align the wording.
5. `skills/help/references/fix-a-run.md:9`. "design spec, section 8.3" exists (`docs/specs/2026-10-12-kern-design.md:396`) but is a repo doc, not a user-facing one.
6. `tests/skills-help.test.mjs:~30`. The `['One','Every']` filter can never match (the lines start with a capital, the regex wants lowercase). Also no test for `## Steps` followed by a bullet list. The "must open with a numbered list" branch of rule 6 is never exercised.
7. `scripts/lib/lint-rules.mjs:~176`. First H2 is found by a line scan, so a `## ` line inside a code fence before `## Steps` would fail a valid file. Unlikely today.

### Assessment
**Task quality:** Needs fixes. The brief is implemented faithfully and tests pass, but rule 6 silently skips any route row that is not in the bare form and `/kern:help check` depends on a truncated list.

Counts: Critical 0, Important 2, Minor 7.
