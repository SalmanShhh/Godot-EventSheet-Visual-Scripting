# EventForge - PLAY MODE MAKES THE SHEET THE DEBUGGER, for an object's own states.
#
# While the game runs with a states sheet open, the head band gains a live half ("current: Chase ·
# 3.2 s") and the timed row shows its progress where it is asked ("3.2 of 6"). This file is the four
# promises that make that safe to leave switched on, each one measured rather than described:
#
#   THE STREAM IS THE ONE THAT ALREADY SHIPPED   the two facts ride the Live Values frame the game
#                                                was already flushing, under names the editor and
#                                                the compiler are pinned to agree on - and the
#                                                seconds are the LEFT-HAND SIDE of the very line the
#                                                Is in X for over Ns row compiles to.
#   ZERO COST WHEN CLOSED                        a sheet with the debug switch off carries no
#                                                instrumentation at all, and a sheet with it on
#                                                opens no new channel.
#   STRICTLY READ-ONLY                           frames arrive, the band reads them, and the
#                                                document does not move a byte.
#   NOTHING IS DRAWN OVER THE GAME               every word of this renders in the sheet, in the
#                                                draw pass the value chips already use.
@tool
class_name StatePlayModeTest
extends RefCounted

## The states the sheet below declares, and the one it opens in.
const DECLARED: PackedStringArray = ["Patrol", "Chase", "Stagger"]
const STARTS_IN: String = "Patrol"

## What the running game adds to its values frame when the object has states. Pinned as BYTES,
## because "the editor reads what the compiler writes" is exactly the pair of halves that drifts.
## Asked BY VALUE rather than by position: an enum member may name its own value, and a key list
## indexed by one would be reading a different member or running off the end.
const STATE_ENTRY: String = "\"state\", State.find_key(state)"
const SECONDS_ENTRY: String = "\"state_seconds\", (Time.get_ticks_msec() - state_entered_msec) / 1000.0"

## The debugger messages a compiled sheet is allowed to send. Frozen: this feature adds none, which
## is the whole of "the session asks the running game" - there is no second protocol.
const SHIPPED_MESSAGES: PackedStringArray = [
	"eventsheets:live_values", "eventsheets:fired_events", "eventsheets:event_times",
	"eventsheets:paused_row", "eventsheets:input", "eventsheets:children_report",
	"eventsheets:runtime_error",
]

## The files this feature is, swept for anything that would put a panel over the running game or a
## window over the sheet. The boundary law, as a property of the source rather than a promise.
const OWN_FILES: PackedStringArray = [
	"res://addons/eventsheet/editor/interaction/state_watch.gd",
	"res://addons/eventsheet/editor/interaction/viewport_live_values_helper.gd",
]

## What none of them may name. A viewport overlay is a layer, a window or a node added to somebody
## else's tree; every one of those spellings is refused here.
const OVERLAY_WORDS: PackedStringArray = [
	"CanvasLayer", "Window.new(", "AcceptDialog", "Popup", "add_child(", "get_tree().root",
]


static func run() -> bool:
	# The watch is a static store belonging to the RUN, so a suite sharing one process starts from
	# nothing and leaves nothing behind.
	EventSheetStateWatch.clear()
	var ok: bool = true
	ok = _test_the_stream_is_the_one_that_shipped() and ok
	ok = _test_zero_cost_when_closed() and ok
	ok = _test_the_band_reading() and ok
	ok = _test_a_frame_without_states_says_nothing() and ok
	ok = _test_the_run_ending_ends_the_reading() and ok
	ok = _test_play_mode_never_edits() and ok
	ok = _test_the_progress_is_read_off_the_row() and ok
	ok = _test_nothing_is_drawn_over_the_game() and ok
	ok = _test_the_band_row_is_found_by_its_own_metadata() and ok
	ok = _test_an_enum_that_names_its_own_values() and ok
	EventSheetStateWatch.clear()
	return ok


