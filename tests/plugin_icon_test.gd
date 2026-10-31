# EventForge - the plugin icon.
#
# One event drawn in one ink: a frame cut in two down the middle, a trigger arrow on the condition
# side, two action bars on the other, filled shapes with even-odd cut-outs on the 16 px grid. The ink
# is Godot's plain-icon light grey, and the plugin swaps it for the editor's own icon colour when it
# loads, because Godot recolours its own icons for a light theme but not a plugin's. The import asks
# the same of the importer for the @icon a sheet resource shows in the FileSystem.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const NAME: String = "plugin_icon_test"
const ICON_PATH: String = "res://addons/eventsheet/icons/eventsheet.svg"
const EVENT_ROW_SVG: String = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\" viewBox=\"0 0 16 16\"><path d=\"M3 3h10a2 2 0 0 1 2 2v6a2 2 0 0 1 -2 2h-10a2 2 0 0 1 -2 -2v-6a2 2 0 0 1 2 -2zM3 4.5h3.75a0.5 0.5 0 0 1 0.5 0.5v6a0.5 0.5 0 0 1 -0.5 0.5h-3.75a0.5 0.5 0 0 1 -0.5 -0.5v-6a0.5 0.5 0 0 1 0.5 -0.5zM9.25 4.5h3.75a0.5 0.5 0 0 1 0.5 0.5v6a0.5 0.5 0 0 1 -0.5 0.5h-3.75a0.5 0.5 0 0 1 -0.5 -0.5v-6a0.5 0.5 0 0 1 0.5 -0.5z\" fill=\"#E0E0E0\" fill-rule=\"evenodd\"/><path d=\"M3.7 6.1L6.3 8L3.7 9.9z\" fill=\"#E0E0E0\" fill-rule=\"evenodd\"/><path d=\"M10.4 6h1.6a0.5 0.5 0 0 1 0.5 0.5v0.5a0.5 0.5 0 0 1 -0.5 0.5h-1.6a0.5 0.5 0 0 1 -0.5 -0.5v-0.5a0.5 0.5 0 0 1 0.5 -0.5z\" fill=\"#E0E0E0\" fill-rule=\"evenodd\"/><path d=\"M10.4 8.5h0.7a0.5 0.5 0 0 1 0.5 0.5v0.5a0.5 0.5 0 0 1 -0.5 0.5h-0.7a0.5 0.5 0 0 1 -0.5 -0.5v-0.5a0.5 0.5 0 0 1 0.5 -0.5z\" fill=\"#E0E0E0\" fill-rule=\"evenodd\"/></svg>\n"
const LIGHT_INK: Color = Color("#5a5a5a")


static func run() -> bool:
	var ok: bool = true
	var svg: String = FileAccess.get_file_as_string(ICON_PATH)
	ok = SUPPORT.pins(NAME, [
		["the icon is the Event row drawing", svg, EVENT_ROW_SVG],
		["drawn in one ink", _fills(svg), PackedStringArray(["#E0E0E0"])],
		["the ink the plugin swaps is that one", EventForgePlugin.PLUGIN_ICON_INK, "#E0E0E0"],
	]) and ok
	var inked: String = EventForgePlugin.inked_svg(svg, LIGHT_INK)
	ok = SUPPORT.pins(NAME, [
		["swapping the ink leaves no light grey", _fills(inked), PackedStringArray(["#5A5A5A"])],
		["and either spelling of the hex is swapped", EventForgePlugin.inked_svg("fill=\"#e0e0e0\"", LIGHT_INK), "fill=\"#5A5A5A\""],
	]) and ok
	var texture: Texture2D = EventForgePlugin.inked_svg_texture(svg, LIGHT_INK, 1.0)
	var image: Image = texture.get_image() if texture != null else Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.convert(Image.FORMAT_RGBA8)
	var big: Texture2D = EventForgePlugin.inked_svg_texture(svg, LIGHT_INK, 2.0)
	ok = SUPPORT.pins(NAME, [
		["the icon is 16 px at editor scale 1", image.get_size(), Vector2i(16, 16)],
		["and 32 px at editor scale 2", Vector2i(big.get_size()) if big != null else Vector2i.ZERO, Vector2i(32, 32)],
		["the frame is solid ink", _hex(image.get_pixel(1, 7)), "5a5a5aff"],
		["an action bar is solid ink", _hex(image.get_pixel(11, 6)), "5a5a5aff"],
		["the condition side is cut out under the arrow", image.get_pixel(4, 10).a, 0.0],
		["the action side is cut out under the bars", image.get_pixel(12, 10).a, 0.0],
		["outside the frame is empty", image.get_pixel(8, 1).a, 0.0],
		["a texture drawn in the ink is in the ink", EventForgePlugin.is_in_ink(texture, LIGHT_INK), true],
		["the light grey one is not, so the import is redrawn", EventForgePlugin.is_in_ink(EventForgePlugin.inked_svg_texture(svg, Color("#E0E0E0"), 1.0), LIGHT_INK), false],
		["text that is not an svg draws nothing", EventForgePlugin.inked_svg_texture("", LIGHT_INK, 1.0), null],
	]) and ok
	ok = SUPPORT.pins(NAME, [
		["with no theme to ask the ink stays light grey", EventForgePlugin.editor_icon_ink(null), Color("#E0E0E0")],
		["a theme's plain icon colour is the ink", _hex(EventForgePlugin.editor_icon_ink(_theme_inked(LIGHT_INK))), "5a5a5aff"],
	]) and ok
	# A switch between a dark and a light editor theme while it runs: the editor asks for the icon
	# again, and an icon inked for the other theme is made again in the new ink.
	var made: Texture2D = EventForgePlugin.inked_svg_texture(svg, Color("#E0E0E0"), 1.0)
	ok = SUPPORT.pins(NAME, [
		["no icon yet is made", EventForgePlugin.icon_needs_inking(null, Color("#E0E0E0"), Color("#E0E0E0")), true],
		["one in the editor's ink is kept", EventForgePlugin.icon_needs_inking(made, Color("#E0E0E0"), Color("#E0E0E0")), false],
		["one inked for the dark theme is made again on the light one",
			EventForgePlugin.icon_needs_inking(made, Color("#E0E0E0"), LIGHT_INK), true],
	]) and ok
	var import_text: String = FileAccess.get_file_as_string(ICON_PATH + ".import")
	ok = SUPPORT.pins(NAME, [
		["the import draws the @icon in the editor's colours", import_text.contains("editor/convert_colors_with_editor_theme=true"), true],
		["and at the editor's scale", import_text.contains("editor/scale_with_editor_scale=true"), true],
	]) and ok
	return ok


static func _fills(svg: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var pattern: RegEx = RegEx.create_from_string("fill=\"(#[0-9A-Fa-f]{6})\"")
	for found: RegExMatch in pattern.search_all(svg):
		if not out.has(found.get_string(1)):
			out.append(found.get_string(1))
	return out


static func _hex(colour: Color) -> String:
	return colour.to_html(true)


## A theme whose sample icon is a soft-edged square in `ink`, the way an editor icon reaches it.
static func _theme_inked(ink: Color) -> Theme:
	var image: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(ink, 0.4))
	image.fill_rect(Rect2i(4, 4, 8, 8), ink)
	var theme: Theme = Theme.new()
	theme.set_icon(EventForgePlugin.EDITOR_INK_SAMPLE_ICON, "EditorIcons", ImageTexture.create_from_image(image))
	return theme
