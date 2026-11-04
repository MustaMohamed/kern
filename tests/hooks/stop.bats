#!/usr/bin/env bats
# hooks/stop: self-review step 2's backstop (M3 part 2 project 1, paid round 1's goal 2; the user's "Fix it in
# project 1" and "Stop hook (Recommended)", 2026-11-04). In 3 of 3 runs of workflow-self-review-proofs the model
# read self-review, gave `fix first` from reading and ran no review-check. The hook blocks the stop once when the
# turn's last read of the running kern's self-review has no review-check run after it, and fails open on every
# fault (the turn and the running kern since the controller's rulings on round 2's fix review). Each row writes a
# small transcript in the shapes Claude Code writes: one JSON object per line, the user's prompt in a user entry,
# an assistant entry per tool_use block, the tool's result in a user entry.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  kern_env "$R"
  K="$(kern_root)"
  T="$BATS_TEST_TMPDIR/t.jsonl"
  : >"$T"
  N=0
  P=/plugins/kern
  # The running kern's own copy: kern_env points CLAUDE_PLUGIN_ROOT at K, and the hook runs from K.
  SR="$K/skills/self-review/SKILL.md"
}

# entry CONTENT: appends an assistant entry whose message.content is [CONTENT], keys in the order a Claude Code
# transcript writes them (message before type). CONTENT is one content block without its braces: bash 3.2
# brace-expands a literal {"a":1,"b":2} inside "$( )".
entry() {
  N=$((N + 1))
  printf '{"parentUuid":"p%s","isSidechain":false,"userType":"external","cwd":"%s","sessionId":"test-session","version":"2.1.318","message":{"id":"msg_%s","type":"message","role":"assistant","model":"claude-sonnet-5-5","content":[{%s}],"stop_reason":null,"usage":{"input_tokens":2,"output_tokens":3}},"requestId":"req_%s","type":"assistant","uuid":"u%s","timestamp":"2026-11-04T11:05:04.633Z"}\n' \
    "$N" "$CWD" "$N" "$1" "$N" "$N" >>"$T"
}

# use NAME INPUT: an assistant entry holding one tool_use block; INPUT is the input object's fields, JSON-escaped.
use() {
  entry "\"type\":\"tool_use\",\"id\":\"toolu_$((N + 1))\",\"name\":\"$1\",\"input\":{$2},\"caller\":{\"type\":\"direct\"}"
}
read_file() { use Read "\"file_path\":\"$1\""; }
sh_run() { use Bash "\"command\":\"$1\",\"description\":\"run\""; }
skill() { use Skill "\"skill\":\"$1\""; }
# say TEXT: an assistant text block.
say() { entry "\"type\":\"text\",\"text\":\"$1\""; }
# prompt TEXT: a user entry holding a typed prompt, as a transcript writes it (role before content).
prompt() {
  N=$((N + 1))
  printf '{"parentUuid":"u%s","isSidechain":false,"userType":"external","cwd":"%s","sessionId":"test-session","type":"user","message":{"role":"user","content":"%s"},"uuid":"q%s"}\n' \
    "$N" "$CWD" "$1" "$N" >>"$T"
}
# meta TEXT: a user entry Claude Code adds itself, as a skill's body after a Skill call (isMeta).
meta() {
  N=$((N + 1))
  printf '{"parentUuid":"u%s","isSidechain":false,"type":"user","message":{"role":"user","content":[{"type":"text","text":"%s"}]},"isMeta":true,"uuid":"m%s","sourceToolUseID":"toolu_%s"}\n' \
    "$N" "$1" "$N" "$N" >>"$T"
}
# result TEXT: the user entry holding the last tool_use's result, with the toolUseResult copy a transcript keeps.
result() {
  printf '{"parentUuid":"u%s","isSidechain":false,"type":"user","message":{"role":"user","content":[{"tool_use_id":"toolu_%s","type":"tool_result","content":"%s","is_error":false}]},"uuid":"r%s","toolUseResult":{"type":"text","file":{"filePath":"%s","content":"%s"}}}\n' \
    "$N" "$N" "$1" "$N" "$SR" "$1" >>"$T"
}

