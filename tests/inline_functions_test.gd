# A function handed to a call over several lines reads as ONE row: the call, with the function a chip.
#
# `enemies.sort_custom(func(a, b) -> bool:` and the lines under it are one statement, and before this
# they drew as a block of code three lines tall. The fold is a pure view: the row keeps its code, the
# hover keeps every line, and the file keeps its bytes.
@tool
class_name InlineFunctionsTest
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	var ok: bool = true
	ok = _test_the_fold() and ok
	ok = _test_the_row() and ok
	return ok


static func _test_the_fold() -> bool:
	var rows: Array = []
	for example: Array in [
		["a one-line body is the chip, without its return",
			"enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:\n\treturn a.position.x < b.position.x\n)",
			"enemies.sort_custom(func(a, b): a.position.x < b.position.x)"],
		["the paren glued to the last body line closes the call the same way",
			"names.sort_custom(func(a: String, b: String) -> bool:\n\treturn a.length() < b.length())",
			"names.sort_custom(func(a, b): a.length() < b.length())"],
		["a longer body shows its first line and says there is more",
			"var picked: Array = names.filter(func(entry: String) -> bool:\n\tvar trimmed: String = entry.strip_edges()\n\treturn not trimmed.is_empty()\n)",
			"var picked: Array = names.filter(func(entry): var trimmed: String = entry.strip_edges() …)"],
		["what follows the function stays as written",
			"follow_option(dropdown, func(index: int) -> String:\n\treturn str(index)\n, true)",
			"follow_option(dropdown, func(index): str(index), true)"],
		["the function may open on a later line of the call, which is then read on one line",
			"var changed: bool = _dock._perform_undoable_sheet_edit(\n\t\"Rename\",\n\tfunc() -> bool:\n\t\trename()\n\t\treturn true\n)",
			"var changed: bool = _dock._perform_undoable_sheet_edit(\"Rename\", func(): rename() …)"],
		["a statement continued over lines in the body is one statement",
			"names.sort_custom(func(a: String, b: String) -> bool:\n\treturn rank(a) < rank(b) \\\n\t\tor a < b)",
			"names.sort_custom(func(a, b): rank(a) < rank(b) or a < b)"],
		["a note inside the body is not its first line",
			"call_deferred_thing(func() -> void:\n\t# later\n\trefresh()\n)",
			"call_deferred_thing(func(): refresh())"],
		["a function not handed to a call is not this",
			"var double := func(value: int) -> int:\n\treturn value * 2", ""],
		["one line is already one row", "items.map(func(v): return v * 2)", ""],
		["func( inside a string is not a function",
			"print(\"func(\",\n\tvalue)", ""],
		["a statement that goes on after the call is not one call",
			"if items.any(func(v: int) -> bool:\n\treturn v > 0\n):\n\tprint(1)", ""],
	]:
		rows.append([example[0], EventSheetInlineFunctions.folded(str(example[1])), example[2]])
	return SUPPORT.pins("inline_functions_test", rows)


static func _test_the_row() -> bool:
	var ok: bool = true
	# Spelled as the one-line twin when a reading knows the twin: Sort by reads the same either way.
	ok = SUPPORT.check("inline_functions_test", "keeping the return gives the one-line twin",
		EventSheetInlineFunctions.folded("shop.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:\n\treturn a.price < b.price)", true),
		"shop.sort_custom(func(a, b): return a.price < b.price)") and ok
	var code: String = "enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:\n\treturn a.position.x < b.position.x\n)"
	var event: EventRow = EventRow.new()
	event.trigger_id = "OnReady"
	var raw: RawCodeRow = RawCodeRow.new()
	raw.code = code
	event.actions.append(raw)
	var viewport: EventSheetViewport = EventSheetViewport.new()
	var spans: Array = viewport._row_builder._build_event_spans(event)
	var action_text: PackedStringArray = PackedStringArray()
	var code_cells: int = 0
	var raw_actions: int = 0
	var last_line: int = -1
	for span: Variant in spans:
		var metadata: Dictionary = (span as SemanticSpan).metadata
		last_line = maxi(last_line, int(metadata.get("line_index", 0)))
		if str(metadata.get("lane", "")) != "action" or int(metadata.get("ace_index", -1)) != 0:
			continue
		action_text.append((span as SemanticSpan).text)
		code_cells += 1 if bool(metadata.get("code_cell", false)) else 0
		raw_actions += 1 if bool(metadata.get("raw_action", false)) else 0
	ok = SUPPORT.check("inline_functions_test", "the statement is one action, its function a chip",
		"".join(action_text).contains("func(a, b): a.position.x < b.position.x"), true) and ok
	ok = SUPPORT.check("inline_functions_test", "and none of it is drawn as code", code_cells, 0) and ok
	ok = SUPPORT.check("inline_functions_test", "it stands for the row's own code, which the hover lists",
		raw_actions > 0, true) and ok
	ok = SUPPORT.check("inline_functions_test", "the line count says one row, as the spans draw it",
		viewport._row_builder._count_event_lines(event), last_line + 1) and ok
	ok = SUPPORT.check("inline_functions_test", "the row keeps the lines it was written in",
		raw.code, code) and ok
	viewport.free()
	return ok
