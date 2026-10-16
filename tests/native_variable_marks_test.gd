@tool
extends RefCounted
# Godot EventSheets - the drawn look of a variable row
#
# The type word in its colour family, the value as the Inspector draws it, the doc comment in
# italics and the badge tiles at the row's right. All of it is paint over spans the row already
# had, so the pins here are the VALUES each mark is decided and placed by:
#   1. which colour family a type reads as, declared or inferred;
#   2. which glyph a value takes, and the vector components it shows;
#   3. which badges a variable earns, and the save keys the saved badge reads;
#   4. that a family colour stays readable on the fill it lands on;
#   5. where the badge tiles stand, and which one a point is on;
#   6. that the row builder stamps the facts without changing a word, and that the toggles move the
#      room the marks take and nothing else.

const SUPPORT := preload("res://tests/support.gd")
const NativeVariableMarks := preload("res://addons/eventsheet/editor/interaction/native_variable_marks.gd")
const TEST_NAME := "native_variable_marks_test"


static func run() -> bool:
	var ok: bool = true
	ok = _test_type_families() and ok
	ok = _test_value_glyphs() and ok
	ok = _test_badges() and ok
	ok = _test_readable_ink() and ok
	ok = _test_tile_geometry() and ok
	ok = _test_builder_stamps_facts_and_keeps_words() and ok
	return ok


static func _test_type_families() -> bool:
	var enums := PackedStringArray(["GateState"])
	return SUPPORT.pins(TEST_NAME, [
		["a float is a number", NativeVariableMarks.type_family("float", 2.0), "number"],
		["an int is a number", NativeVariableMarks.type_family("int", 1), "number"],
		["a StringName is text", NativeVariableMarks.type_family("StringName", &"a"), "text"],
		["a bool", NativeVariableMarks.type_family("bool", true), "bool"],
		["a Vector3i is a vector", NativeVariableMarks.type_family("Vector3i", Vector3i.ZERO), "vector"],
		["a Color", NativeVariableMarks.type_family("Color", Color.WHITE), "color"],
		["a typed array is a collection", NativeVariableMarks.type_family("Array[Node2D]", []), "collection"],
		["a packed array is a collection", NativeVariableMarks.type_family("PackedStringArray", PackedStringArray()), "collection"],
		["a PackedScene is an object", NativeVariableMarks.type_family("PackedScene", null), "object"],
		["a NodePath is an object", NativeVariableMarks.type_family("NodePath", NodePath("..")), "object"],
		["a node class is an object", NativeVariableMarks.type_family("Node2D", null), "object"],
		["a resource class is an object", NativeVariableMarks.type_family("Curve", null), "object"],
		["the sheet's own enum", NativeVariableMarks.type_family("GateState", 0, false, enums), "enum"],
		["another script's enum", NativeVariableMarks.type_family("Gate.State", 0), "enum"],
		["anything else is a class", NativeVariableMarks.type_family("GateSettings", null), "class"],
		["untyped: the value says", NativeVariableMarks.type_family("", 100), "number"],
		["untyped code: a quoted literal", NativeVariableMarks.type_family("", "\"idle\"", true), "text"],
		["untyped code: a constructor", NativeVariableMarks.type_family("", "Vector2.ZERO", true), "vector"],
		["untyped code that says nothing", NativeVariableMarks.type_family("", "speed * 2", true), ""],
	])


static func _test_value_glyphs() -> bool:
	return SUPPORT.pins(TEST_NAME, [
		["true is a ticked box", NativeVariableMarks.value_glyph("bool", "true", true, false),
			{"glyph": "bool", "axes": PackedStringArray(), "on": true}],
		["false is an empty one", NativeVariableMarks.value_glyph("bool", "false", false, false)["on"], false],
		["a hint-read bool keeps its words", NativeVariableMarks.value_glyph("bool", "yes", true, false)["glyph"], ""],
		["a Vector2 shows its components", NativeVariableMarks.value_glyph("vector", "(0.0, -48.0)", Vector2(0, -48), false)["axes"],
			PackedStringArray(["0", "-48"])],
		["a Vector3 shows three", NativeVariableMarks.vector_axes(Vector3(1.5, 0, 2)), PackedStringArray(["1.5", "0", "2"])],
		["a literal constructor", NativeVariableMarks.vector_axes("Vector2(0, -48.0)", true), PackedStringArray(["0", "-48"])],
		["a named constant", NativeVariableMarks.vector_axes("Vector3.ONE", true), PackedStringArray(["1", "1", "1"])],
		["a constructor of the wrong arity reads as text", NativeVariableMarks.vector_axes("Vector3(1, 2)", true), PackedStringArray()],
		["a computed vector reads as text", NativeVariableMarks.vector_axes("Vector2(speed, 0)", true), PackedStringArray()],
		["a node path is a resource chip", NativeVariableMarks.value_glyph("object", "../Hinge", NodePath("../Hinge"), false)["glyph"], "resource"],
		["an empty object is plain", NativeVariableMarks.value_glyph("object", "null", null, false)["glyph"], ""],
		["a number stays plain text", NativeVariableMarks.value_glyph("number", "2", 2.0, false)["glyph"], ""],
		["the tick box takes its box and a gap", NativeVariableMarks.glyph_extra_width("bool"), 19.0],
		["the chip takes its padding and mark", NativeVariableMarks.glyph_extra_width("resource"), 30.0],
	])


