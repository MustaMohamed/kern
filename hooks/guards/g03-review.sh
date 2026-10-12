# shellcheck shell=bash
# G3 review posting: no self-approval, findings carry a taxonomy label, posting asks; every other
# gh api write asks. review.post_policy auto allows a post only in the shape _gh_proven and the
# checks here accept (the _gh_* helpers are in g02-pr.sh).

# gh option tables for _gh_opts (gh 2.100.0), and the options an allowed post may carry.
_GH_REVIEW_OPTS="approve/a/b comment/c/b request-changes/r/b body/b/v body-file/F/v repo/R/v help/h/b"
_GH_REVIEW_SAFE="approve comment request-changes body-file"
_GH_COMMENT_OPTS="body/b/v body-file/F/v attach/-/v editor/e/b web/w/b edit-last/-/b \
create-if-none/-/b delete-last/-/b yes/-/b repo/R/v help/h/b"
_GH_COMMENT_SAFE="body-file"
_GH_API_OPTS="method/X/v field/F/v raw-field/f/v header/H/v input/-/v jq/q/v template/t/v \
include/i/b silent/-/b verbose/-/b paginate/-/b slurp/-/b cache/-/v hostname/-/v preview/p/v \
allow-escape-sequences/-/b help/h/b"
_GH_API_SAFE="method field raw-field input jq silent"
_G03_TAX_DEFAULT="blocker,should-fix,nit,pre-existing"

guard_g03() {
  case "$TOOL" in
    Skill) _g03_skill; return 0 ;;
    Bash) ;;
    *) return 0 ;;
  esac
  local cmd i=0
  cmd=$(ti_get command) || return 0
  _gh_load "$cmd"
  while [ "$i" -lt "${#_GH_RECS[@]}" ]; do
    case "$(gh_sub "${_GH_RECS[$i]}")" in
      "pr review") _g03_review "$i" ;;
      "pr comment") _g03_comment "$i" ;;
      api*) _g03_api "$i" ;;
    esac
    i=$((i + 1))
  done
}

# The built-in code-review skill: --comment posts at once; --fix edits the tree it runs in.
_g03_skill() {
  case "$TOOL_INPUT" in *code-review*) ;; *) return 0 ;; esac
  case "$TOOL_INPUT" in
    *--comment*) vote ask G3 "code-review --comment posts findings to the PR immediately" ;;
  esac
  case "$TOOL_INPUT" in
    *--fix*) in_main_checkout "$CWD" && vote ask G3 "code-review --fix in the main checkout edits shared files" ;;
  esac
}

# _g03_post WHAT PROVEN SHAPE: posting follows review.post_policy; auto allows only when PROVEN is 1.
_g03_post() {
  if [ "$AUTOPILOT" = 1 ]; then
    vote deny G3 "$1 under autopilot: review posting stays human"
    return 0
  fi
  case "$(policy_for review.post)" in
    deny) vote deny G3 "review.post_policy deny" ;;
    auto)
      if [ "$2" = 1 ]; then
        vote allow G3 "review.post_policy auto: $1"
      else
        vote ask G3 "$1 in a shape kern cannot check; review.post_policy auto allows only $3"
      fi
      ;;
    *) vote ask G3 "$1 posts to the PR" ;;
  esac
}

# _g03_ask WHAT: ask, deny under autopilot.
_g03_ask() {
  vote ask G3 "$1"
  [ "$AUTOPILOT" = 1 ] && vote deny G3 "$1 (under autopilot)"
}

# _g03_path FILE: FILE as an absolute path, relative ones read from CWD.
_g03_path() {
  case "$1" in /*) printf '%s\n' "$1" ;; *) printf '%s\n' "$CWD/$1" ;; esac
}

# _g03_labelled FILE: the first non-empty line starts with a review.taxonomy label as a whole word:
# the label ends the line or is followed by a blank, `:`, `*`, `.`, `,`, `)` or `]`.
_g03_labelled() {
  local tax first rest label c
  [ -f "$1" ] || return 1
  tax=$(settings_get review.taxonomy "$_G03_TAX_DEFAULT")
  first=$(sed -n '/[^[:space:]]/{p;q;}' "$1" | sed 's/^[[:space:]*#>-]*//' | tr '[:upper:]' '[:lower:]')
  rest="$tax,"
  while [ -n "$rest" ]; do
    label=${rest%%,*}; rest=${rest#*,}
    label=$(printf '%s' "$label" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')
    [ -n "$label" ] || continue
    case "$first" in "$label"*) ;; *) continue ;; esac
    c=${first#"$label"}
    c=${c%"${c#?}"}
    case "$c" in "" | [[:space:]] | : | '*' | . | , | ')' | ']') return 0 ;; esac
  done
  return 1
}

