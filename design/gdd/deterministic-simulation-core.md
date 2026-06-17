# Deterministic Simulation Core

> **Status**: Designed
> **Author**: Codex
> **Last Updated**: 2026-06-17
> **Last Verified**: 2026-06-17
> **Implements Pillar**: Deterministic Trust; Rules Clarity Beats Hidden Complexity

## Summary

The Deterministic Simulation Core is the pure rules boundary for every match. It accepts explicit match setup data and validated player intentions, applies them in a stable order, and produces match state, event output, state hashes, and replayable action logs without depending on UI, networking, real time, or random engine state.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `Godot Project Foundation`

## Overview

This system is the foundation that makes Card Combat trustworthy. It defines how a match state is initialized, how commands enter the rules layer, how deterministic state transitions are applied, and how replay verification proves that the same starting state plus the same ordered actions always produces the same result. Players do not directly see this system, but they feel its effects every time the game explains a legal action, prevents an invalid move, resolves a response window consistently, or replays a disputed match outcome.

## Player Fantasy

This is an indirect player fantasy system. It supports the feeling that the duel is fair, inspectable, and skill-based: when players win or lose, they should believe the outcome came from visible decisions rather than hidden client behavior, timing accidents, or inconsistent resolution. The emotional target is quiet trust; the system should be invisible when working and immediately diagnosable when something goes wrong.

## Detailed Design

### Core Rules

1. The simulation core owns the authoritative in-memory `MatchState` for local MVP matches.
2. The simulation core must not read from UI nodes, scene tree state, wall-clock time, frame delta, input devices, network packets, file system state, or global random functions.
3. Every match starts from a `MatchSetup` payload containing:
   - rule set version
   - card data version
   - player ids
   - ordered deck ids for each player
   - initial seed
   - selected prototype or format configuration
4. Every player or AI action enters the system as an `ActionCommand`.
5. An `ActionCommand` must include:
   - command id
   - actor player id
   - command type
   - payload
   - local sequence number
   - optional expected state hash
6. The simulation validates a command before applying it.
7. A rejected command must not mutate `MatchState`.
8. A rejected command may produce a `RejectedCommandEvent` for debugging, UI feedback, and future networking diagnostics.
9. An accepted command applies exactly one deterministic transition batch.
10. A transition batch may emit multiple gameplay events, but the resulting `MatchState` is the source of truth.
11. Gameplay events are outputs of state transitions, not authoritative inputs.
12. All randomness must use a seeded deterministic random stream owned by `MatchState`.
13. Random stream reads must be logged by purpose, stream id, and draw index.
14. MVP simulation values must use integers, enums, booleans, arrays, and dictionaries with canonical ordering rules. Floating point values are forbidden in core match resolution.
15. State serialization must be canonical: equivalent states must serialize to the same byte/string representation on every supported client.
16. After every accepted command, the system must compute a state hash from canonical match state.
17. Replay must rebuild the match from `MatchSetup` and the ordered accepted commands, then compare final state hash and event sequence against expected output.
18. The simulation core may expose query functions for legal actions, legal targets, and preview data, but query functions must not mutate state.
19. The simulation core must support local MVP play first. Online authority and synchronization must wrap this system later rather than replacing it.
20. Production code must not import from `prototypes/`.

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| Uninitialized | No `MatchSetup` has been loaded | `initialize_match(setup)` succeeds | Rejects all gameplay commands |
| Ready | `MatchSetup` loaded and initial state built | First accepted command or match abort | Legal-action queries are valid |
| AwaitingCommand | Simulation is waiting for next command | Valid command is submitted, match ends, or abort occurs | No state changes except query cache invalidation |
| ResolvingCommand | Command passed validation and transition batch begins | Transition batch completes or fatal deterministic error occurs | Applies rules in stable order and emits events |
| Complete | Win/loss/draw/surrender condition reached | Replay or reset begins | Rejects further gameplay commands except replay/export commands |
| ErrorHalted | Deterministic invariant fails | Manual debug reset | Stops mutation and records diagnostic event |

Valid transition flow:

```text
Uninitialized -> Ready -> AwaitingCommand -> ResolvingCommand -> AwaitingCommand
AwaitingCommand -> Complete
ResolvingCommand -> Complete
Any active state -> ErrorHalted on invariant failure
Complete -> Ready only through full match reset/replay initialization
```

### Interactions with Other Systems

