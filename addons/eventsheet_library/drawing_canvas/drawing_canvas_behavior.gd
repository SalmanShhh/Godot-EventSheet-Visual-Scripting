## @ace_tags(drawing, visual)
## @ace_category("Drawing Canvas")
## @ace_requires(CanvasSurface, DrawingPrefabResource)
## @ace_version(1.0.0)
@icon("res://eventsheet_addons/drawing_canvas/icon.svg")
class_name DrawingCanvas
extends Node
## A texture your event sheet draws onto with actions: lines, circles, rings, rects, cones, stamps, textured ribbons, and a raycast line-of-sight fan. Strokes can persist until cleared or auto-clear every frame, and the live texture is an expression you can feed to a TextureRect, shader, particle, or 3D Decal.

## The node this behavior acts on (its parent). Required host: Node2D.
var host: Node2D = null

func _enter_tree() -> void:
	host = get_parent() as Node2D
	if host == null:
		push_warning("DrawingCanvas behavior requires a Node2D parent.")

# --- Designer knobs (tune in the Inspector) ---
## Canvas texture width in pixels.
@export var canvas_width: int = 512
## Canvas texture height in pixels.
@export var canvas_height: int = 512
## On: the canvas clears itself every frame - re-issue draw actions each tick (vision
## cones, telegraphs). Off: strokes accumulate until Clear Canvas (paint, splats).
@export var auto_clear: bool = false
## How draw coordinates are read: world = scene positions (the canvas is centered on
## the host and follows it); canvas = raw pixels on the texture (0,0 = top-left).
@export_enum("world", "canvas") var coordinates: String = "world"
## Show the canvas on the host (a centered Sprite2D child). Off: the canvas renders
## offscreen and you place Canvas Texture wherever you want it.
@export var display_on_host: bool = true

## A prefab to preview in the 2D EDITOR viewport, drawn at this node so you can position a
## formation before wiring Draw Prefab. Design aid only - the running game never draws it.
@export_group("Editor Preview")
@export var preview_prefab: DrawingPrefabResource = null
## Scale of the editor preview.
@export var preview_scale: float = 1.0
## Rotation of the editor preview, in degrees.
@export var preview_rotation: float = 0.0

## The canvas's LIVE texture - assign it to a TextureRect, a material, a particle, or a
## 3D Decal (the Decal Painter pack accepts it directly). Updates as the canvas draws.
## @ace_expression
## @ace_name("Canvas Texture")
## @ace_display_template("The live canvas texture")
func canvas_texture() -> Texture2D:
	return CanvasSurface.for_node(host).texture()

func _ready() -> void:
	CanvasSurface.for_node(host).configure(canvas_width, canvas_height, auto_clear, coordinates, display_on_host)

## @ace_condition
## @ace_name("Is Auto Clear")
## @ace_display_template("Canvas auto-clears each frame")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.is_auto_clear()")
func is_auto_clear() -> bool:
	return CanvasSurface.for_node(host).auto_clear

## Wipes the canvas. In persistent mode the wipe happens on the next frame and the
## canvas keeps strokes again afterwards.
## @ace_action
## @ace_name("Clear Canvas")
## @ace_display_template("Clear the canvas")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.clear_canvas()")
func clear_canvas() -> void:
	CanvasSurface.for_node(host).clear()

## On: the canvas wipes itself every frame (re-issue draws each tick - vision cones,
## telegraphs). Off: strokes stay until Clear Canvas (paint, splats, skid marks).
## @ace_action
## @ace_name("Set Auto Clear")
## @ace_display_template("Set auto clear to {enabled}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.set_auto_clear({enabled})")
func set_auto_clear(enabled: bool) -> void:
	CanvasSurface.for_node(host).set_auto_clear(enabled)

## Shows or hides the canvas display on the host.
## @ace_action
## @ace_name("Set Canvas Visible")
## @ace_display_template("Set the canvas visible to {visible_now}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.set_canvas_visible({visible_now})")
func set_canvas_visible(visible_now: bool) -> void:
	CanvasSurface.for_node(host).set_display_visible(visible_now)

## Draws a line segment - attack direction indicators, lasers, aim guides.
## @ace_action
## @ace_name("Draw Line")
## @ace_display_template("Draw a line from ({from_x}, {from_y}) to ({to_x}, {to_y})")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_line({from_x}, {from_y}, {to_x}, {to_y}, {width}, {color})")
func draw_canvas_line(from_x: float, from_y: float, to_x: float, to_y: float, width: float, color: Color) -> void:
	CanvasSurface.for_node(host).line(from_x, from_y, to_x, to_y, width, color)

