# Godot EventSheets - which pack directory publishes which provider, read once per session.
#
# Split out of the public API so that the picker can ask without naming `EventSheets`, whose methods
# name the compiler, the importer, the Doctor, the viewport and the dock. The picker asks for every
# pack card it lists. `EventSheets.addon_pack_directory` and `pack_providers` keep their shapes and
# forward here.
#
# No `class_name`: callers preload it, the same reason `extension_registries.gd` has none.
@tool
extends RefCounted

## provider id -> pack directory, built in ONE pass over the addon scripts and reused for the
## whole session. Per-provider scanning was measured at ~63 ms per newly seen provider on a
## corpus this size, and this map is read on the picker's selection-change path, so a
## per-provider scan is a visible stall every time the reader arrows onto a new pack. Builtin
## providers are not in the map at all - the miss must cost nothing, not a full corpus read.
static var _pack_dir_by_provider: Dictionary = {}
## Set ONLY by the function that fills the map completely (a flag pre-set by a partial scan is
## how a lazy cache silently loses entries).
static var _pack_dir_map_built: bool = false


## The pack directory a provider id lives in, "" for a builtin or an unknown one.
static func addon_pack_directory(provider_id: String) -> String:
	var wanted: String = provider_id.strip_edges()
	if wanted.is_empty():
		return ""
	_ensure_pack_directory_map()
	return str(_pack_dir_by_provider.get(wanted, ""))


## Every provider id declared inside a pack directory, sorted.
static func pack_providers(pack_dir: String) -> PackedStringArray:
	var wanted: String = pack_dir.strip_edges().trim_suffix("/").get_file()
	var providers: PackedStringArray = PackedStringArray()
	if wanted.is_empty():
		return providers
	_ensure_pack_directory_map()
	for provider_id: Variant in _pack_dir_by_provider:
		if str(_pack_dir_by_provider[provider_id]) == wanted:
			providers.append(str(provider_id))
	providers.sort()
	return providers


## Reads every addon script once and records every class_name it finds against its directory.
static func _ensure_pack_directory_map() -> void:
	if _pack_dir_map_built:
		return
	var matcher: RegEx = RegEx.create_from_string("(?m)^class_name[ \\t]+([A-Za-z_][A-Za-z0-9_]*)")
	for script_path: String in EventSheetAddonScanner.list_addon_scripts():
		var source: String = FileAccess.get_file_as_string(script_path)
		if source.is_empty():
			continue
		var directory: String = script_path.get_base_dir().get_file()
		for found: RegExMatch in matcher.search_all(source):
			var declared: String = found.get_string(1)
			if not _pack_dir_by_provider.has(declared):
				_pack_dir_by_provider[declared] = directory
	_pack_dir_map_built = true
