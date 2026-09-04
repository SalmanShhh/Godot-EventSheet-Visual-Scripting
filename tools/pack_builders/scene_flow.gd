# Pack builder - scene_flow (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Scene Flow behavior: scene changes with a polished fade, from one node. The fade runner
## parents itself to the TREE ROOT (not the dying scene), so the fade-out, the swap, and the
## fade-in all survive the change - the classic "my transition died with my scene" trap, solved
## once. Also the home of Reload and Quit, so a menu needs no code for any of the big three.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node"
	sheet.custom_class_name = "SceneFlowBehavior"
	sheet.class_description = "Polished scene changes from one node: fade to another scene, fade-reload the current one, jump or reload instantly, and quit the game. The fade overlay parents itself to the tree root instead of the dying scene, so the transition survives the swap instead of vanishing halfway through."
	sheet.addon_category = "Scenes"
	sheet.ace_expose_all_mode = "node"
	sheet.variables = {
		"fade_color": {"type": "Color", "default": Color(0, 0, 0, 1), "exported": true, "attributes": {"tooltip": "The cover colour the screen fades through."}},
		"fade_seconds": {"type": "float", "default": 0.4, "exported": true, "attributes": {"tooltip": "Fade-out (and fade-in) duration in seconds.", "range": {"min": "0.05", "max": "5", "step": "0.05"}}},
		"wipe_image": {"type": "Texture2D", "default": null, "exported": true, "attributes": {"tooltip": "The greyscale picture a wipe transition follows: its dark parts are covered first and its light parts last, so a ramp is a bar wipe, a radial ramp is a clock, and a painted shape is whatever you painted. Empty is a plain left-to-right sweep."}},
		"loading_scene": {"type": "String", "default": "", "exported": true, "attributes": {"tooltip": "The screen shown while Go To Scene With Loading waits for the next scene. The pack ships loading_screen.tscn as a starter to copy and restyle; empty means no screen at all, and the wait happens where the player is standing.", "file": {"filters": ["*.tscn", "*.scn"]}}},
		"loading_transition": {"type": "String", "default": "fade", "exported": true, "options": ["none", "fade", "wipe", "dissolve", "iris", "blinds", "pixelate", "page curl"], "attributes": {"tooltip": "The shape drawn over BOTH halves of a loading change: onto the loading screen and off it again into the new scene. The same wardrobe Go To Scene With picks from, held over the node's Fade Seconds. None swaps plainly."}},
		"loading_tips_file": {"type": "String", "default": "", "exported": true, "attributes": {"tooltip": "A text file of tips, one per line, that Loading Tip picks from - one tip is chosen when the load starts and stays put for the whole wait. The pack ships tips.txt as a starter; the file is yours, and a line starting with # is a note to yourself. Add *.txt to the export filters so it ships with the game.", "file": {"filters": ["*.txt"]}}}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Scene Flow behavior: scene changes with a polished fade, from one node. The fade runner parents itself to the TREE ROOT (not the dying scene), so the fade-out, the swap, and the fade-in all survive the change. Fade To Scene / Go To Scene / Fade Reload / Reload / Quit Game cover a whole menu's needs with zero code. Go To Scene With and Reload Scene With draw a shape over the change instead - fade, wipe, dissolve, iris, blinds, pixelate or page curl - and On Transition Finished fires on the Scene Flow node in the scene it arrived at. Go To Scene With Loading puts a screen of your own in the middle of that change while the next scene comes off the disk: On Loading Progress and Loading Progress move a bar, Loading Tip reads a line out of a text file you own, and Enter Loaded Scene is what a press-any-key row does."
	sheet.events.append(about)

	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## The root-parented fade overlay: fades out, swaps (or reloads) the scene, fades back in,",
		"## then frees itself. Lives under the tree root so the running tween outlives the old scene;",
		"## the \"scene_flow_transition\" group is the busy flag Is Transitioning reads.",
		"class TransitionRunner:",
		"\textends CanvasLayer",
		"\tvar fade_seconds: float = 0.4",
		"\tvar fade_color: Color = Color.BLACK",
		"\tvar target_path: String = \"\"",
		"\tvar _rect: ColorRect = null",
		"",
		"\tfunc _ready() -> void:",
		"\t\tadd_to_group(\"scene_flow_transition\")",
		"\t\tlayer = 128",
		"\t\t_rect = ColorRect.new()",
		"\t\t_rect.color = fade_color",
		"\t\t_rect.modulate.a = 0.0",
		"\t\t_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)",
		"\t\tadd_child(_rect)",
		"\t\tvar fade: Tween = create_tween()",
		"\t\tfade.tween_property(_rect, \"modulate:a\", 1.0, fade_seconds)",
		"\t\tfade.tween_callback(_swap)",
		"\t\tfade.tween_property(_rect, \"modulate:a\", 0.0, fade_seconds)",
		"\t\tfade.tween_callback(queue_free)",
		"",
		"\tfunc _swap() -> void:",
		"\t\tif target_path.is_empty():",
		"\t\t\tget_tree().reload_current_scene()",
		"\t\telse:",
		"\t\t\tget_tree().change_scene_to_file(target_path)",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Transitioning\")",
		"func is_transitioning() -> bool:",
		"\treturn not get_tree().get_nodes_in_group(\"scene_flow_transition\").is_empty()",
		"",
		"## @ace_expression",
		"## @ace_name(\"Current Scene Path\")",
		"func current_scene_path() -> String:",
		"\tvar current: Node = get_tree().current_scene",
		"\treturn current.scene_file_path if current != null else \"\"",
		"",
		"func _start_fade(path: String) -> void:",
		"\tif is_transitioning():",
		"\t\treturn",
		"\tvar runner: TransitionRunner = TransitionRunner.new()",
		"\trunner.fade_seconds = maxf(0.05, fade_seconds)",
		"\trunner.fade_color = fade_color",
		"\trunner.target_path = path",
		"\tget_tree().root.add_child(runner)"
	]))
	sheet.events.append(block)

	var transitions: RawCodeRow = RawCodeRow.new()
	transitions.code = "\n".join(_transition_lines())
	sheet.events.append(transitions)

	var loading: RawCodeRow = RawCodeRow.new()
	loading.code = "\n".join(_loading_lines())
	sheet.events.append(loading)

	var ready_row: EventRow = EventRow.new()
	ready_row.trigger_provider_id = "Core"
	ready_row.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "\n".join(PackedStringArray([
		"# Every Scene Flow node listens for a finished transition, because the one that hears it is the one",
		"# standing in the scene the transition arrived at.",
		"add_to_group(TRANSITION_LISTENERS)"
	]))
	ready_row.actions.append(ready_body)
	sheet.events.append(ready_row)

	Lib.append_function(sheet, "fade_to_scene", "Fade To Scene", "Scenes",
		"Fades the screen out, changes to the scene, and fades back in (ignored while a transition runs).",
		[["path", "String"]], "\n".join(PackedStringArray([
		"if path.strip_edges().is_empty():",
		"\treturn",
		"_start_fade(path.strip_edges())"
	])))

	Lib.append_function(sheet, "fade_reload_scene", "Fade Reload Scene", "Scenes",
		"Fades out, reloads the current scene, and fades back in - the polished retry button.",
		[], "\n".join(PackedStringArray([
		"_start_fade(\"\")"
	])))

	Lib.append_function(sheet, "go_to_scene", "Go To Scene", "Scenes",
		"Changes to the scene immediately (no fade).",
		[["path", "String"]], "\n".join(PackedStringArray([
		"if not path.strip_edges().is_empty():",
		"\tget_tree().change_scene_to_file(path.strip_edges())"
	])))

	Lib.append_function(sheet, "reload_scene", "Reload Scene", "Scenes",
		"Reloads the current scene immediately (no fade).",
		[], "\n".join(PackedStringArray([
		"get_tree().reload_current_scene()"
	])))

	Lib.append_function(sheet, "quit_game", "Quit Game", "Scenes",
		"Quits the game (a no-op on platforms that forbid it, like web).",
		[], "\n".join(PackedStringArray([
		"get_tree().quit()"
	])))

	Lib.append_function(sheet, "go_to_scene_with", "Go To Scene With", "Scenes",
		"Changes to the scene with a transition drawn over it: the shape walks on over the first half, the scene is swapped under the cover, and it walks off again over the second. The shapes are fade, wipe (following the Wipe Image knob), dissolve, iris, blinds, pixelate and page curl. The cover colour is the node's Fade Color. Ignored while a transition is already running; emits On Transition Finished when the new scene is up and the cover is off.",
		[["path", "String"], ["transition", "String"], ["seconds", "float"], ["ease", "String"]],
		"if path.strip_edges().is_empty():\n\treturn\n_start_transition(path.strip_edges(), transition, seconds, ease)")
	_default(sheet, "transition", "fade")
	_param_options(sheet, "transition", ["fade", "wipe", "dissolve", "iris", "blinds", "pixelate", "page curl"])
	_param_desc(sheet, "path", "The scene to open. Its res:// path, or an expression that answers with one.")
	_param_desc(sheet, "transition", "The shape drawn over the change. Wipe follows the node's Wipe Image; pixelate and page curl read the screen back while they run.")
	_default(sheet, "seconds", "0.6")
	_param_desc(sheet, "seconds", "How long the whole change takes, on and off again. Held over a floor while no flashing is on.")
	_default(sheet, "ease", "smooth")
	_param_options(sheet, "ease", ["linear", "smooth", "in", "out"])
	_param_desc(sheet, "ease", "What the walk feels like: linear is one speed, smooth eases both ends, in starts slowly, out arrives slowly.")
	_quoted_argument(sheet, "go_to_scene_with({path}, \"{transition}\", {seconds}, \"{ease}\")")

	Lib.append_function(sheet, "reload_scene_with", "Reload Scene With", "Scenes",
		"Reloads the current scene with a transition drawn over it - the polished retry, in whichever shape the game uses everywhere else. Same shapes, same cover colour and same one-at-a-time rule as Go To Scene With; emits On Transition Finished when the fresh scene is up.",
		[["transition", "String"], ["seconds", "float"], ["ease", "String"]],
		"_start_transition(\"\", transition, seconds, ease)")
	_default(sheet, "transition", "fade")
	_param_options(sheet, "transition", ["fade", "wipe", "dissolve", "iris", "blinds", "pixelate", "page curl"])
	_param_desc(sheet, "transition", "The shape drawn over the reload. Wipe follows the node's Wipe Image; pixelate and page curl read the screen back while they run.")
	_default(sheet, "seconds", "0.6")
	_param_desc(sheet, "seconds", "How long the whole reload takes, on and off again. Held over a floor while no flashing is on.")
	_default(sheet, "ease", "smooth")
	_param_options(sheet, "ease", ["linear", "smooth", "in", "out"])
	_param_desc(sheet, "ease", "What the walk feels like: linear is one speed, smooth eases both ends, in starts slowly, out arrives slowly.")
	_quoted_argument(sheet, "reload_scene_with(\"{transition}\", {seconds}, \"{ease}\")")

	Lib.append_function(sheet, "go_to_with_loading", "Go To Scene With Loading", "Scenes",
		"Shows the node's Loading Scene while the next scene comes off the disk on a thread, then enters it. The wait is over when BOTH the load has finished and the minimum seconds have passed, so the screen cannot flash past on a fast machine; On Loading Progress moves a bar through Loading Progress, and Loading Tip answers with one line of the tips file. With Wait For Key on it stops there and waits for Enter Loaded Scene. The node's Loading Transition wraps both halves of the change.",
		[["scene", "String"], ["min_seconds", "float"], ["wait_for_key", "bool"]],
		"_start_loading(scene, min_seconds, wait_for_key)")
	_param_desc(sheet, "scene", "The scene to open. Its res:// path, or an expression that answers with one.")
	_default(sheet, "min_seconds", "1.0")
	_param_desc(sheet, "min_seconds", "The shortest the loading screen stays up, in seconds. One second is enough to be read as a beat rather than as a flicker; zero enters the moment the load lands.")
	_default(sheet, "wait_for_key", "false")
	_param_desc(sheet, "wait_for_key", "On: the wait ends at On Loading Finished and the screen stays up until a row runs Enter Loaded Scene - the press-any-key screen. Off: the new scene is entered as soon as the wait is over.")

	Lib.append_function(sheet, "enter_loaded_scene", "Enter Loaded Scene", "Scenes",
		"Enters the scene a loading screen has been holding. Does nothing at all while the wait is still on, so a bare \"any key pressed\" row is safe to leave on the loading screen; it is what Wait For Key waits for.",
		[], "\n".join(PackedStringArray([
		"var runner: LoadingRunner = _loading_runner()",
		"if runner != null:",
		"\trunner.enter()"
	])))

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.verb_sentences(sheet, {
		"fade_to_scene": "Fade to scene [b]{path}[/b]",
		"go_to_scene_with": "Go to scene [b]{path}[/b] with a [b]{transition}[/b] over [b]{seconds}[/b] s",
		"reload_scene_with": "Reload with a [b]{transition}[/b] over [b]{seconds}[/b] s",
		"go_to_with_loading": "Go to scene [b]{scene}[/b] with loading, at least [b]{min_seconds}[/b] s",
	})
	Lib.feature_verbs(sheet, ["fade_to_scene", "go_to_scene_with", "go_to_with_loading"])
	if not Lib.save_pack(sheet, "res://eventsheet_addons/scene_flow/scene_flow_behavior"):
		return false
	# THE SHADERS ARE THE TRANSITIONS: a shape whose file is missing draws nothing, so they ship in
	# the same build as the script that loads them. The loading screen and its tips file ship the
	# same way, and for the opposite reason: they are STARTERS rather than machinery. Nothing points
	# at them until a project fills in the two Inspector knobs, and both are meant to be copied into
	# the project's own folders and rewritten - which is why the pack ships one of each and never a
	# list of screens or a table of tips it owns.
	return Lib.ship_files("scene_flow", "res://eventsheet_addons/scene_flow/scene_flow_behavior",
		PackedStringArray(["gdshader", "tscn", "txt"]))


