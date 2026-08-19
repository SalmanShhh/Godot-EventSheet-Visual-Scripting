@tool
class_name ReadingWords4Test
extends RefCounted

# Pins the reading words for batch four's shapes (N5 - N11): what an object IS and HAS, the text and
# math expression names, saving / files / JSON, the behaviour words a body, a camera and an emitter
# read in, the input phases, and the debug verbs.
#
# Three gates, in the order they matter:
#   1. the grammar's own values - one shape, one sentence, asserted literally;
#   2. the whole path - a hand-written file opened as a sheet, walked row by row, so a reading that
#      stops reaching the canvas is caught even when the grammar still answers on its own;
#   3. the two promises the reading rests on - the file still saves byte-identically, and a row built
#      from the PICKER reads exactly what the same shape typed by hand reads.
#
# The source lives here as a string rather than in tests/fixtures/ for the same reason
# reading_words_test's does: the lifter's byte gate compares against what the COMPILER would emit, and
# the compiler puts ONE blank line between functions, so a checked-in two-blank-line file could never
# lift and the fixture would silently test nothing.

const SOURCE_PATH := "user://eventforge_reading_words4.gd"

const SOURCE: String = """@tool
class_name ReadingWords4Player
extends CharacterBody2D

var hp: int = 10
var label: String = ""
var inventory: Dictionary = {}
var wave: Array = []
var config: ConfigFile = ConfigFile.new()
var other: Node = null

@onready var ball: RigidBody2D = $Ball
@onready var lens: Camera2D = $Lens
@onready var sparks: GPUParticles2D = $Sparks

func _ready() -> void:
	label = label.to_upper()
	label = label.substr(0, 3)
	label = label.substr(2, 4)
	hp = label.length()
	label = label.strip_edges()
	label = "{0}: {1}".format([hp, label])
	hp = pow(hp, 2)
	wave = label.split(",")
	config.set_value("save", "score", hp)
	hp = config.get_value("save", "score", 0)
	config.save("user://save.cfg")
	label = JSON.stringify(inventory)
	inventory = JSON.parse_string(label)
	push_error("no target")
	push_warning(label)
	printerr(label)
	print_rich(label)
	assert(hp >= 0, "hp went negative")
	breakpoint

func _physics_process(_delta: float) -> void:
	ball.apply_impulse(velocity)
	ball.linear_velocity = velocity
	lens.zoom = Vector2(2, 2)
	lens.make_current()
	sparks.emitting = true
	sparks.restart()
	set_collision_mask_value(2, true)
	collision_layer = 0
	hp = Input.get_action_strength("gas")

func _process(_delta: float) -> void:
	if other is Node2D:
		hp += 1
	if "potion" in inventory:
		hp += 1
	if hp in [1, 2, 3]:
		hp += 1
	if other.has_method("take_damage"):
		hp += 1
	if has_node("Ball"):
		hp += 1
	if hp >= 10:
		hp = 0
	if FileAccess.file_exists("user://log.txt"):
		hp = 0
	if Input.is_action_just_released("jump"):
		hp = 0
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		hp = 0
	if label.begins_with("a"):
		hp = 0
	if label.contains("b"):
		hp = 0
"""

## Every reading the opened file must contain, one per shape N5 - N11 claims.
static var EXPECTED_READINGS: PackedStringArray = PackedStringArray([
	# N6 - text and math in the reader's own expression names
	"System ▸ Set label to uppercase(label)",
	"System ▸ Set label to left(label, 3)",
	"System ▸ Set label to mid(label, 2, 4)",
	"System ▸ Set hp to length of label",
	"System ▸ Set label to trim(label)",
	"System ▸ Set label to hp & \": \" & label",
	"System ▸ Set hp to hp ^ 2",
	"System ▸ Set wave to split(label, \",\")",
	# N7 - saving, files and JSON under the three objects that own them
	"Local Storage ▸ Set item save/score to hp",
	"System ▸ Set hp to Local Storage.Item(\"save/score\") (or 0)",
	"Local Storage ▸ Save \"save.cfg\"",
	"JSON ▸ Set label to JSON.ToString(inventory)",
	"JSON ▸ Set inventory to JSON.Parse(label)",
	# N8 - the behaviour words, by the object's known class
	"ball ▸ Physics  Apply impulse velocity",
	"ball ▸ Physics  Set velocity to velocity",
	"lens ▸ Set zoom to 200%",
	"lens ▸ Make current",
	"sparks ▸ Particles  Start spraying",
	"sparks ▸ Particles  Restart",
	"ReadingWords4Player ▸ Enable collisions with 2",
	"ReadingWords4Player ▸ Set collisions off",
	# N9 - the analogue read belongs to the pad, not to System
	"Gamepad ▸ Set hp to strength of \"gas\"",
	# N9 - the mouse question, and the release phase
	"Mouse ▸ left button is down",
	"Keyboard ▸ On \"jump\" released",
	# N5 - what an object is and has, and the comparison glyph
	"other ▸ is a Node2D",
	"System ▸ inventory has key \"potion\"",
	"System ▸ hp is one of 1, 2, 3",
	"other ▸ has function Take Damage",
	"ReadingWords4Player ▸ has child Ball",
	"System ▸ hp ≥ 10",
	# N6 - the two text questions, in the same words the value expressions read in
	"System ▸ label starts with \"a\"",
	"System ▸ label contains \"b\"",
	# N7 - the file test
	"File ▸ \"log.txt\" exists",
	# N11 - the debug verbs
	"System ▸ Log error \"no target\"",
	"System ▸ Log error label",
	"System ▸ Log warning label",
	"System ▸ Log label",
	"System ▸ Assert hp ≥ 0 \"hp went negative\""
])

