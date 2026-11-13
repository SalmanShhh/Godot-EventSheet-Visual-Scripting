# Godot EventSheets - the New behaviour form, and the rows of a global it edits.
#
# The forms ask the familiar questions as described dropdowns, keep the chosen choice's sentence in
# view, say a name problem while it is typed, and only offer copies that fit (packs made for the same
# kind of object). A global's row in Godot's own Project Settings > Globals > Autoload is what the
# settings form changes; making a new global is Godot's own door.
@tool
class_name NewAddonPanelTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true
	var host: Control = Control.new()
	var panel: EventSheetNewAddonPanel = EventSheetNewAddonPanel.new()
	panel.init(host)
	panel.open()
	ok = _check("a behaviour form asks what it works on, CharacterBody2D first offered",
		panel._kind_option.get_item_text(panel._kind_option.selected), "CharacterBody2D") and ok
	ok = _check("and keeps that choice's sentence in view under it",
		(panel._kind_option.get_parent().get_child(1) as Label).text,
		"A 2D character moved by code: it gets velocity and move_and_slide(), the usual choice for walking, patrolling, jumping.") and ok
	ok = _check("an empty name says nothing yet", panel._name_note.text, "") and ok
	panel._name_edit.text = "Node"
	panel._name_edit.text_changed.emit("Node")
	ok = _check("a clashing name is said as it is typed", panel._name_note.text,
		"\"Node\" can't be a name here - use letters, digits and underscores, starting with a letter, and not the name of a class that already exists.") and ok
	panel._name_edit.text = "FreshlyNamedThing"
	panel._name_edit.text_changed.emit("FreshlyNamedThing")
	ok = _check("a usable name clears it", panel._name_note.visible, false) and ok
	ok = _check("the line under the form says what Create makes", panel._path_label.text,
		"Makes res://eventsheet_addons/freshly_named_thing/freshly_named_thing.gd and opens it as a sheet.") and ok
	var starts: Array = _items(panel._start_option)
	ok = SUPPORT.pins("new_addon_panel_test", [
		["starts with Empty", starts[0], "Empty"],
		["offers copies of the packs made for a CharacterBody2D", starts.has("Copy of Platformer Movement"), true],
		["and none made for another kind", starts.has("Copy of Bullet"), false],
		["ends with the two ways from your own script", starts.slice(-2), ["From a script I wrote", "From the selected node"]],
	]) and ok
	panel._kind_option.select(1)
	panel._kind_option.item_selected.emit(1)
	ok = _check("changing what it works on changes the copies", _items(panel._start_option).has("Copy of Bullet"), true) and ok
	ok = SUPPORT.pins("new_addon_panel_test", [
		["a behaviour's category leads with its own name, which a project with no packs still has",
			panel._shelf_option.get_item_text(0), "Its own name"],
		["and it stays the chosen one whatever pack the copies list starts with",
			[panel._shelf_option.selected, panel._shelf_option.get_item_metadata(panel._shelf_option.selected)], [0, ""]],
		["a pack shelf names the packs already on it", panel._shelf_option.get_item_tooltip(1).begins_with("Listed with "), true],
	]) and ok

	ProjectSettings.set_setting("autoload/ZzPanelGlobal", "*res://zz_panel_global.gd")
	ok = _check("a global cannot take an autoload's name", EventSheetNewAddonPanel.name_problem("ZzPanelGlobal", true),
		"Project Settings > Globals already has an autoload called ZzPanelGlobal - pick another name.") and ok
	ProjectSettings.set_setting("autoload/ZzPanelGlobal", null)

	# Turning a global on and off is its row in Project Settings > Globals > Autoload.
	EventSheetNewAddonPanel.set_global_row("ZzPanelGlobal", "res://zz_panel_global.gd")
	ok = _check("on writes the autoload row", ProjectSettings.get_setting("autoload/ZzPanelGlobal", ""), "*res://zz_panel_global.gd") and ok
	EventSheetNewAddonPanel.set_global_row("ZzPanelGlobal", "")
	ok = _check("off removes it", ProjectSettings.has_setting("autoload/ZzPanelGlobal"), false) and ok
	# An existing project's autoload scene lives anywhere, under any name: its root node's script is
	# the global.
	var scene_path: String = "user://zz_panel_world_scene.tscn"
	var scene_file: FileAccess = FileAccess.open(scene_path, FileAccess.WRITE)
	scene_file.store_string("[gd_scene load_steps=2 format=3]\n\n"
		+ "[ext_resource type=\"Texture2D\" path=\"res://icon.svg\" id=\"2_tex\"]\n"
		+ "[ext_resource type=\"Script\" uid=\"uid://zzpanel\" path=\"res://zz_panel_state.gd\" id=\"1_state\"]\n\n"
		+ "[node name=\"World\" type=\"Node\"]\nscript = ExtResource(\"1_state\")\n\n"
		+ "[node name=\"Child\" type=\"Node\" parent=\".\"]\nscript = ExtResource(\"2_tex\")\n")
	scene_file.close()
	ProjectSettings.set_setting("autoload/ZzPanelWorld", "*" + scene_path)
	ok = SUPPORT.pins("new_addon_panel_test", [
		["a scene autoload names its root node's script", EventSheetACEGenerator.scene_root_script(scene_path), "res://zz_panel_state.gd"],
		["and the picker's generator agrees", EventSheetACEGenerator.autoload_name_for_path("res://zz_panel_state.gd"), "ZzPanelWorld"],
	]) and ok
	ProjectSettings.set_setting("autoload/ZzPanelWorld", null)
	DirAccess.remove_absolute(scene_path)
	# The Behaviour library lists the packs a project lacks, each as a row: its name, the kind of
	# node it works on and what it is, and what else comes with it. The kind a pack works on is read
	# from its own source: the typed host, else what it requires, else any node.
	var bullet: Dictionary = EventSheetPackCatalog.describe("bullet")
	var window: EventSheetBehaviourLibraryWindow = EventSheetBehaviourLibraryWindow.new()
	var mine: Dictionary = {"name": "Patrol", "dir": "zz_patrol", "category": "Movement", "path": "res://zz_patrol.gd", "state": "library"}
	var blink: Dictionary = {"name": "Blink", "dir": "zz_blink", "category": "", "path": "res://zz_blink.gd", "state": "library"}
	var row_packs: Array[Dictionary] = [bullet.merged({"state": "library"}), mine, blink]
	window._packs = row_packs
	window._rebuild_list()
	var row_words: Array = []
	for row: Button in window.rows():
		var said: Array = []
		for label: Node in row.find_children("*", "Label", true, false):
			said.append((label as Label).text)
		row_words.append(said)
	var searched: Array = _searched(window, "blin")
	var no_match: Array = _searched(window, "zzz-nothing")
	ok = SUPPORT.pins("new_addon_panel_test", [
		["the rows read in name order, each its name then its kind", row_words.map(func(said: Array) -> Array: return said.slice(0, 1)),
			[["Blink"], ["Bullet"], ["Patrol"]]],
		["a search shows only the rows it matches, building nothing", searched, ["Blink"]],
		["...and says so when it matches nothing", no_match, ["No behaviour here matches that."]],
		["the works-on kind reads the typed host before what a pack requires",
			EventSheetBehaviourLibraryWindow.works_on("extends Node
## @ace_requires(\"Camera3D\")
"), "Camera3D"],
		["a data pack that is not a node is named by what it extends",
			EventSheetBehaviourLibraryWindow.works_on("class_name ZzLoot
extends Resource
"), "Resource"],
		["a node pack works on any node", EventSheetBehaviourLibraryWindow.works_on("extends Node
"), ""],
	]) and ok
	window.free()
	host.free()
	return ok


## The names the Behaviour library shows after typing `query` (the hidden rows are still there, only not
## drawn), or what it says when nothing matches.
static func _searched(window: EventSheetBehaviourLibraryWindow, query: String) -> Array:
	var built: int = window.rows().size()
	window._search.text = query
	window._filter()
	var shown: Array = []
	for row: Button in window.rows():
		if row.visible:
			shown.append(str(row.find_children("*", "Label", true, false)[0].text))
	if shown.is_empty():
		shown.append(window._no_match.text)
	return shown if window.rows().size() == built else ["the search rebuilt the rows"]


static func _items(dropdown: OptionButton) -> Array:
	var out: Array = []
	for index: int in range(dropdown.item_count):
		out.append(dropdown.get_item_text(index))
	return out


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("new_addon_panel_test", label, actual, expected)
