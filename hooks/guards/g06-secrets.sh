# shellcheck shell=bash
# G6 secrets: scan what a commit or push would publish, commit messages included; refuse never_commit
# paths. G6 reads only what git stores (the index for a commit, commits for a push), never the
# worktree, with color, external diff, textconv, fsmonitor, signatures, replace refs and
# diff.relative off and every file read as text, so repo config can neither hide an added line nor
# run a program here. Each walk runs under with_timeout and streams into the scan. Records are read
# with G5's _g05_split and _g05_message and options with G1's _g01_opts: the dispatcher sources every
# guard before it calls any.

# Seconds a walk may run. Under bats, KERN_SCAN_SECS shortens it.
_G06_SECS=8
[ -n "${BATS_TEST_FILENAME-}" ] && _G06_SECS=${KERN_SCAN_SECS:-8}

# Diff options for every patch G6 reads. A staged diff also takes --diff-filter=d; a push walk does
# not, because in git log it drops whole commits, messages included, and _g06_parse skips the names
# of deleted files itself.
_G06_DIFF=(--text --no-relative --no-color --no-ext-diff --no-textconv --src-prefix=a/ --dst-prefix=b/)

# Line markers in a walk's output: \035 starts a never_commit name, \034 the walk's exit code. In a
# push walk git prints \036 before each commit's hash and message and \037 after the message.
_G06_NAME=$'\035'
_G06_RC=$'\034'

# The secret rules, `name|ERE` per line. Each is matched against the text field of a scan line,
# which starts with a space, so `[^A-Za-z0-9_]` also matches at the start of the text.
_G06_RULES='private-key|-----BEGIN [A-Z ]*PRIVATE KEY-----
pgp-private-key|-----BEGIN PGP PRIVATE KEY BLOCK-----
aws-access-key|(AKIA|ASIA)[0-9A-Z]{16}
github-token|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{22,}
slack-token|xox[baprs]-[A-Za-z0-9-]{10,}
api-key|[^A-Za-z0-9_]sk-[A-Za-z0-9_-]{20,}
stripe-key|[rs]k_live_[A-Za-z0-9]{20,}
google-api-key|AIza[0-9A-Za-z_-]{35}'

guard_g06() {
  [ "$TOOL" = Bash ] || return 0
  local cmd rec moved=0
  cmd=$(ti_get command) || return 0
  while IFS= read -r rec; do
    [ -n "$rec" ] || continue
    case "$rec" in *GIT_DIR=* | *GIT_WORK_TREE=* | *GIT_INDEX_FILE=*) moved=1 ;; esac
    if ! _g06_ready; then
      case "$(git_sub "$rec" | cut -f2)" in
        commit | push) vote ask G6 "the secret scan could not load its parsers" ;;
      esac
      continue
    fi
    if ! _g05_split "$rec"; then
      # After a cd, later git commands run where G6 cannot tell.
      case "${_G05_HEAD##*/}" in cd | pushd | popd | builtin) moved=1 ;; esac
      continue
    fi
    case "$_G05_SUB" in commit | push) ;; *) continue ;; esac
    if [ "$moved" = 1 ] || [ "$_G05_MOVED" = 1 ]; then
      _g06_unscanned "could not scan: git $_G05_SUB after cd, --git-dir, --work-tree, GIT_DIR= or GIT_INDEX_FILE= reads a repository or index kern does not see"
      continue
    fi
    case "$_G05_SUB" in
      commit) _g06_commit ;;
      push) _g06_push ;;
    esac
  done <<EOT
$(git_words "$cmd")
EOT
}

# _g06_ready: G5's and G1's parsers and with_timeout are loaded.
_g06_ready() {
  declare -F _g05_split _g05_message _g01_opts with_timeout >/dev/null &&
    [ -n "${_G05_COMMIT_OPTS-}" ] && [ -n "${_G01_PUSH_OPTS-}" ]
}

# _g06_unscanned REASON: asks, and denies under autopilot.
_g06_unscanned() {
  vote ask G6 "$1"
  [ "$AUTOPILOT" = 1 ] && vote deny G6 "$1 (autopilot)"
  return 0
}

