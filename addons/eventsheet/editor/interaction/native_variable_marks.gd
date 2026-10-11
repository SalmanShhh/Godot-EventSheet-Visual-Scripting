@tool
extends RefCounted
# Godot EventSheets - the DRAWN look of a variable row: the type word in its colour, the value as the
# Inspector shows it, the doc-comment note in italics, and the small badge tiles at the row's right.
#
# A variable row keeps every word it had. What this file decides is how those words are PAINTED:
#   - the type word wears one of nine colour families (number, text, true/false, vector, colour,
#     object, enum, collection, class) in a monospaced face, the way a type reads in code;
#   - the value reads as the Inspector would draw it: a tick box for a bool, X / Y (/ Z) fields with
#     axis-coloured letters for a vector, a framed chip with a resource mark for a scene, a resource
#     or a node path. A colour keeps the swatch the row already draws;
#   - the variable's `##` doc comment, already the row's last muted note, leans into italics;
#   - the badges say how the Inspector treats the variable: shown in it, kept in a range, given a
#     tooltip, kept by the Save System. Each is an icon on a small tile; none is a word.
#
# NOTHING HERE IS A WIDGET. Every mark is painted on the virtualized canvas, the way the colour
# swatch and the old Inspector mark were. The row builder stamps FACTS onto spans that already exist
# (which family a type is, which glyph a value takes, which badges a variable earns), so no span is
# added and no reading moves; the measuring side and the painting side then ask this file the same
# questions, which is what keeps the room a glyph reserves equal to the room it draws in.
#
# Static and stateless apart from small caches (fonts built once, a sheet's save keys read once per
# change of its file), so the builder, the renderer, the tooltip and the suite share one answer.

## The colour families a type word can wear, one per token on the event style.
const FAMILY_NUMBER := "number"
const FAMILY_TEXT := "text"
const FAMILY_BOOL := "bool"
const FAMILY_VECTOR := "vector"
const FAMILY_COLOR := "color"
const FAMILY_OBJECT := "object"
const FAMILY_ENUM := "enum"
const FAMILY_COLLECTION := "collection"
const FAMILY_CLASS := "class"

## The value glyphs. A colour's swatch is the row's own trailing one, except on an Inspector-style
## row (inspector_variable_rows), where the swatch leads and the value reads as its #RRGGBB hex.
const GLYPH_BOOL := "bool"
const GLYPH_VECTOR := "vector"
const GLYPH_RESOURCE := "resource"
const GLYPH_COLOR := "color"

## The leading colour swatch of an Inspector-style row, and the gap between it and the hex.
const SWATCH_WIDTH := 34.0
const SWATCH_HEIGHT := 14.0
const SWATCH_GAP := 6.0

## The prefix the compiler's own bookkeeping members start with (the Every X Seconds clock, a spawn's
## temporary), which an Inspector-style sheet leaves out of its variable rows.
const COMPILER_VARIABLE_PREFIX := "__"

## The badges, in the order they stand at the row's right.
const BADGE_INSPECTOR := "inspector"
const BADGE_RANGE := "range"
const BADGE_TOOLTIP := "tooltip"
const BADGE_SAVED := "saved"
const BADGE_ORDER: PackedStringArray = [BADGE_INSPECTOR, BADGE_RANGE, BADGE_TOOLTIP, BADGE_SAVED]

## A badge tile and the icon inside it, and the room between two tiles and before the first.
const TILE_SIZE := 18.0
const TILE_ICON := 12.0
const TILE_GAP := 2.0
const TILE_LEAD := 8.0

## The bool tick box and the gap between it and the word beside it.
const TICK_BOX := 13.0
const TICK_GAP := 6.0

## A vector's mini fields: inner padding, the gap between the axis letter and its number, the gap
## between two fields, and the field height.
const FIELD_PAD := 5.0
const FIELD_LETTER_GAP := 4.0
const FIELD_GAP := 4.0
const FIELD_HEIGHT := 18.0

## A resource chip: padding before the mark, the mark, the gap after it, and padding after the text.
const CHIP_PAD_LEFT := 5.0
const CHIP_ICON := 12.0
const CHIP_ICON_GAP := 5.0
const CHIP_PAD_RIGHT := 8.0

## The slant of the italic note, as the shear the font's outlines take. Shearing leaves the advances
## all but as they were, so the note is measured as before and only its letters lean.
const ITALIC_SHEAR := 0.2

## The axis letters' colours when no editor theme is there to ask (a headless run, a preview): the
## design's own pairs, for a dark sheet and a light one. In a running editor the Inspector's own
## property colours are used, so the letters match the X / Y / Z the Inspector draws.
const AXIS_COLORS_DARK: Array[Color] = [Color("#ff8a80"), Color("#9ccc65"), Color("#64b5f6")]
const AXIS_COLORS_LIGHT: Array[Color] = [Color("#b3261e"), Color("#2e7d32"), Color("#1565c0")]
const AXIS_LETTERS: PackedStringArray = ["X", "Y", "Z", "W"]

