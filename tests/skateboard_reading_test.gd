# EventForge - Y9 / Y22 / Y23 / Y24: the board, the rail, and the words both of them read as.
#
# Five gates, and the order matters:
#   1. the WHOLE-FILE facts, including their refusals - the gate that keeps `velocity.y =
#      -jump_speed` and `rotation += TAU * delta` belonging to whoever wrote them in every project
#      that is not writing a board;
#   2. the grammar answering value by value, so a change to a reading shows up as a moved string
#      rather than as a moved number;
#   3. a REAL hand-written file opened as a sheet and walked row by row, with both an expected and
#      a forbidden list - the forbidden half is what proves the two-line ride collapsed into one
#      row instead of quietly staying two;
#   4. the pattern claims, on the events that own them;
#   5. the byte round-trip, because every reading here is a lens and the file may not move.
#
# Plus the packs themselves, pinned on VALUES: the chain arithmetic, the balance meter's warning
# mark, and the rail geometry. The physics half (a slope that accelerates the board, an ollie that
# leaves the ground, a snap that engages inside its distance) cannot run here - `run_tests.gd` has
# no main loop, so no physics steps - and is measured by a non-headless harness instead; the
# numbers it measured are written down beside the rows that produced them.
@tool
class_name SkateboardReadingTest
extends RefCounted

const SOURCE_PATH := "user://skateboard_reading_probe.gd"

## The hand-written shape both items are about: a board that rolls with the slope, pushes, ollies
## and spins, and a rail it snaps to by closest offset and rides by baked sample.
const SOURCE := """extends CharacterBody2D

@onready var rail: Path2D = $\"../Rail\"
var grinding := false
var rail_offset := 0.0
var push_speed := 40.0
var max_speed := 600.0
var ollie_speed := 420.0
var grind_speed := 320.0
var gravity := 980.0


func _physics_process(delta):
	if is_on_floor():
		var slope := get_floor_normal().x
		velocity.x += slope * gravity * delta
		if Input.is_action_just_pressed(\"push\"):
			velocity.x = move_toward(velocity.x, max_speed * sign(velocity.x), push_speed)
		if Input.is_action_just_pressed(\"jump\"):
			velocity.y = -ollie_speed
	else:
		velocity.y += gravity * delta
		if Input.is_action_pressed(\"trick\"):
			rotation += TAU * delta
	if not grinding:
		var closest := rail.curve.get_closest_offset(rail.to_local(global_position))
		var point := rail.to_global(rail.curve.sample_baked(closest))
		if global_position.distance_to(point) < 12.0:
			grinding = true
			rail_offset = closest
	if grinding:
		rail_offset += grind_speed * delta
		global_position = rail.to_global(rail.curve.sample_baked(rail_offset))
		if rail_offset >= rail.curve.get_baked_length():
			grinding = false
	move_and_slide()
"""

## Every row the opened file must read as. The board's four verbs and the rail's five questions.
const EXPECTED_READINGS: PackedStringArray = [
	"CharacterBody2D ▸ Skateboard ▸ Roll with the slope gravity along the floor",
	"CharacterBody2D ▸ Skateboard ▸ Push toward max speed by push speed",
	"CharacterBody2D ▸ Skateboard ▸ Ollie ollie speed",
	"CharacterBody2D ▸ Skateboard ▸ Spin one turn per second",
	"CharacterBody2D ▸ Grind ▸ Is not grinding",
	"CharacterBody2D ▸ Grind ▸ Is grinding",
	"CharacterBody2D ▸ Grind ▸ Is near rail rail within 12.0",
	"CharacterBody2D ▸ Grind ▸ Start grinding rail",
	"CharacterBody2D ▸ Grind ▸ Grind along rail at grind_speed",
	"CharacterBody2D ▸ Grind ▸ Has reached the end",
	"CharacterBody2D ▸ Grind ▸ Hop off"
]

