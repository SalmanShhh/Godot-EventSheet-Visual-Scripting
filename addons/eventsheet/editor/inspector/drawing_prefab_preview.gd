# Godot EventSheets - DrawingPrefabResource preview renderer (editor-only).
#
# Rasterizes a DrawingPrefabResource's ordered `steps` into an Image so you can SEE the composed drawing
# before you use it. One software rasterizer (no scene tree, no CanvasItem) feeds both preview surfaces:
#   - the Inspector panel (EventSheetDrawingPrefabInspector), and
#   - the FileSystem / resource-picker thumbnail (EventSheetDrawingPrefabPreviewGenerator).
# Software (not draw_* / SubViewport) so it is thread-safe - Godot generates resource thumbnails off the
# main thread, where touching the tree would crash. Geometry mirrors DrawingCanvas.draw_prefab so the
# preview matches what the pack actually paints (rotation is fixed at 0 - a preview shows the base pose).
@tool
class_name EventSheetDrawingPrefabPreview
extends RefCounted

const _SUPERSAMPLE: int = 2  # render at 2x then shrink for cheap anti-aliasing
const _STAMP_BASE: float = 12.0  # nominal stamp side (px, prefab-local) before its scale multiplier


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
			var w: float = maxf(absf(p3), 1.0)
			return Rect2(at, Vector2(p1, p2)).abs().grow(w * 0.5)
		"cone":
			var cr: float = maxf(absf(p3), 1.0)
			return Rect2(at.x - cr, at.y - cr, cr * 2.0, cr * 2.0)
		"stamp":
			var s: float = maxf(absf(p1), 0.01) * _STAMP_BASE
			return Rect2(at.x - s * 0.5, at.y - s * 0.5, s, s)
	return Rect2(at.x - 2.0, at.y - 2.0, 4.0, 4.0)


## Renders the steps into an Image of `size`, letterboxed on `bg`. Deterministic and tree-free.
static func rasterize(steps: Array, size: Vector2i, bg: Color) -> Image:
	var w: int = maxi(size.x, 8) * _SUPERSAMPLE
	var h: int = maxi(size.y, 8) * _SUPERSAMPLE
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	var bounds: Rect2 = compute_bounds(steps).grow(4.0)
	# Fit the whole prefab into the image with a margin, preserving aspect and centering.
	var span: Vector2 = Vector2(maxf(bounds.size.x, 1.0), maxf(bounds.size.y, 1.0))
	var scale: float = minf(float(w) / span.x, float(h) / span.y) * 0.86
	var center_local: Vector2 = bounds.get_center()
	var center_px: Vector2 = Vector2(w, h) * 0.5
	for step: Variant in steps:
		if step is Dictionary:
			_rasterize_step(img, step as Dictionary, scale, center_local, center_px)
	if _SUPERSAMPLE > 1:
		img.resize(maxi(size.x, 8), maxi(size.y, 8), Image.INTERPOLATE_LANCZOS)
	return img


## Convenience: a ready-to-show texture (used by the Inspector panel).
static func rasterize_texture(steps: Array, size: Vector2i, bg: Color) -> ImageTexture:
	return ImageTexture.create_from_image(rasterize(steps, size, bg))


static func _to_px(local: Vector2, scale: float, center_local: Vector2, center_px: Vector2) -> Vector2:
	return (local - center_local) * scale + center_px


static func _rasterize_step(img: Image, entry: Dictionary, scale: float, center_local: Vector2, center_px: Vector2) -> void:
	var at_local: Vector2 = Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))
	var at: Vector2 = _to_px(at_local, scale, center_local, center_px)
	var p1: float = float(entry.get("p1", 0.0))
	var p2: float = float(entry.get("p2", 0.0))
	var p3: float = float(entry.get("p3", 0.0))
	var tint: Color = Color.from_string(str(entry.get("color", "white")), Color.WHITE)
	match str(entry.get("kind", "")):
		"circle":
			_fill_disc(img, at, maxf(p1, 0.5) * scale, tint)
		"ring":
			_fill_ring(img, at, maxf(p1, 0.5) * scale, maxf(p2 * scale, float(_SUPERSAMPLE)), tint)
		"rect":
			var corner: Vector2 = _to_px(at_local + Vector2(p1, p2), scale, center_local, center_px)
			_fill_rect(img, Rect2(at, corner - at).abs(), tint)
		"line":
			var to_px: Vector2 = _to_px(at_local + Vector2(p1, p2), scale, center_local, center_px)
			_fill_stroke(img, at, to_px, maxf(p3 * scale, float(_SUPERSAMPLE)), tint, entry, scale)
		"cone":
			_fill_cone(img, at, maxf(p3, 0.5) * scale, p1, p2, tint)
		"stamp":
			var half: float = maxf(p1, 0.01) * _STAMP_BASE * scale * 0.5
			_fill_rect(img, Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0), tint)


