# Godot EventSheets - DrawingPrefabResource preview renderer (editor-only).
#
# Rasterizes a DrawingPrefabResource's ordered `steps` into an Image so you can SEE the composed drawing
# before you use it. One software rasterizer (no scene tree, no CanvasItem) feeds both preview surfaces:
#   - the Inspector panel (EventSheetDrawingPrefabInspector), and
#   - the FileSystem / resource-picker thumbnail (EventSheetDrawingPrefabPreviewGenerator).
# Software (not draw_* / SubViewport) so it is thread-safe - Godot generates resource thumbnails off the
# main thread, where touching the tree would crash. It follows the same rules the pack paints with:
# a line ends at its End measured from the prefab's origin, ends and dashes are drawn, and a stamp is
# its texture turned by its Spin (the preview shows the base pose, so the prefab's own rotation is 0).
@tool
class_name EventSheetDrawingPrefabPreview
extends RefCounted

const _SUPERSAMPLE: int = 2  # render at 2x then shrink for cheap anti-aliasing
## How strong a step is drawn while another step is the chosen one.
const QUIET_STRENGTH: float = 0.28
## How many bands a large picture is drawn in at once, and the fewest steps that are worth drawing in bands.
const BAND_COUNT: int = 8
const BAND_MIN_STEPS: int = 24
## Room to spare, in pixels, when a fill works out which columns of a row can hold its shape.
const PRUNE_MARGIN: float = 1.5
## The shortest see-through run worth looking at to blend it in one go: a shorter one is blended pixel by pixel.
const BLEND_RUN_LEAST: int = 12
## Whether a fill visits only the columns of a row that can hold its shape. It always draws the same pixels either way;
## a test turns it off to draw every pixel of the bounding box the long way and compares.
static var prune_columns: bool = true
## Whether a see-through run laid over pixels of one colour is blended once and written across. It always draws the same
## pixels either way; a test turns it off and compares.
static var blend_runs: bool = true


## The prefab-local bounding box that encloses every step (before any fit/scale). Empty steps -> a unit box.
static func compute_bounds(steps: Array) -> Rect2:
	var bounds: Rect2 = Rect2()
	var seeded: bool = false
	for step: Variant in steps:
		if not (step is Dictionary):
			continue
		var box: Rect2 = _step_bounds(step as Dictionary)
		bounds = box if not seeded else bounds.merge(box)
		seeded = true
	if not seeded:
		return Rect2(-16, -16, 32, 32)
	return bounds


## The local bounding box of a single step, sized by its kind.
static func _step_bounds(entry: Dictionary) -> Rect2:
	var at: Vector2 = Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))
	var p1: float = float(entry.get("p1", 0.0))
	var p2: float = float(entry.get("p2", 0.0))
	var p3: float = float(entry.get("p3", 0.0))
	match str(entry.get("kind", "")):
		"circle", "ring":
			var r: float = maxf(absf(p1), 1.0)
			return Rect2(at.x - r, at.y - r, r * 2.0, r * 2.0)
		"rect":
			return Rect2(at, Vector2(p1, p2)).abs()
		"line":
			# A line's End is a point in the prefab's own space, measured from the origin - not a
			# length added to the offset - so the box runs from the offset to that point.
			var w: float = maxf(absf(p3), 1.0)
			return Rect2(at, Vector2.ZERO).expand(Vector2(p1, p2)).grow(w * 0.5)
		"cone":
			var cr: float = maxf(absf(p3), 1.0)
			return Rect2(at.x - cr, at.y - cr, cr * 2.0, cr * 2.0)
		"arc", "pie", "regular_polygon":
			# The whole circle the shape sits on, so the box does not move while its angles are being typed.
			var reach: float = maxf(absf(p1), 1.0)
			if str(entry.get("kind", "")) == "arc":
				reach += maxf(float(entry.get("thickness", 2.0)), 1.0) * 0.5
			return Rect2(at.x - reach, at.y - reach, reach * 2.0, reach * 2.0)
		"rounded_rect":
			return Rect2(at, Vector2(p1, p2)).abs()
		"stamp":
			# The box of the stamp's texture at its scale, turned by its Spin. A stamp with no texture
			# that loads draws nothing, so it only holds its place.
			var texture: Texture2D = _stamp_texture(entry)
			if texture == null:
				return Rect2(at.x - 2.0, at.y - 2.0, 4.0, 4.0)
			var size: Vector2 = texture.get_size() * maxf(absf(p1), 0.01)
			var turn: float = deg_to_rad(p2)
			var half: Vector2 = Vector2(
				absf(size.x * cos(turn)) + absf(size.y * sin(turn)),
				absf(size.x * sin(turn)) + absf(size.y * cos(turn))) * 0.5
			return Rect2(at - half, half * 2.0)
	return Rect2(at.x - 2.0, at.y - 2.0, 4.0, 4.0)


## The texture a stamp step names, by its path or its uid text - or null when there is none or it does
## not load. Loading by path is safe off the main thread, which is where thumbnails are made.
static func _stamp_texture(entry: Dictionary) -> Texture2D:
	var path: String = str(entry.get("texture", "")).strip_edges()
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as Texture2D


