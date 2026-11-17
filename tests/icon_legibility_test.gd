# EventForge - every behaviour (pack) icon and every picker section icon reads at 16 px.
#
# The rules are the ones a survey of the icons measured, kept as numbers so a weak or a duplicate icon
# cannot ship again:
#   - enough lit pixels at 16 px (a drawing thinner than that is a smudge),
#   - a small share of half-covered pixels (a drawing off the pixel grid blurs),
#   - at least 3:1 contrast on the light editor's panel colours,
#   - no two icons nearer than a set distance (shape distance: the share of the 256 pixels that differ,
#     best of the nine one-pixel shifts), so two behaviours cannot wear the same picture.
# Every exception is named with its reason; the lists only shrink.
@tool
extends RefCounted

const SUPPORT := preload("res://tests/support.gd")
const STYLE := preload("res://tools/icon_style.gd")
const NAME: String = "icon_legibility_test"

const MIN_LIT: int = 40
const MAX_BLUR: float = 0.48
const MIN_CONTRAST: float = 3.0
const MIN_DISTANCE: float = 0.08
## The editor's light panel and tree colours, and Godot's own light-theme ink for each of ours.
const LIGHT_GROUNDS: Array[Color] = [Color("e6e6e6"), Color("f5f5f5")]
const LIGHT_INKS: Dictionary = {
	"#e0e0e0": "#5a5a5a", "#8da5f3": "#3d64dd", "#fc7f7f": "#cd3838", "#8eef97": "#2fa139", "#c38ef1": "#a85de9",
}

## Icons whose curved or diagonal strokes blur more than the limit and that were judged readable by eye.
const BLUR_EXCEPTIONS: PackedStringArray = [
	"pack:abilities", "pack:outline", "pack:sine", "pack:sine_3d", "section:json",
]
## Godot's own green for a Control is under 3:1 on the light panel; the anchor icon wears exactly that ink.
const CONTRAST_EXCEPTIONS: PackedStringArray = ["pack:anchor"]
## Pairs that share a picture on purpose: a section named after a behaviour wears that behaviour's drawing.
const SAME_DRAWING_PAIRS: PackedStringArray = [
	"pack:blend_modes|section:blend_modes", "pack:pin|section:pin", "pack:pin_3d|section:pin",
	"pack:vector_shapes|pack:vector_shapes#3d",
]
## Pairs a little nearer than the limit that mean different things and were judged apart by eye.
const NEAR_PAIRS: PackedStringArray = []


static func run() -> bool:
	var icons: Array = _icons()
	var rows: Dictionary = {}
	var lit_short: PackedStringArray = PackedStringArray()
	var blurry: PackedStringArray = PackedStringArray()
	var dim: PackedStringArray = PackedStringArray()
	for icon: Dictionary in icons:
		var name: String = str(icon["name"])
		var image: Image = _raster(str(icon["svg"]))
		var measured: Dictionary = _measure(image)
		rows[name] = measured["rows"]
		if int(measured["lit"]) < MIN_LIT:
			lit_short.append("%s (%d)" % [name, int(measured["lit"])])
		if float(measured["blur"]) > MAX_BLUR and not BLUR_EXCEPTIONS.has(name):
			blurry.append("%s (%.2f)" % [name, float(measured["blur"])])
		var light: float = _light_contrast(str(icon["svg"]))
		if light < MIN_CONTRAST and not CONTRAST_EXCEPTIONS.has(name):
			dim.append("%s (%.2f)" % [name, light])
	var near: PackedStringArray = _near_pairs(rows)
	var ok: bool = true
	ok = SUPPORT.check(NAME, "icons measured: every pack, the vector_shapes 3D icon and every section", icons.size() >= 199, true) and ok
	ok = SUPPORT.check(NAME, "every icon has at least %d lit pixels at 16 px" % MIN_LIT, ", ".join(lit_short), "") and ok
	ok = SUPPORT.check(NAME, "no icon blurs (half-covered pixels at most %.2f) unless named" % MAX_BLUR, ", ".join(blurry), "") and ok
	ok = SUPPORT.check(NAME, "every icon holds %.1f:1 on the light panel unless named" % MIN_CONTRAST, ", ".join(dim), "") and ok
	ok = SUPPORT.check(NAME, "no two icons are nearer than %.2f unless named" % MIN_DISTANCE, ", ".join(near), "") and ok
	for name: String in BLUR_EXCEPTIONS:
		ok = SUPPORT.check(NAME, "blur exception %s still names an icon" % name, rows.has(name), true) and ok
	for name: String in CONTRAST_EXCEPTIONS:
		ok = SUPPORT.check(NAME, "contrast exception %s still names an icon" % name, rows.has(name), true) and ok
	return ok


## Every pack icon, the second icon a pack carries for 3D classes, and every section icon, as
## {name, svg}. A name is `pack:<folder>`, `pack:<folder>#3d` or `section:<file name>`.
static func _icons() -> Array:
	var found: Array = []
	var packs: PackedStringArray = DirAccess.get_directories_at(STYLE.ADDONS_DIR)
	packs.sort()
	for pack: String in packs:
		for file: String in ["icon.svg", "icon_3d.svg"]:
			var path: String = "%s/%s/%s" % [STYLE.ADDONS_DIR, pack, file]
			if FileAccess.file_exists(path):
				found.append({"name": "pack:%s%s" % [pack, "" if file == "icon.svg" else "#3d"], "svg": FileAccess.get_file_as_string(path)})
	var files: PackedStringArray = DirAccess.get_files_at(STYLE.SECTION_DIR)
	files.sort()
	for file: String in files:
		if file.ends_with(".svg"):
			found.append({"name": "section:%s" % file.get_basename(), "svg": FileAccess.get_file_as_string("%s/%s" % [STYLE.SECTION_DIR, file])})
	return found


