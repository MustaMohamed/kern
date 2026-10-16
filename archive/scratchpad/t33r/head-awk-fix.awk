
{ buf = buf (NR > 1 ? "\n" : "") $0 }
END {
  split("if then elif else do while until ! { time nocorrect coproc", A, " "); for (k in A) RW[A[k]] = 1
  n = split(buf, C, ""); i = 1; skip = 0
  for (;;) {
    while (i <= n && (C[i] == " " || C[i] == "\t")) i++
    if (i > n) exit
    s = i; q = ""; d = 0
    for (; i <= n; i++) {
      c = C[i]
      if (q == sq) { if (c == sq) q = ""; continue }
      if (c == "\\") { i++; continue }
      if (q == "`") { if (c == "`") q = ""; continue }
      if (c == "$" && (C[i + 1] == "(" || C[i + 1] == "{")) { QS[++d] = q; q = ""; i++; continue }
      if (q == "\"") { if (c == "\"") q = ""; continue }
      if (d && (c == "(" || c == "{")) { QS[++d] = ""; continue }
      if (d && (c == ")" || c == "}")) { q = QS[d--]; continue }
      if (c == sq || c == "\"" || c == "`") { q = c; continue }
      if (!d && (c == " " || c == "\t")) break
    }
    w = substr(buf, s, i - s)
    if (skip) { skip = 0; continue }
    if (w in RW) continue
    if (w == "repeat") { skip = 1; continue }
    t = w; sub(/^[0-9]+/, "", t)
    if (t ~ /^(<|>|&>)/) { if (t !~ /[^<>&|]/) skip = 1; continue }
    if (w ~ /^[A-Za-z_][A-Za-z0-9_]*[+]?=/) continue
    print substr(buf, 1, s - 1); print w; print substr(buf, i); exit
  }
}