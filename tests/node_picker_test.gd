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

	# The themed picker's "Use Node" button enables only when a real node row is highlighted.
	dialog._populate_node_picker_from_root(root)
	var ok_button: Button = dialog._node_picker_window.get_ok_button()
	dialog._on_node_picker_selection_changed()
	all_passed = _check("Use Node disabled with nothing selected", ok_button.disabled, true) and all_passed
	var first_row: TreeItem = dialog._node_picker_tree.get_root().get_first_child()
	if first_row != null:
		first_row.select(0)
	dialog._on_node_picker_selection_changed()
	all_passed = _check("Use Node enables when a node row is selected",
		first_row != null and not ok_button.disabled, true) and all_passed

	# Cross-scene scan finds the demo player scene by node/class.
	var hits: Array = ACEParamsDialog.scan_scene_files("CharacterBody2D", "res://demo")
	all_passed = _check("scene: scan finds nodes across .tscn files", hits.size() >= 1, true) and all_passed

	# Keypad constants keep their underscore.
	all_passed = _check("keypad keys map to KEY_KP_*",
		ACEParamsDialog.key_constant_for(KEY_KP_ADD), "KEY_KP_ADD") and all_passed

	# Unique-name (%) references collapse deep paths — Godot's answer to node-heavy objects. Picking a
	# scene-unique deep node hands back %Name (a flat handle) instead of the brittle $A/B/C path.
	var arena: Node2D = Node2D.new()
	arena.name = "Arena"
	var arena_visuals: Node2D = Node2D.new()
	arena_visuals.name = "Visuals"
	arena.add_child(arena_visuals)
	arena_visuals.owner = arena
	var arena_body: Sprite2D = Sprite2D.new()
	arena_body.name = "Body"
	arena_visuals.add_child(arena_body)
	arena_body.owner = arena
	all_passed = _check("a non-unique deep node uses the $path",
		ACEParamsDialog._best_node_reference(arena, "Visuals/Body"), "$\"Visuals/Body\"") and all_passed
	arena_body.unique_name_in_owner = true
	all_passed = _check("a scene-unique deep node collapses to %Name",
		ACEParamsDialog._best_node_reference(arena, "Visuals/Body"), "%Body") and all_passed
	dialog._node_picker_search.text = ""
	dialog._populate_node_picker_from_root(arena)
	all_passed = _check("the picker tree shows the %handle for a unique node",
		_tree_column(dialog._node_picker_tree, 0).has("%Body"), true) and all_passed
	arena.free()

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
