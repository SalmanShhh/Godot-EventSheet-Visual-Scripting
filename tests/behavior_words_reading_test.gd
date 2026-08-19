@tool
class_name BehaviorWordsReadingTest
extends RefCounted

# Pins the behaviors a hand-rolled script writes, read with the behavior's own words - the shapes
# batch nine claims:
#
#   T5   a raycast cast at a target is ONE question: "<object> has line of sight to <target>"
#   T6   the grab / release / follow trio is the Drag & Drop behavior, and an anchor preset is the
#        Anchor behavior's "Anchor to <corner>"
#   T7   a collision shape switched off is the Solid going away, a one-way shape is the Jump-thru,
#        and a collision layer is the layer the Solid is on
#   T23  `test_move(transform, offset)` is "Is overlapping at offset", the platformer's own question
#   T25  a weighted draw, a seed and the noise are the Advanced Random object's rows
#   T26  the system clock's calls and fields are the Date object's expressions
#
# Four gates, in the order they matter:
#   1. the grammar's own values - one shape, one sentence, asserted literally;
#   2. the whole path - a hand-written file opened as a sheet, walked row by row, so a reading that
#      stops reaching the canvas is caught even when the grammar still answers on its own;
#   3. the claims - every event holding one of these shapes says so in the pattern registry, with
#      the source lines as evidence and the pack that could replace it;
#   4. the promise all of them rest on - the file still saves byte-identically.
#
# The source lives here as a string rather than in tests/fixtures/ for the same reason its sibling
# reading tests' sources do: the lifter's byte gate compares against what the COMPILER would emit,
# and the compiler puts ONE blank line between functions, so a checked-in two-blank-line file could
# never lift and the fixture would silently test nothing.

const SOURCE_PATH := "user://eventforge_behavior_words_reading.gd"

const SOURCE: String = """extends CharacterBody2D

@onready var ray: RayCast2D = $RayCast2D
@export var sight_range: float = 400.0
@export var enemy_scene: PackedScene
var loaded: bool = false
var dragging: bool = false
var grab_offset: Vector2 = Vector2.ZERO
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var noise: FastNoiseLite = FastNoiseLite.new()
var hp: int = 100
var drop: String = ""
var stamp: float = 0.0
var day: String = ""

func can_see(t: Node2D) -> bool:
	if global_position.distance_to(t.global_position) > sight_range:
		return false
	ray.target_position = to_local(t.global_position)
	ray.force_raycast_update()
	return not ray.is_colliding() or ray.get_collider() == t

func grab() -> void:
	dragging = true
	grab_offset = global_position - get_global_mouse_position()

func release() -> void:
	dragging = false

func _process(_delta: float) -> void:
	if dragging:
		global_position = get_global_mouse_position() + grab_offset
	if test_move(transform, Vector2(0, 1)):
		hp = 1

func open_gate() -> void:
	$CollisionShape2D.one_way_collision = true
	$CollisionShape2D.disabled = true
	set_collision_layer_value(1, true)

func roll() -> void:
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	rng.seed = hash("level-1")
	drop = ["coin", "gem", "nothing"][rng.rand_weighted([70, 20, 10])]
	var now: Dictionary = Time.get_datetime_dict_from_system()
	hp = now.hour
	stamp = Time.get_unix_time_from_system()
	day = Time.get_date_string_from_system()

func spawn(spawn_point: Node2D, angle: float) -> void:
	var e = enemy_scene.instantiate()
	e.global_position = spawn_point.global_position
	$FX.add_child(e)
	e.rotation = angle

func sweep() -> void:
	for a in $Area2D.get_overlapping_areas():
		hp += 1

func load_all() -> void:
	while not loaded:
		await get_tree().process_frame
"""

