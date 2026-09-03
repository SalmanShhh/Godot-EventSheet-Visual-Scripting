# Pack builder - blend_modes (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## Blend Modes: the twenty ways one picture can meet the one behind it, as rows.
##
## Godot draws five of them by itself - normal, add, subtract, multiply and premultiplied are fields
## on a CanvasItemMaterial, and a sprite set to one of them costs exactly what a sprite costs. The
## other fifteen (screen, overlay, the two colour ones, the four light-and-dark ones, the rest) are
## the ones every drawing tool has and Godot has no field for, because they need the pixels that are
## already on the screen: the item has to read them back and do the arithmetic itself. That is a
## shader per mode, and writing one is where the idea usually stops.
##
## So the pack ships them: fifteen shaders beside this script, one per mode, each with one dial, plus
## a mask shader that lets a second picture decide where the first is allowed to be. One row picks a
## mode by its ordinary name and the pack finds the file.
##
## The shaders are REAL FILES in the source folder, not strings built at run time - highlighted,
## parse-checked on import, and copied into the pack folder by `Lib.ship_files` the way any other
## companion a pack needs would be. The behaviour code is a real file too, so every verb here is
## ordinary GDScript with its own annotations rather than a quoted array of lines.
static func build() -> bool:
	var src: Lib.PackSource = Lib.pack_from_source("blend_modes", "Node", "BlendModesAddon",
		"The twenty ways a picture can meet the one behind it, as rows: the five Godot draws by itself, and fifteen that read the screen back through a shader the pack ships - screen, overlay, the light-and-dark family, difference, and the four that take a colour apart. Plus a mask, so a second picture decides where the first is allowed to be. Ships as the BlendModes autoload, so any sheet can blend any canvas item.",
		Lib.manifest().autoload("BlendModes").category("Blend Modes").tags(["visual", "shader", "juice", "effects", "blend"]))
	src.note("Blend Modes (autoload): register as the BlendModes autoload, then Blend As is one row - screen for a glow, multiply for a stain, overlay for a texture laid over a surface, colour for a tint that keeps the shading. The five native modes cost nothing; the fifteen shader ones read the screen once per pixel the item covers, so they are for the few things that want them. Mask With hands the shape over to another picture. This pack is an event sheet - extend it by editing it.")
	src.block("runtime")
	if not Lib.publish(src, "res://eventsheet_addons/blend_modes/blend_modes_addon"):
		return false
	# The shaders ARE the pack: fifteen of the twenty modes do not exist without one, so a pack
	# folder without them is a pack that silently does nothing. They ship in the same build.
	return Lib.ship_files("blend_modes", "res://eventsheet_addons/blend_modes/blend_modes_addon",
		PackedStringArray(["gdshader"]))
