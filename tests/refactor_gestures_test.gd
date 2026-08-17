# Godot EventSheets - the reverse refactor gestures: Wrap, Unwrap, Inline, Duplicate as Variant,
# and snippets with blanks.
#
# Every one is driven through the REAL editor path - the dock's apply funnel, the menu glue the
# context menus call, the dialog objects themselves - and asserted on the resulting SHEET plus the
# GDScript it compiles to, which is the only thing a user's game runs.
#
# The load-bearing pins are the byte ones, because a refactor that changes behaviour is worse than
# no refactor at all:
#   • wrap then unwrap re-emits the sheet's GDScript BYTE-IDENTICALLY,
#   • extract then inline re-emits it byte-identically too (inline really is the inverse),
#   • undo after a wrap re-emits it byte-identically (one undo step, fully reversible).
# The rest pin the refusals - a gapped or non-trailing wrap, an argument inline cannot re-point,
# a blank left empty - because each refusal exists to stop a silent reorder or a broken row.
@tool
class_name RefactorGesturesTest
extends RefCounted

const COMPILE_PATH := "user://eventforge_refactor_gestures.gd"


## The editor's undo manager as the EDITOR's own is shaped: the dock funnels edits through
## create_action / add_do_method / add_undo_method / commit_action, and the commit RUNS the do
## method (that is what replaces the sheet with a snapshot duplicate). A plain UndoRedo takes
## Callables instead of (object, method, arg) and would silently register nothing.
class RecordingUndoManager:
	extends RefCounted
	var _pending_do: Array = []
	var _pending_undo: Array = []
	var _stack: Array = []

	func create_action(_action_name: Variant = null) -> void:
		_pending_do = []
		_pending_undo = []

	func add_do_method(target: Variant = null, method: Variant = null, argument: Variant = null) -> void:
		_pending_do = [target, method, argument]

	func add_undo_method(target: Variant = null, method: Variant = null, argument: Variant = null) -> void:
		_pending_undo = [target, method, argument]

	func commit_action() -> void:
		_stack.append(_pending_undo)
		if _pending_do.size() == 3:
			(_pending_do[0] as Object).call(str(_pending_do[1]), _pending_do[2])

	func undo() -> void:
		if _stack.is_empty():
			return
		var entry: Array = _stack.pop_back()
		if entry.size() == 3:
			(entry[0] as Object).call(str(entry[1]), entry[2])

	func redo() -> void:
		pass

	func has_undo() -> bool:
		return not _stack.is_empty()

	func has_redo() -> bool:
		return false

	func clear_history() -> void:
		_stack.clear()


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_wrap_and_unwrap() and all_passed
	all_passed = _test_wrap_refusals() and all_passed
	all_passed = _test_wrap_refuses_a_trigger() and all_passed
	all_passed = _test_unwrap_keeps_what_the_guard_carried() and all_passed
	all_passed = _test_inline_leaves_displayed_text_alone() and all_passed
	all_passed = _test_unwrap_keeps_run_order() and all_passed
	all_passed = _test_inline_is_the_inverse_of_extract() and all_passed
	all_passed = _test_inline_everywhere_and_remove() and all_passed
	all_passed = _test_duplicate_as_variant() and all_passed
	all_passed = _test_snippet_blanks() and all_passed
	all_passed = _test_menu_entries() and all_passed
	if all_passed:
		print("[PASS] refactor_gestures_test: wrap, unwrap, inline, variant and snippet blanks driven through their real paths")
	return all_passed

# ── Wrap / Unwrap ────────────────────────────────────────────────────────────


