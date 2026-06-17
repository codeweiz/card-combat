# Active Session State

Task: Godot Project Foundation GDD
Status: In implementation; Godot 4.6.3 available at `/Applications/Godot.app/Contents/MacOS/Godot`
Concept: Card Combat
Path: Prototype-first into Systems Design
Current Phase: Technical Setup + Systems Design

## Hypothesis

If players deploy units across three lanes and hold a small number of response cards to interrupt opponent actions, each match will create clear tactical pressure around lane commitment and timing.

Success signal:

- At least 3 non-obvious decisions in one simulated match.
- Readable lane state after every action.
- Complete action log can replay the same result from the starting state.

## Files

- `production/project-stage-report.md`
- `prototypes/lane-stack-duel-concept/rules.md`
- `prototypes/lane-stack-duel-concept/play-log.md`
- `prototypes/lane-stack-duel-concept/PIVOT-NOTE.md`
- `prototypes/index.md`
- `design/gdd/systems-index.md`
- `design/gdd/godot-project-foundation.md`
- `design/gdd/deterministic-simulation-core.md`
- `design/gdd/card-data-model.md`
- `design/gdd/turn-timing-resource-system.md`
- `design/gdd/zone-lane-board-system.md`
- `design/gdd/stack-response-system.md`
- `design/gdd/card-effect-resolution-system.md`
- `design/gdd/action-log-replay-system.md`
- `design/gdd/deck-construction-validation.md`
- `design/gdd/prototype-card-set-archetypes.md`
- `design/gdd/local-match-flow.md`
- `design/gdd/match-board-ui-input.md`
- `design/gdd/cross-platform-interaction-layer.md`
- `design/gdd/determinism-test-harness.md`
- `design/gdd/gdd-cross-review-2026-06-17.md`
- `design/gdd/reviews/individual-review-summary-2026-06-17.md`
- `design/gdd/reviews/`
- `docs/architecture/adr-0001-mvp-deterministic-card-simulation.md`
- `docs/architecture/adr-0002-mvp-card-effect-resolution-architecture.md`
- `docs/architecture/adr-0003-mvp-lane-board-and-response-window-state.md`
- `docs/registry/architecture.yaml`
- `project.godot`
- `src/core/stable_hash.gd`
- `src/core/card/`
- `src/core/simulation/`
- `tools/smoke/smoke_deterministic_core.gd`

## Current Result

The first play log produced meaningful lane and response decisions, but it also exposed an unclear response-resource model. Preliminary recommendation is PIVOT within the same hook, not kill.

The project now has a draft systems index with 32 identified systems and 14 MVP systems. All 14 MVP systems are drafted: `Godot Project Foundation`, `Deterministic Simulation Core`, `Card Data Model`, `Turn, Timing, and Resource System`, `Zone and Lane Board System`, `Stack and Response System`, `Card Effect Resolution System`, `Action Log and Replay System`, `Deck Construction and Validation`, `Prototype Card Set and Archetypes`, `Local Match Flow`, `Match Board UI and Input`, `Cross-Platform Interaction Layer`, and `Determinism Test Harness`. A lean single-session cross-GDD review report exists at `design/gdd/gdd-cross-review-2026-06-17.md` with verdict `CONCERNS`: no blocking cross-document contradiction found and future GDD references should remain provisional until authored. Same-day revisions resolved the earlier individual-review blockers for SHA-256 canonical hashing, immutable canonical snapshots, `.tres` Resource card authoring, response type/speed, accepted response focus risk, main-resource refresh, structured replay events, match board layout/focus routes, and input bindings/gamepad scope. Lean single-session individual design reviews now exist under `design/gdd/reviews/`, summarized in `design/gdd/reviews/individual-review-summary-2026-06-17.md`: 14/14 MVP GDDs reviewed, 13 approved, 1 needs revision. The remaining NEEDS REVISION GDD is `prototype-card-set-archetypes.md`, because first-playable content still lacks a 24-card runnable pool and sample decks still include design-only cards. Systems Design gate remains blocked until that content gap is revised or explicitly accepted as an MVP risk. The Godot Project Foundation GDD defines the project shell contract around Godot 4.6.3, `project.godot`, source/test/prototype isolation, engine reference docs, headless smoke, platform baseline, warning settings, and renderer fallback. The first GDScript implementation skeleton covers project setup, card data, SHA-256 deterministic state hashing, command validation, immutable canonical state snapshots, lane board state, pending response windows, `pass_response`, typed effect params, `cancel_original` response effects, unit placement after pass, duplicate same-lane placement rejection, and a smoke script. ADR-0003 now reverse-documents the implemented lane board, runtime unit, response window, and stack item state architecture, and `docs/registry/architecture.yaml` has matching state ownership, interface, performance budget, API decision, and forbidden-pattern entries. Current implementation gaps remain: gate-check, `MatchSetup` per-player validated deck loadouts, ordered deck ids, opening hand/deck state, phase flow, attack commands, surrender/empty-deck loss, terminal win logic, replay log persistence, actual MatchBoard UI scenes, Godot input action maps, focus routes, gesture handling, layout readiness checks, determinism fixtures, action-log replay runner, formal test framework, export presets, and CI test gates before first playable. Godot is not on PATH, but `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/smoke/smoke_deterministic_core.gd` passes with final hash `e530e326a67c19fa5b6c181cd973937bbf57d5bea142389d0ccb6825517b2df3`.

