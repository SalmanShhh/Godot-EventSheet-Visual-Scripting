@tool
extends EditorInspectorPlugin
# One small link at the top of Godot's Inspector for a resource or node whose script is a sheet:
#
#   EnemyStats  goblin.tres
#   Shape EnemyStats…            <- opens the Inspector Designer for enemy_stats.gd
#   max_health   100
#
# A script is a sheet when the plugin pairs it with one (a sheet's generated script, a pack) or when it
# is a project .gd with something exported to shape - a .gd file is a sheet the moment it is opened as
# one. Scripts of other addons, and objects with no script, are left exactly as Godot draws them. The
# reading is the same light text scan the "Edit Event Sheet" button makes, memoized there, so a
# selection costs no compile.
#
# Registered once the workspace is built (the plugin hands it its door), so neither the editor's boot
# nor a sheet's first open loads it.

## Opens the Designer for a sheet path: Callable(sheet_path: String).
var open_designer: Callable = Callable()

# _can_handle runs on every Inspector refresh, so whether a script exports anything is read once per
# version of the file: {script path: [modified time, exports anything]}.
static var _exports_cache: Dictionary = {}


## The sheet the object's script is, or "" (which also means "don't handle"). Static so a headless test
## can ask it: an EditorInspectorPlugin can only be used by the editor.
static func sheet_for(object: Object) -> String:
	if not (object is Resource or object is Node):
		return ""
	var script: Script = object.get_script() as Script
	if script == null or script.resource_path.get_extension() != "gd" or script.resource_path.contains("::"):
		return ""
	var path: String = script.resource_path
	if object is Node:
		var paired: String = EventSheetEditButtonPlugin.sheet_path_for(object)
		if not paired.is_empty():
			return paired
	if path.begins_with("res://addons/"):
		return ""
	var modified: int = int(FileAccess.get_modified_time(path))
	var cached: Array = _exports_cache.get(path, [])
	if cached.is_empty() or int(cached[0]) != modified:
		var exports: bool = EventSheetEditButtonPlugin.member_variables(path).any(
			func(member: Dictionary) -> bool: return bool(member.get("exported", false)))
		cached = [modified, exports]
		_exports_cache[path] = cached
	return path if bool(cached[1]) else ""


## The link's words: "Shape <the script's class>…", the class named exactly as the script declares it
## (its file name when it declares none).
static func link_text(object: Object) -> String:
	var script: Script = object.get_script() as Script
	var named: String = str(script.get_global_name()) if script != null else ""
	if named.is_empty() and script != null:
		named = script.resource_path.get_file().get_basename()
	return EventSheetL10n.translate("Shape %s…") % named


func _can_handle(object: Object) -> bool:
	return not sheet_for(object).is_empty()


func _parse_begin(object: Object) -> void:
	var sheet_path: String = sheet_for(object)
	if sheet_path.is_empty():
		return
	var link: LinkButton = LinkButton.new()
	link.text = link_text(object)
	link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	link.add_theme_color_override("font_color", EventSheetPopupUI.accent_color())
	link.tooltip_text = EventSheetL10n.translate("Opens the Inspector Designer for %s: how each field of it looks, when it shows and what it checks.") % sheet_path.get_file()
	link.pressed.connect(func() -> void:
		if open_designer.is_valid():
			open_designer.call(sheet_path))
	add_custom_control(link)
