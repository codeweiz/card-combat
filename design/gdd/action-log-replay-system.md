# Action Log and Replay System

> **Status**: Designed
> **Author**: Codex
> **Last Updated**: 2026-06-17
> **Last Verified**: 2026-06-17
> **Implements Pillar**: Deterministic Trust; Rules Clarity Beats Hidden Complexity; Cross-Platform First

## Summary

The Action Log and Replay System records the deterministic match inputs and
outputs needed to prove that a duel can be reconstructed from its starting setup
and accepted commands. It stores match setup metadata, card data compatibility,
accepted command order, result events, and state hashes so local tests, future
match authority, debug tools, and player-facing replays can identify exactly
where a match diverged.

> **Quick reference** - Layer: `Feature` · Priority: `MVP` · Key deps: `Deterministic Simulation Core`, `Card Effect Resolution System`

## Overview

Card Combat needs replayable action logs before it needs online infrastructure.
This system is the persistence contract around the deterministic rules core:
record every accepted command with enough context to replay it, record the
simulation result that followed, and verify later that a fresh simulation reaches
the same event order and state hash. The MVP log is not a video replay or UI
animation timeline. It is a rules audit trail that future UI replay, match
authority, bug reports, and determinism tests can consume.

## Player Fantasy

Players should feel that the game can explain itself. If a response cancels a
unit, a card fizzles, or a match result is disputed, the answer should be
inspectable rather than mysterious. Most players experience this indirectly
through consistent outcomes, clear logs, and trustworthy replay playback; serious
players and testers can use it to study decisions and prove that a match resolved
under the same rules for everyone.

## Detailed Design

### Core Rules

1. An action log belongs to exactly one match run.
2. A log must start with immutable `MatchSetup` data needed to rebuild the
   initial deterministic match state.
3. A log must record `rule_set_version`, `format_id`, `initial_seed`,
   `player_ids`, and `card_data_hash`.
4. A log must fail compatibility before replay if the current runtime cannot
   provide the same rule set version and card data hash.
5. Canonical replay records accepted commands, not client-owned outcomes.
6. Rejected commands are optional debug diagnostics and do not become canonical
   replay inputs in MVP.
7. Every accepted command entry must record:
   - log index
   - command id
   - actor player id
   - actor-local sequence id
   - command type
   - command payload
   - state hash before submission
   - accepted result events
   - state hash after resolution
8. Command entries must be append-only after they are accepted.
9. The accepted command order is the replay order.
10. Replay starts from a fresh `DeterministicSimulationCore` initialized with the
    logged setup and matching card database.
11. Replay submits each logged accepted command in order.
12. Before each replayed command, the replay runner compares the current state
    hash to the entry's recorded `state_hash_before`.
13. After each replayed command, the replay runner compares:
    - accepted/rejected status
    - result event sequence
    - state hash after resolution
14. Any mismatch produces a deterministic replay mismatch report.
15. MVP replay stops at the first blocking mismatch.
16. Tooling may collect up to `MAX_REPLAY_MISMATCHES_REPORTED_MVP` mismatches in
    diagnostic mode, but a single mismatch is enough to fail verification.
17. Event order is significant.
18. Runtime string events are accepted only for the current smoke skeleton.
    Replay fixtures, UI replay, and future authority must use the structured
    `SimulationEvent` schema defined in this GDD.
19. Structured event records must include:
    - `event_schema_version`
    - `global_event_index`
    - `command_event_index`
    - `event_type`
    - `source_command_id`
    - `source_stack_item_id` or empty id when not applicable
    - `actor_player_id` or empty id when not applicable
    - `primary_card_id` or empty id when not applicable
    - `target_ref` with deterministic target coordinates or empty data
    - deterministic `payload`
20. Event records must not contain UI nodes, animation handles, wall-clock time,
    frame delta, object memory ids, or localized display strings.
21. Replay must compare structured event records by canonical field order.
22. Replay must not read from input devices, scene tree state, network state,
    file system state, wall-clock time, or global random functions.
23. Any future random effect must log deterministic random stream id and draw
    index; MVP does not require random card effects.
24. A replay may be displayed by UI, but UI playback reads log data and derived
    simulation snapshots. It must not change replay results.
25. Saved logs may include non-canonical metadata such as build label, device,
    capture time, or debug notes, but those fields are excluded from replay
    verification formulas.
26. Logs should be serializable as deterministic dictionaries/arrays first.
    Binary compression or cloud storage is out of scope for MVP.
