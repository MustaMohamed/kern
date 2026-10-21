#!/usr/bin/env bats
# Homebrew bash 5.3.15 (macOS, measured 2026-10-21) segfaults now and then when a subshell undoes a locale
# change, and only while neither LANG nor LC_ALL is set (Task 16l). kern makes no such change anywhere a
# hook runs, and each entry hook exports LANG=C when neither is set, which leaves the locale as it was
# (Task 16m). The crash depends on the process's memory layout: one process either crashes on every try
# or on none, so each check runs many fresh processes. The caller's locale is unset in the test shell,
# not with env -u, whose effect on the crash rate was measured both ways.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  R=$(cd "$R" && pwd -P)
  kern_env "$R"
  K="$(kern_root)"
}

# The guard line every entry hook runs first.
GUARD='[ -n "${LANG-}${LC_ALL-}" ] || export LANG=C'

# first_command FILE: the first line of FILE that is neither blank nor a comment.
first_command() {
  grep -vE '^[[:space:]]*(#|$)' "$1" | head -n 1
}

@test "each entry hook runs the locale guard before anything else" {
  local h
  for h in session-start prompt-submit pre-tool-use subagent-start; do
    [ "$(first_command "$K/hooks/$h")" = "$GUARD" ] || { echo "$h starts with: $(first_command "$K/hooks/$h")"; return 1; }
  done
}

@test "the entry guard stops the bash 5.3 locale crash" {
  local b i=0 bad=0
  b=$(bash53) || skip "no bash 5.3 or later here"
  unset LANG LC_ALL LC_CTYPE
  # The crash's minimal shape after the first command of pre-tool-use: a `local LC_ALL=C` undone at
  # return, inside $( ) with a command after it.
  printf '%s\n' "$(first_command "$K/hooks/pre-tool-use")" 'f() { local LC_ALL=C; :; }' 'v=$(f; echo t)' '[ "$v" = t ]' \
    >"$BATS_TEST_TMPDIR/once.sh"
  while [ "$i" -lt 300 ]; do
    i=$((i + 1))
    "$b" "$BATS_TEST_TMPDIR/once.sh" 2>/dev/null || bad=$((bad + 1))
  done
  [ "$bad" -eq 0 ] || { echo "$b failed $bad of 300 runs"; return 1; }
}

@test "the entry guard sets LANG only when neither LANG nor LC_ALL is set, for git too" {
  local real h want got p
  real=$(command -v git)
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  printf '#!/bin/sh\nprintf "%%s %%s\\n" "${LANG-unset}" "${LC_ALL-unset}" >>"%s"\nexec "%s" "$@"\n' \
    "$BATS_TEST_TMPDIR/git.log" "$real" >"$BATS_TEST_TMPDIR/bin/git"
  chmod +x "$BATS_TEST_TMPDIR/bin/git"
  for h in session-start prompt-submit pre-tool-use subagent-start; do
    case "$h" in
      session-start) p=$(payload SessionStart '"source":"startup"') ;;
      prompt-submit) p=$(payload UserPromptSubmit '"prompt":"hello"') ;;
      pre-tool-use) p=$(bash_payload 'git push origin main') ;;
      subagent-start) p=$(payload SubagentStart '"agent_id":"a","agent_type":"Explore"') ;;
    esac
    for want in 'C unset' 'en_US.UTF-8 unset' 'unset en_US.UTF-8' 'C unset/LC_CTYPE'; do
      : >"$BATS_TEST_TMPDIR/git.log"
      (
        unset LANG LC_ALL LC_CTYPE
        case "$want" in
          en_US.UTF-8*) export LANG=en_US.UTF-8 ;;
          unset*) export LC_ALL=en_US.UTF-8 ;;
          */LC_CTYPE) export LC_CTYPE=UTF-8 ;;
        esac
        PATH="$BATS_TEST_TMPDIR/bin:$PATH" bash "$K/hooks/$h" <<<"$p" >/dev/null 2>&1
      )
      got=$(sort -u "$BATS_TEST_TMPDIR/git.log")
      [ "$got" = "${want%/LC_CTYPE}" ] || { echo "$h with $want: git saw '$got'"; return 1; }
    done
  done
}

