#!/usr/bin/env bats
# hooks/lib/gitctx.sh: command splitting and git parsing that every guard relies on.

load ../helpers/common

setup() {
  export KERN_ROOT
  KERN_ROOT="$(kern_root)"
  for lib in settings gitctx; do
    # shellcheck source=/dev/null
    . "$KERN_ROOT/hooks/lib/$lib.sh"
  done
  export CWD=/tmp
}

# finds CMD SUB: some simple command that git_words prints for CMD is `git SUB` to git_sub and to cmd_head.
finds() {
  local line t hit=""
  while IFS= read -r line; do
    t=$(git_sub "$line") || continue
    if [ "$(printf '%s\n' "$t" | cut -f2)" = "$2" ] && [ "$(cmd_head "$line")" = "git $2" ]; then hit=1; fi
  done <<EOT
$(git_words "$1")
EOT
  [ -n "$hit" ] || { echo "no git $2 in: $1"; git_words "$1"; return 1; }
}

# finds_gh CMD: some simple command that git_words prints for CMD is `gh pr create` to gh_sub.
finds_gh() {
  local line hit=""
  while IFS= read -r line; do
    if [ "$(gh_sub "$line")" = "pr create" ]; then hit=1; fi
  done <<EOT
$(git_words "$1")
EOT
  [ -n "$hit" ] || { echo "no gh pr create in: $1"; git_words "$1"; return 1; }
}

@test "git_words splits chains and keeps quoted separators" {
  run git_words 'cd x && git push origin main; echo "a;b" | grep q || git status'
  [ "${lines[0]}" = "cd x" ]
  [ "${lines[1]}" = "git push origin main" ]
  [ "${lines[2]}" = 'echo "a;b"' ]
  [ "${lines[3]}" = "grep q" ]
  [ "${lines[4]}" = "git status" ]
}

@test "git_words also prints the bodies of bash -c, eval, \$( ) and backticks" {
  run git_words "bash -c 'git stash && git switch main'"
  [[ "$output" == *$'\n'"git stash"$'\n'"git switch main"* ]] || false
  run git_words 'echo $(git push -f) && x=`git reset --hard`'
  [[ "$output" == *$'\n'"git push -f"* ]] || false
  [[ "$output" == *$'\n'"git reset --hard"* ]] || false
}

@test "git_words reads \$(( )) as arithmetic and prints each \$( ) and backtick inside it" {
  run git_words 'echo $(( $(date +%s) - `id -u` + a[$(git push -f)] ))'
  [ "$output" = "$(printf '%s\n' 'echo $(( $(date +%s) - `id -u` + a[$(git push -f)] ))' 'date +%s' 'id -u' 'git push -f')" ]
  run git_words 'echo $(( $(( $(git push -f) )) * 2 ))'
  [ "$output" = "$(printf '%s\n' 'echo $(( $(( $(git push -f) )) * 2 ))' 'git push -f')" ]
  # The inner ( closes before a ) that does not close the outer one: $( ) around a subshell.
  run git_words 'echo $((git push -f) )'
  [[ "$output" == *$'\n'"git push -f"* ]] || false
  run git_words 'echo $((git stash);(git push -f))'
  [[ "$output" == *$'\n'"git stash"$'\n'"git push -f"* ]] || false
}

@test "git_words reads \$(( as \$( ) when bash or zsh may, so a paren it cannot count hides no command" {
  local c
  # bash 5.3, bash 3.2 or zsh 5.9 runs the command in each, and says so on a harmless echo.
  for c in 'echo $((git push -f "))") )' 'echo $((git push -f ")" ))' "echo \$((git push -f ')' ))" \
    'echo $((git push -f `echo ")"` ))' 'echo $((git push -f `echo "))"`) )' 'echo $((git push -f ${x:-))}) )' \
    "echo \$((git push -f \$'))') )" "$(printf '%s\n' 'echo $(( $(git push -f # ))' ') + 1 ))')" \
    "$(printf '%s\n' 'echo $(( $(true # )))' 'git push -f) ))')"; do
    run git_words "$c"
    [[ "$output" == *$'\n'"git push -f"* ]] || { echo "$c -> $output"; return 1; }
  done
}

@test "git_words reads a single quote inside \$(( )) as literal, so a \$( ) or backtick there is a command" {
  local c
  # In $(( )) a single quote is literal when the arithmetic expands, so bash 3.2, bash 5.3 and zsh 5.9
  # all run the backtick or $( ) inside one; git_words must print it. Backtick and $( ), bare, quoted,
  # assigned, nested and as an array subscript.
  for c in "echo \$(( '\`git push -f\`' ))" "echo \"\$(( '\`git push -f\`' ))\"" "x=\$(( '\`git push -f\`' ))" \
    "echo \$(( '\$(git push -f)' ))" "x=\$(( '\$(git push -f)' ))" "echo \$(( \$(( '\$(git push -f)' )) ))" \
    "echo \$(( a['\$(git push -f)'] ))"; do
    run git_words "$c"
    [[ "$output" == *$'\n'"git push -f"* ]] || { echo "$c -> $output"; return 1; }
  done
}

@test "git_words falls back to \$( ) at a case inside \$(( )), so a command there is not hidden" {
  # A case keyword means the $(( is not arithmetic: its ) pattern terminators cannot be paren-counted,
  # so arith() returns 0 and the body is read as a $( ) subshell. Dropping the case rule reads it as
  # arithmetic and hides the bare command, turning this red.
  run git_words 'echo $(( (case x in (x) git push -f ;; esac) ))'
  [[ "$output" == *$'\n'"git push -f"* ]] || false
}

@test "git_words reads \$[ ] old-style arithmetic, so a \$( ) or backtick inside it is a command" {
  local c
  # In $[ ] a single quote is literal, as in $(( )); all three shells run the $( ) or backtick inside
  # one. Single-quoted $( ), single-quoted backtick, and the unquoted form.
  for c in "echo \$[ '\$(git push -f)' ]" "echo \$[ '\`git push -f\`' ]" "echo \$[ \$(git push -f) + 1 ]"; do
    run git_words "$c"
    [[ "$output" == *$'\n'"git push -f"* ]] || { echo "$c -> $output"; return 1; }
  done
}

@test "git_words reads a bare (( )) arithmetic command, so a \$( ) or backtick inside it is a command" {
  local c
  # bash 5.3 and zsh run the $( ) or backtick inside (( '...' )); bash 3.2 errors on it. A single quote
  # in the arithmetic is literal, so the command inside is read.
  for c in "(( '\$(git push -f)' ))" "(( '\`git push -f\`' ))" "if (( '\$(git push -f)' )); then :; fi" \
    "for (( i='\$(git push -f)'; i<1; i++ )); do :; done"; do
    run git_words "$c"
    [[ "$output" == *$'\n'"git push -f"* ]] || { echo "$c -> $output"; return 1; }
  done
  # A subshell ((cmd) ) still splits, and an arithmetic (( )) with no substitution prints no command.
  run git_words 'echo $((git stash);(git push -f))'
  [[ "$output" == *$'\n'"git stash"$'\n'"git push -f"* ]] || false
}

@test "git_words reads a single quote inside \"...\" as literal, so a \$( ) or backtick there is a command" {
  local c
  # Inside double quotes a single quote is literal; all three shells run the $( ) or backtick inside
  # one. 0.3.0 missed echo "'\$(cmd)'". Single quotes, ((-text, backtick, assignment, and an apostrophe.
  for c in "echo \"'\$(git push -f)'\"" "echo \"(( '\$(git push -f)' ))\"" "echo \"'\`git push -f\`'\"" \
    "x=\"'\$(git push -f)'\"" "echo \"it's \$(git push -f)\"" "echo \"\${x:-'\$(git push -f)'}\""; do
    run git_words "$c"
    [[ "$output" == *$'\n'"git push -f"* ]] || { echo "$c -> $output"; return 1; }
  done
}

# has_push OUTPUT: some record of OUTPUT is the command git push --force origin main.
has_push() { printf '%s\n' "$1" | grep -qE '^git push --force origin main( |$)'; }

