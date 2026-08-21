# Godot EventSheets - W6. A menu built in code, read as the menu it is.
#
# Two halves are pinned here, and both of them are VALUES. The first is the words: the add_item run
# reads as ONE bar naming its items in order, and every `match id:` arm reads as the trigger
# `On "Save" chosen` with the number resolved back to the label the user clicks. The second is that
# nothing moved: the reading is display-only, so a file opened and saved untouched reproduces every
# byte - and it is pinned for BOTH spellings a handler is written in, the lambda handed to `connect`
# and the plain function a connect line named, because a reading that only holds for one of them
# would quietly leave half the menus in the world unread.
#
# The authored half is pinned the same way, in the other direction: the picker rows emit exactly the
# lines the reading recognises, and the emitted file re-opens as exactly what it was written from.
@tool
class_name MenuReadingTest
extends RefCounted

## The mockup's own example: a menu built in a run, answered by a lambda, with one arm on an id no
## item ever declared - the branch that can never run.
const LAMBDA_PATH := "user://w6_menu_lambda.gd"
const LAMBDA_SOURCE := """@tool
extends Node

var sheet_popup: PopupMenu = null


func _build_menu() -> void:
	sheet_popup = PopupMenu.new()
	sheet_popup.add_item("New…", 0)
	sheet_popup.add_item("Open…", 1)
	sheet_popup.add_item("Save", 2)
	sheet_popup.add_separator()
	sheet_popup.add_item("Sheet Type…", 4)
	sheet_popup.id_pressed.connect(func(id: int) -> void:
		match id:
			0:
				_new_sheet()
			1:
				_open_sheet_dialog()
			2:
				_save_current_sheet()
			4:
				_open_sheet_type_dialog()
			7:
				_lost_branch())
"""

## The other spelling: a named handler, a tick item, and two items sharing one id - the bug this
## repo shipped three times in one merge, with the second item dead however clearly it is written.
const NAMED_PATH := "user://w6_menu_named.gd"
const NAMED_SOURCE := """@tool
extends Node

var view_menu: PopupMenu = null


func _build_menu() -> void:
	view_menu.add_item("Minimap", 5)
	view_menu.add_check_item("Follow selection", 6)
	view_menu.add_item("Patterns", 5)
	view_menu.id_pressed.connect(_on_view_chosen)


func _on_view_chosen(id: int) -> void:
	match id:
		5:
			_toggle_minimap()
		6:
			_toggle_follow()
"""


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_facts() and all_passed
	all_passed = _test_bar_words() and all_passed
	all_passed = _test_arm_words() and all_passed
	all_passed = _test_opened_files() and all_passed
	all_passed = _test_doctor_notes() and all_passed
	all_passed = _test_authoring() and all_passed
	all_passed = _test_round_trip() and all_passed
	return all_passed


## The one walk: which items went into which menu, and which handler answers it. Both spellings, and
## a file that builds no menu at all, which is every game script.
static func _test_facts() -> bool:
	var passed: bool = true
	var lambda_facts: Dictionary = EventSheetMenuFacts.facts(LAMBDA_SOURCE.split("\n"))
	passed = _check("the menu is keyed by the variable both halves share",
		", ".join(PackedStringArray((lambda_facts.get("menus", {}) as Dictionary).keys())),
		"sheet_popup") and passed
	var named_facts: Dictionary = EventSheetMenuFacts.facts(NAMED_SOURCE.split("\n"))
	passed = _check("a named handler is filed under the menu the connect line gave it",
		EventSheetMenuFacts.handler_menu(named_facts, "_on_view_chosen"), "view_menu") and passed
	passed = _check("a lambda has no name to file, and files none",
		", ".join(PackedStringArray((lambda_facts.get("menu_handlers", {}) as Dictionary).keys())),
		"") and passed
	passed = _check("the connect line names the menu a lambda answers",
		EventSheetMenuFacts.connected_menu_key("\tsheet_popup.id_pressed.connect(func(id: int) -> void:"),
		"sheet_popup") and passed
	passed = _check("a connect to anything else names no menu",
		EventSheetMenuFacts.connected_menu_key("\tbutton.pressed.connect(_on_pressed)"), "") and passed
	passed = _check("a script that builds no menu says nothing at all",
		EventSheetMenuFacts.facts(PackedStringArray([
			"extends Node", "func _ready() -> void:", "\tprint(\"hello\")"
		])).is_empty(), true) and passed
	passed = _check("the menu is named after the variable, without the word that says it is a menu",
		EventSheetMenuFacts.display_name("sheet_popup"), "Sheet") and passed
	passed = _check("a private context menu is named the same way, whole tail and all",
		EventSheetMenuFacts.display_name("_tree_context_menu"), "Tree") and passed
	passed = _check("and a row of it wears the menu as its object",
		EventSheetMenuFacts.object_words("sheet_popup"), "Sheet menu") and passed
	return passed


