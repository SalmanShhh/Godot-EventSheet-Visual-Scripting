@tool
class_name EventSheetExpressionWalk
extends RefCounted

# Reading an expression the way Godot's own completion does: where is the caret, what is in front of
# the dot, and what TYPE is that?
#
# Everything here is a pure function of the text before the caret and of what the sheet (and the
# scene it is attached to) declare. It lists nothing itself: it answers "the thing before this dot is
# a SpriteFrames", and EventSheetMemberCatalog says what a SpriteFrames has. A step it cannot type -
# an untyped variable, a Variant return, a node the open scene does not hold - answers `known: false`,
# which completion turns into an honest "worked out while the game runs" rather than a guess.

const MemberCatalog := preload("res://addons/eventsheet/ace/member_catalog.gd")
const ClassReference := preload("res://addons/eventsheet/ace/class_reference.gd")

## How deep resolving a variable's own default may recurse (a default that names another variable).
const MAX_DEPTH := 4


# ── Reading the text ─────────────────────────────────────────────────────────────────────


## One left-to-right pass over the text before the caret: the brackets still open (each with where it
## opened and how many top-level commas followed it), and the string literal the caret is inside, if
## any. {"stack": [{open, at, commas}], "quote": String, "quote_at": int}.
static func scan(text: String) -> Dictionary:
	var stack: Array = []
	var quote: String = ""
	var quote_at: int = -1
	var index: int = 0
	var length: int = text.length()
	while index < length:
		var character: String = text[index]
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if character == quote:
				quote = ""
			index += 1
			continue
		if character == "\"" or character == "'":
			quote = character
			quote_at = index
		elif character == "(" or character == "[" or character == "{":
			stack.append({"open": character, "at": index, "commas": 0})
		elif character == ")" or character == "]" or character == "}":
			if not stack.is_empty():
				stack.pop_back()
		elif character == ",":
			if not stack.is_empty():
				(stack[stack.size() - 1] as Dictionary)["commas"] = int((stack[stack.size() - 1] as Dictionary)["commas"]) + 1
		elif character == "#":
			break
		index += 1
	return {"stack": stack, "quote": quote, "quote_at": quote_at}


static func _is_word(character: String) -> bool:
	return character == "_" or character.to_lower() != character.to_upper() or character.is_valid_int()


## The expression in front of the dot that ends `head` ("" when `head` does not end in a dot or the
## dot follows nothing readable): `$Sprite.sprite_frames.` gives `$Sprite.sprite_frames`, and
## `get_node("a").b(1).` gives `get_node("a").b(1)`.
static func receiver_before_dot(head: String) -> String:
	if not head.ends_with("."):
		return ""
	var index: int = head.length() - 1
	while index > 0:
		var character: String = head[index - 1]
		if character == ")" or character == "]" or character == "}":
			var opener: int = _matching_open(head, index - 1)
			if opener < 0:
				break
			index = opener
		elif _is_word(character) or character == ".":
			index -= 1
		elif character == "/" and _path_sigil_before(head, index - 1):
			index -= 1
		elif character == "$" or (character == "%" and not EventSheetCompletions.is_modulo_context(head.substr(0, index))):
			index -= 1
			break
		else:
			break
	var found: String = head.substr(index, head.length() - 1 - index).strip_edges()
	return "" if found.begins_with(".") else found


## True when a `$` starts the run of path characters that ends at `at`.
static func _path_sigil_before(text: String, at: int) -> bool:
	var index: int = at
	while index > 0:
		var character: String = text[index - 1]
		if character == "$":
			return true
		if not (_is_word(character) or character == "/" or character == "."):
			return false
		index -= 1
	return false


## The index of the bracket that opens the one closing at `close_at`, strings skipped. -1 when none.
static func _matching_open(text: String, close_at: int) -> int:
	var depth: int = 0
	var index: int = close_at
	var quote: String = ""
	while index >= 0:
		var character: String = text[index]
		if not quote.is_empty():
			if character == quote and (index == 0 or text[index - 1] != "\\"):
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character == ")" or character == "]" or character == "}":
			depth += 1
		elif character == "(" or character == "[" or character == "{":
			depth -= 1
			if depth == 0:
				return index
		index -= 1
	return -1


