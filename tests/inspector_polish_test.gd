# Godot EventSheets - Inspector polish: widget_hint editors + per-row "Selected ACE"
# widget_hint-specific EditorProperty widgets (slider/multiline/expression) replace the
# default inspector controls, and selecting a condition/trigger/action in the sheet
# surfaces ITS params as live inspector properties - edits route through the dock's
# undoable write (the exposed node never mutates sheet resources itself).
@tool
class_name InspectorPolishTest
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

	# ── widget_hint mapping (construction is editor-only; classes assert headless) ──
	all_passed = _check("slider hint maps to the slider editor",
		ACEParamInspectorPlugin.widget_class_for_hint("slider"), ACEParamInspectorPlugin.SliderParamProperty) and all_passed
	all_passed = _check("multiline hint maps to the TextEdit editor",
		ACEParamInspectorPlugin.widget_class_for_hint("multiline"), ACEParamInspectorPlugin.MultilineParamProperty) and all_passed
	all_passed = _check("expression hint maps to the fx editor",
		ACEParamInspectorPlugin.widget_class_for_hint("expression"), ACEParamInspectorPlugin.ExpressionParamProperty) and all_passed
	all_passed = _check("unknown hints fall back to default widgets",
		ACEParamInspectorPlugin.widget_class_for_hint("") == null, true) and all_passed
	var bounds: PackedFloat64Array = ACEParamInspectorPlugin._parse_range({"param_meta": {"range": "0,10,0.5"}})
	all_passed = _check("range parses from param metadata",
		bounds[0] == 0.0 and bounds[1] == 10.0 and is_equal_approx(bounds[2], 0.5), true) and all_passed

	# ── Per-row "Selected ACE" scope ────────────────────────────────────────
	var sheet: EventSheetResource = EventSheetResource.new()
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnReady"
	var heal: ACEAction = ACEAction.new()
	heal.provider_id = "DemoHealthAddon"
	heal.ace_id = "method:heal"
	heal.params = {"amount": 5}
	heal.codegen_template = "health += {amount}"
	event.actions.append(heal)
	sheet.events.append(event)
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	editor.set_undo_redo_manager(NoopUndoManager.new())
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var row_data: EventRowData = viewport.get_flat_rows()[0].get("row")
	viewport._ensure_event_spans(row_data)
	var action_span: int = -1
	for index in range(row_data.spans.size()):
		var metadata: Dictionary = row_data.spans[index].metadata if row_data.spans[index].metadata is Dictionary else {}
		if str(metadata.get("kind", "")) == "action" and int(metadata.get("ace_index", -1)) == 0:
			action_span = index
			break
	all_passed = _check("action span found", action_span >= 0, true) and all_passed
	viewport._select_from_click(0, action_span, false)
	all_passed = _check("selected ACE resolves to the action", viewport.get_selected_ace_resource(), heal) and all_passed

	var exposed: EventSheetExposedNode = editor.get_exposed_node()
	exposed.set_row_context(viewport.get_selected_ace_resource())
	var has_selected_prop: bool = false
	for property_info in exposed._get_property_list():
		if str(property_info.get("name", "")) == "selected_ace/amount":
			has_selected_prop = true
	all_passed = _check("selected ACE params surface as inspector properties", has_selected_prop, true) and all_passed
	all_passed = _check("inspector reads the row's live value", exposed._get("selected_ace/amount"), 5) and all_passed
	var amount_entry: Dictionary = exposed.get_property_entry("selected_ace/amount")
	all_passed = _check("fx param hint doubles as the widget hint", str(amount_entry.get("widget_hint", "")), "expression") and all_passed

	# Writes route through the dock (undoable) and land on the row resource.
	all_passed = _check("inspector set is accepted", exposed._set("selected_ace/amount", 9), true) and all_passed
	all_passed = _check("the row's param actually changed", heal.params.get("amount"), 9) and all_passed
	all_passed = _check("inspector re-reads the new value", exposed._get("selected_ace/amount"), 9) and all_passed

	# Deselecting clears the section.
	exposed.set_row_context(null)
	var still_has: bool = false
	for property_info in exposed._get_property_list():
		if str(property_info.get("name", "")).begins_with("selected_ace/"):
			still_has = true
	all_passed = _check("clearing the context removes the section", still_has, false) and all_passed
	editor.free()

	return all_passed


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] inspector_polish_test: %s" % label)
		return true
	print("[FAIL] inspector_polish_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
