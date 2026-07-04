# Godot EventSheets - collapsible regions (v0.11 chapter 3, P1).
#
# #region / #endregion fence rows pair into foldable ranges IN THE VIEW LAYER ONLY:
# the sheet still stores flat fence rows, so emission and the byte round-trip are
# untouched by construction (pinned below anyway). The rows between a matched pair
# become the opener's visual children and fold through the existing machinery;
# unbalanced fences never pair and stay flat - the wart-not-error contract.
@tool
class_name RegionFoldingTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()

	# ── A balanced fence pair adopts the rows between as visual children ──
	var sheet: EventSheetResource = _sheet_with([
		_region("Combat", false),
		_comment("hurt rules"),
		_comment("heal rules"),
		_region("", true),
		_comment("outside the region")
	])
	var compiled_before: String = str(SheetCompiler.compile(sheet).get("output", ""))
	var rows: Array = viewport._build_rows_from_sheet(sheet)
	var openers: Array = _region_rows_in(rows)
	ok = _check("one region row at top level (the opener)", openers.size(), 1) and ok
	var opener: EventRowData = openers[0] if openers.size() == 1 else null
	ok = _check("opener adopts rows + closer as children", opener.children.size() if opener != null else -1, 3) and ok
	if opener != null and opener.children.size() == 3:
		ok = _check("the closing fence rides as the last child",
			opener.children[2].source_resource is CustomBlockRow
				and bool(((opener.children[2].source_resource as CustomBlockRow).fields as Dictionary).get("is_end", false)),
			true) and ok
		ok = _check("children indent one level under the opener", opener.children[0].indent, 1) and ok
	ok = _check("rows after the closer stay at top level",
		_last_comment_text_in(rows), "outside the region") and ok

	# ── Pairing is view-only: the model compiles byte-identically after building ──
	ok = _check("row building never touches the model bytes",
		str(SheetCompiler.compile(sheet).get("output", "")) == compiled_before, true) and ok

	# ── Folding: the seeded fold state hides the range in the flat list ──
	if opener != null:
		viewport._fold_state[opener.row_uid] = true
		var folded_rows: Array = viewport._build_rows_from_sheet(sheet)
		var folded_opener: EventRowData = _region_rows_in(folded_rows)[0]
		ok = _check("fold state seeds the rebuilt opener", folded_opener.folded, true) and ok
		var tail_span: SemanticSpan = folded_opener.spans[folded_opener.spans.size() - 1]
		# The count names CONTENT rows; the closing fence is plumbing, not content.
		ok = _check("a folded region names its hidden count", tail_span.text, "· 2 rows hidden") and ok
		viewport._fold_state.clear()

	# ── Unbalanced fences stay flat ──
	var lone_end: Array = viewport._build_rows_from_sheet(_sheet_with([_region("", true), _comment("after")]))
	ok = _check("a lone closer stays a flat row", _region_rows_in(lone_end).size(), 1) and ok
	ok = _check("a lone closer adopts no children", (_region_rows_in(lone_end)[0] as EventRowData).children.is_empty(), true) and ok
	var lone_open: Array = viewport._build_rows_from_sheet(_sheet_with([_region("Combat", false), _comment("collected then unwound")]))
	var lone_opener: EventRowData = _region_rows_in(lone_open)[0]
	ok = _check("an unclosed opener unwinds flat", lone_opener.children.is_empty(), true) and ok
	ok = _check("its would-be children stay at top level", _last_comment_text_in(lone_open), "collected then unwound") and ok

	# ── Styled regions: color + description ride an @ace_region marker, byte-gated ──
	var styled_block: CustomBlockRow = _region("Combat", false)
	styled_block.fields["color"] = "#ff8844"
	styled_block.fields["description"] = "Damage and healing"
	var styled_sheet: EventSheetResource = _sheet_with([styled_block, _comment("inside"), _region("", true)])
	var styled_source: String = str(SheetCompiler.compile(styled_sheet).get("output", ""))
	ok = _check("styled opener emits the marker + fence pair",
		styled_source.contains("## @ace_region(#ff8844, \"Damage and healing\")\n#region Combat"), true) and ok
	# Opened as a .gd (the external path), a styled fence lifts as ONE region row and
	# the untouched sheet reproduces the file byte-identically - the lossless covenant.
	var external_source: String = "extends Node\n\n## @ace_region(#ff8844, \"Damage and healing\")\n#region Combat\n# inside\n#endregion\n"
	var reimported: EventSheetResource = GDScriptImporter.new().import_external_source(external_source)
	reimported.external_source_path = "user://styled_region.gd"
	var relifted: Array = _region_blocks_in(reimported)
	ok = _check("styled fence lifts back as ONE region row", relifted.size(), 2) and ok
	if relifted.size() == 2:
		var opener_block: CustomBlockRow = relifted[0]
		ok = _check("color survives the round-trip", str(opener_block.fields.get("color", "")), "#ff8844") and ok
		ok = _check("description survives the round-trip", str(opener_block.fields.get("description", "")), "Damage and healing") and ok
	ok = _check("styled round-trip is byte-identical",
		str(SheetCompiler.compile(reimported, "user://styled_region.gd").get("output", "")) == external_source, true) and ok

	# A hand-written marker in a non-canonical shape fails the byte gate and stays raw.
	var near_miss: EventSheetResource = GDScriptImporter.new().import_external_source(
		"extends Node\n\n## @ace_region(\"desc first\", #ffffff)\n#region Odd\n#endregion\n")
	ok = _check("non-canonical markers never lift as styled regions",
		_region_blocks_with_color(near_miss).is_empty(), true) and ok

	# ── Groups and every block kind pair into regions like any other row ──
	var group := EventGroup.new()
	group.group_name = "Inner Group"
	var enum_row := EnumRow.new()
	var mixed_sheet: EventSheetResource = _sheet_with([
		_region("Everything", false),
		group,
		enum_row,
		_comment("plain comment"),
		_region("", true)
	])
	var mixed_rows: Array = viewport._build_rows_from_sheet(mixed_sheet)
	var mixed_opener: EventRowData = _region_rows_in(mixed_rows)[0]
	ok = _check("a group nests inside a region", mixed_opener.children.size(), 4) and ok
	if mixed_opener.children.size() == 4:
		ok = _check("the group row is the region's child", mixed_opener.children[0].source_resource is EventGroup, true) and ok
		ok = _check("an enum block is the region's child", mixed_opener.children[1].source_resource is EnumRow, true) and ok

	# ── Fold All / Unfold All sweep every paired region in one step ──
	var sweep_sheet: EventSheetResource = _sheet_with([
		_region("A", false), _comment("x"), _region("", true),
		_region("B", false), _comment("y"), _region("", true)
	])
	viewport.set_sheet(sweep_sheet)
	viewport.set_region_folds(true)
	var swept: Array = _region_rows_in(viewport._build_rows_from_sheet(sweep_sheet))
	ok = _check("Fold All folds every region", bool(swept[0].folded) and bool(swept[1].folded), true) and ok
	viewport.set_region_folds(false)
	swept = _region_rows_in(viewport._build_rows_from_sheet(sweep_sheet))
	ok = _check("Unfold All reopens every region", bool(swept[0].folded) or bool(swept[1].folded), false) and ok

	# ── The containing region resolves from any row inside its range ──
	viewport._fold_state.clear()
	viewport.set_sheet(sweep_sheet)
	ok = _check("a row inside region A resolves to A's opener", viewport._enclosing_region_flat_index(1), 0) and ok
	ok = _check("the opener itself counts as inside", viewport._enclosing_region_flat_index(0), 0) and ok
	ok = _check("a row inside region B resolves to B's opener", viewport._enclosing_region_flat_index(4), 3) and ok

	# ── Surround with Region: fences wrap the context row as one undo step ──
	var dock: EventSheetDock = EventSheetEditor.new() as EventSheetDock
	dock.set_undo_redo_manager(EventSheetEditorTest.FakeEditorUndoRedoManager.new())
	dock.setup(_sheet_with([_comment("alpha"), _comment("beta")]))
	var dock_sheet: EventSheetResource = dock.get_current_sheet()
	var alpha_row := EventRowData.new()
	alpha_row.source_resource = dock_sheet.events[0]
	dock._context_row = alpha_row
	dock._surround_selection_with_region()
	var wrapped_kinds: Array = []
	for entry: Resource in dock.get_current_sheet().events:
		if entry is CustomBlockRow:
			wrapped_kinds.append(bool((entry as CustomBlockRow).fields.get("is_end", false)))
		else:
			wrapped_kinds.append(str((entry as CommentRow).text))
	ok = _check("surround inserts opener + closer around the row",
		str(wrapped_kinds), str([false, "alpha", true, "beta"])) and ok

	dock.free()
	viewport.free()
	return ok