# -- An enum member that names its own value ----------------------------------------------------
## `enum State { PATROL, CHASE, STAGGER = 7 }` is ordinary hand-written GDScript, and the whole pitch
## of this family is that an object which wrote its states by hand already has the feature. A frame
## that read the key list BY POSITION answered the wrong member for such an enum, or ran off the end
## of the list four times a second in the player - and a byte pin over the shipped shape could not
## see it, because the bytes were consistent and only the meaning was wrong.
##
## So this RUNS the emitted expression: the compiler's own `__live_frame` line is lifted out of the
## compiled file verbatim and evaluated against an object whose state is 7. Nothing is re-spelled
## here, which is what makes the pin about the compiler rather than about this test.
static func _test_an_enum_that_names_its_own_values() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.emit_live_values = true
	var declared: EnumRow = EnumRow.new()
	declared.enum_name = EventSheetStateFacts.ENUM_NAME
	declared.members = PackedStringArray(["PATROL", "CHASE", "STAGGER = 7"])
	sheet.events.append(declared)
	var state_var: LocalVariable = LocalVariable.new()
	state_var.name = EventSheetStateFacts.STATE_VARIABLE
	state_var.type_name = EventSheetStateFacts.ENUM_NAME
	state_var.default_value = "State.PATROL"
	state_var.expression_default = true
	sheet.events.append(state_var)
	var since: LocalVariable = LocalVariable.new()
	since.name = EventSheetStateFacts.SINCE_VARIABLE
	since.type_name = "int"
	since.default_value = EventSheetStateFacts.SINCE_INITIAL
	since.expression_default = true
	sheet.events.append(since)
	var emitted: String = _emit(sheet)
	var frame_line: String = ""
	for line: String in emitted.split("\n"):
		if line.strip_edges().begins_with("var __live_frame: Array = ["):
			frame_line = line.strip_edges()
			break
	var ok: bool = _check("the compiled object builds a values frame", frame_line.is_empty(), false)
	if frame_line.is_empty():
		return false
	var probe: PackedStringArray = PackedStringArray([
		"extends RefCounted",
		"enum %s { %s }" % [EventSheetStateFacts.ENUM_NAME, ", ".join(declared.members)],
		"var %s: %s = %s.STAGGER" % [EventSheetStateFacts.STATE_VARIABLE,
			EventSheetStateFacts.ENUM_NAME, EventSheetStateFacts.ENUM_NAME],
		"var %s: int = %s" % [EventSheetStateFacts.SINCE_VARIABLE,
			EventSheetStateFacts.SINCE_INITIAL],
		"func frame() -> Array:",
		"\t%s" % frame_line,
		"\treturn __live_frame",
		"",
	])
	var script: GDScript = GDScript.new()
	script.source_code = "\n".join(probe)
	ok = _check("and that frame is a script that runs", script.reload(), OK) and ok
	if script.reload() != OK:
		return false
	var frame: Array = (script.new() as Object).call("frame")
	var at: int = frame.find(EventSheetStateWatch.STATE_KEY)
	ok = _check("a member that names its own value still streams as its own name",
		"" if at < 0 or at + 1 >= frame.size() else str(frame[at + 1]), "STAGGER") and ok
	return ok


# -- The stream ---------------------------------------------------------------------------------
static func _test_the_stream_is_the_one_that_shipped() -> bool:
	var sheet: EventSheetResource = _authored_sheet()
	sheet.emit_live_values = true
	var emitted: String = _emit(sheet)
	var ok: bool = _check("the running game says which state it is in",
		emitted.contains(STATE_ENTRY), true)
	ok = _check("and how long it has been in it", emitted.contains(SECONDS_ENTRY), true) and ok
	# Both entries ride the frame that was being sent anyway: one message, the one that shipped.
	ok = _check("both ride the values frame that already shipped",
		emitted.contains("EngineDebugger.send_message(\"eventsheets:live_values\", __live_frame)"),
		true) and ok
	ok = _check("and the feature opens no channel of its own",
		_message_names(emitted), PackedStringArray(["eventsheets:live_values"])) and ok
	# The editor reads exactly the names the compiler writes. Two halves, one pin.
	ok = _check("the editor reads the state under the name the game sends it",
		emitted.contains("\"%s\", State.find_key" % EventSheetStateWatch.STATE_KEY), true) and ok
	ok = _check("and the seconds under theirs",
		emitted.contains("\"%s\", (Time.get_ticks_msec()" % EventSheetStateWatch.SECONDS_KEY), true) and ok
	# And the seconds are not a number invented for a readout: they are the left-hand side of the
	# line the timed row compiles to, so the progress compares what the row compares.
	var timed_template: String = _template_of("InStateForOver")
	ok = _check("the streamed seconds are the timed row's own left-hand side",
		timed_template.contains("(Time.get_ticks_msec() - state_entered_msec) / 1000.0"), true) and ok
	return ok


