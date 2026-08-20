@tool
class_name SpatialWordsReadingTest
extends RefCounted

# Pins the batch-thirteen 3D words - the four families a 3D project writes that read as arithmetic
# today, each of which the sheet already has one sentence for:
#
#   X1   moving and turning: one of six directions at a speed, the three turns in degrees a second,
#        turning toward a facing, the facing a direction makes, and Look At's up-vector fold
#   X3   facing: how far off facing something is, and which side of an object something is on
#   X5   placing: standing where another object stands, and tilting onto the ground's slope
#   X31  angle and distance: the point an angle and a distance name, one loop step's share of a full
#        turn, and the ring / spiral claim built out of the pair
#
# Five gates, in the order they matter:
#   1. the grammar's own values - one shape, one sentence, asserted literally;
#   2. the shapes that must NOT be claimed, because a reading that is almost right is worse than the
#      code it replaced;
#   3. the pattern the ring and the spiral claim, by the words the chip says;
#   4. the AUTHORING half: every row on the 3D page writes back exactly the spelling gate one reads;
#   5. the promise all of it rests on - the file still saves byte-identically, because every reading
#      here is a lens over a value the row already holds.
#
# The source lives here as a string rather than in tests/fixtures/ for the same reason its sibling
# reading tests' sources do: the lifter's byte gate compares against what the COMPILER would emit,
# and the compiler puts ONE blank line between functions, so a checked-in two-blank-line file could
# never lift and the fixture would silently test nothing.

const SOURCE_PATH := "user://eventforge_spatial_words_reading.gd"

const SOURCE: String = """extends CharacterBody3D

@export var speed: float = 6.0
@export var turn_rate: float = 90.0
@onready var target: Node3D = $"../Boss"
@onready var spawn: Marker3D = $SpawnPoint

func _physics_process(delta):
	global_position += -transform.basis.z * speed * delta
	global_position += transform.basis.x * 2.0 * delta
	rotate_y(deg_to_rad(turn_rate * delta))

func face_boss(delta):
	look_at(target.global_position)
	var to_target = (target.global_position - global_position).normalized()
	var desired = Basis.looking_at(to_target)
	basis = basis.slerp(desired, 5.0 * delta)

func drop() -> void:
	global_position = spawn.global_position
	basis = Basis(Quaternion(Vector3.UP, Vector3.UP)) * basis
"""

## The statements whose sentence this parcel settles, as "object ▸ sentence".
static var STATEMENT_READINGS: Dictionary = {
	# X1 - one of six directions, at a speed, per second
	"global_position += -transform.basis.z * speed * delta":
		"Player ▸ Move forward at speed per second",
	"global_position += transform.basis.x * 2.0 * delta": "Player ▸ Move right at 2 per second",
	"position += basis.y * lift * delta": "Player ▸ Move up at lift per second",
	"position += -basis.x * strafe * delta": "Player ▸ Move left at strafe per second",
	"global_position += wind * 3.0 * delta": "Player ▸ Move along wind at 3 per second",
	# X1 - the three turns, and the axis each one is about
	"rotate_y(deg_to_rad(turn_rate * delta))": "Player ▸ Rotate clockwise at turn_rate°/s · yaw",
	"rotate_y(deg_to_rad(-turn_rate * delta))":
		"Player ▸ Rotate counter-clockwise at turn_rate°/s · yaw",
	"rotate_x(deg_to_rad(pitch_rate * delta))": "Player ▸ Rotate up at pitch_rate°/s · pitch",
	"rotate_z(deg_to_rad(roll_rate * delta))": "Player ▸ Roll left at roll_rate°/s · roll",
	"rotate_object_local(Vector3.UP, deg_to_rad(turn_rate * delta))":
		"Player ▸ Rotate clockwise at turn_rate°/s · yaw (in its own space)",
	# X1 - turning toward a facing, and facing something with an up vector worth saying
	"basis = basis.slerp(desired, 5.0 * delta)": "Player ▸ Rotate toward desired at 5 per second",
	"look_at(target.global_position)": "Player ▸ Look at target",
	"look_at(target.global_position, Vector3.UP)": "Player ▸ Look at target",
	"look_at(target.global_position, wall_normal)": "Player ▸ Look at target (up is wall_normal)",
	# X5 - standing where another object stands, and tilting onto a slope
	"crate.global_position = spawn.global_position": "crate ▸ Set position to spawn spawn point",
	"crate.global_position = target.global_position": "crate ▸ Set position to target another object",
	"crate.basis = Basis(Quaternion(Vector3.UP, ground_normal)) * crate.basis":
		"crate ▸ Align to the ground's slope"
}

