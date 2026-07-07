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

	# new_sheet: the one public way to author a sheet / behavior / tool from code.
	var made: EventSheetResource = EventSheets.new_sheet({"class_name": "Turret", "host_class": "Node2D", "behavior_mode": true, "category": "My Pack", "tags": ["ai"]})
	ok = _check("new_sheet configures the resource",
		made.custom_class_name == "Turret" and made.host_class == "Node2D" and made.behavior_mode and made.addon_category == "My Pack" and made.addon_tags == PackedStringArray(["ai"]), true) and ok
	ok = _check("new_sheet compiles with its class_name",
		str(EventSheets.compile(made).get("output", "")).contains("class_name Turret"), true) and ok
	var tool_src: String = str(EventSheets.compile(EventSheets.new_sheet({"tool_mode": true, "host_class": "EditorScript"})).get("output", ""))
	ok = _check("new_sheet can shape a tool script",
		tool_src.contains("@tool") and tool_src.contains("extends EditorScript"), true) and ok

	# ── Inspector services, dock-free (the parity toolkit for extensions) ──
	var inspector_attrs: Dictionary = {"range": {"min": "0", "max": "100"}, "drawer": "progress_bar", "group": "Combat", "header": "Combat", "info": "Tune with care."}
	ok = _check("describe_inspector speaks the preview card's sentence",
		EventSheets.describe_inspector("int", inspector_attrs),
		"A whole number, from 0 to 100, shown as a progress bar, grouped under Combat, under a \"Combat\" section header, with an info note.") and ok
	var preview: Control = EventSheets.build_inspector_preview("armour", "int", "10", inspector_attrs)
	ok = _check("build_inspector_preview returns the live preview card",
		preview is EventSheetInspectorPreviewCard, true) and ok
	preview.free()
	var api_var: LocalVariable = LocalVariable.new()
	api_var.name = "armour"
	api_var.type_name = "int"
	api_var.default_value = 10
	api_var.exported = true
	api_var.attributes = {"header": "Combat", "drawer": "progress_bar", "range": {"min": "0", "max": "100"}}
	ok = _check("variable_code returns the exact Ships-as lines",
		EventSheets.variable_code(api_var),
		"# @inspector_header Combat\n@export_custom(PROPERTY_HINT_NONE, \"eventsheet:progress_bar:0:100\") var armour: int = 10") and ok

	# ── Custom Block API: the hover seam (kinds explain their rows on hover) ──
	ok = _check("block kinds hover silently by default",
		EventSheetBlockKind.new().hover_text(CustomBlockRow.new()), "") and ok
	var hover_kind: EventSheetBlockKind = EventSheetBlockKind.new()
	var hover_script: GDScript = GDScript.new()
	hover_script.source_code = "extends EventSheetBlockKind\n\n\nfunc hover_text(entry: Resource) -> String:\n\treturn \"spawns %s\" % str((entry as CustomBlockRow).fields.get(\"what\", \"?\"))\n"
	ok = _check("a kind's hover_text override parses", hover_script.reload() == OK, true) and ok
	if hover_script.reload() == OK:
		hover_kind = hover_script.new() as EventSheetBlockKind
		var hover_row: CustomBlockRow = CustomBlockRow.new()
		hover_row.fields = {"what": "goblins"}
		ok = _check("hover_text reads the row's own fields", hover_kind.hover_text(hover_row), "spawns goblins") and ok

	# simple_block_kind: a whole Custom Block kind from a Dictionary, no subclassing.
	var note_kind: EventSheetBlockKind = EventSheets.simple_block_kind({
		"kind_id": "api_test.note", "title": "Note", "category": "Blocks",
		"fields": [{"id": "text", "label": "Text", "type": TYPE_STRING, "default": "hi"}],
		"emit": "## NOTE: {text}", "summary": "note: {text}"})
	var note_row: CustomBlockRow = CustomBlockRow.new()
	note_row.kind_id = "api_test.note"
	note_row.fields = {"text": "remember this"}
	ok = _check("simple_block_kind emits its template",
		note_kind.emit(note_row), PackedStringArray(["## NOTE: remember this"])) and ok
	ok = _check("simple_block_kind fills the summary template", note_kind.summary(note_row), "note: remember this") and ok
	ok = _check("simple_block_kind exposes the field schema", note_kind.fields().size(), 1) and ok
	EventSheets.register_block_kind(note_kind)
	ok = _check("a simple block kind registers on the block registry",
		EventSheetBlockRegistry.kind_for(note_row) != null, true) and ok

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
