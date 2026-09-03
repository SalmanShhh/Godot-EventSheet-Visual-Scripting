## @ace_tags(visual, shader, juice, effects, blend)
## @ace_category("Blend Modes")
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/blend_modes/icon.svg")
class_name BlendModesAddon
extends Node
## The twenty ways a picture can meet the one behind it, as rows: the five Godot draws by itself, and fifteen that read the screen back through a shader the pack ships - screen, overlay, the light-and-dark family, difference, and the four that take a colour apart. Plus a mask, so a second picture decides where the first is allowed to be. Ships as the BlendModes autoload, so any sheet can blend any canvas item.

## Where the pack's own shaders live once it is installed. The pack builder copies them here beside
## the script, so a mode is a file on disk rather than a string compiled at run time.
const SHADER_DIRECTORY: String = "res://eventsheet_addons/blend_modes/"

## The five modes Godot draws WITHOUT a shader, by the word the row uses. These cost nothing extra:
## the renderer already knows how to draw a quad this way, so a sprite set to one of them is exactly
## as cheap as a sprite that is not.
const NATIVE_MODES: Dictionary = {
	"normal": CanvasItemMaterial.BLEND_MODE_MIX,
	"add": CanvasItemMaterial.BLEND_MODE_ADD,
	"subtract": CanvasItemMaterial.BLEND_MODE_SUB,
	"multiply": CanvasItemMaterial.BLEND_MODE_MUL,
	"premultiplied": CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
}

## The fifteen the pack draws with a shader of its own, one file per mode. Each one reads back what
## is already on the screen under the item, which is the only way to blend against it - so these
## cost one screen read per pixel the item covers, and the help words on the row say so.
const SHADER_MODES: PackedStringArray = ["screen", "overlay", "darken", "lighten",
	"colour dodge", "colour burn", "hard light", "soft light", "difference", "exclusion", "hue",
	"saturation", "colour", "luminosity", "copy"]

## The five ways a mask and the thing it masks can meet, IN THE ORDER blend_mask.gdshader numbers
## them - the position in this list is the number written into the shader, so nothing has to keep a
## second table of numbers in step with this one.
const MASK_MODES: PackedStringArray = ["inside", "outside", "atop", "behind", "xor"]

## The name the mode file takes: the word with its spaces closed up. "colour dodge" is
## blend_colour_dodge.gdshader, and a mode word and its file can therefore never drift apart.
const SHADER_PREFIX: String = "blend_"

## What the pack remembers ON THE ITEM rather than in a table of its own: the mode word it was last
## asked for, and the material it was wearing before the pack touched it. Kept on the node so an item
## freed mid-game takes its own record with it, and so two of these packs could never disagree.
const MODE_META: StringName = &"blend_modes_mode"
const WORN_META: StringName = &"blend_modes_worn"
const GROUP_META: StringName = &"blend_modes_group"

## The mode an item is in when nobody has said otherwise - what Blend Mode reads back for an item no
## row here has touched, and what the row shows the moment it is dropped.
const DEFAULT_MODE: String = "normal"

## The shaders loaded so far, by mode word. A project that only ever uses screen loads one file.
var _shaders: Dictionary = {}

