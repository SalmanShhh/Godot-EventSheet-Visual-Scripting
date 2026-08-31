# EventForge - one object's own states: declared once, read back, and compiled to plain lines.
#
# The whole feature rests on one decision - an object's states are ORDINARY declarations, an enum
# plus a variable, not a new kind of thing - so this pins the consequences of that decision:
#   1. the reader: what a sheet's declarations say its states are, and the silence of a sheet with
#      none,
#   2. the rows: each of the four compiles to the line a person would have written,
#   3. the moment: On leaving fires before On entering, in ONE handler, because the object raises one
#      signal for a change,
#   4. the round trip: a sheet with states compiles, opens and re-emits byte for byte - and a spine
#      somebody wrote by hand opens as the rows,
#   5. the dialog: what Declare states writes, and that writing twice changes nothing,
#   6. the findings: a state no row can reach, and a row naming a state this object never declared,
#   7. the order a change inside a change actually runs in, pinned by RUNNING the emitted machine
#      rather than by reading it - the one promise a static assertion cannot make,
#   8. and the hold clock of the state the object STARTS in, pinned the same way: a value at
#      instantiation is not something a line of emitted text can be asked about.
@tool
class_name ObjectStateTest
extends RefCounted

const OUT_PATH := "user://__eventsheets_states_probe.gd"


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _run_reader() and all_passed
	all_passed = _run_rows() and all_passed
	all_passed = _run_moment() and all_passed
	all_passed = _run_round_trip() and all_passed
	all_passed = _run_dialog() and all_passed
	all_passed = _run_findings() and all_passed
	all_passed = _run_change_inside_a_change() and all_passed
	all_passed = _run_starting_hold() and all_passed
	if all_passed:
		print("[PASS] object_state_test: the reader, the rows, the moment, the round trip, the dialog, the findings, the nested change and the starting hold")
	return all_passed


# ── 1. What a sheet's declarations say its states are ─────────────────────────────────────
static func _run_reader() -> bool:
	var all_passed: bool = true
	var quiet: EventSheetResource = EventSheetResource.new()
	all_passed = _check("a sheet with no enum declares no states",
		EventSheetStateFacts.declares_states(quiet), false) and all_passed
	all_passed = _check("and its band says nothing at all",
		EventSheetStateFacts.band_reading(quiet), "") and all_passed

	var sheet: EventSheetResource = _states_sheet()
	all_passed = _check("the states are the enum's members, as words",
		EventSheetStateFacts.names(sheet),
		PackedStringArray(["Patrol", "Chase", "Stagger"])) and all_passed
	all_passed = _check("the state it starts in is the variable's own value",
		EventSheetStateFacts.starts_in(sheet), "Patrol") and all_passed
	all_passed = _check("the band is one fact: the states, and the one it starts in",
		EventSheetStateFacts.band_reading(sheet),
		"Patrol · Chase · Stagger, starts in Patrol") and all_passed
	all_passed = _check("and it echoes the line the compiler writes",
		EventSheetStateFacts.band_echo(sheet),
		"enum State { PATROL, CHASE, STAGGER }") and all_passed
	all_passed = _check("the bare members are what a row's parameter carries",
		EventSheetStateFacts.bare_members(sheet),
		PackedStringArray(["PATROL", "CHASE", "STAGGER"])) and all_passed

	# One spelling rule for the whole plugin: states say a member the way the game's modes do.
	all_passed = _check("a member reads as a word",
		EventSheetStateFacts.word_for("GAVE_UP"), "Gave Up") and all_passed
	all_passed = _check("and the word writes back as the member",
		EventSheetStateFacts.member_for("Gave Up"), "GAVE_UP") and all_passed
	return all_passed


