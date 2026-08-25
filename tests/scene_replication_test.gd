# The scene seam: what a `.tscn` says about keeping a game in step, read back.
#
# The facts this covers are not in any script, so a fixture SCENE is the only honest input:
# tests/fixtures/multiplayer_scene_player.tscn keeps four properties of a player in step (two always,
# one on change, one at spawn only) at 0.05 s, and tests/fixtures/multiplayer_scene_level.tscn holds
# the spawner that can make it, with the `spawn_function` its own script hands over.
#
# Pinned by VALUE, because every one of these is a fact a row shows a reader: which properties, in
# which mode, how often, seen by whom, from which spawner and which factory - plus the readings and
# the echoes composed out of them, the public API's two calls, and the config rewrite behind "Keep in
# step". A variable the scene says nothing about must come back with nothing, which is the half that
# keeps the mark off every ordinary row in every single-player project.
@tool
class_name SceneReplicationTest
extends RefCounted

const PLAYER_SCRIPT: String = "res://tests/fixtures/multiplayer_scene_player.gd"
const PLAYER_SCENE: String = "res://tests/fixtures/multiplayer_scene_player.tscn"
const LEVEL_SCRIPT: String = "res://tests/fixtures/multiplayer_scene_level.gd"
const LEVEL_SCENE: String = "res://tests/fixtures/multiplayer_scene_level.tscn"


static func run() -> bool:
	EventSheetSceneReplication.clear_cache()
	var ok: bool = true
	ok = _test_modes() and ok
	ok = _test_paths() and ok
	ok = _test_the_player_scene() and ok
	ok = _test_the_spawner() and ok
	ok = _test_the_readings() and ok
	ok = _test_the_public_api() and ok
	ok = _test_the_head_bands() and ok
	ok = _test_writing_a_mode() and ok
	ok = _test_the_scene_the_editor_holds() and ok
	ok = _test_a_scene_that_says_nothing() and ok
	EventSheetSceneReplication.clear_cache()
	return ok


## The two stored facts turned into the three words the Replication panel offers. `spawn` alone is
## "at spawn"; a mode number outranks it, because a property that keeps going was already sent once.
static func _test_modes() -> bool:
	var ok: bool = _check("always", EventSheetSceneReplication.mode_of(true,
		EventSheetSceneReplication.REPLICATION_ALWAYS), EventSheetSceneReplication.MODE_ALWAYS)
	ok = _check("on change", EventSheetSceneReplication.mode_of(true,
		EventSheetSceneReplication.REPLICATION_ON_CHANGE), EventSheetSceneReplication.MODE_ON_CHANGE) and ok
	ok = _check("at spawn", EventSheetSceneReplication.mode_of(true,
		EventSheetSceneReplication.REPLICATION_NEVER), EventSheetSceneReplication.MODE_AT_SPAWN) and ok
	ok = _check("neither is not kept in step at all", EventSheetSceneReplication.mode_of(false,
		EventSheetSceneReplication.REPLICATION_NEVER), EventSheetSceneReplication.MODE_OFF) and ok
	return ok


## Walking a node path from where it is written. The default `..` on a synchronizer means its parent,
## which is why a scene that writes no `root_path` still syncs the root.
static func _test_paths() -> bool:
	var ok: bool = _check("a child's parent is the root",
		EventSheetSceneReplication.resolve_path("PlayerSync", ".."), ".")
	ok = _check("a sibling is addressed through the parent",
		EventSheetSceneReplication.resolve_path("Rig/Sync", "../Body"), "Rig/Body") and ok
	ok = _check("`.` stays where it is",
		EventSheetSceneReplication.resolve_path("Rig/Sync", "."), "Rig/Sync") and ok
	ok = _check("above the root is still the root",
		EventSheetSceneReplication.resolve_path(".", "../.."), ".") and ok
	return ok


