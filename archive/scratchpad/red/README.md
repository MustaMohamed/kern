# kern

A personal Claude Code plugin that routes work through a small always-on kernel, enforces safety with guard hooks, and defers to each project's own rules and skills.

## Install

1. `gh auth login`
2. In Claude Code: `/plugin marketplace add <owner>/kern`, then `/plugin install kern@kern` at user scope.
3. Optional: restore `~/.claude/kern.yml`. Per project, run `/kern:help setup` when the defaults are not enough.

## Develop

Clone to the path named by `kern_repo` in `~/.claude/kern.yml` and run `claude --plugin-dir <path>`. Run `scripts/ci-local` before pushing.

## Documents

- Design: `docs/specs/2026-10-12-kern-design.md`
- Skill specs for M1 and M2: `docs/specs/2026-10-12-kern-m1-m2-skills.md`
- Plans: `docs/plans/`
