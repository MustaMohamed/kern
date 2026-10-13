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
# The read-only filters an allowed push may pipe into (_g01_filter). None of these options reads
# a file. head and tail also take -NUM.
_G01_TAIL_OPTS="lines/n/1 bytes/c/1 quiet/q/0 silent/-/0 verbose/v/0"
_G01_HEAD_OPTS="lines/n/1 bytes/c/1 quiet/q/0 silent/-/0 verbose/v/0"
_G01_GREP_OPTS="regexp/e/1 ignore-case/i/0 invert-match/v/0 extended-regexp/E/0 \
fixed-strings/F/0 basic-regexp/G/0 word-regexp/w/0 line-regexp/x/0 count/c/0 line-number/n/0 \
only-matching/o/0 quiet/q/0 silent/-/0 no-messages/s/0 max-count/m/1 after-context/A/1 \
before-context/B/1 context/C/1 color/-/o colour/-/o"
_G01_CAT_OPTS="number/n/0 number-nonblank/b/0 squeeze-blank/s/0 show-nonprinting/v/0 \
show-ends/E/0 show-tabs/T/0 show-all/A/0 -/e/0 -/t/0 -/u/0"
# The characters a branch or remote name may hold in an allowed push; no shell expands any of them.
_G01_NAME_CHARS="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._/-"

guard_g01() {
  [ "$TOOL" = Bash ] || return 0
  local cmd rec w=() t moved=0
  cmd=$(ti_get command) || { fail_closed "Bash call without a command"; return 0; }
  _G01_RECS=()
  while IFS= read -r rec; do [ -n "$rec" ] && _G01_RECS+=("$rec"); done <<EOT
$(git_words "$cmd")
EOT
  _G01_CMD=$cmd
  _G01_IDX=0
  while [ "$_G01_IDX" -lt "${#_G01_RECS[@]}" ]; do
    rec=${_G01_RECS[$_G01_IDX]}
    _G01_IDX=$((_G01_IDX + 1))
    w=()
    while IFS= read -r t; do w+=("$t"); done <<EOT
$(_cmd_words "$rec")
EOT
    # After a cd, or a GIT_DIR or GIT_WORK_TREE assignment, later git commands run where G1
    # cannot tell.
    case "$rec" in *GIT_DIR=* | *GIT_WORK_TREE=* | *GIT_DIR+=* | *GIT_WORK_TREE+=*) moved=1 ;; esac
    case "${w[0]}" in
      cd | pushd | popd) moved=1 ;;
      builtin) case "${w[1]-}" in cd | pushd | popd) moved=1 ;; esac ;;
      # Any case: on a case-insensitive file system GIT and GH run git and gh.
      [Gg][Hh] | */[Gg][Hh]) _g01_gh "$rec" "${w[@]}" ;;
      [Gg][Ii][Tt] | */[Gg][Ii][Tt]) _g01_git_rec "$rec" "$moved" "${w[@]}" ;;
    esac
    case "${w[0]}" in "" | [Gg][Hh] | */[Gg][Hh] | [Gg][Ii][Tt] | */[Gg][Ii][Tt]) ;; *) _g01_hidden "${w[@]}" ;; esac
  done
}

# Git's own commands that only read, which a git behind another command may run (_g01_hidden).
_G01_READ_ONLY=" status log diff show rev-parse ls-files ls-remote blame describe grep help version cat-file \
shortlog for-each-ref merge-base name-rev count-objects var "