## Renders the steps into an Image of `size`, letterboxed on `bg`. Deterministic and tree-free. When `quiet_except`
## names steps (by position in `steps`), every other step is drawn quietened to a fraction of its strength so the named
## ones stand out; an empty list quietens nothing and draws the very same pixels as before it existed.
static func rasterize(steps: Array, size: Vector2i, bg: Color, quiet_except: Array = [], bands: int = -1) -> Image:
	var w: int = maxi(size.x, 8) * _SUPERSAMPLE
	var h: int = maxi(size.y, 8) * _SUPERSAMPLE
	var layout: Dictionary = _layout(steps, size)
	var parts: int = _bands_for(steps) if bands < 0 else bands
	var img: Image = null
	if parts <= 1:
		var whole: _Canvas = _Canvas.new(w, 0, h, bg)
		_draw_steps(whole, steps, layout, quiet_except)
		img = whole.image
	else:
		# A large picture is drawn in horizontal bands at once. Every pixel belongs to one band and is blended by the
		# same steps in the same order, so the picture is exactly the one a single pass draws.
		var rows_per: int = ceili(float(h) / float(parts))
		var canvases: Array = []
		var top: int = 0
		while top < h:
			canvases.append(_Canvas.new(w, top, mini(rows_per, h - top), bg))
			top += rows_per
		var group: int = WorkerThreadPool.add_group_task(func(index: int) -> void:
			_draw_steps(canvases[index] as _Canvas, steps, layout, quiet_except), canvases.size(), -1, true)
		WorkerThreadPool.wait_for_group_task_completion(group)
		img = Image.create(w, h, false, Image.FORMAT_RGBA8)
		for part: Variant in canvases:
			var band: _Canvas = part
			img.blit_rect(band.image, Rect2i(0, 0, w, band.rows), Vector2i(0, band.top))
	if _SUPERSAMPLE > 1:
		img.resize(maxi(size.x, 8), maxi(size.y, 8), Image.INTERPOLATE_LANCZOS)
	return img


## How many bands a picture of these steps is drawn in. A picture with a stamp is drawn whole (a stamp loads its texture
## while it is drawn, and every band would load it again), and so is one too small for the bands to pay for themselves.
static func _bands_for(steps: Array) -> int:
	if steps.size() < BAND_MIN_STEPS:
		return 1
	for step: Variant in steps:
		if step is Dictionary and str((step as Dictionary).get("kind", "")) == "stamp":
			return 1
	return BAND_COUNT


## Blends every step, in order, into the rows of one canvas.
static func _draw_steps(canvas: _Canvas, steps: Array, layout: Dictionary, quiet_except: Array) -> void:
	var scale: float = float(layout["scale"])
	var center_local: Vector2 = layout["center_local"]
	var center_px: Vector2 = layout["center_px"]
	for position: int in range(steps.size()):
		var step: Variant = steps[position]
		if step is Dictionary:
			var fade: float = 1.0 if quiet_except.is_empty() or quiet_except.has(position) else QUIET_STRENGTH
			_rasterize_step(canvas, step as Dictionary, scale, center_local, center_px, fade)


## A strip of the picture being drawn: `rows` rows starting at row `top` of the whole, as an image of its own that the
## fills write into by the whole picture's own row numbers.
class _Canvas:
	extends RefCounted

	var image: Image = null
	var width: int = 0
	var top: int = 0
	var rows: int = 0

	func _init(wide: int, first_row: int, row_count: int, ground: Color) -> void:
		width = wide
		top = first_row
		rows = row_count
		image = Image.create(wide, row_count, false, Image.FORMAT_RGBA8)
		image.fill(ground)


## How the steps are laid into a picture of `size`: the scale (in supersampled pixels per local unit), the local point
## that sits in the middle and the pixel it sits at. The one place the fit is worked out, shared by drawing and picking.
static func _layout(steps: Array, size: Vector2i) -> Dictionary:
	var w: int = maxi(size.x, 8) * _SUPERSAMPLE
	var h: int = maxi(size.y, 8) * _SUPERSAMPLE
	var bounds: Rect2 = compute_bounds(steps).grow(4.0)
	# Fit the whole prefab into the image with a margin, preserving aspect and centering.
	var span: Vector2 = Vector2(maxf(bounds.size.x, 1.0), maxf(bounds.size.y, 1.0))
	return {"scale": minf(float(w) / span.x, float(h) / span.y) * 0.86, "center_local": bounds.get_center(), "center_px": Vector2(w, h) * 0.5}


## Picture pixels per prefab-local unit, at the size the picture is shown.
static func view_scale(steps: Array, size: Vector2i) -> float:
	return float(_layout(steps, size)["scale"]) / float(_SUPERSAMPLE)


## The prefab-local point drawn at a pixel of the picture (and the pixel a local point is drawn at, the other way).
static func local_from_pixel(steps: Array, size: Vector2i, pixel: Vector2) -> Vector2:
	var layout: Dictionary = _layout(steps, size)
	return (pixel * float(_SUPERSAMPLE) - (layout["center_px"] as Vector2)) / float(layout["scale"]) + (layout["center_local"] as Vector2)


static func pixel_from_local(steps: Array, size: Vector2i, local: Vector2) -> Vector2:
	var layout: Dictionary = _layout(steps, size)
	return _to_px(local, float(layout["scale"]), layout["center_local"], layout["center_px"]) / float(_SUPERSAMPLE)


## The step drawn at a prefab-local point, or -1: the one drawn LAST (on top) when several cover it, as what you see
## is what is taken. `tolerance` is how far, in local units, a point may miss a shape and still hit it. A step that
## draws nothing (a stamp whose texture does not load) cannot be taken. Uses the same sizes the picture is drawn with.
static func hit_step(steps: Array, local: Vector2, tolerance: float) -> int:
	for position: int in range(steps.size() - 1, -1, -1):
		var step: Variant = steps[position]
		if step is Dictionary and _covers(step as Dictionary, local, tolerance):
			return position
	return -1