# _g03_sel_ok SEL: SEL names a PR of this repo: empty (the current branch's), a number or a branch.
# A URL may name another repo.
_g03_sel_ok() {
  case "$1" in *://* | -*) return 1 ;; esac
}

# _g03_self SEL REPO: for an approval of PR SEL (empty: the current branch's) in REPO (empty: this
# repo). Votes deny when its author is the gh user, and asks (deny under autopilot) when that cannot
# be checked: a URL, or gh missing or failing. Exit 0 only when the author is someone else.
_g03_self() {
  local me author
  if ! _g03_sel_ok "$1"; then
    _g03_ask "approval of $1: kern cannot check its author"
    return 1
  fi
  if command -v gh >/dev/null 2>&1 &&
    me=$( (cd "$CWD" && with_timeout 10 gh api user --jq .login) 2>/dev/null) && [ -n "$me" ] &&
    author=$( (cd "$CWD" && with_timeout 10 gh pr view ${1:+"$1"} ${2:+-R "$2"} --json author --jq .author.login) 2>/dev/null) &&
    [ -n "$author" ]; then
    if [ "$me" = "$author" ]; then
      vote deny G3 "self-approval: use a COMMENT review on your own PR"
      return 1
    fi
    return 0
  fi
  _g03_ask "approval: the PR author could not be checked (gh unavailable)"
  return 1
}

_g03_review() {
  local toks sel repo file ok=0
  toks=$(_gh_args "${_GH_RECS[$1]}" 2 | _gh_opts "$_GH_REVIEW_OPTS")
  [ "$(_gh_last "$toks" help)" = true ] && return 0
  sel=$(_gh_pos "$toks" | sed -n 1p)
  repo=$(_gh_last "$toks" repo) || repo=""
  if [ "$(_gh_last "$toks" approve)" = true ]; then
    _g03_self "$sel" "$repo" || return 0
  fi
  file=$(_gh_last "$toks" body-file) || file=""
  if [ -n "$file" ] && ! _g03_labelled "$(_g03_path "$file")"; then
    vote deny G3 "review body must open with a review.taxonomy label ($(settings_get review.taxonomy "$_G03_TAX_DEFAULT"))"
    return 0
  fi
  if _gh_proven "$1" "$toks" && _gh_only "$toks" "$_GH_REVIEW_SAFE" &&
    [ "$(_gh_pos "$toks" | wc -l)" -le 1 ] && _g03_sel_ok "$sel" &&
    { [ -z "$file" ] || _gh_file_ok "$file"; }; then
    ok=1
  fi
  # shellcheck disable=SC2016 # literal backticks
  _g03_post "gh pr review" "$ok" '`gh pr review [<number>] --comment|--request-changes|--approve [--body-file <file in the repo>]` alone'
}

_g03_comment() {
  local toks sel file ok=0
  toks=$(_gh_args "${_GH_RECS[$1]}" 2 | _gh_opts "$_GH_COMMENT_OPTS")
  [ "$(_gh_last "$toks" help)" = true ] && return 0
  if [ "$(_gh_last "$toks" delete-last)" = true ]; then
    _g03_ask "gh pr comment --delete-last deletes a comment"
    return 0
  fi
  sel=$(_gh_pos "$toks" | sed -n 1p)
  file=$(_gh_last "$toks" body-file) || file=""
  if _gh_proven "$1" "$toks" && _gh_only "$toks" "$_GH_COMMENT_SAFE" &&
    [ "$(_gh_pos "$toks" | wc -l)" -le 1 ] && _g03_sel_ok "$sel" &&
    { [ -z "$file" ] || _gh_file_ok "$file"; }; then
    ok=1
  fi
  # shellcheck disable=SC2016 # literal backticks
  _g03_post "gh pr comment" "$ok" '`gh pr comment [<number>] --body-file <file in the repo>` alone'
}

