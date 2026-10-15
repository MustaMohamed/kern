# shellcheck shell=bash
# G2 PR create: drafts only, no duplicate PR for a head, `gh pr ready` stays human under autopilot.
# An allow approves the whole Bash call, so G2 allows a draft only in the shape _g02_proven accepts;
# any other draft asks, or is denied under autopilot. The _gh_* helpers below are shared with G3 and
# G4: the dispatcher sources every guard before it calls any. They use G1's _g01_filter and
# _g01_quiet_redirect the same way.

# gh option tables for _gh_opts, from gh 2.100.0 `--help`: LONG/SHORT/KIND, `-` for no short form.
# KIND b is a boolean, v takes a value.
_GH_CREATE_OPTS="title/t/v body/b/v body-file/F/v base/B/v head/H/v label/l/v assignee/a/v \
reviewer/r/v milestone/m/v project/p/v template/T/v repo/R/v attach/-/v recover/-/v draft/d/b \
fill/f/b fill-first/-/b fill-verbose/-/b web/w/b dry-run/-/b no-maintainer-edit/-/b editor/e/b \
help/h/b"
# The options an allowed draft may carry. The others add people, labels, projects or files, take
# the body from elsewhere, open an editor or a browser, or name another repo.
_GH_CREATE_SAFE="title body-file base head draft fill fill-first fill-verbose dry-run no-maintainer-edit"
_GH_READY_OPTS="undo/-/b repo/R/v help/h/b"
# gh 2.100.0's command groups (`gh help`) and their aliases (`gh help <group>`) that ask when gh runs
# behind another command (_g02_hidden): all but browse, search and status, which only read or open a
# browser. help and version are not listed there either.
_G02_GROUPS=" auth codespace cs discussion gist issue org pr project release repo skill skills cache run \
workflow agent-task agent-tasks agent agents alias api attestation at completion config copilot extension \
extensions ext gpg-key label licenses preview ruleset rs secret ssh-key variable "
# gh 2.100.0's own commands: what `gh help` lists under CORE, GITHUB ACTIONS and ADDITIONAL COMMANDS
# and HELP TOPICS, the group aliases each `gh <command> --help` lists under ALIASES, and the hidden
# help, version and credits. gh refuses an alias or an extension named like one of its commands, so a
# first word outside this list is an alias (`gh alias set`) or an extension (`gh extension install`).
_GH_CMDS=" auth browse codespace cs discussion gist issue org pr project release repo skill skills cache \
run workflow agent-task agent-tasks agent agents alias api attestation at completion config copilot \
extension extensions ext gpg-key label licenses preview ruleset rs search secret ssh-key status variable \
accessibility a11y actions environment exit-codes formatting mintty reference telemetry help version credits "

guard_g02() {
  [ "$TOOL" = Bash ] || return 0
  local cmd sub i=0
  cmd=$(ti_get command) || return 0
  # Only a command whose text holds gh, in any case or split by quotes or a backslash, is parsed.
  case "$cmd ${KERN_ALIAS_TEXT-}" in *[Gg][Hh]* | *[Gg][\"\'\\]*[Hh]*) ;; *) return 0 ;; esac
  _gh_load "$cmd"
  while [ "$i" -lt "${#_GH_RECS[@]}" ]; do
    sub=$(gh_sub "${_GH_RECS[$i]}") || sub=""
    if [ -n "$sub" ]; then
      _gh_canon "$sub"
      sub=$_GH_SUB
      _g02_own "$sub"
    fi
    case "$sub" in
      "pr create") _g02_create "$i" ;;
      "pr ready") _g02_ready "$i" ;;
      "") _g02_hidden "${_GH_RECS[$i]}" ;;
    esac
    i=$((i + 1))
  done
}

