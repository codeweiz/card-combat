# Technical Preferences

<!-- Populated by /setup-engine. Updated as the user makes decisions throughout development. -->
<!-- All agents reference this file for project-specific standards and conventions. -->

## Engine & Language

- **Engine**: Godot 4.6.3
- **Language**: GDScript
- **Rendering**: Godot 4 Forward+ for desktop, Compatibility renderer as fallback for Web/Mobile after profiling
- **Physics**: Godot Physics 2D for card-table interactions; Jolt 3D is not a core dependency for the initial 2D client

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: PC, Web, Mobile for first-party clients; console remains a later porting target through certified third-party support
- **Input Methods**: Keyboard/Mouse, Touch, Gamepad
- **Primary Input**: Pointer-first card interaction that maps cleanly to mouse and touch
- **Gamepad Support**: Partial for menus and match navigation; full gamepad UX requires a dedicated UX spec
- **Touch Support**: Full for mobile and tablet-sized layouts
- **Platform Notes**: Avoid hover-only affordances. All match actions must have touch-safe hit targets, keyboard/mouse alternatives, and deterministic UI state suitable for synchronized multiplayer.

## Naming Conventions

- **Classes**: PascalCase with `class_name` where editor registration is useful, e.g. `CardDefinition`
- **Variables**: snake_case with explicit static types, e.g. `current_mana: int`
- **Signals/Events**: snake_case past tense with typed parameters, e.g. `card_played(card_id: StringName)`
- **Files**: snake_case matching the class, e.g. `card_definition.gd`
- **Scenes/Prefabs**: PascalCase matching the root node responsibility, e.g. `MatchBoard.tscn`
- **Constants**: UPPER_SNAKE_CASE, e.g. `MAX_HAND_SIZE`

## Performance Budgets

- **Target Framerate**: 60 FPS on desktop and modern mobile; 30 FPS acceptable fallback for low-end mobile/Web
- **Frame Budget**: 16.6 ms target, with gameplay simulation kept deterministic and event-driven rather than per-frame polling
- **Draw Calls**: Keep match board UI under 150 draw calls before batching/theme optimization; revise after art direction and device profiling
- **Memory Ceiling**: 512 MB initial runtime ceiling for Web/Mobile clients; revise after asset budgets are defined

## Testing

- **Framework**: GUT or gdUnit4 to be selected during `/test-setup`; headless Godot tests required in CI once the project file exists
- **Minimum Coverage**: No numeric threshold until systems exist; critical rule, card resolution, deck validation, and networking code must have automated tests before story completion
- **Required Tests**: Balance formulas, card rules, turn sequencing, deterministic simulation, deck validation, matchmaking/networking contracts, save/profile migration

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- Gameplay state changes driven only by client trust in multiplayer
- Card effects implemented as untyped dictionaries when a typed Resource or command object is required
- Hover-only UI behavior for required actions
- Hidden per-frame polling for systems that can be event-driven

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- `docs/architecture/adr-0001-mvp-deterministic-card-simulation.md` — MVP deterministic rules boundary and card data model.
- `docs/architecture/adr-0002-mvp-card-effect-resolution-architecture.md` — Typed card effect resolver and effect params.
- `docs/architecture/adr-0003-mvp-lane-board-and-response-window-state.md` — Lane board, runtime unit, response window, and stack item state ownership.

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist (all `.gd` files)
- **Shader Specialist**: godot-shader-specialist (`.gdshader` files, VisualShader resources)
- **UI Specialist**: godot-specialist (Control nodes, CanvasLayer, themes, focus and input routing)
- **Additional Specialists**: godot-gdextension-specialist (GDExtension/native bindings only, not part of the initial language stack)
- **Routing Notes**: Invoke the primary specialist for architecture, project settings, export presets, and cross-platform implications. Invoke the GDScript specialist for gameplay/UI code quality and typed signal architecture. Invoke the shader specialist only for material/VFX work. GDExtension requires an ADR before adoption.

### File Extension Routing

<!-- Use this table to select the right specialist per file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (`.gd` files) | godot-gdscript-specialist |
| Shader / material files (`.gdshader`, VisualShader) | godot-shader-specialist |
| UI / screen files (Control nodes, CanvasLayer, themes) | godot-specialist |
| Scene / prefab / level files (`.tscn`, `.tres`) | godot-specialist |
| Native extension / plugin files (`.gdextension`, C++/Rust bindings) | godot-gdextension-specialist |
| General architecture review | godot-specialist |
