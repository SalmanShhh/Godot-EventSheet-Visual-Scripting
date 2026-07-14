# EventForge module - Drawing (2D immediate-mode canvas, on any node).
#
# Draw shapes, ribbons, and prefabs onto ANY Node2D without attaching the Drawing Canvas behavior: each
# verb calls CanvasSurface.for_node({node}), which lazily builds one offscreen render target per node and
# caches it on the node. This is the first-class, pickable form of the Drawing Canvas pack's verbs - same
# runtime, usable in any sheet. CanvasSurface ships with eventsheet_addons/ (plain GDScript, no editor
# plugin), so generated games carry it like any other pack runtime; ace_ids/templates are API once shipped.
# Module contract: see ace_factory.gd.
@tool
class_name EventForgeDrawingACEs
extends RefCounted

const F := preload("res://addons/eventforge/registration/ace_factory.gd")

const CAT := "Drawing"


static func get_descriptors() -> Array[ACEDescriptor]:
	var d: Array[ACEDescriptor] = []

	# ── Setup / control ──
	d.append(F.make_descriptor("Core", "DrawConfigure", "Configure Canvas", ACEDescriptor.ACEType.ACTION, "CanvasSurface.for_node({node}).configure({width}, {height}, {auto_clear}, {coordinates}, {display_on_host})", "", [_node(), F.make_param("width", "int", "512", "Width", "Canvas texture width in pixels.", "expression"), F.make_param("height", "int", "512", "Height", "Canvas texture height in pixels.", "expression"), F.make_param("auto_clear", "String", "false", "Auto Clear", "On: wipes every frame (telegraphs). Off: strokes accumulate (paint).", "", ["true", "false"]), F.make_param("coordinates", "String", "\"world\"", "Coordinates", "world = scene positions (centered on the node); canvas = raw texture pixels.", "", ["world", "canvas"]), F.make_param("display_on_host", "String", "true", "Show On Node", "Show the canvas as a centered Sprite2D on the node.", "", ["true", "false"])], CAT, "configure canvas on {node}")
		.described("Sets up (or retunes) the drawing surface on a node - size, auto-clear mode, coordinate mode, and whether it shows on the node."))
	d.append(F.make_descriptor("Core", "DrawClear", "Clear Canvas", ACEDescriptor.ACEType.ACTION, "CanvasSurface.for_node({node}).clear()", "", [_node()], CAT, "clear canvas on {node}")
		.described("Wipes the node's canvas. In persistent mode the wipe happens next frame, then strokes keep again."))
	d.append(F.make_descriptor("Core", "DrawSetAutoClear", "Set Auto Clear", ACEDescriptor.ACEType.ACTION, "CanvasSurface.for_node({node}).set_auto_clear({enabled})", "", [_node(), F.make_param("enabled", "String", "true", "Enabled", "On: wipes every frame. Off: strokes stay until Clear Canvas.", "", ["true", "false"])], CAT, "set auto clear {enabled} on {node}")
		.described("Switches a node's canvas between per-frame wipe (telegraphs, vision cones) and persistent strokes (paint, splats)."))

	# ── Shapes ──
	d.append(F.make_descriptor("Core", "DrawLine", "Draw Line", ACEDescriptor.ACEType.ACTION, "CanvasSurface.for_node({node}).line({from_x}, {from_y}, {to_x}, {to_y}, {width}, {color})", "", [_node(), _num("from_x", "From X"), _num("from_y", "From Y"), _num("to_x", "To X"), _num("to_y", "To Y"), F.make_param("width", "float", "2.0", "Width", "Line thickness in pixels.", "expression"), _color()], CAT, "draw line on {node}")
		.described("Draws a line segment onto a node's canvas - attack direction indicators, lasers, aim guides.").featured())
	d.append(F.make_descriptor("Core", "DrawCircle", "Draw Circle", ACEDescriptor.ACEType.ACTION, "CanvasSurface.for_node({node}).circle({x}, {y}, {radius}, {color})", "", [_node(), _num("x", "X"), _num("y", "Y"), F.make_param("radius", "float", "16.0", "Radius", "Circle radius in pixels.", "expression"), _color()], CAT, "draw circle on {node}")
		.described("Draws a filled circle onto a node's canvas - the classic soft blob shadow under a character.").featured())
	d.append(F.make_descriptor("Core", "DrawRing", "Draw Ring", ACEDescriptor.ACEType.ACTION, "CanvasSurface.for_node({node}).ring({x}, {y}, {radius}, {width}, {color})", "", [_node(), _num("x", "X"), _num("y", "Y"), F.make_param("radius", "float", "16.0", "Radius", "Ring radius in pixels.", "expression"), F.make_param("width", "float", "2.0", "Width", "Outline thickness.", "expression"), _color()], CAT, "draw ring on {node}")
		.described("Draws a circle outline onto a node's canvas - selection rings, blast-radius previews."))
	d.append(F.make_descriptor("Core", "DrawRect", "Draw Rect", ACEDescriptor.ACEType.ACTION, "CanvasSurface.for_node({node}).rect({x}, {y}, {width}, {height}, {color})", "", [_node(), _num("x", "X"), _num("y", "Y"), F.make_param("width", "float", "32.0", "Width", "Rectangle width.", "expression"), F.make_param("height", "float", "32.0", "Height", "Rectangle height.", "expression"), _color()], CAT, "draw rect on {node}")
		.described("Draws a filled rectangle onto a node's canvas (x/y = top-left corner)."))
	d.append(F.make_descriptor("Core", "DrawDashedLine", "Draw Dashed Line", ACEDescriptor.ACEType.ACTION, "CanvasSurface.for_node({node}).dashed_line({from_x}, {from_y}, {to_x}, {to_y}, {dash_length}, {gap_length}, {width}, {color})", "", [_node(), _num("from_x", "From X"), _num("from_y", "From Y"), _num("to_x", "To X"), _num("to_y", "To Y"), _dash(), _gap(), F.make_param("width", "float", "2.0", "Width", "Line thickness in pixels.", "expression"), _color()], CAT, "draw dashed line on {node}")
		.described("Draws a dashed line segment onto a node's canvas - aim guides, tethers, boundary previews. Dash and gap set the on/off rhythm."))
	d.append(F.make_descriptor("Core", "DrawDashedRing", "Draw Dashed Ring", ACEDescriptor.ACEType.ACTION, "CanvasSurface.for_node({node}).dashed_ring({x}, {y}, {radius}, {dash_length}, {gap_length}, {width}, {color})", "", [_node(), _num("x", "X"), _num("y", "Y"), F.make_param("radius", "float", "16.0", "Radius", "Ring radius in pixels.", "expression"), _dash(), _gap(), F.make_param("width", "float", "2.0", "Width", "Outline thickness.", "expression"), _color()], CAT, "draw dashed ring on {node}")
		.described("Draws a dashed circle outline onto a node's canvas - range rings, dashed selection markers. Same dash primitive as Draw Dashed Line, wrapped around the circle."))
	d.append(F.make_descriptor("Core", "DrawDashedRect", "Draw Dashed Rect", ACEDescriptor.ACEType.ACTION, "CanvasSurface.for_node({node}).dashed_rect({x}, {y}, {width}, {height}, {dash_length}, {gap_length}, {line_width}, {color})", "", [_node(), _num("x", "X"), _num("y", "Y"), F.make_param("width", "float", "32.0", "Width", "Rectangle width.", "expression"), F.make_param("height", "float", "32.0", "Height", "Rectangle height.", "expression"), _dash(), _gap(), F.make_param("line_width", "float", "2.0", "Line Width", "Outline thickness.", "expression"), _color()], CAT, "draw dashed rect on {node}")
		.described("Draws a dashed rectangle outline onto a node's canvas - selection boxes, build-placement previews, zone markers. The dash rhythm carries continuously around all four sides."))
	d.append(F.make_descriptor("Core", "DrawCone", "Draw Cone", ACEDescriptor.ACEType.ACTION, "CanvasSurface.for_node({node}).cone({x}, {y}, {facing_deg}, {fov_deg}, {radius}, {color})", "", [_node(), _num("x", "X"), _num("y", "Y"), F.make_param("facing_deg", "float", "0.0", "Facing", "Facing angle in degrees.", "expression"), F.make_param("fov_deg", "float", "60.0", "FOV", "Field-of-view width in degrees.", "expression"), F.make_param("radius", "float", "64.0", "Radius", "Cone reach in pixels.", "expression"), _color()], CAT, "draw cone on {node}")
		.described("Draws a filled wedge onto a node's canvas - the attack-telegraph cone (pair with Auto Clear so it follows each frame)."))
	d.append(F.make_descriptor("Core", "DrawStamp", "Draw Stamp", ACEDescriptor.ACEType.ACTION, "CanvasSurface.for_node({node}).stamp({texture}, {x}, {y}, {scale_factor}, {rotation_deg})", "", [_node(), F.make_param("texture", "Texture2D", "null", "Texture", "The image to stamp.", "expression"), _num("x", "X"), _num("y", "Y"), F.make_param("scale_factor", "float", "1.0", "Scale", "Stamp scale.", "expression"), F.make_param("rotation_deg", "float", "0.0", "Rotation", "Stamp rotation in degrees.", "expression")], CAT, "draw stamp on {node}")
		.described("Stamps a texture onto a node's canvas - bullet holes, footprints, splats. In persistent mode they pile up like decals."))
	d.append(F.make_descriptor("Core", "DrawLineOfSight", "Draw Line Of Sight", ACEDescriptor.ACEType.ACTION, "CanvasSurface.for_node({node}).line_of_sight({origin_x}, {origin_y}, {facing_deg}, {fov_deg}, {max_range}, {collision_mask}, {color})", "", [_node(), _num("origin_x", "Origin X"), _num("origin_y", "Origin Y"), F.make_param("facing_deg", "float", "0.0", "Facing", "Facing angle in degrees.", "expression"), F.make_param("fov_deg", "float", "90.0", "FOV", "Cone of view in degrees.", "expression"), F.make_param("max_range", "float", "300.0", "Range", "Max ray length in pixels.", "expression"), F.make_param("collision_mask", "int", "1", "Collision Mask", "Physics layers the rays stop on.", ""), _color()], CAT, "draw line of sight on {node}")
		.described("Draws a character's LINE OF SIGHT as a filled fan onto a node's canvas: rays stop at walls so the shape hugs the level. Re-issue each tick with Auto Clear for a live vision cone."))
	d.append(F.make_descriptor("Core", "DrawPrefabAce", "Draw Prefab", ACEDescriptor.ACEType.ACTION, "CanvasSurface.for_node({node}).prefab({prefab}, {x}, {y}, {scale_factor}, {rotation_deg})", "", [_node(), F.make_param("prefab", "Resource", "null", "Prefab", "A DrawingPrefabResource (.tres) - its steps replay in order.", "expression"), _num("x", "X"), _num("y", "Y"), F.make_param("scale_factor", "float", "1.0", "Scale", "Formation scale.", "expression"), F.make_param("rotation_deg", "float", "0.0", "Rotation", "Formation rotation in degrees.", "expression")], CAT, "draw prefab on {node}")
		.described("Replays a DrawingPrefabResource's steps onto a node's canvas at a position, scale, and rotation - a target marker or scorch stamped anywhere."))

	# ── Ribbons ──
	d.append(F.make_descriptor("Core", "DrawStartRibbon", "Start Ribbon", ACEDescriptor.ACEType.ACTION, "CanvasSurface.for_node({node}).start_ribbon({follow}, {point_count}, {width}, {color})", "", [_node(), F.make_param("follow", "Node", "self", "Follow", "The node whose trail the ribbon traces.", "expression"), F.make_param("point_count", "int", "20", "Points", "How many frames of history the ribbon keeps.", "expression"), F.make_param("width", "float", "8.0", "Width", "Ribbon width.", "expression"), _color()], CAT, "start ribbon on {node}")
		.described("Starts a textured ribbon on a node's canvas trailing another node - sword swooshes, skid marks, comet tails. Its update runs automatically."))
	d.append(F.make_descriptor("Core", "DrawSetRibbonTexture", "Set Ribbon Texture", ACEDescriptor.ACEType.ACTION, "CanvasSurface.for_node({node}).set_ribbon_texture({follow}, {texture})", "", [_node(), F.make_param("follow", "Node", "self", "Follow", "The followed node whose ribbon to skin.", "expression"), F.make_param("texture", "Texture2D", "null", "Texture", "The ribbon texture, stretched along its length.", "expression")], CAT, "set ribbon texture on {node}")
		.described("Skins a running ribbon with a texture, stretched along its length."))
	d.append(F.make_descriptor("Core", "DrawStopRibbon", "Stop Ribbon", ACEDescriptor.ACEType.ACTION, "CanvasSurface.for_node({node}).stop_ribbon({follow})", "", [_node(), F.make_param("follow", "Node", "self", "Follow", "The followed node whose ribbon to end.", "expression")], CAT, "stop ribbon on {node}")
		.described("Ends the ribbon trailing a node."))

	# ── Read-back ──
	d.append(F.make_descriptor("Core", "DrawCanvasTexture", "Canvas Texture", ACEDescriptor.ACEType.EXPRESSION, "CanvasSurface.for_node({node}).texture()", "", [_node()], CAT, "canvas texture of {node}")
		.described("A node's LIVE canvas texture - assign it to a TextureRect, a material, a particle, or a 3D Decal. Updates as the canvas draws."))
	d.append(F.make_descriptor("Core", "DrawIsAutoClear", "Is Auto Clear", ACEDescriptor.ACEType.CONDITION, "CanvasSurface.for_node({node}).auto_clear", "", [_node()], CAT, "canvas on {node} is auto clear")
		.described("True when a node's canvas wipes itself every frame."))

	return d


static func _node() -> ACEParam:
	return F.make_param("node", "Node", "self", "On", "The canvas host - any Node2D. Its drawing surface is created on first use.", "expression")


static func _num(param_id: String, label: String) -> ACEParam:
	return F.make_param(param_id, "float", "0.0", label, "", "expression")


static func _color() -> ACEParam:
	return F.make_param("color", "Color", "Color.WHITE", "Color", "The draw color.", "")


static func _dash() -> ACEParam:
	return F.make_param("dash_length", "float", "12.0", "Dash", "Length of each dash in pixels.", "expression")


static func _gap() -> ACEParam:
	return F.make_param("gap_length", "float", "8.0", "Gap", "Gap between dashes in pixels.", "expression")


static func section_descriptions() -> Dictionary:
	return {CAT: "Draw shapes, ribbons, and prefabs onto any node's 2D canvas - the pickable form of the Drawing Canvas verbs, backed by the shared CanvasSurface runtime. Persistent strokes or per-frame telegraphs; the live texture feeds sprites, UI, materials, or a 3D Decal."}
