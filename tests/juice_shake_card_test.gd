# Godot EventSheets - the Shake card's Fade in and Fade out ticks, its Custom curve, and the two
# Juice rows that shake for a length: Shake For and Shake With Curve.
#
# THE ONE THING THIS FILE IS ABOUT: a shake the user times lasts exactly the Seconds they typed and
# has the shape they asked for, while a Shake card saved before the ticks existed, and the shipped
# Shake row, shake exactly as they always have (trauma that fades at the Juice node's Shake Decay).
# The shape is applied to the amount BEFORE the camera squares it, a timed shake adds to the trauma
# under the same cap of 1, and Stop Shake ends both kinds and says so.
#
# The suite has no scene tree, so the Juice node's frame is stepped by hand, as the Juice pack's own
# test does: the trauma and the timed level advance without a camera. What the camera does with them
# (the offset, a camera that ignores rotation, the camera put back exactly) was measured on a running
# tree, frame by frame.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "juice_shake_card"

const JUICE: String = "res://eventsheet_addons/juice/juice_behavior.gd"
const PLAYER: String = "res://eventsheet_addons/juice/juice_player.gd"
const SCHEMA: String = "res://addons/eventsheet/editor/inspector/feedback_card_schema.gd"
## The file both the Juice node and the Juice Player already share, where the shape is written once
## so the editor preview of a Shake card and the running shake can never disagree.
const RUNNER: String = "res://eventsheet_addons/juice/moment_runner.gd"

## One frame at 60 frames a second.
const FRAME: float = 1.0 / 60.0

## The row that has shipped, and the line it writes. Frozen.
const SHAKE_TEMPLATE: String = "## @ace_codegen_template(\"$JuiceBehavior.shake({strength})\")"


static func run() -> bool:
	var ok: bool = true
	ok = _trauma_pins() and ok
	ok = _row_pins() and ok
	ok = _shape_pins() and ok
	ok = _length_pins() and ok
	ok = _card_pins() and ok
	ok = _schema_pins() and ok
	ok = _old_pack_pins() and ok
	ok = _stop_pins() and ok
	return ok


## Today's shake, pinned before anything moves: Shake 0.4 loses 1.4 a second whatever Seconds says.
static func _trauma_pins() -> bool:
	var juice: Node = (load(JUICE) as GDScript).new()
	var heard: Array = [0]
	juice.connect("shake_stopped", func() -> void: heard[0] += 1)
	juice.call("shake", 0.4)
	_step(juice, 6)
	var after_six: float = snappedf(float(juice.call("current_trauma")), 0.001)
	_step(juice, 12)
	var after_eighteen: bool = bool(juice.call("is_shaking"))
	var stopped_alone: int = heard[0]
	juice.call("shake", 0.8)
	_step(juice, 3)
	juice.call("stop_shake")
	_step(juice, 1)
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a trauma shake of 0.4 is 0.26 after six frames", after_six, 0.26],
		["and over after eighteen (0.3 s), however long the card said", after_eighteen, false],
		["On Shake Stopped is heard once when it fades out", stopped_alone, 1],
		["and once more after Stop Shake", heard[0], 2],
	])
	juice.free()
	return ok


## The two new rows are real typed methods, and the shipped row is untouched.
static func _row_pins() -> bool:
	var script: GDScript = load(JUICE)
	var text: String = FileAccess.get_file_as_string(JUICE)
	return SUPPORT.pins(TEST_NAME, [
		["the shipped Shake row writes the line it always has", text.contains(SHAKE_TEMPLATE), true],
		["Shake For takes an amount, a length and the two ticks", _signature(script, "shake_for"),
			"amount: float, seconds: float, fade_in: bool, fade_out: bool"],
		["Shake With Curve takes an amount, a length and a Curve", _signature(script, "shake_with_curve"),
			"amount: float, seconds: float, curve: Curve"],
		["Shake For is a row", text.contains("## @ace_codegen_template(\"$JuiceBehavior.shake_for({amount}, {seconds}, {fade_in}, {fade_out})\")"), true],
		["Shake With Curve is a row", text.contains("## @ace_codegen_template(\"$JuiceBehavior.shake_with_curve({amount}, {seconds}, {curve})\")"), true],
	])


