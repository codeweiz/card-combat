# Deck Construction and Validation

> **Status**: Designed
> **Author**: Codex
> **Last Updated**: 2026-06-17
> **Last Verified**: 2026-06-17
> **Implements Pillar**: Skillful Deck Identity; Rules Clarity Beats Hidden Complexity; Deterministic Trust

## Summary

Deck Construction and Validation defines how player deck lists become legal match
loadouts. It checks card ids, format rules, copy limits, card status, required
card-role coverage, and deterministic deck fingerprints before a match can start.
It sits between immutable card data and local match flow so invalid, disabled, or
format-incompatible decks never enter simulation.

> **Quick reference** - Layer: `Core` · Priority: `MVP` · Key deps: `Card Data Model`

## Overview

Card Combat needs deck identity before large collection systems or ranked formats.
This system lets players assemble small, readable MVP decks from validated card
definitions and guarantees that every accepted deck can be replayed later with
the same card data hash and format rules. MVP deck validation is intentionally
narrow: one main deck, no sideboard, no collection ownership checks, no ranked
ban list service, and no live economy. The output is a validated deck loadout
that Local Match Flow can attach to deterministic match setup.

## Player Fantasy

Players should feel that a deck is their strategy engine, not just a pile of
cards. Validation should support experimentation while protecting clarity: if a
deck is illegal, the player should know exactly whether the problem is size,
copy count, unavailable card status, wrong format, or missing core role coverage.
The emotional target is confident ownership: "this is my plan, and the game can
prove it is legal under the same rules my opponent uses."

## Detailed Design

### Core Rules

1. A deck list belongs to exactly one format.
2. MVP supports the `mvp_local` format for first playable local matches.
3. Paper prototype fixed decks may be represented as a separate prototype format,
   but production source must not import deck lists directly from `prototypes/`.
4. A deck list must reference card ids, not copied card definition data.
5. Card data validation must pass before deck validation runs.
6. Deck validation must use the same `CardDatabase` and `card_data_hash` that the
   future match setup will use.
7. A deck list must declare:
   - `deck_id`
   - `owner_player_id` or profile owner id when available
   - `format_id`
   - ordered `card_ids`
   - optional `display_name`
   - optional `declared_archetype_tags`
8. MVP `mvp_local` decks have exactly `MVP_LOCAL_DECK_SIZE` cards.
9. MVP `mvp_local` decks may include only `active` or `prototype` cards.
10. Disabled cards cannot enter any new deck.
11. Deprecated cards cannot enter new decks but remain loadable for old replays
    when the replay card data hash matches.
12. Unknown card ids make the deck invalid.
13. A card may appear at most `MVP_MAX_COPIES_PER_CARD` times unless a future
    format rule explicitly overrides that card's copy limit.
14. MVP decks must contain at least `MVP_MIN_UNIQUE_CARDS` unique card ids.
15. MVP decks must contain at least `MVP_MIN_UNIT_CARDS` unit cards so lane play
    can be tested.
16. MVP decks must contain at least `MVP_MIN_RESPONSE_CARDS` response-speed cards
    so response windows can be tested.
17. MVP decks must contain no more than `MVP_MAX_RESPONSE_CARDS` response-speed
    cards to avoid response-heavy lists that cannot play proactive turns.
18. Deck validation may emit warnings for weak archetype identity, but warnings
    do not block MVP local play.
19. A deck with no declared archetype tags is legal in MVP if all hard format
    rules pass.
20. Deck fingerprints must be deterministic and must include format id, card data
    hash, deck schema version, and sorted card counts.
21. Validation errors must be stable, specific, and UI-displayable.
22. Accepted local match setup must include or derive per-player validated deck
    loadouts before draw/deck zones are implemented.
23. A match cannot start if any required player deck is invalid.
24. Deck validation must not read scene tree state, UI state, live collection
    ownership, network state, or wall-clock time.
25. Collection ownership, crafting, monetization, ranked bans, sideboards, and
    best-of-three rules are out of scope for MVP deck validation.

### Data Shape

Minimum MVP `DeckList` shape:

```text
DeckList
  deck_id: StringName
  owner_player_id: StringName
  format_id: StringName
  card_ids: Array[StringName]
  display_name: String optional
  declared_archetype_tags: Array[StringName] optional
```

Minimum MVP `ValidatedDeck` output:

```text
ValidatedDeck
  deck_id: StringName
  owner_player_id: StringName
  format_id: StringName
  card_ids: Array[StringName]
  card_counts_by_id: Dictionary[StringName, int]
  deck_fingerprint: String
  card_data_hash: String
  valid: bool
  errors: Array[String]
  warnings: Array[String]
```

Implementation note: current `MatchSetup` stores `format_id` and
`card_data_hash`, but it does not yet store per-player deck ids or ordered deck
card ids. Local Match Flow must add that setup data before draw/deck-zone
simulation can be considered complete.

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| DraftDeck | Player or tool is editing card ids | Validation requested | May be incomplete or illegal |
| ValidatingDeck | Card database and format rules are available | Validation passes or fails | Checks ids, status, size, copies, and composition |
| LegalDeck | All hard rules pass | Edited, format changes, or card data changes | Can be selected for local match setup |
| WarningDeck | Hard rules pass but warning rules fail | Player edits or accepts warning | Legal for MVP, but UI/tooling should explain weakness |
| InvalidDeck | One or more hard rules fail | Player edits and reruns validation | Cannot start a match |
| DeprecatedReplayDeck | Deck exists only for old replay compatibility | Replay load completes or fails | Loadable only with matching card data hash |

Valid flow:

```text
DraftDeck -> ValidatingDeck -> LegalDeck
DraftDeck -> ValidatingDeck -> WarningDeck
DraftDeck -> ValidatingDeck -> InvalidDeck
LegalDeck -> DraftDeck                      # player edits
WarningDeck -> DraftDeck                    # player edits
DeprecatedReplayDeck -> LegalDeck is not allowed for new play
```

### Interactions with Other Systems

| System | Data In | Data Out | Ownership Boundary |
|--------|---------|----------|--------------------|
| Card Data Model | Card ids, card status, type, speed, tags, card data hash | Card legality facts and deck fingerprint input | Card data owns definitions; deck validation owns format legality |
| Deterministic Simulation Core | Validated deck loadouts and card data hash | Match setup eligibility | Core owns match state; deck validation blocks invalid setup before core init |
| Action Log and Replay System | Deck fingerprint, card data hash, format id | Replay compatibility evidence | Replay records facts; deck validation computes and verifies deck facts |
| Prototype Card Set and Archetypes | Prototype card pool and archetype tags | Legal prototype/test decks | Prototype content supplies cards; deck validation enforces format rules |
| Local Match Flow | Selected player deck lists | Legal match loadouts or validation errors | Match flow starts matches only with legal decks |
| Match Board UI and Input | Validation errors, warnings, role counts | Deck editor disabled states and explanations | UI displays results; validation owns truth |
| Card Collection and Inventory | Future ownership data | Ownership-gated legality later | Collection is out of MVP; deck validation reserves integration point |
| Balance and Content Tooling | Deck composition, card counts, archetype tags | Meta/composition reports later | Tooling analyzes; validation enforces hard rules |
| Match Authority Architecture | Submitted deck loadout and fingerprint | Authority-side legality verdict later | Authority must rerun validation; client cannot self-certify decks |

## Formulas

### Deck Size Valid

The `deck_size_valid` formula is defined as:

`deck_size_valid = deck_card_count == MVP_LOCAL_DECK_SIZE`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| deck_card_count | C | int | 0-200 | Number of card ids in the submitted deck list |
| MVP_LOCAL_DECK_SIZE | D | int | 20 | Required main-deck size for MVP local constructed play |

**Output Range:** boolean.
**Example:** A 20-card `mvp_local` deck passes this formula; a 19-card deck
fails before copy or composition checks matter.

### Deck Copy Count Valid

The `deck_copy_count_valid` formula is defined as:

`deck_copy_count_valid = highest_copy_count <= MVP_MAX_COPIES_PER_CARD`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| highest_copy_count | H | int | 0-200 | Maximum count of any single card id in the deck |
| MVP_MAX_COPIES_PER_CARD | M | int | 2 | MVP local copy limit per card id |

**Output Range:** boolean.
**Example:** Three copies of `vanguard` fail MVP validation when the copy limit
is 2.

### Deck Card Pool Valid

The `deck_card_pool_valid` formula is defined as:

`deck_card_pool_valid = all_card_ids_resolve and all_card_statuses_allowed and format_id_supported`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| all_card_ids_resolve | R | bool | true/false | Every submitted card id exists in the active `CardDatabase` |
| all_card_statuses_allowed | S | bool | true/false | Every card status is legal for the selected format |
| format_id_supported | F | bool | true/false | The validator recognizes the submitted format id |

