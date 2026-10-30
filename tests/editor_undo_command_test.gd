# Godot EventSheets - the sheet's Undo and Redo are the editor's own
#
# Inside the editor, EditorUndoRedoManager keeps its own stacks of steps beside the UndoRedo of each
# history, and only its own Undo (Scene > Undo) moves a step between them, tells the History panel and
# lets Scene > Redo find it again. Running a history's UndoRedo by hand skipped all of that, so the
# sheet's Ctrl+Z and the editor's Undo fell out of step. The sheet therefore activates the editor's
# menu item, found by the shortcut the editor gave it. Pinned here as values:
#   1. The item is found by its shortcut, in a menu below the root, and not by its words.
#   2. Looking in one known menu finds it there, and a menu without it answers nothing.
#   3. Outside the editor there is no such item, so the adapter says so and falls back.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "editor_undo_command_test"


static func run() -> bool:
	var undo_shortcut: Shortcut = Shortcut.new()
	var other_shortcut: Shortcut = Shortcut.new()
	var root: Control = Control.new()
	var holder: Control = Control.new()
	root.add_child(holder)
	var words_menu: PopupMenu = PopupMenu.new()
	words_menu.add_item("Undo", 2)
	holder.add_child(words_menu)
	var scene_menu: PopupMenu = PopupMenu.new()
	scene_menu.add_item("New Scene", 0)
	scene_menu.add_item("Save Scene", 1)
	scene_menu.add_shortcut(undo_shortcut, 13)
	scene_menu.set_item_text(2, "Undo")
	scene_menu.add_shortcut(other_shortcut, 14)
	holder.add_child(scene_menu)
	var found: Array = EventSheetUndoRedoAdapter.editor_menu_item(root, undo_shortcut)
	var in_known: Array = EventSheetUndoRedoAdapter.editor_menu_item(scene_menu, undo_shortcut, true)
	var not_in_words: Array = EventSheetUndoRedoAdapter.editor_menu_item(words_menu, undo_shortcut, true)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["found by its shortcut, below the root",
			[found[0] == scene_menu, found[1]] if found.size() == 2 else found, [true, 2]],
		["its id is the editor's", scene_menu.get_item_id(int(found[1])) if found.size() == 2 else -1, 13],
		["found in the one known menu",
			[in_known[0] == scene_menu, in_known[1]] if in_known.size() == 2 else in_known, [true, 2]],
		["a menu with the words but not the shortcut answers nothing", not_in_words, []],
		["no shortcut answers nothing", EventSheetUndoRedoAdapter.editor_menu_item(root, null), []],
		["outside the editor there is no item to ask",
			EventSheetUndoRedoAdapter.editor_command_state("ui_undo"), -1],
		["so the command is not run", EventSheetUndoRedoAdapter.run_editor_command("ui_undo"), false],
	])
	root.free()
	return ok
