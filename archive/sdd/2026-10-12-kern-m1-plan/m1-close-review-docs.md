# M1 close review: kernel, skills, scripts, docs (92cecaa..d322e19)

### Spec Compliance

Commands run: `node --test tests/*.test.mjs` 69/69 pass; `node scripts/lint-skills.mjs` clean; `node scripts/check-version.mjs` agree; `node scripts/route-eval.mjs` passed.

- ✅ Routing rows and rule 6: kernel.md:13-14 use the bare `Read {KERN}/...` and `Read {ROOT}/...` form lint-rules.mjs:173 requires; both targets open with `## Steps` and `1.`; map.md lists every user-reachable skill, `hello` exempt with a reason.
- ✅ Rule 7: rendered kernel 3,562 chars with long-settings and 3,125 with none, both with the root normalised; plus terse.md, 5,238, under 9,000; subagent kernel 684 plus 147 for the terse line, under 1,200.
- ✅ Rule 13: every key the code reads is in the table. The Read-by column drifts from the code; see Minor 2.
- ✅ Rule 15: the eight fixture dirs match lint-rules.mjs:256 and hook-shape.sh.
- ✅ Versions: plugin.json and marketplace.json say 0.1.0; the heading renders from plugin.json (render.sh:29-31), so nothing hardcodes it. The normalisation paths in lint-rules.mjs:206 and session-start.bats:32 say `0.1.0`, Task 18 Step 1 says `0.2.0`. They are the same length, so this is harmless.
- ❌ CHANGELOG draft: Important 3. ❌ NOTICE map: Minor 8. ❌ Task 18 Step 4: Important 4.
- ⚠️ The status-line snippet's fallback `~/.claude/plugins/data/kern-kern` (fix-a-run.md:18) is unverified under `--plugin-dir`.

### Strengths

The kernel, mode and autopilot skills match the hooks on the points that matter for safety. Only a typed command turns autopilot on. G16 denies state writes. Under autopilot, merge, deploy, review posts and tracker writes are denied: g14-tracker.sh:98 never allows under autopilot, and g03 denies. The skill's commit, push and draft-PR shapes match G5, G1 and G2's own retry text. Help check now reads the files instead of the capped block.

### Issues

**Critical:** none.

**Important**

1. **G5 checks no convention in the default setup path.** settings.md:42 gives `commit.convention` the default "detected from `git log`", read by G5. Skills spec A5 (m1-m2-skills.md:94) says the same. g05-commit.sh:288 reads `settings_get commit.convention ''` and skips the check when the key is unset, and no hook calls kern-detect. Help setup writes detected values "only where detection guessed wrong" (help SKILL.md:22). So a project whose convention detects correctly ends up with no G5 convention check. autopilot SKILL.md:21 and prompt-submit:185 still promise commits "when the message passes the convention ... checks". Fix: setup always writes `commit.convention`, since a guard reads it, or G5 runs the detection. Then change the default cell to say what G5 does when the key is unset.

2. **The guard reference users are sent to is stale, and "auto" is overstated.** fix-a-run.md:9 says each guard's rule is in design 8.3. Three of its rows contradict the code:
   - design:408 G13: "Copies to and mutating SQL ... denied". The shipped G13 denies every unproven call that names a target: ssh commands off the read list, curl, nc and sftp writes (g13-protected.sh:1-9).
   - design:409 G14: "MCP write calls ask". It omits gh issue and label writes, the `tracker.policy: auto` allowlist, and GitHub MCP writes always asking (g14-tracker.sh:21-32).
   - design:400 G1 omits the proven-shape allow, the ask for aliases and git extensions, and the ask for a hidden git. Its lease rule says "own branches in the current stack". g01-git.sh:603-611 allows only the current branch.

   In the same way, settings.md:39, :45-47 and :57, and fix-a-run.md:9 ("changes ask to auto"), never say that auto covers only the proven shape. A user who sets `tracker.policy: auto` with the GitHub MCP is asked every time and finds no explanation in the docs. Fix: add a short "what auto and autopilot allow" table to settings.md, point fix-a-run there or at contract.md:100-115, and refresh the G1, G13 and G14 rows in design 8.3.

3. **The CHANGELOG draft (plan:5389-5394) does not describe what M1 shipped.** "Guards G1 to G6, G13 to G16" is the only guard line. It leaves out:
   - the proven-shape allow model;
   - G13's read-only model, which denies in both modes;
   - G14's per-family allowlists, GitHub MCP writes always asking, and deletes always asking;
   - Task 9a and 12a: a hidden git or gh behind a wrapper asks;
   - the own-command list, which makes git aliases and extensions ask;
   - known limits: shell-snapshot aliases (`gpf!`, `grhh`) hide git from every guard (ledger:266), `GIT_CONFIG*` environment assignments, ANSI-C quoting, interpreters, and the open G13 adversarial review (ledger:344).

   Also, release.mjs:23-28 moves the whole Unreleased block, so CHANGELOG.md:7 "M0 accepted" becomes a 0.2.0 note. Fix: add those bullets and a known-limits bullet, and move the M0 line under 0.1.0.

