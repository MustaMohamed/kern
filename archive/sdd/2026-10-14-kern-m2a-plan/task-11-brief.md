### Task 11: `plan-check`, plans and specs linted in code

**Files:**
- Create: `scripts/plan-check`
- Test: `tests/scripts/plan-check.bats`

**Interfaces:**
- Consumes: `settings_get shared_services`, `settings_get work_dir` (M1).
- Produces:
  - `plan-check FILE`: a file with `### Task N:` headings is a plan, any other a spec. Prints `FILE:LINE: message` per problem; exit 0 clean, 1 problems, 2 usage. Plan checks: frontmatter (`status: draft|approved`, `spec:`, `commits: ask`; an approved plan also needs `approved: <date>, "<words>"` and `execution: step|inline|delegate`); the sections `## Global Constraints`, `## Review Focus`, `## File map`; tasks numbered 1 to N; per task a Files list with a backticked path, Consumes and Produces lines, a Blocked by line (`none` or `Task K`), an Acceptance line and a `Run:`/`Expected:` pair; Blocked by names earlier tasks only (so no cycle can form); two tasks that share a Files path, a `shared_services` entry both mention, or `migration` paths are ordered by Blocked by; a name a task consumes, produced by another task, comes from an earlier task that blocks it; every acceptance number of the spec (frontmatter `spec:`, `WORK/` resolved under the main worktree) is covered; no `TBD`, `TODO`, "similar to Task", "add appropriate", "fill in" or "implement later"; no long dashes or curly quotes outside code. Spec checks: `status: draft|approved|draft (parked under autopilot)`, the approval line when approved, and the sections of the spec template (`form: short` needs only Problem, Constraints, Acceptance criteria and Test seams).
  - `plan-check --graph PLAN`: after a clean lint, TSV rows `overlap<TAB>A<TAB>B<TAB><shared>` and `wave<TAB><n><TAB><task numbers>`; a wave's tasks share no file or service. execute-plan steps 2 and 4 read them.
  - `plan-check --files PLAN N`: task N's Files paths, one per line, line ranges removed, and a trailing `/**` or `/*` printed as the directory with a trailing `/` (pre-flight 1 #9); execute-plan feeds them to `wt-diff --allow-file`, which also accepts a trailing `*`.

- [ ] **Step 1: Write the failing tests**

