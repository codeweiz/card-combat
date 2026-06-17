# Prototype Card Set and Archetypes

> **Status**: Designed
> **Author**: Codex
> **Last Updated**: 2026-06-17
> **Last Verified**: 2026-06-17
> **Implements Pillar**: Skillful Deck Identity; Rules Clarity Beats Hidden Complexity; Deterministic Trust

## Summary

Prototype Card Set and Archetypes defines the MVP test card pool, the two first
archetype directions, and the readiness gate that decides whether a card can
move from paper prototype into Godot data. It converts the 12-card
`Lane-stack Duel` seed into production-facing card specifications without
claiming final balance, final names, final art, or full implementation parity.

> **Quick reference** - Layer: `Feature` - Priority: `MVP` - Key deps: `Card Data Model`, `Deck Construction and Validation`

## Overview

This system supplies small, inspectable card content for the first playable
local duel. It is not the full collection system, not a release set, and not a
live balance environment. Its job is to prove that three-lane pressure and
one-card response windows can create readable deck identity using data-driven
cards that pass the Card Data Model, Deck Construction and Validation, Stack and
Response, and Card Effect Resolution contracts.

The paper prototype produced a useful 12-card seed, but that seed mixes effects
that are already covered by MVP schemas with effects that still need status or
temporary-modifier rules. This GDD therefore tracks every seed card by
implementation tier before any card is treated as legal production data.

## Player Fantasy

Players should feel that even a tiny prototype deck has a plan. A lane-pressure
player should feel rewarded for spreading threats and forcing awkward blocks. A
reactive-control player should feel rewarded for saving focus and answering the
one action that matters. Both decks should remain readable enough that a loss
points to a better card choice, timing decision, or lane commitment rather than
to hidden rules.

## Detailed Design

### Core Rules

1. MVP prototype card content must be authored as `CardDefinition` data before
   it enters local match setup.
2. Production source must not import card data, deck lists, or effect behavior
   directly from `prototypes/`.
3. Prototype cards use `status = prototype` until art, balance, text, and review
   gates promote them to `active`.
4. The MVP card pool target is `MVP_CARD_POOL_TARGET = 24` valid cards.
5. The initial seed is the 12 cards from
   `prototypes/lane-stack-duel-concept/rules.md`.
6. The 12 seed cards are evidence, not final content. Their names and numbers
   may change before promotion.
7. A card is implementation-ready only when:
   - its `CardDefinition` validates,
   - its target profile exists,
   - every `effect_ref` uses an approved typed effect schema,
   - its effect behavior is implemented in deterministic runtime code, and
   - it can appear in at least one legal `mvp_local` sample deck.
8. Cards that require unsupported effect categories remain in `schema_ready` until
   runtime is implemented for that behavior.
9. No `design_only` card is allowed in first-playable `mvp_local` sample decks.
9. The MVP prototype set must support at least `MVP_ARCHETYPE_TARGET = 2`
   archetype directions.
10. The first archetypes are `lane_pressure` and `response_control`.
11. Every prototype card must declare at least one archetype tag, one role tag,
    and one implementation tier tag.
12. Archetype tags are deckbuilding and tooling labels; they do not execute
    rules behavior.
13. A legal sample deck may include cards from both archetypes, but its declared
    archetype must describe its primary game plan.
14. A card may bridge archetypes only when its role is useful in both plans and
    does not become generically mandatory.
15. Prototype decks use the `mvp_local` format.
16. Prototype decks must obey `MVP_LOCAL_DECK_SIZE`,
    `MVP_MAX_COPIES_PER_CARD`, `MVP_MIN_UNIQUE_CARDS`,
    `MVP_MIN_UNIT_CARDS`, `MVP_MIN_RESPONSE_CARDS`, and
    `MVP_MAX_RESPONSE_CARDS`.
17. Prototype cards must be balanced around the dedicated response `focus`
    model, not the paper prototype's carried-over main resource model.
18. Response-speed cards must spend `focus` and may be played only in response
    windows.
19. Main-speed spells must not be playable as responses.
20. The first playable prototype should prefer simple cards over novel mechanics
    until deterministic effect, replay, and UI explanation paths are proven.
