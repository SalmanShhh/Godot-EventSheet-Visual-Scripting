# EventForge - the three readings a TOOL script needed most.
#
#   A multi-line `{...}` / `[...]` used as a VALUE (returned, emitted, appended, declared)
#        reads as ONE row: the statement's own sentence, the word table / list where the literal
#        sat, and each entry as a named chip. The orphan `}` / `})` / `],` row disappears into it.
#   A function handed around as a VALUE reads as an ƒ chip, a Callable local reads
#        `Local function`, `c.call(x)` reads Call c, `c.is_valid()` reads `c is set`, and a
#        one-line map / filter lambda reads in the Array ACEs' own words.
#   A receiver whose declared CLASS the sheet knows names its object column by that class,
#        humanized with the plugin prefix dropped, its own name muted beside it.
#
# All three are DISPLAY-ONLY, so the byte gates below are the point: the same sheet that renders
# the collapsed row must still compile back to the exact source it was opened from. The one
# authoring seam (editing a chip) writes back through the row it came from, and is byte-gated too.
@tool
class_name ValueLiteralRowsTest
extends RefCounted

## A function body holding the four shapes a table can be written as: a returned table, a table passed to a
## call, a nested table, and a declared list. Every one of them is written over several lines, which
## is what the importer splits into one verbatim row per line.
const LITERAL_SOURCE := """extends Node


func snapshot() -> Dictionary:
	return {
		"row_index": row_index,
		"span_index": span_index,
		"kind": kind,
		"source_resource": source,
	}


func request(path: String) -> void:
	targets.append({
		"mode": "replace_action",
		"path": path,
	})


func widths() -> Array:
	print("measuring")
	return [
		first_width,
		second_width,
	]
"""


