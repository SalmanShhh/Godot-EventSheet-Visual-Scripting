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
## Fires every time the loading reading MOVES, on the Scene Flow node standing in the loading
## screen - which is exactly where a row that sets a bar wants to be. It carries nothing:
## Loading Progress answers with the number, so the row reads as a sentence.
## @ace_trigger
## @ace_name("On Loading Progress")
signal loading_progress_changed
## Fires once when the wait is over: the scene is off the disk AND the minimum seconds have
## been served. With Wait For Key off the swap follows immediately; with it on, this is the
## moment to show "press any key", and Enter Loaded Scene is what the key does.
## @ace_trigger
## @ace_name("On Loading Finished")
signal loading_finished

## The cover colour the screen fades through.
@export var fade_color: Color = Color(0.0, 0.0, 0.0, 1.0)
## Fade-out (and fade-in) duration in seconds.
@export_range(0.05, 5, 0.05) var fade_seconds: float = 0.4
## The greyscale picture a wipe transition follows: its dark parts are covered first and its light parts last, so a ramp is a bar wipe, a radial ramp is a clock, and a painted shape is whatever you painted. Empty is a plain left-to-right sweep.
@export var wipe_image: Texture2D = null
## The screen shown while Go To Scene With Loading waits for the next scene. The pack ships loading_screen.tscn as a starter to copy and restyle; empty means no screen at all, and the wait happens where the player is standing.
@export_file("*.tscn", "*.scn") var loading_scene: String = ""
## The shape drawn over BOTH halves of a loading change: onto the loading screen and off it again into the new scene. The same wardrobe Go To Scene With picks from, held over the node's Fade Seconds. None swaps plainly.
@export_enum("none", "fade", "wipe", "dissolve", "iris", "blinds", "pixelate", "page curl") var loading_transition: String = "fade"
## A text file of tips, one per line, that Loading Tip picks from - one tip is chosen when the load starts and stays put for the whole wait. The pack ships tips.txt as a starter; the file is yours, and a line starting with # is a note to yourself. Add *.txt to the export filters so it ships with the game.
@export_file("*.txt") var loading_tips_file: String = ""

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

## THE ACCESSIBILITY FLOOR. A player who has asked for no flashing gets the same transition in the
## same shape, held over this many seconds - because a shape that sweeps the whole screen and back
## in a tenth of a second is a flash whatever shape it is. This is the same floor the post stack
## holds its walks over, read off the same Engine meta the built-in Set No Flashing row writes.
const TRANSITION_FLASH_FLOOR_SECONDS: float = 0.4
const TRANSITION_NO_FLASHING_META: StringName = &"no_flashing"

## And the shortest a transition may be when nobody has asked for anything: short enough to feel
## instant, long enough that the swap still happens under cover.
const TRANSITION_FLOOR_SECONDS: float = 0.1

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

# --- Loading screens: a screen of your own while the next scene comes off the disk ---

## The group the one running background load joins, so Is Loading, Loading Progress and
## Loading Tip are ONE question with one answer rather than three fields that can disagree.
## It is a group rather than a member because the poller OUTLIVES the scene the row was in:
## the node that started the load is replaced by the loading screen a moment later.
const LOADING_GROUP: StringName = &"scene_flow_loading"

## The word that means "no shape over the change" in the Loading Transition knob. Every other
## word in that list is one of the shapes above, so a loading change wears the same wardrobe
## the rest of the game's changes do.
const LOADING_NO_TRANSITION: String = "none"

## The line a tips file leaves out: a comment, so a file of tips can carry a note about itself
## and a tip can be parked without being deleted.
const LOADING_TIP_COMMENT: String = "#"

