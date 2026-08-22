@tool
class_name PinModesTest
extends RefCounted

# Y4 / Y5 / Y6. The Pin behavior in every mode, and the two ways the pin words and the child words
# get crossed.
#
#   Y4  rope and bar     the two DISTANCE modes - a rope hangs slack and pulls only when taut, a bar
#                        holds its length every tick
#   Y5  soft, axis,      the follow that lags, one axis at a time, the anchor's scale, a named point
#       size, point,     on another object (a marker, a bone, a hand), and a point travelling a path
#       path
#   Y6  pin or child     the head bar's "pinned to X (rope)" fact, and the Doctor's two notes -
#                        following the same object twice, and pinning to one that gets destroyed
#
# Six gates:
#   1. the recognisers' own values - one shape, one sentence, asserted literally;
#   2. the REFUSALS, which are the point of the whole file: `scale = x.scale` and
#      `position.x = x.position.x` are two of the most general spellings in the language, and a
#      reading that claimed every one of them would put a Pin chip on half the lines in half the
#      projects in the world. They read as pins only in a file that has already pinned that anchor;
#   3. the AUTHORING half - every new picker row writes exactly the line the reading recognises;
#   4. the head bar fact, off a file opened as a sheet;
#   5. the Doctor's two notes and the fixes they offer;
#   6. the promise all of it rests on - the file still saves byte for byte, because every reading
#      here is a lens over values the row already holds.

const SOURCE_PATH := "user://eventforge_pin_modes_reading.gd"

const SOURCE: String = """extends Node2D

@onready var hand: Marker2D = $Player/Hand
@onready var rail: PathFollow2D = $Track/Runner
@export var rope_length: float = 80.0
@export var bar_length: float = 64.0
@export var follow_speed: float = 10.0
var anchor: Node2D
var hitch: Node2D
var lead: Node2D
var ground: Node2D
var pin_offset: Vector2 = Vector2(0, -20)

func _physics_process(delta: float) -> void:
	global_position = anchor.global_position + (global_position - anchor.global_position).limit_length(rope_length)
	global_position = hitch.global_position + (global_position - hitch.global_position).normalized() * bar_length
	global_position = global_position.lerp(lead.global_position, follow_speed * delta)
	rotation = lead.rotation
	global_position = hand.global_position + pin_offset
	global_position = rail.global_position
	global_position.x = ground.global_position.x
	global_position.y = ground.global_position.y
	scale = anchor.scale
"""

## A rope and nothing else - the head bar's own sentence, with one mode in it.
const ROPE_ONLY: String = """extends Node2D

var anchor: Node2D
var rope_length: float = 80.0

func _physics_process(_delta: float) -> void:
	global_position = anchor.global_position + (global_position - anchor.global_position).limit_length(rope_length)
"""

## Y6. A child of the thing it is pinned to - the classic "it drifts twice as fast" bug. Being a
## child already carries the object, and the pin writes its place a second time from the same source.
const DOUBLE_FOLLOW: String = """extends Node2D

@onready var rig: Node2D = get_parent()
var pin_offset: Vector2 = Vector2(0, -20)

func _physics_process(_delta: float) -> void:
	global_position = rig.global_position + pin_offset
"""

## Y6. A pin to an object this file destroys, with no Unpin and no validity question.
const FREED_ANCHOR: String = """extends Node2D

var anchor: Node2D
var pin_offset: Vector2 = Vector2(0, -20)

func _physics_process(_delta: float) -> void:
	global_position = anchor.global_position + pin_offset

func finish() -> void:
	anchor.queue_free()
"""

## Y6. The same file with the accepted fix written in, which is what must NOT be flagged.
const FREED_ANCHOR_GUARDED: String = """extends Node2D

var anchor: Node2D
var pin_offset: Vector2 = Vector2(0, -20)

func _physics_process(_delta: float) -> void:
	if is_instance_valid(anchor):
		global_position = anchor.global_position + pin_offset

func finish() -> void:
	anchor.queue_free()
"""

