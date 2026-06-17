# Zone and Lane Board System

> **Status**: Designed
> **Author**: Codex
> **Last Updated**: 2026-06-17
> **Last Verified**: 2026-06-17
> **Implements Pillar**: Rules Clarity Beats Hidden Complexity; Deterministic Trust

## Summary

The Zone and Lane Board System owns the deterministic board layout for MVP duels: players, life totals, zones, lanes, and unit occupancy. It formalizes the first prototype's three-lane pressure so placement can become a real command instead of a paper-only notation.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Deterministic Simulation Core`, `Card Data Model`

## Overview

The board is the visible tactical surface of a match. MVP play uses three lanes: Left, Center, and Right. Each lane has one slot per player, so both players may have a unit contesting the same lane, but a player cannot stack multiple units into the same lane. This system owns zone and lane state, unit instances, occupancy checks, player life totals, and board snapshots for UI, replay, and future effect resolution.

## Player Fantasy

Players should feel that board position matters. Playing a unit is not just "summon stats"; it is a commitment to a lane. Blocking one lane should not erase pressure in the other lanes, and the board should always make it obvious where threats and defenses are located.

## Detailed Design

### Core Rules

1. MVP matches have exactly two players.
2. Each player starts with `STARTING_PLAYER_LIFE`.
3. The MVP board has exactly three lanes: `left`, `center`, and `right`.
4. Lane order is stable: `left`, `center`, `right`.
5. Each lane has one unit slot per player.
6. A player may control at most one unit in a given lane.
7. Both players may have a unit in the same lane at the same time.
8. A unit card can be placed only into an empty lane slot controlled by its owner.
9. A unit instance must have:
   - `unit_instance_id`
   - `owner_player_id`
   - `card_id`
   - `attack`
   - `health`
   - `max_health`
   - `ready`
10. Unit instance ids must be deterministic and unique within a match.
11. MVP unit stats are copied from validated card data at placement time.
12. Card definition data remains immutable after placement; runtime damage modifies only the unit instance.
13. A unit with health less than or equal to 0 is destroyed and removed from its lane.
14. Destroyed units do not remain on the board.
15. Movement between lanes must preserve owner and unit instance id.
16. Movement is legal only if the destination lane slot for that owner is empty.
17. Adjacent movement is allowed only between `left <-> center` and `center <-> right`.
18. Cross-lane movement from `left` to `right` or `right` to `left` is illegal unless a future effect explicitly allows it.
19. Board state must serialize lanes in stable lane order and players in stable player order.
20. Board queries must not mutate state.
21. Placement, movement, damage, healing, and destruction are mutation operations and must be called only through deterministic simulation transitions.
22. UI may request board snapshots but may not write board state directly.

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| Empty Slot | Lane slot has no unit for a player | Unit is placed or moved in | Legal placement target |
| Occupied Slot | Lane slot has one unit for a player | Unit moves, is destroyed, or is removed by rule | Blocks same-owner placement |
| Ready Unit | Unit survived since prior owner turn and ready flag is true | Unit attacks or becomes exhausted by effect | Eligible for future attack declarations |
| Exhausted Unit | Unit entered this turn or attacked this turn | Owner start/ready step marks ready | Not eligible to attack |
| Damaged Unit | Unit health is below max but above 0 | Healed, damaged to 0, or destroyed | Remains in lane |
| Destroyed Unit | Unit health is 0 or lower | Removed from board | Cannot act or be targeted on board |

### Interactions with Other Systems

| System | Data In | Data Out | Ownership Boundary |
|--------|---------|----------|--------------------|
| Deterministic Simulation Core | Mutation calls and command context | Canonical board state and mutation result | Core applies transitions; board owns board invariants |
| Card Data Model | Unit card ids and prototype unit stats | Unit instances created from card ids | Card data owns definitions; board owns runtime instances |
| Turn, Timing, and Resource System | AttackPhase and ready timing | Ready/exhausted eligibility | Timing owns when units can act |
| Stack and Response System | Pending move/placement/attack response windows | Current board legality after responses | Stack owns timing; board owns spatial legality |
| Card Effect Resolution System | Damage, heal, move, destroy requests | Mutated unit and lane state | Effects request changes; board validates spatial/state constraints |
| Match Board UI and Input | Board snapshots and legal lane targets | Lane display, targeting affordances | UI displays snapshots, never mutates |
| Action Log and Replay System | Board mutation events | Replayable board state sequence | Replay consumes deterministic board outputs |

## Formulas

### Lane Occupancy Valid

The `lane_occupancy_valid` formula is defined as:

`lane_occupancy_valid = lane_exists and owner_player_id_valid and slot_empty_for_owner`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| lane_exists | L | bool | true/false | Target lane is one of the legal MVP lanes |
| owner_player_id_valid | P | bool | true/false | Owner is one of the two match players |
| slot_empty_for_owner | S | bool | true/false | Owner has no unit in that lane |

