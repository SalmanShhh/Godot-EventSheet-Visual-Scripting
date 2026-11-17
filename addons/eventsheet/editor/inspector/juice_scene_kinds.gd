# Godot EventSheets - the juice cards that change the scene, the light, the look and the sound
# (editor-only, UI-free).
#
# Collision off for a time, a collision layer for a time, removing a node, drawing a 2D node in front,
# switching a node off, facing another node, turning by or to an angle, shaking an angle, flaring a light,
# moving a value of the scene's look and holding an effect of an audio bus. Each kind is plain data: the
# fields it has, the classes it accepts (the card's node picker offers only those, and the quiet amber line
# under a card says when the picked node is none of them), and the one sentence that says what it does. What
# each card DOES when it plays is the pack's, written in the Juice Player itself.
#
# Every number a card starts with is one that is FELT the moment the card is played, and every node is
# picked, never typed. The amber lines are computed from the edited player and the node a card points at, and
# are never stored.
#
# Loaded by path from the juice card kinds, so the first open of the editor does not compile it.
@tool
extends RefCounted

const FIELDS_PATH: String = "res://addons/eventsheet/editor/inspector/juice_card_fields.gd"
const SHAKE_PATH: String = "res://addons/eventsheet/editor/inspector/juice_shake_fields.gd"
const ENVIRONMENT_WORDS_PATH: String = "res://addons/eventforge/registration/environment_words.gd"
const CAMERA_WORDS_PATH: String = "res://addons/eventforge/registration/camera_attribute_words.gd"

## The classes of a collision shape: the nodes that carry a `disabled` tick.
const SHAPES: Array = ["CollisionShape2D", "CollisionShape3D", "CollisionPolygon2D", "CollisionPolygon3D"]

## The classes that carry a collision layer and a mask.
const BODIES: Array = ["CollisionObject2D", "CollisionObject3D"]

## The classes a turning card can turn: a 2D node and a Control by `rotation`, a 3D node about its up axis.
const TURNABLE: Array = ["Node2D", "Node3D", "Control"]

## The classes the physics engine turns itself, which a turning card refuses.
const REFUSED_FOR_TURNING: Array = ["RigidBody2D", "RigidBody3D"]

## The lights a Light card flares.
const LIGHTS: Array = ["Light2D", "Light3D"]

## The value of the scene's look a new Scene Look card moves: how strongly bright things glow.
const GLOW_STRENGTH: String = "glow_intensity"

## What a new Spring card kicks, by the name of the property, in the property's own units: a speed in units a second.
const SPRING_KICKS: Dictionary = {"scale": Vector2(3.0, 3.0), "position": Vector2(0.0, -200.0), "rotation": 8.0}

## The ways a Bus Effect card changes a bus.
const BUS_WAYS: String = "options:muffle=Muffle,dive=Dive,wash=Wash,switch=Switch an effect on"


static func fields() -> Script:
	return load(FIELDS_PATH) as Script


## Every kind this file adds, in the order the Add box lists them inside a family.
static func kinds(family_of: Dictionary) -> Array:
	var all: Array = []
	all.append_array(_scene_kinds(family_of))
	all.append_array(_turning_kinds(family_of))
	all.append_array(_light_look_sound_kinds(family_of))
	all.append_array(_time_kinds(family_of))
	return all


static func _kind(word: String, label: String, help: String, family_of: Dictionary, fields_list: Array, defaults: Dictionary,
		accepts: Array, search: Array = [], refuses: Array = []) -> Dictionary:
	return {
		"kind": word,
		"category": str(family_of.get(word, "")),
		"label": label,
		"help": help,
		"fields": fields_list,
		"live": [],
		"defaults": defaults,
		"accepts": accepts,
		"refuses": refuses,
		"search": PackedStringArray(search),
		"badge": EventSheetFeedbackCardSchema.seconds_badge
	}


## A node field that offers only the classes the card accepts. `empty` is what a card with no node picked means.
static func _node(key: String, label: String, types: Array, empty: String = "") -> Dictionary:
	return {"key": key, "label": label, "drawer": "node", "types": types, "empty": empty}


static func _over(label: String, default_seconds: float, show_if: String = "") -> Dictionary:
	var made: Dictionary = {"key": "seconds", "label": label, "drawer": "unit:time", "default": default_seconds}
	if not show_if.is_empty():
		made["show_if"] = show_if
	return made


