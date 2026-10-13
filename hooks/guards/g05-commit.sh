# shellcheck shell=bash
# G5 commit: message convention and attribution checks, explicit staging, commit.policy.
# An allow approves the whole Bash call, so G5 allows a commit only in the shape _g05_proven accepts;
# any other passing commit asks, or is denied under autopilot. Options are read with G1's _g01_opts,
# and the shape is checked with G1's _g01_filter and _g01_quiet_redirect and G2's _gh_literal and
# _gh_file_ok: the dispatcher sources every guard before it calls any. G6 reads commits with
# _g05_split and _g05_message.

# Option tables for _g01_opts, from `git commit -h` and `git add -h` (git 2.54); commit also takes
# the hidden --allow-empty and --allow-empty-message.
_G05_COMMIT_OPTS="quiet/q/0 verbose/v/0 file/F/1 author/-/1 date/-/1 message/m/1 \
reedit-message/c/1 reuse-message/C/1 fixup/-/1 squash/-/1 reset-author/-/0 trailer/-/1 \
signoff/s/0 template/t/1 edit/e/0 cleanup/-/1 status/-/0 gpg-sign/S/o all/a/0 include/i/0 \
interactive/-/0 patch/p/0 unified/U/1 inter-hunk-context/-/1 only/o/0 no-verify/n/0 verify/-/0 \
dry-run/-/0 short/-/0 branch/-/0 ahead-behind/-/0 porcelain/-/0 long/-/0 null/z/0 amend/-/0 \
no-post-rewrite/-/0 post-rewrite/-/0 untracked-files/u/o pathspec-from-file/-/1 \
pathspec-file-nul/-/0 allow-empty/-/0 allow-empty-message/-/0"
_G05_ADD_OPTS="dry-run/n/0 verbose/v/0 interactive/i/0 patch/p/0 auto-advance/-/0 unified/U/1 \
inter-hunk-context/-/1 edit/e/0 force/f/0 update/u/0 renormalize/-/0 intent-to-add/N/0 all/A/0 \
ignore-removal/-/0 refresh/-/0 ignore-errors/-/0 ignore-missing/-/0 sparse/-/0 chmod/-/1 \
pathspec-from-file/-/1 pathspec-file-nul/-/0"

guard_g05() {
  [ "$TOOL" = Bash ] || return 0
  local cmd rec i=0 moved=0
  cmd=$(ti_get command) || return 0
  _G05_CMD=$cmd
  _G05_RECS=()
  while IFS= read -r rec; do [ -n "$rec" ] && _G05_RECS+=("$rec"); done <<EOT
$(git_words "$cmd")
EOT
  while [ "$i" -lt "${#_G05_RECS[@]}" ]; do
    if _g05_split "${_G05_RECS[$i]}"; then
      [ "$moved" = 1 ] && _G05_MOVED=1
      if ! declare -F _g01_foreign >/dev/null; then
        vote ask G5 "kern could not load the list of git's own commands"
      elif _g01_foreign G5 "$_G05_SUB"; then
        i=$((i + 1))
        continue
      fi
      case "$_G05_SUB" in
        add | stage) _g05_add "${_G05_RECS[$i]}" ;;
        commit) _g05_commit "$i" ;;
      esac
    else
      # After a cd, or an exported GIT_DIR or GIT_WORK_TREE, later git commands run where G5 cannot
      # tell.
      case "${_G05_HEAD##*/}" in cd | pushd | popd | builtin) moved=1 ;; esac
      _g05_env_has later GIT_DIR GIT_WORK_TREE && moved=1
    fi
    i=$((i + 1))
  done
}

# _g05_ready: G1's and G2's parsers are loaded.
_g05_ready() {
  declare -F _g01_opts _g01_filter _g01_quiet_redirect _gh_literal _gh_file_ok >/dev/null
}

