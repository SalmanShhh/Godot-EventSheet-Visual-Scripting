# EventForge - the game's own mode: declared once, guarded once, and read back.
#
# The whole feature rests on one decision - a game's modes are four ORDINARY declarations, not a new
# kind of thing - so this pins the consequences of that decision:
#   1. the reader: what a sheet's declarations say its modes are, and the silence of a sheet with
#      none,
#   2. the guard: a group that runs in a mode wraps its rows in the test it stands for, joined with
#      the other two guards in the order the compiler joins them,
#   3. the moment: On leaving fires before On entering, in ONE handler, because the engine raises one
#      signal for a change,
#   4. the round trip: a sheet with modes compiles, opens and re-emits byte for byte - including a
#      group whose only annotation is which mode it runs in.
@tool
class_name GameStateTest
extends RefCounted

const OUT_PATH := "user://__eventsheets_modes_probe.gd"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _run_reader() and all_passed
	all_passed = _run_guard() and all_passed
	all_passed = _run_moment() and all_passed
	all_passed = _run_round_trip() and all_passed
	all_passed = _run_dialog() and all_passed
	all_passed = _run_findings() and all_passed
	all_passed = _run_seen() and all_passed
	if all_passed:
		print("[PASS] game_state_test: the reader, the guard, the moment, the round trip, the dialog, the findings and the trail")
	return all_passed


# ── 5. What the Edit modes dialog writes ──────────────────────────────────────────────────
static func _run_dialog() -> bool:
	var all_passed: bool = true
	all_passed = _check("the modes field is not a syntax to learn",
		EventSheetModesDialog.words_of("Playing · Paused, Cutscene | Menu"),
		PackedStringArray(["Playing", "Paused", "Cutscene", "Menu"])) and all_passed
	all_passed = _check("and it says what it will write",
		EventSheetModesDialog.in_code(PackedStringArray(["Playing", "Game Over"]), "Playing"),
		"enum Mode { PLAYING, GAME_OVER } · var mode: Mode = Mode.PLAYING") and all_passed

	# Four declarations onto a bare sheet, and not one of them a new kind of thing.
	var sheet: EventSheetResource = EventSheetResource.new()
	all_passed = _check("the dialog writes the declarations",
		EventSheetModesDialog.write(sheet, PackedStringArray(["Playing", "Paused"]), "Paused", {}),
		true) and all_passed
	all_passed = _check("the sheet now declares modes",
		EventSheetModeFacts.names(sheet), PackedStringArray(["Playing", "Paused"])) and all_passed
	all_passed = _check("starting in the one it was told",
		EventSheetModeFacts.starts_in(sheet), "Paused") and all_passed
	all_passed = _check("with a stack for Push and Go back",
		EventSheetModeFacts.has_stack(sheet), true) and all_passed
	all_passed = _check("and the two functions those rows call",
		_function_names(sheet), PackedStringArray(["push_mode", "go_back"])) and all_passed
	# Writing again leaves them exactly as they are - a body somebody rewrote is theirs.
	(sheet.functions[0] as EventFunction).description = "mine now"
	EventSheetModesDialog.write(sheet, PackedStringArray(["Playing", "Paused"]), "Paused", {})
	all_passed = _check("and a second write does not replace them",
		str((sheet.functions[0] as EventFunction).description), "mine now") and all_passed
	all_passed = _check("and no policy rows at all, because nothing asked for one",
		_entering_events(sheet), 0) and all_passed

	# One mode that wants something else, and every mode says what it wants - a policy has to be
	# total to be true, or entering a mode from the paused one leaves the game paused.
	EventSheetModesDialog.write(sheet, PackedStringArray(["Playing", "Paused"]), "Paused",
		{"Paused": {"physics": false, "mouse": true}})
	all_passed = _check("every mode now says what it wants", _entering_events(sheet), 2) and all_passed
	var read_back: Dictionary = EventSheetModesDialog.read_policy(sheet)
	all_passed = _check("and the answers read back off the rows",
		read_back.get("Paused", {}), {"physics": false, "mouse": true}) and all_passed
	all_passed = _check("including the mode that wanted the plain ones",
		read_back.get("Playing", {}), {"physics": true, "mouse": true}) and all_passed
	# Rewriting with nothing special takes the rows away again: a sheet should not carry two rows
	# per mode saying the game runs normally.
	EventSheetModesDialog.write(sheet, PackedStringArray(["Playing", "Paused"]), "Paused", {})
	all_passed = _check("and they go away when nothing wants them", _entering_events(sheet), 0) and all_passed
	return all_passed