static func _covers(entry: Dictionary, local: Vector2, tolerance: float) -> bool:
	var at: Vector2 = Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))
	var p1: float = float(entry.get("p1", 0.0))
	var p2: float = float(entry.get("p2", 0.0))
	var p3: float = float(entry.get("p3", 0.0))
	match str(entry.get("kind", "")):
		"circle":
			return local.distance_to(at) <= maxf(p1, 0.5) + tolerance
		"ring":
			return absf(local.distance_to(at) - maxf(p1, 0.5)) <= maxf(p2, tolerance) * 0.5 + tolerance
		"rect":
			return Rect2(at, Vector2(p1, p2)).abs().grow(tolerance).has_point(local)
		"line":
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(local, at, Vector2(p1, p2))
			return local.distance_to(closest) <= maxf(p3, tolerance) * 0.5 + tolerance
		"cone":
			var apex_offset: Vector2 = local - at
			if apex_offset.length() > maxf(p3, 0.5) + tolerance:
				return false
			if apex_offset.length() <= tolerance:
				return true
			return absf(wrapf(apex_offset.angle() - deg_to_rad(p1), -PI, PI)) <= deg_to_rad(maxf(p2, 1.0)) * 0.5
		"arc":
			if p1 <= 0.0 or not _in_sweep(local - at, p2, p3):
				return false
			return absf(local.distance_to(at) - p1) <= maxf(float(entry.get("thickness", 2.0)), tolerance) * 0.5 + tolerance
		"pie":
			if p1 <= 0.0:
				return false
			var reach: float = local.distance_to(at)
			return reach <= p1 + tolerance and (reach <= tolerance or _in_sweep(local - at, p2, p3))
		"rounded_rect":
			var body: Rect2 = Rect2(at, Vector2(p1, p2)).abs()
			if body.size.x <= 0.0 or body.size.y <= 0.0:
				return false
			var round_by: float = clampf(p3, 0.0, minf(body.size.x, body.size.y) * 0.5)
			var gap: Vector2 = (local - body.get_center()).abs() - (body.size * 0.5 - Vector2(round_by, round_by))
			return Vector2(maxf(gap.x, 0.0), maxf(gap.y, 0.0)).length() + minf(maxf(gap.x, gap.y), 0.0) - round_by <= tolerance
		"regular_polygon":
			return p1 > 0.0 and _polygon_distance(local - at, p1, p2, p3) <= tolerance
		"stamp":
			var texture: Texture2D = _stamp_texture(entry)
			if texture == null:
				return false
			var box: Vector2 = texture.get_size() * maxf(absf(p1), 0.01)
			var turn: float = deg_to_rad(p2)
			var from_centre: Vector2 = local - at
			var inside: Vector2 = Vector2(from_centre.x * cos(turn) + from_centre.y * sin(turn), -from_centre.x * sin(turn) + from_centre.y * cos(turn))
			return absf(inside.x) <= box.x * 0.5 + tolerance and absf(inside.y) <= box.y * 0.5 + tolerance
	return false


## Convenience: a ready-to-show texture (used by the Inspector panel).
static func rasterize_texture(steps: Array, size: Vector2i, bg: Color, quiet_except: Array = []) -> ImageTexture:
	return ImageTexture.create_from_image(rasterize(steps, size, bg, quiet_except))


static func _to_px(local: Vector2, scale: float, center_local: Vector2, center_px: Vector2) -> Vector2:
	return (local - center_local) * scale + center_px


static func _rasterize_step(img: _Canvas, entry: Dictionary, scale: float, center_local: Vector2, center_px: Vector2, fade: float = 1.0) -> void:
	var at_local: Vector2 = Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))
	var at: Vector2 = _to_px(at_local, scale, center_local, center_px)
	var p1: float = float(entry.get("p1", 0.0))
	var p2: float = float(entry.get("p2", 0.0))
	var p3: float = float(entry.get("p3", 0.0))
	var tint: Color = Color.from_string(str(entry.get("color", "white")), Color.WHITE)
	tint.a *= fade
	match str(entry.get("kind", "")):
		"circle":
			_fill_disc(img, at, maxf(p1, 0.5) * scale, tint)
		"ring":
			_fill_ring(img, at, maxf(p1, 0.5) * scale, maxf(p2 * scale, float(_SUPERSAMPLE)), tint)
		"rect":
			var corner: Vector2 = _to_px(at_local + Vector2(p1, p2), scale, center_local, center_px)
			_fill_rect(img, Rect2(at, corner - at).abs(), tint)
		"line":
			var to_px: Vector2 = _to_px(Vector2(p1, p2), scale, center_local, center_px)
			_fill_stroke(img, at, to_px, maxf(p3 * scale, float(_SUPERSAMPLE)), tint, entry, scale)
		"cone":
			_fill_cone(img, at, maxf(p3, 0.5) * scale, p1, p2, tint)
		"arc":
			_fill_arc(img, at, p1 * scale, maxf(float(entry.get("thickness", 2.0)) * scale, float(_SUPERSAMPLE)), p2, p3, tint)
		"pie":
			_fill_pie(img, at, p1 * scale, p2, p3, tint)
		"rounded_rect":
			_fill_rounded_rect(img, Rect2(at, Vector2(p1, p2) * scale).abs(), p3 * scale, tint)
		"regular_polygon":
			_fill_polygon(img, at, p1 * scale, p2, p3, tint)
		"stamp":
			var texture: Texture2D = _stamp_texture(entry)
			if texture != null:
				_fill_stamp(img, at, texture, maxf(p1, 0.01) * scale, p2, tint)