## Next

1. Continue using `/Applications/Godot.app/Contents/MacOS/Godot` for local headless checks unless Godot is added to PATH.
2. Revise or explicitly accept the remaining Prototype Card Set content blocker in `design/gdd/reviews/individual-review-summary-2026-06-17.md`.
3. Resolve or explicitly accept remaining cross-GDD review concerns from `design/gdd/gdd-cross-review-2026-06-17.md`, especially provisional future GDD references.
4. Re-run `/design-review design/gdd/prototype-card-set-archetypes.md` after substantive content revision.
5. Run `/gate-check systems-design` after the prototype card set blocker is resolved.
6. Expand effect implementation beyond `cancel_original`: damage, healing, adjacent movement, destruction, and structured effect event objects.
7. Add per-player validated deck loadout data, ordered deck ids, opening hand/deck state, phase flow, attack commands, surrender/empty-deck loss, terminal win logic, replay log persistence, MatchBoard scenes, input action maps, focus routes, gesture handling, layout readiness checks, determinism fixtures, action-log replay runner, formal test framework, export presets, and CI test gates before first playable.
8. If continuing design after MVP review revisions, start `design/gdd/ai-training-opponent.md`.

## Session Extract — /review-all-gdds 2026-06-17

- Verdict: CONCERNS
- GDDs reviewed: 14 MVP system GDDs plus game concept and systems index
- Flagged for revision: None blocking; warning-level follow-ups in systems-index, turn-timing-resource-system, action-log-replay-system, determinism-test-harness
- Blocking issues: None
- Recommended next: run individual fresh-session `/design-review` passes for MVP GDDs, then `/gate-check systems-design`
- Report: design/gdd/gdd-cross-review-2026-06-17.md

## Session Extract - /design-review lean batch 2026-06-17

- Mode: lean single-session individual reviews, no specialist subagents spawned
- GDDs reviewed: 14/14 MVP system GDDs
- Approved: 13 after same-day re-review fixes
- Needs revision: 1
- Approved GDDs: godot-project-foundation, deterministic-simulation-core, card-data-model, turn-timing-resource-system, zone-lane-board-system, stack-response-system, card-effect-resolution-system, action-log-replay-system, deck-construction-validation, local-match-flow, match-board-ui-input, cross-platform-interaction-layer, determinism-test-harness
- Needs revision GDDs: prototype-card-set-archetypes
- Resolved blocker themes: SHA-256 canonical serialization/hash, immutable canonical state snapshot, card authoring format and response type/speed decision, response focus/formula validation, structured replay event schema, concrete match board layouts/focus routes, and concrete input bindings/gamepad support scope
- Remaining blocker theme: playable 24-card content readiness and design-only cards in runnable sample deck profiles
- Report: design/gdd/reviews/individual-review-summary-2026-06-17.md
