# The math words, the space words, and the unit that rides the value.
#
# Three claims are held to account here.
#
# First, that each of the four value-shaping rows IS the call in its echo: the template and the line
# a person would have typed are the same string, which is what makes a hand-written `clampf` open as
# the Keep row and save back as its own bytes. The lift is proved on a real file that round-trips.
#
# Second, that an angle field never lies about its unit. A plain number is degrees and is written
# through `deg_to_rad`; a value written in radians stays in radians, emitted raw, with no conversion
# wrapped round somebody's PI; and the row says which it ended up meaning either way.
#
# Third, that the transform facts a scene can be asked about are said only when they bite, and say
# the reader's own arithmetic rather than a rule.
@tool
class_name MathAndSpaceWordsTest
extends RefCounted

const MATH := preload("res://addons/eventforge/registration/modules/math_words_aces.gd")
const SPACE := preload("res://addons/eventforge/registration/modules/space_words_aces.gd")
const LENS := preload("res://addons/eventforge/registration/value_lens.gd")
const ARENA_SCRIPT := "res://tests/fixtures/space_scene_arena.gd"

## A file written the way somebody would write it by hand, with one line per row this wave adds.
const HAND_WRITTEN := """extends Node2D

var value := 0.0
var max_hp := 100.0


func _process(delta: float) -> void:
	value = clampf(value, 0.0, max_hp)
	value = lerp(value, 1.5, 0.1)
	value = wrapf(value, 0.0, 360.0)
	value = remap(value, 0.0, max_hp, 0.0, 1.0)
	position += transform.x * 240.0 * delta
	global_position += Vector2.RIGHT * 20.0 * delta
	global_position = Vector2.ZERO + (global_position - Vector2.ZERO).rotated(deg_to_rad(30.0) * delta)
	rotation = rotate_toward(rotation, global_position.angle_to_point(Vector2.ZERO), deg_to_rad(180.0) * delta)
"""


static func run() -> bool:
	var ok: bool = true
	EventSheetSceneLightingFacts.clear_cache()
	ok = _test_the_templates_are_the_calls() and ok
	ok = _test_the_hand_written_file_opens_as_rows() and ok
	ok = _test_a_bare_number_is_degrees() and ok
	ok = _test_radians_are_kept_raw() and ok
	ok = _test_the_row_says_its_unit() and ok
	ok = _test_a_weight_reads_as_a_percentage() and ok
	ok = _test_the_transform_facts() and ok
	EventSheetSceneLightingFacts.clear_cache()
	return ok


## Every template of the wave, by value. A template is a compatibility promise the moment it ships,
## and these ones are also the claim that the row and the call are one thing.
static func _test_the_templates_are_the_calls() -> bool:
	var templates: Dictionary = {}
	for descriptor: ACEDescriptor in MATH.get_descriptors() + SPACE.get_descriptors():
		templates[descriptor.ace_id] = descriptor.codegen_template
	return _check("each row writes exactly the call its echo shows", templates, {
		"KeepBetween": "{var_name} = clampf({var_name}, {low}, {high})",
		"MoveTowardEachTick": "{var_name} = lerp({var_name}, {target}, {weight})",
		"RescaleInto": "{into} = remap({amount}, {in_low}, {in_high}, {out_low}, {out_high})",
		"WrapAround": "{var_name} = wrapf({var_name}, {low}, {high})",
		"MoveForwardOwnFacing": "position += transform.x * {speed} * {delta_t}",
		"MoveTheWorldsWay": "global_position += {direction} * {speed} * {delta_t}",
		"TurnAroundPoint": "global_position = {centre} + (global_position - {centre}).rotated(deg_to_rad({degrees_per_second}) * {delta_t})",
		"FaceTargetAtSpeed": "rotation = rotate_toward(rotation, global_position.angle_to_point({target}), deg_to_rad({degrees_per_second}) * {delta_t})",
		"SwingOnHinge": "create_tween().tween_property(self, \"rotation\", rotation + deg_to_rad({degrees}), {seconds})",
	})


