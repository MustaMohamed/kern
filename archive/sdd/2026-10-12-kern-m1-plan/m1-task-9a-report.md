# M1 Task 9a report: splitter and G16 hardening

Status: DONE_WITH_CONCERNS

Commit: `e660754 M1: harden the command splitter and G16 against common shapes` (on `main`, parent `0a39bfa`, not pushed, no trailers). It holds only the four files the brief names, staged with `git add --`.

## What I did

The brief has no code, so I designed the change and wrote the tests first.

1. Wrote 11 new tests: 7 in `tests/hooks/gitctx.bats` and 4 in `tests/hooks/g16-state.bats`. I also added cases to 2 existing G16 tests: the scratchpad no-vote test and the settings ask test.
2. Ran them against HEAD and saw RED for the expected reasons. I also ran each new G16 command through the dispatcher with a scratch probe, because `expect_bash` stops at the first failing command.
3. Changed `hooks/lib/gitctx.sh` and `hooks/guards/g16-state.sh`, and got GREEN.
4. Self-review found 2 regressions in my own first version. I added a test for each, saw both fail, fixed them, and saw GREEN (details under "Self-review fixes").
5. Ran shellcheck, the lint, the whole suite and the timings, then committed.

### Design, by brief item

**1. G16 Bash reader allow-list (`g16-state.sh`)**
- `_g16_bash` starts from "write". It clears that only for these heads: `cat head tail less more grep egrep fgrep rg ls stat wc file diff cmp jq`, `sed` or `perl` with no `-i`, `--in-place` or `-i<suffix>`, `cd` and `pushd`, and a segment with no command name. The head is the first word `_cmd_words` prints.
- A non-reading head whose words include a state word sets the deny. One whose words include a settings word sets the ask.
- The existing redirect pass (`_g16_redirects`) still runs for every head, so a redirect into a state or settings word counts whatever the head is.
- `_g16_kind` classifies a lower-cased word as a state word when any of these holds:
  - The word holds the sessions dir path. This is a contains-match, as at HEAD, so `of=<dir>/x` counts.
  - The word holds `sessions` and ends in `.state`.
  - The word is `<sid>.state`, or ends in `/<sid>.state`.
  - Once a leading `~`, `$home`, `${home}`, `$claude_plugin_data` or `${claude_plugin_data}` is expanded, the word holds the sessions dir, or it is an absolute glob that matches the state path in `case "$sd/$sid.state" in $e)`. The lower-cased spellings are needed because the command is lower-cased before the check.
- A settings word ends in `.claude/kern.yml` or `.claude/kern.local.yml`, or is exactly `kern.yml` or `kern.local.yml`.
- The prefilter `_g16_names` now passes any command that contains `sessions`, `.state`, `kern.yml` or `kern.local.yml`, or names `$sd`.
- `cd`/`pushd` sets the in-sessions-dir flag from its target, and a `cd` elsewhere clears it. While the flag is set, every non-reading command and every redirect counts as a state write, as at HEAD. There is no cd-ancestor tracking.

**2. Redirections glued to words (`gitctx.sh`)**
- In `_shell_words`, an unquoted `<`, `>` or `&>` now starts a new word. The exceptions: it does not when it follows an fd number or another operator character. So `main>/dev/null` gives `main` and `>/dev/null`, `b&>c` gives `b` and `&>c`, `d<<EOF` gives `d` and `<<EOF`, and `2>&1` stays whole.
- `push_targets` maps `@`, like `HEAD`, to `current_branch`.

**3. Wrapper option tables (`_cmd_words`)**
- `_cmd_words` is now an awk `word()` function with an `opt` table:
  - sudo: `-C -D -g -h -p -R -r -T -t -U -u`
  - env: `-C -P -S -u`
  - exec: `-a`
  - timeout: `-s -k`
  - nice: `-n`
- `timeout` skips its duration after its options. `nice -N` is a plain flag.
- The value of `env -S` is split on blanks and fed back through `word()`, so `env -S "git push origin main"` reads as `git push origin main`.
- The shell pass in `git_words` now handles these:
  - `-o`, `+o`, `-O` and `+O` take a value.
  - Any `-[a-z]*c[a-z]*` word is the script flag, so `-cx` and `-lc` both work.
  - Other `-` and `+` flags are skipped.

