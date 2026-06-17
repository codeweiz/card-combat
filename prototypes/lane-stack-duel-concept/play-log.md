// PROTOTYPE - NOT FOR PRODUCTION
// Question: Does lane positioning plus one-card response timing create clear tactical pressure?
// Date: 2026-06-17

# Lane-Stack Duel Paper Prototype Play Log

---

## Starting State

Player A:

- Life: 20
- Max resource: 0
- Current resource: 0
- Opening hand: Vanguard, Guard Flash, Spark Shot, Duelist
- Deck top after opening hand: Sidestep

Player B:

- Life: 20
- Max resource: 0
- Current resource: 0
- Opening hand: Sentinel, Spark Shot, Counter Sigil, Duelist
- Deck top after opening hand: Challenge

Board:

```text
Left:   A[empty] vs B[empty]
Center: A[empty] vs B[empty]
Right:  A[empty] vs B[empty]
```

---

## Turn 1 - Player A

### A001 - Start Phase

- Player A max resource: 0 -> 1
- Player A current resource: 1
- Player A draws Sidestep

### A002 - Main Action: Vanguard to Center

- Resource before: 1
- Player A plays Vanguard to Center for 1
- Resource after: 0
- Response window: opens
- Player B response: none
- Resolution: Vanguard enters Center, not ready this turn

Board:

```text
Left:   A[empty] vs B[empty]
Center: A[Vanguard 2/2] vs B[empty]
Right:  A[empty] vs B[empty]
```

### A003 - Attack Phase

- Vanguard was played this turn and is not ready.
- No attacks.

Life: A 20, B 20

---

## Turn 1 - Player B

### B001 - Start Phase

- Player B max resource: 0 -> 1
- Player B current resource: 1
- Player B draws Challenge

### B002 - Main Action: Pass

- Player B has Sentinel and Duelist but both cost 2.
- Player B passes.

### B003 - Attack Phase

- No units.

Life: A 20, B 20

**Decision Point 1**: Player B cannot answer the Center Vanguard yet. This makes Player A's early lane commitment matter, but B knows Spark Shot or Sentinel can contest it next turn.

---

## Turn 2 - Player A

### A004 - Start Phase

- Player A max resource: 1 -> 2
- Player A current resource: 2
- Player A draws Breaker

Hand: Guard Flash, Spark Shot, Duelist, Sidestep, Breaker

### A005 - Main Action: Duelist to Left

- Resource before: 2
- Player A plays Duelist to Left for 2
- Resource after: 0
- Response window: opens
- Player B response: none
- Resolution: Duelist enters Left, not ready this turn

Board:

```text
Left:   A[Duelist 3/1] vs B[empty]
Center: A[Vanguard 2/2] vs B[empty]
Right:  A[empty] vs B[empty]
```

### A006 - Attack Phase: Vanguard Attacks Face

- Vanguard is ready.
- Attack declaration opens response window.
- Player B response: none
- Vanguard deals 2 damage to Player B.

Life: A 20, B 18

**Decision Point 2**: Player A chooses to widen lanes instead of holding resource for Guard Flash or Spark Shot. This creates pressure but leaves A unable to protect Duelist this turn.

---

## Turn 2 - Player B

### B004 - Start Phase

- Player B max resource: 1 -> 2
- Player B current resource: 2
- Player B draws Guard Flash

Hand: Sentinel, Spark Shot, Counter Sigil, Duelist, Challenge, Guard Flash

### B005 - Main Action: Spark Shot on Duelist

- Resource before: 2
- Player B plays Spark Shot targeting A's Duelist in Left for 1
- Resource after: 1
- Response window: opens
- Player A response: Guard Flash on Duelist for 1
- Player A resource before response: 0, because A spent all 2 resource on Duelist last turn.
- Response is illegal because Player A has no current resource.
- Corrected response: none
- Resolution: Spark Shot deals 2 damage to Duelist.
- Duelist health: 1 -> -1
- Duelist destroyed.

Board:

```text
Left:   A[empty] vs B[empty]
Center: A[Vanguard 2/2] vs B[empty]
Right:  A[empty] vs B[empty]
```

### B006 - Main Action Continuation: No Further Main Card

- This prototype allows only 1 main action per turn.
- Player B keeps 1 resource unused.

### B007 - Attack Phase

- No units.

Life: A 20, B 18