# ── Software fills (each iterates only its own pixel bounding box, so cost tracks shape area, not image size) ──
static func _px_bounds(img: _Canvas, r: Rect2) -> Rect2i:
	var clip: Rect2i = Rect2i(0, img.top, img.width, img.rows)
	return Rect2i(int(floor(r.position.x)), int(floor(r.position.y)), int(ceil(r.size.x)) + 1, int(ceil(r.size.y)) + 1).intersection(clip)


static func _blend(img: _Canvas, x: int, y: int, c: Color) -> void:
	var row: int = y - img.top
	if c.a >= 0.999:
		img.image.set_pixel(x, row, c)
	else:
		img.image.set_pixel(x, row, img.image.get_pixel(x, row).lerp(c, c.a))


## The half width of a circle of `radius` along a pixel row `dy` from its centre, plus a pixel and a half to spare, or -1
## when the row cannot touch the circle. Every pixel the circle's own test accepts lies inside it, so a fill that visits
## only these columns and still asks the circle's own test of each draws the very same pixels as one that visits the
## whole bounding box: the spare room is what keeps rounding from ever mattering.
static func _chord(radius: float, dy: float) -> float:
	if not prune_columns:
		return 1.0e9
	if absf(dy) > radius + PRUNE_MARGIN:
		return -1.0
	return sqrt(maxf(radius * radius - dy * dy, 0.0)) + PRUNE_MARGIN


## The columns of `box` whose pixel centres lie within `reach` of `middle`: [first, one past the last].
static func _columns(box: Rect2i, middle: float, reach: float) -> Vector2i:
	return Vector2i(maxi(box.position.x, int(floor(middle - reach - 0.5))), mini(box.position.x + box.size.x, int(floor(middle + reach - 0.5)) + 1))


## The columns of `columns` whose pixel centres are within `half_width` of `middle`, which a fill that knows them to be
## inside its shape (with the same spare room as above) writes in one go: [first, one past the last], or an empty run
## when there are none or the long way was asked for.
static func _solid_columns(columns: Vector2i, middle: float, half_width: float) -> Vector2i:
	if not prune_columns or half_width <= 0.0:
		return Vector2i(columns.x, columns.x)
	var first: int = maxi(columns.x, int(ceil(middle - half_width - 0.5)))
	var last: int = mini(columns.y, int(floor(middle + half_width - 0.5)) + 1)
	if last <= first:
		return Vector2i(columns.x, columns.x)
	return Vector2i(first, last)


## Writes the pixels of row `y` from column `first` up to `last`. An opaque colour sets every one of them to it, which is
## what setting them one at a time does; a see-through one is blended into each as ever.
static func _fill_run(img: _Canvas, y: int, first: int, last: int, c: Color) -> void:
	if last <= first:
		return
	if c.a >= 0.999:
		img.image.fill_rect(Rect2i(first, y - img.top, last - first, 1), c)
		return
	# A see-through run over pixels that are all one colour (the ground, or the inside of one earlier shape) is that one
	# colour blended once and written across, which is what blending each pixel gives: the same sum on the same colour.
	var count: int = last - first
	if blend_runs and count >= BLEND_RUN_LEAST:
		var row: int = y - img.top
		var under: PackedByteArray = img.image.get_region(Rect2i(first, row, count, 1)).get_data()
		if under.slice(4) == under.slice(0, under.size() - 4):
			img.image.fill_rect(Rect2i(first, row, count, 1), img.image.get_pixel(first, row).lerp(c, c.a))
			return
	for x: int in range(first, last):
		_blend(img, x, y, c)


static func _fill_disc(img: _Canvas, center: Vector2, radius: float, c: Color) -> void:
	var r: float = maxf(radius, 1.0)
	var box: Rect2i = _px_bounds(img, Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0))
	for y: int in range(box.position.y, box.position.y + box.size.y):
		var dy: float = y + 0.5 - center.y
		var reach: float = _chord(r, dy)
		if reach < 0.0:
			continue
		var columns: Vector2i = _columns(box, center.x, reach)
		var solid: Vector2i = _solid_columns(columns, center.x, sqrt(maxf(r * r - dy * dy, 0.0)) - PRUNE_MARGIN)
		for x: int in range(columns.x, solid.x):
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= r:
				_blend(img, x, y, c)
		_fill_run(img, y, solid.x, solid.y, c)
		for x: int in range(solid.y, columns.y):
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= r:
				_blend(img, x, y, c)


static func _fill_ring(img: _Canvas, center: Vector2, radius: float, width: float, c: Color) -> void:
	var r: float = maxf(radius, 1.0)
	var half: float = maxf(width, 1.0) * 0.5
	var box: Rect2i = _px_bounds(img, Rect2(center - Vector2(r + half, r + half), Vector2(r + half, r + half) * 2.0))
	for y: int in range(box.position.y, box.position.y + box.size.y):
		var cuts: PackedInt32Array = _band_cuts(box, center, r, half, y, true)
		if cuts.is_empty():
			continue
		# The stretches between the cuts are asked pixel by pixel; the two stretches the cuts mark as lying wholly inside the
		# ring are written as runs, and the middle of the hole is left alone.
		for span: int in [0, 2, 4, 6]:
			for x: int in range(cuts[span], cuts[span + 1]):
				if absf(Vector2(x + 0.5, y + 0.5).distance_to(center) - r) <= half:
					_blend(img, x, y, c)
			if span == 0:
				_fill_run(img, y, cuts[1], cuts[2], c)
			elif span == 4:
				_fill_run(img, y, cuts[5], cuts[6], c)


