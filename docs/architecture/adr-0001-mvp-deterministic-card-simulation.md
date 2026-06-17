# ADR-0001: MVP Deterministic Card Simulation Architecture

## Status

Accepted

## Date

2026-06-17

## Last Verified

2026-06-17

## Decision Makers

Codex acting under user authorization.

## Summary

The MVP card rules layer will be implemented as scene-independent, deterministic GDScript classes. Match state is owned only by the deterministic simulation core, while card definitions are immutable Resource data loaded through a card data model boundary.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | HIGH - Godot 4.6.3 is post-cutoff and must be verified against local engine docs |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/current-best-practices.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None intentionally required for MVP core rules |
| **Verification Required** | Run headless Godot script/class loading once Godot 4.6.3 is installed locally |

> **Note**: If the project upgrades Godot, re-validate this ADR before editing the simulation core.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | Future ADRs for match authority, replay persistence, content pipeline, and online synchronization |
| **Blocks** | Production implementation of deterministic simulation, card data, action replay, and match authority until accepted |
| **Ordering Note** | This ADR should be treated as the first architecture stance for MVP rules code. Later ADRs must wrap this core rather than bypass it. |

## Context

### Problem Statement

Card Combat is intended to become a cross-platform, multi-client competitive card battler. The game cannot trust client-submitted outcomes, and it must be able to replay action logs. The first implementation therefore needs a deterministic core boundary before UI, networking, or visual polish enter the codebase.

### Current State

The project has concept and systems documents, but no Godot project, no source code, and no ADRs. The first two MVP GDDs define a deterministic simulation core and card data model. `src/CLAUDE.md` requires every new code system to have a corresponding ADR.

### Constraints

- Godot version is pinned to 4.6.3.
- First-party clients target PC, Web, and Mobile.
- Client code language is GDScript for Web compatibility.
- Core match simulation must be replayable from setup data and accepted action commands.
- Core simulation must not depend on scene tree state, UI nodes, wall-clock time, frame delta, networking, or global random functions.
- Card behavior must not be represented as untyped dictionaries when typed data or command objects are needed.

### Requirements

- Support a local deterministic MVP duel before online play.
- Support canonical state hashes after accepted commands.
- Support immutable card definitions with data hashes.
- Support future server-authoritative validation without replacing the local rules implementation.
- Keep core rules testable without loading match UI scenes.
- Keep gameplay simulation event-driven rather than per-frame polling.

## Decision

Implement the MVP rules layer using three boundaries:

1. **Card Data Model**: typed `Resource` classes for immutable card definitions and effect references.
2. **Deterministic Simulation Core**: scene-independent `RefCounted` classes for match setup, commands, match state, validation, state transitions, state hashing, and replay-facing outputs.
3. **Presentation/Runtime Adapter**: future Node/Control scenes may call the simulation core, but they never own or directly mutate match state.

The simulation core will be pure GDScript and will not be an Autoload singleton. Runtime scenes or tests must instantiate and inject it directly. This keeps the rules layer usable by local Godot UI, headless tests, and future server/authority wrappers.

### Architecture

```text
Godot UI / Local Match Flow / Future Network Adapter
                 |
                 | submit ActionCommand, query legal actions
                 v
        DeterministicSimulationCore
                 |
                 | reads immutable card definitions
                 v
             CardDatabase
                 |
                 | contains typed Resource definitions
                 v
        CardDefinition + EffectRef

Simulation output:
  MatchState snapshot
  Gameplay events
  Rejected command reason
  State hash
```

### Key Interfaces

```gdscript
class_name DeterministicSimulationCore
extends RefCounted

func initialize_match(setup: MatchSetup, card_database: CardDatabase) -> SimulationResult
func submit_command(command: ActionCommand) -> SimulationResult
func get_state_snapshot() -> Dictionary
func get_state_hash() -> String
func query_legal_actions(player_id: StringName) -> Array[ActionCommand]
```

```gdscript
class_name CardDatabase
extends RefCounted

func add_definition(definition: CardDefinition) -> bool
func validate() -> CardValidationReport
func get_card_definition(card_id: StringName) -> CardDefinition
func get_card_data_hash() -> String
```

```gdscript
class_name CardDefinition
extends Resource

@export var card_id: StringName
@export var schema_version: int
@export var name_key: StringName
@export var rules_text_key: StringName
@export var card_type: StringName
@export var speed: StringName
@export var base_cost: int
@export var targeting_profile_id: StringName
@export var effect_refs: Array[EffectRef]
@export var tags: Array[StringName]
@export var status: StringName
```

### Implementation Guidelines

- Use `RefCounted` for core services and value-like runtime objects that do not need editor serialization.
- Use `Resource` for authorable card definitions and effect references.
- Use explicit static types for all public fields and functions.
- Use `StringName` for ids and enums represented as string ids in MVP code.
- Keep serialization canonical by sorting dictionary keys and definition ids before hashing.
- Use `StableHash.stable_hash()` for replay-facing state and card data hashes;
  it returns a SHA-256 lowercase hex digest of the canonical string.
- Expose state to UI, replay, and tooling as deep-copied canonical snapshots,
  not mutable `MatchState` references.
