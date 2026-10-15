# Capability map

A short table that fixes module boundaries and build order before any spec is written.

## When to split

Draw a map when the ask holds several independently testable capabilities: distinct consumers or data, acceptance criteria that cluster into groups that could ship alone, or one part that could be cut without rewriting the others. A single capability skips the map.

## Map format

| Capability | User-visible outcome | Depends on | Build order |
|---|---|---|---|
| identity | sign in and out | none | 1 |
| billing | pay and get invoices | identity | 2 |

Ids are kebab-case, chosen once, never renamed. Dependencies point one way with no cycles; two modules that need each other are one module. The contract between two modules goes in the provider's spec.

## Approval

The map is approved before any module spec, on an explicit typed yes. Then each module goes through define in build order, one spec per module, named by its capability id. Save the approved map beside the specs.
