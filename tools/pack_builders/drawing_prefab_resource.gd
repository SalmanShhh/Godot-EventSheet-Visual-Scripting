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
	# Runtime compiled-steps cache: replaying a prefab across 1000+ stamps must not re-parse strings
	# (Color.from_string, dict.get defaults, stamp texture loads) every draw. compiled_steps() parses the
	# steps ONCE into typed draw entries and caches them, invalidated when the resource changes. Both
	# renderers (DrawingPrefabStamp.draw_prefab_steps and CanvasSurface.prefab) read this on the main
	# thread; the off-thread thumbnail rasterizer keeps reading the raw steps and never touches this.
	var cache: RawCodeRow = RawCodeRow.new()
	cache.code = "\n".join(PackedStringArray([
		"## The steps pre-parsed into typed draw entries, cached until the resource changes - so replaying",
		"## this prefab across many stamps does not re-parse colors/kinds every draw. Runtime only (not",
		"## exported, so never serialized). Read ONLY on the main thread (the draw paths); the off-thread",
		"## thumbnail rasterizer reads the raw steps instead and never calls this.",
		"var _compiled: Array = []",
		"var _compiled_valid: bool = false",
		"var _compiled_size: int = -1",
		"",
		"## Returns steps pre-parsed to typed entries {kind, x, y, p1, p2, p3, color: Color, tex: Texture2D},",
		"## building and caching on first call and after any change. The size guard also rebuilds when steps",
		"## are appended or removed at runtime; an in-place value edit needs emit_changed() (the Inspector",
		"## does this automatically on every cell edit).",
		"func compiled_steps() -> Array:",
		"\tif not changed.is_connected(_invalidate_compiled):",
		"\t\tchanged.connect(_invalidate_compiled)",
		"\tif _compiled_valid and _compiled_size == steps.size():",
		"\t\treturn _compiled",
		"\t_compiled = compile_steps(steps)",
		"\t_compiled_size = steps.size()",
		"\t_compiled_valid = true",
		"\treturn _compiled",
		"",
		"func _invalidate_compiled() -> void:",
		"\t_compiled_valid = false",
		"\t_compiled = []",
		"",
		"## Parses raw steps (Dictionaries of strings) into typed entries - colors parsed once, stamp",
		"## textures loaded once (main thread). The renderers use the SAME shape for their generic-Resource",
		"## fallback, so a cached draw and an uncached draw are identical.",
		"static func compile_steps(raw: Array) -> Array:",
		"\tvar out: Array = []",
		"\tfor step: Variant in raw:",
		"\t\tif not (step is Dictionary):",
		"\t\t\tcontinue",
		"\t\tvar entry: Dictionary = step",
		"\t\tvar kind: String = str(entry.get(\"kind\", \"\"))",
		"\t\tvar tex: Texture2D = null",
		"\t\tif kind == \"stamp\":",
		"\t\t\tvar texture_path: String = str(entry.get(\"texture\", \"\")).strip_edges()",
		"\t\t\tif not texture_path.is_empty() and ResourceLoader.exists(texture_path):",
		"\t\t\t\ttex = load(texture_path) as Texture2D",
		"\t\tout.append({",
		"\t\t\t\"kind\": kind,",
		"\t\t\t\"x\": float(entry.get(\"x\", 0.0)),",
		"\t\t\t\"y\": float(entry.get(\"y\", 0.0)),",
		"\t\t\t\"p1\": float(entry.get(\"p1\", 0.0)),",
		"\t\t\t\"p2\": float(entry.get(\"p2\", 0.0)),",
		"\t\t\t\"p3\": float(entry.get(\"p3\", 0.0)),",
		"\t\t\t\"color\": Color.from_string(str(entry.get(\"color\", \"white\")), Color.WHITE),",
		"\t\t\t\"tex\": tex,",
		"\t\t})",
		"\treturn out",
	]))
	sheet.events.append(cache)
	return Lib.save_pack(sheet, "res://eventsheet_addons/drawing_prefab_resource/drawing_prefab_resource")
