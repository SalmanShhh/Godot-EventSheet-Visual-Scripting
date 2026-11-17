# Godot EventSheets - the juice cards that change the scene: collision, removing a node, draw order,
# switching a node off, looking at and turning, and shaking an object's angle.
#
# THE ONE THING THIS FILE IS ABOUT: each card sets a property Godot really has, on the classes Godot
# really puts it on, and starts with numbers that do something the moment it is played. The class a
# card accepts is checked against Godot's own class list here, so a card that names a property no
# class has, or a class that does not exist, fails this file before anybody drops it on a node. And a
# value two cards both change goes back only when the LAST of them is done, to what it was before
# the FIRST touched it.
#
# What the cards do on a running tree (a shape switched off inside a collision callback, a z index
# past 4096, a node switched off freezing the tweens of the player under it) was measured frame by
# frame outside the suite, which has no scene tree.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "juice_scene_cards"

const PACK: String = "res://eventsheet_addons/juice/juice_player.gd"
const SCHEMA: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"

## Each card: its word, the family it is saved under, the property it sets, the classes it accepts,
## and a starting value that is felt (field key, value).
const CARDS: Array = [
	["collision_for", "scene", "disabled", ["CollisionShape2D", "CollisionShape3D", "CollisionPolygon2D", "CollisionPolygon3D"], ["seconds", 0.5]],
	["collision_layer_for", "scene", "collision_layer", ["CollisionObject2D", "CollisionObject3D"], ["layer", 1]],
	["remove_node", "scene", "", ["Node"], ["after_list", true]],
	["draw_order", "scene", "z_index", ["CanvasItem"], ["z_index", 10]],
	["switch_node", "scene", "process_mode", ["Node"], ["seconds", 0.5]],
	["look_at", "transform", "rotation", ["Node2D", "Node3D"], ["seconds", 0.2]],
	["rotate_by", "transform", "rotation", ["Node2D", "Node3D", "Control"], ["degrees", 45.0]],
	["rotate_to", "transform", "rotation", ["Node2D", "Node3D", "Control"], ["degrees", 90.0]],
	["rotation_shake", "transform", "rotation", ["Node2D", "Node3D", "Control"], ["degrees", 10.0]],
]

## A physics body's transform belongs to the physics server: the turning cards refuse these.
const REFUSED_FOR_TURNING: PackedStringArray = ["RigidBody2D", "RigidBody3D"]


static func run() -> bool:
	var ok: bool = true
	ok = _godot_pins() and ok
	ok = _kind_pins() and ok
	ok = _family_pins() and ok
	ok = _hold_pins() and ok
	ok = _length_pins() and ok
	return ok


## The Godot facts the cards stand on, asked of Godot itself.
static func _godot_pins() -> bool:
	var area: Area2D = Area2D.new()
	var item: Node2D = Node2D.new()
	var camera: Camera2D = Camera2D.new()
	var rows: Array = [
		["a 2D shape has a disabled tick", ClassDB.class_has_method("CollisionShape2D", "set_disabled"), true],
		["a 3D polygon has one too", ClassDB.class_has_method("CollisionPolygon3D", "set_disabled"), true],
		["an area has no disabled tick of its own", "disabled" in area, false],
		["a collision object starts on layer 1", area.collision_layer, 1],
		["and switched off it leaves the world (Disable Mode Remove)", area.disable_mode, CollisionObject2D.DISABLE_MODE_REMOVE],
		["z index starts at 0", item.z_index, 0],
		["a Control cannot look at a point", ClassDB.class_has_method("Control", "look_at"), false],
		["a 2D camera ignores rotation unless told", camera.ignore_rotation, true],
		["a 2D camera has no cull mask (the viewport has)", "cull_mask" in camera, false],
		["a collision object can set one mask layer by number", ClassDB.class_has_method("CollisionObject2D", "set_collision_mask_value"), true],
		["and one layer", ClassDB.class_has_method("CollisionObject3D", "set_collision_layer_value"), true],
	]
	area.free()
	item.free()
	camera.free()
	return SUPPORT.pins(TEST_NAME, rows)


