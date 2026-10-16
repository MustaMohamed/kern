# hook_file HOOK: hooks/HOOK in the repo, or HOOK itself when it is a path (a test's modified copy).
hook_file() {
  case "$1" in */*) printf '%s\n' "$1" ;; *) printf '%s/hooks/%s\n' "$(kern_root)" "$1" ;; esac
}

# need_list HOOK LIB: the functions that HOOK's `need LIB ...` lines name, sorted, one per line.
need_list() {
  awk -v l="$2" '$1 == "need" && $2 == l { for (i = 3; i <= NF; i++) print $i }' "$(hook_file "$1")" | sort
}

# lib_functions LIB: the functions hooks/lib/LIB defines with `name() {`, sorted, one per line.
lib_functions() {
  sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)() {.*/\1/p' "$(kern_root)/hooks/lib/$1" | sort
}

# hook_libs HOOK: the libraries HOOK sources with a `. "$KERN_ROOT/hooks/lib/X.sh"` line.
hook_libs() {
  sed -n 's|^\. "\$KERN_ROOT/hooks/lib/\([A-Za-z0-9_-]*\.sh\)".*|\1|p' "$(hook_file "$1")"
}

# odd_lib_sources HOOK: lines that load a hooks/lib file in any form but the column-0
# `. "$KERN_ROOT/hooks/lib/X.sh"` that hook_libs reads (indented, `source`, a loop, a variable path).
odd_lib_sources() {
  grep -nE '(^|[;&|[:space:]])(\.|source)[[:space:]].*hooks/lib/' "$(hook_file "$1")" |
    grep -vE '^[0-9]+:\. "\$KERN_ROOT/hooks/lib/[A-Za-z0-9_-]+\.sh"' || true
}

# need_lists_match HOOK: HOOK loads its libraries only in the form hook_libs reads, has need lines for
# exactly those libraries, and each library's need lines name exactly the functions it defines. Prints
# the difference otherwise.
need_lists_match() {
  local libs lib odd
  odd=$(odd_lib_sources "$1")
  [ -z "$odd" ] || { echo "$1 loads a hooks/lib file in a form these checks cannot read: $odd"; return 1; }
  libs=$(hook_libs "$1")
  [ -n "$libs" ] || { echo "$1 has no source line for a hooks/lib library"; return 1; }
  [ "$(printf '%s\n' "$libs" | sort)" = "$(awk '$1 == "need" { print $2 }' "$(hook_file "$1")" | sort -u)" ] ||
    { echo "$1: its need lines and its source lines name different libraries"; return 1; }
  for lib in $libs; do
    [ -n "$(lib_functions "$lib")" ] || { echo "$lib defines no functions"; return 1; }
    [ "$(need_list "$1" "$lib")" = "$(lib_functions "$lib")" ] ||
      { echo "$1, $lib: need list differs from its definitions"; diff <(need_list "$1" "$lib") <(lib_functions "$lib"); return 1; }
  done
}

