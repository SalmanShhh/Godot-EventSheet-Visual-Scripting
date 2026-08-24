# EventForge - the three lighting behaviour packs (Light Flicker, Light Pulse, Day/Night Cycle).
#
# Two halves, and both are values rather than counts:
#
#   WHAT THE SHEET SEES - the vocabulary each pack publishes, pinned by the exact sentence a row
#   reads and the exact line it compiles to. A display template or a codegen template is what a
#   saved sheet depends on, so a change to either shows up here as a named string rather than as a
#   number that moved.
#
#   WHAT THE CODE DOES - the arithmetic under the clock, called directly on an instance. `_sun_turn`,
#   `_crossed`, `_daylight` and `it_is_day` need no scene tree and no frames, so the awkward cases
#   (a day that runs past midnight, the wrap at 0:00, a curve nobody drew) are pinned here where
#   they are cheap. The per-frame half - that a light's energy really moves - is a runtime smoke
#   run non-headless, because `_process` needs a main loop this suite deliberately has no access to.
#
# The two light packs also have to keep SHARING their binding block: the question "which property
# does this host spell brightness with" is one answer emitted into both files, and a copy that
# drifted would be two answers.
@tool
class_name LightingPacksTest
extends RefCounted

const FLICKER: String = "res://eventsheet_addons/light_flicker/light_flicker_behavior.gd"
const PULSE: String = "res://eventsheet_addons/light_pulse/light_pulse_behavior.gd"
const CYCLE: String = "res://eventsheet_addons/day_night_cycle/day_night_cycle_behavior.gd"

## The line both light packs must carry, byte for byte: the whole point of _lib's shared block is
## that neither pack owns its own copy of the brightness question.
const SHARED_BINDING: String = "\t_brightness_property = _first_property_of(PackedStringArray([\"energy\", \"light_energy\"]))"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _flicker_reads() and all_passed
	all_passed = _pulse_reads() and all_passed
	all_passed = _cycle_reads() and all_passed
	all_passed = _packs_share_one_binding() and all_passed
	all_passed = _the_clock_maths() and all_passed
	all_passed = _the_light_verbs_run() and all_passed
	return all_passed


## Light Flicker: two actions and one question, each pinned by the sentence and the line.
static func _flicker_reads() -> bool:
	var all_passed: bool = true
	var published: Dictionary = _published(FLICKER)
	all_passed = _check("Start Flickering reads as a sentence",
		_template(published, "Start Flickering"), "Start flickering after [b]{after_seconds}[/b] s") and all_passed
	all_passed = _check("Start Flickering compiles to the call",
		_code(published, "Start Flickering"), "{target}.start_flickering({after_seconds})") and all_passed
	all_passed = _check("Stop Flickering reads as a sentence",
		_template(published, "Stop Flickering"), "Stop flickering and settle at [b]{settle_at}[/b]") and all_passed
	all_passed = _check("Stop Flickering compiles to the call",
		_code(published, "Stop Flickering"), "{target}.stop_flickering({settle_at})") and all_passed
	# `{target}` is the retargetable node slot every behaviour verb carries; its DEFAULT is what a
	# freshly dropped row really writes, so this is the assertion that says the row does something.
	all_passed = _check("a dropped row calls the behaviour on its own node",
		str(_param(published, "Start Flickering", "target").get("default_value", "")), "$LightFlickerBehavior") and all_passed
	all_passed = _check("Is Flickering is a condition",
		_kind(published, "Is Flickering"), ACEDefinition.ACEType.CONDITION) and all_passed
	# The delay parameter is NAMED rather than left as its identifier, and the picker opens on the
	# GDScript default rather than on a zero somebody has to notice and change.
	all_passed = _check("the delay parameter is named",
		str(_param(published, "Start Flickering", "after_seconds").get("display_name", "")),
		"After Seconds") and all_passed
	all_passed = _check("the delay parameter starts at 0",
		str(_param(published, "Start Flickering", "after_seconds").get("default_value", "")), "0.0") and all_passed
	# The four Inspector knobs, as the emitted file really spells them - the Vector2 literal in
	# particular, which is why the knobs are written rather than handed over as a real Vector2.
	var source: String = FileAccess.get_file_as_string(FLICKER)
	all_passed = _check("the between knob keeps the numbers it was given",
		source.contains("@export var between: Vector2 = Vector2(0.8, 1.2)"), true) and all_passed
	all_passed = _check("the speed knob is a slider",
		source.contains("@export_range(0.1, 60, 0.1) var times_a_second: float = 12.0"), true) and all_passed
	all_passed = _check("reach flickering is off until asked for",
		source.contains("@export var also_flicker_reach: bool = false"), true) and all_passed
	all_passed = _check("the flame is lit on arrival",
		source.contains("@export var running: bool = true"), true) and all_passed
	return all_passed


