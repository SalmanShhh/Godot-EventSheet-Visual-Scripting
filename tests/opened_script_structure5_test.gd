# EventForge - the engine callbacks that used to open as helper functions, pinned by VALUE on a
# real fixture file:
#
#   _draw          reads as the object's own paint trigger (OnDraw)
#   _enter_tree    reads as the object's created trigger (OnEnterTree) - unless it is the host binding
#   _exit_tree     reads as the object's destroyed trigger (OnExitTree)
#   _notification  whose whole body is a `match what:` reads as ONE trigger per matched notification
#
# All four are READINGS: the rows change, the file does not. The byte round-trip is asserted first,
# because a reading that costs a file its round-trip is not a reading, it is a bug. The two negative
# shapes matter just as much - a host-binding `_enter_tree` and the `if what == ...` spelling of the
# language-changed handler must both stay exactly where they were.
@tool
class_name OpenedScriptStructure5Test
extends RefCounted

const FIXTURE_PATH: String = "res://tests/fixtures/opened_script_structure5.gd"

## The host-binding boilerplate a host-targeting behaviour pack ships. The compiler regenerates this
## from the sheet's host metadata, so it must NOT lift to a trigger (that would emit it twice).
const HOST_BINDING_SOURCE: String = "extends Node\n\nvar host: Node2D = null\n\n\nfunc _enter_tree() -> void:\n\thost = get_parent() as Node2D\n\tif host == null:\n\t\tpush_warning(\"Dash behavior requires a Node2D parent.\")\n"

## The language-changed handler's shape: an `if`, not a `match`. It has always opened as a code block
## and must keep doing so - the match lift may not quietly claim it.
const LOCALE_SOURCE: String = "extends Node\n\n\nfunc _notification(what: int) -> void:\n\tif what == NOTIFICATION_TRANSLATION_CHANGED:\n\t\tprint(\"changed\")\n"


static func run() -> bool:
	var ok: bool = true
	ok = _round_trips() and ok
	ok = _trigger_ids() and ok
	ok = _host_binding_stays_code() and ok
	ok = _locale_shape_stays_code() and ok
	ok = _resolver_shapes() and ok
	return ok


## ── the contract that outranks every reading ─────────────────────────────────────────────────────
static func _round_trips() -> bool:
	var source: String = FileAccess.get_file_as_string(FIXTURE_PATH)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FIXTURE_PATH)
	var output: String = str(SheetCompiler.compile(sheet, FIXTURE_PATH).get("output", ""))
	return _check("the fixture comes back byte-identical", output, source)


## ── one trigger id per callback, in the file's own order ─────────────────────────────────────────
static func _trigger_ids() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(FIXTURE_PATH)
	var ids: PackedStringArray = PackedStringArray()
	for item: Variant in sheet.events:
		if item is EventRow:
			ids.append((item as EventRow).trigger_id)
	ok = _check("the callbacks lift as triggers, in file order", ", ".join(ids),
		"OnEnterTree, OnDraw, OnExitTree, OnNotification:NOTIFICATION_APPLICATION_PAUSED, OnNotification:NOTIFICATION_APPLICATION_RESUMED, OnNotification:NOTIFICATION_WM_CLOSE_REQUEST") and ok
	ok = _check("none of them stayed a helper function", sheet.functions.size(), 0) and ok
	# Every notification shares ONE handler: the engine calls _notification once per notification, so
	# a second same-named function would not even parse.
	var keys: Dictionary = {}
	for item: Variant in sheet.events:
		if item is EventRow and (item as EventRow).trigger_id.begins_with("OnNotification:"):
			keys[TriggerResolver.get_trigger_key(item as EventRow)] = true
	ok = _check("all three notifications group into one handler", keys.size(), 1) and ok
	return ok


## ── the host binding is regenerated boilerplate, so it stays a code row ──────────────────────────
static func _host_binding_stays_code() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _sheet_from_source(HOST_BINDING_SOURCE, "res://__structure5_host_binding.gd")
	var trigger_ids: PackedStringArray = PackedStringArray()
	var raw_headers: PackedStringArray = PackedStringArray()
	for item: Variant in sheet.events:
		if item is EventRow:
			trigger_ids.append((item as EventRow).trigger_id)
		elif item is RawCodeRow:
			raw_headers.append((item as RawCodeRow).code.split("\n")[0])
	ok = _check("the host binding lifts to no trigger at all", ", ".join(trigger_ids), "") and ok
	ok = _check("it stays the code row it was", raw_headers.has("func _enter_tree() -> void:"), true) and ok
	return ok


## ── the `if what == ...` handler is a different shape and keeps its old reading ──────────────────
static func _locale_shape_stays_code() -> bool:
	var ok: bool = true
	var sheet: EventSheetResource = _sheet_from_source(LOCALE_SOURCE, "res://__structure5_locale.gd")
	var trigger_ids: PackedStringArray = PackedStringArray()
	for item: Variant in sheet.events:
		if item is EventRow:
			trigger_ids.append((item as EventRow).trigger_id)
	ok = _check("an `if what ==` handler is not claimed by the match lift", ", ".join(trigger_ids), "") and ok
	return ok


## ── the compiler's side of the four new ids ──────────────────────────────────────────────────────
static func _resolver_shapes() -> bool:
	var ok: bool = true
	ok = _check("OnDraw emits the paint callback", _function_name_for("OnDraw"), "_draw") and ok
	ok = _check("OnEnterTree emits the enter callback", _function_name_for("OnEnterTree"), "_enter_tree") and ok
	ok = _check("OnExitTree emits the exit callback", _function_name_for("OnExitTree"), "_exit_tree") and ok
	ok = _check("a notification id emits the notification callback",
		_function_name_for("OnNotification:NOTIFICATION_APPLICATION_PAUSED"), "_notification") and ok
	ok = _check("the notification constant comes back off the id",
		TriggerResolver.notification_constant_for("OnNotification:NOTIFICATION_WM_CLOSE_REQUEST"), "NOTIFICATION_WM_CLOSE_REQUEST") and ok
	ok = _check("an ordinary id names no notification", TriggerResolver.notification_constant_for("OnReady"), "") and ok
	return ok


static func _function_name_for(trigger_id: String) -> String:
	var event: EventRow = EventRow.new()
	event.trigger_id = trigger_id
	return str(TriggerResolver.resolve_trigger(event).get("function_name", ""))


## Imports a source string as an opened script. The importer reads from DISK, so the source is
## written to a real file first (an in-memory GDScript has no path and lifts nothing).
static func _sheet_from_source(source: String, path: String) -> EventSheetResource:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return EventSheetResource.new()
	file.store_string(source)
	file.close()
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return sheet


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] %s: expected %s, got %s" % [label, str(expected), str(actual)])
	return false
