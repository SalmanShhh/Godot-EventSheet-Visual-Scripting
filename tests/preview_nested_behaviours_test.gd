# Godot EventSheets - the Scene dock's "Preview its behaviours" finds behaviours at any depth.
#
# The entry used to look only at the right-clicked node's own children. Now it plays every behaviour below the
# node that acts on that node or on one under it, leaves out a behaviour that acts on something outside, leaves
# out the inside of an instanced scene that is not opened up, and stops looking after a fixed number of nodes so
# a right-click in a very large scene does not wait on the whole tree.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const WALK := preload("res://addons/eventforge/editor/preview_behaviours.gd")
const P := "preview_nested_behaviours_test"

static var _script: GDScript = null


static func run() -> bool:
	_script = GDScript.new()
	_script.source_code = "extends Node\nvar acts_on: Variant = null\nfunc _preview_start() -> void:\n\tpass\nfunc _preview_stop() -> void:\n\tpass\n"
	_script.reload()
	var ok: bool = _depth()
	ok = _hosts() and ok
	ok = _instances() and ok
	ok = _bound() and ok
	return ok


static func _behaviour(parent: Node, name: String) -> Node:
	var made: Node = Node.new()
	made.set_script(_script)
	made.name = name
	parent.add_child(made)
	return made


static func _plain(parent: Node, name: String) -> Node:
	var made: Node = Node.new()
	made.name = name
	parent.add_child(made)
	return made


static func _depth() -> bool:
	var selected: Node2D = Node2D.new()
	var direct: Node = _behaviour(selected, "Direct")
	var holder: Node = _plain(selected, "Holder")
	var two_down: Node = _behaviour(holder, "TwoDown")
	var deeper: Node = _plain(_plain(_plain(holder, "A"), "B"), "C")
	var five_down: Node = _behaviour(deeper, "FiveDown")
	var elsewhere: Node = Node.new()
	var outside: Node = _behaviour(elsewhere, "Outside")
	var found: Array[Node] = WALK.find(selected, null)
	var from_nothing: Array[Node] = WALK.find(null, null)
	var table: Array = [
		["a direct child is found, nearest first, then the ones further down", found, [direct, two_down, five_down]],
		["a behaviour in a holder two levels down is found", found.has(two_down), true],
		["a behaviour five levels down is found", found.has(five_down), true],
		["a behaviour outside the node is not", found.has(outside), false],
		["the menu's own question gives the same answer", EventSheetContextMenu.previewing_behaviours_under(selected), [direct, two_down, five_down]],
		["no node finds none", from_nothing, []],
		["the holder is not a behaviour", found.has(holder), false],
	]
	var passed: bool = SUPPORT.pins(P, table)
	selected.free()
	elsewhere.free()
	return passed


static func _hosts() -> bool:
	var selected: Node2D = Node2D.new()
	var holder: Node = _plain(selected, "Holder")
	var sprite: Node = _plain(holder, "Sprite")
	var outside_node: Node = Node.new()
	var acts_on_inside: Node = _behaviour(selected, "ActsOnInside")
	acts_on_inside.set("acts_on", sprite)
	var acts_on_path: Node = _behaviour(holder, "ActsOnPath")
	acts_on_path.set("acts_on", NodePath("../Sprite"))
	var acts_outside: Node = _behaviour(selected, "ActsOutside")
	acts_outside.set("acts_on", outside_node)
	var acts_on_self: Node = _behaviour(sprite, "ActsOnParentByDefault")
	var found: Array[Node] = WALK.find(selected, null)
	var table: Array = [
		["a behaviour that acts on a node under the selection is found", found.has(acts_on_inside), true],
		["so is one that names its host by path", found.has(acts_on_path), true],
		["one under the selection that acts on a node outside it is left out", found.has(acts_outside), false],
		["one with no named host acts on its parent", found.has(acts_on_self), true],
		["the selected node itself being the host counts", WALK.find(sprite, null), [acts_on_self]],
	]
	var passed: bool = SUPPORT.pins(P, table)
	selected.free()
	outside_node.free()
	return passed


static func _instances() -> bool:
	var edited: Node2D = Node2D.new()
	edited.name = "Edited"
	var selected: Node2D = Node2D.new()
	selected.name = "Selected"
	edited.add_child(selected)
	selected.owner = edited
	var own: Node = _behaviour(selected, "Own")
	own.owner = edited
	# An instance of another scene: its root belongs to the edited scene, what is inside belongs to the instance.
	var instance: Node2D = Node2D.new()
	instance.name = "Instance"
	instance.scene_file_path = "res://not_a_real_scene.tscn"
	selected.add_child(instance)
	instance.owner = edited
	var inside: Node = _behaviour(instance, "Inside")
	inside.owner = instance
	var closed: Array[Node] = WALK.find(selected, edited)
	edited.set_editable_instance(instance, true)
	var opened: Array[Node] = WALK.find(selected, edited)
	var table: Array = [
		["a behaviour of the edited scene is found", closed.has(own), true],
		["the inside of an instance that is not opened up is not", closed.has(inside), false],
		["once its children are opened up it is", opened.has(inside), true],
		["with no edited scene given every node counts", WALK.find(selected, null).has(inside), true],
	]
	var passed: bool = SUPPORT.pins(P, table)
	edited.free()
	return passed


static func _bound() -> bool:
	var selected: Node2D = Node2D.new()
	var near: Node = _behaviour(selected, "Near")
	for group: int in 20:
		var holder: Node = _plain(selected, "Holder%d" % group)
		for leaf: int in 100:
			_plain(holder, "Leaf%d" % leaf)
	var far_holder: Node = _plain(_plain(selected, "FarHolder"), "Deeper")
	var far: Node = _behaviour(far_holder, "Far")
	var walked: Dictionary = WALK.walk(selected, null, WALK.MAX_VISITED)
	var everything: Dictionary = WALK.walk(selected, null, 100000)
	var table: Array = [
		["the walk looks at no more than its limit", int(walked["visited"]), WALK.MAX_VISITED],
		["and says it stopped early", bool(walked["cut"]), true],
		["the nearest behaviour is still found", (walked["found"] as Array).has(near), true],
		["a behaviour past the limit is left out", (walked["found"] as Array).has(far), false],
		["without the limit the whole scene is read and the far one is found", [int(everything["visited"]) > WALK.MAX_VISITED, (everything["found"] as Array).has(far), bool(everything["cut"])], [true, true, false]],
	]
	var passed: bool = SUPPORT.pins(P, table)
	selected.free()
	return passed
