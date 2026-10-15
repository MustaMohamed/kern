#!/usr/bin/env bash
# Find the test file that creates an unwanted file or directory, by running test files one at a time.
# Usage: find-polluter.sh POLLUTION_PATH TEST_GLOB -- TEST_CMD...    (each test file is appended to TEST_CMD)
# Example: find-polluter.sh .git 'src/**/*.test.ts' -- npx vitest run
# Prints `polluter: <file> creates <path>` and exits 1 at the first file that creates the path, leaving
# the path in place to inspect (remove it before another run). Prints `no polluter found among <n> test
# files` and exits 0 when none does. Exit 2: usage, no matching file, TEST_CMD not found, or POLLUTION_PATH
# already present. A failing test is not an error here; only the path matters.
# Adapted from superpowers systematic-debugging/find-polluter.sh (MIT); the test command is an argument.
set -euo pipefail
if [ $# -lt 4 ] || [ "$3" != "--" ]; then
  echo "usage: find-polluter.sh POLLUTION_PATH TEST_GLOB -- TEST_CMD..." >&2
  exit 2
fi
pollution=$1
pattern=${2#./}
shift 3
case "$pattern" in
  '' | /*) echo "find-polluter: TEST_GLOB must be a non-empty path relative to the current directory: $2" >&2; exit 2 ;;
esac
command -v "$1" > /dev/null 2>&1 || { echo "find-polluter: test command not found: $1" >&2; exit 2; }
# A * in find -path also matches /, so a glob with **/ needs a second form that drops it.
found=$(find . \( -path "./$pattern" -o -path "./${pattern//\*\*\//}" \) -type f) || {
  echo "find-polluter: find failed while listing $pattern" >&2
  exit 2
}
files=$(printf '%s\n' "$found" | LC_ALL=C sort -u | grep -v '^$' || true)
[ -n "$files" ] || { echo "find-polluter: no test files match $pattern" >&2; exit 2; }
# A path that exists before the first run would be blamed on the first file.
if [ -e "$pollution" ] || [ -L "$pollution" ]; then
  echo "find-polluter: $pollution already exists; remove it first" >&2
  exit 2
fi
total=$(printf '%s\n' "$files" | wc -l | tr -d ' ')
n=0
while IFS= read -r f; do
  f=${f%$'\r'}
  n=$((n + 1))
  echo "[$n/$total] $f"
  "$@" "$f" > /dev/null 2>&1 || true
  # The loop stops at the first file that creates the path, so the path is absent before every run.
  if [ -e "$pollution" ] || [ -L "$pollution" ]; then
    echo "polluter: $f creates $pollution"
    exit 1
  fi
done <<EOF
$files
EOF
echo "no polluter found among $total test files"
