# Godot EventSheets - a state is renamed or removed PROJECT-WIDE, and every machine is its own row.
#
# A state is an enum member, and other files can name it. The States window lists every sheet row and every
# other script that says the state before it changes anything, then changes all of them under one Undo; a
# removed state moves its users to the machine's default. Every `<x>_state` variable typed by an enum of its
# own is a machine and a state row of its own, and the state a running game is in carries its time inside
# its own token. These pin the pure halves of all of that, headless.
@tool
class_name StatesProjectWideTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const P := "states_project_wide_test"

const OTHER_SCRIPT := "extends Node\n\nfunc check(p: Player) -> void:\n\tif p.state == Player.State.RUN:\n\t\tprint(\"running\")\n\tmatch p.state:\n\t\tPlayer.State.RUN:\n\t\t\tpass\n\t\tPlayer.State.JUMP:\n\t\t\tpass\n"
const CHILD_SCRIPT := "extends Player\n\nfunc _ready() -> void:\n\tstate = State.RUN\n"
const UNRELATED_SCRIPT := "extends Node\n\nenum State { IDLE, RUN }\nvar state: State = State.RUN\n"


static func run() -> bool:
	var rows: Array = []

	# --- who names a state outside the sheet ---
	var sources: Dictionary = {"res://ui/hud.gd": OTHER_SCRIPT, "res://enemies/slime.gd": CHILD_SCRIPT, "res://misc/other.gd": UNRELATED_SCRIPT}
	var uses: Array[Dictionary] = EventSheetStateUses.scan(sources, "Player", "State", PackedStringArray(["RUN"]))
	rows.append(["two files use RUN, path ordered", _paths(uses), ["res://enemies/slime.gd", "res://ui/hud.gd"]])
	rows.append(["the file that says it through the class counts both lines", int(uses[1]["count"]), 2])
	rows.append(["the child that extends the class counts the bare enum", int(uses[0]["count"]), 1])
	rows.append(["an unrelated script's own enum is never listed", _paths(uses).has("res://misc/other.gd"), false])
	rows.append(["the list says file and places", EventSheetStateUses.list_lines(uses), PackedStringArray(["slime.gd - 1 place", "hud.gd - 2 places"])])
	rows.append(["a state nobody names lists nothing", EventSheetStateUses.scan(sources, "Player", "State", PackedStringArray(["DEAD"])).size(), 0])
	var rewritten: Dictionary = EventSheetStateUses.rewrite(OTHER_SCRIPT, "Player", "State", "RUN", "SPRINT")
	rows.append(["a rewrite says the new name in both places", [int(rewritten["hits"]), str(rewritten["text"]).contains("Player.State.SPRINT:"), str(rewritten["text"]).contains("Player.State.RUN")], [2, true, false]])
	rows.append(["...and leaves a different state alone", str(rewritten["text"]).contains("Player.State.JUMP:"), true])

	# --- the window: the rename and the removal are listed first, then done to the files ---
	var sheet: EventSheetResource = _machine_sheet()
	var model: Dictionary = EventSheetStatesDialog.model_of(sheet)
	((model["states"] as Array)[1] as Dictionary)["name"] = "SPRINT"
	var lines: PackedStringArray = EventSheetStatesDialog.effect_lines(sheet, model, {}, sources)
	rows.append(["the rename is listed with the sheet and each file", lines, PackedStringArray(["RUN becomes SPRINT in: this sheet (4 rows), slime.gd (1 place), hud.gd (2 places)."])])
	var edits: Dictionary = EventSheetStatesDialog.project_file_edits(sheet, model, {}, sources)
	rows.append(["only the files that name it are edited", edits.keys(), ["res://enemies/slime.gd", "res://ui/hud.gd"]])
	rows.append(["the edit carries the text before, so Undo can put it back",
		[str((edits["res://ui/hud.gd"] as Dictionary)["before"]) == OTHER_SCRIPT, str((edits["res://ui/hud.gd"] as Dictionary)["after"]).contains("Player.State.SPRINT")], [true, true]])
	rows.append(["the child's inherited spelling follows", str((edits["res://enemies/slime.gd"] as Dictionary)["after"]).contains("state = State.SPRINT"), true])
	var swap: Dictionary = EventSheetStatesDialog.model_of(sheet)
	((swap["states"] as Array)[1] as Dictionary)["name"] = "JUMP"
	((swap["states"] as Array)[2] as Dictionary)["name"] = "RUN"
	var swapped: String = str((EventSheetStatesDialog.project_file_edits(sheet, swap, {}, sources)["res://ui/hud.gd"] as Dictionary)["after"])
	rows.append(["two states that swap names do not meet halfway", [swapped.contains("if p.state == Player.State.JUMP:"), swapped.contains("Player.State.RUN:\n\t\t\tpass")], [true, true]])
	var removal: Dictionary = EventSheetStatesDialog.model_of(sheet)
	(removal["states"] as Array).remove_at(1)
	rows.append(["a removal lists the users and where they go",
		EventSheetStatesDialog.effect_lines(sheet, removal, {}, sources), PackedStringArray(["RUN is removed. These move to IDLE, the default: this sheet (4 rows), slime.gd (1 place), hud.gd (2 places)."])])
	var moved: String = str((EventSheetStatesDialog.project_file_edits(sheet, removal, {}, sources)["res://enemies/slime.gd"] as Dictionary)["after"])
	rows.append(["...and the file's users move to the default", moved.contains("state = State.IDLE"), true])

	# --- every <x>_state variable typed by its own enum is its own machine ---
	var two: EventSheetResource = _two_machine_sheet()
	var machines: Array[Dictionary] = EventSheetStateFacts.machines(two)
	rows.append(["a sheet with two machines finds two", _machine_variables(machines), ["state", "weapon_state"]])
	rows.append(["the second machine knows its own enum", str(machines[1]["enum_name"]), "WeaponState"])
	rows.append(["the second machine's states are its own", EventSheetStateFacts.bare_members(two, machines[1]), PackedStringArray(["HOLSTERED", "DRAWN", "FIRING"])])
	rows.append(["its default is the one the variable starts in", EventSheetStateFacts.default_member(two, machines[1]), "DRAWN"])
	rows.append(["the helper previous_state is no machine", EventSheetStateFacts.machine(two, "previous_state").is_empty(), true])
	rows.append(["a variable that shares the primary enum is no second machine", _machine_variables(EventSheetStateFacts.machines(_shared_enum_sheet())), ["state"]])
	rows.append(["a card for the second machine's state is keyed by its machine", str(EventSheetStateFacts.state_card(two, "DRAWN", machines[1]).get("id", "")), "state:weapon_state:DRAWN"])
	rows.append(["...and says it is the default", str(EventSheetStateFacts.state_card(two, "DRAWN", machines[1]).get("subtitle", "")), "the default state"])

	# --- the window renames and removes inside the second machine only ---
	var weapon_model: Dictionary = EventSheetStatesDialog.model_of(two, machines[1])
	((weapon_model["states"] as Array)[2] as Dictionary)["name"] = "SHOOTING"
	rows.append(["a second machine's rename applies", EventSheetStatesDialog.apply_model(two, weapon_model, machines[1]), true])
	rows.append(["...to its own enum", EventSheetStateFacts.bare_members(two, EventSheetStateFacts.machines(two)[1]), PackedStringArray(["HOLSTERED", "DRAWN", "SHOOTING"])])
	rows.append(["...and its own rows", _first_param(two, "weapon_phase"), "SHOOTING"])
	rows.append(["the primary machine is untouched", EventSheetStateFacts.bare_members(two, EventSheetStateFacts.machines(two)[0]), PackedStringArray(["IDLE", "RUN", "JUMP"])])
	rows.append(["the second machine's variable still starts in its default", str(EventSheetStateFacts.variable_row(two, "weapon_state").default_value), "WeaponState.DRAWN"])

	# --- the state row of each machine is drawn, and a click can pick a state ---
	var editor: EventSheetEditor = EventSheetEditor.new()
	editor.setup(_two_machine_sheet())
	var viewport: EventSheetViewport = editor.get_viewport_control()
	var state_rows: Array[EventRowData] = []
	var names: PackedStringArray = PackedStringArray()
	for entry: Variant in viewport.get_flat_rows():
		var row: EventRowData = (entry as Dictionary).get("row") as EventRowData
		if row == null:
			continue
		for span: SemanticSpan in row.spans:
			if span.text == "is one of":
				state_rows.append(row)
			if span.text in ["weapon_state", "state", "weapon_phase"] and bool((span.metadata as Dictionary).get("variable_name_span", false)):
				names.append(span.text)
	rows.append(["each machine is one row", state_rows.size(), 2])
	rows.append(["the second machine's variable is not also drawn as a loose variable", names, PackedStringArray(["state", "weapon_state"])])
	if state_rows.size() == 2:
		var drawn: SemanticSpan = _span(state_rows[1], "DRAWN")
		rows.append(["a state token names its state for the click", str((drawn.metadata as Dictionary).get("state_token", "")), "DRAWN"])
		rows.append(["...and its machine", str((drawn.metadata as Dictionary).get("variable_name", "")), "weapon_state"])
		rows.append(["only the primary machine's tokens can light up for the game", (drawn.metadata as Dictionary).has("state_name"), false])
		rows.append(["the primary machine's tokens can", (_span(state_rows[0], "RUN").metadata as Dictionary).has("state_name"), true])

	# --- the live state lights up INSIDE its token, with its time ---
	EventSheetStateWatch.clear()
	rows.append(["no game, no token text", EventSheetStateWatch.token_text("RUN"), ""])
	var before: String = EventSheetStateWatch.live_signature()
	EventSheetStateWatch.note_frame({"state": "RUN", "state_seconds": 3.24}, "")
	rows.append(["the live token reads the state and how long it held", EventSheetStateWatch.token_text("RUN"), "RUN · 3.2 s"])
	rows.append(["a state the game is not in has no token text", EventSheetStateWatch.token_text("IDLE"), ""])
	rows.append(["the layout changes only when the state changes", [before, EventSheetStateWatch.live_signature()], ["", "RUN"]])
	EventSheetStateWatch.note_frame({"state": "RUN", "state_seconds": 4.5}, "")
	rows.append(["the seconds moving does not change the layout word", EventSheetStateWatch.live_signature(), "RUN"])
	rows.append(["the token reserves room for a hundred seconds", EventSheetStateWatch.token_reserve("RUN"), "RUN · 99.9 s"])
	var live_row: EventRowData = null
	editor.get_viewport_control().rebuild_rows()
	for entry: Variant in viewport.get_flat_rows():
		var maybe: EventRowData = (entry as Dictionary).get("row") as EventRowData
		if maybe != null and _span(maybe, "is one of") != null and _span(maybe, "RUN") != null:
			live_row = maybe
	if live_row != null:
		rows.append(["while live the row holds the room for the token's time", _span(live_row, "RUN · 99.9 s") != null, true])
	EventSheetStateWatch.clear()
	rows.append(["the row's end carries no chip of the live state", viewport._live_values_helper.chip_for(live_row) if live_row != null else "", ""])

	# --- every variable type has a card (int, float, bool, String, Vector2, enum, node, resource) ---
	var typed: EventSheetResource = _two_machine_sheet()
	for pair: Array in [["hp", "int"], ["speed", "float"], ["alive", "bool"], ["label", "String"], ["pos", "Vector2"], ["target", "Node2D"], ["icon", "Texture2D"]]:
		var variable: LocalVariable = LocalVariable.new()
		variable.name = str(pair[0])
		variable.type_name = str(pair[1])
		typed.events.append(variable)
	var card_titles: Array = []
	var card_notes: Array = []
	for type_name: String in ["int", "float", "bool", "String", "Vector2", "WeaponState", "Node2D", "Texture2D"]:
		var card: Dictionary = EventSheetTypeCards.card_for(type_name, typed)
		card_titles.append(str(card.get("title", "")))
		card_notes.append(str((card.get("notes", PackedStringArray([""])) as PackedStringArray)[0]))
	rows.append(["a card exists for each of the eight kinds of type", card_titles, ["int", "float", "bool", "String", "Vector2", "WeaponState", "Node2D", "Texture2D"]])
	rows.append(["...each naming the page it comes from", card_notes, [
		"Godot class reference: int", "Godot class reference: float", "Godot class reference: bool", "Godot class reference: String",
		"Godot class reference: Vector2", "Godot manual: GDScript, enums", "Godot class reference: Node2D", "Godot class reference: Texture2D"]])
	var typed_editor: EventSheetEditor = EventSheetEditor.new()
	typed_editor.setup(typed)
	var marks: Dictionary = {}
	for entry: Variant in typed_editor.get_viewport_control().get_flat_rows():
		var row: EventRowData = (entry as Dictionary).get("row") as EventRowData
		if row == null:
			continue
		for span: SemanticSpan in row.spans:
			if bool((span.metadata as Dictionary).get("variable_type_span", false)):
				var head: Variant = (span.metadata as Dictionary).get("head_card", {})
				marks[str((head as Dictionary).get("title", span.text))] = bool((span.metadata as Dictionary).get("hover_card_mark", false))
	rows.append(["every drawn type word has a dotted rule and a card", [marks.get("int"), marks.get("float"), marks.get("bool"), marks.get("String"), marks.get("Vector2"), marks.get("Node2D"), marks.get("Texture2D")],
		[true, true, true, true, true, true, true]])
	return SUPPORT.pins(P, rows)


