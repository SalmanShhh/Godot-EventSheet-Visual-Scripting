# EventSheet - a wavy underline under the exact characters a finding is about
# A text field cannot colour part of its text, so the underline is drawn by a transparent overlay that
# sits over the field and asks the field where each character is. It owns no state of the field's: the
# spans are set by whoever checked the text and cleared the moment the text changes, so a stale
# underline never points at characters that moved.
@tool
class_name EventSheetSpanUnderline
extends Control

## The meta a field carries its overlay under.
const META_KEY: String = "span_underline"
## How tall one wave is, and how far apart its peaks sit, in unscaled pixels.
const WAVE_HEIGHT: float = 2.0
const WAVE_STEP: float = 3.0

var field: TextEdit = null
var spans: Array[Vector2i] = []
var colour: Color = Color(0.93, 0.44, 0.44)


## The overlay of `field`, made on first use.
static func of(target: TextEdit) -> EventSheetSpanUnderline:
	if target.has_meta(META_KEY):
		var existing: Variant = target.get_meta(META_KEY)
		if is_instance_valid(existing):
			return existing as EventSheetSpanUnderline
	var overlay: EventSheetSpanUnderline = EventSheetSpanUnderline.new()
	overlay.field = target
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	target.add_child(overlay)
	target.set_meta(META_KEY, overlay)
	target.resized.connect(overlay.queue_redraw)
	return overlay


## Underlines `new_spans` (character ranges of the field's first line, [start, end)) in `new_colour`.
func underline(new_spans: Array[Vector2i], new_colour: Color) -> void:
	spans = new_spans
	colour = new_colour
	queue_redraw()


func clear() -> void:
	if spans.is_empty():
		return
	spans = []
	queue_redraw()


func _draw() -> void:
	if field == null or not is_instance_valid(field):
		return
	for span: Vector2i in spans:
		if span.y <= span.x or span.x < 0 or span.y > field.get_line(0).length():
			continue
		var from_rect: Rect2i = field.get_rect_at_line_column(0, span.x)
		var to_rect: Rect2i = field.get_rect_at_line_column(0, span.y - 1)
		if from_rect.position.x < 0 or to_rect.position.x < 0:
			continue  # scrolled out of view
		var baseline: float = float(from_rect.position.y + from_rect.size.y) - 1.0
		var start_x: float = float(from_rect.position.x)
		var end_x: float = float(to_rect.position.x + to_rect.size.x)
		if to_rect.position.y != from_rect.position.y:
			end_x = size.x - 4.0  # wrapped onto a second row: underline to the edge of the first
		_wave(start_x, end_x, baseline)


func _wave(start_x: float, end_x: float, baseline: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var x: float = start_x
	var up: bool = false
	while x < end_x:
		points.append(Vector2(x, baseline - (WAVE_HEIGHT if up else 0.0)))
		x += WAVE_STEP
		up = not up
	points.append(Vector2(end_x, baseline))
	if points.size() >= 2:
		draw_polyline(points, colour, 1.0, true)
