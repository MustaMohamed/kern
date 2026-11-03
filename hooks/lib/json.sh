# shellcheck shell=bash
# JSON helpers for kern hooks. POSIX awk only, so behaviour is the same with or without jq.
# All functions read the JSON document from $KERN_INPUT.

# Scanner shared by json_get and json_get_raw. Prints the value of the first object key equal to
# `key`. mode=str prints a decoded string value; mode=raw prints the raw JSON text of any value.
# The input is split into the array C once, one character per element: substr per character is
# quadratic in BWK awk. Exit 0 found, 1 absent (or, in str mode, not a string), 2 malformed input.
_KERN_JSON_AWK='
function skip_ws(p) { while (p <= n && index(" \t\r\n", C[p]) > 0) p++; return p }
function str_end(p,   d) {
  # p is the index just after an opening quote; returns the index of the closing quote, or 0.
  while (p <= n) {
    d = C[p]
    if (d == "\\") { p += 2; continue }
    if (d == "\"") return p
    p++
  }
  return 0
}
# decode S: prints the string body S decoded. An escaped backslash is held as \001 while the other
# escapes go, so each backslash left starts an escape. \u0001 to \u007f, in either hex case, print as
# the character, once: the pieces between \u escapes are printed one by one, so a decoded \u0001 is
# not read back as a backslash and the work stays linear. \u0080 and above stay as the six characters.
# \u0000 exits 1 before anything prints, as bash cannot hold the byte.
function decode(s,   n, P, i, h) {
  gsub(/\\\\/, "\001", s)
  if (index(s, "\\u0000")) exit 1
  gsub(/\\"/, "\"", s); gsub(/\\\//, "/", s)
  gsub(/\\n/, "\n", s); gsub(/\\t/, "\t", s); gsub(/\\r/, "\r", s)
  gsub(/\\b/, "\b", s); gsub(/\\f/, "\f", s)
  if (!index(s, "\\u")) { gsub(/\001/, "\\", s); printf "%s", s; return }
  for (i = 1; i < 128; i++) U[sprintf("%04x", i)] = sprintf("%c", i)
  n = split(s, P, /\\u/)
  for (i = 1; i <= n; i++) {
    s = P[i]
    if (i > 1) {
      h = tolower(substr(s, 1, 4))
      if (h in U) { printf "%s", U[h]; s = substr(s, 5) }
      else printf "%s", "\\u"
    }
    gsub(/\001/, "\\", s)
    printf "%s", s
  }
}
function raw_end(p,   c, depth, e) {
  c = C[p]
  if (c == "\"") { e = str_end(p + 1); return e }
  if (c == "{" || c == "[") {
    depth = 0
    while (p <= n) {
      c = C[p]
      if (c == "\"") { e = str_end(p + 1); if (!e) return 0; p = e + 1; continue }
      if (c == "{" || c == "[") depth++
      else if (c == "}" || c == "]") { depth--; if (depth == 0) return p }
      p++
    }
    return 0
  }
  while (p <= n && index(",}] \t\r\n", C[p]) == 0) p++
  return p - 1
}
{ buf = buf (NR > 1 ? "\n" : "") $0 }
END {
  n = split(buf, C, ""); i = 1
  while (i <= n) {
    c = C[i]
    if (c != "\"") { i++; continue }
    e = str_end(i + 1)
    if (!e) exit 2
    tok = substr(buf, i + 1, e - i - 1)
    i = e + 1
    k = skip_ws(i)
    if (substr(buf, k, 1) != ":" || tok != key) continue
    k = skip_ws(k + 1)
    if (k > n) exit 2
    if (mode == "str") {
      if (substr(buf, k, 1) != "\"") exit 1
      e = str_end(k + 1)
      if (!e) exit 2
      decode(substr(buf, k + 1, e - k - 1))
      exit 0
    }
    e = raw_end(k)
    if (!e || e < k) exit 2
    printf "%s", substr(buf, k, e - k + 1)
    exit 0
  }
  exit 1
}'

# json_get KEY: decoded string value of the first "KEY": whose value is a string.
json_get() {
  printf '%s' "${KERN_INPUT-}" | env LC_ALL=C awk -v key="$1" -v mode=str "$_KERN_JSON_AWK"
}

# json_get_raw KEY: raw JSON text of the first "KEY": value (object, array, string or literal).
json_get_raw() {
  printf '%s' "${KERN_INPUT-}" | env LC_ALL=C awk -v key="$1" -v mode=raw "$_KERN_JSON_AWK"
}

# json_escape: stdin escaped for the body of a JSON string, without the surrounding quotes. Every
# byte below 0x20 is escaped (tab, CR and newline as \t, \r and \n, the rest as \u00XX): reasons
# echo command words, and json_get decodes \b and \f to raw bytes.
json_escape() {
  env LC_ALL=C awk '
    BEGIN {
      for (i = 1; i < 32; i++) if (i != 10) { c = sprintf("%c", i); e[c] = sprintf("\\u%04x", i); cls = cls c }
      e["\t"] = "\\t"; e["\r"] = "\\r"; e["\\"] = "\\\\"; e["\""] = "\\\""
      re = "[" cls "\\\\\"]"
    }
    {
      s = $0; out = ""
      while (match(s, re)) { out = out substr(s, 1, RSTART - 1) e[substr(s, RSTART, 1)]; s = substr(s, RSTART + 1) }
      printf "%s%s%s", (NR > 1 ? "\\n" : ""), out, s
    }'
}

# json_ok: exit 0 when $KERN_INPUT is one object: starts with { and ends with } after trimming, and
# holds no \u0000 escape. json_get refuses that escape, so a guard would read its field as absent; the
# hook fails closed instead. An escaped backslash before u0000 is text, and awk runs only when the
# input holds those six characters.
json_ok() {
  local t
  t=$(printf '%s' "${KERN_INPUT-}" | tr -d ' \t\r\n')
  case "$t" in '{'*'}') ;; *) return 1 ;; esac
  case "${KERN_INPUT-}" in *'\u0000'*) ;; *) return 0 ;; esac
  printf '%s' "${KERN_INPUT-}" | env LC_ALL=C awk '{ gsub(/\\\\/, ""); if (index($0, "\\u0000")) exit 1 }'
}

# ti_get KEY: json_get applied to the hook's tool_input object ($TOOL_INPUT, set by pre-tool-use).
ti_get() {
  KERN_INPUT="${TOOL_INPUT-}" json_get "$1"
}
