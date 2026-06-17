# ADR-0003: MVP Lane Board and Response Window State Architecture

## Status

Accepted

## Date

2026-06-17

## Last Verified

2026-06-17

## Decision Makers

Codex acting under user authorization.

## Reverse Documentation Source

This ADR was reverse-documented from the current implementation in:

- `src/core/simulation/board_state.gd`
- `src/core/simulation/lane_state.gd`
- `src/core/simulation/unit_instance.gd`
- `src/core/simulation/response_window_state.gd`
- `src/core/simulation/stack_item.gd`
- `src/core/simulation/deterministic_simulation_core.gd`

It captures the architecture already used by the MVP skeleton and locks the
ownership boundaries before Action Log and Replay work builds on them.

## Summary

MVP board state and response-window state will live as deterministic
scene-independent substates inside `MatchState`. `BoardState` owns lane, life,
and runtime unit invariants. `ResponseWindowState` owns the current pending
original action, optional response item, response count, defender priority, and
window lifecycle. `DeterministicSimulationCore` remains the only transition
boundary that can advance or mutate those substates from submitted commands.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | HIGH - Godot 4.6.3 is post-cutoff and must be verified against local engine docs |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/current-best-practices.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None intentionally required for MVP board or stack state |
| **Verification Required** | Run headless Godot smoke tests after class registration and after any mutation API expansion |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001: MVP Deterministic Card Simulation Architecture; ADR-0002: MVP Card Effect Resolution Architecture |
| **Enables** | Future ADR for Action Log and Replay event schema; future ADR for Local Match Flow; future ADR for Match Authority Architecture |
| **Blocks** | Production implementation of replay persistence, attack resolution, damage/heal/move effects, and match UI mutation hooks until accepted |
| **Ordering Note** | This ADR refines ADR-0001's `MatchState` boundary. It must not let board, stack, UI, or effects bypass `DeterministicSimulationCore.submit_command()`. |

## Context

### Problem Statement

The project now has working GDScript classes for lane board state, runtime units,
pending response windows, and stack item snapshots. ADR-0001 establishes the
overall deterministic core, and ADR-0002 establishes card effect resolution, but
neither fully documents the board/stack substates that future action logs,
combat effects, UI queries, and replay verification must read. Without this
ADR, later systems could accidentally duplicate board ownership, mutate stack
state directly, or log incomplete transient response data.

### Current Implementation

The MVP skeleton implements:

- `BoardState` with stable lane order, player life totals, unit placement, and
  canonical board serialization.
- `LaneState` with one unit slot per player per lane.
- `UnitInstance` with copied runtime stats and deterministic instance ids.
- `ResponseWindowState` with `closed`, `open`, and `resolving` states.
- `StackItem` snapshots for original and response commands.
- `DeterministicSimulationCore` routing commands through response-window checks
  before board mutation.

### Constraints

- Godot version is pinned to 4.6.3.
- Client code language is GDScript for Web compatibility.
- Core state must stay scene-independent and testable headlessly.
- The authoritative match state remains owned by `DeterministicSimulationCore`.
- Board and response-window data must serialize canonically for hashing and
  future replay verification.
- UI, animation, networking, and prototype files must not directly mutate board
  or stack state.
- MVP stack depth is capped at one original item plus one response item.

### Requirements

- Represent the three-lane MVP board with deterministic lane order.
- Preserve the one-unit-per-player-per-lane invariant.
- Create runtime unit instances from immutable card definitions.
- Record original actions as pending before affected board mutation.
- Allow exactly one defender response or explicit `pass_response` per window.
- Resolve response effects before rechecking and resolving the original action.
- Serialize board state, response-window state, and stack item outcomes in a
  deterministic order.
- Keep all mutation reachable from accepted command transitions only.

## Decision

Use `RefCounted` state objects owned under `MatchState` for MVP board and
response-window state:

1. `MatchState.board` stores the current `BoardState`.
2. `BoardState` stores stable `lane_order`, lane instances, player life totals,
   and the next deterministic unit instance index.
3. Each `LaneState` stores a dictionary of unit slots keyed by player id.
4. Each `UnitInstance` stores runtime mutable unit values copied from a card
   definition at placement time.
5. `MatchState.response_window` stores the active `ResponseWindowState`.
6. `ResponseWindowState` stores one pending original `StackItem` and at most one
   response `StackItem`.
