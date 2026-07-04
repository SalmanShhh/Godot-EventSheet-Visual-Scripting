@tool
class_name EventSheetClipboard
extends RefCounted
# The CLIPBOARD / COPY-PASTE cluster. This helper owns:
#   • Copy - an ACE (condition/action/trigger) or the selected row(s). Row copies are written in two
#     forms at once: the internal `_clipboard` (rich, same-session pastes) and a portable text snippet
#     on the SYSTEM clipboard (shareable across projects, editor instances, forum/Discord posts),
#   • Paste - priority order: portable snippets → raw GDScript copied from anywhere (auto-converted to
#     events/rows through the .gd-import pipeline) → the internal clipboard for same-session rich pastes,
#   • the two shareable/GDScript paste paths (`_paste_snippet_text`, `_paste_gdscript_text`) and the
#     "Add GDScript action" context action,
#   • the internal-clipboard STATE `_clipboard` itself (no external reader - confirmed by grep before
#     the move; only this helper reads/writes it).
#
# Extracted from event_sheet_dock.gd to keep that file maintainable.
#
# WHAT STAYS ON THE DOCK (reached here through `_dock`):
#   • the mutation funnel (`_perform_undoable_sheet_edit` / `_mark_dirty` / `_refresh_after_edit` /
#     `_set_status`), plus `_current_sheet` / `_active_view` / `_context_row`,
#   • `_ensure_sheet_for_editing` / `_ensure_selected_event` - the pre-edit guards that sit INTERLEAVED
#     right after the copy/paste block on the dock (they stay put),
#   • `_insert_row_below_selection` (a dock delegate into ace_apply), `_assign_fresh_event_uids`,
#     `_resource_contains_descendant`, `_get_selected_rows_from_context`.
# Globals (EventSheetSnippet, GDScriptImporter, DisplayServer) are unchanged.
#
# The dock keeps thin one-line delegates (original names + signatures + returns) for every method
# reached from outside this helper - menu_bar (`_dock._on_copy_requested` / `_dock._on_paste_requested`),
# author_actions (`_dock._top_level_selected_resources` / `_dock._paste_snippet_text`),
# event_sheet_editor_test + snippet_share_test (copy/paste), gdscript_paste_test
# (`editor._paste_gdscript_text`) and inflow_gdscript_test (`editor._add_gdscript_action_to_context_row`)
# - so those callers resolve unchanged. `_looks_like_gdscript` is internal-only (called only from
# `_paste_gdscript_text`, both here) so it needs no delegate; it stays STATIC.
#
# CLOSURE NOTES - 4 undoable lambdas:
#   • `_on_paste_requested`'s lambda captures the LOCALS `clip_type` / `payload` / `selected_resource`
#     / `result` and calls `_dock._insert_row_below_selection`,
#   • `_paste_snippet_text`'s lambda captures `required_variables` / `counters` / `rows` and reaches
#     `_dock._current_sheet.variables` / `_dock._active_view` / `_dock._assign_fresh_event_uids` /
#     `_dock._insert_row_below_selection`. The `counters` / `result` mutate-by-Dictionary idiom (GDScript
#     lambdas capture by value, so a Dictionary is how the closure writes a running total back out) is
#     preserved EXACTLY - not reindented or renamed,
#   • `_add_gdscript_action_to_context_row`'s lambda captures the LOCAL `target_event` (clean),
#   • `_paste_gdscript_text`'s lambda captures `rows` / `anchor` and calls `_dock._insert_row_below_selection`.
#   Inside each lambda: dock state/STAY-methods → `_dock.`; moved siblings
#   (`_top_level_selected_resources`, `_looks_like_gdscript`) stay bare.

var _dock: Control = null


func init(dock: Control) -> void:
	_dock = dock

# The internal clipboard: rich, same-session copies of a row/condition/action/trigger. No external
# reader - this helper is the only owner (grep-confirmed before the move).
var _clipboard: Dictionary = {}


