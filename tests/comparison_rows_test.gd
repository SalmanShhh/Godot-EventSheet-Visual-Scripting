# Godot EventSheets - how a sheet asks a question (slice K).
#
# What this pins, in the order a reader meets it:
#   1. THE SYMBOLS. An authored comparison row shows the glyph a reader means - ≤ ≥ ≠, and `=` for
#      equality - while the template and the emitted line keep the two-character GDScript spelling.
#   2. THE ONE COMPARE DIALOG. Three boxes in, one existing ACE out: the mapping table, the round
#      trip back into the boxes, and the two lines the help strip shows.
#   3. THE FLIP. An inverted comparison with a clean opposite renders AND emits the opposite, and
#      both spellings of it lift to the same row. Everything else still wears the denial mark.
#   4. THE "or" DIVIDER, and the Else row that says what it follows.
#   5. THE PICK. A filter that narrows a family reads as the pick it is, with the family in the
#      object column.
#   6. THE FILING. In the picker, the comparison family is one entry plus one sub-folder, not
#      twelve rows scattered across three categories - and every one of the twelve is still there.
@tool
class_name ComparisonRowsTest
extends RefCounted

## The dialog under test. A class_name is not a constant expression, so the alias that lets the
## mapping table below read as a table is the script itself.
const COMPARE := preload("res://addons/eventsheet/editor/dock/compare_condition_dialog.gd")


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_symbols() and all_passed
	all_passed = _test_dialog_mapping() and all_passed
	all_passed = _test_flip() and all_passed
	all_passed = _test_or_and_else() and all_passed
	all_passed = _test_pick_sentence() and all_passed
	all_passed = _test_picker_filing() and all_passed
	if all_passed:
		print("[PASS] comparison_rows: a comparison reads as the question it is.")
	return all_passed


# ── 1. The symbols ──


static func _test_symbols() -> bool:
	var passed: bool = true
	# The one table every reader of an operator resolves through.
	passed = _check("at most", EventForgeACEFactory.comparison_glyph("<="), "≤") and passed
	passed = _check("at least", EventForgeACEFactory.comparison_glyph(">="), "≥") and passed
	passed = _check("not equal", EventForgeACEFactory.comparison_glyph("!="), "≠") and passed
	passed = _check("equality reads as one =", EventForgeACEFactory.comparison_glyph("=="), "=") and passed
	passed = _check("anything else is left alone",
		EventForgeACEFactory.comparison_glyph("score + 1"), "score + 1") and passed

	var sheet: EventSheetResource = _sheet_with_comparison("<=", false)
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_sheet(sheet)
	passed = _check("the authored row shows the glyph",
		_condition_text(viewport, sheet), "hp ≤ 0") and passed
	viewport.free()

	var equal_sheet: EventSheetResource = _sheet_with_comparison("==", false)
	var equal_viewport: EventSheetViewport = EventSheetViewport.new()
	equal_viewport.set_sheet(equal_sheet)
	passed = _check("and one `=` where GDScript writes two",
		_condition_text(equal_viewport, equal_sheet), "hp = 0") and passed
	equal_viewport.free()

	# The row is what changed; the file is not.
	passed = _check("the emitted line keeps the GDScript spelling",
		_compiled(sheet).contains("if hp <= 0:"), true) and passed
	return passed


# ── 2. The one Compare dialog ──


