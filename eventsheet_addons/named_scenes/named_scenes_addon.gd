## @ace_tags(scenes, navigation, levels)
## @ace_category("Scenes")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/named_scenes/icon.svg")
class_name NamedScenesPackAddon
extends Node
## A scene registry as the NamedScenes autoload singleton: give each .tscn a short name once, and every row afterwards addresses it by that name instead of by a res:// path. Carry Into Next Scene hands a record to the scene you are opening, On Scene Ready fires with the name once it is running, and Current Scene Is answers which one you are in.

## @ace_trigger
## @ace_name("On Scene Ready")
## @ace_category("Scenes")
signal scene_ready(scene_name: String)

# scene name -> the res:// path of its .tscn. The whole point of the pack: one place that
# knows where a level lives, so no row ever has to.
var _registry: Dictionary = {}
# scene name -> an already-loaded PackedScene, warmed by Preload Named Scene.
var _preloaded: Dictionary = {}
# The record Carry Into Next Scene left for the scene that has not opened yet.
var _pending_handoff: Dictionary = {}
# The record belonging to the scene running right now - what Scene Argument reads.
var _handoff: Dictionary = {}
# The name of the scene most recently announced ready, or "" before the first one.
var _current_name: String = ""

## @ace_action
## @ace_featured
## @ace_name("Register Scene")
## @ace_category("Scenes")
## @ace_description("Gives a scene file a short name every row can use instead of its path. Registering the same name again replaces the path, so a boot sheet can safely re-run. Do this once at startup, in a sheet every scene reaches.")
## @ace_display_template("Register scene [b]{scene_name}[/b] = [b]{scene_path}[/b]")
## @ace_param_hint(scene_path scene_path)
## @ace_icon("res://eventsheet_addons/named_scenes/icon.svg")
## @ace_codegen_template("NamedScenes.register_scene({scene_name}, {scene_path})")
func register_scene(scene_name: String = "arena", scene_path: String = "") -> void:
	if scene_name.is_empty() or scene_path.is_empty():
		push_warning("Named Scenes: Register Scene needs both a name and a .tscn path.")
		return
	_registry[scene_name] = scene_path

## @ace_action
## @ace_name("Register Scenes In Folder")
## @ace_category("Scenes")
## @ace_description("Registers every .tscn directly inside a folder under its own file name, so res://levels/arena.tscn becomes "arena". The folder IS the level list: add a scene to it and the game knows about it with no row to edit. Sub-folders are left alone.")
## @ace_icon("res://eventsheet_addons/named_scenes/icon.svg")
## @ace_codegen_template("NamedScenes.register_scenes_in_folder({folder})")
func register_scenes_in_folder(folder: String = "res://levels") -> void:
	var directory: DirAccess = DirAccess.open(folder)
	if directory == null:
		push_warning("Named Scenes: no folder at '%s'." % folder)
		return
	for file_name: String in directory.get_files():
		if not file_name.ends_with(".tscn"):
			continue
		_registry[file_name.get_basename()] = folder.path_join(file_name)

## @ace_action
## @ace_name("Forget Named Scene")
## @ace_category("Scenes")
## @ace_description("Removes one name from the registry and drops anything Preload Named Scene had warmed for it. Use it when a level is unlocked or retired at runtime; rows that still name it will warn instead of changing scene.")
## @ace_icon("res://eventsheet_addons/named_scenes/icon.svg")
## @ace_codegen_template("NamedScenes.forget_named_scene({scene_name})")
func forget_named_scene(scene_name: String = "arena") -> void:
	_registry.erase(scene_name)
	_preloaded.erase(scene_name)

