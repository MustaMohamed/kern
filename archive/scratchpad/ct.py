p='tests/hooks/aliases.bats'; s=open(p).read()
def rep(a,b):
    global s
    assert s.count(a)==1, a[:80]; s=s.replace(a,b)
rep('''@test "with aliases loaded, no command gets a weaker decision than without them, in both modes" {
  local h c mode want got s rank_want rank_got W SD''','''@test "with aliases loaded, no command gets a weaker decision than without them, in both modes, a forged cache included" {
  local h c mode want got s rank_want rank_got W SD forged''')
rep('''  rank() { case "$(decision_of "$1")" in deny) echo 3 ;; ask) echo 2 ;; none) echo 1 ;; allow) echo 0 ;; *) echo 9 ;; esac; }''',
'''  rank() { case "$(decision_of "$1")" in deny) echo 3 ;; ask) echo 2 ;; none) echo 1 ;; allow) echo 0 ;; *) echo 9 ;; esac; }
  # A forged cache: the hostile table under a first line that matches the oh-my-zsh snapshot.
  KERN_SHELL_SNAPSHOT="$BATS_TEST_TMPDIR/omz.sh" bash "$(kern_root)/hooks/pre-tool-use" <<<"$(bash_payload ls)" >/dev/null
  forged="$BATS_TEST_TMPDIR/forged.cache"
  { head -n 1 "$SD/aliases.cache"
    bash -c '. "$1/hooks/lib/aliases.sh"; LC_ALL=C awk -v sq="'"'"'" "$_ALIASES_AWK" <"$2"' _ "$(kern_root)" "$BATS_TEST_TMPDIR/hostile.sh"
  } >"$forged"
  [ "$(wc -l <"$forged")" -gt 10 ]''')
rep('''      for s in omz hostile; do
        got=$(env KERN_GUARDS= KERN_SHELL_SNAPSHOT="$BATS_TEST_TMPDIR/$s.sh" bash "$(kern_root)/hooks/pre-tool-use" <<<"$(bash_payload "$c")")''',
'''      for s in omz hostile forged; do
        if [ "$s" = forged ]; then cp "$forged" "$SD/aliases.cache"; s=omz; fi
        got=$(env KERN_GUARDS= KERN_SHELL_SNAPSHOT="$BATS_TEST_TMPDIR/$s.sh" bash "$(kern_root)/hooks/pre-tool-use" <<<"$(bash_payload "$c")")''')
s += r'''
@test "the parsed alias table is cached in the state dir, and the next call reads the cache" {
  local c="$CLAUDE_PLUGIN_DATA/sessions/aliases.cache" first
  all "gpf! origin main"
  [ "$(decision_of "$output")" = deny ]
  [ -f "$c" ]
  first=$(head -n 1 "$c")
  [[ "$first" == "kern aliases "*$'\t'"$SNAPS/snapshot-zsh-1791935887205-ewlszo.sh"$'\t'* ]] || { echo "$first"; return 1; }
  # zz is in the cache only (7a7a is its hex): its vote shows the cache was read, not the snapshot.
  printf '%s\n7a7a\tgit push --force\n' "$first" >"$c"
  all "zz origin main"
  [ "$(decision_of "$output")" = deny ] || { echo "$output"; return 1; }
}

@test "a cache is rebuilt when the snapshot's path, size or modification time changes" {
  local c="$CLAUDE_PLUGIN_DATA/sessions/aliases.cache" f="$SNAPS/snapshot-zsh-1791978476876-cqjrpm.sh"
  snap "alias -- x='git push --force'"
  expect deny "x origin main"
  # Same size, later time.
  printf "alias -- x='git status --abc'\n" >"$f"
  touch -t 203101010000 "$f"
  expect none "x origin main"
  # Other size, same time.
  printf "alias -- x='git push --force --verbose'\n" >"$f"
  touch -t 203101010000 "$f"
  expect deny "x origin main"
  # Another snapshot path.
  printf "alias -- x='git status --abc'\n" >"$BATS_TEST_TMPDIR/other.sh"
  KERN_SHELL_SNAPSHOT="$BATS_TEST_TMPDIR/other.sh" all "x origin main"
  [ "$(decision_of "$output")" = none ] || { echo "$output"; return 1; }
  [[ "$(head -n 1 "$c")" == *$'\t'"$BATS_TEST_TMPDIR/other.sh"$'\t'* ]] || false
}

@test "a forged cache is data: substitutions and backticks in it run nothing, and lines without a hex name are skipped" {
  local c="$CLAUDE_PLUGIN_DATA/sessions/aliases.cache" m="$BATS_TEST_TMPDIR/marks" first cmd
  mkdir -p "$m"
  all ls
  first=$(head -n 1 "$c")
  # h1, h2 and h3 are 6831, 6832 and 6833.
  {
    printf '%s\n' "$first"
    printf '6831\tgit status $(touch %s/c1)\n' "$m"
    printf '6832\tgit status `touch %s/c2`\n' "$m"
    printf '$(touch %s/c3)\tgit push --force\n' "$m"
    printf 'touch %s/c4\n; touch %s/c5\n`touch %s/c6`\n' "$m" "$m" "$m"
    printf '6833\tgit push --force\n'
  } >"$c"
  for cmd in h1 h2 "h3 origin main"; do
    all "$cmd"
    [ "$(decision_of "$output")" != error ] || { echo "$cmd -> $output"; return 1; }
  done
  [ "$(decision_of "$output")" = deny ]
  run ls -A "$m"
  [ -z "$output" ] || { echo "ran: $output"; return 1; }
}

@test "a cache that cannot be written, or a symlinked cache or state dir, changes nothing" {
  local sd="$CLAUDE_PLUGIN_DATA/sessions" want
  all "gpf! origin main"
  want=$output
  [ "$(decision_of "$want")" = deny ]
  rm -rf "$sd"
  mkdir -p "$sd"
  chmod 500 "$sd"
  all "gpf! origin main"
  chmod 700 "$sd"
  [ "$output" = "$want" ] || { echo "$output"; return 1; }
  [ ! -e "$sd/aliases.cache" ]
  # A symlinked cache is replaced by a rename, never written through.
  printf 'keep\n' >"$BATS_TEST_TMPDIR/target"
  ln -s "$BATS_TEST_TMPDIR/target" "$sd/aliases.cache"
  all "gpf! origin main"
  [ "$output" = "$want" ] || { echo "$output"; return 1; }
  [ "$(cat "$BATS_TEST_TMPDIR/target")" = keep ]
  # A symlinked state dir is neither read nor written.
  rm -rf "$sd"
  mkdir -p "$BATS_TEST_TMPDIR/real-sessions"
  ln -s "$BATS_TEST_TMPDIR/real-sessions" "$sd"
  all "gpf! origin main"
  [ "$output" = "$want" ] || { echo "$output"; return 1; }
  [ ! -e "$BATS_TEST_TMPDIR/real-sessions/aliases.cache" ]
}
'''
open(p,'w').write(s)