# ── 6. The two things that go wrong with modes ────────────────────────────────────────────
static func _run_findings() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = _modes_sheet()
	all_passed = _check("a sheet nothing points at yet says every mode is unused",
		_kinds(EventSheetModeFacts.findings(sheet)),
		PackedStringArray([EventSheetModeFacts.KIND_MODE_UNUSED, EventSheetModeFacts.KIND_MODE_UNUSED,
			EventSheetModeFacts.KIND_MODE_UNUSED, EventSheetModeFacts.KIND_MODE_UNUSED])) and all_passed

	# A game that can reach the cutscene and nothing else: the softlock, found at authoring.
	var stuck: EventSheetResource = _modes_sheet()
	stuck.events.append(_row("OnReady", [], [_go_to_mode("CUTSCENE")]))
	var found: Array[Dictionary] = EventSheetModeFacts.findings(stuck)
	all_passed = _check("the mode rows enter but never leave is the softlock",
		_kind_for(found, "Cutscene"), EventSheetModeFacts.KIND_NO_WAY_OUT) and all_passed
	all_passed = _check("said in the words of what it costs a player",
		_message_for(found, "Cutscene"),
		"Rows go to Cutscene and none of them ever leaves it. A player who reaches that mode is stuck in it.") and all_passed

	# A second way out, and the finding goes with nothing to clean up.
	stuck.events.append(_row("OnProcess", [], [_go_to_mode("PLAYING")]))
	all_passed = _check("a way out clears it",
		_kind_for(EventSheetModeFacts.findings(stuck), "Cutscene"), "") and all_passed

	# THE REACHABILITY IS THE WHOLE QUESTION. A three-mode game where every mode is entered and only
	# the last one has nothing leaving it: the finding has to name that one and only that one, which
	# it cannot do by asking whether the sheet has more than one mode in it.
	var chain: EventSheetResource = _modes_sheet()
	chain.events.append(_row("OnReady", [], [_go_to_mode("MENU")]))
	chain.events.append(_row("OnProcess", [_in_mode("MENU")], [_go_to_mode("PLAYING")]))
	chain.events.append(_row("OnProcess", [_in_mode("PLAYING")], [_go_to_mode("CUTSCENE")]))
	chain.events.append(_row("OnProcess", [_in_mode("CUTSCENE")], [_action("hud_shown = false")]))
	var chained: Array[Dictionary] = EventSheetModeFacts.findings(chain)
	all_passed = _check("the mode at the end of the chain is the one nobody leaves",
		_kind_for(chained, "Cutscene"), EventSheetModeFacts.KIND_NO_WAY_OUT) and all_passed
	all_passed = _check("and the modes with a row leaving them are clear",
		[_kind_for(chained, "Menu"), _kind_for(chained, "Playing")], ["", ""]) and all_passed

	# A row gated on ANOTHER mode cannot be the way out of this one, and a row that runs once when
	# the game starts is how the game begins rather than how a player gets unstuck.
	var one_shot: EventSheetResource = _modes_sheet()
	one_shot.events.append(_row("OnProcess", [_in_mode("PLAYING")], [_go_to_mode("CUTSCENE")]))
	one_shot.events.append(_row("OnReady", [], [_go_to_mode("MENU")]))
	all_passed = _check("neither shape is a way out of the cutscene",
		_kind_for(EventSheetModeFacts.findings(one_shot), "Cutscene"),
		EventSheetModeFacts.KIND_NO_WAY_OUT) and all_passed

	# Go back is a way out of anything that can reach it, and a group's own "runs in" gates the rows
	# inside it exactly as an In mode condition on each of them would.
	var popped: EventSheetResource = _modes_sheet()
	popped.events.append(_row("OnProcess", [_in_mode("PLAYING")], [_go_to_mode("CUTSCENE")]))
	var while_watching: EventGroup = EventGroup.new()
	while_watching.name = "Cutscene"
	while_watching.runs_in = "Cutscene"
	while_watching.events.append(_row("OnProcess", [], [_go_back_mode()]))
	popped.events.append(while_watching)
	all_passed = _check("a Go back inside the group that runs in the mode is the way out",
		_kind_for(EventSheetModeFacts.findings(popped), "Cutscene"), "") and all_passed
	return all_passed