## Each card is in the Add box, names a node to act on, starts with a value that does something, and
## accepts only classes that exist and carry the property it sets.
static func _kind_pins() -> bool:
	var rows: Array = []
	for card: Array in CARDS:
		var word: String = card[0]
		var kind: Dictionary = _kind(word)
		var keys: PackedStringArray = _keys_of(kind)
		rows.append(["%s is a card" % word, kind.is_empty(), false])
		rows.append(["%s names the node it acts on" % word, keys.has("node"), true])
		var starts: Array = card[4]
		rows.append(["%s starts with %s %s" % [word, starts[0], str(starts[1])], (kind.get("defaults", {}) as Dictionary).get(starts[0]), starts[1]])
		var accepts: Array = kind.get("accepts", [])
		rows.append(["%s accepts the classes Godot puts its property on" % word, ",".join(PackedStringArray(accepts)), ",".join(PackedStringArray(card[3]))])
		for named: Variant in accepts:
			var real: bool = ClassDB.class_exists(str(named))
			var carries: bool = str(card[2]).is_empty() or _class_has_property(str(named), str(card[2]))
			rows.append(["%s: %s exists and has %s" % [word, named, card[2]], real and carries, true])
		if card[1] == "transform":
			rows.append(["%s refuses a rigid body" % word, ",".join(PackedStringArray(kind.get("refuses", []))), ",".join(REFUSED_FOR_TURNING)])
		else:
			rows.append(["%s refuses nothing" % word, (kind.get("refuses", []) as Array).size(), 0])
	var draw: Dictionary = _kind("draw_order")
	rows.append(["Draw Order keeps its number inside Godot's range", str(_field(draw, "z_index").get("range", "")), "-4096,4096"])
	var remove: Dictionary = _kind("remove_node")
	rows.append(["Remove Node waits for the list to end by default", (remove.get("defaults", {}) as Dictionary).get("after_list"), true])
	var shake: Dictionary = _kind("rotation_shake")
	rows.append(["Rotation Shake has the same Fade out tick as Shake, ticked", (shake.get("defaults", {}) as Dictionary).get("fade_out"), true])
	rows.append(["and the same Fade in tick, a curve and the drawing of the shape", _keys_of(shake).slice(3, 7), PackedStringArray(["fade_in", "fade_out", "curve", "shake_shape"])])
	var switched: Dictionary = _kind("switch_node")
	rows.append(["Switch Node has a tick for each of the three things Godot has", _keys_of(switched).slice(1, 4), PackedStringArray(["do", "visible", "process"])])
	var starting: Dictionary = switched.get("defaults", {})
	rows.append(["it hides and stops its scripts to begin with, and leaves collision alone", [starting.get("visible"), starting.get("process"), starting.get("collision")], [true, true, false]])
	var layer: Dictionary = _kind("collision_layer_for")
	var layer_start: Dictionary = layer.get("defaults", {})
	rows.append(["Collision Layer starts by taking a mask layer off", [layer_start.get("part"), layer_start.get("on")], ["mask", false]])
	rows.append(["and its layer number is held to 1 to 32", str(_field(layer, "layer").get("range", "")), "1,32"])
	rows.append(["Look At names the node it faces", _keys_of(_kind("look_at")).has("target"), true])
	return SUPPORT.pins(TEST_NAME, rows)


## One family per word, the same in the Inspector and in the game.
static func _family_pins() -> bool:
	var families: Variant = (load(PACK) as GDScript).get_script_constant_map().get("CATEGORY_OF")
	var table: Dictionary = families if families is Dictionary else {}
	var words: Variant = (load(PACK) as GDScript).get_script_constant_map().get("WORLD_WORDS")
	var rows: Array = []
	for card: Array in CARDS:
		rows.append(["%s is a %s card in the game" % [card[0], card[1]], str(table.get(card[0], "")), card[1]])
		rows.append(["%s is the same family in the Inspector" % card[0], str(_kind(card[0]).get("category", "")), card[1]])
		rows.append(["%s is played by the player itself" % card[0], (words as PackedStringArray).has(card[0]) if words is PackedStringArray else false, true])
	return SUPPORT.pins(TEST_NAME, rows)


