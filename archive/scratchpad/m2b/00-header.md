# kern M2b Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove goal 0 for M2 against the sources and the user's own judgment, then release 0.4.0: a behavioural eval runner with pressure tests (coverage gap 13); a kernel-adherence grader with host isolation, negative and multi-turn cases and committed snapshots (gap 10); head-to-head evals for planning, debugging and review against superpowers, pocock and a no-plugin control on seeded fixtures with hidden answer keys; a standing-cost measurement in tokens; the coverage re-audit of M2 rows; and the side-by-side pilot, after which the user decides on switching superpowers off.

**Architecture:** Every runner reuses M2a's `scripts/lib/claude-run.mjs`: a project-shaped temp workspace, `claude -p` with stream-json in and out, and the isolation flags `--setting-sources project --strict-mcp-config --no-session-persistence`, so the user's plugins, hooks, MCP servers and saved sessions never reach a run. Grading is code first and a model second: the adherence grader is pure code over the tool calls; the behaviour and head-to-head graders are separate, isolated `claude -p` calls that see a digest of the run and, for head-to-head, redacted attempts under blind ids, with the key written only after grading. Pure parts (case loading, digests, verdict parsing, pass rules, redaction, blinding, the gate) are unit-tested in CI with no model call; the fixtures are tested in CI too (a diagnose fixture's held-out tests fail on the repo and pass with its reference patch; a review fixture's labels sit on added lines of a patch that keeps the tests green). Runs that spend tokens happen only on the user's yes and leave committed snapshots.

**Tech Stack:** Node 22 (`node:test`, no npm dependencies), bash 3.2+, git 2.31+, Claude Code 2.1.296 (`claude -p --plugin-dir --input-format stream-json --output-format stream-json --verbose`, `--output-format json` for the usage block), the upstream trees from `scripts/fetch-upstream` (superpowers `5bf4e780`, pocock `49dd158d`).

**Spec:** `docs/specs/2026-10-12-kern-design.md` (sections 1.1, 11, 13, 14 row M2b) and `docs/specs/coverage.md`. Shared names: `docs/plans/contract.md`, "Additions from the M2a and M2b plans". Traceability: `docs/plans/2026-10-14-kern-m2-traceability.md`. Starts from tag `v0.3.0` (M2a Task 33).

## Global Constraints

- M2a's Global Constraints apply unchanged; this list adds what is specific to M2b.
- A step that runs `claude -p` spends tokens. Before it, show the command, the number of model calls it makes (cases x runs, plus grader calls) and the model, then ask; run it only on the user's yes. Every runner has `--dry-run`, which calls no model and lists what a run would do.
- Isolation: every model run goes through `runClaude` with `ISOLATION`; the runner records `ISOLATION`, the model and `claude --version` in its snapshot. Fixture copies get project-shaped names (`billing-service`, `shop-cart`, `invoice-service`); no path, file or prompt the model sees names an eval, a grader or an answer key.
- Pass rules are fixed before any run and are not tuned after: a behaviour or adherence case passes on at least two of three runs (behaviour: and at most one invalid run); a head-to-head category passes when kern's mean score is at least the strongest other arm's and its mean false alarms are at most that arm's, the control arm included; the pilot's pass rule is in `docs/pilot.md`, written and agreed before the first pilot run.
- A failed gate is a finding, not a reason to edit the case. Fix kern, record the fix under "Tasks added during execution", and re-run. A case, fixture, rubric or answer key changes only when it is wrong on its own terms (it tests something the spec does not say), and the change says so in its commit body.
- Snapshots (`evals/snapshots/*.json`) are committed. Raw transcripts and head-to-head keys go to `evals/results/` (gitignored).
- Haiku runs are reported, never gating.
- Prose in every file follows unslop: answer first, no filler, no long dashes, no curly quotes.

## Review Focus

1. **A grader that passes a run it should fail.** A bare skill name, or a skill file under `~/.claude/skills`, is not kern's route. Pinned in Task 2 (`a bare skill name or a skill file outside the plugin root is not the route`).
2. **A grader reply that is not JSON, or has the wrong count.** It voids the run; it never passes it. Pinned in Task 1 (`a grader reply that is not one JSON verdict per expectation is invalid, never a pass`) and Task 3 (`a malformed grade voids the run`).
3. **An arm identifiable from its output.** Plugin names, skill paths, `CLAUDE_PLUGIN_ROOT` and `.kern/` are redacted before the grader sees an attempt. Pinned in Task 3 (`redaction removes every name, path and namespaced skill that identifies an arm`).
4. **A nested `node --test` that reports to its parent.** A fixture test that spawns `node --test` must drop `NODE_TEST_CONTEXT`, or the child reports into the parent's stream and exits 0 with no tests run. Pinned in Task 3 (the fixture tests fail before the reference patch, which they could not if the child ran nothing).
5. **A fixture whose bug is caught by its own visible tests.** A diagnose or review fixture is useless if `npm test` already fails on it (unless the task says the visible test fails). Pinned in Tasks 3, 5 and 6.
6. **Pilot prompts reworded after the fact.** `evals/heldout-pilot.json` is pinned by its sha256 in the commit that creates it. Pinned in Task 11.

---
