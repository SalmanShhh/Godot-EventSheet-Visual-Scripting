@tool
extends RefCounted
# Godot EventSheets - Inspector-style variable rows
#
# A theme that states inspector_variable_rows reads a variable row the way the Inspector lists a
# property: the GDScript type, the capitalised name, the value (a colour as its swatch and hex), the
# `##` description as the one italic note, and the attributes only as icon tiles - no kind mark, no
# scope word, no code echo. hide_compiler_variables leaves the compiler's `__` bookkeeping members
# out of the rows. Pinned as values:
#   1. the two tokens: off by default, on in the Editor Native starter and its rule, stated off in
#      every other shipped theme;
#   2. the readings the row prints: the GDScript type word, the Inspector name, a colour's hex;
#   3. the rows the builder makes under Editor Native, word for word, and under Classic Sheet as before;
#   4. a capitalised name still renames from the identifier the file holds;
#   5. the hidden bookkeeping member still compiles;
#   6. an italic note draws in room enough for its slanted words, so the editor's fonts keep its last
#      letter (the span is measured upright, and a slant can round a pixel or two wider).

const SUPPORT := preload("res://tests/support.gd")
const NativeVariableMarks := preload("res://addons/eventsheet/editor/interaction/native_variable_marks.gd")
const TEST_NAME := "native_variable_rows_test"
const NATIVE_THEME := "res://addons/eventsheet/themes/editor_native_theme.tres"
const CLASSIC_THEME := "res://addons/eventsheet/themes/classic_sheet_theme.tres"
const OTHER_THEMES := [
	"res://addons/eventsheet/themes/classic_sheet_theme.tres",
	"res://addons/eventsheet/themes/mockup_slate_theme.tres",
	"res://demo/themes/catppuccin_mocha_theme.tres",
	"res://demo/themes/designer_template_theme.tres",
	"res://demo/themes/dracula_theme.tres",
	"res://demo/themes/gruvbox_dark_theme.tres",
	"res://demo/themes/high_contrast_theme.tres",
	"res://demo/themes/monokai_theme.tres",
	"res://demo/themes/nord_theme.tres",
	"res://demo/themes/soft_light_theme.tres",
	"res://demo/themes/solarized_light_theme.tres",
]


static func run() -> bool:
	var ok: bool = true
	ok = _test_tokens() and ok
	ok = _test_readings() and ok
	ok = _test_native_rows() and ok
	ok = _test_classic_rows_unchanged() and ok
	ok = _test_rename_edits_the_identifier() and ok
	ok = _test_hidden_member_still_compiles() and ok
	ok = _test_italic_note_keeps_its_last_letter() and ok
	return ok


static func _test_tokens() -> bool:
	var native: EventSheetEventStyle = (load(NATIVE_THEME) as EventSheetEditorStyle).get_event_style()
	var built: EventSheetEventStyle = EventSheetEditorThemeDeriver.native_style(
		EventSheetEditorThemeDeriver.NATIVE_DARK_REFERENCE_BASE).get_event_style()
	var others: Array = []
	for path: String in OTHER_THEMES:
		var style: EventSheetEventStyle = (load(path) as EventSheetEditorStyle).get_event_style()
		others.append([path.get_file(), style.inspector_variable_rows, style.hide_compiler_variables])
	var expected_others: Array = []
	for path: String in OTHER_THEMES:
		expected_others.append([path.get_file(), false, false])
	return SUPPORT.pins(TEST_NAME, [
		["the tokens default off", [EventSheetEventStyle.new().inspector_variable_rows,
			EventSheetEventStyle.new().hide_compiler_variables], [false, false]],
		["the starter states both on", [native.inspector_variable_rows, native.hide_compiler_variables], [true, true]],
		["and so does the rule it is built by", [built.inspector_variable_rows, built.hide_compiler_variables], [true, true]],
		["every other shipped theme states both off", others, expected_others],
	])


