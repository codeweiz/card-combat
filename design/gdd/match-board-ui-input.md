# Match Board UI and Input

> **Status**: Designed
> **Author**: Codex
> **Last Updated**: 2026-06-17
> **Last Verified**: 2026-06-17
> **Implements Pillar**: Rules Clarity Beats Hidden Complexity; Cross-Platform First; Deterministic Trust

## Summary

Match Board UI and Input defines the first playable match screen contract: how
players inspect the board, read cards, choose legal actions, select targets,
respond or pass, see rejected-command reasons, and understand the final result.
It is a presentation and input-routing layer over Local Match Flow and the
deterministic core. It never owns gameplay truth and never mutates match state
directly.

> **Quick reference** - Layer: `Presentation` - Priority: `MVP` - Key deps: `Local Match Flow`, `Zone and Lane Board System`

## Overview

The match board is the player-facing surface of the MVP duel. It must make three
lanes, hand cards, player life, resources, response windows, legal targets, and
results readable on PC, Web, and Mobile. It converts player input into local
match intentions, but only Local Match Flow and the deterministic core decide
whether a command is legal or accepted. The screen must support mouse, touch,
keyboard, and later gamepad navigation without hover-only required behavior.

Godot 4.6 separates mouse/touch focus from keyboard/gamepad focus, so this GDD
requires explicit focus states and visual feedback for both pointer and focus
navigation. The UI should be quiet, dense enough for repeated play, and built
for scanning rather than marketing-style presentation.

## Player Fantasy

Players should feel like they are reading a clean duel table. At a glance, they
should know whose turn it is, which lanes matter, what cards can be played, what
the opponent is threatening, and whether they have a response window. The screen
should make clever decisions feel available without making rules feel hidden:
select a card, see legal targets, commit, then watch the verified result.

## Detailed Design

### Core Rules

1. Match Board UI displays the latest authoritative local match snapshot.
2. Match Board UI submits intentions to Local Match Flow; it never writes
   `MatchState`, board state, hand state, stack state, or action logs directly.
3. Every required action must be available with pointer, touch, and keyboard
   focus navigation.
4. Hover may reveal extra detail, but hover must never be the only way to take a
   required action or read a required reason.
5. All visible strings must be localization-key driven or ready to become
   localization keys.
6. UI must use card data fields for name, type, speed, cost, rules text, status,
   tags, art key, frame key, and audio key.
7. UI must use Local Match Flow prompt state to decide whether the active player
   or defender is being asked to act.
8. UI must use core/legal-action query output to enable commands and target
   affordances.
9. UI may display disabled cards and targets only with specific disabled reasons.
10. UI must distinguish main-speed and response-speed cards without requiring
    long rules text.
11. UI must show player life totals, main resources, focus when relevant, deck
    counts, hand counts, active player, current phase, and current prompt owner.
12. UI must show three lanes in stable order: left, center, right.
13. Each lane must show one slot per player.
14. A player must be able to identify unit owner, attack, health, ready state,
    and lane position without opening the action log.
15. The hand must support up to `MAX_HAND_SIZE_MVP = 10` cards without hiding
    required actions.
16. Hand cards may compress visually, but selected/inspected cards must show
    full required rules information.
17. Touch targets for required actions must satisfy `MIN_TOUCH_TARGET_PX = 48`.
18. Cards and buttons must have stable dimensions so hover, focus, and disabled
    states do not resize the layout.
19. Selecting a card enters target preview only when that card requires targets.
20. If an action has exactly one legal target and no ambiguity, UI may preselect
    it but must still show the target before commit on touch devices.
21. Target selection must show legal and illegal lanes/units distinctly.
22. A command commit requires explicit confirmation when the action has a target.
23. Response windows must show:
    - the pending original action,
    - defender focus,
    - legal response cards,
    - disabled response reasons, and
    - an explicit `pass_response` affordance.
24. The pass response affordance must be visible whenever response priority is
    held by the defender.
25. During command resolution animation, UI may lock new input but must not
    change canonical state until the core result arrives.
26. UI state must reconcile to the latest state hash after each accepted command.
27. Rejected commands must preserve the previous authoritative board and hand
    display while showing the rejection reason.
