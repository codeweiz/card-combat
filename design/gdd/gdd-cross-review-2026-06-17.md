# Cross-GDD Review Report

Date: 2026-06-17
Mode: lean single-session review; no subagents spawned
GDDs Reviewed: 14 system GDDs plus game concept and systems index

Systems Covered:

- Godot Project Foundation
- Deterministic Simulation Core
- Card Data Model
- Turn, Timing, and Resource System
- Zone and Lane Board System
- Stack and Response System
- Card Effect Resolution System
- Action Log and Replay System
- Deck Construction and Validation
- Prototype Card Set and Archetypes
- Local Match Flow
- Match Board UI and Input
- Cross-Platform Interaction Layer
- Determinism Test Harness

---

## Scope and Evidence

This review loaded the systems index, game concept, entity registry, architecture
registry, and all 14 MVP system GDDs. Mechanical checks confirmed:

- All 14 MVP GDDs exist.
- All 14 MVP GDDs include the 8 required sections: Overview, Player Fantasy,
  Detailed Design, Formulas, Edge Cases, Dependencies, Tuning Knobs, and
  Acceptance Criteria.
- No placeholder markers were found in the reviewed MVP GDDs.
- `design/registry/entities.yaml` and `docs/registry/architecture.yaml` parse.
- Registry formulas and constants have no duplicate names.
- Current Godot smoke passes with final hash
  `e530e326a67c19fa5b6c181cd973937bbf57d5bea142389d0ccb6825517b2df3`.

This report does not replace independent per-GDD `/design-review` passes. The
systems index still records `Design docs reviewed = 0` and `Design docs approved
= 0`.

---

## Consistency Issues

### Blocking

None found in the current MVP GDD set.

### Warnings

#### W-01 Future GDD References Are Present Before Target Docs Exist

Several MVP documents reference future Vertical Slice, Alpha, or Full Vision GDD
paths that are not authored yet:

- `action-log-replay-system.md` and `deterministic-simulation-core.md` reference
  `design/gdd/match-authority-architecture.md`.
- `card-data-model.md` references `design/gdd/card-frame-visual-identity-system.md`
  and `design/gdd/localization-text-layout.md`.
- `deck-construction-validation.md` references
  `design/gdd/card-collection-inventory.md`.

These are not MVP blockers because those systems are explicitly listed as later
priority tiers in `systems-index.md`. Before architecture or story generation
uses these as hard links, either create the target GDDs or keep the references
phrased as future assumptions.

#### W-02 Dependency Sections Are Not Fully Reciprocal in Wording

The systems index gives a coherent dependency order, and each MVP GDD lists its
major dependencies. However, individual GDD dependency tables use mixed wording:
some list hard upstream dependencies, some list future dependents, and some list
indirect consumers. This is usable for design, but architecture traceability will
need a normalized dependency matrix generated from `systems-index.md` plus each
GDD's dependency table.

#### W-03 Individual Design Review Gate Is Still Unmet

All MVP GDDs are drafted, but none are individually marked reviewed or approved.
The Systems Design -> Technical Setup gate requires every MVP-tier GDD to pass
`/design-review`. This is a process gate issue, not a cross-GDD contradiction.

---

## Game Design Issues

### Blocking

None found.

### Warnings

#### W-04 Response Focus Remains the Main Hook Risk

The concept and systems index both note that the lane-plus-stack hook has signal
but the response-resource model needs another focused prototype. The drafted MVP
GDDs consistently use `RESPONSE_FOCUS_PER_OPPONENT_TURN = 2`,
`MAX_FOCUS = 2`, and `MAX_RESPONSES_PER_WINDOW_MVP = 1`; no contradiction was
found. The design risk is empirical: these values are plausible but not yet
validated by a second focused prototype.

Recommendation: run the focused response `focus` prototype or mark the current
values as an accepted MVP risk before locking first playable scope.

#### W-05 Attention Budget Is High but Mitigated

During a typical match turn, players may need to track hand cards, lane
positions, unit stats, main resource, focus, response priority, target legality,
and recent action log events. That exceeds the comfortable 3-4 active-system
guideline if all are emphasized equally.

Mitigations already present in the GDDs:

- One response per window.
- Three fixed lanes.
- One unit slot per player per lane.
- Explicit disabled reasons.
- Match Board UI and Cross-Platform Interaction Layer require no-hover and
  touch-safe presentation.

Recommendation: keep action log and debug hash secondary in the first playable
UI; prioritize active prompt, lane state, legal targets, and response pass.

#### W-06 Structured Event Schema Is Deferred but Will Become a Hard Dependency