# ── 7. What a running game shows: the trail, and the guard in the why report ──────────────
static func _run_seen() -> bool:
	var all_passed: bool = true
	all_passed = _check("nothing streamed yet is no trail",
		EventSheetLiveValuesPanel.trail_reading(PackedStringArray()), "") and all_passed
	all_passed = _check("the trail says how the game got where it is",
		EventSheetLiveValuesPanel.trail_reading(PackedStringArray(["MENU", "PLAYING", "CUTSCENE"])),
		"Menu › Playing › Cutscene") and all_passed

	var sheet: EventSheetResource = _modes_sheet()
	var group: EventGroup = EventGroup.new()
	group.name = "Movement"
	group.runs_in = "Playing"
	var row: EventRow = _row("OnProcess", [], [_action("velocity.x = 100.0")])
	group.events.append(row)
	sheet.events.append(group)
	all_passed = _check("the why report names the guard and the mode the game was in",
		EventSheetWhyPanel.mode_guard_line(sheet, row, {"mode": "CUTSCENE"}),
		"It runs in Playing; the game was in Cutscene - the trail in Live Values says how it got there.") and all_passed
	all_passed = _check("and says nothing when the two agree",
		EventSheetWhyPanel.mode_guard_line(sheet, row, {"mode": "PLAYING"}), "") and all_passed
	all_passed = _check("nor when nothing has streamed a mode",
		EventSheetWhyPanel.mode_guard_line(sheet, row, {}), "") and all_passed
	return all_passed


## The functions a sheet declares, in order.
static func _function_names(sheet: EventSheetResource) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for entry: Variant in sheet.functions:
		var declared: EventFunction = entry as EventFunction
		if declared != null:
			names.append(declared.function_name)
	return names


## How many On entering events a sheet carries - what the policy is written as.
static func _entering_events(sheet: EventSheetResource) -> int:
	var counted: int = 0
	for entry: Variant in sheet.events:
		var event_row: EventRow = entry as EventRow
		if event_row != null and event_row.trigger_id == EventSheetModeFacts.ENTERING_TRIGGER_ID:
			counted += 1
	return counted


static func _kinds(found: Array[Dictionary]) -> PackedStringArray:
	var kinds: PackedStringArray = PackedStringArray()
	for finding: Dictionary in found:
		kinds.append(str(finding.get("kind", "")))
	return kinds


static func _kind_for(found: Array[Dictionary], subject: String) -> String:
	for finding: Dictionary in found:
		if str(finding.get("subject", "")) == subject:
			return str(finding.get("kind", ""))
	return ""


static func _message_for(found: Array[Dictionary], subject: String) -> String:
	for finding: Dictionary in found:
		if str(finding.get("subject", "")) == subject:
			return str(finding.get("message", ""))
	return ""


