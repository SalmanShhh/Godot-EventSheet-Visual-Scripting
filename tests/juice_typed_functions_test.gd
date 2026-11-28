# Godot EventSheets - the typed function behind every juice card, and the two cards added with them.
#
# THE ONE THING THIS FILE IS ABOUT: a card, a sheet row and a line of hand-written GDScript reach ONE function. So a
# card played from its dictionary and the same work asked of the typed function must leave the scene in the same
# state; a script that calls every typed function through a typed variable must parse (a typo is a parse error, not a
# silent nothing); the new functions stay out of the picker; and the Position Shake and Grayscale cards do what their
# words say. The suite has no scene tree, so what needs a clock (a timer, a tween) is proven by the game run instead.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PLAYER: String = "res://eventsheet_addons/juice/juice_player.gd"
const JUICE: String = "res://eventsheet_addons/juice/juice_behavior.gd"
const JUICE_3D: String = "res://eventsheet_addons/juice_3d/juice_3d_behavior.gd"
const SCREEN: String = "res://eventsheet_addons/screen_fx/screen_fx.gd"
const SCHEMA_PATH: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"

const TEST_NAME: String = "juice_typed_functions"

## Every function this build adds to the Juice Player, which the picker must not list a second time.
const PLAYER_FUNCTIONS: PackedStringArray = [
	"tween_property", "emit_signal_on", "emit_juice_signal", "play_player", "play_sound", "stop_sound", "fade_bus", "vibrate", "vibrate_pattern",
	"restart_particles", "start_particles", "stop_particles", "play_animation", "play_sprite_animation", "show_node",
	"hide_node", "show_node_for", "call_method", "spawn_scene", "push_away_from", "push_along_motion", "push_towards",
	"force_for_a_time", "gravity_for_a_time", "freeze_body", "pop", "fade_node", "focus_control", "count_label_to",
	"reveal_text", "fill_bar_to", "tween_shader_value", "disable_collision_for", "set_collision_bit_for", "remove_node",
	"draw_order_for", "switch_node_off_for", "switch_node_off", "switch_node_on", "rotate_by", "rotate_to", "turn_to_face",
	"rotation_shake", "flare_light", "tween_scene_look", "bus_effect_for", "slow_object", "kick_spring",
	"tween_animation_parameter", "shake_position"
]


static func run() -> bool:
	var ok: bool = true
	ok = _hidden_pins() and ok
	ok = _parse_pins() and ok
	ok = _both_ways_pins() and ok
	ok = _timed_shake_pins() and ok
	ok = _position_shake_pins() and ok
	ok = _grayscale_pins() and ok
	ok = _schema_pins() and ok
	ok = _old_scene_pins() and ok
	return ok


static func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path)


## A player built the way the suite builds one: a script on a node, a host above it and its targets beside it.
static func _world() -> Dictionary:
	var host: Node2D = Node2D.new()
	host.name = "Host"
	var player: Node = Node.new()
	player.set_script(load(PLAYER))
	player.name = "Player"
	host.add_child(player)
	player.set("host", host)
	var sparks: CPUParticles2D = CPUParticles2D.new()
	sparks.name = "Sparks"
	sparks.emitting = false
	host.add_child(sparks)
	var body: CharacterBody2D = CharacterBody2D.new()
	body.name = "Body"
	host.add_child(body)
	var other: Node2D = Node2D.new()
	other.name = "Other"
	other.position = Vector2(100.0, 0.0)
	host.add_child(other)
	var listener: Node = Node.new()
	listener.name = "Listener"
	listener.set_script(_Recorder)
	host.add_child(listener)
	return {"host": host, "player": player, "sparks": sparks, "body": body, "other": other, "listener": listener}


## What a scene looks like after a play: everything the plays below can change.
static func _state(world: Dictionary) -> String:
	var host: Node2D = world["host"] as Node2D
	return str([(world["sparks"] as CPUParticles2D).emitting, (world["body"] as CharacterBody2D).velocity, host.visible,
		host.position, host.rotation, (world["other"] as Node2D).rotation, (world["other"] as Node2D).visible,
		(world["other"] as Node2D).process_mode, (world["listener"] as Node).get("calls")])


