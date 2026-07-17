# Pack builder - drawing_canvas (one pack per file; run via tools/build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## DrawingCanvas: an event-sheet-parity drawing surface - a texture the sheet draws onto with verbs
## (lines, circles, cones, stamps, ribbons, line-of-sight fans). All the engine plumbing (the offscreen
## SubViewport, the command queue, coordinate mapping, the self-updating ribbons) now lives in the shared
## CanvasSurface runtime pack, so THIS behaviour is thin: each verb is a one-line call to the surface, and
## the per-frame ribbon loop is gone. Two modes: PERSISTENT (strokes accumulate until Clear Canvas) and
## AUTO-CLEAR (redrawn every frame). The live texture is an expression, so the same canvas feeds a
## Sprite2D, a TextureRect, a shader, or a 3D Decal.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.behavior_mode = true
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "DrawingCanvas"
	sheet.class_description = "A texture your event sheet draws onto with verbs: lines, circles, rings, rects, cones, stamps, textured ribbons, and a raycast line-of-sight fan. Strokes can persist until cleared or auto-clear every frame, and the live texture is an expression you can feed to a TextureRect, shader, particle, or 3D Decal."
	sheet.addon_category = "Drawing Canvas"
	sheet.addon_tags = PackedStringArray(["drawing", "visual"])
	var about: CommentRow = CommentRow.new()
	about.text = "Drawing Canvas behavior (event-sheet parity): a texture your sheet draws onto with verbs - lines, circles, rings, rects, cones, texture stamps, textured ribbons, and a raycast LINE OF SIGHT fan. Persistent mode keeps strokes until Clear Canvas (paint, blood splats, skid marks); Auto Clear redraws every frame (attack telegraphs, vision cones). Canvas Texture exposes the live texture for materials, UI, or a 3D Decal. The drawing plumbing lives in the shared CanvasSurface runtime; this pack is a thin event sheet - extend it by editing it."
	sheet.events.append(about)

	# Designer knobs + the one hidden helper that fetches this host's shared drawing surface. All the
	# heavy plumbing moved to CanvasSurface, so what remains here is configuration + thin verbs.
	var knobs: RawCodeRow = RawCodeRow.new()
	knobs.code = "\n".join(PackedStringArray([
		"# --- Designer knobs (tune in the Inspector) ---",
		"## Canvas texture width in pixels.",
		"@export var canvas_width: int = 512",
		"## Canvas texture height in pixels.",
		"@export var canvas_height: int = 512",
		"## On: the canvas clears itself every frame - re-issue draw verbs each tick (vision",
		"## cones, telegraphs). Off: strokes accumulate until Clear Canvas (paint, splats).",
		"@export var auto_clear: bool = false",
		"## How draw coordinates are read: world = scene positions (the canvas is centered on",
		"## the host and follows it); canvas = raw pixels on the texture (0,0 = top-left).",
		"@export_enum(\"world\", \"canvas\") var coordinates: String = \"world\"",
		"## Show the canvas on the host (a centered Sprite2D child). Off: the canvas renders",
		"## offscreen and you place Canvas Texture wherever you want it.",
		"@export var display_on_host: bool = true",
		"",
		"## A prefab to preview in the 2D EDITOR viewport, drawn at this node so you can position a",
		"## formation before wiring Draw Prefab. Design aid only - the running game never draws it.",
		"@export_group(\"Editor Preview\")",
		"@export var preview_prefab: DrawingPrefabResource = null",
		"## Scale of the editor preview.",
		"@export var preview_scale: float = 1.0",
		"## Rotation of the editor preview, in degrees.",
		"@export var preview_rotation: float = 0.0",
	]))
	sheet.events.append(knobs)

	# On Ready: hand the designer knobs to the surface once.
	var on_ready: EventRow = EventRow.new()
	on_ready.trigger_provider_id = "Core"
	on_ready.trigger_id = "OnReady"
	var ready_body: RawCodeRow = RawCodeRow.new()
	ready_body.code = "CanvasSurface.for_node(host).configure(canvas_width, canvas_height, auto_clear, coordinates, display_on_host)"
	on_ready.actions.append(ready_body)
	sheet.events.append(on_ready)

	# ── Drawing verbs: each is a one-line call to the shared surface (ace_ids unchanged). ──
	var verbs: RawCodeRow = RawCodeRow.new()
	verbs.code = "\n".join(PackedStringArray([
		"## The canvas's LIVE texture - assign it to a TextureRect, a material, a particle, or a",
		"## 3D Decal (the Decal Painter pack accepts it directly). Updates as the canvas draws.",
		"## @ace_expression",
		"## @ace_name(\"Canvas Texture\")",
		"## @ace_display_template(\"The live canvas texture\")",
		"func canvas_texture() -> Texture2D:",
		"\treturn CanvasSurface.for_node(host).texture()",
		"",
		"## @ace_condition",
		"## @ace_name(\"Is Auto Clear\")",
		"## @ace_display_template(\"Canvas auto-clears each frame\")",
		"func is_auto_clear() -> bool:",
		"\treturn CanvasSurface.for_node(host).auto_clear",
		"",
		"## Wipes the canvas. In persistent mode the wipe happens on the next frame and the",
		"## canvas keeps strokes again afterwards.",
		"## @ace_action",
		"## @ace_name(\"Clear Canvas\")",
		"## @ace_display_template(\"Clear the canvas\")",
		"func clear_canvas() -> void:",
		"\tCanvasSurface.for_node(host).clear()",
		"",
		"## On: the canvas wipes itself every frame (re-issue draws each tick - vision cones,",
		"## telegraphs). Off: strokes stay until Clear Canvas (paint, splats, skid marks).",
		"## @ace_action",
		"## @ace_name(\"Set Auto Clear\")",
		"## @ace_display_template(\"Set auto clear to {enabled}\")",
		"func set_auto_clear(enabled: bool) -> void:",
		"\tCanvasSurface.for_node(host).set_auto_clear(enabled)",
		"",
		"## Shows or hides the canvas display on the host.",
		"## @ace_action",
		"## @ace_name(\"Set Canvas Visible\")",
		"## @ace_display_template(\"Set the canvas visible to {visible_now}\")",
		"func set_canvas_visible(visible_now: bool) -> void:",
		"\tCanvasSurface.for_node(host).set_display_visible(visible_now)",
		"",
		"## Draws a line segment - attack direction indicators, lasers, aim guides.",
		"## @ace_action",
		"## @ace_name(\"Draw Line\")",
		"## @ace_display_template(\"Draw a line from ({from_x}, {from_y}) to ({to_x}, {to_y})\")",
		"func draw_canvas_line(from_x: float, from_y: float, to_x: float, to_y: float, width: float, color: Color) -> void:",
		"\tCanvasSurface.for_node(host).line(from_x, from_y, to_x, to_y, width, color)",
		"",
		"## Draws a filled circle - the classic soft blob shadow under a character.",
		"## @ace_action",
		"## @ace_name(\"Draw Circle\")",
		"## @ace_display_template(\"Draw a circle at ({x}, {y}), radius {radius}\")",
		"func draw_canvas_circle(x: float, y: float, radius: float, color: Color) -> void:",
		"\tCanvasSurface.for_node(host).circle(x, y, radius, color)",
		"",
		"## Draws a circle outline - selection rings, blast-radius previews.",
		"## @ace_action",
		"## @ace_name(\"Draw Ring\")",
		"## @ace_display_template(\"Draw a ring at ({x}, {y}), radius {radius}\")",
		"func draw_canvas_ring(x: float, y: float, radius: float, width: float, color: Color) -> void:",
		"\tCanvasSurface.for_node(host).ring(x, y, radius, width, color)",
		"",
		"## Draws a filled rectangle (x/y = top-left corner).",
		"## @ace_action",
		"## @ace_name(\"Draw Rect\")",
		"## @ace_display_template(\"Draw a rect at ({x}, {y}), {width} by {height}\")",
		"func draw_canvas_rect(x: float, y: float, width: float, height: float, color: Color) -> void:",
		"\tCanvasSurface.for_node(host).rect(x, y, width, height, color)",
		"",
		"## Draws a DASHED line segment - aim guides, tethers, boundary previews. dash_length and",
		"## gap_length set the on/off rhythm.",
		"## @ace_action",
		"## @ace_name(\"Draw Dashed Line\")",
		"## @ace_display_template(\"Draw a dashed line from ({from_x}, {from_y}) to ({to_x}, {to_y})\")",
		"func draw_canvas_dashed_line(from_x: float, from_y: float, to_x: float, to_y: float, dash_length: float, gap_length: float, width: float, color: Color) -> void:",
		"\tCanvasSurface.for_node(host).dashed_line(from_x, from_y, to_x, to_y, dash_length, gap_length, width, color)",
		"",
		"## Draws a DASHED circle outline - range rings, dashed selection markers. The same dash",
		"## primitive as Draw Dashed Line, wrapped around the circle.",
		"## @ace_action",
		"## @ace_name(\"Draw Dashed Ring\")",
		"## @ace_display_template(\"Draw a dashed ring at ({x}, {y}), radius {radius}\")",
		"func draw_canvas_dashed_ring(x: float, y: float, radius: float, dash_length: float, gap_length: float, width: float, color: Color) -> void:",
		"\tCanvasSurface.for_node(host).dashed_ring(x, y, radius, dash_length, gap_length, width, color)",
		"",
		"## Draws a DASHED rectangle outline - selection boxes, build-placement previews, zone",
		"## markers. The dash rhythm carries continuously around all four sides.",
		"## @ace_action",
		"## @ace_name(\"Draw Dashed Rect\")",
		"## @ace_display_template(\"Draw a dashed rect at ({x}, {y}), {width} by {height}\")",
		"func draw_canvas_dashed_rect(x: float, y: float, width: float, height: float, dash_length: float, gap_length: float, line_width: float, color: Color) -> void:",
		"\tCanvasSurface.for_node(host).dashed_rect(x, y, width, height, dash_length, gap_length, line_width, color)",
		"",
		"## Draws a filled wedge - the attack-telegraph cone (pair with Auto Clear so it follows",
		"## the attacker every frame).",
		"## @ace_action",
		"## @ace_name(\"Draw Cone\")",
		"## @ace_display_template(\"Draw a cone at ({x}, {y}) facing {facing_deg} deg, fov {fov_deg} deg\")",
		"func draw_canvas_cone(x: float, y: float, facing_deg: float, fov_deg: float, radius: float, color: Color) -> void:",
		"\tCanvasSurface.for_node(host).cone(x, y, facing_deg, fov_deg, radius, color)",
		"",
		"## Stamps a texture onto the canvas - bullet holes, footprints, splats. In persistent",
		"## mode stamps pile up like decals.",
		"## @ace_action",
		"## @ace_name(\"Draw Stamp\")",
		"## @ace_display_template(\"Stamp {texture} at ({x}, {y})\")",
		"func draw_canvas_stamp(texture: Texture2D, x: float, y: float, scale_factor: float, rotation_deg: float) -> void:",
		"\tCanvasSurface.for_node(host).stamp(texture, x, y, scale_factor, rotation_deg)",
		"",
		"## Draws a character's LINE OF SIGHT as a filled fan: rays cast against the collision",
		"## mask stop at walls, so the shape hugs the level exactly. Re-issue each tick with",
		"## Auto Clear on for a live vision cone. Origin and range are WORLD coordinates.",
		"## @ace_action",
		"## @ace_name(\"Draw Line Of Sight\")",
		"## @ace_display_template(\"Draw line of sight from ({origin_x}, {origin_y}) facing {facing_deg} deg, range {max_range}\")",
		"func draw_line_of_sight(origin_x: float, origin_y: float, facing_deg: float, fov_deg: float, max_range: float, collision_mask: int, color: Color) -> void:",
		"\tCanvasSurface.for_node(host).line_of_sight(origin_x, origin_y, facing_deg, fov_deg, max_range, collision_mask, color)",
		"",
		"## Replays a DrawingPrefabResource's steps IN ORDER at a position, scaled and rotated -",
		"## author a target marker or scorch formation once as a .tres, stamp it everywhere.",
		"## @ace_action",
		"## @ace_name(\"Draw Prefab\")",
		"## @ace_display_template(\"Stamp a prefab at ({x}, {y})\")",
		"func draw_prefab(prefab: Resource, x: float, y: float, scale_factor: float, rotation_deg: float) -> void:",
		"\tCanvasSurface.for_node(host).prefab(prefab, x, y, scale_factor, rotation_deg)",
		"",
		"## Starts a textured ribbon trailing a node - sword swooshes, skid marks, comet tails.",
		"## The ribbon follows for Point Count frames of history; Set Ribbon Texture skins it.",
		"## @ace_action",
		"## @ace_name(\"Start Ribbon\")",
		"## @ace_display_template(\"Start a ribbon trailing {follow}\")",
		"func start_ribbon(follow: Node, point_count: int, width: float, color: Color) -> void:",
		"\tCanvasSurface.for_node(host).start_ribbon(follow, point_count, width, color)",
		"",
		"## Skins a running ribbon with a texture, stretched along its length.",
		"## @ace_action",
		"## @ace_name(\"Set Ribbon Texture\")",
		"## @ace_display_template(\"Skin {follow}'s ribbon with {texture}\")",
		"func set_ribbon_texture(follow: Node, texture: Texture2D) -> void:",
		"\tCanvasSurface.for_node(host).set_ribbon_texture(follow, texture)",
		"",
		"## Ends the ribbon trailing a node.",
		"## @ace_action",
		"## @ace_name(\"Stop Ribbon\")",
		"## @ace_display_template(\"Stop the ribbon trailing {follow}\")",
		"func stop_ribbon(follow: Node) -> void:",
		"\tCanvasSurface.for_node(host).stop_ribbon(follow)"
	]))
	sheet.events.append(verbs)

	return Lib.save_pack(sheet, "res://eventsheet_addons/drawing_canvas/drawing_canvas_behavior")
