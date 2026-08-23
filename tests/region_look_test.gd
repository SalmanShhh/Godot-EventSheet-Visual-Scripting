# Godot EventSheets - a region reads as a fold mark, and can trade places with a group (slice E).
#
# What this pins, in the order a reader meets it:
#   1. THE ROW. A fence is its OWN row type, asked for through the Custom Block API rather than
#      borrowed from the group bar: a dashed `#` badge, the name, the description beside it and the
#      fence line echoed at the right edge - all found by span METADATA, never by position.
#   2. THE PAIRING. Unchanged by the new look: a matched pair still adopts its rows, the closing
#      fence still rides last, and an unmatched fence still stays flat (the wart-not-error covenant).
#   3. THE REFACTORS. Region to group and back, on the plain container the rows live in - and the
#      round trip is byte-identical, which is the only proof that "nothing inside moves" is true.
#   4. THE ORPHAN. The amber note under an unmatched fence, the row its fix names, and the fence the
#      fix actually writes.
@tool
class_name RegionLookTest
extends RefCounted


static func run() -> bool:
	var all_passed: bool = true
	all_passed = _test_row_look() and all_passed
	all_passed = _test_look_is_reusable() and all_passed
	all_passed = _test_pairing_unchanged() and all_passed
	all_passed = _test_refactors() and all_passed
	all_passed = _test_orphan_note() and all_passed
	if all_passed:
		print("[PASS] region_look: a region reads as the fold mark it is.")
	return all_passed


# ── 1. The row ──


static func _test_row_look() -> bool:
	var passed: bool = true
	# The kind asks for the look through the public hook; every other kind keeps the flat block row.
	passed = _check("the region kind asks for the region look",
		EventSheetBlockRegistry.get_kind("region").row_style(null), "region") and passed
	passed = _check("an ordinary kind keeps the flat block row",
		EventSheetBlockRegistry.get_kind("preload").row_style(null), "section") and passed

	var opener: CustomBlockRow = _region("Debug helpers", false)
	opener.fields["description"] = "prints and cheats"
	var sheet: EventSheetResource = _sheet_with([opener, _comment("inside"), _region("", true)])
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_sheet(sheet)
	var head: EventRowData = _row_for(viewport, opener)
	passed = _check("an opening fence is a REGION row, not a group",
		head.row_type if head != null else -1, EventRowData.RowType.REGION) and passed
	passed = _check("it leads with the fold mark the file starts the line with",
		_span_text(head, "region_badge", true), EventSheetRegionFacts.FENCE_GLYPH) and passed
	passed = _check("the mark is a DASHED outline, the script editor's fold stroke",
		_span_flag(head, "region_badge", true, "badge_dashed"), true) and passed
	passed = _check("the name reads as the name", _span_text(head, "region_title", true), "Debug helpers") and passed
	passed = _check("and renames in place", _span_meta(head, "region_title", true, "edit_kind"), "region_name") and passed
	passed = _check("the description sits muted beside it",
		_span_text(head, "region_note", true), "prints and cheats") and passed
	passed = _check("the echo is the line the file has",
		_span_text(head, "region_fence", "open"), "#region Debug helpers") and passed
	passed = _check("the echo hugs the right edge",
		_span_flag(head, "region_fence", "open", "align_right"), true) and passed

	# The closing fence: one slim tick whose only text is the line it stands for.
	var tick: EventRowData = head.children[head.children.size() - 1] if head != null and not head.children.is_empty() else null
	passed = _check("the closing fence is a REGION row too",
		tick.row_type if tick != null else -1, EventRowData.RowType.REGION) and passed
	passed = _check("its only text is the #endregion echo",
		_all_span_text(tick), EventSheetRegionFacts.CLOSING_LINE) and passed
	passed = _check("and it draws slimmer than an ordinary row",
		_row_height_of(viewport, tick) < _row_height_of(viewport, head), true) and passed

	# Folded, the head says how much it holds and echoes both fences on one line.
	viewport._fold_state[head.row_uid] = true
	viewport.set_sheet(sheet)
	var folded: EventRowData = _row_for(viewport, opener)
	passed = _check("a folded region says how much it holds",
		_span_text(folded, "region_note", true), "1 row") and passed
	passed = _check("and echoes both fences with the body elided",
		_span_text(folded, "region_fence", "open"), "#region Debug helpers … #endregion") and passed
	viewport.free()
	return passed


