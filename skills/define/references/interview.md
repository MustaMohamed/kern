# Interview

Draw out what the user wants before any design. One question at a time, each with your guess. A fact the repo can answer goes to a `kern:investigator` subagent, never to the user.

## Hypothesis and confidence

Before asking, write your best read of the ask in one sentence and an honest confidence from 0 to 100%.

```
HYPOTHESIS: You want a way to answer "how are we doing?" in standup, and "dashboard" was the first form that came to mind.
CONFIDENCE: ~30%. Missing: who it is for, what "metrics" means here, what success looks like.
```

Below about 70%, name what is missing on the same line. The number is honest only if you could predict the user's reaction to your next three questions; if you could not, lower it.

## One question at a time

```
Q: <one focused question>
GUESS: <your answer, with the reasoning behind it>
```

Wait for the reaction before the next question. A batch buries the guesses, invites skimming, and locks in a framing the first answer may overturn. A visible guess is faster to correct than an answer built from nothing. A polite user may agree to be agreeable: sometimes guess in a direction you expect them to reject.

## Want versus should-want

Watch for answers that sound like best practice instead of a want: "scalable", "clean", "the standard way", "I should probably". Ask: "If you did not have to justify this to anyone, what would you actually want?"

## Restate and confirm

At high confidence, write back, in the user's words, in 5 to 8 lines:

- Outcome, User, Why now, Success, Constraint, Out of scope.

Then list what was said and what is assumed. Out of scope is required: half of misalignment is silent disagreement about what is not being built. Only an explicit yes approves, as a typed reply in chat. "Whatever you think" is delegation: re-ask with two concrete options. "Sounds good" and silence are not a yes: ask what they would refine. Silence, then "okay, let's start", means the user gave up on the interview, not that they agree: stop and ask what you missed. A recorded approval quotes one whole line of the user's message, verbatim. On a correction, fold it in and restate.

## When to step back

Two rounds without rising confidence: stop and say so. For example: "I have asked six questions and still cannot predict your answers. Something basic is missing. Do you want to step back?" Then wait.
