# Stack and Response System

> **Status**: Designed
> **Author**: Codex
> **Last Updated**: 2026-06-17
> **Last Verified**: 2026-06-17
> **Implements Pillar**: Rules Clarity Beats Hidden Complexity; Deterministic Trust; Cross-Platform First

## Summary

The Stack and Response System owns MVP response windows, pending action order, defender response priority, pass handling, and stack resolution. It turns lane-plus-stack timing into a constrained, inspectable rule: one eligible action may open one response window, the defending player may play at most one response card or pass, then the response resolves before the original action if the original action remains legal.

> **Quick reference** - Layer: `Core` · Priority: `MVP` · Key deps: `Turn, Timing, and Resource System`

## Overview

Card Combat needs interactive timing without letting every action become a long, opaque chain. This system defines the minimal stack model for MVP: eligible main actions and attack declarations can pause as pending original actions; the non-active player receives a clear response window; one response card may be submitted; and resolution proceeds in deterministic order. Players feel the system directly when they decide whether to spend limited `focus` to interrupt a key play, but the system remains narrow enough for mobile and Web readability.

## Player Fantasy

Players should feel like they can set a trap, protect a key unit, or blunt a lethal line at exactly the right moment. The fantasy is not "answer everything"; it is "I saw the decisive window and used my one response well." The opponent should still feel that their proactive turn matters because the defender has a constrained response budget and cannot create an endless chain.

## Detailed Design

### Core Rules

1. MVP stack play occurs only inside response windows opened by eligible actions.
2. Eligible MVP response-window triggers are:
   - a unit placement that can affect board pressure
   - a spell or effect that targets a unit, lane, or player
   - an attack declaration
3. Pure phase transitions, draws, resource refreshes, and pass commands do not open response windows.
4. A response window belongs to exactly one original action.
5. The original action is recorded as pending before it mutates the affected gameplay state.
6. While a response window is open, the defending player has response priority.
7. The active player does not receive response priority in MVP.
8. The defending player may submit exactly one response-speed command or a `pass_response` command.
9. `MAX_RESPONSES_PER_WINDOW_MVP` is 1 and is inherited from the Turn, Timing, and Resource System.
10. Response-speed cards require an open response window.
11. Main-speed cards cannot be submitted during a response window.
12. A response command must satisfy timing, speed, target, and focus affordability before it is accepted.
13. A passed response window closes without adding a response stack item.
14. A response card is added above the original action as the top stack item.
15. MVP stack depth is at most 2 items: one original action plus one response.
16. Responses resolve before the original action.
17. After a response resolves, the original action must re-check current legality before resolving.
18. If the original action's target is gone, invalid, protected from that action, or explicitly canceled, the original action fizzles or is canceled according to its effect rule.
19. A canceled or fizzled original action remains in the action log with its final resolution reason.
20. Rejected response commands do not close the response window and do not mutate match state.
21. A response window closes only when the defender submits a legal response, submits `pass_response`, the match ends, or a deterministic safety halt occurs.
22. If a response resolves and ends the match, the original action does not resolve.
23. The stack must be serialized in deterministic order.
24. Querying whether a response is legal must not mutate state.
25. The UI may display pending stack state, legal response cards, focus cost, and pass affordance, but may not write stack state directly.
26. Production source must not import prototype stack rules from `prototypes/`.

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| NoWindow | No pending response window exists | Eligible action is accepted as pending | Normal main/attack timing rules apply |
| OriginalPending | Eligible original action is recorded and waiting for defender choice | Defender responds or passes | Original action has not yet applied affected gameplay mutation |
| ResponsePending | Defender response command is accepted | Response finishes resolving | Response sits above original action |
| ResolvingResponse | ResponsePending begins resolution | Response mutation completes or match ends | Applies response effect first |
| RecheckingOriginal | Response has resolved or defender passed | Original is legal, canceled, fizzled, or match ends | Re-validates original target/current legality |
| ResolvingOriginal | Original action remains legal | Original mutation completes | Applies original action effects |
| WindowClosed | Response and/or original resolution is complete | Return to prior phase/attack flow | Clears transient stack state |
| StackHalted | Invariant or safety cap fails | Debug reset/replay abort | Stops mutation and emits diagnostic output |

