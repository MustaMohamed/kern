. "$1/hooks/lib/aliases.sh"
while IFS= read -r c; do
  printf '%s => [%s]\n' "$c" "$(printf '%s' "$c" | LC_ALL=C awk -v sq="'" "$_ALIAS_HEAD_AWK" | sed -n 2p)"
done <<'CASES'
X=$(printf "%s" a) gpf! origin main
X=$(echo "(") gpf! origin main
X=$(echo ")" ) gpf! origin main
X="$(echo "a b")" gpf! origin main
X=$(a "$(b "c d")" e) gpf! origin main
X=${Y:-"}"} gpf! origin main
X=$(a `b c` d) gpf! origin main
X='a b' Y=$(c d) time gpf! origin main
X='' 'gpf!' origin main
X=$(echo 'a ) b') gpf! origin main
CASES
