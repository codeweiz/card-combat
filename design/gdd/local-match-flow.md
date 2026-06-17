# Local Match Flow

> **Status**: Designed
> **Author**: Codex
> **Last Updated**: 2026-06-17
> **Last Verified**: 2026-06-17
> **Implements Pillar**: Deterministic Trust; Rules Clarity Beats Hidden Complexity; Cross-Platform First; Skillful Deck Identity

## Summary

Local Match Flow defines how two local players move from validated decks into a
complete deterministic duel and a replay-verifiable result. It is the orchestration
layer for first playable: select loadouts, validate content, build `MatchSetup`,
initialize the deterministic core, start action-log recording, route commands,
handle response prompts, detect terminal outcomes, and finalize replay evidence.

> **Quick reference** - Layer: `Feature` - Priority: `MVP` - Key deps: `Deck Construction and Validation`, `Action Log and Replay System`

## Overview

The local match is the first place where Card Combat becomes an actual game
loop instead of isolated rules. This system does not own card behavior, deck
legality, board mutation, response resolution, or replay verification. It owns
the sequence that connects those systems into one local 1v1 session: two valid
players, two valid decks, one deterministic setup, one live simulation core, one
recording action log, one terminal match result, and one replay checkable log.

Current implementation is earlier than this GDD: `MatchSetup` has rule set,
format, seed, player ids, and card data hash, but it does not yet store
per-player validated deck loadouts, ordered deck card ids, opening hands,
draw/deck zones, phase flow, attack declarations, surrender, or terminal win
logic. Those are required before this system can be considered first playable.

## Player Fantasy

Players should feel that a local duel starts cleanly, runs under the same rules
for both sides, and ends with an outcome the game can explain. The emotional
target is "sit down, choose a plan, play a fair duel, and know exactly why it
ended." The player should not feel the orchestration layer directly; they should
feel reliable match start, clear turn handoff, visible response opportunities,
specific rejection reasons, and a result that can be replayed from the log.

## Detailed Design

### Core Rules

1. MVP local match flow supports exactly `LOCAL_MATCH_PLAYER_COUNT = 2` players.
2. A local match uses the `mvp_local` format unless a future format is explicitly
   selected.
3. A local match cannot start from raw deck lists.
4. A local match requires one `ValidatedDeck` per player.
5. Each `ValidatedDeck` must pass `deck_legal`.
6. Both validated decks must use the same `card_data_hash`.
7. Both validated decks must use the same `format_id`.
8. First playable local matches require `prototype_card_pool_ready` unless the
   session is explicitly marked as a smoke/dev exception.
9. The local match request must include:
   - `match_id`
   - `rule_set_version`
   - `format_id`
   - `initial_seed`
   - two unique `player_ids`
   - one validated deck loadout per player
   - the `card_data_hash` used for validation
10. `MatchSetup` must include per-player deck loadouts before draw/deck-zone
    simulation is implemented.
11. A per-player deck loadout must include:
    - `player_id`
    - `deck_id`
    - `deck_fingerprint`
    - ordered `card_ids`
    - optional `declared_archetype_tags`
12. MVP first playable uses ordered deck card ids as deterministic draw order.
13. Seeded shuffle is reserved for a later deterministic RNG pass; it must not
    be implied by `initial_seed` until random stream logging is implemented.
14. Each player draws `STARTING_HAND_SIZE_MVP = 4` cards during opening setup.
15. Mulligan is disabled for MVP local match flow.
16. A player cannot hold more than `MAX_HAND_SIZE_MVP = 10` cards.
17. If a draw would exceed max hand size, the drawn card is discarded to a
    deterministic overflow/discard result once discard zones exist; until then,
    the flow must block hand-size overflow in tests.
18. If a player must draw from an empty deck in MVP, that player loses
    immediately with `deck_empty_loss`.
19. The local match flow initializes `DeterministicSimulationCore` only after
    card data and deck loadouts are validated.
20. The local match flow starts action-log recording before the first accepted
    gameplay command.
21. The action-log header must contain the exact `MatchSetup` facts used to
    initialize the core.
