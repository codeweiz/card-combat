# Action Log and Replay System Review Log

## Review - 2026-06-17 - Verdict: NEEDS REVISION

Scope signal: L
Specialists: none; lean single-session review
Completeness: 8/8 sections present
Dependency graph: `design/gdd/match-authority-architecture.md` NOT FOUND; future Alpha dependency
Blocking items: 1 | Recommended: 3
Prior verdict resolved: First review

Summary: The replay GDD correctly defines accepted-command replay, hash checks,
event comparison, compatibility failure, and mismatch reporting. Approval should
wait until the temporary string-event contract is replaced by a concrete MVP
structured event schema, because this system is the persistence boundary.

Required before approval:

1. Define the MVP structured event record schema, including event type names,
   source command/stack identifiers, deterministic payload shape, and field
   ordering.

Recommended revisions:

1. Keep match-authority references marked future until the Alpha authority GDD
   exists.
2. Decide whether rejected commands remain debug-only or get a sidecar format
   before networking work.
3. Add one example accepted command entry and one mismatch report example for
   programmers and QA.

## Re-review - 2026-06-17 - Verdict: APPROVED

Scope signal: L
Specialists: none; lean single-session re-review
Blocking items: 0 | Recommended: 2
Prior verdict resolved: Yes

Summary: The replay event blocker was resolved by adding the MVP
`SimulationEvent` and `EventTargetRef` schemas, canonical event ordering, and
the initial event type list required before replay UI or authority consumes log
events.
