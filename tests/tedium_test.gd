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

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] tedium_test: %s" % label)
		return true
	print("[FAIL] tedium_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