## The two inks a mark drawn ON a filled shape is chosen between - a tick on its box, a number on a
## selected gutter. Not a theme decision: the fill is the theme's, and the ink is whichever of these
## reads on it.
const CONTRAST_INK_ON_DARK := Color.WHITE
const CONTRAST_INK_ON_LIGHT := Color(0.08, 0.09, 0.11)
## The faint frame of a glyph, the same choice at a whisper: dark on a light fill, light on a dark.
const FRAME_INK_ON_LIGHT := Color(0.0, 0.0, 0.0, 0.45)
const FRAME_INK_ON_DARK := Color(1.0, 1.0, 1.0, 0.5)
## Under this luminance a fill takes the light ink.
const TICK_INK_LUMINANCE := 0.6

## The monospaced faces a type word asks the system for, in order; the sheet's own font backs them.
const MONO_FONT_NAMES: PackedStringArray = ["Cascadia Mono", "Consolas", "JetBrains Mono", "Menlo",
	"DejaVu Sans Mono", "monospace"]

## The Godot classes a resource chip is drawn for even though ClassDB is not asked: the value types
## that are always a file or a path.
const OBJECT_TYPES: PackedStringArray = ["PackedScene", "Resource", "NodePath", "Script", "Texture2D",
	"AudioStream", "Material", "Shader", "Mesh", "Font", "Theme"]

static var _mono_cache: Dictionary = {}
static var _italic_cache: Dictionary = {}
static var _saved_cache: Dictionary = {}
static var _box_cache: Dictionary = {}
static var _default_style: EventSheetEventStyle = null


## The colour family of a variable's type, or "" when nothing about it says. Read from the declared
## type first, then from the value for an untyped declaration (`var hp := 100` is a number).
## `enum_names` are the enums the sheet declares, so a variable typed by one reads as an enum rather
## than as a class.
static func type_family(type_name: String, default_value: Variant, expression_default: bool = false,
		enum_names: PackedStringArray = PackedStringArray()) -> String:
	var declared: String = type_name.strip_edges()
	if declared.is_empty() or declared == "Variant":
		return _inferred_family(default_value, expression_default)
	match declared:
		"int", "float":
			return FAMILY_NUMBER
		"String", "StringName":
			return FAMILY_TEXT
		"bool":
			return FAMILY_BOOL
		"Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i":
			return FAMILY_VECTOR
		"Color":
			return FAMILY_COLOR
		"Array", "Dictionary":
			return FAMILY_COLLECTION
	if declared.begins_with("Array[") or declared.begins_with("Dictionary[") \
			or (declared.begins_with("Packed") and declared.ends_with("Array")):
		return FAMILY_COLLECTION
	if OBJECT_TYPES.has(declared):
		return FAMILY_OBJECT
	var bare: String = declared.get_slice(".", declared.get_slice_count(".") - 1)
	if enum_names.has(bare):
		return FAMILY_ENUM
	if ClassDB.class_exists(declared):
		if ClassDB.is_parent_class(declared, "Node") or ClassDB.is_parent_class(declared, "Resource"):
			return FAMILY_OBJECT
		return FAMILY_CLASS
	# A dotted type (`Gate.State`) is another script's enum far more often than anything else.
	if declared.contains("."):
		return FAMILY_ENUM
	return FAMILY_CLASS


static func _inferred_family(default_value: Variant, expression_default: bool) -> String:
	if not expression_default:
		match typeof(default_value):
			TYPE_INT, TYPE_FLOAT:
				return FAMILY_NUMBER
			TYPE_STRING, TYPE_STRING_NAME:
				return FAMILY_TEXT
			TYPE_BOOL:
				return FAMILY_BOOL
			TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I:
				return FAMILY_VECTOR
			TYPE_COLOR:
				return FAMILY_COLOR
			TYPE_ARRAY, TYPE_DICTIONARY:
				return FAMILY_COLLECTION
			TYPE_NODE_PATH, TYPE_OBJECT:
				return FAMILY_OBJECT
		return ""
	var text: String = str(default_value).strip_edges()
	if text.is_empty():
		return ""
	if text == "true" or text == "false":
		return FAMILY_BOOL
	if text.begins_with("\"") or text.begins_with("'") or text.begins_with("&\""):
		return FAMILY_TEXT
	if text.begins_with("[") or text.begins_with("{"):
		return FAMILY_COLLECTION
	if text.is_valid_float():
		return FAMILY_NUMBER
	if text.begins_with("^\"") or text.begins_with("preload(") or text.begins_with("load("):
		return FAMILY_OBJECT
	if text.begins_with("Color"):
		return FAMILY_COLOR
	if text.begins_with("Vector"):
		return FAMILY_VECTOR
	return ""


