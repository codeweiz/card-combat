// PROTOTYPE - NOT FOR PRODUCTION
// Question: Does lane positioning plus one-card response timing create clear tactical pressure?
// Date: 2026-06-17

# Lane-Stack Duel Paper Prototype Rules

---

## Purpose

This Paper prototype tests the first candidate hook for Card Combat: **Lane-plus-stack combat**. The goal is to combine the readable board stakes of a lane card battler with the response timing drama of a chain/stack system.

This prototype is deliberately small. It does not test collection, deckbuilding, online matchmaking, final UI, monetization, or production card balance.

---

## Hypothesis

If players deploy units across three lanes and hold a small number of response cards to interrupt opponent actions, each match will create clear tactical pressure around lane commitment and timing.

The hypothesis is supported if one simulated match produces:

- At least 3 non-obvious decisions where either player has multiple defensible choices.
- A readable lane state after every action.
- A complete action log that can replay the same result from the starting state.

---

## Riskiest Assumption

The riskiest assumption is that a response window after every major action adds depth without making the game feel slow or opaque. If every response is obvious, the stack system is unnecessary. If every response is confusing, the hook is too heavy for a cross-platform card battler.

---

## Components

### Players

- 2 players: Player A and Player B.
- Each player starts at 20 life.
- Each player has a 12-card prototype deck.
- Each player starts with 4 cards in hand.
- No mulligan in this prototype.

### Lanes

There are 3 lanes:

- Left
- Center
- Right

Each lane can contain at most 1 unit per player. A lane can therefore hold up to 2 opposing units, one on each side.

### Resources

- Player A starts with 1 max resource on Turn 1.
- Player B starts with 1 max resource on Turn 1.
- At the start of each player's turn, that player increases max resource by 1, up to 6.
- At the start of each player's turn, that player's current resource refreshes to max resource.
- Unspent current resource remains available through the opponent's next turn for response cards.
- When that player's next turn starts, current resource refreshes to max resource and replaces any unspent amount.

This prototype uses small values so the paper match reaches meaningful turns quickly.

---

## Turn Structure

Each turn follows this structure:

1. **Start Phase**
   - Active player increases max resource by 1, up to 6.
   - Active player refreshes current resource.
   - Active player draws 1 card.

2. **Main Action Phase**
   - Active player may play 1 card or pass.
   - If the action creates a response window, the defending player may play at most 1 response card.
   - Resolve the response first, then resolve the original action if still legal.

3. **Attack Phase**
   - Each ready unit controlled by the active player attacks in its lane.
   - If opposed by an enemy unit in the same lane, it deals damage to that unit.
   - If unopposed, it deals damage to the enemy player.
   - Units do not counterattack automatically in this prototype.

4. **End Phase**
   - Remove expired shields.
   - Pass turn to the opponent.

---

## Response Window Rules

A response window opens after:

- A unit is played.
- A spell targets a unit or player.
- A unit begins attacking.

The non-active player may play at most 1 response card per window. After that response resolves, the original action resolves if it is still legal.

Response timing is intentionally limited to one card to keep the paper test readable. Future versions may test longer chains if this version produces good decisions without confusion.

### Response Resource Rule

Response cards use the same current resource pool as main actions. This means spending all resources on your own turn leaves no resource for responses during the opponent's turn.

This is a prototype rule, not a locked production decision. If playtesting shows this is too punishing or hard to track, the next prototype should test a separate response resource.

---

## Unit Rules

Each unit has:

- Attack
- Health
- Lane
- Ready state

Units can attack on the controller's next turn after being played. A unit played this turn is not ready during that same turn.

When a unit takes damage, reduce its health. If health reaches 0 or less, destroy it and remove it from its lane.

---

## Card Set

Each player uses the same 12-card prototype deck for this paper test.

| ID | Card | Type | Cost | Speed | Effect |
|----|------|------|------|-------|--------|
| C01 | Vanguard | Unit | 1 | Main | 2 attack / 2 health. Play into an empty lane. |
| C02 | Sentinel | Unit | 2 | Main | 1 attack / 4 health. Play into an empty lane. |
| C03 | Duelist | Unit | 2 | Main | 3 attack / 1 health. Play into an empty lane. |
| C04 | Breaker | Unit | 3 | Main | 3 attack / 3 health. Play into an empty lane. |
| C05 | Spark Shot | Spell | 1 | Main | Deal 2 damage to a unit. Opens response window. |
| C06 | Direct Bolt | Spell | 2 | Main | Deal 3 damage to the enemy player. Opens response window. |
| C07 | Guard Flash | Response | 1 | Response | Give a unit +2 health until end of turn before damage resolves. |
| C08 | Counter Sigil | Response | 2 | Response | Cancel a spell that targets a unit. |
| C09 | Sidestep | Response | 1 | Response | Move one friendly unit to an empty adjacent lane before an attack resolves. |
| C10 | Challenge | Spell | 1 | Main | Move an enemy unit to an adjacent empty lane on its side. Opens response window. |
| C11 | Rally Mark | Spell | 1 | Main | Give a friendly unit +1 attack this turn. Opens response window. |
| C12 | Anchor Ward | Response | 1 | Response | Prevent a friendly unit from being moved this window. |

### Prototype Deck Order

To keep the play log reproducible, both players use fixed deck order.

Player A deck from top to bottom:

1. Vanguard
2. Guard Flash
3. Spark Shot
4. Duelist
5. Sidestep
6. Breaker
7. Rally Mark
8. Direct Bolt
9. Sentinel
10. Counter Sigil
11. Challenge
12. Anchor Ward

Player B deck from top to bottom:

1. Sentinel
2. Spark Shot
3. Counter Sigil
4. Duelist
5. Challenge
6. Guard Flash
7. Vanguard
8. Sidestep
9. Direct Bolt
10. Breaker
11. Anchor Ward
12. Rally Mark

Each player draws the top 4 cards as their opening hand.

---

## Lane Notation

Use this notation in the play log:

```text
Left:   A[unit hp/atk] vs B[unit hp/atk]
Center: A[unit hp/atk] vs B[unit hp/atk]
Right:  A[unit hp/atk] vs B[unit hp/atk]
```

Use `empty` if a side has no unit in that lane.

Example:

```text
Center: A[Vanguard 2/2] vs B[Sentinel 1/4]
```

The first number shown is attack and the second is current health.

---

## Action Log Requirements

Every action should record:

- Action ID.
- Active player.
- Turn number.
- Current resource before and after payment.
- Card or attack declared.
- Target lane or target entity.
- Whether a response window opened.
- Response card used, if any.
- Final resolution.
- Resulting life totals and lane state.

This is intentionally close to a future deterministic replay format. The format is text for now; production implementation should use structured data.

---

## Explicit Cuts

This prototype does not include:

- Godot implementation.
- Networking.
- AI opponent.
- Deckbuilding.
- Mulligan.
- Card rarity.
- Account/profile.
- Collection.
- Ranked ladder.
- Store or monetization.
- Final UI.
- Final art, animation, VFX, or audio.
- More than one response per window.
- Simultaneous triggers.
- Random effects.

---

## Prototype Verdict Criteria

After running or reading the play log, classify the result:

- **PROCEED** if lane commitment and response timing produce at least 3 meaningful choices while remaining readable.
- **PIVOT** if one part works but the other creates too much friction.
- **KILL** if the hook only works when heavily explained or does not produce interesting decisions.

---

## Next Step After Reading

Read `play-log.md` as if playing the match for the first time. Mark each point where you would consider a different play. The prototype is useful if those points are visible from the board state rather than only from designer commentary.
