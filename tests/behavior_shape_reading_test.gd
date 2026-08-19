@tool
class_name BehaviorShapeReadingTest
extends RefCounted

# Pins the hand-rolled BEHAVIOR shapes - the arithmetic a script writes where a shipped behavior has
# words:
#
#   T1  Bullet    the angle of motion, the acceleration, the gravity, the step, the bounce, and how
#                 far the projectile has flown
#   T2  Turret    the nearest-in-family loop, holding a target, and turning toward it
#   T3  Move To   gliding to a point, being under way, arriving, stopping
#   T4  the five one-liners: Rotate, Wrap around layout, Bound to layout, Pin to, Fade out
#
# Four gates, in the order they matter:
#   1. the recognisers' own values - one shape, one sentence, asserted literally;
#   2. the whole path - a hand-written file opened as a sheet, walked row by row;
#   3. the claims - every shape is registered on the event that owns it, with the source lines as
#      evidence and the pack that could replace it;
#   4. the promise all of them rest on - the file still saves byte-identically, because every one is
#      a lens over values the row already holds.
#
# The source lives here as a string rather than in tests/fixtures/ for the same reason its sibling
# reading tests' sources do: the lifter's byte gate compares against what the COMPILER would emit,
# and the compiler puts ONE blank line between functions, so a checked-in two-blank-line file could
# never lift and the fixture would silently test nothing.

const SOURCE_PATH := "user://eventforge_behavior_shape_reading.gd"

const SOURCE: String = """extends Node2D

signal arrived

@export var speed: float = 600.0
@export var accel: float = 0.0
@export var gravity: float = 0.0
@export var range_px: float = 800.0
@export var rotate_speed: float = 90.0
@export var fire_rate: float = 0.5
@export var turn_rate: float = 4.0
var velocity: Vector2 = Vector2.ZERO
var start: Vector2 = Vector2.ZERO
var destination: Vector2 = Vector2.ZERO
var moving: bool = false
var target: Node2D
var since_shot: float = 0.0
var screen: Vector2 = Vector2(1152, 648)
var anchor: Node2D
var pin_offset: Vector2 = Vector2(0, -20)

func _physics_process(delta: float) -> void:
	speed += accel * delta
	velocity = Vector2.RIGHT.rotated(rotation) * speed
	velocity.y += gravity * delta
	position += velocity * delta
	if position.distance_to(start) > range_px:
		queue_free()

func aim(delta: float) -> void:
	var nearest = null
	var best = range_px
	for e in get_tree().get_nodes_in_group("enemy"):
		var d = global_position.distance_to(e.global_position)
		if d < best:
			best = d
			nearest = e
	target = nearest
	if target:
		rotation = lerp_angle(rotation, global_position.angle_to_point(target.global_position), turn_rate * delta)

func go_to(p: Vector2) -> void:
	destination = p
	moving = true

func glide(delta: float) -> void:
	position = position.move_toward(destination, speed * delta)
	if position.distance_to(destination) < 1.0:
		moving = false
		arrived.emit()

func decorate(delta: float) -> void:
	rotation_degrees += rotate_speed * delta
	position.x = wrapf(position.x, 0.0, screen.x)
	position = position.clamp(Vector2.ZERO, screen)
	global_position = anchor.global_position + pin_offset
	rotation = anchor.rotation

func collect() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 1.0)
	tw.tween_callback(queue_free)
"""

## The statements whose sentence this parcel settles, as "object ▸ sentence".
static var STATEMENT_READINGS: Dictionary = {
	# T1 - the Bullet behavior's four steps and its bounce
	"speed += accel * delta": "Coin ▸ Bullet  Set speed to speed accelerating by accel",
	"velocity = Vector2.RIGHT.rotated(rotation) * speed":
		"Coin ▸ Bullet  Set angle of motion to angle",
	"velocity = Vector2.from_angle(rotation) * speed":
		"Coin ▸ Bullet  Set angle of motion to angle",
	"velocity = transform.x * speed": "Coin ▸ Bullet  Set angle of motion to angle",
	"velocity.y += gravity * delta": "Coin ▸ Bullet  Set gravity to gravity",
	"position += velocity * delta": "Coin ▸ Bullet  Move",
	"move_and_collide(velocity * delta)": "Coin ▸ Bullet  Move",
	"velocity = velocity.bounce(normal)": "Coin ▸ Bullet  Bounce off solids",
	# T2 - the turn toward the target the loop filled
	"rotation = lerp_angle(rotation, global_position.angle_to_point(target.global_position), turn_rate * delta)":
		"Coin ▸ Turret  Rotate toward target at turn_rate",
	# T3 - the glide, its start and its stop
	"position = position.move_toward(destination, speed * delta)":
		"Coin ▸ Move To  Move toward destination at speed",
	"destination = p": "Coin ▸ Move To  Move to position p at speed",
	"moving = true": "Coin ▸ Move To  Start moving",
	"moving = false": "Coin ▸ Move To  Stop",
	# T4 - the five one-liners
	"rotation_degrees += rotate_speed * delta":
		"Coin ▸ Rotate  Rotate clockwise at rotate_speed (degrees per second)",
	"position.x = wrapf(position.x, 0.0, screen.x)": "Coin ▸ Wrap  Wrap around layout horizontally",
	"position.y = wrapf(position.y, 0.0, screen.y)": "Coin ▸ Wrap  Wrap around layout vertically",
	"position = position.clamp(Vector2.ZERO, screen)":
		"Coin ▸ Bound To  Bound to layout (inside (0, 0) - screen)",
	"global_position = anchor.global_position + pin_offset":
		"Coin ▸ Pin  Pin to anchor (position · offset pin_offset)",
	"rotation = anchor.rotation": "Coin ▸ Pin  Pin to anchor (angle)",
	"tw.tween_property(self, \"modulate:a\", 0.0, 1.0)":
		"Coin ▸ Fade  Fade out over 1 seconds (then destroy)"
}