21. A card that disagrees with current effect schemas should be redesigned or
    held out of the playable set rather than forcing ad hoc runtime code.
22. Direct player damage is allowed only through the approved `deal_damage`
    effect path and target profiles.
23. Temporary attack, temporary health, shielding, and movement prevention are
    not implementation-ready until a status/modifier design exists.
24. `Counter Sigil` is the prototype example for the approved `cancel_original`
    behavior.
25. First playable set target remains `MVP_CARD_POOL_TARGET = 24`; `SchemaReady`
    cards without runtime may remain in deck design but must be explicitly
    blocked from loading until implementation is complete.

### Card Specification Shape

Prototype content uses this production-facing authoring shape:

```text
PrototypeCardSpec
  card_id: StringName
  name_key: StringName
  rules_text_key: StringName
  card_type: unit | spell | response
  speed: main | response
  base_cost: int
  unit_attack: int optional
  unit_health: int optional
  targeting_profile_id: StringName
  effect_refs: Array[EffectRef]
  tags: Array[StringName]
  status: prototype
  implementation_tier: runtime_skeleton | schema_ready | design_only
  source_evidence: prototype file or GDD
```

Implementation tier meanings:

| Tier | Meaning | Playable in Godot MVP data? |
|------|---------|-----------------------------|
| `runtime_skeleton` | Current code has a partial deterministic path for this category | Yes for smoke scope only |
| `schema_ready` | GDD and typed params describe the effect, but runtime mutation may still need implementation | Not until runtime is complete |
| `design_only` | The card needs a missing effect/status schema | No |

### Seed Card Set

| Seed ID | Proposed `card_id` | Card | Type | Cost | Speed | Effect / Stats | Archetype Tags | Implementation Tier |
|---------|--------------------|------|------|------|-------|----------------|----------------|---------------------|
| C01 | `vanguard` | Vanguard | Unit | 1 | Main | 2 attack / 2 health; play into an empty lane | `lane_pressure`, `curve_unit` | `runtime_skeleton` |
| C02 | `sentinel` | Sentinel | Unit | 2 | Main | 1 attack / 4 health; play into an empty lane | `response_control`, `blocker_unit` | `runtime_skeleton` |
| C03 | `duelist` | Duelist | Unit | 2 | Main | 3 attack / 1 health; play into an empty lane | `lane_pressure`, `threat_unit` | `runtime_skeleton` |
| C04 | `breaker` | Breaker | Unit | 3 | Main | 3 attack / 3 health; play into an empty lane | `lane_pressure`, `finisher_unit` | `runtime_skeleton` |
| C05 | `spark_shot` | Spark Shot | Spell | 1 | Main | `deal_damage(amount: 2)` to a unit | `response_control`, `removal` | `schema_ready` |
| C06 | `direct_bolt` | Direct Bolt | Spell | 2 | Main | `deal_damage(amount: 3)` to enemy player | `burn_tempo`, `reach` | `schema_ready` |
| C07 | `guard_flash` | Guard Flash | Response | 1 | Response | `cancel_original` for a targeted spell before it resolves | `response_control`, `counter` | `schema_ready` |
| C08 | `counter_sigil` | Counter Sigil | Response | 2 | Response | `cancel_original` for a targeted spell; current runtime only proves generic cancel path | `response_control`, `counter` | `schema_ready` |
| C09 | `sidestep` | Sidestep | Response | 1 | Response | `move_unit_adjacent` for a friendly unit before an attack resolves | `lane_pressure`, `protection` | `schema_ready` |
| C10 | `challenge` | Challenge | Spell | 1 | Main | `move_unit_adjacent` for an enemy unit on its side | `lane_pressure`, `displacement` | `schema_ready` |
| C11 | `rally_mark` | Rally Mark | Spell | 1 | Main | `deal_damage(amount: 1)` to an enemy unit | `lane_pressure`, `removal` | `schema_ready` |
| C12 | `anchor_ward` | Anchor Ward | Response | 1 | Response | `cancel_original` for a pending enemy action that would move a unit | `response_control`, `counter` | `schema_ready` |
| C13 | `lancer` | Lancer | Unit | 2 | Main | 2 attack / 2 health; play into an empty lane | `lane_pressure`, `curve_unit` | `runtime_skeleton` |
| C14 | `bulwark_stone` | Bulwark Stone | Unit | 2 | Main | 1 attack / 4 health; play into an empty lane | `response_control`, `blocker_unit` | `runtime_skeleton` |
| C15 | `assault_runner` | Assault Runner | Unit | 3 | Main | 3 attack / 2 health; play into an empty lane | `lane_pressure`, `finisher_unit` | `runtime_skeleton` |
| C16 | `flank_probe` | Flank Probe | Spell | 1 | Main | `move_unit_adjacent` for a friendly unit before it attacks | `lane_pressure`, `displacement` | `schema_ready` |
| C17 | `pin_bolt` | Pin Bolt | Spell | 2 | Main | `deal_damage(amount: 1)` to an enemy unit | `lane_pressure`, `removal` | `schema_ready` |
| C18 | `iron_bulwark` | Iron Bulwark | Unit | 3 | Main | 2 attack / 3 health; play into an empty lane | `response_control`, `blocker_unit` | `runtime_skeleton` |
| C19 | `counter_sigil_2` | Counter Sigil II | Response | 1 | Response | `cancel_original` for a pending enemy action that changes board state | `response_control`, `counter` | `runtime_skeleton` |
| C20 | `focus_bolt` | Focus Bolt | Response | 2 | Response | `cancel_original` for a targeted unit action in response | `response_control`, `counter` | `runtime_skeleton` |
| C21 | `grip_lock` | Grip Lock | Response | 1 | Response | `cancel_original` for a targeted enemy spell | `response_control`, `counter` | `runtime_skeleton` |
| C22 | `bridgeshot` | Bridge Shot | Response | 1 | Response | `move_unit_adjacent` for a friendly unit before a response window ends | `neutral`, `tempo` | `schema_ready` |
| C23 | `burn_burst` | Burn Burst | Spell | 1 | Main | `deal_damage(amount: 1)` to enemy player life | `neutral`, `reach` | `schema_ready` |
| C24 | `warded_charge` | Warded Charge | Spell | 2 | Main | `move_unit_adjacent` for a friendly unit into a pressured lane | `neutral`, `bridge` | `schema_ready` |

