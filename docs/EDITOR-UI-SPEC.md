# EventForge Editor UI Specification

## 1. Overview

This document captures the **currently implemented** EventForge editor UX and the immediate refinement direction.
It intentionally avoids describing unbuilt behavior as complete.

## 2. Current implemented UX

### 2.1 ACE picker window

- ACE selection uses a dedicated popup **Window** (`ACEPickerPopup`), not an inline inspector list.
- The picker window is titled and movable by the editor user.
- Picker title is mode-specific and visible in the window chrome and body header:
  - `Add Event`
  - `Add Condition`
  - `Replace Condition`
  - `Add Action`
- **Live search/filter**: A `LineEdit` (`ACEPickerSearch`) below the title allows real-time filtering of entries by name, description, or node type.  When the search box is non-empty, pre-declared empty group headers are hidden so only groups that contain a matching entry are shown.  Clearing the search restores the full grouped list.
- Picker entries are grouped by ACE category, with Construct-style event groups shown when adding events.
- ACE groups are colour-coded by type:
  - **Node-type groups** (e.g. `CharacterBody2D`, `Area2D`, `Node2D`, `Timer`, `AnimationPlayer`, `RigidBody2D`) use **amber** text — these group ACEs by the Godot class they belong to.
  - `Run Context / Triggers` uses teal-green.
  - `Variables` uses muted blue.
  - `Custom ACEs` (runtime providers) uses purple.
  - Other logical category groups use a neutral muted colour.
- **Per-item type colour-coding**: Each ACE entry in the picker tree has its text coloured by ACE type so conditions, actions, and triggers are visually distinguishable within a mixed group:
  - **Triggers** use soft green.
  - **Conditions** use soft blue.
  - **Actions** use soft teal.
- **Type-labelled tooltips**: Item tooltips are prefixed with the ACE type in brackets (e.g. `[Condition]  Is on floor`) so hovering immediately reveals whether an entry is a condition, action, or trigger.
- `ACEDescriptor` carries a `node_type` field that determines the primary group.  When `node_type` is non-empty it takes priority over `category`.
- `EVENT_PICKER_GROUPS` pre-declares node-type sections so they appear before descriptor scanning in the "Add Event" picker.  Pre-declared node types:
  - `CharacterBody2D`, `Area2D`, `Node2D`, `RigidBody2D`, `Timer`, `AnimationPlayer`
- Built-in ACEs tagged with their Godot class origin:
  - `IsOnFloor`, `MoveAndSlide`, `SetVelocity` → `CharacterBody2D`
  - `OnBodyEntered`, `OnAreaEntered` → `Area2D`
  - `SetPosition2D`, `SetRotationDeg` → `Node2D`
  - `ApplyCentralImpulse` → `RigidBody2D`
  - `StartTimer`, `StopTimer`, `IsTimerStopped`, `OnTimeout` → `Timer`
  - `PlayAnimation`, `StopAnimation`, `IsAnimationPlaying`, `OnAnimationFinished` → `AnimationPlayer`

### 2.2 ACE parameter dialog

- ACE params use a compact `ConfirmationDialog` popup (`ACE Parameters`) sized for fast edit/apply flow.
- Field layout is left-label / right-control per row.
- Parameter descriptions render below their corresponding control when present.
- If params were opened from the picker, the dialog shows `◀ Back` and returns to the same picker mode/context.
- If an ACE has zero editable params, it is applied immediately in single-apply mode (no redundant param dialog loop).
- Variable-reference params use a dropdown of current sheet variables.
  - When no variables exist, the dropdown shows `No variables available` disabled.
  - Apply is blocked for missing variable references.
  - The dialog hint explicitly tells the user to add a variable first.
- String params tagged with `hint = "expression"` show an inline `ƒx` button.
  - `ƒx` opens an **Insert Expression** picker popup backed by ACE descriptors of type `EXPRESSION`.
  - Expression entries are grouped by node type / namespace using the same grouping rules as the event picker (`node_type` first, then category/provider fallback).
  - Selecting an expression inserts its code template (with descriptor default params) into the target field.

### 2.3 Event sheet row UX