22. Every accepted command returned by the core must be appended to the action
    log with before and after state hashes.
23. Rejected commands remain UI/debug feedback and are not canonical replay
    inputs in MVP.
24. The flow must route player intentions through core commands only. It must
    not mutate `MatchState`, board, hand, deck, response-window, or stack state
    directly.
25. While no response window is open, the active player receives the main action
    prompt for the current phase.
26. While a response window is open, the defender receives only legal response
    and `pass_response` options.
27. Local Match Flow may ask the core for legal actions and disabled reasons,
    but query calls must not mutate state.
28. The MVP main phase allows at most `MAIN_ACTIONS_PER_TURN_MVP = 1` accepted
    proactive main action.
29. The MVP attack phase lets each ready unit attack at most once.
30. Explicit pass commands advance from Main Phase to Attack Phase, from Attack
    Phase to End Phase, and from a response window back to original resolution.
31. A match reaches terminal state when a player life total is 0 or lower,
    a legal surrender command resolves, a player loses by empty deck draw, or a
    deterministic halt occurs.
32. Once terminal state is reached, no further gameplay command can be accepted.
33. Match result must include winner, loser, end reason, final state hash,
    command count, event count, and action-log id.
34. A finalized local match log must be replay-compatible before the first
    playable milestone can claim deterministic completion.
35. Production source must not import prototype match logs or prototype deck
    files directly from `prototypes/`.

### Data Shape

Minimum MVP `LocalMatchRequest` shape:

```text
LocalMatchRequest
  match_id: StringName
  rule_set_version: int
  format_id: StringName
  initial_seed: int
  player_ids: Array[StringName]
  player_loadouts: Array[PlayerDeckLoadout]
  card_data_hash: String
```

Minimum MVP `PlayerDeckLoadout` shape:

```text
PlayerDeckLoadout
  player_id: StringName
  deck_id: StringName
  deck_fingerprint: String
  ordered_card_ids: Array[StringName]
  declared_archetype_tags: Array[StringName]
```

Minimum MVP `LocalMatchResult` shape:

```text
LocalMatchResult
  match_id: StringName
  winner_player_id: StringName optional
  loser_player_id: StringName optional
  end_reason: StringName
  final_state_hash: String
  action_log_id: StringName
  command_count: int
  event_count: int
  replay_verified: bool
```

Required `MatchSetup` extension before first playable:

```text
MatchSetup
  rule_set_version: int
  card_data_hash: String
  player_ids: Array[StringName]
  initial_seed: int
  format_id: StringName
  player_deck_loadouts: Array[PlayerDeckLoadout]
```

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| NoSession | No local match request exists | Player selects local duel | No match state exists |
| SelectingLoadouts | Local duel selected | Two deck loadouts submitted | Players choose decks and ids |
| ValidatingContent | Loadouts submitted | Validation passes or fails | Card data, prototype pool, and decks are checked |
| SetupReady | Validation passes | Core initialization requested | Immutable setup payload is built |
| InitializingCore | `MatchSetup` and `CardDatabase` supplied | Core accepts setup or rejects it | Core state and log header are created |
| OpeningSetup | Core initialized | Opening hands and first turn are ready | Ordered decks produce opening hands |
| MatchActive | Opening setup complete | Terminal condition occurs or match aborts | Flow alternates prompts, commands, response windows, phases, and turns |
| AwaitingMainAction | Active player has priority outside response window | Command accepted, pass submitted, or match ends | Main-speed actions and phase pass are available |
| AwaitingResponse | Response window is open | Defender responds or passes | Defender has response priority only |
| ResolvingCommand | Core accepts a command | Result events and hash captured | Action log appends accepted command entry |
| MatchComplete | Terminal condition reached | Log finalization begins | No gameplay commands accepted |
| LogFinalized | Result and final hash recorded | Replay verification requested | Canonical log is immutable |
| ReplayVerified | Replay matches expected | Report consumed | Local match is proven deterministic |
| MatchFailed | Validation, initialization, replay, or deterministic invariant fails | Player exits or restarts | Failure reason is displayed and logged |