# _gh_canon SUB: sets _GH_SUB to SUB (gh_sub's `<group> <verb>`) with gh 2.100.0's aliases replaced
# by the commands they name, as the ALIASES section of `gh <group> [<verb>] --help` lists them: pr new
# is pr create, ext is extension, every ls is list.
_gh_canon() {
  local g="${1%% *}" v=""
  case "$1" in *" "*) v=${1#* } ;; esac
  case "$g" in
    cs) g=codespace ;;
    skills) g=skill ;;
    agent-tasks | agent | agents) g=agent-task ;;
    at) g=attestation ;;
    extensions | ext) g=extension ;;
    rs) g=ruleset ;;
  esac
  case "$g $v" in
    "gist new" | "issue new" | "pr new" | "release new" | "repo new") v=create ;;
    "pr co") v=checkout ;;
    "skill add") v=install ;;
    "skill show") v=preview ;;
    "extension uninstall") v=remove ;;
    "secret remove" | "variable remove") v=delete ;;
    *" ls") v=list ;;
  esac
  _GH_SUB="$g${v:+ $v}"
}

# _g02_own SUB: SUB (from _gh_canon) runs one of gh's own commands. A first word outside _GH_CMDS is an
# alias or an extension, which kern cannot read: ask, deny under autopilot. gh alias set, import and
# delete change what such a word runs, gh extension exec runs an extension, and gh extension install
# and upgrade install code: they ask too. gh's own --help, -h and --version pass; any other option
# first is read as unknown.
_g02_own() {
  local g="${1%% *}" why
  case "$g" in --help | -h | --version) return 0 ;; esac
  case "$_GH_CMDS" in
    *" $g "*) ;;
    *)
      vote ask G2 "gh $g is not one of gh's own commands (an alias or an extension); run the gh command it stands for so kern can check it"
      [ "$AUTOPILOT" = 1 ] && vote deny G2 "gh $g under autopilot: not one of gh's own commands"
      return 0
      ;;
  esac
  case "$1" in
    "alias set" | "alias import" | "alias delete") why="gh $1 changes what a gh word runs" ;;
    "extension exec") why="gh extension exec runs an extension kern cannot read" ;;
    "extension install" | "extension upgrade") why="gh $1 installs code that runs as a gh command" ;;
    *) return 0 ;;
  esac
  vote ask G2 "$why; the user confirms it"
  [ "$AUTOPILOT" = 1 ] && vote deny G2 "$why (under autopilot)"
  return 0
}

# _g02_hidden RECORD: a simple command whose head is neither git nor gh may still run gh (an unknown
# wrapper, xargs, find -exec). Each later word whose basename is gh (any case) is read past -R or
# --repo and its value; when the next word is one of _G02_GROUPS, G2 asks, deny under autopilot.
# Only a record whose text holds gh, or g and h apart by quotes or a backslash (g''h), and that does
# not start with the word git or gh, is read: no other record costs a process.
_g02_hidden() {
  local w=() t i=1 n
  case "$1" in *[Gg][Hh]* | *[Gg][\"\'\\]*[Hh]*) ;; *) return 0 ;; esac
  case "${1%%[[:space:]]*}" in [Gg][Ii][Tt] | */[Gg][Ii][Tt] | [Gg][Hh] | */[Gg][Hh]) return 0 ;; esac
  while IFS= read -r t; do w+=("$t"); done <<EOT
$(_cmd_words "$1")
EOT
  n=${#w[@]}
  case "${w[0]}" in "" | [Gg][Hh] | */[Gg][Hh] | [Gg][Ii][Tt] | */[Gg][Ii][Tt]) return 0 ;; esac
  while [ "$i" -lt "$n" ]; do
    t=${w[$i]}
    i=$((i + 1))
    case "${t##*/}" in [Gg][Hh]) ;; *) continue ;; esac
    while [ "$i" -lt "$n" ]; do
      case "${w[$i]}" in
        -R | --repo) i=$((i + 2)) ;;
        -R?* | --repo=*) i=$((i + 1)) ;;
        *) break ;;
      esac
    done
    [ "$i" -lt "$n" ] || return 0
    case "$_G02_GROUPS" in *" ${w[$i]} "*) ;; *) continue ;; esac
    vote ask G2 "gh inside ${w[0]} cannot be checked; run gh directly"
    [ "$AUTOPILOT" = 1 ] && vote deny G2 "gh inside ${w[0]} under autopilot: it cannot be checked; run gh directly"
    return 0
  done
}

