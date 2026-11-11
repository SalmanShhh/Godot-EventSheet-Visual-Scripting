# Godot EventSheets - the nine mistakes a row can make that Godot only says when the game runs.
#
# Each of these passes in silence today: the sheet compiles, the editor is content, and the mistake
# is met the first time the line is reached. Every rule here is checked against what Godot really
# does (a real run of the engine, not a belief about it), and every sentence states that and
# nothing more:
#
#   wrong node type      a row asks a node for something its class does not have. Godot stops the
#                        function with "Invalid call. Nonexistent function 'play' in base 'Label'".
#   a path that is gone  a literal res:// path nobody has. preload() of it is a parse error and the
#                        script does not load; load() prints two errors and hands back null.
#   a group nothing is   a group no scene and no script ever puts a node in. The loop over it is
#   in                   silently empty: Godot prints nothing at all.
#   a missing control    an Input Map action the project does not have. Godot prints "The InputMap
#                        action ... doesn't exist" and the control never fires.
#   a $Path not in the   a node the scene does not have. Godot prints "Node not found" and hands back
#   scene                null, so the next line that touches it stops.
#   signal value count   an emit or a handler whose number of values differs from the declaration.
#                        Parsing is fine; when it runs Godot prints "Error calling from signal" and
#                        the handler does NOT run (a handler with a default for the extra value is
#                        fine).
#   a While that cannot  nothing inside the loop can change what the condition reads, so it never
#   end                  ends and the game stops responding.
#   a local hiding a     the same name declared again inside an event. Over a sheet variable Godot
#   variable             only warns (SHADOWED_VARIABLE) and the change is made to the local; over a
#                        parameter it is a parse error and the script does not load.
#   division by a        `x / 0`: with whole numbers Godot stops the function ("Division by zero
#   literal zero         error in operator '/'"); with a decimal the answer is inf and nothing is
#                        said. `1 / 0` with literals on both sides is a parse error.
#
# THE QUIET SHEET LAW. Nothing here renders in the sheet. A finding puts the row it is about into the
# quiet state - amber for a warning, red for an error - and the words live in the help strip under
# the selected row and in the Doctor's inbox.
#
# EVIDENCE, NOT SUSPICION. A node check needs a scene that runs this script; a path check needs a
# literal path (user:// and anything built at run time is never judged); a group check looks at every
# scene and every script of the project. Where the evidence is missing the answer is nothing.
#
# WHAT IS REMEMBERED. "It is spawned / added at run time" is a fact about the game, so it is kept in
# the project (a project setting naming the sheet and the thing), never in the sheet file: a sheet
# written as a .gd must not gain a byte it did not have, and the round trip stays exact.
#
# NOTHING IS STORED IN ROWS. Every finding is derived on every ask, so a fixed row stops reporting
# with nothing to clean up. The project-wide facts (which groups exist, which paths exist) are held
# for the session and dropped when the editor says the filesystem moved.
#
# PURE + STATIC: no viewport, no dialog, no display server, so every word is pinned headless.
@tool
class_name EventSheetMistakeFindings
extends RefCounted

## The findings, by id. Frozen: the amber and red states, the strip, the Doctor and the tests address
## one by these.
const KIND_WRONG_NODE_TYPE := "wrong-node-type"
const KIND_MISSING_PATH := "path-not-in-project"
const KIND_EMPTY_GROUP := "group-nothing-is-in"
const KIND_MISSING_ACTION := "input-action-not-in-map"
const KIND_MISSING_NODE := "node-path-not-in-scene"
const KIND_EMIT_COUNT := "signal-emit-value-count"
const KIND_HANDLER_COUNT := "signal-handler-value-count"
const KIND_ENDLESS_WHILE := "while-never-ends"
const KIND_LOCAL_HIDES_VARIABLE := "local-hides-variable"
const KIND_LOCAL_HIDES_PARAMETER := "local-hides-parameter"
const KIND_DIVIDE_BY_ZERO := "divide-by-literal-zero"
const KIND_WRONG_KIND := "value-of-the-wrong-kind"

## The one-click repairs a finding offers. "" on a finding whose repair is a decision.
const FIX_USE_NAME := "use_the_name"
const FIX_POINT_AT_NODE := "point_at_node"
const FIX_ADD_ACTION := "add_input_action"
const FIX_PICK_ACTION := "pick_input_action"
const FIX_RUN_TIME := "known_at_run_time"
const FIX_STOP_AFTER := "stop_after_rounds"
const FIX_PICK_NODE := "pick_another_node"
const FIX_PICK_ROW := "pick_another_action"
const FIX_PICK_FILE := "pick_a_file"
const FIX_GROUP_ON_NODE := "add_group_to_node"
const FIX_EMIT_VALUES := "fit_emit_values"
const FIX_OPEN_SIGNAL := "open_the_signal"
const FIX_HANDLER_VALUES := "fit_handler_values"
const FIX_ADD_TO_SIGNAL := "add_to_the_signal"
const FIX_CHANGE_VARIABLE := "change_the_variable"
const FIX_MAKE_IF := "make_it_an_if"
const FIX_RENAME_LOCAL := "rename_the_local"
const FIX_REMOVE_LOCAL := "remove_the_local"
const FIX_OPEN_VALUE := "open_the_value"
const FIX_USE_VALUE := "use_the_value"
const FIX_GO_TO_VARIABLE := "go_to_the_variable"

## Where a finding hangs: under the event whose row says the mistake, or on a variable's own row.
const ANCHOR_EVENT := "event"
const ANCHOR_VARIABLE := "variable"
const ANCHOR_BLOCK := "block"

## The project setting that remembers "it is spawned / added at run time": a Dictionary of
## sheet path -> Array of "kind|subject" strings. In the project, never in the sheet file.
const REMEMBER_SETTING := "eventsheets/mistakes/known_at_run_time"

## A renamed local's new name starts with this, so "score" reads "round_score": it lasts one run of the event.
const RENAMED_LOCAL_PREFIX := "round_"

## The guard "Stop after 1000 rounds" writes, spelled once so the door, the test and the sentence agree.
const GUARD_LIMIT: int = 1000
const GUARD_COUNTER := "rounds"

## The calls that ask a group something, in the spelling a row compiles to.
const GROUP_CALLS: PackedStringArray = [
	"get_nodes_in_group", "get_first_node_in_group", "is_in_group", "call_group", "call_group_flags",
	"set_group", "set_group_flags", "notify_group", "notify_group_flags",
]

## Words that are not variables when a loop condition is read.
const CONDITION_WORDS: PackedStringArray = [
	"and", "or", "not", "in", "is", "true", "false", "null", "self", "if", "else", "as", "PI", "TAU", "INF", "NAN",
]

## The quoted-string matcher, the string-free reading of a line, and the matchers behind each rule,
## compiled once: the walk runs over every row of an opened sheet.
static var _action_regex: RegEx = null
static var _axis_regex: RegEx = null
static var _member_regex: RegEx = null
static var _added_action_regex: RegEx = null
static var _member_cache: Dictionary = {}
static var _group_regex: RegEx = null
static var _path_regex: RegEx = null
static var _node_ref_regex: RegEx = null
static var _get_node_regex: RegEx = null
static var _emit_regex: RegEx = null
static var _emit_signal_regex: RegEx = null
static var _connect_regex: RegEx = null
static var _divide_regex: RegEx = null
static var _declare_regex: RegEx = null
static var _chain_regex: RegEx = null
static var _add_group_regex: RegEx = null

## The groups the project puts nodes in, held for the session: {group name: "scene" | "script"}.
static var _project_groups: Dictionary = {}
static var _project_groups_built: bool = false

## The folders the group scan reads, or empty for the whole project (the editor's case). A test or
## a tool judging a sheet against a fixture sets it, so the scenes and scripts of the rest of the
## project cannot answer for the fixture: a project with a group "enemy" would otherwise change
## which name is nearest to a typo in a fixture that only knows "enemies".
static var _group_scan_scope: PackedStringArray = PackedStringArray()

## script path -> the scene facts that script's sheet is judged against, held for the session.
static var _scene_cache: Dictionary = {}


## Drops everything held. The editor calls this when the filesystem changes; tests call it between
## fixtures so one project's groups cannot answer for the next one's.
static func clear_cache() -> void:
	_project_groups.clear()
	_project_groups_built = false
	_scene_cache.clear()
	EventSheetTypeCheck.forget_lines()


## Limits the group scan to the scenes and scripts under these folders (res:// prefixes); an empty
## list puts the whole project back. Drops the groups held, so the next ask scans again.
static func limit_group_scan_to(folders: PackedStringArray) -> void:
	_group_scan_scope = folders
	_project_groups.clear()
	_project_groups_built = false


static func _in_group_scan_scope(path: String) -> bool:
	if _group_scan_scope.is_empty():
		return true
	for folder: String in _group_scan_scope:
		if path.begins_with(folder):
			return true
	return false


## Every mistake this sheet makes, in the order the rules run. `script_path` is the file the sheet
## lives in - it is how the scene that runs the sheet is found. A sheet with no file earns no scene
## finding, because without a scene there is no evidence.
static func findings(sheet: EventSheetResource, script_path: String = "") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if sheet == null:
		return found
	var own_path: String = script_path.strip_edges()
	if own_path.is_empty():
		own_path = sheet.external_source_path
	var walk: Dictionary = _read(sheet)
	var rows: Array[Dictionary] = walk["rows"]
	# An event with no rows yet still has a trigger: a handler's own parameters can be wrong before its first action.
	if rows.is_empty() and (walk["variable_rows"] as Array).is_empty() and (walk["events"] as Array).is_empty():
		return found
	var remembered: PackedStringArray = remembered_for(own_path)
	var scene: Dictionary = scene_facts(own_path)
	_wrong_node_types(rows, scene, walk, found)
	_missing_paths(rows, walk["variable_rows"], found)
	_empty_groups(rows, sheet, own_path, remembered, found)
	_missing_actions(rows, walk, found)
	_missing_nodes(rows, scene, remembered, found)
	_signal_counts(sheet, walk, rows, found)
	_endless_whiles(rows, walk, found)
	_hidden_locals(walk, found)
	_zero_divisions(rows, walk, found)
	_wrong_kinds(sheet, rows, scene, walk, found)
	found.append_array(EventSheetListFindings.findings(sheet, rows))
	return found


## The words after a save: how many rows cannot run or do not do what they say, and the first. ""
## when there are none.
static func summary(found: Array[Dictionary]) -> String:
	var counted: int = 0
	var first: String = ""
	for finding: Dictionary in found:
		if str(finding.get("kind", "")) == KIND_MISSING_ACTION:
			continue
		counted += 1
		if first.is_empty():
			first = str(finding.get("message", ""))
	if counted == 0:
		return ""
	return EventSheetL10n.translate("%d mistake(s) the game would only meet when it runs - the first: %s") % [counted, first]


# -- What is remembered ---------------------------------------------------------------------------


## The "kind|subject" strings this project has recorded as true at run time for one sheet.
static func remembered_for(sheet_path: String) -> PackedStringArray:
	var held: Variant = ProjectSettings.get_setting(REMEMBER_SETTING, {})
	if not (held is Dictionary) or sheet_path.is_empty():
		return PackedStringArray()
	return PackedStringArray((held as Dictionary).get(sheet_path, PackedStringArray()))


