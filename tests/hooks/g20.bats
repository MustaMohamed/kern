#!/usr/bin/env bats
# G20: status: approved needs the user's own words from their last message.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  R=$(cd "$R" && pwd -P)
  kern_env "$R"
  K="$(kern_root)"
  mkdir -p "$R/.kern/specs" "$CLAUDE_PLUGIN_DATA/sessions"
  SPEC="$R/.kern/specs/export.md"
  printf '%s\n' '---' 'status: draft' 'date: 2026-10-14' 'approved: (set only on an explicit yes)' '---' '## Problem' > "$SPEC"
  touch -t 202001010000 "$SPEC"
}

# say PROMPT: the user's message, through the real prompt-submit hook. PROMPT holds no double quote.
say() {
  printf '{"session_id":"test-session","cwd":"%s","hook_event_name":"UserPromptSubmit","prompt":"%s"}' "$CWD" "$1" |
    bash "$K/hooks/prompt-submit" > /dev/null
}

# approve_payload QUOTE [PATH]: an Edit that sets status: approved and replaces the placeholder approved:
# line with one quoting QUOTE.
approve_payload() {
  tool_payload Edit "\"file_path\":\"${2:-$SPEC}\",\"old_string\":\"status: draft\\ndate: 2026-10-14\\napproved: (set only on an explicit yes)\",\"new_string\":\"status: approved\\ndate: 2026-10-14\\napproved: 2026-10-14, \\\"$1\\\"\""
}

# approve QUOTE [PATH]: G20's vote on that Edit.
approve() {
  run_guard "$(approve_payload "$1" "${2-}")" g20
}

GO='/kern:autopilot go MA-254'

# ticket LINE...: the draft with LINE... in its frontmatter, old as in setup.
ticket() {
  printf '%s\n' '---' "$@" 'status: draft' 'date: 2026-10-14' 'approved: (set only on an explicit yes)' '---' '## Problem' > "$SPEC"
  touch -t 202001010000 "$SPEC"
}

# approve_as FIELD: the go's Edit, from a call that carries the JSON field FIELD.
approve_as() {
  local p
  p=$(approve_payload "$GO")
  run_guard "{$1,${p#\{}" g20
}

# write_spec LINE...: a Write of a new spec whose frontmatter holds LINE..., JSON text.
write_spec() {
  local c='---' l
  for l in "$@"; do c="$c\\n$l"; done
  run_guard "$(tool_payload Write "\"file_path\":\"$R/.kern/specs/new.md\",\"content\":\"$c\\n---\\n## Problem\\n\"")" g20
}

# state_line LINE: appends LINE to the state; state_get reads the last line of a key.
state_line() {
  printf '%s\n' "$1" >> "$CLAUDE_PLUGIN_DATA/sessions/test-session.state"
}

# no_vote: G20 said nothing on the last call.
no_vote() {
  [ "$status" -eq 0 ] && [ -z "$output" ] || { echo "status $status: $output"; return 1; }
}

# deny_autopilot: the project denies autopilot, so a go refuses and a recorded one reads as off.
deny_autopilot() {
  mkdir -p "$R/.claude"
  printf 'autopilot: denied\n' > "$R/.claude/kern.local.yml"
}

# go_refused: the state holds autopilot off and no go.
go_refused() {
  local f="$CLAUDE_PLUGIN_DATA/sessions/test-session.state"
  grep -q '^autopilot: off$' "$f" || { cat "$f"; return 1; }
  [ -z "$(sed -n 's/^go: //p' "$f")" ] || { cat "$f"; return 1; }
}

# command_denied: G20 denied the last call's quote as a command.
command_denied() {
  [ "$(decision_of "$output")" = deny ] || { echo "$output"; return 1; }
  [[ "$output" == *'is a command, not an explicit yes'* ]] || { echo "$output"; return 1; }
}

# go_denied: G20 denied the last call as an approval under autopilot with no go for it.
go_denied() {
  [ "$(decision_of "$output")" = deny ] || { echo "$output"; return 1; }
  [[ "$output" == *'only a go approves, for its ticket'* ]] || { echo "$output"; return 1; }
}

@test "a quote of the user's last message approves" {
  say 'Yes, approved.'
  approve 'Yes, approved.'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a quote with other spacing and case still matches the same line" {
  say '  YES,   approved!  '
  approve 'yes, approved'
  [ -z "$output" ]
}

@test "one whole line of a longer message approves; part of a line does not" {
  say 'Looks right to me.\nYes, go with delegate.\nAlso rename the flag later.'
  approve 'Yes, go with delegate.'
  [ -z "$output" ]
  approve 'go with delegate'
  [ "$(decision_of "$output")" = deny ]
}

@test "an invented quote is denied" {
  say 'yes'
  approve 'ship it'
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"kern G20: the approved: quote is not a line of the user's last message"* ]] || false
}

@test "sounds good and whatever you think are not a yes" {
  say 'sounds good'
  approve 'sounds good'
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *'is not an explicit yes'* ]] || false
  say 'Whatever you think.'
  approve 'Whatever you think.'
  [ "$(decision_of "$output")" = deny ]
}

@test "a refusal, a hold or a question is not a yes, though it is a whole line of the user's message" {
  say "No, not yet.\nDon't approve it yet\nCan you change the title?\nsounds good"
  for q in 'No, not yet.' "Don't approve it yet" 'Can you change the title?' 'sounds good'; do
    approve "$q"
    [ "$(decision_of "$output")" = deny ] || { echo "quote: $q: $output"; return 1; }
    [[ "$output" == *'is not an explicit yes'* ]] || { echo "quote: $q: $output"; return 1; }
  done
}

@test "a yes that ends in a question mark is a question, not a yes" {
  # "Yes, go ahead?" holds yes and go ahead and no hold word, so only the final question mark denies it
  # (Opus audit F-G20b: no test pinned that rule). The same line without it approves.
  say 'Yes, go ahead?'
  approve 'Yes, go ahead?'
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *'"Yes, go ahead?\" is not an explicit yes (it needs a word such as yes, ok or go ahead, no word such as no, not, wait or later, and no final question mark)'* ]] || false
  say 'Yes, go ahead.'
  approve 'Yes, go ahead.'
  [ -z "$output" ]
}

@test "a line that holds an affirmative word and no negation approves" {
  say 'ok good, go\nyes, delegate'
  approve 'ok good, go'
  [ -z "$output" ]
  approve 'yes, delegate'
  [ -z "$output" ]
}

@test "a line with no affirmative word, or with a hold word, is not a yes" {
  say 'Change the title first.\nyes, but wait for the review\nGo ahead later\nlooks great'
  for q in 'Change the title first.' 'yes, but wait for the review' 'Go ahead later' 'looks great'; do
    approve "$q"
    [ "$(decision_of "$output")" = deny ] || { echo "quote: $q: $output"; return 1; }
    [[ "$output" == *'ask the user for an explicit yes, then quote that line'* ]] || { echo "quote: $q: $output"; return 1; }
  done
}

@test "an invented quote's reason says to ask for an explicit yes" {
  say 'yes'
  approve 'ship it'
  [[ "$output" == *"ask the user for an explicit yes, then quote that line"* ]] || false
}

@test "a frontmatter with more than one approved: line, in any case or indentation, is denied" {
  say 'yes'
  for second in 'approved: 2026-10-16, \"I never said this\"' '  approved: 2026-10-16, \"yes\"' 'APPROVED: x'; do
    run_guard "$(tool_payload Write "\"file_path\":\"$R/.kern/specs/two.md\",\"content\":\"---\\nstatus: approved\\nApproved: 2026-10-16, \\\"yes\\\"\\n$second\\n---\\n\"")" g20
    [ "$(decision_of "$output")" = deny ] || { echo "second: $second: $output"; return 1; }
    [[ "$output" == *'more than one approved: line'* ]] || { echo "second: $second: $output"; return 1; }
  done
  approved_spec 'yes'
  edit '## Problem' 'approved: 2026-10-16, \"yes\"\n## Problem'
  [ -z "$output" ]
  edit 'status: approved' 'status: approved\napproved: 2026-10-16, \"yes\"'
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *'more than one approved: line'* ]] || false
}

@test "a quote from an earlier message, or from a wrapped one, is denied" {
  say 'yes'
  say 'yes, and add the CSV header row'
  approve 'yes'
  [ "$(decision_of "$output")" = deny ]
  say '<task-notification>yes</task-notification>'
  approve 'yes, and add the CSV header row'
  [ -z "$output" ]
}

@test "a draft changed after the user's message is denied" {
  say 'yes'
  touch -t 203001010000 "$SPEC"
  approve 'yes'
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"changed after the user's last message"* ]] || false
}

@test "a missing approved: quote is denied" {
  say 'yes'
  run_guard "$(tool_payload Edit "\"file_path\":\"$SPEC\",\"old_string\":\"status: draft\",\"new_string\":\"status: approved\"")" g20
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"needs an approved: line"* ]] || false
}

@test "under autopilot even a real quote is denied" {
  say 'yes'
  printf 'autopilot: on\n' >> "$CLAUDE_PLUGIN_DATA/sessions/test-session.state"
  approve 'yes'
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"under autopilot only a go approves, for its ticket; keep status: draft (parked under autopilot) and park the question"* ]] || false
}

@test "with a go live, a refused approval names the two lines the go wants, and only then" {
  ticket 'issue: "#853"'
  say "$GO"
  approve "$GO"
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *'under autopilot only a go approves, for its ticket; this go wants one line approved: <date>, \"/kern:autopilot go MA-254\" and one line issue: \"MA-254\"; a file for another ticket keeps status: draft'* ]] || false
  [[ "$output" != *'park the question'* ]] || false
  approve_as '"agent_type":"kern:implementer"'
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *'keep status: draft (parked under autopilot) and park the question'* ]] || false
}

