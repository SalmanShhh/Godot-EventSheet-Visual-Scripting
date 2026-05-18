# EventSheet Theme Token Spec

This token spec is modeled from the provided Construct 3 `theme.css`, but mapped into the current Godot-native EventSheet workflow.

## Construct 3 mapping

Construct-style CSS selectors map to Godot EventSheet tokens in three layers:

1. `EventSheetEventStyle` for shared sheet/block/lane/group/comment/interaction tokens
2. `EventSheetElementStyle` for condition/action chip tokens
3. Scene previews (`event_visual_element.tscn`, `condition_visual_element.tscn`, `action_visual_element.tscn`) for designer-facing template editing

## Token groups

### Sheet and event block shell

| Token | Godot field | Purpose |
|---|---|---|
| `sheet.background` | `EventSheetEventStyle.sheet_background_color` | Whole sheet canvas behind all rows |
| `event.background` | `row_background_color` | Primary event block background |
| `event.background_alt` | `row_background_alt_color` | Alternating event block background |
| `event.border` | `row_border_color` | Event block top/bottom edge contrast |
| `event.divider` | `lane_divider_color` | Split between condition/action lanes |

### Structural lanes and badge column

| Token | Godot field | Purpose |
|---|---|---|
| `condition.lane.background` | `condition_lane_color` | Left stacked condition lane |
| `condition.lane.padding` | `condition_lane_padding` | Left lane inner padding |
| `condition.badge_column.width` | `condition_badge_column_width` | Shared badge column for trigger / OR / invert |
| `action.lane.background` | `action_lane_color` | Right stacked action lane |
| `action.lane.padding` | `action_lane_padding` | Right lane inner padding |
| `event.minimum_height` | `minimum_row_height` | Minimum event block height before stacked rows expand it |

### Condition and action entry roles

| Token | Godot field | Purpose |
|---|---|---|
| `condition.name_text` | `EventSheetElementStyle.text_color` | Condition row readable text |
| `condition.entry.background` | `chip_background_color` | Condition chip fill |
| `condition.entry.border` | `chip_border_color` | Condition chip border |
| `condition.entry.hover` | `chip_hover_color` | Condition hover fill |
| `condition.badge.background` | `badge_background_color` | Trigger / OR / invert badge fill |
| `condition.badge.foreground` | `badge_foreground_color` | Trigger / OR / invert badge text |
| `action.name_text` | `EventSheetElementStyle.text_color` | Action row readable text |
| `action.entry.background` | `chip_background_color` | Action chip fill |
| `action.entry.border` | `chip_border_color` | Action chip border |
| `action.entry.hover` | `chip_hover_color` | Action hover fill |

### Name/description cell roles

Construct CSS often separates a name cell from a description/value cell. The current Godot renderer still paints one semantic span per authored entry, so both roles map to the same `text_color` token today.

- Condition name/description cell roles are previewed in `condition_visual_element.tscn` and `event_visual_element.tscn`
- Action name/description cell roles are previewed in `action_visual_element.tscn` and `event_visual_element.tscn`
- Future renderer passes can split these into separate text tokens without changing the overall token naming scheme

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

### Hover and selection states

| Token | Godot field | Purpose |
|---|---|---|
| `interaction.selection_fill` | `selection_fill_color` | Whole-row and marquee selection fill |
| `interaction.hover_fill` | `hover_fill_color` | Whole-row hover fill |
| `condition.entry.hover` | `EventSheetElementStyle.chip_hover_color` | Condition entry hover |
| `action.entry.hover` | `EventSheetElementStyle.chip_hover_color` | Action entry hover |

## Workflow mapping

### Scene-driven editing

Use these scenes when a designer wants to edit the preview directly in Godot:

- `res://addons/eventsheet/elements/event_visual_element.tscn`
- `res://addons/eventsheet/elements/condition_visual_element.tscn`
- `res://addons/eventsheet/elements/action_visual_element.tscn`

### Resource-driven editing

Use `EventSheetEditorStyle` when a designer wants installable, duplicable token packages:

- `event_style` = structural tokens
- `condition_style` = condition entry tokens
- `action_style` = action entry tokens

### Package/manifest workflow

Use `res://demo/themes/designer_template_theme_manifest.cfg` as the current template for a Construct-style installable theme package workflow.

It records:

- package metadata
- style resource path
- scene template paths
- token names to edit first

## Current renderer notes

- The custom viewport/event-row renderer remains the source of truth for layout and hit-testing.
- Tokens currently theme sheet background, event block backgrounds/borders, condition/action lanes, group/comment visuals, and hover/selection states.
- Condition/action name and description roles are intentionally documented now even though they still share one text style token in the current renderer.
