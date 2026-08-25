# EventForge - a connects-only `_ready` must not sink its file. A `_ready` whose body is nothing
# but connect lines lifts to ZERO events (emission regenerates it from the handlers' connect
# metas), so nothing carried the source's two-blank gap above it - the synthesized `_ready`
# re-emitted with ONE blank, the whole-file byte-verify failed, and EVERY function in the file
# (the menu handler, an unrelated `_draw`, all of them) degraded to raw script blocks. The gap
# (and a non-canonical header spelling) now ride the first lifted event as metadata the compiler
# reads back. Pins: the reported menu-dispatch shape lifts end to end (named `id_pressed` handler
# whose body is a top-level `match id:` with literal arms), the match lifts as a MatchRow with its
# branch text verbatim, one genuinely unliftable function still degrades ALONE, and both fixtures
# round-trip byte-identically.
@tool
class_name ConnectsOnlyReadyLiftTest
extends RefCounted


const MENU_DISPATCH_LINES: Array[String] = [
	"extends Control",
	"",
	"",
	"var sheet_menu: PopupMenu = null",
	"",
	"",
	"func _ready() -> void:",
	"\tsheet_menu.id_pressed.connect(_on_sheet_menu_chosen)",
	"",
	"",
	"func _on_sheet_menu_chosen(id: int) -> void:",
	"\tmatch id:",
	"\t\t0:",
	"\t\t\tprint(\"open\")",
	"\t\t1:",
	"\t\t\tprint(\"save\")",
	"\t\t_:",
	"\t\t\tpush_error(\"unknown menu id\")",
	"",
	"",
	"func _draw() -> void:",
	"\tprint(\"draw\")",
	"",
]


static func run() -> bool:
	var ok: bool = true

	# ── The reported shape: prelude var, two-blank style gaps, connects-only `_ready`, a named
	# menu handler dispatching on a top-level `match id:`, and an unrelated `_draw`. ──
	var source: String = "\n".join(MENU_DISPATCH_LINES)
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	var raw_funcs: Array = _raw_function_headers(sheet)
	ok = _check("no function stays a raw script block", raw_funcs, []) and ok
	var events: Array = _event_rows(sheet)
	ok = _check("both the handler and _draw lift as events", events.size(), 2) and ok
	if events.size() == 2:
		var handler: EventRow = events[0]
		ok = _check("the handler lifts to its signal trigger", handler.trigger_id, "signal:id_pressed") and ok
		ok = _check("wired to the menu the connect line names", handler.trigger_source_path, "sheet_menu") and ok
		ok = _check("the dispatch is one MatchRow action", handler.actions.size() == 1 and handler.actions[0] is MatchRow, true) and ok
		if handler.actions.size() == 1 and handler.actions[0] is MatchRow:
			var dispatch: MatchRow = handler.actions[0]
			ok = _check("the match subject is the signal's id", dispatch.match_expression, "id") and ok
			ok = _check("the literal arms are kept verbatim", dispatch.branches_text,
				"0:\n\tprint(\"open\")\n1:\n\tprint(\"save\")\n_:\n\tpush_error(\"unknown menu id\")") and ok
		ok = _check("the unrelated _draw lifts too", (events[1] as EventRow).trigger_id, "OnDraw") and ok
	sheet.external_source_path = "user://_connects_only_ready_rt.gd"
	var roundtrip: String = str(SheetCompiler.compile(sheet, "user://_connects_only_ready_rt.gd").get("output", ""))
	ok = _check("the full lift round-trips byte-identically", roundtrip == source, true) and ok

	# ── One genuinely unliftable function (a header wrapped over two lines, which is not a header
	# on any path) degrades ALONE: the handler and _draw still lift - anchored in place - and the
	# file still round-trips. This is the standing contract the whole-file revert used to violate. ──
	var hairy_lines: Array[String] = MENU_DISPATCH_LINES.duplicate()
	hairy_lines.remove_at(hairy_lines.size() - 1)
	hairy_lines.append_array([
		"",
		"",
		"func gnarly(",
		"\t\ta: Array) -> void:",
		"\ta.reduce(func(x, y): return x + y)",
		"",
	])
	var hairy_source: String = "\n".join(hairy_lines)
	var hairy_sheet: EventSheetResource = GDScriptImporter.new().import_external_source(hairy_source)
	var hairy_raw: Array = _raw_function_headers(hairy_sheet)
	ok = _check("only the refusing function (and the raw _ready holding its connect) stay raw",
		hairy_raw, ["func _ready() -> void:", "func gnarly("]) and ok
	var hairy_events: Array = _event_rows(hairy_sheet)
	ok = _check("the handler and _draw still lift beside the refusal", hairy_events.size(), 2) and ok
	if hairy_events.size() == 2:
		ok = _check("the handler kept its signal trigger", (hairy_events[0] as EventRow).trigger_id, "signal:id_pressed") and ok
		ok = _check("and its match dispatch", (hairy_events[0] as EventRow).actions.size() == 1 \
			and (hairy_events[0] as EventRow).actions[0] is MatchRow, true) and ok
		ok = _check("_draw kept its trigger", (hairy_events[1] as EventRow).trigger_id, "OnDraw") and ok
	hairy_sheet.external_source_path = "user://_connects_only_ready_hairy_rt.gd"
	var hairy_roundtrip: String = str(SheetCompiler.compile(hairy_sheet, "user://_connects_only_ready_hairy_rt.gd").get("output", ""))
	ok = _check("the partial lift round-trips byte-identically", hairy_roundtrip == hairy_source, true) and ok

	return ok


static func _raw_function_headers(sheet: EventSheetResource) -> Array:
	var headers: Array = []
	for row: Variant in sheet.events:
		if row is RawCodeRow:
			var code: String = (row as RawCodeRow).code
			if code.begins_with("func ") or code.begins_with("static func "):
				headers.append(code.split("\n")[0])
	return headers


static func _event_rows(sheet: EventSheetResource) -> Array:
	var events: Array = []
	for row: Variant in sheet.events:
		if row is EventRow:
			events.append(row)
	return events


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] connects_only_ready_lift_test: %s" % label)
		return true
	print("[FAIL] connects_only_ready_lift_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
