# EventForge module - layers: what a layer does with the camera, and how far behind it scrolls.
#
# The Layers shelf already holds where an OBJECT sits in the drawing order (around_objects_aces.gd:
# Z order, Move To Layer, Set Layer Order). This file is about the LAYER itself, and about the two
# nodes a 2D game builds a background out of.
#
#   A CANVASLAYER either follows the camera or it does not. That one flag is the difference between
#   a HUD (fixed on the screen, which is what a CanvasLayer is usually added for) and a layer of
#   world that happens to have its own drawing order. Beside it: which layer draws over which, said
#   relative to another layer rather than as two numbers that drift apart, and the layer's own
#   offset, which is how a whole layer is nudged without touching anything on it.
#
#   A PARALLAX LAYER scrolls at a fraction of the camera. Godot has two nodes for this and a project
#   will meet both: Parallax2D is the modern one (a single node, its own scroll scale, its own
#   repeat), and ParallaxLayer inside a ParallaxBackground is the older pair that every project
#   older than Godot 4.3 is built on. The same words are mapped onto both, under names that say
#   which node they are for, so an existing project reads as sentences instead of as property
#   writes nobody has a word for.
#
# THE WORDS ARE THE SAME BECAUSE THE IDEA IS THE SAME. `scroll_scale` and `motion_scale` are the
# same fraction under two spellings, and `repeat_size` and `motion_mirroring` are the same tiling
# distance; a reader who has learned one of the pairs has learned the other. What is NOT mapped is
# drift: Parallax2D has an `autoscroll` of its own and the older layer has none, so the older half
# ships two rows rather than three and nothing pretends otherwise.
#
# Everything compiles to plain property writes with zero plugin references, honouring the parity
# covenant.
@tool
class_name EventForgeLayerACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

## The same shelf the object-side layer rows are filed under, on purpose: a reader looking for
## "layers" should find all of it in one place rather than half of it under a second heading.
const CAT := "Layers"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []
	_canvas_layers(descriptors)
	_parallax(descriptors)
	return descriptors


## What a CanvasLayer does with the camera, and where it sits among the other layers.
static func _canvas_layers(d: Array[ACEDescriptor]) -> void:
	d.append(F.act("LayerStayFixedOnScreen", "Stay Fixed On Screen", "follow_viewport_enabled = false", CAT, "stay fixed on screen", "Pins this whole layer to the screen, so the camera moving through the world leaves it exactly where it is. What a HUD, a pause menu or a letterbox border wants, and what a CanvasLayer does out of the box.", "CanvasLayer").featured())

	d.append(F.act("LayerMoveWithTheWorld", "Move With The World", "follow_viewport_enabled = true", CAT, "move with the world", "Lets the camera move this layer, so everything on it sits in the world rather than on the screen. The other half of the switch above: a layer of scenery drawn behind the level, a layer of effects drawn over it, both moving with the view.", "CanvasLayer"))

	# Both relative rows carry their OWN `{target.}` slot rather than taking the automatic "On node"
	# one. The retarget pass refuses to prefix a line whose right-hand side reads the assigned member
	# back, and `layer = {other}.layer + 1` does - correctly in general, and safely here only because
	# the member being read belongs to the OTHER layer, which the row names in a field of its own.
	d.append(F.act("LayerDrawAbove", "Draw Above", "{target.}layer = {other}.layer + 1", CAT, "draw above [b]{other}[/b]", "Puts this layer one step in front of another one, whatever number that other layer happens to be on. Relative on purpose: insert a layer between them later and the pair keeps its order, where two hand-typed numbers quietly stop meaning what they meant.", "CanvasLayer").param("other", "$\"../World\"", "Above", "The layer to draw over - this one takes its order plus one.", "scene_node").param_built(_on_node_param()).featured())

	d.append(F.act("LayerDrawBelow", "Draw Below", "{target.}layer = {other}.layer - 1", CAT, "draw below [b]{other}[/b]", "The other end: puts this layer one step behind another one, whatever number that other layer is on. The backdrop that must stay behind the world however the world's own layer is numbered.", "CanvasLayer").param("other", "$\"../HUD\"", "Below", "The layer to draw behind - this one takes its order minus one.", "scene_node").param_built(_on_node_param()))

	d.append(F.act("LayerOffset", "Offset Layer", "offset = {by}", CAT, "offset layer by [b]{by}[/b]", "Nudges the whole layer, without touching a single thing on it. A HUD sliding in from the edge, a background pushed a little to one side, a shake that leaves the world alone.", "CanvasLayer").param_typed("Vector2", "by", "Vector2(0, 0)", "By", "How far to move the layer, in pixels.", "expression"))


