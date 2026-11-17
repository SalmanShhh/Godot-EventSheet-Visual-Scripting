@tool
extends RefCounted

## The Scene field of a spawn row. A row's scene slot is any parameter whose template says `{scene}.instantiate()`,
## so the slot takes a PackedScene held by name as well as a `load()` of a path. This is what the field offers
## FIRST: the scene variables and constants this sheet declares itself, each inserting its own name, so the row
## writes `enemy_scene.instantiate()` - the line a Godot user would write - and the sheet never writes a
## `preload` on its own. Loaded by path from the dialog, so naming it costs the first-open closure nothing.


## Whether the template runs `.instantiate()` on the parameter `key`: the one thing that makes it a scene slot.
static func is_scene_slot(template: String, key: String) -> bool:
	return not key.is_empty() and template.contains("{%s}.instantiate()" % key)


## The sheet's own scene variables and constants as completion entries, in the order the sheet declares them. A
## variable is a scene when its declared type is PackedScene, or when it holds a `load` / `preload` of a scene
## file without saying a type.
static func entries(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for member: Dictionary in EventSheetVariableOwners.member_rows(sheet):
		var value_text: String = str(member.get("value", "")).strip_edges()
		var is_scene: bool = str(member.get("type_name", "")) == "PackedScene" \
			or (value_text.contains("load(") and (value_text.contains(".tscn\"") or value_text.contains(".scn\"")))
		if not is_scene:
			continue
		var scope: String = str(member.get("scope", ""))
		found.append({
			"text": str(member.get("name", "")),
			"detail": EventSheetL10n.translate("A scene this sheet holds.") + ("" if value_text.is_empty() else " · %s" % value_text),
			"kind": EventSheetCompletions.KIND_VARIABLE,
			"type": "PackedScene",
			"scope": scope,
		})
	return found


## The ranked list with the sheet's scene slots in front: the ones the typed text matches come first, and the
## rest of the list follows without them said twice.
static func in_front(sheet: EventSheetResource, ranked: Array[Dictionary], needle: String) -> Array[Dictionary]:
	var scenes: Array[Dictionary] = EventSheetCompletions.rank(entries(sheet), needle)
	if scenes.is_empty():
		return ranked
	var named: Dictionary = {}
	var out: Array[Dictionary] = []
	for entry: Dictionary in scenes:
		named[str(entry["text"])] = true
		out.append(entry)
	for entry: Dictionary in ranked:
		if not named.has(str(entry.get("text", ""))):
			out.append(entry)
	return out
