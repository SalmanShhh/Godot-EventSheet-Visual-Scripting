# Godot EventSheets - a Juice Player beside a Juice 3D node plays its cards over a 3D view.
#
# THE ONE THING THIS FILE IS ABOUT: the player does not change for its call. It already plays through
# "the node beside it that answers moment_step"; Juice 3D gains that one call, with the 3D meaning of
# each word (zoom is the field of view, punch is the scale of the Node3D, flash tints a 3D sprite or
# label and otherwise the screen), and a scene that has BOTH a 2D Juice node and a Juice 3D node beside
# its player keeps playing through the 2D one, exactly as it does today.
#
# Called without a scene tree, as the suite must: the Juice 3D node's state (its trauma, the field of
# view a zoom asks for) is read straight after the call. The camera, the field of view, the scale and
# the time scale were measured frame by frame on a running tree outside the suite.
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")

const TEST_NAME: String = "juice_3d_cards"

const PACK: String = "res://eventsheet_addons/juice/juice_player.gd"
const JUICE_2D: String = "res://eventsheet_addons/juice/juice_behavior.gd"
const JUICE_3D: String = "res://eventsheet_addons/juice_3d/juice_3d_behavior.gd"
const RUNNER: String = "res://eventsheet_addons/juice/moment_runner.gd"

## The rows that have shipped on Juice 3D, and the lines they write. Frozen.
const FROZEN_3D: PackedStringArray = [
	"# @ace_codegen_template(\"$Juice3DBehavior.shake({strength})\")",
	"# @ace_codegen_template(\"$Juice3DBehavior.punch_scale({strength}, {duration})\")",
]


static func run() -> bool:
	var ok: bool = true
	ok = _call_pins() and ok
	ok = _limit_pins() and ok
	ok = _choice_pins() and ok
	return ok


static func _has(script: Script, method: String) -> bool:
	for entry: Dictionary in script.get_script_method_list():
		if str(entry.get("name", "")) == method:
			return true
	return false


static func _signature(script: Script, method: String) -> Array:
	for entry: Dictionary in script.get_script_method_list():
		if str(entry.get("name", "")) == method:
			var names: Array = []
			for argument: Dictionary in entry.get("args", []):
				names.append("%s:%d" % [argument.get("name", ""), int(argument.get("type", 0))])
			return names
	return ["missing"]


## Juice 3D answers the player's one call, with the same arguments as the 2D node.
static func _call_pins() -> bool:
	var flat: GDScript = load(JUICE_2D)
	var deep: GDScript = load(JUICE_3D)
	var juice: Node = deep.new()
	var answers: bool = _has(deep, "moment_step")
	var trauma: float = -1.0
	var halved: float = -1.0
	if answers:
		juice.call("moment_step", "shake", 0.6, "", 0.0, 1.0)
		trauma = snappedf(float(juice.get("trauma")), 0.001)
		juice.call("stop_shake")
		juice.call("moment_step", "shake", 0.8, "", 0.0, 0.5)
		halved = snappedf(float(juice.get("trauma")), 0.001)
	var fov: float = -1.0
	if _has(deep, "fov_for_zoom"):
		fov = snappedf(float(deep.call("fov_for_zoom", 75.0, 110.0)), 0.001)
	juice.free()
	var text: String = FileAccess.get_file_as_string(JUICE_3D)
	var frozen: bool = true
	for line: String in FROZEN_3D:
		frozen = frozen and text.contains(line)
	return SUPPORT.pins(TEST_NAME, [
		["Juice 3D answers the call a Juice Player makes", answers, true],
		["with the same arguments as the 2D node", _signature(deep, "moment_step"), _signature(flat, "moment_step")],
		["a Shake card at 0.6 shakes the 3D camera by the same trauma", trauma, 0.6],
		["and the strength of the play scales it", halved, 0.4],
		["a Zoom card at 110 narrows a 75 degree view to 69.797 (a tenth closer)", fov, 69.797],
		["Juice 3D opens a play and closes it", [_has(deep, "juice_player_began"), _has(deep, "juice_player_ended")], [true, true]],
		["the shipped Juice 3D rows write the lines they always have", frozen, true],
		["Juice 3D still needs no plugin: it names no file outside its own folder and the engine",
			text.contains("res://addons/"), false],
		["and none of the moment layer's own files either", text.contains("MomentRunner"), false],
	])