## The pixel columns of row `y` that can lie in a band `half` either side of a circle of `radius`, as eight column numbers
## in order: [first of the outer circle, the left stretch that is surely inside the band (from, up to), the hole's middle
## (from, up to), the right stretch that is surely inside the band (from, up to), one past the last of the outer circle].
## A pixel centre well inside the band by the room spared (see PRUNE_MARGIN) is surely in it, and one well inside the hole
## surely is not; everything else between is for the caller to ask. `solids` says whether the stretches that are surely inside
## are wanted (a ring's are; an arc's are not, its sweep decides). Empty when the row cannot touch the band.
static func _band_cuts(box: Rect2i, center: Vector2, radius: float, half: float, y: int, solids: bool) -> PackedInt32Array:
	var dy: float = y + 0.5 - center.y
	var outer: float = _chord(radius + half, dy)
	if outer < 0.0:
		return PackedInt32Array()
	var outside: Vector2i = _columns(box, center.x, outer)
	var inner_radius: float = radius - half
	var near_in: float = 0.0
	var near_out: float = 0.0
	if prune_columns and inner_radius > 0.0 and absf(dy) < inner_radius:
		var along: float = sqrt(inner_radius * inner_radius - dy * dy)
		near_in = along - PRUNE_MARGIN
		near_out = along + PRUNE_MARGIN
	# The columns whose centres are surely in the hole, and (wider) the ones that may be near it.
	var hole: Vector2i = _solid_columns(outside, center.x, near_in)
	var solid: Vector2i = Vector2i(outside.x, outside.x)
	if solids:
		solid = _solid_columns(outside, center.x, sqrt(maxf((radius + half) * (radius + half) - dy * dy, 0.0)) - PRUNE_MARGIN)
	var left: Vector2i = Vector2i(outside.x, outside.x)
	var right: Vector2i = Vector2i(outside.y, outside.y)
	var skip: Vector2i = Vector2i(outside.x, outside.x)
	if solid.y > solid.x:
		left = solid
		right = Vector2i(solid.y, solid.y)
		skip = Vector2i(solid.y, solid.y)
		if near_out > 0.0:
			var near: Vector2i = _solid_columns(outside, center.x, near_out)
			if near.y > near.x:
				left = Vector2i(solid.x, clampi(near.x, solid.x, solid.y))
				right = Vector2i(clampi(near.y, solid.x, solid.y), solid.y)
				skip = Vector2i(clampi(hole.x, left.y, right.x), clampi(hole.y, left.y, right.x))
				skip.y = maxi(skip.x, skip.y)
	elif hole.y > hole.x:
		skip = hole
		right = Vector2i(outside.y, outside.y)
	return PackedInt32Array([outside.x, left.x, left.y, skip.x, skip.y, right.x, right.y, outside.y])


static func _fill_rect(img: _Canvas, r: Rect2, c: Color) -> void:
	var box: Rect2i = _px_bounds(img, r)
	for y: int in range(box.position.y, box.position.y + box.size.y):
		if prune_columns:
			_fill_run(img, y, box.position.x, box.position.x + box.size.x, c)
			continue
		for x: int in range(box.position.x, box.position.x + box.size.x):
			_blend(img, x, y, c)


## A line step's stroke, with the two things the card can now say about it: what its ends look like,
## and whether it is dashed. A step that says neither draws exactly the capsule it always drew.
##
## THE PATTERN IS WALKED IN PIXELS, along the segment, so the thumbnail of a dashed line differs
## from the thumbnail of a plain one at the pixels a reader would look at rather than by a hair.
static func _fill_stroke(img: _Canvas, a: Vector2, b: Vector2, width: float, c: Color, entry: Dictionary, scale: float) -> void:
	var span: float = a.distance_to(b)
	var half: float = maxf(width, 1.0) * 0.5
	# A step that never named its ends is a step from before the card could ask, and the canvas draws
	# it with square-cut ends. The picture has to answer the same way, or a prefab saved last year
	# looks rounder in the thumbnail than it does in the game.
	var ends: String = str(entry.get("caps", "none"))
	if not bool(entry.get("dashed", false)) or span <= 0.001:
		_fill_span(img, a, b, half, c, 0.0, span, ends)
		return
	var dash: float = maxf(float(entry.get("dash_size", 8.0)) * scale, 1.0)
	var gap: float = maxf(float(entry.get("dash_spacing", 6.0)) * scale, 0.0)
	var period: float = dash + gap
	var style: String = str(entry.get("dash_style", "plain"))
	var dash_ends: String = "round" if style == "rounded" else ("angled" if style == "angled" else "none")
	# Whole periods of offset land where they started, so a scrolled pattern never jumps.
	var at: float = -fposmod(float(entry.get("dash_offset", 0.0)) * period, period)
	while at < span:
		_fill_span(img, a, b, half, c, maxf(at, 0.0), minf(at + dash, span), dash_ends)
		at += period


