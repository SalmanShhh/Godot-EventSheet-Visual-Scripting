# Godot EventSheets - a state machine is ONE row, said once, in the code's own words.
#
# What used to read four times in three spellings (a band, the enum row, the state variable and three
# helper declarations, then rows borrowing the host or System) is one row: the state glyph, the type, the
# variable's name, "is one of", the states as written with the default marked, and what the machine is
# for. The helper declarations stay in the code and are not drawn; the rows that use the machine name the
# state variable as their object; every state name and every type word carries a card.
@tool
class_name StateRowTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "state_row_test"


static func run() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	EventSheetStatesDialog.write(sheet, PackedStringArray(["IDLE", "RUN", "JUMP"]), "RUN")
	var model: Dictionary = EventSheetStatesDialog.model_of(sheet)
	model["description"] = "What the player is doing."
	((model["states"] as Array)[0] as Dictionary)["note"] = "Standing still."
	EventSheetStatesDialog.apply_model(sheet, model)
	var asking: EventRow = EventRow.new()
	asking.conditions.append(_ace(ACECondition.new(), "InState", {"state": "RUN"}))
	asking.actions.append(_ace(ACEAction.new(), "GoToState", {"state": "JUMP"}))
	sheet.events.append(asking)
	var speed: LocalVariable = LocalVariable.new()
	speed.name = "speed"
	speed.type_name = "float"
	speed.default_value = 220.0
	sheet.events.append(speed)

	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(sheet)
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var rows: Array[EventRowData] = []
	for entry: Variant in viewport.get_flat_rows():
		rows.append((entry as Dictionary).get("row") as EventRowData)
	var state_row: EventRowData = null
	var speed_row: EventRowData = null
	var event_row: EventRowData = null
	var drawn_names: PackedStringArray = PackedStringArray()
	for row: EventRowData in rows:
		if row == null:
			continue
		for span: SemanticSpan in row.spans:
			if span.text == "is one of":
				state_row = row
			if span.text == "speed":
				speed_row = row
				drawn_names.append(span.text)
		if row.row_type == EventRowData.RowType.EVENT and event_row == null and row.event_number > 0:
			event_row = row
		for span: SemanticSpan in row.spans:
			if span.text in ["previous_state", "state_entered_msec", "On State Changed"]:
				drawn_names.append(span.text)

	var table: Array = [
		["the machine is one row", state_row != null, true],
		["the helper declarations are not drawn as rows", drawn_names, PackedStringArray(["speed"])],
		["no head band repeats the states", EventSheetHeadBands.facts(sheet, "").get("states", ""), ""],
		["the head still knows states are declared", EventSheetHeadBands.facts(sheet, "").get("states_declared", false), true],
	]
	if state_row != null:
		var words: PackedStringArray = PackedStringArray()
		for span: SemanticSpan in state_row.spans:
			if not span.text.strip_edges().is_empty() and not span.text.strip_edges() == "x":
				words.append(span.text)
		table.append(["the row reads type, name, is one of, the states as written, the default marked, then what it is for",
			words.slice(words.find("State")), PackedStringArray(["State", "state", "is one of", "IDLE", "·", "RUN", "(default)", "·", "JUMP", "What the player is doing."])])
		var run_span: SemanticSpan = _span(state_row, "RUN")
		table.append(["a state name has a dotted rule", bool((run_span.metadata as Dictionary).get("hover_card_mark", false)), true])
		table.append(["...and a card with its name, that it is the default, and its sentence",
			[(run_span.metadata["head_card"] as Dictionary).get("title"), (run_span.metadata["head_card"] as Dictionary).get("subtitle")],
			["RUN", "the default state"]])
		var idle_card: Dictionary = _span(state_row, "IDLE").metadata["head_card"] as Dictionary
		table.append(["a state's sentence is on its card", [idle_card.get("title"), idle_card.get("subtitle"), (idle_card.get("lines") as PackedStringArray)[0]],
			["IDLE", null, "Standing still."]])
		var type_span: SemanticSpan = _span(state_row, "State")
		table.append(["the type word carries the state glyph", (type_span.metadata as Dictionary).get("object_glyph"), "state"])
		table.append(["...and a card saying it is an enum", ((type_span.metadata["head_card"] as Dictionary).get("lines") as PackedStringArray)[0].begins_with("An enum: one of a fixed set of named values, IDLE, RUN or JUMP."), true])
		table.append(["a double-click on the row opens the States window, not the variable", bool((run_span.metadata as Dictionary).get("state_machine", false)), true])
	if speed_row != null:
		var float_span: SemanticSpan = _type_span(speed_row)
		table.append(["every variable's type has a dotted rule", float_span != null and bool((float_span.metadata as Dictionary).get("hover_card_mark", false)), true])
		if float_span != null:
			var card: Dictionary = float_span.metadata["head_card"] as Dictionary
			table.append(["...and a sentence with the page it comes from", [card.get("title"), (card.get("notes") as PackedStringArray)[0]],
				["float", "Godot class reference: float"]])
	if event_row != null:
		viewport._row_builder._ensure_event_spans(event_row)
		var condition: SemanticSpan = null
		var action: SemanticSpan = null
		for span: SemanticSpan in event_row.spans:
			if str(span.metadata.get("kind", "")) == "condition" and condition == null:
				condition = span
			if str(span.metadata.get("kind", "")) == "action" and action == null:
				action = span
		table.append(["the condition says is RUN about the state variable", [condition.text, condition.metadata.get("object_label"), condition.metadata.get("object_glyph")],
			["is RUN", "state", "state"]])
		table.append(["the action says go to JUMP about the state variable", [action.text, action.metadata.get("object_label")],
			["go to JUMP", "state"]])
		table.append(["a state named inside a sentence is a word with a card", ((condition.metadata.get("word_cards", []) as Array)[0] as Dictionary).get("length"), 3])
	return SUPPORT.pins(P, table)


static func _span(row: EventRowData, text: String) -> SemanticSpan:
	for span: SemanticSpan in row.spans:
		if span.text == text:
			return span
	return null


static func _type_span(row: EventRowData) -> SemanticSpan:
	for span: SemanticSpan in row.spans:
		if span.metadata is Dictionary and bool((span.metadata as Dictionary).get("variable_type_span", false)):
			return span
	return null


static func _ace(ace: Resource, ace_id: String, params: Dictionary) -> Resource:
	ace.set("provider_id", "Core")
	ace.set("ace_id", ace_id)
	ace.set("params", params)
	return ace