28. The action log strip should show the most recent accepted events in MVP; a
    full replay timeline can wait for later UI replay work.
29. Match result view must show winner, loser, end reason, final state hash, and
    replay verification status when available.
30. Debug hash and event count may be hidden by default but must be available in
    development/debug builds.
31. UI must not import prototype logs, prototype deck files, or production rules
    from `prototypes/`.
32. UI implementation should use Godot `Control` scenes and theme resources,
    not gameplay state stored in visual nodes.
33. UI implementation must account for Godot 4.6 dual-focus behavior: pointer
    hover/press state and keyboard/gamepad focus may be on different controls.
34. The first MVP board screen may use placeholder card art, but card type,
    speed, cost, owner, lane, target, and response information must be readable.

### Screen Regions

| Region | Required Information | Primary Interactions |
|--------|----------------------|----------------------|
| Opponent status | Life, deck count, hand count, focus if responding, active/defender marker | Inspect public state |
| Board lanes | Left/Center/Right lanes, each player's unit slot, attack/health/ready state | Select legal lane/unit targets, inspect units |
| Stack/response prompt | Pending original, defender focus, response/pass choices, cancel/fizzle status | Play response, pass response, inspect pending action |
| Player hand | Up to 10 cards, cost, type, speed, legal/disabled state | Select card, inspect card, begin target selection |
| Player status | Life, main resource, focus when relevant, deck count, active/defender marker | Inspect own state |
| Phase/action bar | Active phase, prompt owner, pass/end/confirm/cancel actions | Pass phase, confirm command, cancel selection |
| Event strip | Recent accepted events and rejection reason | Inspect latest result |
| Result overlay | Winner, loser, end reason, final hash, replay status | Return/retry/replay later |

### MVP Layout Specifications

Desktop/Web landscape target:

| Region | Placement | Size Rule | Notes |
|--------|-----------|-----------|-------|
| Opponent status | Top band | Full width, compact height | Shows opponent life, deck/hand count, active/defender marker |
| Board lanes | Center | Three equal columns; each lane has opponent slot above player slot | Primary tactical focus, stable left/center/right order |
| Stack/response prompt | Right side of board or board-overlay strip | Must not cover selected lane targets | Visible only during response windows or stack resolution |
| Player hand | Bottom band | Up to 10 compressed cards in one row with selected card detail expansion | Required actions remain reachable at max hand size |
| Player status | Bottom-left or lower status strip | Adjacent to hand/resource display | Shows life, main resource, focus when relevant |
| Phase/action bar | Between board and hand | Fixed-height command strip | Pass, confirm, cancel, and phase prompts live here |
| Event strip | Left or lower-left utility strip | Up to `ACTION_LOG_VISIBLE_ROWS_MVP` rows | Debug/test MVP; must not replace board feedback |
| Result overlay | Center overlay after terminal state | Modal-like overlay over frozen final board | Shows end reason, winner/loser, final hash, replay status |

Mobile portrait target:

| Region | Placement | Size Rule | Notes |
|--------|-----------|-----------|-------|
| Opponent status | Top safe-area band | Full width, one compact row | No hover-only detail |
| Board lanes | Upper-middle | Three columns, reduced unit cards, stable lane labels | Must preserve 48px lane/slot targets when targetable |
| Stack/response prompt | Above hand or slide-up prompt | Full width when active | Pass response and legal responses always visible/reachable |
| Player hand | Bottom scroll/compressed row | Up to 10 cards with detail inspect panel | Provisional hand model: compressed row plus detail inspect |
| Player status | Lower safe-area band near hand | Compact resource/life display | Must not clip under safe area |
| Phase/action bar | Sticky above or integrated with hand | Fixed action row | Confirm, cancel, pass remain at least 48px |
| Event strip | Collapsed one-row summary | Expand through log detail action | Avoids stealing board/hand space |
| Result overlay | Full-screen overlay over frozen final board | Scroll if localized text requires | Hash/replay status visible in debug/test builds |

Mobile landscape may use the desktop region order with reduced event strip and
compressed hand cards, provided `touch_target_valid` remains true for all
required controls.

### Input Model