## The strength fades running right now, keyed by the item's instance id, so a second fade on the
## same item replaces the first rather than the two of them fighting over one uniform.
var _fades: Dictionary = {}
## Blends this item into whatever has already been drawn under it. The five native modes are the
## ones Godot draws by itself and cost nothing; the other fifteen read the screen back through a
## shader, which costs one screen read for every pixel the item covers - a look for the few things
## that want it rather than for every sprite in the scene.
## @ace_action
## @ace_featured
## @ace_name("Blend As")
## @ace_category("Blend Modes")
## @ace_codegen_template("BlendModes.blend_as({item}, "{mode}", {strength})")
## @ace_display_template("Blend [i]{item}[/i] as [b]{mode}[/b]")
## @ace_param(item, hint: expression, default: self, desc: "The canvas item to blend. self is the node running this sheet.")
## @ace_param(mode, hint: blend_mode, default: screen, options: normal=Normal|add=Add|subtract=Subtract|multiply=Multiply|premultiplied=Premultiplied|screen=Screen|overlay=Overlay|darken=Darken|lighten=Lighten|colour dodge=Colour dodge|colour burn=Colour burn|hard light=Hard light|soft light=Soft light|difference=Difference|exclusion=Exclusion|hue=Hue|saturation=Saturation|colour=Colour|luminosity=Luminosity|copy=Copy, desc: "Which look. The five at the top are the ones the renderer draws by itself; the rest read the screen.")
## @ace_param(strength, default: 1.0, desc: "How far the blend goes. 0 leaves the screen as it was, 1 is the whole mode. Native modes ignore it.")
func blend_as(item: CanvasItem, mode: String = "screen", strength: float = 1.0) -> void:
	if item == null:
		return
	var wanted: String = mode.strip_edges().to_lower()
	if NATIVE_MODES.has(wanted):
		_wear_native(item, wanted)
		return
	if not SHADER_MODES.has(wanted):
		push_warning("Blend As: no blend mode is called \"%s\" - the twenty words are %s." % [
			mode, ", ".join(mode_words())])
		return
	var worn: Material = item.material
	if worn is ShaderMaterial and not is_pack_material(worn):
		# NEVER a silent replacement: this item already wears somebody's own effect, and putting a
		# blend shader on it would throw that effect away without a word. The Doctor says the same
		# thing about the row before the game is ever run.
		push_warning("Blend As: %s already wears its own shader material, so the \"%s\" blend was not put on it. Blend a child or a parent instead, or take the shader off first." % [
			item.name, wanted])
		return
	var shader: Shader = _shader_for(wanted)
	if shader == null:
		return
	_remember_worn(item)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	item.material = material
	item.set_meta(MODE_META, wanted)
	set_blend_strength(item, strength)
## Turns the blend up or down without changing which mode it is - the same dial Blend As set when it
## put the look on. An item in a native mode has nothing to turn, so this does nothing to one.
## @ace_action
## @ace_name("Set Blend Strength")
## @ace_category("Blend Modes")
## @ace_codegen_template("BlendModes.set_blend_strength({item}, {strength})")
## @ace_display_template("Set [i]{item}[/i] blend strength to [b]{strength}[/b]")
## @ace_param(item, hint: expression, default: self, desc: "The canvas item whose blend to turn.")
## @ace_param(strength, default: 1.0, desc: "0 leaves the screen as it was, 1 is the whole mode.")
func set_blend_strength(item: CanvasItem, strength: float = 1.0) -> void:
	var material: ShaderMaterial = _pack_material_of(item)
	if material == null:
		return
	_stop_fade(item)
	material.set_shader_parameter("strength", clampf(strength, 0.0, 1.0))
## Walks the blend to a new strength over time instead of jumping to it - a look coming on as the
## boss appears, a mask opening, a glow settling. One tween, and nothing kept between frames.
## @ace_action
## @ace_name("Fade Blend Strength")
## @ace_category("Blend Modes")
## @ace_codegen_template("BlendModes.fade_blend_strength({item}, {strength}, {seconds})")
## @ace_display_template("Fade [i]{item}[/i] blend to [b]{strength}[/b] over [b]{seconds}[/b] s")
## @ace_param(item, hint: expression, default: self, desc: "The canvas item whose blend to walk.")
## @ace_param(strength, default: 0.0, desc: "Where the walk ends. 0 is the screen as it was.")
## @ace_param(seconds, default: 0.4, desc: "How long the walk takes.")
func fade_blend_strength(item: CanvasItem, strength: float = 0.0, seconds: float = 0.4) -> void:
	var material: ShaderMaterial = _pack_material_of(item)
	if material == null:
		return
	_stop_fade(item)
	var landing: float = clampf(strength, 0.0, 1.0)
	if seconds <= 0.0 or not is_inside_tree():
		material.set_shader_parameter("strength", landing)
		return
	var walk: Tween = create_tween()
	walk.tween_property(material, "shader_parameter/strength", landing, seconds)
	_fades[item.get_instance_id()] = walk