## Gate one: the statement readings, as "object ▸ sentence".
static var STATEMENT_READINGS: Dictionary = {
	"global_position = anchor.global_position + (global_position - anchor.global_position).limit_length(rope_length)":
		"Lantern ▸ Pin  Pin to anchor (rope, max length rope_length)",
	"global_position = hitch.global_position + (global_position - hitch.global_position).normalized() * bar_length":
		"Lantern ▸ Pin  Pin to hitch (bar, length bar_length)",
	"global_position = global_position.lerp(lead.global_position, follow_speed * delta)":
		"Lantern ▸ Pin  Pin to lead softly (speed follow_speed)",
	"rotation = lead.rotation": "Lantern ▸ Pin  Pin to lead (angle)",
	"global_position = hand.global_position + pin_offset":
		"Lantern ▸ Pin  Pin to Player's hand (offset pin_offset)",
	"global_position = rail.global_position": "Lantern ▸ Pin  Pin to Track's path position",
	"global_position.x = ground.global_position.x": "Lantern ▸ Pin  Pin X position to ground",
	"global_position.y = ground.global_position.y": "Lantern ▸ Pin  Pin Y position to ground",
	"scale = anchor.scale": "Lantern ▸ Pin  Pin size to anchor"
}

## Gate two: the shadow trap. Each of these is a line the reading MUST leave alone, because the
## spelling belongs to everybody. The words on the right are the plain readings they keep.
static var REFUSALS: Dictionary = {
	"scale = stray.scale": "Lantern ▸ Set scale to stray.scale",
	"global_position.x = stray.global_position.x": "Lantern ▸ Set X to stray.global_position.x",
	"global_position.y = stray.global_position.y": "Lantern ▸ Set Y to stray.global_position.y",
	# A lerp with a FIXED weight is a fixed-fraction lerp, not a follow with a speed.
	"global_position = global_position.lerp(stray.global_position, 0.5)":
		"Lantern ▸ Set global_position to global_position.lerp(stray.global_position, 0.5)",
	# THE one that cost a shipped reading: a camera closing on a target is written with exactly the
	# soft pin's bytes, and the sheet has had words for that for longer. A per-second lerp toward
	# another object only reads as a pin in a file that pins that anchor somewhere else too.
	"global_position = global_position.lerp(stray.global_position, 5 * delta)":
		"Lantern ▸ Set global_position to global_position.lerp(stray.global_position, 5 * dt)"
}

## Gate three: {ace_id: [params, the sentence the line it writes must read as]}. The picker row and
## the hand-written line are the same bytes, so they are the same sentence.
##
## Only the two DISTANCE modes are here, and the reason is the whole lesson of this file. A picker
## row's template is not just what the row writes - it is what the IMPORTER matches, so a template
## for `global_position.x = a.global_position.x`, `scale = a.scale` or `p = p.lerp(a.p, k * delta)`
## would re-file every such line in every project as a pin no matter what the READING's gates say.
## The last of those three is byte for byte how a camera scrolls toward a target, and shipping it
## took the camera's own row away from it. Those four modes are authored on the pack instead.
static var AUTHORING_PARITY: Dictionary = {
	"PinToObjectRope": [{"anchor": "anchor", "length": "rope_length"},
		"Lantern ▸ Pin  Pin to anchor (rope, max length rope_length)"],
	"PinToObjectBar": [{"anchor": "hitch", "length": "bar_length"},
		"Lantern ▸ Pin  Pin to hitch (bar, length bar_length)"]
}

## Y4/Y5. The pin spellings that must NOT have a picker row, because their template would be handed
## to the importer. Pinned by NAME so a later parcel cannot quietly add one back.
static var UNAUTHORED_SHAPES: PackedStringArray = PackedStringArray([
	"PinToObjectSoftly", "PinXPositionToObject", "PinYPositionToObject", "PinSizeToObject"
])

## Y5. The verbs the two packs publish for the modes above. Named, not counted: a count says nothing
## about which row went missing.
static var PIN_2D_VERBS: PackedStringArray = PackedStringArray([
	"Pin To", "Pin To At Offset", "Set Pin Offset", "Pin To Rope", "Pin To Bar", "Pin To Softly",
	"Pin To With Spring", "Pin X Position To", "Pin Y Position To", "Pin Size To", "Pin To Point",
	"Pin To Path", "Set Path Progress", "Unpin", "Is Pinned", "Is Taut", "Set Pin Mode",
	"Set Pin Axes", "PinOffsetX", "PinOffsetY", "PinDistance", "PinPathProgress"
])

