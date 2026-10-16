#!/bin/bash
# cacheatk.sh: attacks on the alias cache of 90a9fb9 (head3). Never sources a snapshot or a cache.
T33=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t33r
. "$T33/harness.sh"; HEAD=$T33/head3
setup_env >/dev/null
SD="$CLAUDE_PLUGIN_DATA/sessions"; mkdir -p "$SD"
CACHE="$SD/aliases.cache"
M="$W/marks"; mkdir -p "$M"
git -C "$W/wt" -c user.email=other@example.com -c user.name=Other commit -q --allow-empty -m "other: work"
git -C "$W/wt" push -q origin feat >/dev/null 2>&1
printf 'key = AKIA%s\n' ABCDEFGHIJKLMNOP >"$W/wt/creds.txt"; git -C "$W/wt" add creds.txt
echo '{}' >"$HOME/.claude/settings.json"
export CWD="$W/wt"
SNAP="$W/snap.sh"; cp "$T33/real-snap.sh" "$SNAP"
ALEN=$(/bin/bash -c '. "$1/hooks/lib/aliases.sh"; printf %s "${#_ALIASES_AWK}"' _ "$HEAD")
key() { stat -f '%z %m' "$1"; }
header() { printf 'kern aliases 1 %s\t%s\t%s' "$ALEN" "$1" "$(key "$1")"; }
hexof() { printf '%s' "$1" | od -An -tx1 | tr -d ' \n'; }
# table: the _KA_ table aliases_load builds now (state.sh + aliases.sh only; the cache is read as data).
table() { KERN_SHELL_SNAPSHOT="$SNAP" /bin/bash -c '. "$1/hooks/lib/state.sh"; . "$1/hooks/lib/aliases.sh"; aliases_load; for v in ${!_KA_@}; do printf "%s=%s\n" "$v" "${!v}"; done | sort' _ "$HEAD"; }
run_set() {
  local m c
  for m in off on; do
    autopilot "$m"
    for c in "cd $HOME/.claude && ls && echo x > settings.json" "cd $SD && ls && echo x > foo" \
      "ls && git push --force-with-lease origin feat" "true; git commit -m 'feat: add creds'" \
      "gpf! origin main" "git push --force origin main" "_ _ _ _ _ _ _ _ _ gpf! origin main" "gst"; do
      printf '%s %s\n' "$m" "$(cmp_cmd "$c" "$SNAP" | sed "s#$W#W#g" | head -1)"
    done
  done
}
echo "== A1 forged cache: valid header, hostile entries"
{
  header "$SNAP"; echo
  printf '%s\t%s\n' "$(hexof ls)" 'cd / && git log' "$(hexof true)" 'cd -; git status' "$(hexof gpf!)" 'git status' \
    "$(hexof git)" 'git status' "$(hexof _)" 'sudo ' \
    "$(hexof x1)" "git status \$(touch $M/x1)" "$(hexof x2)" "git status \`touch $M/x2\`" \
    "ZZ" 'git push' "6G" 'git push' "../x" 'git push' "61 62" 'git push' "_KA_61" 'git push'
} >"$CACHE"
chmod 600 "$CACHE"
table | sed "s#$W#W#g" | cut -c1-80
run_set
echo "markers: $(ls -A "$M" | tr '\n' ' ')"
echo "cache still forged: $(head -c 40 "$CACHE" | head -1 | cut -c1-30) lines=$(wc -l <"$CACHE")"
echo "== A2 header names another snapshot"
OTHER="$W/other.sh"; printf "alias -- gpf!='git status'\n" >"$OTHER"
{ header "$OTHER"; echo; printf '%s\t%s\n' "$(hexof gpf!)" 'git status'; } >"$CACHE"
table | grep -c . ; head -1 "$CACHE" | cut -f2 | sed "s#$W#W#g"
echo "== A3 CR and NUL in the header"
{ header "$SNAP"; printf '\r\n'; printf '%s\t%s\n' "$(hexof gpf!)" 'git status'; } >"$CACHE"
echo "CR header -> gpf! is $(table | grep "^_KA_$(hexof gpf!)=" | cut -d= -f2) (rebuilt: $(head -1 "$CACHE" | od -c | grep -c '\\r'))"
{ header "$SNAP" | sed 's/aliases/ali\x00ases/'; printf '\n%s\t%s\n' "$(hexof gpf!)" 'git status'; } >"$CACHE"
echo "NUL header -> gpf! is $(table 2>&1 | grep "^_KA_$(hexof gpf!)=" | cut -d= -f2)"
{ header "$SNAP"; printf '\n6\0001\tgit push --force\n'; } >"$CACHE"
echo "NUL in a name -> $(table 2>&1 | tr '\n' ' ' | cut -c1-100)"
echo "== A4 4 MB cap"
/usr/bin/python3 -I - "$CACHE" "$(header "$SNAP")" <<'PY'
import sys
path, hdr = sys.argv[1], sys.argv[2]
cap = 4194304
lines = []
total = 0
# fill exactly to the cap with filler entries, then one more alias over it
i = 0
filler_v = "git status " + "a" * 1000
while True:
    h = "%04x" % (0x7000 + i)  # names p0.. never used
    l = len(h) + len(filler_v) + 2
    if total + l > cap - 40: break
    lines.append(h + "\t" + filler_v); total += l; i += 1
# pad to exactly cap with one entry
rem = cap - total - 40
lines.append("7a7a\t" + "git status " + "b" * (rem - 4 - 2 - 11))
total += len(lines[-1]) + 1
# 40 bytes: a final alias that crosses the cap
lines.append("676f6f6f\tgit push --force " + "c" * (40 - 8 - 2 - 17))
open(path, "w").write(hdr + "\n" + "\n".join(lines) + "\n")
print("entries", len(lines), "bytes after header", total + len(lines[-1]) + 1)
PY
echo "cache bytes: $(wc -c <"$CACHE")"
t=$(table); echo "loaded $(printf '%s\n' "$t" | grep -c .) entries; goooo(crossing)=$(printf '%s\n' "$t" | grep -c '^_KA_676f6f6f=') zz(last under cap)=$(printf '%s\n' "$t" | grep -c '^_KA_7a7a=')"
echo "== A4b one 64 MB line after a valid header"
{ header "$SNAP"; echo; printf '6162\tgit status '; head -c 67108864 /dev/zero | tr '\0' a; echo; } >"$CACHE"
s=$(/usr/bin/python3 -c 'import time;print(time.time())'); table >/dev/null; e=$(/usr/bin/python3 -c 'import time;print(time.time())')
/usr/bin/python3 -c "print('aliases_load with a 64 MB line: %.1f s' % ($e - $s))"