## The player scene, property by property: the name a row shows, the mode, and the facts the whole
## synchronizer carries.
static func _test_the_player_scene() -> bool:
	var synced: Array = EventSheetSceneReplication.synced_in_scene(PLAYER_SCENE, PLAYER_SCRIPT)
	var modes: Dictionary = {}
	for entry: Variant in synced:
		modes[str((entry as Dictionary).get("name", ""))] = str((entry as Dictionary).get("mode", ""))
	var ok: bool = _check("every kept property is read, in the order the config numbers them",
		_names(synced), PackedStringArray(["position", "hp", "stamina", "nickname"]))
	ok = _check("the modes are the three the panel offers", modes, {
		"position": EventSheetSceneReplication.MODE_ALWAYS,
		"hp": EventSheetSceneReplication.MODE_ALWAYS,
		"stamina": EventSheetSceneReplication.MODE_ON_CHANGE,
		"nickname": EventSheetSceneReplication.MODE_AT_SPAWN,
	}) and ok
	var hp: Dictionary = EventSheetSceneReplication.entry_for(synced, "hp")
	ok = _check("the synchronizer names itself", str(hp.get("synchronizer", "")), "PlayerSync") and ok
	ok = _check("and says where it is", str(hp.get("synchronizer_path", "")), "PlayerSync") and ok
	ok = _check("the property keeps its NodePath spelling", str(hp.get("property_path", "")), ".:hp") and ok
	ok = _check("the node it belongs to is the scene root", str(hp.get("node_path", "")), ".") and ok
	ok = _check("the interval is the file's", float(hp.get("interval", 0.0)), 0.05) and ok
	ok = _check("an unwritten public_visibility means everyone",
		bool(hp.get("public_visibility", false)), true) and ok
	ok = _check("a variable the scene says nothing about has no entry",
		EventSheetSceneReplication.entry_for(synced, "armour"), {}) and ok
	return ok


## The spawner: read from the scene for everything Godot stores there, and from the SCRIPT for the
## one thing it never stores - the callable.
static func _test_the_spawner() -> bool:
	var spawners: Array = EventSheetSceneReplication.spawners_in_scene(LEVEL_SCENE)
	var ok: bool = _check("the level has one spawner", spawners.size(), 1)
	if spawners.is_empty():
		return false
	var spawner: Dictionary = spawners[0]
	ok = _check("named as the scene names it", str(spawner.get("name", "")), "Spawner") and ok
	ok = _check("with the path it puts them on", str(spawner.get("spawn_path", "")), "../Players") and ok
	ok = _check("and the limit the file writes", int(spawner.get("spawn_limit", 0)), 4) and ok
	ok = _check("the scenes it can make", spawner.get("scenes", PackedStringArray()),
		PackedStringArray([PLAYER_SCENE])) and ok
	ok = _check("the factory comes from the script, because a .tscn cannot hold a Callable",
		str(spawner.get("spawn_function", "")), "spawn_player") and ok
	ok = _check("a bare assignment is a name", EventSheetSceneReplication.spawn_function_in_source(
		"func _ready() -> void:\n\tspawn_function = make_player\n", "Spawner"), "make_player") and ok
	ok = _check("and so is the quoted Callable spelling", EventSheetSceneReplication.spawn_function_in_source(
		"$Spawner.spawn_function = Callable(self, \"make_player\")\n", "Spawner"), "make_player") and ok
	ok = _check("a line addressing another spawner is not this one's",
		EventSheetSceneReplication.spawn_function_in_source(
			"$Other.spawn_function = make_enemy\n", "Spawner"), "") and ok
	ok = _check("and an expression is not a name a row could show",
		EventSheetSceneReplication.spawn_function_in_source(
			"spawn_function = make_player.bind(2)\n", "Spawner"), "") and ok
	return ok


