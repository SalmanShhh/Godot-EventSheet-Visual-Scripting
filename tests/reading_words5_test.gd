@tool
class_name ReadingWords5Test
extends RefCounted

# Pins the reading words for batch five's shapes (P6 / P8 / P9 / P11): the wait-then, the tick
# switches and the process mode, the question a @tool script asks about itself, the drawing verbs, the
# lifecycle and notification trigger names, and the named argument chips.
#
# Four gates, in the order they matter:
#   1. the grammar's own values - one shape, one sentence, asserted literally;
#   2. the trigger words on their own, which is where P8 and P9 live (the trigger ids themselves are
#      the structure's business; what they SAY is this file's);
#   3. the whole path - two hand-written files opened as sheets, walked row by row, so a reading that
#      stops reaching the canvas is caught even when the grammar still answers on its own;
#   4. the two promises the reading rests on - the files still save byte-identically, and a row built
#      from the PICKER reads exactly what the same shape typed by hand reads.
#
# The two sources are checked-in fixtures rather than strings, because P9's whole question is whether
# the opened file is the script the SCENE carries: `opened_script_words5_root.gd` is the root script of
# `opened_script_words5_root.tscn`, and `opened_script_words5_part.gd` sits on a CHILD node of that same
# scene, which is exactly the two cases P9 splits on.

const ROOT_PATH := "res://tests/fixtures/opened_script_words5_root.gd"
const PART_PATH := "res://tests/fixtures/opened_script_words5_part.gd"

## The context an opened CharacterBody2D script called Player produces.
const CONTEXT: Dictionary = {
	"self_object": "System",
	"script_object": "Player",
	"owner": "Player",
	"signals": {},
	"engine_properties": {"position": true, "visible": true},
	"object_classes": {"Player": "CharacterBody2D", "sprite": "AnimatedSprite2D"}
}

## Every reading the opened ROOT file must contain. Its object is "Node2D": the file declares no
## class_name, so the class it extends is the only name anybody calls that object by.
static var ROOT_READINGS: PackedStringArray = PackedStringArray([
	# P9 - the script the SCENE carries, so its _ready is the layout starting
	"System ▸ On start of layout",
	# P6 - the question a @tool script asks about itself
	"System ▸ is in the editor",
	# P6 - the tick switches and the process mode
	"Node2D ▸ Set Every tick (physics) deactivated",
	"Node2D ▸ Set Every tick (draw) activated",
	"Node2D ▸ Set input deactivated",
	"Node2D ▸ Set disabled",
	# P6 - the wait, then the step that follows it
	"System ▸ ⏳ Wait 2 seconds then Call Explode",
	# P8 - the drawing verbs
	"Node2D ▸ Draw line (0, 0) to (100, 0), red",
	"Node2D ▸ Draw rectangle Rect2(0, 0, 10, 10), blue",
	"Node2D ▸ Draw circle at (4, 4), radius 2, green",
	"Node2D ▸ Redraw",
	# P11 - named chips on an emit, on one of the sheet's own functions, and on the optional
	# engine argument that had none
	"System ▸ Signal On Hit   damage = 3",
	"sprite ▸ Set animation to \"burst\" (play)   speed = 2"
])

## And the PART file, which sits on a child node of the same scene: its _ready is that object being
## created, not the layout opening.
static var PART_READINGS: PackedStringArray = PackedStringArray([
	"CharacterBody2D ▸ On created"
])


static func run() -> bool:
	var ok: bool = true
	ok = _statement_values() and ok
	ok = _condition_values() and ok
	ok = _refusals() and ok
	ok = _lifecycle_trigger_words() and ok
	ok = _notification_trigger_words() and ok
	ok = _opened_files_read() and ok
	ok = _round_trip() and ok
	ok = _picked_matches_typed() and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] reading_words5_test: %s" % label)
		return true
	print("[FAIL] reading_words5_test: %s - expected %s, got %s" % [label, expected, actual])
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