## The theme colour a family is painted in, made readable on the `background` the row is filled
## with. Clear for no family.
static func family_color(event_style: EventSheetEventStyle, family: String, background: Color) -> Color:
	if event_style == null:
		return Color(0.0, 0.0, 0.0, 0.0)
	var stated: Color = Color(0.0, 0.0, 0.0, 0.0)
	match family:
		FAMILY_NUMBER:
			stated = event_style.type_number_color
		FAMILY_TEXT:
			stated = event_style.type_text_color
		FAMILY_BOOL:
			stated = event_style.type_bool_color
		FAMILY_VECTOR:
			stated = event_style.type_vector_color
		FAMILY_COLOR:
			stated = event_style.type_color_color
		FAMILY_OBJECT:
			stated = event_style.type_object_color
		FAMILY_ENUM:
			stated = event_style.type_enum_color
		FAMILY_COLLECTION:
			stated = event_style.type_collection_color
		FAMILY_CLASS:
			stated = event_style.type_class_color
	if stated.a <= 0.01:
		return stated
	return readable_ink(stated, background)


## `ink` kept readable on `background`. A pale colour on a light fill is darkened and a deep one on
## a dark fill is lightened, the hue kept either way - so a palette stated for one kind of sheet
## still reads on the other.
static func readable_ink(ink: Color, background: Color) -> Color:
	var light_fill: bool = background.get_luminance() >= 0.5
	var luminance: float = ink.get_luminance()
	if light_fill and luminance > 0.5:
		return ink.darkened(clampf((luminance - 0.3) / maxf(luminance, 0.01), 0.0, 0.75))
	if not light_fill and luminance < 0.35:
		return ink.lightened(0.55)
	return ink


## The faint ink a glyph's frame is drawn in on `background`: light on a dark fill, dark on a light.
static func frame_ink(background: Color) -> Color:
	return FRAME_INK_ON_LIGHT if background.get_luminance() >= 0.5 else FRAME_INK_ON_DARK


## The ink that reads on `fill`: the light one under `threshold` luminance, the dark one above it.
static func contrast_ink(fill: Color, threshold: float) -> Color:
	return CONTRAST_INK_ON_DARK if fill.get_luminance() < threshold else CONTRAST_INK_ON_LIGHT


## Which glyph a value takes, as {"glyph": String, "axes": PackedStringArray, "on": bool}; an empty
## glyph means the value stays plain text. `value_text` is the value as the row reads it.
static func value_glyph(family: String, value_text: String, default_value: Variant,
		expression_default: bool) -> Dictionary:
	var shown: String = value_text.strip_edges()
	match family:
		FAMILY_BOOL:
			if shown == "true" or shown == "false":
				return {"glyph": GLYPH_BOOL, "axes": PackedStringArray(), "on": shown == "true"}
		FAMILY_VECTOR:
			var axes: PackedStringArray = vector_axes(default_value, expression_default)
			if not axes.is_empty():
				return {"glyph": GLYPH_VECTOR, "axes": axes, "on": false}
		FAMILY_OBJECT:
			if not shown.is_empty() and shown not in ["null", "<null>", "\"\"", "^\"\"", "<Object#null>"]:
				return {"glyph": GLYPH_RESOURCE, "axes": PackedStringArray(), "on": false}
	return {"glyph": "", "axes": PackedStringArray(), "on": false}


## The components of a vector value as the Inspector prints them ("0", "-48"), or none when the
## value is not a vector the row can read without running anything: a real Vector, a literal
## constructor `Vector2(0, -48)`, or one of the named constants every reader knows.
static func vector_axes(default_value: Variant, expression_default: bool = false) -> PackedStringArray:
	var axes := PackedStringArray()
	match typeof(default_value):
		TYPE_VECTOR2, TYPE_VECTOR2I:
			for component: Variant in [default_value.x, default_value.y]:
				axes.append(_number_text(float(component)))
			return axes
		TYPE_VECTOR3, TYPE_VECTOR3I:
			for component: Variant in [default_value.x, default_value.y, default_value.z]:
				axes.append(_number_text(float(component)))
			return axes
		TYPE_VECTOR4, TYPE_VECTOR4I:
			for component: Variant in [default_value.x, default_value.y, default_value.z, default_value.w]:
				axes.append(_number_text(float(component)))
			return axes
	if not (default_value is String or default_value is StringName):
		return axes
	var text: String = str(default_value).strip_edges().replace(" ", "")
	var dimensions: int = 0
	for prefix: String in ["Vector2", "Vector3", "Vector4"]:
		if text.begins_with(prefix):
			dimensions = int(prefix.right(1))
			text = text.trim_prefix(prefix).trim_prefix("i")
			break
	if dimensions == 0:
		return axes
	match text:
		".ZERO":
			text = "(%s)" % ",".join(_repeat("0", dimensions))
		".ONE":
			text = "(%s)" % ",".join(_repeat("1", dimensions))
	if not (text.begins_with("(") and text.ends_with(")")):
		return axes
	var parts: PackedStringArray = text.substr(1, text.length() - 2).split(",")
	# `Vector2(5)` is no constructor GDScript has, and `Vector3(a, b)` would mislead: the count must
	# be the dimension's own, and every part a plain number.
	if parts.size() != dimensions:
		return axes
	for part: String in parts:
		if not part.is_valid_float():
			return PackedStringArray()
		axes.append(_number_text(float(part)))
	return axes


