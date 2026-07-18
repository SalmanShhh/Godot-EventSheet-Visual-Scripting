# Godot EventSheets - Inspector property drag into the sheet
# Drag a property out of the Inspector and drop it on the sheet: on a param VALUE it
# inserts the access expression; anywhere else the dock builds a Set Property action
# targeting that node + property with the CURRENT value pre-filled. Pins: the drag payload
# recognition (Godot's {type: "obj_property"} shape), the reference/access/value resolution
# (self vs %unique vs $path, literal forms, objects excluded), and the Set Property
# descriptor the drop targets existing with the expected template.
@tool
class_name PropertyDropTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true

	# ---- payload recognition ----
	var node: Node = Node.new()
	all_passed = _check("the Inspector payload is recognized",
		EventSheetViewport.is_property_drag({"type": "obj_property", "object": node, "property": "visible"}), true) and all_passed
	all_passed = _check("other drags are not",
		EventSheetViewport.is_property_drag({"type": "nodes", "nodes": []}), false) and all_passed
	all_passed = _check("a non-node owner is not (resources have no scene reference)",
		EventSheetViewport.is_property_drag({"type": "obj_property", "object": RefCounted.new(), "property": "x"}), false) and all_passed
	node.free()

	# ---- reference/access/value resolution ----
	var root: Node2D = Node2D.new()
	root.name = "Level"
	var sprite: Node2D = Node2D.new()
	sprite.name = "Sprite"
	sprite.visible = false
	root.add_child(sprite)
	var child_parts: Dictionary = EventSheetViewport.property_drop_parts(
		{"type": "obj_property", "object": sprite, "property": "visible"}, root)
	all_passed = _check("a child resolves to its $path reference", child_parts.get("reference"), "$Sprite") and all_passed
	all_passed = _check("the access expression reads through the reference", child_parts.get("access"), "$Sprite.visible") and all_passed
	all_passed = _check("the current value pre-fills as a literal", child_parts.get("value"), "false") and all_passed
	var self_parts: Dictionary = EventSheetViewport.property_drop_parts(
		{"type": "obj_property", "object": root, "property": "position"}, root)
	all_passed = _check("the scene root resolves to self", self_parts.get("reference"), "self") and all_passed
	all_passed = _check("self access is the bare property", self_parts.get("access"), "position") and all_passed
	all_passed = _check("math types serialize as constructors", self_parts.get("value"), "Vector2(0, 0)") and all_passed
	root.free()

	# ---- value literal forms ----
	all_passed = _check("colors serialize", EventSheetViewport.property_value_literal(Color(1, 0, 0, 1)), "Color(1, 0, 0, 1)") and all_passed
	all_passed = _check("strings serialize quoted", EventSheetViewport.property_value_literal("hi"), "\"hi\"") and all_passed
	all_passed = _check("objects have no literal form", EventSheetViewport.property_value_literal(RefCounted.new()), "") and all_passed

	# ---- the target action exists with the expected template ----
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "SetProperty")
	all_passed = _check("Set Property is registered", descriptor != null, true) and all_passed
	if descriptor != null:
		all_passed = _check("its template assigns through the target", descriptor.codegen_template, "{target}.{property} = {value}") and all_passed

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] property_drop_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
