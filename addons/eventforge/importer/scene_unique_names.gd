# Godot EventSheets - the %Name is a word the sheet can speak.
#
# Godot already has a name for "the one node I mean, wherever somebody moves it to": the scene-unique
# mark, written `%HealthBar` and stored in the `.tscn` as `unique_name_in_owner = true`. It is the
# engine's own idea, nothing here invents a second one, and this file is only the place that reads it
# back out of the scene text so the editor can offer it as an object rather than as typing.
#
# TWO QUESTIONS, ONE WALK:
#   - WHICH %names a sheet's scene carries, which is the picker's `%names` section;
#   - WHAT CLASS one of them is, which is what lets a statement written on `%HealthBar` read as a row
#     on a ProgressBar instead of as a row on a bare Node.
#
# THE SCENE IS THE ONLY AUTHORITY. Nothing is registered, nothing is cached into a sheet and nothing
# is written back: the mark lives in the scene file, the reader derives from it on every ask, and a
# node that loses the mark simply stops being listed. This is deliberately NOT a registry of names -
# the named_scenes pack already owns the idea of naming scenes, and a second table of node names
# would be two places to disagree about one truth.
#
# WHAT IS NOT CLAIMED. A `%Name` this cannot resolve - the scene never marked it, the scene is an
# instanced child whose type the text does not spell, no scene uses this script at all - is simply
# absent, and every reader above degrades to the honest plain code it already showed. A guessed class
# would be worse than none: it would put an object's whole vocabulary on a row that cannot take it.
#
# NOTHING NEW TO CHECK. The Doctor's shipped `%token` validation already sweeps every sheet for a
# `%Name` no scene carries, so a stale name is reported there and nowhere else - the sheet itself
# stays quiet, and a row on a name the scene dropped keeps its plain reading and its amber state.
#
# COST. One read of the scene text, through EventSheetSceneLights - the project's one node walk,
# already cached per file stamp - so a picker asking per keystroke and a row builder asking per
# rebuild share the same parse.
#
# PURE + STATIC: a script path in, plain Dictionaries out. No dock, no canvas, no editor.
@tool
class_name EventSheetSceneUniqueNames
extends RefCounted

## The scene attribute that carries the mark. The editor writes it as a BARE flag on the node's own
## header line rather than as a property under it, which is why the scene walk reads it there and
## hands it on as `unique`. An absent flag means "not marked", never "unknown".
const MARK_ATTRIBUTE: String = "unique_name_in_owner"

## How a row spells one of these nodes. The sigil is the engine's own, and every reader here writes
## it the same way so a picked object and a lifted line name the node with the same characters.
const SIGIL: String = "%"


## Every scene-unique node of the scenes that run `script_path`, in scene order:
##   {"name", "path", "class", "reference", "scene_path"}
## `reference` is `%Name` - the spelling a row addresses it by, which is the whole point of the mark.
## Empty for a script no scene uses, and for a scene that marked nothing.
static func for_script(script_path: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var seen: Dictionary = {}
	for node: Dictionary in EventSheetSceneLights.nodes_for_script(script_path):
		if not is_marked(node):
			continue
		var node_name: String = str(node.get("name", ""))
		# A name is unique WITHIN one owner, so two scenes running the same script can each carry a
		# `%HealthBar`. The sheet can only speak one of them, and the first in scene order is the one
		# every other reader here would resolve - so it is the one listed, rather than a duplicate row
		# a reader could not tell apart.
		if node_name.is_empty() or seen.has(node_name):
			continue
		seen[node_name] = true
		found.append({
			"name": node_name,
			"path": str(node.get("path", "")),
			"class": str(node.get("class", "")),
			"reference": SIGIL + node_name,
			"scene_path": str(node.get("scene_path", "")),
		})
	return found


## True when one node entry of the scene walk carries the mark. Asked of the entry rather than of the
## file, so this family and every other one read the same single walk of the scene text.
static func is_marked(node: Dictionary) -> bool:
	return bool(node.get("unique", false))


## `%Name` -> the class that node is, plus the bare `Name` under the same answer, so a reader holding
## either spelling gets the same class. This is what the object-class map merges, and therefore what
## turns a statement on a `%Name` receiver into a row on that object.
##
## Nothing is guessed: a name absent from this map is a name the scene cannot answer for.
static func classes_for_script(script_path: String) -> Dictionary:
	var classes: Dictionary = {}
	for node: Dictionary in for_script(script_path):
		var node_class: String = str(node["class"]).strip_edges()
		if node_class.is_empty():
			continue
		classes[str(node["reference"])] = node_class
		classes[str(node["name"])] = node_class
	return classes


## The class one `%Name` is, or "" when this scene cannot answer for it. Takes the spelling a row
## actually wrote - with the sigil or without it - because a caller holding a receiver should not
## have to know which half of the map to ask.
static func class_of(script_path: String, reference: String) -> String:
	var text: String = reference.strip_edges()
	if text.is_empty():
		return ""
	return str(classes_for_script(script_path).get(text, ""))