## P6 / P8 / P11 in the action lane.
static func _statement_values() -> bool:
	var ok: bool = true
	for pair: Array in [
		# P6 - switching a tick on and off is the sheet's own activation, said about a tick
		["set_physics_process(false)", "Player ▸ Set Every tick (physics) deactivated"],
		["set_process(true)", "Player ▸ Set Every tick (draw) activated"],
		["set_process_input(false)", "Player ▸ Set input deactivated"],
		["set_process_unhandled_input(true)", "Player ▸ Set unhandled input activated"],
		["$Hurtbox.set_physics_process(false)", "Hurtbox ▸ Set Every tick (physics) deactivated"],
		# P6 - the process mode, in both of Godot's spellings
		["process_mode = PROCESS_MODE_DISABLED", "Player ▸ Set disabled"],
		["process_mode = PROCESS_MODE_INHERIT", "Player ▸ Set enabled"],
		["process_mode = Node.PROCESS_MODE_ALWAYS", "Player ▸ Set always active"],
		["process_mode = PROCESS_MODE_PAUSABLE", "Player ▸ Set pausable"],
		["process_mode = PROCESS_MODE_WHEN_PAUSED", "Player ▸ Set active only when paused"],
		# P6 - the wait, then the step that runs when it ends
		["get_tree().create_timer(2.0).timeout.connect(func(): explode())",
			"System ▸ ⏳ Wait 2 seconds then Call Explode"],
		["get_tree().create_timer(0.5).timeout.connect(explode)",
			"System ▸ ⏳ Wait 0.5 seconds then Call Explode"],
		["get_tree().create_timer(1.0).timeout.connect(func(): hp = 0)",
			"System ▸ ⏳ Wait 1 seconds then Set hp to 0"],
		["get_tree().create_timer(0.15).timeout.connect(func(): queue_free(), CONNECT_ONE_SHOT)",
			"System ▸ ⏳ Wait 0.15 seconds then Player  Destroy"],
		# P8 - the drawing verbs
		["draw_line(Vector2(0, 0), Vector2(100, 0), Color.RED)",
			"Player ▸ Draw line (0, 0) to (100, 0), red"],
		["draw_rect(box, Color.BLUE)", "Player ▸ Draw rectangle box, blue"],
		["draw_circle(Vector2(4, 4), 2.0, Color.GREEN)",
			"Player ▸ Draw circle at (4, 4), radius 2, green"],
		["queue_redraw()", "Player ▸ Redraw"],
		# P11 - the optional engine argument that used to have no name
		["sprite.play(\"run\", 2.0)", "sprite ▸ Set animation to \"run\" (play)   speed = 2"],
		["sprite.play(\"run\")", "sprite ▸ Set animation to \"run\" (play)"]
	]:
		ok = _check("\"%s\" reads \"%s\"" % [str(pair[0]), str(pair[1])], _read(str(pair[0])), str(pair[1])) and ok
	return ok


## P6 in the condition lane: one question, whichever of Godot's two spellings asked it.
static func _condition_values() -> bool:
	var ok: bool = true
	for pair: Array in [
		["Engine.is_editor_hint()", "System ▸ is in the editor"],
		["OS.has_feature(\"editor\")", "System ▸ is in the editor"]
	]:
		ok = _check("condition \"%s\" reads \"%s\"" % [str(pair[0]), str(pair[1])],
			_read_condition(str(pair[0])), str(pair[1])) and ok
	return ok


## The refusals. Every one of these is a shape that ALMOST fits, and a sentence that almost fits is
## worse than the code it replaced - so the line keeps its GDScript instead.
static func _refusals() -> bool:
	var ok: bool = true
	# A switch whose value is a variable is in whichever state that variable holds; no row can say.
	ok = _check("a computed tick switch is refused", _read("set_process(enabled)"), "") and ok
	# A bound callable is not one step this grammar can name, so the whole wait keeps its code.
	ok = _check("a bound callback is refused",
		_read("get_tree().create_timer(1.0).timeout.connect(spawn.bind(3))"), "") and ok
	# A repeating connection is not a one-shot wait, and reading it as one would lose the repetition.
	# U10 gave it the sentence it does have - wiring a handler up is an ACTION - so the pin is that it
	# reads as the wiring it is and never as the wait it is not.
	ok = _check("a plain signal connect is a wiring, not a wait",
		_read("$Timer.timeout.connect(explode)"), "Timer ▸ Wire On Timeout to Explode") and ok
	# A line whose colour argument has a width behind it would have to drop the width to read.
	ok = _check("a drawn line with a width is refused",
		_read("draw_line(a, b, Color.RED, 4.0)"), "") and ok
	# Three arguments is a different verb (`play(name, speed, from_end)`), not this sentence.
	ok = _check("a three-argument play is refused",
		_read("sprite.play(\"run\", 2.0, true)"), "") and ok
	# An unknown process mode has no word of its own, so the row stays the property write it is.
	ok = _check("an unknown process mode keeps the plain set",
		_read("process_mode = wanted"), "System ▸ Set process_mode to wanted") and ok
	return ok


## P8 / P9 - the lifecycle trigger words, and who each belongs to. The trigger ids are the structure's
## business; these are the words, which is what a reader actually meets.
static func _lifecycle_trigger_words() -> bool:
	var ok: bool = true
	for row: Array in [
		# P9 - the same trigger id, the two answers the scene decides between
		["OnReady", true, "On start of layout", "System"],
		["OnReady", false, "On created", "Player"],
		["OnExitTree", true, "On end of layout", "System"],
		["OnExitTree", false, "On destroyed", "Player"],
		# P8 - the rest read the same wherever the script sits
		["OnEnterTree", true, "On created", "Player"],
		["OnEnterTree", false, "On created", "Player"],
		["OnDraw", false, "On draw", "Player"]
	]:
		var reading: Dictionary = EventSheetViewportReadingRows.lifecycle_trigger_reading(
			str(row[0]), "Whatever", bool(row[1]), "Player")
		ok = _check("%s (scene root %s) reads \"%s\"" % [str(row[0]), str(row[1]), str(row[2])],
			str(reading.get("text", "")), str(row[2])) and ok
		ok = _check("%s (scene root %s) belongs to %s" % [str(row[0]), str(row[1]), str(row[3])],
			str(reading.get("object", "")), str(row[3])) and ok
	# A script with no name of its own keeps whatever label the row already had.
	ok = _check("a nameless script keeps the row's own object",
		str(EventSheetViewportReadingRows.lifecycle_trigger_reading(
			"OnReady", "Whatever", false, "").get("object", "")), "Whatever") and ok
	# Every other trigger is left exactly as it was.
	ok = _check("a tick trigger is not a lifecycle one",
		EventSheetViewportReadingRows.lifecycle_trigger_reading("OnProcess", "System", false, "Player"),
		{}) and ok
	return ok


