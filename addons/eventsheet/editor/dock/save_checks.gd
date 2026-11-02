@tool
class_name EventSheetSaveChecks
extends RefCounted

# What a save learns about the file it just wrote, and tells the sheet.
#
# Three things were known to the editor at save time and then dropped:
#
#   1. Whether the ENGINE can compile the script the sheet writes. A save used to check each row's
#      free code against a probe and, when the whole script failed for a reason no row explained (a
#      template's output, a pasted block, a name the host class already owns), said nothing at all -
#      and the engine's own words never reached the reader, because a detached GDScript reload prints
#      them to the Output panel and returns only an error code. The one door that gives both the line
#      and the message exactly as the engine words them is asking a second Godot to parse the file
#      (EventSheetParseErrors), a few hundred milliseconds, so it runs on a worker thread after the
#      save has already finished and lands on the next frame it can.
#   2. The same question for a sheet that IS a .gd: the parse check ran when the file was opened and
#      never again, so a save that broke the file left the red marks and the head bar's count from
#      before.
#   3. The compiler's warnings, which it returns beside every script and nothing in the editor read.
#
# Each answer is joined to the rows the way the rest of the editor does it: the engine's errors go
# through the compiler's source map onto the row that wrote the failing line and wear the red marker
# whose hover is the engine's sentence; the warnings the compiler attributed to an event set the quiet
# amber state on it; both are counted on the status line.

## Where the row marks of each layer are kept, per sheet file: {path: {"lint": [...], "engine": [...]}}.
## Not on the sheet itself: a .tres sheet saves its metadata into the file, and a mark is a fact about
## this session, not about the sheet.
static var _layers: Dictionary = {}

var _dock: Control = null
var _thread: Thread = null
## The request the worker is answering, and the newest one that arrived while it ran. A save made
## while a check is still running only replaces the waiting request: the answer to a file that has
## since been written again would be about bytes that no longer exist.
var _request: Dictionary = {}
var _waiting: Dictionary = {}


func init(dock: Control) -> void:
	_dock = dock


## Runs after a write: records what the compiler said, repaints the amber state when the set of
## warnings changed, and starts the engine's check of `written_path` in the background. `compile_result`
## is the result of the compile that wrote the file. Returns the words for the status line about the
## warnings ("" when there were none), so the caller can put them beside its own sentence.
func after_write(sheet: EventSheetResource, written_path: String, compile_result: Dictionary) -> String:
	var warnings: Array = compile_result.get("warnings", [])
	var warnings_changed: bool = EventSheetCompilerFindings.record(sheet, compile_result)
	if warnings_changed:
		_repaint_rows()
	_begin_engine_check({
		"path": written_path,
		"sheet_key": EventSheetCompilerFindings.key_of(sheet),
		"source_map": compile_result.get("source_map", []),
		"backed": not sheet.external_source_path.is_empty(),
	})
	return EventSheetCompilerFindings.summary(warnings)


## Starts the check on a worker thread, or queues it behind the one already running. Nothing here
## blocks: the save that called it has already told the reader it is done.
func _begin_engine_check(request: Dictionary) -> void:
	var path: String = str(request.get("path", ""))
	if path.is_empty() or not path.begins_with("res://") or not FileAccess.file_exists(path):
		return
	if _thread != null:
		_waiting = request
		return
	_request = request
	_thread = Thread.new()
	_thread.start(_check_off_thread.bind(path))


func _check_off_thread(path: String) -> void:
	var errors: Array = EventSheetParseErrors.check_file(path)
	_check_returned.call_deferred(errors)


func _check_returned(errors: Array) -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	var request: Dictionary = _request
	_request = {}
	apply_engine_result(request, errors)
	if not _waiting.is_empty():
		var next: Dictionary = _waiting
		_waiting = {}
		_begin_engine_check(next)


## Joins the worker, if one is running. The dock calls it on its way out so a thread is never left
## to outlive the object it reports to.
func join() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null