## @ace_action
## @ace_featured
## @ace_name("Go To Named Scene")
## @ace_category("Scenes")
## @ace_description("Changes to the scene registered under this name. Nothing happens (with a warning) if the name was never registered, or if the file behind it can no longer be opened, so neither a typo nor a moved .tscn can leave the game on a black screen. On Scene Ready fires with the name only once the new scene is really the one running.")
## @ace_display_template("Go to scene named [b]{scene_name}[/b]")
## @ace_icon("res://eventsheet_addons/named_scenes/icon.svg")
## @ace_codegen_template("NamedScenes.go_to_named_scene({scene_name})")
func go_to_named_scene(scene_name: String = "arena") -> void:
	var path: String = str(_registry.get(scene_name, ""))
	if path.is_empty():
		push_warning("Named Scenes: no scene is registered as '%s'." % scene_name)
		return
	if not is_inside_tree():
		return
	# Remember WHICH scene is running before asking for the change: waiting for current_scene to
	# be merely non-null would fall straight through, because the outgoing scene is still there.
	var leaving_id: int = get_tree().current_scene.get_instance_id() if get_tree().current_scene != null else 0
	if get_tree().change_scene_to_file(path) != OK:
		# A registered path whose .tscn has since been moved or broken. Announcing readiness here
		# would run the new scene's setup rows against the scene that is still on screen.
		push_warning("Named Scenes: '%s' is registered as %s, but that scene could not be opened." % [scene_name, path])
		return
	# change_scene_to_file is deferred to the end of the frame, so the new scene is not there
	# yet. Waiting for a DIFFERENT current_scene is what makes On Scene Ready honest.
	await get_tree().process_frame
	while get_tree().current_scene == null or get_tree().current_scene.get_instance_id() == leaving_id:
		await get_tree().process_frame
	announce_scene_ready(scene_name)

## @ace_action
## @ace_name("Preload Named Scene")
## @ace_category("Scenes")
## @ace_description("Loads a registered scene into memory now, without changing to it, so the change is instant when it comes. Warm the next level while the player is reading a hint or watching a door open. Loading it twice does no extra work.")
## @ace_display_template("Preload scene named [b]{scene_name}[/b]")
## @ace_icon("res://eventsheet_addons/named_scenes/icon.svg")
## @ace_codegen_template("NamedScenes.preload_named_scene({scene_name})")
func preload_named_scene(scene_name: String = "arena") -> void:
	if _preloaded.has(scene_name):
		return
	var path: String = str(_registry.get(scene_name, ""))
	if path.is_empty():
		push_warning("Named Scenes: no scene is registered as '%s'." % scene_name)
		return
	var packed: Resource = ResourceLoader.load(path)
	if packed == null:
		push_warning("Named Scenes: '%s' could not be loaded from %s." % [scene_name, path])
		return
	_preloaded[scene_name] = packed

## @ace_action
## @ace_name("Carry Into Next Scene")
## @ace_category("Scenes")
## @ace_description("Hands a record to the scene you are about to open: a spawn door, a difficulty, who sent you. It belongs to the NEXT scene, so the one you are leaving still reads its own arguments until the change lands.")
## @ace_display_template("Carry [b]{payload}[/b] into the next scene")
## @ace_param_hint(payload expression)
## @ace_icon("res://eventsheet_addons/named_scenes/icon.svg")
## @ace_codegen_template("NamedScenes.carry_into_next_scene({payload})")
func carry_into_next_scene(payload: Dictionary = {}) -> void:
	_pending_handoff = payload.duplicate(true)

## @ace_action
## @ace_name("Announce Scene Ready")
## @ace_category("Scenes")
## @ace_description("Marks a named scene as the one now running: the carried record becomes readable through Scene Argument, Current Scene Is starts answering this name, and On Scene Ready fires with it. Go To Named Scene calls this for you once the new scene exists - call it yourself only when you changed scene some other way.")
## @ace_icon("res://eventsheet_addons/named_scenes/icon.svg")
## @ace_codegen_template("NamedScenes.announce_scene_ready({scene_name})")
func announce_scene_ready(scene_name: String = "arena") -> void:
	_current_name = scene_name
	_handoff = _pending_handoff.duplicate(true)
	_pending_handoff = {}
	scene_ready.emit(scene_name)

## @ace_condition
## @ace_name("Current Scene Is")
## @ace_category("Scenes")
## @ace_description("Whether the named scene is the one running right now. It answers on the name last announced ready, so it keeps working for a scene you loaded by hand as long as Announce Scene Ready was called.")
## @ace_icon("res://eventsheet_addons/named_scenes/icon.svg")
## @ace_codegen_template("NamedScenes.current_scene_is({scene_name})")
func current_scene_is(scene_name: String = "hub") -> bool:
	return _current_name == scene_name

## @ace_condition
## @ace_name("Scene Is Registered")
## @ace_category("Scenes")
## @ace_description("Whether a name has a scene behind it. Ask before Go To Named Scene when the name comes from data (a level list, a save file) rather than from a row you typed.")
## @ace_icon("res://eventsheet_addons/named_scenes/icon.svg")
## @ace_codegen_template("NamedScenes.scene_is_registered({scene_name})")
func scene_is_registered(scene_name: String = "arena") -> bool:
	return _registry.has(scene_name)

