# shellcheck shell=bash
# G21 local deletes: rm, rmdir, unlink, shred and find -delete get no vote when every target resolves
# inside the command's worktree (not .git) or a scratch directory ($TMPDIR, /tmp, /private/tmp,
# WORK/tmp). Any other target, or one kern cannot resolve, asks, and autopilot turns the ask into a
# denial. No policy key loosens it, and it never votes allow. A run removes a file on its own branch
# as ordinary work; delete is on the stop list everywhere else.
# The words of each simple command come from _cmd_words, as for G15, and any word may name a tool
# (basename, lower case), so an unknown wrapper, xargs or find -exec cannot hide it. The cost: a tool
# named as a plain word judges the words after it, so `ls rm` asks; only the heads in _G21_AWK's read
# list never vote. Quoted text stays one word, except after ssh, watch, or the -c of sh, bash, zsh, dash,
# su or script behind another command: there each later word is split, since it may be a command line.
# A target is unresolved when it holds a variable other than $TMPDIR, a leading ~ or =, a brace list, a
# [ ] glob, or a * or ? before its last part. The worktree top is that of the command's cwd, and symlinks
# are followed through the part of a path that exists, so a link that points out of the worktree is
# outside. Any git worktree but this one is outside, and so is a directory that holds a worktree. A cd
# adds its target to the directories a relative path is read from, and each reading must pass, since
# kern cannot tell what a subshell undoes.
# Out of scope (accepted limits): other ways to delete (mv, git clean, a file redirect, a script in
# another language), an alias or function of the shell, and a script that the command sources and that
# sets TMPDIR.

