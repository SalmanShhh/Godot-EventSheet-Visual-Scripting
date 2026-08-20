@tool
class_name EventSheetEditorSourceFacts
extends RefCounted

# W3 / W4 / W5 / W16. What a TOOL script's own shape says about it, answered once per rebuild.
#
# Four shapes an editor is written in, none of which any single line can answer:
#
#   helper of X      a RefCounted whose `_init` stores the object it was handed and whose methods
#                    reach back through it. That is a BEHAVIOR of that object in the sheet's sense,
#                    so its rows read under the object's name rather than under a member nobody
#                    can see.
#   one undo step    an edit handed to a mutation funnel as a label plus a callback. The funnel is
#                    one door and the callback IS the edit, so the pair reads as one step with the
#                    edit hanging under it.
#   shared store     a class that is all `static` - no instances, shared state, shared verbs. The
#                    head says so, because "one for the whole editor" is the fact a reader needs
#                    before reading any row of it.
#   vocabulary       a module whose `register(registry)` fills the vocabulary with
#                    add_condition / add_action / add_expression, which are the Define rows a pack
#                    already reads as.
#
# Everything here is DISPLAY ONLY and every function is static and pure, so a test pins a reading by
# value without a viewport. Nothing is written back, and the byte round-trip cannot move.
#
# The answers come from the file's own SOURCE when the sheet was opened from one - a `func` header
# is not a row, so the row-level line walk the other fact modules use cannot see the two shapes that
# are stated in a header. A sheet with no file on disk simply gets {} and every reading built on it
# keeps the plain words it already had.

## The mutation funnels a step is wrapped in: a label and a callback, in that order. Frozen with the
## pattern ids - the reading, the claim and the health check all key on the pair.
const FUNNEL_METHODS: PackedStringArray = ["_perform_undoable_sheet_edit", "perform_undoable_sheet_edit"]

## The word an ALIAS of the funnel is spelled with. A coordinator's door is often reached through a
## thin forwarder on a helper, and a forwarder that says "undoable" in its own name is saying it
## does the same thing - which is the only claim the reading makes about it.
const FUNNEL_WORD := "undoable"

## The vocabulary calls a module publishes a row with, and the kind word each one publishes.
const REGISTER_CALLS: Dictionary = {
	"add_condition": "condition", "add_action": "action", "add_expression": "expression"
}

## The second spelling of the same thing: one descriptor built with every field in order. The
## positions a Define row reads are the id, the name, the kind, the template, the inputs and the
## category - which is what this table says, so nothing downstream counts arguments.
const DESCRIPTOR_CALL := "make_descriptor"
const DESCRIPTOR_POSITIONS: Dictionary = {
	"provider": 0, "id": 1, "name": 2, "kind": 3, "template": 4, "params": 6, "category": 7
}

## The kind word behind each spelling of the descriptor's type argument.
const DESCRIPTOR_KINDS: Dictionary = {
	"CONDITION": "condition", "ACTION": "action", "EXPRESSION": "expression", "TRIGGER": "trigger"
}

## The words a doc comment above a constant uses to say it must never change. Either spelling marks
## the row, because both are how the promise is written down in practice.
const FROZEN_WORDS: PackedStringArray = ["frozen", "never rename"]

## The last file read, and what it said. One entry is enough: the questions are asked in bursts about
## the sheet being rebuilt, never about two files at once.
static var _cache: Dictionary = {}


## Everything below, merged into the sentence context once per rebuild:
##
##   helper_of            {member, object, file} - the stored back-reference, the object it names
##                        and the file that object's class lives in ("" when it cannot be resolved)
##   shared_store         true when the class is all static
##   shared_members       {name: true} for each `static var`
##   frozen_constants     {name: true} for each `const` whose doc comment says it is frozen
##   vocabulary_module    true when the file publishes vocabulary rows
##   vocabulary_rows      [{kind, id, name, category, inputs, template}] in file order
##   recursive_functions  {name: true} for each function that calls itself
##
## The Dictionary returned is the cache's own and is READ-ONLY to its callers - everything here is a
## reading, and nothing that reads a file's shape has any business editing the answer.
static func facts(sheet: EventSheetResource) -> Dictionary:
	if sheet == null:
		return {}
	var path: String = str(sheet.external_source_path).strip_edges()
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	# The answers are a function of the file's TEXT, and a row build asks for them once per head bar
	# and once per variable row. Keyed by the file's own modification time, so an edited file is read
	# again and an unchanged one is read once - the read itself is what this is saving, so the stamp
	# is taken WITHOUT reading it.
	var stamp: String = "%s|%d" % [path, FileAccess.get_modified_time(path)]
	if str(_cache.get("stamp", "")) == stamp:
		return _cache.get("facts", {}) as Dictionary
	var found: Dictionary = facts_for_source(FileAccess.get_file_as_string(path))
	_cache = {"stamp": stamp, "facts": found}
	return found


