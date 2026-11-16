# Godot EventSheets - "Add shape": a flat box of the six kinds, each with its tile, typing narrows it,
# Enter adds the highlighted one, and the new card goes last and opens.
@tool
class_name DrawingPrefabAddShapeTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PREFIX := "drawing_prefab_add_shape_test"
const PREFAB_STEPS := preload("res://addons/eventsheet/editor/inspector/drawing_prefab_steps_property.gd")


static func _leaves(tree: Tree) -> Array:
	var found: Array = []
	var item: TreeItem = tree.get_root().get_first_child() if tree.get_root() != null else null
	while item != null:
		found.append(item)
		item = item.get_next()
	return found


static func _words(tree: Tree) -> String:
	var words: PackedStringArray = PackedStringArray()
	for item: Variant in _leaves(tree):
		words.append((item as TreeItem).get_text(0))
	return ",".join(words)


static func run() -> bool:
	var editor: PREFAB_STEPS.ShapeStepsEditor = PREFAB_STEPS.ShapeStepsEditor.new()
	editor.set_steps([{"kind": "circle", "x": 0.0, "y": 0.0, "p1": 5.0, "p2": 0.0, "p3": 0.0, "color": "#ffffff", "texture": ""}])
	editor.call("prepare_add_box")
	var tree: Tree = editor.call("add_box_tree")
	var all_have_tiles: bool = true
	var kinds: PackedStringArray = PackedStringArray()
	for item: Variant in _leaves(tree):
		var leaf: TreeItem = item as TreeItem
		kinds.append(str(leaf.get_metadata(0)))
		if leaf.get_icon(0) == null:
			all_have_tiles = false
	var rows: Array = [
		["the add button says Add shape", str(editor.call("add_button_text")).ends_with("Add shape"), true],
		["the box is one flat list of the six kinds, no headings", _words(tree), "Circle,Ring,Rectangle,Line,Cone,Stamp"],
		["each leaf stores the stored word", ",".join(kinds), "circle,ring,rect,line,cone,stamp"],
		["every kind wears its tile", all_have_tiles, true],
	]
	var filter: LineEdit = editor.call("add_box_filter")
	filter.text = "ri"
	editor.call("refill_add_box")
	rows.append(["typing narrows the list", _words(tree), "Ring"])
	filter.text = "rect"
	editor.call("refill_add_box")
	rows.append(["by the plain name too", _words(tree), "Rectangle"])
	rows.append(["the first match is highlighted so Enter has something to add", tree.get_selected() != null, true])
	editor.call("add_highlighted_or_first")
	var steps: Array = editor.get_steps()
	rows.append(["Enter adds the highlighted shape, and the new card goes last", str((steps[steps.size() - 1] as Dictionary).get("kind")), "rect"])
	rows.append(["the list grew by one", steps.size(), 2])
	rows.append(["the new card is open", editor.call("is_unfolded", 1), true])
	rows.append(["and the one before it is not", editor.call("is_unfolded", 0), false])
	rows.append(["the new rectangle starts with what the card already seeded", "%s,%s" % [str((steps[1] as Dictionary).get("p1")), str((steps[1] as Dictionary).get("p2"))], "24.0,16.0"])
	filter.text = "zzz"
	editor.call("refill_add_box")
	rows.append(["a search that matches nothing lists nothing", _leaves(tree).size(), 0])
	editor.free()
	return SUPPORT.pins(PREFIX, rows)