# _g05_split RECORD: reads a git record (any case, any path) into _G05_DIR (where git runs: CWD, then
# each -C), _G05_SUB, _G05_ARGS (the words after the subcommand), _G05_PLAIN (1 when only -C pairs
# come before the subcommand), _G05_CROSS (1 when a -C leaves this session's repository),
# _G05_CONFIG (1 with -c or --config-env) and _G05_MOVED (1 with --git-dir or --work-tree, or a
# GIT_DIR or GIT_WORK_TREE assignment). _G05_HEAD is the first word and _G05_ENV what _g05_env
# prints, read for every record. Exit 1 when the record is not git with a subcommand.
_g05_split() {
  local w=() t i=1 n d
  while IFS= read -r t; do w+=("$t"); done <<EOT
$(_cmd_words "$1")
EOT
  _G05_HEAD=${w[0]-}
  _G05_DIR=${CWD:-$PWD}
  _G05_SUB=""
  _G05_ARGS=()
  _G05_PLAIN=1
  _G05_CROSS=0
  _G05_CONFIG=0
  _G05_MOVED=0
  _G05_ENV=""
  case "$1" in *=* | *[Ee][Nn][Vv]* | *[Ss][Uu][Dd][Oo]* | *declare* | *typeset*) _G05_ENV=$(_g05_env "$1") ;; esac
  _g05_env_has now GIT_DIR GIT_WORK_TREE && _G05_MOVED=1
  case "$_G05_HEAD" in [Gg][Ii][Tt] | */[Gg][Ii][Tt]) ;; *) return 1 ;; esac
  n=${#w[@]}
  while [ "$i" -lt "$n" ]; do
    case "${w[$i]}" in
      -C)
        d=${w[$((i + 1))]-}
        case "$d" in /*) _G05_DIR=$d ;; *) _G05_DIR="$_G05_DIR/$d" ;; esac
        [ -n "${KERN_MAIN-}" ] && [ "$(kern_main_root "$_G05_DIR" 2>/dev/null)" = "$KERN_MAIN" ] || _G05_CROSS=1
        i=$((i + 2))
        ;;
      --git-dir | --work-tree) _G05_MOVED=1; _G05_PLAIN=0; i=$((i + 2)) ;;
      --git-dir=* | --work-tree=*) _G05_MOVED=1; _G05_PLAIN=0; i=$((i + 1)) ;;
      -c | --config-env) _G05_CONFIG=1; _G05_PLAIN=0; i=$((i + 2)) ;;
      --config-env=*) _G05_CONFIG=1; _G05_PLAIN=0; i=$((i + 1)) ;;
      --namespace | --super-prefix | --attr-source) _G05_PLAIN=0; i=$((i + 2)) ;;
      -*) _G05_PLAIN=0; i=$((i + 1)) ;;
      *) break ;;
    esac
  done
  [ "$i" -lt "$n" ] || return 1
  _G05_SUB=${w[$i]}
  i=$((i + 1))
  while [ "$i" -lt "$n" ]; do
    _G05_ARGS+=("${w[$i]}")
    i=$((i + 1))
  done
}

# _g05_env RECORD: what RECORD changes in the environment of the command it runs, one line each:
# NAME for a VAR=value or VAR+=value word before the command word (after the wrappers env, sudo,
# command, builtin, exec, nice, nohup, time and timeout, in any case, and their options: the value
# options are _cmd_words' `cw_opt`); +NAME when the assignment outlives the record (an export or
# declare -x command, behind wrappers or not, or a record that is only assignments); @cwd when env
# -C/--chdir or sudo -D/-R/--chdir/--chroot changes the directory. Never a substring of an argument.
_g05_env() {
  _shell_words "$1" | LC_ALL=C awk -v sq="'" "$_GW_AWK"'
    BEGIN {
      n = split("env sudo command builtin exec nice nohup time timeout", a, " ")
      for (k = 1; k <= n; k++) wrap[a[k]] = 1
    }
    function asg(s) { sub(/\+?=.*/, "", s); names[++m] = s }
    dx && /^-/ { if ($0 ~ /x/) ex = 1; next }
    dx { dx = 0; if (!ex) done = 1 }
    ex { if ($0 ~ /^[A-Za-z_][A-Za-z0-9_]*\+?=/) asg($0); next }
    done { next }
    skip { skip = 0; next }
    /^[0-9]*(<|>|&>)/ { if ($0 ~ /^[0-9]*[<>&|]+$/) skip = 1; next }
    /^(if|then|elif|else|do|while|until|!|\{)$/ { w = ""; next }
    /^[A-Za-z_][A-Za-z0-9_]*\+?=/ { asg($0); next }
    { b = $0; sub(/.*\//, "", b); lb = tolower(b) }
    lb in wrap { w = lb; dur = (lb == "timeout"); next }
    /^-/ && w != "" {
      if (w == "env" && ($0 ~ /^--c/ || $0 ~ /^-[^-]*C/)) print "@cwd"
      if (w == "sudo" && ($0 ~ /^--c[hr]/ || $0 ~ /^-[^-]*[DR]/)) print "@cwd"
      if (index(cw_opt[w], " " $0 " ")) skip = 1
      next
    }
    dur { dur = 0; next }
    # The command word: export, declare and typeset assign for the records after.
    b == "export" { ex = 1; next }
    b == "declare" || b == "typeset" { dx = 1; next }
    { done = 1 }
    END { for (k = 1; k <= m; k++) print ((ex || !done) ? "+" : "") names[k] }'
}

# _g05_env_has WHEN GLOB...: exit 0 when a line of _G05_ENV matches a GLOB. WHEN `now` reads every
# line (NAME, +NAME, @cwd); `later` reads only the +NAME lines, which hold for the records after.
_g05_env_has() {
  local when="$1" l g
  shift
  while IFS= read -r l; do
    case "$when:$l" in
      later:+*) l=${l#+} ;;
      later:*) continue ;;
      now:+*) l=${l#+} ;;
    esac
    for g in "$@"; do
      # shellcheck disable=SC2254
      case "$l" in $g) return 0 ;; esac
    done
  done <<EOT
$_G05_ENV
EOT
  return 1
}

