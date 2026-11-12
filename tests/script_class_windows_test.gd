@tool
extends RefCounted
# Godot EventSheets - making a script class and changing it. Insert new object picks what the class
# is from tiles or the class tree, refuses a name it cannot write and writes the head the compiler
# would.


const SUPPORT := preload("res://tests/support.gd")
const NAME := "script_class_windows_test"
const INSERT_PATH := "res://addons/eventsheet/editor/dock/insert_object_dialog.gd"


static func run() -> bool:
	return _test_insert_rules() and _test_insert_window()


static func _test_insert_rules() -> bool:
	var insert: Script = load(INSERT_PATH)
	var tree: Array = insert.tree_rows(PackedStringArray(["CharacterBody2D", "Area2D"]))
	# Insert writes Godot's own Recent list the way Create New Node does: newest first, once each.
	var lists: String = "user://script_class_lists_%d" % OS.get_process_id()
	DirAccess.make_dir_recursive_absolute(lists)
	FileAccess.open(lists.path_join("create_recent.Node"), FileAccess.WRITE).store_string("Sprite2D\nArea2D\nMyHandMadeClass\n")
	insert.remember_recent("Area2D", lists)
	insert.remember_recent("Resource", lists)
	var recent_file: String = FileAccess.get_file_as_string(lists.path_join("create_recent.Node"))
	var recent_read: PackedStringArray = insert.godot_class_list("create_recent", lists)
	var nodes: PackedStringArray = ClassDB.get_inheriters_from_class("Node2D")
	nodes.sort()
	var every_line: Dictionary = {"Sprite2D": true, "Area2D": true, "MyHandMadeClass": true}
	for class_id: String in nodes.slice(0, 40):
		insert.remember_recent(class_id, lists)
		every_line[class_id] = true
	var recent_kept: int = FileAccess.get_file_as_string(lists.path_join("create_recent.Node")).split("\n", false).size()
	DirAccess.remove_absolute(lists.path_join("create_recent.Node"))
	DirAccess.remove_absolute(lists)
	return SUPPORT.pins(NAME, [
		["Insert puts its class first in Godot's Recent list, keeping the rest as written", recent_file, "Area2D\nSprite2D\nMyHandMadeClass\n"],
		["...and the window reads it back first", recent_read, PackedStringArray(["Area2D", "Sprite2D"])],
		["Insert never shortens the Recent list Godot wrote", recent_kept, every_line.size()],
		["an empty name asks for one", insert.name_problem("", "res://tests/"), "Name it to insert it."],
		["a name code cannot write is refused", insert.name_problem("2fast", "res://tests/"), "\"2fast\" cannot be a class name."],
		["a class Godot has is refused", insert.name_problem("Node2D", "res://tests/"), "\"Node2D\" is already the name of another class."],
		["a file already in the folder is refused", insert.name_problem("Support", "res://tests/"), "support.gd is already in this folder."],
		["a free name passes", insert.name_problem("ScriptClassProbe", "res://tests/"), ""],
		["the file is the name in snake_case", insert.file_name_for("PlayerCombat"), "player_combat.gd"],
		["the head is what the compiler writes", insert.file_head("CharacterBody2D", "Player", true),
			"@tool\nclass_name Player\nextends CharacterBody2D"],
		["an editor tool always runs in the editor", insert.file_head("EditorScript", "Cleaner", false),
			"@tool\nclass_name Cleaner\nextends EditorScript"],
		["the class tree climbs to Node and greys what nothing is made of", tree, [
			["Node", 0, true], ["CanvasItem", 1, false], ["Node2D", 2, true], ["CollisionObject2D", 3, false],
			["Area2D", 4, true], ["PhysicsBody2D", 4, false], ["CharacterBody2D", 5, true]]],
		["a tile's words", insert.words_for("Area2D"), ["Area", "Detects what enters or leaves it: pickups, triggers, hit boxes."]],
	])


static func _test_insert_window() -> bool:
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	var window: RefCounted = load(INSERT_PATH).new()
	var dialog: ConfirmationDialog = window.open(dock, "res://tests/")
	var tile_groups: int = 0
	var undescribed: int = 0
	for child: Node in window._grid_box.get_children():
		if child is ItemList:
			tile_groups += 1
			for index: int in (child as ItemList).item_count:
				if (child as ItemList).get_item_tooltip(index).is_empty():
					undescribed += 1
	var opened_with: Array = [window._name_edit.text, dialog.get_ok_button().disabled]
	var first_sentence: String = window._chosen_label.text
	window._name_edit.text = "ScriptClassProbe"
	window._refresh()
	var named_allows: bool = not dialog.get_ok_button().disabled
	window._choose("EditorScript")
	var forced: Array = [window._tool_check.button_pressed, window._tool_check.disabled]
	window._search.text = "Area"
	window._fill()
	var found: PackedStringArray = PackedStringArray()
	for child: Node in window._grid_box.get_children():
		if child is ItemList:
			for index: int in (child as ItemList).item_count:
				found.append(str((child as ItemList).get_item_metadata(index)))
	var ok: bool = SUPPORT.pins(NAME, [
		["four groups of tiles", tile_groups, 4],
		["every tile says what it is", undescribed, 0],
		["the chosen kind's sentence is on screen", first_sentence,
			"Character - A body you move with code: players and enemies that walk, jump and collide."],
		["it opens with a free name filled in, so Insert is ready", opened_with,
			["Player", false]],
		["a name the folder already uses is not the one offered", load(INSERT_PATH).free_name("Support", "res://tests/"), "Support2"],
		["a free name lets Insert go", named_allows, true],
		["an editor tool's switch is on and fixed", forced, [true, true]],
		["the footer names the file and folder", window._target_label.text, "Creates script_class_probe.gd in res://tests/ and opens it."],
		["search keeps the matching tiles first", found.slice(0, 2), PackedStringArray(["Area2D", "Area3D"])],
	])
	dock.free()
	return ok
