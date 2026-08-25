@tool
class_name EventSheetStateMachineFacts
extends RefCounted

# The hand-rolled state machine, read as the FSM behavior a sheet already has words for.
#
# An enum of names plus a variable of that enum IS a state machine: the enum is the states list, the
# variable is the current state, the function that assigns it is the transition, and the two `match`
# functions it calls around the assignment are enter and exit. Nothing about that is a guess once all
# of it is on the page together, which is why the question is answered ONCE here, over the file's
# lines, and handed to the sentence grammar as an ordinary context key.
#
# Everything here reads text and answers questions. Nothing edits a row, nothing is emitted, and no
# reading may move the byte round-trip: the file is untouched. Every function is static and takes
# lines, so a test can pin the facts without a viewport.


## Everything this file says about its state machine, or {} when it has none:
##
##   enum_name       the enum that lists the states ("State")
##   variable        the variable that holds the current one ("state")
##   previous        the variable that remembers the one before it ("previous_state"), "" when none
##   states          PackedStringArray of the enum's members, in the order they are written
##   initial         the member the variable starts on ("IDLE")
##   transition      the function that assigns the variable from a parameter ("change_state"), "" when none
##   enter           the function called AFTER the assignment ("_enter_state"), "" when none
##   exit            the function called BEFORE it ("_exit_state"), "" when none
##
## Both halves are required: an enum on its own is a list of names, and a variable on its own is a
## variable. Only when a variable is DECLARED of the enum's type is there a machine to read.
static func facts(lines: PackedStringArray) -> Dictionary:
	var enums: Dictionary = _enum_members(lines)
	if enums.is_empty():
		return {}
	var typed: Dictionary = _variables_typed_by(lines, enums)
	for enum_name: String in enums:
		var holders: Array = typed.get(enum_name, [])
		var current: Dictionary = _current_state_variable(holders)
		if current.is_empty():
			continue
		var members: PackedStringArray = enums[enum_name]
		var initial: String = str(current.get("initial", ""))
		if initial.is_empty() and not members.is_empty():
			initial = members[0]
		var found: Dictionary = {
			"enum_name": enum_name,
			"variable": str(current.get("name", "")),
			"previous": _previous_state_variable(holders, str(current.get("name", ""))),
			"states": members,
			"initial": initial,
			"transition": "", "enter": "", "exit": ""
		}
		found.merge(_transition_functions(lines, str(current.get("name", ""))), true)
		return found
	return {}


## The enums a file declares at top level, as {name: members}. Only the one-line spelling is read -
## a multi-line enum body is a shape the reading would have to reassemble, and a machine that reads
## half its states would be worse than one that reads none.
static func _enum_members(lines: PackedStringArray) -> Dictionary:
	var found: Dictionary = {}
	for line: String in lines:
		if line.begins_with("\t") or line.begins_with(" "):
			continue
		var text: String = line.strip_edges()
		if not text.begins_with("enum "):
			continue
		var open_at: int = text.find("{")
		var close_at: int = text.rfind("}")
		if open_at < 0 or close_at < open_at:
			continue
		var enum_name: String = text.substr(5, open_at - 5).strip_edges()
		if not EventSheetSentence.is_identifier(enum_name):
			continue
		var members: PackedStringArray = PackedStringArray()
		for piece: String in text.substr(open_at + 1, close_at - open_at - 1).split(","):
			var bare: String = piece.strip_edges().get_slice("=", 0).strip_edges()
			if EventSheetSentence.is_identifier(bare):
				members.append(bare)
		if not members.is_empty():
			found[enum_name] = members
	return found


## The top-level variables DECLARED of each enum's type, as {enum name: Array[{name, initial}]}.
## `initial` is the member the declaration starts the variable on, "" when it names none.
static func _variables_typed_by(lines: PackedStringArray, enums: Dictionary) -> Dictionary:
	var found: Dictionary = {}
	for line: String in lines:
		if line.begins_with("\t") or line.begins_with(" "):
			continue
		var text: String = line.strip_edges()
		if not text.begins_with("var "):
			continue
		var declared: String = text.substr(4).strip_edges()
		var colon_at: int = declared.find(":")
		if colon_at <= 0:
			continue
		var variable_name: String = declared.substr(0, colon_at).strip_edges()
		if not EventSheetSentence.is_identifier(variable_name):
			continue
		var rest: String = declared.substr(colon_at + 1).strip_edges()
		var type_name: String = rest
		var initial: String = ""
		var equals_at: int = EventSheetSentence.top_level_index(rest, " = ")
		if equals_at >= 0:
			type_name = rest.substr(0, equals_at).strip_edges()
			initial = _enum_member_of(rest.substr(equals_at + 3).strip_edges(), type_name, enums)
		if not enums.has(type_name):
			continue
		if not found.has(type_name):
			found[type_name] = []
		(found[type_name] as Array).append({"name": variable_name, "initial": initial})
	return found