**Output Range:** boolean.
**Example:** A deck containing a disabled card fails even if deck size and copy
counts are otherwise legal.

### Deck Composition Valid

The `deck_composition_valid` formula is defined as:

`deck_composition_valid = unique_card_count >= MVP_MIN_UNIQUE_CARDS and unit_card_count >= MVP_MIN_UNIT_CARDS and response_card_count >= MVP_MIN_RESPONSE_CARDS and response_card_count <= MVP_MAX_RESPONSE_CARDS`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| unique_card_count | U | int | 0-200 | Number of distinct card ids in the deck |
| MVP_MIN_UNIQUE_CARDS | Q | int | 10 | Minimum distinct card ids for MVP local decks |
| unit_card_count | N | int | 0-200 | Number of unit cards in the deck |
| MVP_MIN_UNIT_CARDS | M | int | 6 | Minimum unit cards required to test lane play |
| response_card_count | R | int | 0-200 | Number of response-speed cards in the deck |
| MVP_MIN_RESPONSE_CARDS | A | int | 4 | Minimum response-speed cards required to test stack play |
| MVP_MAX_RESPONSE_CARDS | X | int | 8 | Maximum response-speed cards allowed in MVP local decks |

**Output Range:** boolean.
**Example:** A 20-card deck with 10 unique cards, 7 unit cards, and 4 response
cards passes this formula.

### Deck Legal

The `deck_legal` formula is defined as:

`deck_legal = card_data_valid and deck_size_valid and deck_copy_count_valid and deck_card_pool_valid and deck_composition_valid`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| card_data_valid | D | bool | true/false | Card database validation passed before deck validation |
| deck_size_valid | S | bool | true/false | Deck has the required number of cards |
| deck_copy_count_valid | C | bool | true/false | No card exceeds copy limit |
| deck_card_pool_valid | P | bool | true/false | All cards resolve and are allowed in format |
| deck_composition_valid | O | bool | true/false | MVP role coverage rules pass |

**Output Range:** boolean.
**Example:** A deck with legal size and copies still fails if one card id is
unknown because `deck_card_pool_valid` is false.

### Deck Fingerprint

The `deck_fingerprint` formula is defined as:

`deck_fingerprint = stable_hash(canonical_serialize(format_id, card_data_hash, deck_schema_version, card_counts_sorted_by_card_id))`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| format_id | F | StringName | supported format ids | Format rules used for validation |
| card_data_hash | H | String | implementation-defined | Hash of card data used to resolve ids |
| deck_schema_version | V | int | 1+ | Version of the deck-list schema |
| card_counts_sorted_by_card_id | C | dictionary/list | 0-N cards | Stable counts for each card id sorted by card id |
| canonical_serialize | S(F,H,V,C) | function | deterministic string/bytes | Stable serialization function |
| stable_hash | X(S) | function | implementation-defined | Hash function selected by implementation ADR/test setup |