## The key a remembered fact is filed under.
static func memory_key(kind: String, subject: String) -> String:
	return "%s|%s" % [kind, subject]


## Records that a path or a group is true at run time, for one sheet. Returns true when the memory
## changed. Writes the setting only; saving project.godot is the caller's explicit step.
static func remember(sheet_path: String, kind: String, subject: String) -> bool:
	if sheet_path.is_empty() or subject.is_empty():
		return false
	var held: Variant = ProjectSettings.get_setting(REMEMBER_SETTING, {})
	var book: Dictionary = (held as Dictionary).duplicate(true) if held is Dictionary else {}
	var entries: PackedStringArray = PackedStringArray(book.get(sheet_path, PackedStringArray()))
	var key: String = memory_key(kind, subject)
	if entries.has(key):
		return false
	entries.append(key)
	entries.sort()
	book[sheet_path] = entries
	ProjectSettings.set_setting(REMEMBER_SETTING, book)
	return true


# -- The walk -------------------------------------------------------------------------------------


## Reads the sheet once: one entry per row-in-a-lane with the line it compiles to, plus the facts the
## rules share (the variables it declares, the signals, the functions). ONE walk for every rule.
static func _read(sheet: EventSheetResource) -> Dictionary:
	var walk: Dictionary = {
		"rows": [] as Array[Dictionary], "variable_rows": [], "sheet_variables": {}, "signals": {},
		"functions": {}, "connected": {}, "events": [] as Array[Dictionary], "text": "",
		"verbatim": [], "behavior": sheet.behavior_mode, "host_class": sheet.host_class, "sheet": sheet,
	}
	_collect_declarations(sheet.events, walk)
	for name_key: Variant in sheet.variables.keys():
		if not (walk["sheet_variables"] as Dictionary).has(str(name_key)):
			(walk["sheet_variables"] as Dictionary)[str(name_key)] = ""
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function != null:
			(walk["functions"] as Dictionary)[event_function.function_name.strip_edges()] = event_function
	_walk_rows(sheet.events, "", PackedStringArray(), walk)
	for entry: Variant in sheet.functions:
		var event_function: EventFunction = entry as EventFunction
		if event_function == null:
			continue
		var names: PackedStringArray = PackedStringArray()
		for parameter: Variant in event_function.params:
			var declared: ACEParam = parameter as ACEParam
			if declared != null and not declared.id.strip_edges().is_empty():
				names.append(declared.id.strip_edges())
		_walk_rows(event_function.events if not event_function.events.is_empty() else event_function.rows,
			event_function.function_name, names, walk)
	var pieces: PackedStringArray = PackedStringArray()
	for context: Dictionary in walk["rows"]:
		pieces.append(str(context.get("line", "")))
	walk["text"] = "\n".join(pieces)
	_collect_connections(walk)
	return walk


## The sheet-level variables, the signals and the verbatim function names a sheet declares, groups
## walked through.
static func _collect_declarations(items: Array, walk: Dictionary) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_collect_declarations(EventSheetGroupFacts.children(item as EventGroup), walk)
		elif item is LocalVariable:
			var variable: LocalVariable = item as LocalVariable
			(walk["sheet_variables"] as Dictionary)[variable.name.strip_edges()] = variable.type_name
			var written: String = str(variable.default_value)
			if written.contains("res://"):
				(walk["variable_rows"] as Array).append({"variable": variable, "block": null, "text": written})
		elif item is CustomBlockRow:
			# `const COIN := preload("res://scenes/coin.tscn")` lifts to a preload block.
			var block: CustomBlockRow = item as CustomBlockRow
			var path_text: String = str(block.fields.get("path", ""))
			if block.kind_id == "preload" and path_text.begins_with("res://"):
				(walk["variable_rows"] as Array).append({"variable": null, "block": block,
					"text": "preload(\"%s\")" % path_text, "name": str(block.fields.get("name", ""))})
		elif item is SignalRow:
			var declared: SignalRow = item as SignalRow
			(walk["signals"] as Dictionary)[declared.signal_name.strip_edges()] = declared.params
		elif item is RawCodeRow:
			(walk["verbatim"] as Array).append((item as RawCodeRow).code)
			for line: String in (item as RawCodeRow).code.split("\n"):
				var text: String = line.strip_edges()
				if text.begins_with("func "):
					(walk["functions"] as Dictionary)[text.substr(5).get_slice("(", 0).strip_edges()] = null


## Every action and condition of every event, with the line it compiles to and where it sits.
static func _walk_rows(items: Array, function_name: String, function_params: PackedStringArray,
		walk: Dictionary) -> void:
	for item: Variant in items:
		if item is EventGroup:
			_walk_rows(EventSheetGroupFacts.children(item as EventGroup), function_name, function_params, walk)
			continue
		var event_row: EventRow = item as EventRow
		if event_row == null or not event_row.enabled:
			continue
		_walk_event(event_row, function_name, function_params, [], walk)


static func _walk_event(event_row: EventRow, function_name: String, function_params: PackedStringArray,
		outer_locals: Array, walk: Dictionary) -> void:
	# What a trigger hands its handler is a parameter of the function it compiles to, exactly like a
	# function's own: a local of that name is the same parse error.
	var parameters: PackedStringArray = function_params
	if not event_row.trigger_id.is_empty() or not event_row.trigger_args.is_empty():
		parameters = function_params.duplicate()
		var written: String = event_row.trigger_args
		if written.strip_edges().is_empty() and not event_row.trigger_id.is_empty():
			written = str(TriggerResolver.resolve_trigger(event_row).get("args", ""))
		for piece: String in split_top_level(written):
			parameters.append(piece.get_slice("=", 0).get_slice(":", 0).strip_edges())
	var event_info: Dictionary = {
		"event": event_row, "function": function_name, "params": parameters,
		"locals": [], "outer_locals": outer_locals,
	}
	(walk["events"] as Array).append(event_info)
	for local: Variant in event_row.local_variables:
		var declared: LocalVariable = local as LocalVariable
		if declared != null:
			(event_info["locals"] as Array).append(declared.name.strip_edges())
			_add_text_row(event_row, declared, "local", -1, str(declared.default_value), walk)
	for pick_index: int in range(event_row.pick_filters.size()):
		var pick: PickFilter = event_row.pick_filters[pick_index] as PickFilter
		if pick != null and pick.enabled:
			_add_text_row(event_row, pick, "pick", pick_index, "\n".join([pick.collection_value,
				pick.source_expression, pick.predicate_expression, pick.order_by_expression]), walk)
	if event_row.trigger != null:
		_add_row(event_row, event_row.trigger, "trigger", -1, walk)
	for index: int in range(event_row.conditions.size()):
		_add_row(event_row, event_row.conditions[index], "condition", index, walk)
	# A string that runs over several verbatim blocks (GDScript allows it) is one string: the quote a
	# block leaves open is handed to the next, so the words inside it are never read as code.
	var open_quote: String = ""
	for index: int in range(event_row.actions.size()):
		var action: Variant = event_row.actions[index]
		_add_row(event_row, action, "action", index, walk, open_quote)
		if action is RawCodeRow:
			open_quote = quote_left_open((action as RawCodeRow).code, open_quote)
		var declared_name: String = _declared_local(action)
		if not declared_name.is_empty():
			(event_info["locals"] as Array).append(declared_name)
	var carried: Array = outer_locals.duplicate()
	carried.append_array(event_info["locals"] as Array)
	for child: Variant in event_row.sub_events:
		if child is EventRow and (child as EventRow).enabled:
			_walk_event(child as EventRow, function_name, parameters, carried, walk)
		elif child is EventGroup:
			_walk_rows(EventSheetGroupFacts.children(child as EventGroup), function_name, parameters, walk)


## The name a row declares as a local, or "" - the two local-variable verbs, and a verbatim `var`.
static func _declared_local(entry: Variant) -> String:
	if entry is RawCodeRow:
		for line: String in (entry as RawCodeRow).code.split("\n"):
			var text: String = line.strip_edges()
			if text.begins_with("var "):
				return text.substr(4).split(":")[0].split("=")[0].strip_edges()
		return ""
	var action: ACEAction = entry as ACEAction
	if action == null or not str(action.ace_id).begins_with("SetLocalVar"):
		return ""
	return str(_params_of(action).get("name", "")).strip_edges()


## A part of an event that is not an action or a condition but still holds code: a pick filter's
## collection, an event-level variable's starting value.
static func _add_text_row(event_row: EventRow, resource: Resource, lane: String, index: int, text: String,
		walk: Dictionary) -> void:
	if text.strip_edges().is_empty():
		return
	(walk["rows"] as Array).append({
		"event": event_row, "lane": lane, "index": index, "row": resource, "line": text, "params": {},
	})


static func _add_row(event_row: EventRow, entry: Variant, lane: String, index: int, walk: Dictionary,
		open_quote: String = "") -> void:
	var resource: Resource = entry as Resource
	if resource == null:
		return
	var enabled_value: Variant = resource.get("enabled")
	if enabled_value is bool and not bool(enabled_value):
		return
	(walk["rows"] as Array).append({
		"event": event_row, "lane": lane, "index": index, "row": resource,
		"line": open_quote + emitted_line(resource), "params": _params_of(resource),
	})


## The quote still open at the end of a block of code (`"` or `'`), or "" when every string closed.
## `open_quote` is the quote the block starts inside.
static func quote_left_open(code: String, open_quote: String = "") -> String:
	var quote: String = open_quote
	var index: int = 0
	var length: int = code.length()
	while index < length:
		var character: String = code[index]
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if character == quote:
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character == "#":
			while index < length and code[index] != "\n":
				index += 1
			continue
		index += 1
	return quote


## The line one row compiles to: the verbatim text of a block, or the template filled with the row's
## own values. The same order the compiler resolves in, so a rule can never read a different line than
## the one that gets written. A row the registry has never heard of reads as "".
static func emitted_line(entry: Variant) -> String:
	if entry is RawCodeRow:
		return (entry as RawCodeRow).code
	if entry is ACEAction:
		return ActionCodegen.generate_action(entry as ACEAction)
	if entry is ACECondition:
		return ConditionCodegen.generate_condition(entry as ACECondition)
	return ""


static func _params_of(entry: Resource) -> Dictionary:
	if entry == null:
		return {}
	var params: Variant = entry.get("params")
	if params is Dictionary and not (params as Dictionary).is_empty():
		return params as Dictionary
	var alias: Variant = entry.get("parameters")
	return alias as Dictionary if alias is Dictionary else {}


## A line without its string contents and its comment, so a rule never reads a word inside a quote
## or after a `#`. Strings keep their quotes (`""`), which is what keeps `"a" % b` apart from `%b`.
static func code_only(line: String) -> String:
	return _scan(line, false)


## A line without its comments, strings kept as written - the reading `emit_signal("name")` and
## `load("res://x")` need.
static func strip_comments(line: String) -> String:
	return _scan(line, true)