# _gh_load CMD: the simple commands of CMD in _GH_RECS, and CMD in _GH_CMD. G2, G3 and G14 load
# the same command, so a second load of it keeps the records the first one read.
_gh_load() {
  local rec
  [ "${_GH_LOADED-}" = 1 ] && [ "$_GH_CMD" = "$1" ] && return 0
  _GH_CMD=$1
  _GH_RECS=()
  while IFS= read -r rec; do [ -n "$rec" ] && _GH_RECS+=("$rec"); done <<EOT
$(git_words "$1")
EOT
  _GH_LOADED=1
}

# _gh_args RECORD N: the words of a gh record after `gh` and its N command words (2 for `pr create`,
# 1 for `api`), one per line. An option before the command words (gh_sub lets only -R and --repo
# through) is kept.
_gh_args() {
  _cmd_words "$1" | awk -v k="$2" '
    NR == 1 { next }
    skip { skip = 0; print; next }
    n < k && ($0 == "-R" || $0 == "--repo") { skip = 1; print; next }
    n < k && /^-/ { print; next }
    n < k { n++; next }
    { print }'
}

# _gh_opts TABLE: reads words, one per line, and prints gh's reading of them (pflag), one token per
# line: `--long=value` for an option, a boolean as `--long=true` or `--long=false`; `@word` for an
# argument; `>redir` for a redirection and its target, which the shell takes out before gh reads
# options; `?word` for a word gh rejects: an unknown option, a missing value, a boolean value it
# cannot parse. A long option is its exact name (pflag has no abbreviations); a value option takes
# the next word even when it starts with -; short options cluster, and `-xVAL` and `-x=VAL` attach.
_gh_opts() {
  LC_ALL=C awk -v table="$1" '
    BEGIN {
      nt = split(table, ent, " ")
      for (i = 1; i <= nt; i++) {
        split(ent[i], f, "/"); K[f[1]] = f[3]
        if (f[2] != "-") sh[f[2]] = f[1]
      }
    }
    take { r[nr] = r[nr] $0; take = 0; next }
    /^[0-9]*(<|>|&>)/ { r[++nr] = $0; take = ($0 ~ /^[0-9]*[<>&|]+$/); next }
    { w[++n] = $0 }
    function bool(v) {
      if (v ~ /^(1|t|T|TRUE|true|True)$/) return "true"
      if (v ~ /^(0|f|F|FALSE|false|False)$/) return "false"
      return ""
    }
    # opt(name, v, has): one option; has is 1 when the value v came attached.
    function opt(name, v, has,   b) {
      if (K[name] == "b") {
        if (!has) { print "--" name "=true"; return }
        b = bool(v)
        print (b == "" ? "?--" name "=" v : "--" name "=" b)
        return
      }
      if (has) { print "--" name "=" v; return }
      if (p < n) { print "--" name "=" w[++p]; return }
      print "?--" name
    }
    END {
      for (k = 1; k <= nr; k++) print ">" r[k]
      for (p = 1; p <= n; p++) {
        x = w[p]
        if (dd) { print "@" x; continue }
        if (x == "--") { dd = 1; continue }
        if (x ~ /^--./) {
          a = substr(x, 3); eq = index(a, "="); nm = eq ? substr(a, 1, eq - 1) : a
          if (nm in K) opt(nm, substr(a, eq + 1), eq > 0); else print "?" x
          continue
        }
        if (x ~ /^-./) {
          for (j = 2; j <= length(x); j++) {
            c = substr(x, j, 1)
            if (!(c in sh)) { print "?-" c; break }
            nm = sh[c]; rest = substr(x, j + 1)
            if (substr(rest, 1, 1) == "=") { opt(nm, substr(rest, 2), 1); break }
            if (K[nm] == "b") { opt(nm, "", 0); continue }
            opt(nm, rest, rest != ""); break
          }
          continue
        }
        print "@" x
      }
    }'
}

# _gh_last TOKS NAME: the value of the last NAME option in TOKS. Exit 1 when there is none.
_gh_last() {
  local t v="" hit=1
  while IFS= read -r t; do
    case "$t" in "--$2="*) v=${t#--"$2"=}; hit=0 ;; esac
  done <<EOT
$1
EOT
  [ "$hit" = 0 ] || return 1
  printf '%s\n' "$v"
}

