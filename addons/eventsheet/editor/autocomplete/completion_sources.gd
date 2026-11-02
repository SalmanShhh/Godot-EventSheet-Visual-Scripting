@tool
class_name EventSheetCompletions
extends RefCounted

const ReadingDoors := preload("res://addons/eventsheet/editor/interaction/reading_doors.gd")
## What only some fields ask, read by path when one does: naming any of these would compile it,
## and what it names, into every first open that loads the completions.
const COMMAND_PALETTE_PATH := "res://addons/eventsheet/editor/dock/command_palette.gd"
const PROJECT_FIND_PATH := "res://addons/eventsheet/editor/dock/project_find.gd"
const LINT_PATH := "res://addons/eventsheet/ace/gdscript_lint.gd"
const TILESET_FACTS_PATH := "res://addons/eventforge/tileset_facts.gd"
const DAMAGE_TYPE_FACTS_PATH := "res://addons/eventforge/damage_type_facts.gd"

# THE list of names a field can be completed with - one source, whatever the field is.
#
# The plugin already knows every name a sheet can say: it compiles them all. What it did not have
# was one place to ASK. An expression box had its own completion, the ▾ combos had their own lists,
# the inline value editor in the sheet had nothing at all, and a field could therefore be blinder
# than the dialog showing the same parameter. This is the one door: give it a sheet, the KIND of
# field, and what the reader has typed so far, and it answers with entries ranked best first.
#
# WHAT A FIELD KIND IS. It is the parameter's own `hint` wherever a parameter has one, so a pack
# that ships `"input_action"` gets completion without knowing this file exists, and one that ships
# a hint nobody has heard of gets nothing rather than a wrong list. A few kinds have no hint behind
# them (a Call row's function name, a type field, a file field) and are named here instead. A kind
# may carry an argument after a colon - `file:PackedScene`, `enum_value:State` - exactly the way
# the parameter hints already do.
#
# THE PERFORMANCE CONTRACT. Building a list is allowed to be slow; typing is not. So each kind's
# list is built ONCE per sheet, held, and only FILTERED per keystroke. Nothing here scans the
# project on a keypress. The caches are dropped when the sheet is edited (the dock) and when the
# filesystem changes (the editor's own ping), which are the only two things that can change an
# answer. Every by-file reader this leans on - the scene readers, the shader reader, the Input Map
# read - already keys on path and mtime, so the second ask is free even the first time round.
#
# WHAT AN ENTRY IS. {"text": what typing it inserts, "detail": the line that explains it,
# "kind": a stable word naming what sort of thing it is}. `kind` is an id, not a display string -
# it never changes spelling and is never translated; `detail` is the sentence a reader reads.


## The field kinds. Each is a parameter hint where one exists, so a pack's own hint IS its source
## name. Frozen once shipped, like an ace_id: a field asking for "expression" must go on getting
## expressions.
const FIELD_EXPRESSION := "expression"
const FIELD_VARIABLE := "variable_reference"
const FIELD_FUNCTION := "function_name"
const FIELD_SIGNAL := "signal_reference"
## A method of the object a row is AIMED at, which is why this kind carries an argument: the target
## expression. `method_reference:$Hurtbox` is a different list from `method_reference:Progress`, and
## the cache keys on the whole kind, so both are held and neither is a guess.
const FIELD_METHOD := "method_reference"
const FIELD_GROUP := "group_reference"
const FIELD_MODE := "mode_reference"
## And ONE OBJECT's own declared states, read off the sheet being edited rather than off the
## project: an enemy's states are the enemy's, and a list mixing two objects' would be a guess.
const FIELD_STATE := "state_reference"
## The States window's own two kinds of field: the name of a state (offered the words rows already use and
## a machine's usual ones) and the sentence for one (offered the sentences the sheet already wrote).
const FIELD_STATE_NAME := "state_name_entry"
const FIELD_STATE_NOTE := "state_note_entry"
const FIELD_INPUT_ACTION := "input_action"
const FIELD_NODE := "scene_node"
const FIELD_SHADER_DIAL := "shader_dial"
## The two lists a TILESET names: the custom data layers its tiles can carry, and the terrains it
## can be painted with. Read off the project's own tileset files, so a Data field offers the words
## this project's tiles were actually authored with rather than a vocabulary of guesses.
const FIELD_TILE_DATA_KEY := "tile_data_key"
const FIELD_TILE_TERRAIN := "tile_terrain"
## The kinds of damage the PROJECT deals, read off its own DamageTypeSet files. A type field offers
## this game's words - fire, bleed, psychic - and a project that has written no set down gets a
## plain field rather than a list of somebody else's elements.
const FIELD_DAMAGE_TYPE := "damage_type"
## An animation of the scene this sheet is attached to, and a named moment inside one. The marker
## kind carries the animation as its argument the way a method carries its target: the markers of
## `swing` are not the markers of `idle`, and a list that mixed them would be a guess.
const FIELD_ANIMATION := "animation_reference"
const FIELD_MARKER := "marker_reference"
## The three with no hint behind them: a class to extend or to type a variable as, one of an enum's
## own values, and a file from the project.
const FIELD_CLASS := "class_name"
const FIELD_ENUM_VALUE := "enum_value"
const FIELD_FILE := "file"
## A PATH, in either of the two places a game has: the project's own files under `res://` and the
## player's folder under `user://`. The `res://` half is the same walk the file kinds above make; the
## `user://` half is what really exists in that folder at edit time, which is the only honest answer
## about a place the game writes to while it runs.
const FIELD_PATH := "file_path"
## The two kinds the Quick Add field ASKS with, rather than completes with. They are field kinds
## because that is where a list that must be built once and only filtered afterwards belongs: the
## cache, its two invalidations and the filtering contract are already here, and the alternative was
## a second index of the sheet that would have gone stale on its own schedule.
##
## `ask_row` is everything one sheet can be FOUND by, read through the project Find's own collection
## so the answers and the Find window can never disagree. `ask_symbol` is everything one sheet
## DECLARES by name - its states, its functions, its signals, its tree variables.
const FIELD_ASK_ROW := "ask_row"
const FIELD_ASK_SYMBOL := "ask_symbol"

## The hints that ARE a file field, and the resource type each one means. A hint that already says
## which type it takes should not have to say it twice at the call site.
const FILE_HINTS: Dictionary = {
	"scene_path": "PackedScene",
	"spawn_scene": "PackedScene",
	"audio_path": "AudioStream",
	"resource_path": "",
}

## The kinds whose answer is about the PROJECT rather than about the sheet asking. Held once for
## every sheet, because ten open tabs asking for the Input Map is one Input Map.
const PROJECT_SCOPED: Array[String] = [FIELD_GROUP, FIELD_INPUT_ACTION, FIELD_NODE, FIELD_CLASS,
	FIELD_FILE, FIELD_PATH, FIELD_TILE_DATA_KEY, FIELD_TILE_TERRAIN, FIELD_DAMAGE_TYPE,
	"scene_path", "spawn_scene",
	"audio_path", "resource_path"]

## The separator between the halves of a detail line. One character, so a detail reads as one line
## rather than as two facts jammed together.
const SEPARATOR := "·"

## The stable `kind` words an entry can carry. Ids, not display strings - a popup may draw an icon
## per kind and a test pins them, so they are spelled once here.
const KIND_VARIABLE := "variable"
const KIND_MEMBER := "member"
const KIND_FUNCTION := "function"
const KIND_SIGNAL := "signal"
const KIND_GROUP := "group"
const KIND_ACTION := "action"
const KIND_NODE := "node"
const KIND_CLASS := "class"
const KIND_FILE := "file"
const KIND_DIAL := "dial"
const KIND_ANIMATION := "animation"
const KIND_MARKER := "marker"
const KIND_ENUM := "enum"
const KIND_BUILTIN := "builtin"
## The kinds reflection adds: a local of the event being edited, and the four things a type has.
const KIND_LOCAL := "local"
const KIND_PROPERTY := "property"
const KIND_METHOD := "method"
const KIND_CONSTANT := "constant"
## What the Quick Add field's answers can BE. Ids like the rest, never display strings: an answer
## says its kind in the reader's own language through the ask, and pins itself in tests through this.
const KIND_ROW := "row"
const KIND_STATE := "state"
const KIND_MODE := "mode"
const KIND_FINDING := "finding"

## The CodeEdit completion icon one kind wears, for the two fields that are real code boxes and
## keep the engine's own popup (the expression box and the Script block). One table, so a name
## completing in a dialog and the same name completing in a code box wear the same badge.
const CODE_EDIT_KINDS: Dictionary = {
	KIND_VARIABLE: CodeEdit.KIND_VARIABLE,
	KIND_MEMBER: CodeEdit.KIND_MEMBER,
	KIND_FUNCTION: CodeEdit.KIND_FUNCTION,
	KIND_BUILTIN: CodeEdit.KIND_FUNCTION,
	KIND_SIGNAL: CodeEdit.KIND_SIGNAL,
	KIND_ENUM: CodeEdit.KIND_CONSTANT,
	KIND_CLASS: CodeEdit.KIND_CLASS,
	KIND_NODE: CodeEdit.KIND_NODE_PATH,
	KIND_FILE: CodeEdit.KIND_FILE_PATH,
	KIND_LOCAL: CodeEdit.KIND_VARIABLE,
	KIND_PROPERTY: CodeEdit.KIND_MEMBER,
	KIND_METHOD: CodeEdit.KIND_FUNCTION,
	KIND_CONSTANT: CodeEdit.KIND_CONSTANT,
}


## The engine's completion icon for one of this seam's kinds, defaulting to plain text for a kind
## the engine has no picture of.
static func code_edit_kind(kind: String) -> int:
	return int(CODE_EDIT_KINDS.get(kind, CodeEdit.KIND_PLAIN_TEXT))


## How many entries a rank hands back. A field with two thousand candidates is still answered in
## one pass, but nobody reads past the first screen and a popup that draws them all stutters.
const RESULT_LIMIT: int = 40

## The shortest query the letters-in-order tier will answer. Two letters are a subsequence of
## almost every long name - `hp` is inside `show_behind_parent` - so a shorter query than this buys
## a screen of noise under the answer the reader actually typed.
const FUZZY_FLOOR: int = 3

