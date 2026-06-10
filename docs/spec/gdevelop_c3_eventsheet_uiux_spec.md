# GDevelop / Construct 3 EventSheet UI/UX Spec — Godot Translation

> **Reference design study** that guided the editor. Current shipped behavior and the
> parity matrix live in `docs/EDITOR-UI-SPEC.md` (§5 interaction contract, §6 parity).

This document captures the key interaction-model learnings from GDevelop and Construct 3
EventSheet editors that directly inform the visual and interaction design of the Godot EventForge
EventSheet editor.

Reference systems studied:
- **Construct 3** (c3.construct.net) — the gold standard EventSheet UX
- **GDevelop** (gdevelop.io) — open-source C3-style engine with a similar event sheet

---

## Core Interaction Model

### 1. Row / Lane / Block Architecture

The EventSheet is organized as a vertical list of **event rows**, each subdivided into:
- **Condition lane** (left half) — what must be true for the event to fire
- **Action lane** (right half) — what happens when the event fires
- **Sub-event lane** (indented rows) — nested events that fire within the same tick

Interactions should target the **structural unit the user is looking at**, not an abstract span:
- Clicking a condition entry → that condition entry is the target
- Clicking an action entry → that action entry is the target
- Clicking an event block → that event block is the target
- Clicking a group header → that group + all contained events are the target

### 2. Condition / Action Entries Are Full-Width List Items

Each condition and each action occupies one **full-width list row** inside its lane.

- The text of the entry spans the full column width.
- Hover shows a background highlight for the full entry width.
- Click selects that entry with a clear background highlight.
- Double-click (or left-click on already-selected) opens the edit dialog.

**NOT** chip/token fragments scattered inline — even though multiple conditions share the
condition lane, they stack vertically as individual list rows.

### 3. Hover Affordances

Every clickable row must show an unambiguous hover affordance:
- **Condition hover** → condition row gets a visible background tint
- **Action hover** → action row gets a visible background tint
- **Comment hover** → the comment row gets a background tint
- **Group header hover** → the group header gets a background tint
- **Variable row hover** → the variable row gets a background tint

Minimum recommended hover alpha: **≥ 0.40** over the row background.
Do not rely on color alone — add a subtle left-side accent border (1–3 px) on hover.

### 4. Selection Visual Design

Selected items must be **unmistakably** distinct from unselected:
- Background fill: ≥ 0.50 alpha over row background
- Left accent border: 2–4 px solid, in selection color
- Selected entry font color should be brighter/whiter
- Multi-selected entries: each selected entry shows selected state (same fill, same border)

Do NOT use a single row-level highlight to communicate "a chip inside is selected" — the
user should see the specific entry highlighted.

### 5. Drag and Drop Interaction Model

#### Moving Conditions / Actions
- Drag a condition row → other rows in the condition lane dimly highlight as drop targets
- Drop between two rows → thin horizontal insertion bar appears
- The dragged item should show a visual "ghost" or cursor change indicating it is moving

#### Moving Event Blocks / Groups
- Drag an event row → other event rows show before/after/inside drop zones
- "Inside" zone is indicated by an indented insertion line
- Dragging a group moves the group + all its contained events as a block

### 6. Group Block Visual Language

Groups are structural containers that anchor a section of the EventSheet:
- Group header is visually distinct: larger left border, accent background
- All events inside the group are indented and show a connecting left-rail guide
- Selecting the group selects the whole block (for copy/paste, move, delete)
- Folding the group collapses all contained events visually

### 7. Variable Row Visual Language

Variable rows use a compact "document line" metaphor:
- Scope badge (Global / Local / Const) is a pill/badge on the left, text centered in the pill
- Variable name, type annotation (`:Type`), and default value (`= value`) are on one line
- The row is directly editable by double-clicking anywhere on it
- Hover shows a background tint indicating the row is editable

---

## Visual Hierarchy and Density

### Recommended Color Roles

| Role | Purpose | Suggested Alpha |
|---|---|---|
| Row background | Base surface | 1.0 |
| Condition lane tint | Subtle left-column distinction | 0.05–0.10 |
| Action lane tint | Subtle right-column distinction | 0.04–0.08 |
| Hover fill | Hover state fill | 0.08–0.14 |
| Selection fill | Selected state fill | 0.30–0.50 |
| Entry hover | Individual entry hover | 0.40–0.60 |
| Entry selected | Individual entry selected | 0.55–0.75 |