## The questions this parcel settles, as "object ▸ sentence". The first two are the same idiom said
## two ways - through the locals the file named, and spelled out in one breath.
static var CONDITION_READINGS: Dictionary = {
	"forward.dot(to_enemy) > cos(deg_to_rad(45.0))": "Guard ▸ Is within 45° of facing enemy",
	"forward.dot(to_enemy) < cos(deg_to_rad(45.0))": "Guard ▸ Is not within 45° of facing enemy",
	"(-global_transform.basis.z).dot((enemy.global_position - global_position).normalized()) > cos(deg_to_rad(30.0))":
		"Player ▸ Is within 30° of facing enemy",
	"to_local(enemy.global_position).z > 0.0": "enemy is behind Player",
	"to_local(enemy.global_position).z < 0.0": "enemy is in front of Player",
	"to_local(enemy.global_position).x > 0.0": "enemy is to the right of Player",
	"to_local(enemy.global_position).x < 0.0": "enemy is to the left of Player"
}

## The values this parcel names, and what the sheet calls them.
static var EXPRESSION_READINGS: Dictionary = {
	# X1 - the basis table, both halves of it
	"-global_transform.basis.z": "Player's forward",
	"global_transform.basis.z": "Player's backward",
	"transform.basis.x": "Player's right",
	"-transform.basis.x": "Player's left",
	"basis.y": "Player's up",
	"-basis.y": "Player's down",
	"Basis.looking_at(to_target)": "facing along to_target",
	# X31 - the point at an angle, in all three spellings, and one step's share of a turn
	"Vector2(cos(angle), sin(angle)) * radius": "the point at angle angle, distance radius",
	"Vector2.from_angle(angle) * radius": "the point at angle angle, distance radius",
	"Vector3(cos(angle), 0, sin(angle)) * radius": "the point at angle angle, distance radius",
	"TAU * float(i) / float(n)": "i's share of a full turn",
	"TAU * float(i) / float(8)": "i's share of a full turn",
	# X31 - a place ON a circle is the point added to a centre, which is how a ring and a spiral are
	# both actually written.
	"centre + Vector2.from_angle(deg_to_rad(orbit_angle)) * orbit_radius":
		"centre + the point at angle orbit_angle°, distance orbit_radius"
}

## Shapes that must NOT be claimed. A reading that is ALMOST right is worse than the code it read:
## a 2D object's own `look_at` is a different sentence the sheet already has, a place read off a
## table is not another object's place, a slerp at a frame-rate-dependent rate is arithmetic, and a
## circle whose cosine and sine are different angles is not a circle.
static var REFUSED: Dictionary = {
	"basis = basis.slerp(desired, 0.1)": "Player ▸ Set basis to basis.slerp(desired, 0.1)",
	"crate.global_position = ground.position": "crate ▸ Set global_position to ground.position",
	"Vector2(cos(a), sin(b)) * radius": "(cos(a), sin(b)) * radius"
}


static func run() -> bool:
	var ok: bool = true
	ok = _grammar_values() and ok
	ok = _refusals() and ok
	ok = _claims() and ok
	ok = _authoring() and ok
	ok = _round_trip() and ok
	return ok


## The sentence context an opened 3D script hands the grammar, including the two facts the reading
## rows gather once per rebuild: whose forward each local holds, and what each direction points at.
static func _context() -> Dictionary:
	return {
		"self_object": "Player",
		"script_object": "Player",
		"self_class": "CharacterBody3D",
		"engine_properties": {"position": true, "global_position": true, "basis": true},
		"object_classes": {
			"target": "Node3D", "crate": "Node3D", "spawn": "Marker3D", "enemy": "Node3D",
			"Guard": "CharacterBody3D"
		},
		"facing_locals": {"forward": "Guard"},
		"direction_locals": {"to_enemy": {"from": "Guard", "to": "enemy"}}
	}


## Gate one: the grammar answering on its own, value by value.
static func _grammar_values() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	for code: String in STATEMENT_READINGS:
		ok = _check("statement %s" % code,
			_joined_segments(EventSheetSentence.statement(code, context)),
			str(STATEMENT_READINGS[code])) and ok
	for expression: String in CONDITION_READINGS:
		ok = _check("condition %s" % expression,
			_joined_pieces(EventSheetSentence.condition_pieces(expression, context)),
			str(CONDITION_READINGS[expression])) and ok
	for value: String in EXPRESSION_READINGS:
		ok = _check("expression %s" % value,
			EventSheetSentence.expression_text(value, context),
			str(EXPRESSION_READINGS[value])) and ok
	# X1. A 2D object writes some of the same lines meaning something else, so the whole section is
	# gated on the class: its own one-argument `look_at` keeps the sentence the sheet already has.
	var flat: Dictionary = _context()
	flat["self_class"] = "Node2D"
	ok = _check("a 2D object's look_at keeps its own words",
		_joined_segments(EventSheetSentence.statement("look_at(target.global_position)", flat)),
		"Player ▸ Set angle toward target.global_position") and ok
	ok = _check("and a 2D object's move line stays the arithmetic it is",
		_joined_segments(EventSheetSentence.statement(
			"position += -transform.basis.z * speed * delta", flat)),
		"Player ▸ Add -transform.basis.z * speed * dt to position") and ok
	return ok


