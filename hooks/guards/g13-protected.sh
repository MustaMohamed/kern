# shellcheck shell=bash
# G13 protected targets: the hosts in protected_targets are read-only, so G13 proves a read and
# denies, in both modes, any call to a target it cannot prove reads. A missed write is the costly
# failure; a read G13 cannot prove is denied, and the user runs it by hand with `!`.
# An ssh to a target must run a remote command whose every segment (after `cmd /c` and
# `powershell -Command`) is on a closed read list, with no redirect except to /dev/null, nul or an
# fd copy, and no input on stdin; `ssh -N` tunnels and `ssh -O` control commands are exempt.
# Targets match the host in any case, as user@host or in a URL; an entry may be host:port.
# Out of scope (accepted limits): scripts and programs that connect on their own (an extractor, a
# Perl or Python client), an ssh config alias not listed itself, and names built at run time
# (variables, ANSI-C quoting).

guard_g13() {
  [ "$TOOL" = Bash ] || return 0
  local cmd flat list rec fed
  cmd=$(ti_get command) || return 0
  case "$cmd" in *'\u'*) cmd=$(_g13_unescape "$cmd") ;; esac
  # Cheap prefilter before settings_get: some client or transfer name, quotes and backslashes removed.
  flat=${cmd//[\"\'\\]/}
  _g13_names "$flat" || return 0
  list=$(settings_get protected_targets '')
  [ -n "$list" ] || return 0
  while IFS= read -r rec; do
    if _g13_names "${rec//[\"\'\\]/}"; then
      fed=0
      _g13_fed "$cmd" "$rec" && fed=1
      _g13_judge "$rec" "$list" "$fed" "$cmd"
    fi
  done <<EOT
$(git_words "$cmd")
EOT
  _g13_legacy "$cmd" "$list"
}

# _g13_names TEXT: exit 0 when TEXT holds a client or transfer name G13 reads, in any case.
_g13_names() {
  case "$1" in
    *[Ss][Ss][Hh]* | *[Ss][Cc][Pp]* | *[Ss][Ff][Tt][Pp]* | *[Rr][Ss][Yy][Nn][Cc]* | *[Mm][Yy][Ss][Qq][Ll]* | \
      *[Mm][Aa][Rr][Ii][Aa][Dd][Bb]* | *[Pp][Ss][Qq][Ll]* | *[Ss][Qq][Ll][Ii][Tt][Ee]* | *[Ss][Qq][Ll][Cc][Mm][Dd]* | \
      *[Pp][Gg]_*) return 0 ;;
  esac
  return 1
}

# _g13_unescape CMD: CMD with the JSON escapes \u0000 to \u007f decoded (ti_get leaves \uXXXX as is).
_g13_unescape() {
  printf '%s' "$1" | LC_ALL=C awk '
    BEGIN { for (i = 0; i < 128; i++) hex[sprintf("%04x", i)] = sprintf("%c", i) }
    { buf = buf (NR > 1 ? "\n" : "") $0 }
    END {
      out = ""
      while (match(buf, /\\u00[0-7][0-9a-fA-F]/)) {
        out = out substr(buf, 1, RSTART - 1) hex[tolower(substr(buf, RSTART + 2, 4))]
        buf = substr(buf, RSTART + RLENGTH)
      }
      printf "%s", out buf
    }'
}

# _g13_fed CMD REC: exit 0 when REC follows a pipe at any place it appears in CMD, or cannot be
# found there (a record git_words rebuilt), so its stdin may be fed.
_g13_fed() {
  local rest="$1" r="${2//$_GW_NL/$'\n'}" pre
  case "$rest" in *"$r"*) ;; *) return 0 ;; esac
  while :; do
    case "$rest" in *"$r"*) ;; *) return 1 ;; esac
    pre=${rest%%"$r"*}
    while :; do
      case "$pre" in *[[:space:]] | *'(' | *'{' | *'!') pre=${pre%?} ;; *) break ;; esac
    done
    case "$pre" in *'||') ;; *'|' | *'|&') return 0 ;; esac
    rest=${rest#*"$r"}
  done
}

# _g13_judge REC LIST FED CMD: denies for each client in the simple command REC that reaches a target
# in LIST without a proven read. FED is 1 when REC's stdin may come from a pipe; CMD is the whole
# command (for PGHOST=, MYSQL_HOST= and the like set before the client).
_g13_judge() {
  local why out
  # shellcheck disable=SC2153 # _GW_AWK is set in gitctx.sh
  if ! out=$(printf '%s' "$1" | G13_TG="$2" G13_FED="$3" G13_CMD="$4" LC_ALL=C awk -v sq="'" "$_GW_AWK$_G13_AWK$_G13_SQL_AWK" 2>&1); then
    vote deny G13 "the protected_targets check failed: ${out%%$'\n'*}"
    return 0
  fi
  while IFS= read -r why; do
    [ -n "$why" ] && vote deny G13 "$why"
  done <<EOT
$out
EOT
}

