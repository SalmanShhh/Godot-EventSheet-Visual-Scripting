# A whole world saved as a file, put on and crossed over to - the rows, and the helper behind them.
#
# The claim this file holds to account has three parts, and the middle one is the whole reason the
# work is a real function rather than a template:
#
#   * NEITHER ARTIST FILE IS MODIFIED. The look on disk is loaded, deep-copied, and the COPY is what
#     the node wears - so turning the fog up afterwards changes the scene and nothing else. Pinned by
#     reaching into the file on disk after a row has run and asking whether it moved.
#   * A CROSSFADE IS TWO HALVES. Numbers, vectors and colours are WALKED; switches, modes and
#     resources are CUT, all at once, at the halfway point, because there is nothing between "glow
#     on" and "glow off" to walk through. Pinned as which properties land in which half, and by
#     applying the cut to a live world and asking what moved.
#   * THE END IS SAID OUT LOUD. A finished blend raises the node's own `world_look_blended` signal
#     with the look it landed on - a plain signal a sheet declares for itself, so it is pinned on a
#     node that declares one.
#
# The looks here are made in the test and saved to `user://`. Nothing named ships with the plugin,
# which is the point: a look is the project's own file.
@tool
class_name WorldLookTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const MODULE := preload("res://addons/eventforge/registration/modules/world_look_aces.gd")
const RESOLVER := preload("res://addons/eventforge/compiler/trigger_resolver.gd")

## Where the two made-up looks are written. Named after this test so a parallel shard cannot collide
## with another one's file.
const DUSK_PATH := "user://__world_look_test_dusk.tres"
const NOON_PATH := "user://__world_look_test_noon.tres"

## The script a node wears when it wants to hear about a finished blend - the plain signal block a
## sheet would declare, written as a real file because a script built from a string in memory has no
## path for the engine to load it back through.
const LISTENER_PATH := "user://__world_look_test_listener.gd"
const LISTENER_SOURCE := """extends WorldEnvironment

signal world_look_blended(look)

var heard: String = ""


func remember(look: String) -> void:
	heard = look
"""


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_rows() and ok
	ok = _test_the_trigger_is_a_plain_signal() and ok
	ok = _test_a_look_is_worn_as_a_copy() and ok
	ok = _test_the_artist_file_is_untouched() and ok
	ok = _test_a_blend_walks_the_numbers_and_cuts_the_rest() and ok
	ok = _test_the_midpoint_cut_writes_only_the_cut_half() and ok
	ok = _test_the_end_is_said_out_loud() and ok
	ok = _test_a_missing_look_does_nothing() and ok
	return ok


## The four rows, by the bytes they emit and the fields they hand a reader. Every one of them names
## the node it acts on, because a look belongs to a node rather than to a class.
static func _test_the_rows() -> bool:
	var templates: Dictionary = {}
	var fields: Dictionary = {}
	for row: ACEDescriptor in MODULE.get_descriptors():
		templates[row.ace_id] = str(row.codegen_template)
		var named: PackedStringArray = PackedStringArray()
		for parameter: ACEParam in row.params:
			named.append("%s=%s" % [parameter.id, str(parameter.default_value)])
		fields[row.ace_id] = ", ".join(named)
	return SUPPORT.pins("world_look_test", [
		["putting a look on is one call", templates.get("WorldUseLook", ""),
			"WorldLook.use({node}, {look})"],
		["crossing over is the same call with a length of time",
			templates.get("WorldBlendToLook", ""),
			"WorldLook.blend({node}, {look}, {seconds})"],
		["and the look being worn is read back off the node",
			templates.get("WorldCurrentLook", ""), "WorldLook.came_from({node})"],
		["the blend row's fields", fields.get("WorldBlendToLook", ""),
			"node=$WorldEnvironment, look=\"\", seconds=1.0"],
		["the trigger emits nothing of its own", templates.get("OnWorldLookBlended", ""), ""]
	])


## The other half of the trigger: a plain signal the sheet declares, connected the way every other
## declared signal is. Nothing here invents a mechanism.
static func _test_the_trigger_is_a_plain_signal() -> bool:
	var event: EventRow = EventRow.new()
	event.trigger_id = "OnWorldLookBlended"
	var resolved: Dictionary = RESOLVER.resolve_trigger(event)
	return SUPPORT.pins("world_look_test", [
		["the handler is named after the signal", str(resolved.get("function_name", "")),
			"_on_world_look_blended"],
		["it is handed the look that landed", str(resolved.get("args", "")), "look: String"],
		["and it connects to the sheet's own signal", str(resolved.get("signal_name", "")),
			"world_look_blended"]
	])


## A look is worn as a COPY, and the file it came from is written down beside it - which is the only
## place the answer can come from, because a copy has no path of its own.
static func _test_a_look_is_worn_as_a_copy() -> bool:
	_write_look(DUSK_PATH, 0.5, true)
	var world: WorldEnvironment = WorldEnvironment.new()
	WorldLook.use(world, DUSK_PATH)
	var worn: Environment = world.environment
	var ok: bool = SUPPORT.pins("world_look_test", [
		["the world wears the look's own values", worn.fog_density, 0.5],
		["worn as a copy, which has no file of its own", worn.resource_path, ""],
		["and the file it came from is remembered", WorldLook.came_from(world), DUSK_PATH]
	])
	world.free()
	return ok