static func _test_wrap_and_unwrap() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = _tick_event(["\"run\"", "\"shake\"", "\"step\""])
	sheet.events.append(event)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(RecordingUndoManager.new())
	var before: String = _compile(sheet)
	all_passed = _check("the flat event emits its three actions", before.count("print("), 3) and all_passed

	# The wrap, through the dock's apply funnel - the same call the ACE picker makes, carrying the
	# actions to re-parent. One undoable edit builds the guard AND moves the actions.
	var always: ACEDefinition = editor._find_definition("Core", "Always")
	all_passed = _check("the builtin Always condition resolves", always != null, true) and all_passed
	editor._apply_ace_definition(always, {}, {
		"mode": "new_sub_condition_event",
		"selected_resource": event,
		"wrap_actions": event.actions.duplicate(),
	})
	var wrapped_event: EventRow = editor._current_sheet.events[0] as EventRow
	all_passed = _check("the wrapped event keeps no actions of its own", wrapped_event.actions.size(), 0) and all_passed
	all_passed = _check("one fresh guarded sub-event holds them", wrapped_event.sub_events.size(), 1) and all_passed
	var guard: EventRow = wrapped_event.sub_events[0] as EventRow
	all_passed = _check("the guard carries the picked condition", (guard.conditions[0] as ACECondition).ace_id, "Always") and all_passed
	all_passed = _check("and all three actions, in order", guard.actions.size(), 3) and all_passed
	all_passed = _check("the actions kept their order",
		str((guard.actions[2] as ACEAction).params.get("message", "")), "\"step\"") and all_passed
	var wrapped_source: String = _compile(editor._current_sheet)
	all_passed = _check("the emitted code now guards them", wrapped_source.contains("if true:"), true) and all_passed

	# ONE undo step: the whole wrap comes back off, byte for byte.
	editor._undo_redo_adapter.undo()
	all_passed = _check("undo restores the sheet byte-for-byte", _compile(editor._current_sheet), before) and all_passed

	# Wrap again, then unwrap: the pair is a true round trip.
	var live: EventRow = editor._current_sheet.events[0] as EventRow
	editor._apply_ace_definition(always, {}, {
		"mode": "new_sub_condition_event",
		"selected_resource": live,
		"wrap_actions": live.actions.duplicate(),
	})
	var to_unwrap: EventRow = (editor._current_sheet.events[0] as EventRow).sub_events[0] as EventRow
	var before_unwrap: String = _compile(editor._current_sheet)
	editor._context_row = _row_data_for(to_unwrap)
	EventSheetRefactorMenu.unwrap_requested(editor)
	all_passed = _check("unwrap drops the empty shell", (editor._current_sheet.events[0] as EventRow).sub_events.size(), 0) and all_passed
	all_passed = _check("and hands the actions back to the parent", (editor._current_sheet.events[0] as EventRow).actions.size(), 3) and all_passed
	all_passed = _check("wrap then unwrap re-emits the sheet byte-for-byte", _compile(editor._current_sheet), before) and all_passed
	# Unwrap is the gesture that MOVES rows between parents, so its undo is the one most worth
	# pinning by bytes rather than by counts.
	editor._undo_redo_adapter.undo()
	all_passed = _check("undo after an unwrap restores the guard byte-for-byte",
		_compile(editor._current_sheet), before_unwrap) and all_passed
	editor.free()
	return all_passed


static func _test_wrap_refusals() -> bool:
	var all_passed: bool = true
	var event: EventRow = _tick_event(["\"a\"", "\"b\"", "\"c\""])
	all_passed = _check("wrapping every action is sound", EventSheetWrapUnwrap.wrap_refusal(event, event.actions.duplicate()), "") and all_passed
	all_passed = _check("so is the trailing run",
		EventSheetWrapUnwrap.wrap_refusal(event, [event.actions[1], event.actions[2]]), "") and all_passed
	all_passed = _check("a gapped selection is refused, with the reason",
		EventSheetWrapUnwrap.wrap_refusal(event, [event.actions[0], event.actions[2]]),
		"Can't wrap a gapped selection - the kept action in the middle would change run order. Select a contiguous run.") and all_passed
	all_passed = _check("so is a run that is not the last one (a guard runs after the actions above it)",
		EventSheetWrapUnwrap.wrap_refusal(event, [event.actions[0], event.actions[1]]),
		"Wrap takes the LAST run of actions (a guard runs after the actions above it). Select through the final action, or wrap them all.") and all_passed

	# Unwrap's refusals name what would be LOST.
	var sheet: EventSheetResource = EventSheetResource.new()
	var parent: EventRow = _tick_event([])
	var child: EventRow = EventRow.new()
	child.actions.append(_print_action("\"child\""))
	parent.sub_events.append(child)
	sheet.events.append(parent)
	all_passed = _check("a plain sub-event unwraps", EventSheetWrapUnwrap.unwrap_refusal(sheet, child), "") and all_passed
	all_passed = _check("a top-level event has nothing to unwrap into",
		EventSheetWrapUnwrap.unwrap_refusal(sheet, parent),
		"Unwrap lifts a sub-event's rows into the event above it - this row is already top-level.") and all_passed
	child.pick_filters.append(PickFilter.new())
	all_passed = _check("a For Each sub-event refuses - its rows would run once instead of per item",
		EventSheetWrapUnwrap.unwrap_refusal(sheet, child),
		"This sub-event is a loop (For Each) - lifting its rows out would run them once instead of per item.") and all_passed
	child.pick_filters.clear()
	var sibling: EventRow = EventRow.new()
	sibling.else_mode = EventRow.ElseMode.ELSE
	parent.sub_events.append(sibling)
	all_passed = _check("and one whose Else sits below it refuses too",
		EventSheetWrapUnwrap.unwrap_refusal(sheet, child),
		"The sub-event below is this one's Else - clear that Else first, then unwrap.") and all_passed
	return all_passed


