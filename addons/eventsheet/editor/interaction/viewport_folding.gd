@tool
class_name ViewportFolding
extends RefCounted
# The FOLDING subsystem of the event sheet's virtualized viewport, extracted from
# event_sheet_viewport.gd to keep that file maintainable. This layer owns every fold
# GESTURE and the persistence that makes region folds survive reopening the project:
#
#   - toggling one row's fold (the arrow / Left-Right keys / fold-by-uid),
#   - the Fold All / Unfold All sweeps (Command Palette; optionally groups too),
#   - the whole-sheet Collapse All / Expand All / Expand To Level sweeps and the one-line
#     summary a collapsed row wears (the sheet is browsed by collapsing, so a collapsed
#     block must still say what it holds),
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
	_set_folds_in(_viewport._root_rows, SWEEP_BOTH if include_groups else SWEEP_REGIONS, folded)
	_viewport._refresh_rows()
	persist_region_folds()


## Folds or unfolds every event GROUP in one step, leaving regions and event blocks alone.
func set_group_folds(folded: bool) -> void:
	_set_folds_in(_viewport._root_rows, SWEEP_GROUPS, folded)
	_viewport._refresh_rows()
	persist_region_folds()


## Open all / Close all: true while ANY group on the sheet is open, which is what makes the one
## gesture a toggle instead of two commands.
func any_group_open() -> bool:
	return _any_open_in(_viewport._root_rows, SWEEP_GROUPS)


## The same question for regions: true while any paired fence still shows its body, which is
## what makes Fold All / Unfold All one toggling item instead of two commands.
func any_region_open() -> bool:
	return _any_open_in(_viewport._root_rows, SWEEP_REGIONS)


## Which containers a sweep is about. Every sweep here is about ONE kind of container - the event
## groups, the paired regions, or (the whole-sheet Fold Everything) both - so the walks below take
## the kind rather than existing once per kind.
const SWEEP_GROUPS := "groups"
const SWEEP_REGIONS := "regions"
const SWEEP_BOTH := "both"


## True when a row is a container of the kind this sweep is about. A row holding nothing is never
## one: folding it would mean nothing.
func _sweeps(row_data: EventRowData, sweep: String) -> bool:
	if row_data.children.is_empty():
		return false
	if sweep != SWEEP_GROUPS and _viewport._row_builder._is_region_row(row_data):
		return true
	return sweep != SWEEP_REGIONS and row_data.source_resource is EventGroup


func _any_open_in(rows: Array[EventRowData], sweep: String) -> bool:
	for row_data: EventRowData in rows:
		if _sweeps(row_data, sweep) and not row_data.folded:
			return true
		if _any_open_in(row_data.children, sweep):
			return true
	return false


func _set_folds_in(rows: Array[EventRowData], sweep: String, folded: bool) -> void:
	for row_data: EventRowData in rows:
		if _sweeps(row_data, sweep):
			row_data.folded = folded
			_viewport._fold_state[row_data.row_uid] = folded
		_set_folds_in(row_data.children, sweep, folded)


## Collapses or expands EVERY row that holds other rows - the whole-sheet Collapse All /
## Expand All (Ctrl+Shift+[ / Ctrl+Shift+], View menu, Command Palette). Unlike
## set_region_folds this asks nothing about the KIND of row: an event block, a group, a
## region and a published verb all collapse, because "collapse the sheet" means the sheet.
## The level is remembered per file (collapse all is level 1; expand all forgets it).
func set_all_folds(folded: bool) -> void:
	_apply_level_to(_viewport._root_rows, 1 if folded else 0, 1)
	_viewport._refresh_rows()
	persist_region_folds()
	persist_collapse_level(1 if folded else 0)


## View > Expand To Level N: every row shallower than `level` is expanded and everything at
## `level` or deeper is collapsed (root rows are level 1). Level 1 is therefore exactly
## Collapse All, and a level deeper than the sheet expands all of it.
func expand_to_level(level: int) -> void:
	var clamped: int = maxi(level, 1)
	_apply_level_to(_viewport._root_rows, clamped, 1)
	_viewport._refresh_rows()
	persist_region_folds()
	persist_collapse_level(clamped)


## Re-applies a remembered level when a file is reopened. Same walk, but it neither
## persists (nothing changed to remember) nor clamps a 0 up to 1 - level 0 means "this file
## has no remembered collapse", and re-collapsing it would be the opposite of that.
func apply_collapse_level(level: int) -> void:
	if level <= 0:
		return
	_apply_level_to(_viewport._root_rows, level, 1)
	_viewport._refresh_rows()


