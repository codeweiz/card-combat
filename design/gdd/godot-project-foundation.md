# Godot Project Foundation

> **Status**: Designed
> **Author**: Codex
> **Last Updated**: 2026-06-17
> **Last Verified**: 2026-06-17
> **Implements Pillar**: Cross-Platform First; Deterministic Trust; Rules Clarity Beats Hidden Complexity

## Summary

Godot Project Foundation defines the minimum project shell that every MVP system
depends on: pinned Godot version, project configuration, directory contract,
source/test/prototype isolation, engine reference docs, headless verification,
and first-party platform assumptions. It is the operational base that lets
systems move from GDDs into Godot code without changing the rules, losing
determinism, or mixing production source with throwaway prototypes.

> **Quick reference** - Layer: `Foundation` - Priority: `MVP` - Key deps: none

## Overview

The foundation is the stable Godot workspace contract for Card Combat. It does
not define cards, turns, lanes, UI, replay, or match flow. It defines where those
systems live, which engine version they target, which language and platforms are
allowed, how headless checks run, and which project settings are already part of
the baseline. The current project is scaffolded with `project.godot`, `src/`,
`design/`, `docs/`, `tools/`, `prototypes/`, and production session state; this
GDD turns that scaffold into an explicit MVP system requirement.

## Player Fantasy

Players should never notice this system directly. They feel it as reliability:
the same duel can be built, tested, and eventually shipped across desktop, Web,
and mobile clients without project-level surprises. For the team, the fantasy is
a clean workbench: source code has a known home, experiments stay isolated,
engine assumptions are pinned, and headless checks catch broken foundations
before higher-level systems are blamed.

## Detailed Design

### Core Rules

1. The project uses Godot `GODOT_ENGINE_VERSION = 4.6.3`.
2. The Godot project file must exist at `project.godot`.
3. `project.godot` must declare the application name `Card Combat`.
4. `project.godot` must include Godot 4.6 as a feature baseline.
5. Client code language is GDScript for Web compatibility.
6. First-party platforms are PC, Web, and Mobile.
7. Console remains a later porting target and is not a first-party MVP baseline.
8. Production source lives under `src/`.
9. Tests live under `tests/`; no test suite should be placed in `src/`.
10. Tools and one-off verification scripts live under `tools/`.
11. Throwaway prototype work lives under `prototypes/`.
12. Production source must not import code or data from `prototypes/`.
13. Design documents live under `design/`.
14. Technical and architecture documents live under `docs/`.
15. Engine reference documents live under `docs/engine-reference/godot/`.
16. Session state lives under `production/session-state/`.
17. Core gameplay code must remain scene-independent until a UI/adapter system
    explicitly consumes it.
18. GDScript warning settings for unsafe property, method, and cast access must
    remain enabled unless a later ADR changes the quality gate.
19. Desktop rendering may use Godot Forward+; Web/Mobile must keep a
    Compatibility renderer path until profiling proves otherwise.
20. No Autoload singleton may be added without documenting purpose and ownership.
21. The deterministic core must be instantiable in headless scripts without
    loading match UI scenes.
22. The current headless smoke script path is
    `tools/smoke/smoke_deterministic_core.gd`.
23. Local verification should run Godot through
    `/Applications/Godot.app/Contents/MacOS/Godot` until Godot is added to PATH.
24. Any future export preset must preserve the PC/Web/Mobile platform baseline.
25. Any new code system under `src/` needs a governing ADR before production
    implementation.

### Directory Contract

| Path | Owner | Purpose | MVP Rule |
|------|-------|---------|----------|
| `project.godot` | Godot Project Foundation | Engine project configuration | Must exist and load in Godot 4.6.3 |
| `src/` | Engineering | Production game source | No prototype imports |
| `src/core/` | Core gameplay engineering | Scene-independent deterministic rules | Headless-loadable |
| `assets/` | Art/audio/content pipeline later | Production assets | Keep generated/imported files out until pipeline exists |
| `design/gdd/` | Design | GDDs and systems index | Systems must cross-reference dependencies |
| `design/registry/` | Design/architecture | Cross-system named facts | YAML must parse |
| `docs/architecture/` | Architecture | ADRs | New code systems require ADRs |
| `docs/engine-reference/godot/` | Technical direction | Version-pinned engine notes | Check before post-cutoff API use |
| `tests/` | QA/engineering | Automated tests | To be scaffolded by `/test-setup` |
| `tools/` | Engineering/tooling | Smoke, build, pipeline scripts | Scripts must be runnable from repo root |
| `prototypes/` | Design/prototyping | Disposable experiments | Never imported by production source |
| `production/` | Production management | Stage reports and session state | Tracks current work and gates |