- Event rows use a **two-lane composition**: a condition lane (left) and an action lane (right), separated by a 2 px `ColorRect` lane divider — closely matching Construct 3's event sheet grammar.
- Rows avoid explicit lane headers (`IF`, `THEN`, `Conditions`, `Actions`, `when`, `do`) — the column position alone conveys lane identity.
- The condition lane occupies approximately 35 % of the row width (`COND_LANE_RATIO = 1.0`); the action lane occupies approximately 65 % (`ACTION_LANE_RATIO = 1.85`). These ratios are constant across all rows, providing cross-row column alignment.
- Each lane is a `PanelContainer` with a subtly distinct background tint:
  - Condition lane: `COND_LANE_BG` — slightly blue-tinted.
  - Action lane: `ACTION_LANE_BG` — near-neutral, leans teal.
- The outer `PanelContainer` (the row itself) carries zero content margins so the lane panels extend flush from the depth-accent left border to the right edge — lanes read as the row, not as widgets inside the row.
- **Condition lane** composition (top-to-bottom, then left-to-right):
  - Header row: `⋮` select handle · run-context/trigger button (expands) · `+` add-condition button.
  - `VBoxContainer` of condition entries, one per line — **C3-style vertical list**, not horizontal token chips.
- **Action lane** composition:
  - Header row: spacer (expands) · `+Add` action button.
  - `VBoxContainer` of action entries, one per line — **C3-style vertical list**, not horizontal token chips.
- Each condition/action entry is a full-width flat `Button` (left-aligned text, transparent background, subtle hover tint) that spans the entire column — no chip borders, no chip backgrounds. This matches Construct 3's text-based row grammar.
- The 2 px `LANE_DIVIDER_COLOR` `ColorRect` between lanes provides a clear, stable vertical boundary that creates the horizontal eventsheet rhythm.
- Condition entries use blue-tinted text; action entries use teal/green-tinted text — clearly distinct from each other.
- Entry text color uses C3-style column affinity: blue for conditions (cold/left), teal for actions (warm/right).
- A left gutter is rendered for every row, with branch guides for nested/sub-event rows.
- Condition and action entries are clickable (left-click to edit, right-click for context menu).
- Delete affordances are implemented:
  - event delete via inline row `✕` action (positioned right of the action lane)
  - condition delete via condition context menu (`Delete Condition`)
  - action delete via action context menu (`Delete Action`)
- Row-level insertion affordances are in-flow with the sheet row surface:
  - event rows expose `+↑` / `+↓` controls to insert a new event above or below
  - group rows expose `+↑` / `+↓` controls to insert sibling events above or below the group
  - comment rows expose `+↑` / `+↓` controls to insert inline comment rows above or below
  - insertion respects structural containers (root events, nested sub-events, and group child arrays) so above/below behavior stays local to hierarchy depth
- Events now provide a paired in-flow anchor: `Add Event` and `Add Comment`.
- `Add Event` now follows the same structural insertion context as group/comment add flows:
  - when an event/group/comment row is selected, the new event is inserted **below** that selected row
  - when nothing is selected, the new event is appended at root
  - the `Add Event` picker description explicitly states the current insertion placement target
- **Comment rows** are now **full-width amber banner rows** — no lane split. Layout:
  - A 3 px amber left-accent `ColorRect` (type indicator).
  - `//` prefix label.
  - Inline `LineEdit` spanning the full remaining width (transparent background, amber text).
  - `+↑` / `+↓` / `✎` / `×` contextual controls (dimmed at rest, brightened on hover/selection).
  - Comments are visually distinctive through amber background color, not through a lane split.
- Comment rows support direct inline text editing, with inspector text editing kept in sync.
- Condition/action entries support drag-and-drop reordering and cross-event moves (via `EntryTokenButton`).
- Comment rows support drag-and-drop relocation above/below event rows and relative to other comment rows.
- Row-level insertion controls are intentionally de-emphasized at rest and become full-emphasis on row hover/selection.
- When deleting a focused condition/action, inspector selection falls back to the owning event view.
- Variable and group rows share the same sheet-line/gutter composition model.
- **Group rows** are now **full-width header rows** — no lane split. Layout:
  - A 3 px purple/indigo left-accent `ColorRect`.
  - Collapse/expand `▶/▼` button.
  - `Group` type label.
  - Group name label (expands).
  - Event count label (e.g. `(2)`).
  - `+↑` / `+↓` / `✎` / `×` controls.
  - Groups are visually distinctive through purple/indigo background color.
