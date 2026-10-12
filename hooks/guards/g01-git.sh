# shellcheck shell=bash
# G1 git safety: main-checkout state changes, push, force push, merge. Design spec 8.3.
# An allow approves the whole Bash call, so G1 allows a push only in the one shape _g01_proven
# accepts; any other push asks, or is denied under autopilot.

# Option tables for _g01_opts, from `git <cmd> -h` (git 2.54): LONG/SHORT/KIND, `-` for none.
# KIND 0 takes no value, 1 takes one (attached or the next word), o takes one only when attached.
_G01_PUSH_OPTS="verbose/v/0 quiet/q/0 repo/-/1 all/-/0 branches/-/0 mirror/-/0 delete/d/0 \
tags/-/0 dry-run/n/0 porcelain/-/0 force/f/0 force-with-lease/-/o force-if-includes/-/0 \
recurse-submodules/-/1 thin/-/0 receive-pack/-/1 exec/-/1 set-upstream/u/0 progress/-/0 \
prune/-/0 no-verify/-/0 verify/-/0 follow-tags/-/0 signed/-/o atomic/-/0 push-option/o/1 \
ipv4/4/0 ipv6/6/0"
_G01_RESET_OPTS="quiet/q/0 no-refresh/-/0 refresh/-/0 mixed/-/0 soft/-/0 hard/-/0 merge/-/0 \
keep/-/0 recurse-submodules/-/o patch/p/0 auto-advance/-/0 unified/U/1 inter-hunk-context/-/1 \
intent-to-add/N/0 pathspec-from-file/-/1 pathspec-file-nul/-/0"
_G01_BRANCH_OPTS="verbose/v/0 quiet/q/0 track/t/o set-upstream-to/u/1 unset-upstream/-/0 \
color/-/o remotes/r/0 contains/-/1 no-contains/-/1 abbrev/-/o all/a/0 delete/d/0 -/D/0 move/m/0 \
-/M/0 omit-empty/-/0 copy/c/0 -/C/0 list/l/0 show-current/-/0 create-reflog/-/0 \
edit-description/-/0 force/f/0 merged/-/1 no-merged/-/1 column/-/o sort/-/1 points-at/-/1 \
ignore-case/i/0 recurse-submodules/-/0 format/-/1"
_G01_CLEAN_OPTS="quiet/q/0 dry-run/n/0 force/f/0 interactive/i/0 -/d/0 exclude/e/1 -/x/0 -/X/0"
_G01_WT_REMOVE_OPTS="force/f/0"

guard_g01() {
  [ "$TOOL" = Bash ] || return 0
  local cmd rec recs=() w=() t moved=0
  cmd=$(ti_get command) || { fail_closed "Bash call without a command"; return 0; }
  while IFS= read -r rec; do [ -n "$rec" ] && recs+=("$rec"); done <<EOT
$(git_words "$cmd")
EOT
  _G01_CMD=$cmd
  _G01_NREC=${#recs[@]}
  for rec in "${recs[@]}"; do
    w=()
    while IFS= read -r t; do w+=("$t"); done <<EOT
$(_cmd_words "$rec")
EOT
    # After a cd, or a GIT_DIR or GIT_WORK_TREE assignment, later git commands run where G1
    # cannot tell.
    case "$rec" in *GIT_DIR=* | *GIT_WORK_TREE=*) moved=1 ;; esac
    case "${w[0]}" in
      cd | pushd | popd) moved=1 ;;
      builtin) case "${w[1]-}" in cd | pushd | popd) moved=1 ;; esac ;;
      gh | */gh) _g01_gh "$rec" "${w[@]}" ;;
      git | */git) _g01_git_rec "$rec" "$moved" "${w[@]}" ;;
    esac
  done
}

# _g01_gh RECORD gh WORDS...: `gh pr merge`, with or without -R/--repo, and `gh api` on a merge
# endpoint.
_g01_gh() {
  local rec="$1" a=() skip=0 x
  shift 2
  for x in "$@"; do
    if [ "$skip" = 1 ]; then
      skip=0
      continue
    fi
    case "$x" in
      -R | --repo) skip=1 ;;
      -R?* | --repo=*) ;;
      *) a+=("$x") ;;
    esac
  done
  case "${a[0]-}" in
    pr) case " ${a[*]} " in *" merge "*) _g01_merge "gh pr merge" ;; esac ;;
    api) case "$rec" in *"/merge"*) _g01_merge "gh api merge endpoint" ;; esac ;;
  esac
}

