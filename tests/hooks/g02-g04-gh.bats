#!/usr/bin/env bats
# G2 PR create, G3 review posting, G4 untrusted text. gh is a stub (helpers/common.bash fake_gh).

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  git -C "$R" switch -q -c feat
  kern_env "$R"
  fake_gh
}

g() { run_guard "$(bash_payload "$1")" "$2"; }

@test "G2: a non-draft PR is denied in both modes" {
  g "gh pr create --title x --body-file b.md" g02
  [ "$(decision_of "$output")" = deny ]
  set_autopilot on
  g "gh pr create --title x --body-file b.md" g02
  [ "$(decision_of "$output")" = deny ]
}

@test "G2: a draft with no existing PR asks; pr.policy auto allows; autopilot allows" {
  g "gh pr create --draft --title x --body-file b.md" g02
  [ "$(decision_of "$output")" = ask ]
  mkdir -p "$R/.claude"; printf 'pr.policy: auto\n' >"$R/.claude/kern.local.yml"
  g "gh pr create --draft --title x --body-file b.md" g02
  [ "$(decision_of "$output")" = allow ]
  rm "$R/.claude/kern.local.yml"
  set_autopilot on
  g "gh pr create --draft --title x --body-file b.md" g02
  [ "$(decision_of "$output")" = allow ]
}

@test "G2: an open PR for the head is denied; a merged one asks" {
  export FAKE_GH_STATES=OPEN
  g "gh pr create --draft --title x --body-file b.md" g02
  [ "$(decision_of "$output")" = deny ]
  export FAKE_GH_STATES=MERGED
  g "gh pr create --draft --title x --body-file b.md" g02
  [ "$(decision_of "$output")" = ask ]
}

@test "G2: gh failing means dedup unknown: ask, deny under autopilot" {
  export FAKE_GH_RC=1
  g "gh pr create --draft --title x --body-file b.md" g02
  [ "$(decision_of "$output")" = ask ]
  set_autopilot on
  g "gh pr create --draft --title x --body-file b.md" g02
  [ "$(decision_of "$output")" = deny ]
}

@test "G2: gh pr ready asks, denied under autopilot" {
  g "gh pr ready 12" g02
  [ "$(decision_of "$output")" = ask ]
  set_autopilot on
  g "gh pr ready 12" g02
  [ "$(decision_of "$output")" = deny ]
}

@test "G3: self-approval is denied; approving another author's PR asks" {
  export FAKE_GH_ME=me FAKE_GH_AUTHOR=me
  g "gh pr review 12 --approve" g03
  [ "$(decision_of "$output")" = deny ]
  export FAKE_GH_AUTHOR=someone
  g "gh pr review 12 --approve" g03
  [ "$(decision_of "$output")" = ask ]
}

@test "G3: a review body without a taxonomy label is denied; with one it asks" {
  printf 'Looks fine to me\n' >"$R/plain.md"
  printf '**Blocker**: null deref at a.ts:3\n' >"$R/labelled.md"
  g "gh pr review 12 --comment --body-file plain.md" g03
  [ "$(decision_of "$output")" = deny ]
  g "gh pr review 12 --comment --body-file labelled.md" g03
  [ "$(decision_of "$output")" = ask ]
}

@test "G3: every posting is denied under autopilot" {
  printf 'nit: rename\n' >"$R/labelled.md"
  set_autopilot on
  g "gh pr review 12 --comment --body-file labelled.md" g03
  [ "$(decision_of "$output")" = deny ]
  g "gh pr comment 12 --body-file labelled.md" g03
  [ "$(decision_of "$output")" = deny ]
}

@test "G3: gh api review post checks every body; a GET is not a post" {
  printf '{"comments":[{"body":"nit: a"},{"body":"bad"}]}' >"$R/review.json"
  g "gh api repos/o/r/pulls/12/reviews --input review.json" g03
  [ "$(decision_of "$output")" = deny ]
  printf '{"comments":[{"body":"Blocker: a"}]}' >"$R/review.json"
  g "gh api repos/o/r/pulls/12/reviews --input review.json" g03
  [ "$(decision_of "$output")" = ask ]
  g "gh api repos/o/r/pulls/12/comments" g03
  [ "$(decision_of "$output")" = none ]
}

@test "G3: code-review --comment through the Skill tool asks; plain code-review: no vote" {
  run_guard "$(payload PreToolUse '"tool_name":"Skill","tool_input":{"skill":"code-review","args":"main...feat --comment"}')" g03
  [ "$(decision_of "$output")" = ask ]
  run_guard "$(payload PreToolUse '"tool_name":"Skill","tool_input":{"skill":"code-review","args":"main...feat --max-findings 15"}')" g03
  [ "$(decision_of "$output")" = none ]
}

@test "G4: inline --body is denied; --body-file passes G4" {
  g "gh pr comment 12 --body hello" g04
  [ "$(decision_of "$output")" = deny ]
  g "gh issue create --title t --body=x" g04
  [ "$(decision_of "$output")" = deny ]
  g "gh pr comment 12 --body-file c.md" g04
  [ "$(decision_of "$output")" = none ]
}

@test "G4: gh api -f body= is denied" {
  g "gh api repos/o/r/issues/1/comments -f body=hello" g04
  [ "$(decision_of "$output")" = deny ]
}