## The call the caret is inside: {"callee": name, "receiver": expression before its dot (or ""),
## "arg": index of the argument under the caret, "open_at": index of the "("} - or {} when the caret
## is not inside a call's parentheses.
static func call_context(text_before_caret: String) -> Dictionary:
	var scanned: Dictionary = scan(text_before_caret)
	var stack: Array = scanned["stack"]
	var level: int = stack.size() - 1
	while level >= 0 and str((stack[level] as Dictionary)["open"]) != "(":
		level -= 1
	if level < 0:
		return {}
	var frame: Dictionary = stack[level]
	var open_at: int = int(frame["at"])
	var name_end: int = open_at
	var name_start: int = name_end
	while name_start > 0 and _is_word(text_before_caret[name_start - 1]):
		name_start -= 1
	if name_start == name_end:
		return {}
	var receiver: String = ""
	if name_start > 0 and text_before_caret[name_start - 1] == ".":
		receiver = receiver_before_dot(text_before_caret.substr(0, name_start))
	return {"callee": text_before_caret.substr(name_start, name_end - name_start), "receiver": receiver,
		"arg": int(frame["commas"]) if level == stack.size() - 1 else int(frame["commas"]), "open_at": open_at,
		"direct": level == stack.size() - 1}


## The string literal the caret is inside, as {"text": what is typed inside the quotes so far,
## "quote": the quote character, "call": the call_context of the call whose argument it is}, or {}
## when the caret is not inside a string.
static func string_context(text_before_caret: String) -> Dictionary:
	var scanned: Dictionary = scan(text_before_caret)
	var quote: String = str(scanned["quote"])
	if quote.is_empty():
		return {}
	var quote_at: int = int(scanned["quote_at"])
	var before_quote: String = text_before_caret.substr(0, quote_at)
	# A StringName or NodePath literal wears a sigil (&"jump", ^"A/B"): it is the quote that counts.
	return {"text": text_before_caret.substr(quote_at + 1), "quote": quote, "call": call_context(before_quote),
		"before": before_quote}


# ── Typing the receiver ──────────────────────────────────────────────────────────────────


## What `expression` is, as {"type": String, "known": bool, "static": bool}. `static` means the
## expression names a TYPE (Vector2, Input, Node), whose constants and static functions follow the
## dot, rather than a value. `locals` is {name: type} for the names the event being edited declares.
static func resolve(expression: String, sheet: EventSheetResource, locals: Dictionary = {}, depth: int = 0) -> Dictionary:
	var unknown: Dictionary = {"type": "", "known": false, "static": false}
	var text: String = expression.strip_edges()
	if text.is_empty() or depth > MAX_DEPTH:
		return unknown
	var segments: PackedStringArray = _segments(text)
	if segments.is_empty():
		return unknown
	var current: Dictionary = _resolve_root(segments[0], sheet, locals, depth)
	for index: int in range(1, segments.size()):
		if not bool(current.get("known", false)):
			return unknown
		current = _step(current, segments[index])
	return current if bool(current.get("known", false)) else unknown


## The text split at its top-level dots, brackets and strings kept whole.
static func _segments(text: String) -> PackedStringArray:
	var parts: PackedStringArray = PackedStringArray()
	var depth: int = 0
	var quote: String = ""
	var start: int = 0
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if not quote.is_empty():
			if character == "\\":
				index += 2
				continue
			if character == quote:
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
		elif character == "." and depth == 0 and index > start:
			# A number's decimal point is no member access.
			if not (text.substr(start, index - start).is_valid_int() and index + 1 < text.length() and text[index + 1].is_valid_int()):
				parts.append(text.substr(start, index - start))
				start = index + 1
		index += 1
	parts.append(text.substr(start))
	return parts


## The identifier (or `$path`, `%name`) a segment starts with, and what follows it ("(...)" or "[...]").
static func _head_and_tail(segment: String) -> Array:
	var text: String = segment.strip_edges()
	var end: int = 0
	if text.begins_with("$") or text.begins_with("%"):
		end = 1
		if text.length() > 1 and (text[1] == "\"" or text[1] == "'"):
			var close: int = text.find(text[1], 2)
			end = close + 1 if close > 0 else text.length()
		else:
			while end < text.length() and (_is_word(text[end]) or text[end] == "/"):
				end += 1
	else:
		while end < text.length() and _is_word(text[end]):
			end += 1
	return [text.substr(0, end), text.substr(end)]