## The same, from source text alone - the shape a test pins.
static func facts_for_source(source: String) -> Dictionary:
	var lines: PackedStringArray = source.split("\n")
	var out: Dictionary = {}
	var helper: Dictionary = _helper_of(lines)
	if not helper.is_empty():
		out["helper_of"] = helper
	if _is_shared_store(lines):
		out["shared_store"] = true
	var shared_members: Dictionary = _shared_members(lines)
	if not shared_members.is_empty():
		out["shared_members"] = shared_members
	var frozen: Dictionary = _frozen_constants(lines)
	if not frozen.is_empty():
		out["frozen_constants"] = frozen
	var rows: Array = vocabulary_rows(lines)
	if not rows.is_empty():
		out["vocabulary_module"] = true
		out["vocabulary_rows"] = rows
	var recursive: Dictionary = recursive_functions(lines)
	if not recursive.is_empty():
		out["recursive_functions"] = recursive
	return out


## True when a method name is the mutation funnel, or an alias forwarding to it.
static func is_funnel_method(method: String) -> bool:
	var name: String = method.strip_edges()
	return FUNNEL_METHODS.has(name) or name.to_lower().contains(FUNNEL_WORD)


## True when the project being edited IS this editor's own repo - the one project where a file can
## be a helper of the dock, a shared store or a page of the vocabulary. Everything gated on this is
## invisible to an ordinary game project, which is the point: a game has no such files.
##
## The test is the two things only this repo has side by side: the plugin's own manifest, and the
## folder its behavior packs are built from.
static func is_editor_project() -> bool:
	return FileAccess.file_exists("res://addons/eventforge/plugin.cfg") \
		and DirAccess.dir_exists_absolute("res://tools/pack_builders")


## The file's own text, or "" when the sheet was not opened from one.
static func source_text(sheet: EventSheetResource) -> String:
	if sheet == null:
		return ""
	var path: String = str(sheet.external_source_path).strip_edges()
	if path.is_empty() or not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


# ── W3: a helper with a back-reference ────────────────────────────────────────────────────────


## {member, object, file} for a RefCounted whose `_init` only stores what it was handed and whose
## other functions reach back through it, {} for everything else. Strict on purpose: a constructor
## that DOES something is a constructor, and calling its class a behavior of its argument would put
## a reader's eyes on the wrong object.
static func _helper_of(lines: PackedStringArray) -> Dictionary:
	if not _extends_class(lines, "RefCounted"):
		return {}
	var init_at: int = -1
	var parameters: PackedStringArray = PackedStringArray()
	for index: int in lines.size():
		var head: Dictionary = _function_header(lines[index])
		if head.is_empty() or str(head.get("name", "")) != "_init":
			continue
		init_at = index
		parameters = head.get("params", PackedStringArray())
		break
	if init_at < 0 or parameters.is_empty():
		return {}
	var stored: PackedStringArray = PackedStringArray()
	for body_line: String in _body_lines(lines, init_at):
		var statement: String = body_line.strip_edges()
		if statement.is_empty() or statement.begins_with("#"):
			continue
		var at: int = statement.find(" = ")
		if at < 0:
			return {}
		var member: String = statement.substr(0, at).strip_edges()
		var value: String = statement.substr(at + 3).strip_edges()
		if not _is_plain_name(member) or not parameters.has(value):
			return {}
		stored.append(member)
	if stored.is_empty():
		return {}
	for member: String in stored:
		if not _used_as_receiver(lines, member, init_at):
			continue
		return {
			"member": member,
			"object": object_word(member),
			"file": _class_file_for(member, lines)
		}
	return {}


