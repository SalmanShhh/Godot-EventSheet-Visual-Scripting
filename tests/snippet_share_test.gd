# EventForge — Shareable snippets (system-clipboard text, cross-project paste)
#
# Rows serialize to portable versioned text (no script paths/UIDs) and paste back into a
# different sheet/editor: structure and params survive, pasted events get fresh UIDs, and
# sheet variables the snippet references are auto-created (never overwritten). Tests drive
# serialize/deserialize and the dock's _paste_snippet_text directly so no OS clipboard is
# needed (headless-safe).
@tool
extends RefCounted
class_name SnippetShareTest

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

	# Source sheet: a group holding an event (trigger + condition + addon-style action with
	# a baked codegen template + in-flow GDScript), plus a standalone comment.
	var source_sheet: EventSheetResource = EventSheetResource.new()
	source_sheet.variables = {"health": {"type": "int", "default": 100, "exported": true}}
	var group: EventGroup = EventGroup.new()
	group.group_name = "Combat"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "Always"
	event.conditions.append(condition)
	var action: ACEAction = ACEAction.new()
	action.provider_id = "DemoHealthAddon"
	action.ace_id = "method:heal"
	action.params = {"amount": 5}
	action.codegen_template = "health += {amount}"
	event.actions.append(action)
	var inline_block: RawCodeRow = RawCodeRow.new()
	inline_block.code = "print(health)"
	event.actions.append(inline_block)
	group.events.append(event)
	source_sheet.events.append(group)
	var comment: CommentRow = CommentRow.new()
	comment.text = "shared wisdom"
	source_sheet.events.append(comment)
	var original_uid: String = event.event_uid

	# Serialize → portable text with markers; addon provider listed as a dependency.
	var snippet_text: String = EventSheetSnippet.serialize_rows([group, comment], source_sheet)
	all_passed = _check("snippet text carries the v1 marker", EventSheetSnippet.is_snippet_text(snippet_text), true) and all_passed
	all_passed = _check("plain text is not mistaken for a snippet", EventSheetSnippet.is_snippet_text("hello"), false) and all_passed
	var parsed: Dictionary = EventSheetSnippet.deserialize(snippet_text)
	all_passed = _check("snippet lists its addon providers", (parsed.get("providers", []) as Array).has("DemoHealthAddon"), true) and all_passed
	all_passed = _check("snippet carries the referenced variable", (parsed.get("required_variables", {}) as Dictionary).has("health"), true) and all_passed

	# Paste into a DIFFERENT, empty sheet via the dock path.
	var editor: EventSheetEditor = EventSheetEditor.new()
	var target_sheet: EventSheetResource = EventSheetResource.new()
	editor.setup(target_sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	all_passed = _check("garbage text falls through to the internal clipboard", editor._paste_snippet_text("not a snippet"), false) and all_passed
	all_passed = _check("snippet text pastes", editor._paste_snippet_text(snippet_text), true) and all_passed
	all_passed = _check("both rows arrived", target_sheet.events.size(), 2) and all_passed
	var pasted_group: EventGroup = target_sheet.events[0] as EventGroup
	all_passed = _check("group structure survives", pasted_group != null and pasted_group.group_name == "Combat", true) and all_passed
	var pasted_event: EventRow = (pasted_group.events[0] if pasted_group != null and not pasted_group.events.is_empty() else null) as EventRow
	all_passed = _check("event structure survives", pasted_event != null and pasted_event.trigger_id == "OnProcess" and pasted_event.conditions.size() == 1, true) and all_passed
	if pasted_event != null:
		all_passed = _check("pasted event gets a fresh UID",
			not pasted_event.event_uid.is_empty() and pasted_event.event_uid != original_uid, true) and all_passed
		var pasted_action: ACEAction = pasted_event.actions[0] as ACEAction
		all_passed = _check("params survive the round-trip", pasted_action != null and int(pasted_action.params.get("amount", 0)) == 5, true) and all_passed
		all_passed = _check("baked codegen template survives (compiles without the addon)",
			ActionCodegen.generate_action(pasted_action) if pasted_action != null else "", "health += 5") and all_passed
		all_passed = _check("in-flow GDScript survives",
			pasted_event.actions.size() == 2 and pasted_event.actions[1] is RawCodeRow and (pasted_event.actions[1] as RawCodeRow).code == "print(health)", true) and all_passed
	all_passed = _check("missing referenced variable was auto-created",
		target_sheet.variables.has("health") and int((target_sheet.variables["health"] as Dictionary).get("default", 0)) == 100, true) and all_passed

	# Existing variables are never overwritten by a paste.
	var second_editor: EventSheetEditor = EventSheetEditor.new()
	var guarded_sheet: EventSheetResource = EventSheetResource.new()
	guarded_sheet.variables = {"health": {"type": "int", "default": 1, "exported": false}}
	second_editor.setup(guarded_sheet)
	second_editor.set_undo_redo_manager(NoopUndoManager.new())
	second_editor._paste_snippet_text(snippet_text)
	all_passed = _check("existing variable is not overwritten",
		int((guarded_sheet.variables["health"] as Dictionary).get("default", 0)), 1) and all_passed
	second_editor.free()

	# Copy collector: selecting a group (which cascades to its children) serializes only the
	# top-most row — children travel inside the parent. (Refresh first: the Noop undo manager
	# used in tests skips the snapshot-restore that refreshes the viewport in the editor.)
	editor._refresh_after_edit()
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var group_index: int = -1
	var flat: Array[Dictionary] = viewport.get_flat_rows()
	for i in range(flat.size()):
		var row_data: EventRowData = flat[i].get("row")
		if row_data != null and row_data.source_resource == pasted_group:
			group_index = i
	viewport._select_from_click(group_index, -1, false)
	var top_level: Array = editor._top_level_selected_resources()
	all_passed = _check("cascade selection serializes only the top-most row",
		top_level.size() == 1 and top_level[0] == pasted_group, true) and all_passed
	editor.free()

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] snippet_share_test: %s" % label)
		return true
	print("[FAIL] snippet_share_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