- Variable rows remain compact in-canvas, with rich hover tooltips that include type/default and optional variable descriptions.

### 2.4 Editor shell and document framing

- EventForge registers as a **main editor workspace** via `EditorPlugin._has_main_screen()`.
- EventSheet editing is hosted in the central editor viewport, not a bottom dock panel.
- Selecting an `EventSheetResource` in the editor routes into this workspace via plugin `_handles()`/`_edit()` integration.
- The editor uses a main-screen workspace shell modelled after Godot's Script editor:
  - **Toolbar** spans the full workspace width, flush at the top with no outer margin — no dock-panel-era padding above or beside it.
  - Toolbar background has zero corner radius so it sits flush at the top edge of the workspace.
  - Toolbar bottom border (1 px) provides the only visual separation from the content area below.
  - Top row of the toolbar: `EventSheet` label | separator | sheet name | dirty indicator | document meta | separator | selection meta | spacer
  - Top row now also includes a **document path hint** between document meta and selection meta so the active resource path is always visible.
  - Action row of the toolbar: `New Sheet` | `Open` | `Save` | `Save As…` | separator | `+ Event` | `+ Variable` | shortcut hints | spacer | `Compile Preview`
  - **Dirty indicator** `●` (amber dot) appears next to the sheet name when the sheet has unsaved changes; hidden when the sheet is clean.
  - **Save / Save As** buttons are present and enabled whenever a sheet is loaded.
  - Canvas section and inspector section have small 6 px breathing margins on left/right/top and 4 px bottom margin — just enough visual separation from the toolbar, no bottom-dock-era outer padding.
  - **Status bar** sits at the very bottom of the workspace, full-width, with a 1 px top border — matches the Godot editor idiom for script-editor feedback lines.
  - Status bar shows operation results (save, compile, add/delete events and variables) replacing the old toolbar top-row status text.
- Keyboard workflow shortcuts:
  - `Ctrl+S` → save sheet in place (Save As if no path)
  - `Ctrl+Shift+S` → save sheet to new path (Save As)
  - `Ctrl+E` → add event (inserts below selected row context when available; otherwise appends at root)
  - `Ctrl+Shift+V` → add variable
  - `Ctrl+Shift+C` → add condition on selected event row
  - `Ctrl+Shift+A` → add action on selected event row
  - `Q` → add comment row using current structural selection context
  - `G` → add group (inserts EventGroup relative to selection or appends at bottom)
  - `Ctrl+C` → copy selected event row (including nested sub-events)
  - `Ctrl+V` → paste copied event row below current selection context
  - `Ctrl+D` → duplicate selected event row (deep clone + insert immediately after source)
  - `Delete` → remove selected event/condition/action/variable/group
  - `Escape` → clear current selection (show empty inspector)
  - `Enter` / `KP Enter` → edit current selection (open params dialog for condition/action, add-condition picker for event, or focus inline text edit for comment)
  - `↑` / `↓` → navigate selection up or down through the visual row order (works for EventRowUI, GroupRowUI, and CommentRowUI; blocked when a LineEdit/TextEdit/SpinBox has focus)
- **Dirty state tracking**: `EventSheetEditor._is_dirty` is set on every mutation (add/edit/delete events, conditions, actions, variables, groups, condition inversion) and cleared on sheet load or successful save.
- Document header (`SheetDocumentHeader`) inside the canvas shows:
  - The sheet file name (or "Untitled Sheet" / "No Sheet Loaded") as the document title
  - The sheet resource path as a secondary hint line (`Unsaved (in-memory)` for unsaved sheets)
  - A summary of globals and root entries
  - A 3px left-accent border rail to visually anchor the header as the document root
- Canvas uses a **document strip** (`SheetCanvasDocumentStrip`) above the scroll surface:
  - Shows `EventSheetResource` kind tag
  - Shows an active-resource tab shell (`SheetCanvasResourceTab`) with document title + dirty dot
  - Shows resource path hint beside the active tab shell
  - Uses a 1px bottom border like editor tab/resource strips
