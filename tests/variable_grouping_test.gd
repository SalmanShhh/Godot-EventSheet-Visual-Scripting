# EventForge — Discord-style variable folders. Dragging one variable onto another folds both into a
# shared Inspector group (the SHIPPED @export_group attribute, so folders round-trip like dialog-set
# groups); a fresh folder opens the naming popup select-all'd; renaming applies to every member; an
# empty name dissolves the folder. Grouped globals sort adjacent so the bubble outline can wrap the
# run as one visual unit — variable_group_runs is the (pure) geometry the bubble draw uses. All edits
# ride the undo funnel, whose commit REPLACES resources: every assertion re-reads the LIVE sheet.
@tool
class_name VariableGroupingTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── The pure group model: dict globals + tree variables ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.variables = {
		"speed": {"type": "float", "default": 100.0, "exported": true},
		"jump_power": {"type": "float", "default": 4.0, "exported": true},
		"debug_name": {"type": "String", "default": "", "exported": true},
	}
	var tree_var: LocalVariable = LocalVariable.new()
	tree_var.name = "combo_window"
	tree_var.type_name = "float"
	tree_var.exported = true
	sheet.events.append(tree_var)

	ok = _check("a fresh global has no group", EventSheetVariableGrouping.group_of(sheet, "global", "speed", null), "") and ok
	ok = _check("setting a global's group reports change",
		EventSheetVariableGrouping.set_group(sheet, "global", "speed", null, "Movement"), true) and ok
	ok = _check("…and sticks", EventSheetVariableGrouping.group_of(sheet, "global", "speed", null), "Movement") and ok
	ok = _check("same value again is a no-op",
		EventSheetVariableGrouping.set_group(sheet, "global", "speed", null, "Movement"), false) and ok
	ok = _check("tree variable grouping works through its resource",
		EventSheetVariableGrouping.set_group(sheet, "tree", "", tree_var, "Movement"), true) and ok
	EventSheetVariableGrouping.set_group(sheet, "global", "jump_power", null, "Movement")
	ok = _check("rename reaches every member (2 globals + 1 tree)",
		EventSheetVariableGrouping.rename_group(sheet, "Movement", "Locomotion"), 3) and ok
	ok = _check("renamed on the tree var too", EventSheetVariableGrouping.group_of(sheet, "tree", "", tree_var), "Locomotion") and ok
	ok = _check("an empty name dissolves the folder",
		EventSheetVariableGrouping.rename_group(sheet, "Locomotion", ""), 3) and ok
	ok = _check("…leaving members ungrouped", EventSheetVariableGrouping.group_of(sheet, "global", "speed", null), "") and ok

	# ── The drop gesture end-to-end (drag speed ONTO jump_power) ──
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()
	var speed_row: EventRowData = _variable_row(view, "speed")
	var jump_row: EventRowData = _variable_row(view, "jump_power")
	ok = _check("variable rows found", speed_row != null and jump_row != null, true) and ok
	dock._variable_grouping.on_group_requested(speed_row, jump_row)
	var live: EventSheetResource = dock.get_current_sheet()
	ok = _check("drop folds BOTH into a fresh 'New Group'",
		EventSheetVariableGrouping.group_of(live, "global", "speed", null) + "/" +
		EventSheetVariableGrouping.group_of(live, "global", "jump_power", null), "New Group/New Group") and ok
	ok = _check("the naming popup opens pre-filled (type-to-name)",
		dock._variable_grouping._rename_field.text, "New Group") and ok

	# Name it via the popup (the Discord flow: drag → type → Enter).
	dock._variable_grouping._rename_field.text = "Movement"
	dock._variable_grouping.commit_rename()
	live = dock.get_current_sheet()
	ok = _check("the popup's name applies to every member",
		EventSheetVariableGrouping.group_of(live, "global", "speed", null), "Movement") and ok
	ok = _check("ungrouped var untouched", EventSheetVariableGrouping.group_of(live, "global", "debug_name", null), "") and ok

	# ── Joining an existing folder adopts its name (no popup churn) ──
	var debug_row: EventRowData = _variable_row(view, "debug_name")
	var grouped_row: EventRowData = _variable_row(view, "speed")
	dock._variable_grouping.on_group_requested(debug_row, grouped_row)
	live = dock.get_current_sheet()
	ok = _check("dropping onto a grouped variable joins its folder",
		EventSheetVariableGrouping.group_of(live, "global", "debug_name", null), "Movement") and ok

	# ── Adjacency + bubble geometry ──
	var flat: Array = view.get_flat_rows()
	var runs: Array = ViewportRowBuilder.variable_group_runs(flat)
	ok = _check("one bubble run wraps the folder", runs.size(), 1) and ok
	if runs.size() == 1:
		var run: Dictionary = runs[0]
		ok = _check("the run carries the folder name", str(run.get("group")), "Movement") and ok
		ok = _check("the run spans all three members", int(run.get("end")) - int(run.get("start")) + 1, 3) and ok
		for index: int in range(int(run.get("start")), int(run.get("end")) + 1):
			var row_data: EventRowData = (flat[index] as Dictionary).get("row")
			ok = _check("row %d in the bubble is a grouped variable row" % index,
				str((row_data.spans[0].metadata as Dictionary).get("variable_group", "")), "Movement") and ok

	# ── The compiled output still groups via @export_group (the shipped round-trip) ──
	var output: String = str(SheetCompiler.compile(live, "user://_var_grouping_out.gd").get("output", ""))
	ok = _check("the folder ships as @export_group", output.contains("@export_group(\"Movement\")"), true) and ok

	# ── One level deeper, same gesture: dropping a variable onto
	# a variable it ALREADY shares the folder with nests both into a subgroup. ──
	var live_view: EventSheetViewport = dock._active_view()
	var nest_source: EventRowData = _variable_row(live_view, "speed")
	var nest_target: EventRowData = _variable_row(live_view, "jump_power")
	dock._variable_grouping.on_group_requested(nest_source, nest_target)
	var live_after: EventSheetResource = dock._current_sheet
	ok = _check("the drop nests both into a fresh subgroup",
		str(((live_after.variables.get("speed", {}) as Dictionary).get("attributes", {}) as Dictionary).get("subgroup", "")), "New Subgroup") and ok
	ok = _check("the naming popup opens in subgroup mode", dock._variable_grouping._rename_is_subgroup, true) and ok
	dock._variable_grouping._rename_field.text = "Tuning"
	dock._variable_grouping.commit_rename()
	ok = _check("naming renames the subgroup for every member",
		str(((dock._current_sheet.variables.get("jump_power", {}) as Dictionary).get("attributes", {}) as Dictionary).get("subgroup", "")), "Tuning") and ok
	var nested_output: String = str(SheetCompiler.compile(dock._current_sheet, "user://_var_subgroup_out.gd").get("output", ""))
	ok = _check("the nest ships as @export_subgroup under the group",
		nested_output.contains("@export_group(\"Movement\")") and nested_output.contains("@export_subgroup(\"Tuning\")"), true) and ok

	# ── Review regressions: nested-subgroup rename + orphaned-subgroup clear ──
	# A tree variable under an event's sub-rows must rename with its subgroup siblings.
	var nested_sheet: EventSheetResource = EventSheetResource.new()
	nested_sheet.host_class = "Node2D"
	var holder: EventRow = EventRow.new()
	holder.trigger_provider_id = "Core"
	holder.trigger_id = "OnReady"
	var nested_var: LocalVariable = LocalVariable.new()
	nested_var.name = "buried"
	nested_var.type_name = "float"
	nested_var.exported = true
	nested_var.attributes = {"group": "Deep", "subgroup": "Tuning"}
	holder.sub_events.append(nested_var)
	nested_sheet.events.append(holder)
	ok = _check("subgroup rename reaches variables nested in sub_events",
		EventSheetVariableGrouping.rename_subgroup(nested_sheet, "Tuning", "Knobs"), 1) and ok
	ok = _check("…and the nested member carries the new name",
		str((nested_var.attributes as Dictionary).get("subgroup", "")), "Knobs") and ok
	# Clearing a group must clear its subgroup too - a bare @export_subgroup would nest under
	# an unrelated earlier group in the Inspector.
	EventSheetVariableGrouping.set_group(nested_sheet, "tree", "", nested_var, "")
	ok = _check("clearing the group clears the orphan subgroup",
		(nested_var.attributes as Dictionary).has("subgroup"), false) and ok

	dock.free()
	return ok


static func _variable_row(view: EventSheetViewport, var_name: String) -> EventRowData:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and not row_data.spans.is_empty() and row_data.spans[0].metadata is Dictionary \
				and str((row_data.spans[0].metadata as Dictionary).get("variable_name", "")) == var_name:
			return row_data
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] variable_grouping_test: %s" % label)
		return true
	print("[FAIL] variable_grouping_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