Valid flow:

```text
NoSession -> SelectingLoadouts -> ValidatingContent -> SetupReady
SetupReady -> InitializingCore -> OpeningSetup -> MatchActive
MatchActive -> AwaitingMainAction -> ResolvingCommand -> MatchActive
MatchActive -> AwaitingResponse -> ResolvingCommand -> MatchActive
MatchActive -> MatchComplete -> LogFinalized -> ReplayVerified
ValidatingContent -> MatchFailed
InitializingCore -> MatchFailed
ResolvingCommand -> MatchFailed
LogFinalized -> MatchFailed
```

### Interactions with Other Systems

| System | Data In | Data Out | Ownership Boundary |
|--------|---------|----------|--------------------|
| Card Data Model | Card database and hash | Card compatibility for setup | Card data owns definitions; match flow only requires a validated database |
| Deck Construction and Validation | Player deck lists/loadouts | `ValidatedDeck` and deck fingerprints | Deck validation owns legality; match flow owns pairing decks to players |
| Prototype Card Set and Archetypes | Prototype readiness and sample decks | First-playable content gate | Prototype content owns card readiness; match flow blocks unready first playable sessions |
| Deterministic Simulation Core | `MatchSetup`, commands, card database | Results, snapshots, state hashes, rejection reasons | Core owns match state; match flow only submits commands and reads outputs |
| Turn, Timing, and Resource System | Current phase, priority, resources, focus | Prompt state and pass/advance needs | Timing owns legality; match flow presents the current owner of priority |
| Zone and Lane Board System | Board snapshots, life totals, ready units | Terminal checks and attack prompt context | Board owns lanes/life; match flow reads terminal state only through snapshots/events |
| Stack and Response System | Response-window state and legal response query | Defender prompts and pass routing | Stack owns response state; match flow routes response commands |
| Card Effect Resolution System | Result events and terminal mutations | End-condition evidence | Effects own semantics; match flow consumes outcomes |
| Action Log and Replay System | Setup, accepted commands, events, hashes, final result | Replay compatibility and verification report | Log owns persistence/verifier; match flow starts/stops recording |
| Match Board UI and Input | Prompt state, legal actions, result summary | Player intentions | UI gathers intentions; match flow validates routing through core |
| Determinism Test Harness | Match request fixtures and expected logs | Automated first-playable verification later | Test harness proves flow; match flow provides session contract |
| Match Authority Architecture | Future authority policy | Online wrapping requirements later | Out of MVP local flow; future authority must reuse this setup/command/log contract |

## Formulas

### Match Setup Complete

The `match_setup_complete` formula is defined as:

`match_setup_complete = rule_set_version_supported and format_id_supported and player_count_valid and player_ids_unique and card_data_hash_matches and both_deck_loadouts_present`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| rule_set_version_supported | R | bool | true/false | Runtime supports the requested local rules version |
| format_id_supported | F | bool | true/false | Requested format is supported, MVP starts with `mvp_local` |
| player_count_valid | P | bool | true/false | Player count equals `LOCAL_MATCH_PLAYER_COUNT` |
| player_ids_unique | U | bool | true/false | The two player ids are non-empty and distinct |
| card_data_hash_matches | C | bool | true/false | Setup hash equals the validated `CardDatabase` hash |
| both_deck_loadouts_present | D | bool | true/false | Each player has one validated deck loadout in setup |

**Output Range:** boolean.
**Example:** A setup with two players and a matching card hash still fails if
one player lacks an ordered deck loadout.

### Local Match Start Ready

The `local_match_start_ready` formula is defined as:

`local_match_start_ready = card_data_valid and both_decks_legal and prototype_card_pool_ready and match_setup_complete and action_log_header_ready`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| card_data_valid | C | bool | true/false | Card database validation passed |
| both_decks_legal | D | bool | true/false | Both player decks pass `deck_legal` |
| prototype_card_pool_ready | P | bool | true/false | Prototype card pool meets first-playable readiness gate |
| match_setup_complete | S | bool | true/false | Setup contains all required deterministic inputs |
| action_log_header_ready | L | bool | true/false | Action log header contains setup, format, rule, seed, player, deck, and card hash facts |

