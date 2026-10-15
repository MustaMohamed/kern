# shellcheck shell=bash
# Shell aliases the Bash tool's shell defines. Claude Code runs each Bash call as
# `zsh -c 'source <shell snapshot> && eval <command>'`, so an alias such as gp='git push' runs git
# with no git word in the command. kern reads the alias table from the shell snapshot as text, keeps
# the aliases whose expansion holds a git or gh word, and git_words judges such an alias as its
# expansion as well as itself. Nothing from the snapshot is ever run.
# Needs nothing. aliases_load sets KERN_ALIASES and the _KA_* table; alias_expand sets ALIAS_EXP.

# _ALIASES_AWK: reads a snapshot and prints `<hex of name><TAB>expansion` for each alias whose
# expansion holds a word that is git or gh (by its last path part, any case, quotes removed). Lines are
# `alias [--] name=value`, with a CRLF read as LF; value is a bare word, single-quoted text with '\''
# for a quote, or backslash escapes. A value in $'...' or double quotes, an unclosed quote, a control
# byte, a name holding a quote, a slash, a $, a backtick, a backslash or a byte outside printable ASCII,
# a name over 256 bytes and a line over 4096 bytes are skipped, and so is every alias line after the
# first 1 MB of them, which bounds the time a large or hostile snapshot costs. The head word is the
# first word after NAME=value words and zsh's reserved words; when it names another alias, it is
# replaced by that alias's value, as zsh re-expands a replacement's head word, each name at most once,
# at most 8 times and while the expansion is at most 4096 bytes. Each value is read one character at
# a time from split(), never by substr per character, which is quadratic in BWK awk.
# shellcheck disable=SC2016 # awk text
_ALIASES_AWK='
BEGIN {
  for (i = 33; i < 127; i++) { c = sprintf("%c", i); if (!index("\"/\\$`=" sq, c)) HX[c] = sprintf("%02x", i) }
  DEL = sprintf("%c", 127); BAD = sprintf("%c", 1)
  split("if then elif else do while until ! { time nocorrect coproc", RWA, " ")
  for (i in RWA) RW[RWA[i]] = 1
}
# unq(s): the alias value s with the quoting of the alias command removed, or BAD.
function unq(s,    n, C, i, c, out, q) {
  n = split(s, C, ""); out = ""; q = 0
  for (i = 1; i <= n; i++) {
    c = C[i]
    if ((c < " " && c != "\t") || c == DEL) return BAD
    if (q) { if (c == sq) q = 0; else out = out c; continue }
    if (c == sq) { q = 1; continue }
    if (c == "\\") {
      if (i == n || (C[i + 1] < " " && C[i + 1] != "\t") || C[i + 1] == DEL) return BAD
      i++; out = out C[i]; continue
    }
    if (c == "\"" || c == "$" || c == "`" || c == " " || c == "\t") return BAD
    out = out c
  }
  return q ? BAD : out
}
# head(v): the head word of v, after NAME=value words, reserved words and repeat with its count. Sets
# hk to its index among the words split(v, w, /[ \t]+/) gives, 0 when there is none.
function head(v,    w, n, k) {
  n = split(v, w, /[ \t]+/)
  for (k = 1; k <= n; k++) {
    if (w[k] == "" || w[k] ~ /^[A-Za-z_][A-Za-z0-9_]*[+]?=/ || (w[k] in RW)) continue
    if (w[k] == "repeat") { k++; continue }
    hk = k; return w[k]
  }
  hk = 0; return ""
}
# gitword(v): true when a word of v, split at blanks and shell operators, is git or gh by its last
# path part, in any case, once quotes and backslashes are removed.
function gitword(v,    w, n, k, b, P) {
  n = split(v, w, /[ \t;&|()<>]+/)
  for (k = 1; k <= n; k++) {
    b = w[k]; gsub(/["\\]/, "", b); gsub(sq, "", b)
    b = tolower(P[split(b, P, "/")])
    if (b == "git" || b == "gh") return 1
  }
  return 0
}
{ sub(/\r$/, "") }
/^alias / && length($0) <= 4096 && (spent += length($0)) <= 1048576 {
  line = substr($0, 7)
  if (substr(line, 1, 3) == "-- ") line = substr(line, 4)
  e = index(line, "="); if (e < 2 || e > 257) next
  name = substr(line, 1, e - 1)
  n = split(name, C, ""); h = ""
  for (i = 1; i <= n; i++) { if (!(C[i] in HX)) next; h = h HX[C[i]] }
  v = unq(substr(line, e + 1))
  if (v == BAD || v == "") next
  if (!(name in val)) order[++cnt] = name
  val[name] = v; hx[name] = h
}
END {
  for (i = 1; i <= cnt; i++) {
    nm = order[i]; v = val[nm]; split("", seen); seen[nm] = 1
    for (d = 0; d < 8; d++) {
      hd = head(v)
      if (hd == "" || !(hd in val) || (hd in seen) || length(v) > 4096) break
      seen[hd] = 1
      n = split(v, w, /[ \t]+/); pre = ""; rest = ""
      for (k = 1; k <= n; k++) if (w[k] != "") { if (k < hk) pre = pre w[k] " "; else if (k > hk) rest = rest " " w[k] }
      v = pre val[hd] rest
    }
    if (gitword(v)) print hx[nm] "\t" v
  }
}'

# _ALIAS_CHARS: the characters an alias name may hold, as _ALIASES_AWK reads it, listed so that no
# locale range decides it.
_ALIAS_CHARS='!#%&()*+,-.0123456789:;<>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[]^_abcdefghijklmnopqrstuvwxyz{|}~'
_ALIAS_BLANK=$' \t'

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

# aliases_load: sets one variable _KA_<hex of name> per alias whose expansion holds a git or gh word,
# holding its expansion, and KERN_ALIASES=1 when there is at least one. Names are hex-encoded because
# alias names hold characters such as ! and - that a variable name cannot; two hex digits per byte keep
# distinct names apart. The snapshot is read as text by awk, at most its first 4 MB; nothing from it is
# evaluated. A missing, unreadable or unparseable snapshot sets nothing, which changes nothing, and so
# does any failure here: it never stops the hook.
aliases_load() {
  local snap out h v
  KERN_ALIASES=""
  # The table holds only what this snapshot defines, never a _KA_ variable from the environment.
  for h in ${!_KA_@}; do unset "$h"; done
  snap=$(alias_snapshot) || return 0
  out=$(set -o pipefail; head -c 4194304 2>/dev/null <"$snap" | LC_ALL=C awk -v sq="'" "$_ALIASES_AWK" 2>/dev/null) || return 0
  while IFS=$'\t' read -r h v; do
    case "$h" in '' | *[!0123456789abcdef]*) continue ;; esac
    [ -n "$v" ] || continue
    printf -v "_KA_$h" '%s' "$v"
    KERN_ALIASES=1
  done <<<"$out"
  return 0
}

# alias_text CMD: the expansion of each record of CMD (git_words, from gitctx.sh) whose head word is an
# alias aliases_load set, one per line. A guard that skips a command whose text lacks a name it reads
# (gh, push) reads this text too, so an alias such as prc='gh pr create' is not skipped.
alias_text() {
  local rec
  [ -n "${KERN_ALIASES-}" ] || return 0
  while IFS= read -r rec; do
    if alias_expand "$rec"; then printf '%s\n' "$ALIAS_EXP"; fi
  done <<EOF
$(git_words "$1")
EOF
}

# alias_expand SEG: when the head word of the simple command SEG is an alias aliases_load set, sets
# ALIAS_EXP to SEG with that word replaced by its expansion. Exit 1 otherwise. As zsh does, the head
# word is the first word after unquoted NAME=value words, redirections (with a target in the next word
# when none is attached) and the reserved words if then elif else do while until ! { time nocorrect
# coproc and repeat with its count; zsh does not expand an alias after command, builtin, exec, noglob
# or -, and neither does this. A word with a quote, a backslash, a $ or a backtick is never an alias, as
# in zsh, and ends the search.
alias_expand() {
  local rest="$1" pre="" w t h c i=0 skip=0
  [ -n "${KERN_ALIASES-}" ] || return 1
  while :; do
    rest=${rest#"${rest%%[!"$_ALIAS_BLANK"]*}"}
    w=${rest%%["$_ALIAS_BLANK"]*}
    case "$w" in '' | *[\"\'\\\$\`]*) return 1 ;; esac
    if [ "$skip" = 1 ]; then
      skip=0
    else
      # t: the word after an fd number, which a redirection starts with.
      t=${w#"${w%%[!0123456789]*}"}
      case "$w" in
        if | then | elif | else | do | while | until | '!' | '{' | time | nocorrect | coproc) ;;
        repeat) skip=1 ;;
        *)
          case "$t" in
            # An operator with no target attached (`>`, `2>`) takes the next word as its target.
            '<'* | '>'* | '&>'*) case "$t" in *[!\<\>\&\|]*) ;; *) skip=1 ;; esac ;;
            *=*)
              t=${w%%=*}
              t=${t%+}
              case "$t" in '' | [0123456789]* | *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_]*) return 1 ;; esac
              ;;
            *) break ;;
          esac
          ;;
      esac
    fi
    pre="$pre$w "
    rest=${rest#"$w"}
  done
  [ "${#w}" -le 256 ] || return 1
  h=""
  while [ "$i" -lt "${#w}" ]; do
    c=${w:i:1}
    case "$_ALIAS_CHARS" in *"$c"*) ;; *) return 1 ;; esac
    printf -v c '%02x' "'$c"
    h="$h$c"
    i=$((i + 1))
  done
  h="_KA_$h"
  [ -n "${!h-}" ] || return 1
  # shellcheck disable=SC2034 # read by git_words
  ALIAS_EXP="$pre${!h}${rest#"$w"}"
}
