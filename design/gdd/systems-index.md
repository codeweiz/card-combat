# Systems Index: Card Combat

> **Status**: Draft
> **Created**: 2026-06-17
> **Last Updated**: 2026-06-17
> **Source Concept**: design/gdd/game-concept.md
> **Prototype Evidence**: prototypes/lane-stack-duel-concept/
> **Review Mode**: lean

---

## Overview

Card Combat needs a deterministic, inspectable card-battle foundation before it needs live-service features. The MVP should prove that a local 1v1 duel can run from card data, validate legal actions, resolve lane and response-stack decisions, and replay from an ordered action log. The `Lane-plus-stack` prototype produced enough tactical signal to remain the leading hook, but its response-resource rule needs another focused iteration before the hook is locked for production.

This index intentionally separates the game into small systems so design, architecture, tests, and Godot implementation can advance in a safe order. Multiplayer, accounts, economy, ranked play, and live operations are real full-vision needs, but they should not enter MVP until deterministic local play is proven.

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | Godot Project Foundation | Core | MVP | Designed | design/gdd/godot-project-foundation.md | - |
| 2 | Deterministic Simulation Core | Core | MVP | In Implementation | design/gdd/deterministic-simulation-core.md | Godot Project Foundation |
| 3 | Card Data Model | Core | MVP | In Implementation | design/gdd/card-data-model.md | Deterministic Simulation Core |
| 4 | Zone and Lane Board System | Gameplay | MVP | In Implementation | design/gdd/zone-lane-board-system.md | Deterministic Simulation Core, Card Data Model |
| 5 | Turn, Timing, and Resource System | Gameplay | MVP | Designed | design/gdd/turn-timing-resource-system.md | Deterministic Simulation Core, Card Data Model |
| 6 | Stack and Response System | Gameplay | MVP | In Implementation | design/gdd/stack-response-system.md | Turn, Timing, and Resource System |
| 7 | Card Effect Resolution System | Gameplay | MVP | In Implementation | design/gdd/card-effect-resolution-system.md | Zone and Lane Board System, Stack and Response System |
| 8 | Action Log and Replay System | Persistence | MVP | Designed | design/gdd/action-log-replay-system.md | Deterministic Simulation Core, Card Effect Resolution System |
| 9 | Deck Construction and Validation | Gameplay | MVP | Designed | design/gdd/deck-construction-validation.md | Card Data Model |
| 10 | Prototype Card Set and Archetypes | Gameplay | MVP | Designed | design/gdd/prototype-card-set-archetypes.md | Card Data Model, Deck Construction and Validation |
| 11 | Local Match Flow | Core | MVP | Designed | design/gdd/local-match-flow.md | Deck Construction and Validation, Action Log and Replay System |
| 12 | Match Board UI and Input | UI | MVP | Designed | design/gdd/match-board-ui-input.md | Local Match Flow, Zone and Lane Board System |
| 13 | Cross-Platform Interaction Layer | UI | MVP | Designed | design/gdd/cross-platform-interaction-layer.md | Match Board UI and Input |
| 14 | Determinism Test Harness | Meta | MVP | Designed | design/gdd/determinism-test-harness.md | Action Log and Replay System |
| 15 | AI Training Opponent | Gameplay | Vertical Slice | Not Started | - | Local Match Flow, Card Effect Resolution System |
| 16 | Tutorial and Rules Explanation | UI | Vertical Slice | Not Started | - | Match Board UI and Input, Card Effect Resolution System |
| 17 | Menu and Navigation Shell | UI | Vertical Slice | Not Started | - | Godot Project Foundation, Cross-Platform Interaction Layer |
| 18 | Card Frame and Visual Identity System | UI | Vertical Slice | Not Started | - | Match Board UI and Input |
| 19 | Audio Feedback System | Audio | Vertical Slice | Not Started | - | Card Effect Resolution System, Match Board UI and Input |
| 20 | Localization and Text Layout | UI | Vertical Slice | Not Started | - | Card Data Model, Match Board UI and Input |
| 21 | Accessibility and Focus Navigation | UI | Vertical Slice | Not Started | - | Cross-Platform Interaction Layer, Menu and Navigation Shell |
| 22 | Match Authority Architecture | Core | Alpha | Not Started | - | Deterministic Simulation Core, Action Log and Replay System |
| 23 | Online Networking and Synchronization | Core | Alpha | Not Started | - | Match Authority Architecture, Local Match Flow |
| 24 | Lobby and Matchmaking | Meta | Alpha | Not Started | - | Online Networking and Synchronization |
| 25 | Player Profile and Persistence | Persistence | Alpha | Not Started | - | Menu and Navigation Shell |
| 26 | Card Collection and Inventory | Progression | Alpha | Not Started | - | Player Profile and Persistence, Card Data Model |
| 27 | Balance and Content Tooling | Meta | Alpha | Not Started | - | Card Data Model, Determinism Test Harness |
| 28 | Content Pipeline | Meta | Alpha | Not Started | - | Card Data Model, Card Frame and Visual Identity System |
| 29 | Progression and Fair Economy | Progression | Full Vision | Not Started | - | Player Profile and Persistence, Card Collection and Inventory |
| 30 | Ranked and Seasonal Formats | Meta | Full Vision | Not Started | - | Lobby and Matchmaking, Balance and Content Tooling |
| 31 | Social, Spectator, and Deck Sharing | Meta | Full Vision | Not Started | - | Online Networking and Synchronization, Player Profile and Persistence |
| 32 | Live Operations and Telemetry | Meta | Full Vision | Not Started | - | Player Profile and Persistence, Online Networking and Synchronization |

