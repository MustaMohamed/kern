# shellcheck shell=bash
# shellcheck disable=SC2154  # TOOL and AGENT are set by hooks/pre-tool-use
# G18: kern's read-only agents may run only allowlisted read commands in Bash.
# Sourced by hooks/pre-tool-use, which sets TOOL, AGENT and TOOL_INPUT and provides ti_get, git_words,
# git_sub, _shell_words and vote. G18_AGENTS holds the agent_type the M1 spike recorded for the
# investigator.
G18_AGENTS="kern:investigator"
# Stands for the output of a $( ) in the text _g18_read gives back.
G18_ANY=$'\034'

# g18_allowed SIMPLE_COMMAND: exit 0 when the command only reads. Options are judged on the words the
# shell passes, quotes and backslashes removed, so '-o' and -dele''te are seen as -o and -delete.
g18_allowed() {
  local c words w1 sub w n=0
  # 2>&1, >&2 and a redirect to /dev/null are dropped only when they end their word: >&1x writes to a
  # file named 1x, and >/dev/nullx to /dev/nullx.
  c=$(printf '%s' "$1" | sed -E -e 's/[0-9]*>&[0-9]+([[:space:]]|$)/\1/g' \
    -e 's#(&|[0-9]*)>[[:space:]]*/dev/null([[:space:]]|$)#\2#g' -e 's/^[[:space:]]*//')
  _g18_expands "$c" && return 1
  words=$(_shell_words "$c")
  w1=${words%%$'\n'*}
  # A word from a $( ) may be anything, so only a command that is safe with any word takes one.
  case "$c" in *"$G18_ANY"*)
    _g18_plain "$w1"
    return
    ;;
  esac
  case "$w1" in
    git)
      sub=$(git_sub "$c" | cut -f2) || return 1
      case "$sub" in
        status | log | show | blame | diff | grep | ls-files | ls-tree | rev-parse | rev-list | cat-file | merge-base | describe | shortlog | name-rev) ;;
        *) return 1 ;;
      esac
      # A config value, an external diff, a pager or an output file can run a program or write one.
      # git grep reads --op as --open-files-in-pager, and -O inside a cluster such as -nO.
      while IFS= read -r w; do
        case "$w" in -c | -c* | --config-env* | -O* | --op* | --output* | --ext-diff* | --textconv*) return 1 ;; esac
        case "$sub:$w" in grep:-[!-]*O*) return 1 ;; esac
      done <<EOF
$words
EOF
      ;;
    rg)
      # --pre and --hostname-bin run a program; -z runs decompression programs, alone or in a cluster
      # such as -nz.
      while IFS= read -r w; do
        case "$w" in --pre* | --search-zip* | --hostname-bin*) return 1 ;; --*) ;; -*z*) return 1 ;; esac
      done <<EOF
$words
EOF
      ;;
    printf)
      # printf -v NAME assigns a variable at run time, which G18 cannot follow, so printf takes no option.
      while IFS= read -r w; do
        n=$((n + 1))
        case "$n:$w" in 2:-*) return 1 ;; esac
      done <<EOF
$words
EOF
      ;;
    file)
      # -C writes a .mgc file, also inside a cluster such as -bC; file reads --co as --compile. -z and -Z
      # run decompression programs; --u is a prefix only of --uncompress and --uncompress-noreport.
      while IFS= read -r w; do
        case "$w" in --co* | --u*) return 1 ;; --*) ;; -*C* | -*z* | -*Z*) return 1 ;; esac
      done <<EOF
$words
EOF
      ;;
    sort)
      # -o writes a file, also inside a cluster such as -uo; --compress-program runs a program. sort
      # reads --o as --output and --co as --compress-program.
      while IFS= read -r w; do
        case "$w" in --o* | --co*) return 1 ;; --*) ;; -*o*) return 1 ;; esac
      done <<EOF
$words
EOF
      ;;
    find)
      while IFS= read -r w; do
        case "$w" in -delete | -exec* | -ok* | -fprint* | -fls) return 1 ;; esac
      done <<EOF
$words
EOF
      ;;
    sed)
      # Only sed -n with a script of line numbers and p, such as 1,20p or $p, then file names: a later
      # word that starts with - (-i, --in-place, -e 'w file') could write, so it is not allowed.
      while IFS= read -r w; do
        n=$((n + 1))
        case "$n" in
          1) ;;
          2) [ "$w" = -n ] || return 1 ;;
          3)
            case "$w" in *p) ;; *) return 1 ;; esac
            case "${w%p}" in *[!0-9,\$]*) return 1 ;; esac
            ;;
          *) case "$w" in -*) return 1 ;; esac ;;
        esac
      done <<EOF
