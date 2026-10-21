# shellcheck shell=bash
# Shell and git parsing for guards. Needs settings.sh; uses aliases.sh when it is loaded. Reads CWD and
# KERN_MAIN.

# A newline inside one record (quoted text, or the inside of $( )) is printed as this byte, so a
# caller that reads records line by line never takes a quoted line for a command.
_GW_NL=$'\037'
# git_words' own state, never taken from the environment: _GW_IN marks a call inside the outermost
# one, _GW_NOALIAS a call that splits an alias's expansion. _GW_QB, set by G00 alone for its call, asks
# for each quoted here-doc body that may hold an array subscript as one record after a \035 byte.
unset _GW_IN _GW_NOALIAS _GW_QB

# _GW_AWK: awk functions shared by _shell_words, _cmd_words and _split_words (run with -v sq="'").
# sw(STR) splits STR into words, quotes removed, in sw_w[1..sw_n] (see _shell_words). cw_reset()
# starts a simple command and cw(WORD) feeds it one word; the command name and its arguments
# collect in cw_w[1..cw_n] (see _cmd_words).
# shellcheck disable=SC2016 # awk text
_GW_AWK='
  BEGIN {
    cw_opt["sudo"] = " -C -D -g -h -p -R -r -T -t -U -u --user --group --host --prompt --chdir --chroot "
    cw_opt["sudo"] = cw_opt["sudo"] "--role --type --close-from --other-user --command-timeout "
    cw_opt["env"] = " -C -P -S -u --chdir --unset --split-string --argv0 "
    cw_opt["exec"] = " -a "
    cw_opt["timeout"] = " -s -k --signal --kill-after "
    cw_opt["nice"] = " -n --adjustment "
    # The long options of bash (long_args in shell.c); 1 takes the next word as its value. bash also
    # reads them with one dash (-rcfile f), and only before the first short option.
    split("debug debugger dump-po-strings dump-strings help login noediting noprofile norc posix " \
      "pretty-print protected restricted verbose version wordexp", sh_a, " ")
    for (sh_i in sh_a) sh_long[sh_a[sh_i]] = 0
    sh_long["rcfile"] = sh_long["init-file"] = 1
  }
  # gw_dyn(w): true when the word w, quotes removed, may expand into other words at run time: it
  # holds a $ or a backtick, or a brace pattern ({a,b} or {a..b}).
  function gw_dyn(w) { return w ~ /[$`]/ || w ~ /[{][^}]*(,|[.][.])[^}]*[}]/ }
  # gw_path(w): true when the word w is $NAME/ or ${NAME}/ and a rest gw_dyn finds literal, such as
  # $HOME/.local/bin/bats: a path under a variable, which is an accepted limit as a script file is.
  function gw_path(w) {
    return w ~ /^[$]([{][A-Za-z_][A-Za-z0-9_]*[}]|[A-Za-z_][A-Za-z0-9_]*)\// &&
      !gw_dyn(substr(w, index(w, "/")))
  }
  # shc(h, z): for the sh-family shell at cw_w[h], the index of the word it runs as its -c script, by
  # the rules of bash (z = 0) or of zsh (z = 1). Callers take both, since sh may be either. The script
  # is the first word after the options, which end at -, --, or the first word that does not start
  # with - or +. A c in a cluster, after either sign, asks for a script. bash: long options come
  # first, and each o or O in a cluster takes the next word. zsh: o takes the rest of its cluster or
  # else the next word, b ends the options after its word, --emulate takes the next word and any
  # other --name takes no value. Returns 0 when no script is run, and -1 when a word that may be an
  # option or its value is built at run time (a script operand under a variable, as gw_path reads
  # it, is a script file).
  # Also sets shc_op, the index of the first word after the options (0 when there is none), and
  # shc_s, true when an s in a cluster reads the commands from stdin.
  function shc(h, z,   k, w, c, lng, nm, n, i, C, brk) {
    c = 0; lng = !z; shc_op = 0; shc_s = 0
    for (k = h + 1; k <= cw_n; k++) {
      w = cw_w[k]
      # A redirection is not an argument; one with no target attached takes the next word.
      if (w ~ /^[0-9]*(<|>|&>)/) { if (w ~ /^[0-9]*[<>&|]+$/) k++; continue }
      if (w !~ /^[-+]/) { shc_op = k; if (c) return k; return gw_dyn(w) && !gw_path(w) ? -1 : 0 }
      if (gw_dyn(w)) return -1
      if (w == "-" || w == "--" || (z && w == "+")) { k++; break }
      if (lng && w ~ /^-/) {
        nm = w; sub(/^--?/, "", nm)
        if (nm in sh_long) { if (sh_long[nm] && ++k <= cw_n && gw_dyn(cw_w[k])) return -1; continue }
        if (w ~ /^--/) return 0
      }
      lng = 0
      if (z && w == "--emulate") { if (++k <= cw_n && gw_dyn(cw_w[k])) return -1; continue }
      if (z && w ~ /^--/) continue
      n = split(substr(w, 2), C, ""); brk = 0
      for (i = 1; i <= n; i++) {
        if (C[i] == "s") shc_s = 1
        if (C[i] == "c") c = 1
        else if (z && C[i] == "b") brk = 1
        else if (z && C[i] == "o") { if (i == n && ++k <= cw_n && gw_dyn(cw_w[k])) return -1; break }
        else if (!z && (C[i] == "o" || C[i] == "O") && ++k <= cw_n && gw_dyn(cw_w[k])) return -1
      }
      if (brk) { k++; break }
    }
    if (k <= cw_n) shc_op = k
    return c && k <= cw_n ? k : 0
  }
  # sw and cw read a string once: split(s, C, "") for its characters and split(s, P, "/") for its last
  # path part. In BWK awk, substr scans the whole string on every call, so substr per character, or
  # sub(/.*\//) on a long word, is quadratic in its length.
  # sw_q[k] is 1 when word k held a quote or a backslash.
  function sw(buf,   n, q, w, have, i, c, C, wq) {
    sw_n = 0; n = split(buf, C, ""); q = ""; w = ""; have = 0; wq = 0
    for (i = 1; i <= n; i++) {
      c = C[i]
      if (q == sq) { if (c == sq) q = ""; else w = w c; continue }
      if (q == "\"") {
        if (c == "\"") q = ""
        else if (c == "\\" && index("\"\\$`", C[i + 1])) { i++; w = w C[i] }
        else w = w c
        continue
      }
      if (c == "\\") { i++; w = w C[i]; have = 1; wq = 1; continue }
      if (c == sq || c == "\"") { q = c; have = 1; wq = 1; continue }
      if (c == " " || c == "\t" || c == "\n" || c == "\037") {
        if (have) { sw_w[++sw_n] = w; sw_q[sw_n] = wq }
        w = ""; have = 0; wq = 0; continue
      }
      # An unquoted, unescaped # that starts a word is a comment, to the newline, as in bash.
      if (c == "#" && !have) { while (i < n && index("\n\037", C[i + 1]) == 0) i++; continue }
      if ((c == "<" || c == ">" || (c == "&" && C[i + 1] == ">")) && have && w !~ /^[0-9]+$/ && w !~ /[<>&]$/) {
        sw_w[++sw_n] = w; sw_q[sw_n] = wq; w = ""; wq = 0
      }
      w = w c; have = 1
    }
    if (have) { sw_w[++sw_n] = w; sw_q[sw_n] = wq }
  }
  function cw_reset() { cw_n = 0; cw_s = 0; cw_val = 0; cw_split = 0; cw_wrap = ""; cw_dur = 0; cw_cnt = 0; cw_mod = 0; cw_rw = 0 }
  # cw_line(s): feeds cw the words of the command line s (the value of env -S), split at blanks
  # outside quotes and with the quotes removed, as env -S reads it.
  function cw_line(s,   n, C, i, c, q, w, have) {
    n = split(s, C, ""); q = ""; w = ""; have = 0
    for (i = 1; i <= n; i++) {
      c = C[i]
      if (q == sq) { if (c == sq) q = ""; else w = w c; continue }
      if (c == "\\" && i < n && (q == "" || index("\"\\$`", C[i + 1]))) { i++; w = w C[i]; have = 1; continue }
      if (q == "\"") { if (c == "\"") q = ""; else w = w c; continue }
      if (c == sq || c == "\"") { q = c; have = 1; continue }
      if (c == " " || c == "\t" || c == "\037") { if (have) cw(w); w = ""; have = 0; continue }
      w = w c; have = 1
    }
    if (have) cw(w)
  }
  function cw(x,   b, v, P) {
    if (cw_s) { cw_w[++cw_n] = x; return }
    if (cw_val) {
      cw_val = 0
      if (cw_split) { cw_split = 0; cw_line(x) }
      return
    }
    # The word after repeat is its count, whatever it looks like: zsh reads -1+2 as one. A literal
    # count of 0 or less runs the command no time; any other count but a literal one may.
    if (cw_cnt) {
      cw_cnt = 0
      if (x ~ /^-?[0-9]+$/ && x + 0 <= 0) cw_mod = 3
      else if (x !~ /^[0-9]+$/ && cw_mod < 2) cw_mod = 2
      return
    }
    if (x ~ /^[0-9]*(<|>|&>)/) { cw_val = (x ~ /^[0-9]*[<>&|]+$/); return }
    if (x ~ /^[A-Za-z_][A-Za-z0-9_]*\+?=/) return
    # zsh runs the command after its precommand modifier noglob and its reserved words nocorrect,
    # coproc and repeat with its count. cw_mod (cmd_mod): 1 when one came before the command name, 2
    # when the command may then not run in this shell, 3 when it does not: coproc runs it in a
    # subshell, and a reserved word that is quoted (cw_q, which only cmd_mod sets) or follows noglob or
    # nocorrect (cw_rw) is a command that is not found.
    if (x ~ /^(if|then|elif|else|do|while|until|!|[{])$/) { cw_wrap = ""; return }
    if (x == "noglob") { cw_wrap = ""; cw_rw = 1; if (!cw_mod) cw_mod = 1; return }
    if (x ~ /^(nocorrect|coproc|repeat)$/) {
      cw_wrap = ""
      if (x == "coproc" || cw_q || cw_rw) cw_mod = 3
      else if (!cw_mod) cw_mod = 1
      if (x == "nocorrect") cw_rw = 1
      if (x == "repeat") cw_cnt = 1
      return
    }
    # Any case: on a case-insensitive file system ENV and Sudo run env and sudo.
    b = tolower(P[split(x, P, "/")])
    if (b ~ /^(command|exec|time|nohup|sudo|env|timeout|nice)$/) { cw_wrap = b; cw_dur = (b == "timeout"); return }
    if (x ~ /^-/) {
      # env -S, after any of the flags -0 -i -v in its cluster: the line is attached or the next word.
      if (cw_wrap == "env" && x ~ /^(-[0iv]*S|--split-string=)/) {
        v = x; sub(/^(-[0iv]*S|--split-string=)/, "", v)
        if (v != "") cw_line(v); else if (x !~ /^--/) { cw_val = 1; cw_split = 1 }
        return
      }
      if (cw_wrap in cw_opt && index(cw_opt[cw_wrap], " " x " ")) { cw_val = 1; cw_split = (cw_wrap == "env" && (x == "-S" || x == "--split-string")) }
      return
    }
    if (cw_dur) { cw_dur = 0; return }
    cw_s = 1; cw_w[++cw_n] = x
  }
'

# _GW_SCAN: the quote-aware scanner that _split_words and _subst_bodies share (run with -v sq="'"). It
# reads a command with a stack of contexts, as bash and zsh do: each $( ), backtick, $(( )), $[ ], ${ },
# subscript and double quote starts a context of its own, so the quotes and parens inside one are its
# own, and only its own unquoted closer ends it. sc_init(STR) puts the characters of STR in SC[1..SN].
# sc_end(I, K, DQ) reads SC from position I inside a context of kind K (DQ: inside double quotes) and
# returns the position of the last character of the closer that ends it, or 0 when the text ends first.
# The kinds:
#   t  a whole record (_subst_bodies), which never closes.
#   c  the body of a $( ): closes at the ) that balances it. A # that starts a word is a comment to the
#      newline. case WORD in ... esac is read: the ) that ends a pattern closes no $( ), a ( before a
#      pattern is optional, and the clause commands are read (re-review concern 2). When a ${ } or $[ ]
#      in the body holds a ), bash 3.2 ends the $( ) there while bash 5.3 and zsh read on, so sc_cmd
#      prints both readings (re-review concern 3). The program defines sc_lt(I, CS) and sc_nl(I), called
#      at a << and at a newline here outside arithmetic (CS: where the simple command starts); each
#      returns the last position it read. _split_words reads here-docs with them.
#   b  the body of a backtick pair: closes at the next backtick that no backslash escapes, quoted or
#      not, as bash 3.2, bash 5.3 and zsh 5.9 all read it.
#   d  a double-quoted string: closes at the next " that no backslash escapes. A single quote is literal.
#   h  an unquoted here-doc body (_subst_bodies STR h): read as d, but a double quote is literal too and
#      nothing closes it. bash 3.2, bash 5.3 and zsh 5.9 run the $( ) in '$(cmd)' and ${x:-'$(cmd)'}
#      there, and a backtick there keeps the backslash before a " (measured).
#   e  the body of ${ }: closes at the next }, as bash reads it (all three shells give ${x:-{}a} the
#      value {a}, and bash runs the line after ${x:-{<<X}). Inside "..." a single quote is literal, which
#      is what bash and zsh run for "${x:-'...'}", and the reading that shows the guards more where they
#      differ.
#   a  the body of $(( )) or a bare (( )): arithmetic, where a single quote is literal, but the parens
#      inside one do not count, as bash finds the end (zsh counts them). Closes at the )) that ends it
#      when the ) that closes its inner ( is followed by ); returns -1 when it is not, since bash and zsh
#      then read a $( ) or ( ) around a subshell: `$((git push) )` runs git push.
#   k  the body of $[ ] or of a subscript, arithmetic too: closes at the ] that balances it. A single
#      quote is literal, and the brackets inside one do not count, as in a.
# A subscript, NAME[ ] or the [ ] in ${NAME[ ]}, is read as k only while printing (sc_sub): bash 5.3 and
# zsh run a['$(cmd)']=1. Outside an assignment NAME[ is a glob, so its brackets end nothing, and the
# context reads the subscript as its own text too.
# In a and k, sc_un is set at what bash or zsh reads in a way this scan cannot be sure of: a $ before a
# quote or {, a <<, a comment or a case, a double quote or backtick that holds a paren (in a) or a
# bracket (in k), a double quote that holds a backtick, $( ), $[ ] or ${ }, and a paren or bracket in a
# single quote. When bash finds the closing )) it skips the parens in quotes and backticks, while zsh
# counts them. Such an unsure one is read both ways (sc_dpar, sc_brk, sc_bare), so the guards never
# read less than a shell runs.
# With sc_pr set, the scan prints the body of each $( ) and backtick pair it meets outside another one,
# once per position: a backtick body with its escapes removed, as the shell runs it, and for a $( ) or
# backtick that never closes, the rest of the text. A single quote that never closes is then literal.
# Past 16 nested contexts the scan goes on flat (sc_flat), since mawk's eval stack holds about 35 nested
# $( ) here; while printing, it prints the text of such a context whole, as a body, and sets sc_cap, so
# _subst_bodies also prints a $KERN_UNREAD record that G00 denies under autopilot (re-review concern 5).
# shellcheck disable=SC2016 # awk text
_GW_SCAN='
  function sc_init(s) {
    SS = s; SN = split(s, SC, ""); sc_dep = 0; sc_pr = 0; sc_un = 0; sc_chk = ""; sc_ar = 0
    sc_q3 = 0; sc_kpar = 0; sc_cap = 0
  }
  # sc_in(set, ch): true when the character ch is one of set (BWK awk finds an empty string anywhere).
  function sc_in(set, ch) { return ch != "" && index(set, ch) > 0 }
  # sc_ws(i): true when position i starts a word.
  function sc_ws(i) { return i == 1 || sc_in(" \t\n\037;&|(", SC[i - 1]) }
  # sc_case(i): true when the word at i is case.
  function sc_case(i) {
    return SC[i] == "c" && SC[i + 1] == "a" && SC[i + 2] == "s" && SC[i + 3] == "e" && sc_in(" \t\n\037", SC[i + 4])
  }
  # sc_named(i): true when the [ at i follows a NAME that starts a word, as in an array assignment.
  function sc_named(i,   j) {
    for (j = i - 1; j >= 1 && SC[j] ~ /[A-Za-z0-9_]/; j--) ;
    return j < i - 1 && SC[j + 1] ~ /[A-Za-z_]/ && (j == 0 || sc_in(" \t\n\037;&|()", SC[j]))
  }
  # sc_put(a, b, bt, dq): prints SC[a..b] as a body, once per position; bt marks a backtick body.
  function sc_put(a, b, bt, dq,   t) {
    if ((a, b) in sc_seen) return
    sc_seen[a, b] = 1
    t = substr(SS, a, b - a + 1)
    if (bt && index(t, "\\")) t = sc_unbt(t, dq)
    print t
  }
  # sc_unbt(t, dq): the backtick body t as the shell runs it: the backslash before a \, ` or $, or
  # before a " when the backtick is inside double quotes, is removed.
  function sc_unbt(t, dq,   n, P, i, o) {
    n = split(t, P, ""); o = ""
    for (i = 1; i <= n; i++) {
      if (P[i] == "\\" && i < n && (index("\\`$", P[i + 1]) || (dq && P[i + 1] == "\""))) i++
      o = o P[i]
    }
    return o
  }
  # sc_quote(i, ansi): for the single quote at i, the position of the one that closes it; in an ANSI-C
  # quote (ansi, a $ before the quote) a backslash escapes. When none does: i while printing, so the
  # quote is read as literal, else 0.
  function sc_quote(i, ansi,   j) {
    for (j = i + 1; j <= SN; j++) {
      if (ansi && SC[j] == "\\") j++
      else if (SC[j] == sq) return j
    }
    return sc_pr ? i : 0
  }
  # sc_cmd(i, a): for the $( at i, whose body starts at a, the position of the ) that closes it, or 0.
  # Prints the body. When the body holds a ) inside a ${ } or $[ ] (sc_q3), bash 3.2 ends the $( ) there
  # while bash 5.3 and zsh read on; both readings are printed, so whatever any of the three runs is read.
  function sc_cmd(i, a,   pr, un, ck, e, q3) {
    pr = sc_pr; un = sc_un; ck = sc_chk; sc_pr = 0; sc_chk = ""
    e = sc_end(a, "c", 0); q3 = sc_q3
    sc_pr = pr; sc_un = un; sc_chk = ck
    if (pr) {
      sc_put(a, e ? e - 1 : SN, 0, 0)
      if (q3 && e > 0) { sc_put(a, q3 - 1, 0, 0); sc_put(q3 + 1, e - 1, 0, 0) }
    }
    return e
  }
  # sc_tick(i, dq): for the backtick at i, the position of the one that closes it, or 0. Prints the body.
  function sc_tick(i, dq,   pr, e) {
    pr = sc_pr; sc_pr = 0
    e = sc_end(i + 1, "b", dq)
    sc_pr = pr
    if (pr) sc_put(i + 1, e ? e - 1 : SN, 1, dq)
    return e
  }
  # sc_arith(a, k, dq): the end of the arithmetic body of kind a or k that starts at a; sc_au says
  # whether the scan was unsure. The first scan is kept per position, so nested arithmetic is not read
  # again and again. With sc_pr set the body is read a second time, to print the bodies inside it.
  function sc_arith(a, k, dq,   pr, un) {
    pr = sc_pr; un = sc_un
    if (!((k, a) in sc_m)) { sc_pr = 0; sc_un = 0; sc_m[k, a] = sc_end(a, k, dq); sc_u[k, a] = sc_un }
    if (pr && sc_m[k, a] > 0) { sc_pr = 1; sc_end(a, k, dq) }
    sc_au = sc_u[k, a]; sc_pr = pr; sc_un = un || sc_au
    return sc_m[k, a]
  }
  # sc_dpar(i, dq): for the $(( at i, the position of its last ): arithmetic when its inner ( closes
  # right before the ) that closes it, else a $( ) around a subshell. Unsure, it is read both ways, and
  # the later end counts.
  function sc_dpar(i, dq,   a, e) {
    a = sc_arith(i + 3, "a", dq)
    if (a > 0 && !sc_au) return a
    e = sc_cmd(i, i + 2)
    return a > e ? a : e
  }
  # sc_brk(i, dq): for the $[ at i, the position of the ] that closes it. Unclosed, or unsure while
  # printing, i: the context around it then reads the $[ ] as its own text too, after the bodies inside
  # are printed.
  function sc_brk(i, dq,   a) {
    a = sc_arith(i + 2, "k", dq)
    return a > 0 && !(sc_au && sc_pr) ? a : i
  }
  # sc_bare(i): for the bare (( at i, the position of the ) that closes it when it is arithmetic. Not,
  # or unsure, i: the context then reads it as two parens. sc_ba keeps the end of the arithmetic reading.
  function sc_bare(i,   a) {
    a = sc_arith(i + 2, "a", 0); sc_ba = a
    return a > 0 && !sc_au ? a : i
  }
  # sc_sub(i, dq): while printing, reads the subscript whose [ is at i as arithmetic (see k).
  function sc_sub(i, dq,   un) { if (sc_pr) { un = sc_un; sc_end(i + 1, "k", dq); sc_un = un } }
  # sc_open(i, k, dq): reads the opener at i, as a context of kind k reads it: $( ), $(( )), $[ ], ${ },
  # a backtick, a quote, an ANSI-C quote or $"...". Returns the position of its last character, i when
  # nothing opens there, or 0 when the text ends inside it.
  function sc_open(i, k, dq,   c, x, e, ck) {
    c = SC[i]; x = SC[i + 1]
    if (c == "$" && x == "(") return SC[i + 2] == "(" ? sc_dpar(i, dq) : sc_cmd(i, i + 2)
    if (c == "$" && x == "[") return sc_brk(i, dq)
    if (c == "$" && x == "{") return sc_end(i + 2, "e", dq)
    if (k == "a" || k == "k") {
      if (c != "`" && c != "\"") return i
      ck = sc_chk; sc_chk = k == "a" ? "()" : "[]"
      e = c == "`" ? sc_tick(i, dq) : sc_end(i + 1, "d", 1)
      sc_chk = ck
      return e
    }
    if (c == "`") return sc_tick(i, k == "h" ? 0 : dq)
    if (k == "d" || k == "h") return i
    if (c == "\"") return sc_end(i + 1, "d", 1)
    if (k == "e" && dq) return i
    if (c == sq) return sc_quote(i, 0)
    if (c == "$" && x == sq) return sc_quote(i + 1, 1)
    if (c == "$" && x == "\"") return sc_end(i + 2, "d", 1)
    return i
  }
  # sc_flat(i, k): the end of the context of kind k from i, read flat: its own brackets are counted,
  # and a quote or backtick is skipped to its pair, with nothing nested.
  function sc_flat(i, k,   o, z, p, c, q) {
    o = k == "e" ? "{" : k == "k" ? "[" : "("; z = k == "e" ? "}" : k == "k" ? "]" : ")"
    p = k == "a" ? 2 : 1; q = ""
    for (; i <= SN; i++) {
      c = SC[i]
      if (c == "\\") { i++; continue }
      if (q != "") { if (c == q) q = ""; continue }
      if (k == "b" || k == "d") { if (c == (k == "b" ? "`" : "\"")) return i; continue }
      if (c == sq || c == "\"" || c == "`") { q = c; continue }
      if (k == "t" || k == "h") continue
      if (c == o) p++
      else if (c == z && --p == (k == "a")) return k == "a" ? (SC[i + 1] == ")" ? i + 1 : -1) : i
    }
    return 0
  }
  function sc_end(i, k, dq,   p, c, x, e, cs, h0, r, sk, sb, cn, q3, cst) {
    if (sc_dep >= 16) {
      sc_cap = 1
      r = sc_flat(i, k)
      if (sc_pr) sc_put(i, r > 0 ? r - 1 : SN, 0, 0)
      return r
    }
    sc_dep++
    r = 0; p = k == "a" ? 2 : 1; cs = i; h0 = hn; sk = 0; sb = 0; cn = 0; q3 = 0
    if (k == "a") sc_ar++
    for (; i <= SN; i++) {
      c = SC[i]; x = SC[i + 1]
      if (c == "\\") { i++; continue }
      if (k == "b" || k == "d" || k == "h") {
        if (k != "h" && c == (k == "b" ? "`" : "\"")) { r = i; break }
        if (sc_chk != "" && (index(sc_chk, c) || (k == "d" && (c == "`" || (c == "$" && sc_in("{([", x)))))) sc_un = 1
        if (k == "b" || (c != "$" && c != "`")) continue
      } else if (k == "a" || k == "k") {
        if (c == sq) { sk = !sk; continue }
        if ((c == "$" && sc_in("{\"" sq, x)) || (c == "<" && x == "<") || (sc_ws(i) && (c == "#" || sc_case(i)))) sc_un = 1
        if (sk && sc_in("()[]", c)) sc_un = 1
        # In a single quote a double quote is text: bash skips the quote whole to find the end.
        if (sk && c == "\"") continue
        # A ) inside $[ ] (not in a single quote) is where bash 3.2 ends an enclosing $( ) (sc_kpar).
        if (k == "k" && c == ")" && !sk && !sc_kpar) sc_kpar = i
        if (!sk && c == (k == "a" ? "(" : "[")) { p++; continue }
        if (!sk && c == (k == "a" ? ")" : "]") && --p == (k == "a")) { r = k == "k" ? i : x == ")" ? i + 1 : -1; break }
      } else {
        # A subscript: sb counts the ones open here, where a << is no here-doc.
        if (c == "[" && (k == "e" || sc_named(i))) { sb++; sc_sub(i, dq); continue }
        if (c == "]" && sb) sb--
        # A ) inside ${ } is where bash 3.2 ends an enclosing $( ) (sc_kpar).
        if (k == "e" && c == ")" && !sc_kpar) sc_kpar = i
        if (k == "e" && c == "}") { r = i; break }
        if (k != "e" && c == "(" && x == "(" && sc_ws(i) && (e = sc_bare(i)) > i) { i = e; continue }
        if (k == "c") {
          # case WORD in ... esac: a ) that ends a pattern (state 2) closes no $( ), a ( before one is
          # optional, and the commands between pattern) and ;; are read (re-review concern 2). cst[cn]:
          # 1 after case (awaiting in), 2 in a pattern, 3 in a clause body; esac ends the case.
          if (sc_ws(i) && sc_case(i)) { cst[++cn] = 1; i += 3; continue }
          if (cn && cst[cn] == 1) {
            if (sc_ws(i) && c == "i" && x == "n" && sc_in(" \t\n\037;&|(", SC[i + 2])) { cst[cn] = 2; i++; continue }
          } else if (cn) {
            if (sc_ws(i) && c == "e" && SC[i + 1] == "s" && SC[i + 2] == "a" && SC[i + 3] == "c" && sc_in(" \t\n\037;&|)", SC[i + 4])) { cn--; i += 3; continue }
            if (cst[cn] == 2) {
              if (c == "(") continue
              if (c == ")") { cst[cn] = 3; continue }
            } else if (c == ";" && (x == ";" || x == "&")) cst[cn] = 2
          }
          if (c == "#" && sc_ws(i)) { while (i < SN && SC[i + 1] != "\n" && SC[i + 1] != "\037") i++; continue }
          if (c == "<" && x == "<" && !sc_ar && !sb) { i = sc_lt(i, cs); continue }
          if (c == "\n") { cs = i + 1; if (!sc_ar) i = sc_nl(i); continue }
          if (sc_in(";&|", c)) { cs = i + 1; continue }
          if (c == "(") { p++; cs = i + 1; continue }
          if (c == ")" && --p == 0) { r = i; break }
        }
        # A ${ } or $[ ] whose body holds a ) (sc_kpar): bash 3.2 ends this $( ) at that ), the others
        # read on. q3 keeps the first such ), so sc_cmd prints both readings.
        if (k == "c" && c == "$" && (x == "{" || x == "[")) {
          sc_kpar = 0
          if (!(e = sc_open(i, k, dq))) break
          if (sc_kpar && !q3) q3 = sc_kpar
          i = e; continue
        }
      }
      if (c == "$" || c == "`" || c == "\"" || c == sq) {
        if (!(e = sc_open(i, k, dq))) break
        i = e
      }
    }
    if (k == "a") sc_ar--
    if (hn > h0) hn = h0
    sc_dep--
    sc_q3 = k == "c" ? q3 : sc_q3
    return r
  }
'

# git_words CMD: one simple command per line. Splits on ; & && || | ( ), the words { and }, and
# newlines outside quotes, backticks and $( ); a redirection (2>&1, &>, >|) never splits, and a
# backslash-newline is dropped. Here-doc bodies are data: they are left out, but the bodies of the $( )
# and backticks in an unquoted body are read as commands (see _split_words); the body itself is never a
# record. The script of an sh-family shell's -c (any path, any option form, as shc reads it by the rules
# of bash and of zsh, after the wrappers and keywords _cmd_words skips), the arguments of `eval`, a
# `trap` handler, and the bodies of $( ) and backticks are split again and printed after their wrapper,
# so a command inside a string is still seen. When an awk pass errors, git_words emits a $KERN_UNREAD
# record and keeps the records it has; G00 denies that record under autopilot, so it is the backstop.
# Only a _split_words failure also reaches git_words' exit status (the false after the inner awk pass
# and inside _subst_bodies is masked by the while loops around them), so a guard that reads git_words
# under `set -o pipefail` fails closed on it too: G00 denies and G15 asks. G13 reads git_words through a
# here-doc without pipefail, so on such a failure it sees only the $KERN_UNREAD record and votes nothing;
# G00 is the backstop there. Out of scope here: commands that xargs or find -exec run (G1 and G2 ask for
# a git or gh among their words), and a here-doc piped into a shell (cat <<EOF | sh).
git_words() {
  local seg inner body first hm=$'\036' qm=$'\035' forged=0
  # hm starts an unquoted here-doc body record from _split_words, and qm a quoted body on G00s call
  # (_GW_QB). A command that holds either byte itself could forge one, so its marked records are then
  # also read as ordinary records.
  case "$1" in *"$hm"* | *"$qm"*) forged=1 ;; esac
  # With aliases loaded (aliases.sh), the outermost call prints the command's own records exactly as
  # without aliases, in their order, then every expansion record after all of them. Inner calls mark an
  # expansion record with a leading tab, which no record of the command starts with (_split_words trims
  # blanks). So an expansion never changes the context a record of the command is read in, such as a
  # cd before it: it can only add votes.
  if [ -z "${_GW_IN-}" ] && [ -n "${KERN_ALIASES-}" ]; then
    _GW_IN=1 git_words "$1" | LC_ALL=C awk '/^\t/ { a[++n] = substr($0, 2); next } { print } END { for (i = 1; i <= n; i++) print a[i] }'
    return
  fi
  _split_words "$1" | while IFS= read -r seg; do
    # An unquoted here-doc body: only the bodies of its $( ) and backticks are commands, read as the shell
    # expands the body (_subst_bodies kind h); the body itself is data, so it is not printed.
    case "$seg" in
      "$hm"*)
        _subst_bodies "${seg#"$hm"}" h | while IFS= read -r body; do
          if [ -n "$body" ]; then git_words "${body//$_GW_NL/$'\n'}"; fi
        done
        [ "$forged" = 1 ] || continue
        ;;
      # A quoted here-doc body, emitted only on G00s call: printed as it is for G00 to scan for an array
      # subscript, and never read for commands, since the shell expands nothing in it.
      "$qm"*) if [ "$forged" = 0 ]; then printf '%s\n' "$seg"; continue; fi ;;
    esac
    printf '%s\n' "$seg"
    # A record whose head word is an alias that runs git or gh (aliases.sh) is judged as its expansion
    # too, split again and marked for the outermost call to print last. A guard that allows only a
    # command whose first record starts with git or gh never allows an alias. The expansion's own words
    # are not expanded again: zsh does not re-expand the alias it is expanding, and the table already
    # followed the head-word chain.
    if [ -z "${_GW_NOALIAS-}" ] && declare -F alias_expand >/dev/null && alias_expand "$seg"; then
      _GW_NOALIAS=1
      git_words "$ALIAS_EXP" | LC_ALL=C sed $'s/^/\t/'
      _GW_NOALIAS=
    fi
    # shellcheck disable=SC2016 # a literal $( in the text
    case "$seg" in
      *'$('* | *'`'*)
        _subst_bodies "$seg" | while IFS= read -r body; do
          if [ -n "$body" ]; then git_words "${body//$_GW_NL/$'\n'}"; fi
        done
        ;;
    esac
    # The wrapper pass costs a process, so it runs only when the first word, quotes removed,
    # is a redirection, an assignment, a keyword, a zsh precommand modifier, a wrapper, eval or a
    # shell. A wrapper or shell name matches in any case, as _cmd_words reads it.
    # One tr pass strips the quotes, and only when the word holds one: ${first//[...]/} is cubic in
    # the word's length on bash 3.2 in a UTF-8 locale.
    first=${seg%%[[:space:]]*}
    case "$first" in *[\"\'\\]*) first=$(printf '%s' "$first" | LC_ALL=C tr -d "\"'\\\\") ;; esac
    case "/$first" in
      *'<'* | *'>'* | *=* | */if | */then | */elif | */else | */do | */while | */until | */'!' | */'{' | \
        */noglob | */nocorrect | */coproc | */repeat | \
        */[Ee][Vv][Aa][Ll] | */[Cc][Oo][Mm][Mm][Aa][Nn][Dd] | */[Ee][Xx][Ee][Cc] | */[Tt][Ii][Mm][Ee] | \
        */[Nn][Oo][Hh][Uu][Pp] | */[Ss][Uu][Dd][Oo] | */[Ee][Nn][Vv] | */[Tt][Ii][Mm][Ee][Oo][Uu][Tt] | \
        */[Nn][Ii][Cc][Ee] | */[Ss][Hh] | */[Bb][Aa][Ss][Hh] | */[Zz][Ss][Hh] | */[Dd][Aa][Ss][Hh] | \
        */[Tt][Rr][Aa][Pp]) ;;
      *) continue ;;
    esac
    # One line per inner command line: the words after eval, a trap handler, or each script shc finds,
    # read by the rules of bash and of zsh. Each is split on its own, so one cannot quote the other away.
    # The awk pass fails closed ($KERN_UNREAD, which G00 denies) if it ever errors; its false is masked by
    # the while loop below, so only the record reaches git_words' caller.
    { printf '%s' "$seg" | LC_ALL=C awk -v sq="'" "$_GW_AWK"'
      { buf = buf (NR > 1 ? "\037" : "") $0 }
      END {
        sw(buf); cw_reset(); for (k = 1; k <= sw_n; k++) cw(sw_w[k])
        if (!cw_n) exit
        b = tolower(P[split(cw_w[1], P, "/")])
        if (b == "eval") { for (k = 2; k <= cw_n; k++) out = out (k > 2 ? " " : "") cw_w[k]; print out; exit }
        # trap HANDLER SIGSPEC... runs the handler as code at the trap; its first non-option word is the
        # handler, quotes removed. bash, zsh, bash 3.2 all run it (measured).
        if (b == "trap") { for (k = 2; k <= cw_n; k++) if (cw_w[k] !~ /^-/) { print cw_w[k]; break }; exit }
        if (b !~ /^(ba|z|da)?sh$/) exit
        s = shc(1, 0); t = shc(1, 1)
        if (s > 0) print cw_w[s]
        if (t > 0 && t != s) print cw_w[t]
      }' || { printf '%s\n' '$KERN_UNREAD'; false; }
    } | while IFS= read -r inner; do
      if [ -n "$inner" ]; then git_words "${inner//$_GW_NL/$'\n'}"; fi
    done
  done
}

