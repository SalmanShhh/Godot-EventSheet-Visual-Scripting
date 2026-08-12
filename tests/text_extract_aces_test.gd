# Godot EventSheets - the text-extraction + failure-report vocabulary (text_extract_aces.gd).
#
# Eight pure expressions that have to be right in three separate ways, so each is checked three ways:
#   1. SHAPE - registered exactly once (an ace_id or a display name that collides with a shipped verb
#      would silently shadow it), in the category the picker puts it in, as an EXPRESSION, described.
#   2. EMISSION - a real sheet compiled through SheetCompiler puts the SHIPPED template in the file
#      verbatim, and the compiled file parses, instantiates and runs, filling typed sheet variables.
#   3. BEHAVIOUR - each template is substituted through the real ActionCodegen into a function of its
#      own and driven with real inputs, INCLUDING every edge the descriptions promise: a marker that
#      is not there, an empty line, a quoted phrase, an unterminated quote, JSON that parses, JSON
#      that does not, a table with nothing wrong, a missing column, a null record, and a 0 that must
#      never be mistaken for a blank.
#
# The failure paths are the point of the three report verbs, so they are asserted explicitly in both
# directions: empty result when there is nothing wrong, and the exact sentence when there is.
@tool
class_name TextExtractACEsTest
extends RefCounted

## Every ace_id this module ships, in picker order.
const IDS: Array[String] = [
	"TextBefore", "TextAfter", "TextBetween", "NumberInText", "SplitKeepingQuotes",
	"ExplainJsonProblem", "ExplainTableProblem", "MissingFields",
]

## ace_id -> the display name and category it must keep (both are API once shipped).
const SHIPPED: Dictionary = {
	"TextBefore": ["Text Before", "Text"],
	"TextAfter": ["Text After", "Text"],
	"TextBetween": ["Text Between", "Text"],
	"NumberInText": ["Number In Text", "Text"],
	"SplitKeepingQuotes": ["Split Keeping Quotes", "Text"],
	"ExplainJsonProblem": ["Explain JSON Problem", "JSON"],
	# The table report files with Table From File, the verb that PRODUCES the rows it reads - an
	# author who just built a table and wants "why is my spreadsheet wrong" opens one picker section.
	"ExplainTableProblem": ["Explain Table Problem", "Files: Tables"],
	"MissingFields": ["Missing Fields", "Variables: Dictionary"],
}

## The dialogue line the extraction verbs are taught with, as a GDScript literal.
const SAMPLE_LINE: String = "\"Ada [angry]: hi\""


static func run() -> bool:
	var ok: bool = true
	ok = _test_registry_shape() and ok
	ok = _test_emitted_lines() and ok
	ok = _test_compiled_sheet_runs() and ok
	ok = _test_extraction_edges() and ok
	ok = _test_split_keeping_quotes() and ok
	ok = _test_reports_say_what_broke() and ok
	return ok


## Registered exactly once each (the shadowing guard), in the shipped category, as a described
## expression that declares no state - these are the parts that become API the moment they ship.
static func _test_registry_shape() -> bool:
	var ok: bool = true
	var id_counts: Dictionary = {}
	var name_counts: Dictionary = {}
	var by_id: Dictionary = {}
	for descriptor: ACEDescriptor in EventForgeBuiltinACEs.get_descriptors():
		id_counts[descriptor.ace_id] = int(id_counts.get(descriptor.ace_id, 0)) + 1
		name_counts[descriptor.display_name] = int(name_counts.get(descriptor.display_name, 0)) + 1
		by_id[descriptor.ace_id] = descriptor
	for ace_id: String in IDS:
		var expected: Array = SHIPPED[ace_id]
		ok = _check("%s is registered exactly once" % ace_id, int(id_counts.get(ace_id, 0)), 1) and ok
		ok = _check("\"%s\" is the only verb with that name" % str(expected[0]), int(name_counts.get(str(expected[0]), 0)), 1) and ok
		if not by_id.has(ace_id):
			ok = false
			continue
		var descriptor: ACEDescriptor = by_id[ace_id]
		ok = _check("%s displays as \"%s\"" % [ace_id, str(expected[0])], str(descriptor.display_name), str(expected[0])) and ok
		ok = _check("%s sits in %s" % [ace_id, str(expected[1])], str(descriptor.category), str(expected[1])) and ok
		ok = _check("%s is an expression" % ace_id, descriptor.ace_type, ACEDescriptor.ACEType.EXPRESSION) and ok
		ok = _check("%s carries hover help" % ace_id, str(descriptor.description).strip_edges().is_empty(), false) and ok
		ok = _check("%s declares no member state" % ace_id, str(descriptor.member_template).strip_edges(), "") and ok
	return ok