| Input Step | Pointer/Touch | Keyboard/Gamepad | Output |
|------------|---------------|------------------|--------|
| Select card | Click/tap card | Focus card and press confirm | Selected source |
| Inspect card | Long press, detail button, or secondary click where available | Focus card and press inspect | Card detail panel |
| Select target | Tap legal lane/unit/player target | Move focus among legal targets and confirm | Selected target |
| Commit action | Confirm button or second tap on selected legal target | Confirm on commit affordance | Local match intention |
| Cancel selection | Cancel button or tap outside safe cancel region | Back/cancel input | Return to prior prompt |
| Pass phase/window | Tap visible pass affordance | Focus pass affordance and confirm | `pass_*` intention |
| Open log detail | Tap event strip | Focus event strip and confirm | Expanded event detail |

### MVP Focus Route

Focus route groups are stable even when some controls are disabled:

```text
player_hand -> board_lanes -> phase_action_bar -> response_prompt -> event_strip
event_strip -> phase_action_bar -> player_hand
```

Directional focus rules:

| From | Up | Down | Left | Right | Cancel |
|------|----|------|------|-------|--------|
| Player hand card | Board lane same column if available | Phase/action bar | Previous hand card | Next hand card | Clear selection |
| Board lane/unit | Opponent status if inspectable | Player hand or phase/action bar | Previous lane | Next lane | Clear target/source selection |
| Phase/action bar | Board lane or response prompt | Player hand | Previous action | Next action | Clear current selection or return to ViewingBoard |
| Response prompt | Pending original/board highlight | Legal response cards or pass | Previous response control | Next response control | Keep prompt open; clear selected response |
| Event strip | Board lanes | Phase/action bar | Previous event | Next event | Collapse log detail |
| Result overlay | Result controls only | Result controls only | Previous result control | Next result control | No gameplay cancel; result owns exit/retry |

The pass response control, confirm control, cancel control, selected card detail,
and event strip must all be focusable whenever they are visible.

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| LoadingMatch | Local match setup is initializing | Snapshot arrives or setup fails | Disable gameplay input and show loading/validation state |
| SetupInvalid | Local match start failed | Player edits setup or exits | Show specific card/deck/setup reason |
| ViewingBoard | Snapshot is current and no source is selected | Card/unit/action selected or response opens | Normal board inspection |
| SelectingSource | Player focuses/selects a hand card or unit | Source selected, canceled, or prompt changes | Show legal/disabled actions |
| SelectingTarget | Selected action requires target | Target confirmed or selection canceled | Highlight legal and illegal targets |
| ConfirmingAction | Source and targets are selected | Command submitted or canceled | Show exact command summary |
| AwaitingResponse | Response window is open | Response/pass submitted or window closes | Show pending original and defender choices |
| ResolvingCommand | Command accepted and result animation is playing | Authoritative snapshot catches up | Lock new gameplay input |
| RejectedCommand | Core/local flow rejects command | Player acknowledges or selects another action | Show specific rejection reason |
| MatchComplete | Terminal result received | Player exits/restarts/replay later | Show result and replay status |
| ReplayMismatchDebug | Replay verification failed | Player exits/debugs | Show first mismatch summary |

Valid flow:

```text
LoadingMatch -> ViewingBoard
LoadingMatch -> SetupInvalid
ViewingBoard -> SelectingSource -> SelectingTarget -> ConfirmingAction -> ResolvingCommand -> ViewingBoard
ViewingBoard -> AwaitingResponse -> ResolvingCommand -> ViewingBoard
ResolvingCommand -> MatchComplete
ConfirmingAction -> RejectedCommand -> ViewingBoard
MatchComplete -> ReplayMismatchDebug
```

### Interactions with Other Systems

