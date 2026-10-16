#!/bin/bash
T33=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t33r
. "$T33/harness.sh"; HEAD=$T33/head3
setup_env >/dev/null
SD="$CLAUDE_PLUGIN_DATA/sessions"; mkdir -p "$SD"; CACHE="$SD/aliases.cache"
SNAP="$W/snap.sh"; cp "$T33/real-snap.sh" "$SNAP"
ALEN=$(/bin/bash -c '. "$1/hooks/lib/aliases.sh"; printf %s "${#_ALIASES_AWK}"' _ "$HEAD")
header() { printf 'kern aliases 1 %s\t%s\t%s' "$ALEN" "$1" "$(stat -f '%z %m' "$1")"; }
table() { KERN_SHELL_SNAPSHOT="$SNAP" /bin/bash -c '. "$1/hooks/lib/state.sh"; . "$1/hooks/lib/aliases.sh"; aliases_load; for v in ${!_KA_@}; do printf "%s=%s\n" "$v" "${!v}"; done | sort' _ "$HEAD"; }
for extra in 0 1; do
  /usr/bin/python3 -I - "$CACHE" "$(header "$SNAP")" "$extra" <<'PY'
import sys
path, hdr, extra = sys.argv[1], sys.argv[2], int(sys.argv[3])
cap = 4194304
body = []
total = 0
i = 0
v = "git status " + "a" * 1000
while total + len(v) + 7 < cap - 100:
    l = "%05x\t%s" % (0x10000 + i, v); body.append(l); total += len(l) + 1; i += 1
last = "6c617374\tgit push --force "
pad = cap - total - (len(last) + 1) + extra
last += "z" * pad
body.append(last); total += len(last) + 1
open(path, "w").write(hdr + "\n" + "\n".join(body) + "\n")
print("bytes after header:", total, "cap+%d" % (total - cap))
PY
  echo "last alias loaded: $(table | grep -c '^_KA_6c617374=')"
done