## Puts one answer of the engine's check on the sheet it was about: the rows its lines came from wear
## the red marker, a .gd sheet's stored parse errors (the head bar's count) are replaced, and the
## status line says the first error in the engine's own words. Skipped when the tab has moved on to
## another sheet - the marks belong to the sheet they were measured on. Public and synchronous so the
## suite drives it without a thread.
func apply_engine_result(request: Dictionary, errors: Array) -> void:
	var key: String = str(request.get("sheet_key", ""))
	if key.is_empty():
		return
	var rows: Array = EventSheetParseErrors.row_diagnostics(errors, request.get("source_map", []))
	var layers: Dictionary = _layers_of(key)
	var changed: bool = layers.get("engine", []) != rows
	layers["engine"] = rows
	var sheet: EventSheetResource = _dock._current_sheet if _dock != null else null
	if sheet == null or EventSheetCompilerFindings.key_of(sheet) != key:
		return
	var head_changed: bool = false
	if bool(request.get("backed", false)):
		head_changed = EventSheetParseErrors.errors_for(sheet) != errors
		EventSheetParseErrors.store_on_sheet(sheet, errors)
	if changed or head_changed:
		_paint(sheet, head_changed)
	if not errors.is_empty():
		var first: Dictionary = errors[0]
		_dock._set_status(EventSheetL10n.translate(
			"Saved, but Godot cannot compile the script this sheet writes: %s (line %d of %s) - the row it came from is marked.") % [
			str(first.get("message", "")), int(first.get("line", 0)), str(request.get("path", "")).get_file()], true)


## The row marks the lint pass found, remembered beside the engine's so the two are painted together.
static func set_lint_layer(sheet: EventSheetResource, diagnostics: Array) -> void:
	_layers_of(EventSheetCompilerFindings.key_of(sheet))["lint"] = diagnostics


## Every red mark a sheet wears: the lint's, then the engine's for the rows the lint did not mark. A row
## the lint marked with its generic "does not compile" wording takes the engine's sentence when the
## engine named the same row, because the engine's words are the reason.
static func merged_diagnostics(sheet: EventSheetResource) -> Array:
	var layers: Dictionary = _layers.get(EventSheetCompilerFindings.key_of(sheet), {})
	var merged: Array = []
	var by_uid: Dictionary = {}
	for entry: Variant in layers.get("lint", []):
		var carried: Dictionary = (entry as Dictionary).duplicate()
		merged.append(carried)
		by_uid[str(carried.get("uid", ""))] = carried
	for entry: Variant in layers.get("engine", []):
		var engine_mark: Dictionary = entry as Dictionary
		var uid: String = str(engine_mark.get("uid", ""))
		if by_uid.has(uid):
			var existing: Dictionary = by_uid[uid]
			if str(existing.get("message", "")).contains(GENERIC_LINT_WORDS):
				existing["message"] = str(engine_mark.get("message", ""))
		else:
			merged.append(engine_mark.duplicate())
			by_uid[uid] = merged[merged.size() - 1]
	return merged


## The sentence the probe lint puts on a row when it cannot say why; the engine's reason replaces it.
const GENERIC_LINT_WORDS := "parse/analyze failed"


static func _layers_of(key: String) -> Dictionary:
	if not _layers.has(key):
		_layers[key] = {"lint": [], "engine": []}
	return _layers[key]


## Replaces the engine layer of a sheet's marks - what a parse check found.
static func set_engine_layer(sheet: EventSheetResource, marks: Array) -> void:
	_layers_of(EventSheetCompilerFindings.key_of(sheet))["engine"] = marks


## Forgets every layer. A test's way back to a clean slate.
static func clear_layers() -> void:
	_layers.clear()


## Paints the merged marks on the active view. A set equal to the one already painted rebuilds nothing
## (the viewport's own rule); `rebuild` is for a .gd sheet whose stored parse errors changed, which
## the head bar's count reads while the rows are built.
func _paint(sheet: EventSheetResource, rebuild: bool) -> void:
	var view: EventSheetViewport = _dock._active_view() if _dock != null else null
	if view == null:
		return
	view.set_row_diagnostics(merged_diagnostics(sheet))
	if rebuild:
		view._refresh_rows()


## Rebuilds the rows of the active view so a changed set of compiler warnings shows. Only called when
## the set changed: a save that found the same warnings, or none before and none now, costs nothing.
func _repaint_rows() -> void:
	var view: EventSheetViewport = _dock._active_view() if _dock != null else null
	if view != null:
		view._refresh_rows()