### Archetype Directions

| Archetype | Primary Fantasy | Core Decisions | Seed Cards | Needs Before First Playable |
|-----------|-----------------|----------------|------------|-----------------------------|
| `lane_pressure` | Build threats across lanes and force the opponent to answer the wrong lane | Where to place units, when to move blockers, whether to spend main action on pressure or displacement | Vanguard, Duelist, Breaker, Lancer, Assault Runner, Flank Probe, Sidestep, Pin Bolt | Implement attack flow and movement effect coverage |
| `response_control` | Hold focus for the decisive response and preserve enough board state to stabilize | Which action to counter, which unit to protect, when passing is stronger than spending focus | Sentinel, Spark Shot, Guard Flash, Counter Sigil, Counter Sigil II, Bulwark Stone, Direct Bolt | Implement response scope, player damage, and cancel path completeness |

`burn_tempo` is a support tag for direct damage and low-cost removal. It is not a
full MVP archetype until it has enough cards to produce a legal deck without
crowding out lane play.

### Expansion Requirements To 24 Cards

The 12 seed cards are enough to test the shape of two deck plans, but the MVP
pool target remains 24 valid cards so deck identity is not overly repetitive.
The next 12 card slots should be authored under these requirements:

| Slot Group | Count | Required Purpose | Constraints |
|------------|-------|------------------|-------------|
| Lane-pressure units | 3 | Add low and mid-cost lane commitments | Must keep 3-lane occupancy readable |
| Lane-pressure actions | 2 | Add movement or attack-pressure decisions | Must use approved movement/damage schemas or wait |
| Response-control units | 2 | Add blockers or value units that make protection meaningful | Must not create board stalls by themselves |
| Response-control responses | 3 | Add cancel, protection, or fizzle tools | Must spend focus and stay within one-response window |
| Neutral bridge cards | 2 | Help both sample decks reach legal counts | Must not become automatic 2-of cards in every deck |

### Sample Deck Profiles