- Central workspace composition now uses `HSplitContainer` (`WorkspaceSplit`) for
  canvas/inspector, matching the dedicated-editor split model instead of a fixed
  panel stack + separator.
- Document framing keeps `SheetSectionGlobals` as a shell, while `SheetSectionEvents` is now a flatter continuous host so authored rows dominate the canvas.
- The document header card (formerly `SheetDocumentHeader`) is no longer rendered inside the canvas scroll surface — resource info is exclusively shown in the `SheetCanvasDocumentStrip` above the canvas. This keeps the scrollable area free for event rows from the very first pixel.
- Section headers use a `ColorRect` accent rail in the header instead of a bullet label, providing a design-system-consistent visual hierarchy.
- Each section header is separated from its body by an `HSeparator` to create a clear visual tier.
- Section empty states are rendered as styled `PanelContainer` cards, providing a consistent visual affordance.
- Empty states are presented as centered onboarding cards with direct create/open actions.
- The inspector empty state is rendered as a contextual card to keep selection/idle surfaces visually consistent with canvas sections.
- Inspector content for selected events, variables, and groups is wrapped in consistently styled card shells using the same design system as the empty state card.
- Each inspector card includes a tinted `HSeparator` immediately after the heading label, separating the card type label from its content rows.

### 2.7 Dense-sheet readability (Phase 5)

- Row wrap margins are 1px top/bottom (down from 2px) for denser sheet rendering.
- Canvas `VBoxContainer` separation is 1px (down from 6px in Phase 8) for continuous packed sheet presentation.
- Section body `VBoxContainer` separation is 3px (down from 4px).
- All row types (event, variable, group) use tighter content margins (top/bottom 3px for events, 5px for variable/group).
- Event, variable, and group rows use a `border_width_left` of 3+depth (up from 2+depth) for a stronger depth hierarchy accent.
- Depth guide `ColorRect` lines use opacity 0.80 (up from 0.68) for better visibility at depth.
- Event rows use a 2 px `ColorRect` lane divider (`LANE_DIVIDER_COLOR`) replacing the earlier `VSeparator` for a stronger, pixel-stable lane boundary.

### 2.8 Final cross-surface polish (Phase 6)

- Inspector cards use `border_width_left = 3` for a left accent rail, visually anchoring them like row panels.
- The inspector empty state includes an `HSeparator` after the "Inspector" heading, consistent with the event/variable/group inspector cards.
- The group inspector card styles the Enabled and Collapsed labels with semantic colors: green-tinted for `true`, red-tinted for `false`, and muted blue-grey for Collapsed.
- Section header separators are tinted with the section's accent color at low opacity (0.30), replacing the previous generic border color — improving visual coherence between the section accent rail and its separator.
- The toolbar top row adds a `VSeparator` between the document-meta label and the selection-meta label for clearer visual separation of the two context streams.
- The `+ action` inline button uses teal/green font colors matching the action lane (`do` clause prefix), making lane affinity of add buttons visually consistent (blue `+ condition` → blue condition lane, teal `+ action` → teal action lane).

### 2.9 Horizontal eventsheet lane composition (Phase 7)

- Event rows now use a **two-panel lane layout**: a condition lane (`PanelContainer`, ~35% width) and an action lane (`PanelContainer`, ~65% width), with a 2 px `ColorRect` divider between them.
- Both lane panels have zero outer separation (`HBoxContainer.separation = 0`) so the lanes sit flush against each other and the row border, composing a single horizontal eventsheet lane rather than floating widgets.
- The run-context (trigger) button is anchored at the top of the condition lane and expands horizontally — it reads as the event's "heading" within the lane, making the trigger identity immediately visible.
- The `+ condition` button moves into the condition lane header row, keeping add affordances visually co-located with their lane.
- The `+Add` action button sits at the trailing edge of the action lane flow, keeping it within the action lane with compact labeling.
- The `✕` delete button sits outside both lane panels at the far-right edge of the row.
- Consistent `COND_LANE_RATIO` / `ACTION_LANE_RATIO` constants ensure the lane boundary remains at the same horizontal position across all rows, creating a stable eventsheet column grid.
- Lane spacing and token padding are tightened (`h_separation`/`v_separation` and lane panel insets) to increase vertical density while keeping row readability.
- Run-context and condition/action entries use square, bordered cell styling (including a stronger left border accent on tokens) so entries read as sheet cells rather than rounded chips.
- Empty lane placeholders are lane-tinted (condition vs action) to preserve lane identity even when one side has no authored entries.
- Nested sheet gutters use tighter spacing plus stronger guide contrast to improve parent/child readability in dense lane-based rows.
- Events section now uses an in-flow `Add Event` anchor row aligned to the same gutter/row grid as authored event rows.

