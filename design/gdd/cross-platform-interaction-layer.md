# Cross-Platform Interaction Layer

> **Status**: Designed
> **Author**: Codex
> **Last Updated**: 2026-06-17
> **Last Verified**: 2026-06-17
> **Implements Pillar**: Cross-Platform First; Rules Clarity Beats Hidden Complexity; Deterministic Trust

## Summary

Cross-Platform Interaction Layer defines how mouse, touch, keyboard, and later
gamepad input become the same match-board intentions without changing the rules
of the duel. It owns device context, semantic input actions, focus policy,
gesture disambiguation, and platform layout constraints. It does not own match
state, card legality, command resolution, or replay data.

> **Quick reference** - Layer: `Presentation` - Priority: `MVP` - Key deps: `Match Board UI and Input`

## Overview

The interaction layer is the adapter between platform-specific input and the
match board. A player may click a card, tap a card, focus it with keyboard, or
later select it with a gamepad, but those actions must resolve to the same
semantic UI intent: select, inspect, choose target, confirm, cancel, pass, or
open log detail. The layer must make PC, Web, and Mobile play the same match
under the same rules while still respecting each device's physical constraints.

Godot 4.6 separates mouse/touch focus from keyboard/gamepad focus, so this GDD
requires the interaction layer to track pointer state and focus-navigation state
as distinct inputs. The layer may help presentation decide what to highlight,
but only Match Board UI and Local Match Flow decide whether an intent is
currently legal.

## Player Fantasy

Players should feel that the game understands the way they are playing. A mouse
player can click precisely, a mobile player can tap without accidental commits,
and a keyboard or gamepad player can reach every required action without losing
context. The fantasy is not about the input layer itself; it is the confidence
that tactical decisions are never gated by a hidden control trick or a device
the UI forgot to support.

## Detailed Design

### Core Rules

1. The layer supports four MVP input methods: mouse, touch, keyboard, and
   gamepad.
2. PC and Web must support mouse and keyboard.
3. Mobile must support touch.
4. Gamepad support is partial in MVP and covers menu/match navigation only when
   a focus route exists.
5. No gameplay rule may differ by platform or input method.
6. Raw input events must be normalized into semantic UI actions before they
   reach Match Board UI.
7. Semantic UI actions are:
   - `ui_select`
   - `ui_inspect`
   - `ui_confirm`
   - `ui_cancel`
   - `ui_pass`
   - `ui_focus_next`
   - `ui_focus_previous`
   - `ui_focus_up`
   - `ui_focus_down`
   - `ui_focus_left`
   - `ui_focus_right`
   - `ui_open_log`
   - `ui_toggle_detail`
8. The deterministic simulation core must never receive raw input events,
   pointer positions, key codes, touch ids, or gamepad button ids.
9. Device-specific input facts may be recorded in debug telemetry, but they are
   not canonical replay inputs.
10. Match commands submitted to Local Match Flow must be canonical intentions
    built by Match Board UI after selection and legality checks.
11. The active device context may change when a different input family produces
    a meaningful action.
12. Passive pointer hover does not switch authoritative focus-navigation state.
13. Pointer hover and keyboard/gamepad focus may exist on different controls in
    Godot 4.6; both must be visually distinguishable.
14. Commit source is determined only by explicit confirm/tap/click, never by
    hover alone.
15. Every required match action must be reachable without hover.
16. Touch required targets must satisfy `MIN_TOUCH_TARGET_PX = 48`.
17. Touch targeted actions require target preview before command commit.
18. Long press is reserved for inspect/detail on touch and must not commit a
    gameplay action.
19. Drag/scroll gestures must not accidentally confirm selected cards.
20. Keyboard and gamepad navigation require explicit focus routes for all
    required match-board regions.
21. A focus route is complete only if select, inspect, confirm, cancel, pass,
    and log detail are reachable from the board state that exposes them.
22. Cancel must always return to the previous interaction state or clear the
    current selection without submitting a command.
