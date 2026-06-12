# Godot EventSheets — tedium-reduction arc (docs/TEDIUM-REDUCTION-SPEC.md).
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

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] tedium_test: %s" % label)
		return true
	print("[FAIL] tedium_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