## The grammar's own values, with the context an opened CharacterBody2D script produces.
const CONTEXT: Dictionary = {
	"self_object": "System",
	"script_object": "Player",
	"owner": "Player",
	"signals": {},
	"engine_properties": {
		"position": true, "rotation": true, "velocity": true, "visible": true,
		"collision_layer": true, "collision_mask": true
	},
	"object_classes": {
		"ball": "RigidBody2D", "lens": "Camera2D", "sparks": "GPUParticles2D",
		"Player": "CharacterBody2D"
	}
}


static func run() -> bool:
	var ok: bool = true
	ok = _statement_values() and ok
	ok = _condition_values() and ok
	ok = _expression_values() and ok
	ok = _refusals() and ok
	ok = _opened_file_reads() and ok
	ok = _breakpoint_row_wears_the_mark() and ok
	ok = _round_trip() and ok
	ok = _picked_matches_typed() and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] reading_words4_test: %s" % label)
		return true
	print("[FAIL] reading_words4_test: %s - expected %s, got %s" % [label, expected, actual])
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


## N7 / N8 / N11 in the action lane.
static func _statement_values() -> bool:
	var ok: bool = true
	for pair: Array in [
		# N7 - saving, files and JSON
		["config.set_value(\"save\", \"score\", score)",
			"Local Storage ▸ Set item save/score to score"],
		["s = config.get_value(\"save\", \"score\", 0)", "System ▸ Set s to Local Storage.Item(\"save/score\") (or 0)"],
		["s = config.get_value(\"save\", \"score\")", "System ▸ Set s to Local Storage.Item(\"save/score\")"],
		["config.save(\"user://save.cfg\")", "Local Storage ▸ Save \"save.cfg\""],
		["config.load(\"user://saves/slot1.cfg\")", "Local Storage ▸ Load \"slot1.cfg\""],
		["d = JSON.parse_string(text)", "JSON ▸ Set d to JSON.Parse(text)"],
		["t = JSON.stringify(d)", "JSON ▸ Set t to JSON.ToString(d)"],
		["f = FileAccess.open(\"user://log.txt\", FileAccess.WRITE)",
			"File ▸ Open \"log.txt\" for writing (as f)"],
		["var f = FileAccess.open(\"user://log.txt\", FileAccess.READ)",
			"File ▸ Open \"log.txt\" for reading (as f)"],
		["f.store_string(line)", "f ▸ Write line"],
		["t = f.get_as_text()", "System ▸ Set t to f's contents"],
		# N8 - the behaviour words, gated on the object's known class
		["ball.apply_impulse(dir * 300)", "ball ▸ Physics  Apply impulse dir * 300"],
		["ball.apply_force(push)", "ball ▸ Physics  Apply force push"],
		["ball.linear_velocity = v", "ball ▸ Physics  Set velocity to v"],
		["ball.angular_velocity = 2.0", "ball ▸ Physics  Set angular velocity to 2"],
		["lens.zoom = Vector2(2, 2)", "lens ▸ Set zoom to 200%"],
		["lens.make_current()", "lens ▸ Make current"],
		["sparks.emitting = true", "sparks ▸ Particles  Start spraying"],
		["sparks.emitting = false", "sparks ▸ Particles  Stop spraying"],
		["sparks.restart()", "sparks ▸ Particles  Restart"],
		["set_collision_mask_value(2, true)", "Player ▸ Enable collisions with 2"],
		["set_collision_layer_value(3, false)", "Player ▸ Set collision with layer 3 off"],
		["collision_layer = 0", "Player ▸ Set collisions off"],
		["collision_mask = 0", "Player ▸ Set collisions off"],
		# N9 - the analogue reads belong to the pad
		["s = Input.get_action_strength(\"gas\")", "Gamepad ▸ Set s to strength of \"gas\""],
		["s = Input.get_action_raw_strength(\"gas\")", "Gamepad ▸ Set s to raw strength of \"gas\""],
		["x = Input.get_axis(\"left\", \"right\")", "Keyboard ▸ Set x to axis \"left\"/\"right\""],
		# N11 - the debug verbs
		["push_error(\"no target\")", "System ▸ Log error \"no target\""],
		["printerr(x)", "System ▸ Log error x"],
		["push_warning(x)", "System ▸ Log warning x"],
		["print_rich(x)", "System ▸ Log x"],
		["assert(hp >= 0, \"hp went negative\")", "System ▸ Assert hp ≥ 0 \"hp went negative\""],
		["assert(hp > 0)", "System ▸ Assert hp > 0"]
	]:
		ok = _check("\"%s\" reads \"%s\"" % [str(pair[0]), str(pair[1])], _read(str(pair[0])), str(pair[1])) and ok
	return ok


