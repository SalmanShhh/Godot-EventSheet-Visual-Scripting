# Godot EventSheets - input and signal handlers read as the triggers a player would name them.
#
# Three things are pinned here, by VALUE (the exact strings a reader sees):
#   A  a lifecycle handler that sits AFTER a pack's verbs still lifts as EVENTS, anchored in place
#      (EventAnchorRow), and the file recompiles byte-identically.
#   B  each top-level branch of an `_input` / `_unhandled_input` / `_unhandled_key_input` reads as
#      ONE event-sheet trigger row - Mouse > On mouse moved, Keyboard > On Escape pressed - with the
#      casts gone from the sentence and `event.relative.x` reading as the mouse's delta.
#   C  a hand-written signal handler reads as its SOURCE NODE plus the payload its parameters carry.
#   D  symmetry: a Mouse/Keyboard trigger AUTHORED on a sheet compiles to GDScript that, reopened,
#      reads as exactly the same row - so a file round-trips through both worlds unchanged.
@tool
class_name InputHandlerReadingTest
extends RefCounted

const FPS_PACK: String = "res://eventsheet_addons/fps_controller/fps_controller_behavior.gd"

## A hand-written script in nobody's house style: helpers above the handlers, a `$Node` connect,
## casts inside the branch tests, and a mouse-button branch beside a key-RELEASED branch.
const HANDWRITTEN: String = """extends Node2D

@onready var hurtbox: Area2D = $Hurtbox

func _ready() -> void:
	$Hurtbox.body_entered.connect(_on_hurtbox_body_entered)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		fire()
	elif event is InputEventKey and not (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_SPACE:
		stop_firing()

func _on_hurtbox_body_entered(body: Node2D) -> void:
	print(body.name)

func fire() -> void:
	print("fire")

func stop_firing() -> void:
	print("stop")
"""


static func run() -> bool:
	var ok: bool = true

	# ── A: the FPS pack's three lifecycle handlers anchor in place, and the file still round-trips ──
	var fps: EventSheetResource = GDScriptImporter.new().import_external(FPS_PACK)
	ok = _check("every lifecycle handler of the FPS pack opens as events, in place",
		_anchor_triggers(fps), PackedStringArray(["OnReady", "OnPhysicsProcess", "OnUnhandledInput"])) and ok
	ok = _check("the anchored _unhandled_input holds one event per branch",
		_anchor_row_count(fps, "OnUnhandledInput"), 2) and ok
	ok = _check("the anchors did not cost the pack a verb", _exposed_verbs(fps), 31) and ok
	ok = _check("the opened FPS pack recompiles byte-identically",
		str(SheetCompiler.compile(fps, FPS_PACK).get("output", "")), FileAccess.get_file_as_string(FPS_PACK)) and ok

	# ── B: the FPS pack's `_unhandled_input` reads as two event-sheet trigger rows ─
	var fps_rows: Array[PackedStringArray] = _handler_readings(fps, "OnUnhandledInput")
	ok = _check("the mouse-motion branch reads as a Mouse trigger with the capture check under it",
		fps_rows[0] if fps_rows.size() > 0 else PackedStringArray(),
		PackedStringArray(["Mouse|On mouse moved", "Mouse|mouse is captured", "ƒ|Call Add Look   x = mouse's ΔX   y = mouse's ΔY"])) and ok
	ok = _check("the key branch reads as a Keyboard trigger, not an Else",
		fps_rows[1] if fps_rows.size() > 1 else PackedStringArray(),
		PackedStringArray(["Keyboard|On Escape pressed", "ƒ|Call Release Mouse"])) and ok

	# ── B + C: a hand-written file - mouse button, key released, and a connected handler ──
	var handwritten_path: String = "user://eventsheets_handwritten_input_test.gd"
	var handwritten_file: FileAccess = FileAccess.open(handwritten_path, FileAccess.WRITE)
	handwritten_file.store_string(HANDWRITTEN)
	handwritten_file.close()
	var hand: EventSheetResource = GDScriptImporter.new().import_external(handwritten_path)
	ok = _check("the hand-written file recompiles byte-identically",
		str(SheetCompiler.compile(hand, handwritten_path).get("output", "")), HANDWRITTEN) and ok
	var hand_rows: Array[PackedStringArray] = _event_readings(hand)
	ok = _check("a mouse-button branch names the button and the edge",
		hand_rows[0] if hand_rows.size() > 0 else PackedStringArray(),
		PackedStringArray(["Mouse|On right button pressed", "ƒ|Call Fire"])) and ok
	ok = _check("a key-RELEASED branch says released",
		hand_rows[1] if hand_rows.size() > 1 else PackedStringArray(),
		PackedStringArray(["Keyboard|On Space released", "ƒ|Call Stop Firing"])) and ok
	ok = _check("a hand-written signal handler reads as its source node, with its payload as a chip",
		hand_rows[2] if hand_rows.size() > 2 else PackedStringArray(),
		PackedStringArray(["Hurtbox|On collision with", "|body", "System|Print body.name"])) and ok

	# ── D: an AUTHORED Keyboard/Mouse trigger reads back as the same row after save + reopen ──
	ok = _check("an authored Keyboard trigger reopens as the same row",
		_authored_round_trip("KeyEventPressed", {"key": "KEY_ESCAPE"}, "user://eventsheets_authored_key_test.gd"),
		PackedStringArray(["Keyboard|On Escape pressed", "ƒ|Call Fire"])) and ok
	ok = _check("an authored Mouse trigger reopens as the same row",
		_authored_round_trip("MouseButtonEventPressed", {"button": "MOUSE_BUTTON_RIGHT"}, "user://eventsheets_authored_mouse_test.gd"),
		PackedStringArray(["Mouse|On right button pressed", "ƒ|Call Fire"])) and ok
	return ok