## The sentences the head bands say, and the lines of the files they came from.
static func _test_the_readings() -> bool:
	var synced: Array = EventSheetSceneReplication.synced_in_scene(PLAYER_SCENE, PLAYER_SCRIPT)
	var grouped: Dictionary = EventSheetSceneReplication.by_synchronizer(synced)
	var ok: bool = _check("one band per synchronizer", grouped.size(), 1)
	var entries: Array = grouped.values()[0] if not grouped.is_empty() else []
	ok = _check("the reading says which, in what mode, how often and who sees it",
		EventSheetSceneReplication.synchronizer_reading(entries),
		"PlayerSync · position, hp always · stamina on change · nickname at spawn · every 0.05 s · seen by everyone") and ok
	ok = _check("the echo is the scene's own lines",
		EventSheetSceneReplication.synchronizer_echo(entries),
		"multiplayer_scene_player.tscn: MultiplayerSynchronizer \"PlayerSync\" (replication_config, replication_interval = 0.05)") and ok
	ok = _check("the mark's hover names the synchronizer and the mode",
		EventSheetSceneReplication.mark_hover(EventSheetSceneReplication.entry_for(synced, "nickname")),
		"PlayerSync · at spawn") and ok
	var spawner: Dictionary = (EventSheetSceneReplication.spawners_in_scene(LEVEL_SCENE))[0]
	ok = _check("the spawner reads as where it is and what it calls",
		EventSheetSceneReplication.spawner_reading(spawner),
		"Spawner in multiplayer_scene_level.tscn · from spawn_player()") and ok
	ok = _check("and echoes its own properties",
		EventSheetSceneReplication.spawner_echo(spawner),
		"multiplayer_scene_level.tscn: MultiplayerSpawner \"Spawner\", spawn_path = \"../Players\", spawn_limit = 4") and ok
	ok = _check("a spawner nothing hands a factory drops that half",
		EventSheetSceneReplication.spawner_reading({"name": "Pool", "scene_path": "res://a.tscn"}),
		"Pool in a.tscn") and ok
	return ok


## The two calls the API publishes, answered off a sheet rather than off a path - which is the whole
## point of them, because a pack holds a sheet and not a script path.
static func _test_the_public_api() -> bool:
	var player: EventSheetResource = EventSheets.new_sheet({"class_name": "Player"})
	player.external_source_path = PLAYER_SCRIPT
	var synced: Array[Dictionary] = EventSheets.synced_properties(player)
	var ok: bool = _check("the sheet's own kept properties", _names(synced),
		PackedStringArray(["position", "hp", "stamina", "nickname"]))
	var spawners: Array[Dictionary] = EventSheets.spawners_of(player)
	ok = _check("one spawner is about this sheet", spawners.size(), 1) and ok
	ok = _check("and it is one somewhere else that can make it",
		str(spawners[0].get("relation", "")) if not spawners.is_empty() else "",
		EventSheetSceneReplication.RELATION_SPAWNS_THIS) and ok
	var level: EventSheetResource = EventSheets.new_sheet({"class_name": "Level"})
	level.external_source_path = LEVEL_SCRIPT
	var own: Array[Dictionary] = EventSheets.spawners_of(level)
	ok = _check("the level's own spawner is in its own scene",
		str(own[0].get("relation", "")) if not own.is_empty() else "",
		EventSheetSceneReplication.RELATION_IN_SCENE) and ok
	ok = _check("and the level keeps nothing in step",
		EventSheets.synced_properties(level).size(), 0) and ok
	ok = _check("a sheet with no file behind it answers with nothing",
		EventSheets.synced_properties(EventSheets.new_sheet({})).size(), 0) and ok
	ok = _check("and so does no sheet at all", EventSheets.spawners_of(null).size(), 0) and ok
	return ok


