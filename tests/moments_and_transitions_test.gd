# Godot EventSheets - a moment is a file, and a transition is one walk with a swap in the middle.
#
# Two features that look nothing alike and are the same idea twice: a beat of the game written down
# as data, played by one row. A moment is a list of steps the Juice pack plays; a transition is a
# cover walked on, a scene swapped under it, and the cover walked off. This test drives both the way
# a row does - the pack's own functions, called on an instance built in memory and never added to a
# tree - so nothing here needs a renderer, a viewport or a frame.
#
# WHAT THIS CATCHES, and nothing else in the suite does:
#   - a starter moment that stops loading, or names a step word or a screen effect nothing answers
#     to, which is a file that plays half of itself in silence;
#   - the strength on a Moment row scaling a number it must not - a zoom percentage, a slowmo's time
#     scale - which reads as the moment mysteriously breaking at any strength but 1;
#   - a step that stops going through the ONE no-flashing clamp, so a player who asked for no
#     flashing gets a strobe from the layer that was added to protect them;
#   - the transition's progress model moving: the swap must land at the halfway point, and the cover
#     must be off at both ends, or a scene changes in front of the player;
#   - a transition shape whose shader file is missing or has lost its `progress` dial, which is a
#     transition that covers the screen and never uncovers it.
#
# THE ONE THING PLAYED FOR REAL is a shake step, because a shake is a number on the behaviour. The
# other step words reach for a tree - a timer, a tween, a camera - and a treeless instance is not
# where those are answered; what a moment does with their AMOUNTS is pinned through the two functions
# that decide it.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "moments_and_transitions_test"

## The three packs under test, loaded by path rather than named as classes: a test that names a class
## the class cache has not caught up with fails for the wrong reason.
const JUICE_SCRIPT := "res://eventsheet_addons/juice/juice_behavior.gd"
const SCENE_FLOW_SCRIPT := "res://eventsheet_addons/scene_flow/scene_flow_behavior.gd"
const SCREEN_FX_SCRIPT := "res://eventsheet_addons/screen_fx/screen_fx.gd"
const MOMENT_SCRIPT := "res://eventsheet_addons/moment_resource/moment_resource.gd"

## Where the starters and the transition shaders ship.
const MOMENT_DIRECTORY := "res://eventsheet_addons/juice/"
const TRANSITION_DIRECTORY := "res://eventsheet_addons/scene_flow/"

## The six starters, and the steps each one is made of. Pinned as VALUES rather than counted,
## because the point of a starter is what it does, and a file that quietly lost its second half
## would pass every count.
const STARTERS := {
	"impact": "shake,hitstop,chromatic,pulse",
	"kill": "shake,hitstop,shockwave,chromatic,pulse,slowmo",
	"triumph": "pulse,pulse,flash",
	"danger": "hold,hold",
	"calm": "hold,hold,hold,hold",
	"cut": "flash,zoom"
}


static func run() -> bool:
	var passed: bool = _a_moment_is_a_file()
	passed = _the_starters_are_files_that_load() and passed
	passed = _strength_scales_what_a_player_sees() and passed
	passed = _no_flashing_is_a_ceiling_here_too() and passed
	passed = _a_step_plays() and passed
	passed = _the_transition_walk() and passed
	passed = _every_shape_has_a_shader() and passed
	return passed


## A MOMENT IS A FILE: written, read back on another day, and still the same list of steps. This is
## the whole promise of a moment being a resource rather than a name in a dropdown - a game owns its
## moments, keeps them in version control and hands them to somebody else.
static func _a_moment_is_a_file() -> bool:
	var steps: Array[Dictionary] = [
		{"verb": "shake", "amount": 0.5, "effect": "", "seconds": 0.0},
		{"verb": "pulse", "amount": 0.7, "effect": "glitch", "seconds": 0.3}
	]
	var made: Resource = _a_moment("Boss hit", steps)
	var path: String = "user://tests/moment_round_trip.tres"
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var wrote: int = ResourceSaver.save(made, path)
	var read_back: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	var rows: Array = [
		["a moment writes out as a file", wrote, OK],
		["that reads back", read_back != null, true],
		["under the name it was given",
			"" if read_back == null else str(read_back.get("moment_name")), "Boss hit"],
		["with its steps in the order they fire", _verbs_of(read_back), "shake,pulse"],
		["and every number it recorded", _amounts_of(read_back), "0.5,0.7"],
		["including the screen effect a step names", _effects_of(read_back), ",glitch"]
	]
	return SUPPORT.pins(P, rows)


