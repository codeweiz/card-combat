# Card Data Model

> **Status**: Designed
> **Author**: Codex
> **Last Updated**: 2026-06-17
> **Last Verified**: 2026-06-17
> **Implements Pillar**: Rules Clarity Beats Hidden Complexity; Skillful Deck Identity; Deterministic Trust

## Summary

The Card Data Model defines the immutable source data for cards, effect references, targeting rules, timing speed, text keys, tags, and versioning. It prevents production card behavior from becoming untyped dictionaries or hardcoded script branches, and it gives the deterministic simulation core a stable input format.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `Deterministic Simulation Core`

## Overview

Card data is the contract between design, rules simulation, UI, localization, content tooling, and future server authority. A card definition describes what a card is allowed to request: its id, type, timing speed, cost, targets, tags, text, and effect references. It does not directly mutate match state; the effect resolution system interprets validated effect references during simulation. This separation lets the game add cards without rewriting core rules and lets action logs replay against a known card data version.

## Player Fantasy

This is mostly an indirect system, but it strongly supports deck identity. Players should feel that every card has a clear role, readable timing, and a reliable rules meaning. A player building a deck should be able to understand whether a card is proactive, reactive, lane-focused, combo-focused, defensive, or archetype-specific from its data-driven presentation and tags.

## Detailed Design

### Core Rules

1. Every playable card must have exactly one `CardDefinition`.
2. `CardDefinition` data is immutable during a match.
3. Runtime card instances reference `CardDefinition.card_id`; they do not copy mutable definition data.
4. Card ids must be globally unique within a card data version.
5. Card ids must be stable once released. Deprecated cards remain addressable for old logs and saves.
6. Card definitions must be loaded and validated before a match starts.
7. The deterministic simulation core receives card data by version and hash, not by ad hoc runtime edits.
8. Every card must declare:
   - `card_id`
   - `schema_version`
   - `name_key`
   - `rules_text_key`
   - `card_type`
   - `speed`
   - `base_cost`
   - `targeting_profile_id`
   - `effect_refs`
   - `tags`
   - `status`
9. MVP card types are `unit`, `spell`, and `response`.
10. MVP speed values are `main` and `response`.
11. MVP treats `response` as both a card type and a speed. A playable response
    card must use `card_type = response` and `speed = response`.
12. Main-speed response cards and response-speed non-response cards are invalid
    for MVP unless a future hybrid schema is approved.
13. A card with speed `main` can only be submitted during valid main-action windows.
14. A card with speed `response` can only be submitted during valid response windows.
15. A card may reference one or more effect ids, but each reference must include typed parameters required by that effect.
16. Effects must be referenced by id and parameter object. Card data must not embed executable script text.
17. Targeting profile ids define what the card may target at validation time.
18. Card text must use localization keys from the start, even in prototype content.
19. Card tags are design-facing and tooling-facing descriptors, not effect code.
20. Card art, frame, and audio references are optional for MVP placeholder cards but must use explicit fields when present.
21. Card definitions must support a `status` field: `active`, `prototype`, `disabled`, or `deprecated`.
22. Disabled cards cannot enter new legal decks.
23. Deprecated cards cannot enter new legal decks but remain loadable for old replays or saves.
24. Prototype cards can be used in local prototype formats but not production formats.
25. Card data validation must run before deck validation.
26. Card data validation failure blocks match start.
27. Production code must not import prototype card definitions from `prototypes/`; prototype learnings must be rewritten into production data.

### Data Shape

Minimum MVP `CardDefinition` shape:

```text
CardDefinition
  card_id: StringName
  schema_version: int
  name_key: StringName
  rules_text_key: StringName
  card_type: CardType
  speed: CardSpeed
  base_cost: int
  targeting_profile_id: StringName
  effect_refs: Array[EffectRef]
  tags: Array[StringName]
  status: CardStatus
  art_key: StringName optional
  frame_key: StringName optional
  audio_key: StringName optional
```

Minimum MVP `EffectRef` shape:

```text
EffectRef
  effect_id: StringName
  params: typed parameter object validated against effect schema
```

### MVP Authoring Format

MVP production card data is authored as Godot `.tres` Resource assets backed by
the `CardDefinition`, `EffectRef`, and typed `EffectParams` classes accepted in
ADR-0001 and ADR-0002. Smoke tests and narrow headless fixtures may still build
`CardDatabase` instances programmatically, but reusable playable content should
enter through Resource definitions so designers, tools, validation, and Godot
imports use the same schema. JSON, CSV, or hybrid exports are deferred to the
future content pipeline and must preserve the same canonical card data hash.

Example paper-prototype conversion:

```text
card_id: "spark_shot"
card_type: spell
speed: main
base_cost: 1
targeting_profile_id: "enemy_or_friendly_unit"
effect_refs:
  - effect_id: "deal_damage"
    params:
      amount: 2
tags: ["damage", "unit_target"]
```

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| Draft | Designer is authoring or editing a definition | Validation run begins | May be incomplete; not loadable by matches |
| Validating | Data loader checks schema, ids, text keys, target profiles, and effect refs | Validation succeeds or fails | Produces validation report |
| Active | Validation succeeds and status is `active` | Disabled or deprecated by content update | Legal in supported formats |
| Prototype | Validation succeeds and status is `prototype` | Promoted, disabled, or removed | Legal only in prototype/local formats |
| Disabled | Card is blocked from new decks | Reactivated or deprecated | Loadable for tooling, not legal for new decks |
| Deprecated | Card is preserved for old content | Never exits except through migration tooling | Loadable for old saves/replays, not legal for new decks |
| Invalid | Validation fails | Designer fixes data and reruns validation | Blocks match start and content export |

### Interactions with Other Systems

| System | Data In | Data Out | Ownership Boundary |
|--------|---------|----------|--------------------|
| Deterministic Simulation Core | Card data version and card data hash | Definition ids used in match setup and state | Data model owns definitions; simulation owns runtime state |
| Turn, Timing, and Resource System | `speed`, `base_cost`, card type | Legal timing and affordability decisions | Timing system owns when a card can be played |
| Stack and Response System | `speed`, response tags, target profile | Response-window legality decisions | Stack system owns priority windows |
| Zone and Lane Board System | Card type and lane/zone tags | Valid placement target checks | Board system owns spatial legality |
| Card Effect Resolution System | `effect_refs` and typed params | Resolved state mutations and events | Effect system owns effect semantics |
| Deck Construction and Validation | `card_id`, status, tags, format metadata | Legal deck list or validation errors | Deck system owns format rules and copy counts |
| Match Board UI and Input | name keys, text keys, cost, speed, target profiles, tags | Display cards, legal targets, disabled reasons | UI owns presentation and interaction |
| Localization and Text Layout | `name_key`, `rules_text_key` | Localized text and overflow reports | Localization owns final text strings |
| Card Frame and Visual Identity System | card type, speed, tags, art/frame keys | Card frame selection and visual affordances | Visual system owns art direction |
| Balance and Content Tooling | Full card definitions | Reports, filters, validation errors, data exports | Tooling owns authoring workflows |

## Formulas

### Card Data Hash

The `card_data_hash` formula is defined as:

`card_data_hash = stable_hash(canonical_serialize(card_definitions_sorted_by_card_id, card_schema_version))`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| card_definitions_sorted_by_card_id | D | array | 0-N cards | All loaded card definitions sorted by stable `card_id` |
| card_schema_version | V | int | 1+ | Schema version used to interpret definitions |
| canonical_serialize | C(D,V) | function | deterministic string/bytes | Stable serialization function |
| stable_hash | H(C) | function | SHA-256 lowercase hex string | `StableHash.stable_hash()` hashes the canonical string with `String.sha256_text()` |

**Output Range:** implementation-defined hash string or integer; identical card data must produce identical output on every platform.
**Example:** A replay stores `card_data_hash`; if current content hash differs, replay must fail before command playback.

### Card Definition Valid

The `card_definition_valid` formula is defined as:

`card_definition_valid = required_fields_present and id_unique and refs_resolve and params_match_schema and localization_keys_exist`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| required_fields_present | R | bool | true/false | All required fields exist and have legal types |
| id_unique | U | bool | true/false | No duplicate `card_id` in the loaded data set |
| refs_resolve | E | bool | true/false | All `effect_id` and `targeting_profile_id` references exist |
| params_match_schema | P | bool | true/false | Every effect param object matches its effect schema |
| localization_keys_exist | L | bool | true/false | Required text keys exist in the active source locale |

**Output Range:** boolean.
**Example:** If a card references `deal_damage` but omits required `amount`, `params_match_schema` is false and the definition is invalid.

### MVP Card Pool Coverage

The `mvp_card_pool_coverage` formula is defined as:

`mvp_card_pool_coverage = valid_mvp_cards / MVP_CARD_POOL_TARGET`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| valid_mvp_cards | C | int | 0-200 | Count of active/prototype cards legal in the MVP format |
| MVP_CARD_POOL_TARGET | T | int | 24 | Initial target card count for first Godot playable prototype |

