#!/bin/bash
T33=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t33r
. "$T33/harness.sh"
setup_env >/dev/null
HC=$HOME/.claude; mkdir -p "$HC/agents"; echo '{}' >"$HC/settings.json"
mkdir -p "$W/tmpd"; ln -s "$HC" "$W/tmpd/linkc"; ln -s "$HC/agents" "$W/lnkagents"
autopilot on
for spec in "$W/wt|cd $W/tmpd && cd linkc && sed -i '' s/a/b/ settings.json" "$W/wt|cd $W/tmpd/linkc && sed -i '' s/a/b/ settings.json" \
  "$W/lnkagents|cd -P .. && sed -i '' s/a/b/ settings.json" "$W/lnkagents|cd .. && sed -i '' s/a/b/ settings.json" \
  "$W/lnkagents|sed -i '' s/a/b/ ../settings.json"; do
  export CWD=${spec%%|*}; c=${spec#*|}
  for pair in "b35 h35b" "h35 h35b"; do set -- $pair; BASE=$T33/$1; HEAD=$T33/$2
    printf 'cwd=%s %s->%s ' "${CWD#$W/}" "$1" "$2"; cmp2 "$c" | head -1 | sed "s#$W#W#g" | cut -c1-130; done
done
D=$W/z; mkdir -p "$D"; ln -s "$HC/agents" "$D/la"
( cd "$D/la" && /bin/zsh -fc 'cd -P .. && pwd' | sed "s#$W#W#"; cd "$D/la" && /bin/zsh -fc 'cd .. && pwd' | sed "s#$W#W#" )