**Output Range:** boolean.
**Example:** A smoke test may initialize the core with a partial card pool, but
first playable `local_match_start_ready` is false until the prototype pool and
sample decks are ready.

### Opening Hand Valid

The `opening_hand_valid` formula is defined as:

`opening_hand_valid = all_player_hand_counts_equal_starting_size and all_player_deck_counts_equal_remaining_size`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| all_player_hand_counts_equal_starting_size | H | bool | true/false | Every player starts with `STARTING_HAND_SIZE_MVP` cards in hand |
| all_player_deck_counts_equal_remaining_size | D | bool | true/false | Every player deck has `MVP_LOCAL_DECK_SIZE - STARTING_HAND_SIZE_MVP` cards remaining |

**Output Range:** boolean.
**Example:** With 20-card decks and starting hand size 4, each player should
start with 4 cards in hand and 16 cards in deck.

### Main Action Budget Available

The `main_action_budget_available` formula is defined as:

`main_action_budget_available = main_actions_used_this_turn < MAIN_ACTIONS_PER_TURN_MVP`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| main_actions_used_this_turn | A | int | 0-10 | Count of accepted proactive main actions this turn |
| MAIN_ACTIONS_PER_TURN_MVP | M | int | 1 | MVP proactive main action budget |

**Output Range:** boolean.
**Example:** After Player A plays one main-speed unit in Main Phase, the main
action budget is exhausted and only pass/phase-advance commands remain.

### Local Match Complete

The `local_match_complete` formula is defined as:

`local_match_complete = player_life_zero_or_less or surrender_accepted or deck_empty_loss or deterministic_halt`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| player_life_zero_or_less | L | bool | true/false | At least one player's life total is 0 or lower |
| surrender_accepted | S | bool | true/false | A legal surrender command resolved |
| deck_empty_loss | D | bool | true/false | A player was required to draw from an empty deck |
| deterministic_halt | H | bool | true/false | Core entered a deterministic invariant failure state |

**Output Range:** boolean.
**Example:** If Player B life becomes 0 from an attack, local match flow enters
`MatchComplete` before any further prompts are shown.

### Local Match Replay Ready

The `local_match_replay_ready` formula is defined as:

`local_match_replay_ready = action_log_finalized and final_state_hash_recorded and replay_data_compatible`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| action_log_finalized | L | bool | true/false | Canonical log accepts no further entries |
| final_state_hash_recorded | H | bool | true/false | Final state hash is stored in the result and log footer |
| replay_data_compatible | R | bool | true/false | Rule set, card data hash, and log schema can be replayed by current runtime |

