# Test design

A test exists to catch a specific break. Each section gives a rule and the question that checks it.

## Name the break

Before the test body, name the production change that should make it fail, and say whether that change is a bug or a decision. A test that only a decision can fail (a constant's value, exact message wording, private structure) fires on redesign and sleeps through bugs. Test the behaviour that depends on the decision: not `expect(MAX_RETRIES).toBe(5)` but "a failing call is retried 5 times and the 6th attempt never happens."
Gate: can you name a bug that fails this test? If not, redesign it around an observable behaviour.

## Test the real thing

Run the artifact and assert its output, side effects or exit code. Asserting that a script or config contains a line proves only that the source is the source. Test your boundary: the route you register, the query you emit, the payload you produce. Upstream mechanics are their maintainers' tests. Trivial getters, constants and forwarding earn a test only when they validate, default, derive or cause a side effect.
Gate: if only the framework remained, would this test still matter?

## Mocks need a reason

A mock assertion passes when the mock is present and fails when it is absent, so it says nothing about the component. Mock only the slow or external call, and learn the real method's side effects first so the ones the test depends on stay real. A double that accepts any argument verifies nothing: assert arguments and call counts when they are part of the contract, and give each branch (success, error, malformed) its own fixture. Mirror the real structure, every documented field. Cleanup that only tests call lives in test utilities, not on the production class. When mock setup outgrows the test, use real components.
Gate: are you asserting on the mock itself? Unmock it or delete the assertion.

## Mutation check

Before you finish, mutate the code and see a test fail. Run `probe --mutate <file>:<line>` on a new condition: it inverts one operator on that line, the first in probe's fixed order, or drops a `!` when the line has none, in a throwaway fork; point it at a line with a single condition so you know which one changed. For tests added to existing code, which pass at once, this check is their RED. The fork is never the worktree, and `probe: mutation caught` means a test notices. `probe: mutation survived` means the behaviour is unprotected or the test is tautological. Also ask what a wrong constant, a wrong branch, a missing side effect or an empty return would do.
Gate: does at least one test fail for each realistic mutation?

## Tautological tests

An expected value comes from an independent source: a known-good literal, a worked example or the spec. It is never recomputed the way the code computes it, as in `expect(add(a, b)).toBe(a + b)`, nor taken from the same builder or helper, nor a constant asserted equal to itself.

```ts
expect(buildSearchQuery({ tag: 'urgent' })).toBe('tag:"urgent"'); // hand-derived literal
```

Gate: could this assertion ever disagree with the code? If not, replace the expected value with a literal.

## Adversarial inputs

The happy value proves little. Cover empty, zero, false, cleared, several elements, and the value a real caller sends. A control over a list reads and writes the whole list, so test it with more than one element.
Gate: does a test use each of these where the code takes the input?

## Behaviour, not implementation

Call the code as its users do and assert the exact result they see. Rewrite or delete any test that would pass if every import returned undefined. These shapes fail that check: no assertion or a loose one (`toBeDefined`, `toBeTruthy`, `not.toThrow`), only a call or an absence (`toHaveBeenCalled`, `toEqual([])`), a restated constant or default, and assertions on data the test built without calling the subject. Fix: call the subject with one concrete input and assert the literal output or effect. For an absence, also assert the presence on another input. The tell for implementation coupling is a test that breaks on a refactor that changes no behaviour.
Gate: if you refactor with behaviour unchanged, does the test stay green?