| System | Data In | Data Out | Ownership Boundary |
|--------|---------|----------|--------------------|
| Local Match Flow | Prompt state, legal actions, command results, result summary | Player intentions and selected targets | Local flow owns orchestration; UI owns presentation/input |
| Zone and Lane Board System | Board snapshots, lane ids, unit stats, player life | Lane/slot display and target affordances | Board owns state; UI renders snapshots |
| Card Data Model | Card display fields, speed, type, cost, text keys, tags | Card rendering and filters | Card data owns facts; UI renders them |
| Turn, Timing, and Resource System | Phase, active player, priority, resources, focus | Phase/resource display and disabled reasons | Timing owns legality; UI displays it |
| Stack and Response System | Pending original, response owner, response legal actions | Response prompt and pass affordance | Stack owns response state; UI routes choices |
| Card Effect Resolution System | Effect preview metadata and result events | Target highlights and outcome labels | Effects own semantics; UI displays preview/result |
| Action Log and Replay System | Recent accepted events, mismatch status, final hash | Event strip and result/replay panels | Log owns persistence; UI displays summaries |
| Cross-Platform Interaction Layer | Input device abstraction and focus policy later | Device-specific input actions | Interaction layer owns mappings after designed |
| Tutorial and Rules Explanation | UI anchors for explanations later | Tutorial callouts | Tutorial owns instructional flow |
| Card Frame and Visual Identity System | Frame rules and visual style later | Final card frames | Visual identity owns final art system |
| Accessibility and Focus Navigation | Focus/readout requirements later | Accessible labels and navigation paths | Accessibility system owns full compliance pass |

## Formulas

### Match Board Action Enabled

The `match_board_action_enabled` formula is defined as:

`match_board_action_enabled = local_match_active and actor_has_prompt_priority and action_in_legal_actions and not ui_locked_for_resolution`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| local_match_active | M | bool | true/false | Local match is active and not complete |
| actor_has_prompt_priority | P | bool | true/false | Player currently owns the prompt according to Local Match Flow |
| action_in_legal_actions | A | bool | true/false | Action appears in the current legal-action query |
| ui_locked_for_resolution | L | bool | true/false | UI is waiting for accepted command result/animation reconciliation |

**Output Range:** boolean.
**Example:** A response card is disabled if the defender does not currently have
response priority, even if the card is in hand.

### Target Selection Complete

The `target_selection_complete` formula is defined as:

`target_selection_complete = selected_source_valid and required_target_count_met and all_selected_targets_legal`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| selected_source_valid | S | bool | true/false | Selected card/unit/action is still legal in the latest snapshot |
| required_target_count_met | C | bool | true/false | The action has all required targets selected |
| all_selected_targets_legal | T | bool | true/false | Every selected target appears in the legal target set |

**Output Range:** boolean.
**Example:** `Spark Shot` cannot show commit enabled until a legal unit target
is selected.

### Touch Target Valid

The `touch_target_valid` formula is defined as:

`touch_target_valid = target_width_px >= MIN_TOUCH_TARGET_PX and target_height_px >= MIN_TOUCH_TARGET_PX`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| target_width_px | W | int | 0-4096 | Rendered width of required interactive target |
| target_height_px | H | int | 0-4096 | Rendered height of required interactive target |
| MIN_TOUCH_TARGET_PX | M | int | 48 | Minimum MVP touch target dimension |

**Output Range:** boolean.
**Example:** A pass response button rendered at 44 by 48 pixels fails because
width is below the minimum.

### Response Prompt Complete

The `response_prompt_complete` formula is defined as:

`response_prompt_complete = pending_original_visible and defender_focus_visible and legal_response_options_visible and pass_response_visible`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| pending_original_visible | O | bool | true/false | The original action that opened the window is visible |
| defender_focus_visible | F | bool | true/false | Defender focus is shown while response priority is held |
| legal_response_options_visible | R | bool | true/false | Legal response cards/options are visible or reachable |
| pass_response_visible | P | bool | true/false | Explicit pass response affordance is visible/reachable |

**Output Range:** boolean.
**Example:** A prompt with legal response cards but no pass button is incomplete
because MVP replay requires explicit response pass.

### UI State Synced

The `ui_state_synced` formula is defined as:

`ui_state_synced = displayed_state_hash == latest_state_hash and pending_authoritative_update_count == 0`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| displayed_state_hash | D | hash | any state hash | Hash of the snapshot currently displayed by UI |
| latest_state_hash | L | hash | any state hash | Latest authoritative state hash from Local Match Flow/core |
| pending_authoritative_update_count | P | int | 0-100 | Count of accepted result updates not yet reflected in UI state |

**Output Range:** boolean.
**Example:** If animation is still showing an old board after a command result,
`ui_state_synced` is false until display catches up to the latest snapshot.

