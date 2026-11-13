# EventForge module - the everyday object rows, under the names people look for them by.
#
# Each row is a Godot property or call under a word a newcomer searches for, and its description
# names the real property so the Godot name is learned by using the row. Nothing here wraps anything:
# every row emits the bare line an intermediate Godot user would type, and the sheet reads the same
# line the same way when it is typed by hand.
#
# OPACITY. Godot has no opacity property: it is the alpha of the node's tint (`modulate.a`, 0 to 1).
# The row says "50%" and the code stays `modulate.a = 0.5`, through the fraction reading lens, so the
# number the sheet shows is the one people think in and the number in the script is the one Godot
# stores.
#
# SIZE. A sprite's size is its texture's size times its scale, so Set Sprite Size writes the scale that
# gives that size, and its description says so. A Control has Set Control Size already.
#
# WHERE AN OBJECT ENDS. The four edges are measured in the level (the node's own rectangle through
# its position and scale). A rotated node is measured as if it were not, and the descriptions say so.
#
# ONCE EVER. Trigger Once re-arms each time its condition goes false and true again. Once Ever runs the
# event one time for the life of the object: it declares a plain bool on the script and sets it.
#
# Module contract: see ace_factory.gd - ace_ids/templates are API (compatibility covenant).
@tool
class_name EventForgeCommonObjectACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT_ACTIONS: String = "General Actions"
const CAT_CONDITIONS: String = "General Conditions"
const CAT_EXPRESSIONS: String = "General Expressions"


static func get_descriptors() -> Array[ACEDescriptor]:
	var descriptors: Array[ACEDescriptor] = []

	# -- Opacity ------------------------------------------------------------------------
	var opacity: ACEParam = F.make_param("opacity", "float", "1.0", "Opacity",
		"0 is invisible, 1 is solid. The row shows it as a percentage; the script keeps Godot's 0 to 1.", "expression")
	opacity.display_lens = EventForgeValueLens.LENS_FRACTION
	descriptors.append(F.act("SetOpacity", "Set Opacity", "modulate.a = {opacity}", CAT_ACTIONS, "Set opacity to {opacity}",
		"Sets how see-through the node is. Godot has no opacity property: it is the alpha of the node's tint, so this writes modulate.a, where 0 is invisible and 1 is solid.", "CanvasItem").param_built(opacity))
	descriptors.append(F.expr("Opacity", "Opacity", "modulate.a", CAT_EXPRESSIONS, "opacity",
		"How solid the node is, from 0 (invisible) to 1 (solid). It is the alpha of the node's tint, modulate.a.", "CanvasItem"))

	# -- Size ---------------------------------------------------------------------------------
	# Set Scale (3D) and Set Control Size already exist and write `scale = ...` and `set_size(...)`. A second
	# row with the same line would make a hand-written line read back as either, so there is none.
	descriptors.append(F.act("SetSpriteSize", "Set Sprite Size", "scale = {size} / texture.get_size()", CAT_ACTIONS, "Set size to {size} pixels",
		"Makes a sprite a size in pixels. A sprite has no size property: its size is its picture's size times its scale, so this writes the scale that gives the size you name.", "Sprite2D").param("size", "Vector2(64, 64)", "Size", "Width and height in pixels, as a Vector2.", "expression"))
	descriptors.append(F.expr("SpriteWidth", "Width", "(get_rect().size.x * scale.x)", CAT_EXPRESSIONS, "width",
		"How wide a sprite is on screen, in pixels: its picture's width times its scale. A sprite has no width property.", "Sprite2D"))
	descriptors.append(F.expr("SpriteHeight", "Height", "(get_rect().size.y * scale.y)", CAT_EXPRESSIONS, "height",
		"How tall a sprite is on screen, in pixels: its picture's height times its scale. A sprite has no height property.", "Sprite2D"))

	# -- The four edges ----------------------------------------------------------------------
	descriptors.append(F.expr("SpriteLeft", "Left", "(global_position.x + get_rect().position.x * scale.x)", CAT_EXPRESSIONS, "left edge",
		"The x of the sprite's left edge in the level. A turned sprite is measured as if it were not.", "Sprite2D"))
	descriptors.append(F.expr("SpriteRight", "Right", "(global_position.x + get_rect().end.x * scale.x)", CAT_EXPRESSIONS, "right edge",
		"The x of the sprite's right edge in the level. A turned sprite is measured as if it were not.", "Sprite2D"))
	descriptors.append(F.expr("SpriteTop", "Top", "(global_position.y + get_rect().position.y * scale.y)", CAT_EXPRESSIONS, "top edge",
		"The y of the sprite's top edge in the level (y grows downward). A turned sprite is measured as if it were not.", "Sprite2D"))
	descriptors.append(F.expr("SpriteBottom", "Bottom", "(global_position.y + get_rect().end.y * scale.y)", CAT_EXPRESSIONS, "bottom edge",
		"The y of the sprite's bottom edge in the level (y grows downward). A turned sprite is measured as if it were not.", "Sprite2D"))

	# -- An id, a marker, the level's edge -------------------------------------------------------------
	descriptors.append(F.expr("InstanceId", "Instance Id", "get_instance_id()", CAT_EXPRESSIONS, "instance id",
		"A number that names this object while the game runs. Keep it in a variable and pick the object again later with Pick By UID. It is not saved between runs.", "Node"))
	descriptors.append(F.expr("MarkerPosition", "Marker Position", "(get_node({marker}) as Node2D).global_position", CAT_EXPRESSIONS, "position of marker {marker}",
		"Where a Marker2D child sits in the level - the muzzle of a gun, a hand, a spawn point. Place the Marker2D under the object in the scene and name it here.", "Node2D").param("marker", "\"Marker2D\"", "Marker", "The name of the Marker2D child, in quotes.", "expression"))
	descriptors.append(F.cond("IsOutsideLevelBounds", "Is Outside The Level Bounds", "not {bounds}.has_point(global_position)", CAT_CONDITIONS, "is outside the level bounds {bounds}",
		"True when the node has left a rectangle you name once for the level - a bullet that flew off, a player that fell out of the world. Godot has no fixed scene size, so the rectangle is yours.", "Node2D").param("bounds", "Rect2(0, 0, 1152, 648)", "Bounds", "The level's rectangle, as a Rect2: left, top, width, height.", "expression"))
	descriptors.append(F.cond("IsOutsideCameraLimits", "Is Outside The Camera Limits", "(global_position.x < get_viewport().get_camera_2d().limit_left or global_position.x > get_viewport().get_camera_2d().limit_right or global_position.y < get_viewport().get_camera_2d().limit_top or global_position.y > get_viewport().get_camera_2d().limit_bottom)", CAT_CONDITIONS, "is outside the camera limits",
		"True when the node is beyond the limits set on the current Camera2D - the edges of the level the camera will not show past.", "Node2D"))

	# -- Once ever ------------------------------------------------------------------------------
	descriptors.append(F.cond("OnceEver", "Once Ever", "__once_ever_{uid}()", "Run Context", "Once ever",
		"True the first time the event's other conditions hold, and never again for this object. Trigger Once, by comparison, fires again each time the condition goes false and then true. It keeps one true-or-false variable on the script.").evaluated_last().stateful("var __once_ever_seen_{uid}: bool = false\n\nfunc __once_ever_{uid}() -> bool:\n\tif __once_ever_seen_{uid}:\n\t\treturn false\n\t__once_ever_seen_{uid} = true\n\treturn true"))
	return descriptors