## Authors one `_unhandled_input` event holding the given input CONDITION, compiles it, reopens the
## emitted .gd the way the dock does, and reports how the reopened row reads. The whole point of D:
## this must equal what the hand-written spelling above reads.
static func _authored_round_trip(ace_id: String, params: Dictionary, path: String) -> PackedStringArray:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "AuthoredInput"
	var event: EventRow = EventRow.new()
	event.trigger_id = "OnUnhandledInput"
	event.trigger_provider_id = "Core"
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	event.conditions.append(condition)
	var call_action: ACEAction = ACEAction.new()
	call_action.provider_id = "Core"
	call_action.ace_id = "CallFunction"
	call_action.params = {"function_name": "fire", "args": ""}
	event.actions.append(call_action)
	sheet.events.append(event)
	var fire: EventFunction = EventFunction.new()
	fire.function_name = "fire"
	sheet.functions.append(fire)
	SheetCompiler.compile(sheet, path)
	var reopened: EventSheetResource = GDScriptImporter.new().import_external(path)
	var readings: Array[PackedStringArray] = _event_readings(reopened)
	return readings[0] if not readings.is_empty() else PackedStringArray()


## Every EventAnchorRow's trigger, in sheet order.
static func _anchor_triggers(sheet: EventSheetResource) -> PackedStringArray:
	var triggers: PackedStringArray = PackedStringArray()
	for entry: Variant in sheet.events:
		if entry is EventAnchorRow:
			triggers.append((entry as EventAnchorRow).trigger_id)
	return triggers


static func _anchor_row_count(sheet: EventSheetResource, trigger_id: String) -> int:
	for entry: Variant in sheet.events:
		if entry is EventAnchorRow and (entry as EventAnchorRow).trigger_id == trigger_id:
			return (entry as EventAnchorRow).event_uids.size()
	return -1


static func _exposed_verbs(sheet: EventSheetResource) -> int:
	var exposed: int = 0
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).expose_as_ace:
			exposed += 1
	return exposed


## How the rows of one anchored handler read, as "object|text" per span (badges and the "+ Add"
## affordances dropped - they are chrome, not sentence).
static func _handler_readings(sheet: EventSheetResource, trigger_id: String) -> Array[PackedStringArray]:
	var wanted: Dictionary = {}
	for entry: Variant in sheet.events:
		if entry is EventAnchorRow and (entry as EventAnchorRow).trigger_id == trigger_id:
			for anchored_uid: String in (entry as EventAnchorRow).event_uids:
				wanted[anchored_uid] = true
	return _readings(sheet, wanted)


## How every top-level event of a sheet reads, in order.
static func _event_readings(sheet: EventSheetResource) -> Array[PackedStringArray]:
	var wanted: Dictionary = {}
	for entry: Variant in sheet.events:
		if entry is EventRow:
			wanted[(entry as EventRow).event_uid] = true
	return _readings(sheet, wanted)


static func _readings(sheet: EventSheetResource, wanted: Dictionary) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null or not (row_data.source_resource is EventRow):
			continue
		if not wanted.has((row_data.source_resource as EventRow).event_uid):
			continue
		view._ensure_event_spans(row_data)
		var texts: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			if span.text.begins_with("+ Add ") or span.metadata is not Dictionary:
				continue
			if str((span.metadata as Dictionary).get("badge_style", "")) == "trigger":
				continue
			texts.append("%s|%s" % [str((span.metadata as Dictionary).get("object_label", "")), span.text])
		rows.append(texts)
	dock.free()
	return rows


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] input_handler_reading_test: %s" % label)
		return true
	print("[FAIL] input_handler_reading_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
