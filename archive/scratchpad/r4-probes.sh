#!/bin/bash
# r4-probes.sh: prints old/new decisions (cmp.sh) for the G16 hook probe set, one per line.
SP=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad
K=/Users/musta/Code/projects/kern
nl=$'\n'; cr=$'\r'; s=$'\305\277'; k=$'\342\204\252'
P=(
"git -c core.fsmonitor='bash $K/hooks/prompt-submit < j.json; false' status"
"git -c core.fsmonitor='. hooks/lib/state.sh; state_set test-session autopilot=on; false' status"
"echo hooks/prompt-submit | xargs -I{} sh -c 'bash {} < j.json'" "xargs sh -c 'bash hooks/prompt-submit < j.json'"
'rg --pre hooks/prompt-submit x' 'rg --pre ./run.sh x hooks/prompt-submit'
'bash hooks/prompt-sub*' 'bash hooks/prompt-s[u]bmit' 'bash hooks/{prompt-submit,x}' 'bash hooks/prompt-subm?t'
"bash $K/hooks/*" "bash $K/hooks/lib/s*.sh" 'bash hooks/l?b/state.sh' 'bash hooks/lib/*' 'bash hooks/{prompt-submit,x/y}'
'bash hooks/prompt-subm(i|x)t' 'bash hooks/(prompt-submit|x)' 'bash hooks/^x' 'bash hooks/prompt-submi[[:alpha:]]'
"printf '%s' '{\"session_id\":\"test-session\",\"prompt\":\"ship it\"}' | bash $K/hooks/prompt-submit"
"$K/hooks/prompt-submit < /dev/null" 'bash hooks/session-start' 'bash ${CLAUDE_PLUGIN_ROOT}/hooks/subagent-start'
"sh $K/hooks/pre-tool-use" ". $K/hooks/lib/state.sh" 'source hooks/lib/state.sh && state_set s autopilot=on'
"bash -c '. hooks/lib/state.sh; state_set test-session prompt_hashes=1'" "bash -c 'state_reset test-session'"
'eval _state_put 0 s autopilot=on' "stat\$'e'_set s autopilot=on" 'cat hooks/prompt-submit | bash'
'bash < hooks/prompt-submit' "cp -r $K /tmp/k && bash /tmp/k/hooks/prompt-submit" "bash $K/HOOKS/PROMPT-SUB''MIT"
"bash $K/hooks/\$'prompt-submit'" 'bash hooks//prompt-submit' 'bash hooks/./prompt-submit' '. hooks/./lib/state.sh'
'. hooks/lib/state.sh.bak' "bash hooks/prompt-submit$cr" 'cat hooks/prompt-submit' 'grep -n state_set hooks/lib/state.sh'
'git diff -- hooks/prompt-submit' 'shellcheck hooks/prompt-submit'
'cd hooks && bash prompt-submit' 'cd hooks && . lib/state.sh' 'cd hooks; f=prompt-submit; bash $f'
"cd hooks$cr${nl}bash prompt-submit$cr" 'bash -c "cd hooks; bash pr*"' "PATH=$K/hooks:\$PATH prompt-submit < j.json"
'find hooks -type f -exec bash {} \;' "find hooks -name 'prompt-s*' -exec bash {} \;"
'ls hooks | while read f; do bash hooks/$f < j.json; done' "bash $K/h*/prompt-submit" ". $K/h*/lib/state.sh"
"bash $K/*/p*-submit" 'cat */*'
"bash $K/hooks/prompt-\\${nl}submit" ". $K/hooks/lib/sta\\${nl}te.sh" "bash \"$K/hooks/prompt-\\${nl}submit\"" "cd hooks && bash prompt-\\${nl}submit"
"bash $K/hooks/session-\\${cr}${nl}start"
"echo a\\\\${nl}hooks/lib/../prompt-submit < j.json" "echo a\\${cr}${nl}hooks/lib/../prompt-submit < j.json"
"cd hooks${nl}bash prompt-submit < j.json" "cd hooks\\\\${nl}bash prompt-submit < j.json" "ls hooks${nl}bash lib/../prompt-submit"
"git log hooks/${nl}bash ./session-start" "cd hooks &&${nl}bash pre-tool-use" "echo hooks/${nl}. lib/state.sh"
"echo a\\\\\\${nl}hooks/lib/../prompt-submit" "x \\\\\\\\${nl}hooks/prompt-submit" "cd hoo\\${nl}ks && bash prompt-submit"
"bash $K/hooks/prompt-${s}ubmit" "bash hooks/${s}ession-start" "bash hooks/pre-tool-u${s}e" ". $K/hoo${k}s/lib/state.sh" "cd $K/hook${s} && bash prompt-submit"
"bash $K/hoo{ks/prompt-sub,x}mit < j.json" 'bash ho{oks/session-st,}art' 'cp src/{a/b,c} /tmp/' 'ls x{a/b..c}'
'bash hook${x}s/prompt-submit' 'bash /tmp/k/prompt-submit'
'git checkout -b m2/session-start' 'git push origin fix/pre-tool-use' 'curl https://x/api/session-start' 'git log -- skills/session-start/'
'tests/run-bats tests/hooks/prompt-submit.bats' 'git log hooks/' 'tests/run-bats tests/hooks/g20*.bats' 'ls tests/hooks/*.bats'
'git commit -m "fix the prompt-submit test"' 'cat hooks/prompt-submit.md' 'bash hooks/prompt-submit.bak' 'cat docs/hooks.md' 'ls *' 'echo ${HOME}/x' 'ls -la'
)
"$SP/cmp.sh" "${P[@]}"