static func _test_dialog_mapping() -> bool:
	var passed: bool = true
	# The table: what each of the three boxes writes. Values, never counts.
	var cases: Array = [
		# left kind, operator, on a variable, left, right, second, tolerance, ignore case
		#   -> expected ace id, expected params
		[COMPARE.KIND_NUMBER, "<=", true, "hp", "0", "", "", false,
			COMPARE.ACE_COMPARE_VAR, {"var_name": "hp", "op": "<=", "value": "0"}],
		[COMPARE.KIND_NUMBER, ">=", false, "score", "Game.HighScore", "", "", false,
			COMPARE.ACE_COMPARE_VALUES, {"a": "score", "op": ">=", "b": "Game.HighScore"}],
		[COMPARE.KIND_NUMBER, COMPARE.OPERATOR_BETWEEN, true, "hp", "1", "50", "", false,
			COMPARE.ACE_IS_BETWEEN, {"value": "hp", "min": "1", "max": "50"}],
		[COMPARE.KIND_NUMBER, COMPARE.OPERATOR_NOT_BETWEEN, true, "hp", "1", "50", "", false,
			COMPARE.ACE_IS_OUTSIDE_RANGE, {"value": "hp", "min": "1", "max": "50"}],
		[COMPARE.KIND_NUMBER, COMPARE.OPERATOR_WITHIN, true, "speed", "0", "", "0.5", false,
			COMPARE.ACE_VALUES_ARE_NEAR, {"a": "speed", "b": "0", "tolerance": "0.5"}],
		[COMPARE.KIND_TEXT, COMPARE.OPERATOR_IS, true, "name", "\"bob\"", "", "", false,
			COMPARE.ACE_COMPARE_VAR, {"var_name": "name", "op": "==", "value": "\"bob\""}],
		[COMPARE.KIND_TEXT, COMPARE.OPERATOR_IS, true, "name", "\"bob\"", "", "", true,
			COMPARE.ACE_TEXT_EQUALS_IGNORE_CASE, {"a": "name", "b": "\"bob\""}],
		[COMPARE.KIND_TEXT, COMPARE.OPERATOR_IS_NOT, false, "name", "\"bob\"", "", "", false,
			COMPARE.ACE_COMPARE_VALUES, {"a": "name", "op": "!=", "b": "\"bob\""}],
		[COMPARE.KIND_TEXT, COMPARE.OPERATOR_BEGINS_WITH, true, "name", "\"B\"", "", "", false,
			COMPARE.ACE_TEXT_BEGINS_WITH, {"text": "name", "prefix": "\"B\""}],
		[COMPARE.KIND_TEXT, COMPARE.OPERATOR_BEGINS_WITH, true, "name", "\"B\"", "", "", true,
			COMPARE.ACE_TEXT_BEGINS_WITH, {"text": "name.to_lower()", "prefix": "\"B\".to_lower()"}],
		[COMPARE.KIND_TEXT, COMPARE.OPERATOR_ENDS_WITH, true, "name", "\"y\"", "", "", false,
			COMPARE.ACE_TEXT_ENDS_WITH, {"text": "name", "suffix": "\"y\""}],
		[COMPARE.KIND_TEXT, COMPARE.OPERATOR_CONTAINS, true, "name", "\"o\"", "", "", false,
			COMPARE.ACE_TEXT_CONTAINS, {"text": "name", "needle": "\"o\""}],
		[COMPARE.KIND_TEXT, COMPARE.OPERATOR_IS_ONE_OF, true, "name", "[\"bob\", \"alice\"]", "", "", false,
			COMPARE.ACE_TEXT_IS_ONE_OF, {"text": "name", "options": "[\"bob\", \"alice\"]"}],
		[COMPARE.KIND_TEXT, COMPARE.OPERATOR_MATCHES, true, "name", "\"level_*\"", "", "", false,
			COMPARE.ACE_TEXT_MATCHES, {"text": "name", "pattern": "\"level_*\""}],
		[COMPARE.KIND_TEXT, COMPARE.OPERATOR_IS_EMPTY, true, "input_text", "", "", "", false,
			COMPARE.ACE_TEXT_IS_EMPTY, {"text": "input_text"}]
	]
	for entry: Variant in cases:
		var row: Array = entry
		var written: Dictionary = COMPARE.writes(str(row[0]), str(row[1]), bool(row[2]), str(row[3]),
			str(row[4]), str(row[5]), str(row[6]), bool(row[7]))
		passed = _check("%s writes %s" % [str(row[1]), str(row[8])], str(written["ace_id"]), str(row[8])) and passed
		passed = _check("%s params" % str(row[1]), written["params"], row[9]) and passed

	# "is not, ignoring case" has no condition of its own: it is the ignore-case equality inverted.
	var not_ignoring: Dictionary = COMPARE.writes(COMPARE.KIND_TEXT, COMPARE.OPERATOR_IS_NOT, true,
		"name", "\"bob\"", "", "", true)
	passed = _check("is-not-ignoring-case is the ignore-case equality",
		str(not_ignoring["ace_id"]), COMPARE.ACE_TEXT_EQUALS_IGNORE_CASE) and passed
	passed = _check("...inverted", bool(not_ignoring["negated"]), true) and passed

	# Which operator list a left side gets, and how many value fields each asks for.
	passed = _check("a text left side gets the text list",
		str((COMPARE.operators_for(COMPARE.KIND_TEXT)[0] as Dictionary)["key"]), COMPARE.OPERATOR_IS) and passed
	passed = _check("a number left side gets the comparison list",
		str((COMPARE.operators_for(COMPARE.KIND_NUMBER)[0] as Dictionary)["key"]), "==") and passed
	passed = _check("a range asks for two values",
		COMPARE.fields_for(COMPARE.KIND_NUMBER, COMPARE.OPERATOR_BETWEEN), COMPARE.FIELDS_TWO) and passed
	passed = _check("a tolerance asks for one and a give-or-take",
		COMPARE.fields_for(COMPARE.KIND_NUMBER, COMPARE.OPERATOR_WITHIN), COMPARE.FIELDS_TOLERANCE) and passed
	passed = _check("is empty asks for nothing",
		COMPARE.fields_for(COMPARE.KIND_TEXT, COMPARE.OPERATOR_IS_EMPTY), COMPARE.FIELDS_NONE) and passed
	passed = _check("a quoted literal is text",
		COMPARE.kind_of("", "\"bob\""), COMPARE.KIND_TEXT) and passed
	passed = _check("a declared String is text", COMPARE.kind_of("String", ""), COMPARE.KIND_TEXT) and passed
	passed = _check("a declared int is not", COMPARE.kind_of("int", ""), COMPARE.KIND_NUMBER) and passed

	# A row opens back into the boxes it was written from.
	var boxes: Dictionary = COMPARE.boxes_for(COMPARE.ACE_IS_BETWEEN, {"value": "hp", "min": "1", "max": "50"}, false)
	passed = _check("a range row opens on its range operator", str(boxes["operator"]), COMPARE.OPERATOR_BETWEEN) and passed
	passed = _check("with both ends filled in", [str(boxes["right"]), str(boxes["second"])], ["1", "50"]) and passed
	var cased: Dictionary = COMPARE.boxes_for(COMPARE.ACE_TEXT_BEGINS_WITH,
		{"text": "name.to_lower()", "prefix": "\"B\".to_lower()"}, false)
	passed = _check("an ignore-case row opens with the tick on", bool(cased["ignore_case"]), true) and passed
	passed = _check("and the sides read back plain", [str(cased["left"]), str(cased["right"])], ["name", "\"B\""]) and passed
	passed = _check("a row this dialog cannot write opens nowhere",
		COMPARE.boxes_for("IsOnFloor", {}, false), {}) and passed

	# The two lines the help strip shows, and where they come from.
	passed = _check("READS AS is the row, in glyphs",
		COMPARE.reads_as(COMPARE.ACE_COMPARE_VAR, {"var_name": "hp", "op": "<=", "value": "0"}, false),
		"hp ≤ 0") and passed
	passed = _check("IN CODE is the line the compiler writes",
		COMPARE.in_code(COMPARE.ACE_COMPARE_VAR, {"var_name": "hp", "op": "<=", "value": "0"}, false),
		"if hp <= 0:") and passed
	passed = _check("inverted, both lines flip rather than deny",
		[COMPARE.reads_as(COMPARE.ACE_COMPARE_VAR, {"var_name": "hp", "op": "<=", "value": "0"}, true),
			COMPARE.in_code(COMPARE.ACE_COMPARE_VAR, {"var_name": "hp", "op": "<=", "value": "0"}, true)],
		["hp > 0", "if hp > 0:"]) and passed
	passed = _check("with no opposite to show, it leads with the word",
		COMPARE.reads_as(COMPARE.ACE_TEXT_BEGINS_WITH, {"text": "name", "prefix": "\"B\""}, true),
		"not name begins with \"B\"") and passed
	return passed


