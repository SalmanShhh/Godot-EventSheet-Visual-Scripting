# Godot EventSheets - script errors read from the editor's own debugger, so a `.gd` sheet (whose file
# must stay byte-identical) and a hand-written script reach the runtime-error strip with nothing added
# to the game. Pins: the payload parse (a script error, an engine error raised on a script's behalf,
# warnings and other messages dropped, malformed payloads dropped), the once-per-place rule, a fake
# debugger node attached / released / lacking the signal, and a `.gd` sheet's source map resolving its
# line to a row only while its file is what the sheet would write.
@tool
class_name EditorErrorFeedTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const FEED := preload("res://addons/eventsheet/editor/dock/editor_error_feed.gd")
const NAME := "editor_error_feed_test"


## Stands in for the engine's debugger node: only the signal matters.
class FakeDebugger extends RefCounted:
	signal debug_data(message: String, data: Array)


class NoSignal extends RefCounted:
	pass


static func run() -> bool:
	var ok: bool = true
	ok = _parse_pins() and ok
	ok = _repeat_pins() and ok
	ok = _attach_pins() and ok
	ok = _gd_sheet_pins() and ok
	return ok


## The data exactly as a real game sent it (Godot 4.7): time, file, function, line, error, description,
## warning flag, stack value count, then (file, function, line) per frame.
static func _script_error() -> Array:
	return [0, 0, 9, 931, "res://game/hand.gd", "_boom", 14, "Out of bounds get index '5' (on base: 'Array')",
		"", false, 6, "res://game/hand.gd", "_boom", 14, "res://game/hand.gd", "_process", 9]


static func _parse_pins() -> bool:
	var script_error: Dictionary = FEED.parse("error", _script_error())
	var engine: Array = [0, 0, 2, 17, "scene/main/node.cpp", "get_node", 1743, "Method/function failed.",
		"Node not found: \"Gone\".", false, 6, "res://game/engine_case.gd", "_ready", 31,
		"res://game/engine_case.gd", "_enter", 5]
	var engine_error: Dictionary = FEED.parse("error", engine)
	var warning: Array = _script_error()
	warning[9] = true
	var no_script_frame: Array = [0, 0, 2, 17, "scene/main/node.cpp", "get_node", 1743, "Method/function failed.",
		"", false, 0]
	var empty_text: Array = _script_error()
	empty_text[7] = ""
	return SUPPORT.pins(NAME, [
		["a script error names its file", str(script_error.get("script_path", "")), "res://game/hand.gd"],
		["its line", int(script_error.get("line", 0)), 14],
		["and says the engine's message", str(script_error.get("message", "")),
			"Out of bounds get index '5' (on base: 'Array')"],
		["an engine error is placed at the script line that caused it",
			str(engine_error.get("script_path", "")), "res://game/engine_case.gd"],
		["on that frame's line", int(engine_error.get("line", 0)), 31],
		["and keeps both halves of its words", str(engine_error.get("message", "")),
			"Method/function failed. - Node not found: \"Gone\"."],
		["a warning is not a failure", FEED.parse("error", warning).is_empty(), true],
		["another kind of message is not an error", FEED.parse("stack_dump", _script_error()).is_empty(), true],
		["an engine error with no script frame has no row to point at",
			FEED.parse("error", no_script_frame).is_empty(), true],
		["a payload with nothing to say is dropped", FEED.parse("error", empty_text).is_empty(), true],
		["a short payload is dropped, not an error", FEED.parse("error", [0, 0, 1]).is_empty(), true],
		["an empty payload is dropped", FEED.parse("error", []).is_empty(), true],
		["a script path is res:// and .gd", FEED.is_script_path("res://a/b.gd"), true],
		["an engine source file is not one", FEED.is_script_path("scene/main/node.cpp"), false],
	])


static func _repeat_pins() -> bool:
	var seen: Dictionary = {}
	var first: bool = FEED.is_repeat(seen, "res://a.gd", 3)
	var again: bool = FEED.is_repeat(seen, "res://a.gd", 3)
	var other_line: bool = FEED.is_repeat(seen, "res://a.gd", 4)
	var other_file: bool = FEED.is_repeat(seen, "res://b.gd", 3)
	return SUPPORT.pins(NAME, [
		["the first sight of a place is new", first, false],
		["the same place again is a repeat", again, true],
		["another line is new", other_line, false],
		["another file is new", other_file, false],
	])


static func _attach_pins() -> bool:
	var feed: RefCounted = FEED.new()
	var said: Array = []
	feed.error_seen.connect(func(message: String, path: String, line: int) -> void:
		said.append([message, path, line]))
	var fake: FakeDebugger = FakeDebugger.new()
	var attached: bool = feed.attach(fake)
	var attached_twice: bool = feed.attach(fake)
	fake.debug_data.emit("performance:profile_frame", [1.0])
	fake.debug_data.emit("error", _script_error())
	var warning: Array = _script_error()
	warning[9] = true
	fake.debug_data.emit("error", warning)
	var heard: int = said.size()
	feed.release()
	fake.debug_data.emit("error", _script_error())
	var after_release: int = said.size()
	return SUPPORT.pins(NAME, [
		["a node with the signal is attached", attached, true],
		["attaching it twice is a no-op", attached_twice, false],
		["a node without the signal is a quiet no-op", feed.attach(NoSignal.new()), false],
		["null is a quiet no-op", feed.attach(null), false],
		["no root finds nothing", feed.attach_all(null), 0],
		["only the script error was said", heard, 1],
		["with its message, file and line", said[0], ["Out of bounds get index '5' (on base: 'Array')",
			"res://game/hand.gd", 14]],
		["after release nothing is said", after_release, 1],
	])


static func _gd_sheet_pins() -> bool:
	EventSheetRuntimeErrorLocator.clear()
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Boom"
	action.codegen_template = "print(1 / 0)"
	event.actions.append(action)
	sheet.events.append(event)
	var path: String = "user://editor_error_feed_gd_sheet.gd"
	sheet.external_source_path = path
	var echoed: Dictionary = SheetCompiler.echo(sheet)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(str(echoed.get("output", "")))
	file.close()
	var line: int = EventSheetLineRowMapper.range_for_resource(echoed.get("source_map", []), event).x
	var fresh: Dictionary = EventSheetRuntimeErrorLocator.source_map_for(sheet, false)
	var entries: Array = EventSheetLineRowMapper.entries_for_line(fresh.get("map", []), line)
	var found_event: bool = false
	for entry: Variant in entries:
		if instance_from_id(int((entry as Dictionary).get("uid", 0))) == event:
			found_event = true
	# A sheet edited since the file was written points at no row rather than the wrong one.
	var extra: EventRow = EventRow.new()
	extra.trigger_provider_id = "Core"
	extra.trigger_id = "OnReady"
	var extra_action: ACEAction = ACEAction.new()
	extra_action.provider_id = "Core"
	extra_action.ace_id = "Extra"
	extra_action.codegen_template = "print(2)"
	extra.actions.append(extra_action)
	sheet.events.insert(0, extra)
	var edited: Dictionary = EventSheetRuntimeErrorLocator.source_map_for(sheet, true)
	var passed: bool = SUPPORT.pins(NAME, [
		["a .gd sheet's output is its own file", EventSheetRuntimeErrorLocator.output_path_of(sheet), path],
		["its error line maps to the row that wrote it", found_event, true],
		["and the map is current while the file is what the sheet writes", bool(fresh.get("stale", true)), false],
		["unsaved edits make it stale", bool(edited.get("stale", false)), true],
	])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	EventSheetRuntimeErrorLocator.clear()
	return passed