Valid flow:

```text
NoWindow -> OriginalPending
OriginalPending -> ResponsePending -> ResolvingResponse -> RecheckingOriginal
OriginalPending -> RecheckingOriginal              # defender passes
RecheckingOriginal -> ResolvingOriginal -> WindowClosed -> NoWindow
RecheckingOriginal -> WindowClosed                 # original canceled or fizzled
Any stack state -> WindowClosed                    # match complete
Any stack state -> StackHalted                     # deterministic invariant failure
```

### Interactions with Other Systems

| System | Data In | Data Out | Ownership Boundary |
|--------|---------|----------|--------------------|
| Deterministic Simulation Core | Submitted commands, current match state, state hashes | Accepted/rejected stack commands, canonical stack state, resolution events | Core applies deterministic transition order; stack owns pending-window invariants |
| Turn, Timing, and Resource System | Current phase, active player, defender, focus, timing legality | Response priority, response-window close events, focus spend requests | Timing owns priority/resource legality; stack owns pending item order |
| Card Data Model | Card `speed`, `base_cost`, type, target profile, effect refs | Response card eligibility and stack item metadata | Card data owns static definitions; stack reads timing-relevant fields |
| Zone and Lane Board System | Current lane/unit/player targets | Original action recheck after response | Board owns spatial legality; stack asks board whether pending targets remain legal |
| Card Effect Resolution System | Effect payloads for original and response items | Mutation results, cancel/fizzle reasons, gameplay events | Effect system owns item semantics; stack owns resolution order |
| Action Log and Replay System | Accepted original, pass, and response commands | Replayable stack sequence and per-item outcomes | Replay owns persistence; stack exposes canonical item order and outcomes |
| Match Board UI and Input | Pending stack snapshot and legal response query | Response prompt, pass button, disabled reasons | UI displays and submits intentions; stack validates and mutates only through core |

## Formulas

### Response Window Opens

The `response_window_opens` formula is defined as:

`response_window_opens = eligible_trigger and defender_exists and match_not_complete and no_response_window_open`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| eligible_trigger | E | bool | true/false | The original action is a unit placement, targeted spell/effect, or attack declaration that can be responded to |
| defender_exists | D | bool | true/false | A valid non-active player exists for this turn |
| match_not_complete | M | bool | true/false | The match has not reached a terminal result |
| no_response_window_open | W | bool | true/false | There is no existing response window or stack resolution in progress |

**Output Range:** boolean.
**Example:** A main-speed damage spell targeting a unit opens a response window if the defender exists, the match is still active, and no other response window is already open.

### Response Command Valid

The `response_command_valid` formula is defined as:

`response_command_valid = response_window_open and actor_is_defender and card_speed_is_response and focus_can_pay and responses_used_in_window < MAX_RESPONSES_PER_WINDOW_MVP`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| response_window_open | W | bool | true/false | A response window currently exists |
| actor_is_defender | A | bool | true/false | Command actor is the defending player with response priority |
| card_speed_is_response | S | bool | true/false | Submitted card uses `response` speed |
| focus_can_pay | F | bool | true/false | Defender has enough focus for the response cost |
| responses_used_in_window | R | int | 0-1 MVP | Number of accepted responses already used in this window |
| MAX_RESPONSES_PER_WINDOW_MVP | C | int | 1 | MVP cap owned by Turn, Timing, and Resource System |

**Output Range:** boolean.
**Example:** If Player B has an open response window, 2 focus, and plays a 1-focus response card before any response was used, the command is valid if target rules also pass.

### Stack Resolution Order

The `stack_resolution_order` formula is defined as:

`stack_resolution_order = response_item_then_original_item`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| response_item | R | stack item or null | 0-1 item | Accepted defending-player response, if any |
| original_item | O | stack item | exactly 1 item | Pending original action that opened the response window |
| response_item_then_original_item | RO | ordered list | 1-2 items | Response first when present, original second if still legal |

