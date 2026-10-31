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

# each_no_vote, each_denied: hook each line of stdin as the investigator's command. In a line \" is a double
# quote and \n a newline once the JSON payload is decoded.
each_no_vote() {
  while IFS= read -r cmd; do
    hook kern:investigator "$cmd"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || { echo "unexpected vote for: $cmd"; false; }
  done
}
each_denied() {
  while IFS= read -r cmd; do
    hook kern:investigator "$cmd"
    denied || { echo "not denied: $cmd"; false; }
  done
}

@test "read commands get no G18 vote" {
  for cmd in 'git log --oneline -5' 'git -C src blame a.txt' 'rg -n foo src' 'ls -la' 'wc -l a.txt' 'find . -name a.txt' 'sed -n 1,5p a.txt' "sed -n '\$p' a.txt" 'sort -rn a.txt' 'file a.txt' 'printf %s a.txt'; do
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

@test "a variable the shell reads differently from G18 is still denied" {
  # Pilot fix plan 2, Task 7 as ruled in review (MA-254 round 2, events 14 and 15): the shell can change or skip an
  # assignment in ways G18 cannot see, such as single quotes, zsh subscripts and zsh modifiers.
  for cmd in 'w=1; sed -n '"'"'1,$w$1p'"'"' a.txt' 'T=a-o; sort $T[2,3] out.txt a.txt' 'T=ao; sort $T:s/a/-/ out.txt a.txt' \
    'T=a-o; sort \"$T[2,3]\" out.txt a.txt' 'T=ao; sort \"$T:s/a/-/\" out.txt a.txt'; do
    hook kern:investigator "$cmd"
    denied || { echo "not denied: $cmd"; false; }
  done
}

@test "the pilot's read-only investigator commands get no vote" {
  each_no_vote <<'EOF'
git status -sb | head -2; git rev-parse --short HEAD
for f in a.ts b.ts; do cat -n \"$f\"; done
f=$(git ls-files | grep -i 'entity.ts$'); echo \"$f\"; grep -n Column \"$f\"
d=src/x; cat -n $d/a.ts $d/b.ts; grep -n cycle $d/a.ts
rg -n \"Props|onAdd|=>\" src/a.tsx | head -8
grep -n 'x$' a.ts
T=src/a; cat -n $T/a.txt
T=src; grep -n foo ${T}/a.txt | head -5
T=src; for x in a b; do cat $T/$x; done
EOF
}

@test "the pilot's writes stay denied through a loop, a variable or a substitution" {
  each_denied <<'EOF'
for f in a b; do rm \"$f\"; done
f=$(mktemp); echo x > \"$f\"
for f in $(cat list); do cat \"$f\"; done
sed -i 's/a/b/' a.ts
EOF
}

@test "a for over literal words is read word by word" {
  each_no_vote <<'EOF'
for f in \"a.ts\" 'b.ts'; do echo \"== $f\"; head -5 ${f}; done
for f in a b\ndo\n  cat -n $f\n  wc -l $f\ndone
for f in a b; do grep -n x $f 2>/dev/null | head -3; done | sort -rn
for f in a b; do git show HEAD:src/$f | head -5; done; for f in c d; do cat $f; done
for f in a b; do sed -n 1,5p $f; done
for f in a b; do cat $f 2>&1; done
for f in a b; do cat $f &>/dev/null; done
EOF
  each_denied <<'EOF'
for f in; do cat a; done
for f in *.ts; do cat \"$f\"; done
for f in {a,b}; do cat \"$f\"; done
for f in ~/a b; do cat \"$f\"; done
for f in 'a b' c; do cat \"$f\"; done
for f in $d/a; do cat \"$f\"; done
d=a; for f in $d b; do cat \"$f\"; done
for f; do cat \"$f\"; done
for f g in a b; do cat \"$f\"; done
for file in a b; do cat \"$file\"; done
for ((i = 0; i < 2; i++)); do cat a; done
for f (a b) cat $f
for f in a b; cat $f
for f in a -o; do sort $f out.txt a.txt; done
for f in a b; do $f x; done
for f in a b; do cat \"$f\" > out.txt; done
for f in a b; do cat \"$f\"; done > out.txt
for f in a b; do cat \"$f\"; done 2> err.txt
for f in a b; do for g in c d; do cat $f$g; done; done
for f in a b; do d=$f; cat $d; done
for f in a b; do d=x; cat $d/$f; done
for f in a b; do cat $f; done; cat $f
for f in a b; do cat $f
while true; do cat a; done
EOF
}

@test "a one-letter variable set to a plain value is read as that value" {
  each_no_vote <<'EOF'
d='src/x'; cat \"$d\"/a.ts
d=src && cat ${d}/a.ts
d=src\ncat $d/a.ts
d=a.ts; sort -rn $d
d=src; find $d -name a.ts
d=a; git log --oneline -- $d
d=a; d=b; cat $d
d=a; cat $d\\\n/b.ts
EOF
  each_denied <<'EOF'
d=-o; sort $d out.txt a.txt
d=rm; $d a
d=a; rm $d
d=
d='a b'; cat $d
d=*; cat $d
d=~/a; cat $d
d=a\\ b; cat $d
d=a; e=$d; cat $e
d=a e=b; cat $d
d=a cat $d
d+=a; cat $d
file=a; cat $file
path=/tmp; cat a
cat $d
cat $HOME/a
d=a; cat $da
d=a; cat ${d:-b}
d=a; cat ${#d}
d=a; cat $d$(ls)
true && d=a; cat $d
true || d=a; cat $d
d=a || cat $d
d=a | cat $d
d=a & cat $d
d=a && e=b; cat $e
(d=a); cat $d
{ d=a; }; cat $d
if true; then d=a; fi; cat $d
if true; then true; d=a; fi; cat $d
d=a; cat <(ls $d)
d=a; true && { true; d=b; }; cat $d
d=a; cat <<E\nd=b\nE\ncat $d
d=a; cat b # ; d=c\ncat $d
d=\"a\\b\"; cat $d
c=cat; $c a
d=a; cat <<EOF2\n$d\nEOF2
EOF
}

@test "a longer variable name gets the advice to use one letter only when that would pass" {
  while IFS= read -r cmd; do
    hook kern:investigator "$cmd"
    denied || { echo "not denied: $cmd"; false; }
    [[ "$output" == *"use a one-letter name"* ]] || { echo "no advice: $cmd"; false; }
  done <<'EOF'
file=a; cat $file
file=$(ls); cat \"$file\"
for file in a b; do cat \"$file\"; done
d=a; file=b; cat ${file}
EOF
  while IFS= read -r cmd; do
    hook kern:investigator "$cmd"
    denied || { echo "not denied: $cmd"; false; }
    [[ "$output" != *"use a one-letter name"* ]] || { echo "wrong advice: $cmd"; false; }
  done <<'EOF'
rm a
for f in a b; do rm \"$f\"; done
f=$(ls); sort $f out.txt
d=a; cat $file
cat $HOME/a
PATH=/tmp; cat a
rm a; file=b
file=a.ts; cat a.ts
rm a; file=b; cat $file
for file in a b; do cat a; done
EOF
}

@test "G18 reads a list across a newline, a joined line and the byte after a variable as the shell does" {
  each_denied <<'EOF'
d=-o; true ||\nd=a; sort $d out.txt a.txt
d=-o; test -f missing &&\nd=a; sort $d out.txt a.txt
d=-o; cat a |\nd=a; sort $d out.txt a.txt
x=a; sort $x\\\ny-o out.txt a.txt
T=ao; sort $T\\\n:s/a/-/ out.txt a.txt
T=a-o; sort $T\\\n[2,3] out.txt a.txt
sort a.txt $\\\n(echo -ob.txt)
x=a; sort $xé-o out.txt a.txt
EOF
}

@test "a continuation that the shell keeps or that splits an operator is denied" {
  each_denied <<'EOF'
cat a\\\n#b; rm c
cat a # b\\\nrm c
cat a\n# b\\\nrm c
cat a \\\n# b\\\nrm c
d='a\\\n-o'; sort $d out.txt a.txt
d='x\\\n-delete'; find . $d
for f in 'a\\\n-o'; do sort $f out.txt a.txt; done
cat <\\\n<'E'\nb\\\nE\nrm a\nE
EOF
}

@test "_g18_join removes a line continuation and stops where the shell keeps one" {
  # shellcheck source=/dev/null
  . "$KERN_ROOT/hooks/guards/g18-readonly-agent.sh"
  [ "$(_g18_join $'a\\\nb')" = ab ]
  [ "$(_g18_join $'a\\\\\nb')" = $'a\\\\\nb' ]
  [ "$(_g18_join $'a\\\\\\\nb')" = $'a\\\\b' ]
  run _g18_join $'a # b\\\nc'
  [ "$status" -ne 0 ]
  run _g18_join $'a <<E \\\nb'
  [ "$status" -ne 0 ]
  run _g18_join $'a \'b\\\nc\''
  [ "$status" -ne 0 ]
  run _g18_join $'cat <\\\n<E'
  [ "$status" -ne 0 ]
  [ "$(_g18_join $'\"it\'s\\\nb\"')" = "\"it'sb\"" ]
}

@test "an assignment of a read-only substitution is read as an unknown word" {
  each_no_vote <<'EOF'
f=\"$(git rev-parse --short HEAD)\"; echo $f
d=src; f=$(ls $d | head -1); cat \"$d/$f\"
f=$(git ls-files | head -1); g=$(cat $f | head -1); echo \"$g\"
f=$(git ls-files | grep -c x) && echo \"$f\"
EOF
  each_denied <<'EOF'
f=$(rm a); echo \"$f\"
f=$(cat a | sh); echo \"$f\"
f=$(cat a > b); echo \"$f\"
f=$(cat $(ls)); echo \"$f\"
f=$(g=a; cat $g); echo \"$f\"
f=$(for g in a b; do cat $g; done); echo \"$f\"
f=$(ls)x; cat $f
f=a$(ls); cat $f
f=$(ls)$(ls); cat $f
f=`ls`; cat $f
f=$(ls); sort $f out.txt
f=$(ls); rg -n x $f
f=$(ls); sed -n 1p $f
f=$(ls); git log $f
f=$(ls); find . $f
f=$(ls); printf $f
f=$(ls); $f a
f=$(ls); for g in $f; do cat $g; done
f=$(ls); cat $f > out.txt
cat $(ls)
EOF
}

@test "a quoted pattern is data" {
  each_no_vote <<'EOF'
rg -n 'a => b' a.ts
rg -n '$(foo)' a.ts
rg -n 'a <(b' a.ts
rg -n \"a > b\" a.ts
rg -n \"a <(b\" a.ts
rg -n a\\>b a.ts
git log --format='%h > %s' -1
grep -n \"x$\" a.ts
grep -n x$ a.ts
grep -n x$
grep x$ | head
rg foo$
git ls-files | grep tsx$
grep x$ 2>&1
cat a.txt >/dev/null 2>/dev/null
EOF
  each_denied <<'EOF'
rg -n \"$(foo)\" a.ts
rg -n \"a\" a.ts > \"b\"
rg -n 'a' a.ts >'b'
cat a.ts > b'
cat 'a > b
cat a >(cat)
grep -n \"$x\" a.ts
grep x$2>&1
rg -$0>&1
d=a; cat $d; grep x$
EOF
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
  for cmd in 'IFS=/; cat -n a.txt' 'PATH=/tmp; cat a.txt' 'T=-o; sort $T out.txt a.txt' \
    '{cat,a.txt}' 'rg -n foo x{,--pre=sh}' 'rg -n foo -{-pre=sh,x}' 'rg -n foo \"-\"{-pre=sh,x}' 'sed -n {1w/tmp/x,p} a.txt' 'cat a{1..3}.txt' 'cat {a,{b,c}}.txt' \
    'cat \"$(id)\"' 'rg -n \"foo`id`\" a.md' \
    'printf -v PATH %s /tmp; cat a.txt' 'printf -- %s a' \
    'git -C {.,branch} log' 'sed -n 1p {a,b}.txt' 'find {.,src} -name x'; do
    hook kern:investigator "$cmd"
    denied || { echo "not denied: $cmd"; false; }
  done
}