27. The action log is not the authority model by itself. Future match authority
    must validate commands before accepting them into the log.
28. Production code must not import prototype play logs from `prototypes/`.
29. The smoke script's final hash is acceptable as early evidence, but proper
    replay tests must be added through the test harness.

### Structured Event Schema

Minimum MVP `SimulationEvent` shape:

```text
SimulationEvent
  event_schema_version: int
  global_event_index: int
  command_event_index: int
  event_type: StringName
  source_command_id: StringName
  source_stack_item_id: StringName
  actor_player_id: StringName
  primary_card_id: StringName
  target_ref: EventTargetRef
  payload: Dictionary[StringName, Variant]
```

Minimum MVP `EventTargetRef` shape:

```text
EventTargetRef
  target_kind: StringName
  player_id: StringName optional
  lane_id: StringName optional
  unit_instance_id: StringName optional
  card_id: StringName optional
```

MVP event type ids:

| Event Type | Required Payload Fields | Notes |
|------------|-------------------------|-------|
| `match_initialized` | `state_hash_after` | First event after setup succeeds |
| `command_accepted` | `state_hash_before` | Optional wrapper event if command entries need explicit accepted marker |
| `response_window_opened` | `window_id`, `defender_player_id`, `pending_original_command_id` | Original action has not yet applied affected mutation |
| `response_passed` | `window_id` | Explicit replayable defender pass |
| `response_played` | `window_id`, `response_card_id` | Response stack item accepted |
| `effect_resolved` | `effect_id`, `outcome` | Generic effect success event |
| `effect_fizzled` | `effect_id`, `reason` | Effect failed without mutation |
| `original_canceled` | `original_command_id`, `reason` | Pending original will not resolve |
| `original_fizzled` | `original_command_id`, `reason` | Pending original target/current legality failed |
| `unit_played` | `unit_instance_id`, `lane_id`, `owner_player_id` | Original placement resolved |
| `unit_damaged` | `unit_instance_id`, `amount`, `health_after` | Future damage effect |
| `unit_healed` | `unit_instance_id`, `amount`, `health_after` | Future heal effect |
| `unit_moved` | `unit_instance_id`, `source_lane_id`, `destination_lane_id` | Future movement effect |
| `unit_destroyed` | `unit_instance_id`, `reason` | Unit removed from lane |
| `match_completed` | `winner_player_id`, `loser_player_id`, `end_reason`, `final_state_hash` | Terminal result |

Canonical event ordering is by `global_event_index`, then by
`command_event_index` inside the command entry. Event payload dictionaries must
serialize with sorted keys through `StableHash.canonical_string()`.

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| NoLog | No match log exists | Match setup accepted | No replay data exists |
| Recording | Match initialized and log header written | Command accepted or match ends | Ready to append accepted command entries |
| CommandPending | Command submitted to core | Core accepts or rejects command | State hash before command is known |
| EntryAppended | Command accepted and result captured | Next command or match finalization | Entry is immutable replay input |
| Finalized | Match complete or recording stopped | Replay requested | Log can no longer accept match entries |
| ReplayInitializing | Replay runner receives log and card database | Compatibility passes or fails | Rebuild initial deterministic state |
| Replaying | Replay is submitting accepted commands | All commands match or mismatch occurs | Compares before/after hashes and events |
| Verified | Replay completes without mismatch | Report consumed | Log is verified against current runtime/data |
| Mismatch | A hash, event, or acceptance result differs | Report consumed or replay aborted | Replay has failed |
| Incompatible | Rule set or card data hash does not match | Correct runtime/data supplied | Replay cannot start safely |

Valid flow:

```text
NoLog -> Recording -> CommandPending -> EntryAppended -> Recording
Recording -> Finalized
Finalized -> ReplayInitializing -> Replaying -> Verified
ReplayInitializing -> Incompatible
Replaying -> Mismatch
```

### Interactions with Other Systems

