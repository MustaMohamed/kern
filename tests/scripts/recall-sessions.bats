#!/usr/bin/env bats
# tests/scripts/recall-sessions.bats

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  cd "$REPO"
  slug=$(printf '%s' "$REPO" | LC_ALL=C tr -c 'A-Za-z0-9' '-')
  P="$HOME/.claude/projects"
  mkdir -p "$P/$slug/subagents" "$P/$slug--claude-worktrees-feat-a" "$P/-other-project" "$P/$slug-old"
  printf 'x\n' > "$P/$slug/old.jsonl"; touch -t 202001010000 "$P/$slug/old.jsonl"
  printf 'xx\n' > "$P/$slug/a.jsonl"; touch -t "$(date -v-2d +%Y%m%d%H%M 2> /dev/null || date -d '2 days ago' +%Y%m%d%H%M)" "$P/$slug/a.jsonl"
  printf 'xxx\n' > "$P/$slug/b.jsonl"
  printf 'w\n' > "$P/$slug--claude-worktrees-feat-a/w.jsonl"; touch -t "$(date -v-1d +%Y%m%d%H%M 2> /dev/null || date -d '1 day ago' +%Y%m%d%H%M)" "$P/$slug--claude-worktrees-feat-a/w.jsonl"
  printf 's\n' > "$P/$slug/subagents/child.jsonl"
  printf 'o\n' > "$P/-other-project/o.jsonl"
  printf 'sib\n' > "$P/$slug-old/sibling.jsonl"
  now=$(( $(date +%s) * 1000 ))
  {
    printf '{"display":"floci swap: where are we","pastedContents":{},"timestamp":%s,"project":"%s","sessionId":"b"}\n' "$now" "$REPO"
    printf '{"display":"floci in the other repo","pastedContents":{},"timestamp":%s,"project":"/elsewhere","sessionId":"o"}\n' "$now"
    printf '{"display":"unrelated","pastedContents":{},"timestamp":%s,"project":"%s","sessionId":"a"}\n' "$now" "$REPO"
  } > "$HOME/.claude/history.jsonl"
}

@test "this project's sessions, newest first, worktree sessions included, children and old ones skipped" {
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
  [[ "${lines[0]}" == session$'\t'*$'\t'b$'\t'4$'\t'*"/b.jsonl" ]] || false
  [[ "${lines[1]}" == session$'\t'*$'\t'w$'\t'* ]] || false
  [[ "${lines[2]}" == session$'\t'*$'\t'a$'\t'* ]] || false
  [[ "$output" != *other-project* ]] || false
}

@test "a sibling project whose slug starts with the main slug is never listed" {
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --days 3650
  [ "$status" -eq 0 ]
  [[ "$output" != *sibling* ]] || false
  [[ "$output" != *"$slug-old"* ]] || false
}

@test "--days widens the window" {
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --days 3650
  [ "${#lines[@]}" -eq 4 ]
}

@test "--topic adds this project's matching prompts only" {
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --topic FLOCI
  [ "$(printf '%s\n' "$output" | grep -c '^prompt')" -eq 1 ]
  [[ "$output" == *$'prompt\t'*$'\tb\tfloci swap: where are we'* ]] || false
}

@test "--topic skips a prompt from a sibling project whose path starts with the main path" {
  printf '{"display":"floci from the old checkout","pastedContents":{},"timestamp":%s,"project":"%s-old","sessionId":"old"}\n' "$now" "$REPO" >> "$HOME/.claude/history.jsonl"
  printf '{"display":"floci in a subdir","pastedContents":{},"timestamp":%s,"project":"%s/sub","sessionId":"sub"}\n' "$now" "$REPO" >> "$HOME/.claude/history.jsonl"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --topic floci
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c '^prompt')" -eq 1 ]
  [[ "$output" != *"old checkout"* ]] || false
  [[ "$output" != *"in a subdir"* ]] || false
}

@test "--topic takes a worktree prompt" {
  printf '{"display":"floci in a worktree","pastedContents":{},"timestamp":%s,"project":"%s/.claude/worktrees/feat-a","sessionId":"w"}\n' "$now" "$REPO" >> "$HOME/.claude/history.jsonl"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --topic floci
  [ "$(printf '%s\n' "$output" | grep -c '^prompt')" -eq 2 ]
  [[ "$output" == *$'\tw\tfloci in a worktree'* ]] || false
}

@test "--topic finds a word after an escaped quote and still reads the fields behind it" {
  printf '{"display":"say \\"hi\\" then floci later","pastedContents":{},"timestamp":%s,"project":"%s","sessionId":"q"}\n' "$now" "$REPO" >> "$HOME/.claude/history.jsonl"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --topic floci
  [ "$status" -eq 0 ]
  [[ "$output" == *$'prompt\t'*$'\tq\tsay "hi" then floci later' ]] || false
}

@test "--topic reads past a display that ends in an escaped backslash" {
  printf '{"display":"floci C:\\\\tmp\\\\","pastedContents":{},"timestamp":%s,"project":"%s","sessionId":"bs"}\n' "$now" "$REPO" >> "$HOME/.claude/history.jsonl"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --topic 'c:\tmp'
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\tbs\tfloci C:\\tmp\\' ]] || false
}

@test "--topic reads a history line that ends in a carriage return" {
  printf '{"display":"floci with crlf","pastedContents":{},"timestamp":%s,"project":"%s","sessionId":"cr"}\r\n' "$now" "$REPO" >> "$HOME/.claude/history.jsonl"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --topic 'with crlf'
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\tcr\tfloci with crlf' ]] || false
}

@test "--topic skips prompts older than the window" {
  printf '{"display":"floci ancient","pastedContents":{},"timestamp":1000000,"project":"%s","sessionId":"anc"}\n' "$REPO" >> "$HOME/.claude/history.jsonl"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --topic ancient
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c '^prompt')" -eq 0 ]
}

@test "no ~/.claude/projects and no history is an empty answer, not an error" {
  rm -rf "$HOME/.claude"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --topic floci
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "an unreadable transcript folder is an error, not an empty list" {
  [ "$(id -u)" -ne 0 ] || skip "root reads every folder"
  chmod 000 "$P/$slug"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions"
  chmod 755 "$P/$slug"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *recall-sessions:* ]] || false
  [ -z "$output" ]
}

@test "an unreadable history file is an error" {
  [ "$(id -u)" -ne 0 ] || skip "root reads every file"
  chmod 000 "$HOME/.claude/history.jsonl"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --topic floci
  chmod 644 "$HOME/.claude/history.jsonl"
  [ "$status" -ne 0 ]
  [[ "$stderr" == *recall-sessions:* ]] || false
}

@test "a bad option exits 2" {
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --days soon
  [ "$status" -eq 2 ]
}

@test "an empty --topic exits 2" {
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --topic ''
  [ "$status" -eq 2 ]
}

@test "outside a git repository exits 2" {
  cd "$TMP"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"not a git repository"* ]] || false
}