## The object a stored back-reference names: the member's own name, without the underscore that
## marks it private and in the sentence case every other object label is written in.
static func object_word(member: String) -> String:
	var bare: String = member.strip_edges().lstrip("_").strip_edges()
	if bare.is_empty():
		return ""
	return bare.replace("_", " ").capitalize()


## The file the object's own class lives in, resolved from what the project itself declares: the
## member's declared type when that type is a project class, else the class whose file is named
## after the member. "" when nothing resolves, and the bar then simply names no file.
static func _class_file_for(member: String, lines: PackedStringArray) -> String:
	var declared: String = _declared_type_of(member, lines)
	var classes: Array = ProjectSettings.get_global_class_list()
	if not declared.is_empty() and not ClassDB.class_exists(declared):
		for entry: Dictionary in classes:
			if str(entry.get("class", "")) == declared:
				return str(entry.get("path", "")).get_file()
	var bare: String = member.strip_edges().lstrip("_")
	if bare.is_empty():
		return ""
	# Which of the candidate files is the object is decided by what the FILE ITSELF declares, not by
	# a list of names kept somewhere: the one that declares the members this class reaches through
	# the reference is the one the reader means. A tie falls back to the shortest name.
	var reached: PackedStringArray = _members_reached_through(member, lines)
	var best: String = ""
	var best_score: int = -1
	for entry: Dictionary in classes:
		var path: String = str(entry.get("path", ""))
		var base: String = path.get_file().get_basename()
		if base != bare and not base.ends_with("_%s" % bare):
			continue
		var score: int = _declares_count(path, reached)
		if score > best_score or (score == best_score and not best.is_empty() and path.get_file().length() < best.length()):
			best_score = score
			best = path.get_file()
	return best


## The member names this file reaches through the back-reference, in the spelling they are written
## in ( `_dock._select_row(...)` reaches `_select_row` ).
static func _members_reached_through(member: String, lines: PackedStringArray) -> PackedStringArray:
	var reached: PackedStringArray = PackedStringArray()
	var head: String = "%s." % member
	for line: String in lines:
		var from: int = 0
		while true:
			var at: int = line.find(head, from)
			if at < 0:
				break
			from = at + head.length()
			var name: String = ""
			var index: int = from
			while index < line.length():
				var character: String = line[index]
				if not (character == "_" or character.to_lower() != character.to_upper() or character.is_valid_int()):
					break
				name += character
				index += 1
			if not name.is_empty() and not reached.has(name):
				reached.append(name)
	return reached


## How many of `wanted` a script declares as a function or a variable. 0 for a file that cannot be
## read, which simply loses the tie-break rather than the whole reading.
static func _declares_count(path: String, wanted: PackedStringArray) -> int:
	if wanted.is_empty() or not FileAccess.file_exists(path):
		return 0
	var source: String = FileAccess.get_file_as_string(path)
	var found: int = 0
	for name: String in wanted:
		if source.contains("func %s(" % name) or source.contains("var %s" % name):
			found += 1
	return found


## The declared type of a member variable, "" when the file did not write one.
static func _declared_type_of(member: String, lines: PackedStringArray) -> String:
	var head: String = "var %s:" % member
	for line: String in lines:
		if not line.begins_with(head):
			continue
		var rest: String = line.substr(head.length())
		var stop: int = rest.find("=")
		return (rest if stop < 0 else rest.substr(0, stop)).strip_edges()
	return ""


## True when some line OUTSIDE the constructor reaches through the member - which is what makes the
## class a behavior of the object rather than a class that merely remembers one.
static func _used_as_receiver(lines: PackedStringArray, member: String, init_at: int) -> bool:
	var body: PackedStringArray = _body_lines(lines, init_at)
	for index: int in lines.size():
		if index > init_at and index <= init_at + body.size():
			continue
		if lines[index].contains("%s." % member):
			return true
	return false


# ── W5: a shared store ────────────────────────────────────────────────────────────────────────