## The picker's sub-event mode lists TRIGGERS as well as conditions, because an ordinary sub-event
## may have one. A WRAP may not: the compiler builds a sub-event's `if` out of its conditions alone,
## so a trigger-headed guard emits no guard at all and the wrapped actions would run unconditionally
## while the sheet showed them guarded. The refusal happens before anything moves.
static func _test_wrap_refuses_a_trigger() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = _tick_event(["\"run\"", "\"step\""])
	sheet.events.append(event)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(RecordingUndoManager.new())
	var before: String = _compile(editor._current_sheet)
	var trigger: ACEDefinition = editor._find_definition("Core", "OnProcess")
	all_passed = _check("the builtin every-frame trigger resolves", trigger != null, true) and all_passed
	if trigger != null:
		all_passed = _check("…and it really is a trigger", trigger.ace_type, ACEDefinition.ACEType.TRIGGER) and all_passed
		var live: EventRow = editor._current_sheet.events[0] as EventRow
		editor._apply_ace_definition(trigger, {}, {
			"mode": "new_sub_condition_event",
			"selected_resource": live,
			"wrap_actions": live.actions.duplicate(),
		})
		all_passed = _check("a wrap with a trigger picked is refused", (editor._current_sheet.events[0] as EventRow).sub_events.size(), 0) and all_passed
		all_passed = _check("…the actions stay where they were", (editor._current_sheet.events[0] as EventRow).actions.size(), 2) and all_passed
		all_passed = _check("…and the emitted code is byte-for-byte what it was",
			_compile(editor._current_sheet), before) and all_passed
	editor.free()
	return all_passed


## Unwrapping the FIRST sub-event appends its actions straight to the parent - but only when the
## guard carried nothing except its condition. A DISABLED guard holds code the author switched off,
## and a `With node` guard retargets every action it holds; merging either into the parent changes
## what the sheet does, so those travel in a carrier that keeps both.
static func _test_unwrap_keeps_what_the_guard_carried() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	var parent: EventRow = _tick_event(["\"first\""])
	var guard: EventRow = EventRow.new()
	guard.enabled = false
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "Always"
	condition.codegen_template = "true"
	guard.conditions.append(condition)
	guard.actions.append(_print_action("\"switched off\""))
	parent.sub_events.append(guard)
	sheet.events.append(parent)
	var before: String = _compile(sheet)
	all_passed = _check("a disabled guard unwraps", EventSheetWrapUnwrap.unwrap_event(sheet, guard) >= 0, true) and all_passed
	all_passed = _check("…without switching its actions back on", _compile(sheet), before) and all_passed
	all_passed = _check("…because they travel in a carrier that is still off",
		(parent.sub_events[0] as EventRow).enabled, false) and all_passed
	all_passed = _check("…and the parent kept only its own action", parent.actions.size(), 1) and all_passed

	var scoped_sheet: EventSheetResource = EventSheetResource.new()
	var scoped_parent: EventRow = _tick_event(["\"first\""])
	var scoped_guard: EventRow = EventRow.new()
	scoped_guard.with_node_target = "$Enemy"
	scoped_guard.actions.append(_print_action("\"scoped\""))
	scoped_parent.sub_events.append(scoped_guard)
	scoped_sheet.events.append(scoped_parent)
	var scoped_before: String = _compile(scoped_sheet)
	all_passed = _check("a With node guard unwraps", EventSheetWrapUnwrap.unwrap_event(scoped_sheet, scoped_guard) >= 0, true) and all_passed
	all_passed = _check("…keeping the node its actions were scoped to",
		(scoped_parent.sub_events[0] as EventRow).with_node_target, "$Enemy") and all_passed
	all_passed = _check("…so the emitted code still targets that node",
		_compile(scoped_sheet), scoped_before) and all_passed
	return all_passed


