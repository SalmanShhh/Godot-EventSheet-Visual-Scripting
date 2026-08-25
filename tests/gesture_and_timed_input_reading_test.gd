@tool
class_name GestureAndTimedInputReadingTest
extends RefCounted

# Pins batch thirteen's input readings and the vocabulary behind them:
#
#   The sensor SHAPES - a stored neutral point (Set neutral to Touch.Acceleration), the tilt
#        fed into movement (Steer by tilt x at ...), and the rotation rate fed into yaw and pitch
#        (Aim by gyro), which is mouse look with the phone doing the turning
#   Swipes and drawn shapes claimed as one pattern, with the behaviour that does the whole
#        thing offered as the adoption
#   A shooter's shots, blasts and wrapping weapon index, and the secrets counter beside them
#   The flag-and-deadline pair an input window is opened with, read as one row that says which
#        clock it is on
#   The options-screen shape - the live Input Map being rewritten and the settings the packs read
#
# Four gates, in the order they matter:
#   1. the grammar's own values - one shape, one sentence, asserted literally;
#   2. the whole path - a hand-written file opened as a sheet, walked row by row;
#   3. the pattern registry - each new shape claimed on the event that owns it;
#   4. the promise all of them rest on - the file still saves byte-identically.
#
# A fifth gate stands beside them: the AUTHORED rows write the very lines the readings recognise, so
# the picker and the reader cannot drift apart. Their shipped templates are asserted post-transform
# (a node-scoped ACE gains the optional "On node" prefix on its way to the registry).
#
# The source lives here as a string rather than in tests/fixtures/ for the same reason its sibling
# reading tests' sources do: the lifter's byte gate compares against what the COMPILER would emit,
# and the compiler puts ONE blank line between functions.

const SOURCE_PATH := "user://eventforge_gesture_timed_input_reading.gd"

const SOURCE: String = """extends CharacterBody3D

@onready var cam: Camera3D = $Camera3D
@export var tilt_strength := 900.0
var neutral := Vector3.ZERO
var window_open := false
var window_until := 0.0
var weapons: Array = []
var weapon_index := 0
var secrets_found: Array = []
var listening_for := ""

func calibrate() -> void:
	neutral = Input.get_accelerometer()

func steer_by_tilt(delta: float) -> void:
	var tilt := Input.get_accelerometer() - neutral
	velocity.x = tilt.x * tilt_strength * delta

func aim_by_gyro(delta: float) -> void:
	var rate := Input.get_gyroscope()
	rotate_y(-rate.y * delta)
	cam.rotate_x(-rate.x * delta)

func open_dodge_window(seconds: float) -> void:
	window_open = true
	window_until = Time.get_ticks_msec() / 1000.0 + seconds

func answer_the_window(event: InputEvent) -> void:
	if window_open and event.is_action_pressed("dodge"):
		var remaining := window_until - Time.get_ticks_msec() / 1000.0
		if remaining > 0.15:
			print("good")

func gather_the_stroke(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		print("down")

func next_weapon() -> void:
	weapon_index = (weapon_index + 1) % weapons.size()

func find_secret(secret_name: String) -> void:
	if not secret_name in secrets_found:
		secrets_found.append(secret_name)

func rebind(event: InputEvent) -> void:
	InputMap.action_erase_events(listening_for)
	InputMap.action_add_event(listening_for, event)
"""

