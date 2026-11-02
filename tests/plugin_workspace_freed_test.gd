# EventForge - the disabled plugin's workspace and docs dock actually go away.
# A node already taken out of the tree and then only queue_free()d is never collected (the engine's
# delete queue skips it), so disabling the plugin left the whole workspace, about nine hundred
# nodes, alive and unreachable; every enable/disable cycle added another copy. _exit_tree frees them
# with free(). The second half pins that nothing keeps the workspace's helpers alive after it is
# freed (no helper cycle through a strong back-reference).
@tool
class_name PluginWorkspaceFreedTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PLUGIN_PATH: String = "res://addons/eventforge/plugin.gd"
const EDITOR_PATH: String = "res://addons/eventforge/editor/event_sheet_editor.gd"
# Helpers that outlive a freed workspace and are NOT a cycle this test can ask the workspace to break:
# the UI builder is kept by a callable the engine still holds after the controls are freed (one small
# object per disable, measured in the real editor and listed in the changelog as the remaining residue).
const KNOWN_RESIDUE: Array[String] = ["_ui_builder"]


static func run() -> bool:
	var passed: bool = true
	var source: String = FileAccess.get_file_as_string(PLUGIN_PATH)
	var start: int = source.find("func _exit_tree()")
	var body: String = source.substr(start) if start >= 0 else ""
	passed = _check("_exit_tree found", start >= 0, true) and passed
	passed = _check("the workspace is freed immediately", body.contains("_event_sheet_editor.free()"), true) and passed
	passed = _check("the docs dock is freed immediately", body.contains("_doc_dock.free()"), true) and passed
	passed = _check("neither is merely queued", body.contains("_event_sheet_editor.queue_free()") or body.contains("_doc_dock.queue_free()"), false) and passed
	var editor: Object = load(EDITOR_PATH).new()
	var refs: Array = []
	var names: Array = []
	for property: Dictionary in editor.get_property_list():
		if not (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var value: Variant = editor.get(str(property["name"]))
		if value is RefCounted and not (value is Resource):
			refs.append(weakref(value))
			names.append(str(property["name"]))
		value = null
	passed = _check("the workspace holds helpers to check", refs.size() > 0, true) and passed
	editor.free()
	var alive: Array = []
	for index: int in refs.size():
		if (refs[index] as WeakRef).get_ref() != null and not KNOWN_RESIDUE.has(names[index]):
			alive.append(names[index])
	passed = _check("no helper outlives the freed workspace", alive, []) and passed
	return passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("plugin_workspace_freed_test", label, actual, expected)
