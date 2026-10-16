#!/bin/bash
T33=/private/tmp/claude-501/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0/scratchpad/t33r
. "$T33/harness.sh"; HEAD=$T33/head3
setup_env >/dev/null
SD="$CLAUDE_PLUGIN_DATA/sessions"; mkdir -p "$SD"; CACHE="$SD/aliases.cache"
SNAP="$W/snap.sh"; cp "$T33/real-snap.sh" "$SNAP"
export CWD="$W/wt"
load() { KERN_SHELL_SNAPSHOT="$SNAP" perl -e 'alarm 5; exec @ARGV' /bin/bash -c '. "$1/hooks/lib/state.sh"; . "$1/hooks/lib/aliases.sh"; aliases_load; n=0; for v in ${!_KA_@}; do n=$((n+1)); done; echo $n' _ "$HEAD"; }
load >/dev/null; cp "$CACHE" "$W/valid.cache"
echo "== A5 TOCTOU: a FIFO renamed over the cache while 400 loads run"
( i=0; while [ -e "$W/race.on" ]; do cp "$W/valid.cache" "$SD/.v$i"; mv -f "$SD/.v$i" "$CACHE"; mkfifo "$SD/.f$i"; mv -f "$SD/.f$i" "$CACHE"; i=$((i+1)); done ) &
touch "$W/race.on"; hang=0; ok=0; other=0
for i in $(seq 400); do out=$(load); rc=$?; if [ $rc = 142 ]; then hang=$((hang+1)); elif [ "$out" = 205 ]; then ok=$((ok+1)); else other=$((other+1)); fi; done
rm -f "$W/race.on"; wait
echo "loads: 205 entries=$ok hung(alarm 5 s)=$hang other=$other"
rm -f "$CACHE"
echo "== A6 symlink swapped in for the mktemp file, 300 cold loads"
VICTIM="$W/victim.txt"; echo ORIGINAL >"$VICTIM"
( while [ -e "$W/race6.on" ]; do for f in "$SD"/.aliases.cache.*; do [ -f "$f" ] && [ ! -L "$f" ] && ln -sf "$VICTIM" "$f" 2>/dev/null; done; done ) &
touch "$W/race6.on"
for i in $(seq 300); do rm -f "$CACHE"; load >/dev/null; done
rm -f "$W/race6.on"; wait
echo "victim now: $(head -c 60 "$VICTIM" | head -1 | cut -c1-40) ($(wc -c <"$VICTIM") bytes); cache is symlink: $([ -L "$CACHE" ] && echo yes || echo no); stray tmp: $(ls -A "$SD" | grep -c '^\.aliases')"
rm -f "$CACHE"
echo "== A7 a read-only state dir with a planted cache; a symlinked state dir; a symlinked cache"
load >/dev/null; cp "$CACHE" "$W/good.cache"
printf "%s\n" "$(head -1 "$W/good.cache")" "$(printf '%s' gst | od -An -tx1 | tr -d ' \n')	git push --force" >"$CACHE"
chmod 555 "$SD"; echo "read-only dir, planted cache: entries=$(load) (1 = planted cache read)"; chmod 755 "$SD"
rm -f "$CACHE"; chmod 555 "$SD"; echo "read-only dir, no cache: entries=$(load); cache written: $([ -e "$CACHE" ] && echo yes || echo no)"; chmod 755 "$SD"
mv "$SD" "$W/real-sessions"; ln -s "$W/real-sessions" "$SD"; cp "$W/good.cache" "$W/real-sessions/aliases.cache"
printf "%s\n" "$(head -1 "$W/good.cache")" "6762	git push --force" >"$W/real-sessions/aliases.cache"
echo "symlinked state dir with a planted one-entry cache: entries=$(load) (205 = not read)"; rm "$SD"; mv "$W/real-sessions" "$SD"
printf "%s\n" "$(head -1 "$W/good.cache")" "6762	git push --force" >"$W/planted.cache"; rm -f "$CACHE"; ln -s "$W/planted.cache" "$CACHE"
echo "symlinked cache: entries=$(load) (205 = not read); planted untouched: $(wc -l <"$W/planted.cache") lines; cache still symlink: $([ -L "$CACHE" ] && echo yes || echo no)"
rm -f "$CACHE"
echo "== A8 twenty hooks at once, cold"
for i in $(seq 20); do (cmp_cmd "gpf! origin main" "$SNAP" >"$W/par.$i") & done; wait
echo "decisions: $(cat "$W"/par.* | awk '{print $3}' | sort | uniq -c | tr '\n' ' ')"
echo "cache header ok: $([ "$(head -1 "$CACHE")" = "$(head -1 "$W/good.cache")" ] && echo yes || echo no); body equal: $(cmp -s "$CACHE" "$W/good.cache" && echo yes || echo no); stray tmp: $(ls -A "$SD" | grep -c '^\.aliases')"
echo "== A9 same size, same mtime second: an edit the cache does not see"
printf "%s\n" "alias -- gx='git status --short'" >"$SNAP"; touch -t 202610160300.00 "$SNAP"; rm -f "$CACHE"
autopilot on
echo "before edit: $(cmp_cmd 'gx origin main' "$SNAP" | head -1)"
printf "%s\n" "alias -- gx='git push --force x'" >"$SNAP"; touch -t 202610160300.00 "$SNAP"
echo "after same-size edit, mtime restored (warm cache): $(cmp_cmd 'gx origin main' "$SNAP" | head -1)"
echo "same, cold cache: $(COLD=1 cmp_cmd 'gx origin main' "$SNAP" | head -1)"
echo "ctime before/after is visible: $(stat -f '%c %i' "$SNAP")"
