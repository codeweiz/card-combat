# Turn, Timing, and Resource System

> **Status**: Designed
> **Author**: Codex
> **Last Updated**: 2026-06-17
> **Last Verified**: 2026-06-17
> **Implements Pillar**: Rules Clarity Beats Hidden Complexity; Deterministic Trust

## Summary

The Turn, Timing, and Resource System defines match phases, active-player flow, command windows, main resources, and response `focus`. It resolves the first paper prototype's biggest ambiguity by separating proactive turn spending from reactive response spending.

> **Quick reference** — Layer: `Core` · Priority: `MVP` · Key deps: `Deterministic Simulation Core`, `Card Data Model`

## Overview

Card Combat needs a turn structure that is readable enough for cross-platform play while still leaving room for response timing. This system defines when players may act, what type of card speed is legal, how main resources grow and refresh, and how the non-active player can spend a small dedicated `focus` pool on response cards. The design goal is to create interaction tension without requiring players to remember hidden leftover resource from a previous turn.

## Player Fantasy

Players should feel like duelists managing tempo and restraint. On their own turn, they build pressure with main resources. On the opponent's turn, they keep a limited amount of `focus` for clutch interruptions. The fantasy is not "react to everything"; it is "pick the one response window that matters."

## Detailed Design

### Core Rules

1. A match alternates turns between exactly two players for MVP local play.
2. Each turn belongs to one active player.
3. The non-active player is the defending player for that turn.
4. A turn is divided into ordered phases:
   - Start Phase
   - Draw Phase
   - Main Phase
   - Attack Phase
   - End Phase
5. Phases always resolve in the same order.
6. The active player may submit main-speed commands only during Main Phase unless a later GDD grants an exception.
7. The active player may declare attacks only during Attack Phase.
8. Response windows may open during Main Phase or Attack Phase after eligible actions.
9. The defending player may submit response-speed commands only while a response window is open.
10. Each response window allows at most one defending-player response in MVP.
11. The response window closes immediately after the defending player responds or passes.
12. Main-speed cards cannot be played as responses.
13. Response-speed cards cannot be played as proactive main actions unless a card explicitly gains a future hybrid rule.
14. Each player has `main_resource` and `max_main_resource`.
15. Each player has `focus` and `max_focus`.
16. Main resource pays for main-speed cards and proactive actions.
17. Focus pays for response-speed cards.
18. Main resource and focus never pay for each other's cards in MVP.
19. At the active player's Start Phase, that player's `max_main_resource` increases by `MAIN_RESOURCE_GAIN_PER_TURN`, up to `MAIN_RESOURCE_CAP`.
20. At the active player's Start Phase, that player's `main_resource` refreshes to `max_main_resource`.
21. At the active player's Start Phase, that player's `focus` resets to 0.
22. At the defending player's first response window each opponent turn, their `focus` refreshes to `RESPONSE_FOCUS_PER_OPPONENT_TURN`.
23. The defending player's focus persists across response windows during the same opponent turn until spent or until that player becomes active.
24. If the defending player spends all focus, they cannot respond again that opponent turn unless another system explicitly grants focus.
25. The active player does not receive focus during their own turn.
26. Affordability is checked before timing legality resolves the command.
27. A command that fails phase, speed, resource, or focus checks is rejected without mutating match state.
28. Every phase transition, response-window open/close, and resource refresh must be recorded as deterministic events or derivable from deterministic state.

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| StartPhase | Turn begins | Resource refresh completes | Refresh active player's main resource, reset active focus |
| DrawPhase | StartPhase complete | Draw command or automatic draw resolves | Active player draws by future deck rules |
| MainPhase | DrawPhase complete | Active player passes or uses allowed main action budget | Main-speed commands legal for active player |
| ResponseWindow | Eligible action opens response timing | Defender responds or passes | One response-speed command legal for defender |
| AttackPhase | MainPhase complete | All attacks declared/resolved or active player passes attacks | Attack declarations legal |
| EndPhase | AttackPhase complete | Cleanup resolves | Temporary effects expire and turn advances |
| TurnComplete | EndPhase complete | Next player StartPhase begins | Active/defender roles swap |

