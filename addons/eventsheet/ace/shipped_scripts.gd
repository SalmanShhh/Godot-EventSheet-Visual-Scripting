# Godot EventSheets - which script files the plugin itself ships.
#
# A rule meant for a user's own script (a row that acts on the real thing instead of a hidden copy, a
# `static func` read as a row) must leave the plugin's own files reading exactly as before: a shipped
# behaviour's vocabulary is a compatibility promise. A file is the plugin's when it sits under `addons/`,
# in a pack folder the plugin ships, or at the root of `eventsheet_addons/`; any other folder there is
# the reader's own. A leaf that names nothing, so the readers a boot reaches can ask it. No class_name.
@tool
extends RefCounted

const PACK_DIRECTORY: String = "res://eventsheet_addons/"
## By path, so the list of folders is read only when a script under the packs' root asks.
const SHIPPED_PACKS_PATH: String = "res://addons/eventforge/shipped_pack_folders.gd"


## True for a file the plugin ships, false for a script the reader wrote.
static func is_shipped(path: String) -> bool:
	if path.begins_with("res://addons/"):
		return true
	if not path.begins_with(PACK_DIRECTORY):
		return false
	var rest: String = path.trim_prefix(PACK_DIRECTORY)
	var slash: int = rest.find("/")
	return slash < 0 or load(SHIPPED_PACKS_PATH).FOLDERS.has(rest.substr(0, slash))
