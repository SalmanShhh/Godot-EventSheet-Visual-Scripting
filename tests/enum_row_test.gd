# Godot EventSheets — EnumRow (first-class enums, rich-variables phase 1)
# Enums are sheet rows compiling to canonical single-line class enums (before variables,
# so enum-typed vars work), render as variable-like rows, edit via dialog, verify-lift
# from generated code, travel in snippets, and feed lint + dot-context completion.
@tool
extends RefCounted
class_name EnumRowTest

class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass

static func run() -> bool:
	var all_passed: bool = true

	# Compile: canonical line, ordered before variables, explicit values, disabled skipped.
	var sheet: EventSheetResource = EventSheetResource.new()
	var state: EnumRow = EnumRow.new()
	state.enum_name = "State"
	state.members = PackedStringArray(["IDLE", "RUN", "HURT = 4"])
	sheet.events.append(state)
	var off: EnumRow = EnumRow.new()
	off.enum_name = "Unused"
	off.enabled = false
	sheet.events.append(off)
	var current: LocalVariable = LocalVariable.new()
	current.name = "state"
	current.type_name = "State"
	current.default_value = 0
	sheet.events.append(current)
	var result: Dictionary = SheetCompiler.compile(sheet, "user://eventsheets_enum.gd")
	var output: String = str(result.get("output", ""))
	all_passed = _check("canonical enum line emits", output.contains("enum State { IDLE, RUN, HURT = 4 }"), true) and all_passed
	all_passed = _check("disabled enums skip", output.contains("Unused"), false) and all_passed
	all_passed = _check("enums emit before variables",
		output.find("enum State") < output.find("var state: State"), true) and all_passed
	all_passed = _check("enum-typed variable compiles", output.contains("var state: State = 0"), true) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("enum output parses", generated.reload(true) == OK, true) and all_passed
	var enum_mapped: bool = false
	for entry in result.get("source_map", []):
		if str((entry as Dictionary).get("kind", "")) == "enum":
			enum_mapped = true
	all_passed = _check("enum rows are source-mapped", enum_mapped, true) and all_passed

	# Lint + completion: expressions referencing the enum validate; State. completes members.
	all_passed = _check("expressions referencing the enum lint",
		bool(EventSheetGDScriptLint.lint_expression("state == State.RUN", sheet).get("ok", false)), true) and all_passed
	var members: Array[String] = []
	for candidate in EventSheetGDScriptLint.completion_for_context("State.", sheet):
		members.append(str(candidate.get("label", "")))
	all_passed = _check("State. completes members (values stripped)",
		members.has("IDLE") and members.has("HURT") and not members.has("HURT = 4"), true) and all_passed
	var flat: Array[String] = []
	for candidate in EventSheetGDScriptLint.completion_for_context("Sta", sheet):
		flat.append(str(candidate.get("label", "")))
	all_passed = _check("enum name is a flat candidate", flat.has("State"), true) and all_passed

	# Verify-lift: generated enums re-open as EnumRows; non-canonical forms stay blocks.
	var external_source: String = "extends Node\n\nenum Mode { A, B = 7 }\n\nenum Spaced {  X }\n"
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(external_source)
	var lifted_enum: EnumRow = null
	var raw_blocks: int = 0
	for row in imported.events:
		if row is EnumRow:
			lifted_enum = row
		elif row is RawCodeRow and (row as RawCodeRow).code.contains("Spaced"):
			raw_blocks += 1
	all_passed = _check("canonical enum lifts", lifted_enum != null and lifted_enum.enum_name == "Mode" and lifted_enum.members[1] == "B = 7", true) and all_passed
	all_passed = _check("non-canonical enum stays a block", raw_blocks, 1) and all_passed
	imported.external_source_path = "user://eventsheets_enum_rt.gd"
	var roundtrip: String = str(SheetCompiler.compile(imported, "user://eventsheets_enum_rt.gd").get("output", ""))
	all_passed = _check("external enum round-trip is byte-identical", roundtrip == external_source, true) and all_passed

	# Snippets: enums travel.
	var snippet: String = EventSheetSnippet.serialize_rows([state], sheet)
	var parsed: Dictionary = EventSheetSnippet.deserialize(snippet)
	var pasted_enum: EnumRow = null
	for row in parsed.get("rows", []):
		if row is EnumRow:
			pasted_enum = row
	all_passed = _check("enums travel in snippets",
		pasted_enum != null and pasted_enum.enum_name == "State" and pasted_enum.members.size() == 3, true) and all_passed

	# Editor: renders as a row; dialog applies edits undoably.
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var enum_row_data: EventRowData = null
	for entry in viewport.get_flat_rows():
		var row: EventRowData = entry.get("row")
		if row != null and row.source_resource == state:
			enum_row_data = row
	all_passed = _check("enum renders as a row", enum_row_data != null, true) and all_passed
	if enum_row_data != null:
		all_passed = _check("enum row shows the declaration",
			enum_row_data.spans[1].text, "State { IDLE, RUN, HURT = 4 }") and all_passed
	editor._struct_rows._ensure_enum_dialog()
	editor._struct_rows._enum_target = state
	editor._struct_rows._enum_name_edit.text = "PlayerState"
	editor._struct_rows._enum_members_edit.text = "IDLE\nDASH"
	editor._struct_rows._on_enum_dialog_confirmed()
	all_passed = _check("dialog applies name + members",
		state.enum_name == "PlayerState" and state.members == PackedStringArray(["IDLE", "DASH"]), true) and all_passed
	editor.free()

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] enum_row_test: %s" % label)
		return true
	print("[FAIL] enum_row_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
