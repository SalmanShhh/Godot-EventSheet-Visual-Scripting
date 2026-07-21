# EventSheet - editor style/resource regression tests
@tool
class_name EventSheetStyleTest
extends RefCounted

const TEST_LONG_CONDITION_PROVIDER := "TestLongCondition"
const TEST_LONG_ACTION_PROVIDER := "TestLongAction"
const EXAMPLE_THEME_PATHS := [
	"res://demo/themes/high_contrast_theme.tres",
	"res://demo/themes/soft_light_theme.tres",
	"res://demo/themes/designer_template_theme.tres",
	"res://demo/themes/dracula_theme.tres",
	"res://demo/themes/nord_theme.tres",
	"res://demo/themes/gruvbox_dark_theme.tres",
	"res://demo/themes/monokai_theme.tres",
	"res://demo/themes/solarized_light_theme.tres",
	"res://demo/themes/catppuccin_mocha_theme.tres"
]
const DESIGNER_THEME_MANIFEST_PATH := "res://demo/themes/designer_template_theme_manifest.cfg"


static func run() -> bool:
	var passed: bool = true
	var style := EventSheetEditorStyle.new()
	passed = _check("style creates event style resource", style.event_style != null, true) and passed
	passed = _check("style creates condition style resource", style.condition_style != null, true) and passed
	passed = _check("style creates action style resource", style.action_style != null, true) and passed
	passed = _check("style exposes sheet background token", style.event_style.sheet_background_color.a > 0.0, true) and passed
	passed = _check("style exposes group badge token", style.event_style.group_badge_background_color.a > 0.0, true) and passed
	passed = _check("style exposes comment token", style.event_style.comment_text_color.a > 0.0, true) and passed
	passed = _check("style exposes interaction token", style.event_style.selection_fill_color.a > 0.0, true) and passed
	# The gutter (line + event numbers) is themeable: tokens exist and seed from the palette,
	# so the auto-enumerating Theme Editor picks them up with sane defaults.
	passed = _check("gutter background token seeds from the palette",
		style.event_style.gutter_background_color, EventSheetPalette.COLOR_GUTTER_BG) and passed
	passed = _check("gutter text token seeds from the palette",
		style.event_style.gutter_text_color, EventSheetPalette.COLOR_GUTTER_TEXT) and passed
	# Published-verb tokens seed from the palette, so a fresh style keeps the shipped look.
	passed = _check("verb role accents seed from the palette",
		style.event_style.ace_action_accent_color == EventSheetPalette.COLOR_ACE_ACTION_BADGE_FG
		and style.event_style.ace_condition_accent_color == EventSheetPalette.COLOR_ACE_CONDITION_BADGE_FG
		and style.event_style.ace_expression_accent_color == EventSheetPalette.COLOR_ACE_EXPRESSION_BADGE_FG, true) and passed
	passed = _check("verb wash strength defaults to the tuned dark-sheet value",
		is_equal_approx(style.event_style.verb_row_tint_strength, 0.10), true) and passed
	# EVERY bundled preset dresses published verbs in ITS OWN palette. A preset that skipped them would
	# fall back to EventForge's amber/teal/purple and stop looking like the theme it claims to be, so
	# each one must set all three roles, and they must be distinguishable from each other.
	for theme_path: String in EXAMPLE_THEME_PATHS:
		var preset: EventSheetEditorStyle = load(theme_path) as EventSheetEditorStyle
		if preset == null or preset.event_style == null:
			passed = _check("preset loads: %s" % theme_path, false, true) and passed
			continue
		var preset_style: EventSheetEventStyle = preset.event_style
		var theme_name: String = theme_path.get_file()
		passed = _check("%s dresses verbs in its own palette (not the default amber)" % theme_name,
			preset_style.ace_action_accent_color != EventSheetPalette.COLOR_ACE_ACTION_BADGE_FG, true) and passed
		passed = _check("%s keeps its three verb roles distinguishable" % theme_name,
			preset_style.ace_action_accent_color != preset_style.ace_condition_accent_color
			and preset_style.ace_condition_accent_color != preset_style.ace_expression_accent_color
			and preset_style.ace_action_accent_color != preset_style.ace_expression_accent_color, true) and passed
	# Pin the seeded default look (the exact values ensure_defaults() bakes for a
	# fresh style) so a regression in the defaults is caught, not just non-null-ness.
	passed = _check(
		"default trigger badge color seeded",
		style.event_style.trigger_badge_background_color.is_equal_approx(Color(0.41, 0.51, 0.76, 0.95)),
		true
	) and passed
	passed = _check(
		"default condition lane color seeded",
		style.event_style.condition_lane_color.is_equal_approx(Color(0.11, 0.14, 0.20, 0.58)),
		true
	) and passed
	passed = _check(
		"default condition chip colors seeded",
		style.condition_style.text_color.is_equal_approx(Color(0.78, 0.88, 1.00, 1.0))
			and style.condition_style.chip_background_color.is_equal_approx(Color(0.30, 0.56, 0.82, 0.14)),
		true
	) and passed
	passed = _check(
		"default action chip colors seeded",
		style.action_style.text_color.is_equal_approx(Color(0.68, 0.92, 0.78, 1.0))
			and style.action_style.chip_background_color.is_equal_approx(Color(0.25, 0.66, 0.56, 0.12)),
		true
	) and passed
	passed = _check(
		"element badge derives from chip fill",
		style.condition_style.badge_background_color.is_equal_approx(style.condition_style.chip_background_color.darkened(0.24))
			and style.action_style.badge_background_color.is_equal_approx(style.action_style.chip_background_color.darkened(0.24)),
		true
	) and passed

	style.event_style.minimum_row_height = 40
	style.event_style.condition_lane_padding = 18
	style.event_style.action_lane_padding = 14
	style.event_style.lane_divider_width = 4
	style.event_style.minimum_conditions_lane_width = 220
	style.event_style.sheet_background_color = Color(0.09, 0.10, 0.12, 1.0)
	style.event_style.group_badge_background_color = Color(0.40, 0.25, 0.85, 1.0)
	style.condition_style.font_size_delta = 3
	style.condition_style.horizontal_padding = 14
	style.condition_style.vertical_padding = 4
	style.condition_style.gap_after = 14
	style.action_style.font_size_delta = 2
	style.action_style.horizontal_padding = 12
	style.action_style.vertical_padding = 4
	style.action_style.gap_after = 12

	var style_path: String = "user://event_sheet_editor_style_roundtrip.tres"
	var save_err: Error = ResourceSaver.save(style, style_path)
	passed = _check("style round-trip save succeeds", save_err, OK) and passed
	var loaded_style: Resource = ResourceLoader.load(style_path)
	passed = _check("style round-trip loads as EventSheetEditorStyle", loaded_style is EventSheetEditorStyle, true) and passed
	if loaded_style is EventSheetEditorStyle:
		var cast_style: EventSheetEditorStyle = loaded_style as EventSheetEditorStyle
		passed = _check("style round-trip keeps event row height", cast_style.event_style.minimum_row_height, 40) and passed
		passed = _check("style round-trip keeps sheet background token", cast_style.event_style.sheet_background_color, Color(0.09, 0.10, 0.12, 1.0)) and passed
		passed = _check("style round-trip keeps group badge token", cast_style.event_style.group_badge_background_color, Color(0.40, 0.25, 0.85, 1.0)) and passed
		passed = _check("style round-trip keeps condition padding", cast_style.condition_style.horizontal_padding, 14) and passed
		passed = _check("style round-trip keeps action gap", cast_style.action_style.gap_after, 12) and passed

	var sheet := EventSheetResource.new()
	sheet.editor_style = style
	sheet.variables["health"] = {"type": "int", "default": 100, "const": true}

	var intro_comment := CommentRow.new()
	intro_comment.text = "Styled rows should stay readable and non-overlapping."

	var styled_group := EventGroup.new()
	styled_group.name = "Styled Group"
	styled_group.group_name = styled_group.name
	var group_child := EventRow.new()
	group_child.event_uid = "group_child"
	group_child.conditions = [_make_condition("Core", "Always", {})]
	group_child.actions = [_make_action("Core", "QueueFree", {})]
	styled_group.events = [group_child]

	var styled_event := EventRow.new()
	styled_event.event_uid = "styled_event"
	styled_event.trigger = _make_condition("Core", "OnReady", {})
	styled_event.conditions = [
		_make_condition(TEST_LONG_CONDITION_PROVIDER, "Condition text that is intentionally long so custom padding and font size must still stay inside the condition lane", {})
	]
	styled_event.actions = [
		_make_action(TEST_LONG_ACTION_PROVIDER, "Action text that is intentionally long so the styled chip must still stay before the add action affordance", {})
	]
	styled_event.comment = "Styled action comment should remain inside the action lane."
	var local_variable := LocalVariable.new()
	local_variable.name = "ammo"
	local_variable.type_name = "int"
	local_variable.default_value = 5
	local_variable.is_constant = true
	styled_event.local_variables.append(local_variable)

	sheet.events = [intro_comment, styled_group, styled_event]

	var dock := EventSheetDock.new()
	dock.setup(sheet)
	var viewport: EventSheetViewport = dock.get_viewport_control()
	var rows: Array[Dictionary] = viewport.get_flat_rows()
	passed = _check("viewport exposes configured editor style", viewport.get_editor_style() == style, true) and passed

	var global_row_index: int = _find_row_index_by_uid(rows, "variable_global_health")
	var comment_row_index: int = _find_row_index_by_text(rows, intro_comment.text)
	var group_row_index: int = _find_row_index_by_text(rows, "Styled Group")
	var event_row_index: int = _find_row_index_by_uid(rows, styled_event.event_uid)
	passed = _check("styled sheet includes global variable row", global_row_index >= 0, true) and passed
	passed = _check("styled sheet includes comment row", comment_row_index >= 0, true) and passed
	passed = _check("styled sheet includes group row", group_row_index >= 0, true) and passed
	passed = _check("styled sheet includes event row", event_row_index >= 0, true) and passed

	var global_layout: Dictionary = viewport.get_row_layout_for_test(global_row_index, 780.0)
	var comment_layout: Dictionary = viewport.get_row_layout_for_test(comment_row_index, 780.0)
	var group_layout: Dictionary = viewport.get_row_layout_for_test(group_row_index, 780.0)
	var event_layout: Dictionary = viewport.get_row_layout_for_test(event_row_index, 780.0)
	var global_row: EventRowData = rows[global_row_index].get("row")
	var comment_row: EventRowData = rows[comment_row_index].get("row")
	var group_row: EventRowData = rows[group_row_index].get("row")
	var event_row: EventRowData = rows[event_row_index].get("row")

	passed = _check("styled event row height expands for custom chip sizing", float(event_layout.get("row_height", 0.0)) > float(EventSheetViewport.ROW_HEIGHT), true) and passed
	passed = _check("adjacent styled rows do not overlap vertically", _rows_are_stacked_without_overlap(viewport, rows, 780.0), true) and passed

	var group_title_index: int = _find_span_index_by_text(group_row, "Styled Group")
	passed = _check(
		"group row renders its styled title (the redundant 'Group' badge is gone)",
		group_title_index >= 0,
		true
	) and passed

	var scope_index: int = _find_span_index_by_text(global_row, "global")
	var name_index: int = _find_span_index_by_text(global_row, "health")
	var const_index: int = _find_span_index_by_text(global_row, "const")
	var value_index: int = _find_span_index_by_text(global_row, "100")
	var global_row_rect: Rect2 = global_layout.get("row_rect", Rect2())
	passed = _check(
		"variable name, const, and value spans remain ordered (redundant 'global' pill removed)",
		scope_index == -1
			and name_index >= 0
			and const_index >= 0
			and value_index >= 0
			and global_row.spans[name_index].rect.end.x < global_row.spans[const_index].rect.position.x
			and global_row.spans[value_index].rect.end.x <= global_row_rect.end.x - EventSheetPalette.ROW_HORIZONTAL_PADDING,
		true
	) and passed

	var comment_span_index: int = _find_span_index_by_text(comment_row, intro_comment.text)
	var comment_row_rect: Rect2 = comment_layout.get("row_rect", Rect2())
	passed = _check(
		"comment row stays inside the visible row width",
		comment_span_index >= 0
			and comment_row.spans[comment_span_index].rect.end.x <= comment_row_rect.end.x - EventSheetPalette.ROW_HORIZONTAL_PADDING,
		true
	) and passed

	var condition_index: int = _find_span_index_by_kind(event_row, "condition")
	var action_index: int = _find_span_index_by_kind(event_row, "action")
	var add_action_index: int = _find_span_index_by_kind(event_row, "add_action")
	var action_lane_rect: Rect2 = event_layout.get("action_lane_rect", Rect2())
	var lane_divider_x: float = float(event_layout.get("lane_divider_x", -1.0))
	passed = _check(
		"styled condition and action spans stay in their lanes",
		condition_index >= 0
			and action_index >= 0
			and event_row.spans[condition_index].rect.end.x <= lane_divider_x
			and event_row.spans[action_index].rect.position.x >= lane_divider_x,
		true
	) and passed
	passed = _check(
		"add action affordance sits below the actions inside the action lane",
		action_index >= 0
			and add_action_index >= 0
			and event_row.spans[add_action_index].rect.position.y > event_row.spans[action_index].rect.position.y
			and event_row.spans[add_action_index].rect.end.x <= action_lane_rect.end.x,
		true
	) and passed
	var custom_theme_path: String = "user://event_sheet_custom_theme.tres"
	var custom_theme := EventSheetEditorStyle.new()
	custom_theme.action_style.text_color = Color(1.0, 0.42, 0.42, 1.0)
	var custom_theme_saved: Error = ResourceSaver.save(custom_theme, custom_theme_path)
	passed = _check("custom theme save succeeds", custom_theme_saved, OK) and passed
	passed = _check("dock loads custom theme style", dock.load_theme_style_from_path(custom_theme_path), true) and passed
	passed = _check("dock applies loaded custom theme to current sheet", dock.get_current_sheet().editor_style != null, true) and passed
	passed = _check(
		"loaded custom theme changes action text color",
		dock.get_current_sheet().editor_style.get_action_style().text_color,
		Color(1.0, 0.42, 0.42, 1.0)
	) and passed
	custom_theme.action_style.text_color = Color(0.35, 1.0, 0.50, 1.0)
	var custom_theme_resaved: Error = ResourceSaver.save(custom_theme, custom_theme_path)
	passed = _check("custom theme re-save succeeds", custom_theme_resaved, OK) and passed
	passed = _check("dock reloads active theme file", dock.reload_active_theme(), true) and passed
	passed = _check(
		"reloaded theme picks updated action text color",
		dock.get_current_sheet().editor_style.get_action_style().text_color,
		Color(0.35, 1.0, 0.50, 1.0)
	) and passed
	passed = _check("dock can switch back to default theme", dock.use_default_theme(), true) and passed
	passed = _check("default theme clears per-sheet style override", dock.get_current_sheet().editor_style == null, true) and passed
	for theme_path in EXAMPLE_THEME_PATHS:
		passed = _check("example theme file exists: %s" % theme_path.get_file(), FileAccess.file_exists(theme_path), true) and passed
		var example_theme: Resource = ResourceLoader.load(theme_path)
		passed = _check("example theme loads as EventSheetEditorStyle: %s" % theme_path.get_file(), example_theme is EventSheetEditorStyle, true) and passed
		if example_theme is EventSheetEditorStyle:
			var themed_event_style: EventSheetEventStyle = (example_theme as EventSheetEditorStyle).get_event_style()
			passed = _check("example theme exposes structural tokens: %s" % theme_path.get_file(), themed_event_style.sheet_background_color.a > 0.0 and themed_event_style.selection_fill_color.a > 0.0, true) and passed
	passed = _check("designer theme manifest exists", FileAccess.file_exists(DESIGNER_THEME_MANIFEST_PATH), true) and passed
	if FileAccess.file_exists(DESIGNER_THEME_MANIFEST_PATH):
		var manifest_text: String = FileAccess.get_file_as_string(DESIGNER_THEME_MANIFEST_PATH)
		passed = _check("designer theme manifest references style resource", manifest_text.contains("designer_template_theme.tres"), true) and passed
		passed = _check("designer theme manifest lists tokens section", manifest_text.contains("[tokens]"), true) and passed

	# Godot 4.7 "Modern" editor-theme adaptation: a default sheet must inherit the editor's
	# neutral grayscale chrome (not the blue-tinted palette fallback) while keeping the
	# functional ACE accents. EventSheetGodotTheme.apply() is the pure mapping used in-editor.
	var modern_base := Color("#252525")
	var modern_accent := Color("#569eff")
	var modern_font := Color("#ced0d2")
	var adapted := EventSheetEditorStyle.new()
	adapted.ensure_defaults()
	EventSheetGodotTheme.apply(
		adapted, modern_base, modern_base.darkened(0.15), modern_base.darkened(0.25), modern_accent, modern_font
	)
	var adapted_event_style: EventSheetEventStyle = adapted.get_event_style()
	passed = _check(
		"modern adaptation keeps sheet chrome neutral (low saturation)",
		adapted_event_style.sheet_background_color.s < 0.12 and adapted_event_style.row_background_color.s < 0.12,
		true
	) and passed
	passed = _check(
		"modern adaptation derives selection fill from editor accent",
		is_equal_approx(adapted_event_style.selection_fill_color.r, modern_accent.r)
			and is_equal_approx(adapted_event_style.selection_fill_color.g, modern_accent.g)
			and is_equal_approx(adapted_event_style.selection_fill_color.b, modern_accent.b)
			and adapted_event_style.selection_fill_color.a < 1.0,
		true
	) and passed
	passed = _check(
		"modern adaptation uses editor accent for the trigger badge",
		adapted_event_style.trigger_badge_background_color.is_equal_approx(modern_accent),
		true
	) and passed
	passed = _check(
		"modern adaptation keeps condition/action lane tints subtle",
		adapted_event_style.condition_lane_color.a < 0.06 and adapted_event_style.action_lane_color.a < 0.06,
		true
	) and passed
	# A light editor theme must flip the chrome light too (proves it tracks the theme, not a constant).
	var light_adapted := EventSheetEditorStyle.new()
	light_adapted.ensure_defaults()
	var light_base := Color("#e8e8e8")
	EventSheetGodotTheme.apply(
		light_adapted, light_base, light_base.darkened(0.06), light_base.darkened(0.12), Color("#3a7bd5"), Color("#202020")
	)
	passed = _check(
		"light editor theme produces light sheet chrome",
		light_adapted.get_event_style().sheet_background_color.v > 0.5,
		true
	) and passed

	dock.free()
	return passed


