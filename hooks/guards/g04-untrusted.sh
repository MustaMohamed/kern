# shellcheck shell=bash
# G4 untrusted text: PR, issue, review and release text goes through a file, never inline in the
# command. The gh api option table and the _gh_* helpers are in g03-review.sh and g02-pr.sh.

guard_g04() {
  [ "$TOOL" = Bash ] || return 0
  local cmd seg sub words w
  cmd=$(ti_get command) || return 0
  # Only a command whose text holds gh, in any case or split by quotes or a backslash, is parsed.
  case "$cmd" in *[Gg][Hh]* | *[Gg][\"\'\\]*[Hh]*) ;; *) return 0 ;; esac
  while IFS= read -r seg; do
    sub=$(gh_sub "$seg") || continue
    # gh's aliases (pr new, issue new, release new) read as the commands they name (g02-pr.sh).
    _gh_canon "$sub" && sub=$_GH_SUB
    case "$sub" in
      "pr "* | "issue "* | "release "*) _g04_text "$seg" "$sub" ;;
      api*)
        words=$(_shell_words "$seg")
        while IFS= read -r w; do
          case "$w" in
            body=* | -fbody=* | -Fbody=*) vote deny G4 "send gh api bodies with --input <file>, not -f body="; break ;;
          esac
        done <<EOT
$words
EOT
        _g04_api "$seg"
        ;;
    esac
  done <<EOT
$(git_words "$cmd")
EOT
}

# _g04_text RECORD SUB: inline text on a pr, issue or release command. Each verb that takes text has
# its text flag (b --body, n --notes, c --comment) and its boolean short flags, from gh 2.100.0
# `--help`. A word is inline text when it is the long flag (`--x` or `--x=`), or a short cluster
# that reaches the letter through boolean letters only: -b, -bTEXT, -b=TEXT, -wbTEXT. --body on any
# pr or issue verb counts too. pr checkout's -b (a branch) and issue develop's -b (a base) are not
# text.
_g04_text() {
  local spec letter bools long w hit=0
  case "$2" in
    "pr create") spec="b defw" ;;
    "pr merge") spec="b dmrs" ;;
    "pr review") spec="b acr" ;;
    "pr comment" | "issue create" | "issue comment") spec="b ew" ;;
    "pr edit" | "issue edit") spec="b -" ;;
    "pr close") spec="c d" ;;
    "pr reopen" | "issue close" | "issue reopen") spec="c -" ;;
    "release create") spec="n dp" ;;
    "release edit") spec="n -" ;;
    *) spec="" ;;
  esac
  letter=${spec%% *}
  bools=${spec#* }
  case "$letter" in b) long=--body ;; n) long=--notes ;; c) long=--comment ;; *) long="" ;; esac
  while IFS= read -r w; do
    case "$w" in --body | --body=*) case "$2" in "pr "* | "issue "*) hit=1 ;; esac ;; esac
    [ -n "$letter" ] || continue
    case "$w" in "$long" | "$long="*) hit=1 ;; esac
    _g04_cluster "$w" "$letter" "$bools" && hit=1
  done <<EOT
$(_shell_words "$1")
EOT
  [ "$hit" = 1 ] || return 0
  if [ "$letter" = c ]; then
    vote deny G4 "a close or reopen --comment is inline text; post it with gh pr|issue comment --body-file <file>"
  else
    vote deny G4 "pass PR, issue, review and release text with --body-file or --notes-file <file>, not inline"
  fi
}

# _g04_cluster WORD LETTER BOOLS: WORD is a short-option cluster that reaches LETTER with only
# letters from BOOLS before it.
_g04_cluster() {
  local w c
  case "$1" in --* | -) return 1 ;; -*) w=${1#-} ;; *) return 1 ;; esac
  while [ -n "$w" ]; do
    c=${w%"${w#?}"}
    [ "$c" = "$2" ] && return 0
    case "$3" in *"$c"*) ;; *) return 1 ;; esac
    w=${w#?}
  done
  return 1
}

# _g04_api RECORD: a -f or -F field named body, or ending in [body], read as gh reads the flags
# (--field=body=x, -f=body=x and -fbody=x included).
_g04_api() {
  local toks t kv
  toks=$(_gh_args "$1" 1 | _gh_opts "$_GH_API_OPTS")
  while IFS= read -r t; do
    case "$t" in
      --field=* | --raw-field=*)
        kv=${t#*=}
        case "${kv%%=*}" in
          body | *"[body]")
            vote deny G4 "send gh api bodies with --input <file>, not a body field"
            return 0
            ;;
        esac
        ;;
    esac
  done <<EOT
$toks
EOT
}