## The GDScript type an Inspector-style row prints: the declared type exactly as written, else the
## type the value gives away (`var hits := 5` is an `int`), else `Variant`. Never a reading word.
static func gdscript_type_word(type_name: String, default_value: Variant, expression_default: bool) -> String:
	var declared: String = type_name.strip_edges()
	if not declared.is_empty() and declared != "Variant":
		return declared
	if not expression_default:
		if typeof(default_value) == TYPE_NIL or typeof(default_value) == TYPE_OBJECT:
			return "Variant"
		return type_string(typeof(default_value))
	var text: String = str(default_value).strip_edges()
	if text == "true" or text == "false":
		return "bool"
	if text.begins_with("&\""):
		return "StringName"
	if text.begins_with("^\""):
		return "NodePath"
	if text.begins_with("\"") or text.begins_with("'"):
		return "String"
	if text.begins_with("["):
		return "Array"
	if text.begins_with("{"):
		return "Dictionary"
	if text.is_valid_int():
		return "int"
	if text.is_valid_float():
		return "float"
	# A constructor or a constant of one of the engine's value types: `Vector2(0, 3)`, `Color.WHITE`.
	var cut: int = -1
	for index: int in range(text.length()):
		if text[index] == "(" or text[index] == ".":
			cut = index
			break
	if cut > 0:
		var head: String = text.left(cut)
		for variant_type: int in range(1, TYPE_MAX):
			if type_string(variant_type) == head and head != "Object":
				return head
	return "Variant"


## A variable's name the way the Inspector capitalises a property: `open_speed` reads "Open Speed".
static func inspector_name(identifier: String) -> String:
	var shown: String = identifier.strip_edges().capitalize()
	return shown if not shown.is_empty() else identifier


## The colour a value holds, whichever way it was written - a real Color, a `Color.RED` constant, a
## `Color(1, 0.7, 0.3)` literal, a `Color("#ffb347")` call - or null when it is not one the row can
## read without running anything.
static func color_of(default_value: Variant) -> Variant:
	if default_value is Color:
		return default_value
	if not (default_value is String or default_value is StringName):
		return null
	var text: String = str(default_value).strip_edges()
	if text.begins_with("Color.") and not text.contains("("):
		var named: String = text.trim_prefix("Color.").replace("_", "").to_lower()
		# A name the engine does not know falls back to whichever default it is handed, so two
		# opposite defaults disagree exactly when the name is not a colour.
		var dark := Color()
		var found: Color = Color.from_string(named, dark)
		return found if found == Color.from_string(named, dark.inverted()) else null
	if not (text.begins_with("Color(") and text.ends_with(")")):
		return null
	var inner: String = text.trim_prefix("Color(").trim_suffix(")").strip_edges()
	if inner.begins_with("\"") and inner.ends_with("\"") and inner.length() >= 2:
		var html: String = inner.substr(1, inner.length() - 2)
		return Color.html(html) if Color.html_is_valid(html) else null
	var numbers: PackedStringArray = inner.split(",")
	if numbers.size() < 3 or numbers.size() > 4:
		return null
	for number: String in numbers:
		if not number.strip_edges().is_valid_float():
			return null
	return Color(float(numbers[0]), float(numbers[1]), float(numbers[2]),
		float(numbers[3]) if numbers.size() > 3 else 1.0)


## `#RRGGBB`, or `#RRGGBBAA` when the colour is not fully opaque - the Inspector's own spelling.
static func color_hex(colour: Color) -> String:
	return "#%s" % (colour.to_html(false) if is_equal_approx(colour.a, 1.0) else colour.to_html(true)).to_upper()


## The width a colour value draws at: the swatch, the gap, and its hex in the type word's face.
static func color_value_width(hex: String, base: Font, font_size: int) -> float:
	return SWATCH_WIDTH + SWATCH_GAP + type_word_width(hex, base, font_size)


## Paints a colour value from `x`, centred on `centre_y`: the swatch edged in `frame`, then the hex in
## `ink` in the type word's face. Returns the swatch's rect, which a click on it opens the picker from.
static func draw_color_value(control: CanvasItem, x: float, centre_y: float, colour: Color, hex: String,
		base: Font, font_size: int, ink: Color, frame: Color) -> Rect2:
	var swatch := Rect2(x, centre_y - SWATCH_HEIGHT * 0.5, SWATCH_WIDTH, SWATCH_HEIGHT)
	_fill_rounded(control, swatch, colour, 2)
	control.draw_rect(swatch.grow(-0.5), frame, false, 1.0)
	var size: int = type_font_size(font_size)
	control.draw_string(mono_font(base), Vector2(swatch.end.x + SWATCH_GAP, centre_y + float(size) * 0.35), hex,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, ink)
	return swatch


