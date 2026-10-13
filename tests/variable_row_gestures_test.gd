# Godot EventSheets - what a variable row offers besides its window, pinned as the code each gesture
# writes and the words the help strip says:
#   1. Group by prefix proposes the start the names share and writes ONE prefix group above the first.
#   2. End group here writes `@export_group("")` above the member; dragging the end line moves it.
#   3. Move into a group, and an Inspector look picked from the submenu, land on the member.
#   4. The help strip says the member's type, value, Inspector state and group, with its doors.
#   5. Add > Inspector button writes the button and the function it runs.
#   6. The Ghost Row reads "max_jumps is a whole number from 1 to 3, in the Inspector".
#   7. The variable window searches its types, and fills node and resource slots (Pick, Load, New).
# Each written file is opened again and saved again, byte for byte.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "variable_row_gestures_test"
const GESTURES := preload("res://addons/eventsheet/editor/dock/variable_gestures.gd")
const RECIPES := preload("res://addons/eventsheet/editor/dock/ghost_recipes.gd")
const SECTIONS := preload("res://addons/eventsheet/editor/interaction/export_sections.gd")
const PROBE := "user://eventsheet_variable_gestures_probe.gd"
const BULLETS := "extends Node\n\n@export var bullet_count = 3\n@export var bullet_speed = 10.0\n@export var health = 10\n"
const GUN := "extends Node\n\n@export_group(\"Gun\")\n@export var damage = 3\n@export var reload_time = 1.5\n@export var spread = 2.0\n"


static func run() -> bool:
	var ok: bool = _groups()
	ok = _strip() and ok
	ok = _dock_gestures() and ok
	ok = _ghost_sentence() and ok
	ok = _window() and ok
	return ok


static func _groups() -> bool:
	var rows: Array = [
		["two names share their start", SECTIONS.shared_start(PackedStringArray(["bullet_count", "bullet_speed"])), "bullet"],
		["one name is its own start", SECTIONS.shared_start(PackedStringArray(["health"])), "health"],
		["names that share nothing", SECTIONS.shared_start(PackedStringArray(["health", "damage"])), ""],
	]
	var sheet: EventSheetResource = _opened(BULLETS)
	GESTURES.group_by_prefix(sheet, PackedStringArray(["bullet_speed", "bullet_count"]), "Bullet", "bullet")
	rows.append(["group by prefix writes one prefix group above the first", _members(sheet),
		"@export_group(\"Bullet\", \"bullet\")\n@export var bullet_count = 3\n@export var bullet_speed = 10.0\n@export var health = 10"])
	rows.append(["...and the file it writes reopens and saves byte for byte", _resaved(sheet), _emitted(sheet)])
	GESTURES.move_into_group(sheet, "health", "Bullet")
	rows.append(["move into a group writes the group's line above it", _members(sheet).get_slice("\n", 3) + "\n" + _members(sheet).get_slice("\n", 4),
		"@export_group(\"Bullet\")\n@export var health = 10"])
	sheet = _opened(GUN)
	var reload_row: EventRowData = _member_row(sheet, "reload_time", "Gun")
	rows.append(["End group here is offered inside a group", GESTURES.can_end_group_here(reload_row, sheet), true])
	GESTURES.end_group_here(sheet, "reload_time")
	rows.append(["End group here writes the end above the member", _members(sheet),
		"@export_group(\"Gun\")\n@export var damage = 3\n@export_group(\"\")\n@export var reload_time = 1.5\n@export var spread = 2.0"])
	rows.append(["...and is not offered twice", GESTURES.can_end_group_here(reload_row, sheet), false])
	rows.append(["...nor on the member that opens the group", GESTURES.can_end_group_here(_member_row(sheet, "damage", "Gun"), sheet), false])
	rows.append(["the end reopens and saves byte for byte", _resaved(sheet), _emitted(sheet)])
	GESTURES.set_look(sheet, "spread", "storage")
	rows.append(["a look from the submenu lands on the member", _members(sheet).get_slice("\n", 4), "@export_storage var spread = 2.0"])
	return SUPPORT.pins(P, rows)


