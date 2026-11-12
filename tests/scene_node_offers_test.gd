@tool
class_name SceneNodeOffersTest
extends RefCounted

# Pins what Godot's own scene data decides about a canvas drop: a node in the group `secret` is
# offered the secrets counter, a node in the group `water` the two water rows, and a node whose
# script exports `needs_key` the door event. The scene is a real .tscn written under user:// and
# loaded back, because groups live in the scene file and only a persistent group survives a pack.

const SUPPORT := preload("res://tests/support.gd")
const OFFERS := preload("res://addons/eventsheet/editor/dock/scene_node_offers.gd")
const NAME := "scene_node_offers_test"
const SCENE_PATH := "user://scene_node_offers_level.tscn"
const DOOR_SCRIPT_PATH := "user://scene_node_offers_door.gd"
const PLAIN_SCRIPT_PATH := "user://scene_node_offers_plain.gd"


static func run() -> bool:
	var ok: bool = true
	var root: Node = _level_root()
	ok = _the_groups(root) and ok
	ok = _the_door_variable(root) and ok
	ok = _the_lookup(root) and ok
	ok = _nothing_extra(root) and ok
	root.free()
	return ok


## Writes the scene file, loads it back and returns the instanced root.
static func _level_root() -> Node:
	_write_script(DOOR_SCRIPT_PATH, "extends StaticBody3D\n@export var needs_key: String = \"red_key\"\n")
	_write_script(PLAIN_SCRIPT_PATH, "extends StaticBody3D\nvar needs_key: String = \"red_key\"\n")
	var level: Node3D = Node3D.new()
	level.name = "Level"
	_add(level, Area3D.new(), "SecretRoom").add_to_group("secret", true)
	_add(level, Area3D.new(), "Pool").add_to_group("water", true)
	_add(level, Area3D.new(), "Plain")
	_add(level, StaticBody3D.new(), "RedDoor").set_script(load(DOOR_SCRIPT_PATH))
	_add(level, StaticBody3D.new(), "NotExported").set_script(load(PLAIN_SCRIPT_PATH))
	var packed: PackedScene = PackedScene.new()
	packed.pack(level)
	ResourceSaver.save(packed, SCENE_PATH)
	level.free()
	return (ResourceLoader.load(SCENE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()


static func _add(parent: Node, child: Node, node_name: String) -> Node:
	child.name = node_name
	parent.add_child(child)
	child.owner = parent
	return child


static func _write_script(path: String, source: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(source)
	file.close()


static func _the_groups(root: Node) -> bool:
	var ok: bool = true
	ok = SUPPORT.check(NAME, "a node in the secret group is a secret",
		OFFERS.is_secret(root.get_node("SecretRoom")), true) and ok
	ok = SUPPORT.check(NAME, "a node in the water group is water",
		OFFERS.is_water(root.get_node("Pool")), true) and ok
	ok = SUPPORT.check(NAME, "a secret is not water",
		OFFERS.is_water(root.get_node("SecretRoom")), false) and ok
	ok = SUPPORT.check(NAME, "water is not a secret",
		OFFERS.is_secret(root.get_node("Pool")), false) and ok
	ok = SUPPORT.check(NAME, "the group names are the plain literals",
		[OFFERS.SECRET_GROUP, OFFERS.WATER_GROUP], ["secret", "water"]) and ok
	return ok


static func _the_door_variable(root: Node) -> bool:
	var ok: bool = true
	ok = SUPPORT.check(NAME, "a script exporting needs_key makes a door",
		OFFERS.is_locked_door(root.get_node("RedDoor")), true) and ok
	ok = SUPPORT.check(NAME, "a needs_key that is not exported does not",
		OFFERS.is_locked_door(root.get_node("NotExported")), false) and ok
	ok = SUPPORT.check(NAME, "a node with no script does not",
		OFFERS.is_locked_door(root.get_node("Plain")), false) and ok
	return ok


static func _the_lookup(root: Node) -> bool:
	var ok: bool = true
	ok = SUPPORT.check(NAME, "the offer for each node, by value",
		[OFFERS.offer_for(root.get_node("SecretRoom")), OFFERS.offer_for(root.get_node("RedDoor")),
			OFFERS.offer_for(root.get_node("Pool")), OFFERS.offer_for(root.get_node("Plain"))],
		["secret", "door", "water", ""]) and ok
	ok = SUPPORT.check(NAME, "a label finds its node",
		OFFERS.find_node(root, "SecretRoom").name, &"SecretRoom") and ok
	ok = SUPPORT.check(NAME, "the census reference is tried first",
		OFFERS.find_node(root, "secret_room", "$SecretRoom").name, &"SecretRoom") and ok
	return ok


static func _nothing_extra(root: Node) -> bool:
	var ok: bool = true
	ok = SUPPORT.check(NAME, "a label the scene does not hold finds nothing",
		OFFERS.find_node(root, "Ghost") == null, true) and ok
	ok = SUPPORT.check(NAME, "no scene open finds nothing",
		OFFERS.find_node(null, "SecretRoom") == null, true) and ok
	ok = SUPPORT.check(NAME, "and no node offers nothing", OFFERS.offer_for(null), "") and ok
	ok = SUPPORT.check(NAME, "outside the editor there is no open scene to ask",
		OFFERS.offer_in_open_scene("SecretRoom"), "") and ok
	return ok