## Every function is hidden from the picker: a function that is not hidden would be a second row for a card.
static func _hidden_pins() -> bool:
	var text: String = _text(PLAYER)
	var rows: Array = []
	var missing: PackedStringArray = PackedStringArray()
	for named: String in PLAYER_FUNCTIONS:
		var at: int = text.find("\nfunc %s(" % named)
		if at < 0:
			missing.append(named + " (absent)")
			continue
		var above: String = text.substr(maxi(at - 900, 0), mini(at, 900))
		var block: String = above.substr(above.rfind("\n\n") + 2)
		if not block.contains("@ace_hidden"):
			missing.append(named)
	rows.append(["every typed function of the Juice Player is hidden from the picker", missing, PackedStringArray()])
	rows.append(["the timed shake function of the 2D Juice node is hidden", _is_hidden(_text(JUICE), "shake_timed"), true])
	rows.append(["the timed shake function of the 3D Juice node is hidden", _is_hidden(_text(JUICE_3D), "shake_timed"), true])
	rows.append(["the stack's hold function is hidden", _is_hidden(_text(SCREEN), "hold_post_effect"), true])
	return SUPPORT.pins(TEST_NAME, rows)


static func _is_hidden(text: String, named: String) -> bool:
	var at: int = text.find("\nfunc %s(" % named)
	if at < 0:
		return false
	var above: String = text.substr(maxi(at - 900, 0), mini(at, 900))
	return above.substr(above.rfind("\n\n") + 2).contains("@ace_hidden")