## The ace_ids these items add, with the template each one SHIPS - after the registry has given a
## node-scoped ACE its optional "On node" prefix. Frozen from here on: an authored row must keep
## writing the very line the reading above recognises.
static var SHIPPED_TEMPLATES: Dictionary = {
	"TouchSetNeutralTilt": "{neutral} = Input.get_accelerometer()",
	"TouchSteerByTilt": "{target.}velocity.{motion_axis} = {tilt}.{sensor_axis} * {strength} * delta",
	# No "On node" prefix on this one: its second line leads with a slot rather than a member, so the
	# registry leaves the whole template alone - which is the spelling a hand-written gyro aim has.
	"TouchAimByGyro": "rotate_y(-{rate}.y * delta)\n{camera}.rotate_x(-{rate}.x * delta)",
	# The Prompt tail sits at the very END of both window templates and ships blank, which is what
	# lets the window own the prompt without moving a single byte of what a promptless window writes.
	"OpenInputWindow": "{open_flag} = true\n{deadline} = Time.get_ticks_msec() / 1000.0 + {seconds}{prompt}",
	"CloseInputWindow": "{open_flag} = false{prompt}",
	"InputWindowMissed": "({open_flag} and Time.get_ticks_msec() / 1000.0 >= {deadline})",
	"SwitchToNextWeapon": "{index} = ({index} + 1) % {weapons}.size()",
	"SwitchToPreviousWeapon": "{index} = ({index} - 1 + {weapons}.size()) % {weapons}.size()",
	"RebindControlTo": "InputMap.action_erase_events({action})\nInputMap.action_add_event({action}, {event})",
	"SetEffectStrength": "Engine.set_meta(\"effect_strength\", clampf({percent} / 100.0, 0.0, 1.0))",
	"NoFlashing": "bool(Engine.get_meta(\"no_flashing\", false))"
}

## Every reading the opened file must contain, one per shape these items claim.
static var EXPECTED_READINGS: PackedStringArray = PackedStringArray([
	"System ▸ Set neutral to Touch.Acceleration",
	"CharacterBody3D ▸ Steer by tilt x at tilt strength",
	"CharacterBody3D ▸ Aim by gyro",
	"System ▸ Open input window \"dodge\" for seconds"
])

## Readings the file must NOT contain: the lines each run swallowed. A run that silently stopped
## firing would otherwise pass the list above by never being asked about.
static var FORBIDDEN_READINGS: PackedStringArray = PackedStringArray([
	"cam ▸ Rotate around X by -rate.x * delta",
	"CharacterBody3D ▸ Set window open to true"
])


static func run() -> bool:
	var ok: bool = true
	ok = _grammar_values() and ok
	ok = _shipped_templates() and ok
	var opened: Dictionary = _open_and_read()
	var readings: PackedStringArray = opened.get("readings", PackedStringArray())
	for expected: String in EXPECTED_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	for forbidden: String in FORBIDDEN_READINGS:
		ok = _check("no row still reads \"%s\"" % forbidden, readings.has(forbidden), false) and ok
	ok = _pattern_claims(opened.get("patterns", {})) and ok
	ok = _round_trip() and ok
	ok = _starters() and ok
	ok = _teach_and_save_are_one_flow() and ok
	return ok


## Teaching a shape and saving the library used to be two half-truths: teaching wrote into the
## library but nothing said so, and saving replaced the library wholesale and then did NOTHING at all
## when the resource had no file - the guide had to carry a trap paragraph for both. One write-through
## now serves teach, forget and save, and every refusal says why out loud. Both rows keep their ids.
static func _teach_and_save_are_one_flow() -> bool:
	var ok: bool = true
	var source: String = FileAccess.get_file_as_string("res://eventsheet_addons/touch_gestures/touch_gestures.gd")
	ok = _check("teaching goes through the one write-through",
		source.contains("\t_shapes[shape_name] = _normalise(_stroke)\n\t_write_through_to_library()"), true) and ok
	ok = _check("and so does forgetting",
		source.contains("\t_shapes.erase(shape_name)\n\t_write_through_to_library()"), true) and ok
	ok = _check("the write-through marks the resource changed, which is what makes Save write it",
		source.contains("\tshape_library.shapes = _shapes.duplicate(true)\n\tshape_library.emit_changed()"), true) and ok
	ok = _check("saving with no library attached says so instead of returning quietly",
		source.contains("push_warning(\"[Touch Gestures] No shape library is attached"), true) and ok
	ok = _check("and so does saving a library that has no file to be written to",
		source.contains("push_warning(\"[Touch Gestures] The attached shape library has never been saved as a file"), true) and ok
	ok = _check("both rows keep the ids they shipped with",
		source.contains("## @ace_name(\"Teach Shape From Stroke\")") \
			and source.contains("## @ace_name(\"Save Shapes To Library\")"), true) and ok
	var guide: String = FileAccess.get_file_as_string("res://docs/Addons/Touch-Gestures.md")
	ok = _check("the guide no longer documents the trap as a trap",
		guide.contains("Teaching writes to the library, but only saving makes it permanent."), false) and ok
	ok = _check("it says what actually happens now",
		guide.contains("Teaching updates the library there and then; saving is what puts it on disk."), true) and ok
	return ok