**Rules Note**: Current resource only refreshes on the active player's turn. This makes response cards powerful but requires planning. If this feels too punishing in playtest, a future prototype can test a separate response resource.

---

## Turn 3 - Player A

### A007 - Start Phase

- Player A max resource: 2 -> 3
- Player A current resource: 3
- Player A draws Rally Mark

Hand: Guard Flash, Spark Shot, Sidestep, Breaker, Rally Mark

### A008 - Main Action: Spark Shot on Player B

- Resource before: 3
- Player A plays Spark Shot targeting Player B directly.
- Correction: Spark Shot only targets units.
- Illegal action rewound before resolution.

### A009 - Main Action: Breaker to Right

- Resource before: 3
- Player A plays Breaker to Right for 3
- Resource after: 0
- Response window: opens
- Player B response: none
- Resolution: Breaker enters Right, not ready this turn

Board:

```text
Left:   A[empty] vs B[empty]
Center: A[Vanguard 2/2] vs B[empty]
Right:  A[Breaker 3/3] vs B[empty]
```

### A010 - Attack Phase: Vanguard Attacks Face

- Attack declaration opens response window.
- Player B response: none
- Vanguard deals 2 damage to Player B.

Life: A 20, B 16

**Decision Point 3**: The illegal Spark Shot attempt shows why target legality must be explicit and why action logs must support failed intentions or pre-validation. For the paper test, illegal actions are rewound. In production, the UI should prevent this action.

---

## Turn 3 - Player B

### B008 - Start Phase

- Player B max resource: 2 -> 3
- Player B current resource: 3
- Player B draws Vanguard

Hand: Sentinel, Counter Sigil, Duelist, Challenge, Guard Flash, Vanguard

### B009 - Main Action: Challenge on Vanguard

- Resource before: 3
- Player B plays Challenge targeting A's Vanguard in Center for 1
- Challenge attempts to move Vanguard to A's Left or Right.
- Player B chooses A's Left.
- Resource after: 2
- Response window: opens
- Player A response: none, because A has 0 current resource.
- Resolution: Vanguard moves from Center to Left.

Board:

```text
Left:   A[Vanguard 2/2] vs B[empty]
Center: A[empty] vs B[empty]
Right:  A[Breaker 3/3] vs B[empty]
```

### B010 - Attack Phase

- No units.

Life: A 20, B 16

**Decision Point 4**: Player B uses Challenge defensively to reshape A's attack pattern instead of developing Sentinel or Duelist. This is a meaningful lane decision because it affects which lanes are open for future blockers.

---

## Turn 4 - Player A

### A011 - Start Phase

- Player A max resource: 3 -> 4
- Player A current resource: 4
- Player A draws Direct Bolt

Hand: Guard Flash, Spark Shot, Sidestep, Rally Mark, Direct Bolt

### A012 - Main Action: Rally Mark on Breaker

- Resource before: 4
- Player A plays Rally Mark on Breaker for 1
- Breaker gets +1 attack this turn, becoming 4/3.
- Resource after: 3
- Response window: opens
- Player B response: Counter Sigil on Rally Mark.
- Player B pays 2 for Counter Sigil.
- Player B resource before response: 2, carried over from B's previous turn.
- Player B resource after response: 0
- Resolution: Counter Sigil cancels Rally Mark.
- Breaker remains 3/3.

### A013 - Attack Phase: Vanguard Attacks Face from Left

- Attack declaration opens response window.
- Player B response: none
- Vanguard deals 2 damage to Player B.
- Player B life: 16 -> 14

### A014 - Attack Phase: Breaker Attacks Face from Right

- Attack declaration opens response window.
- Player B response: none, no current resource remains.
- Breaker deals 3 damage to Player B.
- Player B life: 14 -> 11

Board:

```text
Left:   A[Vanguard 2/2] vs B[empty]
Center: A[empty] vs B[empty]
Right:  A[Breaker 3/3] vs B[empty]
```

Life: A 20, B 11

**Decision Point 5**: Player B spends Counter Sigil on a temporary buff instead of saving it for a later removal spell. This is a clear response-timing decision with visible cost.

---

## Turn 4 - Player B

### B011 - Start Phase

- Player B max resource: 3 -> 4
- Player B current resource: 4
- Player B draws Sidestep

Hand: Sentinel, Duelist, Guard Flash, Vanguard, Sidestep

### B012 - Main Action: Sentinel to Right