## A script that calls every typed function through a typed variable parses: the editor's completion list is made of
## these names and their typed arguments, and a misspelt one is an error here instead of a silent nothing at run time.
static func _parse_pins() -> bool:
	var lines: PackedStringArray = PackedStringArray([
		"extends Node",
		"",
		"@onready var player: JuicePlayer = $JuicePlayer",
		"@onready var juice: JuiceBehavior = $Juice",
		"@onready var juice_3d: Juice3DBehavior = $Juice3D",
		"@onready var screen: ScreenFx = $ScreenFx",
		"",
		"",
		"func call_everything(node: Node, body: Node, label: Label, bar: ProgressBar, tree: AnimationTree, light: Light2D, shape: Node, curve: Curve, other: JuicePlayer) -> void:",
		"\tplayer.tween_property(node, \"modulate:a\", 0.5, 0.2, null, Tween.TRANS_SINE, Tween.EASE_OUT, true, false)",
		"\tplayer.emit_signal_on(node, \"ready\", [])",
		"\tplayer.emit_juice_signal(\"done\")",
		"\tplayer.play_player(other, 1.0)",
		"\tplayer.play_sound(null, 0.0, 1.0, \"Master\", true, \"hit\")",
		"\tplayer.stop_sound(\"hit\", 0.2)",
		"\tplayer.fade_bus(\"Master\", -12.0, 0.3)",
		"\tplayer.vibrate(0.5, 0.5, 0.2)",
		"\tplayer.vibrate_pattern(3, 0.3, 0.5, 0.5, 0.1, JuicePlayer.LAST_USED_CONTROLLER)",
		"\tplayer.restart_particles(node)",
		"\tplayer.start_particles(node)",
		"\tplayer.stop_particles(node)",
		"\tplayer.play_animation(null, \"idle\", 0.4)",
		"\tplayer.play_sprite_animation(node, \"idle\", 0.4)",
		"\tplayer.show_node(node)",
		"\tplayer.hide_node(node)",
		"\tplayer.show_node_for(node, 0.2)",
		"\tplayer.call_method(node, \"queue_redraw\", [])",
		"\tplayer.spawn_scene(null, node)",
		"\tplayer.push_away_from(body, node, 300.0)",
		"\tplayer.push_along_motion(body, 300.0)",
		"\tplayer.push_towards(body, Vector3.UP, 300.0)",
		"\tplayer.force_for_a_time(body, Vector3(0.0, -400.0, 0.0), 0.5)",
		"\tplayer.gravity_for_a_time(body, 0.2, 0.5)",
		"\tplayer.freeze_body(body, 0.1)",
		"\tplayer.pop(node, 1.3, 0.15)",
		"\tplayer.fade_node(node, 0.0, 0.3)",
		"\tplayer.focus_control(null)",
		"\tplayer.count_label_to(label, 100.0, 0.6)",
		"\tplayer.reveal_text(label, 0.8, 0.0)",
		"\tplayer.fill_bar_to(bar, 1.0, 0.3)",
		"\tplayer.tween_shader_value(node, \"amount\", 1.0, 0.12, Tween.TRANS_QUAD, true, true)",
		"\tplayer.disable_collision_for(shape, 0.5)",
		"\tplayer.set_collision_bit_for(body, 1, false, 0.5, true)",
		"\tplayer.remove_node(node, true)",
		"\tplayer.draw_order_for(node, 10, 0.5)",
		"\tplayer.switch_node_off_for(node, 0.5, true, true, false)",
		"\tplayer.switch_node_off(node, true, true, false)",
		"\tplayer.switch_node_on(node, true, true, false)",
		"\tplayer.rotate_by(node, 45.0, 0.2)",
		"\tplayer.rotate_to(node, 90.0, 0.2)",
		"\tplayer.turn_to_face(node, body, 0.2)",
		"\tplayer.rotation_shake(node, 10.0, 0.3, false, true, curve)",
		"\tplayer.flare_light(light, 3.0, Color.ORANGE, 0.08, true, 0.2, Tween.TRANS_SINE, Tween.EASE_OUT)",
		"\tplayer.tween_scene_look(\"glow_intensity\", 2.0, 0.1, 0.3, null)",
		"\tplayer.bus_effect_for(\"Master\", JuicePlayer.BusWay.MUFFLE, 400.0, 0.5, 0.2, 0)",
		"\tplayer.slow_object(node, 0.3, 0.5)",
		"\tplayer.kick_spring(node, \"scale\", Vector2(3.0, 3.0))",
		"\tplayer.tween_animation_parameter(tree, \"parameters/blend\", 1.0, 0.2, true, 0.2)",
		"\tplayer.shake_position(node, 8.0, 0.4, false, true, curve, 1.0, 0.0, 1.0, 30.0, 1.0)",
		"\tjuice.shake(0.4)",
		"\tjuice.shake_timed(0.4, 0.5, false, true, curve, 1.0)",
		"\tjuice.shake_position(8.0, 0.4, false, true, curve, 1.0, 1.0, 30.0)",
		"\tjuice.stop_position_shake()",
		"\tjuice_3d.shake_timed(0.4, 0.5, false, true, curve, 1.0)",
		"\tjuice_3d.shake_position(0.1, 0.4, false, true, curve, 1.0, 1.0, 1.0, 30.0)",
		"\tscreen.grayscale(1.0, 1.0, 0.2, 0.4, false)",
		"\tscreen.grayscale_from(Vector2.ZERO, 800.0, 1.0, 1.0, 0.2, false, 0.4, false, false)",
		"\tscreen.clear_grayscale(0.4)",
		"\tscreen.shockwave(Vector2.ZERO, 1.0)",
		"\tscreen.chromatic_pulse(0.6, 0.35)",
		"\tscreen.pulse_post_effect(\"vignette\", 0.6, 0.35)",
		"\tscreen.hold_post_effect(\"vignette\", 1.0, 0.5)",
		"\tjuice.flash(Color.WHITE, 0.1)",
		"\tjuice.hitstop(0.08, 0.0)",
		"\tjuice.slowmo(0.3, 0.3, \"realtime\")",
		"\tjuice.punch_scale(0.3, 0.2)",
		"\tjuice.zoom_by_percent(110.0, 0.2)",
		"\tjuice.squash_and_stretch(0.3, 0.2)",
		"\tjuice.punch_position(Vector2(0.0, -10.0), 0.2)",
		"\tjuice.punch_rotation(10.0, 0.2)",
		"\tjuice.chromatic_shake(12.0, 0.3, \"reducing\", -1.0)",
		""
	])
	var path: String = SUPPORT.own_path("juice_from_code.gd")
	var written: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	written.store_string("\n".join(lines))
	written.close()
	var script: GDScript = ResourceLoader.load(path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE) as GDScript
	var rows: Array = [
		["a script calling every typed function through typed variables loads", script != null, true],
		["and it can be instantiated, which a parse error forbids", script != null and script.can_instantiate(), true]
	]
	return SUPPORT.pins(TEST_NAME, rows)


