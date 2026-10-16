# Task 14 report: Guard G20, approvals that quote the user

Commit: `00d284e M2: add guard G20 so only the user's words approve a spec or plan` (on main, not pushed; 7 named paths).

## Implemented

- `hooks/guards/g20-approval.sh` (new): `guard_g20` for Write, Edit and Bash (Monitor is read as Bash by the dispatcher). Never votes allow.
- `hooks/lib/state.sh`: `prompt_hashes`, verbatim from the brief (djb2 mod 2^32 in awk under `LC_ALL=C`).
- `hooks/prompt-submit`: every UserPromptSubmit prompt that is not wrapped records `prompt_hashes: <hashes>` in session state. Deviation from the brief's `[ -n "$TRIM" ] &&`: it records in the `else` of the `wrapped` test, so an empty user prompt also replaces the last one's lines (contract: "rewritten on every user prompt that is not wrapped"). Without this, an empty prompt left the previous message's hashes standing as "the user's last message".
- `hooks/pre-tool-use`: `need state.sh prompt_hashes`; `KERN_GUARD_IDS` gains `g20`.
- `hooks/session-start`: `need state.sh prompt_hashes`.
- `CHANGELOG.md`: the brief's line under `## [Unreleased]`.
- `tests/hooks/g20.bats`: the brief's 20 tests, unchanged.

### Where the guard goes beyond the brief's code, and why

Each item closes a probe that got through the brief's version (probes listed below), except 7 and 11, which remove false denies.

Write and Edit:

1. Markdown names match in any case (`.Md`, `.mD`, `.MARKDOWN`). The brief matched `.md`, `.MD`, `.markdown`; on macOS an Edit of `export.Md` writes `export.md`.
2. A non-Markdown path that is a symlink reaching a Markdown name (up to 8 links) is checked, for Write, Edit and shell writes.
3. An Edit with an empty `old_string` is judged on `new_string` as the whole file (Claude Code creates the file that way). The brief returned early for a file that does not exist.
4. Edit matching follows Claude Code's Edit: CRLF read as LF before `old_string` is matched (a multi-line `old_string` on a CRLF file matched nothing in the brief's awk, so no vote), and a curly-quote fallback when `old_string` is not found.
5. Frontmatter reading is never narrower than the consumers or a YAML parser: `status` and `approved` keys in any case, blanks around the colon, a trailing `# comment`, a BOM before the first `---`, blanks after a `---`. `ledger-open` and `plan-check` accept a strict subset of these.
6. The unchanged-approval test compares every `approved:` line, not only the first, so adding a second line to an approved file is checked. The quote still comes from the first `approved:` line (the brief's tests produce two `approved:` lines and expect approval).
7. The quote runs from the first to the last double quote on the line, so a user line that holds a double quote can be quoted whole.
8. A quote with no hash (blank, punctuation only, over 500 characters) never matches. In the brief, an empty quote hash matched an empty or missing `prompt_hashes` record (`*"  "*`), so `"..."` approved before any prompt was recorded.
9. The non-answer check also drops a final `?`, `,`, `;` or `:` (`maybe?`, `Sounds good,`). Hashing is unchanged.
10. Freshness: the draft must be strictly older than the state file. bash 3.2 compares whole seconds, so with the brief's `"$p" -nt "$sf"` a draft edited in the same second as the prompt passed.

Bash:

11. The brief's interpreter rule (`python`, `node`, `ruby`, `sh`, `bash`, `zsh` with `approved` and a `.md` argument) denied kern's own `bash ${CLAUDE_PLUGIN_ROOT}/scripts/task-review <ledger>.md N TREE ROUND compliant approved`, which execute-plan will run for every task. G20 now judges an interpreter only when it runs inline code (`-c`, `-e`, `--eval` and similar, `eval`, a `-` operand, or a script on stdin, such as a here-doc), and then denies when the command holds both `approved` and a Markdown name anywhere, here-doc bodies included. A script run by name is the brief's accepted limit, and `sh`/`bash` inline scripts are already split into their own commands by `git_words`.
12. In the brief, `python3 -c "...open('x.md','w')..."` and `python3 - <<'PY' ... PY` got through: the path was inside the code word or the here-doc body, never an argument ending in `.md`.
13. `perl -pi -e`, `perl -i.bak`, `perl -0777 -pi`, `sed -Ei`, `sed -ni`, `sed --in-place=.bak`: in-place is read from option clusters per tool, not from a literal ` -i`. `perl -pi` (the usual form) got through the brief's `*' -i'*` test. Clusters also tell the script operand from the files: `sed -i -es/draft/approved/ x.md` (attached script), BSD `sed -i ''`, `sed -E` (no value), `perl -Mstrict` (not in-place), `awk -v x=1 -i inplace`.
14. The word `approved` is matched in any case and after quotes and backslashes are taken out (`appro''ved`, `APPROVED`).
15. Wrappers are skipped (`sudo tee`, `env sed -i`) through `_cmd_words`.
16. Redirect forms `>|`, `&>`, `&>>`, `<>`, `>&file` and fd-prefixed forms.
17. Copy family widened to `ln`, `rsync`, `ditto`, `git mv`; `-t DIR`; a destination directory receives each source by its own name (`cp /tmp/export.md .kern/specs/` got through the brief, whose target was the directory). A relative `ln -s` source is read from the link's directory.
18. Any file word in a command that writes a Markdown file is checked for approved frontmatter, not only `cp`/`mv`/`install` sources: `cat p.txt > spec.md`, `tee spec.md < p.txt`, `dd if=p.txt of=spec.md`, and a two-step `mv` through a `.tmp` name.
19. `ed`, `ex`, `vi`, `vim`, `nvim`, `sponge` operands; awk programs that name a Markdown file (`print > "x.md"`) when the command holds `approved`.
20. With `approved` in the command, a destination built at run time is denied: a glob (`sed -i s/draft/approved/ .kern/specs/*`), a variable (`for f in ...; do sed -i ... $f; done`), and the commands `find -exec` and `xargs` run, with `{}` standing for the names.
21. `cd` is followed, so `cd .kern/specs && echo x >> export.md` resolves the approved file.

## Tests

macOS (bash 3.2 via `tests/run-bats`, BSD awk):

- `tests/run-bats tests/hooks/g20.bats`: 20/20.
- `tests/run-bats tests/hooks`: 1..483, 483 ok, 0 not ok, rc 0 (on the final code; includes the need-list, guard-id, prompt-submit and G16 suites).
- `tests/run-bats tests/scripts`: 1..188, 188 ok, 0 not ok (on the final code).
- `node --test 'tests/**/*.test.mjs'`: 77 pass, 0 fail.
- `node scripts/lint-skills.mjs`: `lint: clean`.
- `bash tests/hook-shape.sh`: `hook-shape: 8 cases passed`.
- `shellcheck -x -S warning` on `g20-approval.sh`, `state.sh`, `prompt-submit`, `pre-tool-use`, `session-start`: no output.

Ubuntu (`kern-ci:task17`, bash 5.2.21, mawk 1.3.4, repo mounted at /kern-repo): `tests/run-bats tests/hooks/g20.bats` 20/20 on the final code; the 35-probe file below also 35/35 (it exercises the awk octal BOM and curly-quote paths under mawk).

## TDD evidence

RED, before any implementation (tests written from the brief, guard absent): 1..20, 15 not ok, 5 ok. The 5 passing were the no-vote and approve-only tests (1, 2, 10, 12, 16), as the brief expected. Failures: 3 to 9, 11, 13 to 15, 17, 18 (no deny), 19 (`prompt_hashes: command not found`), 20 (dispatcher list). GREEN after implementation: 20/20 on macOS and Ubuntu.

## Self-review probes

A scratch bats file (not committed) ran 35 probes through the real dispatcher with `KERN_GUARDS=g20` and the real prompt-submit. All pass on macOS and Ubuntu with the final code. Probes that got through an earlier version of this implementation and were fixed: same-second draft edit before the flip (item 10), `ln -sf ../../p.txt spec.md` (item 17), `sed -i -es/draft/approved/ spec.md` (item 13).

Denied as intended:

- Two Edits: an invented quote added while draft, then `draft` to `approved`: denied (quote not a line of the last message). A real quote added while draft, then the flip: denied (draft changed after the message).
- `replace_all` (brief test 15); quote from an earlier message; a wrapped prompt records nothing (brief test 6); non-answers `sounds good`, `Whatever you think.`, `maybe?`, `Sounds good,`; a `"..."` quote with no prompt recorded and after an empty prompt; an empty prompt replacing a `yes`; a 600-character quote; first `approved:` line fake and a later one real.
- Frontmatter forms: `status:  approved`, `"approved"`, `'approved'`, `Status: Approved`, `status: approved # ok`, `status : approved`, `status:approved`; CRLF file with a multi-line `old_string`; CRLF Write; BOM; `---  ` with trailing blanks; Edit with empty `old_string` on a new file; `export.Md`, `x.MARKDOWN`; curly-quote fallback; a Write through `alias.txt -> spec.md`.
- Bash: `perl -pi -e`, `perl -i -pe`, `perl -pi.bak -e`, `perl -0777 -pi -e`; `python3 -c` and `node -e` with the path in the code; `python3 - <<'PY'`; `printf ... | tee`; `cat > new.md <<'EOF'`; `printf ... > x.md`; `sudo tee -a x.md <<<`; `env sed -i`; `bash -c`, `eval`, `$( )`; a path with a space; Monitor; from a prepared `p.txt`: `cp`, `cat >`, `tee <`, `dd`, `ln -sf`, `rsync`, `install -m`, `git mv`, two-step `mv`; `cp tmp/export.md .kern/specs/` and `cp -t`; glob, `find -exec`, `xargs`, `for` loop; `appro''ved`, `APPROVED`; to an approved file without the word: `>>`, `cd && >>`, `truncate -s 0`.

No vote, as intended: `grep -rn approved spec.md`; `sed -n '/approved/p'`; `awk '/approved/'`; `cat | grep approved`; `git commit -m 'export.md approved'`; `git log --grep approved -- spec.md`; `find -exec grep -l approved`; `bash $K/scripts/task-review <ledger.md> ... compliant approved`; `bash $K/scripts/ledger-open spec.md`; `echo hi >> notes.md`; `sed -i s/a/b/ notes.md`; `node scripts/build.mjs docs/x.md --approved`; `cp README.md docs.md`; re-approval of an approved file with a fresh real quote; a user line holding double quotes quoted whole; a second frontmatter block (not read by G20, and `ledger-open` refuses the file).

## Concerns and accepted limits

1. `ledger-open` accepts a plan at any path and extension. G20 guards Markdown names only, so a Write of `plan.txt` with `status: approved` and an invented quote, then `ledger-open plan.txt`, opens a ledger. The brief's "accepts one at any path because G20 now guards them all" holds only for Markdown names. Suggested follow-up (outside this task's files): `ledger-open` refuses a plan whose name is not `.md`/`.markdown`, or G20 covers every extension.
2. G20 depends on `wrapped()` in prompt-submit (M1). Any non-user prompt it misses becomes "the user's last message", and its lines can be quoted. Probe P31: a teammate message preceded by a `<system-reminder>` block is recorded, and a quote of its `ship it` line approves. The M1 spike saw wrappers at the start of the prompt, so this is a dependency, not an observed hole.
3. Approval by AskUserQuestion does not work: its answer is a tool result, not a prompt, so no hashes are recorded and the quote is denied. Skills must ask for the yes as a typed message.
4. The approval does not bind content. An approved file whose `approved:` lines stay the same can be rewritten freely, by Edit or by a whole-file Write (brief test 16 requires the body-edit case). A Write of a new file has no freshness check, so `rm spec.md` followed by a Write of a new approved spec quoting a real yes passes (probe P23). The approval edit itself may also change the body.
5. djb2 is not a cryptographic hash. A quote crafted to collide with a line of the user's message would pass. The contract fixes djb2; the guard targets a sloppy approval, not an adversarial one.
6. The non-answer list is exact after normalization: `sounds good to me` or `ok sounds good` are not on it.
7. Not seen (accepted, the brief's "hides the path or the word" class): a script run by name; a word built at run time (`appr$x`, `$'\x61pproved'`, an awk program that builds the word); a recursive directory copy (`cp -r prep/ .kern/`); `git checkout`/`restore`/`apply`, `patch`, `curl -o`, `tar`/`unzip`; package runners (`npx`, `uvx`, `uv run`) in front of an interpreter; hard links (`ln spec.md notes.txt`, then a Write of `notes.txt`); Bash writes through a dynamic path when the command lacks `approved`.
8. False denies, accepted: an interpreter with inline code in a command that also holds `approved` and a Markdown name, readers included (`perl -ne 'print if /approved/' spec.md`, `python3 -c ... spec.md approved`; the brief's own interpreter rule denied these too; `awk '/approved/' spec.md` passes); `perl -Mfeature=...` read as in-place or inline; a write of a Markdown file in a command that also names an approved file (`grep x approved-spec.md > counts.md`); a quoted `">"` word read as a redirect.
9. The guard is 575 lines, a little larger than G16 (479). Per-call cost on macOS is under 0.2 s including dispatcher start-up, measured on three sample commands.

## Fix report 1: ledger-open accepts only a Markdown plan (lead ruling on concern 1)

Commit: `0cafbc2 M2: ledger-open accepts only a Markdown plan` (named paths: `scripts/ledger-open`, `tests/scripts/ledger.bats`, `hooks/guards/g20-approval.sh`; not pushed; no CHANGELOG line, since `scripts/` is outside the CHANGELOG rule and the hooks change is comment-only).

Changes:

- `scripts/ledger-open` exits 2 and writes nothing when the plan's name is not Markdown. It also exits 2 when the file a symlinked plan names (followed up to 8 links) is not Markdown, or when its frontmatter `spec:` value is not Markdown. Markdown means `.md` or `.markdown` in any case, exactly as G20's `_g20_md` reads it. `spec: none` and a missing `spec:` line are still accepted. `tests/scripts/ledger.bats` builds its approved plans with `spec: none`, and Task 34's planned `no-commit-review.bats` does the same, so refusing `none` would break both. `none` names no file.
- The default ledger slug now drops the extension whatever its case: `Upper.MD` gives `upper`, not `upper-md`. `.md` plans get the same slug as before.
- G20's header comment states its accepted limits: the dependency on `wrapped()`; an AskUserQuestion answer is not recorded and cannot approve (define and plan ask for a typed reply); approval does not bind content (rewrite of an approved file, a body change in the approval edit, rm plus a new Write); djb2 collisions; shell writes that hide the path or the word. It also notes that ledger-open now runs only Markdown plans.

TDD: two new tests in `tests/scripts/ledger.bats`.

- "refuses a plan or a spec: line that is not a Markdown name, and writes nothing": `plan.txt` carrying `status: approved` and an invented quote `"ship it"`, run with a fresh DIR and with the default DIR; `link.md -> plan.txt`; a `plan.md` whose `spec:` is `WORK/specs/export.txt`.
- "takes a Markdown name in any case, and spec: none": `Upper.MD`, and `spec: WORK/specs/export.Markdown`.

RED: both failed. The first failed at its first assertion: `plan.txt` was accepted with exit 0. The second failed on the slug `upper-md`. GREEN: `tests/run-bats tests/scripts/ledger.bats` 1..18, 18 ok. `tests/run-bats tests/hooks/g20*.bats` 20 ok. `shellcheck -x -S warning scripts/ledger-open hooks/guards/g20-approval.sh` gives no output. No other test calls ledger-open.

## Fix report 2: review round 1 (C1, I2, I3 and minors)

Commits (main, not pushed, named paths, no trailers):

- `5aae040 M2: G16 denies running kern's hooks or calling its state functions`: `hooks/guards/g16-state.sh`, `tests/hooks/g16-state.bats`, `CHANGELOG.md` (new G16 line).
- `1564141 M2: G20, ledger-open and plan-check read frontmatter one way`: `scripts/lib/frontmatter.awk` (new), `hooks/guards/g20-approval.sh`, `scripts/ledger-open`, `scripts/plan-check`, `tests/hooks/g20.bats`, `tests/hooks/g20-probes.bats` (new).

### C1: one frontmatter reader

`scripts/lib/frontmatter.awk` defines `fm_delim(s, first)`, which is the one `---` rule: a trailing CR and trailing blanks are dropped, and on the first line a UTF-8 BOM is dropped too. With `-v fm_print=1` the file prints the frontmatter lines, CR dropped, and exits 3 when the block opens and never closes. The three readers:

- G20 runs it with `-f` on the Write content, on the Edit result (its Edit model, `_G20_EDIT_AWK`, now only produces the post-edit text) and on the current file. If the reader cannot run (any exit other than 0 or 3), G20 fails closed (G0 ask).
- ledger-open runs it with `-f`: exit 3 is "frontmatter not closed", any other failure is exit 2.
- plan-check prepends the file to its main awk program, which uses `fm_delim` for its open and close rules. Its `spec:` lookup goes through the reader too.

A side fix: plan-check's `spec:` sed now uses `[[:blank:]]`. BSD sed read `[ \t]` as space, backslash or `t`.

Ruling followed: a `---  ` or `---\r` line closes the block for all three. On the review's probe files, none of the three reads `status: approved`: G20 gives no vote, ledger-open refuses with `status: none` and writes nothing, and plan-check reports `plan status is draft or approved, not ""`. The forgery is closed because ledger-open no longer reads further than G20. The forged Write is not itself denied, because under the agreed rule it approves nothing. A third test covers the opposite case. With an opener `---  ` and the status line inside the block, G20 denies the Write, and ledger-open, given the same file written directly, reads it as approved too.

### I2: shell writes judged on every line

`_g20_holds FILE` is true when any line of FILE matches the `status: approved` pattern, frontmatter or not. A Bash write to a Markdown target is denied when the target holds such a line, or when any file the command names does (this replaces the frontmatter-only check for targets and sources). Accepted cost, named in the ruling: shell writes to documents that show `status: approved` in an example are denied, and so is copying from them.

### I3: G16 denies running kern's hook code

`_g16_hooks` runs for every Bash command whose text, in any case, with quotes and backslashes removed, could name hook code or a state function. Text that cannot is not lower-cased, which keeps G16's cost test green. Each simple command is parsed, including `bash -c`, `eval` and `$( )` bodies. The vote is deny in both modes when any of these holds:

- a simple command whose name is not a reader names a hook file by its tail: `prompt-submit`, `session-start`, `subagent-start` or `pre-tool-use`, bare or after `/`; anything under `hooks/lib/`; or `lib/<kern lib>.sh` after a `cd` into `hooks`;
- a simple command's name is `state_set`, `_state_put` or `state_reset`;
- a reader names a hook file and the same command also runs `sh`, `bash`, `zsh`, `dash`, `ksh`, `fish`, `source`, `.` or `eval` (`cat hooks/prompt-submit | bash`).

The readers are cat, head, tail, less, more, grep, rg, ls, stat, wc, file, diff, cmp, echo, printf, test, git, shellcheck, shfmt, bat, nl, od, xxd, hexdump, strings, checksum tools, basename, dirname, realpath, readlink, cd, `sed` without in-place, and `find` without `-exec`, `-ok` or `-delete`. They get no vote, so kern development (`shellcheck hooks/...`, `git add -- hooks/...`, `tests/run-bats tests/hooks/pre-tool-use.bats`) is not blocked. A shell edit of a hook file (`sed -i ... hooks/pre-tool-use`) is denied.

Limits: a path or a function name built at run time, and a hook path inside interpreter code (`python3 -c "subprocess.run([... 'hooks/prompt-submit'])"`), are not seen.

### Minors

- `tests/hooks/g20-probes.bats`: the 37 self-review probes (P1 to P35 with P1b and P6b), made portable (no `sed -i ''` in setup, `cd "$R"`). The echo-only probes now assert: P17's two-step mv denies, P26 denies. P23, P31 and P35 assert accepted limits and are named as such, and P34 asserts the accepted perl false deny. Then one test per finding: C1 x3, I2 x2, I3 x2 (run with `g16`), N1 to N3. g20.bats stays at the brief's 20.
- g20.bats "other files and draft edits get no G20 vote" now creates `notes.md` holding `status: draft` and no frontmatter, so the Edit reaches the guard's Edit model and reader.
- Negations added to the non-answer list: `no`, `nope`, `not yet`, `wait`, `stop`, `don't`, `do not`. A right single quote is read as an apostrophe (`Don’t`), mapped through an ANSI-C escape because lint rule 11 rejects curly quotes in source.
- An Edit whose `old_string` G20's model cannot find (exact, then with curly quotes straightened), or an Edit of a file that does not exist, is denied when `new_string` holds a `status:` or `approved:` line: "old_string is not in X as G20 reads it ...". Other Edits it cannot place get no vote.
- The freshness message is now "X changed after the user's last message; set status and approved: in one edit, on a draft unchanged since the user's yes, so ask for the yes again". I added the second half to the required phrase: once the file is newer than the state file, a one-edit retry is still denied until the user writes again, so the message has to say to ask.

### RED and GREEN

RED is the run before any fix in this round (`tests/run-bats tests/hooks/g20-probes.bats`: 1..47, 37 ok, 10 not ok; `tests/run-bats -f "kern's hook code" tests/hooks/g16-state.bats`: 1..2, 1 not ok).

| Test | RED (before) | GREEN |
| --- | --- | --- |
| C1 `---  ` closer | G20 no vote; ledger-open opened a ledger (exit 0) | all three read no approval |
| C1 `---\r` closer | same as above | same |
| C1 `---  ` opener | ledger-open refused (status: none) while G20 denied | G20 denies, ledger-open reads it as approved |
| I2 `sed -i '' 3d p4.md` | no vote | deny, "p4.md holds a status: approved line" |
| I2 `tail -n +2 staged.md > p5.md` | no vote | deny, "staged.md, which holds a status: approved line" |
| I3 prompt-submit forgery (G16) | no vote | deny, "kern G16: kern's hooks run only from Claude Code ..." |
| I3 `bash -c '. hooks/lib/state.sh; state_set ...'` (G16) | no vote | deny, same reason |
| g16-state.bats: 15 run/source/call forms, and under autopilot | no vote on the first | all deny |
| g16-state.bats: reads and test runs not denied | passed (no rule yet) | passes |
| N1 negations | `no` approved (no vote) | all 8 deny "is not an explicit yes" |
| N2 old_string not found | no vote | deny; a plain unplaced Edit still no vote |
| N3 message | old message | new message |
| P1 to P35 (37 tests) | pass (they probe the code already committed) | pass |
| g20.bats test 10 fix | passed vacuously | passes, now judged by the guard |

Final runs (macOS, bash 3.2): `tests/run-bats tests/hooks` 1..532, 532 ok, rc 0. `tests/run-bats tests/scripts` 1..190, 190 ok. `node --test` 77 pass, 0 fail. `node scripts/lint-skills.mjs` clean, after replacing the curly apostrophe that first failed rule 11. `bash tests/hook-shape.sh` 8 cases passed. `shellcheck -x -S warning` on g16-state.sh, g20-approval.sh, ledger-open, plan-check, state.sh, prompt-submit, pre-tool-use and session-start gives no output.

Ubuntu (`kern-ci:task17`, bash 5.2, mawk): g20.bats 20/20, g20-probes.bats 47/47, g16-state.bats 35/35, ledger.bats 18/18, plan-check.bats 25/25, shellcheck clean.
