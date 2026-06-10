# C3 Workflow Alignment Status

> Updated 2026-06. The granular parity matrix lives in `docs/EDITOR-UI-SPEC.md`; this is
> the workflow-level summary.

This status maps current editor behavior to the project's Construct-style event sheet
workflow goals.

## Aligned

- Sheet tabs with type badges (⚙ behavior / ◆ custom node), title/path strip, dirty dots.
- Two-lane rows with **object icons + labels** per ACE cell, value highlighting, flat
  cells, per-cell hover, C3 spacing, crisp text at every zoom, drag-resizable lane
  divider, footer "Add event…" rows.
- Full authoring loop: picker (live search + C3 synonym aliases), params dialog with
  GDScript ƒx fields (live validation), empty-space double-click/context creation,
  drag/drop with insertion arrows + drag ghosts, multi-select, copy/paste (including
  cross-project text snippets), enable/disable with strikethrough, undo/redo.
- Sub-events, Else/Else-If, groups, comments (nestable), and variables-as-rows — all of
  which now also **compile** (nested bodies, `elif`/`else` chains, comment lines, local
  variables).
- Behaviors as first-class citizens: attach under any node, parameters in the Inspector,
  their ACEs in every sheet's picker (Platformer/8-direction packs bundled).
- GDScript pairing beyond C3: two-way provenance panel, in-flow GDScript blocks with
  lint/completion, open-any-`.gd`-as-sheet with ACE-level lifting.

## Partial

- Marquee/box selection works from empty canvas; interaction depth still trails mature C3
  ergonomics in edge cases.
- Mixed-structure copy/paste covers common paths, not every exhaustive combination.
- Theme switching has a toolbar preset picker; the designer-facing **visual theme editor**
  is the final 1.0 phase.

## Missing

- Multiline inline comment editing and per-comment colors; comment ↔ action-cell
  conversion (visual-completeness phase).
- Full keyboard-first authoring coverage expected by long-form C3 power users.
- Pick-filter compilation (the one remaining event-flow construct).