## THE SIX STARTERS. They are shipped files rather than code, so what they hold is a fact this can
## read - and every word in them has to be one the player answers to, because a step nothing claims
## does nothing at all and says so only in a warning nobody is watching for.
static func _the_starters_are_files_that_load() -> bool:
	var juice: Node = _a_juice()
	var screen: Node = _a_screen()
	var known_effects: PackedStringArray = screen.effect_words()
	var rows: Array = []
	var unknown_verbs: PackedStringArray = PackedStringArray()
	var unknown_effects: PackedStringArray = PackedStringArray()
	for called: String in STARTERS:
		var found: Resource = juice._moment_named(called)
		rows.append(["the %s starter is a file the Moment row finds by name" % called,
			found != null, true])
		rows.append(["and it is made of these steps", _verbs_of(found), str(STARTERS[called])])
		for step: Variant in juice._moment_steps(found):
			var entry: Dictionary = step as Dictionary
			var word: String = str(entry.get("verb", ""))
			if not juice.MOMENT_VERBS.has(word):
				unknown_verbs.append("%s/%s" % [called, word])
			var effect: String = str(entry.get("effect", ""))
			if word == "pulse" or word == "hold":
				if not known_effects.has(effect):
					unknown_effects.append("%s/%s" % [called, effect])
	rows.append(["every step word in them is one the player knows", ",".join(unknown_verbs), ""])
	rows.append(["and every screen effect they ask for is one the stack ships",
		",".join(unknown_effects), ""])
	juice.free()
	screen.free()
	return SUPPORT.pins(P, rows)


## THE STRENGTH ON THE ROW is how much of the moment you get, so it scales the amounts a player SEES
## and nothing else. A slowmo's time scale, a hitstop's freeze and a zoom's percentage are numbers of
## another kind: doubling one of those does not mean twice as much of anything, and a moment played
## at 0.5 that halved them would break in a way nobody could read off the file.
static func _strength_scales_what_a_player_sees() -> bool:
	var juice: Node = _a_juice()
	var rows: Array = [
		["a shake at full strength is the amount the file wrote",
			juice._moment_amount("shake", 0.4, 1.0), 0.4],
		["and at half strength, half of it", juice._moment_amount("shake", 0.4, 0.5), 0.2],
		["a pulse is scaled the same way, because it is also something seen",
			juice._moment_amount("pulse", 0.8, 0.5), 0.4],
		["a zoom percentage is NOT, because 115 per cent halved is not half a zoom",
			juice._moment_amount("zoom", 115.0, 0.5), 115.0],
		["nor is a slowmo's time scale", juice._moment_amount("slowmo", 0.35, 2.0), 0.35],
		["nor a hitstop's freeze", juice._moment_amount("hitstop", 0.0, 2.0), 0.0],
		["a negative strength is no moment rather than an inverted one",
			juice._moment_amount("shake", 0.4, -3.0), 0.0]
	]
	juice.free()
	return SUPPORT.pins(P, rows)


## NO FLASHING IS A CEILING, not a switch that turns the moments off. A player who asked for it gets
## the same rows - the hit still hits - with the amplitude held under the ceiling and the time held
## over the floor. The same Engine meta the built-in accessibility rows write, so a game carrying
## those needs nothing else.
static func _no_flashing_is_a_ceiling_here_too() -> bool:
	var flashing_was: Variant = Engine.get_meta("no_flashing", null)
	var juice: Node = _a_juice()
	Engine.set_meta("no_flashing", false)
	var rows: Array = [
		["with nothing asked for, a full amount is a full amount",
			juice._moment_amount("flash", 1.0, 1.0), 1.0],
		["and a quick step stays quick", juice._moment_seconds("flash", 0.05), 0.05]
	]
	Engine.set_meta("no_flashing", true)
	rows.append(["a player who asked for no flashing gets the same step under the ceiling",
		juice._moment_amount("flash", 1.0, 1.0), juice.MOMENT_FLASH_CEILING])
	rows.append(["held from below as well, so an inverted step cannot dodge it",
		juice._moment_amount("punch", -1.0, 1.0), -juice.MOMENT_FLASH_CEILING])
	rows.append(["and it is slowed to the floor, because a small strobe is still a strobe",
		juice._moment_seconds("flash", 0.05), juice.MOMENT_FLASH_FLOOR_SECONDS])
	rows.append(["while a step that is already slow is left alone",
		juice._moment_seconds("flash", 2.0), 2.0])
	rows.append(["a zoom is not held at all, because its number is not an amplitude",
		juice._moment_amount("zoom", 115.0, 1.0), 115.0])
	juice.free()
	Engine.set_meta("no_flashing", false)
	if flashing_was == null:
		Engine.remove_meta("no_flashing")
	else:
		Engine.set_meta("no_flashing", flashing_was)
	return SUPPORT.pins(P, rows)


