# EventForge - the Construct-style loop index (loopindex). Opt-in per loop via
# PickFilter.index_name: the emitter declares `var <name>: int = -1` above the loop and bumps
# it as the body's FIRST statement, so the counter runs 0, 1, 2... regardless of the loop kind
# (For Each, Repeat - even over a range that starts elsewhere - and While). The importer lifts
# that exact three-line shape back into index_name, so it round-trips byte-identically; the
# LoopIndex / LoopIndexNamed expressions read the counter as a plain local (parity - zero
# runtime). Pins: emission shape per kind, 0-based independence from the Repeat range, nested
# named indexes, the lift, the round-trip, no-index output unchanged, and the budgeted warning.
@tool
class_name LoopIndexTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ---- emission: For Each with an index ----
	var foreach_output: String = _compile(_loop_sheet(PickFilter.CollectionKind.EXPRESSION, "enemies", "loop_index"))
	ok = _check(ok, foreach_output.contains("\tvar loop_index: int = -1\n\tfor item in enemies:\n\t\tloop_index += 1"), "For Each emits the declare/loop/bump triple")

	# ---- emission: Repeat over an offset range stays 0-based ----
	var repeat_output: String = _compile(_loop_sheet(PickFilter.CollectionKind.REPEAT, "2, 8", "loop_index"))
	ok = _check(ok, repeat_output.contains("\tvar loop_index: int = -1\n\tfor item in range(2, 8):\n\t\tloop_index += 1"), "Repeat keeps the index 0-based even over range(2, 8)")

	# ---- emission: While loops count too ----
	var while_output: String = _compile(_loop_sheet(PickFilter.CollectionKind.WHILE, "hp > 0", "loop_index"))
	ok = _check(ok, while_output.contains("\tvar loop_index: int = -1\n\twhile hp > 0:\n\t\tloop_index += 1"), "While emits the same counter shape")

	# ---- no index name -> output byte-identical to before the feature ----
	var plain_output: String = _compile(_loop_sheet(PickFilter.CollectionKind.EXPRESSION, "enemies", ""))
	ok = _check(ok, not plain_output.contains("loop_index"), "an unnamed index emits nothing")

	# ---- the covenant: every indexed shape round-trips byte-exactly ----
	ok = _check(ok, EventSheets.round_trips(foreach_output), "For Each + index round-trips")
	ok = _check(ok, EventSheets.round_trips(repeat_output), "Repeat + index round-trips")
	ok = _check(ok, EventSheets.round_trips(while_output), "While + index round-trips")

	# ---- the lift recovers index_name (not just verbatim) ----
	var lifted: EventSheetResource = EventSheets.open_gd_as_sheet(foreach_output)
	var lifted_pick: PickFilter = _first_pick(lifted)
	ok = _check(ok, lifted_pick != null and lifted_pick.index_name == "loop_index", "the lift recovers index_name (got %s)" % (lifted_pick.index_name if lifted_pick != null else "<no pick>"))

	# ---- nested loops with distinct names (the C3 loopindex(\"name\") shape) ----
	var nested: EventSheetResource = _loop_sheet(PickFilter.CollectionKind.EXPRESSION, "waves", "wave_index")
	var outer_row: EventRow = nested.events[0] as EventRow
	var inner_row: EventRow = EventRow.new()
	var inner_pick: PickFilter = PickFilter.new()
	inner_pick.collection_kind = PickFilter.CollectionKind.REPEAT
	inner_pick.collection_value = "3"
	inner_pick.iterator_name = "i"
	inner_pick.index_name = "spawn_index"
	inner_row.pick_filters.append(inner_pick)
	var inner_action: ACEAction = ACEAction.new()
	inner_action.provider_id = "Core"
	inner_action.ace_id = "RunCode"
	inner_action.codegen_template = "print(wave_index, spawn_index)"
	inner_row.actions.append(inner_action)
	outer_row.sub_events.append(inner_row)
	var nested_output: String = _compile(nested)
	ok = _check(ok, nested_output.contains("var wave_index: int = -1") and nested_output.contains("var spawn_index: int = -1"), "nested loops carry distinct named indexes")
	ok = _check(ok, EventSheets.round_trips(nested_output), "nested named indexes round-trip")

	# ---- the LoopIndex expressions are plain locals (templates compile to identifiers) ----
	var registry_hits: int = 0
	for descriptor: ACEDescriptor in EventForgeLoopACEs.get_descriptors():
		if descriptor.ace_id == "LoopIndex":
			registry_hits += 1
			ok = _check(ok, descriptor.codegen_template == "loop_index", "LoopIndex reads the conventional local")
		elif descriptor.ace_id == "LoopIndexNamed":
			registry_hits += 1
			ok = _check(ok, descriptor.codegen_template == "{name}", "LoopIndexNamed reads the named local")
	ok = _check(ok, registry_hits == 2, "both loopindex expressions are registered")

	# ---- budgeted loops warn and skip the counter ----
	var budgeted: EventSheetResource = _loop_sheet(PickFilter.CollectionKind.EXPRESSION, "enemies", "loop_index")
	(_first_pick(budgeted) as PickFilter).frame_spread_count = 5
	var budgeted_result: Dictionary = SheetCompiler.compile(budgeted, "user://loop_index_budgeted.gd")
	var budgeted_warnings: String = str(budgeted_result.get("warnings", []))
	ok = _check(ok, str(budgeted_result.get("output", "")).find("var loop_index") == -1, "a budgeted loop emits no counter")
	ok = _check(ok, budgeted_warnings.contains("Loop index ignored"), "a budgeted loop warns that the index is ignored")
	for temp: String in ["user://loop_index_test.gd", "user://loop_index_budgeted.gd"]:
		if FileAccess.file_exists(temp):
			DirAccess.remove_absolute(temp)

	return ok


static func _loop_sheet(kind: int, collection: String, index_name: String) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	var pick: PickFilter = PickFilter.new()
	pick.collection_kind = kind
	pick.collection_value = collection
	pick.iterator_name = "item" if kind != PickFilter.CollectionKind.WHILE else ""
	pick.index_name = index_name
	row.pick_filters.append(pick)
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "RunCode"
	action.codegen_template = "print(item)" if kind != PickFilter.CollectionKind.WHILE else "hp -= 1"
	row.actions.append(action)
	sheet.events.append(row)
	if kind == PickFilter.CollectionKind.WHILE:
		sheet.variables = {"hp": {"type": "int", "default": 3, "exported": false}}
	return sheet


static func _compile(sheet: EventSheetResource) -> String:
	return str(SheetCompiler.compile(sheet, "user://loop_index_test.gd").get("output", ""))


static func _first_pick(sheet: EventSheetResource) -> PickFilter:
	for entry: Variant in sheet.events:
		if entry is EventRow and not (entry as EventRow).pick_filters.is_empty():
			return (entry as EventRow).pick_filters[0]
	return null


static func _check(ok: bool, condition: bool, label: String) -> bool:
	if not condition:
		print("  [FAIL] ", label)
	return ok and condition
