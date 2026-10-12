# shellcheck shell=bash
# JSON helpers for kern hooks. POSIX awk only, so behaviour is the same with or without jq.
# All functions read the JSON document from $KERN_INPUT.

# Scanner shared by json_get and json_get_raw. Prints the value of the first object key equal to
# `key`. mode=str prints a decoded string value; mode=raw prints the raw JSON text of any value.
# Exit 0 found, 1 absent (or, in str mode, not a string), 2 malformed input.
_KERN_JSON_AWK='
function skip_ws(p) { while (p <= n && index(" \t\r\n", substr(buf, p, 1)) > 0) p++; return p }
function str_end(p,   d) {
  # p is the index just after an opening quote; returns the index of the closing quote, or 0.
  while (p <= n) {
    d = substr(buf, p, 1)
    if (d == "\\") { p += 2; continue }
    if (d == "\"") return p
    p++
  }
  return 0
}
function decode(s) {
  gsub(/\\\\/, "\001", s)
  gsub(/\\"/, "\"", s); gsub(/\\\//, "/", s)
  gsub(/\\n/, "\n", s); gsub(/\\t/, "\t", s); gsub(/\\r/, "\r", s)
  gsub(/\\b/, "\b", s); gsub(/\\f/, "\f", s)
  gsub(/\001/, "\\", s)
  return s
}
function raw_end(p,   c, depth, e) {
  c = substr(buf, p, 1)
  if (c == "\"") { e = str_end(p + 1); return e }
  if (c == "{" || c == "[") {
    depth = 0
    while (p <= n) {
      c = substr(buf, p, 1)
      if (c == "\"") { e = str_end(p + 1); if (!e) return 0; p = e + 1; continue }
      if (c == "{" || c == "[") depth++
      else if (c == "}" || c == "]") { depth--; if (depth == 0) return p }
      p++
    }
    return 0
  }
  while (p <= n && index(",}] \t\r\n", substr(buf, p, 1)) == 0) p++
  return p - 1
}
{ buf = buf (NR > 1 ? "\n" : "") $0 }
END {
  n = length(buf); i = 1
  while (i <= n) {
    c = substr(buf, i, 1)
    if (c != "\"") { i++; continue }
    e = str_end(i + 1)
    if (!e) exit 2
    tok = substr(buf, i + 1, e - i - 1)
    i = e + 1
    k = skip_ws(i)
    if (substr(buf, k, 1) != ":" || tok != key) continue
    k = skip_ws(k + 1)
    if (mode == "str") {
      if (substr(buf, k, 1) != "\"") exit 1
      e = str_end(k + 1)
      if (!e) exit 2
      printf "%s", decode(substr(buf, k + 1, e - k - 1))
      exit 0
    }
    e = raw_end(k)
    if (!e) exit 2
    printf "%s", substr(buf, k, e - k + 1)
    exit 0
  }
  exit 1
}'

# json_get KEY: decoded string value of the first "KEY": whose value is a string.
json_get() {
  printf '%s' "${KERN_INPUT-}" | LC_ALL=C awk -v key="$1" -v mode=str "$_KERN_JSON_AWK"
}

# json_get_raw KEY: raw JSON text of the first "KEY": value (object, array, string or literal).
json_get_raw() {
  printf '%s' "${KERN_INPUT-}" | LC_ALL=C awk -v key="$1" -v mode=raw "$_KERN_JSON_AWK"
}

# json_escape: stdin escaped for the body of a JSON string, without the surrounding quotes.
json_escape() {
  local tab cr
  tab=$(printf '\t'); cr=$(printf '\r')
  LC_ALL=C sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e "s/${tab}/\\\\t/g" -e "s/${cr}/\\\\r/g" |
    LC_ALL=C awk 'BEGIN { sep = "" } { printf "%s%s", sep, $0; sep = "\\n" }'
}

# json_ok: exit 0 when $KERN_INPUT is one object: starts with { and ends with } after trimming.
json_ok() {
  local t
  t=$(printf '%s' "${KERN_INPUT-}" | tr -d ' \t\r\n')
  case "$t" in '{'*'}') return 0 ;; *) return 1 ;; esac
}

# ti_get KEY: json_get applied to the hook's tool_input object ($TOOL_INPUT, set by pre-tool-use).
ti_get() {
  KERN_INPUT="${TOOL_INPUT-}" json_get "$1"
}
