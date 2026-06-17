# Card Effect Resolution System

> **Status**: Designed
> **Author**: Codex
> **Last Updated**: 2026-06-17
> **Last Verified**: 2026-06-17
> **Implements Pillar**: Rules Clarity Beats Hidden Complexity; Deterministic Trust; Skillful Deck Identity

## Summary

The Card Effect Resolution System interprets validated card `effect_refs` and turns them into deterministic match mutations, events, cancel/fizzle outcomes, and board/resource changes. It is the rules vocabulary that lets card data express behavior without embedding executable script text or untyped dictionaries.

> **Quick reference** - Layer: `Feature` · Priority: `MVP` · Key deps: `Zone and Lane Board System`, `Stack and Response System`

## Overview

Card effects are where a card battler gains identity, but they are also the highest-risk source of replay drift and unreadable interactions. This system defines a small MVP effect language with typed parameter resources, deterministic target checks, stable per-effect ordering, and explicit failure outcomes. It consumes effect references from card data, applies them through the deterministic simulation core, asks the board/timing/stack systems to validate their owned state, and emits structured events that UI, replay, and future authority systems can inspect.

## Player Fantasy

Players should feel that each card does exactly what its text promises, even when responses interrupt the original line. A clever response should visibly cancel, move, protect, damage, or preserve a unit because the rules say so, not because of hidden script behavior. The emotional target is confident mastery: players can learn interactions, predict outcomes, and build decks around reliable effect patterns.

## Detailed Design

### Core Rules

1. Every card effect in MVP resolves from an `EffectRef` listed on a validated `CardDefinition`.
2. `EffectRef.effect_id` selects the effect schema.
3. `EffectRef.params` must be a typed parameter resource compatible with that effect schema.
4. Card data must not embed executable script text.
5. Card effects must not be implemented as raw untyped dictionaries in production runtime code.
6. The deterministic simulation core owns the transition boundary; this system owns effect semantics inside that boundary.
7. Effects resolve only after command timing, resource, stack, and first-pass target validation have accepted the command or stack item.
8. Effects resolve in the order listed by the card definition unless a future effect explicitly changes ordering.
9. MVP effect batches are sequential: effect 1 mutates state before effect 2 checks current state.
10. Each effect must emit a deterministic outcome: `resolved`, `fizzled`, `canceled_original`, `partial`, or `no_effect`.
11. An effect that cannot find a required target fizzles without mutating state.
12. The default multi-target rule is `DEFAULT_MULTI_TARGET_FIZZLE_MODE = all_required_targets`: if any required target is illegal, the whole effect fizzles.
13. Optional targets may be missing only when the effect schema explicitly allows them.
14. Damage, healing, movement, destruction, and original-action cancelation are MVP effect categories.
15. Damage and healing use integers only.
16. Damage reduces current unit health or player life by a non-negative integer amount.
17. Unit health at or below 0 destroys the unit and removes it from the board.
18. Healing cannot raise a unit above `max_health` unless a future effect explicitly increases max health first.
19. Movement may move a unit only to a legal lane slot defined by the Zone and Lane Board System.
20. MVP adjacent movement uses `adjacent_lane_move_valid`; cross-lane movement requires a future explicit effect flag.
21. `cancel_original` may only resolve inside a response window with an original stack item.
22. `cancel_original` marks the original stack item canceled and supplies a reason for replay/UI.
23. A canceled original action does not apply its remaining effects.
24. A response effect resolves before original-action recheck, following `stack_resolution_order`.
25. After response effects resolve, the pending original action must use `original_action_still_legal` before applying original effects.
26. Effects may request resource/focus changes, but timing/resource caps and floors remain owned by the Turn, Timing, and Resource System.
27. Effects may request board mutations, but lane occupancy, movement, damage, healing, and destruction invariants remain owned by the Zone and Lane Board System.
28. Effects may not read UI, scene tree state, wall-clock time, frame delta, global random functions, or network state.
29. Any effect that needs randomness must use a named deterministic random stream owned by match state; no random effects are required for MVP.
30. Every effect result must be serializable in canonical match event order.
31. Production source must not import effect behavior or card data directly from `prototypes/`.

### MVP Effect Schemas