## The share of the amount a timed shake has at a share of its time, for each pair of ticks and for a
## curve. Measured on a running tree: Fade out 0.6 over 0.5 s read 0.54 0.48 ... 0.06 every 3 frames,
## Fade in the same rising, both ticks 0.12 0.24 0.36 0.48 0.60 0.48 ..., no tick 0.60 throughout.
static func _shape_pins() -> bool:
	var script: GDScript = load(RUNNER)
	if not script.has_method("shake_shape"):
		return SUPPORT.check(TEST_NAME, "the shared runner answers what shape a timed shake has", false, true)
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.15, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var at_quarter: Array = []
	var at_half: Array = []
	for ticks: Array in [[false, true], [true, false], [true, true], [false, false]]:
		at_quarter.append(snappedf(float(script.call("shake_shape", 0.25, ticks[0], ticks[1], null)), 0.001))
		at_half.append(snappedf(float(script.call("shake_shape", 0.5, ticks[0], ticks[1], null)), 0.001))
	return SUPPORT.pins(TEST_NAME, [
		["a quarter through: fade out, fade in, both, neither", at_quarter, [0.75, 0.25, 0.5, 1.0]],
		["half way through", at_half, [0.5, 0.5, 1.0, 1.0]],
		["a curve is the shape, whatever the ticks say",
			snappedf(float(script.call("shake_shape", 0.15, false, true, curve)), 0.001), 1.0],
	])


## A timed shake lasts its Seconds exactly, adds to the trauma under the cap, and ends with one
## On Shake Stopped.
static func _length_pins() -> bool:
	var juice: Node = (load(JUICE) as GDScript).new()
	if not juice.has_method("shake_for"):
		juice.free()
		return SUPPORT.check(TEST_NAME, "the Juice node can shake for a length", false, true)
	var heard: Array = [0]
	juice.connect("shake_stopped", func() -> void: heard[0] += 1)
	juice.call("shake_for", 0.6, 0.5, false, false)
	_step(juice, 29)
	var still: bool = bool(juice.call("is_shaking"))
	var trauma_untouched: float = float(juice.call("current_trauma"))
	_step(juice, 2)
	var over: bool = bool(juice.call("is_shaking"))
	var stopped: int = heard[0]
	juice.call("shake", 0.4)
	juice.call("shake_for", 0.8, 0.5, false, false)
	_step(juice, 1)
	var capped: float = snappedf(float(juice.call("shake_level")) if juice.has_method("shake_level") else -1.0, 0.001)
	juice.call("stop_shake")
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["a level shake of 0.5 s is still shaking at 29 frames", still, true],
		["it adds nothing to the trauma a Shake row reads", trauma_untouched, 0.0],
		["and is over at 31 frames", over, false],
		["On Shake Stopped is heard once when it ends", stopped, 1],
		["a timed shake on top of trauma is capped at 1", capped, 1.0],
		["Stop Shake ends both kinds", bool(juice.call("is_shaking")), false],
	])
	juice.free()
	return ok


## A card with neither tick nor curve shakes as it always has; a card with a tick is a timed shake.
static func _card_pins() -> bool:
	var plain: Array = _played([{"verb": "shake", "amount": 0.4, "effect": "", "seconds": 2.0}])
	var faded: Array = _played([{"verb": "shake", "amount": 0.6, "effect": "", "seconds": 0.5, "fade_out": true}])
	return SUPPORT.pins(TEST_NAME, [
		["a Shake card saved before the ticks is trauma, as before", plain, [0.4, true]],
		["a Shake card with Fade out is a timed shake, not trauma", faded, [0.0, true]],
	])


## The Shake card in the Inspector: two ticks and a curve kept as uid text, Fade out ticked on a
## new card only.
static func _schema_pins() -> bool:
	var schema: Dictionary = (load(SCHEMA) as GDScript).call("schema")
	var spec: Dictionary = {"kind_key": "verb", "stripe_key": "category"}
	var shake: Dictionary = _kind(schema, "shake")
	var drawers: Dictionary = {}
	for field: Variant in shake.get("fields", []):
		drawers[str((field as Dictionary).get("key", ""))] = str((field as Dictionary).get("drawer", ""))
	var fresh_shake: Dictionary = EventSheetCardSchemas.new_card(spec, shake)
	var fresh_flash: Dictionary = EventSheetCardSchemas.new_card(spec, _kind(schema, "flash"))
	return SUPPORT.pins(TEST_NAME, [
		["the Shake card has a Fade in tick", drawers.get("fade_in", ""), "bool"],
		["and a Fade out tick", drawers.get("fade_out", ""), "bool"],
		["and a curve kept as a file's uid text, never a Curve object", drawers.get("curve", ""), "resource:Curve"],
		["a new Shake card starts with Fade out ticked", fresh_shake.get("fade_out", null), true],
		["and Fade in unticked, stored only when touched", fresh_shake.has("fade_in"), false],
		["no other kind of card gets the ticks", fresh_flash.has("fade_out"), false],
	])