# ── Software fills (each iterates only its own pixel bounding box, so cost tracks shape area, not image size) ──
static func _px_bounds(img: Image, r: Rect2) -> Rect2i:
	var clip: Rect2i = Rect2i(0, 0, img.get_width(), img.get_height())
	return Rect2i(int(floor(r.position.x)), int(floor(r.position.y)), int(ceil(r.size.x)) + 1, int(ceil(r.size.y)) + 1).intersection(clip)


static func _blend(img: Image, x: int, y: int, c: Color) -> void:
	if c.a >= 0.999:
		img.set_pixel(x, y, c)
	else:
		img.set_pixel(x, y, img.get_pixel(x, y).lerp(c, c.a))


static func _fill_disc(img: Image, center: Vector2, radius: float, c: Color) -> void:
	var r: float = maxf(radius, 1.0)
	var box: Rect2i = _px_bounds(img, Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0))
	for y: int in range(box.position.y, box.position.y + box.size.y):
		for x: int in range(box.position.x, box.position.x + box.size.x):
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= r:
				_blend(img, x, y, c)


static func _fill_ring(img: Image, center: Vector2, radius: float, width: float, c: Color) -> void:
	var r: float = maxf(radius, 1.0)
	var half: float = maxf(width, 1.0) * 0.5
	var box: Rect2i = _px_bounds(img, Rect2(center - Vector2(r + half, r + half), Vector2(r + half, r + half) * 2.0))
	for y: int in range(box.position.y, box.position.y + box.size.y):
		for x: int in range(box.position.x, box.position.x + box.size.x):
			if absf(Vector2(x + 0.5, y + 0.5).distance_to(center) - r) <= half:
				_blend(img, x, y, c)


static func _fill_rect(img: Image, r: Rect2, c: Color) -> void:
	var box: Rect2i = _px_bounds(img, r)
	for y: int in range(box.position.y, box.position.y + box.size.y):
		for x: int in range(box.position.x, box.position.x + box.size.x):
			_blend(img, x, y, c)


## A line step's stroke, with the two things the card can now say about it: what its ends look like,
## and whether it is dashed. A step that says neither draws exactly the capsule it always drew.
##
## THE PATTERN IS WALKED IN PIXELS, along the segment, so the thumbnail of a dashed line differs
## from the thumbnail of a plain one at the pixels a reader would look at rather than by a hair.
static func _fill_stroke(img: Image, a: Vector2, b: Vector2, width: float, c: Color, entry: Dictionary, scale: float) -> void:
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
static func _fill_span(img: Image, a: Vector2, b: Vector2, half: float, c: Color, from_along: float, to_along: float, ends: String) -> void:
	if to_along <= from_along:
		return
	var direction: Vector2 = (b - a).normalized() if a.distance_to(b) > 0.001 else Vector2.RIGHT
	var normal: Vector2 = Vector2(-direction.y, direction.x)
	var start_point: Vector2 = a + direction * from_along
	var end_point: Vector2 = a + direction * to_along
	var box: Rect2i = _px_bounds(img, Rect2(start_point, end_point - start_point).abs().grow(half + 1.0))
	for y: int in range(box.position.y, box.position.y + box.size.y):
		for x: int in range(box.position.x, box.position.x + box.size.x):
			var offset: Vector2 = Vector2(x + 0.5, y + 0.5) - a
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
			if within:
				_blend(img, x, y, c)


static func _fill_cone(img: Image, center: Vector2, radius: float, facing_deg: float, fov_deg: float, c: Color) -> void:
	var r: float = maxf(radius, 1.0)
	var facing: float = deg_to_rad(facing_deg)
	var half_fov: float = deg_to_rad(maxf(fov_deg, 1.0)) * 0.5
	var box: Rect2i = _px_bounds(img, Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0))
	for y: int in range(box.position.y, box.position.y + box.size.y):
		for x: int in range(box.position.x, box.position.x + box.size.x):
			var d: Vector2 = Vector2(x + 0.5, y + 0.5) - center
			if d.length() <= r and absf(wrapf(d.angle() - facing, -PI, PI)) <= half_fov:
				_blend(img, x, y, c)