# ── 2. Each row is the line a person would have written ───────────────────────────────────
static func _run_rows() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = _states_sheet()
	sheet.events.append(_row("OnProcess", [_condition("InState", {"state": "PATROL"})],
		[_action_ace("GoToState", {"state": "CHASE"})]))
	sheet.events.append(_row("OnProcess", [_condition("WasInState", {"state": "STAGGER"})], []))
	sheet.events.append(_row("OnProcess",
		[_condition("InStateForOver", {"state": "STAGGER", "seconds": "0.4"})], []))
	var built: String = str(SheetCompiler.compile(sheet, OUT_PATH).get("output", ""))
	all_passed = _check("Is in is the comparison it stands for",
		built.contains("if state == State.PATROL:"), true) and all_passed
	all_passed = _check("Go to is one plain assignment",
		built.contains("state = State.CHASE"), true) and all_passed
	all_passed = _check("Was in reads the state before this one",
		built.contains("if previous_state == State.STAGGER:"), true) and all_passed
	all_passed = _check("and the timed one reads the clock the setter started",
		built.contains("if state == State.STAGGER and (Time.get_ticks_msec() - state_entered_msec) / 1000.0 > 0.4:"),
		true) and all_passed
	all_passed = _check("the variable itself is what announces the change",
		built.contains("\t\tstate_changed.emit(was, value)"), true) and all_passed
	all_passed = _check("the emitted script parses", _parses(built), true) and all_passed
	return all_passed


# ── 3. Leaving before entering, in one handler ────────────────────────────────────────────
static func _run_moment() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = _states_sheet()
	# Deliberately written the wrong way round: entering first, leaving second. The emitter is what
	# puts them in the order the object runs them.
	sheet.events.append(_row(EventSheetStateFacts.ENTERING_TRIGGER_ID, [],
		[_action("alarm_on = true")], {"state": "CHASE"}))
	sheet.events.append(_row(EventSheetStateFacts.LEAVING_TRIGGER_ID, [],
		[_action("alarm_on = false")], {"state": "CHASE"}))
	var built: String = str(SheetCompiler.compile(sheet, OUT_PATH).get("output", ""))
	all_passed = _check("both rows share one handler",
		built.count("func _on_state_changed("), 1) and all_passed
	all_passed = _check("which takes both halves of the change",
		built.contains("func _on_state_changed(from_state: int, to_state: int) -> void:"),
		true) and all_passed
	all_passed = _check("and is wired to the signal the state variable emits",
		built.contains("state_changed.connect(_on_state_changed)"), true) and all_passed
	var leaving_at: int = built.find("if from_state == State.CHASE:")
	var entering_at: int = built.find("if to_state == State.CHASE:")
	all_passed = _check("leaving is written", leaving_at >= 0, true) and all_passed
	all_passed = _check("entering is written", entering_at >= 0, true) and all_passed
	all_passed = _check("and leaving comes first, whatever order the sheet is in",
		leaving_at < entering_at, true) and all_passed
	all_passed = _check("the emitted script parses", _parses(built), true) and all_passed
	return all_passed


# ── 4. Compiled, opened, re-emitted byte for byte ─────────────────────────────────────────
static func _run_round_trip() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = _states_sheet()
	sheet.events.append(_row("OnProcess", [_condition("InState", {"state": "PATROL"})],
		[_action_ace("GoToState", {"state": "CHASE"})]))
	var built: String = str(SheetCompiler.compile(sheet, OUT_PATH).get("output", ""))
	_write(built)
	var opened: EventSheetResource = GDScriptImporter.new().import_external(OUT_PATH)
	all_passed = _check("the file opens as a sheet", opened != null, true) and all_passed
	if opened == null:
		return all_passed
	all_passed = _check("its states are read back",
		EventSheetStateFacts.names(opened),
		PackedStringArray(["Patrol", "Chase", "Stagger"])) and all_passed
	all_passed = _check("re-emitting reproduces the file byte for byte",
		str(SheetCompiler.compile(opened, OUT_PATH).get("output", "")), built) and all_passed
	all_passed = _check("and the Go to line came back as the row it is",
		_holds_ace(opened.events, "GoToState"), true) and all_passed

	# The other direction: a file NOBODY wrote with this plugin, spelling the same idea the way a
	# person writes it. It opens as the rows, and saving it writes their bytes back.
	var by_hand: String = "\n".join(PackedStringArray([
		"extends CharacterBody2D",
		"",
		"enum State { PATROL, CHASE }",
		"",
		"signal state_changed(from_state: int, to_state: int)",
		"",
		"var state: State = State.PATROL",
		"var previous_state: State = State.PATROL",
		"",
		"func _process(delta: float) -> void:",
		"\tif state == State.PATROL:",
		"\t\tprint(delta)",
		"",
	]))
	_write(by_hand)
	var hand_sheet: EventSheetResource = GDScriptImporter.new().import_external(OUT_PATH)
	all_passed = _check("a hand-written machine opens with its states read",
		EventSheetStateFacts.names(hand_sheet), PackedStringArray(["Patrol", "Chase"])) and all_passed
	all_passed = _check("and starting where it says",
		EventSheetStateFacts.starts_in(hand_sheet), "Patrol") and all_passed
	all_passed = _check("the state test came back as the Is in row",
		_holds_ace(hand_sheet.events, "InState"), true) and all_passed
	all_passed = _check("and saving it writes their own bytes back",
		str(SheetCompiler.compile(hand_sheet, OUT_PATH).get("output", "")), by_hand) and all_passed
	return all_passed