## True when nothing of this class is ever made: at least one `static var`, no instance variable and
## no instance function. A class with one static helper on it is NOT a shared store - saying so
## would put the head line on half the files in a project.
static func _is_shared_store(lines: PackedStringArray) -> bool:
	var shared: int = 0
	for line: String in lines:
		if line.begins_with("static var "):
			shared += 1
			continue
		if line.begins_with("var ") or line.begins_with("@export"):
			return false
		if line.begins_with("func "):
			return false
	return shared > 0


## {name: true} for each `static var` the file declares.
static func _shared_members(lines: PackedStringArray) -> Dictionary:
	var found: Dictionary = {}
	for line: String in lines:
		if not line.begins_with("static var "):
			continue
		var rest: String = line.substr(11)
		var name: String = _leading_name(rest)
		if not name.is_empty():
			found[name] = true
	return found


## {name: true} for each `const` whose doc comment above it says it must never change.
static func _frozen_constants(lines: PackedStringArray) -> Dictionary:
	var found: Dictionary = {}
	for index: int in lines.size():
		if not lines[index].begins_with("const "):
			continue
		var name: String = _leading_name(lines[index].substr(6))
		if name.is_empty():
			continue
		var comment: String = ""
		var above: int = index - 1
		while above >= 0 and lines[above].strip_edges().begins_with("#"):
			comment = "%s %s" % [lines[above].strip_edges(), comment]
			above -= 1
		var lowered: String = comment.to_lower()
		for word: String in FROZEN_WORDS:
			if lowered.contains(word):
				found[name] = true
				break
	return found


# ── W16: a vocabulary module, and a function that calls itself ────────────────────────────────


## Every vocabulary row the file publishes, in file order:
## {kind, id, name, category, inputs, template}. Empty for a file that publishes none.
static func vocabulary_rows(lines: PackedStringArray) -> Array:
	var rows: Array = []
	for index: int in lines.size():
		var statement: String = lines[index].strip_edges()
		for call_name: String in REGISTER_CALLS:
			var head: String = ".%s(" % call_name
			var at: int = statement.find(head)
			if at < 0:
				continue
			var arguments_text: String = statement.substr(at + head.length())
			var comma: int = arguments_text.find(",")
			if comma <= 0:
				break
			var id_text: String = arguments_text.substr(0, comma).strip_edges()
			var row_id: String = _unquoted(id_text)
			# A publish hands over an id and then a DICTIONARY of the row's fields. Insisting on both
			# is what keeps `InputMap.add_action(name)` - an ordinary call that happens to share a
			# verb with the registry - from reading as a row nobody published.
			if row_id.is_empty() or not id_text.begins_with("\"") \
					or not arguments_text.substr(comma + 1).strip_edges().begins_with("{"):
				break
			# The row's own fields sit in the dictionary handed over beside the id - on the same line
			# when it is short, on the lines below when it is not. Both are read, and a publish whose
			# fields never arrive keeps the id alone rather than inventing the rest.
			var open_at: int = at + head.length() - 1
			var close_at: int = _matching_bracket(statement, open_at)
			var entries: Dictionary = _dictionary_entries(lines, index) if close_at < 0 \
				else _inline_entries(statement.substr(open_at + 1, close_at - open_at - 1))
			rows.append({
				"kind": str(REGISTER_CALLS[call_name]),
				"id": row_id,
				"name": str(entries.get("name", "")),
				"category": str(entries.get("category", "")),
				"inputs": str(entries.get("params", "")),
				"template": str(entries.get("codegen_template", ""))
			})
			break
	rows.append_array(_descriptor_rows(lines))
	return rows