## The SHIPPED templates, filled the way the dock fills them, land in the compiled file verbatim.
static func _test_emitted_lines() -> bool:
	var output: String = _compile(_build_sheet(), "user://text_extract_emit.gd")
	var ok: bool = _check("Text Before emits the plain get_slice form",
		output.contains("\tspeaker = \"Ada [angry]: hi\".get_slice(\" [\", 0)"), true)
	ok = _check("Text Between emits the split-then-slice form",
		output.contains("\tmood = str((Array(\"Ada [angry]: hi\".split(\"[\", true, 1)) + [\"\"])[1]).get_slice(\"]\", 0)"), true) and ok
	ok = _check("Text After emits the rest-of-the-line form",
		output.contains("\tsays = str((Array(\"Ada [angry]: hi\".split(\"]: \", true, 1)) + [\"\"])[1])"), true) and ok
	ok = _check("Number In Text emits the pattern the author never sees",
		output.contains("\tchapter = (RegEx.create_from_string(\"-?[0-9]+(\\\\.[0-9]+)?\").search_all(\"Chapter 3 of 9\").map(func(__m): return __m.get_string()) + [\"0\"]).front().to_float()"), true) and ok
	ok = _check("Split Keeping Quotes emits the quote-toggling walk",
		output.contains("\twords = Array(\"give \\\"iron sword\\\" 2\".split(\"\\\"\")).reduce(func(__acc, __part): return [not __acc[0], __acc[1] + ([__part] if __acc[0] and not __part.is_empty() else Array(__part.split(\" \", false)))], [false, []])[1]"), true) and ok
	ok = _check("Explain JSON Problem emits the bound-instance form with a 1-based line",
		output.contains("\tjson_problem = (func(__json: JSON) -> String: return \"\" if __json.parse(\"{\\\"a\\\" 1}\") == OK else \"line %d: %s\" % [__json.get_error_line() + 1, __json.get_error_message()]).call(JSON.new())"), true) and ok
	ok = _check("Explain Table Problem emits the row/column sentence",
		output.contains("\"row %d, column \\\"%s\\\": \\\"%s\\\" is not a number\" % [__i + 1, __c, __rows[__i].get(__c, \"\")]"), true) and ok
	ok = _check("Explain Table Problem binds the rows once, at the call",
		output.contains(".call([{\"id\": \"a\", \"price\": \"5\"}, {\"id\": \"b\", \"price\": \"abc\"}], [\"price\"])"), true) and ok
	ok = _check("Missing Fields emits the blank test that spares a 0",
		output.contains("func(__p): return __p[1] == null or ((__p[1] is String or __p[1] is Array or __p[1] is Dictionary) and __p[1].is_empty())"), true) and ok
	ok = _check("Missing Fields splits the field list at the call",
		output.contains(".call({\"name\": \"Cave\", \"tiles\": []}, Array(\"name, tiles, spawn_point\".split(\",\")))"), true) and ok
	ok = _check("no emitted line reaches for the plugin at runtime (the parity covenant)",
		output.contains("EventSheets."), false) and ok
	return ok


## The compiled sheet is real GDScript: it instantiates, one _process tick runs all eight verbs, and
## every result lands in the typed sheet variable that declared it.
static func _test_compiled_sheet_runs() -> bool:
	var node: Node = _instantiate(_compile(_build_sheet(), "user://text_extract_run.gd"))
	if node == null:
		return _check("the compiled text-extract sheet instantiates", false, true)
	node.call("_process", 0.016)
	var ok: bool = _check("Text Before fills the speaker", str(node.get("speaker")), "Ada")
	ok = _check("Text Between fills the mood", str(node.get("mood")), "angry") and ok
	ok = _check("Text After fills what was said", str(node.get("says")), "hi") and ok
	ok = _check("Number In Text reads the chapter", float(node.get("chapter")), 3.0) and ok
	ok = _check("Split Keeping Quotes keeps the item name whole", node.get("words"), ["give", "iron sword", "2"]) and ok
	ok = _check("Explain JSON Problem names the line", str(node.get("json_problem")).begins_with("line 1: "), true) and ok
	ok = _check("Explain Table Problem names the row and column",
		str(node.get("table_problem")), "row 2, column \"price\": \"abc\" is not a number") and ok
	ok = _check("Missing Fields lists the blanks", str(node.get("gaps")), "tiles, spawn_point") and ok
	node.free()
	return ok