_g05_broad() {
  vote ask G5 "$1 stages every change; stage named files with git add -- <paths>"
  [ "$AUTOPILOT" = 1 ] && vote deny G5 "$1 under autopilot"
}

# _g05_add RECORD: git add or git stage that may stage every change: -A, -u, --renormalize or
# --no-ignore-removal in any spelling, --pathspec-from-file, an option kern cannot read, a word of
# RECORD that expands (_gh_literal: $, backticks, globs, ~, braces), or a pathspec _g05_wide calls
# wide.
_g05_add() {
  local toks t why=""
  if ! _g05_ready; then
    _g05_broad "git $_G05_SUB (kern could not load its option parser)"
    return 0
  fi
  _gh_literal "$1" || why="with a word that expands"
  toks=$(_g01_opts "$_G05_ADD_OPTS" "${_G05_ARGS[@]}")
  while IFS= read -r t; do
    case "$t" in
      --all | --no-ignore-removal | --update | --renormalize | --pathspec-from-file=*) why=${t%%=*} ;;
      "?"*) why="${t#\?} (an option kern cannot read)" ;;
      @*) _g05_wide "${t#@}" && why=${t#@} ;;
    esac
  done <<EOT
$toks
EOT
  [ -n "$why" ] && _g05_broad "git $_G05_SUB $why"
  return 0
}