```bash
#!/usr/bin/env bats
# tests/scripts/plan-check.bats
# Fixture plans are written one printf argument per line, so their headings stay out of column 0 of
# the kern plan that carries this file and task extractors reading that plan are not confused.

bats_require_minimum_version 1.5.0
load ../helpers/wt

setup() {
  wt_test_env
  REPO="$TMP/repo"
  make_fixture "$REPO"
  cd "$REPO"
  printf '%s\n' '---' 'status: approved' 'date: 2026-10-14' 'approved: 2026-10-14, "yes"' '---' '' \
    '## Acceptance criteria' '' '1. Parses a line.' '2. Stores it.' '3. Documents it.' > spec.md
  task() { # task N TITLE FILE CONSUMES PRODUCES BLOCKED ACCEPT
    printf '%s\n' "### Task $1: $2" '' '**Files:**' "- Create: \`$3\`" '' '**Interfaces:**' "- Consumes: $4" "- Produces: $5" '' \
      "**Blocked by:** $6" '' "**Acceptance:** $7" '' "- [ ] Step 1: Run: \`node --test\`. Expected: one failure." ''
  }
  {
    printf '%s\n' '---' 'status: approved' 'spec: spec.md' 'approved: 2026-10-14, "yes, delegate"' 'execution: delegate' 'commits: ask' '---' '' \
      '## Global Constraints' '' '- Node 22.' '' '## Review Focus' '' '1. Empty input; pinned in Task 1.' '' '## File map' '' '| Path | Task | Responsibility |' '|---|---|---|' ''
    task 1 Parser 'src/parse.js:1-20' none '`parse(text)`' none 1
    task 2 'Migration A' db/migrations/001_a.sql '`parse(text)`' '`table-a`' 'Task 1' 2
    task 3 'Migration B' db/migrations/002_b.sql none '`table-b`' 'Task 2' 2
    task 4 Docs docs/parse.md none '`docs`' none 3
  } > plan.md
}

pc() { run --separate-stderr bash "$KERN_ROOT/scripts/plan-check" "$@"; }
says() { printf '%s\n' "$output" | grep -qF -- "$1" || { echo "missing: $1"; echo "$output"; false; }; }

@test "a sound plan passes" {
  pc plan.md
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "--graph prints the overlap and the waves" {
  pc --graph plan.md
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = $'overlap\t2\t3\tmigrations' ]
  [ "${lines[1]}" = $'wave\t1\t1 4' ]
  [ "${lines[2]}" = $'wave\t2\t2' ]
  [ "${lines[3]}" = $'wave\t3\t3' ]
}

@test "--files prints a task's paths without line ranges" {
  pc --files plan.md 1
  [ "$status" -eq 0 ]
  [ "$output" = "src/parse.js" ]
}

@test "--files prints a trailing /** or /* as its directory" {
  sed -i.bak 's#^- Create: `docs/parse.md`$#- Create: `docs/**`, `tests/parse/*`#' plan.md
  pc --files plan.md 4
  [ "$status" -eq 0 ]
  [ "$output" = $'docs/\ntests/parse/' ]
}

@test "two tasks on one shared service must be ordered" {
  sed -i.bak 's/^\*\*Blocked by:\*\* Task 2$/**Blocked by:** none/' plan.md
  pc plan.md
  [ "$status" -eq 1 ]
  says "Task 2 and Task 3 share migrations, but Task 3 is not blocked by Task 2"
}

@test "a shared_services entry orders tasks that both mention it" {
  mkdir -p .claude
  printf 'shared_services: redis\n' > .claude/kern.local.yml
  sed -i.bak 's/^Docs$/Docs/; s#^- Create: `docs/parse.md`#- Create: `docs/parse.md` (flush redis)#; s#^- Create: `src/parse.js:1-20`#- Create: `src/parse.js:1-20` (redis cache)#' plan.md
  pc plan.md
  [ "$status" -eq 1 ]
  says "Task 1 and Task 4 share redis, but Task 4 is not blocked by Task 1"
}

@test "a consumer must be blocked by its producer, and cannot come first" {
  sed -i.bak 's/^\*\*Blocked by:\*\* Task 1$/**Blocked by:** none/' plan.md
  pc plan.md
  says "Task 2 consumes \`parse\` from Task 1 but is not blocked by it"
  awk 'f == 0 && $0 == "- Consumes: none" { print "- Consumes: `table-b`"; f = 1; next } { print }' plan.md.bak > plan.md
  pc plan.md
  says "Task 1 consumes \`table-b\` before Task 3 produces it"
}

@test "a task blocked by a later task, a gap in numbering and a missing Run/Expected pair are errors" {
  sed -i.bak 's/^\*\*Blocked by:\*\* none$/**Blocked by:** Task 4/; s/^### Task 4: Docs$/### Task 5: Docs/' plan.md
  pc plan.md
  [ "$status" -eq 1 ]
  says "Task 1 is blocked by Task 4, which is not an earlier task"
  says "Task 5 is out of sequence; expected Task 4"
  printf '%s\n' '### Task 6: Bare' '' '**Files:**' '- Create: `x.txt`' > bare.md
  cat plan.md bare.md > plan2.md
  pc plan2.md
  says "Task 6: no Run: and Expected: pair"
  says "Task 6: no Blocked by line"
}

@test "an acceptance criterion no task covers is an error" {
  sed -i.bak 's/^\*\*Acceptance:\*\* 3$/**Acceptance:** 1/' plan.md
  pc plan.md
  says "acceptance criterion 3 of the spec is covered by no task"
}

@test "placeholders, an unapproved approval and a missing spec are errors" {
  sed -i.bak 's/^- Node 22\.$/- Node 22. TBD/; s/^approved: .*$/approved: yes/; s/^spec: spec.md$/spec: gone.md/' plan.md
  pc plan.md
  says "placeholder: - Node 22. TBD"
  says "status: approved needs approved: with the date and the user's quoted words"
  says "spec gone.md not found"
}

@test "a spec needs its sections and an approval with the user's words" {
  printf '%s\n' '---' 'status: approved' 'approved: 2026-10-14' '---' '## Problem' '## Acceptance criteria' '1. a' > s.md
  pc s.md
  [ "$status" -eq 1 ]
  says "missing section ## Constraints"
  says "status: approved needs approved: with the date and the user's quoted words"
  printf '%s\n' '---' 'status: draft' 'form: short' '---' '## Problem' '## Constraints' '- Always: x' '## Acceptance criteria' '1. a' '## Test seams' > short.md
  pc short.md
  [ "$status" -eq 0 ]
}

@test "usage errors exit 2" {
  pc
  [ "$status" -eq 2 ]
  pc --files plan.md x
  [ "$status" -eq 2 ]
  pc none.md
  [ "$status" -eq 2 ]
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tests/run-bats tests/scripts/plan-check.bats`
Expected: every test fails; `scripts/plan-check: No such file or directory`.

- [ ] **Step 3: Write `scripts/plan-check`**

```bash
#!/usr/bin/env bash
# Lint a kern plan or spec, and read a plan's task graph, so its structure is checked in code.
# Usage: plan-check FILE              problems as FILE:LINE: message; exit 0 clean, 1 problems, 2 usage
#        plan-check --graph PLAN      after a clean lint, TSV rows: overlap<TAB>A<TAB>B<TAB>shared and
#                                     wave<TAB>N<TAB>tasks; tasks in one wave share no file or service
#        plan-check --files PLAN N    Task N's Files paths, one per line, line ranges removed; a path
#                                     ending in /** or /* is printed as its directory with a trailing /
# A file with "### Task N:" headings is a plan; any other file is a spec.
# Plan checks: frontmatter; Global Constraints, Review Focus and File map; per task Files, Interfaces
# (Consumes, Produces), Blocked by, Acceptance and a Run:/Expected: pair; tasks numbered from 1; a task
# blocked only by earlier tasks; tasks sharing a file or a shared_services entry ordered by Blocked by;
# a consumed name blocked by its producer; every spec acceptance number covered; no placeholders, long
# dashes or curly quotes. Structure checks adapted from pstack poteto-mode scripts/check-plan.mjs (MIT).
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
# shellcheck source=/dev/null
. "$here/../hooks/lib/settings.sh"
usage() { echo "usage: plan-check FILE | plan-check --graph PLAN | plan-check --files PLAN N" >&2; exit 2; }
mode=lint n=''
case "${1-}" in
  --graph) mode=graph; shift ;;
  --files) mode=files; shift ;;
esac
[ $# -ge 1 ] || usage
file=$1
if [ "$mode" = files ]; then
  [ $# -eq 2 ] || usage
  n=$2
  case "$n" in '' | *[!0-9]*) usage ;; esac
else
  [ $# -eq 1 ] || usage
fi
[ -f "$file" ] || { echo "plan-check: no such file: $file" >&2; exit 2; }

MAIN=$(kern_main_root "$PWD" 2> /dev/null) || MAIN=''
export KERN_MAIN="$MAIN"
SHARED=$(settings_get shared_services '' 2> /dev/null || true)
WD=$(settings_get work_dir .kern 2> /dev/null || echo .kern)

# Acceptance numbers of the plan's spec, when the spec: line names a file that resolves.
ACCEPT='' SPECPATH=''
spec=$(awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } NR > 1 && /^spec:/ { sub(/^spec:[ \t]*/, ""); print }' "$file")
case "$spec" in
  *.md)
    case "$spec" in WORK/*) spec="$MAIN/${WD%/}/${spec#WORK/}" ;; esac
    for c in "$spec" "$(dirname "$file")/$spec" "$MAIN/$spec"; do
      if [ -f "$c" ]; then SPECPATH=$c; break; fi
    done
    if [ -n "$SPECPATH" ]; then
      ACCEPT=$(awk '/^## / { on = ($0 ~ /^## Acceptance criteria/) ; next } on && /^[0-9]+\. / { sub(/\..*/, ""); printf "%s ", $0 }' "$SPECPATH")
    else
      ACCEPT=MISSING
    fi
    ;;