### 2.10 Row type badges
- Group rows use the **4 px purple accent strip** as the sole type indicator (no text `Group` badge needed).
- Group rows display the event count in parentheses when the group has child events (e.g., `(2)`).
- The event count label is hidden (empty string) when the group has no child events.
- Comment rows use `#` as a plain text prefix label within the amber banner row.

### 2.11 C3-aligned sheet-level anatomy (Phase 8)

This phase pushes the EventSheet editor from row-anatomy improvements toward a full
Construct 3-style event sheet surface, guided by `c3-eventsheet-spec.md` and
`godot-c3-eventsheet-port.md`.

#### Sheet structure
- `SheetSectionEvents` is now a plain `VBoxContainer` (not a PanelContainer), making the
  events body a continuous unframed host — events dominate the canvas surface.
- Canvas `VBoxContainer` separation reduced from 6 px to **1 px** so rows read as a
  continuous packed sheet rather than spaced-out widgets.
- Canvas outer margin reduced to **zero** — rows extend edge-to-edge, matching C3's
  full-width sheet surface.
- Document header card removed from `refresh_canvas()` — resource info lives in the
  existing `SheetCanvasDocumentStrip`, not as a repeated sheet-interior widget.

#### C3-style column header bar
- A `SheetColumnHeader` `PanelContainer` is now rendered at the top of the events
  section, pinned above all rows.
- The header shows **"Conditions"** (left, blue-tinted) and **"Actions"** (right,
  teal-tinted) labels aligned with the actual lane columns in every event row below —
  making the two-column authoring surface immediately readable.
- A `gutter_spacer` Control of exactly `SHEET_GUTTER_BASE_WIDTH` pixels keeps the
  "Conditions" label aligned to the left edge of the conditions column, not the sheet edge.
- A 2 px `ColorRect` divider in the header mirrors the lane divider in event rows,
  creating a consistent vertical column boundary from the header down through all rows.
- A right-side `controls_spacer` Control accounts for row-level controls (insert/delete
  buttons) so the column labels are not visually offset by the controls column.

#### Gutter improvements
- The per-row gutter width is now determined by `SHEET_GUTTER_BASE_WIDTH + indent_level
  × SHEET_GUTTER_INDENT_WIDTH` constants (`18 px` base, `14 px` per indent level) for
  explicit, stable sizing.
- The leftmost gutter element is now a 2 px `ColorRect` rail (solid boundary colour)
  rather than a `│` text label — a pixel-accurate boundary that scales cleanly.
- Per-depth continuation rails are now `1 px ColorRect` slices preceded by explicit
  spacer Controls of `SHEET_GUTTER_INDENT_WIDTH - 1` px — the spacer + rail pattern
  ensures each depth level's guide line is positioned exactly at the branch origin point.
- Rail opacity now increments with depth (`minf(0.55 + depth × 0.06, 0.95)`, clamped below 1.0) so deeper guides are
  progressively more visible, helping hierarchy readability in dense sheets.
- `SheetLineRow` HBoxContainer separation reduced to **0** — rows and their gutters are
  flush-adjacent, no gap between the gutter column and the row content.
- Nested rows now include a short horizontal connector stub at the gutter end, so
  parent→child branch continuity reads as an actual tree connection rather than
  indentation alone.
- Nested rows now include a subtle 2 px "nested lead" strip between gutter and row
  body, making top-level vs nested event rhythm clearer in dense sheets.

