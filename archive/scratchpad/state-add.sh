# prompt_hashes: reads text on stdin and prints, space-separated, one hash per non-blank line of up to
# 500 characters (the first 20 such lines). A line is lowercased, its blanks folded to one space and
# trimmed, and a final run of . and ! dropped, so "Yes, approved!" and "yes,  approved" hash the same.
# G20 hashes an approved: quote the same way and looks for it among the user's last prompt's hashes.
prompt_hashes() {
  LC_ALL=C awk '
    BEGIN { for (i = 1; i < 256; i++) ord[sprintf("%c", i)] = i }
    {
      s = tolower($0); gsub(/[ \t\r]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s); sub(/[.!]+$/, "", s)
      if (s == "" || length(s) > 500 || ++n > 20) next
      h = 5381
      for (i = 1; i <= length(s); i++) h = (h * 33 + ord[substr(s, i, 1)]) % 4294967296
      out = out (out == "" ? "" : " ") sprintf("%.0f", h)
    }
    END { print out }'
}
