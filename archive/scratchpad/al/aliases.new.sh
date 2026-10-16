# shellcheck shell=bash
# Shell aliases the Bash tool's shell defines. Claude Code runs each Bash call as
# `zsh -c 'source <shell snapshot> && eval <command>'`, so an alias such as gp='git push' runs git
# with no git word in the command. kern reads the alias table from the shell snapshot, keeps the
# aliases that run git or gh, and git_words judges such an alias as its expansion.
# Needs nothing. Sets KERN_ALIASES; alias_expand sets ALIAS_EXP.

# _ALIASES_AWK: reads a snapshot and prints `name<TAB>expansion` for each alias whose expansion runs
# git or gh. Lines are `alias [--] name=value`; value is a bare word, single-quoted text with '\''
# for a quote, or backslash escapes. A value in $'...' or double quotes, an unclosed quote, a name
# holding a quote, a slash, a $ or a backtick, or a value with a newline is skipped. The head word is
# the first word after NAME=value words; when it names another alias, it is replaced by that alias's
# value, as zsh re-expands a replacement's head word, each name at most once and at most 8 times.
# shellcheck disable=SC2016 # awk text
_ALIASES_AWK='
function unq(s,    i, j, c, out, n) {
  out = ""; n = length(s); i = 1
  while (i <= n) {
    c = substr(s, i, 1)
    if (c == sq) {
      j = index(substr(s, i + 1), sq); if (!j) return "\001"
      out = out substr(s, i + 1, j - 1); i += j + 1
    } else if (c == "\\") {
      if (i == n) return "\001"
      out = out substr(s, i + 1, 1); i += 2
    } else if (c == "\"" || c == "$" || c == "`" || c == " " || c == "\t") {
      return "\001"
    } else { out = out c; i++ }
  }
  return out
}
function head(v,    w, n, k) {
  n = split(v, w, /[ \t]+/)
  for (k = 1; k <= n; k++) {
    if (w[k] == "" || w[k] ~ /^[A-Za-z_][A-Za-z0-9_]*=/) continue
    hk = k; return w[k]
  }
  hk = 0; return ""
}
/^alias / {
  line = substr($0, 7)
  if (substr(line, 1, 3) == "-- ") line = substr(line, 4)
  e = index(line, "="); if (e < 2) next
  name = substr(line, 1, e - 1)
  if (name ~ /[ \t\/"\\$`=]/ || index(name, sq)) next
  v = unq(substr(line, e + 1))
  if (v == "\001" || v == "") next
  val[name] = v; order[++cnt] = name
}
END {
  for (i = 1; i <= cnt; i++) {
    nm = order[i]; v = val[nm]; split("", seen); seen[nm] = 1
    for (d = 0; d < 8; d++) {
      h = head(v)
      if (h == "" || !(h in val) || (h in seen)) break
      seen[h] = 1
      n = split(v, w, /[ \t]+/); pre = ""; rest = ""
      for (k = 1; k <= n; k++) if (w[k] != "") { if (k < hk) pre = pre w[k] " "; else if (k > hk) rest = rest " " w[k] }
      v = pre val[h] rest
    }
    b = head(v); sub(/.*\//, "", b)
    if (b == "git" || b == "gh") print nm "\t" v
  }
}'

# alias_snapshot: prints the shell snapshot to read; exit 1 when there is none. KERN_SHELL_SNAPSHOT
# names one (tests). Otherwise the newest snapshot-*.sh under the Claude Code config dir: the hook
# input and environment do not name the snapshot a session sourced, so the newest stands in for it.
alias_snapshot() {
  local f newest=""
  if [ -n "${KERN_SHELL_SNAPSHOT-}" ]; then
    [ -f "$KERN_SHELL_SNAPSHOT" ] && [ -r "$KERN_SHELL_SNAPSHOT" ] || return 1
    printf '%s\n' "$KERN_SHELL_SNAPSHOT"
    return 0
  fi
  for f in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/shell-snapshots/snapshot-*.sh; do
    [ -f "$f" ] && [ -r "$f" ] || continue
    if [ -z "$newest" ] || [ "$f" -nt "$newest" ]; then newest=$f; fi
  done
  [ -n "$newest" ] || return 1
  printf '%s\n' "$newest"
}

# aliases_load: sets KERN_ALIASES to the table, one `name<TAB>expansion` line each, with a newline
# before the first and after the last. A missing, unreadable or unparseable snapshot leaves it empty,
# and an empty table changes nothing.
aliases_load() {
  local snap
  KERN_ALIASES=""
  snap=$(alias_snapshot) || return 0
  KERN_ALIASES=$(LC_ALL=C awk -v sq="'" "$_ALIASES_AWK" "$snap" 2>/dev/null) || KERN_ALIASES=""
  if [ -n "$KERN_ALIASES" ]; then KERN_ALIASES=$'\n'"$KERN_ALIASES"$'\n'; fi
  return 0
}

# alias_expand SEG: when the head word of the simple command SEG (the first word after unquoted
# NAME=value words) is an alias in KERN_ALIASES, sets ALIAS_EXP to SEG with that word replaced by its
# expansion. Exit 1 otherwise. A head word with a quote, a backslash, a $, a backtick or a slash is
# never an alias, as in zsh; an assignment word that holds one of those ends the search.
alias_expand() {
  local rest="$1" pre="" w x
  [ -n "${KERN_ALIASES-}" ] || return 1
  while :; do
    rest=${rest#"${rest%%[![:space:]]*}"}
    w=${rest%%[[:space:]]*}
    case "$w" in
      '' | *[\"\'\\\$\`/]*) return 1 ;;
      [A-Za-z_]*=*)
        case "${w%%=*}" in *[!A-Za-z0-9_]*) break ;; esac
        pre="$pre$w "
        rest=${rest#"$w"}
        ;;
      *) break ;;
    esac
  done
  case "$KERN_ALIASES" in *$'\n'"$w"$'\t'*) ;; *) return 1 ;; esac
  x=${KERN_ALIASES#*$'\n'"$w"$'\t'}
  # shellcheck disable=SC2034 # read by git_words
  ALIAS_EXP="$pre${x%%$'\n'*}${rest#"$w"}"
}
