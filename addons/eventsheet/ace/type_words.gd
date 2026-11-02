# EventSheet - Godot's type errors, said plainly
# One table from the analyzer's messages to a sentence a person who has never read a script can act
# on, and one set of words for the kinds of value (whole number, text, two numbers, a colour, a node).
# Every pattern here was produced on the engine this plugin ships against and is pinned by a test that
# runs the message again; a message that matches nothing is shown exactly as Godot wrote it, never
# paraphrased into a claim nobody checked.
@tool
class_name EventSheetTypeWords
extends RefCounted


## A kind of value said the way a sentence says it, from the type name Godot printed for it.
static func kind_words(type_name: String) -> String:
	match type_name.strip_edges():
		"int":
			return EventSheetL10n.translate("a whole number")
		"float":
			return EventSheetL10n.translate("a number")
		"bool":
			return EventSheetL10n.translate("true or false")
		"String", "StringName":
			return EventSheetL10n.translate("text")
		"Vector2":
			return EventSheetL10n.translate("two numbers (Vector2)")
		"Vector2i":
			return EventSheetL10n.translate("two whole numbers (Vector2i)")
		"Vector3":
			return EventSheetL10n.translate("three numbers (Vector3)")
		"Color":
			return EventSheetL10n.translate("a colour")
		"NodePath":
			return EventSheetL10n.translate("a node path")
		"Array":
			return EventSheetL10n.translate("a list")
		"Dictionary":
			return EventSheetL10n.translate("a dictionary")
		"null", "Nil", "void":
			return EventSheetL10n.translate("nothing")
	var name_text: String = type_name.strip_edges()
	if name_text.begins_with("Array[") or (name_text.begins_with("Packed") and name_text.ends_with("Array")):
		return EventSheetL10n.translate("a list")
	if ClassDB.class_exists(name_text) and ClassDB.is_parent_class(name_text, "Node"):
		return EventSheetL10n.translate("a node (%s)") % name_text
	return name_text


## What to write instead, for a slot that wants `type_name`.
static func advice_for(type_name: String) -> String:
	match type_name.strip_edges():
		"int", "float":
			return EventSheetL10n.translate("Write a number, or an expression that gives a number.")
		"String", "StringName":
			return EventSheetL10n.translate("Write text in quotes, or put the value in str(...) to turn it into text.")
		"bool":
			return EventSheetL10n.translate("Write true or false, or a question that gives one.")
		"Vector2":
			return EventSheetL10n.translate("Write Vector2(x, y), or a value that gives a Vector2.")
		"Vector2i":
			return EventSheetL10n.translate("Write Vector2i(x, y) with whole numbers, or a value that gives a Vector2i.")
		"Color":
			return EventSheetL10n.translate("Write a Color, like Color(1, 0.5, 0), or a value that gives one.")
	var name_text: String = type_name.strip_edges()
	if ClassDB.class_exists(name_text) and ClassDB.is_parent_class(name_text, "Node"):
		return EventSheetL10n.translate("Write a node, like $Name, or a value that gives one.")
	return ""


## The patterns, each as {regex, id}. The first group of every pattern is named by what it captures.
const _PATTERNS: Array[Array] = [
	["assign", "^Cannot assign a value of type \"(?<from>[^\"]+)\" as \"(?<to>[^\"]+)\"\\.$"],
	["assigned", "^Value of type \"(?<from>[^\"]+)\" cannot be assigned to a variable of type \"(?<to>[^\"]+)\"\\.$"],
	["operands", "^Invalid operands \"(?<a>[^\"]+)\" and \"(?<b>[^\"]+)\" for \"(?<op>[^\"]+)\" operator\\.$"],
	["many", "^Too many arguments for \"(?<fn>[^\"(]+)\\(\\)\" call\\. Expected at most (?<want>\\d+) but received (?<got>\\d+)\\.$"],
	["few", "^Too few arguments for \"(?<fn>[^\"(]+)\\(\\)\" call\\. Expected at least (?<want>\\d+) but received (?<got>\\d+)\\.$"],
	["argument", "^Invalid argument for \"(?<fn>[^\"(]+)\\(\\)\" function: argument (?<n>\\d+) should be \"(?<want>[^\"]+)\" but is \"(?<got>[^\"]+)\"\\.$"],
	["pass", "^Cannot pass a value of type \"(?<from>[^\"]+)\" as \"(?<to>[^\"]+)\"\\.$"],
	["member", "^Cannot find member \"(?<member>[^\"]+)\" in base \"(?<base>[^\"]+)\"\\.$"],
]