## The same rows written the other way: one descriptor per call, every field in position. Read with
## the same top-level split the rest of the grammar uses, so a template full of commas and brackets
## is one argument rather than five.
static func _descriptor_rows(lines: PackedStringArray) -> Array:
	var rows: Array = []
	var constants: Dictionary = _string_constants(lines)
	var head: String = "%s(" % DESCRIPTOR_CALL
	for line: String in lines:
		var at: int = line.find(head)
		if at < 0:
			continue
		var open_at: int = at + head.length() - 1
		var close_at: int = _matching_bracket(line, open_at)
		if close_at < 0:
			continue
		var arguments: PackedStringArray = _top_level_arguments(
			line.substr(open_at + 1, close_at - open_at - 1))
		var row_id: String = _positional(arguments, "id", constants)
		if row_id.is_empty():
			continue
		var kind_text: String = _positional(arguments, "kind", constants)
		var kind: String = ""
		for suffix: String in DESCRIPTOR_KINDS:
			if kind_text.ends_with(suffix):
				kind = str(DESCRIPTOR_KINDS[suffix])
				break
		if kind.is_empty():
			continue
		var params_text: String = _positional(arguments, "params", constants)
		rows.append({
			"kind": kind,
			"provider": _positional(arguments, "provider", constants),
			"id": row_id,
			"name": _positional(arguments, "name", constants),
			"category": _positional(arguments, "category", constants),
			"inputs": ", ".join(_descriptor_param_words(params_text)),
			"template": _positional(arguments, "template", constants)
		})
	return rows


## One positional argument, unquoted, with a named constant resolved to the text it holds.
static func _positional(arguments: PackedStringArray, field: String, constants: Dictionary) -> String:
	var index: int = int(DESCRIPTOR_POSITIONS.get(field, -1))
	if index < 0 or index >= arguments.size():
		return ""
	var text: String = arguments[index].strip_edges()
	if constants.has(text):
		return str(constants[text])
	return _unquoted(text)


## "action: String" for each parameter a descriptor's list builds - the input words a Define row
## shows, in the order the row receives them.
static func _descriptor_param_words(params_text: String) -> PackedStringArray:
	var words: PackedStringArray = PackedStringArray()
	var head: String = "make_param("
	var rest: String = params_text
	while true:
		var at: int = rest.find(head)
		if at < 0:
			break
		var open_at: int = at + head.length() - 1
		var close_at: int = _matching_bracket(rest, open_at)
		if close_at < 0:
			break
		var arguments: PackedStringArray = _top_level_arguments(
			rest.substr(open_at + 1, close_at - open_at - 1))
		rest = rest.substr(close_at + 1)
		if arguments.is_empty():
			continue
		var id_text: String = _unquoted(arguments[0])
		if id_text.is_empty():
			continue
		var type_text: String = _unquoted(arguments[1]) if arguments.size() > 1 else ""
		words.append(id_text if type_text.is_empty() else "%s: %s" % [id_text, type_text])
	return words


## {NAME: text} for every file-level `const NAME := "text"` - the categories a module writes once and
## names everywhere.
static func _string_constants(lines: PackedStringArray) -> Dictionary:
	var found: Dictionary = {}
	for line: String in lines:
		if not line.begins_with("const "):
			continue
		var name: String = _leading_name(line.substr(6))
		if name.is_empty():
			continue
		var at: int = line.find("=")
		if at < 0:
			continue
		var value: String = line.substr(at + 1).strip_edges()
		if value.begins_with("\"") and value.ends_with("\""):
			found[name] = _unquoted(value)
	return found