## Text Before / Text Between / Text After / Number In Text against the edges their help promises.
static func _test_extraction_edges() -> bool:
	var probe: RefCounted = _behaviour_probe()
	if probe == null:
		return _check("the extraction templates compile into functions", false, true)
	var ok: bool = _check("Text Before cuts at the first marker", str(probe.call("text_before", "Ada [angry]: hi", " [")), "Ada")
	ok = _check("Text Before hands back the whole line when the marker is missing",
		str(probe.call("text_before", "plain line", " [")), "plain line") and ok
	ok = _check("Text Before of an empty line is empty", str(probe.call("text_before", "", " [")), "") and ok
	ok = _check("Text After starts past the marker", str(probe.call("text_after", "Ada [angry]: hi", "]: ")), "hi") and ok
	ok = _check("Text After is empty when the marker is missing", str(probe.call("text_after", "plain", "]: ")), "") and ok
	ok = _check("Text After keeps everything, including later markers",
		str(probe.call("text_after", "a-b-c", "-")), "b-c") and ok
	ok = _check("Text Between reads the tag", str(probe.call("text_between", "Ada [angry]: hi", "[", "]")), "angry") and ok
	ok = _check("Text Between is empty when the opening marker is missing",
		str(probe.call("text_between", "Ada says hi", "[", "]")), "") and ok
	ok = _check("Text Between runs to the end when the closing marker is missing",
		str(probe.call("text_between", "Ada [angry: hi", "[", "]")), "angry: hi") and ok
	ok = _check("Text Between handles markers longer than one character",
		str(probe.call("text_between", "a<<b>>c", "<<", ">>")), "b") and ok
	ok = _check("Number In Text finds the first number", float(probe.call("number_in_text", "Chapter 3 of 9")), 3.0) and ok
	ok = _check("Number In Text is 0 when there is no number", float(probe.call("number_in_text", "no digits here")), 0.0) and ok
	ok = _check("Number In Text reads decimals", float(probe.call("number_in_text", "v1.25-beta")), 1.25) and ok
	ok = _check("Number In Text keeps a minus sign", float(probe.call("number_in_text", "temperature -5 degrees")), -5.0) and ok
	return ok


## The console/search-box splitter, including the cases the naive Split Text gets wrong.
static func _test_split_keeping_quotes() -> bool:
	var probe: RefCounted = _behaviour_probe()
	if probe == null:
		return _check("the split template compiles into a function", false, true)
	var ok: bool = _check("a quoted phrase stays one piece",
		probe.call("split_keeping_quotes", "give \"iron sword\" 2", " "), ["give", "iron sword", "2"])
	ok = _check("runs of separators never produce blanks",
		probe.call("split_keeping_quotes", "  spaced   out  ", " "), ["spaced", "out"]) and ok
	ok = _check("an empty line splits into nothing",
		probe.call("split_keeping_quotes", "", " "), []) and ok
	ok = _check("an unterminated quote runs to the end of the line",
		probe.call("split_keeping_quotes", "give \"iron sword", " "), ["give", "iron sword"]) and ok
	ok = _check("an empty quoted phrase adds no piece",
		probe.call("split_keeping_quotes", "say \"\" now", " "), ["say", "now"]) and ok
	ok = _check("a quoted separator survives (a pasted spreadsheet cell)",
		probe.call("split_keeping_quotes", "a,\"b,c\",d", ","), ["a", "b,c", "d"]) and ok
	ok = _check("the naive split it replaces would have made four pieces of that",
		"a,\"b,c\",d".split(",").size(), 4) and ok
	return ok