## Draws a filled circle - the classic soft blob shadow under a character.
## @ace_action
## @ace_name("Draw Circle")
## @ace_display_template("Draw a circle at ({x}, {y}), radius {radius}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_circle({x}, {y}, {radius}, {color})")
func draw_canvas_circle(x: float, y: float, radius: float, color: Color) -> void:
	CanvasSurface.for_node(host).circle(x, y, radius, color)

## Draws a circle outline - selection rings, blast-radius previews.
## @ace_action
## @ace_name("Draw Ring")
## @ace_display_template("Draw a ring at ({x}, {y}), radius {radius}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_ring({x}, {y}, {radius}, {width}, {color})")
func draw_canvas_ring(x: float, y: float, radius: float, width: float, color: Color) -> void:
	CanvasSurface.for_node(host).ring(x, y, radius, width, color)

## Draws a filled rectangle (x/y = top-left corner).
## @ace_action
## @ace_name("Draw Rect")
## @ace_display_template("Draw a rect at ({x}, {y}), {width} by {height}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_rect({x}, {y}, {width}, {height}, {color})")
func draw_canvas_rect(x: float, y: float, width: float, height: float, color: Color) -> void:
	CanvasSurface.for_node(host).rect(x, y, width, height, color)

## Draws a DASHED line segment - aim guides, tethers, boundary previews. dash_length and
## gap_length set the on/off rhythm.
## @ace_action
## @ace_name("Draw Dashed Line")
## @ace_display_template("Draw a dashed line from ({from_x}, {from_y}) to ({to_x}, {to_y})")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_dashed_line({from_x}, {from_y}, {to_x}, {to_y}, {dash_length}, {gap_length}, {width}, {color})")
func draw_canvas_dashed_line(from_x: float, from_y: float, to_x: float, to_y: float, dash_length: float, gap_length: float, width: float, color: Color) -> void:
	CanvasSurface.for_node(host).dashed_line(from_x, from_y, to_x, to_y, dash_length, gap_length, width, color)

## Draws a DASHED circle outline - range rings, dashed selection markers. The same dash
## primitive as Draw Dashed Line, wrapped around the circle.
## @ace_action
## @ace_name("Draw Dashed Ring")
## @ace_display_template("Draw a dashed ring at ({x}, {y}), radius {radius}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_dashed_ring({x}, {y}, {radius}, {dash_length}, {gap_length}, {width}, {color})")
func draw_canvas_dashed_ring(x: float, y: float, radius: float, dash_length: float, gap_length: float, width: float, color: Color) -> void:
	CanvasSurface.for_node(host).dashed_ring(x, y, radius, dash_length, gap_length, width, color)

## Draws a DASHED rectangle outline - selection boxes, build-placement previews, zone
## markers. The dash rhythm carries continuously around all four sides.
## @ace_action
## @ace_name("Draw Dashed Rect")
## @ace_display_template("Draw a dashed rect at ({x}, {y}), {width} by {height}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_dashed_rect({x}, {y}, {width}, {height}, {dash_length}, {gap_length}, {line_width}, {color})")
func draw_canvas_dashed_rect(x: float, y: float, width: float, height: float, dash_length: float, gap_length: float, line_width: float, color: Color) -> void:
	CanvasSurface.for_node(host).dashed_rect(x, y, width, height, dash_length, gap_length, line_width, color)

## Draws a filled wedge - the attack-telegraph cone (pair with Auto Clear so it follows
## the attacker every frame).
## @ace_action
## @ace_name("Draw Cone")
## @ace_display_template("Draw a cone at ({x}, {y}) facing {facing_deg} deg, fov {fov_deg} deg")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_cone({x}, {y}, {facing_deg}, {fov_deg}, {radius}, {color})")
func draw_canvas_cone(x: float, y: float, facing_deg: float, fov_deg: float, radius: float, color: Color) -> void:
	CanvasSurface.for_node(host).cone(x, y, facing_deg, fov_deg, radius, color)

## Stamps a texture onto the canvas - bullet holes, footprints, splats. In persistent
## mode stamps pile up like decals.
## @ace_action
## @ace_name("Draw Stamp")
## @ace_display_template("Stamp {texture} at ({x}, {y})")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_stamp({texture}, {x}, {y}, {scale_factor}, {rotation_deg})")
func draw_canvas_stamp(texture: Texture2D, x: float, y: float, scale_factor: float, rotation_deg: float) -> void:
	CanvasSurface.for_node(host).stamp(texture, x, y, scale_factor, rotation_deg)