# _subst_bodies STR: the body of each outermost $( ) and backtick pair, one per line, as the scanner
# (_GW_SCAN) finds them, at any depth of quotes, ${ } and arithmetic. A $(( )), a $[ ], a subscript and
# a bare (( )) arithmetic command are arithmetic, not commands: in their place come the bodies of the
# $( ) and backtick pairs inside them, with a single quote read as literal text. Any other $(( is a $( )
# around a subshell; one the scanner is unsure of gives both readings. With a second argument h, STR is
# an unquoted here-doc body and is read as one (kind h): its quotes are literal text.
# An awk error prints $KERN_UNREAD; the false after it is masked by the while loop that reads this
# output in git_words, so only the record, not the exit status, reaches git_words' caller.
_subst_bodies() {
  printf '%s' "$1" | LC_ALL=C awk -v sq="'" -v kd="${2:-t}" "$_GW_SCAN"'
    function sc_lt(i, cs) { return i }
    function sc_nl(i) { return i }
    { buf = buf (NR > 1 ? " " : "") $0 }
    # Past the nesting limit the scan goes flat and may miss a command, so it fails closed: it prints a
    # $KERN_UNREAD record, which G00 denies under autopilot, on top of every body it did find (concern 5).
    END { sc_init(buf); sc_pr = 1; sc_end(1, kd, kd == "h"); if (sc_cap) print "$KERN_UNREAD" }' ||
    { printf '%s\n' '$KERN_UNREAD'; false; }
}