# ── 3. The flip ──


static func _test_flip() -> bool:
	var passed: bool = true
	# Which templates flip, decided once for the compiler, the importer and the row alike.
	passed = _check("a plain binary comparison flips",
		EventForgeACEFactory.flipped_comparison_params("{a} {op} {b}", {"a": "x", "op": "<=", "b": "0"}),
		{"a": "x", "op": ">", "b": "0"}) and passed
	passed = _check("a comparison buried in an expression does not",
		EventForgeACEFactory.flipped_comparison_params("absf({a} - {b}) <= {t}", {"a": "x", "b": "0", "t": "1"}),
		{}) and passed
	passed = _check("nor does a template with a literal side",
		EventForgeACEFactory.flipped_comparison_params("health {op} {value}", {"op": "<", "value": "10"}),
		{}) and passed

	# Emission: the inverted row IS the opposite question.
	var sheet: EventSheetResource = _sheet_with_comparison("<=", true)
	var flipped_output: String = _compiled(sheet)
	passed = _check("an inverted comparison emits its opposite",
		flipped_output.contains("if hp > 0:"), true) and passed
	passed = _check("and wears no `not (` at all", flipped_output.contains("not ("), false) and passed

	# Everything else still wraps: a baked template is not a comparison this table can read.
	var baked: ACECondition = ACECondition.new()
	baked.provider_id = "Core"
	baked.ace_id = "CompareVar"
	baked.codegen_template = "is_hurt()"
	baked.negated = true
	passed = _check("a condition with no opposite still wraps",
		ConditionCodegen.generate_condition(baked), "not (is_hurt())") and passed

	# The row says the same thing the file does, and drops the denial mark with it.
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_sheet(sheet)
	passed = _check("the row shows the opposite too", _condition_text(viewport, sheet), "hp > 0") and passed
	passed = _check("and wears no denial mark", _has_negated_mark(viewport, sheet), false) and passed
	viewport.free()

	# Both spellings lift to the SAME ROW - the comparison, with the invert on for the long one - and
	# each re-emits ITSELF, because the row remembers which spelling its file used.
	var short_spelling: EventRow = _lifted_condition_row("if hp > 0:\n\tprint(\"alive\")")
	var long_spelling: EventRow = _lifted_condition_row("if not (hp <= 0):\n\tprint(\"alive\")")
	passed = _check("the short spelling lifts as the comparison it is",
		[_lifted_expression(short_spelling), _lifted_negated(short_spelling)], ["hp > 0", false]) and passed
	passed = _check("the long spelling lifts as the comparison with the invert on, not a raw expression",
		[_lifted_ace(long_spelling), _lifted_expression(long_spelling), _lifted_negated(long_spelling)],
		["Core/CompareVar", "hp <= 0", true]) and passed
	passed = _check("…so the row asks the question in the same words the short spelling does",
		_row_condition_text(long_spelling), "hp > 0") and passed
	passed = _check("and the row remembers which spelling its file used",
		[(short_spelling.conditions[0] as ACECondition).negation_wrapped,
			(long_spelling.conditions[0] as ACECondition).negation_wrapped], [false, true]) and passed

	# The covenant, both ways round: whatever each spelling lifted to re-emits that spelling exactly.
	for body: String in ["if hp > 0:\n\tprint(\"alive\")", "if not (hp <= 0):\n\tprint(\"alive\")"]:
		var source: String = _source_around(body)
		var imported: EventSheetResource = GDScriptImporter.new().import_external_source(source)
		imported.external_source_path = "user://__compare_rt.gd"
		passed = _check("`%s` round-trips byte-identically" % body.get_slice("\n", 0),
			str(SheetCompiler.compile(imported, "user://__compare_rt.gd").get("output", "")), source) and passed
	return passed