## The other direction, on a whole file: somebody's own `_process` full of these lines opens as the
## rows they mean, and saving it untouched writes their file back byte for byte.
static func _test_the_hand_written_file_opens_as_rows() -> bool:
	var sheet: EventSheetResource = EventSheets.open_gd_as_sheet(HAND_WRITTEN)
	var opened: Array = []
	if sheet != null:
		for entry: Variant in sheet.events:
			var row: EventRow = entry as EventRow
			if row == null:
				continue
			for action: Variant in row.actions:
				opened.append(str((action as Resource).get("ace_id")))
	return _check("a file of hand-written maths and moves opens as rows, and saves itself back", {
		"rows": opened,
		"round trips": EventSheets.round_trips(HAND_WRITTEN),
	}, {
		"rows": ["KeepBetween", "MoveTowardEachTick", "WrapAround", "RescaleInto",
			"MoveForwardOwnFacing", "MoveTheWorldsWay", "TurnAroundPoint", "FaceTargetAtSpeed"],
		"round trips": true,
	})


## A plain number is degrees, and the field writes the conversion so the code says so out loud. The
## `deg` suffix is the same answer said deliberately.
static func _test_a_bare_number_is_degrees() -> bool:
	return _check("a bare number is degrees, converted where it is stored", {
		"45 where the slot wants radians": EventForgeAngleUnits.stored("45"),
		"45 deg where the slot wants radians": EventForgeAngleUnits.stored("45 deg"),
		"45 where the template converts": EventForgeAngleUnits.stored("45", EventForgeAngleUnits.DEGREES),
		"an expression": EventForgeAngleUnits.stored("aim_angle"),
		"nothing": EventForgeAngleUnits.stored(""),
		# A name that merely ENDS in those three letters said no unit, so it keeps every letter it
		# was typed with. Chopping the tail off would emit a variable the game does not have.
		"a name ending in deg": EventForgeAngleUnits.stored("angle_deg"),
		"a name ending in rad": EventForgeAngleUnits.stored("aim_rad"),
		"a name ending in grad": EventForgeAngleUnits.stored("turn_grad"),
		"a unit said straight after the number": EventForgeAngleUnits.stored("1.2rad"),
	}, {
		"45 where the slot wants radians": "deg_to_rad(45)",
		"45 deg where the slot wants radians": "deg_to_rad(45)",
		"45 where the template converts": "45",
		"an expression": "deg_to_rad(aim_angle)",
		"nothing": "",
		"a name ending in deg": "deg_to_rad(angle_deg)",
		"a name ending in rad": "deg_to_rad(aim_rad)",
		"a name ending in grad": "deg_to_rad(turn_grad)",
		"a unit said straight after the number": "1.2",
	})


## THE UNIT RIDES THE VALUE: somebody who wrote PI meant PI, and nothing is wrapped round it. A
## project that thinks in radians flips what a bare number means, and only what is WRITTEN after
## that - a value already stored is read by what it says, never by the setting.
static func _test_radians_are_kept_raw() -> bool:
	var settings_before: Variant = ProjectSettings.get_setting(EventForgeAngleUnits.SETTING, null)
	ProjectSettings.set_setting(EventForgeAngleUnits.SETTING, EventForgeAngleUnits.RADIANS)
	var in_a_radian_project: String = EventForgeAngleUnits.stored("45")
	var typed_into_a_field: String = EventForgeAngleUnits.stored("45", EventForgeAngleUnits.DEGREES)
	var read_back_there: String = LENS.read(LENS.LENS_ANGLE, "30")
	ProjectSettings.set_setting(EventForgeAngleUnits.SETTING, settings_before)
	return _check("a radian spelling is kept exactly as it was written", {
		"PI/4 where the slot wants radians": EventForgeAngleUnits.stored("PI/4"),
		"TAU * 0.125 where the slot wants radians": EventForgeAngleUnits.stored("TAU * 0.125"),
		"1.2 rad where the slot wants radians": EventForgeAngleUnits.stored("1.2 rad"),
		"PI/4 where the template converts": EventForgeAngleUnits.stored("PI/4", EventForgeAngleUnits.DEGREES),
		"an expression ending in PI": EventForgeAngleUnits.stored("spin_speed * PI"),
		"an expression ending in TAU": EventForgeAngleUnits.stored("x * TAU"),
		"a name that merely contains those letters": EventForgeAngleUnits.stored("SPIN * TAUNT"),
		"45 in a radian project": in_a_radian_project,
		"45 typed into a field in a radian project": typed_into_a_field,
		"a bare 30 read back in a radian project": read_back_there,
	}, {
		"PI/4 where the slot wants radians": "PI/4",
		"TAU * 0.125 where the slot wants radians": "TAU * 0.125",
		"1.2 rad where the slot wants radians": "1.2",
		"PI/4 where the template converts": "rad_to_deg(PI/4)",
		"an expression ending in PI": "spin_speed * PI",
		"an expression ending in TAU": "x * TAU",
		"a name that merely contains those letters": "deg_to_rad(SPIN * TAUNT)",
		"45 in a radian project": "45",
		"45 typed into a field in a radian project": "rad_to_deg(45)",
		"a bare 30 read back in a radian project": "30°",
	})


