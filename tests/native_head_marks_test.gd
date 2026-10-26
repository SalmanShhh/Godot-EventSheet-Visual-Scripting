@tool
extends RefCounted
# Godot EventSheets - the class head, the Include bar and the inner-class block
#
# The head of a sheet reads as ONE head bar (the class, the kind of file, what it extends; a shared
# sheet's mark and who includes it on its name card), each Include as a bar with the line it writes at its
# right and the included sheet's variables under it, and an inner data class as one framed block
# whose open form ends in "+ Add field" and in what a class is for. The pins hold:
#   1. how one line of source reads as a top-level variable, and what does not;
#   2. a shared sheet's wiring and the project's scripts that include it;
#   3. which variables of a sheet hold an inner class;
#   4. the head bar of a shared sheet: its words, and the share and "Included by" on its name card;
#   5. the Include bar's shape in a theme that states the Include edge, and in one that does not,
#      and View > Included Variables turning the rows under it off;
#   6. the inner-class block's frame, its "+ Add field" and its explainer - and that a read-only
#      preview gets neither.

const SUPPORT := preload("res://tests/support.gd")
const NativeHeadMarks := preload("res://addons/eventsheet/editor/interaction/native_head_marks.gd")
const TEST_NAME := "native_head_marks_test"
const SHARED_BASE := "res://tests/fixtures/shared_sheets/fixture_damage_rules.gd"
const SHARED_HELPER := "res://tests/fixtures/shared_sheets/fixture_pause_handling.gd"
const INCLUDER := "res://tests/fixtures/shared_sheets/fixture_includer.gd"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const CLASSIC_THEME := "res://addons/eventsheet/themes/classic_sheet_theme.tres"
const USERS_FILE := "user://native_head_marks_users.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _test_declarations() and ok
	ok = _test_includers() and ok
	ok = _test_class_users() and ok
	ok = _test_class_head_of_a_shared_sheet() and ok
	ok = _test_include_bar_shape() and ok
	ok = _test_included_variables_toggle() and ok
	ok = _test_class_block() and ok
	return ok


static func _test_declarations() -> bool:
	return SUPPORT.pins(TEST_NAME, [
		["an inferred literal", NativeHeadMarks.declaration_of("var health := 100"),
			{"name": "health", "type": "int", "value": "100"}],
		["an exported, typed variable", NativeHeadMarks.declaration_of("@export var speed: float = 2.0"),
			{"name": "speed", "type": "float", "value": "2.0"}],
		["a typed list", NativeHeadMarks.declaration_of("var guards: Array[Node2D] = []"),
			{"name": "guards", "type": "Array[Node2D]", "value": "[]"}],
		["an object a constructor makes", NativeHeadMarks.declaration_of("var settings := GateSettings.new()"),
			{"name": "settings", "type": "GateSettings", "value": "GateSettings.new()"}],
		["a trailing comment is not the value", NativeHeadMarks.declaration_of("var lives: int = 3 # starting lives"),
			{"name": "lives", "type": "int", "value": "3"}],
		["an indented line belongs to a function or a class", NativeHeadMarks.declaration_of("\tvar inner := 1"), {}],
		["a function is not a variable", NativeHeadMarks.declaration_of("func _ready() -> void:"), {}],
	])


static func _test_includers() -> bool:
	NativeHeadMarks.forget_includers()
	var variables: Array = []
	for variable: Dictionary in NativeHeadMarks.shared_variables(SHARED_BASE):
		variables.append("%s %s %s" % [variable["type"], variable["name"], variable["value"]])
	return SUPPORT.pins(TEST_NAME, [
		["the base wiring is read off the file", NativeHeadMarks.shared_wiring(SHARED_BASE), "base_class"],
		["the helper wiring is read off the file", NativeHeadMarks.shared_wiring(SHARED_HELPER), "helper"],
		["an ordinary script is not a shared sheet", NativeHeadMarks.shared_wiring(INCLUDER), ""],
		["the script that extends the base includes it",
			NativeHeadMarks.includers_of(SHARED_BASE), PackedStringArray(["Fixture Includer"])],
		["the script that keeps the helper includes it",
			NativeHeadMarks.includers_of(SHARED_HELPER), PackedStringArray(["Fixture Includer"])],
		["the variables an includer can use", variables, ["int damage_taken 0"]],
		["a file's includes are read once per version, so a second walk only checks its date",
			is_same(NativeHeadMarks._include_facts(INCLUDER), NativeHeadMarks._include_facts(INCLUDER)), true],
		["the walk names an includer by its class", NativeHeadMarks._include_facts(INCLUDER)["name"], "Fixture Includer"],
		["a script that extends a node is a node's script", _host_cases(), [true, true, false, false]],
	])