Valid phase flow:

```text
StartPhase -> DrawPhase -> MainPhase -> AttackPhase -> EndPhase -> TurnComplete
MainPhase -> ResponseWindow -> MainPhase
AttackPhase -> ResponseWindow -> AttackPhase
TurnComplete -> next player's StartPhase
```

### Interactions with Other Systems

| System | Data In | Data Out | Ownership Boundary |
|--------|---------|----------|--------------------|
| Deterministic Simulation Core | Command submission, player ids, current match state | Phase changes, resource changes, rejection reasons | Core applies transitions; timing system defines legality |
| Card Data Model | `speed`, `base_cost`, card type | Affordability and timing interpretation | Card data owns static values; this system owns spending rules |
| Stack and Response System | Response window state | Window open/close and response eligibility | This system opens/closes windows; stack system resolves response contents |
| Zone and Lane Board System | Attack-ready units and lane state | Attack phase legality | Board owns attackable entities; timing owns when attacks can happen |
| Card Effect Resolution System | Effect-triggered resource changes | Updated resource/focus values | Effects request changes; this system validates caps and floors |
| Match Board UI and Input | Current phase, active player, legal speeds, resource/focus values | UI affordances and disabled reasons | UI displays state; this system owns legality |
| Action Log and Replay System | Phase/resource events | Replayable event sequence | Replay records outputs; this system must be deterministic |

## Formulas

### Main Resource Refresh

The `main_resource_refresh` formula is defined as:

`max_main_resource_after = min(max_main_resource_before + MAIN_RESOURCE_GAIN_PER_TURN, MAIN_RESOURCE_CAP)`

`main_resource_after = max_main_resource_after`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| max_main_resource_before | M | int | 0-10 | Player's resource cap before refresh |
| MAIN_RESOURCE_GAIN_PER_TURN | G | int | 1 | Amount max resource increases each active turn |
| MAIN_RESOURCE_CAP | C | int | 10 | MVP resource cap |
| max_main_resource_after | A | int | 1-10 | Player's resource cap after refresh |
| main_resource_after | R | int | 1-10 | Current spendable main resource after refresh |

**Output Range:** 1 to 10 for normal play.
**Example:** If a player starts turn with max resource 3, refresh sets max and current main resource to 4.

### Focus Refresh

The `focus_refresh` formula is defined as:

`focus = RESPONSE_FOCUS_PER_OPPONENT_TURN`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| RESPONSE_FOCUS_PER_OPPONENT_TURN | F | int | 1-3 | Focus granted to the defending player during the opponent's turn |

**Output Range:** 1 to 3; MVP starting value is 2.
**Example:** When Player B receives their first response window during Player A's turn, Player B focus becomes 2.

### Command Timing Valid

The `command_timing_valid` formula is defined as:

`command_timing_valid = phase_allows_speed and actor_has_priority and resource_pool_can_pay`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| phase_allows_speed | P | bool | true/false | Current phase/window allows the command speed |
| actor_has_priority | A | bool | true/false | Actor is active player or defending player with response priority |
| resource_pool_can_pay | R | bool | true/false | Main resource or focus can pay the command cost |