#### Anchor row (C3-style sheet footer)
- The "Add Event / Add Group / Add Comment" anchor row is now placed at the **bottom**
  of the events section (after the last event row), wrapped in a thin
  `PanelContainer` with a top border — reads as a sheet footer, not as a top-of-sheet
  toolbar.
- The anchor row contains three flat buttons: **"Add Event"**, **"Add Group"**, and
  **"Add Comment"**, separated by `VSeparator`s.  Each button uses colour-coded text
  matching its row type (blue / purple / amber).
- The left margin of the anchor wrapper matches `SHEET_GUTTER_BASE_WIDTH` so its
  content is horizontally aligned with the event row content (not with the gutter).

#### "Add Group" authoring
- `_on_add_group_requested()` is now wired to the anchor row "Add Group" button.
- Creates an `EventGroup` with `group_name = "New Group"`, appends it to
  `current_sheet.events` (or inserts relative to the selected row), refreshes the
  canvas, and focuses the new group row.

#### Group row improvements
- Left accent strip widened from 3 px to **4 px** — clearer visual boundary, matching
  the C3 port guide's `ColorAccent (ColorRect, 4px wide)` specification.
- `_apply_row_style` now uses named colour constants (`GROUP_BG`, `GROUP_BG_HOVER`,
  `GROUP_BG_SELECTED`, `GROUP_BORDER*`) for clarity and consistency.
- Content margins simplified: the PanelContainer panel handles no left margin (accent
  is provided by the ColorRect, not the border), 0 top/bottom from the panel (margin
  in the HBoxContainer separation), and 4 px right.
- **Enabled/disabled visual state**: when `event_group.enabled == false`:
  - A `_disabled_badge` Label ("Disabled", red-tinted) is shown.
  - The entire row is dimmed to **55 % opacity** — matching the C3 port guide's
    "Disabled groups are rendered at 40% opacity" guidance, adjusted to 55% for
    dark-theme readability.
- When `enabled == true`, the badge is hidden and opacity is 100 %.
- Group rows now expose an inline enable/disable `CheckBox` (left of the group name)
  that toggles `event_group.enabled` directly in-row and immediately refreshes the
  sheet + inspector selection context.
- The `"Group"` type badge label is removed from the layout — the purple accent strip
  and the name label alone identify the row type cleanly.
- Child-count readability now improves when collapsed:
  - expanded group count shows `(N)`
  - collapsed group count shows `(N hidden)`

#### Comment row improvements
- Left accent strip widened from 3 px to **4 px** — matches the group row update for
  visual consistency across full-width row types.
- Prefix label changed from `//` (two-slash code comment) to `#` (single-hash section marker) — closer to C3's section-annotation style
  (single-hash section markers).
- Named colour constants (`COMMENT_ACCENT`, `COMMENT_BG*`, `COMMENT_BORDER*`) used
  throughout for maintainability.
- Comment banners now support style-aware and `color_tag`-aware palettes:
  - `color_tag` values (e.g. `blue`, `green`, `red`, `orange`, `grey`) map to distinct
    section colours
  - fallback mapping from `CommentStyle` (`NOTE`, `TODO`, `WARNING`, `SECTION`) maps to
    corresponding palettes
  - default remains warm yellow/amber
- Content margins simplified: no left margin in PanelContainer (accent handled by
  ColorRect), 3 px top/bottom, 4 px right.
- Background colour slightly warmer/more saturated amber (`0.156, 0.128, 0.064`) for
  a cleaner banner differentiation from event rows.

### 2.12 Sub-event support status

- Sub-event rendering groundwork exists:
  - nested event resources are rendered with indentation
  - recursive sub-event deletion by UID is supported in editor-side removal logic
- Full sub-event authoring UX is **not** implemented yet (no complete add/move/reparent/drag-drop authoring flow).

### 2.13 Workflow fluency and interaction polish (Phase 9)

This phase improves authoring speed, keyboard navigation, and drag/drop visual feedback
inside the Construct 3-style sheet established by Phase 8.

#### Keyboard navigation
- **`↑` / `↓` arrow keys** navigate the selection through all visual row types
  (EventRowUI, GroupRowUI, CommentRowUI) in top-to-bottom order.  Blocked when a
  LineEdit, TextEdit, or SpinBox has keyboard focus so typing is never interrupted.