**Output Range:** implementation-defined hash string.
**Example:** Two deck lists with the same card counts in different editing order
produce the same fingerprint, while different card data hash produces a different
fingerprint.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Deck has too few or too many cards | Reject with `deck_size_invalid` and report expected/actual counts | Size is the first hard format gate |
| Unknown card id appears | Reject and list the missing card id | Players and tools need direct repair feedback |
| Duplicate card exceeds copy limit | Reject and list card id plus current/max copies | Copy-limit failures should be actionable |
| Card data validation failed | Reject deck validation before card-level checks | Deck rules cannot trust invalid definitions |
| Disabled card appears | Reject for all new decks | Disabled content is not legal play content |
| Deprecated card appears in new deck | Reject for new play | Deprecated cards are replay-compatible only |
| Prototype card appears in `mvp_local` | Allow for MVP local testing | MVP local uses prototype placeholder cards |
| Prototype card appears in future production format | Reject unless format explicitly allows it | Prevents prototype content leakage |
| Deck meets hard rules but has weak archetype tags | Emit warning only | MVP should not over-constrain early archetype exploration |
| Deck has no response cards | Reject for MVP local | Stack/response hook needs response coverage in tests |
| Deck has too many response cards | Reject for MVP local | Prevents non-functional hands in first playable tests |
| Deck has no units | Reject for MVP local | Lane play must be testable |
| Deck order differs but card counts match | Fingerprint matches; initial match deck order is produced later by deterministic setup | Fingerprints should represent deck legality, not draw order |
| Same card counts but different card data hash | Fingerprint differs and replay compatibility fails | Card meaning may have changed |
| Player edits deck during match setup | Revalidate and regenerate fingerprint before match start | Avoids stale legality state |
| Match starts without validated deck loadouts | Reject match setup | Simulation must not invent deck legality |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|----------------------|
| Card Data Model | This depends on Card Data Model | Reads card ids, status, type, speed, tags, and card data hash |
| Deterministic Simulation Core | This feeds Deterministic Simulation Core | Provides valid deck loadouts before match initialization |
| Action Log and Replay System | This feeds Action Log and Replay System | Supplies deck fingerprints, format id, and card data hash for compatibility |
| Prototype Card Set and Archetypes | Depends on this | Needs legal test decks and archetype tags |
| Local Match Flow | Depends on this | Starts local matches only after both decks validate |
| Match Board UI and Input | Depends on this | Displays validation errors and deck editor state |
| Determinism Test Harness | Depends on this | Builds valid test decks and invalid-deck cases |
| Card Collection and Inventory | Future dependency | Adds ownership checks after profile/collection systems exist |
| Balance and Content Tooling | Depends on this | Analyzes card counts, role coverage, and archetype coverage |
| Match Authority Architecture | Depends on this later | Must rerun validation server-side before accepting online matches |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `DECK_SCHEMA_VERSION` | 1 | 1+ | Enables migrations and new fields | Not applicable below 1 |
| `MVP_LOCAL_DECK_SIZE` | 20 | 20-40 | More variance and longer deck plans | Faster matches and simpler testing |
| `MVP_MAX_COPIES_PER_CARD` | 2 | 1-3 | More consistency and combo reliability | More variety, less consistency |
| `MVP_MIN_UNIQUE_CARDS` | 10 | 8-20 | More variety and broader testing | More focused/repetitive decks |
| `MVP_MIN_UNIT_CARDS` | 6 | 4-12 | More lane board presence | More spell/response room |
| `MVP_MIN_RESPONSE_CARDS` | 4 | 0-8 | More response-window testing | Fewer interaction moments |
| `MVP_MAX_RESPONSE_CARDS` | 8 | 4-12 | More reactive identity | More proactive deck pressure |
| `ALLOW_PROTOTYPE_CARDS_IN_MVP_LOCAL` | true | true/false | Faster placeholder-card iteration | Stricter production parity |
| `SIDEBOARD_SIZE_MVP` | 0 | 0 only for MVP | Future best-of-three support | No sideboard complexity |

## Visual/Audio Requirements

This system does not own final card visuals or audio, but it must provide clear
validation states that the deck editor and match setup UI can present.

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Deck valid | Deck editor enables start/save affordance | Optional soft confirm later | High |
| Deck invalid | Deck editor highlights invalid count/card/format rule | Optional soft error later | High |
| Deck warning | Deck editor shows non-blocking warning marker | None | Medium |
| Card exceeds copy limit | Specific card row shows current/max copies | None | High |
| Card unavailable in format | Card row disabled with reason | None | High |

## Game Feel

### Feel Reference

Deck construction should feel like shaping a plan under clear constraints. The
validator should be fast enough that every edit immediately explains whether the
deck is legal, without making players hunt through hidden rules.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|--------|-----------------------------------|-------------------------|-------|
| Validate one MVP deck | 50ms | 3 frames | Local deck editor target |
| Recompute deck fingerprint | 20ms | 2 frames | On save/start |
| Show card-specific error | 50ms | 3 frames | On add/remove card |
| Validate both player decks for local match | 100ms | 6 frames | Before match setup |

### Weight and Responsiveness Profile

- **Weight**: Light and immediate; validation should not feel like a separate
  loading step for MVP decks.
- **Player control**: High in deck editor; every invalid state should be
  explainable and repairable.
- **Snap quality**: Categorical for hard rules, advisory for warnings.
- **Failure texture**: Specific and constructive; errors name the card, count,
  format rule, and expected value when possible.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|------------------|-----------|
