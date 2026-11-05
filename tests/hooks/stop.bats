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
  # Paid round 3's h2h review run 0 answered a block with a reply that only added review-check's output, and the
  # grader graded that last reply, so the reason asks for the whole report again (the user's "All three
  # (Recommended)", 2026-11-04).
  [[ "$reason" == *'(`--no-spec` with none) then give the whole report again, its verdict from the `floor:` line.' ]] || false
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

@test "a word of 1,024 bytes or more names no command: a 1,024-byte path to review-check is no run, a 1,023-byte one is" {
  local a w
  a=$(printf '%1010s' '' | tr ' ' a)
  # /, 1,010 letters and /review-check: 1,024 bytes (round 2's fix review, Minor 2: word() cut only above 1,024).
  w="/$a/review-check"
  [ "${#w}" -eq 1024 ]
  read_file "$SR"
  sh_run "$w . pkg --no-spec"
  stop
  blocks
  w="/${a#a}/review-check"
  [ "${#w}" -eq 1023 ]
  : >"$T"
  read_file "$SR"
  sh_run "$w . pkg --no-spec"
  stop
  allows
}

@test "a single-quoted path counts as written: a cat of self-review, a value the call set, a review-check run" {
  # Each arm of the quote strip that drops a single quote (round 2's fix review, Minor 4).
  local c
  for c in "cat '$SR'" "K='$K'; cat \$K/skills/self-review/SKILL.md"; do
    : >"$T"
    sh_run "$c"
    stop
    blocks || { echo "for: $c"; return 1; }
  done
  : >"$T"
  read_file "$SR"
  sh_run "bash '$P/scripts/review-check' . pkg --no-spec"
  stop
  allows
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
  # The last input passes json_ok, and a malformed string hides stop_hook_active, so json.sh reads it with exit 2
  # while transcript_path still reads (round 2's fix review, Minor 1).
  for in in '' 'not json' "{\"transcript_path\":\"$T\"" "[\"transcript_path\",\"$T\"]" "{\"transcript_path\":\"$T\",\"stop_hook_active\":false" \
    "{\"transcript_path\":\"$T\",\"q\":\"a\\\",\"stop_hook_active\":true}"; do
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

@test "an API request blob starts no turn: a read after the prompt, then a blob, then no review-check blocks" {
  # CLI 2.1.318 copies the messages of each API request into the transcript as api-request-blob lines. A user one
  # holds "role":"user","content": with a list that opens with a text block, or a string, and no isMeta flag (paid
  # round 3's triage), so a blob written between the read and the stop started the turn past the read and allowed.
  local b
  for b in '[{"type":"text","text":"<system-reminder>\nAs you answer, you can use the following context:\n</system-reminder>\n"},{"type":"text","text":"Review the branch."}]' \
    '"<system-reminder>\n[SYSTEM NOTIFICATION - NOT USER INPUT]\nThis is an automated background-task event.\n</system-reminder>"'; do
    : >"$T"
    prompt 'Review the branch.'
    read_file "$SR"
    result '1\t---\n2\tname: self-review'
    printf '{"type":"api-request-blob","sessionId":"test-session","hash":"b2f955116893f3540d5f55a21fcbb1486d4172b956a4e051a96ff5d4a96f0531","message":{"role":"user","content":%s}}\n' "$b" >>"$T"
    say 'Verdict: fix first.'
    stop
    blocks || { echo "for: $b"; return 1; }
  done
}

@test "the scan skips API request blobs: a review-check after the read, then a late blob that repeats the read, allows" {
  # An assistant blob copies a message's tool_use blocks at depth 4 under message.content, where the session's own
  # calls sit, so a blob written after a later call would read as a new read (the controller's ruling on the round 4
  # fix batch's concern 1).
  prompt 'Review the branch.'
  read_file "$SR"
  result '1\t---'
  sh_run "bash $P/scripts/review-check . pkg --no-spec"
  result 'floor: none'
  printf '{"type":"api-request-blob","sessionId":"test-session","hash":"3215d4a1aa39a7d63f95c2a0974d46e6ca61abb3abe0dc72afc570b17d594bca","message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_2","name":"Read","input":{"file_path":"%s"},"caller":{"type":"direct"}}]}}\n' "$SR" >>"$T"
  say 'Verdict: ready.'
  stop
  allows
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

# M3 part 2 project 2, Task 7: the Stop hook holds a go to ready, checks the size ask and nudges on request. The
# background launches and task notifications come from tests/fixtures/transcripts: synthetic lines in the shapes
# Claude Code 2.1.318 writes (a Bash call with run_in_background and its result's backgroundTaskId; an Agent call
# and its result's async_launched status; a task-notification as a user entry, a queue operation and a queued
# attachment), with invented text.

STATE() { printf '%s\n' "$CLAUDE_PLUGIN_DATA/sessions/test-session.state"; }
# repo_key: go_repo for this repository, as apply_go writes it.
repo_key() {
  printf '%s' "$(git -C "$R" worktree list --porcelain | sed -n '1s/^worktree //p')" | git -C "$R" hash-object --stdin
}
# go_on [PHASE]: autopilot on with a live go MA-254 for this repository, its go_phase PHASE (pr when left out).
go_on() {
  set_autopilot on
  printf 'go: MA-254\ngo_repo: %s\ngo_phase: %s\n' "$(repo_key)" "${1-pr}" >>"$(STATE)"
}
state_line() { printf '%s\n' "$1" >>"$(STATE)"; }
st() { sed -n "s/^$1: //p" "$(STATE)"; }
# go_prompt: the typed go, as Claude Code writes a slash command the user typed.
go_prompt() {
  N=$((N + 1))
  printf '{"parentUuid":null,"isSidechain":false,"type":"user","message":{"role":"user","content":"<command-message>kern:autopilot</command-message>\\n<command-name>/kern:autopilot</command-name>\\n<command-args>go MA-254</command-args>"},"uuid":"g%s"}\n' "$N" >>"$T"
}
# fixture NAME: appends tests/fixtures/transcripts/NAME.jsonl.
fixture() { cat "$K/tests/fixtures/transcripts/$1.jsonl" >>"$T"; }
# out TEXT: the result of the last tool_use, a Bash call whose stdout is TEXT (JSON-escaped), as a transcript keeps it.
out() {
  printf '{"parentUuid":"u%s","isSidechain":false,"type":"user","message":{"role":"user","content":[{"tool_use_id":"toolu_%s","type":"tool_result","content":"%s","is_error":false}]},"uuid":"o%s","toolUseResult":{"stdout":"%s","stderr":"","interrupted":false,"isImage":false,"noOutputExpected":false}}\n' \
    "$N" "$N" "$1" "$N" "$1" >>"$T"
}
# drafted: the go pushed its branch and opened its draft PR.
drafted() {
  sh_run 'git push -u origin ma-254'
  out ''
  sh_run 'gh pr create --draft --title MA-254 --body-file pr-body.md'
  out 'https://github.com/o/r/pull/12'
}
# held: the last stop exited 0 with a block object, whatever its reason; sets reason.
held() {
  [ "$status" -eq 0 ] && reason=$(reason_of "$output") || { echo "expected a block; status $status, output: $output"; return 1; }
}
nudge_on() {
  mkdir -p "$R/.claude"
  printf 'stop.nudge: on\n' >>"$R/.claude/kern.local.yml"
}
# bg_out ID: the result of the last tool_use, a Bash call Claude Code sent to the background as task ID.
bg_out() {
  printf '{"parentUuid":"u%s","isSidechain":false,"type":"user","message":{"role":"user","content":[{"tool_use_id":"toolu_%s","type":"tool_result","content":"Command running in background with ID: %s.","is_error":false}]},"uuid":"b%s","toolUseResult":{"stdout":"","stderr":"","interrupted":false,"isImage":false,"noOutputExpected":false,"backgroundTaskId":"%s"}}\n' \
    "$N" "$N" "$1" "$N" "$1" >>"$T"
}
# notice [TOOL_USE_ID]: a task-notification user entry, naming TOOL_USE_ID in <tool-use-id> when given (a Monitor's
# event can name none), after its queue operation.
notice() {
  local id=""
  [ -n "${1-}" ] && id="<tool-use-id>$1</tool-use-id>\\n"
  N=$((N + 1))
  printf '{"type":"queue-operation","operation":"enqueue","sessionId":"test-session","content":"<task-notification>\\n<task-id>t%s</task-id>\\n%s<status>completed</status>\\n</task-notification>"}\n' "$N" "$id" >>"$T"
  printf '{"parentUuid":"u%s","isSidechain":false,"type":"user","message":{"role":"user","content":"<task-notification>\\n<task-id>t%s</task-id>\\n%s<status>completed</status>\\n<event>line %s</event>\\n</task-notification>"},"uuid":"n%s","origin":{"kind":"task-notification"}}\n' \
    "$N" "$N" "$id" "$N" "$N" >>"$T"
}
# fail_with: puts grep, tail, wc and awk stubs first on PATH, which fail as KERN_T_FAIL says: turn or window, the
# hook's grep for the turn or the go's prompt; scan, its tail of the transcript; wc, its line count; state, a state
# read of the key KERN_T_KEY. Each runs the real tool otherwise.
fail_with() {
  local d="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$d"
  cat >"$d/grep" <<EOF
#!/bin/sh
case "\$KERN_T_FAIL:\$*" in turn:*'"content":("'* | window:*command-message*) exit 2 ;; esac
exec $(command -v grep) "\$@"
EOF
  cat >"$d/tail" <<EOF
#!/bin/sh
case "\$KERN_T_FAIL:\$1 \$2" in 'scan:-n +'*) exit 1 ;; esac
exec $(command -v tail) "\$@"
EOF
  cat >"$d/wc" <<EOF
#!/bin/sh
case "\$KERN_T_FAIL:\$*" in wc:-l) exit 0 ;; esac
exec $(command -v wc) "\$@"
EOF
  cat >"$d/awk" <<EOF