| Effect ID | Params Resource | Required Target | Primary Mutation | Notes |
|-----------|-----------------|-----------------|------------------|-------|
| `deal_damage` | `DamageEffectParams` | unit or player target | Reduce health/life by `amount` | Destroys units at 0 health |
| `heal_unit` | `HealEffectParams` | unit target | Increase current health by `amount` up to max | Does not revive destroyed units |
| `move_unit_adjacent` | `MoveUnitEffectParams` | unit plus destination lane | Move unit if destination is adjacent and empty for owner | Used by movement responses |
| `cancel_original` | `CancelOriginalEffectParams` | pending original stack item | Mark original action canceled | Used by response cards |

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| UnresolvedEffect | Effect ref selected for current stack item | Target validation begins | No mutation yet |
| ValidatingTargets | Effect checks required current targets | Targets valid or invalid | Reads board/player/stack state without mutation |
| ResolvingEffect | Targets valid and effect schema accepted | Mutation succeeds, fizzles, or cancels | Applies one deterministic effect |
| ApplyingBoardMutation | Effect requests damage/heal/move/destroy | Board accepts or rejects mutation | Board invariants decide final board state |
| ApplyingStackMutation | Effect requests original cancel/fizzle | Stack accepts or rejects mutation | Stack records cancel/fizzle outcome |
| EffectResolved | Mutation completed | Next effect starts or batch ends | Emits deterministic event output |
| EffectFizzled | Required target or condition failed | Next effect starts or batch ends | Emits fizzle event without mutation |
| EffectBatchComplete | All effects processed or terminal state reached | Stack/original flow continues | Returns ordered effect outcomes to core |

Valid flow:

```text
UnresolvedEffect -> ValidatingTargets -> ResolvingEffect -> EffectResolved
UnresolvedEffect -> ValidatingTargets -> EffectFizzled
ResolvingEffect -> ApplyingBoardMutation -> EffectResolved
ResolvingEffect -> ApplyingStackMutation -> EffectResolved
EffectResolved -> next UnresolvedEffect
EffectFizzled -> next UnresolvedEffect
last effect -> EffectBatchComplete
```

### Interactions with Other Systems

| System | Data In | Data Out | Ownership Boundary |
|--------|---------|----------|--------------------|
| Deterministic Simulation Core | Stack item, command context, match state | Ordered effect outcomes, events, mutations | Core owns transition boundary; effect system owns effect semantics |
| Card Data Model | `effect_refs`, typed params, card id, target profile | Effect schema validation and runtime effect list | Card data owns definitions; effects interpret definitions |
| Stack and Response System | Pending original item, response item, window state | Cancel/fizzle outcomes, original legality inputs | Stack owns item order/window state; effects can mark item outcomes |
| Zone and Lane Board System | Unit, lane, player-life state | Damage, heal, move, destroy requests | Board owns spatial and unit-state invariants |
| Turn, Timing, and Resource System | Resource/focus state and caps | Resource/focus change requests | Timing/resource owns caps, floors, and affordability |
| Action Log and Replay System | Effect outcome events | Replayable mutation event sequence | Replay persists outputs; effects provide deterministic event data |
| Match Board UI and Input | Effect preview and failure reasons | Legal target explanations and result labels | UI consumes effect metadata; effects never read UI |
| Balance and Content Tooling | Effect schemas and params | Validation reports and card coverage data | Tooling validates data before matches |

## Formulas

### Effect Batch Resolution

The `effect_batch_resolution` formula is defined as:

`effect_batch_resolution = resolve(effect_refs_sorted_by_card_order, current_state)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| effect_refs_sorted_by_card_order | E | array | 0-MAX_EFFECT_REFS_PER_CARD | Effect refs listed on the resolving card in card data order |
| current_state | S | structured data | valid match state | State at the moment this effect batch starts |
| resolve | R(E,S) | function | deterministic ordered outcomes | Applies each effect sequentially, with each mutation visible to later effects |

**Output Range:** ordered list of 0 to `MAX_EFFECT_REFS_PER_CARD` effect outcomes.
**Example:** A card with `deal_damage` then `move_unit_adjacent` first damages the target; if the target is destroyed, the move effect fizzles because the unit is no longer on board.

### Damage Application

The `damage_application` formula is defined as:

`target_health_after_damage = max(0, target_health_before - damage_amount)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| target_health_before | H | int | 0-999 MVP safe range | Current unit health or player life before damage |
| damage_amount | D | int | 0-99 MVP safe range | Non-negative integer damage amount from typed params |
| target_health_after_damage | A | int | 0-999 MVP safe range | Clamped health/life after damage |

