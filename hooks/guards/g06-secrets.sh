# shellcheck shell=bash
# G6 secrets: scan what a commit or push would publish, commit messages included; refuse never_commit
# paths. Git is read with color, external diff and textconv off, so repo config can neither hide an
# added line nor run a program here. Records are read with G5's _g05_split and _g05_message and
# options with G1's _g01_opts: the dispatcher sources every guard before it calls any.

# Diff options for every patch G6 reads.
_G06_DIFF=(--no-color --no-ext-diff --no-textconv --src-prefix=a/ --dst-prefix=b/)

guard_g06() {
  [ "$TOOL" = Bash ] || return 0
  local cmd rec
  cmd=$(ti_get command) || return 0
  while IFS= read -r rec; do
    [ -n "$rec" ] || continue
    if ! declare -F _g05_split _g05_message _g01_opts >/dev/null || [ -z "${_G05_COMMIT_OPTS-}" ] ||
      [ -z "${_G01_PUSH_OPTS-}" ]; then
      case "$(git_sub "$rec" | cut -f2)" in
        commit | push) vote ask G6 "the secret scan could not load its parsers" ;;
      esac
      continue
    fi
    _g05_split "$rec" || continue
    case "$_G05_SUB" in
      commit) _g06_commit ;;
      push) _g06_push ;;
    esac
  done <<EOT
$(git_words "$cmd")
EOT
}

# _g06_git DIR ARGS...: git in DIR with color off whatever the config says.
_g06_git() {
  local d="$1"
  shift
  git -C "$d" -c color.ui=never "$@" 2>/dev/null
}

