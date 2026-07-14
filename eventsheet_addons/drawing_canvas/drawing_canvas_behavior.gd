## @ace_tags(drawing, visual)
## @ace_category("Drawing Canvas")
@icon("res://eventsheet_addons/behavior.svg")
class_name DrawingCanvas
extends Node

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
## On: the canvas clears itself every frame - re-issue draw verbs each tick (vision
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
func canvas_texture() -> Texture2D:
	return CanvasSurface.for_node(host).texture()

func _ready() -> void:
	CanvasSurface.for_node(host).configure(canvas_width, canvas_height, auto_clear, coordinates, display_on_host)

## @ace_condition
## @ace_name("Is Auto Clear")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.is_auto_clear()")
func is_auto_clear() -> bool:
	return CanvasSurface.for_node(host).auto_clear

## @ace_action
## @ace_name("Clear Canvas")
## @ace_description("Wipes the canvas. In persistent mode the wipe happens on the next frame and the canvas keeps strokes again afterwards.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.clear_canvas()")
func clear_canvas() -> void:
	CanvasSurface.for_node(host).clear()

## @ace_action
## @ace_name("Set Auto Clear")
## @ace_description("On: the canvas wipes itself every frame (re-issue draws each tick - vision cones, telegraphs). Off: strokes stay until Clear Canvas (paint, splats, skid marks).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.set_auto_clear({enabled})")
func set_auto_clear(enabled: bool) -> void:
	CanvasSurface.for_node(host).set_auto_clear(enabled)

## @ace_action
## @ace_name("Set Canvas Visible")
## @ace_description("Shows or hides the canvas display on the host.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.set_canvas_visible({visible_now})")
func set_canvas_visible(visible_now: bool) -> void:
	CanvasSurface.for_node(host).set_display_visible(visible_now)

## @ace_action
## @ace_name("Draw Line")
## @ace_description("Draws a line segment - attack direction indicators, lasers, aim guides.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_line({from_x}, {from_y}, {to_x}, {to_y}, {width}, {color})")
func draw_canvas_line(from_x: float, from_y: float, to_x: float, to_y: float, width: float, color: Color) -> void:
	CanvasSurface.for_node(host).line(from_x, from_y, to_x, to_y, width, color)

## @ace_action
## @ace_name("Draw Circle")
## @ace_description("Draws a filled circle - the classic soft blob shadow under a character.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_circle({x}, {y}, {radius}, {color})")
func draw_canvas_circle(x: float, y: float, radius: float, color: Color) -> void:
	CanvasSurface.for_node(host).circle(x, y, radius, color)

## @ace_action
## @ace_name("Draw Ring")
## @ace_description("Draws a circle outline - selection rings, blast-radius previews.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_ring({x}, {y}, {radius}, {width}, {color})")
func draw_canvas_ring(x: float, y: float, radius: float, width: float, color: Color) -> void:
	CanvasSurface.for_node(host).ring(x, y, radius, width, color)

## @ace_action
## @ace_name("Draw Rect")
## @ace_description("Draws a filled rectangle (x/y = top-left corner).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_rect({x}, {y}, {width}, {height}, {color})")
func draw_canvas_rect(x: float, y: float, width: float, height: float, color: Color) -> void:
	CanvasSurface.for_node(host).rect(x, y, width, height, color)

## @ace_action
## @ace_name("Draw Cone")
## @ace_description("Draws a filled wedge - the attack-telegraph cone (pair with Auto Clear so it follows the attacker every frame).")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_cone({x}, {y}, {facing_deg}, {fov_deg}, {radius}, {color})")
func draw_canvas_cone(x: float, y: float, facing_deg: float, fov_deg: float, radius: float, color: Color) -> void:
	CanvasSurface.for_node(host).cone(x, y, facing_deg, fov_deg, radius, color)

## @ace_action
## @ace_name("Draw Stamp")
## @ace_description("Stamps a texture onto the canvas - bullet holes, footprints, splats. In persistent mode stamps pile up like decals.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.draw_canvas_stamp({texture}, {x}, {y}, {scale_factor}, {rotation_deg})")
func draw_canvas_stamp(texture: Texture2D, x: float, y: float, scale_factor: float, rotation_deg: float) -> void:
	CanvasSurface.for_node(host).stamp(texture, x, y, scale_factor, rotation_deg)

## @ace_action
## @ace_name("Draw Line Of Sight")
## @ace_description("Draws a character's LINE OF SIGHT as a filled fan: rays cast against the collision mask stop at walls, so the shape hugs the level exactly. Re-issue each tick with Auto Clear on for a live vision cone. Origin and range are WORLD coordinates.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.draw_line_of_sight({origin_x}, {origin_y}, {facing_deg}, {fov_deg}, {max_range}, {collision_mask}, {color})")
func draw_line_of_sight(origin_x: float, origin_y: float, facing_deg: float, fov_deg: float, max_range: float, collision_mask: int, color: Color) -> void:
	CanvasSurface.for_node(host).line_of_sight(origin_x, origin_y, facing_deg, fov_deg, max_range, collision_mask, color)

## @ace_action
## @ace_name("Draw Prefab")
## @ace_description("Replays a DrawingPrefabResource's steps IN ORDER at a position, scaled and rotated - author a target marker or scorch formation once as a .tres, stamp it everywhere.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.draw_prefab({prefab}, {x}, {y}, {scale_factor}, {rotation_deg})")
func draw_prefab(prefab: Resource, x: float, y: float, scale_factor: float, rotation_deg: float) -> void:
	CanvasSurface.for_node(host).prefab(prefab, x, y, scale_factor, rotation_deg)

## @ace_action
## @ace_name("Start Ribbon")
## @ace_description("Starts a textured ribbon trailing a node - sword swooshes, skid marks, comet tails. The ribbon follows for Point Count frames of history; Set Ribbon Texture skins it.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.start_ribbon({follow}, {point_count}, {width}, {color})")
func start_ribbon(follow: Node, point_count: int, width: float, color: Color) -> void:
	CanvasSurface.for_node(host).start_ribbon(follow, point_count, width, color)

## @ace_action
## @ace_name("Set Ribbon Texture")
## @ace_description("Skins a running ribbon with a texture, stretched along its length.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.set_ribbon_texture({follow}, {texture})")
func set_ribbon_texture(follow: Node, texture: Texture2D) -> void:
	CanvasSurface.for_node(host).set_ribbon_texture(follow, texture)

## @ace_action
## @ace_name("Stop Ribbon")
## @ace_description("Ends the ribbon trailing a node.")
## @ace_icon("res://eventsheet_addons/behavior.svg")
## @ace_codegen_template("$DrawingCanvas.stop_ribbon({follow})")
func stop_ribbon(follow: Node) -> void:
	CanvasSurface.for_node(host).stop_ribbon(follow)

# Drawing Canvas behavior (event-sheet parity): a texture your sheet draws onto with verbs - lines, circles, rings, rects, cones, texture stamps, textured ribbons, and a raycast LINE OF SIGHT fan. Persistent mode keeps strokes until Clear Canvas (paint, blood splats, skid marks); Auto Clear redraws every frame (attack telegraphs, vision cones). Canvas Texture exposes the live texture for materials, UI, or a 3D Decal. The drawing plumbing lives in the shared CanvasSurface runtime; this pack is a thin event sheet - extend it by editing it.
