# Godot EventSheets - what the SCENE says about keeping a game in step (E2).
#
# Godot's high-level multiplayer keeps half of its story outside the script. A `MultiplayerSynchronizer`
# holds the list of properties it replicates, how often, and who may see them; a `MultiplayerSpawner`
# holds which scenes it can make and where it puts them. All of it lives in the `.tscn`, written by the
# Inspector and by the Replication panel - so a sheet that only reads the `.gd` shows a variable that
# is silently shared across the network as an ordinary variable.
#
# This is the one seam that reads those facts back. It is a READER first: the scene file is parsed
# through `EventSheetSceneConnections` (the project's one reader of scene text), and nothing is ever
# copied into the sheet - a mark on a row is derived on every build, so the `.gd` round-trip is
# untouched by a scene fact and deleting the sheet loses nothing. It is a WRITER only through
# `EditorInterface`: changing a property's mode edits the node in the open scene and registers the
# change with the scene's own undo, so the Inspector and the Replication panel stay the other editors
# of the same facts rather than being overwritten behind the reader's back.
#
# PURE + STATIC, apart from the two editor gestures at the foot. Everything a test needs - the modes,
# the readings, the echoes, the config rewrite - answers from a scene path and a script path with no
# dock, no canvas and no editor.
@tool
class_name EventSheetSceneReplication
extends RefCounted

## The three modes the Replication panel offers, plus the absence of all of them, as the words a row
## says. Frozen: rows, menus, the variable dialog and the public API all address a mode by these.
const MODE_OFF: String = "off"
const MODE_ALWAYS: String = "always"
const MODE_ON_CHANGE: String = "on change"
const MODE_AT_SPAWN: String = "at spawn"

## The reading order of the modes wherever several are said at once - the order the Replication panel
## lists them in, loudest first.
const MODE_ORDER: PackedStringArray = [MODE_ALWAYS, MODE_ON_CHANGE, MODE_AT_SPAWN]

## Godot's own numbers for `SceneReplicationConfig.replication_mode`, named so the parser reads as
## what the file means rather than as three magic integers.
const REPLICATION_NEVER: int = 0
const REPLICATION_ALWAYS: int = 1
const REPLICATION_ON_CHANGE: int = 2

## A synchronizer with no `root_path` line syncs its parent - Godot's default, and the shape every
## tutorial writes, so the absent line has to mean the same here as it does in the engine.
const DEFAULT_ROOT_PATH: String = ".."

const SYNCHRONIZER_TYPE: String = "MultiplayerSynchronizer"
const SPAWNER_TYPE: String = "MultiplayerSpawner"

## Which side of a spawner a reading is about: one that lives in this sheet's own scene (and can
## therefore be given a Spawn row), or one somewhere else whose list can make this scene.
const RELATION_IN_SCENE: String = "in_scene"
const RELATION_SPAWNS_THIS: String = "spawns_this"

## script path -> {"synced": Array, "spawners": Array}. Session-lifetime for the same reason the
## connection reader caches: the head asks on every build, and a scene does not change under a
## running editor often enough to justify re-reading a project directory per row sweep.
static var _cache: Dictionary = {}