# ── 1b. The look is a hook, not a privilege of one kind ──


## The row LOOK is asked for through the public Custom Block API, so a kind that is NOT the built-in
## region can wear it - which is the whole reason the region stopped borrowing the group bar through
## a private branch. Such a row reads with the kind's OWN words: EventSheetRegionFacts answers only
## about the fences it owns, so the title is the kind's summary and the echo is the last line it
## emits.
static func _test_look_is_reusable() -> bool:
	var passed: bool = true
	var script: GDScript = GDScript.new()
	script.source_code = "extends EventSheetBlockKind\n\n\nfunc summary(block: CustomBlockRow) -> String:\n\treturn str(block.fields.get(\"name\", \"\"))\n\n\nfunc emit(block: CustomBlockRow) -> PackedStringArray:\n\treturn PackedStringArray([\"# --- %s ---\" % str(block.fields.get(\"name\", \"\"))])\n\n\nfunc style(_block: CustomBlockRow) -> Dictionary:\n\treturn {\"accent\": Color(\"#33cc88\")}\n\n\nfunc row_style(_entry: Resource) -> String:\n\treturn \"region\"\n"
	passed = _check("a kind that asks for the fold-mark look parses", script.reload(), OK) and passed
	var kind: EventSheetBlockKind = script.new() as EventSheetBlockKind
	kind.kind_id = "region_look_test.chapter"
	kind.title = "Chapter"
	EventSheets.register_block_kind(kind)
	var block: CustomBlockRow = CustomBlockRow.new()
	block.kind_id = kind.kind_id
	block.fields = {"name": "Movement"}
	var sheet: EventSheetResource = _sheet_with([block])
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_sheet(sheet)
	var row: EventRowData = _row_for(viewport, block)
	passed = _check("a kind that asks for the look is drawn as a fold mark",
		row.row_type if row != null else -1, EventRowData.RowType.REGION) and passed
	passed = _check("it reads with its OWN name, never the region's placeholder",
		_span_text(row, "region_title", true), "Movement") and passed
	passed = _check("and echoes the line IT writes",
		_span_text(row, "region_fence", "open"), "# --- Movement ---") and passed
	passed = _check("and wears the tint its style() asks for, the same hook a flat row tints with",
		row.custom_color if row != null else Color(), Color("#33cc88")) and passed
	passed = _check("which is the line the compile really writes",
		str(SheetCompiler.compile(sheet).get("output", "")).contains("# --- Movement ---"), true) and passed
	passed = _check("and the API answers the same line for that row",
		EventSheets.code_line(block), "# --- Movement ---") and passed
	viewport.free()
	return passed


# ── 2. The pairing, unchanged ──


static func _test_pairing_unchanged() -> bool:
	var passed: bool = true
	var container: Array = [
		_region("Combat", false), _comment("a"), _comment("b"), _region("", true), _comment("outside")
	]
	var paired: Dictionary = EventSheetRegionFacts.pairing(container)
	passed = _check("a matched pair pairs", str(paired["pairs"]), str({0: 3})) and passed
	passed = _check("nothing is orphaned", [paired["orphan_openers"], paired["orphan_closers"]], [[], []]) and passed

	var nested: Array = [
		_region("Outer", false), _region("Inner", false), _comment("x"), _region("", true), _region("", true)
	]
	passed = _check("regions nest by a stack, innermost first",
		str(EventSheetRegionFacts.pairing(nested)["pairs"]), str({1: 3, 0: 4})) and passed

	var lopsided: Array = [_region("", true), _region("Unclosed", false), _comment("tail")]
	var lopsided_pairing: Dictionary = EventSheetRegionFacts.pairing(lopsided)
	passed = _check("a closer with nothing above it is an orphan",
		lopsided_pairing["orphan_closers"], [0] as Array[int]) and passed
	passed = _check("an opener that never closes is an orphan",
		lopsided_pairing["orphan_openers"], [1] as Array[int]) and passed

	# The view still adopts the rows between a pair, and the model still compiles the same bytes.
	var sheet: EventSheetResource = _sheet_with(container)
	var before: String = str(SheetCompiler.compile(sheet).get("output", ""))
	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_sheet(sheet)
	var head: EventRowData = _row_for(viewport, container[0])
	passed = _check("the opener adopts its rows plus the closing fence",
		head.children.size() if head != null else -1, 3) and passed
	passed = _check("building rows never touches the model bytes",
		str(SheetCompiler.compile(sheet).get("output", "")), before) and passed
	viewport.free()
	return passed