**Output Range:** 0.0 to 1.0+; 1.0 means the MVP target is met.
**Example:** 12 valid paper-prototype cards produce coverage `12 / 24 = 0.5`.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Duplicate `card_id` appears in loaded data | Mark both conflicting definitions invalid and block export/match start | Stable ids are required for replay |
| Card references missing `effect_id` | Mark card invalid | Effects cannot be guessed by the loader |
| Card references missing `targeting_profile_id` | Mark card invalid | Legal target UI and validation need explicit rules |
| Effect params include unknown fields | Mark card invalid unless schema explicitly allows extension fields | Prevents typo-driven behavior |
| Effect params omit required fields | Mark card invalid | Prevents partial effects from reaching simulation |
| `base_cost` is negative | Mark card invalid | Negative costs create resource exploits |
| `base_cost` exceeds format maximum | Mark card invalid for that format but keep definition loadable | Supports different future formats without deleting data |
| Card has `response` type but `main` speed | Allow only if explicitly tagged as hybrid in future schema; invalid for MVP | Keeps MVP timing readable |
| Card has missing localization key | Mark card invalid for production export; allow prototype export only with visible placeholder text | Production card text must be localized |
| Card text and effect refs disagree | Mark as validation warning initially, later error when text tooling exists | Text/effect parity is important but requires tooling |
| Deprecated card appears in old replay | Load definition if data version/hash matches replay | Old logs must remain inspectable |
| Deprecated card appears in new deck | Deck validation rejects it | Deprecated cards should not enter new play |
| Prototype card appears in production format | Deck validation rejects it | Prototype content must not leak into production |
| Card art key is missing | Use placeholder art in MVP | Art should not block rules validation |
| Card schema version is newer than runtime supports | Reject load with schema mismatch | Prevents silent misinterpretation |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|----------------------|
| Deterministic Simulation Core | This depends on Deterministic Simulation Core | Must provide stable data version and hash to match setup/replay |
| Turn, Timing, and Resource System | Depends on this | Reads speed and base cost |
| Zone and Lane Board System | Depends on this | Reads card type and placement tags |
| Stack and Response System | Depends on this | Reads response speed and timing tags |
| Card Effect Resolution System | Depends on this | Reads effect ids and typed params |
| Deck Construction and Validation | Depends on this | Reads card ids, status, tags, and format metadata |
| Match Board UI and Input | Depends on this | Displays card text, speed, cost, and legal target hints |
| Localization and Text Layout | Depends on this | Resolves `name_key` and `rules_text_key` |
| Card Frame and Visual Identity System | Depends on this | Uses card type, speed, tags, frame key, and art key |
| Balance and Content Tooling | Depends on this | Validates, filters, and exports card definitions |
| Content Pipeline | Depends on this | Packages card data for clients and future servers |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `CARD_SCHEMA_VERSION` | 1 | 1+ | Enables data migrations and new fields | Not applicable below 1 |
| `MVP_CARD_POOL_TARGET` | 24 | 12-40 | More archetype variety and interaction coverage | Faster testing, less deck identity proof |
| `MAX_EFFECT_REFS_PER_CARD` | 3 | 1-6 | Supports richer card behavior | Keeps card text and validation simpler |
| `MAX_TAGS_PER_CARD` | 8 | 2-16 | Better filtering and archetype tooling | Less tooling precision |
| `MAX_BASE_COST_MVP` | 10 | 6-15 | Supports expensive finishers | Keeps MVP curve compact |
| `ALLOW_PROTOTYPE_STATUS_IN_LOCAL_FORMATS` | true | true/false | Easier iteration with test cards | Stricter production parity |

## Visual/Audio Requirements

The Card Data Model does not own final visual or audio presentation, but it must expose stable keys that downstream presentation systems consume.

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Card type displayed | Card frame chooses type styling from `card_type` | None | High |
| Card speed displayed | Response/main timing badge from `speed` | None | High |
| Card played | UI may use `audio_key` later | Optional card play stinger | Medium |
| Card has missing art | Placeholder art frame | None | Medium |

## Game Feel

### Feel Reference

This system should support the feeling of quickly understanding a card at a glance, similar to clean digital card game presentation: cost, timing, type, target intent, and rules text should all line up with actual behavior.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|--------|-----------------------------------|-------------------------|-------|
| Fetch card definition by id | 5ms | <1 frame | Local lookup target |
| Validate one card definition in editor/tooling | 10ms | N/A | Tooling target |
| Query display fields for one hand card | 16ms | 1 frame | UI target for responsive hand rendering |

### Animation Feel Targets

This system owns no animation. It must keep presentation keys stable so UI can animate cards without parsing rules text.

| Animation | Startup Frames | Active Frames | Recovery Frames | Feel Goal | Notes |
|-----------|---------------|--------------|----------------|-----------|-------|
| Not owned by this system | N/A | N/A | N/A | Data lookup should not delay UI | UI systems own animation |