## The statements whose sentence this parcel settles, as "object ▸ sentence".
static var STATEMENT_READINGS: Dictionary = {
	# T6 - the drag trio
	"dragging = true": "Player ▸ Drag & Drop ▸ Start dragging",
	"dragging = false": "Player ▸ Drag & Drop ▸ Drop",
	"grab_offset = global_position - get_global_mouse_position()":
		"Player ▸ Drag & Drop ▸ Remember the grab offset",
	"global_position = get_global_mouse_position() + grab_offset":
		"Player ▸ Drag & Drop ▸ Follow the cursor (keeping the grab offset)",
	# T6 - the anchor words
	"set_anchors_preset(Control.PRESET_TOP_RIGHT)":
		"Player ▸ Anchor ▸ Anchor to top right (of the window)",
	"panel.set_anchors_preset(Control.PRESET_FULL_RECT)":
		"panel ▸ Anchor ▸ Anchor to full rect (of the window)",
	"anchor_left = 0.5": "Player ▸ Anchor ▸ Set left anchor to 0.5",
	"offset_top = 8": "Player ▸ Anchor ▸ Set top margin to 8",
	# T7 - what this body is to the others
	"$CollisionShape2D.one_way_collision = true":
		"Player ▸ Jump-thru ▸ Set enabled (one-way: solid from above only)",
	"$CollisionShape2D.one_way_collision = false": "Player ▸ Jump-thru ▸ Set disabled",
	"$CollisionShape2D.disabled = true": "Player ▸ Solid ▸ Set disabled",
	"$CollisionShape2D.disabled = false": "Player ▸ Solid ▸ Set enabled",
	"set_collision_layer_value(1, true)": "Player ▸ Solid ▸ On layer 1",
	"set_collision_layer_value(2, false)": "Player ▸ Solid ▸ Not on layer 2",
	# T25 - the seeds
	"rng.seed = hash(\"level-1\")": "Advanced Random ▸ Set seed to \"level-1\"",
	"rng.seed = 12345": "Advanced Random ▸ Set seed to 12,345",
	"noise.noise_type = FastNoiseLite.TYPE_PERLIN": "Advanced Random ▸ Set noise type to Perlin",
	"randomize()": "Advanced Random ▸ Randomize seed"
}

## The condition readings the grammar must answer on its own, as "object ▸ sentence".
static var CONDITION_READINGS: Dictionary = {
	# T6 - with the file's own drag proved, the flag is the behavior's question
	"dragging": "Player ▸ Drag & Drop ▸ Is dragging",
	"not dragging": "Player ▸ Drag & Drop ▸ Is not dragging",
	# T23 - the platformer's "is there ground just below me"
	"test_move(transform, Vector2(0, 1))": "Player ▸ Is overlapping at offset (0, 1) (a solid)",
	"move_and_collide(Vector2(0, 1), true)": "Player ▸ Is overlapping at offset (0, 1) (a solid)",
	# T23 - the overlap questions that already read, kept honest beside the new one
	"hurtbox.overlaps_body(other)": "hurtbox ▸ Is overlapping other"
}

## The values whose whole-expression reading this parcel settles.
static var EXPRESSION_READINGS: Dictionary = {
	# T5 - the whole ray test as the one condition the Line of Sight behavior publishes
	"not ray.is_colliding() or ray.get_collider() == t":
		"Player has line of sight to t (within sight_range)",
	# T25 - a list indexed by a weighted draw is one thought
	"[\"coin\", \"gem\", \"nothing\"][rng.rand_weighted([70, 20, 10])]":
		"choose weighted(\"coin\" 70, \"gem\" 20, \"nothing\" 10)",
	# T25 - the noise, by the type the file stated
	"noise.get_noise_2d(x, y)": "AdvancedRandom.Perlin2d(x, y)",
	"noise.get_noise_3d(x, y, z)": "AdvancedRandom.Perlin3d(x, y, z)",
	# T26 - the clock and the calendar
	"now.hour": "Date.Hour",
	"now.minute": "Date.Minute",
	"Time.get_unix_time_from_system()": "Date.Now",
	"Time.get_date_string_from_system()": "Date.Today",
	"Time.get_time_string_from_system()": "Date.TimeString"
}

