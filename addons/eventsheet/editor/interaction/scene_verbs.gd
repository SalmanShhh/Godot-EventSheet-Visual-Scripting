# Godot EventSheets - what the sheet's OWN ROWS say about the scene's two networking nodes.
#
# The scene half of Godot's multiplayer is read from the `.tscn` (scene_replication.gd): which
# properties a synchronizer keeps in step, which scenes a spawner may make. This is the other
# direction - the facts that live in the ROWS, and that nothing else can answer:
#
#   - which scene a Spawn row names, and whether the spawner it addresses actually lists that scene
#     (a spawner asked for a scene it does not know spawns a copy that never travels, and the only
#     place that mismatch is visible is here, between the row and the scene);
#   - which of this sheet's functions a synchronizer ASKS about visibility. `add_visibility_filter`
#     is a row like any other, and the function it names is an ordinary function - so the fact that
#     it is a visibility filter is not stored anywhere, it is READ back off the row that uses it,
#     exactly as a message is read off its own `@rpc` annotation rather than off a flag.
#
# PURE + STATIC: a sheet in, plain Dictionaries out. No dock, no canvas, no editor - so the row's
# words, the dialog's suggestions and the writer's arguments are all pinned headless.
@tool
class_name EventSheetSceneVerbs
extends RefCounted

## The vocabulary this reading is about. Frozen alongside the descriptors themselves: a row is one
## of these by its `ace_id`, never by what its words happen to say.
const PROVIDER := "Core"
const SPAWN_ACE_ID := "SpawnReplicatedScene"
const FILTER_ACE_ID := "AddVisibilityFilter"

## The parameters those two rows carry their answers in.
const SCENE_PARAM := "scene"
const FILTER_PARAM := "filter"
const TARGET_PARAM := "target"

## The field kind the *Scene* parameter opens - the one hint in the vocabulary whose field is filled
## from a scene file rather than from the project or the row. Spelled here because the dialog, the
## field factory's paragraph table and the descriptor all have to agree on it.
const SCENE_HINT := "spawn_scene"


## Every scene the spawners of this sheet's own scene may make, as the QUOTED paths a row holds
## (`"res://player.tscn"`) - the Spawn dialog's suggestions. In scene order, nothing said twice, and
## empty for a sheet whose scene has no spawner: a list with nothing in it is a plain field, which is
## the right field when there is nothing to pick from.
static func spawn_scene_choices(sheet: EventSheetResource) -> PackedStringArray:
	var choices: PackedStringArray = PackedStringArray()
	for spawner: Dictionary in spawners_in_scene(sheet):
		for scene: String in (spawner.get("scenes", PackedStringArray()) as PackedStringArray):
			var quoted: String = "\"%s\"" % scene
			if not choices.has(quoted):
				choices.append(quoted)
	return choices