7. `StackItem` stores command identity, actor, card, target, and final
   resolution flags (`canceled`, `fizzled`, `resolved`, `outcome_reason`).
8. `DeterministicSimulationCore` is the only object allowed to call board and
   response-window mutation methods in response to player commands.

The implementation may expose board and response-window snapshots for early
tooling, but direct state references must be treated as read-only by callers.
Before UI or networking work starts, this should become an immutable snapshot or
copy API rather than a writable reference.

### Architecture Diagram

```text
ActionCommand
     |
     v
DeterministicSimulationCore
     |
     | owns transition ordering and command acceptance
     v
MatchState
     |
     +-- BoardState
     |     +-- LaneState[left, center, right]
     |     +-- UnitInstance records
     |     +-- player_life_by_id
     |
     +-- ResponseWindowState
           +-- original_item: StackItem
           +-- response_item: StackItem
           +-- defender_player_id
           +-- responses_used
```

### Key Interfaces

```gdscript
class_name BoardState
extends RefCounted

func initialize(player_ids: Array[StringName]) -> void
func can_place_unit(owner_player_id: StringName, lane_id: StringName) -> bool
func place_unit(owner_player_id: StringName, lane_id: StringName, definition: CardDefinition) -> UnitInstance
func to_canonical_data(player_order: Array[StringName]) -> Dictionary
```

```gdscript
class_name ResponseWindowState
extends RefCounted

func open_for_original(next_window_index: int, original_command: ActionCommand, defender_id: StringName) -> void
func clear() -> void
func is_open() -> bool
func has_priority(player_id: StringName) -> bool
func can_accept_response(player_id: StringName) -> bool
func to_canonical_data() -> Dictionary
```

```gdscript
class_name StackItem
extends RefCounted

static func from_command(kind: StringName, command: ActionCommand) -> StackItem
func to_canonical_data() -> Dictionary
```

### Ownership Rules

- `DeterministicSimulationCore` owns transition order, command acceptance,
  sequence checks, state hashes, and when substates mutate.
- `BoardState` owns lane existence, lane order, player life storage, unit
  placement, and runtime unit id allocation.
- `LaneState` owns same-owner lane-slot occupancy.
- `UnitInstance` owns mutable runtime unit stats after placement.
- `ResponseWindowState` owns active response-window lifecycle and defender
  priority checks.
- `StackItem` owns replay-facing original/response outcome flags.
- `CardEffectResolver` may set stack outcome flags only while invoked by the
  deterministic core during an accepted transition.
- UI, scenes, animation, and network adapters may read snapshots and submit
  commands, but must not write board, unit, response-window, or stack state.

## Alternatives Considered

### Alternative 1: Board and stack as scene-tree Nodes

- **Description**: Represent lanes, units, and stack prompts as Nodes that own
  their own gameplay state.
- **Pros**: Easy to inspect visually in the Godot editor; direct mapping to UI.
- **Cons**: Blurs presentation and rules ownership, makes headless replay
  harder, and risks hidden `_process` or input-driven mutation.
- **Rejection Reason**: Conflicts with ADR-0001 deterministic core boundaries.

### Alternative 2: Store board and stack only as event log projections

- **Description**: Avoid mutable board/stack objects and rebuild current state
  by replaying events after every command.
- **Pros**: Strong audit trail and simple persistence model.
- **Cons**: Expensive and awkward for immediate legal-action queries; premature
  before the action-log schema exists.
- **Rejection Reason**: MVP needs fast local command validation first. Replay
  can later consume the same canonical state and events.

### Alternative 3: Use untyped dictionaries for all board and stack state

- **Description**: Keep `MatchState` as a nested dictionary of lanes, units, and
  stack values.
- **Pros**: Simple serialization and quick iteration.
- **Cons**: Weak invariants, typo-prone fields, poor editor/compiler feedback,
  and harder targeted tests.
- **Rejection Reason**: Conflicts with typed GDScript and explicit ownership
  requirements.

## Consequences

### Positive

- Board, unit, and response-window invariants are isolated in small classes.
- Future replay can hash stack item outcomes and board state without reading UI.
- `cancel_original`, pass, and normal original resolution have one shared
  pending-item model.
- The model stays compatible with local smoke tests and future server authority.

### Negative