static func _paths(uses: Array[Dictionary]) -> Array:
	var out: Array = []
	for entry: Dictionary in uses:
		out.append(str(entry["path"]))
	return out


static func _machine_variables(machines: Array[Dictionary]) -> Array:
	var out: Array = []
	for found: Dictionary in machines:
		out.append(str(found["variable_name"]))
	return out


static func _span(row: EventRowData, text: String) -> SemanticSpan:
	for span: SemanticSpan in row.spans:
		if span.text == text:
			return span
	return null


static func _first_param(sheet: EventSheetResource, variable_marker: String) -> String:
	for entry: Variant in sheet.events:
		var raw: RawCodeRow = entry as RawCodeRow
		if raw != null and raw.code.contains(variable_marker):
			var at: int = raw.code.find("WeaponState.")
			return raw.code.substr(at + 12).split("\n")[0].strip_edges()
	return ""


static func _machine_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	sheet.custom_class_name = "Player"
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


static func _two_machine_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = _machine_sheet()
	var weapon_enum: EnumRow = EnumRow.new()
	weapon_enum.enum_name = "WeaponState"
	weapon_enum.members = PackedStringArray(["HOLSTERED", "DRAWN", "FIRING"])
	sheet.events.append(weapon_enum)
	var weapon: LocalVariable = LocalVariable.new()
	weapon.name = "weapon_state"
	weapon.type_name = "WeaponState"
	weapon.default_value = "WeaponState.DRAWN"
	weapon.expression_default = true
	sheet.events.append(weapon)
	var phase: RawCodeRow = RawCodeRow.new()
	phase.code = "var weapon_phase := WeaponState.FIRING"
	sheet.events.append(phase)
	return sheet


static func _shared_enum_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = _machine_sheet()
	var other: LocalVariable = LocalVariable.new()
	other.name = "ai_state"
	other.type_name = "State"
	other.default_value = "State.IDLE"
	other.expression_default = true
	sheet.events.append(other)
	return sheet


static func _ace(ace: Resource, ace_id: String, params: Dictionary) -> Resource:
	ace.set("provider_id", "Core")
	ace.set("ace_id", ace_id)
	ace.set("params", params)
	return ace