## The TRANSITIONS half of the pack: the shapes, the runner that draws one, and the one progress
## model all three of them read. Split out so build() reads as the shape of the pack.
static func _transition_lines() -> PackedStringArray:
	return PackedStringArray([
		"# --- Transitions: a scene change with a shader drawn over it ---",
		"",
		"## Where the transition shaders live once the pack is installed, and the name one takes: the word a",
		"## row uses with its spaces closed up, under one prefix. A word and its file can never drift apart.",
		"const TRANSITION_DIRECTORY: String = \"res://eventsheet_addons/scene_flow/\"",
		"const TRANSITION_PREFIX: String = \"transition_\"",
		"",
		"## The seven shapes a transition can take, by the word a row uses. Each is one shader file with a",
		"## `progress` dial; the two that read the screen back - pixelate and page curl - say so in their own",
		"## first lines, and they only read it while a transition is actually running.",
		"const TRANSITIONS: PackedStringArray = [\"fade\", \"wipe\", \"dissolve\", \"iris\", \"blinds\", \"pixelate\",",
		"\t\"page curl\"]",
		"",
		"## The group every running transition joins - the shipped fade above and the shaded ones below alike,",
		"## so Is Transitioning is ONE question with one answer rather than two flags that can disagree.",
		"const TRANSITION_GROUP: StringName = &\"scene_flow_transition\"",
		"",
		"## THE ACCESSIBILITY FLOOR. A player who has asked for no flashing gets the same transition in the",
		"## same shape, held over this many seconds - because a shape that sweeps the whole screen and back",
		"## in a tenth of a second is a flash whatever shape it is. This is the same floor the post stack",
		"## holds its walks over, read off the same Engine meta the built-in Set No Flashing row writes.",
		"const TRANSITION_FLASH_FLOOR_SECONDS: float = 0.4",
		"const TRANSITION_NO_FLASHING_META: StringName = &\"no_flashing\"",
		"",
		"## And the shortest a transition may be when nobody has asked for anything: short enough to feel",
		"## instant, long enough that the swap still happens under cover.",
		"const TRANSITION_FLOOR_SECONDS: float = 0.1",
		"",
		"## And the group every Scene Flow node joins, so a finished transition can tell somebody. The runner",
		"## outlives the scene it started in, so the node it tells is whichever one is standing in the NEW",
		"## scene - which is exactly where a row waiting on the arrival wants to be.",
		"const TRANSITION_LISTENERS: StringName = &\"scene_flow_listener\"",
		"",
		"## Fires when a transition started by Go To Scene With or Reload Scene With has finished: the new",
		"## scene is up and the cover is off. It arrives on the Scene Flow node in the NEW scene, carrying the",
		"## shape the transition was, so one handler can tell a wipe from an iris.",
		"## @ace_trigger",
		"## @ace_name(\"On Transition Finished\")",
		"signal transition_finished(shape: String)",
		"",
		"## The root-parented runner that draws a transition and swaps the scene under it. Like the fade",
		"## runner above, it parents itself to the TREE ROOT rather than to the scene being replaced, so the",
		"## walk out, the swap and the walk back in all survive the change.",
		"##",
		"## THE TOP SLOT: it draws above everything, post effects included, because a transition is the one",
		"## thing that must not itself be graded, blurred or vignetted by the look the game happens to be",
		"## wearing. That is ONE rectangle for the whole transition, and the post stack underneath keeps its",
		"## own - a transition never builds a second screen of its own to fight with.",
		"class ShaderTransitionRunner:",
		"\textends CanvasLayer",
		"\tvar shape: String = \"fade\"",
		"\tvar seconds: float = 0.6",
		"\tvar ease_word: String = \"smooth\"",
		"\tvar cover_color: Color = Color.BLACK",
		"\tvar wipe_image: Texture2D = null",
		"\tvar target_path: String = \"\"",
		"\tvar _rect: ColorRect = null",
		"\tvar _material: ShaderMaterial = null",
		"\tvar _walked: float = 0.0",
		"\tvar _swapped: bool = false",
		"",
		"\tfunc _ready() -> void:",
		"\t\tadd_to_group(SceneFlowBehavior.TRANSITION_GROUP)",
		"\t\tlayer = 128",
		"\t\tvar shader: Shader = SceneFlowBehavior.transition_shader(shape)",
		"\t\tif shader == null:",
		"\t\t\t# A shape with no shader must not leave the screen covered for ever: do the swap this",
		"\t\t\t# row asked for, plainly, and go.",
		"\t\t\t_swap()",
		"\t\t\t_finish()",
		"\t\t\treturn",
		"\t\t_material = ShaderMaterial.new()",
		"\t\t_material.shader = shader",
		"\t\t_material.set_shader_parameter(\"progress\", 0.0)",
		"\t\t_material.set_shader_parameter(\"cover_color\", cover_color)",
		"\t\tif wipe_image != null:",
		"\t\t\t_material.set_shader_parameter(\"wipe_image\", wipe_image)",
		"\t\t\t_material.set_shader_parameter(\"use_image\", 1.0)",
		"\t\t_rect = ColorRect.new()",
		"\t\t_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE",
		"\t\t_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)",
		"\t\t_rect.material = _material",
		"\t\tadd_child(_rect)",
		"\t\tset_process(true)",
		"",
		"\tfunc _process(delta: float) -> void:",
		"\t\t# A transition is measured in seconds a PLAYER waits, so a slowmo running underneath it must",
		"\t\t# not stretch it: the frame's own time is put back through the time scale it was scaled by.",
		"\t\t_walked += delta / maxf(Engine.time_scale, 0.0001)",
		"\t\tvar fraction: float = clampf(_walked / maxf(seconds, 0.1), 0.0, 1.0)",
		"\t\tif _material != null:",
		"\t\t\t_material.set_shader_parameter(\"progress\",",
		"\t\t\t\tSceneFlowBehavior.transition_cover(fraction, ease_word))",
		"\t\tif not _swapped and fraction >= 0.5:",
		"\t\t\t_swapped = true",
		"\t\t\t_swap()",
		"\t\tif fraction >= 1.0:",
		"\t\t\t_finish()",
		"",
		"\tfunc _swap() -> void:",
		"\t\tif target_path.is_empty():",
		"\t\t\tget_tree().reload_current_scene()",
		"\t\telse:",
		"\t\t\tget_tree().change_scene_to_file(target_path)",
		"",
		"\tfunc _finish() -> void:",
		"\t\tset_process(false)",
		"\t\tfor listener: Node in get_tree().get_nodes_in_group(SceneFlowBehavior.TRANSITION_LISTENERS):",
		"\t\t\tif listener.has_signal(\"transition_finished\"):",
		"\t\t\t\tlistener.emit_signal(\"transition_finished\", shape)",
		"\t\tqueue_free()",
		"",
		"## HOW COVERED THE SCREEN IS at a point in the walk: nothing at the start, everything at the halfway",
		"## mark where the scene is exchanged, and nothing again at the end. ONE progress model, so the",
		"## shader, the swap and anything asking about the walk are reading the same triangle rather than",
		"## three of their own.",
		"##",
		"## The ease words are what the walk feels like on the way up and back: linear is a constant speed,",
		"## smooth eases both ends, in starts slowly and out arrives slowly.",
		"static func transition_cover(fraction: float, ease_word: String) -> float:",
		"\tvar walk: float = clampf(fraction, 0.0, 1.0)",
		"\tvar cover: float = 1.0 - absf(1.0 - walk * 2.0)",
		"\tmatch ease_word.strip_edges().to_lower():",
		"\t\t\"smooth\":",
		"\t\t\treturn smoothstep(0.0, 1.0, cover)",
		"\t\t\"in\":",
		"\t\t\treturn cover * cover",
		"\t\t\"out\":",
		"\t\t\treturn 1.0 - (1.0 - cover) * (1.0 - cover)",
		"\t\t_:",
		"\t\t\treturn cover",
		"",
		"## Which part of the walk a point is in: \"out\" while the cover is coming on, \"swap\" at the midpoint",
		"## where the scene is exchanged, \"in\" while the cover is coming off the new one.",
		"static func transition_phase(fraction: float) -> String:",
		"\tvar walk: float = clampf(fraction, 0.0, 1.0)",
		"\tif is_equal_approx(walk, 0.5):",
		"\t\treturn \"swap\"",
		"\treturn \"out\" if walk < 0.5 else \"in\"",
		"",
		"## The shader one shape wears, loaded from the pack folder beside this script. A word that is not a",
		"## shape, or one whose file is missing, is a warning and a plain swap rather than a covered screen",
		"## nobody can get out of.",
		"static func transition_shader(shape: String) -> Shader:",
		"\tvar word: String = shape.strip_edges().to_lower()",
		"\tif not TRANSITIONS.has(word):",
		"\t\tpush_warning(\"Scene Flow: no transition is called \\\"%s\\\" - the shapes are %s.\" % [",
		"\t\t\tshape, \", \".join(TRANSITIONS)])",
		"\t\treturn null",
		"\tvar path: String = TRANSITION_DIRECTORY + TRANSITION_PREFIX + word.replace(\" \", \"_\") + \".gdshader\"",
		"\tif not ResourceLoader.exists(path):",
		"\t\tpush_warning(\"Scene Flow has no shader file for the \\\"%s\\\" transition at %s.\" % [word, path])",
		"\t\treturn null",
		"\treturn load(path) as Shader",
		"",
		"## The shortest a transition may be right now: the ordinary floor, or the accessibility one for a",
		"## player who has asked for no flashing. A transition is one of the three things this project holds",
		"## over that floor, beside a post-stack walk and a moment step.",
		"## @ace_hidden",
		"static func transition_floor_seconds() -> float:",
		"\tif bool(Engine.get_meta(TRANSITION_NO_FLASHING_META, false)):",
		"\t\treturn TRANSITION_FLASH_FLOOR_SECONDS",
		"\treturn TRANSITION_FLOOR_SECONDS",
		"",
		"## Starts one shaded transition, or does nothing at all if another is already running - the same",
		"## one-at-a-time rule the shipped fade follows.",
		"## @ace_hidden",
		"func _start_transition(path: String, shape: String, seconds: float, ease_word: String) -> void:",
		"\tif is_transitioning():",
		"\t\treturn",
		"\tvar runner: ShaderTransitionRunner = ShaderTransitionRunner.new()",
		"\trunner.shape = shape",
		"\trunner.seconds = maxf(seconds, transition_floor_seconds())",
		"\trunner.ease_word = ease_word",
		"\trunner.cover_color = fade_color",
		"\trunner.wipe_image = wipe_image",
		"\trunner.target_path = path",
		"\tget_tree().root.add_child(runner)"
	])