@test "git_words reads the quotes inside each \$( ) as its own, so a quoted paren or quote there hides no command" {
  local c
  # Every $( ) and backtick starts its own quoting, and a ( or ) inside its quotes opens or closes
  # nothing. bash 3.2, bash 5.3 and zsh 5.9 run the force push in each (re-review Critical 1, the
  # regression, and Critical 2, from 0.3.0), with a quoted ) or ( and a lone " or ' inside $( ).
  for c in "echo \"\$(echo \")\")\" '\"' \$(git push --force origin main)" \
    "echo \$(echo '(' \$(git push --force origin main))" \
    "echo \$(echo \")\") '\"' \$(git push --force origin main)" \
    "echo \$(echo ')' ; git push --force origin main)" \
    "echo \"\$(echo '\"')\" ; git push --force origin main" \
    "echo \"\`git push --force origin main \")\"\`\""; do
    run git_words "$c"
    has_push "$output" || { echo "$c -> $output"; return 1; }
  done
}

# corpus: the shapes of the Task 7 differential sweeps, rounds 1 to 4, one per line as TAG SHAPE. In
# SHAPE, @ and @2 stand for the command and <NL> for a newline. TAG run: bash 3.2, bash 5.3 or zsh 5.9
# runs the command (measured with a harmless marker), so git_words must print it as a record. not: no
# shell runs it. gap: a shell runs it but git_words cannot surface it as a record, while G00 denies it
# under autopilot (Task 7a: a builtin that evaluates a single-quoted substitution as arithmetic, local -i
# included; and an array subscript opening with [$( or [`, written in single quotes or in a quoted
# here-doc body, stored and read later by arithmetic). The exceptions, which no guard sees and the M3 row
# records, are a subscript built at run time and the zsh glob qualifier. A line that starts with # is a
# note.
corpus() {
  cat <<'EOF'
# Rounds 1 to 3.
not echo $(( @ ))
not echo $(( '@' ))
not echo "$(( '@' ))"
not echo $(( "@" ))
not echo "$(( "@" ))"
not echo $(( 'x'@ ))
run echo $(( `@` ))
run echo $(( '`@`' ))
run echo "$(( '`@`' ))"
run echo $(( "`@`" ))
run echo $( @ )
run echo $( ( @ ) )
run echo $(( @ ) )
run echo $(( @ );( @2 ))
run echo $(( '$(@)' ))
run x=$(( '$(@)' ))
run x=$(( '`@`' ))
not echo $(( $(( @ )) ))
run echo $(( $(( '$(@)' )) ))
run echo $(( 1 + $(@) ))
run echo $(( a[$(@)] ))
run echo $(( a[`@`] ))
run echo $(( a['$(@)'] ))
run echo $(( ${x:-$(@)} ))
run echo ${x:-$(@)}
run echo $(( ${x:-`@`} ))
# Round 4 reads this (an unsure $(( is read both ways), though round 3 recorded it as an M3 gap.
run echo $(( $'$(@)' ))
run echo $(( $'x'+$(@) ))
not (( @ ))
run (( $(@) ))
run (( '$(@)' ))
run echo $[ $(@) ]
run echo $[ '$(@)' ]
not echo $(( $(@ #) ))
not echo $(( 1 )) # $(@)
run cat <<< $(( $(@) ))
run case x in x) @ ;; esac
run echo $(( $(case x in x) @ ;; esac) ))
run echo $(( \( $(@) \) ))
run echo $(( $(@) \( ))
run echo $((<NL>$(@)<NL>))
run echo $(( ((1)) + $(@) ))
run echo $(( ( $(@) ) ))
run x=$(( $(@) ))
run n=$(( `@` / 60 ))
run echo $(( $(@) + 1 ))
run echo "$(( $(@) ))"
run echo $[ '$(@)' ]
run echo $[ '`@`' ]
run echo $[ $(@) + 1 ]
run echo $[ `@` + 1 ]
run echo "$[ '$(@)' ]"
run x=$[ '$(@)' ]
run echo $[ a[$(@)] ]
run echo $[ a['$(@)'] ]
run echo $[ $[ '$(@)' ] ]
run echo $[ $(( '$(@)' )) ]
run echo $(( $[ '$(@)' ] ))
run echo $[ ']' + $(@) ]
run echo $[ "]" + $(@) ]
run echo $[ \] + $(@) ]
not echo $[ 1 + $(@)
run echo $[ $(@) ] '$(@2)'
# Round 4 reads this ($[ ] is read whole, past a newline), though round 3 recorded it as an M3 gap.
run echo $[<NL>'$(@)'<NL>]
run (( '`@`' ))
run (( x = '$(@)' ))
run if (( '$(@)' )); then :; fi
run while (( '$(@)' )); do break; done
run (( '$(@)' )) && :
run : ; (( '$(@)' ))
run ( (( '$(@)' )) )
run x=$( (( '$(@)' )) )
run ! (( '$(@)' ))
run for (( i='$(@)'; i<1; i++ )); do :; done
run (( "$(@)" ))
run ((@) )
run ((@);(@2))
run (( @ ) )
run (( ')' ; @ ))
not (( 1 )) '$(@2)'
run echo "'$(@)'"
run echo "(( '$(@)' ))"
run echo "'`@`'"
run x="'$(@)'"
run echo "it's $(@)"
run echo "'"$(@)"'"
not echo "'"'$(@2)'"'"
run echo "a\"b'$(@)'"
not echo "a\\"'$(@2)'
not echo "\$(@2)"
run echo $"'$(@)'"
run cat <<< "'$(@)'"
run echo $(( "'$(@)'" ))
run echo $[ "'$(@)'" ]
run echo "${x:-'$(@)'}"
run echo ${x:-"'$(@)'"}
run echo "$(echo "'$(@)'")"
run echo "`echo "'$(@)'"`"
run echo "a" 'b' "'$(@)'"
run echo "\\'$(@)'"
not printf %s "it's" '$(@2)'
run echo "'$(@)" "'"
run echo "'" $(@)
run echo "$x's" $(@)
run cat <<< '"'$(@)'"'
run echo "'${x}'$(@)"
run (( "'$(@)'" ))
run echo "a\`b'$(@)'"
run echo "'$(( '$(@)' ))'"
# Round 4: quotes across $( ) boundaries, backticks, ANSI-C quotes, comments and subscripts.
run echo "$(echo ")")" '"' $(@)
run echo $(echo '(' $(@))
run echo $(echo ")") '"' $(@)
run echo "`echo ")"`" '"' $(@)
run echo $(echo ')' ; @)
run echo $(echo "(" ; @)
run echo "$(echo "(" ; @)"
run echo $(echo $(echo ')') ; @)
run echo $(echo "$(echo ')')" ; @)
run echo "$(echo '"')" ; @
run x="$(echo "'")" ; @
run echo $(echo "'" ; @)
run echo $(echo "a)b" '(' $(@) ')')
run echo "$(echo ")" '"')" ; @
run echo "$(echo "$(echo '"')")" ; @
run echo $(echo "$(echo "$(echo ")")")" ; @)
run echo "${x:-$(echo ")")}" ; @
run echo $(echo ${x:-")"} ; @)
run echo $(echo $'\')' ; @)
run echo $'it\'s' ; @
run echo $(echo $'(' ; @)
run echo "$(echo `echo ")"`; @)"
run echo "`@ ")"`"
run echo "$(echo `echo '"'`)" ; @
run echo "`echo '"'`" ; @
run echo $(echo `echo '('` ; @)
run echo $(echo `echo "("` ; @)
run echo `echo \`@\``
run echo "`echo \"$(@)\"`"
run echo $(echo `echo \`@\``)
run echo $(echo "it's" ; @)
run echo "$(echo "it's")" ; @
run echo $(echo # it's<NL>@)
run echo $(true # )<NL>@)
run echo $(echo $(( 1 )) '(' ; @)
run echo $(( "(" + $(@) ))
run echo $(echo ${x:-)} ; @)
run x=$(cat <<EOF<NL>it's (<NL>EOF<NL>) ; @
not echo $(echo ")") '$(@2)'
not echo "$(echo ")")" '$(@2)'
not echo $(echo '(' '$(@2)')
not echo "$(echo '"')" '$(@2)'
not echo `echo '`'` ; @2
run a['$(@)']=1
run echo ${a['$(@)']}
run echo "${a['`@`']}"
run a[']']=1; @
run echo x[a'b' ; @ ; echo ]
run echo "$(case x in x) @ ;; esac)"
run echo $(echo "`echo ')'`" ; @)
run echo "$(echo "`echo '"'`")" ; @
run x=$(echo $'\'' ; @)
run echo $(echo $"(" ; @)
run echo "$(echo $'"')" ; @
run echo "${x:-"$(echo ")")"}" ; @
run echo `echo "\`@\`"`
run echo "$(echo "$(echo "'")")" ; @
run echo $(echo '"' "'" ; @)
run (( '$(@)' ')' ))
run echo $(( '$(@)' ')' ))
run echo $[ '$(@)' ']' ]
run (( ')' + '$(@)' ))
run echo $(( (1) '(' '$(@)' ))
# Round 5: case inside $( ) (concern 2); a ) inside ${ } or $[ ] that bash 3.2 closes on (concern 3).
run echo $(case x in x) @ ;; esac)
run echo "$(case x in x) @ ;; esac)"
run echo `case x in x) @ ;; esac`
run echo $(case x in (a|x) @ ;; (y) : ;; esac)
run echo $(case x in a) : ;; x) @ ;; esac)
run echo $(case x in x) case y in y) @ ;; esac ;; esac)
run x=$(case x in x) @ ;; esac)
run echo "$(echo $[)] `@`)"
run echo "$(echo $[ (1) ) ] `@`)"
run echo $(echo ${x:-)} `@`)
run "$("$[')''"']""'""'"""$[)')']`@`''"""")"$((''))
# Task 7a: an unquoted here-doc body undergoes command substitution, so git_words reads its $( ) and
# backticks; a quoted delimiter keeps the body literal (not). A trap handler runs as code, so it is read.
run cat <<EOF<NL>$(@)<NL>EOF
run x=$(cat <<EOF<NL>$(@)<NL>EOF<NL>)
run cat <<-EOF<NL>$(@)<NL>EOF
run cat <<EOF<NL>`@`<NL>EOF
run echo $(cat <<EOF<NL>$(@)<NL>EOF<NL>)
run trap '@' EXIT
run trap '$(@)' EXIT
run trap "@" EXIT
not cat <<'EOF'<NL>$(@)<NL>EOF
not cat <<"EOF"<NL>$(@)<NL>EOF
not cat <<\EOF<NL>$(@)<NL>EOF
# Task 7a fix round 1: a quote in a here-doc body is literal text, so a $( ) inside one runs.
run cat <<EOF<NL>'$(@)'<NL>EOF
run cat <<EOF<NL>${x:-'$(@)'}<NL>EOF
not cat <<EOF<NL>\$(@)<NL>EOF
not local -i n='$(@)'
# Task 7a gaps: a shape a shell runs but git_words cannot surface as a record, yet G00 denies under
# autopilot (g00-unproven.bats). A builtin that evaluates a single-quoted $( ) as arithmetic (let,
# declare -i, typeset -i, local -i, printf -v, read, [[ -eq ]]); and a single-quoted array subscript that
# opens with [$( or [` (optional spaces), stored and read later by arithmetic (echo $((x)), (( )), an
# integer assignment), which fix round 2 made G00 deny by its text.
gap let 'a[$(@)]'
gap declare -i n='a[$(@)]'
gap typeset -i n='a[$(@)]'
gap printf -v 'a[$(@)]' x
gap read 'a[$(@)]'
gap [[ 1 -eq 'a[$(@)]' ]]
gap f(){ local -i n='a[$(@)]'; }; f
gap x='a[$(@)]'; echo $((x))
gap declare -i n; n='a[$(@)]'
gap a='b[ $(@) ]'; (( a ))
# Task 7a fix round 3: a quoted here-doc body stores the subscript literally, and arithmetic evaluates it;
# git_words prints no record for a quoted body, and G00 scans the body for the subscript itself.
gap x=$(cat <<'H'<NL>a[$(@)]<NL>H<NL>); echo $((x))
gap x=$(cat <<"H"<NL>a[$(@)]<NL>H<NL>); echo $((x))
gap x=$(cat <<\H<NL>a[$(@)]<NL>H<NL>); echo $((x))
# No guard sees these, M3 limits recorded in the design spec. A subscript built at run time (here by
# concatenation) and then evaluated waits for one parse per command. A zsh glob qualifier e:'...': runs
# code; it is zsh-only and needs a matching glob.
gap x='a['; x+='$(@)'; x+=']'; echo $((x))
gap echo *(e:'@':)
gap echo *(e:'$(@)':)
EOF
}