### Impact Moments

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|-------------|--------------|-------------------|---------------|
| Invalid card data warning | N/A | Tooling highlights invalid field and reason | Yes |
| Missing localization/art fallback | N/A | UI/tooling shows explicit placeholder | Yes |

### Weight and Responsiveness Profile

- **Weight**: Lightweight and predictable; data lookup should never feel heavy.
- **Player control**: Indirect; players benefit from clear card presentation and reliable deck identity.
- **Snap quality**: Crisp and categorical; card type, speed, and targets should be unambiguous.
- **Acceleration model**: Instant lookup after data load.
- **Failure texture**: Clear tooling errors for designers; clear disabled states for players.

### Feel Acceptance Criteria

- [ ] A player can distinguish main-speed cards from response-speed cards without reading long rules text.
- [ ] A disabled or illegal card has a visible reason in tooling/UI.
- [ ] Card display never depends on executable effect code.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|------------------|-----------|
| Card name | Hand, board, deck editor, collection | On card render | Always |
| Rules text | Hand inspect, card detail, deck editor | On card inspect/render | Always |
| Cost | Hand, deck editor, card detail | On card render | Always |
| Card type | Card frame and detail panel | On card render | Always |
| Speed | Timing badge or frame affordance | On card render | Always |
| Legal target hint | Match board UI | On card selection | Card has targeting profile |
| Tags/archetype labels | Deck editor and tooling | On filter/search | Deckbuilding or content work |
| Status | Tooling/deck editor | On card list render | Disabled/deprecated/prototype cards |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|------------|-----------------------------|--------|
| Card data hash feeds match setup | `design/gdd/deterministic-simulation-core.md` | `card_data_hash`, match setup data | Data dependency |
| Speed and cost feed timing legality | `design/gdd/turn-timing-resource-system.md` | `speed`, `base_cost` | Data dependency |
| Placement tags feed lane legality | `design/gdd/zone-lane-board-system.md` | card type and lane tags | Data dependency |
| Response speed feeds stack rules | `design/gdd/stack-response-system.md` | response timing tags | Rule dependency |
| Effect refs feed effect resolution | `design/gdd/card-effect-resolution-system.md` | effect id and params | Data dependency |
| Card ids feed deck legality | `design/gdd/deck-construction-validation.md` | card id, status, tags | Data dependency |
| Text keys feed localization | `design/gdd/localization-text-layout.md` | `name_key`, `rules_text_key` | Data dependency |
| Visual keys feed card frame system | `design/gdd/card-frame-visual-identity-system.md` | `art_key`, `frame_key`, card type | Data dependency |

## Acceptance Criteria

- [ ] **GIVEN** a complete valid card definition, **WHEN** card data validation runs, **THEN** the card enters `active` or `prototype` loadable state.
- [ ] **GIVEN** two cards with the same `card_id`, **WHEN** validation runs, **THEN** both definitions are rejected and match start is blocked.
- [ ] **GIVEN** a card referencing an unknown effect id, **WHEN** validation runs, **THEN** the card is rejected with the missing effect id named.
- [ ] **GIVEN** a card referencing an unknown targeting profile, **WHEN** validation runs, **THEN** the card is rejected with the missing profile named.
- [ ] **GIVEN** a card with missing localization keys, **WHEN** production export validation runs, **THEN** export fails.
- [ ] **GIVEN** a deprecated card in an old replay with matching card data hash, **WHEN** replay loads, **THEN** the card definition remains available for replay.
- [ ] **GIVEN** a deprecated card in a new deck, **WHEN** deck validation runs, **THEN** the deck is rejected.
- [ ] **GIVEN** identical card data on two supported clients, **WHEN** `card_data_hash` is computed, **THEN** both clients produce the same hash.
- [ ] **GIVEN** 24 valid MVP cards, **WHEN** `mvp_card_pool_coverage` is computed with target 24, **THEN** coverage equals 1.0.
- [ ] Performance: fetching a card definition by id completes within 5ms in local runtime.
- [ ] No card behavior is implemented as raw executable script text embedded in card data.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|------------|
| What is the final list of MVP effect schemas? | Systems Designer | Before Card Effect Resolution GDD | Pending card rules design |
| How strict should text/effect parity validation be in MVP? | Systems Designer / Localization Lead | Before content pipeline | Pending tooling capability |
| What naming convention should production card ids use for factions/archetypes? | Systems Designer / Writer | Before first authored card batch | Pending art/narrative direction |

---

## Lean Review Notes

Specialist review was not run inline. Run `/design-review design/gdd/card-data-model.md` in a fresh session before approval.