## The quiet amber line under a card that points at the wrong kind of node, a body the physics engine turns, or
## a node that holds this player. One function per card word, so the sentence is the card's own.
static func _node_line(word: String, key: String = "node") -> Dictionary:
	var text: Callable = func(card: Dictionary, _cards: Array, _index: int, edited: Object) -> String:
		return node_note(word, card, edited, key)
	var care: Callable = func(card: Dictionary, _cards: Array, _index: int, edited: Object) -> bool:
		return not node_note(word, card, edited, key).is_empty()
	return {"key": key + "_note", "label": "", "drawer": "note", "text": text, "hide_empty": true, "warn_when": care}


static func _scene_kinds(family_of: Dictionary) -> Array:
	return [
		_kind("collision_for", "Collision For A Time",
			"Switches a collision shape off for a time, then on again: the moment after a hit when nothing can hurt you. Godot refuses a shape's disabled tick in the middle of a physics step, so the card waits for the safe moment.",
			family_of, [
				_node("node", "Shape", SHAPES),
				_over("For", 0.5),
				_node_line("collision_for")
			], {"seconds": 0.5}, SHAPES, ["hit", "invincible", "dodge", "disabled", "i-frames"]),
		_kind("collision_layer_for", "Collision Layer For A Time",
			"Takes a body or an area off a collision layer, or stops it seeing one, for a time: a ghost that walks through walls, a platform you drop through. It is changed at the safe moment, so it is fine to play from a collision.",
			family_of, [
				_node("node", "Body", BODIES),
				{"key": "part", "label": "Change", "drawer": "options:mask=What it sees (mask),layer=What it is on (layer)", "default": "mask"},
				{"key": "layer", "label": "Layer number", "drawer": "layer_pick", "default": 1},
				{"key": "on", "label": "Switch it on", "drawer": "bool", "default": false},
				_over("For", 0.5),
				_node_line("collision_layer_for")
			], {"part": "mask", "layer": 1, "on": false, "seconds": 0.5}, BODIES, ["layer", "mask", "ghost", "pass through", "one way"]),
		_kind("remove_node", "Remove Node",
			"Removes a node: handed back to its pool when it came from one, freed when it did not. After this list ends is ticked to begin with, so the sound and the particles of a death are not cut off.",
			family_of, [
				_node("node", "Node", ["Node"], "This object"),
				{"key": "after_list", "label": "After this list ends", "drawer": "bool", "default": true},
				_node_line("remove_node")
			], {"after_list": true}, ["Node"], ["destroy", "free", "kill", "queue_free", "despawn"]),
		_kind("draw_order", "Draw Order For A Time",
			"Brings a 2D node in front of the rest for a time, or sends it behind. 2D only: a 3D node is drawn by its distance from the camera.",
			family_of, [
				_node("node", "Node", ["CanvasItem"], "This object"),
				{"key": "z_index", "label": "Z index", "drawer": "int", "whole": true, "default": 10, "range": "-4096,4096"},
				_over("For", 0.5),
				_node_line("draw_order")
			], {"z_index": 10, "seconds": 0.5}, ["CanvasItem"], ["z index", "front", "behind", "layer", "sort"]),
		_kind("switch_node", "Switch Node On Or Off",
			"Godot has no active tick, so this does the three things it means, each with its own tick: hide it, stop its scripts, disable its collision. Off for a time, off for good, or back on.",
			family_of, [
				_node("node", "Node", ["Node"], "This object"),
				{"key": "do", "label": "Do", "drawer": "options:for_a_time=Switch off for a time,off=Switch off,on=Switch back on", "default": "for_a_time"},
				{"key": "visible", "label": "Hide it", "drawer": "bool", "default": true},
				{"key": "process", "label": "Stop its scripts", "drawer": "bool", "default": true},
				{"key": "collision", "label": "Disable its collision", "drawer": "bool", "default": false},
				_over("For", 0.5, "do==for_a_time"),
				_node_line("switch_node")
			], {"do": "for_a_time", "visible": true, "process": true, "collision": false, "seconds": 0.5}, ["Node"], ["activate", "deactivate", "hide", "disable", "enable"])
	]


