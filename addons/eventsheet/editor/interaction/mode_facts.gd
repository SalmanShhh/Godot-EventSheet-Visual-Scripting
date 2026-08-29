# Godot EventSheets - the game's own modes, read off the sheet that declares them.
#
# Object states shipped long ago (the State Machine behaviour). The GAME's mode - Playing, Paused,
# Cutscene, Menu - is still everyone's first hand-rolled enum plus a hundred ifs, and the ifs are
# the part that goes wrong: one of them gets forgotten, a group runs during a cutscene, and nothing
# errors.
#
# The whole feature rests on ONE decision, and it is deliberately the boring one: a game's modes are
# not a new kind of thing. They are an enum, a variable, a signal and a stack - four ordinary
# declarations the author could have typed, and which a hand-written project usually HAS typed. So:
#
#   - nothing is stored anywhere but in those four declarations,
#   - the dialog that writes them writes ordinary rows, undoably,
#   - a project that wrote them by hand is already using this feature and does not know it,
#   - and this file is the one reader everything else asks - the band, the dropdowns, the guard, the
#     Doctor, the live view and the vocabulary all agree because they ask here.
#
# PURE + STATIC: no viewport, no dialog, no display server, so every word is pinned headless.
@tool
class_name EventSheetModeFacts
extends RefCounted

## The names the four declarations go by. Frozen: a hand-written project spelling them this way is
## already declaring modes, which is the point of choosing the obvious names.
const ENUM_NAME: String = "Mode"
const MODE_VARIABLE: String = "mode"
const CHANGED_SIGNAL: String = "mode_changed"
const STACK_VARIABLE: String = "mode_stack"

## The signal's parameters, as the compiler writes them. Two, because "what did we leave" is half of
## every question asked at the moment of a change.
const CHANGED_SIGNAL_PARAMS: PackedStringArray = ["from_mode: int", "to_mode: int"]

## The mode variable's SETTER - where "and tell everybody" belongs in Godot, and the reason going to
## a mode is one plain assignment rather than a line plus a line somebody has to remember. Assigning
## the same mode twice announces nothing: a signal that fires when nothing changed is a signal every
## handler has to guard itself against.
const SETTER_BODY: String = "if value == mode:\n\treturn\nvar was: int = mode\nmode = value\nmode_changed.emit(was, value)"

## The two functions the stack rows CALL, declared beside the four declarations. They exist for the
## same reason the setter does - the row's line should be the line a person would write - and for one
## more: a row named Push Mode whose only call was `push_back` would claim that call in every list a
## reader ever writes, because the vocabulary index reads a leading call as what a row is about.
const PUSH_FUNCTION: String = "push_mode"
const BACK_FUNCTION: String = "go_back"
const PUSH_BODY: String = "mode_stack.push_back(mode)\nmode = next"
const BACK_BODY: String = "if not mode_stack.is_empty():\n\tmode = mode_stack.pop_back()"


## True when this sheet declares modes at all. Everything else here is silent for a sheet that does
## not - a project with no modes grows no bands, no findings and no vocabulary it did not ask for.
static func declares_modes(sheet: EventSheetResource) -> bool:
	return not names(sheet).is_empty()


## The declared modes, in the order the enum declares them, as the words a reader says: PLAYING ->
## "Playing". Empty for a sheet with no Mode enum.
static func names(sheet: EventSheetResource) -> PackedStringArray:
	var said: PackedStringArray = PackedStringArray()
	for member: String in members(sheet):
		said.append(word_for(member))
	return said


## The enum's members exactly as it declares them, explicit values and all ("MENU = 3" stays that).
static func members(sheet: EventSheetResource) -> PackedStringArray:
	var row: EnumRow = enum_row(sheet)
	return PackedStringArray() if row == null else row.members


## The modes THIS PROJECT declares, for a sheet that is not the one declaring them - a Player sheet
## saying "In mode Playing" needs the Game sheet's list. Its own declarations win; failing those, the
## autoloads are read, because global state is what an Autoload is for and it is where the engine's
## own guide says a game's spine belongs.
##
## The autoloads are read as TEXT, one line each: the whole point is a dropdown filling in under a
## reader's hand, and opening every autoload as a sheet to fill a dropdown is a cost that would be
## paid on every dialog.
static func project_members(sheet: EventSheetResource) -> PackedStringArray:
	var mine: PackedStringArray = members(sheet)
	if not mine.is_empty():
		return mine
	for path: String in autoload_scripts():
		var declared: PackedStringArray = members_in_source(FileAccess.get_file_as_string(path))
		if not declared.is_empty():
			return declared
	return PackedStringArray()