**Output Range:** ordered list with 1 to 2 stack items in MVP.
**Example:** `Counter Sigil` resolves before `Spark Shot`; if `Counter Sigil` cancels the spell, `Spark Shot` is logged as canceled and does not deal damage.

### Original Action Still Legal

The `original_action_still_legal` formula is defined as:

`original_action_still_legal = original_exists and not original_canceled and current_targets_legal and match_not_complete`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| original_exists | O | bool | true/false | The pending original stack item still exists |
| original_canceled | C | bool | true/false | A response or rule has canceled the original |
| current_targets_legal | T | bool | true/false | Current board/player/zone state still satisfies the original target profile |
| match_not_complete | M | bool | true/false | Response resolution did not end the match |

**Output Range:** boolean.
**Example:** If a response moves the targeted unit to a lane where the spell can no longer target it, the original action fizzles unless that effect explicitly allows retargeting.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Original action is not an eligible trigger | Resolve it immediately through normal timing; do not open a response window | Avoids prompts for routine actions |
| Active player tries to respond to the defender response | Reject command without mutation | MVP has no counter-response chain |
| Defender tries a main-speed card during ResponseWindow | Reject with timing reason; window remains open | Keeps proactive and reactive speeds distinct |
| Defender lacks focus for all response cards | Window may still open, but legal response query returns only `pass_response` | Player sees the timing moment without illegal card affordances |
| Defender submits invalid response target | Reject without closing the window | Mis-targeting should not consume the response opportunity |
| Defender passes | Close the window and recheck/resolve the original action | Passing is an explicit deterministic command for replay clarity |
| Response cancels original | Log response resolved, log original canceled, clear stack | Canceled actions must remain replayable |
| Response moves or destroys original target | Recheck target legality; fizzle original if target is no longer legal | Current state after response governs original resolution |
| Response ends the match | Enter Complete state and skip original resolution | Terminal outcomes should not continue resolving stale actions |
| Original action becomes illegal for cost reasons after response | Do not refund/recharge based on response effects unless effect text says so; legality recheck focuses on current target and cancel state | Cost was paid on accepted original declaration |
| Rejected response command arrives with stale expected hash | Reject with state hash mismatch; window remains unchanged | Preserves desync diagnostics |
| Duplicate response command id is submitted | Reject without mutation | Prevents double-submit and replay ambiguity |
| Response window exists when another eligible action tries to open one | Enter invariant failure or reject nested window depending on implementation mode | MVP forbids nested windows |
| Action has multiple targets and one becomes illegal | Effect rule defines all-or-nothing, partial, or retarget behavior; default MVP behavior is fizzle all if any required target is illegal | Prevents hidden partial resolution |
| UI timer expires in future timed mode | Submit deterministic `pass_response` through match authority | Wall-clock timeout policy belongs to match flow/authority, not stack rules |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|----------------------|
| Deterministic Simulation Core | This depends on Deterministic Simulation Core | Stack commands must enter through deterministic command submission and state hashing |
| Turn, Timing, and Resource System | This depends on Turn, Timing, and Resource System | Uses response priority, focus, speed legality, and `MAX_RESPONSES_PER_WINDOW_MVP` |
| Card Data Model | This depends on Card Data Model | Reads card speed, cost, target profile, and effect refs |
| Zone and Lane Board System | This depends on Zone and Lane Board System | Rechecks board targets and lane legality after responses |
| Card Effect Resolution System | Depends on this | Resolves stack items in the order this system defines |
| Action Log and Replay System | Depends on this | Persists original, response, pass, cancel, fizzle, and final stack outcomes |
| Match Board UI and Input | Depends on this | Displays response prompt, pending action, legal response choices, focus cost, and pass |
| Match Authority Architecture | Depends on this later | Future online authority must validate response priority and timeout-pass behavior |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `MAX_RESPONSES_PER_WINDOW_MVP` | 1 | 1 only for MVP | Longer chains and more interaction, but much higher readability risk | Not applicable below 1 if responses exist |
| `RESPONSE_STACK_MAX_DEPTH_MVP` | 2 | 1-2 for MVP | Allows one response above original | 1 disables response cards |
| `OPEN_WINDOW_ON_UNIT_PLACEMENT` | true | true/false | More chances to respond to board development | Faster play, fewer defensive tools |
| `OPEN_WINDOW_ON_TARGETED_SPELL` | true | true/false | Lets defensive responses protect key targets | Makes removal more reliable |
| `OPEN_WINDOW_ON_ATTACK_DECLARATION` | true | true/false | Enables combat tricks and movement responses | Faster attack phase |
| `RESPONSE_PASS_REQUIRED` | true | true/false | Replay logs explicit defender choice | Faster UI if auto-pass exists, but less inspectable |
| `DEFAULT_MULTI_TARGET_FIZZLE_MODE` | all_required_targets | all_required_targets / per_target | More predictable all-or-nothing resolution | More granular but harder to explain |

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Response window opens | Pending original action is highlighted; defender sees response prompt and focus | Subtle alert optional | High |
| Response card selected | Response card previews above pending original | Soft selection sound later | High |
| Defender passes | Prompt closes with a clear pass state | Subtle dismiss sound optional | Medium |
| Response resolves | Response card/effect resolves before original | Card response stinger later | High |
| Original canceled/fizzled | Original action receives canceled/fizzled label before clearing | Soft cancel sound optional | High |
| Original resolves | Original action proceeds after response check | Owned by effect/board presentation | High |