## The two starter sheets these items add compile to GDScript that actually parses, and each one is
## the kind of script it says it is. A starter is the first thing a newcomer compiles, so a starter
## that does not is worse than no starter.
static func _starters() -> bool:
	var ok: bool = true
	var arsenal: EventSheetResource = EventSheetStarterTemplates.build_starter(30)
	var options: EventSheetResource = EventSheetStarterTemplates.build_starter(31)
	ok = _check("the arsenal starter is a body that moves", arsenal.host_class, "CharacterBody3D") and ok
	ok = _check("the options starter is a screen", options.host_class, "Control") and ok
	ok = _check("the options starter remembers its settings between runs",
		bool((options.variables.get("effect_strength_percent", {}) as Dictionary)
			.get("attributes", {}).get("remember", false)), true) and ok
	for named: Array in [["boomer arsenal", arsenal], ["game options", options]]:
		var built: String = str(SheetCompiler.compile(named[1] as EventSheetResource,
			"user://eventforge_x13_starter.gd").get("output", ""))
		var script: GDScript = GDScript.new()
		script.source_code = built
		ok = _check("the %s starter compiles to GDScript that parses" % str(named[0]),
			script.reload(), OK) and ok
	return ok


## The sentence context an opened tilt-and-window script hands the grammar. The three fact maps are
## what the file itself says - which value is a tilt, which is a rotation rate, and which flag and
## deadline make up the window - so nothing here is a guess a single line could not check.
static func _context() -> Dictionary:
	return {
		"self_object": "Player",
		"script_object": "Player",
		"self_class": "CharacterBody3D",
		"object_classes": {"cam": "Camera3D"},
		"engine_properties": {"position": true, "velocity": true},
		"tilt_variables": {"tilt": "neutral"},
		"rate_variables": {"rate": true},
		"input_window": {
			"flag": "window_open", "deadline": "window_until",
			"action": "\"dodge\"", "perfect": "0.15"
		}
	}


## Gate one: the grammar answering on its own, value by value.
static func _grammar_values() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	# The calibration line, and the two ways it is refused.
	ok = _check("the stored neutral point reads as the calibration row",
		str(EventSheetSentence.tilt_neutral_parts("neutral = Input.get_accelerometer()", context)
			.get("text", "")), "Set neutral to Touch.Acceleration") and ok
	ok = _check("the calibration row says what the player has to do",
		str(EventSheetSentence.tilt_neutral_parts("neutral = Input.get_accelerometer()", context)
			.get("note", "")), "hold the device how you want \"flat\" to feel") and ok
	ok = _check("a sensor read the file never measures a tilt from is refused",
		EventSheetSentence.tilt_neutral_parts("shake = Input.get_accelerometer()", context).is_empty(),
		true) and ok
	# The tilt fed into movement, and the same line without a tilt behind it.
	ok = _check("the tilt fed into movement reads as steering",
		str(EventSheetSentence.tilt_steer_parts("velocity.x = tilt.x * tilt_strength * delta", context)
			.get("text", "")), "Steer by tilt x at tilt strength") and ok
	ok = _check("a multiplication by something that is not a tilt is refused",
		EventSheetSentence.tilt_steer_parts("velocity.x = wind.x * tilt_strength * delta", context)
			.is_empty(), true) and ok
	# The two halves of a gyro aim, and the note they share.
	var turn: Dictionary = EventSheetSentence.gyro_aim_turn_parts("rotate_y(-rate.y * delta)", context)
	ok = _check("the body's half of a gyro aim names the rate", str(turn.get("rate", "")), "rate") and ok
	ok = _check("the camera's half names the camera",
		str(EventSheetSentence.gyro_aim_pitch_parts("cam.rotate_x(-rate.x * delta)", context, "rate")
			.get("camera", "")), "cam") and ok
	ok = _check("a pitch driven by a different value is refused",
		EventSheetSentence.gyro_aim_pitch_parts("cam.rotate_x(-look.x * delta)", context, "rate")
			.is_empty(), true) and ok
	ok = _check("the gyro note says where each half happens and what drives it",
		EventSheetSentence.gyro_aim_note(),
		"yaw on the body, pitch on the camera · Touch.RotationRate") and ok
	# The opened window, and the note that says which clock the deadline is on.
	var opened: Dictionary = EventSheetSentence.input_window_parts("window_open = true",
		"window_until = Time.get_ticks_msec() / 1000.0 + seconds", context)
	ok = _check("the flag and the deadline read as one opened window",
		str(opened.get("text", "")), "Open input window \"dodge\" for seconds") and ok
	ok = _check("the window note says the perfect band and which clock it is on",
		str(opened.get("note", "")),
		"perfect = the last 0.15s · on the engine clock, which keeps running while paused") and ok
	ok = _check("a flag with no deadline beside it is refused",
		EventSheetSentence.input_window_parts("window_open = true", "hp = 100", context).is_empty(),
		true) and ok
	ok = _check("a window note with no graded answers still says which clock",
		EventSheetSentence.input_window_note(""),
		"on the engine clock, which keeps running while paused") and ok
	return ok


