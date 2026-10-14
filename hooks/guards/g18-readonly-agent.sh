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
  case "$c" in *'>'* | *'<('* | *\$\(* | *'`'*) return 1 ;; esac
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
# pair after @ with no comma or .. inside, such as git's HEAD@{1} or @{u}, does not expand.
_g18_expands() {
  printf '%s' "$1" | LC_ALL=C awk -v sq="'" '
    { buf = buf (NR > 1 ? "\n" : "") $0 }
    END {
      n = split(buf, C, ""); q = ""; s = ""
      for (i = 1; i <= n; i++) {
        c = C[i]
        if (q == sq) { if (c == sq) q = ""; continue }
        if (c == "\\") { i++; continue }
        if (c == "$" || c == "`") exit 0
        if (q == "\"") { if (c == "\"") q = ""; continue }
        if (c == sq || c == "\"") { q = c; continue }
        s = s c
      }
      gsub(/@[{][^,.{}]*[}]/, "", s)
      exit index(s, "{") ? 0 : 1
    }'
}

guard_g18() {
  [ "$TOOL" = "Bash" ] || return 0
  [ -n "${AGENT:-}" ] || return 0
  case " $G18_AGENTS " in *" $AGENT "*) ;; *) return 0 ;; esac
  local cmd line
  if ! cmd=$(ti_get command); then
    vote deny G18 "read-only agent: the Bash input has no command"
    return 0
  fi
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if ! g18_allowed "$line"; then
      vote deny G18 "$AGENT is read-only; '${line%%[[:space:]]*}' with these arguments is not on its allowlist (git log, show, blame, diff, grep, ls-files; rg, grep, ls, cat, head, tail, wc; find without -exec or -delete; sed -n with line numbers). Ask the controller to run it."
      return 0
    fi
  done <<EOF
$(git_words "$cmd")
EOF
}