## And the file on disk does not move when the worn copy is written through - the whole reason the
## copy is taken.
static func _test_the_artist_file_is_untouched() -> bool:
	_write_look(DUSK_PATH, 0.5, true)
	var world: WorldEnvironment = WorldEnvironment.new()
	WorldLook.use(world, DUSK_PATH)
	world.environment.fog_density = 0.75
	var reread: Environment = ResourceLoader.load(DUSK_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	var ok: bool = SUPPORT.pins("world_look_test", [
		["the scene's own copy took the change", world.environment.fog_density, 0.75],
		["and the look on disk is exactly as it was saved", reread.fog_density, 0.5]
	])
	world.free()
	return ok


## Which half of a world is walked and which half is cut. Asked of the two lists themselves, by name,
## because that split is the whole design of a crossfade.
static func _test_a_blend_walks_the_numbers_and_cuts_the_rest() -> bool:
	var wanted: Environment = Environment.new()
	var walked: PackedStringArray = WorldLook.crossed_properties(wanted)
	var cut: Dictionary = WorldLook.cut_values(wanted)
	return SUPPORT.pin_table("world_look_test", {
		"fog_density": "walked",
		"adjustment_saturation": "walked",
		"fog_light_color": "walked",
		"sky_rotation": "walked",
		"fog_enabled": "cut",
		"glow_enabled": "cut",
		"background_mode": "cut",
		"tonemap_mode": "cut",
		"sky": "cut",
		"adjustment_color_correction": "cut",
		# A resource's own identity is not part of a look: carrying the artist file's name across
		# would hand this scene that file's identity along with its appearance.
		"resource_name": "carried by neither",
		"resource_local_to_scene": "carried by neither"
	}, func(property: Variant) -> String:
		var name_text: String = str(property)
		if walked.has(name_text):
			return "walked"
		return "cut" if cut.has(name_text) else "carried by neither")


## The midpoint itself: applying the cut writes the switches and the modes and leaves every number
## exactly where the walk had got it to.
static func _test_the_midpoint_cut_writes_only_the_cut_half() -> bool:
	var wanted: Environment = Environment.new()
	wanted.fog_enabled = true
	wanted.glow_enabled = true
	wanted.fog_density = 0.75
	var live: Environment = Environment.new()
	live.fog_density = 0.25
	WorldLook.apply_cut(live, WorldLook.cut_values(wanted))
	# `fog_mode` is one of Godot's own setters that moves a number as a side effect, so this is also
	# the pin on the put-back: without it the fog would jerk to the new mode's default density for a
	# frame in the middle of every crossfade.
	return SUPPORT.pins("world_look_test", [
		["the switches land all at once", [live.fog_enabled, live.glow_enabled], [true, true]],
		["and the number is left to the walk that is carrying it", live.fog_density, 0.25]
	])


## The end of a blend: the look written down, and the node's own signal raised with it. A blend of no
## time at all lands at once, which is what lets a headless test ask about the endpoint.
static func _test_the_end_is_said_out_loud() -> bool:
	_write_look(NOON_PATH, 0.25, false)
	var listener: Script = _listener_script()
	if listener == null:
		return SUPPORT.check("world_look_test", "the listening script builds", "missing", "built")
	var world: WorldEnvironment = WorldEnvironment.new()
	world.set_script(listener)
	world.connect("world_look_blended", Callable(world, "remember"))
	WorldLook.blend(world, NOON_PATH, 0.0)
	var ok: bool = SUPPORT.pins("world_look_test", [
		["the world landed on the look", world.environment.fog_density, 0.25],
		["the look it landed on is remembered", WorldLook.came_from(world), NOON_PATH],
		["and the node said so with its own signal", str(world.get("heard")), NOON_PATH]
	])
	world.free()
	return ok


## A path that names no look does NOTHING - it does not error, and it does not blank the world the
## scene is already wearing. A look is dressing, and a missing one must never take a game down.
static func _test_a_missing_look_does_nothing() -> bool:
	var world: WorldEnvironment = WorldEnvironment.new()
	var already: Environment = Environment.new()
	already.fog_density = 0.375
	world.environment = already
	WorldLook.use(world, "user://__world_look_test_nothing_here.tres")
	WorldLook.blend(world, "", 0.0)
	var ok: bool = SUPPORT.pins("world_look_test", [
		["the world the scene was wearing is untouched", world.environment.fog_density, 0.375],
		["and nothing was written down about a look", WorldLook.came_from(world), ""]
	])
	world.free()
	return ok


## One made-up look, saved where the rows can load it from. Two dials are enough: one number for the
## walked half and one switch for the cut half.
static func _write_look(path: String, fog_density: float, fog_enabled: bool) -> void:
	var look: Environment = Environment.new()
	look.fog_density = fog_density
	look.fog_enabled = fog_enabled
	ResourceSaver.save(look, path)


## The listening script as a real file on disk, because a GDScript built from a string in memory has
## no path and the engine cannot load one back through nothing.
static func _listener_script() -> Script:
	var file: FileAccess = FileAccess.open(LISTENER_PATH, FileAccess.WRITE)
	if file == null:
		return null
	file.store_string(LISTENER_SOURCE)
	file.close()
	return ResourceLoader.load(LISTENER_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Script
