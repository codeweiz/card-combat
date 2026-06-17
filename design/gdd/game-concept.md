# Game Concept: Card Combat

*Created: 2026-06-17*
*Status: Draft*

---

## Elevator Pitch

Card Combat is a cross-platform competitive card battler built in Godot where players construct decks, summon units or effects, and outplay opponents through deterministic turn-based card resolution. It targets the readable tactical rhythm of Hearthstone and the expressive combo identity of Yu-Gi-Oh!, but the exact differentiating hook is intentionally still open for design discovery.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Digital collectible card game / tactical card battler |
| **Platform** | PC, Web, Mobile for first-party clients; console as later porting target |
| **Target Audience** | Mid-core card game players who enjoy deckbuilding, readable matches, and competitive mastery |
| **Player Count** | Primarily 1v1 multiplayer; AI opponent and solo training are expected support modes |
| **Session Length** | 8-15 minute matches; 30-60 minute play sessions |
| **Monetization** | Undecided; must not compromise competitive fairness |
| **Estimated Scope** | Large (multi-stage production; multiplayer, content pipeline, balance, live operations, and cross-platform UX are all material work) |
| **Comparable Titles** | Hearthstone, Yu-Gi-Oh! Master Duel, Marvel Snap |

---

## Overview

The project is a Godot-based, multi-client card battle game designed around deterministic turn resolution, deck construction, and readable tactical decision-making. The initial concept baseline prioritizes validating whether the core match loop can be fun and technically reliable across PC, Web, and Mobile before committing to large card pools, ranked infrastructure, or monetization systems.

---

## Player Fantasy

Players should feel like clever duelists who win by reading the opponent, planning several turns ahead, and expressing personal style through deck construction. The fantasy is not only collecting powerful cards; it is proving that a chosen strategy, timing window, and combo line can beat another human player under clear rules.

---

## Core Fantasy

You are a duelist-pilot who builds a personal strategy engine and then tests it under pressure against another player. Every card choice should feel intentional, every turn should create visible consequences, and every match should leave the player with a clear "I could have played that differently" learning moment.

---

## Unique Hook

**Open design question.** The project should not ship as a generic clone. Candidate hook directions to explore:

- **Lane-plus-stack combat**: combine board positioning with chain/response timing so simple turns still produce tactical tension.
- **Shared tempo track**: both players contest a visible initiative/resource timeline instead of only spending private mana.
- **Transforming deck identity**: decks evolve during a match through declared archetype pivots, creating counterplay around when a player commits.

The hook must be selected through prototyping before full GDD work.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Challenge** | 1 | Deckbuilding tradeoffs, tactical sequencing, bluffing, and matchup knowledge |
| **Expression** | 2 | Archetypes, card synergies, cosmetics, and player-authored deck identity |
| **Fellowship** | 3 | Friend matches, spectating, community deck sharing, and social meta discussion |
| **Fantasy** | 4 | Strong card identities, faction themes, and duel presentation |
| **Discovery** | 5 | New combos, card interactions, and meta shifts |
| **Sensation** | 6 | Responsive card handling, readable VFX, and satisfying impact moments |
| **Narrative** | Supporting | Optional world/faction framing, not core campaign dependency |
| **Submission** | Supporting | Casual queues and AI practice, not the primary design target |

### Key Dynamics

- Players iterate decks after losses and look for cleaner answers to common threats.
- Players learn timing windows, resource thresholds, and opponent archetype signals.
- Players discuss and share deck lists, matchup guides, and combo lines.
- Players prefer clarity over surprise when resolving complex card interactions.

### Core Mechanics

1. Deck construction with legality checks, archetype identity, and clear format rules.
2. Deterministic turn structure with server-authoritative action validation.
3. Card play and effect resolution with inspectable timing and priority rules.
4. Board state management for units, attachments, resources, status effects, and zones.
5. Matchmaking or lobby flow for human-vs-human play, plus AI/training fallback.

---

## Detailed Rules

This concept document does not finalize card-system rules yet. The following baseline constraints govern later system GDDs:

1. Matches are deterministic and must be reproducible from an ordered action log plus initial seed.
2. Multiplayer authority must not trust client-submitted outcomes; clients submit intentions, the authority validates and resolves.
3. Every card effect must have explicit timing, target legality, failure behavior, and UI explanation.
4. Deck legality must be validated before a match starts and again by the authoritative match service.
5. Required actions must work with mouse, touch, and keyboard/gamepad navigation patterns.
6. All visible card text must be localization-ready from the start.

---

## Formulas

No production balance formulas are approved yet. Initial prototype formulas should be treated as disposable and moved into data/config files, not hardcoded into scripts.

Candidate prototype variables:

| Variable | Meaning | Initial Range | Notes |
| ---- | ---- | ---- | ---- |
| `STARTING_HAND_SIZE` | Cards drawn before mulligan/start | 3-5 | Depends on final resource model |
| `MAX_HAND_SIZE` | Maximum cards retained in hand | 7-10 | Must avoid mobile UI overflow |
| `STARTING_HEALTH` | Player defeat threshold | 20-40 | Depends on match length target |
| `BASE_RESOURCE_PER_TURN` | Default resource growth | 1-2 | May be replaced by a non-mana tempo system |
| `TARGET_MATCH_MINUTES` | Desired average match length | 8-15 | Primary pacing KPI |

Example placeholder pacing check:

```text
expected_turns = TARGET_MATCH_MINUTES * average_turns_per_minute
average_damage_per_turn = STARTING_HEALTH / expected_turns
```

This is only a sanity check for prototype tuning, not a final combat formula.

---

## Edge Cases

- If a card target becomes illegal before resolution, the effect must define whether it fizzles, retargets, or partially resolves.
- If both players trigger simultaneous effects, the priority/tie-break rule must be explicit and reproducible.
- If a client disconnects mid-match, the authority must preserve match state and define reconnect, timeout, or surrender behavior.
- If a mobile client changes orientation or suspends/resumes, the match UI must recover without duplicating actions.
- If localization changes card text length, the UI must preserve rules readability without hiding critical information.
- If network latency delays feedback, the client may preview intent but must distinguish preview from confirmed authoritative state.

---

## Dependencies

| Dependency | Why It Matters |
| ---- | ---- |
| Engine setup | Godot version, language, export targets, and UI constraints shape all implementation stories |
| Card rules GDD | Defines zones, timing, targeting, effect grammar, and deterministic resolution |
| Match architecture ADR | Defines authority model, networking topology, replay/action log, and anti-cheat posture |
| UX spec | Required for cross-platform card interaction, readability, touch targets, and focus navigation |
| Art bible | Required before asset production and card-frame/UI identity decisions |
| Test setup | Required before implementing deterministic rule and balance systems |

Bidirectional dependency notes must be added to each system GDD when those documents are created.

---

## Tuning Knobs

| Knob | Safe Starting Range | Affects |
| ---- | ---- | ---- |
| Starting hand size | 3-5 cards | Opening agency, mulligan value, match variance |
| Deck size | 20-40 cards | Consistency, collection burden, match predictability |
| Copies per card | 1-3 | Combo reliability and deck identity |
| Average match duration | 8-15 minutes | Platform fit, queue cadence, mobile session suitability |
| Turn timer | 30-90 seconds | Competitive pace, mobile accessibility, rope pressure |
| Resource growth rate | 1-2 per turn or custom tempo model | Curve design, comeback space, combo timing |

All tuning values must eventually live in data resources or config files with source rationale.

---

## Acceptance Criteria

The concept baseline is ready to proceed when:

- A prototype can run one deterministic local match loop using placeholder cards.
- A saved action log can replay the same match outcome.
- The board UI supports mouse and touch for all required actions.
- The project has a documented decision for the unique hook direction.
- The first card rules GDD defines timing, target legality, zones, and failure behavior.
- The networking ADR defines whether MVP uses local-only, peer-hosted, or server-authoritative play.

---

## Core Loop

### Moment-to-Moment (30 seconds)

Inspect hand and board, choose a card or action, preview legal targets and consequences, commit the action, then observe confirmed resolution.

### Short-Term (5-15 minutes)

Play a full duel: mulligan/opening hand, build resources or tempo, contest board/control state, execute win condition, and learn from the final turn sequence.

### Session-Level (30-120 minutes)

Queue several matches, adjust one deck between games, test a matchup hypothesis, and leave with a clearer understanding of which cards or lines underperformed.

### Long-Term Progression

Progress through collection, ranked mastery, deck refinement, seasonal formats, cosmetic identity, and possibly faction/story unlocks. Competitive fairness constraints must be resolved before monetization design.

---

## Game Pillars

### Pillar 1: Rules Clarity Beats Hidden Complexity

Players may face deep interactions, but the game must make timing, legality, and outcomes inspectable.

*Design test*: If a mechanic is exciting but hard to explain in UI, simplify or reframe it before adding tutorial burden.

### Pillar 2: Skillful Deck Identity

Decks should express a plan, not just a pile of efficient cards.

*Design test*: If a card is strong in every deck, redesign it toward archetype commitment or counterplay.

### Pillar 3: Cross-Platform First

The same core match must be playable on desktop, Web, and mobile without different rules.

*Design test*: If a required action only works well with hover, right-click, or large-screen density, redesign the interaction.

### Pillar 4: Deterministic Trust

Every match outcome must be reproducible and defensible.

*Design test*: If a system cannot be replayed from action logs or validated by authority, it is not ready for multiplayer.

### Anti-Pillars