**4. Here-doc bodies (`_split_words`, `git_words`)**
- `_split_words` queues the delimiter of each `<<WORD`, `<<-WORD`, `<<'WORD'` and `<<"WORD"`. It ignores `<<<`.
- This happens at the top level, unquoted inside `$( )`, and inside `"$( )"`.
- At the next newline that ends a command line, it finds each closing line, stripping leading tabs for `<<-`.
- At the top level, the body and the closing line are dropped.
- Inside `$( )`, the body is dropped but the closing line is kept. So when `_subst_bodies` hands the body back to `git_words`, it splits the same way again: the here-doc is now empty.
- A here-doc with no closing line skips nothing. So a misread `<<` cannot hide the commands after it. Examples are `$((1 << 2))` and an unterminated here-doc.
- Records keep newline as their separator. A newline inside one record is printed as byte `\037` (`_GW_NL`).
- `_shell_words` treats an unquoted `\037` as a blank. A quoted one stays inside its word.
- `git_words` turns `\037` back into a newline before it splits a `$( )` body, a `-c` script or `eval` arguments again. This choice keeps every existing `${lines[n]}` test and every planned `while read` caller working unchanged.

**5. Cost**
- `_subst_bodies` runs only when the record contains `$(` or a backtick.
- The wrapper pass (`_cmd_words` plus awk, two processes) runs only when the first word fits one of these, after its quotes are removed and on any path: an assignment, a keyword, `eval`, a wrapper (`command exec time nohup sudo env timeout nice`), or a shell (`sh bash zsh dash`).

## TDD evidence

### RED against HEAD (`0a39bfa`)

Command: `tests/run-bats tests/hooks/gitctx.bats tests/hooks/g16-state.bats`