# _g01_hidden HEAD WORDS...: a simple command whose head is neither git nor gh may still run git: an
# unknown wrapper (caffeinate, stdbuf), xargs, find -exec, or a wrapper option _cmd_words does not
# read (env --ch, env -iC). Each later word whose basename is git (any case) is read past git's
# global options; when the next word is one of git's own commands outside _G01_READ_ONLY, G1 asks,
# deny under autopilot. Any other word after it (curl in `apt-get install git curl`, an option git
# rejects) gets no vote. Quoted text is one word, so `grep -rn "git push" docs` holds no word git,
# while `echo git push` asks. A -c or --config-env that sets alias.* (any case) asks whatever word
# follows, since the alias may stand for any command; an alias set in git config is not seen.
_g01_hidden() {
  local head="$1" al
  shift
  while [ $# -gt 0 ]; do
    case "${1##*/}" in
      [Gg][Ii][Tt]) shift ;;
      *) shift; continue ;;
    esac
    al=0
    while [ $# -gt 0 ]; do
      case "$1" in
        -c | --config-env)
          shift
          case "${1-}" in [Aa][Ll][Ii][Aa][Ss].*) al=1 ;; esac
          [ $# -gt 0 ] && shift
          ;;
        --config-env=[Aa][Ll][Ii][Aa][Ss].*) al=1; shift ;;
        -C | --git-dir | --work-tree | --namespace | --super-prefix | --attr-source | --shallow-file)
          shift
          [ $# -gt 0 ] && shift
          ;;
        --git-dir=* | --work-tree=* | --namespace=* | --config-env=* | --super-prefix=* | --attr-source=* | \
          --exec-path=* | -p | -P | --paginate | --no-pager | --bare | --no-replace-objects | --no-lazy-fetch | \
          --no-optional-locks | --no-advice | --literal-pathspecs | --no-literal-pathspecs | --glob-pathspecs | \
          --noglob-pathspecs | --icase-pathspecs) shift ;;
        *) break ;;
      esac
    done
    if [ "$al" = 0 ]; then
      [ $# -gt 0 ] || return 0
      case "$_G01_GIT_CMDS" in *" $1 "*) ;; *) continue ;; esac
      case "$_G01_READ_ONLY" in *" $1 "*) continue ;; esac
    fi
    vote ask G1 "git inside $head cannot be checked; run git directly"
    [ "$AUTOPILOT" = 1 ] && vote deny G1 "git inside $head under autopilot: it cannot be checked; run git directly"
    return 0
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
  _g01_foreign G1 "$1" && return 0
  _g01_git "$dir" "$plain" "$@"
}

# Git 2.54's own commands (`git --list-cmds=builtins,main`) less pack-redundant and whatchanged,
# which an alias of the same name replaces. Git runs every one of these whatever alias config says
# (checked with `git -c alias.<cmd>='!echo ...' <cmd> -h` for each), so a subcommand outside the list
# is an alias or a git-<name> program on PATH, such as git-lfs.
_G01_GIT_CMDS=" add am annotate apply archive backfill bisect blame branch bugreport bundle cat-file \
check-attr check-ignore check-mailmap check-ref-format checkout checkout--worker checkout-index cherry \
cherry-pick clean clone column commit commit-graph commit-tree config count-objects credential \
credential-cache credential-cache--daemon credential-osxkeychain credential-store daemon describe \
diagnose diff diff-files diff-index diff-pairs diff-tree difftool difftool--helper fast-export \
fast-import fetch fetch-pack filter-branch fmt-merge-msg for-each-ref for-each-repo format-patch fsck \
fsck-objects fsmonitor--daemon gc get-tar-commit-id grep gui--askpass gui--askyesno hash-object help \
history hook http-backend http-fetch http-push imap-send index-pack init init-db interpret-trailers \
last-modified log ls-files ls-remote ls-tree mailinfo mailsplit maintenance merge merge-base merge-file \
merge-index merge-octopus merge-one-file merge-ours merge-recursive merge-recursive-ours \
merge-recursive-theirs merge-resolve merge-subtree merge-tree mergetool mktag mktree multi-pack-index \
mv name-rev notes p4 pack-objects pack-refs patch-id pickaxe prune prune-packed pull push quiltimport \
range-diff read-tree rebase receive-pack reflog refs remote remote-ext remote-fd remote-ftp remote-ftps \
remote-http remote-https repack replace replay repo request-pull rerere reset restore rev-list \
rev-parse revert rm send-email send-pack sh-i18n--envsubst shell shortlog show show-branch show-index \
show-ref sparse-checkout stage stash status stripspace submodule submodule--helper subtree switch \
symbolic-ref tag unpack-file unpack-objects update-index update-ref update-server-info upload-archive \
upload-archive--writer upload-pack var verify-commit verify-pack verify-tag version web--browse \
worktree write-tree "

# _g01_foreign GUARD SUB: when SUB is not one of git's own commands, votes ask (deny under autopilot)
# as GUARD and exits 0. No config is read, so -c, HOME, XDG_CONFIG_HOME, GIT_DIR, cd and include
# paths cannot steer it. SUB may be an option word G1's loop does not know: only the options that
# end git without running a subcommand pass; any other (such as --shallow-file, which takes a value
# and hides the command after it) asks.
_g01_foreign() {
  case "$2" in
    -v | --version | -h | --help | --exec-path | --html-path | --man-path | --info-path | --list-cmds=*) return 1 ;;
  esac
  case "$_G01_GIT_CMDS" in *" $2 "*) return 1 ;; esac
  vote ask "$1" "git $2 is not one of git's own commands (an alias or an extension); run the git command it stands for so kern can check it"
  [ "$AUTOPILOT" = 1 ] && vote deny "$1" "git $2 under autopilot: not one of git's own commands"
  return 0
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
    HEAD | @) _G01_DST=${2:-HEAD} ;;
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
  a=$(git -C "$1" log --no-show-signature --format=%ae "origin/$base..$3" 2>/dev/null) || return 1
  _g01_only "$a" "$me" || return 1
  git -C "$1" rev-parse --verify -q "refs/remotes/$2/$4" >/dev/null || return 0
  a=$(git -C "$1" log --no-show-signature --format=%ae "origin/$base..refs/remotes/$2/$4" 2>/dev/null) || return 1
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

