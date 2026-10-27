# shellcheck shell=bash
# shellcheck disable=SC2154  # TOOL and AGENT are set by hooks/pre-tool-use
# G18: kern's read-only agents may run only allowlisted read commands in Bash.
# Sourced by hooks/pre-tool-use, which sets TOOL, AGENT and TOOL_INPUT and provides ti_get, git_words,
# git_sub, _shell_words and vote. G18_AGENTS holds the agent_type the M1 spike recorded for the
# investigator.
G18_AGENTS="kern:investigator"

# g18_allowed SIMPLE_COMMAND: exit 0 when the command only reads. Options are judged on the words the
# shell passes, quotes and backslashes removed, so '-o' and -dele''te are seen as -o and -delete.
g18_allowed() {
  local c words w1 sub w n=0
  # 2>&1, >&2 and a redirect to /dev/null are dropped only when they end their word: >&1x writes to a
  # file named 1x, and >/dev/nullx to /dev/nullx.
  c=$(printf '%s' "$1" | sed -E -e 's/[0-9]*>&[0-9]+([[:space:]]|$)/\1/g' \
    -e 's#(&|[0-9]*)>[[:space:]]*/dev/null([[:space:]]|$)#\2#g' -e 's/^[[:space:]]*//')
  case "$c" in *'>'* | *'<('* | *\$\(*) return 1 ;; esac
  _g18_expands "$c" && return 1
  words=$(_shell_words "$c")
  w1=${words%%$'\n'*}
  case "$w1" in
    git)
      sub=$(git_sub "$c" | cut -f2) || return 1
      case "$sub" in
        log | show | blame | diff | grep | ls-files | ls-tree | rev-parse | rev-list | cat-file | merge-base | describe | shortlog | name-rev) ;;
        *) return 1 ;;
      esac
      # A config value, an external diff, a pager or an output file can run a program or write one.
      # git grep reads --op as --open-files-in-pager, and -O inside a cluster such as -nO.
      while IFS= read -r w; do
        case "$w" in -c | -c* | --config-env* | -O* | --op* | --output* | --ext-diff* | --textconv*) return 1 ;; esac
        case "$sub:$w" in grep:-[!-]*O*) return 1 ;; esac
      done <<EOF
$words
EOF
      ;;
    rg)
      # --pre and --hostname-bin run a program; -z runs decompression programs, alone or in a cluster
      # such as -nz.
      while IFS= read -r w; do
        case "$w" in --pre* | --search-zip* | --hostname-bin*) return 1 ;; --*) ;; -*z*) return 1 ;; esac
      done <<EOF
$words
EOF
      ;;
    grep | ls | cat | head | tail | wc | cut | tr | nl | stat | du | pwd | echo | printf | basename | dirname | realpath | cd | true | test | jq | column | cmp | diff | comm) ;;
    file)
      # -C writes a .mgc file, also inside a cluster such as -bC; file reads --co as --compile. -z and -Z
      # run decompression programs; --u is a prefix only of --uncompress and --uncompress-noreport.
      while IFS= read -r w; do
        case "$w" in --co* | --u*) return 1 ;; --*) ;; -*C* | -*z* | -*Z*) return 1 ;; esac
      done <<EOF
$words
EOF
      ;;
    sort)
      # -o writes a file, also inside a cluster such as -uo; --compress-program runs a program. sort
      # reads --o as --output and --co as --compress-program.
      while IFS= read -r w; do
        case "$w" in --o* | --co*) return 1 ;; --*) ;; -*o*) return 1 ;; esac
      done <<EOF
$words
EOF
      ;;
    find)
      while IFS= read -r w; do
        case "$w" in -delete | -exec* | -ok* | -fprint* | -fls) return 1 ;; esac
      done <<EOF
$words
EOF
      ;;
    sed)
      # Only sed -n with a script of line numbers and p, such as 1,20p or $p, then file names: a later
      # word that starts with - (-i, --in-place, -e 'w file') could write, so it is not allowed.
      while IFS= read -r w; do
        n=$((n + 1))
        case "$n" in
          1) ;;
          2) [ "$w" = -n ] || return 1 ;;
          3)
            case "$w" in *p) ;; *) return 1 ;; esac
            case "${w%p}" in *[!0-9,\$]*) return 1 ;; esac
            ;;
          *) case "$w" in -*) return 1 ;; esac ;;
        esac
      done <<EOF
$words
EOF
      [ "$n" -ge 3 ] || return 1
      ;;
    *) return 1 ;;
  esac
  return 0
}

