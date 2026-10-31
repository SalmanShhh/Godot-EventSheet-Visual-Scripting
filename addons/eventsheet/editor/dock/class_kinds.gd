@tool
extends RefCounted
# Kinds of a class: a sheet that names itself (class_name Enemy) is an object every sheet can pick,
# and a sheet that extends it (class_name Slime, extends Enemy) is a kind of it. This file is the
# model of that, free of any window, so a menu, a dialog and a test all ask the same questions.
#
# WHAT IT ANSWERS
#   - the classes of the project, as a tree of kinds (each with the class it extends), so an object
#     list can show your own classes first with a kind nested under what it is a kind of
#   - what a class hands down: the variables and functions Enemy declares and every class above it
#   - the head of a sheet in either vocabulary ("a kind of Enemy" / "extends Enemy")
#   - the three things a kind can do with what it inherited, each written as ordinary sheet data
#     that compiles to the GDScript a person would have typed:
#       start a variable at another value   -> an `_init` function that sets it
#       replace a function                  -> a function of the same name and parameters that
#                                              first runs the parent's version (super)
#       a fresh sheet that is a kind of X   -> host_class = X, its own class_name
#
# Loaded BY PATH from the dialogs that need it; it is not named as a class, so nothing on the boot
# path pays for it.

## The words of the head in each vocabulary, as [familiar, godot]. The sheet's Familiar Words
## switch picks one; the GDScript under both is the same line.
const HEAD_WORDS: Dictionary = {
	"kind_of": ["a kind of", "extends"],
	"kind_of_title": ["A kind of", "Extends"],
	"from": ["From", "Inherited from"],
	"replaces": ["Replaces", "Overrides"],
	"also_run": ["Also run", "Call super:"],
	"make_kinds": ["Make kinds of it", "Extend it"],
	"starts_it_at": ["starts it at", "overrides the default"],
}

const _FUNC := "^func\\s+(\\w+)\\s*\\((.*)\\)\\s*(?:->\\s*([\\w\\.\\[\\]]+))?\\s*:"
const _VAR := "^(?:@export\\w*(?:\\([^)]*\\))?\\s+)*var\\s+(\\w+)\\s*(?::\\s*([\\w\\.\\[\\]]+))?\\s*(?::?=\\s*(.+?))?\\s*(?:#.*)?$"
const _EXTENDS := "^extends\\s+(\\w+)"


## One word of the head, in the vocabulary asked for.
static func word(key: String, familiar: bool) -> String:
	var pair: Array = HEAD_WORDS.get(key, [key, key])
	return str(pair[0] if familiar else pair[1])


## The class_name -> {path, base} of every class the project declares, read from the editor's own
## class list. The base is the name after `extends`, which is itself a project class or an engine one.
static func project_classes() -> Dictionary:
	var found: Dictionary = {}
	for info: Dictionary in ProjectSettings.get_global_class_list():
		var declared: String = str(info.get("class", ""))
		var path: String = str(info.get("path", ""))
		if declared.is_empty() or not path.begins_with("res://") or path.begins_with("res://addons/"):
			continue
		found[declared] = {"path": path, "base": str(info.get("base", ""))}
	return found


## The class `name` extends, or "" when it is not a project class. Reads the declaring script's own
## `extends` line, so a class that extends a project class says so rather than naming the engine
## ancestor at the bottom of the chain (the editor's list reports that one).
static func parent_of(class_text: String, classes: Dictionary = {}) -> String:
	var table: Dictionary = classes if not classes.is_empty() else project_classes()
	if not table.has(class_text):
		return ""
	return declared_base(FileAccess.get_file_as_string(str((table[class_text] as Dictionary).get("path", ""))))


## The name after the first top-level `extends` of a source, "" when there is none.
static func declared_base(source: String) -> String:
	var regex: RegEx = RegEx.create_from_string(_EXTENDS)
	for line: String in source.split("\n"):
		var hit: RegExMatch = regex.search(line)
		if hit != null:
			return hit.get_string(1)
	return ""


## Your classes as a tree, kinds nested under what they extend: [{name, base, depth, path}] in the
## order a list draws them (a class, then its kinds, each indented one deeper). A class whose base
## is an engine class (or none) is a root; everything is sorted by name so the order never moves.
static func kinds_tree(classes: Dictionary = {}) -> Array[Dictionary]:
	var table: Dictionary = classes if not classes.is_empty() else project_classes()
	var parent_by_name: Dictionary = {}
	for class_text: String in table:
		var base: String = declared_base(FileAccess.get_file_as_string(str((table[class_text] as Dictionary).get("path", ""))))
		parent_by_name[class_text] = base if table.has(base) else ""
	var ordered: Array[Dictionary] = []
	var roots: Array = []
	for class_text: String in table:
		if str(parent_by_name[class_text]).is_empty():
			roots.append(class_text)
	roots.sort()
	for root: String in roots:
		_append_kinds(ordered, root, 0, parent_by_name, table, {})
	return ordered