Action Log and Replay, Match Board UI, Local Match Flow, and Determinism Test
Harness all agree that string events are acceptable only for skeleton/smoke use.
They also agree that structured events are required before production replay UI
or match authority. This is consistent, but it is a clear upcoming architecture
decision.

Recommendation: write an ADR for structured action log event schema before
implementing replay persistence, replay UI, or online authority.

---

## Cross-System Scenario Issues

Scenarios walked: 5

1. Local match starts from two validated MVP decks.
2. Active player plays a unit into a lane and defender cancels it with a response.
3. Active player plays a unit and defender explicitly passes response.
4. Touch player selects a targeted action during a response-capable board state.
5. Match completes and the result is finalized for replay verification.

### Blockers

None found.

### Warnings

#### W-07 Local Match Start Is Fully Designed but Not Yet Implemented

Systems involved: Deck Construction and Validation, Prototype Card Set and
Archetypes, Local Match Flow, Deterministic Simulation Core, Action Log and
Replay System.

The GDDs agree on the required start sequence: validated decks, compatible card
data hash, complete `MatchSetup`, ordered deck ids, opening hands, action-log
header, and core initialization. Current implementation is intentionally behind
that contract. This is not a design contradiction, but it is the primary
first-playable implementation gap.

#### W-08 Replay Verification Depends on Future Action Log Implementation

Systems involved: Local Match Flow, Action Log and Replay System, Determinism
Test Harness, Match Board UI and Input.

The GDDs agree that match completion must record final hash and replay status.
The current smoke proves repeated deterministic state hash for a narrow command
sequence, but it does not yet implement saved action logs or replay fixtures.

### Info

#### I-01 Response Cancel Scenario Is Cross-System Coherent

Systems involved: Stack and Response System, Card Effect Resolution System,
Zone and Lane Board System, Action Log and Replay System.

The response cancel path is consistently specified: original action opens a
window, defender has response priority, `cancel_original` can cancel supported
original commands, canceled original does not place the unit, and rejected or
canceled state must remain hashable/replayable.

#### I-02 Cross-Platform Input Boundary Is Coherent with Replay

Systems involved: Match Board UI and Input, Cross-Platform Interaction Layer,
Action Log and Replay System.

The input GDDs consistently keep raw input events out of canonical replay data.
Mouse, touch, keyboard, and gamepad paths normalize into UI intentions, and only
accepted match commands become replay inputs.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| `design/gdd/systems-index.md` | Still records `Design docs reviewed = 0`; run individual reviews before gate pass | Process | Warning |
| `design/gdd/turn-timing-resource-system.md` | Response focus value still awaits focused prototype validation | Design Risk | Warning |
| `design/gdd/action-log-replay-system.md` | Structured event schema deferred before replay UI/authority | Architecture Follow-up | Warning |
| `design/gdd/determinism-test-harness.md` | Fixture runner and replay verifier not implemented yet | Implementation Follow-up | Warning |

No GDD is flagged as `Needs Revision` from this cross-review because no blocking
cross-document contradiction was found.

---

## Verdict: CONCERNS

The MVP GDD set is coherent enough to continue toward gate validation, but it is
not ready to pass Systems Design -> Technical Setup yet. The blockers for the
phase gate are procedural and evidence-based: individual `/design-review` passes
are missing, and gate-check still needs to run after those reviews. Design-wise,
the response focus model remains the highest-risk unvalidated assumption.

## Required Actions Before Re-Running Gate

1. Run individual `/design-review` for all 14 MVP GDDs in fresh sessions.
2. Resolve or explicitly accept any findings from those reviews.
3. Decide whether to run the second response `focus` prototype now or record the
   current focus values as an accepted MVP risk.
4. Re-run `/gate-check systems-design`.

## Follow-Up Resolution - 2026-06-17

Same-day lean individual reviews were completed and logged under
`design/gdd/reviews/`. After re-review fixes:

- Individual GDD reviews are complete for all 14 MVP GDDs.
- `RESPONSE_FOCUS_PER_OPPONENT_TURN = 2` is recorded as the accepted
  first-playable MVP risk value, with validation deferred to the first Godot
  playable.
- Structured replay events are now defined in
  `design/gdd/action-log-replay-system.md`.
- Deterministic hashing now uses SHA-256 over canonical strings.
- `DeterministicSimulationCore.get_state_snapshot()` now returns a deep-copied
  canonical dictionary, not a mutable `MatchState` reference.
- Match Board UI and Cross-Platform Interaction Layer now include concrete
  layout, focus-route, and input-binding contracts.

Remaining gate concern: `design/gdd/prototype-card-set-archetypes.md` still
needs revision because first-playable content lacks a 24-card runnable pool and
the sample decks still include design-only cards.
