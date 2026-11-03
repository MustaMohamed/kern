# shellcheck shell=bash
# G21 local deletes: rm, rmdir, unlink, shred, their GNU g names and find -delete get no vote when every
# target resolves inside the command's worktree (not its top, not .git) or a scratch directory ($TMPDIR,
# /tmp, /private/tmp, WORK/tmp). Any other target, or one kern cannot resolve, asks, and autopilot turns
# the ask into a denial. No policy key loosens it, and it never votes allow. A run removes a file on its
# own branch as ordinary work; delete is on the stop list everywhere else.
# The words of each simple command come from _cmd_words, as for G15, and any word may name a tool
# (basename, lower case), so an unknown wrapper, xargs or find -exec cannot hide it. The cost: a tool
# named as a plain word judges the words after it, so `ls rm` asks; only the read path in _G21_AWK never
# votes. Quoted text stays one word, except where it may be a command line: each later word after ssh,
# watch, or the -c of sh, bash, zsh, dash, su or script behind another command, and, outside git and gh
# heads, a word with a blank whose command position names a tool. Those are split, their quotes dropped.
# A target is unresolved when it holds a variable other than $TMPDIR, a leading ~ or =, a brace list, a
# [ ] glob, a * or ? before its last part, a last part that can match .., or a ( in its simple command.
# The worktree top is that of the call's cwd: the payload's, or the directory of an opening cd to a
# literal absolute path in a linked worktree, since a subagent's shell starts at the main checkout. That
# cd adds no reading of its own. Symlinks are followed through the part of a path that exists, so a
# link that points out of the worktree is outside. Any git worktree but this one is
# outside, and so is a directory that holds a worktree, but for the main checkout seen from a worktree
# nested in it. A cd adds its target to the directories a relative path is read from, whatever its place
# in the text, and each reading must pass, since kern cannot tell what a subshell undoes. A cd kern
# cannot follow, a directory option and a link or move in the command leave no relative target.
# No top is named when core.worktree is set or, under a go, when the command's repository is not the
# go's. No WORK/tmp is named when a link moves it. A scratch path under the directory that holds the
# main checkout is outside, unless that directory is a scratch root.
# Out of scope (accepted limits): other ways to delete (mv, ln, git clean, rsync --delete, tar
# --remove-files, a file redirect, a shell script file, a script in another language), an alias or
# function of the shell, a script that the command sources and that sets TMPDIR, and a case fold outside
# ASCII. Each call is judged alone, so G21 does not trace what an earlier call placed in a scratch
# directory: the design's rule on deletes, held in model text, covers that. With a cwd in the main
# checkout the worktree is the main checkout, as for any session there. A quoted first root or primary
# value of find is not read at run time. A subagent or session that opens with a cd into a sibling
# worktree deletes there with no vote, as a session in that worktree does.

# _G21_TOOLS and _G21_FINDS: the delete tools and the finds, the one list the judge and _g21_paren read.
_G21_TOOLS='rm rmdir unlink shred grm grmdir gunlink gshred'
_G21_FINDS='find gfind'