# _gh_only TOKS NAMES: every option in TOKS is one of the space-separated long NAMES.
_gh_only() {
  local t n
  while IFS= read -r t; do
    case "$t" in
      --*)
        n=${t#--}
        case " $2 " in *" ${n%%=*} "*) ;; *) return 1 ;; esac
        ;;
    esac
  done <<EOT
$1
EOT
}

# _gh_pos TOKS: the arguments in TOKS, one per line.
_gh_pos() {
  printf '%s\n' "$1" | sed -n 's/^@//p'
}

# _gh_literal RECORD: exit 0 when no word of RECORD expands: no $ or backtick outside single
# quotes, and no unquoted ~, glob (* ? [) or brace list ({a,b} or {a..b}).
_gh_literal() {
  printf '%s' "$1" | LC_ALL=C awk -v sq="'" '
    { buf = buf (NR > 1 ? "\n" : "") $0 }
    END {
      n = length(buf); q = ""; br = 0
      for (i = 1; i <= n; i++) {
        c = substr(buf, i, 1)
        if (q == sq) { if (c == sq) q = ""; continue }
        if (c == "\\") { i++; continue }
        if (q == "\"") { if (c == "\"") q = ""; else if (c == "$" || c == "`") exit 1; continue }
        if (c == sq || c == "\"") { q = c; continue }
        if (index("$`~*?[", c)) exit 1
        if (c == "{") br++
        else if (c == "}") { if (br) br-- }
        else if (br && (c == "," || (c == "." && substr(buf, i + 1, 1) == "."))) exit 1
      }
      exit (q != "")
    }'
}

# _gh_proven IDX TOKS: the gh record at IDX in _GH_RECS, read by _gh_opts as TOKS, may be allowed as
# the whole Bash call. All hold: it is the command's first record and starts with `gh `, so no cd,
# assignment, wrapper, function or alias definition comes before it; every later record is a
# read-only filter (_g01_filter); the command has no $( ) or backticks; no word of the record
# expands; TOKS has no word gh rejects and no redirection but to /dev/null or an fd copy.
_gh_proven() {
  local t i=1
  declare -F _g01_filter >/dev/null && declare -F _g01_quiet_redirect >/dev/null || return 1
  [ "$1" = 0 ] || return 1
  case "${_GH_RECS[0]}" in "gh "*) ;; *) return 1 ;; esac
  # shellcheck disable=SC2016 # a literal $( in the text
  case "$_GH_CMD" in *'$('* | *'`'*) return 1 ;; esac
  _gh_literal "${_GH_RECS[0]}" || return 1
  while IFS= read -r t; do
    case "$t" in
      "?"*) return 1 ;;
      ">"*) _g01_quiet_redirect "${t#>}" || return 1 ;;
    esac
  done <<EOT
$2
EOT
  while [ "$i" -lt "${#_GH_RECS[@]}" ]; do
    _g01_filter "${_GH_RECS[$i]}" || return 1
    i=$((i + 1))
  done
}

# _gh_file_ok FILE: FILE, relative to CWD, is a regular file and not a symlink, inside the main
# worktree and not under .git; and it is in the work_dir (.kern) or not ignored by git, so a secret
# kept out of git (.env) does not become a post either.
_gh_file_ok() {
  local f="$1" d main wd
  [ -n "$f" ] && [ -n "${KERN_MAIN-}" ] || return 1
  case "$f" in /*) ;; *) f="$CWD/$f" ;; esac
  [ -f "$f" ] && [ ! -L "$f" ] || return 1
  d=$(cd "$(dirname "$f")" 2>/dev/null && pwd -P) || return 1
  main=$(cd "$KERN_MAIN" 2>/dev/null && pwd -P) || return 1
  wd=$(settings_get work_dir .kern)
  case "$d/" in
    "$main/.git/"*) return 1 ;;
    "$main/${wd%/}/"*) return 0 ;;
    "$main/"*) ;;
    *) return 1 ;;
  esac
  # check-ignore exits 1 for a path git does not ignore; 0 is ignored, 128 an error.
  git -C "$d" -c core.fsmonitor=false check-ignore -q -- "${f##*/}" 2>/dev/null
  [ $? = 1 ]
}