| System | Data In | Data Out | Ownership Boundary |
|--------|---------|----------|--------------------|
| Deterministic Simulation Core | `MatchSetup`, `ActionCommand`, `SimulationResult`, state hashes | Accepted command entries, replay verification input | Core owns resolution; log records inputs/outputs |
| Card Data Model | `card_data_hash`, card definitions for replay | Compatibility verdict | Card data owns definitions; replay refuses mismatched data |
| Turn, Timing, and Resource System | Phase/resource/focus events | Replayable timing sequence | Timing owns rules; log records deterministic outputs |
| Zone and Lane Board System | Board mutation events and state hashes | Replayable board progression | Board owns state; log records hash/effect evidence |
| Stack and Response System | Original, response, pass, cancel/fizzle events | Replayable stack sequence | Stack owns ordering; log preserves outcomes |
| Card Effect Resolution System | Effect outcome events | Replayable mutation event sequence | Effects own semantics; log stores ordered outcomes |
| Local Match Flow | Match start/end and player command submissions | Recording lifecycle and replay request entry point | Match flow orchestrates; log does not read UI |
| Determinism Test Harness | Test logs and expected hashes | Pass/fail replay reports | Test harness runs replay verification |
| Match Authority Architecture | Future authoritative accepted commands | Audit trail and desync evidence | Authority validates; log persists accepted facts |
| Match Board UI and Input | Replay snapshots/events | Playback timeline and debug panels | UI presents replay but never mutates canonical log |

## Formulas

### Action Log Entry Complete

The `action_log_entry_complete` formula is defined as:

`action_log_entry_complete = command_recorded and state_hash_before_recorded and result_recorded and state_hash_after_recorded`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| command_recorded | C | bool | true/false | The accepted `ActionCommand` and payload were written to the entry |
| state_hash_before_recorded | B | bool | true/false | The state hash before command submission was written |
| result_recorded | R | bool | true/false | Accepted status and ordered result events were written |
| state_hash_after_recorded | A | bool | true/false | The state hash after command resolution was written |

**Output Range:** boolean.
**Example:** A `play_response` entry is complete only when the command, prior
hash, `response_played`/effect/original outcome events, and post-resolution hash
are all present.

### Replay Step Matches Expected

The `replay_step_matches_expected` formula is defined as:

`replay_step_matches_expected = before_hash_matches and command_reaccepted and events_match and after_hash_matches`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| before_hash_matches | B | bool | true/false | Fresh replay state hash equals the entry's recorded `state_hash_before` |
| command_reaccepted | C | bool | true/false | The core accepted the command during replay |
| events_match | E | bool | true/false | Replay result events match the recorded events in order |
| after_hash_matches | A | bool | true/false | Replay state hash after command equals the recorded `state_hash_after` |

**Output Range:** boolean.
**Example:** If a response cancel emits the same events but leaves a different
final hash, this formula returns false because `after_hash_matches` is false.

### Replay Matches Expected

The `replay_matches_expected` formula is defined as:

`replay_matches_expected = (final_hash == expected_final_hash) and (event_count == expected_event_count) and (mismatch_count == 0)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| final_hash | FH | hash | any valid state hash | Hash produced after replay finishes |
| expected_final_hash | EH | hash | any valid state hash | Final hash recorded by the original run |
| event_count | EC | int | 0-10000 MVP safe cap | Number of replayed result events |
| expected_event_count | EE | int | 0-10000 MVP safe cap | Number of result events recorded by the original run |
| mismatch_count | MC | int | 0+ | Number of command, event, compatibility, or hash mismatches |

**Output Range:** boolean.
**Example:** If final hash and event count match and no mismatch was reported,
the replay is verified.

### Replay Data Compatible

The `replay_data_compatible` formula is defined as:

`replay_data_compatible = rule_set_version_matches and card_data_hash_matches and log_schema_supported`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| rule_set_version_matches | R | bool | true/false | Current runtime supports the logged rule set version |
| card_data_hash_matches | C | bool | true/false | Current card database hash equals the logged card data hash |
| log_schema_supported | S | bool | true/false | Runtime can read the log schema version |

**Output Range:** boolean.
**Example:** An old replay with a different card data hash fails before any
command is submitted.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Log header is missing setup data | Mark log invalid and do not replay | Replay cannot rebuild the initial state safely |
| Card data hash differs | Return `Incompatible`; do not attempt command playback | Prevents silent misinterpretation of old cards |
| Rule set version differs | Return `Incompatible` unless runtime explicitly supports that version | Rules changes can alter deterministic outcomes |
| Command entry lacks state hash before or after | Mark entry incomplete and fail validation before replay | Hash comparisons are required evidence |
| Replayed command is rejected | Stop with mismatch at that command index | Original log claims the command was accepted |
| Events differ but final hash matches | Report mismatch | UI/replay/authority still rely on event order and explanations |
| Events match but final hash differs | Report mismatch | State is authoritative even if event text looks correct |
| A command id appears twice | Fail log validation | Duplicate command ids break auditability |
| Actor-local sequence id has a gap | Fail replay before command playback or report mismatch at first gap | Sequence order must be gapless |
| Rejected command appears in debug sidecar | Keep it out of canonical replay input | Debug diagnostics should not change replay |
| Match is not complete but recording stops | Mark log as partial; allow diagnostic replay but not verified match replay | Partial logs are useful for bugs but not final proof |
| Replay reaches safety cap | Halt with mismatch diagnostic | Prevents infinite replay loops |
| Non-canonical metadata differs | Ignore for verification | Device/build notes should not affect rules correctness |
| Structured event schema is unavailable | Use string events only for smoke/local diagnostics; block UI replay production stories | Prevents temporary strings becoming a shipped contract |
| Replay requested while live recording is active | Use a snapshot copy or reject until finalized | Replay must not mutate the live match |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|----------------------|
| Deterministic Simulation Core | This depends on Deterministic Simulation Core | Needs setup, commands, results, state hashes, and deterministic reinitialization |
| Card Data Model | This depends on Card Data Model | Replays require matching card data hash and loadable card definitions |
| Card Effect Resolution System | This depends on Card Effect Resolution System | Effect outcomes and events must be deterministic and ordered |
| Stack and Response System | This depends on Stack and Response System | Logs response/pass/cancel/fizzle stack outcomes |
| Zone and Lane Board System | This depends on Zone and Lane Board System | Logs board mutation evidence through events and hashes |
| Turn, Timing, and Resource System | This depends on Turn, Timing, and Resource System | Logs phase/resource/focus events and timing rejections |
| Local Match Flow | Depends on this | Starts/stops recording and requests local playback |
| Determinism Test Harness | Depends on this | Runs replay verification as automated tests |
| Match Authority Architecture | Depends on this | Uses accepted command logs and hashes for audit/desync diagnostics |
| Match Board UI and Input | Depends on this indirectly | Displays replay timeline and log explanations |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `REPLAY_HASH_CHECK_FREQUENCY` | every accepted command | every accepted command only for MVP | Not applicable; strongest verification | Weaker diagnostics if less frequent |
| `PERSIST_REJECTED_COMMANDS_MVP` | false for canonical log | false; debug sidecar allowed | More diagnostics if true later | Smaller and cleaner replay inputs |
| `MAX_REPLAY_MISMATCHES_REPORTED_MVP` | 10 | 1-50 | More batch diagnostics | Faster fail-fast reports |
| `MAX_COMMANDS_PER_MATCH` | 500 | 100-2000 | Supports longer matches | Catches runaway sessions sooner |
| `MAX_EVENTS_PER_COMMAND` | 64 | 16-256 | Supports complex effect batches | Catches runaway effect chains sooner |
| `LOG_NON_CANONICAL_METADATA` | true | true/false | Better bug reports | Smaller log files |
| `STRUCTURED_EVENT_SCHEMA_REQUIRED` | before UI replay production | true before UI/authority | Safer long-term contract | Faster prototype if delayed |

## Visual/Audio Requirements

This is mostly an infrastructure system. It does not own match VFX or audio, but
future replay UI needs a few presentation cues fed by log verification state.

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Replay verified | Debug/test UI shows verified status and final hash | None | Medium |
| Replay mismatch | Debug/test UI highlights first mismatching command index and field | Error sound optional in tools | High |
| Incompatible replay | UI explains rule/card/log schema mismatch | None | High |
| Replay playback step | Future replay UI advances command/result timeline | Optional subtle tick later | Medium |

## Game Feel

### Feel Reference

The log should feel like a clean match transcript, not like a developer dump.
Players and testers should be able to answer "what happened, in what order, and
why did replay fail?" without parsing engine internals.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|--------|-----------------------------------|-------------------------|-------|
| Append accepted command entry | 10ms | <1 frame | Local memory target before persistence |
| Validate log header compatibility | 50ms | 3 frames | Before replay starts |
| Replay one simple command | 100ms | 6 frames | Same pure simulation budget as core |
| Replay 500-command MVP log | 1000ms | N/A | Debug/tooling target |

### Weight and Responsiveness Profile

- **Weight**: Light during live play; logging must not create visible delay.
- **Player control**: Indirect; players trust outcomes and can inspect playback.
- **Snap quality**: Exact and chronological; each command has one clear result.
- **Failure texture**: Diagnostic; mismatch reports name the first divergent
  command, field, expected value, and actual value.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|------------------|-----------|
| Current state hash | Debug overlay/test report | After accepted command | Debug tools enabled |
| Log verification status | Replay/debug panel | On replay complete/fail | Replay requested |
| First mismatch command index | Replay/debug panel | On mismatch | Replay mismatch |
| Expected vs actual event/hash | Replay/debug panel | On mismatch | Replay mismatch |
| Command timeline | Future replay UI | Per replay step | Player-facing replay enabled |
| Incompatibility reason | Replay load dialog/debug panel | On load failure | Card/rule/schema mismatch |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|------------|-----------------------------|--------|
| Replays rebuild from setup and accepted commands | `design/gdd/deterministic-simulation-core.md` | setup, commands, hashes | Data dependency |
| Card data hash gates replay compatibility | `design/gdd/card-data-model.md` | `card_data_hash` | Data dependency |
| Response outcomes must be logged | `design/gdd/stack-response-system.md` | pass, cancel, fizzle, original resolution | Rule dependency |
| Board mutations must be replayable | `design/gdd/zone-lane-board-system.md` | lane occupancy and unit state hashes | State dependency |
| Effect outcomes feed replay events | `design/gdd/card-effect-resolution-system.md` | ordered effect outcomes | Data dependency |
| Future match flow starts/stops recording | `design/gdd/local-match-flow.md` | local duel lifecycle | Future dependency |
| Future authority consumes logs | `design/gdd/match-authority-architecture.md` | command validation and desync audit | Future dependency |

## Acceptance Criteria

- [ ] **GIVEN** a match is initialized, **WHEN** recording starts, **THEN** the log header contains setup, player ids, rule set version, format id, initial seed, and card data hash.
- [ ] **GIVEN** an accepted command, **WHEN** the log records it, **THEN** the entry includes command payload, state hash before, ordered result events, and state hash after.
- [ ] **GIVEN** a rejected command, **WHEN** canonical replay input is built, **THEN** the rejected command is excluded from accepted command playback.
- [ ] **GIVEN** a log with matching card data hash and rule set version, **WHEN** replay starts, **THEN** a fresh deterministic core initializes to the same initial state hash.
- [ ] **GIVEN** a complete accepted command log, **WHEN** replay submits commands in order, **THEN** every command is accepted during replay.
- [ ] **GIVEN** a replayed command emits events, **WHEN** events are compared with the log, **THEN** event order and content match exactly.
- [ ] **GIVEN** a replayed command resolves, **WHEN** state hash is compared, **THEN** the replay hash equals the recorded post-command hash.
- [ ] **GIVEN** a replay produces a different event or hash, **WHEN** mismatch is reported, **THEN** the report names the first mismatching command index and field.
- [ ] **GIVEN** card data hash differs, **WHEN** replay is requested, **THEN** replay returns `Incompatible` before command playback.
- [ ] **GIVEN** rule set version differs, **WHEN** runtime lacks explicit support for that version, **THEN** replay returns `Incompatible`.
- [ ] **GIVEN** duplicate command ids in a log, **WHEN** log validation runs, **THEN** validation fails before replay.
- [ ] **GIVEN** an incomplete entry missing required hashes, **WHEN** log validation runs, **THEN** validation fails before replay.
- [ ] **GIVEN** two identical setup and accepted command sequences, **WHEN** both are replayed, **THEN** `replay_matches_expected` returns true.
- [ ] Performance: replay of a 500-command MVP log completes within 1000ms on the target development machine in headless/debug tooling.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|------------|
| Should rejected commands become part of a signed authority audit log later? | Network Programmer / QA Lead | Before Match Authority ADR | Provisional: debug sidecar only for MVP |
| Should player-facing replay store intermediate snapshots or rebuild them on demand? | Gameplay Programmer / UX Designer | Before replay UI | Provisional: rebuild from commands for verification; optional cached snapshots for UI later |
| What serialization format should saved logs use on disk/cloud? | Tools Programmer / Backend Engineer | Before persistence implementation | Provisional: deterministic dictionary/JSON-like schema for MVP tooling |
| How should old replay compatibility be handled after card errata? | Systems Designer / Producer | Before live content updates | Provisional: require exact card data hash for MVP |

---

## Lean Review Notes

Specialist review was not run inline because `production/review-mode.txt` is set
to `lean` and no subagent spawn was explicitly requested. Run
`/design-review design/gdd/action-log-replay-system.md` in a fresh session before
approval.
