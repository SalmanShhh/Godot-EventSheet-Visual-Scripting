# Godot EventSheets — dragging a scene node into a param field to reference it.
#
# Dropping a Scene-dock node onto an expression/path field inserts a node reference. For Godot's node-heavy
# objects this now prefers a scene-unique %Name (collapses a deep $A/B/C/D path to %D, reparent-proof) when
# the dragged node carries one — the same flat handle the node picker hands back — instead of a brittle
# $path. Pins the drag→reference conversion + the %Name preference.
@tool
extends RefCounted
class_name NodeDragReferenceTest

static func run() -> bool:
	var all_passed: bool = true

	# A scene-unique node drags in as %Name; a plain one as $path.
	var root: Node = Node.new()
	root.name = "Root"
	var hero: Node = Node.new()
	hero.name = "Hero"
	root.add_child(hero)
	hero.owner = root
	hero.unique_name_in_owner = true
	var plain: Node = Node.new()
	plain.name = "Plain"
	root.add_child(plain)
	plain.owner = root

	all_passed = _check("a scene-unique node drags in as %Name",
		ACEParamsDialog._best_node_reference(root, "Hero"), "%Hero") and all_passed
	all_passed = _check("a non-unique node drags in as $path",
		ACEParamsDialog._best_node_reference(root, "Plain"), "$Plain") and all_passed
	root.free()

	# Drop payloads: a node becomes a $reference; a path with spaces is quoted; a file becomes a literal.
	all_passed = _check("a dragged node payload becomes a $reference",
		ACEParamsDialog.drop_data_to_expression({"type": "nodes", "nodes": ["/root/Main/Player"]}), "$Player") and all_passed
	all_passed = _check("a path with spaces is quoted",
		ACEParamsDialog._node_reference("My Node"), "$\"My Node\"") and all_passed

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] node_drag_reference_test: %s" % label)
		return true
	print("[FAIL] node_drag_reference_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
