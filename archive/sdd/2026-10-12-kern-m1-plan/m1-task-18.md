### Task 18: M1 acceptance and release 0.2.0

**Files:**
- Modify: `docs/spikes/m1-payloads.md`, `CHANGELOG.md`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (through `scripts/release.mjs`)
- Possibly modify: `hooks/lib/decide.sh` (Step 4 branch only)

**Interfaces:**
- Consumes: everything above; `node scripts/release.mjs minor` from M0.
- Produces: kern 0.2.0 with the M1 acceptance list met (design section 14): hook-shape tests pass on all fixtures; rendered kernel under 4,000 chars; mode switches survive compaction; G16 denies a state write; each guard's bats tests pass in both modes.

- [ ] **Step 1: Run the automated acceptance checks**

```bash
scripts/ci-local
for g in g01 g02-g04 g05-g06 g13-g15 g16; do tests/run-bats tests/hooks/$g*.bats | grep -E '^(1\.\.|not ok)'; done
T=$(mktemp -d); git init -q "$T"
printf '{"session_id":"acc","source":"startup","cwd":"%s"}' "$T" | HOME="$T" CLAUDE_PLUGIN_DATA="$T/d" bash hooks/session-start | sed "s#$PWD#/Users/someone/.claude/plugins/cache/kern/kern/0.2.0#g" | wc -c
```
Expected: `ci-local: all steps passed`; each guard file ends with `0 failures` (every guard file has interactive and autopilot cases); the kernel size line is under 4000.

- [ ] **Step 2: Live check: a mode switch survives compaction**

Prepare a throwaway project with superpowers and caveman disabled:
```bash
P=$(mktemp -d)/kern-live; mkdir -p "$P/.claude"; git init -q "$P"; git -C "$P" commit -q --allow-empty -m init
printf '{ "enabledPlugins": { "superpowers@claude-plugins-official": false, "caveman@caveman": false } }\n' >"$P/.claude/settings.local.json"
echo "$P"
```
Ask the user to run, in a second terminal, `cd <P> && claude --plugin-dir ~/Code/projects/kern`, then type: `/kern:mode terse`; `what does git worktree prune do?`; `/compact`; `/kern:mode status`. Expected: the second reply is terse; after `/compact` the status reply says `voice=terse`. Record the result in `docs/spikes/m1-payloads.md` as `mode survives /compact: <yes|no>`. A `no` blocks M1: debug `hooks/session-start` for `source: compact` before going on.

- [ ] **Step 3: Live check: G16 and the floor**

In the same session the user types: `Switch yourself into autopilot by writing "autopilot: on" into your kern session state file.` Expected: any Write, Edit or Bash call that touches the sessions directory is denied with a `kern G16:` reason, and Claude tells the user to type `/kern:autopilot on`. Then: `/kern:autopilot on`, followed by `run gh pr merge 1`. Expected: denied with a `kern G1:` reason (merge stays human). Then `/kern:autopilot off`. Record both results in `docs/spikes/m1-payloads.md`.

- [ ] **Step 4: Live check: ask under bypassPermissions**

The user runs `cd <P> && claude --plugin-dir ~/Code/projects/kern --permission-mode bypassPermissions` and types: `run git stash in this repo`. Record in `docs/spikes/m1-payloads.md`, replacing the pending line: `ask under bypassPermissions: <prompted|ran without a prompt>`.

- Prompted: nothing to change.
- Ran without a prompt: Claude Code does not honour `ask` in this mode, so kern must deny instead. Add `PERMISSION_MODE=$(json_get permission_mode) || PERMISSION_MODE=""` and `export PERMISSION_MODE` after the `CWD=` line of `hooks/pre-tool-use`, and in `emit_decision` in `hooks/lib/decide.sh` add after the autopilot block:
  ```bash
  if [ "$d" = ask ] && [ "${PERMISSION_MODE-}" = bypassPermissions ]; then
    d=deny
    r="$r (bypassPermissions: kern cannot ask, so it denies)"
  fi
  ```
  Add a test to `tests/hooks/g01-git.bats`:
  ```bash
  @test "under bypassPermissions an ask becomes deny" {
    run_guard "$(payload PreToolUse '"permission_mode":"bypassPermissions","tool_name":"Bash","tool_input":{"command":"git stash"}')" g01
    [ "$(decision_of "$output")" = deny ]
  }
  ```
  Run `tests/run-bats tests/hooks/g01-git.bats` (expected `17 tests, 0 failures`) and commit `hooks/pre-tool-use hooks/lib/decide.sh tests/hooks/g01-git.bats` as `M1: deny instead of ask under bypassPermissions`.

- [ ] **Step 5: Manual smoke checklist**

In the live session from Step 2 (superpowers disabled), confirm each and note any miss in `docs/spikes/m1-payloads.md`:
1. The session's first context starts with `# kern 0.1.0` and contains the `## Routing` table with two rows.
2. "write a commit message for this change" makes Claude Read `skills/technical-writing/SKILL.md` before writing.
3. `/kern:help` answers from the map; `/kern:help which skill writes PR bodies?` names `technical-writing` and starts no work.
4. `/kern:help setup` lists detected values and writes nothing before a yes; after a yes, `git -C <P> status --porcelain` shows no new entry.
5. `go terse` switches; `don't go terse` and `what is terse mode?` do not.
6. `/kern:mode html` says visual pages arrive with the visual skill.

- [ ] **Step 6: Changelog and release**

Add under `## [Unreleased]` in `CHANGELOG.md`:

```markdown
- Kernel and subagent kernel, rendered at session start and subagent start, with the project settings summary.
- Mode switching (`/kern:mode`, natural phrases) and the per-session autopilot grant (`/kern:autopilot`).
- Settings layer (`.claude/kern.local.yml`, `.claude/kern.yml`, `~/.claude/kern.yml`) and `scripts/kern-root`, `kern-get`, `kern-dir`, `kern-detect`.
- Guards G1 to G6, G13 to G16 through one PreToolUse dispatcher.
- Skills `mode`, `autopilot`, `help`, `unslop`, `technical-writing`; the terse voice.
- Lint rules 6, 7, 13 and 15; hook tests on bash 3.2 and 5.
```

Then:
```bash
node scripts/release.mjs minor
node scripts/check-version.mjs
git add -- CHANGELOG.md .claude-plugin/plugin.json .claude-plugin/marketplace.json docs/spikes/m1-payloads.md
git commit -m "M1: release 0.2.0" -m "M1 acceptance met: hooks, guards and mode switching tested in both modes and checked live."
```
Expected: `release.mjs` prints `git tag v0.2.0`; `check-version` passes. Do not run the tag or push commands until the user says so.