---

## Categories

| Category | Description | Systems In This Project |
|----------|-------------|-------------------------|
| **Core** | Foundation systems everything depends on | Godot project, deterministic simulation, local match flow, match authority, networking |
| **Gameplay** | The systems that make the duel interesting | Lane board, timing/resources, response stack, effect resolution, decks, prototype cards, AI |
| **Progression** | How the player grows over time | Collection, inventory, progression, fair economy |
| **Persistence** | State that must survive sessions | Action logs, replays, player profile |
| **UI** | Player-facing interaction and information | Match board, cross-platform input, menus, tutorial, visual identity, localization, accessibility |
| **Audio** | Sound and music systems | Audio feedback for card, lane, and match events |
| **Meta** | Production, competitive, and operational systems | Tests, tooling, matchmaking, ranked formats, social features, telemetry |

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Required for a local deterministic duel and first Godot playable prototype | First playable prototype | Design first |
| **Vertical Slice** | Required for one polished, teachable, cross-platform match experience | Vertical slice / demo | Design second |
| **Alpha** | Required for online play, account-backed content, and production content workflows | Alpha milestone | Design third |
| **Full Vision** | Live-service, competitive, monetization, and community systems | Beta / release | Design after the core loop proves itself |

---

## Dependency Map

### Foundation Layer

1. **Godot Project Foundation** — establishes project file, scene layout, export assumptions, and GDScript conventions.
2. **Deterministic Simulation Core** — pure simulation layer that must not depend on UI or networking.
3. **Card Data Model** — typed definitions for cards, effects, costs, speeds, text, and localization keys.

### Core Layer

1. **Zone and Lane Board System** — depends on simulation and card data; owns lanes, units, players, and board occupancy.
2. **Turn, Timing, and Resource System** — depends on simulation and card data; owns active player, priority windows, and resource rules.
3. **Deck Construction and Validation** — depends on card data; ensures matches start from legal decks.
4. **Stack and Response System** — depends on turn/timing; owns response windows and chain constraints.

### Feature Layer

1. **Card Effect Resolution System** — depends on board state and stack timing; turns card data into deterministic outcomes.
2. **Action Log and Replay System** — depends on effect resolution; records all accepted player intentions and outcomes.
3. **Prototype Card Set and Archetypes** — depends on card data and deck validation; supplies MVP test content.
4. **Local Match Flow** — depends on decks, replay, and rules; provides a complete local duel loop.
5. **AI Training Opponent** — depends on local match flow and effect resolution; supports solo testing.

### Presentation Layer