static func _host_cases() -> Array:
	return [ViewportRowBuilder.host_is_node("CharacterBody2D"), ViewportRowBuilder.host_is_node(""),
		ViewportRowBuilder.host_is_node("Resource"), ViewportRowBuilder.host_is_node("RefCounted")]


static func _test_class_users() -> bool:
	var file: FileAccess = FileAccess.open(USERS_FILE, FileAccess.WRITE)
	file.store_string("extends Node\n\nvar settings: GateSettings\nvar waves: Array[GateSettings] = []\n"
		+ "var _spare := GateSettings.new()\nvar speed := 2.0\n")
	file.close()
	var users: PackedStringArray = NativeHeadMarks.class_users(USERS_FILE, "GateSettings")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(USERS_FILE))
	# The open sheet answers from the rows it holds, so a variable added a moment ago - never saved,
	# never on disk - is a user straight away.
	var sheet := EventSheetResource.new()
	for declared: Array in [["settings", "GateSettings", null], ["waves", "Array[GateSettings]", null],
			["_spare", "Variant", "GateSettings.new()"], ["speed", "float", 2.0]]:
		var variable := LocalVariable.new()
		variable.name = declared[0]
		variable.type_name = declared[1]
		variable.default_value = declared[2]
		sheet.events.append(variable)
	return SUPPORT.pins(TEST_NAME, [
		["a variable, a list and a private one hold the class", users,
			PackedStringArray(["settings (a variable)", "waves (a list)", "_spare (a variable)"])],
		["an unsaved sheet answers from its own rows", NativeHeadMarks.class_users_in_sheet(sheet, "GateSettings"),
			PackedStringArray(["settings (a variable)", "waves (a list)", "_spare (a variable)"])],
	])


static func _test_class_head_of_a_shared_sheet() -> bool:
	NativeHeadMarks.forget_includers()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SHARED_BASE)
	sheet.read_only = false
	var view := _view_of(sheet)
	var head: EventRowData = _row_with_uid(view, "sheet_head_bar_")
	var notes: Array = []
	for span: SemanticSpan in head.spans if head != null else []:
		var card: Variant = (span.metadata as Dictionary).get("head_card") if span.metadata is Dictionary else null
		if card is Dictionary and str((card as Dictionary).get("id", "")) == "name":
			notes = Array((card as Dictionary).get("notes", []))
	var result: bool = SUPPORT.pins(TEST_NAME, [
		["the head bar reads the class, the kind and the base",
			_lead_texts(head),
			"◆ | FixtureDamageRules | Custom node · extends | Node"],
		["no extends band of its own", _row_with_uid(view, "sheet_head_extends_") == null, true],
		["the share mark and who includes it are the name card's words, not the bar's",
			[_texts(head).contains("⇆"), notes.slice(-2)],
			[false, ["A shared sheet: other sheets can include it.", "Included by Fixture Includer"]]],
		["a node's script says the node runs it", str(_flag_of(head, "Custom node", "hover_note")).get_slice(" Click", 0),
			"What this file is: a script, run by the node it is attached to."],
	])
	view.free()
	return result


static func _test_included_variables_toggle() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(INCLUDER)
	var view := _view_of(sheet)
	var shown: bool = _row_with_uid(view, "include_variable_FixtureDamageRules_damage_taken") != null
	view.show_included_variables = false
	view.rebuild_rows()
	var hidden: bool = _row_with_uid(view, "include_variable_FixtureDamageRules_damage_taken") == null
	var bar_kept: bool = _row_with_uid(view, "include_line_FixtureDamageRules") != null
	view.free()
	return SUPPORT.pins(TEST_NAME, [
		["View > Included Variables on lists them, off leaves the bar alone",
			[shown, hidden, bar_kept], [true, true, true]],
	])


static func _test_include_bar_shape() -> bool:
	var native_bar: EventRowData = _include_bar(NATIVE_THEME)
	# Every bundled theme states the Include edge now, so the clear case is a theme whose designer
	# cleared it.
	var classic_bar: EventRowData = _include_bar(CLASSIC_THEME, true)
	return SUPPORT.pins(TEST_NAME, [
		["a theme stating the Include edge draws a rounded bar",
			[native_bar.outline_radius, native_bar.height_scale, native_bar.outline_color.a > 0.0],
			[16.0, 1.3, true]],
		["a theme leaving it clear keeps the flat line",
			[classic_bar.outline_radius, classic_bar.height_scale, classic_bar.outline_color.a > 0.0],
			[0.0, 1.0, false]],
		["the rounded bar's echo is drawn at full strength", _echo_alpha(native_bar), 1.0],
		["the flat line's echo keeps its resting fade", _echo_alpha(classic_bar), EventSheetCodeEcho.REST_ALPHA],
	])