static func _turning_kinds(family_of: Dictionary) -> Array:
	var shake_fields: Array = (load(SHAKE_PATH) as Script).call("fields")
	var swing: Array = [
		_node("node", "Node", TURNABLE, "This object"),
		{"key": "degrees", "label": "Swing", "drawer": "num", "default": 10.0, "suffix": "degrees"},
		{"key": "seconds", "label": "Over", "drawer": "unit:time", "default": 0.3},
		shake_fields[0], shake_fields[1], shake_fields[2], shake_fields[3],
		{"key": "rotation_says", "label": "", "drawer": "note", "text": rotation_says, "hide_empty": true},
		_node_line("rotation_shake")
	]
	return [
		_kind("look_at", "Look At",
			"Turns a node to face another node over a time: in 2D its right points at it, in 3D it turns the way Godot's own look at does.",
			family_of, [
				_node("node", "Node", ["Node2D", "Node3D"], "This object"),
				_node("target", "Look at", ["Node2D", "Node3D"]),
				_over("Over", 0.2),
				_node_line("look_at")
			], {"seconds": 0.2}, ["Node2D", "Node3D"], ["face", "aim", "point at", "turn towards"], REFUSED_FOR_TURNING),
		_kind("rotate_by", "Rotate By",
			"Turns a node by an angle over a time. On the sprite or mesh of a physics body, never on the body.",
			family_of, [
				_node("node", "Node", TURNABLE, "This object"),
				{"key": "degrees", "label": "Turn by", "drawer": "num", "default": 45.0, "suffix": "degrees"},
				_over("Over", 0.2),
				_node_line("rotate_by")
			], {"degrees": 45.0, "seconds": 0.2}, TURNABLE, ["spin", "turn", "rotation"], REFUSED_FOR_TURNING),
		_kind("rotate_to", "Rotate To",
			"Turns a node to an angle over a time, the short way round. On the sprite or mesh of a physics body, never on the body.",
			family_of, [
				_node("node", "Node", TURNABLE, "This object"),
				{"key": "degrees", "label": "Turn to", "drawer": "num", "default": 90.0, "suffix": "degrees"},
				_over("Over", 0.2),
				_node_line("rotate_to")
			], {"degrees": 90.0, "seconds": 0.2}, TURNABLE, ["spin", "turn", "rotation", "angle"], REFUSED_FOR_TURNING),
		_kind("rotation_shake", "Rotation Shake",
			"Wobbles the angle of a node, not its place, and settles it: a sign that rattles. It has the same fade ticks and curve as Shake.",
			family_of, swing, {"degrees": 10.0, "seconds": 0.3, "fade_out": true}, TURNABLE, ["wobble", "rattle", "tremble", "shake"], REFUSED_FOR_TURNING)
	]


static func _light_look_sound_kinds(family_of: Dictionary) -> Array:
	return [
		_kind("light", "Light",
			"Flares a light to a brightness and a colour and lets it go back by itself: a muzzle flash. It works on the 2D and 3D lights, and a light that was off is switched on for the flare.",
			family_of, [
				_node("node", "Light", LIGHTS, "This object"),
				{"key": "energy_from", "label": "Energy", "drawer": "optional", "empty": "From where it is"},
				{"key": "energy_to", "label": "", "drawer": "num", "default": 3.0, "beside": true, "to_word": "to"},
				{"key": "colour_from", "label": "Colour", "drawer": "optional_color", "empty": "From where it is", "sample": light_colour},
				{"key": "colour_to", "label": "", "drawer": "color_button", "default": Color(1.0, 0.6, 0.2), "beside": true, "to_word": "to"},
				_over("Over", 0.08),
				{"key": "back", "label": "Go back", "drawer": "bool", "default": true, "redraw": true},
				{"key": "back_seconds", "label": "Back over", "drawer": "unit:time", "default": 0.2, "show_if": "back"},
				{"key": "ease", "label": "Curve", "drawer": "options:out=Ease out,in=Ease in,in_out=Ease in and out,linear=Linear", "default": "out"},
				_node_line("light")
			], {"energy_to": 3.0, "colour_to": Color(1.0, 0.6, 0.2), "seconds": 0.08, "back": true, "back_seconds": 0.2, "ease": "out"},
			LIGHTS, ["muzzle flash", "lamp", "brightness", "energy", "flicker"]),
		_kind("scene_look", "Scene Look",
			"Moves one value of the look of the scene to a number and back: glow, brightness, contrast, saturation, exposure, fog. It changes the scene's own copy, so no other scene changes. In a 2D game the glow needs a WorldEnvironment whose background is set to Canvas.",
			family_of, [
				_node("node", "Node", ["WorldEnvironment", "Camera3D"], "The scene's WorldEnvironment"),
				{"key": "property", "label": "Value", "drawer": "options:" + look_choices(), "default": GLOW_STRENGTH},
				{"key": "to", "label": "To", "drawer": "num", "default": 2.0},
				_over("Over", 0.1),
				{"key": "back_seconds", "label": "Back over", "drawer": "unit:time", "default": 0.3},
				_node_line("scene_look")
			], {"property": GLOW_STRENGTH, "to": 2.0, "seconds": 0.1, "back_seconds": 0.3}, ["WorldEnvironment", "Camera3D"],
			["glow", "bloom", "fog", "saturation", "exposure", "environment", "post processing", "colour grade"]),
		_kind("bus_effect", "Bus Effect For A Time",
			"Holds an effect of an audio bus for a time and puts it back: a low-pass that muffles the world when you are hurt. An effect the bus lacks is added at its end for the card and taken off again when the card is done, so the bus is left as it was. Never shown in the editor.",
			family_of, [
				{"key": "bus", "label": "Bus", "drawer": "bus", "default": "Master"},
				{"key": "how", "label": "Way", "drawer": BUS_WAYS, "default": "muffle", "redraw": true},
				{"key": "to", "label": "To", "drawer": "num", "default": 400.0, "visible_when": bus_has_a_value},
				{"key": "slot", "label": "Effect number", "drawer": "int", "whole": true, "default": 0, "show_if": "how==switch"},
				{"key": "bus_says", "label": "", "drawer": "note", "text": bus_says, "hide_empty": true, "warn_when": bus_value_off},
				_over("For", 0.5),
				{"key": "back_seconds", "label": "Back over", "drawer": "unit:time", "default": 0.2, "visible_when": bus_has_a_value}
			], {"bus": "Master", "how": "muffle", "to": 400.0, "seconds": 0.5, "back_seconds": 0.2}, [],
			["muffle", "low pass", "underwater", "reverb", "duck", "audio effect"])
	]