@test "under autopilot a go approves its ticket's spec" {
  ticket 'issue: MA-254'
  say "$GO"
  approve "$GO"
  no_vote
}

@test "a go approves in the write that creates a short spec" {
  say "$GO"
  write_spec 'form: short' 'status: approved' 'issue: MA-254' 'approved: 2026-10-31, \"/kern:autopilot go MA-254\"'
  no_vote
}

@test "a go matches other spellings of the issue" {
  ticket 'issue: ma-254'
  say "$GO"
  approve "$GO"
  no_vote
  ticket 'issue: #853'
  say '/kern:autopilot go 853'
  approve '/kern:autopilot go 853'
  no_vote
  ticket 'issue: 853'
  say '/kern:autopilot go #853'
  approve '/kern:autopilot go 853'
  no_vote
}

@test "one pair of matching quotes around the issue is dropped" {
  ticket 'issue: "#853"'
  say '/kern:autopilot go 853'
  approve '/kern:autopilot go 853'
  no_vote
  ticket 'issue: "MA-254"'
  say "$GO"
  approve "$GO"
  no_vote
  ticket "issue: 'ma-254'"
  approve "$GO"
  no_vote
}

@test "a quoted issue still names only its own ticket" {
  say "$GO"
  ticket 'issue: "MA-9"'
  approve "$GO"
  go_denied
  for l in 'issue: "MA-254' "issue: MA-254'" "issue: \"MA-254'" "issue: \"'MA-254'\"" 'issue: ""MA-254""' 'issue: ""'; do
    ticket "$l"
    approve "$GO"
    go_denied || { echo "line: $l"; return 1; }
  done
  ticket 'issue: "MA-254"' 'issue: "MA-9"'
  approve "$GO"
  go_denied
}

@test "a go does not approve another ticket" {
  ticket 'issue: MA-9'
  say "$GO"
  approve "$GO"
  go_denied
  approve '/kern:autopilot go MA-9'
  go_denied
}

@test "a spec with no ticket gets no approval" {
  say "$GO"
  ticket
  approve "$GO"
  go_denied
  for l in 'issue: none' 'issue: (tracker id, or none)' 'issue:'; do
    ticket "$l"
    approve "$GO"
    go_denied
  done
}

@test "only the frontmatter's one issue: line names the ticket" {
  say "$GO"
  ticket
  printf 'issue: MA-254\n' >> "$SPEC"
  touch -t 202001010000 "$SPEC"
  approve "$GO"
  go_denied
  ticket 'issue: MA-254' 'Issue: MA-9'
  approve "$GO"
  go_denied
  ticket 'issue: MA-9' 'issue: MA-254'
  approve "$GO"
  go_denied
}

@test "the quote must be the go line" {
  ticket 'issue: MA-254'
  say "$GO"
  for q in yes '/kern:autopilot go ma-254' '/kern:autopilot go MA-9' '/autopilot go MA-254' 'kern:autopilot go MA-254' \
    '/kern:autopilot go MA-254 now'; do
    approve "$q"
    go_denied || { echo "quote: $q"; return 1; }
  done
  run_guard "$(tool_payload Edit "\"file_path\":\"$SPEC\",\"old_string\":\"status: draft\",\"new_string\":\"status: approved\"")" g20
  go_denied
}

@test "a second approved: line takes the go's approval away" {
  say "$GO"
  write_spec 'status: approved' 'issue: MA-254' 'Approved: (old)' 'approved: 2026-10-31, \"/kern:autopilot go MA-254\"'
  go_denied
}

@test "a subagent cannot use the go" {
  ticket 'issue: MA-254'
  say "$GO"
  approve_as '"agent_type":"kern:implementer"'
  go_denied
  approve_as '"agent_id":"a1"'
  go_denied
  approve_as '"permission_mode":"default"'
  no_vote
}

@test "a go from another repository does not approve" {
  say "$GO"
  R2="$BATS_TEST_TMPDIR/other"
  make_repo "$R2"
  R2=$(cd "$R2" && pwd -P)
  CWD=$R2
  mkdir -p "$R2/.kern/specs"
  SPEC="$R2/.kern/specs/export.md"
  ticket 'issue: MA-254'
  approve "$GO"
  go_denied
}

@test "a replaced go no longer approves" {
  ticket 'issue: MA-1'
  say '/kern:autopilot go MA-1'
  say '/kern:autopilot go MA-2'
  approve '/kern:autopilot go MA-1'
  go_denied
}

@test "a draft written after the go still approves" {
  ticket 'issue: MA-254'
  say "$GO"
  touch -t 203001010000 "$SPEC"
  approve "$GO"
  no_vote
}

@test "under autopilot with no go nothing approves" {
  ticket 'issue: MA-254'
  say '/kern:autopilot on'
  approve "$GO"
  go_denied
}

@test "a cleared go or go_repo is no go" {
  ticket 'issue: MA-254'
  say "$GO"
  state_line 'go_repo: '
  approve "$GO"
  go_denied
  say "$GO"
  state_line 'go: '
  approve "$GO"
  go_denied
}

@test "a go past its draft approves nothing" {
  # M3 part 2 project 2, Task 2: G2 writes go_phase pr at the draft PR, and the go lives on through CI.
  ticket 'issue: MA-254'
  say "$GO"
  mkdir -p "$R/.kern/plans"
  plan="\"file_path\":\"$R/.kern/plans/export.md\",\"content\":\"---\\nstatus: approved\\nissue: MA-254\\napproved: 2026-11-05, \\\"$GO\\\"\\n---\\n## Goal\\n\""
  state_line 'go_phase: pr'
  run_guard "$(tool_payload Write "$plan")" g20
  go_denied
  [[ "$output" == *'only until its draft PR opens; the draft for MA-254 is open'* ]] || false
  approve "$GO"
  go_denied
  state_line 'go_phase: '
  approve "$GO"
  no_vote
}

@test "a new go clears go_phase" {
  ticket 'issue: "#8"'
  say "$GO"
  state_line 'go_phase: pr'
  say '/kern:autopilot go 8'
  [ "$(sed -n 's/^go_phase: //p' "$CLAUDE_PLUGIN_DATA/sessions/test-session.state")" = "" ]
  approve '/kern:autopilot go 8'
  no_vote
  state_line 'go_phase: pr'
  say '/kern:autopilot off'
  [ "$(sed -n 's/^go_phase: //p' "$CLAUDE_PLUGIN_DATA/sessions/test-session.state")" = "" ]
}

# M3 part 2 project 2, Task 8: under a go a plan approves only after plan step 11's review record holds
# Verdict: approve.

# write_plan [WORK]: the go's Write of a plan, WORK/plans/export.md (WORK .kern by default), approved in
# that first write.
write_plan() {
  run_guard "$(tool_payload Write "\"file_path\":\"$R/${1:-.kern}/plans/export.md\",\"content\":\"---\\nstatus: approved\\nissue: MA-254\\napproved: 2026-11-05, \\\"$GO\\\"\\nexecution: delegate\\n---\\n## Goal\\n\"")" g20
}

# review LINE...: the plan review's record for export.md under .kern, one line per LINE.
review() {
  mkdir -p "$R/.kern/reviews"
  printf '%s\n' "$@" > "$R/.kern/reviews/plan-export.md"
}

# review_denied [WORK]: G20 denied the last call for want of the plan's approving review, naming its record
# under WORK (.kern by default).
review_denied() {
  [ "$(decision_of "$output")" = deny ] || { echo "$output"; return 1; }
  [[ "$output" == *"kern G20: under a go a plan approves only after its review: "*"/${1:-.kern}/reviews/plan-export.md, where plan step 11 saves the plan reviewer's reply, needs a line Verdict: approve and no line Verdict: revise; keep status: draft"* ]] || { echo "$output"; return 1; }
}

# plan_untold: G20 failed closed on the last call, as it could not tell whether the file is a plan.
plan_untold() {
  [ "$(decision_of "$output")" = deny ] || { echo "$output"; return 1; }
  [[ "$output" == *"G20 could not tell whether export.md is a plan, which under a go approves only after its review"* ]] || { echo "$output"; return 1; }
}

@test "a go's plan approved in its first write is denied" {
  say "$GO"
  write_plan
  review_denied
  # Neither the plans folder nor the work dir need exist yet: the Write makes them.
  rm -rf "$R/.kern"
  write_plan
  review_denied
  # An Edit that approves a draft plan is judged the same way.
  mkdir -p "$R/.kern/plans"
  SPEC="$R/.kern/plans/export.md"
  ticket 'issue: MA-254'
  approve "$GO"
  review_denied
}

@test "a go's plan approved after an approving review passes" {
  say "$GO"
  review 'Verdict: approve' '' '2: the verify command names no file. name it.'
  write_plan
  no_vote
  mkdir -p "$R/.kern/plans"
  SPEC="$R/.kern/plans/export.md"
  ticket 'issue: MA-254'
  approve "$GO"
  no_vote
  # Blanks around the line, a CRLF line end among them, leave it the verdict.
  review '  Verdict: approve	'
  write_plan
  no_vote
  printf 'Verdict: approve\r\n' > "$R/.kern/reviews/plan-export.md"
  write_plan
  no_vote
}

@test "a revise verdict keeps the approval denied" {
  say "$GO"
  review 'Verdict: revise' '' '1: two tasks read the interface differently. pin one signature.'
  write_plan
  review_denied
}

@test "a record rewritten from revise to approve then allows" {
  # Task 8's pre-review change: plan step 11 saves a go's second review over the same record.
  say "$GO"
  review 'Verdict: revise' '' '1: two tasks read the interface differently. pin one signature.'
  write_plan
  review_denied
  review 'Verdict: approve'
  write_plan
  no_vote
}