**Output Range:** boolean.
**Example:** Player A can place a unit in Center if Center exists and Player A has no unit in Center, even if Player B already has a unit there.

### Adjacent Lane Move Valid

The `adjacent_lane_move_valid` formula is defined as:

`adjacent_lane_move_valid = abs(source_lane_index - destination_lane_index) == 1 and destination_slot_empty`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| source_lane_index | S | int | 0-2 | Stable index of source lane |
| destination_lane_index | D | int | 0-2 | Stable index of destination lane |
| destination_slot_empty | E | bool | true/false | Destination slot is empty for the moving unit owner |

**Output Range:** boolean.
**Example:** Left to Center is valid when the owner's Center slot is empty; Left to Right is invalid for MVP adjacent movement.

### Unit Destroyed

The `unit_destroyed` formula is defined as:

`unit_destroyed = unit.health <= 0`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| unit.health | H | int | -999 to 999 MVP safe range | Current runtime health for the unit instance |

**Output Range:** boolean.
**Example:** A 2-health unit that takes 2 damage is destroyed and removed from its lane.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Player tries placing into their occupied lane slot | Reject command without mutation | Lane cap is core tactical constraint |
| Player places unit opposite enemy unit in same lane | Allow placement if owner's slot is empty | Both players can contest a lane |
| Target lane id is unknown | Reject command without mutation | Prevents invalid board coordinates |
| Owner player id is unknown | Reject command without mutation | Prevents orphan units |
| Unit card lacks unit stats | Reject placement before mutation | Board cannot create ambiguous runtime unit |
| Unit health reaches exactly 0 | Destroy and remove unit | Keeps destruction threshold simple |
| Unit takes damage beyond 0 | Destroy and remove unit; do not preserve negative board health | Board display should stay clean |
| Unit is moved to occupied own slot | Reject movement without mutation | Prevents illegal stacking |
| Unit is moved to occupied enemy slot | Allow if own destination slot is empty | Enemy unit occupies the opposite side of same lane, not the same slot |
| Unit moves from left to right directly | Reject for MVP adjacent movement | Keeps movement readable |
| Two effects attempt to move same unit in one transition batch | Resolve by stack/effect order; second checks current lane after first | Board validates current state at each mutation |
| UI asks for legal lanes during response window | Return non-mutating legal target data | UI must preview without changing state |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|----------------------|
| Deterministic Simulation Core | This depends on Deterministic Simulation Core | Board mutations occur inside deterministic transitions |
| Card Data Model | This depends on Card Data Model | Unit placement reads card ids and prototype unit stats |
| Turn, Timing, and Resource System | This depends on timing for attack/ready windows | Attack eligibility depends on phase and readiness |
| Stack and Response System | Depends on this | Responses can alter lane state before action resolution |
| Card Effect Resolution System | Depends on this | Effects apply damage, healing, movement, and destruction |
| Action Log and Replay System | Depends on this | Logs board mutation events and verifies replayed board state |
| Match Board UI and Input | Depends on this | Displays lanes, units, legal placement targets, and target highlights |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `LANE_COUNT_MVP` | 3 | 3 only for MVP | Not tunable until later formats | Three lanes are the prototype baseline |
| `MAX_UNITS_PER_PLAYER_PER_LANE` | 1 | 1 only for MVP | Not tunable until later formats | Preserves lane commitment |
| `STARTING_PLAYER_LIFE` | 20 | 15-40 | Longer matches and more comeback space | Shorter matches, more burst pressure |
| `UNIT_READY_ON_OWNER_NEXT_TURN` | true | true/false | Slower board development | Faster aggression if false |
| `ALLOW_ADJACENT_MOVEMENT_ONLY` | true | true/false | Keeps movement readable | Allows more dramatic movement effects if false |

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Unit placed | Unit card appears in chosen lane slot | Soft placement sound later | High |
| Lane full for owner | Slot disabled with reason | Error sound optional | High |
| Unit moved | Unit travels from source to destination lane | Movement sound optional | Medium |
| Unit damaged | Health marker changes and damage event shown | Hit sound later | High |
| Unit destroyed | Unit removed with clear destruction feedback | Destruction sound later | High |

## Game Feel

### Feel Reference

Lane interaction should feel like a readable tactical board, closer to a compact digital duel board than a freeform battlefield. The board should answer "where is the threat?" instantly.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|--------|-----------------------------------|-------------------------|-------|
| Query legal placement lanes | 50ms | 3 frames | On card selection |
| Place unit into lane | 100ms | 6 frames | Pure simulation before animation |
| Move unit between adjacent lanes | 100ms | 6 frames | Pure simulation before animation |
| Update unit health/destroyed state | 100ms | 6 frames | Pure simulation before animation |