## True for a member the compiler writes for its own bookkeeping, never one an author declared.
static func is_compiler_variable(variable_name: String) -> bool:
	return variable_name.begins_with(COMPILER_VARIABLE_PREFIX)


static func _repeat(text: String, count: int) -> PackedStringArray:
	var out := PackedStringArray()
	for _index: int in range(count):
		out.append(text)
	return out


## A number as the Inspector prints it: a whole number without its `.0`, anything else as written.
static func _number_text(value: float) -> String:
	if is_equal_approx(value, roundf(value)) and absf(value) < 1.0e15:
		return str(int(roundf(value)))
	return str(snappedf(value, 0.0001))


## The badges a variable earns, in their standing order.
static func badges_for(exported: bool, has_range: bool, has_doc: bool, saved: bool) -> PackedStringArray:
	var badges := PackedStringArray()
	if exported:
		badges.append(BADGE_INSPECTOR)
	if has_range:
		badges.append(BADGE_RANGE)
	if has_doc:
		badges.append(BADGE_TOOLTIP)
	if saved:
		badges.append(BADGE_SAVED)
	return badges


## Whether a variable is kept in a range by `@export_range`, read from what the importer stored: the
## structured range, or the hint text when the structured lift could not take it.
static func has_range(variable: LocalVariable) -> bool:
	if variable == null:
		return false
	if variable.attributes is Dictionary and (variable.attributes as Dictionary).get("range") is Dictionary:
		return true
	return variable.export_hint.strip_edges().begins_with("@export_range(")


## The names a sheet's own source keeps through the Save System: every key it writes (a Save Value
## row, a save_state() member) and every value a Remember row keeps. The same reading of the source
## the Doctor's save-key check makes, so a badge and a finding can never disagree about what a save
## is. Read once per change of the file; an in-memory sheet with no file keeps nothing.
static func saved_names(source_path: String) -> Dictionary:
	if source_path.is_empty() or not FileAccess.file_exists(source_path):
		return {}
	var modified: int = FileAccess.get_modified_time(source_path)
	var cached: Dictionary = _saved_cache.get(source_path, {})
	if not cached.is_empty() and int(cached.get("modified", -1)) == modified:
		return cached.get("names", {})
	var names: Dictionary = {}
	var source: String = FileAccess.get_file_as_string(source_path)
	if source.contains("save_") or source.contains("__remember_cfg"):
		# By path, so the editor half never compiles the Doctor until a sheet that saves is read.
		var doctor: Script = load("res://addons/eventforge/project_doctor.gd") as Script
		if doctor != null:
			var usage: Dictionary = doctor.call("save_key_usage", source)
			for key: String in usage.get("saved", PackedStringArray()):
				names[key] = true
			for key: String in usage.get("remembered", PackedStringArray()):
				names[key] = true
	_saved_cache[source_path] = {"modified": modified, "names": names}
	return names


## What a badge means, for its hover.
static func badge_tooltip(badge: String) -> String:
	match badge:
		BADGE_INSPECTOR:
			return EventSheetL10n.translate("Editable in the Inspector")
		BADGE_RANGE:
			return EventSheetL10n.translate("Kept between limits in the Inspector (@export_range).")
		BADGE_TOOLTIP:
			return EventSheetL10n.translate("Has a description: its ## comment, which the Inspector shows as its tooltip.")
		BADGE_SAVED:
			return EventSheetL10n.translate("Kept by the Save System under this variable's name.")
	return ""


## The room a run of `count` badge tiles takes at the row's right, the lead before them included.
## Nothing at all for no tiles.
static func badge_reserve(count: int) -> float:
	if count <= 0:
		return 0.0
	return TILE_LEAD + float(count) * TILE_SIZE + float(count - 1) * TILE_GAP


## The badges a row carries, read off the span the builder stamped them on.
static func row_badges(row_data: EventRowData) -> PackedStringArray:
	var span: SemanticSpan = badge_span(row_data)
	if span == null:
		return PackedStringArray()
	return PackedStringArray((span.metadata as Dictionary).get("variable_badges", PackedStringArray()))


## The span a row's badges are stamped on (its name), or null.
static func badge_span(row_data: EventRowData) -> SemanticSpan:
	if row_data == null or not row_data.variable_row:
		return null
	for span: SemanticSpan in row_data.spans:
		if span != null and span.metadata is Dictionary \
				and not PackedStringArray((span.metadata as Dictionary).get("variable_badges", PackedStringArray())).is_empty():
			return span
	return null


