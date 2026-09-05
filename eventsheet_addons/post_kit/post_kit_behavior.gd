## @ace_tags(camera, effects, shader, 3d, visual)
## @ace_category("Post Kit")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/post_kit/icon.svg")
class_name PostKitBehavior
extends Node
## The camera's own post stack, for Forward+: vignette, desaturate, pixelate, tint and fade, under the same names the 2D post stack uses, added by name and pulsed in one row. Plus an outline drawn through walls - mark a group, and a second camera's mask of one visual layer is edge-detected over the frame. Attach it under the Camera3D or the WorldEnvironment that carries the Compositor.

## The node this behavior acts on (its parent). Required host: Node.
var host: Node = null

func _enter_tree() -> void:
	host = get_parent() as Node
	if host == null:
		push_warning("PostKitBehavior behavior requires a Node parent.")

## Where the pack's effect scripts and their compute shaders live once it is installed. The builder
## copies them there beside the pack, so an effect is a file on disk rather than a string.
const EFFECT_DIRECTORY: String = "res://eventsheet_addons/post_kit/effects/"

## The name an effect's script takes: the effect word with its spaces closed up, under one prefix.
## An effect word and its file can therefore never drift apart.
const EFFECT_PREFIX: String = "post_"

## The five effects a row adds by name. They are the words the 2D post stack uses for the same
## looks, so a row reads alike whether it is on the screen or on the camera, and a project that
## moves from one to the other keeps its sheet.
const POST_EFFECTS: PackedStringArray = ["vignette", "desaturate", "pixelate", "tint", "fade"]

## The reserved entry the outline rows wear. It is an ordinary stack entry under a name no Add Post
## Effect row can mint, so Has Post Effect and Post Strength can see it with no second mechanism -
## but it is not in the word list, because an outline with nothing marked has nothing to draw.
const OUTLINE_EFFECT: String = "outline"

## The renderer that has a compositor at all. Mobile and Compatibility have no rendering device to
## hand a compute shader to, so every row here does nothing on them rather than erroring, and the
## ship-it check names it once with the 2D packs as the door.
const FORWARD_PLUS: String = "forward_plus"

## THE ACCESSIBILITY CEILING. A player who has asked for no flashing gets the same rows - a pulse
## still pulses, an outline still lands - with the amplitude held under this and the time held over
## FLASH_FLOOR_SECONDS, so nothing the camera draws can strobe.
const FLASH_CEILING: float = 0.3
const FLASH_FLOOR_SECONDS: float = 0.4

## The two Engine meta this project already keeps its accessibility answers in - the same two the
## built-in Set No Flashing and Set Effect Strength rows write. A game that has those rows needs
## nothing else for the camera to obey them.
const NO_FLASHING_META: StringName = &"no_flashing"
const EFFECT_STRENGTH_META: StringName = &"effect_strength"

## The name the mask viewport takes under this node, so a reader who opens the remote tree during a
## run can see what the outline is made of.
const MASK_NODE_NAME: String = "PostKitMask"

## Which visual layer the mask camera can see, and the one the outline rows switch on for the meshes
## they mark. 20 is the last layer Godot has and the one a project is least likely to be using.
@export_range(1, 20, 1) var mask_layer: int = 20

## THE STACK, in the order the effects are applied: the first entry works on the frame first and the
## last one has the last word. An entry is a small record rather than a node, because the order, the
## names and the strengths are what rows ask about.
##
##   called    the name rows address this entry by (its effect word, when nobody said otherwise)
##   effect    which of the shipped effects it is
##   strength  how far the row ASKED it to go, 0 to 1 - the request, not what reached the frame.
##             The two accessibility dials are applied once, on the way to the CompositorEffect, so
##             a walk that moves this value cannot scale it a second time
##   enabled   whether it is applied at all
##   resource  the CompositorEffect wearing it
var _stack: Array[Dictionary] = []

## The Compositor this node hangs its effects on - the parent's own, when it had one already.
var _compositor: Compositor = null

## The strength walks running right now, keyed by the entry they move, so a second row on the same
## entry replaces the first rather than the two of them fighting over one dial.
var _stack_walks: Dictionary = {}

## The mask rig, built the first time something is outlined and freed when nothing is: a viewport
## with a transparent background and a camera that can see one visual layer and nothing else.
var _mask: SubViewport = null
var _mask_camera: Camera3D = null

