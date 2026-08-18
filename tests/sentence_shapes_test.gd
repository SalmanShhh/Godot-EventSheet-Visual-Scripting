@tool
class_name SentenceShapesTest
extends RefCounted

# Opens a hand-written script as a sheet and pins what every row READS.
#
# sentence_grammar_test pins the grammar itself; this one pins the whole path - importer, lifter,
# row builder, span metadata - so a shape that stops reaching the canvas is caught even when the
# grammar still answers correctly on its own. It also gates the two promises the reading rests on:
#
#   1. the file still round-trips byte-identically (a reading may never cost a byte), and
#   2. a row built from the PICKER reads exactly what the same shape typed by hand reads.
#
# The source lives here as a string rather than in tests/fixtures/ for one concrete reason: the
# lifter's byte gate compares against what the COMPILER would emit, and the compiler puts one blank
# line between functions - so a two-blank-line file (which the style gate requires of every checked-in
# .gd) can never lift, and the fixture would silently test nothing.

const SOURCE_PATH := "user://eventforge_sentence_shapes.gd"

const SOURCE: String = """## @ace_expose_all(node)
extends Node

var host: Node2D = null
var _jumps_left: int = 0
var _coyote_timer: float = 0.0
var crouching: bool = false
var push_x: float = 0.0

## @ace_trigger
## @ace_name("On Jumped")
signal jumped

## @ace_action
## @ace_name("Do Everything")
## @ace_codegen_template("$Fixture.do_everything({amount})")
func do_everything(amount: float) -> void:
	if host == null:
		return
	_jumps_left -= 1
	_coyote_timer += amount
	_coyote_timer = maxf(_coyote_timer - amount, 0.0)
	host.position.x = amount * 2.0
	var remaining: float = amount
	push_x = move_toward(push_x, 0.0, remaining)
	if crouching:
		push_x = clamp(push_x, -1.0, 1.0)
	if not crouching:
		push_x = deg_to_rad(amount)
	if Input.is_action_pressed(&"ui_accept"):
		queue_free()
	if randf() < 0.3:
		host.call_deferred("queue_free")
	jumped.emit()
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://menu.tscn")

## @ace_condition
## @ace_name("Can Jump")
## @ace_codegen_template("$Fixture.can_jump()")
func can_jump() -> bool:
	if host != null:
		return true
	return false

## @ace_expression
## @ace_name("Jumps Left")
## @ace_codegen_template("$Fixture.jumps_left()")
func jumps_left() -> int:
	return _jumps_left
"""

## Every reading the opened file must contain, one per shape the grammar claims.
static var EXPECTED_READINGS: PackedStringArray = PackedStringArray([
	"host ▸ does not exist",
	"System ▸ Stop event",
	"System ▸ Subtract 1 from _jumps_left",
	"System ▸ Add amount to _coyote_timer",
	"System ▸ Set _coyote_timer to max(_coyote_timer - amount, 0)",
	"host ▸ Set position.x to amount * 2",
	"Local number remaining = amount",
	"System ▸ Set push_x to push_x moved toward 0 by remaining",
	"System ▸ crouching is true",
	"System ▸ Set push_x to push_x kept between -1 and 1",
	"System ▸ crouching is false",
	"System ▸ Set push_x to amount°",
	"Keyboard ▸ ui_accept is down",
	"System ▸ Destroy",
	"System ▸ 30% chance",
	"host ▸ Destroy (at end of frame)",
	"System ▸ Signal On Jumped",
	"System ▸ ⏳ Wait 0.5 seconds",
	"System ▸ Go to scene res://menu.tscn",
	"host ▸ exists",
	"System ▸ Answer yes",
	"System ▸ Answer no",
	"System ▸ Give back _jumps_left"
])


static func run() -> bool:
	var ok: bool = true
	var readings: PackedStringArray = _open_and_read()
	for expected: String in EXPECTED_READINGS:
		ok = _check("hand-written row reads \"%s\"" % expected, readings.has(expected), true) and ok
	ok = _round_trip() and ok
	ok = _picked_matches_typed() and ok
	ok = _local_variable_round_trip() and ok
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] sentence_shapes_test: %s" % label)
		return true
	print("[FAIL] sentence_shapes_test: %s - expected %s, got %s" % [label, expected, actual])
	return false