# ── 1. What a sheet's declarations say its modes are ──────────────────────────────────────
static func _run_reader() -> bool:
	var all_passed: bool = true
	var quiet: EventSheetResource = EventSheetResource.new()
	all_passed = _check("a sheet with no enum declares no modes",
		EventSheetModeFacts.declares_modes(quiet), false) and all_passed
	all_passed = _check("and its band says nothing at all",
		EventSheetModeFacts.band_reading(quiet), "") and all_passed

	var sheet: EventSheetResource = _modes_sheet()
	all_passed = _check("the modes are the enum's members, as words",
		EventSheetModeFacts.names(sheet),
		PackedStringArray(["Playing", "Paused", "Cutscene", "Menu"])) and all_passed
	all_passed = _check("the mode it starts in is the variable's own value",
		EventSheetModeFacts.starts_in(sheet), "Menu") and all_passed
	all_passed = _check("the band is one fact: the modes, and the one it opens on",
		EventSheetModeFacts.band_reading(sheet),
		"Playing · Paused · Cutscene · Menu - starts in Menu") and all_passed
	all_passed = _check("and it echoes the line the compiler writes",
		EventSheetModeFacts.band_echo(sheet),
		"enum Mode { PLAYING, PAUSED, CUTSCENE, MENU }") and all_passed
	all_passed = _check("the sheet keeps a stack, so Push and Go back have somewhere to push",
		EventSheetModeFacts.has_stack(sheet), true) and all_passed

	# The two spellings of a mode, and the one rule that turns each into the other.
	all_passed = _check("a member reads as a word",
		EventSheetModeFacts.word_for("GAME_OVER"), "Game Over") and all_passed
	all_passed = _check("an explicit value is not part of the word",
		EventSheetModeFacts.word_for("MENU = 3"), "Menu") and all_passed
	all_passed = _check("and the word writes back as the member",
		EventSheetModeFacts.member_for("Game Over"), "GAME_OVER") and all_passed
	return all_passed


# ── 2. The guard a group's mode puts on its rows ──────────────────────────────────────────
static func _run_guard() -> bool:
	var all_passed: bool = true
	all_passed = _check("a group that names no mode guards nothing",
		EventGroup.runs_in_guard(""), "") and all_passed
	all_passed = _check("and one that names a mode compiles to the comparison it stands for",
		EventGroup.runs_in_guard("Playing"), "mode == Mode.PLAYING") and all_passed
	all_passed = _check("a two-word mode is one member",
		EventGroup.runs_in_guard("Game Over"), "mode == Mode.GAME_OVER") and all_passed

	var sheet: EventSheetResource = _modes_sheet()
	var group: EventGroup = EventGroup.new()
	group.name = "Movement"
	group.group_name = "Movement"
	group.runs_in = "Playing"
	group.events.append(_row("OnProcess", [], [_action("velocity.x = 100.0")]))
	sheet.events.append(group)
	var built: String = str(SheetCompiler.compile(sheet, OUT_PATH).get("output", ""))
	all_passed = _check("the group's rows run behind the mode test",
		built.contains("\tif mode == Mode.PLAYING:"), true) and all_passed
	all_passed = _check("and the header says which mode, so opening the file finds it again",
		built.contains("runs_in=\"Playing\""), true) and all_passed
	all_passed = _check("the emitted script parses", _parses(built), true) and all_passed
	return all_passed


# ── 3. Leaving before entering, in one handler ────────────────────────────────────────────
static func _run_moment() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = _modes_sheet()
	# Deliberately written the wrong way round: entering first, leaving second. The emitter is what
	# puts them in the order the game runs them.
	sheet.events.append(_row(EventSheetModeFacts.ENTERING_TRIGGER_ID, [],
		[_action("hud_shown = false")], {"mode": "CUTSCENE"}))
	sheet.events.append(_row(EventSheetModeFacts.LEAVING_TRIGGER_ID, [],
		[_action("hud_shown = true")], {"mode": "CUTSCENE"}))
	var built: String = str(SheetCompiler.compile(sheet, OUT_PATH).get("output", ""))
	all_passed = _check("both rows share one handler",
		built.count("func _on_mode_changed("), 1) and all_passed
	all_passed = _check("which takes both halves of the change",
		built.contains("func _on_mode_changed(from_mode: int, to_mode: int) -> void:"), true) and all_passed
	all_passed = _check("and is wired to the signal the mode rows emit",
		built.contains("mode_changed.connect(_on_mode_changed)"), true) and all_passed
	var leaving_at: int = built.find("if from_mode == Mode.CUTSCENE:")
	var entering_at: int = built.find("if to_mode == Mode.CUTSCENE:")
	all_passed = _check("leaving is written", leaving_at >= 0, true) and all_passed
	all_passed = _check("entering is written", entering_at >= 0, true) and all_passed
	all_passed = _check("and leaving comes first, whatever order the sheet is in",
		leaving_at < entering_at, true) and all_passed
	all_passed = _check("the emitted script parses", _parses(built), true) and all_passed

	# The handler these two rows share does not open as the two rows again - it comes back as a
	# readable function block, which is the honest degradation. What must hold is the promise under
	# it: the file opens and saves byte for byte, so nothing an author wrote is at risk either way.
	var file: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	file.store_string(built)
	file.close()
	var opened: EventSheetResource = GDScriptImporter.new().import_external(OUT_PATH)
	all_passed = _check("a sheet with mode triggers opens and saves byte for byte",
		str(SheetCompiler.compile(opened, OUT_PATH).get("output", "")), built) and all_passed
	return all_passed