## Every visual instance an outline row switched the mask layer on for, so Stop Outlining can switch
## it off again on exactly those and leave the project's own layer bits alone.
var _marked: Array[VisualInstance3D] = []

## Whether this run has already said out loud that there is no compositor here. Once is honest;
## once a frame is noise.
var _said_no_compositor: bool = false
## The camera the effects hang on: the parent, when this behavior was put under one, and otherwise
## whichever camera the viewport is currently drawing through.
func _camera() -> Camera3D:
	if host is Camera3D:
		return host as Camera3D
	var view: Viewport = get_viewport()
	if view == null:
		return null
	return view.get_camera_3d()
## The Compositor the effects are written into: the parent's own when it had one, and a fresh one
## hung on it when it did not. Both a Camera3D and a WorldEnvironment carry one, which is why the
## parent is asked for the property rather than for its class.
func _ensure_compositor() -> Compositor:
	if _compositor != null:
		return _compositor
	if not _has_compositor():
		return null
	if host == null or not ("compositor" in host):
		push_warning("Post Kit expects a Camera3D or a WorldEnvironment as its parent - the node that carries the Compositor.")
		return null
	_compositor = host.get("compositor") as Compositor
	if _compositor == null:
		_compositor = Compositor.new()
		host.set("compositor", _compositor)
	return _compositor
## One effect, built from its own script file. A word with no file draws nothing and says so, which
## is what a pack folder missing its effects looks like from a row.
func _make(effect: String) -> CompositorEffect:
	var script_path: String = EFFECT_DIRECTORY + EFFECT_PREFIX + effect.replace(" ", "") + ".gd"
	var made: GDScript = load(script_path) as GDScript
	if made == null:
		push_warning("Post Kit: the effect \"%s\" has no script at %s." % [effect, script_path])
		return null
	return made.new() as CompositorEffect
## The size the mask viewport should be: the size of the frame the outline is drawn over.
func _view_size() -> Vector2i:
	var view: Viewport = get_viewport()
	if view == null:
		return Vector2i(1, 1)
	var size: Vector2i = Vector2i(view.get_visible_rect().size)
	return Vector2i(maxi(size.x, 1), maxi(size.y, 1))
## The outline entry's effect resource, or null when nothing is being outlined.
func _outline_effect() -> CompositorEffect:
	var at: int = _find(OUTLINE_EFFECT)
	if at < 0:
		return null
	return _stack[at].get("resource", null) as CompositorEffect

func _ready() -> void:
	# Nothing is built here on purpose: a camera with this behavior under it and no rows using it
	# costs one node. The Compositor arrives with the first Add Post Effect, and the mask rig with
	# the first outline.
	set_process(false)

func _process(delta: float) -> void:
	# Only ever running while something is outlined. The mask camera has to stand exactly where the
	# real one does, or the outline would sit beside the thing it belongs to.
	if _mask == null or not is_instance_valid(_mask) or _mask_camera == null:
		set_process(false)
		return
	var camera: Camera3D = _camera()
	if camera == null:
		return
	var want: Vector2i = _view_size()
	if _mask.size != want:
		_mask.size = want
	_mask_camera.global_transform = camera.global_transform
	_mask_camera.projection = camera.projection
	_mask_camera.fov = camera.fov
	_mask_camera.size = camera.size
	_mask_camera.near = camera.near
	_mask_camera.far = camera.far
	_mask_camera.keep_aspect = camera.keep_aspect
	# The mask's texture is handed over every frame rather than once: a viewport that has been
	# resized is a different texture, and an outline pointed at the old one would draw nothing.
	var made: CompositorEffect = _outline_effect()
	if made != null:
		made.set("mask_texture", RenderingServer.texture_get_rd_texture(_mask.get_texture().get_rid()))