# _g06_added: reads a unified diff, prints `path:line:text` for every added line. A `+++ ` line is a
# file header only between a `diff` line and the first `@@`; inside a hunk it is an added line whose
# text starts with `++ `, so no text is ever taken for a path.
_g06_added() {
  LC_ALL=C awk '
    /^diff / { h = 1; next }
    h && /^\+\+\+ / { p = substr($0, 5); sub(/^b\//, "", p); next }
    /^@@ / { h = 0; split($3, a, ","); ln = substr(a[1], 2) + 0; next }
    h { next }
    /^\+/ { print p ":" ln ":" substr($0, 2); ln++; next }
    /^ / { ln++ }'
}

# _g06_msg LABEL TEXT: TEXT as `LABEL:line:text` lines for _g06_scan.
_g06_msg() {
  [ -n "$2" ] || return 0
  printf '%s\n' "$2" | awk -v l="$1" '{ print l ":" NR ":" $0 }'
}

# The secret rules, `name|ERE` per line.
_G06_RULES='private-key|-----BEGIN [A-Z ]*PRIVATE KEY-----
pgp-private-key|-----BEGIN PGP PRIVATE KEY BLOCK-----
aws-access-key|(AKIA|ASIA)[0-9A-Z]{16}
github-token|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{22,}
slack-token|xox[baprs]-[A-Za-z0-9-]{10,}
api-key|sk-[A-Za-z0-9_-]{20,}
stripe-key|[rs]k_live_[A-Za-z0-9]{20,}
google-api-key|AIza[0-9A-Za-z_-]{35}'

# _g06_scan: reads `path:line:text` lines, prints `path:line <rule>` per hit. Never prints the text.
# One grep of every rule at once reads the stream; each rule then sorts only the lines that hit, so a
# large diff is read once and never held in a shell variable.
_g06_scan() {
  local any="" hits rule re
  while IFS='|' read -r rule re; do any="${any:+$any|}($re)"; done <<EOT
$_G06_RULES
EOT
  hits=$(grep -E -- "$any")
  [ -n "$hits" ] || return 0
  while IFS='|' read -r rule re; do
    printf '%s\n' "$hits" | grep -E -- "$re" | cut -d: -f1,2 | sed "s/\$/ $rule/"
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

_g06_report() {
  local hits="$1" diff="$2"
  if [ -n "$hits" ]; then
    vote deny G6 "possible secret, not committed or pushed: $(printf '%s\n' "$hits" | awk '!s[$0]++' | head -n 5 | paste -sd ';' - | sed 's/;/; /g')"
  elif command -v gitleaks >/dev/null 2>&1; then
    printf '%s\n' "$diff" | gitleaks stdin --no-banner --redact >/dev/null 2>&1
    [ $? -eq 1 ] && vote deny G6 "gitleaks reports a secret in this change; run gitleaks yourself to see where"
  fi
}

# _g06_commit: the commit _g05_split just read. Scans the staged diff and the message; with -a or
# --pathspec-from-file also the unstaged diff, and with pathspecs (bare, -i or -o) the unstaged diff
# of those paths, because git commits their worktree content.
_g06_commit() {
  local dir="$_G05_DIR" toks t diff names msg wide=0 paths=()
  toks=$(_g01_opts "$_G05_COMMIT_OPTS" "${_G05_ARGS[@]}")
  while IFS= read -r t; do
    case "$t" in
      --all | --pathspec-from-file=*) wide=1 ;;
      @*) paths+=("${t#@}") ;;
    esac
  done <<EOT
$toks
EOT
  diff=$(_g06_git "$dir" diff --cached "${_G06_DIFF[@]}")
  names=$(_g06_git "$dir" diff --cached --name-only)
  if [ "$wide" = 1 ]; then
    diff="$diff
$(_g06_git "$dir" diff "${_G06_DIFF[@]}")"
    names="$names
$(_g06_git "$dir" diff --name-only)"
  elif [ ${#paths[@]} -gt 0 ]; then
    diff="$diff
$(_g06_git "$dir" diff "${_G06_DIFF[@]}" -- "${paths[@]}")"
    names="$names
$(_g06_git "$dir" diff --name-only -- "${paths[@]}")"
  fi
  msg=$(_g05_message "$dir" "$toks" raw)
  _g06_paths "$names"
  _g06_report "$( { printf '%s\n' "$diff" | _g06_added; _g06_msg "commit message" "$msg"; } | _g06_scan)" "$diff"
}

# _g06_remote DIR: the remote a push with no repository argument goes to: branch.<b>.pushRemote,
# remote.pushDefault, branch.<b>.remote, else origin.
_g06_remote() {
  local b r
  b=$(current_branch "$1") || b=""
  if [ -n "$b" ] && r=$(git -C "$1" config "branch.$b.pushRemote" 2>/dev/null); then
    printf '%s\n' "$r"
  elif r=$(git -C "$1" config remote.pushDefault 2>/dev/null); then
    printf '%s\n' "$r"
  elif [ -n "$b" ] && r=$(git -C "$1" config "branch.$b.remote" 2>/dev/null); then
    printf '%s\n' "$r"
  else
    printf 'origin\n'
  fi
}

# _g06_push: the push _g05_split just read. Scans every commit it sends that the target remote's
# tracking refs do not hold (`<srcs> --not --remotes=<remote>`), merges diffed against each parent
# (-m) so content added in a merge is seen, and their messages. Sources: each refspec's source, all
# branches for --all, --branches, --mirror or a pattern, tags for --tags or --mirror, else HEAD; a
# source that does not resolve asks. The target is the repository argument, else the remote git
# would pick; one that `git remote` does not list, such as a URL, excludes nothing.
_g06_push() {
  local dir="$_G05_DIR" toks t r src sha remote="" have=0 revs=() refs=() ex=() diff names msgs
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
  for r in "${refs[@]}"; do
    r=${r#+}
    src=${r%%:*}
    case "$src" in
      "") continue ;;
      *'*'*) revs+=(--branches); continue ;;
    esac
    case "$src" in -*) sha="" ;; *) sha=$(git -C "$dir" rev-parse --verify -q "$src^{commit}" 2>/dev/null) ;; esac
    if [ -n "$sha" ]; then
      revs+=("$sha")
    else
      vote ask G6 "cannot resolve the push source $src, so what it pushes was not scanned"
    fi
  done
  if [ ${#refs[@]} -eq 0 ] && [ ${#revs[@]} -eq 0 ]; then
    sha=$(git -C "$dir" rev-parse --verify -q 'HEAD^{commit}' 2>/dev/null) && revs+=("$sha")
  fi
  [ ${#revs[@]} -gt 0 ] || return 0
  [ -n "$remote" ] || remote=$(_g06_remote "$dir")
  if word_has "$(git -C "$dir" remote 2>/dev/null)" "$remote"; then
    case "$remote" in *'*'* | *'?'* | *'['*) ;; *) ex=(--not "--remotes=$remote") ;; esac
  fi
  diff=$(_g06_git "$dir" log -p -m "${_G06_DIFF[@]}" --format= "${revs[@]}" "${ex[@]}")
  names=$(_g06_git "$dir" log -m --name-only --format= "${revs[@]}" "${ex[@]}" | sort -u)
  msgs=$(_g06_git "$dir" log --no-show-signature --format='kern-msg %h%n%B' "${revs[@]}" "${ex[@]}" |
    awk '/^kern-msg / { c = $2; n = 0; next } { n++; print "commit " c " message:" n ":" $0 }')
  _g06_paths "$names"
  _g06_report "$( { printf '%s\n' "$diff" | _g06_added; printf '%s\n' "$msgs"; } | _g06_scan)" "$diff"
}