static func _region_blocks_in(sheet: EventSheetResource) -> Array:
	var output: Array = []
	for entry: Resource in sheet.events:
		if entry is CustomBlockRow and (entry as CustomBlockRow).kind_id == "region":
			output.append(entry)
	return output


static func _region_blocks_with_color(sheet: EventSheetResource) -> Array:
	var output: Array = []
	for entry: Resource in _region_blocks_in(sheet):
		if not str((entry as CustomBlockRow).fields.get("color", "")).is_empty():
			output.append(entry)
	return output


static func _sheet_with(entries: Array) -> EventSheetResource:
	var sheet := EventSheetResource.new()
	for entry: Resource in entries:
		sheet.events.append(entry)
	return sheet


static func _region(label: String, is_end: bool) -> CustomBlockRow:
	var block := CustomBlockRow.new()
	block.kind_id = "region"
	block.fields = {"label": label, "is_end": is_end}
	return block


static func _comment(text: String) -> CommentRow:
	var comment := CommentRow.new()
	comment.text = text
	return comment


static func _region_rows_in(rows: Array) -> Array:
	var output: Array = []
	for row_data: EventRowData in rows:
		if row_data.source_resource is CustomBlockRow and (row_data.source_resource as CustomBlockRow).kind_id == "region":
			output.append(row_data)
	return output


static func _last_comment_text_in(rows: Array) -> String:
	var last_text: String = ""
	for row_data: EventRowData in rows:
		if row_data.source_resource is CommentRow:
			last_text = (row_data.source_resource as CommentRow).text
	return last_text


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] region_folding_test: %s" % label)
		return true
	print("[FAIL] region_folding_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
