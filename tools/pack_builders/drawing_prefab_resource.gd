# Pack builder - drawing_prefab_resource (a data-driven Custom Resource; run via build_sample_behaviors.gd).
@tool

const Lib := preload("res://tools/pack_builders/_lib.gd")


## DrawingPrefabResource: a reusable drawing as a .tres asset - an ORDERED list of shape
## steps (circle, ring, rect, line, cone, stamp) edited as a grid in the Inspector. The
## Drawing Canvas's Draw Prefab action replays the steps in order at any position, scale,
## and rotation - author a target marker or explosion scorch once, stamp it everywhere.
static func build() -> bool:
	var sheet: EventSheetResource = EventSheetResource.new()
	sheet.host_class = "Resource"
	sheet.custom_class_name = "DrawingPrefabResource"
	sheet.class_description = "A reusable drawing: an ordered grid of shape steps replayed by the Drawing Canvas's Draw Prefab action at any position, scale, and rotation. Fill the steps grid in the Inspector and save as a .tres."
	sheet.variables = {
		"prefab_name": {"type": "String", "default": "marker", "exported": true,
			"attributes": {"tooltip": "A label for your own reference (the canvas does not read it)."}},
		"steps": {"type": "Array", "default": [], "exported": true,
			"attributes": {"tooltip": "The shapes, drawn top to bottom. kind: circle / ring / rect / line / cone / stamp. x,y = the step's offset from the prefab origin. p1,p2,p3 by kind - circle: p1 radius; ring: p1 radius, p2 width; rect: p1 width, p2 height; line: p1,p2 = end offset, p3 width; cone: p1 facing deg, p2 fov deg, p3 radius; stamp: p1 scale, p2 rotation deg (texture = the image path). color: a name or hex like #ff8800.",
				"drawer": "table", "table_columns": [{"name": "kind", "type": "enum", "options": ["circle", "ring", "rect", "line", "cone", "stamp"]}, {"name": "x", "type": "float"}, {"name": "y", "type": "float"}, {"name": "p1", "type": "float"}, {"name": "p2", "type": "float"}, {"name": "p3", "type": "float"}, {"name": "color", "type": "color"}, {"name": "texture", "type": "String"}]}}
	}
	return Lib.save_pack(sheet, "res://eventsheet_addons/drawing_prefab_resource/drawing_prefab_resource")