static func _resolve_root(segment: String, sheet: EventSheetResource, locals: Dictionary, depth: int) -> Dictionary:
	var unknown: Dictionary = {"type": "", "known": false, "static": false}
	var parts: Array = _head_and_tail(segment)
	var head: String = parts[0]
	var tail: String = parts[1].strip_edges()
	if head.is_empty():
		var literal: String = _literal_type(segment.strip_edges())
		return {"type": literal, "known": true, "static": false} if not literal.is_empty() else unknown
	if head.begins_with("$") or head.begins_with("%"):
		return _apply_tail(_node_type(head), tail)
	var host: String = sheet.host_class if sheet != null and ClassDB.class_exists(sheet.host_class) else ""
	if head == "self":
		return _apply_tail({"type": host, "known": not host.is_empty(), "static": false}, tail)
	if head == "host" and sheet != null and sheet.behavior_mode:
		return _apply_tail({"type": host, "known": not host.is_empty(), "static": false}, tail)
	if locals.has(head):
		var local_type: String = _settled(str(locals[head]), depth)
		return _apply_tail({"type": local_type, "known": not local_type.is_empty(), "static": false}, tail)
	var symbols: Dictionary = EventSheetCompletions.symbol_types(sheet)
	if symbols.has(head):
		var symbol: Dictionary = symbols[head]
		if bool(symbol.get("function", false)):
			return _apply_tail({"type": str(symbol.get("type", "")), "known": not str(symbol.get("type", "")).is_empty(), "static": false}, tail, true)
		var symbol_type: String = _settled(str(symbol.get("type", "")), depth)
		return _apply_tail({"type": symbol_type, "known": not symbol_type.is_empty(), "static": false}, tail)
	if sheet != null:
		for enum_row: EnumRow in EventSheetCompletions.sheet_enums_of(sheet):
			if enum_row.enum_name == head:
				return {"type": MemberCatalog.ENUM_PREFIX + head, "known": true, "static": false}
	if not host.is_empty():
		var host_member: String = MemberCatalog.member_type(host, head)
		if not host_member.is_empty():
			return _apply_tail({"type": host_member, "known": true, "static": false}, tail, MemberCatalog.method_info(host, head).size() > 0)
	# A singleton is a value (Input.is_action_pressed is an instance call), though it is also a class.
	if Engine.has_singleton(head):
		var singleton: Object = Engine.get_singleton(head)
		var singleton_class: String = singleton.get_class() if singleton != null else ""
		return _apply_tail({"type": singleton_class, "known": ClassDB.class_exists(singleton_class), "static": false}, tail)
	if MemberCatalog.knows(head):
		if tail.begins_with("("):
			# Vector2(1, 2) is a Vector2; Node.new() a Node (handled in _step); the call is the value.
			return _apply_tail({"type": head, "known": true, "static": false}, tail.substr(_group_end(tail)).strip_edges())
		return _apply_tail({"type": head, "known": true, "static": true}, tail)
	var autoload_path: String = _autoload_script(head)
	if not autoload_path.is_empty():
		return _apply_tail({"type": MemberCatalog.SCRIPT_PREFIX + autoload_path, "known": true, "static": false}, tail)
	var class_path: String = EventSheetCompletions.global_class_path(head)
	if not class_path.is_empty():
		return _apply_tail({"type": MemberCatalog.SCRIPT_PREFIX + class_path, "known": true, "static": true}, tail)
	return unknown


## A variable's recorded type, made walkable: a generic suffix kept (Array[int] still indexes to
## int), "Variant" and "" unknown.
static func _settled(type_text: String, _depth: int) -> String:
	var cleaned: String = type_text.strip_edges()
	return "" if cleaned in ["", "Variant", "void"] else cleaned


## The index just past the bracket group that opens at the start of `text`.
static func _group_end(text: String) -> int:
	var depth: int = 0
	var quote: String = ""
	for index: int in range(text.length()):
		var character: String = text[index]
		if not quote.is_empty():
			if character == quote and text[index - 1] != "\\":
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character == "(" or character == "[" or character == "{":
			depth += 1
		elif character == ")" or character == "]" or character == "}":
			depth -= 1
			if depth == 0:
				return index + 1
	return text.length()


## Applies what trails a name: a call (the value is what the name RETURNS when `as_call`, else the
## call is a construction) and indexing, which loses the type unless the collection is typed.
static func _apply_tail(current: Dictionary, tail: String, _is_call: bool = false) -> Dictionary:
	var unknown: Dictionary = {"type": "", "known": false, "static": false}
	var rest: String = tail.strip_edges()
	var result: Dictionary = current
	while not rest.is_empty():
		if not bool(result.get("known", false)):
			return unknown
		var end: int = _group_end(rest)
		if rest.begins_with("["):
			var element: String = MemberCatalog.element_of(str(result.get("type", "")))
			if element.is_empty():
				return unknown
			result = {"type": element, "known": true, "static": false}
		elif not rest.begins_with("("):
			return unknown
		rest = rest.substr(end).strip_edges()
	return result


