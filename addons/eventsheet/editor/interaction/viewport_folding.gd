@tool
class_name ViewportFolding
extends RefCounted
# The FOLDING subsystem of the event sheet's virtualized viewport, extracted from
# event_sheet_viewport.gd to keep that file maintainable. This layer owns every fold
# GESTURE and the persistence that makes region folds survive reopening the project:
#
#   - toggling one row's fold (the arrow / Left-Right keys / fold-by-uid),
#   - the Fold All / Unfold All sweeps (Command Palette; optionally groups too),
#   - resolving the innermost region CONTAINING a row (Ctrl+Shift+bracket keys),
#   - counting a row's currently-visible descendants (bubble ranges, fold targets),
#   - region fold persistence: per-project editor metadata keyed by the sheet's path
#     and each region's stable "label#occurrence" key - a fold survives sessions
#     without the .gd changing by a single byte (folds are editor state, not code).
#
# STATE STAYS ON THE VIEWPORT (the established helper contract): _fold_state,
# persisted_region_folds, _root_rows, and _flat_rows are read and written through
# the `_viewport.` back-reference, so multi-view fold isolation and the
# snapshot-duplicate undo funnel behave exactly as before the extraction. Bodies
# were moved VERBATIM - only member access was rewritten through `_viewport.`.
# The viewport keeps one-line delegates for every public/former name, so call
# sites (tests, palette commands, input handlers) needed no edits.

var _viewport: Control = null


func init(viewport: Control) -> void:
	_viewport = viewport


## Toggles one row's fold and remembers it for the session; region folds also
## persist across sessions (see persist_region_folds).
func toggle_row_fold(row_index: int) -> void:
	var row_data: EventRowData = _viewport._row_at(row_index)
	if row_data == null or row_data.children.is_empty():
		return
	row_data.folded = not row_data.folded
	_viewport._fold_state[row_data.row_uid] = row_data.folded
	_viewport._refresh_rows()
	if _viewport._row_builder._is_region_row(row_data):
		persist_region_folds()


## Fold-by-uid for callers that hold a row identity rather than a flat index
## (breakpoint jumps, tests). Returns whether the uid was found.
func toggle_row_fold_by_uid(row_uid: String) -> bool:
	if row_uid.is_empty():
		return false
	for index in range(_viewport._flat_rows.size()):
		var row_data: EventRowData = _viewport._row_at(index)
		if row_data != null and row_data.row_uid == row_uid:
			toggle_row_fold(index)
			return true
	return false


## Folds or unfolds every paired region in one step (Command Palette: Fold All
## Regions / Unfold All Regions). include_groups extends the sweep to event
## groups for the whole-sheet Fold Everything command.
func set_region_folds(folded: bool, include_groups: bool = false) -> void:
	_set_folds_in(_viewport._root_rows, folded, include_groups)
	_viewport._refresh_rows()
	persist_region_folds()


func _set_folds_in(rows: Array[EventRowData], folded: bool, include_groups: bool) -> void:
	for row_data: EventRowData in rows:
		if row_data.children.is_empty():
			continue
		var foldable: bool = _viewport._row_builder._is_region_row(row_data) \
			or (include_groups and row_data.source_resource is EventGroup)
		if foldable:
			row_data.folded = folded
			_viewport._fold_state[row_data.row_uid] = folded
		_set_folds_in(row_data.children, folded, include_groups)


## The flat index of the innermost paired region whose visible range contains
## flat_index (the opener itself counts as inside), or -1. Walks backwards, so
## the first covering opener found is the innermost.
func enclosing_region_flat_index(flat_index: int) -> int:
	if flat_index < 0 or flat_index >= _viewport._flat_rows.size():
		return -1
	for candidate_index in range(flat_index, -1, -1):
		var candidate: EventRowData = _viewport._flat_rows[candidate_index].get("row")
		if candidate == null or candidate.children.is_empty():
			continue
		if not _viewport._row_builder._is_region_row(candidate):
			continue
		if candidate_index + visible_descendant_count(candidate) >= flat_index:
			return candidate_index
	return -1


## How many of a row's descendants are currently visible in the flat list (its
## children run contiguously right after it in flatten order; a folded child
## contributes itself but hides its own subtree).
func visible_descendant_count(row_data: EventRowData) -> int:
	if row_data.folded:
		return 0
	var count: int = 0
	for child: EventRowData in row_data.children:
		count += 1
		count += visible_descendant_count(child)
	return count


# ── Region fold persistence (editor state, NEVER the sheet's bytes) ────────────────────────────
# Guarded to the editor: headless runs (tests) seed _viewport.persisted_region_folds directly.


func sheet_persist_key() -> String:
	if _viewport._sheet == null:
		return ""
	var sheet_path: String = str(_viewport._sheet.external_source_path)
	if sheet_path.is_empty():
		sheet_path = _viewport._sheet.resource_path
	return sheet_path


func load_persisted_region_folds() -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	var sheet_key: String = sheet_persist_key()
	if settings == null or sheet_key.is_empty():
		return
	var all_folds: Dictionary = settings.get_project_metadata("eventsheets", "region_folds", {})
	_viewport.persisted_region_folds = all_folds.get(sheet_key, {})


func persist_region_folds() -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	var sheet_key: String = sheet_persist_key()
	if settings == null or sheet_key.is_empty():
		return
	var all_folds: Dictionary = settings.get_project_metadata("eventsheets", "region_folds", {})
	var snapshot: Dictionary = region_fold_snapshot()
	if snapshot.is_empty():
		all_folds.erase(sheet_key)
	else:
		all_folds[sheet_key] = snapshot
	settings.set_project_metadata("eventsheets", "region_folds", all_folds)
	_viewport.persisted_region_folds = snapshot


## The regions currently folded, by stable key - only folded entries are stored
## (open is the default), so an all-open sheet stores nothing at all.
func region_fold_snapshot() -> Dictionary:
	var snapshot: Dictionary = {}
	_collect_region_folds(_viewport._root_rows, snapshot)
	return snapshot


func _collect_region_folds(rows: Array[EventRowData], snapshot: Dictionary) -> void:
	for row_data: EventRowData in rows:
		if row_data.folded and row_data.has_meta("region_fold_key"):
			snapshot[str(row_data.get_meta("region_fold_key"))] = true
		_collect_region_folds(row_data.children, snapshot)