static func _test_readings() -> bool:
	return SUPPORT.pins(TEST_NAME, [
		["a declared type is printed as written", NativeVariableMarks.gdscript_type_word("Array[Node2D]", [], false), "Array[Node2D]"],
		["an enum type by its name", NativeVariableMarks.gdscript_type_word("GateState", 0, false), "GateState"],
		["an untyped whole number is an int", NativeVariableMarks.gdscript_type_word("", "5", true), "int"],
		["an untyped decimal is a float", NativeVariableMarks.gdscript_type_word("", "300.0", true), "float"],
		["an untyped quoted literal is a String", NativeVariableMarks.gdscript_type_word("", "\"idle\"", true), "String"],
		["a constructor names its type", NativeVariableMarks.gdscript_type_word("", "Vector2.ZERO", true), "Vector2"],
		["a real value names its type", NativeVariableMarks.gdscript_type_word("Variant", Color.RED, false), "Color"],
		["a computed value says Variant", NativeVariableMarks.gdscript_type_word("", "speed * 2", true), "Variant"],
		["the Inspector's capitals", NativeVariableMarks.inspector_name("open_speed"), "Open Speed"],
		["a one-word name", NativeVariableMarks.inspector_name("lives"), "Lives"],
		["a real colour as its hex", NativeVariableMarks.color_hex(NativeVariableMarks.color_of(Color8(255, 179, 71))), "#FFB347"],
		["a literal colour", NativeVariableMarks.color_hex(NativeVariableMarks.color_of("Color(1, 0, 0)")), "#FF0000"],
		["a named constant", NativeVariableMarks.color_hex(NativeVariableMarks.color_of("Color.WHITE")), "#FFFFFF"],
		["an html call", NativeVariableMarks.color_hex(NativeVariableMarks.color_of("Color(\"#336699\")")), "#336699"],
		["see-through keeps its alpha", NativeVariableMarks.color_hex(Color(1, 1, 1, 0.5)), "#FFFFFF80"],
		["a computed colour is not read", NativeVariableMarks.color_of("Color(r, g, b)"), null],
		["a bookkeeping member", NativeVariableMarks.is_compiler_variable("__every_ps_spawn"), true],
		["an author's member", NativeVariableMarks.is_compiler_variable("_private"), false],
	])


static func _test_native_rows() -> bool:
	var viewport: EventSheetViewport = _viewport_for(NATIVE_THEME)
	var raw_rows: int = 0
	for index: int in range(viewport._flat_rows.size()):
		var row: EventRowData = viewport._row_at(index)
		if row != null and row.source_resource is RawCodeRow:
			raw_rows += 1
	var speed_name: SemanticSpan = _span_with(_row_named(viewport, "open_speed"), "variable_name_span")
	var glow_value: SemanticSpan = _span_with(_row_named(viewport, "glow_color"), "variable_value_span")
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["an exported variable: type, name, value, its tooltip as the note",
			_words(_row_named(viewport, "open_speed")),
			["float", "Open Speed", "⚙", "=", "2", "How fast the gate opens"]],
		["a plain var reads the ## line above it as its note",
			_words(_row_named(viewport, "open_progress")), ["float", "Open Progress", "=", "0", "How far open the gate is"]],
		["so the ## line is not listed again", raw_rows, 0],
		["an untyped var prints the type its value gives away", _words(_row_named(viewport, "hit_count")),
			["int", "Hit Count", "=", "5"]],
		["a colour reads as its hex", _words(_row_named(viewport, "glow_color")), ["Color", "Glow Color", "=", "#FFB347"]],
		["and leads with its swatch", [glow_value.metadata.get("value_glyph"), glow_value.metadata.get("value_swatch")],
			["color", Color8(255, 179, 71)]],
		["typing into it edits the reading the sentence row edits", glow_value.metadata.get("edit_text"), "(1.0, 0.702, 0.2784, 1.0)"],
		["a typed list keeps its GDScript type", _words(_row_named(viewport, "guards")).slice(0, 2),
			["Array[Node2D]", "Guards"]],
		["the tiles are the attributes", speed_name.metadata.get("variable_badges"),
			PackedStringArray(["inspector", "range", "tooltip"])],
		["the scope word moves to the name's hover",
			str(speed_name.metadata.get("hover_note", "")).contains(EventSheetVariableSentence.scope_word(
				EventSheetVariableSentence.SCOPE_INSTANCE)), true],
		["the compiler's bookkeeping member is not listed", _row_named(viewport, "__every_tick") == null, true],
	])
	viewport.free()
	return ok


static func _test_classic_rows_unchanged() -> bool:
	var viewport: EventSheetViewport = _viewport_for(CLASSIC_THEME)
	var speed: Array = _words(_row_named(viewport, "open_speed"))
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["classic: the kind mark, the scope word, the type in words, the identifier", speed.slice(0, 4),
			["x", "Instance", "number", "open_speed"]],
		["classic: the declaration echo still trails it", str(speed[speed.size() - 1]),
			"@export_range(0, 10, 1) var open_speed: float = 2.0"],
		["classic: the colour keeps its numbers",
			_span_with(_row_named(viewport, "glow_color"), "variable_value_span").text, "(1.0, 0.702, 0.2784, 1.0)"],
		["classic: the bookkeeping member is listed", _row_named(viewport, "__every_tick") != null, true],
	])
	viewport.free()
	return ok