## The condition readings the recognisers must answer on their own, as "object ▸ sentence".
static var CONDITION_READINGS: Dictionary = {
	"position.distance_to(start) > range_px": "Coin ▸ Bullet  Distance travelled > range_px",
	"position.distance_to(destination) < 1.0": "Coin ▸ Move To  Has arrived",
	"target": "Coin ▸ Turret  Has target",
	"moving": "Coin ▸ Move To  Is moving"
}


## Every reading the OPENED file must contain, one per shape that survives the importer's lift. A
## line the importer claimed for a shipped row reads through that row's own words instead, which is
## why the turn toward the target is absent here and pinned in the recogniser gate above.
static var EXPECTED_ROW_READINGS: PackedStringArray = PackedStringArray([
	"Node2D ▸ Bullet  Set Speed to Speed accelerating by Accel",
	"Node2D ▸ Bullet  Set angle of motion to angle",
	"Node2D ▸ Bullet  Set Gravity to Gravity",
	"Node2D ▸ Bullet  Move",
	"Node2D ▸ Bullet  Distance travelled > Range Px",
	"Node2D ▸ Turret  Has target",
	"Node2D ▸ Move To  Move to position p at Speed",
	"Node2D ▸ Move To  Start moving",
	"Node2D ▸ Move To  Move toward destination at Speed",
	"Node2D ▸ Move To  Has arrived",
	"Node2D ▸ Move To  Stop",
	"Node2D ▸ Rotate  Rotate clockwise at Rotate Speed (degrees per second)",
	"Node2D ▸ Wrap  Wrap around layout horizontally",
	"Node2D ▸ Bound To  Bound to layout (inside (0, 0) - screen)",
	"Node2D ▸ Pin  Pin to anchor (position · offset pin offset)",
	"Node2D ▸ Pin  Pin to anchor (angle)",
	"Node2D ▸ Fade  Fade out over 1 seconds (then destroy)"
])


## T27. The authoring half: {ace_id: [the params it is dropped with, the sentence the line it writes
## must read as]}. The gate below fills each descriptor's own TEMPLATE with those params and reads
## the result, so a template that drifts away from the shape stops being recognised and fails here
## rather than silently authoring a row that reads as arithmetic.
static var AUTHORING_PARITY: Dictionary = {
	"SetAngleOfMotion": [{"angle": "rotation", "speed": "speed"},
		"Coin ▸ Bullet  Set angle of motion to angle"],
	"StepAlongVelocity": [{"delta_t": "delta"}, "Coin ▸ Bullet  Move"],
	"BounceOffSolid": [{"normal": "normal"}, "Coin ▸ Bullet  Bounce off solids"],
	"GlideToward": [{"destination": "destination", "speed": "speed", "delta_t": "delta"},
		"Coin ▸ Move To  Move toward destination at speed"],
	"RotateClockwise": [{"degrees_per_second": "rotate_speed", "delta_t": "delta"},
		"Coin ▸ Rotate  Rotate clockwise at rotate_speed (degrees per second)"],
	"WrapAroundLayoutX": [{"low": "0.0", "high": "screen.x"},
		"Coin ▸ Wrap  Wrap around layout horizontally"],
	"WrapAroundLayoutY": [{"low": "0.0", "high": "screen.y"},
		"Coin ▸ Wrap  Wrap around layout vertically"],
	"BoundToLayout": [{"low": "Vector2.ZERO", "high": "screen"},
		"Coin ▸ Bound To  Bound to layout (inside (0, 0) - screen)"],
	"PinToObject": [{"anchor": "anchor", "offset": "pin_offset"},
		"Coin ▸ Pin  Pin to anchor (position · offset pin_offset)"],
	"PinAngleToObject": [{"anchor": "anchor"}, "Coin ▸ Pin  Pin to anchor (angle)"]
}