static func run() -> bool:
	var ok: bool = true

	# ── the run is recognised, and the rows it consumes vanish into the lead ───────
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(LITERAL_SOURCE)
	sheet.external_source_path = "user://w12_literal.gd"
	ok = _check("the opened file reproduces byte-identically",
		str(SheetCompiler.compile(sheet, "user://w12_literal.gd").get("output", "")), LITERAL_SOURCE) and ok

	var snapshot_actions: Array = _actions_of(sheet, "snapshot")
	var snapshot_groups: Dictionary = EventSheetValueLiteralRows.groups(snapshot_actions)
	ok = _check("the returned table is one run", (snapshot_groups["leads"] as Dictionary).size(), 1) and ok
	var returned: Dictionary = _lead(snapshot_groups)
	ok = _check("the statement reads with a hole where the literal sat",
		str(returned.get("statement", "")).strip_edges(), "return ⟦⟧") and ok
	ok = _check("it is a table", str(returned.get("open", "")), "{") and ok
	ok = _check("every entry line became an entry",
		(returned.get("entries", []) as Array).size(), 4) and ok
	ok = _check("the closing bracket row is consumed, not rendered",
		(snapshot_groups["consumed"] as Dictionary).size(), 5) and ok
	ok = _check("a table entry reads key = value",
		EventSheetValueLiteralRows.chip_text((returned.get("entries", []) as Array)[1], true),
		"span index = span index") and ok
	ok = _check("Familiar Words off shows the file's own spelling",
		EventSheetValueLiteralRows.chip_text((returned.get("entries", []) as Array)[1], false),
		"\"span_index\" = span_index") and ok

	var request_actions: Array = _actions_of(sheet, "request")
	var request_groups: Dictionary = EventSheetValueLiteralRows.groups(request_actions)
	var appended: Dictionary = _lead(request_groups)
	ok = _check("a literal passed to a call keeps the call around the hole",
		str(appended.get("statement", "")).strip_edges(), "targets.append(⟦⟧)") and ok
	ok = _check("a string value keeps its quotes and reads as words",
		EventSheetValueLiteralRows.chip_text((appended.get("entries", []) as Array)[0], true),
		"mode = \"replace action\"") and ok

	var widths_actions: Array = _actions_of(sheet, "widths")
	var widths_groups: Dictionary = EventSheetValueLiteralRows.groups(widths_actions)
	ok = _check("the returned list is one run", (widths_groups["leads"] as Dictionary).size(), 1) and ok
	var listed: Dictionary = _lead(widths_groups)
	ok = _check("a returned list is a list", str(listed.get("open", "")), "[") and ok
	ok = _check("a list entry is its value alone",
		EventSheetValueLiteralRows.chip_text((listed.get("entries", []) as Array)[0], true),
		"first width") and ok
	ok = _check("the statement BEFORE the literal is not part of the run",
		(widths_groups["consumed"] as Dictionary).has(0), false) and ok

	# ── the classifier refuses what it cannot account for ───────
	ok = _check("a wrapped CALL is not a literal",
		EventSheetValueLiteralRows.groups(_raw_rows(["foo(", "\tbar,", ")"]))["leads"].is_empty(), true) and ok
	ok = _check("an unbalanced run is refused",
		EventSheetValueLiteralRows.groups(_raw_rows(["return {", "\t\"a\": 1,"]))["leads"].is_empty(), true) and ok
	ok = _check("a comment among the entries leaves the run alone",
		EventSheetValueLiteralRows.groups(_raw_rows(["return {", "\t# why", "\t\"a\": 1,", "}"]))["leads"].is_empty(), true) and ok
	var nested: Dictionary = _lead(EventSheetValueLiteralRows.groups(_raw_rows(
		["return {", "\t\"outer\": {", "\t\t\"inner\": 1,", "\t},", "}"])))
	ok = _check("a nested literal nests",
		EventSheetValueLiteralRows.chip_text((nested.get("entries", []) as Array)[0], true),
		"outer = table (inner = 1)") and ok

	# ── the fold, and the hover that never hides an entry ───────
	var long_run: Array = _raw_rows(["return {", "\t\"a\": 1,", "\t\"b\": 2,", "\t\"c\": 3,", "\t\"d\": 4,", "}"])
	var long_lead: Dictionary = _lead(EventSheetValueLiteralRows.groups(long_run))
	ok = _check("four entries is one more than the fold shows",
		(long_lead.get("entries", []) as Array).size() - EventSheetValueLiteralRows.FOLD_AT, 1) and ok
	ok = _check("the hover carries the whole literal",
		EventSheetValueLiteralRows.full_text(long_lead.get("entries", []), "{", true),
		"table: a = 1 · b = 2 · c = 3 · d = 4") and ok

	# ── authoring: a chip edit rewrites ITS row, and the file still round-trips ──────
	var edit_sheet: EventSheetResource = GDScriptImporter.new().import_external_source(LITERAL_SOURCE)
	edit_sheet.external_source_path = "user://w12_edited.gd"
	var edit_event: EventRow = _event_of(edit_sheet, "snapshot")
	# The field opens on the FILE's own spelling (edit_text), never on the reading - so what comes
	# back is source, and a quoted key stays a quoted key.
	ok = _check("the chip's edit field holds the source, not the reading",
		EventSheetValueLiteralRows.chip_text(
			(returned.get("entries", []) as Array)[1], false),
		"\"span_index\" = span_index") and ok
	ok = _check("editing a chip is accepted", EventSheetValueLiteralRows.apply_entry_edit(
		edit_event, "literal_entry_line:0:2", "\"span_index\" = 7"), true) and ok
	ok = _check("the edited row keeps its indent and its comma",
		(edit_event.actions[2] as RawCodeRow).code, "\t\"span_index\": 7,") and ok
	ok = _check("an empty edit is refused", EventSheetValueLiteralRows.apply_entry_edit(
		edit_event, "literal_entry_line:0:2", "   "), false) and ok
	ok = _check("a multi-line edit is refused", EventSheetValueLiteralRows.apply_entry_edit(
		edit_event, "literal_entry_line:0:2", "a\nb"), false) and ok
	ok = _check("the edited file still compiles to exactly what the rows say",
		str(SheetCompiler.compile(edit_sheet, "user://w12_edited.gd").get("output", "")),
		LITERAL_SOURCE.replace("\t\t\"span_index\": span_index,", "\t\t\"span_index\": 7,")) and ok

	# ── measured: the plugin's own biggest file, before and after ──────
	# The number that matters is that the collapse CLAIMS the shape at all on real code: these are
	# the rows that were bare literal entries and orphan brackets, and every one of them is now an
	# entry chip on a row that says what the statement does.
	var measured: Dictionary = _measure("res://addons/eventsheet/editor/event_sheet_viewport.gd")
	ok = _check("the viewport's literal runs are claimed", int(measured["runs"]) >= 15, true) and ok
	ok = _check("and they take at least a hundred bare lines with them",
		int(measured["claimed"]) >= 100, true) and ok

	# ── a function handed around as a value ───────
	var function_context: Dictionary = {"function_params": {"_open_sheet_in_workspace": []}}
	ok = _check("a bare function name is an ƒ chip",
		EventSheetSentence.expression_text("_open_sheet_in_workspace", function_context),
		"ƒ Open Sheet In Workspace") and ok
	ok = _check("a name the sheet does not declare is left alone",
		EventSheetSentence.expression_text("some_variable", function_context), "some_variable") and ok
	ok = _check("Callable(self, \"f\") is the same chip",
		EventSheetSentence.expression_text("Callable(self, \"on_done\")", {}), "ƒ On Done") and ok
	ok = _check("a Callable local reads Local function",
		EventSheetSentence.type_word("Callable"), "function") and ok
	ok = _check("a held function's call reads as a Call",
		_sentence_text("\tcallback.call(result)", {"variable_types": {"callback": "Callable"}}),
		"Call callback   result") and ok
	ok = _check("a call by NAME on an untyped receiver is not claimed as one",
		_sentence_text("\tnode.call(\"heal\")", {}).contains("Call node"), false) and ok
	ok = _check("asking whether a held function is there reads `is set`",
		EventSheetSentence.expression_text("callback.is_valid()", {}), "callback is set") and ok
	ok = _check("a one-line map lambda reads as each one's member",
		EventSheetSentence.expression_text("rows.map(func(r): return r.name)", {}),
		"rows each one's name") and ok
	ok = _check("a one-line filter lambda reads as those where",
		EventSheetSentence.expression_text("rows.filter(func(r): return r.ready)", {}),
		"rows those where ready") and ok
	ok = _check("a lambda with a BODY is left as code",
		EventSheetSentence.lambda_over_list_words("rows.map(func(r):\n\treturn r.name)", {}), "") and ok
	# The way back: the words the chip shows name the function they came from, and words that
	# name nothing this sheet declares resolve to nothing rather than to a guess.
	ok = _check("the chip's words name the function behind them",
		EventSheetSentence.function_reference_name("ƒ Open Sheet In Workspace", function_context),
		"_open_sheet_in_workspace") and ok
	ok = _check("words naming no declared function resolve to nothing",
		EventSheetSentence.function_reference_name("ƒ Something Else", function_context), "") and ok
	ok = _check("plain words are not a chip at all",
		EventSheetSentence.function_reference_name("Open Sheet In Workspace", function_context), "") and ok
	ok = _function_chip_span() and ok

	# ── the object column says what the receiver IS ───────
	ok = _check("the plugin prefix comes off and the acronym stays",
		EventSheetViewportReadingRows.class_object_label("EventSheetACERegistry"), "ACE registry") and ok
	ok = _check("a two-word class reads as two words",
		EventSheetViewportReadingRows.class_object_label("EventSheetFindBar"), "Find bar") and ok
	ok = _check("a class with no plugin prefix is read the same way",
		EventSheetViewportReadingRows.class_object_label("EditorDock"), "Editor dock") and ok
	var typed_context: Dictionary = {"variable_types": {"_registry": "EventSheetACERegistry"}}
	var typed: Dictionary = EventSheetViewportReadingRows.typed_object_label("_registry", typed_context, true)
	ok = _check("the object label becomes the class", str(typed.get("label", "")), "ACE registry") and ok
	ok = _check("and the variable's own name is muted beside it",
		str(typed.get("note", "")), "registry") and ok
	ok = _check("Familiar Words off shows the class as written",
		str(EventSheetViewportReadingRows.typed_object_label("_registry", typed_context, false).get("label", "")),
		"EventSheetACERegistry") and ok
	ok = _check("an undeclared receiver keeps the label it had",
		EventSheetViewportReadingRows.typed_object_label("helper", {}, true).is_empty(), true) and ok
	ok = _check("System is never renamed",
		EventSheetViewportReadingRows.typed_object_label("System",
			{"variable_types": {"System": "EventSheetDock"}}, true).is_empty(), true) and ok

	return ok


