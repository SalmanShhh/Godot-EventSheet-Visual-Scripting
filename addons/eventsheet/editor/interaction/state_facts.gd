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

## What the clock is DECLARED as, and why it is not `0`. A variable initialiser runs when the object
## is built, so this starts the hold at the object's own birth - which is when the state it starts in
## began. Declared as `0` instead, the timed question would compare against the whole run: an enemy
## spawned a minute in and standing in Patrol would answer "Is in Patrol for over 2s" true on its
## very first frame, and the band would say it had held that state for a minute.
const SINCE_INITIAL: String = "Time.get_ticks_msec()"

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
		# A `match state:` row, wherever it sits. Its arms hold verbatim lines rather than ACE rows,
		# and a Go to written in one of them reaches a state exactly as a row does. The arm PATTERNS
		# are deliberately NOT read here: a pattern asks, and asking has never been a way in.
		if item is MatchRow and only.has(GOING_ACE_IDS[0]):
			for member: String in gone_to_in_match(item as MatchRow):
				_note(into, member)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		if with_triggers and (event_row.trigger_id == ENTERING_TRIGGER_ID
				or event_row.trigger_id == LEAVING_TRIGGER_ID):
			_note(into, str(event_row.trigger_params.get(STATE_PARAM, "")))
		for is_action: bool in [false, true]:
			for ace: Variant in (event_row.actions if is_action else event_row.conditions):
				if ace is MatchRow and only.has(GOING_ACE_IDS[0]):
					for member: String in gone_to_in_match(ace as MatchRow):
						_note(into, member)
					continue
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


# -- What the trail needs to know about this sheet -----------------------------------------------
## The id of the timed question, named here because the trail is the one reader that needs it apart
## from the other three.
const TIMED_ACE_ID: String = "InStateForOver"
## And its second parameter - how long the row is waiting for.
const SECONDS_PARAM: String = "seconds"


## ONE index over this sheet, for every reader of the state trail: which rows can move the object
## into which state, and which rows are waiting on or answering each state. Built once per sheet and
## handed to the trail, because the trail may not reach a sheet at all - it takes plain Dictionaries
## and returns text, which is what makes "the debugger never edits the document" a property of the
## code rather than a promise about it.
##
##     causes     [{uid, to, text}]        every event with a Go to, said as the trigger it hangs off
##     timed      {member: {uid, text}}    the Is in X for over Ns row waiting on that state
##     leaving    {member: {uid, text}}    the On leaving row for that state
##     entering   {member: {uid, text}}    the On entering row for that state
##
## The three lookups keep the FIRST row found for a state, in reading order, so the index is the same
## twice over the same sheet. Empty for a sheet that declares no states.
static func trail_rows(sheet: EventSheetResource) -> Dictionary:
	var index: Dictionary = {"causes": [], "timed": {}, "leaving": {}, "entering": {}}
	if sheet != null and declares_states(sheet):
		_walk_trail(sheet.events, index)
	return index


static func _walk_trail(items: Array, index: Dictionary) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk_trail(EventSheetGroupFacts.children(item as EventGroup), index)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		var trigger_state: String = str(event_row.trigger_params.get(STATE_PARAM, "")).strip_edges()
		if not trigger_state.is_empty():
			if event_row.trigger_id == LEAVING_TRIGGER_ID:
				_file_row(index["leaving"], trigger_state, event_row.event_uid,
					row_reading(LEAVING_TRIGGER_ID, trigger_state))
			elif event_row.trigger_id == ENTERING_TRIGGER_ID:
				_file_row(index["entering"], trigger_state, event_row.event_uid,
					row_reading(ENTERING_TRIGGER_ID, trigger_state))
		for ace: Variant in event_row.conditions:
			var asked: Dictionary = _ace_params(ace, TIMED_ACE_ID)
			var waiting: String = str(asked.get(STATE_PARAM, "")).strip_edges()
			if not waiting.is_empty():
				_file_row(index["timed"], waiting, event_row.event_uid, row_text(TIMED_ACE_ID, {
					STATE_PARAM: waiting, SECONDS_PARAM: str(asked.get(SECONDS_PARAM, "")),
				}))
		for ace: Variant in event_row.actions:
			var going: String = str(_ace_params(ace, GOING_ACE_IDS[0]).get(STATE_PARAM, "")).strip_edges()
			if going.is_empty():
				continue
			(index["causes"] as Array).append({
				"uid": event_row.event_uid,
				"to": going,
				"text": EventSheetArrangement.trigger_words(event_row),
			})
		_walk_trail(event_row.sub_events, index)


