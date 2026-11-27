# EventForge - typed variables for the nodes a sheet calls, written the way a Godot user writes them.
#
# A sheet that calls a behaviour on a child node writes `$HudKit.set_text(...)`. That line works, but
# Godot cannot say what `$HudKit` is, so a hand edit gets no completion list after the dot and a typo in
# the method name is found only when the line runs. Declaring the node once, with its type,
#
#     @onready var hud_kit: HudKitBehavior = $HudKit
#
# and calling through it (`hud_kit.set_text(...)`) gives the editor everything it needs.
#
# THE COMPILER spells it (`apply`): once the whole file is in place, every `$Path.member` whose node has
# a known type is written through a variable, and one declaration per path is added under the class head.
# The type comes from the behaviour a row belongs to (a Hud Kit row is on a Hud Kit) or from what the
# sheet itself remembers (`node_variable_types`). A path with no known type keeps `$Path` as it was, and
# so does every place a variable cannot serve: a class inside the file, a static function, a class-level
# initialiser, and the handlers Godot runs before `@onready` variables are set.
#
# THE IMPORTER reads it back (`expand`): the declaration lines are taken out and each variable is put
# back as the path it stands for, so a file that says `hud_kit.set_text(...)` opens as the same rows as a
# file that says `$HudKit.set_text(...)`. The importer then writes the result and compares it with the
# file; a file that does not come back byte for byte is read as it stands, which is the way it was read
# before this existed.
#
# Reach it by path (`preload`); it has no class_name so loading it compiles nothing more.
@tool
extends RefCounted

## Handlers Godot runs before an `@onready` variable has its value, or outside the node's own scene
## (the editor asks a tool script's `_validate_property` before the node is ready). A `$Path` stays a
## path in all of these.
const EARLY_HANDLERS: PackedStringArray = [
	"_init", "_enter_tree", "_notification", "_validate_property", "_get_configuration_warnings",
	"_get", "_set", "_get_property_list", "_property_can_revert", "_property_get_revert", "_to_string",
]

## Names a variable may not take: words GDScript reserves and the global functions a line may call.
const RESERVED: PackedStringArray = [
	"and", "as", "assert", "await", "break", "breakpoint", "class", "class_name", "const", "continue",
	"elif", "else", "enum", "extends", "false", "for", "func", "if", "in", "is", "match", "not", "null",
	"or", "pass", "preload", "return", "self", "signal", "static", "super", "true", "var", "void", "while",
	"yield", "print", "prints", "printt", "range", "min", "max", "abs", "sign", "load", "str", "len", "int",
	"float", "bool", "typeof", "clamp", "lerp", "floor", "ceil", "round", "sqrt", "pow", "sin", "cos", "tan",
	"hash", "seed", "wrap", "push_error", "push_warning", "randi", "randf", "rand_range", "convert", "inst_to_dict",
	"dict_to_inst", "weakref", "is_instance_valid", "is_instance_of", "type_string", "error_string", "fmod", "log", "exp",
]

## The comment above the declarations. It tells a reader why the lines are there, and it is what marks them as
## written by the compiler: a script that declares a variable of its own by hand, even one that looks the same,
## is never read as having typed variables, so its variable stays a variable of its own.
const MARKER: String = "# Nodes this sheet calls, declared once with their type."

const _PATH: String = "[A-Za-z_][A-Za-z0-9_]*(?:/[A-Za-z_][A-Za-z0-9_]*)*"
const _DECLARATION: String = "^@onready var ([a-z_][a-z0-9_]*): ([A-Za-z_][A-Za-z0-9_]*) = (\\$" + _PATH + ")$"

static var _call_re: RegEx
static var _declaration_re: RegEx
static var _token_re: RegEx
static var _path_token_re: RegEx
static var _global_classes: Dictionary = {}
static var _global_classes_built: bool = false
## Filled by `_masked`: 1 for each line that begins inside a string running over several lines.
static var _begins_in_string: PackedByteArray = PackedByteArray()