# stop [ACTIVE]: runs hooks/stop on a Stop input for the transcript, stop_hook_active ACTIVE (default false).
stop() {
  run bash "$K/hooks/stop" <<<"$(payload Stop "\"transcript_path\":\"$T\",\"permission_mode\":\"default\",\"stop_hook_active\":${1:-false}")"
}

# reason_of OUTPUT: the reason of OUTPUT as JSON.parse reads it, when OUTPUT is exactly {"decision":"block","reason":...}.
reason_of() {
  printf '%s' "$1" | node -e 'const o = JSON.parse(require("fs").readFileSync(0, "utf8"));
    if (o.decision !== "block" || Object.keys(o).join() !== "decision,reason") process.exit(3);
    process.stdout.write(o.reason)'
}

# blocks: the last stop exited 0 with the block object; sets reason.
blocks() {
  [ "$status" -eq 0 ] && reason=$(reason_of "$output") && [[ "$reason" == *'review-check <wt> <package> --spec <spec>'* ]] ||
    { echo "expected a block; status $status, output: $output"; return 1; }
}

# allows: the last stop exited 0 and printed nothing.
allows() {
  [ "$status" -eq 0 ] && [ -z "$output" ] || { echo "expected an allow; status $status, output: $output"; return 1; }
}

@test "blocks after a self-review Read with no review-check, as in round 1's three runs" {
  prompt 'Review the currency branch before the PR.'
  read_file "$SR"
  result '1\t---\n2\tname: self-review'
  read_file "$CWD/.kern/specs/currency.md"
  result '1\t---\n2\tstatus: approved'
  sh_run 'git diff main...HEAD --stat && git diff main...HEAD'
  result ' src/format.js | 3 +++'
  sh_run "for k in base_branch test.focused; do bash $P/scripts/kern-get \$k; done; npm test 2>&1 | tail -15"
  result 'exit 3'
  say '**Verdict: fix first.** I did not run review-check on a diff this small.'
  stop
  blocks
  [[ "$reason" == 'kern: self-review step 2 has not run since self-review was read.'* ]] || false
  [[ "$reason" == *'When a spec exists, write `<package>.proofs.md`'* ]] || false
  [[ "$reason" == *'(`--no-spec` with none)'* ]] || false
  [[ "$reason" == *'give the verdict from its `floor:` line.' ]] || false
  # unslop: no em dash and no en dash.
  [[ "$reason" != *"$(printf '\342\200\224')"* && "$reason" != *"$(printf '\342\200\223')"* ]] || false
}

@test "allows when review-check runs after the read" {
  read_file "$SR"
  result '1\t---'
  sh_run "R=\$(bash $P/scripts/kern-dir reviews); bash $P/scripts/review-check . \$R/feat-currency-1 --spec .kern/specs/currency.md"
  result 'floor: fix first'
  say 'Verdict: fix first.'
  stop
  allows
}

@test "a review-check run counts by path, through bash or sh, quoted or after cd, and a print of it does not" {
  local c
  for c in "$P/scripts/review-check . pkg --no-spec" "bash $P/scripts/review-check . pkg --no-spec" \
    "cd /w && sh -e $P/scripts/review-check . pkg --spec s.md" "bash \\\"\${CLAUDE_PLUGIN_ROOT}/scripts/review-check\\\" . pkg --no-spec" \
    "F=1 review-check . pkg --no-spec | tail -40" "out=\$(bash $P/scripts/review-check . pkg --no-spec)"; do
    : >"$T"
    read_file "$SR"
    sh_run "$c"
    stop
    allows || { echo "for: $c"; return 1; }
  done
  # The last one is JSON for `echo x\nreview-check` with a backslash and an n: one simple command, as the escaped
  # backslash decodes before the letter after it.
  for c in "cat $P/scripts/review-check" "grep -n floor $P/scripts/review-check" "echo review-check" "ls $P/scripts/review-check-old" \
    "echo x\\\\nreview-check . pkg --no-spec"; do
    : >"$T"
    read_file "$SR"
    sh_run "$c"
    stop
    blocks || { echo "for: $c"; return 1; }
  done
}