static var PIN_3D_VERBS: PackedStringArray = PackedStringArray([
	"Pin To", "Pin To At Offset", "Set Pin Offset", "Pin To Rope", "Pin To Bar", "Pin To Softly",
	"Pin To With Spring", "Pin X Position To", "Pin Y Position To", "Pin Z Position To",
	"Pin Size To", "Pin To Point", "Pin To Path", "Set Path Progress", "Unpin", "Is Pinned",
	"Is Taut", "Set Pin Mode", "Set Pin Axes", "PinOffsetX", "PinOffsetY", "PinOffsetZ",
	"PinDistance", "PinPathProgress"
])


static func run() -> bool:
	var ok: bool = true
	ok = _recogniser_values() and ok
	ok = _refusals() and ok
	ok = _authoring_parity() and ok
	ok = _head_bar_fact() and ok
	ok = _doctor_notes() and ok
	ok = _pack_verbs() and ok
	ok = _round_trip() and ok
	return ok


## Gate one: the recognisers answering on their own, value by value.
static func _recogniser_values() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	for code: String in STATEMENT_READINGS:
		ok = _check("statement %s" % code,
			_joined_segments(EventSheetSentence.statement(code, context)),
			str(STATEMENT_READINGS[code])) and ok
	var seats: Dictionary = EventSheetBehaviorShapes.pin_seat_names(SOURCE.split("\n"))
	ok = _check("the marker declaration names the object it hangs off",
		str((seats.get("hand", {}) as Dictionary).get("owner", "")), "Player") and ok
	ok = _check("the marker declaration names the point",
		str((seats.get("hand", {}) as Dictionary).get("point", "")), "hand") and ok
	ok = _check("a path follower is a seat of its own kind",
		bool((seats.get("rail", {}) as Dictionary).get("path", false)), true) and ok
	ok = _check("a plain object variable is not a seat", seats.has("anchor"), false) and ok
	return ok


## Gate two: the refusals. `scale = x.scale` and one axis copied from another object are spellings
## the whole world writes, so they only read as a pin in a file that has already pinned that anchor.
static func _refusals() -> bool:
	var ok: bool = true
	var bare: Dictionary = {
		"self_object": "Lantern", "script_object": "Lantern", "self_class": "Node2D",
		"engine_properties": {"position": true, "global_position": true, "scale": true,
			"rotation": true}
	}
	for code: String in REFUSALS:
		ok = _check("a file that pins nothing keeps \"%s\"" % code,
			_joined_segments(EventSheetSentence.statement(code, bare)),
			str(REFUSALS[code])) and ok
		ok = _check("\"%s\" wears no Pin chip in a file that pins nothing" % code,
			_joined_segments(EventSheetSentence.statement(code, bare)).contains("Pin "),
			false) and ok
	# And the other half of the gate: in THIS file the same size copy IS a pin, because the file
	# pins that anchor on the line above it.
	ok = _check("the same size copy reads as a pin once the file has pinned that anchor",
		_joined_segments(EventSheetSentence.statement("scale = anchor.scale", _context())),
		"Lantern ▸ Pin  Pin size to anchor") and ok
	return ok


## Gate three: every new picker row writes EXACTLY the arithmetic the reading recognises.
static func _authoring_parity() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	for ace_id: String in AUTHORING_PARITY:
		var pair: Array = AUTHORING_PARITY[ace_id]
		var code: String = _filled_template(ace_id, pair[0])
		ok = _check("%s writes a line at all" % ace_id, code.is_empty(), false) and ok
		ok = _check("%s writes \"%s\"" % [ace_id, code],
			_joined_segments(EventSheetSentence.statement(code, context)), str(pair[1])) and ok
	var minted: PackedStringArray = PackedStringArray()
	for descriptor: ACEDescriptor in EventForgeBehaviorShapeACEs.get_descriptors():
		if UNAUTHORED_SHAPES.has(str(descriptor.ace_id)):
			minted.append(str(descriptor.ace_id))
	ok = _check("the over-general pin spellings have no picker row to hand the importer",
		",".join(minted), "") and ok
	return ok