# ── 4. The "or" divider, and what an Else follows ──


static func _test_or_and_else() -> bool:
	var passed: bool = true
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	event.condition_mode = EventRow.ConditionMode.OR
	event.conditions.append(_comparison("hp", "<=", "0", false))
	event.conditions.append(_comparison("lives", "==", "0", false))
	sheet.events.append(event)
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_sheet(sheet)
	var row: EventRowData = _row_for(viewport, event)
	# Line 0 is the trigger's, so the two conditions are lines 1 and 2 - the divider goes above the
	# second condition, wherever its line happens to fall.
	passed = _check("an OR event rules a divider above its second condition",
		Array(row.or_condition_lines) if row != null else [], [2]) and passed
	passed = _check("and badges nothing", _all_span_text(row).contains("OR"), false) and passed
	event.condition_mode = EventRow.ConditionMode.AND
	viewport.set_sheet(sheet)
	passed = _check("an AND event rules nothing",
		Array(_row_for(viewport, event).or_condition_lines), []) and passed
	viewport.free()

	# The geometry: half a line-gap above the first span of the line being divided, across the lane.
	var laid_out: EventRowData = EventRowData.new()
	laid_out.spans = [_placed_span(0, Rect2(40.0, 100.0, 120.0, 18.0)),
		_placed_span(1, Rect2(40.0, 122.0, 120.0, 18.0))]
	var geometry: Dictionary = EventRowRenderer.or_divider_geometry(laid_out, 1, Rect2(30.0, 96.0, 300.0, 44.0))
	passed = _check("the rule sits in the gap above the line",
		float(geometry.get("y", 0.0)), 122.0 - EventRowRenderer.OR_DIVIDER_GAP) and passed
	passed = _check("and spans the lane, inset at both ends",
		[float(geometry.get("from_x", 0.0)), float(geometry.get("to_x", 0.0))],
		[30.0 + EventRowRenderer.OR_DIVIDER_INSET, 330.0 - EventRowRenderer.OR_DIVIDER_INSET]) and passed
	passed = _check("a line with nothing on it is never ruled",
		EventRowRenderer.or_divider_geometry(laid_out, 4, Rect2(30.0, 96.0, 300.0, 44.0)), {}) and passed

	# The Else row names the event its chain starts at.
	passed = _check("an Else says what it follows",
		ViewportRowBuilder.else_follows_text(_numbered_else_rows(9), 1, 0), "neither of 9") and passed
	passed = _check("an Else whose head is off the canvas says nothing",
		ViewportRowBuilder.else_follows_text(_numbered_else_rows(0), 1, 0), "") and passed
	return passed


