# Godot EventSheets - the ONE shape a variable row reads in, and the code echo beside it.
#
# V1/V2/V3/V13. A variable row is a sentence: a kind badge, the scope word, the type word, the name,
# a sliders mark when the value is editable in the Inspector, then `= value`. The `name : Type` code
# grammar is gone from the row (it lives on the hover and in the code panel), the scope word is
# DERIVED from where the sheet lives rather than stored, the list keeps the order it was written in,
# and the declaration the compiler will emit echoes at the row's right edge.
#
# Everything here is pinned by VALUE - the words, the token classes, the order - because a count
# would still pass after the row lost the very fact the count was standing in for.
@tool
class_name VariableRowSentenceTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_tokeniser_names_every_part_of_a_declaration() and ok
	ok = _test_the_echo_is_the_declaration_line_only() and ok
	ok = _test_the_segments_rest_below_full_colour() and ok
	ok = _test_the_scope_word_is_derived() and ok
	ok = _test_the_list_keeps_the_order_it_was_written_in() and ok
	ok = _test_the_row_reads_as_one_sentence() and ok
	ok = _test_the_view_dial_decides_what_the_row_carries() and ok
	ok = _test_an_inspector_group_is_a_folder_strip_over_unindented_rows() and ok
	ok = _test_a_literal_that_does_not_fit_its_type_is_refused() and ok
	ok = _test_the_order_is_written_not_sorted_behind_your_back() and ok
	ok = _test_the_order_reaches_the_file() and ok
	ok = _test_show_in_inspector_writes_the_flag() and ok
	return ok


## V2 - order is a fact about the file now, so the two gestures that change it WRITE it: Sort A-Z on
## the row menu, and dragging one declaration past another. Both land through the undo funnel.
static func _test_the_order_is_written_not_sorted_behind_your_back() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.variables = {
		"speed": {"type": "float", "default": 200.0, "exported": false},
		"hp": {"type": "int", "default": 100, "exported": false},
		"alive": {"type": "bool", "default": true, "exported": false},
	}
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()
	var moved: EventRowData = _row_named(view, "alive")
	var anchor: EventRowData = _row_named(view, "speed")
	dock._on_row_drop_requested(moved, anchor, "before", false)
	ok = _check("dragging a declaration writes the new order",
		PackedStringArray(dock.get_current_sheet().variables.keys()),
		PackedStringArray(["alive", "speed", "hp"])) and ok
	dock._on_undo_requested()
	ok = _check("and undo puts the file back",
		PackedStringArray(dock.get_current_sheet().variables.keys()),
		PackedStringArray(["speed", "hp", "alive"])) and ok
	dock._variables.sort_variables_alphabetically()
	ok = _check("Sort A-Z writes name order rather than sorting the view",
		PackedStringArray(dock.get_current_sheet().variables.keys()),
		PackedStringArray(["alive", "hp", "speed"])) and ok
	dock.free()
	return ok


## V2 - and the file follows: what the rows show is the order the compiler writes, so the echo on a
## row cannot claim a line the file does not have. Without this the reorder was a view-only gesture.
static func _test_the_order_reaches_the_file() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.variables = {
		"speed": {"type": "float", "default": 200.0, "exported": false},
		"hp": {"type": "int", "default": 100, "exported": false},
		"alive": {"type": "bool", "default": true, "exported": false},
	}
	ok = _check("the emitted file is in the order the rows are in",
		_declared_names(sheet), PackedStringArray(["speed", "hp", "alive"])) and ok
	sheet.variables = {
		"alive": {"type": "bool", "default": true, "exported": false},
		"hp": {"type": "int", "default": 100, "exported": false},
		"speed": {"type": "float", "default": 200.0, "exported": false},
	}
	ok = _check("and Sort A-Z is a change to the file, not to the view",
		_declared_names(sheet), PackedStringArray(["alive", "hp", "speed"])) and ok
	return ok