## Adds one effect to the end of the camera's post stack and turns it on. The five words are
## vignette, desaturate, pixelate, tint and fade - the same words the 2D post stack uses, so a row
## reads alike on either. Leave the name empty and the entry is called after its effect, which is
## what one of each wants.
##
## FORWARD+ ONLY. Mobile and Compatibility have no compositor, so this row does nothing at all
## there; Screen FX does the same looks on any renderer.
## @ace_action
## @ace_featured
## @ace_name("Add Post Effect")
## @ace_display_template("Add [b]{effect}[/b] at [b]{strength}[/b]")
## @ace_param(effect, options: vignette=Vignette|desaturate=Desaturate|pixelate=Pixelate|tint=Tint|fade=Fade, default: vignette, desc: "Which effect. Each one runs a compute shader over the whole frame, so each one costs a pass over every pixel the camera drew.")
## @ace_param(called, default_word: "", desc: "What later rows address it by. Empty names it after its effect, which is what one of each wants.")
## @ace_param(strength, default: 0.6, desc: "How far it goes, 0 to 1. Scaled by the effect-strength dial, and held under a ceiling while no flashing is on.")
## @ace_icon("res://eventsheet_addons/post_kit/icon.svg")
## @ace_codegen_template("$PostKitBehavior.add_post_effect("{effect}", "{called}", {strength})")
func add_post_effect(effect: String = "vignette", called: String = "", strength: float = 0.6) -> void:
	var word: String = effect.strip_edges().to_lower()
	if not POST_EFFECTS.has(word):
		push_warning("Add Post Effect: no effect is called \"%s\" - the words are %s." % [
			effect, ", ".join(POST_EFFECTS)])
		return
	var name_of_it: String = called.strip_edges().to_lower()
	if name_of_it.is_empty():
		name_of_it = word
	_add_entry(word, name_of_it, strength)

## Takes one effect off the stack, so it stops costing anything at all.
## @ace_action
## @ace_name("Remove Post Effect")
## @ace_display_template("Remove post effect [b]{called}[/b]")
## @ace_param(called, default: vignette, desc: "The name the entry was added under.")
## @ace_icon("res://eventsheet_addons/post_kit/icon.svg")
## @ace_codegen_template("$PostKitBehavior.remove_post_effect("{called}")")
func remove_post_effect(called: String = "vignette") -> void:
	var at: int = _find(called)
	if at < 0:
		return
	_stop_walk_on(str(_stack[at].get("called", "")))
	_stack.remove_at(at)
	_write_effects()

## Turns one effect back on without forgetting how far up it was.
## @ace_action
## @ace_name("Enable Post Effect")
## @ace_display_template("Enable post effect [b]{called}[/b]")
## @ace_param(called, default: vignette, desc: "The name the entry was added under.")
## @ace_icon("res://eventsheet_addons/post_kit/icon.svg")
## @ace_codegen_template("$PostKitBehavior.enable_post_effect("{called}")")
func enable_post_effect(called: String = "vignette") -> void:
	_set_enabled(called, true)

## Turns one effect off and leaves it in the stack, so a later Enable Post Effect brings back the
## same strength rather than a fresh guess at it.
## @ace_action
## @ace_name("Disable Post Effect")
## @ace_display_template("Disable post effect [b]{called}[/b]")
## @ace_param(called, default: vignette, desc: "The name the entry was added under.")
## @ace_icon("res://eventsheet_addons/post_kit/icon.svg")
## @ace_codegen_template("$PostKitBehavior.disable_post_effect("{called}")")
func disable_post_effect(called: String = "vignette") -> void:
	_set_enabled(called, false)

## Sets how far one effect goes, straight away.
## @ace_action
## @ace_name("Set Post Strength")
## @ace_display_template("Set [b]{called}[/b] strength to [b]{strength}[/b]")
## @ace_param(called, default: vignette, desc: "The name the entry was added under.")
## @ace_param(strength, default: 1.0, desc: "How far it goes, 0 to 1, before the accessibility dials have their say.")
## @ace_icon("res://eventsheet_addons/post_kit/icon.svg")
## @ace_codegen_template("$PostKitBehavior.set_post_strength("{called}", {strength})")
func set_post_strength(called: String = "vignette", strength: float = 1.0) -> void:
	_stop_walk_on(called.strip_edges().to_lower())
	_write_strength(called, strength)

## Sets ONE OF AN EFFECT'S OWN DIALS - the tint's colour, the vignette's softness, the pixelate's
## block size. Strength is how far the effect goes; this is what the effect is, and it is the row
## that sits one dropdown deeper than the quick form. The same words the screen's own stack uses, so
## a project that moves renderer keeps its sheet.
##
## FORWARD+ ONLY. Nothing happens on Mobile or Compatibility.
## @ace_action
## @ace_name("Set Post Dial")
## @ace_display_template("Set [b]{called}[/b] [b]{dial}[/b] to [b]{value}[/b]")
## @ace_param(called, default: vignette, desc: "The name the entry was added under.")
## @ace_param(dial, default: tint, desc: "Which of that effect's own dials - the property the effect declares. The pack guide lists them per effect.")
## @ace_param(value, default: 0.5, desc: "What to set it to: a number, a Color, whatever that dial takes.")
## @ace_icon("res://eventsheet_addons/post_kit/icon.svg")
## @ace_codegen_template("$PostKitBehavior.set_post_dial("{called}", "{dial}", {value})")
func set_post_dial(called: String = "vignette", dial: String = "tint", value: Variant = 0.5) -> void:
	var at: int = _find(called)
	var dial_name: String = dial.strip_edges()
	if at < 0 or dial_name.is_empty():
		return
	var made: CompositorEffect = _stack[at].get("resource", null) as CompositorEffect
	if made == null:
		return
	if not _has_dial(made, dial_name):
		push_warning("Set Post Dial: the \"%s\" effect has no dial called \"%s\"." % [
			str(_stack[at].get("effect", "")), dial_name])
		return
	made.set(dial_name, value)