## Inline substitutes a VALUE, so it may not rewrite the sentences the body prints. The shipped
## rename deliberately rewrites prose (an author renaming a concept means the comments too); this
## caller asks for the literal-safe pass, and the difference is visible in one row.
static func _test_inline_leaves_displayed_text_alone() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	var verb: EventFunction = EventFunction.new()
	verb.function_name = "announce"
	var parameter: ACEParam = ACEParam.new()
	parameter.id = "who"
	verb.params.append(parameter)
	var body: EventRow = EventRow.new()
	body.actions.append(_print_action("\"who is out\""))
	body.actions.append(_print_action("who"))
	verb.events.append(body)
	sheet.functions.append(verb)
	var caller: EventRow = _tick_event([])
	var call_action: ACEAction = ACEAction.new()
	call_action.provider_id = "Core"
	call_action.ace_id = "CallFunction"
	call_action.codegen_template = "{function_name}({args})"
	call_action.params = {"function_name": "announce", "args": "player_name"}
	caller.actions.append(call_action)
	sheet.events.append(caller)

	all_passed = _check("the call inlines", EventSheetInlineOps.inline_function_call(sheet, caller, 0), true) and all_passed
	all_passed = _check("the printed sentence is untouched",
		str((caller.actions[0] as ACEAction).params.get("message", "")), "\"who is out\"") and all_passed
	all_passed = _check("…while the parameter really was bound to the argument",
		str((caller.actions[1] as ACEAction).params.get("message", "")), "player_name") and all_passed
	return all_passed


## Unwrapping a LATER sub-event must not move its actions in front of the sub-events above it.
## The lifted actions travel in a condition-less carrier row, which emits as plain statements at
## the parent's own body indent - so the run order the author read is the run order that ships.
static func _test_unwrap_keeps_run_order() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	var parent: EventRow = _tick_event(["\"first\""])
	var guarded: EventRow = EventRow.new()
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "Always"
	condition.codegen_template = "true"
	guarded.conditions.append(condition)
	guarded.actions.append(_print_action("\"guarded\""))
	var later: EventRow = EventRow.new()
	var second_condition: ACECondition = ACECondition.new()
	second_condition.provider_id = "Core"
	second_condition.ace_id = "Always"
	second_condition.codegen_template = "true"
	later.conditions.append(second_condition)
	later.actions.append(_print_action("\"last\""))
	parent.sub_events.append(guarded)
	parent.sub_events.append(later)
	sheet.events.append(parent)

	all_passed = _check("the second sub-event unwraps", EventSheetWrapUnwrap.unwrap_event(sheet, later), 1) and all_passed
	var lines: PackedStringArray = _compile(sheet).split("\n")
	var first_line: int = _line_with(lines, "print(\"first\")")
	var guarded_line: int = _line_with(lines, "print(\"guarded\")")
	var last_line: int = _line_with(lines, "print(\"last\")")
	all_passed = _check("the lifted action still runs after the sub-event above it", last_line > guarded_line, true) and all_passed
	all_passed = _check("at the parent's own indent, not the guard's",
		_indent_of(lines[last_line]), _indent_of(lines[first_line])) and all_passed
	all_passed = _check("and the guard above it is untouched", _indent_of(lines[guarded_line]) > _indent_of(lines[first_line]), true) and all_passed
	return all_passed

