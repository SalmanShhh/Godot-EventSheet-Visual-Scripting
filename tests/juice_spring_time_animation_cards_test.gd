# Godot EventSheets - the Spring card, Slow One Object, and the Animation Parameter card.
#
# THE ONE THING THIS FILE IS ABOUT: the cards speak Godot's own terms and only offer what really
# moves. A spring kicks the kinds of value the Spring pack can spring (never a Vector4) and leaves the
# settling to the Spring node; "slow one object" means the speed_scale the engine's animation and
# particle nodes have (an AnimationTree has none, and the game's own scripts keep their speed); and
# the animation card offers only an AnimationTree's parameters that can be written.
#
# Measured outside the suite on a running tree: every spring landed EXACTLY on its target (float,
# int, Vector2, Vector3 and Colour), a Vector4 was refused with a warning, Engine.time_scale reached a
# node set to Process Mode Always as well (so one object cannot be kept at full speed by it), and an
# AnimationPlayer's speed_scale multiplied with the game's time scale.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "juice_spring_time_animation_cards"

const PACK: String = "res://eventsheet_addons/juice/juice_player.gd"
const SCHEMA: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
const SPRING: String = "res://eventsheet_addons/spring/spring_behavior.gd"

## The engine nodes that have a speed of their own.
const SPEED_CLASSES: PackedStringArray = ["AnimationPlayer", "AnimatedSprite2D", "AnimatedSprite3D",
	"GPUParticles2D", "CPUParticles2D", "GPUParticles3D", "CPUParticles3D"]


static func run() -> bool:
	var ok: bool = true
	ok = _godot_pins() and ok
	ok = _spring_pins() and ok
	ok = _slow_pins() and ok
	ok = _animation_pins() and ok
	return ok


## Green today; must stay green.
static func _godot_pins() -> bool:
	var rows: Array = [
		["an AnimationTree has no speed_scale", ClassDB.class_has_method("AnimationTree", "set_speed_scale"), false],
		["an AnimationPlayer has no loop property (the Animation has loop_mode)", ClassDB.class_has_method("AnimationPlayer", "set_loop"), false],
		["Animation.loop_mode exists", ClassDB.class_has_method("Animation", "set_loop_mode"), true],
	]
	for named: String in SPEED_CLASSES:
		rows.append(["%s has speed_scale" % named, ClassDB.class_has_method(named, "set_speed_scale"), true])
	return SUPPORT.pins(TEST_NAME, rows)


## The Spring card leans on a Spring node under the node, in the Spring pack's own words.
static func _spring_pins() -> bool:
	var kind: Dictionary = _kind("spring")
	var text: String = FileAccess.get_file_as_string(SPRING)
	var script: GDScript = load(PACK)
	var keys: PackedStringArray = PackedStringArray()
	for field: Variant in kind.get("fields", []):
		keys.append(str((field as Dictionary).get("key", "")))
	var holder: Node2D = Node2D.new()
	var plain: Node2D = Node2D.new()
	var spring: Node = (load(SPRING) as GDScript).new() as Node
	holder.add_child(spring)
	var rows: Array = [
		["the Spring pack still springs a property", text.contains("func bump_property(property_path: String, amount: Variant) -> void:"), true],
		["the Spring card is in the Add box", str(kind.get("label", "")), "Spring"],
		["it is an Object card", str(kind.get("category", "")), "transform"],
		["it names the node, the property, the kick and the Spring node's two numbers", ",".join(keys).begins_with("node,property,kick,damping,frequency"), true],
		["a new card kicks the scale", str((kind.get("defaults", {}) as Dictionary).get("property", "")), "scale"],
		["it says it needs a Spring node", str(kind.get("help", "")).contains("Spring node"), true],
		["the two numbers are left to the Spring node until they are touched", [(_field(kind, "damping")).has("default"), (_field(kind, "frequency")).has("default")], [false, false]],
		["the Spring node under a node is found", script.call("spring_of", holder) == spring, true],
		["a node with no Spring node has none", script.call("spring_of", plain) == null, true],
		["a float kick is a number", script.call("spring_kick", 2.0, 1.0, 1.0), 2.0],
		["a kick on a Vector2 stays a Vector2 and follows the strength", script.call("spring_kick", Vector2(2.0, 4.0), Vector2.ONE, 0.5), Vector2(1.0, 2.0)],
		["a number given for a Vector2 kicks both sides", script.call("spring_kick", 2.0, Vector2.ONE, 1.0), Vector2(2.0, 2.0)],
		["a kick on a Vector3", script.call("spring_kick", Vector3(1.0, 2.0, 3.0), Vector3.ONE, 1.0), Vector3(1.0, 2.0, 3.0)],
		["a kick on a colour", script.call("spring_kick", Color(1.0, 0.0, 0.0, 0.0), Color.WHITE, 1.0), Color(1.0, 0.0, 0.0, 0.0)],
		["it is only offered for a Node2D", ",".join(PackedStringArray(kind.get("accepts", []))), "Node2D"],
		["it is not part of a skip to the end", _text(PACK).contains("\"spring\", \"slow_object\", \"animation_parameter\""), true],
		["it is never previewed in the editor", str(script.call("editor_kind", "spring")).begins_with("skipped:"), true],
	]
	holder.free()
	plain.free()
	return SUPPORT.pins(TEST_NAME, rows)