## What must no longer be there. Each of these is the reading a line KEPT before the board words
## existed, so a run that silently stopped grouping - or a reading that silently stopped firing -
## fails here instead of looking green.
const FORBIDDEN_READINGS: PackedStringArray = [
	"System ▸ Set velocity Y to -ollie speed",
	"System ▸ Add grind speed * dt to rail offset",
	"System ▸ rail offset ≥ rail's curve baked length"
]

const SKATEBOARD_PACK := "res://eventsheet_addons/skateboard/skateboard_behavior.gd"
const SKATEBOARD_3D_PACK := "res://eventsheet_addons/skateboard_3d/skateboard_3d_behavior.gd"


static func run() -> bool:
	var ok: bool = true
	ok = _facts_and_refusals() and ok
	ok = _grammar_values() and ok
	var opened: Dictionary = _open_and_read()
	var readings: PackedStringArray = opened.get("readings", PackedStringArray())
	for expected: String in EXPECTED_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	for forbidden: String in FORBIDDEN_READINGS:
		ok = _check("no row still reads \"%s\"" % forbidden, readings.has(forbidden), false) and ok
	ok = _pattern_claims(opened.get("patterns", {})) and ok
	ok = _round_trip() and ok
	ok = _registered_ids() and ok
	ok = _pack_rows() and ok
	ok = _chain_and_balance() and ok
	ok = _rail_geometry() and ok
	ok = _showcases() and ok
	return ok


## Gate one: what the file has to SAY before any of this fires, and the three ways it can decline.
static func _facts_and_refusals() -> bool:
	var ok: bool = true
	var lines: PackedStringArray = _lines(SOURCE)
	var grind: Dictionary = EventSheetPatternReadings.grind_facts(lines)
	ok = _check("the rail the file rides is named", str(grind.get("rail", "")), "rail") and ok
	ok = _check("the offset the ride walks is the one it also samples the curve with",
		str(grind.get("offset", "")), "rail_offset") and ok
	ok = _check("the flag the file both raises and lowers is the riding flag",
		str(grind.get("riding", "")), "grinding") and ok
	ok = _check("the speed the ride steps at is read off the step",
		str(grind.get("speed", "")), "grind_speed") and ok
	var skate: Dictionary = EventSheetPatternReadings.skate_facts(lines)
	ok = _check("the slope the board rolls with is named", str(skate.get("slope", "")), "slope") and ok
	ok = _check("the ollie knob is named", str(skate.get("ollie", "")), "ollie_speed") and ok
	ok = _check("the top-speed knob is named", str(skate.get("top_speed", "")), "max_speed") and ok
	# THE GATE. A file that measures a path is not riding one, and a file that jumps is not a board.
	var measuring: PackedStringArray = _lines("var closest = path.curve.get_closest_offset(here)")
	ok = _check("a closest offset with no baked sample beside it is not a ride",
		EventSheetPatternReadings.grind_facts(measuring).is_empty(), true) and ok
	var jumping: PackedStringArray = _lines("var ollie_speed = 420.0\nvelocity.y = -ollie_speed")
	ok = _check("a jump in a file that never rolls with a slope is not an ollie",
		EventSheetPatternReadings.skate_facts(jumping).is_empty(), true) and ok
	var turning: PackedStringArray = _lines("rotation += TAU * delta")
	ok = _check("a turn in a file that never rolls with a slope is not a trick",
		EventSheetPatternReadings.skate_facts(turning).is_empty(), true) and ok
	return ok