## The three report verbs, in both directions: empty when nothing is wrong, a sentence when it is.
static func _test_reports_say_what_broke() -> bool:
	var probe: RefCounted = _behaviour_probe()
	if probe == null:
		return _check("the report templates compile into functions", false, true)

	# ── Explain JSON Problem ──
	var ok: bool = _check("valid JSON explains nothing", str(probe.call("json_problem", "{\"a\": 1}")), "")
	ok = _check("a broken first line is reported as line 1",
		str(probe.call("json_problem", "{\"a\" 1}")).begins_with("line 1: "), true) and ok
	var deep: String = str(probe.call("json_problem", "{\n\t\"a\": 1,\n\t\"b\" 2\n}"))
	ok = _check("the line number counts the way an editor shows it", deep.begins_with("line 3: "), true) and ok
	ok = _check("the report carries the parser's own message after the line",
		deep.trim_prefix("line 3: ").is_empty(), false) and ok
	ok = _check("an empty file is reported, not waved through",
		str(probe.call("json_problem", "")).is_empty(), false) and ok
	ok = _check("the literal null is valid JSON and explains nothing",
		str(probe.call("json_problem", "null")), "") and ok

	# ── Explain Table Problem ──
	var priced: Array = [{"id": "a", "price": "5"}, {"id": "b", "price": "abc"}]
	ok = _check("the first bad cell is named with its row and column",
		str(probe.call("table_problem", priced, ["price"])), "row 2, column \"price\": \"abc\" is not a number") and ok
	ok = _check("a clean table explains nothing",
		str(probe.call("table_problem", [{"price": "5"}, {"price": 7.5}], ["price"])), "") and ok
	ok = _check("a column that is not there is reported, not skipped",
		str(probe.call("table_problem", [{"id": "a"}], ["price"])), "row 1, column \"price\": \"\" is not a number") and ok
	ok = _check("an empty table explains nothing", str(probe.call("table_problem", [], ["price"])), "") and ok
	ok = _check("only the listed columns are judged",
		str(probe.call("table_problem", [{"id": "a", "price": "5"}], ["price"])), "") and ok

	# THE failure mode a report verb must not have: this module makes an EMPTY result the all-clear,
	# so a shape it cannot read must not answer with one. Rows that are not records (a list of lists,
	# which is what a table read by some other route looks like) used to fault inside the lambda and
	# hand back "" - the malformed import then sailed through the branch meant to stop it.
	ok = _check("rows that are not records are reported, not waved through as all-clear",
		str(probe.call("table_problem", [["a", "b"]], ["price"])), "row 1 is not a record") and ok
	ok = _check("a bad row is found even when good ones come first",
		str(probe.call("table_problem", [{"price": "5"}, "not a row at all"], ["price"])), "row 2 is not a record") and ok
	ok = _check("a nothing where a row should be is reported too",
		str(probe.call("table_problem", [null], ["price"])), "row 1 is not a record") and ok
	# And the all-clear still means what it says for a table that really is fine.
	ok = _check("a good table is still silent after all that",
		str(probe.call("table_problem", [{"price": "1"}, {"price": "2"}], ["price"])), "") and ok

	# ── Missing Fields ──
	ok = _check("the blank fields are listed in order",
		str(probe.call("missing_fields", {"name": "Cave", "tiles": [], "extra": 0}, "name, tiles, spawn_point")),
		"tiles, spawn_point") and ok
	ok = _check("a complete record lists nothing",
		str(probe.call("missing_fields", {"name": "Cave", "tiles": [1], "spawn_point": Vector2.ZERO}, "name, tiles, spawn_point")), "") and ok
	ok = _check("a 0 is a real value, never a missing field",
		str(probe.call("missing_fields", {"score": 0}, "score")), "") and ok
	ok = _check("an empty record reports every field",
		str(probe.call("missing_fields", {}, "id, name")), "id, name") and ok
	ok = _check("a null record reports every field instead of crashing",
		str(probe.call("missing_fields", null, "id, name")), "id, name") and ok
	var resource: Resource = Resource.new()
	resource.resource_name = "hero"
	ok = _check("a resource is checked the same way a record is",
		str(probe.call("missing_fields", resource, "resource_name, resource_path")), "resource_path") and ok
	return ok


## `<Node> / eight typed variables / _process: eight Set Variable rows, one per verb`.
static func _build_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.events.append(_variable("speaker", "String", ""))
	sheet.events.append(_variable("mood", "String", ""))
	sheet.events.append(_variable("says", "String", ""))
	sheet.events.append(_variable("chapter", "float", 0.0))
	sheet.events.append(_variable("words", "Array", []))
	sheet.events.append(_variable("json_problem", "String", ""))
	sheet.events.append(_variable("table_problem", "String", ""))
	sheet.events.append(_variable("gaps", "String", ""))
	var row: EventRow = EventRow.new()
	row.trigger_provider_id = "Core"
	row.trigger_id = "OnProcess"
	row.actions.append(_set_var("speaker", _expr("TextBefore", {"text": SAMPLE_LINE, "marker": "\" [\""})))
	row.actions.append(_set_var("mood", _expr("TextBetween", {"text": SAMPLE_LINE, "open": "\"[\"", "close": "\"]\""})))
	row.actions.append(_set_var("says", _expr("TextAfter", {"text": SAMPLE_LINE, "marker": "\"]: \""})))
	row.actions.append(_set_var("chapter", _expr("NumberInText", {"text": "\"Chapter 3 of 9\""})))
	row.actions.append(_set_var("words", _expr("SplitKeepingQuotes", {"text": "\"give \\\"iron sword\\\" 2\"", "separator": "\" \""})))
	row.actions.append(_set_var("json_problem", _expr("ExplainJsonProblem", {"text": "\"{\\\"a\\\" 1}\""})))
	row.actions.append(_set_var("table_problem", _expr("ExplainTableProblem", {
		"records": "[{\"id\": \"a\", \"price\": \"5\"}, {\"id\": \"b\", \"price\": \"abc\"}]",
		"columns": "[\"price\"]"})))
	row.actions.append(_set_var("gaps", _expr("MissingFields", {
		"record": "{\"name\": \"Cave\", \"tiles\": []}",
		"fields": "\"name, tiles, spawn_point\""})))
	sheet.events.append(row)
	return sheet


