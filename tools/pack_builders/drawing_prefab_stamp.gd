# Pack builder - drawing_prefab_stamp (a @tool Node2D that draws a DrawingPrefabResource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## DrawingPrefabStamp: drop this node into a 2D scene, assign a DrawingPrefabResource, and it draws
## the composed formation right in the editor viewport (and in game) - a placeable, previewable stamp.
## It is the dedicated "viewport gizmo" for prefabs: what you see in the editor is what Draw Prefab
## paints at runtime. Drawing needs a _draw() render pass, which the ACE vocabulary cannot express, so
## the render routine is a single raw block (shared statically with the DrawingCanvas preview gizmo).
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.tool_mode = true  # so _draw runs in the editor, not just at runtime
	sheet.host_class = "Node2D"
	sheet.custom_class_name = "DrawingPrefabStamp"
	sheet.addon_category = "Drawing Canvas"
	sheet.addon_tags = PackedStringArray(["drawing", "visual"])
	sheet.class_description = "Draws a DrawingPrefabResource in the 2D viewport (editor and game) - a placeable, previewable stamp of a prefab formation."
	var block: RawCodeRow = RawCodeRow.new()
	block.code = "\n".join(PackedStringArray([
		"## The formation to draw. Fill its steps grid in the Inspector - a live preview appears here and on the node.",
		"@export var prefab: DrawingPrefabResource = null:",
		"\tset(value):",
		"\t\tif prefab != null and prefab.changed.is_connected(queue_redraw):",
		"\t\t\tprefab.changed.disconnect(queue_redraw)",
		"\t\tprefab = value",
		"\t\tif prefab != null and not prefab.changed.is_connected(queue_redraw):",
		"\t\t\tprefab.changed.connect(queue_redraw)",
		"\t\tqueue_redraw()",
		"## Uniform scale applied to the whole formation.",
		"@export var prefab_scale: float = 1.0:",
		"\tset(value):",
		"\t\tprefab_scale = value",
		"\t\tqueue_redraw()",
		"## Rotation of the whole formation, in degrees.",
		"@export var prefab_rotation: float = 0.0:",
		"\tset(value):",
		"\t\tprefab_rotation = value",
		"\t\tqueue_redraw()",
		"",
		"func _draw() -> void:",
		"\tdraw_prefab_steps(self, prefab, Vector2.ZERO, prefab_scale, prefab_rotation)",
		"",
		"## Draws a DrawingPrefabResource's ordered steps onto any CanvasItem at an origin, scaled and",
		"## rotated as one - the shared vector renderer for the stamp node and the DrawingCanvas preview",
		"## gizmo. Sets the canvas transform once so every step draws in prefab-local space.",
		"## @ace_hidden",
		"static func draw_prefab_steps(canvas: CanvasItem, prefab_res: Resource, origin: Vector2, scale_by: float, rotation_deg: float) -> void:",
		"\tif prefab_res == null:",
		"\t\treturn",
		"\tvar steps: Variant = prefab_res.get(\"steps\")",
		"\tif not (steps is Array):",
		"\t\treturn",
		"\tcanvas.draw_set_transform(origin, deg_to_rad(rotation_deg), Vector2.ONE * maxf(scale_by, 0.001))",
		"\tfor step: Variant in steps:",
		"\t\tif not (step is Dictionary):",
		"\t\t\tcontinue",
		"\t\tvar entry: Dictionary = step",
		"\t\tvar at: Vector2 = Vector2(float(entry.get(\"x\", 0.0)), float(entry.get(\"y\", 0.0)))",
		"\t\tvar p1: float = float(entry.get(\"p1\", 0.0))",
		"\t\tvar p2: float = float(entry.get(\"p2\", 0.0))",
		"\t\tvar p3: float = float(entry.get(\"p3\", 0.0))",
		"\t\tvar tint: Color = Color.from_string(str(entry.get(\"color\", \"white\")), Color.WHITE)",
		"\t\tmatch str(entry.get(\"kind\", \"\")):",
		"\t\t\t\"circle\":",
		"\t\t\t\tcanvas.draw_circle(at, maxf(p1, 0.5), tint)",
		"\t\t\t\"ring\":",
		"\t\t\t\tcanvas.draw_arc(at, maxf(p1, 0.5), 0.0, TAU, 48, tint, maxf(p2, 1.0))",
		"\t\t\t\"rect\":",
		"\t\t\t\tcanvas.draw_rect(Rect2(at, Vector2(p1, p2)), tint)",
		"\t\t\t\"line\":",
		"\t\t\t\tcanvas.draw_line(at, at + Vector2(p1, p2), tint, maxf(p3, 1.0))",
		"\t\t\t\"cone\":",
		"\t\t\t\tvar points: PackedVector2Array = PackedVector2Array([at])",
		"\t\t\t\tfor i: int in 25:",
		"\t\t\t\t\tvar angle: float = deg_to_rad(p1 - p2 * 0.5 + p2 * float(i) / 24.0)",
		"\t\t\t\t\tpoints.append(at + Vector2.from_angle(angle) * maxf(p3, 0.5))",
		"\t\t\t\tcanvas.draw_colored_polygon(points, tint)",
		"\t\t\t\"stamp\":",
		"\t\t\t\tvar texture_path: String = str(entry.get(\"texture\", \"\")).strip_edges()",
		"\t\t\t\tif not texture_path.is_empty() and ResourceLoader.exists(texture_path):",
		"\t\t\t\t\tvar texture: Texture2D = load(texture_path) as Texture2D",
		"\t\t\t\t\tif texture != null:",
		"\t\t\t\t\t\tcanvas.draw_texture_rect(texture, Rect2(at - texture.get_size() * maxf(p1, 0.01) * 0.5, texture.get_size() * maxf(p1, 0.01)), false, tint)",
		"\tcanvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)"
	]))
	sheet.events.append(block)
	return Lib.save_pack(sheet, "res://eventsheet_addons/drawing_prefab_stamp/drawing_prefab_stamp")