## The same list as words, which is what a dropdown of modes offers.
static func project_words(sheet: EventSheetResource) -> PackedStringArray:
	var said: PackedStringArray = PackedStringArray()
	for member: String in project_members(sheet):
		said.append(word_for(member))
	return said


## Every script the project registers as an Autoload, in the order project.godot lists them.
static func autoload_scripts() -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	for property: Dictionary in ProjectSettings.get_property_list():
		var setting: String = str(property.get("name", ""))
		if not setting.begins_with("autoload/"):
			continue
		var value: String = str(ProjectSettings.get_setting(setting, "")).trim_prefix("*")
		var resolved: String = value
		if value.begins_with("uid://"):
			resolved = ResourceUID.get_id_path(ResourceUID.text_to_id(value))
		if resolved.ends_with(".gd") and FileAccess.file_exists(resolved):
			paths.append(resolved)
	return paths


## The members of a `enum Mode { … }` line in a file's text, empty when it declares none. One line,
## one regular expression: the file may be a sheet or may be somebody's own hand-written spine, and
## either way this is the declaration.
static func members_in_source(source: String) -> PackedStringArray:
	var declared: RegEx = RegEx.new()
	declared.compile("enum[ \\t]+%s[ \\t]*\\{([^}]*)\\}" % ENUM_NAME)
	var found: RegExMatch = declared.search(source)
	if found == null:
		return PackedStringArray()
	var members_said: PackedStringArray = PackedStringArray()
	for part: String in found.get_string(1).split(","):
		var member: String = part.strip_edges()
		if not member.is_empty():
			members_said.append(member)
	return members_said


## The Mode enum row of this sheet, or null. Found by NAME, because the name is the declaration.
static func enum_row(sheet: EventSheetResource) -> EnumRow:
	if sheet == null:
		return null
	for entry: Variant in sheet.events:
		var row: EnumRow = entry as EnumRow
		if row != null and row.enabled and row.enum_name.strip_edges() == ENUM_NAME:
			return row
	return null


## The mode this game starts in - the `mode` variable's initial value, said as a word. "" when the
## sheet declares modes but nothing says which one it opens on.
static func starts_in(sheet: EventSheetResource) -> String:
	var declared: LocalVariable = variable_row(sheet, MODE_VARIABLE)
	if declared == null:
		return ""
	return word_for(str(declared.default_value).strip_edges().trim_prefix("%s." % ENUM_NAME))


## True when this sheet keeps a stack of modes - what Push mode and Go back need to exist.
static func has_stack(sheet: EventSheetResource) -> bool:
	return variable_row(sheet, STACK_VARIABLE) != null


## One of the sheet's own declarations by name, or null. These are TREE variables - plain `var`
## lines at class level, not Inspector fields: which mode a game is in is not a knob a designer
## turns, and an enum member cannot be spelled as an exported default anyway.
static func variable_row(sheet: EventSheetResource, wanted: String) -> LocalVariable:
	if sheet == null:
		return null
	for entry: Variant in sheet.events:
		var declared: LocalVariable = entry as LocalVariable
		if declared != null and declared.name.strip_edges() == wanted:
			return declared
	return null


## PLAYING -> "Playing", GAME_OVER -> "Game Over", and an explicit value dropped ("MENU = 3" is the
## Menu mode). One rule, so the band, the dropdown and the row all say the same word.
static func word_for(member: String) -> String:
	var bare: String = member.split("=")[0].strip_edges()
	if bare.is_empty():
		return ""
	var words: PackedStringArray = PackedStringArray()
	for part: String in bare.split("_"):
		if not part.is_empty():
			words.append(part.substr(0, 1).to_upper() + part.substr(1).to_lower())
	return " ".join(words)


## And back: "Game Over" -> GAME_OVER, the identifier a row's parameter carries. Tolerant of being
## handed the identifier already, so a row that stored one is not mangled by a round trip.
static func member_for(word: String) -> String:
	var trimmed: String = word.strip_edges()
	if trimmed.is_empty():
		return ""
	return trimmed.replace(" ", "_").to_upper()


## The band's reading: the modes this sheet declares and the one it starts in, in one line, because
## that is one fact - what the modes of this game ARE. Empty for a sheet that declares none.
static func band_reading(sheet: EventSheetResource) -> String:
	var said: PackedStringArray = names(sheet)
	if said.is_empty():
		return ""
	var opening: String = starts_in(sheet)
	var listed: String = " · ".join(said)
	return listed if opening.is_empty() else "%s - starts in %s" % [listed, opening]