## A card played from its dictionary and the same work asked of the typed function leave the scene the same way.
static func _both_ways_pins() -> bool:
	var cases: Array = [
		["restart particles", {"verb": "particles", "node": NodePath("../Sparks"), "do": "restart"}, func(w: Dictionary) -> void: (w["player"] as Node).call("restart_particles", w["sparks"])],
		["start particles", {"verb": "particles", "node": NodePath("../Sparks"), "do": "start"}, func(w: Dictionary) -> void: (w["player"] as Node).call("start_particles", w["sparks"])],
		["stop particles", {"verb": "particles", "node": NodePath("../Sparks"), "do": "stop"}, func(w: Dictionary) -> void: (w["player"] as Node).call("stop_particles", w["sparks"])],
		["hide the object", {"verb": "show_hide", "do": "hide"}, func(w: Dictionary) -> void: (w["player"] as Node).call("hide_node", w["host"])],
		["show the object", {"verb": "show_hide", "do": "show"}, func(w: Dictionary) -> void: (w["player"] as Node).call("show_node", w["host"])],
		["call a method", {"verb": "call_method", "node": NodePath("../Listener"), "method": "heard", "args": [7]}, func(w: Dictionary) -> void: (w["player"] as Node).call("call_method", w["listener"], "heard", [7])],
		["push along a fixed way", {"verb": "push", "body": NodePath("../Body"), "direction": "fixed", "x": 3.0, "y": 0.0, "speed": 100.0, "scaled": false}, func(w: Dictionary) -> void: (w["player"] as Node).call("push_towards", w["body"], Vector3(3.0, 0.0, 0.0), 100.0)],
		["push away from a node", {"verb": "push", "body": NodePath("../Body"), "direction": "away", "from": NodePath("../Other"), "speed": 50.0, "scaled": false}, func(w: Dictionary) -> void: (w["player"] as Node).call("push_away_from", w["body"], w["other"], 50.0)],
		["rotate by at once", {"verb": "rotate_by", "node": NodePath("../Other"), "degrees": 30.0, "seconds": 0.0}, func(w: Dictionary) -> void: (w["player"] as Node).call("rotate_by", w["other"], 30.0, 0.0)],
		["rotate to at once", {"verb": "rotate_to", "node": NodePath("../Other"), "degrees": 90.0, "seconds": 0.0}, func(w: Dictionary) -> void: (w["player"] as Node).call("rotate_to", w["other"], 90.0, 0.0)],
		["tween a property at once", {"verb": "tween_property", "node": NodePath("../Other"), "effect": "rotation", "to": 1.5, "seconds": 0.0}, func(w: Dictionary) -> void: (w["player"] as Node).call("tween_property", w["other"], "rotation", 1.5, 0.0)],
		["switch an object off for good", {"verb": "switch_node", "node": NodePath("../Other"), "do": "off", "visible": true, "process": true}, func(w: Dictionary) -> void: (w["player"] as Node).call("switch_node_off", w["other"], true, true, false)],
		["switch an object back on", {"verb": "switch_node", "node": NodePath("../Other"), "do": "on", "visible": true, "process": true}, func(w: Dictionary) -> void: (w["player"] as Node).call("switch_node_on", w["other"], true, true, false)]
	]
	var rows: Array = []
	for entry: Variant in cases:
		var case: Array = entry as Array
		var by_card: Dictionary = _world()
		(by_card["player"] as Node).call("_do_step", case[1], 1.0)
		var by_code: Dictionary = _world()
		(case[2] as Callable).call(by_code)
		rows.append(["%s: the card and the typed function leave the scene the same" % case[0], _state(by_card), _state(by_code)])
		for one: Dictionary in [by_card, by_code]:
			(one["host"] as Node).free()
	var lost: Dictionary = _world()
	var skipped: Array = []
	(lost["player"] as Node).connect("on_feedback_skipped", func(label: String, why: String) -> void: skipped.append([label, why]))
	(lost["player"] as Node).call("restart_particles", null)
	(lost["player"] as Node).call("restart_particles", null)
	rows.append(["a typed call with nothing to act on says so and does not raise On Juice Card Skipped", skipped, []])
	(lost["host"] as Node).free()
	return SUPPORT.pins(TEST_NAME, rows)