static func _make_condition(provider_id: String, ace_id: String, params: Dictionary) -> ACECondition:
	var condition := ACECondition.new()
	condition.provider_id = provider_id
	condition.ace_id = ace_id
	condition.params = params.duplicate(true)
	return condition


static func _make_action(provider_id: String, ace_id: String, params: Dictionary) -> ACEAction:
	var action := ACEAction.new()
	action.provider_id = provider_id
	action.ace_id = ace_id
	action.params = params.duplicate(true)
	return action


static func _find_row_index_by_uid(rows: Array[Dictionary], expected_uid: String) -> int:
	for index in range(rows.size()):
		var row_data: EventRowData = rows[index].get("row")
		if row_data != null and row_data.row_uid == expected_uid:
			return index
	return -1


static func _find_row_index_by_text(rows: Array[Dictionary], expected_text: String) -> int:
	for index in range(rows.size()):
		var row_data: EventRowData = rows[index].get("row")
		if row_data != null and _find_span_index_by_text(row_data, expected_text) >= 0:
			return index
	return -1


static func _rows_are_stacked_without_overlap(viewport: EventSheetViewport, rows: Array[Dictionary], width: float) -> bool:
	for index in range(rows.size() - 1):
		var current_layout: Dictionary = viewport.get_row_layout_for_test(index, width)
		var next_layout: Dictionary = viewport.get_row_layout_for_test(index + 1, width)
		var current_rect: Rect2 = current_layout.get("row_rect", Rect2())
		var next_rect: Rect2 = next_layout.get("row_rect", Rect2())
		if next_rect.position.y + 0.01 < current_rect.end.y:
			return false
	return true


static func _find_span_index_by_kind(row_data: EventRowData, expected_kind: String) -> int:
	if row_data == null:
		return -1
	for index in range(row_data.spans.size()):
		var span: SemanticSpan = row_data.spans[index]
		if span == null or not (span.metadata is Dictionary):
			continue
		if str((span.metadata as Dictionary).get("kind", "")) == expected_kind:
			return index
	return -1


static func _find_span_index_by_text(row_data: EventRowData, expected_text: String) -> int:
	if row_data == null:
		return -1
	for index in range(row_data.spans.size()):
		var span: SemanticSpan = row_data.spans[index]
		if span != null and span.text == expected_text:
			return index
	return -1


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] event_sheet_style_test: %s" % label)
		return true
	print("[FAIL] event_sheet_style_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