## The variables an emitted sheet declares, in file order.
static func _declared_names(sheet: EventSheetResource) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var output: String = str(SheetCompiler.compile(sheet, "user://variable_row_order.gd").get("output", ""))
	for line: String in output.split("
"):
		var bare: String = line.strip_edges()
		if bare.begins_with("var ") and bare.contains(":"):
			names.append(bare.trim_prefix("var ").get_slice(":", 0).strip_edges())
	return names


## V8 - "Show in Inspector" is the one gesture that adds `@export` to a variable, so it has to reach
## the sheet: the flag is written, the edit is one undo step, and the menu's tick follows it.
static func _test_show_in_inspector_writes_the_flag() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.variables = {"hp": {"type": "int", "default": 100, "exported": false}}
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var manager: EventSheetVariablesManager = dock._variables
	manager._context_variable = {"name": "hp", "scope": "global", "exported": false}
	ok = _check("the tick starts where the descriptor says", manager.context_variable_exported(), false) and ok
	manager._on_variable_context_menu_id_pressed(dock.VARIABLE_MENU_SHOW_IN_INSPECTOR)
	ok = _check("the flag is written into the sheet",
		bool((dock.get_current_sheet().variables["hp"] as Dictionary).get("exported", false)), true) and ok
	ok = _check("and the row now emits an @export line",
		str(SheetCompiler.compile(dock.get_current_sheet(), "user://variable_row_export.gd").get("output", "")).contains("@export var hp"),
		true) and ok
	ok = _check("the menu tick follows the write", manager.context_variable_exported(), true) and ok
	dock._on_undo_requested()
	ok = _check("and it is one undo step",
		bool((dock.get_current_sheet().variables["hp"] as Dictionary).get("exported", true)), false) and ok
	dock.free()
	return ok


## The live variable row named `var_name` in a dock's view, or null.
static func _row_named(view: EventSheetViewport, var_name: String) -> EventRowData:
	for entry: Variant in view.get_flat_rows():
		var row_data: EventRowData = (entry as Dictionary).get("row")
		if row_data != null and _name_of(row_data) == var_name:
			return row_data
	return null


## Every part of a declaration lands in the class the script editor would colour it with.
static func _test_the_tokeniser_names_every_part_of_a_declaration() -> bool:
	var ok: bool = true
	var line: String = "@export var speed: float = 200.0  # pixels"
	ok = _check("the runs put the line back together exactly", _rejoined(line), line) and ok
	ok = _check("an annotation is an annotation", _token_of(line, "@export"), "annotation") and ok
	ok = _check("var is a keyword", _token_of(line, "var"), "keyword") and ok
	ok = _check("the name is a member", _token_of(line, "speed"), "member") and ok
	ok = _check("the declared type is a type", _token_of(line, "float"), "type") and ok
	ok = _check("the literal is a number", _token_of(line, "200.0"), "number") and ok
	ok = _check("the colon is a symbol", _token_of(line, ":"), "symbol") and ok
	ok = _check("the trailing note is a comment", _token_of(line, "# pixels"), "comment") and ok
	var text_line: String = "const GREETING: String = \"hi there\""
	ok = _check("const is a keyword", _token_of(text_line, "const"), "keyword") and ok
	ok = _check("a String is a type", _token_of(text_line, "String"), "type") and ok
	ok = _check("a quoted literal is one string run", _token_of(text_line, "\"hi there\""), "string") and ok
	ok = _check("an engine class is a type too", EventSheetCodeEcho.word_token("Node2D"), "type") and ok
	ok = _check("true is a keyword, not a member", EventSheetCodeEcho.word_token("true"), "keyword") and ok
	return ok


## The echo is the DECLARATION - never the doc comment above it, never the Inspector section header
## the emitter writes in front of a grouped variable.
static func _test_the_echo_is_the_declaration_line_only() -> bool:
	var ok: bool = true
	var emitted: String = "## How fast it walks.\n@export_group(\"Movement\")\n@export var speed: float = 200.0"
	ok = _check("the doc comment and the group header are left where they belong",
		EventSheetCodeEcho.declaration_line(emitted), "@export var speed: float = 200.0") and ok
	var variable := LocalVariable.new()
	variable.name = "hp"
	variable.type_name = "int"
	variable.default_value = 100
	ok = _check("a plain member echoes the line the compiler writes",
		EventSheetCodeEcho.line_for(variable), "var hp: int = 100") and ok
	ok = _check("a sheet-level variable goes through the same emitter",
		EventSheetCodeEcho.line_for_descriptor("lives", {"type": "int", "default": 3, "exported": false}),
		"var lives: int = 3") and ok
	ok = _check("a global read here echoes the way you would type it",
		EventSheetCodeEcho.reference_line("Game", "Score"), "Game.Score") and ok
	return ok


## A resting echo is drawn at a fraction of its colour; the run count and the text never change with it.
static func _test_the_segments_rest_below_full_colour() -> bool:
	var ok: bool = true
	var line: String = "var hp: int = 100"
	var colours: Dictionary = EventSheetCodeEcho.palette(EventSheetReadingStyle.new(), EventSheetEventStyle.new())
	var resting: Array[Dictionary] = EventSheetCodeEcho.segments(line, colours, EventSheetCodeEcho.REST_ALPHA)
	ok = _check("one segment per run", resting.size(), EventSheetCodeEcho.tokens(line).size()) and ok
	var keyword_alpha: float = 0.0
	for segment: Dictionary in resting:
		if str(segment.get("text", "")) == "var":
			keyword_alpha = (segment.get("color") as Color).a
	ok = _check("the resting run is at the resting alpha",
		is_equal_approx(keyword_alpha, colours[EventSheetCodeEcho.TOKEN_KEYWORD].a * EventSheetCodeEcho.REST_ALPHA),
		true) and ok
	var lit: Array = EventRowRenderer.opaque_segments(resting)
	var lit_alpha: float = 0.0
	for entry: Variant in lit:
		if str((entry as Dictionary).get("text", "")) == "var":
			lit_alpha = ((entry as Dictionary).get("color") as Color).a
	ok = _check("and comes up to full on the row under the pointer", lit_alpha, 1.0) and ok
	return ok


## V3 - the scope word comes from where the sheet lives, and from `const`. Nothing is stored.
static func _test_the_scope_word_is_derived() -> bool:
	var ok: bool = true
	var view := EventSheetViewport.new()
	var node_sheet: EventSheetResource = EventSheetResource.new()
	node_sheet.host_class = "Node2D"
	node_sheet.variables = {"hp": {"type": "int", "default": 100, "exported": false}}
	ok = _check("a node script says Instance",
		_scope_word(view._build_global_variable_rows(node_sheet), "hp"), "Instance") and ok
	var resource_sheet: EventSheetResource = EventSheetResource.new()
	resource_sheet.host_class = "Resource"
	resource_sheet.variables = {"damage": {"type": "float", "default": 10.0, "exported": true}}
	ok = _check("a Resource script says Field",
		_scope_word(view._build_global_variable_rows(resource_sheet), "damage"), "Field") and ok
	var const_sheet: EventSheetResource = EventSheetResource.new()
	const_sheet.host_class = "Node2D"
	const_sheet.variables = {"MAX_HP": {"type": "int", "default": 100, "const": true, "exported": false}}
	ok = _check("a const says Constant",
		_scope_word(view._build_global_variable_rows(const_sheet), "MAX_HP"), "Constant") and ok
	view.free()
	return ok


## V2 - author order. The view stopped sorting these by name, so the list reads as the file does.
static func _test_the_list_keeps_the_order_it_was_written_in() -> bool:
	var view := EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables = {
		"speed": {"type": "float", "default": 200.0, "exported": false},
		"hp": {"type": "int", "default": 100, "exported": false},
		"alive": {"type": "bool", "default": true, "exported": false},
	}
	var names: PackedStringArray = PackedStringArray()
	for row: Variant in view._build_global_variable_rows(sheet):
		names.append(_name_of(row as EventRowData))
	view.free()
	return _check("the rows are in the order they were written",
		names, PackedStringArray(["speed", "hp", "alive"]))


## V1 - the shape: badge, scope word, type word, name, sliders mark, `=`, value. No pills, and no
## `name : Type` anywhere on the row (that spelling survives as the name's hover).
static func _test_the_row_reads_as_one_sentence() -> bool:
	var ok: bool = true
	var view := EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.variables = {"speed": {"type": "float", "default": 200.0, "exported": true}}
	var rows: Array = view._build_global_variable_rows(sheet)
	var row: EventRowData = rows[0]
	ok = _check("the row is a variable row the theme can wash", row.variable_row, true) and ok
	ok = _check("the sentence reads scope, type, name, value",
		_texts(row), "x | Instance | number | speed | ⚙ | = | 200 | @export var speed: float = 200.0") and ok
	ok = _check("the kind badge leads the row",
		bool((row.spans[0].metadata as Dictionary).get("variable_badge", false)), true) and ok
	ok = _check("the scope word is plain text, never a pill",
		bool((row.spans[1].metadata as Dictionary).get("badge", false)), false) and ok
	ok = _check("the type word is plain text too",
		bool((row.spans[2].metadata as Dictionary).get("badge", false)), false) and ok
	ok = _check("the name keeps the declaration grammar on its hover",
		str((row.spans[3].metadata as Dictionary).get("hover_note", "")), "speed : float") and ok
	ok = _check("the Inspector mark says what it means",
		str((row.spans[4].metadata as Dictionary).get("hover_note", "")), "Editable in the Inspector") and ok
	ok = _check("and it is a mark, not the word Inspector",
		bool((row.spans[4].metadata as Dictionary).get("inspector_badge", false)), true) and ok
	view.free()
	return ok


## V13 - the dial decides what the row carries: the sentence alone, the sentence with its echo, or
## the declaration as the whole row.
static func _test_the_view_dial_decides_what_the_row_carries() -> bool:
	var ok: bool = true
	var view := EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.variables = {"hp": {"type": "int", "default": 100, "exported": false}}
	view.variable_row_view = EventSheetCodeEcho.VIEW_SENTENCE
	ok = _check("sentence: nothing on the row is spelled the GDScript way",
		_texts(view._build_global_variable_rows(sheet)[0]), "x | Instance | whole number | hp | = | 100") and ok
	view.variable_row_view = EventSheetCodeEcho.VIEW_BOTH
	ok = _check("both: the sentence leads and the declaration echoes",
		_texts(view._build_global_variable_rows(sheet)[0]),
		"x | Instance | whole number | hp | = | 100 | var hp: int = 100") and ok
	view.variable_row_view = EventSheetCodeEcho.VIEW_CODE
	ok = _check("code: the row IS the line, and keeps its badge",
		_texts(view._build_global_variable_rows(sheet)[0]), "x | var hp: int = 100") and ok
	view.free()
	return ok


## V1 - an Inspector group is the one thing in the list that folds: a slim strip naming the folder
## over rows that are NOT pushed sideways by it.
static func _test_an_inspector_group_is_a_folder_strip_over_unindented_rows() -> bool:
	var ok: bool = true
	var view := EventSheetViewport.new()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.variables = {
		"hp": {"type": "int", "default": 100, "exported": false},
		"speed": {"type": "float", "default": 200.0, "exported": true, "attributes": {"group": "Movement"}},
		"jump": {"type": "float", "default": 400.0, "exported": true, "attributes": {"group": "Movement"}},
	}
	var rows: Array = view._build_global_variable_rows(sheet)
	ok = _check("the group is one strip, not a chip on every row", rows.size(), 2) and ok
	var strip: EventRowData = rows[1]
	ok = _check("the strip is named for the folder", _texts(strip), "Movement") and ok
	ok = _check("the strip owns the rows, so the folder folds", strip.children.size(), 2) and ok
	ok = _check("and the rows inside are not indented", strip.children[0].indent, 0) and ok
	ok = _check("no row wears a group pill any more",
		_texts(strip.children[0]).contains("Movement"), false) and ok
	view.free()
	return ok


## V12 - the type word is the guide rail on the value the row lets you edit in place.
static func _test_a_literal_that_does_not_fit_its_type_is_refused() -> bool:
	var ok: bool = true
	ok = _check("a whole number refuses a fraction",
		EventSheetVariableSentence.value_fits("int", "1.5"), false) and ok
	ok = _check("and takes a whole one", EventSheetVariableSentence.value_fits("int", "12"), true) and ok
	ok = _check("a number takes a fraction", EventSheetVariableSentence.value_fits("float", "1.5"), true) and ok
	ok = _check("a boolean takes only true or false",
		EventSheetVariableSentence.value_fits("bool", "yes"), false) and ok
	ok = _check("text takes whatever you type",
		EventSheetVariableSentence.value_fits("String", "anything"), true) and ok
	return ok


## The line rebuilt from its runs - a tokeniser that drops or duplicates a character is a tokeniser
## that draws the wrong line.
static func _rejoined(line: String) -> String:
	var text: String = ""
	for run: Dictionary in EventSheetCodeEcho.tokens(line):
		text += str(run.get("text", ""))
	return text


## The token class the run whose text is exactly `piece` was given, "" when no run is that piece.
static func _token_of(line: String, piece: String) -> String:
	for run: Dictionary in EventSheetCodeEcho.tokens(line):
		if str(run.get("text", "")) == piece:
			return str(run.get("token", ""))
	return ""


## Every span's text, in order - the row as one readable line.
static func _texts(row_data: EventRowData) -> String:
	if row_data == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		parts.append(str(span.text))
	return " | ".join(parts)


## The name a variable row is about, from its metadata (never its span order).
static func _name_of(row_data: EventRowData) -> String:
	if row_data == null or row_data.spans.is_empty():
		return ""
	var metadata: Dictionary = row_data.spans[0].metadata if row_data.spans[0].metadata is Dictionary else {}
	return str(metadata.get("variable_name", ""))


## The scope word drawn on the row named `var_name`, "" when no such row exists.
static func _scope_word(rows: Array, var_name: String) -> String:
	for entry: Variant in rows:
		var row_data: EventRowData = entry as EventRowData
		if row_data == null or _name_of(row_data) != var_name:
			continue
		for span: SemanticSpan in row_data.spans:
			var metadata: Dictionary = span.metadata if span.metadata is Dictionary else {}
			if bool(metadata.get("variable_scope_span", false)):
				return str(span.text)
	return ""


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] variable_row_sentence_test: %s" % label)
		return true
	print("[FAIL] variable_row_sentence_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