## N5 / N7 / N9 in the condition lane.
static func _condition_values() -> bool:
	var ok: bool = true
	for pair: Array in [
		# N5 - what an object IS, what a table or a list HOLDS, what an object HAS
		["body is Player", "body ▸ is a Player"],
		["$Hurtbox is Area2D", "Hurtbox ▸ is a Area2D"],
		["\"potion\" in inventory", "System ▸ inventory has key \"potion\""],
		["x in [1, 2, 3]", "System ▸ x is one of 1, 2, 3"],
		["x in wave", "System ▸ wave contains x"],
		["body.has_method(\"take_damage\")", "body ▸ has function Take Damage"],
		["has_node(\"Sprite2D\")", "Player ▸ has child Sprite2D"],
		["$Hurtbox.has_node(\"Shape\")", "Hurtbox ▸ has child Shape"],
		# N5 - the two comparison glyphs, wherever a comparison is shown
		["rotation >= 1.5", "Player ▸ angle (radians) ≥ 1.5"],
		["position.x <= 0", "Player ▸ X ≤ 0"],
		["hp >= 10", " ▸ hp ≥ 10"],
		# N7 - the storage and file questions
		["config.has_section_key(\"save\", \"score\")", "Local Storage ▸ has item save/score"],
		["FileAccess.file_exists(\"user://logs/log.txt\")", "File ▸ \"log.txt\" exists"],
		# N9 - the release, the two InputEvent spellings, and the raw device questions
		["Input.is_action_just_released(\"jump\")", "Keyboard ▸ On \"jump\" released"],
		["event.is_action_pressed(\"pause\")", "Keyboard ▸ On \"pause\" pressed (this event)"],
		["event.is_action_released(\"pause\")", "Keyboard ▸ On \"pause\" released (this event)"],
		["Input.is_key_pressed(KEY_X)", "Keyboard ▸ X is down"],
		["Input.is_key_pressed(KEY_SPACE)", "Keyboard ▸ Space is down"],
		["Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)", "Mouse ▸ left button is down"]
	]:
		ok = _check("condition \"%s\" reads \"%s\"" % [str(pair[0]), str(pair[1])],
			_read_condition(str(pair[0])), str(pair[1])) and ok
	return ok


## N6 - the expression names a migrating reader types into a field.
static func _expression_values() -> bool:
	var ok: bool = true
	for pair: Array in [
		["name.to_upper()", "uppercase(name)"],
		["name.to_lower()", "lowercase(name)"],
		["text.substr(0, 3)", "left(text, 3)"],
		["text.substr(2, 4)", "mid(text, 2, 4)"],
		["text.right(4)", "right(text, 4)"],
		# M43 already reads `length()` as "length of x", which is the honest answer for a vector as
		# well as for text - so N6 defers to it rather than implying a count with `len(...)`.
		["text.length()", "length of text"],
		["text.find(\"x\")", "find(text, \"x\")"],
		["text.replace(\"a\", \"b\")", "replace(text, \"a\", \"b\")"],
		["text.strip_edges()", "trim(text)"],
		["text.split(\",\")", "split(text, \",\")"],
		["text.begins_with(\"a\")", "text starts with \"a\""],
		["text.ends_with(\"z\")", "text ends with \"z\""],
		["text.contains(\"b\")", "text contains \"b\""],
		["\"%s: %d\".format([a, b])", "a & \": \" & b"],
		["\"{0}: {1}\".format([a, b])", "a & \": \" & b"],
		["pow(x, 2)", "x ^ 2"],
		["int(x)", "int(x)"],
		["float(x)", "float(x)"],
		["a >= b", "a ≥ b"],
		["a <= b", "a ≤ b"],
		["a != b", "a ≠ b"],
		# A comparison INSIDE a literal is the user's own text, not an operator.
		["\"a >= b\"", "\"a >= b\""],
		# An idiom may never quietly drop an argument it was not given a place for.
		["text.find(\"x\", 3)", "text.find(\"x\", 3)"]
	]:
		ok = _check("expression \"%s\" reads \"%s\"" % [str(pair[0]), str(pair[1])],
			EventSheetSentence.expression_text(str(pair[0])), str(pair[1])) and ok
	return ok