## What one of an effect's own dials currently holds - the other half of Set Post Dial, for a row
## that nudges a value rather than naming one. Nothing at all for an entry or a dial that is not
## there.
## @ace_expression
## @ace_name("Post Dial")
## @ace_display_template("[b]{called}[/b] [b]{dial}[/b]")
## @ace_param(called, default: vignette, desc: "The name the entry was added under.")
## @ace_param(dial, default: tint, desc: "Which of that effect's own dials to read back.")
## @ace_icon("res://eventsheet_addons/post_kit/icon.svg")
## @ace_codegen_template("$PostKitBehavior.post_dial("{called}", "{dial}")")
func post_dial(called: String = "vignette", dial: String = "tint") -> Variant:
	var at: int = _find(called)
	if at < 0:
		return null
	var made: CompositorEffect = _stack[at].get("resource", null) as CompositorEffect
	if made == null or not _has_dial(made, dial.strip_edges()):
		return null
	return made.get(dial.strip_edges())

## Walks one effect's strength to a value over a number of seconds - the slow drain of colour as the
## health goes, the vignette closing in.
## @ace_action
## @ace_name("Fade Post Strength")
## @ace_display_template("Fade [b]{called}[/b] to [b]{to}[/b] over [b]{seconds}[/b] s")
## @ace_param(called, default: vignette, desc: "The name the entry was added under.")
## @ace_param(to, default: 1.0, desc: "The strength it arrives at, 0 to 1.")
## @ace_param(seconds, default: 0.5, desc: "How long the walk takes. Held over a floor while no flashing is on.")
## @ace_icon("res://eventsheet_addons/post_kit/icon.svg")
## @ace_codegen_template("$PostKitBehavior.fade_post_strength("{called}", {to}, {seconds})")
func fade_post_strength(called: String = "vignette", to: float = 1.0, seconds: float = 0.5) -> void:
	_walk_strength(called.strip_edges().to_lower(), clampf(to, 0.0, 1.0), _slowed(seconds), 0.0,
		0.0, false)

## Flashes one effect up and lets it fall back - the whole sentence a hit, a pickup or a near miss
## wants, in one row and with nothing to tune. An effect that was not on the stack is borrowed for
## the moment and taken off again at the end.
##
## FORWARD+ ONLY. Nothing happens on Mobile or Compatibility; Screen FX pulses the same words on
## any renderer.
## @ace_action
## @ace_featured
## @ace_name("Pulse Post Effect")
## @ace_display_template("Pulse [b]{effect}[/b] at [b]{strength}[/b] for [b]{seconds}[/b] s")
## @ace_param(effect, options: vignette=Vignette|desaturate=Desaturate|pixelate=Pixelate|tint=Tint|fade=Fade, default: vignette, desc: "Which effect to flash up and let fall.")
## @ace_param(strength, default: 0.6, desc: "How far up it goes, 0 to 1. Held under a ceiling while no flashing is on.")
## @ace_param(seconds, default: 0.35, desc: "How long it takes to fall back to where it was.")
## @ace_icon("res://eventsheet_addons/post_kit/icon.svg")
## @ace_codegen_template("$PostKitBehavior.pulse_post_effect("{effect}", {strength}, {seconds})")
func pulse_post_effect(effect: String = "vignette", strength: float = 0.6, seconds: float = 0.35) -> void:
	var word: String = effect.strip_edges().to_lower()
	if not POST_EFFECTS.has(word):
		push_warning("Pulse Post Effect: no effect is called \"%s\" - the words are %s." % [
			effect, ", ".join(POST_EFFECTS)])
		return
	var borrowed: bool = _find(word) < 0
	var falls_back_to: float = 0.0
	if borrowed:
		_add_entry(word, word, 0.0)
	else:
		falls_back_to = float(_stack[_find(word)].get("strength", 0.0))
	if _find(word) < 0:
		return
	_stop_walk_on(word)
	_write_strength(word, strength)
	if seconds <= 0.0:
		return
	_walk_strength(word, clampf(strength, 0.0, 1.0), 0.0, falls_back_to, _slowed(seconds), borrowed)