These profiles are design targets for deck validation. They are not runnable
until every listed card is implementation-ready.

| Profile | Card Counts | Rules Check |
|---------|-------------|-------------|
| `lane_pressure_sample` | 2x Vanguard, 2x Duelist, 2x Breaker, 2x Lancer, 2x Assault Runner, 2x Pin Bolt, 2x Flank Probe, 2x Spark Shot, 2x Sidestep, 2x Counter Sigil | 20 cards, 10 unique, 10 units, 2 responses |
| `response_control_sample` | 2x Sentinel, 2x Bulwark Stone, 2x Vanguard, 2x Breaker, 2x Spark Shot, 2x Direct Bolt, 2x Counter Sigil, 2x Counter Sigil II, 2x Focus Bolt, 2x Sidestep | 20 cards, 10 unique, 8 units, 4 responses |

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| PaperSeed | Card exists only in prototype documents | Converted to `PrototypeCardSpec` | Useful for learning, not loadable by production |
| SpecDraft | Card has a proposed `card_id`, tags, and effect intent | Schema validation begins | May still contain unsupported effects |
| SchemaReady | All effect refs use approved schemas | Runtime behavior implemented or card deferred | Can enter implementation backlog |
| RuntimeReady | Deterministic code resolves the card behavior | Deck validation includes it in sample decks | Can be included in local test data |
| PlaytestEnabled | Card is in `mvp_local` prototype data | Playtest verdict changes status | Legal for local MVP only |
| DisabledPrototype | Card failed clarity, balance, or implementation checks | Redesigned and revalidated | Not legal for new decks |
| PromotedActive | Card passes production content review | Deprecated or rebalanced by future process | Future non-prototype formats may include it |

Valid flow:

```text
PaperSeed -> SpecDraft -> SchemaReady -> RuntimeReady -> PlaytestEnabled
SpecDraft -> DisabledPrototype
SchemaReady -> DisabledPrototype
PlaytestEnabled -> DisabledPrototype
PlaytestEnabled -> PromotedActive
```

### Interactions with Other Systems

| System | Data In | Data Out | Ownership Boundary |
|--------|---------|----------|--------------------|
| Card Data Model | Prototype card specs, tags, status, effect refs | Valid or invalid card definitions | Card data owns schema; this system owns content intent |
| Deck Construction and Validation | Card ids, statuses, tags, sample deck lists | Legal sample deck verdicts | Deck validation owns hard format rules |
| Turn, Timing, and Resource System | Costs, speed, response focus assumptions | Main/resource and focus affordability needs | Timing owns payment and speed legality |
| Stack and Response System | Response-speed cards and cancel/protection intent | Response-window coverage needs | Stack owns window order and one-response cap |
| Card Effect Resolution System | Required effect categories and params | Runtime readiness gaps | Effects own deterministic mutations |
| Zone and Lane Board System | Unit stats, lanes, movement needs | Lane pressure and blocking behavior | Board owns occupancy, attack, movement, and life state |
| Action Log and Replay System | Sample deck ids, card data hash, effect outcomes | Replay coverage for seed cards | Replay owns persistence and mismatch reporting |
| Local Match Flow | Playtest-enabled cards and validated decks | Selectable local match loadouts | Match flow owns start/end loop |
| Balance and Content Tooling | Archetype tags, roles, costs, usage | Coverage and balance reports later | Tooling analyzes, this GDD defines MVP intent |

## Formulas

### Prototype Card Pool Ready

The `prototype_card_pool_ready` formula is defined as:

`prototype_card_pool_ready = valid_mvp_cards >= MVP_CARD_POOL_TARGET and archetype_count >= MVP_ARCHETYPE_TARGET and sample_deck_pair_ready`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| valid_mvp_cards | C | int | 0-200 | Count of active/prototype cards that pass card data validation for `mvp_local` |
| MVP_CARD_POOL_TARGET | T | int | 24 | Target card count for first playable prototype |
| archetype_count | A | int | 0-10 | Count of archetype directions with enough tagged cards for a sample deck |
| MVP_ARCHETYPE_TARGET | R | int | 2 | Required first playable archetype count |
| sample_deck_pair_ready | D | bool | true/false | Both sample deck profiles are legal under current data and runtime support |