# _G21_AWK: the judge, run on git_words records after _GW_AWK. Prints one line per fact, in record order:
# `T<TAB>word` a target to resolve, `C<TAB>word` a cd to a literal directory, `M` a cd kern cannot follow,
# `O` a git directory set in the environment, `L` a link or move, `X<TAB>text` a delete kern cannot judge,
# and `.` at the end.
# shellcheck disable=SC2016 # awk text
_G21_AWK='
  function g21_name(w,   P) { return tolower(P[split(w, P, "/")]) }
  # g21_fact(w): the word w sets a git directory, or names a link or move, in any record.
  function g21_fact(w) {
    if (w ~ /^GIT_(DIR|WORK_TREE)=/) print "O"
    if (g21_name(w) in G21L) print "L"
  }
  # g21_tok(t): the token t of a command line, past a --name= or the option glued to a tool name.
  function g21_tok(t,   j, b) {
    sub(/^--[^=]*=/, "", t)
    if (t ~ /^-[A-Za-z]/)
      for (j = 3; j <= length(t); j++) { b = substr(t, j); if (tolower(b) in G21W) return b }
    return t
  }
  # g21_cmd(w): the word w holds a blank, and a command in it, past any wrapper or keyword, names a tool.
  function g21_cmd(w,   n, A, i, c, T, j, t, wr) {
    if (w !~ /[ \t\037]/) return 0
    n = split(w, A, /[;&|()\037]+/)
    for (i = 1; i <= n; i++) {
      gsub(/^[ \t]+/, "", A[i])
      c = split(A[i], T, /[ \t]+/); wr = 0
      for (j = 1; j <= c; j++) {
        gsub(qre, "", T[j])
        t = g21_name(g21_tok(T[j]))
        if (t in G21W) return 1
        if (t ~ /^(command|exec|time|nohup|sudo|env|timeout|nice|builtin|then|do|else|if|while|until|!|[{])$/) wr = 1
        else if (!wr) break
      }
    }
    return 0
  }
  # g21_split(w): adds the tokens of the command line w to L, its quotes dropped.
  function g21_split(w,   n, A, i) {
    n = split(w, A, /[ \t\037;&|()]+/)
    for (i = 1; i <= n; i++) { gsub(qre, "", A[i]); if (A[i] != "") L[++m] = g21_tok(A[i]) }
  }
  # g21_t(w): the target w; after a directory option (mv) only a path that does not lean on the cwd.
  function g21_t(w) {
    if (mv && w !~ /^[\/$]/) print "X\t" w ", after a directory option"
    else print "T\t" w
  }
  # g21_dots(x): the literal cd word x has a .. the shell may read otherwise than the disk: after a part of
  # its own, or after an earlier cd into a part.
  function g21_dots(x,   y) {
    y = x
    while (y ~ /^[.][.](\/|$)/) sub(/^[.][.]\/*/, "", y)
    if (y ~ /(^|\/)[.][.](\/|$)/ || (cdp && x ~ /^[.][.](\/|$)/)) return 1
    if (y != "") cdp = 1
    return 0
  }
  # g21_bare(s): the command record s expands outside quotes, so one word may become several.
  function g21_bare(s,   n, C, i, c, q, o) {
    n = split(s, C, ""); q = ""; o = ""
    for (i = 1; i <= n; i++) {
      c = C[i]
      if (q == sq) { if (c == sq) q = ""; continue }
      if (q == "\"") { if (c == "\\") i++; else if (c == "\"") q = ""; continue }
      if (c == "\\") { i++; continue }
      if (c == sq || c == "\"") { q = c; continue }
      o = o c
    }
    return gw_dyn(o)
  }
  # g21_built(p): the find at L[p] with a word built at run time, which may be any primary. A first root
  # and the value of a primary in G21V stay free when each is one word that does not start as an option.
  function g21_built(p,   j, w, root, one) {
    root = 1; one = !r && !g21_bare($0)
    for (j = p + 1; j <= m; j++) {
      w = L[j]
      if (root && (w ~ /^-[HPEXdsxfD]+$/ || w ~ /^-O/)) continue
      if (gw_dyn(w) && !(one && (root || L[j - 1] ~ G21V) && w !~ /^-/ && w !~ /[$][@*]|[[][@*][]]/)) {
        print "X\tfind with a word kern cannot read"
        return
      }
      root = 0
    }
  }
  # g21_roots(p): the targets of the find at L[p], the words before its expression; . with none. A find
  # that follows links leaves them, and xargs or a host may add to it.
  function g21_roots(p,   j, n) {
    if (rooted) return
    rooted = 1
    if (xa || rem) { print "X\tfind after xargs or on another host"; return }
    for (j = p + 1; j <= m; j++) if (L[j] == "-L" || L[j] == "-follow") { print "X\tfind that follows links"; return }
    n = 0
    for (j = p + 1; j <= m; j++) {
      if (L[j] ~ /^-[HPEXdsxfD]+$/ || L[j] ~ /^-O/) continue
      if (L[j] ~ /^-/ || L[j] == "(" || L[j] == "!") break
      n++; g21_t(L[j])
    }
    if (!n) g21_t(".")
  }
  # g21_tool(p): the tool at L[p]: its targets, up to the end of the words or of a find -exec. Returns
  # where it stopped.
  function g21_tool(p,   j, n, dd, w) {
    n = 0; dd = 0
    for (j = p + 1; j <= m; j++) {
      w = L[j]
      if (fnd && (w == ";" || w == "+")) break
      if (!dd && w ~ /^[0-9]*(<|>|&>)/) { if (w ~ /^[0-9]*[<>&|]+$/) j++; continue }
      if (!dd && w == "--") { dd = 1; continue }
      if (!dd && w ~ /^-./) continue
      n++
      if (fnd && w == "{}") g21_roots(fnd)
      else if (fnd) print "X\t" L[p] " " w " in a find"
      else if (!xa && !rem) g21_t(w)
    }
    if (xa) print "X\t" L[p] " after xargs"
    else if (rem) print "X\t" L[p] " on another host"
    else if (!n && p > 1) print "X\t" L[p] " with no target kern can read"
    return j
  }
  BEGIN {
    split(tools, G21A, " ")
    for (k in G21A) G21T[G21A[k]] = G21W[G21A[k]] = 1
    split(finds, G21A, " ")
    for (k in G21A) G21F[G21A[k]] = G21W[G21A[k]] = 1
    G21L["ln"] = G21L["gln"] = G21L["mv"] = G21L["gmv"] = 1
    G21W["ln"] = G21W["gln"] = G21W["mv"] = G21W["gmv"] = 1
    G21W["xargs"] = G21W["parallel"] = G21W["ssh"] = 1
    G21C["sh"] = G21C["bash"] = G21C["zsh"] = G21C["dash"] = G21C["su"] = G21C["script"] = 1
    G21V = "^-(i?(name|path|wholename|regex|lname)|x?type|user|group|uid|gid|size|perm|flags|[aBcm](time|min|newer)|newer.*|maxdepth|mindepth|samefile|inum|links|fstype)$"
    qre = "[\"" sq "]"
  }
  {
    sw($0); cw_reset()
    for (k = 1; k <= sw_n; k++) { cw(sw_w[k]); g21_fact(sw_w[k]) }
    if (!cw_n) next
    # mv: an option that may change directory comes before the tool (env -C, sudo -D, git -C).
    mv = 0
    for (k = 1; k <= sw_n; k++) {
      if (g21_name(sw_w[k]) in G21T) break
      if (sw_w[k] ~ /^-[A-Za-z]*[CDR]/ || sw_w[k] ~ /^--(ch|dir|wd|work-tree|git-dir)/) mv = 1
      if (sw_w[k] ~ /^-[A-Za-z]*w/ && g21_name(cw_w[1]) ~ /^(nsenter|unshare)$/) mv = 1
    }
    # L[1..m]: the words. r: a command line starts here (ssh, watch, the -c of a shell that is not the
    # head, whose script git_words does not read), so each word after it is split.
    m = 0; r = 0; host = 0
    wide = g21_name(cw_w[1]) !~ /^(git|gh)$/
    for (k = 1; k <= cw_n; k++) {
      if (r) { g21_split(cw_w[k]); continue }
      L[++m] = cw_w[k]
      if (host && (cw_w[k] ~ /^[-+][A-Za-z]*c/ || cw_w[k] ~ /^--command(=|$)/)) {
        r = m
        x = cw_w[k]
        if (x ~ /^--command=/) x = substr(x, 11)
        else if (x ~ /^--/) x = ""
        else x = substr(x, index(x, "c") + 1)
        g21_split(x)
        continue
      }
      if (wide && g21_cmd(cw_w[k])) { g21_split(cw_w[k]); continue }
      h = g21_name(cw_w[k])
      if (h == "ssh" || h == "watch") r = m
      else if (k > 1 && (h in G21C)) host = 1
    }
    for (k = 1; k <= m; k++) g21_fact(L[k])
    h = g21_name(L[1]); b = 1
    if (h == "builtin" && m > 1) { h = g21_name(L[2]); b = 2 }
    if (h == "pushd" || h == "popd") { print "M"; next }
    if (h == "cd" || h == "chdir") {
      n = 0
      for (k = b + 1; k <= m; k++) {
        if (L[k] ~ /^[0-9]*(<|>|&>)/) { if (L[k] ~ /^[0-9]*[<>&|]+$/) k++; continue }
        if (L[k] == "--" || L[k] ~ /^-[LPe@]+$/) continue
        n++; x = L[k]
      }
      if (n == 1 && x !~ /^[-+~]/ && x !~ /[$`*?[{\037]/ && !g21_dots(x)) print "C\t" x
      else print "M"
      next
    }
    # The read path: a head that only reads, unless a word of it runs a command.
    if (h ~ /^(grep|egrep|fgrep|rg|echo|printf|which|whereis|type)$/ || (h == "git" && L[2] ~ /^(grep|log)$/)) {
      for (k = 2; k <= m; k++)
        if (L[k] ~ /^--pre/ || (h == "git" && L[2] == "grep" && (L[k] ~ /^-[A-Za-z]*O/ || L[k] ~ /^--op/)))
          print "X\t" h " with a word that runs a command"
      next
    }
    fnd = 0; xa = 0; rem = 0; rooted = 0
    for (p = 1; p <= m; p++) {
      t = g21_name(L[p])
      if (t == "xargs" || t == "parallel") xa = 1
      else if (t == "ssh") rem = 1
      else if ((t in G21F) && !fnd) { fnd = p; if (xa) g21_roots(p); g21_built(p) }
      else if (fnd && L[p] == "-delete") g21_roots(fnd)
      else if (t in G21T) p = g21_tool(p)
    }
  }
  END { print "." }
'

# _G21_CDRE: what leaves a cd unfollowed, in the text _g21_text reads: CDPATH, in any case (zsh ties
# cdpath to it), a name built at run time, and a loop, function or trap, which may run a cd more than once.
_G21_CDRE='[Cc][Dd][Pp][Aa][Tt][Hh]|[$`]|[(][ \t]*[)]|(^|[ \t;&|(])(for|while|until|select|repeat|function|trap)([ \t]|$)'

guard_g21() {
  [ "$TOOL" = Bash ] || return 0
  local cmd out line seen=0
  cmd=$(ti_get command) || return 0
  _g21_named "$cmd ${KERN_ALIAS_TEXT-}" || return 0
  # A failed parse or judge leaves no `.`, so G21 asks.
  # shellcheck disable=SC2153 # _GW_AWK is set in gitctx.sh
  out=$(set -o pipefail; git_words "$cmd" |
    env LC_ALL=C awk -v sq="'" -v tools="$_G21_TOOLS" -v finds="$_G21_FINDS" "$_GW_AWK$_G21_AWK") || out=""
  _G21_CMD=$cmd
  _g21_open "$cmd"
  # An opening cd the judge did not read as that word is no match.
  if [ -n "$_G21_OPEN" ]; then
    case $'\n'"$out"$'\n' in
      *$'\n'"C	$_G21_OPEN"$'\n'*) ;;
      *) _G21_CWD=${CWD:-$PWD} _G21_OPEN="" ;;
    esac
  fi
  _G21_DIRS=$_G21_CWD$'\n'
  _G21_CD=0
  _G21_LOST=0
  _G21_SWAP=0
  _G21_ROUTE=0
  _G21_LOADED=0
  # Every cd, link and move counts before any target: the order of the text is not the order of the run.
  while IFS= read -r line; do
    case "$line" in
      .) seen=1 ;;
      M) _G21_CD=1 _G21_LOST=1 ;;
      O) _G21_LOST=1 ;;
      L) _G21_SWAP=1 ;;
      C*)
        if [ -n "$_G21_OPEN" ] && [ "${line#C	}" = "$_G21_OPEN" ]; then
          _G21_OPEN=""
        else
          _G21_CD=1
          _g21_cd "${line#C	}"
        fi
        ;;
    esac
  done <<EOT
$out
EOT
  [ "$seen" = 1 ] || { _g21_vote "kern could not read the command"; return 0; }
  if [ "$_G21_CD" = 1 ] && { [ -n "${CDPATH-}" ] || ! _g21_text "$_G21_CDRE"; }; then
    _G21_LOST=1
  fi
  case "$cmd" in *'('*) _g21_paren "$cmd" || { _g21_vote "a ( beside a delete target"; return 0; } ;; esac
  while IFS= read -r line; do
    case "$line" in
      X*) _g21_vote "${line#X	}"; return 0 ;;
      T*)
        [ "$_G21_SWAP" = 0 ] || { _g21_vote "${line#T	}"; return 0; }
        _g21_target "${line#T	}" || return 0
        ;;
    esac
  done <<EOT
$out
EOT
}

# _G21_OPENRE: a call that opens with cd, one word, and &&: leading blanks only, no option and no prefix.
# Space and tab are spelled out, since [[:blank:]] follows the locale and the shell's words do not.
_G21_OPENRE=$'^[ \t]*cd[ \t]+("[^"]+"|\'[^\']+\'|[^ \t"\']+)[ \t]+&&'

# _g21_open CMD: sets _G21_CWD, the call's cwd. It is the payload's, or, when CMD opens as _G21_OPENRE
# reads and its word is a literal absolute path whose physical form lies at or under a listed worktree
# other than the first, the main checkout, that physical form. _G21_OPEN then holds the word, so the
# judge's first cd line adds no reading. A cd that fails leaves git no directory, so no top is named.
# A lone & holds no match: it runs the list before it in a subshell, so the rest stays at the payload's
# cwd. &&, the pipe |& and the redirections >&, <&, &> and &>> are not one, nor is a & that a backslash
# escapes or that a pair of single or double quotes holds. When the text holds a $, a backtick, a #, a [,
# a << or a ((, where the shell may read a quote character as no quote, or a quote that never closes,
# every & counts. A failed read also holds no match.
_g21_open() {
  local w real line t n=0
  _G21_CWD=${CWD:-$PWD}
  _G21_OPEN=""
  [[ $1 =~ $_G21_OPENRE ]] || return 0
  w=${BASH_REMATCH[1]}
  printf '%s' "$1" | env LC_ALL=C awk -v sq="'" '
    { s = s $0 "\n" }
    END {
      o = s
      if (s !~ /[$`#[]|<<|[(][(]/) {
        n = split(s, C, ""); q = ""; o = ""
        for (i = 1; i <= n; i++) {
          c = C[i]
          if (q == sq) { if (c == sq) q = ""; continue }
          if (q == "\"") { if (c == "\\") i++; else if (c == "\"") q = ""; continue }
          if (c == "\\") { i++; continue }
          if (c == sq || c == "\"") { q = c; continue }
          o = o c
        }
        if (q != "") o = s
      }
      gsub(/&&|[|<>]&|&>>?/, "", o)
      exit (index(o, "&") > 0)
    }' ||
    return 0
  case "$w" in \"* | \'*) w=${w:1:${#w}-2} ;; esac
  case "$w" in /*) ;; *) return 0 ;; esac
  case "$w" in *[\$\`\\*?\[\]{}~\;\&\|\(\)\<\>\"\'\!#$'\n'$'\037']*) return 0 ;; esac
  case "/$w/" in */../*) return 0 ;; esac
  real=$(_g21_real "$w") || return 0
  while IFS= read -r line; do
    case "$line" in 'worktree '?*) ;; *) continue ;; esac
    n=$((n + 1))
    [ "$n" -gt 1 ] || continue
    t=$(_g21_real "${line#worktree }") || continue
    case "$real/" in
      "$t"/*)
        _G21_CWD=$real
        _G21_OPEN=$w
        return 0
        ;;
    esac
  done <<EOT
$(git -C "$_G21_CWD" -c core.fsmonitor=false worktree list --porcelain 2>/dev/null)
EOT
}

# _g21_named CMD: exit 0 when CMD, with quotes, backslashes and newlines removed, holds a tool name or
# -delete, in any case. A superset of what the judge can match, read before any parse.
_g21_named() {
  local flat=$1
  case "$1" in *[\"\'\\]* | *$'\n'*) flat=$(printf '%s' "$1" | env LC_ALL=C tr -d '"\047\\\n') ;; esac
  case "$flat" in
    *[Rr][Mm]* | *[Uu][Nn][Ll][Ii][Nn][Kk]* | *[Ss][Hh][Rr][Ee][Dd]* | *[Dd][Ee][Ll][Ee][Tt][Ee]* | *[Ff][Ii][Nn][Dd]*) return 0 ;;
  esac
  return 1
}

# _g21_paren CMD: exit 1 when an open paren follows a tool in a simple command of CMD: a zsh qualifier or
# group, which git_words splits off its word. Quoted text may be a script, so it is read the same way,
# unless the head is git, gh or a read and it runs no substitution. A failed read also exits other than 0.
_g21_paren() {
  printf '%s' "$1" | env LC_ALL=C tr '\n' '\037' | env LC_ALL=C awk -v sq="'" -v tools="$_G21_TOOLS $_G21_FINDS" '
    BEGIN { n = split(tools, A, " "); for (i = 1; i <= n; i++) TOOL[A[i]] = 1 }
    function scan(s,   n, C, i, c, q, w, t, h, sp, b, P) {
      n = split(s, C, ""); q = ""; w = ""; t = 0; h = ""; sp = ""
      for (i = 1; i <= n; i++) {
        c = C[i]
        if (q != "") {
          if (c == q) {
            q = ""
            if (index(sp, "(") && (h !~ /^(git|gh|grep|egrep|fgrep|rg|echo|printf)$/ || sp ~ /[$][(]|`/) && scan(sp)) return 1
            w = w sp; sp = ""
          }
          else if (q == "\"" && c == "\\") { i++; sp = sp C[i] }
          else sp = sp c
          continue
        }
        if (c == "\\") { i++; w = w C[i]; continue }
        if (c == sq || c == "\"") { q = c; continue }
        if (c == "#" && w == "") { while (i < n && C[i + 1] != "\037") i++; continue }
        if (index(" \t(;&|)`\037", c)) {
          if (w != "") {
            b = tolower(P[split(w, P, "/")])
            if (h == "") h = b
            if (c != "(" && (b in TOOL)) t = 1
            w = ""
          }
          if (c == "(" && C[i - 1] == "$") { t = 0; h = "" }
          if (c == "(" && t) return 1
          if (index(";&|)`\037", c)) { t = 0; h = "" }
          continue
        }
        w = w c
      }
      return 0
    }
    { if (scan($0)) exit 1 }'
}

# _g21_vote WHAT: asks; emit_decision denies under autopilot. The reason names the way through. A session
# at the main checkout gets the opening cd as its route past a cd, and when a target lies in a linked
# worktree or the text names one. A session in a worktree gets none, so no reason points it at a sibling.
# A find's built word need not be a delete, so it gets its own reason.
_g21_vote() {
  local why="delete outside this worktree and its scratch directories, or one kern cannot resolve: ${1:0:80}"
  local d lc
  if [ "$1" = 'find with a word kern cannot read' ]; then
    vote ask G21 "find with a word built at run time, which may be any primary, so kern cannot tell it from a delete; write the word literally"
    return 0
  fi
  _g21_load
  lc=$(_g21_lc "$_G21_CMD")
  while IFS= read -r d; do
    [ -n "$d" ] && [ "$d" != "$_G21_LTOP" ] || continue
    case "$lc" in *"$d"*) _G21_ROUTE=1 ;; esac
  done <<EOT
$_G21_LTREES
EOT
  [ "$_G21_SWAP" = 0 ] || why="$why; run the link or move as its own call"
  [ "$_G21_CD$_G21_ROUTE" = 00 ] || [ "$_G21_LTOP" != "$_G21_LMAIN" ] ||
    why="$why; open the call with cd <absolute worktree path> &&"
  case "$1" in *'$'*) why="$why; for a temp file run mktemp as its own call, then name the literal path" ;; esac
  vote ask G21 "$why; name each target as a literal path inside the worktree, not its top, or in a scratch directory"
}

# _g21_cd DIR: the literal DIR of a cd: each directory a relative path may start from gains DIR. Past
# eight readings kern stops following.
_g21_cd() {
  local d new=""
  case "$1" in
    /*) new=$1$'\n' ;;
    *)
      while IFS= read -r d; do
        [ -n "$d" ] && new="$new$d/$1"$'\n'
      done <<EOT
$_G21_DIRS
EOT
      ;;
  esac
  _G21_DIRS=$_G21_DIRS$new
  case "$_G21_DIRS" in *$'\n'*$'\n'*$'\n'*$'\n'*$'\n'*$'\n'*$'\n'*$'\n'*$'\n'*) _G21_LOST=1 ;; esac
}

# _g21_real PATH: absolute PATH with `.`, `..` and every symlink in the part that exists resolved, as the
# kernel walks it. A missing part stays as written. Exit 1 after 16 links.
_g21_real() {
  local todo="$1/" cur="" part link n=0
  while [ -n "$todo" ]; do
    part=${todo%%/*}
    todo=${todo#*/}
    case "$part" in
      '' | .) continue ;;
      ..) cur=${cur%/*}; continue ;;
    esac
    if [ -L "$cur/$part" ]; then
      n=$((n + 1))
      [ "$n" -le 16 ] || return 1
      link=$(readlink "$cur/$part") || return 1
      case "$link" in /*) cur="" ;; esac
      todo="$link/$todo"
    else
      cur="$cur/$part"
    fi
  done
  printf '%s\n' "${cur:-/}"
}

# _g21_text RE: exit 1 when RE matches the command with quotes and backslashes dropped and its reads of
# $TMPDIR removed, by line or with the lines joined.
_g21_text() {
  printf '%s' "$_G21_CMD" | env LC_ALL=C tr -d '"\047\\' | env LC_ALL=C awk -v re="$1" '
    { gsub(/[$][{]TMPDIR[}]|[$]TMPDIR/, ""); s = s $0; if ($0 ~ re) f = 1 }
    END { if (s ~ re) f = 1; exit f }'
}

# _g21_tmpdir: TMPDIR in the hook's environment is what the shell will see: an absolute path other than
# the root, and the command names TMPDIR only to read it and expands nothing else.
_g21_tmpdir() {
  case "${TMPDIR-}" in /*) ;; *) return 1 ;; esac
  [ -n "$(printf '%s' "$TMPDIR" | env LC_ALL=C tr -d /)" ] || return 1
  # shellcheck disable=SC2016 # an awk regex
  _g21_text 'TMPDIR|[$`]'
}

# _g21_lc TEXT: TEXT in lower case, ASCII only: a disk may fold case, and folding only refuses more.
_g21_lc() { printf '%s\n' "$1" | env LC_ALL=C tr 'A-Z' 'a-z'; }

# _g21_own_top: the call's cwd may name its worktree: core.worktree is unset, since a git config call
# gets no vote and it would move the top, and under a go this is the go's repository.
_g21_own_top() {
  local v go repo k
  v=$(git -C "$_G21_CWD" -c core.fsmonitor=false config --get core.worktree 2>/dev/null)
  [ $? = 1 ] && [ -z "$v" ] || return 1
  go=$(state_get "$SID" go 2>/dev/null)
  case $? in 0) ;; 1) return 0 ;; *) return 1 ;; esac
  [ -n "$go" ] || return 0
  repo=$(state_get "$SID" go_repo 2>/dev/null) || return 1
  k=$(consent_key "${KERN_MAIN-}") || return 1
  [ -n "$repo" ] && [ "$repo" = "$k" ]
}

# _g21_load: once per command, reads the worktree top (_G21_TOP, empty outside a work tree), WORK/tmp
# (_G21_WORK), the other scratch directories (_G21_SCRATCH) and every worktree of the payload cwd's
# repository and, after an opening cd, of the repository it lands in, as a repository nested in a
# worktree lists its own (_G21_TREES), physical, the lists one per line. WORK/tmp lies in the main
# worktree, so it is named apart. It follows kern-dir: a work_dir that is unread, that leaves the
# repository, or that a link moves names none. _G21_HOLD is the directory that holds the main checkout
# when that lies under a scratch root but is none. The _G21_L names are the lower-case forms, for
# _g21_path.
_g21_load() {
  [ "$_G21_LOADED" = 0 ] || return 0
  _G21_LOADED=1
  local t d wd line main="" hold list
  _G21_TOP=""
  if _g21_own_top; then
    t=$(git -C "$_G21_CWD" -c core.fsmonitor=false rev-parse --show-toplevel 2>/dev/null) && [ -n "$t" ] &&
      _G21_TOP=$(_g21_real "$t")
  fi
  _G21_SCRATCH=""
  for d in "${TMPDIR-}" /tmp /private/tmp; do
    case "$d" in /*) ;; *) continue ;; esac
    t=$(_g21_real "$d") || continue
    [ "$t" = / ] || _G21_SCRATCH="$_G21_SCRATCH$t"$'\n'
  done
  [ -z "${KERN_MAIN-}" ] || main=$(_g21_real "$KERN_MAIN") || main=""
  _G21_WORK=""
  if [ -n "$main" ] && wd=$(settings_get work_dir .kern); then
    wd=${wd%/}
    case "$wd" in
      '' | . | :* | .git | .git* | /* | *..*) ;;
      *)
        t=$(_g21_real "$main/$wd/tmp") && [ "$t" = "$main/$wd/tmp" ] && _G21_WORK=$t
        ;;
    esac
  fi
  _G21_HOLD=""
  hold=${main%/*}
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    [ "$d" != "$hold" ] || { _G21_HOLD=""; break; }
    case "$hold" in "$d"/?*) _G21_HOLD=$hold ;; esac
  done <<EOT
$_G21_SCRATCH
EOT
  _G21_TREES=""
  list=$(git -C "${CWD:-$PWD}" -c core.fsmonitor=false worktree list --porcelain 2>/dev/null)
  [ "$_G21_CWD" = "${CWD:-$PWD}" ] ||
    list=$list$'\n'$(git -C "$_G21_CWD" -c core.fsmonitor=false worktree list --porcelain 2>/dev/null)
  while IFS= read -r line; do
    case "$line" in
      'worktree '?*) t=$(_g21_real "${line#worktree }") && _G21_TREES="$_G21_TREES$t"$'\n' ;;
    esac
  done <<EOT
$list
EOT
  _G21_LTOP=$(_g21_lc "$_G21_TOP")
  _G21_LMAIN=$(_g21_lc "$main")
  _G21_LHOLD=$(_g21_lc "$_G21_HOLD")
  _G21_LTREES=$(_g21_lc "$_G21_TREES")
}

# _g21_path PATH GLOB: the resolved absolute PATH may go. GLOB is its last part when that is a pattern.
# Inside the worktree top: anything but a .git, in any case, and a pattern must not match the .git beside
# it. Else inside WORK/tmp, or a scratch directory but for what _G21_HOLD holds, and a pattern must not lie
# directly at one. No worktree may then be PATH, lie under it or hold it, compared in lower case, but for
# the top itself, what holds the top of a PATH inside it, and the main checkout around WORK/tmp.
_g21_path() {
  local p="$1" glob="$2" d ok=0 own=0 work=0 lp lg up
  _g21_load
  if [ -n "$_G21_TOP" ] && case "$p" in "$_G21_TOP"/?*) true ;; *) false ;; esac; then
    case "/${p#"$_G21_TOP"/}/" in */.[Gg][Ii][Tt]/*) return 1 ;; esac
    if [ -n "$glob" ] && [ "${p%/*}" = "$_G21_TOP" ]; then
      # shellcheck disable=SC2194,SC2254
      case .git in $glob) return 1 ;; esac
    fi
    ok=1 own=1
  elif [ -n "$_G21_WORK" ] && case "$p" in "$_G21_WORK"/?*) true ;; *) false ;; esac; then
    [ -z "$glob" ] || [ "${p%/*}" != "$_G21_WORK" ] || return 1
    ok=1 work=1
  else
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      case "$p" in
        "$d"/?*)
          [ -z "$glob" ] || [ "${p%/*}" != "$d" ] || return 1
          ok=1
          ;;
      esac
    done <<EOT
$_G21_SCRATCH
EOT
  fi
  [ "$ok" = 1 ] || return 1
  lp=$(_g21_lc "$p")
  lg=$(_g21_lc "$glob")
  if [ "$own$work" = 00 ] && [ -n "$_G21_LHOLD" ]; then
    case "$lp" in "$_G21_LHOLD"/*) return 1 ;; esac
  fi
  # A pattern reads the directory above it: a worktree below that counts when its first part matches.
  up=$lp
  [ -z "$glob" ] || up=${lp%/*}
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    [ "$d" != "$lp" ] || return 1
    case "$d" in
      "$up"/*)
        [ -n "$glob" ] || return 1
        d=${d#"$up"/}
        # shellcheck disable=SC2254
        case "${d%%/*}" in $lg) return 1 ;; esac
        continue
        ;;
    esac
    [ "$d" != "$_G21_LTOP" ] || continue
    if [ "$own" = 1 ]; then
      case "$_G21_LTOP" in "$d"/*) continue ;; esac
    fi
    [ "$work" = 0 ] || [ "$d" != "$_G21_LMAIN" ] || continue
    case "$lp" in
      "$d"/*)
        _G21_ROUTE=1
        return 1
        ;;
    esac
  done <<EOT
$_G21_LTREES
EOT
}

# _g21_target WORD: resolves WORD from every directory a relative path may start from. Exit 1 after the
# ask when it cannot pass.
_g21_target() {
  local t="$1" dir last glob="" d p
  case "$t" in
    '$TMPDIR' | '$TMPDIR/'* | '${TMPDIR}' | '${TMPDIR}/'*)
      _g21_tmpdir || { _g21_vote "$1"; return 1; }
      t=${t#*TMPDIR}
      t=$TMPDIR${t#\}}
      ;;
  esac
  case "$t" in
    *'$'* | *'`'* | '~'* | '='* | *'{'* | *'}'* | *'['* | *$'\037'*) _g21_vote "$1"; return 1 ;;
  esac
  case "$t" in
    */*) dir=${t%/*}/ last=${t##*/} ;;
    *) dir="" last=$t ;;
  esac
  case "$dir" in *[*?]*) _g21_vote "$1"; return 1 ;; esac
  case "$last" in *[*?]*) glob=$last ;; esac
  case "$glob" in
    .*)
      # shellcheck disable=SC2194,SC2254
      case .. in $glob) _g21_vote "$1"; return 1 ;; esac
      ;;
  esac
  case "$t" in
    /*)
      p=$(_g21_real "$t") && _g21_path "$p" "$glob" || { _g21_vote "$1"; return 1; }
      return 0
      ;;
  esac
  [ "$_G21_LOST" = 0 ] || { _g21_vote "$1"; return 1; }
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    p=$(_g21_real "$d/$t") && _g21_path "$p" "$glob" || { _g21_vote "$1"; return 1; }
  done <<EOT
$_G21_DIRS
EOT
}