# ── 5. The pick ──


static func _test_pick_sentence() -> bool:
	var passed: bool = true
	var narrowed: Dictionary = EventSheetViewportReadingRows.pick_words("enemy", "hp < 10",
		"global_position.distance_to(Player.global_position)", false, 3)
	passed = _check("a filtered pick reads as the pick it is",
		str(narrowed.get("text", "")), "Pick where hp < 10 · nearest to Player first · top 3") and passed
	passed = _check("and the family owns it", str(narrowed.get("object", "")), "Enemy") and passed
	passed = _check("an order with no test still reads",
		str(EventSheetViewportReadingRows.pick_words("enemy", "", "hp", true, 0).get("text", "")),
		"Pick highest hp first") and passed
	passed = _check("a plain walk over everything is not a pick",
		EventSheetViewportReadingRows.pick_words("enemy", "", "", false, 0), {}) and passed
	passed = _check("a distance names what it measures to",
		EventSheetViewportReadingRows.distance_target("global_position.distance_to($Enemies/Player.global_position)"),
		"Player") and passed
	passed = _check("and anything else is not a distance",
		EventSheetViewportReadingRows.distance_target("hp * 2"), "") and passed

	# The row itself: the sentence in the cell, the family in the object column.
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var pick: PickFilter = PickFilter.new()
	pick.iterator_name = "enemy"
	pick.collection_kind = PickFilter.CollectionKind.GROUP
	pick.collection_value = "enemy"
	pick.predicate_expression = "hp < 10"
	pick.pick_first_n = 3
	event.pick_filters.append(pick)
	sheet.events.append(event)
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_sheet(sheet)
	var row: EventRowData = _row_for(viewport, event)
	var span: SemanticSpan = _span_with(row, "kind", "pick_filter")
	passed = _check("the authored pick row reads as a pick",
		span.text if span != null else "<no pick span>", "Pick where hp < 10 · top 3") and passed
	passed = _check("with the family in the object column",
		str((span.metadata as Dictionary).get("object_label", "")) if span != null else "", "Enemy") and passed
	viewport.free()
	return passed