## Whether an effect by that name is on the stack at all, on or off. The gate for a row that should
## only add one once.
## @ace_condition
## @ace_name("Has Post Effect")
## @ace_display_template("has the post effect [b]{called}[/b]")
## @ace_param(called, default: vignette, desc: "The name the entry was added under.")
## @ace_icon("res://eventsheet_addons/post_kit/icon.svg")
## @ace_codegen_template("$PostKitBehavior.has_post_effect("{called}")")
func has_post_effect(called: String = "vignette") -> bool:
	return _find(called) >= 0

## How far one effect has been ASKED to go, 0 to 1 - the strength the rows set, before the
## effect-strength setting and the no-flashing ceiling are applied on the way to the CompositorEffect.
## That is the number a sheet's own arithmetic means: Set Post Strength to Post Strength + 0.1 walks
## up in tenths whatever a player's accessibility dials are doing, where reading the dialled value
## back would fold those dials in again on every round trip and the effect would sink towards
## nothing. 0 for one that is not there.
## @ace_expression
## @ace_name("Post Strength")
## @ace_param(called, default: vignette, desc: "The name the entry was added under.")
## @ace_icon("res://eventsheet_addons/post_kit/icon.svg")
## @ace_codegen_template("$PostKitBehavior.post_strength("{called}")")
func post_strength(called: String = "vignette") -> float:
	var at: int = _find(called)
	if at < 0:
		return 0.0
	return float(_stack[at].get("strength", 0.0))

## Draws an outline around every node in a group, THROUGH whatever is standing in front of them -
## the enemies behind the wall, the objective across the level, the teammate in the smoke.
##
## The row switches the mask layer on for those nodes' meshes and a second camera that can see that
## layer and nothing else draws them into a mask, which is edge-detected over the finished frame.
## So the outline is one extra pass over the marked meshes, and nothing at all when nothing is
## marked. Ask for seconds and it takes itself off again; ask for 0 and Stop Outlining ends it.
##
## FORWARD+ ONLY. Nothing happens on Mobile or Compatibility.
## @ace_action
## @ace_featured
## @ace_name("Outline Group Through Walls")
## @ace_display_template("Outline group [b]{group}[/b] through walls in [b]{colour}[/b]")
## @ace_param(group, default: enemies, desc: "The group whose nodes are outlined. Every visual instance under each of them is marked.")
## @ace_param(colour, default: Color.YELLOW, desc: "The colour the outline is drawn in.")
## @ace_param(width, default: 2.0, desc: "How thick the outline is, in pixels of the frame.")
## @ace_param(seconds, default: 0.0, desc: "How long it lasts. 0 leaves it on until Stop Outlining.")
## @ace_icon("res://eventsheet_addons/post_kit/icon.svg")
## @ace_codegen_template("$PostKitBehavior.outline_group_through_walls("{group}", {colour}, {width}, {seconds})")
func outline_group_through_walls(group: String = "enemies", colour: Color = Color.YELLOW, width: float = 2.0, seconds: float = 0.0) -> void:
	if not is_inside_tree() or not _has_compositor():
		# THE RENDERER IS ASKED FIRST, because "does nothing" has to mean nothing: marking the meshes
		# and only then finding out there is no compositor left every one of them switched onto the
		# mask layer with nothing to take them off again.
		return
	var marked: int = 0
	for node: Node in get_tree().get_nodes_in_group(group.strip_edges()):
		marked += _mark(node, true)
	if marked == 0:
		push_warning("Outline Group Through Walls: nothing in the group \"%s\" has a mesh to outline." % group)
		return
	_start_outline(colour, width, 0.0, seconds)

