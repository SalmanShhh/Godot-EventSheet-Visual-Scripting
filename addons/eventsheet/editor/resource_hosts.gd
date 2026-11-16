# Godot EventSheets - which names are a Resource class of the project (editor-only, a leaf).
#
# A sheet that extends `AudioStream` or `Texture2D` is a data asset because the engine says those
# classes inherit Resource. A sheet that extends a class from the user's OWN project (a card base, a
# stat block) is just as much a data asset, but the engine knows nothing of it: only the project's
# global class list does, and it names each class's base. This file walks that list.
#
# It names no other class on purpose: the first open of the workspace compiles everything a file names,
# and the two callers are on that path, so they load this by path and pay for it only when a sheet
# extends something the engine has never heard of.
@tool
extends RefCounted

## The most bases a chain of project classes is followed through, so a loop in a broken project ends.
const MOST_BASES: int = 32


## True when `host_class` is a class of this project whose chain of bases reaches Resource, through other
## project classes and then an engine class.
static func is_project_resource(host_class: String) -> bool:
	var bases: Dictionary = {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		bases[str(entry.get("class", ""))] = str(entry.get("base", ""))
	var walk: String = host_class.strip_edges()
	for step: int in range(MOST_BASES):
		if not bases.has(walk):
			return false
		walk = str(bases[walk])
		if walk == "Resource" or (ClassDB.class_exists(walk) and ClassDB.is_parent_class(walk, "Resource")):
			return true
	return false
