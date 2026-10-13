# Godot EventSheets - Release hardening: export-integrity hook + visual theme editor.
#
# Export hook: the EditorExportPlugin's recompile-all pass is a static, headless-safe
# helper (the same code runs at _export_begin), so exports can never ship stale generated
# scripts. Theme editor: the reflective token model (enumerate/apply/duplicate/save) is
# tested headless; the dialog itself is editor chrome over these primitives.
@tool
class_name ReleaseHardeningTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var all_passed: bool = true

	# Export integrity: a sheet on disk is discovered and recompiles cleanly. Scans tests/fixtures
	# because that is where the compiler's golden sheet lives - the showcases under demo/ are .gd-first
	# (their sheets are not shipped as .tres), so demo/ holds data assets and themes but no event sheet.
	var report: Dictionary = EventSheetExportIntegrityPlugin.recompile_all_sheets("res://tests/fixtures")
	all_passed = _check("export pass finds and compiles a sheet on disk", int(report.get("compiled", 0)) >= 1, true) and all_passed
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
	# PUBLISHED VERBS must be previewable, or the verb tokens (role accents, wash strength, chips)
	# cannot be judged while restyling. One per role, since each role's accent is its own token.
	var sample_roles: Array[String] = []
	for entry: Variant in sample.functions:
		if entry is EventFunction:
			sample_roles.append(ViewportRowBuilder.define_role_for(entry as EventFunction))
	all_passed = _check("the sample previews an Action verb", sample_roles.has("action"), true) and all_passed
	all_passed = _check("the sample previews a Condition verb", sample_roles.has("condition"), true) and all_passed
	all_passed = _check("the sample previews an Expression verb", sample_roles.has("expression"), true) and all_passed
	var sample_uids: Array[String] = []
	for entry: Dictionary in viewport.get_flat_rows():
		var sample_row: EventRowData = entry.get("row")
		if sample_row != null:
			sample_uids.append(sample_row.row_uid)
	all_passed = _check("the verb row itself renders in the preview", sample_uids.has("define_fn_spawn_pickup"), true) and all_passed

	# The Theme editor's form is reflective, so a token only reaches the user if it is an @export.
	all_passed = _check("the role accents are offered as tokens",
		token_names.has("ace_action_accent_color") and token_names.has("ace_condition_accent_color")
		and token_names.has("ace_expression_accent_color"), true) and all_passed
	all_passed = _check("so are the wash strength and the verb chips",
		token_names.has("verb_row_tint_strength") and token_names.has("verb_chip_background_color")
		and token_names.has("verb_chip_foreground_color"), true) and all_passed

	# Truthfulness: the Define row must read the STYLE, not EventSheetPalette. Restyle a role and a
	# strength, rebuild, and check the row that comes out - that is the whole point of the tokens.
	EventSheetThemeEditor.apply_token(working.event_style, "ace_condition_accent_color", Color.RED)
	EventSheetThemeEditor.apply_token(working.event_style, "verb_row_tint_strength", 0.3)
	var restyled: EventSheetResource = EventSheetThemeEditor.build_sample_sheet(working)
	var restyled_view: EventSheetViewport = EventSheetViewport.new()
	restyled_view.set_sheet(restyled)
	var condition_verb_row: EventRowData = null
	var action_verb_row: EventRowData = null
	for entry: Dictionary in restyled_view.get_flat_rows():
		var restyled_row: EventRowData = entry.get("row")
		if restyled_row == null:
			continue
		if restyled_row.row_uid == "define_fn_can_afford":
			condition_verb_row = restyled_row
		elif restyled_row.row_uid == "define_fn_spawn_pickup":
			action_verb_row = restyled_row
	all_passed = _check("a restyled role accent reaches the verb's badge",
		condition_verb_row != null and condition_verb_row.spans[0].metadata.get("badge_fg") == Color.RED, true) and all_passed
	all_passed = _check("and tints the row's wash with it",
		condition_verb_row != null and is_equal_approx(condition_verb_row.custom_color.r, 1.0), true) and all_passed
	all_passed = _check("the wash STRENGTH is the token, not a baked literal",
		action_verb_row != null and is_equal_approx(action_verb_row.custom_color.a, 0.3), true) and all_passed
	restyled_view.free()
	viewport.free()

	# Preset saving produces a loadable .tres.
	var theme_editor: EventSheetThemeEditor = EventSheetThemeEditor.new()
	theme_editor._working_style = working
	all_passed = _check("preset saves", theme_editor.save_preset("user://eventsheets_theme_preset.tres"), OK) and all_passed
	var loaded: EventSheetEditorStyle = load("user://eventsheets_theme_preset.tres") as EventSheetEditorStyle
	all_passed = _check("preset round-trips with the edited token",
		loaded.event_style.behavior_accent_color if loaded != null and loaded.event_style != null else Color.BLACK, Color.BLUE) and all_passed

	# A preset that cannot be written says so on the status bar instead of saying nothing.
	var status_dock: Control = _status_recorder()
	theme_editor._dock = status_dock
	var failed_save: Error = theme_editor.save_preset("res://no_such_folder_for_presets/preset.tres")
	all_passed = _check("a preset written into a missing folder fails", failed_save != OK, true) and all_passed
	all_passed = _check("and the failure reaches the status bar as an error",
		[str(status_dock.get("last_text")).begins_with("Theme preset could not be saved: preset.tres"), status_dock.get("last_is_error")], [true, true]) and all_passed
	theme_editor._dock = null
	status_dock.free()

	# Each number token's spin box takes the token's OWN range and step, so a 0.20-0.80 ratio
	# stepping 0.01 can be set to 0.45 instead of snapping to the 0.5 grid of a -4096..4096 box.
	var token_form: VBoxContainer = VBoxContainer.new()
	theme_editor._build_section(token_form, "Sheet", EventSheetEventStyle.new())
	var spins: Dictionary = {}
	for spin_node: Node in token_form.find_children("*", "SpinBox", true, false):
		var spin_row: Node = spin_node.get_parent()
		spins[(spin_row.get_child(0) as Label).text] = spin_node
	var lane_spin: SpinBox = spins.get("Condition Lane Ratio") as SpinBox
	all_passed = _check("the lane ratio spin box carries the token's range and step",
		[lane_spin.min_value, lane_spin.max_value, lane_spin.step] if lane_spin != null else [], [0.2, 0.8, 0.01]) and all_passed
	if lane_spin != null:
		lane_spin.value = 0.45
	all_passed = _check("so 0.45 can be set", lane_spin.value if lane_spin != null else 0.0, 0.45) and all_passed
	var height_spin: SpinBox = spins.get("Minimum Conditions Lane Width") as SpinBox
	all_passed = _check("an int token keeps its own bounds too",
		[height_spin.min_value, height_spin.max_value, height_spin.step] if height_spin != null else [], [120.0, 480.0, 1.0]) and all_passed
	token_form.free()

	# Quick Style - the no-token-fiddling path: EventSheetGodotTheme.apply regenerates the
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
	return SUPPORT.check("release_hardening_test", label, actual, expected)


## A stand-in dock that keeps the last status line it was given.
static func _status_recorder() -> Control:
	var recorder_script: GDScript = GDScript.new()
	recorder_script.source_code = "extends Control\nvar last_text: String = \"\"\nvar last_is_error: bool = false\nfunc _set_status(text: String, is_error: bool = false) -> void:\n\tlast_text = text\n\tlast_is_error = is_error\n"
	recorder_script.reload()
	var recorder: Control = Control.new()
	recorder.set_script(recorder_script)
	return recorder
