# shellcheck shell=bash
# Shell and git parsing for guards. Needs settings.sh. Reads CWD and KERN_MAIN.

# A newline inside one record (quoted text, or the inside of $( )) is printed as this byte, so a
# caller that reads records line by line never takes a quoted line for a command.
_GW_NL=$'\037'

# git_words CMD: one simple command per line. Splits on ; & && || | ( ), the words { and }, and
# newlines outside quotes, backticks and $( ); a redirection (2>&1, &>, >|) never splits, and a
# backslash-newline is dropped. Here-doc bodies are data: they are left out (see _split_words).
# The script of an sh-family shell's -c (any path, flags such as -lc or -cx, after the wrappers and
# keywords _cmd_words skips), the arguments of `eval`, and the bodies of $( ) and backticks are
# split again and printed after their wrapper, so a command inside a string is still seen. Out of
# scope: commands that xargs or find -exec run.
git_words() {
  local seg inner body first
  _split_words "$1" | while IFS= read -r seg; do
    printf '%s\n' "$seg"
    # shellcheck disable=SC2016 # a literal $( in the text
    case "$seg" in
      *'$('* | *'`'*)
        _subst_bodies "$seg" | while IFS= read -r body; do
          [ -n "$body" ] && git_words "${body//$_GW_NL/$'\n'}"
        done
        ;;
    esac
    # The wrapper pass costs two processes, so it runs only when the first word, quotes removed,
    # is an assignment, a keyword, a wrapper, eval or a shell.
    first=${seg%%[[:space:]]*}
    case "/${first//[\"\'\\]/}" in
      *=* | */if | */then | */elif | */else | */do | */while | */until | */'!' | */'{' | */eval | \
        */command | */exec | */time | */nohup | */sudo | */env | */timeout | */nice | */sh | */bash | \
        */zsh | */dash) ;;
      *) continue ;;
    esac
    inner=$(_cmd_words "$seg" | LC_ALL=C awk '
      NR == 1 { b = $0; sub(/.*\//, "", b); if (b == "eval") e = 1; else if (b !~ /^(ba|z|da)?sh$/) exit; next }
      e { out = out (o++ ? " " : "") $0; next }
      c { print; exit }
      v { v = 0; next }
      /^[-+][oO]$/ { v = 1; next }
      /^-[a-z]*c[a-z]*$/ { c = 1; next }
      /^[-+]/ { next }
      { exit }
      END { if (e) print out }')
    [ -n "$inner" ] && git_words "${inner//$_GW_NL/$'\n'}"
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

# _split_words STR: the simple commands of STR, one record per line (see git_words). A here-doc
# (<<WORD, <<-WORD, <<'WORD', <<"WORD") is read at the newline that ends its command line: the body
# up to the closing WORD line is skipped. At the top level the body and closing line are dropped;
# inside $( ) the closing line is kept, so the record still parses the same when split again. A
# here-doc with no closing line skips nothing, so a misread `<<` never hides the commands after it.
_split_words() {
  printf '%s' "$1" | LC_ALL=C awk -v sq="'" '
    function emit(s) { gsub(/\\\n/, "", s); gsub(/^[ \t\n]+|[ \t\n]+$/, "", s); gsub(/\n/, "\037", s); if (s != "") print s }
    function sep(ch) { return ch == "" || index(" \t\n;&|()", ch) > 0 }
    # cut(e): emits the record gathered so far, up to position e - 1.
    function cut(e) { emit(pre substr(buf, start, e - start)); pre = "" }
    # hdop(j): true when the `<` at j opens a here-doc operator (`<<`, not `<<<`).
    function hdop(j) { return substr(buf, j + 1, 1) == "<" && substr(buf, j + 2, 1) != "<" && substr(buf, j - 1, 1) != "<" }
    # heredoc(j): queues the delimiter word that follows the `<<` ending at j - 1, quotes removed.
    # Returns the position after the word.
    function heredoc(j,   d, wq, ch, dash) {
      dash = 0
      if (substr(buf, j, 1) == "-") { dash = 1; j++ }
      while (j <= n && index(" \t", substr(buf, j, 1))) j++
      d = ""; wq = ""
      for (; j <= n; j++) {
        ch = substr(buf, j, 1)
        if (wq != "") { if (ch == wq) wq = ""; else d = d ch; continue }
        if (ch == sq || ch == "\"") { wq = ch; continue }
        if (ch == "\\") { j++; d = d substr(buf, j, 1); continue }
        if (index(" \t\n;&|<>()", ch)) break
        d = d ch
      }
      if (d != "") { hd[++hn] = d; hx[hn] = dash }
      return j
    }
    # bodies(j): at the newline j, finds the closing line of each queued here-doc and clears the
    # queue. Returns the line number of the last closing line, or 0 when one is missing.
    function bodies(j,   h, k, t) {
      while (lp < NR && off[lp + 1] <= j) lp++
      k = lp; nh = hn; hn = 0
      for (h = 1; h <= nh; h++) {
        for (k++; k <= NR; k++) { t = L[k]; if (hx[h]) sub(/^\t+/, "", t); if (t == hd[h]) break }
        if (k > NR) return 0
        last[h] = k
      }
      return k
    }
    # nested(j): at the newline j inside $( ), drops the here-doc bodies and keeps their closing
    # lines. Returns where scanning resumes.
    function nested(j,   k, h) {
      if (!(k = bodies(j))) return j + 1
      pre = pre substr(buf, start, j - start + 1)
      for (h = 1; h < nh; h++) pre = pre L[last[h]] "\n"
      start = off[k]
      return off[k] + length(L[k])
    }
    { L[NR] = $0; buf = buf (NR > 1 ? "\n" : "") $0 }
    END {
      n = length(buf); q = ""; depth = 0; start = 1; i = 1; pre = ""; hn = 0; lp = 1; off[1] = 1
      for (k = 2; k <= NR; k++) off[k] = off[k - 1] + length(L[k - 1]) + 1
      while (i <= n) {
        c = substr(buf, i, 1)
        if (q == sq) { if (c == sq) q = ""; i++; continue }
        if (c == "\\") { i += 2; continue }
        if (q == "\"") {
          if (c == "\"") q = ""
          else if (c == "$" && substr(buf, i + 1, 1) == "(") { depth++; i++ }
          else if (c == ")" && depth > 0) depth--
          else if (depth > 0 && c == "<" && hdop(i)) { i = heredoc(i + 2); continue }
          else if (depth > 0 && c == "\n" && hn) { i = nested(i); continue }
          i++; continue
        }
        if (q == "`") { if (c == "`") q = ""; i++; continue }
        if (c == sq || c == "\"" || c == "`") { q = c; i++; continue }
        if (c == "<" && hdop(i)) { i = heredoc(i + 2); continue }
        if (c == "$" && substr(buf, i + 1, 1) == "(") { depth++; i += 2; continue }
        if (depth > 0) {
          if (c == "\n" && hn) { i = nested(i); continue }
          if (c == "(") depth++; else if (c == ")") depth--
          i++; continue
        }
        p = substr(buf, i - 1, 1)
        x = substr(buf, i + 1, 1)
        if ((c == "&" && (p == ">" || p == "<" || x == ">")) || (c == "|" && p == ">")) { i++; continue }
        if ((c == "{" || c == "}") && (i == 1 || sep(p)) && sep(x)) {
          cut(i)
          start = i + 1
        } else if (c == ";" || c == "\n" || c == "&" || c == "|" || c == "(" || c == ")") {
          cut(i)
          if ((c == "&" || c == "|") && x == c) i++
          start = i + 1
          if (c == "\n" && hn && (k = bodies(i))) { i = off[k] + length(L[k]); start = i + 1 }
        }
        i++
      }
      cut(n + 1)
    }'
}

# _shell_words STR: the words of one simple command, quotes removed, one per line. A newline
# inside quotes stays in its word as \037 (git_words' in-record newline). An unquoted <, >, &> run
# starts a new word unless it follows an fd number or another operator: `main>/dev/null` gives
# `main` and `>/dev/null`, while `2>&1` stays whole.
_shell_words() {
  printf '%s' "$1" | LC_ALL=C awk -v sq="'" '
    { buf = buf (NR > 1 ? "\037" : "") $0 }
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
        if (c == " " || c == "\t" || c == "\037") { if (have) print w; w = ""; have = 0; continue }
        if ((c == "<" || c == ">" || (c == "&" && substr(buf, i + 1, 1) == ">")) && have && w !~ /^[0-9]+$/ && w !~ /[<>&]$/) {
          print w; w = ""
        }
        w = w c; have = 1
      }
      if (have) print w
    }'
}

# _cmd_words CMDLINE: the words of a simple command from its command name on, one per line.
# Skips leading VAR=value words, the keywords if then elif else do while until ! {, the wrappers
# command, exec, time, nohup, sudo, env, timeout and nice (any path), and their options. The
# options in `opt` take a value; timeout's duration follows its options; the value of env -S is
# a command line, read as words.
_cmd_words() {
  _shell_words "$1" | LC_ALL=C awk '
    BEGIN {
      opt["sudo"] = " -C -D -g -h -p -R -r -T -t -U -u "
      opt["env"] = " -C -P -S -u "
      opt["exec"] = " -a "
      opt["timeout"] = " -s -k "
      opt["nice"] = " -n "
    }
    function word(x,   a, k, m, b) {
      if (s) { print x; return }
      if (val) {
        val = 0
        if (split_s) { split_s = 0; m = split(x, a, /[ \t\037]+/); for (k = 1; k <= m; k++) if (a[k] != "") word(a[k]) }
        return
      }
      if (x ~ /^[A-Za-z_][A-Za-z0-9_]*=/) return
      if (x ~ /^(if|then|elif|else|do|while|until|!|[{])$/) { wrap = ""; return }
      b = x; sub(/.*\//, "", b)
      if (b ~ /^(command|exec|time|nohup|sudo|env|timeout|nice)$/) { wrap = b; dur = (b == "timeout"); return }
      if (x ~ /^-/) {
        if (wrap in opt && index(opt[wrap], " " x " ")) { val = 1; split_s = (wrap == "env" && x == "-S") }
        return
      }
      if (dur) { dur = 0; return }
      s = 1; print x
    }
    { word($0) }'
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