## Light Pulse: the same two rows and the same question, on a wave instead of a noise field.
static func _pulse_reads() -> bool:
	var all_passed: bool = true
	var published: Dictionary = _published(PULSE)
	all_passed = _check("Start Pulsing reads as a sentence",
		_template(published, "Start Pulsing"), "Start pulsing after [b]{after_seconds}[/b] s") and all_passed
	all_passed = _check("Stop Pulsing compiles to the call",
		_code(published, "Stop Pulsing"), "{target}.stop_pulsing({settle_at})") and all_passed
	all_passed = _check("Is Pulsing is a condition",
		_kind(published, "Is Pulsing"), ACEDefinition.ACEType.CONDITION) and all_passed
	var source: String = FileAccess.get_file_as_string(PULSE)
	all_passed = _check("the pulse breathes wider than the flame flickers",
		source.contains("@export var between: Vector2 = Vector2(0.6, 1.4)"), true) and all_passed
	all_passed = _check("a breath is measured as a period, not a speed",
		source.contains("@export_range(0.05, 60, 0.05) var period_seconds: float = 2.0"), true) and all_passed
	return all_passed


## Day/Night Cycle: four actions, two questions, four triggers, and the reading of the clock.
static func _cycle_reads() -> bool:
	var all_passed: bool = true
	var published: Dictionary = _published(CYCLE)
	all_passed = _check("Set The Time reads as a sentence",
		_template(published, "Set The Time"), "Set the time to [b]{hour}[/b]:00") and all_passed
	all_passed = _check("Set The Time compiles to the call",
		_code(published, "Set The Time"), "{target}.set_the_time({hour})") and all_passed
	all_passed = _check("Run The Clock Faster reads as a sentence",
		_template(published, "Run The Clock Faster"), "Run the clock [b]{times_faster}[/b] times faster") and all_passed
	all_passed = _check("Pause The Clock compiles to the call",
		_code(published, "Pause The Clock"), "{target}.pause_the_clock()") and all_passed
	all_passed = _check("Resume The Clock compiles to the call",
		_code(published, "Resume The Clock"), "{target}.resume_the_clock()") and all_passed
	all_passed = _check("It Is Night reads as a sentence",
		_template(published, "It Is Night"), "It is night") and all_passed
	all_passed = _check("It Is Day is a condition",
		_kind(published, "It Is Day"), ACEDefinition.ACEType.CONDITION) and all_passed
	# The hour is an expression because it is an exported property: a row reads it, the Inspector
	# sets it, and Set The Time is the row that moves it safely.
	all_passed = _check("the hour reads back as an expression",
		_kind(published, "Time Of Day"), ACEDefinition.ACEType.EXPRESSION) and all_passed
	all_passed = _check("the hour inserts the property",
		_code(published, "Time Of Day"), "{target}.time_of_day") and all_passed
	# The four moments, each a real signal so a sheet connects to it the way it connects to any other.
	for moment: Array in [["On Sunrise", "sunrise"], ["On Sunset", "sunset"], ["On Midnight", "midnight"], ["On The Hour", "hour_struck"]]:
		all_passed = _check("%s is a trigger" % str(moment[0]),
			_kind(published, str(moment[0])), ACEDefinition.ACEType.TRIGGER) and all_passed
		all_passed = _check("%s names its signal" % str(moment[0]),
			str(_definition(published, str(moment[0])).metadata.get("source_name", "")), str(moment[1])) and all_passed
	all_passed = _check("the hour trigger carries the hour it struck",
		_param(published, "On The Hour", "hour").get("id", ""), "hour") and all_passed
	var source: String = FileAccess.get_file_as_string(CYCLE)
	all_passed = _check("the sun target only accepts lights",
		source.contains("@export_node_path(\"Light2D\", \"Light3D\") var sun_light: NodePath = \"\""), true) and all_passed
	all_passed = _check("the sky target accepts either dimension's holder",
		source.contains("@export_node_path(\"WorldEnvironment\", \"CanvasModulate\") var world_lighting: NodePath = \"\""), true) and all_passed
	for curve: String in ["sun_brightness", "ambient_brightness", "sky_tint_strength"]:
		all_passed = _check("%s is a curve a designer draws" % curve,
			source.contains("@export var %s: Curve = null" % curve), true) and all_passed
	return all_passed


