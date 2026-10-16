b=$' \t'
x=$'  a\tb c'
x=${x#"${x%%[!"$b"]*}"}
w=${x%%["$b"]*}
printf '[%s] [%s]\n' "$x" "$w"
c='*'; case 'abc' in *"$c"*) echo bad;; *) echo ok-star;; esac
c='?'; case 'abc' in *"$c"*) echo bad;; *) echo ok-q;; esac
c='['; case 'a[c' in *"$c"*) echo ok-br;; *) echo bad;; esac
printf -v h '%02x' "'!"; echo $h
w='ab'; printf '%s %s\n' "${#w}" "${w:1:1}"