# _G21_AWK: the judge, run on git_words records after _GW_AWK. Prints one line per fact, in record order:
# `T<TAB>word` a target to resolve, `C<TAB>word` a cd to a literal directory, `M` a cd kern cannot follow,
# `X<TAB>text` a delete kern cannot judge, and `.` at the end.
# shellcheck disable=SC2016 # awk text
_G21_AWK='
  function g21_name(w,   P) { return tolower(P[split(w, P, "/")]) }
  # g21_t(w): the target w; after a directory option (mv) only a path that does not lean on the cwd.
  function g21_t(w) {
    if (mv && w !~ /^[\/$]/) print "X\t" w ", after a directory option"
    else print "T\t" w
  }
  # g21_roots(p): the targets of the find at L[p], the words before its expression; . with none. A find
  # that follows links leaves them.
  function g21_roots(p,   j, n) {
    if (rooted) return
    rooted = 1
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
    G21T["rm"] = G21T["rmdir"] = G21T["unlink"] = G21T["shred"] = 1
    G21C["sh"] = G21C["bash"] = G21C["zsh"] = G21C["dash"] = G21C["su"] = G21C["script"] = 1
    qre = "[\"" sq "]"
  }
  {
    sw($0); cw_reset()
    for (k = 1; k <= sw_n; k++) cw(sw_w[k])
    if (!cw_n) next
    # mv: an option that may change directory comes before the tool (env -C, sudo -D, git -C).
    mv = 0
    for (k = 1; k <= sw_n; k++) {
      if (g21_name(sw_w[k]) in G21T) break
      if (sw_w[k] ~ /^-[A-Za-z]*[CDR]/ || sw_w[k] ~ /^--(ch|dir)/) mv = 1
    }
    # L[1..m]: the words. r: a command line starts here (ssh, watch, the -c of a shell that is not the
    # head, whose script git_words does not read), so each word after it is split, its quotes dropped.
    m = 0; r = 0; host = 0
    for (k = 1; k <= cw_n; k++) {
      if (r) {
        n = split(cw_w[k], a, /[ \t\037;&|()]+/)
        for (i = 1; i <= n; i++) { gsub(qre, "", a[i]); if (a[i] != "") L[++m] = a[i] }
        continue
      }
      L[++m] = cw_w[k]
      if (host && (cw_w[k] ~ /^[-+][A-Za-z]*c/ || cw_w[k] ~ /^--command(=|$)/)) {
        r = m
        x = cw_w[k]
        if (x ~ /^--command=/) x = substr(x, 11)
        else if (x ~ /^--/) x = ""
        else x = substr(x, index(x, "c") + 1)
        n = split(x, a, /[ \t\037;&|()]+/)
        for (i = 1; i <= n; i++) { gsub(qre, "", a[i]); if (a[i] != "") L[++m] = a[i] }
        continue
      }
      h = g21_name(cw_w[k])
      if (h == "ssh" || h == "watch") r = m
      else if (k > 1 && (h in G21C)) host = 1
    }
    h = g21_name(L[1]); b = 1
    if (h == "builtin" && m > 1) { h = g21_name(L[2]); b = 2 }
    if (h == "pushd" || h == "popd") { print "M"; next }
    if (h == "cd") {
      n = 0
      for (k = b + 1; k <= m; k++) {
        if (L[k] ~ /^[0-9]*(<|>|&>)/) { if (L[k] ~ /^[0-9]*[<>&|]+$/) k++; continue }
        if (L[k] == "--" || L[k] ~ /^-[LPe@]+$/) continue
        n++; x = L[k]
      }
      if (n == 1 && x != "-" && x !~ /[$`*?[{\037]/ && x !~ /^~/) print "C\t" x
      else print "M"
      next
    }
    if (h ~ /^(grep|egrep|fgrep|rg|echo|printf|which|whereis|type|man)$/) next
    fnd = 0; xa = 0; rem = 0; rooted = 0
    for (p = 1; p <= m; p++) {
      t = g21_name(L[p])
      if (t == "xargs" || t == "parallel") xa = 1
      else if (t == "ssh") rem = 1
      else if (t == "find" && !fnd) fnd = p
      else if (fnd && L[p] == "-delete") g21_roots(fnd)
      else if (t in G21T) p = g21_tool(p)
    }
  }
  END { print "." }
'

guard_g21() {
  [ "$TOOL" = Bash ] || return 0
  local cmd out line seen=0
  cmd=$(ti_get command) || return 0
  _g21_named "$cmd ${KERN_ALIAS_TEXT-}" || return 0
  # A failed parse or judge leaves no `.`, so G21 asks.
  # shellcheck disable=SC2153 # _GW_AWK is set in gitctx.sh
  out=$(set -o pipefail; git_words "$cmd" | env LC_ALL=C awk -v sq="'" "$_GW_AWK$_G21_AWK") || out=""
  _G21_CMD=$cmd
  _G21_DIRS=${CWD:-$PWD}$'\n'
  _G21_CD=0
  _G21_LOST=0
  _G21_LOADED=0
  while IFS= read -r line; do
    case "$line" in
      .) seen=1 ;;
      M) _G21_CD=1 _G21_LOST=1 ;;
      C*) _G21_CD=1; _g21_cd "${line#C	}" ;;
      X*) _g21_vote "${line#X	}"; return 0 ;;
      T*) _g21_target "${line#T	}" || return 0 ;;
    esac
  done <<EOT
$out
EOT
  [ "$seen" = 1 ] || _g21_vote "kern could not read the command"
}

# _g21_named CMD: exit 0 when CMD, with quotes, backslashes and newlines removed, holds a tool name or
# -delete, in any case. A superset of what the judge can match, read before any parse.
_g21_named() {
  local flat=$1
  case "$1" in *[\"\'\\]* | *$'\n'*) flat=$(printf '%s' "$1" | env LC_ALL=C tr -d '"\047\\\n') ;; esac
  case "$flat" in
    *[Rr][Mm]* | *[Uu][Nn][Ll][Ii][Nn][Kk]* | *[Ss][Hh][Rr][Ee][Dd]* | *[Dd][Ee][Ll][Ee][Tt][Ee]*) return 0 ;;
  esac
  return 1
}

# _g21_vote WHAT: asks; emit_decision denies under autopilot. A cd in the command brings its fix.
_g21_vote() {
  local why="delete outside this worktree and its scratch directories, or one kern cannot resolve: ${1:0:80}"
  [ "$_G21_CD" = 0 ] || why="$why; run cd <wt> as its own call"
  vote ask G21 "$why"
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

# _g21_tmpdir: TMPDIR in the hook's environment is what the shell will see: an absolute path other than
# the root, and no word of the command, quotes dropped, names TMPDIR but to read it.
_g21_tmpdir() {
  case "${TMPDIR-}" in /*) ;; *) return 1 ;; esac
  [ -n "$(printf '%s' "$TMPDIR" | env LC_ALL=C tr -d /)" ] || return 1
  printf '%s' "$_G21_CMD" | env LC_ALL=C tr -d '"\047\\\n' | env LC_ALL=C awk '
    { gsub(/[$][{]TMPDIR[}]|[$]TMPDIR/, "") }
    /TMPDIR/ { f = 1 }
    END { exit f }'
}

# _g21_load: once per command, reads the worktree top (_G21_TOP, empty outside a work tree), WORK/tmp
# (_G21_WORK), the other scratch directories (_G21_SCRATCH) and every worktree of the repository
# (_G21_TREES), physical, the lists one per line. WORK/tmp lies in the main worktree, so it is named
# apart. It follows kern-dir: a work_dir that is unread, or that leaves the repository, names none.
_g21_load() {
  [ "$_G21_LOADED" = 0 ] || return 0
  _G21_LOADED=1
  local t d wd line
  _G21_TOP=""
  t=$(git -C "${CWD:-$PWD}" -c core.fsmonitor=false rev-parse --show-toplevel 2>/dev/null) && [ -n "$t" ] &&
    _G21_TOP=$(_g21_real "$t")
  _G21_SCRATCH=""
  for d in "${TMPDIR-}" /tmp /private/tmp; do
    case "$d" in /*) ;; *) continue ;; esac
    t=$(_g21_real "$d") || continue
    [ "$t" = / ] || _G21_SCRATCH="$_G21_SCRATCH$t"$'\n'
  done
  _G21_WORK=""
  if [ -n "${KERN_MAIN-}" ] && wd=$(settings_get work_dir .kern); then
    wd=${wd%/}
    case "$wd" in
      '' | . | :* | .git | .git* | /* | *..*) ;;
      *) _G21_WORK=$(_g21_real "$KERN_MAIN/$wd/tmp") || _G21_WORK="" ;;
    esac
  fi
  _G21_TREES=""
  while IFS= read -r line; do
    case "$line" in
      'worktree '?*) t=$(_g21_real "${line#worktree }") && _G21_TREES="$_G21_TREES$t"$'\n' ;;
    esac
  done <<EOT
$(git -C "${CWD:-$PWD}" -c core.fsmonitor=false worktree list --porcelain 2>/dev/null)
EOT
}

# _g21_path PATH GLOB: the resolved absolute PATH may go. GLOB is its last part when that is a pattern.
# Inside the worktree top: anything but a .git, in any case, and a pattern must not match the .git beside
# it. Else inside WORK/tmp, or a scratch directory. Past WORK/tmp, no worktree may be PATH, lie under it
# or, unless it is this one, hold it.
_g21_path() {
  local p="$1" glob="$2" d ok=0 up
  _g21_load
  if [ -n "$_G21_TOP" ] && case "$p" in "$_G21_TOP"/?*) true ;; *) false ;; esac; then
    case "/${p#"$_G21_TOP"/}/" in */.[Gg][Ii][Tt]/*) return 1 ;; esac
    if [ -n "$glob" ] && [ "${p%/*}" = "$_G21_TOP" ]; then
      # shellcheck disable=SC2194,SC2254
      case .git in $glob) return 1 ;; esac
    fi
    ok=1
  elif [ -n "$_G21_WORK" ] && case "$p" in "$_G21_WORK"/?*) true ;; *) false ;; esac; then
    return 0
  else
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      case "$p" in "$d"/?*) ok=1 ;; esac
    done <<EOT
$_G21_SCRATCH
EOT
  fi
  [ "$ok" = 1 ] || return 1
  # A pattern reads the directory above it: a worktree below that counts when its first part matches.
  up=$p
  [ -z "$glob" ] || up=${p%/*}
  while IFS= read -r d; do
    [ -n "$d" ] || continue
    [ "$d" != "$p" ] || return 1
    case "$d" in
      "$up"/*)
        [ -n "$glob" ] || return 1
        d=${d#"$up"/}
        # shellcheck disable=SC2254
        case "${d%%/*}" in $glob) return 1 ;; esac
        continue
        ;;
    esac
    [ "$d" != "$_G21_TOP" ] || continue
    case "$p" in "$d"/*) return 1 ;; esac
  done <<EOT
$_G21_TREES
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
