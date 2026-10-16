# M1 fix wave B report (saved by the controller from the implementer's parts)

## Part 1

DONE_WITH_CONCERNS. Commits: 91a0160 (settings: what auto allows, union lists, Read-by; kernel denies), 1e43b77 (skills: phrase rule, lease on current branch, check values, prose), b2d99a2 (NOTICE credits help and addy files; design 8.3 G1, G13, G14 rows). After each: lint clean, node 69/69, session-start 9/9; also hook-shape 8, settings.bats, route-eval. No test pinned changed text.
- Imp 2: settings.md section "What auto and autopilot allow" (9 rows: commit, push, lease push, draft PR, review post, gh issue/label, Linear MCP, Notion MCP, GitHub MCP always asks) plus the whole-call rule, what `<file>` means, other guards still vote, deletes/chat/floor never covered; the policy paragraph says other values read as ask, auto = those shapes only, deny denies in both modes; first cells are plain words so settings_known_keys and rule 13 skip them. fix-a-run points there and to contract.md. Design 8.3 G1, G13, G14 rows rewritten from the code.
- Minor 2: Read-by fixed (work_dir adds G2, G3, G5, G14; base_branch G1, G5; branch.protected G1, G5 with the real default; deploy.envs G1, G5, G15; autopilot read by pre-tool-use for every guard); wave A's I3 union and the G5-detection default written in.
- Minor 3: kernel Autonomy: "Even with that word, kern denies a plain force push, a lease push unless every commit is the user's, and a call to a protected target it cannot prove is a read. Give the user the command to run with `!`."
- Minor 4: lease push only `<current-branch>`, unprotected, own commits.
- Minor 6: mode Words states the real phrase rule with two examples.
- Minor 7: "lets through" in settings.md and the template.
- Minor 8: NOTICE map rows for help SKILL.md and fix-a-run.md (poteto-help), check-version.mjs and lint-rules.mjs (addy); no caveman text is copied.
- Minor 10: design §14 lists G13 to G16; §6.1 presets replaced by B1's one-word-one-field rule.
- Minor 11: parentheses outside code removed in kernel.md, settings.md, help SKILL.md, fix-a-run.md, map.md, autopilot SKILL.md; routing header "Observable trigger"; semicolon chains split (kernel Precedence a numbered list); stacked colons fixed; passive voice made active.
- Minor 12: help Check compares values with the Values column and names a misspelt policy reading as ask.

## Part 2

Claims checked against code (file:line per guard: G1 g01-git.sh:547, :552, :556, :588-590, :597-599, :602, :483-512, :406-418, :610, :616-623, asks at :303-358, :216, :82; G2 g02-pr.sh:291, :308-315, :242-260; G3 g03-review.sh:51, :58, :119, :139; G5 g05-commit.sh:281-302, :321-358, :377, :391-393; G6 g06-secrets.sh:227, :257; G13 no `vote allow`, network clients :515; G14 g14-tracker.sh:29, :32, :128-131, :171-177, :210-213, :223-250; decide.sh:43-46; pre-tool-use:36; settings.sh:53 union, :146 policy_for; state.sh:77-94; gitctx.sh:393; prompt-submit:111-132; work_dir readers through _gh_file_ok).
Kernel size (root normalised): 3,795 chars with long-settings (3,574 before), 3,348 with none; no rule 7 warning.
Concerns: (1) settings.md's commit.convention cell describes wave A's G5 detection, not yet in g05 at b2d99a2; (2) an added Review post row, checked against g03; (3) fix-a-run points to docs/plans/contract.md, a plan file; (4) not ruled, left: design §4.3 "When (observable)", §6.1 storage line (.json, mode.default vs .state, mode.voice, mode.surface), mode SKILL step 3 and template parentheses, the autopilot commit line omits G5's ticket-id check; (5) kernel.md:2 keeps its semicolon (session-start.bats:21 pins it), lines 31 and 34 keep two-clause semicolons.

## Final rider: e5f6257

"asks or denies" in settings.md (policy paragraph, auto/autopilot intro, lease row); `<file>` says not a symlink (g02-pr.sh:246); kernel Autonomy trimmed with every rule kept, floor sentence "Only on the user's word this session: <same 5 actions>. kern denies plain force pushes, lease pushes unless every commit is the user's, and protected-target calls not proven reads. The user runs those with `!`."; kernel.md :31 and :34 semicolons removed (line 2 pinned); fix-a-run "and its rule is in". Autonomy 650 chars as a template, 642 rendered; Precedence 429 -> 414 (F9 budget 420); rendered kernel 3,618 with long-settings, 3,153 with none. Lint clean, node 69/69, session-start 9/9. Autonomy merges "Before asking, check if a command answers" into "Escalate product and preference calls no command answers".