static func _test_badges() -> bool:
	var ranged := LocalVariable.new()
	ranged.attributes = {"range": {"min": "0", "max": "10"}}
	var hinted := LocalVariable.new()
	hinted.export_hint = "@export_range(0, 1)"
	var source_path: String = "user://native_variable_marks_test_source.gd"
	var handle: FileAccess = FileAccess.open(source_path, FileAccess.WRITE)
	handle.store_string("extends Node\n\nvar coins := 0\nvar hp := 3\n\nfunc _save() -> void:\n" +
		"\tSaveSystem.save_value(\"coins\", coins)\n\t# SaveSystem.save_value(\"hp\", hp)\n")
	handle.close()
	var saved: Dictionary = NativeVariableMarks.saved_names(source_path)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["every badge, in its standing order", NativeVariableMarks.badges_for(true, true, true, true),
			PackedStringArray(["inspector", "range", "tooltip", "saved"])],
		["only what the variable earns", NativeVariableMarks.badges_for(false, false, true, true),
			PackedStringArray(["tooltip", "saved"])],
		["a structured range", NativeVariableMarks.has_range(ranged), true],
		["a range left in the hint", NativeVariableMarks.has_range(hinted), true],
		["no variable, no range", NativeVariableMarks.has_range(null), false],
		["a key the file saves is saved", saved.has("coins"), true],
		["a save in a comment is not", saved.has("hp"), false],
		["a sheet with no file saves nothing", NativeVariableMarks.saved_names(""), {}],
		["the eye says what the old mark said", NativeVariableMarks.badge_tooltip("inspector"), "Editable in the Inspector"],
	])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(source_path))
	return ok


static func _test_readable_ink() -> bool:
	var dark_fill := Color("#262b33")
	var light_fill := Color("#ffffff")
	var pale := Color("#a6d18f")
	var deep := Color("#2c681c")
	return SUPPORT.pins(TEST_NAME, [
		["a pale colour on a dark fill is kept", NativeVariableMarks.readable_ink(pale, dark_fill).to_html(false), "a6d18f"],
		["a deep colour on a light fill is kept", NativeVariableMarks.readable_ink(deep, light_fill).to_html(false), "2c681c"],
		["a deep colour on a dark fill is lightened", NativeVariableMarks.readable_ink(deep, dark_fill).get_luminance() > 0.5, true],
		["a pale colour on a light fill is darkened", NativeVariableMarks.readable_ink(pale, light_fill).get_luminance() < 0.5, true],
		["the axis letters for a dark row", NativeVariableMarks.axis_colors(dark_fill)[0].to_html(false), "ff8a80"],
		["the axis letters for a light row", NativeVariableMarks.axis_colors(light_fill)[0].to_html(false), "b3261e"],
	])


static func _test_tile_geometry() -> bool:
	var row := EventRowData.new()
	row.variable_row = true
	var name_span := SemanticSpan.new()
	name_span.text = "open_speed"
	name_span.rect = Rect2(100.0, 40.0, 80.0, 18.0)
	name_span.metadata = {"variable_badges": PackedStringArray(["inspector", "range"]), "badge_tiles_x": 500.0}
	row.spans.append(name_span)
	var rects: Array[Rect2] = NativeVariableMarks.tile_rects(500.0, 49.0, 2)
	return SUPPORT.pins(TEST_NAME, [
		["no tiles reserve nothing", NativeVariableMarks.badge_reserve(0), 0.0],
		["three tiles reserve the lead, three tiles and two gaps", NativeVariableMarks.badge_reserve(3), 66.0],
		["the first tile stands one lead in", rects[0], Rect2(508.0, 40.0, 18.0, 18.0)],
		["the next one a gap after it", rects[1], Rect2(528.0, 40.0, 18.0, 18.0)],
		["the row's badges", NativeVariableMarks.row_badges(row), PackedStringArray(["inspector", "range"])],
		["a point on the second tile", NativeVariableMarks.badge_at(row, Vector2(537.0, 49.0)), "range"],
		["a point between the sentence and the tiles", NativeVariableMarks.badge_at(row, Vector2(450.0, 49.0)), ""],
	])