# _g01_filter RECORD: exit 0 when RECORD is tail, head, grep or cat with options from its table
# only (head and tail also -NUM), quiet redirections, and no file argument; grep may take its
# pattern as its one argument when no -e gives it.
_g01_filter() {
  local w=() args=() t table toks n=0 pat=0 dd=""
  case "$1" in tail | "tail "* | head | "head "* | grep | "grep "* | cat | "cat "*) ;; *) return 1 ;; esac
  # An expansion or a glob could turn a word into a file argument.
  case "$1" in *'$'* | *'{'* | *'}'* | *'*'* | *'?'* | *'['*) return 1 ;; esac
  while IFS= read -r t; do w+=("$t"); done <<EOT
$(_cmd_words "$1")
EOT
  case "${w[0]}" in
    tail) table=$_G01_TAIL_OPTS ;;
    head) table=$_G01_HEAD_OPTS ;;
    grep) table=$_G01_GREP_OPTS ;;
    cat) table=$_G01_CAT_OPTS ;;
    *) return 1 ;;
  esac
  for t in "${w[@]:1}"; do
    # -NUM is a count for head and tail, but after `--` it names a file.
    [ "$t" = -- ] && dd=1
    if [ -z "$dd" ] && { [ "${w[0]}" = tail ] || [ "${w[0]}" = head ]; }; then
      case "$t" in -*[!0-9]* | -) ;; -*) continue ;; esac
    fi
    args+=("$t")
  done
  [ ${#args[@]} -gt 0 ] || return 0
  toks=$(_g01_opts "$table" "${args[@]}")
  while IFS= read -r t; do
    case "$t" in
      "?"*) return 1 ;;
      ">"*) _g01_quiet_redirect "${t#>}" || return 1 ;;
      @*) n=$((n + 1)) ;;
      --regexp=*) pat=1 ;;
    esac
  done <<EOT
$toks
EOT
  [ "$n" = 0 ] && return 0
  [ "${w[0]}" = grep ] && [ "$n" = 1 ] && [ "$pat" = 0 ]
}

# _g01_proven DIR PLAIN ODD CUR REMOTE REFS...: the one push shape G1 may allow. All hold: this
# git record is the command's first, every later record is a read-only filter (_g01_filter), and
# the command has no $( ) or backticks; the record holds no $, {, }, *, ?, [ or ~, so no word
# expands or globs; the record is `git`, -C options, `push` (PLAIN 1), and every push option is in
# the safe set or a quiet redirection (ODD 0); CUR and REMOTE hold only _G01_NAME_CHARS; REMOTE is
# a name `git remote` lists, with no push, mirror, receivepack or vcs config, and the URL a push
# goes to is its own URL: no pushurl, and no insteadOf or pushInsteadOf rewrite applies; there is
# at least one refspec, and each pushes CUR (a branch) to CUR.
_g01_proven() {
  local dir="$1" plain="$2" odd="$3" cur="$4" remote="$5" r s d k u i=1
  shift 5
  [ "$_G01_IDX" = 1 ] && [ "$plain" = 1 ] && [ "$odd" = 0 ] && [ $# -gt 0 ] && [ -n "$remote" ] || return 1
  # shellcheck disable=SC2016 # a literal $( in the text
  case "$_G01_CMD" in *'$('* | *'`'*) return 1 ;; esac
  case "${_G01_RECS[0]}" in *'$'* | *'{'* | *'}'* | *'*'* | *'?'* | *'['* | *'~'*) return 1 ;; esac
  case "$cur" in "" | *[!"$_G01_NAME_CHARS"]*) return 1 ;; esac
  case "$remote" in *[!"$_G01_NAME_CHARS"]*) return 1 ;; esac
  while [ "$i" -lt "${#_G01_RECS[@]}" ]; do
    _g01_filter "${_G01_RECS[$i]}" || return 1
    i=$((i + 1))
  done
  for r in "$@"; do
    case "$r" in *:*) s=${r%%:*}; d=${r#*:} ;; *) s=$r; d=$cur ;; esac
    case "$s" in "$cur" | HEAD | @ | "refs/heads/$cur") ;; *) return 1 ;; esac
    case "$d" in "$cur" | "refs/heads/$cur") ;; *) return 1 ;; esac
  done
  word_has "$(git -C "$dir" remote 2>/dev/null)" "$remote" || return 1
  while IFS= read -r k; do
    case "${k%% *}" in
      "remote.$remote.push" | "remote.$remote.mirror" | "remote.$remote.receivepack" | "remote.$remote.vcs") return 1 ;;
    esac
  done <<EOT