# ── 4. Compiled, opened, re-emitted byte for byte ─────────────────────────────────────────
static func _run_round_trip() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = _modes_sheet()
	var group: EventGroup = EventGroup.new()
	group.name = "Movement"
	group.group_name = "Movement"
	group.runs_in = "Playing"
	group.events.append(_row("OnProcess", [], [_action("velocity.x = 100.0")]))
	sheet.events.append(group)
	sheet.events.append(_row("OnReady", [], [_go_to_mode("PLAYING")]))
	var built: String = str(SheetCompiler.compile(sheet, OUT_PATH).get("output", ""))
	all_passed = _check("Go to mode is one plain assignment",
		built.contains("\tmode = Mode.PLAYING"), true) and all_passed
	all_passed = _check("and the variable itself is what announces the change",
		built.contains("\t\tmode_changed.emit(was, value)"), true) and all_passed

	var file: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	file.store_string(built)
	file.close()
	var opened: EventSheetResource = GDScriptImporter.new().import_external(OUT_PATH)
	all_passed = _check("the file opens as a sheet", opened != null, true) and all_passed
	if opened == null:
		return all_passed
	all_passed = _check("its modes are read back",
		EventSheetModeFacts.names(opened),
		PackedStringArray(["Playing", "Paused", "Cutscene", "Menu"])) and all_passed
	all_passed = _check("and the group remembers which mode it runs in",
		_runs_in_of(opened.events), "Playing") and all_passed
	var again: String = str(SheetCompiler.compile(opened, OUT_PATH).get("output", ""))
	all_passed = _check("re-emitting reproduces the file byte for byte", again, built) and all_passed
	all_passed = _check("and the Go to mode line came back as the row it is",
		_first_ace_id(opened.events, "GoToMode"), true) and all_passed

	# The other direction: a file NOBODY wrote with this plugin, spelling the same idea the way a
	# person writes it. It opens as the rows, and saving it writes their bytes back.
	var by_hand: String = "\n".join(PackedStringArray([
		"extends Node",
		"",
		"enum Mode { PLAYING, PAUSED }",
		"",
		"signal mode_changed(from_mode: int, to_mode: int)",
		"",
		"var mode: Mode = Mode.PLAYING",
		"var mode_stack: Array[int] = []",
		"",
		"func _process(delta: float) -> void:",
		"\tif mode == Mode.PLAYING:",
		"\t\tprint(delta)",
		"",
	]))
	var hand_file: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	hand_file.store_string(by_hand)
	hand_file.close()
	var hand_sheet: EventSheetResource = GDScriptImporter.new().import_external(OUT_PATH)
	all_passed = _check("a hand-written spine opens with its modes read",
		EventSheetModeFacts.names(hand_sheet), PackedStringArray(["Playing", "Paused"])) and all_passed
	all_passed = _check("and starting where it says",
		EventSheetModeFacts.starts_in(hand_sheet), "Playing") and all_passed
	all_passed = _check("the mode test came back as the In mode row",
		_first_ace_id(hand_sheet.events, "InMode"), true) and all_passed
	all_passed = _check("and saving it writes their own bytes back",
		str(SheetCompiler.compile(hand_sheet, OUT_PATH).get("output", "")), by_hand) and all_passed
	return all_passed