### Animation Feel Targets

| Animation | Startup Frames | Active Frames | Recovery Frames | Feel Goal | Notes |
|-----------|---------------|--------------|----------------|-----------|-------|
| Unit placement | 0-6 | 12-24 | 0-6 | Snappy and readable | UI owns final animation |
| Adjacent movement | 0-6 | 12-24 | 0-6 | Clear lane-to-lane travel | Must not hide final lane |
| Unit destruction | 0-6 | 12-30 | 0-6 | Clear removal, not noisy | Must preserve board readability |

### Impact Moments

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|-------------|--------------|-------------------|---------------|
| Placement confirm | 100-200 | Slot highlight settles | Yes |
| Lane illegal | 100-200 | Disabled slot pulse/reason | Yes |
| Unit destroyed | 200-400 | Unit exits and lane becomes empty | Yes |

### Weight and Responsiveness Profile

- **Weight**: Medium-light; lane choices matter, but board manipulation should stay quick.
- **Player control**: High; legal lanes must be obvious before committing.
- **Snap quality**: Crisp slot-based movement, not analog dragging as a rules requirement.
- **Acceleration model**: Immediate legality feedback; presentation animation can be brief.
- **Failure texture**: Clear and spatial; invalid placement should point at the occupied slot or invalid lane.

### Feel Acceptance Criteria

- [ ] Players can identify all occupied lanes without opening a log.
- [ ] Players can tell which side owns each unit in a lane.
- [ ] Illegal placement feedback names the lane and reason.
- [ ] Moving a unit never leaves ambiguity about its final lane.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|------------------|-----------|
| Lane names/order | Match board | Static | Always |
| Player life totals | Player status areas | On life change | Always |
| Unit attack/health | Unit card or board badge | On unit change | Unit on board |
| Unit owner | Board side/color/frame | On unit render | Unit on board |
| Ready/exhausted state | Unit affordance | On ready/exhaust change | Unit on board |
| Legal placement lanes | Lane slots | On selected unit card | Unit card selected |
| Illegal placement reason | Slot tooltip/inline hint | On invalid target attempt | Invalid lane target |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|------------|-----------------------------|--------|
| Board state is hashed by core | `design/gdd/deterministic-simulation-core.md` | canonical match state and hash | Data dependency |
| Unit placement reads card data | `design/gdd/card-data-model.md` | card type and prototype unit stats | Data dependency |
| Attack and ready timing use phases | `design/gdd/turn-timing-resource-system.md` | AttackPhase and readiness timing | Rule dependency |
| Response effects may move units | `design/gdd/stack-response-system.md` | response windows before resolution | Rule dependency |
| Effects mutate board | `design/gdd/card-effect-resolution-system.md` | damage, heal, move, destroy | Ownership handoff |
| UI consumes board snapshots | `design/gdd/match-board-ui-input.md` | lane occupancy and legal targets | Data dependency |

## Acceptance Criteria

- [ ] **GIVEN** an empty three-lane board, **WHEN** Player A places a unit in Center, **THEN** Center contains Player A's unit and other lanes remain empty.
- [ ] **GIVEN** Player A already has a unit in Center, **WHEN** Player A tries to place another unit in Center, **THEN** the command is rejected without state mutation.
- [ ] **GIVEN** Player A has a unit in Center, **WHEN** Player B places a unit in Center, **THEN** both units exist in opposing slots in Center.
- [ ] **GIVEN** a unit in Left, **WHEN** a legal adjacent move targets Center and Center is empty for that owner, **THEN** the unit moves to Center with the same instance id.
- [ ] **GIVEN** a unit in Left, **WHEN** movement targets Right without a special rule, **THEN** the move is rejected.
- [ ] **GIVEN** a unit with 2 health, **WHEN** it takes 2 damage, **THEN** it is destroyed and removed from its lane.
- [ ] **GIVEN** the same placement/movement sequence is replayed, **WHEN** replay completes, **THEN** board state hash matches the original run.
- [ ] Performance: legal lane query returns within 50ms in local MVP.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|------------|
| Should player life belong to board state or a later player-state system? | Gameplay Programmer | Before combat damage GDD | Provisional: board/match state owns MVP life totals |
| Should unit stats live directly on card definitions or effect parameters? | Systems Designer | Before Card Effect Resolution GDD | Provisional: MVP card definitions expose prototype unit stats |
| Should units become ready during Start Phase or a dedicated Ready Phase? | Systems Designer | Before attack implementation | Provisional: owner Start Phase |
| Should lane count ever vary by format? | Systems Designer | After MVP | Provisional: fixed 3 lanes |

---

## Lean Review Notes

Specialist review was not run inline. Run `/design-review design/gdd/zone-lane-board-system.md` in a fresh session before approval.
