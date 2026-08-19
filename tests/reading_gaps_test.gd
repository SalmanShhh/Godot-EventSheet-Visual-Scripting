@tool
class_name ReadingGapsTest
extends RefCounted

# Pins the five reading gaps batch eleven closed - the families of line a finished Godot game is
# full of that an event sheet already has words for:
#
#   V1  a RigidBody IS the Physics behavior: mass, gravity scale, the material's friction and
#       elasticity, the pushes, immovable, sleeping, damping, the joints, an area's world gravity
#   V2  the Controls a form is made of: Text input, List, Check box, File chooser, Tabs, and the
#       two formatted-text verbs
#   V3  a PathFollow IS the Follow a Path behavior
#   V6  the text words: the named format, zeropad, capitalised, and the regular expressions
#   V7  the numbers a profiling script reads by name, and the wait that freezes the game
#
# Four gates, in the order they matter:
#   1. the grammar's own values - one shape, one sentence, asserted literally;
#   2. the facts the file states about itself, which several of the readings are gated on;
#   3. the whole path - a hand-written file opened as a sheet, walked row by row, so a reading that
#      stops reaching the canvas is caught even when the grammar still answers on its own;
#   4. the promise every one of them rests on - the file still saves byte-identically.
#
# The source lives here as a string rather than in tests/fixtures/ for the same reason its sibling
# reading tests' sources do: the lifter's byte gate compares against what the COMPILER would emit,
# and the compiler puts ONE blank line between functions, so a checked-in two-blank-line file could
# never lift and the fixture would silently test nothing.

const SOURCE_PATH := "user://eventforge_reading_gaps.gd"

const SOURCE: String = """extends RigidBody2D

@export var kick: float = 400.0
var mat: PhysicsMaterial = PhysicsMaterial.new()
var frames: int = 0

func _ready() -> void:
	mass = 2.0
	gravity_scale = 0.5
	mat.friction = 0.8
	mat.bounce = 0.3
	physics_material_override = mat
	linear_damp = 2.0

func _on_hit(dir: Vector2) -> void:
	apply_torque_impulse(10)
	apply_impulse(dir * kick, Vector2(0, 10))
	freeze = true
	frames = Engine.get_frames_drawn()
	OS.delay_msec(500)
"""

## V1. The physics statements, as "object ▸ sentence". Each is claimed only on a body the sheet
## KNOWS is one, which the last two gates below check by asking a plain node the same questions.
static var PHYSICS_STATEMENTS: Dictionary = {
	"mass = 2.0": "Crate ▸ Physics  Set mass to 2",
	"gravity_scale = 0.5": "Crate ▸ Physics  Set gravity scale to 0.5",
	"mat.friction = 0.8": "Crate ▸ Physics  Set friction to 0.8",
	"mat.bounce = 0.3": "Crate ▸ Physics  Set elasticity to 0.3",
	"physics_material_override.friction = 0.8": "Crate ▸ Physics  Set friction to 0.8",
	"physics_material_override = mat": "Crate ▸ Physics  Use physics material mat",
	"linear_damp = 2.0": "Crate ▸ Physics  Set linear damping to 2",
	"angular_damp = 1.0": "Crate ▸ Physics  Set angular damping to 1",
	"freeze = true": "Crate ▸ Physics  Set immovable",
	"freeze = false": "Crate ▸ Physics  Set movable",
	"apply_torque(5)": "Crate ▸ Physics  Apply torque 5",
	"apply_torque_impulse(10)": "Crate ▸ Physics  Apply torque impulse 10",
	"apply_impulse(dir * kick, Vector2(0, 10))": "Crate ▸ Physics  Apply impulse dir * kick at (0, 10)",
	"apply_force(push, Vector2(0, 4))": "Crate ▸ Physics  Apply force push at (0, 4)",
	"add_child(PinJoint2D.new())": "Crate ▸ Create revolute joint",
	"add_child(DampedSpringJoint2D.new())": "Crate ▸ Create distance joint",
	"add_child(GrooveJoint2D.new())": "Crate ▸ Create prismatic joint",
	"zone.gravity = 200": "zone ▸ Physics  Set world gravity to 200"
}