@test "allows a stop the hook already blocked (stop_hook_active true)" {
  read_file "$SR"
  stop true
  allows
}

@test "allows with no read of self-review, other reads of its folder and of other skills included" {
  stop
  allows
  read_file "$P/skills/self-review/references/proofs.md"
  read_file "$P/skills/review/SKILL.md"
  use Grep "\"pattern\":\"floor\",\"path\":\"$SR\""
  use Edit "\"file_path\":\"$SR\",\"old_string\":\"a\",\"new_string\":\"b\""
  sh_run "grep -n review-check $SR"
  skill 'kern:review'
  stop
  allows
}

@test "allows on a missing, unnamed or unreadable transcript" {
  read_file "$SR"
  run bash "$K/hooks/stop" <<<"$(payload Stop "\"transcript_path\":\"$BATS_TEST_TMPDIR/none.jsonl\",\"stop_hook_active\":false")"
  allows
  run bash "$K/hooks/stop" <<<"$(payload Stop '"stop_hook_active":false')"
  allows
  run bash "$K/hooks/stop" <<<"$(payload Stop "\"transcript_path\":\"$BATS_TEST_TMPDIR\",\"stop_hook_active\":false")"
  allows
  run bash "$K/hooks/stop" <<<"$(payload Stop '"transcript_path":7,"stop_hook_active":false')"
  allows
}

@test "allows on unparseable input" {
  local in
  read_file "$SR"
  for in in '' 'not json' "{\"transcript_path\":\"$T\"" "[\"transcript_path\",\"$T\"]" "{\"transcript_path\":\"$T\",\"stop_hook_active\":false"; do
    run bash "$K/hooks/stop" <<<"$in"
    allows || { echo "for: $in"; return 1; }
  done
}

@test "blocks when the only review-check came before the last read" {
  read_file "$SR"
  sh_run "bash $P/scripts/review-check . pkg --spec s.md"
  result 'floor: fix first'
  say 'Fixing the findings, then a second round.'
  read_file "$SR"
  stop
  blocks
}

@test "counts a Skill call naming self-review as a read" {
  local s
  for s in kern:self-review self-review; do
    : >"$T"
    skill "$s"
    stop
    blocks || { echo "for: $s"; return 1; }
  done
}

@test "counts a cat, sed or head of the file as a read, through CLAUDE_PLUGIN_ROOT or a path the call set" {
  local c
  for c in "cat $SR" "sed -n '1,60p' \\\"$SR\\\"" "head -80 $SR" "cd /w; cat -n $SR | head -40" \
    "cat \${CLAUDE_PLUGIN_ROOT}/skills/self-review/SKILL.md" "head -40 \\\"\$CLAUDE_PLUGIN_ROOT/skills/self-review/SKILL.md\\\"" \
    "K=$K; R=\$(bash \$K/scripts/kern-dir reviews); cat \$K/skills/self-review/SKILL.md" "S=\\\"$K/skills/\\\"; sed -n 1,9p \${S}/self-review/SKILL.md" "export K=$K && cat \$K/skills/self-review/SKILL.md"; do
    : >"$T"
    sh_run "$c"
    stop
    blocks || { echo "for: $c"; return 1; }
  done
}

@test "counts only the running kern's own copy: another checkout's, a relative path or an unknown variable allows" {
  local c
  for c in "cat /other/kern/skills/self-review/SKILL.md" "cat skills/self-review/SKILL.md" "head \$HOME/kern/skills/self-review/SKILL.md" \
    "K=/other/kern; cat \$K/skills/self-review/SKILL.md" "K=\$(pwd); cat \$K/skills/self-review/SKILL.md" "cat ${SR}.bak" \
    "S=$K/skills sed -n 1p \${S}/self-review/SKILL.md"; do
    : >"$T"
    sh_run "$c"
    stop
    allows || { echo "for: $c"; return 1; }
  done
  : >"$T"
  read_file /other/kern/skills/self-review/SKILL.md
  read_file "$CWD/skills/self-review/SKILL.md"
  stop
  allows
  # Each Bash call starts a fresh shell, so a path set in an earlier call names nothing.
  : >"$T"
  sh_run "K=$K"
  sh_run "cat \$K/skills/self-review/SKILL.md"
  stop
  allows
}