# The judge, run on one simple command with _GW_AWK's functions. qw(STR) splits like sw and marks in
# qw_r[k] a word that is an unquoted redirection (a quoted '>' is an argument). Every word whose
# basename, lowercased and without .exe, is a client is judged from there on (a wrapper G13 does not
# know, such as caffeinate or sshpass, hides nothing); _cmd_words' head is judged too when no word
# matched (env -S). Each reason prints once.
# shellcheck disable=SC2016 # awk text
_G13_AWK='
  function qw(buf,   n, q, w, have, i, c, rd, quo, nx) {
    qw_n = 0; n = length(buf); q = ""; w = ""; have = 0; rd = 0; quo = 0; dy = 0
    for (i = 1; i <= n; i++) {
      c = substr(buf, i, 1)
      if (q == sq) { if (c == sq) q = ""; else w = w c; continue }
      if (q == "\"") {
        if (c == "\"") q = ""
        else if (c == "\\" && index("\"\\$`", substr(buf, i + 1, 1))) { i++; w = w substr(buf, i, 1) }
        else { w = w c; if (c == "$" || c == "`") dy = 1 }
        continue
      }
      if (c == "\\") { i++; w = w substr(buf, i, 1); have = 1; quo = 1; continue }
      if (c == sq || c == "\"") { q = c; have = 1; quo = 1; continue }
      if (c == " " || c == "\t" || c == "\n" || c == "\037") {
        if (have) { qw_w[++qw_n] = w; qw_r[qw_n] = rd; qw_d[qw_n] = dy }
        w = ""; have = 0; rd = 0; quo = 0; dy = 0; continue
      }
      if (c == "#" && !have) { while (i < n && index("\n\037", substr(buf, i + 1, 1)) == 0) i++; continue }
      nx = substr(buf, i + 1, 1)
      if (c == "<" || c == ">" || (c == "&" && nx == ">")) {
        if (have && w !~ /^[0-9]+$/ && w !~ /[<>&]$/) { qw_w[++qw_n] = w; qw_r[qw_n] = rd; qw_d[qw_n] = dy; w = ""; quo = 0; rd = 0; dy = 0 }
        if (!quo && w ~ /^[0-9]*$/) rd = 1
      }
      if (c == "$" || c == "`") dy = 1
      w = w c; have = 1
    }
    if (have) { qw_w[++qw_n] = w; qw_r[qw_n] = rd; qw_d[qw_n] = dy }
  }
  function base(w) { sub(/.*[\/\\]/, "", w); w = tolower(w); sub(/\.exe$/, "", w); return w }
  function canon(h) { h = tolower(h); sub(/\.$/, "", h); gsub(/^\[|\]$/, "", h); if (h == "127.0.0.1" || h == "::1") h = "localhost"; return h }
  # hit(H, P): the target that host H on port P names, else 0.
  function hit(h, p,   k) {
    h = canon(h)
    if (h == "") return 0
    for (k = 1; k <= tn; k++) if (th[k] == h && (tp[k] == "" || tp[k] == p)) return k
    return 0
  }
  # bnd(S, T, P): S holds the host T, not inside a longer name, followed by :P or ,P when P is set.
  function bnd(s, t, p,   i, a, l) {
    l = length(t)
    while ((i = index(s, t)) > 0) {
      a = substr(s, i + l, 1)
      if ((i == 1 || substr(s, i - 1, 1) !~ /[a-z0-9._-]/) && a !~ /[a-z0-9._-]/) {
        if (p == "") return 1
        if ((a == ":" || a == ",") && substr(s, i + l + 1, length(p)) == p && substr(s, i + l + 1 + length(p), 1) !~ /[0-9]/) return 1
      }
      s = substr(s, i + 1)
    }
    return 0
  }
  # named(S): the target S names anywhere as a whole host (an option value), else 0.
  function named(s,   k) {
    s = tolower(s)
    for (k = 1; k <= tn; k++) {
      if (th[k] == "") continue
      if (bnd(s, th[k], tp[k])) return k
      if (th[k] == "localhost" && (bnd(s, "127.0.0.1", tp[k]) || bnd(s, "::1", tp[k]))) return k
    }
    return 0
  }
  # uhost(W): sets UH and UP from [scheme://][user@]host[:port] (UP empty when absent).
  function uhost(w) {
    UP = ""
    sub(/^[A-Za-z][A-Za-z0-9+.-]*:\/\//, "", w); sub(/\/.*/, "", w); sub(/.*@/, "", w)
    if (match(w, /:[0-9]*$/)) { UP = substr(w, RSTART + 1); w = substr(w, 1, RSTART - 1) }
    UH = w
  }
  function unq(s) { gsub(/"/, "", s); gsub(sq, "", s); return s }
  # deny(S): prints the reason S once, with the way out.
  function deny(s) { s = s "; run it yourself with ! if it only reads"; if (!(s in said)) { said[s] = 1; print s } }
  function join(a, i, n,   s) { s = ""; for (; i <= n; i++) s = s (s == "" ? "" : " ") a[i]; return s }
  # redir(K): W[K] is an unquoted redirection: sets RO (operator, fd number dropped) and RT (target);
  # returns the index of the last word it takes.
  function redir(k,   w) {
    w = W[k]
    match(w, /^[0-9]*(&>>|&>|<<<|<<-|<<|<>|<&|>&|>>|>\||<|>)/)
    RO = substr(w, RSTART, RLENGTH); sub(/^[0-9]*/, "", RO)
    RT = substr(w, RLENGTH + 1)
    if (RT == "" && k < N) { RT = W[k + 1]; return k + 1 }
    return k
  }

  # rem(S, D): "" when the remote command S only reads, else what is not proven. Quotes are not
  # trusted to protect a separator or a redirect: the remote shell may be cmd, which has no quotes.
  function rem(s, d,   n, segs, i, why) {
    if (d > 4) return "wrappers nest too deep"
    why = rredir(s)
    if (why != "") return why
    n = split(RS_OUT, segs, /[;&|\n\037(){}`]/)
    for (i = 1; i <= n; i++) if ((why = rseg(segs[i], d)) != "") return why
    return ""
  }
  # rredir(S): "" when every redirect in S goes to /dev/null, nul, $null or is an fd copy; sets RS_OUT
  # to S without them.
  function rredir(s,   out, op, t, why) {
    out = ""; why = ""
    while (match(s, /(&>>?|[0-9*]*(>>|>&|>\||<<<|<<-|<<|<>|<&|>|<))[ \t]*/)) {
      op = substr(s, RSTART, RLENGTH); out = out substr(s, 1, RSTART - 1) " "
      s = substr(s, RSTART + RLENGTH)
      match(s, /^[^ \t;&|<>(){}\n\037]*/); t = substr(s, 1, RLENGTH); s = substr(s, RLENGTH + 1)
      gsub(/[ \t]/, "", op); t = unq(t)
      if (op ~ /&$/ && t ~ /^([0-9]+|-)$/) continue
      if (op ~ />/ && op !~ /</ && tolower(t) ~ /^(\/dev\/null|nul|\$null)$/) continue
      if (why == "") why = "redirect " op t
    }
    RS_OUT = out s
    return why
  }
  # rseg(SEG, D): one segment of a remote command: its head must be on the read list.
  function rseg(seg, d,   n, a, h, i, w) {
    gsub(/^[ \t]+|[ \t]+$/, "", seg)
    if (seg == "") return ""
    n = split(seg, a, /[ \t]+/)
    h = base(unq(a[1]))
    if (h == "cmd") return rcmd(a, n, d)
    if (h == "powershell" || h == "pwsh") return rps(a, n, h, d)
    if (!(h in READ)) return "`" h "` is not on the read list"
    for (i = 2; i <= n; i++) {
      w = unq(a[i])
      if (h == "find" && tolower(w) ~ /^-(delete|exec|execdir|ok|okdir|fprint|fprint0|fprintf|fls)$/) return "`find " w "` writes or runs a command"
      if (h == "date" && (w ~ /^-[A-Za-z]*s/ || w ~ /^--set/ || w ~ /^[0-9]/)) return "`date " w "` may set the clock"
      if (h == "hostname" && w !~ /^-([sfiIdaAvhV]|-short|-fqdn|-long|-ip-address|-all-ip-addresses|-domain|-alias|-all-fqdns|-help|-version)$/) return "`hostname " w "` may set the host name"
      if (h == "file" && w ~ /^(-[A-Za-z]*C|--compile)/) return "`file " w "` writes a magic file"
    }
    return ""
  }
  # rcmd: cmd [/x ...] /c|/k COMMAND; any other cmd is a shell.
  function rcmd(a, n, d,   i, w, rest) {
    for (i = 2; i <= n; i++) {
      w = unq(a[i])
      if (tolower(w) ~ /^\/[ck]/) {
        rest = substr(a[i], index(a[i], "/") + 2) " " join(a, i + 1, n)
        if (unq(rest) ~ /^[ \t]*$/) break
        return rem(rest, d + 1)
      }
      if (w !~ /^\/[A-Za-z](:.*)?$/) break
    }
    return "`cmd` without /c is a shell"
  }
  # rps: powershell or pwsh [options] -Command COMMAND (Windows PowerShell also takes COMMAND bare).
  function rps(a, n, h, d,   i, w, p, rest) {
    for (i = 2; i <= n; i++) {
      w = tolower(unq(a[i]))
      if (w !~ /^[-\/]/) {
        if (h == "powershell") return rem(join(a, i, n), d + 1)
        return "`pwsh` runs a script file"
      }
      p = substr(w, 2)
      if (p ~ /^(c|com|comm|comma|comman|command|commandwithargs|cwa)$/) {
        rest = join(a, i + 1, n); w = unq(rest); gsub(/[ \t]/, "", w)
        if (w == "" || w == "-") return "`" h "` reads its command from stdin"
        return rem(rest, d + 1)
      }
      if (p ~ /^(nop|noprofile|noni|noninteractive|nol|nologo|sta|mta|noe|noexit)$/) continue
      if (p ~ /^(ex|ep|executionpolicy|w|win|windowstyle|if|inp|inputformat|o|of|outputformat|v|version|config|configurationname|wd|workingdirectory|settingsfile)$/) { i++; continue }
      return "`" h " -" p "` cannot be checked"
    }
    return "`" h "` with no command is a shell"
  }

  # j_ssh(S): ssh at word S. OpenSSH reads options before and after the destination; the first word
  # after that starts the remote command.
  function j_ssh(s,   k, w, j, c, v, dest, port, nf, nin, ctl, inc, rc, orc, stdin, t, key, h, why, lc, lt, dyn) {
    port = 22; dest = ""; rc = ""; orc = ""; nf = 0; nin = 0; ctl = 0; inc = 0; stdin = ""; t = 0; lc = ""; lt = 0; OH = ""; dyn = 0
    for (k = s + 1; k <= N; k++) {
      w = W[k]
      if (R[k]) {
        k = redir(k)
        if (RO ~ /^</ && !(RO == "<" && RT == "/dev/null")) stdin = RO
        continue
      }
      if (inc) { rc = rc " " w; dyn = dyn || D[k]; continue }
      if (w ~ /^-./ && w != "--") {
        for (j = 2; j <= length(w); j++) {
          c = substr(w, j, 1)
          if (index("BbcDEeFIiJLlmOoPpQRSWw", c)) {
            v = substr(w, j + 1)
            if (v == "" && k < N) v = W[++k]
            if (c == "p") port = v
            else if (c == "J" && !t) t = hops(v)
            else if (c == "O" || c == "W") ctl = 1
            else if (c == "o") {
              key = tolower(v); sub(/[ =].*/, "", key); sub(/^[^ =]*[ =][ \t]*/, "", v)
              if (key == "port") port = v
              else if (key == "hostname") OH = v
              else if (key == "remotecommand") { orc = v; dyn = dyn || D[k] }
              else if (key == "proxyjump" && !t) t = hops(v)
              else if (key ~ /^(proxycommand|localcommand|knownhostscommand)$/ && (lt = named(v))) lc = key
              else if (!t) t = named(v)
            }
            break
          }
          if (c == "N") nf = 1
          else if (c == "n") nin = 1
          else if (c == "G" || c == "V") ctl = 2
        }
        continue
      }
      if (w == "--") continue
      if (dest == "") { dest = w; continue }
      inc = 1; rc = w; dyn = D[k]
    }
    if (ctl == 2 || dest == "") return
    uhost(dest)
    if (!t) t = hit(UH, UP != "" ? UP : port)
    if (!t && OH != "") t = hit(OH, UP != "" ? UP : port)
    if (lc != "") { deny("ssh -o " lc " runs a command that names protected target " tr[lt] "; kern cannot check it"); return }
    if (!t) return
    h = tr[t]
    if (rc == "" && orc == "") {
      if (nf || ctl) return
      deny("ssh to protected target " h " with no remote command opens a shell")
      return
    }
    if (!nin && stdin != "") deny("ssh to protected target " h " with input on stdin (" stdin ")")
    else if (!nin && FED) deny("ssh to protected target " h " with input piped to it")
    if (dyn) deny("ssh to protected target " h ": the remote command is built at run time ($ or a backtick)")
    if (rc != "" && (why = rem(rc, 0)) != "") deny("ssh to protected target " h ": " why)
    if (orc != "" && (why = rem(orc, 0)) != "") deny("ssh -o RemoteCommand to protected target " h ": " why)
  }
  # hops(V): the target a comma list of jump hosts names, else 0.
  function hops(v,   n, a, i, t) {
    n = split(v, a, ",")
    for (i = 1; i <= n; i++) { uhost(a[i]); if ((t = hit(UH, UP != "" ? UP : 22))) return t }
    return 0
  }

  function judge(b, k) {
    if (b == "ssh") j_ssh(k)
    else if (b in SQLFAM) j_sql(k, b)
  }

  BEGIN {
    FED = ENVIRON["G13_FED"] == 1
    nt = split(ENVIRON["G13_TG"], ta, ",")
    for (k = 1; k <= nt; k++) {
      e = ta[k]; gsub(/^[ \t\[]+|[ \t\]]+$/, "", e)
      if (e == "") continue
      tr[++tn] = e
      uhost(e); th[tn] = canon(UH); tp[tn] = UP
    }
    nr = split("ls cat head tail grep wc stat file du df pwd whoami hostname uname date id echo sha256sum md5sum find " \
      "dir type findstr where ver get-childitem get-content select-string get-item test-path get-filehash measure-object " \
      "gci gc sls", ra, " ")
    for (k = 1; k <= nr; k++) READ[ra[k]] = 1
    JUDGE["ssh"] = 1
    CMDTXT = ENVIRON["G13_CMD"]
  }
  { buf = buf (NR > 1 ? "\037" : "") $0 }
  END {
    qw(buf); N = qw_n
    for (k = 1; k <= N; k++) { W[k] = qw_w[k]; R[k] = qw_r[k]; D[k] = qw_d[k] }
    found = 0
    for (k = 1; k <= N; k++) if (!R[k] && ((b = base(W[k])) in JUDGE)) { found = 1; judge(b, k) }
    if (found) exit
    cw_reset()
    for (k = 1; k <= N; k++) cw(W[k])
    if (!cw_n || !((b = base(cw_w[1])) in JUDGE)) exit
    N = cw_n
    for (k = 1; k <= N; k++) { W[k] = cw_w[k]; R[k] = (k > 1 && W[k] ~ /^[0-9]*(<|>|&>)/); D[k] = (W[k] ~ /[$`]/) }
    judge(b, 1)
  }
'

# The SQL judge, appended to _G13_AWK. A client reaches a target when its host (-h, --host, a URL, a
# conninfo host=, PGHOST= or MYSQL_HOST= in the command, else localhost) and its port (likewise, else
# the client default) name one, or an option value names one as a whole host; sqlite3 when its file
# is one. Then every statement in -e, -c, -Q, --init-command and every input file (-f, -i, <) is
# proven: it starts with SELECT, SHOW, DESCRIBE, DESC, EXPLAIN or WITH and holds no write, lock,
# file or wait word, for every way the client may lex its strings. Piped, here-doc or run-time input,
# a file G13 cannot read, and no statement at all are denied.
# shellcheck disable=SC2016 # awk text
_G13_SQL_AWK='
  function j_sql(s, b,   fam, k, w, j, c, v, x, opt, pos, t, i, h, why, role) {
    fam = SQLFAM[b]
    nh = 0; np = 0; nst = 0; bad = ""; stdin = ""; dyn = 0; single = 0; locks = ""; pos = 0; dbf = ""; FBT = 0; vars = ""
    for (k = s + 1; k <= N; k++) {
      w = W[k]
      if (R[k]) {
        k = redir(k)
        if (RO == "<") sqlfile(RT)
        else if (RO ~ /^</) stdin = RO
        continue
      }
      if (fam == "lite" && w ~ /^-/) {
        opt = w; sub(/^--/, "-", opt)
        if ((opt in LITEV) && k < N) {
          v = W[++k]
          if (opt == "-cmd") sqlst(v, D[k])
          else if (opt == "-init") sqlfile(v)
        }
        continue
      }
      if (w ~ /^--./) {
        opt = w; v = ""; x = 0
        if ((j = index(w, "=")) > 0) { opt = substr(w, 1, j - 1); v = substr(w, j + 1); x = 1 }
        role = ((b SUBSEP opt) in LONG) ? LONG[b, opt] : LONG[fam, opt]
        if (role != "") {
          if (!x && k < N) v = W[++k]
          sqlopt(role, v, D[k], fam)
        } else {
          if (x) fb(v)
          if (b ~ /dump$/) dumpopt(opt, v, x)
        }
        continue
      }
      if (w ~ /^-./) {
        if (fam == "ms") {
          c = substr(w, 2, 1)
          if (index(SQLV[b], c)) { v = substr(w, 3); if (v == "" && k < N) v = W[++k]; sqlopt(ROLE[b, c], v, D[k], fam) }
          continue
        }
        for (j = 2; j <= length(w); j++) {
          c = substr(w, j, 1)
          if (index(SQLV[b], c)) {
            v = substr(w, j + 1)
            if (v == "" && k < N) v = W[++k]
            sqlopt(ROLE[b, c], v, D[k], fam)
            break
          }
          if (fam == "my" && index("p#", c)) break
          if (b ~ /dump$/ && index("lxF", c)) locks = locks " -" c
          if (b == "psql" && c == "l") ST[++nst] = "\\l"
        }
        continue
      }
      if (fam == "lite") { if (++pos == 1) dbf = w; else sqlst(w, D[k]); continue }
      conn(w); fb(w)
    }
    if (fam == "lite") t = litehit(dbf, s)
    else {
      if (nh == 0) { envscan(fam, "h"); H[++nh] = "localhost" }
      if (np == 0) { envscan(fam, "p"); P[++np] = DEFPORT[fam] }
      t = 0
      for (i = 1; i <= nh && !t; i++) for (j = 1; j <= np && !t; j++) t = hit(H[i], P[j])
      if (!t) t = FBT
    }
    if (!t) return
    h = tr[t]
    if (b in SQLREAD) return
    if (b ~ /dump$/) {
      if (!single) deny(b " of protected target " h " without --single-transaction locks tables")
      if (locks != "") deny(b " of protected target " h " with" locks " takes a lock or writes")
      return
    }
    if (!(b in SQLRUN)) { deny(b " against protected target " h ": kern proves reads only for mysql, mariadb, psql, sqlite3, sqlcmd, mysqldump and pg_dump"); return }
    if (FED) deny("SQL to protected target " h " with input piped to " b)
    if (stdin != "") deny("SQL to protected target " h " with input from " stdin)
    if (bad != "") deny("SQL to protected target " h ": cannot read " bad)
    if (dyn) deny("SQL to protected target " h " built at run time ($ or a backtick)")
    if (nst == 0) { deny("SQL to protected target " h " with no statement opens an interactive " b); return }
    for (i = 1; i <= nst; i++) if ((why = sqlok(ST[i], fam)) != "") { deny("SQL to protected target " h ": " why); break }
    if (vars != "" && (index(vars, ";") || (why = sqlkw(sqlstrip(vars, fam, 1), fam, "")) != "")) deny("SQL to protected target " h ": a psql variable holds SQL")
  }
  # sqlopt(ROLE, V, DYN, FAM): h host, P port, S sqlcmd server, e statement, f file, d database or
  # conninfo, v psql variable; anything else may still name a target.
  function sqlopt(role, v, dy, fam,   n, a, i) {
    if (role == "h") { n = split(v, a, ","); for (i = 1; i <= n; i++) H[++nh] = a[i] }
    else if (role == "P") { n = split(v, a, ","); for (i = 1; i <= n; i++) P[++np] = a[i] }
    else if (role == "S") sqlserver(v)
    else if (role == "e") sqlst(v, dy)
    else if (role == "f") { n = split(v, a, fam == "ms" ? "," : "\001"); for (i = 1; i <= n; i++) sqlfile(a[i]) }
    else if (role == "d") { conn(v); fb(v) }
    else if (role == "v") { sub(/^[^=]*=/, "", v); vars = vars " " v }
    else fb(v)
  }
  # sqlserver(V): sqlcmd [tcp:]host[\instance][,port].
  function sqlserver(v) {
    sub(/^[A-Za-z]+:/, "", v)
    if (match(v, /,[0-9]+$/)) { P[++np] = substr(v, RSTART + 1); v = substr(v, 1, RSTART - 1) }
    sub(/\\.*/, "", v)
    H[++nh] = v
  }
  function sqlst(v, dy) { ST[++nst] = v; if (dy) dyn = 1 }
  function sqlfile(f,   t) {
    if (f ~ /^(-|\/dev\/stdin|\/dev\/fd\/0|\/proc\/self\/fd\/0)$/) { stdin = "stdin"; return }
    t = slurp(f)
    if (SLURP_OK) ST[++nst] = t
    else if (bad == "") bad = f
  }
  function slurp(f,   line, t, r) {
    if (f ~ /^~\//) f = ENVIRON["HOME"] substr(f, 2)
    else if (f !~ /^\//) f = ENVIRON["CWD"] "/" f
    t = ""; SLURP_OK = 0
    while ((r = (getline line < f)) > 0) t = t line "\n"
    if (r < 0) return ""
    close(f); SLURP_OK = 1
    return t
  }
  # conn(W): hosts and ports from a URL or a conninfo string.
  function conn(w,   hp, n, a, i, k, kv) {
    if (w ~ /^[A-Za-z][A-Za-z0-9+.-]*:\/\//) {
      hp = w; sub(/^[^:]*:\/\//, "", hp); sub(/[\/?].*/, "", hp); sub(/.*@/, "", hp)
      n = split(hp, a, ",")
      for (i = 1; i <= n; i++) { uhost(a[i]); if (UH != "") H[++nh] = UH; if (UP != "") P[++np] = UP }
      hp = w; sub(/^[^?]*\??/, "", hp); gsub(/&/, " ", hp); w = hp
    }
    n = split(w, a, /[ \t]+/)
    for (i = 1; i <= n; i++) {
      if (!(k = index(a[i], "="))) continue
      kv = tolower(substr(a[i], 1, k - 1))
      if (kv == "host" || kv == "hostaddr") sqlopt("h", substr(a[i], k + 1))
      else if (kv == "port") sqlopt("P", substr(a[i], k + 1))
    }
  }
  # fb(V): remembers the first target V names as a whole host.
  function fb(v) { if (!FBT) FBT = named(v) }
  # envscan(FAM, KIND): hosts or ports assigned anywhere in the command (PGHOST=x psql, export ...).
  function envscan(fam, kind,   names, n, a, i, s, v) {
    names = ENVN[fam, kind]
    n = split(names, a, " ")
    for (i = 1; i <= n; i++) {
      s = CMDTXT
      while (match(s, "(^|[^A-Za-z0-9_])" a[i] "=[^ \t;&|)]*")) {
        v = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
        sub(/^[^=]*=/, "", v); v = unq(v)
        if (kind == "p") P[++np] = v
        else if (a[i] == "SQLCMDSERVER") sqlserver(v)
        else H[++nh] = v
      }
    }
  }
  # litehit(F, S): the target the sqlite3 file F is, or a path target any later word holds.
  function litehit(f, s,   k, e, lf, i) {
    lf = lpath(f)
    for (k = 1; k <= tn; k++) {
      e = tolower(tr[k])
      if (index(e, "/")) { if (f != "" && lf == lpath(e)) return k; for (i = s + 1; i <= N; i++) if (index(tolower(W[i]), e)) return k }
      else if (f != "" && (tolower(f) == e || substr(lf, length(lf) - length(e)) == "/" e)) return k
    }
    return 0
  }
  function lpath(p) {
    if (p ~ /^~\//) p = ENVIRON["HOME"] substr(p, 2)
    else if (p !~ /^\//) p = ENVIRON["CWD"] "/" p
    return tolower(p)
  }
  function dumpopt(opt, v, x,   off) {
    off = x && tolower(v) ~ /^(0|off|false)$/
    if (opt == "--single-transaction") single = !off
    else if (opt ~ /^--(skip|disable)-single-transaction$/) single = 0
    else if (!off && opt ~ /^--(lock-tables|lock-all-tables|master-data|source-data|flush-logs|flush-privileges|delete-master-logs|delete-source-logs|dump-slave|dump-replica|lock-for-backup)$/) locks = locks " " opt
  }

  # sqlok(TEXT, FAM): "" when every statement in TEXT reads, under each way FAM may lex strings
  # (mysql: backslash escapes on or off; psql: in E strings only, or everywhere).
  function sqlok(text, fam,   n, a, i, why) {
    n = split(LEX[fam], a, " ")
    for (i = 1; i <= n; i++) if ((why = sqlvar(text, fam, a[i])) != "") return why
    return ""
  }
  function sqlvar(text, fam, bs,   s, c, e, rest, n, a, i, why, line, out) {
    gsub(/\037/, "\n", text)
    s = sqlstrip(text, fam, bs)
    if (fam == "my") {
      while (match(s, /\\./)) {
        c = substr(s, RSTART + 1, 1)
        if (c != "g" && c != "G") return "mysql client command \\" c
        s = substr(s, 1, RSTART - 1) ";" substr(s, RSTART + 2)
      }
    } else if (fam == "pg") {
      while (match(s, /\\[^ \t\n;]*/)) {
        c = substr(s, RSTART + 1, RLENGTH - 1); e = RSTART; rest = substr(s, RSTART)
        if (c !~ /^(d[A-Za-z+]*|l\+?|x|q|g|gx|conninfo|timing)$/) return "psql meta-command \\" c
        s = substr(s, 1, e - 1) ";" (match(rest, /\n/) ? substr(rest, RSTART) : "")
      }
    } else {
      n = split(s, a, "\n"); out = ""
      for (i = 1; i <= n; i++) {
        line = a[i]
        if (fam == "lite" && line ~ /^[ \t]*\./) {
          c = line; sub(/^[ \t]*\./, "", c); sub(/[ \t].*/, "", c)
          if (!(tolower(c) in LITEDOT)) return "sqlite3 dot command ." c
          line = ";"
        }
        if (fam == "ms") {
          if (tolower(line) ~ /^[ \t]*go([ \t]+[0-9]+)?[ \t]*$/) line = ";"
          else if (line ~ /^[ \t]*(:|!!)/) return "sqlcmd command " line
          else if (index(line, "$(")) return "sqlcmd variable in " line
        }
        out = out line "\n"
      }
      s = out
    }
    n = split(s, a, ";")
    for (i = 1; i <= n; i++) if ((why = sqlstmt(a[i], fam)) != "") return why
    return ""
  }
  # sqlstrip(S, FAM, BS): S with comments removed and strings and quoted names replaced by an empty
  # string; a MySQL /*! or /*M! comment is code. BS 1: a backslash escapes in every string; e: only
  # in an E string; 0: never. psql also has dollar quotes; only mysql has # comments and backticks.
  function sqlstrip(s, fam, bs,   n, i, c, nx, out, j, q, esc, e, tag) {
    n = length(s); out = ""
    for (i = 1; i <= n; i++) {
      c = substr(s, i, 1); nx = substr(s, i + 1, 1)
      if ((c == "-" && nx == "-" && index(" \t\n", substr(s, i + 2, 1))) || (c == "#" && fam == "my")) {
        while (i < n && substr(s, i + 1, 1) != "\n") i++
        out = out " "; continue
      }
      if (c == "/" && nx == "*") {
        if (substr(s, i + 2, 1) == "!" || substr(s, i + 2, 2) == "M!") {
          i += (substr(s, i + 2, 1) == "!") ? 2 : 3
          while (substr(s, i + 1, 1) ~ /[0-9]/) i++
          out = out " "; continue
        }
        e = index(substr(s, i + 2), "*/")
        if (!e) break
        i += e + 2; out = out " "; continue
      }
      if (c == "*" && nx == "/") { i++; out = out " "; continue }
      if (c == sq || c == "\"" || (c == "`" && fam == "my")) {
        esc = (bs == 1) || (bs == "e" && c == sq && i > 1 && substr(s, i - 1, 1) ~ /[eE]/ && (i == 2 || substr(s, i - 2, 1) !~ /[A-Za-z0-9_]/))
        for (j = i + 1; j <= n; j++) {
          q = substr(s, j, 1)
          if (esc && q == "\\") { j++; continue }
          if (q == c) { if (substr(s, j + 1, 1) == c) { j++; continue }; break }
        }
        out = out " "; i = j; continue
      }
      if (c == "$" && fam == "pg" && (i == 1 || substr(s, i - 1, 1) !~ /[A-Za-z0-9_$]/) && match(substr(s, i), /^\$([A-Za-z_][A-Za-z0-9_]*)?\$/)) {
        tag = substr(s, i, RLENGTH)
        e = index(substr(s, i + RLENGTH), tag)
        if (!e) { out = out " "; break }
        i += RLENGTH + e + length(tag) - 2; out = out " "; continue
      }
      out = out c
    }
    return out
  }
  # sqlstmt(ST, FAM): one statement starts with a read word and holds no write, lock, file or wait word.
  function sqlstmt(st, fam,   rest, n, tk, x, i, w) {
    rest = tolower(st); n = 0
    while (match(rest, /[a-z_][a-z0-9_$]*/)) { tk[++n] = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH) }
    x = tolower(st); gsub(/^[ \t\n(]+/, "", x)
    if (x == "") return ""
    if (!n || !(tk[1] in SQLHEAD) || index(x, tk[1]) != 1) { x = substr(x, 1, 24); gsub(/[\n\t]/, " ", x); return "statement `" x "` is not a read" }
    return sqlkw(st, fam, tk[1])
  }
  # sqlkw(S, FAM, HEAD): "" unless S holds a write, lock, file or wait word.
  function sqlkw(s, fam, head,   rest, w, p) {
    rest = tolower(s); p = ""
    while (match(rest, /[a-z_][a-z0-9_$]*/)) {
      w = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
      if (head == "show" && (w == "create" || w == "set")) { p = w; continue }
      if ((w in SQLANY) || (fam == "ms" && (w in MSANY)) || w ~ /^(pg_advisory_|pg_try_advisory_|pg_stat_reset|pg_replication_origin_)/) return "`" w "` writes, locks or waits"
      if (w == "share" && (p == "for" || p == "key")) return "`" p " share` locks rows"
      p = w
    }
    return ""
  }
  BEGIN {
    n = split("mysql mariadb mysqldump mariadb-dump mysqladmin mariadb-admin mysqlimport mariadb-import mysqlcheck " \
      "mariadb-check mysqlshow mariadb-show mysqlpump mysqlslap mariadb-slap mysqlbinlog mariadb-binlog mysql_upgrade " \
      "mariadb-upgrade mysqlsh", a, " ")
    for (i = 1; i <= n; i++) { SQLFAM[a[i]] = "my"; SQLV[a[i]] = "hPSu"; ROLE[a[i], "h"] = "h"; ROLE[a[i], "P"] = "P" }
    SQLV["mysql"] = SQLV["mariadb"] = "DehPSu"; ROLE["mysql", "e"] = ROLE["mariadb", "e"] = "e"
    SQLV["mysqldump"] = SQLV["mariadb-dump"] = "hPSurwT"
    n = split("psql pg_dump pg_dumpall pg_restore pg_isready", a, " ")
    for (i = 1; i <= n; i++) { SQLFAM[a[i]] = "pg"; ROLE[a[i], "h"] = "h"; ROLE[a[i], "p"] = "P"; ROLE[a[i], "d"] = "d" }
    SQLV["psql"] = "cdfhpUvoLPFRT"; ROLE["psql", "c"] = "e"; ROLE["psql", "f"] = "f"; ROLE["psql", "v"] = "v"
    SQLV["pg_dump"] = "dfFhjnNpSTtUZe"; SQLV["pg_dumpall"] = "dfhlpSU"; SQLV["pg_restore"] = "dfFhIjLnNpPSTtUe"; SQLV["pg_isready"] = "dhptU"
    SQLFAM["sqlite3"] = SQLFAM["sqlite"] = "lite"
    SQLFAM["sqlcmd"] = "ms"; SQLV["sqlcmd"] = "SUPdQqiovHltswacfkyYmLAGeh"
    ROLE["sqlcmd", "S"] = "S"; ROLE["sqlcmd", "Q"] = ROLE["sqlcmd", "q"] = "e"; ROLE["sqlcmd", "i"] = "f"
    n = split("my pg ms", a, " ")
    for (i = 1; i <= n; i++) { LONG[a[i], "--host"] = "h"; LONG[a[i], "--port"] = "P" }
    LONG["mysql", "--execute"] = LONG["mariadb", "--execute"] = "e"
    LONG["mysql", "--init-command"] = LONG["mariadb", "--init-command"] = "e"
    LONG["mysql", "--init-command-add"] = LONG["mariadb", "--init-command-add"] = "e"
    LONG["pg", "--dbname"] = "d"; LONG["psql", "--command"] = "e"; LONG["psql", "--file"] = "f"
    LONG["psql", "--set"] = LONG["psql", "--variable"] = "v"
    LONG["ms", "--server"] = "S"; LONG["ms", "--query"] = "e"; LONG["ms", "--input-file"] = "f"
    n = split("-cmd -init -separator -newline -nullvalue -vfs -mmap -heap -maxsize -escape", a, " ")
    for (i = 1; i <= n; i++) LITEV[a[i]] = 1
    n = split("tables schema indexes indices databases headers mode dbinfo quit exit show help width fullschema", a, " ")
    for (i = 1; i <= n; i++) LITEDOT[a[i]] = 1
    DEFPORT["my"] = 3306; DEFPORT["pg"] = 5432; DEFPORT["ms"] = 1433
    ENVN["my", "h"] = "MYSQL_HOST"; ENVN["my", "p"] = "MYSQL_TCP_PORT"
    ENVN["pg", "h"] = "PGHOST PGHOSTADDR"; ENVN["pg", "p"] = "PGPORT"; ENVN["ms", "h"] = "SQLCMDSERVER"
    LEX["my"] = "1 0"; LEX["pg"] = "e 1"; LEX["lite"] = "0 1"; LEX["ms"] = "0 1"
    n = split("mysql mariadb psql sqlite3 sqlite sqlcmd", a, " ")
    for (i = 1; i <= n; i++) SQLRUN[a[i]] = 1
    n = split("pg_dump pg_dumpall pg_isready mysqlshow mariadb-show mysqlbinlog mariadb-binlog", a, " ")
    for (i = 1; i <= n; i++) SQLREAD[a[i]] = 1
    n = split("select show describe desc explain with", a, " ")
    for (i = 1; i <= n; i++) SQLHEAD[a[i]] = 1
    n = split("insert update delete merge drop create alter grant revoke lock unlock into outfile dumpfile " \
      "get_lock release_lock release_all_locks sleep benchmark pg_sleep pg_sleep_for pg_sleep_until " \
      "pg_terminate_backend pg_cancel_backend pg_reload_conf pg_rotate_logfile pg_switch_wal pg_switch_xlog " \
      "pg_promote pg_create_restore_point set_config setval nextval lo_import lo_export lo_unlink lo_create " \
      "lo_creat lo_put lo_from_bytea lo_truncate pg_file_write pg_file_unlink pg_file_rename pg_file_sync dblink " \
      "dblink_exec dblink_connect dblink_send_query query_to_xml query_to_xml_and_xmlschema query_to_xmlschema " \
      "pg_drop_replication_slot pg_create_physical_replication_slot pg_create_logical_replication_slot " \
      "pg_logical_emit_message pg_backup_start pg_backup_stop pg_start_backup pg_stop_backup " \
      "pg_import_system_collations pg_wal_replay_pause pg_wal_replay_resume sys_exec sys_eval master_pos_wait " \
      "source_pos_wait wait_for_executed_gtid_set wait_until_sql_thread_after_gtids", a, " ")
    for (i = 1; i <= n; i++) SQLANY[a[i]] = 1
    n = split("exec execute kill shutdown truncate backup restore dbcc waitfor reconfigure openrowset " \
      "opendatasource openquery bulk", a, " ")
    for (i = 1; i <= n; i++) MSANY[a[i]] = 1
    for (b in SQLFAM) JUDGE[b] = 1
  }
'

# _g13_legacy CMD LIST: scp, rsync and sftp toward a target.
_g13_legacy() {
  local cmd="$1" seg rest target
  rest="$2,"
  while [ -n "$rest" ]; do
    target=${rest%%,*}
    rest=${rest#*,}
    target=$(printf '%s' "$target" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    [ -n "$target" ] || continue
    case "$cmd" in *"$target"*) ;; *) continue ;; esac
    while IFS= read -r seg; do
      _g13_segment "$seg" "$target"
    done <<EOT
$(git_words "$cmd")
EOT
  done
}

_g13_segment() {
  local seg="$1" target="$2" head last
  head=$(cmd_head "$seg")
  case "${head%% *}" in
    scp | rsync)
      last=$(_shell_words "$seg" | tail -n 1)
      case "$last" in *"$target"*) vote deny G13 "copy to protected target $target" ;; esac
      ;;
    sftp)
      printf '%s\n' "$seg" | grep -Eiq '(^|[^a-z])(put|rm|rename|mkdir|rmdir|chmod)[[:space:]]' &&
        vote deny G13 "sftp write to protected target $target"
      ;;
  esac
}
