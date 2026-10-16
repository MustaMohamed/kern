p='tests/hooks/aliases.bats'; s=open(p).read()
def rep(a,b):
    global s
    assert s.count(a)==1, a[:80]; s=s.replace(a,b)
start=s.index('@test "a cache that cannot be written, or a symlinked cache or state dir, changes nothing" {')
end=s.index('\n}\n', start)+3
s=s[:start]+r'''@test "a cache that cannot be written changes nothing, and a symlinked cache or state dir is never read, even with a valid first line" {
  local sd="$CLAUDE_PLUGIN_DATA/sessions" want planted
  all "gpf! origin main"
  want=$output
  [ "$(decision_of "$want")" = deny ]
  # A cache with this snapshot's first line and an alias the snapshot lacks: zz (7a7a) runs git push --force.
  planted=$(printf '%s\n7a7a\tgit push --force' "$(head -n 1 "$sd/aliases.cache")")
  rm -rf "$sd"
  mkdir -p "$sd"
  chmod 500 "$sd"
  all "gpf! origin main"
  chmod 700 "$sd"
  [ "$output" = "$want" ] || { echo "$output"; return 1; }
  [ ! -e "$sd/aliases.cache" ]
  # A symlinked cache is not read, and a rename replaces it, so its target is never written.
  printf '%s\n' "$planted" >"$BATS_TEST_TMPDIR/target"
  ln -s "$BATS_TEST_TMPDIR/target" "$sd/aliases.cache"
  all "zz origin main"
  [ "$(decision_of "$output")" = none ] || { echo "symlinked cache read: $output"; return 1; }
  [ "$(cat "$BATS_TEST_TMPDIR/target")" = "$planted" ]
  all "gpf! origin main"
  [ "$output" = "$want" ] || { echo "$output"; return 1; }
  # A cache in a symlinked state dir is neither read nor written.
  rm -rf "$sd"
  mkdir -p "$BATS_TEST_TMPDIR/real-sessions"
  printf '%s\n' "$planted" >"$BATS_TEST_TMPDIR/real-sessions/aliases.cache"
  ln -s "$BATS_TEST_TMPDIR/real-sessions" "$sd"
  all "zz origin main"
  [ "$(decision_of "$output")" = none ] || { echo "cache in a symlinked dir read: $output"; return 1; }
  all "gpf! origin main"
  [ "$output" = "$want" ] || { echo "$output"; return 1; }
  [ "$(cat "$BATS_TEST_TMPDIR/real-sessions/aliases.cache")" = "$planted" ]
}
'''+s[end:]
rep('''@test "a cache is rebuilt when the snapshot's path, size or modification time changes" {''',
'''@test "a cache is rebuilt when the snapshot's path, size, modification time or change time changes" {''')
rep('''  # Another snapshot path.''','''  # Same size and modification time put back, edited in place: the change time differs, which counts
  # seconds, so wait for the next one.
  printf "alias -- x='git status --xyz'\\n" >"$f"
  touch -t 203101010000 "$f"
  expect none "x origin main"
  sleep 1
  printf "alias -- x='git push --force'\\n" >"$f"
  touch -t 203101010000 "$f"
  # The edit kept the size, the modification time and the inode: only the change time tells it apart.
  printf "alias -- x='git push -f -v-v-v'\\n" >"$f"
  touch -t 203101010000 "$f"
  expect deny "x origin main"
  # Another snapshot path.''')
s += r'''
@test "a cache larger than the table can be is rebuilt without reading its lines" {
  local c="$CLAUDE_PLUGIN_DATA/sessions/aliases.cache"
  all "gpf! origin main"
  [ "$(decision_of "$output")" = deny ]
  # A valid first line, then one line over the 4 MB cap.
  { head -n 1 "$c"; printf '7a7a\t'; head -c 4300000 /dev/zero | tr '\0' a; printf '\n'; } >"$c.big"
  mv "$c.big" "$c"
  all "gpf! origin main"
  [ "$(decision_of "$output")" = deny ] || { echo "$output"; return 1; }
  [ "$(wc -c <"$c")" -lt 100000 ]
}
'''
open(p,'w').write(s)
