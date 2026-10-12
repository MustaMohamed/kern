#!/usr/bin/env bats
# tests/scripts/fetch-upstream.bats

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export KERN_UPSTREAM_DIR="$BATS_TEST_TMPDIR/up"
  REMOTE="$BATS_TEST_TMPDIR/remote"
  git init -q -b main "$REMOTE"
  git -C "$REMOTE" -c user.email=t@t -c user.name=t commit -q --allow-empty -m one
  SHA1=$(git -C "$REMOTE" rev-parse HEAD)
  git -C "$REMOTE" -c user.email=t@t -c user.name=t commit -q --allow-empty -m two
  export KERN_UPSTREAM_ADDY_URL="$REMOTE" KERN_UPSTREAM_ADDY_SHA="$SHA1"
}

@test "clones at the pinned commit" {
  run bash "$ROOT/scripts/fetch-upstream" addy
  [ "$status" -eq 0 ]
  [ "$(git -C "$KERN_UPSTREAM_DIR/addy" rev-parse HEAD)" = "$SHA1" ]
}

@test "second run is a no-op" {
  bash "$ROOT/scripts/fetch-upstream" addy
  run bash "$ROOT/scripts/fetch-upstream" addy
  [ "$status" -eq 0 ]
  [[ "$output" == *"addy: already at"* ]] || false
}

@test "missing commit exits 3 and removes the partial clone" {
  export KERN_UPSTREAM_ADDY_SHA=0000000000000000000000000000000000000000
  run bash "$ROOT/scripts/fetch-upstream" addy
  [ "$status" -eq 3 ]
  [ ! -e "$KERN_UPSTREAM_DIR/addy" ]
}

@test "copy source is copied" {
  mkdir -p "$BATS_TEST_TMPDIR/cave"; echo hi > "$BATS_TEST_TMPDIR/cave/NOTICE"
  export KERN_UPSTREAM_CAVEMAN_SRC="$BATS_TEST_TMPDIR/cave"
  run bash "$ROOT/scripts/fetch-upstream" caveman
  [ "$status" -eq 0 ]
  [ "$(cat "$KERN_UPSTREAM_DIR/caveman/NOTICE")" = hi ]
}

@test "missing copy source exits 3" {
  export KERN_UPSTREAM_CAVEMAN_SRC="$BATS_TEST_TMPDIR/nope"
  run bash "$ROOT/scripts/fetch-upstream" caveman
  [ "$status" -eq 3 ]
}

@test "a failing git source is not swallowed" {
  export KERN_UPSTREAM_ADDY_URL="$BATS_TEST_TMPDIR/no-such-remote"
  run bash "$ROOT/scripts/fetch-upstream" addy
  [ "$status" -eq 3 ]
}

@test "unknown key exits 2" {
  run bash "$ROOT/scripts/fetch-upstream" nonsense
  [ "$status" -eq 2 ]
}