1. **Match Board UI and Input** — depends on local match flow and lane state; displays legal actions and resolved state.
2. **Cross-Platform Interaction Layer** — depends on match UI; unifies mouse, touch, keyboard, and later gamepad navigation.
3. **Tutorial and Rules Explanation** — depends on match UI and rules; teaches timing, targeting, and lane decisions.
4. **Menu and Navigation Shell** — depends on Godot foundation and input layer; connects match, deck, settings, and future online screens.
5. **Card Frame and Visual Identity System** — depends on match UI; controls card readability and art production constraints.
6. **Audio Feedback System** — depends on resolved gameplay events and UI events.
7. **Localization and Text Layout** — depends on card data and UI; keeps card text readable across languages and devices.
8. **Accessibility and Focus Navigation** — depends on input layer and menus; ensures required actions are not pointer-only.

### Production and Online Layer

1. **Determinism Test Harness** — depends on action logs and simulation; catches replay drift.
2. **Match Authority Architecture** — depends on deterministic simulation and replay logs; defines trust boundaries.
3. **Online Networking and Synchronization** — depends on authority architecture and local match flow.
4. **Lobby and Matchmaking** — depends on online networking.
5. **Player Profile and Persistence** — depends on menu shell; becomes the base for accounts, collection, and settings.
6. **Card Collection and Inventory** — depends on player profile and card data.
7. **Balance and Content Tooling** — depends on card data and tests.
8. **Content Pipeline** — depends on card data and visual identity.

### Full Vision Layer

1. **Progression and Fair Economy** — depends on profile and collection.
2. **Ranked and Seasonal Formats** — depends on matchmaking and balance tooling.
3. **Social, Spectator, and Deck Sharing** — depends on networking and profile.
4. **Live Operations and Telemetry** — depends on profile and networking.

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | Deterministic Simulation Core | MVP | Foundation | gameplay-programmer, systems-designer | M |
| 2 | Card Data Model | MVP | Foundation | gameplay-programmer, tools-programmer | M |
| 3 | Turn, Timing, and Resource System | MVP | Core | systems-designer, gameplay-programmer | M |
| 4 | Zone and Lane Board System | MVP | Core | systems-designer, gameplay-programmer | M |
| 5 | Stack and Response System | MVP | Core | systems-designer, gameplay-programmer | L |
| 6 | Card Effect Resolution System | MVP | Feature | gameplay-programmer, systems-designer | L |
| 7 | Action Log and Replay System | MVP | Feature | gameplay-programmer, qa-lead | M |
| 8 | Deck Construction and Validation | MVP | Core | systems-designer, gameplay-programmer | M |
| 9 | Prototype Card Set and Archetypes | MVP | Feature | systems-designer | S |
| 10 | Local Match Flow | MVP | Feature | gameplay-programmer | M |
| 11 | Godot Project Foundation | MVP | Foundation | godot-specialist, gameplay-programmer | S |
| 12 | Match Board UI and Input | MVP | Presentation | ui-programmer, ux-designer | L |
| 13 | Cross-Platform Interaction Layer | MVP | Presentation | ui-programmer, ux-designer | M |
| 14 | Determinism Test Harness | MVP | Production | qa-lead, gameplay-programmer | M |
| 15 | AI Training Opponent | Vertical Slice | Feature | ai-programmer, gameplay-programmer | M |
| 16 | Tutorial and Rules Explanation | Vertical Slice | Presentation | ux-designer, writer | M |
| 17 | Menu and Navigation Shell | Vertical Slice | Presentation | ui-programmer | M |
| 18 | Card Frame and Visual Identity System | Vertical Slice | Presentation | art-director, ui-programmer | M |
| 19 | Localization and Text Layout | Vertical Slice | Presentation | localization-lead, ui-programmer | M |
| 20 | Accessibility and Focus Navigation | Vertical Slice | Presentation | accessibility-specialist, ui-programmer | M |
| 21 | Audio Feedback System | Vertical Slice | Presentation | sound-designer, audio-director | S |
| 22 | Match Authority Architecture | Alpha | Production and Online | technical-director, network-programmer | L |
| 23 | Online Networking and Synchronization | Alpha | Production and Online | network-programmer | L |
| 24 | Lobby and Matchmaking | Alpha | Production and Online | network-programmer, backend engineer | L |
| 25 | Player Profile and Persistence | Alpha | Production and Online | gameplay-programmer, backend engineer | M |
| 26 | Card Collection and Inventory | Alpha | Production and Online | systems-designer, gameplay-programmer | M |
| 27 | Balance and Content Tooling | Alpha | Production and Online | tools-programmer, systems-designer | L |
| 28 | Content Pipeline | Alpha | Production and Online | tools-programmer, technical-artist | M |
| 29 | Progression and Fair Economy | Full Vision | Full Vision | economy-designer, producer | L |
| 30 | Ranked and Seasonal Formats | Full Vision | Full Vision | live-ops-designer, network-programmer | L |
| 31 | Social, Spectator, and Deck Sharing | Full Vision | Full Vision | community-manager, network-programmer | L |
| 32 | Live Operations and Telemetry | Full Vision | Full Vision | live-ops-designer, analytics-engineer | L |

