#!/usr/bin/env node
// Behavioural evals: does kern behave as the skill says, under pressure and across a workflow?
// Spends tokens; never runs in CI; ask the user before a run.
// Usage: node scripts/behave.mjs [--case <id>] [--runs N] [--model <m>] [--grader-model <m>] [--allow-dirty] [--dry-run]
// A full run writes evals/snapshots/behave-<model>-<date>.json (committed); a --case run, or a full run with no valid
// run or stopped by a fatal error, writes its snapshot beside the transcripts instead (behaveMain, Task 17a G3). An
// expectation a case's `checks` names is decided by that scripted check, with no model (Task 16j); the rest get one
// grader call per run. A case with a tree check also saves each run's treeState, at its start and end, as
// <case>-<i>.tree.json beside its events. Any argument the runner does not know is a usage error (exit 2).
import { fileURLToPath } from 'node:url';
import { behaveMain } from './lib/behave.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
process.exit(behaveMain({ root: ROOT, argv: process.argv.slice(2) }));
