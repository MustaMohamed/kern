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
#   substitution.
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
  # shellcheck disable=SC2153 # _GW_AWK is set in gitctx.sh
  out=$(set -o pipefail; git_words "$cmd" | LC_ALL=C awk -v sq="'" "$_GW_AWK$_G00_AWK") || out=""
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
