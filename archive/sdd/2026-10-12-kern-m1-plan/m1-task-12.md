### Task 12: G5 commit and G6 secrets

**Files:**
- Create: `hooks/guards/g05-commit.sh`, `hooks/guards/g06-secrets.sh`
- Test: `tests/hooks/g05-g06-commit.bats`

**Interfaces:**
- Consumes: `git_sub`, `_shell_words`, `word_has`, `current_branch`, `base_branch_name`, `policy_for commit`, `settings_get commit.convention|commit.id_from_branch|commit.attribution|never_commit`.
- Produces: `guard_g05`, `guard_g06`. G5: a message read from `-m`, `--message`, `-F`, `--file`, `-C`/`-c`, or `--amend --no-edit`; a message built by `$( )` or backticks, or an editor commit, asks (deny under autopilot); failed checks deny in both modes (attribution trailer while `commit.attribution: none`; subject not matching `commit.convention`; a ticket id in the branch name, by `commit.id_from_branch`, missing from the subject); passing commits follow `commit.policy` and are allowed under autopilot; `git add -A|--all|.|:/|-u|*` and `git commit -a` ask, deny under autopilot. G6: staged diff on commit (plus unstaged with `-a`), outgoing range on push (`@{u}..HEAD`, else `origin/<base>..HEAD`); added lines matched against six secret patterns, reported as `path:line rule` only; `gitleaks stdin` when installed; `never_commit` globs denied.

- [ ] **Step 1: Write the failing test**

`tests/hooks/g05-g06-commit.bats`:
```bash
#!/usr/bin/env bats
# G5 commit checks and G6 secret scan.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  git -C "$R" switch -q -c CDS-2465/replace-minio
  mkdir -p "$R/.claude"
  printf 'commit.convention: "^CDS-[0-9]+: "\n' >"$R/.claude/kern.local.yml"
  kern_env "$R"
}

g() { run_guard "$(bash_payload "$1")" "$2"; }

@test "G5: a passing -F message asks interactively and is allowed under autopilot" {
  printf 'CDS-2465: swap MinIO for Floci\n\nWhy.\n' >"$R/msg.txt"
  g "git commit -F msg.txt" g05
  [ "$(decision_of "$output")" = ask ]
  set_autopilot on
  g "git commit -F msg.txt" g05
  [ "$(decision_of "$output")" = allow ]
}

@test "G5: a subject off convention is denied in both modes" {
  printf 'swap MinIO\n' >"$R/msg.txt"
  g "git commit -F msg.txt" g05
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"commit.convention"* ]] || false
  set_autopilot on
  g "git commit -F msg.txt" g05
  [ "$(decision_of "$output")" = deny ]
}

@test "G5: a missing ticket id from the branch is denied" {
  printf 'commit.convention: ".*"\n' >"$R/.claude/kern.local.yml"
  g "git commit -m 'swap MinIO'" g05
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"CDS-2465"* ]] || false
}

@test "G5: an AI attribution trailer is denied unless commit.attribution allows it" {
  printf 'CDS-2465: swap\n\nClaude-Session: https://claude.ai/code/session_x\n' >"$R/msg.txt"
  g "git commit -F msg.txt" g05
  [ "$(decision_of "$output")" = deny ]
  printf 'commit.convention: "^CDS-[0-9]+: "\ncommit.attribution: allowed\n' >"$R/.claude/kern.local.yml"
  g "git commit -F msg.txt" g05
  [ "$(decision_of "$output")" = ask ]
}

@test "G5: a message built by command substitution cannot be checked: ask, deny under autopilot" {
  g "git commit -m \$(cat m.txt)" g05
  [ "$(decision_of "$output")" = ask ]
  set_autopilot on
  g "git commit -m \$(cat m.txt)" g05
  [ "$(decision_of "$output")" = deny ]
}

@test "G5: commit.policy auto allows a passing commit; deny denies it" {
  printf 'commit.convention: "^CDS-[0-9]+: "\ncommit.policy: auto\n' >"$R/.claude/kern.local.yml"
  g "git commit -m 'CDS-2465: swap'" g05
  [ "$(decision_of "$output")" = allow ]
  printf 'commit.policy: deny\n' >"$R/.claude/kern.local.yml"
  g "git commit -m 'CDS-2465: swap'" g05
  [ "$(decision_of "$output")" = deny ]
}

@test "G5: git add -A and commit -a ask, denied under autopilot; git add -- path: no vote" {
  g "git add -A" g05
  [ "$(decision_of "$output")" = ask ]
  g "git add ." g05
  [ "$(decision_of "$output")" = ask ]
  g "git add -- src/a.ts" g05
  [ "$(decision_of "$output")" = none ]
  set_autopilot on
  g "git add -A" g05
  [ "$(decision_of "$output")" = deny ]
  g "git commit -am 'CDS-2465: x'" g05
  [ "$(decision_of "$output")" = deny ]
}

@test "G6: a staged private key is denied without printing it" {
  printf -- '-----BEGIN RSA PRIVATE KEY-----\nMIIEsecret\n' >"$R/id_rsa"
  git -C "$R" add id_rsa
  g "git commit -m 'CDS-2465: key'" g06
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"id_rsa:1 private-key"* ]] || false
  [[ "$output" != *"MIIEsecret"* ]] || false
}

@test "G6: a clean staged change: no vote" {
  printf 'hello\n' >"$R/a.txt"
  git -C "$R" add a.txt
  g "git commit -m 'CDS-2465: a'" g06
  [ "$(decision_of "$output")" = none ]
}

@test "G6: never_commit paths are denied" {
  printf 'never_commit: *.db, .env*\n' >"$R/.claude/kern.local.yml"
  printf 'x\n' >"$R/data.db"
  git -C "$R" add data.db
  g "git commit -m 'CDS-2465: db'" g06
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"data.db"* ]] || false
}

@test "G6: a push scans the outgoing commits" {
  printf 'token = "ghp_abcdefghijklmnopqrstuvwxyz0123"\n' >"$R/cfg.txt"
  git -C "$R" add cfg.txt
  git -C "$R" commit -q -m "CDS-2465: cfg"
  g "git push -u origin CDS-2465/replace-minio" g06
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"cfg.txt:1 github-token"* ]] || false
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/run-bats tests/hooks/g05-g06-commit.bats`
Expected: FAIL; vote cases get `none`.