## A value two cards change goes back only when the last of them is done, to what it was before the first.
## Run on a player that has never been in a tree: the hold is plain bookkeeping, the clock is not needed.
static func _hold_pins() -> bool:
	var script: GDScript = load(PACK) as GDScript
	var player: Node = script.new() as Node
	var item: Node2D = Node2D.new()
	var first: Dictionary = player.call("_hold", item, "z_index", 10)
	var second: Dictionary = player.call("_hold", item, "z_index", 20)
	var while_both: int = item.z_index
	player.call("_end_hold", first)
	var after_first: int = item.z_index
	player.call("_end_hold", second)
	var after_both: int = item.z_index
	player.call("_end_hold", second)
	var after_a_second_end: int = item.z_index
	# A hold let go by Stop is let go for good: a timer that comes later cannot end the next one.
	var third: Dictionary = player.call("_hold", item, "z_index", 30)
	player.call("_release_holds")
	var after_release: int = item.z_index
	var fourth: Dictionary = player.call("_hold", item, "z_index", 40)
	player.call("_end_hold", third)
	var stale_timer: int = item.z_index
	player.call("_end_hold", fourth)
	# What Restore puts back is what the property was before the FIRST card.
	var written: Array = player.get("_restore_to")
	var restore_value: Variant = (written[0] as Dictionary).get("value") if not written.is_empty() else null
	# A layer is held bit by bit: two cards on two layers of one mask keep their own way back.
	var area: Area2D = Area2D.new()
	area.collision_mask = 0b101
	var on_one: Dictionary = player.call("_hold", area, "collision_mask", false, true, 1)
	var on_two: Dictionary = player.call("_hold", area, "collision_mask", false, true, 2)
	var held: Dictionary = script.get("_holds")
	var before_one: Variant = (held.get(on_one.get("key")) as Dictionary).get("before")
	var before_two: Variant = (held.get(on_two.get("key")) as Dictionary).get("before")
	# Two players that change one thing agree on what it goes back to, and one letting go leaves the other's hold.
	var other: Node = script.new() as Node
	var thing: Node2D = Node2D.new()
	player.call("_hold", thing, "z_index", 10)
	other.call("_hold", thing, "z_index", 20)
	player.call("_release_holds")
	var other_still_holds: int = thing.z_index
	other.call("_release_holds")
	var both_gone: int = thing.z_index
	var rows: Array = [
		["two players on one z index: one letting go leaves the other's hold", other_still_holds, 20],
		["and the last one gives back what it was before either", both_gone, 0],
		["two holds on a z index: the later number wins while both hold", while_both, 20],
		["the first one ending leaves it where the second put it", after_first, 20],
		["the last one ending gives back what it was before the first", after_both, 0],
		["ending a hold twice does nothing the second time", after_a_second_end, 0],
		["a release puts everything back at once", after_release, 0],
		["and a timer from before the release cannot end the next hold", stale_timer, 40],
		["the last end gives it back", item.z_index, 0],
		["Restore would write the value from before the first card", restore_value, 0],
		["a layer hold remembers whether that layer was on (layer 1 was)", before_one, true],
		["and layer 2, which was off", before_two, false],
		["a hold on a node that is gone is no hold at all", (player.call("_hold", null, "z_index", 5) as Dictionary).is_empty(), true],
	]
	area.free()
	item.free()
	thing.free()
	player.free()
	other.free()
	(script.get("_holds") as Dictionary).clear()
	return SUPPORT.pins(TEST_NAME, rows)


## How long a card takes, and what the editor does with it.
static func _length_pins() -> bool:
	var script: GDScript = load(PACK) as GDScript
	var skipped: Array = []
	for word: String in ["remove_node", "switch_node", "collision_for", "collision_layer_for"]:
		skipped.append(str(script.call("editor_kind", word)).begins_with("skipped:"))
	var felt: Array = []
	for word: String in ["look_at", "rotate_by", "rotate_to", "rotation_shake", "draw_order"]:
		felt.append(script.call("editor_kind", word))
	return SUPPORT.pins(TEST_NAME, [
		["a Collision card is as long as its seconds", script.call("card_length", {"verb": "collision_for", "seconds": 0.5}), 0.5],
		["a Draw Order card too", script.call("card_length", {"verb": "draw_order", "seconds": 0.7}), 0.7],
		["a Rotate By card too", script.call("card_length", {"verb": "rotate_by", "seconds": 0.2}), 0.2],
		["a Rotation Shake card too", script.call("card_length", {"verb": "rotation_shake", "seconds": 0.3}), 0.3],
		["the editor leaves alone the cards that would change a node of your scene or need physics", skipped, [true, true, true, true]],
		["and plays the cards that only change a property of a node", felt, ["felt", "felt", "felt", "felt", "felt"]],
	])


static func _kind(word: String) -> Dictionary:
	var schema: Dictionary = (load(SCHEMA) as GDScript).call("schema")
	for kind: Variant in schema.get("kinds", []):
		if str((kind as Dictionary).get("kind", "")) == word:
			return kind as Dictionary
	return {}


static func _field(kind: Dictionary, key: String) -> Dictionary:
	for field: Variant in kind.get("fields", []):
		if str((field as Dictionary).get("key", "")) == key:
			return field as Dictionary
	return {}


static func _keys_of(kind: Dictionary) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	for field: Variant in kind.get("fields", []):
		keys.append(str((field as Dictionary).get("key", "")))
	return keys


static func _class_has_property(named: String, property: String) -> bool:
	for entry: Dictionary in ClassDB.class_get_property_list(named, false):
		if str(entry.get("name", "")) == property:
			return true
	return false
