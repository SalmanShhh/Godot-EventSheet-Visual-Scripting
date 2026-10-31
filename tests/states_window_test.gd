# Godot EventSheets - the States window's working copy: what Apply writes, and what a rename follows.
#
# The window edits a COPY of the machine (names, sentences, the default) and writes it in one edit. These
# pin the writing: a rename reaches every row that said the old name (conditions, actions, both triggers,
# the lines of a match and of kept code), the default is always exactly one and moves on when its state is
# removed, a state some row still uses cannot be removed, and the sentences land as the `##` lines above
# the enum and its members and read back the same.
@tool
class_name StatesWindowTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "states_window_test"


static func run() -> bool:
	var rows: Array = []
	var sheet: EventSheetResource = _machine_sheet()

	# --- the working copy reads the machine as written ---
	var model: Dictionary = EventSheetStatesDialog.model_of(sheet)
	rows.append(["the copy lists the states as written", _names(model), ["IDLE", "RUN", "JUMP"]])
	rows.append(["the copy knows the default", int(model["default"]), 0])
	rows.append(["a sheet with no machine gets three to start from", _names(EventSheetStatesDialog.model_of(EventSheetResource.new())), ["IDLE", "CHASE", "HURT"]])

	# --- a rename is followed everywhere ---
	var renamed: Dictionary = EventSheetStatesDialog.model_of(sheet)
	((renamed["states"] as Array)[1] as Dictionary)["name"] = "SPRINT"
	rows.append(["a rename is not a problem", EventSheetStatesDialog.problem_with(sheet, renamed), ""])
	rows.append(["applying it succeeds", EventSheetStatesDialog.apply_model(sheet, renamed), true])
	rows.append(["the enum member is renamed", EventSheetStateFacts.bare_members(sheet), PackedStringArray(["IDLE", "SPRINT", "JUMP"])])
	rows.append(["the condition followed", _param(sheet.events[_index_of_row(sheet, 0)], "conditions", 0), "SPRINT"])
	rows.append(["the action followed", _param(sheet.events[_index_of_row(sheet, 0)], "actions", 0), "SPRINT"])
	rows.append(["the trigger followed", str((sheet.events[_index_of_row(sheet, 1)] as EventRow).trigger_params.get("state", "")), "SPRINT"])
	rows.append(["a line of kept code followed", _kept_code(sheet).contains("State.SPRINT") and not _kept_code(sheet).contains("State.RUN"), true])

	# --- exactly one default, always ---
	var moved: Dictionary = EventSheetStatesDialog.model_of(sheet)
	moved["default"] = 2
	EventSheetStatesDialog.apply_model(sheet, moved)
	rows.append(["the variable starts in the chosen default", EventSheetStateFacts.default_member(sheet), "JUMP"])
	rows.append(["...and the variable line says so", str(EventSheetStateFacts.variable_row(sheet, "state").default_value), "State.JUMP"])

	# --- a state rows still use cannot be removed; one nothing uses can, and the default moves on ---
	var removing: Dictionary = EventSheetStatesDialog.model_of(sheet)
	(removing["states"] as Array).remove_at(1)
	removing["default"] = 1
	rows.append(["a state that rows still say cannot be removed", EventSheetStatesDialog.problem_with(sheet, removing).is_empty(), false])
	rows.append(["...and nothing changes", EventSheetStatesDialog.apply_model(sheet, removing), false])
	rows.append(["...the members are as they were", EventSheetStateFacts.bare_members(sheet), PackedStringArray(["IDLE", "SPRINT", "JUMP"])])

	# --- sentences are ## lines, and read back ---
	var noted: Dictionary = EventSheetStatesDialog.model_of(sheet)
	noted["description"] = "What the player is doing."
	((noted["states"] as Array)[0] as Dictionary)["note"] = "Standing still."
	EventSheetStatesDialog.apply_model(sheet, noted)
	var enum_row: EnumRow = EventSheetStateFacts.enum_row(sheet)
	rows.append(["the description is the enum's", enum_row.description, "What the player is doing."])
	rows.append(["the state's note is the member's", enum_row.note_for("IDLE"), "Standing still."])
	var written: String = str(SheetCompiler.compile(sheet).get("output", ""))
	rows.append(["the compiler writes the ## lines in place", written.contains("## What the player is doing.\nenum State {\n\t## Standing still.\n\tIDLE,"), true])
	rows.append(["the code preview is the same text", EventSheetStatesDialog.code_for(noted).begins_with("## What the player is doing.\nenum State {\n\t## Standing still.\n\tIDLE,"), true])

	# --- names must be names ---
	var bad: Dictionary = EventSheetStatesDialog.model_of(sheet)
	((bad["states"] as Array)[0] as Dictionary)["name"] = "2fast"
	rows.append(["a name that cannot be an identifier is refused", EventSheetStatesDialog.problem_with(sheet, bad).contains("2fast"), true])
	var twice: Dictionary = EventSheetStatesDialog.model_of(sheet)
	((twice["states"] as Array)[0] as Dictionary)["name"] = "JUMP"
	rows.append(["two states of one name are refused", EventSheetStatesDialog.problem_with(sheet, twice).contains("JUMP"), true])
	return SUPPORT.pins(P, rows)


static func _machine_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	EventSheetStatesDialog.write(sheet, PackedStringArray(["IDLE", "RUN", "JUMP"]), "IDLE")
	var asking: EventRow = EventRow.new()
	asking.conditions.append(_ace(ACECondition.new(), "InState", {"state": "RUN"}))
	asking.actions.append(_ace(ACEAction.new(), "GoToState", {"state": "RUN"}))
	sheet.events.append(asking)
	var entering: EventRow = EventRow.new()
	entering.trigger_id = "OnEnteringState"
	entering.trigger_params = {"state": "RUN"}
	sheet.events.append(entering)
	var kept: RawCodeRow = RawCodeRow.new()
	kept.code = "if velocity.x != 0:\n\tstate = State.RUN"
	sheet.events.append(kept)
	return sheet


static func _ace(ace: Resource, ace_id: String, params: Dictionary) -> Resource:
	ace.set("provider_id", "Core")
	ace.set("ace_id", ace_id)
	ace.set("params", params)
	return ace


static func _names(model: Dictionary) -> Array:
	var out: Array = []
	for entry: Dictionary in (model["states"] as Array):
		out.append(str(entry["name"]))
	return out


static func _index_of_row(sheet: EventSheetResource, nth_event: int) -> int:
	var seen: int = 0
	for index: int in sheet.events.size():
		if sheet.events[index] is EventRow:
			if seen == nth_event:
				return index
			seen += 1
	return -1


static func _param(entry: Resource, lane: String, at: int) -> String:
	var ace: Resource = (entry.get(lane) as Array)[at]
	return str((ace.get("params") as Dictionary).get("state", ""))


static func _kept_code(sheet: EventSheetResource) -> String:
	for entry: Variant in sheet.events:
		if entry is RawCodeRow:
			return (entry as RawCodeRow).code
	return ""