@test "the running kern's root counts as written and resolved, through a link and through CLAUDE_PLUGIN_ROOT" {
  local p
  ln -s "$K" "$BATS_TEST_TMPDIR/kern-link"
  for p in "$BATS_TEST_TMPDIR/kern-link/skills/self-review/SKILL.md" "$SR"; do
    : >"$T"
    read_file "$p"
    run env CLAUDE_PLUGIN_ROOT="$BATS_TEST_TMPDIR/kern-link" bash "$BATS_TEST_TMPDIR/kern-link/hooks/stop" \
      <<<"$(payload Stop "\"transcript_path\":\"$T\",\"stop_hook_active\":false")"
    blocks || { echo "for: $p"; return 1; }
  done
  # macOS spells a temporary folder with or without /private; both name one file.
  : >"$T"
  read_file /private/var/folders/kern-test/kern/skills/self-review/SKILL.md
  run env CLAUDE_PLUGIN_ROOT=/var/folders/kern-test/kern bash "$K/hooks/stop" <<<"$(payload Stop "\"transcript_path\":\"$T\",\"stop_hook_active\":false")"
  blocks
}

@test "counts only a read in the turn: a read before the last prompt allows, one after it blocks" {
  prompt 'Review the branch.'
  read_file "$SR"
  say 'Verdict: fix first.'
  prompt 'Thanks. Now rename the helper in src/format.js.'
  sh_run 'git diff --stat'
  stop
  allows
  read_file "$SR"
  stop
  blocks
  # A prompt whose content is a list of blocks starts a turn too.
  printf '{"parentUuid":"x","isSidechain":false,"type":"user","message":{"role":"user","content":[{"type":"text","text":"Next task."}]},"uuid":"q9"}\n' >>"$T"
  stop
  allows
}

@test "a meta entry, a prompt Claude Code wrapped itself and a tool result start no turn" {
  prompt 'Review the branch.'
  skill kern:self-review
  meta 'Base directory for this skill: /k. # self-review'
  sh_run 'npm test'
  result 'ok 2 - sum adds'
  prompt '<task-notification><task-id>b1</task-id><status>completed</status></task-notification>'
  printf '{"parentUuid":"x","isSidechain":false,"type":"user","message":{"role":"user","content":"This session is being continued from a previous conversation."},"isCompactSummary":true,"uuid":"c1"}\n' >>"$T"
  stop
  blocks
}

@test "a transcript with no self-review, or a turn with none, allows on a grep and never runs the scan" {
  local real
  real=$(command -v awk)
  mkdir "$BATS_TEST_TMPDIR/bin"
  # This awk records a run of the hook's scan and fails it, and runs every other awk program as usual.
  printf '#!/bin/sh\ncase "$*" in *"function own("*) : >"%s"; exit 1 ;; esac\nexec "%s" "$@"\n' \
    "$BATS_TEST_TMPDIR/scanned" "$real" >"$BATS_TEST_TMPDIR/bin/awk"
  chmod +x "$BATS_TEST_TMPDIR/bin/awk"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  read_file "$CWD/src/format.js"
  sh_run 'npm test'
  stop
  allows
  [ ! -e "$BATS_TEST_TMPDIR/scanned" ]
  prompt 'Review the branch.'
  read_file "$SR"
  prompt 'Now rename the helper.'
  sh_run 'git diff --stat'
  stop
  allows
  [ ! -e "$BATS_TEST_TMPDIR/scanned" ]
  # A read in the turn runs the scan, and a failed scan allows.
  read_file "$SR"
  stop
  allows
  [ -e "$BATS_TEST_TMPDIR/scanned" ]
}