**Output Range:** boolean.
**Example:** A pool with 24 valid cards, 2 archetypes, and legal lane/control
sample decks is ready. A 12-card seed with design-only cards is not ready.

### Archetype Card Coverage

The `archetype_card_coverage` formula is defined as:

`archetype_card_coverage = archetype_tagged_cards / MVP_ARCHETYPE_CARD_TARGET`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| archetype_tagged_cards | C | int | 0-200 | Valid cards tagged for the archetype being evaluated |
| MVP_ARCHETYPE_CARD_TARGET | T | int | 12 | Target tagged-card count per MVP archetype |

**Output Range:** 0.0 to 1.0+; 1.0 means the archetype has enough tagged card
coverage for MVP testing.
**Example:** `lane_pressure` with 8 valid tagged cards has coverage `8 / 12 =
0.67`.

### Implementation Readiness Ratio

The `implementation_readiness_ratio` formula is defined as:

`implementation_readiness_ratio = implementation_ready_cards / MVP_CARD_POOL_TARGET`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| implementation_ready_cards | R | int | 0-200 | Count of cards with validated data and deterministic runtime behavior |
| MVP_CARD_POOL_TARGET | T | int | 24 | Target card count for first playable prototype |

**Output Range:** 0.0 to 1.0+.
**Example:** If 6 cards validate and have runtime behavior, readiness is `6 / 24
= 0.25`.

### Sample Deck Pair Ready

The `sample_deck_pair_ready` formula is defined as:

`sample_deck_pair_ready = lane_pressure_deck_legal and response_control_deck_legal and shared_card_data_hash`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| lane_pressure_deck_legal | L | bool | true/false | Lane-pressure sample passes deck validation |
| response_control_deck_legal | R | bool | true/false | Response-control sample passes deck validation |
| shared_card_data_hash | H | bool | true/false | Both sample decks were validated against the same card data hash |

**Output Range:** boolean.
**Example:** If both decks pass but were validated against different card data
hashes, this formula is false because replay/setup compatibility is ambiguous.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Seed card requires unsupported effect schema | Keep card in `design_only`; do not include it in playable Godot deck data | Prevents ad hoc effects from entering deterministic runtime |
| Card has valid schema but runtime resolver is missing mutation behavior | Mark `schema_ready`; block from first playable decks until runtime catches up | Card data validity alone is not behavior readiness |
| Paper prototype effect differs from runtime skeleton behavior | Document the difference in implementation notes and prefer GDD behavior for future work | Avoids treating smoke scaffolding as final design |
| A sample deck includes a disabled or design-only card | Deck profile is not runnable and `sample_deck_pair_ready` is false | Sample decks must prove playable content, not paper intent |
| Archetype has enough tagged cards but no legal deck | Archetype is not playable for MVP | Deck rules are the actual test gate |
| `Counter Sigil` tries to cancel a unit while its text says spell | Reject or retarget the data before playable use | Card text and effect params must match |
| `Spark Shot` is submitted during a response window | Reject as main-speed timing violation | Paper log exposed this exact risk |
| `Guard Flash` is represented as normal healing | Reject the conversion unless text changes | Temporary health is not the same as permanent heal |
| `Anchor Ward` keeps its movement-prevention intention in prose only | Keep it out of runnable decks until movement-prevention status exists | Protection rules need explicit duration and affected effect categories |
| Direct player damage is authored without player-life target support | Keep card out of runnable decks | Target profiles and life mutation must exist together |
| A neutral bridge card appears in every sample deck | Flag as balance/archetype warning, not a hard validation error | MVP should protect deck identity without over-constraining exploration |
| Prototype card reaches `active` without design review | Block promotion | Prototype status is intentionally not production approval |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|----------------------|
| Card Data Model | This depends on Card Data Model | Uses `CardDefinition`, effect refs, tags, status, and card data hash |
| Deck Construction and Validation | This depends on Deck Construction and Validation | Uses `mvp_local` rules, copy limits, and sample deck legality |
| Turn, Timing, and Resource System | This depends on Turn, Timing, and Resource System | Uses main speed, response speed, and focus affordability |
| Stack and Response System | This depends on Stack and Response System | Uses one response per window and response-first resolution |
| Card Effect Resolution System | This depends on Card Effect Resolution System | Uses approved effect schemas and runtime readiness checks |
| Zone and Lane Board System | This depends on Zone and Lane Board System | Uses three lanes, unit stats, attack pressure, and movement legality |
| Action Log and Replay System | Depends on this | Needs card pool, deck ids, and effect outcomes for replay tests |
| Local Match Flow | Depends on this | Needs two legal sample decks before first local duel loop |
| Match Board UI and Input | Depends on this | Displays card text, cost, type, speed, tags, and readiness errors |
| Balance and Content Tooling | Depends on this | Reports card coverage, archetype coverage, and implementation readiness |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `MVP_CARD_POOL_TARGET` | 24 | 12-40 | More archetype variety and deckbuilding signal | Faster first playable, weaker deck identity proof |
| `MVP_ARCHETYPE_TARGET` | 2 | 2-4 | More matchup variety | Sharper first playable focus |
| `MVP_ARCHETYPE_CARD_TARGET` | 12 | 8-16 | More complete archetype identity | Easier to reach playable readiness |
| `MVP_SAMPLE_DECK_COUNT` | 2 | 2-4 | More matchup coverage | Less validation effort |
| `MVP_INITIAL_SEED_CARD_COUNT` | 12 | 12 fixed for this prototype | Not applicable | Not applicable |
| `MVP_IMPLEMENTATION_READY_CARD_TARGET` | 24 | 12-40 | Stronger data/runtime coverage | Earlier but narrower playable prototype |
| `PROTOTYPE_CARD_STATUS` | prototype | prototype only before review | Not applicable | Not applicable |
| `MAX_CARDS_PER_ARCHETYPE_SAMPLE` | 20 | 20 fixed by `MVP_LOCAL_DECK_SIZE` | Not applicable in MVP | Not applicable in MVP |

