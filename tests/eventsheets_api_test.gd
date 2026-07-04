# Godot EventSheets - the public extension API (addons/eventsheet/api/eventsheets.gd).
#
# EventSheets is a compatibility promise: these pins hold its shapes still. Editor
# services run against a real dock; codegen and vocabulary services run dock-free.
# The dogfood pins prove the plugin's own features consume the same seams an
# extension would: the region fold commands arrive via register_palette_command,
# and the palette merges API entries after the built-ins.
@tool
class_name EventSheetsAPITest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── Codegen services, dock-free ──
	var source: String = "extends Node\n\nfunc _ready() -> void:\n\tprint(tr(\"HELLO\"))\n"
	var sheet: EventSheetResource = EventSheets.open_gd_as_sheet(source)
	ok = _check("open_gd_as_sheet lifts a sheet", sheet != null and sheet.host_class == "Node", true) and ok
	ok = _check("round_trips holds the byte gate", EventSheets.round_trips(source), true) and ok
	var built: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_id = "OnReady"
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "Print"
	action.codegen_template = "print({value})"
	action.params = {"value": "\"hi\""}
	event.actions.append(action)
	built.events.append(event)
	ok = _check("compile emits through the API",
		str(EventSheets.compile(built).get("output", "")).contains("print(\"hi\")"), true) and ok

	# ── Vocabulary services, dock-free ──
	ok = _check("class_vocabulary reflects on demand",
		EventSheets.class_vocabulary("GraphEdit").size() >= 10, true) and ok

	# ── Project health: an extension check runs everywhere the Doctor runs ──
	EventSheets.register_doctor_check("api_test.probe", func(sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
		findings.append({"severity": "info", "check": "api_test.probe", "path": "res://",
			"message": "probe saw %d sheets" % sheet_paths.size()}))
	EventSheets.register_doctor_check("api_test.probe", func(_sheet_paths: PackedStringArray, findings: Array[Dictionary]) -> void:
		findings.append({"severity": "info", "check": "api_test.probe", "path": "res://", "message": "replaced probe"}))
	var report: Dictionary = EventSheets.doctor()
	var probe_messages: Array = []
	for finding: Dictionary in (report.get("findings", []) as Array):
		if str(finding.get("check", "")) == "api_test.probe":
			probe_messages.append(str(finding.get("message", "")))
	ok = _check("re-registering an id replaces, and the check reports through doctor()",
		probe_messages, ["replaced probe"]) and ok
	ok = _check("severity counts include extension findings",
		int(report.get("errors", -1)) + int(report.get("warnings", -1)) + int(report.get("infos", -1)),
		(report.get("findings", []) as Array).size()) and ok
	EventSheets.unregister_doctor_check("api_test.probe")
	ok = _check("unregister empties the Doctor's extension list",
		EventSheetProjectDoctor._extension_checks.is_empty(), true) and ok

	# ── Editor services against a live dock ──
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(EventSheetResource.new())
	ok = _check("the dock registers itself with the API", EventSheets.current_sheet() == dock.get_current_sheet(), true) and ok

	# edit(): one funnel step, refresh + dirty handled, mutation sees the live sheet.
	var edited: bool = EventSheets.edit("API adds a comment", func(live_sheet: EventSheetResource) -> void:
		var comment: CommentRow = CommentRow.new()
		comment.text = "added through the API"
		live_sheet.events.append(comment))
	ok = _check("edit() lands the mutation as a change", edited, true) and ok
	var found: bool = false
	for entry: Resource in EventSheets.current_sheet().events:
		if entry is CommentRow and (entry as CommentRow).text == "added through the API":
			found = true
	ok = _check("the mutation reached the live sheet", found, true) and ok

	# Palette registration: an extension entry lands in the palette list; the dogfooded
	# fold commands are already there via the same seam.
	var ran: Array = []
	EventSheets.register_palette_command("API Test Command", func() -> void: ran.append(true))
	var titles: Array = []
	for command: Dictionary in dock._command_palette_commands():
		titles.append(str(command.get("title", "")))
	ok = _check("a registered command reaches the palette", titles.has("API Test Command"), true) and ok
	ok = _check("the fold commands dogfood the same seam", titles.has("Fold All Regions") and titles.has("Unfold Everything"), true) and ok
	for command: Dictionary in EventSheets.palette_commands():
		if str(command.get("title", "")) == "API Test Command":
			(command.get("run") as Callable).call()
	ok = _check("the registered action runs", ran.size(), 1) and ok
	EventSheets.unregister_palette_command("API Test Command")
	ok = _check("unregister removes the entry",
		EventSheets.palette_commands().filter(func(c: Dictionary) -> bool: return str(c.get("title", "")) == "API Test Command").is_empty(), true) and ok

	dock.free()
	return ok


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] eventsheets_api_test: %s" % label)
		return true
	print("[FAIL] eventsheets_api_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
