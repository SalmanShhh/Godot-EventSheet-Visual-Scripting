# Godot EventSheets - one OBJECT's own states, read off the sheet that declares them.
#
# An enemy is patrolling, or chasing, or staggered. Every event-sheet user already builds that as a
# variable they compare in conditions and set in actions, and every Godot user writes it as an enum.
# So this is that, and deliberately nothing more: a state is NOT a new kind of row, NOT a group with
# run-only-in-this-state semantics, and NOT a diagram. The head band IS the diagram.
#
# THE SAME MACHINERY AS THE GAME'S MODES, one level down. `mode_facts.gd` reads the GAME's own
# machine - the Mode enum an Autoload declares, the mode variable, the mode_changed signal - and this
# reads an OBJECT's, declaration for declaration:
#
#     the game            this object
#     enum Mode           enum State
#     var mode            var state
#     mode_changed        state_changed
#     In mode X           Is in X
#     Go to mode X        Go to X
#
# Two readers rather than one because the two are asked of different sheets and answer about
# different things (a game has one mode; a level holds fifty objects with a state each), and the
# rules they share - how a member is said as a word, how many names a band shows - are CALLED here
# rather than copied, so a reader can never meet two spellings of one idea.
#
# AND THE STATE MACHINE PACK: `eventsheet_addons/state_machine/` ships the same idea as a behaviour
# node with a String state (Current state is / Go to state / Time in state). It is frozen and keeps
# working exactly as it did. The difference is where the machine lives: the pack puts it in a child
# node with a string that a typo can spell wrong, and this puts it in the object's own script as an
# enum a dropdown fills in. New work belongs here; nothing that uses the pack has to move.
#
# PURE + STATIC: no viewport, no dialog, no display server, so every word is pinned headless.
@tool
class_name EventSheetStateFacts
extends RefCounted

## The names the declarations go by. Frozen, and deliberately the obvious ones: a hand-written object
## spelling them this way is already declaring states, which is the whole point of choosing them.
const ENUM_NAME: String = "State"
const STATE_VARIABLE: String = "state"
const PREVIOUS_VARIABLE: String = "previous_state"
const SINCE_VARIABLE: String = "state_entered_msec"
const CHANGED_SIGNAL: String = "state_changed"

## The signal's parameters, as the compiler writes them. Two, for the same reason the game's mode
## signal carries two: what we just LEFT is half of every question asked at the moment of a change.
const CHANGED_SIGNAL_PARAMS: PackedStringArray = ["from_state: int", "to_state: int"]

## The state variable's SETTER - where "and tell everybody" belongs in Godot, and the reason Go to is
## one plain assignment rather than a line plus a line somebody has to remember. Assigning the same
## state twice announces nothing: a signal that fires when nothing changed is a signal every handler
## has to guard itself against. It also records the two things the other rows read - what we were in
## before, and when this one began - so that Was in and the timed Is in need no bookkeeping row.
const SETTER_BODY: String = "if value == state:\n\treturn\nvar was: int = state\nprevious_state = was\nstate = value\nstate_entered_msec = Time.get_ticks_msec()\nstate_changed.emit(was, value)"


## True when this sheet declares states at all. Everything else here is silent for a sheet that does
## not - an object with no states grows no band, no findings and no vocabulary it did not ask for.
static func declares_states(sheet: EventSheetResource) -> bool:
	return not names(sheet).is_empty()


## The declared states, in the order the enum declares them, as the words a reader says: PATROL ->
## "Patrol". Empty for a sheet with no State enum.
static func names(sheet: EventSheetResource) -> PackedStringArray:
	var said: PackedStringArray = PackedStringArray()
	for member: String in members(sheet):
		said.append(word_for(member))
	return said


## The enum's members exactly as it declares them, explicit values and all ("STAGGER = 3" stays that).
static func members(sheet: EventSheetResource) -> PackedStringArray:
	var row: EnumRow = enum_row(sheet)
	return PackedStringArray() if row == null else row.members


## The bare member names, with any explicit value dropped - what a row's parameter carries and what
## the reachability checks compare.
static func bare_members(sheet: EventSheetResource) -> PackedStringArray:
	var bare: PackedStringArray = PackedStringArray()
	for member: String in members(sheet):
		bare.append(member.split("=")[0].strip_edges())
	return bare


## The State enum row of this sheet, or null. Found by NAME, because the name is the declaration.
static func enum_row(sheet: EventSheetResource) -> EnumRow:
	if sheet == null:
		return null
	for entry: Variant in sheet.events:
		var row: EnumRow = entry as EnumRow
		if row != null and row.enabled and row.enum_name.strip_edges() == ENUM_NAME:
			return row
	return null