$words
EOF
      [ "$n" -ge 3 ] || return 1
      ;;
    *) _g18_plain "$w1" || return 1 ;;
  esac
  return 0
}

# _g18_plain WORD: exit 0 when WORD is a read whose every option only reads, so any words may follow it.
_g18_plain() {
  case "$1" in
    grep | ls | cat | head | tail | wc | cut | tr | nl | stat | du | pwd | echo | basename | dirname | realpath | cd | true | test | jq | column | cmp | diff | comm) return 0 ;;
  esac
  return 1
}

# _g18_expands TEXT: exit 0 when the shell may turn TEXT into words it does not show, or write: a $ or a
# backtick outside single quotes ($_, ${x:--o}, $'-o', $(id)), a brace expansion ({-o,out.txt}), a > or <(
# outside all quotes, or a quote that never closes. A $ before a blank or a closing double quote stays a $,
# such as a regex anchor. A brace pair after @ with no comma or .. inside, such as git's HEAD@{1} or @{u},
# does not expand. One brace list of file names in a word passes (list below) only when the record's first
# word is cat, head, tail, wc, ls, grep, rg, stat or du: each takes extra words only as more operands to
# read. Other commands' words are positional, so git -C {.,branch} log runs git -C . branch log; they keep
# the plain rule.
_g18_expands() {
  printf '%s' "$1" | env LC_ALL=C awk -v sq="'" '
    # list W K: 1 when the record is a read (rd), and word W, the Kth, is not the first, does not start
    # with -, holds one { before one }, and the group holds a comma, no .., and items of name characters,
    # none empty or starting with -.
    function list(w, k,   g, a, m, i) {
      if (!rd || k == 1 || substr(w, 1, 1) == "-") return 0
      if (gsub(/[{]/, "{", w) != 1 || gsub(/[}]/, "}", w) != 1) return 0
      g = substr(w, index(w, "{") + 1); if (!index(g, "}")) return 0
      g = substr(g, 1, index(g, "}") - 1)
      if (!index(g, ",") || index(g, "..")) return 0
      m = split(g, a, ",")
      for (i = 1; i <= m; i++) if (a[i] !~ /^[A-Za-z0-9_.\/+][A-Za-z0-9_.\/+-]*$/) return 0
      return 1
    }
    { buf = buf (NR > 1 ? "\n" : "") $0 }
    END {
      # s keeps every character; a quoted or escaped brace, comma, blank, < or > becomes _, so it neither
      # expands, splits a word nor redirects, and a quoted - still starts its word.
      n = split(buf, C, ""); q = ""; s = ""
      for (i = 1; i <= n; i++) {
        c = C[i]
        if (q == sq) { if (c == sq) q = ""; else s = s (c ~ /[{},<>[:space:]]/ ? "_" : c); continue }
        if (c == "\\") { i++; s = s (C[i] ~ /[{},<>[:space:]]/ ? "_" : C[i]); continue }
        if (c == "`") exit 0
        if (c == "$" && C[i + 1] !~ /[[:space:]]/ && !(q != "" && C[i + 1] == "\"")) exit 0
        if (q == "\"") { if (c == "\"") q = ""; else s = s (c ~ /[{},<>[:space:]]/ ? "_" : c); continue }
        if (c == sq || c == "\"") { q = c; continue }
        s = s c
      }
      if (q != "" || s ~ />|<[(]/) exit 0
      gsub(/@[{][^,.{}]*[}]/, "@", s)
      m = split(s, W, /[[:space:]]+/); k = 0; rd = 0
      for (i = 1; i <= m; i++) {
        if (W[i] == "") continue
        k++
        if (k == 1) rd = W[i] ~ /^(cat|head|tail|wc|ls|grep|rg|stat|du)$/
        if (index(W[i], "{") && !list(W[i], k)) exit 0
      }
      exit 1
    }'
}

# _g18_read CMD: the simple commands of CMD, joined, one per line, with its loops and variables read out,
# for _g18_denied to judge; exit 1 when G18 cannot read all of it or a longer variable name is set. Exit 3,
# when a longer name is also read, gives the text it would have with a one-letter name.
# A for over literal words becomes its body once per word. A variable becomes its value, in every quote
# the shell expands it in: a plain literal, or $G18_ANY for a $( ) alone, whose commands take the
# assignment's place. Only one-letter names, and that is what makes an assignment safe: no shell and no
# allowlisted command reads one, while a longer name can change what runs. IFS, PATH and GIT_* do, and so
# do zsh's lowercase path and fpath, tied to PATH and FPATH, so case does not mark them and no list of such
# names stays complete. An assignment counts only at the top level, first or after ; or a newline that ends
# a list, and ending in ;, a newline or &&. A newline after &&, || or | does not end the list. Anywhere else
# the shell may skip or lose the assignment, and the value G18 judged would not be the one that runs. A
# nested loop or substitution stops the read, and so does any other expansion, a group, a subshell, a
# here-doc or a comment.
_g18_read() {
  printf '%s' "$1" | env LC_ALL=C awk -v sq="'" -v any="$G18_ANY" '
    function gap(i) { while (i <= n && (C[i] == " " || C[i] == "\t")) i++; return i }
    function past(i) { while (i <= n && (C[i] == " " || C[i] == "\t" || C[i] == "\n")) i++; return i }
    function plain(s) { return !R && Q < 2 && s ~ /^[A-Za-z0-9_.\/:@+-]+$/ }
    # ends(i): true when a command ends at i. The & and | of a redirect (2>&1, &>, >|) do not end one.
    function ends(i,   c) {
      c = C[i]
      if (i > n || c == ";" || c == "\n" || (sb && c == ")")) return 1
      if (c == "&") return C[i - 1] != ">" && C[i - 1] != "<" && C[i + 1] != ">"
      return c == "|" && C[i - 1] != ">"
    }
    # after(c): true when byte c may follow a bare $x. Only these: zsh reads any other as more of the
    # name, multibyte letters among them, or as a modifier or a subscript.
    function after(c) { return c == "" || index(" \t\n/.-\";|&)$", c) > 0 }
    # ref(i, q): adds the expansion at the $ at i, in quote q, to W and P. Only $x and ${x} of a set x
    # read. A $ that expands nothing stays a $, as in _g18_expands. U is 1 once a longer name is read.
    # Returns the last position read.
    function ref(i, q,   b, v) {
      v = C[i + 1]
      if (v == " " || v == "\t" || (q != "" && v == "\"")) { W = W "$"; P = P "$"; return i }
      b = v == "{"
      i += 1 + b
      for (v = ""; C[i] ~ /[A-Za-z0-9_]/; i++) v = v C[i]
      i--
      if (!(v in V)) exit 1
      if (b) { if (C[++i] != "}") exit 1 }
      else if (!after(C[i + 1])) exit 1
      if (v !~ /^[A-Za-z]$/) U = 1
      W = W V[v]; P = P V[v]; R = 1
      return i
    }
    # word(i): reads the word at i into W, its text with variables read, and P, with its quotes gone as
    # well. Q is 1 for a quote and 2 for a backslash; R is 1 for a variable. Returns the position after it.
    function word(i,   c, q, a) {
      W = P = ""; Q = R = 0; q = ""; a = i
      for (; i <= n; i++) {
        c = C[i]
        if (q == sq) { W = W c; if (c == sq) q = ""; else P = P c; continue }
        if (c == "`") exit 1
        if (c == "\\") { W = W c C[++i]; P = P C[i]; Q = 2; continue }
        if (c == "$") { i = ref(i, q); continue }
        if (c == "\"" || (c == sq && q == "")) { W = W c; q = (q == "" ? c : ""); if (!Q) Q = 1; continue }
        if (q != "") { W = W c; P = P c; continue }
        if (c == " " || c == "\t" || ends(i)) break
        if (c == "(" || c == ")" || (c == "<" && C[i + 1] == "<") || (c == "#" && i == a)) exit 1
        W = W c; P = P c
      }
      if (q != "" || W == "{" || W == "}") exit 1
      return i
    }
    # bind(v, i): reads the value at i of an assignment to v. Returns the position after it. T is 1 once
    # a longer name is set.
    function bind(v, i,   d) {
      if (v !~ /^[A-Za-z]$/) T = 1
      d = C[i] == "\""
      if (C[i + d] != "$" || C[i + d + 1] != "(") {
        i = word(i)
        if (!plain(P)) exit 1
        V[v] = P
        return i
      }
      sb = 1; i = stmts(i + d + 2, 2); sb = 0
      if (d && C[++i] != "\"") exit 1
      V[v] = any
      return i + 1
    }
    # loop(i): reads a for, from the word after it, and its body once per word. Returns the position
    # after its done.
    function loop(i,   v, m, k, w, b) {
      i = word(gap(i)); v = P
      if (Q || v !~ /^[A-Za-z_][A-Za-z0-9_]*$/) exit 1
      if (v !~ /^[A-Za-z]$/) T = 1
      i = word(gap(i))
      if (Q || P != "in") exit 1
      for (i = gap(i); !ends(i); i = gap(i)) {
        i = word(i)
        if (!plain(P)) exit 1
        w[++m] = P
      }
      if (!m || (C[i] != ";" && C[i] != "\n")) exit 1
      b = word(past(i + 1))
      if (Q || P != "do") exit 1
      for (k = 1; k <= m; k++) { V[v] = w[k]; i = stmts(b, 1) }
      delete V[v]
      return i
    }
    # stmts(i, ctx): reads statements from i, each command to O as a line, up to the end of the text (ctx
    # 0), the done of a loop body (1) or the ) of a substitution (2). Returns the position it stopped at.
    # lead: a statement that starts here is sure to run.
    function stmts(i, ctx,   lead, t) {
      lead = 1
      for (;;) {
        i = gap(i)
        if (i > n) { if (ctx) exit 1; return i }
        if (ctx == 2 && C[i] == ")") return i
        if (C[i] == ";" || C[i] == "\n") { lead = 1; i++; continue }
        if (C[i] == "&" || C[i] == "|") { lead = 0; i = past(i + (C[i + 1] == C[i] ? 2 : 1)); continue }
        if (match(substr(buf, i), /^[A-Za-z_][A-Za-z0-9_]*=/)) {
          if (ctx || !lead) exit 1
          t = RLENGTH
          i = gap(bind(substr(buf, i, t - 1), i + t))
          if (i <= n && C[i] != ";" && C[i] != "\n" && (C[i] != "&" || C[i + 1] != "&")) exit 1
          continue
        }
        lead = 0
        i = word(i)
        if (R) exit 1
        if (!Q && P == "done" && ctx == 1) return i
        if (!Q && P == "for") {
          if (ctx) exit 1
          i = gap(loop(i))
          if (!ends(i)) exit 1
          continue
        }
        t = W
        for (i = gap(i); !ends(i); i = gap(i)) { i = word(i); t = t " " W }
        O = O t "\n"
      }
    }
    { buf = buf (NR > 1 ? "\n" : "") $0 }
    END { n = split(buf, C, ""); stmts(1, 0); printf "%s", O; exit (U ? 3 : T ? 1 : 0) }'
}

# _g18_denied TEXT: exit 0 when a command of TEXT is not allowed, with that command in _G18_LINE.
_g18_denied() {
  local line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if ! g18_allowed "$line"; then
      _G18_LINE=$line
      return 0
    fi
  done <<EOF
$(git_words "$1")
EOF
  return 1
}

# _g18_join CMD: CMD with its line continuations removed. A backslash pairs with the next character, so an
# escaped backslash before a newline stays. Exit 1 on a line whose comment ends in a backslash, or on any
# here-doc: the shell keeps a continuation there, so removing it would hide the next line.
_g18_join() {
  printf '%s' "$1" | env LC_ALL=C awk '
    { if ($0 ~ /(^|[ \t;&|()])#.*\\$/) bad = 1; buf = buf (NR > 1 ? "\n" : "") $0 }
    END {
      if (bad || index(buf, "<<")) exit 1
      n = split(buf, C, "")
      for (i = 1; i <= n; i++) {
        if (C[i] != "\\") { printf "%s", C[i]; continue }
        if (C[i + 1] != "\n") printf "%s%s", C[i], C[i + 1]
        i++
      }
    }'
}

# _g18_denies CMD: exit 0 when G18 denies CMD, with the command it names in _G18_LINE. Both passes read CMD
# joined, since the shell joins lines before it reads a name or an expansion. A command with a loop or a
# variable is judged as _g18_read reads it, so a body or a value that is not allowed alone is denied here
# too; one it cannot read is denied. _G18_LONG is 1 when only a longer variable name stops CMD.
_g18_denies() {
  local join=$1 text rc=0
  _G18_LONG=0
  _G18_LINE=$1
  case "$1" in *\\$'\n'*) join=$(_g18_join "$1") || return 0 ;; esac
  _g18_denied "$join" || return 1
  text=$(_g18_read "$join") || rc=$?
  case "$rc" in 0 | 3) ;; *) return 0 ;; esac
  _g18_denied "$text" && return 0
  [ "$rc" = 3 ] || return 1
  _G18_LONG=1
}

guard_g18() {
  [ "$TOOL" = "Bash" ] || return 0
  [ -n "${AGENT:-}" ] || return 0
  case " $G18_AGENTS " in *" $AGENT "*) ;; *) return 0 ;; esac
  local cmd next="Ask the controller to run it."
  if ! cmd=$(ti_get command); then
    vote deny G18 "read-only agent: the Bash input has no command"
    return 0
  fi
  if _g18_denies "$cmd"; then
    [ "$_G18_LONG" = 0 ] || next="G18 reads only one-letter variable names: use a one-letter name and retry."
    vote deny G18 "$AGENT is read-only; '${_G18_LINE%%[[:space:]]*}' with these arguments is not on its allowlist (git log, show, blame, diff, grep, ls-files, status; rg, grep, ls, cat, head, tail, wc; find without -exec or -delete; sed -n with line numbers; a for over literal words; a one-letter variable set first to a plain value or a read-only \$( )). $next"
  fi
}
