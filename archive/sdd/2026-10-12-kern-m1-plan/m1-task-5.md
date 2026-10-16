### Task 5: Session state

**Files:**
- Create: `hooks/lib/state.sh`
- Test: `tests/hooks/state.bats`

**Interfaces:**
- Consumes: `hooks/lib/settings.sh`.
- Produces: `state_dir`, `state_file SID` (exit 2 bad id), `state_get SID KEY` (exit 1 unset, 2 unsafe), `state_set SID KEY=VALUE...` (exit 2 on a bad key, a newline in a value, or a symlink), `state_reset SID`, `autopilot_on SID`, `now_iso`. Keys: `voice`, `surface`, `autopilot`, `since`.

- [ ] **Step 1: Write the failing test**

`tests/hooks/state.bats`:
```bash
#!/usr/bin/env bats
# hooks/lib/state.sh: atomic writes, permissions, ids, symlinks, autopilot.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  export KERN_ROOT
  KERN_ROOT="$(kern_root)"
  for lib in settings state; do
    # shellcheck source=/dev/null
    . "$KERN_ROOT/hooks/lib/$lib.sh"
  done
}

@test "state_reset writes defaults with mode 0600" {
  state_reset s1
  [ "$(state_get s1 voice)" = normal ]
  [ "$(state_get s1 surface)" = auto ]
  [ "$(state_get s1 autopilot)" = off ]
  [ "$(ls -l "$(state_file s1)" | cut -c1-10)" = "-rw-------" ]
}

@test "state_reset takes mode.voice and mode.surface from settings and rejects junk" {
  mkdir -p "$R/.claude"
  printf 'mode.voice: terse\nmode.surface: banana\n' >"$R/.claude/kern.local.yml"
  state_reset s1
  [ "$(state_get s1 voice)" = terse ]
  [ "$(state_get s1 surface)" = auto ]
}

@test "state_set updates one key and keeps the others" {
  state_reset s1
  state_set s1 voice=terse
  [ "$(state_get s1 voice)" = terse ]
  [ "$(state_get s1 surface)" = auto ]
  [ "$(grep -c '^voice: ' "$(state_file s1)")" -eq 1 ]
}

@test "bad session ids, bad keys, newlines and symlinks are refused" {
  run state_file "../x"
  [ "$status" -eq 2 ]
  run state_set s1 "Voice=terse"
  [ "$status" -eq 2 ]
  run state_set s1 "voice=a
autopilot: on"
  [ "$status" -eq 2 ]
  mkdir -p "$(state_dir)"
  ln -s /etc/hosts "$(state_dir)/s2.state"
  run state_set s2 voice=terse
  [ "$status" -eq 2 ]
}

@test "autopilot_on needs the state and no denied setting" {
  state_reset s1
  run autopilot_on s1
  [ "$status" -eq 1 ]
  state_set s1 autopilot=on
  autopilot_on s1
  printf 'autopilot: denied\n' >"$HOME/.claude/kern.yml"
  run autopilot_on s1
  [ "$status" -eq 1 ]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run-bats tests/hooks/state.bats`
Expected: FAIL with `hooks/lib/state.sh: No such file or directory`.

- [ ] **Step 3: Write `hooks/lib/state.sh`**

```bash
# shellcheck shell=bash
# kern session state: one flat `key: value` file per session, written only by kern hooks.
# Needs settings.sh. Guard G16 denies tool writes under state_dir.

state_dir() {
  printf '%s/sessions\n' "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/kern-kern}"
}

# state_file SID: path of the session's state file. Exit 2 for an id outside [A-Za-z0-9_-].
state_file() {
  case "$1" in
    '' | *[!A-Za-z0-9_-]*) return 2 ;;
  esac
  printf '%s/%s.state\n' "$(state_dir)" "$1"
}

# state_get SID KEY: prints the value. Exit 1 unset, 2 bad id or unsafe file.
state_get() {
  local f
  f=$(state_file "$1") || return 2
  [ -L "$f" ] && return 2
  [ -f "$f" ] || return 1
  LC_ALL=C awk -v k="$2" 'index($0, k ": ") == 1 { v = substr($0, length(k) + 3); found = 1 }
    END { if (found) { print v; exit 0 } exit 1 }' "$f"
}

# state_set SID KEY=VALUE...: atomic update (temp file in the same dir, then mv), mode 0600.
state_set() {
  local sid="$1" f dir tmp kv k v content
  shift
  f=$(state_file "$sid") || return 2
  dir=$(dirname "$f")
  (umask 077 && mkdir -p "$dir") || return 2
  [ -L "$dir" ] && return 2
  [ -L "$f" ] && return 2
  content=""
  [ -f "$f" ] && content=$(cat "$f")
  for kv in "$@"; do
    k=${kv%%=*}
    v=${kv#*=}
    case "$k" in '' | *[!a-z_]*) return 2 ;; esac
    case "$v" in *"
"*) return 2 ;; esac
    content=$(printf '%s\n' "$content" | LC_ALL=C awk -v k="$k" 'index($0, k ": ") != 1 && $0 != ""')
    content="$content
$k: $v"
  done
  tmp=$(umask 077 && mktemp "$dir/.state.XXXXXX") || return 2
  printf '%s\n' "$content" | sed '/^$/d' >"$tmp" || { rm -f "$tmp"; return 2; }
  mv -f "$tmp" "$f"
}

# now_iso: current UTC time, ISO 8601.
now_iso() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# state_reset SID: defaults from settings, autopilot off.
state_reset() {
  local voice surface
  voice=$(settings_get mode.voice normal)
  surface=$(settings_get mode.surface auto)
  case "$voice" in normal | terse) ;; *) voice=normal ;; esac
  case "$surface" in chat | auto | html) ;; *) surface=auto ;; esac
  state_set "$1" "voice=$voice" "surface=$surface" "autopilot=off" "since=$(now_iso)"
}

# autopilot_on SID: exit 0 only when no settings layer says `autopilot: denied` and the state says on.
autopilot_on() {
  [ "$(settings_get autopilot allowed)" = denied ] && return 1
  [ "$(state_get "$1" autopilot 2>/dev/null)" = on ]
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `tests/run-bats tests/hooks/state.bats`
Expected: `5 tests, 0 failures`.

- [ ] **Step 5: Commit**

```bash
git add -- hooks/lib/state.sh tests/hooks/state.bats
git commit -m "M1: store per-session mode and autopilot state" -m "Atomic, owner-only writes keyed by session id; only hooks write it, and G16 keeps tools out."
```

---