## The bar the run collapses into: the menu's name, then its items in order - a separator as a dash,
## a check item with its tick, an item whose id was already taken marked as the dead one it is.
static func _test_bar_words() -> bool:
	var passed: bool = true
	var lambda_bar: Dictionary = EventSheetMenuFacts.bar_words(
		EventSheetMenuFacts.menu_of(EventSheetMenuFacts.facts(LAMBDA_SOURCE.split("\n")), "sheet_popup"))
	passed = _check("the bar names the menu", str(lambda_bar.get("text", "")), "Menu Sheet") and passed
	passed = _check("and lists every item in the order the file adds them",
		str(lambda_bar.get("note", "")),
		"sheet popup · items: New… · Open… · Save · ─ · Sheet Type…") and passed
	var named_bar: Dictionary = EventSheetMenuFacts.bar_words(
		EventSheetMenuFacts.menu_of(EventSheetMenuFacts.facts(NAMED_SOURCE.split("\n")), "view_menu"))
	passed = _check("a tick item wears its tick, and a dead item says it is never chosen",
		str(named_bar.get("note", "")),
		"view menu · items: Minimap · ✓ Follow selection · Patterns (never chosen)") and passed
	return passed


## The arms: the id resolved back to the label, and the id nothing declared kept as a number.
static func _test_arm_words() -> bool:
	var passed: bool = true
	var menu: Dictionary = EventSheetMenuFacts.menu_of(
		EventSheetMenuFacts.facts(LAMBDA_SOURCE.split("\n")), "sheet_popup")
	passed = _check("an arm reads as the item it answers",
		str(EventSheetMenuFacts.arm_words(menu, "0").get("text", "")), "On New… chosen") and passed
	passed = _check("an arm past a separator resolves too",
		str(EventSheetMenuFacts.arm_words(menu, "4").get("text", "")), "On Sheet Type… chosen") and passed
	var unknown: Dictionary = EventSheetMenuFacts.arm_words(menu, "7")
	passed = _check("an id no item declared keeps its number",
		str(unknown.get("text", "")), "On item 7 chosen") and passed
	passed = _check("and says it is not a known item, which is what colours it",
		bool(unknown.get("known", true)), false) and passed
	passed = _check("the catch-all arm is not an item and reads as it always did",
		EventSheetMenuFacts.arm_words(menu, "_").is_empty(), true) and passed
	return passed