#!/bin/sh
case "\$KERN_T_FAIL:\$*" in "state:-v k=\$KERN_T_KEY "*) exit 2 ;; esac
exec $(command -v awk) "\$@"
EOF
  chmod +x "$d/grep" "$d/tail" "$d/wc" "$d/awk"
  export PATH="$d:$PATH"
}

@test "a go that quits before its draft is sent back" {
  go_on ''
  go_prompt
  sh_run 'npm test'
  out 'ok 1 - sum adds'
  say 'The change is built and its tests pass.'
  stop
  held
  [[ "$reason" == 'kern: this go has not reached its finish line: no draft PR is open yet. Do that next, or, when the run must stop here, end with the report, its first line `kern stop: <what>`.' ]] || false
  [ "$(st stop_backs)" = 1 ]
  [ "$(st stop_line)" = "$(wc -l <"$T" | tr -d ' ')" ]
  [[ "$reason" != *"$(printf '\342\200\224')"* && "$reason" != *"$(printf '\342\200\223')"* ]] || false
}

@test "a go whose last message reports a stop may end" {
  go_on ''
  go_prompt
  say 'kern stop: required check lint cannot run\nThe project names no lint command, and the ticket requires one.'
  stop
  allows
  [ "$(st stop_down)" = 1 ]
  [ -z "$(st stop_backs)" ]
}