## True when some row of this sheet carries that ace id - the difference between a line that LIFTED
## and one that came back as a block of code with a reading drawn over it.
static func _first_ace_id(items: Array, wanted: String) -> bool:
	for item: Variant in items:
		if item is EventGroup and _first_ace_id(EventSheetGroupFacts.children(item as EventGroup), wanted):
			return true
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		for lane: Array in [event_row.conditions, event_row.actions]:
			for ace: Variant in lane:
				if ace is Resource and str((ace as Resource).get("ace_id")) == wanted:
					return true
		if _first_ace_id(event_row.sub_events, wanted):
			return true
	return false


## The runs_in of the first group in a lifted sheet, "" when there is none.
static func _runs_in_of(items: Array) -> String:
	for item: Variant in items:
		if item is EventGroup:
			return (item as EventGroup).runs_in
	return ""


## A sheet that declares modes the way the Edit modes dialog writes them: the enum, the variable it
## starts in, the signal the change travels on, and the stack Push and Go back use.
static func _modes_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	var declared: EnumRow = EnumRow.new()
	declared.enum_name = EventSheetModeFacts.ENUM_NAME
	declared.members = PackedStringArray(["PLAYING", "PAUSED", "CUTSCENE", "MENU"])
	sheet.events.append(declared)
	var changed: SignalRow = SignalRow.new()
	changed.signal_name = EventSheetModeFacts.CHANGED_SIGNAL
	changed.params = EventSheetModeFacts.CHANGED_SIGNAL_PARAMS
	sheet.events.append(changed)
	var mode_var: LocalVariable = _declared(EventSheetModeFacts.MODE_VARIABLE,
		EventSheetModeFacts.ENUM_NAME, "Mode.MENU")
	mode_var.setter_param = "value"
	mode_var.setter_body = EventSheetModeFacts.SETTER_BODY
	sheet.events.append(mode_var)
	sheet.events.append(_declared(EventSheetModeFacts.STACK_VARIABLE, "Array[int]", "[]"))
	sheet.variables["hud_shown"] = {"type": "bool", "default": true}
	return sheet


## A plain class-level `var` - what the Edit modes dialog writes for the mode and the stack. Not an
## Inspector field: an enum member cannot be spelled as an exported default, and which mode a game
## is in is not a knob a designer turns.
static func _declared(name: String, type_name: String, initial: String) -> LocalVariable:
	var declared: LocalVariable = LocalVariable.new()
	declared.name = name
	declared.type_name = type_name
	declared.default_value = initial
	declared.expression_default = true
	return declared


static func _row(trigger_id: String, conditions: Array, actions: Array,
		trigger_params: Dictionary = {}) -> EventRow:
	var row: EventRow = EventRow.new()
	row.trigger_id = trigger_id
	row.trigger_params = trigger_params
	for condition: Variant in conditions:
		row.conditions.append(condition)
	for action: Variant in actions:
		row.actions.append(action)
	return row


static func _action(template: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "TestAction"
	action.codegen_template = template
	return action


## A real Go to mode row, taken from the shipped descriptor so the test cannot pass against a
## template nobody ships.
static func _go_to_mode(member: String) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "GoToMode"
	action.params = {EventSheetModeFacts.MODE_PARAM: member}
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "GoToMode")
	if descriptor != null:
		action.codegen_template = descriptor.codegen_template
	return action


## The shipped In mode condition, so a row can be gated on a mode the way an author gates one.
static func _in_mode(member: String) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "InMode"
	condition.params = {EventSheetModeFacts.MODE_PARAM: member}
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "InMode")
	if descriptor != null:
		condition.codegen_template = descriptor.codegen_template
	return condition


## And the shipped Go back, which leaves whatever mode it runs in.
static func _go_back_mode() -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "GoBackMode"
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "GoBackMode")
	if descriptor != null:
		action.codegen_template = descriptor.codegen_template
	return action


static func _parses(source: String) -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload() == OK


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] game_state_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