@test "a record that also holds a revise line is no approve" {
  # Task 8 fix round 1: a revise line anywhere in the record outweighs an approve line.
  say "$GO"
  for order in approve revise; do
    if [ "$order" = approve ]; then review 'Verdict: approve' '  Verdict: revise'; else review 'Verdict: revise' 'Verdict: approve'; fi
    write_plan
    review_denied || { echo "first: $order"; return 1; }
  done
  # Text that only mentions a revise is no revise line.
  review 'Verdict: approve' '' 'An earlier draft got Verdict: revise.'
  write_plan
  no_vote
  # A failed read of the revise line stays no approve.
  read_fails grep '*Verdict: revise*'
  write_plan
  review_denied
  [ "$(read_failures grep)" -ge 1 ]
}

@test "a go fails closed when the work dir cannot be told" {
  # Task 8 fix round 1: a work_dir kern-dir refuses leaves G20 unable to tell a plan. A settings file that cannot be
  # read reads as autopilot denied, so a go never meets one; the lost-pipe row covers a failed settings read.
  mkdir -p "$R/.claude"
  printf 'work_dir: ../out\n' > "$R/.claude/kern.local.yml"
  say "$GO"
  write_plan
  plan_untold
}

@test "a . or .. part after a directory that does not exist yet fails closed" {
  # Task 8 fix round 1: the Write resolves new/../export.md to plans/export.md, which a string compare reads as
  # nested.
  say "$GO"
  local p
  for p in plans/new/../export.md new/../plans/export.md plans/./export.md plans//export.md; do
    rm -rf "$R/.kern/plans" "$R/.kern/new"
    run_guard "$(tool_payload Write "\"file_path\":\"$R/.kern/$p\",\"content\":\"---\\nstatus: approved\\nissue: MA-254\\napproved: 2026-11-05, \\\"$GO\\\"\\n---\\n\"")" g20
    plan_untold || { echo "path: $p"; return 1; }
  done
  # Through directories that exist, cd -P resolves the parts, so the plan is seen as one.
  mkdir -p "$R/.kern/plans/new"
  run_guard "$(tool_payload Write "\"file_path\":\"$R/.kern/plans/new/../export.md\",\"content\":\"---\\nstatus: approved\\nissue: MA-254\\napproved: 2026-11-05, \\\"$GO\\\"\\n---\\n\"")" g20
  review_denied
}

@test "a go's plan is not approved when a substitution's pipe fails" {
  # Task 8 fix round 1: a substitution whose pipe cannot be made gives status 0 and no output, which must not read
  # as "no plan". work_dir is .work, so a settings read that fell back to the .kern default would miss the plan.
  # Each substitution _g20_reviewed starts fails in turn, for the plan and for a link to it, with no record.
  local n f p
  for f in json settings state decide; do . "$K/hooks/lib/$f.sh"; done
  . "$K/hooks/guards/g20-approval.sh"
  mkdir -p "$R/.claude" "$R/.work/plans"
  printf 'work_dir: .work\n' > "$R/.claude/kern.local.yml"
  ln -s .work/plans/export.md "$R/docs-link.md"
  SID=test-session
  KERN_MAIN=$(kern_main_root "$R")
  for p in "$R/.work/plans/export.md" "$R/docs-link.md"; do
    _KERN_VOTE=''
    _g20_reviewed "$p"
    [ "$_KERN_VOTE" = deny ] || { echo "no deny for $p"; return 1; }
    _KERN_VOTE=''
    n=1
    while [ "$n" -le 80 ]; do
      if (pipe_fails "$n" _g20_reviewed "$p"; [ -z "$_KERN_VOTE" ]) 2>/dev/null; then
        echo "no vote for $p when substitution $n failed"
        return 1
      fi
      [ -e "$BATS_TEST_TMPDIR/pipe-failed" ] || break
      n=$((n + 1))
    done
    [ "$n" -gt 3 ] && [ "$n" -le 80 ] || { echo "$p: stopped at $n"; return 1; }
  done
}

@test "only a whole line Verdict: approve is an approving review" {
  say "$GO"
  for l in 'Verdict: approve | revise' 'verdict: approve' 'Verdict: approved' 'Verdict:  approve' '**Verdict: approve**' \
    'Verdict: approve, once task 2 names its file' 'The reviewer gave no Verdict: approve'; do
    review "$l"
    write_plan
    review_denied || { echo "line: $l"; return 1; }
  done
  # A record that is no regular file is no approve.
  rm -f "$R/.kern/reviews/plan-export.md"
  mkdir "$R/.kern/reviews/plan-export.md"
  write_plan
  review_denied
}

@test "a review record that cannot be read is no approve" {
  say "$GO"
  review 'Verdict: approve'
  read_fails grep '*plan-export.md'
  write_plan
  review_denied
  [ "$(read_failures grep)" -ge 1 ]
  read_fails grep '*plan-export.md' 0
  chmod 000 "$R/.kern/reviews/plan-export.md"
  write_plan
  chmod 644 "$R/.kern/reviews/plan-export.md"
  review_denied
  write_plan
  no_vote
}

@test "a person's approval is unchanged" {
  mkdir -p "$R/.kern/plans"
  SPEC="$R/.kern/plans/export.md"
  ticket
  say 'Yes, go with delegate.'
  approve 'Yes, go with delegate.'
  no_vote
  review 'Verdict: revise'
  approve 'Yes, go with delegate.'
  no_vote
  approve 'ship it'
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"kern G20: the approved: quote is not a line of the user's last message"* ]] || false
}

@test "the review record is read from the work dir the settings name" {
  mkdir -p "$R/.claude"
  printf 'work_dir: .work\n' > "$R/.claude/kern.local.yml"
  say "$GO"
  review 'Verdict: approve'
  write_plan .work
  review_denied .work
  mkdir -p "$R/.work/reviews"
  printf 'Verdict: approve\n' > "$R/.work/reviews/plan-export.md"
  write_plan .work
  no_vote
}

@test "a write through a link into the plans folder is a plan's" {
  say "$GO"
  mkdir -p "$R/.kern/plans"
  printf '%s\n' '---' 'status: draft' '---' > "$R/.kern/plans/export.md"
  ln -s .kern/plans/export.md "$R/docs-link.md"
  run_guard "$(tool_payload Write "\"file_path\":\"$R/docs-link.md\",\"content\":\"---\\nstatus: approved\\nissue: MA-254\\napproved: 2026-11-05, \\\"$GO\\\"\\n---\\n\"")" g20
  review_denied
}

@test "a failed read is no go" {
  ticket 'issue: MA-254'
  say "$GO"
  read_fails awk 'k=go'
  approve "$GO"
  go_denied
  [ "$(read_failures awk)" -ge 1 ]
  read_fails awk 'k=go' 0
  read_fails awk 'k=go_repo'
  approve "$GO"
  go_denied
  [ "$(read_failures awk)" -ge 2 ]
  read_fails awk 'k=go_repo' 0
  read_fails git '*hash-object*'
  approve "$GO"
  go_denied
  [ "$(read_failures git)" -ge 1 ]
  read_fails git '*hash-object*' 0
  # M3 part 2 project 2, Task 2's fix round 1: a go_phase read that fails is no go either.
  read_fails awk 'k=go_phase'
  approve "$GO"
  go_denied
  [ "$(read_failures awk)" -ge 3 ]
  read_fails awk 'k=go_phase' 0
  read_fails awk '*toupper*'
  approve "$GO"
  go_denied
  [ "$(read_failures awk)" -ge 4 ]
  read_fails awk '*toupper*' 0
  approve "$GO"
  no_vote
}

@test "a go past its draft approves nothing when a substitution's pipe fails" {
  # Task 2's fix round 1: a substitution whose pipe cannot be made gives status 0 and no output, which must
  # not read as an empty go_phase. The go_phase read fails by its text, since by count an earlier read's
  # own subshell reaches each index first; then each substitution _g20_go starts fails in turn.
  local n=1 f after
  for f in json settings state decide; do . "$K/hooks/lib/$f.sh"; done
  . "$K/hooks/guards/g20-approval.sh"
  say "$GO"
  SID=test-session
  KERN_MAIN=$(kern_main_root "$R")
  after=$(printf '%s\n' 'status: approved' 'issue: MA-254' "approved: 2026-11-05, \"$GO\"")
  _g20_go "$after"
  state_line 'go_phase: pr'
  _g20_go "$after" || true
  [ "$_G20_PAST" = MA-254 ]
  if (pipe_fails go_phase _g20_go "$after") 2>/dev/null; then
    echo "approved when the go_phase read's pipe failed"
    return 1
  fi
  [ -e "$BATS_TEST_TMPDIR/pipe-failed" ]
  while [ "$n" -le 40 ]; do
    if (pipe_fails "$n" _g20_go "$after") 2>/dev/null; then
      echo "approved when substitution $n failed"
      return 1
    fi
    [ -e "$BATS_TEST_TMPDIR/pipe-failed" ] || break
    n=$((n + 1))
  done
  [ "$n" -gt 5 ] && [ "$n" -le 40 ]
}

@test "a go refused by a denied project is not a yes" {
  ticket 'issue: MA-254'
  deny_autopilot
  say "$GO"
  go_refused
  approve "$GO"
  command_denied
}

@test "a go refused for a skill conflict is not a yes" {
  ticket 'issue: MA-254'
  mkdir -p "$R/.claude/skills/commit"
  printf 'x\n' > "$R/.claude/skills/commit/SKILL.md"
  say "$GO"
  go_refused
  approve "$GO"
  command_denied
}

@test "a go line on another ticket's spec is not a yes with autopilot off" {
  ticket 'issue: MA-9'
  deny_autopilot
  say '/kern:autopilot go MA-1'
  go_refused
  approve '/kern:autopilot go MA-1'
  command_denied
}

