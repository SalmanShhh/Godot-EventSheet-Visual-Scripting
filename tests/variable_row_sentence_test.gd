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
	ok = _test_a_sheet_variables_echo_is_a_line_of_the_compiled_file() and ok
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
	ok = _test_f2_renames_the_name_in_place() and ok
	ok = _test_a_dropped_row_writes_what_a_field_needs() and ok
	return ok


## V8. F2 (and a double-click on the name) opens the NAME as a field, with the count of what
## committing will rewrite beside it. The row's default edit is untouched: Enter still means "edit
## the value", which is what `edit_gesture` on the name keeps true.
static func _test_f2_renames_the_name_in_place() -> bool:
	var ok: bool = true
	# The line the field shows, out of what the project walk found. Pure, so it is pinned first.
	ok = _check("one use in one sheet reads singular",
		EventSheetFindReferences.inline_rename_note([{"sheet": "a.gd", "count": 1}]),
		"renames 1 use in 1 sheet · Enter to apply · Esc") and ok
	ok = _check("and several read plural",
		EventSheetFindReferences.inline_rename_note([{"sheet": "a.gd", "count": 6}, {"sheet": "b.gd", "count": 2}]),
		"renames 8 uses in 2 sheets · Enter to apply · Esc") and ok
	ok = _check("a name nothing uses yet says so rather than counting to zero",
		EventSheetFindReferences.inline_rename_note([]),
		"used nowhere yet · Enter to apply · Esc") and ok

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.variables = {"hp": {"type": "int", "default": 100, "exported": false}}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetVar"
	action.codegen_template = "{var_name} = {value}"
	action.params = {"var_name": "hp", "value": "50"}
	event.actions.append(action)
	sheet.events.append(event)
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()
	# …and the menu says which key does the same thing, read off the shortcut table so a rebound
	# key hints as the key it was rebound to.
	ok = _check("the row menu names the rename key",
		_menu_key(dock._variable_context_menu, dock.VARIABLE_MENU_RENAME), "F2") and ok
	ok = _check("and the Add submenu names the two that have one",
		[_menu_key(dock._add_variable_submenu, dock.EMPTY_MENU_ADD_VARIABLE),
			_menu_key(dock._add_variable_submenu, dock.EMPTY_MENU_ADD_INSTANCE_VARIABLE),
			_menu_key(dock._add_variable_submenu, dock.EMPTY_MENU_ADD_LOCAL_VARIABLE)],
		["V", "Ctrl+Shift+V", ""]) and ok
	var row: EventRowData = _row_named(view, "hp")
	ok = _check("the row is on the canvas", row != null, true)
	if row == null:
		dock.free()
		return false
	var name_span: SemanticSpan = _span_flagged(row, "variable_name_span")
	ok = _check("the name is a field, opened by its own gesture",
		[bool((name_span.metadata as Dictionary).get("editable", false)),
			str((name_span.metadata as Dictionary).get("edit_kind", "")),
			str((name_span.metadata as Dictionary).get("edit_gesture", ""))],
		[true, "variable_rename", "rename"]) and ok
	var row_index: int = _index_of(view, row)
	ok = _check("F2 opens the name, not the value",
		[view.begin_variable_rename(row_index),
			int(view.get_editing_context_for_test().get("span_index", -1))],
		[true, row.spans.find(name_span)]) and ok
	ok = _check("with the buffer on the name it is about",
		str(view.get_editing_context_for_test().get("buffer", "")), "hp") and ok
	ok = _check("and the count of what committing will rewrite beside it",
		view._editing_note.ends_with("Enter to apply · Esc"), true) and ok
	view._cancel_edit()
	# The default edit is unchanged: Enter on the row still reaches the VALUE cell.
	view._selected_row_index = row_index
	view._selected_span_index = -1
	ok = _check("Enter still edits the value",
		[view.begin_edit_selected(),
			str((row.spans[int(view.get_editing_context_for_test().get("span_index", -1))].metadata as Dictionary).get("edit_kind", ""))],
		[true, "variable_value"]) and ok
	view._cancel_edit()
	# Committing the rename is Rename Everywhere: the declaration AND every row that names it.
	view.begin_variable_rename(row_index)
	view._editing_buffer = "health"
	view._commit_edit()
	ok = _check("committing renames the declaration",
		PackedStringArray(dock.get_current_sheet().variables.keys()), PackedStringArray(["health"])) and ok
	ok = _check("and every row that names it",
		_first_action_param(dock.get_current_sheet(), "var_name"), "health") and ok
	dock.free()
	return ok