23. Confirm must submit at most one semantic action per input press/release
    cycle.
24. During command resolution lock, input may move visual focus but may not
    submit new gameplay intentions.
25. Layout reflow caused by orientation, viewport, or safe-area changes must
    preserve current authoritative match snapshot and clear unsafe pending
    target commits.
26. UI text scale or localization changes must not remove required controls.
27. Input action names should use stable `StringName` identifiers in GDScript
    hot paths.
28. Godot input maps must be data-driven project settings or resources, not
    hardcoded per scene.
29. The first playable can ship with placeholder device icons, but each input
    method must have testable action mappings.
30. Accessibility and Focus Navigation may later extend this system; this GDD
    provides the MVP reachability and no-hover baseline.

### Semantic Action Contract

| Semantic Action | Mouse | Touch | Keyboard | Gamepad | Match Board Meaning |
|-----------------|-------|-------|----------|---------|---------------------|
| `ui_select` | Primary click | Tap | Focus + confirm | Focus + confirm | Select card, unit, lane, player, or control |
| `ui_inspect` | Secondary click or detail button | Long press or detail button | Inspect key | Face/button mapped to inspect | Open card/unit/detail view |
| `ui_confirm` | Confirm button or valid second click | Confirm button or valid second tap | Confirm key | Confirm button | Commit current UI choice |
| `ui_cancel` | Cancel button or safe empty area | Cancel button or safe empty area | Cancel/back key | Cancel/back button | Clear selection or return one state |
| `ui_pass` | Pass affordance click | Pass affordance tap | Focus pass + confirm | Focus pass + confirm | Submit pass phase/window intention |
| `ui_open_log` | Event strip click | Event strip tap | Focus event strip + confirm | Focus event strip + confirm | Show event detail |
| `ui_focus_*` | Not required | Not required | Direction keys/tab | D-pad/stick | Move focus among reachable controls |
| `ui_toggle_detail` | Detail button | Detail button | Detail key | Detail button | Expand/collapse detail panel |

### Default MVP Bindings

Godot action names use the semantic action ids in this table. Physical labels
are provisional and may be localized or remapped later, but the semantic action
names are stable.

| Semantic Action | Mouse | Touch | Keyboard Default | Gamepad Default | MVP Support |
|-----------------|-------|-------|------------------|-----------------|-------------|
| `ui_select` | Primary click | Tap | Enter or Space on focused control | South face button | Full |
| `ui_inspect` | Secondary click or detail button | Long press or detail button | I | West face button | Full |
| `ui_confirm` | Confirm button or second click on confirmed target | Confirm button or second tap after preview | Enter | South face button | Full |
| `ui_cancel` | Cancel button or safe empty-area click | Cancel button or safe empty-area tap | Escape or Backspace | East face button | Full |
| `ui_pass` | Pass affordance click | Pass affordance tap | P when pass is focused or pass shortcut enabled | Focus pass then South button | Full |
| `ui_focus_next` | N/A | N/A | Tab | Right shoulder | Keyboard full, gamepad partial |
| `ui_focus_previous` | N/A | N/A | Shift+Tab | Left shoulder | Keyboard full, gamepad partial |
| `ui_focus_up` | N/A | N/A | Up arrow or W | D-pad up or left stick up | Keyboard full, gamepad partial |
| `ui_focus_down` | N/A | N/A | Down arrow or S | D-pad down or left stick down | Keyboard full, gamepad partial |
| `ui_focus_left` | N/A | N/A | Left arrow or A | D-pad left or left stick left | Keyboard full, gamepad partial |
| `ui_focus_right` | N/A | N/A | Right arrow or D | D-pad right or left stick right | Keyboard full, gamepad partial |
| `ui_open_log` | Event strip click | Event strip tap | L when event strip is focused or log shortcut enabled | Focus event strip then South button | Full |
| `ui_toggle_detail` | Detail button | Detail button | D | North face button | Full |