@test "a recorded go whose project then denies autopilot is not a yes" {
  ticket 'issue: MA-254'
  say "$GO"
  deny_autopilot
  approve "$GO"
  command_denied
}

@test "a go line pasted into a longer message is not a yes" {
  ticket 'issue: MA-254'
  say "Please run this\n$GO"
  go_refused
  approve "$GO"
  command_denied
}

@test "a quote's case and blanks do not hide an autopilot command" {
  ticket 'issue: MA-254'
  deny_autopilot
  say "$GO"
  for q in ' /kern:autopilot go MA-254' '/KERN:AUTOPILOT GO MA-254' '  /Kern:Autopilot   go ma-254'; do
    approve "$q"
    command_denied || { echo "quote: [$q]"; return 1; }
  done
  say '/autopilot go MA-254'
  for q in '/autopilot go MA-254' ' /AUTOPILOT go MA-254'; do
    approve "$q"
    command_denied || { echo "quote: [$q]"; return 1; }
  done
}

@test "an autopilot line is not a yes, whatever follows" {
  ticket 'issue: MA-254'
  for q in '/kern:autopilot ok' '/autopilot yes' '/kern:autopilot go ahead'; do
    say "$q"
    go_refused
    approve "$q"
    command_denied || { echo "quote: [$q]"; return 1; }
  done
}

@test "the one-line command envelope of a go is not a yes" {
  ticket 'issue: MA-254'
  E='<command-name>/kern:autopilot</command-name><command-args>go MA-254</command-args>'
  say "$E"
  go_refused
  approve "$E"
  command_denied
  deny_autopilot
  say "$E"
  go_refused
  approve "$E"
  command_denied
}

@test "no line of the three-line command envelope of a go is a yes" {
  ticket 'issue: MA-254'
  E='<command-message>kern:autopilot</command-message>\n<command-name>/kern:autopilot</command-name>\n<command-args>go MA-254</command-args>'
  for setting in allowed denied; do
    [ "$setting" = allowed ] || deny_autopilot
    say "$E"
    go_refused
    for q in '<command-args>go MA-254</command-args>' ' <COMMAND-ARGS>go ma-254</COMMAND-ARGS>' \
      '<command-name>/kern:autopilot</command-name>' '<command-message>kern:autopilot</command-message>'; do
      approve "$q"
      command_denied || { echo "$setting: quote: [$q]"; return 1; }
    done
  done
}

@test "a yes that only names the command still approves" {
  ticket 'issue: MA-254'
  say 'Yes, then run /kern:autopilot go MA-1'
  approve 'Yes, then run /kern:autopilot go MA-1'
  no_vote
}

@test "a shell write of the go quote stays denied" {
  ticket 'issue: MA-254'
  say "$GO"
  run_guard "$(tool_payload Bash "\"command\":\"sed -i '' 's|^approved:.*|approved: 2026-10-31, \\\"$GO\\\"|' $SPEC\"")" g20
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *'set or change an approval with the Edit or Write tool'* ]] || false
}

@test "other files and draft edits get no G20 vote" {
  say 'no'
  # notes.md exists and holds the old_string, so the Edit is judged; it has no frontmatter.
  printf '%s\n' '# notes' 'status: draft' 'date: 2026-10-14' 'approved: (set only on an explicit yes)' > "$R/notes.md"
  approve 'no' "$R/notes.md"
  [ -z "$output" ]
  run_guard "$(tool_payload Edit "\"file_path\":\"$SPEC\",\"old_string\":\"## Problem\",\"new_string\":\"## Problem\\nstatus: draft\"")" g20
  [ -z "$output" ]
}

@test "a Bash write of approved into a spec is denied; a read is not" {
  run_guard "$(bash_payload "sed -i '' s/draft/approved/ .kern/specs/export.md")" g20
  [ "$(decision_of "$output")" = deny ]
  run_guard "$(bash_payload "grep -n approved .kern/specs/export.md")" g20
  [ -z "$output" ]
}

@test "a Write of a new plan with a real quote approves" {
  mkdir -p "$R/.kern/plans"
  say 'yes, inline'
  run_guard "$(tool_payload Write "\"file_path\":\"$R/.kern/plans/p.md\",\"content\":\"---\\nstatus: approved\\napproved: 2026-10-14, \\\"yes, inline\\\"\\n---\\n\"")" g20
  [ -z "$output" ]
}

# edit OLD NEW [REPLACE_ALL] [PATH]: an Edit of the spec (or PATH). OLD and NEW hold no double quote.
edit() {
  run_guard "$(tool_payload Edit "\"file_path\":\"${4:-$SPEC}\",\"old_string\":\"$1\",\"new_string\":\"$2\",\"replace_all\":${3:-false}")" g20
}

# approved_spec QUOTE: makes the spec approved with QUOTE, older than the user's message.
approved_spec() {
  printf '%s\n' '---' 'status: approved' 'date: 2026-10-14' "approved: 2026-10-14, \"$1\"" '---' '## Problem' > "$SPEC"
  touch -t 202001010000 "$SPEC"
}

@test "an Edit of draft to approved is checked though new_string has no status line" {
  say 'yes'
  edit 'draft' 'approved'
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"needs an approved: line"* ]] || false
}

@test "an Edit that changes the approved: line of an approved file is checked" {
  approved_spec 'yes'
  say 'yes'
  edit 'approved: 2026-10-14, \"yes\"' 'approved: 2026-10-14, \"ship it\"'
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"not a line of the user's last message"* ]] || false
}

@test "replace_all is honoured when the edit is applied" {
  printf '%s\n' '---' 'title: draft notes' 'status: draft' 'approved: (set only on an explicit yes)' '---' > "$SPEC"
  touch -t 202001010000 "$SPEC"
  say 'yes'
  edit 'draft' 'approved' false
  [ -z "$output" ]
  edit 'draft' 'approved' true
  [ "$(decision_of "$output")" = deny ]
}

@test "an approved file edited below its frontmatter gets no vote" {
  approved_spec 'yes'
  edit '## Problem' '## Problem\nSums print bare.'
  [ -z "$output" ]
}

@test "a Markdown file outside the work dir is checked too" {
  mkdir -p "$R/docs/plans"
  say 'yes'
  run_guard "$(tool_payload Write "\"file_path\":\"$R/docs/plans/p.md\",\"content\":\"---\nstatus: approved\napproved: 2026-10-14, \\\"ship it\\\"\n---\n\"")" g20
  [ "$(decision_of "$output")" = deny ]
  run_guard "$(tool_payload Write "\"file_path\":\"$R/docs/notes.md\",\"content\":\"# notes\\napproved by nobody\\n\"")" g20
  [ -z "$output" ]
}

@test "gawk -i inplace, and cp or mv of an approved file onto a spec, are denied" {
  run_guard "$(bash_payload "gawk -i inplace '{ sub(/draft/, \\\"approved\\\") } 1' .kern/specs/export.md")" g20
  [ "$(decision_of "$output")" = deny ]
  printf '%s\n' '---' 'status: approved' 'approved: 2026-10-14, "yes"' '---' > "$BATS_TEST_TMPDIR/x.md"
  run_guard "$(bash_payload "cp $BATS_TEST_TMPDIR/x.md .kern/specs/export.md")" g20
  [ "$(decision_of "$output")" = deny ]
  run_guard "$(bash_payload "mv $BATS_TEST_TMPDIR/x.md .kern/specs/export.md")" g20
  [ "$(decision_of "$output")" = deny ]
  run_guard "$(bash_payload "cp README.md notes.md")" g20
  [ -z "$output" ]
}

@test "prompt_hashes folds case, blanks and a final . or !, one hash per line" {
  . "$K/hooks/lib/state.sh"
  [ "$(printf '  YES,   approved!  \n\nsecond line\n' | prompt_hashes)" = "$(printf 'yes, approved\nsecond line\n' | prompt_hashes)" ]
  [ "$(printf 'one\ntwo\n' | prompt_hashes | wc -w | tr -d ' ')" -eq 2 ]
}

@test "the dispatcher lists g20 among the guards it expects" {
  grep -q '^KERN_GUARD_IDS=".* g20[ "]' "$K/hooks/pre-tool-use"
}

@test "a contraction or cannot holds the approval, with a straight or curly apostrophe" {
  say "Looks ok, but I can't sign off yet\nWe can't ship this yet\nI cannot approve it\nok, but it isn’t ready\nok, but I won’t sign\nyes it doesnt work"
  for q in "Looks ok, but I can't sign off yet" "We can't ship this yet" 'I cannot approve it' 'ok, but it isn’t ready' 'ok, but I won’t sign' 'yes it doesnt work'; do
    approve "$q"
    [ "$(decision_of "$output")" = deny ] || { echo "quote: $q: $output"; return 1; }
    [[ "$output" == *'is not an explicit yes'* ]] || { echo "quote: $q: $output"; return 1; }
  done
  say 'yes, delegate\nok good, go'
  approve 'yes, delegate'
  [ -z "$output" ]
  approve 'ok good, go'
  [ -z "$output" ]
}

# sh_cmd COMMAND: G20 on a Bash COMMAND, which may hold any character.
sh_cmd() {
  . "$K/hooks/lib/json.sh"
  run_guard "$(tool_payload Bash "\"command\":\"$(printf '%s' "$1" | json_escape)\"")" g20
}

# denied: G20 denied the last call.
denied() {
  [ "$(decision_of "$output")" = deny ] || { echo "expected deny: $output"; return 1; }
}

# working_dirs [WORK]: makes WORK/ledgers/x, WORK/reviews and WORK/tmp, WORK being .kern by default.
working_dirs() {
  mkdir -p "$R/${1:-.kern}/ledgers/x" "$R/${1:-.kern}/reviews" "$R/${1:-.kern}/tmp" "$R/.kern/plans"
}