---

## Circular Dependencies

- **Match Board UI and Input <-> Card Effect Resolution System**: UI needs legal-action explanations from the rules engine, while the rules engine needs clear UI-facing legality results. Resolve with a rules query interface that returns legal actions, target sets, preview data, and failure reasons without importing UI code.
- **Match Authority Architecture <-> Online Networking and Synchronization**: Networking needs authority decisions, and authority decisions must account for network constraints. Resolve by writing the match authority ADR before implementation, then treating networking as an adapter around deterministic simulation and action logs.
- **Card Data Model <-> Localization and Text Layout**: Card text keys belong in data, but layout constraints shape how effects are worded. Resolve by requiring localization keys and short rules text fields in card data from the start.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|------------------|------------|
| Stack and Response System | Design | Can become too slow or opaque on mobile if every action opens a confusing timing window. | Run a second Paper prototype with dedicated response `focus`, then write a narrow timing GDD. |
| Card Effect Resolution System | Technical | Untyped or ad hoc effects will make replay, validation, and tooling fragile. | Use typed effect commands/resources and require tests before adding many cards. |
| Action Log and Replay System | Technical | Replay drift breaks trust in deterministic multiplayer. | Build replay tests as part of MVP, not after networking. |
| Match Board UI and Input | UX | Card text, lane state, and response prompts may overflow on mobile. | Prototype responsive board layout early in Godot with placeholder cards. |
| Match Authority Architecture | Technical | Server-authoritative PvP likely requires backend infrastructure outside the Godot client. | Write ADR before online implementation; keep MVP local until authority model is approved. |
| Balance and Content Tooling | Scope | Large card pools become unmaintainable without tooling. | Keep MVP card pool small and data-driven; add tooling before Alpha content expansion. |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 32 |
| Design docs started | 14 |
| Design docs reviewed | 14 |
| Design docs approved | 13 |
| MVP systems designed | 14/14 |
| Vertical Slice systems designed | 0/7 |

---

## Review Evidence

| Review Artifact | Result | Notes |
|-----------------|--------|-------|
| `design/gdd/gdd-cross-review-2026-06-17.md` | CONCERNS | No blocking cross-GDD contradiction; follow-up resolved most concerns, prototype card content remains open |
| `design/gdd/reviews/individual-review-summary-2026-06-17.md` | CONCERNS | 14 lean single-session GDD reviews complete; 13 approved and 1 needs revision after same-day fixes |

### Individual Review Verdicts

| GDD | Verdict |
|-----|---------|
| `design/gdd/godot-project-foundation.md` | APPROVED |
| `design/gdd/deterministic-simulation-core.md` | APPROVED |
| `design/gdd/card-data-model.md` | APPROVED |
| `design/gdd/turn-timing-resource-system.md` | APPROVED |
| `design/gdd/zone-lane-board-system.md` | APPROVED |
| `design/gdd/stack-response-system.md` | APPROVED |
| `design/gdd/card-effect-resolution-system.md` | APPROVED |
| `design/gdd/action-log-replay-system.md` | APPROVED |
| `design/gdd/deck-construction-validation.md` | APPROVED |
| `design/gdd/prototype-card-set-archetypes.md` | NEEDS REVISION |
| `design/gdd/local-match-flow.md` | APPROVED |
| `design/gdd/match-board-ui-input.md` | APPROVED |
| `design/gdd/cross-platform-interaction-layer.md` | APPROVED |
| `design/gdd/determinism-test-harness.md` | APPROVED |