- Resource before: 4
- Player B plays Sentinel to Right for 2
- Resource after: 2
- Response window: opens
- Player A response: none
- Resolution: Sentinel enters Right, opposing Breaker.

Board:

```text
Left:   A[Vanguard 2/2] vs B[empty]
Center: A[empty] vs B[empty]
Right:  A[Breaker 3/3] vs B[Sentinel 1/4]
```

### B013 - Attack Phase

- Sentinel was played this turn and is not ready.
- No attacks.

Life: A 20, B 11

**Decision Point 6**: Player B chooses Sentinel over Duelist because it can survive Breaker and stabilize a lane. The lane cap makes this a commitment.

---

## Turn 5 - Player A

### A015 - Start Phase

- Player A max resource: 4 -> 5
- Player A current resource: 5
- Player A draws Sentinel

Hand: Guard Flash, Spark Shot, Sidestep, Direct Bolt, Sentinel

### A016 - Main Action: Direct Bolt to Player B

- Resource before: 5
- Player A plays Direct Bolt targeting Player B for 2.
- Resource after: 3
- Response window: opens
- Player B response: none. Guard Flash and Sidestep do not protect player life, and Counter Sigil has already been spent.
- Resolution: Player B takes 3 damage.
- Player B life: 11 -> 8

### A017 - Attack Phase: Vanguard Attacks Face

- Attack declaration opens response window.
- Player B response: none.
- Vanguard deals 2 damage.
- Player B life: 8 -> 6

### A018 - Attack Phase: Breaker Attacks Sentinel

- Breaker attacks opposing Sentinel in Right.
- Attack declaration opens response window.
- Player B response: Guard Flash on Sentinel for 1.
- Player B resource before response: 2, carried over from B's previous turn.
- Player B resource after response: 1
- Sentinel health: 4 -> 6 until end of turn.
- Breaker deals 3 damage to Sentinel.
- Sentinel health this turn: 6 -> 3.
- End phase removes temporary +2 max/current health adjustment.
- Sentinel remains at 1 health after shield expires.

Board after end phase:

```text
Left:   A[Vanguard 2/2] vs B[empty]
Center: A[empty] vs B[empty]
Right:  A[Breaker 3/3] vs B[Sentinel 1/1]
```

Life: A 20, B 6

**Decision Point 7**: Guard Flash creates a real response moment. Player B preserves Sentinel at 1 health, which keeps Breaker blocked next turn unless A spends removal.

---

## Turn 5 - Player B

### B014 - Start Phase

- Player B max resource: 4 -> 5
- Player B current resource: 5
- Player B draws Direct Bolt

Hand: Duelist, Vanguard, Sidestep, Direct Bolt

### B015 - Main Action: Direct Bolt to Player A

- Resource before: 5
- Player B plays Direct Bolt targeting Player A for 2.
- Resource after: 3
- Response window: opens
- Player A response: none. Guard Flash protects units only.
- Resolution: Player A takes 3 damage.
- Player A life: 20 -> 17

### B016 - Attack Phase: Sentinel Attacks Breaker

- Sentinel is ready.
- Sentinel attacks opposing Breaker in Right.
- Response window opens.
- Player A response: Spark Shot on Sentinel is illegal as a response because Spark Shot is Main speed.
- Corrected response: none.
- Sentinel deals 1 damage to Breaker.
- Breaker health: 3 -> 2

Board:

```text
Left:   A[Vanguard 2/2] vs B[empty]
Center: A[empty] vs B[empty]
Right:  A[Breaker 3/2] vs B[Sentinel 1/1]
```

Life: A 17, B 6

**Rules Note**: This turn exposes a needed production distinction: Main-speed spells cannot be used as responses. The current card table already states speed, and the action log confirms why the UI must enforce it.

---

## Turn 6 - Player A

### A019 - Start Phase

- Player A max resource: 5 -> 6
- Player A current resource: 6
- Player A draws Counter Sigil

Hand: Guard Flash, Spark Shot, Sidestep, Sentinel, Counter Sigil

### A020 - Main Action: Spark Shot on Sentinel

- Resource before: 6
- Player A plays Spark Shot targeting B's Sentinel for 1.
- Resource after: 5
- Response window opens.
- Player B response: Sidestep is legal only for a friendly unit moving to an empty adjacent lane before an attack resolves. This is not an attack window.
- Player B response: none.
- Resolution: Spark Shot deals 2 damage to Sentinel.
- Sentinel health: 1 -> -1.
- Sentinel destroyed.