- [ ] **Step 3: Write `hooks/guards/g05-commit.sh`**

```bash
# shellcheck shell=bash
# G5 commit: message convention and attribution checks, explicit staging, commit.policy.

guard_g05() {
  [ "$TOOL" = Bash ] || return 0
  local cmd seg parsed dir sub rest
  cmd=$(ti_get command) || return 0
  while IFS= read -r seg; do
    parsed=$(git_sub "$seg") || continue
    dir=${parsed%%	*}
    rest=${parsed#*	}
    sub=${rest%%	*}
    case "$sub" in
      add) _g05_add "$seg" ;;
      commit) _g05_commit "$dir" "$seg" ;;
    esac
  done <<EOT
$(git_words "$cmd")
EOT
}

_g05_broad() {
  vote ask G5 "$1 stages every change; stage named files with git add -- <paths>"
  [ "$AUTOPILOT" = 1 ] && vote deny G5 "$1 under autopilot"
}

_g05_add() {
  local words
  words=$(_shell_words "$1" | awk 'f { print } $0 == "add" { f = 1 }')
  if word_has "$words" -A --all . :/ -u --update '*'; then
    _g05_broad "git add -A"
  fi
}

# _g05_message DIR WORDS: prints the commit message. Exit 1 when it cannot be read statically.
_g05_message() {
  local dir="$1" words="$2" w prev="" msg="" have=0 f ref
  while IFS= read -r w; do
    case "$prev" in
      -m | --message) msg="${msg:+$msg

}$w"; have=1; prev=""; continue ;;
      -F | --file) f="$w"; prev=""; continue ;;
      -C | -c | --reuse-message | --reedit-message) ref="$w"; prev=""; continue ;;
    esac
    case "$w" in
      -m | --message | -F | --file | -C | -c | --reuse-message | --reedit-message) prev="$w" ;;
      --message=*) msg="${msg:+$msg

}${w#--message=}"; have=1 ;;
      --file=*) f="${w#--file=}" ;;
      -m?*) msg="${msg:+$msg

}${w#-m}"; have=1 ;;
      -F?*) f="${w#-F}" ;;
    esac
  done <<EOT
$words
EOT
  if [ -n "${f-}" ]; then
    [ "$f" = - ] && return 1
    case "$f" in /*) ;; *) f="$dir/$f" ;; esac
    [ -f "$f" ] || return 1
    cat "$f"
    return 0
  fi
  if [ "$have" = 1 ]; then
    case "$msg" in *'$('* | *'`'*) return 1 ;; esac
    printf '%s\n' "$msg"
    return 0
  fi
  if [ -n "${ref-}" ]; then
    git -C "$dir" log -1 --format=%B "$ref" 2>/dev/null
    return $?
  fi
  if word_has "$words" --no-edit && word_has "$words" --amend; then
    git -C "$dir" log -1 --format=%B 2>/dev/null
    return $?
  fi
  return 1
}