## Draws a character's LINE OF SIGHT as a filled fan: rays cast against the collision
## mask stop at walls, so the shape hugs the level exactly. Re-issue each tick with
## Auto Clear on for a live vision cone. Origin and range are WORLD coordinates.
## @ace_action
## @ace_name("Draw Line Of Sight")
## @ace_display_template("Draw line of sight from ({origin_x}, {origin_y}) facing {facing_deg} deg, range {max_range}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_line_of_sight({origin_x}, {origin_y}, {facing_deg}, {fov_deg}, {max_range}, {collision_mask}, {color})")
func draw_line_of_sight(origin_x: float, origin_y: float, facing_deg: float, fov_deg: float, max_range: float, collision_mask: int, color: Color) -> void:
	CanvasSurface.for_node(host).line_of_sight(origin_x, origin_y, facing_deg, fov_deg, max_range, collision_mask, color)

## Replays a DrawingPrefabResource's steps IN ORDER at a position, scaled and rotated -
## author a target marker or scorch formation once as a .tres, stamp it everywhere.
## @ace_action
## @ace_name("Draw Prefab")
## @ace_display_template("Stamp a prefab at ({x}, {y})")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_prefab({prefab}, {x}, {y}, {scale_factor}, {rotation_deg})")
func draw_prefab(prefab: Resource, x: float, y: float, scale_factor: float, rotation_deg: float) -> void:
	CanvasSurface.for_node(host).prefab(prefab, x, y, scale_factor, rotation_deg)

## Starts a textured ribbon trailing a node - sword swooshes, skid marks, comet tails.
## The ribbon follows for Point Count frames of history; Set Ribbon Texture skins it.
## @ace_action
## @ace_name("Start Ribbon")
## @ace_display_template("Start a ribbon trailing {follow}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.start_ribbon({follow}, {point_count}, {width}, {color})")
func start_ribbon(follow: Node, point_count: int, width: float, color: Color) -> void:
	CanvasSurface.for_node(host).start_ribbon(follow, point_count, width, color)

## Skins a running ribbon with a texture, stretched along its length.
## @ace_action
## @ace_name("Set Ribbon Texture")
## @ace_display_template("Skin {follow}'s ribbon with {texture}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.set_ribbon_texture({follow}, {texture})")
func set_ribbon_texture(follow: Node, texture: Texture2D) -> void:
	CanvasSurface.for_node(host).set_ribbon_texture(follow, texture)

## Ends the ribbon trailing a node.
## @ace_action
## @ace_name("Stop Ribbon")
## @ace_display_template("Stop the ribbon trailing {follow}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.stop_ribbon({follow})")
func stop_ribbon(follow: Node) -> void:
	CanvasSurface.for_node(host).stop_ribbon(follow)

## Bakes a node's CURRENT visual onto the canvas at its own world position - stamp a sprite, decal or
## icon permanently (persistent mode) or once per frame (auto clear). Non-destructive: the node stays,
## so pair it with Destroy to bake decor into one texture. Sprites, animated sprites and texture rects
## paste with their rotation, scale, flip, frame and tint; a node with no texture is skipped.
## @ace_action
## @ace_name("Paste Node")
## @ace_display_template("Paste {node} onto the canvas")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.paste_node({node})")
func paste_node(node: Node) -> void:
	CanvasSurface.for_node(host).paste_node(node)

## Bakes a node's visual at an EXPLICIT spot (read like the other draw coordinates), scaled and rotated -
## stamp an off-screen template sprite anywhere, any number of times.
## @ace_action
## @ace_name("Paste Node At")
## @ace_display_template("Paste {node} at ({x}, {y})")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.paste_node_at({node}, {x}, {y}, {scale_factor}, {rotation_deg})")
func paste_node_at(node: Node, x: float, y: float, scale_factor: float, rotation_deg: float) -> void:
	CanvasSurface.for_node(host).paste_node_at(node, x, y, scale_factor, rotation_deg)

## Bakes every visible texture-bearing node under {layer} that is currently ON SCREEN onto the canvas -
## flatten a whole layer of decor into one texture (pair with Destroy for a performance bake). {layer}
## is any parent: a CanvasLayer, a container node, or the scene root.
## @ace_action
## @ace_name("Paste Layer On Screen")
## @ace_display_template("Paste everything on screen under {layer}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.paste_layer_on_screen({layer})")
func paste_layer_on_screen(layer: Node) -> void:
	CanvasSurface.for_node(host).paste_layer_on_screen(layer)