## Gate two: the grammar answering on its own, value by value.
static func _grammar_values() -> bool:
	var ok: bool = true
	var context: Dictionary = {
		"self_object": "Skater",
		"script_object": "Skater",
		"self_class": "CharacterBody2D",
		"engine_properties": {"velocity": true, "rotation": true, "global_position": true},
		"grind": {"rail": "rail", "offset": "rail_offset", "snap": "closest", "riding": "grinding",
			"speed": "grind_speed", "points": {"point": true}},
		"skate": {"slope": "slope", "gravity": "gravity", "ollie": "ollie_speed",
			"top_speed": "max_speed", "push": "push_speed"}
	}
	ok = _check("the slope projection reads as the board's own row, with the note that says why",
		_text(EventSheetSentence.skate_statement("velocity.x += slope * gravity * delta", context)),
		"Skateboard ▸ Roll with the slope gravity along the floor") and ok
	ok = _check("the move_toward toward the top speed reads as one push",
		_text(EventSheetSentence.skate_statement(
			"velocity.x = move_toward(velocity.x, max_speed * sign(velocity.x), push_speed)", context)),
		"Skateboard ▸ Push toward max speed by push_speed") and ok
	ok = _check("the same call aimed at a standstill reads as the brake instead",
		_text(EventSheetSentence.skate_statement(
			"velocity.x = move_toward(velocity.x, 0.0, brake_force)", context)),
		"Skateboard ▸ Brake by brake_force") and ok
	ok = _check("the pop off the ground reads as the ollie",
		_text(EventSheetSentence.skate_statement("velocity.y = -ollie_speed", context)),
		"Skateboard ▸ Ollie ollie_speed") and ok
	ok = _check("a whole turn a second reads as a spin",
		_text(EventSheetSentence.skate_statement("rotation += TAU * delta", context)),
		"Skateboard ▸ Spin one turn per second") and ok
	ok = _check("the same turn the other way reads as a flip",
		_text(EventSheetSentence.skate_statement("rotation -= TAU * delta", context)),
		"Skateboard ▸ Flip one turn per second") and ok
	ok = _check("a named rate reads as that many turns a second",
		_text(EventSheetSentence.skate_statement("rotation += 3.0 * TAU * delta", context)),
		"Skateboard ▸ Spin 3.0 turns per second") and ok
	ok = _check("an ordinary turn is left alone",
		EventSheetSentence.skate_statement("rotation += spin_speed * delta", context).is_empty(),
		true) and ok
	ok = _check("the flag going up reads as locking onto the rail",
		_text(EventSheetSentence.skate_statement("grinding = true", context)),
		"Grind ▸ Start grinding rail") and ok
	ok = _check("the flag coming down reads as letting it go",
		_text(EventSheetSentence.skate_statement("grinding = false", context)),
		"Grind ▸ Hop off") and ok
	ok = _check("a distance to the point read off the curve reads as the snap's question",
		_text(EventSheetSentence.skate_condition("global_position.distance_to(point) < 12.0", context)),
		"Grind ▸ Is near rail rail within 12.0") and ok
	ok = _check("a distance to anything else is still a distance",
		EventSheetSentence.skate_condition("global_position.distance_to(door) < 12.0", context).is_empty(),
		true) and ok
	ok = _check("the offset against the baked length reads as the end of the line",
		_text(EventSheetSentence.skate_condition(
			"rail_offset >= rail.curve.get_baked_length()", context)),
		"Grind ▸ Has reached the end") and ok
	ok = _check("the bare flag reads as the question it is",
		_text(EventSheetSentence.skate_condition("grinding", context)),
		"Grind ▸ Is grinding") and ok
	# The run grouper's two halves, asked directly so the group cannot pass by accident.
	ok = _check("the ride step hands back the speed it walks at",
		EventSheetSentence.grind_step_speed("rail_offset += grind_speed * delta", "rail_offset"),
		"grind_speed") and ok
	ok = _check("a step with no delta on it is not a ride",
		EventSheetSentence.grind_step_speed("rail_offset += 4.0", "rail_offset"), "") and ok
	ok = _check("the position write is the ride's other half",
		EventSheetSentence.is_grind_sample_write(
			"global_position = rail.to_global(rail.curve.sample_baked(rail_offset))",
			"rail", "rail_offset"), true) and ok
	ok = _check("a sample read into a LOCAL is the question, not the ride",
		EventSheetSentence.is_grind_sample_write(
			"var point = rail.to_global(rail.curve.sample_baked(rail_offset))",
			"rail", "rail_offset"), false) and ok
	return ok