## V1. The two questions a body answers.
static var PHYSICS_CONDITIONS: Dictionary = {
	"sleeping": "Crate ▸ Physics  Is sleeping",
	"not sleeping": "Crate ▸ Physics  Is awake",
	"freeze": "Crate ▸ Physics  Is immovable"
}

## V2. The form's own words, one Control at a time.
static var UI_STATEMENTS: Dictionary = {
	"name_edit.placeholder_text = \"Your name\"":
		"name_edit ▸ Text input  Set placeholder to \"Your name\"",
	"name_edit.text = \"\"": "name_edit ▸ Text input  Set text to \"\"",
	"list.add_item(\"Sword\")": "list ▸ List  Add item \"Sword\"",
	"list.remove_item(0)": "list ▸ List  Remove item 0",
	"list.select(2)": "list ▸ List  Select item 2",
	"list.clear()": "list ▸ List  Clear",
	"tabs.current_tab = 1": "tabs ▸ Tabs  Switch to tab 1",
	"rich.append_text(\"[color=red]!\")": "rich ▸ Append formatted text \"[color=red]!\"",
	"mute.button_pressed = true": "mute ▸ Check box  Set checked",
	"chooser.popup_centered()": "chooser ▸ File chooser  Open",
	"tooltip_text = \"Heals 10 hp\"": "Inventory ▸ Set tooltip to \"Heals 10 hp\""
}

## V3. The path walk, in the Follow a Path behavior's words. The row belongs to the object that
## MOVES, not to the follower node that carries the distance.
static var PATH_STATEMENTS: Dictionary = {
	"follow.progress += speed * delta": "Enemy ▸ Follow a Path  Move along path at speed",
	"follow.progress = 0.0": "Enemy ▸ Follow a Path  Go to start",
	"follow.progress = half": "Enemy ▸ Follow a Path  Set distance along path to half",
	"follow.loop = false": "Enemy ▸ Follow a Path  Set looping off",
	"follow.rotates = true": "Enemy ▸ Follow a Path  Set rotate with path on",
	"curve.add_point(spot)": "Enemy ▸ Follow a Path  Add path point spot"
}

## V6 / V7. The values that read as one word, and the one statement that says what it costs.
static var VALUE_READINGS: Dictionary = {
	"Engine.get_frames_drawn()": "tickcount",
	"Engine.get_frames_per_second()": "fps",
	"Time.get_ticks_usec()": "now (microseconds)",
	"get_process_delta_time()": "dt",
	"get_physics_process_delta_time()": "dt",
	"RegEx.new()": "a pattern",
	"rx.search(text)": "first match of rx in text",
	"rx.search_all(text)": "all matches of rx in text",
	"rx.sub(text, \"#\")": "replace matches of rx in text with \"#\"",
	"int(m.get_string())": "int(the match)",
	"\"%s has %d hp\" % [name, hp]": "name & \" has \" & hp & \" hp\"",
	"\"{a} vs {b}\".format({\"a\": p1, \"b\": p2})": "\"{a} vs {b}\" with a = p1, b = p2",
	"str(score).pad_zeros(5)": "zeropad(score, 5)",
	"raw.capitalize()": "capitalised raw",
	"list.get_item_text(i)": "list.ItemText(i)"
}


static func run() -> bool:
	var ok: bool = true
	ok = _grammar_values() and ok
	ok = _strictness() and ok
	ok = _facts() and ok
	ok = _opened_file() and ok
	ok = _round_trip() and ok
	return ok