## One row's parameters when it IS the asked-for vocabulary, {} otherwise.
static func _ace_params(ace: Variant, wanted_id: String) -> Dictionary:
	if not (ace is Resource) or str((ace as Resource).get("ace_id")) != wanted_id:
		return {}
	var params: Variant = (ace as Resource).get("params")
	return params if params is Dictionary else {}


## First row found for a state wins, so the index reads the same twice over the same sheet.
static func _file_row(into: Dictionary, member: String, uid: String, text: String) -> void:
	if not into.has(member):
		into[member] = {"uid": uid, "text": text}


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
	return row_text(ace_id, {STATE_PARAM: member})


## The same reading with EVERY parameter filled in from the row that carries them - which is what the
## timed question needs, since "Is in Stagger for over 6s" is two answers and not one. The state
## parameter goes through the plugin's one spelling rule and the rest are said as the row says them.
## "" when the id names no row of this vocabulary.
static func row_text(ace_id: String, params: Dictionary) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor == null:
		return ""
	var said: String = EventSheetL10n.translate(descriptor.get_display_text().strip_edges())
	for key: Variant in params:
		var name: String = str(key)
		var value: String = str(params[key]).strip_edges()
		said = said.replace("{%s}" % name, word_for(value) if name == STATE_PARAM else value)
	return said


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
	var member: String = member_gone_to(line)
	return "" if member.is_empty() else row_reading("GoToState", member)


## The member one hand-written line moves this object INTO - `state = State.CHASE` is CHASE, and ""
## for every other line. ONE rule, called by the reading above and by the reachability walk below, so
## the sentence a reader is shown on an arm's line and the fact the Doctor counts off that same line
## can never be two different answers.
static func member_gone_to(line: String) -> String:
	var text: String = line.strip_edges()
	var assignment: String = "%s = %s" % [STATE_VARIABLE, MEMBER_PREFIX]
	if not text.begins_with(assignment):
		return ""
	var member: String = text.substr(assignment.length()).strip_edges()
	return "" if member.is_empty() or not member.is_valid_identifier() else member


## The states a `match state:` row reaches from INSIDE its arms, in encounter order.
##
## A transition written in an arm's body is part of that arm's VERBATIM text - it never becomes an
## ACE row, which is exactly what lets the whole `match` be written back the way it was found - so
## the ace-row walk cannot see it. Without this, the tutorial machine the whole feature exists to
## welcome was told by the Doctor that the state its own patrol arm goes to was unreachable, which is
## the one thing that finding must never say.
##
## Both spellings of a match are read: the verbatim `branches_text` an opened file arrives as, and
## the structured `cases` an author edits it into, whose bodies hold ordinary Go to rows.
static func gone_to_in_match(row: MatchRow) -> PackedStringArray:
	var reached: PackedStringArray = PackedStringArray()
	if row == null or not row.enabled or not is_state_subject(row.match_expression):
		return reached
	for line: String in row.branches_text.split("\n"):
		_note(reached, member_gone_to(line))
	for case_row: MatchCase in row.cases:
		if case_row == null or not case_row.enabled:
			continue
		for item: Variant in case_row.events:
			if item is RawCodeRow:
				for line: String in (item as RawCodeRow).code.split("\n"):
					_note(reached, member_gone_to(line))
			elif item is Resource and str((item as Resource).get("ace_id")) == GOING_ACE_IDS[0]:
				var params: Variant = (item as Resource).get("params")
				if params is Dictionary:
					_note(reached, str((params as Dictionary).get(STATE_PARAM, "")))
	return reached


## True when a `match` subject is THIS object's own state variable - the canonical `match state:` a
## hand-written machine opens with, and the only subject these readings are true of.
static func is_state_subject(match_expression: String) -> bool:
	return match_expression.strip_edges() == STATE_VARIABLE


