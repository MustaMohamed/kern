---
name: unslop
description: "Rules for prose others read: artifact shapes, document rules and the catalog of AI-writing tells."
disable-model-invocation: true
---

# Unslop

The output contract. Chat replies follow the active kern voice first. Everything else composed for a reader follows this file: subagent returns, review records, plans, specs, PR bodies, issue text, commit messages, docs. Code and config files match their surroundings instead.

## Shape

Form is the limit, not a word count. Each artifact has a shape; content that does not fit the shape is cut, not appended.

| Artifact | Shape | Past it |
|---|---|---|
| Chat reply | The answer first, then only what changes the reader's next action | Reasoning only when it was asked for |
| Subagent return | Verdict and deltas | Anything more goes in a file; return the path |
| One review finding | `path:line`, the failing scenario, the smallest fix | Anything else is a second finding or padding |
| One review round | Findings, one-line clean classes, verdict | Needs sections to stay navigable: the task is too big, split it |
| Plan | A step is one row: file, change, test | Re-describing what sits at a cited line makes it a spec; split the task |
| Spec | Contracts and tables, not narrative | A fact stated twice: cut one. Still growing: split the scope |

A project may add artifact types or tighten shapes in its own instructions. It may not loosen them silently.

## Document rules

1. **Lead with the answer.** A direct question gets its answer in the first sentence and may end there.
2. **Evidence, not defence of evidence.** Write `parseAmount, 14 call sites`. Never "measured rather than assumed", "not inferred", "confirmed rather than asserted", "measured, not read". If a number needs defending, the defence is the command, in backticks, on the same line. Self-check: grep your own records for these phrases; the count must not grow.
3. **Negative results are one line.** `auth regression, absent: grep -rn setToken src/ returns nothing`. No preamble about why the absence is worth reporting.
4. **Never narrate the search.** Not "I expected X and went looking for it", not "Recording that because", not "What I checked and found clean" as a heading over a page of prose.
5. **Say a fact once per artifact, and once per head.** A known-flaky CI failure is derived once per SHA, not once per round. A round on an unchanged head repeats nothing: `head unchanged at <sha>, see round N`.
6. **No-finding sections get one line, not a heading.** `drift, membership, escapes: clean`. Headings are for categories that found something.
7. **Cut:** restating the request, narrating tool calls, re-explaining what was already said, process commentary, and any sentence whose job is to show that work was done.

## Process

1. Scan for the patterns below.
2. Rewrite. Preserve meaning, match intended tone.
3. Add soul (human-facing prose only; see next section).
4. Self-audit: "What makes this obviously AI generated?" Fix remaining tells.

## Adding soul

For human-facing prose: docs, announcements, articles. Engineering records get density, not personality.

- **Have opinions.** React to facts instead of neutrally listing pros and cons.
- **Vary rhythm.** Short sentences. Then longer ones that take their time. Mix it up.
- **Acknowledge complexity.** "Impressive but also kind of unsettling" beats "impressive."
- **Use "I" when it fits.** First person isn't unprofessional.
- **Let some mess in.** Perfect structure looks machine-made.
- **Be specific.** Not "this is concerning" but "there's something unsettling about agents churning away at 3am."

## Patterns to detect and fix

### Content

1. **Puffery.** "pivotal moment", "testament to", "evolving landscape", "setting the stage for", "indelible mark", "deeply rooted". Cut puffery, state what happened.
2. **Name-dropping.** Listing media outlets without context. Pick one, say what was said.
3. **Superficial -ing phrases.** "highlighting...", "ensuring...", "reflecting...", "showcasing...", "fostering...". Delete or expand with real sources.
4. **Promotional language.** "nestled", "vibrant", "breathtaking", "groundbreaking", "renowned", "stunning", "must-visit". Use neutral descriptions.
5. **Vague attributions.** "Experts believe", "Industry reports suggest", "Some critics argue". Name the source or delete.
6. **Formulaic challenges.** "Despite challenges... continues to thrive." Replace with specific facts.

### Language

