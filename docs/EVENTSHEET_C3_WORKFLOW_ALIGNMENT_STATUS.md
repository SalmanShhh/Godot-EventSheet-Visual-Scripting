# C3 Workflow Alignment Status

This status maps current editor behavior to the project’s Construct-style event sheet workflow goals.

## Aligned

- Sheet-level title/path strip behaves like a document tab context.
- Empty-space double-click adds new events quickly.
- Empty-space context menu exposes creation actions.
- Event rows support condition/action lane composition and contextual ACE editing.
- Multi-row selection and copy/paste/reorder workflows exist.
- Event block body selection now includes its descendant sub-events.
- Condition/action span hover and selection emphasize the span itself (without full-row hover fill).
- Drag previews for condition/action ACE moves now show three cues together: source-chip emphasis, event-block target highlighting, and a placeholder chip slot at the landing point.
- Else / ElseIf markers are represented in the condition lane.

## Partial

- Marquee/box selection now works from empty canvas, but interaction depth still trails mature C3 ergonomics.
- Mixed-structure copy/paste (events + groups + comments in every combination) is functional in common paths, not fully exhaustive.
- Theme switching exists, but not yet as a full preset browser UX.
- Else/ElseIf authoring flows are represented in data/rendering but not yet fully guided through dedicated UX steps.
- Theme workflow now supports both disk reload and visual-template rebuild from the dock toolbar, but still lacks a richer preset browser/package manager UX.
- ACE enabled/disabled controls exist in editor UX; runtime semantics are still being expanded.

## Missing

- Full parity keyboard-first authoring coverage expected by long-form C3 power users.
- Advanced timeline/debug overlays and richer block manipulation patterns from the spec.
- Complete visual parity for every edge interaction in nested structures.
