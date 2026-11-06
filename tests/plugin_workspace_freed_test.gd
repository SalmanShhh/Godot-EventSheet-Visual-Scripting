# EventForge - the disabled plugin's workspace and docs dock go away, and take their helpers along.
# _exit_tree queues them rather than freeing them on the spot, because a disable can arrive from a call
# still inside the workspace: the frame's end is the first moment nothing of it is on the stack.
#
# TRAP this file once fell into: under `--editor --script`, a node queued while outside the tree is NOT
# collected. That run's main loop is the script's SceneTree, and the queue of an out-of-tree node goes
# to the engine's singleton tree, which is not the one that flushes. A real editor collects it
# (never-in-tree and removed-then-queued both freed, in a plain `--editor` run of a probe plugin), so an
# orphan count from a `--script` harness that grows by the workspace's size per disable is the harness.
#
# The second half pins that nothing keeps the workspace's helpers alive after it is freed (no helper
# cycle through a strong back-reference).
@tool
class_name PluginWorkspaceFreedTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PLUGIN_PATH: String = "res://addons/eventforge/plugin.gd"
const EDITOR_PATH: String = "res://addons/eventforge/editor/event_sheet_editor.gd"
# Helpers that outlive a freed workspace and are NOT a cycle this test can ask the workspace to break.
const KNOWN_RESIDUE: Array[String] = []


static func run() -> bool:
	var passed: bool = true
	var source: String = FileAccess.get_file_as_string(PLUGIN_PATH)
	var start: int = source.find("func _exit_tree()")
	var body: String = source.substr(start) if start >= 0 else ""
	passed = _check("_exit_tree found", start >= 0, true) and passed
	passed = _check("the workspace is queued, so a call inside it can finish", body.contains("_event_sheet_editor.queue_free()"), true) and passed
	passed = _check("and so is the docs dock", body.contains("_doc_dock.queue_free()"), true) and passed
	passed = _check("neither is freed on the spot", body.contains("_event_sheet_editor.free()") or body.contains("_doc_dock.free()"), false) and passed
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