## The member `State.IDLE` names, "" for anything that is not a member of that enum. A value the enum
## does not list is not a state, however much it looks like one.
static func _enum_member_of(value: String, enum_name: String, enums: Dictionary) -> String:
	var text: String = value.strip_edges()
	var prefix: String = "%s." % enum_name
	if not text.begins_with(prefix):
		return ""
	var member: String = text.substr(prefix.length()).strip_edges()
	var members: PackedStringArray = enums.get(enum_name, PackedStringArray())
	return member if Array(members).has(member) else ""


## Which of an enum's variables holds the CURRENT state: the one the declaration starts on a member.
## A file that starts none of them is not read as a machine - which of two untouched variables is the
## current state would be a coin toss, and the head would name the wrong one.
static func _current_state_variable(holders: Array) -> Dictionary:
	for entry: Variant in holders:
		if not str((entry as Dictionary).get("initial", "")).is_empty():
			return entry
	return {}


## The variable that remembers the state BEFORE this one: a second variable of the same enum that the
## declaration leaves empty. "" when the file keeps none, which is the common case.
static func _previous_state_variable(holders: Array, current: String) -> String:
	for entry: Variant in holders:
		var name_text: String = str((entry as Dictionary).get("name", ""))
		if name_text != current and str((entry as Dictionary).get("initial", "")).is_empty():
			return name_text
	return ""


## The three functions a machine turns through, found by what they DO rather than by their names:
## the transition is the function whose body assigns the state variable from one of its parameters,
## and the two calls it makes on the state around that assignment are exit (before) and enter (after).
## A file that spells them differently - `set_state`, `_on_enter` - reads exactly the same.
static func _transition_functions(lines: PackedStringArray, variable: String) -> Dictionary:
	var found: Dictionary = {"transition": "", "enter": "", "exit": ""}
	var function_name: String = ""
	var parameters: PackedStringArray = PackedStringArray()
	var calls_before: PackedStringArray = PackedStringArray()
	var assigned_at: int = -1
	for line: String in lines:
		var text: String = line.strip_edges()
		if not line.begins_with("\t") and not line.begins_with(" "):
			if text.begins_with("func "):
				var declared: Dictionary = _function_parts(text)
				function_name = str(declared.get("name", ""))
				parameters = declared.get("params", PackedStringArray())
				calls_before = PackedStringArray()
				assigned_at = -1
				continue
			function_name = ""
			continue
		if function_name.is_empty():
			continue
		var called: String = _state_call_of(text, variable)
		if not called.is_empty():
			if assigned_at < 0:
				calls_before.append(called)
			elif found["transition"] == function_name and str(found["enter"]).is_empty():
				found["enter"] = called
			continue
		var equals_at: int = EventSheetSentence.top_level_index(text, " = ")
		if equals_at <= 0 or text.substr(0, equals_at).strip_edges() != variable:
			continue
		if not Array(parameters).has(text.substr(equals_at + 3).strip_edges()):
			continue
		found["transition"] = function_name
		assigned_at = 0
		if not calls_before.is_empty():
			found["exit"] = calls_before[calls_before.size() - 1]
	return found


## The function a `_enter_state(state)` line calls on the state variable, "" for any other line. The
## single argument is what makes it a call ABOUT the state rather than a call that happens to run here.
static func _state_call_of(text: String, variable: String) -> String:
	var call: Dictionary = EventSheetSentence.call_parts(text)
	if call.is_empty() or not str(call.get("target", "")).is_empty():
		return ""
	var args: PackedStringArray = call.get("args", PackedStringArray())
	if args.size() != 1 or args[0].strip_edges() != variable:
		return ""
	return str(call.get("method", ""))