# ── 3. The refactors ──


static func _test_refactors() -> bool:
	var passed: bool = true
	var source: String = "extends Node\n\n#region Combat\n# hurt rules\n#endregion\n"
	var sheet: EventSheetResource = GDScriptImporter.new().import_external_source(source)
	sheet.external_source_path = "user://region_refactor.gd"
	passed = _check("the fixture round-trips before anything is refactored",
		str(SheetCompiler.compile(sheet, "user://region_refactor.gd").get("output", "")), source) and passed

	var opener: CustomBlockRow = _first_opening_fence(sheet)
	var group: EventGroup = EventSheetRefactor.region_to_group(sheet.events, opener)
	passed = _check("region to group makes a group", group != null, true) and passed
	passed = _check("it takes the region's name", group.display_name() if group != null else "", "Combat") and passed
	passed = _check("it keeps the rows that were inside",
		group.child_rows().size() if group != null else -1, 1) and passed
	passed = _check("and both fences are gone",
		EventSheetRegionFacts.pairing(sheet.events)["pairs"].is_empty(), true) and passed

	passed = _check("a plain group can go back", EventSheetRefactor.group_to_region_problem(group), "") and passed
	passed = _check("group to region writes the pair",
		EventSheetRefactor.group_to_region(sheet.events, group), true) and passed
	passed = _check("the round trip is byte-identical",
		str(SheetCompiler.compile(sheet, "user://region_refactor.gd").get("output", "")), source) and passed

	# What a region cannot carry, said in the words the menu item wears.
	var with_local := EventGroup.new()
	with_local.group_name = "Combat"
	with_local.local_variables.append(LocalVariable.new())
	passed = _check("a group with a local says so",
		EventSheetRefactor.group_to_region_problem(with_local), "has 1 local") and passed
	var switchable := EventGroup.new()
	switchable.group_name = "Tutorial"
	switchable.runtime_toggleable = true
	passed = _check("a switchable group says so",
		EventSheetRefactor.group_to_region_problem(switchable), "can be switched at runtime") and passed
	passed = _check("and the refactor refuses it",
		EventSheetRefactor.group_to_region([switchable], switchable), false) and passed

	# Remove keeps everything the fences held.
	var kept_sheet: EventSheetResource = _sheet_with([
		_region("Combat", false), _comment("a"), _comment("b"), _region("", true)
	])
	var kept_opener: CustomBlockRow = _first_opening_fence(kept_sheet)
	passed = _check("removing a region keeps its rows",
		EventSheetRefactor.remove_region_keep_rows(kept_sheet.events, kept_opener), 2) and passed
	passed = _check("and leaves nothing but them", kept_sheet.events.size(), 2) and passed
	return passed


# ── 4. The orphan ──


