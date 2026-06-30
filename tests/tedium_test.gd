# Godot EventSheets — tedium-reduction arc (Tier 2+3, spec retired once delivered:
# see the CHANGELOG slices for the design record).
# Grows a block per slice: True Rename + create-variable quick-fix, snippets,
# bulk multi-select ops, session restore, canvas drops, attach/run loop closers.
@tool
extends RefCounted
class_name TediumTest

class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false

static func run() -> bool:
	var all_passed: bool = true

	# ── True Rename: word-boundary across every model surface ─────────────────────
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.variables = {
		"hp": {"type": "int", "default": 10, "exported": true},
		"hp_max": {"type": "int", "default": 10, "exported": true, "attributes": {"show_if": "hp > 0"}},
	}
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = "hp += 1\nhp_max = 5"
	event.actions.append(raw)
	var action: ACEAction = ACEAction.new()
	action.ace_id = "SetVar"
	action.params = {"value": "hp + hp_max"}
	event.actions.append(action)
	var note: CommentRow = CommentRow.new()
	note.text = "heals hp over time"
	sheet.events.append(note)
	sheet.events.append(event)
	var count: int = EventSheetRefactor.rename_symbol(sheet, "hp", "health")
	all_passed = _check("rename rewrites code, params, comments and the declaration",
		raw.code == "health += 1\nhp_max = 5"
		and str(action.params.get("value")) == "health + hp_max"
		and note.text == "heals health over time"
		and sheet.variables.has("health") and not sheet.variables.has("hp")
		and count >= 4, true) and all_passed
	all_passed = _check("rename preserves declaration order",
		sheet.variables.keys(), ["health", "hp_max"]) and all_passed
	all_passed = _check("attribute strings on other variables follow the rename",
		str((sheet.variables["hp_max"] as Dictionary).get("attributes", {}).get("show_if")), "health > 0") and all_passed
	all_passed = _check("absent symbols rename nothing",
		EventSheetRefactor.rename_symbol(sheet, "mana", "energy"), 0) and all_passed
	all_passed = _check("collisions are refused",
		EventSheetRefactor.validate_new_name(sheet, "health", "hp_max").is_empty(), false) and all_passed
	all_passed = _check("invalid identifiers are refused",
		EventSheetRefactor.validate_new_name(sheet, "health", "2fast").is_empty(), false) and all_passed

	# Function rename updates the declaration and call-site params.
	var exposed: EventFunction = EventFunction.new()
	exposed.function_name = "boost"
	sheet.functions.append(exposed)
	var call_action: ACEAction = ACEAction.new()
	call_action.ace_id = "CallFunction"
	call_action.params = {"function_name": "boost", "args": ""}
	event.actions.append(call_action)
	EventSheetRefactor.rename_symbol(sheet, "boost", "dash")
	all_passed = _check("function rename covers declaration + call sites",
		exposed.function_name == "dash" and str(call_action.params.get("function_name")) == "dash", true) and all_passed

	# Includers: the dock rewrites + saves sheets that include the renamed one.
	var library: EventSheetResource = EventSheetResource.new()
	library.host_class = "Node"
	library.variables = {"spd": {"type": "float", "default": 1.0, "exported": true}}
	ResourceSaver.save(library, "user://rename_lib.tres")
	var consumer: EventSheetResource = EventSheetResource.new()
	consumer.host_class = "Node"
	consumer.includes = ["user://rename_lib.tres"]
	var consumer_raw: RawCodeRow = RawCodeRow.new()
	consumer_raw.code = "var x = spd * 2"
	consumer.events.append(consumer_raw)
	ResourceSaver.save(consumer, "user://rename_consumer.tres")
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(ResourceLoader.load("user://rename_lib.tres", "", ResourceLoader.CACHE_MODE_IGNORE))
	editor.set_undo_redo_manager(NoopUndoManager.new())
	editor._current_sheet_path = "user://rename_lib.tres"
	var touched: PackedStringArray = editor._rename_in_includers("spd", "speed", PackedStringArray(["user://rename_consumer.tres"]))
	var reloaded: EventSheetResource = ResourceLoader.load("user://rename_consumer.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	all_passed = _check("includers are rewritten and saved",
		touched == PackedStringArray(["rename_consumer.tres"])
		and (reloaded.events[0] as RawCodeRow).code == "var x = speed * 2", true) and all_passed

	# ── Create-variable quick-fix (the engine hides parse-error text, so the unknown
	# identifier is derived from the expression against the sheet context) ─────────
	var lint_sheet: EventSheetResource = editor._current_sheet
	all_passed = _check("unknown identifiers are spotted",
		ACEParamsDialog.undeclared_identifier_in_expression("missing_thing + 1", lint_sheet), "missing_thing") and all_passed
	all_passed = _check("declared variables are accounted for",
		ACEParamsDialog.undeclared_identifier_in_expression("spd * 2", lint_sheet), "") and all_passed
	all_passed = _check("calls are skipped, their unknown args are not",
		ACEParamsDialog.undeclared_identifier_in_expression("clamp(spd, 0, max_hp)", lint_sheet), "max_hp") and all_passed
	all_passed = _check("string literals and member accesses never look unknown",
		ACEParamsDialog.undeclared_identifier_in_expression("\"hp text\" + str(name.length())", lint_sheet), "") and all_passed
	all_passed = _check("the quick-fix declares a float once",
		editor._create_variable_quickfix("boost_speed")
		and str((editor._current_sheet.variables.get("boost_speed", {}) as Dictionary).get("type")) == "float"
		and not editor._create_variable_quickfix("boost_speed"), true) and all_passed
	# End to end: a failing expression field grows the "+ var" button; creating the
	# variable re-lints clean and the button hides.
	var dialog: ACEParamsDialog = ACEParamsDialog.new()
	dialog.set_lint_context_provider(func() -> EventSheetResource: return editor._current_sheet)
	dialog.set_variable_creator(editor._create_variable_quickfix)
	var field_box: HBoxContainer = HBoxContainer.new()
	var expression_edit: LineEdit = LineEdit.new()
	field_box.add_child(expression_edit)
	expression_edit.text = "missing_thing + 1"
	dialog._validate_expression_field(expression_edit)
	var quickfix: Button = dialog._quickfix_buttons.get(expression_edit) as Button
	all_passed = _check("unknown identifier grows the + var button",
		quickfix != null and quickfix.visible and quickfix.text == "+ var missing_thing", true) and all_passed
	dialog._on_quickfix_pressed(expression_edit)
	all_passed = _check("the button creates the variable and the field lints clean",
		editor._current_sheet.variables.has("missing_thing") and not quickfix.visible, true) and all_passed
	field_box.free()
	editor.free()
	DirAccess.remove_absolute("user://rename_lib.tres")
	DirAccess.remove_absolute("user://rename_consumer.tres")

	# ── Row snippets: the clipboard text format is the file format ────────────────
	ProjectSettings.set_setting("eventsheets/project/snippets_dir", "user://snip_dir")
	for stale: String in EventSheetSnippetLibrary.list_snippets():
		DirAccess.remove_absolute(stale)
	var snippet_sheet: EventSheetResource = EventSheetResource.new()
	snippet_sheet.host_class = "Node"
	var snippet_event: EventRow = EventRow.new()
	snippet_event.trigger_provider_id = "Core"
	snippet_event.trigger_id = "OnProcess"
	var snippet_action: ACEAction = ACEAction.new()
	snippet_action.ace_id = "SetVar"
	snippet_action.codegen_template = "combo += 1"
	snippet_event.actions.append(snippet_action)
	snippet_sheet.events.append(snippet_event)
	var snippet_text: String = EventSheetSnippet.serialize_rows([snippet_event], snippet_sheet)
	var saved_path: String = EventSheetSnippetLibrary.save_snippet("Combo Bump", snippet_text)
	all_passed = _check("snippets file under snake_case names",
		saved_path, "user://snip_dir/combo_bump.txt") and all_passed
	all_passed = _check("the file IS the clipboard format",
		EventSheetSnippetLibrary.read_snippet(saved_path), snippet_text) and all_passed
	all_passed = _check("name collisions suffix instead of overwriting",
		EventSheetSnippetLibrary.save_snippet("Combo Bump", snippet_text), "user://snip_dir/combo_bump-2.txt") and all_passed
	all_passed = _check("the library lists sorted snippets",
		EventSheetSnippetLibrary.list_snippets(),
		PackedStringArray(["user://snip_dir/combo_bump-2.txt", "user://snip_dir/combo_bump.txt"])) and all_passed
	# Insert rides the normal snippet paste: fresh rows land on the open sheet.
	var insert_editor: EventSheetEditor = EventSheetEditor.new()
	var insert_sheet: EventSheetResource = EventSheetResource.new()
	insert_sheet.host_class = "Node"
	insert_editor.setup(insert_sheet)
	insert_editor.set_undo_redo_manager(NoopUndoManager.new())
	insert_editor._insert_snippet_path(saved_path)
	all_passed = _check("insert appends the snippet's rows",
		insert_sheet.events.size() == 1 and insert_sheet.events[0] is EventRow, true) and all_passed
	all_passed = _check("inserted events never share the source uid",
		(insert_sheet.events[0] as EventRow).event_uid == snippet_event.event_uid, false) and all_passed
	ProjectSettings.set_setting("eventsheets/project/snippets_dir", null)
	DirAccess.remove_absolute("user://snip_dir/combo_bump.txt")
	DirAccess.remove_absolute("user://snip_dir/combo_bump-2.txt")

	# ── Bulk operations on a selection ────────────────────────────────────────────
	var bulk_sheet: EventSheetResource = insert_editor._current_sheet
	var bulk_rows: Array = []
	for index in 3:
		var bulk_event: EventRow = EventRow.new()
		bulk_event.trigger_provider_id = "Core"
		bulk_event.trigger_id = "OnProcess"
		bulk_sheet.events.append(bulk_event)
		bulk_rows.append(bulk_event)
	insert_editor._bulk_set_enabled_on(bulk_rows)
	all_passed = _check("bulk disable lands uniformly",
		not (bulk_rows[0] as EventRow).enabled and not (bulk_rows[2] as EventRow).enabled, true) and all_passed
	insert_editor._bulk_set_enabled_on(bulk_rows)
	all_passed = _check("bulk toggle re-enables uniformly",
		(bulk_rows[0] as EventRow).enabled and (bulk_rows[2] as EventRow).enabled, true) and all_passed
	var before_count: int = bulk_sheet.events.size()
	insert_editor._bulk_duplicate_rows(bulk_rows)
	all_passed = _check("bulk duplicate copies each row in place",
		bulk_sheet.events.size(), before_count + 3) and all_passed
	var first_duplicate: EventRow = bulk_sheet.events[bulk_sheet.events.find(bulk_rows[0]) + 1] as EventRow
	all_passed = _check("duplicates re-bake their event uids",
		first_duplicate.event_uid == (bulk_rows[0] as EventRow).event_uid, false) and all_passed
	# Same-parent rail: a top-level row + a sub-event can't be grouped together.
	var nested_parent: EventRow = bulk_rows[0] as EventRow
	var nested_child: EventRow = EventRow.new()
	nested_parent.sub_events.append(nested_child)
	all_passed = _check("mixed-parent selections refuse to group",
		insert_editor._bulk_group_rows([bulk_rows[1], nested_child]).is_empty(), false) and all_passed
	var group_problem: String = insert_editor._bulk_group_rows([bulk_rows[1], bulk_rows[2]])
	var grouped: EventGroup = null
	for row: Variant in bulk_sheet.events:
		if row is EventGroup:
			grouped = row
	all_passed = _check("same-parent selections group in order",
		group_problem.is_empty() and grouped != null and grouped.events.size() == 2
		and grouped.events[0] == bulk_rows[1] and grouped.events[1] == bulk_rows[2], true) and all_passed
	insert_editor.free()

	# ── Session restore: tabs survive a restart ──────────────────────────────────
	var session_a: EventSheetResource = EventSheetResource.new()
	session_a.host_class = "Node"
	ResourceSaver.save(session_a, "user://session_a.tres")
	var session_b: EventSheetResource = EventSheetResource.new()
	session_b.host_class = "Node"
	ResourceSaver.save(session_b, "user://session_b.tres")
	var session_editor: EventSheetEditor = EventSheetEditor.new()
	session_editor.setup(ResourceLoader.load("user://session_a.tres", "", ResourceLoader.CACHE_MODE_IGNORE))
	session_editor.set_undo_redo_manager(NoopUndoManager.new())
	session_editor._open_sheet_in_tab(ResourceLoader.load("user://session_b.tres", "", ResourceLoader.CACHE_MODE_IGNORE), "user://session_b.tres")
	session_editor._session._session_tracking = true
	session_editor._persist_session()
	var written: ConfigFile = ConfigFile.new()
	written.load("user://eventsheets_session.cfg")
	all_passed = _check("sessions persist saved-tab paths + the active index",
		PackedStringArray(written.get_value("session", "paths", PackedStringArray()))
		== PackedStringArray(["user://session_a.tres", "user://session_b.tres"])
		and int(written.get_value("session", "active", -1)) == 1, true) and all_passed
	session_editor.free()
	DirAccess.remove_absolute("user://session_b.tres")
	var restored_editor: EventSheetEditor = EventSheetEditor.new()
	restored_editor.setup(null)
	restored_editor.set_undo_redo_manager(NoopUndoManager.new())
	restored_editor._restore_session()
	all_passed = _check("restore reopens existing sheets and skips deleted ones",
		restored_editor.get_open_tab_count() == 2
		and restored_editor._current_sheet_path == "user://session_a.tres", true) and all_passed
	ProjectSettings.set_setting("eventsheets/editor/restore_session", false)
	var gated_editor: EventSheetEditor = EventSheetEditor.new()
	gated_editor.setup(null)
	gated_editor.set_undo_redo_manager(NoopUndoManager.new())
	gated_editor._restore_session()
	all_passed = _check("the setting gates session restore",
		gated_editor.get_open_tab_count(), 1) and all_passed
	ProjectSettings.set_setting("eventsheets/editor/restore_session", null)
	gated_editor.free()

	# ── Canvas asset drops with intent ────────────────────────────────────────────
	all_passed = _check("file payloads resolve to droppable assets only",
		EventSheetViewport._resolve_dropped_asset_paths({"type": "files", "files": ["res://a.tscn", "res://b.png", "res://c.ogg"]}),
		PackedStringArray(["res://a.tscn", "res://c.ogg"])) and all_passed
	all_passed = _check("non-file payloads resolve to nothing",
		EventSheetViewport._resolve_dropped_asset_paths({"type": "nodes", "nodes": []}), PackedStringArray()) and all_passed
	var drop_event: EventRow = EventRow.new()
	drop_event.trigger_provider_id = "Core"
	drop_event.trigger_id = "OnProcess"
	restored_editor._current_sheet.events.append(drop_event)
	restored_editor._apply_asset_drop(drop_event, PackedStringArray(["res://level.tscn", "res://jump.ogg"]))
	all_passed = _check("dropped assets become pre-filled actions",
		drop_event.actions.size() == 2
		and (drop_event.actions[0] as ACEAction).ace_id == "SpawnSceneAt"
		and str((drop_event.actions[0] as ACEAction).params.get("path")) == "\"res://level.tscn\""
		and (drop_event.actions[1] as ACEAction).ace_id == "PlaySound", true) and all_passed
	all_passed = _check("multi-line drop templates bake a fresh uid",
		(drop_event.actions[0] as ACEAction).codegen_template.contains("{uid}"), false) and all_passed
	restored_editor._apply_asset_drop(null, PackedStringArray(["res://x.tscn"]))
	all_passed = _check("empty-space drops only hint",
		drop_event.actions.size(), 2) and all_passed
	all_passed = _check("unknown extensions build no action",
		restored_editor._action_for_asset("res://image.png") == null, true) and all_passed
	restored_editor.free()
	DirAccess.remove_absolute("user://session_a.tres")
	DirAccess.remove_absolute("user://eventsheets_session.cfg")

	# ── Loop closers: attach where you're looking, run what uses the sheet ────────
	all_passed = _check("reverse scene lookup pairs the showcase",
		EventSheetProjectDoctor.scenes_attaching("res://demo/showcase/showcase_carousel.gd"),
		PackedStringArray(["res://demo/showcase/showcase_carousel.tscn"])) and all_passed
	all_passed = _check("reverse scene lookup pairs the demo player",
		EventSheetProjectDoctor.scenes_attaching("res://demo/sheets/player_generated.gd"),
		PackedStringArray(["res://demo/scenes/player.tscn"])) and all_passed
	var behavior_sheet: EventSheetResource = EventSheetResource.new()
	behavior_sheet.behavior_mode = true
	behavior_sheet.host_class = "Node2D"
	ResourceSaver.save(behavior_sheet, "user://attach_probe.tres")
	var attach_sheet: EventSheetResource = ResourceLoader.load("user://attach_probe.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	var host: Node2D = Node2D.new()
	var attach_result: Dictionary = EventSheetAuthorLoop.attach_behavior(attach_sheet, host)
	all_passed = _check("attach compiles + parents the behavior child",
		bool(attach_result.get("ok")) and host.get_child_count() == 1
		and host.get_child(0).get_script() != null and host.get_child(0).owner == host, true) and all_passed
	all_passed = _check("matching hosts attach without a warning note",
		str(attach_result.get("message")).contains("expects"), false) and all_passed
	var wrong_host: Node = Node.new()
	var mismatch_result: Dictionary = EventSheetAuthorLoop.attach_behavior(attach_sheet, wrong_host)
	all_passed = _check("host mismatch warns but still attaches",
		bool(mismatch_result.get("ok")) and str(mismatch_result.get("message")).contains("expects a Node2D"), true) and all_passed
	var unsaved_behavior: EventSheetResource = EventSheetResource.new()
	unsaved_behavior.behavior_mode = true
	all_passed = _check("unsaved behavior sheets are refused with the fix named",
		str(EventSheetAuthorLoop.attach_behavior(unsaved_behavior, host).get("message")).contains("Save the sheet"), true) and all_passed
	all_passed = _check("non-behavior sheets are refused",
		bool(EventSheetAuthorLoop.attach_behavior(EventSheetResource.new(), host).get("ok")), false) and all_passed
	host.free()
	wrong_host.free()
	DirAccess.remove_absolute("user://attach_probe.tres")
	DirAccess.remove_absolute("user://attach_probe_generated.gd")
	# Run-from-sheet routes behaviors to the Test Bench instead of hunting scenes.
	var run_editor: EventSheetEditor = EventSheetEditor.new()
	var run_sheet: EventSheetResource = EventSheetResource.new()
	run_sheet.behavior_mode = true
	run_sheet.host_class = "Node2D"
	run_editor.setup(run_sheet)
	run_editor.set_undo_redo_manager(NoopUndoManager.new())
	run_editor._run_from_sheet()
	all_passed = _check("run-from-sheet guards behaviors without side effects",
		run_editor.get_open_tab_count(), 1) and all_passed
	run_editor.free()

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] tedium_test: %s" % label)
		return true
	print("[FAIL] tedium_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