## The help strip under a selected member, read off the rows the sheet really draws.
static func _strip() -> bool:
	var sheet: EventSheetResource = _opened("extends Node\n\n@export_group(\"Bullet\", \"bullet\")\n@export var bullet_count = 3\n"
		+ "@export var health = 10\n@export_range(1, 3, 1) var max_jumps: int = 2\nvar _cooldown: float = 0.0\n")
	var view: EventSheetViewport = EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.set_sheet(sheet)
	var said: Dictionary = {}
	for entry: Dictionary in view.get_flat_rows():
		_collect_strips(entry.get("row") as EventRowData, sheet, said)
	view.free()
	return SUPPORT.pins(P, [
		["a member a prefix group shuts out says why, and offers the move",
			said.get("health"), ["int health = 10 · in the Inspector · not in a group  Not in Bullet: that group only takes names starting bullet.", ["move", "properties"]]],
		["a member in a group with a slider offers its look and its range",
			said.get("bullet_count"), ["int bullet_count = 3 · in the Inspector · in group Bullet", ["look", "properties"]]],
		["a slider says its range",
			said.get("max_jumps"), ["int max_jumps = 2 · in the Inspector · not in a group  A slider from 1 to 3 in the Inspector.", ["move", "range", "properties"]]],
		["a private member is not in the Inspector", said.get("_cooldown"), ["float _cooldown = 0.0 · not in the Inspector", ["properties"]]],
		["the doors read as the board names them", [GESTURES.link_label("move"), GESTURES.link_label("look"), GESTURES.link_label("range"), GESTURES.link_label("properties")],
			["Move into a group…", "Change look…", "Edit range…", "Properties…"]],
	])


static func _collect_strips(row: EventRowData, sheet: EventSheetResource, into: Dictionary) -> void:
	if row == null:
		return
	if row.source_resource is LocalVariable:
		var strip: Dictionary = GESTURES.strip_for(row, sheet)
		if not strip.is_empty():
			into[(row.source_resource as LocalVariable).name] = [strip["text"], Array(strip["links"])]
	for child: EventRowData in row.children:
		_collect_strips(child, sheet, into)


## The gestures that go through the dock: the end line dropped on another member, the Inspector
## button, and the Ghost Row's variable - each one undo step.
static func _dock_gestures() -> bool:
	var rows: Array = []
	var sheet: EventSheetResource = _opened(GUN)
	GESTURES.end_group_here(sheet, "reload_time")
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var end_line: EventRowData = EventRowData.new()
	end_line.spans.append(SemanticSpan.new())
	end_line.spans[0].metadata = {"kind": "variable", "variable_name": "", "group_end_owner": "reload_time"}
	var target: EventRowData = EventRowData.new()
	target.source_resource = GESTURES.member(dock._current_sheet, "spread")
	dock._on_row_drop_requested(end_line, target, "before")
	rows.append(["the end line dropped on a member moves the end above it", _members(dock._current_sheet),
		"@export_group(\"Gun\")\n@export var damage = 3\n@export var reload_time = 1.5\n@export_group(\"\")\n@export var spread = 2.0"])
	dock._current_sheet.tool_mode = true
	dock._variable_gestures.add_inspector_button("Bake", "Bake", "", "Tool buttons")
	var emitted: String = _emitted(dock._current_sheet)
	rows.append(["Add > Inspector button writes the group and the button", emitted.substr(emitted.find("@export_group(\"Tool")).get_slice("\n", 0)
		+ "\n" + emitted.substr(emitted.find("@export_group(\"Tool")).get_slice("\n", 1),
		"@export_group(\"Tool buttons\")\n@export_tool_button(\"Bake\", \"Bake\") var bake_button = _bake"])
	rows.append(["...and the function it runs", emitted.contains("func _bake() -> void:"), true])
	rows.append(["the button's prompt shows the same code", GESTURES.inspector_button_code("Bake", "Bake", "_bake", "Tool buttons", false),
		"@export_group(\"Tool buttons\")\n@export_tool_button(\"Bake\", \"Bake\") var bake_button = _bake"])
	rows.append(["the button reopens and saves byte for byte", _resaved(dock._current_sheet), emitted])
	dock._ghost_row.apply_variable(RECIPES.variable_offer_for("max_jumps is a whole number from 1 to 3, in the Inspector"))
	rows.append(["the Ghost Row's sentence declares the variable",
		_emitted(dock._current_sheet).contains("@export_range(1, 3, 1) var max_jumps: int = 1"), true])
	rows.append(["...but never a second of the same name",
		dock._ghost_row.apply_variable(RECIPES.variable_offer_for("max_jumps is a whole number")), false])
	dock.free()
	return SUPPORT.pins(P, rows)


