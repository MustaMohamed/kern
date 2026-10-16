# kern working archive, 2026-10-16

This orphan branch holds everything about kern that lived outside the repo's tracked files when M2a was paused: the claude.ai artifacts, the subagent-driven-development (SDD) ledgers and review records, the controller's scratch files, and the memory note. The code itself is not here; it is on `main` (local) and on `origin/backup/m1-wip`, both at `6ed3abd`.

## State at the pause

- M2a: Tasks 1 to 33 and the added Task 35 are complete and reviewed. Task 34 (CI and release 0.3.0) has not started.
- `main` is not pushed to `origin/main`. It is pushed only with release 0.3.0, on the user's yes.
- The exact resume steps are the PAUSE block at the end of `archive/sdd/2026-10-14-kern-m2a-plan/progress.md`.

## What is where

| Path | What it holds |
| --- | --- |
| `archive/artifacts/personal-agent-framework-design/index.html` | Design, rev 5. Was https://claude.ai/artifact/NQ55fRJA1WU39Finrs3evj |
| `archive/artifacts/kern-design-spec/index.html` | Design spec page. Was https://claude.ai/artifact/LdSz6NWBLx2j2cU7V3dwgh |
| `archive/artifacts/kern-build-plans/` | M0, M1 and M2 plans page, plus its attached Markdown: `plans/` (M0, M1, M2 plans, contract) and `specs/` (design, M1 and M2 skills). Was https://claude.ai/artifact/XGwZDKqHwCbmuhRmSUZr3S |
| `archive/artifacts/kern-m2a-plan/index.html` | M2a plan page the user approved. Was https://claude.ai/artifact/BeqNDcNn8dc8PReimxfov6 |
| `archive/artifacts/kern-build-progress/index.html` | Progress report. Was https://claude.ai/artifact/LzghDNfJ98dASp8HHMLqPT |
| `archive/artifacts/kern-m1-milestone/index.html` | M1 milestone report. Was https://claude.ai/artifact/1TAoyi4Ku88E4uz44oRhCF |
| `archive/sdd/` | A copy of the repo's gitignored `.superpowers/sdd/`: the M0, M1 and M2a ledgers (`progress.md`), task briefs, implementer reports, review diffs, the M2 pre-flight, goal-0 review and source audit, the resume notes, and the implementer and reviewer rules |
| `archive/scratchpad/` | The controller's session scratch files: every task review and re-review (`task-NN-review.md`, `task-NN-rereview-N.md`), ci-local and hook-suite logs, the exec-eval run log, corpora lists and harness scripts (`t33r/`, `t35/`, `t35b/`), patches, and the progress and M2a plan page sources (`kern-progress/`, `kern-m2a-plan/`). Only files under 1 MB, at most one folder deep: the scratch repo copies and mutation trees were left out |
| `archive/memory/kern-framework.md` | The Claude Code memory note about kern |
| `archive/evals-snapshots/exec-2026-10-15.json` | The first exec-eval run (tree `f928642`): 5 PASS, the split case FAIL from the eval's own fixture bug, fixed later in `a4defd7` and `bf1ebbb`. Not the release snapshot; Task 34 writes that one |

The artifact pages are standalone HTML; open them in a browser. The artifact copies on claude.ai stay where they were; these are snapshots of their latest versions.

## Not in this archive

- **The session transcript.** It is at `~/.claude/projects/-Users-musta-Code-projects-cds-cds-app-rewrite/f869eca6-5423-48df-a8fd-cb9929a686e0.jsonl` on the machine that ran it. It also holds unrelated CDS work, so it was not copied into a personal repo.
- **`.upstream/`** (the five source plugins, 59 MB). It is gitignored and rebuilt by `scripts/fetch-upstream`.
- **The CDS workflow framework audit** (the CDS evaluation that preceded kern). It holds CDS-internal detail, so it is kept only locally, at `.superpowers/archive-local/cds-workflow-audit.html` in the kern checkout. It was https://claude.ai/artifact/ErVxPJy8h88nJaKTD6DZMv
- **The scratch repo copies, mutation trees and full corpus result folders** (about 1.6 GB). The scripts and lists that produced them are in `archive/scratchpad/`.

## Resume on another machine or account

```bash
git clone https://github.com/MustaMohamed/kern.git && cd kern
git switch -C main origin/backup/m1-wip        # local main at the backup tip, 6ed3abd
git fetch origin archive/kern-backup-2026-10-16
git worktree add ../kern-archive archive/kern-backup-2026-10-16
mkdir -p .superpowers && cp -R ../kern-archive/archive/sdd .superpowers/sdd
scripts/fetch-upstream                           # rebuilds .upstream/
```

Then read the PAUSE block at the end of `.superpowers/sdd/2026-10-14-kern-m2a-plan/progress.md` and continue with Task 34.
