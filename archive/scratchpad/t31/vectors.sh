#!/usr/bin/env bash
# vectors.sh KERN_DIR OUT_DIR [include]: builds a repo whose own config names a marker program for every
# execution vector, drives each kern hook through its git paths, and lists the markers that ran.
# With `include`, every vector sits in a file the repo config pulls in with include.path instead.
set -u
K="$1"
S="$2"
MODE="${3-direct}"
rm -rf "$S"
mkdir -p "$S/bin" "$S/marks" "$S/hookdir" "$S/home/.claude" "$S/data"
export MARKS="$S/marks"

# fail NAME: touches the marker and exits 1. cat NAME: touches it and copies stdin. tc NAME: textconv.
mk() {
  local name="$1" kind="$2"
  case "$kind" in
    fail) printf '#!/bin/sh\ntouch "%s/%s"\nexit 1\n' "$MARKS" "$name" >"$S/bin/$name" ;;
    ok) printf '#!/bin/sh\ntouch "%s/%s"\nexit 0\n' "$MARKS" "$name" >"$S/bin/$name" ;;
    cat) printf '#!/bin/sh\ntouch "%s/%s"\ncat\n' "$MARKS" "$name" >"$S/bin/$name" ;;
    tc) printf '#!/bin/sh\ntouch "%s/%s"\ncat "$1"\n' "$MARKS" "$name" >"$S/bin/$name" ;;
  esac
  chmod +x "$S/bin/$name"
}

R="$S/repo"
git init -q -b main "$R"
git -C "$R" config user.name "Test User"
git -C "$R" config user.email "test@example.com"
git -C "$R" config commit.gpgsign false
printf 'readme\n' >"$R/README.md"
printf '* filter=evil diff=evil merge=evil\n' >"$R/.gitattributes"
git -C "$R" add README.md .gitattributes
git -C "$R" commit -q -m "init"
git init -q --bare -b main "$R.origin"
git -C "$R" remote add origin "$R.origin"
git -C "$R" push -q origin main
git -C "$R" remote set-head origin main >/dev/null
git -C "$R" switch -q -c feat
printf 'feat\n' >"$R/feat.txt"
git -C "$R" add feat.txt
git -C "$R" commit -q -m "feat"
git -C "$R" push -q origin feat

for n in fsmonitor ssh gitproxy askpass editor seqeditor gpg gpgssh cred altrefs uploadpack receivepack \
  diffext diffcmd mergedrv; do mk "$n" fail; done
for n in clean smudge pager pager-cmd; do mk "$n" cat; done
mk textconv tc
for h in applypatch-msg pre-applypatch post-applypatch pre-commit pre-merge-commit prepare-commit-msg \
  commit-msg post-commit pre-rebase post-checkout post-merge pre-push pre-receive update proc-receive \
  post-receive post-update reference-transaction push-to-checkout pre-auto-gc post-rewrite \
  sendemail-validate fsmonitor-watchman p4-changelist p4-prepare-changelist p4-post-changelist \
  p4-pre-submit post-index-change; do
  printf '#!/bin/sh\ntouch "%s/hook-%s"\nexit 0\n' "$MARKS" "$h" >"$S/hookdir/$h"
  chmod +x "$S/hookdir/$h"
  cp "$S/hookdir/$h" "$R/.git/hooks/$h"
done

CFG="$R/.git/config"
if [ "$MODE" = include ]; then
  CFG="$S/included.cfg"
  : >"$CFG"
  git -C "$R" config include.path "$CFG"
fi
c() { git config -f "$CFG" "$@"; }
c core.fsmonitor "$S/bin/fsmonitor"
c core.hooksPath "$S/hookdir"
c filter.evil.clean "$S/bin/clean"
c filter.evil.smudge "$S/bin/smudge"
c diff.evil.textconv "$S/bin/textconv"
c diff.evil.command "$S/bin/diffcmd"
c diff.external "$S/bin/diffext"
c merge.evil.driver "$S/bin/mergedrv"
c core.pager "$S/bin/pager"
for p in log diff config remote ls-files check-ignore for-each-ref worktree rev-parse symbolic-ref status show; do
  c "pager.$p" "$S/bin/pager-cmd"
