# Godot EventSheets - batch param edit (the C3 edit-many reflex): a condition/action that
# appears more than once across the selected rows edits ONCE - the dialog's values apply
# to every matching instance in a single undo step. Pins: the enumeration walk (same
# provider + ace id groups, sub-events and groups descend, singletons excluded), the
# apply-to-all VALUES (every target's params update, non-matching slots untouched), and
# the stale-slot guard (an index whose ACE changed since the menu opened is skipped).
@tool
class_name BatchParamEditTest
extends RefCounted


class NoopUndoManager:
	extends RefCounted
	func create_action(_a = null) -> void: pass
	func add_do_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func add_undo_method(_a = null, _b = null, _c = null, _d = null, _e = null) -> void: pass
	func commit_action() -> void: pass
	func has_undo() -> bool: return false
	func has_redo() -> bool: return false


static func _log_action(message_value: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "ConsoleLog"
	action.params = {"message": message_value, "level": "print"}
	return action


static func _other_action() -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "PushWarning"
	action.params = {"message": "\"keep me\""}
	return action


static func run() -> bool:
	var all_passed: bool = true

	var first: EventRow = EventRow.new()
	first.actions.append(_log_action("\"one\""))
	first.actions.append(_other_action())
	var second: EventRow = EventRow.new()
	second.actions.append(_log_action("\"two\""))
	var nested: EventRow = EventRow.new()
	nested.actions.append(_log_action("\"three\""))
	second.sub_events.append(nested)
	var group: EventGroup = EventGroup.new()
	var grouped: EventRow = EventRow.new()
	grouped.actions.append(_log_action("\"four\""))
	group.events.append(grouped)

	# ---- enumeration: only the repeated ACE groups, walking sub-events + group children ----
	var groups: Array = EventSheetACEApply.batch_edit_groups([first, second, group])
	all_passed = _check("only the repeated ACE forms a batch group (the singleton is excluded)", groups.size(), 1) and all_passed
	var batch: Dictionary = groups[0] if not groups.is_empty() else {}
	all_passed = _check("the group carries its identity", "%s.%s/%s" % [batch.get("provider_id", ""), batch.get("ace_id", ""), batch.get("kind", "")], "Core.ConsoleLog/action") and all_passed
	all_passed = _check("all four instances are targets (sub-event + grouped included)", (batch.get("targets", []) as Array).size(), 4) and all_passed

	# ---- apply-to-all through the dock funnel: one call, every target's VALUES update ----
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.events.append(first)
	sheet.events.append(second)
	sheet.events.append(group)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var definition: ACEDefinition = editor._find_definition("Core", "ConsoleLog")
	all_passed = _check("the builtin ConsoleLog definition resolves", definition != null, true) and all_passed
	# Stale-slot guard setup: swap the grouped instance for a DIFFERENT ACE after enumeration,
	# as if the user edited it between opening the menu and pressing OK.
	grouped.actions[0] = _other_action()
	editor._apply_ace_definition(definition, {"message": "\"batched\"", "level": "push_warning"}, {
		"mode": "batch_edit_params",
		"batch_kind": "action",
		"batch_targets": batch.get("targets", []),
		"batch_count": 4
	})
	all_passed = _check("the first instance took the new message", str((first.actions[0] as ACEAction).params.get("message", "")), "\"batched\"") and all_passed
	all_passed = _check("the second instance took the new level", str((second.actions[0] as ACEAction).params.get("level", "")), "push_warning") and all_passed
	all_passed = _check("the sub-event instance updated too", str((nested.actions[0] as ACEAction).params.get("message", "")), "\"batched\"") and all_passed
	all_passed = _check("a non-matching action in the same row is untouched", str((first.actions[1] as ACEAction).params.get("message", "")), "\"keep me\"") and all_passed
	all_passed = _check("the stale slot (ACE swapped after enumeration) is skipped, never corrupted", str((grouped.actions[0] as ACEAction).ace_id), "PushWarning") and all_passed
	all_passed = _check("replaced instances re-bake the codegen template", (first.actions[0] as ACEAction).codegen_template.is_empty(), false) and all_passed

	# ---- per-param apply: unchecked keys keep each instance's own value ----
	# Retune only "level" across the survivors; "message" stays per-instance.
	editor._apply_ace_definition(definition, {"message": "\"ignored\"", "level": "print_rich"}, {
		"mode": "batch_edit_params",
		"batch_kind": "action",
		"batch_targets": batch.get("targets", []),
		"batch_count": 4,
		"batch_apply_params": ["level"]
	})
	all_passed = _check("the checked param applies everywhere", str((first.actions[0] as ACEAction).params.get("level", "")), "print_rich") and all_passed
	all_passed = _check("the unchecked param keeps the instance's own value", str((first.actions[0] as ACEAction).params.get("message", "")), "\"batched\"") and all_passed
	all_passed = _check("the sub-event instance also keeps its own unchecked value", str((nested.actions[0] as ACEAction).params.get("message", "")), "\"batched\"") and all_passed

	# ---- Select All Matching: the walk + the viewport multi-select ----
	# After the batch apply: ConsoleLog lives on first, second, and nested (grouped was
	# swapped to PushWarning by the stale-slot setup). The walk descends sub-events + groups.
	var matches: Array = EventSheetACEApply.matching_event_rows(sheet.events, "Core", "ConsoleLog")
	all_passed = _check("matching walk finds every user (sub-event included, swapped row excluded)",
		matches, [first, second, nested]) and all_passed
	all_passed = _check("the group's swapped row matches its NEW ace",
		EventSheetACEApply.matching_event_rows(sheet.events, "Core", "PushWarning"), [first, grouped]) and all_passed
	var select_viewport: EventSheetViewport = editor.get_viewport_control()
	var selected_count: int = select_viewport.select_resources(matches)
	all_passed = _check("select_resources selects every match", selected_count, 3) and all_passed
	all_passed = _check("the selection lands on the viewport rows", select_viewport.get_selected_rows().size() >= 3, true) and all_passed
	editor.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] batch_param_edit_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