### Current Project Settings Baseline

| Setting | Current Value | Requirement |
|---------|---------------|-------------|
| `config_version` | `5` | Must remain valid for Godot 4 project format |
| `application/config/name` | `Card Combat` | Must match product name in concept docs |
| `application/config/features` | `PackedStringArray("4.6")` | Must remain compatible with pinned Godot 4.6.3 |
| `gdscript/warnings/unsafe_property_access` | `1` | Required quality warning |
| `gdscript/warnings/unsafe_method_access` | `1` | Required quality warning |
| `gdscript/warnings/unsafe_cast` | `1` | Required quality warning |
| `rendering/renderer/rendering_method.mobile` | `gl_compatibility` | Required Web/Mobile fallback path |

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| NoProject | No `project.godot` exists | Project file created | Godot checks cannot run |
| ProjectScaffolded | `project.godot` and core directories exist | Engine/version docs and smoke script exist | Code can begin but gates are partial |
| FoundationDesigned | This GDD and registry facts exist | Validation passes | MVP foundation is explicit and reviewable |
| FoundationVerified | YAML, placeholder, and Godot smoke checks pass | New foundation change lands | Ready for dependent MVP design/implementation work |
| FoundationNeedsRevision | A project setting, path, or smoke gate fails | Issue corrected and revalidated | Blocks first-playable claims |

Valid flow:

```text
NoProject -> ProjectScaffolded -> FoundationDesigned -> FoundationVerified
FoundationVerified -> FoundationNeedsRevision -> FoundationVerified
```

### Interactions with Other Systems

| System | Data In | Data Out | Ownership Boundary |
|--------|---------|----------|--------------------|
| Deterministic Simulation Core | Godot version, `src/` conventions, headless script support | Scene-independent code location and smoke path | Foundation owns workspace rules; core owns gameplay state |
| Card Data Model | GDScript/Resource conventions and source layout | Data class location and validation gate | Foundation owns project shell; card data owns schema |
| Match Board UI and Input | Platform baseline and renderer fallback | UI project assumptions | Foundation owns platform constraints; UI owns screens |
| Cross-Platform Interaction Layer | Input method baseline and Godot 4.6 focus notes | Device support assumptions | Foundation owns supported platform set |
| Determinism Test Harness | Headless Godot command, tools path, tests path | Test runner prerequisites | Foundation owns runnable project shell; harness owns fixtures |
| Content Pipeline | Assets path and import assumptions later | Asset root contract | Foundation owns directories; pipeline owns transformations |
| CI/Release Automation | Godot binary/export assumptions later | Build and smoke command prerequisites | Foundation owns local project invariants |

## Formulas

### Godot Project Foundation Ready

The `godot_project_foundation_ready` formula is defined as:

`godot_project_foundation_ready = project_file_present and godot_version_pinned and directory_contract_present and headless_smoke_available`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| project_file_present | P | bool | true/false | `project.godot` exists at the repository root |
| godot_version_pinned | V | bool | true/false | Engine reference pins Godot 4.6.3 |
| directory_contract_present | D | bool | true/false | Required root directories exist or are reserved |
| headless_smoke_available | H | bool | true/false | Smoke script path exists and can be run headlessly |

**Output Range:** boolean.
**Example:** A repo with code and docs but no smoke script is scaffolded, not
foundation-ready.

### Project Settings Baseline Valid

The `project_settings_baseline_valid` formula is defined as:

`project_settings_baseline_valid = application_name_valid and engine_feature_valid and gdscript_warnings_enabled and mobile_renderer_fallback_configured`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| application_name_valid | A | bool | true/false | Godot application name is `Card Combat` |
| engine_feature_valid | E | bool | true/false | Godot features include the 4.6 baseline |
| gdscript_warnings_enabled | W | bool | true/false | Unsafe access/cast warnings remain enabled |
| mobile_renderer_fallback_configured | M | bool | true/false | Mobile renderer fallback is configured for Web/Mobile risk |

**Output Range:** boolean.
**Example:** Disabling unsafe GDScript warnings makes the baseline invalid even
if the smoke script still passes.

