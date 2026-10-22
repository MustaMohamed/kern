#!/usr/bin/env node
// Behavioural evals: does kern behave as the skill says, under pressure and across a workflow?
// Spends tokens; never runs in CI; ask the user before a run.
// Usage: node scripts/behave.mjs [--case <id> | --changed <range>] [--runs N | --quick] [--jobs N] [--no-cache] [--model <m>] [--grader-model <m>]
//        [--allow-dirty] [--dry-run]
//        node scripts/behave.mjs --resume <results dir> [--jobs N] [--no-cache]
//        node scripts/behave.mjs --regrade <results dir>
// A full run writes evals/snapshots/behave-<model>-<date>.json (committed); a --case run, or a full run with no valid
// run or stopped by a fatal error, writes its snapshot beside the transcripts instead (behaveMain, Task 17a G3). An
// expectation a case's `checks` names is decided by that scripted check, with no model (Task 16j); the rest get one
// grader call per run. A case with a tree check also saves each run's treeState, at its start and end, as
// <case>-<i>.tree.json beside its events. Any argument the runner does not know is a usage error (exit 2).
// --jobs N runs N sessions at once (default 6); --quick runs each case once and --changed <range> only the cases whose
// inputs changed, each into a results dir of its own and never a committed snapshot; a run whose inputs match a valid
// cached one is reused unless --no-cache; --resume <dir> runs only what that run lacks; --regrade <dir> grades its
// saved transcripts again and starts no session (behaveMain).
import { fileURLToPath } from 'node:url';
import { behaveMain } from './lib/behave.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
process.exit(await behaveMain({ root: ROOT, argv: process.argv.slice(2) }));