## Fills one node in a flat colour, through whatever is in front of it - where the thing is, rather
## than what shape it is. The same mask as the outline, drawn solid.
## @ace_action
## @ace_name("Silhouette Node Through Walls")
## @ace_display_template("Silhouette [i]{node}[/i] through walls in [b]{colour}[/b]")
## @ace_param(node, hint: node_path, default: $Enemy, desc: "The node to fill. Every visual instance under it is marked.")
## @ace_param(colour, default: Color.YELLOW, desc: "The colour it is filled with.")
## @ace_param(seconds, default: 0.0, desc: "How long it lasts. 0 leaves it on until Stop Outlining.")
## @ace_icon("res://eventsheet_addons/post_kit/icon.svg")
## @ace_codegen_template("$PostKitBehavior.silhouette_node_through_walls({node}, {colour}, {seconds})")
func silhouette_node_through_walls(node: Node3D, colour: Color = Color.YELLOW, seconds: float = 0.0) -> void:
	if node == null or not is_inside_tree() or not _has_compositor():
		# The renderer is asked before anything is marked, for the reason the group row asks first.
		return
	if _mark(node, true) == 0:
		push_warning("Silhouette Node Through Walls: %s has no mesh to fill." % node.name)
		return
	_start_outline(colour, 2.0, 1.0, seconds)

## Ends every outline and silhouette at once: the mask layer goes back off the meshes that were
## marked, the entry leaves the stack, and the mask rig is freed, so nothing is left running.
## @ace_action
## @ace_name("Stop Outlining")
## @ace_icon("res://eventsheet_addons/post_kit/icon.svg")
## @ace_codegen_template("$PostKitBehavior.stop_outlining()")
func stop_outlining() -> void:
	for instance: VisualInstance3D in _marked:
		if is_instance_valid(instance):
			instance.set_layer_mask_value(_layer_bit(), false)
	_marked.clear()
	remove_post_effect(OUTLINE_EFFECT)
	_free_mask()

## Whether a node is one of the ones being drawn through walls right now.
## @ace_condition
## @ace_name("Is Outlined")
## @ace_display_template("[i]{node}[/i] is outlined")
## @ace_param(node, hint: node_path, default: $Enemy, desc: "The node to ask about.")
## @ace_icon("res://eventsheet_addons/post_kit/icon.svg")
## @ace_codegen_template("$PostKitBehavior.is_outlined({node})")
func is_outlined(node: Node3D) -> bool:
	if node == null:
		return false
	for instance: VisualInstance3D in _marked:
		if is_instance_valid(instance) and (instance == node or node.is_ancestor_of(instance)):
			return true
	return false

## Whether something solid is standing between the camera and a node - the question an outline row
## is usually the answer to, asked on its own so a sheet can decide instead of always drawing.
##
## It is one ray from the camera to the node's own origin, so a body whose middle is visible past
## the corner of a wall reads as seen. That is a cheap question with an honest answer, not a
## visibility test.
## @ace_condition
## @ace_name("Is Hidden From View")
## @ace_display_template("[i]{node}[/i] is hidden from view")
## @ace_param(node, hint: node_path, default: $Enemy, desc: "The node to ask about.")
## @ace_icon("res://eventsheet_addons/post_kit/icon.svg")
## @ace_codegen_template("$PostKitBehavior.is_hidden_from_view({node})")
func is_hidden_from_view(node: Node3D) -> bool:
	if node == null or not is_inside_tree():
		return false
	var camera: Camera3D = _camera()
	if camera == null:
		return false
	var world: World3D = camera.get_world_3d()
	if world == null or world.direct_space_state == null:
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		camera.global_position, node.global_position)
	query.collide_with_areas = false
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	var blocker: Node = hit.get("collider", null) as Node
	if blocker == null:
		return false
	return blocker != node and not node.is_ancestor_of(blocker) and not blocker.is_ancestor_of(node)

## Where an entry sits in the stack, or -1. Names are compared trimmed and lower-cased, so a row that
## says "Vignette" and one that says "vignette" mean the same entry.
func _find(called: String) -> int:
	var wanted: String = called.strip_edges().to_lower()
	if wanted.is_empty():
		return -1
	for at: int in _stack.size():
		if str(_stack[at].get("called", "")) == wanted:
			return at
	return -1

## What a row's requested strength really becomes: scaled by the effect-strength dial the whole
## project shares, then held under the ceiling while no flashing is on. ONE function, so no row can
## be the one that forgot.
func _allowed(strength: float) -> float:
	var dial: float = clampf(float(Engine.get_meta(EFFECT_STRENGTH_META, 1.0)), 0.0, 1.0)
	var wanted: float = clampf(strength, 0.0, 1.0) * dial
	if bool(Engine.get_meta(NO_FLASHING_META, false)):
		wanted = minf(wanted, FLASH_CEILING)
	return wanted

