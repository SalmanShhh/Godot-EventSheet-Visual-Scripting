## @ace_category("Scenes")
## @ace_expose_all(node)
## @ace_version(1.0.0)
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

## Fires when a transition started by Go To Scene With or Reload Scene With has finished: the new
## scene is up and the cover is off. It arrives on the Scene Flow node in the NEW scene, carrying the
## shape the transition was, so one handler can tell a wipe from an iris.
## @ace_trigger
## @ace_name("On Transition Finished")
signal transition_finished(shape: String)

## The cover colour the screen fades through.
@export var fade_color: Color = Color(0.0, 0.0, 0.0, 1.0)
## Fade-out (and fade-in) duration in seconds.
@export_range(0.05, 5, 0.05) var fade_seconds: float = 0.4
## The greyscale picture a wipe transition follows: its dark parts are covered first and its light parts last, so a ramp is a bar wipe, a radial ramp is a clock, and a painted shape is whatever you painted. Empty is a plain left-to-right sweep.
@export var wipe_image: Texture2D = null

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

# --- Transitions: a scene change with a shader drawn over it ---

## Where the transition shaders live once the pack is installed, and the name one takes: the word a
## row uses with its spaces closed up, under one prefix. A word and its file can never drift apart.
const TRANSITION_DIRECTORY: String = "res://eventsheet_addons/scene_flow/"
const TRANSITION_PREFIX: String = "transition_"

## The seven shapes a transition can take, by the word a row uses. Each is one shader file with a
## `progress` dial; the two that read the screen back - pixelate and page curl - say so in their own
## first lines, and they only read it while a transition is actually running.
const TRANSITIONS: PackedStringArray = ["fade", "wipe", "dissolve", "iris", "blinds", "pixelate",
	"page curl"]

## The group every running transition joins - the shipped fade above and the shaded ones below alike,
## so Is Transitioning is ONE question with one answer rather than two flags that can disagree.
const TRANSITION_GROUP: StringName = &"scene_flow_transition"

## And the group every Scene Flow node joins, so a finished transition can tell somebody. The runner
## outlives the scene it started in, so the node it tells is whichever one is standing in the NEW
## scene - which is exactly where a row waiting on the arrival wants to be.
const TRANSITION_LISTENERS: StringName = &"scene_flow_listener"

## The root-parented runner that draws a transition and swaps the scene under it. Like the fade
## runner above, it parents itself to the TREE ROOT rather than to the scene being replaced, so the
## walk out, the swap and the walk back in all survive the change.
##
## THE TOP SLOT: it draws above everything, post effects included, because a transition is the one
## thing that must not itself be graded, blurred or vignetted by the look the game happens to be
## wearing. That is ONE rectangle for the whole transition, and the post stack underneath keeps its
## own - a transition never builds a second screen of its own to fight with.
class ShaderTransitionRunner:
	extends CanvasLayer
	var shape: String = "fade"
	var seconds: float = 0.6
	var ease_word: String = "smooth"
	var cover_color: Color = Color.BLACK
	var wipe_image: Texture2D = null
	var target_path: String = ""
	var _rect: ColorRect = null
	var _material: ShaderMaterial = null
	var _walked: float = 0.0
	var _swapped: bool = false

	func _ready() -> void:
		add_to_group(SceneFlowBehavior.TRANSITION_GROUP)
		layer = 128
		var shader: Shader = SceneFlowBehavior.transition_shader(shape)
		if shader == null:
			# A shape with no shader must not leave the screen covered for ever: do the swap this
			# row asked for, plainly, and go.
			_swap()
			_finish()
			return
		_material = ShaderMaterial.new()
		_material.shader = shader
		_material.set_shader_parameter("progress", 0.0)
		_material.set_shader_parameter("cover_color", cover_color)
		if wipe_image != null:
			_material.set_shader_parameter("wipe_image", wipe_image)
			_material.set_shader_parameter("use_image", 1.0)
		_rect = ColorRect.new()
		_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_rect.material = _material
		add_child(_rect)
		set_process(true)

	func _process(delta: float) -> void:
		# A transition is measured in seconds a PLAYER waits, so a slowmo running underneath it must
		# not stretch it: the frame's own time is put back through the time scale it was scaled by.
		_walked += delta / maxf(Engine.time_scale, 0.0001)
		var fraction: float = clampf(_walked / maxf(seconds, 0.1), 0.0, 1.0)
		if _material != null:
			_material.set_shader_parameter("progress",
				SceneFlowBehavior.transition_cover(fraction, ease_word))
		if not _swapped and fraction >= 0.5:
			_swapped = true
			_swap()
		if fraction >= 1.0:
			_finish()

	func _swap() -> void:
		if target_path.is_empty():
			get_tree().reload_current_scene()
		else:
			get_tree().change_scene_to_file(target_path)

	func _finish() -> void:
		set_process(false)
		for listener: Node in get_tree().get_nodes_in_group(SceneFlowBehavior.TRANSITION_LISTENERS):
			if listener.has_signal("transition_finished"):
				listener.emit_signal("transition_finished", shape)
		queue_free()
