@tool
class_name ViewportEmptyStateHelper
extends RefCounted
# The getting-started empty state drawn over a sheet with no authored rows: a centered heading,
# one or two real CLICKABLE call-to-action buttons, and a de-emphasized tip. Extracted from
# event_sheet_viewport.gd to keep that file maintainable.
#
# draw_empty_state is invoked only from the viewport's _draw, so all draw_* calls are proxied
# through _viewport (the owning CanvasItem) - CanvasItem.draw_* only works inside the owning
# node's _draw. The button rects drawn here are remembered (logical space, the same space
# viewport_input's _to_logical_position produces) so a single click on one activates it:
# cta_action_at(position) is consulted by the input path before box selection starts.

var _viewport: Control = null

# action id -> Rect2 in logical canvas space, refreshed on every draw and cleared when the
# empty state is not showing (so stale rects can never eat clicks on a populated sheet).
var _cta_rects: Dictionary = {}


func init(viewport: Control) -> void:
	_viewport = viewport


## True when the sheet has no authored rows - either genuinely empty, or holding only the
## trailing "+ Add event…" footer affordance(s). Drives the getting-started empty state so a
## brand-new sheet shows guidance instead of a lone footer row.
func is_sheet_visually_empty() -> bool:
	for entry: Dictionary in _viewport._flat_rows:
		var row_data: EventRowData = entry.get("row")
		if row_data != null and not _viewport._row_is_add_event_footer(row_data):
			return false
	return true


## The call-to-action buttons for the current state, as {action, label} in draw order. Pure
## function of the sheet so tests can pin both states without a viewport:
## - no sheet loaded: one button that opens the starter-template menu (there is nowhere to put
##   an event yet, so "add your first event" would be a lie).
## - empty sheet: the primary add-first-event button plus a starter-template shortcut.
static func cta_specs(sheet: EventSheetResource) -> Array[Dictionary]:
	if sheet == null:
		return [
			{"action": "template_menu", "label": "Create an event sheet…"},
		]
	return [
		{"action": "add_event", "label": "+  Add your first event"},
		{"action": "template_menu", "label": "New from template…"},
	]


## The action id ("add_event" / "template_menu") of the CTA button under `position` (logical
## canvas space), or "" when the click is not on a button. Rects are refreshed each draw and
## cleared when the empty state stops showing, so this is always in sync with what's on screen.
func cta_action_at(position: Vector2) -> String:
	for action: String in _cta_rects:
		if (_cta_rects[action] as Rect2).has_point(position):
			return action
	return ""


## Called by the viewport's _draw when the sheet is NOT visually empty, so clicks on rows can
## never hit a leftover button rect from a previous empty frame.
func clear_cta_rects() -> void:
	_cta_rects.clear()


## Calm getting-started state for an empty sheet, centered like a proper landing view: one clear
## heading, one primary sentence, real clickable buttons, and a single de-emphasized tip -
## instead of a dense top-left run-on of shortcuts that reads as clutter (and that a new user
## couldn't click anyway). Called from the viewport's _draw, so drawing is proxied through
## _viewport (the owning CanvasItem).
func draw_empty_state(width: float) -> void:
	_cta_rects.clear()
	var font: Font = _viewport._get_font()
	var font_size: int = _viewport._get_font_size()
	# Intent-aware advice (behaviour / autoload / editor tool / custom resource / no sheet), so a
	# brand-new sheet steers its author toward that script type's full potential. One extendable
	# table owns the text: EventSheetScriptIntent.empty_sheet_advice.
	var advice: Dictionary = EventSheetScriptIntent.empty_sheet_advice(_viewport._sheet)
	# Canvas-drawn text sits outside the auto-translated Control tree, so this choke point
	# translates explicitly (a no-op pass-through in the default English).
	var heading: String = EventSheetL10n.translate(str(advice.get("heading", "")))
	var primary: String = EventSheetL10n.translate(str(advice.get("primary", "")))
	var tip: String = EventSheetL10n.translate(str(advice.get("tip", "")))
	var center_x: float = width * 0.5
	var max_w: float = max(width - 36.0, 1.0)
	var heading_size: int = EventSheetPalette.resolve_font_size(font_size, 0, 2)
	var tip_size: int = EventSheetPalette.resolve_font_size(font_size, -1)
	var y: float = 52.0 + float(heading_size)
	_draw_centered_line(font, heading, heading_size, center_x, y, max_w, EventSheetPalette.TEXT_PRIMARY)
	y += float(font_size) + 16.0
	_draw_centered_line(font, primary, font_size, center_x, y, max_w, EventSheetPalette.TEXT_SECONDARY)
	y += float(font_size) + 18.0
	y = _draw_cta_buttons(font, font_size, center_x, y)
	y += float(tip_size) + 22.0
	_draw_centered_line(font, tip, tip_size, center_x, y, max_w, EventSheetPalette.TEXT_MUTED)


func _draw_centered_line(font: Font, text: String, size: int, center_x: float, baseline_y: float, max_w: float, color: Color) -> void:
	if text.is_empty():
		return
	var text_w: float = minf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x, max_w)
	_viewport.draw_string(font, Vector2(center_x - text_w * 0.5, baseline_y), text, HORIZONTAL_ALIGNMENT_LEFT, max_w, size, color)


## Draws the CTA buttons side by side, centered as a group, and records each button's rect for
## click hit-testing. The first button is the primary (accented) one. Returns the y just below
## the button row so the tip can flow under it.
func _draw_cta_buttons(font: Font, font_size: int, center_x: float, top_y: float) -> float:
	var specs: Array[Dictionary] = cta_specs(_viewport._sheet)
	var pad_x: float = 18.0
	var gap: float = 12.0
	var height: float = float(font_size) + 18.0
	var widths: Array[float] = []
	var total_w: float = 0.0
	for spec: Dictionary in specs:
		var w: float = font.get_string_size(EventSheetL10n.translate(str(spec["label"])), HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x + pad_x * 2.0
		widths.append(w)
		total_w += w
	total_w += gap * float(maxi(specs.size() - 1, 0))
	var x: float = center_x - total_w * 0.5
	var accent: Color = EventSheetPalette.COLOR_ACTION
	for spec_index: int in range(specs.size()):
		var spec: Dictionary = specs[spec_index]
		var rect: Rect2 = Rect2(x, top_y, widths[spec_index], height)
		var primary_button: bool = spec_index == 0
		var pill: StyleBoxFlat = StyleBoxFlat.new()
		pill.set_corner_radius_all(6)
		pill.set_border_width_all(1)
		if primary_button:
			pill.bg_color = Color(accent.r, accent.g, accent.b, 0.20)
			pill.border_color = Color(accent.r, accent.g, accent.b, 0.65)
		else:
			pill.bg_color = Color(1.0, 1.0, 1.0, 0.05)
			pill.border_color = Color(1.0, 1.0, 1.0, 0.22)
		_viewport.draw_style_box(pill, rect)
		var label: String = EventSheetL10n.translate(str(spec["label"]))
		var label_w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		var label_color: Color = EventSheetPalette.TEXT_PRIMARY if primary_button else EventSheetPalette.TEXT_SECONDARY
		var baseline: float = rect.position.y + rect.size.y * 0.5 + float(font_size) * 0.36
		_viewport.draw_string(font, Vector2(rect.position.x + (rect.size.x - label_w) * 0.5, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, font_size, label_color)
		_cta_rects[str(spec["action"])] = rect
		x += widths[spec_index] + gap
	return top_y + height
