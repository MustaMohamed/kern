### Task 14: Guard G20, approvals that quote the user

**Files:**
- Create: `hooks/guards/g20-approval.sh`
- Modify: `hooks/lib/state.sh` (append `prompt_hashes`), `hooks/prompt-submit` (record the hashes), `hooks/pre-tool-use` (`KERN_GUARD_IDS`, one `need` line), `hooks/session-start` (one `need` line), `CHANGELOG.md`
- Test: `tests/hooks/g20.bats`

**Interfaces:**
- Consumes (M1): `state_set`, `state_get`, `state_file` (state.sh); `ti_get`, `json_get_raw` (json.sh); `git_words`, `_shell_words` (gitctx.sh); `vote`, `fail_closed`; the dispatcher's `TOOL`, `CWD`, `SID`, `KERN_MAIN`, `AUTOPILOT`; `wrapped` in prompt-submit.
- Produces:
  - `prompt_hashes` (state.sh): reads text on stdin; prints, space-separated, one hash per non-blank line of up to 500 characters (the first 20 such lines), after lowercasing, folding blanks to one space, trimming and dropping a final run of `.` and `!`.
  - Session state key `prompt_hashes: <hashes>`, rewritten by prompt-submit on every user prompt that is not wrapped (a task notification, a cross-session, teammate, channel or agent message, or a scheduled task records nothing). G16 already denies any tool write to the state file.
  - `guard_g20`: on a Write or Edit of any Markdown file (`.md`, `.markdown`) whose frontmatter, as the file will be after the call, sets `status: approved` (bare or quoted), unless the file already had that status with the same `approved:` line; so it also checks an Edit that changes the `approved:` line of an approved file. For an Edit the post-edit text is built from the file, `old_string`, `new_string` and `replace_all` (pre-flight 1 #2: G20 read only `new_string`, so an Edit of `draft` to `approved`, or a second Edit of the `approved:` line, got no vote). The scope is every Markdown file, not only `WORK/specs/` and `WORK/plans/`, because a project's own spec system may keep plans under `docs/` (pre-flight 1 #7, ruling). Then: deny under autopilot; deny when no `approved:` line with a double-quoted quote is in the new text or the file; deny when the quote, normalized, is on the non-answer list (`sounds good`, `whatever you think`, `whatever`, `up to you`, `your call`, `you decide`, `i guess`, `maybe`, `not sure`, `looks fine i guess`); deny when its hash is not among the user's last prompt's hashes; deny when the file is newer than the state file (the draft changed after that prompt). On a Bash command: deny when one of its simple commands writes a Markdown file (a redirect; every `.md` argument of `sed -i`, `perl -i`, `awk` or `gawk -i inplace`, `ed`, `ex`, `tee` or `truncate`; `dd of=`; the last argument of `cp`, `mv` or `install`; any `.md` argument of a script interpreter when the command holds `approved`) and the command holds the word `approved`, or the target is approved now, or a `cp`, `mv` or `install` source is an approved Markdown file. G20 never votes allow. Accepted limits: a write that hides both the path and the word, such as a script file run by name or an awk program that builds the word, is not seen; G20 may ask about an unrelated Markdown file that sets `status: approved` (the ruling's stated cost); `ledger-open` still refuses a plan with no quoted approval, and accepts one at any path because G20 now guards them all.

- [ ] **Step 1: Write the failing tests**

```bash
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

# approve QUOTE [PATH]: an Edit that sets status: approved with an approved: line quoting QUOTE.
approve() {
  run_guard "$(tool_payload Edit "\"file_path\":\"${2:-$SPEC}\",\"old_string\":\"status: draft\",\"new_string\":\"status: approved\\ndate: 2026-10-14\\napproved: 2026-10-14, \\\"$1\\\"\"")" g20
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

@test "a quote from an earlier message, or from a wrapped one, is denied" {
  say 'yes'
  say 'now add the CSV header row'
  approve 'yes'
  [ "$(decision_of "$output")" = deny ]
  say '<task-notification>yes</task-notification>'
  approve 'now add the CSV header row'
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
  [[ "$output" == *"under autopilot nothing approves"* ]] || false
}

@test "other files and draft edits get no G20 vote" {
  say 'no'
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run-bats tests/hooks/g20.bats`
Expected: the deny tests, the `prompt_hashes` test and the dispatcher-list test fail; the no-vote tests pass.

- [ ] **Step 3: Append `prompt_hashes` to `hooks/lib/state.sh`**

```bash
# prompt_hashes: reads text on stdin and prints, space-separated, one hash per non-blank line of up to
# 500 characters (the first 20 such lines). A line is lowercased, its blanks folded to one space and
# trimmed, and a final run of . and ! dropped, so "Yes, approved!" and "yes,  approved" hash the same.
# G20 hashes an approved: quote the same way and looks for it among the user's last prompt's hashes.
prompt_hashes() {
  LC_ALL=C awk '
    BEGIN { for (i = 1; i < 256; i++) ord[sprintf("%c", i)] = i }
    {
      s = tolower($0); gsub(/[ \t\r]+/, " ", s); sub(/^ /, "", s); sub(/ $/, "", s); sub(/[.!]+$/, "", s)
      if (s == "" || length(s) > 500 || ++n > 20) next
      h = 5381
      for (i = 1; i <= length(s); i++) h = (h * 33 + ord[substr(s, i, 1)]) % 4294967296
      out = out (out == "" ? "" : " ") sprintf("%.0f", h)
    }
    END { print out }'
}
```

Every library function needs a `need` entry in each hook that checks it (`need_lists_match`, M1 0.2.1). In `hooks/pre-tool-use` and in `hooks/session-start`, add this line right after the existing `need state.sh state_dir ...` line:

```bash
need state.sh prompt_hashes
```

- [ ] **Step 4: Record the user's lines in `hooks/prompt-submit`**

In the `else` branch (UserPromptSubmit), right after the block that clears `TRIM` for a wrapped prompt (the `if wrapped "$TRIM"; then ... fi` block), insert:

```bash
  # The user's own words, hashed line by line, so G20 can check an approved: quote against them. A
  # wrapped prompt is not the user's and records nothing.
  [ -n "$TRIM" ] && state_set "$SID" "prompt_hashes=$(printf '%s\n' "$TRIM" | prompt_hashes)"
```

- [ ] **Step 5: Write `hooks/guards/g20-approval.sh`**

```bash
# shellcheck shell=bash
# shellcheck disable=SC2154  # TOOL, CWD, SID and AUTOPILOT are set by hooks/pre-tool-use
# G20 approval: a Markdown file (a spec or plan under the work dir, or the project's own spec system
# under docs/) becomes `status: approved`, or changes the approved: line of an approved file, only on
# the user's own words. The check reads the file as it will be after the Write or Edit, so splitting
# the change over two edits does not get past it. The approved: line must quote one whole line of the
# user's last message, verbatim, that is not a non-answer such as "sounds good", and the file must be
# older than that message. prompt-submit records the message's line hashes in the session state, which
# G16 protects. Under autopilot nothing approves.
_G20_NOT_YES=" sounds good | whatever you think | whatever | up to you | your call | you decide | i guess | maybe | not sure | looks fine i guess "

# _G20_FM_AWK: prints the frontmatter (the lines between a first line --- and the next ---) of the text
# it reads, after replacing ENVIRON G20_OLD with G20_NEW: the first match, or every match when G20_ALL
# is true. An empty G20_OLD replaces nothing. A trailing CR is dropped from each line.
# shellcheck disable=SC2016 # awk text
_G20_FM_AWK='
{ t = t $0 "\n" }
END {
  o = ENVIRON["G20_OLD"]
  if (o != "") {
    out = ""; r = t
    while ((i = index(r, o)) > 0) {
      out = out substr(r, 1, i - 1) ENVIRON["G20_NEW"]; r = substr(r, i + length(o))
      if (ENVIRON["G20_ALL"] != "true") break
    }
    t = out r
  }
  n = split(t, L, "\n")
  for (k = 1; k <= n; k++) sub(/\r$/, "", L[k])
  if (L[1] != "---") exit
  for (k = 2; k <= n && L[k] != "---"; k++) print L[k]
}'

# _g20_approved FRONTMATTER: exit 0 when FRONTMATTER sets status: approved (bare or quoted).
_g20_approved() {
  printf '%s\n' "$1" | grep -Eq "^status:[[:space:]]*[\"']?approved[\"']?[[:space:]]*\$"
}

# _g20_line FRONTMATTER: prints the value of its first approved: line.
_g20_line() {
  printf '%s\n' "$1" | sed -n 's/^approved:[[:space:]]*//p' | head -n 1
}

# _g20_md PATH: exit 0 when PATH names a Markdown file.
_g20_md() {
  case "$1" in *.md | *.MD | *.markdown) return 0 ;; esac
  return 1
}

# _g20_front FILE: the frontmatter of FILE as it is now; nothing when FILE is not a readable file.
_g20_front() {
  [ -f "$1" ] && [ -r "$1" ] || return 0
  LC_ALL=C awk "$_G20_FM_AWK" "$1" 2> /dev/null
}

guard_g20() {
  case "$TOOL" in
    Write | Edit) _g20_file ;;
    Bash) _g20_bash ;;
  esac
}

_g20_file() {
  local p text old new all before after approved quote qh hashes sf norm
  p=$(ti_get file_path) || return 0
  _g20_md "$p" || return 0
  case "$p" in /*) ;; *) p="${CWD:-$PWD}/$p" ;; esac
  before=$(_g20_front "$p")
  if [ "$TOOL" = Write ]; then
    # $( ) drops trailing newlines; the x keeps them, as the replacement in Edit needs them.
    text=$(ti_get content && printf x) || return 0
    after=$(printf '%s' "${text%x}" | LC_ALL=C awk "$_G20_FM_AWK")
  else
    [ -f "$p" ] || return 0
    old=$(ti_get old_string && printf x) || return 0
    new=$(ti_get new_string && printf x) || return 0
    all=$(KERN_INPUT="${TOOL_INPUT-}" json_get_raw replace_all 2> /dev/null) || all=false
    after=$(G20_OLD="${old%x}" G20_NEW="${new%x}" G20_ALL="$all" LC_ALL=C awk "$_G20_FM_AWK" "$p") ||
      { fail_closed "G20 could not read the Edit of $(basename "$p") for an approval"; return 0; }
  fi
  _g20_approved "$after" || return 0
  approved=$(_g20_line "$after")
  # An approved file whose approved: line stays the same is not being approved now.
  if _g20_approved "$before" && [ "$(_g20_line "$before")" = "$approved" ]; then return 0; fi
  if [ "${AUTOPILOT:-0}" = 1 ]; then
    vote deny G20 "under autopilot nothing approves a spec or plan; keep status: draft (parked under autopilot) and park the question"
    return 0
  fi
  quote=$(printf '%s' "$approved" | sed -n 's/^[^"]*"\([^"]*\)".*/\1/p')
  if [ -z "$quote" ]; then
    vote deny G20 "status: approved needs an approved: line with the date and the user's words in double quotes, in the same edit"
    return 0
  fi
  norm=$(printf '%s\n' "$quote" | LC_ALL=C tr '[:upper:]' '[:lower:]' | sed -e 's/[[:space:]][[:space:]]*/ /g' -e 's/^ //' -e 's/ $//' -e 's/[.!]*$//')
  case "$_G20_NOT_YES" in
    *" $norm "*) vote deny G20 "\"$quote\" is not an explicit yes; ask the user for one"; return 0 ;;
  esac
  qh=$(printf '%s\n' "$quote" | prompt_hashes)
  hashes=$(state_get "$SID" prompt_hashes 2> /dev/null) || hashes=''
  case " $hashes " in
    *" $qh "*) ;;
    *) vote deny G20 "the approved: quote is not a line of the user's last message; quote one whole line of it verbatim, or ask for a yes"; return 0 ;;
  esac
  sf=$(state_file "$SID" 2> /dev/null) || sf=''
  if [ -f "$p" ] && [ -n "$sf" ] && [ "$p" -nt "$sf" ]; then
    vote deny G20 "$(basename "$p") changed after the user's last message; show the draft again and get a fresh yes"
  fi
}

# _g20_targets WORDS: the Markdown files a simple command (its words, one per line) writes: a redirect
# target; every .md argument of sed -i, perl -i, awk or gawk -i inplace, ed, ex, tee and truncate, or of
# a script interpreter (python, node, ruby, sh) when APPROVED is 1; dd's of=; the last argument of cp,
# mv and install.
_g20_targets() {
  local words="$1" first all
  first=$(printf '%s\n' "$words" | head -n 1)
  first=${first##*/}
  all=" $(printf '%s\n' "$words" | tr '\n' ' ')"
  printf '%s\n' "$words" | awk 'f { print; f = 0; next } /^[0-9]*>>?$/ { f = 1; next } /^[0-9]*>>?./ { sub(/^[0-9]*>>?/, ""); print }'
  case "$first" in
    sed | perl) case "$all" in *' -i'* | *' --in-place'*) printf '%s\n' "$words" | sed '1d' ;; esac ;;
    awk | gawk) case "$all" in *' -i inplace '* | *' -iinplace '* | *' --include=inplace '* | *' --include inplace '*) printf '%s\n' "$words" | sed '1d' ;; esac ;;
    ed | ex | tee | truncate) printf '%s\n' "$words" | sed '1d' ;;
    dd) printf '%s\n' "$words" | sed -n 's/^of=//p' ;;
    cp | mv | install) printf '%s\n' "$words" | sed '1d' | grep -v '^-' | tail -n 1 ;;
    python | python3 | node | ruby | sh | bash | zsh) [ "$APPROVED" = 1 ] && printf '%s\n' "$words" | sed '1d' ;;
  esac
}

# _g20_bash: a shell command that writes a Markdown file could set or change an approval without the
# quote check. It is denied when one of its simple commands writes a .md file (see _g20_targets) and
# the command holds the word approved, or the target is approved now, or a cp, mv or install source is
# an approved Markdown file.
_g20_bash() {
  local cmd line words first t s APPROVED=0
  cmd=$(ti_get command) || return 0
  case "$cmd" in *.md* | *.MD* | *.markdown*) ;; *) return 0 ;; esac
  case "$cmd" in *approved*) APPROVED=1 ;; esac
  while IFS= read -r line; do
    line=$(printf '%s' "$line" | sed -e 's/[0-9]*>&[0-9]//g' -e 's#[0-9]*>[[:space:]]*/dev/null##g' -e 's/^[[:space:]]*//')
    [ -n "$line" ] || continue
    words=$(_shell_words "$line")
    first=$(printf '%s\n' "$words" | head -n 1)
    first=${first##*/}
    while IFS= read -r t; do
      _g20_md "$t" || continue
      case "$t" in /*) ;; *) t="${CWD:-$PWD}/$t" ;; esac
      if [ "$APPROVED" = 1 ] || _g20_approved "$(_g20_front "$t")"; then
        vote deny G20 "set or change an approval with the Edit or Write tool, so kern can check the user's quote"
        return 0
      fi
      case "$first" in
        cp | mv | install)
          while IFS= read -r s; do
            case "$s" in /*) ;; *) s="${CWD:-$PWD}/$s" ;; esac
            if _g20_approved "$(_g20_front "$s")"; then
              vote deny G20 "copying an approved Markdown file onto $(basename "$t") skips the quote check; set the approval with the Edit or Write tool"
              return 0
            fi
          done <<SRC
$(printf '%s\n' "$words" | sed '1d' | grep -v '^-' | sed '$d')
SRC
          ;;
      esac
    done <<TGT
$(_g20_targets "$words")
TGT
  done <<CMD
$(git_words "$cmd")
CMD
  return 0
}
```

- [ ] **Step 6: Add the id to the dispatcher**

In `hooks/pre-tool-use`, set:

```bash
KERN_GUARD_IDS="g00 g01 g02 g03 g04 g05 g06 g13 g14 g15 g16 g18 g20"
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `tests/run-bats tests/hooks/g20.bats tests/hooks/pre-tool-use.bats tests/hooks/session-start.bats tests/hooks/prompt-submit.bats tests/hooks/g16-state.bats && shellcheck -x -S warning hooks/guards/g20-approval.sh hooks/lib/state.sh hooks/prompt-submit`
Expected: g20.bats's 20 tests and every test in the other four files pass (bats prints one total for all five; the need-list tests see `prompt_hashes`); shellcheck prints nothing.

- [ ] **Step 8: Update the changelog and commit**

Add under `## [Unreleased]` in `CHANGELOG.md`: `- Guard G20: a Markdown spec or plan becomes approved, or changes its approved: line, only with a quote of the user's last message, judged on the file as the edit leaves it; never under autopilot.`

```bash
git add -- hooks/guards/g20-approval.sh hooks/lib/state.sh hooks/prompt-submit hooks/pre-tool-use hooks/session-start tests/hooks/g20.bats CHANGELOG.md
git commit -m "M2: add guard G20 so only the user's words approve a spec or plan" -m "Approval was a line Claude wrote; now its quote must match a line of the user's last message, so an invented yes or a sounds-good cannot unlock plan or execute-plan."
```

---

