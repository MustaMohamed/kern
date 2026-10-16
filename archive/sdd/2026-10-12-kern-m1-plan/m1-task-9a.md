### Task 9a: Splitter and G16 hardening (added by the Task 9 review)

Task 9 shipped the guard dispatcher, `hooks/lib/gitctx.sh` and G16. Its last re-review found gaps that are not regressions of a single fix but limits of the lexical design. This task closes the ones that matter before Tasks 10 to 13 build on `gitctx.sh`. It has no code in the plan: you design the change, test first.

**Files:**
- Modify: `hooks/lib/gitctx.sh`, `hooks/guards/g16-state.sh`
- Test: `tests/hooks/gitctx.bats`, `tests/hooks/g16-state.bats`

**Read first:** `hooks/lib/gitctx.sh`, `hooks/guards/g16-state.sh`, `hooks/pre-tool-use`, `tests/helpers/common.bash` (`run_guard`, `bash_payload`, `tool_payload`, `decision_of`, `set_autopilot`), the two bats files, and in `docs/plans/contract.md` the lines for `gitctx.sh`, `push_targets` and G16.

**Ground rules:**
- G16 is best effort. Writes through an interpreter (`python -c`, `node -e`) or through a variable (`D=...; echo > $D/x`) stay out of scope, as do `xargs` and `find -exec`. Do not add cd-ancestor tracking.
- No vote inside a pipeline subshell. Bash 3.2: no `${x,,}`, no `mapfile`, no associative arrays, no `;&`.
- Every existing test keeps passing. A 200 KB Write through the dispatcher stays under 2 s.
- Plain reads of the state dir or the settings files give no vote.

**Scope:**

1. **G16 Bash: reader allow-list.**
   - Heads that only read: `cat head tail less more grep egrep fgrep rg ls stat wc file diff cmp jq`, plus `sed` and `perl` without `-i` (or `-i<suffix>`). Use `_cmd_words` to find the head.
   - Any other head in a segment that names a state word is a write and gets deny. This replaces the writer list.
   - A redirection (`>`, `>>`, `>|`, `&>`) to a state word is a write whatever the head.
   - A state word is any of:
     - a word under `$sd`;
     - a word that, after expanding a leading `~`, `$HOME`, `${HOME}`, `$CLAUDE_PLUGIN_DATA` or `${CLAUDE_PLUGIN_DATA}`, glob-matches the real state path, tested as `case "$sd/$SID.state" in $w)`;
     - any word containing `sessions` and ending in `.state`, case-insensitive;
     - a word equal to `<sid>.state` or ending in `/<sid>.state` (Task 9 round D).
   - Settings words, which get ask instead: a word ending in `.claude/kern.yml` or `.claude/kern.local.yml`, or exactly `kern.yml` or `kern.local.yml`.
   - Widen the prefilter so these cases reach the check: the command contains `sessions`, `.state`, `kern.yml` or `kern.local.yml`, or names `$sd`.

2. **Redirections glued to words.**
   - `_shell_words` emits each unquoted `<`, `>`, `>>`, `>|`, `&>`, `2>`, `2>&1` and `<<` run as its own word, so `main>/dev/null` becomes `main` `>/dev/null`. This fixes every consumer.
   - `push_targets` maps `@` and `HEAD` to `current_branch`.

3. **Wrapper option tables in `_cmd_words`.**
   - sudo: `-C -D -g -h -p -R -r -T -t -U -u` take a value.
   - env: `-C -P -S -u` take a value. `env -S "..."` treats its value as a command line.
   - exec: `-a` takes a value.
   - Shells: `-o +o -O +O` take a value. Any `-[a-z]*c[a-z]*` word is the script flag (`bash -cx "..."`).
   - New wrappers: `timeout` (its options, then the duration) and `nice` (`-n N`, `-N`).

4. **Here-doc bodies.**
   - `_split_words` skips the body of `<<WORD`, `<<-WORD`, `<<'WORD'` and `<<"WORD"` up to the closing `WORD` line. Bodies are data, not commands.
   - `git_words` emits segments with a record separator other than newline, or otherwise keeps a quoted multi-line segment whole, so callers never read a quoted line as a command.
   - The standard commit form must give exactly one git segment, `git commit -m ...`. Nothing inside the message counts, including a line that names a state path after `>` or a line like `docs: x (git push --force is blocked)`:
     ```
     git commit -m "$(cat <<'EOF'
     ...
     EOF
     )"
     ```

5. **Cost.**
   - `_subst_bodies` runs only when the segment contains `$(` or a backtick.
   - The wrapper pass runs only when the first word is a shell, `eval` or a known wrapper.
   - A 1,000-line here-doc command must run through `git_words` in under 1 s on `/bin/bash` 3.2. Today it takes 5.1 s.

**Tests (each must fail before your change where it is a behaviour change):**
- g16-state.bats, deny:
  - `cd ~/.claude/plugins/data/kern-kern && sed -i '' s/off/on/ sessions/*.state`
  - `cd $CLAUDE_PLUGIN_DATA && echo autopilot: on > sessions/*.state`
  - `echo autopilot: on > ~/.claude/p*/d*/k*/s*/*.state` (for this case, point `HOME` and `CLAUDE_PLUGIN_DATA` so the state dir is `$HOME/.claude/plugins/data/kern-kern/sessions`)
  - `rsync /tmp/x <sessions>/a.state`
  - `curl -so <sessions>/a.state file:///tmp/x`
  - `ditto /tmp/x <sessions>/a.state`
  - `echo on > "<sessions>/<sid>.state"` (a double-quoted target; the Task 9 round-D re-review saw no vote for it)
- g16-state.bats, ask:
  - `cd .claude && sed -i '' s/ask/auto/ kern.yml`
- g16-state.bats, no vote:
  - `cat`, `grep`, `ls` and `sed -n` of a state file;
  - the commit form above with a state path inside the message;
  - a write into a scratchpad path that holds the session id.
- gitctx.bats:
  - `push_targets` gives `main` for `origin main>/dev/null`, `origin main&>/dev/null` and `origin @`.
  - `git_sub` finds git in each of `exec -a x git push origin main`, `sudo -p x git push`, `sudo -C 3 git push`, `env -P /usr/bin git push`, `env -S "git push origin main"`, `bash -o pipefail -c "git push origin main"`, `bash -cx "git push"`, `timeout 30 git push`, `nice -n 5 git push`.
  - The commit form gives exactly one segment, and it is the commit.
  - The 1,000-line here-doc timing case.

**Commit:**
```bash
git add -- hooks/lib/gitctx.sh hooks/guards/g16-state.sh tests/hooks/gitctx.bats tests/hooks/g16-state.bats
git commit -m "M1: harden the command splitter and G16 against common shapes" -m "Here-doc bodies are data, redirections split from words, wrapper options are known, and G16 treats any non-reading command on a state path as a write."
```

Run the whole suite once before committing: `tests/run-bats tests/hooks/*.bats tests/scripts/*.bats` and `node --test tests/*.test.mjs`.
