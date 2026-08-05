# EventSheet - "this generic call looks like one of your verbs".
#
# A row that reached the sheet as a raw Call Method - hand-written code that was lifted, or a
# call typed before the class was scanned - can often be named: `$Inventory.add_item("potion", 1)`
# IS the Inventory pack's "Add Item". This offers that name and a one-click conversion.
#
# WHY THE IMPORTER DOES NOT DO THIS. Teaching the lifter to match project vocabulary was
# considered and rejected. A lift is a pure function of the file's bytes today; consulting
# the vocabulary would make it depend on mutable editor state (the class scan, reflection
# caches, and per-verb hidden flags), so the same file would lift differently on two
# machines. And the drift audit that would be cited as proof compares BYTES: a row that
# silently changed which verb it names re-emits identical bytes, so the gate cannot see the
# damage. Attribution is therefore a USER ACT - the tool offers, the user decides, and the
# ordinary apply path bakes the template exactly as it does for any picked verb.
#
# Conservative by the same law as the rename suggester: exactly one candidate or nothing.
@tool
class_name EventSheetVerbSuggestion
extends RefCounted


## The class a call's target expression names, or "" when it is not a plain reference.
## `$Inventory` / `$Player/Inventory` / `Inventory` / `%Inventory` all name Inventory; an
## expression with a call or an index in it names nothing (we will not guess through it).
static func class_from_target(target: String) -> String:
	var text: String = target.strip_edges()
	if text.is_empty():
		return ""
	if text.contains("(") or text.contains("[") or text.contains(" "):
		return ""
	text = text.trim_prefix("$").trim_prefix("%")
	if text.contains("/"):
		text = text.get_slice("/", text.get_slice_count("/") - 1)
	if text.is_empty() or not text[0].to_upper() == text[0]:
		return ""  # a lowercase head is a variable, not a class/behaviour node
	for character in text:
		if not (character.is_valid_identifier() or character == "_"):
			return ""
	return text if text.is_valid_identifier() else ""


## Splits a call's argument text into top-level arguments, respecting quotes, parentheses and
## brackets: `"a, b", Vector2(1, 2), [3, 4]` is THREE arguments. Static + pure. An empty or
## whitespace-only argument list yields [].
static func split_arguments(args: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var current: String = ""
	var depth: int = 0
	var quote: String = ""
	for index: int in range(args.length()):
		var character: String = args[index]
		if not quote.is_empty():
			current += character
			# A quote closes only when it is not escaped.
			if character == quote and (index == 0 or args[index - 1] != "\\"):
				quote = ""
			continue
		match character:
			"\"", "'":
				quote = character
				current += character
			"(", "[", "{":
				depth += 1
				current += character
			")", "]", "}":
				depth -= 1
				current += character
			",":
				if depth == 0:
					out.append(current.strip_edges())
					current = ""
				else:
					current += character
			_:
				current += character
	if not current.strip_edges().is_empty():
		out.append(current.strip_edges())
	return out


## The single project verb a generic call matches, or {} when the answer is not certain.
## Returns {provider_id, ace_id, display_name, arguments} - `arguments` are the split
## argument expressions, ready to map onto the verb's parameters positionally.
##
## `candidates` is the vocabulary to search: an Array of ACEDefinition. Callers pass the
## project's own verbs (see EventSheetProjectScanner + EventSheetClassDBSource), which keeps
## this function pure and testable without a project.
static func suggest(target: String, method: String, args: String, candidates: Array) -> Dictionary:
	var class_id: String = class_from_target(target)
	var member: String = method.strip_edges()
	if class_id.is_empty() or member.is_empty():
		return {}
	var arguments: PackedStringArray = split_arguments(args)
	var wanted_id: String = "method:%s" % member
	var found: Dictionary = {}
	for definition: ACEDefinition in candidates:
		if definition == null or str(definition.provider_id) != class_id or str(definition.id) != wanted_id:
			continue
		# Arity must agree exactly. A mismatch means this is a different overload or the
		# member changed, and silently dropping or inventing an argument would corrupt the row.
		if definition.parameters.size() != arguments.size():
			continue
		if not found.is_empty():
			return {}  # two candidates: the tool does not actually know
		found = {
			"provider_id": str(definition.provider_id),
			"ace_id": str(definition.id),
			"display_name": str(definition.display_name),
			"arguments": arguments,
		}
	return found


## The parameter values for a converted row: each split argument mapped positionally onto the
## verb's own parameter ids. {} when the counts disagree (the caller should not convert).
static func mapped_params(definition: ACEDefinition, arguments: PackedStringArray) -> Dictionary:
	if definition == null or definition.parameters.size() != arguments.size():
		return {}
	var params: Dictionary = {}
	for index: int in range(arguments.size()):
		var parameter: Variant = definition.parameters[index]
		if not (parameter is Dictionary):
			return {}
		var id: String = str((parameter as Dictionary).get("id", ""))
		if id.is_empty():
			return {}
		params[id] = arguments[index]
	return params