- `get_state_snapshot()` now returns a deep-copied canonical dictionary, so
  callers that need richer object queries must use explicit query APIs instead
  of mutating runtime state objects.
- Damage, healing, movement, attack readiness, focus spending, and structured
  event objects still require additional implementation.
- `BoardState.place_unit()` currently increments `next_unit_index` before
  `LaneState.add_unit()` succeeds; current callers pre-check legality, but
  future mutation methods should avoid consuming ids on failed lower-level adds.

### Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| UI code expects live `MatchState` objects from `get_state_snapshot()` | Medium | Medium | Keep the public API canonical and immutable; add explicit query APIs for richer UI needs |
| Stack outcome strings become permanent replay schema | Medium | Medium | Define structured event objects in Action Log and Replay ADR |
| Board and effect systems both try to own damage/move semantics | Medium | High | Board owns invariants; effect resolver requests mutations through board-owned APIs |
| Unit id allocation drifts after failed low-level placement | Low | Medium | Keep pre-validation in core now; adjust `place_unit()` when more placement paths are added |
| Focus/resource affordability is not yet enforced in response command code | Medium | Medium | Implement Turn/Timing/Resource state before expanding response card content |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `design/gdd/zone-lane-board-system.md` | Board has stable `left`, `center`, `right` lane order and one unit slot per player per lane | Locks `BoardState` and `LaneState` as the runtime ownership model |
| `design/gdd/zone-lane-board-system.md` | Board queries must not mutate state and board mutations must occur only through deterministic transitions | Keeps mutation behind `DeterministicSimulationCore` command acceptance |
| `design/gdd/stack-response-system.md` | Original actions are recorded as pending before affected gameplay mutation | Defines `ResponseWindowState.original_item` as the pending original snapshot |
| `design/gdd/stack-response-system.md` | MVP stack depth is one original plus one response | Defines `ResponseWindowState` as a two-item stack model |
| `design/gdd/stack-response-system.md` | Canceled and fizzled original actions remain replayable with final outcome reason | Requires `StackItem` outcome flags in canonical state |
| `design/gdd/card-effect-resolution-system.md` | `cancel_original` marks pending original stack items canceled before original recheck | Allows resolver to set stack outcome flags only during core-driven response resolution |
| `design/gdd/deterministic-simulation-core.md` | Match state serialization must be canonical and hashable | Requires board, response window, and stack item `to_canonical_data()` outputs |

## Performance Implications

- **CPU**: Lane occupancy query should remain within 50ms; placement and
  response/pass resolution should remain within 100ms before presentation
  animation.
- **Memory**: Small `RefCounted` objects per lane, unit, and active response
  window. No per-frame allocation requirement.
- **Load Time**: No meaningful load-time cost beyond class registration.
- **Network**: No direct network use. Future authority should send commands and
  hashes, not client-owned board or stack mutations.

## Migration Plan

1. Keep current board and response-window objects under `MatchState`.
2. Add structured event objects during the Action Log and Replay work.
3. Add explicit legal-action, board, stack, and prompt query helpers as UI needs
   grow; do not expose mutable runtime state objects.
4. Add damage, healing, movement, attack readiness, and focus spending through
   board/timing-owned APIs rather than direct dictionary writes.
5. Add automated tests through the selected Godot test framework after
   `/test-setup`; keep the smoke script as the immediate class-loading and
   deterministic hash check.

## Validation Criteria

- [ ] Godot 4.6.3 loads all board, unit, response-window, and stack classes
      without parse errors.
- [ ] Unit placement opens a response window before mutating the board.
- [ ] `pass_response` resolves the pending original placement.
- [ ] `play_response` with `cancel_original` prevents original board mutation.
- [ ] Duplicate same-owner lane placement is rejected without state mutation.
- [ ] Board state and response-window state appear in canonical match hashes.
- [ ] Production source does not import from `prototypes/`.
- [ ] Core board and stack code does not depend on scene tree state,
      `_process`, wall-clock time, or frame delta.

## Related Decisions

- `docs/architecture/adr-0001-mvp-deterministic-card-simulation.md`
- `docs/architecture/adr-0002-mvp-card-effect-resolution-architecture.md`
- `design/gdd/deterministic-simulation-core.md`
- `design/gdd/zone-lane-board-system.md`
- `design/gdd/stack-response-system.md`
- `design/gdd/card-effect-resolution-system.md`
