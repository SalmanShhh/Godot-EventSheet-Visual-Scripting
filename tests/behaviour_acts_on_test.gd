# Godot EventSheets - a behaviour's "Acts on" field.
#
# THE ONE THING THIS FILE IS ABOUT: Acts on is empty by default and then the host is the parent,
# exactly as before; set, the host is the node it names, wherever the behaviour sits. A scene saved
# before the field existed loads with it empty, so nothing changes for it.
@tool
class_name BehaviourActsOnTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME: String = "behaviour_acts_on"
const PACK: GDScript = preload("res://eventsheet_addons/platformer_movement/platformer_movement_behavior.gd")


static func run() -> bool:
	var ok: bool = true
	var source: String = PACK.source_code
	ok = SUPPORT.check(TEST_NAME, "the shipped pack declares an exported Acts on of its host type",
		source.contains("@export var acts_on: CharacterBody2D = null"), true) and ok
	ok = SUPPORT.check(TEST_NAME, "the pack documents it in one sentence",
		source.contains("## @ace_hidden\n## The node this behavior acts on. Empty: its parent.\n@export var acts_on"), true) and ok

	# Empty: the parent, as before.
	var body: CharacterBody2D = CharacterBody2D.new()
	var behaviour: Node = PACK.new() as Node
	body.add_child(behaviour)
	behaviour.call("_enter_tree")
	ok = SUPPORT.check(TEST_NAME, "with Acts on empty the host is the parent", behaviour.get("host") == body, true) and ok

	# Set: the named node, wherever the behaviour sits.
	var folder: Node = Node.new()
	var elsewhere: Node = PACK.new() as Node
	var target: CharacterBody2D = CharacterBody2D.new()
	folder.add_child(elsewhere)
	elsewhere.set("acts_on", target)
	elsewhere.call("_enter_tree")
	ok = SUPPORT.check(TEST_NAME, "with Acts on set the host is that node, not the parent", elsewhere.get("host") == target, true) and ok

	# A wrong parent and nothing set: no host, which is what the warning words are about.
	var crate: Node2D = Node2D.new()
	var stray: Node = PACK.new() as Node
	crate.add_child(stray)
	stray.call("_enter_tree")
	ok = SUPPORT.check(TEST_NAME, "under the wrong parent with Acts on empty there is no host", stray.get("host"), null) and ok

	for node: Node in [body, folder, target, crate]:
		node.free()
	return ok
