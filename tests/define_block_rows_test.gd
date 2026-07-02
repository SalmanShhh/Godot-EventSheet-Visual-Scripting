# EventForge — Define-block rendering: the sheet's functions (its published verbs) appear on the
# canvas as a foldable "Published verbs" section, one Define row per EventFunction. Functions live in
# sheet.functions, a SEPARATE array from sheet.events, so before this view a behaviour pack's whole
# vocabulary was invisible outside the Functions dialog. Pins: the role classification (void=Action /
# bool=Condition / typed=Expression, mirroring the ACE Studio cards), the badge/chip spans, the
# compiler-bound signature line, the fold-with-fingerprint default, and — covenant-critical — that the
# view is a pure READ (opening a real pack still round-trips byte-identically).
@tool
extends RefCounted
class_name DefineBlockRowsTest

static func run() -> bool:
	var ok: bool = true

	# ── A sheet with one verb of each kind + one internal helper ──
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.functions.append(_make_function("take_damage", TYPE_NIL, true, "Take Damage", "Health"))
	sheet.functions.append(_make_function("is_dead", TYPE_BOOL, true, "", ""))
	sheet.functions.append(_make_function("health_percent", TYPE_FLOAT, true, "Health %", ""))
	sheet.functions.append(_make_function("recalc_cache", TYPE_NIL, false, "", ""))

	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()

	# ── The section header: present, folded by default, fingerprint tells the vocabulary weight ──
	var header: EventRowData = _find_row_by_uid_prefix(view, "published_verbs_")
	ok = _check("the Published verbs section exists", header != null, true) and ok
	ok = _check("folded by default (weight at a glance, detail on demand)", header.folded if header != null else false, true) and ok
	ok = _check("one Define child per function", header.children.size() if header != null else -1, 4) and ok
	var fingerprint: String = str(header.spans[1].text) if header != null and header.spans.size() > 1 else ""
	ok = _check("fingerprint counts exposed verbs by role + internals", fingerprint, "⚡1 · ?1 · ƒx1 · 1 internal") and ok

	# ── Role classification mirrors the ACE Studio cards ──
	ok = _check("void → action", ViewportRowBuilder.define_role_for(_make_function("f", TYPE_NIL, true, "", "")), "action") and ok
	ok = _check("bool → condition", ViewportRowBuilder.define_role_for(_make_function("f", TYPE_BOOL, true, "", "")), "condition") and ok
	ok = _check("float → expression", ViewportRowBuilder.define_role_for(_make_function("f", TYPE_FLOAT, true, "", "")), "expression") and ok

	# ── The Define rows themselves (unfold to inspect the children) ──
	var action_row: EventRowData = header.children[0] if header != null else null
	var condition_row: EventRowData = header.children[1] if header != null else null
	var expression_row: EventRowData = header.children[2] if header != null else null
	var internal_row: EventRowData = header.children[3] if header != null else null
	ok = _check("action badge", _span_text(action_row, 0), "Action") and ok
	ok = _check("display name prefers @ace_name", _span_text(action_row, 1), "Take Damage") and ok
	ok = _check("category chip rides along", _row_has_span_text(action_row, "Health"), true) and ok
	ok = _check("an action has NO return chip", _row_has_span_text(action_row, "→ void"), false) and ok
	ok = _check("condition badge", _span_text(condition_row, 0), "Condition") and ok
	ok = _check("condition name falls back to the humanized function name", _span_text(condition_row, 1), "Is Dead") and ok
	ok = _check("condition carries the → bool chip", _row_has_span_text(condition_row, "→ bool"), true) and ok
	ok = _check("expression carries its typed chip", _row_has_span_text(expression_row, "→ float"), true) and ok
	ok = _check("an un-exposed helper is marked internal", _row_has_span_text(internal_row, "internal"), true) and ok
	ok = _check("an exposed verb is NOT marked internal", _row_has_span_text(action_row, "internal"), false) and ok
	ok = _check("the signature line is the compiler's own emission",
		_row_has_span_text(action_row, "func take_damage(amount: float) -> void"), true) and ok

	# ── A function-less sheet grows no section ──
	var empty_dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	empty_dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	empty_dock.setup(EventSheetResource.new())
	ok = _check("no functions → no section", _find_row_by_uid_prefix(empty_dock._active_view(), "published_verbs_") == null, true) and ok
	empty_dock.free()

	# ── Covenant: the view is a pure read — opening a REAL pack still round-trips byte-identically.
	# Since the per-function shell-lift, an opened pack's verbs arrive as REAL EventFunctions, so the
	# Published verbs section appears for packs too — one Define child per lifted function.
	var pack_path: String = "res://eventsheet_addons/health/health_behavior.gd"
	var source: String = (FileAccess.open(pack_path, FileAccess.READ)).get_as_text()
	dock._load_sheet_from_path(pack_path)  # the real user open path (verify-lift included)
	var opened: EventSheetResource = dock.get_current_sheet()
	ok = _check("an opened pack lifts real functions", opened.functions.size() > 20, true) and ok
	var pack_header: EventRowData = _find_row_by_uid_prefix(dock._active_view(), "published_verbs_")
	ok = _check("the pack shows its verbs section", pack_header != null, true) and ok
	ok = _check("one Define child per lifted function",
		pack_header.children.size() if pack_header != null else -1, opened.functions.size()) and ok
	var reemitted: String = str(SheetCompiler.compile(opened, pack_path).get("output", ""))
	ok = _check("round-trip stays byte-identical with the view built (drift=0)", reemitted == source, true) and ok

	dock.free()
	return ok

static func _make_function(fn_name: String, return_type: int, exposed: bool, display: String, category: String) -> EventFunction:
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = fn_name
	event_function.return_type = return_type
	event_function.expose_as_ace = exposed
	event_function.ace_display_name = display
	event_function.ace_category = category
	var param: ACEParam = ACEParam.new()
	param.id = "amount"
	param.type_name = "float"
	event_function.params.append(param)
	return event_function

static func _find_row_by_uid_prefix(view: EventSheetViewport, prefix: String) -> EventRowData:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.row_uid.begins_with(prefix):
			return row_data
	return null

static func _span_text(row_data: EventRowData, index: int) -> String:
	if row_data == null or index >= row_data.spans.size():
		return ""
	return str(row_data.spans[index].text)

static func _row_has_span_text(row_data: EventRowData, needle: String) -> bool:
	if row_data == null:
		return false
	for span: SemanticSpan in row_data.spans:
		if str(span.text) == needle:
			return true
	return false

static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] define_block_rows_test: %s" % label)
		return true
	print("[FAIL] define_block_rows_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