## True while this item is blending the way the row says. Reads the same record Blend Mode does, so
## an item nothing here has touched answers to "normal" rather than to nothing at all.
## @ace_condition
## @ace_name("Blend Mode Is")
## @ace_category("Blend Modes")
## @ace_codegen_template("BlendModes.blend_mode_is({item}, "{mode}")")
## @ace_display_template("[i]{item}[/i] blend is [b]{mode}[/b]")
## @ace_param(item, hint: expression, default: self, desc: "The canvas item to ask about.")
## @ace_param(mode, hint: blend_mode, default: screen, options: normal=Normal|add=Add|subtract=Subtract|multiply=Multiply|premultiplied=Premultiplied|screen=Screen|overlay=Overlay|darken=Darken|lighten=Lighten|colour dodge=Colour dodge|colour burn=Colour burn|hard light=Hard light|soft light=Soft light|difference=Difference|exclusion=Exclusion|hue=Hue|saturation=Saturation|colour=Colour|luminosity=Luminosity|copy=Copy, desc: "The mode to compare against.")
func blend_mode_is(item: CanvasItem, mode: String = "screen") -> bool:
	return blend_mode(item) == mode.strip_edges().to_lower()
## The word this item is blending by, for any value field - "screen", "multiply", "normal". An item
## no row here has touched reads back "normal", which is what it is doing.
## @ace_expression
## @ace_name("Blend Mode")
## @ace_category("Blend Modes")
## @ace_codegen_template("BlendModes.blend_mode({item})")
## @ace_display_template("blend mode of [i]{item}[/i]")
## @ace_param(item, hint: expression, default: self, desc: "The canvas item to read.")
func blend_mode(item: CanvasItem) -> String:
	if item == null:
		return DEFAULT_MODE
	return str(item.get_meta(MODE_META, DEFAULT_MODE))
## Lets a second picture decide where this one is allowed to be. The mask's transparency is what is
## read, so any sprite, any drawn shape and any texture with a hole in it works as one - a torn
## edge, a spotlight, a wipe that moves.
## @ace_action
## @ace_featured
## @ace_name("Mask With")
## @ace_category("Blend Modes")
## @ace_codegen_template("BlendModes.mask_with({item}, {shape}, "{mode}")")
## @ace_display_template("Mask [i]{item}[/i] with [b]{shape}[/b], [b]{mode}[/b]")
## @ace_param(item, hint: expression, default: self, desc: "The canvas item to mask.")
## @ace_param(shape, hint: expression, default: null, desc: "The texture whose transparency decides. Drag one in, or read one off another node.")
## @ace_param(mode, default: inside, options: inside=Inside the mask|outside=Outside the mask|atop=The mask shape|behind=Behind the item|xor=Where only one of them is, desc: "How the two shapes meet.")
func mask_with(item: CanvasItem, shape: Texture2D = null, mode: String = "inside") -> void:
	if item == null:
		return
	if shape == null:
		push_warning("Mask With: no texture was handed to the mask on %s, so nothing was masked." % item.name)
		return
	var wanted: String = mode.strip_edges().to_lower()
	var mask_number: int = MASK_MODES.find(wanted)
	if mask_number < 0:
		push_warning("Mask With: no mask mode is called \"%s\" - the five words are %s." % [
			mode, ", ".join(MASK_MODES)])
		return
	var worn: Material = item.material
	if worn is ShaderMaterial and not is_pack_material(worn):
		push_warning("Mask With: %s already wears its own shader material, so it was not masked. Mask a child or a parent instead." % item.name)
		return
	var shader: Shader = _shader_for("mask")
	if shader == null:
		return
	_remember_worn(item)
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("mask", shape)
	material.set_shader_parameter("mask_mode", mask_number)
	material.set_shader_parameter("strength", 1.0)
	item.material = material
	item.set_meta(MODE_META, "mask")
