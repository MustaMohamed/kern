#!/usr/bin/env bats
# tests/hooks/g18.bats

load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  mkdir -p "$CLAUDE_PLUGIN_DATA/sessions"
  export KERN_GUARDS=g18
}

# payload AGENT_TYPE COMMAND: a PreToolUse Bash payload; AGENT_TYPE may be empty. COMMAND has no double quotes.
payload() {
  local extra=''
  [ -n "$1" ] && extra=",\"agent_id\":\"a1\",\"agent_type\":\"$1\""
  printf '{"session_id":"s1","cwd":"%s","hook_event_name":"PreToolUse","permission_mode":"default","tool_name":"Bash","tool_input":{"command":"%s"}%s}' "$REPO" "$2" "$extra"
}

hook() { run bash "$KERN_ROOT/hooks/pre-tool-use" <<< "$(payload "$1" "$2")"; }
autopilot() { printf 'voice: normal\nsurface: auto\nautopilot: on\n' > "$CLAUDE_PLUGIN_DATA/sessions/s1.state"; }
denied() { [[ "$output" =~ \"permissionDecision\":\ *\"deny\" ]] && [[ "$output" == *"kern G18: "* ]]; }

@test "read commands get no G18 vote" {
  for cmd in 'git log --oneline -5' 'git -C src blame a.txt' 'rg -n foo src' 'ls -la' 'wc -l a.txt' 'find . -name a.txt' 'sed -n 1,5p a.txt' "sed -n '\$p' a.txt" 'sort -rn a.txt' 'file a.txt'; do
    hook kern:investigator "$cmd"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || { echo "unexpected vote for: $cmd"; false; }
  done
}

@test "pipes and stderr to /dev/null stay allowed" {
  hook kern:investigator 'git log --oneline 2>/dev/null | head -n 5'
  [ -z "$output" ]
  hook kern:investigator 'cat a.txt 2>&1 | wc -l'
  [ -z "$output" ]
}

@test "writes and unknown commands are denied" {
  for cmd in 'git commit -m wip' 'git checkout main' 'rm -rf build' 'sed -i s/a/b/ a.txt' 'find . -name x -delete' 'npm test' 'git diff --output=x.patch' 'sort -o out.txt a.txt' \
    'sort -uo out.txt a.txt' 'sort --compress-program=sh a.txt' 'file -C -m magic' 'uniq a.txt out.txt' 'sed -n 1w/tmp/out.txt a.txt' \
    'git -c core.pager=sh log' 'git -c diff.external=sh diff' 'git --config-env=core.pager=X log' 'git grep -Ocat foo' 'git grep --open-files-in-pager=cat foo' 'rg --pre cat foo' \
    'sed -n 1p -i a.txt' 'sed -n 1p a.txt -i' 'sed -n 1p --in-place=.bak a.txt' "sed -n 1p -e 'w /tmp/x' a.txt" 'rg -nz foo'; do
    hook kern:investigator "$cmd"
    denied || { echo "not denied: $cmd"; false; }
  done
}

# In these lists \" is a double quote and \\ a backslash once the JSON payload is decoded.
@test "an option word built by quotes, escapes or expansion is still denied" {
  for cmd in 'sort \"-o\" out.txt a.txt' \
    "sort '-o' out.txt a.txt" "find . '-delete'" "find . -dele''te" "sed -n 1p '-i' a.txt" 'sed -n 1p \\-i a.txt' \
    "git '-c' core.pager=sh log" "rg '-z' foo" "file '-C' -m magic" 'sort {-o,out.txt} a.txt' 'sed -n 1p {-i,a.txt}' \
    'sort ${x:--o} out.txt a.txt' 'echo -o; sort $_ out.txt a.txt' "sort \$'-o' out.txt a.txt" 'sed -n \"$p\" a.txt'; do
    hook kern:investigator "$cmd"
    denied || { echo "not denied: $cmd"; false; }
  done
}

@test "abbreviated long options and short-option clusters are still denied" {
  for cmd in 'git grep --op=cat foo' 'git grep -nOcat foo' 'sort --out=out.txt a.txt' 'sort --co=sh a.txt' \
    'file --comp -m magic' 'file -bC -m magic'; do
    hook kern:investigator "$cmd"
    denied || { echo "not denied: $cmd"; false; }
  done
}

@test "an option that runs a program is denied: rg --hostname-bin, file -z and -Z" {
  for cmd in 'rg --hostname-bin=./h.sh foo' 'rg --hostname-bin ./h.sh foo' "rg -n '--hostname-bin=hostname' foo" \
    'file -z a.gz' 'file -Z a.gz' 'file -bz a.gz' 'file -bZ a.gz' 'file --uncompress a.gz' 'file --uncompress-noreport a.gz' \
    'file --uncompress-n a.gz'; do
    hook kern:investigator "$cmd"
    denied || { echo "not denied: $cmd"; false; }
  done
}

@test "a redirect that only looks like 2>&1 or /dev/null is denied" {
  for cmd in 'cat a.txt >&1x' 'cat a.txt 2>&1y' 'cat a.txt >/dev/nullx' 'cat a.txt &>/dev/null.txt'; do
    hook kern:investigator "$cmd"
    denied || { echo "not denied: $cmd"; false; }
  done
}

@test "quoted arguments, git's @{ } and stream redirects stay allowed" {
  for cmd in "rg -n 'ERROR|WARN' a.txt" 'sed -n \"1,5p\" a.txt' 'sed -n 1,20p' 'git log @{u}..HEAD' 'git log -1 HEAD@{1}' \
    \"git\"' log -1' 'cat a.txt >/dev/null' 'cat a.txt &>/dev/null' 'echo hi >&2' "jq '{a: .b}' x.json" 'git log -SOpen'; do
    hook kern:investigator "$cmd"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || { echo "unexpected vote for: $cmd"; false; }
  done
}

@test "a file redirect is denied" {
  hook kern:investigator 'git log > out.txt'
  denied
  hook kern:investigator 'echo hi >> notes.txt'
  denied
}

@test "a denied command anywhere in a chain denies the call" {
  hook kern:investigator 'git log -1 && git push origin main'
  denied
}

@test "other agents and the main session get no G18 vote" {
  hook '' 'rm -rf build'
  [ -z "$output" ]
  hook kern:implementer 'rm -rf build'
  [ -z "$output" ]
}

@test "autopilot changes nothing for G18" {
  autopilot
  hook kern:investigator 'git log --oneline -5'
  [ -z "$output" ]
  hook kern:investigator 'git commit -m wip'
  denied
}

@test "the dispatcher lists g18 among the guards it expects" {
  grep -q '^KERN_GUARD_IDS=".* g18[ "]' "$KERN_ROOT/hooks/pre-tool-use"
}

@test "a one-letter variable set once to a plain path is read as that path" {
  # Pilot fix plan 2, Task 7 (MA-254 round 2, events 14 and 15): T=src/...; cat -n $T/... was denied for the assignment.
  for cmd in 'T=src/a; cat -n $T/a.txt' 'T=src; grep -n foo ${T}/a.txt | head -5' "f='/tmp/x.txt'; grep -n foo \$f" \
    'cd src; T=src/a; cat -n $T/b.txt; git grep -n foo' 'T=src && C=docs; cat $T/a.txt $C/b.md'; do
    hook kern:investigator "$cmd"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || { echo "unexpected vote for: $cmd"; false; }
  done
}

@test "a brace list of file names and an escaped backtick in double quotes pass" {
  # Events 16 and 17: grep -n -o "...[^']*" .../{a,b}.md, and rg -n -o "...[^'\`]*" with the backtick escaped.
  bt='rg -n -o \"foo[^'"'"'\\`]*\" a.md'
  for cmd in 'grep -n -o foo src/{a,b}.md' 'rg -n foo docs/{x,y}.md | head' 'ls {src,docs}' "$bt" 'git log -1 HEAD@{1}'; do
    hook kern:investigator "$cmd"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || { echo "unexpected vote for: $cmd"; false; }
  done
}

@test "variables, brace lists and backticks that could hide an option or run code are still denied" {
  for cmd in 'IFS=/; cat -n a.txt' 'PATH=/tmp; cat a.txt' 'T=$HOME; cat $T/a.txt' 'T=-o; sort $T out.txt a.txt' \
    'T=a.txt || T=-o; sort $T out.txt' 'T=a.txt cat $T' "T='a b'; cat \$T" 'T=*.txt; cat $T' 'sort $T out.txt; T=-o' \
    'T=a; sort ${T:--o} out.txt' 'T=a; sort $Tx out.txt' \
    '{cat,a.txt}' 'rg -n foo x{,--pre=sh}' 'rg -n foo -{-pre=sh,x}' 'rg -n foo \"-\"{-pre=sh,x}' 'sed -n {1w/tmp/x,p} a.txt' 'cat a{1..3}.txt' 'cat {a,{b,c}}.txt' \
    'cat \"$(id)\"' 'rg -n \"foo`id`\" a.md' 'T=src; for x in a b; do cat $T/$x; done' \
    'test -f /etc/passwd || T=1p; sed -n $T w/tmp/x a.txt' 'T=1p | sed -n $T w/tmp/x a.txt' 'T=1p & sed -n $T w/tmp/x a.txt' \
    '( T=1p ); sed -n $T w/tmp/x a.txt'; do
    hook kern:investigator "$cmd"
    denied || { echo "not denied: $cmd"; false; }
  done
}