## One function per verb, built from the SHIPPED template through the real codegen substitution, so
## the edge cases below drive exactly the code a sheet ships - not a re-typed copy of it.
static func _behaviour_probe() -> RefCounted:
	var lines: Array[String] = [
		"@tool",
		"extends RefCounted",
		"func text_before(text: String, marker: String) -> String:",
		"\treturn %s" % _expr("TextBefore", {"text": "text", "marker": "marker"}),
		"func text_after(text: String, marker: String) -> String:",
		"\treturn %s" % _expr("TextAfter", {"text": "text", "marker": "marker"}),
		"func text_between(text: String, open_marker: String, close_marker: String) -> String:",
		"\treturn %s" % _expr("TextBetween", {"text": "text", "open": "open_marker", "close": "close_marker"}),
		"func number_in_text(text: String) -> float:",
		"\treturn %s" % _expr("NumberInText", {"text": "text"}),
		"func split_keeping_quotes(text: String, separator: String) -> Array:",
		"\treturn %s" % _expr("SplitKeepingQuotes", {"text": "text", "separator": "separator"}),
		"func json_problem(text: String) -> String:",
		"\treturn %s" % _expr("ExplainJsonProblem", {"text": "text"}),
		"func table_problem(rows: Array, cols: Array) -> String:",
		"\treturn %s" % _expr("ExplainTableProblem", {"records": "rows", "columns": "cols"}),
		"func missing_fields(record: Variant, fields: String) -> String:",
		"\treturn %s" % _expr("MissingFields", {"record": "record", "fields": "fields"}),
		"",
	]
	# NOTE the trailing "": a single-line lambda's body runs to the end of its line, so a script whose
	# LAST line is one fails to parse without the terminating newline. Real compiler output has it.
	var script: GDScript = GDScript.new()
	script.source_code = "\n".join(lines)
	if script.reload() != OK:
		print("  behaviour probe failed to reload:\n%s" % script.source_code)
		return null
	return script.new()


## The registered descriptor's template with the given arguments substituted by the real codegen.
static func _expr(ace_id: String, args: Dictionary) -> String:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", ace_id)
	if descriptor == null:
		return "\"%s IS NOT REGISTERED\"" % ace_id
	return ActionCodegen._apply_template(str(descriptor.codegen_template), args)


## A Set Variable row carrying the REAL Set Variable template, baked exactly as the dock bakes it.
static func _set_var(variable_name: String, value_expression: String) -> ACEAction:
	var descriptor: ACEDescriptor = ACERegistry.find_descriptor("Core", "SetVar")
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Core"
	action.ace_id = "SetVar"
	action.codegen_template = ActionCodegen._apply_template(str(descriptor.codegen_template),
		{"var_name": variable_name, "value": value_expression})
	return action


static func _variable(variable_name: String, type_name: String, default_value: Variant) -> LocalVariable:
	var variable: LocalVariable = LocalVariable.new()
	variable.name = variable_name
	variable.type_name = type_name
	variable.default_value = default_value
	return variable


static func _compile(sheet: EventSheetResource, path: String) -> String:
	return str(SheetCompiler.compile(sheet, path).get("output", ""))


static func _instantiate(source: String) -> Node:
	var script: GDScript = GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		print("  compiled source failed to reload:\n%s" % source)
		return null
	var node: Node = Node.new()
	node.set_script(script)
	return node


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] text_extract_aces_test: %s" % label)
		return true
	print("[FAIL] text_extract_aces_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
