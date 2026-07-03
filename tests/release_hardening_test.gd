# Godot EventSheets — Release hardening: export-integrity hook + visual theme editor.
#
# Export hook: the EditorExportPlugin's recompile-all pass is a static, headless-safe
# helper (the same code runs at _export_begin), so exports can never ship stale generated
# scripts. Theme editor: the reflective token model (enumerate/apply/duplicate/save) is
# tested headless; the dialog itself is editor chrome over these primitives.
@tool
class_name ReleaseHardeningTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# Export integrity: the demo sheet is discovered and recompiles cleanly.
	var report: Dictionary = EventSheetExportIntegrityPlugin.recompile_all_sheets("res://demo")
	all_passed = _check("export pass finds and compiles the demo sheet", int(report.get("compiled", 0)) >= 1, true) and all_passed
	all_passed = _check("export pass has no failures", int(report.get("failed", 0)), 0) and all_passed

	# Theme editor primitives: token enumeration is reflective and typed.
	var event_style: EventSheetEventStyle = EventSheetEventStyle.new()
	var tokens: Array[Dictionary] = EventSheetThemeEditor.editable_tokens(event_style)
	var token_names: Array[String] = []
	for token in tokens:
		token_names.append(str(token.get("name")))
	all_passed = _check("tokens enumerate reflectively (has behavior accent)", token_names.has("behavior_accent_color"), true) and all_passed
	all_passed = _check("tokens enumerate reflectively (has comment text color)", token_names.has("comment_text_color"), true) and all_passed

	# apply_token writes values and reports changes truthfully.
	all_passed = _check("apply_token changes a color",
		EventSheetThemeEditor.apply_token(event_style, "behavior_accent_color", Color.RED), true) and all_passed
	all_passed = _check("the color actually changed", event_style.behavior_accent_color, Color.RED) and all_passed
	all_passed = _check("apply_token is a no-op for equal values",
		EventSheetThemeEditor.apply_token(event_style, "behavior_accent_color", Color.RED), false) and all_passed

	# duplicate_style never aliases the original (live edits stay sandboxed).
	var base_style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	base_style.event_style = event_style
	var working: EventSheetEditorStyle = EventSheetThemeEditor.duplicate_style(base_style)
	EventSheetThemeEditor.apply_token(working.event_style, "behavior_accent_color", Color.BLUE)
	all_passed = _check("working copy edits never touch the original", event_style.behavior_accent_color, Color.RED) and all_passed
	all_passed = _check("missing sub-styles are filled in", working.condition_style != null and working.action_style != null, true) and all_passed

	# The preview sample sheet exercises the themable surfaces and loads in a viewport.
	var sample: EventSheetResource = EventSheetThemeEditor.build_sample_sheet(working)
	all_passed = _check("sample sheet carries the working style", sample.editor_style == working, true) and all_passed
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_sheet(sample)
	all_passed = _check("preview viewport builds rows from the sample", viewport._flat_rows.size() > 0, true) and all_passed
	viewport.free()

	# Preset saving produces a loadable .tres.
	var theme_editor: EventSheetThemeEditor = EventSheetThemeEditor.new()
	theme_editor._working_style = working
	all_passed = _check("preset saves", theme_editor.save_preset("user://eventsheets_theme_preset.tres"), OK) and all_passed
	var loaded: EventSheetEditorStyle = load("user://eventsheets_theme_preset.tres") as EventSheetEditorStyle
	all_passed = _check("preset round-trips with the edited token",
		loaded.event_style.behavior_accent_color if loaded != null and loaded.event_style != null else Color.BLACK, Color.BLUE) and all_passed

	# Quick Style — the no-token-fiddling path: EventSheetGodotTheme.apply regenerates the
	# entire chrome from base/accent/text, so one colour change re-skins the whole sheet.
	var quick: EventSheetEditorStyle = EventSheetThemeEditor.duplicate_style(null)
	var quick_base: Color = Color("#202830")
	EventSheetGodotTheme.apply(quick, quick_base, quick_base.darkened(0.15), quick_base.darkened(0.25), Color("#ff8800"), Color.WHITE)
	all_passed = _check("Quick Style spreads the accent across the palette",
		quick.event_style.group_accent_color, Color("#ff8800")) and all_passed
	all_passed = _check("Quick Style derives the sheet background from the base tone",
		quick.event_style.sheet_background_color, quick_base.darkened(0.25)) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] release_hardening_test: %s" % label)
		return true
	print("[FAIL] release_hardening_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