## Game Feel

### Feel Reference

The response moment should feel like a clean counter-window, not a rules negotiation. Players should instantly see the pending original action, whether they have focus, which response cards are legal, and what pass will do.

### Input Responsiveness

| Action | Max Input-to-Response Latency (ms) | Frame Budget (at 60fps) | Notes |
|--------|-----------------------------------|-------------------------|-------|
| Open response window prompt | 100ms | 6 frames | After original action declaration |
| Query legal response cards | 50ms | 3 frames | On window open and hand changes |
| Submit response/pass | 100ms | 6 frames | Pure simulation before presentation animation |
| Recheck original legality | 50ms | 3 frames | After response resolution |

### Animation Feel Targets

| Animation | Startup Frames | Active Frames | Recovery Frames | Feel Goal | Notes |
|-----------|---------------|--------------|----------------|-----------|-------|
| Pending original lift/highlight | 0-6 | Until response choice | 0-6 | Clear but not blocking | Must fit mobile board |
| Response card enters stack | 0-6 | 8-18 | 0-6 | Fast interrupt cue | Avoid long chain theatre |
| Canceled/fizzled label | 0-6 | 12-24 | 0-6 | Unambiguous ruling | Must not hide board state |

### Impact Moments

| Impact Type | Duration (ms) | Effect Description | Configurable? |
|-------------|--------------|-------------------|---------------|
| Response opportunity | 100-300 | Prompt and pending-action emphasis | Yes |
| Response commit | 100-250 | Response card/effect takes priority | Yes |
| Cancel/fizzle ruling | 150-300 | Pending original visibly fails to resolve | Yes |

### Weight and Responsiveness Profile

- **Weight**: Medium; the window should feel important, but not like a separate turn.
- **Player control**: High for the defender during the window, bounded by one response and focus.
- **Snap quality**: Categorical; each stack item is pending, resolving, canceled, fizzled, or resolved.
- **Acceleration model**: Prompt immediately, resolve quickly after response/pass.
- **Failure texture**: Judicial and readable; canceled/fizzled actions show why.

### Feel Acceptance Criteria

- [ ] Players can identify the pending original action without reading the log.
- [ ] Players can tell whether they are responding or passing.
- [ ] Players understand why the original action resolved, fizzled, or was canceled.
- [ ] No MVP response sequence requires tracking more than one response card.

