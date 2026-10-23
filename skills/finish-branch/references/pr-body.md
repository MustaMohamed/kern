# PR body

A one-minute briefing for a reviewer who has the diff. Write it with the Write tool to a file under `WORK/tmp` and pass `--body-file`. Use these sections in this order and drop a section with nothing to say. Keep the whole body under about 40 lines; detail goes in a linked file, not the body.

## Why

The problem and who has it, in two or three sentences. Link the issue.

## What changed

The behaviour change as the smallest useful view: a call tree, pseudocode, a short diff sketch or a diagram when it explains faster than prose; otherwise one to three bullets. Name both sides of a rename.

## Scope

What this PR covers, and a "Didn't touch" line for the nearby things a reviewer might expect.

## Tradeoffs

Only the rejected alternatives a reviewer would otherwise ask about. Skip it when there was no real choice.

## Merge danger

One-way or two-way door. The blast radius: data, consumers, deploy order. What breaks if this is wrong, and how to roll back. Name each `bar-lowered` change self-review kept, with the user's yes for it.

## Verification

Before and after. Screenshots first when the change is visible and the environment can show it; otherwise commands with their output: the failing reproduction, the passing run, the full suite summary.