## The shader one shape wears, loaded from the pack folder beside this script. A word that is not a
## shape, or one whose file is missing, is a warning and a plain swap rather than a covered screen
## nobody can get out of.
static func transition_shader(shape: String) -> Shader:
	var word: String = shape.strip_edges().to_lower()
	if not TRANSITIONS.has(word):
		push_warning("Scene Flow: no transition is called \"%s\" - the shapes are %s." % [
			shape, ", ".join(TRANSITIONS)])
		return null
	var path: String = TRANSITION_DIRECTORY + TRANSITION_PREFIX + word.replace(" ", "_") + ".gdshader"
	if not ResourceLoader.exists(path):
		push_warning("Scene Flow has no shader file for the \"%s\" transition at %s." % [word, path])
		return null
	return load(path) as Shader

func _ready() -> void:
	# Every Scene Flow node listens for a finished transition, because the one that hears it is the one
	# standing in the scene the transition arrived at.
	add_to_group(TRANSITION_LISTENERS)

## @ace_action
## @ace_featured
## @ace_name("Fade To Scene")
## @ace_category("Scenes")
## @ace_description("Fades the screen out, changes to the scene, and fades back in (ignored while a transition runs).")
## @ace_display_template("Fade to scene [b]{path}[/b]")
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

## @ace_action
## @ace_featured
## @ace_name("Go To Scene With")
## @ace_category("Scenes")
## @ace_description("Changes to the scene with a transition drawn over it: the shape walks on over the first half, the scene is swapped under the cover, and it walks off again over the second. The shapes are fade, wipe (following the Wipe Image knob), dissolve, iris, blinds, pixelate and page curl. The cover colour is the node's Fade Color. Ignored while a transition is already running; emits On Transition Finished when the new scene is up and the cover is off.")
## @ace_display_template("Go to scene [b]{path}[/b] with a [b]{transition}[/b] over [b]{seconds}[/b] s")
## @ace_param_options(transition fade, wipe, dissolve, iris, blinds, pixelate, page curl)
## @ace_param_options(ease linear, smooth, in, out)
## @ace_icon("res://eventsheet_addons/scene_flow/icon.svg")
## @ace_codegen_template("$SceneFlowBehavior.go_to_scene_with({path}, "{transition}", {seconds}, "{ease}")")
func go_to_scene_with(path: String, transition: String, seconds: float, ease: String) -> void:
	if path.strip_edges().is_empty():
		return
	_start_transition(path.strip_edges(), transition, seconds, ease)

## @ace_action
## @ace_name("Reload Scene With")
## @ace_category("Scenes")
## @ace_description("Reloads the current scene with a transition drawn over it - the polished retry, in whichever shape the game uses everywhere else. Same shapes, same cover colour and same one-at-a-time rule as Go To Scene With; emits On Transition Finished when the fresh scene is up.")
## @ace_display_template("Reload with a [b]{transition}[/b] over [b]{seconds}[/b] s")
## @ace_param_options(transition fade, wipe, dissolve, iris, blinds, pixelate, page curl)
## @ace_param_options(ease linear, smooth, in, out)
## @ace_icon("res://eventsheet_addons/scene_flow/icon.svg")
## @ace_codegen_template("$SceneFlowBehavior.reload_scene_with("{transition}", {seconds}, "{ease}")")
func reload_scene_with(transition: String, seconds: float, ease: String) -> void:
	_start_transition("", transition, seconds, ease)

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

## HOW COVERED THE SCREEN IS at a point in the walk: nothing at the start, everything at the halfway
## mark where the scene is exchanged, and nothing again at the end. ONE progress model, so the
## shader, the swap and anything asking about the walk are reading the same triangle rather than
## three of their own.
##
## The ease words are what the walk feels like on the way up and back: linear is a constant speed,
## smooth eases both ends, in starts slowly and out arrives slowly.
static func transition_cover(fraction: float, ease_word: String) -> float:
	var walk: float = clampf(fraction, 0.0, 1.0)
	var cover: float = 1.0 - absf(1.0 - walk * 2.0)
	match ease_word.strip_edges().to_lower():
		"smooth":
			return smoothstep(0.0, 1.0, cover)
		"in":
			return cover * cover
		"out":
			return 1.0 - (1.0 - cover) * (1.0 - cover)
		_:
			return cover

## Which part of the walk a point is in: "out" while the cover is coming on, "swap" at the midpoint
## where the scene is exchanged, "in" while the cover is coming off the new one.
static func transition_phase(fraction: float) -> String:
	var walk: float = clampf(fraction, 0.0, 1.0)
	if is_equal_approx(walk, 0.5):
		return "swap"
	return "out" if walk < 0.5 else "in"

## @ace_hidden
func _start_transition(path: String, shape: String, seconds: float, ease_word: String) -> void:
	if is_transitioning():
		return
	var runner: ShaderTransitionRunner = ShaderTransitionRunner.new()
	runner.shape = shape
	runner.seconds = maxf(seconds, 0.1)
	runner.ease_word = ease_word
	runner.cover_color = fade_color
	runner.wipe_image = wipe_image
	runner.target_path = path
	get_tree().root.add_child(runner)

# Scene Flow behavior: scene changes with a polished fade, from one node. The fade runner parents itself to the TREE ROOT (not the dying scene), so the fade-out, the swap, and the fade-in all survive the change. Fade To Scene / Go To Scene / Fade Reload / Reload / Quit Game cover a whole menu's needs with zero code. Go To Scene With and Reload Scene With draw a shape over the change instead - fade, wipe, dissolve, iris, blinds, pixelate or page curl - and On Transition Finished fires on the Scene Flow node in the scene it arrived at.