## One `.name`, `.name(...)` or `.name[...]` step from `current`.
static func _step(current: Dictionary, segment: String) -> Dictionary:
	var unknown: Dictionary = {"type": "", "known": false, "static": false}
	var parts: Array = _head_and_tail(segment)
	var member: String = parts[0]
	var tail: String = parts[1].strip_edges()
	var type_text: String = str(current.get("type", ""))
	var through_statics: bool = bool(current.get("static", false))
	if member.is_empty():
		return unknown
	if through_statics and member == "new" and tail.begins_with("("):
		return _apply_tail({"type": type_text, "known": true, "static": false}, tail.substr(_group_end(tail)).strip_edges())
	if type_text.begins_with(MemberCatalog.ENUM_PREFIX):
		return unknown
	var found: String = MemberCatalog.member_type(type_text, member, through_statics)
	if found.is_empty() and through_statics:
		# A constant of an instance-typed namespace, or an engine class's enum value read off the class.
		found = MemberCatalog.member_type(type_text, member, false)
	if found.is_empty():
		return unknown
	# The value of `thing.method(...)` is what the method returns; `thing.prop` is the property's type.
	return _apply_tail({"type": found, "known": true, "static": false}, tail)


## A literal's type, "" when the text is not a plain literal.
static func _literal_type(text: String) -> String:
	if text.is_empty():
		return ""
	if text.begins_with("\"") or text.begins_with("'") or text.begins_with("&\"") or text.begins_with("^\""):
		return "String" if text[0] != "&" and text[0] != "^" else ("StringName" if text[0] == "&" else "NodePath")
	if text.begins_with("["):
		return "Array"
	if text.begins_with("{"):
		return "Dictionary"
	if text == "true" or text == "false":
		return "bool"
	if text.is_valid_int():
		return "int"
	if text.is_valid_float():
		return "float"
	return ""


## The type of a `$Path` or `%Name` in the scene the sheet is attached to: its script's class name,
## the script itself, or its engine class. Unknown when there is no scene or the node is not in it.
static func _node_type(token: String) -> Dictionary:
	var unknown: Dictionary = {"type": "", "known": false, "static": false}
	var root: Node = EventSheetCompletions.scene_root()
	if root == null:
		return unknown
	var path: String = token.substr(1).trim_prefix("\"").trim_suffix("\"").trim_prefix("'").trim_suffix("'")
	var node: Node = root.get_node_or_null(NodePath(path if token.begins_with("$") else "%" + path))
	if node == null:
		return unknown
	return {"type": type_of_node(node), "known": true, "static": false}


## What a node is, as a type descriptor: its script (by class name when it has one, else "script:path")
## or its engine class.
static func type_of_node(node: Node) -> String:
	var script: Script = node.get_script() as Script
	if script != null:
		var global_name: String = str(script.get_global_name())
		if not global_name.is_empty():
			return global_name if ClassDB.class_exists(global_name) else MemberCatalog.SCRIPT_PREFIX + script.resource_path
		if not script.resource_path.is_empty():
			return MemberCatalog.SCRIPT_PREFIX + script.resource_path
	return node.get_class()


## The script an Autoload name points at, "" when it is no script autoload.
static func _autoload_script(autoload_name: String) -> String:
	var setting: String = "autoload/%s" % autoload_name
	if not ProjectSettings.has_setting(setting):
		return ""
	var path: String = str(ProjectSettings.get_setting(setting)).trim_prefix("*")
	return path if path.ends_with(".gd") else ""


# ── The call a hint is about ─────────────────────────────────────────────────────────────


## The hint for the call the caret is inside: {"parts": PackedStringArray, "active": int, "text": String}
## or {} when the caret is in no call this can describe. parts reads `play(`, `name: StringName = &""`,
## `, custom_speed: float = 1.0`, `) -> void`; `active` is the index of the argument under the caret.
static func signature(text_before_caret: String, sheet: EventSheetResource, locals: Dictionary = {}, with_utility: bool = true) -> Dictionary:
	var call: Dictionary = call_context(text_before_caret)
	if call.is_empty():
		return {}
	var callee: String = str(call["callee"])
	var info: Dictionary = {}
	var receiver: String = str(call["receiver"])
	if not receiver.is_empty():
		var typed: Dictionary = resolve(receiver, sheet, locals)
		if bool(typed.get("known", false)):
			info = MemberCatalog.method_info(str(typed["type"]), callee, bool(typed.get("static", false)))
	else:
		info = bare_signature(callee, sheet, with_utility)
	if info.is_empty():
		return {}
	return _format(callee, info, int(call["arg"]))


