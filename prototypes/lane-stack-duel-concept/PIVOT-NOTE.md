// PROTOTYPE - NOT FOR PRODUCTION
// Question: What should the next Lane-plus-stack iteration change?
// Date: 2026-06-17

# Pivot Note: Lane-Stack Duel Concept

## Original Hypothesis

If players deploy units across three lanes and hold a small number of response cards to interrupt opponent actions, each match will create clear tactical pressure around lane commitment and timing.

## Verdict

**PIVOT within the same hook.**

The paper play log showed enough lane and response decisions to keep exploring `Lane-plus-stack`, but it also exposed an unclear response-resource model. This is a rules clarity issue, not a reason to abandon the core direction.

## What To Keep

- **Three-lane board pressure**: Blocking one lane should not reset all offensive pressure.
- **One-card response windows**: The limitation kept the log readable while still creating tactical interruption moments.
- **Deterministic action log**: The play log revealed illegal intentions and resource ambiguity, which is exactly the kind of issue the production client must prevent.

## What To Change

The next prototype should replace the carried-over resource rule with a clearer response model.

Priority test:

1. Each player gets a separate `focus` resource used only for response cards.
2. `focus` refreshes to 1 or 2 at the start of each opponent turn.
3. Main-turn resource and response resource are tracked separately.

## Revised Hypothesis

If response cards use a small dedicated `focus` resource instead of leftover main-turn resource, players will still face meaningful timing decisions while the board state remains easier to read and teach.

Success signal:

- At least 3 meaningful response decisions appear in one simulated match.
- No response is rejected because the player forgot how resource carryover works.
- The action log can replay without corrections or illegal-action rewinds.

## Next Prototype

Create `prototypes/lane-stack-focus-concept/` as a second Paper prototype if this pivot is tested before Godot implementation.