@test "after a reported stop the finish line stays down" {
  go_on ''
  go_prompt
  say 'kern stop: required check lint cannot run'
  stop
  allows
  prompt 'What does the lint rule check?'
  say 'It checks that each hook file loads its libraries.'
  stop
  allows
  [ "$(st stop_down)" = 1 ]
  [ -z "$(st stop_backs)" ]
}

@test "a stop line counts past list, quote, emphasis and heading marks, as the grader reads it" {
  # Final review I2: scripts/lib/exec-grade.mjs's stopLines drops these marks before `kern stop: `, so a stop the
  # grader passes is one the hook lets end.
  local l
  for l in '**kern stop: class 2 red: deploy-preview**' '## kern stop: class 2 red: deploy-preview' \
    '1. kern stop: class 2 red: deploy-preview' '12) kern stop: class 2 red: deploy-preview' \
    '  > - _kern stop: merge_' '+ `kern stop: merge`' 'Report:\n### **kern stop: merge**'; do
    : >"$T"
    go_on ''
    go_prompt
    say "$l"
    stop
    allows || { echo "line: $l"; return 1; }
    [ "$(st stop_down)" = 1 ] || { echo "line: $l"; return 1; }
  done
  # A mark that is not one of those, a number with no blank after it, or a word before it is no stop line.
  for l in 'Step 2 kern stop: merge' '1.kern stop: merge' '(kern stop: merge)' '~~kern stop: merge~~'; do
    : >"$T"
    go_on ''
    go_prompt
    say "$l"
    stop
    held || { echo "line: $l"; return 1; }
    [[ "$reason" == *'no draft PR is open yet'* ]] || { echo "line: $l"; return 1; }
  done
}

@test "a go waiting on a background ci-wait may end" {
  go_on
  go_prompt
  drafted
  fixture background-bash
  say 'CI is running; I will read its verdict when it reports.'
  stop
  allows
  [ -z "$(st stop_backs)" ]
  # Once the wait reports, the finish line holds again: its next step is gh pr ready.
  fixture task-notification
  say 'CI reported.'
  stop
  held
  [[ "$reason" == *'`gh pr ready` has not marked the PR ready'* ]] || false
}

@test "a go waiting on a background subagent may end" {
  go_on ''
  go_prompt
  fixture async-agent
  say 'Task 2 runs in the background.'
  stop
  allows
  fixture task-notification-queued
  say 'Task 2 is in.'
  stop
  held
  [[ "$reason" == *'no draft PR is open yet'* ]] || false
}

@test "a go's prompt bounds its waits: a background task from before the go holds nothing open" {
  go_on ''
  prompt 'Start the dev server.'
  fixture background-bash
  say 'The server runs in the background.'
  go_prompt
  say 'Planning the change.'
  stop
  held
  [[ "$reason" == *'no draft PR is open yet'* ]] || false
}

@test "a red verdict with no push after it is named" {
  go_on
  go_prompt
  drafted
  sh_run "bash $P/scripts/ci-wait $R"
  out 'check: lint: fail\ncheck: test: pass\nci: red lint'
  say 'Lint is red.'
  stop
  held
  [[ "$reason" == *'`ci-wait` reported `ci: red lint` and no push came after it'* ]] || false
  # A push after the red moves the finish line to the next wait; a send-back under a go holds on stop_hook_active.
  sh_run 'git push origin ma-254'
  out ''
  say 'Pushed the lint fix.'
  stop true
  held
  [[ "$reason" == *'no `ci-wait` has run since the last push'* ]] || false
  # A verdict read from the wait's output file, through Read's line numbers, counts as well.
  sh_run "bash $P/scripts/ci-wait $R"
  out 'check: lint: pass\nci: clear'
  read_file /tmp/kern-test/tasks/bk3q9x2mz.output
  result '     1\tcheck: lint: fail\n     2\tci: red lint'
  stop true
  held
  [[ "$reason" == *'`ci: red lint`'* ]] || false
}

@test "the third send-back asks for the report; the fourth stop ends" {
  go_on ''
  go_prompt
  say 'Done.'
  stop
  held
  [[ "$reason" != *'stopped short'* ]] || false
  [ "$(st stop_backs)" = 1 ]
  stop true
  held
  [ "$(st stop_backs)" = 2 ]
  stop true
  held
  [[ "$reason" == *'This is the third send-back in a row: end with your report, saying the run stopped short.' ]] || false
  [ "$(st stop_backs)" = 3 ]
  stop true
  allows
  [ "$(st stop_backs)" = 0 ]
}

@test "a task notification resets the count" {
  go_on ''
  go_prompt
  fixture async-agent
  fixture task-notification-queued
  say 'Task 2 is in.'
  stop
  held
  [ "$(st stop_backs)" = 1 ]
  # The notification came before the last block, so the count goes on.
  stop true
  held
  [ "$(st stop_backs)" = 2 ]
  fixture background-bash
  fixture task-notification
  say 'CI reported.'
  stop true
  held
  [ "$(st stop_backs)" = 1 ]
  # Each wait starts the count again once: a later notice of the same wait does not.
  fixture task-notification
  stop true
  held
  [ "$(st stop_backs)" = 2 ]
}

@test "a go's report must name review-check's skip" {
  go_on
  state_line 'stop_down: 1'
  go_prompt
  sh_run "bash $P/scripts/review-check $R pkg --no-spec --autopilot"
  out 'check: verify.fast: skip (named)\ncheck: floor-scan: ok\nproofs: not checked (no spec)\nfloor: none'
  say 'Verdict: ready. Every check passed.'
  stop
  held
  [[ "$reason" == 'kern: review-check printed `check: verify.fast: skip (named)` this turn, and the report does not name that skip. Give the whole report again with a line that names each skipped check and the word skip.' ]] || false
  [ "$(st stop_backs)" = 1 ]
  # Naming the check without the word skip on its line is not enough.
  say 'Verdict: ready. verify.fast had nothing to run.'
  stop true
  held
  say 'Verdict: ready.\n- verify.fast: skip (named), no command resolves.'
  stop true
  allows
}