## The state this object starts in - the `state` variable's initial value, said as a word. "" when
## the sheet declares states but nothing says which one it opens in.
static func starts_in(sheet: EventSheetResource) -> String:
	var declared: LocalVariable = variable_row(sheet, STATE_VARIABLE)
	if declared == null:
		return ""
	return word_for(str(declared.default_value).strip_edges().trim_prefix("%s." % ENUM_NAME))


## One of the sheet's own declarations by name, or null. These are TREE variables - plain `var` lines
## at class level, not Inspector fields: which state an object is in is not a knob a designer turns,
## and an enum member cannot be spelled as an exported default anyway.
static func variable_row(sheet: EventSheetResource, wanted: String) -> LocalVariable:
	if sheet == null:
		return null
	for entry: Variant in sheet.events:
		var declared: LocalVariable = entry as LocalVariable
		if declared != null and declared.name.strip_edges() == wanted:
			return declared
	return null


## PATROL -> "Patrol", GAVE_UP -> "Gave Up". ONE spelling rule for the whole plugin: the game's modes
## declared it first and states use that same one, so the band, the dropdown and the row can never
## disagree about which word a member is.
static func word_for(member: String) -> String:
	return EventSheetModeFacts.word_for(member)


## And back: "Gave Up" -> GAVE_UP, the identifier a row's parameter carries.
static func member_for(word: String) -> String:
	return EventSheetModeFacts.member_for(word)


## The band's reading: the states this object has and the one it starts in, in one line, because that
## is one fact - what the states of this object ARE. Empty for a sheet that declares none.
##
## The same scale law the modes band obeys, from the same constant: a band is a place to look, not a
## list of everything, so an object with twenty states says the first few and how many more.
static func band_reading(sheet: EventSheetResource) -> String:
	var said: PackedStringArray = names(sheet)
	if said.is_empty():
		return ""
	var opening: String = starts_in(sheet)
	var shown: PackedStringArray = said.slice(0, EventSheetModeFacts.BAND_NAMES_SHOWN)
	var listed: String = " · ".join(shown)
	if said.size() > shown.size():
		listed += " · " + EventSheetL10n.translate("%d more") % (said.size() - shown.size())
	return listed if opening.is_empty() else "%s, starts in %s" % [listed, opening]


## The line of the file that band stands for: the enum, in the emitter's OWN words rather than in a
## second spelling of them, so the band can never echo a line the compiler would not write.
static func band_echo(sheet: EventSheetResource) -> String:
	var row: EnumRow = enum_row(sheet)
	return "" if row == null else SheetCompiler._emit_enum_line(row)


# -- The vocabulary, and what each half of it is for ---------------------------------------------
## The rows that MOVE the object, and the rows that only ask about it. Two lists rather than one
## because reachability is the reason the Doctor reads them: a state nothing goes to is a different
## fact from a state nothing mentions.
const GOING_ACE_IDS: PackedStringArray = ["GoToState"]
const STATE_ACE_IDS: PackedStringArray = ["GoToState", "InState", "InStateForOver", "WasInState"]

## The triggers that answer a change of state, and the parameter every row of this family carries.
const ENTERING_TRIGGER_ID: String = "OnEnteringState"
const LEAVING_TRIGGER_ID: String = "OnLeavingState"
const STATE_PARAM: String = "state"


## Every state a row of this sheet NAMES, in encounter order - what Go to, Is in, Was in, On entering
## and On leaving are pointed at.
static func named_states(sheet: EventSheetResource) -> PackedStringArray:
	var named: PackedStringArray = PackedStringArray()
	if sheet != null:
		_walk(sheet.events, named, STATE_ACE_IDS, true)
	return named


## The states rows can move the object INTO - the ones a Go to names. Nothing else can put an object
## into a state, which is what makes this the reachability answer.
static func entered_states(sheet: EventSheetResource) -> PackedStringArray:
	var entered: PackedStringArray = PackedStringArray()
	if sheet != null:
		_walk(sheet.events, entered, GOING_ACE_IDS, false)
	return entered


static func _walk(items: Array, into: PackedStringArray, only: PackedStringArray,
		with_triggers: bool) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk(EventSheetGroupFacts.children(item as EventGroup), into, only, with_triggers)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		if with_triggers and (event_row.trigger_id == ENTERING_TRIGGER_ID
				or event_row.trigger_id == LEAVING_TRIGGER_ID):
			_note(into, str(event_row.trigger_params.get(STATE_PARAM, "")))
		for is_action: bool in [false, true]:
			for ace: Variant in (event_row.actions if is_action else event_row.conditions):
				if not (ace is Resource) or not only.has(str((ace as Resource).get("ace_id"))):
					continue
				var params: Variant = (ace as Resource).get("params")
				if params is Dictionary:
					_note(into, str((params as Dictionary).get(STATE_PARAM, "")))
		_walk(event_row.sub_events, into, only, with_triggers)