Board:

```text
Left:   A[Vanguard 2/2] vs B[empty]
Center: A[empty] vs B[empty]
Right:  A[Breaker 3/2] vs B[empty]
```

### A021 - Attack Phase: Vanguard Attacks Face

- Vanguard attacks Player B.
- Response window opens.
- Player B response: none.
- Player B life: 6 -> 4

### A022 - Attack Phase: Breaker Attacks Face

- Breaker attacks Player B.
- Response window opens.
- Player B response: none.
- Player B life: 4 -> 1

Life: A 17, B 1

**Decision Point 8**: Player A chooses removal before attacks rather than face damage with Direct Bolt. This preserves the lane attack line and demonstrates that board state can matter even near lethal.

---

## Turn 6 - Player B

### B017 - Start Phase

- Player B max resource: 5 -> 6
- Player B current resource: 6
- Player B draws Breaker

Hand: Duelist, Vanguard, Sidestep, Direct Bolt, Breaker

### B018 - Main Action: Breaker to Left

- Resource before: 6
- Player B plays Breaker to Left for 3, opposing Vanguard.
- Resource after: 3
- Response window opens.
- Player A response: Counter Sigil is illegal because Breaker is a unit, not a spell targeting a unit.
- Corrected response: none.
- Resolution: Breaker enters Left, not ready this turn.

Board:

```text
Left:   A[Vanguard 2/2] vs B[Breaker 3/3]
Center: A[empty] vs B[empty]
Right:  A[Breaker 3/2] vs B[empty]
```

### B019 - Attack Phase

- Breaker was played this turn and is not ready.
- No attacks.

Life: A 17, B 1

**Decision Point 9**: Player B blocks the Vanguard lane but cannot answer the Right lane this turn. This demonstrates the value of three lanes: a single blocker does not reset the whole board.

---

## Turn 7 - Player A

### A023 - Start Phase

- Player A max resource remains 6.
- Player A current resource: 6
- Player A draws Challenge.

Hand: Guard Flash, Sidestep, Sentinel, Counter Sigil, Challenge

### A024 - Main Action: Challenge on B's Breaker

- Resource before: 6
- Player A plays Challenge targeting B's Breaker in Left for 1.
- Player A attempts to move B's Breaker from Left to Center.
- Resource after: 5
- Response window opens.
- Player B response: none. Anchor Ward is not in hand.
- Resolution: B's Breaker moves to Center.

Board:

```text
Left:   A[Vanguard 2/2] vs B[empty]
Center: A[empty] vs B[Breaker 3/3]
Right:  A[Breaker 3/2] vs B[empty]
```

### A025 - Attack Phase: Vanguard Attacks Face

- Vanguard attacks Player B from Left.
- Response window opens.
- Player B response: none.
- Vanguard deals 2 damage.
- Player B life: 1 -> -1

Result: Player A wins.

---

## Replay Check

This play log can be replayed from:

- The fixed initial hands.
- The fixed deck order.
- The ordered action list A001 through A025 and B001 through B019.
- The deterministic rules in `rules.md`.

The same sequence produces:

- Player A life: 17
- Player B life: -1
- Winner: Player A

---

## Prototype Observations

### What Worked

- Lane position mattered. A single blocker did not solve all pressure because attacks are lane-specific.
- Response cards created visible tradeoffs when players had current resource available.
- The log exposed several UI and rules needs: speed tags, target legality, response affordability, and action pre-validation.

### What Needs Revision

- The resource model is awkward for responses because current resource carries across opponent turns implicitly. This must be made explicit or replaced with a separate response resource.
- Several illegal action attempts occurred during the paper simulation. That is useful evidence, but a real client must prevent them before submission.
- One response per window kept the log readable, but the Yu-Gi-Oh!-style fantasy may eventually need limited multi-step chains.

### Preliminary Recommendation

**PIVOT within the same hook.**

The `Lane-plus-stack` direction produced meaningful decisions, but the response resource model needs revision before this should become the locked production hook. The next prototype should test either:

1. A separate `focus` resource reserved for responses, or
2. A simpler rule where unspent active-turn resource clearly remains available for responses until the player's next turn.

This is not a concept kill. The lane plus response structure produced enough tactical pressure to justify another focused iteration.