## Where each tile of a run stands: the run starts `TILE_LEAD` right of `start_x`, centred on
## `centre_y`. One rect per badge, in order.
static func tile_rects(start_x: float, centre_y: float, count: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for index: int in range(count):
		rects.append(tile_rect(start_x, centre_y, index))
	return rects


## One tile of the run `tile_rects` lays out, by its index - what the painter asks per tile, so a
## frame builds no array per row.
static func tile_rect(start_x: float, centre_y: float, index: int) -> Rect2:
	return Rect2(start_x + TILE_LEAD + float(index) * (TILE_SIZE + TILE_GAP), centre_y - TILE_SIZE * 0.5,
		TILE_SIZE, TILE_SIZE)


## The badge whose tile `point` is on, or "" - the one question the hover asks.
static func badge_at(row_data: EventRowData, point: Vector2) -> String:
	var span: SemanticSpan = badge_span(row_data)
	if span == null or not ((span.metadata as Dictionary).get("badge_tiles_x") is float):
		return ""
	var badges: PackedStringArray = row_badges(row_data)
	var rects: Array[Rect2] = tile_rects(float((span.metadata as Dictionary)["badge_tiles_x"]),
		span.rect.get_center().y, badges.size())
	for index: int in range(rects.size()):
		if rects[index].grow(1.0).has_point(point):
			return badges[index]
	return ""


## The foreground and background of a badge's tile, from the theme's four badge pairs.
static func badge_colors(event_style: EventSheetEventStyle, badge: String) -> Array[Color]:
	return [badge_ink(event_style, badge, true), badge_ink(event_style, badge, false)]


## One half of a badge's pair - its foreground, or its background - without building the pair, which
## is what the painter asks per tile per frame.
static func badge_ink(event_style: EventSheetEventStyle, badge: String, foreground: bool) -> Color:
	var style: EventSheetEventStyle = event_style if event_style != null else _fallback_style()
	match badge:
		BADGE_RANGE:
			return style.range_badge_foreground_color if foreground else style.range_badge_background_color
		BADGE_TOOLTIP:
			return style.tooltip_badge_foreground_color if foreground else style.tooltip_badge_background_color
		BADGE_SAVED:
			return style.saved_badge_foreground_color if foreground else style.saved_badge_background_color
	return style.inspector_badge_foreground_color if foreground else style.inspector_badge_background_color


## The style a badge asks when the canvas has none: the style's own defaults, made once.
static func _fallback_style() -> EventSheetEventStyle:
	if _default_style == null:
		_default_style = EventSheetEventStyle.new()
	return _default_style


## Paints one badge tile: a rounded tile in the badge's background with its icon on it.
static func draw_badge_tile(control: CanvasItem, rect: Rect2, badge: String, foreground: Color,
		background: Color) -> void:
	_fill_rounded(control, rect, background, 4)
	var icon := Rect2(rect.get_center() - Vector2(TILE_ICON, TILE_ICON) * 0.5, Vector2(TILE_ICON, TILE_ICON))
	var stroke: float = maxf(icon.size.x / 16.0 * 1.4, 1.0)
	match badge:
		BADGE_INSPECTOR:
			# An eye: two arcs meeting at the corners, and the pupil.
			var upper := PackedVector2Array()
			var lower := PackedVector2Array()
			for step: int in range(13):
				var t: float = float(step) / 12.0
				var x: float = lerpf(1.5, 14.5, t)
				var lift: float = sin(t * PI) * 4.5
				upper.append(_at(icon, x, 8.0 - lift))
				lower.append(_at(icon, x, 8.0 + lift))
			control.draw_polyline(upper, foreground, stroke, true)
			control.draw_polyline(lower, foreground, stroke, true)
			control.draw_circle(_at(icon, 8.0, 8.0), _units(icon, 2.0), foreground)
		BADGE_RANGE:
			# A slider: the track and its knob.
			control.draw_line(_at(icon, 2.0, 8.0), _at(icon, 14.0, 8.0), foreground, stroke, true)
			control.draw_circle(_at(icon, 10.0, 8.0), _units(icon, 2.6), background)
			control.draw_arc(_at(icon, 10.0, 8.0), _units(icon, 2.2), 0.0, TAU, 16, foreground, stroke, true)
		BADGE_TOOLTIP:
			# A speech bubble.
			control.draw_polyline(PackedVector2Array([_at(icon, 2.5, 3.5), _at(icon, 13.5, 3.5),
				_at(icon, 13.5, 10.5), _at(icon, 7.5, 10.5), _at(icon, 4.5, 13.0), _at(icon, 4.5, 10.5),
				_at(icon, 2.5, 10.5), _at(icon, 2.5, 3.5)]), foreground, stroke, true)
		BADGE_SAVED:
			# A disk: its body, the shutter and the label.
			control.draw_polyline(PackedVector2Array([_at(icon, 3.0, 2.5), _at(icon, 11.0, 2.5),
				_at(icon, 13.5, 5.0), _at(icon, 13.5, 13.5), _at(icon, 3.0, 13.5), _at(icon, 3.0, 2.5)]),
				foreground, stroke, true)
			control.draw_polyline(PackedVector2Array([_at(icon, 5.5, 2.5), _at(icon, 5.5, 5.5),
				_at(icon, 9.5, 5.5), _at(icon, 9.5, 2.5)]), foreground, stroke, true)
			control.draw_polyline(PackedVector2Array([_at(icon, 5.5, 13.5), _at(icon, 5.5, 9.5),
				_at(icon, 10.5, 9.5), _at(icon, 10.5, 13.5)]), foreground, stroke, true)


## The room a value glyph adds to (bool, resource) or takes in place of (vector) the value's text.
## Returns the span's whole width for a vector and the EXTRA width otherwise, which is how the
## measuring side reads it.
static func glyph_extra_width(glyph: String) -> float:
	match glyph:
		GLYPH_BOOL:
			return TICK_BOX + TICK_GAP
		GLYPH_RESOURCE:
			return CHIP_PAD_LEFT + CHIP_ICON + CHIP_ICON_GAP + CHIP_PAD_RIGHT
	return 0.0


## The whole width of a vector's fields at this font and size.
static func vector_width(axes: PackedStringArray, font: Font, font_size: int) -> float:
	if axes.is_empty() or font == null:
		return 0.0
	var width: float = 0.0
	for index: int in range(axes.size()):
		width += _field_width(AXIS_LETTERS[mini(index, AXIS_LETTERS.size() - 1)], axes[index], font, font_size)
	return width + float(axes.size() - 1) * FIELD_GAP


static func _field_width(letter: String, number: String, font: Font, font_size: int) -> float:
	var letter_size: int = maxi(font_size - 1, 8)
	return FIELD_PAD + font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, letter_size).x \
		+ FIELD_LETTER_GAP + font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x + FIELD_PAD