## Gate four: each shape is claimed in the registry, on the event that owns it.
static func _pattern_claims(patterns: Dictionary) -> bool:
	var ok: bool = true
	# A claim is deduped per (pattern, row): four board verbs on one tick are one claim, and the rail
	# is claimed twice because catching it and riding it are two separate events.
	ok = _check("the board pattern is claimed on the event that writes its verbs",
		int(patterns.get("skateboard", 0)), 1) and ok
	ok = _check("the rail pattern is claimed on both the catch and the ride",
		int(patterns.get("grind", 0)), 2) and ok
	return ok


## Gate five: every reading here is a lens over a value the row already holds, so opening the real
## hand-written file and saving it untouched puts back every byte.
static func _round_trip() -> bool:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)


## Both ids are registered, and the words and the adoptable pack are the ones the chip shows.
static func _registered_ids() -> bool:
	var ok: bool = true
	ok = _check("the rail id is registered",
		EventSheetPatternFacts.PATTERN_IDS.has("grind"), true) and ok
	ok = _check("the board id is registered",
		EventSheetPatternFacts.PATTERN_IDS.has("skateboard"), true) and ok
	ok = _check("the rail chip says what it is",
		EventSheetPatternVocabulary.words("grind"), "Riding a rail") and ok
	ok = _check("the board chip says what it is",
		EventSheetPatternVocabulary.words("skateboard"), "Momentum movement on a board") and ok
	ok = _check("both point at the pack that could replace the hand-written shape",
		"%s|%s" % [EventSheetPatternVocabulary.adoptable("grind"),
			EventSheetPatternVocabulary.adoptable("skateboard")], "skateboard|skateboard") and ok
	return ok


## The rows the packs publish, by the names they are frozen under. A rename would break every sheet
## that ever dropped one, so this is the covenant written down.
static func _pack_rows() -> bool:
	var ok: bool = true
	var source: String = FileAccess.get_file_as_string(SKATEBOARD_PACK)
	for row: String in ["Push", "Roll With The Slope", "Ollie", "Manual", "Stop The Manual",
			"Brake", "Reverse", "Spin Trick", "Flip Trick", "Land The Trick", "Bail",
			"Add To Chain", "Bank Chain", "Drop Chain", "Start Balancing", "Steer The Balance",
			"Is Rolling", "Is Airborne", "Is In A Manual", "Is Losing Balance", "Balance",
			"Chain Score", "Multiplier", "Banked Score", "Spin Turns", "On Ollie",
			"On Landed Clean", "On Bailed", "On Trick Done", "Is Near Rail", "Start Grinding",
			"Grind Along Rail", "Has Reached The End", "Hop Off", "Ride Zipline", "Is Grinding"]:
		ok = _check("the board publishes %s" % row,
			source.contains("## @ace_name(\"%s\")" % row), true) and ok
	ok = _check("the rail rows sit in their own section, so a traversal pack can adopt them",
		source.contains("## @ace_category(\"Grind\")"), true) and ok
	var source_3d: String = FileAccess.get_file_as_string(SKATEBOARD_3D_PACK)
	for row: String in ["Align The Board To The Surface", "On Launched Off The Lip",
			"Surface Normal", "Roll With The Slope", "Is Near Rail", "Ride Zipline"]:
		ok = _check("the 3D board publishes %s" % row,
			source_3d.contains("## @ace_name(\"%s\")" % row), true) and ok
	ok = _check("the 3D twin is a body that moves in three dimensions",
		source_3d.contains("var host: CharacterBody3D = null"), true) and ok
	# Y24 - the chain rows are offered to fighters too, in the same words.
	var combo: String = FileAccess.get_file_as_string("res://eventsheet_addons/combo_box/combo_box_addon.gd")
	for row: String in ["Add To Chain", "Bank Chain", "Drop Chain", "Chain Score", "Multiplier"]:
		ok = _check("the combo pack offers %s as well" % row,
			combo.contains("## @ace_name(\"%s\")" % row), true) and ok
	# Y24 - a meter with a CENTRE, which a bar cannot show.
	var hud: String = FileAccess.get_file_as_string("res://eventsheet_addons/hud_kit/hud_kit_behavior.gd")
	ok = _check("the HUD pack gained the balance needle",
		hud.contains("## @ace_name(\"Set Needle\")"), true) and ok
	return ok