_g01_merge() {
  vote ask G1 "$1 merges a PR; merge always needs the user's word"
  [ "$AUTOPILOT" = 1 ] && vote deny G1 "$1 under autopilot: merge stays human"
}

# _g01_git_rec RECORD MOVED git WORDS...: reads git's global options, then checks the subcommand.
# The directory is empty (unknown) when MOVED is 1 or with --git-dir or --work-tree. PLAIN is 1
# when the record is `git`, then only -C options, then the subcommand.
_g01_git_rec() {
  local rec="$1" dir="${CWD:-$PWD}" plain=1
  [ "$2" = 1 ] && dir=""
  shift 3
  case "$rec" in "git "*) ;; *) plain=0 ;; esac
  while [ $# -gt 0 ]; do
    case "$1" in
      -C)
        [ $# -ge 2 ] || return 0
        if [ -n "$dir" ]; then
          case "$2" in /*) dir="$2" ;; *) dir="$dir/$2" ;; esac
        fi
        shift 2
        ;;
      --git-dir | --work-tree)
        [ $# -ge 2 ] || return 0
        dir=""; plain=0; shift 2
        ;;
      --git-dir=* | --work-tree=*) dir=""; plain=0; shift ;;
      -c | --config-env | --namespace | --super-prefix | --attr-source)
        [ $# -ge 2 ] || return 0
        plain=0; shift 2
        ;;
      --config-env=* | --namespace=* | --super-prefix=* | --attr-source=* | --exec-path=* | -p | -P | \
        --paginate | --no-pager | --bare | --no-replace-objects | --no-lazy-fetch | --no-optional-locks | \
        --no-advice | --literal-pathspecs | --glob-pathspecs | --noglob-pathspecs | --icase-pathspecs)
        plain=0; shift
        ;;
      *) break ;;
    esac
  done
  [ $# -gt 0 ] || return 0
  _g01_git "$dir" "$plain" "$@"
}

# _g01_opts TABLE WORDS...: git's option parsing of WORDS, one token per line: `--long` or
# `--long=value` for an option (a short option prints its long name, or `-X` when it has none),
# `@word` for an argument, `>redir` for a redirection and its target, `?word` for an option git
# rejects as unknown or ambiguous. Short clusters split; a long option may be any unique prefix,
# as in git; `--no-` negates.
_g01_opts() {
  local table="$1"
  shift
  [ $# -gt 0 ] || return 0
  printf '%s\n' "$@" | LC_ALL=C awk -v table="$table" '
    BEGIN {
      nt = split(table, ent, " ")
      for (i = 1; i <= nt; i++) {
        split(ent[i], f, "/"); L[i] = f[1]; S[i] = f[2]; K[i] = f[3]
        if (S[i] != "-") sh[S[i]] = i
      }
    }
    { w[++n] = $0 }
    function tok(i) { return L[i] != "-" ? "--" L[i] : "-" S[i] }
    # lng(a): one long option, a without its dashes. An exact name wins; else a prefix must match
    # one option only. A negated form (hi 0) takes no value.
    function lng(a,   eq, nm, v, i, hit, hi, nc, c, cn, h2, i2) {
      eq = index(a, "="); nm = eq ? substr(a, 1, eq - 1) : a; v = substr(a, eq + 1)
      if (nm == "") { print "?--" a; return }
      hit = ""; nc = 0
      for (i = 1; i <= nt; i++) {
        if (L[i] == "-") continue
        if (nm == L[i]) { hit = "--" L[i]; hi = i; break }
        if (nm == "no-" L[i]) { hit = "--" nm; hi = 0; break }
        if (L[i] ~ /^no-/ && nm == substr(L[i], 4)) { hit = "--" nm; hi = 0; break }
        c = ""
        if (index(L[i], nm) == 1) { c = "--" L[i]; cn = i }
        else if (nm ~ /^no-/ && index(L[i], substr(nm, 4)) == 1) { c = "--no-" L[i]; cn = 0 }
        else if (index("no-", nm) == 1) { c = "--no-" L[i]; cn = 0 }
        else if (L[i] ~ /^no-/ && index(substr(L[i], 4), nm) == 1) { c = "--" substr(L[i], 4); cn = 0 }
        if (c != "") { nc++; h2 = c; i2 = cn }
      }
      if (hit == "") {
        if (nc != 1) { print "?--" a; return }
        hit = h2; hi = i2
      }
      if (!hi || K[hi] == "0") { print (eq ? "?--" a : hit); return }
      if (eq) { print hit "=" v; return }
      if (K[hi] == "o") { print hit; return }
      if (p < n) print hit "=" w[++p]; else print "?--" a
    }
    function shrt(a,   j, c, i, r) {
      for (j = 1; j <= length(a); j++) {
        c = substr(a, j, 1)
        if (!(c in sh)) { print "?-" c; return }
        i = sh[c]; r = substr(a, j + 1)
        if (K[i] == "1") {
          if (r == "") { if (p < n) r = w[++p]; else { print "?-" c; return } }
          print tok(i) "=" r; return
        }
        if (K[i] == "o") { print tok(i) (r != "" ? "=" r : ""); return }
        print tok(i)
      }
    }
    END {
      for (p = 1; p <= n; p++) {
        x = w[p]
        if (x ~ /^[0-9]*(<|>|&>)/) {
          if (x ~ /^[0-9]*[<>&|]+$/ && p < n) x = x w[++p]
          print ">" x
        }
        else if (dd) print "@" x
        else if (x == "--" || x == "--end-of-options") dd = 1
        else if (x ~ /^--/) lng(substr(x, 3))
        else if (x ~ /^-./) shrt(substr(x, 2))
        else print "@" x
      }
    }'
}

# _g01_main_op DIR WHAT: ask in the main checkout (deny under autopilot); nothing elsewhere. An
# unknown DIR (empty) may be the main checkout.
_g01_main_op() {
  if [ -z "$1" ]; then
    if [ "$AUTOPILOT" = 1 ]; then
      vote deny G1 "git $2 after cd, --git-dir or --work-tree may hit the main checkout (D3)"
    else
      vote ask G1 "git $2 after cd, --git-dir or --work-tree may change the main checkout (D3)"
    fi
    return 0
  fi
  in_main_checkout "$1" || return 0
  if [ "$AUTOPILOT" = 1 ]; then
    vote deny G1 "git $2 in the main checkout (D3); use a kern worktree"
  else
    vote ask G1 "git $2 in the main checkout changes shared state (D3)"
  fi
}

# _g01_git DIR PLAIN SUB WORDS...
_g01_git() {
  local dir="$1" plain="$2" sub="$3" rest t
  shift 3
  rest="$*"
  case "$sub" in
    switch | rebase | bisect | pull) _g01_main_op "$dir" "$sub" ;;
    checkout)
      case " $rest " in
        *" -b "* | *" -B "* | *" --orphan "*) _g01_main_op "$dir" "checkout -b" ;;
        *) _g01_main_op "$dir" checkout ;;
      esac
      ;;
    reset)
      t=$(_g01_opts "$_G01_RESET_OPTS" "$@")
      word_has "$t" --hard --merge --keep && _g01_main_op "$dir" "reset $rest"
      ;;
    stash) case "$rest" in list* | show*) ;; *) _g01_main_op "$dir" stash ;; esac ;;
    clean)
      t=$(_g01_opts "$_G01_CLEAN_OPTS" "$@")
      word_has "$t" --dry-run && ! word_has "$t" --no-dry-run && return 0
      _g01_main_op "$dir" clean
      ;;
    merge)
      case " $rest " in *" --abort "*) return 0 ;; esac
      vote ask G1 "git merge"
      [ "$AUTOPILOT" = 1 ] && vote deny G1 "git merge under autopilot"
      ;;
    branch)
      t=$(_g01_opts "$_G01_BRANCH_OPTS" "$@")
      if word_has "$t" -D || { word_has "$t" --delete && word_has "$t" --force; }; then
        _g01_destructive "git branch -D"
      fi
      ;;
    worktree)
      [ "${1-}" = remove ] || return 0
      shift
      t=$(_g01_opts "$_G01_WT_REMOVE_OPTS" "$@")
      word_has "$t" --force && _g01_destructive "git worktree remove --force"
      ;;
    push) _g01_push "$dir" "$plain" "$@" ;;
  esac
}

_g01_destructive() {
  vote ask G1 "$1 discards work"
  [ "$AUTOPILOT" = 1 ] && vote deny G1 "$1 under autopilot"
}

# _g01_ref REF CUR: sets _G01_SRC and _G01_DST for one refspec: `*` for a pattern or `:`; DST
# without refs/heads/ or heads/, and CUR for HEAD or @.
_g01_ref() {
  local r="${1#+}"
  case "$r" in
    *'*'* | :) _G01_SRC='*'; _G01_DST='*'; return 0 ;;
    *:*) _G01_SRC=${r%%:*}; _G01_DST=${r#*:} ;;
    *) _G01_SRC=$r; _G01_DST=$r ;;
  esac
  case "$_G01_DST" in
    HEAD | @) _G01_DST=$2 ;;
    refs/heads/*) _G01_DST=${_G01_DST#refs/heads/} ;;
    heads/*) _G01_DST=${_G01_DST#heads/} ;;
  esac
}

# _g01_quiet_redirect REDIR: exit 0 for a redirection that writes no file: to /dev/null, or an fd copy.
_g01_quiet_redirect() {
  local r="${1#"${1%%[!0-9]*}"}"
  case "$r" in '>&'[0-9] | '>/dev/null' | '>>/dev/null' | '&>/dev/null' | '&>>/dev/null') return 0 ;; esac
  return 1
}

# _g01_only AUTHORS ME: every line of AUTHORS is ME.
_g01_only() {
  local a
  while IFS= read -r a; do
    [ -z "$a" ] || [ "$a" = "$2" ] || return 1
  done <<EOT
$1
EOT
  return 0
}

# _g01_own DIR REMOTE SRC DST: every commit on SRC past origin/<base>, and on REMOTE's DST when
# that ref exists, was authored by user.email. A lookup error, or a REMOTE that `git remote` does
# not list, counts as not own.
_g01_own() {
  local me base a
  [ -n "$2" ] && word_has "$(git -C "$1" remote 2>/dev/null)" "$2" || return 1
  me=$(git -C "$1" config user.email 2>/dev/null) && [ -n "$me" ] || return 1
  base=$(base_branch_name) || return 1
  a=$(git -C "$1" log --format=%ae "origin/$base..$3" 2>/dev/null) || return 1
  _g01_only "$a" "$me" || return 1
  git -C "$1" rev-parse --verify -q "refs/remotes/$2/$4" >/dev/null || return 0
  a=$(git -C "$1" log --format=%ae "origin/$base..refs/remotes/$2/$4" 2>/dev/null) || return 1
  _g01_only "$a" "$me"
}

# _g01_own_refs DIR REMOTE CUR REFS...: _g01_own for the source and destination of each refspec,
# or HEAD to CUR when there is none.
_g01_own_refs() {
  local dir="$1" remote="$2" cur="$3" r
  shift 3
  if [ $# -eq 0 ]; then
    _g01_own "$dir" "$remote" HEAD "$cur"
    return
  fi
  for r in "$@"; do
    _g01_ref "$r" "$cur"
    _g01_own "$dir" "$remote" "$_G01_SRC" "$_G01_DST" || return 1
  done
}

# _g01_proven DIR PLAIN ODD CUR REMOTE REFS...: the one push shape G1 may allow. All hold: the Bash
# command is this single git record, with no $( ) or backticks; the record is `git`, -C options,
# `push` (PLAIN 1), and every push option is in the safe set or a quiet redirection (ODD 0);
# REMOTE is a name `git remote` lists, with no push, mirror or receivepack config; there is at
# least one refspec, and each pushes CUR (a branch) to CUR.
_g01_proven() {
  local dir="$1" plain="$2" odd="$3" cur="$4" remote="$5" r s d k
  shift 5
  [ "$_G01_NREC" = 1 ] && [ "$plain" = 1 ] && [ "$odd" = 0 ] && [ $# -gt 0 ] && [ -n "$remote" ] || return 1
  # shellcheck disable=SC2016 # a literal $( in the text
  case "$_G01_CMD" in *'$('* | *'`'*) return 1 ;; esac
  case "$cur" in "" | HEAD) return 1 ;; esac
  for r in "$@"; do
    case "$r" in *:*) s=${r%%:*}; d=${r#*:} ;; *) s=$r; d=$cur ;; esac
    case "$s" in "$cur" | HEAD | @ | "refs/heads/$cur") ;; *) return 1 ;; esac
    case "$d" in "$cur" | "refs/heads/$cur") ;; *) return 1 ;; esac
  done
  word_has "$(git -C "$dir" remote 2>/dev/null)" "$remote" || return 1
  while IFS= read -r k; do
    case "${k%% *}" in "remote.$remote.push" | "remote.$remote.mirror" | "remote.$remote.receivepack") return 1 ;; esac
  done <<EOT
$(git -C "$dir" config --get-regexp '^remote\..*\.(push|mirror|receivepack)$' 2>/dev/null)
EOT
  return 0
}

# _g01_push DIR PLAIN WORDS...: force first, then push.policy deny, remote delete, an unknown
# directory, protected targets and lease pushes; an allow needs _g01_proven.
_g01_push() {
  local dir="$1" plain="$2" toks t r cur policy force=none del=0 odd=0 val=0 all=0 have=0 prot=0
  local remote="" refs=() tg=()
  shift 2
  toks=$(_g01_opts "$_G01_PUSH_OPTS" "$@")
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    case "$t" in
      --force | --mirror) force=hard ;;
      --force-with-lease | --force-if-includes) [ "$force" = hard ] || force=lease ;;
      --force-with-lease=*) [ "$force" = hard ] || force=lease; val=1 ;;
      --delete) del=1 ;;
      --all | --branches) all=1 ;;
      @*) if [ "$have" = 0 ]; then remote=${t#@}; have=1; else refs+=("${t#@}"); fi ;;
    esac
    # The safe set: anything else makes the push unproven. --no-verify is outside it, because
    # it skips the pre-push hook.
    case "$t" in
      --set-upstream | --quiet | --verbose | --force-with-lease | @*) ;;
      ">"*) _g01_quiet_redirect "${t#>}" || odd=1 ;;
      *) odd=1 ;;
    esac
  done <<EOT
$toks
EOT
  for r in "${refs[@]}"; do
    case "$r" in +*) force=hard ;; esac
    case "${r#+}" in :?*) del=1 ;; tag | ^*) odd=1 ;; esac
  done
  if [ "$force" = hard ]; then
    vote deny G1 "plain force push (--force, -f, +refspec or --mirror); use --force-with-lease on your own branch"
    return 0
  fi
  policy=$(policy_for push)
  if [ "$policy" = deny ]; then
    vote deny G1 "push.policy deny"
    return 0
  fi
  if [ "$del" = 1 ]; then
    vote ask G1 "git push deleting a remote branch; deletion always needs the user's word"
    [ "$AUTOPILOT" = 1 ] && vote deny G1 "remote branch delete under autopilot"
    return 0
  fi
  if [ -z "$dir" ]; then
    vote ask G1 "git push after cd, --git-dir or --work-tree: what it pushes is unknown"
    [ "$AUTOPILOT" = 1 ] && vote deny G1 "git push from an unknown directory under autopilot"
    return 0
  fi
  cur=$(current_branch "$dir")
  [ "$all" = 1 ] && tg+=("*")
  [ ${#refs[@]} -gt 0 ] || tg+=("$cur")
  for r in "${refs[@]}"; do
    _g01_ref "$r" "$cur"
    tg+=("$_G01_DST")
  done
  for t in "${tg[@]}"; do
    branch_protected "$t" || continue
    prot=1
    vote ask G1 "push to protected branch $t"
    [ "$AUTOPILOT" = 1 ] && vote deny G1 "push to protected branch $t under autopilot"
  done
  [ "$prot" = 0 ] || return 0
  if [ "$force" = lease ]; then
    if [ "$AUTOPILOT" = 0 ]; then
      if _g01_own_refs "$dir" "$remote" "$cur" "${refs[@]}"; then
        vote ask G1 "force-with-lease push of ${tg[*]}"
      else
        vote deny G1 "${tg[*]} may hold commits by other authors (or that could not be checked); a shared branch is never force-pushed"
      fi
    elif [ "$(settings_get rebase.push ask)" != autopilot ]; then
      vote deny G1 "lease push under autopilot needs rebase.push: autopilot"
    elif [ "$val" = 1 ]; then
      vote deny G1 "--force-with-lease=<ref>:<expect> under autopilot; use the bare option"
    elif ! _g01_proven "$dir" "$plain" "$odd" "$cur" "$remote" "${refs[@]}"; then
      vote deny G1 "autopilot lease push only as git [-C dir] push --force-with-lease <remote> $cur, alone in the command"
    elif ! _g01_own_refs "$dir" "$remote" "$cur" "${refs[@]}"; then
      vote deny G1 "lease push of $cur: not every commit is yours, or that could not be checked"
    else
      vote allow G1 "lease push of own branch $cur (rebase.push: autopilot)"
    fi
    return 0
  fi
  if _g01_proven "$dir" "$plain" "$odd" "$cur" "$remote" "${refs[@]}"; then
    if [ "$AUTOPILOT" = 1 ]; then
      vote allow G1 "autopilot push of the current branch $cur"
    elif [ "$policy" = auto ]; then
      vote allow G1 "push.policy auto: push $cur"
    else
      vote ask G1 "push $cur"
    fi
  elif [ "$AUTOPILOT" = 1 ]; then
    vote deny G1 "autopilot pushes only the current branch, as git [-C dir] push [-u] <remote> $cur, alone in the command"
  elif [ "$policy" = auto ]; then
    vote ask G1 "push ${tg[*]}: push.policy auto covers only a plain push of the current branch, alone in the command"
  else
    vote ask G1 "push ${tg[*]}"
  fi
}