## Bakes every visible texture-bearing node under {layer} whose world rect falls inside the box at
## ({x}, {y}) sized {width} by {height} (world coordinates) onto the canvas - flatten a region
## regardless of the camera.
## @ace_action
## @ace_name("Paste Layer In Box")
## @ace_display_template("Paste everything under {layer} inside the box at ({x}, {y})")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.paste_layer_in_box({layer}, {x}, {y}, {width}, {height})")
func paste_layer_in_box(layer: Node, x: float, y: float, width: float, height: float) -> void:
	CanvasSurface.for_node(host).paste_layer_in_box(layer, x, y, width, height)

## Hands the canvas a draw STYLE: every styled row after this one draws with that file's
## thickness, caps, colour and dashes until the style is replaced, popped or reset. An empty
## slot is the canvas's own defaults. The rows that carry their own width and colour are
## untouched by it - a style is for the rows below, which carry neither.
## @ace_action
## @ace_featured
## @ace_name("Set Draw Style")
## @ace_display_template("Set the draw style to {style}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.set_draw_style({style})")
func set_draw_style(style: Resource) -> void:
	CanvasSurface.for_node(host).set_draw_style(style)

## Sets a style with the one in force kept underneath it - draw, then Pop Draw Style, and the
## rows carry on in the style they were in before.
## @ace_action
## @ace_name("Push Draw Style")
## @ace_display_template("Push the draw style {style}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.push_draw_style({style})")
func push_draw_style(style: Resource) -> void:
	CanvasSurface.for_node(host).push_draw_style(style)

## Goes back to the style that was in force before the last Push Draw Style.
## @ace_action
## @ace_name("Pop Draw Style")
## @ace_display_template("Pop the draw style")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.pop_draw_style()")
func pop_draw_style() -> void:
	CanvasSurface.for_node(host).pop_draw_style()

## Drops the whole stack: the canvas draws in its own defaults again.
## @ace_action
## @ace_name("Reset Draw Style")
## @ace_display_template("Reset the draw style")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.reset_draw_style()")
func reset_draw_style() -> void:
	CanvasSurface.for_node(host).reset_draw_style()

## Draws an arc of a circle in the current draw style - the cooldown sweep, the turn radius,
## the range band. Angles are degrees, measured the way the engine measures them.
## @ace_action
## @ace_featured
## @ace_name("Draw Arc")
## @ace_display_template("Draw an arc at ({x}, {y}), radius {radius}, {from_degrees} to {to_degrees} degrees")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_arc_shape({x}, {y}, {radius}, {from_degrees}, {to_degrees})")
func draw_arc_shape(x: float, y: float, radius: float, from_degrees: float, to_degrees: float) -> void:
	CanvasSurface.for_node(host).draw_arc_shape(x, y, radius, from_degrees, to_degrees)

## Draws a filled wedge of a circle in the current draw style - the same two angles as an arc,
## filled in: the attack telegraph, the pie slice, the vision wedge.
## @ace_action
## @ace_name("Draw Pie")
## @ace_display_template("Draw a pie at ({x}, {y}), radius {radius}, {from_degrees} to {to_degrees} degrees")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_pie({x}, {y}, {radius}, {from_degrees}, {to_degrees})")
func draw_pie(x: float, y: float, radius: float, from_degrees: float, to_degrees: float) -> void:
	CanvasSurface.for_node(host).draw_pie(x, y, radius, from_degrees, to_degrees)

## Draws a rectangle with rounded corners from its CENTRE, filled or as an outline - the panel,
## the selection box, the button plate.
## @ace_action
## @ace_name("Draw Rounded Rect")
## @ace_display_template("Draw a rounded rect at ({x}, {y}), {width} by {height}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_rounded_rect({x}, {y}, {width}, {height}, {corner_radius}, {filled})")
func draw_rounded_rect(x: float, y: float, width: float, height: float, corner_radius: float, filled: bool) -> void:
	CanvasSurface.for_node(host).draw_rounded_rect(x, y, width, height, corner_radius, filled)