## The brightness question is answered once, in _lib, and emitted into both light packs. A pack that
## grew its own copy would answer it twice, which is how the two dimensions come apart.
static func _packs_share_one_binding() -> bool:
	var all_passed: bool = true
	for path: String in [FLICKER, PULSE]:
		all_passed = _check("%s carries the shared binding" % path.get_file(),
			FileAccess.get_file_as_string(path).contains(SHARED_BINDING), true) and all_passed
	return all_passed


## The arithmetic the clock is made of, called straight on an instance - no tree, no frames.
static func _the_clock_maths() -> bool:
	var all_passed: bool = true
	var cycle: Node = load(CYCLE).new()
	cycle.sunrise_hour = 6.0
	cycle.sunset_hour = 18.0

	# The sun's circle: on the horizon at sunrise, overhead at the middle of the day, on the horizon
	# again at sunset, and all the way round by the next sunrise.
	cycle.time_of_day = 6.0
	all_passed = _check("the sun is on the horizon at sunrise", cycle._sun_turn(), 0.0) and all_passed
	cycle.time_of_day = 12.0
	all_passed = _check("the sun is overhead at midday", cycle._sun_turn(), 0.25) and all_passed
	all_passed = _check("midday is full daylight", cycle._daylight(), 1.0) and all_passed
	cycle.time_of_day = 18.0
	all_passed = _check("the sun is on the horizon at sunset", cycle._sun_turn(), 0.5) and all_passed
	cycle.time_of_day = 0.0
	all_passed = _check("midnight is the far side of the circle", cycle._sun_turn(), 0.75) and all_passed
	all_passed = _check("midnight has no daylight at all", cycle._daylight(), 0.0) and all_passed

	# A day that runs past midnight (a night shift, a polar summer) is stretched the same way, so
	# noon is still overhead rather than wherever twelve o'clock happens to fall.
	cycle.sunrise_hour = 20.0
	cycle.sunset_hour = 4.0
	cycle.time_of_day = 0.0
	all_passed = _check("a day that runs past midnight still peaks in its middle",
		cycle._sun_turn(), 0.25) and all_passed
	all_passed = _check("and it counts as day", cycle.it_is_day(), true) and all_passed
	cycle.time_of_day = 12.0
	all_passed = _check("noon is night on that schedule", cycle.it_is_night(), true) and all_passed

	# The wrap at midnight is the one crossing a plain comparison gets wrong.
	all_passed = _check("a mark passed inside one reading is caught",
		cycle._crossed(5.9, 6.1, 6.0), true) and all_passed
	all_passed = _check("a mark not reached yet is not caught",
		cycle._crossed(5.7, 5.9, 6.0), false) and all_passed
	all_passed = _check("midnight is caught across the wrap",
		cycle._crossed(23.9, 0.1, 0.0), true) and all_passed
	all_passed = _check("a mark behind the wrap is not caught twice",
		cycle._crossed(23.9, 0.1, 12.0), false) and all_passed
	all_passed = _check("a still clock crosses nothing",
		cycle._crossed(6.0, 6.0, 6.0), false) and all_passed

	# A curve nobody drew falls back to the shape the sun itself takes, so an unopened Inspector
	# still gives a working day rather than a black one.
	cycle.sunrise_hour = 6.0
	cycle.sunset_hour = 18.0
	cycle.time_of_day = 12.0
	all_passed = _check("an undrawn curve falls back to the value it is given",
		cycle._sample(null, 0.42), 0.42) and all_passed
	var drawn: Curve = Curve.new()
	drawn.add_point(Vector2(0.0, 0.25))
	drawn.add_point(Vector2(1.0, 0.25))
	all_passed = _check("a drawn curve is read at the hour it is",
		cycle._sample(drawn, 0.0), 0.25) and all_passed

	# Set The Time takes the hour it is given, wrapping rather than refusing.
	cycle.set_the_time(26.0)
	all_passed = _check("Set The Time wraps past the end of the day", cycle.time_of_day, 2.0) and all_passed
	cycle.run_the_clock(-5.0)
	all_passed = _check("the clock never runs backwards", cycle.clock_scale, 0.0) and all_passed
	cycle.free()
	return all_passed