## The timed shake is one function behind the card on both Juice nodes, and the card still reaches it.
static func _timed_shake_pins() -> bool:
	var rows: Array = []
	for path: String in [JUICE, JUICE_3D]:
		var by_card: Node = Node.new()
		by_card.set_script(load(path))
		by_card.call("shake_from_card", {"amount": 0.5, "seconds": 1.0, "fade_out": true}, 1.0)
		var by_code: Node = Node.new()
		by_code.set_script(load(path))
		by_code.call("shake_timed", 0.5, 1.0, false, true, null, 1.0)
		var made: Array = by_card.get("_timed_shakes")
		var asked: Array = by_code.get("_timed_shakes")
		rows.append(["%s: the card makes one timed shake" % path.get_file(), made.size(), 1])
		rows.append(["%s: and it is the shake the typed function makes" % path.get_file(), str((made[0] as Dictionary).get("amount")) + str((made[0] as Dictionary).get("seconds")) + str((made[0] as Dictionary).get("fade_out")), str((asked[0] as Dictionary).get("amount")) + str((asked[0] as Dictionary).get("seconds")) + str((asked[0] as Dictionary).get("fade_out"))])
		rows.append(["%s: a nothing amount makes no shake" % path.get_file(), _shakes_after(path, 0.0), 0])
		by_card.free()
		by_code.free()
	return SUPPORT.pins(TEST_NAME, rows)


static func _shakes_after(path: String, amount: float) -> int:
	var node: Node = Node.new()
	node.set_script(load(path))
	node.call("shake_timed", amount, 1.0)
	var count: int = (node.get("_timed_shakes") as Array).size()
	node.free()
	return count


