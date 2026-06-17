# ADR-0002: MVP Card Effect Resolution Architecture

## Status

Accepted

## Date

2026-06-17

## Last Verified

2026-06-17

## Decision Makers

Codex acting under user authorization.

## Summary

MVP card effects will resolve through a scene-independent `CardEffectResolver` service that interprets typed `EffectRef` data and returns deterministic effect outcomes. Card definitions stay immutable Resource data, while match state remains owned by the deterministic simulation core.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | HIGH - Godot 4.6.3 is post-cutoff and must be verified against local engine docs |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/current-best-practices.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None intentionally required for MVP effect resolution |
| **Verification Required** | Run headless Godot script/class loading once Godot 4.6.3 is installed locally |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001: MVP Deterministic Card Simulation Architecture |
| **Enables** | Future ADRs for action log/replay event schema, content pipeline, match authority, and online synchronization |
| **Blocks** | Production implementation of complex card effects until accepted |
| **Ordering Note** | This ADR must wrap ADR-0001's deterministic core boundary and must not replace match-state ownership. |

## Context

### Problem Statement

Card Combat needs card behavior that is data-driven, replayable, and inspectable. The Card Data Model already stores `EffectRef` objects, and the Stack and Response System now needs response effects such as `cancel_original` to resolve before pending original actions. Without a dedicated effect resolver, card behavior would drift into ad hoc command branches or untyped dictionaries.

### Constraints

- Godot version is pinned to 4.6.3.
- Client code language is GDScript for Web compatibility.
- Core match simulation must remain scene-independent and deterministic.
- Match state is owned by `DeterministicSimulationCore` and mutated only inside accepted transition batches.
- Card definitions are immutable Resource data.
- Runtime card effects must not be executable script text embedded in card data.
- Runtime effect params must not be raw untyped dictionaries.
- MVP core state must use integers, enums, booleans, arrays, and dictionaries with canonical ordering; floating point values are forbidden.

### Requirements

- Resolve `EffectRef` lists in card-data order.
- Support typed parameter resources for MVP effect schemas.
- Support response effects that cancel pending original stack items.
- Support future damage, heal, movement, and destruction effects without changing the public command boundary.
- Emit deterministic effect outcome events for UI, replay, and diagnostics.
- Keep effect resolution testable without loading match UI scenes.

## Decision

Implement MVP card effects as a `CardEffectResolver` `RefCounted` service invoked by `DeterministicSimulationCore` during accepted command or stack-item resolution.

Effect behavior will be selected by explicit `effect_id` values on `EffectRef`. Each effect that requires parameters uses a typed `EffectParams` subclass. The resolver reads immutable `CardDefinition` data through `CardDatabase`, reads and writes match-owned state only through objects passed by the deterministic core, and returns ordered string events for the current skeleton. A later Action Log and Replay ADR should replace string events with structured event objects.

Initial MVP effect ids:

- `cancel_original`: marks the pending original stack item canceled when a response resolves against an allowed command type.
- `deal_damage`: reserved effect schema for integer damage to units or players.
- `heal_unit`: reserved effect schema for integer unit healing.
- `move_unit_adjacent`: reserved effect schema for adjacent lane movement.

The first implementation will wire `cancel_original` so response cards can prove response-first resolution. Damage, healing, and movement are designed now but may be implemented incrementally as their commands/cards enter the playable prototype.

### Architecture Diagram

```text
DeterministicSimulationCore
        |
        | resolves accepted command / stack item
        v
CardEffectResolver
        |
        | reads immutable card definition
        v
CardDatabase -> CardDefinition -> EffectRef -> typed EffectParams
        |
        | mutates only state passed by core
        v
MatchState -> ResponseWindowState / BoardState
```

### Key Interfaces

```gdscript
class_name CardEffectResolver
extends RefCounted

func resolve_card_effects(
	definition: CardDefinition,
	state: MatchState,
	source_item: StackItem
) -> Array[String]
```

```gdscript
class_name CancelOriginalEffectParams
extends EffectParams

@export var allowed_command_types: Array[StringName]
```

### Ownership Rules

- `CardEffectResolver` owns effect interpretation and effect outcome generation.
- `DeterministicSimulationCore` owns when the resolver is invoked and when state hashes are computed.
- `BoardState` owns board invariants such as lane occupancy and unit destruction.
- `ResponseWindowState` owns pending original/response stack item state.
- Card data owns immutable `EffectRef` and typed params.

## Alternatives Considered

### Alternative 1: Hardcode effects directly in command handlers

