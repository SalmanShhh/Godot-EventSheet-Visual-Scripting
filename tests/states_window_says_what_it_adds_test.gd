# Godot EventSheets - The States window shows every line it will write before it writes it.
#
# Declaring states on a file that has none writes more than the enum and the state variable: the
# variable's setter, the `state_changed` signal and two helper variables (the state it came from, and
# when the current one began). The code the window shows while you pick must show them too, so a
# hand-written file never gains a line nobody was shown. A file that already has a machine gets only
# its renames, so for it the window shows no extra lines.
@tool
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const P := "states_window_says_what_it_adds_test"
const BARE := "extends Node\n\n\nfunc _process(_delta: float) -> void:\n\tpass\n"
const MACHINE := "extends Node\n\nenum State { IDLE, RUN }\n\nvar state: State = State.IDLE\n\n\nfunc _process(_delta: float) -> void:\n\tif state == State.RUN:\n\t\tprint(\"running\")\n"


static func run() -> bool:
	var bare: EventSheetResource = SUPPORT.reopen(BARE, true, SUPPORT.own_path("states_window_adds_bare.gd"))
	var model: Dictionary = EventSheetStatesDialog.model_of(bare)
	model["states"] = [{"name": "IDLE", "orig": "", "note": ""}, {"name": "RUN", "orig": "", "note": ""}]
	model["default"] = 0
	var shown: String = EventSheetStatesDialog.code_for(model)
	EventSheetStatesDialog.apply_model(bare, model)
	var written: String = SUPPORT.compile_output(bare)
	var ok: bool = SUPPORT.pins(P + ": declaring", [
		["declaring writes the signal", written.contains("signal state_changed"), true],
		["the window shows the signal before it is written", shown.contains("signal state_changed"), true],
		["the window shows the helper that keeps the state it came from", shown.contains("previous_state"), true],
		["the window shows the helper that keeps when the state began", shown.contains("state_entered_msec"), true],
		["the window shows that the state variable gets a setter", shown.contains("set("), true],
	])
	var every_line_written: bool = true
	for line: String in shown.split("\n"):
		var plain: String = line.strip_edges()
		if plain.is_empty() or plain.begins_with("enum ") or plain.begins_with("}") or plain.ends_with(","):
			continue
		if not written.contains(plain):
			every_line_written = false
	ok = SUPPORT.check(P, "every other line the window shows is a line the file gets", every_line_written, true) and ok
	var opened: EventSheetResource = SUPPORT.reopen(MACHINE, true, SUPPORT.own_path("states_window_adds_machine.gd"))
	var renaming: Dictionary = EventSheetStatesDialog.model_of(opened)
	var shown_for_rename: String = EventSheetStatesDialog.code_for(renaming)
	ok = SUPPORT.pins(P + ": renaming", [
		["a file that has states is shown no helper it will not get",
			[shown_for_rename.contains("previous_state"), shown_for_rename.contains("signal state_changed")], [false, false]],
	]) and ok
	return ok