---

## Next Steps

- [x] Accept `RESPONSE_FOCUS_PER_OPPONENT_TURN = 2` as the first-playable MVP risk value; validate after Godot playable.
- [x] Draft `/design-system godot-project-foundation`.
- [x] Run lean `/design-review design/gdd/godot-project-foundation.md`; review log written.
- [x] Draft `/design-system deterministic-simulation-core`.
- [x] Run lean `/design-review design/gdd/deterministic-simulation-core.md`; same-day re-review approved.
- [x] Draft `/design-system card-data-model`.
- [x] Run lean `/design-review design/gdd/card-data-model.md`; same-day re-review approved.
- [x] Scaffold Godot project and first deterministic simulation/card data scripts.
- [x] Run `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/smoke/smoke_deterministic_core.gd`.
- [x] Draft `/design-system turn-timing-resource-system`.
- [x] Run lean `/design-review design/gdd/turn-timing-resource-system.md`; same-day re-review approved.
- [x] Draft `/design-system zone-lane-board-system`.
- [x] Run lean `/design-review design/gdd/zone-lane-board-system.md`; review log written.
- [x] Draft `/design-system stack-response-system`.
- [x] Run lean `/design-review design/gdd/stack-response-system.md`; review log written.
- [x] Expand the deterministic core skeleton with pending original action and `pass_response` flow.
- [x] Draft `/design-system card-effect-resolution-system`.
- [x] Run lean `/design-review design/gdd/card-effect-resolution-system.md`; review log written.
- [x] Write ADR-0002 for MVP Card Effect Resolution Architecture.
- [x] Expand the deterministic core skeleton with typed `cancel_original` response effect resolution.
- [x] Reverse-document ADR-0003 for MVP Lane Board and Response Window State Architecture.
- [x] Draft `/design-system action-log-replay-system`.
- [x] Run lean `/design-review design/gdd/action-log-replay-system.md`; same-day re-review approved.
- [x] Draft `/design-system deck-construction-validation`.
- [x] Run lean `/design-review design/gdd/deck-construction-validation.md`; review log written.
- [x] Draft `/design-system prototype-card-set-archetypes`.
- [x] Run lean `/design-review design/gdd/prototype-card-set-archetypes.md`; needs revision.
- [x] Draft `/design-system local-match-flow`.
- [x] Run lean `/design-review design/gdd/local-match-flow.md`; review log written.
- [x] Draft `/design-system match-board-ui-input`.
- [x] Run lean `/design-review design/gdd/match-board-ui-input.md`; same-day re-review approved.
- [x] Draft `/design-system cross-platform-interaction-layer`.
- [x] Run lean `/design-review design/gdd/cross-platform-interaction-layer.md`; same-day re-review approved.
- [x] Draft `/design-system determinism-test-harness`.
- [x] Run lean `/design-review design/gdd/determinism-test-harness.md`; review log written.
- [x] Run `/review-all-gdds` after MVP system GDDs are drafted.
- [ ] Resolve or accept individual and cross-GDD review concerns from `design/gdd/reviews/individual-review-summary-2026-06-17.md` and `design/gdd/gdd-cross-review-2026-06-17.md`.
- [ ] Run `/gate-check systems-design` after MVP GDD reviews are complete.
- [x] Expand the deterministic core skeleton with first lane placement and board occupancy mutation.

---

## Lean Review Notes

`TD-SYSTEM-BOUNDARY`, `PR-SCOPE`, and `CD-SYSTEMS` were skipped because `production/review-mode.txt` is set to `lean`. A formal `/gate-check systems-design` should be run before treating this index as approved.
