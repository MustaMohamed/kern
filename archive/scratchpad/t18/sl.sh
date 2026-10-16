n=$(cat c 2>/dev/null||echo 0); n=$((n+1)); echo $n>c; case $n in 1) sleep 0.1;; 2) sleep 0.5;; 3) sleep 0.3;; 4) sleep 0.2;; esac