## The root-parented poller that holds one background load: it asks the loader how far it has
## got, tells the loading screen, and enters the new scene when the wait is over. Like the two
## transition runners above it lives under the TREE ROOT, because the row that started it is
## standing in a scene that is about to be replaced by the loading screen.
class LoadingRunner:
	extends Node
	var target_path: String = ""
	var min_seconds: float = 1.0
	var wait_for_key: bool = false
	var tip: String = ""
	var shape: String = "none"
	var cover_seconds: float = 0.4
	var cover_color: Color = Color.BLACK
	var wipe_image: Texture2D = null
	var reading: float = 0.0
	var finished: bool = false
	var _elapsed: float = 0.0
	var _entering: bool = false
	# The loaded scene, held from the moment it lands until the swap has actually happened. A
	# threaded load nobody is holding can be dropped again before a covered change reaches its
	# halfway mark, and the second read off the disk is the hitch the whole screen was for.
	var _held_scene: PackedScene = null

	func _ready() -> void:
		add_to_group(SceneFlowBehavior.LOADING_GROUP)
		# A loading screen goes on loading while the game is paused: a pause menu that leads into
		# a level is the ordinary case rather than a strange one.
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_process(true)

	func _process(delta: float) -> void:
		if _entering:
			# Holding the scene until the cover is off, and then there is nothing left to hold.
			if get_tree().get_nodes_in_group(SceneFlowBehavior.TRANSITION_GROUP).is_empty():
				queue_free()
			return
		# The minimum is seconds a PLAYER waits, so a slowmo running underneath must not stretch
		# it: the frame's own time is put back through the time scale it was scaled by.
		_elapsed += delta / maxf(Engine.time_scale, 0.0001)
		var seen: Array = []
		var status: int = ResourceLoader.load_threaded_get_status(target_path, seen)
		if status == ResourceLoader.THREAD_LOAD_FAILED \
				or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_warning("Scene Flow could not load %s, so the loading screen is where the game stays." % target_path)
			queue_free()
			return
		var now: float = SceneFlowBehavior.loading_reading(
			float(seen[0]) if not seen.is_empty() else 0.0, _elapsed, min_seconds)
		if not is_equal_approx(now, reading):
			reading = now
			_tell("loading_progress_changed")
		if finished:
			return
		if not SceneFlowBehavior.loading_wait_is_over(status, _elapsed, min_seconds):
			return
		finished = true
		_tell("loading_finished")
		if not wait_for_key:
			enter()

	## Swaps to the scene this runner has been waiting for, under the loading transition when the
	## node asked for one. Does NOTHING while the wait is still on, which is what makes a bare
	## "any key pressed -> Enter Loaded Scene" row safe to leave on the loading screen.
	func enter() -> void:
		if _entering or not finished:
			return
		var packed: PackedScene = ResourceLoader.load_threaded_get(target_path) as PackedScene
		if packed == null:
			push_warning("Scene Flow loaded %s and it is not a scene, so there is nothing to enter." % target_path)
			queue_free()
			return
		_entering = true
		_held_scene = packed
		var word: String = shape.strip_edges().to_lower()
		var busy: bool = not get_tree().get_nodes_in_group(
			SceneFlowBehavior.TRANSITION_GROUP).is_empty()
		if busy or word.is_empty() or word == SceneFlowBehavior.LOADING_NO_TRANSITION:
			get_tree().change_scene_to_packed(packed)
			queue_free()
			return
		var runner: SceneFlowBehavior.ShaderTransitionRunner = \
			SceneFlowBehavior.ShaderTransitionRunner.new()
		runner.shape = word
		runner.seconds = maxf(cover_seconds, SceneFlowBehavior.transition_floor_seconds())
		runner.ease_word = "smooth"
		runner.cover_color = cover_color
		runner.wipe_image = wipe_image
		# The PATH rather than the scene object, because the shipped runner swaps by path - and
		# the file it names is the one held above, so the swap comes out of the cache instead of
		# off the disk a second time.
		runner.target_path = target_path
		get_tree().root.add_child(runner)

	## Tells every Scene Flow node in the tree, which is the same address the finished transition
	## uses: the node that hears it is the one standing in the loading screen.
	func _tell(what: String) -> void:
		for listener: Node in get_tree().get_nodes_in_group(
				SceneFlowBehavior.TRANSITION_LISTENERS):
			if listener.has_signal(what):
				listener.emit_signal(what)
