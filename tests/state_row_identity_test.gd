@tool
extends RefCounted
# Godot EventSheets - the state row acts on the machine it stands for.
#
# The state row is drawn where the State enum sits and stands for the enum and the lines it hides (the
# `state` variable, the previous state, the entered time, `state_changed`). It used to carry the
# VARIABLE as its source, so Delete removed only `var state` and the machine fell apart into loose
# rows, Add below landed after the variable, a drag moved the variable while the row stayed put, and
# the jump to code went to the variable's line. The pins hold:
#   1. the row's source is the enum (where it is drawn), and it still reads its marks off the variable;
#   2. the machine's parts are the enum plus every hidden line, and nothing for an ordinary row;
#   3. a delete widened to the parts takes the whole machine and leaves the rest of the sheet, and
#      no loose helper row is drawn afterwards;
#   4. a copy of the state row carries every part.

const SUPPORT := preload("res://tests/support.gd")
const P := "state_row_identity_test"
const RowEditOps := preload("res://addons/eventsheet/editor/dock/row_edit_ops.gd")


static func run() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	EventSheetStatesDialog.write(sheet, PackedStringArray(["IDLE", "RUN", "JUMP"]), "IDLE")
	var other: LocalVariable = LocalVariable.new()
	other.name = "speed"
	other.type_name = "float"
	other.default_value = "200.0"
	sheet.events.append(other)
	var declared: int = sheet.events.size()
	var event: EventRow = EventRow.new()
	sheet.events.append(event)
	# Choosing a state for is / go to shows each state's own sentence beside its name.
	var noted: Dictionary = EventSheetStatesDialog.model_of(sheet)
	((noted["states"] as Array)[1] as Dictionary)["note"] = "Running flat out."
	EventSheetStatesDialog.apply_model(sheet, noted)
	var offered: Array = EventSheetCompletions.candidates(sheet, EventSheetCompletions.FIELD_STATE)
	var details: Array = []
	for entry: Variant in offered:
		details.append([str((entry as Dictionary).get("text", "")), str((entry as Dictionary).get("detail", ""))])

	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(1200.0, 900.0)
	view.set_sheet(sheet)
	var state_row: EventRowData = null
	var state_index: int = -1
	var event_index: int = -1
	var drawn_rows: int = 0
	for index: int in view.get_flat_rows().size():
		var row_data: EventRowData = view._row_at(index)
		if row_data != null and ViewportRowBuilder._is_state_machine_row(row_data):
			state_row = row_data
			state_index = index
		if row_data != null and row_data.source_resource == event:
			event_index = index
		if row_data != null and row_data.source_resource != null:
			drawn_rows += 1
	var enum_row: EnumRow = EventSheetStateFacts.enum_row(sheet)
	var parts: Array[Resource] = EventSheetStateFacts.machine_parts(sheet, enum_row)
	var part_names: PackedStringArray = PackedStringArray()
	for part: Resource in parts:
		part_names.append(str(part.get("name") if part is LocalVariable else
			(part.get("enum_name") if part is EnumRow else part.get("signal_name"))))
	var widened: Array[Resource] = RowEditOps.with_machine_parts(sheet, [enum_row] as Array[Resource])
	var ordinary: Array[Resource] = RowEditOps.with_machine_parts(sheet, [other] as Array[Resource])
	var rows: Array = [
		["the state field offers each state with its sentence", details,
			[["IDLE", ""], ["RUN", "Running flat out."], ["JUMP", ""]]],
		["the name of the state variable opens the card of the lines the row keeps out of sight",
			_name_card_lines(state_row), PackedStringArray([
				"state_entered_msec - when the state it is in began",
				"previous_state - the state it was in before this one",
				"state_changed - announced every time the state changes"])],
		["the state row is drawn", state_row != null, true],
		["it acts for the enum it is drawn at", state_row.source_resource == enum_row if state_row != null else false, true],
		["the machine is the enum and every line the row hides",
			part_names, PackedStringArray(["State", "state_entered_msec", "previous_state", "state", "state_changed"])],
		["the hidden variable is part of it too", EventSheetStateFacts.machine_parts(sheet, parts[1]).size(), parts.size()],
		["an ordinary row has no machine", EventSheetStateFacts.machine_parts(sheet, other).size(), 0],
		["a delete of the state row widens to the whole machine", widened.size(), parts.size()],
		["a delete of an ordinary row stays that row", ordinary, [other] as Array[Resource]],
		["the sheet draws one row for the machine plus the ordinary ones", drawn_rows, 3],
		["carried over the middle of an event, the state row goes beside it, never into it",
			_drop_mode_over(view, state_index, event_index) in ["before", "after"], true],
	]
	for part: Resource in widened:
		sheet.events.erase(part)
	rows.append(["deleting the widened set takes the machine and leaves the rest", sheet.events, [other, event]])
	rows.append(["and nothing of the machine is left", EventSheetStateFacts.machine(sheet).is_empty()
		and EventSheetStateFacts.variable_row(sheet, "previous_state") == null, true])
	rows.append(["the sheet declared six lines before", declared, 6])
	view.free()
	return SUPPORT.pins(P, rows)


## The drop mode the sheet resolves for the state row carried over the middle of the event row.
static func _drop_mode_over(view: EventSheetViewport, carried_index: int, target_index: int) -> String:
	if carried_index < 0 or target_index < 0:
		return "<rows missing>"
	view._drag_row_index = carried_index
	view._drag_row_indices = [carried_index]
	var middle: Vector2 = Vector2(40.0, view._row_metrics_helper.row_top(target_index)
		+ view._row_metrics_helper.row_height(target_index) * 0.5)
	var mode: String = view._resolve_drop_mode({"row_index": target_index}, middle)
	view._drag_row_index = -1
	view._drag_row_indices = []
	return mode


static func _name_card_lines(state_row: EventRowData) -> PackedStringArray:
	if state_row == null:
		return PackedStringArray()
	for span: SemanticSpan in state_row.spans:
		var meta: Dictionary = span.metadata if span.metadata is Dictionary else {}
		if bool(meta.get("variable_name_span", false)):
			return (meta.get("head_card", {}) as Dictionary).get("lines", PackedStringArray())
	return PackedStringArray()
