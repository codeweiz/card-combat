# Deterministic Simulation Core Review Log

## Review - 2026-06-17 - Verdict: NEEDS REVISION

Scope signal: L
Specialists: none; lean single-session review
Completeness: 8/8 sections present
Dependency graph: `design/gdd/match-authority-architecture.md` NOT FOUND; future Alpha dependency
Blocking items: 2 | Recommended: 3
Prior verdict resolved: First review

Summary: The deterministic core GDD is directionally strong and matches the
project pillars, but two implementation contracts remain unresolved enough to
block approval. Programmers still need a settled canonical serialization/hash
contract and a state snapshot ownership rule before UI, replay, or authority
work depends on the core.

Required before approval:

1. Define the MVP stable hash and canonical serialization contract, including
   dictionary ordering, enum/string representation, and minimum hash strength.
2. Resolve state snapshot ownership: immutable snapshots/copies versus
   controlled in-place mutation, and update the GDD or an ADR accordingly.

Recommended revisions:

1. Keep the match-authority reference explicitly marked as future until the
   Alpha GDD exists.
2. Decide whether rejected commands are persisted only in debug logs or also in
   a replay sidecar before action-log implementation.
3. Add a first deterministic RNG stream policy before any random effect enters
   MVP.

## Re-review - 2026-06-17 - Verdict: APPROVED

Scope signal: L
Specialists: none; lean single-session re-review
Blocking items: 0 | Recommended: 2
Prior verdict resolved: Yes

Summary: The blocking hash and snapshot ownership issues were resolved. The
implementation now uses SHA-256 over canonical strings, and
`get_state_snapshot()` returns a deep-copied canonical dictionary rather than a
mutable `MatchState` reference.
