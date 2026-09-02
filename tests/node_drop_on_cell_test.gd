# Godot EventSheets - dropping a scene node onto a condition/action param value.
#
# Dragging a node from the Scene dock onto a param VALUE in a cell sets that param to the node reference
# (prefers %unique-names), no dialog - the deep-node-friendly event-sheet gesture. The param hit-test reuses
# the proven double-click-to-edit path (layout-dependent, exercised in the editor); this pins the pure
# pieces: the drag discriminator and the path→reference conversion.
@tool
class_name NodeDropOnCellTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var all_passed: bool = true

	# _is_node_path_drag accepts a Scene-dock node-path drag, rejects everything else.
	all_passed = _check("accepts a scene-dock node-path drag",
		EventSheetViewport._is_node_path_drag({"type": "nodes", "nodes": ["/root/Main/Player"]}), true) and all_passed
	all_passed = _check("rejects a files drag",
		EventSheetViewport._is_node_path_drag({"type": "files", "files": ["a.png"]}), false) and all_passed
	all_passed = _check("rejects an empty nodes payload",
		EventSheetViewport._is_node_path_drag({"type": "nodes", "nodes": []}), false) and all_passed
	all_passed = _check("rejects a non-dictionary payload",
		EventSheetViewport._is_node_path_drag("nope"), false) and all_passed

	# An Object-valued "nodes" payload is a behaviour-source drag (ACE preview), NOT a path drag.
	var node: Node = Node.new()
	all_passed = _check("rejects an Object-valued nodes payload (behaviour drag)",
		EventSheetViewport._is_node_path_drag({"type": "nodes", "nodes": [node]}), false) and all_passed
	node.free()

	# End-to-end: the dropped node path becomes a node reference (the converter the params dialog uses).
	all_passed = _check("a dropped node path resolves to a node reference",
		ACEParamsDialog.drop_data_to_expression({"type": "nodes", "nodes": ["/root/Main/Player"]}), "$Player") and all_passed

	# Type-gate: a node ref fits object/String/expression params, but NOT a plain number/bool cell (a footgun).
	all_passed = _check("a node ref is rejected on a plain int param",
		EventSheetViewport._node_ref_fits_param_type("int", ""), false) and all_passed
	all_passed = _check("a node ref is rejected on a plain bool param",
		EventSheetViewport._node_ref_fits_param_type("bool", ""), false) and all_passed
	all_passed = _check("a node ref is allowed on an expression-hinted numeric param",
		EventSheetViewport._node_ref_fits_param_type("float", "expression"), true) and all_passed
	all_passed = _check("a node ref is allowed on a String param",
		EventSheetViewport._node_ref_fits_param_type("String", ""), true) and all_passed
	all_passed = _check("a node ref is allowed on an object/node-typed param",
		EventSheetViewport._node_ref_fits_param_type("Node2D", ""), true) and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("node_drop_on_cell_test", label, actual, expected)
