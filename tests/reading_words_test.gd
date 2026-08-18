@tool
class_name ReadingWordsTest
extends RefCounted

# Pins the Construct WORDS for the shapes an ordinary game script is full of (M25 - M33).
#
# Three gates, in the order they matter:
#   1. the grammar's own values - one shape, one sentence, asserted literally;
#   2. the whole path - a hand-written file opened as a sheet, walked row by row, so a reading that
#      stops reaching the canvas is caught even when the grammar still answers on its own;
#   3. the two promises the reading rests on - the file still saves byte-identically, and a row built
#      from the PICKER reads exactly what the same shape typed by hand reads.
#
# The source lives here as a string rather than in tests/fixtures/ for the same reason
# sentence_shapes_test's does: the lifter's byte gate compares against what the COMPILER would emit,
# and the compiler puts ONE blank line between functions, so a checked-in two-blank-line file could
# never lift and the fixture would silently test nothing.

const SOURCE_PATH := "user://eventforge_reading_words.gd"

const SOURCE: String = """class_name ReadingWordsPlayer
extends CharacterBody2D

var lives: int = 3
var label: String = ""
var inventory: Dictionary = {}
var items: Array = []
var speed: float = 100.0
var attacker: Node = null

## @ace_trigger
## @ace_name("On Damaged")
signal damaged(amount: int, source: Node)

func _ready() -> void:
	position.x = 100
	label = str(lives) + " lives"
	label = "Score: %d" % lives
	label = "%d / %d" % [lives, speed]
	lives = inventory["potion"]
	lives = items[0]
	lives = randi_range(1, 6)
	speed = randf_range(0.5, 2.0)
	speed = rad_to_deg(rotation)
	speed = snapped(speed, 0.5)
	lives = len(items)
	lives = items.size()
	print("ready")
	add_to_group("enemies")
	get_tree().call_group("enemies", "flee")
	create_tween().tween_property(self, "position", velocity, 0.3)
	damaged.emit(3, attacker)

func _physics_process(delta: float) -> void:
	velocity.x = speed * delta
	velocity = Input.get_vector("left", "right", "up", "down")
	for i in range(3):
		lives += i
		break
	for i in range(2, 8):
		continue
	while lives > 0:
		lives -= 1
	for child in get_children():
		child.queue_free()

func _process(delta: float) -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
"""

## Every reading the opened file must contain, one per shape M25 - M33 claims.
static var EXPECTED_READINGS: PackedStringArray = PackedStringArray([
	# M25 - the script's own object is named, engine properties read under it, globals are System
	"ReadingWordsPlayer ▸ Set X to 100",
	"System ▸ Print \"ready\"",
	# M27 - dt reaches a LIFTED row too, where the grammar's own rewriting never runs
	"System ▸ Set velocity X to speed * dt",
	# M31 - text joins with &, indexing reads possessively
	"System ▸ Set label to lives & \" lives\"",
	"System ▸ Set label to \"Score: \" & lives",
	"System ▸ Set label to lives & \" / \" & speed",
	"System ▸ Set lives to inventory's \"potion\"",
	"System ▸ Set lives to items' item 0",
	# M32 - the extended idiom table
	"System ▸ Set lives to random whole number 1 to 6",
	"System ▸ Set speed to random number 0.5 to 2",
	"System ▸ Set speed to rotation in degrees",
	"System ▸ Set speed to speed snapped to 0.5",
	"System ▸ Set lives to items' count",
	"ReadingWordsPlayer ▸ Tween position to velocity over 0.3s",
	# M30 - groups read as families, and the PICKED group row says the same words
	"enemies (group) ▸ Call Flee",
	# M28 - payload chips and the two tick waits
	"ReadingWordsPlayer ▸ Signal On Damaged   amount = 3   source = attacker",
	"System ▸ ⏳ Wait one tick",
	# M27 - the tick triggers in Construct's words
	"System ▸ Every tick (physics)",
	"System ▸ Every tick (draw)",
	# M33 - Construct's loop words
	"System ▸ Repeat 3 times (loopindex i)",
	"System ▸ For \"i\" from 2 to 7",
	"System ▸ While lives > 0",
	"System ▸ For each child child",
	"System ▸ Stop loop",
	"System ▸ Next",
	# M26 - any other call reads Object ▸ Verb, never verb ( args )
	"child ▸ Destroy"
])

