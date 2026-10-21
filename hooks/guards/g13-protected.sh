# shellcheck shell=bash
# G13 protected targets: the hosts in protected_targets are read-only, so G13 proves a read and
# denies, in both modes, any call to a target it cannot prove reads. A missed write is the costly
# failure; a read G13 cannot prove is denied, and the user runs it by hand with `!`.
# An ssh to a target must run a remote command whose every segment is on a closed read list (a cmd
# or powershell wrapper denies: G13 does not unwrap one), with no redirect except to /dev/null, nul
# or an fd copy, and no input on stdin; `ssh -N` tunnels and `ssh -O` control commands are exempt.
# SQL to a target must be proven statement by statement (_G13_SQL_AWK); a copy may only come from a
# target, and sftp may only run read verbs (_G13_XFER_AWK).
# Targets match the host in any case, as user@host or in a URL; an entry may be host:port.
# Out of scope (accepted limits): scripts and programs that connect on their own (an extractor, a
# Perl or Python client), an ssh config alias not listed itself, and names built at run time
# (variables, ANSI-C quoting).

guard_g13() {
  [ "$TOOL" = Bash ] || return 0
  local cmd list
  cmd=$(ti_get command) || return 0
  case "$cmd" in *'\u'*) cmd=$(_g13_unescape "$cmd") ;; esac
  case "$cmd" in *\\$'\n'*) cmd=$(_g13_join "$cmd") ;; esac
  # Cheap prefilter before settings_get: some client or transfer name, quotes and backslashes removed.
  _g13_flat "$cmd ${KERN_ALIAS_TEXT-}"
  _g13_names "$_G13_FLAT" || return 0
  list=$(settings_get protected_targets '')
  # A settings layer that could not be read may name more targets, so a command naming a client asks;
  # the targets the readable layers name are still checked.
  [ $? != 4 ] || vote ask G13 "protected_targets is unknown: $(settings_unread_why protected_targets)"
  [ -n "$list" ] || return 0
  _g13_scan "$cmd" "$list" 0
}

# _g13_scan CMD LIST DEPTH: judges each simple command of CMD that names a client.
_g13_scan() {
  local rec prev="" fed up
  while IFS= read -r rec; do
    if _g13_flat "$rec" && _g13_names "$_G13_FLAT"; then
      fed=0
      up=""
      if _g13_fed "$1" "$rec"; then
        fed=1
        up=$(_g13_upstream "$1" "$rec" "$prev")
      fi
      _g13_judge "$rec" "$2" "$fed" "$1" "$up" "$3"
    fi
    prev=$rec
  done <<EOT
$(git_words "$1")
EOT
}

# _g13_flat TEXT: sets _G13_FLAT to TEXT less quotes and backslashes, in one linear pass: bash 3.2's
# ${x//[...]/} is cubic on long text in a UTF-8 locale. Text with none of them is kept as is.
_g13_flat() {
  case "$1" in
    *[\"\'\\]*) _G13_FLAT=$(printf '%s' "$1" | env LC_ALL=C tr -d '\\"\047') ;;
    *) _G13_FLAT=$1 ;;
  esac
}

# _g13_names TEXT: exit 0 when TEXT holds a client or transfer name G13 reads, in any case (nc only as
# a whole word: as a substring it is in too many commands).
_g13_names() {
  case "$1" in
    *[Ss][Ss][Hh]* | *[Ss][Cc][Pp]* | *[Ff][Tt][Pp]* | *[Rr][Ss][Yy][Nn][Cc]* | *[Mm][Yy][Ss][Qq][Ll]* | \
      *[Mm][Aa][Rr][Ii][Aa][Dd][Bb]* | *[Pp][Ss][Qq][Ll]* | *[Ss][Qq][Ll][Ii][Tt][Ee]* | *[Ss][Qq][Ll][Cc][Mm][Dd]* | \
      *[Pp][Gg]_* | *[Pp][Ll][Ii][Nn][Kk]* | *[Mm][Yy][Cc][Ll][Ii]* | *[Pp][Gg][Cc][Ll][Ii]* | *[Uu][Ss][Qq][Ll]* | \
      *[Ll][Ii][Tt][Ee][Cc][Ll][Ii]* | *[Cc][Uu][Rr][Ll]* | *[Ww][Gg][Ee][Tt]* | *[Ss][Mm][Bb]* | *[Mm][Oo][Ss][Hh]* | \
      *[Pp][Ww][Ss][Hh]* | *[Pp][Oo][Ww][Ee][Rr][Ss][Hh][Ee][Ll][Ll]* | *[Nn][Cc][Aa][Tt]* | *[Nn][Ee][Tt][Cc][Aa][Tt]* | \
      *[Tt][Ee][Ll][Nn][Ee][Tt]* | *[Ss][Qq][Ss][Hh]* | *[Ii][Ss][Qq][Ll]* | [Nn][Cc]) return 0 ;;
  esac
  # nc as a whole word: a byte before and after it that is not a word byte, or the text's end. The word
  # bytes are listed: a range such as A-Z follows the locale's collation in bash 3.2, which in en_US.UTF-8
  # leaves out letters such as e-acute, and a `local LC_ALL=C` crashes bash 5.3 now and then (state.sh).
  case "$1" in
    [Nn][Cc][!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-]* | \
      *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-][Nn][Cc] | \
      *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-][Nn][Cc][!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-]*)
      return 0
      ;;
  esac
  return 1
}

