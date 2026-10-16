load /Users/musta/Code/projects/kern/tests/helpers/common
K=/Users/musta/Code/projects/kern
t() { { printf '%s\n' "$1"; cat $K/hooks/pre-tool-use; } > $BATS_TEST_TMPDIR/h; run need_lists_match $BATS_TEST_TMPDIR/h; echo "[$1] => $status" >&3; }
@test probes {
 t '. "${KERN_ROOT}/hooks/lib/json.sh"'
 t '# . "$KERN_ROOT/hooks/lib/json.sh"'
 t 'x=1 . "$KERN_ROOT/hooks/lib/json.sh"'
 t '. "$KERN_ROOT/hooks/lib/json.sh"; . "$KERN_ROOT/hooks/lib/extra.sh"'
 t 'd=$KERN_ROOT/hooks; . "$d/lib/json.sh"'
 t '. "$KERN_ROOT/hooks/lib/$lib.sh"'
 t '. $KERN_ROOT/hooks/lib/json.sh'
 t "eval '. \$KERN_ROOT/hooks/lib/json.sh'"
 t 'source "$KERN_ROOT/hooks/lib/json.sh"'
}