## Gate four: the head bar's Y6 fact - what this object rides, in the pin's own mode words, off the
## file itself. Pinned by value here and walked through a real viewport below.
static func _head_bar_fact() -> bool:
	var ok: bool = true
	var rope: Array = EventSheetBehaviorShapes.pin_summaries(ROPE_ONLY.split("\n"))
	ok = _check("a rope file rides one thing", rope.size(), 1) and ok
	if rope.size() == 1:
		var first: Dictionary = rope[0]
		ok = _check("and names it", str(first.get("name", "")), "anchor") and ok
		ok = _check("and says which mode", ",".join(
			first.get("modes", PackedStringArray()) as PackedStringArray), "rope") and ok
	var many: Array = EventSheetBehaviorShapes.pin_summaries(SOURCE.split("\n"))
	var said: PackedStringArray = PackedStringArray()
	for summary: Variant in many:
		said.append("%s (%s)" % [str((summary as Dictionary).get("name", "")),
			" · ".join((summary as Dictionary).get("modes", PackedStringArray()) as PackedStringArray)])
	ok = _check("every mode in the fixture is one line of the bar", " | ".join(said),
		"anchor (rope · size) | hitch (bar) | lead (soft · angle) | Player's hand (position) | Track's path (position) | ground (x only · y only)") and ok
	# A place copied with an angle is ONE pin the pack calls "position and angle", not two.
	var both: Array = EventSheetBehaviorShapes.pin_summaries(PackedStringArray([
		"var anchor: Node2D", "global_position = anchor.global_position", "rotation = anchor.rotation"
	]))
	ok = _check("a place and an angle from one object are one pin", both.size(), 1) and ok
	if both.size() == 1:
		ok = _check("said in the mode word the pack's own knob uses", ",".join(
			(both[0] as Dictionary).get("modes", PackedStringArray()) as PackedStringArray),
			"position and angle") and ok
	var opened: PackedStringArray = _opened_rows()
	ok = _check("the opened file grows a Pins bar", opened.has("Pins"), true) and ok
	var bar_lines: PackedStringArray = PackedStringArray()
	for line: String in opened:
		if line.begins_with("pinned to "):
			bar_lines.append(line)
	# The OPENED file's bar, measured. It differs from the raw-source answer above in one place: the
	# importer lifts `scale = anchor.scale` to a shipped Set row, so that line is no longer in the
	# code the bar walks and the anchor is left saying `(rope)` rather than `(rope · size)`. Pinned
	# as it is rather than as it might be, because a bar that named a mode the canvas does not show
	# would be the exact failure the gates above exist to prevent.
	ok = _check("whose lines are the mockup's own sentences", " | ".join(bar_lines),
		"pinned to anchor (rope) | pinned to hitch (bar) | pinned to lead (soft · angle) | pinned to Player's hand (position) | pinned to Track's path (position) | pinned to ground (x only · y only)") and ok
	return ok


## Gate five: the Doctor's two Y6 notes, and the fixes each one offers.
static func _doctor_notes() -> bool:
	var ok: bool = true
	ok = _check("every spelling of a pin is found", ",".join(
		EventSheetProjectDoctor.pinned_anchors(SOURCE)),
		"anchor,ground,hand,hitch,lead,rail") and ok
	ok = _check("a child of the thing it is pinned to is a double follow", ",".join(
		EventSheetProjectDoctor.double_follow_anchors(DOUBLE_FOLLOW)), "rig") and ok
	ok = _check("a file that only pins is not a double follow", ",".join(
		EventSheetProjectDoctor.double_follow_anchors(FREED_ANCHOR)), "") and ok
	ok = _check("a pin to an object this file destroys is named", ",".join(
		EventSheetProjectDoctor.freed_pin_anchors(FREED_ANCHOR)), "anchor") and ok
	ok = _check("a file that already asks whether it is still there is left alone", ",".join(
		EventSheetProjectDoctor.freed_pin_anchors(FREED_ANCHOR_GUARDED)), "") and ok
	var double_fixes: Array[Dictionary] = EventSheetQuickFixes.fixes_for(
		{"check": "double-follow", "subject": "rig"})
	ok = _check("the double follow offers both ways out", _fix_labels(double_fixes),
		"Unpin it from rig | Take it out of rig") and ok
	var freed_fixes: Array[Dictionary] = EventSheetQuickFixes.fixes_for(
		{"check": "pin-to-freed-object", "subject": "anchor"})
	ok = _check("the freed anchor offers the guard and the unpin", _fix_labels(freed_fixes),
		"Unpin before anchor goes | Ask whether anchor is still there") and ok
	ok = _check("and each of the three fixes answers rather than failing", "%s|%s|%s" % [
		bool(EventSheetQuickFixes.apply("unpin_it", {"subject": "rig"}, {}).get("ok", false)),
		bool(EventSheetQuickFixes.apply("remove_from_parent", {"subject": "rig"}, {}).get("ok", false)),
		bool(EventSheetQuickFixes.apply("guard_pin_anchor", {"subject": "anchor"}, {}).get("ok", false))
	], "true|true|true") and ok
	return ok