# _g18_expands TEXT: exit 0 when the shell may turn TEXT into words it does not show: a $ or a
# backtick outside single quotes ($_, ${x:--o}, $'-o'), or a brace expansion ({-o,out.txt}). A brace
# pair after @ with no comma or .. inside, such as git's HEAD@{1} or @{u}, does not expand. One brace
# list of file names in a word passes (list below): the shell makes only file-name words of it.
_g18_expands() {
  printf '%s' "$1" | env LC_ALL=C awk -v sq="'" '
    # list W K: 1 when word W, the Kth, is not the first, does not start with -, holds one { before one },
    # and the group holds a comma, no .., and items of name characters, none empty or starting with -.
    function list(w, k,   g, a, m, i) {
      if (k == 1 || substr(w, 1, 1) == "-") return 0
      if (gsub(/[{]/, "{", w) != 1 || gsub(/[}]/, "}", w) != 1) return 0
      g = substr(w, index(w, "{") + 1); if (!index(g, "}")) return 0
      g = substr(g, 1, index(g, "}") - 1)
      if (!index(g, ",") || index(g, "..")) return 0
      m = split(g, a, ",")
      for (i = 1; i <= m; i++) if (a[i] !~ /^[A-Za-z0-9_.\/+][A-Za-z0-9_.\/+-]*$/) return 0
      return 1
    }
    { buf = buf (NR > 1 ? "\n" : "") $0 }
    END {
      # s keeps every character; a quoted or escaped brace, comma or blank becomes _, so it neither
      # expands nor splits a word, and a quoted - still starts its word.
      n = split(buf, C, ""); q = ""; s = ""
      for (i = 1; i <= n; i++) {
        c = C[i]
        if (q == sq) { if (c == sq) q = ""; else s = s (c ~ /[{},[:space:]]/ ? "_" : c); continue }
        if (c == "\\") { i++; s = s (C[i] ~ /[{},[:space:]]/ ? "_" : C[i]); continue }
        if (c == "$" || c == "`") exit 0
        if (q == "\"") { if (c == "\"") q = ""; else s = s (c ~ /[{},[:space:]]/ ? "_" : c); continue }
        if (c == sq || c == "\"") { q = c; continue }
        s = s c
      }
      gsub(/@[{][^,.{}]*[}]/, "@", s)
      m = split(s, W, /[[:space:]]+/); k = 0
      for (i = 1; i <= m; i++) {
        if (W[i] == "") continue
        k++
        if (index(W[i], "{") && !list(W[i], k)) exit 0
      }
      exit 1
    }'
}

# _g18_assign RECORD: exit 0 when RECORD is only NAME=VALUE with a one-letter NAME and a plain VALUE
# (letters, digits and _ . / : @ + -, in one pair of quotes or none); sets _G18_N and _G18_V. No shell and
# no allowlisted command reads a one-letter variable from its environment, while IFS, PATH, GIT_* or
# RIPGREP_CONFIG_PATH would change what runs, so any longer name stays denied.
_g18_assign() {
  local r=$1
  r=${r#"${r%%[![:space:]]*}"}
  r=${r%"${r##*[![:space:]]}"}
  case "$r" in [A-Za-z]=*) ;; *) return 1 ;; esac
  _G18_N=${r%%=*}
  _G18_V=${r#?=}
  case "$_G18_V" in
    \'*\') _G18_V=${_G18_V#\'} && _G18_V=${_G18_V%\'} ;;
    \"*\") _G18_V=${_G18_V#\"} && _G18_V=${_G18_V%\"} ;;
  esac
  case "$_G18_V" in '' | *[!A-Za-z0-9_./:@+-]*) return 1 ;; esac
  return 0
}

# _g18_subst TEXT NAME VALUE: TEXT with each $NAME and ${NAME} replaced by VALUE, so G18 judges the words
# the shell would run. $NAMEx names another variable and stays, and any $ left is denied as before.
_g18_subst() {
  printf '%s' "$1" | N=$2 V=$3 env LC_ALL=C awk '
    { buf = buf (NR > 1 ? "\n" : "") $0 }
    END {
      n = ENVIRON["N"]; v = ENVIRON["V"]; out = ""
      while ((i = index(buf, "$")) > 0) {
        out = out substr(buf, 1, i - 1); buf = substr(buf, i + 1)
        if (substr(buf, 1, 3) == "{" n "}") { out = out v; buf = substr(buf, 4); continue }
        if (substr(buf, 1, 1) == n && substr(buf, 2, 1) !~ /[A-Za-z0-9_]/) { out = out v; buf = substr(buf, 2); continue }
        out = out "$"
      }
      printf "%s", out buf
    }'
}

guard_g18() {
  [ "$TOOL" = "Bash" ] || return 0
  [ -n "${AGENT:-}" ] || return 0
  case " $G18_AGENTS " in *" $AGENT "*) ;; *) return 0 ;; esac
  local cmd line bare seen=' ' asg='' n v nl=$'\n'
  if ! cmd=$(ti_get command); then
    vote deny G18 "read-only agent: the Bash input has no command"
    return 0
  fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    # A one-letter variable set once to a plain value is read as that value in the records after it.
    # One set twice is denied: after || or in a branch, G18 cannot tell which value a later record reads.
    if _g18_assign "$line"; then
      case "$seen" in
        *" $_G18_N "*)
          vote deny G18 "$AGENT is read-only; $_G18_N is set twice in one command, so G18 cannot tell which value a later command reads. Set each variable once."
          return 0
          ;;
      esac
      seen="$seen$_G18_N "
      asg="$asg$_G18_N=$_G18_V$nl"
      continue
    fi
    bare=$line
    while IFS='=' read -r n v; do
      [ -n "$n" ] && line=$(_g18_subst "$line" "$n" "$v") && bare=$(_g18_subst "$bare" "$n" "")
    done <<EOF
$asg
EOF
    # The assignment may not reach this record (after ||, in a pipeline, in the background, a subshell or
    # a branch), so the record must also pass with each variable empty.
    if [ "$bare" != "$line" ] && ! g18_allowed "$bare"; then
      vote deny G18 "$AGENT is read-only; with a variable unset, as it may be when this command runs, '${bare%%[[:space:]]*}' with these arguments is not on its allowlist. Write the value out."
      return 0
    fi
    if ! g18_allowed "$line"; then
      vote deny G18 "$AGENT is read-only; '${line%%[[:space:]]*}' with these arguments is not on its allowlist (git log, show, blame, diff, grep, ls-files; rg, grep, ls, cat, head, tail, wc; find without -exec or -delete; sed -n with line numbers). Ask the controller to run it."
      return 0
    fi
  done <<EOF
$(git_words "$cmd")
EOF
}
