# Lane-Stack Duel Concept Prototype

Source type: Paper prototype
Status: Pivoted within hook
Date: 2026-06-17

## Purpose

This prototype tests whether three-lane board commitment plus a one-card
response window creates clear tactical pressure for Card Combat. It is the first
candidate validation pass for the `Lane-plus-stack` combat hook.

The prototype intentionally excludes collection, deckbuilding, matchmaking,
final UI, monetization, and production card balance. Its only job is to test the
shape of lane commitment, response timing, and deterministic action logging.

## Core Hypothesis

If players deploy units across three lanes and hold a small number of response
cards to interrupt opponent actions, a match should produce readable board
states and several non-obvious tactical decisions.

The original success signals were:

- At least 3 non-obvious decisions where either player has multiple defensible
  choices.
- A readable lane state after every action.
- A complete action log that can replay the same result from the starting state.

## Prototype Setup

- 2 players.
- 20 life per player.
- 12-card mirrored prototype deck.
- 4-card opening hand.
- 3 lanes: Left, Center, Right.
- At most 1 unit per player per lane.
- Main resource grows each turn up to 6.
- Response cards used leftover current resource from the previous own turn.
- One response card at most may be played in each response window.

Response windows opened after:

- A unit is played.
- A spell targets a unit or player.
- A unit begins attacking.

## What Was Tested

The play log tested a fixed opening sequence using deterministic deck order and
explicit lane notation. It exercised:

- Unit placement into lanes.
- Attack pressure from an uncontested lane.
- A targeted damage spell.
- A response attempt rejected by the prototype's resource rule.
- A movement spell that changes future lane pressure.
- Illegal-action rewind for an invalid target declaration.

## Result

Verdict: **Pivot within the same hook.**

The prototype produced enough lane and response decision points to keep
exploring `Lane-plus-stack`, but it exposed a weak response-resource rule. Using
leftover main-turn resource for responses was too easy to misread and caused a
response card to be rejected because the player had spent all resource on their
own previous turn.

This is a rules clarity problem, not a reason to abandon the hook.

## What Worked

- Three lanes created visible pressure even with very small card values.
- One-card response windows kept stack timing readable.
- The deterministic play log exposed illegal intentions and ambiguous resource
  state, which are exactly the issues production validation should catch early.

## What Changed

The next rule direction replaces carried-over main resource with a dedicated
response resource named `focus`.

The revised model is:

- Main resource pays for proactive main-turn cards.
- `focus` pays for response-speed cards.
- `focus` refreshes to a small value, provisionally 1 or 2, during the
  opponent's turn.
- Main resource and `focus` remain separate in MVP.

## Production Follow-Through

Current design work has already incorporated this pivot:

- `design/gdd/turn-timing-resource-system.md` defines response `focus` as a
  separate resource.
- `design/gdd/stack-response-system.md` keeps one-card MVP response windows and
  deterministic pending-original resolution.
- `design/gdd/card-effect-resolution-system.md` defines typed response effects,
  including `cancel_original`.
- `src/core/simulation/deterministic_simulation_core.gd` now has an initial
  response-window skeleton with `pass_response` and `play_response`.

## Files

- `rules.md` - prototype rules, deck list, and action-log requirements.
- `play-log.md` - deterministic simulated match log.
- `PIVOT-NOTE.md` - conclusion and next prototype recommendation.

## Follow-Up

If this concept is tested again as paper design before deeper Godot
implementation, create `prototypes/lane-stack-focus-concept/` and use the
dedicated `focus` resource model from the start.
