@tool
class_name ReadingWords7Test
extends RefCounted

# Pins the reading words batch seven added - the questions a real script asks that used to read as
# the operators they are rather than as the sheet's own row:
#
#   A range, an angle window, a distance, an area and an approximate equality each read as ONE
#        condition, in the sheet's name for it, with the note that says which end is left out
#   The cooldown-by-timestamp idiom reads as "X seconds have passed since", and writing the
#        clock into a variable reads "Set ... to now"
#   A roll under a probability reads as a percentage chance, and the random calls read by the
#        sheet's own expression names under Familiar Words
#   The expression-name table, which also settles the length question: len(x) under Familiar
#        Words, "length of x" otherwise
#   The scene-flow actions read as Go to layout / Restart layout / Pause the game / Unpause /
#        Set time scale / Quit game, always on, with the layout named the way the file is named
#   The platform words on a CharacterBody, including the two the sign of a vertical speed means
#        the OPPOSITE of in 3D
#   The layout edges and the on-screen question
#
# Three gates, in the order they matter:
#   1. the grammar's own values - one shape, one sentence, asserted literally;
#   2. the whole path - a hand-written file opened as a sheet, walked row by row, so a reading that
#      stops reaching the canvas is caught even when the grammar still answers on its own;
#   3. the promise every one of these rests on - the file still saves byte-identically, because all
#      of them are lenses over values the row already holds.
#
# The source lives here as a string rather than in tests/fixtures/ for the same reason its sibling
# reading tests' sources do: the lifter's byte gate compares against what the COMPILER would emit,
# and the compiler puts ONE blank line between functions, so a checked-in two-blank-line file could
# never lift and the fixture would silently test nothing.

const SOURCE_PATH := "user://eventforge_reading_words7.gd"

const SOURCE: String = """extends CharacterBody2D

var hp: int = 3
var max_hp: int = 10
var last_shot: int = 0
var started: float = 0.0
var target_angle: float = 0.0

func _physics_process(delta: float) -> void:
	if is_on_floor():
		hp = 3
	if is_on_ceiling():
		hp = 2
	if velocity.x != 0:
		hp = 1
	if Time.get_ticks_msec() - last_shot > 500:
		last_shot = Time.get_ticks_msec()
	if 0 < hp and hp < max_hp:
		hp = 5
	if abs(angle_difference(rotation, target_angle)) < deg_to_rad(10):
		hp = 6
	if position.distance_to(Vector2.ZERO) < 100:
		hp = 7
	if Rect2(0, 0, 640, 360).has_point(position):
		hp = 8
	if is_zero_approx(velocity.length()):
		hp = 9
	if position.x < 0 or position.x > get_viewport_rect().size.x:
		hp = 10
	if randf() < 0.3:
		hp = 11
	get_tree().paused = true
	Engine.time_scale = 0.5
	get_tree().change_scene_to_file("res://levels/level_2.tscn")
	get_tree().reload_current_scene()
	get_tree().quit()
"""

## Every reading the opened file must contain, one per shape this batch claims.
static var EXPECTED_READINGS: PackedStringArray = PackedStringArray([
	# The platform words, on a body
	"CharacterBody2D ▸ Is on floor",
	"CharacterBody2D ▸ Is touching ceiling",
	"CharacterBody2D ▸ Is moving",
	# The cooldown idiom, both halves. The name lens spells the variables as words on the
	# canvas, which is why these read "last shot" where the grammar's own answer says "last_shot".
	"System ▸ 0.5 seconds have passed since last shot",
	"System ▸ Set last shot to now",
	# One condition per question
	"CharacterBody2D ▸ angle is within 10° of target angle",
	"CharacterBody2D ▸ is within 100 of (0, 0)",
	"CharacterBody2D ▸ is inside area 0, 0 - 640 × 360",
	"CharacterBody2D ▸ speed is about 0 (not moving)",
	# The layout edge. The `or` of the two edges arrives as two lifted conditions (the
	# importer files each comparison as its own row), so the reading - both edges
	# collapsed into one line - is what a test written on the raw condition text gets; here the
	# right-hand edge is the one this file proves reaches the canvas.
	"CharacterBody2D ▸ Is outside layout (right)",
	# A roll under a probability
	"System ▸ 30% chance",
	# The scene-flow words, always on
	"System ▸ Pause the game",
	"System ▸ Set time scale to 0.5",
	"System ▸ Go to layout Level 2",
	"System ▸ Restart layout",
	"System ▸ Quit game"
])

## Readings the file must NOT contain: the words each shape replaced. A reading that silently stops
## firing would otherwise pass the list above by never being asked about.
static var FORBIDDEN_READINGS: PackedStringArray = PackedStringArray([
	"CharacterBody2D ▸ Is by ceiling",
	"System ▸ Set last_shot to time in ms",
	"System ▸ Go to scene \"res://levels/level_2.tscn\"",
	"System ▸ Set time scale to 0 (pause)"
])

