#!/usr/bin/env bats
# tests/scripts/recall-sessions.bats

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  # The caller's Claude Code session id would mark one of its sessions current; each test sets its own.
  unset CLAUDE_CODE_SESSION_ID
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
  # Only the history read fails; the slug and the settings reads use the real awk.
  shim awk "case \"\$*\" in *history.jsonl*) exit 3 ;; esac; exec $(command -v awk) \"\$@\""
  run --separate-stderr env PATH="$TMP/shim:$PATH" bash "$KERN_ROOT/scripts/recall-sessions" --topic floci
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"recall-sessions: cannot read"* ]] || false
  [ -z "$output" ]
}

@test "a failing or empty-handed slug dies loudly" {
  shim awk "[ -z \"\${KERN_SLUG_IN+x}\" ] || exit 1; exec $(command -v awk) \"\$@\""
  run --separate-stderr env PATH="$TMP/shim:$PATH" bash "$KERN_ROOT/scripts/recall-sessions"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"recall-sessions: cannot slug $REPO"* ]] || false
  [ -z "$output" ]
  shim awk "[ -z \"\${KERN_SLUG_IN+x}\" ] || exit 0; exec $(command -v awk) \"\$@\""
  run --separate-stderr env PATH="$TMP/shim:$PATH" bash "$KERN_ROOT/scripts/recall-sessions"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"recall-sessions: cannot slug $REPO"* ]] || false
  [ -z "$output" ]
}

# jslug PATH [HASH]: Claude Code's transcript folder name for PATH, computed as its JS computes it (2.1.308,
# functions k and J0): every UTF-16 code unit outside A-Za-z0-9 becomes -, and a name over 200 characters
# is cut to 200 and gets -HASH (the real hash is Claude Code's own; any suffix stands in for it).
jslug() {
  node -e 'const n = process.argv[1].replace(/[^a-zA-Z0-9]/g, "-"); process.stdout.write(n.length <= 200 ? n : n.slice(0, 200) + "-" + process.argv[2])' "$1" "${2:-h4sh}"
}

@test "a path with an é, a 3-byte character or an emoji finds the folder Claude Code names" {
  # é is 2 UTF-8 bytes and 1 UTF-16 unit, 中 is 3 bytes and 1 unit, 😀 is 4 bytes and 2 units.
  [ "$(jslug "/proj"$'\303\251'"/repo")" = "-proj--repo" ]
  [ "$(jslug "/"$'\360\237\230\200'"/repo")" = "----repo" ]
  for name in "proj"$'\303\251' "c"$'\344\270\255'"k" "e"$'\360\237\230\200'"m"; do
    R="$TMP/$name/repo"
    mkdir -p "$R"
    git init -q "$R"
    s=$(jslug "$R")
    mkdir -p "$P/$s"
    printf 'u\n' > "$P/$s/u.jsonl"
    cd "$R"
    run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [ "${lines[0]##*$'\t'}" = "$P/$s/u.jsonl" ]
  done
}

@test "a path whose folder name passes 200 characters finds its folder by the transcript's cwd" {
  R="$TMP/long/$(printf '%*s' $((210 - ${#TMP} - 6)) '' | tr ' ' d)"
  [ "${#R}" -eq 210 ]
  mkdir -p "$R"
  git init -q "$R"
  s=$(jslug "$R" abc123)
  # A second path sharing the first 200 characters: same prefix, its own hash, a cwd that only starts with R.
  d=$(jslug "${R}x" zzz999)
  [ "${s%-abc123}" = "${d%-zzz999}" ]
  mkdir -p "$P/$s" "$P/$d" "$P/$(jslug "$R" | cut -c1-200)"
  { printf '{"type":"queue-operation"}\n'; printf '{"type":"user","cwd":"%s","sessionId":"long"}\n' "$R"; } > "$P/$s/long.jsonl"
  printf '{"type":"user","cwd":"%s","sessionId":"decoy"}\n' "${R}x" > "$P/$d/decoy.jsonl"
  printf 'cut\n' > "$P/$(jslug "$R" | cut -c1-200)/cut.jsonl"
  cd "$R"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "${lines[0]}" == session$'\t'*$'\tlong\t'*$'\t'"$P/$s/long.jsonl" ]] || false
}

