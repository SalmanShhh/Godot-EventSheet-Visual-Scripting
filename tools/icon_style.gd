# EventForge - how a behaviour (pack) icon is made from its glyph.
#
# A pack's icon is drawn the way Godot draws its own node icons: 16 x 16, no ground, filled shapes,
# one ink. The glyph (the drawing alone, in the neutral ink) lives in tools/pack_builders/icons/<pack>.glyph;
# this file turns it into the pack's icon.svg:
#   - the ink is the family of the node the pack works on (Node3D red, Control green, Node2D blue,
#     animation purple, everything else Godot's neutral grey), derived from the pack's own scripts,
#   - a behaviour (a pack that declares `var host: X = null`) wears one small dot in the bottom-right
#     corner in the same ink, which is what tells it from a plain node,
#   - the import beside it asks the importer to recolour the icon with the editor theme, which is what
#     makes the same file read on a light editor as Godot's own icons do.
# Pure functions, no state: tools/build_icons.gd writes the files, tests/godot_style_icons_test.gd and
# the pack build read the same answers.
@tool
extends RefCounted

const ADDONS_DIR: String = "res://eventsheet_addons"
const SECTION_DIR: String = "res://addons/eventsheet/icons/sections"
const GLYPH_DIR: String = "res://tools/pack_builders/icons"
## The ink a glyph source is drawn in; every other ink is this one with the family's colour swapped in.
const GLYPH_INK: String = "#e0e0e0"
## Godot's own icon inks (dark theme). Each is a key of the editor's light-theme conversion map, so a
## flagged import turns it into Godot's own light-theme ink.
const INK_NEUTRAL: String = "#e0e0e0"
const INK_2D: String = "#8da5f3"
const INK_3D: String = "#fc7f7f"
const INK_UI: String = "#8eef97"
const INK_ANIMATION: String = "#c38ef1"
const INKS: PackedStringArray = [INK_NEUTRAL, INK_2D, INK_3D, INK_UI, INK_ANIMATION]
const DOT_PREFIX: String = "<circle cx=\"13\" cy=\"13\" r=\"2\""
## The import flag that makes Godot draw an icon in the editor theme's colours.
const IMPORT_FLAG: String = "editor/convert_colors_with_editor_theme=true"


## The svg text of an icon: the glyph in `ink`, plus the behaviour dot when `dot` is set.
static func render(glyph: String, ink: String, dot: bool) -> String:
	var body: String = glyph.strip_edges().replace(GLYPH_INK, ink)
	if dot:
		body += "%s fill=\"%s\"/>" % [DOT_PREFIX, ink]
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\" viewBox=\"0 0 16 16\">%s</svg>\n" % body


## The family ink of an engine class name; neutral for anything that is none of the four families.
static func family_ink(engine_class: String) -> String:
	if engine_class.is_empty() or not ClassDB.class_exists(engine_class):
		return INK_NEUTRAL
	if engine_class == "Node3D" or ClassDB.is_parent_class(engine_class, "Node3D"):
		return INK_3D
	if engine_class == "Control" or ClassDB.is_parent_class(engine_class, "Control"):
		return INK_UI
	if engine_class == "Node2D" or ClassDB.is_parent_class(engine_class, "Node2D"):
		return INK_2D
	if ClassDB.is_parent_class(engine_class, "AnimationMixer") or engine_class == "Tween":
		return INK_ANIMATION
	return INK_NEUTRAL


## The class a pack's behaviour works on (`var host: X = null`), or "" when the pack declares none.
static func host_class(pack: String) -> String:
	var pattern: RegEx = RegEx.create_from_string("(?m)^var host: ([A-Za-z_][A-Za-z0-9_]*) = null$")
	for source: String in _sources(pack):
		var found: RegExMatch = pattern.search(source)
		if found != null:
			return found.get_string(1)
	return ""