4. **Task 18 Step 4 would break the fail-closed path (plan-mandated).** plan:5358 says to insert `PERMISSION_MODE=...` and `export PERMISSION_MODE` "after the `CWD=` line". That places them between pre-tool-use:28 and `cwd_rc=$?` at :29, so `cwd_rc` reads export's 0. A malformed `cwd` then stops failing closed, and an absent one leaves `CWD` empty. The step's "17 tests" is stale, since g01-git.bats has 54. The Files list (plan:5322-5323) also omits hooks/pre-tool-use and the test file. Fix: insert after pre-tool-use:30, expect 55 tests, and list all three files.

**Minor**

1. render.sh:61 points the cut `Set:` entries to `/kern:help check`, but Check (help SKILL.md:32-38) validates keys and never prints values. Point to `bash {ROOT}/scripts/kern-get <key>`, or have Check list the resolved values.
2. Read-by drift in settings.md:
   - `work_dir` omits G2 and G5 (g02-pr.sh:249).
   - `base_branch` names G6, which never reads it, and omits G5 (g05-commit.sh:354 through `branch_protected`). `branch.protected` and `deploy.envs` also omit G5.
   - `autopilot` names five guards, but the dispatcher applies it to every guard (pre-tool-use:36, decide.sh:43).
   - The `branch.protected` default reads as a value that a setting replaces. gitctx.sh:390-400 always adds the base branch and `deploy.envs`, and protects main, master, trunk and develop when the base branch is unknown.
3. kernel.md:19 says "Never without the user's word", which implies the user's word unlocks these actions. G1 denies a plain force push, and a lease push over other authors' commits, in both modes (g01-git.sh:547, :599). G13 denies in both modes too. Add one line: kern denies these outright, so hand the user the command to run with `!`.
4. autopilot SKILL.md:25 allows a lease push to `<branch>` "only to your own branches". Under autopilot G1 allows only the current branch, and its own reason text says `<current-branch>`.
5. prompt-submit:185, the line that prints on every prompt under autopilot, omits the allowed shapes: `-m` or `-F` only, a named remote and branch, no wrapper and no `cd`. It also says "the human" where the kernel and the skill say "the user". After `/compact` this line is the only rule left, so Claude's default here-doc commit is denied once per commit. Spec-mandated (B2.5).
6. mode SKILL.md:23 says "A phrase that opens the prompt also switches". `go terse for the rest of this session` and `be terse from now on` switch nothing and print nothing (`_nl_ok`, prompt-submit:131). State the real rule: the phrase alone, or followed by punctuation, "and", "then", "now" or "please".
7. settings.md:79 and kern.local.yml:41 say G13 "allows only proven reads". G13 never votes allow: a proven read gets no vote. Write "lets through".
8. NOTICE file map gaps:
   - skills/help/SKILL.md and references/fix-a-run.md adapt pstack poteto-help. They reuse its sentence "Check the state that changes the answer, and mention it only when it does", its multiple-choice opener and its "Fix a run" table (.upstream/pstack/pstack/skills/poteto-help/SKILL.md:17-25, :128).
   - check-version.mjs:3 and lint-rules.mjs:2 credit addy in their headers, and the map does not list them.
   - NOTICE:22-24 says files changed from caveman sources say so in their first lines. Neither mapped caveman file does, because neither copies caveman text. Say that no caveman text is copied.
9. Task 18 Step 5 item 4 (plan:5380) cannot detect a missing exclude for kern.local.yml. Step 2's settings.local.json already shows as `?? .claude/` in `git status --porcelain`, so a new untracked file inside `.claude/` adds no line. Check with `git check-ignore -q .claude/kern.local.yml` instead.
10. Design drift:
    - §14 lists M1's guards as "G1 to G6 and G14 to G16", without G13.
    - §6.1's preset "/kern:mode terse = terse + chat" contradicts B1 and prompt-submit:41-42, where each word sets one axis.
    - plan:3381 says a body file must be "tracked-or-.kern", and plan:3751 says ".kern dir". The code uses `work_dir` and also accepts untracked files that git does not ignore.
11. Prose against unslop:
    - Parentheses outside code break unslop:76: settings.md has 30, help SKILL.md 19, kernel.md 10 and fix-a-run.md 7. Ruling 358 enforced the same rule on unslop itself.
    - Semicolon chains, against technical-writing:95: kernel.md:6, settings.md:52 and map.md:3.
    - Stacked colons: help SKILL.md:14 ("an unclear need: ask one multiple-choice question: set up ...").
    - Passive voice: autopilot SKILL.md:28 ("Judgment calls are parked").
12. Help check reports unknown keys but not invalid values. `push.policy: atuo` silently reads as ask (settings.sh:136-139). Compare each value with the Values column.

### Assessment

**Task quality:** Needs fixes. The text and the code agree on what autopilot denies. They disagree on what G5 checks by default, on what auto allows, and on which guard rules the user is told to read. The release notes and Task 18 Step 4 also need correcting before 0.2.0.
