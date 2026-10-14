# The frontmatter reader that guard G20, ledger-open and plan-check share, so all three agree on which
# lines are a file's frontmatter: from a first line --- up to the next --- line. A --- line is read
# with trailing blanks and a trailing CR dropped, and the first line also with a UTF-8 byte order mark
# dropped. If they disagreed, a file could hold an approval that G20 never saw and ledger-open accepts.
#
# fm_delim(s, first): s is a --- line; first: s is the file's first line.
function fm_delim(s, first) {
  if (first) sub(/^\357\273\277/, "", s)
  sub(/[ \t\r]+$/, "", s)
  return s == "---"
}

# Run with -v fm_print=1 to print the frontmatter lines of the input, each without a trailing CR. Exit 3
# when the block opens and never closes; its lines are still printed. A program that loads this file
# for fm_delim alone leaves fm_print unset, and these rules do nothing.
fm_print && FNR == 1 { if (!fm_delim($0, 1)) exit; fm_open = 1; next }
fm_print && fm_delim($0, 0) { fm_closed = 1; exit }
fm_print { sub(/\r$/, ""); print }
END { if (fm_print && fm_open && !fm_closed) exit 3 }