## The ƒ chip on a real row is a span of its OWN, carrying the raw name a click jumps to -
## and splitting it off changes not one word of what the row says. Both halves are pinned here,
## because a split that quietly dropped or reordered a word would still look like a working link.
static func _function_chip_span() -> bool:
	var ok: bool = true
	var handler: EventFunction = EventFunction.new()
	handler.function_name = "_open_sheet_in_workspace"
	var wiring: EventFunction = EventFunction.new()
	wiring.function_name = "_wire_up"
	var event_row: EventRow = EventRow.new()
	event_row.event_uid = "wire"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = "menu.open_sheet = _open_sheet_in_workspace"
	event_row.actions.append(raw)
	wiring.events.append(event_row)
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node"
	sheet.functions.append(wiring)
	sheet.functions.append(handler)
	var style: EventSheetEditorStyle = EventSheetEditorStyle.new()
	style.ensure_defaults()
	sheet.editor_style = style
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_ace_registry(EventSheetACERegistry.new())
	viewport.set_sheet(sheet)
	viewport.set_reading_mode(true)
	var chip: SemanticSpan = null
	var whole: String = ""
	for row_data: EventRowData in _rows_of(viewport):
		if row_data.source_resource != event_row:
			continue
		viewport._row_builder._ensure_event_spans(row_data)
		for span: SemanticSpan in row_data.spans:
			if not str(span.metadata.get("kind", "")) in ["action", "function_ref"]:
				continue
			whole += span.text
			if str(span.metadata.get("kind", "")) == "function_ref":
				chip = span
	ok = _check("the row's ƒ chip is a span of its own", chip != null, true) and ok
	if chip != null:
		ok = _check("the chip reads as the function's name in words", chip.text,
			"ƒ open sheet in workspace") and ok
		ok = _check("and carries the raw name a click jumps to",
			str(chip.metadata.get("name", "")), "_open_sheet_in_workspace") and ok
	ok = _check("splitting the chip off changes no word of the row",
		whole.strip_edges(), "Set open sheet to ƒ open sheet in workspace") and ok
	# The seam the click lands on: the same lookup the Outline uses, answering with the function.
	ok = _check("the name the chip carries finds the function it names",
		ViewportRowBuilder.find_function_by_name(sheet, "_open_sheet_in_workspace"), handler) and ok
	viewport.free()
	return ok


