# EventSheet Theme Token Spec

The theming contract for the EventSheet editor. Tokens live on three resources —
`EventSheetEditorStyle` (the installable package) holding one `EventSheetEventStyle`
(sheet/block/lane/semantic tokens) and two `EventSheetElementStyle`s (condition / action
entry tokens). This spec is modeled on Construct 3's theme system but exposes a far richer
sheet surface than C3's public theme API.

## Construct 3 mapping

Construct 3 themes are CSS-variable packages (see the C3 theme SDK: `addon.json` +
`theme.css`). Their public surface is small (window chrome, icon recolors,
`--event-sheet-background-color`); ours maps the same idea into typed Godot resources:

1. `EventSheetEventStyle` — shared sheet/block/lane/group/comment/interaction/semantic tokens
2. `EventSheetElementStyle` — condition/action entry tokens
3. Scene previews (`event_visual_element.tscn`, `condition_visual_element.tscn`,
   `action_visual_element.tscn`) for designer-facing template editing

Direct C3-variable equivalents: `--event-sheet-background-color` →
`sheet_background_color`; `--invert-icon-color` → `invert_marker_color`.

### Stability contract

- Every `@export` on the three style resources is **stable theme API**: existing `.tres`
  themes keep loading when tokens are added (missing properties fall back to defaults).
- Tokens are never renamed/removed without a CHANGELOG migration note.
- Colors accept any Godot `Color` (alpha included) — no six-digit-hex restriction like C3.
- `docs_integrity_test.gd` guards this spec; `theme_presets_test.gd` guards preset loading.

## Token groups

### Sheet and event block shell

| Token | Godot field | Default | Purpose |
|---|---|---|---|
| `sheet.background` | `EventSheetEventStyle.sheet_background_color` | palette `BG_0` | Whole sheet canvas behind all rows |
| `event.background` | `row_background_color` | palette `BG_0` | Primary event block background |
| `event.background_alt` | `row_background_alt_color` | palette `BG_1` | Alternating event block background |
| `event.border` | `row_border_color` | lane divider color | Event block top/bottom edge |
| `event.divider` | `lane_divider_color` | palette divider | Split between condition/action lanes |
| `event.minimum_height` | `minimum_row_height` | `ROW_HEIGHT` | Minimum block height before stacking |

### Structural lanes and badge column

| Token | Godot field | Default | Purpose |
|---|---|---|---|
| `condition.lane.background` | `condition_lane_color` | palette | Left condition lane fill |
| `condition.lane.padding` | `condition_lane_padding` | palette | Left lane inner padding |
| `condition.lane.ratio` | `condition_lane_ratio` | `0.38` | Conditions/actions split (drag-resizable in-editor, 0.2–0.8) |
| `condition.badge_column.width` | `condition_badge_column_width` | palette | Shared badge column (trigger / OR / invert) |
| `action.lane.background` | `action_lane_color` | palette | Right action lane fill |
| `action.lane.padding` | `action_lane_padding` | palette | Right lane inner padding |

### Condition and action entries (flat cells)

Entries render as flat full-line cells (C3-style contiguous blocks), not rounded chips.

| Token | Godot field | Default | Purpose |
|---|---|---|---|
| `condition.name_text` | `EventSheetElementStyle.text_color` | palette | Condition text |
| `condition.entry.background` | `chip_background_color` | palette | Condition cell fill |
| `action.name_text` | `EventSheetElementStyle.text_color` | palette | Action text |
| `action.entry.background` | `chip_background_color` | palette | Action cell fill |
| `condition.badge.background` | `badge_background_color` | palette | Trigger/OR badge fill |
| `condition.badge.foreground` | `badge_foreground_color` | palette | Trigger/OR badge text |
| `trigger.badge.background` | `EventSheetEventStyle.trigger_badge_background_color` | palette | Trigger ➜ arrow circle |
| `trigger.badge.foreground` | `trigger_badge_foreground_color` | palette | Trigger ➜ arrow glyph |

### Semantic colors (C3-style reading aids)