## The message read against the table: {id, fields} or {} for a message with no plain form.
static func recognise(message: String) -> Dictionary:
	for pattern: Array in _PATTERNS:
		var found: RegExMatch = RegEx.create_from_string(str(pattern[1])).search(message.strip_edges())
		if found == null:
			continue
		var fields: Dictionary = {}
		for group_name: String in found.names:
			fields[group_name] = found.get_string(group_name)
		return {"id": str(pattern[0]), "fields": fields}
	return {}


## Which of several messages about one line should speak. The engine says an assignment twice and a
## wrong argument twice, in two phrasings; the call-shaped one names the function, so it leads.
static func lead_message(messages: Array) -> String:
	var best: String = ""
	var best_rank: int = 99
	for message: Variant in messages:
		var text: String = str(message)
		var recognised: Dictionary = recognise(text)
		var rank: int = 50
		match str(recognised.get("id", "")):
			"argument":
				rank = 0
			"many", "few":
				rank = 1
			"operands":
				rank = 2
			"member":
				rank = 3
			"assign", "assigned":
				rank = 4
			"pass":
				rank = 5
		if rank < best_rank:
			best_rank = rank
			best = text
	return best


## The sentence for one message. `context` holds what the message cannot say for itself:
##   target   the name being assigned to (`score`), or ""
##   value    the text of the field that was typed
##   code     the line of GDScript the field became
##   sheet    the sheet, for a function's own parameter names
## Returns {head, body} - both empty when the table has no plain form for it (the caller then shows the
## message as Godot wrote it).
static func sentence(message: String, context: Dictionary) -> Dictionary:
	var recognised: Dictionary = recognise(message)
	if recognised.is_empty():
		return {}
	var fields: Dictionary = recognised["fields"]
	var value_text: String = str(context.get("value", "")).strip_edges()
	match str(recognised["id"]):
		"assign", "assigned", "pass":
			var wanted: String = str(fields.get("to", ""))
			var got: String = str(fields.get("from", ""))
			var target: String = str(context.get("target", ""))
			var head: String = EventSheetL10n.translate("%s holds %s.") % [target, kind_words(wanted)] \
				if not target.is_empty() else EventSheetL10n.translate("This takes %s.") % kind_words(wanted)
			var body: String = EventSheetL10n.translate("%s is %s.") % [_short(value_text), kind_words(got)]
			var advice: String = advice_for(wanted)
			return {"head": head, "body": body + (" " + advice if not advice.is_empty() else "")}
		"operands":
			var operator_text: String = str(fields.get("op", ""))
			var sides: Array = _sides_of(str(context.get("code", "")), operator_text)
			var left_kind: String = kind_words(str(fields.get("a", "")))
			var right_kind: String = kind_words(str(fields.get("b", "")))
			if sides.size() == 2 and not str(sides[0]).is_empty() and not str(sides[1]).is_empty():
				return {
					"head": EventSheetL10n.translate("%s is %s.") % [_short(str(sides[0])), left_kind],
					"body": EventSheetL10n.translate("It cannot be used with \"%s\" against %s, which is %s. Both sides need the same kind of value.") % [
						operator_text, _short(str(sides[1])), right_kind],
				}
			return {
				"head": EventSheetL10n.translate("%s and %s do not mix.") % [left_kind, right_kind],
				"body": EventSheetL10n.translate("\"%s\" needs the same kind of value on both sides.") % operator_text,
			}
		"many", "few":
			var function_name: String = str(fields.get("fn", ""))
			var wanted_count: int = int(fields.get("want", "0"))
			var got_count: int = int(fields.get("got", "0"))
			var signature: String = function_signature(context.get("sheet", null) as EventSheetResource, function_name)
			var takes: String = EventSheetL10n.translate("%s takes %d value(s)") % [function_name, wanted_count]
			var head_text: String = takes + (" " + signature if not signature.is_empty() else "") + "."
			var tail: String = EventSheetL10n.translate("This gives %d. Remove the extra ones, or add a parameter to %s.") % [got_count, function_name] \
				if str(recognised["id"]) == "many" else EventSheetL10n.translate("This gives %d. Add the missing ones, or remove a parameter from %s.") % [got_count, function_name]
			return {"head": head_text, "body": tail}
		"argument":
			var function_label: String = str(fields.get("fn", ""))
			var position: int = int(fields.get("n", "1"))
			var parameter_name: String = _parameter_name(context.get("sheet", null) as EventSheetResource, function_label, position)
			var arguments: PackedStringArray = split_top_level(value_text)
			var given: String = _short(arguments[position - 1].strip_edges()) if position - 1 < arguments.size() else _short(value_text)
			var subject: String = EventSheetL10n.translate("%s's %s") % [function_label, parameter_name] if not parameter_name.is_empty() \
				else EventSheetL10n.translate("%s's value %d") % [function_label, position]
			return {
				"head": EventSheetL10n.translate("%s is %s.") % [subject, kind_words(str(fields.get("want", "")))],
				"body": EventSheetL10n.translate("%s is %s.") % [given, kind_words(str(fields.get("got", "")))]
					+ (" " + advice_for(str(fields.get("want", ""))) if not advice_for(str(fields.get("want", ""))).is_empty() else ""),
			}
		"member":
			var member: String = str(fields.get("member", ""))
			var base: String = str(fields.get("base", ""))
			return {
				"head": EventSheetL10n.translate("%s has no %s.") % [base, member],
				"body": EventSheetL10n.translate("Check the spelling of %s.") % member,
			}
	return {}