# INVENTED: JSON text of a file that sets status: approved with a quote the user never gave.
INVENTED='---\nstatus: approved\napproved: 2026-10-14, \"ship it\"\n---\n'

# write_to PATH: a Write of the invented approval to PATH.
write_to() {
  run_guard "$(tool_payload Write "\"file_path\":\"$1\",\"content\":\"$INVENTED\"")" g20
}

# write_text PATH TEXT: a Write of TEXT, JSON text, to PATH.
write_text() {
  run_guard "$(tool_payload Write "\"file_path\":\"$1\",\"content\":\"$2\"")" g20
}

@test "a ledger append that holds approved gets no vote" {
  working_dirs
  sh_cmd "printf '%s\n' 'Decision: size approved as one PR' >> .kern/ledgers/x/ledger.md"
  no_vote
}

@test "a here-doc that holds approved into a review note gets no vote" {
  working_dirs
  sh_cmd "cat > .kern/reviews/task-3.md <<'EOF'
Task quality: approved
EOF"
  no_vote
}

@test "a working file written beside a read of an approved spec gets no vote" {
  working_dirs
  approved_spec 'yes'
  sh_cmd "printf 'x\n' > .kern/reviews/p.proofs.md; bash proof-check .kern/specs/export.md .kern/reviews/p.proofs.md"
  no_vote
}

@test "a shell write that holds approved into a spec or plan is denied" {
  working_dirs
  sh_cmd "printf 'status: approved\n' > .kern/specs/x.md"
  denied
  sh_cmd "printf 'status: approved\n' > .kern/plans/x.md"
  denied
}

@test "a shell write to WORK/tmp gets no vote" {
  working_dirs
  sh_cmd "printf 'notes\n' > .kern/tmp/p.md"
  no_vote
  sh_cmd "printf 'approved\n' > .kern/tmp/p.md"
  no_vote
  printf '%s\n' '---' 'status: approved' '---' > "$R/.kern/tmp/p.md"
  sh_cmd "printf 'notes\n' >> .kern/tmp/p.md"
  no_vote
}

@test "a Write or Edit of a working file that holds only the word gets no vote" {
  working_dirs
  for f in ledgers/x/ledger.md reviews/task-3.md tmp/p.md; do
    run_guard "$(tool_payload Write "\"file_path\":\"$R/.kern/$f\",\"content\":\"Task quality: approved\\n\"")" g20
    no_vote
  done
  printf '## Problem\n' > "$R/.kern/tmp/note.md"
  edit '## Problem' '## Problem\nThe size was approved.' false "$R/.kern/tmp/note.md"
  no_vote
}

@test "a Write or Edit that approves a working file, spec or plan is denied" {
  working_dirs
  for f in ledgers/x/ledger.md reviews/task-3.md tmp/p.md plans/x.md; do
    write_to "$R/.kern/$f"
    denied
  done
  cp "$SPEC" "$R/.kern/tmp/draft.md"
  edit 'status: draft' 'status: approved' false "$R/.kern/tmp/draft.md"
  denied
  edit 'status: draft' 'status: approved'
  denied
}

@test "a shell redirect that approves a working file is denied" {
  working_dirs
  for f in .kern/ledgers/x/ledger.md .kern/reviews/p.md .kern/tmp/p.md; do
    sh_cmd "echo 'status: approved' > $f"
    denied
  done
}

@test "the word status alone in a working file gets no vote" {
  working_dirs
  sh_cmd "printf 'Status: done\n' > .kern/reviews/p.md"
  no_vote
  run_guard "$(tool_payload Write "\"file_path\":\"$R/.kern/reviews/q.md\",\"content\":\"Status: done\\n\"")" g20
  no_vote
}

@test "both words in a shell write's text are denied, and the reason sends it to the Write tool" {
  working_dirs
  sh_cmd "printf 'status of the size: approved by the lead\n' > .kern/tmp/p.md"
  denied
  [[ "$output" == *'both status and approved'* ]] || false
  [[ "$output" == *'use the Write tool, which judges each line'* ]] || false
  [[ "$output" == *'a line holding both stays denied; for a ledger line, reword it or append it in a call of its own'* ]] || false
}

@test "both words in upper case in a working file's text are denied" {
  working_dirs
  sh_cmd "printf 'STATUS: DONE. APPROVED.\n' >> .kern/reviews/p.md"
  denied
}

@test "both words in a here-doc into a working file are denied" {
  working_dirs
  sh_cmd "cat > .kern/reviews/task-3.md <<'EOF'
Status: done
Task quality: approved
EOF"
  denied
}

@test "a printf with newlines that approves a working file is denied" {
  working_dirs
  sh_cmd "printf '---\nstatus: approved\napproved: 2026-10-14\n---\n' > .kern/tmp/p.md"
  denied
}

@test "a Write or Edit with both words on one line of a working file is denied, naming the line" {
  working_dirs
  write_text "$R/.kern/reviews/p.md" '# Note\nstatus of the size: approved by the lead\n'
  denied
  [[ "$output" == *'line 2 of p.md holds both status and approved'* ]] || false
  [[ "$output" == *'reword that line'* ]] || false
  [[ "$output" == *"keep a report's Status: line"* ]] || false
  write_text "$R/.kern/reviews/p.md" 'APPROVED, AND THE STATUS STANDS\nstatus approved\n'
  denied
  [[ "$output" == *'line 1 of p.md'* ]] || false
  [[ "$output" != *'line 2 of p.md'* ]] || false
  printf 'Status: done\n' > "$R/.kern/reviews/q.md"
  edit 'done' 'approved' false "$R/.kern/reviews/q.md"
  denied
  [[ "$output" == *'line 1 of q.md'* ]] || false
}

@test "a Write of a report with Status: on one line and the word on a later line gets no vote" {
  working_dirs
  mkdir -p "$R/.kern/ledgers/x/reports"
  write_text "$R/.kern/ledgers/x/reports/task-3.md" 'Status: DONE_WITH_CONCERNS\n\nThe size was approved as one PR.\n'
  no_vote
  write_text "$R/.kern/ledgers/x/reports/task-4.md" 'Status: DONE \\\nThe size was approved as one PR.\n'
  no_vote
}

@test "a Write of a draft under WORK/tmp with its approved: placeholder gets no vote" {
  working_dirs
  write_text "$R/.kern/tmp/draft.md" '---\nstatus: draft\napproved: (set only on an explicit yes)\n---\n## Problem\n'
  no_vote
}

@test "an Edit of a real ledger gets no vote" {
  working_dirs
  printf '%s\n' '# kern ledger: .kern/plans/x.md' 'Plan: abc' 'Main: /r branch=main head=abc status=def' \
    'Task 1: review round=1 tree=abc spec=compliant quality=approved' 'Task 2: note' > "$R/.kern/ledgers/x/ledger.md"
  edit 'Task 2: note' 'Task 2: a note' false "$R/.kern/ledgers/x/ledger.md"
  no_vote
}

@test "an Edit G20 cannot model reads the whole of a working file, as it has no exact bytes" {
  working_dirs
  printf 'Status: done\n' > "$R/.kern/reviews/q.md"
  edit 'not in the file' 'approved' false "$R/.kern/reviews/q.md"
  denied
  [[ "$output" == *'old_string is not in q.md'* ]] || false
  edit 'not in the file' 'the word approved'
  no_vote
}

@test "a Write or Edit into a working directory that does not exist yet is judged from the nearest one that does" {
  working_dirs
  write_text "$R/.kern/reviews/new/deep/p.md" 'status of the size: approved by the lead\n'
  denied
  rm -rf "$R/.kern/tmp"
  write_text "$R/.kern/tmp/new/p.md" 'status of the size: approved by the lead\n'
  denied
  edit 'x' 'status of the size: approved by the lead' false "$R/.kern/reviews/new/p.md"
  denied
  write_text "$R/.kern/reviews/new/p.md" 'Status: done\n'
  no_vote
}

@test "a Write outside the working directories that does not exist yet gets no vote" {
  working_dirs
  write_text "$R/.kern/notes/new/p.md" 'status of the size: approved by the lead\n'
  no_vote
  write_text '/g20-no-such-directory/p.md' 'status of the size: approved by the lead\n'
  no_vote
}

@test "both words in a spec's body are not a working file's matter" {
  say 'yes'
  run_guard "$(tool_payload Write "\"file_path\":\"$R/.kern/specs/n.md\",\"content\":\"Status: done\\nTask quality: approved\\n\"")" g20
  no_vote
}

@test "an approval written after a cd into a working directory is denied" {
  working_dirs
  sh_cmd "cd .kern/tmp && printf 'status: approved\n' > p.md"
  denied
}

@test "an approval written through a symlinked working name is denied" {
  working_dirs
  printf 'x\n' > "$R/.kern/reviews/real.md"
  ln -s ../reviews/real.md "$R/.kern/tmp/link.md"
  ln -s ../reviews "$R/.kern/tmp/dir"
  sh_cmd "printf 'status: approved\n' >> .kern/tmp/link.md"
  denied
  sh_cmd "printf 'status: approved\n' > .kern/tmp/dir/x.md"
  denied
  write_to "$R/.kern/tmp/link.md"
  denied
}

@test "a name beside a working directory is not a working file" {
  working_dirs
  mkdir -p "$R/.kern/tmp2" "$R/.kern/specs/tmp"
  for f in .kern/tmp2/p.md .kern/specs/tmp/p.md .kern/tmp.md tmp/p.md; do
    mkdir -p "$R/${f%/*}"
    sh_cmd "printf 'approved\n' > $f"
    denied
    write_to "$R/$f"
    denied
  done
}

