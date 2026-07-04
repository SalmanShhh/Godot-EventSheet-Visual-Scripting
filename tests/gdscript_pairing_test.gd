# EventForge - GDScript pairing batch
#
# Guards the event-sheet→GDScript bridge features: inline GDScript blocks (render multi-line, compile
# verbatim at class level), codegen tooltip previews, the picker search synonyms, and the
# new semantic theme tokens.
@tool
class_name GDScriptPairingTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# Compile: top-level + group-nested blocks emit verbatim at class level; disabled skipped.
	var sheet: EventSheetResource = EventSheetResource.new()
	var helper_block: RawCodeRow = RawCodeRow.new()
	helper_block.code = "func heal(amount: int) -> void:\n\thealth += amount"
	sheet.events.append(helper_block)
	var group: EventGroup = EventGroup.new()
	group.group_name = "G"
	var grouped_block: RawCodeRow = RawCodeRow.new()
	grouped_block.code = "@onready var sprite: Sprite2D = $Sprite2D"
	group.events.append(grouped_block)
	sheet.events.append(group)
	var disabled_block: RawCodeRow = RawCodeRow.new()
	disabled_block.code = "var should_not_appear := true"
	disabled_block.enabled = false
	sheet.events.append(disabled_block)
	var output: String = str(SheetCompiler.compile(sheet, "user://eventforge_raw_blocks.gd").get("output", ""))
	all_passed = _check("top-level GDScript block compiles verbatim",
		output.contains("func heal(amount: int) -> void:") and output.contains("\thealth += amount"), true) and all_passed
	all_passed = _check("group-nested GDScript block compiles",
		output.contains("@onready var sprite: Sprite2D = $Sprite2D"), true) and all_passed
	all_passed = _check("disabled GDScript block is skipped",
		not output.contains("should_not_appear"), true) and all_passed
	# Raw blocks alone (no group, which has its own pre-existing TODO) emit no placeholder.
	var raw_only_sheet: EventSheetResource = EventSheetResource.new()
	var raw_only_block: RawCodeRow = RawCodeRow.new()
	raw_only_block.code = "signal healed(amount: int)"
	raw_only_sheet.events.append(raw_only_block)
	var raw_only_output: String = str(SheetCompiler.compile(raw_only_sheet, "user://eventforge_raw_only.gd").get("output", ""))
	all_passed = _check("no TODO placeholder for raw blocks",
		not raw_only_output.contains("# TODO: row type not yet implemented") and raw_only_output.contains("signal healed(amount: int)"), true) and all_passed

	# Render: a raw block shows as a multi-line row, lines stacked vertically.
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_sheet(sheet)
	var raw_index: int = -1
	var flat: Array[Dictionary] = viewport.get_flat_rows()
	for i in range(flat.size()):
		var row_data: EventRowData = flat[i].get("row")
		if row_data != null and row_data.source_resource == helper_block:
			raw_index = i
	all_passed = _check("raw block renders as a row", raw_index >= 0, true) and all_passed
	var raw_row_data: EventRowData = flat[raw_index].get("row")
	all_passed = _check("raw block line_count matches its code", raw_row_data.line_count, 2) and all_passed
	all_passed = _check("raw block row is taller than one line",
		viewport._resolve_row_height(raw_row_data) > float(EventSheetPalette.ROW_HEIGHT), true) and all_passed
	viewport._get_or_build_row_layout(raw_index, viewport.get_canvas_logical_width(), viewport._get_font(), viewport._get_font_size())
	var line0_y: float = -1.0
	var line1_y: float = -1.0
	for span in raw_row_data.spans:
		if span == null or not (span.metadata is Dictionary):
			continue
		if str((span.metadata as Dictionary).get("kind", "")) != "raw_code":
			continue
		var line_index: int = int((span.metadata as Dictionary).get("line_index", -1))
		if line_index == 0 and not bool((span.metadata as Dictionary).get("badge", false)):
			line0_y = span.rect.position.y
		elif line_index == 1:
			line1_y = span.rect.position.y
	all_passed = _check("raw block lines stack vertically", line1_y > line0_y and line0_y >= 0.0, true) and all_passed

	# Codegen preview: template substitution and Core descriptor lookup.
	all_passed = _check("codegen template fills params",
		EventSheetViewport.fill_codegen_template("health += {amount}", {"amount": 5}), "health += 5") and all_passed
	all_passed = _check("empty template yields empty preview",
		EventSheetViewport.fill_codegen_template("", {"x": 1}), "") and all_passed
	var preview: String = viewport._tooltip_helper.codegen_preview_for("Core", "Always", {})
	all_passed = _check("Core/Always previews its codegen ('true')", preview, "true") and all_passed
	viewport.free()

	# Picker synonyms: event-sheet phrases map to Godot search terms.
	all_passed = _check("'on start of layout' maps to ready",
		ACEPickerDialog._c3_synonym_queries("on start of layout").has("ready"), true) and all_passed
	all_passed = _check("'spawn' maps to instantiate",
		ACEPickerDialog._c3_synonym_queries("spawn").has("instantiate"), true) and all_passed
	all_passed = _check("short queries are not synonym-expanded",
		ACEPickerDialog._c3_synonym_queries("on").is_empty(), true) and all_passed

	# New semantic theme tokens exist with event-sheet-faithful defaults.
	var style: EventSheetEventStyle = EventSheetEventStyle.new()
	all_passed = _check("invert marker token defaults to red", style.invert_marker_color, Color("#FF0000")) and all_passed
	all_passed = _check("object label token exists", style.object_label_color, EventSheetPalette.COLOR_OBJECT) and all_passed
	all_passed = _check("value highlight token exists", style.value_highlight_color, EventSheetPalette.COLOR_VALUE) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] gdscript_pairing_test: %s" % label)
		return true
	print("[FAIL] gdscript_pairing_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
