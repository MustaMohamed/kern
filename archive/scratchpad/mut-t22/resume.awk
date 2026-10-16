# A literal reading of references/resume.md "Where to continue", for the probe. TASKS: space-separated task numbers in order.
/^Worktree: / { wt = 1 }
/^Wave: tasks / { s = $0; sub(/^Wave: tasks /, "", s); sub(/ forks=.*/, "", s); n = split(s, w, " "); for (i = 1; i <= n; i++) wave[w[i]] = 1 }
/^Applied: Task [0-9]+ / { applied[$3] = 1 }
/^parked: / { if (match($0, /Task [0-9]+/)) parked[substr($0, RSTART + 5, RLENGTH - 5)] = 1 }
/^Task [0-9]+: / {
  t = $2; sub(/:$/, "", t)
  if ($0 ~ /: complete /) complete[t] = 1
  if ($0 ~ /: review round=/) reviews[t]++
  if ($0 !~ /: minor \(deferred\): /) last[t] = $0
}
END {
  if (!wt) { print "step 5"; exit }
  m = split(ENVIRON["TASKS"], order, " ")
  for (i = 1; i <= m; i++) { t = order[i]; if (wave[t] && complete[t] && !applied[t] && !parked[t]) { print "step 11 for Task " t; exit } }
  for (i = 1; i <= m; i++) {
    t = order[i]; if (complete[t] || parked[t]) continue
    r = reviews[t] + 1; l = last[t]
    if (l == "") print "step 6 for Task " t
    else if (l ~ /: start tree=/) print "Task " t ": keep start tree; snapshot equal: dispatch again; changed: step 8 as round " r
    else if (l ~ /: review round=/ && l !~ /spec=compliant quality=approved$/) print (r > 3 ? "Task " t ": past the cap, split proposal" : "Task " t ": write fix round=" r ", continue step 9")
    else if (l ~ /: fix round=/) print "Task " t ": resume that fix round"
    else print "Task " t ": step 10"
    exit
  }
  print "step 12"
}