@test "no hook site makes a locale change bash 5.3 must undo, without the entry guard" {
  local b i=0 bad=0 out first=""
  b=$(bash53) || skip "no bash 5.3 or later here"
  unset LANG LC_ALL LC_CTYPE
  printf -- '---\nstatus: draft\n---\n# hi\n' >"$R/spec.md"
  printf -- '---\nstatus: approved\n---\n' >"$R/held.md"
  printf 'v{VERSION} {ROOT}\n' >"$BATS_TEST_TMPDIR/tpl.md"
  printf 'secret\n' >"$R/s.txt"
  git -C "$R" add s.txt
  # Each former crash site, in the shape that crashed: a single command with a redirect inside $( ), a
  # function as a pipeline element, a function whose locale change is undone inside $( ). The libraries
  # and guards load as pre-tool-use loads them, but without the entry hook, so its guard is not in play.
  cat >"$BATS_TEST_TMPDIR/sites.sh" <<'EOS'
for l in json settings state decide render aliases gitctx; do . "$KERN_ROOT/hooks/lib/$l.sh" || exit 9; done
for g in "$KERN_ROOT"/hooks/guards/g*.sh; do . "$g" || exit 9; done
R=$1 AUTOPILOT=0 KERN_MAIN=$1 CWD=$1
bad=""
# site NAME GOT WANT: records NAME when GOT is not WANT. A pipeline's statuses end GOT as "rc=N".
site() { [ "$2" = "$3" ] || bad="$bad $1"; }
TOOL=Write TOOL_INPUT="{\"file_path\":\"$R/spec.md\",\"content\":\"---\\nstatus: draft\\n---\\n# x\\n\"}"
_KERN_VOTE=""; guard_g20; site g20-write "$_KERN_VOTE" ""
TOOL=Edit TOOL_INPUT="{\"file_path\":\"$R/spec.md\",\"old_string\":\"# hi\",\"new_string\":\"# ho\"}"
_KERN_VOTE=""; guard_g20; site g20-edit "$_KERN_VOTE" ""
site g20-holds "$(_g20_holds "$R/held.md"; echo "rc=$?")" rc=0
site g13-names "$(_g13_names 'ssh h'; echo "rc=$?")" rc=0
site json-escape "$(printf 'a"b' | json_escape; echo " rc=${PIPESTATUS[1]}")" 'a\"b rc=0'
site render "$(K_VERSION=1 K_ROOT=/r render_template "$2" | cat; echo "rc=${PIPESTATUS[0]}")" $'v1 /r\nrc=0'
site gh-opts "$(printf 'x\n' | _gh_opts 'web/w/b'; echo "rc=${PIPESTATUS[1]}")" $'@x\nrc=0'
site g06-parse "$(git -C "$R" diff --cached | _g06_parse | cat; echo "rc=${PIPESTATUS[1]}")" $'\035s.txt\ns.txt:1\t secret\nrc=0'
site g06-msgs "$(printf 'abc\001hi' | _g06_msgs | cat; echo "rc=${PIPESTATUS[1]}")" $'commit abc message:1\t hi\nrc=0'
site g06-keep "$(printf 'a:1\t x\n' | _g06_keep | cat; echo "rc=${PIPESTATUS[1]}")" rc=1
[ -z "$bad" ] || { echo "$bad"; exit 1; }
EOS
  while [ "$i" -lt 100 ]; do
    i=$((i + 1))
    out=$(KERN_ROOT="$K" "$b" "$BATS_TEST_TMPDIR/sites.sh" "$R" "$BATS_TEST_TMPDIR/tpl.md" 2>/dev/null) && continue
    bad=$((bad + 1))
    [ -n "$first" ] || first=$out
  done
  [ "$bad" -eq 0 ] || { echo "$b failed $bad of 100 runs, the first at:$first"; return 1; }
}

@test "G20 never fails closed on a .md Write or Edit under bash 5.3 with no locale" {
  local b i=0 bad=0 out w e p first=""
  b=$(bash53) || skip "no bash 5.3 or later here"
  unset LANG LC_ALL LC_CTYPE
  printf -- '---\nstatus: draft\n---\n# hi\n' >"$R/spec.md"
  w=$(tool_payload Write "\"file_path\":\"$R/spec.md\",\"content\":\"---\\nstatus: draft\\n---\\n# x\\n\"")
  e=$(tool_payload Edit "\"file_path\":\"$R/spec.md\",\"old_string\":\"# hi\",\"new_string\":\"# ho\"")
  # A draft written or edited gets no vote; G20 failing closed asks "G20 could not read ...".
  while [ "$i" -lt 100 ]; do
    i=$((i + 1))
    if [ $((i % 2)) = 0 ]; then p=$w; else p=$e; fi
    out=$(KERN_GUARDS=g20 "$b" "$K/hooks/pre-tool-use" <<<"$p" 2>&1) && [ -z "$out" ] && continue
    bad=$((bad + 1))
    [ -n "$first" ] || first=$out
  done
  [ "$bad" -eq 0 ] || { echo "$b: G20 voted or failed in $bad of 100 runs, first: $first"; return 1; }
}