# _g13_unescape CMD: CMD with the JSON escapes \u0000 to \u007f decoded (ti_get leaves \uXXXX as is).
_g13_unescape() {
  printf '%s' "$1" | env LC_ALL=C awk '
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

# _g13_join CMD: CMD with each backslash-newline the shell drops removed (one an even run of
# backslashes ends stays), so a continued line reads as git_words reads it.
_g13_join() {
  printf '%s' "$1" | env LC_ALL=C awk '
    NR > 1 { printf "%s", sep }
    {
      if (match($0, /\\+$/) && RLENGTH % 2 == 1) { printf "%s", substr($0, 1, length($0) - 1); sep = "" }
      else { printf "%s", $0; sep = "\n" }
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

# _g13_upstream CMD REC PREV: prints PREV when, at every place REC follows a pipe in CMD, PREV is the
# command right before that pipe, so PREV's output is REC's input.
_g13_upstream() {
  local rest="$1" r="${2//$_GW_NL/$'\n'}" p="${3//$_GW_NL/$'\n'}" pre
  [ -n "$p" ] || return 0
  while :; do
    case "$rest" in *"$r"*) ;; *) break ;; esac
    pre=${rest%%"$r"*}
    rest=${rest#*"$r"}
    while :; do
      case "$pre" in *[[:space:]] | *'(' | *'{' | *'!') pre=${pre%?} ;; *) break ;; esac
    done
    case "$pre" in
      *'||') continue ;;
      *'|&') pre=${pre%??} ;;
      *'|') pre=${pre%?} ;;
      *) continue ;;
    esac
    while :; do
      case "$pre" in *[[:space:]]) pre=${pre%?} ;; *) break ;; esac
    done
    case "$pre" in "$p" | *[[:space:]\;\&\|\(\)\{\}]"$p") ;; *) return 0 ;; esac
  done
  printf '%s' "$p"
}

# _g13_judge REC LIST FED CMD UP DEPTH: denies for each client in the simple command REC that reaches
# a target in LIST without a proven read. FED is 1 when REC's stdin may come from a pipe, and UP is
# the command that feeds it when G13 can tell; CMD is the whole command (for PGHOST= and the like set
# before the client, and for here-doc bodies). A line the judge starts with \001 is a command another
# host runs (ssh bastion "scp f v1-host:"): it is scanned in turn, two levels deep; one deeper that
# names a client is denied.
_g13_judge() {
  local why out
  # shellcheck disable=SC2153 # _GW_AWK is set in gitctx.sh
  if ! out=$(printf '%s' "$1" | G13_TG="$2" G13_FED="$3" G13_CMD="$4" G13_UP="$5" env LC_ALL=C \
    awk -v sq="'" "$_GW_AWK$_G13_AWK$_G13_SQL_AWK$_G13_XFER_AWK" 2>&1); then
    vote deny G13 "the protected_targets check failed: ${out%%$'\n'*}"
    return 0
  fi
  while IFS= read -r why; do
    case "$why" in
      $'\001'*)
        why=${why#?}
        why=${why//$_GW_NL/$'\n'}
        if [ "$6" -lt 2 ]; then
          _g13_scan "$why" "$2" $(($6 + 1))
        elif _g13_flat "$why" && _g13_names "$_G13_FLAT"; then
          vote deny G13 "a command run on another host nests too deep to check against protected targets"
        fi
        ;;
      ?*) vote deny G13 "$why" ;;
    esac
  done <<EOT
$out
EOT
}

