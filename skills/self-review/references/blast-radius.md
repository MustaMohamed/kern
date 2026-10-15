# Blast radius

Find what a change breaks somewhere else. Listing callers is not the job; `rg` does that in a second. The job is the breakage a symbol search does not show. A write-up that sounds right proves nothing, so find the one or two facts the change is safe because of and prove them by running code.

## How sure are you

Take each fact the change's safety rests on as far down this ladder as is cheap, and say where it stopped.

1. You said so. Worthless alone.
2. You pointed at the line: a real `file:line`, or the library's own source.
3. You showed the bad case can't happen: you walked the failure step by step and it does not reach.
4. You ran it: a script or test that calls the real code and fails loud if you are wrong.
5. You reproduced it in the app.

A fact you could not get past level 2 is reported as unproven.

## Writer sweep

Grep every writer of a property the change gates on, in every package, and read each one. A reader sweep only answers who breaks; a writer sweep answers whether the state can occur at all. For each writer ask: could this produce the gated shape without meaning to? One writer checked is never enough, and an empty search is a result: say what it would have found.

## Where grep stops

Read the source of a library you call, at its pinned version and with any local patch. Work out when things run (teardown, async ordering). Follow what a symbol search misses: an API's JSON, a DB column, a wire format, another language reading the same bytes, a feature flag, code three hops downstream.

## Risks and cleared

- The one fact it is safe because of, the level it reached, and the proof, or "unproven".
- Risks: how each breaks, `file:line`, how likely, what it costs, and the cheapest check.
- Cleared: what you checked and why it is fine.
- Before merging: the smallest test or script that would catch the real bug.
