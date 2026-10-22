# The code fence reader that plan-check and task-brief share, so both agree on which lines are fenced and
# a task one finds the other finds too (audit C-M1: two copies had drifted apart). Loaded ahead of a
# program's own text; it holds functions only.
#
# Code fences as CommonMark reads them: an opener is a run of 3 or more backticks or tildes after at most
# 3 spaces, and the info string of a backtick opener holds no backtick; only a run of the same character,
# at least as long, with nothing but spaces after it, closes the fence. So a tilde fence may hold a backtick
# line, and a longer fence may hold a shorter one. Rule from pstack check-plan.mjs:47-74 (MIT).

# fence_run(s, c): the length of the run of character c at the start of s, after at most 3 spaces.
function fence_run(s, c,   n) {
  sub(/^ ? ? ?/, "", s)
  n = 0
  while (substr(s, n + 1, 1) == c) n++
  return n
}

# fence_mark(line): 1 when line opens a fence, -1 when it closes the open one, else 0. Call it once per
# line, in order. It keeps its state in the globals fence (1 inside a fence), fence_ch and fence_len, and
# reads line without a trailing CR.
function fence_mark(line,   c, run, rest) {
  sub(/\r$/, "", line)
  if (fence) {
    run = fence_run(line, fence_ch)
    if (run < fence_len) return 0
    rest = line; sub(/^ ? ? ?/, "", rest)
    if (substr(rest, run + 1) !~ /^[ \t]*$/) return 0
    fence = 0
    return -1
  }
  c = "`"; run = fence_run(line, c)
  if (run < 3) { c = "~"; run = fence_run(line, c) }
  if (run < 3) return 0
  rest = line; sub(/^ ? ? ?/, "", rest)
  if (c == "`" && index(substr(rest, run + 1), "`") > 0) return 0
  fence = 1; fence_ch = c; fence_len = run
  return 1
}
