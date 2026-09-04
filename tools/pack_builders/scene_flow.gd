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
		"wipe_image": {"type": "Texture2D", "default": null, "exported": true, "attributes": {"tooltip": "The greyscale picture a wipe transition follows: its dark parts are covered first and its light parts last, so a ramp is a bar wipe, a radial ramp is a clock, and a painted shape is whatever you painted. Empty is a plain left-to-right sweep."}}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Scene Flow behavior: scene changes with a polished fade, from one node. The fade runner parents itself to the TREE ROOT (not the dying scene), so the fade-out, the swap, and the fade-in all survive the change. Fade To Scene / Go To Scene / Fade Reload / Reload / Quit Game cover a whole menu's needs with zero code. Go To Scene With and Reload Scene With draw a shape over the change instead - fade, wipe, dissolve, iris, blinds, pixelate or page curl - and On Transition Finished fires on the Scene Flow node in the scene it arrived at."
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
	_default(sheet, "seconds", "0.6")
	_default(sheet, "ease", "smooth")
	_param_options(sheet, "ease", ["linear", "smooth", "in", "out"])
	_quoted_argument(sheet, "go_to_scene_with({path}, \"{transition}\", {seconds}, \"{ease}\")")

	Lib.append_function(sheet, "reload_scene_with", "Reload Scene With", "Scenes",
		"Reloads the current scene with a transition drawn over it - the polished retry, in whichever shape the game uses everywhere else. Same shapes, same cover colour and same one-at-a-time rule as Go To Scene With; emits On Transition Finished when the fresh scene is up.",
		[["transition", "String"], ["seconds", "float"], ["ease", "String"]],
		"_start_transition(\"\", transition, seconds, ease)")
	_default(sheet, "transition", "fade")
	_param_options(sheet, "transition", ["fade", "wipe", "dissolve", "iris", "blinds", "pixelate", "page curl"])
	_default(sheet, "seconds", "0.6")
	_default(sheet, "ease", "smooth")
	_param_options(sheet, "ease", ["linear", "smooth", "in", "out"])
	_quoted_argument(sheet, "reload_scene_with(\"{transition}\", {seconds}, \"{ease}\")")

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.verb_sentences(sheet, {
		"fade_to_scene": "Fade to scene [b]{path}[/b]",
		"go_to_scene_with": "Go to scene [b]{path}[/b] with a [b]{transition}[/b] over [b]{seconds}[/b] s",
		"reload_scene_with": "Reload with a [b]{transition}[/b] over [b]{seconds}[/b] s",
	})
	Lib.feature_verbs(sheet, ["fade_to_scene", "go_to_scene_with"])
	if not Lib.save_pack(sheet, "res://eventsheet_addons/scene_flow/scene_flow_behavior"):
		return false
	# THE SHADERS ARE THE TRANSITIONS: a shape whose file is missing draws nothing, so they ship in
	# the same build as the script that loads them.
	return Lib.ship_files("scene_flow", "res://eventsheet_addons/scene_flow/scene_flow_behavior",
		PackedStringArray(["gdshader"]))


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
		"## Starts one shaded transition, or does nothing at all if another is already running - the same",
		"## one-at-a-time rule the shipped fade follows.",
		"## @ace_hidden",
		"func _start_transition(path: String, shape: String, seconds: float, ease_word: String) -> void:",
		"\tif is_transitioning():",
		"\t\treturn",
		"\tvar runner: ShaderTransitionRunner = ShaderTransitionRunner.new()",
		"\trunner.shape = shape",
		"\trunner.seconds = maxf(seconds, 0.1)",
		"\trunner.ease_word = ease_word",
		"\trunner.cover_color = fade_color",
		"\trunner.wipe_image = wipe_image",
		"\trunner.target_path = path",
		"\tget_tree().root.add_child(runner)"
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