## Rewrites `lines` in place: every `$Path.member` with a known type goes through a variable, and the
## declarations are added under the class head. `types` maps a path as written (`$HudKit`,
## `$Skater/Skateboard`) to the class its node wears. Returns where the declarations went (the 0-based line index) and how many lines
## were added, so the caller can move its source map; zero lines when nothing changed.
static func apply(lines: PackedStringArray, types: Dictionary) -> Vector2i:
	if types.is_empty():
		return Vector2i.ZERO
	var extends_at: int = _extends_line(lines)
	if extends_at < 0:
		return Vector2i.ZERO
	_prepare()
	var masked: PackedStringArray = _masked(lines)
	var eligible: PackedByteArray = _eligible_lines(lines, _begins_in_string)
	var used: PackedStringArray = PackedStringArray()
	for index: int in range(lines.size()):
		if eligible[index] == 0:
			continue
		for found: RegExMatch in _call_re.search_all(masked[index]):
			var path: String = "$" + found.get_string(1)
			if types.has(path) and not used.has(path):
				used.append(path)
	if used.is_empty():
		return Vector2i.ZERO
	var names: Dictionary = _names_for(used, masked, _reserved_by_host(lines[extends_at]))
	for index: int in range(lines.size()):
		if eligible[index] == 0:
			continue
		var line: String = lines[index]
		var found_all: Array[RegExMatch] = _call_re.search_all(masked[index])
		for at: int in range(found_all.size() - 1, -1, -1):
			var path: String = "$" + found_all[at].get_string(1)
			if not names.has(path):
				continue
			# `$Path` is replaced up to its dot: the rest of the line is untouched.
			line = line.substr(0, found_all[at].get_start()) + str(names[path]) + line.substr(found_all[at].get_end() - 1)
		lines[index] = line
	var insert_at: int = _head_end(lines, extends_at)
	var block: PackedStringArray = PackedStringArray(["", MARKER])
	for path: String in used:
		block.append("@onready var %s: %s = %s" % [names[path], types[path], path])
	for offset: int in range(block.size()):
		lines.insert(insert_at + offset, block[offset])
	return Vector2i(insert_at, block.size())


## Writes the typed variables of a sheet into its finished lines, and moves the source map (1-based inclusive line
## ranges) down by the lines added. The classes are what the sheet remembers, then what its rows say (a pack's
## verb is on that pack's node); a path two packs claim is left out, since neither is the answer.
static func write_into(lines: PackedStringArray, sheet: EventSheetResource, source_map: Array) -> void:
	var types: Dictionary = sheet.node_variable_types.duplicate()
	var conflicts: Dictionary = {}
	var from_rows: Dictionary = {}
	types_from_rows(sheet.events, from_rows, conflicts)
	for function_entry: Variant in sheet.functions:
		if function_entry is EventFunction:
			var function_rows: Array = (function_entry as EventFunction).events
			types_from_rows(function_rows if not function_rows.is_empty() else (function_entry as EventFunction).rows, from_rows, conflicts)
	for path: Variant in from_rows:
		if not types.has(path):
			types[path] = from_rows[path]
	for path: Variant in conflicts:
		types.erase(path)
	var placed: Vector2i = apply(lines, types)
	if placed.y <= 0:
		return
	for entry: Variant in source_map:
		if entry is Dictionary:
			var range_entry: Dictionary = entry as Dictionary
			if int(range_entry.get("start", 0)) >= placed.x + 1:
				range_entry["start"] = int(range_entry["start"]) + placed.y
			if int(range_entry.get("end", 0)) >= placed.x + 1:
				range_entry["end"] = int(range_entry["end"]) + placed.y


## Where the declarations go: straight under the class head, after the comment block a class may carry
## under its `extends` line (its description and annotation lines). A comment run that is followed by a
## member with no blank line between belongs to that member, so the declarations go above it instead.
static func _head_end(lines: PackedStringArray, extends_at: int) -> int:
	var at: int = extends_at + 1
	var run_end: int = at
	while run_end < lines.size() and lines[run_end].begins_with("#"):
		run_end += 1
	if run_end > at and (run_end >= lines.size() or lines[run_end].is_empty()):
		return run_end
	return at


static func _extends_line(lines: PackedStringArray) -> int:
	for index: int in range(lines.size()):
		if lines[index].begins_with("extends "):
			return index
	return -1