## One pass over text that knows where a string begins and ends, so a `#` inside a string is not a
## comment and a string that runs over several lines (GDScript allows it) is one string. A quote is
## closed by the same quote; a backslash keeps the next character inside.
static func _scan(text: String, keep_strings: bool) -> String:
	if not text.contains("#") and not text.contains("\"") and not text.contains("'"):
		return text
	var pieces: PackedStringArray = PackedStringArray()
	var quote: String = ""
	var index: int = 0
	var length: int = text.length()
	while index < length:
		var character: String = text[index]
		if not quote.is_empty():
			if character == "\\" and index + 1 < length:
				if keep_strings:
					pieces.append(character + text[index + 1])
				index += 2
				continue
			if character == quote:
				quote = ""
				pieces.append(character if keep_strings else "\"")
			elif keep_strings:
				pieces.append(character)
			index += 1
			continue
		if character == "\"" or character == "'":
			quote = character
			pieces.append(character if keep_strings else "\"")
		elif character == "#":
			while index < length and text[index] != "\n":
				index += 1
			continue
		else:
			pieces.append(character)
		index += 1
	return "".join(pieces)


# -- Scene facts ----------------------------------------------------------------------------------


## What the scene(s) running this script say about their nodes, or {"known": false} when no scene
## does. {"known", "scenes": [files], "tables": [{"paths": {relative path: class}, "unique": {name: class},
## "instanced": [relative path prefixes], "inherited": bool, "host_class": String}]}.
static func scene_facts(script_path: String) -> Dictionary:
	if script_path.is_empty() or not script_path.begins_with("res://"):
		return {"known": false}
	if _scene_cache.has(script_path):
		return _scene_cache[script_path]
	var facts: Dictionary = {"known": false, "scenes": [] as Array[String], "tables": []}
	var scenes: PackedStringArray = EventSheetSceneReplication.scenes_using(script_path)
	var host: String = str(EventSheetSceneReplication.host_node(script_path).get("node_path", "."))
	for scene_path: String in scenes:
		var table: Dictionary = _scene_table(scene_path, host)
		if table.is_empty():
			continue
		(facts["scenes"] as Array).append(scene_path)
		(facts["tables"] as Array).append(table)
	facts["known"] = not (facts["tables"] as Array).is_empty()
	_scene_cache[script_path] = facts
	return facts


## One scene's nodes as the script's own node sees them: paths relative to the node the script is on.
static func _scene_table(scene_path: String, host: String) -> Dictionary:
	var paths: Dictionary = {}
	var unique: Dictionary = {}
	var instanced: PackedStringArray = PackedStringArray()
	var inherited: bool = false
	var host_class: String = ""
	var scripted: Dictionary = {}
	var below: String = "%s/" % host
	for entry: Variant in EventSheetSceneConnections.nodes_of_scene(scene_path):
		var node: Dictionary = entry
		var node_path: String = str(node.get("path", ""))
		var node_class: String = str(node.get("type", ""))
		var is_instance: bool = not str(node.get("instance_path", "")).is_empty()
		if node_path == ".":
			inherited = node_class.is_empty()
		var relative: String = ""
		if node_path == host:
			relative = "."
			host_class = node_class
		elif host == ".":
			relative = node_path
		elif node_path.begins_with(below):
			relative = node_path.substr(below.length())
		if bool(node.get("unique", false)) \
				or str((node.get("properties", {}) as Dictionary).get("unique_name_in_owner", "")) == "true":
			unique[str(node.get("name", ""))] = node_class
			if not str(node.get("script_path", "")).is_empty():
				scripted["%" + str(node.get("name", ""))] = true
		if relative.is_empty():
			continue
		paths[relative] = "" if is_instance else node_class
		if is_instance:
			instanced.append(relative)
		if relative != "." and not str(node.get("script_path", "")).is_empty():
			scripted["$" + relative] = true
	return {"paths": paths, "unique": unique, "instanced": instanced, "inherited": inherited,
		"host_class": host_class, "scripted": scripted}


## True when a `$Path` / `%Name` is certainly NOT in this scene: the node is not there, no ancestor of
## it is an instanced scene (whose inside this file cannot see), and the scene is not inherited.
static func _node_missing(table: Dictionary, reference: String) -> bool:
	if bool(table.get("inherited", false)):
		return false
	if reference.begins_with("%"):
		return not (table["unique"] as Dictionary).has(reference.substr(1))
	var path: String = reference.substr(1)
	if (table["paths"] as Dictionary).has(path):
		return false
	var parts: PackedStringArray = path.split("/")
	var prefix: String = ""
	for part: String in parts:
		prefix = part if prefix.is_empty() else prefix + "/" + part
		if (table["instanced"] as PackedStringArray).has(prefix):
			return false
	return true


## The class a reference names in a table, "" when unknown (an instanced scene, a variable).
static func _class_in(table: Dictionary, reference: String) -> String:
	if reference.is_empty() or reference == "self":
		return str(table.get("host_class", ""))
	if reference.begins_with("%"):
		return str((table["unique"] as Dictionary).get(reference.substr(1), ""))
	if reference.begins_with("$"):
		return str((table["paths"] as Dictionary).get(reference.substr(1), ""))
	return ""


# -- 1. The wrong node type ------------------------------------------------------------------------


## A row built for one kind of node, pointed at a node that does not have what it asks for. The test is
## Godot's own: the row is a call or a property of the node (`{target.}play(...)`), and the node's class
## either has that member or does not. A class Godot knows, named by the scene, with no script of its
## own, is judged; a variable, a call, an instanced scene or a node with a script is left alone, because
## the member may be one the script adds.
static func _wrong_node_types(rows: Array[Dictionary], scene: Dictionary, walk: Dictionary,
		found: Array[Dictionary]) -> void:
	if not bool(scene.get("known", false)):
		return
	var seen: Dictionary = {}
	var own: Dictionary = walk["functions"].duplicate()
	own.merge(walk["sheet_variables"])
	for context: Dictionary in rows:
		var entry: Resource = context["row"] as Resource
		if not (entry is ACEAction or entry is ACECondition):
			continue
		var members: Array[Dictionary] = target_members(entry)
		if members.is_empty():
			continue
		var target: String = str((context["params"] as Dictionary).get("target", "")).strip_edges()
		if not (target.is_empty() or target == "self" or target.begins_with("$") or target.begins_with("%")):
			continue
		if target.contains(".") or target.contains("(") or target.contains("\""):
			continue
		var on_self: bool = target.is_empty() or target == "self"
		# In a behaviour sheet a row with no "On node" acts on the node the behaviour is attached to
		# (its host), not on the node the behaviour's own script sits on, and the scene cannot say which.
		if on_self and bool(walk.get("behavior", false)):
			continue
		var verdicts: Array[String] = []
		var culprit: String = ""
		var actual_class: String = ""
		for table: Dictionary in scene["tables"]:
			var actual: String = _class_in(table, target)
			if actual.is_empty() or not ClassDB.class_exists(actual) or (not on_self and _is_scripted(table, target)):
				verdicts.append("unknown")
				continue
			var lacking: String = ""
			for member: Dictionary in members:
				if on_self and own.has(str(member["name"])):
					continue
				if not class_has_member(actual, str(member["name"]), bool(member["method"])):
					lacking = str(member["name"])
					break
			verdicts.append("fits" if lacking.is_empty() else "lacks")
			if not lacking.is_empty() and culprit.is_empty():
				culprit = lacking
				actual_class = actual
		if verdicts.is_empty() or verdicts.has("unknown") or verdicts.has("fits"):
			continue
		# A row on the node itself that names a local of its body is about the local: `amount = 2` in a function
		# with `var amount` reads like a verb's "set amount", and it asks the node for nothing.
		if on_self and _is_a_local_name(culprit, walk):
			continue
		var event_row: EventRow = context["event"] as EventRow
		var key: String = "%d|%s|%s" % [event_row.get_instance_id(), target, culprit]
		if seen.has(key):
			continue
		seen[key] = true
		var node_label: String = EventSheetL10n.translate("this node") if on_self else target.substr(1)
		var better: String = "" if on_self else _node_with_members(scene["tables"][0] as Dictionary, members)
		var sentence: String
		if on_self:
			sentence = EventSheetL10n.translate("This node is a %s, which has no \"%s\" - the row asks it for one. Godot refuses the script (a parse error: not found in base self), so it does not load. Put this row on a node that has it, or pick another action.") % [actual_class, culprit]
		else:
			sentence = EventSheetL10n.translate("%s is a %s, which has no \"%s\" - the row asks it for one. Godot stops the function when the line runs (\"Invalid call. Nonexistent function\" for a method, \"Invalid assignment of property\" for a property). Point it at a node that has it, or pick another action.") % [
				node_label, actual_class, culprit]
		var doors: Array = []
		if not better.is_empty():
			var better_class: String = str((scene["tables"][0]["paths"] as Dictionary).get(better.substr(1), ""))
			doors.append([FIX_POINT_AT_NODE, EventSheetL10n.translate("Point at %s") % ("%s (%s)" % [better.substr(1), better_class])])
		if not on_self:
			doors.append([FIX_PICK_NODE, EventSheetL10n.translate("Pick another node...")])
		doors.append([FIX_PICK_ROW, EventSheetL10n.translate("Pick another action...")])
		var extra: Dictionary = {"to": better, "red": true, "member": culprit}
		extra.merge(_door_keys(doors))
		found.append(_finding(KIND_WRONG_NODE_TYPE, "error", event_row, node_label, sentence, "", "", context, extra))


## True when any body of the sheet can call something by this name: a local, a loop's item, a parameter.
static func _is_a_local_name(word: String, walk: Dictionary) -> bool:
	return (walk.get("sheet") as EventSheetResource) != null \
		and EventSheetGDScriptLint.scope_names_of(walk["sheet"] as EventSheetResource).has(word)


## The members of the node a row's template reaches through its "On node" slot: `{target.}play(&{anim})`
## asks the node for a method called play. [{"name", "method"}], empty for a row with no such slot.
static func target_members(entry: Resource) -> Array[Dictionary]:
	var members: Array[Dictionary] = []
	var template: String = str(entry.get("codegen_template"))
	if not template.contains("{target.}"):
		var descriptor: ACEDescriptor = ACERegistry.find_descriptor(str(entry.get("provider_id")), str(entry.get("ace_id")))
		template = descriptor.codegen_template if descriptor != null else ""
	if not template.contains("{target.}"):
		return members
	if _member_regex == null:
		_member_regex = RegEx.create_from_string("\\{target\\.\\}(?<member>[A-Za-z_][A-Za-z0-9_]*)(?<call>\\s*\\()?")
	for hit: RegExMatch in _member_regex.search_all(template):
		members.append({"name": hit.get_string("member"), "method": not hit.get_string("call").is_empty()})
	return members


## True when Godot's class has the method or the property. Held for the session: the answer to a
## class and a name never changes while an editor is open.
static func class_has_member(node_class: String, member: String, is_method: bool) -> bool:
	var key: String = "%s.%s" % [node_class, member]
	if _member_cache.has(key):
		return bool(_member_cache[key])
	var has: bool = ClassDB.class_has_method(node_class, member)
	if not has:
		for property: Dictionary in ClassDB.class_get_property_list(node_class):
			if str(property.get("name", "")) == member:
				has = true
				break
	_member_cache[key] = has
	return has