**Output Range:** boolean.
**Example:** A completed match without a final hash is not replay-ready even if
the winner is known.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Player ids are duplicated | Reject setup before core initialization | Player-owned state and logs need distinct owners |
| One player has no validated deck | Reject setup before core initialization | Match flow must not invent a deck |
| Deck is edited after validation | Revalidate and regenerate fingerprint before setup | Prevents stale legal-state bugs |
| The two decks use different card data hashes | Reject setup | A match cannot resolve two meanings for the same card id |
| Prototype pool is not first-playable ready | Block first-playable session; allow explicitly marked smoke/dev exception only | Keeps milestone claims honest |
| `MatchSetup` lacks deck loadouts | Reject first-playable setup | Draw/deck zones cannot be deterministic without them |
| Opening draw would exceed max hand size | Fail setup/test until hand overflow rule is implemented | Avoids silent card loss |
| Player must draw from empty deck | End match with `deck_empty_loss` for drawing player | Deterministic and simple MVP fatigue rule |
| Active player submits a command during response window | Reject through core and keep response prompt active | Stack system owns response priority |
| Defender ignores response prompt | MVP local flow requires explicit `pass_response`; future timers must submit deterministic pass commands | Replay needs visible defender choice |
| Accepted command is not appended to log | Enter `MatchFailed` and halt local session | Replay proof is mandatory |
| Rejected command is appended as canonical input | Reject log validation | MVP replays accepted commands only |
| Core result events indicate terminal state mid-resolution | Finish resolution, record final hash, then enter `MatchComplete` | Avoids losing the decisive event |
| Match reaches `MAX_COMMANDS_PER_MATCH` before terminal state | Halt with deterministic diagnostic result | Prevents runaway local sessions |
| Replay verification fails after match complete | Mark result unverified and surface first mismatch | A visible result is not enough without replay proof |
| User exits local match before completion | Finalize as partial diagnostic log, not a verified match result | Partial logs help debugging but do not prove full match |
| Godot app suspends on mobile in future local play | Pause UI only; core state remains unchanged until a command is submitted | Wall-clock state must not mutate simulation |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|----------------------|
| Card Data Model | This depends on Card Data Model | Needs validated card database and card data hash before setup |
| Deck Construction and Validation | This depends on Deck Construction and Validation | Requires one legal deck loadout per player |
| Prototype Card Set and Archetypes | This depends on Prototype Card Set and Archetypes | Requires first-playable card pool/sample deck readiness |
| Deterministic Simulation Core | This depends on Deterministic Simulation Core | Initializes core and submits all gameplay commands through it |
| Turn, Timing, and Resource System | This depends on Turn, Timing, and Resource System | Reads active player, phase, priority, main resource, and focus prompts |
| Zone and Lane Board System | This depends on Zone and Lane Board System | Reads board snapshots, player life totals, ready units, and terminal life state |
| Stack and Response System | This depends on Stack and Response System | Routes response priority and explicit pass commands |
| Card Effect Resolution System | This depends on Card Effect Resolution System | Consumes resolved events and terminal mutations |
| Action Log and Replay System | This depends on Action Log and Replay System | Starts/stops recording and requires replay verification |
| Match Board UI and Input | Depends on this | Needs prompt state, legal action routing, result summary, and replay status |
| Cross-Platform Interaction Layer | Depends on this indirectly | Must map input methods to the same local command flow |
| Determinism Test Harness | Depends on this | Runs scripted local matches and replay checks |
| AI Training Opponent | Depends on this | Uses local flow as the solo match loop later |
| Match Authority Architecture | Depends on this later | Future authority wraps the same setup, command, and log contract |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `LOCAL_MATCH_PLAYER_COUNT` | 2 | 2 only for MVP | Not applicable until multiplayer formats change | Not applicable below 2 |
| `LOCAL_MATCH_RULE_SET_VERSION` | 1 | 1+ | Enables rule migrations | Not applicable below 1 |
| `STARTING_HAND_SIZE_MVP` | 4 | 3-5 | More opening options and less variance | Faster starts but fewer choices |
| `MAX_HAND_SIZE_MVP` | 10 | 7-10 | More card retention | Less mobile UI pressure |
| `MULLIGAN_ENABLED_MVP` | false | false/true | Better opening smoothing later | Faster first playable |
| `LOCAL_MATCH_USES_ORDERED_DECKS_MVP` | true | true until deterministic shuffle exists | Avoids random-stream dependency | Not applicable |
| `MAIN_ACTIONS_PER_TURN_MVP` | 1 | 1-2 | More active-turn complexity | Keeps turns faster and closer to paper prototype |
| `MAX_LOCAL_MATCH_TURNS_MVP` | 40 | 20-80 | More time for control mirrors | Faster runaway detection |
| `LOCAL_MATCH_REPLAY_REQUIRED` | true | true for MVP | Stronger determinism proof | Not recommended to disable |

## Visual/Audio Requirements

Local Match Flow does not own final VFX or audio, but it defines the match events
that presentation systems must eventually communicate.

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Match setup valid | Start button or local match entry becomes enabled | Optional confirm later | High |
| Match setup invalid | Specific deck/card/setup reason is shown | Soft error optional | High |
| Turn changes | Active player and phase indicator update | Subtle turn tick optional | High |
| Response prompt required | Defender prompt, focus, and pass/respond choices are shown | Prompt sound optional | High |
| Command rejected | Inline reason near attempted action | Soft error optional | High |
| Match complete | Winner, end reason, final hash/replay status available in result view | Victory/defeat stinger later | High |
| Replay verification failed | Debug/result panel shows mismatch reason | Error sound optional in tools | High |

