# Godot EventSheets — Pick-filter compilation + rendering (C3 "for each" picking)
# Pick filters wrap the event body in direct for loops (group/children/iterable) with an
# optional iterator-scoped predicate and first-N cap; conditions gate the loop; filters
# nest in order. Plain loops — the parity contract holds.
@tool
extends RefCounted
class_name PickFilterTest

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

	# Group pick + predicate + first-N, inside a condition gate, with a sub-event.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var grounded: ACECondition = ACECondition.new()
	grounded.provider_id = "Core"
	grounded.ace_id = "IsOnFloor"
	event.conditions.append(grounded)
	var pick: PickFilter = PickFilter.new()
	pick.iterator_name = "enemy"
	pick.collection_kind = PickFilter.CollectionKind.GROUP
	pick.collection_value = "enemies"
	pick.predicate_expression = "enemy.health < 50"
	pick.pick_first_n = 3
	event.pick_filters.append(pick)
	var hurt: ACEAction = ACEAction.new()
	hurt.provider_id = "Test"
	hurt.ace_id = "hurt"
	hurt.codegen_template = "enemy.take_hit()"
	event.actions.append(hurt)
	var nested: EventRow = EventRow.new()
	var nested_action: ACEAction = ACEAction.new()
	nested_action.provider_id = "Test"
	nested_action.ace_id = "mark"
	nested_action.codegen_template = "enemy.mark()"
	nested.actions.append(nested_action)
	event.sub_events.append(nested)
	sheet.events.append(event)

	var result: Dictionary = SheetCompiler.compile(sheet, "user://eventsheets_pick.gd")
	var output: String = str(result.get("output", ""))
	all_passed = _check("conditions gate the loop",
		output.find("\tif is_on_floor():") < output.find("for enemy in"), true) and all_passed
	all_passed = _check("group collection compiles",
		output.contains("\t\tfor enemy in get_tree().get_nodes_in_group(\"enemies\"):"), true) and all_passed
	all_passed = _check("predicate filters with continue",
		output.contains("\t\t\tif not (enemy.health < 50):\n\t\t\t\tcontinue"), true) and all_passed
	all_passed = _check("first-N caps with break",
		output.contains("__pick_count_0 += 1") and output.contains("> 3:\n\t\t\t\tbreak"), true) and all_passed
	all_passed = _check("actions run inside the loop", output.contains("\t\t\tenemy.take_hit()"), true) and all_passed
	all_passed = _check("sub-events nest inside the loop", output.contains("\t\t\tenemy.mark()"), true) and all_passed
	all_passed = _check("no pick TODO remains", output.contains("pick filters not yet implemented"), false) and all_passed
	var generated: GDScript = GDScript.new()
	generated.source_code = output
	all_passed = _check("pick output parses", generated.reload(true) == OK, true) and all_passed

	# Children collection; empty body gets pass; order_by warns.
	var child_sheet: EventSheetResource = EventSheetResource.new()
	var child_event: EventRow = EventRow.new()
	child_event.trigger_provider_id = "Core"
	child_event.trigger_id = "OnReady"
	var child_pick: PickFilter = PickFilter.new()
	child_pick.collection_kind = PickFilter.CollectionKind.CHILDREN
	child_pick.order_by_expression = "item.name"
	child_event.pick_filters.append(child_pick)
	child_sheet.events.append(child_event)
	var child_result: Dictionary = SheetCompiler.compile(child_sheet, "user://eventsheets_pick_children.gd")
	var child_output: String = str(child_result.get("output", ""))
	all_passed = _check("children collection compiles (ordered copy)",
		child_output.contains("var __pick_sorted_0: Array = Array(get_children())") and child_output.contains("for item in __pick_sorted_0:"), true) and all_passed
	all_passed = _check("empty loop body gets pass", child_output.contains("\t\tpass"), true) and all_passed
	all_passed = _check("order_by compiles a sorted copy (no warning anymore)",
		str(child_result.get("output", "")).contains(".sort_custom(func(__pick_a, __pick_b): return ("), true) and all_passed

	# Disabled filters are skipped entirely.
	child_pick.enabled = false
	var disabled_output: String = str(SheetCompiler.compile(child_sheet, "user://eventsheets_pick_off.gd").get("output", ""))
	all_passed = _check("disabled filters skip", disabled_output.contains("for item in"), false) and all_passed
	child_pick.enabled = true

	# Rendering: a "For each …" span in the condition lane, line counting in sync.
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var row_data: EventRowData = viewport.get_flat_rows()[0].get("row")
	viewport._ensure_event_spans(row_data)
	var pick_span_text: String = ""
	for span in row_data.spans:
		if str((span.metadata if span.metadata is Dictionary else {}).get("kind", "")) == "pick_filter":
			pick_span_text = span.text
	all_passed = _check("pick filter renders in the condition lane",
		pick_span_text, "For each enemy in group \"enemies\" where enemy.health < 50 (first 3)") and all_passed
	all_passed = _check("line counting includes pick rows",
		viewport._count_event_lines(event), row_data.line_count) and all_passed

	# Authoring dialog round-trip (add via the same path the row menu uses).
	editor._ensure_pick_dialog()
	editor._pick_target_event = event
	editor._pick_target_index = -1
	editor._pick_iterator_edit.text = "coin"
	editor._pick_kind_option.select(0)
	editor._pick_collection_edit.text = "coins"
	editor._pick_predicate_edit.text = ""
	editor._pick_first_n_spin.value = 0
	editor._on_pick_filter_confirmed()
	all_passed = _check("dialog adds a pick filter", event.pick_filters.size(), 2) and all_passed
	all_passed = _check("dialog values land on the resource",
		(event.pick_filters[1] as PickFilter).iterator_name == "coin" and (event.pick_filters[1] as PickFilter).collection_value == "coins", true) and all_passed
	editor._pick_target_index = 1
	editor._on_pick_filter_deleted()
	all_passed = _check("dialog delete removes the filter", event.pick_filters.size(), 1) and all_passed
	editor.free()

	return all_passed

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] pick_filter_test: %s" % label)
		return true
	print("[FAIL] pick_filter_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
