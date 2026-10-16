#!/bin/bash
# runatk.sh SNAPNAME CWDKIND TREE: the atk/ corpus, both modes, base 770a9f8 against TREE.
T33=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t33r
. "$T33/harness.sh"; BASE=$T33/b35; HEAD=$T33/h35
setup_env
SNAP="$T33/$1-snap.sh"
mkdir -p "$R/.claude"
printf 'push.policy: auto\ndeploy.envs: production\nprotected_targets: prod-db.internal\n' >"$R/.claude/kern.local.yml"
git -C "$W/wt" -c user.email=other@example.com -c user.name=Other commit -q --allow-empty -m "other: work"
git -C "$W/wt" push -q origin feat >/dev/null 2>&1
printf 'key = AKIA%s\n' ABCDEFGHIJKLMNOP >"$W/wt/creds.txt"; git -C "$W/wt" add creds.txt
echo '{}' >"$HOME/.claude/settings.json"
SD="$CLAUDE_PLUGIN_DATA/sessions"; mkdir -p "$SD"
case "$2" in main) export CWD="$R" ;; wt) export CWD="$W/wt" ;; esac
for mode in off on; do
  autopilot "$mode"
  for f in "$T33"/atk/c*.txt; do
    c=$(cat "$f"); c=${c//@HC@/$HOME/.claude}; c=${c//@SD@/$SD}
    out=$(cmp2 "$c" "$SNAP")
    printf '%s %s %s %s %s\n' "$1" "$2" "$mode" "$(basename "$f" .txt)" "${out//$'\n'/ // }"
  done
done
