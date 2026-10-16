n=$'\037'
for w in "a{b" "a[b" 'a$b' 'a`b' "a${n}b" "a^b" "a#b" "/tmp/x" "rel" "~/x"; do
  case "1:$w" in
    1:*[\$\`*?[\{^#]* | 1:*"$n"* | 1:- | 1:+* | 1:=*) r=unk ;;
    *) r=other ;;
  esac
  printf '%q -> %s\n' "$w" "$r"
done