## The engine class the pack's first declared class ends up extending, following the pack's own
## classes down to an engine one ("" for a pack with no script that names a class).
static func own_engine_class(pack: String) -> String:
	var parents: Dictionary = {}
	var first: String = ""
	var name_pattern: RegEx = RegEx.create_from_string("(?m)^class_name\\s+(\\S+)")
	var extends_pattern: RegEx = RegEx.create_from_string("(?m)^extends\\s+(\\S+)")
	for source: String in _sources(pack):
		var named: RegExMatch = name_pattern.search(source)
		var base: RegExMatch = extends_pattern.search(source)
		if named == null or base == null:
			continue
		parents[named.get_string(1)] = base.get_string(1)
		if first.is_empty():
			first = named.get_string(1)
	var current: String = first
	for _step: int in range(16):
		if current.is_empty() or ClassDB.class_exists(current) or not parents.has(current):
			break
		current = str(parents[current])
	return current if ClassDB.class_exists(current) else ""


## The ink a pack's icon is drawn in: what it works on, else what it is.
static func ink_for(pack: String) -> String:
	var host: String = host_class(pack)
	return family_ink(host if not host.is_empty() else own_engine_class(pack))


static func _sources(pack: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var folder: String = "%s/%s" % [ADDONS_DIR, pack]
	var names: PackedStringArray = DirAccess.get_files_at(folder)
	names.sort()
	for file_name: String in names:
		if file_name.ends_with(".gd"):
			out.append(FileAccess.get_file_as_string("%s/%s" % [folder, file_name]))
	return out


## The glyph source text for a pack (its own, else its 2D twin's), or "" when none is drawn yet.
static func glyph_for(pack: String) -> String:
	var own: String = "%s/%s.glyph" % [GLYPH_DIR, pack]
	if FileAccess.file_exists(own):
		return FileAccess.get_file_as_string(own)
	if pack.ends_with("_3d"):
		var twin: String = "%s/%s.glyph" % [GLYPH_DIR, pack.trim_suffix("_3d")]
		if FileAccess.file_exists(twin):
			return FileAccess.get_file_as_string(twin)
	return ""


## The import file beside an icon: exactly what the editor writes for an svg that follows the editor
## theme (so opening the project rewrites nothing), with an id and a cache name that depend only on the
## path. Godot rewrites the path-bound lines itself when the folder is moved, and keeps the flag.
static func import_text(svg_path: String) -> String:
	var hash_text: String = svg_path.md5_text()
	var uid: String = ResourceUID.id_to_text(("0x" + hash_text.substr(0, 15)).hex_to_int())
	var cached: String = "res://.godot/imported/%s-%s.ctex" % [svg_path.get_file(), hash_text]
	return "[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\nuid=\"%s\"\npath=\"%s\"\nmetadata={\n\"has_editor_variant\": true,\n\"vram_texture\": false\n}\n\n[deps]\n\nsource_file=\"%s\"\ndest_files=[\"%s\"]\n\n[params]\n\n" % [uid, cached, svg_path, cached] \
		+ "compress/mode=0\ncompress/high_quality=false\ncompress/lossy_quality=0.7\ncompress/uastc_level=0\ncompress/rdo_quality_loss=0.0\ncompress/hdr_compression=1\ncompress/normal_map=0\ncompress/channel_pack=0\nmipmaps/generate=false\nmipmaps/limit=-1\nroughness/mode=0\nroughness/src_normal=\"\"\nprocess/channel_remap/red=0\nprocess/channel_remap/green=1\nprocess/channel_remap/blue=2\nprocess/channel_remap/alpha=3\nprocess/fix_alpha_border=true\nprocess/premult_alpha=false\nprocess/normal_map_invert_y=false\nprocess/hdr_as_srgb=false\nprocess/hdr_clamp_exposure=false\nprocess/size_limit=0\ndetect_3d/compress_to=1\nsvg/scale=1.0\neditor/scale_with_editor_scale=true\neditor/convert_colors_with_editor_theme=true\n"
