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
  mkdir -p "$REPO/.claude/worktrees" "$P/$slug/subagents" "$P/$slug--claude-worktrees-feat-a" "$P/-other-project" "$P/$slug-old"
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

# hist_line SESSION PROJECT TEXT: append a compact history line for this test.
hist_line() {
  printf '{"display":"%s","pastedContents":{},"timestamp":%s,"project":"%s","sessionId":"%s"}\n' "$3" "$now" "$2" "$1" >> "$HOME/.claude/history.jsonl"
}

# shim NAME BODY: a NAME command ahead of the real one on PATH; run through `run env PATH=...`.
shim() {
  mkdir -p "$TMP/shim"
  printf '#!/bin/sh\n%s\n' "$2" > "$TMP/shim/$1"
  chmod +x "$TMP/shim/$1"
}

@test "--days 08 and 09 are decimal, and keep the prompts" {
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --days 08 --topic floci
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c '^prompt')" -eq 1 ]
  [ -z "$stderr" ]
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --days 09 --topic floci
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c '^session')" -eq 3 ]
  [ "$(printf '%s\n' "$output" | grep -c '^prompt')" -eq 1 ]
}

@test "an unreadable ~/.claude, projects dir or HOME is an error" {
  [ "$(id -u)" -ne 0 ] || skip "root reads every folder"
  for target in "$HOME/.claude" "$HOME/.claude/projects" "$HOME"; do
    chmod 000 "$target"
    run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions"
    chmod 755 "$target"
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"recall-sessions: cannot read $target"* ]] || false
    [ -z "$output" ]
  done
}

@test "a dangling history symlink is an error, a missing history is not" {
  rm "$HOME/.claude/history.jsonl"
  ln -s "$TMP/nowhere" "$HOME/.claude/history.jsonl"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --topic floci
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"recall-sessions: cannot read"* ]] || false
  rm "$HOME/.claude/history.jsonl"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --topic floci
  [ "$status" -eq 0 ]
}

@test "a prompt with no sessionId prints - so the columns hold" {
  printf '{"display":"floci nosession","pastedContents":{},"timestamp":%s,"project":"%s"}\n' "$now" "$REPO" >> "$HOME/.claude/history.jsonl"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --topic nosession
  [[ "$output" == *$'prompt\t'*$'\t-\tfloci nosession' ]] || false
}

@test "a linked worktree outside the main checkout is included, by exact path" {
  git worktree add --quiet "$TMP/linked" -b lw
  mkdir -p "$P/$(printf '%s' "$TMP/linked" | LC_ALL=C tr -c 'A-Za-z0-9' '-')" "$P/$(printf '%s' "$TMP/linked" | LC_ALL=C tr -c 'A-Za-z0-9' '-')-x"
  printf 'l\n' > "$P/$(printf '%s' "$TMP/linked" | LC_ALL=C tr -c 'A-Za-z0-9' '-')/lw.jsonl"
  printf 'l\n' > "$P/$(printf '%s' "$TMP/linked" | LC_ALL=C tr -c 'A-Za-z0-9' '-')-x/notlw.jsonl"
  hist_line lw "$TMP/linked" "floci linked"
  hist_line notlw "$TMP/linked-x" "floci not linked"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --topic floci
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\tlw\t'*"/lw.jsonl"* ]] || false
  [[ "$output" == *$'\tlw\tfloci linked'* ]] || false
  [[ "$output" != *notlw* ]] || false
}

@test "a shared absolute worktree.dir does not pull in other projects under it" {
  shared="$TMP/shared"
  mkdir -p "$shared" "$REPO/.claude"
  printf 'worktree.dir: %s\n' "$shared" > "$REPO/.claude/kern.local.yml"
  sslug=$(printf '%s' "$shared" | LC_ALL=C tr -c 'A-Za-z0-9' '-')
  mkdir -p "$P/$sslug-projB" "$P/$sslug-other"
  printf 'p\n' > "$P/$sslug-projB/projb.jsonl"
  printf 'p\n' > "$P/$sslug-other/otherp.jsonl"
  hist_line projb "$shared/projB" "floci in projB"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --days 3650 --topic floci
  [ "$status" -eq 0 ]
  [[ "$output" != *projb* ]] || false
  [[ "$output" != *otherp* ]] || false
  [[ "$output" != *projB* ]] || false
}

