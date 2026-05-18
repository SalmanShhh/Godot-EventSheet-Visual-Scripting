@tool
class_name EventSheetThemeLayoutTemplate
extends Control

@export_group("Designer Guide")
@export_multiline var designer_usage_hint: String = "Open this scene first for a full visual EventSheet layout workflow. Edit the named preview nodes directly in the 2D editor, then save and use Reload Theme in the EventSheet dock to regenerate style tokens from this scene."
@export_multiline var scene_role_hint: String = "SheetBackground/EventBlockShell/ConditionLane/ActionLane/LaneDivider/BadgeColumn preview the structural layout shell. GroupBlock and CommentBlock preview non-event rows. HoverFillPreview and SelectionFillPreview preview interaction overlays."

@export_group("Layout + Alignment")
@export_range(0.20, 0.80, 0.01) var condition_lane_ratio: float = EventSheetPalette.CONDITION_LANE_RATIO
@export_range(120, 480, 1) var minimum_conditions_lane_width: int = int(EventSheetPalette.MIN_CONDITIONS_LANE_WIDTH)
@export_range(0, 32, 1) var condition_lane_padding: int = int(EventSheetPalette.CONDITION_LANE_PADDING)
@export_range(0, 64, 1) var condition_badge_column_width: int = int(EventSheetPalette.CONDITION_BADGE_COLUMN_WIDTH)
@export_range(0, 32, 1) var action_lane_padding: int = int(EventSheetPalette.ACTION_LANE_PADDING)
@export_range(1, 8, 1) var lane_divider_width: int = int(EventSheetPalette.LANE_DIVIDER_WIDTH)
@export_range(28, 96, 1) var minimum_row_height: int = EventSheetPalette.ROW_HEIGHT

@export_group("Condition Entry")
@export var condition_horizontal_padding: int = 8
@export var condition_vertical_padding: int = 2
@export var condition_gap_after: int = 8
@export var condition_badge_extra_width: int = 12
@export var condition_badge_text_color: Color = Color(0.82, 0.87, 0.95, 1.0)
@export var condition_font_size_delta: int = 0

@export_group("Action Entry")
@export var action_horizontal_padding: int = 8
@export var action_vertical_padding: int = 2
@export var action_gap_after: int = 8
@export var action_badge_extra_width: int = 12
@export var action_badge_text_color: Color = Color(0.82, 0.87, 0.95, 1.0)
@export var action_font_size_delta: int = 0

func build_editor_style_parts() -> Dictionary:
return {
"event_style": build_event_style(),
"condition_style": build_condition_style(),
"action_style": build_action_style()
}

func build_event_style() -> EventSheetEventStyle:
var style := EventSheetEventStyle.new()
style.sheet_background_color = _color_rect_color("SheetBackground", EventSheetPalette.BG_0)
style.row_background_color = _color_rect_color("EventBlockShell", EventSheetPalette.BG_0)
style.row_background_alt_color = _color_rect_color("EventBlockShellAlt", EventSheetPalette.BG_1)
style.row_border_color = _color_rect_color("EventBlockBorder", EventSheetPalette.COLOR_LANE_DIVIDER)
style.condition_lane_color = _color_rect_color("ConditionLane", EventSheetPalette.COLOR_LANE_CONDITIONS)
style.action_lane_color = _color_rect_color("ActionLane", EventSheetPalette.COLOR_LANE_ACTIONS)
style.lane_divider_color = _color_rect_color("LaneDivider", EventSheetPalette.COLOR_LANE_DIVIDER)
style.trigger_badge_background_color = _color_rect_color("BadgeColumn", EventSheetPalette.COLOR_TRIGGER_ARROW_BG)
style.trigger_badge_foreground_color = _color_rect_color("BadgeGlyph", EventSheetPalette.COLOR_TRIGGER_ARROW_FG)
style.condition_lane_ratio = condition_lane_ratio
style.minimum_conditions_lane_width = minimum_conditions_lane_width
style.condition_lane_padding = condition_lane_padding
style.condition_badge_column_width = condition_badge_column_width
style.action_lane_padding = action_lane_padding
style.lane_divider_width = lane_divider_width
style.minimum_row_height = minimum_row_height
style.group_background_color = _color_rect_color("GroupBlock", EventSheetPalette.COLOR_GROUP_BG)
style.group_background_alt_color = _color_rect_color("GroupBlockAlt", EventSheetPalette.COLOR_GROUP_BG_ALT)
style.group_accent_color = _color_rect_color("GroupAccent", EventSheetPalette.COLOR_GROUP_ACCENT)
style.group_title_color = _color_rect_color("GroupTitleSwatch", EventSheetPalette.COLOR_GROUP_TITLE)
style.group_badge_background_color = _color_rect_color("GroupBadge", EventSheetPalette.COLOR_GROUP_BADGE_BG)
style.group_badge_foreground_color = _color_rect_color("GroupBadgeText", EventSheetPalette.COLOR_GROUP_BADGE_FG)
style.group_fold_background_color = _color_rect_color("GroupFoldButton", EventSheetPalette.COLOR_GROUP_FOLD_BG)
style.comment_row_background_color = _color_rect_color("CommentBlock", EventSheetPalette.BG_1)
style.comment_text_color = _color_rect_color("CommentTextSwatch", EventSheetPalette.COLOR_COMMENT)
style.selection_fill_color = _color_rect_color("SelectionFillPreview", EventSheetPalette.COLOR_SELECTION)
style.hover_fill_color = _color_rect_color("HoverFillPreview", EventSheetPalette.COLOR_HOVER)
return style

