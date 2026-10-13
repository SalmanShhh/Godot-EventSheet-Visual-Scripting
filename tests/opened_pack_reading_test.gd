# EventForge - a pack opened as a sheet READS like an event sheet.
#
# Three things are pinned here, all of them pure view state over an unchanged .gd:
#   A published verb reads as the same function head every sheet draws: its kind as a coloured word,
#       "Function", "On <name>" exactly as the code names it, what it returns and its tags, then its
#       parameters. Its description is in the name's hover, with how Add Action reads the verb, and
#       its picker metadata answers in the ACE properties panel (EventSheetVerbProperties).
#   Unpublished helpers are the SAME head, in the file's own order - a pack gathers nothing under a
#       bar of its own.
#   Reading mode on open: no "+ Add condition" / "+ Add action" scaffolding, and a body-only row
#       inside a verb leaves its left cell blank instead of saying "Always".
#
# Values, never counts: each assertion pins the exact strings a reader sees.
@tool
class_name OpenedPackReadingTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")


static func run() -> bool:
	# The pinned headers carry no "called by" chips - a cold share index's rendering. Earlier
	# tests legitimately build that index, so the cold start is made here, not assumed.
	EventSheetProjectShareIndex.clear_cache()
	var ok: bool = true

	# ── A read-only preview: one verb of each kind, one documented hidden helper ──
	var sheet: EventSheetResource = _preview_sheet()
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()

	# ── the head: the kind as a coloured word, Function, On <name> as written, then its facts ──────
	var action_row: EventRowData = _row_by_uid(view, "define_fn_take_damage")
	ok = _check("a published verb reads as its function head",
		_span_texts(action_row), PackedStringArray(["Action", "Function", "On take_damage", "In Add Action", "Featured", "PARAM", "float amount"])) and ok
	var condition_row: EventRowData = _row_by_uid(view, "define_fn_is_dead")
	ok = _check("a condition says what it returns",
		_span_texts(condition_row), PackedStringArray(["Condition", "Function", "On is_dead", "returns bool", "In Add Action"])) and ok
	var expression_row: EventRowData = _row_by_uid(view, "define_fn_health_percent")
	ok = _check("an expression says it the same way",
		_span_texts(expression_row), PackedStringArray(["Expression", "Function", "On health_percent", "returns float", "In Add Action"])) and ok
	ok = _check("no row anywhere prints an @ace_ annotation line", _any_span_contains(view, "@ace_"), false) and ok
	ok = _check("the description is not drawn on the row", _any_span_contains(view, "off the pool"), false) and ok
	ok = _check("hovering the name shows it, with how Add Action reads the verb",
		_span_meta(action_row, "On take_damage", "hover_note"),
		"take_damage\nTakes [b]amount[/b] off the pool.\nReads as: Take damage") and ok
	ok = _check("each kind word wears its own colours",
		[_span_meta(action_row, "Action", "badge_bg"), _span_meta(condition_row, "Condition", "badge_bg"),
			_span_meta(expression_row, "Expression", "badge_bg")],
		[Color("#2e5a2a"), Color("#24497a"), Color("#4e3577")]) and ok
	ok = _check("no description caption row is welded above a verb",
		_row_by_uid(view, "verb_note_take_damage") == null, true) and ok
	# ── a pack reads in its file's order: its helper is a function head like any other ──────
	var helper_row: EventRowData = _row_by_uid(view, "define_fn__recalc")
	ok = _check("a hidden helper reads as a function head",
		_span_texts(helper_row), PackedStringArray(["Action", "Function", "On _recalc"])) and ok
	ok = _check("its doc comment is in the name's hover, not on the row",
		str(_span_meta(helper_row, "On _recalc", "hover_note")).get_slice("\n", 1), "Recomputes the cached totals.") and ok
	ok = _check("a pack gathers no Helpers bar", _row_by_uid(view, "helpers_group_"), null) and ok

	# ── Reading mode - no add scaffolding, no "Always" on a body-only row ──────
	ok = _check("no '+ Add condition' anywhere in a read-only preview", _any_span_contains(view, "+ Add condition"), false) and ok
	ok = _check("no '+ Add action' anywhere in a read-only preview", _any_span_contains(view, "+ Add action"), false) and ok
	ok = _check("no '+ Add parameter' cell in a read-only preview", _any_span_contains(view, "+ Add parameter"), false) and ok
	var body_row: EventRowData = action_row.children[0] if action_row != null and not action_row.children.is_empty() else null
	if body_row != null:
		view._ensure_event_spans(body_row)
	ok = _check("a body-only row leaves its left cell blank (no 'Always')",
		_row_has_text(body_row, "Always"), false) and ok
	ok = _check("and it never claims 'Every Tick' either", _row_has_text(body_row, "Every Tick"), false) and ok
	dock.free()

	# ── The same sheet AUTHORED (not read-only): the authoring row and the scaffolding come back ──
	var authored: EventSheetResource = _preview_sheet()
	authored.read_only = false
	authored.external_source_path = ""
	var authored_dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	authored_dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	authored_dock.setup(authored)
	var authored_view: EventSheetViewport = authored_dock._active_view()
	ok = _check("an authored sheet draws the function as an event", _row_has_text(_row_by_uid(authored_view, "define_fn_take_damage"), "On take_damage"), true) and ok
	ok = _check("an authored sheet gathers NO Helpers bar", _row_by_uid(authored_view, "helpers_group_") == null, true) and ok
	ok = _check("an authored sheet keeps its add scaffolding", _any_span_contains(authored_view, "+ Add action"), true) and ok
	authored_dock.free()

	# ── The ACE properties panel: what the header handed over ──
	var verb: EventFunction = _find_function(sheet, "take_damage")
	var rows: Array[Dictionary] = EventSheetVerbProperties.property_rows(verb, sheet)
	ok = _check("the panel answers with the verb's properties, in order",
		_row_labels(rows), PackedStringArray(["Kind", "Category", "Inputs", "Gives back", "Description", "In the picker", "Inserts", "Function"])) and ok
	ok = _check("Kind", _row_value(rows, "Kind"), "Action") and ok
	ok = _check("Category", _row_value(rows, "Category"), "Health") and ok
	ok = _check("Inputs read as name + plain-word type", _row_value(rows, "Inputs"), "amount  number") and ok
	ok = _check("a void action gives back nothing", _row_value(rows, "Gives back"), "nothing") and ok
	ok = _check("Description carries the authored blurb", _row_value(rows, "Description"), "Takes [b]amount[/b] off the pool.") and ok
	ok = _check("the picker row says featured", _row_value(rows, "In the picker"), "★ featured") and ok
	ok = _check("Inserts is the authored codegen template", _row_value(rows, "Inserts"), "$Health.take_damage({amount})") and ok
	ok = _check("Function names the code behind the verb", _row_value(rows, "Function"), "take_damage() in health_behavior.gd") and ok
	var helper_rows: Array[Dictionary] = EventSheetVerbProperties.property_rows(_find_function(sheet, "_recalc"), sheet)
	ok = _check("a helper's picker row says it is not in the picker",
		_row_value(helper_rows, "In the picker"), "not in the picker - this pack uses it inside itself") and ok
	ok = _check("an expression's Gives back reads in plain words",
		_row_value(EventSheetVerbProperties.property_rows(_find_function(sheet, "health_percent"), sheet), "Gives back"), "number") and ok

	# Headless-safe: the panel builds with no display server and no editor singleton.
	var panel: Control = EventSheetVerbProperties.build_panel(verb, sheet)
	ok = _check("the panel builds as a Control, headless", panel is Control, true) and ok
	ok = _check("the panel carries the verb's name as its title (tags stripped)",
		_panel_has_text(panel, "Take damage"), true) and ok
	ok = _check("a null verb degrades instead of crashing",
		EventSheetVerbProperties.build_panel(null, sheet) is Control, true) and ok
	panel.free()

	# Plain-word types: a Node class is one word to a reader, a list is a list.
	ok = _check("a Node class reads as 'object'", ViewportRowBuilder.friendly_type_word("Sprite2D"), "object") and ok
	ok = _check("an Array reads as 'list'", ViewportRowBuilder.friendly_type_word("Array"), "list") and ok
	ok = _check("a Dictionary reads as 'table'", ViewportRowBuilder.friendly_type_word("Dictionary"), "table") and ok
	ok = _check("an unknown class keeps its own name", ViewportRowBuilder.friendly_type_word("HealthPool"), "HealthPool") and ok

	# ── A REAL pack, opened the way a user opens one: the same reading, and no annotation prose ──
	var pack_dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	pack_dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	pack_dock.setup(EventSheetResource.new())
	pack_dock._load_sheet_from_path("res://eventsheet_addons/health/health_behavior.gd")
	var pack_view: EventSheetViewport = pack_dock._active_view()
	ok = _check("an opened pack is a reading surface", pack_view.is_reading_mode(), true) and ok
	ok = _check("no row of a real opened pack prints an @ace_ line", _any_span_contains(pack_view, "@ace_"), false) and ok
	ok = _check("no row of a real opened pack prints a BBCode tag", _any_span_contains(pack_view, "[b]"), false) and ok
	ok = _check("a real opened pack offers no add scaffolding", _any_span_contains(pack_view, "+ Add "), false) and ok
	ok = _check("a real opened pack reads in file order, with no Helpers bar",
		_row_by_uid(pack_view, "helpers_group_"), null) and ok
	pack_dock.free()

	# An `## @ace_*` line never becomes prose.
	ok = _check("an @ace_ line is recognised as annotation", ViewportRowBuilder.is_ace_annotation_line("## @ace_hidden"), true) and ok
	ok = _check("a real doc line is not", ViewportRowBuilder.is_ace_annotation_line("## Recomputes the totals."), false) and ok

	return ok