| System | Data In | Data Out | Ownership Boundary |
|--------|---------|----------|--------------------|
| Godot Project Foundation | Runtime location, project conventions, test runner setup | None | Godot hosts the code; simulation rules stay scene-independent |
| Card Data Model | Card definitions, effect ids, speed tags, localization keys, version id | Card ids referenced in state and events | Card data owns definitions; simulation owns resolved state |
| Turn, Timing, and Resource System | Turn phase rules, priority rules, resource rules | Phase state, active player, available command windows | Timing owns the meaning of turns; core owns transition ordering |
| Zone and Lane Board System | Zone definitions, lane capacity rules | Board occupancy state and zone snapshots | Board system owns spatial rules; core owns canonical state storage |
| Stack and Response System | Response-window rules and stack constraints | Pending command stack and response availability | Stack owns timing windows; core owns command application order |
| Card Effect Resolution System | Effect command definitions | State mutations and gameplay events | Effect system owns effect semantics; core enforces deterministic execution |
| Action Log and Replay System | Accepted commands, rejected-command diagnostics, state hashes | Replay verdicts and mismatch reports | Replay system owns persisted logs; core owns hash and transition behavior |
| Local Match Flow | Match setup request and player commands | Match state snapshots, events, legal-action queries | Match flow orchestrates play; core never reads UI state |
| Match Authority Architecture | Authority policy, expected hashes, command ordering | Server/client verification data | Authority wraps core; core stays transport-agnostic |
| Determinism Test Harness | Test setups and command sequences | Final hashes, event logs, invariant failures | Test harness proves behavior; core exposes deterministic APIs |

## Formulas

### Canonical State Hash

The `canonical_state_hash` formula is defined as:

`canonical_state_hash = stable_hash(canonical_serialize(match_state_core))`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| match_state_core | S | structured data | valid match state only | Authoritative state excluding UI caches, debug labels, and non-gameplay metadata |
| canonical_serialize | C(S) | function | deterministic string/bytes | Serializes keys, arrays, enums, integers, and booleans in a stable order |
| stable_hash | H(C) | function | SHA-256 lowercase hex string | `StableHash.stable_hash()` hashes the canonical string with `String.sha256_text()` |

**Output Range:** implementation-defined hash string or integer; identical state must produce identical output on every target platform.
**Example:** If two clients replay the same `MatchSetup` and action list, both must compute the same `canonical_state_hash` after command 25.

MVP implementation decision: `StableHash.canonical_string()` serializes
supported values with sorted dictionary keys and stable array order, then
`StableHash.stable_hash()` returns the SHA-256 lowercase hex digest of that
canonical string. UI, replay, and tooling receive deep-copied canonical
snapshots from `DeterministicSimulationCore.get_state_snapshot()`; direct
mutable `MatchState` references are not part of the public boundary.

### Replay Verification

The `replay_matches_expected` formula is defined as:

`replay_matches_expected = (final_hash == expected_final_hash) and (event_count == expected_event_count) and (mismatch_count == 0)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| final_hash | FH | hash | any valid state hash | Hash produced after replay finishes |
| expected_final_hash | EH | hash | any valid state hash | Hash recorded by the original run |
| event_count | EC | int | 0-10000 MVP safe cap | Number of events emitted during replay |
| expected_event_count | EE | int | 0-10000 MVP safe cap | Number of events recorded by the original run |
| mismatch_count | MC | int | 0+ | Number of command, hash, or event mismatches detected during replay |

**Output Range:** boolean.
**Example:** If `FH == EH`, `EC == EE`, and `MC == 0`, replay is verified. Any mismatch returns false and produces a diagnostic report.

### Command Sequence Validity

The `command_sequence_valid` formula is defined as:

`command_sequence_valid = command.sequence_id == next_expected_sequence_id[command.actor_player_id]`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| command.sequence_id | SID | int | 0-9999 MVP safe cap | Actor-local ordered command number |
| next_expected_sequence_id[player] | NES | int | 0-9999 MVP safe cap | Next accepted sequence number expected for that actor |
| command.actor_player_id | PID | enum/string id | valid player ids only | Player attempting the command |

**Output Range:** boolean.
**Example:** If Player A has accepted commands 0, 1, and 2, the next valid Player A command must use sequence id 3.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Command actor is not the active or priority-holding player | Reject command without mutating state; emit `RejectedCommandEvent` | Prevents clients from forcing illegal timing |
| Command sequence id is duplicated | Reject command without mutating state | Prevents accidental double-submit and replay ambiguity |
| Command sequence id skips ahead | Reject command and report expected id | Keeps logs gapless and replayable |
| Optional expected state hash differs from current hash | Reject command and report hash mismatch | Allows future clients/servers to detect desync early |
| Command payload references a missing card id | Reject command before effect resolution | Card data must be complete before simulation |
| Command payload references an illegal target | Reject command before mutation if legality can be known at validation time | UI and authority must agree on legal targets |
| Target becomes illegal during a later effect chain | Preserve the command in the log; downstream effect rules decide fizzled, partial, or retarget behavior | Simulation core records ordering but does not invent card-specific semantics |
| A rule requests randomness without a named deterministic stream | Enter `ErrorHalted` in development builds; reject in production builds | Hidden randomness breaks replay |
| Random stream draw order differs during replay | Replay fails with mismatch diagnostics | Draw order is part of deterministic behavior |
| Canonical serialization sees unordered dictionary keys | Sort keys before serialization | Prevents platform-specific key order drift |
| Floating point value enters `MatchState` core | Reject in validation or fail invariant | Cross-platform floating point drift is unacceptable for MVP rules |
| Match reaches safety cap for commands or events | Halt with diagnostic result; do not silently continue | Infinite loops and runaway effects must be visible |
| Replay uses a different rule set or card data version | Replay fails before first command | Replays are only meaningful under matching rules/data |
| Match is already complete and receives gameplay command | Reject command without mutating state | Completed outcomes must stay stable |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|----------------------|
| Godot Project Foundation | This depends on Godot Project Foundation | Needs project/test structure to host GDScript implementation |
| Card Data Model | Card Data Model depends on this | Uses deterministic data constraints and versioning requirements |
| Turn, Timing, and Resource System | Depends on this | Reads and writes turn phase state through core transition APIs |
| Zone and Lane Board System | Depends on this | Stores lane and zone state inside canonical match state |
| Stack and Response System | Depends on this | Requires deterministic command ordering and state mutation boundaries |
| Card Effect Resolution System | Depends on this | Applies effect transitions through the core |
| Action Log and Replay System | Depends on this | Persists accepted commands and validates state hashes |
| Local Match Flow | Depends on this | Drives local player turns through command submission and state snapshots |
| Match Board UI and Input | Depends on this indirectly | Queries legal actions, target sets, previews, and rejection reasons |
| Match Authority Architecture | Depends on this | Wraps the same deterministic rules for server/client validation |
| Determinism Test Harness | Depends on this | Runs scripted command sequences and checks replay results |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `MAX_COMMANDS_PER_MATCH` | 500 | 100-2000 | Allows longer matches and debugging sessions | Catches runaway matches sooner |
| `MAX_EVENTS_PER_COMMAND` | 64 | 16-256 | Allows more complex card effects | Catches runaway effect chains sooner |
| `STATE_HASH_FREQUENCY` | every accepted command | every command only for MVP | More frequent verification; no gameplay downside | Not recommended for MVP |
| `REJECTED_COMMAND_LOGGING` | enabled | enabled/disabled | Better diagnostics and UI feedback | Less noisy logs but harder debugging |
| `ALLOW_FLOATS_IN_CORE_STATE` | false | false only for MVP | Not allowed; would increase drift risk | Keeps deterministic integer-first rules |
| `QUERY_CACHE_ENABLED` | false | false/true | Faster repeated UI queries later | Simpler correctness and debugging now |

## Visual/Audio Requirements

This foundation system has no direct visual or audio presentation requirements. Downstream UI and feedback systems should consume emitted gameplay events and rejected-command reasons to decide what to show or play.

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Command accepted | Owned by Match Board UI | Optional UI confirmation sound later | Medium |
| Command rejected | Owned by Match Board UI | Optional soft error sound later | High |
| Replay mismatch | Owned by debug/test tooling | None | High |

## Game Feel

### Feel Reference

The system should feel like a reliable tournament judge: fast, consistent, and able to explain every ruling. The player should not feel the simulation layer directly, but UI fed by this system should make illegal actions and resolved outcomes feel immediate and defensible.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|--------|-----------------------------------|-------------------------|-------|
| Legal-action query for current hand/board | 50ms | 3 frames | Local MVP target on desktop and modern mobile |
| Command validation result | 50ms | 3 frames | UI should receive accepted/rejected result quickly |
| Simple command resolution | 100ms | 6 frames | Before VFX/animation delay; pure simulation target |
| Replay of 500-command log in debug mode | 1000ms | N/A | Tooling target, not per-frame gameplay |

### Animation Feel Targets

This system does not own animation. It must emit event timing data in a stable order so downstream UI can animate card movement, damage, response windows, and victory states without changing simulation results.

| Animation | Startup Frames | Active Frames | Recovery Frames | Feel Goal | Notes |
|-----------|---------------|--------------|----------------|-----------|-------|
| Not owned by this system | N/A | N/A | N/A | Simulation events should be available immediately | Match Board UI owns animation timing |

### Impact Moments

This system does not create impact effects. It marks event importance so downstream presentation systems can identify accepted commands, rejected commands, lethal resolution, replay mismatch, and phase transitions.

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|-------------|--------------|-------------------|---------------|
| Rejected command diagnostic | N/A | Emits reason code and affected command id | Yes |
| State hash mismatch | N/A | Emits mismatch report for debug/test UI | Yes |
| Match complete | N/A | Emits final outcome event | Yes |

### Weight and Responsiveness Profile

- **Weight**: Light and immediate; this system should not add dramatic delay.
- **Player control**: High clarity; players should quickly see whether an intended action is legal.
- **Snap quality**: Crisp and binary; commands are accepted or rejected with a reason.
- **Acceleration model**: Instant from command submission to validation.
- **Failure texture**: Fair and explanatory; invalid actions should state why they failed.

### Feel Acceptance Criteria

- [ ] Players never wait on pure simulation for simple local actions during MVP play.
- [ ] Invalid actions produce a specific reason rather than a generic failure.
- [ ] Replay mismatches point to the first divergent command or state hash.

## UI Requirements

The simulation core owns no screens, widgets, layout, animations, or input affordances. It must provide the following UI-facing data through query/result interfaces:

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|------------------|-----------|
| Legal action list | Match Board UI | On state change and selected card change | Player is choosing an action |
| Legal target set | Match Board UI | On selected action change | Action requires a target |
| Rejection reason | Match Board UI | Immediately after invalid command attempt | Command validation fails |
| Preview delta | Match Board UI | On legal action hover/tap/selection | UI asks for non-mutating preview |
| Event stream | Match Board UI and logs | After accepted command | Command resolution emits events |
| Current state hash | Debug/test UI | After accepted command | Debug overlays or replay tools enabled |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|------------|-----------------------------|--------|
| Match setup uses card data version | `design/gdd/card-data-model.md` | Card definition versioning | Data dependency |
| Turn legality is delegated | `design/gdd/turn-timing-resource-system.md` | Active player, phase, priority windows | Rule dependency |
| Lane occupancy is delegated | `design/gdd/zone-lane-board-system.md` | Lane and zone state | Data dependency |
| Response windows are delegated | `design/gdd/stack-response-system.md` | Stack/response constraints | Rule dependency |
| Effect semantics are delegated | `design/gdd/card-effect-resolution-system.md` | Card effect mutation rules | Ownership handoff |
| Replay persistence consumes hashes | `design/gdd/action-log-replay-system.md` | Accepted commands and state hashes | Data dependency |
| UI consumes legal action queries | `design/gdd/match-board-ui-input.md` | Legal actions, target sets, rejection reasons | Data dependency |
| Authority wraps deterministic core | `design/gdd/match-authority-architecture.md` | Trust boundary and command validation | Rule dependency |

## Acceptance Criteria

- [ ] **GIVEN** a valid `MatchSetup`, **WHEN** `initialize_match(setup)` runs twice with identical input, **THEN** both runs produce identical initial state hashes.
- [ ] **GIVEN** a valid current state, **WHEN** a legal `ActionCommand` is submitted, **THEN** the command mutates state exactly once and appends one accepted command record.
- [ ] **GIVEN** an illegal `ActionCommand`, **WHEN** validation fails, **THEN** match state hash remains unchanged and a rejection reason is available.
- [ ] **GIVEN** two replays with the same setup and accepted command list, **WHEN** replay completes, **THEN** final hash, event count, and winner match.
- [ ] **GIVEN** a command with a duplicate actor-local sequence id, **WHEN** it is submitted, **THEN** the command is rejected without mutation.
- [ ] **GIVEN** a command with mismatched expected state hash, **WHEN** it is submitted, **THEN** the command is rejected and reports expected vs actual hash.
- [ ] **GIVEN** any core state serialization, **WHEN** dictionary-like structures are serialized, **THEN** keys are ordered canonically.
- [ ] **GIVEN** any core match value, **WHEN** validation scans the state, **THEN** no floating point values are present.
- [ ] **GIVEN** an effect requests randomness, **WHEN** no deterministic stream is specified, **THEN** development builds halt with an invariant failure.
- [ ] **GIVEN** a 500-command MVP replay log, **WHEN** replay runs in debug tooling, **THEN** verification completes within 1000ms on the target development machine.
- [ ] Performance: simple command validation and pure resolution each complete within the latency targets listed in Game Feel before presentation animation.
- [ ] No production implementation imports code or data from `prototypes/`.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|------------|
| Should rejected commands be part of the persisted replay log or only debug logs? | Systems Designer / Network Programmer | Before online play | Pending action log GDD |
| Does MVP need multiple deterministic RNG streams or one match-level stream? | Systems Designer | Before card effect GDD | Pending card rules design |

---

## Lean Review Notes

`creative-director`, `systems-designer`, and `qa-lead` specialist review were not run inline because the project is in `lean` review mode and the current environment does not treat sub-agent delegation as explicitly requested by the user. Run `/design-review design/gdd/deterministic-simulation-core.md` in a fresh session before approval.