## Y5. Both packs publish every mode as a row, and the emitted GDScript is what says so.
static func _pack_verbs() -> bool:
	var ok: bool = true
	ok = _check("the Pin pack publishes every mode",
		_missing_verbs("res://eventsheet_addons/pin/pin_behavior.gd", PIN_2D_VERBS), "") and ok
	ok = _check("the Pin 3D pack publishes every mode",
		_missing_verbs("res://eventsheet_addons/pin_3d/pin_3d_behavior.gd", PIN_3D_VERBS), "") and ok
	ok = _reach_maths() and ok
	var three_d: String = FileAccess.get_file_as_string("res://eventsheet_addons/pin_3d/pin_3d_behavior.gd")
	ok = _check("the 3D twin hosts a Node3D", three_d.contains("var host: Node3D = null"), true) and ok
	ok = _check("and rides a named attachment rather than a bone index",
		three_d.contains("anchor.find_child(pin_point, true, false) as Node3D"), true) and ok
	var two_d: String = FileAccess.get_file_as_string("res://eventsheet_addons/pin/pin_behavior.gd")
	ok = _check("the shipped three modes keep the meaning they always had",
		two_d.contains("const PIN_ANGLE_MODES: PackedStringArray = [\"angle\", \"position and angle\"]"),
		true) and ok
	ok = _check("the mode knob grew rather than being renamed",
		two_d.contains("@export_enum(\"position\", \"angle\", \"position and angle\", \"rope\", \"bar\", \"soft\", \"spring\", \"size\") var pin_mode"),
		true) and ok
	return ok


