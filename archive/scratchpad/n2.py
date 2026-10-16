def rep(p,a,b):
    s=open(p).read(); assert s.count(a)==1,(p,a[:70]); open(p,'w').write(s.replace(a,b))
rep('hooks/lib/aliases.sh','''      if (c == "$" && (C[i + 1] == "(" || C[i + 1] == "{")) { d++; i++; continue }
      if (d && (c == "(" || c == "{")) { d++; continue }
      if (d && (c == ")" || c == "}")) { d--; continue }
      if (q == "\\"") { if (c == "\\"" && !d) q = ""; continue }''','''      # QS[d]: the quote open outside the $( ) or ${ } at depth d, restored when it closes.
      if (c == "$" && (C[i + 1] == "(" || C[i + 1] == "{")) { QS[++d] = q; q = ""; i++; continue }
      if (q == "\\"") { if (c == "\\"") q = ""; continue }
      if (d && (c == "(" || c == "{")) { QS[++d] = ""; continue }
      if (d && (c == ")" || c == "}")) { q = QS[d--]; continue }''')
rep('hooks/lib/aliases.sh','''# the text after it, all as written. Words are split at blanks outside quotes, $( ), ${ } and backticks;
# the words skipped are those alias_expand skips.''','''# the text after it, all as written. Words are split at blanks outside quotes, $( ), ${ } and backticks;
# each $( ) or ${ } keeps its own quote state, so a quote inside one closes there. The words skipped are
# those alias_expand skips.''')