## Everything the scene says about one script: `synced` is one entry per replicated property of a
## node that carries it, `spawners` one entry per spawner this script's scene is involved with.
## Empty for a script no scene uses, and for a project with no scenes at all.
static func for_script(script_path: String) -> Dictionary:
	var path: String = script_path.strip_edges()
	if path.is_empty() or not path.begins_with("res://"):
		return {"synced": [], "spawners": [], "synchronizers": [], "host": {}}
	if _cache.has(path):
		return _cache[path]
	var synced: Array = []
	var spawners: Array = []
	var synchronizers: Array = []
	var own_scenes: PackedStringArray = scenes_using(path)
	for scene_path: String in own_scenes:
		synchronizers.append_array(synchronizers_in_scene(scene_path, path))
		synced.append_array(synced_in_scene(scene_path, path))
		for spawner: Dictionary in spawners_in_scene(scene_path):
			spawner["relation"] = RELATION_IN_SCENE
			spawners.append(spawner)
	# The other direction: a spawner ANYWHERE whose list can make one of this script's scenes. This
	# is what the "spawned by" band stands for, and the scene it names is somebody else's file. A
	# script no scene runs cannot be spawned, and a scene whose text never says MultiplayerSpawner
	# has none - both are answered from the text before the parser is asked, because this sweep is
	# per project directory and the head asks it the first time any sheet is opened.
	var spawner_scenes: PackedStringArray = EventSheetSceneConnections.scene_paths() if not own_scenes.is_empty() \
		else PackedStringArray()
	for scene_path: String in spawner_scenes:
		if not FileAccess.get_file_as_string(scene_path).contains(SPAWNER_TYPE):
			continue
		for spawner: Dictionary in spawners_in_scene(scene_path):
			var spawned: PackedStringArray = spawner.get("scenes", PackedStringArray())
			var makes_this: bool = false
			for candidate: String in own_scenes:
				makes_this = makes_this or spawned.has(candidate)
			if not makes_this:
				continue
			spawner["relation"] = RELATION_SPAWNS_THIS
			spawners.append(spawner)
	var answer: Dictionary = {
		"synced": synced,
		"spawners": spawners,
		# The synchronizers of the sheet's OWN scene whether or not they already carry one of its
		# properties: "Keep in step" has to offer the node before anything is written on it.
		"synchronizers": synchronizers,
		"host": host_node(path),
	}
	_cache[path] = answer
	return answer


## Drops the cache. The editor calls this when the filesystem changes; tests call it between fixtures.
static func clear_cache() -> void:
	_cache.clear()