```
1..43
not ok 4 git is seen behind wrapper options, env -S, shell options, timeout and nice
#   `finds "$c" push' failed
# no git push in: exec -a x git push origin main
not ok 5 the commit form with a here-doc message gives one git segment, and the message is data
#   `[ "${lines[1]}" = "cat <<'EOF'" ]' failed
not ok 6 here-doc bodies are skipped, and the commands after them are still seen
#   `[ "${lines[1]}" = "git status" ]' failed
not ok 7 a quoted multi-line argument stays in its record
#   `[ "${#lines[@]}" -eq 2 ]' failed
not ok 8 a 1,000-line here-doc runs through git_words in under a second
# took 8.585 s
not ok 16 _shell_words splits a redirection from the word before it
not ok 17 push_targets: a redirection glued to the branch, and @
# origin main>/dev/null -> main>/dev/null
not ok 29 any command but a reader that names a state path is denied
# cd ~/.claude/plugins/data/kern-kern && sed -i '' s/off/on/ sessions/*.state ->
not ok 30 a glob that matches the state file once ~ is expanded is denied
# echo autopilot: on > ~/.claude/p*/d*/k*/s*/*.state ->
ok 31 a double-quoted state target is denied
not ok 32 reads of a state file, and a commit message naming one: no vote
#   `[ "$(decision_of "$output")" = none ]' failed
not ok 42 a write to a kern settings file asks, and denies under autopilot
# cd .claude && sed -i '' s/ask/auto/ kern.yml ->
```

The other 32 tests passed, and all of them existed before this task.

A per-command probe through `hooks/pre-tool-use` on `/bin/bash` (a scratch script; `$S` is the sessions dir), at HEAD:

```
none  cd ~/.claude/plugins/data/kern-kern && sed -i '' s/off/on/ sessions/*.state
none  cd $CLAUDE_PLUGIN_DATA && echo autopilot: on > sessions/*.state
none  rsync /tmp/x $S/a.state
none  curl -so $S/a.state file:///tmp/x
none  ditto /tmp/x $S/a.state
none  cd .claude && sed -i '' s/ask/auto/ kern.yml
none  cat|grep|ls|sed -n of $S/a.state          (4 commands, each none)
none  tee <scratchpad>/sessions.md
none  echo x > <scratchpad>/test-session.state.txt
deny  echo on > "$S/test-session.state"
deny  commit form, state path in the message
none  echo autopilot: on > ~/.claude/p*/d*/k*/s*/*.state (state dir under HOME)
```

Every brief deny and ask case gave no vote at HEAD, and the commit-form case was wrongly denied. The read and scratchpad cases were already right at HEAD, so they are regression guards only.

### GREEN

Command: the same two files.

```
1..43
(43 ok, no not ok)
```

Probe after the change:

```
deny  cd ~/.claude/plugins/data/kern-kern && sed -i '' s/off/on/ sessions/*.state
deny  cd $CLAUDE_PLUGIN_DATA && echo autopilot: on > sessions/*.state
deny  rsync /tmp/x $S/a.state
deny  curl -so $S/a.state file:///tmp/x
deny  ditto /tmp/x $S/a.state
ask   cd .claude && sed -i '' s/ask/auto/ kern.yml
none  cat|grep|ls|sed -n of $S/a.state
none  tee <scratchpad>/sessions.md
none  echo x > <scratchpad>/test-session.state.txt
deny  echo on > "$S/test-session.state"
none  commit form, state path in the message
deny  echo autopilot: on > ~/.claude/p*/d*/k*/s*/*.state (state dir under HOME)
```

### Self-review fixes (test first)

My first version had two regressions against HEAD:

- I had narrowed the state-dir check to a prefix match, so `dd if=/tmp/x of=$S/x` lost its deny.
- The wrapper-pass gate did not strip quotes, so `"/bin/bash" -c "git push"` was no longer seen.

I added `dd if=/tmp/x of=$S/x` and `cp -t $S /tmp/x` to the reader test, and `'"/bin/bash" -c "git push"'` and `'/usr/bin/env bash -c "git push"'` to the wrapper test. Against my intermediate code:

```
not ok 1 git is seen behind wrapper options, env -S, shell options, timeout and nice
# no git push in: "/bin/bash" -c "git push"
not ok 2 any command but a reader that names a state path is denied
# dd if=/tmp/x of=.../data/sessions/x ->
```

The fixes: a contains-match on the sessions dir, as at HEAD, and quotes removed from the first word before the gate. Both tests then passed, and these cases also pass at HEAD.

### Whole suite (once, before committing)

```
tests/run-bats tests/hooks/*.bats tests/scripts/*.bats   -> 1..137, 137 ok, 0 not ok (126 before + 11 new)
node --test tests/*.test.mjs                              -> tests 46, pass 46, fail 0
node scripts/lint-skills.mjs                              -> lint: clean
```

### shellcheck 0.11.0

```
shellcheck hooks/lib/gitctx.sh          rc=0
shellcheck -x hooks/lib/gitctx.sh       rc=0
shellcheck hooks/guards/g16-state.sh    rc=0
shellcheck -x hooks/guards/g16-state.sh rc=0
shellcheck -x hooks/pre-tool-use        rc=0
```

The literal `'$('` and `'$home'` case patterns raised SC2016 (info). Each now has a disable comment with its reason. The glob case `in $e)` carries `SC2254`.

### Measurements (macOS `/bin/bash` 3.2.57)

1,000-line here-doc through `git_words`. Each body line is `line N: echo x > /tmp/y; (git push --force)`.

| Command | HEAD | Now |
|---|---|---|
| Commit form, `git commit -m "$(cat <<'EOF' ... EOF\n)"` | 5.217 s, 1003 records | 0.013 s, 2 records |
| Top level, `cat > /tmp/f <<'EOF' ... EOF\ngit status` | 10.409 s, 2003 records | 0.009 s, 2 records |

The bats timing test, measured with `TIMEFORMAT=%R` and `time`, took 8.585 s at HEAD and passes under 1 s now.

Through `hooks/pre-tool-use` on `/bin/bash`:

| Input | HEAD | Now |
|---|---|---|
| 200 KB Write | 1.313 s | 1.336 s (1.36 s on a rerun) |
| Bash, 227 KB here-doc naming `sessions` | 2.433 s | 2.514 s |
| Bash, 200 KB one-line `echo sessions.state xxx...` | 1.952 s, prefilter exit | 5.706 s, deny |

The 227 KB here-doc costs the same at HEAD and now, because the time is spent parsing the JSON. The one-line case is concern 5.

## Files changed

- `hooks/lib/gitctx.sh`
- `hooks/guards/g16-state.sh`
- `tests/hooks/gitctx.bats`
- `tests/hooks/g16-state.bats`

## Deviations

1. **"Exactly one segment" for the commit form.** `git_words` prints two records: the commit, and `cat <<'EOF'`, which is the command inside the `$( )`. The brief's scope says "exactly one git segment". Its test list says "exactly one segment". I followed the scope. The `cat` is a real command, and dropping it would need a special case for `$(cat <<...)`. The test asserts that the first record is the commit, that the second is `cat <<'EOF'`, and that there are no others, so no message line shows up as a record.
2. **The double-quoted target test passed before the change.** At HEAD, `echo on > "$S/test-session.state"` sent with properly escaped JSON (`tool_payload`) already gives deny. A probe of `echo on > "/x/test-session.state"` also denies at HEAD. I could not reproduce the round-D "no vote". The test stays as a guard.
3. **Small additions the design needed.** Each is pinned by a test:
   - A quoted newline survives `_shell_words` as `\037`, and `git_words` decodes it. So a multi-line `bash -c` script is split on its lines. At HEAD its lines were joined with spaces.
   - Wrappers match by basename, so `/usr/bin/env` and `/usr/bin/sudo` are recognized.
   - A `cd` elsewhere clears the in-sessions-dir flag. Without that, the allow-list would deny every later command.
   - The state-dir rule stays a contains-match, as at HEAD, not a prefix match. "Under `$sd`" is read so that `of=$S/x` and `--opt=$S/x` still count.

## Concerns

1. **A leading redirection hides the command name. This gap is older than this task, and I did not fix it.** For `2>/dev/null git push --force`, `_cmd_words` returns `2>/dev/null` as the command name, so `git_sub` fails. That holds at HEAD and now (probe: `not git: 2>/dev/null git push --force`). G1 in Task 10 will miss it. The fix is about two lines in `_cmd_words`: skip a word that starts with an fd number or `<`/`>`/`&>`, and skip the next word when the operator stands alone. It is outside this brief, so I left it for the controller to decide.
2. **What the allow-list now denies.** The brief asks for this, so I recorded it rather than changing it. `echo state lives in $S`, `test -f $S/a.state`, `sort < $S/a.state` and `git add tests/sessions/foo.state` are all denied. So is any non-reading command after `cd $S`; for example, `cd $S && cat x && echo done` is denied. `test` and `[` may be worth adding to the readers.
3. **A reader that writes.** `sed -n 'w $S/a.state' /tmp/x` still gets no vote: `sed` without `-i` is a reader, and the `w` command writes. G16 is best effort, so I left it.
4. **`\037` in records and words.** The contract line for `git_words` ("prints one per line") does not mention the in-record `\037`. When Task 12 reads a multi-line `-m` message through `_shell_words`, it will see `\037` where HEAD gave a space. The subject check behaves the same, because the whole message was already one line. A contract note would help Task 12.
5. **Large one-line Bash commands.** The wider prefilter now sends a 200 KB one-line command that names `sessions` or `.state` through the full parse: 5.7 s against 1.95 s at HEAD. The cost is the per-character awk passes in `_split_words` and `_shell_words` (about 1.5 s per pass at 200 KB), which predate this task. HEAD paid the same for any big command that named the state dir path. The time is under the 20 s hook timeout, and the brief sets no target for this shape.
6. **Lexer limits that predate this task.** A `"` or `)` inside a double-quoted string nested in `$( )` is not tracked as its own quote context. The here-doc rule "no closing line, nothing skipped" means that a misread `<<` hides commands only when a later line happens to equal the misread delimiter.

---

# Fix round 1

Status: DONE

Commit: `374e4d7 M1: close the here-doc and G16 gaps from the Task 9a review` (parent `e660754`, not pushed, no trailers). It stages only the four Task 9a files. `docs/plans/contract.md` has a working-tree change that I did not make; this is the controller's `\037` note, and I left it unstaged.

## Changes, by ruling

**1. A quoted `<<` swallowed the rest (`gitctx.sh`, `heredoc()`).**
- The delimiter word now ends at a newline or at the end of input, even inside a quote.
- If a quote is still open there, nothing is queued.
- Scanning always resumes right after the `<<`, never after the word. So the word's characters, including any `)` or `"` it took from the enclosing string, are lexed as ordinary text. This also covers an even number of quotes after a quoted `<<`, where the word closes cleanly but crosses the `)"` of the enclosing `$( )`.
- The comment on `heredoc()` now says this.

**2. A shell's here-doc is its script.**
- `_split_words` tracks where the current simple command starts (`cs`).
- At a `<<`, `shellin()` runs that command's text through the same word logic as `_cmd_words`. It then checks for `sh`, `bash`, `zsh` or `dash` with no `-[a-z]*c[a-z]*` word.
- When it finds one, the here-doc is not queued, so its body is lexed as commands, as at HEAD.
- To share that logic, `_shell_words` and `_cmd_words` are now thin wrappers over awk functions in one string, `_GW_AWK`, which `_split_words` also uses. As a side effect, `_cmd_words` runs one awk process instead of two.
- `cat <<EOF | sh` is named as out of scope in the `git_words` comment, beside xargs.

**3. Plain reads and messages voted (`g16-state.sh`).**
- The readers are now: `cat head tail less more grep egrep fgrep rg ls stat wc file diff cmp jq echo printf test [ git`, and `find` without `-delete -exec -execdir -ok -okdir -fprint -fprint0 -fprintf`.
- The `*sessions*.state` rule applies only to a word with no blank and no `\037`.
- A settings word asks only for a Task 9 write shape: `tee cp mv ln rm truncate dd install`, or `sed`/`perl` with `-i`. A redirect into a settings file still asks.
- Each segment now tracks a state flag (`seg_s`) and a settings flag (`seg_c`) separately.

**4. A misread `<<` hid real lines (`_split_words`).**
- There is no here-doc inside `$((`, a nested `((`, or a top-level `(( ))`. These are tracked with `ar` and `ta`.
- A word that starts with `#`:
  - At the top level, the comment is skipped to its newline. As a side effect, an apostrophe in a top-level comment no longer opens a quote. At HEAD and at e660754, `# it's a note` followed by a newline and `git push --force` hid the push.
  - Inside `$( )`, it only disables here-docs until the newline (`cm`). I did not skip there, because `$(x #)` would then lose its `)`.
- A `)` that closes a `$( )` drops the here-docs queued inside it (`hdd`, `shut()`).

**5. A leading redirection.**
- In `cw()`, a word that starts with an fd number and `<`, `>` or `&>` is skipped before the command name. When the operator stands alone (`>`, `2>`, `<<`), the next word is skipped too.
- The wrapper-pass gate in `git_words` also fires when the first word holds `<` or `>`.

**6. Smaller.**
- `timeout --signal` and `--kill-after` take a value.
- A glob word votes only when it has as many `/` as the state path.
- I added tests for the `$HOME`, `${HOME}`, `${CLAUDE_PLUGIN_DATA}` and `"$CLAUDE_PLUGIN_DATA"` expansions, using `*.state` so the sid rule cannot be what matches.
- I added a test that `<<<` is not a here-doc.
- The timing test sends `git_words` stderr to `/dev/null`.

## Tests

New tests:
- `gitctx.bats`:
  - `a leading redirection is not the command name`
  - `a << inside quotes in $( ) hides nothing`
  - `a shell reading a here-doc runs its body: the body stays as records`
  - `a here-string is not a here-doc`
- `g16-state.bats`:
  - `plain reads, git commands and messages naming state or settings: no vote`
  - `a shell reading a here-doc runs its body as commands`
  - `a misread << hides no state write`

Extended tests:
- The wrapper test gains `timeout --signal KILL 30 git push` and `timeout --kill-after 5 30 git push`.
- The glob test gains the four expansion forms and `du -sh ~/* ; ls sessions` (no vote).

The new helper `expect_cmd` sends commands that hold `"` or newlines through `json_escape`.

### RED at e660754

Command: `tests/run-bats tests/hooks/gitctx.bats tests/hooks/g16-state.bats`

```
1..50
not ok 4 git is seen behind wrapper options, env -S, shell options, timeout and nice
# no git push in: timeout --signal KILL 30 git push
not ok 5 a leading redirection is not the command name
# no git push in: 2>/dev/null git push --force
not ok 6 a << inside quotes in $( ) hides nothing
# no git push in: echo "$(grep -c '<<' f)"; git push --force
not ok 7 a shell reading a here-doc runs its body: the body stays as records
# no git push in: bash <<'EOF'
not ok 34 a glob that matches the state file once ~ is expanded is denied
# du -sh ~/* ; ls sessions -> ..."permissionDecision":"deny"...
not ok 35 plain reads, git commands and messages naming state or settings: no vote
# git diff .claude/kern.yml -> ..."permissionDecision":"ask"...
not ok 36 a shell reading a here-doc runs its body as commands
not ok 37 a misread << hides no state write
```

The other 42 tests passed. The here-string test and the four expansion cases already passed at e660754: they record existing behaviour.

Per case through `hooks/pre-tool-use` on `/bin/bash` (a scratch probe; the first column is e660754, the second is now):

```
none  deny  bash <<'EOF'|echo autopilot: on > $S/test-session.state|EOF
ask   none  git diff .claude/kern.yml
ask   none  git check-ignore -q .claude/kern.local.yml
ask   none  echo ".claude/kern.local.yml" >> .gitignore
deny  none  git commit -m "G16: deny writes to sessions/<sid>.state"
deny  none  git add tests/sessions/foo.state
deny  none  test -f $S/x.state && echo yes
deny  none  find $S -name '*.state'
deny  deny  find $S -name x -delete
deny  deny  echo on > $S/x.state
ask   ask   cd .claude && sed -i '' s/ask/auto/ kern.yml
none  deny  echo $((1<<X))|echo on > $S/a.state|X
none  deny  # see <<X|echo on > $S/a.state|X
none  deny  x=$(cat <<X)|echo on > $S/a.state|X
deny  none  du -sh ~/* ; ls sessions
deny  deny  echo on > $HOME/.claude/p*/d*/k*/s*/*.state      (also ${HOME}, ${CLAUDE_PLUGIN_DATA}, "$CLAUDE_PLUGIN_DATA")
none  none  cat <<'EOF' | sh|echo autopilot: on > $S/test-session.state|EOF   (out of scope)
```

`git_sub` subcommands that `git_words` finds (first column e660754, second column now):

```
-       push   echo "$(grep -c '<<' f)"; git push --force
-       push   echo "$(echo '<<X')"|git push --force|X
-       push   bash <<'EOF'|git push --force origin main|EOF
-       push   x=$(sudo -u me sh -s <<EOF|git push --force|EOF|)
-       push   2>/dev/null git push --force      (also "> /dev/null git push", "2>/dev/null bash -c "git push"")
-       push   timeout --signal KILL 30 git push  (also --kill-after 5 30)
push    push   cat <<< EOF|git push --force|EOF
-       push   echo $((1<<X))|git push --force|X   (also "$((1<<X))" and (( y = 1 << X )))
-       push   # see <<X|git push --force|X
-       push   # it's a note|git push --force
-       push   x=$(cat <<X)|git push --force|X
-       -      cat <<'EOF|git push --force          (unterminated quote: bash runs nothing either)
-       -      bash -c 'cat' <<EOF|git push --force|EOF   (the -c script reads the body as data)
```

### GREEN

```
tests/run-bats tests/hooks/gitctx.bats tests/hooks/g16-state.bats  -> 1..50, 50 ok
```

### Whole suite (once, before committing)

```
tests/run-bats tests/hooks/*.bats tests/scripts/*.bats   -> 1..144, 144 ok, 0 not ok (137 + 7 new)
node --test tests/*.test.mjs                              -> tests 46, pass 46, fail 0
node scripts/lint-skills.mjs                              -> lint: clean
shellcheck and shellcheck -x, gitctx.sh and g16-state.sh  -> rc=0 (and -x on hooks/pre-tool-use rc=0)
```

### Timings (macOS `/bin/bash` 3.2.57)

- A 1,000-line here-doc through `git_words`: the commit form takes 0.013 s and gives 2 records; the top-level `cat > f <<'EOF'` takes 0.008 s and gives 2 records.
- A 200 KB Write through `hooks/pre-tool-use`: 1.323 s.
- For reference:
  - A 227 KB Bash here-doc naming `sessions` takes 2.509 s, as before; the time goes to JSON parsing.
  - A 200 KB one-line `echo sessions.state ...` takes 5.756 s and now gives no vote, because `echo` is a reader.

## Concerns

None new. The out-of-scope items stay as ruled: `cat <<EOF | sh` (now named in the comment), `sed -n 'w ...'`, and the 5.7 s cost of a 200 KB one-line command.

---

# Fix round 2

Status: DONE

Commit: `b7562fd M1: fix the comment and here-doc shell checks from the 9a re-review` (parent `8dd86ab`, not pushed, no trailers). It stages only the four Task 9a files. This round has no refactors and no new features.

## Changes, by ruling

**1. Comment skip (`gitctx.sh`).** I applied the re-review's patch:
- The backslash branch records `es = i + 1`. `es` is also set to 0 with the other state in `END`.
- At the top level, `#` starts a comment only when `i == 1 || (sep(p) && p != ")" && i - 1 != es)`.
- A one-line comment above that test names the two cases.

**2. `cs` restored when `$( )` closes.** Also applied as patched:
- `csv[depth] = cs` is saved before each of the three `depth++` sites: `$(` in double quotes, `$(` unquoted, and `(` inside `$( )`.
- `shut()` restores `cs = csv[depth]` after `depth--`.
- The comments on `shut()` and on the state variables say this.

**3. Pinning tests only.** No code change.

**4. Minor (`g16-state.sh`).**
- `find -fls` joins the list of find actions that write.
- A glob holding `**` skips the `/` count check, and the comment says so.
- perl's `-i` check now ignores `-M` and `-I`. Before this check runs, G16 lower-cases the whole command, which turns `-I` into `-i`. So before lower-casing, `_g16_bash` rewrites a word-initial ` -I` into ` -\002`. The word loop then treats `-\002...` as in-place only for `sed`, because BSD sed's `-I` is in-place, and as an include dir for perl. Words starting with `-m` (`-M` once lower-cased) are skipped.
- I chose `\002` because bash uses `\001` internally (CTLESC).
- I checked that the marker survives `tr` and here-documents on `/bin/bash` 3.2.

## Tests

New tests:
- `gitctx.bats`:
  - `a shell here-doc after a closed $( ) keeps its body`
  - `a << inside a top-level (( )) is not a here-doc`
  - `a # after an escaped separator or a closing ) is not a comment`. It covers `\ `, `\;`, `\|`, `\&`, `\(`, an escaped tab, `$(date +%s)#tag`, `$((1+1))#` and `<(date)#x`, and checks that `echo a\\ #b; git push --force` stays one record.
- `g16-state.bats`:
  - `a # that bash does not read as a comment hides no state write`

Extended tests:
- The shell here-doc test gains `x=$(date) bash <<'EOF'` with a `touch` body.
- The glob test gains `echo on > ~/.claude/**/*.state` (deny).
- The plain-reads test gains:
  - no vote: `[ -f ... ]`, `printf '%s\n' ...`, `perl -Mstrict -ne`, `perl -Ilib -ne`, the `gh pr create --body` sentence (one line, and with a quoted newline);
  - deny: `find ... -fls <state>`, `perl -i -pe`, `sed -I ''`.

### RED at HEAD (8dd86ab)

Command: `tests/run-bats tests/hooks/gitctx.bats tests/hooks/g16-state.bats`

```
1..54
not ok 8 a shell here-doc after a closed $( ) keeps its body
# no git push in: x=$(date) bash <<'EOF'
not ok 10 a # after an escaped separator or a closing ) is not a comment
# no git push in: echo a\ #b; git push --force
not ok 37 a glob that matches the state file once ~ is expanded is denied
#   `expect_bash deny "echo on > ~/.claude/**/*.state"' failed
not ok 38 plain reads, git commands and messages naming state or settings: no vote
# perl -Mstrict -ne 'print' .../sessions/a.state -> ..."permissionDecision":"deny"...
not ok 39 a shell reading a here-doc runs its body as commands
not ok 40 a # that bash does not read as a comment hides no state write
```

Per case, through a scratch probe (`hooks/pre-tool-use` and `git_words` on `/bin/bash`). The first column is HEAD 8dd86ab, the second is now:

```
git push found
-     push  x=$(date) bash <<'EOF'|git push --force|EOF
-     push  x="$(date)" bash <<'EOF'|git push --force|EOF
-     push  echo a\ #b; ...   (and \;  \|  \&  \(  escaped tab)
-     push  x=$(date +%s)#tag; git push --force
-     push  echo $((1+1))#; git push --force
-     push  cat <(date)#x; git push --force
-     -     echo a\\ #b; git push --force        (a real comment)
push  push  y=1; (( y = 1 << X ))|git push --force|X
G16
none  deny  echo a\ #b; touch $S/test-session.state
none  deny  echo $(date)#t; touch $S/test-session.state
none  deny  x=$(date) bash <<'EOF'|touch $S/test-session.state|EOF
none  deny  find /tmp -name x -fls $S/x.state
none  deny  echo on > ~/.claude/**/*.state
deny  none  perl -Mstrict -ne 'print' $S/a.state
deny  none  perl -Ilib -ne 'print' $S/a.state
deny  deny  perl -i -pe s/a/b/ $S/a.state      (also -i.bak, and sed -I '')
none  none  [ -f $S/x.state ]  /  printf '%s\n' $S/x.state
none  none  gh pr create --title t --body "G16 now guards sessions/x.state"  (and with a quoted newline)
```

The two ruling-3 pins pass at HEAD, as they should. To show they pin the rulings, I ran them against e660754, which has neither the blank/`\037` arm nor the top-level `(( ))` tracking:

```
deny  none  gh pr create --title t --body "G16 now guards sessions/x.state"
deny  none  gh pr create --title t --body "fix: x||G16 now guards sessions/x.state"
-     push  y=1; (( y = 1 << X ))|git push --force|X
```

### GREEN and whole suite

```
tests/run-bats tests/hooks/gitctx.bats tests/hooks/g16-state.bats  -> 1..54, 54 ok
tests/run-bats tests/hooks/*.bats tests/scripts/*.bats             -> 1..148, 148 ok, 0 not ok (144 + 4 new)
node --test tests/*.test.mjs                                        -> tests 46, pass 46, fail 0
node scripts/lint-skills.mjs                                        -> lint: clean
shellcheck and shellcheck -x, gitctx.sh and g16-state.sh            -> rc=0 (and -x on hooks/pre-tool-use rc=0)
```

### Timings (macOS `/bin/bash` 3.2.57; HEAD 8dd86ab in brackets)

| Command | Now | HEAD |
|---|---|---|
| 200 KB Write through `hooks/pre-tool-use` | 1.333 s | 1.329 s |
| 1,000-line here-doc through `git_words`, commit form | 0.016 s, 2 records | 0.013 s |
| `bash <<'EOF'` with 1,000 lines, through `git_words` | 0.146 s, 2002 records | 0.146 s |
| `bash <<'EOF'` with 1,000 `echo line N sessions` lines, through `hooks/pre-tool-use` | 2.680 s | 2.754 s |

The body lines are `line N: echo x > /tmp/y; (git push --force)`; each gives two records.

The last row passes the G16 prefilter. G16 then runs `_cmd_words` once per record, about 2.5 ms each.

## Concerns

None. ANSI-C quotes (`$'...'`) remain out of scope, as ruled.

---

# Revert round (stop rule)

Status: DONE

Commit: `38b23b0 M1: revert the 9a round-2 pieces that hid commands or timed out` (parent `b7562fd`, not pushed, no trailers). It stages only the four Task 9a files.

## Changes

1. **The ` -I` marker is removed** (`g16-state.sh`): both `cmd=${cmd// -I/ -$ui}` and the `-"$ui"*` arm are gone, and the `-m*` skip stays.
   - Test change: `perl -Ilib -ne 'print' <state>` is dropped from the no-vote list.
   - It now denies again. This is the accepted limit: lower-casing reads `-I` as `-i`.
   - `sed -I` on a state path still denies.
2. **`p != ")"` is removed from the comment test** (`gitctx.sh`), and the comment above the test now reads "Not after an escaped blank or operator."
   - Test change: the three `)#` items (gitctx.bats) and `echo $(date)#t` (g16-state.bats) are dropped.
   - `$( )#`, `$(( ))#` and `<( )#` followed by a command are now the accepted limit.
3. **`es` is set only when the escaped character is not a newline:** `if (substr(buf, i + 1, 1) != "\n") es = i + 1`.
   - New `finds` case: `echo a \` + newline + `#it's` + newline + `git push --force`.
   - The test is renamed `a # after an escaped separator is not a comment; after a line continuation it is`.
4. **The `\037` pin is rewritten** with a body that has no blank: `gh pr create --title t --body "fix:` + newline + `sessions/x.state"`.

## Evidence

RED at b7562fd for item 3 (`tests/run-bats -f ...`):

```
not ok 1 a # after an escaped separator is not a comment; after a line continuation it is
# no git push in: echo a \
# #it's
# git push --force
```

Probe (`hooks/pre-tool-use` and `git_words` on `/bin/bash`). The first column is b7562fd, the second is now:

```
git push found
-     push  (cd /tmp)#it's done|git push --force
-     push  echo a \|#it's|git push --force
push  push  echo a\ #b; git push --force          (and a\;#b: still fixed)
G16
deny  deny  sed -I '' s/a/b/ $S/a.state
none  deny  perl -Ilib -ne 'print' $S/a.state       (accepted limit)
none  none  perl -Mstrict -ne 'print' $S/a.state
deny  deny  perl -i -pe s/a/b/ $S/a.state
```

The `\037` pin gives no vote now. On a scratch copy with only the `*"$_GW_NL"*` half of the arm removed, it denies:

```
none  deny  gh pr create --title t --body "fix:|sessions/x.state"
```

The marker's timeout, checked with a 14.6 KB `gh pr create` body that mentions `perl -I lib` 700 times, through the dispatcher:

| Version | Time |
|---|---|
| b7562fd | 30.123 s |
| now | 0.116 s |

## Whole suite (once)

```
tests/run-bats tests/hooks/*.bats tests/scripts/*.bats   -> 1..148, 148 ok, 0 not ok
node --test tests/*.test.mjs                              -> tests 46, pass 46, fail 0
node scripts/lint-skills.mjs                              -> lint: clean
shellcheck and shellcheck -x, gitctx.sh and g16-state.sh  -> rc=0
```

## Concerns

None. The accepted limits are as ruled: perl `-I` reads as `-i`, and `$( )#`, `$(( ))#` and `<( )#` followed by a command are read as a comment.