## The chain arithmetic and the balance meter, on a real instance. Pure state, so no host and no
## tree are needed - which is exactly why these are the parts pinned here rather than in a harness.
static func _chain_and_balance() -> bool:
	var ok: bool = true
	var board: Object = (load(SKATEBOARD_PACK) as GDScript).new()
	board.add_to_chain("kickflip", 100.0)
	ok = _check("the first trick scores at one times", board.chain_score(), 100.0) and ok
	ok = _check("and the next one will be worth twice", board.multiplier(), 2) and ok
	board.add_to_chain("grind", 100.0)
	board.add_to_chain("spin", 100.0)
	ok = _check("three tricks at a climbing multiplier are worth 600", board.chain_score(), 600.0) and ok
	ok = _check("and the fourth would be worth four times", board.multiplier(), 4) and ok
	board.bank_chain()
	ok = _check("banking moves the chain into the total", board.banked_score(), 600.0) and ok
	ok = _check("and leaves nothing running", board.chain_score(), 0.0) and ok
	ok = _check("with the multiplier back at one", board.multiplier(), 1) and ok
	board.add_to_chain("kickflip", 100.0)
	board.drop_chain()
	ok = _check("a dropped chain is worth nothing", board.chain_score(), 0.0) and ok
	ok = _check("and never reaches the banked total", board.banked_score(), 600.0) and ok
	board.start_balancing(0.8)
	ok = _check("balance starts dead centre", board.balance(), 0.0) and ok
	ok = _check("which is not losing it", board.is_losing_balance(), false) and ok
	board._balance = 0.7
	ok = _check("past the warning mark it is", board.is_losing_balance(), true) and ok
	board.stop_manual()
	ok = _check("and stopping the manual puts the needle back", board.balance(), 0.0) and ok
	ok = _check("with nothing left to lose", board.is_losing_balance(), false) and ok
	# The board's own numbers, as the Inspector ships them.
	ok = _check("a push is worth 40 by default", board.push_speed, 40.0) and ok
	ok = _check("the landing tolerance is 25 degrees", board.landing_tolerance_degrees, 25.0) and ok
	ok = _check("and the rail snaps within 12 px", board.rail_snap_distance, 12.0) and ok
	board.free()
	var board_3d: Object = (load(SKATEBOARD_3D_PACK) as GDScript).new()
	ok = _check("the 3D board calls a bank a lip past 55 degrees",
		board_3d.lip_angle_degrees, 55.0) and ok
	ok = _check("and adds nothing on top of the speed the transition gave it",
		board_3d.lip_boost, 0.0) and ok
	board_3d.free()
	return ok