### Card Text Fits MVP

The `card_text_fits_mvp` formula is defined as:

`card_text_fits_mvp = rules_text_line_count <= MAX_CARD_TEXT_LINES_MVP and localized_text_not_overflowing`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| rules_text_line_count | L | int | 0-20 | Rendered rules text line count in MVP card frame |
| MAX_CARD_TEXT_LINES_MVP | M | int | 4 | Maximum compact card rules text lines for MVP |
| localized_text_not_overflowing | O | bool | true/false | Rendered localized text fits within its container |

**Output Range:** boolean.
**Example:** A response card with five compact text lines must use detail view or
shorter text before it is acceptable for MVP card display.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| UI has a stale state hash when player confirms | Submit with expected hash; core rejects on mismatch and UI refreshes | Prevents stale commands from mutating state |
| Legal action disappears during target selection | Cancel selection and show state changed reason | Latest authoritative state controls legality |
| Player taps an illegal lane | Do not submit command; show disabled lane reason | Avoids noisy rejected commands |
| Player double-taps command confirm | Submit at most one command id; second input is ignored or rejected as duplicate | Prevents double-submit ambiguity |
| Response window opens while a card is selected | Clear previous selection and enter response prompt | Prompt priority changed |
| Defender has no legal response cards | Show pass response as the primary available action | Player must still make explicit pass |
| Touch layout cannot show all hand cards at full size | Compress hand cards while preserving selectable targets and detail view | Max hand size must fit mobile |
| Card text overflows in compact view | Truncate only with a visible detail affordance; do not hide required rules in detail view | Rules clarity beats decoration |
| Keyboard focus and mouse hover point to different controls | Show both states distinctly and commit only from explicit confirm | Godot 4.6 dual-focus behavior |
| Match result arrives during animation | Finish or skip animation, then show terminal result and block further commands | Terminal state wins over presentation |
| Replay verification fails after result | Keep result visible but mark replay unverified with first mismatch summary | Outcome display and determinism proof are separate |
| Mobile orientation changes later | Re-layout from latest authoritative snapshot, not from visual node state | UI must not own gameplay state |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|----------------------|
| Local Match Flow | This depends on Local Match Flow | Receives prompt state, legal actions, command results, result summaries |
| Zone and Lane Board System | This depends on Zone and Lane Board System | Renders lane order, units, life totals, ready state, and targets |
| Card Data Model | This depends on Card Data Model | Displays card text, type, speed, cost, tags, art/frame/audio keys |
| Turn, Timing, and Resource System | This depends on Turn, Timing, and Resource System | Displays active player, phase, main resource, focus, and disabled timing reasons |
| Stack and Response System | This depends on Stack and Response System | Displays pending original, response priority, legal response cards, and pass |
| Card Effect Resolution System | This depends on Card Effect Resolution System | Displays previews, outcomes, cancel/fizzle/damage/move labels |
| Action Log and Replay System | This depends on Action Log and Replay System | Displays recent events, result hashes, replay verification status |
| Cross-Platform Interaction Layer | Depends on this | Generalizes device mappings after board interactions are defined |
| Tutorial and Rules Explanation | Depends on this | Anchors tutorial prompts to board, hand, response, and result regions |
| Card Frame and Visual Identity System | Depends on this | Supplies final card visual treatment later |
| Localization and Text Layout | Depends on this | Validates all visible text and card layout in supported locales |
| Accessibility and Focus Navigation | Depends on this | Formalizes focus/readout paths and non-pointer operation |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `MIN_TOUCH_TARGET_PX` | 48 | 44-64 | Easier mobile tapping, more layout pressure | Denser UI, higher mis-tap risk |
| `MAX_CARD_TEXT_LINES_MVP` | 4 | 3-6 | More text visible on card | Smaller text or larger cards |
| `HAND_CARD_VISIBLE_COUNT_MVP` | 10 | 7-10 | Supports max hand without paging | Easier large-card presentation |
| `ACTION_LOG_VISIBLE_ROWS_MVP` | 3 | 0-6 | More recent context | Less board/hand space |
| `MATCH_BOARD_DRAW_CALL_BUDGET` | 150 | 100-200 | More visual richness | Better Web/Mobile performance margin |
| `UI_STATE_SYNC_BUDGET_MS` | 100 | 50-200 | More animation tolerance | Snappier but less forgiving |
| `LEGAL_ACTION_QUERY_UI_BUDGET_MS` | 50 | 16-100 | More complex previews | Faster interaction budget |
| `SELECT_CONFIRM_REQUIRED_MVP` | true | true/false | Prevents accidental targeted actions | Faster expert play if false later |
| `TARGET_PREVIEW_REQUIRED` | true | true/false | Stronger rules clarity | Fewer interaction steps |

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Match loaded | Board regions appear with current player sides and lanes | Optional soft start later | High |
| Card selectable | Card shows enabled state and speed/cost affordance | None | High |
| Card disabled | Card shows disabled state and specific reason on inspect/focus | Optional soft error later | High |
| Legal target preview | Legal lanes/units/players highlight; illegal targets remain distinguishable | None | High |
| Response window opens | Pending original and defender response panel are emphasized | Prompt sound optional later | High |
| Pass response | Pass affordance visibly resolves/clears prompt | Subtle dismiss optional later | Medium |
| Command rejected | Brief reason and unchanged board state | Soft error optional later | High |
| Match complete | Result overlay with end reason, final hash, replay status | Result stinger later | High |
| Replay mismatch | Debug/result panel marks first mismatch | Tool error optional later | Medium |

