#!/bin/bash
T33=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t33r
. "$T33/harness.sh"
setup_env >/dev/null
mkdir -p "$R/.claude"; printf 'push.policy: auto\n' >"$R/.claude/kern.local.yml"
git -C "$W/wt" -c user.email=other@example.com -c user.name=Other commit -q --allow-empty -m "other: work"
git -C "$W/wt" push -q origin feat >/dev/null 2>&1
O="$W/other"; make_repo "$O" >/dev/null 2>&1
export CWD="$W/wt"
for mode in off on; do
  autopilot "$mode"
  for c in "git push --force-with-lease origin feat" "cd $O && git push --force-with-lease origin feat" \
    "cd /tmp; git push --force-with-lease origin feat" "noglob cd $O && git push --force-with-lease origin feat" \
    "env -C $O git push --force-with-lease origin feat" "git --git-dir=$O/.git push --force-with-lease origin feat" \
    "git --work-tree=$O push --force-with-lease origin feat" "cd $O && git -C $W/wt push --force-with-lease origin feat" \
    "cd $O && git push origin main" "git push -u origin feat" "cd . && git push -u origin feat" "cd $O && git push -u origin feat" \
    "coproc cd $O; git push --force-with-lease origin feat" "cd $O && git push --force origin feat" "cd $O && git push origin :feat"; do
    for pair in "b35 h35b" "h35 h35b"; do
      set -- $pair; BASE=$T33/$1; HEAD=$T33/$2
      printf '%s %-4s->%-5s ' "$mode" "$1" "$2"; cmp2 "$c" | head -1 | sed "s#$W#W#g" | cut -c1-150
    done
  done
done