## One run of a stroke between two distances along it, with the end shape named: `none` (cut square
## at the end), `square` (half a width past it), `round` (a half-disc) or `angled` (a 45 degree lean,
## which is what an angled dash is). One pixel loop answers all four - the end shape is the test at
## the two ends rather than a second pass over the same pixels.
static func _fill_span(img: _Canvas, a: Vector2, b: Vector2, half: float, c: Color, from_along: float, to_along: float, ends: String) -> void:
	if to_along <= from_along:
		return
	var direction: Vector2 = (b - a).normalized() if a.distance_to(b) > 0.001 else Vector2.RIGHT
	var normal: Vector2 = Vector2(-direction.y, direction.x)
	var start_point: Vector2 = a + direction * from_along
	var end_point: Vector2 = a + direction * to_along
	var box: Rect2i = _px_bounds(img, Rect2(start_point, end_point - start_point).abs().grow(half + 1.0))
	# A slanted run only touches a diagonal strip of its bounding box. Per row, the columns where the strip (a width of
	# `half` either side of the line) and the run (from a little before the start to a little after the end, the room the
	# end shapes may take) meet are the only ones asked; the rest cannot pass the test, so the pixels are the same. Inside
	# the strip, the middle of the run (clear of its edges and of its ends) is inside whatever the ends look like, and is
	# written in one go.
	var reach: float = half + PRUNE_MARGIN if prune_columns else 1.0e9
	var behind: float = from_along - half - PRUNE_MARGIN if prune_columns else -1.0e9
	var ahead: float = to_along + half + PRUNE_MARGIN if prune_columns else 1.0e9
	var core_reach: float = half - PRUNE_MARGIN
	var core_from: float = from_along + (half + PRUNE_MARGIN if ends == "angled" else PRUNE_MARGIN)
	var core_to: float = to_along - (half + PRUNE_MARGIN if ends == "angled" else PRUNE_MARGIN)
	var has_core: bool = prune_columns and core_reach > 0.0 and core_to > core_from
	for y: int in range(box.position.y, box.position.y + box.size.y):
		var rel_y: float = y + 0.5 - a.y
		var outer: Vector2 = _strip_row(direction, normal, rel_y, reach, behind, ahead)
		if outer.x > outer.y:
			continue
		var columns: Vector2i = Vector2i(maxi(box.position.x, int(floor(a.x + outer.x - 0.5)) - 1), mini(box.position.x + box.size.x, int(floor(a.x + outer.y - 0.5)) + 2))
		var solid: Vector2i = Vector2i(columns.x, columns.x)
		if has_core:
			var inner: Vector2 = _strip_row(direction, normal, rel_y, core_reach, core_from, core_to)
			if inner.x <= inner.y:
				var first: int = maxi(columns.x, int(ceil(a.x + inner.x - 0.5)))
				var last: int = mini(columns.y, int(floor(a.x + inner.y - 0.5)) + 1)
				if last > first:
					solid = Vector2i(first, last)
		for x: int in range(columns.x, solid.x):
			if _in_stroke(Vector2(x + 0.5, y + 0.5) - a, direction, normal, half, from_along, to_along, ends):
				_blend(img, x, y, c)
		_fill_run(img, y, solid.x, solid.y, c)
		for x: int in range(solid.y, columns.y):
			if _in_stroke(Vector2(x + 0.5, y + 0.5) - a, direction, normal, half, from_along, to_along, ends):
				_blend(img, x, y, c)


## The offsets from a line's start, along the x axis at one row `rel_y` below it, of the pixel centres that lie within
## `reach` of the line and between `behind` and `ahead` along it: [first, last], or first past last when there are none.
static func _strip_row(direction: Vector2, normal: Vector2, rel_y: float, reach: float, behind: float, ahead: float) -> Vector2:
	var first_x: float = -1.0e9
	var last_x: float = 1.0e9
	var across_y: float = rel_y * normal.y
	if absf(normal.x) > 0.0001:
		var low_x: float = (-reach - across_y) / normal.x
		var high_x: float = (reach - across_y) / normal.x
		first_x = maxf(first_x, minf(low_x, high_x))
		last_x = minf(last_x, maxf(low_x, high_x))
	elif absf(across_y) > reach:
		return Vector2(1.0, 0.0)
	var along_y: float = rel_y * direction.y
	if absf(direction.x) > 0.0001:
		var start_x: float = (behind - along_y) / direction.x
		var end_x: float = (ahead - along_y) / direction.x
		first_x = maxf(first_x, minf(start_x, end_x))
		last_x = minf(last_x, maxf(start_x, end_x))
	elif along_y < behind or along_y > ahead:
		return Vector2(1.0, 0.0)
	return Vector2(first_x, last_x)


## Whether a pixel centre, `offset` from a line's start, is inside the stroke with the ends named.
static func _in_stroke(offset: Vector2, direction: Vector2, normal: Vector2, half: float, from_along: float, to_along: float, ends: String) -> bool:
	var along: float = offset.dot(direction)
	var perp: float = absf(offset.dot(normal))
	var within: bool = perp <= half and along >= from_along and along <= to_along
	match ends:
		"square":
			within = perp <= half and along >= from_along - half and along <= to_along + half
		"angled":
			var leaned: float = along + offset.dot(normal)
			within = perp <= half and leaned >= from_along and leaned <= to_along
		"round":
			within = within or offset.distance_to(direction * from_along) <= half or offset.distance_to(direction * to_along) <= half
	return within


