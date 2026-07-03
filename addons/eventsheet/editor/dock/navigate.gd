@tool
class_name EventSheetNavigate
extends RefCounted
# Ctrl+Click go-to-definition. Every zero-config addon ACE already carries its own address — its
# provider_id IS the addon script's class_name (that's how the scanner registers it) — so Ctrl+Clicking
# a behaviour-pack verb in a consumer sheet opens THAT BEHAVIOUR AS A SHEET: the jump the script editor
# can't make (it lands you in raw text) and Construct-style tools can't make at all (their behaviors are
# sealed). Built-in Core/module ACEs have no user-meaningful definition file, so they resolve to nothing
# and Ctrl+Click keeps its multi-select meaning there (the viewport's probe arbitrates per cell).
#
# ONE helper on the dock (the future home of the back/forward jump history); the viewport stays a dumb
# emitter: it asks can_navigate() to pick the gesture and emits navigate_requested when it wins.

var _dock: Control = null
# class_name -> res:// script path over the addon folders; built once per session, invalidated never
# (adding an addon script means a rescan on next editor start, same as ACE discovery itself).
var _class_script_cache: Dictionary = {}
var _cache_built: bool = false


func init(dock: Control) -> void:
	_dock = dock


## The viewport's per-cell probe: true when Ctrl+Clicking this span jumps somewhere real.
func can_navigate(row_data: EventRowData, metadata: Dictionary) -> bool:
	return not resolve_target(row_data, metadata).is_empty()


## Where a cell's ACE leads: {"kind": "sheet", "path", "provider"} for an addon-backed verb, {} when
## there is nowhere meaningful to go (built-ins, non-ACE spans).
func resolve_target(row_data: EventRowData, metadata: Dictionary) -> Dictionary:
	if row_data == null or not (row_data.source_resource is EventRow):
		return {}
	var kind: String = str(metadata.get("kind", ""))
	if kind not in ["condition", "action", "trigger"]:
		return {}
	var view: EventSheetViewport = _dock._active_view()
	if view == null:
		return {}
	var ace: Resource = view._resolve_ace_resource(row_data.source_resource, kind, int(metadata.get("ace_index", -1)))
	var provider: String = ""
	if ace is ACECondition:
		provider = (ace as ACECondition).provider_id
	elif ace is ACEAction:
		provider = (ace as ACEAction).provider_id
	if provider.strip_edges().is_empty() or provider == "Core":
		return {}
	var path: String = _script_path_for_class(provider)
	if path.is_empty():
		return {}
	return {"kind": "sheet", "path": path, "provider": provider}


## The jump: open the defining behaviour script AS A SHEET (the lossless .gd-as-events open),
## remembering where you came from so Alt+Left walks straight back.
func navigate(row_data: EventRowData, _span_index: int, metadata: Dictionary) -> void:
	var target: Dictionary = resolve_target(row_data, metadata)
	if target.is_empty():
		return
	record_current()
	open_or_focus(str(target.get("path")))
	_dock._set_status("Opened %s — the behaviour that defines this verb (Alt+Left jumps back)." % str(target.get("path")).get_file())

# ── Jump history (Alt+Left / Alt+Right) — the licence for fearless clicking ─────────────────────
# Two stacks of sheet paths. Every jump-away records the CURRENT file-backed sheet on the back stack
# and clears the forward stack (a new branch of history, exactly like a browser); Back/Forward move a
# path between the stacks and load it. Unsaved in-memory sheets have no path to return to, so they are
# skipped rather than recorded as dead entries.
var _back_stack: PackedStringArray = PackedStringArray()
var _forward_stack: PackedStringArray = PackedStringArray()


## Remember the current sheet before jumping somewhere else. Call this before any history-worthy load
## (Ctrl+Click, the palette's sheet search); skips unsaved sheets and de-dupes consecutive entries.
func record_current() -> void:
	var current: String = _current_history_path()
	if current.is_empty():
		return
	if _back_stack.size() > 0 and _back_stack[_back_stack.size() - 1] == current:
		return
	_back_stack.append(current)
	_forward_stack.clear()


func go_back() -> void:
	_history_step(_back_stack, _forward_stack, "Nothing to go back to yet — Ctrl+Click a verb or open a sheet first.")


func go_forward() -> void:
	_history_step(_forward_stack, _back_stack, "Nothing ahead — Alt+Left goes back first.")


## Pops from one stack onto the other and loads the popped sheet (skipping entries whose file has
## vanished since, so a renamed pack never wedges the history).
func _history_step(from_stack: PackedStringArray, to_stack: PackedStringArray, empty_message: String) -> void:
	while from_stack.size() > 0:
		var path: String = from_stack[from_stack.size() - 1]
		from_stack.remove_at(from_stack.size() - 1)
		if not FileAccess.file_exists(path):
			continue
		var current: String = _current_history_path()
		if not current.is_empty():
			to_stack.append(current)
		open_or_focus(path)
		return
	_dock._set_status(empty_message, true)


## Opens a sheet by path — RE-FOCUSING its tab when that file is already open instead of importing a
## duplicate copy. The tab store dedupes by sheet OBJECT, and every .gd load imports a fresh resource,
## so without this every Back/Forward (or repeated Ctrl+Click) would stack duplicate tabs.
func open_or_focus(path: String) -> void:
	for index: int in range(_dock._open_tabs.size()):
		var tab: Dictionary = _dock._open_tabs[index]
		var tab_sheet: EventSheetResource = tab.get("sheet")
		if str(tab.get("path", "")) == path or (tab_sheet != null and tab_sheet.external_source_path == path):
			_dock._activate_tab(index)
			return
	_dock._load_sheet_from_path(path)


func _current_history_path() -> String:
	var sheet: EventSheetResource = _dock.get_current_sheet()
	if sheet != null and not sheet.external_source_path.is_empty():
		return sheet.external_source_path
	return str(_dock._current_sheet_path)


## class_name → script path over the addon folders. A script's class_name is a single top-of-file
## declaration, so a cheap line scan resolves it without loading the script.
func _script_path_for_class(target_class: String) -> String:
	if not _cache_built:
		_cache_built = true
		for script_path: String in EventSheetAddonScanner.list_addon_scripts():
			var source: String = FileAccess.get_file_as_string(script_path)
			for line: String in source.split("\n", false, 40):
				if line.begins_with("class_name "):
					_class_script_cache[line.trim_prefix("class_name ").strip_edges()] = script_path
					break
	return str(_class_script_cache.get(target_class, ""))