## Draws a shape of N equal sides at a radius, from its centre - the hex cell, the warning
## triangle, the stop sign.
## @ace_action
## @ace_name("Draw Regular Polygon")
## @ace_display_template("Draw a {sides}-sided polygon at ({x}, {y}), radius {radius}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_regular_polygon({x}, {y}, {radius}, {sides}, {angle_degrees}, {filled})")
func draw_regular_polygon(x: float, y: float, radius: float, sides: int, angle_degrees: float, filled: bool) -> void:
	CanvasSurface.for_node(host).draw_regular_polygon(x, y, radius, sides, angle_degrees, filled)

## Draws a closed outline through a list of positions, filled or hollow. Concave outlines are
## allowed: the engine triangulates a filled one.
## @ace_action
## @ace_name("Draw Polygon")
## @ace_display_template("Draw a polygon through {points}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_polygon_shape({points}, {filled})")
func draw_polygon_shape(points: Array, filled: bool) -> void:
	CanvasSurface.for_node(host).draw_polygon_shape(points, filled)

## Draws a path through a list of positions, open or closed - the route preview, the drawn
## trail, the border of a claimed region.
## @ace_action
## @ace_name("Draw Polyline")
## @ace_display_template("Draw a polyline through {points}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_polyline_shape({points}, {closed})")
func draw_polyline_shape(points: Array, closed: bool) -> void:
	CanvasSurface.for_node(host).draw_polyline_shape(points, closed)

## Draws a line of text at a spot in the style's colour - the state name over an enemy, the
## number over a tile, the label on a debug overlay.
## @ace_action
## @ace_name("Draw Text")
## @ace_display_template("Draw the text {message} at ({x}, {y})")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_text({message}, {x}, {y}, {size})")
func draw_text(message: String, x: float, y: float, size: float) -> void:
	CanvasSurface.for_node(host).draw_text(message, x, y, size)

## Draws a texture stretched into a box, from its centre, tinted by the style's colour.
## @ace_action
## @ace_name("Draw Texture")
## @ace_display_template("Draw {texture} at ({x}, {y}), {width} by {height}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_texture_in_rect({texture}, {x}, {y}, {width}, {height})")
func draw_texture_in_rect(texture: Texture2D, x: float, y: float, width: float, height: float) -> void:
	CanvasSurface.for_node(host).draw_texture_in_rect(texture, x, y, width, height)

## Draws a grid of rulings filling a box, from its centre - the level editor's floor, the
## debug overlay's ruler, the graph paper behind a plan.
## @ace_action
## @ace_name("Draw Grid")
## @ace_display_template("Draw a grid at ({x}, {y}), {width} by {height}, cells of {cell_size}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_grid({x}, {y}, {width}, {height}, {cell_size})")
func draw_grid(x: float, y: float, width: float, height: float, cell_size: float) -> void:
	CanvasSurface.for_node(host).draw_grid(x, y, width, height, cell_size)

## Draws a cross - the marker on a spot, the "no" over a placement that will not do.
## @ace_action
## @ace_name("Draw Cross")
## @ace_display_template("Draw a cross at ({x}, {y}), arms of {arm_length}")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_cross({x}, {y}, {arm_length}, {angle_degrees})")
func draw_cross(x: float, y: float, arm_length: float, angle_degrees: float) -> void:
	CanvasSurface.for_node(host).draw_cross(x, y, arm_length, angle_degrees)

## Draws an arrow from one point to another, its head sized in pixels - a force, a facing, a
## route, a debug vector.
## @ace_action
## @ace_name("Draw Arrow")
## @ace_display_template("Draw an arrow from ({from_x}, {from_y}) to ({to_x}, {to_y})")
## @ace_icon("res://eventsheet_addons/drawing_canvas/icon.svg")
## @ace_codegen_template("$DrawingCanvas.draw_arrow({from_x}, {from_y}, {to_x}, {to_y}, {head_size})")
func draw_arrow(from_x: float, from_y: float, to_x: float, to_y: float, head_size: float) -> void:
	CanvasSurface.for_node(host).draw_arrow(from_x, from_y, to_x, to_y, head_size)

# Drawing Canvas behavior (event-sheet parity): a texture your sheet draws onto with actions - lines, circles, rings, rects, cones, texture stamps, textured ribbons, and a raycast LINE OF SIGHT fan. Persistent mode keeps strokes until Clear Canvas (paint, blood splats, skid marks); Auto Clear redraws every frame (attack telegraphs, vision cones). Canvas Texture exposes the live texture for materials, UI, or a 3D Decal. The drawing plumbing lives in the shared CanvasSurface runtime; this pack is a thin event sheet - extend it by editing it.
