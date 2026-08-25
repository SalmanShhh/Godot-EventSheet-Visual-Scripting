@tool
class_name SceneNodeParamPickerTest
extends RefCounted

# The node parameter on the Hierarchy rows is picked out of the layout that is OPEN, not typed
# from memory: the "scene_node" hint offers the edited scene's tree in the spellings a row writes
# (`self`, `%Unique`, `$Path`), and stays a free text field for everything the tree cannot know.
#
# Three gates:
#   1. the choices themselves, value by value - including the empty list a null scene gives, which is
#      the no-scene-open (and headless) fallback to the ordinary text field;
#   2. the dialog dispatching the hint at all, so a param carrying it reaches the picker;
#   3. the Hierarchy rows carrying the hint on every node-ish param and on nothing else.


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _choices() and all_passed
	all_passed = _dispatch() and all_passed
	all_passed = _hierarchy_params() and all_passed
	return all_passed


## Gate one: the choices, as the strings that land in the field.
static func _choices() -> bool:
	var ok: bool = true
	ok = _check("no scene open offers nothing, which leaves a plain text field",
		", ".join(_as_strings(ACEParamsDialog.scene_node_choices(null))), "") and ok

	var root: Node = Node.new()
	root.name = "Level"
	var player: Node = Node.new()
	player.name = "Player"
	root.add_child(player)
	player.owner = root
	var ui: Node = Node.new()
	ui.name = "UI"
	root.add_child(ui)
	ui.owner = root
	var score: Node = Node.new()
	score.name = "Score"
	ui.add_child(score)
	score.owner = root
	score.unique_name_in_owner = true
	var spaced: Node = Node.new()
	spaced.name = "Health Bar"
	root.add_child(spaced)
	spaced.owner = root

	ok = _check("the open layout offers itself, its unique names and every path",
		", ".join(_as_strings(ACEParamsDialog.scene_node_choices(root))),
		"self, %Score, $Player, $UI, $UI/Score, $\"Health Bar\"") and ok
	ok = _check("a plain path follows a bare $", ACEParamsDialog.is_bare_node_path("UI/Score"), true) and ok
	ok = _check("a digit in a name is still bare", ACEParamsDialog.is_bare_node_path("Sprite2D"), true) and ok
	ok = _check("a name with a space is not", ACEParamsDialog.is_bare_node_path("Health Bar"), false) and ok
	root.free()
	return ok


## Gate two: the hint reaches a factory, and that factory hands back a field the value is read from.
static func _dispatch() -> bool:
	var ok: bool = true
	var dialog := ACEParamsDialog.new()
	dialog._ensure_hint_factories()
	ok = _check("the params dialog registers the scene_node hint factory",
		dialog._hint_factories.has("scene_node"), true) and ok
	var field: Control = dialog._create_field(
		{"type": TYPE_STRING, "default_value": "self"}, {}, "child", "scene_node")
	ok = _check("the field is built", field != null, true) and ok
	ok = _check("and the value-bearing control is registered under the param key",
		dialog._fields.get("child") is LineEdit, true) and ok
	ok = _check("carrying the default it was given",
		str((dialog._fields.get("child") as LineEdit).text), "self") and ok
	if field != null:
		field.free()
	return ok


## Gate three: the rows that take a node in the tree say so, and the rows that take a word do not.
static func _hierarchy_params() -> bool:
	var ok: bool = true
	var shipped: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		shipped[str(descriptor.ace_id)] = descriptor
	var expected: Dictionary = {
		"HierarchyAddChild": "child=scene_node, parent=scene_node, keep=",
		"HierarchyRemoveFromParent": "child=scene_node",
		"SetIgnoreParentMovement": "target=scene_node, ignore=",
		"CopyPlaceTo": "follower=scene_node, path=expression",
		"StopCopyingPlace": "follower=scene_node",
		"ForEachChildOf": "target=scene_node"
	}
	for ace_id: String in expected:
		ok = _check("%s hints" % ace_id, _param_hints(shipped.get(ace_id, null)),
			str(expected[ace_id])) and ok
	ok = _check("the Hierarchy rows are still filed on the Hierarchy page",
		str((shipped.get("HierarchyAddChild", null) as ACEDescriptor).category),
		"Nodes: Hierarchy") and ok
	return ok


## "id=hint, id=hint, …" for one shipped ACE, or "" when nothing ships under that id.
static func _param_hints(descriptor: Variant) -> String:
	if descriptor == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for parameter: ACEParam in (descriptor as ACEDescriptor).params:
		parts.append("%s=%s" % [str(parameter.id), str(parameter.hint)])
	return ", ".join(parts)


static func _as_strings(values: Array) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for value: Variant in values:
		texts.append(str(value))
	return texts


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] scene_node_param_picker_test: %s" % label)
		return true
	print("[FAIL] scene_node_param_picker_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