static func _raster(svg: String) -> Image:
	var image: Image = Image.new()
	image.load_svg_from_string(svg, 1.0)
	return image


## {lit, blur, rows}: lit pixels (alpha 0.5 or more), the share of half-covered pixels among the
## touched ones, and the lit mask as sixteen 16-bit rows.
static func _measure(image: Image) -> Dictionary:
	var lit: int = 0
	var partial: int = 0
	var bits: PackedInt32Array = PackedInt32Array()
	bits.resize(16)
	for y: int in 16:
		var row: int = 0
		for x: int in 16:
			var alpha: float = image.get_pixel(x, y).a
			if alpha >= 0.5:
				lit += 1
				row |= 1 << x
			if alpha > 0.1 and alpha < 0.9:
				partial += 1
		bits[y] = row
	return {"lit": lit, "blur": float(partial) / maxf(1.0, float(lit + partial)), "rows": bits}


## The contrast of the icon, as the light editor draws it, against the worse of the two light grounds:
## the alpha-weighted average colour of every touched pixel, composited on the ground.
static func _light_contrast(svg: String) -> float:
	var text: String = svg
	for ink: String in LIGHT_INKS:
		text = text.replace(ink, "@" + ink.substr(1))
	for ink: String in LIGHT_INKS:
		text = text.replace("@" + ink.substr(1), str(LIGHT_INKS[ink]))
	var image: Image = _raster(text)
	var worst: float = 99.0
	for ground: Color in LIGHT_GROUNDS:
		var red: float = 0.0
		var green: float = 0.0
		var blue: float = 0.0
		var weight: float = 0.0
		for y: int in 16:
			for x: int in 16:
				var pixel: Color = image.get_pixel(x, y)
				if pixel.a <= 0.1:
					continue
				red += (pixel.r * pixel.a + ground.r * (1.0 - pixel.a)) * pixel.a
				green += (pixel.g * pixel.a + ground.g * (1.0 - pixel.a)) * pixel.a
				blue += (pixel.b * pixel.a + ground.b * (1.0 - pixel.a)) * pixel.a
				weight += pixel.a
		if weight <= 0.0:
			return 0.0
		var average: Color = Color(red / weight, green / weight, blue / weight)
		var a: float = _luminance(average)
		var b: float = _luminance(ground)
		worst = minf(worst, (maxf(a, b) + 0.05) / (minf(a, b) + 0.05))
	return worst


static func _luminance(color: Color) -> float:
	var channels: Array[float] = []
	for value: float in [color.r, color.g, color.b]:
		channels.append(value / 12.92 if value <= 0.03928 else pow((value + 0.055) / 1.055, 2.4))
	return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


## Names of the pairs nearer than the limit that are neither a 2D icon and its 3D twin, nor named.
static func _near_pairs(rows: Dictionary) -> PackedStringArray:
	var table: PackedByteArray = PackedByteArray()
	table.resize(65536)
	for value: int in range(1, 65536):
		table[value] = table[value >> 1] + (value & 1)
	var names: Array = rows.keys()
	names.sort()
	var shifted: Dictionary = {}
	for name: String in names:
		shifted[name] = _shifts(rows[name])
	var found: PackedStringArray = PackedStringArray()
	for i: int in names.size():
		for j: int in range(i + 1, names.size()):
			var first: String = names[i]
			var second: String = names[j]
			if _is_twin(first, second) or SAME_DRAWING_PAIRS.has("%s|%s" % [first, second]) or NEAR_PAIRS.has("%s|%s" % [first, second]):
				continue
			var best: int = 256
			var base: PackedInt32Array = rows[first]
			for other: PackedInt32Array in shifted[second]:
				var differing: int = 0
				for y: int in 16:
					differing += table[(base[y] ^ other[y]) & 0xFFFF]
				best = mini(best, differing)
			if float(best) / 256.0 < MIN_DISTANCE:
				found.append("%s ~ %s (%.3f)" % [first, second, float(best) / 256.0])
	return found


## The nine one-pixel shifts of a sixteen-row mask, nothing wrapping round the edge.
static func _shifts(rows: PackedInt32Array) -> Array:
	var all: Array = []
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var moved: PackedInt32Array = PackedInt32Array()
			moved.resize(16)
			for y: int in 16:
				var source: int = y - dy
				if source < 0 or source > 15:
					continue
				var row: int = rows[source]
				if dx > 0:
					moved[y] = (row << 1) & 0xFFFF
				elif dx < 0:
					moved[y] = row >> 1
				else:
					moved[y] = row
			all.append(moved)
	return all


## A pack and its `_3d` twin share a picture by design (only the ink differs).
static func _is_twin(first: String, second: String) -> bool:
	return first + "_3d" == second or second + "_3d" == first