@test "a paraphrased size ask is sent back once" {
  local q='The change is now lines: 412 (git diff --shortstat), 398 with -w, in files: 5, over pr.max_lines: 300 (default). Reply split or one PR.'
  sh_run "bash $P/scripts/size-check $R pkg"
  out "size: over pr.max_lines: stop for execute-plan step 10's size decision before the next task\\nsize: ask: $q"
  say 'The change is 412 lines, over the 300 limit. Split it, or keep one PR?'
  stop
  held
  [[ "$reason" == "kern: size-check asked the size question this turn, and your last message does not carry it as printed. End with its question word for word: $q" ]] || false
  stop true
  allows
  : >"$T"
  sh_run "bash $P/scripts/size-check $R pkg"
  out "size: ask: $q"
  say "Step 10 stops here.\\n$q"
  stop
  allows
}

@test "an unproven edit nudges only when asked" {
  use Edit "\"file_path\":\"$R/README.md\",\"old_string\":\"readme\",\"new_string\":\"read me\""
  out 'The file has been updated.'
  say 'Updated the readme.'
  stop
  allows
  nudge_on
  stop
  held
  [[ "$reason" == 'kern: a file was edited after the last proving command of the turn. Run `test.focused` or `test.full` on the change, or `task-done`, `review-check` or `probe`, and report the result.' ]] || false
  # Outside a go a nudge blocks once and counts nothing.
  [ -z "$(st stop_backs)" ]
  stop true
  allows
  # A run of test.full or a kern proving script after the edit clears it; an edit in kern's work dir needs none.
  printf 'test.full: npm test\n' >>"$R/.claude/kern.local.yml"
  sh_run 'cd /w && npm test 2>&1 | tail -5'
  say 'Tests pass.'
  stop
  allows
  use Write "\"file_path\":\"$R/.kern/tmp/pr-body.md\",\"content\":\"Body.\""
  stop
  allows
  use Edit "\"file_path\":\"$R/README.md\",\"old_string\":\"read me\",\"new_string\":\"readme\""
  sh_run "bash $P/scripts/task-done $R"
  stop
  allows
}

# M3 part 2 project 2's paid round 1: under a go the unproven-edit send-back asked only for the result, and
# go-required-check-stop's last reply gave a probe's result alone, the final text the grader reads, so its report lost
# the `Test suite: fail` line. Under a go the reason ends as the skip reason does; outside one it is unchanged.
UNPROVEN='kern: a file was edited after the last proving command of the turn. Run `test.focused` or `test.full` on the change, or `task-done`, `review-check` or `probe`, and report the result.'

@test "under a go the unproven-edit reason asks for the whole report again" {
  go_on ''
  go_prompt
  use Edit "\"file_path\":\"$R/README.md\",\"old_string\":\"readme\",\"new_string\":\"read me\""
  out 'The file has been updated.'
  say 'kern stop: required check test.full cannot run\nTest suite: fail, cannot run.'
  stop
  held
  [ "$reason" = "$UNPROVEN Then give the whole report again." ]
  [ "$(st stop_backs)" = 1 ]
}

@test "outside a go the unproven-edit reason asks for no report" {
  nudge_on
  use Edit "\"file_path\":\"$R/README.md\",\"old_string\":\"readme\",\"new_string\":\"read me\""
  out 'The file has been updated.'
  say 'Updated the readme.'
  stop
  held
  [ "$reason" = "$UNPROVEN" ]
  # A go that reached ready owes its report outside the go, and the nudge there is the same.
  set_autopilot on
  state_line 'go_report: 1'
  stop
  held
  [ "$reason" = "$UNPROVEN" ]
}

@test "a lowered floor names its line or blocks" {
  printf "it('adds', () => {});\n" >"$R/sum.test.js"
  git -C "$R" add sum.test.js
  git -C "$R" commit -q -m 'add test'
  nudge_on
  printf "it.skip('adds', () => {});\n" >"$R/sum.test.js"
  use Edit "\"file_path\":\"$R/sum.test.js\",\"old_string\":\"it(\",\"new_string\":\"it.skip(\""
  sh_run "bash $P/scripts/task-done $R"
  say 'Done.'
  stop
  held
  [[ "$reason" == 'kern: floor-scan finds a lowered floor in this turn'"'"'s edits: `sum.test.js:1` (test-made-easier). Undo it, or name each `path:line` in your last message with the reason it stays.' ]] || false
  # A longer line number names another line.
  say 'sum.test.js:12 is another test.'
  stop
  held
  say 'sum.test.js:1 skips the adds test until its fixture lands.'
  stop
  allows
}

@test "no go, no nudge key, no self-review: no parse" {
  local real
  real=$(command -v awk)
  mkdir "$BATS_TEST_TMPDIR/bin"
  # This awk records a run of the hook's scan and fails it, and runs every other awk program as usual.
  printf '#!/bin/sh\ncase "$*" in *"function own("*) : >"%s"; exit 1 ;; esac\nexec "%s" "$@"\n' \
    "$BATS_TEST_TMPDIR/scanned" "$real" >"$BATS_TEST_TMPDIR/bin/awk"
  chmod +x "$BATS_TEST_TMPDIR/bin/awk"
  export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  prompt 'Rename the helper.'
  use Edit "\"file_path\":\"$R/README.md\",\"old_string\":\"readme\",\"new_string\":\"read me\""
  sh_run 'git push origin feat'
  say 'Renamed.'
  stop
  allows
  [ ! -e "$BATS_TEST_TMPDIR/scanned" ]
  # A go runs the scan.
  go_on ''
  stop
  allows
  [ -e "$BATS_TEST_TMPDIR/scanned" ]
}