## The no-flashing ceiling and floor Juice 3D holds its cards to are the numbers the 2D pack holds its own to.
static func _limit_pins() -> bool:
	var deep: GDScript = load(JUICE_3D)
	var runner: Dictionary = (load(RUNNER) as GDScript).get_script_constant_map()
	var mine: Dictionary = deep.get_script_constant_map()
	var juice: Node = deep.new()
	var held: float = -1.0
	var floor_seconds: float = -1.0
	if _has(deep, "moment_step"):
		Engine.set_meta("no_flashing", true)
		juice.call("moment_step", "shake", 0.8, "", 0.0, 1.0)
		held = snappedf(float(juice.get("trauma")), 0.001)
		floor_seconds = snappedf(float(juice.call("_step_seconds", 0.1)), 0.001)
		Engine.remove_meta("no_flashing")
	juice.free()
	return SUPPORT.pins(TEST_NAME, [
		["the ceiling is the 2D pack's", mine.get("STEP_FLASH_CEILING", -1.0), runner.get("FLASH_CEILING", -2.0)],
		["and so is the floor", mine.get("STEP_FLASH_FLOOR_SECONDS", -1.0), runner.get("FLASH_FLOOR_SECONDS", -2.0)],
		["a shake is held under the ceiling while no flashing is on", held, 0.3],
		["and a short card is held over the floor", floor_seconds, 0.4],
		["the words held to it are the 2D pack's", mine.get("STEP_AMPLITUDE_VERBS", PackedStringArray()), runner.get("AMPLITUDE_VERBS", PackedStringArray(["none"]))],
	])


## Which node a player plays through. A player is aimed at its host by hand (the tree would set it).
static func _choice_pins() -> bool:
	var host: Node3D = Node3D.new()
	var deep: Node = (load(JUICE_3D) as GDScript).new()
	deep.name = "Juice3D"
	host.add_child(deep)
	var player: Node = (load(PACK) as GDScript).new()
	player.set("host", host)
	host.add_child(player)
	var alone: Node = player.call("_juice_quiet")
	var flat: Node = (load(JUICE_2D) as GDScript).new()
	flat.name = "Juice"
	host.add_child(flat)
	player.set("_juice_node", null)
	var both: Node = player.call("_juice_quiet")
	# The 2D node ahead of the 3D one, the way an old scene lists them.
	host.move_child(flat, 0)
	player.set("_juice_node", null)
	var flat_first: Node = player.call("_juice_quiet")
	# A 3D node cached before a 2D one arrived is not kept over it.
	player.set("_juice_node", deep)
	var cached: Node = player.call("_juice_quiet")
	var alone_name: String = alone.name if alone != null else "nothing"
	var both_name: String = both.name if both != null else "nothing"
	var flat_first_name: String = flat_first.name if flat_first != null else "nothing"
	var cached_name: String = cached.name if cached != null else "nothing"
	var yields: bool = deep.has_method("yields_to_other_juice") and bool(deep.call("yields_to_other_juice"))
	var flat_yields: bool = flat.has_method("yields_to_other_juice")
	host.free()
	return SUPPORT.pins(TEST_NAME, [
		["beside a Juice 3D node alone, the player plays through it", alone_name, "Juice3D"],
		["beside both (the 3D one first), it still plays through the 2D node, as old scenes do", both_name, "Juice"],
		["and with the 2D one first, as ever", flat_first_name, "Juice"],
		["a Juice 3D node the player had settled on gives way when a 2D one is there", cached_name, "Juice"],
		["Juice 3D says it plays only when no other Juice node does", yields, true],
		["the 2D node says nothing of the kind, so every old scene reads the same", flat_yields, false],
	])
