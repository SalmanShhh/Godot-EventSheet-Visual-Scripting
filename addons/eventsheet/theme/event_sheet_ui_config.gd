## EventSheetUIConfig — Godot-native configuration resource for the EventSheet editor UI.
##
## Create an instance of this resource (File > New Resource > EventSheetUIConfig)
## and assign it via EventSheetDock.apply_ui_config() or the editor plugin to
## override the default EventSheet color palette and sizing constants.
##
## Example:
##   var config := EventSheetUIConfig.new()
##   config.group_bg_color = Color("#1a2030")
##   config.group_accent_color = Color("#6644ee")
##   event_sheet_dock.apply_ui_config(config)
@tool
class_name EventSheetUIConfig
extends Resource

## Background color for even-depth group rows.
@export var group_bg_color: Color = Color("#222139")
## Background color for odd-depth (alternating) group rows.
@export var group_bg_alt_color: Color = Color("#262444")
## Background color for regular event/comment/variable rows on even rows.
@export var row_bg_color: Color = Color("#1e1f24")
## Background color for regular event/comment/variable rows on odd rows.
@export var row_bg_alt_color: Color = Color("#24262d")
## Accent stripe / border color used on the left edge of group rows.
@export var group_accent_color: Color = Color("#8c78ff")
## Title text color for group row labels.
@export var group_title_color: Color = Color("#f2ecff")
## Background tint for the fold-arrow hit area inside a group row.
@export var group_fold_bg_color: Color = Color(0.55, 0.48, 0.94, 0.20)
## Group badge background color.
@export var group_badge_bg_color: Color = Color("#5b4db9")
## Group badge text color.
@export var group_badge_fg_color: Color = Color("#f4f0ff")

## Tint applied to the condition (left) lane background.
@export var lane_conditions_color: Color = Color(0.30, 0.56, 0.82, 0.08)
## Tint applied to the action (right) lane background.
@export var lane_actions_color: Color = Color(0.25, 0.66, 0.56, 0.06)
## Color of the thin vertical divider line between condition and action lanes.
@export var lane_divider_color: Color = Color("#2f3641")

## Row selection highlight color (should have low alpha).
@export var selection_color: Color = Color(0.36, 0.51, 0.79, 0.22)
## Row hover highlight color (should have very low alpha).
@export var hover_color: Color = Color(1.0, 1.0, 1.0, 0.045)

## Primary text color used for most row labels.
@export var text_primary_color: Color = Color("#d7dae0")
## Secondary / dimmed text color.
@export var text_secondary_color: Color = Color("#9aa1ad")
## Muted text color (line numbers, separators, etc.).
@export var text_muted_color: Color = Color("#6f7580")
## Event/object identifier color.
@export var object_text_color: Color = Color("#6bb6ff")
## Condition text color inside the conditions lane.
@export var condition_text_color: Color = Color("#d7dae0")
## Action text color inside the actions lane.
@export var action_text_color: Color = Color("#ffd166")
## Value text color for literals and variable values.
@export var value_text_color: Color = Color("#7ee787")
## Comment text color.
@export var comment_text_color: Color = Color("#7f848e")

## Background color for condition chips.
@export var condition_chip_bg_color: Color = Color(1.0, 1.0, 1.0, 0.05)
## Border color for condition chips.
@export var condition_chip_border_color: Color = Color(0.38, 0.67, 0.93, 0.26)
## Background color for action chips.
@export var action_chip_bg_color: Color = Color(1.0, 1.0, 1.0, 0.05)
## Border color for action chips.
@export var action_chip_border_color: Color = Color(0.98, 0.86, 0.44, 0.26)
## Background color for event comment chips.
@export var comment_chip_bg_color: Color = Color(1.0, 1.0, 1.0, 0.04)
## Border color for event comment chips.
@export var comment_chip_border_color: Color = Color(0.63, 0.66, 0.71, 0.24)
## Background color for variable scope chips.
@export var variable_chip_bg_color: Color = Color(0.26, 0.31, 0.39, 0.72)
## Border color for variable scope chips.
@export var variable_chip_border_color: Color = Color(0.58, 0.64, 0.74, 0.42)

## Trigger badge background color.
@export var trigger_badge_bg_color: Color = Color("#2ea043")
## Trigger badge text color.
@export var trigger_badge_fg_color: Color = Color("#f0fff4")
## OR badge background color.
@export var or_badge_bg_color: Color = Color(0.26, 0.29, 0.36, 0.95)
## OR badge text color.
@export var or_badge_fg_color: Color = Color(0.82, 0.87, 0.95, 1.0)
## Negated badge background color.
@export var negated_badge_bg_color: Color = Color(0.73, 0.20, 0.24, 0.95)
## Negated badge text color.
@export var negated_badge_fg_color: Color = Color(1.0, 1.0, 1.0, 1.0)
## Constant badge background color.
@export var const_badge_bg_color: Color = Color("#3e5c34")
## Constant badge text color.
@export var const_badge_fg_color: Color = Color("#eafde5")

## Base row height in logical pixels.
@export_range(20, 60, 1) var row_height: int = 28
## Base font size for row text.
@export_range(8, 24, 1) var font_size: int = 13
## Horizontal indent step per nesting level.
@export_range(8, 40, 1) var indent_width: int = 18
