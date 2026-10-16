### Task 32: The 0.2.1 minor findings

**Files:**
- Modify: `hooks/prompt-submit` (`natural`), `tests/fixtures/mode-activation/cases.json`, `tests/hooks/prompt-submit.bats`, `tests/helpers/common.bash`, `tests/hooks/pre-tool-use.bats`, `tests/skills-control.test.mjs`, `skills/mode/SKILL.md`, `CHANGELOG.md`

**Interfaces:**
- Consumes: the 0.2.1 review's Minors 1 to 4 and the ruling that sends them here: a length cap before the sed loop, rejecting rather than truncating; `need_lists_match` fails on any non-canonical hooks/lib source line; doc wording; the phrases "terse voice" and "terse mode on" and whitespace folding.
- Produces: `natural` returns without switching when the first non-blank line is over 200 characters (no phrase is that long, and the ending loop is quadratic: 30 KB of " ." took 10.3 s under BSD sed); it folds runs of blanks to one space before matching; `terse voice` and `terse mode on` switch voice on. `tests/helpers/common.bash` gains `hook_file HOOK` and `odd_lib_sources HOOK`, and `need_lists_match` fails when a hook loads a hooks/lib file in any form but the column-0 `. "$KERN_ROOT/hooks/lib/X.sh"` its other checks read.

- [ ] **Step 1: Write the failing tests**

Append these cases to the array in `tests/fixtures/mode-activation/cases.json`:

```json
  { "prompt": "terse voice", "expect": "on", "known_failing": false },
  { "prompt": "terse mode on", "expect": "on", "known_failing": false },
  { "prompt": "go   terse", "expect": "on", "known_failing": false },
  { "prompt": "back  to\tnormal", "expect": "off", "known_failing": false },
  { "prompt": "use terse voice for the logger", "expect": "none", "known_failing": false }
```

Append to `tests/hooks/prompt-submit.bats`:

```bash
@test "a first line over 200 characters never switches and returns at once" {
  long="go terse$(printf ' .%.0s' $(seq 1 15000))"
  printf 'voice: normal\nsurface: auto\nautopilot: off\n' >"$CLAUDE_PLUGIN_DATA/sessions/test-session.state"
  start=$SECONDS
  printf '{"session_id":"test-session","cwd":"%s","hook_event_name":"UserPromptSubmit","prompt":"%s"}' "$CWD" "$long" |
    bash "$(kern_root)/hooks/prompt-submit" >/dev/null
  [ $((SECONDS - start)) -le 3 ]
  [ "$(st voice)" = normal ]
}
```

Append to `tests/hooks/pre-tool-use.bats`:

```bash
@test "need_lists_match fails on a library loaded in a form it cannot read" {
  for line in '  . "$KERN_ROOT/hooks/lib/json.sh"' 'source "$KERN_ROOT/hooks/lib/json.sh"' 'for l in json; do . "$KERN_ROOT/hooks/lib/$l.sh"; done'; do
    { printf '%s\n' "$line"; cat "$K/hooks/pre-tool-use"; } > "$BATS_TEST_TMPDIR/pre-tool-use"
    run need_lists_match "$BATS_TEST_TMPDIR/pre-tool-use"
    [ "$status" -eq 1 ] || { echo "accepted: $line"; return 1; }
    [[ "$output" == *"in a form these checks cannot read"* ]] || false
  done
}
```

Append to `tests/skills-control.test.mjs` (Minor 3, the doc wording):

```js
test('mode documents the switch phrases the hook accepts', () => {
  const { body } = read('mode');
  assert.match(body, /only when it stands alone on the prompt's first non-blank line/);
  assert.match(body, /a line over 200 characters never does\./);
  assert.match(body, /^- terse voice: .*"terse on", "terse voice", "terse mode on"/m);
});
```

- [ ] **Step 2: Run them to verify they fail**

Run: `tests/run-bats tests/hooks/prompt-submit.bats tests/hooks/pre-tool-use.bats; node --test tests/skills-control.test.mjs`
Expected: the corpus test fails on the four new switching cases; the 200-character test fails on time (about 10 s); the need-list test fails (`need_lists_match` reads a path argument as a hook name and accepts the extra line); the mode wording test fails on its first assertion.

- [ ] **Step 3: Cap and fold in `natural`**

In `hooks/prompt-submit`, replace the comment above `natural` and the function's first statement (the `p=$(printf ... | sed -E ...)` pipeline) with:

```bash
# natural PROMPT: switches only when the first non-blank line, lowercased, trimmed and with its runs of
# blanks folded to one space, is a switch phrase and nothing else, apart from a leading "please", "ok"
# or "okay" and any trailing mix of "please", "now" and final . or !. A phrase that ends in "terse" or
# "normal" may add " mode". A line that holds anything more, such as "use terse, descriptive names",
# never switches, and neither does a line over 200 characters: no phrase is that long, and the ending
# loop below is quadratic in a long run of strippable endings.
natural() {
  local p
  p=$(printf '%s\n' "$1" | sed -n '/[^[:space:]]/{p;q;}')
  [ "${#p}" -le 200 ] || return 0
  p=$(printf '%s\n' "$p" | lower |
    sed -E -e 's/[[:space:]]+/ /g; s/^ //; s/ $//' -e ':a' -e 's/ ?[.!]+$//; s/,? (please|now)$//' -e 'ta' \
      -e 's/^(please|ok|okay),? //; s/(^| )(terse|normal) mode$/\1\2/')
```