func _on_copy_requested() -> void:
	var context: Dictionary = _dock._active_view().get_selected_context()
	var selected_resource: Resource = context.get("source_resource", null)
	if selected_resource == null:
		_dock._set_status("Nothing selected to copy.", true)
		return
	var metadata: Dictionary = context.get("span_metadata", {})
	if selected_resource is EventRow and not metadata.is_empty():
		var event_row: EventRow = selected_resource as EventRow
		var kind: String = str(metadata.get("kind", ""))
		var ace_index: int = int(metadata.get("ace_index", -1))
		if kind == "condition" and ace_index >= 0 and ace_index < event_row.conditions.size():
			_clipboard = {"type": "condition", "payload": event_row.conditions[ace_index].duplicate(true)}
			_dock._set_status("Copied condition.")
			return
		if kind == "action" and ace_index >= 0 and ace_index < event_row.actions.size() and event_row.actions[ace_index] is ACEAction:
			_clipboard = {"type": "action", "payload": (event_row.actions[ace_index] as ACEAction).duplicate(true)}
			_dock._set_status("Copied action.")
			return
		if kind == "trigger" and event_row.trigger != null:
			_clipboard = {"type": "trigger", "payload": event_row.trigger.duplicate(true)}
			_dock._set_status("Copied trigger.")
			return
	# Row copies are written in two forms: the internal clipboard (rich, same-session
	# pastes) and a portable text snippet on the SYSTEM clipboard, so rows can be shared
	# across projects, editor instances, and forum/Discord posts (see EventSheetSnippet).
	var top_level: Array = _top_level_selected_resources()
	if top_level.is_empty():
		top_level = [selected_resource]
	DisplayServer.clipboard_set(EventSheetSnippet.serialize_rows(top_level, _dock._current_sheet))
	_clipboard = {"type": "row", "payload": selected_resource.duplicate(true)}
	_dock._set_status("Copied %d row(s) - shareable snippet placed on the clipboard." % top_level.size())


## Top-most selected row resources: children of a selected ancestor are skipped because
## they already travel inside their parent's serialized form.
func _top_level_selected_resources() -> Array:
	var resources: Array = []
	for row_data in _dock._get_selected_rows_from_context():
		if row_data == null or row_data.source_resource == null:
			continue
		if not resources.has(row_data.source_resource):
			resources.append(row_data.source_resource)
	var top_level: Array = []
	for resource in resources:
		var has_selected_ancestor: bool = false
		for other in resources:
			if other != resource and _dock._resource_contains_descendant(other, resource):
				has_selected_ancestor = true
				break
		if not has_selected_ancestor:
			top_level.append(resource)
	return top_level


func _on_paste_requested() -> void:
	# Paste priority: portable snippets (in-app copies refresh them too) → raw GDScript
	# copied from anywhere (auto-converted to events/rows) → the internal clipboard for
	# same-session rich pastes.
	if _paste_snippet_text(DisplayServer.clipboard_get()):
		return
	if _paste_gdscript_text(DisplayServer.clipboard_get()):
		return
	if _clipboard.is_empty():
		_dock._set_status("Clipboard is empty.", true)
		return
	if not _dock._ensure_sheet_for_editing():
		return
	var clip_type: String = str(_clipboard.get("type", ""))
	var payload: Variant = _clipboard.get("payload", null)
	var context: Dictionary = _dock._active_view().get_selected_context()
	var selected_resource: Resource = context.get("source_resource", null)
	var result := {"label": ""}
	var changed: bool = _dock._perform_undoable_sheet_edit("Paste", func() -> bool:
		match clip_type:
			"row":
				if payload is Resource:
					_dock._insert_row_below_selection((payload as Resource).duplicate(true))
					result["label"] = "Pasted row."
					return true
			"condition":
				if selected_resource is EventRow and payload is ACECondition:
					(selected_resource as EventRow).conditions.append((payload as ACECondition).duplicate(true))
					result["label"] = "Pasted condition."
					return true
			"action":
				if selected_resource is EventRow and payload is ACEAction:
					(selected_resource as EventRow).actions.append((payload as ACEAction).duplicate(true))
					result["label"] = "Pasted action."
					return true
			"trigger":
				if selected_resource is EventRow and payload is ACECondition:
					(selected_resource as EventRow).trigger = (payload as ACECondition).duplicate(true)
					result["label"] = "Pasted trigger."
					return true
		return false
	)
	if not changed:
		_dock._set_status("Paste target is not valid for clipboard payload.", true)
	else:
		_dock._mark_dirty(str(result.get("label", "Pasted.")))


