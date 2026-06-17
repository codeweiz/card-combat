# Determinism Test Harness

> **Status**: Designed
> **Author**: Codex
> **Last Updated**: 2026-06-17
> **Last Verified**: 2026-06-17
> **Implements Pillar**: Deterministic Trust; Rules Clarity Beats Hidden Complexity; Cross-Platform First

## Summary

Determinism Test Harness defines the automated proof layer for Card Combat's
rules core. It turns match setups, command sequences, action logs, expected
state hashes, and replay mismatch reports into repeatable headless checks that
can run locally and in CI. The current `tools/smoke/smoke_deterministic_core.gd`
script is valid early evidence, but this system defines the broader fixture and
golden-result contract needed before first playable can claim deterministic
completion.

> **Quick reference** - Layer: `Production` - Priority: `MVP` - Key deps: `Action Log and Replay System`

## Overview

The test harness proves that the same setup and accepted commands produce the
same hashes, event order, and replay result every time. It is not a gameplay
feature and not a player-facing replay UI. It owns deterministic fixtures,
headless execution, golden hash comparison, mismatch reporting, regression
coverage, and update rules for expected outputs. It must fail loudly when a rule
change, data change, platform difference, or accidental non-determinism changes
the outcome.

The MVP harness can start as Godot headless scripts and later move into GUT or
gdUnit4 after `/test-setup` selects the framework. The contract in this GDD
should survive that tooling choice.

## Player Fantasy

Players feel this system indirectly as trust. When a match resolves the same way
on desktop, Web, and mobile builds, the player can believe that wins and losses
come from decisions rather than platform drift. For developers and QA, the
fantasy is a reliable alarm: if a card effect, response window, or lane mutation
changes deterministic behavior, the harness points to the exact fixture and
first mismatch.

## Detailed Design

### Core Rules

1. The harness runs headless and must not require UI scenes.
2. The harness uses deterministic test fixtures, not prototype play logs from
   `prototypes/`.
3. A fixture must define:
   - fixture id
   - rule set version
   - card data hash or embedded test card database source
   - `MatchSetup`
   - ordered command sequence
   - expected final state hash
   - expected event count
   - optional expected per-command before/after hashes
   - optional expected mismatch report for negative tests
4. Fixtures must be stored in a stable location outside `src/`; the proposed
   MVP path is `tests/fixtures/determinism/`.
5. Fixture data must be deterministic text or resource data that can be reviewed
   in diffs.
6. Golden hashes may be changed only with an explicit reason tied to a rules,
   card data, or fixture update.
7. A golden hash change without an intentional design or implementation change
   is a test failure until investigated.
8. The harness must initialize a fresh deterministic core for every fixture run.
9. The harness must validate fixture schema before running simulation.
10. The harness must reject fixtures whose rule set version, log schema version,
    or card data hash is incompatible with the current runtime unless the test
    is explicitly an incompatibility test.
11. The harness must submit fixture commands in exact order.
12. For positive fixtures, every fixture command must be accepted unless it is
    explicitly marked as an expected rejection case.
13. For rejection fixtures, the expected rejection reason and unchanged state
    hash must be verified.
14. After every accepted command, the harness should compare state hash when the
    fixture provides a per-command hash.
15. After fixture completion, the harness must compare final state hash and event
    count.
16. Replay fixtures must run through Action Log and Replay verification, not
    only through direct command submission.
17. Smoke tests may cover a narrow path, but first playable requires multiple
    named fixtures across lane, response, effect, deck/setup, and log/replay
    behaviors.
18. The suite must include at least one negative determinism fixture that proves
    mismatch reporting names the first divergent command or field.
19. The suite must include at least one incompatible replay fixture for card
    data hash or rule set mismatch.
20. Test code must not depend on scene tree node order, frame delta, wall-clock
    time, device input, network state, or file listing order.
21. Any random stream fixture must record stream id and draw index before random
    gameplay effects are allowed into MVP.
22. CI must run the deterministic smoke gate before any first playable or
    release build claim.
23. A failing deterministic fixture blocks approval of the story or release that
    introduced the failure unless the golden output is intentionally updated and
    reviewed.
24. The harness may expose debug output for humans, but machine pass/fail must
    be based on structured results.
25. The harness is allowed to use current headless scripts until `/test-setup`
    selects GUT or gdUnit4; the GDD defines behavior, not framework lock-in.

### Fixture Shape

Minimum MVP fixture shape:

```text
DeterminismFixture
  fixture_id: StringName
  fixture_schema_version: int
  rule_set_version: int
  card_data_hash: String
  setup: MatchSetup
  commands: Array[ActionCommandRecord]
  expected_final_hash: String
  expected_event_count: int
  expected_replay_verified: bool
```

Optional diagnostic fields:

```text
DeterminismFixtureDiagnostics
  expected_command_hashes: Array[CommandHashExpectation]
  expected_rejections: Array[RejectedCommandExpectation]
  expected_first_mismatch: ReplayMismatchExpectation
  notes: String
```

### Required MVP Fixture Families

| Family | Minimum Count | Purpose |
|--------|---------------|---------|
| Smoke core sequence | 1 | Current lane placement, response cancel, pass response, duplicate rejection path |
| Lane and occupancy | 1 | Lane slot ownership, duplicate placement rejection, board hash stability |
| Stack and response | 1 | Original action, response action, pass, cancel/fizzle ordering |
| Effect resolution | 1 | Typed effect params and deterministic event order |
| Replay compatibility | 1 | Action log replay final hash/event verification |
| Negative mismatch | 1 | First mismatch report is structured and useful |

### States and Transitions

| State | Entry Condition | Exit Condition | Behavior |
|-------|----------------|----------------|----------|
| SuiteIdle | Harness is not running | Test command starts | No fixture state loaded |
| LoadingFixtures | Fixture paths are selected | Fixtures loaded or load fails | Reads fixture definitions in stable sorted order |
| ValidatingFixtures | Fixtures loaded | All schemas pass or validation fails | Checks required fields, compatibility, and expected outputs |
| RunningFixture | One fixture is active | Direct simulation completes or fails | Initializes fresh core and submits commands |
| RunningReplay | Replay fixture or replay mode requested | Replay completes or mismatch occurs | Uses action-log replay verification |
| ComparingResults | Simulation/replay produced results | Pass/fail report created | Compares hashes, events, rejections, mismatch expectations |
| Passed | All fixtures passed | Report consumed | Suite exits with success |
| Failed | Any fixture failed | Report consumed | Suite exits with failure and structured diagnostics |
| GoldenUpdateRequested | Developer requests expected output refresh | Review approves or rejects update | Writes updated expected outputs only with reason |

Valid flow:

```text
SuiteIdle -> LoadingFixtures -> ValidatingFixtures -> RunningFixture
RunningFixture -> ComparingResults -> RunningFixture
RunningFixture -> RunningReplay -> ComparingResults
ComparingResults -> Passed
ComparingResults -> Failed
ComparingResults -> GoldenUpdateRequested -> LoadingFixtures
```

### Interactions with Other Systems

| System | Data In | Data Out | Ownership Boundary |
|--------|---------|----------|--------------------|
| Deterministic Simulation Core | Setup, commands, state hashes, rejection reasons | Pass/fail for direct deterministic execution | Core owns rules; harness owns proof |
| Action Log and Replay System | Action logs, replay verifier, mismatch reports | Replay pass/fail and fixture diagnostics | Replay owns verification logic; harness runs it |
| Card Data Model | Test card databases and card data hashes | Compatibility checks and fixture data | Card data owns definitions; harness owns test fixtures |
| Zone and Lane Board System | Board state through core snapshots/hashes | Lane regression coverage | Board owns state; harness verifies outcomes |
| Stack and Response System | Response windows and pass/cancel outcomes | Response regression coverage | Stack owns timing; harness verifies sequences |
| Card Effect Resolution System | Effect outcomes and event order | Effect regression coverage | Effects own semantics; harness verifies deterministic outputs |
| Local Match Flow | Future full-match fixtures | End-to-end match regression coverage | Match flow owns orchestration; harness verifies the flow |
| Balance and Content Tooling | Future card/content fixture generation | Regression coverage from content edits | Tools may generate fixtures; harness executes them |
| CI/Release Automation | Test command and exit code | Build gate result | CI owns scheduling; harness owns deterministic verdict |

## Formulas

### Determinism Fixture Valid

The `determinism_fixture_valid` formula is defined as:

`determinism_fixture_valid = fixture_schema_supported and setup_complete and command_sequence_valid and expected_outputs_present`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| fixture_schema_supported | S | bool | true/false | Runtime supports the fixture schema version |
| setup_complete | U | bool | true/false | Fixture has enough setup data to initialize the core |
| command_sequence_valid | C | bool | true/false | Fixture command order is gapless and actor-local sequence ids are valid |
| expected_outputs_present | E | bool | true/false | Required final hash, event count, and expected replay flag are present |