## Game Feel

### Feel Reference

The local match should feel like a clean tabletop duel with a precise digital
judge. Starting a match should be quick, commands should resolve quickly, and
interrupt windows should be obvious without feeling like a separate turn.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|--------|-----------------------------------|-------------------------|-------|
| Validate local match start request | 250ms | N/A | Deck/card validation can run outside frame-critical input |
| Initialize local core from setup | 100ms | 6 frames | Before presentation transition |
| Query current prompt/legal actions | 50ms | 3 frames | On state change or selection |
| Submit local command | 100ms | 6 frames | Pure simulation before animation |
| Append accepted command to in-memory log | 10ms | <1 frame | Local memory target |
| Finalize local result | 250ms | N/A | Includes final hash and log footer |

### Animation Feel Targets

| Animation | Startup Frames | Active Frames | Recovery Frames | Feel Goal | Notes |
|-----------|---------------|--------------|----------------|-----------|-------|
| Match start transition | 0-12 | 20-60 | 0-12 | Fast setup into board | UI owns final animation |
| Turn handoff | 0-6 | 12-30 | 0-6 | Clear active player | Must not obscure board state |
| Match result reveal | 0-12 | 30-90 | 0-12 | Decisive but inspectable | Must show end reason and replay status |

### Impact Moments

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|-------------|--------------|-------------------|---------------|
| Match begins | 300-800 | Decks accepted, board initialized, opening hands ready | Yes |
| Response decision | 100-300 | Prompt shifts priority to defender | Yes |
| Match ends | 500-1500 | Winner/end reason shown after final state hash | Yes |

### Weight and Responsiveness Profile

- **Weight**: Medium; match start/end matter, but core command flow remains fast.
- **Player control**: High; players should always know whether they are choosing
  a main action, response, pass, or viewing a result.
- **Snap quality**: Clear state changes between loadout selection, active play,
  response prompt, and result.
- **Failure texture**: Specific and repairable; setup failures name the deck,
  card data, hash, or missing loadout problem.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|------------------|-----------|
| Selected deck and legality | Local setup/deck selection | On deck selection or validation | Before match start |
| Player ids/sides | Local setup and match board | On setup and match start | Always |
| Start disabled reason | Local setup | On validation failure | Before match start |
| Current match state | Match board shell | On accepted command/result | Match active |
| Active player and phase | Match board header | On phase/turn change | Match active |
| Current prompt owner | Match board prompt area | On priority/window change | Match active |
| Legal actions and disabled reasons | Match board interaction layer | On selection/state change | Player choosing action |
| Response prompt and pass option | Match board response area | On response window open | Defender has priority |
| Action log summary | Debug/log panel initially | After accepted command | Debug/tools or replay |
| Final result and end reason | Result view | On match complete | Match complete |
| Replay verification status | Result/debug view | On replay verification | Match complete/log finalized |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|------------|-----------------------------|--------|
| Legal decks gate match start | `design/gdd/deck-construction-validation.md` | `ValidatedDeck`, `deck_legal`, deck fingerprints | Setup dependency |
| Logs prove the local result | `design/gdd/action-log-replay-system.md` | setup header, accepted command entries, replay compatibility | Persistence dependency |
| Core owns state and command acceptance | `design/gdd/deterministic-simulation-core.md` | `MatchSetup`, `ActionCommand`, `SimulationResult`, state hashes | Runtime boundary |
| Prototype pool gates first playable | `design/gdd/prototype-card-set-archetypes.md` | `prototype_card_pool_ready`, sample deck pair | Content dependency |
| Timing defines prompts | `design/gdd/turn-timing-resource-system.md` | phases, priority, main resource, focus | Rule dependency |
| Stack defines response routing | `design/gdd/stack-response-system.md` | response window and `pass_response` | Rule dependency |
| Board owns life and lanes | `design/gdd/zone-lane-board-system.md` | life totals, ready units, lane state | State dependency |
| Effects produce terminal changes | `design/gdd/card-effect-resolution-system.md` | damage, cancel, fizzle, mutation events | Result dependency |

