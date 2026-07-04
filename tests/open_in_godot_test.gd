# Godot EventSheets - "Open in Godot" (open GDScript in Godot's own script editor).
#
# Real files only: a custom-ACE provider script, or a code-backed sheet's .gd source. A block in a
# code-backed sheet applies its popup text, compiles the sheet back to the .gd, and opens that source
# (edits reload on focus via the existing backed-sheet reload). A sheet with no .gd source (.tres)
# has nothing to open, so the block / generated actions nudge the user to Save As… → .gd and DON'T
# write any throwaway files. The editor glue (EditorInterface.edit_script) runs only in the real
# editor (guarded by is_editor_hint()), so headless these actions degrade to a status message.
#
# This pins: a .tres block/generated never mutates state or writes files, and the three affordances
# are wired.
@tool
class_name OpenInGodotTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.setup(null)
	dock._current_sheet = EventSheetResource.new()  # external_source_path empty → a non-backed (.tres) sheet

	# A block in a .tres sheet has no file: "Open in Godot" must NOT mutate the block, must not crash,
	# and must not write any throwaway files - it points the user at Save As… → .gd.
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "print(\"original\")"
	dock._ensure_raw_code_dialog()
	dock._raw_code_target = block
	dock._raw_code_edit.text = "print(\"edited in popup\")"
	dock._open_raw_code_block_in_godot()
	all_passed = _check("block in a .tres sheet is left untouched (no file to open)", block.code, "print(\"original\")") and all_passed

	# Generated "Open in Godot" on a non-backed sheet also just nudges to Save As - no throwaway files.
	dock._ensure_code_panel()
	dock._code_edit.text = "extends Node\nfunc _ready() -> void:\n\tpass\n"
	dock._open_generated_in_godot()
	all_passed = _check("non-backed 'Open in Godot' writes no throwaway files",
		DirAccess.dir_exists_absolute("res://.eventsheets_tmp/"), false) and all_passed

	# Affordances are wired: the block popup, provider dialog, and generated panel each expose "Open in Godot".
	all_passed = _check("block popup has an 'Open in Godot' button",
		_find_button(dock._raw_code_dialog, "Open in Godot Script Editor") != null, true) and all_passed
	dock._build_provider_dialog()
	all_passed = _check("provider dialog has an 'Open in Godot' button",
		_find_button(dock._provider_dialog, "Open in Godot Script Editor") != null, true) and all_passed
	all_passed = _check("generated panel has an 'Open in Godot' button",
		_find_button(dock._side_panel, "Open in Godot Script Editor") != null, true) and all_passed

	dock.free()
	return all_passed


## Walks WITH internal children (get_children(true)) so it sees AcceptDialog's dialog-managed
## buttons (OK/Cancel and add_button() buttons live under an internal HBox excluded by default).
static func _find_button(root: Node, text: String) -> Button:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Button and (node as Button).text == text:
			return node as Button
		for child: Node in node.get_children(true):
			stack.push_back(child)
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] open_in_godot_test: %s" % label)
		return true
	print("[FAIL] open_in_godot_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