# _g02_states HEAD: states of PRs whose head is HEAD, one per line. Exit 2 when gh cannot answer.
_g02_states() {
  command -v gh >/dev/null 2>&1 || return 2
  (cd "$CWD" 2>/dev/null && with_timeout 10 gh pr list --head "$1" --state all --json state --jq '.[].state') 2>/dev/null || return 2
}

# _g02_here IDX TOKS CUR HEAD: the PR is opened from this repo and its current branch CUR, so the
# duplicate check reads the right repo and head: the record is the first, starts with `gh ` and
# expands nothing, names no -R, and HEAD is CUR.
_g02_here() {
  [ "$1" = 0 ] && [ -n "$3" ] && [ "$4" = "$3" ] || return 1
  case "${_GH_RECS[0]}" in "gh "*) ;; *) return 1 ;; esac
  _gh_literal "${_GH_RECS[0]}" || return 1
  ! _gh_last "$2" repo >/dev/null
}

# _g02_proven IDX TOKS FILE: _gh_proven, only _GH_CREATE_SAFE options, no argument, and a body FILE
# that passes _gh_file_ok.
_g02_proven() {
  _gh_proven "$1" "$2" && _gh_only "$2" "$_GH_CREATE_SAFE" || return 1
  [ -z "$(_gh_pos "$2")" ] || return 1
  [ -z "$3" ] || _gh_file_ok "$3"
}

_g02_create() {
  local toks head cur file states policy fix
  toks=$(_gh_args "${_GH_RECS[$1]}" 2 | _gh_opts "$_GH_CREATE_OPTS")
  [ "$(_gh_last "$toks" help)" = true ] && return 0
  # pflag keeps the last setting, so `--draft --draft=false` and `--title --draft` open a ready PR.
  if [ "$(_gh_last "$toks" draft)" != true ]; then
    vote deny G2 "open PRs as drafts: add --draft"
    return 0
  fi
  policy=$(policy_for pr)
  if [ "$policy" = deny ]; then
    vote deny G2 "pr.policy deny"
    return 0
  fi
  cur=$(current_branch "$CWD") || cur=""
  head=$(_gh_last "$toks" head) || head=$cur
  file=$(_gh_last "$toks" body-file) || file=""
  if _g02_here "$1" "$toks" "$cur" "$head"; then
    if ! states=$(_g02_states "$cur"); then
      vote ask G2 "could not check for an existing PR on $cur (gh unavailable)"
      return 0
    fi
    case "$states" in
      *OPEN*) vote deny G2 "a PR is already open for $cur; report it instead of opening another"; return 0 ;;
      *MERGED* | *CLOSED*) vote ask G2 "a merged or closed PR already exists for $cur"; return 0 ;;
    esac
    if _g02_proven "$1" "$toks" "$file"; then
      if [ "$AUTOPILOT" = 1 ]; then
        vote allow G2 "autopilot: draft PR for $cur after dedup"
      elif [ "$policy" = auto ]; then
        vote allow G2 "pr.policy auto: draft PR for $cur"
      else
        vote ask G2 "open a draft PR for $cur"
      fi
      return 0
    fi
  fi
  # shellcheck disable=SC2016 # literal backticks
  fix='kern allows only `gh pr create --draft` alone, from the current branch, with --title, --base, --fill, --fill-first, --fill-verbose, --dry-run, --no-maintainer-edit, --body-file <file in the repo> or --head <current branch>'
  vote ask G2 "draft PR in a shape kern cannot check; $fix"
  [ "$AUTOPILOT" = 1 ] && vote deny G2 "draft PR of an unchecked shape under autopilot; $fix"
}

_g02_ready() {
  local toks
  toks=$(_gh_args "${_GH_RECS[$1]}" 2 | _gh_opts "$_GH_READY_OPTS")
  [ "$(_gh_last "$toks" undo)" = true ] && return 0
  [ "$(_gh_last "$toks" help)" = true ] && return 0
  vote ask G2 "gh pr ready marks a PR ready for review"
  [ "$AUTOPILOT" = 1 ] && vote deny G2 "gh pr ready under autopilot: drafts only"
}
