# EventSheet - the type check for a typed field
# The expression probe (gdscript_lint.gd) answers "does this compile". This answers the question the
# probe could not: "is this the right KIND of value". It compiles the line a field becomes inside a
# stand-in script that declares the sheet's variables and functions with the types they were declared
# with, and lets Godot's own analyzer judge it - there is no second type checker here to drift from the
# engine. What comes back is the analyzer's message (heard through a Logger while the script reloads),
# the characters of the field it is about, and a sentence in plain words (type_words.gd).
#
# A finding exists only where the TYPED stand-in fails and the same line compiles against the untyped
# one: a value that does not compile at all is the old check's business, and a stand-in that cannot be
# built says nothing instead of something false.
@tool
class_name EventSheetTypeCheck
extends RefCounted

## What a finding's level is: Godot will refuse the line / run it but not as meant / cannot be known yet.
const LEVEL_ERROR: String = "error"
const LEVEL_NOTE: String = "note"
## The typed stand-in script could not be written for a reason that is not the value's.
const LEVEL_PAUSED: String = "paused"

## The word a slot the field does not own is filled with: an untyped variable, so the field being checked
## is the only thing that can fail.
const STAND_IN: String = "__slot__"


## Hears the analyzer. Godot prints a script's parse and analyze errors through its error handler while
## `reload()` runs; a Logger added for the duration of one reload receives them with their line.
class Ear extends Logger:
	var messages: Array[Dictionary] = []
	var _thread: int = OS.get_thread_caller_id()

	func _log_error(function: String, file: String, line: int, code: String, _rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_SCRIPT or function != "GDScript::reload" \
				or not file.begins_with("gdscript://") or OS.get_thread_caller_id() != _thread:
			return
		messages.append({"line": line, "text": code.trim_prefix("Parse Error: ")})


## Loads `source` as a script and returns {ok, messages: [{line, text}]}.
static func run_probe(source: String) -> Dictionary:
	var ear: Ear = Ear.new()
	var probe: GDScript = GDScript.new()
	probe.source_code = source
	OS.add_logger(ear)
	var error: Error = probe.reload(true)
	OS.remove_logger(ear)
	return {"ok": error == OK, "messages": ear.messages}


# ── The line a field becomes ─────────────────────────────────────────────────────────────────


## A value another field holds that is safe to write as it stands: a name (a variable, a function, a
## loop's item) or a bare operator. Every other value is replaced by an untyped stand-in, so what is
## judged is the one field being typed.
static func is_structural(text: String) -> bool:
	var word: String = text.strip_edges()
	if word.is_empty():
		return false
	var all_symbols: bool = true
	for character: String in word:
		if not "=!<>+-*/%&|^~ ".contains(character):
			all_symbols = false
			break
	if all_symbols or word in ["and", "or", "in", "is", "not"]:
		return true
	for part: String in word.split("."):
		if not part.is_valid_identifier():
			return false
	return true


## The template with `value` in `param_id`'s slot, as {code, line, column}: the GDScript the verb writes,
## the zero-based line of it that holds the value, and the column the value starts at on that line. {}
## when the template has no such slot. `{target.}` is the optional "On node" prefix and reads the `target`
## field; every other slot takes its own word when that is a name or an operator, else a stand-in.
static func assemble(template: String, param_id: String, value: String, values: Dictionary) -> Dictionary:
	if template.is_empty() or not template.contains("{%s}" % param_id):
		return {}
	var code: String = ""
	var cursor: int = 0
	var value_at: int = -1
	for found: RegExMatch in RegEx.create_from_string("\\{(target\\.|\\w+)\\}").search_all(template):
		code += template.substr(cursor, found.get_start() - cursor)
		cursor = found.get_end()
		var token: String = found.get_string(1)
		if token == "target.":
			var target: String = str(values.get("target", "")).strip_edges()
			code += target + "." if not target.is_empty() else ""
		elif token == param_id:
			if value_at < 0:
				value_at = code.length()
			code += value.strip_edges()
		elif token == "uid":
			code += "0"
		else:
			var other: String = str(values.get(token, "")).strip_edges()
			# A blank argument list is an empty pair of brackets, not an argument: `queue_free({args})`
			# with nothing typed writes `queue_free()`.
			var empty_list: bool = other.is_empty() and found.get_start() > 0 and template[found.get_start() - 1] == "(" \
				and found.get_end() < template.length() and template[found.get_end()] == ")"
			# A value spliced into a member position (`{target}.{property}`) or a whole argument list cannot be
			# replaced by one stand-in variable without changing what the line says: it is written as it is.
			var member_position: bool = found.get_start() > 0 and template[found.get_start() - 1] == "."
			var argument_list: bool = found.get_start() > 0 and template[found.get_start() - 1] == "(" \
				and found.get_end() < template.length() and template[found.get_end()] == ")"
			var written: bool = is_structural(other) or empty_list or member_position or (argument_list and not other.is_empty())
			code += other if written else STAND_IN
	code += template.substr(cursor)
	var before: String = code.substr(0, value_at)
	var line: int = before.count("\n")
	# Whether the value sits inside a call's brackets, which is the only place a message about argument
	# counts or kinds can be about it.
	var in_call: bool = before.count("(") > before.count(")")
	return {"code": code, "line": line, "column": value_at - (before.rfind("\n") + 1), "in_call": in_call}


# ── $Node stand-ins ──────────────────────────────────────────────────────────────────────────


## The class a scene node is known by: its script's class_name when it has one, else its engine class.
static func node_class_of(node: Node) -> String:
	var script: Script = node.get_script() as Script
	if script != null:
		var global_name: String = script.get_global_name()
		if not global_name.is_empty():
			return global_name
	return node.get_class()


## `$Path` and `%Unique` references in `code` rewritten to typed stand-in variables when the open scene
## holds that node, with the declarations they need: {code, lines}. A reference the scene does not hold
## is left as written (untyped), because a node that only exists at runtime is not an error.
static func type_node_references(code: String, scene_root: Node, classes: Dictionary) -> Dictionary:
	var lines: PackedStringArray = PackedStringArray()
	if scene_root == null:
		return {"code": code, "lines": lines}
	var declared: Dictionary = {}
	var rewritten: String = code
	for found: RegExMatch in RegEx.create_from_string("([$%])([A-Za-z_][A-Za-z0-9_]*(?:/[A-Za-z_][A-Za-z0-9_]*)*)").search_all(code):
		var sigil: String = found.get_string(1)
		var path_text: String = found.get_string(2)
		var start: int = found.get_start()
		if sigil == "%" and start > 0:
			var previous: String = code.substr(0, start).strip_edges(false, true)
			if not previous.is_empty() and (previous[-1] == ")" or previous[-1] == "]" or previous[-1] == "_" \
					or previous.right(1).is_valid_identifier() or previous.right(1).is_valid_int()):
				continue  # `a %b` is a remainder, not a unique-name node
		var node: Node = scene_root.get_node_or_null(NodePath(("%" + path_text) if sigil == "%" else path_text))
		if node == null:
			continue
		var type_name: String = node_class_of(node)
		if not ClassDB.class_exists(type_name) and not classes.has(type_name):
			continue
		var stand_in: String = "__node_" + ("u_" if sigil == "%" else "") + path_text.replace("/", "_")
		if not declared.has(stand_in):
			declared[stand_in] = true
			lines.append("var %s: %s" % [stand_in, type_name])
		rewritten = rewritten.replace(found.get_string(), stand_in)
	return {"code": rewritten, "lines": lines}


# ── Running a check ──────────────────────────────────────────────────────────────────────────


## Compiles `body_lines` (statements of one function body) in the typed or untyped stand-in script.
## {ok, messages, first_line}: `first_line` is the probe line of the first body line, so a message's line
## maps back to the body.
static func _probe(body_lines: PackedStringArray, sheet: EventSheetResource, typed: bool, scene_root: Node) -> Dictionary:
	var extra: PackedStringArray = PackedStringArray()
	var code: String = "\n".join(body_lines)
	if typed:
		var rewritten: Dictionary = type_node_references(code, scene_root, EventSheetGDScriptLint._global_class_names())
		code = str(rewritten["code"])
		extra = rewritten["lines"]
	var source: String = EventSheetGDScriptLint.build_probe_source(code, true, sheet, typed, extra)
	var probe_lines: PackedStringArray = source.split("\n")
	var result: Dictionary = run_probe(source)
	result["first_line"] = probe_lines.find("func __eventsheet_lint() -> void:") + 2
	return result


## The finding for one field, or {} when there is nothing to say. `template` is the verb's template (empty
## for a field with none), `param_id` the field, `value` its text, `values` every field of the row, `scope`
## the locals the line can use. The finding:
##   level     "error" (Godot refuses the line) or "note" (the kind cannot be known until the game runs)
##   head/body the plain sentence
##   original  Godot's own message, or "" when it was not Godot who said it
##   span      Vector2i, the characters of `value` the message is about ((-1, -1) when none)
##   reason    the short line that sits beside OK
##   messages  everything the analyzer said
static func check_field(template: String, param_id: String, value: String, values: Dictionary,
		sheet: EventSheetResource, scope: PackedStringArray = PackedStringArray(),
		scene_root: Node = null) -> Dictionary:
	var text: String = value.strip_edges()
	if text.is_empty():
		return {}
	var member_finding: Dictionary = scene_member_finding(text, scene_root)
	var assembled: Dictionary = assemble(template, param_id, text, values)
	var forms: Array[PackedStringArray] = []
	var scope_lines: PackedStringArray = PackedStringArray([("var %s = null" % STAND_IN)])
	for scope_name: String in scope:
		if scope_name.is_valid_identifier() and scope_name != STAND_IN:
			scope_lines.append("var %s = null" % scope_name)
	var value_line: int = 0
	var column: int = 0
	if assembled.is_empty():
		forms.append(scope_lines + PackedStringArray(["var __expression_check__ = (%s)" % text]))
		column = scope_lines.size()
		value_line = scope_lines.size()
	else:
		var code_lines: PackedStringArray = str(assembled["code"]).split("\n")
		value_line = scope_lines.size() + int(assembled["line"])
		column = int(assembled["column"])
		forms.append(scope_lines + code_lines)
		if code_lines.size() == 1:
			forms.append(scope_lines + PackedStringArray(["var __slot_value__ = %s" % code_lines[0]]))
	var finding: Dictionary = {}
	for body: PackedStringArray in forms:
		var typed_run: Dictionary = _probe(body, sheet, true, scene_root)
		if bool(typed_run["ok"]):
			finding = _variant_note(text, scope_lines, sheet, scene_root)
			break
		finding = _finding_from(typed_run, body, value_line, text, column, sheet, bool(assembled.get("in_call", true)))
		if not finding.is_empty():
			break
	if finding.is_empty() or (str(finding.get("level", "")) == LEVEL_PAUSED and not member_finding.is_empty()):
		finding = member_finding
	if not finding.is_empty():
		# The spans are measured in the trimmed text; this is how far the typed text starts past that.
		finding["offset"] = value.length() - value.lstrip(" \t\n").length()
	return finding


## Whether a message is this value's to report. A word the analyzer says about a stand-in is not, and a
## message about the count or kinds of a call's arguments is only when the value IS those arguments (it
## sits inside the call's brackets) or holds the call itself - not when it is the node the call is made on.
static func _is_about_the_value(message: String, value: String, in_call: bool) -> bool:
	if message.contains(STAND_IN):
		return false
	var recognised: Dictionary = EventSheetTypeWords.recognise(message)
	match str(recognised.get("id", "")):
		"many", "few", "argument":
			return in_call or value.contains(str((recognised["fields"] as Dictionary).get("fn", "")) + "(")
		"pass":
			return in_call or value.contains("(")
	return true


## The finding for a typed failure: the messages on the line that holds the field's value, in words.
## {} when the failure is not the value's kind - a line the value is not on, or a message with no plain form
## that the untyped stand-in raises too (that is the plain compile check's to report).
static func _finding_from(run: Dictionary, body: PackedStringArray, value_line: int, value: String, column: int,
		sheet: EventSheetResource, in_call: bool) -> Dictionary:
	var first_line: int = int(run["first_line"])
	var heard: Array = []
	for message: Dictionary in run["messages"]:
		# An error above the body is the stand-in's own (a declaration it could not write), not the value's.
		if int(message["line"]) < first_line:
			return {"level": LEVEL_PAUSED, "reason": str(message["text"]), "messages": [str(message["text"])]}
		# A message about a line that does not hold this field's value is about the template or another
		# field, and is not this field's to report.
		if (int(message["line"]) - first_line == value_line or body.size() == 1) \
				and _is_about_the_value(str(message["text"]), value, in_call):
			heard.append(str(message["text"]))
	if heard.is_empty():
		return {}
	var all_plain: bool = true
	for heard_text: Variant in heard:
		if EventSheetTypeWords.recognise(str(heard_text)).is_empty():
			all_plain = false
	if not all_plain and not bool(_probe(body, sheet, false, null)["ok"]):
		return {}
	var lead: String = EventSheetTypeWords.lead_message(heard)
	var code_line: String = body[value_line] if value_line < body.size() else ""
	var words: Dictionary = EventSheetTypeWords.sentence(lead, {
		"value": value, "code": code_line, "sheet": sheet, "target": _assigned_name(code_line),
	})
	var head: String = str(words.get("head", ""))
	var note: String = str(words.get("body", ""))
	if head.is_empty():
		head = EventSheetL10n.translate("Godot would refuse this.")
		note = EventSheetL10n.translate("It does not fit where it is written. Godot says:") + " " + lead
	var span: Vector2i = span_of(lead, value)
	return {
		"level": LEVEL_ERROR,
		"head": head,
		"body": note,
		"original": str(heard[0]),
		"span": span,
		"reason": _reason_from(head, note),
		"messages": heard,
		"column": column,
		"fixes": rewrites_for(lead, value, span),
	}


## The one-click rewrites for a wrong kind of value, as fixes the dialog offers (never applied by themselves):
## quotes taken off a number written as text, a number made a Vector2, a value wrapped in str(), a quoted
## name made a node reference. Each replaces only the characters the message is about.
static func rewrites_for(message: String, value: String, span: Vector2i) -> Array:
	var recognised: Dictionary = EventSheetTypeWords.recognise(message)
	if recognised.is_empty():
		return []
	var fields: Dictionary = recognised["fields"]
	var wanted: String = str(fields.get("to", fields.get("want", "")))
	var got: String = str(fields.get("from", fields.get("got", "")))
	var piece: String = value.substr(span.x, span.y - span.x).strip_edges()
	var replacement: String = ""
	if wanted in ["int", "float"] and got == "String" and piece.length() >= 2 and piece.begins_with("\"") \
			and piece.ends_with("\"") and piece.substr(1, piece.length() - 2).is_valid_float():
		replacement = piece.substr(1, piece.length() - 2)
	elif wanted == "Vector2" and got in ["int", "float"] and piece.is_valid_float():
		replacement = "Vector2(%s, 0)" % piece
	elif wanted == "String" and got in ["int", "float", "bool"]:
		replacement = "str(%s)" % piece
	elif ClassDB.class_exists(wanted) and ClassDB.is_parent_class(wanted, "Node") and got == "String" \
			and piece.length() >= 3 and piece.begins_with("\"") and piece.ends_with("\"") \
			and piece.substr(1, piece.length() - 2).is_valid_identifier():
		replacement = "$" + piece.substr(1, piece.length() - 2)
	if replacement.is_empty():
		return []
	return [{"kind": "use", "name": value.substr(0, span.x) + replacement + value.substr(span.y)}]


## The name an assignment line writes to: `score` in `score = "ten"`, "" for anything else.
static func _assigned_name(code_line: String) -> String:
	var found: RegExMatch = RegEx.create_from_string("^\\s*([A-Za-z_][A-Za-z0-9_.]*)\\s*(?:[-+*/%]?=)(?!=)").search(code_line)
	return found.get_string(1) if found != null else ""


## The short reason that sits beside OK: the sentence's head and the first sentence of its body, on one line.
static func _reason_from(head: String, note: String) -> String:
	var second: String = note.get_slice(". ", 0).trim_suffix(".")
	if second.length() > 1 and second[0] == second[0].to_upper() and second[0] != second[0].to_lower() \
			and second[1] == second[1].to_lower():
		second = second[0].to_lower() + second.substr(1)
	return head.trim_suffix(".") + "; " + second


## The characters of `value` a message is about, as [start, end): a name the message quotes, the
## arguments past the count a call takes, the one argument that is the wrong kind - else the whole value.
static func span_of(message: String, value: String) -> Vector2i:
	var recognised: Dictionary = EventSheetTypeWords.recognise(message)
	var fields: Dictionary = recognised.get("fields", {})
	var kind: String = str(recognised.get("id", ""))
	if kind == "member":
		var member: String = str(fields.get("member", ""))
		var member_at: int = value.find(member)
		if member_at >= 0:
			return Vector2i(member_at, member_at + member.length())
	elif kind == "many" or kind == "argument":
		var parts: PackedStringArray = _arguments_of(value, str(fields.get("fn", "")))
		var offset: int = int(parts[0])
		var pieces: PackedStringArray = parts.slice(1)
		var index: int = int(fields.get("n", "0")) - 1 if kind == "argument" else int(fields.get("want", "0"))
		if index >= 0 and index < pieces.size():
			var start: int = offset
			for before: int in range(index):
				start += pieces[before].length() + 1
			var end: int = start + pieces[index].length()
			if kind == "many":
				end = offset - 1
				for piece: String in pieces:
					end += piece.length() + 1
			start += pieces[index].length() - pieces[index].lstrip(" \t").length()
			while end > start and value[end - 1] in " \t":
				end -= 1
			return Vector2i(start, end)
	return Vector2i(0, value.length())


## [offset of the argument list inside `value`, then each argument as written] for the call `function_name(`
## inside `value`, or for `value` itself when it holds no such call (the field IS the argument list).
static func _arguments_of(value: String, function_name: String) -> PackedStringArray:
	var offset: int = 0
	var inside: String = value
	var call_at: int = value.find(function_name + "(") if not function_name.is_empty() else -1
	if call_at >= 0:
		offset = call_at + function_name.length() + 1
		var depth: int = 1
		var end: int = offset
		while end < value.length() and depth > 0:
			if value[end] == "(":
				depth += 1
			elif value[end] == ")":
				depth -= 1
			end += 1
		inside = value.substr(offset, end - offset - 1) if depth == 0 else value.substr(offset)
	var out: PackedStringArray = PackedStringArray([str(offset)])
	out.append_array(EventSheetTypeWords.split_top_level(inside))
	return out


## The note a value that types fine but is not known to be any kind earns: asking Godot to infer its type
## (`var x := (...)`) fails when the value is a Variant, and the sentence says nothing is wrong yet. Only
## asked of a value that reaches into something by name (`other.points`), where a person would wonder.
static func _variant_note(value: String, scope_lines: PackedStringArray, sheet: EventSheetResource,
		scene_root: Node) -> Dictionary:
	var reach: RegExMatch = RegEx.create_from_string("(?<![A-Za-z0-9_.\"'$%])([A-Za-z_][A-Za-z0-9_]*)\\.[A-Za-z_]").search(value)
	if reach == null:
		return {}
	var subject: String = reach.get_string(1)
	if ClassDB.class_exists(subject) or Engine.has_singleton(subject) or EventSheetGDScriptLint._global_class_names().has(subject):
		return {}
	var inferred: Dictionary = _probe(scope_lines + PackedStringArray(["var __inferred__ := (%s)" % value]), sheet, true, scene_root)
	if bool(inferred["ok"]):
		return {}
	for message: Dictionary in inferred["messages"]:
		if str(message["text"]).begins_with("Cannot infer the type of"):
			return {
				"level": LEVEL_NOTE,
				"head": EventSheetL10n.translate("Worked out while the game runs."),
				"body": EventSheetL10n.translate("%s has no type here, so what it holds cannot be checked now. Nothing is wrong yet.") % subject,
				"original": "",
				"span": Vector2i(-1, -1),
				"reason": "",
				"messages": [],
			}
	return {}


# ── $Node.member ─────────────────────────────────────────────────────────────────────────────


## `$Player.jump_hieght`: the member a scene node does not have. Godot's analyzer types a node reference
## as the node's class but treats a property lookup on an object as dynamic, so it never says this one;
## the answer here comes from the node's own script and class instead, and only when both can be read in
## full (a script that will not load says nothing). {} when the member exists, the node is not in the open
## scene, or nothing can be told.
static func scene_member_finding(value: String, scene_root: Node) -> Dictionary:
	if scene_root == null:
		return {}
	for found: RegExMatch in RegEx.create_from_string("[$%](?:\"([^\"]+)\"|([A-Za-z_][A-Za-z0-9_]*(?:/[A-Za-z_][A-Za-z0-9_]*)*))\\.([A-Za-z_][A-Za-z0-9_]*)").search_all(value):
		var is_unique: bool = value[found.get_start()] == "%"
		var path_text: String = found.get_string(1) if not found.get_string(1).is_empty() else found.get_string(2)
		var member: String = found.get_string(3)
		var node: Node = scene_root.get_node_or_null(NodePath(("%" + path_text) if is_unique else path_text))
		if node == null:
			continue
		var members: Dictionary = node_members(node)
		if members.is_empty() or members.has(member):
			continue
		var node_label: String = path_text.get_slice("/", path_text.get_slice_count("/") - 1)
		var closest: String = ""
		var best: int = 3
		for candidate: Variant in members.keys():
			var distance: int = EventSheetNameRescue.edit_distance(member.to_lower(), str(candidate).to_lower())
			if distance < best:
				best = distance
				closest = str(candidate)
		var body: String = EventSheetL10n.translate("Check the spelling of %s.") % member
		if not closest.is_empty():
			body = EventSheetL10n.translate("Did you mean %s?") % closest
		var start: int = found.get_start(3)
		return {
			"level": LEVEL_ERROR,
			"head": EventSheetL10n.translate("%s has no %s.") % [node_label, member],
			"body": body + " " + EventSheetL10n.translate("(%s is a %s, read from the scene.)") % [node_label, node_class_of(node)],
			"original": "",
			"span": Vector2i(start, start + member.length()),
			"reason": EventSheetL10n.translate("%s has no %s") % [node_label, member],
			"messages": [],
			"fixes": ([{"kind": "use", "name": value.substr(0, start) + closest + value.substr(start + member.length())}]
				if not closest.is_empty() else []),
		}
	return {}


## Every name one may follow a dot after on `node`: its engine class's properties, methods, signals and
## constants, and those its script and the scripts it extends declare. {} when any script on the chain
## cannot be read in full - a finding is only made from a complete list.
static func node_members(node: Node) -> Dictionary:
	var members: Dictionary = {}
	var native: String = node.get_class()
	for property: Dictionary in ClassDB.class_get_property_list(native):
		members[str(property.get("name", ""))] = true
	for method: Dictionary in ClassDB.class_get_method_list(native):
		members[str(method.get("name", ""))] = true
	for signal_info: Dictionary in ClassDB.class_get_signal_list(native):
		members[str(signal_info.get("name", ""))] = true
	for constant_name: String in ClassDB.class_get_integer_constant_list(native):
		members[constant_name] = true
	for enum_name: String in ClassDB.class_get_enum_list(native):
		members[enum_name] = true
	var script: Script = node.get_script() as Script
	while script != null:
		if not (script is GDScript) or not script.can_instantiate():
			return {}
		for property: Dictionary in script.get_script_property_list():
			members[str(property.get("name", ""))] = true
		for method: Dictionary in script.get_script_method_list():
			members[str(method.get("name", ""))] = true
		for signal_info: Dictionary in script.get_script_signal_list():
			members[str(signal_info.get("name", ""))] = true
		for constant_name: Variant in script.get_script_constant_map().keys():
			members[str(constant_name)] = true
		script = script.get_base_script()
	return members
