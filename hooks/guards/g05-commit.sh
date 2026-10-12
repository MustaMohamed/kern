# shellcheck shell=bash
# G5 commit: message convention and attribution checks, explicit staging, commit.policy.

guard_g05() {
  [ "$TOOL" = Bash ] || return 0
  local cmd seg parsed dir sub rest
  cmd=$(ti_get command) || return 0
  while IFS= read -r seg; do
    parsed=$(git_sub "$seg") || continue
    dir=${parsed%%	*}
    rest=${parsed#*	}
    sub=${rest%%	*}
    case "$sub" in
      add) _g05_add "$seg" ;;
      commit) _g05_commit "$dir" "$seg" ;;
    esac
  done <<EOT
$(git_words "$cmd")
EOT
}

_g05_broad() {
  vote ask G5 "$1 stages every change; stage named files with git add -- <paths>"
  [ "$AUTOPILOT" = 1 ] && vote deny G5 "$1 under autopilot"
}

_g05_add() {
  local words
  words=$(_shell_words "$1" | awk 'f { print } $0 == "add" { f = 1 }')
  if word_has "$words" -A --all . :/ -u --update '*'; then
    _g05_broad "git add -A"
  fi
}

# _g05_message DIR WORDS: prints the commit message. Exit 1 when it cannot be read statically.
_g05_message() {
  local dir="$1" words="$2" w prev="" msg="" have=0 f ref
  while IFS= read -r w; do
    case "$prev" in
      -m | --message) msg="${msg:+$msg

}$w"; have=1; prev=""; continue ;;
      -F | --file) f="$w"; prev=""; continue ;;
      -C | -c | --reuse-message | --reedit-message) ref="$w"; prev=""; continue ;;
    esac
    case "$w" in
      -m | --message | -F | --file | -C | -c | --reuse-message | --reedit-message) prev="$w" ;;
      --message=*) msg="${msg:+$msg

}${w#--message=}"; have=1 ;;
      --file=*) f="${w#--file=}" ;;
      -m?*) msg="${msg:+$msg

}${w#-m}"; have=1 ;;
      -F?*) f="${w#-F}" ;;
    esac
  done <<EOT
$words
EOT
  if [ -n "${f-}" ]; then
    [ "$f" = - ] && return 1
    case "$f" in /*) ;; *) f="$dir/$f" ;; esac
    [ -f "$f" ] || return 1
    cat "$f"
    return 0
  fi
  if [ "$have" = 1 ]; then
    # shellcheck disable=SC2016 # a literal $( in the text
    case "$msg" in *'$('* | *'`'*) return 1 ;; esac
    # A newline inside a quoted -m word arrives as git_words' \037; give the message its lines back.
    printf '%s\n' "${msg//$_GW_NL/$'\n'}"
    return 0
  fi
  if [ -n "${ref-}" ]; then
    git -C "$dir" log -1 --format=%B "$ref" 2>/dev/null
    return $?
  fi
  if word_has "$words" --no-edit && word_has "$words" --amend; then
    git -C "$dir" log -1 --format=%B 2>/dev/null
    return $?
  fi
  return 1
}

# _g05_problems DIR MESSAGE: one line per failed check; nothing when the message passes.
_g05_problems() {
  local dir="$1" msg="$2" subject conv idre branch id
  subject=$(printf '%s\n' "$msg" | sed -n '/[^[:space:]]/{p;q;}')
  if [ "$(settings_get commit.attribution none)" = none ] &&
    printf '%s\n' "$msg" | grep -Eiq 'co-authored-by:.*(claude|anthropic)|generated (with|by) .*claude|claude-session:|claude\.ai/code'; then
    echo "attribution trailer present (commit.attribution: none)"
  fi
  conv=$(settings_get commit.convention '')
  if [ -n "$conv" ] && ! printf '%s\n' "$subject" | grep -Eq -- "$conv"; then
    echo "subject does not match commit.convention $conv"
  fi
  idre=$(settings_get commit.id_from_branch '[A-Z][A-Z0-9]+-[0-9]+')
  branch=$(current_branch "$dir")
  id=$(printf '%s\n' "$branch" | grep -Eo -- "$idre" | head -n 1)
  if [ -n "$id" ]; then
    case "$subject" in *"$id"*) ;; *) echo "subject lacks the ticket id $id from branch $branch" ;; esac
  fi
}

_g05_commit() {
  local dir="$1" words msg problems
  words=$(_shell_words "$2" | awk 'f { print } $0 == "commit" { f = 1 }')
  if word_has "$words" -a --all || printf '%s\n' "$words" | grep -Eq '^-[a-zA-Z]*a[a-zA-Z]*$'; then
    _g05_broad "git commit -a"
  fi
  if ! msg=$(_g05_message "$dir" "$words"); then
    vote ask G5 "commit message cannot be checked here; write it to a file and use git commit -F <file>"
    return 0
  fi
  problems=$(_g05_problems "$dir" "$msg")
  if [ -n "$problems" ]; then
    vote deny G5 "$(printf '%s\n' "$problems" | paste -sd ';' - | sed 's/;/; /g')"
    return 0
  fi
  case "$(policy_for commit)" in
    deny) vote deny G5 "commit.policy deny" ;;
    auto) vote allow G5 "commit.policy auto: message checks pass" ;;
    *)
      if [ "$AUTOPILOT" = 1 ]; then
        vote allow G5 "autopilot commit: message checks pass"
      else
        vote ask G5 "commit (message checks pass)"
      fi
      ;;
  esac
}