# _g05_problems DIR MESSAGE: one line per failed check; nothing when the message passes.
_g05_problems() {
  local dir="$1" msg="$2" subject conv idre branch id
  subject=$(printf '%s\n' "$msg" | sed -n '/[^[:space:]]/{p;q;}')
  if [ "$(settings_get commit.attribution none)" = none ] &&
    printf '%s\n' "$msg" | grep -Eiq 'co-authored-by:.*(claude|anthropic)|generated (with|by) .*claude|claude-session:|claude\.ai/code'; then
    echo "attribution trailer present (commit.attribution: none)"
  fi
  conv=$(settings_get commit.convention '')
  if [ -n "$conv" ] && ! printf '%s\n' "$subject" | grep -Eq -- "$conv"; then
    echo "subject does not match commit.convention $conv"
  fi
  idre=$(settings_get commit.id_from_branch '[A-Z][A-Z0-9]+-[0-9]+')
  branch=$(current_branch "$dir")
  id=$(printf '%s\n' "$branch" | grep -Eo -- "$idre" | head -n 1)
  if [ -n "$id" ]; then
    case "$subject" in *"$id"*) ;; *) echo "subject lacks the ticket id $id from branch $branch" ;; esac
  fi
}

_g05_commit() {
  local dir="$1" words msg problems
  words=$(_shell_words "$2" | awk 'f { print } $0 == "commit" { f = 1 }')
  if word_has "$words" -a --all || printf '%s\n' "$words" | grep -Eq '^-[a-zA-Z]*a[a-zA-Z]*$'; then
    _g05_broad "git commit -a"
  fi
  if ! msg=$(_g05_message "$dir" "$words"); then
    vote ask G5 "commit message cannot be checked here; write it to a file and use git commit -F <file>"
    return 0
  fi
  problems=$(_g05_problems "$dir" "$msg")
  if [ -n "$problems" ]; then
    vote deny G5 "$(printf '%s\n' "$problems" | paste -sd ';' - | sed 's/;/; /g')"
    return 0
  fi
  case "$(policy_for commit)" in
    deny) vote deny G5 "commit.policy deny" ;;
    auto) vote allow G5 "commit.policy auto: message checks pass" ;;
    *)
      if [ "$AUTOPILOT" = 1 ]; then
        vote allow G5 "autopilot commit: message checks pass"
      else
        vote ask G5 "commit (message checks pass)"
      fi
      ;;
  esac
}
```

- [ ] **Step 4: Write `hooks/guards/g06-secrets.sh`**

```bash
# shellcheck shell=bash
# G6 secrets: scan what a commit or push would publish; refuse never_commit paths.

guard_g06() {
  [ "$TOOL" = Bash ] || return 0
  local cmd seg parsed dir sub rest
  cmd=$(ti_get command) || return 0
  while IFS= read -r seg; do
    parsed=$(git_sub "$seg") || continue
    dir=${parsed%%	*}
    rest=${parsed#*	}
    sub=${rest%%	*}
    rest=${rest#*	}
    case "$sub" in
      commit) _g06_commit "$dir" "$rest" ;;
      push) _g06_push "$dir" ;;
    esac
  done <<EOT
$(git_words "$cmd")
EOT
}