## The condition readings the grammar must answer on its own, as "object ▸ sentence".
static var CONDITION_READINGS: Dictionary = {
	# The four spellings of a range, and the notes that say which end is left out
	"x >= 0 and x <= width": "System ▸ x is between 0 and width",
	"0 < hp and hp < max_hp": "Player ▸ hp is between 0 and max_hp (exclusive)",
	"level in range(3, 6)": "System ▸ level is between 3 and 5",
	"hour >= 9 and hour < 17": "System ▸ hour is between 9 and 17 (exclusive top)",
	"width >= x and x >= 0": "System ▸ x is between 0 and width",
	# Angles, in degrees, with the radians the file holds one hover away
	"abs(angle_difference(rotation, target_angle)) < deg_to_rad(10)":
		"Player ▸ angle is within 10° of target_angle",
	"wrapf(a, 0, TAU) > deg_to_rad(30) and wrapf(a, 0, TAU) < deg_to_rad(60)":
		"System ▸ a is between angles 30° and 60°",
	"fmod(a, TAU) > deg_to_rad(30) and fmod(a, TAU) < deg_to_rad(60)":
		"System ▸ a is between angles 30° and 60°",
	"angle_difference(a, b) > 0": "System ▸ a is clockwise from b",
	# Distances, areas and approximate equality
	"position.distance_to(target) < 100": "Player ▸ is within 100 of target",
	"position.distance_squared_to(target) < r * r": "Player ▸ is within r of target",
	"Rect2(0, 0, 640, 360).has_point(position)": "Player ▸ is inside area 0, 0 - 640 × 360",
	"is_equal_approx(speed, 0.0)": "System ▸ speed is about 0",
	"is_zero_approx(velocity.length())": "Player ▸ speed is about 0 (not moving)",
	"absf(a - b) < 0.001": "System ▸ a is about b",
	# The two clocks
	"Time.get_ticks_msec() - last_shot > 500": "System ▸ 0.5 seconds have passed since last_shot",
	"Time.get_unix_time_from_system() - started > 60":
		"System ▸ 60 seconds have passed since started (clock time)",
	# The platform words
	"is_on_floor()": "Player ▸ Is on floor",
	"is_on_wall()": "Player ▸ Is by wall",
	"is_on_ceiling()": "Player ▸ Is touching ceiling",
	"velocity.y < 0": "Player ▸ Is jumping",
	"velocity.y > 0": "Player ▸ Is falling",
	"velocity.x != 0": "Player ▸ Is moving",
	# The layout edges and the screen
	"position.x < 0 or position.x > get_viewport_rect().size.x":
		"Player ▸ Is outside layout (left or right)",
	"position.y < 0": "Player ▸ Is outside layout (top)",
	"get_viewport().get_visible_rect().has_point(global_position)": "Player ▸ Is on-screen",
	"not get_viewport_rect().has_point(position)": "Player ▸ Is outside layout"
}

## The statements whose sentence this batch settles, as "object ▸ sentence".
static var STATEMENT_READINGS: Dictionary = {
	"last_shot = Time.get_ticks_msec()": "Player ▸ Set last_shot to now",
	# Re-pin: the wall clock has a NAME of its own in the sheet now - the Date object's Now - so a
	# variable filled from it says that, and the whole Date family reads alike. The game's own running
	# clock above keeps "now", because no Date expression stands for a number that restarts with the game.
	"started = Time.get_unix_time_from_system()": "Player ▸ Set started to Date.Now",
	"get_tree().change_scene_to_file(\"res://levels/level_2.tscn\")": "System ▸ Go to layout Level 2",
	"get_tree().reload_current_scene()": "System ▸ Restart layout",
	"get_tree().paused = true": "System ▸ Pause the game",
	"get_tree().paused = false": "System ▸ Unpause",
	"Engine.time_scale = 0.5": "System ▸ Set time scale to 0.5",
	"get_tree().quit()": "System ▸ Quit game"
}

## One Godot spelling, one sheet name, and what the same value reads as with the glossary off.
## The pairs are [with Familiar Words, without].
static var EXPRESSION_READINGS: Dictionary = {
	"a.position.distance_to(b.position)": ["distance(a, b)", "distance from a.position to b.position"],
	"a.get_angle_to(b.position)": ["angle(a, b)", "a.get_angle_to(b.position)"],
	"s.split(\",\")[i]": ["tokenat(s, i, \",\")", "split(s, \",\")[i]"],
	"s.length()": ["len(s)", "length of s"],
	"arr.size()": ["len(arr)", "arr' count"],
	"Engine.get_process_frames()": ["tickcount", "Engine.process_frames"],
	"randi_range(1, 6)": ["random(1, 6)", "random whole number 1 to 6"],
	"randf_range(0.5, 2.0)": ["random(0.5, 2)", "random number 0.5 to 2"],
	"randi() % n": ["random(n)", "randi() % n"],
	"[Color.RED, Color.BLUE].pick_random()": ["choose(red, blue)", "[red, blue].pick_random()"],
	"get_viewport_rect().size.x": ["ViewportWidth", "ViewportWidth"]
}