## A stamp: the texture centred on a point, `zoom` pixels per texel, turned by `spin_deg` and tinted.
## Each pixel in the turned box is mapped back into the texture, so the picture is the texture itself
## rather than a square of its colour.
static func _fill_stamp(img: _Canvas, center: Vector2, texture: Texture2D, zoom: float, spin_deg: float, tint: Color) -> void:
	var source: Image = texture.get_image()
	if source == null or source.is_empty():
		return
	if source.is_compressed():
		source.decompress()
	var texels: Vector2i = source.get_size()
	var size: Vector2 = Vector2(texels) * zoom
	var turn: float = deg_to_rad(spin_deg)
	var cos_turn: float = cos(turn)
	var sin_turn: float = sin(turn)
	var reach: Vector2 = Vector2(
		absf(size.x * cos_turn) + absf(size.y * sin_turn),
		absf(size.x * sin_turn) + absf(size.y * cos_turn)) * 0.5
	var box: Rect2i = _px_bounds(img, Rect2(center - reach, reach * 2.0))
	for y: int in range(box.position.y, box.position.y + box.size.y):
		for x: int in range(box.position.x, box.position.x + box.size.x):
			var offset: Vector2 = Vector2(x + 0.5, y + 0.5) - center
			var local: Vector2 = Vector2(offset.x * cos_turn + offset.y * sin_turn, -offset.x * sin_turn + offset.y * cos_turn)
			var across: float = local.x / size.x + 0.5
			var down: float = local.y / size.y + 0.5
			if across < 0.0 or across >= 1.0 or down < 0.0 or down >= 1.0:
				continue
			var texel: Color = source.get_pixel(int(across * texels.x), int(down * texels.y))
			if texel.a > 0.0:
				_blend(img, x, y, Color(texel.r * tint.r, texel.g * tint.g, texel.b * tint.b, texel.a * tint.a))


static func _fill_cone(img: _Canvas, center: Vector2, radius: float, facing_deg: float, fov_deg: float, c: Color) -> void:
	var r: float = maxf(radius, 1.0)
	var facing: float = deg_to_rad(facing_deg)
	var half_fov: float = deg_to_rad(maxf(fov_deg, 1.0)) * 0.5
	var box: Rect2i = _px_bounds(img, Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0))
	for y: int in range(box.position.y, box.position.y + box.size.y):
		var reach: float = _chord(r, y + 0.5 - center.y)
		if reach < 0.0:
			continue
		var columns: Vector2i = _columns(box, center.x, reach)
		for x: int in range(columns.x, columns.y):
			var d: Vector2 = Vector2(x + 0.5, y + 0.5) - center
			if d.length() <= r and absf(wrapf(d.angle() - facing, -PI, PI)) <= half_fov:
				_blend(img, x, y, c)


## Whether a point (measured from the centre) lies inside the sweep that runs from one angle to another, in degrees. The
## sweep goes from the start to the end - backwards when the end is below the start - and is held to one full turn: the
## rule the pack's own outline uses, so the picture and the game agree.
static func _in_sweep(offset: Vector2, start_deg: float, end_deg: float) -> bool:
	var start: float = deg_to_rad(start_deg)
	var sweep: float = clampf(deg_to_rad(end_deg) - start, -TAU, TAU)
	if absf(sweep) < 0.0005:
		return false
	if absf(sweep) >= TAU - 0.0005:
		return true
	return fposmod(offset.angle() - minf(start, start + sweep), TAU) <= absf(sweep)


## The number of sides a polygon step is drawn with: rounded, and held to 3 at least and 32 at most.
static func _sides_of(sides: float) -> int:
	return clampi(roundi(sides), 3, 32)


## Whether a point (measured from the centre) is inside a regular polygon: its angle puts it in front of one side, and
## that side is the apothem away.
static func _in_polygon(offset: Vector2, radius: float, sides: float, angle_deg: float) -> bool:
	var count: int = _sides_of(sides)
	var around: float = fposmod(offset.angle() - deg_to_rad(angle_deg), TAU / float(count)) - PI / float(count)
	return offset.length() * cos(around) <= radius * cos(PI / float(count))


## How far a point (measured from the centre) is outside a regular polygon: 0 inside it.
static func _polygon_distance(offset: Vector2, radius: float, sides: float, angle_deg: float) -> float:
	if _in_polygon(offset, radius, sides, angle_deg):
		return 0.0
	var count: int = _sides_of(sides)
	var best: float = INF
	for corner: int in count:
		var from: Vector2 = Vector2.from_angle(deg_to_rad(angle_deg) + TAU * float(corner) / float(count)) * radius
		var to: Vector2 = Vector2.from_angle(deg_to_rad(angle_deg) + TAU * float(corner + 1) / float(count)) * radius
		best = minf(best, offset.distance_to(Geometry2D.get_closest_point_to_segment(offset, from, to)))
	return best


## `_in_sweep` worked out once for a whole shape rather than once per pixel: the lowest angle of the sweep and its length in
## radians, and whether the sweep covers nothing (0), part of the turn (1) or all of it (2). The arithmetic is the same,
## so the pixels are.
static func _sweep_plan(start_deg: float, end_deg: float) -> Vector3:
	var start: float = deg_to_rad(start_deg)
	var sweep: float = clampf(deg_to_rad(end_deg) - start, -TAU, TAU)
	if absf(sweep) < 0.0005:
		return Vector3(0.0, 0.0, 0.0)
	if absf(sweep) >= TAU - 0.0005:
		return Vector3(0.0, 0.0, 2.0)
	return Vector3(minf(start, start + sweep), absf(sweep), 1.0)


