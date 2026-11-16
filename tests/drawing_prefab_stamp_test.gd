# Godot EventSheets - a stamp step is its texture, turned by its Spin, in every picture of a prefab.
#
# A stamp step names a texture, a scale (p1) and a spin in degrees (p2). Draw Prefab always honoured
# the spin; the stamp node ignored it, and the Inspector picture (the software rasterizer that also
# makes the FileSystem thumbnail) drew every stamp as a tinted square whatever its texture, even with
# none. These pins read the shared placement the stamp node draws under, and the Inspector picture
# pixel by pixel - the suite cannot render a node, so the node's pixels are checked in the editor run.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const TEST_NAME := "drawing_prefab_stamp_test"

const RASTER_PATH := "res://addons/eventsheet/editor/inspector/drawing_prefab_preview.gd"
const PREFAB_PATH := "res://eventsheet_addons/drawing_prefab_resource/drawing_prefab_resource.gd"
const TEXTURE_PATH := "res://eventsheet_addons/drawing_prefab_stamp/icon.svg"
const BACKGROUND := Color(0.0, 0.0, 0.0, 1.0)
const PICTURE := Vector2i(96, 96)


static func run() -> bool:
	var ok: bool = true
	ok = _placement_pins() and ok
	ok = _picture_pins() and ok
	ok = _bounds_pins() and ok
	return ok


static func _stamp(spin: float, scale_by: float = 4.0, texture: String = TEXTURE_PATH) -> Dictionary:
	return {"kind": "stamp", "x": 0.0, "y": 0.0, "p1": scale_by, "p2": spin, "p3": 0.0, "color": "#ffffff", "texture": texture}


## The transform a stamp is drawn under: its offset, turned by its Spin. Asked by name so a tree
## without it reads as a failed pin rather than a file that does not compile.
static func _frame(step: Dictionary) -> Transform2D:
	var script: GDScript = load(PREFAB_PATH) as GDScript
	for method: Dictionary in script.get_script_method_list():
		if str(method.get("name", "")) == "stamp_frame":
			return script.call("stamp_frame", step)
	return Transform2D(NAN, Vector2.INF)


static func _placement_pins() -> bool:
	var spun: Dictionary = _stamp(30.0)
	spun["x"] = 12.0
	spun["y"] = -8.0
	var frame: Transform2D = _frame(spun)
	var still: Transform2D = _frame(_stamp(0.0))
	return SUPPORT.pins(TEST_NAME, [
		["a stamp is turned by its Spin, in degrees", snappedf(rad_to_deg(frame.get_rotation()), 0.001), 30.0],
		["and sits at its offset", frame.origin, Vector2(12.0, -8.0)],
		["a stamp with no Spin is not turned at all", still.get_rotation(), 0.0],
	])


static func _drawn_pixels(image: Image) -> int:
	var count: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y) != BACKGROUND:
				count += 1
	return count


static func _distinct_colours(image: Image, region: Rect2i) -> int:
	var seen: Dictionary = {}
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			seen[image.get_pixel(x, y).to_html()] = true
	return seen.size()


static func _differing_pixels(a: Image, b: Image) -> int:
	var count: int = 0
	for y: int in a.get_height():
		for x: int in a.get_width():
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				count += 1
	return count


static func _picture_pins() -> bool:
	var raster: Script = load(RASTER_PATH)
	var upright: Image = raster.call("rasterize", [_stamp(0.0)], PICTURE, BACKGROUND)
	var quarter: Image = raster.call("rasterize", [_stamp(90.0)], PICTURE, BACKGROUND)
	var bare: Image = raster.call("rasterize", [_stamp(0.0, 4.0, "")], PICTURE, BACKGROUND)
	var missing: Image = raster.call("rasterize", [_stamp(0.0, 4.0, "res://not/a/file.png")], PICTURE, BACKGROUND)
	var middle: Rect2i = Rect2i(PICTURE.x / 2 - 12, PICTURE.y / 2 - 12, 24, 24)
	var red: Image = raster.call("rasterize", [{"kind": "stamp", "x": 0.0, "y": 0.0, "p1": 4.0, "p2": 0.0, "p3": 0.0, "color": "#ff0000", "texture": TEXTURE_PATH}], PICTURE, BACKGROUND)
	var greenest: float = 0.0
	for y: int in red.get_height():
		for x: int in red.get_width():
			greenest = maxf(greenest, red.get_pixel(x, y).g)
	return SUPPORT.pins(TEST_NAME, [
		["the picture of a stamp is its texture, not one flat colour", _distinct_colours(upright, middle) > 2, true],
		["a stamp turned a quarter turn draws different pixels", _differing_pixels(upright, quarter) > 0, true],
		["a stamp with no texture draws nothing", _drawn_pixels(bare), 0],
		["a stamp whose texture is missing draws nothing", _drawn_pixels(missing), 0],
		["the colour tints the texture", greenest < 0.05, true],
	])


static func _bounds_pins() -> bool:
	var raster: Script = load(RASTER_PATH)
	var upright: Rect2 = raster.call("compute_bounds", [_stamp(0.0)])
	var diagonal: Rect2 = raster.call("compute_bounds", [_stamp(45.0)])
	var bare: Rect2 = raster.call("compute_bounds", [_stamp(0.0, 4.0, "")])
	return SUPPORT.pins(TEST_NAME, [
		["a stamp's box is its texture at its scale (a 16 px texture at 4x)", upright.size, Vector2(64.0, 64.0)],
		["turned half a quarter, its box is the turned square's", snappedf(diagonal.size.x, 0.1), 90.5],
		["a stamp with no texture only holds its place", bare.size, Vector2(4.0, 4.0)],
	])