static func _ghost_sentence() -> bool:
	var rows: Array = []
	for case: Array in [
		["max_jumps is a whole number from 1 to 3, in the Inspector", {"variable": "max_jumps", "type": "int", "min": "1", "max": "3", "exported": true, "storage": false, "group": ""}],
		["bullet_speed is a number with decimals, in group Bullet", {"variable": "bullet_speed", "type": "float", "min": "", "max": "", "exported": true, "storage": false, "group": "Bullet"}],
		["_baked is text, saved but hidden", {"variable": "_baked", "type": "String", "min": "", "max": "", "exported": true, "storage": true, "group": ""}],
		["heal 5", {}],
		["hp is a whole number, quickly", {}],
		["name is text from 1 to 3", {}],
	]:
		rows.append(["the sentence \"%s\"" % case[0], RECIPES.variable_offer_for(str(case[0])), case[1]])
	var made: LocalVariable = RECIPES.variable_for(RECIPES.variable_offer_for("_baked is text, saved but hidden"))
	rows.append(["saved but hidden compiles to @export_storage", SheetCompiler._emit_tree_variable_line(made), "@export_storage var _baked: String = \"\""])
	rows.append(["the Ghost Row says what it adds",
		RECIPES.variable_label_for(RECIPES.variable_offer_for("max_jumps is a whole number from 1 to 3, in the Inspector")),
		"⊕  int max_jumps · in the Inspector · a slider from 1 to 3"])
	return SUPPORT.pins(P, rows)


static func _window() -> bool:
	var host: Node = Node.new()
	var dialog: VariableDialog = VariableDialog.new()
	dialog.init_dialog(host)
	dialog.set_sheet_provider(func() -> Variant: return null)
	var rows: Array = []
	dialog.open_for_edit("tree", {}, "muzzle", "Node2D", "", false, "Add", false, false)
	var found: Array = dialog.type_search_entries("area2").map(func(entry: Dictionary) -> String: return str(entry["text"]))
	rows.append(["Search types finds a node class", found.has("Area2D · A node in the scene"), true])
	rows.append(["...and the list's own types by their words", dialog.type_search_entries("whole").map(
		func(entry: Dictionary) -> String: return str(entry["text"])).slice(0, 2), ["int · Whole number", "Vector2i · Whole X and Y"]])
	dialog.pick_type("Area2D")
	rows.append(["picking a class puts the slot on it", [dialog._selected_stored_type(), dialog._class_edit.text], ["Area2D", "Area2D"]])
	rows.append(["a node slot among the events offers Pick", _slot_buttons(dialog), [true, false, false]])
	dialog._on_node_picked(NodePath("Muzzle"))
	rows.append(["a picked node is looked up when the node is ready", [dialog._onready_check.button_pressed, dialog._value_text()], [true, "$Muzzle"]])
	dialog._on_node_picked(NodePath("UI/Score Label"))
	rows.append(["a path with a space is written as get_node", dialog._value_text(), "get_node(\"UI/Score Label\")"])
	dialog.open_for_edit("tree", {}, "falloff", "Curve", "", false, "Add", false, true)
	rows.append(["a resource slot offers Load and New", _slot_buttons(dialog), [false, true, true]])
	dialog._on_resource_loaded("res://data/falloff.tres")
	rows.append(["a loaded file is preloaded", dialog._value_text(), "preload(\"res://data/falloff.tres\")"])
	dialog._on_resource_created("Curve")
	rows.append(["a new one is made", dialog._value_text(), "Curve.new()"])
	dialog.open_for_edit("tree", {}, "max_jumps", "int", "2", false, "Add", false, true)
	var focused: Control = dialog.focus_part("details", "slider")
	rows.append(["Edit range opens on the slider's first detail", [dialog._selected_look_id(), focused is LineEdit], ["slider", true]])
	host.free()
	return SUPPORT.pins(P, rows)


static func _slot_buttons(dialog: VariableDialog) -> Array:
	return dialog._slot_buttons.get_children().map(func(button: Node) -> bool: return (button as Control).visible)


## A member row as the sheet stamps it: its name, and the group the walk put it in.
static func _member_row(sheet: EventSheetResource, var_name: String, group: String) -> EventRowData:
	var row: EventRowData = EventRowData.new()
	row.source_resource = GESTURES.member(sheet, var_name)
	row.spans.append(SemanticSpan.new())
	row.spans[0].metadata = {"kind": "variable", "variable_scope": "tree", "variable_name": var_name, "variable_group": group}
	return row


static func _opened(source: String) -> EventSheetResource:
	var file: FileAccess = FileAccess.open(PROBE, FileAccess.WRITE)
	file.store_string(source)
	file.close()
	return GDScriptImporter.new().import_external(PROBE)


static func _emitted(sheet: EventSheetResource) -> String:
	return str(SheetCompiler.compile(sheet, PROBE).get("output", ""))


## The member lines of the file a sheet writes, from the first annotation on.
static func _members(sheet: EventSheetResource) -> String:
	var emitted: String = _emitted(sheet)
	return emitted.substr(emitted.find("@export")).strip_edges()


## The file a sheet writes, opened again and saved again.
static func _resaved(sheet: EventSheetResource) -> String:
	return _emitted(_opened(_emitted(sheet)))
