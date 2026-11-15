# Godot EventSheets - a movement pack under a rigid body says what will go wrong, once.
#
# A movement pack writes its host's position or scale every frame. For a RigidBody2D or RigidBody3D
# the physics engine moves the body too, so the two fight (jitter, snapping back, passing through
# walls) - and nothing said so. What each pack DOES is a promise and does not change; each now pushes
# one plain warning when it becomes ready with such a host, naming the node, what it changes and what
# to put it on instead. This loads each COMPILED pack, readies it under a RigidBody with an ear on the
# engine's warnings, and pins the exact text. It pins the other half as firmly: the same pack under a
# plain node, or under a character body (which code moves on purpose), says nothing at all.
@tool
class_name PackPhysicsHostWarningsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME := "pack_physics_host_warnings_test"
const ROOT := "res://eventsheet_addons/"

## [folder/file, the pack's name as the warning says it, what it changes, the node to put it on instead].
## The dimension comes from the folder: a folder ending in _3d is a 3D pack.
const GLIDING: Array = [
	["move_to/move_to_behavior.gd", "Move To", "position", "Sprite2D"],
	["move_to_3d/move_to_3d_behavior.gd", "Move To 3D", "position", "MeshInstance3D"],
	["follow/follow_behavior.gd", "Follow", "position", "Sprite2D"],
	["follow_path/path_follow_behavior.gd", "Follow Path", "position", "Sprite2D"],
	["orbit/orbit_behavior.gd", "Orbit", "position", "Sprite2D"],
	["orbit_3d/orbit_3d_behavior.gd", "Orbit 3D", "position", "MeshInstance3D"],
	["tile_movement/tile_movement_behavior.gd", "Tile Movement", "position", "Sprite2D"],
]
const WAVING: Array = [
	["sine/sine_behavior.gd", "Sine", "position or scale", "Sprite2D"],
	["sine_3d/sine_3d_behavior.gd", "Sine 3D", "position", "MeshInstance3D"],
	["spring/spring_behavior.gd", "Spring", "position and scale", "Sprite2D"],
	["juice/juice_behavior.gd", "Juice", "position and scale", "Sprite2D"],
]


static func run() -> bool:
	var ok: bool = true
	ok = _packs("the gliding packs", GLIDING) and ok
	ok = _packs("the waving packs", WAVING) and ok
	return ok


## Runs `action` with an ear on the engine's warnings and returns what was said.
static func _heard(action: Callable) -> Array:
	var ear: SUPPORT.WarningEar = SUPPORT.WarningEar.new()
	OS.add_logger(ear)
	action.call()
	OS.remove_logger(ear)
	return ear.heard


## A pack readied under a parent: it binds its host as it enters the tree, then becomes ready.
static func _ready_under(script: GDScript, parent: Node) -> Node:
	var pack: Node = script.new()
	pack.name = "Mover"
	parent.add_child(pack)
	pack._enter_tree()
	pack._ready()
	return pack


static func _sentence(entry: Array, body: String) -> String:
	return "%s on Mover: this behaviour moves a %s by changing its %s, but the physics engine moves that body too, so the two will fight (jitter, snapping back, passing through walls). Put the behaviour under a node that is not a physics body, such as the %s inside it, or move the body with apply_central_impulse() or its linear_velocity instead." % [
		entry[1], body, entry[2], entry[3]]


static func _packs(label: String, entries: Array) -> bool:
	var rows: Array = []
	for entry: Array in entries:
		var script: GDScript = load(ROOT + str(entry[0]))
		var three: bool = str(entry[0]).get_base_dir().ends_with("_3d")
		var body: String = "RigidBody3D" if three else "RigidBody2D"
		var parent: Node = ClassDB.instantiate(body)
		var said: Array = _heard(func() -> void: _ready_under(script, parent).free())
		rows.append(["%s: %s under a %s says what will go wrong, once" % [label, entry[1], body], said, [_sentence(entry, body)]])
		parent.free()
		var plain: Node = Node3D.new() if three else Node2D.new()
		rows.append(["%s: %s under a plain node says nothing" % [label, entry[1]], _heard(func() -> void: _ready_under(script, plain).free()), []])
		plain.free()
		var character: Node = ClassDB.instantiate("CharacterBody3D" if three else "CharacterBody2D")
		rows.append(["%s: %s under a character body says nothing" % [label, entry[1]], _heard(func() -> void: _ready_under(script, character).free()), []])
		character.free()
	return SUPPORT.pins(NAME, rows)