## The head: one band per synchronizer, one per spawner that can make this scene, in the order the
## stack reads - and NONE of either on a sheet no scene runs, which is the half that keeps every
## single-player head exactly as it was.
static func _test_the_head_bands() -> bool:
	var player: EventSheetResource = EventSheets.new_sheet({"class_name": "Player"})
	player.external_source_path = PLAYER_SCRIPT
	var facts: Dictionary = EventSheetHeadBands.facts(player, "class_name Player
extends CharacterBody2D")
	facts.merge(EventSheetHeadBands.scene_facts(player), true)
	var kinds: PackedStringArray = PackedStringArray()
	var bands: Array[Dictionary] = EventSheetHeadBands.bands(facts)
	for band: Dictionary in bands:
		kinds.append(str(band.get("kind", "")))
	var ok: bool = _check("the scene's bands sit after the file's own, in reading order", kinds,
		PackedStringArray([EventSheetHeadBands.BAND_NAME, EventSheetHeadBands.BAND_EXTENDS,
			EventSheetHeadBands.BAND_SYNC, EventSheetHeadBands.BAND_SPAWNED]))
	var sync_band: Dictionary = _band(bands, EventSheetHeadBands.BAND_SYNC)
	ok = _check("the keeps-in-step band says the whole reading", str(sync_band.get("value", "")),
		"PlayerSync · position, hp always · stamina on change · nickname at spawn · every 0.05 s · seen by everyone") and ok
	ok = _check("and echoes the scene's lines", str(sync_band.get("echo", "")),
		"multiplayer_scene_player.tscn: MultiplayerSynchronizer \"PlayerSync\" (replication_config, replication_interval = 0.05)") and ok
	ok = _check("its control opens the editor that owns the fact", str(sync_band.get("control", "")),
		EventSheetL10n.translate("Replication panel…")) and ok
	ok = _check("and it names the node that gesture is about", str(sync_band.get("reference", "")),
		"%s|PlayerSync" % PLAYER_SCENE) and ok
	var spawned_band: Dictionary = _band(bands, EventSheetHeadBands.BAND_SPAWNED)
	ok = _check("the spawned-by band names the spawner and its scene", str(spawned_band.get("value", "")),
		"Spawner in multiplayer_scene_level.tscn · from spawn_player()") and ok
	ok = _check("and points at the spawner itself", str(spawned_band.get("reference", "")),
		"%s|Spawner" % LEVEL_SCENE) and ok
	# A sheet with no scene behind it: the head is exactly what it was before any of this shipped.
	var lonely: EventSheetResource = EventSheets.new_sheet({"class_name": "Lonely"})
	lonely.external_source_path = "res://tests/fixtures/multiplayer_player_messages.gd"
	var quiet: Dictionary = EventSheetHeadBands.facts(lonely, "class_name Lonely
extends Node")
	quiet.merge(EventSheetHeadBands.scene_facts(lonely), true)
	var quiet_kinds: PackedStringArray = PackedStringArray()
	for band: Dictionary in EventSheetHeadBands.bands(quiet):
		quiet_kinds.append(str(band.get("kind", "")))
	ok = _check("nothing about the network appears on a head no scene replicates", quiet_kinds,
		PackedStringArray([EventSheetHeadBands.BAND_NAME, EventSheetHeadBands.BAND_EXTENDS])) and ok
	ok = _check("and a band of the file itself carries no reference at all",
		str(_band(EventSheetHeadBands.bands(quiet), EventSheetHeadBands.BAND_NAME).get("reference", "?")), "") and ok
	return ok


static func _band(bands: Array[Dictionary], kind: String) -> Dictionary:
	for band: Dictionary in bands:
		if str(band.get("kind", "")) == kind:
			return band
	return {}


## The write half, on the config itself: the three modes, and off again. The editor's undo owns the
## step in the running editor; this is the rewrite it commits.
static func _test_writing_a_mode() -> bool:
	var config := SceneReplicationConfig.new()
	var path := NodePath(".:hp")
	var ok: bool = _check("keeping a new property in step lists it",
		EventSheetSceneReplication.apply_mode(config, path, EventSheetSceneReplication.MODE_ALWAYS)
			and config.get_properties().has(path), true)
	ok = _check("in the mode that was asked for",
		config.property_get_replication_mode(path), SceneReplicationConfig.REPLICATION_MODE_ALWAYS) and ok
	ok = _check("and sent with the object it belongs to",
		config.property_get_spawn(path), true) and ok
	EventSheetSceneReplication.apply_mode(config, path, EventSheetSceneReplication.MODE_ON_CHANGE)
	ok = _check("changing the mode rewrites it rather than adding a second entry",
		config.get_properties().size(), 1) and ok
	ok = _check("reading it back gives the word that was written",
		EventSheetSceneReplication.mode_of(config.property_get_spawn(path),
			config.property_get_replication_mode(path)), EventSheetSceneReplication.MODE_ON_CHANGE) and ok
	EventSheetSceneReplication.apply_mode(config, path, EventSheetSceneReplication.MODE_AT_SPAWN)
	ok = _check("at spawn is the never mode with the spawn flag",
		EventSheetSceneReplication.mode_of(config.property_get_spawn(path),
			config.property_get_replication_mode(path)), EventSheetSceneReplication.MODE_AT_SPAWN) and ok
	EventSheetSceneReplication.apply_mode(config, path, EventSheetSceneReplication.MODE_OFF)
	ok = _check("off takes it out of the config entirely",
		config.get_properties().size(), 0) and ok
	ok = _check("and off again is still nothing, not an error",
		EventSheetSceneReplication.apply_mode(config, path, EventSheetSceneReplication.MODE_OFF), true) and ok
	ok = _check("outside the editor the scene is not written at all",
		bool(EventSheetSceneReplication.write_mode(PLAYER_SCENE, "PlayerSync", ".:hp",
			EventSheetSceneReplication.MODE_ALWAYS).get("ok", true)), false) and ok
	return ok


## The half that keeps every single-player project exactly as it was: a script no scene replicates
## anything for comes back with nothing at all, so no band, no mark and no menu appear.
static func _test_a_scene_that_says_nothing() -> bool:
	var facts: Dictionary = EventSheetSceneReplication.for_script(
		"res://tests/fixtures/multiplayer_player_messages.gd")
	var ok: bool = _check("nothing is kept in step", (facts.get("synced", []) as Array).size(), 0)
	ok = _check("and no spawner is about it", (facts.get("spawners", []) as Array).size(), 0) and ok
	ok = _check("a path that is not a project script is not looked up either",
		EventSheetSceneReplication.for_script("player.gd"),
		{"synced": [], "spawners": [], "synchronizers": [], "host": {}}) and ok
	return ok


## The scene the EDITOR is holding, which is the one the reader has to answer about: a node added
## since the last save is not in the `.tscn` at all. Without this, "Keep in step" on a project that
## had never replicated anything added the synchronizer, looked for it in the file, did not find it,
## and wrote the mode nowhere with nothing said - and the row's own menu went on offering to add the
## synchronizer it had just added. The live reading is pinned against the text reading first, so the
## two can never drift into two different answers about the same scene.
static func _test_the_scene_the_editor_holds() -> bool:
	var root: Node = (load(PLAYER_SCENE) as PackedScene).instantiate()
	var live: Array = EventSheetSceneReplication.synchronizers_of_root(root, PLAYER_SCRIPT)
	var from_text: Array = EventSheetSceneReplication.synchronizers_in_scene(PLAYER_SCENE, PLAYER_SCRIPT)
	var ok: bool = _check("the live tree names the synchronizer the file does",
		_names(live), _names(from_text))
	var held: Dictionary = live[0] if not live.is_empty() else {}
	var written: Dictionary = from_text[0] if not from_text.is_empty() else {}
	for fact: String in ["node_path", "scene_path", "target_path", "interval", "public_visibility"]:
		ok = _check("...and says the same %s" % fact, held.get(fact), written.get(fact)) and ok
	var live_synced: Array = EventSheetSceneReplication.synced_of_root(root, PLAYER_SCRIPT)
	var text_synced: Array = EventSheetSceneReplication.synced_in_scene(PLAYER_SCENE, PLAYER_SCRIPT)
	ok = _check("the same properties are kept in step", _names(live_synced), _names(text_synced)) and ok
	ok = _check("...in the same modes", _modes(live_synced), _modes(text_synced)) and ok
	# The half the file cannot answer: a synchronizer added a moment ago and not saved yet.
	var added := MultiplayerSynchronizer.new()
	added.name = "ExtraSync"
	added.replication_config = SceneReplicationConfig.new()
	root.add_child(added)
	added.owner = root
	ok = _check("a synchronizer added since the last save is part of the reading",
		_names(EventSheetSceneReplication.synchronizers_of_root(root, PLAYER_SCRIPT)),
		PackedStringArray(["PlayerSync", "ExtraSync"])) and ok
	ok = _check("...and the file still says only what was saved into it",
		_names(EventSheetSceneReplication.synchronizers_in_scene(PLAYER_SCENE, PLAYER_SCRIPT)),
		PackedStringArray(["PlayerSync"])) and ok
	root.free()
	return ok


static func _names(entries: Array) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for entry: Variant in entries:
		names.append(str((entry as Dictionary).get("name", "")))
	return names


## The mode each entry is in, keyed by the property - what a row's mark shows.
static func _modes(entries: Array) -> Dictionary:
	var modes: Dictionary = {}
	for entry: Variant in entries:
		modes[str((entry as Dictionary).get("name", ""))] = str((entry as Dictionary).get("mode", ""))
	return modes


static func _check(label: String, actual: Variant, expected: Variant) -> bool:
	if actual == expected:
		print("[PASS] scene_replication_test: %s" % label)
		return true
	print("[FAIL] scene_replication_test: %s" % label)
	print("  expected: %s" % str(expected))
	print("  actual:   %s" % str(actual))
	return false
