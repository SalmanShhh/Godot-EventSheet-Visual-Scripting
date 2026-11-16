# Godot EventSheets - trying a list in the editor when its cards reach other nodes.
#
# THE ONE THING THIS FILE IS ABOUT: a preview of a Particles, Animation, Show or Hide, Pop, Fade, Count
# To, Reveal Text, Fill Bar, Shader Value, Squash, Punch or whole Tween Property card moves nodes that
# are not the object the player sits under, so the list of what a preview wrote down - and puts back on
# Stop, at the end of a pass and before the editor saves - has to name those nodes' properties too. A
# scene saved in the middle of a preview must hold what it held before.
#
# The real editor proves the saved bytes (a scene is saved mid-preview and its text compared); here the
# strip's own record and restore are driven with real nodes that have no scene tree.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NEW_PACK: String = "res://eventsheet_addons/juice/juice_player.gd"
const OLD_PACK: String = "res://eventsheet_addons/juice/feedback_player.gd"
const STRIP_PATH: String = "res://addons/eventsheet/editor/inspector/feedback_player_strip.gd"
const WORLD_PATH: String = "res://addons/eventsheet/editor/inspector/juice_world_preview.gd"

const TEST_NAME: String = "juice_world_preview"


static func run() -> bool:
	var ok: bool = true
	ok = _kind_pins() and ok
	ok = _shape_pins() and ok
	ok = _put_back_pins() and ok
	return ok


static func _pack() -> Script:
	return load(NEW_PACK if ResourceLoader.exists(NEW_PACK) else OLD_PACK) as Script


## Each card the board promises a preview for says it is played, and the file previews it; a card it
## does not preview (a shake, a plain tween of this object) is left to the pack's own sample.
static func _kind_pins() -> bool:
	var world: Script = load(WORLD_PATH) as Script
	var words: PackedStringArray = PackedStringArray(["particles", "animation", "sprite_animation", "show_hide",
		"squash_stretch", "punch_position", "punch_rotation", "pop", "fade", "count_to", "reveal_text", "fill_bar", "shader_value"])
	var unplayed: PackedStringArray = PackedStringArray()
	var unhandled: PackedStringArray = PackedStringArray()
	for word: String in words:
		if str(_pack().call("editor_kind", word)) != "felt":
			unplayed.append(word)
		if not bool(world.call("handles", {"verb": word})):
			unhandled.append(word)
	return SUPPORT.pins(TEST_NAME, [
		["every card with a preview is played, not skipped", unplayed, PackedStringArray()],
		["and the world file handles each of them", unhandled, PackedStringArray()],
		["a tween on another node is handled, the one-number tween on this object is not",
			[world.call("handles", {"verb": "tween_property", "node": NodePath("../Bar"), "effect": "value"}),
				world.call("handles", {"verb": "tween_property", "effect": "modulate", "amount": 0.5})], [true, false]],
		["a shake is the pack's own sample", world.call("handles", {"verb": "shake"}), false]
	])