## Every reading the OPENED file must contain, so a reading that stops reaching the canvas is caught.
## The object column names the class an opened script IS, because that is what the sheet knows itself
## as before anyone gives its object a name of their own.
static var EXPECTED_READINGS: PackedStringArray = PackedStringArray([
	"CharacterBody2D ▸ Drag & Drop ▸ Start dragging",
	"CharacterBody2D ▸ Drag & Drop ▸ Drop",
	"CharacterBody2D ▸ Drag & Drop ▸ Remember the grab offset",
	"CharacterBody2D ▸ Drag & Drop ▸ Follow the cursor (keeping the grab offset)",
	"CharacterBody2D ▸ Drag & Drop ▸ Is dragging",
	"CharacterBody2D ▸ Jump-thru ▸ Set enabled (one-way: solid from above only)",
	"CharacterBody2D ▸ Solid ▸ Set disabled",
	"CharacterBody2D ▸ Solid ▸ On layer 1",
	"CharacterBody2D ▸ Is overlapping at offset (0, 1) (a solid)",
	"Advanced Random ▸ Set seed to \"level-1\"",
	"Advanced Random ▸ Set noise type to Perlin",
	"System ▸ Set drop to choose weighted(\"coin\" 70, \"gem\" 20, \"nothing\" 10)",
	"System ▸ Return CharacterBody2D has line of sight to t (within Sight Range)",
	# T22 - the instantiate, the layer it went onto, where it was put and the property set on the way
	# in are ONE row; the Local row that holds the new object stays where the event declares it.
	"System ▸ Create object enemy_scene on layer FX at spawn point's global position (as e)   rotation = angle",
	# T23 - a loop over what an area is touching
	"System ▸ For each a overlapping Area2D"
])


static func run() -> bool:
	var ok: bool = true
	ok = _grammar_values() and ok
	var readings: PackedStringArray = _open_and_read()
	for expected: String in EXPECTED_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	ok = _facts() and ok
	ok = _claims() and ok
	ok = _round_trip() and ok
	return ok


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
	# Every one of these words rests on a fact the FILE states. With none of them stated, each line
	# keeps the ordinary reading it has today - which is what stops an ordinary boolean, an ordinary
	# property and somebody's own `now` from being dressed up as a behavior.
	var bare: Dictionary = {"self_object": "Player", "script_object": "Player",
		"self_class": "CharacterBody2D"}
	ok = _check("a boolean nothing proved a drag for is an ordinary flag",
		_joined_pieces(EventSheetSentence.condition_pieces("dragging", bare)),
		"Player ▸ dragging is true") and ok
	# The ordinary call reading takes the test apart the way it always has - `get_collider()` is the
	# thing that was hit - rather than saying anything about sight.
	ok = _check("a ray nothing declared keeps the test it wrote",
		EventSheetSentence.expression_text("not ray.is_colliding() or ray.get_collider() == t", bare),
		"not ray.is_colliding() or ray.collider == t") and ok
	ok = _check("somebody else's hour is their own property",
		EventSheetSentence.expression_text("now.hour", bare), "now.hour") and ok
	ok = _check("a weighted draw whose lists do not line up is left alone",
		EventSheetSentence.expression_text("[\"coin\"][rng.rand_weighted([70, 20])]", bare),
		"[\"coin\"][rng.rand_weighted([70, 20])]") and ok
	return ok


## Gate two-and-a-half: the whole-file facts every reading above is built on, as the file states them.
static func _facts() -> bool:
	var ok: bool = true
	_write_source()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var facts: Dictionary = EventSheetViewportReadingRows.behavior_words_facts(sheet)
	ok = _check("the ray the sight test is cast with is named",
		(facts.get("sight_rays", {}) as Dictionary).has("ray"), true) and ok
	ok = _check("the range the guard measures against is named",
		str(facts.get("sight_range", "")), "sight_range") and ok
	ok = _check("the grab offset is named",
		(facts.get("drag_offsets", {}) as Dictionary).has("grab_offset"), true) and ok
	ok = _check("the drag flag is named",
		(facts.get("drag_flags", {}) as Dictionary).has("dragging"), true) and ok
	ok = _check("the noise type the file set is the word the expression uses",
		str(facts.get("noise_type", "")), "Perlin") and ok
	ok = _check("the local the clock was read into is named",
		(facts.get("datetime_locals", {}) as Dictionary).has("now"), true) and ok
	return ok