# ── Fixtures ──


## An event whose one condition is `hp <op> 0`, written the way the picker writes it: no baked
## template, so the descriptor's `{var_name} {op} {value}` is what everything resolves through.
static func _sheet_with_comparison(operator: String, negated: bool) -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	event.conditions.append(_comparison("hp", operator, "0", negated))
	var action: ACEAction = ACEAction.new()
	action.provider_id = "Test"
	action.ace_id = "noop"
	action.codegen_template = "pass"
	event.actions.append(action)
	sheet.events.append(event)
	return sheet


static func _comparison(variable: String, operator: String, value: String, negated: bool) -> ACECondition:
	var condition: ACECondition = ACECondition.new()
	condition.provider_id = "Core"
	condition.ace_id = "CompareVar"
	condition.params = {"var_name": variable, "op": operator, "value": value}
	condition.negated = negated
	return condition


static func _compiled(sheet: EventSheetResource) -> String:
	return str(SheetCompiler.compile(sheet, "user://__comparison_rows.gd").get("output", ""))


## A whole file with `body` as its one raw block, which is what the lift is handed.
static func _source_around(body: String) -> String:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	var event: EventRow = EventRow.new()
	event.trigger_provider_id = "Core"
	event.trigger_id = "OnProcess"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = body
	event.actions.append(raw)
	sheet.events.append(event)
	return str(SheetCompiler.compile(sheet, "user://__compare_src.gd").get("output", ""))


static func _lifted_condition_row(body: String) -> EventRow:
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(_source_around(body))
	return _first_conditioned(imported.events)


static func _first_conditioned(rows: Array) -> EventRow:
	for entry: Variant in rows:
		if entry is EventRow:
			if not (entry as EventRow).conditions.is_empty():
				return entry as EventRow
			var nested: EventRow = _first_conditioned((entry as EventRow).sub_events)
			if nested != null:
				return nested
	return null


static func _lifted_expression(event: EventRow) -> String:
	if event == null or event.conditions.is_empty():
		return "<no condition>"
	var condition: ACECondition = event.conditions[0]
	condition = condition.duplicate()
	condition.negated = false
	return ConditionCodegen.generate_condition(condition)


static func _lifted_negated(event: EventRow) -> bool:
	return event != null and not event.conditions.is_empty() and (event.conditions[0] as ACECondition).negated


## The ACE a lifted row's first condition is, as `provider/ace_id` - the fact that says two spellings
## landed on the same row rather than on two different vocabularies.
static func _lifted_ace(event: EventRow) -> String:
	if event == null or event.conditions.is_empty():
		return "<no condition>"
	var condition: ACECondition = event.conditions[0]
	return "%s/%s" % [condition.provider_id, condition.ace_id]


## What a lifted row's condition cell READS, drawn on a real canvas around that row alone.
static func _row_condition_text(event: EventRow) -> String:
	if event == null:
		return "<no row>"
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.events.append(event)
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_sheet(sheet)
	var reading: String = _condition_text(viewport, sheet)
	viewport.free()
	return reading


## Two flat rows at the same indent: an `if` numbered `head_number`, then the Else that follows it.
static func _numbered_else_rows(head_number: int) -> Array:
	var head_event: EventRow = EventRow.new()
	var head: EventRowData = EventRowData.new()
	head.source_resource = head_event
	head.event_number = head_number
	var else_event: EventRow = EventRow.new()
	else_event.else_mode = EventRow.ElseMode.ELSE
	var tail: EventRowData = EventRowData.new()
	tail.source_resource = else_event
	return [{"row": head}, {"row": tail}]