# ── Inline ───────────────────────────────────────────────────────────────────


static func _test_inline_is_the_inverse_of_extract() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = _tick_event(["\"reset\"", "\"spawn\""])
	sheet.events.append(event)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(RecordingUndoManager.new())
	var before: String = _compile(sheet)

	# The SHIPPED extractor, then the new inverse.
	var extracted: EventFunction = EventSheetExtractOps.extract_actions_to_function(sheet, event, event.actions.duplicate(), "Set Up Level")
	all_passed = _check("extract published a verb", extracted != null, true) and all_passed
	all_passed = _check("and left one Call row behind", event.actions.size(), 1) and all_passed
	all_passed = _check("the call names the verb",
		EventSheetInlineOps.called_function_name(event.actions[0]), extracted.function_name) and all_passed
	all_passed = _check("its body is a plain run of actions inline can splice",
		EventSheetInlineOps.body_actions(extracted).size(), 2) and all_passed
	all_passed = _check("the call site is found from the verb's side",
		EventSheetInlineOps.calls_to(sheet, extracted.function_name).size(), 1) and all_passed

	editor._context_row = _row_data_for(event)
	editor._context_hit = {"ace_index": 0}
	var before_inline: String = _compile(editor._current_sheet)
	EventSheetRefactorMenu.inline_call_requested(editor)
	var inlined_event: EventRow = editor._current_sheet.events[0] as EventRow
	all_passed = _check("inline put both rows back where the call was", inlined_event.actions.size(), 2) and all_passed
	all_passed = _check("in the original order",
		str((inlined_event.actions[1] as ACEAction).params.get("message", "")), "\"spawn\"") and all_passed
	all_passed = _check("the verb itself is left alone (other callers keep working)",
		editor._current_sheet.functions.size(), 1) and all_passed
	editor._undo_redo_adapter.undo()
	all_passed = _check("undo puts the Call row back", (editor._current_sheet.events[0] as EventRow).actions.size(), 1) and all_passed
	all_passed = _check("…and restores the sheet byte-for-byte, not just the row count",
		_compile(editor._current_sheet), before_inline) and all_passed

	# The byte claim: fold the verb away entirely and the sheet emits what it did before extraction.
	var live_function: EventFunction = editor._current_sheet.functions[0] as EventFunction
	all_passed = _check("folding it everywhere is sound",
		EventSheetInlineOps.inline_everywhere_and_remove(editor._current_sheet, live_function), 1) and all_passed
	all_passed = _check("extract then inline re-emits the sheet byte-for-byte",
		_compile(editor._current_sheet), before) and all_passed
	editor.free()
	return all_passed