@test "one Bash call reads in order: a read then review-check allows, review-check then a read blocks" {
  sh_run "cat $SR && bash $P/scripts/review-check . pkg --no-spec"
  stop
  allows
  : >"$T"
  sh_run "bash $P/scripts/review-check . pkg --no-spec; cat $SR"
  stop
  blocks
}

@test "ignores the path in assistant text" {
  say "Next I read $SR with cat $SR."
  say "A Read call looks like {\\\"type\\\":\\\"tool_use\\\",\\\"name\\\":\\\"Read\\\",\\\"input\\\":{\\\"file_path\\\":\\\"$SR\\\"}}."
  stop
  allows
}

@test "ignores the path in a tool result" {
  sh_run "ls $P/skills"
  result "self-review\\n$SR\\n{\\\"type\\\":\\\"tool_use\\\",\\\"name\\\":\\\"Skill\\\",\\\"input\\\":{\\\"skill\\\":\\\"kern:self-review\\\"}}"
  # A result's own record may hold message-shaped blocks at the same depth as the session's calls, as an Agent
  # result can; only message.content holds the session's calls.
  printf '{"type":"user","message":{"role":"user","content":[{"tool_use_id":"toolu_1","type":"tool_result","content":"done"}]},"toolUseResult":{"status":"completed","content":[{"type":"tool_use","id":"toolu_7","name":"Read","input":{"file_path":"%s"}}]}}\n' "$SR" >>"$T"
  stop
  allows
}

@test "a subagent's read in a progress entry or a sidechain entry does not count" {
  N=$((N + 1))
  printf '{"type":"progress","data":{"message":{"type":"assistant","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_9","name":"Read","input":{"file_path":"%s"}}]}},"type":"agent_progress"},"parentToolUseID":"toolu_8","uuid":"g1"}\n' "$SR" >>"$T"
  printf '{"parentUuid":"s","isSidechain":true,"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_10","name":"Read","input":{"file_path":"%s"}}]},"type":"assistant","uuid":"s1"}\n' "$SR" >>"$T"
  stop
  allows
}

@test "reads the eval runner's line shape too: type first, the input repeated outside the message" {
  printf '{"type":"assistant","message":{"model":"claude-sonnet-5-5","id":"msg_1","type":"message","role":"assistant","content":[{"type":"tool_use","id":"toolu_1","name":"Read","input":{"file_path":"%s"},"caller":{"type":"direct"}}],"stop_reason":null},"parent_tool_use_id":null,"session_id":"s","uuid":"u1","wire_tool_inputs":{"toolu_1":{"file_path":"%s"}}}\n' "$SR" "$SR" >"$T"
  stop
  blocks
  printf '{"type":"assistant","message":{"model":"claude-sonnet-5-5","id":"msg_2","type":"message","role":"assistant","content":[{"type":"tool_use","id":"toolu_2","name":"Bash","input":{"command":"bash %s/scripts/review-check . pkg --no-spec"},"caller":{"type":"direct"}}],"stop_reason":null},"parent_tool_use_id":null,"session_id":"s","uuid":"u2"}\n' "$P" >>"$T"
  stop
  allows
}

@test "allows under kern: off" {
  mkdir -p "$R/.claude"
  printf 'kern: off\n' >"$R/.claude/kern.local.yml"
  read_file "$SR"
  stop
  allows
}

