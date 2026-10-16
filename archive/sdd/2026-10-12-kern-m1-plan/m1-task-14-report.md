# M1 Task 14 report (saved by the controller from the implementer's reply)

Status: DONE. Commit 87ba6a1 "M1: add the mode and autopilot skills". skills-control.test.mjs 4/4; lint clean; node 50/50. RED: ENOENT skills/mode/SKILL.md, pass 0, fail 4. GREEN: pass 4, lint clean. Only deviation: the two ordered bullets after the commit bullet in skills/autopilot/SKILL.md, with a second -m paragraph naming them. scripts/kern-dir checked: takes a name such as msg, creates <main root>/<work_dir>/msg and prints the absolute path.

## Fix round 1: 3966994

Commit 3966994 "M1: state the exact shapes autopilot allows". skills-control 4/4, lint clean. Claims checked against g01-git.sh, g02-pr.sh, g05-commit.sh and decide.sh; corrections: exactly one -m or -F; a pathspec is denied; a head with an open PR is denied; the draft PR must be from the current branch; "denied" holds for merged/closed heads (ask becomes deny under autopilot). Step 4 drops "since when".