## ONE STEP, PLAYED FOR REAL, so the table above is not the only thing keeping the two halves in
## step: a shake step has to arrive as trauma on the behaviour, at the strength the row asked for.
## And a moment nobody defined plays nothing rather than guessing.
static func _a_step_plays() -> bool:
	var juice: Node = _a_juice()
	juice._play_moment_step({"verb": "shake", "amount": 0.4, "effect": "", "seconds": 0.0}, 1.0)
	var rows: Array = [["a shake step arrives as trauma", juice.trauma, 0.4]]
	juice._play_moment_step({"verb": "shake", "amount": 0.4, "effect": "", "seconds": 0.0}, 0.5)
	# Printed to three places: two floats added are not the float you would have typed, and a pin
	# that reads "0.6 is not 0.6" teaches nobody anything.
	rows.append(["and a second one at half strength adds half as much", "%.3f" % juice.trauma,
		"0.600"])
	var defined: Resource = _a_moment("Boss", [] as Array[Dictionary])
	juice.define_moment("boss hit", defined)
	rows.append(["a defined name answers with the file it was pointed at",
		juice._moment_named("boss hit") == defined, true])
	rows.append(["under the name however it was typed", juice._moment_named(" Boss Hit ") == defined,
		true])
	juice.define_moment("boss hit", null)
	rows.append(["and an empty slot takes the name away again",
		juice._moment_named("boss hit"), null])
	rows.append(["a name nothing answers to is nothing, not a guess",
		juice._moment_named("nothing is called this"), null])
	juice.free()
	return SUPPORT.pins(P, rows)


## THE PROGRESS MODEL: out over the first half, the swap at the top, in over the second. It is one
## triangle, and everything about a transition reads it - the shader's dial, the moment the scene is
## exchanged, and the answer to which part of it we are in. A model that moved would change the scene
## in front of the player instead of under the cover, which is the one thing a transition exists to
## prevent.
static func _the_transition_walk() -> bool:
	var flow: Node = _a_scene_flow()
	var rows: Array = [
		["the cover is off at the start", flow.transition_cover(0.0, "linear"), 0.0],
		["fully on at the halfway point, which is where the scene is swapped",
			flow.transition_cover(0.5, "linear"), 1.0],
		["and off again at the end", flow.transition_cover(1.0, "linear"), 0.0],
		["a quarter of the way in it is half on", flow.transition_cover(0.25, "linear"), 0.5],
		["and three quarters of the way, half off again",
			flow.transition_cover(0.75, "linear"), 0.5],
		["the walk out is the first half", flow.transition_phase(0.25), "out"],
		["the swap is the midpoint", flow.transition_phase(0.5), "swap"],
		["and the walk back in is the second", flow.transition_phase(0.75), "in"],
		["an ease shapes the walk without moving its ends",
			"%s %s" % [flow.transition_cover(0.0, "smooth"), flow.transition_cover(0.5, "smooth")],
			"0.0 1.0"],
		["easing in starts the cover slowly", flow.transition_cover(0.25, "in"), 0.25],
		["easing out brings it on quickly and settles", flow.transition_cover(0.25, "out"), 0.75],
		["a word that is no ease is the plain walk rather than an error",
			flow.transition_cover(0.25, "nonsense"), 0.5],
		["a fraction past the end is still the end", flow.transition_cover(4.0, "linear"), 0.0],
		["the finished transition is a signal a row can answer",
			flow.has_signal("transition_finished"), true],
		["which the sheet reads as a trigger",
			FileAccess.get_file_as_string(SCENE_FLOW_SCRIPT).contains(
				"@ace_name(\"On Transition Finished\")"), true],
		["and the shaded transitions raise the same busy flag as the shipped fade",
			FileAccess.get_file_as_string(SCENE_FLOW_SCRIPT).contains(
				"add_to_group(SceneFlowBehavior.TRANSITION_GROUP)"), true]
	]
	flow.free()
	return SUPPORT.pins(P, rows)