static func _fill_arc(img: _Canvas, center: Vector2, radius: float, width: float, start_deg: float, end_deg: float, c: Color) -> void:
	if radius <= 0.0:
		return
	var plan: Vector3 = _sweep_plan(start_deg, end_deg)
	if plan.z == 0.0:
		return
	var half: float = maxf(width, 1.0) * 0.5
	var box: Rect2i = _px_bounds(img, Rect2(center - Vector2(radius + half, radius + half), Vector2(radius + half, radius + half) * 2.0))
	for y: int in range(box.position.y, box.position.y + box.size.y):
		var cuts: PackedInt32Array = _band_cuts(box, center, radius, half, y, plan.z == 2.0)
		if cuts.is_empty():
			continue
		for span: int in [0, 2, 4, 6]:
			for x: int in range(cuts[span], cuts[span + 1]):
				var d: Vector2 = Vector2(x + 0.5, y + 0.5) - center
				if absf(d.length() - radius) <= half and (plan.z == 2.0 or fposmod(d.angle() - plan.x, TAU) <= plan.y):
					_blend(img, x, y, c)
			# A full turn is a plain ring: the stretches wholly inside it are written as runs.
			if span == 0:
				_fill_run(img, y, cuts[1], cuts[2], c)
			elif span == 4:
				_fill_run(img, y, cuts[5], cuts[6], c)


static func _fill_pie(img: _Canvas, center: Vector2, radius: float, start_deg: float, end_deg: float, c: Color) -> void:
	if radius <= 0.0:
		return
	var plan: Vector3 = _sweep_plan(start_deg, end_deg)
	if plan.z == 0.0:
		return
	var box: Rect2i = _px_bounds(img, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0))
	for y: int in range(box.position.y, box.position.y + box.size.y):
		var reach: float = _chord(radius, y + 0.5 - center.y)
		if reach < 0.0:
			continue
		var columns: Vector2i = _columns(box, center.x, reach)
		for x: int in range(columns.x, columns.y):
			var d: Vector2 = Vector2(x + 0.5, y + 0.5) - center
			if d.length() <= radius and (plan.z == 2.0 or fposmod(d.angle() - plan.x, TAU) <= plan.y):
				_blend(img, x, y, c)


## A rectangle with round corners: a pixel is in when its distance to the box with the corners cut is not past zero. The
## corner is held to half the shorter side, the rule the pack's outline uses.
static func _fill_rounded_rect(img: _Canvas, r: Rect2, corner: float, c: Color) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var round_by: float = clampf(corner, 0.0, minf(r.size.x, r.size.y) * 0.5)
	var half: Vector2 = r.size * 0.5
	var middle: Vector2 = r.get_center()
	var box: Rect2i = _px_bounds(img, r)
	var columns: Vector2i = Vector2i(box.position.x, box.position.x + box.size.x)
	for y: int in range(box.position.y, box.position.y + box.size.y):
		# Rows clear of the corners are filled right across, and rows beside them all but their corners: those are inside
		# whatever the corner, so only the pixels near a corner are asked.
		var down: float = absf(y + 0.5 - middle.y)
		var solid_half: float = 0.0
		if down <= half.y - round_by - PRUNE_MARGIN:
			solid_half = half.x - PRUNE_MARGIN
		elif down <= half.y - PRUNE_MARGIN:
			solid_half = half.x - round_by - PRUNE_MARGIN
		var solid: Vector2i = _solid_columns(columns, middle.x, solid_half)
		for x: int in range(columns.x, solid.x):
			if _in_rounded(Vector2(x + 0.5, y + 0.5), middle, half, round_by):
				_blend(img, x, y, c)
		_fill_run(img, y, solid.x, solid.y, c)
		for x: int in range(solid.y, columns.y):
			if _in_rounded(Vector2(x + 0.5, y + 0.5), middle, half, round_by):
				_blend(img, x, y, c)


## Whether a point is inside a rectangle with round corners (the box with its corners cut, by the signed distance to it).
static func _in_rounded(point: Vector2, middle: Vector2, half: Vector2, round_by: float) -> bool:
	var q: Vector2 = (point - middle).abs() - (half - Vector2(round_by, round_by))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - round_by <= 0.0


static func _fill_polygon(img: _Canvas, center: Vector2, radius: float, sides: float, angle_deg: float, c: Color) -> void:
	if radius <= 0.0:
		return
	# The pixels nearer the middle than the polygon's flat sides are inside it whichever way it faces.
	var count: int = _sides_of(sides)
	var apothem: float = radius * cos(PI / float(count))
	# What `_in_polygon` works out from the shape alone, once for every pixel of it rather than once for each.
	var turn: float = deg_to_rad(angle_deg)
	var wedge: float = TAU / float(count)
	var half_wedge: float = PI / float(count)
	var limit: float = radius * cos(PI / float(count))
	var box: Rect2i = _px_bounds(img, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0))
	for y: int in range(box.position.y, box.position.y + box.size.y):
		# A regular polygon lies inside the circle through its corners, which is the circle of its radius.
		var dy: float = y + 0.5 - center.y
		var reach: float = _chord(radius, dy)
		if reach < 0.0:
			continue
		var columns: Vector2i = _columns(box, center.x, reach)
		var solid: Vector2i = _solid_columns(columns, center.x, sqrt(maxf(apothem * apothem - dy * dy, 0.0)) - PRUNE_MARGIN)
		for x: int in range(columns.x, solid.x):
			var d: Vector2 = Vector2(x + 0.5, y + 0.5) - center
			if d.length() * cos(fposmod(d.angle() - turn, wedge) - half_wedge) <= limit:
				_blend(img, x, y, c)
		_fill_run(img, y, solid.x, solid.y, c)
		for x: int in range(solid.y, columns.y):
			var d: Vector2 = Vector2(x + 0.5, y + 0.5) - center
			if d.length() * cos(fposmod(d.angle() - turn, wedge) - half_wedge) <= limit:
				_blend(img, x, y, c)