# _split_words STR: the simple commands of STR, one record per line (see git_words). The scanner
# (_GW_SCAN) reads each quote, backtick, $( ), $(( )), $[ ], ${ }, ANSI-C quote, $"..." and subscript
# whole, so only a separator outside all of them ends a record. A here-doc (<<WORD, <<-WORD, <<'WORD',
# <<"WORD") is read at the newline that ends its command line: the body up to the closing WORD line is
# skipped. At the top level the body and closing line are dropped; inside $( ) the closing line is kept,
# so the record still parses the same when split again. An unquoted delimiter (<<WORD, <<-WORD) leaves
# its body subject to command substitution, so hbody emits a body that holds a $( ) or backtick as a
# record that starts with a \036 byte; git_words does not print it, and reads it with _subst_bodies as a
# here-doc body, so only the bodies of its $( ) and backticks become records. A quoted delimiter
# (<<'WORD', <<"WORD", <<\WORD) keeps the body literal and unread. The body of a here-doc that sh, bash, zsh or
# dash reads as its script (no -c) is kept as commands. A `<<` is never a here-doc inside $(( )) or
# (( )), inside ${ }, $[ ] or a NAME[ ] subscript (an array assignment), in a comment, or when its $( )
# closes before the newline; and a here-doc with no closing line skips nothing. So a misread `<<` cannot
# hide the commands after it. A comment at the top level runs to its newline. A quote or context that
# never closes keeps the rest of the text in its record; that text is then read flat too, split at each
# separator, quoted or not, so a quote the scanner misreads cannot hide the commands after it.
_split_words() {
  printf '%s' "$1" | LC_ALL=C awk -v sq="'" -v qb="${_GW_QB-}" "$_GW_AWK$_GW_SCAN"'
    # emit(s): prints the record s. In the flat reading (fl) a record printed already is left out.
    function emit(s) {
      gsub(/\\\n/, "", s); gsub(/^[ \t\n]+|[ \t\n]+$/, "", s)
      if (fl && (s in seen)) return
      seen[s] = 1; gsub(/\n/, "\037", s)
      if (s != "") print s
    }
    function sep(ch) { return ch == "" || index(" \t\n;&|()", ch) > 0 }
    # rec(a, b): the text from position a to b - 1, without the here-doc bodies dropped in it.
    function rec(a, b,   s, j) {
      s = ""
      for (j = 1; j <= dn; j++) {
        if (db[j] < a || da[j] >= b) continue
        s = s substr(buf, a, da[j] - a); a = db[j] + 1
      }
      return s substr(buf, a, b - a)
    }
    # cut(e): emits the record gathered so far, up to position e - 1.
    function cut(e) { emit(rec(start, e)) }
    # flat(j): from j on, emits the records split at every ; & | ( ) and newline that no backslash
    # escapes, quoted or not, but those emitted already.
    function flat(j,   a) {
      fl = 1
      for (a = j; j <= n + 1; j++) {
        if (SC[j] == "\\") { j++; continue }
        if (j <= n && !index(";&|()\n", SC[j])) continue
        emit(substr(buf, a, j - a)); a = j + 1
      }
    }
    # hdat(j): true when the `<` at j opens a here-doc operator (`<<`, not `<<<`) where one can start.
    function hdat(j) { return !ta && !sb && SC[j + 1] == "<" && SC[j + 2] != "<" && SC[j - 1] != "<" }
    # shellin(t): true when the simple command t is sh, bash, zsh or dash and no reading of shc finds
    # a -c script it runs, so a here-doc it reads is its script.
    function shellin(t,   k, b, P) {
      sw(t); cw_reset()
      for (k = 1; k <= sw_n; k++) cw(sw_w[k])
      if (!cw_n) return 0
      b = P[split(cw_w[1], P, "/")]
      if (tolower(b) !~ /^(ba|z|da)?sh$/) return 0
      return shc(1, 0) <= 0 && shc(1, 1) <= 0
    }
    # heredoc(j): queues the delimiter word that starts at j, after a `<<`, quotes removed. The word
    # ends at a blank, an operator, a newline or the end of input, even inside a quote; a quote
    # still open there means the `<<` was quoted text, and nothing is queued. Scanning resumes
    # after the `<<` either way, so the word itself is read as ordinary text.
    function heredoc(j,   d, wq, ch, dash, qd) {
      dash = 0; qd = 0
      if (substr(buf, j, 1) == "-") { dash = 1; j++ }
      while (j <= n && index(" \t", substr(buf, j, 1))) j++
      d = ""; wq = ""
      for (; j <= n; j++) {
        ch = substr(buf, j, 1)
        if (ch == "\n") break
        if (wq != "") { if (ch == wq) wq = ""; else d = d ch; continue }
        if (ch == sq || ch == "\"") { wq = ch; qd = 1; continue }
        if (ch == "\\") { j++; d = d substr(buf, j, 1); qd = 1; continue }
        if (index(" \t;&|<>()", ch)) break
        d = d ch
      }
      # qd marks a quoted or backslashed delimiter (<<'"'"'EOF'"'"', <<"EOF", <<\EOF): its body stays
      # literal, so nothing in it is expanded and hbody leaves it unread.
      if (wq == "" && d != "") { hd[++hn] = d; hx[hn] = dash; hq[hn] = qd }
    }
    # hbody(a): after bodies() set last[1..nh], emits the body of each unquoted here-doc that holds a
    # $( ) or backtick, after a \036 byte, so git_words reads the command substitutions the shell expands
    # in it and never the body itself as a command. A quoted body is data and is skipped, except that on
    # G00s call (qb, from _GW_QB) one that holds a [ and a $( or backtick is emitted after a \035 byte,
    # for G00 to scan for an array subscript the body may store for arithmetic. a is the position just
    # after the operator line, where the first body starts.
    function hbody(a,   h, s) {
      for (h = 1; h <= nh; h++) {
        s = substr(buf, a, off[last[h]] - a)
        if (!hq[h]) { if (index(s, "$(") || index(s, "`")) emit("\036" s) }
        else if (qb && index(s, "[") && (index(s, "$(") || index(s, "`"))) emit("\035" s)
        a = off[last[h]] + length(L[last[h]]) + 1
      }
    }
    # bodies(j): at the newline j, finds the closing line of each queued here-doc and clears the
    # queue. Returns the line number of the last closing line, or 0 when one is missing.
    function bodies(j,   h, k, t) {
      while (lp > 1 && off[lp] > j) lp--
      while (lp < NR && off[lp + 1] <= j) lp++
      k = lp; nh = hn; hn = 0
      for (h = 1; h <= nh; h++) {
        for (k++; k <= NR; k++) { t = L[k]; if (hx[h]) sub(/^\t+/, "", t); if (t == hd[h]) break }
        if (k > NR) return 0
        last[h] = k
      }
      return k
    }
    # sc_lt(j, cs): the scanner hook at a << at j inside $( ), where cs starts the simple command. A
    # here-doc operator (not <<<) queues its delimiter, unless the command is a shell that reads the
    # here-doc as its script. Returns the last position it read.
    function sc_lt(j, cs) {
      if (SC[j + 2] == "<" || SC[j - 1] == "<") return j
      if (!shellin(substr(buf, cs, j - cs))) heredoc(j + 2)
      return j + 1
    }
    # sc_nl(j): the scanner hook at the newline j inside $( ): drops the bodies of the here-docs queued
    # before it (da[], db[]) and keeps their closing lines. Returns the last position it read.
    function sc_nl(j,   k, h, a) {
      if (!hn || !(k = bodies(j))) return j
      hbody(j + 1)
      a = j + 1
      for (h = 1; h <= nh; h++) { da[++dn] = a; db[dn] = off[last[h]] - 1; a = off[last[h]] + length(L[last[h]]) + 1 }
      return off[k] + length(L[k]) - 1
    }
    { L[NR] = $0; buf = buf (NR > 1 ? "\n" : "") $0 }
    # cs: where the current simple command starts. ta: inside (( )) at the top level. sb: the NAME[ ]
    # subscripts open at the top level. es: the last backslash-escaped position. da[1..dn], db[]: the
    # here-doc bodies dropped inside $( ) (sc_nl).
    END {
      n = length(buf); sc_init(buf); start = 1; cs = 1; i = 1; hn = 0; lp = 1; off[1] = 1
      ta = 0; sb = 0; es = 0; dn = 0
      for (k = 2; k <= NR; k++) off[k] = off[k - 1] + length(L[k - 1]) + 1
      while (i <= n) {
        c = SC[i]; p = SC[i - 1]; x = SC[i + 1]
        if (c == "\\") { if (x != "\n") es = i + 1; i += 2; continue }
        if (c == sq || c == "\"" || c == "`" || c == "$") {
          e = sc_open(i, "c", 0)
          if (e > i) { i = e + 1; continue }
          if (!e) break
          i++; continue
        }
        if (c == "[" && sc_named(i)) sb++
        else if (c == "]" && sb) sb--
        if (c == "<" && hdat(i)) {
          if (!shellin(substr(buf, cs, i - cs))) heredoc(i + 2)
          i += 2; continue
        }
        if ((c == "&" && (p == ">" || p == "<" || x == ">")) || (c == "|" && p == ">")) { i++; continue }
        # Not after an escaped blank or operator.
        if (c == "#" && (i == 1 || (sep(p) && i - 1 != es))) {
          e = index(substr(buf, i), "\n")
          i = e ? i + e - 1 : n + 1
          continue
        }
        # A bare (( )) arithmetic command stays in its record whole, so _subst_bodies reads its body in
        # arithmetic mode (a single quote there is literal). A subshell ((cmd) ) splits; one the scanner
        # is unsure of splits, and its arithmetic reading is a record of its own too.
        if (c == "(" && x == "(") {
          if ((e = sc_bare(i)) > i) { i = e + 1; continue }
          if (sc_ba > 0) emit(substr(buf, i, sc_ba - i + 1))
        }
        if (c == "(" && x == "(") ta = 1
        else if (c == ")" && x == ")") ta = 0
        if ((c == "{" || c == "}") && (i == 1 || sep(p)) && sep(x)) {
          cut(i)
          start = cs = i + 1
        } else if (c == ";" || c == "\n" || c == "&" || c == "|" || c == "(" || c == ")") {
          cut(i)
          if ((c == "&" || c == "|") && x == c) i++
          start = cs = i + 1
          if (c == "\n" && hn && (k = bodies(i))) { hbody(i + 1); i = off[k] + length(L[k]); start = cs = i + 1 }
        }
        i++
      }
      cut(n + 1)
      # A quote or context that never closes (at i) holds the rest of the text, in the record just cut.
      # That text is then read again flat, so a quote the scanner misreads hides nothing after it.
      if (i <= n) flat(start)
    }' || { printf '%s\n' '$KERN_UNREAD'; false; }
  # On an awk error the $KERN_UNREAD record is printed and the false is the status this function
  # returns, which git_words' pipeline carries to its own exit under a caller's pipefail.
}