## Whether the runner walks into the new scene by itself at that point, which it does unless the
## row asked to wait for a key - the press-any-key screen.
## @ace_hidden
static func loading_enters_itself(status: int, elapsed: float, min_seconds: float,
		wait_for_key: bool) -> bool:
	return loading_wait_is_over(status, elapsed, min_seconds) and not wait_for_key
## The running load, or null when nothing is loading. One at a time by construction: the group
## holds at most one runner because Go To Scene With Loading refuses while one is alive.
## @ace_hidden
func _loading_runner() -> LoadingRunner:
	if not is_inside_tree():
		return null
	for node: Node in get_tree().get_nodes_in_group(LOADING_GROUP):
		return node as LoadingRunner
	return null

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
## @ace_param(path, default: ProjectSettings.get_setting("application/run/main_scene"), desc: "The scene to open. Its res:// path in quotes, or an expression that answers with one - it starts at the project's own main scene.")
## @ace_param(transition, options: fade|wipe|dissolve|iris|blinds|pixelate|page curl, default: fade, desc: "The shape drawn over the change. Wipe follows the node's Wipe Image; pixelate and page curl read the screen back while they run.")
## @ace_param(seconds, default: 0.6, desc: "How long the whole change takes, on and off again. Held over a floor while no flashing is on.")
## @ace_param(ease, options: linear|smooth|in|out, default: smooth, desc: "What the walk feels like: linear is one speed, smooth eases both ends, in starts slowly, out arrives slowly.")
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
## @ace_param(transition, options: fade|wipe|dissolve|iris|blinds|pixelate|page curl, default: fade, desc: "The shape drawn over the reload. Wipe follows the node's Wipe Image; pixelate and page curl read the screen back while they run.")
## @ace_param(seconds, default: 0.6, desc: "How long the whole reload takes, on and off again. Held over a floor while no flashing is on.")
## @ace_param(ease, options: linear|smooth|in|out, default: smooth, desc: "What the walk feels like: linear is one speed, smooth eases both ends, in starts slowly, out arrives slowly.")
## @ace_icon("res://eventsheet_addons/scene_flow/icon.svg")
## @ace_codegen_template("$SceneFlowBehavior.reload_scene_with("{transition}", {seconds}, "{ease}")")
func reload_scene_with(transition: String, seconds: float, ease: String) -> void:
	_start_transition("", transition, seconds, ease)

## @ace_action
## @ace_featured
## @ace_name("Go To Scene With Loading")
## @ace_category("Scenes")
## @ace_description("Shows the node's Loading Scene while the next scene comes off the disk on a thread, then enters it. The wait is over when BOTH the load has finished and the minimum seconds have passed, so the screen cannot flash past on a fast machine; On Loading Progress moves a bar through Loading Progress, and Loading Tip answers with one line of the tips file. With Wait For Key on it stops there and waits for Enter Loaded Scene. The node's Loading Transition wraps both halves of the change.")
## @ace_display_template("Go to scene [b]{scene}[/b] with loading, at least [b]{min_seconds}[/b] s")
## @ace_param(scene, desc: "The scene to open. Its res:// path, or an expression that answers with one.")
## @ace_param(min_seconds, default: 1.0, desc: "The shortest the loading screen stays up, in seconds. One second is enough to be read as a beat rather than as a flicker; zero enters the moment the load lands.")
## @ace_param(wait_for_key, default: false, desc: "On: the wait ends at On Loading Finished and the screen stays up until a row runs Enter Loaded Scene - the press-any-key screen. Off: the new scene is entered as soon as the wait is over.")
## @ace_icon("res://eventsheet_addons/scene_flow/icon.svg")
## @ace_codegen_template("$SceneFlowBehavior.go_to_with_loading({scene}, {min_seconds}, {wait_for_key})")
func go_to_with_loading(scene: String, min_seconds: float, wait_for_key: bool) -> void:
	_start_loading(scene, min_seconds, wait_for_key)