# ── 5. What the Declare states dialog writes ──────────────────────────────────────────────
static func _run_dialog() -> bool:
	var all_passed: bool = true
	all_passed = _check("the states field is not a syntax to learn",
		EventSheetStatesDialog.words_of("Patrol · Chase, Stagger | Dead"),
		PackedStringArray(["Patrol", "Chase", "Stagger", "Dead"])) and all_passed
	all_passed = _check("and it says what it will write",
		EventSheetStatesDialog.in_code(PackedStringArray(["Patrol", "Gave Up"]), "Patrol"),
		"enum State { PATROL, GAVE_UP } · var state: State = State.PATROL") and all_passed
	all_passed = _check("as well as what the head will read as",
		EventSheetStatesDialog.reads_as(PackedStringArray(["Patrol", "Chase"]), "Chase"),
		"Patrol · Chase, starts in Chase") and all_passed

	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	all_passed = _check("the dialog writes the declarations",
		EventSheetStatesDialog.write(sheet, PackedStringArray(["Patrol", "Chase"]), "Chase"),
		true) and all_passed
	all_passed = _check("the sheet now declares states",
		EventSheetStateFacts.names(sheet), PackedStringArray(["Patrol", "Chase"])) and all_passed
	all_passed = _check("starting in the one it was told",
		EventSheetStateFacts.starts_in(sheet), "Chase") and all_passed
	all_passed = _check("with the two the setter keeps true",
		[EventSheetStateFacts.variable_row(sheet, EventSheetStateFacts.PREVIOUS_VARIABLE) != null,
			EventSheetStateFacts.variable_row(sheet, EventSheetStateFacts.SINCE_VARIABLE) != null],
		[true, true]) and all_passed
	all_passed = _check("and the state variable announces itself",
		EventSheetStateFacts.variable_row(sheet, EventSheetStateFacts.STATE_VARIABLE).setter_body,
		EventSheetStateFacts.SETTER_BODY) and all_passed

	# Writing again renames nothing and adds nothing: one declaration is one machine.
	var before: int = sheet.events.size()
	EventSheetStatesDialog.write(sheet, PackedStringArray(["Patrol", "Chase"]), "Chase")
	all_passed = _check("a second write adds no second copy of anything",
		sheet.events.size(), before) and all_passed
	all_passed = _check("and what it wrote compiles",
		_parses(str(SheetCompiler.compile(sheet, OUT_PATH).get("output", ""))), true) and all_passed
	return all_passed


