#!/usr/bin/env node
// Kernel adherence (design spec 11.1 tier 2, coverage gap 10): does a routed prompt make Claude read the
// route with at most one other call before it, and does a prompt that should not route stay quiet? Each
// run also reports whether it opened a todo list holding the route's steps; that does not gate.
// Spends tokens; never runs in CI; ask the user before a run.
// Usage: node scripts/kernel-adherence.mjs [--case <id>] [--runs N] [--model <m>] [--variant routed] [--plugin <kern tree>] [--allow-dirty] [--dry-run]
//        node scripts/kernel-adherence.mjs --transcript <session.jsonl> --route <route> [--root <plugin root>]
// A full run writes evals/snapshots/adherence-<variant>-<model>-<date>.json (committed); a --case or --plugin run,
// or one with no valid run, writes its snapshot beside its transcripts (adherenceMain, Task 17a). Any argument
// the runner does not know is a usage error (exit 2).
import { fileURLToPath } from 'node:url';
import { adherenceMain } from './lib/adherence.mjs';

const ROOT = fileURLToPath(new URL('..', import.meta.url)).replace(/\/$/, '');
process.exit(adherenceMain({ root: ROOT, argv: process.argv.slice(2) }));