func build_condition_style() -> EventSheetElementStyle:
return _build_element_style_from_button(
"ConditionEntryPreview",
condition_horizontal_padding,
condition_vertical_padding,
condition_gap_after,
condition_badge_extra_width,
condition_badge_text_color,
condition_font_size_delta
)

func build_action_style() -> EventSheetElementStyle:
return _build_element_style_from_button(
"ActionEntryPreview",
action_horizontal_padding,
action_vertical_padding,
action_gap_after,
action_badge_extra_width,
action_badge_text_color,
action_font_size_delta
)

func _build_element_style_from_button(
node_name: String,
horizontal_padding: int,
vertical_padding: int,
gap_after: int,
badge_extra_width: int,
badge_text_color: Color,
font_size_delta: int
) -> EventSheetElementStyle:
var style := EventSheetElementStyle.new()
var button: Button = _button_node(node_name)
if button == null:
return style
var normal_box: StyleBoxFlat = _resolve_flat_stylebox(button, "normal")
var hover_box: StyleBoxFlat = _resolve_flat_stylebox(button, "hover")
style.text_color = button.get_theme_color("font_color")
style.chip_background_color = normal_box.bg_color
style.chip_border_color = normal_box.border_color
style.chip_hover_color = hover_box.bg_color
style.badge_background_color = normal_box.bg_color.darkened(0.24)
style.badge_foreground_color = badge_text_color
style.font_size_delta = font_size_delta
style.horizontal_padding = horizontal_padding
style.vertical_padding = vertical_padding
style.gap_after = gap_after
style.corner_radius = normal_box.corner_radius_top_left
style.badge_extra_width = badge_extra_width
return style

func _button_node(node_name: String) -> Button:
var node: Node = find_child(node_name, true, false)
return node as Button if node is Button else null

func _color_rect_color(node_name: String, fallback: Color) -> Color:
var node: Node = find_child(node_name, true, false)
if node is ColorRect:
return (node as ColorRect).color
return fallback

func _resolve_flat_stylebox(button: Button, style_name: String) -> StyleBoxFlat:
if button == null:
return _fallback_stylebox()
var resolved: StyleBox = button.get_theme_stylebox(style_name)
if resolved is StyleBoxFlat:
return resolved as StyleBoxFlat
return _fallback_stylebox()

func _fallback_stylebox() -> StyleBoxFlat:
var fallback := StyleBoxFlat.new()
fallback.bg_color = Color(1.0, 1.0, 1.0, 0.08)
fallback.border_color = Color(1.0, 1.0, 1.0, 0.18)
fallback.set_border_width_all(1)
fallback.set_corner_radius_all(5)
return fallback