Partial MVP gamepad support means gamepad input may be enabled only on screens
whose focus route passes `focus_route_complete`. Screens without a complete
route must block gameplay submit actions and show an unsupported-input reason.

### Device Contexts

| Context | Entry Signal | Primary Strength | Required Safeguard |
|---------|--------------|------------------|--------------------|
| MousePointer | Mouse click or movement with click intent | Precise selection and hover detail | Hover cannot be required |
| TouchPointer | Touch press, drag, long press, or tap | Direct mobile manipulation | Large targets and gesture disambiguation |
| KeyboardFocus | Key action or focus movement | Deterministic navigation and shortcuts | Complete focus route and visible focus |
| GamepadFocus | Joypad button or axis navigation | Couch/console-ready navigation path | Partial MVP label and no pointer-only blockers |

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| NoInputContext | Screen has loaded but no meaningful input has occurred | First input action arrives | Use default focus if configured |
| MousePointerActive | Mouse click or meaningful pointer activity | Touch, keyboard, or gamepad action arrives | Track pointer hover/press separately from focus |
| TouchPointerActive | Touch press, tap, drag, or long press occurs | Mouse, keyboard, or gamepad action arrives | Use touch-safe target and gesture policy |
| KeyboardFocusActive | Keyboard action or focus movement occurs | Mouse, touch, or gamepad action arrives | Use focus neighbors and explicit confirm |
| GamepadFocusActive | Gamepad action or navigation occurs | Mouse, touch, or keyboard action arrives | Use focus neighbors and explicit confirm |
| GestureDisambiguating | Touch movement or long press threshold is pending | Gesture resolves or is canceled | Distinguish tap, long press inspect, and scroll |
| InputLockedForResolution | Match Board UI reports command resolution lock | UI unlocks after authoritative update | Block gameplay submit actions; allow safe focus/inspect |
| LayoutReflowing | Viewport, orientation, safe area, or text scale changes | Layout validates required controls | Recompute targets and clear unsafe pending commits |

Valid flow:

```text
NoInputContext -> MousePointerActive
NoInputContext -> TouchPointerActive
NoInputContext -> KeyboardFocusActive
NoInputContext -> GamepadFocusActive
TouchPointerActive -> GestureDisambiguating -> TouchPointerActive
AnyActiveContext -> InputLockedForResolution -> PriorActiveContext
AnyActiveContext -> LayoutReflowing -> PriorActiveContext
```

### Interactions with Other Systems

| System | Data In | Data Out | Ownership Boundary |
|--------|---------|----------|--------------------|
| Match Board UI and Input | Board regions, enabled controls, prompt state, selection state | Semantic UI actions, focus changes, gesture outcomes | Match Board owns UI state and canonical intentions; this layer owns input normalization |
| Local Match Flow | Prompt owner and command lock status through Match Board | None directly in MVP | Local flow never receives raw input |
| Action Log and Replay System | None for canonical replay | Optional debug input breadcrumbs only | Replay records canonical commands, not device input |
| Menu and Navigation Shell | Screen stack and default focus later | Shared action map and focus policy | Menu owns screen routing; this layer owns semantic input names |
| Tutorial and Rules Explanation | Tutorial anchors later | Device-specific hint labels later | Tutorial owns instruction content |
| Localization and Text Layout | Text scale and localized label sizes later | Layout-ready flags and missing-control reports | Localization owns strings; this layer protects control reachability |
| Accessibility and Focus Navigation | Accessibility requirements later | Baseline focus routes and no-hover guarantees | Accessibility owns full compliance pass |

## Formulas

### Input Device Context Supported

The `input_device_context_supported` formula is defined as:

`input_device_context_supported = platform_supports_device and action_map_available and context_policy_enabled`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| platform_supports_device | P | bool | true/false | Current platform can receive this input device family |
| action_map_available | A | bool | true/false | Required semantic actions are mapped for this device |
| context_policy_enabled | C | bool | true/false | MVP policy allows the context for this screen |