## The same mask, taken off ANOTHER NODE's picture - the sprite in the scene that is already the
## shape you want. Reads that node's own texture, so moving or swapping the sprite changes the mask.
## @ace_action
## @ace_name("Mask With Node")
## @ace_category("Blend Modes")
## @ace_codegen_template("BlendModes.mask_with_node({item}, {shape_node}, "{mode}")")
## @ace_display_template("Mask [i]{item}[/i] with [i]{shape_node}[/i], [b]{mode}[/b]")
## @ace_param(item, hint: expression, default: self, desc: "The canvas item to mask.")
## @ace_param(shape_node, hint: expression, default: null, desc: "The node whose picture is the shape. A Sprite2D, a TextureRect, anything wearing a texture.")
## @ace_param(mode, default: inside, options: inside=Inside the mask|outside=Outside the mask|atop=The mask shape|behind=Behind the item|xor=Where only one of them is, desc: "How the two shapes meet.")
func mask_with_node(item: CanvasItem, shape_node: CanvasItem = null, mode: String = "inside") -> void:
	if shape_node == null:
		push_warning("Mask With Node: no node was handed to the mask, so nothing was masked.")
		return
	# `in` on the object is the honest question: it answers for a project's own sprite subclass
	# exactly as it does for the engine's, with no list of class names here to keep in step.
	if not ("texture" in shape_node):
		push_warning("Mask With Node: %s wears no texture, so there is no shape to mask with." % shape_node.name)
		return
	mask_with(item, shape_node.get("texture") as Texture2D, mode)
## Takes the mask off and puts back whatever the item was wearing before it - its own material, or
## none at all. An item that was never masked is left exactly as it is.
## @ace_action
## @ace_name("Unmask")
## @ace_category("Blend Modes")
## @ace_codegen_template("BlendModes.unmask({item})")
## @ace_display_template("Unmask [i]{item}[/i]")
## @ace_param(item, hint: expression, default: self, desc: "The canvas item to unmask.")
func unmask(item: CanvasItem) -> void:
	if item == null or blend_mode(item) != "mask":
		return
	_restore_worn(item)
	item.set_meta(MODE_META, DEFAULT_MODE)
## Draws this node's children into one picture first and puts THAT on the screen, so where they
## overlap they stop showing through each other. It is what a half-faded character made of six
## sprites wants, and what a blend mode on a group of things wants. Wraps the children under a
## CanvasGroup, which is Godot's own answer.
## @ace_action
## @ace_featured
## @ace_name("Blend As One")
## @ace_category("Blend Modes")
## @ace_codegen_template("BlendModes.blend_as_one({item})")
## @ace_display_template("Blend [i]{item}[/i] children as one")
## @ace_param(item, hint: expression, default: self, desc: "The node whose children to draw as one picture.")
func blend_as_one(item: CanvasItem) -> void:
	if item == null or is_blended_as_one(item):
		return
	var group: CanvasGroup = CanvasGroup.new()
	group.name = "BlendedAsOne"
	item.add_child(group)
	for child: Node in item.get_children():
		if child != group and child is CanvasItem:
			(child as CanvasItem).reparent(group)
	item.set_meta(GROUP_META, group)
## Puts the children back the way they were, each drawn on its own. The node's own class is never
## changed by either of these, so a node that was already a CanvasGroup in the scene stays one.
## @ace_action
## @ace_name("Blend Separately")
## @ace_category("Blend Modes")
## @ace_codegen_template("BlendModes.blend_separately({item})")
## @ace_display_template("Blend [i]{item}[/i] children separately")
## @ace_param(item, hint: expression, default: self, desc: "The node whose children to draw on their own again.")
func blend_separately(item: CanvasItem) -> void:
	if item == null:
		return
	var group: CanvasGroup = _group_of(item)
	if group == null:
		return
	for child: Node in group.get_children():
		if child is CanvasItem:
			(child as CanvasItem).reparent(item)
	item.remove_meta(GROUP_META)
	group.queue_free()
## True while this node's children are drawn as one picture - either because a row asked for it, or
## because the node in the scene IS a CanvasGroup already.
## @ace_condition
## @ace_name("Is Blended As One")
## @ace_category("Blend Modes")
## @ace_codegen_template("BlendModes.is_blended_as_one({item})")
## @ace_display_template("[i]{item}[/i] blends its children as one")
## @ace_param(item, hint: expression, default: self, desc: "The node to ask about.")
func is_blended_as_one(item: CanvasItem) -> bool:
	if item == null:
		return false
	return item is CanvasGroup or _group_of(item) != null