# -- Zero cost when closed ----------------------------------------------------------------------
static func _test_zero_cost_when_closed() -> bool:
	var sheet: EventSheetResource = _authored_sheet()
	sheet.emit_live_values = false
	var emitted: String = _emit(sheet)
	var ok: bool = _check("with the switch off the game says nothing at all",
		emitted.contains("EngineDebugger"), false)
	ok = _check("and carries no throttle for saying it",
		emitted.contains("__live_values_timer"), false) and ok
	ok = _check("and no state entry", emitted.contains("state_seconds"), false) and ok
	# The machine itself is untouched by any of this: an object with states compiles to the same
	# lines whether anybody is watching or not.
	ok = _check("the machine is the same machine either way",
		emitted.contains("state_entered_msec = Time.get_ticks_msec()"), true) and ok
	# An object with NO states never streams a state, however loudly it is being watched.
	var stateless: EventSheetResource = EventSheetResource.new()
	stateless.host_class = "Node"
	stateless.emit_live_values = true
	stateless.variables = {"score": {"type": "int", "default": 0}}
	ok = _check("an object with no states streams no state",
		_emit(stateless).contains("\"state\","), false) and ok
	return ok


# -- The words ----------------------------------------------------------------------------------
static func _test_the_band_reading() -> bool:
	var ok: bool = _check("a whole number of seconds keeps no decimal point",
		EventSheetStateWatch.seconds_text(6.0), "6")
	ok = _check("and a part of one keeps exactly one",
		EventSheetStateWatch.seconds_text(3.24), "3.2") and ok
	ok = _check("the enum member is said as the word the whole plugin says it with",
		EventSheetStateWatch.compose_band("CHASE", 3.2), "current: Chase · 3.2 s") and ok
	ok = _check("a two-word state too",
		EventSheetStateWatch.compose_band("GAVE_UP", 0.5), "current: Gave Up · 0.5 s") and ok
	ok = _check("the progress says the two numbers and nothing else",
		EventSheetStateWatch.compose_progress(3.2, 6.0), "3.2 of 6") and ok

	EventSheetStateWatch.clear()
	ok = _check("with nothing running the band has no live half",
		EventSheetStateWatch.band_reading(), "") and ok
	ok = _check("and the timed row has no progress",
		EventSheetStateWatch.progress_reading(6.0), "") and ok
	EventSheetStateWatch.note_frame({"state": "CHASE", "state_seconds": 3.2})
	ok = _check("one running game reads as one reading",
		EventSheetStateWatch.band_reading(), "current: Chase · 3.2 s") and ok
	ok = _check("and the timed row shows the progress it is waiting on",
		EventSheetStateWatch.progress_reading(6.0), "3.2 of 6") and ok
	# Two copies of the game: each says which window it is describing, exactly as the value chips do.
	EventSheetStateWatch.note_frame({"state": "CHASE", "state_seconds": 3.2}, "host")
	EventSheetStateWatch.note_frame({"state": "PATROL", "state_seconds": 0.5}, "client")
	ok = _check("two copies of the game read as two labelled readings",
		EventSheetStateWatch.band_reading(),
		"host · current: Chase · 3.2 s   client · current: Patrol · 0.5 s") and ok
	EventSheetStateWatch.clear()
	return ok