static func _test_inline_everywhere_and_remove() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	var first: EventRow = _tick_event(["\"reset\"", "\"spawn\""])
	sheet.events.append(first)
	var extracted: EventFunction = EventSheetExtractOps.extract_actions_to_function(sheet, first, first.actions.duplicate(), "Set Up Level")
	var second: EventRow = _tick_event([])
	var second_call: ACEAction = ACEAction.new()
	second_call.provider_id = "Core"
	second_call.ace_id = "CallFunction"
	second_call.codegen_template = "{function_name}({args})"
	second_call.params = {"function_name": extracted.function_name, "args": ""}
	second.actions.append(second_call)
	sheet.events.append(second)
	all_passed = _check("both call sites are found", EventSheetInlineOps.calls_to(sheet, extracted.function_name).size(), 2) and all_passed

	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(RecordingUndoManager.new())
	editor._context_row = _row_data_for(extracted)
	var before_fold: String = _compile(editor._current_sheet)
	EventSheetRefactorMenu.inline_everywhere_requested(editor)
	all_passed = _check("the verb is gone from the sheet", editor._current_sheet.functions.size(), 0) and all_passed
	all_passed = _check("the first caller got the body", (editor._current_sheet.events[0] as EventRow).actions.size(), 2) and all_passed
	all_passed = _check("so did the second", (editor._current_sheet.events[1] as EventRow).actions.size(), 2) and all_passed
	all_passed = _check("and no Call row is left pointing at nothing",
		_compile(editor._current_sheet).contains(extracted.function_name), false) and all_passed
	editor._undo_redo_adapter.undo()
	all_passed = _check("one undo brings the verb and both calls back", editor._current_sheet.functions.size(), 1) and all_passed
	all_passed = _check("with the call row restored", (editor._current_sheet.events[1] as EventRow).actions.size(), 1) and all_passed
	all_passed = _check("…and the sheet byte-for-byte as it was",
		_compile(editor._current_sheet), before_fold) and all_passed

	# The honest limit: an argument that is not a plain name cannot be re-pointed by a rename.
	var parameterised: EventFunction = EventFunction.new()
	parameterised.function_name = "apply_damage"
	var parameter: ACEParam = ACEParam.new()
	parameter.id = "amount"
	parameterised.params.append(parameter)
	var body: EventRow = EventRow.new()
	body.actions.append(_print_action("amount"))
	parameterised.events.append(body)
	var host: EventSheetResource = EventSheetResource.new()
	host.functions.append(parameterised)
	var caller: EventRow = _tick_event([])
	var call_action: ACEAction = ACEAction.new()
	call_action.provider_id = "Core"
	call_action.ace_id = "CallFunction"
	call_action.codegen_template = "{function_name}({args})"
	call_action.params = {"function_name": "apply_damage", "args": "hit_points"}
	caller.actions.append(call_action)
	host.events.append(caller)
	all_passed = _check("a plain-name argument inlines", EventSheetInlineOps.inline_refusal(host, caller, 0), "") and all_passed
	all_passed = _check("and the parameter is re-pointed at it",
		EventSheetInlineOps.inline_function_call(host, caller, 0), true) and all_passed
	all_passed = _check("so the body reads the caller's value",
		str((caller.actions[0] as ACEAction).params.get("message", "")), "hit_points") and all_passed
	call_action.params = {"function_name": "apply_damage", "args": "base * 2"}
	caller.actions.clear()
	caller.actions.append(call_action)
	all_passed = _check("an expression argument is refused, with the fix named",
		EventSheetInlineOps.inline_refusal(host, caller, 0),
		"This call passes the expression \"base * 2\" - inline can only re-point a plain name. Put the expression in a variable first, then inline.") and all_passed
	editor.free()
	return all_passed

# ── Duplicate as Variant ─────────────────────────────────────────────────────


static func _test_duplicate_as_variant() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.variables["p1_jumps"] = {"type": "int", "default": 0}
	var event: EventRow = _tick_event([])
	var jump: ACEAction = ACEAction.new()
	jump.provider_id = "Core"
	jump.ace_id = "SetProperty"
	jump.codegen_template = "{target}.{property} = {value}"
	jump.params = {"target": "$Player1", "property": "velocity", "value": "p1_jumps"}
	event.actions.append(jump)
	sheet.events.append(event)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(RecordingUndoManager.new())

	var found: Dictionary = EventSheetDuplicateVariant.targets(sheet, [event])
	all_passed = _check("the object the rows point at is offered", found.get("objects", []), ["$Player1"]) and all_passed
	all_passed = _check("so is the variable they need", found.get("variables", []), ["p1_jumps"]) and all_passed

	var dialog: EventSheetDuplicateVariantDialog = EventSheetDuplicateVariantDialog.new()
	dialog.configure(editor, [event])
	dialog._object_fields[0]["edit"].text = "$Player2"
	dialog._variable_fields[0]["edit"].text = "p2_jumps"
	all_passed = _check("the fields describe the retarget", dialog.mapping(),
		{"objects": {"$Player1": "$Player2"}, "variables": {"p1_jumps": "p2_jumps"}}) and all_passed
	all_passed = _check("the variant form survives its own OK press (it hides itself, on success only)",
		dialog.dialog_hide_on_ok, false) and all_passed
	all_passed = _check("the preview shows the rows it will produce, already retargeted",
		"\n".join(dialog.preview_lines()).contains("$Player2.velocity = p2_jumps"), true) and all_passed
	var before_variant: String = _compile(editor._current_sheet)
	all_passed = _check("the variant lands", dialog.confirm(), true) and all_passed
	var live: EventSheetResource = editor._current_sheet
	all_passed = _check("the sheet now holds source and variant", live.events.size(), 2) and all_passed
	all_passed = _check("the variant points at the new object",
		str(((live.events[1] as EventRow).actions[0] as ACEAction).params.get("target", "")), "$Player2") and all_passed
	all_passed = _check("the source is untouched",
		str(((live.events[0] as EventRow).actions[0] as ACEAction).params.get("target", "")), "$Player1") and all_passed
	all_passed = _check("the renamed variable was declared alongside the original",
		live.variables.has("p2_jumps") and live.variables.has("p1_jumps"), true) and all_passed
	editor._undo_redo_adapter.undo()
	all_passed = _check("one undo removes the whole variant", editor._current_sheet.events.size(), 1) and all_passed
	all_passed = _check("…restoring the sheet byte-for-byte, the renamed variable included",
		_compile(editor._current_sheet), before_variant) and all_passed
	dialog.free()
	editor.free()
	return all_passed