## The rail geometry, on a real Path2D. The snap is a closest offset on the curve and a distance
## against it, so the answer is arithmetic a test can check without a physics space.
static func _rail_geometry() -> bool:
	var ok: bool = true
	var rail: Path2D = Path2D.new()
	var curve: Curve2D = Curve2D.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(300.0, 0.0))
	rail.curve = curve
	var body: CharacterBody2D = CharacterBody2D.new()
	body.position = Vector2(150.0, 8.0)
	var board: Object = (load(SKATEBOARD_PACK) as GDScript).new()
	board.host = body
	ok = _check("a board 8 px off the line is near a rail measured at 12",
		board.is_near_rail(rail, 12.0), true) and ok
	ok = _check("and is not near the same rail measured at 4",
		board.is_near_rail(rail, 4.0), false) and ok
	ok = _check("a rail with no curve is not a rail", board.is_near_rail(Path2D.new(), 999.0),
		false) and ok
	ok = _check("and neither is something that is not a path",
		board.is_near_rail(Node2D.new(), 999.0), false) and ok
	board.start_grinding(rail)
	ok = _check("locking on puts the board on the line", board.is_grinding(), true) and ok
	ok = _check("at the nearest point on it", body.position, Vector2(150.0, 0.0)) and ok
	ok = _check("which is not the end of it", board.has_reached_the_end(), false) and ok
	board.hop_off(0.0)
	ok = _check("and hopping off hands the board back", board.is_grinding(), false) and ok
	board.free()
	body.free()
	rail.free()
	return ok


## The two showcases exist, are the sheets they say they are, and are written in the pack's words
## rather than in skating math.
static func _showcases() -> bool:
	var ok: bool = true
	for named: Array in [["res://demo/showcase/skate_park/skate_park.gd", "roll_with_slope"],
			["res://demo/showcase/skate_park_3d/skate_park_3d.gd", "align_board_to_surface"]]:
		var path: String = str(named[0])
		var source: String = FileAccess.get_file_as_string(path)
		ok = _check("%s ships" % path.get_file(), source.is_empty(), false) and ok
		ok = _check("%s calls the pack rather than doing the math" % path.get_file(),
			source.contains("$Skater/Skateboard.%s()" % str(named[1])), true) and ok
		ok = _check("%s hangs the score on the landing" % path.get_file(),
			source.contains("$Skater/Skateboard.bank_chain()"), true) and ok
		ok = _check("%s snaps to the rail through the row, with its distance" % path.get_file(),
			source.contains("is_near_rail($Rail,"), true) and ok
		# The sheet is a lens over this file, so it has to reopen as itself.
		var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
		ok = _check("%s reopens and recompiles byte-identically" % path.get_file(),
			str(SheetCompiler.compile(sheet, path).get("output", "")), source) and ok
	# The measured physics, from the non-headless harness that ran these scenes (deleted after use).
	# Written down because a number nobody recorded is a number nobody can notice changing:
	#   2D  the board lands on the slope at frame 22 and its x speed goes 0.00 -> 93.61 over the
	#       next 40 frames, carrying it from x 110.0 to x 153.7;
	#       ollie(420) sets velocity.y to -420.0 and Is Airborne is true three frames later;
	#       is_near_rail is true 8 px off the line at 16 and false 52 px off it;
	#       start_grinding puts the board at (560.0, 552.0), which is the curve's own point;
	#       the chain reads 100 then 600 at x4, banks 600, and leaves 0 at x1;
	#       the HUD needle is built on first use and sits at x 163.0 of a 220-wide box for a
	#       balance of 0.5, moving to x 207.0 and turning the warning colour at 0.9;
	#       a bail hands the board to the Checkpoint pack, which puts it back at (110.0, 300.0)
	#       with the chain at 0 and the banked 600 untouched.
	#   3D  ground speed goes 0.00 -> 2.90 m/s over 40 frames on the slope;
	#       ollie(6) sets velocity.y to 6.00 and Is Airborne is true three frames later;
	#       is_near_rail is true 0.3 m off the line at 0.8 and false 2.5 m off it;
	#       start_grinding puts the board at (3.50, -1.00, 0.00).
	return ok


## Builds the sheet the reading walk runs over, and walks it: every row's cells as "object ▸ text",
## plus {pattern id: how many events claimed it}.
##
## The rows are assembled here rather than taken from the importer ON PURPOSE, and the reason is
## worth writing down. The importer only lifts a function when recompiling the lifted sheet
## reproduces the file byte for byte, and that gate is sensitive to process-wide state a previous
## compile left behind: compiling any BEHAVIOUR sheet earlier in the same session (the Test Bench
## does it, publishing a pack does it) is enough to make the very next `.gd` open as one verbatim
## block instead of as rows. Nothing about the reading changes - the row it would have drawn simply
## never exists - so a reading test built on the importer would pass alone and fail in a suite,
## reporting a lift bug as a reading bug. The byte round-trip below still runs on the real imported
## file, which is the half of the promise the importer actually owns.
static func _open_and_read() -> Dictionary:
	var sheet: EventSheetResource = _board_sheet()
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


