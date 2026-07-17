## @ace_category("Scenes")
## @ace_expose_all(node)
@icon("res://eventsheet_addons/scene_flow/icon.svg")
class_name SceneFlowBehavior
extends Node
## Polished scene changes from one node: fade to another scene, fade-reload the current one, jump or reload instantly, and quit the game. The fade overlay parents itself to the tree root instead of the dying scene, so the transition survives the swap instead of vanishing halfway through.

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("SceneFlowBehavior behavior requires a Node parent.")

## The cover colour the screen fades through.
@export var fade_color: Color = Color(0.0, 0.0, 0.0, 1.0)
## Fade-out (and fade-in) duration in seconds.
@export_range(0.05, 5, 0.05) var fade_seconds: float = 0.4

## The root-parented fade overlay: fades out, swaps (or reloads) the scene, fades back in,
## then frees itself. Lives under the tree root so the running tween outlives the old scene;
## the "scene_flow_transition" group is the busy flag Is Transitioning reads.
class TransitionRunner:
	extends CanvasLayer
	var fade_seconds: float = 0.4
	var fade_color: Color = Color.BLACK
	var target_path: String = ""
	var _rect: ColorRect = null

	func _ready() -> void:
		add_to_group("scene_flow_transition")
		layer = 128
		_rect = ColorRect.new()
		_rect.color = fade_color
		_rect.modulate.a = 0.0
		_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_rect)
		var fade: Tween = create_tween()
		fade.tween_property(_rect, "modulate:a", 1.0, fade_seconds)
		fade.tween_callback(_swap)
		fade.tween_property(_rect, "modulate:a", 0.0, fade_seconds)
		fade.tween_callback(queue_free)

	func _swap() -> void:
		if target_path.is_empty():
			get_tree().reload_current_scene()
		else:
			get_tree().change_scene_to_file(target_path)

## @ace_action
## @ace_name("Fade To Scene")
## @ace_category("Scenes")
## @ace_description("Fades the screen out, changes to the scene, and fades back in (ignored while a transition runs).")
## @ace_icon("res://eventsheet_addons/scene_flow/icon.svg")
## @ace_codegen_template("$SceneFlowBehavior.fade_to_scene({path})")
func fade_to_scene(path: String) -> void:
	if path.strip_edges().is_empty():
		return
	_start_fade(path.strip_edges())

## @ace_action
## @ace_name("Fade Reload Scene")
## @ace_category("Scenes")
## @ace_description("Fades out, reloads the current scene, and fades back in - the polished retry button.")
## @ace_icon("res://eventsheet_addons/scene_flow/icon.svg")
## @ace_codegen_template("$SceneFlowBehavior.fade_reload_scene()")
func fade_reload_scene() -> void:
	_start_fade("")

## @ace_action
## @ace_name("Go To Scene")
## @ace_category("Scenes")
## @ace_description("Changes to the scene immediately (no fade).")
## @ace_icon("res://eventsheet_addons/scene_flow/icon.svg")
## @ace_codegen_template("$SceneFlowBehavior.go_to_scene({path})")
func go_to_scene(path: String) -> void:
	if not path.strip_edges().is_empty():
		get_tree().change_scene_to_file(path.strip_edges())

## @ace_action
## @ace_name("Reload Scene")
## @ace_category("Scenes")
## @ace_description("Reloads the current scene immediately (no fade).")
## @ace_icon("res://eventsheet_addons/scene_flow/icon.svg")
## @ace_codegen_template("$SceneFlowBehavior.reload_scene()")
func reload_scene() -> void:
	get_tree().reload_current_scene()

## @ace_action
## @ace_name("Quit Game")
## @ace_category("Scenes")
## @ace_description("Quits the game (a no-op on platforms that forbid it, like web).")
## @ace_icon("res://eventsheet_addons/scene_flow/icon.svg")
## @ace_codegen_template("$SceneFlowBehavior.quit_game()")
func quit_game() -> void:
	get_tree().quit()

## @ace_condition
## @ace_name("Is Transitioning")
## @ace_icon("res://eventsheet_addons/scene_flow/icon.svg")
## @ace_codegen_template("$SceneFlowBehavior.is_transitioning()")
func is_transitioning() -> bool:
	return not get_tree().get_nodes_in_group("scene_flow_transition").is_empty()

## @ace_expression
## @ace_name("Current Scene Path")
## @ace_icon("res://eventsheet_addons/scene_flow/icon.svg")
## @ace_codegen_template("$SceneFlowBehavior.current_scene_path()")
func current_scene_path() -> String:
	var current: Node = get_tree().current_scene
	return current.scene_file_path if current != null else ""

func _start_fade(path: String) -> void:
	if is_transitioning():
		return
	var runner: TransitionRunner = TransitionRunner.new()
	runner.fade_seconds = maxf(0.05, fade_seconds)
	runner.fade_color = fade_color
	runner.target_path = path
	get_tree().root.add_child(runner)

# Scene Flow behavior: scene changes with a polished fade, from one node. The fade runner parents itself to the TREE ROOT (not the dying scene), so the fade-out, the swap, and the fade-in all survive the change. Fade To Scene / Go To Scene / Fade Reload / Reload / Quit Game cover a whole menu's needs with zero code.
