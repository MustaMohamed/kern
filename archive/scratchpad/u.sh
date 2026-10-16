. hooks/lib/settings.sh; . hooks/lib/aliases.sh; . hooks/lib/gitctx.sh
export KERN_SHELL_SNAPSHOT=$1; aliases_load
for c in "X='' gpf! origin main" "X=\"a b\" Y=\$(echo a b) time gpf! origin" "X='a' 'gpf!' origin" "_ gpf! origin main" "n n n n n n n n gpf! o" "n n n n n n n n n gpf! o" "tb gpf! o" "cd /x && gst && echo y" "echo \$(gst; cd /y) && git push"; do
  printf '== %s\n' "$c"; git_words "$c" | sed -n l
done