# _shell_words STR: the words of one simple command, quotes removed, one per line. A newline
# inside quotes stays in its word as \037 (git_words' in-record newline). An unquoted <, >, &> run
# starts a new word unless it follows an fd number or another operator: `main>/dev/null` gives
# `main` and `>/dev/null`, while `2>&1` stays whole.
_shell_words() {
  printf '%s' "$1" | LC_ALL=C awk -v sq="'" "$_GW_AWK"'
    { buf = buf (NR > 1 ? "\037" : "") $0 }
    END { sw(buf); for (k = 1; k <= sw_n; k++) print sw_w[k] }'
}

# _cmd_words CMDLINE: the words of a simple command from its command name on, one per line.
# Skips leading redirections (and the target of one that stands alone), VAR=value and VAR+=value
# words, the keywords if then elif else do while until ! {, zsh's noglob, nocorrect and coproc, repeat
# and the word after it (its count), the wrappers command, exec, time, nohup, sudo, env, timeout and
# nice (any path, any case), and their options. The options in `cw_opt` take a
# value as the next word (`--opt=value` is one word); timeout's duration follows its options; the
# value of env -S or --split-string, attached or not and after the flags -0 -i -v in a cluster, is a
# command line, read as words. Any other option `cw_opt` does not list (a cluster such as -iC, a
# prefix such as --ch) takes no value, so the word after it is read as the command name; G1 and G2
# still ask for a later git or gh.
_cmd_words() {
  printf '%s' "$1" | LC_ALL=C awk -v sq="'" "$_GW_AWK"'
    { buf = buf (NR > 1 ? "\037" : "") $0 }
    END { sw(buf); cw_reset(); for (k = 1; k <= sw_n; k++) cw(sw_w[k]); for (k = 1; k <= cw_n; k++) print cw_w[k] }'
}