$(git -C "$dir" config --get-regexp '^remote\..*\.(push|mirror|receivepack|vcs)$' 2>/dev/null)
EOT
  # A pushurl, or an insteadOf or pushInsteadOf rewrite that matches this remote, changes the URL.
  u=$(git -C "$dir" config --get-all "remote.$remote.url" 2>/dev/null) && [ -n "$u" ] || return 1
  [ "$(git -C "$dir" remote get-url --push --all "$remote" 2>/dev/null)" = "$u" ] || return 1
  return 0
}

# _g01_push DIR PLAIN WORDS...: force first, then push.policy deny, remote delete, an unknown
# directory, protected targets and lease pushes; an allow needs _g01_proven.
_g01_push() {
  local dir="$1" plain="$2" toks t r cur policy fix det="" force=none del=0 odd=0 val=0 all=0 have=0 prot=0
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
    # it skips the pre-push hook. --force-if-includes still follows the lease rules.
    case "$t" in
      --set-upstream | --quiet | --verbose | --dry-run | --force-with-lease | --force-if-includes | @*) ;;
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
    fix="run git -C <dir> push instead of cd, --git-dir or --work-tree"
    vote ask G1 "git push after cd, --git-dir or --work-tree: what it pushes is unknown; $fix"
    [ "$AUTOPILOT" = 1 ] && vote deny G1 "git push from an unknown directory under autopilot; $fix"
    return 0
  fi
  cur=$(current_branch "$dir")
  # The retry that reaches the allowed shape: a bare push names its remote and branch.
  if [ -z "$cur" ]; then
    fix="HEAD is detached; check out a branch first"
    det="; $fix"
  elif [ ${#refs[@]} -gt 0 ]; then
    # shellcheck disable=SC2016 # literal backticks
    fix='kern allows only `git push [-u] <remote> <current-branch>` unattended'
    # shellcheck disable=SC2016 # literal backticks
    [ "$force" = lease ] && fix='kern allows only `git push --force-with-lease <remote> <current-branch>` unattended'
  elif [ "$force" = lease ]; then
    fix="name the remote and branch: git push --force-with-lease origin $cur"
  else
    fix="name the remote and branch: git push -u origin $cur"
  fi
  [ "$all" = 1 ] && tg+=("*")
  [ ${#refs[@]} -gt 0 ] || tg+=("${cur:-HEAD}")
  for r in "${refs[@]}"; do
    _g01_ref "$r" "$cur"
    tg+=("$_G01_DST")
  done
  for t in "${tg[@]}"; do
    branch_protected "$t" || continue
    prot=1
    vote ask G1 "push to protected branch $t$det"
    [ "$AUTOPILOT" = 1 ] && vote deny G1 "push to protected branch $t under autopilot$det"
  done
  [ "$prot" = 0 ] || return 0
  if [ "$force" = lease ]; then
    if [ "$AUTOPILOT" = 0 ]; then
      if _g01_own_refs "$dir" "$remote" "$cur" "${refs[@]}"; then
        vote ask G1 "force-with-lease push of ${tg[*]}$det"
      else
        vote deny G1 "${tg[*]} may hold commits by other authors (or that could not be checked); a shared branch is never force-pushed$det"
      fi
    elif [ "$(settings_get rebase.push ask)" != autopilot ]; then
      vote deny G1 "lease push under autopilot needs rebase.push: autopilot$det"
    elif [ "$val" = 1 ]; then
      vote deny G1 "--force-with-lease=<ref>:<expect> under autopilot; use the bare option$det"
    elif ! _g01_proven "$dir" "$plain" "$odd" "$cur" "$remote" "${refs[@]}"; then
      vote deny G1 "autopilot lease push of an unknown shape; $fix"
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
    vote deny G1 "autopilot push of an unknown shape; $fix"
  else
    vote ask G1 "push ${tg[*]}; $fix"
  fi
}