static func _test_a_frame_without_states_says_nothing() -> bool:
	EventSheetStateWatch.clear()
	EventSheetStateWatch.note_frame({"state": "CHASE", "state_seconds": 3.2})
	# The object stopped streaming a state (a different sheet, a sheet with no states). The old
	# reading goes rather than standing over a game that is no longer in it.
	EventSheetStateWatch.note_frame({"score": 10})
	var ok: bool = _check("a frame with no state drops the reading it replaced",
		EventSheetStateWatch.band_reading(), "")
	ok = _check("and there is nothing live to ask about",
		EventSheetStateWatch.is_live(), false) and ok
	EventSheetStateWatch.clear()
	return ok


static func _test_the_run_ending_ends_the_reading() -> bool:
	EventSheetStateWatch.clear()
	EventSheetStateWatch.note_frame({"state": "STAGGER", "state_seconds": 1.5})
	var ok: bool = _check("a running game is live", EventSheetStateWatch.is_live(), true)
	EventSheetStateWatch.clear()
	ok = _check("and a stopped one is not", EventSheetStateWatch.is_live(), false) and ok
	ok = _check("the band goes back to the declaration",
		EventSheetStateWatch.band_reading(), "") and ok
	ok = _check("and the held time is no answer rather than zero",
		EventSheetStateWatch.held_seconds(), -1.0) and ok
	return ok


# -- The document does not move ------------------------------------------------------------------
static func _test_play_mode_never_edits() -> bool:
	EventSheetStateWatch.clear()
	var sheet: EventSheetResource = _authored_sheet()
	sheet.emit_live_values = true
	var before: String = _emit(sheet)
	var rows_before: int = sheet.events.size()
	# A whole run's worth of frames, including the states the sheet declares and one it does not.
	for seconds: float in [0.0, 0.25, 1.5, 3.2]:
		EventSheetStateWatch.note_frame({"state": "CHASE", "state_seconds": seconds})
	EventSheetStateWatch.note_frame({"state": "STAGGER", "state_seconds": 0.25})
	var during: String = _emit(sheet)
	EventSheetStateWatch.clear()
	var after: String = _emit(sheet)
	var ok: bool = _check("the sheet compiles to the same bytes while the game runs", during, before)
	ok = _check("and to the same bytes again once it stops", after, before) and ok
	ok = _check("and no row was added, moved or taken", sheet.events.size(), rows_before) and ok
	return ok


# -- The progress is the row's own number ---------------------------------------------------------
static func _test_the_progress_is_read_off_the_row() -> bool:
	var numeric: ACECondition = _condition("InStateForOver", {"state": "STAGGER", "seconds": "6"})
	var ok: bool = _check("a plain wait travels on the cell as a number",
		ViewportRowBuilder.state_progress_metadata(numeric),
		{ViewportLiveValuesHelper.STATE_PROGRESS_META: 6.0})
	var computed: ACECondition = _condition("InStateForOver",
		{"state": "STAGGER", "seconds": "stagger_time * 2"})
	ok = _check("a computed wait shows no progress rather than an invented one",
		ViewportRowBuilder.state_progress_metadata(computed), {}) and ok
	var untimed: ACECondition = _condition("InState", {"state": "STAGGER"})
	ok = _check("and no other row carries a progress at all",
		ViewportRowBuilder.state_progress_metadata(untimed), {}) and ok
	return ok


# -- The boundary --------------------------------------------------------------------------------
static func _test_nothing_is_drawn_over_the_game() -> bool:
	var ok: bool = true
	for path: String in OWN_FILES:
		var source: String = FileAccess.get_file_as_string(path)
		ok = _check("%s is there to be read" % path.get_file(), source.is_empty(), false) and ok
		var named: PackedStringArray = PackedStringArray()
		for word: String in OVERLAY_WORDS:
			if source.contains(word):
				named.append(word)
		ok = _check("%s draws nothing over anything" % path.get_file(),
			named, PackedStringArray()) and ok
	# And the RUNNING GAME is asked for numbers, never given a panel: the debug compile adds no node
	# and no layer of its own.
	var sheet: EventSheetResource = _authored_sheet()
	sheet.emit_live_values = true
	var emitted: String = _emit(sheet)
	var in_game: PackedStringArray = PackedStringArray()
	for word: String in ["CanvasLayer", "Control.new(", "Label.new("]:
		if emitted.contains(word):
			in_game.append(word)
	ok = _check("and the running game grows no overlay", in_game, PackedStringArray()) and ok
	return ok


