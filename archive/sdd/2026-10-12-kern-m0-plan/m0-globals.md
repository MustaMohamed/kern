# kern M0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the kern repo as a valid Claude Code plugin and marketplace with licensing, lint, routing evals and CI, all green on a placeholder skill.

**Architecture:** One git repo at `~/Code/projects/kern` that is both the plugin (`.claude-plugin/plugin.json`) and its own marketplace (`.claude-plugin/marketplace.json`, `source: "./"`). Dev tooling is zero-dependency Node ESM (`scripts/*.mjs`, tested with `node --test`) plus bash (`scripts/fetch-upstream`, tested with bats). Upstream sources that later milestones port from are cloned at pinned commits into a gitignored `.upstream/`.

**Tech Stack:** Node 22 (built-in `node:test`, no npm dependencies), bash 3.2+ (macOS default) and POSIX tools, bats-core, shellcheck, git, `gh`, Claude Code 2.1.296 (`claude plugin validate --strict`).

**Spec:** `docs/specs/2026-10-12-kern-design.md` (sections 2, 3.4, 11, 12, 14) and `docs/specs/2026-10-12-kern-m1-m2-skills.md`. Shared names and signatures: `docs/plans/contract.md`. Executors read the spec, the contract and this plan.

## Global Constraints

- Plugin name `kern`; skills invoked as `/kern:<skill>` (D-1).
- Claude Code only (D-3). Minimum Claude Code version for development: 2.1.295 (hook `onFailure` needs it); pinned in CI: 2.1.296.
- kern's own licence: MIT. Copyright line: `Copyright (c) 2026 Mustafa Mohamed`.
- Sources and pins: superpowers 6.4.1, MIT, 2025 Jesse Vincent, commit `5bf4e78011075bcfc0dc295f0724994cd123ee71`; cursor/plugins `pstack/` 0.15.17, MIT, 2026 Lauren Tan, `11713c6`; mattpocock/skills 1.3.1, MIT, 2026 Matt Pocock, `49dd158`; addyosmani/agent-skills 0.6.12, MIT, 2025 Addy Osmani, `1be8e34`; caveman 3.2.0, Apache-2.0, 2026 Julius Brussee, installed cache.
- "Caveman", "ultracave" and "megacave" are trademarks: never a name, file name, mode or skill in kern. The mode is `terse`.
- NOTICE reproduces caveman's NOTICE content (Apache-2.0 section 4d). Files modified from an Apache-2.0 source carry a header line saying they were changed. Scripts adapted from any source carry a one-line source comment. SKILL.md files carry none; the NOTICE map covers them.
- Description limits: auto skills at most 300 chars with a trigger phrase, at most 1,500 chars total; path and slash skills at most 120 chars; agents at most 150 chars; auto skills plus agents at most 2,500 chars.
- Lint rule 8: no machine paths or personal names in shipped files (`skills/`, `agents/`, `kernel/`, `modes/`, `hooks/`).
- Lint rule 11: no long dashes (U+2013, U+2014) and no curly quotes (U+2018, U+2019, U+201C, U+201D) in shipped files, `README.md` and `CHANGELOG.md`.
- Versioning: semver; Keep-a-Changelog with an `Unreleased` section; `plugin.json`, `marketplace.json` and the newest CHANGELOG release agree.
- Routing evals: every auto skill has a case file with at least 3 positive prompts, 2 negative prompts and 1 behavioural eval; the rank-1 rate floor only rises.
- Commits in this repo: subject `M0: <imperative summary>`, 72 chars or fewer; body says why; no attribution trailers; stage named paths only (`git add -- <paths>`), never `-A`. Pushes and the GitHub repo creation happen only after the user says yes.
- Prose in every file follows unslop: answer first, no filler, no long dashes, no curly quotes.

## Review Focus

1. **A skill file with Windows line endings.** A SKILL.md saved with `\r\n` must parse the same as `\n`; otherwise lint reports a missing frontmatter on a valid file. Pinned in Task 5, test `parses CRLF frontmatter`.
2. **A description that is quoted, or carries a colon.** `description: "Use when: x"` must lint by its unquoted text and length. Pinned in Task 5, test `strips quotes and keeps colons in values`.
3. **An eval prompt that shares no vocabulary with any skill.** The runner must report "shares no vocabulary", not crash on a zero vector or divide by zero. Pinned in Task 7, test `zero-score prompt is an error, not a crash`.
4. **A CHANGELOG with no release yet, only `Unreleased`.** `check-version` must compare against the manifests' version and fail with a clear message, not throw. Pinned in Task 6, test `no release heading is a clear failure`.
5. **`fetch-upstream` re-run on a tree already at the pin, or with a missing commit.** A re-run must not re-clone; a missing commit exits 3 and leaves no half-filled directory. Pinned in Task 2, tests `second run is a no-op` and `missing commit exits 3 and removes the partial clone`.

## Port-task convention (used from M1 on; stated here so all three plans share it)

A prose file ported from an upstream source names the source file and line range under `.upstream/<source>/`, lists the required headings in order, states the adaptation rules (no source tags, no personal names or machine paths, kern vocabulary, unslop rules, no long dashes or curly quotes), gives the full text of anything that is a contract (frontmatter, `## Steps`, kernel text, mode rules, injected lines, agent return formats), and ends with a check command: lint, `grep` for each required heading, and a size bound with `wc -c`.

## File map

| Path | Task | Responsibility |
|---|---|---|
| `.gitignore`, `README.md`, `docs/specs/*`, `docs/plans/*`, `docs/research/*` | 1 | Repo skeleton and the documents that drive the build |
| `scripts/fetch-upstream`, `tests/scripts/fetch-upstream.bats` | 2 | Pinned upstream trees for port tasks |
| `LICENSE`, `licenses/*`, `NOTICE`, `UPSTREAM.md`, `tests/licensing.test.mjs` | 3 | Licence compliance |
| `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `CHANGELOG.md`, `skills/hello/SKILL.md` | 4 | A valid plugin and marketplace with one placeholder skill |
| `scripts/lib/frontmatter.mjs`, `scripts/lib/lint-rules.mjs`, `scripts/lint-skills.mjs`, `scripts/lint-exemptions.json`, `tests/lint-rules.test.mjs` | 5 | Lint rules 1, 2, 3, 4, 8, 10, 11 |
| `scripts/check-version.mjs`, `scripts/release.mjs`, `tests/versions.test.mjs` | 6 | Lint rule 14 and releases |
| `scripts/lib/rank.mjs`, `scripts/route-eval.mjs`, `evals/cases/hello.json`, `evals/distractors.json`, `evals/baseline.json`, `tests/route-eval.test.mjs` | 7 | Tier 1 routing evals |
| `.github/workflows/ci.yml`, `scripts/ci-local` | 8 | CI and a local mirror of it |
| none (verification only) | 9 | M0 acceptance |

---

