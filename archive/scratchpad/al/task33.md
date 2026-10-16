### Task 33: Shell-snapshot aliases judged as their git or gh expansion

User decision, 2026-10-13: "Catch them in M2". This removes the 0.2.0 known limit on shell aliases (`CHANGELOG.md`, 0.2.0 "Known limits").

**Files:**
- Create: `hooks/lib/aliases.sh`, `tests/hooks/aliases.bats`
- Modify: `hooks/lib/gitctx.sh` (`git_words`), `hooks/pre-tool-use` (source line, need line, `aliases_load`), `CHANGELOG.md`

**Interfaces:**
- Consumes: `git_words` (M1), which every guard that reads a Bash command calls (G1 to G6, G15, and G18); the strict `need_lists_match` of Task 32; `kern_env`, `make_repo`, `run_guard`, `payload`, `bash_payload`, `decision_of` and `set_autopilot` from `tests/helpers/common.bash`.
- Produces:
  - `hooks/lib/aliases.sh`: `alias_snapshot` (the snapshot to read; `KERN_SHELL_SNAPSHOT` names one for tests; otherwise the newest `snapshot-*.sh` under `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/shell-snapshots`; exit 1 when there is none), `aliases_load` (sets one variable `_KA_<hex of the alias name>` per alias that runs git or gh, holding its expansion, and `KERN_ALIASES=1` when there is one; a missing, unreadable or unparseable snapshot sets nothing), `alias_expand SEG` (sets `ALIAS_EXP` to SEG with its head word replaced; exit 1 when the head word is no such alias).
  - `git_words` replaces a record whose head word is such an alias by its expansion and splits that again, so G1 to G6 and G15 judge `gpf! origin main` exactly as `git push --force origin main`.
  - Parse rules: lines `alias [--] name=value`; value a bare word, single-quoted text with `'\''` for a quote, or backslash escapes. Skipped: a value in `$'...'` or double quotes, an unclosed quote, a name holding a quote, a slash, a `$`, a backtick or a byte outside printable ASCII. The head word is the first word after `NAME=value` words. Expansion follows zsh: when the expansion's head word names another alias, that alias's value replaces it (zsh re-expands a replacement's head word), each name at most once and at most 8 times, resolved when the table is built. Inside `git_words`, the expansion's own words are not expanded again.
  - Not followed (accepted limits, recorded in the contract): the snapshot a session sourced is not named by the hook input or the environment, so the newest snapshot stands in for it; zsh's trailing-space rule (an alias whose value ends in a space also expands the next word); aliases inside an expansion other than its head-word chain; global aliases (`alias -g`); `$'...'` values; an alias after an assignment word that holds a quote or a `$`.
- Measured on this machine (2026-10-14, Claude Code 2.1.296, zsh):
  - The Bash tool runs each call as `/bin/zsh -c source <snapshot> 2>/dev/null || true && ... eval ...`. zsh expands aliases in a non-interactive shell, and `eval` parses after the snapshot defined them, so they run.
  - Snapshots are named `snapshot-zsh-<epoch ms>-<6 chars>.sh`, one per Claude Code process, written about 33 s after the process started. This session's was the oldest of 12 on disk, two days younger than the session, so "newest" is not "this session's".
  - The hook input carries no snapshot path, and the environment has `CLAUDE_CODE_SESSION_ID` but no snapshot path.
  - All 12 snapshots had identical alias tables (sha of their `alias` lines): 248 aliases, of which 201 run git or gh.
- Cost, measured as the median of 30 runs of `hooks/pre-tool-use` on that 248-alias snapshot under macOS bash 3.2: +12 ms for a command with no alias, +19 ms when an alias is expanded, against a 50 ms budget. No cache is needed. A table held in variables keeps lookups in the shell: a first draft that searched one 10 KB string per record cost +90 ms.

- [ ] **Step 1: Write the failing tests**

`tests/hooks/aliases.bats`:

```bash
@@ALIASES_BATS@@
```

- [ ] **Step 2: Run them to verify they fail**

Run: `tests/run-bats tests/hooks/aliases.bats`
Expected: tests 1 to 4 and 8 fail (the alias gets no vote); 5, 6, 7 and 9 pass, since they assert no vote, which already holds.

- [ ] **Step 3: Write `hooks/lib/aliases.sh`**

```bash
@@ALIASES_SH@@
```

- [ ] **Step 4: Expand in `git_words` and load in `hooks/pre-tool-use`**

In `hooks/lib/gitctx.sh`, replace the header line `# Shell and git parsing for guards. Needs settings.sh. Reads CWD and KERN_MAIN.` with:

```bash
# Shell and git parsing for guards. Needs settings.sh; uses aliases.sh when it is loaded. Reads CWD and
# KERN_MAIN.
```

and in `git_words`, insert before `printf '%s\n' "$seg"`:

```bash
    # An alias that runs git or gh (aliases.sh) is judged as its expansion, which is split again. The
    # expansion's own words are not expanded again: zsh does not re-expand the alias it is expanding,
    # and the table already followed the head-word chain.
    if [ -z "${_GW_NOALIAS-}" ] && declare -F alias_expand >/dev/null && alias_expand "$seg"; then
      _GW_NOALIAS=1
      git_words "$ALIAS_EXP"
      _GW_NOALIAS=
      continue
    fi
```

`declare -F` keeps `gitctx.sh` usable without `aliases.sh` (`tests/hooks/gitctx.bats` sources it alone).

In `hooks/pre-tool-use`, before the gitctx source line, add:

```bash
# shellcheck source=hooks/lib/aliases.sh
. "$KERN_ROOT/hooks/lib/aliases.sh" || no_lib aliases.sh
```

after the last `need gitctx.sh` line, add:

```bash
need aliases.sh alias_snapshot aliases_load alias_expand
```

and after `kern_enabled || exit 0`, add:

```bash
# The shell's aliases that run git or gh, so git_words judges `gp` as `git push`.
[ "$TOOL" = Bash ] && aliases_load
```

- [ ] **Step 5: Run the tests**

Run: `tests/run-bats tests/hooks/aliases.bats && tests/run-bats tests/hooks && shellcheck -x -S warning hooks/lib/*.sh hooks/guards/*.sh hooks/pre-tool-use`
Expected: `9 tests, 0 failures`; then the whole hook suite passes (498 tests in the planning sandbox, the pre-tool-use need-list test included); shellcheck prints nothing.

- [ ] **Step 6: Measure the cost**

Run `hooks/pre-tool-use` 30 times on a Bash payload with and without `KERN_SHELL_SNAPSHOT` pointing at the newest real snapshot (`ls -t ~/.claude/shell-snapshots/snapshot-*.sh | head -1`), for `git status` and for `git status && gp origin feat`, and compare medians.
Expected: each added median is under 50 ms. Over it: cache the parsed table in the state dir keyed by the snapshot's path and mtime (G16 already denies tool writes there), and measure again.

- [ ] **Step 7: Changelog and commit**

Add under `## [Unreleased]` in `CHANGELOG.md`: `- Guards judge a Bash command whose first word is a shell alias from the Claude Code shell snapshot, such as gpf!, as the git or gh command it expands to. This removes the 0.2.0 known limit on shell aliases; the newest snapshot stands in for the session's, which the hook input does not name.`

```bash
git add -- hooks/lib/aliases.sh hooks/lib/gitctx.sh hooks/pre-tool-use tests/hooks/aliases.bats CHANGELOG.md
git commit -m "M2: judge shell-snapshot aliases as the git or gh they run" -m "An alias such as gpf!='git push --force' ran git with no git word in the command, so every git guard missed it; the user asked for it in M2."
```

---