@test "git_words prints the command of every sweep shape that bash or zsh runs" {
  local line shape c n=0 bad=""
  while IFS= read -r line; do
    [ "${line%% *}" = run ] || continue
    shape=${line#* }
    c=${shape//<NL>/$'\n'}
    c=${c//@2/git push --force origin main}
    c=${c//@/git push --force origin main}
    n=$((n + 1))
    run git_words "$c"
    has_push "$output" || bad="$bad$shape -> $output"$'\n'
  done <<EOT
$(corpus)
EOT
  [ -z "$bad" ] || { printf 'not read:\n%s' "$bad"; return 1; }
  [ "$n" -eq 172 ]
  [ "$(corpus | grep -c '^not ')" -eq 26 ]
  [ "$(corpus | grep -c '^gap ')" -eq 16 ]
}

@test "the recorded gaps keep the reading the corpus pins: git_words surfaces no force push" {
  # The gap shapes (a builtin that evaluates a single-quoted substitution as arithmetic, and a zsh glob
  # qualifier) run a command git_words cannot surface as a record. G00 denies the builtin shapes under
  # autopilot (g00-unproven.bats); the glob qualifier is an M3 limit. This pins that git_words prints no
  # standalone force push for them, so a change that starts to read one is seen.
  local line shape c
  while IFS= read -r line; do
    [ "${line%% *}" = gap ] || continue
    shape=${line#* }
    c=${shape//<NL>/$'\n'}
    c=${c//@2/git push --force origin main}
    c=${c//@/git push --force origin main}
    run git_words "$c"
    ! has_push "$output" || { echo "surfaced (no longer a gap): $shape -> $output"; return 1; }
  done <<EOT
$(corpus)
EOT
}

@test "git_words reads a case inside \$( ) so the commands between pattern) and ;; are seen" {
  local c
  # case WORD in ... esac: the ) that ends a pattern closes no $( ), a ( before a pattern is optional,
  # and the clause commands are read. bash 5.3 and zsh run the force push in each; bash 3.2 misparses a
  # case in $( ), so nothing runs there, and reading the push shows the guards more (re-review concern 2).
  for c in "echo \$(case x in x) git push --force origin main ;; esac)" \
    "echo \"\$(case x in x) git push --force origin main ;; esac)\"" \
    "echo \`case x in x) git push --force origin main ;; esac\`" \
    "echo \$(case x in (a|x) git push --force origin main ;; (y) : ;; esac)" \
    "echo \$(case x in a) : ;; x) git push --force origin main ;; esac)" \
    "echo \$(case x in x) case y in y) git push --force origin main ;; esac ;; esac)" \
    "echo \$(( \$(case x in x) git push --force origin main ;; esac) ))"; do
    run git_words "$c"
    has_push "$output" || { echo "$c -> $output"; return 1; }
  done
}

@test "a \$( ) body that bash 3.2 ends early at a ) inside \${ } or \$[ ] is read both ways" {
  local c
  # bash 3.2 ends a $( ) at the first ) inside a ${ } or $[ ]; bash 5.3 and zsh read the ${ }/$[ ] whole.
  # git_words prints both readings, so the command bash 3.2 runs after the early ) is still seen
  # (re-review concern 3). The first shape (reduced from the one fuzz case round 4 missed) runs the
  # force push in bash 3.2 only; the others in at least one shell. @ stands for the force push, read
  # from a literal here-doc so the quotes, backticks and $ reach git_words unchanged.
  while IFS= read -r c; do
    c=${c//@/git push --force origin main}
    run git_words "$c"
    has_push "$output" || { echo "$c -> $output"; return 1; }
  done <<'EOT'
"$("$[')''"']""'""'"""$[)')']`@`''"""")"$((''))
echo "$(echo $[)] `@`)"
echo $(echo ${x:-)} `@`)
EOT
}

@test "a command nested past the scanner's depth limit fails closed" {
  # Past 16 nested contexts the scan goes flat and may miss a command, so it prints a $KERN_UNREAD
  # record that G00 denies under autopilot, on top of every body it did find (re-review concern 5).
  local o="" c i
  for ((i = 0; i < 20; i++)); do o="$o\$(echo "; done
  c="echo ${o}git push --force origin main"
  for ((i = 0; i < 20; i++)); do c="$c)"; done
  run git_words "$c"
  [[ "$output" == *'$KERN_UNREAD'* ]] || { echo "$output"; return 1; }
}

@test "git_words reads an unquoted here-doc body for \$( ) and backticks; a quoted delimiter stays unread" {
  # An unquoted here-doc body undergoes command substitution in bash 3.2, bash 5.3 and zsh 5.9, so a
  # $( ) or backtick in it runs and git_words must print it (final review Critical 1). The body is
  # read from a literal here-doc so the quotes, backticks and $ reach git_words unchanged.
  local c
  while IFS= read -r c; do
    c=${c//<NL>/$'\n'}
    c=${c//@/git push --force origin main}
    run git_words "$c"
    has_push "$output" || { echo "unread: $c -> $output"; return 1; }
  done <<'EOT'
cat <<EOF<NL>$(@)<NL>EOF
x=$(cat <<EOF<NL>$(@)<NL>EOF<NL>)
cat <<-EOF<NL>$(@)<NL>EOF
cat <<EOF<NL>`@`<NL>EOF
echo $(cat <<EOF<NL>$(@)<NL>EOF<NL>)
EOT
  # A quoted delimiter (<<'EOF', <<"EOF", <<\EOF) keeps the body literal: nothing runs, no push record.
  while IFS= read -r c; do
    c=${c//<NL>/$'\n'}
    c=${c//@/git push --force origin main}
    run git_words "$c"
    ! has_push "$output" || { echo "leaked: $c -> $output"; return 1; }
  done <<'EOT'
cat <<'EOF'<NL>$(@)<NL>EOF
cat <<"EOF"<NL>$(@)<NL>EOF
cat <<\EOF<NL>$(@)<NL>EOF
EOT
}

@test "git_words reads a here-doc body as here-doc text: its quotes are literal, and the body is no record" {
  # In an unquoted here-doc body a quote is literal text, also inside ${ }, while a $( ) inside it keeps
  # quotes of its own; bash 3.2, bash 5.3 and zsh 5.9 run the command in each shape below (Task 7a
  # fix round 1). The body itself is data, so it is never printed as a command record: only the bodies
  # of its $( ) and backticks are (review Important 1).
  local c
  while IFS= read -r c; do
    c=${c//<NL>/$'\n'}
    c=${c//@/git push --force origin main}
    run git_words "$c"
    has_push "$output" || { echo "unread: $c -> $output"; return 1; }
  done <<'EOT'
cat <<EOF<NL>'$(@)'<NL>EOF
cat <<EOF<NL>${x:-'$(@)'}<NL>EOF
cat <<EOF<NL>a ' b<NL>$(@)<NL>EOF
cat <<EOF<NL>$(echo ')' ; @)<NL>EOF
EOT
  run git_words "$(printf '%s\n' 'cat <<EOF' '$(date)' 'EOF')"
  [ "$output" = "$(printf '%s\n' 'cat <<EOF' 'date')" ] || { echo "$output"; return 1; }
  run git_words "$(printf '%s\n' 'cat <<EOF >notes.txt' 'Built $(date) on `hostname`' 'build log' 'EOF')"
  [ "$output" = "$(printf '%s\n' 'cat <<EOF >notes.txt' 'date' 'hostname')" ] || { echo "$output"; return 1; }
}

@test "a quoted here-doc body is no record; on G00's call it comes as one marked record to scan" {
  # A quoted body is data, so git_words prints no record for it. G00 sets _GW_QB, and then a quoted body
  # that may hold a subscript ([ and a $( or backtick) comes as one record after a \035 byte, which only
  # G00 reads, for the subscript pattern (Task 7a re-review Critical 1).
  local c
  c="$(printf '%s\n' "x=\$(cat <<'H'" 'a[$(git push --force origin main)]' 'H' '); echo $((x))')"
  run git_words "$c"
  [[ "$output" != *$'\035'* ]] || { echo "marked without _GW_QB: $output"; return 1; }
  ! has_push "$output" || { echo "quoted body read: $output"; return 1; }
  _GW_QB=1
  run git_words "$c"
  unset _GW_QB
  [[ "$output" == *$'\035''a[$(git push --force origin main)]'* ]] || { echo "no marked body: $output"; return 1; }
  ! has_push "$output" || { echo "quoted body read: $output"; return 1; }
}

@test "git_words reads a trap handler as a command, so a force push there is seen" {
  # trap HANDLER SIGSPEC runs HANDLER as code at the trap in bash 3.2, bash 5.3 and zsh 5.9; git_words
  # reads the handler, quotes removed, so a force push in it is seen (final review Important 2).
  local c
  for c in "trap 'git push --force origin main' EXIT" \
    "trap '\$(git push --force origin main)' EXIT" \
    "trap -- 'git push --force origin main' INT TERM" \
    "trap \"git push --force origin main\" EXIT"; do
    run git_words "$c"
    has_push "$output" || { echo "$c -> $output"; return 1; }
  done
}

@test "git_words fails closed when an awk program fails, and is unchanged when they succeed" {
  # A stub awk that always fails stands in for a crash: git_words then emits the $KERN_UNREAD record
  # that G00 denies, instead of silently reading nothing (final review Minor 1). When awk succeeds the
  # output is unchanged.
  run git_words 'git status'
  [ "$output" = "git status" ]
  local bin="$BATS_TEST_TMPDIR/awkbin" old="$PATH"
  mkdir -p "$bin"
  printf '%s\n' '#!/bin/sh' 'exit 1' >"$bin/awk"
  chmod +x "$bin/awk"
  PATH="$bin:$PATH"
  run git_words 'git status'
  PATH="$old"
  [[ "$output" == *'$KERN_UNREAD'* ]] || { echo "no fail-closed: $output"; return 1; }
}

@test "git and gh are seen behind shells, wrappers, groups and keywords" {
  for c in 'bash -lc "git stash"' 'sh -ec "git stash"' '/bin/bash -c "git stash"' \
    'nohup bash -c "git stash"' 'command git stash' 'exec git stash' 'time git stash' \
    '(git stash)' '{ git stash; }' 'if true; then git stash; fi' '! git stash' \
    'sudo -u me git stash' 'sudo -E git stash'; do
    finds "$c" stash
    finds_gh "${c/git stash/gh pr create}"
  done
  finds 'for b in a; do git push origin $b; done' push
}

@test "a shell's -c is read in a cluster of any case, after options, -- or -, and value long options" {
  # Each form runs its -c script in bash 3.2, bash 5 or zsh 5.9.
  for c in "bash -Ec 'git push'" 'sh -Cc "git push"' 'bash -xec "git push"' 'bash +c "git push"' \
    "bash -c -- 'git push'" "bash -c - 'git push'" "bash -c -e 'git push'" "bash -c +x 'git push'" \
    "bash -c -o pipefail 'git push'" "bash -oc pipefail 'git push'" "bash -co pipefail 'git push'" \
    "bash -eO extglob -c 'git push'" "bash --rcfile f -c 'git push'" "bash --init-file f -c 'git push'" \
    "bash -rcfile f -c 'git push'" "bash -norc -c 'git push'" "bash --norc --login -c 'git push'" \
    "zsh -opipefail -c 'git push'" "zsh -rcfile 'git push'" "ZSH -c -b 'git push'" \
    "bash -rcfile '\"' -c 'git push'"; do
    finds "$c" push
  done
  # Not -c: -C is noclobber, and - ends the options, so a -c after it names a script file.
  for c in "bash -C 'git push'" "bash - -c 'git push'"; do
    run git_words "$c"
    [ "${#lines[@]}" -eq 1 ] || { echo "$c -> $output"; return 1; }
  done
}

@test "zsh's --emulate takes the next word, so the -c after it is read" {
  finds "zsh --emulate sh -c 'git push'" push
  finds "ZSH --emulate ksh -ec 'git push'" push
  run git_words "zsh --emulate sh 'git push'"
  [ "${#lines[@]}" -eq 1 ]
}

@test "a redirection among a shell's options is not its script" {
  for c in "bash 2>/dev/null -c 'git push'" "bash -c 2>&1 'git push'" "bash >/tmp/log -c 'git push'" \
    "bash -c > /tmp/log 'git push'" "bash -c <<< x 'git push'" "zsh -c 2> err 'git push'"; do
    finds "$c" push
  done
}

@test "env -S splits its line with quotes, as env does" {
  finds "env -S \"bash -c 'git push --force origin main'\"" push
  finds "env -S 'sh -c \"git push\"'" push
  run _cmd_words "env -S \"printf '%s' 'a b' c\\ d\""
  [ "$output" = "$(printf '%s\n' printf %s 'a b' 'c d')" ]
}

@test "a shell that runs a -c script reads its here-doc as data, in any cluster form" {
  for c in "bash -Ec 'cat'" "bash -c -- 'cat'" "bash --rcfile f -c 'cat'"; do
    run git_words "$(printf '%s\n' "$c <<'EOF'" 'git push --force' 'EOF')"
    [ "${#lines[@]}" -eq 2 ] || { echo "$c -> $output"; return 1; }
    [ "${lines[1]}" = cat ] || { echo "$c -> $output"; return 1; }
  done
}

@test "git is seen behind wrapper options, env -S, shell options, timeout and nice" {
  for c in 'exec -a x git push origin main' 'sudo -p x git push' 'sudo -C 3 git push' \
    'env -P /usr/bin git push' 'env -S "git push origin main"' \
    'bash -o pipefail -c "git push origin main"' 'bash -cx "git push"' \
    'timeout 30 git push' 'timeout -s KILL 30 git push' 'timeout --signal KILL 30 git push' \
    'timeout --kill-after 5 30 git push' 'nice -n 5 git push' 'nice -5 git push' \
    '"/bin/bash" -c "git push"' '/usr/bin/env bash -c "git push"'; do
    finds "$c" push
  done
}

@test "git is seen after zsh's noglob, nocorrect, coproc and repeat with its count, and in an eval or a shell after them" {
  for c in 'noglob git push' 'nocorrect git push' 'coproc git push' 'repeat 2 git push' 'repeat -1+2 git push' \
    'repeat $n git push' 'repeat 1 2>/dev/null git push' "'noglob' git push" 'nocorrect noglob git push' \
    'noglob sudo git push' 'noglob eval "git push origin main"' 'nocorrect eval "git push"' \
    'repeat 1 eval "git push"' 'coproc eval "git push"' 'noglob sh -c "git push"' \
    "$(printf '%s\n' 'noglob sh <<EOF' 'git push' 'EOF')" "$(printf '%s\n' 'repeat 1 bash <<EOF' 'git push' 'EOF')"; do
    finds "$c" push
  done
  [ "$(_cmd_words 'repeat -1+2 git push')" = "$(printf 'git\npush')" ]
}

@test "a leading redirection is not the command name" {
  for c in '2>/dev/null git push --force' '> /dev/null git push' '2>/dev/null bash -c "git push"'; do
    finds "$c" push
  done
}

@test "a << inside quotes in \$( ) hides nothing" {
  finds 'echo "$(grep -c '"'<<'"' f)"; git push --force' push
  finds "$(printf '%s\n' 'echo "$(echo '"'<<X'"')"' 'git push --force' 'X')" push
}

@test "a shell reading a here-doc runs its body: the body stays as records" {
  finds "$(printf '%s\n' "bash <<'EOF'" 'git push --force origin main' 'EOF')" push
  finds "$(printf '%s\n' 'x=$(sudo -u me sh -s <<EOF' 'git push --force' 'EOF' ')')" push
}

@test "a shell here-doc after a closed \$( ) keeps its body" {
  finds "$(printf '%s\n' "x=\$(date) bash <<'EOF'" 'git push --force' 'EOF')" push
  finds "$(printf '%s\n' "x=\"\$(date)\" bash <<'EOF'" 'git push --force' 'EOF')" push
}

@test "a << inside a top-level (( )) is not a here-doc" {
  finds "$(printf '%s\n' 'y=1; (( y = 1 << X ))' 'git push --force' 'X')" push
}

@test "a << inside \${ }, \$[ ], \$(( )) or a NAME[ ] subscript is not a here-doc" {
  # bash runs the middle line of each: the << is text or arithmetic, not a here-doc.
  finds "$(printf '%s\n' 'echo ${x:-<<X}' 'git push --force origin main' 'X}')" push
  finds "$(printf '%s\n' 'echo $[1<<X]' 'git push --force origin main' 'X]')" push
  finds "$(printf '%s\n' 'echo $((1<<X))' 'git push --force origin main' 'X))')" push
  finds "$(printf '%s\n' 'a[1<<X]=1' 'git push --force origin main' 'X]=1')" push
  finds "$(printf '%s\n' 'echo ${x:-${y:-<<X}}' 'git push --force origin main' 'X}}')" push
  finds "$(printf '%s\n' 'echo ${x:-{<<X}' 'git push --force origin main' 'X}')" push
  finds "$(printf '%s\n' 'echo ${a[$[1<<X]]}' 'git push --force origin main' 'X]]}')" push
  finds "$(printf '%s\n' 'y=$(echo ${x:-<<X}' 'git push --force origin main' 'X})')" push
  finds "$(printf '%s\n' 'y="$(echo ${x:-<<X}' 'git push --force origin main' 'X})"')" push
}

@test "a here-doc after a closed \${ } or subscript, or inside \$( ) in one, is still a here-doc" {
  for c in 'echo ${x:-a} <<EOF' 'echo ${a[1]} <<EOF' 'a[1]=2 cat <<EOF' 'echo ${x:-$(cat <<EOF'; do
    run git_words "$(printf '%s\n' "$c" 'git push --force' 'EOF' ')}' 'git status')"
    [[ "$output" != *"git push --force"* ]] || { echo "$c -> $output"; return 1; }
    [[ "$output" == *"git status"* ]] || { echo "$c -> $output"; return 1; }
  done
}

@test "a # after an escaped separator is not a comment; after a line continuation it is" {
  for c in 'echo a\ #b; git push --force' 'echo a\;#b; git push --force' 'echo a\|#b; git push --force' \
    'echo a\&#b; git push --force' 'echo a\(#b; git push --force' "$(printf 'echo a\\\t#b; git push --force')"; do
    finds "$c" push
  done
  finds "$(printf '%s\n' 'echo a \' "#it's" 'git push --force')" push
  run git_words 'echo a\\ #b; git push --force'
  [ "$output" = 'echo a\\ #b; git push --force' ]
}

@test "a here-string is not a here-doc" {
  run git_words "$(printf '%s\n' 'cat <<< EOF' 'git push --force' 'EOF')"
  [ "${lines[0]}" = "cat <<< EOF" ]
  [ "${lines[1]}" = "git push --force" ]
  [ "${lines[2]}" = EOF ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "the commit form with a here-doc message gives one git segment, and the message is data" {
  # printf, not a here-doc inside $( ): bash 3.2 misparses the apostrophe there.
  cmd=$(printf '%s\n' 'git commit -m "$(cat <<'"'EOF'" 'docs: x (git push --force is blocked)' \
    'echo on > /x/sessions/a.state; git reset --hard' "it's (unbalanced" 'EOF' ')"')
  run git_words "$cmd"
  [ "$(git_sub "${lines[0]}" | cut -f2)" = commit ]
  [ "${lines[1]}" = "cat <<'EOF'" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "here-doc bodies are skipped, and the commands after them are still seen" {
  run git_words "$(printf '%s\n' 'cat > /tmp/f <<-EOF' '	git push --force' '	EOF' 'git status')"
  [ "${lines[0]}" = "cat > /tmp/f <<-EOF" ]
  [ "${lines[1]}" = "git status" ]
  [ "${#lines[@]}" -eq 2 ]
  finds "$(printf '%s\n' 'x=$(cat <<"A" <<B' 'a )' 'A' 'b (' 'B' 'git push --force)')" push
  finds "$(printf '%s\n' 'cat <<EOF' 'no end' 'git push')" push
}

@test "a quoted multi-line argument stays in its record" {
  run git_words "$(printf '%s\n' 'git commit -m "a' 'git push --force"' 'git status')"
  [ "${#lines[@]}" -eq 2 ]
  [ "$(git_sub "${lines[0]}" | cut -f2)" = commit ]
  [ "${lines[1]}" = "git status" ]
  finds "$(printf '%s\n' "bash -c 'git status" "git push --force'")" push
}

@test "a 1,000-line here-doc runs through git_words in under a second" {
  local TIMEFORMAT=%R t
  body=$(awk 'BEGIN { for (i = 1; i <= 1000; i++) printf "line %d: echo x > /tmp/y; (git push --force)\n", i }')
  cmd="git commit -m \"\$(cat <<'EOF'
$body
EOF
)\""
  t=$( { time git_words "$cmd" >"$BATS_TEST_TMPDIR/out" 2>/dev/null || true; } 2>&1)
  awk -v t="$t" 'BEGIN { exit !(t < 1) }' || { echo "took $t s"; return 1; }
  [ "$(wc -l <"$BATS_TEST_TMPDIR/out")" -eq 2 ]
}

@test "a backslash-newline is dropped, not read as a space" {
  finds "git \\
 stash" stash
  run git_words "git sta\\
sh"
  [ "$output" = "git stash" ]
}

@test "quoted parentheses stay inside their word" {
  run git_words 'git commit -m "fix (x)" && (git status)'
  [ "${lines[0]}" = 'git commit -m "fix (x)"' ]
  [ "${lines[1]}" = "git status" ]
  [ "${#lines[@]}" -eq 2 ]
  [ "$(git_sub "${lines[0]}" | cut -f3)" = "-m fix (x)" ]
}

@test "redirections never split a command" {
  run git_words 'git push origin 2>&1 | tail -3'
  [ "${lines[0]}" = "git push origin 2>&1" ]
  [ "${lines[1]}" = "tail -3" ]
  run git_words 'git push origin &>/dev/null; git fetch >| log'
  [ "${lines[0]}" = "git push origin &>/dev/null" ]
  [ "${lines[1]}" = "git fetch >| log" ]
}

@test "git_sub reads -C, skips env and global options" {
  run git_sub 'FOO=1 git -C /repo -c a=b --no-pager push -u origin "my branch"'
  [ "$output" = "/repo	push	-u origin my branch" ]
  run git_sub "ls -la"
  [ "$status" -eq 1 ]
}

@test "git_sub skips each global option of git 2.54, and the next word where it takes a value" {
  for g in -P -p --no-pager --paginate --no-advice --bare --no-replace-objects --no-lazy-fetch \
    --no-optional-locks --literal-pathspecs --glob-pathspecs --noglob-pathspecs --icase-pathspecs \
    '--config-env x=Y' --config-env=x=Y '--git-dir /r/.git' --git-dir=/r/.git '--work-tree /r' \
    --work-tree=/r '--namespace n' --namespace=n '--super-prefix p/' --super-prefix=p/ \
    '--attr-source HEAD' --attr-source=HEAD --exec-path=/x '-c a=b'; do
    run git_sub "git $g push origin production"
    [ "$output" = "/tmp	push	origin production" ] || { echo "$g -> $output"; return 1; }
  done
}

@test "gh_sub, word_value and word_has" {
  [ "$(gh_sub 'GH_TOKEN=x gh pr create --draft')" = "pr create" ]
  w=$(_shell_words "gh pr create --head feat --title 'a b'")
  [ "$(word_value "$w" --head -H)" = feat ]
  [ "$(word_value "$w" --title)" = "a b" ]
  word_has "$w" --title
  run word_has "$w" --draft
  [ "$status" -eq 1 ]
}

@test "current_branch reads HEAD by symbolic-ref, past a tag of the same name" {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  git -C "$R" tag main
  run current_branch "$R"
  [ "$status" -eq 0 ]
  [ "$output" = main ]
  git -C "$R" switch -q --detach
  run current_branch "$R"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "push_targets: refspecs, deletes and the current branch" {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  git -C "$R" switch -q -c feat
  run push_targets "$R" "origin +HEAD:refs/heads/rel :old"
  [ "${lines[0]}" = rel ]
  [ "${lines[1]}" = old ]
  run push_targets "$R" "-u origin"
  [ "$output" = feat ]
}

@test "push_targets skips redirections" {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  for rest in 'origin 2>&1' 'origin >/dev/null' 'origin > /dev/null' 'origin 2> err.log' \
    'origin &>/dev/null' 'origin </dev/null'; do
    run push_targets "$R" "$rest"
    [ "$output" = main ] || { echo "$rest -> $output"; return 1; }
  done
  run push_targets "$R" "$(git_sub 'git push origin 2>&1' | cut -f3)"
  [ "$output" = main ]
}

# words_are STR WORD...: _shell_words prints exactly the WORDs for STR.
words_are() {
  local str="$1"
  shift
  run _shell_words "$str"
  [ "$output" = "$(printf '%s\n' "$@")" ] || { echo "$str -> $output"; return 1; }
}

@test "_shell_words: a word that starts with an unquoted # is a comment to the newline" {
  words_are 'git status # note' git status
  words_are 'git clean -fd # -n' git clean -fd
  words_are "$(printf 'a # b\nc')" a c
  run _cmd_words 'git status # note'
  [ "$output" = "$(printf 'git\nstatus')" ]
}

@test "_shell_words: a # inside a word, quoted or escaped is kept" {
  words_are 'echo a#b' echo 'a#b'
  words_are 'echo ${#x}' echo '${#x}'
  words_are 'echo $#' echo '$#'
  words_are "echo '#x'" echo '#x'
  words_are 'echo "#x"' echo '#x'
  words_are 'echo \#x' echo '#x'
  words_are 'git log --format=%h#%s' git log '--format=%h#%s'
}

@test "_shell_words splits a redirection from the word before it" {
  [ "$(_shell_words 'a main>/dev/null 2>&1 b&>c d<<EOF e2>f' | paste -sd ' ' -)" = \
    "a main >/dev/null 2>&1 b &>c d <<EOF e2 >f" ]
}

@test "push_targets: a redirection glued to the branch, and @" {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  for rest in 'origin main>/dev/null' 'origin main&>/dev/null' 'origin @'; do
    run push_targets "$R" "$rest"
    [ "$output" = main ] || { echo "$rest -> $output"; return 1; }
  done
}

@test "a committed base_branch adds a protected branch; origin/HEAD, or else main and the like, stay protected" {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  mkdir -p "$R/.claude"
  printf 'base_branch: zzz\n' >"$R/.claude/kern.yml"
  git -C "$R" add .claude/kern.yml
  git -C "$R" commit -q -m "chore: kern settings"
  branch_protected zzz
  branch_protected main
  run branch_protected feat
  [ "$status" -eq 1 ]
  # With no origin/HEAD, main, master, trunk and develop are protected whatever base_branch says.
  git -C "$R" remote set-head origin -d
  for b in zzz main master trunk develop; do branch_protected "$b" || { echo "$b"; return 1; }; done
  run branch_protected feat
  [ "$status" -eq 1 ]
  # The re-review's probe: under autopilot, a commit on main and a push of main are denied.
  git -C "$R" remote set-head origin main >/dev/null
  set_autopilot on
  printf 'x\n' >>"$R/README.md"
  git -C "$R" add README.md
  run_guard "$(tool_payload Bash '"command":"git commit -m \"feat: x\""')" ""
  [ "$(decision_of "$output")" = deny ] || { echo "commit -> $output"; return 1; }
  run_guard "$(bash_payload 'git push origin main')" ""
  [ "$(decision_of "$output")" = deny ] || { echo "push -> $output"; return 1; }
}

@test "push_targets prints * for every-branch pushes, and * is protected" {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  for rest in '--all origin' 'origin --mirror' 'origin --branches' \
    'origin refs/heads/*:refs/heads/*' "origin 'feat/*'"; do
    run push_targets "$R" "$rest"
    [ "$output" = '*' ] || { echo "$rest -> $output"; return 1; }
  done
  branch_protected '*'
}

@test "push_targets strips heads/ and reads deletes" {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  run push_targets "$R" "origin heads/rel HEAD:heads/x refs/heads/y"
  [ "${lines[0]}" = rel ]
  [ "${lines[1]}" = x ]
  [ "${lines[2]}" = y ]
  for rest in 'origin --delete old' '--delete origin old' 'origin -d old' 'origin :old' \
    'origin :refs/heads/old' 'origin --delete heads/old'; do
    run push_targets "$R" "$rest"
    [ "$output" = old ] || { echo "$rest -> $output"; return 1; }
  done
}

@test "with_timeout returns promptly when the command finishes" {
  start=$(date +%s)
  out=$(with_timeout 10 echo done)
  [ "$out" = done ]
  [ $(($(date +%s) - start)) -lt 3 ]
}

@test "with_timeout stops a slow command and its children" {
  start=$(date +%s)
  rc=0
  out=$(with_timeout 1 sh -c 'echo partial; sleep 6') || rc=$?
  [ "$rc" -ne 0 ]
  [ "$out" = partial ]
  [ $(($(date +%s) - start)) -lt 3 ]
}

@test "git is seen behind wrapper long options that take a value" {
  for c in 'env --chdir sub git push origin main' 'env --unset X git push' \
    'env --split-string "git push origin main"' 'sudo --user root git push' \
    'sudo --chdir /tmp git push' 'nice --adjustment 5 git push'; do
    finds "$c" push
  done
}

@test "git is seen after an append assignment, an attached env -S line, and a wrapper or shell in another case" {
  for c in 'X+=1 git push' 'GIT_DIR+=/x/.git git push' 'env --split-string="git push origin main"' \
    "env -S'git push origin main'" 'ENV git push' 'Env --chdir=sub git push' 'SUDO -u me git push' \
    '/usr/bin/NoHup git push' 'TIMEOUT 5 git push' 'sudo --chroot /x git push' \
    'BASH -c "git push"' 'ENV bash -c "git push"' 'Sh -c "git push"' 'env -iS "git push origin main"' \
    "env -0vS'git push origin main'" 'env -uS git push'; do
    finds "$c" push
  done
  finds "$(printf '%s\n' "BASH <<'EOF'" 'git push --force origin main' 'EOF')" push
}

@test "every branch is protected while a settings layer that could protect one cannot be read" {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  mkdir -p "$R/.claude"
  printf 'branch.protected: feat/x\n' >"$R/.claude/kern.local.yml"
  branch_protected feat/x
  run branch_protected feat/y
  [ "$status" -eq 1 ]
  read_fails awk "$(cd "$R" && pwd -P)/.claude/kern.local.yml"
  run branch_protected feat/x
  [ "$status" -eq 0 ]
  run branch_protected feat/y
  [ "$status" -eq 0 ]
}

# A command substitution whose pipe cannot be made gives status 0 and no output; an empty branch name
# read that way must not pass for an unprotected branch (re-review of 2026-10-21).
@test "current_branch fails when its read of HEAD comes back empty, and an empty branch counts as protected" {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  rc=0
  got=$(pipe_fails 1 current_branch "$R" 2>/dev/null) || rc=$?
  [ "$rc" -ne 0 ]
  [ -z "$got" ]
  [ "$(current_branch "$R")" = main ]
  run branch_protected ""
  [ "$status" -eq 0 ]
}

# heredoc_cmd OPERATOR BODY: a stored push, then cat reading a here-doc that holds BODY.
heredoc_cmd() {
  printf '%s\n' "x='\$(git push --force origin main)'; cat $1" "$2" 'EOF'
}

@test "on G00's call an unquoted here-doc body that expands a stored string again is a \$KERN_UNREAD record" {
  local b out
  # zsh's e flag in any flag group, after a delimited argument too (zsh 5.9 runs ${(s:):e)x}), zsh's P
  # flag and bash's ${!name} (a subscript in the stored name is evaluated), zsh's % and %% flags (prompt
  # expansion, which runs a $( ) under PROMPT_SUBST) and bash's @P transform all expand the stored $( )
  # again and run it.
  for b in '${(e)x}' '${(Le)x}' 'see ${(qe)x} here' '${x@P}' '${arr[@]@P}' '${${(e)x}}' '${(s:):e)x}' \
    '${(j:):e)x}' '${(j(,)e)x}' '${(l:5::):e)x}' '${(r[3][)][x]e)x}' '${(P)y}' '${(%)x}' '${(%%)x}' \
    '${!y}' '${!y:-z}' '${!a[0]}' '${!1}' '${!@}' '${!*}'; do
    out=$(_GW_QB=1; git_words "$(heredoc_cmd '<<EOF' "$b")")
    [[ "$out" == *'$KERN_UNREAD'* ]] || { echo "$b -> $out"; return 1; }
    out=$(_GW_QB=1; git_words "$(heredoc_cmd '<<-EOF' "$b")")
    [[ "$out" == *'$KERN_UNREAD'* ]] || { echo "<<- $b -> $out"; return 1; }
    # Inside a $( ) the body is dropped the same way, and read the same way.
    out=$(_GW_QB=1; git_words "echo \$($(heredoc_cmd '<<EOF' "$b")"$'\n'")")
    [[ "$out" == *'$KERN_UNREAD'* ]] || { echo "\$( ) $b -> $out"; return 1; }
    # A quoted delimiter keeps the body literal, and other guards' reads are unchanged.
    for op in "<<'EOF'" '<<"EOF"' '<<\EOF'; do
      out=$(_GW_QB=1; git_words "$(heredoc_cmd "$op" "$b")")
      [[ "$out" != *'$KERN_UNREAD'* ]] || { echo "$op $b -> $out"; return 1; }
    done
    out=$(git_words "$(heredoc_cmd '<<EOF' "$b")")
    [[ "$out" != *'$KERN_UNREAD'* ]] || { echo "not G00's call: $b -> $out"; return 1; }
  done
  # Expansions that do not evaluate their value again: an e, P or % inside a delimited flag argument is
  # the argument's text, ${!name[@]}, ${!name[*]}, ${!prefix*} and ${!prefix@} list keys or names, and
  # ${!} (the last background pid), ${!#}, ${!-}, ${!?} and ${!$} read a special parameter's own value.
  for b in '${x}' '${(U)x}' '${(L)x}' '${x@Q}' '$x@P' 'P}' '${(s:e:)x}' '${(j:%P:)x}' '${(l:5::e::P:)x}' \
    '${(j(e))x}' '${!a[@]}' '${!a[*]}' '${!pre*}' '${!pre@}' 'pid ${!}' '${!#}' '${!-}' '${!?}' '${!$}'; do
    out=$(_GW_QB=1; git_words "$(heredoc_cmd '<<EOF' "$b")")
    [[ "$out" != *'$KERN_UNREAD'* ]] || { echo "$b -> $out"; return 1; }
  done
}

@test "under autopilot an unquoted here-doc body that expands a stored string again is denied" {
  local esc
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  esc=$(heredoc_cmd '<<EOF' '${(e)x}' | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{ printf "%s%s", (NR > 1 ? "\\n" : ""), $0 }')
  set_autopilot on
  run_guard "$(tool_payload Bash "\"command\":\"$esc\"")"
  [ "$(decision_of "$output")" = deny ] || { echo "$output"; return 1; }
  # G00 judges only under autopilot, as for the same expansion outside a here-doc.
  set_autopilot off
  run_guard "$(tool_payload Bash "\"command\":\"$esc\"")"
  [ "$(decision_of "$output")" = none ] || { echo "$output"; return 1; }
}

@test "git_words prints \$KERN_UNREAD when its split stage dies before the awk's end line" {
  local real old=$PATH out
  out=$(git_words 'git status')
  [ "$out" = "git status" ]
  real=$(command -v env)
  mkdir -p "$BATS_TEST_TMPDIR/envbin"
  # The env that starts _split_words' awk kills the subshell that ran it, so neither a record nor the
  # awk-error $KERN_UNREAD reaches the reader.
  printf '#!/bin/sh\ncase "$*" in *"function emit("*) kill -9 $PPID; exit 1 ;; esac\nexec %s "$@"\n' "$real" \
    >"$BATS_TEST_TMPDIR/envbin/env"
  chmod +x "$BATS_TEST_TMPDIR/envbin/env"
  PATH="$BATS_TEST_TMPDIR/envbin:$PATH"
  out=$(git_words 'git reset --hard HEAD~3' 2>/dev/null)
  PATH=$old
  [[ "$out" == *'$KERN_UNREAD'* ]] || { echo "no fail-closed: $out"; return 1; }
}

@test "a quote strip that fails still runs the wrapper pass, so the script of a quoted shell name is read" {
  local real old=$PATH out
  real=$(command -v tr)
  mkdir -p "$BATS_TEST_TMPDIR/trbin"
  # The tr that strips the quotes from a record's first word fails with no output, as one whose fork
  # is refused does; every other tr runs the real one.
  cat >"$BATS_TEST_TMPDIR/trbin/tr" <<EOF
#!/bin/sh
case "\$2" in *\\'*) exit 2 ;; esac
exec $real "\$@"
EOF
  chmod +x "$BATS_TEST_TMPDIR/trbin/tr"
  PATH="$BATS_TEST_TMPDIR/trbin:$PATH"
  out=$(git_words "\"bash\" -c 'git push --force origin main'")
  PATH=$old
  has_push "$out" || { echo "$out"; return 1; }
}

# reeval_table: the P1 re-review differential table, one "verdict<TAB>input" per line. verdict is the
# shared hreev matcher's answer (flag or no). The quoted and backslash-escaped forms at the end differ
# between the two call sites by design (a command has quote context, a here-doc body does not), so the
# test compares the G00 command site only on the inputs with no single quote and no backslash.
reeval_table() {
  printf '%s\n' \
    'flag	${(e)x}' 'flag	${(Le)x}' 'flag	see ${(qe)x} here' 'flag	${(qqe)x}' \
    'flag	${(j:):e)x}' 'flag	${(j)e)e)x}' 'flag	${(s)e)e)x}' 'flag	${(s:):e)x}' \
    'flag	${(j(,)e)x}' 'flag	${(l:5::):e)x}' 'flag	${(r[3][)][x]e)x}' 'flag	${(P)y}' \
    'flag	${(%)x}' 'flag	${(%%)x}' 'flag	${${(e)x}}' \
    'flag	${x@P}' 'flag	${arr[@]@P}' 'flag	${a[${i}]@P}' 'flag	"${a[${#a[@]}-1]@P}"' \
    'flag	${x#@P}' 'flag	${x:-@P}' 'flag	echo @P} done' \
    'flag	${!y}' 'flag	${!y:-z}' 'flag	${!y[0]}' 'flag	${!y[1]:-z}' 'flag	${!a[0]}' \
    'flag	${!a[$i]}' 'flag	${!a[@]:-q}' 'flag	${!1}' 'flag	${!@}' 'flag	${!*}' \
    'flag	${!z@P}' 'flag	${!y@Q}' 'flag	${!y@U}' \
    'no	${x}' 'no	${y}' 'no	${(U)x}' 'no	${(L)x}' 'no	${x@Q}' 'no	$x@P' 'no	P}' \
    'no	${(s:e:)x}' 'no	${(j:%P:)x}' 'no	${(l:5::e::P:)x}' 'no	${(j(e))x}' \
    'no	${!a[@]}' 'no	${!a[*]}' 'no	${!pre*}' 'no	${!pre@}' 'no	${!}' 'no	${!#}' \
    'no	${!-}' 'no	${!?}' 'no	${!$}' 'no	${x/@P/y}' 'no	${#a[@]}' 'no	${a[@]}' \
    'flag	'\''${(e)x}'\'' '\''${x@P}'\'' '\''${!y}'\''' \
    "flag	\$'it\\'s \${(e)x}'" "flag	\$'\${(e)x}'" \
    'flag	\${(e)x}' 'flag	\${x@P}' 'flag	\${!y}' \
    "flag	\$\$'\\'\${x@P}''" "flag	\$\$'\\'\${(e)x}''"
}

# hreev_direct INPUT: flag|no, from the shared matcher in hooks/lib/reeval.awk, run on INPUT as one line.
hreev_direct() {
  printf '%s' "$1" | env LC_ALL=C awk "$_GW_REEVAL"$'\n''{ print (hreev($0) ? "flag" : "no") }'
}
# hreev_gitctx INPUT: flag|no, from the git_words call site (an unquoted here-doc body flagged with a
# $KERN_UNREAD record on G00's call).
hreev_gitctx() {
  local body out
  body=$(printf '%s\n%s\n%s\n' 'cat <<EOF' "$1" 'EOF')
  out=$(_GW_QB=1; git_words "$body")
  case "$out" in *'$KERN_UNREAD'*) printf 'flag\n' ;; *) printf 'no\n' ;; esac
}
# hreev_g00 INPUT: flag|no, from the G00 call site (g0_reeval, the only check that prints the
# re-evaluates reason). INPUT is fed as one git_words record to the full G00 awk program.
hreev_g00() {
  local out
  out=$(printf '%s\n' "$1" | env LC_ALL=C awk -v sq="'" "$_G00_REEVAL$_GW_AWK$_G00_AWK")
  case "$out" in *'re-evaluates a stored string'*) printf 'flag\n' ;; *) printf 'no\n' ;; esac
}

@test "the re-eval matcher is one shared file, loaded by both call sites, that neither redefines" {
  local file
  file=$(cat "$KERN_ROOT/hooks/lib/reeval.awk")
  [ -n "$file" ]
  [[ "$file" == *'function hreev('* ]] || false
  # shellcheck source=hooks/guards/g00-unproven.sh
  . "$KERN_ROOT/hooks/guards/g00-unproven.sh"
  [ "$_GW_REEVAL" = "$file" ]
  [ "$_G00_REEVAL" = "$file" ]
  # Only reeval.awk defines hreev; the two sources load it, they do not carry their own copy.
  ! grep -q 'function hreev' "$KERN_ROOT/hooks/guards/g00-unproven.sh"
  ! grep -q 'function hreev' "$KERN_ROOT/hooks/lib/gitctx.sh"
}

@test "the two re-eval call sites agree with the shared matcher on every differential input" {
  local line want input d
  # shellcheck source=hooks/guards/g00-unproven.sh
  . "$KERN_ROOT/hooks/guards/g00-unproven.sh"
  while IFS=$'\t' read -r want input; do
    [ -n "$want" ] || continue
    d=$(hreev_direct "$input")
    [ "$d" = "$want" ] || { echo "hreev($input) = $d, want $want"; return 1; }
    d=$(hreev_gitctx "$input")
    [ "$d" = "$want" ] || { echo "git_words site ($input) = $d, want $want"; return 1; }
    case "$input" in
      *\'* | *\\*) ;;
      *) d=$(hreev_g00 "$input"); [ "$d" = "$want" ] || { echo "G00 site ($input) = $d, want $want"; return 1; } ;;
    esac
  done <<TABLE
$(reeval_table)
TABLE
}