## The two parallax nodes, under the same words.
static func _parallax(d: Array[ACEDescriptor]) -> void:
	d.append(F.act("ParallaxScrollAt", "Scroll At", "scroll_scale = {factor}", CAT, "scroll at [b]{factor}[/b] of the camera", "How much of the camera's movement this layer takes. Below 1 is behind the action and moves slower, which is what reads as distance; 1 moves exactly with the world; above 1 is in front of it. Each axis on its own, so a sky can drift sideways without sliding up and down.", "Parallax2D").param_typed("Vector2", "factor", "Vector2(0.5, 1)", "Fraction", "The share of the camera's movement this layer takes, per axis. 0.5 is half speed.", "expression").featured())

	d.append(F.act("ParallaxRepeatEvery", "Repeat Every", "repeat_size = {size}", CAT, "repeat every [b]{size}[/b]", "Tiles this layer forever, one copy every so many pixels, so a scrolling level never runs off the end of the artwork. Set the distance to the artwork's own width to make the seam invisible; a zero on an axis means no repeating along it.", "Parallax2D").param_typed("Vector2", "size", "Vector2(1920, 0)", "Every", "How far apart the copies sit, in pixels. Zero on an axis means it does not repeat that way.", "expression"))

	d.append(F.act("ParallaxDrift", "Drift", "autoscroll = {speed}", CAT, "drift at [b]{speed}[/b]", "Moves this layer on its own, whether the camera moves or not - clouds crossing the sky, mist over water, a starfield behind a menu that has no camera at all. Pixels per second, per axis; negative goes the other way.", "Parallax2D").param_typed("Vector2", "speed", "Vector2(-20, 0)", "Speed", "How fast the layer drifts by itself, in pixels per second, per axis.", "expression"))

	d.append(F.expr("ParallaxScrollOffset", "Scroll Offset", "scroll_offset", CAT, "scroll offset", "How far this layer has scrolled, in pixels. The number to read when something on the layer has to line up with it - a marker on a distant hill, a sound that fades with the drift.", "Parallax2D"))

	# The older pair, under the same words. ParallaxLayer only does anything inside a
	# ParallaxBackground, which is why the names say so: a reader with the older setup finds the word
	# they already know, and a reader with Parallax2D never meets a row that would do nothing for them.
	d.append(F.act("ParallaxLayerScrollAt", "Scroll At (Background Layer)", "motion_scale = {factor}", CAT, "scroll at [b]{factor}[/b] of the camera", "The same fraction on the older parallax node: how much of the camera's movement this layer takes, below 1 for distance and above 1 for the foreground. This is the row for a ParallaxLayer inside a ParallaxBackground, which is how a project built before Parallax2D arrived is put together.", "ParallaxLayer").param_typed("Vector2", "factor", "Vector2(0.5, 1)", "Fraction", "The share of the camera's movement this layer takes, per axis. 0.5 is half speed.", "expression"))

	d.append(F.act("ParallaxLayerRepeatEvery", "Repeat Every (Background Layer)", "motion_mirroring = {size}", CAT, "repeat every [b]{size}[/b]", "The same tiling on the older parallax node: one copy of this layer every so many pixels, so the level never runs off the end of the artwork. Set it to the artwork's own width; a zero on an axis means no repeating along it.", "ParallaxLayer").param_typed("Vector2", "size", "Vector2(1920, 0)", "Every", "How far apart the copies sit, in pixels. Zero on an axis means it does not repeat that way.", "expression"))


## The "On node" parameter in the shape the automatic retarget pass gives every other node-scoped
## row, for the two rows that spell their own `{target.}` slot. Same id and same words, so a reader
## meets one field rather than two that look alike.
static func _on_node_param() -> ACEParam:
	return F.make_param("target", "String", "", "On node", "Act on another node instead of this one. Leave blank for this node, pick a node, or address one without a tree path - e.g. get_node(\"%HUD\").", "expression")


static func section_descriptions() -> Dictionary:
	return {CAT: "Where a thing draws: its order among the others, which layer it is on, whether that layer follows the camera, and how far behind the camera a parallax layer scrolls."}