## True when the node the reference names has a script of its own (which may add members).
static func _is_scripted(table: Dictionary, reference: String) -> bool:
	return (table.get("scripted", {}) as Dictionary).has(reference)


## The first node of a table whose class has every member, as the reference a row writes ("$Sprite"),
## or "".
static func _node_with_members(table: Dictionary, members: Array[Dictionary]) -> String:
	for path: Variant in (table["paths"] as Dictionary).keys():
		var node_class: String = str((table["paths"] as Dictionary)[path])
		if path == "." or not ClassDB.class_exists(node_class) or _is_scripted(table, "$" + str(path)):
			continue
		var all_there: bool = true
		for member: Dictionary in members:
			if not class_has_member(node_class, str(member["name"]), bool(member["method"])):
				all_there = false
				break
		if all_there:
			return "$" + str(path)
	return ""


# -- 2. A path that does not exist -------------------------------------------------------------------


## A literal res:// path nobody has. A path that ends in a slash, has no file name, is joined to
## something with `+`, or is a format string is a path built at run time, and is never judged.
static func _missing_paths(rows: Array[Dictionary], variable_rows: Array, found: Array[Dictionary]) -> void:
	var seen: Dictionary = {}
	for context: Dictionary in rows:
		for path: String in missing_paths_in(str(context["line"])):
			var event_row: EventRow = context["event"] as EventRow
			var key: String = "%d|%s" % [event_row.get_instance_id(), path]
			if seen.has(key):
				continue
			seen[key] = true
			var closest: String = closest_file(path)
			var extra: Dictionary = {"to": closest, "red": true}
			extra.merge(_door_keys(_path_doors(closest)))
			found.append(_finding(KIND_MISSING_PATH, "error", event_row, path, path_sentence(path, closest), "", "", context, extra))
	for entry: Variant in variable_rows:
		var variable: LocalVariable = (entry as Dictionary)["variable"] as LocalVariable
		var block: CustomBlockRow = (entry as Dictionary)["block"] as CustomBlockRow
		for path: String in missing_paths_in(str((entry as Dictionary)["text"])):
			var closest: String = closest_file(path)
			var declared_here: Dictionary = {
				"kind": KIND_MISSING_PATH, "severity": "error",
				"anchor": ANCHOR_VARIABLE if variable != null else ANCHOR_BLOCK,
				"subject": variable.name.strip_edges() if variable != null else str((entry as Dictionary).get("name", "")),
				"block": block, "path": path, "message": path_sentence(path, closest),
				"to": closest, "red": true, "lane": "variable" if variable != null else "block", "index": -1,
			}
			declared_here.merge(_door_keys(_path_doors(closest)))
			found.append(declared_here)


## The doors on a missing file: its closest, when there is one, and the picker.
static func _path_doors(closest: String) -> Array:
	var doors: Array = []
	if not closest.is_empty():
		doors.append([FIX_USE_NAME, EventSheetL10n.translate("Use %s") % closest])
	doors.append([FIX_PICK_FILE, EventSheetL10n.translate("Pick a file...")])
	return doors


static func path_sentence(path: String, closest: String) -> String:
	var sentence: String = EventSheetL10n.translate("%s is not in the project. It may have been renamed or moved. preload() of it is a parse error and the script does not load; load() prints errors and returns nothing.") % path
	if not closest.is_empty():
		sentence += " " + EventSheetL10n.translate("The closest file is %s.") % closest
	return sentence


## The literal res:// file paths one line names that do not exist.
static func missing_paths_in(line: String) -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	if not line.contains("res://"):
		return missing
	# Only a path handed to a call that LOADS it is judged: the same text in a message, a table of
	# example paths or a file name written to disk is data, and says nothing about a missing file.
	if _path_regex == null:
		_path_regex = RegEx.create_from_string("\\b(?:preload|load|load_threaded_request|change_scene_to_file)\\s*\\(\\s*\"(?<path>res://[^\"\\n]*)\"(?<after>\\s*[+%])?")
	for hit: RegExMatch in _path_regex.search_all(strip_comments(line)):
		var path: String = hit.get_string("path")
		# Built at run time: joined to something, a format string, or a folder rather than a file.
		if hit.get_string("after").contains("+") \
				or hit.get_string("after").contains("%") or path.contains("%") or path.contains("{") \
				or path.contains("*") or path.ends_with("/") or path.get_extension().is_empty() \
				or path.get_file().begins_with("."):
			continue
		if not path_exists(path) and not missing.has(path):
			missing.append(path)
	return missing


## True when the project has this file, as the editor sees it: the file itself, or the resource
## Godot imported from it.
static func path_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or ResourceLoader.exists(path) or DirAccess.dir_exists_absolute(path)


## The file in the same folder whose name is closest to the missing one, or "".
static func closest_file(path: String) -> String:
	var folder: String = path.get_base_dir()
	var best: String = ""
	var best_score: float = 0.0
	for file_name: String in DirAccess.get_files_at(folder):
		if file_name.ends_with(".import") or file_name.ends_with(".uid"):
			continue
		var score: float = file_name.get_basename().similarity(path.get_file().get_basename())
		if file_name.get_extension() != path.get_extension():
			score *= 0.5
		if score > best_score:
			best_score = score
			best = folder.path_join(file_name)
	return best if best_score >= 0.4 else ""


# -- 3. A group nothing is in -------------------------------------------------------------------------


## A group no scene and no script puts a node in. Both are checked, project-wide; a name built at run
## time is never judged. A warning, because a node may join it some other way while the game runs.
static func _empty_groups(rows: Array[Dictionary], sheet: EventSheetResource, own_path: String,
		remembered: PackedStringArray, found: Array[Dictionary]) -> void:
	var seen: Dictionary = {}
	var own_groups: Dictionary = {}
	var queried: Array[Dictionary] = []
	for context: Dictionary in rows:
		var line: String = str(context["line"])
		if not line.contains("_group") and not line.contains("is_in_group"):
			continue
		for name_text: String in groups_added_in(line):
			own_groups[name_text] = true
		for name_text: String in groups_asked_in(line):
			queried.append({"context": context, "group": name_text})
	if queried.is_empty():
		return
	var known: Dictionary = project_groups()
	for entry: Dictionary in queried:
		var group_name: String = str(entry["group"])
		if known.has(group_name) or own_groups.has(group_name) or group_name.begins_with("_") \
				or remembered.has(memory_key(KIND_EMPTY_GROUP, group_name)):
			continue
		var context: Dictionary = entry["context"]
		var event_row: EventRow = context["event"] as EventRow
		var key: String = "%d|%s" % [event_row.get_instance_id(), group_name]
		if seen.has(key):
			continue
		seen[key] = true
		var closest: String = closest_name(group_name, PackedStringArray(known.keys()))
		var sentence: String = EventSheetL10n.translate("No node is in \"%s\": no scene has it and no script or sheet adds it. A loop over it does nothing and Godot prints nothing. Fine if a node joins it some other way at run time.") % group_name
		if not closest.is_empty():
			sentence += " " + EventSheetL10n.translate("Did you mean \"%s\"?") % closest
		var doors: Array = []
		if not closest.is_empty():
			doors.append([FIX_USE_NAME, EventSheetL10n.translate("Use \"%s\"") % closest])
		doors.append([FIX_GROUP_ON_NODE, EventSheetL10n.translate("Add the group to a node...")])
		doors.append([FIX_RUN_TIME, EventSheetL10n.translate("It is added at run time")])
		var extra: Dictionary = {"to": closest}
		extra.merge(_door_keys(doors))
		found.append(_finding(KIND_EMPTY_GROUP, "warning", event_row, group_name, sentence, "", "", context, extra))