## Paints a bool's tick box with its left edge at `x`, centred on `centre_y`: filled with a tick for
## true, an empty frame for false. Returns how far the text after it moves.
static func draw_tick_box(control: CanvasItem, x: float, centre_y: float, checked: bool, fill: Color,
		frame: Color) -> float:
	var box := Rect2(x, centre_y - TICK_BOX * 0.5, TICK_BOX, TICK_BOX)
	if checked:
		_fill_rounded(control, box, fill, 2)
		var tick_ink: Color = contrast_ink(fill, TICK_INK_LUMINANCE)
		control.draw_polyline(PackedVector2Array([_at(box, 3.5, 8.5), _at(box, 6.7, 11.5),
			_at(box, 12.5, 4.5)]), tick_ink, maxf(TICK_BOX / 16.0 * 2.2, 1.5), true)
	else:
		control.draw_rect(box.grow(-0.5), frame, false, 1.0)
	return TICK_BOX + TICK_GAP


## Paints a vector's fields from `x`, centred on `centre_y`: each axis letter in its colour, its
## number in `ink`, inside a faint field edged in `frame`.
static func draw_vector_fields(control: CanvasItem, x: float, centre_y: float, axes: PackedStringArray,
		font: Font, font_size: int, ink: Color, axis_colors: Array[Color], frame: Color) -> void:
	var letter_size: int = maxi(font_size - 1, 8)
	var baseline: float = centre_y + float(font_size) * 0.35
	var field_fill := Color(frame.r, frame.g, frame.b, 0.07)
	var field_edge := Color(frame.r, frame.g, frame.b, 0.28)
	for index: int in range(axes.size()):
		var letter: String = AXIS_LETTERS[mini(index, AXIS_LETTERS.size() - 1)]
		var width: float = _field_width(letter, axes[index], font, font_size)
		var field := Rect2(x, centre_y - FIELD_HEIGHT * 0.5, width, FIELD_HEIGHT)
		_fill_rounded(control, field, field_fill, 3)
		control.draw_rect(field.grow(-0.5), field_edge, false, 1.0)
		var letter_ink: Color = axis_colors[index] if index < axis_colors.size() else ink
		var letter_x: float = x + FIELD_PAD
		control.draw_string(font, Vector2(letter_x, baseline), letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, letter_size, letter_ink)
		control.draw_string(font, Vector2(letter_x + 0.6, baseline), letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, letter_size, letter_ink)
		var number_x: float = letter_x + font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, letter_size).x + FIELD_LETTER_GAP
		control.draw_string(font, Vector2(number_x, baseline), axes[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, ink)
		x += width + FIELD_GAP


## Paints a resource chip's frame and mark from `x`, `text_width` wide inside, centred on `centre_y`.
## Returns how far the text inside it moves from `x`.
static func draw_resource_chip(control: CanvasItem, x: float, centre_y: float, text_width: float,
		mark: Color, ink: Color) -> float:
	var width: float = glyph_extra_width(GLYPH_RESOURCE) + text_width
	var chip := Rect2(x, centre_y - FIELD_HEIGHT * 0.5, width, FIELD_HEIGHT)
	_fill_rounded(control, chip, Color(ink.r, ink.g, ink.b, 0.07), 3)
	control.draw_rect(chip.grow(-0.5), Color(ink.r, ink.g, ink.b, 0.28), false, 1.0)
	var icon := Rect2(x + CHIP_PAD_LEFT, centre_y - CHIP_ICON * 0.5, CHIP_ICON, CHIP_ICON)
	# A hexagon: the resource mark, in the object colour.
	var corners := PackedVector2Array([_at(icon, 8.0, 1.8), _at(icon, 13.5, 4.8), _at(icon, 13.5, 11.2),
		_at(icon, 8.0, 14.2), _at(icon, 2.5, 11.2), _at(icon, 2.5, 4.8), _at(icon, 8.0, 1.8)])
	control.draw_polyline(corners, mark, maxf(CHIP_ICON / 16.0 * 1.4, 1.0), true)
	return CHIP_PAD_LEFT + CHIP_ICON + CHIP_ICON_GAP


## The axis letters' colours: the running editor's own X / Y / Z property colours where it has them,
## else the design's pair for a row filled with `background`.
static func axis_colors(background: Color) -> Array[Color]:
	var fallback: Array[Color] = AXIS_COLORS_LIGHT if background.get_luminance() >= 0.5 else AXIS_COLORS_DARK
	if not Engine.is_editor_hint() or not Engine.has_singleton("EditorInterface"):
		return fallback
	var editor_interface: Object = Engine.get_singleton("EditorInterface")
	if editor_interface == null or not editor_interface.has_method("get_editor_theme"):
		return fallback
	var theme: Theme = editor_interface.call("get_editor_theme")
	if theme == null or not theme.has_color("property_color_x", "Editor"):
		return fallback
	var colors: Array[Color] = []
	for axis: String in ["x", "y", "z", "w"]:
		colors.append(theme.get_color("property_color_%s" % axis, "Editor"))
	return colors


## A monospaced face backed by `base`, for the type word. The SAME object for the measuring side and
## the painting side, so the room a type word reserves is the room it draws in.
static func mono_font(base: Font) -> Font:
	var key: int = base.get_instance_id() if base != null else 0
	if _mono_cache.has(key):
		return _mono_cache[key]
	var mono := SystemFont.new()
	mono.font_names = MONO_FONT_NAMES
	if base != null:
		mono.fallbacks = [base]
	_mono_cache[key] = mono
	return mono


## The type word's size: one step under the row's, the way a type reads beside a name.
static func type_font_size(font_size: int) -> int:
	return maxi(font_size - 1, 8)


## The width a type word draws at, mono and one step smaller.
static func type_word_width(text: String, base: Font, font_size: int) -> float:
	return mono_font(base).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, type_font_size(font_size)).x