### Production Source Isolated

The `production_source_isolated` formula is defined as:

`production_source_isolated = production_src_has_no_prototype_imports and production_src_has_no_session_state_imports`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| production_src_has_no_prototype_imports | P | bool | true/false | Files under `src/` do not import from `prototypes/` |
| production_src_has_no_session_state_imports | S | bool | true/false | Files under `src/` do not import production session state |

**Output Range:** boolean.
**Example:** A core script loading a prototype deck directly fails this formula.

### Headless Smoke Gate Ready

The `headless_smoke_gate_ready` formula is defined as:

`headless_smoke_gate_ready = godot_binary_resolved and project_file_present and smoke_script_present`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| godot_binary_resolved | G | bool | true/false | Local or CI environment can invoke Godot 4.6.3 |
| project_file_present | P | bool | true/false | `project.godot` exists at repo root |
| smoke_script_present | S | bool | true/false | `tools/smoke/smoke_deterministic_core.gd` exists |

**Output Range:** boolean.
**Example:** The local gate is ready when the macOS Godot binary path, project
file, and smoke script all exist.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Godot binary is not on PATH | Use the documented local binary path or fail with an explicit setup message | Local verification should be repeatable |
| `project.godot` is missing | Block implementation and smoke checks until recreated | Godot cannot load the project |
| Engine version changes | Update `docs/engine-reference/godot/VERSION.md`, rerun smoke, and revalidate ADRs | Post-cutoff Godot API drift is high risk |
| A production script imports from `prototypes/` | Reject the change in review or CI | Prototype code is disposable |
| A test is added under `src/` | Move it under `tests/` or `tools/` depending on purpose | Keeps production code clean |
| A new Autoload is added without ownership docs | Block until purpose, API, and owner are documented | Avoids hidden global coupling |
| Export presets are added for one platform only | Mark platform baseline incomplete until PC/Web/Mobile assumptions are addressed | Cross-platform first requires explicit scope |
| Renderer settings change for mobile | Require profiling or documented rationale | Web/Mobile fallback protects first-party targets |
| Headless smoke passes but GDScript warnings are disabled | Treat foundation as needing revision | Passing smoke is not the whole quality gate |
| Generated Godot cache files change | Do not treat cache churn as design evidence | `.godot/` state is editor/runtime cache |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|----------------------|
| Godot Engine 4.6.3 | This depends on pinned engine | Provides project format, GDScript runtime, resources, scene system, and export baseline |
| Technical Preferences | This depends on setup decisions | Supplies language, platform, renderer, testing, and forbidden-pattern decisions |
| Deterministic Simulation Core | Depends on this | Requires headless-loadable `src/core/` and Godot 4.6.3 project shell |
| Card Data Model | Depends on this | Requires GDScript Resource conventions and class discovery |
| Match Board UI and Input | Depends on this | Requires platform, renderer, and Godot UI constraints |
| Cross-Platform Interaction Layer | Depends on this | Requires input method and platform baseline |
| Determinism Test Harness | Depends on this | Requires headless Godot project and `tools/`/`tests/` paths |
| CI/Release Automation | Depends on this later | Requires Godot binary, export presets, and smoke command contract |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `GODOT_ENGINE_VERSION` | 4.6.3 | pinned only until upgrade ADR | Newer engine features, more migration risk | Older engine may lack verified assumptions |
| `FIRST_PARTY_TARGET_PLATFORM_COUNT` | 3 | 1-4 | Broader QA/export burden | Less cross-platform proof |
| `WEB_MOBILE_MEMORY_CEILING_MB` | 512 | 256-1024 | More asset/runtime budget | Stricter optimization pressure |
| `MATCH_BOARD_DRAW_CALL_BUDGET` | 150 | 100-200 | More UI richness | Better Web/Mobile margin |
| `HEADLESS_SMOKE_REQUIRED` | true | true only for MVP gates | Stronger regression protection | Not recommended |
| `GDSCRIPT_UNSAFE_WARNING_LEVEL` | 1 | 0-2 | More strict warnings if raised | Weaker script safety if lowered |

## Visual/Audio Requirements

This foundation system has no runtime visual or audio output. It constrains
where visual and audio systems will live and how they must respect platform
targets.

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Foundation smoke passes | Console/test output only | None | High |
| Foundation smoke fails | Console/test output with failing reason | None | High |
| Engine version mismatch | Setup/report warning | None | High |
| Export preset missing later | CI/release report warning | None | Medium |