## @ace_condition
## @ace_name("Named Scene Is Preloaded")
## @ace_category("Scenes")
## @ace_description("Whether Preload Named Scene has already warmed this scene. Show the Continue button when it has, a spinner while it has not.")
## @ace_icon("res://eventsheet_addons/named_scenes/icon.svg")
## @ace_codegen_template("NamedScenes.named_scene_is_preloaded({scene_name})")
func named_scene_is_preloaded(scene_name: String = "arena") -> bool:
	return _preloaded.has(scene_name)

## @ace_condition
## @ace_name("Has Scene Argument")
## @ace_category("Scenes")
## @ace_description("Whether the scene you are in was handed a value under this key. Lets a level tell "came in by a door" apart from "started here from the menu" without a magic default.")
## @ace_icon("res://eventsheet_addons/named_scenes/icon.svg")
## @ace_codegen_template("NamedScenes.has_scene_argument({key})")
func has_scene_argument(key: String = "door") -> bool:
	return _handoff.has(key)

## @ace_expression
## @ace_name("Scene Argument")
## @ace_category("Scenes")
## @ace_description("A value the previous scene carried over, as text - the door you came in by, who sent you. Answers the fallback when nothing was carried under that key.")
## @ace_icon("res://eventsheet_addons/named_scenes/icon.svg")
## @ace_codegen_template("NamedScenes.scene_argument({key}, {fallback})")
func scene_argument(key: String = "door", fallback: String = "") -> String:
	return str(_handoff.get(key, fallback))

## @ace_expression
## @ace_name("Scene Argument Number")
## @ace_category("Scenes")
## @ace_description("A carried value as a number - an attempt count, a difficulty, a starting score. Answers the fallback when nothing was carried under that key.")
## @ace_icon("res://eventsheet_addons/named_scenes/icon.svg")
## @ace_codegen_template("NamedScenes.scene_argument_number({key}, {fallback})")
func scene_argument_number(key: String = "attempt", fallback: float = 0.0) -> float:
	return float(_handoff.get(key, fallback))

## @ace_expression
## @ace_name("Path Of Named Scene")
## @ace_category("Scenes")
## @ace_description("The res:// path registered under a name, or "" when the name is unknown. The escape hatch for a verb that still wants a path, e.g. the Scene Flow pack's Fade To Scene.")
## @ace_icon("res://eventsheet_addons/named_scenes/icon.svg")
## @ace_codegen_template("NamedScenes.path_of_named_scene({scene_name})")
func path_of_named_scene(scene_name: String = "arena") -> String:
	return str(_registry.get(scene_name, ""))

## @ace_expression
## @ace_name("Current Scene Name")
## @ace_category("Scenes")
## @ace_description("The name of the scene running right now, or "" before the first one was announced. Stabler than a path: save it, show it in a debug corner, key a music track off it.")
## @ace_icon("res://eventsheet_addons/named_scenes/icon.svg")
## @ace_codegen_template("NamedScenes.current_scene_name()")
func current_scene_name() -> String:
	return _current_name

## @ace_expression
## @ace_name("Registered Scene Names")
## @ace_category("Scenes")
## @ace_description("Every registered name, sorted. A level-select screen builds itself from this instead of from a list somebody has to keep in step.")
## @ace_icon("res://eventsheet_addons/named_scenes/icon.svg")
## @ace_codegen_template("NamedScenes.registered_scene_names()")
func registered_scene_names() -> Array:
	var names: Array = _registry.keys()
	names.sort()
	return names

## @ace_hidden
func save_state() -> Dictionary:
	# Save-state seam: the Save System walks any node in its persist group (or targeted by
	# Save/Load Node State) and duck-types these two methods. Plain data only - the loaded
	# PackedScenes are a memory warm-up belonging to this run, so they are left out.
	return {
		"registry": _registry.duplicate(true),
		"current": _current_name,
		"handoff": _handoff.duplicate(true)
	}

## @ace_hidden
func load_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	_registry = (state.get("registry", {}) as Dictionary).duplicate(true)
	_current_name = str(state.get("current", ""))
	_handoff = (state.get("handoff", {}) as Dictionary).duplicate(true)

# Named Scenes: register as the NamedScenes autoload. Register Scene (or Register Scenes In Folder) once at boot, then say Go To Named Scene "arena" everywhere else. Carry Into Next Scene passes a record across the change, read back with Scene Argument. This pack is an event sheet - extend it by editing it.
