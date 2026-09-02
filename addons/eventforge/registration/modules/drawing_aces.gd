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
	d.append(F.act("DrawConfigure", "Configure Canvas", "CanvasSurface.for_node({node}).configure({width}, {height}, {auto_clear}, {coordinates}, {display_on_host})", CAT, "configure canvas on {node}", "Sets up (or retunes) the drawing surface on a node - size, auto-clear mode, coordinate mode, and whether it shows on the node.").param_built(_node()).param_typed("int", "width", "512", "Width", "Canvas texture width in pixels.", "expression").param_typed("int", "height", "512", "Height", "Canvas texture height in pixels.", "expression").param_choice("auto_clear", "false", "Auto Clear", "On: wipes every frame (telegraphs). Off: strokes accumulate (paint).", ["true", "false"]).param_choice("coordinates", "\"world\"", "Coordinates", "world = scene positions (centered on the node); canvas = raw texture pixels.", [{"key": "\"world\"", "label": "world"}, {"key": "\"canvas\"", "label": "canvas"}]).param_choice("display_on_host", "true", "Show On Node", "Show the canvas as a centered Sprite2D on the node.", ["true", "false"]))
	d.append(F.act("DrawClear", "Clear Canvas", "CanvasSurface.for_node({node}).clear()", CAT, "clear canvas on {node}", "Wipes the node's canvas. In persistent mode the wipe happens next frame, then strokes keep again.").param_built(_node()))
	d.append(F.act("DrawSetAutoClear", "Set Auto Clear", "CanvasSurface.for_node({node}).set_auto_clear({enabled})", CAT, "set auto clear {enabled} on {node}", "Switches a node's canvas between per-frame wipe (telegraphs, vision cones) and persistent strokes (paint, splats).").param_built(_node()).param_choice("enabled", "true", "Enabled", "On: wipes every frame. Off: strokes stay until Clear Canvas.", ["true", "false"]))

	# ── Shapes ──
	d.append(F.act("DrawLine", "Draw Line", "CanvasSurface.for_node({node}).line({from_x}, {from_y}, {to_x}, {to_y}, {width}, {color})", CAT, "draw line on {node}", "Draws a line segment onto a node's canvas - attack direction indicators, lasers, aim guides.").param_built(_node()).param_built(_num("from_x", "From X")).param_built(_num("from_y", "From Y")).param_built(_num("to_x", "To X")).param_built(_num("to_y", "To Y")).param_typed("float", "width", "2.0", "Width", "Line thickness in pixels.", "expression").param_built(_color()).featured())
	d.append(F.act("DrawCircle", "Draw Circle", "CanvasSurface.for_node({node}).circle({x}, {y}, {radius}, {color})", CAT, "draw circle on {node}", "Draws a filled circle onto a node's canvas - the classic soft blob shadow under a character.").param_built(_node()).param_built(_num("x", "X")).param_built(_num("y", "Y")).param_typed("float", "radius", "16.0", "Radius", "Circle radius in pixels.", "expression").param_built(_color()).featured())
	d.append(F.act("DrawRing", "Draw Ring", "CanvasSurface.for_node({node}).ring({x}, {y}, {radius}, {width}, {color})", CAT, "draw ring on {node}", "Draws a circle outline onto a node's canvas - selection rings, blast-radius previews.").param_built(_node()).param_built(_num("x", "X")).param_built(_num("y", "Y")).param_typed("float", "radius", "16.0", "Radius", "Ring radius in pixels.", "expression").param_typed("float", "width", "2.0", "Width", "Outline thickness.", "expression").param_built(_color()))
	d.append(F.act("DrawRect", "Draw Rect", "CanvasSurface.for_node({node}).rect({x}, {y}, {width}, {height}, {color})", CAT, "draw rect on {node}", "Draws a filled rectangle onto a node's canvas (x/y = top-left corner).").param_built(_node()).param_built(_num("x", "X")).param_built(_num("y", "Y")).param_typed("float", "width", "32.0", "Width", "Rectangle width.", "expression").param_typed("float", "height", "32.0", "Height", "Rectangle height.", "expression").param_built(_color()))
	d.append(F.act("DrawDashedLine", "Draw Dashed Line", "CanvasSurface.for_node({node}).dashed_line({from_x}, {from_y}, {to_x}, {to_y}, {dash_length}, {gap_length}, {width}, {color})", CAT, "draw dashed line on {node}", "Draws a dashed line segment onto a node's canvas - aim guides, tethers, boundary previews. Dash and gap set the on/off rhythm.").param_built(_node()).param_built(_num("from_x", "From X")).param_built(_num("from_y", "From Y")).param_built(_num("to_x", "To X")).param_built(_num("to_y", "To Y")).param_built(_dash()).param_built(_gap()).param_typed("float", "width", "2.0", "Width", "Line thickness in pixels.", "expression").param_built(_color()))
	d.append(F.act("DrawDashedRing", "Draw Dashed Ring", "CanvasSurface.for_node({node}).dashed_ring({x}, {y}, {radius}, {dash_length}, {gap_length}, {width}, {color})", CAT, "draw dashed ring on {node}", "Draws a dashed circle outline onto a node's canvas - range rings, dashed selection markers. Same dash primitive as Draw Dashed Line, wrapped around the circle.").param_built(_node()).param_built(_num("x", "X")).param_built(_num("y", "Y")).param_typed("float", "radius", "16.0", "Radius", "Ring radius in pixels.", "expression").param_built(_dash()).param_built(_gap()).param_typed("float", "width", "2.0", "Width", "Outline thickness.", "expression").param_built(_color()))
	d.append(F.act("DrawDashedRect", "Draw Dashed Rect", "CanvasSurface.for_node({node}).dashed_rect({x}, {y}, {width}, {height}, {dash_length}, {gap_length}, {line_width}, {color})", CAT, "draw dashed rect on {node}", "Draws a dashed rectangle outline onto a node's canvas - selection boxes, build-placement previews, zone markers. The dash rhythm carries continuously around all four sides.").param_built(_node()).param_built(_num("x", "X")).param_built(_num("y", "Y")).param_typed("float", "width", "32.0", "Width", "Rectangle width.", "expression").param_typed("float", "height", "32.0", "Height", "Rectangle height.", "expression").param_built(_dash()).param_built(_gap()).param_typed("float", "line_width", "2.0", "Line Width", "Outline thickness.", "expression").param_built(_color()))
	d.append(F.act("DrawCone", "Draw Cone", "CanvasSurface.for_node({node}).cone({x}, {y}, {facing_deg}, {fov_deg}, {radius}, {color})", CAT, "draw cone on {node}", "Draws a filled wedge onto a node's canvas - the attack-telegraph cone (pair with Auto Clear so it follows each frame).").param_built(_node()).param_built(_num("x", "X")).param_built(_num("y", "Y")).param_typed("float", "facing_deg", "0.0", "Facing", "Facing angle in degrees.", "expression").param_typed("float", "fov_deg", "60.0", "FOV", "Field-of-view width in degrees.", "expression").param_typed("float", "radius", "64.0", "Radius", "Cone reach in pixels.", "expression").param_built(_color()))
	d.append(F.act("DrawStamp", "Draw Stamp", "CanvasSurface.for_node({node}).stamp({texture}, {x}, {y}, {scale_factor}, {rotation_deg})", CAT, "draw stamp on {node}", "Stamps a texture onto a node's canvas - bullet holes, footprints, splats. In persistent mode they pile up like decals.").param_built(_node()).param_typed("Texture2D", "texture", "null", "Texture", "The image to stamp.", "expression").param_built(_num("x", "X")).param_built(_num("y", "Y")).param_typed("float", "scale_factor", "1.0", "Scale", "Stamp scale.", "expression").param_typed("float", "rotation_deg", "0.0", "Rotation", "Stamp rotation in degrees.", "expression"))
	d.append(F.act("DrawLineOfSight", "Draw Line Of Sight", "CanvasSurface.for_node({node}).line_of_sight({origin_x}, {origin_y}, {facing_deg}, {fov_deg}, {max_range}, {collision_mask}, {color})", CAT, "draw line of sight on {node}", "Draws a character's LINE OF SIGHT as a filled fan onto a node's canvas: rays stop at walls so the shape hugs the level. Re-issue each tick with Auto Clear for a live vision cone.").param_built(_node()).param_built(_num("origin_x", "Origin X")).param_built(_num("origin_y", "Origin Y")).param_typed("float", "facing_deg", "0.0", "Facing", "Facing angle in degrees.", "expression").param_typed("float", "fov_deg", "90.0", "FOV", "Cone of view in degrees.", "expression").param_typed("float", "max_range", "300.0", "Range", "Max ray length in pixels.", "expression").param_typed("int", "collision_mask", "1", "Collision Mask", "Physics layers the rays stop on.").param_built(_color()))
	d.append(F.act("DrawPrefabAce", "Draw Prefab", "CanvasSurface.for_node({node}).prefab({prefab}, {x}, {y}, {scale_factor}, {rotation_deg})", CAT, "draw prefab on {node}", "Replays a DrawingPrefabResource's steps onto a node's canvas at a position, scale, and rotation - a target marker or scorch stamped anywhere.").param_built(_node()).param_typed("Resource", "prefab", "null", "Prefab", "A DrawingPrefabResource (.tres) - its steps replay in order.", "expression").param_built(_num("x", "X")).param_built(_num("y", "Y")).param_typed("float", "scale_factor", "1.0", "Scale", "Formation scale.", "expression").param_typed("float", "rotation_deg", "0.0", "Rotation", "Formation rotation in degrees.", "expression"))

	# ── Ribbons ──
	d.append(F.act("DrawStartRibbon", "Start Ribbon", "CanvasSurface.for_node({node}).start_ribbon({follow}, {point_count}, {width}, {color})", CAT, "start ribbon on {node}", "Starts a textured ribbon on a node's canvas trailing another node - sword swooshes, skid marks, comet tails. Its update runs automatically.").param_built(_node()).param_typed("Node", "follow", "self", "Follow", "The node whose trail the ribbon traces.", "expression").param_typed("int", "point_count", "20", "Points", "How many frames of history the ribbon keeps.", "expression").param_typed("float", "width", "8.0", "Width", "Ribbon width.", "expression").param_built(_color()))
	d.append(F.act("DrawSetRibbonTexture", "Set Ribbon Texture", "CanvasSurface.for_node({node}).set_ribbon_texture({follow}, {texture})", CAT, "set ribbon texture on {node}", "Skins a running ribbon with a texture, stretched along its length.").param_built(_node()).param_typed("Node", "follow", "self", "Follow", "The followed node whose ribbon to skin.", "expression").param_typed("Texture2D", "texture", "null", "Texture", "The ribbon texture, stretched along its length.", "expression"))
	d.append(F.act("DrawStopRibbon", "Stop Ribbon", "CanvasSurface.for_node({node}).stop_ribbon({follow})", CAT, "stop ribbon on {node}", "Ends the ribbon trailing a node.").param_built(_node()).param_typed("Node", "follow", "self", "Follow", "The followed node whose ribbon to end.", "expression"))

	# ── Read-back ──
	d.append(F.expr("DrawCanvasTexture", "Canvas Texture", "CanvasSurface.for_node({node}).texture()", CAT, "canvas texture of {node}", "A node's LIVE canvas texture - assign it to a TextureRect, a material, a particle, or a 3D Decal. Updates as the canvas draws.").param_built(_node()))
	d.append(F.cond("DrawIsAutoClear", "Is Auto Clear", "CanvasSurface.for_node({node}).auto_clear", CAT, "canvas on {node} is auto clear", "True when a node's canvas wipes itself every frame.").param_built(_node()))

	return d