## The text with its declarations taken out and each variable written as the path it stands for, plus
## the class each path wears. Empty when the file has no declaration block under its class head.
static func expand(source: String) -> Dictionary:
	if not source.contains("\n@onready var "):
		return {}
	_prepare()
	var lines: PackedStringArray = source.split("\n")
	var extends_at: int = _extends_line(lines)
	if extends_at < 0:
		return {}
	var at: int = _head_end(lines, extends_at)
	if at + 1 >= lines.size() or not lines[at].is_empty() or lines[at + 1] != MARKER:
		return {}
	var paths: Dictionary = {}
	var types: Dictionary = {}
	var cursor: int = at + 2
	while cursor < lines.size():
		var found: RegExMatch = _declaration_re.search(lines[cursor])
		if found == null:
			break
		paths[found.get_string(1)] = found.get_string(3)
		types[found.get_string(3)] = found.get_string(2)
		cursor += 1
	if paths.is_empty():
		return {}
	var kept: PackedStringArray = PackedStringArray()
	kept.append_array(lines.slice(0, at))
	kept.append_array(lines.slice(cursor))
	var masked: PackedStringArray = _masked(kept)
	var eligible: PackedByteArray = _eligible_lines(kept, _begins_in_string)
	var use_re: RegEx = RegEx.new()
	use_re.compile("(?<![A-Za-z0-9_$.])(" + "|".join(PackedStringArray(paths.keys())) + ")(?=\\.[A-Za-z_])")
	for index: int in range(kept.size()):
		if eligible[index] == 0:
			continue
		var line: String = kept[index]
		var uses: Array[RegExMatch] = use_re.search_all(masked[index])
		for use_at: int in range(uses.size() - 1, -1, -1):
			line = line.substr(0, uses[use_at].get_start()) + str(paths[uses[use_at].get_string(1)]) + line.substr(uses[use_at].get_end())
		kept[index] = line
	return {"text": "\n".join(kept), "types": types}


## The classes a sheet's rows call behaviours on: a row that carries the call as its own line
## (`$HudKit.set_text(...)`) names the node, and the pack it was taken from names the class.
static func types_from_rows(rows: Array, into: Dictionary, conflicts: Dictionary) -> void:
	_prepare()
	for entry: Variant in rows:
		if entry is EventRow:
			var event_row: EventRow = entry as EventRow
			for condition: Variant in event_row.conditions:
				_note_call(condition, into, conflicts)
			for action: Variant in event_row.actions:
				_note_call(action, into, conflicts)
			types_from_rows(event_row.sub_events, into, conflicts)
		elif entry is EventGroup:
			types_from_rows((entry as EventGroup).child_rows(), into, conflicts)


static func _note_call(entry: Variant, into: Dictionary, conflicts: Dictionary) -> void:
	var provider: String = ""
	var template: String = ""
	if entry is ACEAction:
		provider = (entry as ACEAction).provider_id
		template = (entry as ACEAction).codegen_template
	elif entry is ACECondition:
		provider = (entry as ACECondition).provider_id
		template = (entry as ACECondition).codegen_template
	if template.is_empty() or not template.begins_with("$") or not _is_node_class(provider):
		return
	var found: RegExMatch = _call_re.search(template)
	if found == null or found.get_start() != 0:
		return
	var path: String = "$" + found.get_string(1)
	if into.has(path) and str(into[path]) != provider:
		conflicts[path] = true
		return
	into[path] = provider


## True for the name of a class a script publishes that stands on a node: what a pack row's provider is.
static func _is_node_class(provider: String) -> bool:
	if provider.is_empty() or provider == "Core" or provider == "Custom":
		return false
	if not _global_classes_built:
		_global_classes_built = true
		for entry: Dictionary in ProjectSettings.get_global_class_list():
			_global_classes[str(entry.get("class", ""))] = str(entry.get("base", ""))
	if not _global_classes.has(provider):
		return false
	var base: String = str(_global_classes[provider])
	var guard: int = 0
	while _global_classes.has(base) and guard < 16:
		base = str(_global_classes[base])
		guard += 1
	return ClassDB.class_exists(base) and ClassDB.is_parent_class(base, "Node")


## Forgets the project's class list, so a class added since is seen. A long-lived editor asks again after
## its scan; a one-shot tool never needs to.
static func forget_classes() -> void:
	_global_classes.clear()
	_global_classes_built = false


# ── names ─────────────────────────────────────────────────────────────────────────────


## One name per path: the node's own name in snake_case; when that is taken, the parent's name in front
## of it (`player_movement`); then `_node` after it, then a number. Taken means another path already
## has it, the file already writes it as a word of its own, or the class the file extends has a member
## by that name (so `$Name` never shadows `name`).
static func _names_for(paths: PackedStringArray, masked: PackedStringArray, host_reserved: Dictionary) -> Dictionary:
	var words: Dictionary = {}
	for text: String in masked:
		for token: RegExMatch in _token_re.search_all(_path_token_re.sub(text, " ", true)):
			words[token.get_string()] = true
	var names: Dictionary = {}
	var taken: Dictionary = {}
	for path: String in paths:
		var segments: PackedStringArray = path.trim_prefix("$").split("/")
		var candidates: PackedStringArray = PackedStringArray()
		var own: String = _snake(segments[segments.size() - 1])
		candidates.append(own)
		if segments.size() > 1:
			candidates.append(_snake(segments[segments.size() - 2]) + "_" + own)
		candidates.append(own + "_node")
		var chosen: String = ""
		for candidate: String in candidates:
			if not _is_taken(candidate, taken, words, host_reserved):
				chosen = candidate
				break
		var number: int = 2
		while chosen.is_empty():
			var numbered: String = "%s_node_%d" % [own, number]
			if not _is_taken(numbered, taken, words, host_reserved):
				chosen = numbered
			number += 1
		taken[chosen] = true
		names[path] = chosen
	return names