## `base` leaning into italics. A shear of the outlines only, so every advance is close to the one
## `base` measures - close, not equal: the editor's own fonts round the sheared glyphs a pixel or two
## differently, which is what `italic_room` makes up for.
static func italic_font(base: Font) -> Font:
	if base == null:
		return null
	var key: int = base.get_instance_id()
	if _italic_cache.has(key):
		return _italic_cache[key]
	var italic := FontVariation.new()
	italic.base_font = base
	italic.variation_transform = Transform2D(Vector2(1.0, ITALIC_SHEAR), Vector2(0.0, 1.0), Vector2.ZERO)
	_italic_cache[key] = italic
	return italic


## The width an italic note may draw in: the `room` its span was laid out with, plus however much
## wider the slanted words measure than the upright ones the layout measured. Without it the editor's
## fonts lose a note's last letter ("in units per secon") to a rounding the span never knew about.
static func italic_room(base: Font, text: String, font_size: int, room: float) -> float:
	if base == null or text.is_empty():
		return room
	var upright: float = base.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var leaning: float = italic_font(base).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	return room + maxf(leaning - upright, 0.0)


## Rounded fills share one StyleBoxFlat per colour and radius (a handful per theme), so a frame
## allocates nothing.
static func _fill_rounded(control: CanvasItem, rect: Rect2, color: Color, radius: int) -> void:
	var key: String = "%s/%d" % [color.to_html(), radius]
	var box: StyleBoxFlat = _box_cache.get(key)
	if box == null:
		box = StyleBoxFlat.new()
		box.bg_color = color
		box.set_corner_radius_all(radius)
		box.anti_aliasing = true
		_box_cache[key] = box
	control.draw_style_box(box, rect)


## A point of a glyph authored on a 16-unit square, placed inside `rect`.
static func _at(rect: Rect2, x: float, y: float) -> Vector2:
	return rect.position + Vector2(x, y) * (rect.size.x / 16.0)


static func _units(rect: Rect2, length: float) -> float:
	return length * rect.size.x / 16.0
