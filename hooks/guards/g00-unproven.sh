# shellcheck shell=bash
# G00 under autopilot: kern denies a Bash command it cannot read. Every other guard votes on the
# command shapes it knows and on nothing else, so a shape kern cannot see passes them all, and under
# autopilot nobody is there to ask. Interactive mode is unchanged: G00 votes nothing there. Its
# label is G00, apart from the G0 of fail_closed.
# A git_words record is unread when:
# - its command name is built at run time, so the variable can supply the program or its options: a
#   $, a backtick or a brace pattern in it, or a glob with words after it (a lone `*` is a case
#   pattern as often as a command). A path under a variable ($HOME/.local/bin/bats) is read;
# - a shell runs a script kern does not read: the -c of sh, bash, zsh or dash anywhere but the head
#   of the record (git_words prints the head's script as records of its own), the -c of ksh, mksh,
#   ash, csh, fish and the other shells, su or runuser -c, or a word among a shell's options that is
#   built at run time;
# - the shell at its head reads its program from a pipe, a here-string, a file descriptor or a
#   process substitution, or another shell reads a here-doc (git_words keeps the here-doc bodies of
#   sh, bash, zsh and dash as records). A `< file` redirect is a script file;
# - it defines an alias, runs `builtin eval` (eval of run-time text is a record of its own, and its
#   command name is built at run time), or sources stdin, a file descriptor or a process
#   substitution;
# - it is a builtin that evaluates a string as arithmetic or a subscript (let, declare -i, typeset -i,
#   local -i, printf -v, read, or [[/test/[ with -eq/-ne/-lt/-le/-gt/-ge) and holds a $( ) or backtick
#   inside single quotes, which the arithmetic re-runs though git_words read it as literal text; or it
#   holds, in any single-quoted string, an array subscript that opens with a substitution ([$( or [`,
#   optional spaces after [), whose value is stored and evaluated as arithmetic later. Reading the inner
#   command exactly is not practical, so autopilot denies; interactively no guard votes (M3).
# Accepted limits, as a script file run by an interpreter is: the inline code, here-doc or pipe of an
# interpreter other than a shell (python -c, node -e or -p, perl -e or -E, ruby -e, php -r, deno
# eval, osascript -e, lua -e, R -e, julia -e, pwsh -c, `python3 - <<EOF`); a program or script
# operand that is a path under a variable ($VAR/literal-path or "$VAR"/literal-path); an awk program,
# a sed script and the commands other tools embed (git -c, ssh -o ProxyCommand, watch, npx -c).