- Do not use `_process`, `_physics_process`, frame delta, `Time.get_ticks_msec()`, or wall-clock state inside core resolution.
- Do not use Autoload singleton access inside the simulation core.
- Do not import files from `prototypes/` in production source.

## Alternatives Considered

### Alternative 1: Scene-tree Node simulation

- **Description**: Implement match state as Godot Nodes and let board/card scenes mutate state directly.
- **Pros**: Familiar Godot scene workflow; easy visual debugging early.
- **Cons**: Harder to run headless, replay, hash, or reuse server-side; state ownership becomes blurry.
- **Estimated Effort**: Lower first-day effort, higher rework cost.
- **Rejection Reason**: Conflicts with deterministic replay and future server-authoritative validation.

### Alternative 2: Autoload singleton simulation manager

- **Description**: Put match state in a global Autoload manager accessed by UI and gameplay scripts.
- **Pros**: Easy access from any scene.
- **Cons**: Hidden dependencies, difficult isolated tests, load-order coupling, and accidental cross-system writes.
- **Estimated Effort**: Low initial effort, medium/high testing cost.
- **Rejection Reason**: Violates the project's preference for dependency injection and testability.

### Alternative 3: External backend rules engine first

- **Description**: Implement authoritative card rules outside Godot before local client rules.
- **Pros**: Aligns with eventual server-authoritative PvP.
- **Cons**: Slower feedback, extra infrastructure, and premature online scope before MVP rules are proven.
- **Estimated Effort**: High.
- **Rejection Reason**: MVP needs local deterministic proof first; backend authority can wrap the same rules later.

## Consequences

### Positive

- Core rules can be tested without UI.
- Future online authority can reuse the same command/state/hash model.
- Replay and desync diagnostics are designed in from the first implementation.
- Card definitions are structured enough for tooling and localization.

### Negative

- Initial implementation needs more explicit data classes than a quick scene prototype.
- Godot editor-only workflows are less convenient for pure `RefCounted` runtime objects.
- Some UI work must wait for query/result interfaces rather than mutating state directly.

### Neutral

- The MVP starts local-only, but its rules boundary is compatible with future networking.
- Card effects still need a later ADR/GDD before complex behavior is implemented.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| Hash serialization differs across clients | Medium | High | Build canonical serializer tests before relying on hashes |
| GDScript typed arrays/resources have version-specific behavior | Low | Medium | Verify with Godot 4.6.3 once installed |
| RefCounted core becomes too abstract for designers | Medium | Medium | Provide debug UI and readable validation errors |
| Card effect params drift into untyped dictionaries | Medium | High | Require typed effect parameter objects or schema validation before adding many cards |
| Future server cannot run GDScript directly | Medium | Medium | Treat command/state/log schema as portable; decide backend language in match authority ADR |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| CPU (simple command validation + resolution) | N/A | <= 100ms pure simulation target | <= 100ms MVP local action before presentation delay |
| Memory | N/A | Small in-memory match state and card database | <= 512 MB total runtime ceiling for Web/Mobile clients |
| Load Time | N/A | Card database validation at startup/test setup | Must not block future UX without loading indicator |
| Network | N/A | No network in MVP core | Future authority sends commands/hashes, not full client-owned outcomes |

## Migration Plan

There is no existing gameplay code to migrate.

1. Create Godot project skeleton.
2. Add typed card data classes and simulation core classes under `src/core/`.
3. Add a local smoke script that initializes a small card database and match setup.
4. Add proper Godot test framework later through `/test-setup`.
5. Write match authority ADR before any networked implementation.

**Rollback plan**: If this boundary proves too rigid for early prototyping, keep it for production code and add throwaway prototypes under `prototypes/` only. Do not refactor prototype code into production source.

## Validation Criteria

- [ ] Core classes load in Godot 4.6.3 without parse errors.
- [ ] A local smoke script can initialize card data and match setup without scene UI.
- [ ] The same setup and accepted command sequence produces the same state hash on repeated runs.
- [ ] Rejected commands do not mutate state.
- [ ] Production source does not import files from `prototypes/`.
- [ ] No core simulation code depends on `_process`, frame delta, scene tree state, or wall-clock time.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/deterministic-simulation-core.md` | Deterministic Simulation Core | Simulation must not depend on UI, networking, wall-clock time, frame delta, or global random functions | Chooses scene-independent `RefCounted` core services and explicit command submission |
| `design/gdd/deterministic-simulation-core.md` | Deterministic Simulation Core | Replay must rebuild from match setup and accepted commands | Requires setup/command/state/hash model from the first implementation |
| `design/gdd/card-data-model.md` | Card Data Model | Card behavior must be typed and immutable during matches | Chooses `Resource` definitions and effect references read through `CardDatabase` |
| `design/gdd/card-data-model.md` | Card Data Model | Card data hash must gate replay compatibility | Requires deterministic card database hashing |

## Related

- `design/gdd/deterministic-simulation-core.md`
- `design/gdd/card-data-model.md`
- `design/gdd/systems-index.md`
- `docs/engine-reference/godot/VERSION.md`