static func _time_kinds(family_of: Dictionary) -> Array:
	return [
		_kind("spring", "Spring",
			"Kicks a value of a 2D node and lets its Spring node bounce it back to rest: a button that squashes when pressed, a sign that swings. It needs a Spring node under the node. The kick is in the value's own units, a second each: for a scale 3 stretches it a fifth of the way.",
			family_of, [
				_node("node", "Node", ["Node2D"], "This object"),
				{"key": "property", "label": "Property", "drawer": "property", "node_key": "node", "default": "scale", "on_change": spring_reseed},
				{"key": "kick", "label": "Kick", "drawer": "typed", "node_key": "node", "property_key": "property"},
				{"key": "damping", "label": "Damping", "drawer": "num", "unset": 0.85},
				{"key": "frequency", "label": "Swings a second", "drawer": "num", "unset": 2.075},
				_node_line("spring")
			], {"property": "scale", "kick": Vector2(3.0, 3.0)}, ["Node2D"], ["bounce", "wobble", "overshoot", "bump", "kick"]),
		_kind("slow_object", "Slow One Object",
			"Slows the animations and particles under a node for a time, then puts their speed back. Scripts of your own keep their speed, because Godot has nothing to slow them with. It multiplies with Slowmo: half speed here under a Slowmo of 0.5 is a quarter.",
			family_of, [
				_node("node", "Node", ["Node"], "This object"),
				{"key": "speed", "label": "Speed", "drawer": "num", "default": 0.3},
				_over("For", 0.5),
				{"key": "slow_says", "label": "", "drawer": "note", "text": slow_says, "hide_empty": true, "warn_when": slow_finds_nothing}
			], {"speed": 0.3, "seconds": 0.5}, ["Node"], ["slow motion", "speed scale", "freeze", "animation speed"]),
		_kind("animation_parameter", "Animation Parameter",
			"Moves one parameter of an AnimationTree to a value and brings it back: a blend amount, a speed, a condition. It lists only the parameters the tree really has and lets you set.",
			family_of, [
				_node("node", "Animation tree", ["AnimationTree"]),
				{"key": "parameter", "label": "Parameter", "drawer": "choices", "choices": animation_parameters, "also": animation_parameter_chosen, "empty": "Pick a parameter"},
				{"key": "to", "label": "To", "drawer": "typed", "sample": animation_parameter_sample},
				_over("Over", 0.2),
				{"key": "back", "label": "Go back", "drawer": "bool", "default": true, "redraw": true},
				{"key": "back_seconds", "label": "Back over", "drawer": "unit:time", "default": 0.2, "show_if": "back"},
				_node_line("animation_parameter")
			], {"to": 1.0, "seconds": 0.2, "back": true, "back_seconds": 0.2}, ["AnimationTree"], ["blend", "state machine", "condition", "animation speed", "parameters"])
	]