## Gate three: every shape the file holds is CLAIMED on the event that owns it, with the source lines
## as evidence and - where one ships - the behavior that could replace it.
static func _claims() -> bool:
	var ok: bool = true
	_write_source()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	EventSheetPatternFacts.clear(sheet)
	EventSheetViewportReadingRows.claim_behavior_patterns(sheet)
	var claimed: Dictionary = {}
	var adoptable: Dictionary = {}
	var evidence: Dictionary = {}
	for entry: Variant in EventSheetPatternFacts.claims(sheet):
		var claim: Dictionary = entry
		var pattern: String = str(claim.get("pattern", ""))
		claimed[pattern] = true
		var offers: PackedStringArray = adoptable.get(pattern, PackedStringArray())
		offers.append(str(claim.get("adoptable", "")))
		adoptable[pattern] = offers
		var lines: PackedStringArray = evidence.get(pattern, PackedStringArray())
		lines.append_array(claim.get("evidence", PackedStringArray()))
		evidence[pattern] = lines
	for pattern: String in ["line_of_sight", "drag_drop", "solid", "jumpthru", "overlap",
			"advanced_random", "date"]:
		ok = _check("the file claims the %s pattern" % pattern, claimed.has(pattern), true) and ok
	ok = _check("a 2D sight test offers the Line of Sight behavior",
		(adoptable.get("line_of_sight", PackedStringArray()) as PackedStringArray).has("line_of_sight"),
		true) and ok
	ok = _check("a hand-rolled drag offers the Drag & Drop behavior",
		(adoptable.get("drag_drop", PackedStringArray()) as PackedStringArray).has("drag_drop"),
		true) and ok
	ok = _check("a solid offers no behavior of its own - it is what the body already is",
		"".join(adoptable.get("solid", PackedStringArray()) as PackedStringArray), "") and ok
	ok = _check("the sight claim keeps what it saw as evidence",
		"\n".join(evidence.get("line_of_sight", PackedStringArray())).contains("force_raycast_update()"),
		true) and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] behavior_words_reading_test: %s" % label)
		return true
	print("[FAIL] behavior_words_reading_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


## The sentence context an opened controller script hands the grammar, including the whole-file facts
## the reading rows gather once per rebuild.
static func _context() -> Dictionary:
	return {
		"self_object": "Player",
		"script_object": "Player",
		"self_class": "CharacterBody2D",
		"engine_properties": {"position": true, "rotation": true, "velocity": true,
			"global_position": true, "anchor_left": true, "offset_top": true},
		"variable_types": {"hp": "int", "dragging": "bool"},
		"sight_rays": {"ray": true},
		"sight_range": "sight_range",
		"drag_flags": {"dragging": true},
		"drag_offsets": {"grab_offset": true},
		"noise_locals": {"noise": true},
		"noise_type": "Perlin",
		"random_locals": {"rng": true},
		"datetime_locals": {"now": true}
	}


## One condition reading as "object ▸ sentence", or the bare sentence when no object is named.
static func _joined_pieces(reading: Dictionary) -> String:
	var text: String = ""
	for piece: Variant in (reading.get("pieces", []) as Array):
		text += str((piece as Array)[0])
	var object_label: String = str(reading.get("object", ""))
	return "%s ▸ %s" % [object_label, text.strip_edges()] if not object_label.is_empty() else text.strip_edges()


## One statement reading as "object ▸ sentence".
static func _joined_segments(reading: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (reading.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	var object_label: String = str(reading.get("object", ""))
	return "%s ▸ %s" % [object_label, text.strip_edges()] if not object_label.is_empty() else text.strip_edges()


## Writes the source where the importer can open it.
static func _write_source() -> void:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()


## Opens the source as a sheet and returns every cell reading - "object ▸ text" when the row names an
## object, the bare text otherwise.
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


## The promise every reading here rests on: each one is a lens over a value the row already holds, so
## opening the file and saving it untouched puts back every byte.
static func _round_trip() -> bool:
	_write_source()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)
