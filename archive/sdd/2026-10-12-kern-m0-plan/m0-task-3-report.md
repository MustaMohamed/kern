# Task 3 report: Licensing

Status: DONE. Commit a870879 "M0: add MIT licence, upstream licences, NOTICE and pins".

## What I did
- Wrote tests/licensing.test.mjs (brief Step 1), ran RED, copied 6 licence files from .upstream, wrote LICENSE, UPSTREAM.md, NOTICE.
- Spliced licenses/caveman.NOTICE into NOTICE with the brief's sed; `grep -c 'paste the full' NOTICE` printed 0.
- Compared Copyright cells with licence files: all matched (addy 2025 Addy Osmani, pocock 2026 Matt Pocock, pstack 2026 Lauren Tan, superpowers 2025 Jesse Vincent, caveman NOTICE line 2 "Copyright 2026 Julius Brussee"). No edits needed. No fallback note needed.

## TDD
RED: `node --test tests/licensing.test.mjs` -> ENOENT open '/Users/musta/Code/projects/kern/LICENSE' (also UPSTREAM.md, NOTICE).
GREEN: same command -> `# pass 5`, `# fail 0`.

## head -3 licenses/*.LICENSE
addy, pocock, pstack, superpowers: "MIT License" / blank / "Copyright (c) <year> <holder>" as above.
caveman: blank line, "Apache License", "Version 2.0, January 2004".

## Files changed (10, 486 insertions)
LICENSE, NOTICE, UPSTREAM.md, licenses/{superpowers,pstack,pocock,addy,caveman}.LICENSE, licenses/caveman.NOTICE, tests/licensing.test.mjs.

## Concerns
- caveman NOTICE mentions many third-party items (Go modules, fonts, Qwen); copied verbatim as required. Its "Full license texts" paths refer to caveman's repo, not kern.
- Working tree clean after commit. Not pushed.