### Typography Roles

| Text type | Style |
|---|---|
| Object name | Accent blue, medium weight |
| Condition/action text | Near-white, normal weight |
| Action text | Warm accent (amber/gold tint) |
| Comment text | Muted gray |
| Group title | Bright/light, slightly larger |
| Scope badge | Small, high-contrast on colored pill |

---

## Keyboard Navigation

| Key | Action |
|---|---|
| ↑ / ↓ | Move selection between rows |
| Enter / F2 | Rename / edit selected row |
| Delete | Delete selected rows / entries |
| Ctrl+C / Ctrl+V | Copy / paste selected block |
| Ctrl+Z / Ctrl+Y | Undo / Redo |
| Ctrl+D | Duplicate selected row |
| E | Toggle selected ACE enabled/disabled |
| Q | Insert a comment row |
| F | Fold / unfold selected group |

---

## Key Differences from Current Chip Model

The current chip/span model places conditions/actions as inline chips that are:
- Narrow (only as wide as the text + small padding)
- Hard to hover/click precisely
- Hard to show clearly selected

The target GDevelop/C3 model uses:
- Full-width list entries
- Per-entry hover/select states
- Clear visual separation between condition entries (each gets its own row)

### Migration guidance

1. Continue using `EventSheetViewport`'s custom-render approach (do not switch to
   per-row Control widgets).
2. Improve chip-mode rendering constants for stronger hover/selection contrast
   (palette and renderer constants are the right place to tune).
3. `EventRowUI` (in `addons/eventforge/editor/`) already uses full-width list entries
   for conditions/actions and should be the target reference for the newer UI style.

---

## Construct 3 – Key Behavioral Reference Points

### ACE Entry Interaction
1. Move mouse over a condition/action entry → entry gets a highlight tint
2. Click once → entry becomes selected (distinct background + left accent)
3. Double-click → opens the ACE parameters dialog for that entry
4. Right-click → opens context menu (Edit, Replace, Add another, Invert, Delete)

### Group Selection
1. Click group header → entire group is selected (group row + all contained events)
2. Shift+click inside group → extends selection to include individual events
3. Ctrl+click → toggle-selects individual events within a group

### Drag to Move
1. Left-click-hold on condition entry → drag starts, cursor changes to grab
2. Entry follows cursor as a "ghost" overlay
3. Release over another condition entry → insert above/below/replace
4. Escape → cancel drag, restore original position

---

## Implementation Status (as of this PR)

| Feature | Status |
|---|---|
| Condition chip hover contrast | ✅ Improved (CHIP_HOVER_MIN_ALPHA raised to 0.42) |
| Condition chip selection contrast | ✅ Improved (CHIP_SELECT_ALPHA raised to 0.55–0.62) |
| Non-chip span hover | ✅ Improved (alpha raised to 0.46) |
| Row hover fill | ✅ Improved (COLOR_HOVER raised to 0.10) |
| Group selection includes all descendants | ✅ Fixed (span_index no longer blocks descendant collection for GROUP rows) |
| Variable row "Global" badge centered | ✅ Fixed (VERTICAL_ALIGNMENT_CENTER on badge Label) |
| Variable row double-click to edit | ✅ Fixed (variable_edit_requested signal on double-click) |
| EventRowUI entry-level selection visual | ✅ Added (set_selected_condition/action methods) |
| Full-width list entry model (EventRowUI) | ✅ Existing — EventRowUI uses full-width buttons |
| System ACE spec | ✅ Added (docs/spec/construct_3_system_aces_godot_variant_spec.md) |

---

## See Also

- `docs/spec/construct_3_system_aces_godot_variant_spec.md` — System ACE vocabulary
- `addons/eventforge/editor/event_row_ui.gd` — full-width list entry implementation
- `addons/eventsheet/editor/event_sheet_viewport.gd` — main viewport (chip model)
- `addons/eventsheet/editor/event_row_renderer.gd` — chip/span rendering constants
- `addons/eventsheet/theme/event_sheet_palette.gd` — color palette constants
- `AGENTS.md` — codebase conventions and future LLM guidance
