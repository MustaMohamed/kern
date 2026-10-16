#!/bin/bash
# runcorpus.sh SNAPNAME CWDKIND: runs corpus.txt in both modes; prints one line per comparison.
T33=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t33r
. "$T33/harness.sh"; BASE=$T33/${CBASE:-h35}; HEAD=$T33/h35d
setup_env
SNAP="$T33/$1-snap.sh"
mkdir -p "$R/.claude"
printf 'push.policy: auto\ndeploy.envs: production\nprotected_targets: prod-db.internal\n' >"$R/.claude/kern.local.yml"
for d in "$R" "$W/wt"; do
  mkdir -p "$d/docs/plans"; printf -- '---\nstatus: draft\n---\n# x\n' >"$d/docs/plans/x.md"
done
# feat has a commit by another author, so a lease push of feat is denied interactively.
git -C "$W/wt" -c user.email=other@example.com -c user.name=Other commit -q --allow-empty -m "other: work"
git -C "$W/wt" push -q origin feat >/dev/null 2>&1
printf 'key = AKIA%s\n' ABCDEFGHIJKLMNOP >"$W/wt/creds.txt"; git -C "$W/wt" add creds.txt
echo '{}' >"$HOME/.claude/settings.json"
mkdir -p "$CLAUDE_PLUGIN_DATA/sessions"
SD="$CLAUDE_PLUGIN_DATA/sessions"
case "$2" in main) export CWD="$R" ;; wt) export CWD="$W/wt" ;; esac
for mode in off on; do
  autopilot "$mode"
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    c=${line//@NL@/$'\n'}
    c=${c//@HC@/$HOME/.claude}
    c=${c//@SD@/$SD}
    c=${c//@WT@/$W/wt}
    out=$(cmp2 "$c" "$SNAP")
    printf '%s %s %s %s\n' "$1" "$2" "$mode" "${out//$'\n'/ // }"
  done <"$T33/corpus.txt"
done