## THE hint a field shows for the call the caret is in: the receiver's own signature when the call
## has one, else the plain-words line the language's well-known functions carry, else the engine's
## utility function signature. {"parts", "active", "text"} or {}.
static func hint(text_before_caret: String, sheet: EventSheetResource, locals: Dictionary = {}) -> Dictionary:
	var typed: Dictionary = signature(text_before_caret, sheet, locals, false)
	if not typed.is_empty():
		return typed
	var call: Dictionary = call_context(text_before_caret)
	if call.is_empty():
		return {}
	if str(call["receiver"]).is_empty():
		var words: String = str(load("res://addons/eventsheet/ace/gdscript_lint.gd").GDSCRIPT_GLOBAL_HINTS.get(str(call["callee"]), ""))
		if not words.is_empty():
			return {"parts": PackedStringArray([words]), "active": -1, "text": words}
	return signature(text_before_caret, sheet, locals, true)


## The signature of a call with nothing before its name: a function of the sheet, a method of its
## host class, or one of the engine's utility functions.
static func bare_signature(callee: String, sheet: EventSheetResource, with_utility: bool = true) -> Dictionary:
	if sheet != null:
		for function_resource: Variant in sheet.functions:
			var event_function: EventFunction = function_resource as EventFunction
			if event_function != null and event_function.function_name == callee:
				var args: Array = []
				for param: Variant in event_function.params:
					var typed_param: ACEParam = param as ACEParam
					if typed_param != null:
						args.append({"n": typed_param.id, "t": typed_param.type_name, "v": ""})
				var returned: String = event_function.return_type_name
				if returned.is_empty():
					returned = "void" if event_function.return_type == TYPE_NIL else type_string(event_function.return_type)
				return {"args": args, "ret": returned, "va": false}
		var host: String = sheet.host_class if ClassDB.class_exists(sheet.host_class) else ""
		if not host.is_empty():
			var host_info: Dictionary = MemberCatalog.method_info(host, callee)
			if not host_info.is_empty():
				return host_info
	var utility: Dictionary = ClassReference.utility(callee) if with_utility else {}
	if not utility.is_empty():
		var utility_args: Array = []
		for argument: Dictionary in utility.get("a", []):
			utility_args.append({"n": str(argument.get("n", "")), "t": str(argument.get("t", "")), "v": str(argument.get("v", ""))})
		return {"args": utility_args, "ret": str(utility.get("r", "")) if not str(utility.get("r", "")).is_empty() else "void", "va": bool(utility.get("va", false))}
	return {}


static func _format(callee: String, info: Dictionary, active_arg: int) -> Dictionary:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(callee + "(")
	var args: Array = info.get("args", [])
	for index: int in range(args.size()):
		var argument: Dictionary = args[index]
		var piece: String = str(argument.get("n", ""))
		if not str(argument.get("t", "")).is_empty():
			piece += ": " + str(argument["t"])
		if not str(argument.get("v", "")).is_empty():
			piece += " = " + str(argument["v"])
		parts.append(piece if index == 0 else ", " + piece)
	if bool(info.get("va", false)):
		parts.append("..." if args.is_empty() else ", ...")
	var returned: String = str(info.get("ret", ""))
	parts.append(")" if returned.is_empty() else ") -> " + returned)
	var active: int = -1
	if not args.is_empty():
		active = 1 + clampi(active_arg, 0, args.size() - 1)
	elif bool(info.get("va", false)):
		active = 1
	return {"parts": parts, "active": active, "text": "".join(parts)}


## A hint as BBCode for a rich label: the argument under the caret bold and underlined, its comma not.
static func hint_bbcode(hint: Dictionary) -> String:
	if hint.is_empty():
		return ""
	var parts: PackedStringArray = hint["parts"]
	var active: int = int(hint["active"])
	var out: String = ""
	for index: int in range(parts.size()):
		var piece: String = parts[index].replace("[", "[lb]")
		if index == active:
			var comma: String = ""
			if piece.begins_with(", "):
				comma = ", "
				piece = piece.substr(2)
			out += "%s[b][u]%s[/u][/b]" % [comma, piece]
		else:
			out += piece
	return out