## Y4 / Y5. What each mode actually DOES, called straight on a behavior with no tree at all - the
## reach function needs a mode, a length and a frame time and nothing else, so the promise the mode
## names can be pinned by value rather than described.
##
## The numbers below were measured by running demo/showcase/pin_modes/pin_modes.tscn NON-headless
## for 360 physics frames, which is the only place the modes meet real motion:
##
##   rope   distance min 63.780, max 90.000  - slack below the length, never a pixel past it
##   bar    distance min 70.000, max 70.000  - the same length at both ends of the run
##   soft   lag up to 68.651 px              - always behind its anchor, never on top of it
##   X only the shadow's column matched the walker's exactly and its own height never moved (0.0000)
##   point  the sword sat on the hand marker to 0.0000 px on every frame
##   spring the hat reached 19.046 px from the head at its widest overshoot, then settled
static func _reach_maths() -> bool:
	var ok: bool = true
	var pin: Node = (load("res://eventsheet_addons/pin/pin_behavior.gd") as GDScript).new()
	pin.pin_mode = "rope"
	pin.pin_length = 90.0
	ok = _check("a slack rope moves nothing",
		pin._pin_reach(Vector2(0.0, 60.0), Vector2.ZERO, 0.1), Vector2(0.0, 60.0)) and ok
	ok = _check("a taut rope pulls back to exactly its length",
		pin._pin_reach(Vector2(0.0, 300.0), Vector2.ZERO, 0.1), Vector2(0.0, 90.0)) and ok
	pin.pin_mode = "bar"
	pin.pin_length = 70.0
	ok = _check("a bar pushes out to its length",
		pin._pin_reach(Vector2(0.0, 10.0), Vector2.ZERO, 0.1), Vector2(0.0, 70.0)) and ok
	ok = _check("and pulls in to it",
		pin._pin_reach(Vector2(0.0, 300.0), Vector2.ZERO, 0.1), Vector2(0.0, 70.0)) and ok
	pin.pin_mode = "soft"
	pin.pin_speed = 10.0
	ok = _check("a soft pin closes its share of the gap and no more",
		pin._pin_reach(Vector2(100.0, 0.0), Vector2.ZERO, 0.05), Vector2(50.0, 0.0)) and ok
	pin.pin_mode = "spring"
	pin.pin_stiffness = 100.0
	pin.pin_damping = 0.5
	pin.pin_velocity = Vector2.ZERO
	ok = _check("a spring carries velocity between frames",
		roundf(float(pin._pin_reach(Vector2.ZERO, Vector2(100.0, 0.0), 0.1).x) * 100.0) / 100.0,
		93.3) and ok
	pin.pin_mode = "position"
	ok = _check("and a plain pin lands on the goal",
		pin._pin_reach(Vector2(100.0, 0.0), Vector2.ZERO, 0.05), Vector2.ZERO) and ok
	pin.free()
	var pin_3d: Node = (load("res://eventsheet_addons/pin_3d/pin_3d_behavior.gd") as GDScript).new()
	pin_3d.pin_mode = "rope"
	pin_3d.pin_length = 2.0
	ok = _check("the 3D twin's rope hangs slack the same way",
		pin_3d._pin_reach(Vector3(0.0, 1.0, 0.0), Vector3.ZERO, 0.1), Vector3(0.0, 1.0, 0.0)) and ok
	ok = _check("and pulls back to exactly its length",
		pin_3d._pin_reach(Vector3(0.0, 9.0, 0.0), Vector3.ZERO, 0.1), Vector3(0.0, 2.0, 0.0)) and ok
	pin_3d.free()
	return ok


## Gate six: opening the file and saving it untouched puts back every byte.
static func _round_trip() -> bool:
	_write_source()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)


## The verbs the list asks for that the emitted pack does not publish, joined - "" when every one is
## there, and the missing NAMES when they are not.
static func _missing_verbs(pack_path: String, wanted: PackedStringArray) -> String:
	var source: String = FileAccess.get_file_as_string(pack_path)
	var missing: PackedStringArray = PackedStringArray()
	for verb: String in wanted:
		if not source.contains("## @ace_name(\"%s\")" % verb):
			missing.append(verb)
	return ",".join(missing)


static func _fix_labels(fixes: Array[Dictionary]) -> String:
	var labels: PackedStringArray = PackedStringArray()
	for fix: Dictionary in fixes:
		labels.append(str(fix.get("label", "")))
	return " | ".join(labels)


## One shipped descriptor's own codegen template with its slots filled, as a plain sheet emits it.
static func _filled_template(ace_id: String, params: Dictionary) -> String:
	for descriptor: ACEDescriptor in EventForgeBehaviorShapeACEs.get_descriptors():
		if descriptor.ace_id != ace_id:
			continue
		var code: String = descriptor.codegen_template.replace("{host.}", "")
		for key: Variant in params:
			code = code.replace("{%s}" % str(key), str(params[key]))
		return "" if code.contains("{") else code
	return ""


## Every cell reading of the opened fixture as "object ▸ text", plus the bare head-bar spans.
static func _opened_rows() -> PackedStringArray:
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
			readings.append(span.text.strip_edges())
	viewport.free()
	return readings


static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


## The context the opened fixture hands the grammar - the file facts, worked out from the file.
static func _context() -> Dictionary:
	var context: Dictionary = {
		"self_object": "Lantern",
		"script_object": "Lantern",
		"self_class": "Node2D",
		"engine_properties": {"position": true, "global_position": true, "rotation": true,
			"scale": true},
		"variable_types": {"pin_offset": "Vector2", "rope_length": "float", "bar_length": "float",
			"follow_speed": "float"}
	}
	context.merge(EventSheetBehaviorShapes.facts(SOURCE.split("\n")), true)
	return context


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
		print("[PASS] pin_modes_test: %s" % label)
		return true
	print("[FAIL] pin_modes_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
