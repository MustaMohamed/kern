# shellcheck shell=bash
# Shell and git parsing for guards. Needs settings.sh. Reads CWD and KERN_MAIN.

# git_words CMD: one simple command per line. Splits on ; & && || | ( ), the words { and }, and
# newlines outside quotes, backticks and $( ); a redirection (2>&1, &>, >|) never splits, and a
# backslash-newline is dropped. The script of an sh-family shell's -c (any path, flags such as -lc,
# after the wrappers and keywords _cmd_words skips), the arguments of `eval`, and the bodies of $( )
# and backticks are split again and printed after their wrapper, so a command inside a string is
# still seen. Out of scope: commands that xargs or find -exec run.
git_words() {
  local seg inner body
  _split_words "$1" | while IFS= read -r seg; do
    printf '%s\n' "$seg"
    _subst_bodies "$seg" | while IFS= read -r body; do
      [ -n "$body" ] && git_words "$body"
    done
    inner=$(_cmd_words "$seg" | LC_ALL=C awk '
      NR == 1 { b = $0; sub(/.*\//, "", b); if (b == "eval") e = 1; else if (b !~ /^(ba|z|da)?sh$/) exit; next }
      e { out = out (o++ ? " " : "") $0; next }
      c { print; exit }
      /^-[a-z]*c$/ { c = 1; next }
      /^-/ { next }
      { exit }
      END { if (e) print out }')
    [ -n "$inner" ] && git_words "$inner"
  done
}

# _subst_bodies STR: the body of each outermost $( ) and backtick pair, one per line.
_subst_bodies() {
  printf '%s' "$1" | LC_ALL=C awk -v sq="'" '
    { buf = buf (NR > 1 ? " " : "") $0 }
    END {
      n = length(buf); q = ""; depth = 0
      for (i = 1; i <= n; i++) {
        c = substr(buf, i, 1)
        if (q == sq) { if (c == sq) q = ""; continue }
        if (c == "\\") { i++; continue }
        if (depth == 0 && c == "`") {
          e = index(substr(buf, i + 1), "`")
          if (e) { print substr(buf, i + 1, e - 1); i += e }
          continue
        }
        if (c == "$" && substr(buf, i + 1, 1) == "(") {
          if (depth == 0) s = i + 2
          depth++; i++; continue
        }
        if (depth > 0) {
          if (c == "(") depth++
          else if (c == ")") { depth--; if (depth == 0) print substr(buf, s, i - s) }
          continue
        }
        if (c == sq) q = sq
      }
    }'
}

_split_words() {
  printf '%s' "$1" | LC_ALL=C awk -v sq="'" '
    function emit(s) { gsub(/\\\n/, "", s); gsub(/^[ \t\n]+|[ \t\n]+$/, "", s); if (s != "") print s }
    function sep(ch) { return ch == "" || index(" \t\n;&|()", ch) > 0 }
    { buf = buf (NR > 1 ? "\n" : "") $0 }
    END {
      n = length(buf); q = ""; depth = 0; start = 1; i = 1
      while (i <= n) {
        c = substr(buf, i, 1)
        if (q == sq) { if (c == sq) q = ""; i++; continue }
        if (c == "\\") { i += 2; continue }
        if (q == "\"") {
          if (c == "\"") q = ""
          else if (c == "$" && substr(buf, i + 1, 1) == "(") { depth++; i++ }
          else if (c == ")" && depth > 0) depth--
          i++; continue
        }
        if (q == "`") { if (c == "`") q = ""; i++; continue }
        if (c == sq || c == "\"" || c == "`") { q = c; i++; continue }
        if (c == "$" && substr(buf, i + 1, 1) == "(") { depth++; i += 2; continue }
        if (depth > 0) { if (c == "(") depth++; else if (c == ")") depth--; i++; continue }
        p = substr(buf, i - 1, 1)
        x = substr(buf, i + 1, 1)
        if ((c == "&" && (p == ">" || p == "<" || x == ">")) || (c == "|" && p == ">")) { i++; continue }
        if ((c == "{" || c == "}") && (i == 1 || sep(p)) && sep(x)) {
          emit(substr(buf, start, i - start))
          start = i + 1
        } else if (c == ";" || c == "\n" || c == "&" || c == "|" || c == "(" || c == ")") {
          emit(substr(buf, start, i - start))
          if ((c == "&" || c == "|") && x == c) i++
          start = i + 1
        }
        i++
      }
      emit(substr(buf, start))
    }'
}

# _shell_words STR: the words of one simple command, quotes removed, one per line.
_shell_words() {
  printf '%s' "$1" | LC_ALL=C awk -v sq="'" '
    { buf = buf (NR > 1 ? " " : "") $0 }
    END {
      n = length(buf); q = ""; w = ""; have = 0
      for (i = 1; i <= n; i++) {
        c = substr(buf, i, 1)
        if (q == sq) { if (c == sq) q = ""; else w = w c; continue }
        if (q == "\"") {
          if (c == "\"") q = ""
          else if (c == "\\" && index("\"\\$`", substr(buf, i + 1, 1))) { i++; w = w substr(buf, i, 1) }
          else w = w c
          continue
        }
        if (c == "\\") { i++; w = w substr(buf, i, 1); have = 1; continue }
        if (c == sq || c == "\"") { q = c; have = 1; continue }
        if (c == " " || c == "\t") { if (have) print w; w = ""; have = 0; continue }
        w = w c; have = 1
      }
      if (have) print w
    }'
}

# _cmd_words CMDLINE: the words of a simple command from its command name on, one per line.
# Skips leading VAR=value words, the keywords if then elif else do while until ! {, the wrappers
# command, exec, time, nohup, sudo and env, and their options (-u and -g take a value).
_cmd_words() {
  _shell_words "$1" | LC_ALL=C awk '
    s { print; next }
    val { val = 0; next }
    /^[A-Za-z_][A-Za-z0-9_]*=/ { next }
    /^(if|then|elif|else|do|while|until|!|[{]|command|exec|time|nohup|sudo|env)$/ { next }
    /^-[ug]$/ { val = 1; next }
    /^-/ { next }
    { s = 1; print }'
}

# git_sub CMDLINE: for a simple git command prints `<dir>\t<subcommand>\t<rest>`. Exit 1 when the
# command is not git. What _cmd_words skips comes first.
git_sub() {
  local w=() t i=1 n dir="${CWD:-$PWD}" rest=""
  while IFS= read -r t; do w+=("$t"); done <<EOT
$(_cmd_words "$1")
EOT
  n=${#w[@]}
  case "${w[0]}" in git | */git) ;; *) return 1 ;; esac
  while [ "$i" -lt "$n" ]; do
    case "${w[$i]}" in
      -C)
        t="${w[$((i + 1))]-}"
        case "$t" in /*) dir="$t" ;; *) dir="$dir/$t" ;; esac
        i=$((i + 2))
        ;;
      -c) i=$((i + 2)) ;;
      --git-dir=* | --work-tree=* | --namespace=* | --no-pager | --paginate | -p | --bare | --no-replace-objects | --literal-pathspecs | --no-optional-locks) i=$((i + 1)) ;;
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

# current_branch DIR
current_branch() {
  git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null
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

# branch_protected BRANCH: base branch, branch.protected or deploy.envs. With no resolvable base,
# main, master, trunk and develop count as protected. `*` (every branch, from push_targets) does too.
branch_protected() {
  local base
  [ "$1" = "*" ] && return 0
  if base=$(base_branch_name); then
    [ "$1" = "$base" ] && return 0
  else
    case "$1" in main | master | trunk | develop) return 0 ;; esac
  fi
  list_has "$(settings_get branch.protected '')" "$1" && return 0
  list_has "$(settings_get deploy.envs '')" "$1" && return 0
  return 1
}

# push_targets DIR REST: remote branch names a `git push` writes, one per line. `:x`, `-d x` and
# `--delete x` print `x`; `refs/heads/` and `heads/` are stripped. --all, --mirror, --branches and
# a refspec holding `*` print `*`. Redirections (2>&1, >file, `> file`) are skipped. No refspec
# means the current branch.
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
    [ "$t" = HEAD ] && t=$(current_branch "$dir")
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
# What _cmd_words skips comes first.
gh_sub() {
  local out
  out=$(_cmd_words "$1" | awk '
    { w[++n] = $0; if (n == 3) exit }
    END { if (w[1] == "gh" && n >= 3) print w[2] " " w[3]; else if (w[1] == "gh" && n == 2) print w[2] }')
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
