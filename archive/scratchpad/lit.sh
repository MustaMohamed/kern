#!/usr/bin/env bash
K=/Users/musta/Code/projects/kern
. $K/hooks/lib/json.sh; . $K/hooks/lib/settings.sh; . $K/hooks/lib/gitctx.sh; . $K/hooks/lib/decide.sh
for f in $K/hooks/guards/*.sh; do . "$f"; done
while IFS= read -r cmd; do
  _GH_LOADED=0
  _gh_load "$cmd"
  rec=${_GH_RECS[0]}
  if _gh_literal "$rec"; then lit=yes; else lit=no; fi
  toks=$(_gh_args "$rec" 2 | _gh_opts "$_GH_CREATE_OPTS")
  title=$(_gh_last "$toks" title)
  printf 'recs=%s literal=%s title=[%s]\n   cmd: %s\n' "${#_GH_RECS[@]}" "$lit" "$title" "$cmd"
done <<'CMDS'
gh pr create --draft --title "M2: add x" --base main --body-file /a/b.md
gh pr create --draft --title "M2: cost $5" --base main --body-file /a/b.md
gh pr create --draft --title "M2: use `x`" --base main --body-file /a/b.md
gh pr create --draft --title "M2: say \"hi\"" --base main --body-file /a/b.md
gh pr create --draft --title 'M2: cost $5 and `x` and "q"' --base main --body-file /a/b.md
gh pr create --draft --title 'M2: it'\''s fine' --base main --body-file /a/b.md
gh pr create --draft --title 'M2: a*b ~c {a,b}' --base main --body-file /a/b.md
gh pr create --draft --title "M2: a*b" --base main --body-file /a/b.md
CMDS