# _g05_wide PATHSPEC: exit 0 when PATHSPEC may stage the whole tree: `.` or `..` in any spelling,
# pathspec magic (`:/`, `:!x`), a $, glob or ~ that could expand to it, the worktree root by any
# spelling (git rev-parse --show-prefix is empty there, whatever the case of the path), or any path
# after cd, --git-dir or --work-tree.
_g05_wide() {
  local s="$1" p
  [ "$_G05_MOVED" = 1 ] && return 0
  case "$s" in "" | :* | *'$'* | *'*'* | *'?'* | *'['* | '~'*) return 0 ;; esac
  p=$s
  while :; do
    case "$p" in
      */) p=${p%/} ;;
      */.) p=${p%/.} ;;
      ./?*) p=${p#./} ;;
      *) break ;;
    esac
  done
  case "$p" in . | .. | ../*) return 0 ;; esac
  case "$s" in /*) ;; *) s="$_G05_DIR/$s" ;; esac
  [ -d "$s" ] || return 1
  p=$(git -C "$s" -c core.fsmonitor=false rev-parse --show-prefix 2>/dev/null) || return 1
  [ -z "$p" ]
}

# _g05_log DIR REF: REF's commit message. --end-of-options keeps a REF such as --output=<file> from
# being read as a git log option.
_g05_log() {
  git -C "$1" -c core.fsmonitor=false log -1 --no-show-signature --no-color --format=%B --end-of-options "$2" -- 2>/dev/null
}

# _g05_message DIR TOKS [raw]: prints the commit message from _g01_opts tokens: the -F file, else
# every -m joined as paragraphs, else the -C commit's message (or -c's with --no-edit), else HEAD's
# with --amend --no-edit; --trailer values follow as the last paragraph. Exit 1 when the message
# cannot be read: an editor commit (no source, -e, or -c without --no-edit), --fixup or --squash,
# -F - or a file that is not regular, or a -m holding $( or a backtick. With `raw` (G6) it prints
# whatever text it found and exits 0.
_g05_message() {
  local dir="$1" raw="${3-}" t msg="" have=0 f="" ref="" reedit=0 amend=0 edit="" gen=0 tr="" text="" ok=1
  while IFS= read -r t; do
    case "$t" in
      --message=*) msg="${msg:+$msg

}${t#--message=}"; have=1 ;;
      --file=*) f=${t#--file=} ;;
      --reuse-message=*) ref=${t#*=}; reedit=0 ;;
      --reedit-message=*) ref=${t#*=}; reedit=1 ;;
      --trailer=*) tr="${tr:+$tr
}${t#--trailer=}" ;;
      --amend) amend=1 ;;
      --no-amend) amend=0 ;;
      --edit) edit=1 ;;
      --no-edit) edit=0 ;;
      --fixup=* | --squash=*) gen=1 ;;
    esac
  done <<EOT
$2
EOT
  if [ -n "$f" ]; then
    case "$f" in - | /*) ;; *) f="$dir/$f" ;; esac
    if [ "$f" != - ] && [ -f "$f" ]; then text=$(cat "$f"); else ok=0; fi
  elif [ "$have" = 1 ]; then
    text=$msg
    # shellcheck disable=SC2016 # a literal $( in the text
    case "$msg" in *'$('* | *'`'*) ok=0 ;; esac
  elif [ -n "$ref" ]; then
    text=$(_g05_log "$dir" "$ref") || ok=0
    [ "$reedit" = 1 ] && [ "$edit" != 0 ] && ok=0
  elif [ "$amend" = 1 ] && [ "$edit" = 0 ]; then
    text=$(_g05_log "$dir" HEAD) || ok=0
  else
    ok=0
  fi
  [ "$edit" = 1 ] && ok=0
  [ "$gen" = 1 ] && ok=0
  [ -n "$tr" ] && text="${text:+$text

}$tr"
  [ "$ok" = 1 ] || [ "$raw" = raw ] || return 1
  # A newline inside a quoted -m word arrives as git_words' \037; give the message its lines back.
  printf '%s\n' "${text//$_GW_NL/$'\n'}"
}

# _g05_problems DIR MESSAGE: one line per failed check; nothing when the message passes.
_g05_problems() {
  local dir="$1" msg="$2" subject conv src idre branch id
  subject=$(printf '%s\n' "$msg" | sed -n '/[^[:space:]]/{p;q;}')
  if [ "$(settings_get commit.attribution none)" = none ] &&
    printf '%s\n' "$msg" | grep -Eiq 'co-authored-by:.*(claude|anthropic)|generated (with|by) .*claude|claude-session:|claude\.ai/code|(co-authored-by|assisted-by|generated-by)[[:space:]]*[:=].*(claude|anthropic)'; then
    echo "attribution trailer present (commit.attribution: none)"
  fi
  # Unset, the convention is the one kern-detect finds in git log; with none found, none is checked.
  if conv=$(settings_get commit.convention); then
    src=""
  else
    conv=$(cd "$dir" && bash "$KERN_ROOT/scripts/kern-detect" commit.convention 2>/dev/null) || conv=""
    conv=${conv%%$'\t'*}
    src=", detected from git log"
  fi
  if [ -n "$conv" ] && ! printf '%s\n' "$subject" | grep -Eq -- "$conv"; then
    echo "subject does not match commit.convention $conv$src"
  fi
  idre=$(settings_get commit.id_from_branch '[A-Z][A-Z0-9]+-[0-9]+')
  branch=$(current_branch "$dir")
  id=$(printf '%s\n' "$branch" | grep -Eo -- "$idre" | head -n 1)
  if [ -n "$id" ]; then
    # The id counts only when a non-alphanumeric character or the end follows it: CDS-24650 is not
    # CDS-2465.
    printf '%s\n' "$subject" | LC_ALL=C awk -v id="$id" '
      { s = $0; while ((i = index(s, id)) > 0) { if (substr(s, i + length(id), 1) !~ /[A-Za-z0-9]/) { f = 1; exit } s = substr(s, i + 1) } }
      END { exit !f }' || echo "subject lacks the ticket id $id from branch $branch"
  fi
}

# _g05_file_ok DIR FILE: the -F file, relative to DIR, passes G2's _gh_file_ok: a regular file and
# not a symlink, inside the main worktree and not under .git, and in .kern or not ignored by git.
_g05_file_ok() {
  local f="$2"
  [ "$f" != - ] || return 1
  case "$f" in /*) ;; *) f="$1/$f" ;; esac
  _gh_file_ok "$f"
}

# _g05_proven IDX TOKS: the commit at IDX in _G05_RECS, just read by _g05_split and _g01_opts (TOKS),
# may be allowed as the whole Bash call. All hold: it is the command's first record and starts with
# `git `, so no cd, assignment, wrapper, function or alias comes before it; every later record is a
# read-only filter (_g01_filter); the command has no $( ) or backticks; no word of the record
# expands (_gh_literal); only -C pairs that stay in this repository come before `commit`; every
# option is -m, -F, -q or -v, with exactly one -m or -F and no pathspec; every redirection is quiet;
# the -F file passes _g05_file_ok; HEAD is on a branch that branch_protected does not cover.
# On failure _G05_WHY says which check failed.
_g05_proven() {
  local t i=1 src=0 f=""
  _G05_WHY=""
  _g05_ready || { _G05_WHY="kern could not load its parsers"; return 1; }
  [ "$1" = 0 ] || { _G05_WHY="other commands come before it"; return 1; }
  case "${_G05_RECS[0]}" in "git "*) ;; *) _G05_WHY="it does not start with git"; return 1 ;; esac
  # shellcheck disable=SC2016 # a literal $( in the text
  case "$_G05_CMD" in *'$('* | *'`'*) _G05_WHY="command substitution"; return 1 ;; esac
  _gh_literal "${_G05_RECS[0]}" || { _G05_WHY="a word expands"; return 1; }
  while [ "$i" -lt "${#_G05_RECS[@]}" ]; do
    _g01_filter "${_G05_RECS[$i]}" || { _G05_WHY="other commands follow it"; return 1; }
    i=$((i + 1))
  done
  [ "$_G05_PLAIN" = 1 ] || { _G05_WHY="git options other than -C"; return 1; }
  [ "$_G05_CROSS" = 0 ] || { _G05_WHY="-C leaves this repository"; return 1; }
  while IFS= read -r t; do
    case "$t" in
      "" | --quiet | --verbose) ;;
      --message=*) src=$((src + 1)) ;;
      --file=*) src=$((src + 1)); f=${t#--file=} ;;
      ">"*) _g01_quiet_redirect "${t#>}" || { _G05_WHY="a redirection to a file"; return 1; } ;;
      @*) _G05_WHY="a pathspec"; return 1 ;;
      *) t=${t#\?}; _G05_WHY="option ${t%%=*}"; return 1 ;;
    esac
  done <<EOT
$2
EOT
  [ "$src" = 1 ] || { _G05_WHY="not exactly one -m or -F"; return 1; }
  if [ -n "$f" ] && ! _g05_file_ok "$_G05_DIR" "$f"; then
    _G05_WHY="the -F file is not a regular file in the repo"
    return 1
  fi
  t=$(current_branch "$_G05_DIR") || { _G05_WHY="HEAD is detached"; return 1; }
  if branch_protected "$t"; then
    _G05_WHY="$t is a protected branch"
    return 1
  fi
}

# _g05_commit IDX: the commit at IDX in _G05_RECS, just read by _g05_split.
_g05_commit() {
  local toks msg problems policy fix
  if ! _g05_ready; then
    vote ask G5 "kern could not load its option parser, so this commit cannot be checked"
    return 0
  fi
  toks=$(_g01_opts "$_G05_COMMIT_OPTS" "${_G05_ARGS[@]}")
  if word_has "$toks" --all; then
    _g05_broad "git commit -a"
  fi
  if ! msg=$(_g05_message "$_G05_DIR" "$toks"); then
    vote ask G5 "commit message cannot be read: write the message with -m '<text>' or -F <file in the repo>; a \$( ) message cannot be checked"
    return 0
  fi
  problems=$(_g05_problems "$_G05_DIR" "$msg")
  if [ -n "$problems" ]; then
    vote deny G5 "$(printf '%s\n' "$problems" | paste -sd ';' - | sed 's/;/; /g')"
    return 0
  fi
  policy=$(policy_for commit)
  if [ "$policy" = deny ]; then
    vote deny G5 "commit.policy deny"
    return 0
  fi
  if [ "$AUTOPILOT" != 1 ] && [ "$policy" != auto ]; then
    vote ask G5 "commit (message checks pass)"
    return 0
  fi
  if _g05_proven "$1" "$toks"; then
    if [ "$AUTOPILOT" = 1 ]; then
      vote allow G5 "autopilot commit: message checks pass"
    else
      vote allow G5 "commit.policy auto: message checks pass"
    fi
    return 0
  fi
  # shellcheck disable=SC2016 # literal backticks
  fix='kern allows only `git commit -m <msg>` or `git commit -F <file in the repo>` alone, with -q or -v, on an unprotected branch'
  vote ask G5 "commit of a shape kern cannot prove ($_G05_WHY); $fix"
  [ "$AUTOPILOT" = 1 ] && vote deny G5 "unproven commit under autopilot ($_G05_WHY); $fix"
  return 0
}
