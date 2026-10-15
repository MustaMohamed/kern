#!/usr/bin/env bats
# Every command that diagnose's forensics reference and the investigator agent tell the investigator to
# run passes G18, so the investigator is never told to run what its guard denies.

load ../helpers/common

setup() {
  K="$(kern_root)"
  export KERN_ROOT="$K" CWD="$BATS_TEST_TMPDIR"
  for lib in json settings state decide gitctx; do
    # shellcheck source=/dev/null
    . "$K/hooks/lib/$lib.sh"
  done
  # shellcheck source=/dev/null
  . "$K/hooks/guards/g18-readonly-agent.sh"
}

# commands FILE: the backticked shell commands in FILE, one per line.
commands() {
  grep -o '`[^`]*`' "$1" | tr -d '`' |
    grep -E '^(git|rg|grep|ls|cat|head|tail|wc|find|sed|sort|cut|jq|awk|zcat|gzip|sqlite3|uniq|tee|xargs|python3?|node) ' || true
}

@test "each backticked command in forensics.md and investigator.md is on G18's allowlist" {
  [ -f "$K/skills/diagnose/references/forensics.md" ]
  [ -f "$K/agents/investigator.md" ]
  # forensics.md must name commands of its own, so the check cannot pass on investigator.md alone.
  [ -n "$(commands "$K/skills/diagnose/references/forensics.md")" ]
  cmds=$(commands "$K/skills/diagnose/references/forensics.md"; commands "$K/agents/investigator.md")
  while IFS= read -r c; do
    g18_allowed "$c" || { echo "G18 denies: $c"; return 1; }
  done <<EOF
$cmds
EOF
}
