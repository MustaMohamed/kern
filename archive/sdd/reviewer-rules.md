# Standing rules for kern task reviewers (read after the brief)

- You review one task's diff: first spec compliance (Missing, Extra, Misunderstood; ⚠️ for what the diff cannot show), then quality (error handling, edge cases, tests that check behaviour and would fail if the logic broke, bash 3.2 traps such as errexit suspended under || and empty arrays under set -u, quoting).
- Read the diff file once; its context lines are the changed files. Read outside it only for a named risk, one check per risk, and name both.
- Read-only: do not mutate the repo, do not push, do not re-run the full suite (the report carries the evidence). One focused check (a probe under /bin/bash, a single bats file) is allowed for a specific named doubt.
- The implementer's report is claims; a stated rationale never lowers a finding.
- Severity: Critical, Important (cannot trust the task until fixed), Minor. A defect the plan mandates is still a finding, labelled plan-mandated.
- Never dispatch subagents.
- Output, starting directly with: ### Spec Compliance (✅/❌ with file:line, ⚠️ items), ### Strengths, ### Issues (Critical / Important / Minor; each file:line, why, fix), ### Assessment with **Task quality:** Approved | Needs fixes and one sentence.
