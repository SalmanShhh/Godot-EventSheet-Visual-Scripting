# Pack builder - named_scenes (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")

const PACK_ICON := "res://eventsheet_addons/named_scenes/icon.svg"


## Named Scenes: a scene registry as an AUTOLOAD sheet (NamedScenes), so rows stop carrying res://
## paths. Register "arena" once and every row afterwards says Go To Named Scene "arena"; move or
## rename the .tscn and only the registration changes.
##  - A record can ride along to the next scene (Carry Into Next Scene), which is the clean answer to
##    "which door did I come in by" that otherwise sends everybody to a hand-written autoload.
##  - The addressing family the sheets lack: a Current Scene Is condition, an On Scene Ready trigger
##    carrying the name as its argument, and Scene Argument for reading the handoff.
##  - Preload Named Scene warms a scene while the player is still reading a hint, so the change is
##    instant when it comes.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.autoload_mode = true
	sheet.autoload_name = "NamedScenes"
	sheet.host_class = "Node"
	sheet.custom_class_name = "NamedScenesPackAddon"
	sheet.class_description = "A scene registry as the NamedScenes autoload singleton: give each .tscn a short name once, and every row afterwards addresses it by that name instead of by a res:// path. Carry Into Next Scene hands a record to the scene you are opening, On Scene Ready fires with the name once it is running, and Current Scene Is answers which one you are in."
	sheet.addon_category = "Scenes"
	sheet.addon_tags = PackedStringArray(["scenes", "navigation", "levels"])
	var about: CommentRow = CommentRow.new()
	about.text = "Named Scenes: register as the NamedScenes autoload. Register Scene (or Register Scenes In Folder) once at boot, then say Go To Named Scene \"arena\" everywhere else. Carry Into Next Scene passes a record across the change, read back with Scene Argument. This pack is an event sheet - extend it by editing it."
	sheet.events.append(about)

	# The trigger carries the scene NAME as its argument, so a listener row reads which scene became
	# ready without asking a second question.
	var ready_signal: SignalRow = SignalRow.new()
	ready_signal.signal_name = "scene_ready"
	ready_signal.params = PackedStringArray(["scene_name: String"])
	ready_signal.trigger = true
	ready_signal.ace_name = "On Scene Ready"
	ready_signal.ace_category = "Scenes"
	sheet.events.append(ready_signal)

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"# scene name -> the res:// path of its .tscn. The whole point of the pack: one place that",
		"# knows where a level lives, so no row ever has to.",
		"var _registry: Dictionary = {}",
		"# scene name -> an already-loaded PackedScene, warmed by Preload Named Scene.",
		"var _preloaded: Dictionary = {}",
		"# The record Carry Into Next Scene left for the scene that has not opened yet.",
		"var _pending_handoff: Dictionary = {}",
		"# The record belonging to the scene running right now - what Scene Argument reads.",
		"var _handoff: Dictionary = {}",
		"# The name of the scene most recently announced ready, or \"\" before the first one.",
		"var _current_name: String = \"\""
	]))
	sheet.events.append(block)

	# --- The registry ---
	Lib.append_function(sheet, "register_scene", "Register Scene", "Scenes", "Gives a scene file a short name every row can use instead of its path. Registering the same name again replaces the path, so a boot sheet can safely re-run. Do this once at startup, in a sheet every scene reaches.",
		[["scene_name", "String"], ["scene_path", "String"]],
		"\n".join(PackedStringArray([
			"if scene_name.is_empty() or scene_path.is_empty():",
			"\tpush_warning(\"Named Scenes: Register Scene needs both a name and a .tscn path.\")",
			"\treturn",
			"_registry[scene_name] = scene_path"
		])))
	Lib.append_function(sheet, "register_scenes_in_folder", "Register Scenes In Folder", "Scenes", "Registers every .tscn directly inside a folder under its own file name, so res://levels/arena.tscn becomes \"arena\". The folder IS the level list: add a scene to it and the game knows about it with no row to edit. Sub-folders are left alone.",
		[["folder", "String"]],
		"\n".join(PackedStringArray([
			"var directory: DirAccess = DirAccess.open(folder)",
			"if directory == null:",
			"\tpush_warning(\"Named Scenes: no folder at '%s'.\" % folder)",
			"\treturn",
			"for file_name: String in directory.get_files():",
			"\tif not file_name.ends_with(\".tscn\"):",
			"\t\tcontinue",
			"\t_registry[file_name.get_basename()] = folder.path_join(file_name)"
		])))
	Lib.append_function(sheet, "forget_named_scene", "Forget Named Scene", "Scenes", "Removes one name from the registry and drops anything Preload Named Scene had warmed for it. Use it when a level is unlocked or retired at runtime; rows that still name it will warn instead of changing scene.",
		[["scene_name", "String"]],
		"_registry.erase(scene_name)\n_preloaded.erase(scene_name)")

	# --- Going somewhere ---
	Lib.append_function(sheet, "go_to_named_scene", "Go To Named Scene", "Scenes", "Changes to the scene registered under this name. Nothing happens (with a warning) if the name was never registered, or if the file behind it can no longer be opened, so neither a typo nor a moved .tscn can leave the game on a black screen. On Scene Ready fires with the name only once the new scene is really the one running.",
		[["scene_name", "String"]],
		"\n".join(PackedStringArray([
			"var path: String = str(_registry.get(scene_name, \"\"))",
			"if path.is_empty():",
			"\tpush_warning(\"Named Scenes: no scene is registered as '%s'.\" % scene_name)",
			"\treturn",
			"if not is_inside_tree():",
			"\treturn",
			"# Remember WHICH scene is running before asking for the change: waiting for current_scene to",
			"# be merely non-null would fall straight through, because the outgoing scene is still there.",
			"var leaving_id: int = get_tree().current_scene.get_instance_id() if get_tree().current_scene != null else 0",
			"if get_tree().change_scene_to_file(path) != OK:",
			"\t# A registered path whose .tscn has since been moved or broken. Announcing readiness here",
			"\t# would run the new scene's setup rows against the scene that is still on screen.",
			"\tpush_warning(\"Named Scenes: '%s' is registered as %s, but that scene could not be opened.\" % [scene_name, path])",
			"\treturn",
			"# change_scene_to_file is deferred to the end of the frame, so the new scene is not there",
			"# yet. Waiting for a DIFFERENT current_scene is what makes On Scene Ready honest.",
			"await get_tree().process_frame",
			"while get_tree().current_scene == null or get_tree().current_scene.get_instance_id() == leaving_id:",
			"\tawait get_tree().process_frame",
			"announce_scene_ready(scene_name)"
		])))
	Lib.append_function(sheet, "preload_named_scene", "Preload Named Scene", "Scenes", "Loads a registered scene into memory now, without changing to it, so the change is instant when it comes. Warm the next level while the player is reading a hint or watching a door open. Loading it twice does no extra work.",
		[["scene_name", "String"]],
		"\n".join(PackedStringArray([
			"if _preloaded.has(scene_name):",
			"\treturn",
			"var path: String = str(_registry.get(scene_name, \"\"))",
			"if path.is_empty():",
			"\tpush_warning(\"Named Scenes: no scene is registered as '%s'.\" % scene_name)",
			"\treturn",
			"var packed: Resource = ResourceLoader.load(path)",
			"if packed == null:",
			"\tpush_warning(\"Named Scenes: '%s' could not be loaded from %s.\" % [scene_name, path])",
			"\treturn",
			"_preloaded[scene_name] = packed"
		])))
	Lib.append_function(sheet, "carry_into_next_scene", "Carry Into Next Scene", "Scenes", "Hands a record to the scene you are about to open: a spawn door, a difficulty, who sent you. It belongs to the NEXT scene, so the one you are leaving still reads its own arguments until the change lands.",
		[["payload", "Dictionary"]],
		"_pending_handoff = payload.duplicate(true)")
	Lib.append_function(sheet, "announce_scene_ready", "Announce Scene Ready", "Scenes", "Marks a named scene as the one now running: the carried record becomes readable through Scene Argument, Current Scene Is starts answering this name, and On Scene Ready fires with it. Go To Named Scene calls this for you once the new scene exists - call it yourself only when you changed scene some other way.",
		[["scene_name", "String"]],
		"\n".join(PackedStringArray([
			"_current_name = scene_name",
			"_handoff = _pending_handoff.duplicate(true)",
			"_pending_handoff = {}",
			"scene_ready.emit(scene_name)"
		])))

	# --- Conditions ---
	Lib.condition(sheet, "current_scene_is", "Current Scene Is", "Scenes", "Whether the named scene is the one running right now. It answers on the name last announced ready, so it keeps working for a scene you loaded by hand as long as Announce Scene Ready was called.", [["scene_name", "String"]],
		"return _current_name == scene_name")
	Lib.condition(sheet, "scene_is_registered", "Scene Is Registered", "Scenes", "Whether a name has a scene behind it. Ask before Go To Named Scene when the name comes from data (a level list, a save file) rather than from a row you typed.", [["scene_name", "String"]],
		"return _registry.has(scene_name)")
	Lib.condition(sheet, "named_scene_is_preloaded", "Named Scene Is Preloaded", "Scenes", "Whether Preload Named Scene has already warmed this scene. Show the Continue button when it has, a spinner while it has not.", [["scene_name", "String"]],
		"return _preloaded.has(scene_name)")
	Lib.condition(sheet, "has_scene_argument", "Has Scene Argument", "Scenes", "Whether the scene you are in was handed a value under this key. Lets a level tell \"came in by a door\" apart from \"started here from the menu\" without a magic default.", [["key", "String"]],
		"return _handoff.has(key)")

	# --- Expressions ---
	Lib.number(sheet, "scene_argument", "Scene Argument", "Scenes", "A value the previous scene carried over, as text - the door you came in by, who sent you. Answers the fallback when nothing was carried under that key.", [["key", "String"], ["fallback", "String"]],
		"return str(_handoff.get(key, fallback))", TYPE_STRING)
	Lib.number(sheet, "scene_argument_number", "Scene Argument Number", "Scenes", "A carried value as a number - an attempt count, a difficulty, a starting score. Answers the fallback when nothing was carried under that key.", [["key", "String"], ["fallback", "float"]],
		"return float(_handoff.get(key, fallback))", TYPE_FLOAT)
	Lib.number(sheet, "path_of_named_scene", "Path Of Named Scene", "Scenes", "The res:// path registered under a name, or \"\" when the name is unknown. The escape hatch for an action that still wants a path, e.g. the Scene Flow pack's Fade To Scene.", [["scene_name", "String"]],
		"return str(_registry.get(scene_name, \"\"))", TYPE_STRING)
	Lib.number(sheet, "current_scene_name", "Current Scene Name", "Scenes", "The name of the scene running right now, or \"\" before the first one was announced. Stabler than a path: save it, show it in a debug corner, key a music track off it.", [],
		"return _current_name", TYPE_STRING)
	Lib.number(sheet, "registered_scene_names", "Registered Scene Names", "Scenes", "Every registered name, sorted. A level-select screen builds itself from this instead of from a list somebody has to keep in step.", [],
		"var names: Array = _registry.keys()\nnames.sort()\nreturn names", TYPE_ARRAY)

	# Save-state seam - deliberately unpublished; the Save System provides the user-facing actions.
	var persistence: RawCodeRow = RawCodeRow.new()
	persistence.code = "\n".join(PackedStringArray([
		"# Save-state seam: the Save System walks any node in its persist group (or targeted by",
		"# Save/Load Node State) and duck-types these two methods. Plain data only - the loaded",
		"# PackedScenes are a memory warm-up belonging to this run, so they are left out.",
		"## @ace_hidden",
		"func save_state() -> Dictionary:",
		"\treturn {",
		"\t\t\"registry\": _registry.duplicate(true),",
		"\t\t\"current\": _current_name,",
		"\t\t\"handoff\": _handoff.duplicate(true)",
		"\t}",
		"",
		"## @ace_hidden",
		"func load_state(state: Dictionary) -> void:",
		"\tif state.is_empty():",
		"\t\treturn",
		"\t_registry = (state.get(\"registry\", {}) as Dictionary).duplicate(true)",
		"\t_current_name = str(state.get(\"current\", \"\"))",
		"\t_handoff = (state.get(\"handoff\", {}) as Dictionary).duplicate(true)"
	]))
	sheet.events.append(persistence)

	Lib.verb_sentences(sheet, {
		"register_scene": "Register scene [b]{scene_name}[/b] = [b]{scene_path}[/b]",
		"go_to_named_scene": "Go to scene named [b]{scene_name}[/b]",
		"preload_named_scene": "Preload scene named [b]{scene_name}[/b]",
		"carry_into_next_scene": "Carry [b]{payload}[/b] into the next scene",
	})
	Lib.feature_verbs(sheet, ["register_scene", "go_to_named_scene"])
	_set_defaults(sheet, "register_scene", {"scene_name": "\"arena\"", "scene_path": "\"\""}, {"scene_path": "scene_path"})
	_set_defaults(sheet, "register_scenes_in_folder", {"folder": "\"res://levels\""})
	_set_defaults(sheet, "forget_named_scene", {"scene_name": "\"arena\""})
	_set_defaults(sheet, "go_to_named_scene", {"scene_name": "\"arena\""})
	_set_defaults(sheet, "preload_named_scene", {"scene_name": "\"arena\""})
	_set_defaults(sheet, "carry_into_next_scene", {"payload": "{}"}, {"payload": "expression"})
	_set_defaults(sheet, "announce_scene_ready", {"scene_name": "\"arena\""})
	_set_defaults(sheet, "current_scene_is", {"scene_name": "\"hub\""})
	_set_defaults(sheet, "scene_is_registered", {"scene_name": "\"arena\""})
	_set_defaults(sheet, "named_scene_is_preloaded", {"scene_name": "\"arena\""})
	_set_defaults(sheet, "has_scene_argument", {"key": "\"door\""})
	_set_defaults(sheet, "scene_argument", {"key": "\"door\"", "fallback": "\"\""})
	_set_defaults(sheet, "scene_argument_number", {"key": "\"attempt\"", "fallback": "0.0"})
	_set_defaults(sheet, "path_of_named_scene", {"scene_name": "\"arena\""})
	return Lib.save_pack(sheet, "res://eventsheet_addons/named_scenes/named_scenes_addon", PACK_ICON)


## Gives an exposed verb's parameters GDScript defaults (which become the row's pre-filled cells,
## since the emitted pack carries no separate picker default) and optional widget hints.
static func _set_defaults(sheet: EventSheetResource, function_name: String, defaults: Dictionary, hints: Dictionary = {}) -> void:
	for function_resource: Resource in sheet.functions:
		if not (function_resource is EventFunction) or (function_resource as EventFunction).function_name != function_name:
			continue
		for parameter: ACEParam in (function_resource as EventFunction).params:
			if defaults.has(parameter.id):
				parameter.gdscript_default = str(defaults[parameter.id])
			if hints.has(parameter.id):
				parameter.hint = str(hints[parameter.id])
		return
	push_warning("_set_defaults: no function named %s on this sheet (typo?)" % function_name)