## Slow One Object: the speed of what has one, listed, and the plain words that the rest keeps its pace.
static func _slow_pins() -> bool:
	var kind: Dictionary = _kind("slow_object")
	var script: GDScript = load(PACK)
	var root: Node = Node.new()
	var player: AnimationPlayer = AnimationPlayer.new()
	var sparks: CPUParticles2D = CPUParticles2D.new()
	var script_only: Node = Node.new()
	var tree: AnimationTree = AnimationTree.new()
	for child: Node in [player, sparks, script_only, tree]:
		root.add_child(child)
	var found: Array = script.call("speed_nodes_under", root)
	var inner: Node = Node.new()
	var deep: Node2D = Node2D.new()
	deep.add_child(inner)
	var none: Array = script.call("speed_nodes_under", deep)
	var rows: Array = [
		["the card is in the Add box", str(kind.get("label", "")), "Slow One Object"],
		["it is a Time card", str(kind.get("category", "")), "pause"],
		["a new card slows to 0.3", (kind.get("defaults", {}) as Dictionary).get("speed"), 0.3],
		["for half a second", (kind.get("defaults", {}) as Dictionary).get("seconds"), 0.5],
		["it says the object's own scripts keep their speed", str(kind.get("help", "")).contains("own keep their speed"), true],
		["it says it multiplies with Slowmo", str(kind.get("help", "")).contains("multiplies with Slowmo"), true],
		["it finds an animation player and a particles node", found.has(player) and found.has(sparks), true],
		["it never finds a script-only node or an animation tree", found.has(script_only) or found.has(tree), false],
		["a node that has a speed itself is found", (script.call("speed_nodes_under", player) as Array).size(), 1],
		["nothing under a plain node is nothing", none.size(), 0],
		["it is as long as its seconds", script.call("card_length", {"verb": "slow_object", "seconds": 0.5}), 0.5],
	]
	root.free()
	deep.free()
	return SUPPORT.pins(TEST_NAME, rows)


## The animation card offers an AnimationTree's writable parameters only.
static func _animation_pins() -> bool:
	var tree: AnimationTree = AnimationTree.new()
	var blend: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	blend.add_node("speed", AnimationNodeTimeScale.new())
	blend.add_node("mix", AnimationNodeBlend2.new())
	blend.add_node("jump", AnimationNodeOneShot.new())
	blend.add_node("states", AnimationNodeStateMachine.new())
	tree.tree_root = blend
	var script: GDScript = load(PACK)
	var offered: PackedStringArray = script.call("writable_parameters", tree)
	var listed: int = 0
	for entry: Dictionary in tree.get_property_list():
		if str(entry.get("name", "")).begins_with("parameters/"):
			listed += 1
	var none: PackedStringArray = script.call("writable_parameters", null)
	tree.free()
	var kind: Dictionary = _kind("animation_parameter")
	return SUPPORT.pins(TEST_NAME, [
		["Godot lists the tree's parameters without a scene tree", listed > 0, true],
		["the card is in the Add box", str(kind.get("label", "")), "Animation Parameter"],
		["it is an Object card", str(kind.get("category", "")), "transform"],
		["it offers the numbers and the one-shot request, never a read-only time or the playback object",
			",".join(offered), "parameters/speed/scale,parameters/mix/blend_amount,parameters/jump/request"],
		["no tree offers nothing", none.size(), 0],
		["it takes its back time on top of its walk", script.call("card_length", {"verb": "animation_parameter", "seconds": 0.2, "back": true, "back_seconds": 0.3}), 0.5],
		["and no more when it does not go back", script.call("card_length", {"verb": "animation_parameter", "seconds": 0.2, "back": false, "back_seconds": 0.3}), 0.2],
		["it accepts only an animation tree", ",".join(PackedStringArray(kind.get("accepts", []))), "AnimationTree"],
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


static func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)