## Pastes a shareable snippet from text (see EventSheetSnippet). Returns false when the
## text is not a snippet so the caller falls back to the internal clipboard. Pasted events
## get fresh UIDs; sheet variables the snippet references are created when missing (never
## overwritten), so the pasted rows compile immediately.
func _paste_snippet_text(text: String) -> bool:
	if not EventSheetSnippet.is_snippet_text(text):
		return false
	if not _dock._ensure_sheet_for_editing():
		return true
	var snippet: Dictionary = EventSheetSnippet.deserialize(text)
	var rows: Array = snippet.get("rows", [])
	if rows.is_empty():
		_dock._set_status("Clipboard snippet is empty or invalid.", true)
		return true
	# Dictionary so the undoable lambda can mutate it (GDScript lambdas capture by value).
	var counters: Dictionary = {"variables_created": 0}
	var required_variables: Dictionary = snippet.get("required_variables", {})
	var changed: bool = _dock._perform_undoable_sheet_edit("Paste Snippet", func() -> bool:
		for variable_name in required_variables.keys():
			if not _dock._current_sheet.variables.has(variable_name):
				_dock._current_sheet.variables[variable_name] = required_variables[variable_name]
				counters["variables_created"] = int(counters["variables_created"]) + 1
		var anchor: Resource = _dock._active_view().get_selected_context().get("source_resource", null)
		for row in rows:
			if row is EventRow:
				_dock._assign_fresh_event_uids(row as EventRow)
			_dock._insert_row_below_selection(row, anchor)
			anchor = row  # keeps pasted rows in their original order, each after the last
		return true
	)
	if changed:
		var provider_names: PackedStringArray = PackedStringArray()
		for provider in snippet.get("providers", []):
			provider_names.append(str(provider))
		var provider_note: String = "" if provider_names.is_empty() else " Uses providers: %s." % ", ".join(provider_names)
		_dock._mark_dirty("Pasted snippet: %d row(s), %d variable(s) created.%s" % [rows.size(), int(counters["variables_created"]), provider_note])
	return true


## Appends an in-flow GDScript block to the right-clicked event's actions (event-sheet-style inline
## scripting: statements emitted inside the event body).
func _add_gdscript_action_to_context_row() -> void:
	_add_gdscript_action_to_event(_dock._context_row.source_resource if _dock._context_row != null else null)


## C3-style "drop to code here": appends an in-flow GDScript block to the event's actions and opens
## the code editor on it straight away (C3 opens its script block for editing on add). The block runs
## right after the event's conditions pass, with the sheet's variables + host in scope - a deliberate,
## visually-distinct escape hatch (it renders as a merged "GDScript" code cell), not un-lifted residue.
## `target` may be an EventRow directly (context menu) or null (toolbar/menu → uses the selected event).
func _add_gdscript_action_to_event(target: Variant) -> void:
	var target_event: EventRow = target if target is EventRow else _dock._selected_event_for_action()
	if target_event == null:
		_dock._set_status("Select an event first - a GDScript action runs inside it.", true)
		return
	var target_uid: String = target_event.event_uid
	var changed: bool = _dock._perform_undoable_sheet_edit("Add GDScript Action", func() -> bool:
		var inline_raw: RawCodeRow = RawCodeRow.new()
		inline_raw.code = "# GDScript - runs after this event's conditions pass"
		target_event.actions.append(inline_raw)
		return true
	)
	if not changed:
		return
	_dock._mark_dirty("Added GDScript action.")
	# The undo funnel replaced the sheet on commit; find the block we just appended on the LIVE event
	# (by its stable uid) and open the editor on it - like C3 opening the script block immediately.
	var added: RawCodeRow = null
	for live_event: Variant in _dock._current_sheet.events:
		added = _find_appended_raw(live_event, target_uid)
		if added != null:
			break
	# Open the editor on it immediately (C3-style). Headless tests can't pop a window, so guard -
	# the block was still appended, which is what those tests assert.
	if added != null and _dock.is_inside_tree():
		_dock._on_viewport_raw_code_edit_requested(added, true)