## Gate two: the shapes nothing may claim.
static func _refusals() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	for code: String in REFUSED:
		var statement: Dictionary = EventSheetSentence.statement(code, context)
		var reading: String = _joined_segments(statement) if not statement.is_empty() \
			else EventSheetSentence.expression_text(code, context)
		ok = _check("refused %s" % code, reading, str(REFUSED[code])) and ok
	# X3. A direction between two OTHER things is not this object's facing test, however it is spelled.
	ok = _check("a facing test about somebody else's direction says nothing",
		_joined_pieces(EventSheetSentence.condition_pieces(
			"forward.dot(to_ally) > cos(deg_to_rad(45.0))", context)),
		"how much forward points along to_ally (-1 to 1) > cos(45°)") and ok
	return ok


## Gate three: the ring and the spiral, claimed by the words their chip says. A lone conversion is an
## expression rather than a pattern, and claiming one would put a marker on a plain line.
static func _claims() -> bool:
	var ok: bool = true
	var ring: PackedStringArray = PackedStringArray([
		"for i in n:",
		"\tvar angle := TAU * float(i) / float(n)",
		"\tvar b = bullet_scene.instantiate()",
		"\tadd_child(b)",
		"\tb.position = position + Vector2(cos(angle), sin(angle)) * radius"
	])
	ok = _check("a ring loop claims the angle-and-distance pattern",
		_claim_words(ring, "polar"), "places things evenly around a circle") and ok
	var spiral: PackedStringArray = PackedStringArray([
		"orbit_angle += 90.0 * delta",
		"orbit_radius += 20.0 * delta",
		"position = centre + Vector2.from_angle(deg_to_rad(orbit_angle)) * orbit_radius"
	])
	ok = _check("a spiral claims it in its own words",
		_claim_words(spiral, "polar"), "works a place out as an angle and a distance") and ok
	var lone: PackedStringArray = PackedStringArray(["var step := TAU * float(i) / float(n)"])
	ok = _check("a share of a turn with nothing placed at it claims nothing",
		_claim_words(lone, "polar"), "") and ok
	# The two new pattern ids exist, and the words their chip says come from one table.
	ok = _check("the placement pattern is registered",
		EventSheetPatternFacts.PATTERN_IDS.has("placement"), true) and ok
	ok = _check("and the sheet has a word for it",
		EventSheetPatternVocabulary.words("placement"), "Placement") and ok
	ok = _check("the angle-and-distance pattern is registered",
		EventSheetPatternFacts.PATTERN_IDS.has("polar"), true) and ok
	ok = _check("and the sheet has a word for it",
		EventSheetPatternVocabulary.words("polar"), "Angle and distance") and ok
	return ok


## The words a body's claim of one pattern says, or "" when the body claims it at all.
static func _claim_words(body: PackedStringArray, pattern: String) -> String:
	for entry: Variant in EventSheetPatternReadings.claims_in(body, {}):
		if str((entry as Dictionary).get("pattern", "")) == pattern:
			return str((entry as Dictionary).get("words", ""))
	return ""


