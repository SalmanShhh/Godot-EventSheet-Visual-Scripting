# Godot EventSheets — C3 "Combo" properties + color params
# String variables with options compile to @export_enum (Inspector dropdowns) and
# verify-lift back; @ace_param_options gives addon params dropdowns; "enum:Name" hints
# drive sheet-enum dropdowns; color params get a picker and a swatch in the sheet text.
@tool
extends RefCounted
class_name ComboColorTest

static func run() -> bool:
	var all_passed: bool = true

	# Combo variables: canonical @export_enum emission.
	var sheet: EventSheetResource = EventSheetResource.new()
	var difficulty: LocalVariable = LocalVariable.new()
	difficulty.name = "difficulty"
	difficulty.type_name = "String"
	difficulty.default_value = "normal"
	difficulty.exported = true
	difficulty.options = PackedStringArray(["easy", "normal", "hard"])
	sheet.events.append(difficulty)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_combo.gd").get("output", ""))
	all_passed = _check("combo variables emit @export_enum",
		output.contains("@export_enum(\"easy\", \"normal\", \"hard\") var difficulty: String = \"normal\""), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("combo output parses", generated.reload(true) == OK, true) and all_passed

	# Verify-lift: the @export_enum line round-trips into a variable row with options.
	var external_source: String = "extends Node\n\n@export_enum(\"easy\", \"normal\", \"hard\") var difficulty: String = \"normal\"\n"
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(external_source)
	var lifted: LocalVariable = null
	for row in imported.events:
		if row is LocalVariable:
			lifted = row
	all_passed = _check("combo declarations lift with options",
		lifted != null and lifted.options == PackedStringArray(["easy", "normal", "hard"]) and lifted.exported, true) and all_passed
	imported.external_source_path = "user://eventsheets_combo_rt.gd"
	var roundtrip: String = str(SheetCompiler.compile(imported, "user://eventsheets_combo_rt.gd").get("output", ""))
	all_passed = _check("combo round-trip is byte-identical", roundtrip == external_source, true) and all_passed

	# The shipped Sine pack showcases the combo (movement dropdown in the Inspector).
	all_passed = _check("sine pack movement is a combo",
		FileAccess.get_file_as_string("res://eventsheet_addons/sine/sine_behavior.gd").contains(") var movement: String ="), true) and all_passed

	# @ace_param_options annotation -> addon param dropdowns.
	var analyzer: EventSheetSemanticAnalyzer = EventSheetSemanticAnalyzer.new()
	var directives: Array[String] = [
		"@ace_action",
		"@ace_param_options(movement horizontal, vertical, angle)"
	]
	var overrides: Dictionary = analyzer._build_overrides(directives)
	var parsed_options: Dictionary = overrides.get("param_options", {})
	all_passed = _check("@ace_param_options parses",
		parsed_options.get("movement", []) == ["horizontal", "vertical", "angle"], true) and all_passed

	# Dialog: enum-driven dropdown + color picker + guardrails.
	var state: EnumRow = EnumRow.new()
	state.enum_name = "State"
	state.members = PackedStringArray(["IDLE", "RUN"])
	sheet.events.append(state)
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	var enum_field: Control = dialog._create_enum_reference_field("mode", "State.IDLE", "State")
	all_passed = _check("enum hints render dropdowns of members", enum_field is OptionButton, true) and all_passed
	all_passed = _check("enum dropdown stores qualified values",
		(enum_field as OptionButton).get_item_metadata(0), "State.IDLE") and all_passed
	enum_field.free()
	var color_field: Control = dialog._create_color_field("tint", "Color(1, 0, 0, 1)")
	all_passed = _check("color params render a picker", color_field is ColorPickerButton, true) and all_passed
	all_passed = _check("picker preloads the literal", (color_field as ColorPickerButton).color, Color(1, 0, 0, 1)) and all_passed
	all_passed = _check("picker values round-trip as canonical literals",
		dialog._extract_value(color_field), "Color(1.0, 0.0, 0.0, 1.0)") and all_passed
	color_field.free()
	all_passed = _check("combo defaults must be an option",
		VariableDialog.parse_options("easy, normal , hard").size(), 3) and all_passed

	# Swatch metadata: a Color param surfaces on the rendered span.
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var tint: ACEAction = ACEAction.new()
	tint.provider_id = "Core"
	tint.ace_id = "SetModulate"
	tint.codegen_template = "modulate = {color}"
	tint.params = {"color": "Color(0.2, 0.6, 1, 1)"}
	event.actions.append(tint)
	sheet.events.append(event)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var event_row_data: EventRowData = null
	for entry in viewport.get_flat_rows():
		var row: EventRowData = entry.get("row")
		if row != null and row.source_resource == event:
			event_row_data = row
	viewport._ensure_event_spans(event_row_data)
	var swatch_found: bool = false
	for span in event_row_data.spans:
		if span.metadata is Dictionary and (span.metadata as Dictionary).get("swatch_color") is Color:
			swatch_found = ((span.metadata as Dictionary).get("swatch_color") as Color).is_equal_approx(Color(0.2, 0.6, 1, 1))
	all_passed = _check("color params surface a swatch on the action text", swatch_found, true) and all_passed
	editor.free()

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] combo_color_test: %s" % label)
		return true
	print("[FAIL] combo_color_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