## The name and parameter names of a `func name(a, b) -> T:` declaration.
static func _function_parts(text: String) -> Dictionary:
	var body: String = text.substr(5).strip_edges()
	var open_at: int = body.find("(")
	if open_at < 0:
		return {"name": body.trim_suffix(":").strip_edges(), "params": PackedStringArray()}
	var declared_name: String = body.substr(0, open_at).strip_edges()
	var close_at: int = body.rfind(")")
	var params: PackedStringArray = PackedStringArray()
	for piece: String in body.substr(open_at + 1, maxi(close_at - open_at - 1, 0)).split(","):
		var bare: String = piece.strip_edges().get_slice(":", 0).get_slice("=", 0).strip_edges()
		if EventSheetSentence.is_identifier(bare):
			params.append(bare)
	return {"name": declared_name, "params": params}


## A state's name in the sheet's words: `WALL_SLIDE` reads "Wall Slide". The enum's own spelling is
## the code's, and it shows on hover; the row shows the name a reader would say out loud.
static func state_display(member: String) -> String:
	var words: PackedStringArray = PackedStringArray()
	for piece: String in member.strip_edges().split("_"):
		if piece.is_empty():
			continue
		words.append(piece.substr(0, 1).to_upper() + piece.substr(1).to_lower())
	return " ".join(words) if not words.is_empty() else member


## The state a value names, as it reads, or "" when the value is not one of this machine's states.
## `State.JUMP` and a bare `JUMP` both answer, because both are written.
static func state_of(value: String, machine: Dictionary) -> String:
	if machine.is_empty():
		return ""
	var text: String = value.strip_edges()
	var prefix: String = "%s." % str(machine.get("enum_name", ""))
	if text.begins_with(prefix):
		text = text.substr(prefix.length()).strip_edges()
	var states: PackedStringArray = machine.get("states", PackedStringArray())
	return state_display(text) if Array(states).has(text) else ""


## The states a `[State.IDLE, State.RUN]` literal lists, as they read, or empty when the value is not
## a list of this machine's states. One name that is not a state disqualifies the whole list: a
## reading that quietly dropped it would answer a different question than the code asks.
static func states_of_list(value: String, machine: Dictionary) -> PackedStringArray:
	var text: String = value.strip_edges()
	if not text.begins_with("[") or not text.ends_with("]"):
		return PackedStringArray()
	var found: PackedStringArray = PackedStringArray()
	for piece: String in text.substr(1, text.length() - 2).split(","):
		if piece.strip_edges().is_empty():
			continue
		var named: String = state_of(piece, machine)
		if named.is_empty():
			return PackedStringArray()
		found.append(named)
	return found


## The one line the head's Behaviors folder shows for a machine that is written out rather than
## mounted: "FSM · Idle" - the behavior, and the state it starts in.
static func head_line(machine: Dictionary) -> String:
	if machine.is_empty():
		return ""
	return "FSM · %s" % state_display(str(machine.get("initial", "")))


## What that one line STANDS FOR, for the hover: the enum, the variable, the transition function and
## the two match functions this file spells the behavior out with. Named in the order they are read.
static func plumbing_note(machine: Dictionary) -> String:
	if machine.is_empty():
		return ""
	var parts: PackedStringArray = PackedStringArray()
	parts.append("enum %s" % str(machine.get("enum_name", "")))
	parts.append("var %s" % str(machine.get("variable", "")))
	for key: String in ["transition", "enter", "exit"]:
		var named: String = str(machine.get(key, "")).strip_edges()
		if not named.is_empty():
			parts.append("%s()" % named)
	var previous: String = str(machine.get("previous", "")).strip_edges()
	if not previous.is_empty():
		parts.append("var %s" % previous)
	return "%s - %s" % [EventSheetL10n.translate("written into this script"), " · ".join(parts)]


## The lines that ARE the machine, for the pattern registry's evidence: every top-level declaration
## and function header the one FSM line stands for, in file order. The exact source lines, never a
## paraphrase - the chip that shows them is showing the reader why the row says what it says.
static func evidence(lines: PackedStringArray, machine: Dictionary) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if machine.is_empty():
		return found
	var wanted: PackedStringArray = PackedStringArray([
		"enum %s" % str(machine.get("enum_name", "")),
		"var %s:" % str(machine.get("variable", ""))
	])
	var previous: String = str(machine.get("previous", "")).strip_edges()
	if not previous.is_empty():
		wanted.append("var %s:" % previous)
	for key: String in ["transition", "enter", "exit"]:
		var named: String = str(machine.get(key, "")).strip_edges()
		if not named.is_empty():
			wanted.append("func %s(" % named)
	for line: String in lines:
		if line.begins_with("\t") or line.begins_with(" "):
			continue
		var text: String = line.strip_edges()
		for head: String in wanted:
			if text.begins_with(head):
				found.append(text)
				break
	return found
