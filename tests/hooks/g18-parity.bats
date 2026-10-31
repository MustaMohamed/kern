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
    grep -E '^((git|rg|grep|ls|cat|head|tail|wc|find|sed|sort|cut|jq|awk|zcat|gzip|sqlite3|uniq|tee|xargs|python3?|node|for) |[A-Za-z]=)' || true
}

@test "each backticked command in forensics.md and investigator.md is on G18's allowlist" {
  [ -f "$K/skills/diagnose/references/forensics.md" ]
  [ -f "$K/agents/investigator.md" ]
  # forensics.md must name commands of its own, so the check cannot pass on investigator.md alone.
  [ -n "$(commands "$K/skills/diagnose/references/forensics.md")" ]
  cmds=$(commands "$K/skills/diagnose/references/forensics.md"; commands "$K/agents/investigator.md")
  while IFS= read -r c; do
    if _g18_denies "$c"; then echo "G18 denies: $c"; return 1; fi
  done <<EOF
$cmds
EOF
}

@test "each backticked command in forensics.md and investigator.md passes as a loop body" {
  cmds=$(commands "$K/skills/diagnose/references/forensics.md"; commands "$K/agents/investigator.md")
  [ -n "$cmds" ]
  while IFS= read -r c; do
    if _g18_denies "for f in a b; do $c; done"; then echo "G18 denies: $c"; return 1; fi
  done <<EOF
$cmds
EOF
}

@test "G18 still denies writes and programs the investigator must not run" {
  for c in "sed -i s/a/b/ app.log" "echo x >f" "awk '{print}' app.log" "rg --pre cat x app.log" "sort -o out.txt in.txt" "git -c core.pager=cat log"; do
    if g18_allowed "$c"; then echo "G18 allows: $c"; return 1; fi
    if ! _g18_denies "for f in a b; do $c; done"; then echo "G18 allows in a loop: $c"; return 1; fi
    if ! _g18_denies "f=\$($c); echo \"\$f\""; then echo "G18 allows in a substitution: $c"; return 1; fi
  done
}

@test "the parity check fails when a command that G18 denies is planted in a reference" {
  printf 'Run `awk '"'"'{print}'"'"' app.log` now.\n' > "$BATS_TEST_TMPDIR/planted.md"
  cmds=$(commands "$BATS_TEST_TMPDIR/planted.md")
  [ -n "$cmds" ]
  _g18_denies "$cmds"
}

@test "the parity check fails when a loop or an assignment that G18 denies is planted in a reference" {
  # shellcheck disable=SC2016 # a literal command
  printf 'Run `for f in a b; do rm "$f"; done` now.\nRun `f=$(mktemp); cat "$f"` now.\n' > "$BATS_TEST_TMPDIR/planted.md"
  cmds=$(commands "$BATS_TEST_TMPDIR/planted.md")
  [ "$(printf '%s\n' "$cmds" | wc -l)" -eq 2 ]
  while IFS= read -r c; do
    _g18_denies "$c"
  done <<EOF
$cmds
EOF
}