## Position Shake: it stays within the amount and the weights, ends exactly where it began, adds with a second one and
## leaves a node that moves meanwhile with its own motion.
static func _position_shake_pins() -> bool:
	var rows: Array = []
	var juice: Node = Node.new()
	juice.set_script(load(JUICE))
	var target: Node2D = Node2D.new()
	target.position = Vector2(50.0, 20.0)
	juice.set("host", target)
	juice.call("shake_position", 10.0, 0.5, false, false, null, 1.0, 0.0, 60.0)
	var widest: float = 0.0
	var sideways: float = 0.0
	var steps: int = 0
	var moved_up_down: float = 0.0
	while (juice.get("_position_shakes") as Array).size() > 0 and steps < 200:
		juice.call("_position_shake_step", 1.0 / 60.0)
		var away: Vector2 = target.position - Vector2(50.0, 20.0)
		widest = maxf(widest, absf(away.x))
		moved_up_down = maxf(moved_up_down, absf(away.y))
		sideways += absf(away.x)
		steps += 1
	juice.call("_position_take_off")
	rows.append(["a shake never moves the node further than its amount", widest <= 10.0 + 0.001, true])
	rows.append(["a shake with a weight of 0 on y never moves it up or down", moved_up_down, 0.0])
	rows.append(["a shake does move it", sideways > 0.0, true])
	rows.append(["when it ends the node is exactly where it began", target.position, Vector2(50.0, 20.0)])
	juice.call("shake_position", 4.0, 5.0)
	juice.call("shake_position", 4.0, 5.0)
	juice.call("_position_shake_step", 0.016)
	rows.append(["two shakes at once are both running", (juice.get("_position_shakes") as Array).size(), 2])
	juice.call("_position_take_off")
	rows.append(["taking the offset off puts the node back", target.position, Vector2(50.0, 20.0)])
	juice.call("shake_position", 4.0, 5.0)
	juice.call("_position_shake_step", 0.016)
	target.position += Vector2(3.0, 0.0)
	juice.call("_position_take_off")
	rows.append(["a node that moved meanwhile keeps its own motion", target.position, Vector2(53.0, 20.0)])
	juice.call("stop_position_shake")
	rows.append(["stopping ends every shake and leaves the node at its own place", [(juice.get("_position_shakes") as Array).size(), target.position], [0, Vector2(53.0, 20.0)]])
	rows.append(["the camera, the rotation and the scale are never written", [target.rotation, target.scale], [0.0, Vector2.ONE]])
	juice.free()
	target.free()
	var shaker: Node = Node.new()
	shaker.set_script(load(JUICE_3D))
	var cube: Node3D = Node3D.new()
	cube.position = Vector3(1.0, 2.0, 3.0)
	shaker.set("host", cube)
	shaker.call("shake_position", 0.5, 0.3, false, false, null, 1.0, 1.0, 0.0, 60.0)
	var depth: float = 0.0
	var guard: int = 0
	while (shaker.get("_position_shakes") as Array).size() > 0 and guard < 100:
		shaker.call("_position_shake_step", 1.0 / 60.0)
		depth = maxf(depth, absf(cube.position.z - 3.0))
		guard += 1
	shaker.call("_position_take_off")
	rows.append(["a 3D shake with no weight on z never moves the node in depth", depth, 0.0])
	rows.append(["a 3D shake ends exactly where it began", cube.position, Vector3(1.0, 2.0, 3.0)])
	shaker.free()
	cube.free()
	var control: Control = Control.new()
	control.position = Vector2(5.0, 6.0)
	var for_control: Node = Node.new()
	for_control.set_script(load(JUICE))
	for_control.set("host", control)
	for_control.call("shake_position", 6.0, 0.2)
	for_control.call("_position_shake_step", 0.05)
	for_control.call("_position_take_off")
	rows.append(["a Control is shaken and put back too", control.position, Vector2(5.0, 6.0)])
	for_control.free()
	control.free()
	return SUPPORT.pins(TEST_NAME, rows)


## Grayscale: the entry the rows make, the circle's dials, a held grey that Clear takes away, and the shipped Desaturate
## picture unchanged for every row that does not ask for a circle.
static func _grayscale_pins() -> bool:
	var rows: Array = []
	var screen: Node = CanvasLayer.new()
	screen.set_script(load(SCREEN))
	screen.call("grayscale", 0.8, 1.0, 0.2, 0.4, true)
	rows.append(["a held Grayscale puts the colour out of the screen", [bool(screen.call("post_effect_is_on", "grayscale")), snappedf(float(screen.call("post_strength", "grayscale")), 0.001)], [true, 0.8]])
	rows.append(["it is the shipped Desaturate effect, under its own name", screen.call("post_dial", "grayscale", "reach"), -1.0])
	screen.call("clear_grayscale", 0.0)
	rows.append(["Clear Grayscale takes it away", bool(screen.call("post_effect_is_on", "grayscale")), false])
	screen.call("add_post_effect", "desaturate", "", 0.5)
	screen.call("grayscale", 1.0, 1.0, 0.2, 0.4, false)
	screen.call("clear_grayscale", 0.0)
	rows.append(["a project's own Desaturate entry is left alone", [bool(screen.call("post_effect_is_on", "desaturate")), snappedf(float(screen.call("post_strength", "desaturate")), 0.001)], [true, 0.5]])
	screen.call("grayscale_from", Vector2(0.25, 0.75), 600.0, 1.0, 1.0, 0.3, true, 0.4, true, true)
	rows.append(["a circle holds its place on the screen", screen.call("post_dial", "grayscale", "centre"), Vector2(0.25, 0.75)])
	rows.append(["a circle holds how far it grew", screen.call("post_dial", "grayscale", "reach"), 600.0])
	rows.append(["a circle holds which side is grey", screen.call("post_dial", "grayscale", "colour_inside"), true])
	screen.call("grayscale", 0.0, 1.0, 0.0, 0.0, true)
	rows.append(["a Grayscale of amount 0 puts the colour back", bool(screen.call("post_effect_is_on", "grayscale")), false])
	screen.free()
	var shader: String = _text("res://eventsheet_addons/screen_fx/post_desaturate.gdshader")
	rows.append(["with no circle the Desaturate shader keeps its old picture", shader.contains("uniform float reach = -1.0;") and shader.contains("float share = 1.0;"), true])
	return SUPPORT.pins(TEST_NAME, rows)