## T27. The shapes whose AUTHORING is a row that already shipped, so adding a second entry with the
## same template would put two rows with one meaning in the picker and let the more specific one
## quietly claim every line the general one was written for. The line each of those rows writes is
## pinned here all the same, because the reading has to keep recognising it.
static var SHIPPED_ROW_PARITY: Dictionary = {
	# Add To Variable writes exactly this.
	"speed += accel * delta": "Coin ▸ Bullet  Set speed to speed accelerating by accel",
	# Apply Gravity writes exactly this.
	"velocity.y += gravity * delta": "Coin ▸ Bullet  Set gravity to gravity"
}


static func run() -> bool:
	var ok: bool = true
	ok = _recogniser_values() and ok
	ok = _refusals() and ok
	ok = _authoring_parity() and ok
	ok = _opened_rows() and ok
	ok = _claims() and ok
	ok = _round_trip() and ok
	return ok


## Gate one and a half: every picker entry writes EXACTLY the arithmetic the reading recognises, so
## a row dropped from the picker and a line typed by hand are the same bytes and the same sentence.
static func _authoring_parity() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	for ace_id: String in AUTHORING_PARITY:
		var pair: Array = AUTHORING_PARITY[ace_id]
		var code: String = _filled_template(ace_id, pair[0])
		ok = _check("%s writes a line the reading knows" % ace_id, code.is_empty(), false) and ok
		ok = _check("%s writes \"%s\"" % [ace_id, code],
			_joined_segments(EventSheetSentence.statement(code, context)), str(pair[1])) and ok
	for code: String in SHIPPED_ROW_PARITY:
		ok = _check("a shipped row writes \"%s\"" % code,
			_joined_segments(EventSheetSentence.statement(code, context)),
			str(SHIPPED_ROW_PARITY[code])) and ok
	# Is Within Distance writes the arrival question, and Distance To is the launch-point expression a
	# range limit is compared against.
	ok = _check("Is Within Distance writes the arrival question",
		_joined_segments(EventSheetSentence.condition(
			"position.distance_to(destination) <= 1.0", context)), "Coin ▸ Move To  Has arrived") and ok
	ok = _check("Distance To writes the range question",
		_joined_segments(EventSheetSentence.condition(
			"position.distance_to(start) > range_px", context)),
		"Coin ▸ Bullet  Distance travelled > range_px") and ok
	return ok


## One shipped descriptor's own codegen template with its slots filled, as a plain sheet emits it -
## `{host.}` is empty outside a behavior, which is the spelling a hand-written file has.
static func _filled_template(ace_id: String, params: Dictionary) -> String:
	for descriptor: ACEDescriptor in EventForgeBehaviorShapeACEs.get_descriptors():
		if descriptor.ace_id != ace_id:
			continue
		var code: String = descriptor.codegen_template.replace("{host.}", "")
		for key: Variant in params:
			code = code.replace("{%s}" % str(key), str(params[key]))
		return "" if code.contains("{") else code
	return ""


## Gate two: the whole path. A hand-written file opened as a sheet, walked row by row, so a reading
## that answers on its own but stops reaching the canvas is caught.
static func _opened_rows() -> bool:
	var ok: bool = true
	var readings: PackedStringArray = _open_and_read()
	for expected: String in EXPECTED_ROW_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	return ok


## Writes the source, opens it as a sheet, and returns every cell reading as "object ▸ text".
static func _open_and_read() -> PackedStringArray:
	_write_source()
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
	viewport.free()
	return readings


## Every row in the tree, parents before children.
static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


## The context an opened script of these shapes hands the grammar - the file facts the reading rows
## gather once per rebuild, worked out from the file itself so the test and the editor agree.
static func _context() -> Dictionary:
	var facts: Dictionary = EventSheetBehaviorShapes.facts(SOURCE.split("\n"))
	var context: Dictionary = {
		"self_object": "Coin",
		"script_object": "Coin",
		"self_class": "Node2D",
		"engine_properties": {"position": true, "global_position": true, "rotation": true,
			"rotation_degrees": true},
		"variable_types": {"start": "Vector2", "destination": "Vector2", "screen": "Vector2",
			"speed": "float", "range_px": "float"}
	}
	context.merge(facts, true)
	return context


