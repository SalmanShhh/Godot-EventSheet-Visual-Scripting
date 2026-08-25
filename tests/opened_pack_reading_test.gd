# EventForge - a pack opened as a sheet READS like an event sheet.
#
# Three things are pinned here, all of them pure view state over an unchanged .gd:
#   A published verb reads as a TRIGGER: its name and input chips sit in the CONDITION lane -
#       `ƒ Functions ▸ On <name>  chips` - because "when does this run?" is answered by "when it is
#       called". The kind stays a muted word for a condition/expression verb; no category chip, no ★,
#       no "gives back", no description caption. A BBCode display name draws styled, never as raw tags.
#       Its picker metadata answers in the ACE properties panel instead (EventSheetVerbProperties).
#   Unpublished helpers are the SAME Function block (no "internal" badge) with their doc comment
#       as the right-lane caption, gathered under one closed "Helpers" bar - only in a read-only
#       preview, and only as a re-parenting of already-built rows.
#   Reading mode on open: no "+ Add condition" / "+ Add action" scaffolding, and a body-only row
#       inside a verb leaves its left cell blank instead of saying "Always".
#
# Values, never counts: each assertion pins the exact strings a reader sees.
@tool
class_name OpenedPackReadingTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true

	# ── A read-only preview: one verb of each kind, one documented hidden helper ──
	var sheet: EventSheetResource = _preview_sheet()
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var view: EventSheetViewport = dock._active_view()

	# ── the header IS [ƒ, name, input chips] ──────
	var action_row: EventRowData = _row_by_uid(view, "define_fn_take_damage")
	ok = _check("a published verb's header reads as a Function block",
		_span_texts(action_row), PackedStringArray(["ƒ", "On Take damage", "amount"])) and ok
	var condition_row: EventRowData = _row_by_uid(view, "define_fn_is_dead")
	ok = _check("a condition verb says its kind as a muted word",
		_span_texts(condition_row), PackedStringArray(["ƒ", "On Is Dead", "condition"])) and ok
	var expression_row: EventRowData = _row_by_uid(view, "define_fn_health_percent")
	ok = _check("an expression verb says its kind the same way",
		_span_texts(expression_row), PackedStringArray(["ƒ", "On Health %", "expression"])) and ok
	ok = _check("no verb row prints a BBCode tag", _any_span_contains(view, "[b]"), false) and ok
	ok = _check("no row anywhere prints an @ace_ annotation line", _any_span_contains(view, "@ace_"), false) and ok
	ok = _check("the styled name keeps its emphasis as parsed segments (not as tags)",
		_segment_bold_text(action_row), "damage") and ok
	ok = _check("no description caption row is welded above a verb",
		_row_by_uid(view, "verb_note_take_damage") == null, true) and ok

	# The kind is the header's WASH now, so it has to be visible and it has to differ per kind.
	# Compared with a tolerance: a Color stores 32-bit floats, so the alpha read back is the nearest
	# float32 to the constant, not the constant.
	ok = _check("the header carries a visible kind tint",
		action_row != null and is_equal_approx(action_row.custom_color.a, ViewportRowBuilder.VERB_KIND_TINT_ALPHA), true) and ok
	ok = _check("action and condition wash differently",
		_tint_rgb(action_row) != _tint_rgb(condition_row), true) and ok
	ok = _check("condition and expression wash differently",
		_tint_rgb(condition_row) != _tint_rgb(expression_row), true) and ok

	# ── a hidden helper is the same block, with its doc comment in the RIGHT lane ──────
	var helpers_bar_early: EventRowData = _row_by_uid(view, "helpers_group_")
	# Read off the bar's children: the bar ships CLOSED, so its helpers are not in the flat (visible) list.
	var helper_row: EventRowData = helpers_bar_early.children[0] if helpers_bar_early != null and not helpers_bar_early.children.is_empty() else null
	ok = _check("a hidden helper reads as a plain Function block",
		_span_texts(helper_row), PackedStringArray(["ƒ", "On Recalc", "Recomputes the cached totals."])) and ok
	ok = _check("its doc comment is the RIGHT lane's caption",
		_lane_of_text(helper_row, "Recomputes the cached totals."), "action") and ok
	ok = _check("a helper wears no 'internal' badge", _row_has_text(helper_row, "internal"), false) and ok
	var helpers_bar: EventRowData = helpers_bar_early
	ok = _check("the helpers gather under one bar", _span_texts(helpers_bar),
		PackedStringArray(["Helpers", "functions this pack uses inside itself - 1"])) and ok
	ok = _check("the Helpers bar is closed by default", helpers_bar != null and helpers_bar.folded, true) and ok
	ok = _check("the helper row lives INSIDE the bar", _child_uids(helpers_bar), PackedStringArray(["define_fn__recalc"])) and ok
	ok = _check("the Helpers bar owns no resource (it is a lens, not a row)",
		helpers_bar != null and helpers_bar.source_resource == null, true) and ok

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
	ok = _check("an authored sheet keeps its kind badge", _row_has_text(_row_by_uid(authored_view, "define_fn_take_damage"), "Action"), true) and ok
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
	ok = _check("a real opened pack gathers a closed Helpers bar",
		_row_by_uid(pack_view, "helpers_group_") != null, true) and ok
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


static func _row_by_uid(view: EventSheetViewport, prefix: String) -> EventRowData:
	for entry: Dictionary in view.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.row_uid.begins_with(prefix):
			return row_data
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


## The BOLD segment's text on a row's styled name span - proof the tags were parsed, not printed.
static func _segment_bold_text(row_data: EventRowData) -> String:
	if row_data == null:
		return ""
	for span: SemanticSpan in row_data.spans:
		if not (span.metadata is Dictionary):
			continue
		for segment: Variant in (span.metadata as Dictionary).get("bbcode_segments", []):
			if segment is Dictionary and bool((segment as Dictionary).get("bold", false)):
				return str((segment as Dictionary).get("text", ""))
	return ""


static func _tint_rgb(row_data: EventRowData) -> Vector3:
	if row_data == null:
		return Vector3.ZERO
	return Vector3(row_data.custom_color.r, row_data.custom_color.g, row_data.custom_color.b)


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
	if actual == expected:
		print("[PASS] opened_pack_reading_test: %s" % label)
		return true
	print("[FAIL] opened_pack_reading_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