**Output Range:** 0 to the prior target health under normal play; if output is 0 for a unit, `unit_destroyed` becomes true.
**Example:** A 2-health unit hit by 3 damage becomes 0 health and is destroyed.

### Heal Application

The `heal_application` formula is defined as:

`target_health_after_heal = min(target_max_health, target_health_before + heal_amount)`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| target_health_before | H | int | 1-999 MVP safe range | Current unit health before healing |
| heal_amount | A | int | 0-99 MVP safe range | Non-negative integer heal amount from typed params |
| target_max_health | M | int | 1-999 MVP safe range | Current max health for the unit |

**Output Range:** current health to max health under normal play.
**Example:** A 2/4 unit healed for 3 becomes 4/4, not 5/4.

### Effect Target Still Legal

The `effect_target_still_legal` formula is defined as:

`effect_target_still_legal = target_exists and target_matches_profile and not target_protected_from_effect`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| target_exists | E | bool | true/false | Current match state still contains the required target |
| target_matches_profile | P | bool | true/false | Current target still satisfies the effect target profile |
| target_protected_from_effect | X | bool | true/false | Active protection/cancel rule blocks this effect category |

**Output Range:** boolean.
**Example:** A response that moves a unit out of a spell's required target profile makes `effect_target_still_legal` false for that original spell.

### Cancel Original Valid

The `cancel_original_valid` formula is defined as:

`cancel_original_valid = response_window_open and original_exists and original_command_type_allowed`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| response_window_open | W | bool | true/false | Stack system currently has an open or resolving response window |
| original_exists | O | bool | true/false | There is a pending original stack item |
| original_command_type_allowed | C | bool | true/false | `CancelOriginalEffectParams.allowed_command_types` is empty or contains the original command type |

**Output Range:** boolean.
**Example:** A counter response with allowed command type `play_unit` can cancel a pending unit placement but cannot cancel a future unrelated command type.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Effect id is unknown | Reject card data at validation time; reject runtime command if somehow reached | Unknown behavior cannot be guessed |
| Params resource is missing for an effect that requires params | Reject card data and block match start | Prevents partial runtime behavior |
| Params resource has negative damage or heal amount | Reject card data | Negative values create ambiguous reverse effects |
| Required target no longer exists | Effect fizzles without mutation and emits a fizzle event | Current state governs resolution |
| Optional target no longer exists | Resolve remaining legal portion only if schema permits optional target behavior | Optional behavior must be explicit |
| Damage exceeds unit health | Clamp health to 0, destroy unit, emit damage then destroyed events | Board display should not preserve negative health |
| Heal targets destroyed unit | Fizzle unless a future revive effect schema explicitly allows it | Healing is not revival |
| Move targets occupied own lane slot | Fizzle movement without mutation | Board owns lane occupancy |
| Move targets occupied enemy lane slot | Allow if own destination slot is empty | Enemy slot is separate from owner's slot |
| Move targets non-adjacent lane | Fizzle unless params explicitly allow non-adjacent movement in a future schema | MVP movement stays readable |
| Cancel original runs outside a response window | Fizzle without mutation and emit invalid-cancel reason | Canceling requires a pending original action |
| Cancel original has disallowed original command type | Fizzle and leave original pending | Counter cards can be scoped |
| Response cancels original and then another effect damages the original target | Resolve later response effects normally if their targets remain legal | Response effect batch still resolves in order |
| Effect batch reaches event safety cap | Halt with deterministic diagnostic result | Prevents runaway effect loops |
| Effect would require floating point math | Reject schema for MVP | Core state forbids floats for deterministic resolution |
| Effect result text differs from card rules text | Runtime resolves effect data; tooling should flag text mismatch later | Card text cannot be authoritative over data |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|----------------------|
| Deterministic Simulation Core | This depends on Deterministic Simulation Core | Effects resolve inside command transition batches and state hashes |
| Card Data Model | This depends on Card Data Model | Reads `effect_refs`, effect ids, typed params, card ids, and target profiles |
| Stack and Response System | This depends on Stack and Response System | Receives stack item order and writes cancel/fizzle outcomes |
| Zone and Lane Board System | This depends on Zone and Lane Board System | Requests damage, heal, move, destroy, and player-life mutations |
| Turn, Timing, and Resource System | This depends on Turn, Timing, and Resource System | Requests resource/focus adjustments and respects caps/floors |
| Action Log and Replay System | Depends on this | Persists ordered effect outcomes and mutation events |
| Match Board UI and Input | Depends on this | Displays previews, resolved outcomes, disabled reasons, cancel/fizzle labels |
| Prototype Card Set and Archetypes | Depends on this | Uses approved effect schemas to author first cards |
| Balance and Content Tooling | Depends on this | Validates effect params and reports schema usage |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `MAX_EFFECT_REFS_PER_CARD` | 3 | 1-6 | Enables richer cards | Keeps card text and resolution easier to inspect |
| `MAX_DAMAGE_AMOUNT_MVP` | 10 | 1-20 | Supports bigger burst/removal | Keeps combat slower and safer |
| `MAX_HEAL_AMOUNT_MVP` | 10 | 1-20 | Supports stronger sustain | Keeps board damage stickier |
| `ALLOW_PARTIAL_MULTI_TARGET_RESOLUTION` | false | false/true | Enables complex multi-target cards | Keeps MVP fizzle rules simple |
| `ALLOW_RANDOM_EFFECTS_MVP` | false | false only for MVP | Not allowed until deterministic RNG is fully tested | Preserves replay confidence |
| `ALLOW_NON_ADJACENT_EFFECT_MOVEMENT_MVP` | false | false/true | Enables dramatic movement effects | Keeps lane movement readable |

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Damage applied | Health/life value changes with readable damage marker | Hit sound later | High |
| Unit destroyed | Unit leaves lane clearly after damage event | Destruction sound later | High |
| Unit healed | Health marker increases without hiding current board state | Heal sound optional | Medium |
| Unit moved | Unit travels from source lane to destination lane | Movement sound optional | Medium |
| Original canceled | Pending original action receives canceled label | Cancel sound optional | High |
| Effect fizzled | Pending/effect item shows fizzle reason in log or label | Soft fizzle sound optional | High |

