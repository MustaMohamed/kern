node scripts/route-eval.mjs >/tmp/t30out 2>&1; echo "exit=$? $(tail -1 /tmp/t30out | head -c 120)"