## V8. A variable row let go on a parameter VALUE writes what that field needs: bare for the object's
## own variable, `Game.Score` for a global, because inside an expression the prefix is real code.
static func _test_a_dropped_row_writes_what_a_field_needs() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "Player"
	sheet.variables = {"hp": {"type": "int", "default": 100, "exported": false}}
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()
	ok = _check("this object's own variable drops bare",
		view.variable_insert_text(_row_named(view, "hp")), "hp") and ok
	ok = _check("and a row that is not a declaration drops nothing at all",
		view.variable_insert_text(EventRowData.new()), "") and ok
	dock.free()
	return ok


## The key a menu item hints, as the reader sees it written; "" when the item names none.
static func _menu_key(menu: PopupMenu, item_id: int) -> String:
	var index: int = menu.get_item_index(item_id)
	if index < 0:
		return "<no item %d>" % item_id
	var shortcut: Shortcut = menu.get_item_shortcut(index)
	return shortcut.get_as_text() if shortcut != null else ""


## One parameter off the first action of the sheet's first event - read from the LIVE sheet, since
## the undo funnel commits by replacing resources with snapshot duplicates.
static func _first_action_param(sheet: EventSheetResource, param_id: String) -> String:
	for entry: Variant in sheet.events:
		if entry is EventRow and not (entry as EventRow).actions.is_empty():
			var params: Variant = (entry as EventRow).actions[0].get("params")
			return str((params as Dictionary).get(param_id, "")) if params is Dictionary else ""
	return ""


## The first span carrying `flag` in its metadata, or null.
static func _span_flagged(row_data: EventRowData, flag: String) -> SemanticSpan:
	for span: SemanticSpan in row_data.spans:
		if span != null and span.metadata is Dictionary and bool((span.metadata as Dictionary).get(flag, false)):
			return span
	return null


## The flat index of a row on the canvas, -1 when it is not drawn.
static func _index_of(view: EventSheetViewport, row_data: EventRowData) -> int:
	var rows: Array[Dictionary] = view.get_flat_rows()
	for index: int in range(rows.size()):
		if rows[index].get("row") == row_data:
			return index
	return -1


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


## The echo on a sheet-level variable is checked against a REAL COMPILE, not against a second
## formatter's idea of the same declaration - a stand-in variable routed through the tree-variable
## emitter disagreed with the compiler about four facts a descriptor can carry, so the row promised a
## line the file does not have. Each of the four is here, and every echo is looked for in the output.
static func _test_a_sheet_variables_echo_is_a_line_of_the_compiled_file() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Player"
	sheet.host_class = "Node2D"
	sheet.variables = {
		"ammo": {"type": "int", "default": 99, "const": true},
		"notes": {"type": "String", "default": "", "attributes": {"multiline": true}},
		"seed_value": {"type": "int", "default": 1, "attributes": {"read_only": true}},
		"hp": {"type": "int", "default": 100, "attributes": {"clamp": true, "range": {"min": 0, "max": 100}}},
	}
	var expected: Dictionary = {
		"ammo": "@export var ammo: int = 99",
		"notes": "@export_multiline var notes: String = \"\"",
		"seed_value": "@export_custom(PROPERTY_HINT_NONE, \"\", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_READ_ONLY) var seed_value: int = 1",
		"hp": "@export_range(0, 100, 1) var hp: int = 100:",
	}
	var output: String = str(SheetCompiler.compile(sheet, "user://eventforge_variable_echo.gd").get("output", ""))
	for var_name: String in expected:
		var echoed: String = EventSheetCodeEcho.line_for_descriptor(var_name, sheet.variables[var_name])
		ok = _check("the echo on %s is the declaration the compiler spells" % var_name,
			echoed, str(expected[var_name])) and ok
		ok = _check("…and that line is in the compiled file", output.contains("\n%s\n" % echoed), true) and ok
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