## And what a row's requested TIME really becomes: never quicker than the floor while no flashing is
## on, because a small amplitude arriving ten times a second is still a strobe.
func _slowed(seconds: float) -> float:
	if bool(Engine.get_meta(NO_FLASHING_META, false)):
		return maxf(seconds, FLASH_FLOOR_SECONDS)
	return maxf(seconds, 0.0)

## The visual layer bit the mask camera sees, from the pack's own setting.
func _layer_bit() -> int:
	return clampi(mask_layer, 1, 20)

## Whether this project has a compositor to hang anything on at all. Asked once per row rather than
## assumed, and said out loud once per run, because a row that quietly does nothing for a whole jam
## is worse than one that says why.
func _has_compositor() -> bool:
	if RenderingServer.get_current_rendering_method() == FORWARD_PLUS:
		return true
	if not _said_no_compositor:
		_said_no_compositor = true
		push_warning("Post Kit: this project is not built for Forward+, which is the only renderer with a compositor - these rows do nothing here. The Screen FX and Blend Modes packs do the same looks on any renderer.")
	return false

## Adds or refreshes one entry and writes the whole stack at the camera. Shared by Add Post Effect,
## Pulse Post Effect and the outline rows, so all three build an entry the same way.
func _add_entry(effect: String, called: String, strength: float) -> void:
	var at: int = _find(called)
	if at >= 0:
		_stack[at]["enabled"] = true
		_write_strength(called, strength)
		return
	if _ensure_compositor() == null:
		return
	var made: CompositorEffect = _make(effect)
	if made == null:
		return
	var asked: float = clampf(strength, 0.0, 1.0)
	made.set("strength", _allowed(asked))
	_stack.append({"called": called, "effect": effect, "strength": asked,
		"enabled": true, "resource": made})
	_write_effects()

## Pushes the stack at the Compositor, in order. One assignment rather than a mutation, because the
## array the Compositor holds is its own copy of ours.
func _write_effects() -> void:
	var compositor: Compositor = _ensure_compositor()
	if compositor == null:
		return
	var effects: Array[CompositorEffect] = []
	for entry: Dictionary in _stack:
		var made: CompositorEffect = entry.get("resource", null) as CompositorEffect
		if made == null:
			continue
		made.enabled = bool(entry.get("enabled", true))
		effects.append(made)
	compositor.compositor_effects = effects

## Remembers what one entry's row ASKED for and pushes it at the effect, through the accessibility
## dials. The request is what is kept, and the dials have their say once, here, on the way to the
## CompositorEffect - which is what stops a walk over requests from being scaled a second time per
## step.
func _write_strength(called: String, strength: float) -> void:
	var at: int = _find(called)
	if at < 0:
		return
	var asked: float = clampf(strength, 0.0, 1.0)
	_stack[at]["strength"] = asked
	var made: CompositorEffect = _stack[at].get("resource", null) as CompositorEffect
	if made != null:
		made.set("strength", _allowed(asked))

## Turns one entry on or off without forgetting how far up it was.
func _set_enabled(called: String, on: bool) -> void:
	var at: int = _find(called)
	if at < 0:
		return
	_stack[at]["enabled"] = on
	var made: CompositorEffect = _stack[at].get("resource", null) as CompositorEffect
	if made != null:
		made.enabled = on

## Ends the walk on one entry, if there is one, leaving it wherever it had got to.
func _stop_walk_on(called: String) -> void:
	var walk: Tween = _stack_walks.get(called, null)
	if walk != null and walk.is_valid():
		walk.kill()
	_stack_walks.erase(called)

## Walks one entry's strength - there, and optionally back - and takes it off the stack afterwards
## when it was only borrowed for a moment.
##
## WITH NO TREE TO RUN A TWEEN IN (a headless run, a behavior built but not added yet) the walk
## lands on its final value at once, which is the same answer a moment later.
func _walk_strength(called: String, to_value: float, seconds: float, back_to: float, back_seconds: float, drop_after: bool) -> void:
	var at: int = _find(called)
	if at < 0:
		return
	_stop_walk_on(called)
	var ends_at: float = back_to if back_seconds > 0.0 else to_value
	if not is_inside_tree() or (seconds <= 0.0 and back_seconds <= 0.0):
		_write_strength(called, ends_at)
		if drop_after:
			remove_post_effect(called)
		return
	var walk: Tween = create_tween()
	if seconds > 0.0:
		walk.tween_method(func(value: float) -> void: _write_strength(called, value),
			float(_stack[at].get("strength", 0.0)), to_value, seconds)
	if back_seconds > 0.0:
		walk.tween_method(func(value: float) -> void: _write_strength(called, value),
			to_value, back_to, back_seconds)
	if drop_after:
		walk.finished.connect(func() -> void: remove_post_effect(called))
	_stack_walks[called] = walk