# ── Snippets with blanks ─────────────────────────────────────────────────────


static func _test_snippet_blanks() -> bool:
	var all_passed: bool = true
	var source: EventSheetResource = EventSheetResource.new()
	var event: EventRow = _tick_event([])
	var play: ACEAction = ACEAction.new()
	play.provider_id = "Core"
	play.ace_id = "SetProperty"
	play.codegen_template = "{target}.{property} = {value}"
	play.params = {"target": "{{blank:Pickup Node}}", "property": "stream", "value": "{{blank:Sound|\"coin.ogg\"}}"}
	event.actions.append(play)
	source.events.append(event)
	var text: String = EventSheetSnippet.serialize_rows([event], source)

	var blanks: Array = EventSheetSnippet.blanks_in(text)
	all_passed = _check("both blanks are found, in the order they appear", blanks.size(), 2) and all_passed
	all_passed = _check("with their labels", str((blanks[0] as Dictionary).get("label", "")), "Pickup Node") and all_passed
	all_passed = _check("and the default the author demonstrated",
		str((blanks[1] as Dictionary).get("default", "")), "\"coin.ogg\"") and all_passed
	all_passed = _check("a plain snippet has none", EventSheetSnippet.has_blanks(
		EventSheetSnippet.serialize_rows([_tick_event(["\"plain\""])], source)), false) and all_passed
	all_passed = _check("an unanswered blank is named", EventSheetSnippet.missing_blanks(text, {"Sound": "x"}), PackedStringArray(["Pickup Node"])) and all_passed
	var filled: String = EventSheetSnippet.fill_blanks(text, {"Pickup Node": "$Coin", "Sound": "\"chime.ogg\""})
	all_passed = _check("filling leaves no placeholder behind", filled.contains("{{blank:"), false) and all_passed

	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(EventSheetResource.new())
	editor.set_undo_redo_manager(RecordingUndoManager.new())
	var dialog: EventSheetSnippetBlanksDialog = EventSheetSnippetBlanksDialog.new()
	dialog.configure(editor, "Pickup", text)
	all_passed = _check("the form seeds each field with the blank's own default",
		(dialog._fields[1].get("edit") as LineEdit).text, "\"coin.ogg\"") and all_passed
	(dialog._fields[0].get("edit") as LineEdit).text = ""
	all_passed = _check("an empty answer refuses rather than landing a placeholder row", dialog.confirm(), false) and all_passed
	all_passed = _check("and nothing was inserted", editor._current_sheet.events.size(), 0) and all_passed
	# The refusal has to be actionable: AcceptDialog hides on OK before `confirmed` is handled, so
	# with its default the form - and every other answer already typed - would be gone.
	all_passed = _check("the form is not thrown away by the press it refused", dialog.dialog_hide_on_ok, false) and all_passed
	(dialog._fields[0].get("edit") as LineEdit).text = "$Coin"
	(dialog._fields[1].get("edit") as LineEdit).text = "\"chime.ogg\""
	var before_insert: String = _compile(editor._current_sheet)
	all_passed = _check("filled in, the rows land", dialog.confirm(), true) and all_passed
	var landed: EventRow = editor._current_sheet.events[0] as EventRow
	all_passed = _check("with the answers substituted",
		str((landed.actions[0] as ACEAction).params.get("target", "")), "$Coin") and all_passed
	all_passed = _check("everywhere, including the defaulted field",
		str((landed.actions[0] as ACEAction).params.get("value", "")), "\"chime.ogg\"") and all_passed
	editor._undo_redo_adapter.undo()
	all_passed = _check("and the insert is one undo step", editor._current_sheet.events.size(), 0) and all_passed
	all_passed = _check("…leaving the sheet byte-for-byte as it was",
		_compile(editor._current_sheet), before_insert) and all_passed
	dialog.free()
	editor.free()
	return all_passed