# cmd_mod CMDLINE: whether the command _cmd_words finds in CMDLINE runs in this shell, read from what it
# skips before the command name (noglob, nocorrect, coproc, repeat and its count; a modifier word after
# the name, such as an argument, a redirect target or a comment, does not count). Exit 0 when it does
# not: coproc runs it in a subshell, repeat 0 runs it no time, and zsh does not find a quoted reserved
# word, or one after noglob or nocorrect, as a command. Exit 2 when it may not (a repeat count that is
# not a literal number), and 1 when it does. G1, G5 and G6 count a cd as a move unless it exits 0; G16
# and G20 follow only a plain cd (cmd_plain). The awk runs only when the text could hold one of these
# words.
cmd_mod() {
  case "$1" in *noglob* | *nocorrect* | *coproc* | *repeat* | *[\"\'\\]*) ;; *) return 1 ;; esac
  printf '%s' "$1" | LC_ALL=C awk -v sq="'" "$_GW_AWK"'
    { buf = buf (NR > 1 ? "\037" : "") $0 }
    END {
      sw(buf); cw_reset()
      for (k = 1; k <= sw_n; k++) { cw_q = sw_q[k]; cw(sw_w[k]) }
      exit cw_mod == 3 ? 0 : cw_mod == 2 ? 2 : 1
    }'
}

# cmd_plain CMDLINE: exit 0 when the command name of CMDLINE is cd, pushd or popd as written, with only
# assignments and redirections before it. G16 and G20 follow such a cd and no other: a cd behind a zsh
# modifier or reserved word (noglob, nocorrect, coproc, repeat, time, !, if and the like) or a wrapper
# (command, builtin, exec, nice, nohup, env, timeout, sudo) may run in a subshell, run a /usr/bin/cd that
# never moves the shell, or not run at all, and kern does not model each of those as zsh does. On such a
# cd, G16 keeps its readings and adds the target's (its union), and G20 judges from both directories. G1,
# G5 and G6 judge where git would run without a move as well, so they count such a cd as a move.
cmd_plain() {
  case "$1" in cd | cd[[:space:]]* | pushd | pushd[[:space:]]* | popd | popd[[:space:]]*) return 0 ;; esac
  printf '%s' "$1" | LC_ALL=C awk -v sq="'" "$_GW_AWK"'
    { buf = buf (NR > 1 ? "\037" : "") $0 }
    END {
      sw(buf)
      for (k = 1; k <= sw_n; k++) {
        x = sw_w[k]
        # A quoted or escaped word is a command name, never an assignment or a redirect: zsh runs a
        # quoted X=1 as a command. An assignment with a quoted value is read as one too, which only
        # makes the cd a maybe.
        if (!sw_q[k] && x ~ /^[0-9]*(<|>|&>)/) { if (x ~ /^[0-9]*[<>&|]+$/) k++; continue }
        if (!sw_q[k] && x ~ /^[A-Za-z_][A-Za-z0-9_]*\+?=/) continue
        exit x !~ /^(cd|pushd|popd)$/
      }
      exit 1
    }'
}