## Game Feel

### Feel Reference

Effects should feel like crisp rulings that produce visible board changes immediately after the stack decides what resolves. The system should support satisfying card impact without hiding the exact state transition that occurred.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|--------|-----------------------------------|-------------------------|-------|
| Resolve single simple effect | 50ms | 3 frames | Damage, heal, move, or cancel |
| Resolve full MVP effect batch | 100ms | 6 frames | Up to `MAX_EFFECT_REFS_PER_CARD` |
| Query effect preview | 50ms | 3 frames | Non-mutating preview for UI |
| Emit effect result events | 50ms | 3 frames | Before presentation animation |

### Animation Feel Targets

| Animation | Startup Frames | Active Frames | Recovery Frames | Feel Goal | Notes |
|-----------|---------------|--------------|----------------|-----------|-------|
| Damage marker | 0-6 | 12-24 | 0-6 | Clear amount and target | Presentation system owns animation |
| Heal marker | 0-6 | 12-24 | 0-6 | Distinct from damage | Must not obscure health |
| Cancel/fizzle label | 0-6 | 12-24 | 0-6 | Judicial and readable | Must show final ruling |

### Impact Moments

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|-------------|--------------|-------------------|---------------|
| Lethal unit damage | 200-400 | Damage marker then unit removal | Yes |
| Response cancel | 150-300 | Response resolves, original marked canceled | Yes |
| Lane movement | 150-300 | Unit changes lane with clear final position | Yes |

### Weight and Responsiveness Profile

- **Weight**: Medium; effects are the visible payoff of card play.
- **Player control**: High through predictable target and response rules.
- **Snap quality**: Effects should produce categorical outcomes: resolved, fizzled, canceled, or no effect.
- **Acceleration model**: Fast simulation, presentation can add short emphasis after state is known.
- **Failure texture**: Clear and explainable; fizzle/cancel should name the rule cause.

### Feel Acceptance Criteria

