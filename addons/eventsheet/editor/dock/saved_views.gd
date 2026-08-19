@tool
class_name EventSheetSavedViews
extends RefCounted
# SAVED VIEWS (V12) - a way of reading the sheet, named and kept.
#
# A view is three things a reader sets together and then wants back: the ARRANGEMENT (file order /
# object / trigger / group), the FILTER the find bar is holding, and the reading LENSES (humanized
# names, familiar words, compact rows, event numbers, object icons). Saving one names that
# combination; picking it from the View menu restores all three at once.
#
# Display only, like everything it remembers: no sheet is touched, nothing is written into the
# project, and a view that names an arrangement a later build removed reads as file order rather
# than as nothing. Stored per project in the editor's own metadata, beside the fold and zoom
# memories, so views travel with the machine rather than with the repository.

const META_SECTION := "eventsheets"
const META_KEY := "saved_views"

## Headless twin of the editor metadata store, so the whole shape is testable without an editor.
static var _memory: Dictionary = {}


## Every saved view, name -> blob, in a fresh dictionary the caller may keep.
static func all_views() -> Dictionary:
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var stored: Variant = EditorInterface.get_editor_settings().get_project_metadata(META_SECTION, META_KEY, {})
		if stored is Dictionary:
			return (stored as Dictionary).duplicate(true)
	return _memory.duplicate(true)


## The saved names, sorted, so the menu lists them the same way every time.
static func view_names() -> PackedStringArray:
	var names: Array = all_views().keys()
	names.sort()
	var out: PackedStringArray = PackedStringArray()
	for entry: Variant in names:
		out.append(str(entry))
	return out


## The blob one view holds, or an empty dictionary when nothing is saved under that name.
static func view(name: String) -> Dictionary:
	var found: Variant = all_views().get(name.strip_edges(), {})
	return (found as Dictionary) if found is Dictionary else {}


## The blob for the way a sheet is being read right now. `lenses` is whatever the caller wants
## restored later; only the keys it names are put back.
static func describe(arrangement_mode: int, filter_query: String, lenses: Dictionary) -> Dictionary:
	return {
		"arrangement": EventSheetArrangement.mode_id(arrangement_mode),
		"filter": filter_query.strip_edges(),
		"lenses": lenses.duplicate(true),
	}


## Names a view (replacing one of the same name). An empty name saves nothing.
static func save_view(name: String, blob: Dictionary) -> bool:
	var clean: String = name.strip_edges()
	if clean.is_empty():
		return false
	var views: Dictionary = all_views()
	views[clean] = blob.duplicate(true)
	_write(views)
	return true


## Forgets a view. False when there was nothing under that name.
static func delete_view(name: String) -> bool:
	var views: Dictionary = all_views()
	if not views.has(name.strip_edges()):
		return false
	views.erase(name.strip_edges())
	_write(views)
	return true


## The arrangement a saved blob asks for. An unknown id reads as file order.
static func arrangement_of(blob: Dictionary) -> int:
	return EventSheetArrangement.mode_from_id(str(blob.get("arrangement", "")))


static func filter_of(blob: Dictionary) -> String:
	return str(blob.get("filter", ""))


static func lenses_of(blob: Dictionary) -> Dictionary:
	var found: Variant = blob.get("lenses", {})
	return (found as Dictionary) if found is Dictionary else {}


static func _write(views: Dictionary) -> void:
	_memory = views.duplicate(true)
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		EditorInterface.get_editor_settings().set_project_metadata(META_SECTION, META_KEY, views)