static func _is_taken(candidate: String, taken: Dictionary, words: Dictionary, host_reserved: Dictionary) -> bool:
	return taken.has(candidate) or words.has(candidate) or host_reserved.has(candidate) or RESERVED.has(candidate)


static func _snake(node_name: String) -> String:
	var spelled: String = node_name.to_snake_case()
	if spelled.is_empty() or spelled[0].is_valid_int():
		spelled = "node_" + spelled
	return spelled


## Members of the class the file extends, by name: a variable called one of them would hide it.
static func _reserved_by_host(extends_line: String) -> Dictionary:
	var reserved: Dictionary = {}
	var host: String = extends_line.trim_prefix("extends ").strip_edges()
	if not ClassDB.class_exists(host):
		return reserved
	for property: Dictionary in ClassDB.class_get_property_list(host):
		reserved[str(property.get("name", ""))] = true
	for method: Dictionary in ClassDB.class_get_method_list(host):
		reserved[str(method.get("name", ""))] = true
	for signal_entry: Dictionary in ClassDB.class_get_signal_list(host):
		reserved[str(signal_entry.get("name", ""))] = true
	return reserved


# ── what the text is made of ───────────────────────────────────────────────────────────


static func _prepare() -> void:
	if _call_re != null:
		return
	_call_re = RegEx.new()
	_call_re.compile("(?<![A-Za-z0-9_$.])\\$(" + _PATH + ")\\.(?=[A-Za-z_])")
	_declaration_re = RegEx.new()
	_declaration_re.compile(_DECLARATION)
	_token_re = RegEx.new()
	_token_re.compile("[A-Za-z_][A-Za-z0-9_]*")
	_path_token_re = RegEx.new()
	_path_token_re.compile("\\$[A-Za-z0-9_/]+")


## Each line with the inside of its strings and comments blanked to spaces (same length), so a search
## never lands on a word that is only text. A string that runs over several lines carries across them.
static func _masked(lines: PackedStringArray) -> PackedStringArray:
	var masked: PackedStringArray = PackedStringArray()
	_begins_in_string = PackedByteArray()
	var open_triple: String = ""
	for line: String in lines:
		_begins_in_string.append(0 if open_triple.is_empty() else 1)
		var out: String = ""
		var at: int = 0
		var size: int = line.length()
		while at < size:
			var letter: String = line[at]
			if not open_triple.is_empty():
				if line.substr(at, 3) == open_triple:
					out += "   "
					at += 3
					open_triple = ""
				else:
					out += " "
					at += 1
				continue
			if letter == "#":
				out += " ".repeat(size - at)
				break
			if letter == "\"" or letter == "'":
				if line.substr(at, 3) == letter.repeat(3):
					open_triple = letter.repeat(3)
					out += "   "
					at += 3
					continue
				out += letter
				at += 1
				while at < size and line[at] != letter:
					if line[at] == "\\" and at + 1 < size:
						out += "  "
						at += 2
					else:
						out += " "
						at += 1
				if at < size:
					out += letter
					at += 1
				continue
			out += letter
			at += 1
		masked.append(out)
	return masked


## One flag per line: 1 where a variable of the class may stand in for `$Path`: inside a plain function
## body, and nowhere else. A class written inside the file has a scope of its own, a static function and a
## class-level initialiser run without the node's variables, and the handlers in EARLY_HANDLERS run before
## they are set. `inside_string` says which lines begin inside a string that runs over several lines.
static func _eligible_lines(lines: PackedStringArray, inside_string: PackedByteArray) -> PackedByteArray:
	var flags: PackedByteArray = PackedByteArray()
	flags.resize(lines.size())
	var allowed: bool = false
	for index: int in range(lines.size()):
		var line: String = lines[index]
		# A line that begins inside a multi-line string is part of that string, whatever its first letter is.
		if inside_string[index] == 0 and not (line.is_empty() or line.begins_with("#") or line[0] == "	" or line[0] == " "):
			allowed = false
			if line.begins_with("func "):
				allowed = not EARLY_HANDLERS.has(line.substr(5).split("(")[0].strip_edges())
		flags[index] = 1 if allowed else 0
	return flags