@test "a symlink under WORK/tmp that points out is judged as the file it reaches" {
  working_dirs
  ln -s ../specs/export.md "$R/.kern/tmp/link.md"
  sh_cmd "printf 'approved\n' >> .kern/tmp/link.md"
  denied
  write_to "$R/.kern/tmp/link.md"
  denied
  ln -s ../specs/export.md "$R/.kern/tmp/link.txt"
  write_to "$R/.kern/tmp/link.txt"
  denied
  ln -s ../specs "$R/.kern/tmp/dir"
  sh_cmd "printf 'approved\n' > .kern/tmp/dir/x.md"
  denied
  write_to "$R/.kern/tmp/dir/x.md"
  denied
}

@test "a symlink that keeps inside the working directories is a working file" {
  working_dirs
  printf 'x\n' > "$R/.kern/reviews/real.md"
  ln -s ../reviews/real.md "$R/.kern/tmp/link.md"
  sh_cmd "printf 'approved\n' >> .kern/tmp/link.md"
  no_vote
}

@test "a spec that is a symlink into WORK/tmp is judged as a spec" {
  working_dirs
  printf 'x\n' > "$R/.kern/tmp/p.md"
  ln -s ../tmp/p.md "$R/.kern/plans/x.md"
  sh_cmd "printf 'approved\n' >> .kern/plans/x.md"
  denied
  write_to "$R/.kern/plans/x.md"
  denied
}

@test ".. in a path is read as the file system reads it" {
  working_dirs
  sh_cmd "printf 'approved\n' > .kern/tmp/../specs/x.md"
  denied
  write_to "$R/.kern/tmp/../specs/x.md"
  denied
  sh_cmd "cd .kern/tmp && printf 'approved\n' > ../specs/x.md"
  denied
  sh_cmd "printf 'approved\n' > .kern/specs/../tmp/p.md"
  no_vote
  # .. after a symlink leaves the directory the symlink reaches.
  mkdir -p "$R/.kern/specs/sub"
  ln -s ../specs/sub "$R/.kern/tmp/dir"
  sh_cmd "printf 'approved\n' > .kern/tmp/dir/../x.md"
  denied
}

@test "a directory that does not exist yet is not a working directory" {
  working_dirs
  sh_cmd "mkdir -p .kern/tmp/new && printf 'approved\n' > .kern/tmp/new/x.md"
  denied
}

@test "a copy from a working file into a spec or plan is denied" {
  working_dirs
  printf '%s\n' '---' 'status: approved' 'approved: 2026-10-14, "yes"' '---' > "$R/.kern/tmp/p.md"
  for c in 'cp .kern/tmp/p.md .kern/plans/x.md' 'mv .kern/tmp/p.md .kern/specs/x.md' \
    'cat .kern/tmp/p.md > .kern/plans/x.md' 'tee .kern/plans/x.md < .kern/tmp/p.md' \
    'ln -s ../tmp/p.md .kern/plans/x.md' 'ln .kern/tmp/p.md .kern/plans/x.md'; do
    sh_cmd "$c"
    denied
    [[ "$output" == *'status: approved line'* ]] || { echo "$c: $output"; return 1; }
  done
}

@test "an in-place edit of a working file in a command that holds approved is denied" {
  working_dirs
  cp "$SPEC" "$R/.kern/tmp/p.md"
  for c in "sed -i '' 's/draft/approved/' .kern/tmp/p.md" "sed -i.bak -e 's/draft/approved/' .kern/tmp/p.md" \
    "perl -pi -e 's/draft/approved/' .kern/tmp/p.md" "gawk -i inplace '{ sub(/draft/, \"approved\") } 1' .kern/tmp/p.md" \
    "vim -c '%s/draft/approved/' -c wq .kern/tmp/p.md" "ed -s .kern/tmp/p.md <<'EOF'
s/draft/approved/
w
EOF" "find .kern/tmp -name p.md -exec sed -i '' 's/draft/approved/' .kern/tmp/p.md ';'"; do
    sh_cmd "$c"
    denied
    [[ "$output" == *'text editor'* ]] || { echo "$c: $output"; return 1; }
  done
}

@test "BSD sed's -I is an in-place edit" {
  working_dirs
  cp "$SPEC" "$R/.kern/tmp/p.md"
  sh_cmd "sed -I '' 's/draft/approved/' .kern/tmp/p.md"
  denied
  sh_cmd "sed -I.bak 's/draft/approved/' .kern/specs/export.md"
  denied
}

@test "gsed and busybox sed are text editors" {
  working_dirs
  cp "$SPEC" "$R/.kern/tmp/p.md"
  for c in "gsed -i 's/draft/approved/' .kern/tmp/p.md" "busybox sed -i 's/draft/approved/' .kern/tmp/p.md"; do
    sh_cmd "$c"
    denied
    [[ "$output" == *'text editor'* ]] || { echo "$c: $output"; return 1; }
  done
}

@test "ed -q takes no value, so the file after it is read" {
  working_dirs
  cp "$SPEC" "$R/.kern/tmp/p.md"
  sh_cmd "ed -q .kern/tmp/p.md <<'EOF'
s/draft/approved/
w
EOF"
  denied
}

@test "a text editor that writes a working file through a redirect or a pipe in a command that holds approved is denied" {
  working_dirs
  for c in "sed 's/draft/approved/' .kern/specs/export.md > .kern/tmp/p.md" \
    "awk '{ sub(/draft/, \"approved\") } 1' .kern/specs/export.md > .kern/tmp/p.md" \
    "sed 's/draft/approved/' .kern/specs/export.md | tee .kern/tmp/p.md"; do
    sh_cmd "$c"
    denied
    [[ "$output" == *'text editor'* ]] || { echo "$c: $output"; return 1; }
  done
}

@test "a text editor gets no vote on a working file when no command text holds approved" {
  working_dirs
  cp "$SPEC" "$R/.kern/tmp/p.md"
  sh_cmd "sed -i '' 's/Problem/Issue/' .kern/tmp/p.md"
  no_vote
}

@test "a text editor in its own simple command does not touch a working file's note" {
  working_dirs
  sh_cmd "sed -n 1p README.md; printf 'approved\n' >> .kern/ledgers/x/ledger.md"
  no_vote
}

@test "a copy into a working file from a file that holds an approval is denied" {
  working_dirs
  printf '%s\n' '---' 'status: approved' 'approved: 2026-10-14, "yes"' '---' > "$R/notes.txt"
  cp "$R/notes.txt" "$R/notes.md"
  for c in 'cp notes.txt .kern/tmp/p.md' 'cp notes.md .kern/tmp/' 'mv notes.txt .kern/reviews/p.md' \
    'cat notes.txt > .kern/tmp/p.md' 'cat notes.txt >> .kern/ledgers/x/ledger.md' 'tee .kern/tmp/p.md < notes.txt' \
    'ln -s ../../notes.txt .kern/tmp/p.md' 'install notes.txt .kern/tmp/p.md' 'dd if=notes.txt of=.kern/tmp/p.md' \
    'cat notes.txt | tee .kern/tmp/p.md' 'printf %s "$(cat notes.txt)" > .kern/tmp/p.md' \
    'printf %s `cat notes.txt` > .kern/tmp/p.md'; do
    sh_cmd "$c"
    denied
    [[ "$output" == *'holds a status: approved line'* ]] || { echo "$c: $output"; return 1; }
  done
  approved_spec 'yes'
  sh_cmd 'cat .kern/specs/export.md > .kern/tmp/copy.md'
  denied
}

@test "a copy through a compound redirect into a working file is denied" {
  working_dirs
  printf '%s\n' '---' 'status: approved' 'approved: 2026-10-14, "yes"' '---' > "$R/notes.txt"
  for c in '{ cat notes.txt; } > .kern/tmp/p.md' '(cat notes.txt) > .kern/tmp/p.md' \
    'for f in 1; do cat notes.txt; done > .kern/tmp/p.md' 'if true; then cat notes.txt; fi > .kern/tmp/p.md' \
    'exec > .kern/tmp/p.md; cat notes.txt'; do
    sh_cmd "$c"
    denied
    [[ "$output" == *'holds a status: approved line'* ]] || { echo "$c: $output"; return 1; }
  done
}

@test "a substitution in an unquoted here-doc body joins the copy" {
  working_dirs
  printf '%s\n' '---' 'status: approved' 'approved: 2026-10-14, "yes"' '---' > "$R/notes.txt"
  sh_cmd 'cat > .kern/tmp/p.md <<EOF
$(cat notes.txt)
EOF'
  denied
}

@test "a pipe beside a working write joins them" {
  working_dirs
  approved_spec 'yes'
  sh_cmd "grep -c Problem .kern/specs/export.md | wc -l; printf 'x\n' > .kern/tmp/n.md"
  denied
}

@test "a || beside a working write joins nothing" {
  working_dirs
  approved_spec 'yes'
  sh_cmd "grep -c Problem .kern/specs/export.md || true; printf 'x\n' > .kern/tmp/n.md"
  no_vote
  sh_cmd "grep -c Problem .kern/specs/export.md || grep -c Scope .kern/specs/export.md || true; printf 'x\n' > .kern/tmp/n.md"
  no_vote
}

@test "a proofs table beside a read of an approved spec gets no vote" {
  working_dirs
  approved_spec 'yes'
  sh_cmd "cat > .kern/reviews/p.proofs.md <<'EOF'
| Line | State |
|---|---|
| 3 | \$(proved) |
EOF
bash proof-check .kern/specs/export.md .kern/reviews/p.proofs.md"
  no_vote
  sh_cmd "printf '| 3 | \$(proved) |\n' > .kern/reviews/p.proofs.md; bash proof-check .kern/specs/export.md .kern/reviews/p.proofs.md"
  no_vote
}