- `_collect_selectable_rows_in_order(node, result)` helper traverses the canvas tree
  depth-first to produce the ordered list used by the arrow-key handler.

#### New keyboard shortcuts
- **`G`** (no modifiers) → add group; inserts an `EventGroup` relative to the current
  selection (same structural context as `Q` for comments), or appends at the bottom.
- **`Ctrl+D`** → duplicate event; deep-clones the selected `EventRow` (preserving
  conditions, actions, and sub-event hierarchy) and inserts the clone immediately after
  the source row.  The clone receives a fresh `event_uid`.
- **`Escape`** (no modifiers) → deselect; calls `_show_empty_inspector()` to clear the
  selection state and reset the inspector, giving a fast "step back" action.
- **`Enter` / `KP Enter`** (no modifiers) → edit selection:
  - condition selected → opens params dialog for that condition
  - action selected → opens params dialog for that action
  - event selected → opens the add-condition picker for that event
  - comment selected → grabs text focus in the comment row's inline `LineEdit`

#### Comment auto-focus
- After inserting a comment row (via `Q`, anchor row "Add Comment", or relative
  insertion), the inline `LineEdit` in the new row receives keyboard focus automatically
  — the cursor appears ready to type the comment text without a second click.
- `CommentRowUI.grab_text_focus()` is the public method for this; it moves focus to
  `_comment_text_edit` and places the cursor at the end of any existing text.
- `EventSheetEditor._focus_comment_row_text(comment_row: CommentRow)` calls this from
  the editor side by locating the row widget and calling `grab_text_focus()`.

#### Drag/drop visual feedback
- **EventRowUI**: a semi-transparent blue tint overlay (`_drop_highlight_rect`) appears
  over the entire row when a valid condition, action, or comment is dragged over it.
  The overlay is a `ColorRect` added as the last child of the `PanelContainer`, so it
  composites above the lane panels; `mouse_filter = MOUSE_FILTER_IGNORE` means it never
  blocks pointer events to children.  `_set_drop_hovered(bool)` toggles the overlay and
  enables/disables `_process`; `_process` clears the state when the drag ends without
  dropping (i.e. `gui_is_dragging()` returns false).
- **CommentRowUI**: the same overlay mechanism (`_drop_highlight_rect`) shows a warm
  amber tint when another comment row is dragged over it.  `_set_drop_indicator(frac)` /
  `_clear_drop_indicator()` / `_update_drop_highlight()` manage the state.
- **Styled drag previews**: both `EntryTokenButton` (condition/action entries) and
  `CommentRowUI` now produce a styled `PanelContainer` drag preview instead of a plain
  `Label`.  Condition previews use the blue lane palette; action previews use the teal
  lane palette; comment previews use the amber banner palette.
- **Viewport ACE drag previews** now pair insertion lines with stronger destination cues:
  - event-block target highlight
  - destination placeholder chip slot
  - source chip emphasis only on the dragged condition/action entries

#### Selection emphasis
- Event-block selection uses a distinct event-block visual role.
- Subtree selection uses a secondary subtree role so descendants remain visibly related to the selected parent event.
- Condition/action selection keeps focus on the selected chip(s) with stronger entry-level outlines instead of row-level-only emphasis.

#### Toolbar shortcut hints
- The shortcuts hint strip in the toolbar now also shows:
  `G Group` · `Ctrl+D Duplicate` · `Esc Deselect`

## 3. Still planned (not implemented yet)

- Multiple EventSheet tabs (Phase 2.4)
- Group-local variables and nested group bodies (Phase 2.5)
- Sheet functions / local subsheets (Phase 3)
- Scripted ACE providers (Phase 4)
- Scripted structural blocks (Phase 5)
- Full importer / round-trip pipeline (Phase 6)

## 4. Implementation anchors

- Main editor: `addons/eventforge/editor/event_sheet_editor.gd`
- Event row inline clauses/menus: `addons/eventforge/editor/event_row_ui.gd`
- Group groundwork row: `addons/eventforge/editor/group_row_ui.gd`

Current selection state is tracked by entry kind (`event`, `condition`, `action`, `variable`, `group`) plus row/index references in `EventSheetEditor`.
