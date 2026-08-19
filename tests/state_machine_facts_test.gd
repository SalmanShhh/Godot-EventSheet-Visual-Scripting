# Godot EventSheets - S1: an enum plus a variable of it IS a state machine, and reads as the FSM
# behavior - one line in the head, Go to state, Current state is, Previous state is, the in-list
# forms and the CurrentState expression. Pins the facts and every sentence by VALUE.
@tool
class_name StateMachineFactsTest
extends RefCounted

const SOURCE: PackedStringArray = [
	"@export var jump_force := 600.0",
	"enum State { IDLE, RUN, JUMP, WALL_SLIDE }",
	"var state: State = State.IDLE",
	"var previous_state: State",
	"",
	"func change_state(to: State):",
	"\tif state == State.RUN and to == State.JUMP:",
	"\t\tdust.restart()",
	"\t_exit_state(state)",
	"\tprevious_state = state",
	"\tstate = to",
	"\t_enter_state(state)",
	"",
	"func _on_landed():",
	"\tif previous_state == State.WALL_SLIDE:",
	"\t\t_slide()",
	"\tdebug_label.text = State.keys()[state]"
]


static func run() -> bool:
	var all_passed: bool = true
	var machine: Dictionary = EventSheetStateMachineFacts.facts(SOURCE)
	all_passed = _check("the enum is the states list", str(machine.get("enum_name", "")), "State") and all_passed
	all_passed = _check("the initialised variable is the current state", str(machine.get("variable", "")), "state") and all_passed
	all_passed = _check("the empty one remembers the state before", str(machine.get("previous", "")), "previous_state") and all_passed
	all_passed = _check("the states are the enum's members in order", machine.get("states", PackedStringArray()),
		PackedStringArray(["IDLE", "RUN", "JUMP", "WALL_SLIDE"])) and all_passed
	all_passed = _check("the starting state is the one it is declared on", str(machine.get("initial", "")), "IDLE") and all_passed
	all_passed = _check("the transition is the function that assigns from a parameter",
		str(machine.get("transition", "")), "change_state") and all_passed
	all_passed = _check("the call before the assignment is exit", str(machine.get("exit", "")), "_exit_state") and all_passed
	all_passed = _check("the call after it is enter", str(machine.get("enter", "")), "_enter_state") and all_passed
	all_passed = _check("a state reads as the word a reader would say",
		EventSheetStateMachineFacts.state_display("WALL_SLIDE"), "Wall Slide") and all_passed
	all_passed = _check("the head shows one line for the whole machine",
		EventSheetStateMachineFacts.head_line(machine), "FSM · Idle") and all_passed
	all_passed = _check("an enum with no variable of its type is not a machine",
		EventSheetStateMachineFacts.facts(PackedStringArray(["enum Suit { CLUBS, HEARTS }"])), {}) and all_passed
	all_passed = _check("a variable nothing starts is not a machine",
		EventSheetStateMachineFacts.facts(PackedStringArray(["enum State { IDLE }", "var state: State"])), {}) and all_passed

	var context: Dictionary = {"state_machine": machine, "script_object": "Player"}
	all_passed = _check("the transition call reads as the behavior's one action",
		_words(EventSheetSentence.statement("change_state(State.JUMP)", context)),
		"FSM  Go to state \"Jump\"") and all_passed
	all_passed = _check("assigning the variable reads the same",
		_words(EventSheetSentence.statement("state = State.WALL_SLIDE", context)),
		"FSM  Go to state \"Wall Slide\"") and all_passed
	all_passed = _check("a value that is not one of the states keeps its own reading",
		_words(EventSheetSentence.statement("change_state(other)", context)).contains("Go to state"), false) and all_passed
	all_passed = _check("which state it is in is the behavior's question",
		_words(EventSheetSentence.condition("state == State.JUMP", context)),
		"FSM  Current state is \"Jump\"") and all_passed
	all_passed = _check("the state before it is the other one",
		_words(EventSheetSentence.condition("previous_state == State.RUN", context)),
		"FSM  Previous state is \"Run\"") and all_passed
	all_passed = _check("a list of states reads as the in-list form",
		_words(EventSheetSentence.condition("state in [State.IDLE, State.RUN]", context)),
		"FSM  Current state in list \"Idle\", \"Run\"") and all_passed
	all_passed = _check("a list holding something that is not a state is not claimed",
		_words(EventSheetSentence.condition("state in [State.IDLE, other]", context)).contains("in list"), false) and all_passed
	all_passed = _check("the state as a word is the behavior's expression",
		EventSheetSentence.expression_text("State.keys()[state]", context), "Player.FSM.CurrentState") and all_passed
	all_passed = _check("and the previous one likewise",
		EventSheetSentence.expression_text("State.keys()[previous_state]", context), "Player.FSM.PreviousState") and all_passed
	all_passed = _check("the row's object is the script's own object",
		str(EventSheetSentence.condition("state == State.JUMP", context).get("object", "")), "Player") and all_passed

	var facts: Dictionary = EventSheetPatternReadings.facts(SOURCE)
	var claim: Dictionary = EventSheetPatternReadings.state_machine_claim(
		PackedStringArray(["change_state(State.JUMP)"]), facts)
	all_passed = _check("an event that turns the machine claims the pattern",
		str(claim.get("pattern", "")), "state_machine") and all_passed
	all_passed = _check("and offers the shipped behavior for it",
		str(claim.get("adoptable", "")), "StateMachineBehavior") and all_passed
	all_passed = _check("the evidence is the declarations the one line stands for",
		claim.get("evidence", PackedStringArray()), PackedStringArray([
			"enum State { IDLE, RUN, JUMP, WALL_SLIDE }", "var state: State = State.IDLE",
			"var previous_state: State", "func change_state(to: State):"
		])) and all_passed
	all_passed = _check("an event that never touches the machine claims nothing",
		EventSheetPatternReadings.state_machine_claim(PackedStringArray(["hp -= 1"]), facts), {}) and all_passed
	return all_passed


## The words a reading shows, joined - what a reader sees in the cell, with the tones set aside.
static func _words(reading: Dictionary) -> String:
	var out: String = ""
	for entry: Variant in reading.get("segments", []):
		out += str((entry as Dictionary).get("text", ""))
	return out.strip_edges()


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] state_machine_facts_test: %s" % label)
		return true
	print("[FAIL] state_machine_facts_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
