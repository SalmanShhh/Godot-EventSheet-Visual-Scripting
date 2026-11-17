# Godot EventSheets - the scene and settings edits are one step each on the undo history.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "undo_steps_test"
const STEPS := "res://addons/eventforge/editor/undo_steps.gd"


static func run() -> bool:
	var steps: GDScript = load(STEPS)
	var undo: UndoRedo = UndoRedo.new()
	var root: Node = Node.new()
	root.name = "Scene"
	var host: Node = Node.new()
	host.name = "Host"
	root.add_child(host)
	host.owner = root

	# An attached node: Ctrl+Z takes it out, Ctrl+Y puts it back owned by the scene.
	var child: Node = Node.new()
	child.name = "Sine"
	steps.add_child_step(host, child, root, "Attach Sine to Host", undo)
	var added: bool = child.get_parent() == host and child.owner == root
	undo.undo()
	var removed: bool = child.get_parent() == null
	undo.redo()
	var passed: bool = SUPPORT.pins(TEST_NAME, [
		["an attach adds the node owned by the scene", added, true],
		["Ctrl+Z takes the node out", removed, true],
		["Ctrl+Y puts it back, owned again", child.get_parent() == host and child.owner == root, true],
		["the step has the name the history shows", undo.get_current_action_name(), "Attach Sine to Host"],
	])

	# A move under another node, with the place it came from kept.
	var first: Node = Node.new()
	first.name = "First"
	var second: Node = Node.new()
	second.name = "Second"
	root.add_child(first)
	root.add_child(second)
	first.owner = root
	second.owner = root
	var order_before: int = second.get_index()
	steps.reparent_step(second, first, root, "Move Second under First", undo)
	var moved: bool = second.get_parent() == first and second.owner == root
	undo.undo()
	passed = SUPPORT.pins(TEST_NAME, [
		["a move puts the node under the new parent", moved, true],
		["Ctrl+Z puts it back where it was", second.get_parent() == root and second.get_index() == order_before, true],
	]) and passed

	# The Doctor's "Move it under" on the open scene is that same step, and refuses what the file door refuses.
	var doctor: GDScript = load("res://addons/eventforge/behaviour_host_doctor.gd")
	var done: Dictionary = doctor.move_under_open(root, "Second", "First", undo)
	var done_under: bool = second.get_parent() == first
	undo.undo()
	var undone_back: bool = second.get_parent() == root
	var clash_parent: Node = Node.new()
	clash_parent.name = "Third"
	root.add_child(clash_parent)
	clash_parent.owner = root
	var clash_child: Node = Node.new()
	clash_child.name = "Second"
	clash_parent.add_child(clash_child)
	var refused: Dictionary = doctor.move_under_open(root, "Second", "Third", undo)
	passed = SUPPORT.pins(TEST_NAME, [
		["the Doctor's move in the open scene works", [done["ok"], done_under], [true, true]],
		["and says Ctrl+Z takes it back", str(done["message"]).contains("Ctrl+Z"), true],
		["Ctrl+Z undoes the Doctor's move", undone_back, true],
		["a name already taken under the new parent is refused", refused["ok"], false],
	]) and passed

	# A property: a node's script slot or a resource field.
	var mover: Node2D = Node2D.new()
	steps.set_property_step(mover, "position", Vector2(5, 6), "Move", undo)
	var set_to: Vector2 = mover.position
	undo.undo()
	passed = SUPPORT.pins(TEST_NAME, [
		["a property step sets the value", set_to, Vector2(5, 6)],
		["Ctrl+Z sets it back", mover.position, Vector2.ZERO],
	]) and passed

	# A project setting (not saved here: the suite never writes project.godot).
	var key: String = "eventforge_test/undo_steps_probe"
	steps.project_setting_step(key, {"events": []}, "Add control", false, undo)
	var written: bool = ProjectSettings.has_setting(key)
	undo.undo()
	passed = SUPPORT.pins(TEST_NAME, [
		["a setting step writes the setting", written, true],
		["Ctrl+Z clears it", ProjectSettings.has_setting(key), false],
	]) and passed
	for node: Node in [child, mover, root]:
		node.free()
	return passed