## Every scene whose nodes include one carrying this script, in project order.
static func scenes_using(script_path: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for scene_path: String in EventSheetSceneConnections.scene_paths():
		var text: String = FileAccess.get_file_as_string(scene_path)
		if text.is_empty() or not text.contains(script_path):
			continue
		for entry: Variant in EventSheetSceneConnections.nodes_of_scene(scene_path):
			if str((entry as Dictionary).get("script_path", "")) == script_path:
				found.append(scene_path)
				break
	return found


# ── Reading the scene ──────────────────────────────────────────────────────────────────────


## The node a scene runs this script on - `{"scene_path", "node_path", "node_name"}`, {} when no
## scene does. Where a synchronizer would be added, and the object a menu names when it offers to.
static func host_node(script_path: String) -> Dictionary:
	for scene_path: String in scenes_using(script_path):
		for entry: Variant in EventSheetSceneConnections.nodes_of_scene(scene_path):
			var node: Dictionary = entry
			if str(node.get("script_path", "")) != script_path:
				continue
			return {
				"scene_path": scene_path,
				"node_path": str(node.get("path", "")),
				"node_name": str(node.get("name", "")),
			}
	return {}


## Every `MultiplayerSynchronizer` of one scene whose root is a node carrying `script_path` - the
## nodes that could keep one of this script's variables in step, whether or not any of them already
## does: `{"name", "node_path", "scene_path", "target_path", "config_id", "interval",
## "public_visibility"}`.
static func synchronizers_in_scene(scene_path: String, script_path: String) -> Array:
	var found: Array = []
	var scripts: Dictionary = {}
	for entry: Variant in EventSheetSceneConnections.nodes_of_scene(scene_path):
		scripts[str((entry as Dictionary).get("path", ""))] = str((entry as Dictionary).get("script_path", ""))
	for entry: Variant in EventSheetSceneConnections.nodes_of_scene(scene_path):
		var node: Dictionary = entry
		if str(node.get("type", "")) != SYNCHRONIZER_TYPE:
			continue
		var properties: Dictionary = node.get("properties", {})
		var node_path: String = str(node.get("path", ""))
		var target: String = resolve_path(node_path,
			_node_path_text(str(properties.get("root_path", "")), DEFAULT_ROOT_PATH))
		if str(scripts.get(target, "")) != script_path:
			continue
		found.append({
			"name": str(node.get("name", "")),
			"node_path": node_path,
			"scene_path": scene_path,
			"target_path": target,
			"config_id": _sub_resource_id(str(properties.get("replication_config", ""))),
			"interval": str(properties.get("replication_interval", "0")).to_float(),
			# Godot writes `public_visibility` only when it is turned OFF, so an absent line is "yes".
			"public_visibility": str(properties.get("public_visibility", "true")) != "false",
		})
	return found


## Every property one scene keeps in step for the nodes carrying `script_path`, one entry per
## property: `{"name", "property_path", "mode", "synchronizer", "synchronizer_path", "scene_path",
## "node_path", "interval", "public_visibility"}`. `name` is the bare property - the word a variable
## row shows - and `property_path` is the `NodePath` spelling the config actually holds.
static func synced_in_scene(scene_path: String, script_path: String) -> Array:
	var found: Array = []
	var synchronizers: Array = synchronizers_in_scene(scene_path, script_path)
	if synchronizers.is_empty():
		return found
	var configs: Dictionary = _replication_configs(scene_path)
	var scripts: Dictionary = {}
	for entry: Variant in EventSheetSceneConnections.nodes_of_scene(scene_path):
		scripts[str((entry as Dictionary).get("path", ""))] = str((entry as Dictionary).get("script_path", ""))
	for entry: Variant in synchronizers:
		var synchronizer: Dictionary = entry
		var config_id: String = str(synchronizer.get("config_id", ""))
		if not configs.has(config_id):
			continue
		for record: Variant in configs[config_id]:
			var replicated: Dictionary = record
			var owner_path: String = resolve_path(str(synchronizer.get("target_path", ".")),
				str(replicated.get("node", ".")))
			if str(scripts.get(owner_path, "")) != script_path:
				continue
			found.append({
				"name": str(replicated.get("property", "")),
				"property_path": str(replicated.get("path", "")),
				"mode": str(replicated.get("mode", MODE_OFF)),
				"synchronizer": str(synchronizer.get("name", "")),
				"synchronizer_path": str(synchronizer.get("node_path", "")),
				"scene_path": scene_path,
				"node_path": owner_path,
				"interval": float(synchronizer.get("interval", 0.0)),
				"public_visibility": bool(synchronizer.get("public_visibility", true)),
			})
	return found


## Every `MultiplayerSpawner` of one scene: `{"name", "node_path", "scene_path", "spawn_path",
## "spawn_limit", "spawn_function", "scenes"}`. `spawn_function` is read from the SCRIPTS of the
## scene, because Godot never stores a Callable in a `.tscn` - a spawner's factory is always a line
## of code, and naming the file it came from is the only honest way to echo it.
static func spawners_in_scene(scene_path: String) -> Array:
	var found: Array = []
	for entry: Variant in EventSheetSceneConnections.nodes_of_scene(scene_path):
		var node: Dictionary = entry
		if str(node.get("type", "")) != SPAWNER_TYPE:
			continue
		var properties: Dictionary = node.get("properties", {})
		found.append({
			"name": str(node.get("name", "")),
			"node_path": str(node.get("path", "")),
			"scene_path": scene_path,
			"spawn_path": _node_path_text(str(properties.get("spawn_path", "")), ""),
			"spawn_limit": int(str(properties.get("spawn_limit", "0")).to_int()),
			"spawn_function": spawn_function_in_scene(scene_path, str(node.get("name", ""))),
			"scenes": _spawnable_scenes(str(properties.get("_spawnable_scenes", ""))),
		})
	return found


## The function a scene's own code hands its spawner - the `spawn_function = make_player` line - or
## "" when nothing sets one. Read from the scripts the scene uses, in tree order, because that line
## is GDScript and lives nowhere else.
static func spawn_function_in_scene(scene_path: String, spawner_name: String) -> String:
	var seen: Dictionary = {}
	for entry: Variant in EventSheetSceneConnections.nodes_of_scene(scene_path):
		var script_path: String = str((entry as Dictionary).get("script_path", ""))
		if script_path.is_empty() or seen.has(script_path):
			continue
		seen[script_path] = true
		var named: String = spawn_function_in_source(
			FileAccess.get_file_as_string(script_path), spawner_name)
		if not named.is_empty():
			return named
	return ""


## The `spawn_function` a piece of GDScript assigns, "" when it assigns none. Pure, so the shapes it
## understands are pinned by a test rather than by a scene: `$Spawner.spawn_function = make_player`,
## `spawner.spawn_function = _spawn`, and the `Callable(self, "make_player")` spelling.
static func spawn_function_in_source(source: String, spawner_name: String) -> String:
	for raw_line: String in source.split("\n"):
		var line: String = raw_line.strip_edges()
		var marker: int = line.find("spawn_function")
		if marker < 0 or not line.contains("="):
			continue
		var left: String = line.substr(0, marker)
		# A line addressing another spawner by name is that spawner's business, not this one's.
		if not spawner_name.is_empty() and not left.is_empty() and left.contains("$") \
				and not left.contains(spawner_name):
			continue
		var value: String = line.get_slice("=", 1).strip_edges()
		if value.begins_with("Callable("):
			var quoted: String = value.get_slice("\"", 1)
			return quoted if value.contains("\"") else ""
		# `spawn_function = make_player` - the callable is the bare function name; anything with a
		# call in it (`Callable(x).bind(y)`) is not a name a row could show.
		value = value.trim_prefix("self.").strip_edges()
		return value if value.is_valid_identifier() else ""
	return ""


## The mode one replicated property is in, from the two facts the config stores. `spawn` alone means
## the value is sent once with the object and never again; the mode number means every frame (always)
## or only when it moves (on change).
static func mode_of(spawns: bool, replication_mode: int) -> String:
	if replication_mode == REPLICATION_ALWAYS:
		return MODE_ALWAYS
	if replication_mode == REPLICATION_ON_CHANGE:
		return MODE_ON_CHANGE
	return MODE_AT_SPAWN if spawns else MODE_OFF


## The word one mode is said in. A table rather than a lookup on the constant, so every spelling the
## canvas draws is a literal the translation gate can see.
static func mode_word(mode: String) -> String:
	match mode:
		MODE_ALWAYS:
			return EventSheetL10n.translate("always")
		MODE_ON_CHANGE:
			return EventSheetL10n.translate("on change")
		MODE_AT_SPAWN:
			return EventSheetL10n.translate("at spawn")
	return EventSheetL10n.translate("off")


## The word a MENU offers one mode under. Longer than the word a row says, because a menu item is
## read cold and out of context - "At spawn only" answers "and then never again?" where "at spawn",
## trailing a list of property names on a row, already has.
static func mode_menu_word(mode: String) -> String:
	match mode:
		MODE_ALWAYS:
			return EventSheetL10n.translate("Always")
		MODE_ON_CHANGE:
			return EventSheetL10n.translate("On change")
		MODE_AT_SPAWN:
			return EventSheetL10n.translate("At spawn only")
	return EventSheetL10n.translate("Off")


## One synchronizer's whole reading, as the head band says it: which properties, in which mode, how
## often, and who sees it - "PlayerSync · position, hp always · nickname at spawn · every 0.05 s ·
## seen by everyone". `entries` is the slice of `synced_in_scene` that belongs to one synchronizer.
static func synchronizer_reading(entries: Array) -> String:
	if entries.is_empty():
		return ""
	var lead: Dictionary = entries[0]
	var parts: PackedStringArray = PackedStringArray([str(lead.get("synchronizer", ""))])
	for mode: String in MODE_ORDER:
		var names: PackedStringArray = PackedStringArray()
		for entry: Variant in entries:
			if str((entry as Dictionary).get("mode", "")) == mode:
				names.append(str((entry as Dictionary).get("name", "")))
		if not names.is_empty():
			parts.append("%s %s" % [", ".join(names), mode_word(mode)])
	var interval: float = float(lead.get("interval", 0.0))
	if interval > 0.0:
		parts.append(EventSheetL10n.translate("every %s s") % String.num(interval, 3).rstrip("0").rstrip("."))
	parts.append(EventSheetL10n.translate("seen by everyone") if bool(lead.get("public_visibility", true))
		else EventSheetL10n.translate("seen by chosen players"))
	return " · ".join(parts)


## The lines of the scene file that reading came from - the band's echo. Nothing here is invented:
## the interval is named only when the file writes one.
static func synchronizer_echo(entries: Array) -> String:
	if entries.is_empty():
		return ""
	var lead: Dictionary = entries[0]
	var interval: float = float(lead.get("interval", 0.0))
	var config: String = "replication_config" if interval <= 0.0 \
		else "replication_config, replication_interval = %s" % String.num(interval, 3).rstrip("0").rstrip(".")
	return "%s: %s \"%s\" (%s)" % [str(lead.get("scene_path", "")).get_file(), SYNCHRONIZER_TYPE,
		str(lead.get("synchronizer", "")), config]


## One spawner's reading - "Spawner in level.tscn · from make_player(data)". The function half is
## dropped when no line of code sets one, because a band never says a thing the project does not.
static func spawner_reading(spawner: Dictionary) -> String:
	var where: String = EventSheetL10n.translate("%s in %s") % [str(spawner.get("name", "")),
		str(spawner.get("scene_path", "")).get_file()]
	var made_by: String = str(spawner.get("spawn_function", "")).strip_edges()
	return where if made_by.is_empty() else "%s · %s" % [where,
		EventSheetL10n.translate("from %s()") % made_by]


## The spawner's own lines of the scene file - its echo. `spawn_limit` is named only when the file
## writes one, which Godot does only when it is not the default.
static func spawner_echo(spawner: Dictionary) -> String:
	var written: PackedStringArray = PackedStringArray(["%s: %s \"%s\"" % [
		str(spawner.get("scene_path", "")).get_file(), SPAWNER_TYPE, str(spawner.get("name", ""))]])
	var spawn_path: String = str(spawner.get("spawn_path", "")).strip_edges()
	if not spawn_path.is_empty():
		written.append("spawn_path = \"%s\"" % spawn_path)
	var limit: int = int(spawner.get("spawn_limit", 0))
	if limit > 0:
		written.append("spawn_limit = %d" % limit)
	return ", ".join(written)


## The whole sentence a sync mark's hover says: which synchronizer keeps this value in step, and how.
static func mark_hover(entry: Dictionary) -> String:
	return "%s · %s" % [str(entry.get("synchronizer", "")), mode_word(str(entry.get("mode", "")))]


## The entries of one list grouped by the synchronizer that holds them, in the order the scene writes
## them: `{"Scene|Node": Array}`. The head builds one band per key, because one band is one fact.
static func by_synchronizer(entries: Array) -> Dictionary:
	var grouped: Dictionary = {}
	for entry: Variant in entries:
		var record: Dictionary = entry
		var key: String = "%s|%s" % [str(record.get("scene_path", "")), str(record.get("synchronizer_path", ""))]
		if not grouped.has(key):
			grouped[key] = []
		(grouped[key] as Array).append(record)
	return grouped


## The entry of `entries` that keeps one variable in step, {} when nothing does. What a variable row
## asks before it draws its mark.
static func entry_for(entries: Array, variable_name: String) -> Dictionary:
	var wanted: String = variable_name.strip_edges()
	for entry: Variant in entries:
		if str((entry as Dictionary).get("name", "")) == wanted:
			return entry
	return {}


# ── The scene text, read ───────────────────────────────────────────────────────────────────


## Every `SceneReplicationConfig` of one scene, keyed by its sub-resource id, each as a list of
## `{"path", "node", "property", "mode"}`. The config is a sub-resource written INSIDE the scene, so
## it is read from the same text rather than loaded (a load would need the class, and the reader has
## to answer for a project whose scenes are not imported yet).
static func _replication_configs(scene_path: String) -> Dictionary:
	var configs: Dictionary = {}
	var text: String = FileAccess.get_file_as_string(scene_path)
	if text.is_empty():
		return configs
	var current_id: String = ""
	var records: Dictionary = {}
	for raw_line: String in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.begins_with("["):
			if not current_id.is_empty():
				configs[current_id] = _ordered_records(records)
			records = {}
			current_id = EventSheetSceneConnections.attribute(line, "id") \
				if line.begins_with("[sub_resource ") \
					and EventSheetSceneConnections.attribute(line, "type") == "SceneReplicationConfig" \
				else ""
			continue
		if current_id.is_empty() or not line.begins_with("properties/"):
			continue
		var key: String = line.get_slice(" = ", 0).strip_edges()
		var value: String = line.substr(line.find(" = ") + 3).strip_edges()
		var index: String = key.get_slice("/", 1)
		if not records.has(index):
			records[index] = {"path": "", "spawn": false, "replication_mode": REPLICATION_NEVER}
		var record: Dictionary = records[index]
		match key.get_slice("/", 2):
			"path":
				record["path"] = _node_path_text(value, "")
			"spawn":
				record["spawn"] = value == "true"
			"replication_mode":
				record["replication_mode"] = value.to_int()
	if not current_id.is_empty():
		configs[current_id] = _ordered_records(records)
	return configs


## One config's properties in the order the file numbers them, each split into the node it addresses
## and the property on it (`.:hp` is "the sync root" and "hp").
static func _ordered_records(records: Dictionary) -> Array:
	var indices: Array = records.keys()
	indices.sort_custom(func(left: Variant, right: Variant) -> bool: return str(left).to_int() < str(right).to_int())
	var ordered: Array = []
	for index: Variant in indices:
		var record: Dictionary = records[index]
		var path: String = str(record.get("path", ""))
		if path.is_empty():
			continue
		ordered.append({
			"path": path,
			"node": path.get_slice(":", 0) if path.contains(":") else ".",
			"property": path.get_slice(":", 1) if path.contains(":") else path,
			"mode": mode_of(bool(record.get("spawn", false)), int(record.get("replication_mode", REPLICATION_NEVER))),
		})
	return ordered


## A node path walked from where it is written, in the same "." / "A/B" spelling `nodes_of_scene`
## uses. `..` above the root stays at the root: a scene cannot address its own parent, so the honest
## answer there is the root itself rather than a path nothing in this file has.
static func resolve_path(base: String, relative: String) -> String:
	var segments: PackedStringArray = PackedStringArray()
	if base != "." and not base.strip_edges().is_empty():
		segments = base.split("/")
	for step: String in relative.split("/"):
		if step.is_empty() or step == ".":
			continue
		if step == "..":
			if not segments.is_empty():
				segments.remove_at(segments.size() - 1)
			continue
		segments.append(step)
	return "/".join(segments) if not segments.is_empty() else "."


## The text inside `NodePath("...")`, or `fallback` when the property is not written at all.
static func _node_path_text(value: String, fallback: String) -> String:
	var written: String = value.strip_edges()
	if written.is_empty():
		return fallback
	if not written.begins_with("NodePath("):
		return written.trim_prefix("\"").trim_suffix("\"")
	return written.get_slice("\"", 1) if written.contains("\"") else fallback


## The scenes inside `PackedStringArray("res://a.tscn", "res://b.tscn")`.
static func _spawnable_scenes(value: String) -> PackedStringArray:
	var scenes: PackedStringArray = PackedStringArray()
	var written: String = value.strip_edges()
	if not written.begins_with("PackedStringArray("):
		return scenes
	var quoted: PackedStringArray = written.split("\"")
	for index: int in range(1, quoted.size(), 2):
		var scene: String = quoted[index].strip_edges()
		if not scene.is_empty():
			scenes.append(scene)
	return scenes


## The id inside `SubResource("SceneReplicationConfig_x")`, "" when the property names none.
static func _sub_resource_id(value: String) -> String:
	var written: String = value.strip_edges()
	return written.get_slice("\"", 1) if written.begins_with("SubResource(") and written.contains("\"") else ""


# ── Writing, through the editor ────────────────────────────────────────────────────────────


## Puts one property in one mode on a live config. PURE - the caller owns the undo - and the ONE
## place the three modes are turned back into Godot's two facts, so nothing else has to know that
## "at spawn" is a `spawn` flag with the mode set to never. True when the config now says that.
static func apply_mode(config: SceneReplicationConfig, property_path: NodePath, mode: String) -> bool:
	if config == null:
		return false
	var listed: bool = config.get_properties().has(property_path)
	if mode == MODE_OFF:
		if listed:
			config.remove_property(property_path)
		return true
	if not listed:
		config.add_property(property_path)
	# Every kept property is sent with the object it belongs to - the Replication panel ticks Spawn
	# for all three, and a value that arrives blank and fills in a frame later is a flicker nobody
	# asked for. The mode number is what tells "at spawn" from the two that keep going.
	config.property_set_spawn(property_path, true)
	config.property_set_replication_mode(property_path, _replication_mode(mode))
	return true


## The number Godot stores for one of the words a row says.
static func _replication_mode(mode: String) -> int:
	match mode:
		MODE_ALWAYS:
			return REPLICATION_ALWAYS
		MODE_ON_CHANGE:
			return REPLICATION_ON_CHANGE
	return REPLICATION_NEVER


## Keeps one property of one node in step, or stops. The write goes through the SCENE: the node is
## found in the open scene, its config is duplicated, the new one is set through the editor's undo
## manager, and the scene is marked unsaved - so Ctrl+Z takes it back and the Replication panel shows
## it immediately. Returns `{"ok", "reason"}`; the reason is a sentence for the status line.
##
## Refused outside the editor, and refused when the scene holding the synchronizer is not the scene
## being edited: writing into a file somebody is not looking at is how two editors of the same fact
## end up disagreeing.
static func write_mode(scene_path: String, synchronizer_path: String, property_path: String,
		mode: String) -> Dictionary:
	if not Engine.is_editor_hint():
		return {"ok": false, "reason": EventSheetL10n.translate("The scene is only editable inside the editor.")}
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path != scene_path:
		return {"ok": false, "reason": EventSheetL10n.translate("Open %s to change what it keeps in step.")
			% scene_path.get_file()}
	var synchronizer: Node = root if synchronizer_path == "." else root.get_node_or_null(NodePath(synchronizer_path))
	if not (synchronizer is MultiplayerSynchronizer):
		return {"ok": false, "reason": EventSheetL10n.translate("%s is not in the open scene any more.")
			% synchronizer_path}
	var current: SceneReplicationConfig = (synchronizer as MultiplayerSynchronizer).replication_config
	# A duplicate, because the config is a resource the scene shares: editing it in place would
	# change every node pointing at it and leave the undo step holding the object it just edited.
	var written: SceneReplicationConfig = current.duplicate(true) if current != null else SceneReplicationConfig.new()
	if not apply_mode(written, NodePath(property_path), mode):
		return {"ok": false, "reason": EventSheetL10n.translate("%s cannot be kept in step.") % property_path}
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if undo == null:
		(synchronizer as MultiplayerSynchronizer).replication_config = written
	else:
		undo.create_action(EventSheetL10n.translate("Keep %s in step") % property_path)
		undo.add_do_property(synchronizer, "replication_config", written)
		undo.add_undo_property(synchronizer, "replication_config", current)
		undo.commit_action()
	EditorInterface.mark_scene_as_unsaved()
	clear_cache()
	return {"ok": true, "reason": ""}


## Adds a `MultiplayerSynchronizer` under the node a scene runs this script on, so a project that
## has none can be given one from the row that wanted it. Through the scene's undo like every other
## write here, and named after the node it syncs, which is the name every tutorial gives it.
## Returns `{"ok", "reason", "name"}`.
static func add_synchronizer(scene_path: String, node_path: String) -> Dictionary:
	if not Engine.is_editor_hint():
		return {"ok": false, "reason": EventSheetL10n.translate("The scene is only editable inside the editor."), "name": ""}
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path != scene_path:
		return {"ok": false, "reason": EventSheetL10n.translate("Open %s to change what it keeps in step.")
			% scene_path.get_file(), "name": ""}
	var host: Node = root if node_path == "." else root.get_node_or_null(NodePath(node_path))
	if host == null:
		return {"ok": false, "reason": EventSheetL10n.translate("%s is not in the open scene any more.")
			% node_path, "name": ""}
	var added := MultiplayerSynchronizer.new()
	added.name = "%sSync" % host.name
	added.replication_config = SceneReplicationConfig.new()
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if undo == null:
		host.add_child(added)
		added.owner = root
	else:
		undo.create_action(EventSheetL10n.translate("Add a synchronizer to %s") % host.name)
		undo.add_do_method(host, "add_child", added)
		undo.add_do_method(added, "set_owner", root)
		undo.add_do_reference(added)
		undo.add_undo_method(host, "remove_child", added)
		undo.commit_action()
	EditorInterface.mark_scene_as_unsaved()
	clear_cache()
	return {"ok": true, "reason": "", "name": added.name}


## Opens the scene holding a node and selects it, which is where Godot's own Replication panel and
## Inspector are - the gesture both scene bands offer, because both mean "the other editor of this
## fact is over there". False outside the editor, or when the node is gone.
static func reveal_node(scene_path: String, node_path: String) -> bool:
	if not Engine.is_editor_hint() or scene_path.strip_edges().is_empty():
		return false
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null or root.scene_file_path != scene_path:
		EditorInterface.open_scene_from_path(scene_path)
		root = EditorInterface.get_edited_scene_root()
	if root == null:
		return false
	var node: Node = root if node_path == "." else root.get_node_or_null(NodePath(node_path))
	if node == null:
		return false
	var selection: EditorSelection = EditorInterface.get_selection()
	if selection != null:
		selection.clear()
		selection.add_node(node)
	return true
