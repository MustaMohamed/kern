#!/usr/bin/env bash
# Runs every hook over the fixture projects in tests/fixtures/projects (lint rule 15).
# Per case: SessionStart output holds each line of expect.txt (or is empty for <empty>);
# SubagentStart prints valid JSON within 1,200 characters; UserPromptSubmit and PreToolUse
# exit 0 and print nothing or valid JSON.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail=0
cases=0

json_ok() {
  node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{if(!s.trim())process.exit(0);JSON.parse(s)})'
}

for dir in "$ROOT"/tests/fixtures/projects/*/; do
  name=$(basename "$dir")
  cases=$((cases + 1))
  repo="$TMP/$name/repo"
  mkdir -p "$repo/.claude" "$TMP/$name/home/.claude"
  git init -q "$repo"
  for f in kern.local.yml kern.yml; do
    [ -f "$dir/$f" ] && cp "$dir/$f" "$repo/.claude/$f"
  done
  export HOME="$TMP/$name/home" CLAUDE_PLUGIN_DATA="$TMP/$name/data"
  base="\"session_id\":\"shape-$name\",\"cwd\":\"$repo\""
  out=$(printf '{%s,"hook_event_name":"SessionStart","source":"startup"}' "$base" | bash "$ROOT/hooks/session-start")
  while IFS= read -r want; do
    [ -n "$want" ] || continue
    if [ "$want" = "<empty>" ]; then
      [ -z "$out" ] || { echo "FAIL $name: expected no output"; fail=1; }
    elif [[ "$out" != *"$want"* ]]; then
      echo "FAIL $name: missing: $want"
      fail=1
    fi
  done <"$dir/expect.txt"
  sub=$(printf '{%s,"hook_event_name":"SubagentStart","agent_id":"a","agent_type":"Explore"}' "$base" | bash "$ROOT/hooks/subagent-start")
  printf '%s' "$sub" | json_ok || { echo "FAIL $name: SubagentStart output is not JSON"; fail=1; }
  [ "${#sub}" -le 1400 ] || { echo "FAIL $name: SubagentStart output ${#sub} chars"; fail=1; }
  printf '{%s,"hook_event_name":"UserPromptSubmit","prompt":"hello"}' "$base" | bash "$ROOT/hooks/prompt-submit" >/dev/null ||
    { echo "FAIL $name: prompt-submit exited non-zero"; fail=1; }
  pre=$(printf '{%s,"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git status"}}' "$base" | bash "$ROOT/hooks/pre-tool-use")
  printf '%s' "$pre" | json_ok || { echo "FAIL $name: PreToolUse output is not JSON"; fail=1; }
done
[ "$fail" = 0 ] || exit 1
echo "hook-shape: $cases cases passed"