**Output Range:** boolean.
**Example:** Gamepad can be detected on desktop, but match navigation remains
unsupported for a screen if no focus route exists for required controls.

### Interaction Intent Valid

The `interaction_intent_valid` formula is defined as:

`interaction_intent_valid = input_device_context_supported and semantic_action_known and target_affordance_valid and prompt_accepts_action and not gameplay_submit_locked`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| input_device_context_supported | D | bool | true/false | Device context is valid for this platform and screen |
| semantic_action_known | S | bool | true/false | Raw input mapped to a supported semantic UI action |
| target_affordance_valid | T | bool | true/false | The focused or hit target currently exists and can receive the action |
| prompt_accepts_action | P | bool | true/false | Match Board prompt state accepts this semantic action |
| gameplay_submit_locked | L | bool | true/false | UI is locked from submitting gameplay intentions |

**Output Range:** boolean.
**Example:** A keyboard confirm while command resolution is locked can move
focus later, but cannot submit another gameplay intention.

### Focus Route Complete

The `focus_route_complete` formula is defined as:

`focus_route_complete = all_required_controls_focusable and directional_neighbors_defined and cancel_path_defined and no_hover_only_required_action`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| all_required_controls_focusable | R | bool | true/false | Required controls can receive keyboard/gamepad focus |
| directional_neighbors_defined | N | bool | true/false | Directional focus movement reaches required regions |
| cancel_path_defined | C | bool | true/false | Cancel/back has a deterministic return behavior |
| no_hover_only_required_action | H | bool | true/false | Required actions are available without hover |

**Output Range:** boolean.
**Example:** A response prompt fails if pass response can be tapped but cannot
be focused and confirmed by keyboard.

### Gesture Disambiguated

The `gesture_disambiguated` formula is defined as:

`gesture_disambiguated = gesture_matches_single_intent and not gesture_conflicts_with_scroll and confirm_policy_satisfied`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| gesture_matches_single_intent | I | bool | true/false | Touch gesture maps to exactly one semantic action |
| gesture_conflicts_with_scroll | S | bool | true/false | Movement or press duration conflicts with scroll/detail behavior |
| confirm_policy_satisfied | C | bool | true/false | Target preview or explicit confirm requirements have been met |

**Output Range:** boolean.
**Example:** A long press on a card resolves to inspect, not select-and-commit,
because it does not satisfy targeted confirm policy.

### Platform Layout Ready

The `platform_layout_ready` formula is defined as:

`platform_layout_ready = required_regions_visible and required_touch_targets_valid and safe_area_respected and focus_route_complete`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| required_regions_visible | R | bool | true/false | Board, hand, prompt, pass/confirm/cancel, and result regions are visible when required |
| required_touch_targets_valid | T | bool | true/false | Required touch controls satisfy `touch_target_valid` |
| safe_area_respected | S | bool | true/false | Required controls are not clipped by platform safe areas |
| focus_route_complete | F | bool | true/false | Keyboard/gamepad route reaches required controls |