## Gate four: the authoring half. Every row on the 3D page writes EXACTLY the spelling gate one
## reads, which is the whole two-way promise - a line typed by hand and the same line dropped from
## the picker are one row and one file.
static func _authoring() -> bool:
	var ok: bool = true
	var templates: Dictionary = {
		"MoveInDirection3D": "{target.}global_position += {direction} * {speed} * {delta_t}",
		"RotateClockwise3D": "{target.}rotate_y(deg_to_rad({degrees_per_second} * {delta_t}))",
		"RotatePitch3D": "{target.}rotate_x(deg_to_rad({degrees_per_second} * {delta_t}))",
		"Roll3D": "{target.}rotate_z(deg_to_rad({degrees_per_second} * {delta_t}))",
		"RotateToward3DFacing": "basis = basis.slerp({facing}, {rate} * {delta_t})",
		"SetPositionToObject3D": "global_position = {other}.global_position",
		"AlignToGroundSlope3D": "basis = Basis(Quaternion(Vector3.UP, {normal})) * basis",
		"IsWithinAngleOfFacing3D": "{forward}.dot({direction}) > cos(deg_to_rad({angle}))",
		"IsBehindObject3D": "{target.}to_local({point}).z > 0.0",
		"IsInFrontOfObject3D": "{target.}to_local({point}).z < 0.0",
		"IsToTheRightOfObject3D": "{target.}to_local({point}).x > 0.0",
		"IsToTheLeftOfObject3D": "{target.}to_local({point}).x < 0.0",
		"PointAtAngle": "Vector2.from_angle(deg_to_rad({angle})) * {distance}",
		"FacingAlong3D": "Basis.looking_at({direction})"
	}
	var shipped: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		shipped[str(descriptor.ace_id)] = descriptor
	for ace_id: String in templates:
		var descriptor: Variant = shipped.get(ace_id, null)
		if descriptor == null:
			ok = _check("the 3D page ships %s" % ace_id, false, true)
			continue
		ok = _check("%s writes the spelling the reading knows" % ace_id,
			str((descriptor as ACEDescriptor).codegen_template), str(templates[ace_id])) and ok
	# X16. The direction parameter offers the six words and writes the basis expression, so a reader
	# picks "forward" and the file says `-basis.z`.
	var move: ACEDescriptor = shipped.get("MoveInDirection3D", null)
	var labels: PackedStringArray = PackedStringArray()
	var keys: PackedStringArray = PackedStringArray()
	if move != null:
		for parameter: ACEParam in move.params:
			if str(parameter.id) != "direction":
				continue
			for option: Variant in parameter.options:
				labels.append(str((option as Dictionary).get("label", "")))
				keys.append(str((option as Dictionary).get("key", "")))
	ok = _check("the direction dropdown offers the six words", ", ".join(labels),
		"forward, backward, right, left, up, down") and ok
	ok = _check("and writes the axis each one is", ", ".join(keys),
		"-basis.z, basis.z, basis.x, -basis.x, basis.y, -basis.y") and ok
	# X16. The 3D rows are filed on a PAGE with sections, the way the 2D ones are, rather than in one
	# flat list keyed on the node type they are scoped to.
	ok = _check("the move rows are filed on the 3D page",
		str((shipped.get("MoveInDirection3D", null) as ACEDescriptor).category),
		"3D: Move & Turn") and ok
	ok = _check("the placing rows too",
		str((shipped.get("SetPositionToObject3D", null) as ACEDescriptor).category),
		"3D: Place") and ok
	ok = _check("and the facing questions",
		str((shipped.get("IsWithinAngleOfFacing3D", null) as ACEDescriptor).category),
		"3D: See") and ok
	# The reading recognises exactly what the picker writes: the direction dropdown's own first
	# option, filled into the row's own template, reads as the row's own sentence.
	ok = _check("a Move In Direction row reads back as its own words",
		_joined_segments(EventSheetSentence.statement(
			"global_position += -basis.z * 6.0 * delta", _context())),
		"Player ▸ Move forward at 6 per second") and ok
	ok = _check("a Rotate Clockwise row reads back as its own words",
		_joined_segments(EventSheetSentence.statement(
			"rotate_y(deg_to_rad(90.0 * delta))", _context())),
		"Player ▸ Rotate clockwise at 90°/s · yaw") and ok
	ok = _check("an Is Within Angle Of Facing row reads back as its own question",
		_joined_pieces(EventSheetSentence.condition_pieces(
			"forward.dot(to_enemy) > cos(deg_to_rad(45.0))", _context())),
		"Guard ▸ Is within 45° of facing enemy") and ok
	ok = _check("and a Point At Angle row reads back as its own value",
		EventSheetSentence.expression_text(
			"Vector2.from_angle(deg_to_rad(30.0)) * 100.0", _context()),
		"the point at angle 30°, distance 100") and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] spatial_words_reading_test: %s" % label)
		return true
	print("[FAIL] spatial_words_reading_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


## One condition reading as "object ▸ sentence", or the bare sentence when no object is named.
static func _joined_pieces(reading: Dictionary) -> String:
	var text: String = ""
	for piece: Variant in (reading.get("pieces", []) as Array):
		text += str((piece as Array)[0])
	var object_label: String = str(reading.get("object", ""))
	return "%s ▸ %s" % [object_label, text.strip_edges()] if not object_label.is_empty() \
		else text.strip_edges()


## One statement reading as "object ▸ sentence".
static func _joined_segments(reading: Dictionary) -> String:
	if reading.is_empty():
		return ""
	var text: String = ""
	for segment: Variant in (reading.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	var object_label: String = str(reading.get("object", ""))
	return "%s ▸ %s" % [object_label, text.strip_edges()] if not object_label.is_empty() \
		else text.strip_edges()


## Gate five: every reading here is a lens over a value the row already holds, so opening the file
## and saving it untouched puts back every byte.
static func _round_trip() -> bool:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)