# _g06_added: reads a unified diff, prints `path:line:text` for every added line.
_g06_added() {
  LC_ALL=C awk '
    /^\+\+\+ / { p = substr($0, 5); sub(/^b\//, "", p); next }
    /^@@ / { split($3, a, ","); ln = substr(a[1], 2) + 0; next }
    /^\+/ { print p ":" ln ":" substr($0, 2); ln++; next }
    /^ / { ln++ }'
}

# _g06_scan: reads `path:line:text` lines, prints `path:line <rule>` per hit. Never prints the text.
_g06_scan() {
  local added rule re
  added=$(cat)
  [ -n "$added" ] || return 0
  while IFS='|' read -r rule re; do
    printf '%s\n' "$added" | grep -E -- "$re" | cut -d: -f1,2 | sed "s/\$/ $rule/"
  done <<'EOT'
private-key|-----BEGIN [A-Z ]*PRIVATE KEY-----
aws-access-key|AKIA[0-9A-Z]{16}
github-token|gh[pousr]_[A-Za-z0-9]{20,}
slack-token|xox[baprs]-[A-Za-z0-9-]{10,}
api-key|sk-[A-Za-z0-9_-]{20,}
google-api-key|AIza[0-9A-Za-z_-]{35}
EOT
}

# _g06_paths NAMES: deny when a newline-separated path matches a never_commit glob.
_g06_paths() {
  local list glob name rest hits=""
  list=$(settings_get never_commit '')
  [ -n "$list" ] || return 0
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    rest="$list,"
    while [ -n "$rest" ]; do
      glob=${rest%%,*}
      rest=${rest#*,}
      glob=$(printf '%s' "$glob" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
      [ -n "$glob" ] || continue
      # shellcheck disable=SC2254
      case "$name" in $glob) hits="${hits:+$hits, }$name" ;; esac
    done
  done <<EOT
$1
EOT
  [ -n "$hits" ] && vote deny G6 "never_commit paths staged: $hits"
  return 0
}

_g06_report() {
  local hits="$1" diff="$2"
  if [ -n "$hits" ]; then
    vote deny G6 "possible secret, not committed or pushed: $(printf '%s\n' "$hits" | head -n 5 | paste -sd ';' - | sed 's/;/; /g')"
  elif command -v gitleaks >/dev/null 2>&1; then
    printf '%s\n' "$diff" | gitleaks stdin --no-banner --redact >/dev/null 2>&1
    [ $? -eq 1 ] && vote deny G6 "gitleaks reports a secret in this change; run gitleaks yourself to see where"
  fi
}

_g06_commit() {
  local dir="$1" rest="$2" diff names
  diff=$(git -C "$dir" diff --cached 2>/dev/null)
  names=$(git -C "$dir" diff --cached --name-only 2>/dev/null)
  case " $rest " in
    *" -a "* | *" --all "* | *" -am "*)
      diff="$diff
$(git -C "$dir" diff 2>/dev/null)"
      names="$names
$(git -C "$dir" diff --name-only 2>/dev/null)"
      ;;
  esac
  _g06_paths "$names"
  _g06_report "$(printf '%s\n' "$diff" | _g06_added | _g06_scan)" "$diff"
}

_g06_push() {
  local dir="$1" range base diff
  if git -C "$dir" rev-parse --verify -q '@{u}' >/dev/null 2>&1; then
    range='@{u}..HEAD'
  elif base=$(base_branch_name); then
    range="origin/$base..HEAD"
  else
    return 0
  fi
  diff=$(git -C "$dir" log -p --format= "$range" 2>/dev/null)
  _g06_paths "$(git -C "$dir" diff --name-only "$range" 2>/dev/null)"
  _g06_report "$(printf '%s\n' "$diff" | _g06_added | _g06_scan)" "$diff"
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `tests/run-bats tests/hooks/g05-g06-commit.bats`
Expected: `11 tests, 0 failures`.

- [ ] **Step 6: Commit**

```bash
git add -- hooks/guards/g05-commit.sh hooks/guards/g06-secrets.sh tests/hooks/g05-g06-commit.bats
git commit -m "M1: add G5 commit checks and G6 secret scan" -m "A commit must match the project's convention and carry no AI trailer; nothing that looks like a key leaves through a commit or push."
```

---