| Deck size current/required | Deck editor header | On add/remove | Always |
| Copy count current/max | Card row or tooltip | On add/remove | Card count > 0 or invalid attempt |
| Unit/response role counts | Deck editor summary | On add/remove | MVP local format |
| Format id | Deck editor format selector | On deck load/change | Always |
| Validation errors | Deck editor summary and affected rows | On validation | Errors exist |
| Validation warnings | Deck editor summary | On validation | Warnings exist |
| Deck fingerprint | Debug/tooling panel | On save/start | Debug tools enabled |
| Card status reason | Card row disabled reason | On card list render | Disabled/deprecated/format-incompatible |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|------------|-----------------------------|--------|
| Card ids and status come from card data | `design/gdd/card-data-model.md` | `card_id`, `status`, card type, speed, tags | Data dependency |
| Match setup must receive legal loadouts | `design/gdd/deterministic-simulation-core.md` | setup and card data hash | Data dependency |
| Replay compatibility uses deck/card facts | `design/gdd/action-log-replay-system.md` | card data hash and format id | Persistence dependency |
| Prototype card set needs legal test decks | `design/gdd/prototype-card-set-archetypes.md` | archetype tags and prototype cards | Future content dependency |
| Local match flow starts only with valid decks | `design/gdd/local-match-flow.md` | selected deck loadouts | Future flow dependency |
| Collection ownership is out of MVP | `design/gdd/card-collection-inventory.md` | ownership-gated deck legality | Future progression dependency |

## Acceptance Criteria

- [ ] **GIVEN** a valid card database and a 20-card MVP local deck, **WHEN** deck validation runs, **THEN** the deck is accepted if size, copy, card pool, and composition formulas all pass.
- [ ] **GIVEN** a deck with 19 cards, **WHEN** validation runs, **THEN** the deck is rejected with expected size 20 and actual size 19.
- [ ] **GIVEN** a deck with three copies of one card, **WHEN** validation runs, **THEN** the deck is rejected with that card id and max copies 2.
- [ ] **GIVEN** a deck containing an unknown card id, **WHEN** validation runs, **THEN** the deck is rejected and the missing id is listed.
- [ ] **GIVEN** a deck containing a disabled card, **WHEN** validation runs, **THEN** the deck is rejected for new play.
- [ ] **GIVEN** a deck containing a deprecated card, **WHEN** validation runs for new play, **THEN** the deck is rejected while old matching replays may still load it.
- [ ] **GIVEN** an MVP local deck with fewer than 6 unit cards, **WHEN** validation runs, **THEN** the deck is rejected for insufficient unit coverage.
- [ ] **GIVEN** an MVP local deck with fewer than 4 response-speed cards, **WHEN** validation runs, **THEN** the deck is rejected for insufficient response coverage.
- [ ] **GIVEN** an MVP local deck with more than 8 response-speed cards, **WHEN** validation runs, **THEN** the deck is rejected for excessive response coverage.
- [ ] **GIVEN** two deck lists with the same card counts in different editing order, **WHEN** `deck_fingerprint` is computed, **THEN** both fingerprints match.
- [ ] **GIVEN** the same card counts but a different card data hash, **WHEN** `deck_fingerprint` is computed, **THEN** the fingerprint differs.
- [ ] **GIVEN** both players select legal decks, **WHEN** Local Match Flow requests match start, **THEN** validated loadouts are available for match setup.
- [ ] **GIVEN** either player selects an invalid deck, **WHEN** Local Match Flow requests match start, **THEN** match setup is rejected before simulation initialization.
- [ ] Performance: validating one MVP local deck completes within 50ms in local tooling.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|------------|
| Should MVP local deck size stay 20 or move toward 30-40 after the first playable test? | Systems Designer | After first Godot playable playtest | Provisional: 20 for speed and placeholder content scope |
| Should archetype tags ever become hard validation requirements? | Systems Designer | Before Prototype Card Set GDD | Provisional: warnings only for MVP |
| Should match setup store pre-shuffled deck order or shuffle from deck list plus seed? | Gameplay Programmer / QA Lead | Before deck-zone implementation | Provisional: validation produces fingerprint; match setup must add deterministic ordered deck ids |
| When collection exists, does deck validation own ownership checks or call collection service? | Gameplay Programmer / Economy Designer | Before Card Collection and Inventory GDD | Provisional: call collection service later |
| Should response-card minimum remain after focus/resource playtests? | Systems Designer | After second response-focus prototype | Provisional: keep minimum 4 for MVP local interaction coverage |

---

## Lean Review Notes

Specialist review was not run inline because `production/review-mode.txt` is set
to `lean` and no subagent spawn was explicitly requested. Run
`/design-review design/gdd/deck-construction-validation.md` in a fresh session
before approval.
