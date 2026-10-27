# EventForge - a handler the compiler writes underscores the parameters its events never read.
#
# Godot reports "The parameter "delta" is never used" once per handler, for every Every tick, touch
# and signal event that does not read what the trigger hands over - in every project that runs the
# sheet. The compiler now writes such a parameter `_delta`, which is Godot's own cure, and writes it
# plain again the moment an event reads it. Reading a file back, `_delta` is the trigger's `delta`
# again; a file that left an unread parameter plain is somebody's own spelling and comes back exactly
# as it was written. Pinned on the shared spelling functions, on emission and on the round trip.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const UnusedParams := preload("res://addons/eventforge/compiler/unused_params.gd")
const P := "unused_handler_params_test"
const VERIFY := "user://unused_handler_params_probe.gd"

const UNREAD_TICK := "extends Node2D\n\nfunc _process(_delta: float) -> void:\n\tprint(\"tick\")\n"
const PLAIN_UNREAD_TICK := "extends Node2D\n\nfunc _process(delta: float) -> void:\n\tprint(\"tick\")\n"
const READ_TICK := "extends Node2D\n\nfunc _process(delta: float) -> void:\n\tposition.x += 10.0 * delta\n"
const TOUCH := "extends Area2D\n\nfunc _ready() -> void:\n\tbody_entered.connect(_on_body_entered)\n\nfunc _on_body_entered(_body: Node2D) -> void:\n\tprint(\"touched\")\n"


static func run() -> bool:
	var ok: bool = SUPPORT.pins(P, [
		["an unread parameter is underscored",
			UnusedParams.spell("func _process(delta: float) -> void:", PackedStringArray(["\tprint(1)"])),
			"func _process(_delta: float) -> void:"],
		["a read one is not",
			UnusedParams.spell("func _process(delta: float) -> void:", PackedStringArray(["\tx += delta"])),
			"func _process(delta: float) -> void:"],
		["a comment does not count as reading it",
			UnusedParams.spell("func _on_hit(body: Node, at: Vector2) -> void:", PackedStringArray(["\t# body", "\tprint(at)"])),
			"func _on_hit(_body: Node, at: Vector2) -> void:"],
		["a name that is only part of a longer one is not a read",
			UnusedParams.spell("func _input(event: InputEvent) -> void:", PackedStringArray(["\tprint(events)"])),
			"func _input(_event: InputEvent) -> void:"],
		["reading back, `_delta` unread is the trigger's delta",
			UnusedParams.normalize("func _process(_delta: float) -> void:", PackedStringArray(["\tprint(1)"])),
			{"header": "func _process(delta: float) -> void:", "follows": true}],
		["an unread parameter left plain is kept as written",
			UnusedParams.normalize("func _process(delta: float) -> void:", PackedStringArray(["\tprint(1)"])),
			{"header": "func _process(delta: float) -> void:", "follows": false}],
		["an `_x` the body reads stays `_x`",
			UnusedParams.normalize("func _on_x(_body) -> void:", PackedStringArray(["\tprint(_body)"])),
			{"header": "func _on_x(_body) -> void:", "follows": true}],
		["the mark never reaches the output", _finished("func _process(delta: float) -> void:"),
			PackedStringArray(["func _process(_delta: float) -> void:", "\tprint(1)", "", "func other() -> void:", "\tprint(delta)"])],
	])
	ok = _round_trip_pins() and ok
	return ok


## A head followed by a body that does not read delta and then a function that does: the finishing
## pass reads only the body under its own head.
static func _finished(header: String) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray([UnusedParams.mark(header), "\tprint(1)", "", "func other() -> void:", "\tprint(delta)"])
	UnusedParams.finish(lines)
	return lines


static func _round_trip_pins() -> bool:
	var unread: EventSheetResource = SUPPORT.reopen(UNREAD_TICK)
	var reading: EventSheetResource = SUPPORT.reopen(UNREAD_TICK)
	var tick: EventRow = _first_event(reading)
	if tick != null:
		var reads_delta: RawCodeRow = RawCodeRow.new()
		reads_delta.code = "position.x += delta"
		tick.actions.append(reads_delta)
	var touched: EventSheetResource = SUPPORT.reopen(TOUCH)
	var touch_event: EventRow = _first_event(touched, "_on_body_entered")
	return SUPPORT.pins(P, [
		["`_delta` unread lifts to an Every tick event", _first_event(unread).trigger_id if _first_event(unread) != null else "", "OnProcess"],
		["and comes back byte for byte", SUPPORT.reemit(UNREAD_TICK, VERIFY), UNREAD_TICK],
		["an event that starts reading delta gets delta back", _head_of(_emit(reading)), "func _process(delta: float) -> void:"],
		["a plain unread delta is the author's and comes back as written", SUPPORT.reemit(PLAIN_UNREAD_TICK, VERIFY), PLAIN_UNREAD_TICK],
		["a read delta comes back as written", SUPPORT.reemit(READ_TICK, VERIFY), READ_TICK],
		["an unread touched body comes back byte for byte", SUPPORT.reemit(TOUCH, VERIFY), TOUCH],
		["and the trigger names it body, as the signal does",
			str(touch_event.get_meta("__source_trigger_header", "")) if touch_event != null else "",
			"func _on_body_entered(body: Node2D) -> void:"],
	])


static func _emit(sheet: EventSheetResource) -> String:
	if sheet == null:
		return ""
	sheet.external_source_path = VERIFY
	return SUPPORT.compile_output(sheet, VERIFY)


static func _head_of(source: String) -> String:
	for line: String in source.split("\n"):
		if line.begins_with("func _process("):
			return line
	return ""


## The first event of the sheet; with `handler`, the first whose kept head names that function.
static func _first_event(sheet: EventSheetResource, handler: String = "") -> EventRow:
	if sheet == null:
		return null
	for entry: Variant in sheet.events:
		if not (entry is EventRow):
			continue
		var row: EventRow = entry as EventRow
		if handler.is_empty() or str(row.get_meta("__source_trigger_header", "")).begins_with("func %s(" % handler):
			return row
	return null