## The node a card means under a key: the object the player is under when the key is empty and the card allows it.
static func _picked(card: Dictionary, edited: Object, key: String, host_when_empty: bool) -> Node:
	if str(card.get(key, "")).is_empty():
		return fields().call("host_of", edited) as Node if host_when_empty else null
	return fields().call("resolve", edited, card.get(key)) as Node


## Whether a node is one of the classes.
static func _is_any(node: Node, classes: Array) -> bool:
	for named: Variant in classes:
		if node.is_class(str(named)):
			return true
	return false


## The words a card of this word calls the node it needs, in "X is not ..." sentences.
const NEEDS: Dictionary = {
	"collision_for": ["a collision shape", SHAPES],
	"collision_layer_for": ["a body or an area", BODIES],
	"draw_order": ["a 2D node (a 3D node is drawn by its distance from the camera)", ["CanvasItem"]],
	"look_at": ["a 2D or a 3D node", ["Node2D", "Node3D"]],
	"rotate_by": ["a node that can be turned", TURNABLE],
	"rotate_to": ["a node that can be turned", TURNABLE],
	"rotation_shake": ["a node that can be turned", TURNABLE],
	"light": ["a light", LIGHTS],
	"spring": ["a 2D node (a Spring node does not move a UI or a 3D node)", ["Node2D"]],
	"animation_parameter": ["an animation tree", ["AnimationTree"]],
	"scene_look": ["a WorldEnvironment or a 3D camera", ["WorldEnvironment", "Camera3D"]]
}

## The cards whose empty node means the object the player is under.
const HOST_WHEN_EMPTY: Array = ["remove_node", "draw_order", "switch_node", "look_at", "rotate_by", "rotate_to", "rotation_shake", "light", "spring"]


## What is wrong with the node a card points at, in one or two short sentences, or an empty text when nothing is.
static func node_note(word: String, card: Dictionary, edited: Object, key: String = "node") -> String:
	var picked: Node = _picked(card, edited, key, HOST_WHEN_EMPTY.has(word) and key == "node")
	if picked == null:
		return ""
	if NEEDS.has(word):
		var needs: Array = NEEDS[word]
		if not _is_any(picked, needs[1] as Array):
			return EventSheetL10n.translate("%s is not what this card needs. It needs %s.") % [picked.name, EventSheetL10n.translate(str(needs[0]))]
	if ["look_at", "rotate_by", "rotate_to", "rotation_shake"].has(word) and _is_any(picked, REFUSED_FOR_TURNING):
		return EventSheetL10n.translate("%s is a RigidBody, which the physics engine turns. Point this card at the sprite or mesh under it.") % picked.name
	match word:
		"look_at":
			if str(card.get("target", "")).is_empty():
				return EventSheetL10n.translate("Pick the node to look at. Until then this card does nothing.")
		"spring":
			if pack().call("spring_of", picked) == null:
				return EventSheetL10n.translate("There is no Spring node under %s. Add one, or this card does nothing.") % picked.name
		"animation_parameter":
			if str(card.get("parameter", "")).is_empty():
				return EventSheetL10n.translate("Pick the parameter to move. Until then this card does nothing.")
		"remove_node":
			if edited is Node and (picked == edited or picked.is_ancestor_of(edited as Node)):
				return EventSheetL10n.translate("This node holds the player, so it is removed when the list ends, whatever the tick says.")
		"switch_node":
			if edited is Node and (picked == edited or picked.is_ancestor_of(edited as Node)):
				return EventSheetL10n.translate("This node holds the player, so the player's own tweens freeze with it while it is off.")
		"rotation_shake":
			if picked is Camera2D and bool(picked.get("ignore_rotation")):
				return EventSheetL10n.translate("This camera ignores rotation, so the shake cannot be seen. Turn off Ignore Rotation on it.")
		"scene_look":
			if not _scene_has_a_look(card, edited):
				return EventSheetL10n.translate("This scene has no WorldEnvironment to change. Add one, or pick the camera that holds the look.")
	return ""