- **NOT a clone with renamed cards**: Direct imitation weakens product identity and creates design/legal risk.
- **NOT pay-to-win**: Monetization cannot sell competitive advantage without a fair acquisition path.
- **NOT animation over readability**: Card effects can be stylish, but must not obscure resolved state.
- **NOT client-trusted multiplayer**: Clients may present intent, never authoritative outcomes.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| Hearthstone | Fast readability, short sessions, approachable digital-first flow | Avoid over-simplifying interaction depth before selecting the hook | Validates accessible digital card combat |
| Yu-Gi-Oh! Master Duel | Combo expression, chain timing, deck identity | Reduce opacity and rules burden for new players | Validates high-expression card systems |
| Marvel Snap | Mobile-friendly pacing and readable board stakes | Build deeper deck/match systems if scope allows | Validates short-session card battler demand |

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 16-40 |
| **Gaming experience** | Mid-core to competitive card/strategy players |
| **Time availability** | Short matches on mobile/Web; longer deckbuilding and ranked sessions on desktop |
| **Platform preference** | PC for deckbuilding and serious play, mobile/Web for convenient sessions |
| **Current games they play** | Hearthstone, Yu-Gi-Oh! Master Duel, Marvel Snap, Legends of Runeterra-style card games |
| **What they're looking for** | A fair, readable card battler with meaningful deck identity and tactical outplay |
| **What would turn them away** | Unclear rules, pay-to-win collection pressure, slow matches, unreadable mobile UI, unreliable networking |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4.6.3 with GDScript for Web-compatible first-party clients |
| **Key Technical Challenges** | Deterministic card engine, authoritative multiplayer, replay/action logs, cross-platform UI density, content pipeline, balance tooling |
| **Art Style** | Stylized 2D card/UI-first art direction to control scope and preserve cross-platform readability |
| **Art Pipeline Complexity** | Medium if using custom 2D cards/UI; high if each card requires bespoke illustration and animation |
| **Audio Needs** | Moderate: UI feedback, card impact stingers, match ambience |
| **Networking** | Undecided; likely server-authoritative for production PvP, local simulation for prototype |
| **Content Volume** | MVP can start with 20-40 placeholder cards; production scope depends on format and monetization |
| **Procedural Systems** | None required for MVP; card generation tools may support development but should not define live gameplay initially |

---

## Risks and Open Questions

### Design Risks

- The game may feel too derivative unless the unique hook is validated early.
- Deep interaction timing can become unreadable on small screens.
- Deckbuilding depth and short-session pacing may pull in opposite directions.

### Technical Risks

- Deterministic multiplayer and replay correctness are non-trivial and must be designed before production code.
- Godot Web export constraints make GDScript the practical first-party client language if Web remains in scope.
- Server-authoritative PvP likely requires backend infrastructure outside the Godot client.

### Market Risks

- Digital card battlers compete with established IP, large card pools, and mature live operations.
- Fair monetization can reduce short-term revenue options but is important for trust.

### Scope Risks

- "Full platform" can explode scope if interpreted as simultaneous PC, Web, iOS, Android, and console launch.
- Card content, balance, ranked play, cosmetics, and live operations each become major production tracks.

### Open Questions

- What is the unique hook that makes this not just Hearthstone/Yu-Gi-Oh! in Godot?
- Is MVP local-only, AI-only, peer-hosted, or server-authoritative?
- What monetization model preserves competitive fairness?
- What art direction can support many cards without unsustainable asset cost?

---

## MVP Definition

**Core hypothesis**: Players will enjoy a readable, deterministic 1v1 card match loop with meaningful deck identity and enough interaction depth to justify repeated play.

**Required for MVP**:

1. Local deterministic duel loop with placeholder assets and a small curated card set.
2. Deck validation and at least two distinct archetypes.
3. Turn/action/effect resolution with replayable action log.
4. Mouse and touch board interaction.
5. Prototype hook selection: one differentiating mechanic implemented and playtested.

**Explicitly NOT in MVP**:

- Ranked ladder, seasons, battle pass, store, or live economy.
- Large production card pool.
- Final card art or premium VFX.
- Console export.
- Production matchmaking unless the multiplayer architecture ADR explicitly pulls it into MVP.

### Scope Tiers

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 20-40 placeholder cards, 2 archetypes | Local deterministic duel, deck validation, replay log, mouse/touch UI | 4-8 weeks |
| **Vertical Slice** | 40-60 styled cards, 3-4 archetypes | Polished match flow, tutorial/training, one online path if architecture is approved | 8-16 weeks |
| **Alpha** | Full first format placeholder-complete | Account/profile, matchmaking path, balance tooling, automated tests, content pipeline | 4-8 months |
| **Full Vision** | Production card set, live format support | Ranked/casual, seasons, cosmetics/economy, social features, multi-client exports | 12+ months |

---

## Next Steps

- [ ] Run `/art-bible` to establish visual identity before asset production.
- [ ] Run `/prototype card-resolution-loop` to validate deterministic match feel before full system GDDs.
- [ ] Run `/map-systems` to decompose card rules, deckbuilding, match flow, networking, UI, content pipeline, and progression.
- [ ] Run `/design-system card-rules` as the first detailed system GDD.
- [ ] Run `/architecture-decision` for match authority and deterministic replay before multiplayer implementation.
- [ ] Run `/test-setup` before implementing core rules.