@test "a sed that fails on the command leaves it read as joined" {
  local bin="$BATS_TEST_TMPDIR/bin"
  working_dirs
  approved_spec 'yes'
  mkdir "$bin"
  printf '#!/bin/sh\ncase "$1" in "s/||"*) exit 1 ;; esac\nexec %s "$@"\n' "$(command -v sed)" > "$bin/sed"
  chmod +x "$bin/sed"
  PATH="$bin:$PATH"
  sh_cmd "printf '| 3 |\n' > .kern/reviews/p.proofs.md; bash proof-check .kern/specs/export.md .kern/reviews/p.proofs.md"
  denied
}

@test "a copy into a working file from a file with no approval gets no vote" {
  working_dirs
  sh_cmd 'cp README.md .kern/tmp/r.md'
  no_vote
  sh_cmd 'cat README.md | tee .kern/tmp/r.md'
  no_vote
}

@test "a working path built at run time stays judged" {
  working_dirs
  approved_spec 'yes'
  sh_cmd 'printf approved > .kern/tmp/$X.md'
  denied
  sh_cmd 'cat .kern/specs/export.md > .kern/tmp/$X.md'
  denied
  sh_cmd 'printf x > .kern/tmp/$X.md; cat .kern/specs/export.md'
  denied
}

@test "work_dir in the settings names the working directories" {
  working_dirs .work
  mkdir -p "$R/.claude"
  printf 'work_dir: .work\n' > "$R/.claude/kern.local.yml"
  sh_cmd "printf 'approved\n' > .work/tmp/p.md"
  no_vote
  write_to "$R/.work/reviews/p.md"
  denied
  mkdir -p "$R/.kern/tmp"
  sh_cmd "printf 'approved\n' > .kern/tmp/p.md"
  denied
  write_to "$R/.kern/tmp/p.md"
  denied
}

@test "a work_dir kern-dir refuses, or settings that cannot be read, name no working directory" {
  mkdir -p "$R/.claude" "$R/tmp"
  printf 'work_dir: .\n' > "$R/.claude/kern.local.yml"
  sh_cmd "printf 'approved\n' > tmp/p.md"
  denied
  working_dirs
  printf 'work_dir: .kern\n' > "$R/.claude/kern.local.yml"
  read_fails awk "$R/.claude/kern.local.yml"
  sh_cmd "printf 'approved\n' > .kern/tmp/p.md"
  denied
}

@test "a work dir that is a symlink holds its working files where it lands" {
  mkdir -p "$BATS_TEST_TMPDIR/real/tmp" "$BATS_TEST_TMPDIR/real/specs"
  rm -rf "$R/.kern"
  ln -s "$BATS_TEST_TMPDIR/real" "$R/.kern"
  sh_cmd "printf 'approved\n' > .kern/tmp/p.md"
  no_vote
  sh_cmd "printf 'approved\n' > .kern/specs/x.md"
  denied
}

@test "WORK/tmp that is a symlink to the specs holds no working files" {
  rm -rf "$R/.kern/tmp"
  ln -s specs "$R/.kern/tmp"
  sh_cmd "printf 'approved\n' > .kern/tmp/x.md"
  denied
}

@test "WORK is the main worktree's: a linked worktree's own .kern/tmp is judged" {
  working_dirs
  git -C "$R" worktree add -q "$BATS_TEST_TMPDIR/wt" -b t 2> /dev/null
  W=$(cd "$BATS_TEST_TMPDIR/wt" && pwd -P)
  mkdir -p "$W/.kern/tmp"
  export CWD="$W"
  sh_cmd "printf 'approved\n' > .kern/tmp/p.md"
  denied
  sh_cmd "printf 'approved\n' > $R/.kern/tmp/p.md"
  no_vote
}

@test "a working directory named in another case is the same directory on a case-blind file system" {
  working_dirs
  [ -d "$R/.kern/TMP" ] || skip 'the file system tells case apart'
  sh_cmd "printf 'approved\n' > .kern/TMP/p.md"
  no_vote
}

# The route gate (M3 part 2 project 2's round 2 fix batch, the user's "Build the G20 gate", 2026-11-05): paid rounds
# 11-04 2 to 4 and 11-05 1 and 2 built a go's ticket with no spec. Under a live go a main-thread Write, Edit or
# NotebookEdit outside the work dir, of a file that is no test, waits for a spec the go approved under WORK/specs,
# or a Read of the running kern's diagnose skill in the transcript.

TR_N=0
# tr_read PATH [SIDECHAIN]: appends to the transcript a main-thread Read of PATH (a subagent's with SIDECHAIN true).
tr_read() {
  TR_N=$((TR_N + 1))
  printf '{"parentUuid":"p%s","isSidechain":%s,"message":{"role":"assistant","content":[{"type":"tool_use","id":"toolu_%s","name":"Read","input":{"file_path":"%s"}}]},"type":"assistant","uuid":"u%s"}\n' \
    "$TR_N" "${2:-false}" "$TR_N" "$1" "$TR_N" >> "$TR"
}
# route TOOL FIELDS [EXTRA]: G20's vote on a call of TOOL whose tool_input holds FIELDS, from a session whose
# transcript is TR, with EXTRA top-level fields after a comma.
route() {
  run_guard "$(payload PreToolUse "\"transcript_path\":\"$TR\",${3:+$3,}\"tool_name\":\"$1\",\"tool_input\":{$2}")" g20
}
# build PATH [EXTRA]: route's Write of PATH.
build() { route Write "\"file_path\":\"$1\",\"content\":\"export const sum = (a, b) => a + b;\\n\"" "${2-}"; }
# route_denied: G20 denied the last call with the route gate's reason.
route_denied() {
  [ "$(decision_of "$output")" = deny ] || { echo "$output"; return 1; }
  [[ "$output" == *"kern G20: under a go, a build starts at define, and no spec under $R/.kern/specs carries this go's approval. Read \${CLAUDE_PLUGIN_ROOT}/skills/define/SKILL.md and write it first. A bug starts at diagnose; a tests-only ticket edits test files only. A session that EnterWorktree moved into a worktree cannot write $R/.kern/specs: ExitWorktree with action keep, write the spec, then edit the worktree by its path."* ]] ||
    { echo "$output"; return 1; }
}
# go_route: a live go for MA-254, a transcript with the go's prompt, and the project's src and test folders.
go_route() {
  TR="$BATS_TEST_TMPDIR/t.jsonl"
  printf '{"type":"user","message":{"role":"user","content":"/kern:autopilot go MA-254"}}\n' > "$TR"
  mkdir -p "$R/src" "$R/test"
  say "$GO"
}

@test "under a go a build edit with no spec the go approved is denied, by Write, Edit and NotebookEdit" {
  go_route
  build "$R/src/sum.js"
  route_denied
  printf 'export const sum = (a, b) => a - b;\n' > "$R/src/sum.js"
  route Edit "\"file_path\":\"$R/src/sum.js\",\"old_string\":\"a - b\",\"new_string\":\"a + b\""
  route_denied
  route NotebookEdit "\"notebook_path\":\"$R/src/sum.ipynb\",\"new_source\":\"1 + 1\""
  route_denied
  # A new file in a new folder, a relative path, and a linked worktree's file are builds too.
  build "$R/lib/round/sum.js"
  route_denied
  build "src/sum.js"
  route_denied
  git -C "$R" worktree add -q "$R/.claude/worktrees/ma-254" -b ma-254 2> /dev/null
  build "$R/.claude/worktrees/ma-254/src/sum.js"
  route_denied
  # A spec that is a draft, approved for another ticket, or approved by a quote that is not the go's opens nothing.
  printf '%s\n' '---' 'status: draft' 'issue: MA-254' 'approved: 2026-11-05, "/kern:autopilot go MA-254"' '---' > "$R/.kern/specs/draft.md"
  printf '%s\n' '---' 'status: approved' 'issue: MA-1' 'approved: 2026-11-05, "/kern:autopilot go MA-1"' '---' > "$R/.kern/specs/other.md"
  printf '%s\n' '---' 'status: approved' 'issue: MA-254' 'approved: 2026-11-05, "yes"' '---' > "$R/.kern/specs/yes.md"
  build "$R/src/sum.js"
  route_denied
}

@test "a spec under WORK/specs that the go approved opens the gate, past the draft PR too" {
  go_route
  printf '%s\n' '---' 'form: short' 'status: approved' 'issue: MA-254' 'approved: 2026-11-05, "/kern:autopilot go MA-254"' '---' '## Problem' > "$R/.kern/specs/round-sum.md"
  build "$R/src/sum.js"
  no_vote
  # The go's CI fix rounds edit past the draft, where the go approves no new file.
  state_line 'go_phase: pr'
  build "$R/src/sum.js"
  no_vote
  # A spec below a folder in specs, or a spec of a second go, does not count.
  mkdir -p "$R/.kern/specs/old"
  mv "$R/.kern/specs/round-sum.md" "$R/.kern/specs/old/round-sum.md"
  build "$R/src/sum.js"
  route_denied
  mv "$R/.kern/specs/old/round-sum.md" "$R/.kern/specs/round-sum.md"
  say '/kern:autopilot go MA-255'
  build "$R/src/sum.js"
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *'no spec under '*'/specs carries this go'*'s approval'* ]] || false
}

@test "a test file is no build: a tests-only ticket edits test files with no spec" {
  local p
  go_route
  for p in test/sum.test.js tests/test_sum.py src/__tests__/sum.js src/sum.test.js src/sum.spec.ts sum_test.go \
    .claude/worktrees/ma-254/test/sum.js; do
    build "$R/$p"
    no_vote || { echo "path: $p"; return 1; }
  done
  # A test word in a file or folder name that is no test path is a build.
  for p in src/testing.js src/contest/sum.js src/tests.js; do
    build "$R/$p"
    route_denied || { echo "path: $p"; return 1; }
  done
}

