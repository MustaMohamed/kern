# awkcount.sh TREE: awk runs of G20 alone on 110 writes after 4 maybe cds.
. /private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t35b/h.sh
setup_env >/dev/null 2>&1
mkdir -p "$W/bin"; real=$(command -v awk)
printf '#!/bin/bash\necho x >>"%s/awk.log"\nexec %s "$@"\n' "$W" "$real" >"$W/bin/awk"; chmod +x "$W/bin/awk"
c="nice cd a; nice cd b; nice cd c; nice cd d; "; for i in $(seq 1 110); do c="${c}echo x >> notes$i.md; "; done
p=$(payload_of "$c")
PATH="$W/bin:$PATH" env -u KERN_SHELL_SNAPSHOT BATS_TEST_FILENAME=x KERN_GUARDS=g20 /bin/bash "$1/hooks/pre-tool-use" <<<"$p" >/dev/null 2>&1
echo "$(basename "$1") $(wc -l <"$W/awk.log")"
