#!/usr/bin/env bats
# Hooks run git with no fsmonitor program and no repo hooks (coverage gap 18).

load ../helpers/common

# The lines each hook runs right after `export KERN_ROOT`, comments aside.
HARDEN='case "${GIT_CONFIG_COUNT-}" in "" | *[!0-9]* | ??????????*) KERN_GC=0 ;; *) KERN_GC=$((10#$GIT_CONFIG_COUNT)) ;; esac
export GIT_CONFIG_COUNT=$((KERN_GC + 2)) "GIT_CONFIG_KEY_$KERN_GC=core.fsmonitor" "GIT_CONFIG_VALUE_$KERN_GC=false" \
  "GIT_CONFIG_KEY_$((KERN_GC + 1))=core.hooksPath" "GIT_CONFIG_VALUE_$((KERN_GC + 1))=/dev/null"'

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  K="$(kern_root)"
  M="$BATS_TEST_TMPDIR/fsmonitor-ran"
  printf '#!/bin/sh\ntouch "%s"\nexit 1\n' "$M" > "$BATS_TEST_TMPDIR/fsm.sh"
  chmod +x "$BATS_TEST_TMPDIR/fsm.sh"
  git -C "$R" config core.fsmonitor "$BATS_TEST_TMPDIR/fsm.sh"
  git -C "$R" update-index --fsmonitor 2>/dev/null || true
  mkdir -p "$R/.claude"
  # A loosening value makes the settings code list the index (git ls-files -s), which reads fsmonitor.
  printf 'push.policy: auto\n' > "$R/.claude/kern.local.yml"
  rm -f "$M"
}

@test "the fixture's fsmonitor program runs for a plain git call" {
  git -C "$R" ls-files -s >/dev/null
  [ -f "$M" ]
}

@test "session-start runs git without the repo's fsmonitor program" {
  run bash "$K/hooks/session-start" <<<"$(payload SessionStart '"source":"startup"')"
  [ "$status" -eq 0 ]
  [[ "$output" == *"push.policy=auto"* ]] || false
  [ ! -f "$M" ]
}

@test "every hook exports the hardened git config right after KERN_ROOT, before it runs git" {
  local h got
  for h in session-start subagent-start prompt-submit pre-tool-use; do
    got=$(awk '/^export KERN_ROOT$/ { on = 1; next } on && /^#/ { next } on && n < 3 { print; n++ }' "$K/hooks/$h")
    [ "$got" = "$HARDEN" ] || { echo "$h does not harden git right after KERN_ROOT"; return 1; }
  done
}

@test "every git a hook runs, its children's too, gets both pairs after the environment's own" {
  local L="$BATS_TEST_TMPDIR/git-calls" want
  git -C "$R" switch -q -c feat
  printf 'more\n' >>"$R/README.md"
  git -C "$R" -c core.fsmonitor=false add README.md
  # A git first on PATH that records the GIT_CONFIG_ variables of each call, then runs the real git.
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\nprintf "%%s :: %%s\\n" "$(env | grep "^GIT_CONFIG_" | LC_ALL=C sort | paste -sd " " -)" "$*" >>"%s"\nexec "%s" "$@"\n' \
    "$L" "$(command -v git)" >"$BATS_TEST_TMPDIR/bin/git"
  chmod +x "$BATS_TEST_TMPDIR/bin/git"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH" GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=kern.test GIT_CONFIG_VALUE_0=kept
  bash "$K/hooks/session-start" <<<"$(payload SessionStart '"source":"startup"')" >/dev/null
  bash "$K/hooks/subagent-start" <<<"$(payload SubagentStart '"agent_id":"a1","agent_type":"Explore"')" >/dev/null
  bash "$K/hooks/prompt-submit" <<<"$(payload UserPromptSubmit '"prompt":"hello"')" >/dev/null
  bash "$K/hooks/pre-tool-use" <<<"$(bash_payload "git commit -m 'add more'")" >/dev/null
  want="GIT_CONFIG_COUNT=3 GIT_CONFIG_KEY_0=kern.test GIT_CONFIG_KEY_1=core.fsmonitor GIT_CONFIG_KEY_2=core.hooksPath"
  want="$want GIT_CONFIG_VALUE_0=kept GIT_CONFIG_VALUE_1=false GIT_CONFIG_VALUE_2=/dev/null :: "
  # The calls cover the settings index read, G6's staged diff and kern-detect, a child of G5.
  grep -q ':: -C .* ls-files -s' "$L"
  grep -q ':: -C .* diff --cached' "$L"
  grep -q ':: -C .* log --no-show-signature --format=%s -30' "$L"
  run grep -v -F -e "$want" "$L"
  [ "$status" -eq 1 ] || { printf '%s\n' "$output"; return 1; }
}

@test "a GIT_CONFIG_COUNT of more than 9 digits counts as none, so pre-tool-use decides as usual" {
  local c base
  git -C "$R" switch -q -c feat
  printf 'more\n' >>"$R/README.md"
  git -C "$R" -c core.fsmonitor=false add README.md
  base=$(POSIXLY_CORRECT=1 bash "$K/hooks/pre-tool-use" <<<"$(bash_payload "git commit -m 'add more'")")
  [[ "$base" == *'"permissionDecision":"'* ]] || false
  # The first wraps in bash arithmetic; the second wraps the key index negative, which export rejects.
  for c in 99999999999999999999 9223372036854775807; do
    run env GIT_CONFIG_COUNT="$c" POSIXLY_CORRECT=1 bash "$K/hooks/pre-tool-use" <<<"$(bash_payload "git commit -m 'add more'")"
    [ "$status" -eq 0 ] && [ "$output" = "$base" ] || { echo "$c: status $status: $output"; return 1; }
  done
}
