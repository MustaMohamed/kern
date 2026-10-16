# Reads a shell snapshot; prints `name<TAB>expansion` for each alias whose expansion, after zsh's
# head-word chain, runs git or gh.
function unq(s,    i, c, out, n) {
  out = ""; n = length(s); i = 1
  while (i <= n) {
    c = substr(s, i, 1)
    if (c == sq) {
      j = index(substr(s, i + 1), sq); if (!j) return "\001"
      out = out substr(s, i + 1, j - 1); i += j + 1
    } else if (c == "\\") {
      if (i == n) return "\001"
      out = out substr(s, i + 1, 1); i += 2
    } else if (c == "\"" || c == "$" || c == "`" || c == " " || c == "\t") {
      return "\001"
    } else { out = out c; i++ }
  }
  return out
}
function head(v,    w, n, k) {
  n = split(v, w, /[ \t]+/)
  for (k = 1; k <= n; k++) {
    if (w[k] == "") continue
    if (w[k] ~ /^[A-Za-z_][A-Za-z0-9_]*=/) continue
    hk = k; return w[k]
  }
  hk = 0; return ""
}
/^alias / {
  line = substr($0, 7)
  if (substr(line, 1, 3) == "-- ") line = substr(line, 4)
  e = index(line, "="); if (e < 2) next
  name = substr(line, 1, e - 1)
  if (name ~ /[ \t\/'"\\$`=]/) next
  v = unq(substr(line, e + 1))
  if (v == "\001" || v == "") next
  val[name] = v; order[++cnt] = name
}
END {
  for (i = 1; i <= cnt; i++) {
    nm = order[i]; v = val[nm]; delete seen; seen[nm] = 1
    for (d = 0; d < 8; d++) {
      h = head(v)
      if (h == "" || !(h in val) || (h in seen)) break
      seen[h] = 1
      n = split(v, w, /[ \t]+/); rest = ""; pre = ""
      for (k = 1; k <= n; k++) if (w[k] != "") { if (k < hk) pre = pre w[k] " "; else if (k > hk) rest = rest " " w[k] }
      v = pre val[h] rest
    }
    h = head(v); b = h; sub(/.*\//, "", b)
    if (b == "git" || b == "gh") print nm "\t" v
  }
}