## Each card puts its node where the running game would have it at that point of its length.
static func _shape_pins() -> bool:
	var world: Script = load(WORLD_PATH) as Script
	var label: Label = Label.new()
	label.text = "0"
	var reveal: Label = Label.new()
	reveal.text = "Hello there"
	var bar: ProgressBar = ProgressBar.new()
	bar.value = 10.0
	var sprite: Node2D = Node2D.new()
	sprite.modulate = Color(1.0, 0.5, 0.25, 1.0)
	var spark: Node2D = Node2D.new()
	var state: Dictionary = {}
	for node: Object in [label, reveal, bar, sprite, spark]:
		for property: String in ["text", "visible_ratio", "value", "modulate", "visible", "scale", "position", "rotation"]:
			if property in node:
				world.call("remember", state, node, property)
	world.call("step", {"verb": "count_to", "to": "10", "seconds": 1.0}, label, 0.5, 1.0, state)
	var half_count: String = label.text
	world.call("step", {"verb": "reveal_text", "seconds": 1.0}, reveal, 0.25, 1.0, state)
	var quarter_reveal: float = reveal.visible_ratio
	world.call("step", {"verb": "fill_bar", "to": "50", "seconds": 1.0}, bar, 0.5, 1.0, state)
	var half_bar: float = bar.value
	world.call("step", {"verb": "fade", "amount": 0.0, "seconds": 1.0}, sprite, 0.5, 1.0, state)
	var half_fade: Color = sprite.modulate
	world.call("step", {"verb": "show_hide", "do": "flash", "seconds": 0.2}, spark, 0.5, 1.0, state)
	var shown: bool = spark.visible
	world.call("step", {"verb": "show_hide", "do": "flash", "seconds": 0.2}, spark, 1.4, 1.0, state)
	var shown_after: bool = spark.visible
	world.call("step", {"verb": "punch_position", "x": 0.0, "y": -10.0, "seconds": 0.2}, spark, 0.0, 1.0, state)
	var kicked: Vector2 = spark.position
	world.call("step", {"verb": "punch_position", "x": 0.0, "y": -10.0, "seconds": 0.2}, spark, 1.0, 1.0, state)
	var settled: Vector2 = spark.position
	world.call("step", {"verb": "pop", "amount": 2.0, "seconds": 0.5}, sprite, 1.0, 1.0, state)
	var popped_scale: Vector2 = sprite.scale
	label.free()
	reveal.free()
	bar.free()
	sprite.free()
	spark.free()
	return SUPPORT.pins(TEST_NAME, [
		["Count To is half way at half its length", half_count, "5"],
		["Reveal Text shows a quarter of the letters a quarter in", quarter_reveal, 0.25],
		["Fill Bar is half way between where it was and where it goes", half_bar, 30.0],
		["Fade takes the alpha half way and leaves the colour", [half_fade.r, half_fade.g, half_fade.b, half_fade.a], [1.0, 0.5, 0.25, 0.5]],
		["Show for a time is shown while it lasts and hidden when it is over", [shown, shown_after], [true, false]],
		["a position kick starts at the kick and springs back to where it was", [kicked, settled], [Vector2(0.0, -10.0), Vector2.ZERO]],
		["a pop that has ended is back at the scale it had", popped_scale, Vector2.ONE]
	])


## A preview writes down what the cards may move on other nodes, and puts every one of them back.
static func _put_back_pins() -> bool:
	var parent: Node2D = Node2D.new()
	var player: Node = _pack().new()
	player.name = "Juice"
	parent.add_child(player)
	var banner: Label = Label.new()
	banner.name = "Banner"
	banner.text = "12"
	banner.modulate = Color(1.0, 1.0, 1.0, 1.0)
	parent.add_child(banner)
	var meter: ProgressBar = ProgressBar.new()
	meter.name = "Meter"
	meter.value = 20.0
	parent.add_child(meter)
	var strip: Control = (load(STRIP_PATH) as Script).new(player) as Control
	var run_list: Array = [
		{"verb": "count_to", "node": NodePath("../Banner"), "to": "99", "seconds": 0.4},
		{"verb": "fade", "node": NodePath("../Banner"), "amount": 0.0, "seconds": 0.4},
		{"verb": "fill_bar", "node": NodePath("../Meter"), "to": "80", "seconds": 0.4},
		{"verb": "pop", "amount": 3.0, "seconds": 0.4}
	]
	strip.set("_run_list", run_list)
	strip.call("_record_world", parent)
	var recorded: int = (strip.get("_world_base") as Array).size()
	strip.set("_time", 0.4)
	strip.call("_step_world", _pack(), parent)
	var moved: Array = [banner.text, banner.modulate.a, meter.value]
	strip.call("restore")
	var back: Array = [banner.text, banner.modulate.a, meter.value, parent.scale]
	var again: Array = (strip.get("_world_base") as Array).duplicate()
	strip.call("_exit_tree")
	strip.free()
	player.free()
	banner.free()
	meter.free()
	parent.free()
	return SUPPORT.pins(TEST_NAME, [
		["the strip wrote down text, modulate and value of the other nodes and the scale of this one", recorded, 4],
		["the cards moved those other nodes", moved, ["99", 0.0, 80.0]],
		["Restore puts every one of them back", back, ["12", 1.0, 20.0, Vector2.ONE]],
		["and forgets what it had written down", again, []]
	])