## Whether one CompositorEffect really declares a dial by that name. A name it does not have would
## be set on the object and read back by nobody, which is a row that looks like it worked.
func _has_dial(made: Object, dial_name: String) -> bool:
	for declared: Dictionary in made.get_property_list():
		if str(declared.get("name", "")) == dial_name:
			return true
	return false

## Switches the mask layer on (or off) for every visual instance at or under a node, and remembers
## the ones it switched on. Answers how many it touched, so a row with nothing to mark can say so.
func _mark(node: Node, on: bool) -> int:
	var touched: int = 0
	var instance: VisualInstance3D = node as VisualInstance3D
	if instance != null:
		instance.set_layer_mask_value(_layer_bit(), on)
		if on and not _marked.has(instance):
			_marked.append(instance)
		touched += 1
	for child: Node in node.get_children():
		touched += _mark(child, on)
	return touched

## Puts the outline entry on the stack with the colour, width and fill a row asked for, builds the
## mask rig if there is not one yet, and starts the clock when the row named seconds.
func _start_outline(colour: Color, width: float, fill: float, seconds: float) -> void:
	if not _ensure_mask():
		return
	_add_entry(OUTLINE_EFFECT, OUTLINE_EFFECT, 1.0)
	var at: int = _find(OUTLINE_EFFECT)
	if at < 0:
		return
	var made: CompositorEffect = _stack[at].get("resource", null) as CompositorEffect
	if made != null:
		made.set("ink", colour)
		made.set("width", maxf(width, 1.0))
		made.set("fill", clampf(fill, 0.0, 1.0))
	_stop_walk_on(OUTLINE_EFFECT)
	if seconds <= 0.0:
		return
	var clock: Tween = create_tween()
	clock.tween_interval(_slowed(seconds))
	clock.finished.connect(stop_outlining)
	_stack_walks[OUTLINE_EFFECT] = clock

## The mask rig: a viewport with a transparent background holding a camera that can see the mask
## layer and nothing else. Built the first time something is outlined, so a project that never
## outlines anything never pays for it.
func _ensure_mask() -> bool:
	if _mask != null and is_instance_valid(_mask):
		return true
	if not _has_compositor():
		return false
	var camera: Camera3D = _camera()
	if camera == null or not is_inside_tree():
		return false
	_mask = SubViewport.new()
	_mask.name = MASK_NODE_NAME
	_mask.transparent_bg = true
	_mask.handle_input_locally = false
	_mask.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_mask.size = _view_size()
	_mask_camera = Camera3D.new()
	_mask_camera.cull_mask = 1 << (_layer_bit() - 1)
	# A plain white ambient and no sky: the mask is read for its ALPHA, and a sky would fill every
	# pixel of it with something.
	var flat: Environment = Environment.new()
	flat.background_mode = Environment.BG_CLEAR_COLOR
	flat.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	flat.ambient_light_color = Color.WHITE
	flat.ambient_light_energy = 1.0
	_mask_camera.environment = flat
	_mask.add_child(_mask_camera)
	add_child(_mask)
	_mask_camera.current = true
	set_process(true)
	return true

## Frees the mask rig and stops the per-frame work that keeps it pointed at the camera.
func _free_mask() -> void:
	set_process(false)
	if _mask != null and is_instance_valid(_mask):
		_mask.queue_free()
	_mask = null
	_mask_camera = null

# Post Kit behavior: attach it under the Camera3D (or the WorldEnvironment) whose Compositor you want to fill. Add Post Effect wears one of five effects - vignette, desaturate, pixelate, tint, fade - the same words the 2D post stack uses, so a row reads alike on either; Pulse Post Effect is the whole sentence a hit wants in one row. Outline Group Through Walls marks a group's meshes on the pack's mask layer and draws their edge over the frame, wall or no wall; Stop Outlining ends it and frees the rig. FORWARD+ ONLY: on Mobile and Compatibility these rows do nothing at all, and the Screen FX and Blend Modes packs do the same looks on any renderer. This pack is an event sheet - extend it by editing it.
