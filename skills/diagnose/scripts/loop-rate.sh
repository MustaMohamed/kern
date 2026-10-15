#!/usr/bin/env bash
# Run a reproduction loop N times and report how often it is red and how long one run takes, so a
# flaky bug's rate is a number before and after the fix.
# Usage: loop-rate.sh N -- CMD...    Prints: loop-rate: <red>/<N> red, median <seconds>s
# A run is red when CMD exits non-zero. CMD's own output is discarded; CMD is one command with its
# arguments, so wrap a pipeline as sh -c '...'. Exit 0. Exit 2: usage, N not a whole number from 1 to
# 999999999, CMD not found, a run that exits 126 or 127 (it could not run), or the timing could not be read.
# Adapted from pocock diagnosing-bugs (raise the reproduction rate and measure it).
set -euo pipefail
if [ $# -lt 3 ] || [ "$2" != "--" ]; then
  echo "usage: loop-rate.sh N -- CMD..." >&2
  exit 2
fi
n=$1
shift 2
case "$n" in '' | *[!0123456789]*) echo "loop-rate: N must be a whole number above 0: $n" >&2; exit 2 ;; esac
[ "${#n}" -le 9 ] || { echo "loop-rate: N is too large: $n" >&2; exit 2; }
n=$((10#$n))
[ "$n" -ge 1 ] || { echo "loop-rate: N must be a whole number above 0: $n" >&2; exit 2; }
command -v "$1" > /dev/null 2>&1 || { echo "loop-rate: command not found: $1" >&2; exit 2; }
tmp=$(mktemp -d "${TMPDIR:-/tmp}/kern-loop.XXXXXX") || { echo "loop-rate: cannot create a temp directory" >&2; exit 2; }
trap 'rm -rf "$tmp"' EXIT
# bash's own timer prints the real seconds on the group's stderr; a C locale keeps the decimal point a dot.
export LC_ALL=C
TIMEFORMAT=%R
: > "$tmp/secs"
red=0
i=0
while [ "$i" -lt "$n" ]; do
  i=$((i + 1))
  rc=0
  { time "$@" > /dev/null 2>&1; } 2> "$tmp/time" || rc=$?
  if [ "$rc" -eq 126 ] || [ "$rc" -eq 127 ]; then
    echo "loop-rate: the command could not run (exit $rc)" >&2
    exit 2
  fi
  [ "$rc" -eq 0 ] || red=$((red + 1))
  tr -d '\r' < "$tmp/time" | grep -E '^[0123456789]+[.][0123456789]+$' >> "$tmp/secs" || {
    echo "loop-rate: could not read the run time of run $i" >&2
    exit 2
  }
done
median=$(sort -n "$tmp/secs" | awk '{ v[NR] = $1 } END { if (NR % 2) printf "%.3f\n", v[(NR + 1) / 2]; else printf "%.3f\n", (v[NR / 2] + v[NR / 2 + 1]) / 2 }')
echo "loop-rate: $red/$n red, median ${median}s"