## @ace_action
## @ace_name("Enter Loaded Scene")
## @ace_category("Scenes")
## @ace_description("Enters the scene a loading screen has been holding. Does nothing at all while the wait is still on, so a bare "any key pressed" row is safe to leave on the loading screen; it is what Wait For Key waits for.")
## @ace_icon("res://eventsheet_addons/scene_flow/icon.svg")
## @ace_codegen_template("$SceneFlowBehavior.enter_loaded_scene()")
func enter_loaded_scene() -> void:
	var runner: LoadingRunner = _loading_runner()
	if runner != null:
		runner.enter()

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

## The shortest a transition may be right now: the ordinary floor, or the accessibility one for a
## player who has asked for no flashing. A transition is one of the three things this project holds
## over that floor, beside a post-stack walk and a moment step.
## @ace_hidden
static func transition_floor_seconds() -> float:
	if bool(Engine.get_meta(TRANSITION_NO_FLASHING_META, false)):
		return TRANSITION_FLASH_FLOOR_SECONDS
	return TRANSITION_FLOOR_SECONDS

## Starts one shaded transition, or does nothing at all if another is already running - the same
## one-at-a-time rule the shipped fade follows.
## @ace_hidden
func _start_transition(path: String, shape: String, seconds: float, ease_word: String) -> void:
	if is_transitioning():
		return
	var runner: ShaderTransitionRunner = ShaderTransitionRunner.new()
	runner.shape = shape
	runner.seconds = maxf(seconds, transition_floor_seconds())
	runner.ease_word = ease_word
	runner.cover_color = fade_color
	runner.wipe_image = wipe_image
	runner.target_path = path
	get_tree().root.add_child(runner)

## HOW FAR THE WAIT HAS GOT, from 0 to 1 - what Loading Progress answers with and what a bar is
## set to. It is the SLOWER of the two things being waited on: how much of the scene is off the
## disk, and how much of the minimum time has been served. A bar that races to the end and then
## sits there reads as a hang, so this one never runs ahead of the wait it belongs to.
## @ace_hidden
static func loading_reading(loaded: float, elapsed: float, min_seconds: float) -> float:
	var by_disk: float = clampf(loaded, 0.0, 1.0)
	if min_seconds <= 0.0:
		return by_disk
	return minf(by_disk, clampf(elapsed / min_seconds, 0.0, 1.0))

## Whether the wait is over: the scene is off the disk AND the minimum has been served. The two
## are one question, which is what makes a fast machine and a slow one spend the same beat on
## the screen instead of one of them flashing it past.
## @ace_hidden
static func loading_wait_is_over(status: int, elapsed: float, min_seconds: float) -> bool:
	return status == ResourceLoader.THREAD_LOAD_LOADED and elapsed >= min_seconds

## The tips a tips file holds: one per line, blank lines dropped, and a line starting with # left
## out so a file can carry a note about itself. The file is the PROJECT'S - the pack ships one to
## copy and never a list of tips of its own.
## @ace_hidden
static func loading_tip_lines(text: String) -> PackedStringArray:
	var tips: PackedStringArray = PackedStringArray()
	for raw_line: String in text.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.is_empty() or line.begins_with(LOADING_TIP_COMMENT):
			continue
		tips.append(line)
	return tips

## The tip at a position, wrapping round, so any number at all picks one and an empty file
## answers with an empty string rather than reaching past the end of the list.
## @ace_hidden
static func loading_tip_at(tips: PackedStringArray, index: int) -> String:
	if tips.is_empty():
		return ""
	return tips[posmod(index, tips.size())]

## Whether a background load started by Go To Scene With Loading is still in flight. It stays
## true while the screen is up - including the beat where it is waiting for a key, and the
## covered change into the new scene - so a row can gate anything on "still loading".
## @ace_condition
## @ace_name("Is Loading")
## @ace_icon("res://eventsheet_addons/scene_flow/icon.svg")
## @ace_codegen_template("$SceneFlowBehavior.is_loading()")
func is_loading() -> bool:
	return _loading_runner() != null