## Gate five: the authored rows write the very lines the readings recognise.
static func _shipped_templates() -> bool:
	var ok: bool = true
	var shipped: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		shipped[str(descriptor.ace_id)] = str(descriptor.codegen_template)
	for ace_id: String in SHIPPED_TEMPLATES:
		ok = _check("%s writes the line the reading recognises" % ace_id,
			str(shipped.get(ace_id, "")), str(SHIPPED_TEMPLATES[ace_id])) and ok
	return ok


## Gate three: each new shape is claimed in the registry, on the event that owns it.
static func _pattern_claims(patterns: Dictionary) -> bool:
	var ok: bool = true
	ok = _check("the gyro pattern is claimed on the events that write the sensor shapes",
		int(patterns.get("gyro_controls", 0)) > 0, true) and ok
	ok = _check("the timed-input pattern is claimed on the function that opens the window",
		int(patterns.get("qte", 0)) > 0, true) and ok
	ok = _check("the swipe pattern is claimed on the function that reads the touch events",
		int(patterns.get("swipe", 0)), 1) and ok
	ok = _check("the shooter pattern is claimed on the function that switches weapons",
		int(patterns.get("hitscan", 0)), 1) and ok
	ok = _check("the secrets pattern is claimed on the function that counts one",
		int(patterns.get("secrets", 0)), 1) and ok
	ok = _check("the options pattern is claimed on the function that rewrites the Input Map",
		int(patterns.get("accessibility_options", 0)), 1) and ok
	return ok


## Writes the source, opens it as a sheet, walks every row and returns {readings, patterns} - the
## cell readings as "object ▸ text", and {pattern id: how many events claimed it}.
static func _open_and_read() -> Dictionary:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var readings: PackedStringArray = PackedStringArray()
	for row_data: EventRowData in _walk(viewport._root_rows, viewport):
		for span: SemanticSpan in row_data.spans:
			var object_label: String = str(span.metadata.get("object_label", ""))
			var text: String = span.text.strip_edges()
			readings.append("%s ▸ %s" % [object_label, text] if not object_label.is_empty() else text)
	var patterns: Dictionary = {}
	for claim: Variant in EventSheetPatternFacts.claims(sheet):
		var pattern: String = str((claim as Dictionary).get("pattern", ""))
		patterns[pattern] = int(patterns.get(pattern, 0)) + 1
	viewport.free()
	return {"readings": readings, "patterns": patterns}


## Every row in the tree, parents before children.
static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


## Gate four: every reading here is a lens over a value the row already holds, so opening the file
## and saving it untouched puts back every byte.
static func _round_trip() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] gesture_and_timed_input_reading_test: %s" % label)
		return true
	print("[FAIL] gesture_and_timed_input_reading_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