## Whichever way it was written, the ROW says which unit it means - and a value nothing can be said
## about reads as itself rather than claiming a unit it cannot know.
static func _test_the_row_says_its_unit() -> bool:
	return _check("the row always shows the unit it means", {
		"deg_to_rad(45.0)": LENS.read(LENS.LENS_ANGLE, "deg_to_rad(45.0)"),
		"rad_to_deg(PI/4)": LENS.read(LENS.LENS_ANGLE, "rad_to_deg(PI/4)"),
		"PI/4": LENS.read(LENS.LENS_ANGLE, "PI/4"),
		"180.0": LENS.read(LENS.LENS_ANGLE, "180.0"),
		"aim_angle": LENS.read(LENS.LENS_ANGLE, "aim_angle"),
		"an angle field opts in by its hint": LENS.lens_of({"hint": "angle"}),
	}, {
		"deg_to_rad(45.0)": "45.0°",
		"rad_to_deg(PI/4)": "PI/4 rad",
		"PI/4": "PI/4 rad",
		"180.0": "180.0°",
		"aim_angle": "aim_angle",
		"an angle field opts in by its hint": "angle",
	})


## `lerp` takes the fraction, so the row emits the fraction - and says it as the percentage a reader
## thinks in. The value never changes, which is what keeps the code the author's own.
static func _test_a_weight_reads_as_a_percentage() -> bool:
	return _check("a weight reads as the percentage it is", {
		"0.1": LENS.read(LENS.LENS_FRACTION, "0.1"),
		"0.25": LENS.read(LENS.LENS_FRACTION, "0.25"),
		"an expression": LENS.read(LENS.LENS_FRACTION, "rate * 2"),
	}, {
		"0.1": "10%",
		"0.25": "25%",
		"an expression": "rate * 2",
	})


## The three inherited facts, off a real scene: an arm inside a body scaled twice, an enemy mirrored
## by a negative scale, and a hitbox scaled unevenly that turns. Each says the reader's own
## arithmetic rather than a rule.
static func _test_the_transform_facts() -> bool:
	var read: Array = []
	for band: Dictionary in EventSheetSceneTransformFacts.bands(ARENA_SCRIPT):
		read.append("%s%s" % ["! " if bool(band["warning"]) else "", str(band["value"])])
	return _check("the scene's transform facts are said only where they bite", read, [
		"Arm is inside Body (scaled 2) - its own 10 is the world's 20",
		"! Enemy is mirrored by a negative scale - its shapes and raycasts flip with the art; flip the sprite instead",
		"! HitBox is scaled (2, 1) and turned - it will shear; scale the art, not the collider",
	])


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] math_and_space_words_test: %s" % label)
		return true
	print("[FAIL] math_and_space_words_test: %s" % label)
	print("  expected: %s" % expected)
	print("  actual:   %s" % actual)
	return false