# ── 6. The two things that go wrong with an object's states ───────────────────────────────
static func _run_findings() -> bool:
	var all_passed: bool = true
	# Nothing goes anywhere yet: Patrol is the one it starts in, so the other two are unreachable.
	var sheet: EventSheetResource = _states_sheet()
	all_passed = _check("a state nothing goes to and nothing starts in is unreachable",
		_subjects(EventSheetStateFacts.findings(sheet), EventSheetStateFacts.KIND_STATE_UNREACHABLE),
		PackedStringArray(["Chase", "Stagger"])) and all_passed
	all_passed = _check("said in the words of what is wrong with it",
		_message_for(EventSheetStateFacts.findings(sheet), "Chase"),
		"Chase is declared and no row can reach it: nothing goes to it, and the object does not start in it.") and all_passed

	# A Go to clears it, and asking about a state is not a way into it.
	sheet.events.append(_row("OnProcess", [], [_action_ace("GoToState", {"state": "CHASE"})]))
	sheet.events.append(_row("OnProcess", [_condition("InState", {"state": "STAGGER"})], []))
	all_passed = _check("a row that goes there clears it, and a row that only asks does not",
		_subjects(EventSheetStateFacts.findings(sheet), EventSheetStateFacts.KIND_STATE_UNREACHABLE),
		PackedStringArray(["Stagger"])) and all_passed

	# A state from somebody ELSE's family. The dropdown will not write one, so this is what
	# hand-written code looks like when it is read back.
	var foreign: EventSheetResource = _states_sheet()
	foreign.events.append(_row("OnProcess", [], [_action_ace("GoToState", {"state": "CHASE"})]))
	foreign.events.append(_row("OnProcess", [], [_action_ace("GoToState", {"state": "STAGGER"})]))
	foreign.events.append(_row("OnProcess", [_condition("InState", {"state": "CUTSCENE"})], []))
	var found: Array[Dictionary] = EventSheetStateFacts.findings(foreign)
	all_passed = _check("a row naming a state this object does not declare is called out",
		_kind_for(found, "Cutscene"), EventSheetStateFacts.KIND_STATE_NOT_DECLARED) and all_passed
	all_passed = _check("and the object's own states are not",
		[_kind_for(found, "Patrol"), _kind_for(found, "Chase")], ["", ""]) and all_passed

	# A sheet that declares no states says nothing at all, which is every object that has none.
	all_passed = _check("and an object with no states grows no findings",
		EventSheetStateFacts.findings(EventSheetResource.new()).size(), 0) and all_passed

	# THE TUTORIAL MACHINE. A `match state:` arm keeps its body verbatim, so the transition inside it
	# is never an ACE row - and the reachability walk used to call the state that arm plainly goes to
	# unreachable, on the very shape this whole family exists to welcome.
	var tutorial: EventSheetResource = _states_sheet()
	var arms: MatchRow = MatchRow.new()
	arms.match_expression = EventSheetStateFacts.STATE_VARIABLE
	arms.branches_text = "\n".join(PackedStringArray([
		"State.PATROL:", "\tif _sees_player():", "\t\tstate = State.CHASE",
		"State.CHASE:", "\tif not _sees_player():", "\t\tstate = State.PATROL",
		"State.STAGGER:", "\tvelocity.x = 0.0",
	]))
	var holding: EventRow = _row("OnPhysicsProcess", [], [])
	holding.actions.append(arms)
	tutorial.events.append(holding)
	all_passed = _check("a Go to inside a match arm reaches the state, exactly as a row does",
		EventSheetStateFacts.entered_states(tutorial),
		PackedStringArray(["CHASE", "PATROL"])) and all_passed
	all_passed = _check("so only the arm nothing goes to is called unreachable",
		_subjects(EventSheetStateFacts.findings(tutorial),
			EventSheetStateFacts.KIND_STATE_UNREACHABLE),
		PackedStringArray(["Stagger"])) and all_passed
	# A match on something ELSE is not this object's machine, whatever its arms assign.
	arms.match_expression = "phase"
	all_passed = _check("and a match on another subject reaches nothing here",
		EventSheetStateFacts.entered_states(tutorial), PackedStringArray()) and all_passed

	# A ROW DROPPED AND LEFT ALONE. The state parameter defaults to naming nothing, on purpose, so an
	# untouched row substitutes to `state == State.` - which does not parse. Nothing else can see it:
	# the field allows it, and the walks above drop an empty member by construction.
	var unfilled: EventSheetResource = _states_sheet()
	unfilled.events.append(_row("OnProcess", [], [_action_ace("GoToState", {"state": "PATROL"})]))
	unfilled.events.append(_row("OnProcess", [_condition("InState", {"state": ""})],
		[_action_ace("GoToState", {})]))
	all_passed = _check("a row left with no state at all is counted",
		EventSheetStateFacts.unfilled_rows(unfilled), 2) and all_passed
	all_passed = _check("and said as the one state mistake that does not compile",
		_message_for(EventSheetStateFacts.findings(unfilled), EventSheetStateFacts.ENUM_NAME),
		"2 row(s) here name no state at all. An empty state cell compiles to `state == State.`, which is not GDScript, so point each one at one of this object's states.") and all_passed
	all_passed = _check("a sheet whose rows all name a state says nothing about it",
		EventSheetStateFacts.unfilled_rows(sheet), 0) and all_passed
	return all_passed


