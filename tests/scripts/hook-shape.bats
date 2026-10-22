#!/usr/bin/env bats
# tests/hook-shape.sh runs every hook over the fixture projects; here over one fixture, with stub hooks
# that record the environment they get.

setup() {
  K="$BATS_TEST_TMPDIR/k"
  mkdir -p "$K/tests/fixtures/projects/one" "$K/hooks"
  cp "$BATS_TEST_DIRNAME/../hook-shape.sh" "$K/tests/hook-shape.sh"
  printf '<empty>\n' >"$K/tests/fixtures/projects/one/expect.txt"
  printf 'x: 1\n' >"$K/tests/fixtures/projects/one/kern.local.yml"
  for h in session-start prompt-submit pre-tool-use; do
    printf '#!/usr/bin/env bash\ncat >/dev/null\nprintf "%%s %%s\\n" %s "${CLAUDE_CONFIG_DIR-unset}" >>"%s/seen"\n' "$h" "$K" >"$K/hooks/$h"
  done
  printf '#!/usr/bin/env bash\ncat >/dev/null\nprintf "{}"\n' >"$K/hooks/subagent-start"
}

# The bats helpers unset CLAUDE_CONFIG_DIR for the same reason: PreToolUse reads the shell snapshots under it.
@test "hook-shape runs the hooks with no CLAUDE_CONFIG_DIR from the caller" {
  mkdir "$BATS_TEST_TMPDIR/config"
  run env CLAUDE_CONFIG_DIR="$BATS_TEST_TMPDIR/config" bash "$K/tests/hook-shape.sh"
  [ "$status" -eq 0 ]
  [ "$output" = "hook-shape: 1 cases passed" ]
  [ "$(cat "$K/seen")" = "$(printf 'session-start unset\nprompt-submit unset\npre-tool-use unset')" ]
}