static func _test_orphan_note() -> bool:
	var passed: bool = true
	var opener: CustomBlockRow = _region("Debug helpers", false)
	var sheet: EventSheetResource = _sheet_with([opener, _comment("one"), _comment("two")])
	passed = _check("the closer belongs at the end when nothing follows",
		EventSheetRegionFacts.closer_insert_index(sheet.events, 0), 3) and passed

	var viewport: EventSheetViewport = EventSheetViewport.new()
	viewport.set_sheet(sheet)
	var note: EventRowData = _note_row(viewport)
	passed = _check("an unclosed fence gets a note under it", note != null, true) and passed
	passed = _check("and it says what is wrong and what to write",
		_span_text(note, "region_orphan", "message"),
		"Debug helpers never closes, so it cannot fold. Add #endregion after the last row you want inside.") and passed
	passed = _check("the fix names the row the fence would land after",
		note.spans[note.spans.size() - 1].text if note != null else "", "Close after row 4") and passed

	# The fix writes the fence exactly there, and the sheet pairs afterwards.
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(sheet)
	var live_note: EventRowData = _note_row(dock._active_view())
	dock._close_orphan_region(live_note)
	var closed: Array = dock.get_current_sheet().events
	passed = _check("the fence lands after the last row", closed.size(), 4) and passed
	passed = _check("and it is a closing fence", EventSheetRegionFacts.is_closing_fence(closed[3]), true) and passed
	passed = _check("so the region pairs now",
		EventSheetRegionFacts.pairing(closed)["orphan_openers"].is_empty(), true) and passed
	dock.free()

	# A closer with nothing above it says so too, and offers no fix - there is nothing to write.
	var lone: EventSheetResource = _sheet_with([_region("", true), _comment("after")])
	viewport.set_sheet(lone)
	var lone_note: EventRowData = _note_row(viewport)
	passed = _check("a lone closer gets its own note",
		_span_text(lone_note, "region_orphan", "message"),
		"#endregion closes nothing - there is no #region above it. Remove it, or open a region first.") and passed
	passed = _check("with no fix beside it", lone_note.spans.size() if lone_note != null else -1, 2) and passed
	viewport.free()
	return passed


# ── Fixtures and span lookups ──


static func _sheet_with(entries: Array) -> EventSheetResource:
	var sheet := EventSheetResource.new()
	for entry: Variant in entries:
		sheet.events.append(entry as Resource)
	return sheet


static func _region(label: String, is_end: bool) -> CustomBlockRow:
	var block := CustomBlockRow.new()
	block.kind_id = EventSheetRegionFacts.KIND_ID
	block.fields = {"label": label, "is_end": is_end}
	return block


static func _comment(text: String) -> CommentRow:
	var comment := CommentRow.new()
	comment.text = text
	return comment


static func _first_opening_fence(sheet: EventSheetResource) -> CustomBlockRow:
	for entry: Variant in sheet.events:
		if EventSheetRegionFacts.is_opening_fence(entry):
			return entry as CustomBlockRow
	return null


static func _row_for(viewport: EventSheetViewport, resource: Resource) -> EventRowData:
	for entry: Dictionary in viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.source_resource == resource:
			return row_data
	return null


static func _row_height_of(viewport: EventSheetViewport, row_data: EventRowData) -> float:
	var rows: Array[Dictionary] = viewport.get_flat_rows()
	for index: int in range(rows.size()):
		if rows[index].get("row") == row_data:
			return viewport.get_row_height(index)
	return -1.0


static func _note_row(viewport: EventSheetViewport) -> EventRowData:
	for entry: Dictionary in viewport.get_flat_rows():
		var row_data: EventRowData = entry.get("row")
		if row_data != null and row_data.row_uid.begins_with("region_orphan_"):
			return row_data
	return null


## The first span whose metadata `key` equals `value`, or null.
static func _span_with(row_data: EventRowData, key: String, value: Variant) -> SemanticSpan:
	if row_data == null:
		return null
	for span: SemanticSpan in row_data.spans:
		if span == null or not (span.metadata is Dictionary):
			continue
		if (span.metadata as Dictionary).get(key) == value:
			return span
	return null


static func _span_text(row_data: EventRowData, key: String, value: Variant) -> String:
	var span: SemanticSpan = _span_with(row_data, key, value)
	return span.text if span != null else "<no span %s=%s>" % [key, str(value)]


static func _span_meta(row_data: EventRowData, key: String, value: Variant, read: String) -> String:
	var span: SemanticSpan = _span_with(row_data, key, value)
	return str((span.metadata as Dictionary).get(read, "")) if span != null else ""


static func _span_flag(row_data: EventRowData, key: String, value: Variant, flag: String) -> bool:
	var span: SemanticSpan = _span_with(row_data, key, value)
	return bool((span.metadata as Dictionary).get(flag, false)) if span != null else false


## Every span's text on a row, joined - the "its only text is this" assertion.
static func _all_span_text(row_data: EventRowData) -> String:
	if row_data == null:
		return "<no row>"
	var parts: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		if span != null and not str(span.text).strip_edges().is_empty():
			parts.append(str(span.text))
	return " ".join(parts)


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		return true
	print("[FAIL] region_look: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
