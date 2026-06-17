# Turn, Timing, and Resource System Review Log

## Review - 2026-06-17 - Verdict: NEEDS REVISION

Scope signal: L
Specialists: none; lean single-session review
Completeness: 8/8 sections present
Dependency graph: no missing GDD dependencies
Blocking items: 2 | Recommended: 2
Prior verdict resolved: First review

Summary: The timing model solves the paper prototype's resource ambiguity by
separating main resource from response focus, but the approval gate should stay
closed until the refresh formula and focus risk are tightened. This is the
highest-risk design assumption in the current MVP set.

Required before approval:

1. Correct or clarify `main_resource_refresh`; the prose says max resource
   increases and current resource refreshes to max, while the formula assigns
   only `main_resource`.
2. Run the second focused response-resource prototype or explicitly record
   `RESPONSE_FOCUS_PER_OPPONENT_TURN = 2` as an accepted MVP risk.

Recommended revisions:

1. Decide whether focus refreshes at first response window or opponent Start
   Phase before implementation beyond the skeleton.
2. Define whether local MVP has any visible turn timer or explicitly defer it
   to a later UX/system GDD.

## Re-review - 2026-06-17 - Verdict: APPROVED

Scope signal: L
Specialists: none; lean single-session re-review
Blocking items: 0 | Recommended: 2
Prior verdict resolved: Yes

Summary: The main resource refresh formula now separately defines max-resource
growth and current-resource refresh. `RESPONSE_FOCUS_PER_OPPONENT_TURN = 2` is
recorded as the accepted first-playable MVP risk value, with playtest
validation required after the Godot playable exists.
