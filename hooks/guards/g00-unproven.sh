# shellcheck shell=bash
# G0 under autopilot: kern denies a Bash command it cannot read. Every other guard votes on the
# command shapes it knows and on nothing else, so a shape kern cannot see passes them all, and under
# autopilot nobody is there to ask. Interactive mode is unchanged: G0 votes nothing there.
# A git_words record is unread when:
# - its command name is built at run time: it holds a $, a backtick or a brace pattern, or a glob
#   with words after it (a lone `*` is a case pattern as often as a command);
# - an interpreter at any of its words runs inline code (the table in _G00_AWK: the -c of a shell,
#   python -c, node -e, perl -e and the like). The -c script of sh, bash, zsh or dash at the head of
#   the record is read, since git_words prints it as records of its own, unless a word among the
#   options of that shell is built at run time;
# - the interpreter at its head reads its program from stdin: a pipe, a here-string, a file
#   descriptor or a process substitution, or a here-doc to any interpreter but sh, bash, zsh or dash
#   (git_words keeps their here-doc bodies as records). A `< file` redirect is a script file;
# - it defines an alias, runs `builtin eval`, or sources stdin, a file descriptor or a process
#   substitution.
# A script file run by an interpreter is allowed: kern does not read files (an accepted limit). So
# are an awk program, a sed script and the commands other tools embed (git -c, ssh -o ProxyCommand).

