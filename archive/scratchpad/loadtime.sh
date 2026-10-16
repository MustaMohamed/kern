. /Users/musta/Code/projects/kern/hooks/lib/aliases.sh
export KERN_SHELL_SNAPSHOT=$1
s=$(perl -MTime::HiRes=time -e 'printf "%.1f", time*1000')
for i in 1 2 3 4 5 6 7 8 9 10; do aliases_load; done
e=$(perl -MTime::HiRes=time -e 'printf "%.1f", time*1000')
echo "$(basename "$1"): aliases_load mean $(perl -e "printf '%.1f', ($e - $s) / 10") ms, KERN_ALIASES=$KERN_ALIASES"