static func _node() -> ACEParam:
	return F.make_param("node", "Node", "self", "On", "The canvas host - any Node2D. Its drawing surface is created on first use.", "expression")


## A pixel coordinate on the drawing surface. The sentence is composed from the label rather than
## repeated twenty-six times, so every coordinate field on every drawing row says the same true
## thing, and a field added tomorrow says it too.
static func _num(param_id: String, label: String) -> ACEParam:
	var axis: String = "across" if label.ends_with("X") else "down"
	return F.make_param(param_id, "float", "0.0", label,
		"How far %s, in pixels, in the surface's own coordinates - the space a child node of it would sit in." % axis,
		"expression")


static func _color() -> ACEParam:
	return F.make_param("color", "Color", "Color.WHITE", "Color", "The draw color.", "")


static func _dash() -> ACEParam:
	return F.make_param("dash_length", "float", "12.0", "Dash", "Length of each dash in pixels.", "expression")


static func _gap() -> ACEParam:
	return F.make_param("gap_length", "float", "8.0", "Gap", "Gap between dashes in pixels.", "expression")


static func section_descriptions() -> Dictionary:
	return {CAT: "Draw shapes, ribbons, and prefabs onto any node's 2D canvas - the pickable form of the Drawing Canvas pack's actions, backed by the shared CanvasSurface runtime. Persistent strokes or per-frame telegraphs; the live texture feeds sprites, UI, materials, or a 3D Decal."}
