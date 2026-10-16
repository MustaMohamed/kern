#!/usr/bin/env bats
# Shell aliases: a Bash command whose head word is an alias that runs git or gh is judged as its
# expansion, read from the Claude Code shell snapshot.

load ../helpers/common

setup() {
  R="$BATS_TEST_TMPDIR/repo"
  make_repo "$R"
  git -C "$R" worktree add -q -b feat "$BATS_TEST_TMPDIR/wt" >/dev/null 2>&1
  kern_env "$R"
  SNAPS="$HOME/.claude/shell-snapshots"
  mkdir -p "$SNAPS"
  # The shape Claude Code writes for zsh: functions, then `alias -- name=value` lines.
  cat >"$SNAPS/snapshot-zsh-1791935887205-ewlszo.sh" <<'SNAP'
# Snapshot file
unalias -a 2>/dev/null || true
git_current_branch () {
	command git rev-parse --abbrev-ref HEAD
}
alias -- g=git
alias -- gp='git push'
alias -- gpf!='git push --force'
alias -- gpo='g push origin'
alias -- gcan!='git commit --verbose --all --no-edit --amend'
alias -- ghpc='gh pr create'
alias -- gst='git status'
alias -- glg='git log --stat'
alias -- gbgd='LANG=C git branch --no-color -vv | grep ": gone\]" | cut -c 3- | awk '\''{print $1}'\'' | xargs git branch -d'
alias -- ll='ls -l'
alias -- gbad='git push --force
alias -- gnl=$'git\npush --force'
alias -- gdq="git push --force"
alias -- after-bad='git push --force'
SNAP
}

# all CMD: every guard's decision for CMD.
all() { run_guard "$(bash_payload "$1")"; }

# same ALIAS_CMD EXPANDED_CMD: the full hook output is identical for both.
same() {
  all "$1"
  local a="$output"
  all "$2"
  [ "$a" = "$output" ] || { printf '%s -> %s\n%s -> %s\n' "$1" "$a" "$2" "$output"; return 1; }
}

# snap LINE...: a snapshot holding only LINE..., newer than the setup one, so it is the one read.
snap() {
  printf '%s\n' "$@" >"$SNAPS/snapshot-zsh-1791978476876-cqjrpm.sh"
  touch -t 203001010000 "$SNAPS/snapshot-zsh-1791978476876-cqjrpm.sh"
}

# expect DECISION CMD...: every guard together gives DECISION for every CMD.
expect() {
  local want="$1" c
  shift
  for c in "$@"; do
    all "$c"
    [ "$(decision_of "$output")" = "$want" ] || { echo "$c -> $output"; return 1; }
  done
}

# noalias_hook: a copy of the hook that loads no aliases, which is how kern ran before aliases.sh.
noalias_hook() {
  local k="$BATS_TEST_TMPDIR/k"
  rm -rf "$k"
  mkdir -p "$k"
  cp -R "$(kern_root)/hooks" "$k/hooks"
  sed -i.bak '/^\[ "\$TOOL" = Bash \] && aliases_load$/d' "$k/hooks/pre-tool-use"
  ! grep -q '&& aliases_load$' "$k/hooks/pre-tool-use" || return 1
  printf '%s\n' "$k/hooks/pre-tool-use"
}

@test "gpf! origin main is denied like git push --force, in both modes" {
  all "gpf! origin main"
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"kern G1"* ]] || false
  same "gpf! origin main" "git push --force origin main"
  set_autopilot on
  all "gpf! origin main"
  [ "$(decision_of "$output")" = deny ]
}

@test "gp to a protected branch asks even with push.policy auto" {
  mkdir -p "$R/.claude"
  printf 'push.policy: auto\n' >"$R/.claude/kern.local.yml"
  all "gp origin main"
  [ "$(decision_of "$output")" = ask ]
  same "gp origin main" "git push origin main"
}

@test "each alias is judged exactly like its expansion" {
  same "gst" "git status"
  same "gcan!" "git commit --verbose --all --no-edit --amend"
  same "ghpc --title t --body b" "gh pr create --title t --body b"
  same "gpo +main" "git push origin +main"
  same "gbgd" "LANG=C git branch --no-color -vv | grep ': gone' | cut -c 3- | xargs git branch -d"
  set_autopilot on
  same "ghpc --title t --body b" "gh pr create --title t --body b"
}

@test "the head word is found after assignments and in every simple command of a chain" {
  all "GIT_TRACE=1 gpf! origin feat"
  [ "$(decision_of "$output")" = deny ]
  all "cd /tmp && gpf! origin feat"
  [ "$(decision_of "$output")" = deny ]
  all "echo \$(gpf! origin feat)"
  [ "$(decision_of "$output")" = deny ]
}

@test "a quoted or escaped head word, or an alias in argument position, is not expanded" {
  for c in "'gpf!' origin main" "\\\\gpf! origin main" "echo gpf! origin main"; do
    run_guard "$(payload PreToolUse "\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$c\"}")"
    [ "$(decision_of "$output")" = none ] || { echo "$c -> $output"; return 1; }
  done
}