## Gate one: the grammar answering on its own, value by value.
static func _grammar_values() -> bool:
	var ok: bool = true
	var body: Dictionary = _physics_context()
	for code: String in PHYSICS_STATEMENTS:
		ok = _check("physics statement %s" % code,
			_joined_segments(EventSheetSentence.statement(code, body)),
			str(PHYSICS_STATEMENTS[code])) and ok
	for expression: String in PHYSICS_CONDITIONS:
		ok = _check("physics condition %s" % expression,
			_joined_pieces(EventSheetSentence.condition_pieces(expression, body)),
			str(PHYSICS_CONDITIONS[expression])) and ok
	var form: Dictionary = _ui_context()
	for code: String in UI_STATEMENTS:
		ok = _check("form statement %s" % code,
			_joined_segments(EventSheetSentence.statement(code, form)),
			str(UI_STATEMENTS[code])) and ok
	ok = _check("a check box's own question",
		_joined_pieces(EventSheetSentence.condition_pieces("mute.button_pressed", form)),
		"mute ▸ Check box  Is checked") and ok
	ok = _check("a formatted label keeps its tags",
		_joined_segments(EventSheetSentence.statement("rich.text = \"[b]Hi[/b] %s\" % player_name", form)),
		"rich ▸ Set formatted text to \"[b]Hi[/b] \" & player_name") and ok
	var route: Dictionary = _path_context()
	for code: String in PATH_STATEMENTS:
		ok = _check("path statement %s" % code,
			_joined_segments(EventSheetSentence.statement(code, route)),
			str(PATH_STATEMENTS[code])) and ok
	ok = _check("the one question a path walk asks",
		_joined_pieces(EventSheetSentence.condition_pieces("follow.progress_ratio >= 1.0", route)),
		"Enemy ▸ Follow a Path  Has reached the end") and ok
	var words: Dictionary = _text_context()
	for value: String in VALUE_READINGS:
		ok = _check("value %s" % value, EventSheetSentence.expression_text(value, words),
			str(VALUE_READINGS[value])) and ok
	ok = _check("a kept pattern is given its expression",
		_joined_segments(EventSheetSentence.statement("rx.compile(\"\\\\d+\")", words)),
		"Text ▸ Set pattern rx to \"\\d+\" regular expression") and ok
	ok = _check("a blocking delay says what it costs",
		_joined_segments(EventSheetSentence.statement("OS.delay_msec(500)", words)),
		"System ▸ Wait 0.5 seconds ⚠ blocks the game") and ok
	return ok


## Gate two: the strictness every one of these rests on. A member name means one thing on a body and
## another on anything else, so each reading is claimed only where the sheet KNOWS the class.
static func _strictness() -> bool:
	var ok: bool = true
	var plain: Dictionary = _physics_context()
	plain["self_class"] = "Node2D"
	plain["physics_materials"] = {}
	ok = _check("a plain node's mass is a variable",
		_joined_segments(EventSheetSentence.statement("mass = 2.0", plain)),
		"Crate ▸ Set mass to 2") and ok
	ok = _check("a plain node's friction is a property write",
		_joined_segments(EventSheetSentence.statement("mat.friction = 0.8", plain)),
		"mat ▸ Set friction to 0.8") and ok
	var route: Dictionary = _path_context()
	route["object_classes"] = {}
	ok = _check("a step nothing declared a path follower for keeps its arithmetic",
		_joined_segments(EventSheetSentence.statement("follow.progress += speed * delta", route)),
		"follow ▸ Add speed * dt to progress") and ok
	ok = _check("a path step that is not scaled by the frame time is not a speed",
		_joined_segments(EventSheetSentence.statement("follow.progress += 4", _path_context())),
		"follow ▸ Add 4 to progress") and ok
	ok = _check("half a path is a comparison, not an arrival",
		_joined_pieces(EventSheetSentence.condition_pieces("follow.progress_ratio >= 0.5",
			_path_context())), "follow.progress_ratio ≥ 0.5") and ok
	var words: Dictionary = _text_context()
	words["pattern_variables"] = {}
	ok = _check("a search on something no pattern was declared for keeps its call",
		EventSheetSentence.expression_text("rx.search(text)", words), "rx.search(text)") and ok
	ok = _check("a format whose keys the pattern never names keeps its call",
		EventSheetSentence.expression_text("\"{a} vs {b}\".format({\"a\": p1, \"c\": p2})",
			_text_context()), "\"{a} vs {b}\".format({\"a\": p1, \"c\": p2})") and ok
	return ok