## Every mode word the pack knows, native ones first - the order the picker's own list is in, and
## the list a warning prints when somebody types a word that is not one of them.
## @ace_hidden
func mode_words() -> PackedStringArray:
	var words: PackedStringArray = PackedStringArray(NATIVE_MODES.keys())
	words.append_array(SHADER_MODES)
	return words
## One mode's shader, loaded the first time it is asked for and kept after that. A project that only
## ever blends one way loads one file.
func _shader_for(mode: String) -> Shader:
	if _shaders.has(mode):
		return _shaders[mode] as Shader
	var path: String = SHADER_DIRECTORY + SHADER_PREFIX + mode.replace(" ", "_") + ".gdshader"
	var shader: Shader = load(path) as Shader
	if shader == null:
		push_warning("Blend Modes: the shader for \"%s\" is missing from %s." % [mode, SHADER_DIRECTORY])
		return null
	_shaders[mode] = shader
	return shader
## The pack's own material on this item, or null when it is not wearing one - the one question every
## row that turns a dial has to ask first.
func _pack_material_of(item: CanvasItem) -> ShaderMaterial:
	if item == null or not is_pack_material(item.material):
		return null
	return item.material as ShaderMaterial
## The run-time CanvasGroup wrapped around this node's children, or null. Asked through the meta
## rather than by name, so a scene that already has a node called the same thing is never mistaken
## for one of these.
func _group_of(item: CanvasItem) -> CanvasGroup:
	var held: Variant = item.get_meta(GROUP_META, null)
	if held == null or not is_instance_valid(held as Object):
		return null
	return held as CanvasGroup

## @ace_hidden
func is_pack_material(material: Material) -> bool:
	var shader_material: ShaderMaterial = material as ShaderMaterial
	if shader_material == null or shader_material.shader == null:
		return false
	return shader_material.shader.resource_path.begins_with(SHADER_DIRECTORY)

## Puts a native mode on: the item wears an ordinary CanvasItemMaterial, which is what the renderer
## reads the blend off. A shader material this pack put on is taken back off first (the two cannot
## both be worn); somebody ELSE's shader material is kept, because throwing an effect away is never
## what "blend as multiply" meant.
func _wear_native(item: CanvasItem, mode: String) -> void:
	var worn: Material = item.material
	if worn is ShaderMaterial and not is_pack_material(worn):
		item.set_meta(MODE_META, mode)
		push_warning("Blend As: %s wears its own shader material, which decides its own blending - the \"%s\" blend was recorded but the material was left alone." % [
			item.name, mode])
		return
	if is_pack_material(worn):
		_restore_worn(item)
	var canvas_material: CanvasItemMaterial = item.material as CanvasItemMaterial
	if canvas_material == null:
		canvas_material = CanvasItemMaterial.new()
		item.material = canvas_material
	canvas_material.blend_mode = int(NATIVE_MODES[mode])
	item.set_meta(MODE_META, mode)

## Remembers what the item was wearing before the pack put anything on it - once, so a second blend
## on the same item does not record the pack's own material as the thing to go back to.
func _remember_worn(item: CanvasItem) -> void:
	if item.has_meta(WORN_META):
		return
	item.set_meta(WORN_META, item.material)

## Puts back whatever was remembered, and forgets it. Nothing remembered means the item wore nothing
## before, which is exactly what it goes back to.
func _restore_worn(item: CanvasItem) -> void:
	_stop_fade(item)
	item.material = item.get_meta(WORN_META, null) as Material
	if item.has_meta(WORN_META):
		item.remove_meta(WORN_META)

## Ends the strength walk on one item, if there is one, leaving the dial wherever it had got to.
func _stop_fade(item: CanvasItem) -> void:
	var key: int = item.get_instance_id()
	var walk: Tween = _fades.get(key, null) as Tween
	if walk != null and walk.is_valid():
		walk.kill()
	_fades.erase(key)

# Blend Modes (autoload): register as the BlendModes autoload, then Blend As is one row - screen for a glow, multiply for a stain, overlay for a texture laid over a surface, colour for a tint that keeps the shading. The five native modes cost nothing; the fifteen shader ones read the screen once per pixel the item covers, so they are for the few things that want them. Mask With hands the shape over to another picture. This pack is an event sheet - extend it by editing it.
