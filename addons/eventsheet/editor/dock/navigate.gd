@tool
extends RefCounted
class_name EventSheetNavigate
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

## The jump: open the defining behaviour script AS A SHEET (the lossless .gd-as-events open).
func navigate(row_data: EventRowData, _span_index: int, metadata: Dictionary) -> void:
	var target: Dictionary = resolve_target(row_data, metadata)
	if target.is_empty():
		return
	_dock._load_sheet_from_path(str(target.get("path")))
	_dock._set_status("Opened %s — the behaviour that defines this verb (Ctrl+Click any addon cell to jump)." % str(target.get("path")).get_file())

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
