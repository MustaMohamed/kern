# shellcheck shell=bash
# G6 secrets: scan what a commit or push would publish; refuse never_commit paths.

guard_g06() {
  [ "$TOOL" = Bash ] || return 0
  local cmd seg parsed dir sub rest
  cmd=$(ti_get command) || return 0
  while IFS= read -r seg; do
    parsed=$(git_sub "$seg") || continue
    dir=${parsed%%	*}
    rest=${parsed#*	}
    sub=${rest%%	*}
    rest=${rest#*	}
    case "$sub" in
      commit) _g06_commit "$dir" "$rest" ;;
      push) _g06_push "$dir" ;;
    esac
  done <<EOT
$(git_words "$cmd")
EOT
}

# _g06_added: reads a unified diff, prints `path:line:text` for every added line.
_g06_added() {
  LC_ALL=C awk '
    /^\+\+\+ / { p = substr($0, 5); sub(/^b\//, "", p); next }
    /^@@ / { split($3, a, ","); ln = substr(a[1], 2) + 0; next }
    /^\+/ { print p ":" ln ":" substr($0, 2); ln++; next }
    /^ / { ln++ }'
}

# _g06_scan: reads `path:line:text` lines, prints `path:line <rule>` per hit. Never prints the text.
_g06_scan() {
  local added rule re
  added=$(cat)
  [ -n "$added" ] || return 0
  while IFS='|' read -r rule re; do
    printf '%s\n' "$added" | grep -E -- "$re" | cut -d: -f1,2 | sed "s/\$/ $rule/"
  done <<'EOT'
private-key|-----BEGIN [A-Z ]*PRIVATE KEY-----
aws-access-key|AKIA[0-9A-Z]{16}
github-token|gh[pousr]_[A-Za-z0-9]{20,}
slack-token|xox[baprs]-[A-Za-z0-9-]{10,}
api-key|sk-[A-Za-z0-9_-]{20,}
google-api-key|AIza[0-9A-Za-z_-]{35}
EOT
}

# _g06_paths NAMES: deny when a newline-separated path matches a never_commit glob.
_g06_paths() {
  local list glob name rest hits=""
  list=$(settings_get never_commit '')
  [ -n "$list" ] || return 0
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    rest="$list,"
    while [ -n "$rest" ]; do
      glob=${rest%%,*}
      rest=${rest#*,}
      glob=$(printf '%s' "$glob" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
      [ -n "$glob" ] || continue
      # shellcheck disable=SC2254
      case "$name" in $glob) hits="${hits:+$hits, }$name" ;; esac
    done
  done <<EOT
$1
EOT
  [ -n "$hits" ] && vote deny G6 "never_commit paths staged: $hits"
  return 0
}

_g06_report() {
  local hits="$1" diff="$2"
  if [ -n "$hits" ]; then
    vote deny G6 "possible secret, not committed or pushed: $(printf '%s\n' "$hits" | head -n 5 | paste -sd ';' - | sed 's/;/; /g')"
  elif command -v gitleaks >/dev/null 2>&1; then
    printf '%s\n' "$diff" | gitleaks stdin --no-banner --redact >/dev/null 2>&1
    [ $? -eq 1 ] && vote deny G6 "gitleaks reports a secret in this change; run gitleaks yourself to see where"
  fi
}

_g06_commit() {
  local dir="$1" rest="$2" diff names
  diff=$(git -C "$dir" diff --cached 2>/dev/null)
  names=$(git -C "$dir" diff --cached --name-only 2>/dev/null)
  case " $rest " in
    *" -a "* | *" --all "* | *" -am "*)
      diff="$diff
$(git -C "$dir" diff 2>/dev/null)"
      names="$names
$(git -C "$dir" diff --name-only 2>/dev/null)"
      ;;
  esac
  _g06_paths "$names"
  _g06_report "$(printf '%s\n' "$diff" | _g06_added | _g06_scan)" "$diff"
}

_g06_push() {
  local dir="$1" range base diff
  if git -C "$dir" rev-parse --verify -q '@{u}' >/dev/null 2>&1; then
    range='@{u}..HEAD'
  elif base=$(base_branch_name); then
    range="origin/$base..HEAD"
  else
    return 0
  fi
  diff=$(git -C "$dir" log -p --format= "$range" 2>/dev/null)
  _g06_paths "$(git -C "$dir" diff --name-only "$range" 2>/dev/null)"
  _g06_report "$(printf '%s\n' "$diff" | _g06_added | _g06_scan)" "$diff"
}