Asset spec note: visual/audio requirements here are interaction-level only. The
final card frame, VFX, and audio asset list should be produced after the art
bible and card-frame system exist.

## Game Feel

### Feel Reference

The match board should feel like a compact competitive card table: quick to
scan, precise under touch, and direct about legal choices. It should avoid
large decorative panels that compete with lanes, hand cards, or response prompts.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|--------|-----------------------------------|-------------------------|-------|
| Select card or unit | 50ms | 3 frames | Highlight and detail update |
| Show legal targets | 50ms | 3 frames | Uses legal target query/cache |
| Submit command | 100ms | 6 frames | Pure simulation result before animation |
| Show rejection reason | 50ms | 3 frames | Required for rules clarity |
| Reconcile accepted snapshot | 100ms | 6 frames | UI catches up to latest state hash |

### Animation Feel Targets

| Animation | Startup Frames | Active Frames | Recovery Frames | Feel Goal | Notes |
|-----------|---------------|--------------|----------------|-----------|-------|
| Card select lift/focus | 0-4 | Until selection changes | 0-4 | Clear source, no layout shift | Stable card dimensions |
| Target highlight | 0-4 | Until confirm/cancel | 0-4 | Fast legality read | Must work without hover |
| Response prompt entrance | 0-6 | Until respond/pass | 0-6 | Priority shift is obvious | Must not hide board |
| Result overlay | 0-12 | Until dismissed | 0-12 | Decisive and inspectable | Must show end reason |

### Impact Moments

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|-------------|--------------|-------------------|---------------|
| Legal action preview | 50-150 | Card/target relation becomes clear | Yes |
| Response opportunity | 100-300 | Prompt directs attention to defender choice | Yes |
| Match result | 500-1500 | Result displayed after final state update | Yes |

### Weight and Responsiveness Profile

- **Weight**: Medium-light; the board carries tactical weight but should stay
  fast and utilitarian.
- **Player control**: High; required actions are explicit and reversible until
  commit.
- **Snap quality**: Crisp; legal/illegal, selected/unselected, focused/hovered,
  responding/passing states are visually distinct.
- **Failure texture**: Specific; invalid actions explain phase, target, focus,
  ownership, or stale-state causes.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|------------------|-----------|