static func _note(into: PackedStringArray, member: String) -> void:
	var bare: String = member.strip_edges()
	if not bare.is_empty() and not into.has(bare):
		into.append(bare)


# -- Reading a hand-written machine in the rows' own words ---------------------------------------
## The prefix a member of this object's enum is written with, spelled out of the enum's own name so
## renaming one could never leave the other behind.
const MEMBER_PREFIX: String = ENUM_NAME + "."


## What one of this family's rows SAYS about a state - "Is in Patrol", "Go to Chase" - taken from
## that row's own display text rather than spelled a second time here. One spelling for the reading
## of an authored row and the reading of the hand-written line that means the same thing, so a
## `match state:` arm and the Is in row above it can never say one idea two ways. "" when the id
## names no row of this vocabulary.
static func row_reading(ace_id: String, member: String) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor == null:
		return ""
	return EventSheetL10n.translate(descriptor.get_display_text().strip_edges()) \
		.replace("{%s}" % STATE_PARAM, word_for(member))


## The Is in reading of a `match state:` ARM - "State.PATROL:" is "Is in Patrol". "" for an arm this
## vocabulary has nothing to say about (the catch-all `_`, a pattern that is not a member of the
## enum), which is the honest answer: such an arm keeps its own pattern text.
static func arm_reading(pattern: String) -> String:
	var text: String = pattern.strip_edges()
	if not text.begins_with(MEMBER_PREFIX):
		return ""
	var member: String = text.substr(MEMBER_PREFIX.length()).strip_edges()
	return "" if member.is_empty() or member.contains(".") else row_reading("InState", member)


## The Go to reading of one line INSIDE such an arm - `state = State.CHASE` is "Go to Chase". The
## same line outside a match is claimed by the lifter and arrives as a real row; inside one it is
## part of the arm's verbatim body, so this is the only place it can be read at all. "" for every
## other line, which then reads however it already read.
static func statement_reading(line: String) -> String:
	var text: String = line.strip_edges()
	var assignment: String = "%s = %s" % [STATE_VARIABLE, MEMBER_PREFIX]
	if not text.begins_with(assignment):
		return ""
	var member: String = text.substr(assignment.length()).strip_edges()
	return "" if member.is_empty() or not member.is_valid_identifier() else row_reading("GoToState", member)


## True when a `match` subject is THIS object's own state variable - the canonical `match state:` a
## hand-written machine opens with, and the only subject these readings are true of.
static func is_state_subject(match_expression: String) -> bool:
	return match_expression.strip_edges() == STATE_VARIABLE


# -- The two things that go wrong with an object's states ----------------------------------------
## The finding ids. Frozen: the Doctor's lines and the tests address one by these.
const KIND_STATE_UNREACHABLE := "a-state-nothing-reaches"
const KIND_STATE_NOT_DECLARED := "a-state-this-object-does-not-declare"


## Both state mistakes, found by reading the sheet that declares them. Neither is an error - the
## object compiles and runs - and both present as "nothing happened", which is the worst kind of bug
## to find by playing.
##
##   nothing reaches it   a state is declared, no Go to names it, and it is not the one the object
##                        starts in. Written, and unreachable.
##   not declared here    a row names a state this object's enum does not have. The dropdown refuses
##                        to write one, so this is what hand-written code (or a state copied from
##                        another object's family) looks like when it is read back.
##
## Empty for a sheet that declares no states, which is every sheet of an object that has none.
static func findings(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if not declares_states(sheet):
		return found
	var declared: PackedStringArray = bare_members(sheet)
	var entered: PackedStringArray = entered_states(sheet)
	var opening: String = member_for(starts_in(sheet))
	for index: int in range(declared.size()):
		var member: String = declared[index]
		var word: String = names(sheet)[index]
		if member == opening or entered.has(member):
			continue
		found.append({
			"kind": KIND_STATE_UNREACHABLE, "severity": "warning", "subject": word,
			"message": EventSheetL10n.translate("%s is declared and no row can reach it: nothing goes to it, and the object does not start in it.") % word,
		})
	for member: String in named_states(sheet):
		if declared.has(member):
			continue
		found.append({
			"kind": KIND_STATE_NOT_DECLARED, "severity": "warning", "subject": word_for(member),
			"message": EventSheetL10n.translate("A row names the state %s and this object does not declare it. Either add it to the states on the head, or point the row at one of this object's own.") % word_for(member),
		})
	return found