@test "allows when its JSON library is missing" {
  mkdir -p "$BATS_TEST_TMPDIR/k"
  cp -R "$K/hooks" "$BATS_TEST_TMPDIR/k/hooks"
  rm "$BATS_TEST_TMPDIR/k/hooks/lib/json.sh"
  read_file "$SR"
  run bash "$BATS_TEST_TMPDIR/k/hooks/stop" <<<"$(payload Stop "\"transcript_path\":\"$T\",\"stop_hook_active\":false")"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a transcript over 6 MB finishes well under the 10 s timeout, read to its last call" {
  # A prompt, 2,000 results that quote the path and a tool_use, 2,000 Bash calls, one 1 MB Write full of escaped
  # quotes, an early review-check, then the last read of self-review: a block. Then a 1 MB Bash here-doc full of
  # escaped quotes whose last line runs review-check: an allow, as the command's value is built whole. Then a new
  # prompt: an allow from one grep of the turn, which names no self-review.
  awk -v sr="$SR" -v p="$P" -v cwd="$CWD" 'BEGIN {
    print "{\"parentUuid\":null,\"isSidechain\":false,\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":\"Review the branch.\"},\"uuid\":\"q0\"}"
    pad = "text \\\"quoted\\\" " sr " {\\\"type\\\":\\\"tool_use\\\",\\\"name\\\":\\\"Read\\\",\\\"input\\\":{\\\"file_path\\\":\\\"" sr "\\\"}} "
    while (length(pad) < 1300) pad = pad pad
    q = "a\\\"b"; while (length(q) < 1000000) q = q q
    head = "{\"parentUuid\":\"p\",\"isSidechain\":false,\"cwd\":\"" cwd "\",\"message\":{\"id\":\"m\",\"type\":\"message\",\"role\":\"assistant\",\"content\":[{\"type\":\"tool_use\",\"id\":\"t\",\"name\":"
    tail = "}],\"stop_reason\":null},\"type\":\"assistant\",\"uuid\":\"u\"}"
    print head "\"Bash\",\"input\":{\"command\":\"bash " p "/scripts/review-check . pkg --no-spec\"}" tail
    for (i = 1; i <= 2000; i++) {
      print head "\"Bash\",\"input\":{\"command\":\"npm test 2>&1 | tail -15; echo \\\"" i "\\\"\"}" tail
      print "{\"parentUuid\":\"u\",\"isSidechain\":false,\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":[{\"tool_use_id\":\"t\",\"type\":\"tool_result\",\"content\":\"" pad "\"}]},\"toolUseResult\":{\"stdout\":\"" pad "\"}}"
    }
    print head "\"Write\",\"input\":{\"file_path\":\"/w/big.json\",\"content\":\"" q "\"}" tail
    print head "\"Read\",\"input\":{\"file_path\":\"" sr "\"}" tail
    print head "\"Bash\",\"input\":{\"command\":\"cat > /w/big.json <<EOF\\n" q "\\nEOF\\nbash " p "/scripts/review-check . pkg --no-spec\"}" tail >"/dev/stderr"
  }' >"$T" 2>"$BATS_TEST_TMPDIR/heredoc.jsonl"
  [ "$(wc -c <"$T")" -gt 6000000 ]
  t0=$(perl -MTime::HiRes=time -e 'printf "%d", time * 1000')
  stop
  t1=$(perl -MTime::HiRes=time -e 'printf "%d", time * 1000')
  blocks
  echo "# stop took $((t1 - t0)) ms on $(wc -c <"$T") bytes, a block" >&3
  [ $((t1 - t0)) -lt 5000 ] || { echo "took $((t1 - t0)) ms"; return 1; }
  cat "$BATS_TEST_TMPDIR/heredoc.jsonl" >>"$T"
  t0=$(perl -MTime::HiRes=time -e 'printf "%d", time * 1000')
  stop
  t1=$(perl -MTime::HiRes=time -e 'printf "%d", time * 1000')
  allows
  echo "# stop took $((t1 - t0)) ms on $(wc -c <"$T") bytes, an allow" >&3
  [ $((t1 - t0)) -lt 5000 ] || { echo "took $((t1 - t0)) ms"; return 1; }
  prompt 'Now the changelog line.'
  t0=$(perl -MTime::HiRes=time -e 'printf "%d", time * 1000')
  stop
  t1=$(perl -MTime::HiRes=time -e 'printf "%d", time * 1000')
  allows
  echo "# stop took $((t1 - t0)) ms on $(wc -c <"$T") bytes after a new prompt, an allow" >&3
  [ $((t1 - t0)) -lt 2000 ] || { echo "took $((t1 - t0)) ms"; return 1; }
}