## The two light packs' verbs, called with no light attached: the guards are what stop a behaviour
## dropped on the wrong node from faulting every frame.
static func _the_light_verbs_run() -> bool:
	var all_passed: bool = true
	for path: String in [FLICKER, PULSE]:
		var behaviour: Node = load(path).new()
		var name_text: String = path.get_file()
		var start: String = "start_flickering" if path == FLICKER else "start_pulsing"
		var stop: String = "stop_flickering" if path == FLICKER else "stop_pulsing"
		var asks: String = "is_flickering" if path == FLICKER else "is_pulsing"
		behaviour.call(start, 0.0)
		all_passed = _check("%s starts on the frame it is told to" % name_text, behaviour.call(asks), true) and all_passed
		behaviour.call(start, 2.5)
		all_passed = _check("%s is not running while it waits" % name_text, behaviour.call(asks), false) and all_passed
		all_passed = _check("%s stays switched off while it waits" % name_text, bool(behaviour.get("running")), false) and all_passed
		# With no light attached the settle is skipped rather than faulting - the wrong-parent case.
		behaviour.call(stop, 0.25)
		all_passed = _check("%s stops without a light to stop" % name_text, behaviour.call(asks), false) and all_passed
		behaviour.free()
	return all_passed


## Everything one pack publishes, keyed by the name a reader sees.
static func _published(script_path: String) -> Dictionary:
	var by_name: Dictionary = {}
	for definition: ACEDefinition in EventSheetPackReadingCheck.definitions_for_script(script_path):
		by_name[definition.display_name] = definition
	return by_name


static func _definition(published: Dictionary, display_name: String) -> ACEDefinition:
	var found: Variant = published.get(display_name, null)
	return found as ACEDefinition if found is ACEDefinition else ACEDefinition.new()


static func _template(published: Dictionary, display_name: String) -> String:
	return str(_definition(published, display_name).metadata.get("display_template", ""))


static func _code(published: Dictionary, display_name: String) -> String:
	return str(_definition(published, display_name).metadata.get("codegen_template", ""))


static func _kind(published: Dictionary, display_name: String) -> int:
	return _definition(published, display_name).ace_type


static func _param(published: Dictionary, display_name: String, parameter_id: String) -> Dictionary:
	for parameter: Variant in _definition(published, display_name).parameters:
		if parameter is Dictionary and str((parameter as Dictionary).get("id", "")) == parameter_id:
			return parameter as Dictionary
	return {}


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] %s" % label)
	print("       expected: ", expected)
	print("       actual:   ", actual)
	return false