## Acceptance Criteria

- [ ] **GIVEN** two valid `mvp_local` decks and matching card data hash, **WHEN** a local match request is built, **THEN** `match_setup_complete` is true and `MatchSetup` contains both player deck loadouts.
- [ ] **GIVEN** either player lacks a validated deck, **WHEN** local match start is requested, **THEN** setup is rejected before core initialization.
- [ ] **GIVEN** both decks are legal but their card data hashes differ, **WHEN** local match start is requested, **THEN** setup is rejected with a hash mismatch reason.
- [ ] **GIVEN** first playable mode, **WHEN** `prototype_card_pool_ready` is false, **THEN** the match does not start unless the session is explicitly marked as a smoke/dev exception.
- [ ] **GIVEN** a valid setup, **WHEN** the core initializes, **THEN** action-log recording starts with a header containing rule set version, format id, seed, player ids, deck fingerprints, and card data hash.
- [ ] **GIVEN** two 20-card decks, **WHEN** opening setup resolves, **THEN** each player has 4 cards in hand and 16 cards remaining in deck.
- [ ] **GIVEN** the active player has not used a main action this turn, **WHEN** they play a legal main-speed card, **THEN** the action is routed through the core and the accepted result is appended to the log.
- [ ] **GIVEN** the active player already used one main action this turn, **WHEN** they attempt another proactive main action, **THEN** the action is rejected or unavailable by `MAIN_ACTIONS_PER_TURN_MVP`.
- [ ] **GIVEN** a response window is open, **WHEN** the defender chooses pass, **THEN** local match flow submits `pass_response` and records the accepted result.
- [ ] **GIVEN** a response window is open, **WHEN** the active player submits a non-response command, **THEN** the core rejects it and the canonical action log is unchanged.
- [ ] **GIVEN** a command is accepted by the core, **WHEN** local match flow receives its result, **THEN** the action log entry records command data, result events, state hash before, and state hash after.
- [ ] **GIVEN** a player life total reaches 0 or lower, **WHEN** the resolving command completes, **THEN** the match enters `MatchComplete` with winner, loser, end reason, and final state hash recorded.
- [ ] **GIVEN** a player must draw from an empty deck, **WHEN** the draw step resolves, **THEN** that player loses with end reason `deck_empty_loss`.
- [ ] **GIVEN** a match is complete, **WHEN** any further gameplay command is submitted, **THEN** it is rejected without state mutation.
- [ ] **GIVEN** a finalized local match log, **WHEN** replay verification runs with matching card data, **THEN** final hash, event order, and mismatch count prove or reject `local_match_replay_ready`.
- [ ] Performance: local command submission returns a simulation result within 100ms and in-memory log append completes within 10ms in MVP local play.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|------------|
| Should first playable keep ordered deck draw or introduce seeded shuffle after deterministic random stream logging exists? | Gameplay Programmer / Systems Designer | Before implementing opening draw | Provisional: ordered decks for MVP |
| Should empty deck loss remain immediate or become fatigue damage later? | Systems Designer | After first playable playtest | Provisional: immediate loss |
| Should `MAIN_ACTIONS_PER_TURN_MVP` stay at 1 after the focus-resource prototype iteration? | Systems Designer | Before Match Board UI GDD | Provisional: 1 |
| Should local replay verification run automatically after every completed match or only in debug/test builds? | QA Lead / Gameplay Programmer | Before Determinism Test Harness GDD | Provisional: automatic in tests, visible debug result locally |

---

## Lean Review Notes

Specialist review was not run inline because `production/review-mode.txt` is set
to `lean` and no subagent spawn was explicitly requested. Run `/design-review
design/gdd/local-match-flow.md` in a fresh session before approval.