## THE SHADERS ARE THE TRANSITIONS. A shape whose file is missing covers the screen with nothing and
## never uncovers it, so every word the pack offers is checked against a file that exists, compiles,
## and declares the one dial the walk turns.
static func _every_shape_has_a_shader() -> bool:
	var flow: Node = _a_scene_flow()
	var missing: PackedStringArray = PackedStringArray()
	var dialless: PackedStringArray = PackedStringArray()
	var shapes: PackedStringArray = flow.TRANSITIONS
	for shape: String in shapes:
		var path: String = TRANSITION_DIRECTORY + "transition_" + shape.replace(" ", "_") + ".gdshader"
		if not ResourceLoader.exists(path):
			missing.append(shape)
			continue
		var shader: Shader = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as Shader
		if shader == null or not _declares(shader, "progress") or not _declares(shader, "cover_color"):
			dialless.append(shape)
	var rows: Array = [
		["every shape the pack offers has a shader file", ",".join(missing), ""],
		["and every one of those declares the dial the walk turns and the colour it covers with",
			",".join(dialless), ""],
		["the seven shapes a transition can take", ",".join(shapes),
			"fade,wipe,dissolve,iris,blinds,pixelate,page curl"],
		["a shape that is no shape refuses rather than covering the screen for ever",
			flow.transition_shader("spiral"), null],
		["the wipe takes a picture to follow", _declares_in("transition_wipe.gdshader",
			"wipe_image"), true]
	]
	flow.free()
	return SUPPORT.pins(P, rows)


## One Juice behaviour, built and never added to a tree - which is what a headless test has.
static func _a_juice() -> Node:
	return (load(JUICE_SCRIPT) as GDScript).new()


## One Scene Flow behaviour, the same way.
static func _a_scene_flow() -> Node:
	return (load(SCENE_FLOW_SCRIPT) as GDScript).new()


## One Screen FX layer, for the one question that crosses packs: whether a starter names an effect
## the stack actually ships.
static func _a_screen() -> Node:
	return (load(SCREEN_FX_SCRIPT) as GDScript).new()


## One moment resource with the steps given. The steps arrive as an `Array[Dictionary]` because that
## is what the resource declares, and Godot's `set` on a typed property given an untyped array does
## NOTHING AT ALL - silently, with the property left holding its default.
static func _a_moment(called: String, steps: Array[Dictionary]) -> Resource:
	var made: Resource = (load(MOMENT_SCRIPT) as GDScript).new()
	made.set("moment_name", called)
	made.set("steps", steps)
	return made


## A moment's step words, in order - what a reader would see in the Inspector.
static func _verbs_of(moment: Resource) -> String:
	return _column_of(moment, "verb")


## Its amounts, in the same order.
static func _amounts_of(moment: Resource) -> String:
	return _column_of(moment, "amount")


## And the screen effects its steps name, which is empty for every step that does not need one.
static func _effects_of(moment: Resource) -> String:
	return _column_of(moment, "effect")


## One field of every step, in order, as one comparable line.
static func _column_of(moment: Resource, field: String) -> String:
	if moment == null:
		return ""
	var values: PackedStringArray = PackedStringArray()
	for step: Variant in (moment.get("steps") as Array):
		values.append(str((step as Dictionary).get(field, "")))
	return ",".join(values)


## Whether a shader declares a uniform by that name.
static func _declares(shader: Shader, dial: String) -> bool:
	for declared: Dictionary in shader.get_shader_uniform_list():
		if str(declared.get("name", "")) == dial:
			return true
	return false


## The same question, of a file in the pack folder.
static func _declares_in(file_name: String, dial: String) -> bool:
	var shader: Shader = ResourceLoader.load(TRANSITION_DIRECTORY + file_name, "",
		ResourceLoader.CACHE_MODE_IGNORE) as Shader
	return shader != null and _declares(shader, dial)
