# Card Data Model Review Log

## Review - 2026-06-17 - Verdict: NEEDS REVISION

Scope signal: L
Specialists: none; lean single-session review
Completeness: 8/8 sections present
Dependency graph: `design/gdd/localization-text-layout.md` NOT FOUND; `design/gdd/card-frame-visual-identity-system.md` NOT FOUND; future Vertical Slice dependencies
Blocking items: 2 | Recommended: 3
Prior verdict resolved: First review

Summary: The card schema is complete enough to show the intended data boundary,
but approval should wait until two contradictory/open authoring decisions are
resolved. The document currently specifies both `response` card type and
`response` speed while still listing that choice as pending, and it does not
pick the MVP authoring/storage format programmers should implement first.

Required before approval:

1. Resolve whether `response` is a card type, a speed, or both for MVP, then
   remove the contradictory open-question wording.
2. Select the MVP card authoring/storage path, such as Godot `.tres` Resources,
   deterministic JSON-like data, or a documented hybrid.

Recommended revisions:

1. Keep localization and card-frame references provisional until those GDDs are
   authored.
2. Define the first MVP targeting-profile list alongside the card schema.
3. Clarify when missing localization keys are allowed for prototype versus
   production export.

## Re-review - 2026-06-17 - Verdict: APPROVED

Scope signal: L
Specialists: none; lean single-session re-review
Blocking items: 0 | Recommended: 2
Prior verdict resolved: Yes

Summary: The card authoring and response type/speed decisions were resolved.
MVP production card data is authored as Godot `.tres` Resources backed by
`CardDefinition`, `EffectRef`, and typed `EffectParams`; MVP response cards use
both `card_type = response` and `speed = response`.