## Writes the source, opens it as a sheet, and returns every cell reading - "object ▸ text" when the
## row names an object, the bare text otherwise.
static func _open_and_read() -> PackedStringArray:
	var handle: FileAccess = FileAccess.open(SOURCE_PATH, FileAccess.WRITE)
	handle.store_string(SOURCE)
	handle.close()
	return _render(GDScriptImporter.new().import_external(SOURCE_PATH))


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
	# The WHOLE tree, folded rows included: a verb body is collapsed by default in a read-only
	# preview, and what a row reads must not depend on whether its parent happens to be open.
	for row_data: EventRowData in _walk(viewport._root_rows, viewport):
		_append_readings(readings, row_data)
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


## The readings of ONE row - "object ▸ text" when the cell names an object, the bare text otherwise.
## A declaration is three spans (chip, name, value) and reads back as the one line it draws as.
static func _append_readings(readings: PackedStringArray, row_data: EventRowData) -> void:
	var pending_declaration: String = ""
	for span: SemanticSpan in row_data.spans:
		var label: String = str(span.metadata.get("object_label", ""))
		var text: String = span.text.strip_edges()
		if not label.is_empty():
			readings.append("%s ▸ %s" % [label, text])
			continue
		if text.begins_with("Local ") or text.begins_with("= "):
			pending_declaration += text if pending_declaration.is_empty() else " %s" % text
			if text.begins_with("= "):
				readings.append(pending_declaration)
				pending_declaration = ""
			continue
		if not pending_declaration.is_empty():
			pending_declaration += " %s" % text
			continue
		readings.append(text)
	

static func _round_trip() -> bool:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(SOURCE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, SOURCE_PATH).get("output", ""))
	return _check("opening the file and saving it reproduces every byte", output, SOURCE)


## The parity promise: a row dropped from the PICKER reads exactly what the same shape reads when it
## was typed by hand. Both sides go through the canvas, so this catches a wiring gap the grammar's own
## unit test cannot see.
static func _picked_matches_typed() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.custom_class_name = "Fixture"
	var signal_row: SignalRow = SignalRow.new()
	signal_row.signal_name = "jumped"
	signal_row.ace_name = "On Jumped"
	sheet.events.append(signal_row)
	var event_row: EventRow = EventRow.new()
	event_row.trigger_id = "OnReady"
	event_row.conditions.append(_condition("CompareVar", {"var_name": "host", "op": "==", "value": "null"}))
	event_row.actions.append(_action("SetVar", {"var_name": "_coyote_timer", "value": "0.0"}))
	event_row.actions.append(_action("EmitSignal", {"signal_name": "jumped", "args": ""}))
	event_row.actions.append(_action("QueueFree", {}))
	event_row.actions.append(_action("ReturnEarly", {}))
	event_row.actions.append(_action("SetProperty", {"target": "host", "property": "position.x", "value": "1.0"}))
	sheet.events.append(event_row)
	var readings: PackedStringArray = _render(sheet)
	for expected: String in ["host ▸ does not exist", "System ▸ Set _coyote_timer to 0",
			"Fixture ▸ Signal On Jumped", "System ▸ Destroy", "System ▸ Stop event",
			"host ▸ Set position.x to 1"]:
		ok = _check("picked row reads \"%s\"" % expected, readings.has(expected), true) and ok
	return ok


## The Local Variable row a user AUTHORS: it reads as a declaration, it compiles to the same `var`
## line a user could have typed, and reopening the file gives that row back.
static func _local_variable_round_trip() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	var event_row: EventRow = EventRow.new()
	# A bare event emits nothing - the trigger is what gives the body a handler to live in.
	event_row.trigger_id = "OnReady"
	event_row.actions.append(_action("SetLocalVarTyped", {"name": "remaining", "var_type": "float", "value": "1.0"}))
	sheet.events.append(event_row)
	ok = _check("authored local reads as a declaration row",
		_render(sheet).has("Local number remaining = 1"), true) and ok
	var compiled: String = str(SheetCompiler.compile(sheet, "user://eventforge_local_var.gd").get("output", ""))
	ok = _check("authored local compiles to the plain var line",
		compiled.contains("\tvar remaining: float = 1.0"), true) and ok
	var handle: FileAccess = FileAccess.open("user://eventforge_local_var.gd", FileAccess.WRITE)
	handle.store_string(compiled)
	handle.close()
	var reopened: EventSheetResource = GDScriptImporter.new().import_external("user://eventforge_local_var.gd")
	ok = _check("reopening gives the same declaration row back",
		_render(reopened).has("Local number remaining = 1"), true) and ok
	ok = _check("and reopening it saves byte-identically",
		str(SheetCompiler.compile(reopened, "user://eventforge_local_var.gd").get("output", "")), compiled) and ok
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