# -- The three things that go wrong with an object's states --------------------------------------
## The finding ids. Frozen: the Doctor's lines and the tests address one by these.
const KIND_STATE_UNREACHABLE := "a-state-nothing-reaches"
const KIND_STATE_NOT_DECLARED := "a-state-this-object-does-not-declare"
const KIND_STATE_ROW_UNFILLED := "a-state-row-that-names-no-state"


## How many rows of this vocabulary have been dropped and left with their state cell EMPTY. The
## parameter's default names no state on purpose - a row must say which - so an untouched Is in or
## Go to substitutes to `state == State.` / `state = State.`, which is not GDScript and takes the
## whole file down at import. The trigger path is already guarded in the emitter; this is how the
## condition and action path is seen, and it has to be counted rather than named because the thing
## that is wrong with the row is precisely that it names nothing.
static func unfilled_rows(sheet: EventSheetResource) -> int:
	var found: int = 0
	if sheet != null:
		found = _count_unfilled(sheet.events)
	return found


static func _count_unfilled(items: Array) -> int:
	var found: int = 0
	for item: Variant in items:
		if item is EventGroup:
			found += _count_unfilled(EventSheetGroupFacts.children(item as EventGroup))
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null:
			continue
		for is_action: bool in [false, true]:
			for ace: Variant in (event_row.actions if is_action else event_row.conditions):
				if not (ace is Resource) or not STATE_ACE_IDS.has(str((ace as Resource).get("ace_id"))):
					continue
				var params: Variant = (ace as Resource).get("params")
				if not (params is Dictionary) \
						or str((params as Dictionary).get(STATE_PARAM, "")).strip_edges().is_empty():
					found += 1
		found += _count_unfilled(event_row.sub_events)
	return found


## The three state mistakes, found by reading the sheet that declares them. Two of them present as
## "nothing happened", which is the worst kind of bug to find by playing; the third does not compile
## at all, and is here because it is the one shape nothing else in the editor sees.
##
##   nothing reaches it   a state is declared, no Go to names it, and it is not the one the object
##                        starts in. Written, and unreachable.
##   not declared here    a row names a state this object's enum does not have. The field OFFERS the
##                        declared ones and does not forbid the rest - a state may be about to be
##                        declared - so this is the check that catches hand-written code, a state
##                        copied from another object's family, and a name typed a moment too early.
##   names no state       a row of this vocabulary was dropped and its state cell left empty. That
##                        one substitutes to `state == State.`, which does not parse, so unlike the
##                        other two it is not "nothing happened" but "nothing compiles".
##
## ONE WALK PER QUESTION. The enum is read once here and the members carried down rather than
## re-derived per declared state: on a fifteen-hundred-row sheet a twenty-state object used to pay
## twenty full walks of the document for one Doctor pass.
##
## Empty for a sheet that declares no states, which is every sheet of an object that has none.
static func findings(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var row: EnumRow = enum_row(sheet)
	if row == null or row.members.is_empty():
		return found
	var declared: PackedStringArray = PackedStringArray()
	var said: PackedStringArray = PackedStringArray()
	for member: String in row.members:
		declared.append(member.split("=")[0].strip_edges())
		said.append(word_for(member))
	var entered: PackedStringArray = entered_states(sheet)
	var opening: String = member_for(starts_in(sheet))
	for index: int in range(declared.size()):
		if declared[index] == opening or entered.has(declared[index]):
			continue
		found.append({
			"kind": KIND_STATE_UNREACHABLE, "severity": "warning", "subject": said[index],
			"message": EventSheetL10n.translate("%s is declared and no row can reach it: nothing goes to it, and the object does not start in it.") % said[index],
		})
	for member: String in named_states(sheet):
		if declared.has(member):
			continue
		found.append({
			"kind": KIND_STATE_NOT_DECLARED, "severity": "warning", "subject": word_for(member),
			"message": EventSheetL10n.translate("A row names the state %s and this object does not declare it. Either add it to the states on the head, or point the row at one of this object's own.") % word_for(member),
		})
	var unfilled: int = unfilled_rows(sheet)
	if unfilled > 0:
		found.append({
			"kind": KIND_STATE_ROW_UNFILLED, "severity": "warning", "subject": ENUM_NAME,
			"message": EventSheetL10n.translate("%d row(s) here name no state at all. An empty state cell compiles to `state == State.`, which is not GDScript, so point each one at one of this object's states.") % unfilled,
		})
	return found