# The judge, run on one simple command with _GW_AWK's functions. qw(STR) splits like sw and marks in
# qw_r[k] a word that is an unquoted redirection (a quoted '>' is an argument). Every word whose
# basename, lowercased and without .exe, is a client is judged from there on (a wrapper G13 does not
# know, such as caffeinate or sshpass, hides nothing); _cmd_words' head is judged too when no word
# matched (env -S). qw_d[k] marks a word with an unquoted or double-quoted $ or backtick, text the
# shell builds at run time. Each reason prints once.
# shellcheck disable=SC2016 # awk text
_G13_AWK='
  function qw(buf,   n, q, w, have, i, c, rd, quo, nx, dy) {
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
  # canon(H): H lowercased; every loopback or any-address spelling is localhost.
  function canon(h) {
    h = tolower(h); sub(/\.$/, "", h); gsub(/^\[|\]$/, "", h); sub(/^::ffff:/, "", h)
    if (h == "::1" || h == "0" || h == "0.0.0.0" || h ~ /^127\.[0-9]+(\.[0-9]+)?(\.[0-9]+)?$/) h = "localhost"
    return h
  }
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
  # Line sources: src_open(KIND, V) starts reading the string V (KIND s, split at newlines) or the
  # file V (KIND f, ~ and relative paths resolved); each src_line() call sets SL and returns 1, then
  # 0 at the end; SERR is set when the file cannot be read. src_stop() closes it early. Reading line
  # by line, and never joining lines into one string, keeps the time linear in BWK awk.
  function src_open(kind, v) {
    SK = kind; SERR = 0
    if (kind == "s") { SN = split(v, SA, /\n|\037/); SP = 0 }
    else SF = fpath(v)
  }
  function src_line(   r) {
    if (SK == "s") { if (SP >= SN) return 0; SL = SA[++SP]; return 1 }
    if ((r = (getline SL < SF)) > 0) return 1
    close(SF)
    if (r < 0) SERR = 1
    return 0
  }
  function src_stop() { if (SK == "f") close(SF) }
  function fpath(f) {
    if (f ~ /^~\//) return ENVIRON["HOME"] substr(f, 2)
    if (f !~ /^\//) return ENVIRON["CWD"] "/" f
    return f
  }
  # redir(K): W[K] is an unquoted redirection: sets RO (operator, fd number dropped), RT (target) and
  # RD (the target is built at run time); returns the index of the last word it takes.
  function redir(k,   w) {
    w = W[k]
    match(w, /^[0-9]*(&>>|&>|<<<|<<-|<<|<>|<&|>&|>>|>\||<|>)/)
    RO = substr(w, RSTART, RLENGTH); sub(/^[0-9]*/, "", RO)
    RT = substr(w, RLENGTH + 1); RD = D[k]
    if (RT == "" && k < N) { RT = W[k + 1]; RD = D[k + 1]; return k + 1 }
    return k
  }

  # rem(S): "" when the remote command S only reads, else what is not proven. Quotes are not trusted
  # to protect a separator or a redirect: the remote shell may be cmd, which has no quotes. A carriage
  # return ends a PowerShell statement; any other control character denies. A method call (.Name
  # followed by a paren) denies; a property read such as (Get-Item x).CreationTime does not.
  function rem(s,   n, segs, i, why) {
    if (match(s, CTLRE)) return "control character " ORD[substr(s, RSTART, 1)]
    why = rredir(s)
    if (why != "") return why
    if (match(RS_OUT, /\.[A-Za-z_][A-Za-z0-9_]*[ \t]*\(/)) return "method call " substr(RS_OUT, RSTART, RLENGTH)
    n = split(RS_OUT, segs, /[;&|\n\r\037(){}`]/)
    for (i = 1; i <= n; i++) if ((why = rseg(segs[i])) != "") return why
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
  # rseg(SEG): one segment of a remote command: its head must be on the read list. A cmd or
  # powershell wrapper is not unwrapped: it denies.
  function rseg(seg,   n, a, h, i, w) {
    gsub(/^[ \t]+|[ \t]+$/, "", seg)
    if (unq(seg) ~ /^[ \t]*$/) return ""
    n = split(seg, a, /[ \t]+/)
    h = base(unq(a[1]))
    if (h == "cmd" || h == "powershell" || h == "pwsh") return "`" h "` wraps a command, which kern does not unwrap"
    if (h ~ /^\./) return (n == 1 && unq(seg) ~ /^(\.[A-Za-z_][A-Za-z0-9_]*)+$/) ? "" : "`" seg "` is not a property read"
    if (!(h in READ) && h !~ /^get-[a-z]/) return "`" h "` is not on the read list"
    for (i = 2; i <= n; i++) {
      w = unq(a[i])
      if (h == "find" && tolower(w) ~ /^-(delete|exec|execdir|ok|okdir|fprint|fprint0|fprintf|fls)$/) return "`find " w "` writes or runs a command"
      if (h == "date" && (w ~ /^-[A-Za-z]*s/ || w ~ /^--set/ || w ~ /^[0-9]/)) return "`date " w "` may set the clock"
      if (h == "hostname" && w !~ /^-([sfiIdaAvhV]|-short|-fqdn|-long|-ip-address|-all-ip-addresses|-domain|-alias|-all-fqdns|-help|-version)$/) return "`hostname " w "` may set the host name"
      if (h == "file" && w ~ /^(-[A-Za-z]*C|--compile)/) return "`file " w "` writes a magic file"
    }
    return ""
  }
  # j_ssh(S, B): ssh, autossh or plink at word S. OpenSSH reads options before and after the
  # destination; the first word after that starts the remote command. the -M of autossh takes a port.
  # The parse fills the X_ globals and ssh_end decides.
  function j_ssh(s, b,   k, w, j, c, v, vl, inc) {
    X_port = 22; X_dest = ""; X_rc = ""; X_orc = ""; X_nf = 0; X_nin = 0; X_ctl = 0; X_stdin = ""; X_t = 0
    X_lc = ""; X_lt = 0; X_oh = ""; X_dyn = 0; X_mux = 0; X_file = ""; X_load = ""
    if (b == "plink") { p_plink(s); ssh_end(b); return }
    vl = "BbcDEeFIiJLlmOoPpQRSWw" (b == "autossh" ? "M" : "")
    inc = 0
    for (k = s + 1; k <= N; k++) {
      w = W[k]
      if (R[k]) { k = redir(k); sshin(); continue }
      if (inc) { X_rc = X_rc " " w; X_dyn = X_dyn || D[k]; continue }
      if (w ~ /^-./ && w != "--") {
        for (j = 2; j <= length(w); j++) {
          c = substr(w, j, 1)
          if (index(vl, c)) {
            v = substr(w, j + 1)
            if (v == "" && k < N) v = W[++k]
            if (c == "p") X_port = v
            else if (c == "J" && !X_t) X_t = hops(v)
            else if (c == "O" || c == "W") X_ctl = 1
            else if (c == "S" && tolower(v) != "none") X_mux = 1
            else if (c == "o") sshopt(v, D[k])
            break
          }
          if (c == "N") X_nf = 1
          else if (c == "n") X_nin = 1
          else if (c == "G" || c == "V") X_ctl = 2
        }
        continue
      }
      if (w == "--") continue
      if (X_dest == "") { X_dest = w; continue }
      inc = 1; X_rc = w; X_dyn = D[k]
    }
    ssh_end(b)
  }
  # p_plink(S): PuTTY plink [options] [user@]host [command]. -m reads the command from a file, and
  # -load may name the host through a saved session.
  function p_plink(s,   k, w, v, inc) {
    inc = 0
    for (k = s + 1; k <= N; k++) {
      w = W[k]
      if (R[k]) { k = redir(k); sshin(); continue }
      if (inc) { X_rc = X_rc " " w; X_dyn = X_dyn || D[k]; continue }
      if (w ~ /^-./) {
        if (w in PLINKV) {
          v = (k < N) ? W[++k] : ""
          if (w == "-P") X_port = v
          else if (w == "-m") X_file = v
          else if (w == "-load") X_load = v
          else if (w == "-nc") X_ctl = 1
          else if (w == "-proxycmd" && (X_lt = named(v))) X_lc = w
        }
        else if (w == "-N") X_nf = 1
        continue
      }
      if (X_dest == "") { X_dest = w; continue }
      inc = 1; X_rc = w; X_dyn = D[k]
    }
    if (X_dest == "") X_dest = X_load
  }
  function sshin() { if (RO ~ /^</ && !(RO == "<" && RT == "/dev/null")) X_stdin = RO }
  # sshopt(V, DYN): one ssh -o option.
  function sshopt(v, dy,   key) {
    key = tolower(v); sub(/[ =].*/, "", key); sub(/^[^ =]*[ =][ \t]*/, "", v)
    if (key == "port") X_port = v
    else if (key == "hostname") X_oh = v
    else if (key == "remotecommand") { X_orc = v; X_dyn = X_dyn || dy }
    else if (key == "controlpath" || key == "controlmaster") { if (tolower(v) != "none") X_mux = 1 }
    else if (key == "proxyjump" && !X_t) X_t = hops(v)
    else if (key ~ /^(proxycommand|localcommand|knownhostscommand)$/ && (X_lt = named(v))) X_lc = "-o " key
    else if (!X_t) X_t = named(v)
  }
  # ssh_end(TOOL): an ssh whose session may run on a target (its destination, a jump, HostName, or a
  # shared connection, whose master may be on a target) must run a proven read.
  function ssh_end(tool,   t, h, why) {
    if (X_ctl == 2 || X_dest == "") return
    if (X_lc != "") { deny(tool " " X_lc " runs a command that names protected target " tr[X_lt] "; kern cannot check it"); return }
    uhost(X_dest)
    t = X_t
    if (!t) t = hit(UH, UP != "" ? UP : X_port)
    if (!t && X_oh != "") t = hit(X_oh, UP != "" ? UP : X_port)
    if (!t && X_load != "") t = named(X_load)
    if (t) h = tool " to protected target " tr[t]
    else if (X_mux) h = tool " over a shared connection (-S, ControlPath or ControlMaster; judged as a protected target)"
    else {
      # Another host may reach a target in turn (ssh bastion "scp f v1-host:"): the caller checks its
      # command as a command line.
      if (X_rc != "") print "\001" X_rc
      if (X_orc != "") print "\001" X_orc
      return
    }
    if (X_file != "") { deny(h " reads its remote command from " X_file); return }
    if (X_rc == "" && X_orc == "") {
      if (X_nf || X_ctl) return
      deny(h " with no remote command opens a shell")
      return
    }
    if (!X_nin && X_stdin != "") deny(h " with input on stdin (" X_stdin ")")
    else if (!X_nin && FED) deny(h " with input piped to it")
    if (X_dyn) deny(h ": the remote command is built at run time ($ or a backtick)")
    if (X_rc != "" && (why = rem(X_rc)) != "") deny(h ": " why)
    if (X_orc != "" && (why = rem(X_orc)) != "") deny(h " (-o RemoteCommand): " why)
  }
  # hops(V): the target a comma list of jump hosts names, else 0.
  function hops(v,   n, a, i, t) {
    n = split(v, a, ",")
    for (i = 1; i <= n; i++) { uhost(a[i]); if ((t = hit(UH, UP != "" ? UP : 22))) return t }
    return 0
  }

  # j_net(S, B): a network client G13 has no read proof for. It is denied when a word names a target
  # (a host, or an sqlite path), or holds the port of a host:port target next to its host (alone for a
  # loopback target, the client default). pwsh and powershell vote only with a remoting parameter.
  function j_net(s, b,   k, w, t, ps, x, pk, hk) {
    if (b == "pwsh" || b == "powershell") {
      ps = 0
      for (k = s + 1; k <= N; k++) if (tolower(W[k]) ~ /(^|[^a-z0-9_-])-(computername|cn|hostname|[a-z]*session)([^a-z0-9_-]|$)/) ps = 1
      if (!ps) return
    }
    for (t = 1; t <= tn; t++) { pk[t] = 0; hk[t] = (th[t] == "localhost") }
    for (k = s + 1; k <= N; k++) {
      if (R[k]) { k = redir(k); continue }
      w = tolower(W[k])
      if ((t = named(w)) || (t = pathhit(w))) break
      for (t = 1; t <= tn; t++) if (tp[t] != "") {
        if (w ~ ("(^|[^0-9])" tp[t] "([^0-9]|$)")) pk[t] = 1
        if (bnd(w, th[t], "")) hk[t] = 1
      }
      t = 0
    }
    if (!t) for (x = 1; x <= tn && !t; x++) if (pk[x] && hk[x]) t = x
    if (t) deny(b " names protected target " tr[t] "; kern proves reads only for ssh, scp, sftp, rsync and SQL clients")
  }
  # pathhit(W): the path target (an entry holding a /) W holds, else 0.
  function pathhit(w,   k) {
    for (k = 1; k <= tn; k++) if (index(tr[k], "/") && index(w, tolower(tr[k]))) return k
    return 0
  }
  function judge(b, k) {
    if (b == "ssh" || b == "autossh" || b == "plink") j_ssh(k, b)
    else if (b in NET) j_net(k, b)
    else if (b == "scp") j_scp(k)
    else if (b == "rsync") j_rsync(k)
    else if (b == "sftp") j_sftp(k)
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
      "gci gc sls format-table format-list ft fl", ra, " ")
    for (k = 1; k <= nr; k++) READ[ra[k]] = 1
    JUDGE["ssh"] = JUDGE["autossh"] = JUDGE["plink"] = 1
    n = split("-P -l -pw -pwfile -i -m -load -hostkey -L -R -D -nc -proxycmd -sshlog -sshrawlog -sercfg", a, " ")
    for (k = 1; k <= n; k++) PLINKV[a[k]] = 1
    n = split("mycli pgcli usql litecli curl wget smbclient mount_smbfs lftp ftp mosh nc ncat netcat telnet sqsh isql " \
      "pwsh powershell", a, " ")
    for (k = 1; k <= n; k++) NET[a[k]] = JUDGE[a[k]] = 1
    CTLRE = ""
    for (k = 1; k < 128; k++) {
      ORD[sprintf("%c", k)] = k
      if (k < 32 && k != 9 && k != 10 && k != 13 && k != 31 || k == 127) CTLRE = CTLRE sprintf("%c", k)
    }
    CTLRE = "[" CTLRE "]"
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
# proven: it needs no lexing beyond plain literals (see sqlscan), starts with SELECT, SHOW, DESCRIBE,
# DESC, EXPLAIN or WITH, and holds no write, lock, file or wait word. Files are opened only once a
# target is known. Piped, here-doc or run-time input, a file G13 cannot read, input over 1 MB, and no
# statement at all are denied.
# shellcheck disable=SC2016 # awk text
_G13_SQL_AWK='
  function j_sql(s, b,   fam, k, w, j, c, v, x, opt, pos, t, i, h, why, role) {
    fam = SQLFAM[b]
    nh = 0; np = 0; nst = 0; stdin = ""; dyn = 0; single = 0; locks = ""; pos = 0; dbf = ""; FBT = 0; vars = ""; lread = 0
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
        if ((b SUBSEP opt) in LONG) role = LONG[b, opt]
        else if ((fam SUBSEP opt) in LONG) role = LONG[fam, opt]
        else role = lpre(b, fam, opt)
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
          if (b == "psql" && c == "l") lread = 1
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
    if (dyn) deny("SQL to protected target " h " built at run time ($ or a backtick)")
    if (nst == 0 && !lread) { deny("SQL to protected target " h " with no statement opens an interactive " b); return }
    x = 0
    for (i = 1; i <= nst; i++) {
      if ((j = srcsize(i)) < 0) { deny("SQL to protected target " h ": cannot read " ST[i]); STK[i] = "x" }
      else x += j
    }
    if (x > 1048576) { deny("SQL to protected target " h ": input over 1 MB, more than kern reads"); return }
    for (i = 1; i <= nst; i++) if (STK[i] != "x" && (why = sqlscan(i, fam, 0)) != "") { deny("SQL to protected target " h ": " why); break }
    if (vars != "") {
      ST[++nst] = vars; STK[nst] = "s"
      if (index(vars, ";") || (why = sqlscan(nst, fam, 1)) != "") deny("SQL to protected target " h ": a psql variable holds SQL")
    }
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
  # sqlst and sqlfile queue a statement source; a file is not opened until a target is known.
  function sqlst(v, dy) { ST[++nst] = v; STK[nst] = "s"; if (dy) dyn = 1 }
  function sqlfile(f) {
    if (f ~ /^(-|\/dev\/stdin|\/dev\/fd\/0|\/proc\/self\/fd\/0)$/) { stdin = "stdin"; return }
    ST[++nst] = f; STK[nst] = "f"
  }
  # srcsize(I): the bytes of source I, counted up to just past 1 MB; -1 when it cannot be read.
  function srcsize(i,   t) {
    src_open(STK[i], ST[i]); t = 0
    while (src_line()) if ((t += length(SL) + 1) > 1048576) { src_stop(); break }
    return SERR ? -1 : t
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
  # lpre(B, FAM, OPT): the role of the long option OPT abbreviates (mysql clients and getopt_long
  # take any unambiguous prefix), for a prefix of two letters or more; else "".
  function lpre(b, fam, opt,   key, kk) {
    if (length(opt) < 4) return ""
    for (key in LONG) {
      split(key, kk, SUBSEP)
      if ((kk[1] == b || kk[1] == fam) && index(kk[2], opt) == 1) return LONG[key]
    }
    return ""
  }
  # dumpopt: an unambiguous prefix counts too, so --lock-t is --lock-tables.
  function dumpopt(opt, v, x,   off) {
    off = x && tolower(v) ~ /^(0|off|false)$/
    if (length(opt) > 8 && index("--single-transaction", opt) == 1) single = !off
    else if (opt ~ /^--(skip|disable)-single-transaction$/) single = 0
    else if (!off && opt ~ /^--(lock|master|source-d|flush|delete-m|delete-s|dump-s|dump-r)/) locks = locks " " opt
  }

  # sqlscan(I, FAM, FRAG): "" when every statement of source I reads, else why not. G13 lexes only the
  # plainest SQL, so no client can split or quote it differently: a single-quoted literal with no
  # backslash or doubled quote, and (mysql) a backtick name with no backtick inside. A comment, a
  # backslash, a double-quoted string, a dollar quote, an E string, a doubled quote and an unterminated
  # literal deny. It walks each line once (split into characters), so time is linear. sqlite3 dot
  # commands on LITEDOT and sqlcmd GO lines are allowed; other client commands deny. FRAG: a psql
  # variable, which has no statement head.
  function sqlscan(i, fam, frag,   line, n, C, j, c, nx, name, why) {
    src_open(STK[i], ST[i]); Q_q = ""; Q_frag = frag; Q_fam = fam; Q_tok = ""; sqlend()
    while (src_line()) {
      line = SL
      if (Q_q == "") {
        if (fam == "lite" && line ~ /^[ \t]*\./) {
          name = line; sub(/^[ \t]*\./, "", name); sub(/[ \t].*/, "", name)
          if (!(tolower(name) in LITEDOT)) return sqlfail("sqlite3 dot command ." name)
          sqlend(); continue
        }
        if (fam == "ms" && tolower(line) ~ /^[ \t]*go([ \t]+[0-9]+)?[ \t]*$/) { sqlend(); continue }
        if (fam == "ms" && line ~ /^[ \t]*(:|!!)/) return sqlfail("sqlcmd command " substr(line, 1, 24))
      }
      n = split(line, C, "")
      for (j = 1; j <= n; j++) {
        c = C[j]
        if (Q_q != "") {
          if (c == "\\") return sqlfail("a backslash in a literal")
          if (c == Q_q) { if (C[j + 1] == Q_q) return sqlfail("a doubled quote in a literal"); Q_q = "" }
          continue
        }
        nx = C[j + 1]
        if ((c == "-" && nx == "-") || c == "#" || (c == "/" && nx == "*")) return sqlfail("a comment")
        if (c == "\\") return sqlfail("a backslash")
        if (c == "\"") return sqlfail("a double-quoted string")
        if (c == "$" && dollar(C, j, n) != "") return sqlfail("a dollar quote")
        if (fam == "ms" && c == "$" && nx == "(") return sqlfail("sqlcmd variable $(")
        if (c == sq || (c == "`" && fam == "my")) {
          if (c == sq && tolower(Q_tok) == "e") return sqlfail("an E string")
          if ((why = tokend()) != "") return sqlfail(why)
          Q_q = c; continue
        }
        if (c ~ /[A-Za-z_]/ || (Q_tok != "" && c ~ /[0-9$]/)) { Q_tok = Q_tok c; continue }
        if ((why = tokend()) != "") return sqlfail(why)
        if (c == ";") { sqlend(); continue }
        if (c !~ /[ \t\r(]/ && Q_head == "" && !Q_frag) return sqlfail("statement starting `" c "` is not a read")
      }
      if ((why = tokend()) != "") return sqlfail(why)
    }
    if (SERR) return "cannot read " ST[i]
    return Q_q != "" ? "an unterminated literal" : ""
  }
  function sqlfail(why) { src_stop(); return why }
  function sqlend() { Q_head = ""; Q_prev = ""; Q_tok = "" }
  # tokend(): ends the word in Q_tok. The first word of a statement must be a read head; no word may
  # write, lock or wait.
  function tokend(   w) {
    if (Q_tok == "") return ""
    w = tolower(Q_tok); Q_tok = ""
    if (!Q_frag && Q_head == "") { Q_head = w; if (!(w in SQLHEAD)) return "statement starting `" w "` is not a read" }
    if (Q_head == "show" && (w == "create" || w == "set")) { Q_prev = w; return "" }
    if ((w in SQLANY) || (Q_fam == "ms" && (w in MSANY)) || w ~ /^(pg_advisory_|pg_try_advisory_|pg_stat_reset|pg_replication_origin_)/) return "`" w "` writes, locks or waits"
    if (w == "share" && (Q_prev == "for" || Q_prev == "key")) return "`" Q_prev " share` locks rows"
    Q_prev = w
    return ""
  }
  # dollar(C, J, N): the psql dollar-quote tag ($$ or $name$) that starts at C[J], else "".
  function dollar(C, j, n,   k, t) {
    t = "$"
    for (k = j + 1; k <= n && C[k] ~ /[A-Za-z0-9_]/; k++) { if (k == j + 1 && C[k] ~ /[0-9]/) return ""; t = t C[k] }
    return (k <= n && C[k] == "$") ? t "$" : ""
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

# The transfer judge, appended to _G13_AWK. A remote operand is scp://, sftp:// or rsync://
# [user@]host[:port]/..., host::module, or [user@]host:path with the colon before any slash. scp and
# rsync deny a copy whose destination, the last positional word, is on a target; rsync also denies
# --remove-source-files, --delete* and a remote command (--rsync-path, -M) when any operand is on a
# target. A long rsync option written without = is read both with and without a value, so the last
# positional is never guessed wrong. sftp to a target runs only read verbs, read from -b, a
# here-string, the command's only here-doc, a < file, or a pipe from echo, printf or cat.
# shellcheck disable=SC2016 # awk text
_G13_XFER_AWK='
  function isremote(w) {
    return w ~ /^[A-Za-z][A-Za-z0-9+.-]*:\/\// || (index(w, ":") && (!index(w, "/") || index(w, ":") < index(w, "/")))
  }
  # ohit(W, PORT, DPORT): the target the remote operand W names; DPORT is the port of host::module.
  function ohit(w, port, dport,   h) {
    if (w ~ /^[A-Za-z][A-Za-z0-9+.-]*:\/\//) { uhost(w); return hit(UH, UP != "" ? UP : (w ~ /^rsync:/ ? dport : port)) }
    h = substr(w, 1, index(w, ":") - 1); sub(/.*@/, "", h)
    return hit(h, substr(w, index(w, ":") + 1, 1) == ":" ? dport : port)
  }
  # oval(TOOL, V): an ssh -o option of scp, sftp or rsync -e. Sets O_PORT for Port; returns the
  # target its value names. A command option that names a target is denied.
  function oval(tool, v,   key, t) {
    key = tolower(v); sub(/[ =].*/, "", key); sub(/^[^ =]*[ =][ \t]*/, "", v)
    if (key == "port") O_PORT = v
    if (!(t = named(v))) return 0
    if (key ~ /^(proxycommand|localcommand|knownhostscommand|remotecommand)$/) deny(tool " -o " key " runs a command that names protected target " tr[t] "; kern cannot check it")
    return t
  }
  function j_scp(s,   k, w, j, c, v, n, a, t, port, ot, x) {
    n = 0; port = 22; ot = 0
    for (k = s + 1; k <= N; k++) {
      w = W[k]
      if (R[k]) { k = redir(k); continue }
      if (w ~ /^-./) {
        for (j = 2; j <= length(w); j++) {
          c = substr(w, j, 1)
          if (index("cDFiJloPSX", c)) {
            v = substr(w, j + 1)
            if (v == "" && k < N) v = W[++k]
            if (c == "P") port = v
            else if (c == "J" && !ot) ot = hops(v)
            else if (c == "o") { O_PORT = ""; x = oval("scp", v); if (!ot) ot = x; if (O_PORT != "") port = O_PORT }
            break
          }
        }
        continue
      }
      a[++n] = w
    }
    if (n < 2 || !isremote(a[n])) return
    if ((t = ohit(a[n], port, 22)) || (t = ot)) deny("scp copy to protected target " tr[t])
  }
  function j_rsync(s,   k, w, j, c, v, x, pa, pb, na, nb, pend, rm, del, rc, i, t, touch, sp) {
    na = 0; nb = 0; pend = 0; rm = 0; del = 0; rc = ""; RT_OT = 0; sp = 22
    for (k = s + 1; k <= N; k++) {
      w = W[k]
      if (R[k]) { k = redir(k); continue }
      if (w == "--") { for (k++; k <= N; k++) if (!R[k]) { pa[++na] = W[k]; pb[++nb] = W[k] }; break }
      if (w ~ /^--./) {
        pend = 0; x = w; sub(/=.*/, "", x); v = ""
        if (index(w, "=")) v = substr(w, index(w, "=") + 1)
        else if (x ~ /^--(rsh|rsync-path|remote-option)$/) { if (k < N) v = W[++k] }
        else pend = 1
        if (x ~ /^--(remove-source-files|remove-sent-files)$/ || (x == "--remote-option" && v ~ /remove-s(ource|ent)-files/)) rm = 1
        if (x ~ /^--del/ || (x == "--remote-option" && v ~ /^--del/)) del = 1
        if (x ~ /^--(rsync-path|remote-option)$/) rc = x
        if (x == "--rsh") sp = rsh(v, sp)
        continue
      }
      if (w ~ /^-./) {
        pend = 0
        for (j = 2; j <= length(w); j++) {
          c = substr(w, j, 1)
          if (index("efBTM@", c)) {
            v = substr(w, j + 1)
            if (v == "" && k < N) v = W[++k]
            if (c == "e") sp = rsh(v, sp)
            if (c == "M") { rc = "-M"; if (v ~ /remove-s(ource|ent)-files/) rm = 1; if (v ~ /^--del/) del = 1 }
            break
          }
        }
        continue
      }
      pa[++na] = w
      if (pend) pend = 0
      else pb[++nb] = w
    }
    touch = 0
    for (i = 1; i <= na; i++) if ((t = rhit(pa[i], sp))) {
      touch = t
      if (na >= 2 && i == na) deny("rsync to protected target " tr[t])
    }
    for (i = 1; i <= nb; i++) if ((t = rhit(pb[i], sp))) {
      touch = t
      if (nb >= 2 && i == nb) deny("rsync to protected target " tr[t])
    }
    if (!touch) return
    if (rm) deny("rsync --remove-source-files deletes on protected target " tr[touch])
    if (del) deny("rsync --delete touching protected target " tr[touch])
    if (rc != "") deny("rsync " rc " runs a remote command on protected target " tr[touch])
  }
  # rhit(W, PORT): the target the rsync operand W is on: by its host, or any remote operand when -e
  # names a target.
  function rhit(w, port,   t) {
    if (!isremote(w)) return 0
    t = ohit(w, port, 873)
    return t ? t : RT_OT
  }
  # rsh(V, PORT): an rsync -e command. Notes in RT_OT the target it names; returns its -p port.
  function rsh(v, port,   n, a, i, t) {
    n = split(v, a, /[ \t]+/)
    for (i = 1; i <= n; i++) {
      if (a[i] == "-p" && i < n) port = a[i + 1]
      else if (a[i] ~ /^-p[0-9]+$/) port = substr(a[i], 3)
      else if (a[i] == "-o" && i < n) { O_PORT = ""; if ((t = oval("rsync -e", a[i + 1]))) RT_OT = t; if (O_PORT != "") port = O_PORT }
    }
    if (!RT_OT) RT_OT = named(v)
    return port
  }
  function j_sftp(s,   k, w, j, c, v, n, a, t, port, ot, bf, stdin, rt, rd, txt, why, h, x, path) {
    n = 0; port = 22; ot = 0; bf = ""; stdin = ""; rt = ""; rd = 0
    for (k = s + 1; k <= N; k++) {
      w = W[k]
      if (R[k]) { k = redir(k); if (RO ~ /^</) { stdin = RO; rt = RT; rd = RD }; continue }
      if (w ~ /^-./) {
        for (j = 2; j <= length(w); j++) {
          c = substr(w, j, 1)
          if (index("BbcDFiJloPRSsX", c)) {
            v = substr(w, j + 1)
            if (v == "" && k < N) v = W[++k]
            if (c == "b") bf = v
            else if (c == "P") port = v
            else if (c == "J" && !ot) ot = hops(v)
            else if (c == "o") { O_PORT = ""; x = oval("sftp", v); if (!ot) ot = x; if (O_PORT != "") port = O_PORT }
            break
          }
        }
        continue
      }
      a[++n] = w
    }
    if (n < 1) return
    if (a[1] ~ /^[A-Za-z][A-Za-z0-9+.-]*:\/\//) { uhost(a[1]); t = hit(UH, UP != "" ? UP : port); path = a[1]; sub(/^[^:]*:\/\/[^\/]*/, "", path) }
    else { h = a[1]; sub(/:.*/, "", h); sub(/.*@/, "", h); t = hit(h, port); path = index(a[1], ":") ? substr(a[1], index(a[1], ":") + 1) : "" }
    if (!t) t = ot
    if (!t) return
    h = "sftp to protected target " tr[t]
    # sftp host:path with no batch and no input fetches path and exits: a get.
    if (bf == "" && stdin == "" && !FED && path != "") return
    nsrc = 0
    if (bf != "" && bf != "-") { SRK[++nsrc] = "f"; SRV[nsrc] = bf }
    else if (stdin == "<<<") { if (rd) { deny(h ": the here-string is built at run time"); return }; SRK[++nsrc] = "s"; SRV[nsrc] = rt }
    else if (stdin ~ /^<<-?$/) {
      txt = hdbody()
      if (HDN != 1) { deny(h ": the command holds more than one here-doc"); return }
      if (!HDQ && txt ~ /[$`]/) { deny(h ": the here-doc expands $ or a backtick"); return }
      SRK[++nsrc] = "s"; SRV[nsrc] = txt
    }
    else if (stdin == "<") { SRK[++nsrc] = "f"; SRV[nsrc] = rt }
    else if (stdin != "") { deny(h " with input from " stdin); return }
    else if (FED) { if (!upstream()) { deny(h " with input piped from a command kern cannot read"); return } }
    else { deny(h " with no batch opens an interactive session"); return }
    if ((why = sftpok()) != "") deny(h ": " why)
  }
  # sftpok(): "" when every line of the queued sources (SRK, SRV) is a read verb, else why not.
  function sftpok(   i, l, v) {
    for (i = 1; i <= nsrc; i++) {
      src_open(SRK[i], SRV[i])
      while (src_line()) {
        l = SL; sub(/^[ \t]+/, "", l)
        if (l == "" || l ~ /^#/) continue
        sub(/^[-@]+/, "", l)
        v = tolower(l); sub(/[ \t].*/, "", v)
        if (!(v in SFTPREAD)) { src_stop(); return "`" v "` is not a read" }
      }
      if (SERR) return "cannot read " SRV[i]
    }
    return ""
  }
  # upstream(): queues as sources what the piped command G13_UP prints: echo, printf with a literal
  # format or %s\n, or cat of files. Returns 0 when G13 cannot tell.
  function upstream(   n, k, b, t) {
    if (ENVIRON["G13_UP"] == "") return 0
    qw(ENVIRON["G13_UP"]); n = qw_n
    for (k = 1; k <= n; k++) if (qw_r[k] || qw_d[k]) return 0
    b = base(qw_w[1]); t = ""
    if (b == "echo") {
      for (k = 2; k <= n && qw_w[k] ~ /^-[neE]+$/; k++) ;
      for (; k <= n; k++) t = t (t == "" ? "" : " ") qw_w[k]
      gsub(/\\n/, "\n", t); SRK[++nsrc] = "s"; SRV[nsrc] = t; return 1
    }
    if (b == "printf" && n >= 2) {
      if (qw_w[2] == "%s\\n") { for (k = 3; k <= n; k++) { SRK[++nsrc] = "s"; SRV[nsrc] = qw_w[k] }; return 1 }
      if (index(qw_w[2], "%")) return 0
      t = qw_w[2]; gsub(/\\n/, "\n", t); SRK[++nsrc] = "s"; SRV[nsrc] = t; return 1
    }
    if (b == "cat" && n >= 2) {
      for (k = 2; k <= n; k++) { if (qw_w[k] ~ /^-/) return 0; SRK[++nsrc] = "f"; SRV[nsrc] = qw_w[k] }
      return 1
    }
    return 0
  }
  # hdbody(): the body of the only here-doc in the command. Sets HDN to the number of << operators and
  # HDQ when the delimiter is quoted (the body is not expanded).
  function hdbody(   tmp, i, nl, L, k, line, p, off, d, dash, out) {
    HDN = 0; HDQ = 0; tmp = CMDTXT
    while ((i = index(tmp, "<<")) > 0) { if (substr(tmp, i + 2, 1) != "<") HDN++; tmp = substr(tmp, i + (substr(tmp, i + 2, 1) == "<" ? 3 : 2)) }
    if (HDN != 1) return ""
    nl = split(CMDTXT, L, "\n"); p = 0
    for (k = 1; k <= nl && !p; k++) {
      tmp = L[k]; off = 0
      while ((i = index(tmp, "<<")) > 0) {
        if (substr(tmp, i + 2, 1) != "<") { p = off + i; break }
        off += i + 2; tmp = substr(tmp, i + 3)
      }
    }
    if (!p) return ""
    line = L[--k]; d = substr(line, p + 2); dash = 0
    if (substr(d, 1, 1) == "-") { dash = 1; d = substr(d, 2) }
    sub(/^[ \t]+/, "", d)
    match(d, /^[^ \t;&|<>()]*/); d = substr(d, 1, RLENGTH)
    HDQ = (d ~ /["\\]/ || index(d, sq) > 0)
    d = unq(d); gsub(/\\/, "", d)
    out = ""
    for (k++; k <= nl; k++) { line = L[k]; if (dash) sub(/^\t+/, "", line); if (line == d) break; out = out line "\n" }
    return out
  }
  BEGIN {
    JUDGE["scp"] = JUDGE["rsync"] = JUDGE["sftp"] = 1
    n = split("get reget ls dir cd lcd lls pwd lpwd help exit quit bye version progress", a, " ")
    for (i = 1; i <= n; i++) SFTPREAD[a[i]] = 1
  }
'