## Gate one: the recognisers answering on their own, value by value.
static func _recogniser_values() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	ok = _check("the file reads as a projectile", bool(context.get("bullet_motion", false)), true) and ok
	ok = _check("the loop's winner is the turret's target",
		(context.get("turret_targets", {}) as Dictionary).has("target"), true) and ok
	ok = _check("the glide's point is the move-to destination",
		(context.get("move_to_destinations", {}) as Dictionary).has("destination"), true) and ok
	ok = _check("the flag beside it says a glide is running",
		(context.get("move_to_flags", {}) as Dictionary).has("moving"), true) and ok
	for code: String in STATEMENT_READINGS:
		ok = _check("statement %s" % code, _joined_segments(EventSheetSentence.statement(code, context)),
			str(STATEMENT_READINGS[code])) and ok
	for expression: String in CONDITION_READINGS:
		ok = _check("condition %s" % expression,
			_joined_segments(EventSheetSentence.condition(expression, context)),
			str(CONDITION_READINGS[expression])) and ok
	var runs: Array = EventSheetBehaviorShapes.nearest_in_family_runs(SOURCE.split("\n"))
	ok = _check("the file holds one nearest-in-family loop", runs.size(), 1) and ok
	if runs.size() == 1:
		var run: Dictionary = runs[0]
		ok = _check("the loop names the family it searched", str(run.get("family", "")), "enemy") and ok
		ok = _check("the loop's range is what the search started from", str(run.get("range", "")),
			"range_px") and ok
		ok = _check("the loop hands its winner to the target", str(run.get("target", "")), "target") and ok
	return ok


## Gate one, the other half: a shape that is ALMOST one of these keeps the code it is. Every reading
## above is gated on something only a real instance of the shape can say, and this is what pins that.
static func _refusals() -> bool:
	var ok: bool = true
	var bare: Dictionary = {
		"self_object": "Coin", "script_object": "Coin", "self_class": "Node2D",
		"engine_properties": {"position": true, "rotation": true},
		"variable_types": {"start": "Vector2"}
	}
	ok = _check("a file that never steps is not a projectile",
		_joined_segments(EventSheetSentence.statement("speed += accel * delta", bare)),
		"Coin ▸ Add accel * dt to speed") and ok
	ok = _check("a distance measured in a file that is not a projectile stays a distance",
		_joined_segments(EventSheetSentence.condition("position.distance_to(start) > range_px", bare)),
		"distance to start > range_px") and ok
	ok = _check("a bare flag nothing declared a glide for stays a flag",
		_joined_segments(EventSheetSentence.condition("moving", bare)), "Coin ▸ moving is true") and ok
	var context: Dictionary = _context()
	ok = _check("a spin that is not scaled by the frame time is not a Rotate",
		_joined_segments(EventSheetSentence.statement("rotation_degrees += 90", context)),
		"Coin ▸ Add 90 to angle") and ok
	ok = _check("a tween to half opacity is not a fade out",
		_joined_segments(EventSheetSentence.statement(
			"tw.tween_property(self, \"modulate:a\", 0.5, 1.0)", context)).contains("Fade"),
		false) and ok
	return ok


## Gate three: every shape is claimed on the event that owns it, with the pack that could replace it.
static func _claims() -> bool:
	var ok: bool = true
	_write_source()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	EventSheetPatternFacts.clear(sheet)
	EventSheetViewportReadingRows.claim_behavior_shape_patterns(sheet)
	var claims: Array = EventSheetPatternFacts.claims(sheet)
	var turret: Dictionary = {}
	for entry: Variant in claims:
		if str((entry as Dictionary).get("pattern", "")) == "turret":
			turret = entry
	ok = _check("the nearest-in-family loop claims the turret pattern", turret.is_empty(), false) and ok
	if not turret.is_empty():
		ok = _check("the turret claim offers the pack that could replace it",
			str(turret.get("adoptable", "")), "weapon_kit") and ok
		ok = _check("the turret claim says what it acquired", str(turret.get("words", "")),
			"Acquire nearest enemy within range px") and ok
		ok = _check("the turret claim keeps the loop's own lines as evidence",
			"\n".join(turret.get("evidence", PackedStringArray())).contains(
				"for e in get_tree().get_nodes_in_group(\"enemy\"):"), true) and ok
	EventSheetPatternFacts.clear(sheet)
	return ok


## Gate four: the promise every reading here rests on - each one is a lens over a value the row
## already holds, so opening the file and saving it untouched puts back every byte.
static func _round_trip() -> bool:
	_write_source()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)


static func _write_source() -> void:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()


## One reading as "object ▸ sentence", with the chip, if any, in front of the words.
static func _joined_segments(reading: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (reading.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	for piece: Variant in (reading.get("pieces", []) as Array):
		text += str((piece as Array)[0])
	var object_label: String = str(reading.get("object", ""))
	if object_label.is_empty():
		return text.strip_edges()
	return "%s ▸ %s" % [object_label, text.strip_edges()]


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] behavior_shape_reading_test: %s" % label)
		return true
	print("[FAIL] behavior_shape_reading_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
