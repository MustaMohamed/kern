# Smell baseline

The Standards axis when a repo documents few or no standards: twelve code smells from Fowler's Refactoring, chapter 3, as pocock's code-review carries them (MIT; the text is written for kern).

## Rules

- A smell is a labelled judgment call, such as "possible Feature Envy", in the `should-fix` class at most, never a blocker.
- A `review.rules` file that endorses what a smell would flag wins: drop the smell.
- Skip what lint, the formatter or the type checker already enforces.
- Report a smell only on lines the diff adds or changes, with `path:line` and the fix.

## Smells

- Mysterious Name: a name that does not say what it does or holds. Rename it; when no honest name comes, the design is unclear.
- Duplicated Code: the same logic shape in more than one hunk or file of the change. Extract it and call it from both.
- Feature Envy: a function that reaches into another object's data more than its own. Move it to that data.
- Data Clumps: the same few fields or parameters travelling together. Bundle them into one type.
- Primitive Obsession: a primitive or string standing in for a domain concept. Give the concept its own small type.
- Repeated Switches: the same switch or if-chain on the same type in several places. One map, or polymorphism, that both share.
- Shotgun Surgery: one logical change forces scattered edits across many files. Gather what changes together.
- Divergent Change: one module edited for several unrelated reasons. Split it so each part changes for one reason.
- Speculative Generality: abstraction, parameters or hooks for needs the spec does not have. Delete them.
- Message Chains: a long `a.b().c().d()` walk the caller should not depend on. Hide it behind one call.
- Middle Man: a function or class that mostly delegates onward. Call the real target.
- Refused Bequest: a subclass or implementer that ignores most of what it inherits. Use composition instead.