# git_sub CMDLINE: for a simple git command prints `<dir>\t<subcommand>\t<rest>`. Exit 1 when the
# command is not git. What _cmd_words skips comes first. The global options are those of git 2.54,
# the table G1 reads (_g01_git_rec); those that take a value take the next word unless it is
# attached with =. Only -C moves `dir`.
git_sub() {
  local w=() t i=1 n dir="${CWD:-$PWD}" rest=""
  while IFS= read -r t; do w+=("$t"); done <<EOT
$(_cmd_words "$1")
EOT
  n=${#w[@]}
  # Any case: on a case-insensitive file system GIT runs git.
  case "${w[0]}" in [Gg][Ii][Tt] | */[Gg][Ii][Tt]) ;; *) return 1 ;; esac
  while [ "$i" -lt "$n" ]; do
    case "${w[$i]}" in
      -C)
        t="${w[$((i + 1))]-}"
        case "$t" in /*) dir="$t" ;; *) dir="$dir/$t" ;; esac
        i=$((i + 2))
        ;;
      -c | --config-env | --git-dir | --work-tree | --namespace | --super-prefix | --attr-source) i=$((i + 2)) ;;
      --config-env=* | --git-dir=* | --work-tree=* | --namespace=* | --super-prefix=* | --attr-source=* | \
        --exec-path=* | -p | -P | --paginate | --no-pager | --bare | --no-replace-objects | --no-lazy-fetch | \
        --no-optional-locks | --no-advice | --literal-pathspecs | --glob-pathspecs | --noglob-pathspecs | \
        --icase-pathspecs) i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  [ "$i" -lt "$n" ] || return 1
  t="${w[$i]}"
  i=$((i + 1))
  while [ "$i" -lt "$n" ]; do
    rest="${rest:+$rest }${w[$i]}"
    i=$((i + 1))
  done
  printf '%s\t%s\t%s\n' "$dir" "$t" "$rest"
}

# cmd_head CMDLINE: the first two words of a simple command after what _cmd_words skips.
cmd_head() {
  _cmd_words "$1" | awk '
    { out = out (n++ ? " " : "") $0; if (n == 2) exit }
    END { print out }'
}

# in_main_checkout DIR: exit 0 when DIR is inside the main worktree (not a linked worktree).
in_main_checkout() {
  local top main
  top=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) || return 1
  main=$(kern_main_root "$1") || return 1
  [ "$(cd "$top" && pwd -P)" = "$(cd "$main" && pwd -P)" ]
}

# current_branch DIR: the branch HEAD points to, without refs/heads/. Read by symbolic-ref:
# rev-parse --abbrev-ref prints heads/<name> when a tag has the same name. Exit 1, printing
# nothing, on a detached HEAD.
current_branch() {
  local r
  r=$(git -C "$1" symbolic-ref -q HEAD 2>/dev/null) || return 1
  printf '%s\n' "${r#refs/heads/}"
}

# base_branch_name: settings base_branch, else origin/HEAD. Exit 1 when neither resolves.
base_branch_name() {
  local b
  if b=$(settings_get base_branch) && [ -n "$b" ]; then
    printf '%s\n' "$b"
    return 0
  fi
  b=$(git -C "${KERN_MAIN:-${CWD:-$PWD}}" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null) || return 1
  printf '%s\n' "${b#origin/}"
}

# branch_protected BRANCH: the settings base_branch, the origin/HEAD branch, branch.protected or
# deploy.envs. With no origin/HEAD, main, master, trunk and develop count as protected. A base_branch
# only adds a branch, so a committed one cannot unprotect main. `*` (every branch, from
# push_targets) is protected too, and so is every branch while a settings layer that could name one
# cannot be read (settings_get exit 4).
branch_protected() {
  local b k
  [ "$1" = "*" ] && return 0
  for k in base_branch branch.protected deploy.envs; do
    b=$(settings_get "$k" '')
    [ $? = 4 ] && return 0
    case "$k" in
      base_branch) [ -n "$b" ] && [ "$1" = "$b" ] && return 0 ;;
      *) list_has "$b" "$1" && return 0 ;;
    esac
  done
  if b=$(git -C "${KERN_MAIN:-${CWD:-$PWD}}" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null); then
    [ "$1" = "${b#origin/}" ] && return 0
  else
    case "$1" in main | master | trunk | develop) return 0 ;; esac
  fi
  return 1
}

# push_targets DIR REST: remote branch names a `git push` writes, one per line. `:x`, `-d x` and
# `--delete x` print `x`; `refs/heads/` and `heads/` are stripped; `HEAD` and `@` name the current
# branch. --all, --mirror, --branches and a refspec holding `*` print `*`. Redirections (2>&1,
# >file, `> file`, glued as in main>file) are skipped. No refspec means the current branch.
push_targets() {
  local dir="$1" w=() t r i=0 n pos=0 any=0
  while IFS= read -r t; do [ -n "$t" ] && w+=("$t"); done <<EOT
$(_shell_words "$2")
EOT
  n=${#w[@]}
  while [ "$i" -lt "$n" ]; do
    t="${w[$i]}"
    i=$((i + 1))
    case "$t" in
      '<'* | '>'* | '&>'* | [0-9]*'>'* | [0-9]*'<'*)
        # An operator with no target attached (`>`, `2>`) takes the next word as its target.
        r=${t#"${t%%[!0-9]*}"}
        r=${r#"${r%%[!<>&|]*}"}
        [ -n "$r" ] || i=$((i + 1))
        continue
        ;;
      --all | --mirror | --branches) any=1; printf '*\n'; continue ;;
      --repo | --push-option | -o | --receive-pack | --exec) i=$((i + 1)); continue ;;
      -*) continue ;;
    esac
    pos=$((pos + 1))
    [ "$pos" -eq 1 ] && continue
    any=1
    case "$t" in *'*'*) printf '*\n'; continue ;; esac
    t=${t#+}
    case "$t" in
      *:*) t=${t#*:} ;;
    esac
    case "$t" in HEAD | @) t=$(current_branch "$dir") ;; esac
    case "$t" in refs/heads/*) t=${t#refs/heads/} ;; heads/*) t=${t#heads/} ;; esac
    printf '%s\n' "$t"
  done
  [ "$any" = 1 ] || current_branch "$dir"
}

# with_timeout SECS CMD...: runs CMD, killing it after SECS seconds. Returns CMD's exit code. The
# watchdog kills CMD's children first (with pkill, when present), so a grandchild such as `sleep`
# cannot hold the caller's $( ) pipe open after CMD dies.
with_timeout() {
  local secs="$1" pid w rc
  shift
  "$@" &
  pid=$!
  (sleep "$secs" && { command -v pkill >/dev/null && pkill -P "$pid"; kill "$pid"; }) >/dev/null 2>&1 &
  w=$!
  wait "$pid"
  rc=$?
  pkill -P "$w" >/dev/null 2>&1
  kill "$w" >/dev/null 2>&1
  wait "$w" 2>/dev/null
  return "$rc"
}

# gh_sub CMDLINE: for `gh <group> <verb> ...` prints `<group> <verb>`; exit 1 for anything else.
# What _cmd_words skips comes first. The command is gh by its basename in any case (a path, or GH
# on a case-insensitive file system), as G1 reads it. `-R <repo>`, `-R<repo>`, `--repo <repo>` and
# `--repo=<repo>` before the group or the verb are skipped: gh reads them there too.
gh_sub() {
  local out
  out=$(_cmd_words "$1" | awk '
    NR == 1 { b = P[split($0, P, "/")]; if (tolower(b) != "gh") exit; next }
    skip { skip = 0; next }
    $0 == "-R" || $0 == "--repo" { skip = 1; next }
    /^-R./ || /^--repo=/ { next }
    { w[++n] = $0; if (n == 2) exit }
    END { if (n == 2) print w[1] " " w[2]; else if (n == 1) print w[1] }')
  [ -n "$out" ] || return 1
  printf '%s\n' "$out"
}

# word_value WORDS FLAG...: the value after the first of FLAG in the newline-separated WORDS
# (`--flag value` or `--flag=value`). Exit 1 when absent.
word_value() {
  local words="$1" w prev="" f
  shift
  while IFS= read -r w; do
    for f in "$@"; do
      if [ "$prev" = "$f" ]; then printf '%s\n' "$w"; return 0; fi
      case "$w" in "$f="*) printf '%s\n' "${w#"$f"=}"; return 0 ;; esac
    done
    prev="$w"
  done <<EOT
$words
EOT
  return 1
}

# word_has WORDS FLAG...: exit 0 when any FLAG is one of the newline-separated WORDS.
word_has() {
  local words="$1" w f
  shift
  while IFS= read -r w; do
    for f in "$@"; do [ "$w" = "$f" ] && return 0; done
  done <<EOT
$words
EOT
  return 1
}