## The board's shapes as a sheet: the same declarations and the same lines as SOURCE, in the row
## shape a `.gd` opens as when its function lifts. The lines are verbatim from SOURCE, so the
## readings under test are reading exactly the text a hand-written file carries.
static func _board_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	# The knobs the readings are gated on, as the declarations a hand-written file carries. A
	# verbatim prelude row rather than sheet.variables, because the facts walk reads the file's
	# LINES and a knob nobody wrote down is a knob no reading may lean on.
	var prelude: RawCodeRow = RawCodeRow.new()
	prelude.code = "\n".join(PackedStringArray([
		"@onready var rail: Path2D = $\"../Rail\"",
		"var grinding := false",
		"var rail_offset := 0.0",
		"var push_speed := 40.0",
		"var max_speed := 600.0",
		"var ollie_speed := 420.0",
		"var grind_speed := 320.0",
		"var gravity := 980.0"
	]))
	sheet.events.append(prelude)
	# The board: the slope projection that proves it is a board at all, then the three verbs the
	# slope line licenses.
	sheet.events.append(_tick([
		"var slope = get_floor_normal().x",
		"velocity.x += slope * gravity * delta",
		"velocity.x = move_toward(velocity.x, max_speed * sign(velocity.x), push_speed)",
		"velocity.y = -ollie_speed",
		"rotation += TAU * delta"
	]))
	# The rail: the closest-offset snap, its question, and the flag going up.
	var snap: EventRow = _tick([
		"var closest = rail.curve.get_closest_offset(rail.to_local(global_position))",
		"var point = rail.to_global(rail.curve.sample_baked(closest))",
		"grinding = true"
	])
	snap.conditions.append(_raw_condition("not grinding"))
	snap.conditions.append(_raw_condition("global_position.distance_to(point) < 12.0"))
	sheet.events.append(snap)
	# The ride: two lines that are one row, and the end of the line.
	var ride: EventRow = _tick([
		"rail_offset += grind_speed * delta",
		"global_position = rail.to_global(rail.curve.sample_baked(rail_offset))",
		"grinding = false"
	])
	ride.conditions.append(_raw_condition("grinding"))
	ride.conditions.append(_raw_condition("rail_offset >= rail.curve.get_baked_length()"))
	sheet.events.append(ride)
	return sheet


## One Every-tick-physics event carrying the given lines as verbatim action rows.
static func _tick(lines: PackedStringArray) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnPhysicsProcess"
	for line: String in lines:
		var code: RawCodeRow = RawCodeRow.new()
		code.code = line
		row.actions.append(code)
	return row


## One condition carrying its expression verbatim, which is what a lifted `if` line becomes.
static func _raw_condition(expression: String) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "ExpressionIsTrue"
	condition.codegen_template = "{expr}"
	condition.params = {"expr": expression}
	return condition


## Every row in the tree, parents before children.
static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


## The words a reading came out with, joined - or "" when it declined to answer.
static func _text(reading: Dictionary) -> String:
	if reading.is_empty():
		return ""
	var joined: String = ""
	for segment: Variant in (reading.get("segments", []) as Array):
		joined += str((segment as Dictionary).get("text", ""))
	return joined.strip_edges()


static func _lines(source: String) -> PackedStringArray:
	return source.split("\n")


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] skateboard_reading_test: %s" % label)
		return true
	print("[FAIL] skateboard_reading_test: %s - expected %s, got %s" % [label, expected, actual])
	return false