static func _test_the_band_row_is_found_by_its_own_metadata() -> bool:
	var band: EventRowData = _row_with_metadata({
		"head_band": EventSheetHeadBands.BAND_STATES, "kind": "head_band_states"})
	var other: EventRowData = _row_with_metadata({
		"head_band": EventSheetHeadBands.BAND_MODES, "kind": "head_band_modes"})
	var ok: bool = _check("the states band knows itself",
		ViewportLiveValuesHelper.is_states_band(band), true)
	ok = _check("and no other band answers for it",
		ViewportLiveValuesHelper.is_states_band(other), false) and ok
	ok = _check("and neither does nothing at all",
		ViewportLiveValuesHelper.is_states_band(null), false) and ok
	return ok


# -- Fixtures ------------------------------------------------------------------------------------
## The same authored machine the canonical-shape test compiles: three states, the rows that move
## between them, and the timed question this feature draws a progress beside.
static func _authored_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "CharacterBody2D"
	EventSheetStatesDialog.write(sheet, DECLARED, STARTS_IN)
	var timed: EventRow = EventRow.new()
	timed.trigger_provider_id = "Core"
	timed.trigger_id = "OnProcess"
	timed.conditions.append(_condition("InStateForOver", {"state": "STAGGER", "seconds": "6"}))
	timed.actions.append(_action("GoToState", {"state": "PATROL"}))
	sheet.events.append(timed)
	var chase: EventRow = EventRow.new()
	chase.trigger_provider_id = "Core"
	chase.trigger_id = "OnProcess"
	chase.conditions.append(_condition("InState", {"state": "PATROL"}))
	chase.actions.append(_action("GoToState", {"state": "CHASE"}))
	sheet.events.append(chase)
	return sheet


static func _condition(ace_id: String, params: Dictionary) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = ace_id
	condition.params = params
	condition.codegen_template = _template_of(ace_id)
	return condition


static func _action(ace_id: String, params: Dictionary) -> ACEAction:
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = ace_id
	action.params = params
	action.codegen_template = _template_of(ace_id)
	return action


## One row's template off the SHIPPED descriptor - the same bake the dock does at apply time, so
## what this test compiles is what an authored sheet compiles.
static func _template_of(ace_id: String) -> String:
	for descriptor: ACEDescriptor in EventForgeObjectStateACEs.get_descriptors():
		if descriptor.ace_id == ace_id:
			return descriptor.codegen_template
	return ""


static func _emit(sheet: EventSheetResource) -> String:
	return str(SheetCompiler.compile(sheet, "user://state_play_mode.gd").get("output", ""))


## Every debugger message name a compiled sheet sends, sorted and de-duplicated. Sorted because a
## directory of names read in emission order is a value that moves when nothing meaningful did.
static func _message_names(emitted: String) -> PackedStringArray:
	var found: Dictionary = {}
	for name: String in SHIPPED_MESSAGES:
		if emitted.contains("send_message(\"%s\"" % name):
			found[name] = true
	var names: PackedStringArray = PackedStringArray()
	for name: Variant in found.keys():
		names.append(str(name))
	names.sort()
	return names


static func _row_with_metadata(metadata: Dictionary) -> EventRowData:
	var span: SemanticSpan = SemanticSpan.new()
	span.text = "states"
	span.metadata = metadata
	var row: EventRowData = EventRowData.new()
	row.spans.append(span)
	return row


static func _check(label: String, got: Variant, expected: Variant) -> bool:
	if _same(got, expected):
		print("[PASS] state_play_mode_test: %s" % label)
		return true
	print("[FAIL] state_play_mode_test: %s\n  expected: %s\n  got:      %s" % [label, expected, got])
	return false


## Compared as text for everything that is not already the same value, so a PackedStringArray and an
## Array of the same words do not fail for being two spellings of one answer.
static func _same(got: Variant, expected: Variant) -> bool:
	if got == expected:
		return true
	return typeof(got) != typeof(expected) and str(got) == str(expected)