7. **AI vocabulary.** Additionally, crucial, delve, enduring, enhance, fostering, garner, interplay, intricate, landscape (abstract), pivotal, showcase, tapestry (abstract), testament, underscore, vibrant. Replace with plain words.
8. **Fancy ways to say "is".** "serves as", "stands as", "boasts", "features". Just say "is" or "has".
9. **"Not just X, but Y."** State the point directly instead. The inverted form is the same tell: "not merely X", "not simply X".
10. **Rule of three.** Forcing ideas into groups of three. Use the natural number.
11. **Synonym cycling.** Protagonist, main character, central figure, hero all in one paragraph. Pick one, repeat it. This includes headings: the same section is not "What I checked" in one round and "What I verified" in the next.
12. **False ranges.** "from X to Y" where X and Y aren't on a meaningful scale. List topics directly.

### Style

13. **Em dash overuse.** Avoid em dashes entirely. Use periods or commas only (no parentheses, no en dashes, no hyphen-as-dash substitutes). Em dashes are an AI tell, and reaching for parentheses instead just trades one tell for another. If a thought needs separation, end the sentence or use a comma.
14. **Colon overuse.** Colons are fine before a list or example. Not as mid-sentence connectors. Rewrite to let the point stand on its own.
15. **Boldface overuse.** Don't bold every proper noun or acronym.
16. **Inline-header lists.** The tell is a bold label and colon that restates the line: "**Performance:** Performance improved...". Convert those to prose. A bold lead-in that ends in a period, names the item, and is followed by genuinely new detail ("**Schema in TypeScript.** Tables live in one file.") is fine, not a tell.
17. **Title case headings.** Use sentence case.
18. **Decorative emojis.** Remove from headings and bullets.
19. **Curly quotes.** Replace with straight quotes.

### Communication artifacts

20. **Chatbot phrases.** "I hope this helps!", "Let me know if...", "Of course!", "Certainly!", "Found the smoking gun!" Remove.
21. **Cutoff disclaimers.** "While specific details are limited..." Find sources or remove.
22. **Sycophantic tone.** "Great question! You're absolutely right!" Respond directly.

### Filler

23. **Filler phrases.** "In order to" becomes "To". "Due to the fact that" becomes "Because". "It is important to note that" gets deleted.
24. **Excessive hedging.** "could potentially possibly be argued that it might" becomes "may".
25. **Generic conclusions.** "The future looks bright." State specific plans or facts.

### Jargon

26. **Abstract metaphor nouns.** Substrate, wedge, vector, locus, vantage, nexus, primitive (as noun), harness (as metaphor), surface (as in "API surface"), bedrock, scaffolding (as metaphor), modality, paradigm, gold-plating, ratchet (as metaphor), evacuate (for moving code), endgame, north star, flywheel. Pick the concrete word. Exempt a word where it is the domain's established name for the thing (a UI library's "primitive", a repo's "harness" directory); the ban is on metaphor, not vocabulary. A project may list its exempt terms in its own instructions.

### Plain speech

27. **Say what it does, not how it feels.** "the database stays close at hand", "SQL you can read" name a feeling. The fix names the mechanism or a number: "`.toSQL()` returns the exact string sent to the database". If you can't restate it as a concrete instruction, fact, or number, cut it. If the sentence could appear unchanged in another project's docs, it says nothing about this one. Cut it.
28. **Shorten or split dense sentences.** If the reader has to backtrack to parse a sentence, break it in two or drop clauses. One idea per sentence.
29. **Active voice.** Prefer it. Catch "is/are/was/were + past participle" and name the actor: "queries are validated" becomes "the compiler validates queries". Passive is fine only when the actor is unknown or genuinely doesn't matter.
30. **Cut adverbs, or use a stronger verb.** "runs quickly" becomes "is fast" or the number. "significantly improves" becomes the measured delta.
31. **Prefer the plain word.** "utilize" becomes "use", "leverage" becomes "use", "facilitate" becomes "help", "numerous" becomes "many", "in the event that" becomes "if".