static func _placed_span(line_index: int, rect: Rect2) -> SemanticSpan:
	var span: SemanticSpan = SemanticSpan.new()
	span.text = "hp ≤ 0"
	span.rect = rect
	span.metadata = {"lane": "condition", "line_index": line_index}
	return span


# ── Row lookups ──


static func _row_for(viewport: EventSheetViewport, resource: Resource) -> EventRowData:
	for entry: Dictionary in viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource == resource:
			return row_data
	return null


static func _span_with(row_data: EventRowData, key: String, value: Variant) -> SemanticSpan:
	if row_data == null:
		return null
	for span: SemanticSpan in row_data.spans:
		if span != null and span.metadata is Dictionary and (span.metadata as Dictionary).get(key) == value:
			return span
	return null


# ── 6. Where the picker files a comparison ──


## K2. One question, one entry: the owner's group keeps Compare variable (and Is boolean set beside
## it), and every other comparison the dialog can write goes under one sub-folder. Nothing is
## deregistered and nothing is renamed - all twelve ids still resolve, so a sheet that already uses
## one still opens, and searching still finds each by its own name.
static func _test_picker_filing() -> bool:
	var passed: bool = true
	var registry: EventSheetACERegistry = EventSheetACERegistry.new()
	registry.refresh_from_sources([], true)
	var filed: Dictionary = {}
	for ace_id: String in COMPARE.COMPARE_ACE_IDS:
		var definition: ACEDefinition = registry.find_definition(COMPARE.PROVIDER, ace_id)
		if definition == null:
			passed = _check("%s is still registered" % ace_id, false, true)
			continue
		var key: String = ACEPickerDialog.comparison_group_key(definition)
		filed[ace_id] = key if not key.is_empty() else definition.category
	passed = _check("the lead comparison stays in the owner's own group",
		str(filed.get(COMPARE.ACE_COMPARE_VAR, "")), ACEPickerDialog.VARIABLES_CATEGORY) and passed
	passed = _check("and Is boolean set is filed there with it",
		registry.find_definition(COMPARE.PROVIDER, "IsBoolSet").category,
		ACEPickerDialog.VARIABLES_CATEGORY) and passed
	var elsewhere: PackedStringArray = PackedStringArray()
	for ace_id: String in COMPARE.COMPARE_ACE_IDS:
		if ace_id != COMPARE.ACE_COMPARE_VAR and str(filed.get(ace_id, "")) != ACEPickerDialog.COMPARISONS_GROUP:
			elsewhere.append(ace_id)
	passed = _check("every other comparison files under the one sub-folder",
		elsewhere, PackedStringArray()) and passed
	passed = _check("which is a sub-folder OF the owner's group",
		ACEPickerDialog.split_subcategory(ACEPickerDialog.COMPARISONS_GROUP),
		PackedStringArray([ACEPickerDialog.VARIABLES_CATEGORY, "All comparisons"])) and passed
	passed = _check("a verb that is not a comparison is filed by its own category",
		ACEPickerDialog.comparison_group_key(registry.find_definition(COMPARE.PROVIDER, "SetVar")), "") and passed
	# The count is the feature: twelve comparisons registered, one of them led with.
	passed = _check("the family is still twelve rows", COMPARE.COMPARE_ACE_IDS.size(), 12) and passed
	return passed


## The one condition cell's text on the sheet's first event.
static func _condition_text(viewport: EventSheetViewport, sheet: EventSheetResource) -> String:
	var row_data: EventRowData = _row_for(viewport, sheet.events[0])
	var span: SemanticSpan = _span_with(row_data, "kind", "condition")
	return span.text if span != null else "<no condition span>"


static func _has_negated_mark(viewport: EventSheetViewport, sheet: EventSheetResource) -> bool:
	var row_data: EventRowData = _row_for(viewport, sheet.events[0])
	return _span_with(row_data, "badge_style", "negated") != null


static func _all_span_text(row_data: EventRowData) -> String:
	if row_data == null:
		return "<no row>"
	var parts: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		if span != null:
			parts.append(str(span.text))
	return " ".join(parts)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] comparison_rows: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