## P8 - the notifications, in the sheet's words where it has them and in plain words where it does not.
static func _notification_trigger_words() -> bool:
	var ok: bool = true
	for pair: Array in [
		["NOTIFICATION_APPLICATION_PAUSED", "On suspended"],
		["NOTIFICATION_APPLICATION_RESUMED", "On resumed"],
		["NOTIFICATION_APPLICATION_FOCUS_OUT", "On lost focus"],
		["NOTIFICATION_APPLICATION_FOCUS_IN", "On gained focus"],
		["NOTIFICATION_WM_CLOSE_REQUEST", "On close"],
		["NOTIFICATION_PAUSED", "On paused"],
		["NOTIFICATION_UNPAUSED", "On unpaused"],
		["NOTIFICATION_PREDELETE", "On destroyed"],
		# One the sheet has no word for still says what happened, in words rather than in a constant.
		["NOTIFICATION_WM_MOUSE_ENTER", "On wm mouse enter"]
	]:
		ok = _check("%s reads \"%s\"" % [str(pair[0]), str(pair[1])],
			EventSheetViewportReadingRows.notification_trigger_words(str(pair[0])), str(pair[1])) and ok
	# And the whole trigger id, the way a lifted row carries it.
	var reading: Dictionary = EventSheetViewportReadingRows.lifecycle_trigger_reading(
		"OnNotification:NOTIFICATION_WM_CLOSE_REQUEST", "Player", false, "Player")
	ok = _check("a notification trigger reads its words", str(reading.get("text", "")), "On close") and ok
	ok = _check("a notification belongs to System", str(reading.get("object", "")), "System") and ok
	return ok


## The whole path: both files opened as sheets, every row read off the canvas's own spans.
static func _opened_files_read() -> bool:
	var ok: bool = true
	var root_readings: PackedStringArray = _render(_import(ROOT_PATH))
	for expected: String in ROOT_READINGS:
		ok = _check("the scene's own script reads \"%s\"" % expected, root_readings.has(expected), true) and ok
	var part_readings: PackedStringArray = _render(_import(PART_PATH))
	for expected: String in PART_READINGS:
		ok = _check("a script on an object reads \"%s\"" % expected, part_readings.has(expected), true) and ok
	# And the two must NOT read each other's words - that split is the whole of P9.
	ok = _check("only the scene's own script starts the layout",
		part_readings.has("System ▸ On start of layout"), false) and ok
	return ok


static func _import(path: String) -> EventSheetResource:
	return GDScriptImporter.new().import_external(path)


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


## A reading may never cost a byte: opening each file and saving it untouched reproduces it exactly.
static func _round_trip() -> bool:
	var ok: bool = true
	for path: String in [ROOT_PATH, PART_PATH]:
		var handle: FileAccess = FileAccess.open(path, FileAccess.READ)
		var source: String = handle.get_as_text() if handle != null else ""
		if handle != null:
			handle.close()
		var output: String = str(SheetCompiler.compile(_import(path), path).get("output", ""))
		ok = _check("%s saves every byte back" % path.get_file(), output, source) and ok
	return ok


## The parity promise: a row dropped from the PICKER reads exactly what the same shape typed by hand
## reads - which for these shapes is the whole point, because each of them has an ACE of its own.
static func _picked_matches_typed() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Player"
	sheet.host_class = "CharacterBody2D"
	var event_row: EventRow = EventRow.new()
	event_row.trigger_id = "OnReady"
	event_row.conditions.append(_condition("IsInEditor", {}))
	event_row.actions.append(_action("NodeSetPhysicsProcessing", {"on": "false"}))
	event_row.actions.append(_action("NodeSetProcessing", {"on": "true"}))
	event_row.actions.append(_action("NodeSetInputProcessing", {"on": "false"}))
	event_row.actions.append(_action("NodeSetProcessMode", {"mode": "Node.PROCESS_MODE_DISABLED"}))
	event_row.actions.append(_action("CallAfterDelay", {"seconds": "2.0", "callable": "explode"}))
	sheet.events.append(event_row)
	var readings: PackedStringArray = _render(sheet)
	for expected: String in [
		# P9 - a sheet that is nobody's scene root reads its _ready as its object being created
		"Player ▸ On created",
		"System ▸ is in the editor",
		"Player ▸ Set Every tick (physics) deactivated",
		"Player ▸ Set Every tick (draw) activated",
		"Player ▸ Set input deactivated",
		"Player ▸ Set disabled",
		"System ▸ ⏳ Wait 2 seconds then Call Explode"
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