## The group names a line asks about (a literal first argument of a group call).
static func groups_asked_in(line: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if _group_regex == null:
		_group_regex = RegEx.create_from_string("\\b(?<call>" + "|".join(GROUP_CALLS) + ")\\(\\s*&?[\"'](?<name>[^\"']*)[\"']")
	for hit: RegExMatch in _group_regex.search_all(line):
		var name_text: String = hit.get_string("name")
		if not name_text.is_empty() and not names.has(name_text):
			names.append(name_text)
	return names


## The group names a line puts a node in.
static func groups_added_in(line: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if _add_group_regex == null:
		_add_group_regex = RegEx.create_from_string("\\badd_to_group\\(\\s*&?[\"'](?<name>[^\"']*)[\"']")
	for hit: RegExMatch in _add_group_regex.search_all(line):
		var name_text: String = hit.get_string("name")
		if not name_text.is_empty() and not names.has(name_text):
			names.append(name_text)
	return names


## Every group the project puts nodes in: the persistent groups of every scene, every
## `add_to_group("x")` of every script, and the groups the project declares itself. Held for the
## session, so a walk of the whole project happens once and not once per edit.
static func project_groups() -> Dictionary:
	if _project_groups_built:
		return _project_groups
	var groups: Dictionary = {}
	for scene_path: String in EventSheetSceneConnections.scene_paths():
		if not _in_group_scan_scope(scene_path):
			continue
		for entry: Variant in EventSheetSceneConnections.nodes_of_scene(scene_path):
			for group_name: String in (entry as Dictionary).get("groups", PackedStringArray()):
				groups[group_name] = "scene"
	for script_path: String in preload("res://addons/eventforge/project_files.gd").all_scripts():
		if not _in_group_scan_scope(script_path):
			continue
		var source: String = FileAccess.get_file_as_string(script_path)
		if not source.contains("add_to_group"):
			continue
		for group_name: String in groups_added_in(source):
			if not groups.has(group_name):
				groups[group_name] = "script"
	var in_section: bool = false
	for line: String in FileAccess.get_file_as_string("res://project.godot").split("\n"):
		if line.begins_with("["):
			in_section = line.strip_edges() == "[global_groups]"
		elif in_section and line.contains("="):
			groups[line.get_slice("=", 0).strip_edges()] = "project"
	_project_groups = groups
	_project_groups_built = true
	return groups


## The candidate closest to a wanted name - same word in another case, a plural, a typo - or "".
static func closest_name(wanted: String, candidates: PackedStringArray) -> String:
	var best: String = ""
	var best_score: float = 0.0
	for candidate: String in candidates:
		if candidate == wanted:
			continue
		var score: float = 1.0 if candidate.to_lower() == wanted.to_lower() else wanted.to_lower().similarity(candidate.to_lower())
		if score > best_score:
			best_score = score
			best = candidate
	return best if best_score >= 0.5 else ""


# -- 4. An input action the map does not have ---------------------------------------------------------


## A control a row names that the Input Map does not have. A warning: Godot prints "The InputMap action
## ... doesn't exist" and the control never fires. The action is read from the row's line and from any
## input-action parameter of the row, trigger included.
static func _missing_actions(rows: Array[Dictionary], walk: Dictionary, found: Array[Dictionary]) -> void:
	var seen: Dictionary = {}
	var candidates: Array[Dictionary] = []
	var added_here: Dictionary = {}
	var everything: String = str(walk.get("text", "")) + "\n" + "\n".join(walk["verbatim"] as Array)
	if everything.contains("add_action"):
		if _added_action_regex == null:
			_added_action_regex = RegEx.create_from_string("\\badd_action\\(\\s*&?\"(?<name>[^\"]+)\"")
		for hit: RegExMatch in _added_action_regex.search_all(everything):
			added_here[hit.get_string("name")] = true
	for context: Dictionary in rows:
		for name_text: String in actions_in(str(context["line"])):
			if not added_here.has(name_text):
				candidates.append({"context": context, "action": name_text})
		var entry: Resource = context["row"] as Resource
		if not (entry is ACEAction or entry is ACECondition):
			continue
		# A row about the map itself (has_action, add_action) asks or defines; it does not use a control.
		if str(context["line"]).contains("InputMap."):
			continue
		for named: String in _input_parameters(str(entry.get("provider_id")), str(entry.get("ace_id")), context["params"] as Dictionary):
			candidates.append({"context": context, "action": named})
	for event_info: Dictionary in walk["events"]:
		var trigger_event: EventRow = event_info["event"] as EventRow
		if trigger_event.trigger_id.is_empty():
			continue
		var carried: Dictionary = {"event": trigger_event, "lane": "trigger", "index": -1, "row": trigger_event.trigger, "line": "", "params": trigger_event.trigger_params}
		for named: String in _input_parameters(trigger_event.trigger_provider_id, trigger_event.trigger_id, trigger_event.trigger_params):
			candidates.append({"context": carried, "action": named})
	var known: PackedStringArray = EventSheetInputMapFacts.project_action_names()
	for entry: Dictionary in candidates:
		var action_name: String = str(entry["action"])
		if EventSheetInputMapFacts.has_action(action_name):
			continue
		var context: Dictionary = entry["context"]
		var event_row: EventRow = context["event"] as EventRow
		var key: String = "%d|%s" % [event_row.get_instance_id(), action_name]
		if seen.has(key):
			continue
		seen[key] = true
		var closest: String = closest_name(action_name, known)
		var sentence: String = EventSheetL10n.translate("\"%s\" is not in the Input Map, so the control never fires; Godot prints \"The InputMap action doesn't exist\" when the line runs. Names are case-sensitive.") % action_name
		if not closest.is_empty():
			sentence += " " + EventSheetL10n.translate("The map has \"%s\".") % closest
		found.append(_finding(KIND_MISSING_ACTION, "warning", event_row, action_name, sentence,
			FIX_USE_NAME if not closest.is_empty() else FIX_ADD_ACTION,
			EventSheetL10n.translate("Use \"%s\"") % closest if not closest.is_empty() else EventSheetL10n.translate("Add \"%s\" to the Input Map") % action_name,
			context, {"to": closest,
				"second_fix": FIX_ADD_ACTION if not closest.is_empty() else FIX_PICK_ACTION,
				"second_fix_label": EventSheetL10n.translate("Add \"%s\" to the Input Map") % action_name if not closest.is_empty() else EventSheetL10n.translate("Pick an existing action..."),
				"third_fix": FIX_PICK_ACTION if not closest.is_empty() else "",
				"third_fix_label": EventSheetL10n.translate("Pick an existing action...") if not closest.is_empty() else ""}))


## The controls one line asks about: the quoted first argument of a call that reads an action
## (`is_action_pressed("jump")`, `get_action_strength(...)`), and the quoted arguments of `get_axis` /
## `get_vector`. Any other string on the line, even one beside an `Input.` call, is not a control,
## and a name the line only ASKS the map about (`InputMap.has_action("x")`) is a guard, not a use.
static func actions_in(line: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if not line.contains("action") and not line.contains("get_axis") and not line.contains("get_vector"):
		return names
	if _action_regex == null:
		_action_regex = RegEx.create_from_string("\\b(?:is_action_pressed|is_action_released|is_action_just_pressed|is_action_just_released|is_action|get_action_strength|get_action_raw_strength|action_press|action_release)\\(\\s*&?\"(?<name>[^\"]+)\"")
		_axis_regex = RegEx.create_from_string("\\b(?:get_axis|get_vector)\\((?<args>[^)]*)\\)")
	var plain: String = strip_comments(line)
	for hit: RegExMatch in _action_regex.search_all(plain):
		var name_text: String = hit.get_string("name")
		if not names.has(name_text):
			names.append(name_text)
	for hit: RegExMatch in _axis_regex.search_all(plain):
		for piece: String in split_top_level(hit.get_string("args")):
			var written: String = piece.trim_prefix("&")
			if written.length() >= 3 and written.begins_with("\"") and written.ends_with("\""):
				var name_text: String = written.substr(1, written.length() - 2)
				if not names.has(name_text):
					names.append(name_text)
	return names


## The action names a row's own input-action parameters hold (quoted, as written).
static func _input_parameters(provider_id: String, ace_id: String, params: Dictionary) -> PackedStringArray:
	var named: PackedStringArray = PackedStringArray()
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor(provider_id, ace_id)
	if descriptor == null:
		return named
	for parameter: ACEParam in descriptor.params:
		if parameter == null or parameter.hint != "input_action":
			continue
		var written: String = str(params.get(parameter.id, "")).strip_edges()
		if written.length() >= 3 and (written.begins_with("\"") or written.begins_with("&\"")) and written.ends_with("\""):
			var plain: String = written.trim_prefix("&").substr(1, written.trim_prefix("&").length() - 2)
			if not plain.is_empty() and not named.has(plain):
				named.append(plain)
	return named


# -- 5. A $Path that is not in the scene ----------------------------------------------------------------


## A `$Path` or `%Name` the scene does not have. A warning: the node may be spawned while the game
## runs. Godot prints "Node not found" and hands back null, so the next line that touches it stops.
static func _missing_nodes(rows: Array[Dictionary], scene: Dictionary, remembered: PackedStringArray,
		found: Array[Dictionary]) -> void:
	if not bool(scene.get("known", false)):
		return
	var seen: Dictionary = {}
	var tables: Array = scene["tables"]
	var text_all: String = ""
	for context: Dictionary in rows:
		text_all += str(context["line"]) + "\n"
	for context: Dictionary in rows:
		var line: String = str(context["line"])
		if not (line.contains("$") or line.contains("%") or line.contains("get_node")):
			continue
		for reference: String in node_references_in(line):
			var missing_everywhere: bool = true
			for table: Dictionary in tables:
				if not _node_missing(table, reference):
					missing_everywhere = false
					break
			if not missing_everywhere:
				continue
			var plain: String = reference.substr(1)
			# A name the sheet itself sets on a node (`node.name = "Enmy"`) is made at run time.
			if text_all.contains("\"" + plain.get_file() + "\"") or remembered.has(memory_key(KIND_MISSING_NODE, reference)):
				continue
			var event_row: EventRow = context["event"] as EventRow
			var key: String = "%d|%s" % [event_row.get_instance_id(), reference]
			if seen.has(key):
				continue
			seen[key] = true
			var names: PackedStringArray = PackedStringArray()
			for path: Variant in (tables[0]["paths"] as Dictionary).keys():
				names.append(str(path).get_file())
			var closest: String = closest_name(plain.get_file(), names)
			var scene_file: String = str((scene["scenes"] as Array)[0]).get_file()
			var sentence: String = EventSheetL10n.translate("There is no node %s in %s. Godot prints \"Node not found\" and hands back nothing, so the next line that uses it stops. Fine if it is spawned at run time.") % [reference, scene_file]
			var better: String = ""
			if not closest.is_empty():
				better = "%" + closest if reference.begins_with("%") else _reference_to(tables[0] as Dictionary, closest)
				sentence += " " + EventSheetL10n.translate("Did you mean %s?") % better
			found.append(_finding(KIND_MISSING_NODE, "warning", event_row, reference, sentence,
				FIX_USE_NAME if not better.is_empty() else FIX_RUN_TIME,
				EventSheetL10n.translate("Use %s") % better if not better.is_empty() else EventSheetL10n.translate("It is spawned at run time"),
				context, {"to": better, "second_fix": FIX_RUN_TIME if not better.is_empty() else "",
					"second_fix_label": EventSheetL10n.translate("It is spawned at run time") if not better.is_empty() else ""}))


## The reference a row writes for the node of a given name in a table: "$Enemy" or "$Group/Enemy".
static func _reference_to(table: Dictionary, node_name: String) -> String:
	for path: Variant in (table["paths"] as Dictionary).keys():
		if str(path).get_file() == node_name:
			return "$" + str(path)
	return "$" + node_name


## The plain node references one line makes: `$Name`, `$A/B`, `%Name`, and `get_node("A/B")`. Quoted
## forms, `$"My Node"`, are left alone, and so is `%` used as an operator or inside a string.
static func node_references_in(line: String) -> PackedStringArray:
	var references: PackedStringArray = PackedStringArray()
	if _node_ref_regex == null:
		_node_ref_regex = RegEx.create_from_string("(?<![\\w\\)\\]\"'])(?<sigil>[$%])(?<path>[A-Za-z_][A-Za-z0-9_]*(?:/[A-Za-z_][A-Za-z0-9_]*)*)")
		_get_node_regex = RegEx.create_from_string("\\bget_node\\(\\s*[\"'](?<path>[A-Za-z_][A-Za-z0-9_]*(?:/[A-Za-z_][A-Za-z0-9_]*)*)[\"']\\s*\\)")
	var plain: String = code_only(line)
	for hit: RegExMatch in _node_ref_regex.search_all(plain):
		var reference: String = hit.get_string("sigil") + hit.get_string("path")
		# A percent after a value is the modulo operator: `a %b` is not a reference.
		var before: String = plain.substr(0, hit.get_start()).strip_edges(false, true)
		if hit.get_string("sigil") == "%" and not before.is_empty() \
				and not "=(,[{:+-*/<>!&|".contains(before.substr(before.length() - 1)) \
				and not before.ends_with("return") and not before.ends_with("and") and not before.ends_with("or") \
				and not before.ends_with("in") and not before.ends_with("not"):
			continue
		if not references.has(reference):
			references.append(reference)
	for hit: RegExMatch in _get_node_regex.search_all(line):
		var reference: String = "$" + hit.get_string("path")
		if not references.has(reference):
			references.append(reference)
	return references


# -- 6. Signals with the wrong number of values ------------------------------------------------------------


## An emit or a handler whose number of values differs from the signal's declaration. Signals the sheet
## declares are compared with the declaration row; a signal of the host class with Godot's own.
static func _signal_counts(sheet: EventSheetResource, walk: Dictionary, rows: Array[Dictionary],
		found: Array[Dictionary]) -> void:
	var declared: Dictionary = walk["signals"]
	var seen: Dictionary = {}
	for context: Dictionary in rows:
		var line: String = strip_comments(str(context["line"]))
		if not (line.contains(".emit(") or line.contains("emit_signal(")):
			continue
		for emitted: Dictionary in emits_in(line):
			var signal_name: String = str(emitted["signal"])
			var expected: Array = signal_values(signal_name, declared, sheet.host_class)
			if expected.is_empty():
				continue
			var sent: int = int(emitted["count"])
			if sent == int(expected[0]):
				continue
			var event_row: EventRow = context["event"] as EventRow
			var key: String = "%d|%s|%d" % [event_row.get_instance_id(), signal_name, sent]
			if seen.has(key):
				continue
			seen[key] = true
			var extra: Dictionary = {"red": true, "signal": signal_name, "sent": sent, "wanted": int(expected[0]),
				"wanted_names": signal_parameters(signal_name, declared, sheet.host_class)}
			extra.merge(_door_keys(_emit_doors(extra, declared.has(signal_name))))
			found.append(_finding(KIND_EMIT_COUNT, "error", event_row, signal_name,
				EventSheetL10n.translate("%s sends %s, and this emits it with %s. Nothing is said while no handler is connected; once one is, Godot prints \"Error calling from signal\" and the handler does not run.") % [
					signal_name, values_phrase(int(expected[0]), str(expected[1])), values_phrase(sent, "")],
				"", "", context, extra))
	for event_info: Dictionary in walk["events"]:
		var event_row: EventRow = event_info["event"] as EventRow
		var trigger_id: String = event_row.trigger_id
		if not trigger_id.begins_with("signal:"):
			continue
		var signal_name: String = trigger_id.substr(7)
		var expected: Array = signal_values(signal_name, declared, sheet.host_class)
		if expected.is_empty():
			continue
		var handled: Array = handler_values(event_row.trigger_args)
		if int(expected[0]) >= int(handled[0]) and int(expected[0]) <= int(handled[1]):
			continue
		var extra: Dictionary = {"red": true, "signal": signal_name}
		extra.merge(_door_keys(_handler_doors(event_row, signal_name, declared, sheet.host_class, extra)))
		found.append(_finding(KIND_HANDLER_COUNT, "error", event_row, signal_name,
			handler_sentence(signal_name, int(expected[0]), str(expected[1]), handled, event_row.trigger_args),
			"", "", {"lane": "trigger", "index": -1}, extra))
	# A function connected by hand: `hit.connect(_on_hit)` in a verbatim block.
	var functions: Dictionary = walk["functions"]
	for connection: Dictionary in walk["connected"].values():
		var signal_name: String = str(connection["signal"])
		var handler: Variant = functions.get(str(connection["handler"]), null)
		if not (handler is EventFunction):
			continue
		var expected: Array = signal_values(signal_name, declared, sheet.host_class)
		if expected.is_empty():
			continue
		var names: PackedStringArray = PackedStringArray()
		var minimum: int = 0
		for parameter: Variant in (handler as EventFunction).params:
			var declared_param: ACEParam = parameter as ACEParam
			if declared_param == null:
				continue
			names.append(declared_param.id)
			var has_default: bool = not declared_param.default_spelling.strip_edges().is_empty() \
				or not declared_param.gdscript_default.strip_edges().is_empty() \
				or not str(declared_param.default_value).strip_edges().is_empty()
			if not has_default:
				minimum += 1
		var handled: Array = [minimum, names.size()]
		if int(expected[0]) >= minimum and int(expected[0]) <= names.size():
			continue
		var body: Array = (handler as EventFunction).events if not (handler as EventFunction).events.is_empty() else (handler as EventFunction).rows
		var anchor: EventRow = null
		for step: Variant in body:
			if step is EventRow:
				anchor = step as EventRow
				break
		if anchor == null:
			continue
		found.append(_finding(KIND_HANDLER_COUNT, "error", anchor, signal_name,
			handler_sentence(signal_name, int(expected[0]), str(expected[1]), handled, ", ".join(names)),
			"", "", {"lane": "trigger", "index": -1}, {"red": true}))


## The doors on an emit with the wrong count: the values it lacks by their names, or the ones it has too
## many of, and the row that declares the signal. A value is only added or removed where the row says emit.
static func _emit_doors(extra: Dictionary, declared_here: bool) -> Array:
	var doors: Array = []
	var sent: int = int(extra["sent"])
	var wanted: PackedStringArray = extra["wanted_names"]
	if sent < wanted.size():
		var names: PackedStringArray = PackedStringArray()
		for index: int in range(sent, wanted.size()):
			names.append(wanted[index].get_slice(":", 0).strip_edges())
		doors.append([FIX_EMIT_VALUES, EventSheetL10n.translate("Add %s") % ", ".join(names)])
	elif sent > wanted.size():
		doors.append([FIX_EMIT_VALUES, EventSheetL10n.translate("Remove the extra value")])
	if declared_here:
		doors.append([FIX_OPEN_SIGNAL, EventSheetL10n.translate("Open the signal")])
	return doors


## The doors on a handler whose values do not match its signal: take off what the body does not read and
## add to the signal what it lacks, or take from the signal what the handler lacks. `extra` is told what each
## door writes, worked out here so the door never has to read a label.
static func _handler_doors(event_row: EventRow, signal_name: String, declared: Dictionary, host_class: String, extra: Dictionary) -> Array:
	var doors: Array = []
	var pieces: PackedStringArray = split_top_level(event_row.trigger_args)
	var wanted: PackedStringArray = signal_parameters(signal_name, declared, host_class)
	if pieces.size() > wanted.size():
		var over: PackedStringArray = pieces.slice(wanted.size())
		var over_names: PackedStringArray = PackedStringArray()
		var body: String = code_only(body_text(event_row))
		for condition: Variant in event_row.conditions:
			body += "\n" + code_only(emitted_line(condition))
		var read_in_body: bool = false
		for piece: String in over:
			var word: String = piece.get_slice("=", 0).get_slice(":", 0).strip_edges()
			over_names.append(word)
			read_in_body = read_in_body or _has_word(body, word)
		var names_text: String = ", ".join(over_names)
		if not read_in_body:
			extra["handler_args"] = ", ".join(pieces.slice(0, wanted.size()))
			doors.append([FIX_HANDLER_VALUES, EventSheetL10n.translate("Drop %s") % names_text])
		if declared.has(signal_name):
			var widened: PackedStringArray = wanted.duplicate()
			widened.append_array(over)
			extra["signal_params"] = widened
			doors.append([FIX_ADD_TO_SIGNAL, EventSheetL10n.translate("Add %s to the signal") % names_text])
	elif pieces.size() < wanted.size():
		var lacking: PackedStringArray = wanted.slice(pieces.size())
		var lacking_names: PackedStringArray = PackedStringArray()
		for piece: String in lacking:
			lacking_names.append(piece.get_slice(":", 0).strip_edges())
		var taken: PackedStringArray = pieces.duplicate()
		taken.append_array(lacking)
		extra["handler_args"] = ", ".join(taken)
		doors.append([FIX_HANDLER_VALUES, EventSheetL10n.translate("Add %s") % ", ".join(lacking_names)])
	if declared.has(signal_name) and pieces.size() <= wanted.size():
		doors.append([FIX_OPEN_SIGNAL, EventSheetL10n.translate("Open the signal")])
	return doors


## A signal's values as they are declared ("damage: int"), in order.
static func signal_parameters(signal_name: String, declared: Dictionary, host_class: String) -> PackedStringArray:
	if declared.has(signal_name):
		return PackedStringArray(declared[signal_name])
	var names: PackedStringArray = PackedStringArray()
	if not host_class.is_empty() and ClassDB.class_exists(host_class):
		for entry: Dictionary in ClassDB.class_get_signal_list(host_class):
			if str(entry.get("name", "")) == signal_name:
				for argument: Dictionary in entry.get("args", []):
					names.append(str(argument.get("name", "")))
	return names


## [count, "(damage: int)" phrase] for a signal, or [] when it is not a signal this sheet can compare.
static func signal_values(signal_name: String, declared: Dictionary, host_class: String) -> Array:
	if declared.has(signal_name):
		var params: PackedStringArray = declared[signal_name]
		return [params.size(), "(" + ", ".join(params) + ")" if params.size() > 0 else ""]
	if not host_class.is_empty() and ClassDB.class_exists(host_class) and ClassDB.class_has_signal(host_class, signal_name):
		for entry: Dictionary in ClassDB.class_get_signal_list(host_class):
			if str(entry.get("name", "")) == signal_name:
				var names: PackedStringArray = PackedStringArray()
				for argument: Dictionary in entry.get("args", []):
					names.append(str(argument.get("name", "")))
				return [names.size(), "(" + ", ".join(names) + ")" if names.size() > 0 else ""]
	return []


static func values_phrase(count: int, detail: String) -> String:
	var words: String = EventSheetL10n.translate("no values") if count == 0 else (
		EventSheetL10n.translate("1 value") if count == 1 else EventSheetL10n.translate("%d values") % count)
	return words if detail.is_empty() else "%s %s" % [words, detail]


## [fewest, most] values a handler written as "damage: int, source: Node = null" accepts.
static func handler_values(args: String) -> Array:
	var pieces: PackedStringArray = split_top_level(args)
	var minimum: int = 0
	for piece: String in pieces:
		if not piece.contains("="):
			minimum += 1
	return [minimum, pieces.size()]


static func handler_sentence(signal_name: String, sent: int, detail: String, handled: Array, written: String) -> String:
	var takes: String = values_phrase(int(handled[1]), "(%s)" % written.strip_edges() if not written.strip_edges().is_empty() else "")
	return EventSheetL10n.translate("The handler takes %s, and %s sends %s. When it is emitted Godot prints \"Error calling from signal\" and the handler does not run.") % [
		takes, signal_name, values_phrase(sent, detail)]


## Every emit one line makes, as {"signal", "count"}: `name.emit(a, b)` and `emit_signal("name", a, b)`.
static func emits_in(line: String) -> Array[Dictionary]:
	var emitted: Array[Dictionary] = []
	if _emit_regex == null:
		_emit_regex = RegEx.create_from_string("(?<![\\w.])(?<signal>[A-Za-z_][A-Za-z0-9_]*)\\.emit\\(")
		_emit_signal_regex = RegEx.create_from_string("\\bemit_signal\\(\\s*\"(?<signal>[A-Za-z_][A-Za-z0-9_]*)\"")
	for hit: RegExMatch in _emit_regex.search_all(line):
		emitted.append({"signal": hit.get_string("signal"), "count": split_top_level(_balanced_after(line, hit.get_end() - 1)).size()})
	for hit: RegExMatch in _emit_signal_regex.search_all(line):
		var rest: PackedStringArray = split_top_level(_balanced_after(line, line.find("(", hit.get_start())))
		emitted.append({"signal": hit.get_string("signal"), "count": maxi(rest.size() - 1, 0)})
	return emitted


## The text between the bracket at `open_at` and its partner, or "" when it never closes.
static func _balanced_after(text: String, open_at: int) -> String:
	var depth: int = 0
	var quote: String = ""
	for index: int in range(open_at, text.length()):
		var character: String = text[index]
		if not quote.is_empty():
			if character == quote and text[index - 1] != "\\":
				quote = ""
			continue
		if character == "\"" or character == "'":
			quote = character
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
			if depth == 0:
				return text.substr(open_at + 1, index - open_at - 1)
	return ""


## The pieces of a comma list, ignoring commas inside brackets and quotes. "" is no pieces at all.
static func split_top_level(text: String) -> PackedStringArray:
	var pieces: PackedStringArray = PackedStringArray()
	if text.strip_edges().is_empty():
		return pieces
	var depth: int = 0
	var quote: String = ""
	var current: String = ""
	for index: int in range(text.length()):
		var character: String = text[index]
		if not quote.is_empty():
			current += character
			if character == quote and text[index - 1] != "\\":
				quote = ""
			continue
		if character == "\"" or character == "'":
			quote = character
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		if character == "," and depth == 0:
			pieces.append(current.strip_edges())
			current = ""
			continue
		current += character
	pieces.append(current.strip_edges())
	return pieces


## Handlers connected by hand: `signal.connect(handler)` with a plain function name.
static func _collect_connections(walk: Dictionary) -> void:
	if _connect_regex == null:
		_connect_regex = RegEx.create_from_string("(?<![\\w.])(?<signal>[A-Za-z_][A-Za-z0-9_]*)\\.connect\\(\\s*(?<handler>[A-Za-z_][A-Za-z0-9_]*)\\s*\\)")
	var text: String = str(walk.get("text", ""))
	for source: String in walk["verbatim"] as Array:
		text += "\n" + source
	var connected: Dictionary = walk["connected"]
	for hit: RegExMatch in _connect_regex.search_all(text):
		connected["%s>%s" % [hit.get_string("signal"), hit.get_string("handler")]] = {
			"signal": hit.get_string("signal"), "handler": hit.get_string("handler")}


# -- 7. A While that cannot end -------------------------------------------------------------------------


## A While whose body changes nothing its condition reads. Quiet when the body calls a function of the
## sheet, awaits, or stops the loop - the check cannot see inside those, so it does not guess.
static func _endless_whiles(rows: Array[Dictionary], walk: Dictionary, found: Array[Dictionary]) -> void:
	for event_info: Dictionary in walk["events"]:
		var event_row: EventRow = event_info["event"] as EventRow
		for pick_index: int in range(event_row.pick_filters.size()):
			var pick: PickFilter = event_row.pick_filters[pick_index] as PickFilter
			if pick == null or not pick.enabled or pick.collection_kind != PickFilter.CollectionKind.WHILE:
				continue
			var condition: String = pick.collection_value.strip_edges()
			var body: String = body_text(event_row)
			if not loop_cannot_end(condition, body, walk["functions"], str(walk.get("host_class", ""))):
				continue
			var reads: PackedStringArray = condition_chains(condition)
			var read_names: PackedStringArray = PackedStringArray()
			for chain: String in reads:
				read_names.append(chain)
			var subject: String = condition
			var extra: Dictionary = {}
			var doors: Array = []
			var change: Dictionary = change_that_ends(condition)
			if not change.is_empty():
				extra["change"] = change
				doors.append([FIX_CHANGE_VARIABLE, str(change["label"])])
			doors.append([FIX_STOP_AFTER, EventSheetL10n.translate("Stop after %d rounds") % GUARD_LIMIT])
			doors.append([FIX_MAKE_IF, EventSheetL10n.translate("Make it an If")])
			extra.merge(_door_keys(doors))
			found.append(_finding(KIND_ENDLESS_WHILE, "warning", event_row, subject,
				EventSheetL10n.translate("Nothing inside this While changes what \"%s\" reads (%s). Once it is true it stays true, so the loop never ends and the game stops responding. Change one of them inside it, add a stop, or make it an If.") % [
					condition, ", ".join(read_names) if not read_names.is_empty() else condition],
				"", "", {"lane": "pick", "index": pick_index}, extra))


## The one row that would end a loop on a plain comparison of a variable: `lives > 0` counts down, `lives < 9`
## counts up. {} for any other shape, where which way is the right way is the reader's to say.
static func change_that_ends(condition: String) -> Dictionary:
	var found: RegExMatch = RegEx.create_from_string("^(?<name>[A-Za-z_][A-Za-z0-9_]*)\\s*(?<op>>=|<=|>|<)\\s*[-A-Za-z0-9_.]+$").search(condition)
	if found == null or CONDITION_WORDS.has(found.get_string("name")):
		return {}
	var name_text: String = found.get_string("name")
	if found.get_string("op").begins_with(">"):
		return {"ace_id": "SubtractVar", "name": name_text, "label": EventSheetL10n.translate("Add: Subtract 1 from %s") % name_text}
	return {"ace_id": "AddVar", "name": name_text, "label": EventSheetL10n.translate("Add: Add 1 to %s") % name_text}


## Every line the body of an event compiles to, sub-events included.
static func body_text(event_row: EventRow) -> String:
	var pieces: PackedStringArray = PackedStringArray()
	for action: Variant in event_row.actions:
		if action is Resource and not (action.get("enabled") is bool and not bool(action.get("enabled"))):
			pieces.append(emitted_line(action))
	for child: Variant in event_row.sub_events:
		if child is EventRow:
			for condition: Variant in (child as EventRow).conditions:
				pieces.append(emitted_line(condition))
			pieces.append(body_text(child as EventRow))
		elif child is EventGroup:
			for nested: Variant in EventSheetGroupFacts.children(child as EventGroup):
				if nested is EventRow:
					pieces.append(body_text(nested as EventRow))
	return "\n".join(pieces)


## True when a loop condition cannot change while its body runs. The body is judged by its code.
static func loop_cannot_end(condition: String, body: String, sheet_functions: Dictionary, host_class: String = "") -> bool:
	if condition.is_empty():
		return false
	var plain_body: String = code_only(body)
	# The body stops the loop, waits for the frame, or runs something this check cannot see inside.
	for word: String in ["break", "return", "await ", "await(", "yield"]:
		if _has_word(plain_body, word.strip_edges()):
			return false
	for function_name: Variant in sheet_functions.keys():
		if not str(function_name).is_empty() and plain_body.contains(str(function_name) + "("):
			return false
	# So is a method of the sheet's own node (`move_and_slide()`, a project class's own): it can change
	# whatever the condition reads. A call on another node, or one of the language's own, cannot reach a
	# plain variable of this sheet.
	if _calls_its_own_node(plain_body, host_class):
		return false
	if plain_body.contains(".emit(") or plain_body.contains(".call(") or plain_body.contains("emit_signal(") \
			or plain_body.contains("call_deferred(") or plain_body.contains(".connect("):
		return false
	# A call in the condition (`not queue.is_empty()`, `randf() > 0.1`) reads state this check cannot
	# follow, and so does a node, a singleton or a class (`$Timer.time_left`, `Time`): they move on
	# their own. Only plain names the sheet itself can change are judged.
	if code_only(condition).contains("("):
		return false
	var chains: PackedStringArray = condition_chains(condition)
	for chain: String in chains:
		var first: String = chain.substr(0, 1)
		if first == "$" or first == "%" or first.to_upper() == first and first.to_lower() != first:
			return false
	for chain: String in chains:
		if body_changes(plain_body, chain):
			return false
	return true


## True when a body calls something on `self` the check cannot see inside: a bare call that is a method of the
## host class, or any bare call at all under a host Godot does not know (a project class of unknown members).
## The language's own functions (print, str, randf...) are in neither.
static func _calls_its_own_node(plain_body: String, host_class: String) -> bool:
	var native: bool = ClassDB.class_exists(host_class)
	for hit: RegExMatch in RegEx.create_from_string("(?<![\\w.$%])(?<name>[A-Za-z_][A-Za-z0-9_]*)\\s*\\(").search_all(plain_body):
		var called: String = hit.get_string("name")
		if native:
			if ClassDB.class_has_method(host_class, called):
				return true
		elif not host_class.is_empty() and not _is_language_call(called):
			return true
	return false


## True for a name the language itself answers: a utility function or a type's constructor.
static func _is_language_call(called: String) -> bool:
	return EventSheetGDScriptLint.GDSCRIPT_GLOBAL_HINTS.has(called) or called in ["print", "printerr", "push_error", "push_warning", "range", "len", "typeof", "assert", "print_rich", "print_debug", "preload", "load"] \
		or EventSheetGDScriptLint.VALUE_TYPE_NAMES.has(called) or ClassDB.class_exists(called)


## True when a body writes the chain (`lives`, `player.hp`), a part of it, or calls a method on its root.
static func body_changes(plain_body: String, chain: String) -> bool:
	var root: String = chain.split(".")[0].split("[")[0]
	var escaped: String = root.replace("$", "\\$").replace("%", "\\%")
	var assign: RegEx = RegEx.create_from_string("(?<![\\w])" + escaped + "(?:\\s*\\[[^\\]]*\\]|\\.[A-Za-z_][A-Za-z0-9_]*)*\\s*(?:[-+*/%|&^]|<<|>>|\\*\\*)?=(?!=)")
	if assign.search(plain_body) != null:
		return true
	var method: RegEx = RegEx.create_from_string("(?<![\\w])" + escaped + "(?:\\.[A-Za-z_][A-Za-z0-9_]*)*\\.[A-Za-z_][A-Za-z0-9_]*\\(")
	return method.search(plain_body) != null


static func _has_word(text: String, word: String) -> bool:
	var at: int = text.find(word)
	while at >= 0:
		var before_ok: bool = at == 0 or not (text[at - 1].is_valid_identifier() or text[at - 1] == "_")
		var after: int = at + word.length()
		var after_ok: bool = after >= text.length() or not (text[after].is_valid_identifier() or text[after] == "_" or text[after].is_valid_int())
		if before_ok and after_ok:
			return true
		at = text.find(word, at + 1)
	return false


## What a loop condition reads: its variable names and node paths, each as written ("lives",
## "player.hp", "queue.is_empty()"). Words, numbers and operators are not variables.
static func condition_chains(condition: String) -> PackedStringArray:
	if _chain_regex == null:
		_chain_regex = RegEx.create_from_string("(?<![\\w.])[$%]?[A-Za-z_][A-Za-z0-9_]*(?:(?:\\.[A-Za-z_][A-Za-z0-9_]*)|(?:/[A-Za-z_][A-Za-z0-9_]*))*(?:\\(\\))?")
	var chains: PackedStringArray = PackedStringArray()
	for hit: RegExMatch in _chain_regex.search_all(code_only(condition)):
		var chain: String = hit.get_string()
		if CONDITION_WORDS.has(chain) or chains.has(chain):
			continue
		chains.append(chain)
	return chains


# -- 8. A local hiding a variable ----------------------------------------------------------------------------


## A local declared in an event with the name of a sheet variable (a warning: the change is made to
## the local) or of its function's parameter (an error: Godot refuses the script).
static func _hidden_locals(walk: Dictionary, found: Array[Dictionary]) -> void:
	var variables: Dictionary = walk["sheet_variables"]
	for event_info: Dictionary in walk["events"]:
		var event_row: EventRow = event_info["event"] as EventRow
		for local_name: String in event_info["locals"] as Array:
			if local_name.is_empty():
				continue
			if (event_info["params"] as PackedStringArray).has(local_name):
				var extra: Dictionary = {"red": true}
				extra.merge(_local_doors(event_row, local_name, variables, event_info,
					EventSheetL10n.translate("Remove the local (use the parameter %s)") % local_name, extra))
				found.append(_finding(KIND_LOCAL_HIDES_PARAMETER, "error", event_row, local_name,
					EventSheetL10n.translate("This event declares %s, and the function already has a parameter called %s. Godot refuses it (\"There is already a parameter named\") and the script does not load. Rename the local, or use the parameter.") % [local_name, local_name],
					"", "", {"lane": "local", "index": -1}, extra))
			elif variables.has(local_name):
				var extra: Dictionary = {}
				extra.merge(_local_doors(event_row, local_name, variables, event_info,
					EventSheetL10n.translate("Remove the local (use the sheet's %s)") % local_name, extra))
				found.append(_finding(KIND_LOCAL_HIDES_VARIABLE, "warning", event_row, local_name,
					EventSheetL10n.translate("This event's %s hides the sheet's %s. Changes to %s here are made to the local, which is gone when the event ends; the sheet's %s stays the same. Godot warns about it (SHADOWED_VARIABLE).") % [local_name, local_name, local_name, local_name],
					"", "", {"lane": "local", "index": -1}, extra))


## The doors on a hiding local: a free name for it, and - where the declaring row is one the door can take out
## without touching hand-written code - removing it. `extra` is told the new name.
static func _local_doors(event_row: EventRow, local_name: String, variables: Dictionary, event_info: Dictionary,
		remove_label: String, extra: Dictionary) -> Dictionary:
	var taken: Dictionary = variables.duplicate()
	for other: Variant in event_info["locals"] as Array:
		taken[str(other)] = true
	var new_name: String = RENAMED_LOCAL_PREFIX + local_name
	var attempt: int = 2
	while taken.has(new_name):
		new_name = "%s%s_%d" % [RENAMED_LOCAL_PREFIX, local_name, attempt]
		attempt += 1
	extra["new_name"] = new_name
	var doors: Array = [[FIX_RENAME_LOCAL, EventSheetL10n.translate("Rename the local to %s") % new_name]]
	if declaring_row(event_row, local_name) != null:
		doors.append([FIX_REMOVE_LOCAL, remove_label])
	return _door_keys(doors)


## The row of an event that declares a local of this name and can be removed whole: an entry of its local
## list, or an action written by one of the local-variable verbs. Null for a `var` in a verbatim block.
static func declaring_row(event_row: EventRow, local_name: String) -> Resource:
	for local: Variant in event_row.local_variables:
		if local is LocalVariable and (local as LocalVariable).name.strip_edges() == local_name:
			return local as LocalVariable
	for action: Variant in event_row.actions:
		if action is ACEAction and _declared_local(action) == local_name:
			return action as ACEAction
	return null


# -- 9. Division by a literal zero -----------------------------------------------------------------------------


## `/` or `%` with a literal zero on the right. Whole numbers stop the function with an error; a
## decimal zero gives inf and nothing is said, so that is a warning. Only a literal zero is judged.
static func _zero_divisions(rows: Array[Dictionary], walk: Dictionary, found: Array[Dictionary]) -> void:
	var variables: Dictionary = walk["sheet_variables"]
	var seen: Dictionary = {}
	for context: Dictionary in rows:
		var line: String = str(context["line"])
		if not (line.contains("/") or line.contains("%")):
			continue
		for hit: Dictionary in zero_divisions_in(line, variables):
			var event_row: EventRow = context["event"] as EventRow
			var key: String = "%d|%s" % [event_row.get_instance_id(), str(hit["text"])]
			if seen.has(key):
				continue
			seen[key] = true
			var extra: Dictionary = {"red": str(hit["severity"]) == "error"}
			if str(context["lane"]) in ["action", "condition"] and not (context["row"] is RawCodeRow):
				extra.merge(_door_keys([[FIX_OPEN_VALUE, EventSheetL10n.translate("Open the value")]]))
			found.append(_finding(KIND_DIVIDE_BY_ZERO, str(hit["severity"]), event_row, str(hit["text"]),
				str(hit["message"]), "", "", context, extra))


## The divisions by a literal zero one line makes: {"text", "severity", "message"}.
static func zero_divisions_in(line: String, variables: Dictionary = {}) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	if _divide_regex == null:
		_divide_regex = RegEx.create_from_string("(?<left>[A-Za-z_][A-Za-z0-9_.]*|\\d+(?:\\.\\d*)?|\\))\\s*(?<op>[/%])=?\\s*(?<zero>0(?:\\.0*)?|\\.0+)(?![\\w.])")
	var plain: String = code_only(line)
	for hit: RegExMatch in _divide_regex.search_all(plain):
		var left: String = hit.get_string("left")
		var operator_text: String = hit.get_string("op")
		var zero: String = hit.get_string("zero")
		var decimal_zero: bool = zero.contains(".")
		var text: String = "%s %s %s" % [left, operator_text, zero]
		var left_is_number: bool = left.substr(0, 1).is_valid_int()
		var left_is_decimal: bool = left_is_number and left.contains(".")
		var left_type: String = str(variables.get(left, ""))
		if operator_text == "%":
			if decimal_zero:
				continue
			hits.append({"text": text, "severity": "error", "message": EventSheetL10n.translate(
				"%s takes the remainder of a division by zero. Godot stops here with a \"Modulo by zero error\".") % text})
			continue
		if decimal_zero or left_is_decimal or left_type == "float":
			hits.append({"text": text, "severity": "warning", "message": EventSheetL10n.translate(
				"%s divides by zero. With decimals Godot gives inf and says nothing, so everything computed from it becomes inf too.") % text})
		elif left_is_number:
			hits.append({"text": text, "severity": "error", "message": EventSheetL10n.translate(
				"%s divides whole numbers by zero. Godot refuses the script (\"Division by zero error in operator\") and it does not load.") % text})
		elif left_type == "int":
			hits.append({"text": text, "severity": "error", "message": EventSheetL10n.translate(
				"%s divides a whole number by zero, so the game stops here with a \"Division by zero error\".") % text})
		else:
			var value_word: String = EventSheetL10n.translate("the value") if left == ")" else left
			hits.append({"text": text, "severity": "warning", "message": EventSheetL10n.translate(
				"%s divides by zero. If %s holds a whole number the game stops here with a \"Division by zero error\"; with a decimal the answer is inf.") % [text, value_word]})
	return hits


# -- 10. A value of the wrong kind ------------------------------------------------------------------------


## The same question the field asks as you type, asked of every row of the sheet: the line it compiles to,
## in a stand-in script that knows the sheet's types. Only what Godot's own analyzer refuses, in a line the
## untyped stand-in accepts, is a finding - so a mistake here is exactly what the field would have refused.
static func _wrong_kinds(sheet: EventSheetResource, rows: Array[Dictionary], scene: Dictionary, walk: Dictionary,
		found: Array[Dictionary]) -> void:
	var lines: Array[Dictionary] = []
	var contexts: Array[Dictionary] = []
	for context: Dictionary in rows:
		var lane: String = str(context["lane"])
		if lane != "action" and lane != "condition":
			continue
		var code: String = str(context["line"]).strip_edges()
		if code.is_empty() or code.begins_with("#") or not quote_left_open(code).is_empty():
			continue
		lines.append({"code": code, "condition": lane == "condition"})
		contexts.append(context)
	var variables: Dictionary = walk["sheet_variables"]
	var verdicts: Array = EventSheetTypeCheck.judge_lines(sheet, lines, _classes_of_nodes(scene))
	for index: int in range(verdicts.size()):
		var lead: String = str(verdicts[index])
		if lead.is_empty():
			continue
		var context: Dictionary = contexts[index]
		var entry: Resource = context["row"] as Resource
		var words: Dictionary = EventSheetTypeCheck.line_finding(lead, str(lines[index]["code"]), sheet, context["params"] as Dictionary)
		var doors: Array = []
		var extra: Dictionary = {"red": true, "original": lead, "to": str(words.get("rewrite", "")), "param": str(words.get("param", ""))}
		if not str(extra["to"]).is_empty() and not str(extra["param"]).is_empty():
			doors.append([FIX_USE_VALUE, EventSheetL10n.translate("Use %s") % str(extra["to"])])
		if entry is ACEAction or entry is ACECondition:
			doors.append([FIX_OPEN_VALUE, EventSheetL10n.translate("Open the parameters")])
		var target: String = str(words.get("target", ""))
		if variables.has(target):
			extra["variable"] = target
			doors.append([FIX_GO_TO_VARIABLE, EventSheetL10n.translate("Go to %s") % target])
		extra.merge(_door_keys(doors))
		found.append(_finding(KIND_WRONG_KIND, "error", context["event"] as EventRow, str(lines[index]["code"]),
			"%s %s" % [str(words["head"]), str(words["body"])], "", "", context, extra))


## The `$Path` / `%Name` references every scene running this script agrees the class of, as {reference: class}.
static func _classes_of_nodes(scene: Dictionary) -> Dictionary:
	var classes: Dictionary = {}
	if not bool(scene.get("known", false)):
		return classes
	var tables: Array = scene["tables"]
	if tables.is_empty() or bool((tables[0] as Dictionary).get("inherited", false)):
		return classes
	for sigil_table: Array in [["$", "paths"], ["%", "unique"]]:
		for path: Variant in ((tables[0] as Dictionary)[sigil_table[1]] as Dictionary).keys():
			var the_class: String = str(((tables[0] as Dictionary)[sigil_table[1]] as Dictionary)[path])
			if str(path) == "." or the_class.is_empty() or not ClassDB.class_exists(the_class):
				continue
			var agreed: bool = true
			for table: Variant in tables:
				agreed = agreed and not bool((table as Dictionary).get("inherited", false)) \
					and str(((table as Dictionary)[sigil_table[1]] as Dictionary).get(path, "")) == the_class
			if agreed:
				classes[str(sigil_table[0]) + str(path)] = the_class
	return classes


# -- The shape every family speaks ---------------------------------------------------------------------------------


## The doors a finding offers, as the keys the strip and the Doctor read: at most three, first the likeliest.
## Each door is [id, label].
static func _door_keys(doors: Array) -> Dictionary:
	var keys: Dictionary = {}
	var slots: Array = [["fix", "fix_label"], ["second_fix", "second_fix_label"], ["third_fix", "third_fix_label"]]
	for index: int in range(mini(doors.size(), slots.size())):
		keys[str(slots[index][0])] = str(doors[index][0])
		keys[str(slots[index][1])] = str(doors[index][1])
	return keys


## One finding, with every key its readers address filled in. `lane` and `index` say where in the event
## the row sits, so a repair can find it again after the undo funnel replaced the resources it held.
static func _finding(kind: String, severity: String, event_row: EventRow, subject: String, message: String,
		fix: String, fix_label: String, context: Dictionary, extra: Dictionary) -> Dictionary:
	var finding: Dictionary = {
		"kind": kind, "severity": severity, "anchor": ANCHOR_EVENT, "event": event_row,
		"subject": subject, "message": message, "fix": fix, "fix_label": fix_label,
		"lane": str(context.get("lane", "")), "index": int(context.get("index", -1)),
		"to": "", "red": severity == "error",
	}
	finding.merge(extra, true)
	return finding