static func _append_kinds(ordered: Array[Dictionary], class_text: String, depth: int, parent_by_name: Dictionary,
		table: Dictionary, seen: Dictionary) -> void:
	if seen.has(class_text):
		return
	seen[class_text] = true
	ordered.append({"name": class_text, "base": str(parent_by_name.get(class_text, "")), "depth": depth,
		"path": str((table[class_text] as Dictionary).get("path", ""))})
	var kids: Array = []
	for other: String in parent_by_name:
		if str(parent_by_name[other]) == class_text:
			kids.append(other)
	kids.sort()
	for kid: String in kids:
		_append_kinds(ordered, kid, depth + 1, parent_by_name, table, seen)


## The top-level variables of one source: [{name, type, value}] in file order. A `var` inside a
## function is indented and never matches.
static func variables_in(source: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var regex: RegEx = RegEx.create_from_string(_VAR)
	for line: String in source.split("\n"):
		if line.begins_with("\t") or line.begins_with(" "):
			continue
		var hit: RegExMatch = regex.search(line)
		if hit != null:
			out.append({"name": hit.get_string(1), "type": hit.get_string(2), "value": hit.get_string(3)})
	return out


## The top-level functions of one source: [{name, params: [{name, type}], params_text, returns}] in
## file order. A function whose name begins with an underscore is private to its class and is kept
## (a kind may replace it) but flagged `private`.
static func functions_in(source: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var regex: RegEx = RegEx.create_from_string(_FUNC)
	for line: String in source.split("\n"):
		var header: String = line
		if header.begins_with("static "):
			header = header.substr(7)
		var hit: RegExMatch = regex.search(header)
		if hit == null:
			continue
		var params: Array[Dictionary] = []
		for piece: String in _split_top_level(hit.get_string(2)):
			var text: String = piece.strip_edges()
			if text.is_empty():
				continue
			text = text.get_slice("=", 0).strip_edges()
			var param_name: String = text.get_slice(":", 0).strip_edges()
			var param_type: String = text.get_slice(":", 1).strip_edges() if text.contains(":") else ""
			params.append({"name": param_name, "type": param_type})
		out.append({"name": hit.get_string(1), "params": params, "params_text": hit.get_string(2).strip_edges(),
			"returns": hit.get_string(3), "private": hit.get_string(1).begins_with("_")})
	return out


static func _split_top_level(text: String) -> PackedStringArray:
	var pieces: PackedStringArray = PackedStringArray()
	var depth: int = 0
	var current: String = ""
	for character: String in text:
		if character in "([{":
			depth += 1
		elif character in ")]}":
			depth -= 1
		if character == "," and depth == 0:
			pieces.append(current)
			current = ""
		else:
			current += character
	pieces.append(current)
	return pieces


## What a class hands down to its kinds, nearest class first: {variables, functions}, each entry
## carrying `owner` (the class that declares it). A name a nearer class declares hides the same name
## further up, the way the language resolves it. `parent_text` is the class the kind extends.
static func inherited(parent_text: String, classes: Dictionary = {}) -> Dictionary:
	var table: Dictionary = classes if not classes.is_empty() else project_classes()
	var variables: Array[Dictionary] = []
	var functions: Array[Dictionary] = []
	var seen_vars: Dictionary = {}
	var seen_funcs: Dictionary = {}
	var walked: Dictionary = {}
	var current: String = parent_text
	while table.has(current) and not walked.has(current):
		walked[current] = true
		var source: String = FileAccess.get_file_as_string(str((table[current] as Dictionary).get("path", "")))
		for entry: Dictionary in variables_in(source):
			if not seen_vars.has(entry["name"]):
				seen_vars[entry["name"]] = true
				entry["owner"] = current
				variables.append(entry)
		for entry: Dictionary in functions_in(source):
			if not seen_funcs.has(entry["name"]):
				seen_funcs[entry["name"]] = true
				entry["owner"] = current
				functions.append(entry)
		current = declared_base(source)
	return {"variables": variables, "functions": functions}


## The head of a kind in the words asked for: "Slime a kind of Enemy" / "Slime extends Enemy".
static func head_reading(kind_text: String, parent_text: String, familiar: bool) -> String:
	return "%s %s %s" % [kind_text, word("kind_of", familiar), parent_text]


## "Slime starts it at 60.0" / "Slime overrides the default 60.0", for an inherited variable a kind
## starts at another value.
static func starts_it_reading(kind_text: String, value_text: String, familiar: bool) -> String:
	if familiar:
		return "%s %s %s" % [kind_text, word("starts_it_at", true), value_text]
	return "%s %s %s" % [kind_text, word("starts_it_at", false), value_text]


## A fresh sheet that is a kind of `parent_text`: it extends the parent and names itself.
static func new_kind_sheet(kind_text: String, parent_text: String) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = parent_text
	sheet.custom_class_name = kind_text
	return sheet


## A class name from a file stem or typed words: "slime", "big slime" and "big_slime" all become
## "BigSlime", which is what GDScript's own style gives a class.
static func class_name_from(text: String) -> String:
	var stem: String = text.get_file()
	if stem.get_extension().to_lower() == "gd":
		stem = stem.get_basename()
	return stem.to_pascal_case()


## Whether another class already has this name: a project class, or an engine class (which a
## class_name may not shadow). The file the name is being written to, when it already declares it,
## is not "another".
static func name_is_taken(candidate: String, own_path: String = "", classes: Dictionary = {}) -> bool:
	if candidate.is_empty():
		return false
	if ClassDB.class_exists(candidate):
		return true
	var table: Dictionary = classes if not classes.is_empty() else project_classes()
	if not table.has(candidate):
		return false
	return str((table[candidate] as Dictionary).get("path", "")) != own_path


## Makes the kind START an inherited variable at another value: the sheet gains (or edits) an
## `_init` function whose body sets it, which is exactly where GDScript puts a subclass's starting
## values. Returns the EventFunction. A value set before on the same variable is replaced, not
## doubled.
static func start_variable_at(sheet: EventSheetResource, variable_text: String, value_text: String) -> EventFunction:
	var init_function: EventFunction = null
	for existing: EventFunction in sheet.functions:
		if existing.function_name == "_init":
			init_function = existing
			break
	if init_function == null:
		init_function = EventFunction.new()
		init_function.function_name = "_init"
		var step: EventRow = EventRow.new()
		init_function.events.append(step)
		sheet.functions.append(init_function)
	var lane: EventRow = init_function.lane_event()
	if lane == null:
		lane = init_function.events[0] as EventRow if not init_function.events.is_empty() and init_function.events[0] is EventRow else null
	if lane == null:
		lane = EventRow.new()
		init_function.events.append(lane)
	for action: Variant in lane.actions:
		if action is ACEAction and (action as ACEAction).ace_id == "SetVar" \
				and str((action as ACEAction).params.get("var_name", "")) == variable_text:
			(action as ACEAction).params = {"var_name": variable_text, "value": value_text}
			return init_function
	var set_it: ACEAction = ACEAction.new()
	set_it.provider_id = "Core"
	set_it.ace_id = "SetVar"
	set_it.params = {"var_name": variable_text, "value": value_text}
	lane.actions.append(set_it)
	return init_function


## A function of the kind that REPLACES `parent_function` (an entry of `inherited()["functions"]`):
## the same name and parameters, already holding the action that runs the parent's version first, so
## nothing is lost unless the person deletes it. Returns the EventFunction, not yet added to a sheet.
static func replace_function(parent_function: Dictionary) -> EventFunction:
	var replacement: EventFunction = EventFunction.new()
	replacement.function_name = str(parent_function.get("name", ""))
	var names: PackedStringArray = PackedStringArray()
	for entry: Variant in parent_function.get("params", []):
		var param: ACEParam = ACEParam.new()
		param.id = str((entry as Dictionary).get("name", ""))
		param.type_name = str((entry as Dictionary).get("type", ""))
		replacement.params.append(param)
		names.append(param.id)
	var returns: String = str(parent_function.get("returns", ""))
	if not returns.is_empty() and returns != "void":
		replacement.return_type_name = returns
	var lane: EventRow = EventRow.new()
	var also: ACEAction = ACEAction.new()
	also.provider_id = "Core"
	if returns.is_empty() or returns == "void":
		also.ace_id = "CallParentFunction"
		also.params = {"args": ", ".join(names)}
	else:
		# A function that answers must hand the parent's answer on, or the replacement returns nothing.
		also.ace_id = "ReturnValue"
		also.params = {"value": "super(%s)" % ", ".join(names)}
	lane.actions.append(also)
	replacement.events.append(lane)
	return replacement
