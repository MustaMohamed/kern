#!/usr/bin/env bats
# Homebrew bash 5.3.15 (macOS, measured 2026-10-21) segfaults now and then when a subshell undoes a locale
# change, and only while neither LANG nor LC_ALL is set (Task 16l). kern makes no such change anywhere a
# hook runs (Task 16m). The crash depends on the process's memory layout: one process either crashes on
# every try or on none, so each check runs many fresh processes. The caller's locale is unset in the test
# shell, not with env -u, whose effect on the crash rate was measured both ways.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  R=$(cd "$R" && pwd -P)
  kern_env "$R"
  K="$(kern_root)"
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
  while [ "$i" -lt 300 ]; do
    i=$((i + 1))
    out=$(KERN_ROOT="$K" "$b" "$BATS_TEST_TMPDIR/sites.sh" "$R" "$BATS_TEST_TMPDIR/tpl.md" 2>/dev/null) && continue
    bad=$((bad + 1))
    [ -n "$first" ] || first=$out
  done
  [ "$bad" -eq 0 ] || { echo "$b failed $bad of 300 runs, the first at:$first"; return 1; }
}

@test "G20 never fails closed on a .md Write or Edit under bash 5.3 with no locale" {
  local b i=0 bad=0 out w e p first=""
  b=$(bash53) || skip "no bash 5.3 or later here"
  unset LANG LC_ALL LC_CTYPE
  printf -- '---\nstatus: draft\n---\n# hi\n' >"$R/spec.md"
  w=$(tool_payload Write "\"file_path\":\"$R/spec.md\",\"content\":\"---\\nstatus: draft\\n---\\n# x\\n\"")
  e=$(tool_payload Edit "\"file_path\":\"$R/spec.md\",\"old_string\":\"# hi\",\"new_string\":\"# ho\"")
  # A draft written or edited gets no vote; G20 failing closed asks "G20 could not read ...".
  while [ "$i" -lt 300 ]; do
    i=$((i + 1))
    if [ $((i % 2)) = 0 ]; then p=$w; else p=$e; fi
    out=$(KERN_GUARDS=g20 "$b" "$K/hooks/pre-tool-use" <<<"$p" 2>&1) && [ -z "$out" ] && continue
    bad=$((bad + 1))
    [ -n "$first" ] || first=$out
  done
  [ "$bad" -eq 0 ] || { echo "$b: G20 voted or failed in $bad of 300 runs, first: $first"; return 1; }
}
