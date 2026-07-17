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
		"fade_seconds": {"type": "float", "default": 0.4, "exported": true, "attributes": {"tooltip": "Fade-out (and fade-in) duration in seconds.", "range": {"min": "0.05", "max": "5", "step": "0.05"}}},
		"fade_color": {"type": "Color", "default": Color(0, 0, 0, 1), "exported": true, "attributes": {"tooltip": "The cover colour the screen fades through."}}
	}
	var about: CommentRow = CommentRow.new()
	about.text = "Scene Flow behavior: scene changes with a polished fade, from one node. The fade runner parents itself to the TREE ROOT (not the dying scene), so the fade-out, the swap, and the fade-in all survive the change. Fade To Scene / Go To Scene / Fade Reload / Reload / Quit Game cover a whole menu's needs with zero code."
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

	# The pack's hero verbs: starred + bold at the top of their picker section.
	Lib.feature_verbs(sheet, ["fade_to_scene"])
	return Lib.save_pack(sheet, "res://eventsheet_addons/scene_flow/scene_flow_behavior")