## UI Requirements

No player UI is owned by this system. It supplies constraints that UI systems
must obey:

| Requirement | Consumer | Source |
|-------------|----------|--------|
| PC, Web, Mobile first-party clients | Match Board UI, Menu Shell, Interaction Layer | Technical Preferences |
| Avoid hover-only required behavior | Match Board UI, Cross-Platform Interaction Layer | Technical Preferences |
| Mobile/Web renderer fallback exists | Match Board UI, Visual Identity | `project.godot` |
| Godot 4.6 dual-focus must be considered | UI and input systems | Engine reference docs |

## Cross-References

| This Document References | Target Document | Specific Element Referenced | Nature |
|--------------------------|-----------------|-----------------------------|--------|
| Engine version and platform notes | `docs/engine-reference/godot/VERSION.md` | Godot 4.6.3, GDScript for Web, PC/Web/Mobile | Engine constraint |
| Project preferences | `.claude/docs/technical-preferences.md` | language, renderer, testing, forbidden patterns | Technical constraint |
| Directory layout | `.claude/docs/directory-structure.md` | root path contract | Workspace constraint |
| Deterministic rules boundary | `docs/architecture/adr-0001-mvp-deterministic-card-simulation.md` | scene-independent core and no Autoload core | Architecture dependency |
| Effect resolver boundary | `docs/architecture/adr-0002-mvp-card-effect-resolution-architecture.md` | scene-independent effect service | Architecture dependency |
| Board/response state ownership | `docs/architecture/adr-0003-mvp-lane-board-and-response-window-state.md` | core-owned mutation boundaries | Architecture dependency |
| Current smoke path | `tools/smoke/smoke_deterministic_core.gd` | headless deterministic smoke | Verification baseline |

## Acceptance Criteria

- [ ] **GIVEN** the repository root, **WHEN** a developer opens it with Godot 4.6.3, **THEN** `project.godot` loads as `Card Combat`.
- [ ] **GIVEN** the project settings, **WHEN** foundation validation runs, **THEN** `project_settings_baseline_valid` is true.
- [ ] **GIVEN** production source under `src/`, **WHEN** imports are scanned, **THEN** `production_source_isolated` is true.
- [ ] **GIVEN** local Godot is available, **WHEN** `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/smoke/smoke_deterministic_core.gd` runs, **THEN** the smoke exits 0 and prints the deterministic final hash.
- [ ] **GIVEN** a new code system is added under `src/`, **WHEN** implementation begins, **THEN** a governing ADR exists or is created first.
- [ ] **GIVEN** a new test is added, **WHEN** it is committed, **THEN** it lives under `tests/` or a tool-specific path under `tools/`, not production `src/`.
- [ ] **GIVEN** a prototype produces useful code or data, **WHEN** production implementation needs it, **THEN** it is reauthored into `src/`, `assets/`, or `design/` instead of imported from `prototypes/`.
- [ ] **GIVEN** the engine version changes, **WHEN** the change lands, **THEN** engine reference docs, ADR compatibility notes, and smoke checks are revalidated.
- [ ] **GIVEN** future export presets are introduced, **WHEN** release validation runs, **THEN** PC/Web/Mobile scope is explicit and unsupported targets are marked out of MVP.
- [ ] Performance: foundation smoke should complete within the determinism harness smoke budget and must not require loading match UI scenes.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|------------|
| Should Godot be added to PATH or wrapped by a repo-local script? | DevOps Engineer | Before CI setup | Provisional: use `/Applications/Godot.app/Contents/MacOS/Godot` locally |
| Which test framework should `/test-setup` select? | QA Lead / Gameplay Programmer | Before formal tests | Provisional: keep headless smoke until GUT or gdUnit4 is selected |
| When should export presets be created? | Release Manager / DevOps Engineer | Before first packaged build | Provisional: after first playable scope is clear |
| Should `.godot/` editor cache be fully ignored or partially preserved? | Lead Programmer | Before repository cleanup | Provisional: do not use cache churn as source-of-truth evidence |

---

## Lean Review Notes

Specialist review was not run inline because `production/review-mode.txt` is set
to `lean` and no subagent spawn was explicitly requested. Run `/design-review
design/gdd/godot-project-foundation.md` in a fresh session before approval.