## An argument list split at its TOP-LEVEL commas only, so a bracketed list and a string full of
## commas each stay one argument.
static func _top_level_arguments(text: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var depth: int = 0
	var in_string: bool = false
	var quote: String = ""
	var start: int = 0
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if in_string:
			if character == "\\":
				index += 2
				continue
			if character == quote:
				in_string = false
			index += 1
			continue
		if character == "\"" or character == "'":
			in_string = true
			quote = character
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		elif character == "," and depth == 0:
			out.append(text.substr(start, index - start))
			start = index + 1
		index += 1
	out.append(text.substr(start))
	return out


## The index of the bracket closing the one at `open_at`, or -1. Quote-aware, so a bracket inside a
## template string never closes the call.
static func _matching_bracket(text: String, open_at: int) -> int:
	if open_at < 0 or open_at >= text.length():
		return -1
	var depth: int = 0
	var in_string: bool = false
	var quote: String = ""
	var index: int = open_at
	while index < text.length():
		var character: String = text[index]
		if in_string:
			if character == "\\":
				index += 2
				continue
			if character == quote:
				in_string = false
			index += 1
			continue
		if character == "\"" or character == "'":
			in_string = true
			quote = character
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
			if depth == 0:
				return index
		index += 1
	return -1


## The fields of a publish written on ONE line: the id, then the dictionary beside it. Split at its
## top-level commas, so a params list full of its own commas is one field rather than four.
static func _inline_entries(arguments_text: String) -> Dictionary:
	var out: Dictionary = {}
	var arguments: PackedStringArray = _top_level_arguments(arguments_text)
	if arguments.size() < 2:
		return out
	var body: String = arguments[1].strip_edges()
	var open_at: int = body.find("{")
	var close_at: int = _matching_bracket(body, open_at)
	if open_at < 0 or close_at < 0:
		return out
	for entry: String in _top_level_arguments(body.substr(open_at + 1, close_at - open_at - 1)):
		var pair: String = entry.strip_edges()
		if not pair.begins_with("\""):
			continue
		var colon: int = pair.find("\":")
		if colon <= 0:
			continue
		var key: String = pair.substr(1, colon - 1)
		var value: String = pair.substr(colon + 2).strip_edges()
		if key == "params":
			out[key] = ", ".join(_param_words(value))
		else:
			out[key] = _unquoted(value)
	return out


## The `"key": value` entries of the dictionary argument that starts on `from_index`, read down to
## the line that closes it. Only the entries a Define row shows are kept, and `params` is folded
## into the one phrase the row prints ("target: Node").
static func _dictionary_entries(lines: PackedStringArray, from_index: int) -> Dictionary:
	var out: Dictionary = {}
	var params: PackedStringArray = PackedStringArray()
	var index: int = from_index
	var depth: int = 0
	while index < lines.size():
		var text: String = lines[index]
		depth += text.count("{") - text.count("}")
		var statement: String = text.strip_edges()
		var colon: int = statement.find("\":")
		if colon > 0 and statement.begins_with("\""):
			var key: String = statement.substr(1, colon - 1)
			var value: String = statement.substr(colon + 2).strip_edges().trim_suffix(",")
			if key == "params":
				params.append_array(_param_words(value))
			elif not out.has(key):
				out[key] = _unquoted(value)
		if index > from_index and depth <= 0:
			break
		index += 1
	if not params.is_empty():
		out["params"] = ", ".join(params)
	return out


## "target: Node" for each `{"id": "target", "type": "Node"}` written on one line. A params list
## spelled some other way simply names no inputs, which says less rather than something wrong.
static func _param_words(value: String) -> PackedStringArray:
	var words: PackedStringArray = PackedStringArray()
	var rest: String = value
	while true:
		var open_at: int = rest.find("{")
		if open_at < 0:
			break
		var close_at: int = rest.find("}", open_at)
		if close_at < 0:
			break
		var entry: String = rest.substr(open_at + 1, close_at - open_at - 1)
		rest = rest.substr(close_at + 1)
		var id_text: String = _entry_value(entry, "id")
		var type_text: String = _entry_value(entry, "type")
		if id_text.is_empty():
			continue
		words.append(id_text if type_text.is_empty() else "%s: %s" % [id_text, type_text])
	return words


## The value of one `"key": "value"` pair inside a flat dictionary body, "" when it is not there.
static func _entry_value(entry: String, key: String) -> String:
	var head: String = "\"%s\":" % key
	var at: int = entry.find(head)
	if at < 0:
		return ""
	var rest: String = entry.substr(at + head.length()).strip_edges()
	var comma: int = rest.find(",")
	if comma >= 0:
		rest = rest.substr(0, comma)
	return _unquoted(rest)


## {name: true} for each function whose own body calls it. Recursion is the one shape a reader has
## to be told about, and the call row is where telling them helps.
static func recursive_functions(lines: PackedStringArray) -> Dictionary:
	var found: Dictionary = {}
	for index: int in lines.size():
		var head: Dictionary = _function_header(lines[index])
		if head.is_empty():
			continue
		var name: String = str(head.get("name", ""))
		for body_line: String in _body_lines(lines, index):
			if body_line.contains("%s(" % name) and not body_line.strip_edges().begins_with("#"):
				found[name] = true
				break
	return found


## W16. The object a published row belongs to: the provider the module writes it under, else the
## first half of an id spelled "Provider/Name". "" when neither is there.
static func row_provider(row: Dictionary) -> String:
	var provider: String = str(row.get("provider", "")).strip_edges()
	if not provider.is_empty():
		return provider
	var row_id: String = str(row.get("id", ""))
	var at: int = row_id.find("/")
	return row_id.substr(0, at) if at > 0 else ""


## W16. "Define condition Is Pinned" - the lead of a Define row, in the words a pack's own Define
## rows use. Untranslated on purpose: the caller translates the two words it owns.
static func define_lead_parts(row: Dictionary) -> PackedStringArray:
	var name: String = str(row.get("name", ""))
	if name.is_empty():
		name = str(row.get("id", "")).get_slice("/", 1)
	return PackedStringArray([str(row.get("kind", "")), name])


## W16. The receipts a Define row carries after its name: the id it is addressed by, the category it
## is filed under, and the values it takes. Each half is dropped when the module did not write it.
static func define_detail(row: Dictionary, category_word: String, input_word: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var row_id: String = str(row.get("id", "")).strip_edges()
	if not row_id.is_empty():
		parts.append(row_id)
	var category: String = str(row.get("category", "")).strip_edges()
	if not category.is_empty():
		parts.append("%s %s" % [category_word, category])
	var inputs: String = str(row.get("inputs", "")).strip_edges()
	if not inputs.is_empty():
		parts.append("%s %s" % [input_word, inputs])
	return " · ".join(parts)


# ── Shared reading of the file's shape ────────────────────────────────────────────────────────


## {name, params} for a `func` / `static func` header line, {} for anything else.
static func _function_header(line: String) -> Dictionary:
	var text: String = line
	if text.begins_with("static func "):
		text = text.substr(12)
	elif text.begins_with("func "):
		text = text.substr(5)
	else:
		return {}
	var open_at: int = text.find("(")
	if open_at <= 0:
		return {}
	var name: String = text.substr(0, open_at).strip_edges()
	if not _is_plain_name(name):
		return {}
	var close_at: int = text.rfind(")")
	var inner: String = text.substr(open_at + 1, maxi(close_at - open_at - 1, 0))
	var params: PackedStringArray = PackedStringArray()
	for piece: String in inner.split(","):
		var bare: String = piece.strip_edges()
		if bare.is_empty():
			continue
		var stop: int = bare.find(":")
		if stop < 0:
			stop = bare.find("=")
		params.append((bare if stop < 0 else bare.substr(0, stop)).strip_edges())
	return {"name": name, "params": params}


## The indented lines of the function whose header is at `header_index`.
static func _body_lines(lines: PackedStringArray, header_index: int) -> PackedStringArray:
	var body: PackedStringArray = PackedStringArray()
	for index: int in range(header_index + 1, lines.size()):
		var line: String = lines[index]
		if line.strip_edges().is_empty():
			continue
		if not line.begins_with("\t"):
			break
		body.append(line)
	return body


## True when the file extends `wanted` (with or without a class_name above it).
static func _extends_class(lines: PackedStringArray, wanted: String) -> bool:
	for line: String in lines:
		if line.begins_with("extends "):
			return line.substr(8).strip_edges() == wanted
	return false


## The identifier a declaration starts with, "" when the line does not start with one.
static func _leading_name(text: String) -> String:
	var bare: String = text.strip_edges()
	var stop: int = bare.length()
	for index: int in bare.length():
		var character: String = bare[index]
		if character == ":" or character == " " or character == "=":
			stop = index
			break
	var name: String = bare.substr(0, stop)
	return name if _is_plain_name(name) else ""


## True for a bare identifier - no dot, no bracket, no call.
static func _is_plain_name(text: String) -> bool:
	var bare: String = text.strip_edges()
	return not bare.is_empty() and bare.is_valid_identifier()


## A quoted literal without its quotes; anything else unchanged.
static func _unquoted(text: String) -> String:
	var bare: String = text.strip_edges().trim_suffix(",").strip_edges()
	if bare.length() >= 2 and bare.begins_with("\"") and bare.ends_with("\""):
		return bare.substr(1, bare.length() - 2)
	return bare