| Active player | Header/phase bar | On turn/phase change | Match active |
| Current phase | Header/phase bar | On phase change | Match active |
| Prompt owner | Action/response area | On prompt change | Match active |
| Player life | Player status regions | On life change | Always |
| Main resource | Player status/hand area | On refresh/spend | Match active |
| Focus | Response area/status | During opponent turn/response | Focus relevant |
| Deck/hand counts | Player status regions | On draw/discard/hand change | Match active |
| Three lanes | Board center | Static order | Always |
| Unit attack/health/ready | Unit slot/card | On unit state change | Unit exists |
| Hand cards | Player hand area | On hand change | Local player visible hand |
| Card detail | Detail panel/inspect overlay | On inspect/selection | Card selected/focused |
| Legal targets | Board and player targets | On source selection | Action needs target |
| Disabled reasons | Card/target detail or inline reason | On inspect/invalid attempt | Action unavailable |
| Pending original action | Response prompt/stack strip | On response window open | Response priority |
| Pass response | Response prompt | While response window open | Defender priority |
| Recent events | Event strip | After accepted command | Debug/MVP event context |
| Final result | Result overlay | On match complete | Terminal state |
| Replay status | Result/debug overlay | On verification result | Log finalized |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|------------|-----------------------------|--------|
| Prompt state and result summary | `design/gdd/local-match-flow.md` | legal actions, prompt owner, result, replay status | Flow dependency |
| Lane display and unit state | `design/gdd/zone-lane-board-system.md` | lane order, slots, life totals, ready units | State dependency |
| Card display facts | `design/gdd/card-data-model.md` | name/text keys, speed, type, cost, tags | Data dependency |
| Phase/resource/focus display | `design/gdd/turn-timing-resource-system.md` | phase, active player, main resource, focus | Rule dependency |
| Response prompt | `design/gdd/stack-response-system.md` | pending original, response owner, pass | Rule dependency |
| Effect previews and outcome labels | `design/gdd/card-effect-resolution-system.md` | damage, heal, move, cancel, fizzle | Feedback dependency |
| Event strip and replay status | `design/gdd/action-log-replay-system.md` | accepted events, final hash, mismatch | Persistence dependency |

## Acceptance Criteria

- [ ] **GIVEN** a local match snapshot, **WHEN** the match board renders, **THEN** players can see active player, phase, life totals, resources, hand/deck counts, and all three lanes.
- [ ] **GIVEN** a unit exists in a lane, **WHEN** the board renders, **THEN** owner, attack, health, ready state, and lane are visible without opening the log.
- [ ] **GIVEN** a hand card is not legal, **WHEN** the player focuses or inspects it, **THEN** the UI shows a specific disabled reason.
- [ ] **GIVEN** a legal targeted card is selected, **WHEN** target selection begins, **THEN** legal targets and illegal targets are visually distinct.
- [ ] **GIVEN** a required touch action, **WHEN** layout is measured, **THEN** its interactive target satisfies `touch_target_valid`.
- [ ] **GIVEN** a response window opens, **WHEN** the defender receives priority, **THEN** pending original, focus, legal response options, disabled response reasons, and pass response are visible.
- [ ] **GIVEN** the defender has no legal response card, **WHEN** a response window opens, **THEN** pass response remains visible and reachable.
- [ ] **GIVEN** keyboard/gamepad navigation, **WHEN** the player moves focus across cards, lanes, response controls, and pass/confirm/cancel, **THEN** every required action is reachable without pointer input.
- [ ] **GIVEN** pointer hover and keyboard focus are on different controls in Godot 4.6, **WHEN** the UI renders both states, **THEN** the commit source is still determined only by explicit confirm.
- [ ] **GIVEN** a command is rejected, **WHEN** the UI displays feedback, **THEN** the authoritative board state remains unchanged and the reason is shown within 50ms.
- [ ] **GIVEN** an accepted command result, **WHEN** the UI finishes reconciliation, **THEN** `ui_state_synced` is true for the latest state hash.
- [ ] **GIVEN** a match completes, **WHEN** the result overlay appears, **THEN** it shows winner, loser, end reason, final hash, and replay status when available.
- [ ] Performance: selection and legal target display respond within 50ms, command submission feedback begins within 100ms, and match board draw calls stay under `MATCH_BOARD_DRAW_CALL_BUDGET` before final art.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|------------|
| Which card frame visual treatment distinguishes main and response speed before final art bible? | UI Designer / Art Director | Before card frame system | Provisional: placeholder badge and frame accent |

---

## Lean Review Notes

Specialist review was not run inline because `production/review-mode.txt` is set
to `lean` and no subagent spawn was explicitly requested. Run `/design-review
design/gdd/match-board-ui-input.md` in a fresh session before approval.
