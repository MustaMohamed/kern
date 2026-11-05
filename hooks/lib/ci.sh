# shellcheck shell=bash
# kern CI read: a PR's checks, for scripts/ci-wait and G2's `gh pr ready` under a go. Needs settings.sh
# (list_has, and settings_get, which reads CWD and KERN_MAIN) and gitctx.sh (with_timeout).

# _CI_AWK: reads `gh pr checks --json name,bucket` output, gh's stderr mixed in, and prints one
# `<bucket><TAB><name>` line per object of the first JSON array, which starts on a line that opens with
# `[`. Only an object's own `name` and `bucket` string values count. Strings are decoded as json.sh
# decodes them, but a control character, escaped or not, becomes a space, so each check stays on its own
# line. Exit 0 read, 1 no array, 2 an array that does not close.
# shellcheck disable=SC2016 # awk text
_CI_AWK='
BEGIN {
  for (i = 32; i < 127; i++) U[sprintf("%04x", i)] = sprintf("%c", i)
  for (i = 0; i < 32; i++) U[sprintf("%04x", i)] = " "
  U["007f"] = " "
}
function str_end(p) {
  while (p <= n) {
    if (C[p] == "\\") { p += 2; continue }
    if (C[p] == "\"") return p
    p++
  }
  return 0
}
function dec(s,   P, k, i, h, out) {
  gsub(/\\\\/, "\001", s)
  gsub(/\\"/, "\"", s); gsub(/\\\//, "/", s)
  gsub(/\\[bfnrt]/, " ", s)
  if (index(s, "\\u")) {
    k = split(s, P, /\\u/)
    out = P[1]
    for (i = 2; i <= k; i++) {
      h = tolower(substr(P[i], 1, 4))
      if (h in U) out = out U[h] substr(P[i], 5)
      else out = out "\\u" P[i]
    }
    s = out
  }
  gsub(/\001/, "\\", s)
  gsub(/[\t\r\n]/, " ", s)
  return s
}
!on && /^[ \t\r]*\[/ { on = 1 }
on { buf = buf (got++ ? "\n" : "") $0 }
END {
  if (!on) exit 1
  n = split(buf, C, "")
  i = 1
  while (C[i] != "[") i++
  d = 0
  for (; i <= n; i++) {
    c = C[i]
    if (c == "\"") {
      e = str_end(i + 1)
      if (!e) exit 2
      if (d == 2 && want == "key") { key = substr(buf, i + 1, e - i - 1); want = "" }
      else if (d == 2 && want == "value") {
        if (key == "name") nm = dec(substr(buf, i + 1, e - i - 1))
        else if (key == "bucket") bk = dec(substr(buf, i + 1, e - i - 1))
        want = ""
      }
      i = e
      continue
    }
    if (c == "[" || c == "{") {
      d++
      if (d == 2 && c == "{") { obj = 1; want = "key"; key = ""; nm = ""; bk = "" }
      continue
    }
    if (c == "]" || c == "}") {
      if (d == 2 && obj && c == "}") { printf "%s\t%s\n", bk, nm; obj = 0 }
      d--
      if (d == 0) exit 0
      continue
    }
    if (d == 2 && c == ":") want = "value"
    else if (d == 2 && c == ",") want = "key"
  }
  exit 2
}'

# ci_read DIR: reads the checks of the PR for DIR's branch with `gh pr checks --json name,bucket`, run in
# DIR under with_timeout 10, and drops each check whose name `ci.advisory` lists (comma-separated, exact,
# case-sensitive). Prints `check: <name>: <bucket>` per check left, then one verdict: `ci: red <names>`
# when any is `fail` or `cancel`, else `ci: pending <names>` when any is neither that nor `pass` or
# `skipping` (gh 2.103's buckets; an unknown bucket waits), else `ci: none` when none is left, else
# `ci: clear`. The names are joined with ", ", each once. Exit 0 clear or none, 1 red, 3 pending. An empty
# array and gh's "no checks reported" error both read as none. Exit 2, with the cause on stderr, when gh is
# missing, DIR is no directory, or gh prints no JSON array that closes, or exits other than 0 or 8 (gh's
# exit code for pending checks).
ci_read() {
  local out rc=0 recs prc=0 adv rest line bucket name red="" pend="" n=0
  command -v gh >/dev/null 2>&1 || { printf 'ci_read: gh is not installed\n' >&2; return 2; }
  [ -d "$1" ] || { printf 'ci_read: no directory at %s\n' "$1" >&2; return 2; }
  out=$(cd "$1" && with_timeout 10 gh pr checks --json name,bucket 2>&1) || rc=$?
  recs=$(printf '%s\n' "$out" | env LC_ALL=C awk "$_CI_AWK") || prc=$?
  if [ "$prc" = 1 ]; then
    case "$out" in *"no checks reported"*) recs="" prc=0 ;; esac
  elif [ "$prc" = 0 ]; then
    case "$rc" in 0 | 8) ;; *) prc=3 ;; esac
  fi
  if [ "$prc" != 0 ]; then
    line=${out%%$'\n'*}
    printf 'ci_read: gh pr checks exited %s with no JSON kern can read%s\n' "$rc" "${line:+: $line}" >&2
    return 2
  fi
  # Exit 4 leaves a settings file unread that may name more checks; the names read still drop, and fewer
  # dropped checks gate more.
  adv=$(settings_get ci.advisory "") || :
  rest=${recs:+$recs$'\n'}
  while [ -n "$rest" ]; do
    line=${rest%%$'\n'*}
    rest=${rest#*$'\n'}
    bucket=${line%%$'\t'*}
    name=${line#*$'\t'}
    if [ -n "$adv" ] && list_has "$adv" "$name"; then continue; fi
    printf 'check: %s: %s\n' "$name" "$bucket"
    n=$((n + 1))
    case "$bucket" in
      pass | skipping) ;;
      fail | cancel) case ", $red, " in *", $name, "*) ;; *) red="${red:+$red, }$name" ;; esac ;;
      *) case ", $pend, " in *", $name, "*) ;; *) pend="${pend:+$pend, }$name" ;; esac ;;
    esac
  done
  if [ -n "$red" ]; then
    printf 'ci: red %s\n' "$red"
    return 1
  elif [ -n "$pend" ]; then
    printf 'ci: pending %s\n' "$pend"
    return 3
  elif [ "$n" = 0 ]; then
    printf 'ci: none\n'
  else
    printf 'ci: clear\n'
  fi
  return 0
}