# _G00_AWK: the judge, run on git_words records after _GW_AWK. Prints `U<TAB>what` for each thing it
# cannot read, once, and `.` at the end.
# shellcheck disable=SC2016 # awk text
_G00_AWK='
  # g0_family(b): the shell family of the command whose last path part is b: sh (git_words unwraps
  # its -c), osh (another shell, never unwrapped), fish (osh that also takes -C and --command), su
  # (runuser too), or "".
  function g0_family(b,   l) {
    l = tolower(b)
    if (l ~ /^(ba|z|da)?sh$/) return "sh"
    if (l ~ /^(k|mk|lk|ok|pdk|a|ya|po|rba|t?c)sh$/ || l == "ksh93") return "osh"
    if (l == "fish") return "fish"
    if (l == "su" || l == "runuser") return "su"
    return ""
  }
  # g0_flat(s): s with each $( ), $(( )), ${ } and backtick span replaced by $(_), so sw reads one
  # word where the shell sees one (`x=$(ls -t a)` is an assignment, not a command `a`). git_words
  # prints the bodies as records of their own. Inside a span, quotes are skipped and parens counted.
  # A plain ${NAME} stays, as $NAME does, so gw_path can read ${HOME}/bin/x.
  function g0_flat(s,   n, C, i, j, q, sq2, d, o, e, st, out) {
    if (!index(s, "$(") && !index(s, "${") && !index(s, "`")) return s
    n = split(s, C, ""); out = ""; q = ""; st = 1
    for (i = 1; i <= n; i++) {
      if (q == sq) { if (C[i] == sq) q = ""; continue }
      if (C[i] == "\\") { i++; continue }
      if (C[i] == sq && q == "") { q = sq; continue }
      if (C[i] == "\"") { q = q == "\"" ? "" : "\""; continue }
      if (C[i] != "`" && !(C[i] == "$" && (C[i + 1] == "(" || C[i + 1] == "{"))) continue
      if (C[i + 1] == "{" && C[i + 2] ~ /[A-Za-z_]/) {
        for (j = i + 3; j <= n && C[j] ~ /[A-Za-z0-9_]/; j++) ;
        if (C[j] == "}") { i = j; continue }
      }
      out = out substr(s, st, i - st) "$(_)"
      if (C[i] == "`") { for (i++; i <= n && C[i] != "`"; i++) if (C[i] == "\\") i++ }
      else {
        o = C[++i]; e = o == "(" ? ")" : "}"; d = 1; sq2 = ""
        for (i++; i <= n; i++) {
          if (sq2 == sq) { if (C[i] == sq) sq2 = ""; continue }
          if (C[i] == "\\") { i++; continue }
          if (sq2 == "\"") { if (C[i] == "\"") sq2 = ""; continue }
          if (C[i] == sq || C[i] == "\"") sq2 = C[i]
          else if (C[i] == o) d++
          else if (C[i] == e && !--d) break
        }
      }
      st = i + 1
    }
    return out substr(s, st)
  }
  # g0_out(what): prints what once.
  function g0_out(what) {
    if (length(what) > 120) what = substr(what, 1, 117) "..."
    if (!(what in g0_seen)) { g0_seen[what] = 1; print "U\t" what }
  }
  function g0_glob(w,   i) { return w ~ /[*?]/ || ((i = index(w, "[")) && index(substr(w, i + 1), "]")) }
  # g0_src(): where the record reads stdin from: hs a here-string, hd a here-doc, fd a file
  # descriptor, ps a process substitution (or a missing target), file a file, "" not redirected.
  function g0_src(   k, w, t, src) {
    src = ""
    for (k = 1; k <= sw_n; k++) {
      w = sw_w[k]
      if (w !~ /^0?</) continue
      sub(/^0/, "", w)
      if (w ~ /^<<</) src = "hs"
      else if (w ~ /^<</) src = "hd"
      else if (w ~ /^<&/) src = "fd"
      else {
        t = substr(w, 2); sub(/^>/, "", t)
        if (t == "") t = sw_w[k + 1]
        src = t == "" || t ~ /^[<(]/ ? "ps" : "file"
      }
    }
    return src
  }
  function g0_from(src) {
    if (src == "hs") return "a here-string"
    if (src == "hd") return "a here-doc"
    if (src == "fd") return "a file descriptor"
    if (src == "ps") return "a process substitution"
    return "a pipe or stdin"
  }
  # g0_stream(w): 0 when the path w names stdin (/dev/stdin, /dev/fd/0, /proc/self/fd/0), fd when it
  # names another file descriptor, else "".
  function g0_stream(w) {
    if (w !~ /^\/(dev\/(stdin|fd\/[0-9]+)|proc\/self\/fd\/[0-9]+)$/) return ""
    return w ~ /(stdin|\/0)$/ ? "0" : "fd"
  }
  # g0_xargs(k): the index of the command that xargs at cw_w[k] runs, after its options (those of
  # GNU and BSD xargs that take the next word), or 0 when there is none.
  function g0_xargs(k,   j, w) {
    for (j = k + 1; j <= cw_n; j++) {
      w = cw_w[j]
      if (w == "--") return j < cw_n ? j + 1 : 0
      if (w !~ /^-/) return j
      if (w ~ /^-[IJLnPsEdaRS]$/ || w ~ /^--(arg-file|delimiter|max-args|max-procs|max-chars|process-slot-var)$/) j++
    }
    return 0
  }
  # g0_name(j, by): when the word at j, which by runs as a command, is built at run time, says so.
  function g0_name(j, by,   w) {
    if (!j || j > cw_n) return
    w = cw_w[j]
    if ((gw_dyn(w) && !gw_path(w)) || g0_glob(w)) g0_out("the command name " w " after " by " is built at run time")
  }
  # g0_any(k, re): the first word after k that matches re in lower case, or "".
  function g0_any(k, re,   j) {
    for (j = k + 1; j <= cw_n; j++) if (tolower(cw_w[j]) ~ re) return cw_w[j]
    return ""
  }
  # g0_hasarg(re): true when some word after the command name matches re.
  function g0_hasarg(re,   j) { for (j = 2; j <= cw_n; j++) if (cw_w[j] ~ re) return 1; return 0 }
  # g0_sqsub(s): true when s holds a $( ) or a backtick inside a single-quoted span (an ANSI-C $'"'"'...'"'"'
  # counts, since arithmetic re-expands its literal text). That is the one a builtin that evaluates a
  # string as arithmetic runs though git_words read the quote as literal; a $( ) or backtick unquoted or
  # in double quotes is already a record of its own, so it is not flagged here.
  function g0_sqsub(s,   nn, C, i, c, q) {
    nn = split(s, C, ""); q = ""
    for (i = 1; i <= nn; i++) {
      c = C[i]
      if (q == sq) {
        if (c == sq) { q = ""; continue }
        if (c == "`" || (c == "$" && C[i + 1] == "(")) return 1
        continue
      }
      if (q == "\"") {
        if (c == "\\" && index("\"\\$`", C[i + 1])) i++
        else if (c == "\"") q = ""
        continue
      }
      if (c == "\\") { i++; continue }
      if (c == sq) q = sq
      else if (c == "\"") q = "\""
    }
    return 0
  }
  # g0_sqarr(s, lit): true when a single-quoted span of s holds an array subscript that opens with a
  # substitution: a name character, [, optional blanks, then $( or a backtick. x='"'"'a[$(cmd)]'"'"'
  # stored and later evaluated as arithmetic (echo $((x)), (( )), an integer assignment) runs cmd in
  # bash; the single quote is literal where it is written, so git_words cannot surface it. With lit, all
  # of s is literal text, as a quoted here-doc body is. A single-quoted $( ) or backtick that is not a
  # subscript is not flagged, and neither is a [ with no name before it, as in the regex class [$(]:
  # [$(cmd)] with no name runs nothing in any shell (measured).
  function g0_sqarr(s, lit,   nn, C, i, c, q, br, p) {
    nn = split(s, C, ""); q = lit ? sq : ""; br = 0; p = ""
    for (i = 1; i <= nn; i++) {
      c = C[i]
      if (q == sq) {
        if (c == sq && !lit) { q = ""; br = 0; p = c; continue }
        if (c == "[") { br = p ~ /[A-Za-z0-9_]/; p = c; continue }
        if (br) {
          if (c == " " || c == "\t") continue
          if (c == "`" || (c == "$" && C[i + 1] == "(")) return 1
          br = 0
        }
        p = c
        continue
      }
      p = c
      if (q == "\"") {
        if (c == "\\" && index("\"\\$`", C[i + 1])) i++
        else if (c == "\"") q = ""
        continue
      }
      if (c == "\\") { i++; continue }
      if (c == sq) q = sq
      else if (c == "\"") q = "\""
    }
    return 0
  }
  # g0_judge(f, k, b): judges the shell b, of family f, at cw_w[k].
  function g0_judge(f, k, b,   s0, s1, src, w) {
    # su and runuser run a -c through a shell; fish also takes -C and --command. Any word may hold it.
    if (f == "su" || f == "fish") {
      w = g0_any(k, "^(-[a-z]*c|--(init-|session-)?command(=|$))")
      if (w != "") g0_out(b " " w " runs a script kern does not read")
      if (f == "su" || w != "") return
    }
    s1 = shc(k, 1); s0 = shc(k, 0)
    if (s0 < 0 || s1 < 0) { g0_out("a word among the options of " b " is built at run time"); return }
    if (s0 > 0 || s1 > 0) {
      if (f != "sh") g0_out(b " -c runs a script kern does not read")
      else if (k > 1) g0_out(b " -c after " cw_w[1] " runs a script kern does not read")
      return
    }
    if (k > 1 || g0_any(k, "^--?(version|help)$") != "") return
    # A script operand is a file, unless it names stdin (then it reads the stream below) or an fd.
    if (shc_op && !shc_s) {
      if ((w = g0_stream(cw_w[shc_op])) == "") return
      if (w == "fd") { g0_out(b " reads its program from a file descriptor"); return }
    }
    src = g0_src()
    if (src == "file" || (src == "hd" && f == "sh")) return
    g0_out(b " reads its program from " g0_from(src))
  }
  {
    # A single-quoted array subscript that opens with a substitution ([$( or [`), anywhere in the
    # command, is read before anything else: its value is stored and evaluated as arithmetic later,
    # running the inner command, which git_words cannot surface (Task 7a review concern 1). It is checked
    # on the raw record so a record that is only an assignment (x='"'"'a[$(cmd)]'"'"', skipped below as it
    # names no command) is still caught. A record that starts with a \035 byte is a quoted here-doc body,
    # which git_words gives only to G00 (_GW_QB): it is data, scanned whole as literal text for the same
    # subscript (re-review Critical 1), and read no further. A command that holds the byte itself makes
    # git_words print such a record as an ordinary one too; its command name would start with the byte,
    # which no shell finds, so reading it no further here hides nothing.
    if (substr($0, 1, 1) == "\035") {
      if (g0_sqarr(substr($0, 2), 1)) g0_out("a quoted here-doc body holds an array subscript with a $( ) or backtick kern cannot read")
      next
    }
    if (g0_sqarr($0, 0)) { g0_out("a single-quoted array subscript holds a $( ) or backtick kern cannot read"); next }
    sw(g0_flat($0)); cw_reset()
    for (k = 1; k <= sw_n; k++) cw(sw_w[k])
    # The redirections after the command name, and their targets, are not arguments.
    m = 0
    for (k = 1; k <= cw_n; k++) {
      if (k > 1 && cw_w[k] ~ /^[0-9]*(<|>|&>)/) { if (cw_w[k] ~ /^[0-9]*[<>&|]+$/) k++; continue }
      cw_w[++m] = cw_w[k]
    }
    if (!(cw_n = m)) next
    h = cw_w[1]
    if ((gw_dyn(h) && !gw_path(h)) || (cw_n > 1 && g0_glob(h))) {
      # A span g0_flat collapsed is named by the record it came from.
      if (index(h, "$(_)")) h = "of `" substr($0, 1, 60) "`"
      g0_out("the command name " h " is built at run time")
      next
    }
    hb = tolower(P[split(h, P, "/")]); k = 1
    if (hb == "alias") { for (k = 2; k <= cw_n; k++) if (cw_w[k] ~ /=/) { g0_out("alias defines a command kern does not read"); next } }
    if (hb == "builtin" && cw_n > 1) {
      hb = tolower(cw_w[2]); k = 2
      if (hb == "eval") { g0_out("builtin eval runs text kern does not read"); next }
    }
    if ((hb == "source" || hb == ".") && (k == cw_n || g0_stream(cw_w[k + 1]) != "")) {
      g0_out(hb " reads a script from stdin, a file descriptor or a process substitution")
      next
    }
    if ((hb == "source" || hb == ".") && gw_dyn(cw_w[k + 1]) && !gw_path(cw_w[k + 1])) {
      g0_out("the script name " cw_w[k + 1] " that " hb " reads is built at run time")
      next
    }
    # A builtin that evaluates a string as arithmetic or a subscript runs a $( ) or backtick hidden in
    # single quotes, which git_words read as literal text and cannot surface: let, declare -i, typeset
    # -i, local -i, printf -v, read, and [[/test/[ with an arithmetic comparison. bash runs let, declare
    # -i, typeset -i, local -i (in a function) and [[ -eq ]]; bash and zsh run printf -v and read. The
    # integer and float of zsh, and export -i or readonly -i, ran nothing in any of the three shells.
    # Under autopilot it fails closed; the inner command is not visible as a record, so interactively no
    # guard votes (an M3 limit).
    ab = hb == "let" || hb == "read" ||
      ((hb == "declare" || hb == "typeset" || hb == "local") && g0_hasarg("^-[a-zA-Z]*i")) ||
      (hb == "printf" && g0_hasarg("^-v$")) ||
      ((hb == "[[" || hb == "test" || hb == "[") && g0_hasarg("^-(eq|ne|lt|le|gt|ge)$"))
    if (ab && g0_sqsub($0)) {
      g0_out("a string " hb " evaluates as arithmetic holds a $( ) or backtick kern cannot read")
      next
    }
    # Each shell judged; and the command that xargs runs, or find runs after -exec, -execdir, -ok or
    # -okdir, read as a command name.
    fnd = 0
    for (k = 1; k <= cw_n; k++) {
      b = P[split(cw_w[k], P, "/")]
      if ((f = g0_family(b)) != "") g0_judge(f, k, b)
      if (tolower(b) == "xargs") g0_name(g0_xargs(k), "xargs")
      else if (tolower(b) == "find") fnd = 1
      else if (fnd && cw_w[k] ~ /^-(exec|execdir|ok|okdir)$/) g0_name(k + 1, "find " cw_w[k])
    }
  }
  END { print "." }
'

guard_g00() {
  [ "$TOOL" = Bash ] && [ "${AUTOPILOT:-0}" = 1 ] || return 0
  local cmd out line seen=0 what=""
  cmd=$(ti_get command) || return 0
  # _GW_QB asks git_words for each quoted here-doc body that may hold an array subscript, as a \035
  # record only this judge reads. It is set in the substitution subshell, so no other guard gets one.
  # shellcheck disable=SC2153 # _GW_AWK is set in gitctx.sh
  out=$(set -o pipefail; _GW_QB=1; git_words "$cmd" | env LC_ALL=C awk -v sq="'" "$_GW_AWK$_G00_AWK") || out=""
  while IFS= read -r line; do
    case "$line" in
      .) seen=1 ;;
      U*) what="${what:+$what, }${line#U	}" ;;
    esac
  done <<EOT
$out
EOT
  [ "$seen" = 1 ] || what="the command (its judge failed)"
  [ -n "$what" ] || return 0
  vote deny G00 "under autopilot kern denies what it cannot read: $what; to go on, write the code to a file in the repo and run the file, spell each command name out, or have the user run it with !"
}
