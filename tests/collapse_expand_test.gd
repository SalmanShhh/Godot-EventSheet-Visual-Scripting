# Godot EventSheets - Collapse All / Expand All / Expand To Level, and what a collapsed
# block says about itself.
#
# A long sheet is browsed by collapsing, so the sweeps have to be whole-sheet (every row
# that holds other rows, not only the paired regions), the depth has to be nameable
# ("expand to level 2"), the depth a file was left at has to survive reopening it, and a
# collapsed block has to keep saying what it holds. This pins all four:
#
#   1. Collapse All collapses a named row and Expand All reopens it.
#   2. expand_to_level(2) leaves the depth-1 row expanded and collapses the depth-2 row.
#   3. The remembered LEVEL round-trips: a sweep records it, and a fresh view seeded with it
#      applies it the first time the file is set. (A level, not a list of rows: a row uid
#      embeds the live instance id of the resource behind it, so it names nothing at all in
#      the next session, while a depth means the same thing every time.)
#   4. A collapsed row's summary reads its first rows back in the sheet's own words.
@tool
class_name CollapseExpandTest
extends RefCounted


static func run() -> bool:
	var ok: bool = true
	var viewport: EventSheetViewport = EventSheetViewport.new()

	# One outer group holding an inner group, which holds two comments: depth 1 and depth 2,
	# both with children, which is exactly what the level sweeps address.
	var inner: EventGroup = _group("Hurt Rules", [_comment("take damage"), _comment("die")])
	var outer: EventGroup = _group("Combat", [inner])
	var sheet: EventSheetResource = _sheet_with([outer])
	viewport.set_sheet(sheet)

	# ── 1. Collapse All / Expand All reach EVERY row that holds rows, not only regions ──
	viewport.collapse_all()
	var collapsed_rows: Array = viewport._build_rows_from_sheet(sheet)
	ok = _check("Collapse All collapses the outer group",
		bool(_group_row(collapsed_rows, "Combat").folded), true) and ok
	ok = _check("Collapse All reaches the nested group too",
		bool(_group_row(collapsed_rows, "Hurt Rules").folded), true) and ok
	viewport.expand_all()
	var expanded_rows: Array = viewport._build_rows_from_sheet(sheet)
	ok = _check("Expand All reopens the outer group",
		bool(_group_row(expanded_rows, "Combat").folded), false) and ok
	ok = _check("Expand All reopens the nested group",
		bool(_group_row(expanded_rows, "Hurt Rules").folded), false) and ok

	# ── 2. Expand To Level 2: depth 1 stays open, depth 2 closes ──
	viewport.expand_to_level(2)
	var levelled: Array = viewport._build_rows_from_sheet(sheet)
	ok = _check("level 2 leaves the depth-1 row expanded",
		bool(_group_row(levelled, "Combat").folded), false) and ok
	ok = _check("level 2 collapses the depth-2 row",
		bool(_group_row(levelled, "Hurt Rules").folded), true) and ok
	viewport.expand_to_level(1)
	var level_one: Array = viewport._build_rows_from_sheet(sheet)
	ok = _check("level 1 is Collapse All",
		bool(_group_row(level_one, "Combat").folded), true) and ok

	# ── 3. The remembered level round-trips through the view's persisted field ──
	viewport.expand_to_level(2)
	ok = _check("a level sweep records the level", viewport.persisted_collapse_level, 2) and ok
	viewport.expand_all()
	ok = _check("Expand All forgets the level (a file with none opens fully expanded)",
		viewport.persisted_collapse_level, 0) and ok
	viewport.collapse_all()
	ok = _check("Collapse All records level 1", viewport.persisted_collapse_level, 1) and ok

	var reopened: EventSheetViewport = EventSheetViewport.new()
	reopened.persisted_collapse_level = 2
	reopened.set_sheet(sheet)
	var reopened_rows: Array = reopened._build_rows_from_sheet(sheet)
	ok = _check("a reopened file applies its remembered level to depth 1",
		bool(_group_row(reopened_rows, "Combat").folded), false) and ok
	ok = _check("...and to depth 2",
		bool(_group_row(reopened_rows, "Hurt Rules").folded), true) and ok

	# ── 4. A collapsed block still says what it holds ──
	var summary_viewport: EventSheetViewport = EventSheetViewport.new()
	var summary_group: EventGroup = _group("Jump", [
		_comment("host does not exist"),
		_comment("set coyote timer to 0"),
		_comment("play the jump sound"),
		_comment("one row too many")
	])
	var summary_sheet: EventSheetResource = _sheet_with([summary_group])
	summary_viewport.set_sheet(summary_sheet)
	var open_row: EventRowData = _group_row(summary_viewport._build_rows_from_sheet(summary_sheet), "Jump")
	ok = _check("an EXPANDED block wears no summary (its rows are right there)",
		summary_viewport.collapsed_row_summary(open_row), "") and ok
	summary_viewport.collapse_all()
	var summary_row: EventRowData = _group_row(summary_viewport._build_rows_from_sheet(summary_sheet), "Jump")
	ok = _check("a collapsed block names its first rows and trails off",
		summary_viewport.collapsed_row_summary(summary_row),
		"host does not exist - set coyote timer to 0 - play the jump sound - …") and ok

	reopened.free()
	summary_viewport.free()
	viewport.free()
	return ok


static func _sheet_with(entries: Array) -> EventSheetResource:
	var sheet := EventSheetResource.new()
	for entry: Resource in entries:
		sheet.events.append(entry)
	return sheet


static func _group(group_name: String, entries: Array) -> EventGroup:
	var group := EventGroup.new()
	group.group_name = group_name
	for entry: Resource in entries:
		group.events.append(entry)
	return group


static func _comment(text: String) -> CommentRow:
	var comment := CommentRow.new()
	comment.text = text
	return comment


## The row built for the group with `group_name`, searched depth-first through the tree the
## viewport built (a collapsed parent still HAS its children - they are only hidden from the
## flat list, which is exactly why the summary can name them).
static func _group_row(rows: Array, group_name: String) -> EventRowData:
	for row_data: EventRowData in rows:
		if row_data.source_resource is EventGroup \
				and str((row_data.source_resource as EventGroup).group_name) == group_name:
			return row_data
		var found: EventRowData = _group_row(row_data.children, group_name)
		if found != null:
			return found
	return null


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] collapse_expand_test: %s" % label)
		return true
	print("[FAIL] collapse_expand_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
