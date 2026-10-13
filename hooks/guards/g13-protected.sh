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
      _g13_judge "$rec" "$list" "$fed"
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
      *[Pp][Gg]_[Dd][Uu][Mm][Pp]*) return 0 ;;
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

# _g13_judge REC LIST FED: denies for each client in the simple command REC that reaches a target in
# LIST without a proven read. FED is 1 when REC's stdin may come from a pipe.
_g13_judge() {
  local why
  # shellcheck disable=SC2153 # _GW_AWK is set in gitctx.sh
  while IFS= read -r why; do
    [ -n "$why" ] && vote deny G13 "$why"
  done <<EOT
$(printf '%s' "$1" | G13_TG="$2" G13_FED="$3" LC_ALL=C awk -v sq="'" "$_GW_AWK$_G13_AWK")
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
    qw_n = 0; n = length(buf); q = ""; w = ""; have = 0; rd = 0; quo = 0
    for (i = 1; i <= n; i++) {
      c = substr(buf, i, 1)
      if (q == sq) { if (c == sq) q = ""; else w = w c; continue }
      if (q == "\"") {
        if (c == "\"") q = ""
        else if (c == "\\" && index("\"\\$`", substr(buf, i + 1, 1))) { i++; w = w substr(buf, i, 1) }
        else w = w c
        continue
      }
      if (c == "\\") { i++; w = w substr(buf, i, 1); have = 1; quo = 1; continue }
      if (c == sq || c == "\"") { q = c; have = 1; quo = 1; continue }
      if (c == " " || c == "\t" || c == "\n" || c == "\037") {
        if (have) { qw_w[++qw_n] = w; qw_r[qw_n] = rd }
        w = ""; have = 0; rd = 0; quo = 0; continue
      }
      if (c == "#" && !have) { while (i < n && index("\n\037", substr(buf, i + 1, 1)) == 0) i++; continue }
      nx = substr(buf, i + 1, 1)
      if (c == "<" || c == ">" || (c == "&" && nx == ">")) {
        if (have && w !~ /^[0-9]+$/ && w !~ /[<>&]$/) { qw_w[++qw_n] = w; qw_r[qw_n] = rd; w = ""; quo = 0; rd = 0 }
        if (!quo && w ~ /^[0-9]*$/) rd = 1
      }
      w = w c; have = 1
    }
    if (have) { qw_w[++qw_n] = w; qw_r[qw_n] = rd }
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
  function j_ssh(s,   k, w, j, c, v, dest, port, nf, nin, ctl, inc, rc, orc, stdin, t, key, h, why, lc, lt) {
    port = 22; dest = ""; rc = ""; orc = ""; nf = 0; nin = 0; ctl = 0; inc = 0; stdin = ""; t = 0; lc = ""; lt = 0; OH = ""
    for (k = s + 1; k <= N; k++) {
      w = W[k]
      if (R[k]) {
        k = redir(k)
        if (RO ~ /^</ && !(RO == "<" && RT == "/dev/null")) stdin = RO
        continue
      }
      if (inc) { rc = rc " " w; continue }
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
              else if (key == "remotecommand") orc = v
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
      inc = 1; rc = w
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
  }
  { buf = buf (NR > 1 ? "\037" : "") $0 }
  END {
    qw(buf); N = qw_n
    for (k = 1; k <= N; k++) { W[k] = qw_w[k]; R[k] = qw_r[k] }
    found = 0
    for (k = 1; k <= N; k++) if (!R[k] && ((b = base(W[k])) in JUDGE)) { found = 1; judge(b, k) }
    if (found) exit
    cw_reset()
    for (k = 1; k <= N; k++) cw(W[k])
    if (!cw_n || !((b = base(cw_w[1])) in JUDGE)) exit
    N = cw_n
    for (k = 1; k <= N; k++) { W[k] = cw_w[k]; R[k] = (k > 1 && W[k] ~ /^[0-9]*(<|>|&>)/) }
    judge(b, 1)
  }
'

# _g13_legacy CMD LIST: scp, rsync and sftp toward a target, and mutating SQL.
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
    _g13_sql "$cmd" "$target"
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

# _g13_sql CMD TARGET: mutating SQL in the command, or in a file it feeds with -f, --file or <.
_g13_sql() {
  local cmd="$1" target="$2" text f
  text="$cmd"
  for f in $(printf '%s\n' "$cmd" | grep -Eo '(-f|--file=?|<)[[:space:]]*[^[:space:];|&]+\.sql' | sed -E 's/^(-f|--file=?|<)[[:space:]]*//'); do
    case "$f" in /*) ;; *) f="$CWD/$f" ;; esac
    [ -f "$f" ] && text="$text
$(cat "$f")"
  done
  printf '%s\n' "$text" | grep -Eiq '(^|[^a-z_])(insert[[:space:]]+into|update[[:space:]]+[a-z_."`]+[[:space:]]+set|delete[[:space:]]+from|drop[[:space:]]+(table|database|schema|index|view)|alter[[:space:]]+(table|database|schema)|truncate|create[[:space:]]+(table|database|schema|index)|grant[[:space:]]|revoke[[:space:]]|lock[[:space:]]+tables|set[[:space:]]+global|kill[[:space:]]+[0-9])' &&
    vote deny G13 "mutating SQL against protected target $target"
  return 0
}
