### Task 11: G2 PR create, G3 review posting, G4 untrusted text

**Files:**
- Create: `hooks/guards/g02-pr.sh`, `hooks/guards/g03-review.sh`, `hooks/guards/g04-untrusted.sh`
- Test: `tests/hooks/g02-g04-gh.bats`

**Interfaces:**
- Consumes: `gh_sub`, `word_has`, `word_value`, `with_timeout`, `policy_for pr`, `policy_for review.post`, `settings_get review.taxonomy`; `fake_gh` from `tests/helpers/common.bash`.
- Produces: `guard_g02`, `guard_g03`, `guard_g04`. G2: non-draft `gh pr create` denied; duplicate check with `gh pr list --head <head> --state all` (10 s timeout): open PR denied, merged or closed PR asks, gh unavailable asks; a clean draft follows `pr.policy` and is allowed under autopilot; `gh pr ready` asks, deny under autopilot. G3: self-approval denied; a `gh pr review` body file and every `body` in a `gh api .../reviews|comments --input` file must open with a `review.taxonomy` label; posting follows `review.post_policy`, denied under autopilot; a Skill call to `code-review` with `--comment` asks, and `--fix` in the main checkout asks. G4: `--body`/`-b`/`--body=` on `gh pr|issue|release` and `body=` fields on `gh api` are denied in both modes.

- [ ] **Step 1: Write the failing test**

`tests/hooks/g02-g04-gh.bats`:
```bash
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run-bats tests/hooks/g02-g04-gh.bats`
Expected: FAIL; every case that expects a vote gets `none`.

- [ ] **Step 3: Write `hooks/guards/g02-pr.sh`**

```bash
# shellcheck shell=bash
# G2 PR create: drafts only, no duplicate PR for a head, `gh pr ready` stays human under autopilot.

guard_g02() {
  [ "$TOOL" = Bash ] || return 0
  local cmd seg
  cmd=$(ti_get command) || return 0
  while IFS= read -r seg; do
    case "$(gh_sub "$seg")" in
      "pr create") _g02_create "$seg" ;;
      "pr ready")
        word_has "$(_shell_words "$seg")" --undo && continue
        vote ask G2 "gh pr ready marks a PR ready for review"
        [ "$AUTOPILOT" = 1 ] && vote deny G2 "gh pr ready under autopilot: drafts only"
        ;;
    esac
  done <<EOT
$(git_words "$cmd")
EOT
}

# _g02_states HEAD: states of PRs whose head is HEAD, one per line. Exit 2 when gh cannot answer.
_g02_states() {
  command -v gh >/dev/null 2>&1 || return 2
  (cd "$CWD" 2>/dev/null && with_timeout 10 gh pr list --head "$1" --state all --json state --jq '.[].state') 2>/dev/null || return 2
}

_g02_create() {
  local words head states policy
  words=$(_shell_words "$1")
  if ! word_has "$words" --draft -d; then
    vote deny G2 "open PRs as drafts: add --draft"
    return 0
  fi
  head=$(word_value "$words" --head -H) || head=$(current_branch "$CWD")
  if ! states=$(_g02_states "$head"); then
    vote ask G2 "could not check for an existing PR on $head (gh unavailable)"
    return 0
  fi
  case "$states" in
    *OPEN*) vote deny G2 "a PR is already open for $head; report it instead of opening another"; return 0 ;;
    *MERGED* | *CLOSED*) vote ask G2 "a merged or closed PR already exists for $head"; return 0 ;;
  esac
  if [ "$AUTOPILOT" = 1 ]; then
    vote allow G2 "autopilot: draft PR for $head after dedup"
    return 0
  fi
  policy=$(policy_for pr)
  case "$policy" in
    auto) vote allow G2 "pr.policy auto: draft PR for $head" ;;
    deny) vote deny G2 "pr.policy deny" ;;
    *) vote ask G2 "open a draft PR for $head" ;;
  esac
}
```

- [ ] **Step 4: Write `hooks/guards/g03-review.sh`**