## How many built lists are held at once. A key is one sheet and one kind, and the undo funnel
## replaces the sheet resource on every edit, so old keys retire naturally - the cap is what stops
## a long session from holding every one of them.
##
## COUNTED, NOT GUESSED, because the promise this cap has to keep is "a keystroke reads the held
## lists and never goes looking". One ask asks three kinds per open sheet, the comment-door table
## asks five more, and a row dialog asks one per field it draws - so a reader with a dozen tabs open
## is already past two dozen keys, and a cap set there would rebuild a pool on EVERY keystroke, which
## is precisely the regression the ask budget exists to catch. This holds a reader who works with far
## more tabs than anyone does; the lists themselves are small, and a sheet that closes retires its
## own keys the moment the resource behind them is replaced.
const CACHE_LIMIT: int = 120

## How many project files the file source will hold. A file list is the one source that grows with
## the project rather than with the sheet, and a reader picking a texture is not helped by the
## ten-thousandth one.
const FILE_LIMIT: int = 4000
const SCRIPT_MEMBERS_PATH: String = "res://addons/eventsheet/ace/script_members.gd"
const SHADER_UNIFORMS_PATH: String = "res://addons/eventforge/importer/shader_uniforms.gd"

## "<sheet instance>|<kind>" -> the built list, and the order those keys were built in (oldest
## first) so the cap drops the least recently built.
static var _cache: Dictionary = {}
static var _cache_order: Array[String] = []

## Sources a pack registered: field kind -> Callable(sheet, kind) -> Array[Dictionary]. Consulted
## before the built-ins, so a pack may also sharpen a kind the plugin already answers.
static var _extra_sources: Dictionary = {}

## Test seam: the scene root the node and group sources read, when there is no editor to ask.
static var scene_root_override: Node = null


## Everything a field of this kind could hold, ranked against what has been typed so far.
##
## `prefix` is what the reader has typed. For every kind but the expression one that is the word
## itself; for an expression it is the whole text BEFORE THE CARET, because `hp.` and `hp` want
## different answers and only the text before the caret can tell them apart.
##
## `within` is the event the field belongs to, for an expression: its locals (and those of the events
## around it) are names it can say, and no other event's are.
static func for_field(sheet: EventSheetResource, field_kind: String, prefix: String = "", within: Resource = null) -> Array[Dictionary]:
	var kind: String = field_kind.strip_edges()
	if kind.is_empty():
		return []
	if kind == FIELD_EXPRESSION:
		var answer: Dictionary = expression_answer(sheet, prefix, within)
		return rank(answer["entries"], str(answer["needle"]))
	return rank(_pool(sheet, kind), prefix)


## The built list for one kind, UNRANKED - for a reader that has to rank it against lists of other
## kinds and cannot use the per-kind cap to do it. The cache is the point: the list is built once and
## handed back, so joining six kinds on a keystroke costs six lookups rather than six builds.
##
## READ-ONLY. This is the seam's own array rather than a copy of it, because copying every candidate
## on every keypress is precisely the cost this seam exists not to have. Anything that changes what
## it holds changes what every field of that kind offers for the rest of the session.
static func candidates(sheet: EventSheetResource, field_kind: String) -> Array[Dictionary]:
	var kind: String = field_kind.strip_edges()
	return _pool(sheet, kind) if not kind.is_empty() else [] as Array[Dictionary]


## The field kind ONE PARAMETER is: its hint, and - for the parameters that carry none - its id,
## where that id is one of the kinds named here. A Call row's `function_name` is the case this
## exists for: it names a function of this sheet and always did, but no hint ever said so.
static func kind_for_param(hint: String, param_id: String) -> String:
	var declared: String = hint.strip_edges()
	if not declared.is_empty():
		return declared
	return param_id if param_id in [FIELD_FUNCTION, FIELD_CLASS] else ""


## The built list for one kind, from the cache when it is there. The one place a source is built,
## so the cache cannot be walked round by accident.
static func _pool(sheet: EventSheetResource, kind: String) -> Array[Dictionary]:
	var key: String = "%s|%s" % [_scope_of(kind, sheet), kind]
	if _cache.has(key):
		return _cache[key]
	var built: Array[Dictionary] = _build(sheet, kind)
	_cache[key] = built
	_cache_order.append(key)
	while _cache_order.size() > CACHE_LIMIT:
		_cache.erase(_cache_order.pop_front())
	return built


## Which cache a kind's list belongs in: the sheet asking, or the project every sheet shares.
static func _scope_of(kind: String, sheet: EventSheetResource) -> String:
	if PROJECT_SCOPED.has(kind.get_slice(":", 0)):
		return "project"
	return str(sheet.get_instance_id() if sheet != null else 0)


## Builds one kind's list from nothing. A kind nobody answers comes back empty, which is what makes
## an unknown hint a plain field rather than a wrong list.
static func _build(sheet: EventSheetResource, kind: String) -> Array[Dictionary]:
	var head: String = kind.get_slice(":", 0)
	var argument: String = kind.substr(head.length() + 1) if kind.length() > head.length() else ""
	if _extra_sources.has(head):
		return _typed((_extra_sources[head] as Callable).call(sheet, kind))
	if FILE_HINTS.has(head):
		return _file_entries(str(FILE_HINTS[head]))
	match head:
		FIELD_EXPRESSION:
			return _build_expression_entries(sheet)
		FIELD_VARIABLE:
			return _variable_entries(sheet)
		FIELD_FUNCTION:
			return _function_entries(sheet)
		FIELD_SIGNAL:
			return _signal_entries(sheet)
		FIELD_METHOD:
			return _method_entries(sheet, argument)
		FIELD_GROUP:
			return _group_entries()
		FIELD_MODE:
			return _mode_entries(sheet)
		FIELD_STATE:
			return _state_entries(sheet)
		FIELD_STATE_NAME:
			return _state_name_entries(sheet)
		FIELD_STATE_NOTE:
			return _state_note_entries(sheet)
		FIELD_INPUT_ACTION:
			return _input_action_entries()
		FIELD_NODE:
			return _node_entries()
		FIELD_SHADER_DIAL:
			return _dial_entries(sheet)
		FIELD_TILE_DATA_KEY:
			return _tile_data_key_entries()
		FIELD_TILE_TERRAIN:
			return _tile_terrain_entries()
		FIELD_DAMAGE_TYPE:
			return _damage_type_entries()
		FIELD_ANIMATION:
			return _animation_entries(sheet)
		FIELD_MARKER:
			return _marker_entries(sheet, argument)
		FIELD_CLASS:
			return _class_entries()
		FIELD_ENUM_VALUE:
			return _enum_entries(sheet, argument)
		FIELD_FILE:
			return _file_entries(argument)
		FIELD_PATH:
			return _path_entries()
		FIELD_ASK_ROW:
			return _ask_row_entries(sheet)
		FIELD_ASK_SYMBOL:
			return _ask_symbol_entries(sheet)
	return []


# ── The sources ────────────────────────────────────────────────────────────────────────
#
# Each answers one question, and each leans on the reader that already answers it elsewhere: the
# variable catalog the rows and the picker read, the Input Map read the parameter dialog shows, the
# scene readers the head bands use. Nothing here is a second opinion about anything.


## Every variable the sheet can name - its own, the globals it reaches for, the locals in view -
## inserting what the code needs (`Game.Score` keeps its prefix, a local does not) and explained by
## the same sentence its row reads with.
##
## `with_locals` false leaves out the locals: an expression offers only the ones in view of the event
## it is in (see _scope_entries), and every other event's would be a name that cannot be said there.
static func _variable_entries(sheet: EventSheetResource, with_locals: bool = true) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry: Dictionary in EventSheetVariableOwners.catalog(sheet):
		if not with_locals and str(entry.get("group", "")) == EventSheetVariableOwners.GROUP_LOCAL:
			continue
		entries.append({
			"text": str(entry.get("insert_text", entry.get("name", ""))),
			"detail": "%s %s %s" % [str(entry.get("owner", "")), SEPARATOR,
				EventSheetVariableOwners.sentence(entry)],
			"kind": KIND_VARIABLE,
			"type": _type_word_of(str(entry.get("type_name", "")), str(entry.get("value", ""))),
		})
	return entries


## The type a variable reads with in a list: its declared type, else the one its starting value
## gives, else nothing (an honest blank beats "Variant" on a name that never said).
static func _type_word_of(type_name: String, value_text: String) -> String:
	var declared: String = type_name.strip_edges()
	if not declared.is_empty() and declared != "Variant":
		return declared
	var walked: Dictionary = EventSheetExpressionWalk.resolve(value_text, null)
	return str(walked.get("type", "")) if bool(walked.get("known", false)) and not bool(walked.get("static", false)) else ""


## The functions this sheet publishes, each explained by the parameters it takes.
static func _function_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if sheet == null:
		return entries
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function == null or event_function.function_name.strip_edges().is_empty():
			continue
		entries.append({
			"text": event_function.function_name,
			"detail": _function_detail(event_function),
			"kind": KIND_FUNCTION,
			"type": _return_word_of(event_function),
		})
	return entries


## What a sheet function gives back, in Godot's spelling: its named return type, its basic one, or
## void for a function that returns nothing.
static func _return_word_of(event_function: EventFunction) -> String:
	if not event_function.return_type_name.strip_edges().is_empty():
		return event_function.return_type_name.strip_edges()
	return "void" if event_function.return_type == TYPE_NIL else type_string(event_function.return_type)


## What a function's line says: the parameters it takes, or the word for what it is when it takes
## none.
static func _function_detail(event_function: EventFunction) -> String:
	var names: PackedStringArray = PackedStringArray()
	for parameter: Variant in event_function.params:
		var param: ACEParam = parameter as ACEParam
		if param != null and not param.id.strip_edges().is_empty():
			names.append(param.id)
	if names.is_empty():
		# An older sheet (or a lifted one) keeps its parameter names in the plain-string list beside
		# the descriptor one, and a function that reads as taking nothing when it takes two is worse
		# than one with no line at all.
		for legacy_name: String in event_function.parameters:
			names.append(legacy_name)
	var said: String = EventSheetL10n.translate("function")
	if not names.is_empty():
		said += "(%s)" % ", ".join(names)
	return said