## The rows a real opened file draws - the half a static reading cannot prove on its own, and the
## one that proves the walk stamp: an arm inside a LAMBDA knows its menu, and so does an arm inside a
## function a connect line named.
static func _test_opened_files() -> bool:
	var passed: bool = true
	_write(LAMBDA_PATH, LAMBDA_SOURCE)
	var lambda_rows: PackedStringArray = _open_and_read(LAMBDA_PATH)
	passed = _check("the add_item run reads as one bar",
		_has(lambda_rows, "Sheet menu ▸ Menu Sheet"), true) and passed
	passed = _check("the bar lists the menu's items",
		_has(lambda_rows, "sheet popup · items: New… · Open… · Save · ─ · Sheet Type…"), true) and passed
	passed = _check("an arm of the lambda reads as the trigger it is",
		_has(lambda_rows, "Sheet menu ▸ On Save chosen"), true) and passed
	passed = _check("the last arm of the lambda reads too - the `)` glued to it closes the connect",
		_has(lambda_rows, "Sheet menu ▸ On Sheet Type… chosen"), true) and passed
	passed = _check("the arm on an id nothing adds still reads, as the number it waits for",
		_has(lambda_rows, "Sheet menu ▸ On item 7 chosen"), true) and passed
	_write(NAMED_PATH, NAMED_SOURCE)
	var named_rows: PackedStringArray = _open_and_read(NAMED_PATH)
	passed = _check("a named handler's arm knows its menu as well as a lambda's does",
		_has(named_rows, "View menu ▸ On Minimap chosen"), true) and passed
	passed = _check("a tick item's arm reads under the same menu",
		_has(named_rows, "View menu ▸ On Follow selection chosen"), true) and passed
	return passed


## What the Doctor says about the two ways a menu goes quietly wrong. Notes, never warnings.
static func _test_doctor_notes() -> bool:
	var passed: bool = true
	var lambda_notes: Array[Dictionary] = EventSheetProjectDoctor.menu_id_notes(LAMBDA_SOURCE.split("\n"))
	passed = _check("the unreachable branch is one note", lambda_notes.size(), 1) and passed
	passed = _check("and it is filed as the unknown-item note",
		str((lambda_notes[0] as Dictionary).get("check", "")), "menu-unknown-item") and passed
	passed = _check("which says which menu and which number",
		str((lambda_notes[0] as Dictionary).get("message", "")),
		"The Sheet menu answers item 7, and nothing ever adds an item with that id. The branch is real code the menu can never reach - either add the item, or move the branch to the id the item it means already has.") and passed
	var named_notes: Array[Dictionary] = EventSheetProjectDoctor.menu_id_notes(NAMED_SOURCE.split("\n"))
	passed = _check("the shared id is one note", named_notes.size(), 1) and passed
	passed = _check("and it names both items, in the order the file adds them",
		str((named_notes[0] as Dictionary).get("message", "")),
		"The View menu adds \"Patterns\" with id 5, which \"Minimap\" already took. Godot sends that one number for both items and the handler answers it once, so \"Patterns\" is dead however clearly it is written. Give it an id of its own.") and passed
	passed = _check("a file with no menu is worth no notes",
		EventSheetProjectDoctor.menu_id_notes(PackedStringArray(["extends Node"])).size(), 0) and passed
	# A separator is not something the menu can send, so it takes no id - and the item that really
	# carries the number a separator happens to sit at is not a duplicate of it.
	passed = _check("a separator does not take the id of the item at its position",
		EventSheetProjectDoctor.menu_id_notes(PackedStringArray([
			"extends Node", "func _build() -> void:",
			"\tfile_menu.add_item(\"New\", 0)",
			"\tfile_menu.add_separator()",
			"\tfile_menu.add_item(\"Quit\", 1)",
			"\tfile_menu.id_pressed.connect(_on_file_chosen)"
		])).size(), 0) and passed
	return passed