# ── 7. A change started from inside a change, RUN rather than read ────────────────────────
## The setter announces as it assigns, so a Go to written under On entering is a second change that
## happens immediately: its own rows run to the end, and only then do the first change's remaining
## rows resume - by which time the object is somewhere else. That is what the same lines written by
## hand do, and the descriptions and the guide say so; this pins the order by BUILDING the machine,
## loading it and moving it, because no assertion about emitted text can see a runtime order.
static func _run_change_inside_a_change() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = _states_sheet()
	sheet.host_class = "Node"
	sheet.events.append(_declared("trail", "Array", "[]"))
	sheet.events.append(_row(EventSheetStateFacts.LEAVING_TRIGGER_ID, [],
		[_action("trail.append(\"leaving Patrol\")")], {"state": "PATROL"}))
	sheet.events.append(_row(EventSheetStateFacts.LEAVING_TRIGGER_ID, [],
		[_action("trail.append(\"leaving Chase\")")], {"state": "CHASE"}))
	# The row that chains: it says it entered Chase, goes somewhere else, and then says one more thing.
	sheet.events.append(_row(EventSheetStateFacts.ENTERING_TRIGGER_ID, [],
		[_action("trail.append(\"entering Chase\")"),
			_action_ace("GoToState", {"state": "STAGGER"}),
			_action("trail.append(\"still in the Chase row, now in \" + State.find_key(state))")],
		{"state": "CHASE"}))
	sheet.events.append(_row(EventSheetStateFacts.ENTERING_TRIGGER_ID, [],
		[_action("trail.append(\"entering Stagger\")")], {"state": "STAGGER"}))
	var built: String = str(SheetCompiler.compile(sheet, OUT_PATH).get("output", ""))
	all_passed = _check("the machine compiles", _parses(built), true) and all_passed
	_write(built)
	var script: GDScript = ResourceLoader.load(OUT_PATH, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	var machine: Node = script.new()
	machine._ready()
	machine.state = 1  # State.CHASE
	all_passed = _check("a Go to inside On entering runs its own change to the end first, and the rest of the row afterwards",
		Array(machine.trail), [
			"leaving Patrol",
			"entering Chase",
			"leaving Chase",
			"entering Stagger",
			"still in the Chase row, now in STAGGER",
		]) and all_passed
	machine.free()
	return all_passed


# ── 8. The hold clock starts at the object's birth ────────────────────────────────────────
## The setter restarts the clock on a change, and nothing else writes it - so declared as `0` the
## timed question would be comparing against the whole RUN, and an enemy spawned a minute in and
## standing in the state it starts in would answer "for over 2s" on its very first frame. Declared
## with the clock instead, the hold of the starting state begins where the object does. Pinned by
## BUILDING the object, because the defect is a value at instantiation and not a line of text.
static func _run_starting_hold() -> bool:
	var all_passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	EventSheetStatesDialog.write(sheet, PackedStringArray(["Patrol", "Chase"]), "Patrol")
	all_passed = _check("the dialog declares the clock as the clock, not as zero",
		EventSheetStateFacts.variable_row(sheet, EventSheetStateFacts.SINCE_VARIABLE).default_value,
		EventSheetStateFacts.SINCE_INITIAL) and all_passed
	var built: String = str(SheetCompiler.compile(sheet, OUT_PATH).get("output", ""))
	all_passed = _check("and the file says so",
		built.contains("var state_entered_msec: int = Time.get_ticks_msec()"), true) and all_passed
	_write(built)
	var script: GDScript = ResourceLoader.load(OUT_PATH, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	var spawned: Node = script.new()
	# The very question the timed row compiles to, asked of an object one instant old. The whole run
	# is older than this object, which is the case the `0` initialiser answered wrongly.
	var held: float = float(Time.get_ticks_msec() - spawned.state_entered_msec) / 1000.0
	all_passed = _check("an object one instant old has held its starting state for no time at all",
		held < 1.0, true) and all_passed
	spawned.free()
	return all_passed


# ── The sheet these are asked of, and the small helpers ───────────────────────────────────
## A sheet that declares states the way the Declare states dialog writes them: the enum, the signal
## the change travels on, the variable it starts in with its announcing setter, and the two the
## setter keeps true.
static func _states_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	var declared: EnumRow = EnumRow.new()
	declared.enum_name = EventSheetStateFacts.ENUM_NAME
	declared.members = PackedStringArray(["PATROL", "CHASE", "STAGGER"])
	sheet.events.append(declared)
	var changed: SignalRow = SignalRow.new()
	changed.signal_name = EventSheetStateFacts.CHANGED_SIGNAL
	changed.params = EventSheetStateFacts.CHANGED_SIGNAL_PARAMS
	sheet.events.append(changed)
	var state_var: LocalVariable = _declared(EventSheetStateFacts.STATE_VARIABLE,
		EventSheetStateFacts.ENUM_NAME, "State.PATROL")
	state_var.setter_param = "value"
	state_var.setter_body = EventSheetStateFacts.SETTER_BODY
	sheet.events.append(state_var)
	sheet.events.append(_declared(EventSheetStateFacts.PREVIOUS_VARIABLE,
		EventSheetStateFacts.ENUM_NAME, "State.PATROL"))
	sheet.events.append(_declared(EventSheetStateFacts.SINCE_VARIABLE, "int",
		EventSheetStateFacts.SINCE_INITIAL))
	sheet.variables["alarm_on"] = {"type": "bool", "default": false}
	return sheet


## A plain class-level `var` - what the Declare states dialog writes. Not an Inspector field: which
## state an object is in is not a knob a designer turns, and an enum member cannot be spelled as an
## exported default anyway.
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


## A real row, taken from the SHIPPED descriptor so the test cannot pass against a template nobody
## ships.
static func _action_ace(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor != null:
		action.codegen_template = descriptor.codegen_template
	return action


static func _condition(ace_id: String, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor != null:
		condition.codegen_template = descriptor.codegen_template
	return condition


## True when some row of this sheet carries that ace id - the difference between a line that LIFTED
## and one that came back as a block of code with a reading drawn over it.
static func _holds_ace(items: Array, wanted: String) -> bool:
	for item: Variant in items:
		if item is EventGroup and _holds_ace(EventSheetGroupFacts.children(item as EventGroup), wanted):
			return true
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		for lane: Array in [event_row.conditions, event_row.actions]:
			for ace: Variant in lane:
				if ace is Resource and str((ace as Resource).get("ace_id")) == wanted:
					return true
		if _holds_ace(event_row.sub_events, wanted):
			return true
	return false


static func _subjects(found: Array[Dictionary], kind: String) -> PackedStringArray:
	var subjects: PackedStringArray = PackedStringArray()
	for finding: Dictionary in found:
		if str(finding.get("kind", "")) == kind:
			subjects.append(str(finding.get("subject", "")))
	return subjects


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


static func _write(source: String) -> void:
	var file: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	file.store_string(source)
	file.close()


static func _parses(source: String) -> bool:
	var script: GDScript = GDScript.new()
	script.source_code = source
	return script.reload() == OK


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] object_state_test: %s - expected %s, got %s" % [label, str(expected), str(actual)])
	return false