| Token | Godot field | Default | Purpose |
|---|---|---|---|
| `ace.object_label` | `EventSheetEventStyle.object_label_color` | palette `COLOR_OBJECT` | "System" / node-class label before each ACE |
| `ace.value_highlight` | `value_highlight_color` | palette `COLOR_VALUE` | Numbers/strings/booleans inside ACE text |
| `condition.invert_marker` | `invert_marker_color` | `#FF0000` | Red ✗ on inverted conditions (C3 `--invert-icon-color`) |
| `interaction.cell_hover` | `cell_hover_color` | `Color(1,1,1,0.14)` | Hover tint on an individual condition/action cell |

### Group and comment blocks

| Token | Godot field | Purpose |
|---|---|---|
| `group.background` | `group_background_color` | Group row block fill |
| `group.background_alt` | `group_background_alt_color` | Alternating group fill |
| `group.accent` | `group_accent_color` | Left accent rail and separators |
| `group.title` | `group_title_color` | Group label text |
| `group.badge.background` | `group_badge_background_color` | Group badge fill |
| `group.badge.foreground` | `group_badge_foreground_color` | Group badge text |
| `group.fold.background` | `group_fold_background_color` | Fold button backdrop |
| `comment.background` | `comment_row_background_color` | Standalone comment block fill |
| `comment.text` | `comment_text_color` | Comment text color |

### Column header band

| Token | Godot field | Default |
|---|---|---|
| `header.background` | `column_header_background_color` | `#22242b` |
| `header.conditions_text` | `column_header_conditions_color` | `#8fb0e0` |
| `header.actions_text` | `column_header_actions_color` | `#6fd0bf` |

### Hover and selection states

| Token | Godot field | Purpose |
|---|---|---|
| `interaction.selection_fill` | `selection_fill_color` | Whole-row / marquee selection fill (cells add a left accent bar) |
| `interaction.hover_fill` | `hover_fill_color` | Whole-row hover (single-cell rows only) |
| `interaction.cell_hover` | `cell_hover_color` | Per-cell hover (see semantic colors) |

## Workflow mapping

### Godot-native default (editor theme adapter)

Sheets without an explicit theme adopt the running Godot editor's colors via
`EventSheetGodotTheme.adapt_to_editor` (no-op outside the editor; explicit themes are
untouched):

| Editor theme color | Sheet tokens |
|---|---|
| `dark_color_2` | sheet background, column header background, trigger badge foreground |
| `dark_color_1` | row background (alt = lerp toward base), comment background |
| `accent_color` | group accent, selection fill (α 0.16), trigger badge background |
| `font_color` | group title, comment text (α 0.55), header text (α 0.75), hover fill (α 0.04) |

### Resource-driven editing

Use `EventSheetEditorStyle` for installable, duplicable token packages: `event_style` =
structural + semantic tokens, `condition_style` / `action_style` = entry tokens. The
toolbar theme switcher lists presets from `res://addons/eventsheet/themes/` and
`res://demo/themes/`; lane-divider drags persist `condition_lane_ratio` onto the sheet's
style.

### Scene-driven editing

Designers can edit previews directly: `res://addons/eventsheet/elements/*.tscn`
(`event_visual_element`, `condition_visual_element`, `action_visual_element`).

### Package/manifest workflow

`res://demo/themes/designer_template_theme_manifest.cfg` remains the Construct-style
installable theme package template (package metadata, style resource path, scene template
paths, first tokens to edit).

## Current renderer notes

- The custom virtualized viewport/renderer remains the source of truth for layout and
  hit-testing; themes never change layout logic, only tokens.
- Cells are flat, full-line, contiguous (C3 block look); selected cells draw the accent
  fill + left accent bar; disabled rows/ACEs draw strikethrough text.
- Text rasterizes at the physical pixel size for the current zoom (crisp at any zoom);
  group titles draw one size larger.
- Condition/action name and description roles still share one `text_color` token; a future
  renderer pass can split them without renaming existing tokens.
