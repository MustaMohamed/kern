#!/usr/bin/env bash
# overwrite.sh KERN_DIR WORK: two cases where config pairs already in the environment matter to kern.
set -u
K="$1"
W="$2"
rm -rf "$W"
mkdir -p "$W/home/.claude" "$W/data"
export HOME="$W/home" CLAUDE_PLUGIN_DATA="$W/data" CLAUDE_PLUGIN_ROOT="$K"
unset CLAUDE_CODE_ENTRYPOINT GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS
mkrepo() {
  git init -q -b main "$1"
  git -C "$1" config user.name T
  git -C "$1" config user.email t@example.com
  git -C "$1" config commit.gpgsign false
  printf 'r\n' >"$1/README.md"
  git -C "$1" add README.md
  git -C "$1" commit -q -m init
  git init -q --bare -b main "$1.origin"
  git -C "$1" remote add origin "$1.origin"
  git -C "$1" push -q origin main
  git -C "$1" remote set-head origin main >/dev/null
}
payload() { printf '{"session_id":"t","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"%s"}}' "$1" "$2"; }

# Case A: the environment holds push.default=matching. `git push` then sends every branch the remote
# also has, so G6 must scan them all.
A="$W/a"
mkrepo "$A"
git -C "$A" switch -q -c other
git -C "$A" push -q origin other
printf 'key = AKIAABCDEFGHIJKLMNOP\n' >"$A/conf.txt"
git -C "$A" add conf.txt
git -C "$A" commit -q -m "other: conf"
git -C "$A" switch -q -c feat main
printf 'f\n' >"$A/f.txt"
git -C "$A" add f.txt
git -C "$A" commit -q -m feat
echo "A: what a real 'git push' with this environment sends:"
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=push.default GIT_CONFIG_VALUE_0=matching git -C "$A" push --dry-run 2>&1 | sed 's/^/   /'
echo "A: pre-tool-use on 'git push':"
GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=push.default GIT_CONFIG_VALUE_0=matching \
  bash "$K/hooks/pre-tool-use" <<<"$(payload "$A" "git push")" | sed 's/^/   /'

# Case B: the environment holds safe.directory=* (a container whose checkout another uid owns;
# GIT_TEST_ASSUME_DIFFERENT_OWNER stands in for that owner). The project kern.yml lists never_commit.
B="$W/b"
mkrepo "$B"
git -C "$B" switch -q -c feat
mkdir -p "$B/.claude"
printf 'never_commit: secret.txt\n' >"$B/.claude/kern.yml"
printf 's\n' >"$B/secret.txt"
git -C "$B" add secret.txt
echo "B: pre-tool-use on 'git commit -m x':"
GIT_TEST_ASSUME_DIFFERENT_OWNER=1 GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0='*' \
  bash "$K/hooks/pre-tool-use" <<<"$(payload "$B" "git commit -m x")" | sed 's/^/   /'