static func run() -> bool:
	var ok: bool = true
	ok = _grammar_values() and ok
	var readings: PackedStringArray = _open_and_read()
	for expected: String in EXPECTED_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	for forbidden: String in FORBIDDEN_READINGS:
		ok = _check("no row still reads \"%s\"" % forbidden, readings.has(forbidden), false) and ok
	ok = _round_trip() and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] reading_words7_test: %s" % label)
		return true
	print("[FAIL] reading_words7_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


## The sentence context an opened platformer script hands the grammar: the object the script is, the
## properties the engine reports on it, and the variables the sheet declares.
static func _context() -> Dictionary:
	return {
		"self_object": "Player",
		"script_object": "Player",
		"self_class": "CharacterBody2D",
		"engine_properties": {"position": true, "rotation": true, "velocity": true},
		"variable_types": {"hp": "int", "max_hp": "int", "last_shot": "int", "started": "float"}
	}


## Gate one: the grammar answering on its own, value by value. Everything here is pure, so a wrong
## answer is pinned to the one function that produced it rather than to the whole canvas.
static func _grammar_values() -> bool:
	var ok: bool = true
	var context: Dictionary = _context()
	for expression: String in CONDITION_READINGS:
		var reading: Dictionary = EventSheetSentence.condition_pieces(expression, context)
		ok = _check("condition %s" % expression, _joined_pieces(reading),
			str(CONDITION_READINGS[expression])) and ok
	for code: String in STATEMENT_READINGS:
		var reading: Dictionary = EventSheetSentence.statement(code, context)
		ok = _check("statement %s" % code, _joined_segments(reading),
			str(STATEMENT_READINGS[code])) and ok
	# The same value with the glossary on and off, so the table is pinned in both directions.
	var familiar: Dictionary = context.duplicate()
	familiar["familiar_words"] = true
	for value: String in EXPRESSION_READINGS:
		var pair: Array = EXPRESSION_READINGS[value]
		ok = _check("familiar %s" % value, EventSheetSentence.expression_text(value, familiar),
			str(pair[0])) and ok
		ok = _check("plain %s" % value, EventSheetSentence.expression_text(value, context),
			str(pair[1])) and ok
	# The vertical words follow the AXIS. The same test means the opposite in 3D, and a body is
	# the only thing they are claimed on at all.
	var body_3d: Dictionary = _context()
	body_3d["self_class"] = "CharacterBody3D"
	ok = _check("a 3D body rising reads as jumping",
		_joined_pieces(EventSheetSentence.condition_pieces("velocity.y > 0", body_3d)),
		"Player ▸ Is jumping") and ok
	ok = _check("a 3D body sinking reads as falling",
		_joined_pieces(EventSheetSentence.condition_pieces("velocity.y < 0", body_3d)),
		"Player ▸ Is falling") and ok
	var projectile: Dictionary = _context()
	projectile["self_class"] = "Node2D"
	ok = _check("a plain node's vertical speed is not a jump",
		_joined_pieces(EventSheetSentence.condition_pieces("velocity.y < 0", projectile)),
		"Player ▸ velocity.y < 0") and ok
	# The layout a path names, without the folder or the extension it is filed under.
	ok = _check("a scene path names its layout",
		EventSheetSentence.layout_name("\"res://levels/level_2.tscn\""), "Level 2") and ok
	ok = _check("a path that is not a literal keeps what it is",
		EventSheetSentence.layout_name("next_scene"), "next_scene") and ok
	return ok


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


## Writes the source, opens it as a sheet, and returns every cell reading - "object ▸ text" when the
## row names an object, the bare text otherwise.
static func _open_and_read() -> PackedStringArray:
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
	viewport.free()
	return readings


## Every row in the tree, parents before children - a folded parent's children read the same as an
## open one's, and what a row says must not depend on whether anything above it happens to be open.
static func _walk(rows: Array, viewport: EventSheetViewport) -> Array:
	var found: Array = []
	for row_data: EventRowData in rows:
		viewport._row_builder._ensure_event_spans(row_data)
		found.append(row_data)
		found.append_array(_walk(row_data.children, viewport))
	return found


## The promise every reading here rests on: each one is a lens over a value the row already holds,
## so opening the file and saving it untouched puts back every byte.
static func _round_trip() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)