## The line of the file that band stands for: the enum, in the emitter's OWN words rather than in a
## second spelling of them, so the band can never echo a line the compiler would not write.
static func band_echo(sheet: EventSheetResource) -> String:
	var row: EnumRow = enum_row(sheet)
	return "" if row == null else SheetCompiler._emit_enum_line(row)


## Every mode a row of this sheet NAMES, in encounter order - what Go to mode, In mode, Push mode,
## On entering and On leaving are pointed at. The Doctor compares this against the declared list, so
## a mode nothing uses and a row naming a mode nobody declared are the same one walk.
static func named_modes(sheet: EventSheetResource) -> PackedStringArray:
	var named: PackedStringArray = PackedStringArray()
	if sheet != null:
		_walk(sheet.events, named)
	return named


## The modes rows can move the game INTO - the ones a Go to or a Push names. A mode nothing enters
## and nothing leaves is a different problem from a mode nothing can get out of, so they are counted
## apart.
static func entered_modes(sheet: EventSheetResource) -> PackedStringArray:
	var entered: PackedStringArray = PackedStringArray()
	if sheet != null:
		_walk(sheet.events, entered, ENTERING_ACE_IDS)
	return entered


## The vocabulary that MOVES the game, and the vocabulary that only asks about it. Frozen with the
## ace ids themselves: the reachability check is the reason these are two lists and not one.
const ENTERING_ACE_IDS: PackedStringArray = ["GoToMode", "PushMode"]
const MODE_ACE_IDS: PackedStringArray = ["GoToMode", "PushMode", "InMode"]

## The triggers that answer a change of mode, and the trigger parameter every one of them carries.
const ENTERING_TRIGGER_ID: String = "OnEnteringMode"
const LEAVING_TRIGGER_ID: String = "OnLeavingMode"
const MODE_PARAM: String = "mode"


static func _walk(items: Array, into: PackedStringArray, only: PackedStringArray = MODE_ACE_IDS) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk(EventSheetGroupFacts.children(item as EventGroup), into, only)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		var trigger_mode: String = str(event_row.trigger_params.get(MODE_PARAM, "")).strip_edges()
		if not trigger_mode.is_empty() and _trigger_counts(event_row.trigger_id, only):
			_note(into, trigger_mode)
		for is_action: bool in [false, true]:
			for ace: Variant in (event_row.actions if is_action else event_row.conditions):
				if not (ace is Resource) or not only.has(str((ace as Resource).get("ace_id"))):
					continue
				var params: Variant = (ace as Resource).get("params")
				if params is Dictionary:
					_note(into, str((params as Dictionary).get(MODE_PARAM, "")))
		_walk(event_row.sub_events, into, only)


## Whether a trigger counts for this walk. Entering a mode is a way IN and belongs to the
## reachability question; leaving one only ever answers a change somebody else made.
static func _trigger_counts(trigger_id: String, only: PackedStringArray) -> bool:
	if trigger_id == ENTERING_TRIGGER_ID:
		return true
	return trigger_id == LEAVING_TRIGGER_ID and only == MODE_ACE_IDS


static func _note(into: PackedStringArray, member: String) -> void:
	var bare: String = member.strip_edges()
	if not bare.is_empty() and not into.has(bare):
		into.append(bare)


# -- The two things that go wrong with modes -----------------------------------------------------
## The finding ids. Frozen: the Doctor's lines and the tests address one by these.
const KIND_NO_WAY_OUT := "no-way-out-of-a-mode"
const KIND_MODE_UNUSED := "a-mode-nothing-uses"


