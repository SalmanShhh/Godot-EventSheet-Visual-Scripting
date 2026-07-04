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
	var compiled_before: String = str(SheetCompiler.compile(sheet).get("source", ""))
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
		str(SheetCompiler.compile(sheet).get("source", "")) == compiled_before, true) and ok

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

	viewport.free()
	return ok


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