**Output Range:** boolean.
**Example:** A mobile portrait layout fails if the pass response control is
visible but clipped by the safe area or below 48 pixels.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Mouse hover and keyboard focus are on different controls | Show both states distinctly; only explicit confirm/click/tap commits | Godot 4.6 dual-focus allows simultaneous states |
| Player touches a card then drags beyond deadzone | Treat as scroll/drag, not confirm | Prevents accidental mobile commits |
| Player long-presses a legal targeted card | Open inspect/detail; do not commit | Long press is reserved for inspection |
| Viewport changes during target selection | Reflow layout, preserve source selection if still valid, clear pending target commit | Prevents stale screen coordinates |
| Required control is clipped by safe area | Mark layout not ready and disable gameplay submit until reflow succeeds | Required actions must remain reachable |
| Gamepad sends input on a screen without focus route | Ignore gameplay submit and show unsupported/navigation fallback reason | Partial MVP gamepad cannot create pointer-only holes |
| Keyboard repeat fires confirm multiple times | Submit at most one semantic action per press/release cycle | Prevents duplicate command attempts |
| Input arrives during command resolution lock | Allow safe focus/inspect; block gameplay submit | Authoritative result must reconcile first |
| Touch target is visually large but hit shape is smaller | Fail `platform_layout_ready` until hit target matches requirement | Measured interaction target matters |
| Device context switches after passive mouse move | Do not switch context until meaningful click/action | Avoids focus flicker on desktop |
| Browser loses focus mid-selection | Clear unsafe pending commit and require explicit reconfirmation after focus returns | Prevents unintended Web commands |
| Mobile app resumes after suspend | Rebuild from latest snapshot and require fresh explicit confirm | Avoids duplicate stale actions |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|----------------------|
| Match Board UI and Input | This depends on Match Board UI and Input | Receives control regions, selection states, enabled actions, and prompt requirements |
| Local Match Flow | Indirect upstream | Supplies command lock and prompt state through Match Board UI |
| Action Log and Replay System | Indirect upstream | Ensures only canonical match commands become replay inputs |
| Menu and Navigation Shell | Depends on this | Reuses semantic input actions and focus policy for screen navigation |
| Tutorial and Rules Explanation | Depends on this | Uses device-aware prompt labels and interaction anchors |
| Localization and Text Layout | Depends on this | Layout text changes must preserve reachable controls |
| Accessibility and Focus Navigation | Depends on this | Extends MVP focus and no-hover guarantees into full accessibility compliance |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `INPUT_CONTEXT_SWITCH_DEBOUNCE_MS` | 150 | 50-300 | Less flicker when devices alternate | Faster context label changes |
| `LONG_PRESS_INSPECT_MS` | 450 | 300-700 | Fewer accidental inspect opens | Faster mobile card detail |
| `DRAG_SCROLL_DEADZONE_PX` | 12 | 6-24 | Fewer accidental drags | More responsive scrolling |
| `FOCUS_ROUTE_MAX_STEPS_MVP` | 12 | 6-20 | More flexible dense layouts | Stricter focus ergonomics |
| `SUPPORTED_INPUT_METHOD_COUNT_MVP` | 4 | 3-4 | Broader QA matrix | Smaller support scope |
| `SAFE_AREA_MARGIN_PX` | 16 | 0-32 | More mobile safety margin | More usable screen space |
| `MIN_TOUCH_TARGET_PX` | 48 | 44-64 | Easier touch input | Denser layout with higher mis-tap risk |
| `SELECT_CONFIRM_REQUIRED_MVP` | true | true/false | Safer targeted commits | Faster expert input if false later |
| `TARGET_PREVIEW_REQUIRED` | true | true/false | Clearer target legality | Fewer steps if false later |

## Visual/Audio Requirements

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Device context changes | Optional input hint updates without layout jump | None | Medium |
| Keyboard/gamepad focus moves | Visible focus ring or state distinct from hover | None | High |
| Pointer hover | Subtle hover state distinct from focus | None | Medium |
| Touch press | Pressed state on the measured hit target | Optional tap feedback later | High |
| Long press inspect | Detail affordance/progress feedback if needed | Optional soft tick later | Medium |
| Gesture canceled by drag | Selection returns to previous safe state | None | High |
| Unsupported input on current screen | Non-blocking disabled reason | Optional soft error later | Medium |
| Layout reflow | Controls settle without changing match state | None | High |

Asset spec note: visual/audio requirements here are interaction feedback only.
Final control visuals, icons, and audio cues should be specified after the art
bible, menu shell, and accessibility GDDs are approved.

## UI Requirements