## The two new cards are kinds of the Add box, in a family, with search words and defaults a new card starts with.
static func _schema_pins() -> bool:
	var kinds: Array = (load(SCHEMA_PATH) as Script).call("schema").get("kinds")
	var rows: Array = []
	for word: String in ["grayscale", "position_shake"]:
		var found: Dictionary = {}
		for entry: Variant in kinds:
			if str((entry as Dictionary).get("kind", "")) == word:
				found = entry as Dictionary
		rows.append(["%s is a kind of card" % word, not found.is_empty(), true])
		rows.append(["%s has a family" % word, not str(found.get("category", "")).is_empty(), true])
		rows.append(["%s is found by its search words" % word, (found.get("search") as PackedStringArray).size() > 3, true])
	var words: Dictionary = load(PLAYER).get_script_constant_map().get("CATEGORY_OF")
	rows.append(["Grayscale sits with the screen cards", words.get("grayscale"), "screen"])
	rows.append(["Position Shake sits with the cards that move a node", words.get("position_shake"), "transform"])
	rows.append(["the pack plays both words itself", [load(PLAYER).get_script_constant_map().get("WORLD_WORDS").has("grayscale"), load(PLAYER).get_script_constant_map().get("WORLD_WORDS").has("position_shake")], [true, true]])
	rows.append(["the editor plays both", [load(PLAYER).call("editor_kind", "grayscale"), load(PLAYER).call("editor_kind", "position_shake")], ["felt", "felt"]])
	return SUPPORT.pins(TEST_NAME, rows)


## A scene saved before this build, with a Juice Player and its cards, loads with the same cards, plays them, and saves the
## same bytes the second time round.
static func _old_scene_pins() -> bool:
	var path: String = "res://tools/doc_shots/fixtures/hit_juice.tscn"
	var first: Node = (load(path) as PackedScene).instantiate()
	var player: Node = first.get_node("HitJuice")
	var cards: Array = (player.get("steps") as Array).duplicate(true)
	player.set("host", first)
	for card: Variant in cards:
		player.call("_do_step", card, 1.0, true)
	var scene: PackedScene = PackedScene.new()
	scene.pack(first)
	var saved: String = SUPPORT.own_path("old_scene_a.tscn")
	ResourceSaver.save(scene, saved)
	var again: Node = (load(saved) as PackedScene).instantiate()
	var scene_two: PackedScene = PackedScene.new()
	scene_two.pack(again)
	var saved_two: String = SUPPORT.own_path("old_scene_b.tscn")
	ResourceSaver.save(scene_two, saved_two)
	var rows: Array = [
		["an old scene keeps every card it was saved with", again.get_node("HitJuice").get("steps"), cards],
		["and saving it twice writes the same bytes, apart from the resource id Godot invents on each save", _without_ids(FileAccess.get_file_as_string(saved)), _without_ids(FileAccess.get_file_as_string(saved_two))]
	]
	first.free()
	again.free()
	return SUPPORT.pins(TEST_NAME, rows)


## A saved scene's text with the random id of its script resource taken out.
static func _without_ids(text: String) -> String:
	var plain: RegEx = RegEx.new()
	plain.compile("1_[a-z0-9]{5}")
	return plain.sub(text, "1_id", true)


## A node that writes down what it is asked, so Call Method can be seen to arrive.
class _Recorder:
	extends Node

	var calls: Array = []

	func heard(value: Variant) -> void:
		calls.append(value)
