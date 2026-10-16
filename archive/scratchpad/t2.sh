LS=$'\305\277'; KV=$'\342\204\252'
cmd=$'a\\\r\nb c\\\nd e'"${LS}x${KV}y"
t=${cmd//\\$'\r\n'/}
t=${t//\\$'\n'/}
t=${t//$LS/s}
t=${t//$KV/k}
printf '%s' "$t" | od -c | head -3
w='hoo{ks/prompt-sub,x}mit'
case "$w" in *'{'*/*'}'*) case "$w" in *'{'*,*'}'* | *'{'*..*'}'*) echo brace-hit ;; esac ;; esac