```bash
# shellcheck shell=bash
# G3 review posting: no self-approval, findings carry a taxonomy label, posting asks.

guard_g03() {
  case "$TOOL" in
    Skill) _g03_skill; return 0 ;;
    Bash) ;;
    *) return 0 ;;
  esac
  local cmd seg
  cmd=$(ti_get command) || return 0
  while IFS= read -r seg; do
    case "$(gh_sub "$seg")" in
      "pr review") _g03_review "$seg" ;;
      "pr comment") _g03_post "gh pr comment" ;;
      api*)
        case "$seg" in
          *"/reviews"* | *"/comments"*) _g03_api "$seg" ;;
        esac
        ;;
    esac
  done <<EOT
$(git_words "$cmd")
EOT
}

# The built-in code-review skill: --comment posts at once; --fix edits the tree it runs in.
_g03_skill() {
  case "$TOOL_INPUT" in *code-review*) ;; *) return 0 ;; esac
  case "$TOOL_INPUT" in
    *--comment*) vote ask G3 "code-review --comment posts findings to the PR immediately" ;;
  esac
  case "$TOOL_INPUT" in
    *--fix*) in_main_checkout "$CWD" && vote ask G3 "code-review --fix in the main checkout edits shared files" ;;
  esac
}

_g03_post() {
  if [ "$AUTOPILOT" = 1 ]; then
    vote deny G3 "$1 under autopilot: review posting stays human"
    return 0
  fi
  case "$(policy_for review.post)" in
    auto) vote allow G3 "review.post_policy auto: $1" ;;
    deny) vote deny G3 "review.post_policy deny" ;;
    *) vote ask G3 "$1 posts to the PR" ;;
  esac
}

# _g03_labelled FILE: the first non-empty line starts with a review.taxonomy label.
_g03_labelled() {
  local tax first rest label
  [ -f "$1" ] || return 1
  tax=$(settings_get review.taxonomy "blocker,should-fix,nit,pre-existing")
  first=$(sed -n '/[^[:space:]]/{p;q;}' "$1" | sed 's/^[[:space:]*#>-]*//' | tr '[:upper:]' '[:lower:]')
  rest="$tax,"
  while [ -n "$rest" ]; do
    label=${rest%%,*}; rest=${rest#*,}
    label=$(printf '%s' "$label" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')
    [ -n "$label" ] || continue
    case "$first" in "$label"*) return 0 ;; esac
  done
  return 1
}

_g03_review() {
  local words num me author file
  words=$(_shell_words "$1")
  if word_has "$words" --approve -a; then
    num=$(printf '%s\n' "$words" | awk 'f && /^[0-9]+$/ { print; exit } $0 == "review" { f = 1 }')
    if command -v gh >/dev/null 2>&1 &&
      me=$( (cd "$CWD" && with_timeout 10 gh api user --jq .login) 2>/dev/null) &&
      author=$( (cd "$CWD" && with_timeout 10 gh pr view ${num:+"$num"} --json author --jq .author.login) 2>/dev/null) &&
      [ -n "$me" ] && [ "$me" = "$author" ]; then
      vote deny G3 "self-approval: use a COMMENT review on your own PR"
      return 0
    fi
    _g03_post "gh pr review --approve"
    return 0
  fi
  file=$(word_value "$words" --body-file -F) || file=""
  if [ -n "$file" ]; then
    case "$file" in /*) ;; *) file="$CWD/$file" ;; esac
    if ! _g03_labelled "$file"; then
      vote deny G3 "review body must open with a review.taxonomy label ($(settings_get review.taxonomy "blocker,should-fix,nit,pre-existing"))"
      return 0
    fi
  fi
  _g03_post "gh pr review"
}

_g03_api() {
  local words file tax b ok=1
  words=$(_shell_words "$1")
  if ! word_has "$words" -f -F --field --raw-field --input &&
    [ "$(word_value "$words" -X --method 2>/dev/null)" != POST ]; then
    return 0
  fi
  file=$(word_value "$words" --input) || file=""
  if [ -n "$file" ]; then
    case "$file" in /*) ;; *) file="$CWD/$file" ;; esac
    tax=$(settings_get review.taxonomy "blocker,should-fix,nit,pre-existing" | tr '[:upper:]' '[:lower:]')
    while IFS= read -r b; do
      [ -n "$b" ] || continue
      b=$(printf '%s' "$b" | tr '[:upper:]' '[:lower:]' | sed 's/^[*#> -]*//; s/[^a-z-].*//')
      list_has "$tax" "$b" || ok=0
    done <<EOT
$(grep -o '"body"[[:space:]]*:[[:space:]]*"[^"]*' "$file" 2>/dev/null | sed 's/^"body"[[:space:]]*:[[:space:]]*"//')
EOT
    if [ "$ok" = 0 ]; then
      vote deny G3 "every review comment body must open with a review.taxonomy label"
      return 0
    fi
  fi
  _g03_post "gh api review or comment post"
}
```

- [ ] **Step 5: Write `hooks/guards/g04-untrusted.sh`**

```bash
# shellcheck shell=bash
# G4 untrusted text: PR, issue and review text goes through a file, never inline in the command.

guard_g04() {
  [ "$TOOL" = Bash ] || return 0
  local cmd seg words w
  cmd=$(ti_get command) || return 0
  while IFS= read -r seg; do
    case "$(gh_sub "$seg")" in
      "pr "* | "issue "* | "release "*)
        words=$(_shell_words "$seg")
        if word_has "$words" --body -b || printf '%s\n' "$words" | grep -q '^--body='; then
          vote deny G4 "pass PR, issue and review text with --body-file <file>, not inline"
        fi
        ;;
      api*)
        words=$(_shell_words "$seg")
        while IFS= read -r w; do
          case "$w" in
            body=* | -fbody=* | -Fbody=*) vote deny G4 "send gh api bodies with --input <file>, not -f body="; break ;;
          esac
        done <<EOT
$words
EOT
        ;;
    esac
  done <<EOT
$(git_words "$cmd")
EOT
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `tests/run-bats tests/hooks/g02-g04-gh.bats`
Expected: `12 tests, 0 failures`, in under 30 seconds (a longer run means `with_timeout` is waiting on its watchdog; recheck Task 9 Step 4).

- [ ] **Step 7: Commit**

```bash
git add -- hooks/guards/g02-pr.sh hooks/guards/g03-review.sh hooks/guards/g04-untrusted.sh tests/hooks/g02-g04-gh.bats
git commit -m "M1: add G2, G3 and G4 for PRs, review posts and untrusted text" -m "PRs open as drafts after a duplicate check, review posts carry a label and need the user, and comment text never reaches a shell command line."
```

---

