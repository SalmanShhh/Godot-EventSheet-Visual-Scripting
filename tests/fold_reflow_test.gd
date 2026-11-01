# Folding a row used to rebuild every row of the sheet from the ground up, although a fold changes
# what the rows SHOW and not what they ARE. A fold now flattens the rows it already has (re-dressing
# the words of the rows whose fold flipped), and falls back to the full rebuild for a kind whose
# fold state it cannot re-dress. This pins the contract that makes that safe: whatever a fold does
# by reflow, a full rebuild of the same fold state does too.
#   1. Over real sheets, toggling rows one after another by reflow leaves the flat rows (identity,
#      indent, kind, numbers, height, words, selection) exactly as a full rebuild leaves them.
#   2. The reflow path builds no rows (the build counter stands still) and is actually taken for
#      groups and events, not only for the trivial case.
#   3. A row of a kind that cannot be re-dressed sends the change through the full rebuild.
#   4. A sweep (fold all groups, collapse all) lands on the same rows either way.
@tool
class_name FoldReflowTest
extends RefCounted


const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "fold_reflow_test"
const SHEETS: Array[String] = [
	"res://demo/showcase/boomer_level/boomer_level.gd",
	"res://demo/showcase/combo_fighter/combo_fighter.gd",
	"res://demo/showcase/menu_starter/menu_starter.gd",
	"res://demo/showcase/quest_fsm/quest_fsm.gd",
	"res://demo/showcase/carousel/showcase_carousel.gd",
]
## A region around two functions, one of them folded by default: the opener names what it holds.
const REGION_SOURCE := """extends Node


#region Combat
# hurt rules
func hurt(amount: int) -> void:
	print(amount)


# heal rules
func heal(amount: int) -> void:
	print(amount)
#endregion


func _ready() -> void:
	hurt(1)
"""


static func run() -> bool:
	var ok: bool = true
	var reflowed_groups: int = 0
	var reflowed_events: int = 0
	var reflowed_regions: int = 0
	var full_rebuilds: int = 0
	var rows_checked: int = 0
	var sources: Array = []
	for path: String in SHEETS:
		if FileAccess.file_exists(path):
			sources.append([path, FileAccess.get_file_as_string(path)])
	sources.append(["res://tests/fold_reflow_region_source.gd", REGION_SOURCE])
	sources.append(["authored groups", null])
	for source_entry: Array in sources:
		var path: String = str(source_entry[0])
		var sheet: EventSheetResource = _authored_groups() if source_entry[1] == null else SUPPORT.reopen(str(source_entry[1]), true, path)
		var reflow_view: EventSheetViewport = _view_of(sheet)
		var full_view: EventSheetViewport = _view_of(sheet)
		# A selection the folds must keep on the same rows.
		if reflow_view.get_total_row_count() > 2:
			reflow_view._select_row(2)
			full_view._select_row(2)
		var toggled: Array[String] = []
		var mismatch: String = ""
		var targets: Array[String] = _foldable_uids(reflow_view)
		for step: int in range(targets.size() * 2):
			var target_uid: String = targets[step % targets.size()]
			var reflow_row: EventRowData = _row_by_uid(reflow_view, target_uid)
			if reflow_row == null:
				continue
			toggled.append(target_uid)
			var builds_before: int = reflow_view.row_builds()
			var kind_is_group: bool = reflow_row.source_resource is EventGroup
			var kind_is_event: bool = reflow_row.source_resource is EventRow or reflow_row.source_resource is EventFunction
			var kind_is_region: bool = reflow_row.row_type == EventRowData.RowType.REGION
			reflow_view._folding.toggle_row_fold_by_uid(target_uid)
			var reflowed: bool = reflow_view.row_builds() == builds_before
			if reflowed and kind_is_group:
				reflowed_groups += 1
			elif reflowed and kind_is_region:
				reflowed_regions += 1
			elif reflowed and kind_is_event:
				reflowed_events += 1
			elif not reflowed:
				full_rebuilds += 1
				print("fold_reflow_test: full rebuild for %s row_type=%d source=%s" % [path.get_file(), reflow_row.row_type, str(reflow_row.source_resource.get_script().get_global_name()) if reflow_row.source_resource != null else "none"])
			_full_rebuild_toggle(full_view, target_uid)
			var left: PackedStringArray = _shape(reflow_view)
			var right: PackedStringArray = _shape(full_view)
			rows_checked += left.size()
			if left != right:
				mismatch = _first_difference(left, right)
				break
		ok = SUPPORT.check(TEST_NAME, "%s: %d toggles leave the rows as a full rebuild does" % [path.get_file(), toggled.size()], mismatch, "") and ok

		# A sweep lands on the same rows either way.
		reflow_view._folding.set_group_folds(true)
		_full_rebuild_sweep(full_view, true)
		ok = SUPPORT.check(TEST_NAME, "%s: folding every group matches a full rebuild" % path.get_file(), _shape(reflow_view) == _shape(full_view), true) and ok
		reflow_view._folding.set_group_folds(false)
		_full_rebuild_sweep(full_view, false)
		ok = SUPPORT.check(TEST_NAME, "%s: opening every group matches a full rebuild" % path.get_file(), _shape(reflow_view) == _shape(full_view), true) and ok
		reflow_view.free()
		full_view.free()

	ok = SUPPORT.check(TEST_NAME, "groups were folded by reflow", reflowed_groups > 0, true) and ok
	ok = SUPPORT.check(TEST_NAME, "regions were folded by reflow", reflowed_regions > 0, true) and ok
	ok = SUPPORT.check(TEST_NAME, "events were folded by reflow", reflowed_events > 0, true) and ok
	ok = SUPPORT.check(TEST_NAME, "rows were compared", rows_checked > 0, true) and ok
	print("fold_reflow_test: reflow groups=%d regions=%d events=%d full=%d rows=%d" % [reflowed_groups, reflowed_regions, reflowed_events, full_rebuilds, rows_checked])
	return ok