**Output Range:** boolean.
**Example:** A fixture with commands but no expected final hash fails before
simulation runs.

### Fixture Replay Verified

The `fixture_replay_verified` formula is defined as:

`fixture_replay_verified = replay_data_compatible and replay_matches_expected and expected_replay_verified`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| replay_data_compatible | D | bool | true/false | Rule set, card data hash, and log schema can be replayed |
| replay_matches_expected | R | bool | true/false | Replay final hash, event count, and mismatch count match expected |
| expected_replay_verified | E | bool | true/false | Fixture expects this replay to verify successfully |

**Output Range:** boolean.
**Example:** A positive replay fixture passes only when compatibility and replay
matching both succeed.

### Golden Hash Matches

The `golden_hash_matches` formula is defined as:

`golden_hash_matches = actual_final_hash == expected_final_hash`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| actual_final_hash | A | hash | any valid state hash | Hash produced by the fixture run |
| expected_final_hash | E | hash | any valid state hash | Golden hash stored in the fixture |

**Output Range:** boolean.
**Example:** If the smoke fixture produces
`e530e326a67c19fa5b6c181cd973937bbf57d5bea142389d0ccb6825517b2df3` and the
fixture expects that same hash, the hash comparison passes.

### Determinism Suite Passes

The `determinism_suite_passes` formula is defined as:

`determinism_suite_passes = fixture_count >= DETERMINISM_SUITE_MIN_FIXTURES_MVP and failed_fixture_count == 0 and suite_runtime_ms <= DETERMINISM_SUITE_MAX_RUNTIME_MS`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| fixture_count | F | int | 0-1000 | Number of fixtures selected for the suite |
| DETERMINISM_SUITE_MIN_FIXTURES_MVP | M | int | 6 | Minimum named fixtures before first playable determinism claim |
| failed_fixture_count | X | int | 0-1000 | Number of fixtures that failed validation, simulation, replay, or comparison |
| suite_runtime_ms | T | int | 0+ | Total suite runtime in milliseconds |
| DETERMINISM_SUITE_MAX_RUNTIME_MS | R | int | 5000 | MVP local/CI target for the core determinism suite |

**Output Range:** boolean.
**Example:** Five passing fixtures are not enough for first playable because
the MVP minimum is six fixture families.

### Golden Update Allowed

The `golden_update_allowed` formula is defined as:

`golden_update_allowed = golden_hash_update_requested and update_reason_present and affected_design_or_code_change_identified and reviewer_approved`

**Variables:**

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| golden_hash_update_requested | G | bool | true/false | Developer explicitly requested golden output refresh |
| update_reason_present | R | bool | true/false | Change includes a human-readable reason |
| affected_design_or_code_change_identified | C | bool | true/false | Change identifies the design/code/data reason for the new output |
| reviewer_approved | A | bool | true/false | Another review path approved the expectation change |

**Output Range:** boolean.
**Example:** A hash change caused by new damage resolution can be accepted only
when the rule change and reviewer approval are recorded.

## Edge Cases

| Scenario | Expected Behavior | Rationale |
|----------|------------------|-----------|
| Fixture schema version is unsupported | Fail validation before simulation | Old fixture shape may be misread |
| Fixture lacks expected final hash | Fail validation before simulation | Hash evidence is mandatory |
| Fixture command sequence has a gap | Fail validation before simulation | Sequence drift should not be hidden by replay |
| Fixture expects a rejected command | Verify rejection reason and unchanged hash | Rejection paths are part of deterministic behavior |
| Fixture does not mark expected rejection but command rejects | Fail at first rejected command | Positive fixtures require accepted command playback |
| Actual hash differs from golden hash | Fail and report fixture id, command index if available, expected hash, actual hash | Fast diagnosis |
| Event count matches but event order differs | Fail | Order is replay evidence |
| Replay mismatch is expected by a negative fixture | Pass only if first mismatch matches expected field/index | Negative tests must be precise |
| Card data hash differs from fixture | Fail compatibility unless fixture is an incompatibility test | Prevents accidental stale fixture runs |
| Developer updates golden hashes without reason | Reject update | Hash churn destroys trust |
| Fixture order differs by file system | Sort fixture ids/paths before execution | Stable suite output |
| Headless Godot is missing | Fail environment setup with explicit message | CI/local prerequisites must be visible |
| Suite runtime exceeds budget | Fail performance gate or mark as concern before first playable | Regression suite must stay usable |
| Random effect fixture lacks stream draw evidence | Fail validation | Randomness cannot become hidden non-determinism |
| A fixture imports prototype files | Fail validation | Production tests must not depend on disposable prototype artifacts |

