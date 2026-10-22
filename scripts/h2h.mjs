#!/usr/bin/env node
// Head-to-head evals: each task under each arm, then one blind grader call per task-run that sees the
// redacted attempts under opaque ids. The key (blind id to arm) is written only after grading, outside
// anything the grader reads. Spends tokens; never runs in CI; ask the user before a run.
// Usage: node scripts/h2h.mjs [--category plan|diagnose|review] [--task <category/id> | --changed <range>] [--arms a,b]
//        [--runs N | --quick] [--jobs N] [--no-cache] [--model <m>] [--grader-model <m>] [--allow-dirty] [--dry-run]
//        node scripts/h2h.mjs --resume <results dir> [--jobs N] [--no-cache]
//        node scripts/h2h.mjs --regrade <results dir>
// Raw runs and key.json (merged with the day's earlier keys) go to evals/results/h2h-<date>/ (gitignored). A full
// run writes the unblinded scores and the gate to evals/snapshots/h2h-<model>-<date>.json (committed), each review
// row with its decoy and unmatched counts and the grader's raw reply (resultRow); a --category, --task or --arms
// run, or one with no graded task-run, writes its snapshot beside the raw runs instead (h2hMain, Task 17a). Exit 0
// when every category passes, 1 when one fails, 3 when none fails but one is incomplete (a loaded task with no
// graded run), 2 for a usage error or when no task matched. --jobs N runs N sessions at once (default 6), a task-run's
// arms side by side; --quick runs each task once; an arm attempt whose inputs match a cached valid one is reused unless
// --no-cache; --resume <dir> runs only what that run lacks; --regrade <dir> reads its saved grades again (h2hMain).
import { fileURLToPath } from 'node:url';
import { h2hMain } from './lib/h2h.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
process.exit(await h2hMain({ root: ROOT, argv: process.argv.slice(2) }));