esac

DASH=$(printf '\342\200\223|\342\200\224') CURLY=$(printf '\342\200\230|\342\200\231|\342\200\234|\342\200\235') \
  MODE=$mode N=$n SHARED=$SHARED ACCEPT=$ACCEPT SPEC=$spec LC_ALL=C awk -v sq="'" '
function problem(ln, msg) { printf "%s:%d: %s\n", FILENAME, ln, msg; bad = 1 }
function spans(s, out,   k, t) {
  k = 0
  while (match(s, /`[^`]+`/)) { out[++k] = substr(s, RSTART + 1, RLENGTH - 2); s = substr(s, RSTART + RLENGTH) }
  return k
}
function first(s) { sub(/^[ \t]+/, "", s); sub(/[ \t(].*/, "", s); return s }
function has(list, x) { return index(" " list " ", " " x " ") > 0 }
BEGIN { shared_n = split(tolower(ENVIRON["SHARED"]), shared, /[ \t]*,[ \t]*/) }
NR == 1 && $0 == "---" { infm = 1; fmstart = 1; next }
infm && $0 == "---" { infm = 0; next }
infm { k = $0; sub(/:.*/, "", k); v = $0; sub(/^[^:]*:[ \t]*/, "", v); fm[k] = v; fmline[k] = NR; next }
/^[ \t]*(```|~~~)/ { fence = !fence; if (cur) text[cur] = text[cur] " " tolower($0); next }
fence { if (cur) text[cur] = text[cur] " " tolower($0); next }
{
  prose = $0; gsub(/`[^`]*`/, "", prose)
  if (prose ~ ENVIRON["DASH"]) problem(NR, "long dash")
  if (prose ~ ENVIRON["CURLY"]) problem(NR, "curly quote")
  if (prose ~ /(^|[^A-Za-z])(TBD|TODO)([^A-Za-z]|$)/ || tolower(prose) ~ /similar to task|add appropriate|fill in|implement later/) problem(NR, "placeholder: " $0)
}
/^## / { h2[$0] = 1; field = ""; if (cur) { cur = "" } }
/^### Task [0-9]+:/ {
  t = $3; sub(/:$/, "", t); t += 0
  cur = t; tasks++; order[tasks] = t; tline[t] = NR; field = ""
  next
}
!cur { next }
{ text[cur] = text[cur] " " tolower($0) }
/^\*\*Files:\*\*/ { field = "files"; nfiles[cur] += 0; next }
/^\*\*Interfaces:\*\*/ { field = "ifaces"; next }
/^\*\*Blocked by:\*\*/ {
  field = ""; seenb[cur] = 1; s = $0; sub(/^\*\*Blocked by:\*\*[ \t]*/, "", s)
  while (match(s, /Task[ \t]+[0-9]+/)) { b = substr(s, RSTART, RLENGTH); sub(/Task[ \t]+/, "", b); blk[cur] = blk[cur] " " (b + 0); s = substr(s, RSTART + RLENGTH) }
  if (blk[cur] == "" && tolower(s) !~ /none/) problem(NR, "Task " cur ": Blocked by names no task and is not none")
  next
}
/^\*\*Acceptance:\*\*/ {
  field = ""; seena[cur] = 1; s = $0; sub(/^\*\*Acceptance:\*\*[ \t]*/, "", s)
  while (match(s, /[0-9]+/)) { acc[cur] = acc[cur] " " substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH) }
  next
}
/Run:/ { run[cur] = 1 }
/Expected:/ { expect[cur] = 1 }
field == "files" && /^- (Create|Modify|Test|Delete):/ {
  k = spans($0, sp)
  for (i = 1; i <= k; i++) { p = sp[i]; sub(/:[0-9]+(-[0-9]+)?$/, "", p); sub(/\/\*\*?$/, "/", p); nfiles[cur]++; files[cur, nfiles[cur]] = p }
  next
}
field == "ifaces" && /^- Consumes:/ { k = spans($0, sp); for (i = 1; i <= k; i++) cons[cur] = cons[cur] " " first(sp[i]); seenc[cur] = 1; next }
field == "ifaces" && /^- Produces:/ { k = spans($0, sp); for (i = 1; i <= k; i++) { w = first(sp[i]); prod[cur] = prod[cur] " " w; if (!(w in producer)) producer[w] = cur }; seenp[cur] = 1; next }
END {
  if (ENVIRON["MODE"] == "files") {
    t = ENVIRON["N"] + 0
    if (!(t in tline)) { print "plan-check: no Task " t > "/dev/stderr"; exit 2 }
    for (i = 1; i <= nfiles[t]; i++) print files[t, i]
    exit 0
  }
  if (tasks == 0) {
    # A spec.
    st = fm["status"]
    if (!fmstart) problem(1, "no frontmatter")
    else if (st != "draft" && st != "approved" && st != "draft (parked under autopilot)") problem(fmline["status"] + 0, "status is draft, approved or draft (parked under autopilot), not \"" st "\"")
    if (st == "approved" && fm["approved"] !~ /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].*"[^"]+"/) problem(fmline["status"], "status: approved needs approved: with the date and the user" sq "s quoted words")
    if (fm["form"] == "short") need = "## Problem|## Constraints|## Acceptance criteria|## Test seams"
    else need = "## Problem|## Intent|## Constraints|## Assumptions|## Success criteria|## Acceptance criteria|## Decisions|## Compatibility|## Authorization|## Rollout|## Checklists|## Test seams|## Not doing|## Open questions"
    k = split(need, hs, "|")
    for (i = 1; i <= k; i++) if (!(hs[i] in h2)) problem(1, "missing section " hs[i])
    exit bad ? 1 : 0
  }
  # A plan.
  st = fm["status"]
  if (!fmstart) problem(1, "no frontmatter")
  if (st != "draft" && st != "approved") problem(fmline["status"] + 0, "plan status is draft or approved, not \"" st "\"")
  if (st == "approved") {
    if (fm["approved"] !~ /[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].*"[^"]+"/) problem(fmline["status"], "status: approved needs approved: with the date and the user" sq "s quoted words")
    if (fm["execution"] !~ /^(step|inline|delegate)$/) problem(fmline["status"], "status: approved needs execution: step, inline or delegate")
  }
  if (!("spec" in fm)) problem(1, "frontmatter has no spec: line")
  if (fm["commits"] != "ask") problem(1, "frontmatter needs commits: ask")
  k = split("## Global Constraints|## Review Focus|## File map", hs, "|")
  for (i = 1; i <= k; i++) if (!(hs[i] in h2)) problem(1, "missing section " hs[i])
  for (i = 1; i <= tasks; i++) {
    t = order[i]
    if (t != i) problem(tline[t], "Task " t " is out of sequence; expected Task " i)
    if (nfiles[t] + 0 == 0) problem(tline[t], "Task " t ": Files lists no backticked path")
    if (!seenc[t] || !seenp[t]) problem(tline[t], "Task " t ": Interfaces needs a Consumes line and a Produces line")
    if (!seenb[t]) problem(tline[t], "Task " t ": no Blocked by line")
    if (!seena[t]) problem(tline[t], "Task " t ": no Acceptance line")
    if (!run[t] || !expect[t]) problem(tline[t], "Task " t ": no Run: and Expected: pair")
    m = split(blk[t], bs, " ")
    for (j = 1; j <= m; j++) {
      if (bs[j] >= t || !(bs[j] in tline)) problem(tline[t], "Task " t " is blocked by Task " bs[j] ", which is not an earlier task")
      else { anc[t] = anc[t] " " bs[j] " " anc[bs[j]] }
    }
  }
  # Overlap: a shared file or a shared service must be ordered by Blocked by.
  for (i = 1; i <= tasks; i++) for (j = i + 1; j <= tasks; j++) {
    a = order[i]; b = order[j]; what = ""
    for (x = 1; x <= nfiles[a]; x++) for (y = 1; y <= nfiles[b]; y++) if (files[a, x] == files[b, y]) { what = files[a, x]; break }
    if (what == "") for (s = 1; s <= shared_n; s++) if (shared[s] != "" && index(text[a], shared[s]) && index(text[b], shared[s])) { what = shared[s]; break }
    if (what == "") {
      ma = 0; mb = 0
      for (x = 1; x <= nfiles[a]; x++) if (files[a, x] ~ /migration/) ma = 1
      for (y = 1; y <= nfiles[b]; y++) if (files[b, y] ~ /migration/) mb = 1
      if (ma && mb) what = "migrations"
    }
    if (what == "") continue
    ov[++novl] = a "\t" b "\t" what
    if (!has(anc[b], a)) problem(tline[b], "Task " a " and Task " b " share " what ", but Task " b " is not blocked by Task " a)
  }
  # A consumed name must come from an earlier task that blocks the consumer.
  for (i = 1; i <= tasks; i++) {
    t = order[i]; m = split(cons[t], cs, " ")
    for (j = 1; j <= m; j++) {
      w = cs[j]; if (!(w in producer)) continue
      p = producer[w]; if (p == t) continue
      if (p > t) problem(tline[t], "Task " t " consumes `" w "` before Task " p " produces it")
      else if (!has(anc[t], p)) problem(tline[t], "Task " t " consumes `" w "` from Task " p " but is not blocked by it")
    }
  }
  if (ENVIRON["ACCEPT"] == "MISSING") problem(fmline["spec"] + 0, "spec " ENVIRON["SPEC"] " not found")
  else {
    m = split(ENVIRON["ACCEPT"], need_acc, " ")
    for (j = 1; j <= m; j++) {
      ok = 0
      for (i = 1; i <= tasks; i++) if (has(acc[order[i]], need_acc[j])) ok = 1
      if (!ok) problem(fmline["spec"] + 0, "acceptance criterion " need_acc[j] " of the spec is covered by no task")
    }
  }
  if (bad) exit 1
  if (ENVIRON["MODE"] == "graph") {
    for (i = 1; i <= novl; i++) print "overlap\t" ov[i]
    maxw = 0
    for (i = 1; i <= tasks; i++) {
      t = order[i]; lv = 1; m = split(blk[t], bs, " ")
      for (j = 1; j <= m; j++) if (level[bs[j]] + 1 > lv) lv = level[bs[j]] + 1
      level[t] = lv; wave[lv] = wave[lv] (wave[lv] == "" ? "" : " ") t; if (lv > maxw) maxw = lv
    }
    for (lv = 1; lv <= maxw; lv++) print "wave\t" lv "\t" wave[lv]
  }
  exit 0
}' "$file"
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `chmod +x scripts/plan-check && tests/run-bats tests/scripts/plan-check.bats && shellcheck scripts/plan-check`
Expected: `12 tests, 0 failures`; shellcheck prints nothing.

- [ ] **Step 5: Commit**

```bash
git add -- scripts/plan-check tests/scripts/plan-check.bats
git commit -m "M2: add plan-check" -m "Plan ordering, interfaces and acceptance coverage were prose checks a reviewer could miss; a script finds the shared-file pair, the consumed-before-produced name and the uncovered criterion."
```

- [ ] **Step 6: Checkpoint**

Run: `scripts/ci-local`
Expected: last line `ci-local: all steps passed`.

---