## The LOADING half of the pack: a screen of the project's OWN between two scenes, the root-parented
## poller that holds the background load, and the one progress model the bar, the gate and the tests
## all read. Split out for the same reason the transitions are - build() should read as the shape of
## the pack rather than as a wall of lines.
##
## The pack ships a loading screen and a tips file as STARTERS and points at neither: both knobs open
## empty, so a project chooses its own screen and its own words, and copying the starters is the
## fastest way to get there rather than the only way.
static func _loading_lines() -> PackedStringArray:
	return PackedStringArray([
		"# --- Loading screens: a screen of your own while the next scene comes off the disk ---",
		"",
		"## The group the one running background load joins, so Is Loading, Loading Progress and",
		"## Loading Tip are ONE question with one answer rather than three fields that can disagree.",
		"## It is a group rather than a member because the poller OUTLIVES the scene the row was in:",
		"## the node that started the load is replaced by the loading screen a moment later.",
		"const LOADING_GROUP: StringName = &\"scene_flow_loading\"",
		"",
		"## The word that means \"no shape over the change\" in the Loading Transition knob. Every other",
		"## word in that list is one of the shapes above, so a loading change wears the same wardrobe",
		"## the rest of the game's changes do.",
		"const LOADING_NO_TRANSITION: String = \"none\"",
		"",
		"## The line a tips file leaves out: a comment, so a file of tips can carry a note about itself",
		"## and a tip can be parked without being deleted.",
		"const LOADING_TIP_COMMENT: String = \"#\"",
		"",
		"## Fires every time the loading reading MOVES, on the Scene Flow node standing in the loading",
		"## screen - which is exactly where a row that sets a bar wants to be. It carries nothing:",
		"## Loading Progress answers with the number, so the row reads as a sentence.",
		"## @ace_trigger",
		"## @ace_name(\"On Loading Progress\")",
		"signal loading_progress_changed",
		"",
		"## Fires once when the wait is over: the scene is off the disk AND the minimum seconds have",
		"## been served. With Wait For Key off the swap follows immediately; with it on, this is the",
		"## moment to show \"press any key\", and Enter Loaded Scene is what the key does.",
		"## @ace_trigger",
		"## @ace_name(\"On Loading Finished\")",
		"signal loading_finished",
		"",
		"## The root-parented poller that holds one background load: it asks the loader how far it has",
		"## got, tells the loading screen, and enters the new scene when the wait is over. Like the two",
		"## transition runners above it lives under the TREE ROOT, because the row that started it is",
		"## standing in a scene that is about to be replaced by the loading screen.",
		"class LoadingRunner:",
		"\textends Node",
		"\tvar target_path: String = \"\"",
		"\tvar min_seconds: float = 1.0",
		"\tvar wait_for_key: bool = false",
		"\tvar tip: String = \"\"",
		"\tvar shape: String = \"none\"",
		"\tvar cover_seconds: float = 0.4",
		"\tvar cover_color: Color = Color.BLACK",
		"\tvar wipe_image: Texture2D = null",
		"\tvar reading: float = 0.0",
		"\tvar finished: bool = false",
		"\tvar _elapsed: float = 0.0",
		"\tvar _entering: bool = false",
		"\t# The loaded scene, held from the moment it lands until the swap has actually happened. A",
		"\t# threaded load nobody is holding can be dropped again before a covered change reaches its",
		"\t# halfway mark, and the second read off the disk is the hitch the whole screen was for.",
		"\tvar _held_scene: PackedScene = null",
		"",
		"\tfunc _ready() -> void:",
		"\t\tadd_to_group(SceneFlowBehavior.LOADING_GROUP)",
		"\t\t# A loading screen goes on loading while the game is paused: a pause menu that leads into",
		"\t\t# a level is the ordinary case rather than a strange one.",
		"\t\tprocess_mode = Node.PROCESS_MODE_ALWAYS",
		"\t\tset_process(true)",
		"",
		"\tfunc _process(delta: float) -> void:",
		"\t\tif _entering:",
		"\t\t\t# Holding the scene until the cover is off, and then there is nothing left to hold.",
		"\t\t\tif get_tree().get_nodes_in_group(SceneFlowBehavior.TRANSITION_GROUP).is_empty():",
		"\t\t\t\tqueue_free()",
		"\t\t\treturn",
		"\t\t# The minimum is seconds a PLAYER waits, so a slowmo running underneath must not stretch",
		"\t\t# it: the frame's own time is put back through the time scale it was scaled by.",
		"\t\t_elapsed += delta / maxf(Engine.time_scale, 0.0001)",
		"\t\tvar seen: Array = []",
		"\t\tvar status: int = ResourceLoader.load_threaded_get_status(target_path, seen)",
		"\t\tif status == ResourceLoader.THREAD_LOAD_FAILED \\",
		"\t\t\t\tor status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:",
		"\t\t\tpush_warning(\"Scene Flow could not load %s, so the loading screen is where the game stays.\" % target_path)",
		"\t\t\tqueue_free()",
		"\t\t\treturn",
		"\t\tvar now: float = SceneFlowBehavior.loading_reading(",
		"\t\t\tfloat(seen[0]) if not seen.is_empty() else 0.0, _elapsed, min_seconds)",
		"\t\tif not is_equal_approx(now, reading):",
		"\t\t\treading = now",
		"\t\t\t_tell(\"loading_progress_changed\")",
		"\t\tif finished:",
		"\t\t\treturn",
		"\t\tif not SceneFlowBehavior.loading_wait_is_over(status, _elapsed, min_seconds):",
		"\t\t\treturn",
		"\t\tfinished = true",
		"\t\t_tell(\"loading_finished\")",
		"\t\tif not wait_for_key:",
		"\t\t\tenter()",
		"",
		"\t## Swaps to the scene this runner has been waiting for, under the loading transition when the",
		"\t## node asked for one. Does NOTHING while the wait is still on, which is what makes a bare",
		"\t## \"any key pressed -> Enter Loaded Scene\" row safe to leave on the loading screen.",
		"\tfunc enter() -> void:",
		"\t\tif _entering or not finished:",
		"\t\t\treturn",
		"\t\tvar packed: PackedScene = ResourceLoader.load_threaded_get(target_path) as PackedScene",
		"\t\tif packed == null:",
		"\t\t\tpush_warning(\"Scene Flow loaded %s and it is not a scene, so there is nothing to enter.\" % target_path)",
		"\t\t\tqueue_free()",
		"\t\t\treturn",
		"\t\t_entering = true",
		"\t\t_held_scene = packed",
		"\t\tvar word: String = shape.strip_edges().to_lower()",
		"\t\tvar busy: bool = not get_tree().get_nodes_in_group(",
		"\t\t\tSceneFlowBehavior.TRANSITION_GROUP).is_empty()",
		"\t\tif busy or word.is_empty() or word == SceneFlowBehavior.LOADING_NO_TRANSITION:",
		"\t\t\tget_tree().change_scene_to_packed(packed)",
		"\t\t\tqueue_free()",
		"\t\t\treturn",
		"\t\tvar runner: SceneFlowBehavior.ShaderTransitionRunner = \\",
		"\t\t\tSceneFlowBehavior.ShaderTransitionRunner.new()",
		"\t\trunner.shape = word",
		"\t\trunner.seconds = maxf(cover_seconds, SceneFlowBehavior.transition_floor_seconds())",
		"\t\trunner.ease_word = \"smooth\"",
		"\t\trunner.cover_color = cover_color",
		"\t\trunner.wipe_image = wipe_image",
		"\t\t# The PATH rather than the scene object, because the shipped runner swaps by path - and",
		"\t\t# the file it names is the one held above, so the swap comes out of the cache instead of",
		"\t\t# off the disk a second time.",
		"\t\trunner.target_path = target_path",
		"\t\tget_tree().root.add_child(runner)",
		"",
		"\t## Tells every Scene Flow node in the tree, which is the same address the finished transition",
		"\t## uses: the node that hears it is the one standing in the loading screen.",
		"\tfunc _tell(what: String) -> void:",
		"\t\tfor listener: Node in get_tree().get_nodes_in_group(",
		"\t\t\t\tSceneFlowBehavior.TRANSITION_LISTENERS):",
		"\t\t\tif listener.has_signal(what):",
		"\t\t\t\tlistener.emit_signal(what)",
		"",
		"## HOW FAR THE WAIT HAS GOT, from 0 to 1 - what Loading Progress answers with and what a bar is",
		"## set to. It is the SLOWER of the two things being waited on: how much of the scene is off the",
		"## disk, and how much of the minimum time has been served. A bar that races to the end and then",
		"## sits there reads as a hang, so this one never runs ahead of the wait it belongs to.",
		"## @ace_hidden",
		"static func loading_reading(loaded: float, elapsed: float, min_seconds: float) -> float:",
		"\tvar by_disk: float = clampf(loaded, 0.0, 1.0)",
		"\tif min_seconds <= 0.0:",
		"\t\treturn by_disk",
		"\treturn minf(by_disk, clampf(elapsed / min_seconds, 0.0, 1.0))",
		"",
		"## Whether the wait is over: the scene is off the disk AND the minimum has been served. The two",
		"## are one question, which is what makes a fast machine and a slow one spend the same beat on",
		"## the screen instead of one of them flashing it past.",
		"## @ace_hidden",
		"static func loading_wait_is_over(status: int, elapsed: float, min_seconds: float) -> bool:",
		"\treturn status == ResourceLoader.THREAD_LOAD_LOADED and elapsed >= min_seconds",
		"",
		"## Whether the runner walks into the new scene by itself at that point, which it does unless the",
		"## row asked to wait for a key - the press-any-key screen.",
		"## @ace_hidden",
		"static func loading_enters_itself(status: int, elapsed: float, min_seconds: float,",
		"\t\twait_for_key: bool) -> bool:",
		"\treturn loading_wait_is_over(status, elapsed, min_seconds) and not wait_for_key",
		"",
		"## The tips a tips file holds: one per line, blank lines dropped, and a line starting with # left",
		"## out so a file can carry a note about itself. The file is the PROJECT'S - the pack ships one to",
		"## copy and never a list of tips of its own.",
		"## @ace_hidden",
		"static func loading_tip_lines(text: String) -> PackedStringArray:",
		"\tvar tips: PackedStringArray = PackedStringArray()",
		"\tfor raw_line: String in text.split(\"\\n\"):",
		"\t\tvar line: String = raw_line.strip_edges()",
		"\t\tif line.is_empty() or line.begins_with(LOADING_TIP_COMMENT):",
		"\t\t\tcontinue",
		"\t\ttips.append(line)",
		"\treturn tips",
		"",
		"## The tip at a position, wrapping round, so any number at all picks one and an empty file",
		"## answers with an empty string rather than reaching past the end of the list.",
		"## @ace_hidden",
		"static func loading_tip_at(tips: PackedStringArray, index: int) -> String:",
		"\tif tips.is_empty():",
		"\t\treturn \"\"",
		"\treturn tips[posmod(index, tips.size())]",
		"",
		"## Whether a background load started by Go To Scene With Loading is still in flight. It stays",
		"## true while the screen is up - including the beat where it is waiting for a key, and the",
		"## covered change into the new scene - so a row can gate anything on \"still loading\".",
		"## @ace_condition",
		"## @ace_name(\"Is Loading\")",
		"func is_loading() -> bool:",
		"\treturn _loading_runner() != null",
		"",
		"## How far the wait has got, from 0 to 1. Multiply by 100 for a percentage, or set a bar whose",
		"## maximum is 1 straight from it. Zero when nothing is loading.",
		"## @ace_expression",
		"## @ace_name(\"Loading Progress\")",
		"func loading_progress() -> float:",
		"\tvar runner: LoadingRunner = _loading_runner()",
		"\treturn runner.reading if runner != null else 0.0",
		"",
		"## The one line picked out of the tips file when this load started. It stays put for the whole",
		"## wait, because a tip that changes while somebody is reading it is worse than no tip. Empty",
		"## when there is no tips file, or nothing is loading.",
		"## @ace_expression",
		"## @ace_name(\"Loading Tip\")",
		"func loading_tip() -> String:",
		"\tvar runner: LoadingRunner = _loading_runner()",
		"\treturn runner.tip if runner != null else \"\"",
		"",
		"## The running load, or null when nothing is loading. One at a time by construction: the group",
		"## holds at most one runner because Go To Scene With Loading refuses while one is alive.",
		"## @ace_hidden",
		"func _loading_runner() -> LoadingRunner:",
		"\tif not is_inside_tree():",
		"\t\treturn null",
		"\tfor node: Node in get_tree().get_nodes_in_group(LOADING_GROUP):",
		"\t\treturn node as LoadingRunner",
		"\treturn null",
		"",
		"## The tips this node's tips file holds, or none at all when it has no file. Read on each load",
		"## rather than kept, so editing the file while the game runs shows up on the next screen.",
		"## @ace_hidden",
		"func _loading_tips() -> PackedStringArray:",
		"\tvar path: String = loading_tips_file.strip_edges()",
		"\tif path.is_empty() or not FileAccess.file_exists(path):",
		"\t\treturn PackedStringArray()",
		"\treturn loading_tip_lines(FileAccess.get_file_as_string(path))",
		"",
		"## Starts one background load with a screen over it, or does nothing at all if another is",
		"## already running - the same one-at-a-time rule the two transitions follow. The order matters:",
		"## the poller is parented to the ROOT before the loading screen is swapped in, so it is the one",
		"## thing in the change that does not die with the scene the row was standing in.",
		"## @ace_hidden",
		"func _start_loading(path: String, min_seconds: float, wait_for_key: bool) -> void:",
		"\tvar scene_path: String = path.strip_edges()",
		"\tif scene_path.is_empty() or is_loading():",
		"\t\treturn",
		"\tif ResourceLoader.load_threaded_request(scene_path) != OK:",
		"\t\tpush_warning(\"Scene Flow cannot start loading %s - check that the path is a scene that exists.\" % scene_path)",
		"\t\treturn",
		"\tvar runner: LoadingRunner = LoadingRunner.new()",
		"\trunner.target_path = scene_path",
		"\trunner.min_seconds = maxf(min_seconds, 0.0)",
		"\trunner.wait_for_key = wait_for_key",
		"\trunner.tip = loading_tip_at(_loading_tips(), randi())",
		"\trunner.shape = loading_transition",
		"\trunner.cover_seconds = fade_seconds",
		"\trunner.cover_color = fade_color",
		"\trunner.wipe_image = wipe_image",
		"\tget_tree().root.add_child(runner)",
		"\tvar screen: String = loading_scene.strip_edges()",
		"\tif screen.is_empty():",
		"\t\t# No screen of their own: the wait still happens, with the reading and the two triggers,",
		"\t\t# wherever the player is standing.",
		"\t\treturn",
		"\tif loading_transition == LOADING_NO_TRANSITION or is_transitioning():",
		"\t\tget_tree().change_scene_to_file(screen)",
		"\telse:",
		"\t\t_start_transition(screen, loading_transition, fade_seconds, \"smooth\")"
	])