## Visual/Audio Requirements

This system does not define final card frames, art, VFX, or audio. It must
provide enough content metadata for later presentation systems to make prototype
cards readable.

| Requirement | Visual Feedback | Audio Feedback | Priority |
|-------------|----------------|---------------|----------|
| Archetype identity | Deck editor can group cards by `lane_pressure` and `response_control` tags | None | High |
| Implementation readiness | Tooling can show runtime-ready, schema-ready, and design-only cards distinctly | None | High |
| Response card speed | Card frame or badge distinguishes response-speed cards | Optional later | High |
| Prototype status | Prototype cards are visibly marked outside production collection views | None | Medium |
| Missing art | Use explicit prototype art key or simple card-frame fallback | None | Medium |

## Game Feel

### Feel Reference

The first set should feel like a compact duel kit: every card should be easy to
read, have one job, and create visible lane or response consequences. It should
not feel like a final release set with broad keywords and hidden synergies.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|--------|-----------------------------------|-------------------------|-------|
| Filter cards by archetype tag | 50ms | 3 frames | Deck editor/tooling target |
| Validate one sample deck | 100ms | 6 frames | Local MVP target |
| Query readiness for one card | 16ms | 1 frame | UI/tooling display target |

### Impact Moments

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|-------------|--------------|-------------------|---------------|
| Archetype deck selected | N/A | UI shows primary tags and legality status | Yes |
| Card blocked from runnable data | N/A | Tooling names missing schema/runtime dependency | Yes |
| Response-control card becomes legal | N/A | Coverage report updates implementation readiness | Yes |

### Weight and Responsiveness Profile

- **Weight**: Light and test-focused; content should help prove rules, not bury
  them.
- **Player control**: Medium; players express plan through card mix and timing.
- **Snap quality**: Categorical; every card is runtime-ready, schema-ready, or
  design-only.
- **Failure texture**: Direct tooling messages that name the missing schema,
  runtime behavior, or deck validation rule.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|------------------|-----------|