**Output Range:** boolean.
**Example:** A response card in a response window is valid only if the defender has priority and enough focus.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Active player tries response-speed card during Main Phase | Reject command without mutation | MVP separates proactive and reactive play |
| Defender tries main-speed card during ResponseWindow | Reject command without mutation | Prevents hidden off-turn main actions |
| Defender has 0 focus and tries response card | Reject command with `insufficient_focus` | Response limits must be visible |
| Defender receives multiple response windows in one opponent turn | Focus is not refreshed again after the first window | Prevents unlimited response chains |
| Defender never receives a response window during opponent turn | Focus remains unchanged until their own Start Phase resets it to 0 | Focus only matters when response windows exist |
| Active player ends Main Phase with unspent main resource | Unspent main resource remains until their next Start Phase but cannot pay response cards | Keeps resource state deterministic without using it for responses |
| Effect grants focus above cap | Clamp to `MAX_FOCUS` | Avoids unbounded response hoarding |
| Effect reduces main resource below 0 | Clamp to 0 | Prevents negative resource exploits |
| Both players appear to have priority | Enter deterministic invariant failure | Exactly one priority owner is allowed |
| Turn reaches phase loop safety cap | Halt with diagnostic event | Prevents infinite phase loops |
| Match ends during Main Phase or Attack Phase | Skip remaining phases and enter Complete state | Outcome should resolve immediately |
| Player disconnects in future online mode | Out of MVP scope; match authority ADR must define timeout behavior | Timing system does not own networking |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|----------------------|
| Deterministic Simulation Core | This depends on Deterministic Simulation Core | Needs command validation, state mutation, event emission, and hashes |
| Card Data Model | This depends on Card Data Model | Reads `speed`, `base_cost`, and card type |
| Stack and Response System | Stack depends on this | Uses response-window ownership and timing |
| Zone and Lane Board System | Depends on this | Uses AttackPhase and attack declaration timing |
| Card Effect Resolution System | Depends on this | Requests resource/focus changes and reads phase legality |
| Action Log and Replay System | Depends on this | Records phase transitions, resource changes, and rejected timing commands |
| Match Board UI and Input | Depends on this | Displays phase, resource, focus, legal speeds, and disabled reasons |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `STARTING_MAX_MAIN_RESOURCE` | 0 | 0-2 | Faster early game | Slower first turns |
| `MAIN_RESOURCE_GAIN_PER_TURN` | 1 | 1-2 | Faster curve and shorter matches | Slower curve, more setup turns |
| `MAIN_RESOURCE_CAP` | 10 | 6-12 | Allows bigger finishers | Keeps card costs compact |
| `RESPONSE_FOCUS_PER_OPPONENT_TURN` | 2 | 1-3 | More response flexibility | More commitment and fewer interruptions |
| `MAX_FOCUS` | 2 | 1-4 | Enables future focus-grant cards | Keeps response windows simple |
| `MAX_RESPONSES_PER_WINDOW_MVP` | 1 | 1 only for MVP | Not tunable until chain prototype | Keeps readability high |

MVP risk decision: `RESPONSE_FOCUS_PER_OPPONENT_TURN = 2` is accepted as the
first playable starting value. This replaces the earlier requirement to run a
second paper prototype before implementation. The value must be retested in the
first Godot playable and revised if playtesters describe focus as hidden
leftover mana, if response windows feel automatic rather than decisive, or if
the defender routinely answers every meaningful action.

## Visual/Audio Requirements

This system needs clear UI feedback but does not own art assets directly.

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Phase changes | Phase label/timeline updates | Subtle tick optional | High |
| Main resource refresh | Resource counter fills | Soft resource sound optional | Medium |
| Focus available | Response affordance lights up | Subtle alert optional | High |
| Response window opens | Opponent response prompt and timer/focus display | Prompt sound optional | High |
| Command rejected | Disabled reason near card/action | Soft error sound optional | High |

## Game Feel

### Feel Reference

The turn should feel like a crisp digital card duel: clear active turns, sharp response prompts, and no ambiguity about who may act. The response `focus` moment should feel like a limited counterplay opportunity, not like a second full turn.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|--------|-----------------------------------|-------------------------|-------|
| Phase transition display update | 100ms | 6 frames | After pure simulation event |
| Legal timing query | 50ms | 3 frames | Used when selecting cards |
| Response window prompt | 100ms | 6 frames | Must feel immediate |
| Rejection reason | 50ms | 3 frames | Required for rules clarity |

### Animation Feel Targets

| Animation | Startup Frames | Active Frames | Recovery Frames | Feel Goal | Notes |
|-----------|---------------|--------------|----------------|-----------|-------|
| Phase banner update | 0-6 | 12-30 | 0-6 | Snappy, not theatrical | Presentation system owns final animation |
| Focus prompt pulse | 0-6 | Until pass/respond | 0-6 | Noticeable but not obstructive | Must work on mobile |

