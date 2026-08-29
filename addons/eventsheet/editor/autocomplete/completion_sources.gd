@tool
class_name EventSheetCompletions
extends RefCounted

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
const FIELD_INPUT_ACTION := "input_action"
const FIELD_NODE := "scene_node"
const FIELD_SHADER_DIAL := "shader_dial"
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
	FIELD_FILE, "scene_path", "spawn_scene", "audio_path", "resource_path"]

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
const CACHE_LIMIT: int = 24

## How many project files the file source will hold. A file list is the one source that grows with
## the project rather than with the sheet, and a reader picking a texture is not helped by the
## ten-thousandth one.
const FILE_LIMIT: int = 4000

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
static func for_field(sheet: EventSheetResource, field_kind: String, prefix: String = "") -> Array[Dictionary]:
	var kind: String = field_kind.strip_edges()
	if kind.is_empty():
		return []
	if kind == FIELD_EXPRESSION:
		return rank(_expression_pool(sheet, prefix), trailing_word(prefix))
	return rank(_pool(sheet, kind), prefix)


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


## Builds one kind's list from scratch. A kind nobody answers comes back empty, which is what makes
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
		FIELD_INPUT_ACTION:
			return _input_action_entries()
		FIELD_NODE:
			return _node_entries()
		FIELD_SHADER_DIAL:
			return _dial_entries(sheet)
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
	return []


# ── The sources ────────────────────────────────────────────────────────────────────────
#
# Each answers one question, and each leans on the reader that already answers it elsewhere: the
# variable catalog the rows and the picker read, the Input Map read the parameter dialog shows, the
# scene readers the head bands use. Nothing here is a second opinion about anything.


## Every variable the sheet can name - its own, the globals it reaches for, the locals in view -
## inserting what the code needs (`Game.Score` keeps its prefix, a local does not) and explained by
## the same sentence its row reads with.
static func _variable_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry: Dictionary in EventSheetVariableOwners.catalog(sheet):
		entries.append({
			"text": str(entry.get("insert_text", entry.get("name", ""))),
			"detail": "%s %s %s" % [str(entry.get("owner", "")), SEPARATOR,
				EventSheetVariableOwners.sentence(entry)],
			"kind": KIND_VARIABLE,
		})
	return entries


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
		})
	return entries


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
	for member: Dictionary in EventSheetScriptMembers.methods_for(sheet, target):
		entries.append({"text": str(member["name"]),
			"detail": EventSheetScriptMembers.detail_of(member), "kind": KIND_MEMBER})
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


static func _group_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var scene_root: Node = _scene_root()
	for choice: Variant in ACEParamsDialog.group_choices(scene_root):
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
	for choice: Variant in ACEParamsDialog.input_action_choices():
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
	for path: String in ACEParamsDialog.scene_node_paths(scene_root):
		entries.append({"text": "$%s" % path, "detail": EventSheetL10n.translate("node"),
			"kind": KIND_NODE})
	for unique_name: String in ACEParamsDialog.scene_unique_names(scene_root):
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
					EventForgeShaderUniforms.reading(dial as Dictionary)],
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


## Every file under `res://` that is not the plugin's own or the engine's scratch. ONE walk, held
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
static func _expression_pool(sheet: EventSheetResource, text_before_caret: String) -> Array[Dictionary]:
	var receiver: String = member_receiver(text_before_caret)
	if not receiver.is_empty():
		var members: Array[Dictionary] = []
		for candidate: Dictionary in EventSheetGDScriptLint.dot_completion_candidates(receiver, sheet):
			members.append({"text": str(candidate.get("label", "")), "detail": receiver,
				"kind": KIND_MEMBER})
		return members
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
		return addressed
	return _pool(sheet, FIELD_EXPRESSION)


## The flat expression vocabulary: the sheet's variables, its functions, its enums, the host
## class's own members, and the language's globals. Everything a reader can say in a value field
## without reaching through a dot first.
static func _build_expression_entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var entries: Array[Dictionary] = _variable_entries(sheet)
	entries.append_array(_function_entries(sheet))
	entries.append_array(_parameter_entries(sheet))
	entries.append_array(_spawn_chip_entries(sheet))
	entries.append_array(_enum_entries(sheet, ""))
	if sheet != null and ClassDB.class_exists(sheet.host_class):
		for info: Dictionary in ClassDB.class_get_property_list(sheet.host_class):
			var property_name: String = str(info.get("name", ""))
			if property_name.is_empty() or property_name.begins_with("_") or property_name.contains("/"):
				continue
			# A property list also carries the Inspector's own furniture - the category and group
			# headings a class sorts its properties under ("Thread Group"). They are not members and
			# completing one writes a name nothing has.
			if int(info.get("usage", 0)) & (PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP):
				continue
			entries.append({"text": property_name, "detail": "%s %s %s" % [sheet.host_class,
				SEPARATOR, EventSheetL10n.translate("property")], "kind": KIND_MEMBER})
		for info: Dictionary in ClassDB.class_get_method_list(sheet.host_class):
			var method_name: String = str(info.get("name", ""))
			if method_name.is_empty() or method_name.begins_with("_"):
				continue
			entries.append({"text": "%s()" % method_name, "detail": "%s %s %s" % [sheet.host_class,
				SEPARATOR, EventSheetL10n.translate("method")], "kind": KIND_MEMBER})
	for global_name: Variant in EventSheetGDScriptLint.GDSCRIPT_GLOBAL_HINTS.keys():
		entries.append({"text": "%s()" % str(global_name),
			"detail": "%s %s %s" % [EventSheetL10n.translate("built-in"), SEPARATOR,
				str(EventSheetGDScriptLint.GDSCRIPT_GLOBAL_HINTS[global_name])],
			"kind": KIND_BUILTIN})
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
	"MakeNewCopy": "name",
	"SpawnIntoCrowd": "name",
	"SpawnIntoCrowdOldestFirst": "name",
	"SpawnIntoCrowdUnlessFull": "name",
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
static func score_of(entry: Dictionary, query: String) -> int:
	if query.is_empty():
		return 1
	var text: String = str(entry.get("text", "")).to_lower().trim_prefix("\"").trim_suffix("\"")
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
	elif query.length() >= FUZZY_FLOOR and ACEPickerDialog.fuzzy_match(query, text):
		score = 50
	if score > 0:
		score -= mini(text.length(), 99)
	return score


## True when a word of `text` starts with `prefix` - `set_shader_parameter` answering "shader",
## which a plain prefix test would miss and a substring test would rank no higher than a match in
## the middle of a word. Underscores and dots count as gaps, because a reader reading
## `set_shader_parameter` sees three words there whatever the character between them is.
static func word_starts_with(text: String, prefix: String) -> bool:
	for word: String in text.replace("_", " ").replace(".", " ").split(" ", false):
		if word.begins_with(prefix):
			return true
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


## Drops everything. The editor's filesystem ping calls this, because a scene saved, an action
## added in Project Settings or a shader edited changes answers no sheet edit can account for.
## Tests call it between fixtures, for the same reason every other reader here exposes one.
static func clear_cache() -> void:
	_cache.clear()
	_cache_order.clear()


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