## Both mode mistakes, found by reading the sheet that declares them. Neither is an error - the game
## compiles and runs - and both are the kind of bug that presents as "nothing happened", which is
## the worst kind to find by playing.
##
##   no way out    rows enter a mode and nothing ever leaves it. The softlock, found at authoring.
##   nothing uses  a mode is declared, and no group runs in it and no row goes to it.
##
## Empty for a sheet that declares no modes, which is every sheet in a project that does not think
## in them.
static func findings(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if not declares_modes(sheet):
		return found
	var entered: PackedStringArray = entered_modes(sheet)
	var used: PackedStringArray = named_modes(sheet)
	for member: String in members(sheet):
		var bare: String = member.split("=")[0].strip_edges()
		var word: String = word_for(member)
		if not used.has(bare):
			found.append({
				"kind": KIND_MODE_UNUSED, "severity": "info", "subject": word,
				"message": EventSheetL10n.translate("%s is declared and nothing uses it: no group runs in it, and no row goes to it.") % word,
			})
			continue
		# A mode rows can get INTO but never out of is the softlock. "Out of" means any row that goes
		# somewhere else, or the Go back that pops whatever was underneath - a mode only ever pushed
		# onto the stack has a way out by construction.
		if entered.has(bare) and not _has_way_out(sheet, bare):
			found.append({
				"kind": KIND_NO_WAY_OUT, "severity": "warning", "subject": word,
				"message": EventSheetL10n.translate("Rows go to %s and none of them ever leaves it. A player who reaches that mode is stuck in it.") % word,
			})
	return found


## The rows that cannot be the way out of a mode reached later in the game, whatever they do: they
## run once, when the game starts or when the object goes. A Go to mode under one of them is how the
## game BEGINS, not how a player leaves the mode they are stuck in.
const ONE_SHOT_TRIGGER_IDS: PackedStringArray = ["OnReady", "OnEnterTree", "OnExitTree"]


## True when a row that can RUN while the game is in this mode moves it somewhere else.
##
## The question is reachability, so it has to be asked of the rows themselves. A row is asked when
## nothing shuts it out of the mode - it is inside a group that runs in this mode, or under an In
## mode / On entering row naming it, or gated on no mode at all, which is a row that runs whatever
## the game is doing. A row gated on a DIFFERENT mode is shut out, which is exactly why "some other
## mode exists in this sheet" was never an answer to this question.
##
## Leaving means Go back (popping whatever was underneath), Push mode (the mode underneath is
## remembered and Go back returns to it), or a Go to naming any mode but this one.
static func _has_way_out(sheet: EventSheetResource, member: String) -> bool:
	return _leaves_mode(sheet.events, member, PackedStringArray())


static func _leaves_mode(items: Array, member: String, gates: PackedStringArray) -> bool:
	for item: Variant in items:
		if item is EventGroup:
			var group: EventGroup = item as EventGroup
			if _leaves_mode(EventSheetGroupFacts.children(group), member,
					_with_gate(gates, member_for(group.runs_in))):
				return true
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		var here: PackedStringArray = _row_gates(event_row, gates)
		if not _shut_out(here, member) and _row_leaves(event_row, member):
			return true
		if _leaves_mode(event_row.sub_events, member, here):
			return true
	return false


## The mode gates in force for this row - the ones inherited from the groups and rows above it, plus
## the ones the row states itself (In mode conditions, and the mode an On entering row answers).
static func _row_gates(event_row: EventRow, gates: PackedStringArray) -> PackedStringArray:
	var here: PackedStringArray = gates.duplicate()
	if event_row.trigger_id == ENTERING_TRIGGER_ID:
		here = _with_gate(here, str(event_row.trigger_params.get(MODE_PARAM, "")).strip_edges())
	for condition: Variant in event_row.conditions:
		if condition is Resource and str((condition as Resource).get("ace_id")) == "InMode":
			var params: Variant = (condition as Resource).get("params")
			if params is Dictionary:
				here = _with_gate(here, str((params as Dictionary).get(MODE_PARAM, "")).strip_edges())
	return here


static func _with_gate(gates: PackedStringArray, gate: String) -> PackedStringArray:
	var bare: String = gate.strip_edges()
	if bare.is_empty() or gates.has(bare):
		return gates
	var grown: PackedStringArray = gates.duplicate()
	grown.append(bare)
	return grown


## True when these gates keep the row from ever running in this mode - any gate naming another one.
static func _shut_out(gates: PackedStringArray, member: String) -> bool:
	for gate: String in gates:
		if gate != member:
			return true
	return false


## True when this row's own actions move the game out of the mode being judged.
static func _row_leaves(event_row: EventRow, member: String) -> bool:
	if ONE_SHOT_TRIGGER_IDS.has(event_row.trigger_id):
		return false
	for action: Variant in event_row.actions:
		if not (action is Resource):
			continue
		var ace_id: String = str((action as Resource).get("ace_id"))
		if ace_id == "GoBackMode" or ace_id == "PushMode":
			return true
		if ace_id != "GoToMode":
			continue
		var params: Variant = (action as Resource).get("params")
		if params is Dictionary and str((params as Dictionary).get(MODE_PARAM, "")).strip_edges() != member:
			return true
	return false