@test "under a go, kern: off and a state the hook cannot write allow" {
  go_on ''
  go_prompt
  say 'Done.'
  mkdir -p "$R/.claude"
  printf 'kern: off\n' >"$R/.claude/kern.local.yml"
  stop
  allows
  [ -z "$(st stop_backs)" ]
  rm "$R/.claude/kern.local.yml"
  chmod a-w "$CLAUDE_PLUGIN_DATA/sessions"
  stop
  chmod u+w "$CLAUDE_PLUGIN_DATA/sessions"
  allows
  [ -z "$(st stop_backs)" ]
}

@test "outside a live go the finish line does not run" {
  # A go for another repository, then autopilot on with no go.
  set_autopilot on
  printf 'go: MA-254\ngo_repo: 0000000000000000000000000000000000000000\n' >>"$(STATE)"
  go_prompt
  say 'Done.'
  stop
  allows
  set_autopilot on
  stop
  allows
}

@test "stop checks every function each library it loads defines" {
  need_lists_match stop
}

@test "under a go the scan stays linear: a transcript over 6 MB finishes well under the 10 s timeout" {
  # The go's prompt, 2,000 Bash calls, each with a result full of escaped quotes and markers in mid-line, which
  # costs no parse, and every 20th with a ci-wait verdict at its start, which is parsed; 2,000 assistant text
  # blocks; a 1 MB Write full of escaped quotes; a push. A block names the missing ci-wait.
  go_on
  awk -v cwd="$CWD" 'BEGIN {
    print "{\"parentUuid\":null,\"isSidechain\":false,\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":\"<command-message>kern:autopilot</command-message>\\n<command-name>/kern:autopilot</command-name>\\n<command-args>go MA-254</command-args>\"},\"uuid\":\"q0\"}"
    pad = "text \\\"quoted\\\" ci: clear size: ask: x {\\\"type\\\":\\\"tool_use\\\",\\\"name\\\":\\\"Edit\\\"} "
    while (length(pad) < 1300) pad = pad pad
    q = "a\\\"b"; while (length(q) < 1000000) q = q q
    head = "{\"parentUuid\":\"p\",\"isSidechain\":false,\"cwd\":\"" cwd "\",\"message\":{\"id\":\"m\",\"type\":\"message\",\"role\":\"assistant\",\"content\":[{\"type\":\"tool_use\",\"id\":\"t\",\"name\":"
    tail = "}],\"stop_reason\":null},\"type\":\"assistant\",\"uuid\":\"u\"}"
    for (i = 1; i <= 2000; i++) {
      v = (i % 20) ? "" : "ci: pending lint (timeout 45m)\\n"
      print head "\"Bash\",\"input\":{\"command\":\"npm test 2>&1 | tail -15; echo \\\"" i "\\\"\"}" tail
      print "{\"parentUuid\":\"u\",\"isSidechain\":false,\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":[{\"tool_use_id\":\"t\",\"type\":\"tool_result\",\"content\":\"" v pad "\"}]},\"toolUseResult\":{\"stdout\":\"" v pad "\"}}"
      print "{\"parentUuid\":\"u\",\"isSidechain\":false,\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"" pad "\"}]},\"type\":\"assistant\"}"
    }
    print head "\"Write\",\"input\":{\"file_path\":\"/w/big.json\",\"content\":\"" q "\"}" tail
    print head "\"Bash\",\"input\":{\"command\":\"git push origin ma-254\"}" tail
  }' >"$T"
  [ "$(wc -c <"$T")" -gt 6000000 ]
  say 'Pushed.'
  t0=$(perl -MTime::HiRes=time -e 'printf "%d", time * 1000')
  stop
  t1=$(perl -MTime::HiRes=time -e 'printf "%d", time * 1000')
  held
  [[ "$reason" == *'no `ci-wait` has run since the last push'* ]] || false
  echo "# stop took $((t1 - t0)) ms on $(wc -c <"$T") bytes under a go, a block" >&3
  [ $((t1 - t0)) -lt 5000 ] || { echo "took $((t1 - t0)) ms"; return 1; }
}

# Task 7's fix round 1 (the review of 2026-11-05).

@test "notices of tasks that are no wait of the go never reset the count; the fourth stop still ends" {
  local dev mon
  go_on
  go_prompt
  drafted
  # A dev server in the background and a Monitor: neither is one of the go's waits.
  use Bash '"command":"npm run dev","run_in_background":true'
  bg_out bdev1
  dev="toolu_$N"
  use Monitor '"command":"tail -f app.log","description":"app log"'
  out 'Monitor started.'
  mon="toolu_$N"
  say 'Waiting on the server.'
  stop
  held
  [ "$(st stop_backs)" = 1 ]
  notice "$mon"
  notice
  notice "$dev"
  stop true
  held
  [ "$(st stop_backs)" = 2 ]
  notice "$mon"
  notice
  stop true
  held
  [[ "$reason" == *'saying the run stopped short.' ]] || false
  [ "$(st stop_backs)" = 3 ]
  notice "$mon"
  stop true
  allows
  [ "$(st stop_backs)" = 0 ]
}

@test "a background command that is no ci-wait holds nothing open" {
  go_on
  go_prompt
  drafted
  use Bash '"command":"sleep 3600","run_in_background":true'
  bg_out bslp1
  say 'Waiting on the background task.'
  stop
  held
  [[ "$reason" == *'no `ci-wait` has run since the last push'* ]] || false
  # A ci-wait in the foreground is no wait either: its verdict is in.
  sh_run "bash $P/scripts/ci-wait $R"
  out 'ci: clear'
  stop true
  held
  [[ "$reason" == *'`gh pr ready` has not marked the PR ready'* ]] || false
}

@test "a go waiting on CI is not asked for its report" {
  go_on
  go_prompt
  drafted
  sh_run "bash $P/scripts/review-check $R pkg --no-spec --autopilot"
  out 'check: verify.fast: skip (named)\nfloor: none'
  fixture background-bash
  say 'CI is running; the report comes with its verdict.'
  stop
  allows
  [ -z "$(st stop_backs)" ]
  fixture task-notification
  say 'Verdict: ready.'
  stop
  held
  [[ "$reason" == *'kern: review-check printed `check: verify.fast: skip (named)` this turn'* ]] || false
}

# owe_report: the state's go_report is 1, on one line, so st reads it alone.
owe_report() {
  sed '/^go_report: /d' "$(STATE)" >"$(STATE).new" && mv "$(STATE).new" "$(STATE)"
  state_line 'go_report: 1'
}
# ready_allowed: G2's allow of the go's `gh pr ready`, as g02-pr.sh writes it: the go ends, and its report is owed.
ready_allowed() {
  sh_run 'gh pr ready'
  out 'Pull request #12 is marked as ready for review'
  state_line 'go: '
  state_line 'go_phase: '
  owe_report
}

@test "a go that reached ready still owes its report: once, then the key empties" {
  # Final review I1: the ready allow ends the go, so the last stop is no go's; go_report keeps its report check.
  go_on
  go_prompt
  drafted
  sh_run "bash $P/scripts/review-check $R pkg --no-spec --autopilot"
  out 'check: verify.fast: skip (named)\nfloor: none'
  fixture background-bash
  say 'CI is running; the report comes with its verdict.'
  stop
  allows
  fixture task-notification
  ready_allowed
  say 'PR #12 is ready for review. Verdict: ready.'
  stop
  held
  [[ "$reason" == 'kern: review-check printed `check: verify.fast: skip (named)` this turn, and the report does not name that skip. Give the whole report again with a line that names each skipped check and the word skip.' ]] || false
  # The block writes go_report=2 since the round 7 fix batch, so the stop after it reads no report.
  [ "$(st go_report)" = 2 ]
  # Outside the go a send-back is not counted.
  [ -z "$(st stop_backs)" ]
  say 'PR #12 is ready for review.\n- verify.fast: skip (named), no command resolves.'
  stop
  allows
  [ -z "$(st go_report)" ]
  grep -q '^go_report: $' "$(STATE)"
  # With the key empty, the report is not read again.
  sh_run 'git status'
  out ''
  say 'Done.'
  stop
  allows
}

@test "a go's owed report: an open wait keeps the key, a stop the hook blocked empties it, and every fault allows" {
  go_on
  go_prompt
  drafted
  sh_run "bash $P/scripts/review-check $R pkg --no-spec --autopilot"
  out 'check: verify.fast: skip (named)\nfloor: none'
  ready_allowed
  # A wait still open: the report comes later, so the key stays for that stop.
  fixture background-bash
  say 'One more check runs.'
  stop
  allows
  [ "$(st go_report)" = 1 ]
  fixture task-notification
  say 'PR #12 is ready for review.'
  stop
  held
  [[ "$reason" == *'`check: verify.fast: skip (named)`'* ]] || false
  # The check is once: the stop after a block allows and empties the key.
  stop true
  allows
  [ -z "$(st go_report)" ]
  # kern: off allows and writes nothing; so does a read of go_report that fails.
  owe_report
  mkdir -p "$R/.claude"
  printf 'kern: off\n' >"$R/.claude/kern.local.yml"
  stop
  allows
  [ "$(st go_report)" = 1 ]
  rm "$R/.claude/kern.local.yml"
  fail_with
  export KERN_T_FAIL=state KERN_T_KEY=go_report
  stop
  allows
  [ "$(st go_report)" = 1 ]
  export KERN_T_FAIL=none
  stop
  held
  [[ "$reason" == *'`check: verify.fast: skip (named)`'* ]] || false
}

# The round 7 fix batch (M3 part 2 project 2; the user's "Both fixes, then round 8 (Recommended)", 2026-11-05): in paid
# round 7 go-proof-skip's two finish-line send-backs left stop_hook_active set when its `gh pr ready` ended the go, so
# the hook let that stop through and the reworded skip line in the owed report went unread. The owed report is read
# on such a stop too; its block writes go_report=2, and the stop after it allows and empties the key.

# report_key VALUE: the state's go_report is VALUE, on one line, so st reads it alone.
report_key() {
  sed '/^go_report: /d' "$(STATE)" >"$(STATE).new" && mv "$(STATE).new" "$(STATE)"
  state_line "go_report: $1"
}

@test "a go's owed report is read on a stop the hook already blocked, and blocks once" {
  go_on
  go_prompt
  drafted
  say 'The draft is open.'
  stop
  held
  [[ "$reason" == *'no `ci-wait` has run since the last push'* ]] || false
  [ "$(st stop_backs)" = 1 ]
  sh_run "bash $P/scripts/ci-wait $R"
  out 'ci: none'
  ready_allowed
  say 'PR #12 is ready for review.\nProof on the running app: skipped, since neither `verify.browser` nor `verify.app` is set.'
  stop true
  held
  [[ "$reason" == "$PROOF_REASON" ]] || false
  [ "$(st go_report)" = 2 ]
  # Outside the go the send-back is not counted, and the next stop allows and empties the key.
  [ "$(st stop_backs)" = 1 ]
  stop true
  allows
  [ -z "$(st go_report)" ]
  # A write of go_report=2 that fails allows, so the report is never read twice in a row.
  report_key 1
  chmod a-w "$CLAUDE_PLUGIN_DATA/sessions"
  stop true
  chmod u+w "$CLAUDE_PLUGIN_DATA/sessions"
  allows
  [ "$(st go_report)" = 1 ]
}

@test "a stop the hook already blocked, with no report owed, still allows" {
  go_on
  go_prompt
  drafted
  sh_run "bash $P/scripts/review-check $R pkg --no-spec --autopilot"
  out 'check: verify.fast: skip (named)\nfloor: none'
  ready_allowed
  say 'PR #12 is ready for review.\nProof on the running app: skipped, since neither `verify.browser` nor `verify.app` is set.'
  # The report was read, and blocked on once (go_report 2): this stop empties the key, stop_hook_active or not.
  report_key 2
  stop true
  allows
  [ -z "$(st go_report)" ]
  report_key 2
  stop
  allows
  [ -z "$(st go_report)" ]
  # Nothing owed: the report is not read.
  stop true
  allows
  stop
  allows
  [ -z "$(st go_report)" ]
}

# Check (7), the proof skip (M3 part 2 project 2's round 2 fix batch, the user's "Build the Stop hook check",
# 2026-11-05): go-proof-skip's report reworded prove-it's skip line in paid rounds 1 and 2, so a report that names
# the proof on the running app, with neither verify.browser nor verify.app set, must hold the line as printed.
SKIPLINE='skip: proof on the running app, no verify.browser or verify.app'
PROOF_REASON="kern: your report names the proof on the running app, and neither verify.browser nor verify.app is set, so it is prove-it's named skip. Give the whole report again with this line as printed: \`$SKIPLINE\`."
# Under a go the proof skip runs only until the run reports a stop, so its rows meet the finish line before the draft
# (fix round 1: with stop_down 1 the user is back, and a reply may answer a question, not report the go).
NO_DRAFT='kern: this go has not reached its finish line: no draft PR is open yet. Do that next, or, when the run must stop here, end with the report, its first line `kern stop: <what>`.'

@test "a go's report that names the proof on the running app, with neither setting, is sent back for the skip line" {
  local l
  # Round 2's report and PR body, round 1's go-no-lint-draft drift, and each word that names the proof alone.
  for l in 'Not run: I did not run the app on a screen; there is no `verify.browser` or `verify.app` configured.' \
    'Proof on the running app: skip, no `verify.browser` or `verify.app`.' \
    'skip: proof on the running app. The ticket needs none' \
    'No verify.app is set.' 'The running app was not checked.'; do
    : >"$T"
    go_on ''
    go_prompt
    say "Verdict: ready.\\n$l"
    stop
    held || { echo "line: $l"; return 1; }
    [[ "$reason" == "$NO_DRAFT $PROOF_REASON" ]] || { echo "line: $l"; return 1; }
    [ "$(st stop_backs)" = 1 ] || { echo "line: $l"; return 1; }
  done
  # It counts like the other checks: a second send-back is the second in a row.
  stop true
  held
  [[ "$reason" == "$NO_DRAFT $PROOF_REASON" ]] || false
  [ "$(st stop_backs)" = 2 ]
  # While a wait is open the run has not given its report.
  : >"$T"
  go_on
  go_prompt
  drafted
  fixture background-bash
  say 'CI is running; the proof on the running app is a skip.'
  stop
  allows
  [ -z "$(st stop_backs)" ]
}

@test "the report a go owes after ready is read for the skip line too, once and not counted" {
  go_on
  go_prompt
  drafted
  ready_allowed
  say 'PR #12 is ready for review.\nNot run: I did not run the app on a screen; there is no `verify.browser` or `verify.app` configured.'
  stop
  held
  [[ "$reason" == "$PROOF_REASON" ]] || false
  [ -z "$(st stop_backs)" ]
  [ "$(st go_report)" = 2 ]
  stop true
  allows
  [ -z "$(st go_report)" ]
}

@test "the skip line as printed passes, in a list or backticks too" {
  local l
  for l in "$SKIPLINE" "- \`$SKIPLINE\`" "Proof on the running app was not run.\\n$SKIPLINE"; do
    : >"$T"
    go_on ''
    go_prompt
    say "Verdict: ready.\\n$l"
    stop
    held || { echo "line: $l"; return 1; }
    [[ "$reason" == "$NO_DRAFT" ]] || { echo "line: $l"; return 1; }
  done
  # The owed report likewise.
  : >"$T"
  go_on
  go_prompt
  drafted
  ready_allowed
  say "PR #12 is ready for review.\\n$SKIPLINE"
  stop
  allows
  [ -z "$(st go_report)" ]
}

@test "a verify.browser or verify.app setting means no skip, so the report is not held to the line" {
  local k
  for k in 'verify.browser: npx playwright test' 'verify.app: npm run app:check'; do
    : >"$T"
    go_on ''
    mkdir -p "$R/.claude"
    printf '%s\n' "$k" >"$R/.claude/kern.local.yml"
    go_prompt
    say 'Verdict: ready.\nProof on the running app: the invoice screen renders the rounded total.'
    stop
    held || { echo "setting: $k"; return 1; }
    [[ "$reason" == "$NO_DRAFT" ]] || { echo "setting: $k"; return 1; }
  done
}

@test "after a go reports a stop, a reply that names the running app is not sent back for the skip line" {
  # Fix round 1 (the review's Important 1): the go stays live past its stop, and the user's next question is no report.
  go_on ''
  go_prompt
  say 'kern stop: the ticket requires proof on the running app, and neither verify.browser nor verify.app is set'
  stop
  allows
  [ "$(st stop_down)" = 1 ]
  prompt 'How do I set verify.browser?'
  say 'Add a verify.browser line to .claude/kern.local.yml with the command that drives the running app.'
  stop
  allows
  [ -z "$(st stop_backs)" ]
  # A stop the hook already blocked, and a stop_down written before this turn, allow alike.
  stop true
  allows
}

@test "a kern stop line exempts the proof skip: a required proof that cannot run is a stop" {
  go_on ''
  go_prompt
  say 'kern stop: the ticket requires proof on the running app, and neither verify.browser nor verify.app is set'
  stop
  allows
  [ "$(st stop_down)" = 1 ]
  [ -z "$(st stop_backs)" ]
  # With the finish line already down, the stop line still exempts it.
  say '- **kern stop: proof on the running app cannot run**'
  stop
  allows
  [ -z "$(st stop_backs)" ]
}

@test "outside a go the proof skip never fires" {
  local q='Reply split or one PR.'
  # A session the scan reads (size-check ran), with no go and no report owed.
  sh_run "bash $P/scripts/size-check $R pkg"
  out "size: ask: $q"
  say "The running app needs verify.browser, which is not set.\\n$q"
  stop
  allows
  # Autopilot on with no go, likewise.
  set_autopilot on
  stop
  allows
}

@test "a stop allowed with the count at 3 sets it back to 0, so the next failure blocks" {
  go_on ''
  state_line 'stop_backs: 3'
  go_prompt
  fixture async-agent
  say 'Task 2 runs in the background.'
  stop true
  allows
  [ "$(st stop_backs)" = 0 ]
  fixture task-notification-queued
  say 'Task 2 is in.'
  stop true
  held
  [ "$(st stop_backs)" = 1 ]
}

@test "a grep, a tail, a state read or a line count that fails allows" {
  local c
  fail_with
  go_on ''
  go_prompt
  say 'Done.'
  for c in turn window scan wc state:stop_down state:go_phase state:stop_backs state:stop_line; do
    export KERN_T_FAIL=${c%%:*} KERN_T_KEY=${c#*:}
    stop
    allows || { echo "fault $c"; return 1; }
    [ -z "$(st stop_backs)" ] || { echo "fault $c wrote stop_backs"; return 1; }
  done
  export KERN_T_FAIL=none
  stop
  held
  [ "$(st stop_backs)" = 1 ]
}

@test "the floor scan reads each edited file literally from its own repository, and leaves out one in none" {
  mkdir -p "$R/app/[id]" "$R/app/i" "$BATS_TEST_TMPDIR/loose" "$BATS_TEST_TMPDIR/gone"
  printf "it('a', () => {});\n" >"$R/app/[id]/page.test.js"
  printf "it('b', () => {});\n" >"$R/app/i/page.test.js"
  git -C "$R" add app
  git -C "$R" commit -q -m 'add tests'
  nudge_on
  printf "it.skip('a', () => {});\n" >"$R/app/[id]/page.test.js"
  printf "it.skip('b', () => {});\n" >"$R/app/i/page.test.js"
  use Edit "\"file_path\":\"$R/app/[id]/page.test.js\",\"old_string\":\"it(\",\"new_string\":\"it.skip(\""
  use Write "\"file_path\":\"$BATS_TEST_TMPDIR/loose/notes.md\",\"content\":\"x\""
  use Write "\"file_path\":\"$BATS_TEST_TMPDIR/gone/notes.md\",\"content\":\"x\""
  rmdir "$BATS_TEST_TMPDIR/gone"
  sh_run "bash $P/scripts/task-done $R"
  say 'Done.'
  stop
  held
  [[ "$reason" == 'kern: floor-scan finds a lowered floor in this turn'"'"'s edits: `app/[id]/page.test.js:1` (test-made-easier). Undo it,'* ]] || false
}

@test "a lowered floor names 20 hits, then how many more" {
  local i
  for i in $(seq 1 25); do printf "it('t%s', () => {});\n" "$i"; done >"$R/many.test.js"
  git -C "$R" add many.test.js
  git -C "$R" commit -q -m 'add tests'
  nudge_on
  sed 's/^it(/it.skip(/' "$R/many.test.js" >"$BATS_TEST_TMPDIR/many"
  cp "$BATS_TEST_TMPDIR/many" "$R/many.test.js"
  use Edit "\"file_path\":\"$R/many.test.js\",\"old_string\":\"it(\",\"new_string\":\"it.skip(\""
  sh_run "bash $P/scripts/task-done $R"
  say 'Done.'
  stop
  held
  [[ "$reason" == *'`many.test.js:20` (test-made-easier) and 5 more. Undo it,'* ]] || false
  [[ "$reason" != *'many.test.js:21'* ]] || false
}

@test "a call whose input opens with a task-notification is read as a call" {
  nudge_on
  use Write "\"file_path\":\"$R/notes.md\",\"content\":\"<task-notification>notes</task-notification>\""
  say 'Saved the notes.'
  stop
  held
  [[ "$reason" == 'kern: a file was edited after the last proving command of the turn.'* ]] || false
}

@test "an inherited KERN_MAIN does not stand for the input's cwd" {
  go_on ''
  go_prompt
  say 'Done.'
  mkdir -p "$BATS_TEST_TMPDIR/other"
  export KERN_MAIN="$BATS_TEST_TMPDIR/other"
  stop
  unset KERN_MAIN
  held
  [[ "$reason" == *'no draft PR is open yet'* ]] || false
}

@test "a verdict read with the arrow line numbers of a Read counts" {
  go_on
  go_prompt
  drafted
  fixture background-bash
  fixture task-notification
  fixture read-arrow
  say 'CI reported.'
  stop
  held
  [[ "$reason" == *'`ci-wait` reported `ci: red lint` and no push came after it'* ]] || false
  # The arrow as a JSON escape counts as well.
  sh_run "bash $P/scripts/ci-wait $R"
  out 'ci: clear'
  read_file /tmp/kern-test/tasks/bk3q9x2mz.output
  result '     1→ci: red lint'
  stop true
  held
  [[ "$reason" == *'`ci: red lint`'* ]] || false
}