## The alpha the first segment of a row's code echo is drawn at, as a fraction of its colour's own.
static func _echo_alpha(row_data: EventRowData) -> float:
	for span: SemanticSpan in row_data.spans if row_data != null else []:
		if bool((span.metadata as Dictionary).get("code_echo", false)):
			var colour: Color = ((span.metadata as Dictionary)["bbcode_segments"] as Array)[0]["color"]
			return snappedf(colour.a, 0.01)
	return -1.0


static func _test_class_block() -> bool:
	var editable: EventRowData = _class_block(false)
	var preview: EventRowData = _class_block(true)
	var uids: PackedStringArray = PackedStringArray()
	var texts: PackedStringArray = PackedStringArray()
	for child: EventRowData in editable.children:
		uids.append(child.row_uid.get_slice("_Config", 0))
		texts.append(_texts(child))
	var last: EventRowData = editable.children[editable.children.size() - 1]
	return SUPPORT.pins(TEST_NAME, [
		["the open block: its fields, then Add field, then what a class is for", uids,
			PackedStringArray(["data_class_field", "data_class_field", "data_class_add_field",
				"data_class_why", "data_class_why", "data_class_why"])],
		["the add field words", texts[2], "+ Add field"],
		["the explainer leads with when to use a class", texts[3], "Use a class when values belong together"],
		["the head opens the frame and the last row closes it",
			[editable.frame_top, editable.frame_bottom, last.frame_bottom, last.frame_indent == editable.frame_indent],
			[true, false, true, true]],
		["the frame wears the class tokens", editable.frame_color.a > 0.0 and editable.frame_fill.a > 0.0, true],
		["a read-only preview has its fields and nothing to add", preview.children.size(), 2],
	])


static func _class_block(read_only: bool) -> EventRowData:
	var sheet := EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.read_only = read_only
	var raw := RawCodeRow.new()
	raw.code = "class Config:\n\tvar volume: float = 1.0\n\tvar muted: bool = false"
	sheet.events.append(raw)
	var view := _view_of(sheet)
	var found: EventRowData = null
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource == raw:
			found = row_data
	view.free()
	return found


static func _include_bar(theme_path: String, clear_include: bool = false) -> EventRowData:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(INCLUDER)
	sheet.editor_style = (load(theme_path) as EventSheetEditorStyle).duplicate(true)
	if clear_include:
		for token_name: String in ["include_border_color", "include_fill_color", "include_tag_color",
				"include_name_color", "include_note_color"]:
			sheet.editor_style.get_event_style().set(token_name, Color(0.0, 0.0, 0.0, 0.0))
	var view := _view_of(sheet)
	var bar: EventRowData = _row_with_uid(view, "include_line_FixtureDamageRules")
	view.free()
	return bar


static func _view_of(sheet: EventSheetResource) -> EventSheetViewport:
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	return view


static func _row_with_uid(view: EventSheetViewport, prefix: String) -> EventRowData:
	var stack: Array = []
	for entry: Dictionary in view.get_flat_rows():
		stack.append(entry.get("row"))
	while not stack.is_empty():
		var row_data: EventRowData = stack.pop_front()
		if row_data == null:
			continue
		if row_data.row_uid.begins_with(prefix):
			view._row_builder._ensure_event_spans(row_data)
			return row_data
		stack.append_array(row_data.children)
	return null


## One metadata value of the first span on `row_data` whose text starts with `prefix`.
static func _flag_of(row_data: EventRowData, prefix: String, key: String) -> Variant:
	for span: SemanticSpan in row_data.spans if row_data != null else []:
		if span.text.begins_with(prefix):
			return (span.metadata as Dictionary).get(key)
	return null


static func _texts(row_data: EventRowData) -> String:
	if row_data == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		parts.append(span.text)
	return " | ".join(parts)


## The head bar's words before its right-aligned counts: the icon, the name, the kind and the base.
static func _lead_texts(row_data: EventRowData) -> String:
	if row_data == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		if span.metadata is Dictionary and bool((span.metadata as Dictionary).get("align_right", false)):
			break
		parts.append(span.text)
	return " | ".join(parts)