## An authored sheet of groups: one with a description holding comments and a nested group, and a second
## switchable one, so a folded head has counts to name.
static func _authored_groups() -> EventSheetResource:
	var sheet := EventSheetResource.new()
	var inner := EventGroup.new()
	inner.group_name = "Inner"
	inner.events.append(_comment("deep note"))
	var outer := EventGroup.new()
	outer.group_name = "Outer"
	outer.description = "holds things"
	outer.events.append(_comment("first note"))
	outer.events.append(inner)
	outer.events.append(_comment("last note"))
	var other := EventGroup.new()
	other.group_name = "Other"
	other.runtime_toggleable = true
	other.events.append(_comment("other note"))
	sheet.events.append(outer)
	sheet.events.append(other)
	return sheet


static func _comment(text: String) -> CommentRow:
	var comment := CommentRow.new()
	comment.text = text
	return comment


static func _view_of(sheet: EventSheetResource) -> EventSheetViewport:
	var view := EventSheetViewport.new()
	view.set_ace_registry(EventSheetACERegistry.new())
	view.size = Vector2(1200.0, 900.0)
	view.set_sheet(sheet)
	return view


## The first row (in flat order) that holds children, cycling so a sheet's first few foldable rows are
## folded and then unfolded again.
## The first two foldable rows of each kind of row, so groups and regions are folded as well as events.
static func _foldable_uids(view: EventSheetViewport) -> Array[String]:
	var per_kind: Dictionary = {}
	var foldable: Array[String] = []
	for index: int in range(view.get_total_row_count()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null or row_data.children.is_empty():
			continue
		var kind: String = "%d:%s" % [row_data.row_type, str(row_data.source_resource.get_script().get_global_name()) if row_data.source_resource != null else ""]
		if int(per_kind.get(kind, 0)) >= 2:
			continue
		per_kind[kind] = int(per_kind.get(kind, 0)) + 1
		foldable.append(row_data.row_uid)
	return foldable


static func _row_by_uid(view: EventSheetViewport, uid: String) -> EventRowData:
	for index: int in range(view.get_total_row_count()):
		var row_data: EventRowData = view._row_at(index)
		if row_data != null and row_data.row_uid == uid:
			return row_data
	return null


## What a fold did before it learned to reflow: flip the flag, remember it, rebuild everything.
static func _full_rebuild_toggle(view: EventSheetViewport, uid: String) -> void:
	var row_data: EventRowData = _row_by_uid(view, uid)
	if row_data == null:
		return
	row_data.folded = not row_data.folded
	view._fold_state[uid] = row_data.folded
	view._refresh_rows()


static func _full_rebuild_sweep(view: EventSheetViewport, folded: bool) -> void:
	view._folding._set_folds_in(view._root_rows, ViewportFolding.SWEEP_GROUPS, folded, [] as Array[EventRowData])
	view._refresh_rows()


## One line per flat row: everything a fold could get wrong about it.
static func _shape(view: EventSheetViewport) -> PackedStringArray:
	var lines := PackedStringArray()
	for index: int in range(view.get_total_row_count()):
		var row_data: EventRowData = view._row_at(index)
		if row_data == null:
			lines.append("null")
			continue
		var words := PackedStringArray()
		for span: SemanticSpan in row_data.spans:
			words.append(span.text)
		lines.append("%s|%d|%d|%s|%d|%d|%d|%s|%.2f|%s|%s" % [
			row_data.row_uid, row_data.indent, row_data.row_type, str(row_data.folded), row_data.line_number,
			row_data.event_number, row_data.branch_number, str(row_data.selected),
			view._row_metrics_helper.row_height(index), "/".join(words), str(view._selected_row_index)])
	return lines


static func _first_difference(left: PackedStringArray, right: PackedStringArray) -> String:
	if left.size() != right.size():
		return "row counts differ: %d vs %d" % [left.size(), right.size()]
	for index: int in range(left.size()):
		if left[index] != right[index]:
			return "row %d:\n    reflow: %s\n    full:   %s" % [index, left[index], right[index]]
	return ""