## The refusals: a shape that is not recognised keeps its code rather than a confident lie.
static func _refusals() -> bool:
	var ok: bool = true
	for pair: Array in [
		# No known class means no behaviour words - a guess would put them on the wrong object.
		["crate.linear_velocity = v", "crate ▸ Set linear_velocity to v"],
		["crate.apply_impulse(v)", ""],
		# A camera squashed on one axis has no single percentage.
		["lens.zoom = Vector2(2, 1)", "lens ▸ Set zoom to (2, 1)"],
		# `save` on anything that is not plainly a settings file is not storage.
		["sprite.save(\"user://shot.png\")", ""],
		# A computed keycode has no letter to print.
		["breakpoint_at = 1", "System ▸ Set breakpoint_at to 1"]
	]:
		ok = _check("\"%s\" reads \"%s\"" % [str(pair[0]), str(pair[1])], _read(str(pair[0])), str(pair[1])) and ok
	ok = _check("a computed keycode is refused",
		_read_condition("Input.is_key_pressed(chosen_key)"), "") and ok
	ok = _check("a method name held in a variable is refused",
		_read_condition("body.has_method(wanted)"), "") and ok
	return ok


## The whole path: the file opened as a sheet, every row read off the canvas's own spans.
static func _opened_file_reads() -> bool:
	var ok: bool = true
	var readings: PackedStringArray = _render(_import())
	for expected: String in EXPECTED_READINGS:
		ok = _check("opened row reads \"%s\"" % expected, readings.has(expected), true) and ok
	return ok


## N11 - a bare `breakpoint` says nothing in words; the row wears the sheet's own mark instead.
static func _breakpoint_row_wears_the_mark() -> bool:
	var reading: Dictionary = EventSheetSentence.statement("\tbreakpoint", CONTEXT)
	var ok: bool = _check("a bare breakpoint is claimed", bool(reading.get("breakpoint", false)), true)
	ok = _check("a bare breakpoint says nothing in words", _joined(reading).strip_edges(), "") and ok
	ok = _check("only a BARE breakpoint is claimed",
		bool(EventSheetSentence.statement("breakpoint()", CONTEXT).get("breakpoint", false)), false) and ok
	# The whole path: the row the opened file builds wears the mark, not just the grammar's answer.
	ok = _check("the opened row wears the mark", _marked_rows(_import()), 1) and ok
	return ok


## How many rows of an opened sheet wear the breakpoint mark. The fixture holds exactly one bare
## `breakpoint`, and no view state is in play, so any other count means the flag reached the wrong row.
static func _marked_rows(sheet: EventSheetResource) -> int:
	sheet.read_only = true
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var marked: int = 0
	for row_data: EventRowData in _walk(viewport._root_rows, viewport):
		if row_data.breakpoint_enabled:
			marked += 1
	viewport.free()
	return marked


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
	sheet.custom_class_name = "ReadingWords4Player"
	sheet.host_class = "CharacterBody2D"
	var event_row: EventRow = EventRow.new()
	event_row.trigger_id = "OnReady"
	event_row.conditions.append(_condition("FileExists", {"path": "\"user://logs/log.txt\""}))
	event_row.conditions.append(_condition("IsActionJustReleased", {"action": "\"jump\""}))
	event_row.actions.append(_action("PushError", {"message": "\"no target\""}))
	event_row.actions.append(_action("PushWarning", {"message": "\"check this\""}))
	event_row.actions.append(_action("PrintRich", {"value": "\"done\""}))
	event_row.actions.append(_action("Assert", {"condition": "hp >= 0", "message": "\"hp went negative\""}))
	sheet.events.append(event_row)
	var readings: PackedStringArray = _render(sheet)
	for expected: String in [
		"File ▸ \"log.txt\" exists",
		"Keyboard ▸ On \"jump\" released",
		"System ▸ Log error \"no target\"",
		"System ▸ Log warning \"check this\"",
		"System ▸ Log \"done\"",
		"System ▸ Assert hp ≥ 0 \"hp went negative\""
	]:
		ok = _check("picked row reads \"%s\"" % expected, readings.has(expected), true) and ok
	return ok


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	return action


static func _condition(ace_id: String, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	return condition