## UI Requirements

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|------------------|-----------|
| Pending original action | Stack/response prompt or board highlight | On response window open/close | Response window open |
| Response priority owner | Response prompt | On window open | Response window open |
| Defender focus | Response prompt/resource display | On focus refresh/spend | Response window or opponent turn |
| Legal response cards | Hand/card affordances | On window open and state changes | Defender has priority |
| `pass_response` affordance | Response prompt | While window open | Always during response window |
| Response count used | Debug/log UI initially | On response accepted | Window open or replay |
| Resolution status | Action log and board labels | On item resolve/cancel/fizzle | Stack item resolves |
| Disabled response reason | Card tooltip/inline reason | On invalid attempt or card inspect | Defender has priority |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|------------|-----------------------------|--------|
| Commands and hashes are owned by core | `design/gdd/deterministic-simulation-core.md` | command validation and canonical state hash | Implementation boundary |
| Response focus and priority are owned by timing | `design/gdd/turn-timing-resource-system.md` | `focus`, response window, `MAX_RESPONSES_PER_WINDOW_MVP` | Rule dependency |
| Card speed and effect refs come from data | `design/gdd/card-data-model.md` | `speed`, `base_cost`, `targeting_profile_id`, `effect_refs` | Data dependency |
| Lane targets are rechecked after responses | `design/gdd/zone-lane-board-system.md` | lane occupancy and unit existence | State dependency |
| Effect semantics resolve stack items | `design/gdd/card-effect-resolution-system.md` | effect resolution and cancel/fizzle semantics | Ownership handoff |
| Replays persist stack outcomes | `design/gdd/action-log-replay-system.md` | ordered actions and outcome reasons | Persistence dependency |

## Acceptance Criteria

- [ ] **GIVEN** an eligible original action is accepted, **WHEN** it would mutate affected gameplay state, **THEN** it is first recorded as pending and a response window opens.
- [ ] **GIVEN** a response window is open, **WHEN** the defender submits a legal response-speed card with enough focus, **THEN** the response is accepted as the top stack item and resolves before the original.
- [ ] **GIVEN** a response window is open, **WHEN** the defender submits `pass_response`, **THEN** the window closes and the original action rechecks legality before resolving.
- [ ] **GIVEN** a response window is open, **WHEN** the active player submits a response card, **THEN** the command is rejected without state mutation.
- [ ] **GIVEN** the defender already used one response in a window, **WHEN** another response is submitted in the same window, **THEN** it is rejected by `MAX_RESPONSES_PER_WINDOW_MVP`.
- [ ] **GIVEN** a response cancels the original action, **WHEN** stack resolution reaches the original, **THEN** the original is logged as canceled and does not apply its effect.
- [ ] **GIVEN** a response removes or moves the original target, **WHEN** the original rechecks legality, **THEN** it fizzles if its required target is no longer legal.
- [ ] **GIVEN** a response ends the match, **WHEN** stack resolution would continue, **THEN** remaining pending original resolution is skipped.
- [ ] **GIVEN** an invalid response command is rejected, **WHEN** state hash is compared before and after, **THEN** the hash is unchanged and the window remains open.
- [ ] **GIVEN** the same original/response/pass sequence is replayed, **WHEN** replay completes, **THEN** stack item order, outcome reasons, and final state hash match the original run.
- [ ] Performance: legal response query returns within 50ms and response/pass submission returns a simulation result within 100ms in local MVP.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|------------|
| Should unit placement always open a response window, or only when a response card in hand can affect it? | Systems Designer / UX Designer | Before Match Board UI GDD | Provisional: always open for eligible triggers; UI may auto-pass only through deterministic command later |
| Should MVP support response cards that cancel attacks, or only spells/effects? | Systems Designer | Before Prototype Card Set GDD | Provisional: yes, attack declaration is an eligible trigger |
| Should `pass_response` be a visible player command in local MVP or an automatic timeout/pass in UI? | UX Designer / Match Authority Architect | Before Local Match Flow GDD | Provisional: explicit command for replay clarity |
| Should multi-target fizzles be all-or-nothing or per-target for production? | Systems Designer | Before Card Effect Resolution GDD | Provisional: all required targets must remain legal |

---

## Lean Review Notes

Specialist review was not run inline because `production/review-mode.txt` is set to `lean` and no subagent spawn was explicitly requested. Run `/design-review design/gdd/stack-response-system.md` in a fresh session before approval.