## The methods of the object a row is aimed at: what its script declares, with the arguments as
## written and the `##` line above the declaration as the explanation, then what its engine class
## adds. Empty for a target nothing in the project answers to - a row aimed at something worked out
## at run time keeps its typed string, and a guessed list would be worse than none.
static func _method_entries(sheet: EventSheetResource, target: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for member: Dictionary in load(SCRIPT_MEMBERS_PATH).methods_for(sheet, target):
		entries.append({"text": str(member["name"]),
			"detail": load(SCRIPT_MEMBERS_PATH).detail_of(member), "kind": KIND_MEMBER})
	return entries


## The signals in scope: the ones this sheet declares, then the ones its host class already has.
static func _signal_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var seen: Dictionary = {}
	if sheet != null:
		for entry: Variant in sheet.events:
			var row: SignalRow = entry as SignalRow
			if row != null and row.enabled and not row.signal_name.strip_edges().is_empty():
				seen[row.signal_name] = true
				entries.append({"text": row.signal_name, "detail": EventSheetL10n.translate("signal"),
					"kind": KIND_SIGNAL})
	if sheet != null and ClassDB.class_exists(sheet.host_class):
		for info: Dictionary in ClassDB.class_get_signal_list(sheet.host_class):
			var signal_name: String = str(info.get("name", ""))
			if signal_name.is_empty() or seen.has(signal_name):
				continue
			seen[signal_name] = true
			entries.append({"text": signal_name, "detail": sheet.host_class, "kind": KIND_SIGNAL})
	return entries


## Every node group the project declares plus the ones the open scene uses, each with how many
## nodes of that scene are in it.
## The game's declared modes, as the enum members a row stores, with the word each one reads as.
## Read from the sheet that declares them or, for every other sheet, from the project's autoloads -
## the same answer the parameter dialog's dropdown offers, through the one seam.
static func _mode_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for member: String in EventSheetModeFacts.project_members(sheet):
		var word: String = EventSheetModeFacts.word_for(member)
		entries.append({
			"text": EventSheetModeFacts.member_for(word),
			"detail": word,
			"kind": KIND_ENUM,
		})
	return entries


## This object's declared states, as the enum members a row stores, with the word each one reads as.
## Read from the sheet being edited - the same answer the parameter dialog's dropdown offers, through
## the one seam.
static func _state_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for member: String in EventSheetStateFacts.bare_members(sheet):
		# The detail is the state's own sentence (the `##` line above it in the enum), so choosing a
		# state for is / was / go to says what each one is for. The name is already the text.
		entries.append({
			"text": member,
			"detail": EventSheetStateFacts.state_note(sheet, member),
			"kind": KIND_ENUM,
		})
	return entries


## What a state could be called: the states rows name that the enum does not declare yet (a state about to
## be declared), then the names a machine usually has. Declared states are left out - a name already taken
## is not a suggestion.
static func _state_name_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var declared: PackedStringArray = EventSheetStateFacts.bare_members(sheet)
	var seen: Dictionary = {}
	var pool: PackedStringArray = PackedStringArray(EventSheetStateFacts.named_states(sheet))
	pool.append_array(PackedStringArray(["IDLE", "WALK", "RUN", "JUMP", "FALL", "ATTACK", "HURT", "DEAD", "PATROL", "CHASE"]))
	for member: String in pool:
		if declared.has(member) or seen.has(member):
			continue
		seen[member] = true
		entries.append({"text": member, "detail": "", "kind": KIND_ENUM})
	return entries


## The sentences this sheet already wrote about its states and its machine, so a phrase said once is one
## pick the next time.
static func _state_note_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var row: EnumRow = EventSheetStateFacts.enum_row(sheet)
	if row == null:
		return entries
	var pool: PackedStringArray = PackedStringArray()
	pool.append(row.description)
	for member: String in row.members:
		pool.append(row.note_for(member))
	for line: String in pool:
		var text: String = line.strip_edges()
		if not text.is_empty():
			entries.append({"text": text, "detail": "", "kind": KIND_ENUM})
	return entries


## Everything one sheet can be FOUND by, as answers: one entry per findable string, carrying the
## event it lives in so an answer is a door rather than a report. Read through the project Find's own
## collection, which is the point - the field that answers and the window that finds are looking at
## the same sheet through the same eyes.
##
## The pool is built once per sheet and only filtered afterwards, like every other kind here, and the
## undo funnel hands back a new sheet object on every edit, so an edited sheet is re-read rather than
## remembered. Identical strings in the same event are said once: a sheet with forty rows setting
## `"true"` is not forty answers.
static func _ask_row_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var seen: Dictionary = {}
	for found: Dictionary in load(PROJECT_FIND_PATH).findable(sheet):
		var text: String = str(found.get("text", "")).replace("\n", " ").strip_edges()
		if text.is_empty():
			continue
		var uid: String = str(found.get("uid", ""))
		var identity: String = "%s|%s" % [uid, text]
		if seen.has(identity):
			continue
		seen[identity] = true
		entries.append({"text": text, "detail": "", "kind": KIND_ROW, "uid": uid,
			"lower": text.to_lower()})
	return entries


## Everything one sheet DECLARES by name: its states first, because a state is the name a reader
## reaches for while the machine is on their mind, then the functions, signals and tree variables the
## Command Palette's `@` mode already collects - through that same collection, so the two lists of
## what a sheet is called cannot drift apart.
##
## A state's answer is the WORD ("Gave Up"), not the enum member (`GAVE_UP`): the word is what the
## band, the dropdown and the row all say, and it is therefore what a reader types. `symbol` carries
## the member underneath for whoever has to go back to the declaration.
##
## Nothing here holds a Resource. The door is resolved against the LIVE sheet when it is opened - an
## edit replaces every row object in the sheet, and a list holding the old ones would take a reader
## to a row that no longer exists.
static func _ask_symbol_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if sheet == null:
		return entries
	for member: String in EventSheetStateFacts.bare_members(sheet):
		var word: String = EventSheetStateFacts.word_for(member)
		entries.append({"text": word, "detail": "", "kind": KIND_STATE, "symbol": member,
			"lower": word.to_lower()})
	for entry: Variant in load(COMMAND_PALETTE_PATH).collect_symbols(sheet):
		var symbol: Dictionary = entry
		var name: String = str(symbol.get("name", ""))
		entries.append({"text": name, "detail": "", "kind": str(symbol.get("kind", KIND_VARIABLE)),
			"symbol": name, "lower": name.to_lower()})
	return entries


static func _group_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var scene_root: Node = _scene_root()
	for choice: Variant in ReadingDoors.params_dialog().group_choices(scene_root):
		var value: String = str(choice)
		entries.append({
			"text": value,
			"detail": EventSheetParamFieldFactory.node_group_note(value, scene_root),
			"kind": KIND_GROUP,
		})
	return entries


## Every action the project's Input Map declares, with the keys bound to it - the live picker an
## `input_action` field already opens, said through the one seam so the same list rides the popup.
static func _input_action_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for choice: Variant in ReadingDoors.params_dialog().input_action_choices():
		var value: String = str(choice)
		entries.append({
			"text": value,
			"detail": EventSheetParamFieldFactory.input_action_note(value),
			"kind": KIND_ACTION,
		})
	return entries


## The open scene's nodes, by path, and its unique names - the two spellings a row can address a
## node with.
static func _node_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var scene_root: Node = _scene_root()
	if scene_root == null:
		return entries
	for path: String in ReadingDoors.params_dialog().scene_node_paths(scene_root):
		entries.append({"text": "$%s" % path, "detail": EventSheetL10n.translate("node"),
			"kind": KIND_NODE})
	for unique_name: String in ReadingDoors.params_dialog().scene_unique_names(scene_root):
		entries.append({"text": "%%%s" % unique_name,
			"detail": EventSheetL10n.translate("node"), "kind": KIND_NODE})
	return entries


## Every dial the shaders this sheet's own nodes wear declare, named with the shader that declares
## it. A name that is not in this list cannot reach the game: Godot takes a misspelled uniform name
## without a word and then does nothing with it.
static func _dial_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var seen: Dictionary = {}
	for node: Dictionary in EventSheetSceneEffects.for_script(_sheet_script_path(sheet)):
		var shader_path: String = str(node.get("shader_path", ""))
		for dial: Variant in (node.get("dials", []) as Array):
			var dial_name: String = str((dial as Dictionary).get("name", ""))
			if dial_name.is_empty() or seen.has(dial_name):
				continue
			seen[dial_name] = true
			entries.append({
				"text": dial_name,
				"detail": "%s %s %s" % [shader_path.get_file(), SEPARATOR,
					load(SHADER_UNIFORMS_PATH).reading(dial as Dictionary)],
				"kind": KIND_DIAL,
			})
	return entries


## Every animation the scene this sheet is attached to really has, named with how long it runs (or
## that it loops) and which node declares it. Inserted QUOTED, because an animation name is a string
## literal in every row that takes one - completing it into a bare word would write a line naming a
## variable nobody declared.
static func _animation_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for source: Dictionary in EventSheetSceneAnimations.for_script(_sheet_script_path(sheet)):
		for animation: Variant in (source.get("animations", []) as Array):
			var clip: Dictionary = animation
			var clip_name: String = str(clip.get("name", ""))
			if clip_name.is_empty():
				continue
			entries.append({
				"text": "\"%s\"" % clip_name,
				"detail": "%s %s %s" % [EventSheetSceneAnimations.reading(clip), SEPARATOR,
					str(source.get("name", ""))],
				"kind": KIND_ANIMATION,
			})
	return entries


## The named moments inside one animation - what a keyframed clip has instead of frames. The
## argument is the animation the row is about, so a marker list is never a mix of two clips'.
static func _marker_entries(sheet: EventSheetResource, animation_name: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var found: Dictionary = EventSheetSceneAnimations.find(
		EventSheetSceneAnimations.for_script(_sheet_script_path(sheet)), animation_name)
	if found.is_empty():
		return entries
	for marker: Variant in ((found["animation"] as Dictionary).get("markers", []) as Array):
		entries.append({
			"text": "\"%s\"" % str((marker as Dictionary).get("name", "")),
			"detail": EventSheetL10n.translate("%s s into %s") % [
				String.num(float((marker as Dictionary).get("time", 0.0)), 2),
				EventSheetSceneAnimations.unquoted(animation_name)],
			"kind": KIND_MARKER,
		})
	return entries


## The classes a type field can name: the ones this project publishes first (they are the answer a
## reader is usually reaching for), then the engine's own.
static func _class_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var seen: Dictionary = {}
	for entry: Variant in EventSheetProjectScanner.list_project_classes():
		var project_class: String = str((entry as Dictionary).get("name", ""))
		if project_class.is_empty() or seen.has(project_class):
			continue
		seen[project_class] = true
		entries.append({"text": project_class, "detail": str((entry as Dictionary).get("path", "")),
			"kind": KIND_CLASS})
	for engine_class: String in ClassDB.get_class_list():
		if seen.has(engine_class) or not ClassDB.can_instantiate(engine_class):
			continue
		seen[engine_class] = true
		entries.append({"text": engine_class, "detail": ClassDB.get_parent_class(engine_class),
			"kind": KIND_CLASS})
	return entries


## One enum's own values. The enum is named by the kind's argument (`enum_value:State`), because a
## field asking for a value of one enum is not asking for the values of all of them.
static func _enum_entries(sheet: EventSheetResource, enum_name: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if sheet == null:
		return entries
	for row: EnumRow in _sheet_enums(sheet.events):
		if not enum_name.is_empty() and row.enum_name != enum_name:
			continue
		for member: String in row.members:
			var member_name: String = member.get_slice("=", 0).strip_edges()
			if member_name.is_empty():
				continue
			entries.append({"text": "%s.%s" % [row.enum_name, member_name],
				"detail": "%s %s %s" % [row.enum_name, SEPARATOR,
					EventSheetL10n.translate("enum value")], "kind": KIND_ENUM})
	return entries


## Every enum the sheet declares, at any depth.
static func _sheet_enums(entries: Array) -> Array[EnumRow]:
	var found: Array[EnumRow] = []
	for entry: Variant in entries:
		if entry is EnumRow and (entry as EnumRow).enabled:
			found.append(entry as EnumRow)
		elif entry is EventGroup:
			var group: EventGroup = entry as EventGroup
			found.append_array(_sheet_enums(group.events if not group.events.is_empty() else group.rows))
	return found


## The project's files that could BE this resource type, as quoted `res://` paths. The extensions
## come from the engine's own loader rather than from a table here, so a type whose importer
## someone added is filtered correctly without an edit.
static func _file_entries(resource_type: String) -> Array[Dictionary]:
	var wanted: Dictionary = {}
	for extension: String in ResourceLoader.get_recognized_extensions_for_type(resource_type):
		wanted[extension.to_lower()] = true
	var entries: Array[Dictionary] = []
	for path: String in _project_files():
		if not wanted.is_empty() and not wanted.has(path.get_extension().to_lower()):
			continue
		entries.append({"text": "\"%s\"" % path, "detail": path.get_base_dir(), "kind": KIND_FILE})
	return entries


## A path field's candidates: BOTH places a game has, `user://` first.
##
## The `user://` half is read off the folder as it stands at edit time, which is the honest answer
## about a place the GAME writes to while it runs - the file a reader is completing towards is
## usually one their own last test run wrote. It is a list of what is there, never a list of what is
## allowed: any path may still be typed, and one this list has never seen is not wrong.
##
## `user://` leads because it is where a path in this vocabulary almost always belongs - res:// is
## read-only the moment the game is exported - and because the res:// half is the long one.
static func _path_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for path: String in _user_files():
		entries.append({"text": "\"%s\"" % path, "detail": "%s %s %s" % [path.get_base_dir(),
			SEPARATOR, EventSheetL10n.translate("the player's folder")], "kind": KIND_FILE})
	for path: String in _project_files():
		entries.append({"text": "\"%s\"" % path, "detail": "%s %s %s" % [path.get_base_dir(),
			SEPARATOR, EventSheetL10n.translate("the game's own files, read-only once exported")],
			"kind": KIND_FILE})
	return entries


## Every custom data layer name the project's tilesets declare, quoted, because the field it fills
## takes a name as a string. The detail says nothing more than the kind, since a data layer's whole
## meaning is the word itself and the tileset that declares it is usually the only one.
##
## Read as TEXT by EventForgeTileSetFacts rather than by loading anything - the reason lives in that
## file. A project whose tilesets it cannot read answers with an empty list, which is a plain field
## rather than a wrong one.
static func _tile_data_key_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for key: String in load(TILESET_FACTS_PATH).project_data_keys():
		entries.append({"text": "\"%s\"" % key, "detail": EventSheetL10n.translate("tile data"),
			"kind": KIND_MEMBER})
	return entries


## Every kind of damage the project has written down, quoted, because the field it fills takes a
## name as a string. Read as TEXT by the damage type facts rather than by loading anything - a
## set's script ships in a pack the reader may not have installed.
##
## A PROJECT THAT HAS WRITTEN NONE DOWN IS OFFERED THE SHIPPED STARTER, which is the opposite of
## what the Doctor does with the same file and for the opposite reason: a note about a starter
## nobody chose would be a note nobody wanted, while a field that suggests nothing on the first day
## teaches nobody the word it wants. The moment the project writes a set of its own, that set is the
## only one read. A kind this list has never seen is still not wrong - it is one nobody has written
## down yet - so the field takes whatever is typed into it either way.
static func _damage_type_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for kind: Dictionary in load(DAMAGE_TYPE_FACTS_PATH).types_to_suggest():
		entries.append({"text": "\"%s\"" % str(kind["name"]),
			"detail": str(kind["path"]).get_file(), "kind": KIND_MEMBER})
	return entries


## Every terrain the project's tilesets declare, inserting the NUMBER the row's field takes and
## reading out the name and the set it belongs to - which is the whole point of the list, since the
## field is an index and an index says nothing to anybody.
static func _tile_terrain_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for terrain: Dictionary in load(TILESET_FACTS_PATH).project_terrains():
		entries.append({"text": str(terrain["index"]),
			"detail": "%s %s %s %d" % [str(terrain["name"]), SEPARATOR,
				EventSheetL10n.translate("terrain set"), int(terrain["set"])],
			"kind": KIND_MEMBER})
	return entries


## Every file under `user://` as it stands right now, folders walked in SORTED order so two asks of
## an unchanged folder answer identically (the engine's directory walk is filesystem order, which
## differs between platforms). Capped by the same ceiling the project walk uses: a reader picking a
## save slot is not helped by the four-thousandth log line.
static func _user_files() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var pending: Array[String] = ["user://"]
	while not pending.is_empty() and found.size() < FILE_LIMIT:
		var directory: String = pending.pop_front()
		var handle: DirAccess = DirAccess.open(directory)
		if handle == null:
			continue
		var sub_directories: PackedStringArray = handle.get_directories()
		sub_directories.sort()
		for sub_directory: String in sub_directories:
			if sub_directory.begins_with("."):
				continue
			pending.append(directory.path_join(sub_directory))
		var file_names: PackedStringArray = handle.get_files()
		file_names.sort()
		for file_name: String in file_names:
			found.append(directory.path_join(file_name))
			if found.size() >= FILE_LIMIT:
				break
	return found


## Every file under `res://` outside `addons/` and outside dot-folders (the engine's own caches
## such as `.godot`, and version-control data). ONE walk, held
## for the session and dropped when the filesystem changes - the scan a keystroke must never do.
static func _project_files() -> PackedStringArray:
	var key: String = "project|__files"
	if _cache.has(key):
		return PackedStringArray(_cache[key])
	var found: PackedStringArray = PackedStringArray()
	var pending: Array[String] = ["res://"]
	while not pending.is_empty() and found.size() < FILE_LIMIT:
		var directory: String = pending.pop_front()
		var handle: DirAccess = DirAccess.open(directory)
		if handle == null:
			continue
		for sub_directory: String in handle.get_directories():
			if sub_directory.begins_with(".") or sub_directory == "addons":
				continue
			pending.append(directory.path_join(sub_directory))
		for file_name: String in handle.get_files():
			if file_name.ends_with(".import") or file_name.ends_with(".uid"):
				continue
			found.append(directory.path_join(file_name))
			if found.size() >= FILE_LIMIT:
				break
	_cache[key] = found
	return found


# ── Expressions ────────────────────────────────────────────────────────────────────────
#
# The one kind whose answer depends on where the caret is. After `hp.` the reader wants that type's
# members and nothing else; after `$` the scene's nodes; otherwise the flat vocabulary. The reading
# of the context is the choke point the expression box and the Script block already share, so a
# member list here and a member list there cannot disagree.


## The expression candidates for one caret position. Member position and `$`/`%` position are
## answered live (they are cheap, and depend on the token the caret sits behind); the flat
## vocabulary is the cached pool.
##
## The position is read from what comes BEFORE the word being typed, never from the last character:
## `hp.` and `hp.he` are the same position, and a reader who has typed two letters of a member name
## is more sure of what they want than one who has typed none. Reading the last character instead
## meant the list turned back into the sheet's own vocabulary the moment anything was typed, and
## accepting from it wrote a top-level name after the dot.
##
## What it returns is {"entries": the candidates, unranked, "needle": what to rank them against,
## "note": why there is nothing to offer, when that is worth saying}.
static func expression_answer(sheet: EventSheetResource, text_before_caret: String, within: Resource = null) -> Dictionary:
	var needle: String = trailing_word(text_before_caret)
	var locals: Dictionary = scope_types(sheet, within)
	# Inside a string literal the caret is asking for a NAME the call wants, or nothing at all.
	var quoted: Dictionary = EventSheetExpressionWalk.string_context(text_before_caret)
	if not quoted.is_empty():
		return {"entries": _quoted_entries(sheet, quoted, locals), "needle": str(quoted["text"]), "note": ""}
	var head: String = _before_the_typed_word(text_before_caret)
	if head.ends_with("."):
		var receiver_text: String = EventSheetExpressionWalk.receiver_before_dot(head)
		if not receiver_text.is_empty():
			return _member_answer(sheet, receiver_text, needle, locals)
		return {"entries": [] as Array[Dictionary], "needle": needle, "note": ""}
	# The sigil is already typed, so the entries drop theirs - and the one that was typed picks
	# which spelling is on offer: `$` the paths, `%` the unique names.
	var sigil: String = node_sigil(text_before_caret)
	if not sigil.is_empty():
		var addressed: Array[Dictionary] = []
		for entry: Dictionary in _pool(null, FIELD_NODE):
			var text: String = str(entry.get("text", ""))
			if text.begins_with(sigil):
				addressed.append({"text": text.substr(1), "detail": str(entry.get("detail", "")),
					"kind": KIND_NODE})
		return {"entries": addressed, "needle": needle, "note": ""}
	var flat: Array[Dictionary] = []
	flat.append_array(_pool(sheet, FIELD_EXPRESSION))
	flat.append_array(_global_pool())
	var scoped: Array[Dictionary] = _scope_entries(sheet, within)
	if scoped.is_empty():
		return {"entries": flat, "needle": needle, "note": "", "flat": true}
	# The names in view of this event come right after the sheet's own, before the host's and the
	# language's - the order a sheet is read in.
	var merged: Array[Dictionary] = []
	var inserted: bool = false
	for entry: Dictionary in flat:
		if not inserted and str(entry.get("group", "")) == "host":
			merged.append_array(scoped)
			inserted = true
		merged.append(entry)
	if not inserted:
		merged.append_array(scoped)
	return {"entries": merged, "needle": needle, "note": "", "flat": true}


## The members after a dot, or the honest reason there are none.
static func _member_answer(sheet: EventSheetResource, receiver_text: String, needle: String, locals: Dictionary) -> Dictionary:
	var typed: Dictionary = EventSheetExpressionWalk.resolve(receiver_text, sheet, locals)
	if bool(typed.get("known", false)):
		var type_text: String = str(typed["type"])
		var listed: Array[Dictionary] = []
		if type_text.begins_with(EventSheetMemberCatalog.ENUM_PREFIX):
			listed = _sheet_enum_members(sheet, type_text.trim_prefix(EventSheetMemberCatalog.ENUM_PREFIX))
		elif bool(typed.get("static", false)):
			listed = EventSheetMemberCatalog.statics(type_text)
			# A name that is also a value (a singleton, a script class) offers its instance members too.
			if listed.is_empty() or type_text.begins_with(EventSheetMemberCatalog.SCRIPT_PREFIX):
				listed = listed + EventSheetMemberCatalog.members(type_text)
		else:
			listed = EventSheetMemberCatalog.members(type_text)
			# `self` is the sheet's own node: what the sheet declares comes first, then the host's.
			if receiver_text == "self":
				var own: Array[Dictionary] = _own_members(sheet)
				own.append_array(listed)
				listed = own
		if not listed.is_empty():
			return {"entries": listed, "needle": needle, "note": ""}
	# The older readings still answer what the walk does not type: `host.` of a behaviour sheet is
	# typed above, but a `$Child` that is a script class living outside the open scene is not.
	var fallback: Array[Dictionary] = []
	var first: String = receiver_text
	if not first.contains(".") and not first.contains("("):
		for candidate: Dictionary in load(LINT_PATH).dot_completion_candidates(first, sheet):
			fallback.append({"text": str(candidate.get("label", "")), "detail": first, "kind": KIND_MEMBER})
	if not fallback.is_empty():
		return {"entries": fallback, "needle": needle, "note": ""}
	return {"entries": [] as Array[Dictionary], "needle": needle, "note": UNTYPED_NOTE}


## What the sheet declares on its own node, as members: its variables, then its functions.
static func _own_members(sheet: EventSheetResource) -> Array[Dictionary]:
	var own: Array[Dictionary] = []
	for entry: Dictionary in _variable_entries(sheet, false):
		var text: String = str(entry["text"])
		if not text.contains("."):
			var member: Dictionary = entry.duplicate()
			member["lower"] = text.to_lower()
			own.append(member)
	for function_resource: Variant in sheet.functions:
		var event_function: EventFunction = function_resource as EventFunction
		if event_function == null or event_function.function_name.strip_edges().is_empty():
			continue
		var names: PackedStringArray = PackedStringArray()
		for param: Variant in event_function.params:
			if param is ACEParam:
				names.append((param as ACEParam).id)
		own.append({"text": event_function.function_name + "()", "label": "%s(%s)" % [event_function.function_name, ", ".join(names)],
			"detail": _function_detail(event_function), "kind": KIND_FUNCTION, "type": _return_word_of(event_function),
			"lower": event_function.function_name.to_lower(), "caret_back": 1 if not names.is_empty() else 0})
	return own


## The sentence a list says when a step cannot be typed from the sheet alone.
const UNTYPED_NOTE := "worked out while the game runs"


## The members of one of the sheet's own enums, as the entries `State.` has always offered.
static func _sheet_enum_members(sheet: EventSheetResource, enum_name: String) -> Array[Dictionary]:
	var members: Array[Dictionary] = []
	for enum_row: EnumRow in sheet_enums_of(sheet):
		if enum_row.enum_name == enum_name:
			for member: String in enum_row.members:
				var member_name: String = member.get_slice("=", 0).strip_edges()
				members.append({"text": member_name, "detail": enum_name, "kind": KIND_MEMBER, "type": enum_name})
	return members


## Why a list has nothing to say, when the caret is where a type was expected: "" or the sentence
## (already in the editor's language) for the empty-list line.
static func empty_note(sheet: EventSheetResource, text_before_caret: String, within: Resource = null) -> String:
	var answer: Dictionary = expression_answer(sheet, text_before_caret, within)
	return EventSheetL10n.translate("worked out while the game runs") if not str(answer["note"]).is_empty() else ""


## The enums the sheet declares, at any depth.
static func sheet_enums_of(sheet: EventSheetResource) -> Array[EnumRow]:
	return _sheet_enums(sheet.events) if sheet != null else ([] as Array[EnumRow])


## The scene the open sheet's fields look names up in (the injected one in a test).
static func scene_root() -> Node:
	return _scene_root()


## The path of a project script class by its class_name, "" when there is none.
static func global_class_path(class_text: String) -> String:
	return str(load(LINT_PATH)._global_class_path(class_text))


## {name: {"type", "function"}} for the sheet's own variables and functions: what the walk types a
## first word by. Held per sheet, dropped with the rest when the sheet is edited.
static func symbol_types(sheet: EventSheetResource) -> Dictionary:
	if sheet == null:
		return {}
	var key: String = "%d|__symbols" % sheet.get_instance_id()
	if _symbol_cache.has(key):
		return _symbol_cache[key]
	var table: Dictionary = {}
	for entry: Dictionary in EventSheetVariableOwners.catalog(sheet):
		# An autoload's variable is reached through the autoload's name, and a local only from inside
		# its own event (the walk is handed those separately).
		if str(entry.get("autoload", "")) != "" or str(entry.get("group", "")) == EventSheetVariableOwners.GROUP_LOCAL:
			continue
		var name_text: String = str(entry.get("name", ""))
		var type_text: String = _type_word_of(str(entry.get("type_name", "")), str(entry.get("value", "")))
		if not table.has(name_text) or (str(table[name_text].get("type", "")).is_empty() and not type_text.is_empty()):
			table[name_text] = {"type": type_text, "function": false}
	for function_resource: Variant in sheet.functions:
		var event_function: EventFunction = function_resource as EventFunction
		if event_function != null and not event_function.function_name.is_empty():
			table[event_function.function_name] = {"type": _return_word_of(event_function), "function": true}
	_symbol_cache[key] = table
	return table


static var _symbol_cache: Dictionary = {}
static var _scope_cache: Dictionary = {}


## {name: type} for what the event `within` can say that is its own: its locals and those of the
## events it sits under, the values its trigger hands in, and the parameters of the function it is in.
static func scope_types(sheet: EventSheetResource, within: Resource) -> Dictionary:
	var types: Dictionary = {}
	for entry: Dictionary in _scope_facts(sheet, within):
		types[str(entry["name"])] = str(entry["type"])
	return types


## The names in view of an event, as list entries (kind local).
static func _scope_entries(sheet: EventSheetResource, within: Resource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for fact: Dictionary in _scope_facts(sheet, within):
		var starts: String = str(fact.get("value", ""))
		var said: String = str(fact["origin"])
		if not starts.is_empty():
			said += " %s %s" % [SEPARATOR, EventSheetL10n.translate("starts %s") % starts]
		entries.append({"text": str(fact["name"]), "detail": said, "kind": KIND_LOCAL,
			"type": str(fact["type"]), "lower": str(fact["name"]).to_lower()})
	return entries


## The locals and parameters in view of `within`, outermost first: [{name, type, value, origin}].
static func _scope_facts(sheet: EventSheetResource, within: Resource) -> Array[Dictionary]:
	var facts: Array[Dictionary] = []
	if sheet == null or within == null:
		return facts
	var key: String = "%d|%d" % [sheet.get_instance_id(), within.get_instance_id()]
	if _scope_cache.has(key):
		return _scope_cache[key]
	var path: Array = []
	var holder: Resource = null
	for function_resource: Variant in sheet.functions:
		var event_function: EventFunction = function_resource as EventFunction
		if event_function != null and _path_to(event_function.events, within, path):
			holder = event_function
			break
	if holder == null:
		path = []
		_path_to(sheet.events, within, path)
	if holder is EventFunction:
		for param: Variant in (holder as EventFunction).params:
			var typed_param: ACEParam = param as ACEParam
			if typed_param != null and not typed_param.id.strip_edges().is_empty():
				facts.append({"name": typed_param.id, "type": typed_param.type_name, "value": "",
					"origin": EventSheetL10n.translate("Parameter of %s") % (holder as EventFunction).function_name})
	for index: int in range(path.size()):
		var event_row: EventRow = path[index] as EventRow
		if event_row == null:
			continue
		if index == 0 or event_row.trigger_id != "":
			for parameter: String in str(TriggerResolver.resolve_trigger(event_row).get("args", "")).split(","):
				var piece: String = parameter.strip_edges()
				if piece.is_empty():
					continue
				facts.append({"name": piece.get_slice(":", 0).strip_edges(), "type": piece.get_slice(":", 1).strip_edges() if piece.contains(":") else "",
					"value": "", "origin": EventSheetL10n.translate("Handed in by the trigger")})
		for local: LocalVariable in event_row.local_variables:
			if local != null and not local.name.strip_edges().is_empty():
				facts.append({"name": local.name.strip_edges(), "type": _type_word_of(local.type_name, EventSheetVariableOwners.default_text(local.default_value)),
					"value": EventSheetVariableOwners.default_text(local.default_value),
					"origin": EventSheetL10n.translate("Local to this event") if index == path.size() - 1 else EventSheetL10n.translate("Local to a parent event")})
		# A local made by a "Set local variable" action is the other way an event declares one.
		for action: Resource in event_row.actions:
			var declaring: ACEAction = action as ACEAction
			if declaring == null or not str(declaring.ace_id).begins_with("SetLocal"):
				continue
			var declared: Dictionary = declaring.params if not declaring.params.is_empty() else declaring.parameters
			var local_name: String = str(declared.get("name", "")).strip_edges()
			if local_name.is_empty():
				continue
			var value_text: String = str(declared.get("value", "")).strip_edges()
			var local_type: String = str(declared.get("var_type", declared.get("const_type", "")))
			if local_type.is_empty():
				local_type = "float" if str(declaring.ace_id) == "SetLocalFromAxis" else _type_word_of("", value_text)
			facts.append({"name": local_name, "type": local_type, "value": value_text,
				"origin": EventSheetL10n.translate("Local to this event") if index == path.size() - 1 else EventSheetL10n.translate("Local to a parent event")})
	_scope_cache[key] = facts
	return facts


## The event a condition or action belongs to (the event itself when handed one), null when the
## sheet holds no such resource. Asked once when a field opens, never per keystroke.
static func event_holding(sheet: EventSheetResource, resource: Resource) -> Resource:
	if sheet == null or resource == null:
		return null
	if resource is EventRow:
		return resource
	var found: Resource = _holder_in(sheet.events, resource)
	if found != null:
		return found
	for function_resource: Variant in sheet.functions:
		var event_function: EventFunction = function_resource as EventFunction
		if event_function != null:
			found = _holder_in(event_function.events, resource)
			if found != null:
				return found
	return null


static func _holder_in(entries: Array, resource: Resource) -> Resource:
	for entry: Variant in entries:
		if entry is EventRow:
			var event_row: EventRow = entry as EventRow
			if event_row.trigger == resource or event_row.conditions.has(resource) or event_row.actions.has(resource):
				return event_row
			var deeper: Resource = _holder_in(event_row.sub_events, resource)
			if deeper != null:
				return deeper
		elif entry is EventGroup:
			var in_group: Resource = _holder_in(EventSheetGroupFacts.children(entry as EventGroup), resource)
			if in_group != null:
				return in_group
	return null


## Fills `path` with the events from the top down to `target` inside `entries` (groups looked
## through) and says whether it was found.
static func _path_to(entries: Array, target: Resource, path: Array) -> bool:
	for entry: Variant in entries:
		if entry == target:
			path.append(entry)
			return true
		if entry is EventRow:
			path.append(entry)
			if _path_to((entry as EventRow).sub_events, target, path):
				return true
			path.pop_back()
		elif entry is EventGroup:
			if _path_to(EventSheetGroupFacts.children(entry as EventGroup), target, path):
				return true
	return false


# ── Names inside quotes ───────────────────────────────────────────────────────────────────


## What the argument under the caret wants, as one of "action", "animation", "group", "scene",
## "path" - or "" when it wants no particular name. Decided by what the engine's own reference says
## the argument is (its declared name and the class that owns the call), never by guessing from the
## text: a string inside print() or get_node() offers nothing.
static func quoted_kind(sheet: EventSheetResource, call: Dictionary, locals: Dictionary) -> String:
	if call.is_empty() or not bool(call.get("direct", false)):
		return ""
	var callee: String = str(call["callee"])
	var arg_index: int = int(call["arg"])
	var receiver_text: String = str(call["receiver"])
	var receiver_type: String = ""
	if not receiver_text.is_empty():
		var typed: Dictionary = EventSheetExpressionWalk.resolve(receiver_text, sheet, locals)
		if not bool(typed.get("known", false)):
			return ""
		receiver_type = EventSheetMemberCatalog.base_of(str(typed["type"]))
	elif callee in ["load", "preload"] and arg_index == 0:
		return "path"
	var info: Dictionary = {}
	if not receiver_text.is_empty():
		info = EventSheetMemberCatalog.method_info(receiver_type, callee)
	else:
		info = EventSheetExpressionWalk.bare_signature(callee, sheet)
	var args: Array = info.get("args", [])
	if arg_index >= args.size():
		return ""
	var arg_name: String = str((args[arg_index] as Dictionary).get("n", ""))
	var arg_type: String = str((args[arg_index] as Dictionary).get("t", ""))
	if arg_type not in ["StringName", "String", "NodePath"]:
		return ""
	# Godot's own naming: an action argument is called `action` or ends in `_action`, and every name an
	# Input call takes is an Input Map entry (get_axis's negative_x, get_vector's positive_y...).
	if arg_name == "action" or arg_name.ends_with("_action") or (receiver_type == "Input" and arg_type == "StringName"):
		return "action"
	if arg_name == "group":
		return "group"
	if arg_name in ["name", "anim", "animation", "animation_name"] and _is_animated(receiver_type):
		return "animation"
	if arg_name == "path" and (callee == "change_scene_to_file" or receiver_type == "ResourceLoader"):
		return "scene" if callee == "change_scene_to_file" else "path"
	return ""


## True when the class (or a script's base) is one that plays animations by name.
static func _is_animated(type_text: String) -> bool:
	var current: String = type_text
	if current.begins_with(EventSheetMemberCatalog.SCRIPT_PREFIX):
		current = str(load(SCRIPT_MEMBERS_PATH).of_script(current.trim_prefix(EventSheetMemberCatalog.SCRIPT_PREFIX)).get("base", ""))
	while not current.is_empty():
		if current in ["AnimatedSprite2D", "AnimatedSprite3D", "AnimationPlayer", "SpriteFrames"]:
			return true
		current = str(ClassDB.get_parent_class(current))
	return false




## The names a string literal's call wants, said without their quotes (the quote is typed).
static func _quoted_entries(sheet: EventSheetResource, quoted: Dictionary, locals: Dictionary) -> Array[Dictionary]:
	var call: Dictionary = quoted["call"]
	var wanted: String = quoted_kind(sheet, call, locals)
	if wanted.is_empty():
		return [] as Array[Dictionary]
	# Held like every other list: what a call wants is the same on every keystroke inside its quotes.
	var scope: String = "project"
	var key_text: String = wanted
	if wanted == "animation":
		scope = str(sheet.get_instance_id() if sheet != null else 0)
		key_text = "animation:" + str(call["receiver"])
	var key: String = "%s|quoted:%s" % [scope, key_text]
	if _cache.has(key):
		return _cache[key]
	var entries: Array[Dictionary] = []
	match wanted:
		"action":
			for entry: Dictionary in _pool(null, FIELD_INPUT_ACTION):
				entries.append({"text": str(entry["text"]).trim_prefix("\"").trim_suffix("\""), "detail": str(entry.get("detail", "")),
					"kind": KIND_ACTION, "type": str(entry.get("detail", "")), "desc": EventSheetL10n.translate("Input Map control.")})
		"animation":
			entries = _animation_names_of(sheet, call, locals)
		"group":
			entries = _code_aware_groups()
		"scene", "path":
			entries = _path_entries_for(wanted == "scene")
	_cache[key] = entries
	_cache_order.append(key)
	while _cache_order.size() > CACHE_LIMIT:
		_cache.erase(_cache_order.pop_front())
	return entries


## The animations the receiver of `play(` really has: its own SpriteFrames or AnimationPlayer
## library, read off the node in the open scene. Without a node to read, the scene's animations.
static func _animation_names_of(sheet: EventSheetResource, call: Dictionary, locals: Dictionary) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var receiver_text: String = str(call["receiver"])
	var node: Node = null
	if receiver_text.begins_with("$") or receiver_text.begins_with("%"):
		var root: Node = _scene_root()
		if root != null:
			var path: String = receiver_text.substr(1).trim_prefix("\"").trim_suffix("\"")
			node = root.get_node_or_null(NodePath(path if receiver_text.begins_with("$") else "%" + path))
	if node != null:
		var owner_name: String = str(node.name)
		var frames: Variant = node.get("sprite_frames") if "sprite_frames" in node else null
		if frames is SpriteFrames:
			for clip: String in (frames as SpriteFrames).get_animation_names():
				var count: int = (frames as SpriteFrames).get_frame_count(clip)
				var loops: bool = (frames as SpriteFrames).get_animation_loop(clip)
				entries.append({"text": clip, "kind": KIND_ANIMATION, "detail": owner_name,
					"type": (EventSheetL10n.translate("%d frames, loops") if loops else EventSheetL10n.translate("%d frames")) % count,
					"desc": EventSheetL10n.translate("%s's SpriteFrames.") % owner_name})
			return entries
		if node is AnimationPlayer:
			for clip: String in (node as AnimationPlayer).get_animation_list():
				var animation: Animation = (node as AnimationPlayer).get_animation(clip)
				entries.append({"text": clip, "kind": KIND_ANIMATION, "detail": owner_name,
					"type": EventSheetL10n.translate("%s s") % String.num(animation.length, 2),
					"desc": EventSheetL10n.translate("%s's animations.") % owner_name})
			return entries
	for entry: Dictionary in _pool(sheet, FIELD_ANIMATION):
		entries.append({"text": str(entry["text"]).trim_prefix("\"").trim_suffix("\""), "kind": KIND_ANIMATION,
			"detail": str(entry.get("detail", "")), "type": "", "desc": str(entry.get("detail", ""))})
	return entries


## The scene's groups, and the groups only code adds, each saying where it was found.
static func _code_aware_groups() -> Array[Dictionary]:
	var key: String = "project|__code_groups"
	var found_in_code: Dictionary = {}
	if _cache.has(key):
		found_in_code = _cache[key][0]
	else:
		found_in_code = _scan_code_groups()
		_cache[key] = [found_in_code]
		_cache_order.append(key)
	var entries: Array[Dictionary] = []
	var seen: Dictionary = {}
	var scene_root: Node = _scene_root()
	for choice: Variant in ReadingDoors.params_dialog().group_choices(scene_root):
		var group_name: String = str(choice).trim_prefix("\"").trim_suffix("\"")
		seen[group_name] = true
		var where: String = EventSheetL10n.translate("In the open scene.")
		if found_in_code.has(group_name):
			where = EventSheetL10n.translate("In the open scene, and add_to_group in %s.") % str(found_in_code[group_name])
		entries.append({"text": group_name, "kind": KIND_GROUP, "detail": where,
			"type": EventSheetParamFieldFactory.node_group_note(group_name, scene_root), "desc": where})
	for group_name: Variant in found_in_code.keys():
		if seen.has(str(group_name)):
			continue
		var from_file: String = EventSheetL10n.translate("add_to_group(\"%s\", true) in %s.") % [str(group_name), str(found_in_code[group_name])]
		entries.append({"text": str(group_name), "kind": KIND_GROUP, "detail": from_file,
			"type": EventSheetL10n.translate("code only"), "desc": from_file})
	return entries


## {group: first file that adds it} for every add_to_group("name") the project's scripts write.
static func _scan_code_groups() -> Dictionary:
	var found: Dictionary = {}
	var pattern: RegEx = RegEx.create_from_string("add_to_group\\(\\s*[\"']([A-Za-z0-9][A-Za-z0-9_ .\\-]{0,47})[\"']")
	for path: String in _project_files():
		if not path.ends_with(".gd"):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		if text.length() > 200000 or not text.contains("add_to_group"):
			continue
		for hit: RegExMatch in pattern.search_all(text):
			if not found.has(hit.get_string(1)):
				found[hit.get_string(1)] = path.get_file()
	return found


## The project's files for a quoted path: scenes first, then everything else; `scenes_only` for a call
## that changes scene. The type column says what the file is.
static func _path_entries_for(scenes_only: bool) -> Array[Dictionary]:
	var scenes: Dictionary = {}
	for extension: String in ResourceLoader.get_recognized_extensions_for_type("PackedScene"):
		scenes[extension.to_lower()] = true
	var first: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	for path: String in _project_files():
		var is_scene: bool = scenes.has(path.get_extension().to_lower())
		if scenes_only and not is_scene:
			continue
		var entry: Dictionary = {"text": path, "kind": KIND_FILE, "detail": path.get_base_dir(),
			"type": _file_type(path, is_scene), "desc": EventSheetL10n.translate("A scene file.") if is_scene else path.get_file()}
		if is_scene:
			first.append(entry)
		else:
			rest.append(entry)
	return first + rest


static func _file_type(path: String, is_scene: bool) -> String:
	if is_scene:
		return "PackedScene"
	if Engine.is_editor_hint():
		return str(EditorInterface.get_resource_filesystem().get_file_type(path))
	return ""


## The flat expression vocabulary: the sheet's variables, its functions, its enums, the host
## class's own members, and the language's globals. Everything a reader can say in a value field
## without reaching through a dot first.
static func _build_expression_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	# The locals are NOT here: they are the event's own and are added per ask (see expression_answer).
	var entries: Array[Dictionary] = _variable_entries(sheet, false)
	entries.append_array(_function_entries(sheet))
	entries.append_array(_parameter_entries(sheet))
	entries.append_array(_spawn_chip_entries(sheet))
	entries.append_array(_enum_entries(sheet, ""))
	if sheet != null and ClassDB.class_exists(sheet.host_class):
		# The host's own members, with their types, from the same catalog a dot reads. Marked so the
		# event's locals can be slotted in just ahead of them.
		for member: Dictionary in EventSheetMemberCatalog.members(sheet.host_class):
			var hosted: Dictionary = member.duplicate()
			hosted["group"] = "host"
			entries.append(hosted)
		for constant: Dictionary in EventSheetMemberCatalog.statics(sheet.host_class):
			if str(constant.get("member_kind", "")) == "c":
				var hosted_constant: Dictionary = constant.duplicate()
				hosted_constant["group"] = "host"
				entries.append(hosted_constant)
	var global_hints: Dictionary = load(LINT_PATH).GDSCRIPT_GLOBAL_HINTS
	for global_name: Variant in global_hints.keys():
		entries.append({"text": "%s()" % str(global_name),
			"detail": "%s %s %s" % [EventSheetL10n.translate("built-in"), SEPARATOR,
				str(global_hints[global_name])],
			"kind": KIND_BUILTIN})
	return entries


## The names the engine itself puts in scope everywhere: singletons (Input, Time...), the built-in
## value types (Vector2, Color...) and the global enum values (KEY_SPACE, MOUSE_BUTTON_LEFT...). The
## value types and enums come from the class reference, which is nothing until it has been built -
## so this list is held only once it is complete, and rebuilt (cheaply) until then.
static func _global_pool() -> Array[Dictionary]:
	var key: String = "project|__globals"
	if _cache.has(key):
		return _cache[key]
	var entries: Array[Dictionary] = []
	var reference: GDScript = load("res://addons/eventsheet/ace/class_reference.gd")
	for singleton: String in Engine.get_singleton_list():
		entries.append({"text": singleton, "detail": EventSheetL10n.translate("Singleton"), "kind": KIND_CLASS,
			"type": singleton, "lower": singleton.to_lower()})
	var complete: bool = reference.ready()
	for type_name: String in reference.builtin_names():
		entries.append({"text": type_name, "detail": EventSheetL10n.translate("Built-in type"), "kind": KIND_CLASS,
			"type": "", "lower": type_name.to_lower(), "member_kind": "t", "owner": type_name, "member": type_name, "engine": true, "builtin": true})
	for enum_name: Variant in reference.global_enums().keys():
		for value: Variant in reference.global_enums()[enum_name]:
			var constant_name: String = str((value as Dictionary).get("n", ""))
			entries.append({"text": constant_name, "detail": str(enum_name), "kind": KIND_CONSTANT,
				"type": "%s = %d" % [enum_name, int((value as Dictionary).get("v", 0))], "lower": constant_name.to_lower(),
				"member_kind": "c", "owner": "", "member": constant_name, "engine": true, "enum_value": true, "nofuzzy": true})
	if complete:
		_cache[key] = entries
		_cache_order.append(key)
	return entries


## The parameters the sheet's own functions declare, each said with the function it belongs to. A
## reader writing inside a function is reaching for these as often as for a variable, and they are
## the one name the flat vocabulary used to be missing.
static func _parameter_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if sheet == null:
		return entries
	var seen: Dictionary = {}
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function == null:
			continue
		for parameter: Variant in event_function.params:
			var param: ACEParam = parameter as ACEParam
			if param == null or param.id.strip_edges().is_empty() or seen.has(param.id):
				continue
			seen[param.id] = true
			entries.append({"text": param.id, "detail": "%s %s %s" % [
				event_function.function_name, SEPARATOR, EventSheetL10n.translate("parameter")],
				"kind": KIND_VARIABLE})
	return entries


## The rows that name a new copy, and the parameter each one names it in. A spawn row declares a
## real local variable, so the name it was given is a name the rows after it can say - and this is
## the list that offers it. Kept as data rather than as an `if` chain so a spawn row added later is
## offered the moment it says which parameter carries its name.
const SPAWN_NAME_PARAMS: Dictionary = {
	"SpawnNewCopy": "name",
	"SpawnNewCopyDeferred": "name",
	"SpawnNewCopyDeferredWorld": "name",
	"SpawnNewCopyDeferredWorld3D": "name",
	"MakeNewCopy": "name",
	"SpawnIntoCrowd": "name",
	"SpawnIntoCrowdOldestFirst": "name",
	"SpawnIntoCrowdUnlessFull": "name",
	# The launched twin, which declares its local exactly as its frozen neighbour does. Its formation
	# sibling is deliberately NOT here: the name a formation gives a copy lives INSIDE the loop the
	# row writes, so it is gone by the time the next row runs and offering it would be offering a
	# name that cannot be said. The whole formation is addressed by its crowd instead.
	"SpawnFacingAndMoving": "name",
	"SpawnFacingAndMoving3D": "name",
	# A copy of the node's own scene declares its local exactly as the safe spawn it is written from.
	"SpawnCopyOfSelf": "name",
	"SpawnCopyOfSelf3D": "name",
	# And the free-spot spawn, which binds its name ABOVE the branch precisely so the rows underneath
	# can say it. The name is simply nothing when the arena was full, which is the question Is Still
	# Here answers - so the name is worth offering and worth guarding, not worth hiding.
	"SpawnInFreeSpot": "name",
	"SpawnInFreeSpot3D": "name",
}


## Every name a spawn row in this sheet gave a new copy, said with the scene it is a copy of. The
## chip a following row picks its object from: `var new_enemy = Enemy.instantiate()` is what the row
## emitted, so `new_enemy` is simply what the code already says by the time the next row runs.
##
## Sheet-wide rather than event-wide on purpose: this list feeds a FIELD, and a field does not know
## which event it is being edited in. Offering a name is not the same as promising it is in scope -
## the emitted code is where scope is decided, and a name used outside its event fails to compile
## there, loudly, rather than quietly resolving to the wrong thing here.
static func _spawn_chip_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if sheet == null:
		return entries
	var seen: Dictionary = {}
	_collect_spawn_chips(sheet.events, entries, seen)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			_collect_spawn_chips(event_function.events, entries, seen)
	return entries


## The spawn names one row list holds, sub-events and all. A spawn under a condition is still a spawn
## the sheet does and still declares its local, so the rows beside it are offered the name for the
## same reason the rows under a plain event are.
static func _collect_spawn_chips(rows: Array, entries: Array[Dictionary], seen: Dictionary) -> void:
	for row: Variant in rows:
		var event: EventRow = row as EventRow
		if event == null:
			continue
		for entry: Variant in event.actions:
			var action: ACEAction = entry as ACEAction
			if action == null or not SPAWN_NAME_PARAMS.has(action.ace_id):
				continue
			var chip: String = str(action.params.get(str(SPAWN_NAME_PARAMS[action.ace_id]), "")).strip_edges()
			if chip.is_empty() or not chip.is_valid_identifier() or seen.has(chip):
				continue
			seen[chip] = true
			entries.append({"text": chip, "detail": "%s %s %s" % [
				_spawn_scene_word(str(action.params.get("scene", ""))), SEPARATOR,
				EventSheetL10n.translate("the new copy")], "kind": KIND_VARIABLE})
		_collect_spawn_chips(event.sub_events, entries, seen)


## The scene a spawn row names, said the short way a detail line has room for: the declared name as
## written (`Enemy`), or the file name out of a `load("res://…")` path. "" when the field holds
## something this cannot read, which leaves the detail saying only what the name IS.
static func _spawn_scene_word(scene: String) -> String:
	var text: String = scene.strip_edges()
	if text.is_valid_identifier():
		return text
	var opened: int = text.find("\"")
	var closed: int = text.rfind("\"")
	if opened >= 0 and closed > opened:
		return text.substr(opened + 1, closed - opened - 1).get_file()
	return text


## The identifier being typed at the end of `text`, or "" when the caret is not inside one. What a
## rank filters on: the reader typed `health + ma`, and `ma` is the part that is a query.
static func trailing_word(text: String) -> String:
	var index: int = text.length()
	while index > 0 and _is_word_character(text.substr(index - 1, 1)):
		index -= 1
	return text.substr(index)


## True for the characters a GDScript identifier is spelled with. Written out rather than asked of
## `is_valid_identifier`, which answers about a whole name and says no to a lone digit that is
## perfectly legal in the middle of one.
static func _is_word_character(character: String) -> bool:
	return character == "_" or character.to_lower() != character.to_upper() or character.is_valid_int()


## True when a trailing `%` is the modulo / string-format operator (it follows a value: an
## identifier, a number, a `)`, a `]` or a closing quote) rather than the start of a `%Name`
## reference. The one question that tells `score % 10` from `%HealthBar`.
static func is_modulo_context(text_before_caret: String) -> bool:
	var stem: String = text_before_caret.substr(0, text_before_caret.length() - 1).rstrip(" \t")
	if stem.is_empty():
		return false
	var last: String = stem.substr(stem.length() - 1)
	return _is_word_character(last) or ")]\"'".contains(last)


## What comes before the identifier being typed: `health + ma` gives `health + `, `$Spr` gives `$`.
## Where the caret IS, as opposed to what has been typed there - and the two have to be asked apart,
## because a position that changes as soon as a letter is typed is a position nobody can type in.
static func _before_the_typed_word(text: String) -> String:
	return text.substr(0, text.length() - trailing_word(text).length())


## The node sigil the caret sits behind - `$` for a path, `%` for a unique name - and "" when it
## sits behind neither. A `%` that follows a value is the modulo operator and stays one however much
## of a name is typed after it, which is the one question that tells `score % 10` from `%HealthBar`.
static func node_sigil(text_before_caret: String) -> String:
	var head: String = _before_the_typed_word(text_before_caret)
	if head.ends_with("$"):
		return "$"
	return "%" if head.ends_with("%") and not is_modulo_context(head) else ""


## The token a member access reaches through - `hp` in `health + hp.`, `$Sprite` in `$Sprite.he` -
## and "" when the caret is not in member position. The word being typed after the dot is not part
## of the question: `hp.` and `hp.health` reach through the same `hp`.
static func member_receiver(text: String) -> String:
	var head: String = _before_the_typed_word(text)
	if not head.ends_with("."):
		return ""
	head = head.substr(0, head.length() - 1)
	var word: String = trailing_word(head)
	if word.is_empty():
		return ""
	var prefix_index: int = head.length() - word.length()
	if prefix_index > 0 and head.substr(prefix_index - 1, 1) in ["$", "%"]:
		return head.substr(prefix_index - 1)
	return word


# ── Ranking ────────────────────────────────────────────────────────────────────────────


## The entries that match `needle`, best first. Tiers, from the answer a reader meant to the one
## they might accept: the whole name, a name that starts with it, a word of the name that starts
## with it, the name containing it, the explaining line containing it, and finally the letters in
## order anywhere in the name (the "stt" reflex). A shorter name breaks a tie, because a short name
## containing the query is more of the query than a long one.
static func rank(entries: Array[Dictionary], needle: String) -> Array[Dictionary]:
	var query: String = needle.strip_edges().to_lower().trim_prefix("\"").trim_suffix("\"")
	var scored: Array[Dictionary] = []
	for index: int in range(entries.size()):
		var score: int = score_of(entries[index], query)
		if score > 0:
			scored.append({"score": score, "at": index, "entry": entries[index]})
	# Ties keep the order the source built them in - the sheet's own variables before the host
	# class's members, the sheet's own signals before the engine's. Godot's sort is not stable, so
	# the position is part of the comparison rather than something left to it.
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) > int(b["score"])
		return int(a["at"]) < int(b["at"]))
	var ranked: Array[Dictionary] = []
	for hit: Dictionary in scored:
		ranked.append(hit["entry"])
		if ranked.size() >= RESULT_LIMIT:
			break
	return ranked


## One entry's relevance, 0 for no match at all. An empty query matches everything equally, so a
## field opened with nothing typed shows its list in the order the source built it.
##
## An entry may carry `lower` - its own text, already lowered and unquoted - and a source whose list
## is long enough for it to matter should. Lowering a string ALLOCATES one, and a rank that lowers
## every candidate on every keypress pays that allocation per entry per keystroke; a source that
## lowers once when it builds pays it per entry per session. Nothing is required to carry it and
## nothing reads differently for having it.
##
## `allow_fuzzy` is the letters-in-order tier, and a caller ranking PROSE turns it off: a subsequence
## match is a good guess about a name and a coin toss about a sentence, and testing it costs a walk
## of the whole sentence for an answer nobody wanted.
static func score_of(entry: Dictionary, query: String, allow_fuzzy: bool = true) -> int:
	if query.is_empty():
		return 1
	var text: String = entry.get("lower", "")
	if text.is_empty():
		text = str(entry.get("text", "")).to_lower().trim_prefix("\"").trim_suffix("\"")
	var score: int = 0
	if text == query:
		score = 1000
	elif text.begins_with(query):
		score = 600
	elif word_starts_with(text, query):
		score = 400
	elif text.contains(query):
		score = 250
	elif str(entry.get("detail", "")).to_lower().contains(query):
		score = 100
	elif allow_fuzzy and not entry.has("nofuzzy") and query.length() >= FUZZY_FLOOR and ReadingDoors.picker_dialog().fuzzy_match(query, text):
		score = 50
	if score > 0:
		score -= mini(text.length(), 99)
	return score


## True when a word of `text` starts with `prefix` - `set_shader_parameter` answering "shader",
## which a plain prefix test would miss and a substring test would rank no higher than a match in
## the middle of a word. Underscores and dots count as gaps, because a reader reading
## `set_shader_parameter` sees three words there whatever the character between them is.
##
## SCANNED rather than split. The obvious spelling of this - replace the gaps with spaces, split, and
## test each word - allocates two whole strings and an array of every word in the text, EVERY TIME it
## is asked. That is invisible while a rank is over forty names and is most of the cost once one is
## over thousands of sentences, which is what the Quick Add field's answers rank. A word begins where
## the text begins or just after a gap, so finding the prefix and looking at the character in front
## of it is the same question asked without building anything.
static func word_starts_with(text: String, prefix: String) -> bool:
	if prefix.is_empty():
		return false
	var at: int = text.find(prefix)
	while at >= 0:
		if at == 0:
			return true
		var before: int = text.unicode_at(at - 1)
		if before == 32 or before == 95 or before == 46:  # space, underscore, dot
			return true
		at = text.find(prefix, at + 1)
	return false


# ── Caches, and the two things that can change an answer ───────────────────────────────


## Drops what was built for one sheet. The dock calls this after an edit: a variable added, a
## function renamed or a group declared changes what a field can hold, and nothing else does.
static func invalidate(sheet: EventSheetResource) -> void:
	var prefix: String = "%d|" % [sheet.get_instance_id() if sheet != null else 0]
	for key: String in _cache.keys():
		if key.begins_with(prefix):
			_cache.erase(key)
			_cache_order.erase(key)
	for table: Dictionary in [_symbol_cache, _scope_cache]:
		for key: String in table.keys():
			if key.begins_with(prefix):
				table.erase(key)


## Drops what was built for a kind whose answer is a folder the GAME writes to while it runs, and
## does nothing for every other kind. `user://` is not the project: the filesystem ping that drops
## the project-scoped lists never fires for it, and the file a reader is completing towards is
## usually one their own last test run wrote - so a list held for the session would answer with the
## folder as it was two runs ago while its own comment claimed it was reading the folder as it
## stands. Called when a field STARTS completing, which is once per dialog rather than once per
## keystroke: the walk stays off the typing path, and each ask sees the folder it is about.
static func forget_live_folders(field_kind: String = FIELD_PATH) -> void:
	if field_kind.get_slice(":", 0) != FIELD_PATH:
		return
	for key: String in _cache.keys():
		if key.get_slice("|", 1) == FIELD_PATH:
			_cache.erase(key)
			_cache_order.erase(key)


## Drops everything. The editor's filesystem ping calls this, because a scene saved, an action
## added in Project Settings or a shader edited changes answers no sheet edit can account for.
## Tests call it between fixtures, for the same reason every other reader here exposes one.
static func clear_cache() -> void:
	_cache.clear()
	_cache_order.clear()
	_symbol_cache.clear()
	_scope_cache.clear()
	EventSheetMemberCatalog.clear_cache()


## Adds (or replaces) a source for one field kind. `source` is Callable(sheet, field_kind) and
## returns entries; it is asked BEFORE the built-in for that kind, so a pack may sharpen a kind the
## plugin already answers as well as add one it does not. The result is cached exactly like a
## built-in's, so a source is free to be slow.
static func register_source(field_kind: String, source: Callable) -> void:
	if field_kind.strip_edges().is_empty() or not source.is_valid():
		return
	_extra_sources[field_kind.strip_edges()] = source
	clear_cache()


static func unregister_source(field_kind: String) -> void:
	_extra_sources.erase(field_kind.strip_edges())
	clear_cache()


## An Array of anything shaped as a typed entry list, so a registered source may hand back a plain
## Array of Dictionaries (or of Strings, for the simplest case) without the seam's callers ever
## seeing an untyped one.
static func _typed(raw: Variant) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not (raw is Array):
		return entries
	for item: Variant in (raw as Array):
		if item is Dictionary:
			entries.append(item as Dictionary)
		elif item is String:
			entries.append({"text": str(item), "detail": "", "kind": KIND_VARIABLE})
	return entries


## The scene the node and group sources read: the injected one (tests, harnesses), else the scene
## open in the editor, else nothing.
static func _scene_root() -> Node:
	if scene_root_override != null:
		return scene_root_override
	if Engine.is_editor_hint():
		return EditorInterface.get_edited_scene_root()
	return null


## The script path a sheet's own nodes carry, which is how the scene readers find them.
static func _sheet_script_path(sheet: EventSheetResource) -> String:
	if sheet == null:
		return ""
	var path: String = sheet.external_source_path.strip_edges()
	return path if not path.is_empty() else sheet.resource_path.strip_edges()
