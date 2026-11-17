# Godot EventSheets - a denial the short way: `if not x:` for a row placed now.
#
# `not (x)` and `not x` are the same question. A condition row placed now writes the second when the text it
# denies is one plain operand; every row and file written before keeps the first, byte for byte; and both
# spellings open as the same row (the row remembers which one its file used).
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const PlainNegation := preload("res://addons/eventforge/compiler/plain_negation.gd")
const P := "plain_negation_test"


static func run() -> bool:
	var ok: bool = true
	ok = _grammar() and ok
	ok = _emission() and ok
	ok = _reading() and ok
	ok = _tidy() and ok
	return ok


static func _grammar() -> bool:
	var rows: Array = []
	var plain: PackedStringArray = ["level_over", "self", "a.b", "a.b()", "a[b]", "a.b(c, d).e", "Input.is_action_pressed(\"jump\")",
		"a.b(\"x)\")", "a.b(c if d else e)", "a.b[0].c", "a.b(func(): return 1)", "x1", "_x"]
	var not_plain: PackedStringArray = ["", " a", "a ", "a == b", "a and b", "a or b", "a in b", "a is B", "a as B", "x if y else z",
		"func(): pass", "await a.b()", "-a", "not a", "a + b", "a.b() == c", "a.", ".a", "1", "1.5", "a(", "a)(", "a[b", "$Node", "\"text\"", "a b", "a.b() and c()"]
	for text: String in plain:
		rows.append(["`%s` is one plain operand" % text, PlainNegation.is_plain(text), true])
	for text: String in not_plain:
		rows.append(["`%s` is not" % text, PlainNegation.is_plain(text), false])
	return SUPPORT.pins(P, rows)


static func _row(template: String, negated: bool, plain: bool) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "ExpressionIsTrue"
	condition.params = {"expr": template}
	condition.negated = negated
	condition.plain_negation = plain
	return condition


static func _sheet_around(conditions: Array, or_mode: bool = false) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	for condition: Variant in conditions:
		event.conditions.append(condition)
	if or_mode:
		event.condition_mode = EventRow.ConditionMode.OR
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Test"
	action.ace_id = "noop"
	action.codegen_template = "pass"
	event.actions.append(action)
	sheet.events.append(event)
	return sheet


static func _emission() -> bool:
	var table: Array = []
	for pair: Array in [
		["level_over", "not level_over"], ["a.b", "not a.b"], ["a.b()", "not a.b()"], ["a[b]", "not a[b]"],
		["a == b", "not (a == b)"], ["a is B", "not (a is B)"], ["a and b", "not (a and b)"], ["x if y else z", "not (x if y else z)"],
		["await a.b()", "not (await a.b())"], ["-a", "not (-a)"],
	]:
		table.append(["a row placed now denying `%s` writes `%s`" % [pair[0], pair[1]],
			EventSheetConditionCodegen.generate_condition(_row(pair[0], true, true)), pair[1]])
		table.append(["an older row denying `%s` keeps the brackets" % pair[0],
			EventSheetConditionCodegen.generate_condition(_row(pair[0], true, false)), "not (%s)" % pair[0]])
	table.append(["an affirmed row is untouched by the flag", EventSheetConditionCodegen.generate_condition(_row("a.b()", false, true)), "a.b()"])
	var text: String = SUPPORT.compile_output(_sheet_around([_row("level_over", true, true), _row("ready_now()", false, true)]), SUPPORT.own_path("plain_negation.gd"))
	table.append(["the header joins the short denial with the next term", text.contains("if not level_over and ready_now():"), true])
	var either: String = SUPPORT.compile_output(_sheet_around([_row("a", true, true), _row("b.c", true, true)], true), SUPPORT.own_path("plain_negation.gd"))
	table.append(["an Or block joins two short denials", either.contains("if not a or not b.c:"), true])
	return SUPPORT.pins(P, table)


static func _lifted_first(source: String) -> ACECondition:
	var imported: EventSheetResource = SUPPORT.reopen(source)
	for entry: Variant in imported.events:
		if entry is EventRow and not (entry as EventRow).conditions.is_empty():
			return (entry as EventRow).conditions[0] as ACECondition
	return null


static func _file(header: String) -> String:
	return "extends Node2D\n\nvar level_over: bool = false\nvar a: Variant = null\nvar b: Variant = null\n\n\nfunc _process(_delta: float) -> void:\n\tif %s:\n\t\tpass\n" % header


static func _reading() -> bool:
	var table: Array = []
	for header: String in ["not level_over", "not (level_over)", "not a.b()", "not (a.b())", "not Input.is_action_pressed(\"jump\")",
		"not a.b() and c", "not (a == b)", "not (a is B)", "not a == b", "x or not y.z", "not a.b.is_empty()"]:
		var source: String = _file(header)
		var back: String = SUPPORT.reemit(source, SUPPORT.own_path("plain_negation_rt.gd"))
		table.append(["`if %s:` opens and saves back byte for byte" % header, back, source])
	var long_row: ACECondition = _lifted_first(_file("not (level_over)"))
	var long_shape: Array = [long_row != null and long_row.negated, long_row != null and long_row.plain_negation]
	table.append(["the bracketed denial opens as a denied condition that keeps its brackets", long_shape, [true, false]])
	var short_row: ACECondition = _lifted_first(_file("not level_over"))
	table.append(["a hand-written short denial keeps the reading it has always had", [short_row != null and short_row.negated, short_row != null and short_row.plain_negation], [false, false]])
	return SUPPORT.pins(P, table)


static func _reopened(header: String) -> EventSheetResource:
	var sheet: EventSheetResource = SUPPORT.reopen(_file(header))
	sheet.external_source_path = SUPPORT.own_path("plain_negation_tidy.gd")
	return sheet


static func _tidy() -> bool:
	var tidy: GDScript = load("res://addons/eventsheet/editor/dock/tidy_script.gd")
	var plan: Dictionary = tidy.plan(_reopened("not (level_over)"))
	var changes: Array = plan.get("changes", [])
	var first: Dictionary = changes[0] if not changes.is_empty() else {}
	var table: Array = [
		["Tidy offers the short form for the old row", str(first.get("after", "")).strip_edges(), "if not level_over:"],
		["and lists exactly one changed line", changes.size(), 1],
		["a row that denies a comparison is left alone", (tidy.plan(_reopened("not (a == b)")).get("changes", []) as Array).size(), 0],
		["a row already short has nothing to tidy", (tidy.plan(_reopened("not level_over")).get("changes", []) as Array).size(), 0],
	]
	return SUPPORT.pins(P, table)