## Steps a Juice node's frame by hand.
static func _step(juice: Node, frames: int) -> void:
	for frame: int in range(frames):
		juice.call("_process", FRAME)


## A list played by a Juice Player with a Juice node under it: the trauma and whether it shakes.
static func _played(list: Array) -> Array:
	var pack: GDScript = load(PLAYER)
	var player: Node = pack.new()
	var juice: Node = (load(JUICE) as GDScript).new()
	player.add_child(juice)
	var typed: Array[Dictionary] = []
	for card: Variant in list:
		typed.append(card as Dictionary)
	player.set("steps", typed)
	player.call("play", 1.0)
	var answer: Array = [snappedf(float(juice.call("current_trauma")), 0.001), bool(juice.call("is_shaking"))]
	player.free()
	return answer


## A script method's arguments as "name: Type, ...", or "" when the script has no such method.
static func _signature(script: GDScript, method_name: String) -> String:
	for method: Dictionary in script.get_script_method_list():
		if str(method.get("name", "")) != method_name:
			continue
		var parts: PackedStringArray = PackedStringArray()
		for argument: Dictionary in method.get("args", []):
			var type_name: String = str(argument.get("class_name", ""))
			if type_name.is_empty():
				type_name = type_string(int(argument.get("type", TYPE_NIL)))
			parts.append("%s: %s" % [str(argument.get("name", "")), type_name])
		return ", ".join(parts)
	return ""


static func _kind(schema: Dictionary, word: String) -> Dictionary:
	for kind: Variant in schema.get("kinds", []):
		if str((kind as Dictionary).get("kind", "")) == word:
			return kind as Dictionary
	return {}


## A project that keeps an older copy of the Juice pack, one that cannot time a shake, is never offered a
## tick it would ignore: its Shake card has the two fields it always had.
static func _old_pack_pins() -> bool:
	var old_reading: Dictionary = {"words": PackedStringArray(["shake"]), "verbs": {"shake": {"label": "Shake", "help": ""}}, "params": {}}
	var new_reading: Dictionary = old_reading.duplicate(true)
	(new_reading["verbs"] as Dictionary)["shake_for"] = {"label": "Shake For", "help": ""}
	var schema_script: GDScript = load(SCHEMA)
	var old_kinds: Array = schema_script.call("derived_kinds", old_reading)
	var new_kinds: Array = schema_script.call("derived_kinds", new_reading)
	return SUPPORT.pins(TEST_NAME, [
		["an older pack's Shake card has its two fields", ((old_kinds[0] as Dictionary).get("fields") as Array).size(), 2],
		["and a new card of it holds no tick", (old_kinds[0] as Dictionary).get("defaults", {}).has("fade_out"), false],
		["a pack that can time a shake offers the ticks and the curve as well", ((new_kinds[0] as Dictionary).get("fields") as Array).size() > 2, true],
	])


## Stop Shake ends a shake and says so once, whichever kind it was.
static func _stop_pins() -> bool:
	var juice: Node = (load(JUICE) as GDScript).new()
	var heard: Array = [0]
	juice.connect("shake_stopped", func() -> void: heard[0] += 1)
	juice.call("shake", 0.8)
	_step(juice, 3)
	juice.call("stop_shake")
	_step(juice, 2)
	var after_trauma: int = heard[0]
	juice.call("stop_shake")
	var ok: bool = SUPPORT.pins(TEST_NAME, [
		["Stop Shake on a trauma shake is heard once", after_trauma, 1],
		["and a Stop Shake with nothing shaking says nothing", heard[0], 1],
	])
	juice.free()
	return ok
