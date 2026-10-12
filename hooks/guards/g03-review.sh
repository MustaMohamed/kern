# shellcheck shell=bash
# G3 review posting: no self-approval, findings carry a taxonomy label, posting asks.

guard_g03() {
  case "$TOOL" in
    Skill) _g03_skill; return 0 ;;
    Bash) ;;
    *) return 0 ;;
  esac
  local cmd seg
  cmd=$(ti_get command) || return 0
  while IFS= read -r seg; do
    case "$(gh_sub "$seg")" in
      "pr review") _g03_review "$seg" ;;
      "pr comment") _g03_post "gh pr comment" ;;
      api*)
        case "$seg" in
          *"/reviews"* | *"/comments"*) _g03_api "$seg" ;;
        esac
        ;;
    esac
  done <<EOT
$(git_words "$cmd")
EOT
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

_g03_post() {
  if [ "$AUTOPILOT" = 1 ]; then
    vote deny G3 "$1 under autopilot: review posting stays human"
    return 0
  fi
  case "$(policy_for review.post)" in
    auto) vote allow G3 "review.post_policy auto: $1" ;;
    deny) vote deny G3 "review.post_policy deny" ;;
    *) vote ask G3 "$1 posts to the PR" ;;
  esac
}

# _g03_labelled FILE: the first non-empty line starts with a review.taxonomy label.
_g03_labelled() {
  local tax first rest label
  [ -f "$1" ] || return 1
  tax=$(settings_get review.taxonomy "blocker,should-fix,nit,pre-existing")
  first=$(sed -n '/[^[:space:]]/{p;q;}' "$1" | sed 's/^[[:space:]*#>-]*//' | tr '[:upper:]' '[:lower:]')
  rest="$tax,"
  while [ -n "$rest" ]; do
    label=${rest%%,*}; rest=${rest#*,}
    label=$(printf '%s' "$label" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')
    [ -n "$label" ] || continue
    case "$first" in "$label"*) return 0 ;; esac
  done
  return 1
}

_g03_review() {
  local words num me author file
  words=$(_shell_words "$1")
  if word_has "$words" --approve -a; then
    num=$(printf '%s\n' "$words" | awk 'f && /^[0-9]+$/ { print; exit } $0 == "review" { f = 1 }')
    if command -v gh >/dev/null 2>&1 &&
      me=$( (cd "$CWD" && with_timeout 10 gh api user --jq .login) 2>/dev/null) &&
      author=$( (cd "$CWD" && with_timeout 10 gh pr view ${num:+"$num"} --json author --jq .author.login) 2>/dev/null) &&
      [ -n "$me" ] && [ "$me" = "$author" ]; then
      vote deny G3 "self-approval: use a COMMENT review on your own PR"
      return 0
    fi
    _g03_post "gh pr review --approve"
    return 0
  fi
  file=$(word_value "$words" --body-file -F) || file=""
  if [ -n "$file" ]; then
    case "$file" in /*) ;; *) file="$CWD/$file" ;; esac
    if ! _g03_labelled "$file"; then
      vote deny G3 "review body must open with a review.taxonomy label ($(settings_get review.taxonomy "blocker,should-fix,nit,pre-existing"))"
      return 0
    fi
  fi
  _g03_post "gh pr review"
}

_g03_api() {
  local words file tax b ok=1
  words=$(_shell_words "$1")
  if ! word_has "$words" -f -F --field --raw-field --input &&
    [ "$(word_value "$words" -X --method 2>/dev/null)" != POST ]; then
    return 0
  fi
  file=$(word_value "$words" --input) || file=""
  if [ -n "$file" ]; then
    case "$file" in /*) ;; *) file="$CWD/$file" ;; esac
    tax=$(settings_get review.taxonomy "blocker,should-fix,nit,pre-existing" | tr '[:upper:]' '[:lower:]')
    while IFS= read -r b; do
      [ -n "$b" ] || continue
      b=$(printf '%s' "$b" | tr '[:upper:]' '[:lower:]' | sed 's/^[*#> -]*//; s/[^a-z-].*//')
      list_has "$tax" "$b" || ok=0
    done <<EOT
$(grep -o '"body"[[:space:]]*:[[:space:]]*"[^"]*' "$file" 2>/dev/null | sed 's/^"body"[[:space:]]*:[[:space:]]*"//')
EOT
    if [ "$ok" = 0 ]; then
      vote deny G3 "every review comment body must open with a review.taxonomy label"
      return 0
    fi
  fi
  _g03_post "gh api review or comment post"
}
