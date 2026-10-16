node scripts/route-eval.mjs >/tmp/t30out 2>&1; c=$?; echo "exit=$c | $(grep -E '^error|FAILED|passed|TypeError|Error' /tmp/t30out | head -2 | tr '\n' ' ' | head -c 230)"