## The spawners that live in this sheet's own scene - the ones a Spawn row can address. (The other
## half of `EventSheets.spawners_of`, the spawners ELSEWHERE that can make this scene, is what the
## head's "spawned by" band is about and has no verb.)
static func spawners_in_scene(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry: Dictionary in EventSheets.spawners_of(sheet):
		if str(entry.get("relation", "")) == EventSheetSceneReplication.RELATION_IN_SCENE:
			found.append(entry)
	return found


## The spawner a Spawn row's *Spawner* value names, or {} when the scene has none by that name. The
## value is a node reference as the sheet spells them - `$Spawner`, `%Spawner`, `"Spawner"` or the
## bare name - and `self` (or nothing at all) means the sheet's own node, which is the answer when
## the scene has exactly one spawner and the row never had to say which.
static func spawner_named(sheet: EventSheetResource, target: String) -> Dictionary:
	var listed: Array[Dictionary] = spawners_in_scene(sheet)
	if listed.is_empty():
		return {}
	var wanted: String = node_name_of(target)
	if wanted.is_empty() or wanted == "self":
		return listed[0] if listed.size() == 1 else {}
	for spawner: Dictionary in listed:
		if str(spawner.get("name", "")) == wanted or str(spawner.get("node_path", "")) == wanted:
			return spawner
	return {}


## The bare node name inside a sheet's node reference: `$Players/Spawner` -> "Players/Spawner",
## `%Spawner` -> "Spawner", `"Spawner"` -> "Spawner". "" for a value that is not a node reference at
## all (an expression, a variable), because a row that computes its node cannot be checked against
## the scene and should not be guessed at.
static func node_name_of(target: String) -> String:
	var text: String = target.strip_edges()
	if text.begins_with("$") or text.begins_with("%"):
		text = text.substr(1)
	text = EventSheetSentence.unquote(text)
	for character: String in [" ", "(", ".", "+"]:
		if text.contains(character):
			return ""
	return text


## What a Spawn row still needs the SCENE to say, or {} when it needs nothing: the arguments
## `EventSheetSceneReplication.add_spawnable_scene` takes, as `{"scene_path", "spawner_path",
## "scene", "spawner"}`. Empty whenever there is nothing to do or nothing that can be done - the row
## names no scene, the value is not a plain path, the spawner cannot be found, or the spawner already
## lists it. The decision is made HERE rather than in the writer so a dialog can say what pressing OK
## will do before it does it.
static func unlisted_spawn_scene(sheet: EventSheetResource, params: Dictionary) -> Dictionary:
	var scene: String = EventSheetSentence.unquote(str(params.get(SCENE_PARAM, "")).strip_edges())
	if not scene.begins_with("res://"):
		return {}
	var spawner: Dictionary = spawner_named(sheet, str(params.get(TARGET_PARAM, "")))
	if spawner.is_empty():
		return {}
	if (spawner.get("scenes", PackedStringArray()) as PackedStringArray).has(scene):
		return {}
	return {
		"scene_path": str(spawner.get("scene_path", "")),
		"spawner_path": str(spawner.get("node_path", "")),
		"scene": scene,
		"spawner": str(spawner.get("name", "")),
	}


## The line the Spawn dialog's help strip adds when the scene named is not in the spawner's list -
## said BEFORE OK is pressed, because pressing it edits the scene. "" when there is nothing to add.
static func unlisted_scene_note(pending: Dictionary) -> String:
	if pending.is_empty():
		return ""
	return EventSheetL10n.translate("%s is not in %s's list of scenes it may spawn yet. Pressing OK adds it, as one step of the scene's own undo.") \
		% [str(pending.get("scene", "")).get_file(), str(pending.get("spawner", ""))]


## The number the Spawn dialog's strip says while the *Spawner* field has focus: how many copies
## that spawner is allowed to be watching at once. "" when the row names no spawner this scene has,
## and "" for a limit of 0 - which is Godot's own way of saying there is no limit, and a sentence
## about a limit that does not exist is worse than no sentence.
static func spawn_limit_note(sheet: EventSheetResource, params: Dictionary) -> String:
	var spawner: Dictionary = spawner_named(sheet, str(params.get(TARGET_PARAM, "")))
	var limit: int = int(spawner.get("spawn_limit", 0))
	if limit <= 0:
		return ""
	return EventSheetL10n.translate("%s may be watching %d copies at once - its Spawn limit in the Inspector. Past that it refuses to make another until one goes.") \
		% [str(spawner.get("name", "")), limit]


## Every function of this sheet a synchronizer ASKS about visibility, in the order the rows name
## them: `{"name", "synchronizer"}` per function, where `synchronizer` is the node the row addresses
## ("" when the row acts on the sheet's own node). This is the list the function row's own mark reads,
## and the one a Doctor check would join against - a filter nobody asks is just a function.
static func visibility_filters_in(sheet: EventSheetResource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var seen: Dictionary = {}
	for action: ACEAction in _actions_in(sheet):
		if action.provider_id != PROVIDER or action.ace_id != FILTER_ACE_ID:
			continue
		var named: String = str(action.params.get(FILTER_PARAM, "")).strip_edges()
		if not named.is_valid_identifier() or seen.has(named):
			continue
		seen[named] = true
		found.append({"name": named, "synchronizer": node_name_of(str(action.params.get(TARGET_PARAM, "")))})
	return found


## One function's entry in that list, or {} when no synchronizer asks it - which is every other
## function. The one lookup both halves of the row's mark go through: whether to say the words at
## all, and which synchronizer to name. Kept as the whole entry rather than as two questions because
## a filter addressed at the sheet's own node has an EMPTY synchronizer, so "" cannot also mean no.
static func filter_of(sheet: EventSheetResource, function_name: String) -> Dictionary:
	var wanted: String = function_name.strip_edges()
	for entry: Dictionary in visibility_filters_in(sheet):
		if str(entry.get("name", "")) == wanted:
			return entry
	return {}


## Every ACE action of a sheet, its functions and its nested events included. One walk, so a row
## nested three deep inside a function is as visible to this reading as one at the top.
static func _actions_in(sheet: EventSheetResource) -> Array[ACEAction]:
	var found: Array[ACEAction] = []
	if sheet == null:
		return found
	_collect(sheet.events, found)
	for entry: Variant in sheet.functions:
		if entry is EventFunction:
			_collect((entry as EventFunction).events, found)
	return found


static func _collect(events: Array, into: Array[ACEAction]) -> void:
	for entry: Variant in events:
		# A group is the commonest thing a reader does to a sheet, and it holds rows like any other
		# level: a walk that skipped it would lose the row's own mark and under-report the public
		# list the moment somebody tidied their events into folders.
		if entry is EventGroup:
			_collect(EventSheetGroupFacts.children(entry as EventGroup), into)
			continue
		var event: EventRow = entry as EventRow
		if event == null:
			continue
		for action_entry: Variant in event.actions:
			if action_entry is ACEAction:
				into.append(action_entry as ACEAction)
		_collect(event.sub_events, into)