## `(amount: int, label: String)` for a sheet function, or "" when the sheet has none by that name.
static func function_signature(sheet: EventSheetResource, function_name: String) -> String:
	var event_function: EventFunction = _function_named(sheet, function_name)
	if event_function == null:
		return ""
	var parts: PackedStringArray = PackedStringArray()
	for param: ACEParam in event_function.params:
		if param != null and not param.id.is_empty():
			parts.append(param.id if param.type_name.is_empty() else "%s: %s" % [param.id, param.type_name])
	if event_function.params.is_empty():
		for parameter: String in event_function.parameters:
			if not parameter.strip_edges().is_empty():
				parts.append(parameter.strip_edges())
	return "(%s)" % ", ".join(parts)


static func _function_named(sheet: EventSheetResource, function_name: String) -> EventFunction:
	if sheet == null:
		return null
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == function_name:
			return entry as EventFunction
	return null


static func _parameter_name(sheet: EventSheetResource, function_name: String, position: int) -> String:
	var event_function: EventFunction = _function_named(sheet, function_name)
	if event_function == null:
		return ""
	var named: Array[String] = []
	for param: ACEParam in event_function.params:
		if param != null and not param.id.is_empty():
			named.append(param.id)
	if event_function.params.is_empty():
		for parameter: String in event_function.parameters:
			named.append(parameter.get_slice("=", 0).get_slice(":", 0).strip_edges())
	return named[position - 1] if position >= 1 and position <= named.size() else ""


## The two sides of `operator_text` in a line of code, or [] when it does not split cleanly (two
## operators, or none at the top level).
static func _sides_of(code: String, operator_text: String) -> Array:
	var spaced: String = " %s " % operator_text
	var at: int = code.find(spaced)
	if at < 0 or code.find(spaced, at + 1) >= 0:
		return []
	return [code.substr(0, at).strip_edges(), code.substr(at + spaced.length()).strip_edges()]


## A value shortened for a sentence.
static func _short(text: String) -> String:
	return text if text.length() <= 40 else text.left(37) + "..."


## `text` split at the commas that sit outside every bracket and string - the argument list of a call.
static func split_top_level(text: String) -> PackedStringArray:
	var parts: PackedStringArray = PackedStringArray()
	var depth: int = 0
	var quote: String = ""
	var start: int = 0
	var index: int = 0
	while index < text.length():
		var character: String = text[index]
		if not quote.is_empty():
			if character == "\\":
				index += 1
			elif character == quote:
				quote = ""
		elif character == "\"" or character == "'":
			quote = character
		elif character in "([{":
			depth += 1
		elif character in ")]}":
			depth -= 1
		elif character == "," and depth == 0:
			parts.append(text.substr(start, index - start))
			start = index + 1
		index += 1
	parts.append(text.substr(start))
	return parts