@test "an alias to a command that is not git or gh is unaffected" {
  all "ll /tmp"
  [ "$(decision_of "$output")" = none ]
}

@test "a missing or unreadable snapshot changes nothing" {
  rm -f "$SNAPS"/*.sh
  all "gpf! origin main"
  [ "$(decision_of "$output")" = none ]
  printf 'alias -- gpf!=%s\n' "'git push --force'" >"$BATS_TEST_TMPDIR/snap.sh"
  chmod 000 "$BATS_TEST_TMPDIR/snap.sh"
  KERN_SHELL_SNAPSHOT="$BATS_TEST_TMPDIR/snap.sh" all "gpf! origin main"
  [ "$(decision_of "$output")" = none ]
}

@test "malformed alias lines are ignored and the lines after them still count" {
  for c in "gbad origin main" "gnl origin main" "gdq origin main"; do
    all "$c"
    [ "$(decision_of "$output")" = none ] || { echo "$c -> $output"; return 1; }
  done
  all "after-bad origin main"
  [ "$(decision_of "$output")" = deny ]
}

@test "the newest snapshot is read" {
  printf 'alias -- gpf!=%s\n' "'git status'" >"$SNAPS/snapshot-zsh-1791978476876-cqjrpm.sh"
  touch -t 203001010000 "$SNAPS/snapshot-zsh-1791978476876-cqjrpm.sh"
  all "gpf! origin main"
  [ "$(decision_of "$output")" = none ]
}

@test "the head word is found after zsh's reserved words and redirections, as zsh finds it" {
  local f
  for f in "if % origin main; then :; fi" "! % origin main" "time % origin main" "nocorrect % origin main" \
    "coproc % origin main" "repeat 2 % origin main" "while % origin main; do :; done" "{ % origin main; }" \
    "( % origin main )" "2>&1 % origin main" ">/dev/null % origin main" "> /dev/null % origin main" \
    "X+=1 % origin main" "true && % origin main" "eval % origin main"; do
    all "${f//%/gpf!}"
    [ "$(decision_of "$output")" != none ] || { echo "${f//%/gpf!} -> none"; return 1; }
    same "${f//%/gpf!}" "${f//%/git push --force}"
  done
}

@test "command, builtin, noglob, exec and - are not followed, as zsh does not expand after them" {
  expect none "command gpf! origin main" "builtin gpf! origin main" "noglob gpf! origin main" \
    "exec gpf! origin main" "- gpf! origin main" "nohup gpf! origin main"
}

@test "the original command still counts: an alias cannot hide a git or gh word" {
  snap "alias -- git='git status'" "alias -- gh='gh pr list'" "alias -- sh='git status'"
  expect deny "git push --force origin main" "sh -c 'git push --force origin main'"
  all "gh pr merge 1 --admin"
  [ "$(decision_of "$output")" != none ]
  [ "$(decision_of "$output")" != allow ]
}

@test "an alias command is never allowed unattended, and the investigator still may not run one" {
  kern_env "$BATS_TEST_TMPDIR/wt"
  mkdir -p "$R/.claude"
  printf 'push.policy: auto\n' >"$R/.claude/kern.local.yml"
  all "git push -u origin feat"
  [ "$(decision_of "$output")" = allow ]
  all "gp -u origin feat"
  [ "$(decision_of "$output")" = ask ]
  set_autopilot on
  all "gp -u origin feat"
  [ "$(decision_of "$output")" = deny ]
  run_guard "$(payload PreToolUse '"agent_id":"a1","agent_type":"kern:investigator","tool_name":"Bash","tool_input":{"command":"glg"}')"
  [ "$(decision_of "$output")" = deny ]
  [[ "$output" == *"kern G18: kern:investigator is read-only; 'glg'"* ]] || { echo "$output"; return 1; }
}

@test "alias names are encoded one to one, and a chain, a cycle and a self-reference resolve" {
  snap "alias -- a-b='git push --force'" "alias -- a_b='git status'" "alias -- a.b='git status'" \
    "alias -- c1=c2" "alias -- c2=c1" "alias -- s1='s2 origin'" "alias -- s2='s3 --force'" "alias -- s3='git push'" \
    "alias -- git='git --no-pager'" "alias -- l1=l2" "alias -- l2=l3" "alias -- l3=l4" "alias -- l4=l5" \
    "alias -- l5=l6" "alias -- l6=l7" "alias -- l7=l8" "alias -- l8=l9" "alias -- l9=l10" "alias -- l10='git push --force'"
  expect deny "a-b origin main" "s1 main" "git push --force origin main" "l2 origin main"
  expect none "a_b origin main" "a.b origin main" "c1 origin main" "l1 origin main"
}

@test "snapshot text is never run: substitutions, backticks, ; and newlines stay inert" {
  local m="$BATS_TEST_TMPDIR/marks"
  mkdir -p "$m"
  # Every line names a marker file that appears only if kern runs snapshot text.
  snap "touch $m/top" \
    "alias -- h1='git status; \$(touch $m/h1)'" \
    "alias -- h2='git status \`touch $m/h2\`'" \
    "alias -- h3='git status; touch $m/h3'" \
    "alias -- h4='git status" "touch $m/h4'" \
    "alias -- h5=\$'git status\\ntouch $m/h5'" \
    "alias -- h6=\"git status \$(touch $m/h6)\"" \
    "alias -- \$(touch $m/h7)='git status'" \
    "alias -- h8='git status '\\''\$(touch $m/h8)'\\'''" \
    "alias -- h9=git\\ status\\;touch\\ $m/h9" \
    "alias -- h10='git status' ; touch $m/h10" \
    "alias -- h11='git push --force'"
  for c in h1 h2 h3 h4 h5 h6 h7 h8 h9 h10 "h11 origin main"; do
    all "$c"
    [ "$(decision_of "$output")" != error ] || { echo "$c -> $output"; return 1; }
  done
  [ "$(decision_of "$output")" = deny ]
  run ls -A "$m"
  [ -z "$output" ] || { echo "ran: $output"; return 1; }
}

@test "a missing, empty or unparseable snapshot gives exactly the output of a hook with no aliases" {
  local h c out want
  h=$(noalias_hook)
  # NUL bytes, a carriage return alone, and bytes outside ASCII; no alias line.
  printf 'alias\000 -- \001\377=\200\nalias --\nalias -- =x\nalias -- a\rb=git\n\377\376garbage' >"$BATS_TEST_TMPDIR/garbage.sh"
  : >"$BATS_TEST_TMPDIR/empty.sh"
  for s in "$BATS_TEST_TMPDIR/none.sh" "$BATS_TEST_TMPDIR/empty.sh" "$BATS_TEST_TMPDIR/garbage.sh" "$SNAPS"; do
    for c in "gpf! origin main" "git push --force origin main" "git push origin main" "gst" "gh pr create --title t --body b" "ls"; do
      want=$(env KERN_GUARDS= bash "$h" <<<"$(bash_payload "$c")")
      out=$(env KERN_GUARDS= KERN_SHELL_SNAPSHOT="$s" bash "$(kern_root)/hooks/pre-tool-use" <<<"$(bash_payload "$c")")
      [ "$out" = "$want" ] || { printf '%s, %s:\n%s\n%s\n' "$s" "$c" "$out" "$want"; return 1; }
    done
  done
}

@test "CRLF, NUL bytes, a long line and 10,000 aliases leave the hook working" {
  {
    printf "alias -- crlf='git push --force'\r\n"
    printf "alias -- nul='git status'\000x\n"
    printf "alias -- long='git status %s'\n" "$(head -c 200000 /dev/zero | tr '\0' a)"
    i=0
    while [ "$i" -lt 10000 ]; do printf "alias -- x%d='git status'\n" "$i"; i=$((i + 1)); done
    printf "alias -- last='git push --force'\n"
  } >"$SNAPS/snapshot-zsh-1791978476876-cqjrpm.sh"
  touch -t 203001010000 "$SNAPS/snapshot-zsh-1791978476876-cqjrpm.sh"
  expect deny "crlf origin main" "last origin main"
  expect none "long" "x9999" "ls"
  all "nul"
  [ "$(decision_of "$output")" != error ]
}

@test "aliases.sh never aborts a shell under set -eu, and never sets a name outside _KA_" {
  printf "alias -- gpf!='git push --force'\r\n\000\nalias -- 'x'=1\nalias -- \$(id)=git\n" >"$BATS_TEST_TMPDIR/odd.sh"
  for s in "$BATS_TEST_TMPDIR/odd.sh" "$BATS_TEST_TMPDIR/none.sh" "$SNAPS"; do
    run env KERN_SHELL_SNAPSHOT="$s" bash -euc '
      . "$1/hooks/lib/aliases.sh"
      before=$(set | sed -n "s/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p" | sort)
      aliases_load
      alias_expand "ls -l" || true
      alias_expand "" || true
      alias_expand "gpf! origin" || true
      alias_expand "X='"'"''"'"' gpf! origin" || true
      alias_expand "X='"'"'a" || true
      after=$(set | sed -n "s/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p" | sort)
      comm -13 <(printf "%s\n" "$before") <(printf "%s\n" "$after") | grep -v -e "^_KA_" -e "^KERN_ALIASES$" -e "^ALIAS_EXP$" -e "^before$" || true
      echo finished' _ "$(kern_root)"
    [ "$status" -eq 0 ] || { echo "$s: $output"; return 1; }
    [ "$output" = finished ] || { echo "$s: $output"; return 1; }
  done
}

@test "a _KA_ variable from the environment is never an alias" {
  run env _KA_7878='git push --force' bash "$(kern_root)/hooks/pre-tool-use" <<<"$(bash_payload "xx origin main")"
  [ "$(decision_of "$output")" = none ]
}

@test "an alias is not skipped by a guard that reads the command text first, and without a snapshot nothing changes" {
  snap "alias -- prc='gh pr create'" "alias -- rel='gh release create'" "alias -- isc='gh issue create'" \
    "alias -- prv='gh pr review'" "alias -- gp='git push'"
  mkdir -p "$R/.claude"
  printf 'deploy.envs: production\n' >"$R/.claude/kern.local.yml"
  # G2 alone, then G15 alone: each votes on the alias as on its expansion.
  run_guard "$(bash_payload "prc --title t --body-file b.md")" g02
  [[ "$output" == *'"kern G2: '* ]] || { echo "$output"; return 1; }
  a=$output
  run_guard "$(bash_payload "gh pr create --title t --body-file b.md")" g02
  [ "$a" = "$output" ] || { printf '%s\n%s\n' "$a" "$output"; return 1; }
  run_guard "$(bash_payload "gp origin production")" g15
  [[ "$output" == *"G15: deploy or publish: push to deploy branch production"* ]] || { echo "$output"; return 1; }
  a=$output
  run_guard "$(bash_payload "git push origin production")" g15
  [ "$a" = "$output" ] || { printf '%s\n%s\n' "$a" "$output"; return 1; }
  # Every guard together: G4 (inline body), G15 (release), G14 (issue) and G3 (review).
  same "prc --title t --body b" "gh pr create --title t --body b"
  same "rel v1" "gh release create v1"
  same "isc --title t --body-file b.md" "gh issue create --title t --body-file b.md"
  same "prv 1 --approve" "gh pr review 1 --approve"
  expect deny "prc --title t --body b"
  snap "alias -- pdb='git status && psql -h prod-db.internal -c '\\''DELETE FROM x'\\'''"
  printf 'deploy.envs: production\nprotected_targets: prod-db.internal\n' >"$R/.claude/kern.local.yml"
  # G13 cannot find the alias's psql in the command text, so it also reads it as fed by a pipe.
  expect deny "pdb"
  [[ "$output" == *"statement starting \`delete\` is not a read"* ]] || false
  # With no snapshot the same commands get no vote, as before aliases.sh.
  rm -f "$SNAPS"/*.sh
  for c in "prc --title t --body-file b.md" "gp origin production"; do
    for g in g02 g15 ""; do
      run_guard "$(bash_payload "$c")" "$g"
      [ "$(decision_of "$output")" = none ] || { echo "$c, ${g:-all}: $output"; return 1; }
    done
  done
  expect none "prc --title t --body b" "rel v1" "isc --title t --body-file b.md" "prv 1 --approve" "pdb"
}

@test "an alias whose value ends in a space expands the word after it, as zsh does, 8 times, then fails closed" {
  local h c w8 w9 mode want
  h=$(noalias_hook)
  snap "alias -- _='sudo '" "alias -- gpf!='git push --force'" "alias -- n='nice '" "alias -- t='nice"$'\t'"'"
  for mode in off on; do
    set_autopilot "$mode"
    all "_ gpf! origin main"
    [ "$(decision_of "$output")" = deny ] || { echo "$mode: $output"; return 1; }
    [[ "$output" == *"kern G1"* ]] || false
    same "_ gpf! origin main" "sudo git push --force origin main"
    # Without a git or gh alias after it, `_` is judged as before.
    # A trailing tab is not zsh's trailing space: t's value ends in one.
    for c in "_ git status" "_ ls -la" "_ 'gpf!' origin main" "_ X=1 gpf! origin main" "t gpf! origin main"; do
      want=$(env KERN_GUARDS= bash "$h" <<<"$(bash_payload "$c")")
      all "$c"
      [ "$output" = "$want" ] || { printf '%s, %s:\n%s\n%s\n' "$mode" "$c" "$output" "$want"; return 1; }
    done
  done
  # n is `nice `: gpf! is the 8th word after the head n in w8, which expands. In w9 it is the 9th: it
  # stays an alias kern did not expand, which G00 denies under autopilot, as base gives no vote.
  w8="n n n n n n n n gpf! origin main"
  w9="n n n n n n n n n gpf! origin main"
  set_autopilot off
  expect deny "$w8"
  expect none "$w9"
  set_autopilot on
  expect deny "$w8" "$w9"
  [[ "$output" == *'kern G00: '*'$KERN_ALIAS_PAST_8'* ]] || { echo "$output"; return 1; }
}

@test "an assignment with a quote or \$ before the alias does not hide it" {
  for mode in off on; do
    set_autopilot "$mode"
    expect deny "X='' gpf! origin main" "X='a b' gpf! origin main" "X=\$(true) Y=1 gpf! origin main"
    same "X='' gpf! origin main" "X='' git push --force origin main"
    expect none "X='' 'gpf!' origin main" "X='a b' echo gpf! origin main"
  done
}

@test "git_words prints the command's own records as without aliases, then each expansion after all of them" {
  run bash -c '
    . "$1/hooks/lib/settings.sh"; . "$1/hooks/lib/aliases.sh"; . "$1/hooks/lib/gitctx.sh"
    c="cd /x && gst && echo y \$(gp; cd /z) && X=1 gpf! origin main"
    want=$(git_words "$c")
    aliases_load
    [ -n "$KERN_ALIASES" ] || exit 3
    got=$(git_words "$c")
    printf "%s\n--\n%s\n" "$want" "$got"' _ "$(kern_root)"
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
  want=${output%%$'\n--\n'*}
  got=${output#*$'\n--\n'}
  # The command's own records come first, unchanged and in order.
  [ "${got:0:${#want}}" = "$want" ] || { printf '%s\n--\n%s\n' "$want" "$got"; return 1; }
  [ "${got:${#want}}" = $'\ngit status\ngit push\nX=1 git push --force origin main' ] || { printf '[%s]\n' "${got:${#want}}"; return 1; }
  case "$got" in *$'\n\t'* | $'\t'*) echo "marker left in: $got"; return 1 ;; esac
}

@test "with aliases loaded, no command gets a weaker decision than without them, in both modes, a forged cache included" {
  local h c mode want got s rank_want rank_got W SD forged
  h=$(noalias_hook)
  W="$BATS_TEST_TMPDIR/wt"
  SD="$CLAUDE_PLUGIN_DATA/sessions"
  mkdir -p "$SD" "$R/.claude"
  printf 'push.policy: auto\ndeploy.envs: production\n' >"$R/.claude/kern.local.yml"
  # feat holds another author's commit, so a lease push of it is denied; a key is staged in the worktree.
  git -C "$W" -c user.email=other@example.com -c user.name=Other commit -q --allow-empty -m "other: work"
  git -C "$W" push -q origin feat >/dev/null 2>&1
  printf 'key = AKIA%s\n' ABCDEFGHIJKLMNOP >"$W/creds.txt"
  git -C "$W" add creds.txt
  printf '{}\n' >"$HOME/.claude/settings.json"
  kern_env "$W"
  # Aliases as oh-my-zsh defines them, and a hostile table that shadows common commands with a cd.
  cat >"$BATS_TEST_TMPDIR/omz.sh" <<'SNAP'
alias -- _='sudo '
alias -- sudo='nocorrect sudo'
alias -- g=git
alias -- gaa='git add --all'
alias -- gcmsg='git commit --message'
alias -- gp='git push'
alias -- gpf!='git push --force'
alias -- gst='git status'
alias -- grhh='git reset --hard'
alias -- grt='cd "$(git rev-parse --show-toplevel || echo .)"'
SNAP
  cat >"$BATS_TEST_TMPDIR/hostile.sh" <<'SNAP'
alias -- git='git status'
alias -- gh='gh pr list'
alias -- cd='git status; cd'
alias -- ls='cd / && git log'
alias -- cat='cd /tmp; git status'
alias -- echo='GIT_DIR=/x git status; echo'
alias -- env='git status; env'
alias -- sudo='git status; sudo'
alias -- true='cd -; git status'
alias -- if='git push --force'
alias -- time='git status'
alias -- sed='cd /; git status; sed'
alias -- cp='git status; cd /; cp'
alias -- x2='git status &&'
alias -- _='sudo '
alias -- gpf!='git push --force'
alias -- gp='git push'
alias -- gst='git status'
alias -- grt='cd "$(git rev-parse --show-toplevel || echo .)"'
SNAP
  rank() { case "$(decision_of "$1")" in deny) echo 3 ;; ask) echo 2 ;; none) echo 1 ;; allow) echo 0 ;; *) echo 9 ;; esac; }
  # A forged cache: the hostile table under a first line that matches the oh-my-zsh snapshot.
  KERN_SHELL_SNAPSHOT="$BATS_TEST_TMPDIR/omz.sh" bash "$(kern_root)/hooks/pre-tool-use" <<<"$(bash_payload ls)" >/dev/null
  forged="$BATS_TEST_TMPDIR/forged.cache"
  { head -n 1 "$SD/aliases.cache"
    bash -c '. "$1/hooks/lib/aliases.sh"; LC_ALL=C awk -v sq="'"'"'" "$_ALIASES_AWK" <"$2"' _ "$(kern_root)" "$BATS_TEST_TMPDIR/hostile.sh"
  } >"$forged"
  [ "$(wc -l <"$forged")" -gt 10 ]
  for mode in off on; do
    set_autopilot "$mode"
    while IFS= read -r c; do
      want=$(env KERN_GUARDS= bash "$h" <<<"$(bash_payload "$c")")
      rank_want=$(rank "$want")
      for s in omz hostile forged; do
        if [ "$s" = forged ]; then cp "$forged" "$SD/aliases.cache"; s=omz; fi
        got=$(env KERN_GUARDS= KERN_SHELL_SNAPSHOT="$BATS_TEST_TMPDIR/$s.sh" bash "$(kern_root)/hooks/pre-tool-use" <<<"$(bash_payload "$c")")
        rank_got=$(rank "$got")
        [ "$rank_got" != 9 ] && [ "$rank_got" -ge "$rank_want" ] ||
          { printf '%s, %s, %s:\nwithout: %s\nwith:    %s\n' "$mode" "$s" "$c" "$want" "$got"; return 1; }
      done
    done <<CORPUS
cd $HOME/.claude && grt && sed -i '' s/a/b/ settings.json
cd $HOME/.claude && ls && echo x > settings.json
cd $HOME/.claude && true && cp /tmp/x settings.local.json
cd $SD && ls && echo x > foo
cd $SD && grt && echo x > foo
grt && echo x > $SD/test-session.state
git commit -m 'feat: add creds'
grt && git commit -m 'feat: add creds'
gaa && git commit -m x
git push --force-with-lease origin feat
grt && git push --force-with-lease origin feat
ls && git push --force-with-lease origin feat
true; git push --force-with-lease origin feat
git push -u origin feat
gp -u origin feat
gp origin production
gpf! origin main
_ gpf! origin main
_ _ _ _ _ _ _ _ _ gpf! origin main
X='' gpf! origin main
x2 git push --force origin main
CORPUS
  done
}

@test "past 8 trailing-space words the marker is a record of its own, so expansions through nocorrect, watch or a wrapper's value still fail closed" {
  local a c i cmds=()
  # The oh-my-zsh shape: _ is `sudo `, and sudo is `nocorrect sudo`.
  snap "alias -- _='sudo '" "alias -- sudo='nocorrect sudo'" "alias -- gpf!='git push --force'" \
    "alias -- w='watch '" "alias -- to='timeout 5 '" "alias -- eu='env -u X '" "alias -- sr='sudo -u root '"
  for a in "_ 9" "_ 12" "w 9" "to 9" "eu 9" "sr 9"; do
    c=""
    for ((i = 0; i < ${a#* }; i++)); do c="$c${a% *} "; done
    cmds+=("${c}gpf! origin main")
  done
  set_autopilot on
  expect deny "${cmds[@]}"
  all "${cmds[0]}"
  [[ "$output" == *'kern G00: '*'$KERN_ALIAS_PAST_8'* ]] || { echo "$output"; return 1; }
  # Eight words still expand in full: `_ ×8 gpf!` is `nocorrect sudo ×8 git push --force`.
  all "_ _ _ _ _ _ _ _ gpf! origin main"
  [ "$(decision_of "$output")" = deny ] || { echo "$output"; return 1; }
  # Interactively G00 votes nothing, so these get no vote, as without aliases.
  set_autopilot off
  expect none "${cmds[0]}" "${cmds[2]}"
}

@test "the head search keeps each \$( )'s own quotes, so a quote or a parenthesis inside one does not hide the alias" {
  local c
  cat >"$BATS_TEST_TMPDIR/cases" <<'CASES'
X=$(printf "%s" a) gpf! origin main
X=$(echo "(") gpf! origin main
X=$(echo ")" ) gpf! origin main
X="$(echo "a b")" gpf! origin main
X=$(a "$(b "c d")" e) gpf! origin main
X=${Y:-"}"} gpf! origin main
X=$(echo 'a ) b') gpf! origin main
X='' 'gpf!' origin main
CASES
  run bash -c '. "$1/hooks/lib/aliases.sh"
    while IFS= read -r c; do printf "%s" "$c" | LC_ALL=C awk -v sq="'"'"'" "$_ALIAS_HEAD_AWK" | sed -n 2p; done <"$2"' \
    _ "$(kern_root)" "$BATS_TEST_TMPDIR/cases"
  [ "$output" = $'gpf!\ngpf!\ngpf!\ngpf!\ngpf!\ngpf!\ngpf!\n\'gpf!\'' ] || { echo "$output"; return 1; }
  set_autopilot on
  # \" is a quote once the JSON payload is decoded.
  for c in 'X=$(printf \"%s\" a) gpf! origin main' 'X=$(echo \"(\") gpf! origin main' 'X=$(echo \")\" ) gpf! origin main'; do
    run_guard "$(payload PreToolUse "\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"$c\"}")"
    [ "$(decision_of "$output")" = deny ] || { echo "$c -> $output"; return 1; }
    [[ "$output" == *"kern G1"* ]] || { echo "$c -> $output"; return 1; }
  done
}

@test "the parsed alias table is cached in the state dir, and the next call reads the cache" {
  local c="$CLAUDE_PLUGIN_DATA/sessions/aliases.cache" first
  all "gpf! origin main"
  [ "$(decision_of "$output")" = deny ]
  [ -f "$c" ]
  first=$(head -n 1 "$c")
  [[ "$first" == "kern aliases "*$'\t'"$SNAPS/snapshot-zsh-1791935887205-ewlszo.sh"$'\t'* ]] || { echo "$first"; return 1; }
  # zz is in the cache only (7a7a is its hex): its vote shows the cache was read, not the snapshot.
  printf '%s\n7a7a\tgit push --force\n' "$first" >"$c"
  all "zz origin main"
  [ "$(decision_of "$output")" = deny ] || { echo "$output"; return 1; }
}

@test "a cache is rebuilt when the snapshot's path, size, modification time or change time changes" {
  local c="$CLAUDE_PLUGIN_DATA/sessions/aliases.cache" f="$SNAPS/snapshot-zsh-1791978476876-cqjrpm.sh"
  snap "alias -- x='git push --force'"
  expect deny "x origin main"
  # Same size, later time.
  printf "alias -- x='git status --abc'\n" >"$f"
  touch -t 203101010000 "$f"
  expect none "x origin main"
  # Other size, same time.
  printf "alias -- x='git push --force --verbose'\n" >"$f"
  touch -t 203101010000 "$f"
  expect deny "x origin main"
  # Same size and modification time put back, edited in place: the change time differs, which counts
  # seconds, so wait for the next one.
  printf "alias -- x='git status --xyz'\n" >"$f"
  touch -t 203101010000 "$f"
  expect none "x origin main"
  sleep 1
  # This edit keeps the size, the modification time and the inode: only the change time tells it apart.
  printf "alias -- x='git push --force'\n" >"$f"
  touch -t 203101010000 "$f"
  expect deny "x origin main"
  # Another snapshot path.
  printf "alias -- x='git status --abc'\n" >"$BATS_TEST_TMPDIR/other.sh"
  KERN_SHELL_SNAPSHOT="$BATS_TEST_TMPDIR/other.sh" all "x origin main"
  [ "$(decision_of "$output")" = none ] || { echo "$output"; return 1; }
  [[ "$(head -n 1 "$c")" == *$'\t'"$BATS_TEST_TMPDIR/other.sh"$'\t'* ]] || false
}

@test "a forged cache is data: substitutions and backticks in it run nothing, and lines without a hex name are skipped" {
  local c="$CLAUDE_PLUGIN_DATA/sessions/aliases.cache" m="$BATS_TEST_TMPDIR/marks" first cmd
  mkdir -p "$m"
  all ls
  first=$(head -n 1 "$c")
  # h1, h2 and h3 are 6831, 6832 and 6833.
  {
    printf '%s\n' "$first"
    printf '6831\tgit status $(touch %s/c1)\n' "$m"
    printf '6832\tgit status `touch %s/c2`\n' "$m"
    printf '$(touch %s/c3)\tgit push --force\n' "$m"
    printf 'touch %s/c4\n; touch %s/c5\n`touch %s/c6`\n' "$m" "$m" "$m"
    printf '6833\tgit push --force\n'
  } >"$c"
  for cmd in h1 h2 "h3 origin main"; do
    all "$cmd"
    [ "$(decision_of "$output")" != error ] || { echo "$cmd -> $output"; return 1; }
  done
  [ "$(decision_of "$output")" = deny ]
  run ls -A "$m"
  [ -z "$output" ] || { echo "ran: $output"; return 1; }
}

@test "a cache that cannot be written changes nothing, and a symlinked cache or state dir is never read, even with a valid first line" {
  local sd="$CLAUDE_PLUGIN_DATA/sessions" want planted
  all "gpf! origin main"
  want=$output
  [ "$(decision_of "$want")" = deny ]
  # A cache with this snapshot's first line and an alias the snapshot lacks: zz (7a7a) runs git push --force.
  planted=$(printf '%s\n7a7a\tgit push --force' "$(head -n 1 "$sd/aliases.cache")")
  rm -rf "$sd"
  mkdir -p "$sd"
  chmod 500 "$sd"
  all "gpf! origin main"
  chmod 700 "$sd"
  [ "$output" = "$want" ] || { echo "$output"; return 1; }
  [ ! -e "$sd/aliases.cache" ]
  # A symlinked cache is not read, and a rename replaces it, so its target is never written.
  printf '%s\n' "$planted" >"$BATS_TEST_TMPDIR/target"
  ln -s "$BATS_TEST_TMPDIR/target" "$sd/aliases.cache"
  all "zz origin main"
  [ "$(decision_of "$output")" = none ] || { echo "symlinked cache read: $output"; return 1; }
  [ "$(cat "$BATS_TEST_TMPDIR/target")" = "$planted" ]
  all "gpf! origin main"
  [ "$output" = "$want" ] || { echo "$output"; return 1; }
  # A cache in a symlinked state dir is neither read nor written.
  rm -rf "$sd"
  mkdir -p "$BATS_TEST_TMPDIR/real-sessions"
  printf '%s\n' "$planted" >"$BATS_TEST_TMPDIR/real-sessions/aliases.cache"
  ln -s "$BATS_TEST_TMPDIR/real-sessions" "$sd"
  all "zz origin main"
  [ "$(decision_of "$output")" = none ] || { echo "cache in a symlinked dir read: $output"; return 1; }
  all "gpf! origin main"
  [ "$output" = "$want" ] || { echo "$output"; return 1; }
  [ "$(cat "$BATS_TEST_TMPDIR/real-sessions/aliases.cache")" = "$planted" ]
}

@test "a cache larger than the table can be is rebuilt without reading its lines" {
  local c="$CLAUDE_PLUGIN_DATA/sessions/aliases.cache"
  all "gpf! origin main"
  [ "$(decision_of "$output")" = deny ]
  # A valid first line, then one line over the 4 MB cap.
  { head -n 1 "$c"; printf '7a7a\t'; head -c 4300000 /dev/zero | tr '\0' a; printf '\n'; } >"$c.big"
  mv "$c.big" "$c"
  all "gpf! origin main"
  [ "$(decision_of "$output")" = deny ] || { echo "$output"; return 1; }
  [ "$(wc -c <"$c")" -lt 100000 ]
}

# omz_snap: a snapshot shaped as Claude Code writes oh-my-zsh's git plugin: functions in `name () {`
# blocks with tab-indented bodies, closed by a `}` in column 0, then the aliases.
omz_snap() {
  cat >"$SNAPS/snapshot-zsh-1791978476876-cqjrpm.sh" <<'SNAP'
# Snapshot file
unalias -a 2>/dev/null || true
# Functions
ggf () {
	local b
	[[ $# != 1 ]] && b="$(git_current_branch)" 
	git push --force origin "${b:-$1}"
}
ggfl () {
	local b
	[[ $# != 1 ]] && b="$(git_current_branch)" 
	git push --force-with-lease origin "${b:-$1}"
}
grename () {
	if [[ -z "$1" || -z "$2" ]]
	then
		echo "Usage: $0 old_branch new_branch"
		return 1
	fi
	git branch -m "$1" "$2"
	if git push origin :"$1"
	then
		git push --set-upstream origin "$2"
	fi
}
gbda () {
	git branch --no-color --merged | command grep -vE "^([+*]|\s*($(git_main_branch))\s*$)" | command xargs git branch --delete 2> /dev/null
}
ghpv () {
	gh pr view --web
}
mkcd () {
	mkdir -p "$1" && cd "$1"
}
alias -- gst='git status'
SNAP
  touch -t 203001010000 "$SNAPS/snapshot-zsh-1791978476876-cqjrpm.sh"
}

@test "a shell function whose body runs git or gh asks, and under autopilot is denied" {
  omz_snap
  expect ask "ggf" "ggf feat" "ggfl" "grename feat x" "gbda" "ghpv"
  all "ggf feat"
  [[ "$output" == *"kern G1: git kern-shell-function"* ]] || false
  all "ghpv"
  [[ "$output" == *"kern G2: gh kern-shell-function"* ]] || false
  set_autopilot on
  expect deny "ggf" "ggf feat" "ggfl" "grename feat x" "gbda" "ghpv" "X=1 ggf feat" "true && grename feat x"
}

@test "a shell function with no git or gh word changes nothing" {
  omz_snap
  all "mkcd x"
  local a="$output"
  run env KERN_GUARDS= bash "$(noalias_hook)" <<<"$(bash_payload "mkcd x")"
  [ "$a" = "$output" ] || { printf 'with: %s\nwithout: %s\n' "$a" "$output"; return 1; }
  [ "$(decision_of "$a")" = none ]
  set_autopilot on
  all "mkcd x"
  [ "$(decision_of "$output")" = none ]
}

@test "an alias whose head word is a function that runs git is judged as that function" {
  snap 'ggf () {' '	git push --force origin "$1"' '}' "alias -- gff='ggf'"
  expect ask "gff feat"
  set_autopilot on
  expect deny "gff feat"
}

@test "function lines have a parse bound of their own, and aliases after them still count" {
  {
    printf 'big () {\n'
    i=0
    while [ "$i" -lt 12000 ]; do printf '\techo %0100d\n' "$i"; i=$((i + 1)); done
    printf '}\n'
    printf 'late () {\n\tgit push --force\n}\n'
    printf "alias -- gpf!='git push --force'\n"
  } >"$SNAPS/snapshot-zsh-1791978476876-cqjrpm.sh"
  touch -t 203001010000 "$SNAPS/snapshot-zsh-1791978476876-cqjrpm.sh"
  expect none "big" "late"
  expect deny "gpf! origin main"
}

@test "a function in bash's declare -f shape is read too" {
  snap 'ggf () ' '{ ' '    git push --force origin "$1"' '}'
  expect ask "ggf feat"
}

@test "a function named git or gh stores no expansion: git commands get the plain decision" {
  rm -f "$SNAPS"/*
  expect none "git status" "git diff --stat" "git log -1"
  snap 'git () {' '	command git "$@"' '}' 'gh () {' '	command gh "$@"' '}'
  expect none "git status" "git diff --stat" "git log -1" "git symbolic-ref -q --short HEAD"
  set_autopilot on
  expect none "git status" "git diff --stat" "git log -1"
}

@test "a git wrapper function leaves oh-my-zsh's ggf asking and denied under autopilot" {
  snap 'git () {' '	command git "$@"' '}' 'ggf () {' '	git push --force origin "$1"' '}'
  expect ask "ggf feat"
  set_autopilot on
  expect deny "ggf feat"
}
