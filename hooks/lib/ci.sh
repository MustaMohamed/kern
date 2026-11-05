# shellcheck shell=bash
# kern CI read: a PR's checks, for scripts/ci-wait and G2's `gh pr ready` under a go. Needs settings.sh
# (list_has, and settings_get, which reads CWD and KERN_MAIN) and gitctx.sh (with_timeout).

# _CI_AWK: reads the stdout of `gh pr checks --json name,bucket` and prints one `<bucket><TAB><name>`
# line per object of its JSON array. The array starts on the first line that opens with `[` followed by
# `{`, `]` or the line's end, so a line such as `[git remote -v]` starts none. Only an object's own `name`
# and `bucket` string values count. Strings are decoded as json.sh decodes them, but a control character,
# escaped or not, becomes a space, so each check stays on its own line. The array must be whole: every
# string closes, brackets pair, each bare word is true, false, null or a number, and only blanks follow
# it. Exit 0 read, 1 no array, 2 an array that is not whole.
# shellcheck disable=SC2016 # awk text
_CI_AWK='
BEGIN {
  for (i = 32; i < 127; i++) U[sprintf("%04x", i)] = sprintf("%c", i)
  for (i = 0; i < 32; i++) U[sprintf("%04x", i)] = " "
  U["007f"] = " "
  LIT = "+-.0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
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
!on && (/^[ \t\r]*\[[ \t\r]*[]{]/ || /^[ \t\r]*\[[ \t\r]*$/) { on = 1 }
on { buf = buf (got++ ? "\n" : "") $0 }
END {
  if (!on) exit 1
  n = split(buf, C, "")
  i = 1
  while (C[i] != "[") i++
  d = 0
  for (; i <= n; i++) {
    c = C[i]
    if (index(" \t\r\n", c)) continue
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
      S[++d] = c
      if (d == 2 && c == "{") { obj = 1; want = "key"; key = ""; nm = ""; bk = "" }
      continue
    }
    if (c == "]" || c == "}") {
      if (S[d] != (c == "]" ? "[" : "{")) exit 2
      if (d == 2 && obj && c == "}") { printf "%s\t%s\n", bk, nm; obj = 0 }
      if (--d == 0) {
        if (substr(buf, i + 1) ~ /[^ \t\r\n]/) exit 2
        exit 0
      }
      continue
    }
    if (c == ":") { if (d == 2) want = "value"; continue }
    if (c == ",") { if (d == 2) want = "key"; continue }
    j = i
    while (j <= n && index(LIT, C[j])) j++
    if (j == i) exit 2
    if (substr(buf, i, j - i) !~ /^(true|false|null|-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?)$/) exit 2
    if (d == 2 && want == "value") want = ""
    i = j - 1
  }
  exit 2
}'

# ci_read DIR: reads the checks of the PR for DIR's branch with `gh pr checks --json name,bucket`, run in
# DIR under with_timeout 10 with GH_DEBUG set empty, so gh logs nothing and does not fall back to DEBUG.
# It drops each check whose name `ci.advisory` lists (comma-separated, exact, case-sensitive). Prints
# `check: <name>: <bucket>` per check left, then one verdict: `ci: red <names>` when any is `fail` or
# `cancel`, else `ci: pending <names>` when any is neither that nor `pass` or `skipping` (gh 2.103's
# buckets; an unknown bucket waits), else `ci: none` when none is left, else `ci: clear`. The names are
# joined with ", ", each once. Exit 0 clear or none, 1 red, 3 pending. A whole JSON array on gh's stdout
# is the read, whatever gh's exit code: gh may exit 1 on a failed check or 8 on a pending one. An empty
# array and gh's "no checks reported" error on stderr both read as none. Exit 2, with the cause on stderr,
# when gh is missing, DIR is no directory, or gh's stdout holds no whole array.
ci_read() {
  local res out err rc recs prc=0 adv rest line bucket name red="" pend="" n=0
  command -v gh >/dev/null 2>&1 || { printf 'ci_read: gh is not installed\n' >&2; return 2; }
  [ -d "$1" ] || { printf 'ci_read: no directory at %s\n' "$1" >&2; return 2; }
  # gh's stderr reaches the capture through fd 3 while gh runs; its exit code and stdout follow, each
  # after a \036 byte, once gh has exited. JSON holds no raw \036, so the last two split it. fd 3 closes
  # for with_timeout, so its watchdog cannot hold the capture open.
  res=$(
    {
      out=$(cd "$1" && GH_DEBUG='' with_timeout 10 gh pr checks --json name,bucket 2>&3 3>&-)
      printf '\036%s\036%s' "$?" "$out"
    } 3>&1
  )
  out=${res##*$'\036'}
  res=${res%$'\036'*}
  rc=${res##*$'\036'}
  err=${res%$'\036'*}
  recs=$(printf '%s\n' "$out" | env LC_ALL=C awk "$_CI_AWK") || prc=$?
  if [ "$prc" = 1 ]; then
    case "$err" in *"no checks reported"*) recs="" prc=0 ;; esac
  fi
  if [ "$prc" != 0 ]; then
    line=${err%%$'\n'*}
    [ -n "$line" ] || line=${out%%$'\n'*}
    printf 'ci_read: gh pr checks exited %s with no whole JSON array on stdout%s\n' "$rc" "${line:+: $line}" >&2
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