## Whether the edited scene holds something whose look the card can change: the node it names, else a WorldEnvironment.
static func _scene_has_a_look(card: Dictionary, edited: Object) -> bool:
	if not str(card.get("node", "")).is_empty():
		return true
	if not (edited is Node) or (edited as Node).get_tree() == null:
		return true
	var root: Node = (edited as Node).get_tree().edited_scene_root
	return root == null or root is WorldEnvironment or not root.find_children("*", "WorldEnvironment", true, false).is_empty()


## The physics space a body's layers are named in: the 3D one for a 3D body, else the 2D one.
static func layer_space(card: Dictionary, edited: Object) -> String:
	return "3d_physics" if _picked(card, edited, "node", false) is CollisionObject3D else "2d_physics"


## One layer as the list reads it: its number, and the name the project gave it in Project Settings when it gave one.
static func layer_words(space: String, number: int) -> String:
	var named: String = str(ProjectSettings.get_setting("layer_names/%s/layer_%d" % [space, number], "")).strip_edges()
	return "%d - %s" % [number, named] if not named.is_empty() else str(number)


## The thirty-two layers of a physics space, the way the list reads them.
static func layer_choices(space: String) -> PackedStringArray:
	var made: PackedStringArray = PackedStringArray()
	for number: int in range(1, 33):
		made.append(layer_words(space, number))
	return made


## The colour a Light card's start takes when it is first set: the colour of the light the card points at.
static func light_colour(card: Dictionary, edited: Object) -> Variant:
	var picked: Node = _picked(card, edited, "node", true)
	if picked is Light2D:
		return (picked as Light2D).color
	if picked is Light3D:
		return (picked as Light3D).light_color
	return Color.WHITE


## The Juice Player's own code, which knows what a Spring node is and which parameters of a tree can be set.
static func pack() -> Script:
	return load("res://addons/eventsheet/editor/inspector/juice_preview.gd").call("pack_script") as Script


## The nodes a Slow One Object card would slow, from the node it points at (or the object the player is under).
static func slow_nodes(card: Dictionary, edited: Object) -> Array:
	var picked: Node = _picked(card, edited, "node", true)
	return Array(pack().call("speed_nodes_under", picked)) if picked != null else []


## What a Slow One Object card found to slow, in plain words: how many nodes and what they are called.
static func slow_says(card: Dictionary, _cards: Array, _index: int, edited: Object) -> String:
	var found: Array = slow_nodes(card, edited)
	if found.is_empty():
		var picked: Node = _picked(card, edited, "node", true)
		if picked == null:
			return ""
		return EventSheetL10n.translate("Nothing under %s has a speed to slow. Scripts of your own keep their speed.") % picked.name
	var names: PackedStringArray = PackedStringArray()
	for node: Variant in found:
		names.append(str((node as Node).name))
	return EventSheetL10n.translate("Slows %d: %s. Scripts of your own keep their speed.") % [found.size(), ", ".join(names)]


## Whether a Slow One Object card finds nothing to slow, so its line is the quiet amber one.
static func slow_finds_nothing(card: Dictionary, _cards: Array, _index: int, edited: Object) -> bool:
	return _picked(card, edited, "node", true) != null and slow_nodes(card, edited).is_empty()


## The parameters of the animation tree a card points at that a card may set.
static func animation_parameters(card: Dictionary, edited: Object) -> Array:
	var tree: Node = _picked(card, edited, "node", false)
	return Array(pack().call("writable_parameters", tree)) if tree is AnimationTree else []


## What the chosen parameter holds now: the shape of the value the card moves it to.
static func animation_parameter_sample(card: Dictionary, edited: Object) -> Variant:
	var tree: Node = _picked(card, edited, "node", false)
	var parameter: String = str(card.get("parameter", ""))
	if not (tree is AnimationTree) or parameter.is_empty():
		return null
	return tree.get(parameter)


## Choosing a parameter gives the card a value of the parameter's own kind to move it to.
static func animation_parameter_chosen(card: Dictionary, edited: Object, chosen: String) -> Dictionary:
	var tree: Node = _picked(card, edited, "node", false)
	if not (tree is AnimationTree):
		return {}
	var now: Variant = tree.get(chosen)
	match typeof(now):
		TYPE_BOOL:
			return {"to": not bool(now)}
		TYPE_INT:
			return {"to": 1}
		TYPE_VECTOR2:
			return {"to": Vector2.ONE}
	return {"to": 1.0 if float(now) < 0.5 else 0.0}