@test "a worktree.dir whose folder name passes 200 characters takes the cut folders whose cwd lies under it" {
  R="$TMP/lp/$(printf '%*s' $((190 - ${#TMP} - 4)) '' | tr ' ' d)"
  [ "${#R}" -eq 190 ]
  mkdir -p "$R/.claude/worktrees"
  git init -q "$R"
  # A removed worktree under the worktree dir, and a path outside it with the same first 200 characters.
  s=$(jslug "$R/.claude/worktrees/gone" abc123)
  d=$(jslug "$R/.claude/wx/other" zzz999)
  [ "${s%-abc123}" != "$s" ] && [ "${s:0:200}" = "${d:0:200}" ]
  mkdir -p "$P/$s" "$P/$d"
  printf '{"type":"user","cwd":"%s","sessionId":"gone"}\n' "$R/.claude/worktrees/gone" > "$P/$s/gone.jsonl"
  printf '{"type":"user","cwd":"%s","sessionId":"other"}\n' "$R/.claude/wx/other" > "$P/$d/other.jsonl"
  cd "$R"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "${lines[0]}" == session$'\t'*$'\tgone\t'*$'\t'"$P/$s/gone.jsonl" ]] || false
}

@test "the session CLAUDE_CODE_SESSION_ID names is marked current where it sorts, and no other" {
  CLAUDE_CODE_SESSION_ID=a run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 3 ]
  [[ "${lines[0]}" == session$'\t'*$'\t'b$'\t'* ]] || false
  [[ "${lines[1]}" == session$'\t'*$'\t'w$'\t'* ]] || false
  [[ "${lines[2]}" == current$'\t'*$'\t'a$'\t'3$'\t'*"/a.jsonl" ]] || false
  # An id that names no listed session, and no id at all (setup), mark nothing.
  CLAUDE_CODE_SESSION_ID=nope run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions"
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | grep -c '^session')" -eq 3 ]
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions"
  [ "$(printf '%s\n' "$output" | grep -c '^session')" -eq 3 ]
}

@test "--days 0 and 00 are usage errors" {
  for d in 0 00; do
    run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --days "$d"
    [ "$status" -eq 2 ]
    [[ "$stderr" == usage:* ]] || false
    [ -z "$output" ]
  done
}

@test "in a submodule or a separate-git-dir checkout, the sessions are the checkout's, not the git dir's" {
  S="$TMP/sub"
  git init -q -b main "$S"
  git -C "$S" -c user.name=t -c user.email=t@t commit -q --allow-empty -m s
  git -C "$REPO" -c protocol.file.allow=always submodule add -q "$S" mod
  M=$(cd "$REPO/mod" && pwd -P)
  mkdir -p "$P/$(jslug "$M")"
  printf 'm\n' > "$P/$(jslug "$M")/mod.jsonl"
  hist_line mod "$M" "floci in the submodule"
  cd "$REPO/mod"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --topic floci
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [[ "${lines[0]}" == session$'\t'*$'\tmod\t'*"/mod.jsonl" ]] || false
  [[ "${lines[1]}" == prompt$'\t'*$'\tmod\tfloci in the submodule' ]] || false
  W="$TMP/sepwt"
  git init -q -b main --separate-git-dir "$TMP/sepgit" "$W"
  mkdir -p "$P/$(jslug "$W")"
  printf 's\n' > "$P/$(jslug "$W")/sep.jsonl"
  cd "$W"
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "${lines[0]}" == session$'\t'*$'\tsep\t'*"/sep.jsonl" ]] || false
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

@test "CLAUDE_CONFIG_DIR names the folder that holds projects and history.jsonl" {
  run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --topic floci
  want=$output
  mv "$HOME/.claude" "$TMP/cc"
  mkdir -p "$HOME/.claude"
  CLAUDE_CONFIG_DIR="$TMP/cc" run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions" --topic floci
  [ "$status" -eq 0 ]
  [ -n "$output" ]
  # The same sessions and prompts; each session's path now names the config dir.
  [ "${output//$TMP\/cc/$HOME/.claude}" = "$want" ]
  chmod 000 "$TMP/cc/projects"
  CLAUDE_CONFIG_DIR="$TMP/cc" run --separate-stderr bash "$KERN_ROOT/scripts/recall-sessions"
  chmod 755 "$TMP/cc/projects"
  [ "$status" -eq 1 ]
}

@test "the test env drops a CLAUDE_CONFIG_DIR the caller set" {
  export CLAUDE_CONFIG_DIR="$TMP/elsewhere"
  wt_test_env
  [ -z "${CLAUDE_CONFIG_DIR+x}" ]
}