### Impact Moments

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|-------------|--------------|-------------------|---------------|
| Response window opens | 100-300 | Prompt highlight and focus counter emphasis | Yes |
| Resource refresh | 100-200 | Counter fill/update | Yes |
| Command rejected | 100-200 | Error affordance and reason | Yes |

### Weight and Responsiveness Profile

- **Weight**: Light and readable; phase changes should not slow the match.
- **Player control**: High during own turn; constrained but meaningful during response windows.
- **Snap quality**: Crisp and categorical; the UI must show whether a card is main-speed or response-speed.
- **Acceleration model**: Immediate phase and legality response.
- **Failure texture**: Explanatory, not punitive; rejected actions explain phase, speed, priority, or resource reason.

### Feel Acceptance Criteria

- [ ] Players can tell whose turn it is without reading a log.
- [ ] Players can tell when they have response priority.
- [ ] Players can tell why a card is not playable.
- [ ] No playtester describes response resource as "hidden leftover mana" after the focus iteration.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|------------------|-----------|
| Active player | Match board header | Every phase/turn change | Always |
| Current phase | Match board header or timeline | Every phase change | Always |
| Main resource | Player resource display | On refresh/spend/change | Always |
| Focus | Defending player response display | During opponent turn and response windows | When focus relevant |
| Response window status | Board overlay/prompt | On window open/close | During response opportunities |
| Disabled reason | Card/action tooltip or inline label | On attempted invalid action | Invalid command |
| Legal speed indicator | Card frame/badge | On card render | Always |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|------------|-----------------------------|--------|
| Commands are validated by core | `design/gdd/deterministic-simulation-core.md` | command rejection and mutation rules | Rule dependency |
| Card speed and cost come from data | `design/gdd/card-data-model.md` | `speed`, `base_cost` | Data dependency |
| Response windows feed stack rules | `design/gdd/stack-response-system.md` | response priority and window count | Rule dependency |
| Attack timing feeds lane board | `design/gdd/zone-lane-board-system.md` | AttackPhase and attack declaration | State trigger |
| UI displays phase/resource/focus | `design/gdd/match-board-ui-input.md` | timing and resource state | Data dependency |

## Acceptance Criteria

- [ ] **GIVEN** a new match, **WHEN** Player A's first Start Phase begins, **THEN** Player A main resource refreshes according to `main_resource_refresh`.
- [ ] **GIVEN** a player is in Main Phase with enough main resource, **WHEN** they submit a main-speed command, **THEN** timing validation may pass if other legality rules pass.
- [ ] **GIVEN** a player is in Main Phase, **WHEN** they submit a response-speed command, **THEN** the command is rejected without state mutation.
- [ ] **GIVEN** a response window is open and defender has enough focus, **WHEN** defender submits a response-speed command, **THEN** focus is spent and the window resolves.
- [ ] **GIVEN** a response window is open and defender has 0 focus, **WHEN** defender submits a response-speed command, **THEN** the command is rejected with `insufficient_focus`.
- [ ] **GIVEN** two response windows occur during one opponent turn, **WHEN** the second window opens, **THEN** focus does not refresh a second time.
- [ ] **GIVEN** a player becomes active, **WHEN** Start Phase begins, **THEN** that player's focus resets to 0.
- [ ] **GIVEN** a rejected timing command, **WHEN** state hash is compared before and after, **THEN** the hash is unchanged.
- [ ] **GIVEN** the same phase/action sequence is replayed, **WHEN** replay completes, **THEN** phase history and resource values match the original run.
- [ ] Performance: legal timing/resource query returns within 50ms in local MVP.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|------------|
| Should focus refresh at first response window or at opponent Start Phase? | Systems Designer | Before implementation beyond skeleton | Provisional: first response window |
| Should active player ever receive response priority in MVP? | Systems Designer | Before Stack and Response GDD | Provisional: no |
| Should turn timer exist in MVP local prototype? | UX Designer / Systems Designer | Before Match Board UI GDD | Pending UX design |

---

## Lean Review Notes

Specialist review was not run inline. Run `/design-review design/gdd/turn-timing-resource-system.md` in a fresh session before approval.