and extend the first `case` pattern list with `| "terse voice" | "terse mode on"`:

```bash
    terse | "go terse" | "be terse" | "use terse" | "enable terse" | "turn on terse" | "activate terse" | "switch to terse" | "terse on" | \
      "terse voice" | "terse mode on")
```

- [ ] **Step 4: Make `need_lists_match` strict**

In `tests/helpers/common.bash`, replace the block from `# need_list HOOK LIB:` through the end of `need_lists_match` with:

```bash
# hook_file HOOK: hooks/HOOK in the repo, or HOOK itself when it is a path (a test's modified copy).
hook_file() {
  case "$1" in */*) printf '%s\n' "$1" ;; *) printf '%s/hooks/%s\n' "$(kern_root)" "$1" ;; esac
}

# need_list HOOK LIB: the functions that HOOK's `need LIB ...` lines name, sorted, one per line.
need_list() {
  awk -v l="$2" '$1 == "need" && $2 == l { for (i = 3; i <= NF; i++) print $i }' "$(hook_file "$1")" | sort
}

# lib_functions LIB: the functions hooks/lib/LIB defines with `name() {`, sorted, one per line.
lib_functions() {
  sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)() {.*/\1/p' "$(kern_root)/hooks/lib/$1" | sort
}

# hook_libs HOOK: the libraries HOOK sources with a `. "$KERN_ROOT/hooks/lib/X.sh"` line.
hook_libs() {
  sed -n 's|^\. "\$KERN_ROOT/hooks/lib/\([A-Za-z0-9_-]*\.sh\)".*|\1|p' "$(hook_file "$1")"
}

# odd_lib_sources HOOK: lines that load a hooks/lib file in any form but the column-0
# `. "$KERN_ROOT/hooks/lib/X.sh"` that hook_libs reads (indented, `source`, a loop, a variable path).
odd_lib_sources() {
  grep -nE '(^|[;&|[:space:]])(\.|source)[[:space:]].*hooks/lib/' "$(hook_file "$1")" |
    grep -vE '^[0-9]+:\. "\$KERN_ROOT/hooks/lib/[A-Za-z0-9_-]+\.sh"' || true
}

# need_lists_match HOOK: HOOK loads its libraries only in the form hook_libs reads, has need lines for
# exactly those libraries, and each library's need lines name exactly the functions it defines. Prints
# the difference otherwise.
need_lists_match() {
  local libs lib odd
  odd=$(odd_lib_sources "$1")
  [ -z "$odd" ] || { echo "$1 loads a hooks/lib file in a form these checks cannot read: $odd"; return 1; }
  libs=$(hook_libs "$1")
  [ -n "$libs" ] || { echo "$1 has no source line for a hooks/lib library"; return 1; }
  [ "$(printf '%s\n' "$libs" | sort)" = "$(awk '$1 == "need" { print $2 }' "$(hook_file "$1")" | sort -u)" ] ||
    { echo "$1: its need lines and its source lines name different libraries"; return 1; }
  for lib in $libs; do
    [ -n "$(lib_functions "$lib")" ] || { echo "$lib defines no functions"; return 1; }
    [ "$(need_list "$1" "$lib")" = "$(lib_functions "$lib")" ] ||
      { echo "$1, $lib: need list differs from its definitions"; diff <(need_list "$1" "$lib") <(lib_functions "$lib"); return 1; }
  done
}

```

- [ ] **Step 5: Fix the doc wording**

In `skills/mode/SKILL.md`, replace the paragraph that starts "A phrase below also switches" with:

```markdown
A phrase below also switches, without this skill, only when it stands alone on the prompt's first non-blank line: put the phrase alone on that line, or type `/kern:mode`. A leading "please", "ok" or "okay" (with or without a comma), any trailing mix of "please" and "now", one or more final "." or "!", extra spaces between words, and "mode" after "terse" or "normal" are allowed; with anything else on the line, as in "go terse and fix the bug", nothing switches, and a line over 200 characters never does.
```

On the line that starts `- terse voice:`, add `"terse voice"` and `"terse mode on"` after `"terse on"`.
Add under `## [Unreleased]` in `CHANGELOG.md`: `- Mode switches: "terse voice" and "terse mode on" switch; extra spaces are folded; a first line over 200 characters never switches.`

- [ ] **Step 6: Run the tests to verify they pass**

Run: `node --test tests/skills-control.test.mjs && tests/run-bats tests/hooks/prompt-submit.bats tests/hooks/pre-tool-use.bats tests/hooks/session-start.bats && shellcheck -x -S warning hooks/prompt-submit tests/helpers/common.bash && node scripts/lint-skills.mjs`
Expected: every test passes (the corpus now 205 cases); shellcheck prints nothing; no lint errors.

- [ ] **Step 7: Commit**

```bash
git add -- hooks/prompt-submit tests/fixtures/mode-activation/cases.json tests/hooks/prompt-submit.bats tests/helpers/common.bash tests/hooks/pre-tool-use.bats tests/skills-control.test.mjs skills/mode/SKILL.md CHANGELOG.md
git commit -m "M2: close the 0.2.1 minor findings" -m "A 30 KB first line could outrun the 10 s prompt hook; the need-list check skipped libraries loaded any other way; two natural phrases and runs of spaces did not switch."
```

---