## The grammar's own values, with the context an opened CharacterBody2D script produces.
const CONTEXT: Dictionary = {
	"self_object": "System",
	"script_object": "Player",
	"owner": "Player",
	"signals": {"damaged": "On Damaged"},
	"signal_params": {"damaged": ["amount", "source"]},
	"engine_properties": {"position": true, "rotation": true, "velocity": true, "visible": true}
}


static func run() -> bool:
	var ok: bool = true
	ok = _grammar_values() and ok
	ok = _condition_values() and ok
	ok = _call_readings() and ok
	ok = _loop_words() and ok
	ok = _opened_file_reads() and ok
	ok = _round_trip() and ok
	ok = _picked_matches_typed() and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] reading_words_test: %s" % label)
		return true
	print("[FAIL] reading_words_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


static func _joined(result: Dictionary) -> String:
	var text: String = ""
	for segment: Variant in (result.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	return text


static func _read(code: String) -> String:
	var result: Dictionary = EventSheetSentence.statement(code, CONTEXT)
	return "" if result.is_empty() else "%s ▸ %s" % [str(result.get("object", "")), _joined(result)]


static func _read_condition(expression: String) -> String:
	var result: Dictionary = EventSheetSentence.condition(expression, CONTEXT)
	return "" if result.is_empty() else "%s ▸ %s" % [str(result.get("object", "")), _joined(result)]


## M25 / M27 / M28 / M30 / M31 / M32 / M33 at the grammar's own level.
static func _grammar_values() -> bool:
	var ok: bool = true
	for pair: Array in [
		# M25 - the script's object, never `self`
		["position.x = 100", "Player ▸ Set X to 100"],
		["self.position.y = 100", "Player ▸ Set Y to 100"],
		["rotation += 1", "Player ▸ Add 1 to rotation"],
		["score += 1", "System ▸ Add 1 to score"],
		["self.queue_free()", "Player ▸ Destroy"],
		# M27 - delta is Construct's dt
		["velocity.x = speed * delta", "Player ▸ Set velocity.x to speed * dt"],
		["delta_time = 1", "System ▸ Set delta_time to 1"],
		# M28 - payload chips, the signal wait, the tick waits
		["damaged.emit(3, attacker)", "Player ▸ Signal On Damaged   amount = 3   source = attacker"],
		["await door.opened", "System ▸ ⏳ Wait for signal door On Opened"],
		["await get_tree().process_frame", "System ▸ ⏳ Wait one tick"],
		["await get_tree().physics_frame", "System ▸ ⏳ Wait one physics tick"],
		# M30 - groups as families
		["add_to_group(\"enemies\")", "Player ▸ Add to group \"enemies\""],
		["get_tree().call_group(\"enemies\", \"flee\")", "enemies (group) ▸ Call Flee"],
		["get_tree().call_group(\"enemies\", \"take_damage\", 3)", "enemies (group) ▸ Call Take damage   3"],
		# M31 - joins and indexing
		["label = str(lives) + \" lives\"", "System ▸ Set label to lives & \" lives\""],
		["label = \"you: \" + name_text", "System ▸ Set label to \"you: \" & name_text"],
		["label = \"Score: %d\" % score", "System ▸ Set label to \"Score: \" & score"],
		["label = \"%d / %d\" % [a, b]", "System ▸ Set label to a & \" / \" & b"],
		["count = inventory[\"potion\"]", "System ▸ Set count to inventory's \"potion\""],
		["first = items[0]", "System ▸ Set first to items' item 0"],
		["nth = items[i]", "System ▸ Set nth to items' item i"],
		["total = a + b", "System ▸ Set total to a + b"],
		# M32 - the extended idiom table
		["hp = randi_range(1, 6)", "System ▸ Set hp to random whole number 1 to 6"],
		["t = randf_range(0.5, 2.0)", "System ▸ Set t to random number 0.5 to 2"],
		["d = Input.get_vector(\"left\", \"right\", \"up\", \"down\")",
			"Keyboard ▸ Set d to input vector \"left\"/\"right\"/\"up\"/\"down\""],
		["p = global_position.direction_to(target)", "System ▸ Set p to direction from global_position to target"],
		["a = rad_to_deg(x)", "System ▸ Set a to x in degrees"],
		["s = snapped(v, 0.5)", "System ▸ Set s to v snapped to 0.5"],
		["n = len(items)", "System ▸ Set n to items' count"],
		["m = items.size()", "System ▸ Set m to items' count"],
		["create_tween().tween_property(host, \"position\", target, 0.3)",
			"host ▸ Tween position to target over 0.3s"],
		# M33 - the two loop steps
		["break", "System ▸ Stop loop"],
		["continue", "System ▸ Next"],
		# Refusals: a shape that is not recognised keeps its code rather than a confident lie
		["if ready:", ""],
		["await something.call_it()", ""]
	]:
		ok = _check("\"%s\" reads \"%s\"" % [str(pair[0]), str(pair[1])], _read(str(pair[0])), str(pair[1])) and ok
	return ok


## M25 / M30 in the condition lane.
static func _condition_values() -> bool:
	var ok: bool = true
	for pair: Array in [
		["rotation > 1.5", "Player ▸ rotation > 1.5"],
		["position.x <= 0", "Player ▸ X ≤ 0"],
		["visible", "Player ▸ visible is true"],
		["crouching", "System ▸ crouching is true"],
		["enemy.is_in_group(\"boss\")", "enemy ▸ is in group \"boss\""],
		["host == null", "host ▸ does not exist"]
	]:
		ok = _check("condition \"%s\" reads \"%s\"" % [str(pair[0]), str(pair[1])],
			_read_condition(str(pair[0])), str(pair[1])) and ok
	return ok


## M26 - Object ▸ Verb chips, and never a pair of parentheses.
static func _call_readings() -> bool:
	var ok: bool = true
	for entry: Array in [
		["$AnimatedSprite2D.play(\"run\")", PackedStringArray(["name"]), "AnimatedSprite2D ▸ Play   name = \"run\""],
		["$Path/To/Label.set_text(str(score))", PackedStringArray(["text"]), "Label ▸ Set text to score"],
		["print(\"ready\")", PackedStringArray(), "System ▸ Print   \"ready\""],
		["self.take_damage(3)", PackedStringArray(), "Player ▸ Take damage   3"],
		["enemy.queue_free()", PackedStringArray(), "enemy ▸ Destroy"]
	]:
		var code: String = str(entry[0])
		var reading: Dictionary = EventSheetSentence.statement(code, CONTEXT)
		if reading.is_empty():
			reading = EventSheetSentence.call_reading(code, CONTEXT, entry[1])
		var actual: String = "" if reading.is_empty() else "%s ▸ %s" % [str(reading.get("object", "")), _joined(reading)]
		ok = _check("call \"%s\" reads \"%s\"" % [code, str(entry[2])], actual, str(entry[2])) and ok
	ok = _check("a call sentence never shows parentheses",
		_joined(EventSheetSentence.call_reading("$Timer.start(2.0)", CONTEXT, PackedStringArray(["time_sec"]))).contains("("),
		false) and ok
	return ok


## M33 - the loop rows' words, straight off the row-level lens.
static func _loop_words() -> bool:
	var ok: bool = true
	for entry: Array in [
		[PickFilter.CollectionKind.REPEAT, "i", "10", "Repeat 10 times (loopindex i)", ""],
		[PickFilter.CollectionKind.REPEAT, "i", "2, 8", "For \"i\" from 2 to 7", ""],
		[PickFilter.CollectionKind.WHILE, "", "hp > 0", "While hp > 0", ""],
		[PickFilter.CollectionKind.EXPRESSION, "child", "host.get_children()", "For each child child", "host"],
		[PickFilter.CollectionKind.CHILDREN, "child", "", "For each child child", ""]
	]:
		var words: Dictionary = EventSheetViewportReadingRows.loop_words(int(entry[0]), str(entry[1]), str(entry[2]))
		ok = _check("loop \"%s\" reads \"%s\"" % [str(entry[2]), str(entry[3])],
			str(words.get("text", "")), str(entry[3])) and ok
		ok = _check("loop \"%s\" belongs to \"%s\"" % [str(entry[2]), str(entry[4])],
			str(words.get("object", "")), str(entry[4])) and ok
	ok = _check("a list loop keeps the plain For each reading",
		EventSheetViewportReadingRows.loop_words(PickFilter.CollectionKind.EXPRESSION, "x", "wave").is_empty(),
		true) and ok
	# M27 - the tick triggers, wording only: every other trigger keeps its own name.
	ok = _check("the physics trigger reads Construct's words",
		EventSheetViewportReadingRows.tick_trigger_words("OnPhysicsProcess", "Every Physics Tick"),
		"Every tick (physics)") and ok
	ok = _check("the frame trigger reads Construct's words",
		EventSheetViewportReadingRows.tick_trigger_words("OnProcess", "Every Frame"),
		"Every tick (draw)") and ok
	ok = _check("any other trigger keeps its own name",
		EventSheetViewportReadingRows.tick_trigger_words("OnReady", "On Ready"), "On Ready") and ok
	return ok


## The whole path: the file opened as a sheet, every row read off the canvas's own spans.
static func _opened_file_reads() -> bool:
	var ok: bool = true
	var readings: PackedStringArray = _render(_import())
	for expected: String in EXPECTED_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	return ok


static func _import() -> EventSheetResource:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	return GDScriptImporter.new().import_external(SOURCE_PATH)


## The readings of one sheet, straight off the canvas's own spans.
static func _render(sheet: EventSheetResource) -> PackedStringArray:
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
			var label: String = str(span.metadata.get("object_label", ""))
			var text: String = span.text.strip_edges()
			readings.append("%s ▸ %s" % [label, text] if not label.is_empty() else text)
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


## A reading may never cost a byte: opening the file and saving it untouched reproduces it exactly.
static func _round_trip() -> bool:
	var sheet: EventSheetResource = _import()
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)


## The parity promise for the shapes an ACE also has: a row dropped from the PICKER reads exactly
## what the same shape typed by hand reads.
static func _picked_matches_typed() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "ReadingWordsPlayer"
	sheet.host_class = "CharacterBody2D"
	var signal_row: SignalRow = SignalRow.new()
	signal_row.signal_name = "damaged"
	signal_row.ace_name = "On Damaged"
	signal_row.params.append("amount: int")
	signal_row.params.append("source: Node")
	sheet.events.append(signal_row)
	var event_row: EventRow = EventRow.new()
	event_row.trigger_id = "OnReady"
	event_row.actions.append(_action("EmitSignal", {"signal_name": "damaged", "args": "3, attacker"}))
	event_row.actions.append(_action("SetProperty", {"target": "self", "property": "position.x", "value": "100"}))
	event_row.actions.append(_action("CallMethod", {"target": "$AnimatedSprite2D", "method": "play", "args": "\"run\""}))
	sheet.events.append(event_row)
	var readings: PackedStringArray = _render(sheet)
	for expected: String in [
		"ReadingWordsPlayer ▸ Signal On Damaged   amount = 3   source = attacker",
		"ReadingWordsPlayer ▸ Set X to 100",
		"AnimatedSprite2D ▸ Play   name = \"run\""
	]:
		ok = _check("picked row reads \"%s\"" % expected, readings.has(expected), true) and ok
	return ok


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action
