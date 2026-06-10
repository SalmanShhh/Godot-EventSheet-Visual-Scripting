# EventForge — Theme preset discovery + theme token coverage
#
# Verifies the toolbar theme switcher's preset discovery (EventSheetThemePresets) and that
# the column-header theme tokens exist on EventSheetEventStyle. Headless-safe (file I/O only).
@tool
extends RefCounted
class_name ThemePresetsTest

static func run() -> bool:
	var all_passed: bool = true

	var presets: Array[Dictionary] = EventSheetThemePresets.list_presets()
	all_passed = _check("discovers bundled themes (>= 4)", presets.size() >= 4, true) and all_passed
	for preset in presets:
		var name: String = str(preset.get("name", ""))
		var path: String = str(preset.get("path", ""))
		all_passed = _check("preset '%s' has a name" % path, not name.is_empty(), true) and all_passed
		var resource: Resource = ResourceLoader.load(path)
		all_passed = _check("preset '%s' loads as an editor style" % name, resource is EventSheetEditorStyle, true) and all_passed

	all_passed = _check("humanize strips _theme and title-cases",
		EventSheetThemePresets._humanize("construct3_stacked_theme.tres"), "Construct3 Stacked") and all_passed
	all_passed = _check("humanize handles multi-word names",
		EventSheetThemePresets._humanize("high_contrast_theme.tres"), "High Contrast") and all_passed

	# Column-header theme tokens exist with the expected defaults.
	var style: EventSheetEventStyle = EventSheetEventStyle.new()
	all_passed = _check("header background token default", style.column_header_background_color, Color("#22242b")) and all_passed
	all_passed = _check("header conditions colour default", style.column_header_conditions_color, Color("#8fb0e0")) and all_passed
	all_passed = _check("header actions colour default", style.column_header_actions_color, Color("#6fd0bf")) and all_passed

	# A bundled theme can still resolve event/condition/action styles (token coverage intact).
	if presets.size() > 0:
		var first: EventSheetEditorStyle = ResourceLoader.load(str(presets[0].get("path", ""))) as EventSheetEditorStyle
		all_passed = _check("bundled theme resolves an event style", first != null and first.get_event_style() is EventSheetEventStyle, true) and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] theme_presets_test: %s" % label)
		return true
	print("[FAIL] theme_presets_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