## How far the wait has got, from 0 to 1. Multiply by 100 for a percentage, or set a bar whose
## maximum is 1 straight from it. Zero when nothing is loading.
## @ace_expression
## @ace_name("Loading Progress")
## @ace_icon("res://eventsheet_addons/scene_flow/icon.svg")
## @ace_codegen_template("$SceneFlowBehavior.loading_progress()")
func loading_progress() -> float:
	var runner: LoadingRunner = _loading_runner()
	return runner.reading if runner != null else 0.0

## The one line picked out of the tips file when this load started. It stays put for the whole
## wait, because a tip that changes while somebody is reading it is worse than no tip. Empty
## when there is no tips file, or nothing is loading.
## @ace_expression
## @ace_name("Loading Tip")
## @ace_icon("res://eventsheet_addons/scene_flow/icon.svg")
## @ace_codegen_template("$SceneFlowBehavior.loading_tip()")
func loading_tip() -> String:
	var runner: LoadingRunner = _loading_runner()
	return runner.tip if runner != null else ""

## The tips this node's tips file holds, or none at all when it has no file. Read on each load
## rather than kept, so editing the file while the game runs shows up on the next screen.
## @ace_hidden
func _loading_tips() -> PackedStringArray:
	var path: String = loading_tips_file.strip_edges()
	if path.is_empty() or not FileAccess.file_exists(path):
		return PackedStringArray()
	return loading_tip_lines(FileAccess.get_file_as_string(path))

## Starts one background load with a screen over it, or does nothing at all if another is
## already running - the same one-at-a-time rule the two transitions follow. The order matters:
## the poller is parented to the ROOT before the loading screen is swapped in, so it is the one
## thing in the change that does not die with the scene the row was standing in.
## @ace_hidden
func _start_loading(path: String, min_seconds: float, wait_for_key: bool) -> void:
	var scene_path: String = path.strip_edges()
	if scene_path.is_empty() or is_loading():
		return
	if ResourceLoader.load_threaded_request(scene_path) != OK:
		push_warning("Scene Flow cannot start loading %s - check that the path is a scene that exists." % scene_path)
		return
	var runner: LoadingRunner = LoadingRunner.new()
	runner.target_path = scene_path
	runner.min_seconds = maxf(min_seconds, 0.0)
	runner.wait_for_key = wait_for_key
	runner.tip = loading_tip_at(_loading_tips(), randi())
	runner.shape = loading_transition
	runner.cover_seconds = fade_seconds
	runner.cover_color = fade_color
	runner.wipe_image = wipe_image
	get_tree().root.add_child(runner)
	var screen: String = loading_scene.strip_edges()
	if screen.is_empty():
		# No screen of their own: the wait still happens, with the reading and the two triggers,
		# wherever the player is standing.
		return
	if loading_transition == LOADING_NO_TRANSITION or is_transitioning():
		get_tree().change_scene_to_file(screen)
	else:
		_start_transition(screen, loading_transition, fade_seconds, "smooth")

# Scene Flow behavior: scene changes with a polished fade, from one node. The fade runner parents itself to the TREE ROOT (not the dying scene), so the fade-out, the swap, and the fade-in all survive the change. Fade To Scene / Go To Scene / Fade Reload / Reload / Quit Game cover a whole menu's needs with zero code. Go To Scene With and Reload Scene With draw a shape over the change instead - fade, wipe, dissolve, iris, blinds, pixelate or page curl - and On Transition Finished fires on the Scene Flow node in the scene it arrived at. Go To Scene With Loading puts a screen of your own in the middle of that change while the next scene comes off the disk: On Loading Progress and Loading Progress move a bar, Loading Tip reads a line out of a text file you own, and Enter Loaded Scene is what a press-any-key row does.