## The last in-flow RawCodeRow action on the event whose stable uid matches - the block just appended
## (the append put it last). Recurses sub-events + groups so a nested event's block is found too.
static func _find_appended_raw(row: Variant, event_uid: String) -> RawCodeRow:
	if row is EventGroup:
		var group: EventGroup = row as EventGroup
		for child: Variant in (group.events if not group.events.is_empty() else group.rows):
			var found: RawCodeRow = _find_appended_raw(child, event_uid)
			if found != null:
				return found
		return null
	if not (row is EventRow):
		return null
	var event_row: EventRow = row as EventRow
	if event_row.event_uid == event_uid:
		for index: int in range(event_row.actions.size() - 1, -1, -1):
			if event_row.actions[index] is RawCodeRow:
				return event_row.actions[index]
	for sub: Variant in event_row.sub_events:
		var sub_found: RawCodeRow = _find_appended_raw(sub, event_uid)
		if sub_found != null:
			return sub_found
	return null


## Returns true when the clipboard text reads like GDScript (conservative: a paste that is
## not code must fall through to the internal clipboard untouched).
static func _looks_like_gdscript(text: String) -> bool:
	var code_line: RegEx = RegEx.new()
	if code_line.compile("(?m)^(func |var |@export|@onready|signal |extends |class_name |if .*:|for .*:|while .*:|match .*:)") != OK:
		return false
	return code_line.search(text) != null


## Pastes raw GDScript copied from anywhere, converted through the same pipeline that
## opens .gd files as sheets: the lossless rule keeps every line (unrecognized code stays
## verbatim GDScript block rows), declarations verify-lift to variable rows, and trigger
## functions ACE-lift into real events when the round-trip verifies. Returns false for
## non-code clipboards so the regular paste paths continue.
func _paste_gdscript_text(text: String) -> bool:
	if text.strip_edges().is_empty() or EventSheetSnippet.is_snippet_text(text):
		return false
	if not _looks_like_gdscript(text):
		return false
	if not _dock._ensure_sheet_for_editing():
		return false
	var imported: EventSheetResource = GDScriptImporter.new().import_external_source(text)
	if imported.events.is_empty():
		return false
	var rows: Array = imported.events.duplicate()
	var lifted_events: int = 0
	var context: Dictionary = _dock._active_view().get_selected_context()
	var anchor: Resource = context.get("source_resource", null)
	var changed: bool = _dock._perform_undoable_sheet_edit("Paste GDScript", func() -> bool:
		var insert_after: Resource = anchor
		for row: Variant in rows:
			if row is EventRow:
				_dock._assign_fresh_event_uids(row)
			_dock._insert_row_below_selection(row, insert_after)
			insert_after = row
		return true
	)
	if not changed:
		return false
	for row: Variant in rows:
		if row is EventRow:
			lifted_events += 1
	_dock._refresh_after_edit()
	if lifted_events > 0:
		_dock._mark_dirty("Pasted GDScript: %d row(s), %d event(s) auto-converted." % [rows.size(), lifted_events])
	else:
		_dock._mark_dirty("Pasted GDScript as %d block row(s) - no trigger functions to convert." % rows.size())
	return true