## Choosing another property gives a Spring card a kick in the new property's own kind.
static func spring_reseed(card: Dictionary, edited: Object, chosen: Variant) -> Dictionary:
	var picked: Node = _picked(card, edited, "node", true)
	var property: String = str(chosen)
	var now: Variant = picked.get_indexed(NodePath(property)) if picked != null else null
	if SPRING_KICKS.has(property):
		return {"kick": SPRING_KICKS[property]}
	match typeof(now):
		TYPE_VECTOR2:
			return {"kick": Vector2(3.0, 3.0)}
		TYPE_VECTOR3:
			return {"kick": Vector3(3.0, 3.0, 3.0)}
		TYPE_COLOR:
			return {"kick": Color(4.0, 4.0, 4.0, 0.0)}
	return {"kick": 3.0}


## What a Rotation Shake does, in one grey sentence.
static func rotation_says(card: Dictionary) -> String:
	var degrees: String = str(snappedf(float(card.get("degrees", 10.0)), 0.001)).trim_suffix(".0")
	var seconds: String = str(snappedf(float(card.get("seconds", 0.0)), 0.001)).trim_suffix(".0")
	if not str(card.get("curve", "")).strip_edges().is_empty():
		return EventSheetL10n.translate("Swings up to %s degrees over %s s, following your curve, and ends at rest.") % [degrees, seconds]
	var fade_in: bool = bool(card.get("fade_in", false))
	var fade_out: bool = bool(card.get("fade_out", true))
	if fade_in and fade_out:
		return EventSheetL10n.translate("Swings up to %s degrees half way and is at rest at %s s.") % [degrees, seconds]
	if fade_in:
		return EventSheetL10n.translate("Starts at rest and swings %s degrees by %s s.") % [degrees, seconds]
	if fade_out:
		return EventSheetL10n.translate("Swings %s degrees at first and is at rest at %s s.") % [degrees, seconds]
	return EventSheetL10n.translate("Swings %s degrees for %s s, then stops.") % [degrees, seconds]


## The values of the scene's look a card can move, as the options of a choice: the glow, then every value of
## the environment and of the camera that the shipped rows can fade. Read off the same word tables those rows are
## built from, so the card and the rows can never offer different things.
static func look_choices() -> String:
	var made: PackedStringArray = PackedStringArray()
	made.append("%s=%s" % [GLOW_STRENGTH, "Glow strength"])
	for path: String in [ENVIRONMENT_WORDS_PATH, CAMERA_WORDS_PATH]:
		if not ResourceLoader.exists(path):
			continue
		var words: Variant = (load(path) as Script).get_script_constant_map().get("WORDS", [])
		for entry: Variant in words:
			var word: Dictionary = entry as Dictionary
			if not bool(word.get("fades", false)) or str(word.get("kind", "")) != "value":
				continue
			for property: Variant in (word.get("spellings", {}) as Dictionary).keys():
				if str(property) != GLOW_STRENGTH:
					made.append("%s=%s" % [property, str(word.get("word", property)).capitalize()])
	return ",".join(made)


## Whether a way of changing a bus has a number to give.
static func bus_has_a_value(card: Dictionary) -> bool:
	return str(card.get("how", "muffle")) != "switch"


## The line under a Bus Effect card: what its number means for the way chosen, and what the card does to a bus.
static func bus_says(card: Dictionary) -> String:
	match str(card.get("how", "muffle")):
		"dive":
			return EventSheetL10n.translate("A level in decibels, between -80 and 24. A bus with no amplify effect gets one while the card holds, and loses it again.")
		"wash":
			return EventSheetL10n.translate("How much of the reverb is heard, from 0 to 1. A bus with no reverb gets one while the card holds, and loses it again.")
		"switch":
			return EventSheetL10n.translate("Effect 0 is the first effect on the bus. It is switched on, then put back to how it was.")
	return EventSheetL10n.translate("The cutoff in hertz, between 20 and 20500. A bus with no low-pass gets one while the card holds, and loses it again.")


## Whether the number a card gives is outside what its way of changing the bus can take.
static func bus_value_off(card: Dictionary) -> bool:
	var value: float = float(card.get("to", 400.0))
	match str(card.get("how", "muffle")):
		"dive":
			return value < -80.0 or value > 24.0
		"wash":
			return value < 0.0 or value > 1.0
		"switch":
			return false
	return value < 20.0 or value > 20500.0
