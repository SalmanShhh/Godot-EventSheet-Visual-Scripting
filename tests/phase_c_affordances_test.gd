# Godot EventSheets - Phase C: Export as Addon Pack + Godot-native affordances
# One-click addon publishing from the dock, drag-from-docks into fx fields (files ->
# quoted paths, scene nodes -> $Path), and scene-tree-aware $-completion (the open
# scene's actual children complete with their script members and signals).
@tool
class_name PhaseCAffordancesTest
extends RefCounted


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass


static func run() -> bool:
	var all_passed: bool = true

	# ── Export as Addon Pack ─────────────────────────────────────────────────
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "ExportedSpinner"
	var tick: EventRow = EventRow.new()
	tick.trigger_provider_id = "Core"
	tick.trigger_id = "OnProcess"
	var spin: RawCodeRow = RawCodeRow.new()
	spin.code = "if host != null:\n\thost.rotation += delta"
	tick.actions.append(spin)
	sheet.events.append(tick)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor._export_addon_pack("user://eventsheets_export_pack")
	var exported_script: String = FileAccess.get_file_as_string("user://eventsheets_export_pack/exported_spinner.gd")
	all_passed = _check("export writes the compiled script",
		exported_script.contains("class_name ExportedSpinner"), true) and all_passed
	all_passed = _check("export writes the editable sheet",
		FileAccess.file_exists("user://eventsheets_export_pack/exported_spinner.tres"), true) and all_passed
	var exported_sheet: EventSheetResource = ResourceLoader.load("user://eventsheets_export_pack/exported_spinner.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	# Export publishes banner-less (the .gd IS the pack, same as the bundled builders), so the
	# no-drift recompile compares banner-less too.
	var redrift: String = str(SheetCompiler.compile(exported_sheet, "user://eventsheets_export_drift.gd", true).get("output", ""))
	all_passed = _check("exported pack obeys the no-drift rule", redrift == exported_script, true) and all_passed
	# Guardrail: non-behavior sheets refuse.
	var plain: EventSheetResource = EventSheetResource.new()
	editor._current_sheet = plain
	editor._export_addon_pack("user://eventsheets_export_bad")
	all_passed = _check("non-behavior sheets are refused",
		FileAccess.file_exists("user://eventsheets_export_bad/.tres"), false) and all_passed
	editor.free()

	# ── Drag-from-docks payload conversion ───────────────────────────────────
	all_passed = _check("file drops insert quoted paths",
		ACEParamsDialog.drop_data_to_expression({"type": "files", "files": ["res://enemy.tscn"]}), "\"res://enemy.tscn\"") and all_passed
	all_passed = _check("node drops insert $Name references",
		ACEParamsDialog.drop_data_to_expression({"type": "nodes", "nodes": [NodePath("/root/Main/Enemy")]}), "$Enemy") and all_passed
	all_passed = _check("awkward names get the quoted form",
		ACEParamsDialog._node_reference("Path/To Node"), "$\"Path/To Node\"") and all_passed
	all_passed = _check("unknown payloads are ignored",
		ACEParamsDialog.drop_data_to_expression({"type": "obj"}), "") and all_passed

	# ── Scene-tree-aware $-completion ────────────────────────────────────────
	var scene_root: Node2D = Node2D.new()
	scene_root.name = "Main"
	var enemy: Node2D = Node2D.new()
	# The node name must NOT match any registered global class_name: $-completion resolves a global class
	# of the same name FIRST (the behavior-child convention), so a class-named node would complete the
	# CLASS's members instead of this node's actual script. (Regression: a "Enemy" showcase class_name
	# shadowed a node named "Enemy" once an import populated the global-class cache, reddening CI.)
	enemy.name = "MoveToChild"
	enemy.set_script(load("res://eventsheet_addons/move_to/move_to_behavior.gd"))
	scene_root.add_child(enemy)
	EventSheetGDScriptLint.scene_root_provider = func() -> Node: return scene_root
	var labels: Array[String] = []
	for candidate in EventSheetGDScriptLint.completion_for_context("$MoveToChild.", null):
		labels.append(str(candidate.get("label", "")))
	all_passed = _check("scene children complete their script methods", labels.has("move_to_position"), true) and all_passed
	all_passed = _check("scene children complete their signals", labels.has("arrived"), true) and all_passed
	all_passed = _check("scene children complete class members", labels.has("position"), true) and all_passed
	var flat: Array[String] = []
	for candidate in EventSheetGDScriptLint.completion_candidates(null):
		flat.append(str(candidate.get("label", "")))
	all_passed = _check("scene children appear as $Name candidates", flat.has("$MoveToChild"), true) and all_passed
	EventSheetGDScriptLint.scene_root_provider = Callable()
	scene_root.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] phase_c_affordances_test: %s" % label)
		return true
	print("[FAIL] phase_c_affordances_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