static func _test_rename_edits_the_identifier() -> bool:
	var viewport: EventSheetViewport = _viewport_for(NATIVE_THEME)
	viewport.set_external_span_edit_handler_enabled(true)
	var captured: Array = []
	viewport.span_edit_requested.connect(func(_row: EventRowData, kind: String, old_value: String, new_value: String) -> void:
		captured.append([kind, old_value, new_value]))
	var row_index: int = -1
	for index: int in range(viewport._flat_rows.size()):
		if viewport._row_at(index) == _row_named(viewport, "open_speed"):
			row_index = index
	var opened: bool = viewport.begin_variable_rename(row_index)
	var buffer: String = str(viewport.get_editing_context_for_test().get("buffer", ""))
	viewport._editing_buffer = "gate_speed"
	viewport._commit_edit()
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["F2 opens the field", opened, true],
		["on the identifier, not the capitalised name", buffer, "open_speed"],
		["and the rename runs from the identifier", captured, [["variable_rename", "open_speed", "gate_speed"]]],
	])
	viewport.free()
	return ok


static func _test_hidden_member_still_compiles() -> bool:
	var output: String = str(SheetCompiler.new().compile(_sheet()).get("output", ""))
	return SUPPORT.pins(TEST_NAME, [
		["the hidden member is still declared", output.contains("var __every_tick: float = 0.0"), true],
		["the ## line above a plain var is still written", output.contains("## How far open the gate is"), true],
	])


static func _test_italic_note_keeps_its_last_letter() -> bool:
	var font: Font = ThemeDB.fallback_font
	var text: String = "How fast the gate opens, in units per second"
	var upright: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x
	var leaning: float = NativeVariableMarks.italic_font(font).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x
	var room: float = NativeVariableMarks.italic_room(font, text, 12, upright)
	return SUPPORT.pins(TEST_NAME, [
		["the room covers the slanted words", room >= leaning, true],
		["and never shrinks below the span's own", room >= upright, true],
		["the room is the span's plus only what the slant adds", room, upright + maxf(leaning - upright, 0.0)],
		["no font keeps the span's room", NativeVariableMarks.italic_room(null, text, 12, 40.0), 40.0],
		["an empty note keeps it too", NativeVariableMarks.italic_room(font, "", 12, 40.0), 40.0],
	])


static func _sheet() -> EventSheetResource:
	var sheet := EventSheetResource.new()
	sheet.host_class = "Node2D"
	var speed := LocalVariable.new()
	speed.name = "open_speed"
	speed.type_name = "float"
	speed.default_value = 2.0
	speed.exported = true
	speed.attributes = {"range": {"min": "0", "max": "10", "step": "1"}, "tooltip": "How fast the gate opens"}
	sheet.events.append(speed)
	var doc := RawCodeRow.new()
	doc.code = "## How far open the gate is"
	sheet.events.append(doc)
	var progress := LocalVariable.new()
	progress.name = "open_progress"
	progress.type_name = "float"
	progress.default_value = 0.0
	sheet.events.append(progress)
	var glow := LocalVariable.new()
	glow.name = "glow_color"
	glow.type_name = "Color"
	glow.default_value = Color8(255, 179, 71)
	sheet.events.append(glow)
	var hits := LocalVariable.new()
	hits.name = "hit_count"
	hits.type_name = ""
	hits.default_value = "5"
	hits.expression_default = true
	hits.inferred_type = true
	sheet.events.append(hits)
	var guards := LocalVariable.new()
	guards.name = "guards"
	guards.type_name = "Array[Node2D]"
	guards.default_value = []
	sheet.events.append(guards)
	var clock := LocalVariable.new()
	clock.name = "__every_tick"
	clock.type_name = "float"
	clock.default_value = 0.0
	sheet.events.append(clock)
	return sheet


static func _viewport_for(theme_path: String) -> EventSheetViewport:
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var sheet: EventSheetResource = _sheet()
	sheet.editor_style = (load(theme_path) as EventSheetEditorStyle).duplicate(true)
	viewport.set_sheet(sheet)
	return viewport


static func _words(row: EventRowData) -> Array:
	var words: Array = []
	if row == null:
		return words
	for span: SemanticSpan in row.spans:
		if span != null:
			words.append(span.text)
	return words


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
