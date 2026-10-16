K=/Users/musta/Code/projects/kern/skills/diagnose/scripts
FP() { /bin/bash $K/find-polluter.sh "$@"; }
LR() { /bin/bash $K/loop-rate.sh "$@"; }
mkdir t; echo true > t/a.sh; echo 'touch polluted' > t/b.sh; echo true > "t/sp ace.sh"
echo "--glob none"; FP polluted 'x/*.sh' -- sh; echo rc=$?
echo "--TEST_CMD missing"; FP polluted 't/*.sh' -- nosuchcmd; echo rc=$?
echo hi > notexec; touch fakecmd; chmod -x fakecmd
echo "--non-exec file"; FP polluted 't/*.sh' -- ./notexec; echo rc=$?; rm -f polluted
echo "--non-exec 2 (fakecmd)"; FP polluted 't/*.sh' -- ./fakecmd; echo rc=$?; rm -f polluted
echo "--space + polluter"; FP polluted 't/*.sh' -- sh; echo rc=$?; rm -f polluted
echo "--unrelated failing test"; printf 'exit 1\n' > t/a.sh; FP polluted 't/*.sh' -- sh; echo rc=$?; rm -f polluted
echo "--cmd always fails, no pollution"; rm t/b.sh; FP polluted 't/*.sh' -- sh -c 'exit 5' x; echo rc=$?
echo "--cmd bad script path"; FP polluted 't/*.sh' -- sh -c 'exit 127' x; echo rc=$?
echo "--**"; mkdir -p d/e; echo 'touch polluted' > d/e/x.test.js; echo true > d/y.test.js; FP polluted 'd/**/*.test.js' -- sh; echo rc=$?; rm -f polluted
echo "--newline filename"; mkdir nl; printf 'true' > "nl/a
b.sh"; FP polluted 'nl/*.sh' -- sh; echo rc=$?
echo "--dir pollution"; echo 'mkdir pd' > d/y.test.js; FP pd 'd/*.test.js' -- sh; echo rc=$?; rm -rf pd
echo "--dangling symlink preexisting"; ln -s nowhere dl; FP dl 'd/*.test.js' -- sh; echo rc=$?; rm dl
echo "--glob ./ prefix"; FP polluted './t/*.sh' -- sh; echo rc=$?
echo "---LR"
for a in "0 -- true" "00 -- true" "003 -- true" "abc -- true" "-1 -- true" "1.5 -- true" "1000000000 -- true" "999999999x -- true" "3 true" "3 --" "2 -- nosuch" "3 -- false" "4 -- true" "010 -- true"; do echo "[$a]"; LR $a; echo rc=$?; done
echo "--127 inside"; LR 2 -- sh -c 'exit 127'; echo rc=$?
echo "--noexec"; LR 2 -- ./fakecmd; echo rc=$?
printf 'n=$(cat c 2>/dev/null||echo 0); n=$((n+1)); echo $n>c; case $n in 1) sleep 0.1;; 2) sleep 0.5;; 3) sleep 0.3;; 4) sleep 0.2;; esac\n' > sl.sh
rm -f c; LR 3 -- sh sl.sh; rm -f c; LR 4 -- sh sl.sh; rm -f c
echo "--stderr noise"; LR 2 -- sh -c 'echo x >&2; echo 0.5 >&2'; echo rc=$?
echo "--stdin"; LR 2 -- cat </dev/null; echo rc=$?
echo "--tmp leak"; ls ${TMPDIR:-/tmp} | grep -c kern-loop
echo "--HITL"; cp $K/hitl-loop.template.sh h.sh; printf '\ny\r\nboom\r\n' | /bin/bash h.sh | od -c | tail -5
