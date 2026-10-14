# floor-scan's program. Load after test-paths.awk (is_test). Reads a unified git diff; prints
# path:line<TAB>class<TAB>text per hit and exits 1 on any hit. ENVIRON["RATCHETS"] holds
# metric<TAB>path<TAB>key<TAB>min|max lines from ratchet.<metric> settings.
# Patterns adapted from addyosmani/agent-skills constraint-driven-development/references/floor-guard.md (MIT).
function is_doc(p) { return p ~ /\.(md|mdx|txt|rst|adoc)$/ }
function is_ci(p) { return p ~ /(^|\/)\.github\/workflows\/[^\/]+\.ya?ml$|(^|\/)\.gitlab-ci\.ya?ml$|(^|\/)\.circleci\/config\.ya?ml$|(^|\/)azure-pipelines\.ya?ml$|(^|\/)Jenkinsfile$/ }
function is_lintcfg(p) { return p ~ /(^|\/)(\.eslintrc[^\/]*|eslint\.config\.[a-z]+|biome\.jsonc?|\.rubocop\.ya?ml|ruff\.toml|\.flake8|setup\.cfg|pyproject\.toml|\.golangci\.ya?ml)$/ }
function is_tscfg(p) { return p ~ /(^|\/)tsconfig[^\/]*\.json$/ }
function norm(s) { gsub(/[ \t]/, "", s); gsub(/"/, "'", s); sub(/[;,]+$/, "", s); return s }
function hit(p, ln, cls, txt) {
  sub(/^[ \t]+/, "", txt)
  if (length(txt) > 120) txt = substr(txt, 1, 120)
  printf "%s:%d\t%s\t%s\n", p, ln, cls, txt
  hits++
}
# thr(t): sets K and V to a threshold key and its number found in t; returns 1 when found.
function thr(t, keys,   s) {
  if (!match(t, "(" keys ")[\"']?[ \t]*[:=][ \t]*[0-9]+(\\.[0-9]+)?")) return 0
  s = substr(t, RSTART, RLENGTH)
  K = s; sub(/["']?[ \t]*[:=].*/, "", K)
  V = s; sub(/^.*[:=][ \t]*/, "", V)
  return 1
}
function added_line(p, ln, t) {
  if (is_doc(p)) return
  if (t ~ /@ts-ignore|@ts-nocheck|@ts-expect-error|eslint-disable|biome-ignore|#[ ]*noqa|#[ ]*type:[ ]*ignore|istanbul ignore|c8 ignore|nosemgrep|gitleaks:allow|Stryker disable|@SuppressWarnings|\/\/[ ]*nolint|NOLINT|pylint:[ ]*disable|rubocop:disable|pyright:[ ]*ignore|pragma:[ ]*no cover|#[ ]*nosec|#\[allow\(|(^|[^A-Za-z_])as[ \t]+any([^A-Za-z0-9_]|$)|as[ \t]+unknown[ \t]+as[ \t]/) hit(p, ln, "silenced-checker", t)
  if (t ~ /\.(skip|todo)[(.]|(^|[^A-Za-z0-9_.])(xit|xdescribe|xtest|fit|fdescribe)\(|\.only\(|@pytest\.mark\.(skip|xfail)|t\.Skip\(|@Disabled|@Ignore|#\[ignore\]/) hit(p, ln, "test-made-easier", t)
  if (t ~ /catch[ ]*(\([^)]*\))?[ ]*\{[ ]*\}|except[^:]*:[ ]*pass[ ]*$|(^|[^A-Za-z])(TODO|FIXME)([^A-Za-z]|$)|[Nn]ot implemented|unimplemented!\(|todo!\(/) hit(p, ln, "unfinished-work", t)
  if (t ~ /console\.(log|debug|trace)\(|(^|[^A-Za-z0-9_.])debugger([^A-Za-z0-9_]|$)|(^|[^A-Za-z0-9_.])print\(|fmt\.Print(ln|f)?\(|binding\.pry|byebug|var_dump\(|dbg!\(|\[kern-dbg\]/) hit(p, ln, "debug-print", t)
  if (is_ci(p) && t ~ /continue-on-error:[ \t]*true|allow_failure:[ \t]*true|\|\|[ \t]*(true|exit 0|:)[ \t]*$/) hit(p, ln, "bar-lowered", t)
  if (is_tscfg(p) && t ~ /"(strict|noImplicitAny|strictNullChecks|noUncheckedIndexedAccess|noImplicitReturns)"[ \t]*:[ \t]*false/) hit(p, ln, "bar-lowered", t)
  if (is_lintcfg(p) && (t ~ /:[ \t]*["']off["'][ \t]*,?[ \t]*$|:[ \t]*0[ \t]*,?[ \t]*$|Enabled:[ \t]*false|(^|[ \t])(extend-)?ignore[ \t]*=|per-file-ignores/)) hit(p, ln, "bar-lowered", t)
  if (p ~ /(^|\/)package\.json$/ && t ~ /:[ \t]*["']off["'][ \t]*,?[ \t]*$/) hit(p, ln, "bar-lowered", t)
}
# flush: the buffered lines of one file, paired so a moved or reformatted line is not a change.
function flush(   i, t, k, m, d) {
  if (file == "") return
  for (i = 1; i <= na; i++) if (!(norm(at[i]) in rset)) added_line(file, al[i], at[i])
  for (i = 1; i <= nr; i++) {
    t = rt[i]
    if (norm(t) in aset) continue
    if (is_test(file) && !deleted && t ~ /(^|[^A-Za-z_])(expect|assert|should)([^A-Za-z_]|$)/) hit(file, rl[i], "assertion-removed", t)
    if (is_ci(file) && t ~ /^[ \t]*-?[ \t]*(run|script|uses):/) hit(file, rl[i], "bar-lowered", "CI step removed: " t)
    if (is_tscfg(file) && t ~ /"strict"[ \t]*:[ \t]*true/) hit(file, rl[i], "bar-lowered", "strict removed: " t)
  }
  # Thresholds: the k-th removed and k-th added value of one key in this file, in a coverage or
  # ratchet location. min: lowering loosens; max: raising loosens.
  for (k in rk) delete rk[k]
  for (k in ak) delete ak[k]
  for (i = 1; i <= nr; i++) if (thr(rt[i], tkeys)) { rk[K]++; rv[K, rk[K]] = V }
  for (i = 1; i <= na; i++) if (thr(at[i], tkeys)) {
    ak[K]++; m = ak[K]
    if (!((K, m) in rv)) continue
    d = (K in dir) ? dir[K] : "min"
    if ((d == "min" && V + 0 < rv[K, m] + 0) || (d == "max" && V + 0 > rv[K, m] + 0))
      hit(file, al[i], "bar-lowered", ((K in metric) ? "ratchet." metric[K] : "threshold " K) " moved from " rv[K, m] " to " V)
  }
  for (k in rv) delete rv[k]
}
function newfile(   f) {
  flush()
  na = 0; nr = 0; deleted = 0; file = ""; old = ""
  for (f in aset) delete aset[f]
  for (f in rset) delete rset[f]
  for (f in dir) delete dir[f]
  for (f in metric) delete metric[f]
}
function setkeys(   i, n, r, q) {
  tkeys = (file ~ /(jest|vitest|vite|karma|nyc|c8)\.config\.[a-z]+$|(^|\/)(package\.json|\.nycrc(\.json)?|\.c8rc(\.json)?|pyproject\.toml|setup\.cfg|\.coveragerc|tox\.ini|codecov\.ya?ml)$/ || is_ci(file)) ? "branches|lines|functions|statements|fail_under|fail-under|cov-fail-under|minimum|threshold|target" : ""
  n = split(ENVIRON["RATCHETS"], r, "\n")
  for (i = 1; i <= n; i++) {
    if (split(r[i], q, "\t") < 4 || q[2] != file) continue
    tkeys = (tkeys == "" ? "" : tkeys "|") q[3]; dir[q[3]] = q[4]; metric[q[3]] = q[1]
  }
  if (tkeys == "") tkeys = "\001"
}
/^diff --git / { newfile(); inhunk = 0; next }
!inhunk && /^deleted file mode/ { deleted = 1; next }
!inhunk && /^--- / { old = substr($0, 5); sub(/^a\//, "", old); next }
!inhunk && /^\+\+\+ / {
  file = substr($0, 5); sub(/^b\//, "", file)
  if (file == "/dev/null") { file = old; if (is_test(file)) hit(file, 0, "test-deleted", "file deleted") }
  setkeys()
  next
}
!inhunk && /^@@ / {
  inhunk = 1
  split($0, a, " "); o = a[2]; nw = a[3]
  sub(/^-/, "", o); sub(/^\+/, "", nw)
  oc = (o ~ /,/) ? substr(o, index(o, ",") + 1) + 0 : 1; ol = o + 0
  nc = (nw ~ /,/) ? substr(nw, index(nw, ",") + 1) + 0 : 1; nl = nw + 0
  if (oc <= 0 && nc <= 0) inhunk = 0
  next
}
!inhunk { next }
/^\\/ { next }
/^\+/ { na++; at[na] = substr($0, 2); al[na] = nl; aset[norm(at[na])] = 1; nl++; nc-- }
/^-/ { nr++; rt[nr] = substr($0, 2); rl[nr] = ol; rset[norm(rt[nr])] = 1; ol++; oc-- }
/^ / || $0 == "" { ol++; nl++; oc--; nc-- }
inhunk && oc <= 0 && nc <= 0 { inhunk = 0 }
END { flush(); exit (hits > 0) ? 1 : 0 }
