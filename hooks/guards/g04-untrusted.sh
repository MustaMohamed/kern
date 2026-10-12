# shellcheck shell=bash
# G4 untrusted text: PR, issue, review and release text goes through a file, never inline in the
# command. Option tables and _gh_* helpers are in g02-pr.sh and g03-review.sh.

guard_g04() {
  [ "$TOOL" = Bash ] || return 0
  local cmd seg sub words w
  cmd=$(ti_get command) || return 0
  while IFS= read -r seg; do
    sub=$(gh_sub "$seg") || continue
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

# _g04_text RECORD SUB: inline text on a pr, issue or release command. pr create, review and comment
# are read with their option tables, which catch clusters such as -abTEXT. Every verb is also
# scanned word by word for --body, and for -b where it is the body flag (not pr checkout's branch or
# issue develop's base) and release's --notes and -n, attached forms included.
_g04_text() {
  local table="" toks w hit=0
  case "$2" in
    "pr create") table=$_GH_CREATE_OPTS ;;
    "pr review") table=$_GH_REVIEW_OPTS ;;
    "pr comment") table=$_GH_COMMENT_OPTS ;;
  esac
  if [ -n "$table" ]; then
    toks=$(_gh_args "$1" 2 | _gh_opts "$table")
    _gh_last "$toks" body >/dev/null && hit=1
  fi
  while IFS= read -r w; do
    case "$w" in --body | --body=*) case "$2" in "pr "* | "issue "*) hit=1 ;; esac ;; esac
    case "$2" in
      "pr create" | "pr edit" | "pr merge" | "pr review" | "pr comment" | "issue create" | "issue comment" | "issue edit")
        case "$w" in -b*) hit=1 ;; esac
        ;;
      "release create" | "release edit")
        case "$w" in --notes | --notes=* | -n*) hit=1 ;; esac
        ;;
    esac
  done <<EOT
$(_shell_words "$1")
EOT
  [ "$hit" = 1 ] && vote deny G4 "pass PR, issue, review and release text with --body-file or --notes-file <file>, not inline"
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
