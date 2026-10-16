#!/usr/bin/env bash
# measure.sh KERN_DIR FIXTURE...: rendered kernel chars per fixture, root normalized to 52 chars.
K=$1; shift
S=$(mktemp -d)
git init -q "$S/r"; mkdir -p "$S/r/.claude" "$S/h" "$S/d"
for fx in "$@"; do
  rm -f "$S/r/.claude/"kern*.yml
  [ "$fx" = none ] || cp "$K/tests/fixtures/projects/$fx/"kern*.yml "$S/r/.claude/" 2>/dev/null
  out=$(HOME="$S/h" CLAUDE_PLUGIN_DATA="$S/d" bash "$K/hooks/session-start" <<<"{\"session_id\":\"m1\",\"source\":\"startup\",\"cwd\":\"$S/r\",\"hook_event_name\":\"SessionStart\"}")
  norm=${out//"$K"/\/Users\/someone\/.claude\/plugins\/cache\/kern\/kern\/0.1.0}
  echo "$fx: ${#norm} chars"
done
rm -rf "$S"