## Dependencies

| System | Direction | Nature of Dependency |
|--------|-----------|----------------------|
| Action Log and Replay System | This depends on Action Log and Replay System | Uses log schema, replay verification, mismatch reports, and final hashes |
| Deterministic Simulation Core | This depends on Deterministic Simulation Core | Initializes core and submits fixture commands |
| Card Data Model | This depends on Card Data Model | Uses card data hashes and test card definitions |
| Card Effect Resolution System | This depends on Card Effect Resolution System | Verifies typed effect outcomes and event order |
| Stack and Response System | This depends on Stack and Response System | Verifies response windows, pass, cancel, and fizzle paths |
| Zone and Lane Board System | This depends on Zone and Lane Board System | Verifies board occupancy and lane mutation stability |
| Local Match Flow | This depends on Local Match Flow later | End-to-end full-match fixtures will enter through local flow |
| Balance and Content Tooling | Depends on this | Uses fixture failures to catch content/data regressions |
| CI/Release Automation | Depends on this | Runs deterministic gates before build/release claims |

## Tuning Knobs

| Parameter | Current Value | Safe Range | Effect of Increase | Effect of Decrease |
|-----------|--------------|------------|-------------------|-------------------|
| `DETERMINISM_FIXTURE_SCHEMA_VERSION` | 1 | 1+ | Enables fixture migration | Not applicable |
| `DETERMINISM_SUITE_MIN_FIXTURES_MVP` | 6 | 3-20 | Broader first-playable proof | Weaker regression coverage |
| `DETERMINISM_SUITE_MAX_RUNTIME_MS` | 5000 | 1000-30000 | More room for fixtures | Faster feedback, less coverage |
| `HEADLESS_SMOKE_REQUIRED` | true | true only for MVP | Stronger build gate | Not recommended |
| `GOLDEN_HASH_UPDATE_REQUIRES_REVIEW` | true | true only for MVP | Protects determinism trust | Faster but unsafe expectation churn |
| `FIXTURE_SORT_ORDER` | fixture_id_ascending | fixed only | Stable output | N/A |
| `NEGATIVE_FIXTURE_REQUIRED_MVP` | true | true/false | Proves diagnostics | Less mismatch coverage |

## Visual/Audio Requirements

This is a test/tooling system. It does not own game visuals or audio. Any future
test report UI should present fixture id, first mismatch, expected/actual hash,
and replay compatibility reason in plain text.

| Event | Visual Feedback | Audio Feedback | Priority |
|-------|----------------|---------------|----------|
| Fixture passed | Test report line with fixture id | None | Medium |
| Fixture failed | Test report line with first failure field | None | High |
| Golden update requested | Review summary with old/new hash and reason | None | High |
| Suite runtime exceeded | Test report marks budget failure | None | Medium |

## Game Feel

### Feel Reference

The harness should feel boring when rules are stable and sharp when they drift.
It should not ask developers to infer failure from a wall of logs; the first
divergence should be named directly.

### Tool Responsiveness

| Action | Max Runtime | Notes |
|--------|-------------|-------|
| Existing deterministic smoke script | 1000ms | Current narrow gate |
| MVP determinism suite | 5000ms | Six or more fixture families |
| One fixture direct simulation | 500ms | Includes setup, commands, comparison |
| One fixture replay verification | 1000ms | Includes action log replay pass |

### Failure Texture

- **Specific**: report fixture id, phase, command index, field, expected value,
  and actual value when available.
- **Stable**: same failure should produce the same message ordering.
- **Reviewable**: golden update output should be compact enough for code review.

## UI Requirements

No runtime player UI is required. Tooling output must include:

| Information | Display Location | Update Frequency | Condition |
|-------------|-----------------|------------------|-----------|
| Fixture id | Console/test report | Per fixture | Always |
| Fixture schema version | Console/test report | On validation failure | Invalid schema |
| Expected vs actual final hash | Console/test report | On hash mismatch | Hash mismatch |
| Expected vs actual event count | Console/test report | On event mismatch | Event mismatch |
| First mismatch field/index | Console/test report | On replay mismatch | Replay mismatch |
| Golden update reason | Review output | On golden update | Golden refresh requested |
| Suite runtime | Console/test report | End of suite | Always |