## A read-only preview standing in for an opened pack: three published verbs (one per kind) and one
## documented hidden helper, plus a body-only row inside the action so the "Always" rule is exercised.
static func _preview_sheet() -> EventSheetResource:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "Health"
	sheet.external_source_path = "res://eventsheet_addons/health/health_behavior.gd"
	sheet.read_only = true
	var damage: EventFunction = _make_function("take_damage", TYPE_NIL, true, "Take [b]damage[/b]", "Health")
	damage.description = "Takes [b]amount[/b] off the pool."
	damage.featured = true
	damage.codegen_template_override = "$Health.take_damage({amount})"
	var amount: ACEParam = ACEParam.new()
	amount.id = "amount"
	amount.type_name = "float"
	damage.params.append(amount)
	var body_event: EventRow = EventRow.new()
	damage.events.append(body_event)
	sheet.functions.append(damage)
	sheet.functions.append(_make_function("is_dead", TYPE_BOOL, true, "", ""))
	sheet.functions.append(_make_function("health_percent", TYPE_FLOAT, true, "Health %", ""))
	var helper: EventFunction = _make_function("_recalc", TYPE_NIL, false, "", "")
	helper.doc_comment = "## @ace_hidden\n## Recomputes the cached totals."
	sheet.functions.append(helper)
	return sheet