# _G00_AWK: the judge, run on git_words records after _GW_AWK. Prints `U<TAB>what` for each thing it
# cannot read, once, and `.` at the end.
# shellcheck disable=SC2016 # awk text
_G00_AWK='
  # g0_fam(f, in, vn, vr, vd, st, li, lv, ex): the option table of the interpreter family f. Option
  # letters that give inline code (in), that take the rest of their cluster or else the next word as
  # a value (vn), that take the rest of their cluster (vr), that take the digits after them (vd), and
  # that name a module or file to run (st); long options that give inline code (li) and that take the
  # next word as a value (lv); words that print and exit (ex). From each tool --help.
  function g0_fam(f, in_, vn, vr, vd, st, li, lv, ex) {
    G0IN[f] = in_; G0VN[f] = vn; G0VR[f] = vr; G0VD[f] = vd; G0ST[f] = st
    G0LI[f] = " " li " "; G0LV[f] = " " lv " "; G0EX[f] = " " ex " "
  }
  BEGIN {
    g0_fam("py", "c", "WX", "", "", "m", "", "--check-hash-based-pycs", "-V -VV --version -h --help -?")
    g0_fam("node", "ep", "rC", "", "", "", "--eval --print", "--allow-fs-read --allow-fs-write " \
      "--build-snapshot-config --conditions --cpu-prof-dir --cpu-prof-interval --cpu-prof-name " \
      "--diagnostic-dir --disable-proto --disable-warning --dns-result-order --env-file " \
      "--env-file-if-exists --experimental-config-file --experimental-default-type " \
      "--experimental-loader --experimental-sea-config --experimental-test-isolation --heap-prof-dir " \
      "--heap-prof-interval --heap-prof-name --heapsnapshot-near-heap-limit --heapsnapshot-signal " \
      "--icu-data-dir --import --input-type --inspect-publish-uid --loader --localstorage-file " \
      "--max-http-header-size --max-old-space-size-percentage " \
      "--network-family-autoselection-attempt-timeout --openssl-config --redirect-warnings " \
      "--report-filename --report-signal --require --run --secure-heap --secure-heap-min " \
      "--snapshot-blob --test-concurrency --test-coverage-branches --test-coverage-exclude " \
      "--test-coverage-functions --test-coverage-include --test-coverage-lines --test-name-pattern " \
      "--test-reporter --test-reporter-destination --test-shard --test-skip-pattern --test-timeout " \
      "--title --tls-cipher-list --tls-keylog --trace-event-categories --trace-event-file-pattern " \
      "--trace-require-module --unhandled-rejections --use-largepages --v8-pool-size " \
      "--watch-kill-signal --watch-path", "-v --version -h --help")
    g0_fam("bun", "ep", "rF", "", "", "", "--eval --print", "--preload --require --import --cwd " \
      "--config --env-file --port --conditions --title --console-depth --user-agent --filter --shell " \
      "--elide-lines --install --unhandled-rejections --dns-result-order --max-http-header-size " \
      "--fetch-preconnect --cpu-prof-name --cpu-prof-dir --cpu-prof-interval --heap-prof-name " \
      "--heap-prof-dir --cron-title --cron-period", "-v --version -h --help")
    g0_fam("perl", "eE", "I", "MmixFdDCV", "l0", "", "", "", "-v -V -h")
    g0_fam("ruby", "e", "IrCE", "FixTWK", "0", "", "", "--encoding --external-encoding " \
      "--internal-encoding --enable --disable --dump --backtrace-limit --crash-report --parser",
      "-v --version -h --help --copyright")
    g0_fam("php", "rRBE", "cdztS", "", "", "f", "--run --process-begin --process-code --process-end",
      "--php-ini --define --rf --rc --re --rz --ri", "-v --version -h --help -i --info -m --modules")
    g0_fam("osa", "e", "ls", "", "", "", "", "", "")
    g0_fam("lua", "e", "l", "", "", "", "", "", "-v")
    g0_fam("r", "e", "", "", "", "f", "", "", "--version --help")
    g0_fam("julia", "eE", "pLJCHt", "Og", "", "", "--eval --print", "", "-v --version -h --help")
    g0_fam("fish", "cC", "dfo", "", "", "", "--command --init-command", "--debug --debug-output " \
      "--features --profile --profile-startup", "-v --version -h --help")
  }
  # g0_family(b): the interpreter family of the command whose last path part is b, or "".
  function g0_family(b,   l) {
    l = tolower(b)
    if (l ~ /^(ba|z|da)?sh$/) return "sh"
    if (l ~ /^(k|mk|lk|ok|pdk|a|ya|po|rba|t?c)sh$/ || l == "ksh93") return "osh"
    if (l ~ /^(python|pypy)[0-9.]*$/) return "py"
    if (l == "node" || l == "nodejs") return "node"
    if (l ~ /^(bun|perl|ruby|php|fish|deno|julia)$/) return l
    if (l ~ /^(perl|ruby|php)[0-9.]+$/) { sub(/[0-9.]+$/, "", l); return l }
    if (l == "osascript") return "osa"
    if (l ~ /^lua(jit|[0-9.]*)$/) return "lua"
    if (l == "rscript" || b == "R") return "r"
    if (l == "su" || l == "runuser") return "su"
    if (l ~ /^(pwsh|powershell)(\.exe)?$/) return "pwsh"
    return ""
  }
  # g0_flat(s): s with each $( ), $(( )), ${ } and backtick span replaced by $_, so sw reads one word
  # where the shell sees one (`x=$(ls -t a)` is an assignment, not a command `a`). git_words prints
  # the bodies as records of their own. Inside a span, quotes are skipped and parens counted.
  function g0_flat(s,   n, C, i, q, sq2, d, o, e, st, out) {
    if (!index(s, "$(") && !index(s, "${") && !index(s, "`")) return s
    n = split(s, C, ""); out = ""; q = ""; st = 1
    for (i = 1; i <= n; i++) {
      if (q == sq) { if (C[i] == sq) q = ""; continue }
      if (C[i] == "\\") { i++; continue }
      if (C[i] == sq && q == "") { q = sq; continue }
      if (C[i] == "\"") { q = q == "\"" ? "" : "\""; continue }
      if (C[i] != "`" && !(C[i] == "$" && (C[i + 1] == "(" || C[i + 1] == "{"))) continue
      out = out substr(s, st, i - st) "$_"
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
  # g0_scan(f, k): reads the options of the interpreter at cw_w[k] by the table of its family f.
  # Returns I for inline code (g0_flag holds the option), D when a word that may be an option is built
  # at run time, S for a program read from stdin (-), N when no program operand follows, E for an
  # option that prints and exits, and "" for a script file or module.
  function g0_scan(f, k,   j, w, nm, n, i, C, ch) {
    for (j = k + 1; j <= cw_n; j++) {
      w = cw_w[j]
      if (index(G0EX[f], " " w " ")) return "E"
      if (w == "-") return "S"
      if (w == "--") return j < cw_n ? "" : "N"
      if (w !~ /^-/) return gw_dyn(w) ? "D" : ""
      if (gw_dyn(w)) return "D"
      if (w ~ /^--/) {
        nm = w; sub(/=.*/, "", nm)
        if (index(G0LI[f], " " nm " ")) { g0_flag = nm; return "I" }
        if (w !~ /=/ && index(G0LV[f], " " nm " ") && ++j <= cw_n && gw_dyn(cw_w[j])) return "D"
        continue
      }
      n = split(substr(w, 2), C, "")
      for (i = 1; i <= n; i++) {
        ch = C[i]
        if (index(G0IN[f], ch)) { g0_flag = w; return "I" }
        if (index(G0ST[f], ch)) return ""
        if (index(G0VN[f], ch)) { if (i == n && ++j <= cw_n && gw_dyn(cw_w[j])) return "D"; break }
        if (index(G0VR[f], ch)) break
        if (index(G0VD[f], ch)) while (i < n && C[i + 1] ~ /[0-9]/) i++
      }
    }
    return "N"
  }
  # g0_any(k, re): the first word after k that matches re in lower case, or "".
  function g0_any(k, re,   j) {
    for (j = k + 1; j <= cw_n; j++) if (tolower(cw_w[j]) ~ re) return cw_w[j]
    return ""
  }
  # g0_judge(f, k, b): judges the interpreter b, of family f, at cw_w[k].
  function g0_judge(f, k, b,   r, s0, s1, src, w) {
    if (f == "sh" || f == "osh") {
      s1 = shc(k, 1); s0 = shc(k, 0)
      if (s0 < 0 || s1 < 0) { g0_out("a word among the options of " b " is built at run time"); return }
      if (s0 > 0 || s1 > 0) {
        if (f == "osh") g0_out(b " -c runs a script kern does not read")
        else if (k > 1) g0_out(b " -c after " cw_w[1] " runs a script kern does not read")
        return
      }
      if (k > 1 || (shc_op && !shc_s) || g0_any(k, "^--?(version|help)$") != "") return
      src = g0_src()
      if (src == "file" || (src == "hd" && f == "sh")) return
      g0_out(b " reads its program from " g0_from(src))
      return
    }
    if (f == "su") w = g0_any(k, "^(-[a-z]*c|--(session-)?command(=|$))")
    else if (f == "pwsh") w = g0_any(k, "^[-/](c|e|ec|cwa|com[a-z]*|enc[a-z]*)$")
    else if (f == "deno") w = g0_any(k, "^(eval|--eval(-file)?(=.*)?)$")
    if (f == "su" || f == "pwsh" || f == "deno") { if (w != "") g0_out(b " " w " runs inline code"); return }
    r = g0_scan(f, k)
    if (r == "I") { g0_out(b " " g0_flag " runs inline code"); return }
    if (k > 1 || r == "" || r == "E") return
    if (r == "D") { g0_out("a word among the options of " b " is built at run time"); return }
    src = g0_src()
    if (src == "file" || (r == "N" && f != "py" && src != "hd" && src != "hs")) return
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
    if (gw_dyn(h) || (cw_n > 1 && g0_glob(h))) {
      # A span g0_flat collapsed is named by the record it came from.
      if (index(h, "$_")) h = "of `" substr($0, 1, 60) "`"
      g0_out("the command name " h " is built at run time")
      next
    }
    hb = tolower(P[split(h, P, "/")]); k = 1
    if (hb == "alias") { for (k = 2; k <= cw_n; k++) if (cw_w[k] ~ /=/) { g0_out("alias defines a command kern does not read"); next } }
    if (hb == "builtin" && cw_n > 1) {
      hb = tolower(cw_w[2]); k = 2
      if (hb == "eval") { g0_out("builtin eval runs text kern does not read"); next }
    }
    if ((hb == "source" || hb == ".") && (k == cw_n || cw_w[k + 1] ~ /^\/(dev\/(stdin|fd\/)|proc\/self\/fd\/)/)) {
      g0_out(hb " reads a script from stdin, a file descriptor or a process substitution")
      next
    }
    for (k = 1; k <= cw_n; k++) {
      b = P[split(cw_w[k], P, "/")]
      if ((f = g0_family(b)) != "") g0_judge(f, k, b)
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
  vote deny G0 "under autopilot kern denies what it cannot read: $what; to go on, write the code to a file in the repo and run the file, spell each command name out, or have the user run it with !"
}