## `level` 0 expands everything; otherwise a row is collapsed exactly when its own depth
## reaches `level`. Rows without children are left alone (folding one means nothing).
func _apply_level_to(rows: Array[EventRowData], level: int, depth: int) -> void:
	for row_data: EventRowData in rows:
		if not row_data.children.is_empty():
			var folded: bool = level > 0 and depth >= level
			row_data.folded = folded
			_viewport._fold_state[row_data.row_uid] = folded
		_apply_level_to(row_data.children, level, depth + 1)


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


# ── Collapse-level persistence (a sibling of the region folds, same metadata section) ──────────
# What is remembered is the LEVEL, not the list of collapsed rows, and that is deliberate:
# a row's uid embeds the live instance id of the resource behind it, so it names nothing at
# all in the next session, while "this file reads to level 2" means the same thing every
# time the file is opened. Only a level put in force by Collapse All / Expand All / Expand
# To Level is stored; absent (or 0) means the file opens fully expanded, exactly as before.


func load_persisted_collapse_level() -> void:
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	var sheet_key: String = sheet_persist_key()
	if settings == null or sheet_key.is_empty():
		return
	var all_levels: Dictionary = settings.get_project_metadata("eventsheets", "collapse_state", {})
	_viewport.persisted_collapse_level = int(all_levels.get(sheet_key, 0))


func persist_collapse_level(level: int) -> void:
	# The viewport field is written FIRST, outside the editor guard: it is plain view state,
	# and a headless run (the suite) must still be able to read back what it just asked for.
	_viewport.persisted_collapse_level = maxi(level, 0)
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	var sheet_key: String = sheet_persist_key()
	if settings == null or sheet_key.is_empty():
		return
	var all_levels: Dictionary = settings.get_project_metadata("eventsheets", "collapse_state", {})
	if level <= 0:
		all_levels.erase(sheet_key)
	else:
		all_levels[sheet_key] = level
	settings.set_project_metadata("eventsheets", "collapse_state", all_levels)


# ── The one-line summary a collapsed row wears ─────────────────────────────────────────────────
# An event sheet is browsed by collapsing, so a collapsed block that says nothing about what
# it holds has hidden the very thing you collapsed it to find. Each collapsed row therefore
# reads its first rows back in the sheet's own words, muted, after its own text.

## How many of a collapsed row's rows the summary names before it trails off.
const SUMMARY_ROW_LIMIT := 3


## The summary line for a collapsed row, or "" for a row that is not collapsed (or holds
## nothing). Cached on the row itself: rows are rebuilt from scratch whenever the sheet
## changes, so the cache cannot go stale - it dies with the row that carries it.
func collapsed_summary(row_data: EventRowData) -> String:
	if row_data == null or not row_data.folded or row_data.children.is_empty():
		return ""
	if row_data.has_meta("collapse_summary"):
		return str(row_data.get_meta("collapse_summary"))
	var pieces: PackedStringArray = PackedStringArray()
	var more: bool = false
	for child: EventRowData in row_data.children:
		var piece: String = summary_piece(child)
		if piece.is_empty():
			continue
		if pieces.size() >= SUMMARY_ROW_LIMIT:
			more = true
			break
		pieces.append(piece)
	var summary: String = " - ".join(pieces)
	if more and not summary.is_empty():
		summary += " - …"
	row_data.set_meta("collapse_summary", summary)
	return summary


## One held row read back as one phrase: "condition -> action" where the row has both lanes,
## the side it has where it has only one, and its own plain text otherwise (a comment, a
## group bar, a block of code). The "+ Add event" affordance rows are furniture, not
## content, and are skipped. Returns "" for a row with nothing to say.
func summary_piece(row_data: EventRowData) -> String:
	if row_data == null or row_data.row_uid.begins_with("add_event_footer"):
		return ""
	if row_data.row_type == EventRowData.RowType.EVENT and row_data.spans.is_empty():
		_viewport._ensure_event_spans(row_data)
	var conditions: PackedStringArray = PackedStringArray()
	var actions: PackedStringArray = PackedStringArray()
	var plain: PackedStringArray = PackedStringArray()
	for span: SemanticSpan in row_data.spans:
		var text: String = span.text.strip_edges()
		if text.is_empty():
			continue
		var lane: String = ""
		if span.metadata is Dictionary:
			lane = str((span.metadata as Dictionary).get("lane", ""))
		if lane == "condition":
			conditions.append(text)
		elif lane == "action":
			actions.append(text)
		else:
			plain.append(text)
	if not conditions.is_empty() and not actions.is_empty():
		return "%s -> %s" % [" - ".join(conditions), " - ".join(actions)]
	if not conditions.is_empty():
		return " - ".join(conditions)
	if not actions.is_empty():
		return " - ".join(actions)
	return " ".join(plain)