## Gate three: the facts the FILE states about itself, which the material and pattern readings are
## gated on. Nothing here guesses - a variable filled from two different things is dropped, because
## the same word may not read two ways on one sheet.
static func _facts() -> bool:
	var ok: bool = true
	_write_source()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var facts: Dictionary = EventSheetViewportReadingRows.reading_gap_facts(sheet)
	ok = _check("the file's physics material is known by name",
		(facts.get("physics_materials", {}) as Dictionary).has("mat"), true) and ok
	ok = _check("nothing else was mistaken for a material",
		(facts.get("physics_materials", {}) as Dictionary).size(), 1) and ok
	ok = _check("a file with no regular expression declares no pattern",
		(facts.get("pattern_variables", {}) as Dictionary).size(), 0) and ok
	return ok


## Gate four: the same readings on the canvas, where the reader meets them.
static func _opened_file() -> bool:
	var ok: bool = true
	var readings: PackedStringArray = _open_and_read()
	var whole: String = "\n".join(readings)
	for expected: String in ["Set mass to 2", "Set gravity scale to 0.5", "Set friction to 0.8",
			"Set elasticity to 0.3", "Set linear damping to 2", "Apply torque impulse 10",
			"Set immovable", "tickcount", "blocks the game"]:
		ok = _check("the opened file reads \"%s\"" % expected, whole.contains(expected), true) and ok
	for forbidden: String in ["Set gravity_scale to 0.5", "Set freeze to true",
			"Set linear_damp to 2"]:
		ok = _check("no row still reads \"%s\"" % forbidden, whole.contains(forbidden), false) and ok
	# V7. The Doctor sees the same line the reading warns about, so the finding and the chip can
	# never disagree about which call blocks.
	ok = _check("the Doctor names the blocking wait",
		"|".join(EventSheetProjectDoctor.blocking_wait_calls(SOURCE)), "OS.delay_msec(500)") and ok
	ok = _check("a script with no blocking wait is not accused",
		EventSheetProjectDoctor.blocking_wait_calls("func _ready():\n\tpass\n").size(), 0) and ok
	return ok


## The promise every reading here rests on: each one is a lens over a value the row already holds,
## so opening the file and saving it untouched puts back every byte.
static func _round_trip() -> bool:
	_write_source()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)


static func _write_source() -> void:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()


## The sentence context a rigid body's script hands the grammar.
static func _physics_context() -> Dictionary:
	return {
		"self_object": "Crate", "script_object": "Crate", "self_class": "RigidBody2D",
		"object_classes": {"zone": "Area2D"},
		"physics_materials": {"mat": true},
		"engine_properties": {"mass": true, "gravity_scale": true, "freeze": true,
			"sleeping": true, "linear_damp": true, "angular_damp": true}
	}


## The sentence context a menu script hands the grammar.
static func _ui_context() -> Dictionary:
	return {
		"self_object": "Inventory", "script_object": "Inventory", "self_class": "Control",
		"object_classes": {
			"name_edit": "LineEdit", "list": "ItemList", "mute": "CheckBox",
			"tabs": "TabContainer", "rich": "RichTextLabel", "chooser": "FileDialog"
		},
		"engine_properties": {"tooltip_text": true}
	}


## The sentence context a patrolling enemy's script hands the grammar.
static func _path_context() -> Dictionary:
	return {
		"self_object": "Enemy", "script_object": "Enemy", "self_class": "Node2D",
		"object_classes": {"follow": "PathFollow2D", "curve": "Curve2D"}
	}


## The sentence context a HUD script hands the grammar, with the glossary on - `zeropad` and
## `capitalised` are Familiar Words, exactly as `left` and `mid` already are.
static func _text_context() -> Dictionary:
	return {
		"self_object": "HUD", "script_object": "HUD", "self_class": "Node",
		"familiar_words": true,
		"pattern_variables": {"rx": true},
		"match_variables": {"m": true},
		"object_classes": {"list": "ItemList"}
	}


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] reading_gaps_test: %s" % label)
		return true
	print("[FAIL] reading_gaps_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


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
