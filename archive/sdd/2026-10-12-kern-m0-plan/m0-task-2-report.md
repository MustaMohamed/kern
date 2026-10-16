# M0 Task 2 report: fetch-upstream

Status: DONE

Implemented scripts/fetch-upstream and tests/scripts/fetch-upstream.bats verbatim from the brief.

RED: `bats tests/scripts/fetch-upstream.bats` before the script existed: 1..7, tests 1-6 `not ok` (script missing, status 127), including test 2 "No such file or directory". Test 7 (unknown key exits 2) also failed or passed vacuously per bats; all six listed failed as shown.

GREEN: same command after the script: 7 `ok` lines (1..7). `shellcheck scripts/fetch-upstream` printed nothing, exit 0.

Step 5 real fetch (`bash scripts/fetch-upstream`, exit 0):
superpowers: https://github.com/obra/superpowers.git @ 5bf4e78011075bcfc0dc295f0724994cd123ee71
pstack: https://github.com/cursor/plugins.git @ 11713c6
pocock: https://github.com/mattpocock/skills.git @ 49dd158
addy: https://github.com/addyosmani/agent-skills.git @ 1be8e34
caveman: copied
local: copied
`ls .upstream`: addy caveman local pocock pstack superpowers. Superpowers cloned from git; no cache fallback, so nothing to record in UPSTREAM.md.

Files: scripts/fetch-upstream (executable), tests/scripts/fetch-upstream.bats.
Concerns: none. .upstream/ is gitignored (status clean of it).