@test "a main-thread Read of the running kern's diagnose skill opens the gate: a bug starts at diagnose" {
  go_route
  # Another checkout's diagnose, a subagent's read and define's skill open nothing.
  tr_read "$BATS_TEST_TMPDIR/other-kern/skills/diagnose/SKILL.md"
  tr_read "$K/skills/diagnose/SKILL.md" true
  tr_read "$K/skills/define/SKILL.md"
  build "$R/src/sum.js"
  route_denied
  tr_read "$K/skills/diagnose/SKILL.md"
  build "$R/src/sum.js"
  no_vote
}

@test "a subagent's edit is left to the subagent's own route" {
  go_route
  build "$R/src/sum.js" '"agent_type":"kern:implementer"'
  no_vote
  build "$R/src/sum.js" '"agent_id":"a1"'
  no_vote
}

@test "with no live go the gate does not vote" {
  go_route
  # Autopilot off, which ends the go, autopilot on with no go, and a go of another repository.
  say '/kern:autopilot off'
  build "$R/src/sum.js"
  no_vote
  say '/kern:autopilot on'
  build "$R/src/sum.js"
  no_vote
  say "$GO"
  build "$R/src/sum.js"
  route_denied
  R2="$BATS_TEST_TMPDIR/other"
  make_repo "$R2"
  R2=$(cd "$R2" && pwd -P)
  CWD=$R2
  build "$R2/src/sum.js"
  no_vote
}

@test "a file under the work dir is no build, and a fault allows" {
  go_route
  build "$R/.kern/tmp/pr-body.md"
  no_vote
  build "$R/.kern/specs/round-sum.md"
  no_vote
  build "$R/.kern/new/notes.txt"
  no_vote
  # A transcript the guard cannot read, a work dir it cannot read, and a path it cannot resolve allow.
  rm "$TR"
  build "$R/src/sum.js"
  no_vote
  go_route
  mkdir -p "$R/.claude"
  printf 'work_dir: ../outside\n' > "$R/.claude/kern.local.yml"
  build "$R/src/sum.js"
  no_vote
  rm "$R/.claude/kern.local.yml"
  build "$R/new/../src/sum.js"
  no_vote
}

@test "a file outside the main worktree's root is no build: memory, a scratchpad and /tmp pass" {
  # Fix round 1 (the review's Minor 1): the gate holds the go's repository, not every file the session writes.
  local d
  go_route
  for d in "$BATS_TEST_TMPDIR/home/.claude/projects/p/memory" "$BATS_TEST_TMPDIR/scratchpad" /tmp; do
    mkdir -p "$d"
    build "$d/notes.md"
    no_vote || { echo "dir: $d"; return 1; }
  done
  build "$R/src/sum.js"
  route_denied
}

@test "a spec G20 cannot read, a specs dir it cannot list and a transcript grep that fails allow" {
  go_route
  # A spec whose frontmatter cannot be read counts, as G20's other reads do (the review's Minor 13).
  printf '%s\n' '---' 'status: draft' '---' > "$R/.kern/specs/locked.md"
  chmod 000 "$R/.kern/specs/locked.md"
  build "$R/src/sum.js"
  chmod 644 "$R/.kern/specs/locked.md"
  no_vote
  rm "$R/.kern/specs/locked.md"
  build "$R/src/sum.js"
  route_denied
  # A specs dir that cannot be listed (fix round 1, the review's Minor 7).
  chmod 000 "$R/.kern/specs"
  build "$R/src/sum.js"
  chmod 755 "$R/.kern/specs"
  no_vote
  # The diagnose read's third grep fails while the first finds a line (the review's Minor 6): a subagent's read,
  # which that grep would drop, so only its fault opens the gate.
  tr_read "$K/skills/diagnose/SKILL.md" true
  build "$R/src/sum.js"
  route_denied
  read_fails grep '*isSidechain*'
  build "$R/src/sum.js"
  no_vote
  [ "$(read_failures grep)" -ge 1 ]
}

# The commit gate (M3 part 2 project 2's round 7 fix batch; the user's "Both fixes, then round 8 (Recommended)",
# 2026-11-05): round 7's go-required-check-stop wrote its build by a shell redirect, which the route gate does not
# see, and committed it with no spec. Under the route gate's own gate, G5 hands each commit to _g20_commit_route,
# which reads the paths the commit takes, whatever wrote them.

# go_wt: go_route, then a linked worktree W on branch ma-254 under .claude/worktrees, where a go builds.
go_wt() {
  go_route
  W="$R/.claude/worktrees/ma-254"
  git -C "$R" worktree add -q "$W" -b ma-254 2> /dev/null
}
# commit CMD [EXTRA]: G5's vote on the Bash call CMD (no double quote) run in W, from a session whose transcript is
# TR, with EXTRA top-level fields after a comma. G5 calls the commit gate.
commit() {
  local cwd=$CWD
  CWD=$W
  run_guard "$(payload PreToolUse "\"transcript_path\":\"$TR\",${2:+$2,}\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$1\"}")" g05
  CWD=$cwd
}
# commit_denied PATH: G20 denied the last commit with the commit gate's reason, naming PATH; another guard's deny
# may come first.
commit_denied() {
  [ "$(decision_of "$output")" = deny ] || { echo "$output"; return 1; }
  [[ "$output" == *"G20: under a go, a build starts at define, and no spec under $R/.kern/specs carries this go's approval, so this commit of $1 is held. Read \${CLAUDE_PLUGIN_ROOT}/skills/define/SKILL.md and write it first. A bug starts at diagnose; a tests-only ticket commits test files only. A session that EnterWorktree moved into a worktree cannot write $R/.kern/specs: ExitWorktree with action keep, write the spec, then commit in the worktree by its path."* ]] ||
    { echo "$output"; return 1; }
}
# commit_passed: G20 said nothing on the last commit, and G5 allowed it.
commit_passed() {
  [ "$(decision_of "$output")" = allow ] && [[ "$output" != *G20* ]] || { echo "$output"; return 1; }
}
# staged FILE...: writes each FILE in W and stages it.
staged() {
  local f
  for f in "$@"; do
    mkdir -p "$(dirname "$W/$f")"
    printf 'export const sum = (a, b) => a + b;\n' > "$W/$f"
  done
  git -C "$W" add -- "$@"
}

@test "under a go a commit of a build with no spec is denied, whatever wrote its files" {
  go_wt
  staged src/sum.js test/sum.test.js
  commit "git commit -m 'feat: round sum'"
  commit_denied src/sum.js
  # A file the commit deletes is a build too.
  git -C "$W" commit -q -m 'feat: round sum'
  git -C "$W" rm -q src/sum.js
  commit "git commit -m 'feat: drop sum'"
  commit_denied src/sum.js
}

@test "a spec the go approved, or a diagnose Read, opens the commit gate" {
  go_wt
  staged src/sum.js
  tr_read "$K/skills/define/SKILL.md"
  commit "git commit -m 'feat: round sum'"
  commit_denied src/sum.js
  printf '%s\n' '---' 'form: short' 'status: approved' 'issue: MA-254' 'approved: 2026-11-05, "/kern:autopilot go MA-254"' '---' '## Problem' > "$R/.kern/specs/round-sum.md"
  commit "git commit -m 'feat: round sum'"
  commit_passed
  rm "$R/.kern/specs/round-sum.md"
  commit "git commit -m 'feat: round sum'"
  commit_denied src/sum.js
  tr_read "$K/skills/diagnose/SKILL.md"
  commit "git commit -m 'fix: round sum'"
  commit_passed
}

@test "a tests-only commit passes the commit gate, and so does a file under the work dir" {
  go_wt
  staged test/sum.test.js tests/round.py src/__tests__/sum.js src/sum.spec.ts
  commit "git commit -m 'test: round sum'"
  commit_passed
  # A file under the work dir, in a commit run in the main checkout, is no build either.
  git -C "$R" switch -q -c ma-254-notes
  mkdir -p "$R/.kern/notes"
  printf 'n\n' > "$R/.kern/notes/n.md"
  git -C "$R" add -f .kern/notes/n.md
  W=$R
  commit "git commit -m 'docs: notes'"
  commit_passed
}

@test "outside a go, or for a subagent, the commit gate does not vote" {
  go_wt
  staged src/sum.js
  commit "git commit -m 'feat: round sum'" '"agent_id":"a1"'
  commit_passed
  # Autopilot off ends the go; G5 asks as it does for any commit then. Autopilot on with no go allows.
  say '/kern:autopilot off'
  commit "git commit -m 'feat: round sum'"
  [ "$(decision_of "$output")" = ask ]
  [[ "$output" != *G20* ]] || false
  say '/kern:autopilot on'
  commit "git commit -m 'feat: round sum'"
  commit_passed
}

@test "with -a the commit gate reads the tracked changes too" {
  local c
  go_wt
  staged src/sum.js
  git -C "$W" commit -q -m 'feat: sum'
  printf 'export const sum = (a, b) => Math.round((a + b) * 100) / 100;\n' > "$W/src/sum.js"
  # Unstaged, the change is no part of a plain commit.
  commit "git commit -m 'feat: round sum'"
  commit_passed
  for c in "git commit -a -m 'feat: round sum'" "git commit --all -m 'feat: round sum'" "git commit -am 'feat: round sum'"; do
    commit "$c"
    commit_denied src/sum.js || { echo "for: $c"; return 1; }
  done
}

@test "a git fault in the commit gate allows" {
  go_wt
  staged src/sum.js
  read_fails git '--cached'
  commit "git commit -m 'feat: round sum'"
  commit_passed
  [ "$(read_failures git)" -ge 1 ]
}