- **Description**: Add `if command.card_id == ...` branches inside `DeterministicSimulationCore`.
- **Pros**: Fastest for the first one or two cards.
- **Cons**: Card behavior would be code-driven rather than data-driven, difficult to validate, and brittle for replay/content tooling.
- **Rejection Reason**: Conflicts with the Card Data Model and the project's ban on ad hoc card behavior.

### Alternative 2: Store executable script paths or callables in card data

- **Description**: Each card references a script or callable that mutates match state.
- **Pros**: Flexible and designer-extensible in the editor.
- **Cons**: Harder to validate, harder to port to server authority, easier to introduce scene-tree or time dependencies, and unsafe for deterministic replay.
- **Rejection Reason**: Conflicts with replay, authority, and typed validation requirements.

### Alternative 3: Use raw dictionaries for effect params

- **Description**: Store params as arbitrary dictionaries on `EffectRef`.
- **Pros**: Easy to serialize and quick to author.
- **Cons**: Typos become runtime behavior bugs, schemas are implicit, and tooling cannot reliably validate cards before match start.
- **Rejection Reason**: Explicitly forbidden by project technical preferences for card effects.

## Consequences

### Positive

- Card behavior has a single deterministic interpretation boundary.
- Effect schemas can be validated before matches start.
- Response cards can resolve through the same mechanism as main cards.
- Future replay and authority systems can consume stable effect outcome events.
- Effect code remains testable without UI scenes.

### Negative

- More small typed classes are required before many cards can be authored.
- Early prototype content must fit approved effect schemas or wait for schema expansion.
- String events are a temporary skeleton and need a later structured event model.

### Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Effect schema list grows too quickly | Medium | High | Keep MVP schemas narrow and add tooling before large content batches |
| String event format becomes sticky | Medium | Medium | Require Action Log and Replay GDD/ADR to define structured events |
| Resolver gains direct ownership of board or stack state | Medium | High | Keep ownership rules in registry and validate via architecture review |
| GDScript Resource typing differs in Godot 4.6.3 | Low | Medium | Run headless Godot class loading once engine is on PATH |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `design/gdd/card-effect-resolution-system.md` | Effects must interpret typed `EffectRef` data and emit deterministic outcomes | Creates `CardEffectResolver` and typed effect params |
| `design/gdd/card-effect-resolution-system.md` | `cancel_original` must mark pending original stack items canceled | Defines `cancel_original` as the first wired MVP effect |
| `design/gdd/card-data-model.md` | Card behavior must be referenced by effect id and typed params, not executable script text | Keeps effect ids and `EffectParams` resources as the data contract |
| `design/gdd/stack-response-system.md` | Responses resolve before original actions and can cancel/fizzle originals | Resolver is invoked during response stack resolution |
| `design/gdd/deterministic-simulation-core.md` | Core transition batches must remain deterministic and scene-independent | Uses `RefCounted` resolver with no scene tree or time dependency |
| `design/gdd/zone-lane-board-system.md` | Damage, healing, movement, and destruction must respect board invariants | Resolver delegates board legality to board-owned APIs |

## Performance Implications

- **CPU**: Full MVP effect batch must resolve within 100ms before presentation animation.
- **Memory**: Small typed Resource params and transient resolver objects; no per-frame allocation requirement.
- **Load Time**: Card database validation may do more schema checks before match start.
- **Network**: No direct network use. Future authority should send commands and effect outcome hashes/events, not client-owned outcomes.

## Migration Plan

1. Add typed `EffectParams` subclasses for initial schemas.
2. Add `CardEffectResolver` under `src/core/card/`.
3. Invoke resolver from `DeterministicSimulationCore` when a response stack item resolves.
4. Update smoke script to include a response card with `cancel_original`.
5. Later, move string events to structured event objects through Action Log and Replay design.

## Validation Criteria

- [ ] Core classes load in Godot 4.6.3 without parse errors.
- [ ] Card database validation rejects incompatible typed effect params.
- [ ] A response card with `cancel_original` cancels a pending original command.
- [ ] A canceled original command does not mutate board state.
- [ ] Replaying the same response/cancel sequence produces the same final hash.
- [ ] Production source does not import files from `prototypes/`.
- [ ] Effect resolver code does not depend on `_process`, scene tree state, wall-clock time, or frame delta.

## Related Decisions

- `docs/architecture/adr-0001-mvp-deterministic-card-simulation.md`
- `design/gdd/card-effect-resolution-system.md`
- `design/gdd/card-data-model.md`
- `design/gdd/stack-response-system.md`
- `design/gdd/zone-lane-board-system.md`