## Every row of a built viewport, parents before children.
static func _rows_of(viewport: EventSheetViewport) -> Array:
	var found: Array = []
	var pending: Array = viewport._root_rows.duplicate()
	while not pending.is_empty():
		var row_data: EventRowData = pending.pop_front()
		found.append(row_data)
		pending.append_array(row_data.children)
	return found


## The one lead of a group result, or {} - so a classifier that claims nothing fails the check
## above it instead of crashing the whole suite on an empty list.
static func _lead(groups: Dictionary) -> Dictionary:
	var leads: Dictionary = groups.get("leads", {})
	return leads.values()[0] if not leads.is_empty() else {}


## The actions of the event that carries one function's body.
static func _actions_of(sheet: EventSheetResource, function_name: String) -> Array:
	var event: EventRow = _event_of(sheet, function_name)
	return event.actions if event != null else []


static func _event_of(sheet: EventSheetResource, function_name: String) -> EventRow:
	for entry: Variant in sheet.functions:
		var found: EventFunction = entry as EventFunction
		if found == null or found.function_name != function_name:
			continue
		for row: Variant in found.events:
			if row is EventRow:
				return row as EventRow
	return null


## A throwaway row list built from raw lines, for driving the classifier without an importer.
static func _raw_rows(lines: PackedStringArray) -> Array:
	var rows: Array = []
	for line: String in lines:
		var row := RawCodeRow.new()
		row.code = line
		rows.append(row)
	return rows


## How many literal runs one of the plugin's own files holds, and how many bare lines they take.
static func _measure(path: String) -> Dictionary:
	var sheet: EventSheetResource = GDScriptImporter.new().import_external(path)
	var tally: Dictionary = {"runs": 0, "claimed": 0}
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			_walk((entry as EventFunction).events, tally)
	return tally


static func _walk(items: Array, tally: Dictionary) -> void:
	var groups: Dictionary = EventSheetValueLiteralRows.groups(items)
	tally["runs"] = int(tally["runs"]) + (groups["leads"] as Dictionary).size()
	tally["claimed"] = int(tally["claimed"]) + (groups["consumed"] as Dictionary).size() \
		+ (groups["leads"] as Dictionary).size()
	for item: Variant in items:
		if item is EventRow:
			_walk((item as EventRow).actions, tally)
			_walk((item as EventRow).sub_events, tally)
		elif item is EventFunction:
			_walk((item as EventFunction).events, tally)
		elif item is EventGroup:
			_walk((item as EventGroup).events, tally)


## The sentence a statement reads as, segments joined - one VALUE to compare per check.
static func _sentence_text(code: String, context: Dictionary) -> String:
	var sentence: Dictionary = ViewportRowBuilder.statement_sentence(code, context)
	if sentence.is_empty():
		return ""
	var text: String = ""
	for segment: Variant in (sentence.get("segments", []) as Array):
		text += str((segment as Dictionary).get("text", ""))
	return text


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] value_literal_rows_test: %s" % label)
		return true
	print("[FAIL] value_literal_rows_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