- [ ] Players can tell which target an effect changed.
- [ ] Players can tell the difference between canceled, fizzled, and resolved.
- [ ] Damage and destruction never appear out of order.
- [ ] Movement effects leave no ambiguity about final lane.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|------------------|-----------|
| Effect preview | Match board target highlights | On card/action selection | Effect has legal target profile |
| Effect outcome | Action log and board feedback | After effect resolves | Any effect resolves |
| Damage amount | Target marker and log | On damage event | Damage applied |
| Heal amount | Target marker and log | On heal event | Heal applied |
| Destroyed unit | Board lane slot | On destruction event | Unit health reaches 0 |
| Movement source/destination | Board lane highlight | On movement preview and resolution | Movement effect selected/resolved |
| Cancel/fizzle reason | Stack prompt/action log | On cancel/fizzle event | Stack item or effect fails |
| Disabled effect reason | Card tooltip/inline label | On invalid target attempt | Target/effect invalid |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|------------|-----------------------------|--------|
| Effects run inside deterministic transitions | `design/gdd/deterministic-simulation-core.md` | transition batch, state hash, no floats | Architecture boundary |
| Effect refs come from card data | `design/gdd/card-data-model.md` | `effect_refs`, typed params, target profile | Data dependency |
| Stack order decides response before original | `design/gdd/stack-response-system.md` | `stack_resolution_order`, `original_action_still_legal` | Rule dependency |
| Damage/move/heal mutate board | `design/gdd/zone-lane-board-system.md` | unit health, lane occupancy, `unit_destroyed` | State dependency |
| Resource changes respect caps | `design/gdd/turn-timing-resource-system.md` | focus/resource caps and floors | Rule dependency |
| Replays persist effect outcomes | `design/gdd/action-log-replay-system.md` | ordered mutation and event log | Persistence dependency |

## Acceptance Criteria

- [ ] **GIVEN** a card with a known effect id and compatible typed params, **WHEN** its effect batch resolves, **THEN** each effect resolves in card data order.
- [ ] **GIVEN** a card with an unknown effect id, **WHEN** card data validation runs, **THEN** match start is blocked with the missing effect id named.
- [ ] **GIVEN** a damage effect targeting a 2-health unit, **WHEN** it deals 2 damage, **THEN** the unit is destroyed and removed from its lane.
- [ ] **GIVEN** a damage effect targeting a 2-health unit, **WHEN** it deals 3 damage, **THEN** the unit health is clamped to 0 and the unit is destroyed.
- [ ] **GIVEN** a heal effect targeting a 2/4 unit, **WHEN** it heals 3, **THEN** the unit becomes 4/4.
- [ ] **GIVEN** a move effect targeting a unit in Left, **WHEN** it moves to Center and the owner's Center slot is empty, **THEN** the same unit instance id moves to Center.
- [ ] **GIVEN** a move effect targeting a unit in Left, **WHEN** it tries to move to Right without non-adjacent permission, **THEN** the effect fizzles without mutation.
- [ ] **GIVEN** a response card with `cancel_original`, **WHEN** it resolves against an allowed pending original command, **THEN** the original stack item is marked canceled and does not mutate state.
- [ ] **GIVEN** a response moves or destroys the original action's required target, **WHEN** the original rechecks legality, **THEN** the original fizzles under `original_action_still_legal`.
- [ ] **GIVEN** an effect with a required missing target, **WHEN** it resolves, **THEN** it emits a fizzle outcome and match state hash changes only if earlier effects in the same batch mutated state.
- [ ] **GIVEN** identical setup and command sequence, **WHEN** effect resolution is replayed, **THEN** effect outcomes, event order, and final state hash match.
- [ ] Performance: a full MVP effect batch resolves within 100ms in local MVP before presentation animation.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|------------|
| Should player damage/life mutation stay in board state or move to a dedicated player-state system? | Gameplay Programmer | Before direct-damage implementation | Provisional: board/match state owns MVP life totals |
| Should temporary buffs be represented as effects, statuses, or derived turn modifiers? | Systems Designer | Before Prototype Card Set GDD | Pending status/buff design |
| Should `cancel_original` target by command type, card type, effect category, or tags? | Systems Designer | Before first response card batch | Provisional: command type allowlist in typed params |
| Should partial multi-target resolution remain disabled beyond MVP? | Systems Designer | After first effect-heavy playtest | Provisional: disabled for MVP |
| What exact event object schema should replace string events? | Gameplay Programmer / QA Lead | Before Action Log and Replay GDD | Pending replay design |

---

## Lean Review Notes

Specialist review was not run inline because `production/review-mode.txt` is set to `lean` and no subagent spawn was explicitly requested. Run `/design-review design/gdd/card-effect-resolution-system.md` in a fresh session before approval.