static func _test_builder_stamps_facts_and_keeps_words() -> bool:
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet := EventSheetResource.new()
	sheet.host_class = "Node2D"
	var speed := LocalVariable.new()
	speed.name = "open_speed"
	speed.type_name = "float"
	speed.default_value = 2.0
	speed.exported = true
	speed.description = "How fast the gate opens"
	speed.attributes = {"range": {"min": "0", "max": "10"}}
	var locked := LocalVariable.new()
	locked.name = "is_locked"
	locked.type_name = "bool"
	locked.default_value = true
	var offset := LocalVariable.new()
	offset.name = "open_offset"
	offset.type_name = "Vector2"
	offset.default_value = Vector2(0, -48)
	sheet.events.append(speed)
	sheet.events.append(locked)
	sheet.events.append(offset)
	viewport.set_sheet(sheet)
	var speed_row: EventRowData = _row_named(viewport, "open_speed")
	var locked_row: EventRowData = _row_named(viewport, "is_locked")
	var offset_row: EventRowData = _row_named(viewport, "open_offset")
	var speed_type: SemanticSpan = _span_with(speed_row, "variable_type_span")
	var speed_name: SemanticSpan = _span_with(speed_row, "variable_name_span")
	var speed_mark: SemanticSpan = _span_with(speed_row, "inspector_badge")
	var speed_note: SemanticSpan = _span_with(speed_row, "variable_doc_note")
	var locked_value: SemanticSpan = _span_with(locked_row, "variable_value_span")
	var offset_value: SemanticSpan = _span_with(offset_row, "variable_value_span")
	var font: Font = ThemeDB.fallback_font
	var with_marks_mark: float = viewport._row_builder._measure_span_width(speed_mark, speed_mark.text, font, 14)
	var with_marks_value: float = viewport._row_builder._measure_span_width(locked_value, locked_value.text, font, 14)
	viewport.show_value_glyphs = false
	viewport.show_variable_badges = false
	var plain_mark: float = viewport._row_builder._measure_span_width(speed_mark, speed_mark.text, font, 14)
	var plain_value: float = viewport._row_builder._measure_span_width(locked_value, locked_value.text, font, 14)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["the type word keeps its words", speed_type.text, "number"],
		["and carries its family", speed_type.metadata.get("variable_type_family"), "number"],
		["the name carries the badges it earned", speed_name.metadata.get("variable_badges"),
			PackedStringArray(["inspector", "range", "tooltip"])],
		["a variable with nothing to say earns none", _span_with(locked_row, "variable_name_span").metadata.get("variable_badges"),
			PackedStringArray()],
		["the old Inspector mark is still a span, with its glyph", speed_mark.text, "⚙"],
		["the doc comment is the note it always was", speed_note.text, "How fast the gate opens"],
		["a bool value keeps its word and gains a tick box", [locked_value.text, locked_value.metadata.get("value_glyph"), locked_value.metadata.get("value_on")],
			["true", "bool", true]],
		["a vector value keeps its reading and gains its fields", offset_value.metadata.get("value_axes"), PackedStringArray(["0", "-48"])],
		["with badges shown the mark stands among the tiles", with_marks_mark, 0.0],
		["with them off it keeps its own box", plain_mark > 0.0, true],
		["the tick box adds exactly its room", with_marks_value - plain_value, NativeVariableMarks.glyph_extra_width("bool")],
	])
	viewport.free()
	return ok


static func _row_named(viewport: EventSheetViewport, variable_name: String) -> EventRowData:
	for index: int in range(viewport._flat_rows.size()):
		var row: EventRowData = viewport._row_at(index)
		if row == null or not row.variable_row:
			continue
		for span: SemanticSpan in row.spans:
			if span != null and span.metadata is Dictionary and str((span.metadata as Dictionary).get("variable_name", "")) == variable_name:
				return row
	return null


static func _span_with(row: EventRowData, flag: String) -> SemanticSpan:
	if row == null:
		return null
	for span: SemanticSpan in row.spans:
		if span != null and span.metadata is Dictionary and bool((span.metadata as Dictionary).get(flag, false)):
			return span
	return null
