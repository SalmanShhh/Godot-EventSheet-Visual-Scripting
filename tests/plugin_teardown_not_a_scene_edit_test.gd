extends RefCounted
## A plugin that frees its own dock when it is switched off is not editing the scene the editor has
## open. The not-undoable finding reads the plugin's own lifecycle events as the plugin's business:
## On Plugin Enabled builds the plugin's UI and On Plugin Disabled takes it down again, and putting
## either into the reader's undo history would let a Ctrl+Z bring back a dock nobody owns. The same
## file's menu handler, which really does read the edited scene, still earns the finding when it
## edits that scene outside the history.

const SUPPORT := preload("res://tests/support.gd")
const NAME := "plugin_teardown_not_a_scene_edit_test"

## The plugin every project's first editor tool looks like: a dock built on enable and freed on
## disable, plus one menu command that reads the open scene.
const OWN_PLUGIN := """@tool
extends EditorPlugin

const MENU_NAME := "Count Coins In Scene"

var _dock: Control


func _enter_tree() -> void:
	_dock = Control.new()
	add_control_to_dock(DOCK_SLOT_LEFT_UR, _dock)
	add_tool_menu_item(MENU_NAME, _on_count_coins)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_NAME)
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null


func _on_count_coins() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		print("No scene open.")
		return
	print("Coins in scene: ", root.get_child_count())
"""

## The same plugin whose menu command DOES change the open scene by hand: that one still counts.
const EDITING_PLUGIN := """@tool
extends EditorPlugin

var _dock: Control


func _exit_tree() -> void:
	if _dock:
		_dock.queue_free()
		_dock = null


func _on_tidy() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return
	root.get_child(0).queue_free()
"""


## The answer is decided by WHAT a line changes, not by which event it sits in: a menu command that
## closes the plugin's own panel is the plugin's business too, and a switch-on that tidies the open
## scene by hand is an edit of the reader's scene like any other.
const BY_RECEIVER := """@tool
extends EditorPlugin

var _panel: Control


func _enter_tree() -> void:
	_panel = preload("res://panel.tscn").instantiate()
	add_control_to_bottom_panel(_panel, "Coins")
	EditorInterface.get_edited_scene_root().get_child(0).queue_free()


func _on_close_panel() -> void:
	_panel.queue_free()
"""


static func run() -> bool:
	var own: EventSheetResource = SUPPORT.reopen(OWN_PLUGIN, true, "user://plugin_teardown_own.gd")
	var editing: EventSheetResource = SUPPORT.reopen(EDITING_PLUGIN, true, "user://plugin_teardown_editing.gd")
	var by_receiver: EventSheetResource = SUPPORT.reopen(BY_RECEIVER, true, "user://plugin_teardown_by_receiver.gd")
	return SUPPORT.pins(NAME, [
		["a menu command freeing the plugin's own panel is no finding, a switch-on editing the open scene is",
			_subjects(by_receiver), ["EditorInterface.get_edited_scene_root().get_child(0).queue_free()"]],
		["the plugin's own names are what it made or handed to the editor",
			EventSheetUndoableFindings.plugin_own_names(own).keys(), ["_dock"]],
		["the plugin file opens as a tool sheet", own.tool_mode, true],
		["and it reaches the open scene", EventSheetUndoableFindings.edits_the_open_scene(own), true],
		["freeing its own dock on disable is no finding", _subjects(own), []],
		["a hand edit of the open scene still is", _subjects(editing), ["root.get_child(0).queue_free()"]],
		["and the teardown beside it is not", _subjects(editing).has("_dock.queue_free()"), false],
	])


static func _subjects(sheet: EventSheetResource) -> Array:
	var out: Array = []
	for finding: Dictionary in EventSheetUndoableFindings.findings(sheet, "plugin.gd"):
		out.append(str(finding.get("subject", "")))
	return out