static func _make_function(fn_name: String, return_type: int, exposed: bool, display: String, category: String) -> EventFunction:
	var event_function: EventFunction = EventFunction.new()
	event_function.function_name = fn_name
	event_function.return_type = return_type
	event_function.expose_as_ace = exposed
	event_function.ace_display_name = display
	event_function.ace_category = category
	return event_function


static func _find_function(sheet: EventSheetResource, fn_name: String) -> EventFunction:
	for entry: Variant in sheet.functions:
		if entry is EventFunction and (entry as EventFunction).function_name == fn_name:
			return entry as EventFunction
	return null


## Walks the WHOLE tree, not only what is on screen: a pack's reading folds its machinery away, so a
## bar this test asks about may well be inside a closed band.
static func _row_by_uid(view: EventSheetViewport, prefix: String) -> EventRowData:
	for entry: Dictionary in view.get_flat_rows():
		var found: EventRowData = _find_by_uid(entry.get("row"), prefix)
		if found != null:
			return found
	return null


static func _find_by_uid(row_data: EventRowData, prefix: String) -> EventRowData:
	if row_data == null:
		return null
	if row_data.row_uid.begins_with(prefix):
		return row_data
	for child: EventRowData in row_data.children:
		var found: EventRowData = _find_by_uid(child, prefix)
		if found != null:
			return found
	return null


static func _span_texts(row_data: EventRowData) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	if row_data == null:
		return texts
	for span: SemanticSpan in row_data.spans:
		texts.append(str(span.text))
	return texts


static func _child_uids(row_data: EventRowData) -> PackedStringArray:
	var uids: PackedStringArray = PackedStringArray()
	if row_data == null:
		return uids
	for child: EventRowData in row_data.children:
		uids.append(child.row_uid)
	return uids


static func _row_has_text(row_data: EventRowData, needle: String) -> bool:
	for text: String in _span_texts(row_data):
		if text == needle:
			return true
	return false


static func _lane_of_text(row_data: EventRowData, needle: String) -> String:
	if row_data == null:
		return ""
	for span: SemanticSpan in row_data.spans:
		if str(span.text) == needle and span.metadata is Dictionary:
			return str((span.metadata as Dictionary).get("lane", "condition"))
	return ""


static func _span_meta(row_data: EventRowData, text: String, key: String) -> Variant:
	if row_data == null:
		return null
	for span: SemanticSpan in row_data.spans:
		if str(span.text) == text and span.metadata is Dictionary:
			return (span.metadata as Dictionary).get(key)
	return null


## Every span text on every visible row, searched for a fragment - how "no scaffolding anywhere" and
## "no raw annotation anywhere" are proved without naming each row.
static func _any_span_contains(view: EventSheetViewport, needle: String) -> bool:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data == null:
			continue
		view._ensure_event_spans(row_data)
		for span: SemanticSpan in row_data.spans:
			if str(span.text).contains(needle):
				return true
	return false


static func _row_labels(rows: Array[Dictionary]) -> PackedStringArray:
	var labels: PackedStringArray = PackedStringArray()
	for row: Dictionary in rows:
		labels.append(str(row.get("label", "")))
	return labels


static func _row_value(rows: Array[Dictionary], label: String) -> String:
	for row: Dictionary in rows:
		if str(row.get("label", "")) == label:
			return str(row.get("value", ""))
	return ""


## True when any Label / RichTextLabel under the panel carries the text - the panel is built from
## controls, so its content is read by walking it rather than by holding a reference to each field.
static func _panel_has_text(node: Node, needle: String) -> bool:
	if node is Label and (node as Label).text == needle:
		return true
	if node is RichTextLabel and (node as RichTextLabel).text == needle:
		return true
	for child: Node in node.get_children():
		if _panel_has_text(child, needle):
			return true
	return false


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	return SUPPORT.check("opened_pack_reading_test", label, actual, expected)