# _g06_git DIR ARGS...: git in DIR with replace refs, color and fsmonitor off and paths unquoted.
_g06_git() {
  local d="$1"
  shift
  git -C "$d" --no-replace-objects -c color.ui=never -c core.fsmonitor=false -c core.quotePath=false \
    -c log.showRoot=true "$@" 2>/dev/null
}

# _g06_parse: reads a patch, or a push walk with its \036 message records, and prints a scan line
# `<label>\t <text>` for each added line (label `path:line`) and message line (label
# `commit <hash> message:<n>`), and \035<path> for each file it adds or changes (not one it
# deletes). A `+++ ` line is a header only between a `diff` line and the first `@@`, so no text is
# taken for a path. A merge comes as a combined diff (--cc): a line counts when it is added against
# every parent.
_g06_parse() {
  LC_ALL=C awk -v nm="$_G06_NAME" -v rs=$'\036' -v us=$'\037' '
    # name(): prints the pending file name of the header just read, unless the file was deleted.
    function name() { if (pn != "") print nm pn; pn = "" }
    index($0, rs) == 1 { name(); c = substr($0, 2); m = 1; n = 0; h = 0; nc = 0; next }
    m {
      e = index($0, us)
      if (!e) { print "commit " c " message:" ++n "\t " $0; next }
      if (e > 1) print "commit " c " message:" ++n "\t " substr($0, 1, e - 1)
      m = 0; next
    }
    /^diff --git / {
      name(); h = 1; s = substr($0, 12); k = (length(s) - 5) / 2
      if (k > 0 && k == int(k) && substr(s, 1, 2) == "a/" && substr(s, k + 3, 3) == " b/" &&
        substr(s, 3, k) == substr(s, k + 6)) pn = substr(s, 3, k)
      next
    }
    /^diff --cc / { name(); h = 1; pn = substr($0, 11); next }
    /^diff --combined / { name(); h = 1; pn = substr($0, 17); next }
    /^diff / { name(); h = 1; next }
    h && /^deleted file mode/ { pn = ""; next }
    h && /^\+\+\+ / { p = substr($0, 5); sub(/^b\//, "", p); next }
    h && /^(rename|copy) to / { pn = $0; sub(/^(rename|copy) to /, "", pn); next }
    /^@@/ { name(); h = 0; match($0, /^@+/); nc = RLENGTH - 1; split($(nc + 2), a, ","); ln = substr(a[1], 2) + 0; next }
    h || nc < 1 { next }
    /^\\/ { next }
    {
      pre = substr($0, 1, nc)
      if (index(pre, "-")) next
      if (pre ~ /^\++$/) print p ":" ln "\t " substr($0, nc + 1)
      ln++
    }
    END { name() }'
}

# _g06_any: every rule as one ERE.
_g06_any() {
  local any="" rule re
  while IFS='|' read -r rule re; do any="${any:+$any|}($re)"; done <<EOT
$_G06_RULES
EOT
  printf '%s\n' "$any"
}

# _g06_keep: keeps the \035 name lines and the scan lines whose text field hits a rule.
_g06_keep() {
  LC_ALL=C grep -a -E -- "^$_G06_NAME|^[^	]*	.*($(_g06_any))"
}

# _g06_walk DIR ARGS...: `git ARGS` in DIR under with_timeout, streamed through _g06_parse and
# _g06_keep, so the patch is never held in a variable. Prints the kept lines, then \034 and the
# walk's exit code.
_g06_walk() {
  with_timeout "$_G06_SECS" _g06_git "$@" | _g06_parse | _g06_keep
  printf '%s%s\n' "$_G06_RC" "${PIPESTATUS[0]}"
}

# _g06_msg LABEL TEXT: TEXT as scan lines `LABEL:<n>\t <text>`.
_g06_msg() {
  [ -n "$2" ] || return 0
  printf '%s\n' "$2" | LC_ALL=C awk -v l="$1" '{ print l ":" NR "\t " $0 }'
}

# _g06_rules HITS: `<label> <rule>` for each rule each kept scan line hits. Never prints the text.
_g06_rules() {
  local rule re
  while IFS='|' read -r rule re; do
    printf '%s\n' "$1" | LC_ALL=C grep -a -E -- "^[^	]*	.*($re)" | LC_ALL=C cut -f1 | LC_ALL=C sed "s/\$/ $rule/"
  done <<EOT
$_G06_RULES
EOT
}

# _g06_paths NAMES: deny when a newline-separated path, or its last component, matches a
# never_commit glob. The list is comma-separated; one pair of brackets around it ([a, b]) is dropped.
_g06_paths() {
  local list glob name rest hits=""
  list=$(settings_get never_commit '')
  list=${list#"${list%%[![:space:]]*}"}
  list=${list%"${list##*[![:space:]]}"}
  case "$list" in "["*"]") list=${list#\[}; list=${list%\]} ;; esac
  [ -n "$list" ] || return 0
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    rest="$list,"
    while [ -n "$rest" ]; do
      glob=${rest%%,*}
      rest=${rest#*,}
      glob=${glob#"${glob%%[![:space:]]*}"}
      glob=${glob%"${glob##*[![:space:]]}"}
      [ -n "$glob" ] || continue
      # shellcheck disable=SC2254
      case "$name" in $glob) hits="${hits:+$hits, }$name"; break ;; esac
      # shellcheck disable=SC2254
      case "${name##*/}" in $glob) hits="${hits:+$hits, }$name"; break ;; esac
    done
  done <<EOT
$1
EOT
  [ -n "$hits" ] && vote deny G6 "never_commit paths staged: $hits"
  return 0
}

# _g06_finish OUT DIR ARGS...: votes on a walk's output OUT (plus any message scan lines): the
# never_commit names, the rule hits, and a walk that did not finish. With no hit, gitleaks (when
# installed) reads `git ARGS` again.
_g06_finish() {
  local out="$1" rc names hits
  shift
  rc=$(printf '%s\n' "$out" | LC_ALL=C sed -n "s/^$_G06_RC//p" | tail -n 1)
  names=$(printf '%s\n' "$out" | LC_ALL=C sed -n "s/^$_G06_NAME//p" | LC_ALL=C awk '!s[$0]++')
  hits=$(printf '%s\n' "$out" | LC_ALL=C grep -a -v -E "^($_G06_NAME|$_G06_RC)")
  _g06_paths "$names"
  if [ -n "$hits" ]; then
    vote deny G6 "possible secret, not committed or pushed: $(_g06_rules "$hits" | LC_ALL=C awk '!s[$0]++' | head -n 5 | paste -sd ';' - | LC_ALL=C sed 's/;/; /g')"
  fi
  if [ "$rc" != 0 ]; then
    vote ask G6 "secret scan did not finish in ${_G06_SECS} s (exit ${rc:-unknown}); check the change for secrets yourself"
  elif [ -z "$hits" ] && command -v gitleaks >/dev/null 2>&1; then
    with_timeout "$_G06_SECS" _g06_git "$@" | gitleaks stdin --no-banner --redact >/dev/null 2>&1
    [ "${PIPESTATUS[1]}" = 1 ] && vote deny G6 "gitleaks reports a secret in this change; run gitleaks yourself to see where"
  fi
  return 0
}

# _g06_commit: the commit _g05_split just read. Scans the staged diff and the message. -a, -i, -o,
# -p, --interactive, --pathspec-from-file and pathspecs commit worktree content, which G6 never
# reads: they ask, and are denied under autopilot.
_g06_commit() {
  local dir="$_G05_DIR" toks t why="" out msg args
  toks=$(_g01_opts "$_G05_COMMIT_OPTS" "${_G05_ARGS[@]}")
  while IFS= read -r t; do
    case "$t" in
      --all | --include | --only | --interactive | --patch | --pathspec-from-file=*) why=${t%%=*} ;;
      @*) why="with a pathspec" ;;
    esac
  done <<EOT
$toks
EOT
  [ -n "$why" ] && _g06_unscanned "kern scans only staged content; git commit $why commits worktree content it does not read"
  args=(diff --cached "${_G06_DIFF[@]}" --diff-filter=d)
  msg=$(_g05_message "$dir" "$toks" raw)
  out=$(_g06_walk "$dir" "${args[@]}")
  out="$out
$(_g06_msg "commit message" "$msg" | _g06_keep)"
  _g06_finish "$out" "$dir" "${args[@]}"
}

# _g06_remote DIR: the remote a push with no repository argument goes to: branch.<b>.pushRemote,
# remote.pushDefault, branch.<b>.remote, else origin.
_g06_remote() {
  local b r
  b=$(current_branch "$1") || b=""
  if [ -n "$b" ] && r=$(_g06_git "$1" config "branch.$b.pushRemote"); then
    printf '%s\n' "$r"
  elif r=$(_g06_git "$1" config remote.pushDefault); then
    printf '%s\n' "$r"
  elif [ -n "$b" ] && r=$(_g06_git "$1" config "branch.$b.remote"); then
    printf '%s\n' "$r"
  else
    printf 'origin\n'
  fi
}

# _g06_push: the push _g05_split just read. Scans, in one bounded walk, every commit it sends that
# the target remote's tracking refs do not hold, merges as combined diffs, and their messages.
# Sources: each refspec's source; all branches for --all, --branches, --mirror, a pattern, `:`, or
# no refspec under push.default=matching or remote.<r>.push; tags for --tags or --mirror; else HEAD.
# A source that does not resolve asks. The target is the repository argument, else the remote git
# would pick. When it has no tracking refs (a new remote, a URL) the walk skips commits on every
# remote, and asks: that history was not rescanned for this target.
_g06_push() {
  local dir="$_G05_DIR" toks t r src sha remote="" have=0 other=0 revs=() refs=() ex=() args out
  toks=$(_g01_opts "$_G01_PUSH_OPTS" "${_G05_ARGS[@]}")
  while IFS= read -r t; do
    case "$t" in
      --all | --branches) revs+=(--branches) ;;
      --mirror) revs+=(--branches --tags) ;;
      --tags) revs+=(--tags) ;;
      --repo=*) [ "$have" = 1 ] || remote=${t#--repo=} ;;
      @*) if [ "$have" = 0 ]; then remote=${t#@}; have=1; else refs+=("${t#@}"); fi ;;
    esac
  done <<EOT
$toks
EOT
  [ -n "$remote" ] || remote=$(_g06_remote "$dir")
  for r in "${refs[@]}"; do
    r=${r#+}
    case "$r" in :) revs+=(--branches); continue ;; esac
    src=${r%%:*}
    case "$src" in
      "") continue ;;
      *'*'*) revs+=(--branches); continue ;;
      -*) sha="" ;;
      *) sha=$(_g06_git "$dir" rev-parse --verify -q "$src^{commit}") ;;
    esac
    if [ -n "$sha" ]; then
      revs+=("$sha")
    else
      vote ask G6 "cannot resolve the push source $src, so what it pushes was not scanned"
    fi
  done
  if [ ${#refs[@]} -eq 0 ] && [ ${#revs[@]} -eq 0 ]; then
    if [ "$(_g06_git "$dir" config push.default)" = matching ] ||
      [ -n "$(_g06_git "$dir" config --get-all "remote.$remote.push")" ]; then
      revs+=(--branches)
    elif sha=$(_g06_git "$dir" rev-parse --verify -q 'HEAD^{commit}'); then
      revs+=("$sha")
    fi
  fi
  [ ${#revs[@]} -gt 0 ] || return 0
  if word_has "$(_g06_git "$dir" remote)" "$remote" && case "$remote" in *'*'* | *'?'* | *'['*) false ;; esac &&
    [ -n "$(_g06_git "$dir" for-each-ref --count=1 --format=x "refs/remotes/$remote/")" ]; then
    ex=(--not "--remotes=$remote")
  else
    ex=(--not --remotes)
    [ -n "$(_g06_git "$dir" for-each-ref --count=1 --format=x refs/remotes/)" ] && other=1
  fi
  args=(log --no-show-signature -p --cc "${_G06_DIFF[@]}" '--format=%x1e%h%n%B%x1f' "${revs[@]}" "${ex[@]}")
  out=$(_g06_walk "$dir" "${args[@]}")
  _g06_finish "$out" "$dir" "${args[@]}"
  [ "$other" = 1 ] && _g06_unscanned "history already on another remote was not rescanned for $remote"
  return 0
}