## Cross-References

| This Document References | Target GDD | Specific Element Referenced | Nature |
|--------------------------|------------|-----------------------------|--------|
| Replay verification formulas | `design/gdd/action-log-replay-system.md` | replay compatibility, final hash, mismatch report | Direct dependency |
| Core command execution | `design/gdd/deterministic-simulation-core.md` | setup, commands, hashes, rejection reasons | Direct dependency |
| Local first-playable replay proof | `design/gdd/local-match-flow.md` | local match replay-ready result | Future end-to-end dependency |
| Typed effects | `design/gdd/card-effect-resolution-system.md` | effect event order | Regression coverage |
| Response windows | `design/gdd/stack-response-system.md` | response/pass/cancel ordering | Regression coverage |
| Lane mutation | `design/gdd/zone-lane-board-system.md` | board occupancy and state hashes | Regression coverage |
| Current smoke evidence | `tools/smoke/smoke_deterministic_core.gd` | deterministic smoke path and final hash | Existing implementation baseline |

## Acceptance Criteria

- [ ] **GIVEN** a valid determinism fixture, **WHEN** validation runs, **THEN** `determinism_fixture_valid` is true before simulation starts.
- [ ] **GIVEN** a fixture missing expected final hash, **WHEN** validation runs, **THEN** the fixture fails before any command is submitted.
- [ ] **GIVEN** a positive fixture command sequence, **WHEN** the harness runs it twice in fresh cores, **THEN** both runs produce the same final hash and event count.
- [ ] **GIVEN** a replay fixture, **WHEN** the harness runs replay verification, **THEN** `fixture_replay_verified` is true for compatible positive fixtures.
- [ ] **GIVEN** a fixture with a golden final hash, **WHEN** actual final hash differs, **THEN** the harness fails and reports fixture id plus expected/actual hash.
- [ ] **GIVEN** a negative mismatch fixture, **WHEN** replay diverges, **THEN** the harness passes only if the first mismatch index and field match expectation.
- [ ] **GIVEN** a rejected-command fixture, **WHEN** the expected command rejects, **THEN** the rejection reason and unchanged state hash are verified.
- [ ] **GIVEN** card data hash differs from fixture expectation, **WHEN** the fixture is not an incompatibility test, **THEN** compatibility validation fails before playback.
- [ ] **GIVEN** a requested golden hash update, **WHEN** no update reason or reviewer approval is present, **THEN** `golden_update_allowed` is false.
- [ ] **GIVEN** the MVP determinism suite, **WHEN** it runs headless, **THEN** it includes at least six fixture families and satisfies `determinism_suite_passes`.
- [ ] **GIVEN** two environments with the same runtime and fixture data, **WHEN** fixtures are discovered, **THEN** fixture execution order is stable by fixture id.
- [ ] **GIVEN** CI or release validation, **WHEN** deterministic smoke fails, **THEN** the build/release gate fails.
- [ ] Performance: MVP determinism suite completes within `DETERMINISM_SUITE_MAX_RUNTIME_MS = 5000` on the target development machine unless explicitly marked as extended diagnostics.

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|------------|
| Should `/test-setup` choose GUT or gdUnit4 for the long-term fixture runner? | Gameplay Programmer / QA Lead | Before first formal test suite story | Provisional: keep current headless scripts until selected |
| What exact fixture serialization format should be used? | Tools Programmer / Gameplay Programmer | Before fixture implementation | Provisional: deterministic text/resource files under `tests/fixtures/determinism/` |
| How should golden updates be reviewed in trunk-based development? | QA Lead / Producer | Before CI gate | Provisional: require explicit reason and reviewer approval |
| Should Web/Mobile exported builds run the same suite or rely on headless desktop plus smoke on device? | QA Lead | Before platform QA | Provisional: headless desktop first, add platform smoke later |
| Which six fixtures should be implemented first? | Gameplay Programmer / QA Lead | Before first playable test story | Provisional: use fixture families listed in this GDD |

---

## Lean Review Notes

Specialist review was not run inline because `production/review-mode.txt` is set
to `lean` and no subagent spawn was explicitly requested. Run `/design-review
design/gdd/determinism-test-harness.md` in a fresh session before approval.
