# shellcheck shell=bash
# Shell aliases the Bash tool's shell defines. Claude Code runs each Bash call as
# `zsh -c 'source <shell snapshot> && eval <command>'`, so an alias such as gp='git push' runs git
# with no git word in the command. kern reads the alias table from the shell snapshot as text, keeps
# the aliases whose expansion holds a git or gh word, and git_words judges such an alias as its
# expansion as well as itself. Nothing from the snapshot is ever run.
# Needs nothing. aliases_load sets KERN_ALIASES and the _KA_* table; alias_expand sets ALIAS_EXP.

# _ALIASES_AWK: reads a snapshot and prints `<hex of name><TAB>expansion` for each alias whose
# expansion holds a word that is git or gh (by its last path part, any case, quotes removed), and for
# each alias whose expansion ends in a space, which zsh's trailing-space rule lets expand the word after
# it; such an expansion is printed with one space at its end and no other expansion ends in one. Lines are
# `alias [--] name=value`, with a CRLF read as LF; value is a bare word, single-quoted text with '\''
# for a quote, or backslash escapes. A value in $'...' or double quotes, an unclosed quote, a control
# byte, a name holding a quote, a slash, a $, a backtick, a backslash or a byte outside printable ASCII,
# a name over 256 bytes and a line over 4096 bytes are skipped, and so is every alias line after the
# first 1 MB of them, which bounds the time a large or hostile snapshot costs. The head word is the
# first word after NAME=value words and zsh's reserved words; when it names another alias, it is
# replaced by that alias's value, as zsh re-expands a replacement's head word, each name at most once,
# at most 8 times and while the expansion is at most 4096 bytes. Each value is read one character at
# a time from split(), never by substr per character, which is quadratic in BWK awk.
# Shell functions: a `name () {` line in column 0 (zsh's typeset -f shape), or a `name () ` line and then
# a `{` line (bash's declare -f shape), starts a body that runs to the next `}` in column 0. A function
# whose body holds a git or gh word, by the same test as an alias's expansion, gets the expansion
# `git kern-shell-function` (`gh kern-shell-function` when only gh appears, both joined by `;` when both
# do), which G1, G5, G6 and G2 read as an unknown git or gh command: they ask, and under autopilot deny,
# since kern cannot see what the function runs. A head word that names such a function ends an alias's
# chain with that expansion. An alias of the same name wins, as in zsh. Function lines have a bound of
# their own, 1 MB, so alias lines are read exactly as without functions. Not read: a function that runs
# git only through another function or an alias, and any form but the two above.
# shellcheck disable=SC2016 # awk text
_ALIASES_AWK='
BEGIN {
  for (i = 33; i < 127; i++) { c = sprintf("%c", i); if (!index("\"/\\$`=" sq, c)) HX[c] = sprintf("%02x", i) }
  DEL = sprintf("%c", 127); BAD = sprintf("%c", 1)
  GITF = "git kern-shell-function"; GHF = "gh kern-shell-function"
  split("if then elif else do while until ! { time nocorrect coproc", RWA, " ")
  for (i in RWA) RW[RWA[i]] = 1
}
# or2(a, b): a | b for a and b in 0 to 3 (BWK awk and mawk have no bit operators).
function or2(a, b) { return (a % 2 || b % 2) + 2 * (a >= 2 || b >= 2) }
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
# gitkind(v): 1 when a word of v, split at blanks and shell operators, is git by its last path part,
# in any case, once quotes and backslashes are removed; 2 when one is gh; 3 when both are.
function gitkind(v,    w, n, k, b, P, r) {
  n = split(v, w, /[ \t;&|()<>]+/); r = 0
  for (k = 1; k <= n; k++) {
    b = w[k]; gsub(/["\\]/, "", b); gsub(sq, "", b)
    b = tolower(P[split(b, P, "/")])
    if (b == "git" && r % 2 == 0) r += 1
    if (b == "gh" && r < 2) r += 2
  }
  return r
}
function gitword(v) { return gitkind(v) > 0 }
# hexname(name): the hex of name, or "" when a byte of it cannot be in an alias or function name.
function hexname(name,    n, C, i, h) {
  n = split(name, C, ""); h = ""
  for (i = 1; i <= n; i++) { if (!(C[i] in HX)) return ""; h = h HX[C[i]] }
  return h
}
# fnend(): records the function being read when its body ran git or gh.
function fnend() {
  # A function named git or gh stores nothing: the guards already judge the command by its head word.
  if (fn != "" && fk && fn != "git" && fn != "gh") {
    if (!(fn in fv)) forder[++fcnt] = fn
    fv[fn] = fk == 1 ? GITF : fk == 2 ? GHF : GITF "; " GHF; fhx[fn] = fh
  }
  fn = ""; fk = 0
}
{ sub(/\r$/, "") }
# A function body: up to the next } in column 0. Lines are not skipped, so the alias rule reads them as
# it does without functions.
fn != "" && $0 == "}" { fnend() }
fn != "" && $0 != "}" && (fspent += length($0) + 1) <= 1048576 { fk = or2(fk, gitkind($0)) }
fpend != "" { if ($0 ~ /^[{] ?$/ && fspent <= 1048576) { fn = fpend; fh = fph; fk = 0 }; fpend = "" }
/^[^ \t]+ [(][)] ?([{])?$/ && (fspent += length($0) + 1) <= 1048576 {
  fnend()
  nm = $0; sub(/ [(][)] ?([{])?$/, "", nm); fx = hexname(nm)
  if (fx != "" && length(nm) <= 256) {
    if ($0 ~ /[{]$/) { fn = nm; fh = fx; fk = 0 } else { fpend = nm; fph = fx }
  }
}
/^alias / && length($0) <= 4096 && (spent += length($0)) <= 1048576 {
  line = substr($0, 7)
  if (substr(line, 1, 3) == "-- ") line = substr(line, 4)
  e = index(line, "="); if (e < 2 || e > 257) next
  name = substr(line, 1, e - 1)
  h = hexname(name); if (h == "") next
  v = unq(substr(line, e + 1))
  if (v == BAD || v == "") next
  if (!(name in val)) order[++cnt] = name
  val[name] = v; hx[name] = h
}
END {
  fnend()
  for (i = 1; i <= cnt; i++) {
    # ts: the expansion ends in a space (a tab does not count in zsh), its own or that of an alias
    # whose value ends it.
    nm = order[i]; v = val[nm]; split("", seen); seen[nm] = 1; ts = v ~ / $/
    for (d = 0; d < 8; d++) {
      hd = head(v)
      if (hd == "" || length(v) > 4096) break
      # A head word that is no alias left to expand, but a function that runs git or gh, runs it.
      fe = !(hd in val) || (hd in seen)
      if (fe && !(hd in fv)) break
      n = split(v, w, /[ \t]+/); pre = ""; rest = ""
      for (k = 1; k <= n; k++) if (w[k] != "") { if (k < hk) pre = pre w[k] " "; else if (k > hk) rest = rest " " w[k] }
      if (fe) { v = pre fv[hd] rest; break }
      seen[hd] = 1
      if (rest == "" && val[hd] ~ / $/) ts = 1
      v = pre val[hd] rest
    }
    sub(/[ \t]+$/, "", v)
    if (ts) v = v " "
    if (gitword(v) || ts) print hx[nm] "\t" v
  }
  for (i = 1; i <= fcnt; i++) if (!(forder[i] in val)) print fhx[forder[i]] "\t" fv[forder[i]]
}'

# _ALIAS_HEAD_AWK: for a simple command whose leading words include an assignment that holds a quote, a
# $ or a backslash (X='a b' gpf!), prints three lines: the text before the head word, the head word and
# the text after it, all as written. Words are split at blanks outside quotes, $( ), ${ } and backticks;
# each $( ) or ${ } keeps its own quote state, so a quote inside one closes there. The words skipped are
# those alias_expand skips. Prints nothing when there is no head word. A word it
# splits wrongly can only add or miss an expansion record, which git_words prints after the command's
# own records.
# shellcheck disable=SC2016 # awk text
_ALIAS_HEAD_AWK='
{ buf = buf (NR > 1 ? "\n" : "") $0 }
END {
  split("if then elif else do while until ! { time nocorrect coproc", A, " "); for (k in A) RW[A[k]] = 1
  n = split(buf, C, ""); i = 1; skip = 0
  for (;;) {
    while (i <= n && (C[i] == " " || C[i] == "\t")) i++
    if (i > n) exit
    s = i; q = ""; d = 0
    for (; i <= n; i++) {
      c = C[i]
      if (q == sq) { if (c == sq) q = ""; continue }
      if (c == "\\") { i++; continue }
      if (q == "`") { if (c == "`") q = ""; continue }
      # QS[d]: the quote open outside the $( ) or ${ } at depth d, restored when it closes.
      if (c == "$" && (C[i + 1] == "(" || C[i + 1] == "{")) { QS[++d] = q; q = ""; i++; continue }
      if (q == "\"") { if (c == "\"") q = ""; continue }
      if (d && (c == "(" || c == "{")) { QS[++d] = ""; continue }
      if (d && (c == ")" || c == "}")) { q = QS[d--]; continue }
      if (c == sq || c == "\"" || c == "`") { q = c; continue }
      if (!d && (c == " " || c == "\t")) break
    }
    w = substr(buf, s, i - s)
    if (skip) { skip = 0; continue }
    if (w in RW) continue
    if (w == "repeat") { skip = 1; continue }
    t = w; sub(/^[0-9]+/, "", t)
    if (t ~ /^(<|>|&>)/) { if (t !~ /[^<>&|]/) skip = 1; continue }
    if (w ~ /^[A-Za-z_][A-Za-z0-9_]*[+]?=/) continue
    print substr(buf, 1, s - 1); print w; print substr(buf, i); exit
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

# _ALIASES_CACHE_V: the format of the alias cache. Bump it when _ALIASES_AWK's output or the cache
# layout changes meaning; the cache header also holds the awk program's length.
_ALIASES_CACHE_V=2

# _alias_key FILE: prints FILE's size, modification time, change time (in seconds) and inode, from BSD or
# GNU stat; exit 1 when neither reads it. touch can put a modification time back, not a change time.
_alias_key() {
  local k
  k=$(stat -f '%z %m %c %i' "$1" 2>/dev/null) || k=$(stat -c '%s %Y %Z %i' "$1" 2>/dev/null) || return 1
  case "$k" in '' | *[!0123456789\ ]* | ' '* | *' ' | *'  '*) return 1 ;; esac
  # shellcheck disable=SC2086 # digits and single spaces only: four fields
  set -- $k
  [ "$#" = 4 ] || return 1
  printf '%s\n' "$k"
}

# _alias_table: reads `<hex of name><TAB>expansion` lines on stdin into _KA_<hex>, and sets
# KERN_ALIASES=1 for each it keeps. The lines are data: a line whose name is not hex digits is skipped,
# nothing in a line is evaluated, and reading stops after 4 MB.
_alias_table() {
  local h v t=0
  while IFS=$'\t' read -r h v; do
    t=$((t + ${#h} + ${#v} + 2))
    [ "$t" -le 4194304 ] || break
    case "$h" in '' | *[!0123456789abcdef]*) continue ;; esac
    [ -n "$v" ] || continue
    printf -v "_KA_$h" '%s' "$v"
    KERN_ALIASES=1
  done
  return 0
}

# aliases_load: sets one variable _KA_<hex of name> per alias whose expansion holds a git or gh word,
# holding its expansion, and KERN_ALIASES=1 when there is at least one. Names are hex-encoded because
# alias names hold characters such as ! and - that a variable name cannot; two hex digits per byte keep
# distinct names apart. The snapshot is read as text by awk, at most its first 4 MB; nothing from it is
# evaluated. A missing, unreadable or unparseable snapshot sets nothing, which changes nothing, and so
# does any failure here: it never stops the hook.
# The parsed table is cached in aliases.cache under the state dir (state.sh), whose first line names the
# cache format, the snapshot's path, size, modification and change times and inode; a cache whose first
# line differs, or that is larger than the table can be, is rebuilt without reading its lines. The cache is read as data by _alias_table, like the parse it replaces, and a forged one can
# only add expansions, as a forged snapshot can. A cache that cannot be read or written leaves the parse
# as the only source; a symlinked cache or state dir is never used.
aliases_load() {
  local snap out h key size dir="" cache="" line="" tmp
  KERN_ALIASES=""
  # The table holds only what this snapshot defines, never a _KA_ variable from the environment.
  for h in ${!_KA_@}; do unset "$h"; done
  snap=$(alias_snapshot) || return 0
  if declare -F state_dir >/dev/null && key=$(_alias_key "$snap") && dir=$(state_dir); then
    cache="$dir/aliases.cache"
    line="kern aliases $_ALIASES_CACHE_V ${#_ALIASES_AWK}"$'\t'"$snap"$'\t'"$key"
    if [ -f "$cache" ] && [ ! -L "$cache" ] && [ ! -L "$dir" ] && size=$(_alias_key "$cache") &&
      [ "${size%% *}" -le $((4194304 + ${#line} + 1)) ] &&
      { IFS= read -r h && [ "$h" = "$line" ] && _alias_table; } 2>/dev/null <"$cache"; then
      return 0
    fi
  fi
  out=$(set -o pipefail; head -c 4194304 2>/dev/null <"$snap" | env LC_ALL=C awk -v sq="'" "$_ALIASES_AWK" 2>/dev/null) || return 0
  _alias_table <<<"$out"
  # A new file in the state dir, then a rename over the cache, so a planted symlink is never written through.
  if [ -n "$cache" ] && (umask 077 && mkdir -p "$dir") 2>/dev/null && [ ! -L "$dir" ] &&
    tmp=$(mktemp "$dir/.aliases.cache.XXXXXX" 2>/dev/null); then
    { printf '%s\n' "$line" "$out" >"$tmp" && mv -f "$tmp" "$cache"; } 2>/dev/null || rm -f "$tmp" 2>/dev/null
  fi
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

# _alias_var WORD VAR: sets VAR to the name of the _KA_ variable of the alias WORD; exit 1 when WORD
# is no alias aliases_load set. Each byte of WORD must be one of _ALIAS_CHARS, so the hex is one to one.
_alias_var() {
  local h="" c i=0
  [ "${#1}" -le 256 ] || return 1
  while [ "$i" -lt "${#1}" ]; do
    c=${1:i:1}
    case "$_ALIAS_CHARS" in *"$c"*) ;; *) return 1 ;; esac
    printf -v c '%02x' "'$c"
    h="$h$c"
    i=$((i + 1))
  done
  h="_KA_$h"
  [ -n "${!h-}" ] || return 1
  printf -v "$2" '%s' "$h"
}

# alias_expand SEG: when the head word of the simple command SEG is an alias aliases_load set, sets
# ALIAS_EXP to SEG with that word replaced by its expansion. Exit 1 otherwise. When the expansion ends
# in a space, the word after the alias is replaced too when it is such an alias, as zsh's trailing-space
# rule does, and so on, at most 8 times; a 9th word that is still such an alias starts a record of its
# own whose command name is $KERN_ALIAS_PAST_8, which G00 reads as built at run time, so autopilot denies
# it whatever word the expansions before it start with (nocorrect, watch). As zsh does, the
# head word is the first word after NAME=value words, redirections (with a target in the next word when
# none is attached) and the reserved words if then elif else do while until ! { time nocorrect coproc
# and repeat with its count; zsh does not expand an alias after command, builtin, exec, noglob or -, and
# neither does this. An assignment word with a quote, a $ or a backslash hands the search to
# _ALIAS_HEAD_AWK. Any other word with one, or with a backtick, is never an alias, as in zsh, and ends
# the search.
alias_expand() {
  local rest="$1" pre="" w t v skip=0 n=0
  [ -n "${KERN_ALIASES-}" ] || return 1
  while :; do
    rest=${rest#"${rest%%[!"$_ALIAS_BLANK"]*}"}
    w=${rest%%["$_ALIAS_BLANK"]*}
    case "$w" in
      '') return 1 ;;
      *[\"\'\\\$\`]*)
        [ "$skip" = 0 ] || return 1
        case "$w" in *=*) ;; *) return 1 ;; esac
        t=${w%%=*}
        t=${t%+}
        case "$t" in '' | [0123456789]* | *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_]*) return 1 ;; esac
        { IFS= read -r pre || :; IFS= read -r w || :; IFS= read -r rest || :; } <<EOF
$(printf '%s' "$1" | env LC_ALL=C awk -v sq="'" "$_ALIAS_HEAD_AWK")
EOF
        [ -n "$w" ] || return 1
        rest="$w$rest"
        break
        ;;
    esac
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
  _alias_var "$w" v || return 1
  pre="$pre${!v}"
  rest=${rest#"$w"}
  while :; do
    case "$pre" in *' ') ;; *) break ;; esac
    t=${rest#"${rest%%[!"$_ALIAS_BLANK"]*}"}
    w=${t%%["$_ALIAS_BLANK"]*}
    case "$w" in '' | *[\"\'\\\$\`]*) break ;; esac
    _alias_var "$w" v || break
    if [ "$n" -ge 8 ]; then
      # shellcheck disable=SC2016 # a literal $, for G00
      pre="$pre"'; $KERN_ALIAS_PAST_8 '
      break
    fi
    pre="$pre${!v}"
    rest=${t#"$w"}
    n=$((n + 1))
  done
  # shellcheck disable=SC2034 # read by git_words
  ALIAS_EXP="$pre$rest"
}
