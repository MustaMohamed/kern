#!/usr/bin/env bats
# Acceptance for the M1 parser deferral built in the M2b pilot: $(( )) is arithmetic, not a command.
# shellcheck disable=SC2016 # the commands under test hold a literal $

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  set_autopilot on
}

# gx CMD [GUARDS]: G00 (or GUARDS; "" runs them all) on CMD, as in g00-unproven.bats.
gx() { run_guard "$(bash_payload "$1")" "${2-g00}"; }
# g00_all DECISION CMD...: G00 decides DECISION on every CMD.
g00_all() {
  local want="$1" c
  shift
  for c in "$@"; do
    gx "$c"
    [ "$(decision_of "$output")" = "$want" ] || { echo "$c -> $output"; return 1; }
  done
}

@test "arithmetic is not a command: a substitution inside \$(( )) is read, the rest is not" {
  g00_all none 'echo $(( $(date +%s) - 5 ))' 't=$(date +%s); echo $(( $(date +%s) - t ))' 'x=$(( (3 + 4) * 2 ))' 'n=$(( $(wc -l < README.md) + 1 ))' 'echo $((1 + 2))'
  for c in 'echo $(( $(git push --force origin main) + 1 ))' 'echo $( (git push --force origin main) )'; do
    gx "$c" ""
    [ "$(decision_of "$output")" = deny ] || { echo "$c -> $output"; return 1; }
    [[ "$output" == *"kern G1: plain force push"* ]] || { echo "$c -> $output"; return 1; }
  done
}