# _g03_api IDX: a gh api write asks (deny under autopilot), except a REST POST of a PR review or
# review comment, which follows review.post_policy. A write is a method other than GET (fields or
# --input make the default POST), or a graphql call that carries a mutation or reads its query
# from a file.
_g03_api() {
  local toks t kv key val method="" fields=0 input="" ep="" npos=0 fread=0 mut=0 approve=0 bodyf=0
  local file tax b n repo lab=1 ok=0
  toks=$(_gh_args "${_GH_RECS[$1]}" 1 | _gh_opts "$_GH_API_OPTS")
  [ "$(_gh_last "$toks" help)" = true ] && return 0
  while IFS= read -r t; do
    case "$t" in
      --method=*) method=$(printf '%s' "${t#--method=}" | tr '[:lower:]' '[:upper:]') ;;
      --field=* | --raw-field=*)
        fields=1
        kv=${t#*=}
        key=${kv%%=*}
        val=""
        case "$kv" in *=*) val=${kv#*=} ;; esac
        # -F key=@file reads the value from a file (or stdin for @-).
        case "$t:$val" in --field=*:@*) fread=1 ;; esac
        case "$key" in body | *"[body]") bodyf=1 ;; esac
        case "$key=$(printf '%s' "$val" | tr '[:lower:]' '[:upper:]')" in event=APPROVE) approve=1 ;; esac
        case "$val" in *mutation*) mut=1 ;; esac
        ;;
      --input=*) input=${t#--input=} ;;
      @*)
        npos=$((npos + 1))
        [ "$npos" = 1 ] && ep=${t#@}
        ;;
    esac
  done <<EOT
$toks
EOT
  if [ -z "$method" ]; then
    method=GET
    { [ "$fields" = 1 ] || [ -n "$input" ]; } && method=POST
  fi
  case "$ep" in
    graphql | /graphql)
      [ "$mut" = 1 ] || [ "$fread" = 1 ] || [ -n "$input" ] || return 0
      _g03_ask "gh api graphql mutation writes to GitHub"
      return 0
      ;;
  esac
  [ "$method" = GET ] && return 0
  if [ "$method" != POST ] || ! printf '%s\n' "$ep" | grep -Eq '^/?repos/[^/]+/[^/]+/pulls/[0-9]+/(reviews|comments)$'; then
    _g03_ask "gh api $method $ep writes to GitHub"
    return 0
  fi
  # A PR review or review comment. The --input file's bodies must carry a label, and its event
  # counts as an approval too.
  if [ -n "$input" ]; then
    file=$(_g03_path "$input")
    tax=$(settings_get review.taxonomy "$_G03_TAX_DEFAULT" | tr '[:upper:]' '[:lower:]')
    while IFS= read -r b; do
      [ -n "$b" ] || continue
      b=$(printf '%s' "$b" | tr '[:upper:]' '[:lower:]' | sed 's/^[*#> -]*//; s/[^a-z-].*//')
      list_has "$tax" "$b" || lab=0
    done <<EOT
$(grep -o '"body"[[:space:]]*:[[:space:]]*"[^"]*' "$file" 2>/dev/null | sed 's/^"body"[[:space:]]*:[[:space:]]*"//')
EOT
    grep -iq '"event"[[:space:]]*:[[:space:]]*"approve"' "$file" 2>/dev/null && approve=1
  fi
  if [ "$approve" = 1 ]; then
    n=${ep%/*}
    n=${n##*/}
    repo=${ep#/}
    repo=${repo#repos/}
    repo=${repo%%/pulls/*}
    [ "$repo" = "{owner}/{repo}" ] && repo=""
    _g03_self "$n" "$repo" || return 0
  fi
  if [ "$lab" = 0 ]; then
    vote deny G3 "every review comment body must open with a review.taxonomy label"
    return 0
  fi
  # The file is read as text, so a \u escape (a key or an event spelled in escapes) is unproven.
  if _gh_proven "$1" "$toks" && _gh_only "$toks" "$_GH_API_SAFE" && [ "$npos" = 1 ] &&
    [ "$fread" = 0 ] && [ "$bodyf" = 0 ] &&
    { [ -z "$input" ] || { _gh_file_ok "$input" && ! grep -q '\\u' "$file"; }; }; then
    ok=1
  fi
  # shellcheck disable=SC2016 # literal backticks
  _g03_post "gh api review or comment post" "$ok" '`gh api repos/<o>/<r>/pulls/<n>/reviews|comments --input <file in the repo>` alone'
}