| Card name and rules text | Card inspect and deck editor | On render/inspect | Always |
| Archetype tags | Deck editor filters and card details | On render/filter | Prototype card list |
| Implementation tier | Tooling card list, debug deck editor | On data validation | Prototype content work |
| Deck legality | Deck editor and match setup | On edit/validation | Sample deck selected |
| Missing schema/runtime reason | Tooling validation report | On failed readiness check | Card not runtime-ready |
| Prototype status | Collection/deck editor metadata | On card render | Status is `prototype` |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|------------|-----------------------------|--------|
| Card specs become validated definitions | `design/gdd/card-data-model.md` | `CardDefinition`, status, effect refs, card data hash | Data dependency |
| Sample decks must be legal | `design/gdd/deck-construction-validation.md` | `mvp_local`, deck size, copy limits, role coverage | Rule dependency |
| Response cards spend focus | `design/gdd/turn-timing-resource-system.md` | dedicated response `focus` | Rule dependency |
| One-card response windows shape cards | `design/gdd/stack-response-system.md` | `MAX_RESPONSES_PER_WINDOW_MVP`, response order | Timing dependency |
| Card effects must use typed schemas | `design/gdd/card-effect-resolution-system.md` | damage, heal, move, cancel | Behavior dependency |
| Lane pressure depends on board state | `design/gdd/zone-lane-board-system.md` | three lanes, unit occupancy, movement | Gameplay dependency |
| Playable cards feed replay tests | `design/gdd/action-log-replay-system.md` | card data hash, accepted commands, outcomes | Persistence dependency |

## Acceptance Criteria

- [ ] **GIVEN** the 12-card paper seed, **WHEN** it is documented in this GDD, **THEN** every card has a proposed `card_id`, type, speed, cost, effect/stat description, archetype tags, and implementation tier.
- [ ] **GIVEN** a card marked `runtime_skeleton`, **WHEN** it enters Godot smoke scope, **THEN** its current behavior is limited to the implemented deterministic path named in this GDD.
- [ ] **GIVEN** a card marked `schema_ready`, **WHEN** runtime mutation is not implemented, **THEN** it is blocked from first playable loadouts until runtime gate is complete.
- [ ] **GIVEN** a card marked `design_only`, **WHEN** deck validation builds runnable sample decks, **THEN** that card is treated as unavailable until a supporting schema exists.
- [ ] **GIVEN** the MVP prototype pool, **WHEN** `prototype_card_pool_ready` is evaluated, **THEN** it is false unless at least 24 valid cards, 2 archetypes, and 2 legal sample decks are present.
- [ ] **GIVEN** `lane_pressure_sample`, **WHEN** all listed cards become implementation-ready, **THEN** it passes 20-card size, 10 unique cards, at least 6 unit cards, and at least 2 responses.
- [ ] **GIVEN** `response_control_sample`, **WHEN** all listed cards become implementation-ready, **THEN** it passes 20-card size, 10 unique cards, at least 6 unit cards, and at least 4 responses.
- [ ] **GIVEN** a response-speed card, **WHEN** it is authored for MVP, **THEN** its cost is paid from focus and its timing text does not imply main-speed play.
- [ ] **GIVEN** a main-speed spell, **WHEN** the defender has a response window, **THEN** that spell is not listed as a legal response option.
- [ ] **GIVEN** a prototype card reaches `active` promotion, **WHEN** review checks run, **THEN** design review, card data validation, deck validation, and replay compatibility are all complete.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|------------|
| Should Guard Flash and Rally Mark keep simplified MVP effects or require a status/modifier schema in this pass? | Systems Designer / Gameplay Programmer | Before first playable balance pass | Resolved for MVP: keep both cards as simplified approved effects |
| Should movement prevention be modeled as a dedicated protection status, a cancel rule, or a target-profile modifier? | Systems Designer | Before adding full protection mechanics | Deferred: current prototype keeps cancel-driven protection behavior |
| Should `Counter Sigil` cancel by command type, card type, effect category, or target profile? | Systems Designer | Before first response-control playable deck | Provisional: current resolver uses command type allowlist |
| Should the 24-card MVP set use final-facing names or neutral prototype names? | Creative Director / Systems Designer | Before art bible and content pipeline work | Provisional: current names are prototype names |

---

## Lean Review Notes

Specialist review was not run inline because `production/review-mode.txt` is set
to `lean` and no subagent spawn was explicitly requested. Run `/design-review
design/gdd/prototype-card-set-archetypes.md` in a fresh session before approval.
