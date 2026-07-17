# Godot EventSheets - event-sheet-familiarity batch: group descriptions, slow double-click editing,
# variable-rename refactoring, and commit-time guardrails (auto-fix or block bad input).
@tool
class_name UxGuardrailsTest
extends RefCounted


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false
	func undo() -> void: pass
	func redo() -> void: pass
	func clear_history() -> void: pass


static func run() -> bool:
	var all_passed: bool = true

	# ── Identifier guardrails ────────────────────────────────────────────────
	all_passed = _check("spaces auto-correct", EventSheetIdentifierRules.sanitize("my var"), "my_var") and all_passed
	all_passed = _check("digit-led names get prefixed", EventSheetIdentifierRules.sanitize("2nd"), "_2nd") and all_passed
	all_passed = _check("junk is dropped", EventSheetIdentifierRules.sanitize("hp!!"), "hp") and all_passed
	all_passed = _check("keywords are invalid", EventSheetIdentifierRules.is_valid("class"), false) and all_passed
	all_passed = _check("good names are valid", EventSheetIdentifierRules.is_valid("player_hp"), true) and all_passed

	# ── Group description: renders as a second line, inline-editable ────────
	var sheet: EventSheetResource = EventSheetResource.new()
	var group: EventGroup = EventGroup.new()
	group.name = "Gameplay"
	group.group_name = "Gameplay"
	group.description = "Everything about the player"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var act: ACEAction = ACEAction.new()
	act.provider_id = "Test"
	act.ace_id = "setup"
	act.codegen_template = "setup({target}, hp)"
	act.params = {}
	event.actions.append(act)
	group.events.append(event)
	sheet.events.append(group)
	sheet.variables = {"hp": {"type": "int", "default": 1, "exported": false}}
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var viewport: EventSheetViewport = editor.get_viewport_control()
	# Global variables render as rows above the group - locate the group by resource.
	var group_row: EventRowData = null
	var group_row_index: int = -1
	for index in range(viewport.get_flat_rows().size()):
		var flat_row: EventRowData = viewport.get_flat_rows()[index].get("row")
		if flat_row != null and flat_row.source_resource == group:
			group_row = flat_row
			group_row_index = index
	all_passed = _check("description renders as a second line", group_row.line_count, 2) and all_passed
	var description_span: SemanticSpan = group_row.spans[group_row.spans.size() - 1]
	all_passed = _check("description span is inline-editable",
		str((description_span.metadata as Dictionary).get("edit_kind", "")), "group_description") and all_passed
	editor._on_viewport_span_edit_requested(group_row, "group_description", group.description, "The core loop")
	all_passed = _check("editing the description applies", group.description, "The core loop") and all_passed

	# Snippets carry descriptions.
	var snippet: String = EventSheetSnippet.serialize_rows([group], sheet)
	var parsed: Dictionary = EventSheetSnippet.deserialize(snippet)
	var pasted_group: EventGroup = null
	for row in parsed.get("rows", []):
		if row is EventGroup:
			pasted_group = row
	all_passed = _check("group descriptions travel in snippets",
		pasted_group != null and pasted_group.description == "The core loop", true) and all_passed

	# ── Slow double-click (injected clock) ───────────────────────────────────
	# The editable description span is last; slow-clicking it is what begins inline editing.
	var group_title_span: int = group_row.spans.size() - 1
	all_passed = _check("first slow click never edits",
		viewport._maybe_begin_slow_edit(group_row_index, group_title_span, 10000), false) and all_passed
	all_passed = _check("a fast second click defers to double-click",
		viewport._maybe_begin_slow_edit(group_row_index, group_title_span, 10200), false) and all_passed
	viewport._maybe_begin_slow_edit(group_row_index, group_title_span, 20000)
	all_passed = _check("a slow second click begins editing",
		viewport._maybe_begin_slow_edit(group_row_index, group_title_span, 20700), true) and all_passed
	viewport._maybe_begin_slow_edit(group_row_index, group_title_span, 40000)
	all_passed = _check("too-late clicks restart instead of editing",
		viewport._maybe_begin_slow_edit(group_row_index, group_title_span, 42500), false) and all_passed

	# ── Variable rename refactors every embedded reference ──────────────────
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "hp += 1\nprint(hp)"
	sheet.events.append(block)
	var inflow: RawCodeRow = RawCodeRow.new()
	inflow.code = "if hp > 0:\n\thp -= 1"
	event.actions.append(inflow)
	var pick: PickFilter = PickFilter.new()
	pick.collection_kind = PickFilter.CollectionKind.EXPRESSION
	pick.collection_value = "range(hp)"
	pick.predicate_expression = "item < hp"
	event.pick_filters.append(pick)
	act.params = {"target": "hp + 5", "label": "hp display"}
	editor._refresh_after_edit()
	editor._on_variable_dialog_confirmed("health", "int", 1, "global", {"editing": true, "original_name": "hp"}, false, false)
	all_passed = _check("global variable renamed", sheet.variables.has("health") and not sheet.variables.has("hp"), true) and all_passed
	all_passed = _check("class-level blocks updated", block.code, "health += 1\nprint(health)") and all_passed
	all_passed = _check("in-flow blocks updated", inflow.code, "if health > 0:\n\thealth -= 1") and all_passed
	all_passed = _check("pick filters updated",
		pick.collection_value == "range(health)" and pick.predicate_expression == "item < health", true) and all_passed
	all_passed = _check("string params updated (whole-word)",
		str(act.params.get("target")) == "health + 5" and str(act.params.get("label")) == "health display", true) and all_passed
	all_passed = _check("templates rename outside placeholders",
		act.codegen_template, "setup({target}, health)") and all_passed
	var rename_output: String = str(SheetCompiler.compile(sheet, "user://eventsheets_rename.gd").get("output", ""))
	all_passed = _check("codegen still references the new name",
		rename_output.contains("setup(health + 5, health)"), true) and all_passed
	# This assert exposed that GROUP EVENTS never compiled at all - locked in now.
	all_passed = _check("group events compile inline", rename_output.contains("func _ready()"), true) and all_passed
	group.enabled = false
	all_passed = _check("disabled groups drop their children (event-sheet semantics)",
		str(SheetCompiler.compile(sheet, "user://eventsheets_rename_off.gd").get("output", "")).contains("setup("), false) and all_passed
	group.enabled = true

	# ── Commit guardrails ────────────────────────────────────────────────────
	editor._on_variable_dialog_confirmed("my speed", "int", 1, "global", {}, false, false)
	all_passed = _check("variable names auto-correct on commit", sheet.variables.has("my_speed"), true) and all_passed
	var before_count: int = sheet.variables.size()
	editor._on_variable_dialog_confirmed("class", "int", 1, "global", {}, false, false)
	all_passed = _check("keyword names are blocked", sheet.variables.size(), before_count) and all_passed

	editor._struct_rows._ensure_enum_dialog()
	var guarded_enum: EnumRow = EnumRow.new()
	sheet.events.append(guarded_enum)
	editor._struct_rows._enum_target = guarded_enum
	editor._struct_rows._enum_name_edit.text = "player state"
	editor._struct_rows._clear_enum_member_rows()
	editor._struct_rows._add_enum_member_row("idle mode")
	editor._struct_rows._add_enum_member_row("RUN = 4")
	editor._struct_rows._on_enum_dialog_confirmed()
	all_passed = _check("enum names auto-correct",
		guarded_enum.enum_name == "player_state" and guarded_enum.members[0] == "idle_mode" and guarded_enum.members[1] == "RUN = 4", true) and all_passed

	editor._ensure_raw_code_dialog()
	var guarded_block: RawCodeRow = RawCodeRow.new()
	guarded_block.code = "print(1)"
	editor._raw_code_target = guarded_block
	editor._raw_code_in_flow = true
	editor._raw_code_edit.text = "health +"
	editor._on_raw_code_dialog_confirmed()
	all_passed = _check("broken GDScript never commits", guarded_block.code, "print(1)") and all_passed
	all_passed = _check("the dialog keeps the user's text for fixing", editor._raw_code_target, guarded_block) and all_passed

	var params_dialog: ACEParamsDialog = ACEParamsDialog.new()
	params_dialog.set_lint_context_provider(func() -> EventSheetResource: return sheet)
	var field_container: Control = params_dialog._create_expression_field("amount", "health +")
	all_passed = _check("invalid expressions block the params apply",
		params_dialog._first_invalid_expression() != null, true) and all_passed
	for child in field_container.get_children():
		if child is CodeEdit:
			(child as CodeEdit).text = "health + 1"
	all_passed = _check("valid expressions pass the gate", params_dialog._first_invalid_expression(), null) and all_passed
	field_container.free()
	editor.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] ux_guardrails_test: %s" % label)
		return true
	print("[FAIL] ux_guardrails_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