# ── The menu entries a reader can actually find ──────────────────────────────


static func _test_menu_entries() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = _tick_event(["\"a\""])
	sheet.events.append(event)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(RecordingUndoManager.new())
	editor._context_menus.build_all()
	var row_data: EventRowData = _row_data_for(event)
	editor._context_row = row_data
	editor._context_menus._build_row_context_menu(row_data)
	var refactor_index: int = editor._row_context_menu.get_item_index(882)
	all_passed = _check("the row menu carries a Refactor submenu",
		editor._row_context_menu.get_item_text(refactor_index) if refactor_index >= 0 else "", "Refactor") and all_passed
	var submenu: PopupMenu = editor._row_context_menu.get_node_or_null(EventSheetRefactorMenu.SUBMENU_NAME) as PopupMenu
	all_passed = _check("with Wrap in Condition… first",
		submenu.get_item_text(submenu.get_item_index(EventSheetRefactorMenu.MENU_WRAP)), "Wrap in Condition…") and all_passed
	all_passed = _check("Unwrap Event beside it",
		submenu.get_item_text(submenu.get_item_index(EventSheetRefactorMenu.MENU_UNWRAP)), "Unwrap Event") and all_passed
	all_passed = _check("and Duplicate as Variant…",
		submenu.get_item_text(submenu.get_item_index(EventSheetRefactorMenu.MENU_DUPLICATE_VARIANT)), "Duplicate as Variant…") and all_passed
	all_passed = _check("Unwrap is disabled on a top-level event, with the reason as its tooltip",
		submenu.get_item_tooltip(submenu.get_item_index(EventSheetRefactorMenu.MENU_UNWRAP)),
		"Unwrap lifts a sub-event's rows into the event above it - this row is already top-level.") and all_passed
	var inline_index: int = editor._action_context_menu.get_item_index(EventSheetRefactorMenu.ACTION_MENU_INLINE_CALL)
	all_passed = _check("an action's own menu offers Inline This Call",
		editor._action_context_menu.get_item_text(inline_index) if inline_index >= 0 else "", "Inline This Call") and all_passed
	editor.free()
	return all_passed

# ── Helpers ──────────────────────────────────────────────────────────────────


## An Every-Frame event whose actions are plain prints - baked templates, so the compiled text
## is deterministic and readable without depending on any registry lookup.
static func _tick_event(messages: Array) -> EventRow:
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	for message: Variant in messages:
		event.actions.append(_print_action(str(message)))
	return event


static func _print_action(message: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "ConsoleLog"
	action.codegen_template = "print({message})"
	action.params = {"message": message}
	return action


static func _row_data_for(resource: Resource) -> EventRowData:
	var row_data: EventRowData = EventRowData.new()
	row_data.source_resource = resource
	return row_data


static func _compile(sheet: EventSheetResource) -> String:
	return str(SheetCompiler.compile(sheet, COMPILE_PATH).get("output", ""))


static func _line_with(lines: PackedStringArray, needle: String) -> int:
	for index: int in range(lines.size()):
		if lines[index].contains(needle):
			return index
	return -1


static func _indent_of(line: String) -> int:
	return line.length() - line.lstrip("\t").length()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("  [FAIL] refactor_gestures_test: %s (got %s, expected %s)" % [label, str(actual), str(expected)])
	return false