done
c core.sshCommand "$S/bin/ssh"
c core.gitProxy "$S/bin/gitproxy"
c core.askPass "$S/bin/askpass"
c credential.helper "!$S/bin/cred"
c core.editor "$S/bin/editor"
c sequence.editor "$S/bin/seqeditor"
c gpg.program "$S/bin/gpg"
c gpg.ssh.program "$S/bin/gpgssh"
c log.showSignature true
c core.alternateRefsCommand "$S/bin/altrefs"
c remote.origin.uploadpack "$S/bin/uploadpack"
c remote.origin.receivepack "$S/bin/receivepack"
git -C "$R" update-index --fsmonitor 2>/dev/null || true
# A staged change for the commit paths; the fixture setup itself must not count.
printf 'more\n' >>"$R/README.md"
git -C "$R" -c core.hooksPath=/dev/null -c core.fsmonitor=false -c filter.evil.clean=cat add README.md
printf 'body\n' >"$R/body.md"
mkdir -p "$R/.claude"
printf 'commit.policy: auto\npush.policy: auto\npr.policy: auto\nreview.post_policy: auto\n' >"$R/.claude/kern.local.yml"
rm -f "$MARKS"/*

# A stub gh so G2 and G3 reach their gh calls without the network.
mkdir -p "$S/ghbin"
printf '#!/bin/sh\ncase "$*" in "pr list"*) exit 0 ;; "api user"*) echo me ;; "pr view"*) echo someone ;; esac\n' >"$S/ghbin/gh"
chmod +x "$S/ghbin/gh"

export HOME="$S/home" CLAUDE_PLUGIN_DATA="$S/data" CLAUDE_PLUGIN_ROOT="$K"
unset CLAUDE_CODE_ENTRYPOINT
export PATH="$S/ghbin:$PATH"
mkdir -p "$S/data/sessions"

payload() { printf '{"session_id":"t","cwd":"%s","hook_event_name":"%s",%s}' "$R" "$1" "$2"; }
bashp() { payload PreToolUse "\"tool_name\":\"Bash\",\"permission_mode\":\"default\",\"tool_input\":{\"command\":\"$1\"}"; }

step() {
  local name="$1" hook="$2" input="$3"
  rm -f "$MARKS"/*
  out=$(bash "$K/hooks/$hook" <<<"$input" 2>&1)
  printf '%-34s %s\n' "$name" "$(ls "$MARKS" | paste -sd' ' -)"
  ls "$MARKS" >>"$S/all-marks"
  printf '%s\n' "$out" | head -c 300 >"$S/out-$name.txt"
}

step session-start session-start "$(payload SessionStart '"source":"startup"')"
step subagent-start subagent-start "$(payload SubagentStart '"agent_id":"a","agent_type":"Explore"')"
step prompt-submit prompt-submit "$(payload UserPromptSubmit '"prompt":"hello"')"
step commit-m pre-tool-use "$(bashp 'git commit -m x')"
step commit-amend pre-tool-use "$(bashp 'git commit --amend --no-edit')"
step commit-F pre-tool-use "$(bashp 'git commit -F body.md')"
step push-feat pre-tool-use "$(bashp 'git push origin feat')"
step push-lease pre-tool-use "$(bashp 'git push --force-with-lease origin feat')"
step push-bare pre-tool-use "$(bashp 'git push')"
step pr-create pre-tool-use "$(bashp 'gh pr create --draft --title t --body-file body.md')"
step pr-review pre-tool-use "$(bashp 'gh pr review 1 --approve --body-file body.md')"
printf 'voice: normal\nsurface: auto\nautopilot: on\nsince: 2026-10-12T00:00:00Z\n' >"$S/data/sessions/t.state"
step ap-commit-m pre-tool-use "$(bashp 'git commit -m x')"
step ap-push-feat pre-tool-use "$(bashp 'git push origin feat')"
step ap-pr-create pre-tool-use "$(bashp 'gh pr create --draft --title t --body-file body.md')"
echo "ALL MARKS: $(sort -u "$S/all-marks" 2>/dev/null | paste -sd' ' -)"