## Pre-fills the last-appended ACE's parameter default, so the dialog opens with a usable value
## (authoring-time metadata only - defaults never appear in the compiled .gd).
## A dropdown key is inserted into the call verbatim, so a String argument picked from a list of words
## has to carry its own quotes in the TEMPLATE - a quoted key does not survive the annotation round
## trip (the emitter wraps it again and the scanner strips one pair back off). The call prefix is the
## pack's own class name, the same one the automatic template uses.
static func _quoted_argument(sheet: EventSheetResource, call: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	fn.codegen_template_override = "$%s.%s" % [sheet.custom_class_name, call]


## Sets the help text on the last-appended ACE's parameter - the line the params dialog shows under
## the field. It is also what CARRIES the starting value into the shipped pack: the emitter writes a
## parameter's default only on the one-line @ace_param form, and only a parameter that has something
## to say gets that form. So a row whose default matters says what the field is for.
static func _param_desc(sheet: EventSheetResource, param_id: String, help: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.description = help
			parameter.desc = help


static func _default(sheet: EventSheetResource, param_id: String, value: String) -> void:
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.default_value = value


## Sets the dropdown options[] on the last-appended ACE's parameter, so the shape and the ease are
## picked from the list rather than spelled by hand.
static func _param_options(sheet: EventSheetResource, param_id: String, choices: Array) -> void:
	var typed: Array[String] = []
	for choice: Variant in choices:
		typed.append(str(choice))
	var fn: EventFunction = sheet.functions[sheet.functions.size() - 1]
	for parameter: ACEParam in fn.params:
		if parameter.id == param_id:
			parameter.options = typed
