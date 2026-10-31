# shellcheck shell=awk
# hreev(s, r): the one matcher for a parameter expansion that re-evaluates its stored value, so a $( ) or
# backtick kept in the value runs. Shared by git_words (gitctx.sh _split_words, on an unquoted here-doc
# body) and by G00 (g00-unproven.sh g0_reeval, on the expandable text of a command). Keeping one copy is
# why the two sites cannot drift (they did: P1 re-review 1). It flags:
#   - a bash @P transform, anywhere an @P} appears (${x@P}, ${a[${i}]@P});
#   - a bash indirection through a name or a positional parameter (${!y}, ${!1}, ${!@}, ${!*}: the value
#     may hold a subscript), but not ${!y[@]}, ${!y[*]}, ${!pre*} or ${!pre@}, which list keys or names,
#     nor ${!} and ${!#}, ${!-}, ${!?}, ${!$}, which read a special parameter, nor a plain ${!v} that
#     hloop proves holds a literal name;
#   - a zsh flag group holding e, P (its name may hold a subscript), or % (prompt expansion, which runs a
#     $( ) under PROMPT_SUBST). The group is walked as zsh reads it: j s Z _ I g take one delimited
#     argument, l and r up to three, each from its delimiter to the match ( ) [ ] { } < >, or the same
#     character again, and a flag inside an argument is its text. A backslash before the $ is not read,
#     so an escaped expansion counts; an argument that never closes counts.
# Bash 3.2 awk, mawk and gawk all run this: no gawk-only features. P20 (M3) may fold it into the shared
# scanner; until then this file is the single source both awk programs load.
function hreev(s, r,   n, C, i, k, c, d, e, m, t, g) {
  g = hloop(r)
  if (index(s, "@P}")) return 1
  if (!index(s, "${")) return 0
  n = split(s, C, "")
  for (i = 1; i < n; i++) {
    if (C[i] != "$" || C[i + 1] != "{") continue
    if (C[i + 2] == "!") {
      for (k = i + 3; k <= n && C[k] ~ /[A-Za-z0-9_]/; k++) ;
      if (k == i + 3 && C[k] != "@" && C[k] != "*") continue
      if (g != "" && C[k] == "}" && substr(s, i + 3, k - i - 3) == g) continue
      t = substr(s, k, 4)
      if (k > i + 3 && (t == "[@]}" || t == "[*]}" || substr(t, 1, 2) == "*}" || substr(t, 1, 2) == "@}")) continue
      return 1
    }
    if (C[i + 2] != "(") continue
    for (k = i + 3; k <= n && C[k] != ")"; k++) {
      c = C[k]
      if (c == "e" || c == "P" || c == "%") return 1
      if (index("jsZ_Ig", c)) m = 1
      else if (c == "l" || c == "r") m = 3
      else continue
      d = C[k + 1]
      e = d == "(" ? ")" : d == "[" ? "]" : d == "{" ? "}" : d == "<" ? ">" : d
      if (d == "") return 1
      for (; m > 0 && C[k + 1] == d; m--) {
        for (k += 2; k <= n && C[k] != e; k++) ;
        if (k > n) return 1
      }
    }
  }
  return 0
}
# hloop(r): the name whose plain ${!name} cannot re-evaluate in this record, or "". G00 calls hreev once per
# record from its main rule and passes the record as written as r; s is not that, since g0_reeval drops
# quotes and escapes. The name is v after a record `for v in NAME...`, every word a plain name, and holds in
# the next record when that opens the loop body with do: v then holds a name with no subscript, and the words
# of that one command expand before it can change v. A later command in the body may have changed v, and may
# be a function called later, so it stays flagged. The here-doc check passes no r, so it never gets a name.
function hloop(r,   W) {
  if (r ~ /^for[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]+in([ \t]+[A-Za-z_][A-Za-z0-9_]*)+$/) {
    split(r, W, " "); hl_name = W[2]; hl_nr = NR
    return ""
  }
  return (hl_nr && NR == hl_nr + 1 && r ~ /^do[ \t]/) ? hl_name : ""
}