@test "a relative worktree.dir holding .. still finds its linked worktrees, and only those" {
  mkdir -p "$TMP/wts" "$REPO/.claude"
  printf 'worktree.dir: ../wts\n' > "$REPO/.claude/kern.local.yml"
  git worktree add --quiet "$REPO/../wts/lw" -b lw
  lslug=$(printf '%s' "$TMP/wts/lw" | LC_ALL=C tr -c 'A-Za-z0-9' '-')
  oslug=$(printf '%s' "$TMP/wts/other" | LC_ALL=C tr -c 'A-Za-z0-9' '-')
  mkdir -p "$P/$lslug" "$P/$oslug"
  printf 'l\n' > "$P/$lslug/lw.jsonl"
  printf 'o\n' > "$P/$oslug/otherp.jsonl"
  hist_line lw "$TMP/wts/lw" "floci lw"
  hist_line otherp "$TMP/wts/other" "floci other"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --topic floci
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\tlw\t'*"/lw.jsonl"* ]] || false
  [[ "$output" == *$'\tlw\tfloci lw'* ]] || false
  [[ "$output" != *otherp* ]] || false
}

@test "a worktree.dir that does not exist adds no prefix" {
  rmdir "$REPO/.claude/worktrees"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [[ "$output" != *"/w.jsonl"* ]] || false
}

@test "a failing or empty-handed wc dies loudly" {
  shim wc 'exit 1'
  run --separate-stderr env PATH="$TMP/shim:$PATH" bash "$KERN_ROOT/scripts/recall-sessions"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *recall-sessions:* ]] || false
  shim wc 'exit 0'
  run --separate-stderr env PATH="$TMP/shim:$PATH" bash "$KERN_ROOT/scripts/recall-sessions"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"recall-sessions: unreadable size"* ]] || false
}

@test "a failing or empty-handed sort dies loudly" {
  shim sort 'exit 1'
  run --separate-stderr env PATH="$TMP/shim:$PATH" bash "$KERN_ROOT/scripts/recall-sessions"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"recall-sessions: sort failed"* ]] || false
  shim sort 'exit 0'
  run --separate-stderr env PATH="$TMP/shim:$PATH" bash "$KERN_ROOT/scripts/recall-sessions"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"recall-sessions: sort returned 0 of 3"* ]] || false
}

@test "a sort that drops lines dies loudly" {
  shim sort 'head -n 1'
  run --separate-stderr env PATH="$TMP/shim:$PATH" bash "$KERN_ROOT/scripts/recall-sessions"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"recall-sessions: sort returned 1 of 3"* ]] || false
}

@test "a linked worktree inside worktree.dir is listed once, not once per match" {
  git worktree add --quiet "$REPO/.claude/worktrees/lw2" -b lw2
  lslug=$(printf '%s' "$REPO/.claude/worktrees/lw2" | LC_ALL=C tr -c 'A-Za-z0-9' '-')
  mkdir -p "$P/$lslug"
  printf 'l\n' > "$P/$lslug/lw2.jsonl"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c $'\tlw2\t')" -eq 1 ]
}

@test "a failing awk dies loudly" {
  shim awk 'exit 3'
  run --separate-stderr env PATH="$TMP/shim:$PATH" bash "$KERN_ROOT/scripts/recall-sessions" --topic floci
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"recall-sessions: cannot read"* ]] || false
  [ -z "$output" ]
}

@test "a failing tr dies loudly" {
  shim tr 'exit 1'
  run --separate-stderr env PATH="$TMP/shim:$PATH" bash "$KERN_ROOT/scripts/recall-sessions"
  [ "$status" -eq 1 ]
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
