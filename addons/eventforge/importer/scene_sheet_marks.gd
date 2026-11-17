# EventForge - what a sheet says about the scene it was read from.
#
# The editor asks these questions of EVERY sheet it draws ("is this a scene view?", "is this script
# the member of one?"), and the answers are only reads of the sheet's own metadata. They live here,
# in a file that names nothing, so drawing an ordinary sheet does not compile the scene reader that
# builds the answers (its importer, its facts and everything they name). The scene reader keeps the
# same functions and reads them from here.
@tool
extends RefCounted

## The scene a composite sheet was built from, and the per-script members under it.
const SCENE_PATH_META: String = "__scene_sheet_path"
const MEMBERS_META: String = "__scene_members"
## Stamped on each MEMBER sheet, so its Include bar reads as the object bar of the node that carries
## it ("HUD a CanvasLayer") rather than as the script's own identity.
const OBJECT_BAR_META: String = "__scene_object_bar"
## The class of the scene's root node, for the scene bar.
const ROOT_TYPE_META: String = "__scene_root_type"


static func is_scene_sheet(sheet: EventSheetResource) -> bool:
	return sheet != null and sheet.has_meta(SCENE_PATH_META)


static func scene_path_of(sheet: EventSheetResource) -> String:
	return str(sheet.get_meta(SCENE_PATH_META, "")) if sheet != null else ""


## The per-script members, in tree order: {node, node_path, type, script_path, instances, sheet}.
static func members_of(sheet: EventSheetResource) -> Array:
	return (sheet.get_meta(MEMBERS_META, []) as Array) if sheet != null else []


## The class of the scene's root node, for the scene bar.
static func root_type_of(sheet: EventSheetResource) -> String:
	return str(sheet.get_meta(ROOT_TYPE_META, "")) if sheet != null else ""


## The node the object bar of ONE member names, as {node, type, script_path, instances}, or {} for a
## sheet opened on its own.
static func object_bar_of(sheet: EventSheetResource) -> Dictionary:
	return (sheet.get_meta(OBJECT_BAR_META, {}) as Dictionary) if sheet != null else {}
