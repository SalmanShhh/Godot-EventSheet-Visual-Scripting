# Godot EventSheets — Searchable node picker, large-project edition: filter chips,
# group:/script:/scene: queries, recents, used-in-sheet audit (missing = red).
@tool
extends RefCounted
class_name NodePickerTest

static func run() -> bool:
	var all_passed: bool = true

	# A small scene tree to search.
	var root: Node2D = Node2D.new()
	root.name = "Level"
	var enemy: CharacterBody2D = CharacterBody2D.new()
	enemy.name = "Slime"
	enemy.add_to_group("enemies")
	root.add_child(enemy)
	var ui: Control = Control.new()
	ui.name = "HUD"
	root.add_child(ui)
	var sfx: AudioStreamPlayer = AudioStreamPlayer.new()
	sfx.name = "Jingle"
	root.add_child(sfx)

	# Query modes.
	all_passed = _check("plain query matches class",
		ACEParamsDialog.node_matches_query(enemy, "Slime", "characterbody"), true) and all_passed
	all_passed = _check("group: query matches membership",
		ACEParamsDialog.node_matches_query(enemy, "Slime", "group:enemies"), true) and all_passed
	all_passed = _check("group: query rejects non-members",
		ACEParamsDialog.node_matches_query(ui, "HUD", "group:enemies"), false) and all_passed
	var probe_script: GDScript = GDScript.new()
	probe_script.source_code = "extends CharacterBody2D\n"
	probe_script.take_over_path("res://enemy_brain.gd")
	probe_script.reload()
	enemy.set_script(probe_script)
	all_passed = _check("script: query matches the attached script file",
		ACEParamsDialog.node_matches_query(enemy, "Slime", "script:enemy_brain"), true) and all_passed
	enemy.set_script(null)

	# Populated tree: chips filter by base class; recents pin to the top.
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	var host: Node = Node.new()
	dialog.init_dialog(host)
	dialog._ensure_node_picker_ui()
	dialog._node_picker_search.text = ""
	dialog._node_picker_chips["Audio"].button_pressed = true
	dialog._populate_node_picker_from_root(root)
	var labels: PackedStringArray = _tree_column(dialog._node_picker_tree, 0)
	all_passed = _check("Audio chip shows only players",
		labels.size() == 1 and labels[0].contains("Jingle"), true) and all_passed
	dialog._node_picker_chips["Audio"].button_pressed = false
	dialog._node_picker_recents.insert(0, "HUD")
	dialog._populate_node_picker_from_root(root)
	labels = _tree_column(dialog._node_picker_tree, 0)
	all_passed = _check("recents pin first with the star",
		labels.size() > 0 and labels[0] == "★ HUD", true) and all_passed

	# Used-in-sheet audit: refs extracted from params/blocks; missing ones flagged.
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var ace: ACEAction = ACEAction.new()
	ace.provider_id = "Core"
	ace.ace_id = "X"
	ace.codegen_template = "look_at({t})"
	ace.params = {"t": "$Slime.global_position"}
	event.actions.append(ace)
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "$\"UI/Health Bar\".value = 5"
	event.actions.append(block)
	sheet.events.append(event)
	var references: PackedStringArray = ACEParamsDialog.extract_sheet_node_references(sheet)
	all_passed = _check("sheet references extract ($Name and $\"Path\")",
		references.has("Slime") and references.has("UI/Health Bar"), true) and all_passed
	dialog._lint_context_provider = func() -> EventSheetResource: return sheet
	dialog._node_picker_used_toggle.button_pressed = true
	dialog._populate_node_picker_from_root(root)
	var missing_flags: PackedStringArray = _tree_column(dialog._node_picker_tree, 1)
	all_passed = _check("missing references flag red in the audit",
		missing_flags.has("MISSING") and missing_flags.has(""), true) and all_passed
	dialog._node_picker_used_toggle.button_pressed = false

	# Cross-scene scan finds the demo player scene by node/class.
	var hits: Array = ACEParamsDialog.scan_scene_files("CharacterBody2D", "res://demo")
	all_passed = _check("scene: scan finds nodes across .tscn files", hits.size() >= 1, true) and all_passed

	# Keypad constants keep their underscore.
	all_passed = _check("keypad keys map to KEY_KP_*",
		ACEParamsDialog.key_constant_for(KEY_KP_ADD), "KEY_KP_ADD") and all_passed

	host.free()
	root.free()
	return all_passed

static func _tree_column(tree: Tree, column: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var item: TreeItem = tree.get_root().get_first_child() if tree.get_root() != null else null
	while item != null:
		out.append(item.get_text(column))
		item = item.get_next()
	return out

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] node_picker_test: %s" % label)
		return true
	print("[FAIL] node_picker_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