| Requirement | Applies To | Verification |
|-------------|------------|--------------|
| Required controls have semantic action ids | Match board, menus later | Inspect scene/action map |
| Required controls expose pointer and focus states separately | Match board | Godot 4.6 mouse plus keyboard test |
| Touch hit targets meet `MIN_TOUCH_TARGET_PX` | Mobile/Web touch layouts | Runtime layout measurement |
| Focus route reaches pass, confirm, cancel, hand, lanes, response prompt, and log | Keyboard/gamepad layouts | Automated or manual focus traversal |
| Device hints never replace visible controls | All platforms | UI review |
| Layout reflow does not mutate match state | Orientation/viewport changes | Snapshot hash comparison |
| Unsupported partial gamepad flows show a reason | MVP gamepad | Manual input test |
| No required action depends on hover | All platforms | No-hover QA pass |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|------------|-----------------------------|--------|
| Board regions and prompt states | `design/gdd/match-board-ui-input.md` | semantic actions, focus, touch targets, response prompt | Direct dependency |
| Canonical command boundary | `design/gdd/local-match-flow.md` | player intentions and command routing | Replay safety |
| Replay inputs | `design/gdd/action-log-replay-system.md` | accepted commands only | Determinism boundary |
| No-hover requirement | `design/gdd/game-concept.md` | required actions work with mouse, touch, keyboard/gamepad | Pillar constraint |
| Godot 4.6 focus behavior | `docs/engine-reference/godot/modules/input.md` | dual-focus and SDL3 gamepad notes | Engine constraint |
| Godot 4.6 UI behavior | `docs/engine-reference/godot/modules/ui.md` | separate pointer and keyboard/gamepad focus | Engine constraint |

## Acceptance Criteria

- [ ] **GIVEN** a mouse player on the match board, **WHEN** they click a legal card, select a legal target, and confirm, **THEN** the Match Board receives the same canonical UI intent sequence as an equivalent touch or keyboard path.
- [ ] **GIVEN** a touch player selects a targeted card, **WHEN** target preview is required, **THEN** the first tap selects/previews and no gameplay command is submitted until explicit confirm.
- [ ] **GIVEN** a touch long press on a card, **WHEN** the long-press threshold is reached, **THEN** inspect/detail opens and no gameplay command is committed.
- [ ] **GIVEN** keyboard navigation, **WHEN** the player traverses hand, lanes, response controls, pass, confirm, cancel, and event log, **THEN** `focus_route_complete` is true.
- [ ] **GIVEN** pointer hover and keyboard focus land on different controls, **WHEN** the player confirms with keyboard, **THEN** the focused control is used and hover alone does not commit.
- [ ] **GIVEN** command resolution is locked, **WHEN** any device submits confirm/pass/select, **THEN** `interaction_intent_valid` is false for gameplay submit actions.
- [ ] **GIVEN** a mobile layout after orientation or safe-area change, **WHEN** layout validation runs, **THEN** `platform_layout_ready` is true before gameplay submit is re-enabled.
- [ ] **GIVEN** a screen has partial gamepad support, **WHEN** a gamepad user reaches a control without focus neighbors, **THEN** gameplay submit is blocked and the UI shows a supported-input reason.
- [ ] **GIVEN** the browser loses and regains focus during target selection, **WHEN** the player returns, **THEN** pending target commit is cleared and explicit reconfirmation is required.
- [ ] **GIVEN** the action log records accepted commands, **WHEN** the match is replayed, **THEN** no raw input device events are required to reproduce the result.
- [ ] Performance: semantic input dispatch and focus movement must update visible feedback within 50ms; device-context hint changes must not cause board layout shift.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|------------|
| Should touch detail use long press only, or always show a visible detail button? | UX Designer | Before mobile board prototype | Provisional: support both to avoid hidden gestures |
| How should input hints localize for Web keyboard layouts? | Localization Lead | Before localization-text-layout GDD | Provisional: semantic action labels, not physical key names |

---

## Lean Review Notes

Specialist review was not run inline because `production/review-mode.txt` is set
to `lean` and no subagent spawn was explicitly requested. Run `/design-review
design/gdd/cross-platform-interaction-layer.md` in a fresh session before
approval.