## The authored half: the picker rows emit the lines the reading recognises, the menu's items share
## one handler, and the emitted file re-opens as exactly what it was written from.
static func _test_authoring() -> bool:
	var passed: bool = true
	var path: String = "user://w6_menu_authored.gd"
	var sheet: EventSheetResource = _authored_sheet()
	var first: String = str(SheetCompiler.compile(sheet, path).get("output", ""))
	passed = _check("the Add item row writes the line the reading reads",
		first.contains("\tview_menu.add_item(\"Minimap\", 0)"), true) and passed
	passed = _check("every item of one menu shares one handler",
		first.contains("func _on_view_menu_id_pressed(id: int) -> void:\n\tmatch id:\n\t\t0:"), true) and passed
	passed = _check("the second item is a case of that same handler",
		first.contains("\n\t\t1:\n\t\t\tprint(\"Toggle patterns\")"), true) and passed
	passed = _check("the menu is wired through the variable it lives in",
		first.contains("\tview_menu.id_pressed.connect(_on_view_menu_id_pressed)"), true) and passed
	_write(path, first)
	var reopened: EventSheetResource = GDScriptImporter.new().import_external(path)
	passed = _check("the authored menu re-opens as exactly what it was written from",
		str(SheetCompiler.compile(reopened, path).get("output", "")), first) and passed
	var rows: PackedStringArray = _open_and_read(path)
	passed = _check("and the authored file reads back as the menu it is",
		_has(rows, "View menu ▸ On Minimap chosen"), true) and passed
	return passed


## The standing contract: a reading may not move a byte, whichever spelling the menu came in.
static func _test_round_trip() -> bool:
	var passed: bool = true
	for pair: Array in [[LAMBDA_PATH, LAMBDA_SOURCE], [NAMED_PATH, NAMED_SOURCE]]:
		_write(str(pair[0]), str(pair[1]))
		var sheet: EventSheetResource = GDScriptImporter.new().import_external(str(pair[0]))
		passed = _check("%s saves every byte back" % str(pair[0]).get_file(),
			str(SheetCompiler.compile(sheet, str(pair[0])).get("output", "")), str(pair[1])) and passed
	return passed


# ── Helpers ───────────────────────────────────────────────────────────────────────────────────────


## A sheet holding what the picker's two Menu rows put on it: the run that builds the menu, and one
## event per item that answers it.
static func _authored_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "EditorPlugin"
	sheet.tool_mode = true
	var setup: EventRow = EventRow.new()
	setup.trigger_provider_id = "Core"
	setup.trigger_id = "OnPluginEnabled"
	setup.actions.append(_add_item_action("view_menu", "\"Minimap\"", "0"))
	setup.actions.append(_add_item_action("view_menu", "\"Patterns\"", "1"))
	sheet.events.append(setup)
	for pair: Array in [["0", "Toggle minimap"], ["1", "Toggle patterns"]]:
		var chosen: EventRow = EventRow.new()
		chosen.trigger_provider_id = "Core"
		chosen.trigger_id = "OnMenuItemChosen"
		chosen.trigger_params = {"menu": "view_menu", "item": str(pair[0])}
		var body: RawCodeRow = RawCodeRow.new()
		body.code = "print(\"%s\")" % str(pair[1])
		chosen.actions.append(body)
		sheet.events.append(chosen)
	return sheet


static func _add_item_action(menu: String, label: String, id: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "MenuAddItem"
	action.params = {"menu": menu, "label": label, "id": id}
	return action


## Every row's reading in an opened file, as "object ▸ sentence" plus the bare span texts, so a bar's
## note and a trigger's sentence are both findable.
static func _open_and_read(path: String) -> PackedStringArray:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	var view := EventSheetViewport.new()
	view.reading_mode = true
	view.set_sheet(sheet)
	var readings: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _walk(view._root_rows, view):
		for span: SemanticSpan in row_data.spans:
			var object_label: String = str(span.metadata.get("object_label", ""))
			var text: String = span.text.strip_edges()
			readings.append("%s ▸ %s" % [object_label, text] if not object_label.is_empty() else text)
	view.free()
	return readings


static func _walk(rows: Array, view: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		view._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, view))
	return found


static func _has(readings: PackedStringArray, wanted: String) -> bool:
	for reading: String in readings:
		if reading == wanted:
			return true
	return false


static func _write(path: String, source: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(source)
		file.close()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] menu reading: %s" % label)
		return true
	print("[FAIL] menu reading: %s\n  expected: %s\n  actual:   %s" % [label, str(expected), str(actual)])
	return false
