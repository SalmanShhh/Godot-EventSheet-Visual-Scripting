# Godot EventSheets — Node-path validation + autocomplete in expression fields.
#
# Expression params (including the new "On node" target on node-scoped ACEs) accept node references
# like $Player, $"UI/Score" and get_node("UI/Score"). A typo there used to fail silently at runtime.
# This covers the pure helpers behind the editor wiring: extracting literal node references from an
# expression, warning when one does not resolve in the edited scene (a typo), and listing the scene's
# node paths for the `$` autocomplete. The amber-tint wiring itself is exercised by the editor smoke.
@tool
extends RefCounted
class_name NodePathValidationTest

static func run() -> bool:
	var all_passed: bool = true

	# A small detached scene: Root → Player, UI → Score. has_node traverses it without a live tree.
	var root: Node = Node.new()
	root.name = "Root"
	var player: Node = Node.new(); player.name = "Player"; root.add_child(player)
	var ui: Node = Node.new(); ui.name = "UI"; root.add_child(ui)
	var score: Node = Node.new(); score.name = "Score"; ui.add_child(score)

	# Extraction: bare / slashed / quoted $ refs and get_node("…").
	all_passed = _check("extracts a bare $ ref", ACEParamsDialog.node_references_in_expression("$Player"), PackedStringArray(["Player"])) and all_passed
	all_passed = _check("extracts a slashed $ path", ACEParamsDialog.node_references_in_expression("$UI/Score.visible"), PackedStringArray(["UI/Score"])) and all_passed
	all_passed = _check("extracts a quoted $ ref", ACEParamsDialog.node_references_in_expression("$\"UI/Score\""), PackedStringArray(["UI/Score"])) and all_passed
	all_passed = _check("extracts a get_node ref", ACEParamsDialog.node_references_in_expression("get_node(\"UI/Score\").modulate"), PackedStringArray(["UI/Score"])) and all_passed
	all_passed = _check("no refs in a plain expression", ACEParamsDialog.node_references_in_expression("health + 1").size(), 0) and all_passed

	# Validation: resolved paths are silent; a typo returns the offending path.
	all_passed = _check("resolved $ path → no warning", ACEParamsDialog.unresolved_node_reference("$Player", root), "") and all_passed
	all_passed = _check("resolved nested path → no warning", ACEParamsDialog.unresolved_node_reference("$UI/Score", root), "") and all_passed
	all_passed = _check("typo'd path → warns with the bad path", ACEParamsDialog.unresolved_node_reference("$Enmy", root), "Enmy") and all_passed
	all_passed = _check("get_node typo → warns", ACEParamsDialog.unresolved_node_reference("get_node(\"UI/Nope\")", root), "UI/Nope") and all_passed
	all_passed = _check("absolute path is skipped (runtime tree)", ACEParamsDialog.unresolved_node_reference("$\"/root/Main\"", root), "") and all_passed
	all_passed = _check("no scene → no warning", ACEParamsDialog.unresolved_node_reference("$Enmy", null), "") and all_passed
	all_passed = _check("plain expression → no warning", ACEParamsDialog.unresolved_node_reference("health + 1", root), "") and all_passed

	# Autocomplete: every node listed as a relative path.
	var paths: PackedStringArray = ACEParamsDialog.scene_node_paths(root)
	all_passed = _check("autocomplete lists Player", paths.has("Player"), true) and all_passed
	all_passed = _check("autocomplete lists nested UI/Score", paths.has("UI/Score"), true) and all_passed
	all_passed = _check("autocomplete is empty for a null scene", ACEParamsDialog.scene_node_paths(null).size(), 0) and all_passed

	root.free()
	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] node_path_validation_test: %s" % label)
		return true
	print("[FAIL] node_path_validation_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
