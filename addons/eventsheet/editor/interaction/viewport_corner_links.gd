@tool
class_name ViewportCornerLinks
extends RefCounted
# THE TWO CORNER LINKS - adding, back where the adding happens.
#
# The editor's top strip used to front four Add buttons. They are still there, one chevron away, but
# the strip is not where a reader looks when they want another event: they look at the sheet. So the
# canvas carries the two doors itself, in its own corners, as muted text links - "Add event" at the
# top left, "+ Add…" at the top right - exactly the grammar this editor's sheet is modelled on.
#
# They are DOORS ONTO WHAT ALREADY EXISTS, never a second way to add anything: "Add event" runs the
# dock's own add-event path (the E key's, the Ghost Row's, the trailing row's), and "+ Add…" opens
# the very PopupMenu a right-click on empty space opens. The viewport only names which link was
# used; the dock owns both actions.
#
# They are PINNED TO THE VISIBLE CORNERS rather than to the content, so scrolling a long sheet never
# takes them away. That is the same trick the pinned parent strip uses: draw at the scroll offset,
# in the canvas's own logical space. The drawn rects are remembered (logical space, the space
# _to_logical_position produces) so a click on one activates it - the same rect-and-draw pattern the
# getting-started call-to-action buttons use, generalised to a corner.
#
# Everything else about adding is untouched. The Ghost Row, the trailing "+ Add event…" rows,
# double-clicking empty space, the right-click menus and the Quick add field are all still there and
# all still primary; these two links stop the toolbar being the only place a beginner can see one.

## The links, in draw order, as [id, label, corner, what it does, the action id whose key it shows].
## The action id is looked up in EventSheetShortcuts, so a rebound key shows its NEW binding on
## hover; a link that stands for a menu rather than a gesture carries no action and simply says what
## it does.
const LINKS: Array = [
	["add_event", "Add event", "left", "Add an event to this sheet.", "add_event"],
	["add_menu", "+ Add…", "right", "Everything you can add here - the same menu right-clicking empty space opens.", ""],
]

## How far in from the visible corner the words sit, in logical canvas pixels.
const MARGIN_X: float = 12.0
const MARGIN_Y: float = 6.0

var _viewport: Control = null

## link id -> Rect2 in logical canvas space, refreshed on every draw. Cleared first, so a frame that
## draws nothing (an illustration) can never leave a rect behind that eats a click.
var _link_rects: Dictionary = {}


func init(viewport: Control) -> void:
	_viewport = viewport


## The hover words for a link: what it does, then the key that does the same thing. Same shape the
## beginner toolbar's tooltips use, for the same reason - a hand-typed key name goes stale the first
## time somebody rebinds it.
static func tooltip_for(link_id: String) -> String:
	for entry: Variant in LINKS:
		var record: Array = entry
		if str(record[0]) != link_id:
			continue
		var what: String = EventSheetL10n.translate(str(record[3]))
		var action: String = str(record[4])
		if action.is_empty():
			return what
		var binding: String = EventSheetShortcuts.binding_for(action)
		return what if binding.is_empty() else "%s  (%s)" % [what, binding]
	return ""


## WHERE THE LINKS LAND, as {link id: Rect2} in logical canvas space. A pure function of four
## numbers and the measured width of each label, so the suite can pin both corners - and pin them
## again after a resize - without a tree, a font or a rendering server. `left`/`right` are the
## visible window's own edges (not the canvas's), which is what pins the links to the corners a
## reader can see rather than to a canvas that may be wider than the window.
static func layout(widths: Dictionary, left: float, right: float, top: float, link_size: int) -> Dictionary:
	var height: float = float(link_size) + 8.0
	var rects: Dictionary = {}
	for entry: Variant in LINKS:
		var record: Array = entry
		var link_id: String = str(record[0])
		var text_width: float = float(widths.get(link_id, 0.0))
		var x: float = (left + MARGIN_X) if str(record[2]) == "left" else (right - MARGIN_X - text_width)
		rects[link_id] = Rect2(x, top + MARGIN_Y, text_width, height)
	return rects


## The id of the link under `position` in a set of laid-out rects, or "" when the point is on
## neither. Static, so the same answer can be pinned off `layout` alone.
static func link_at_in(rects: Dictionary, position: Vector2) -> String:
	for link_id: String in rects:
		if (rects[link_id] as Rect2).has_point(position):
			return link_id
	return ""


## Draws both links pinned to the visible top corners and arms their click zones. Called from the
## viewport's _draw, so every draw_* goes through _viewport (CanvasItem.draw_* only works inside the
## owning node's _draw). `top_offset` is what the top edge already owes something else - the pinned
## parent strip owns it while it is showing, and the links sit under it rather than through it.
##
## An illustration draws nothing: a figure is a picture of a sheet, and a picture with live click
## zones in it is not a picture. Same rule the getting-started buttons follow.
func draw(font: Font, font_size: int, top_offset: float) -> void:
	_link_rects.clear()
	if _viewport.figure_mode or font == null:
		return
	var zoom: float = maxf(_viewport._zoom_factor, 0.001)
	var left: float = float(_viewport.get_horizontal_scroll()) / zoom
	var right: float = left + _viewport.get_visible_width() / zoom
	var top: float = float(_viewport.get_scroll_offset()) / zoom + top_offset
	var link_size: int = EventSheetPalette.resolve_font_size(font_size, -1)
	var labels: Dictionary = {}
	var widths: Dictionary = {}
	for entry: Variant in LINKS:
		var record: Array = entry
		# Canvas-drawn text sits outside the auto-translated Control tree, so this choke point
		# translates explicitly (a no-op pass-through in the default English).
		var label: String = EventSheetL10n.translate(str(record[1]))
		labels[str(record[0])] = label
		widths[str(record[0])] = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, link_size).x
	_link_rects = layout(widths, left, right, top, link_size)
	var color: Color = EventSheetPalette.TEXT_MUTED
	for link_id: String in _link_rects:
		var rect: Rect2 = _link_rects[link_id]
		_viewport.draw_string(font,
			Vector2(rect.position.x, rect.position.y + rect.size.y * 0.5 + float(link_size) * 0.36),
			str(labels[link_id]), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, link_size, color)
		# The hairline under the words: the same cue a clickable noun in a comment wears, so a link
		# reads as a door rather than as a caption somebody left in the corner.
		_viewport.draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y - 1.0, rect.size.x, 1.0),
			Color(color.r, color.g, color.b, color.a * 0.5), true)


## The id of the link under `position` (logical canvas space), or "" when the point is on neither.
func link_at(position: Vector2) -> String:
	return link_at_in(_link_rects, position)


## The id of the link under `control_position` (the control's own, zoomed coordinates), or "". The
## click path hands positions over in control space, exactly as the pinned parent strip's does.
func link_at_control_position(control_position: Vector2) -> String:
	var zoom: float = maxf(_viewport._zoom_factor, 0.001)
	return link_at(control_position / zoom)


## The drawn rect of one link in logical canvas space, or an empty Rect2 when it is not on screen.
func rect_of(link_id: String) -> Rect2:
	return _link_rects.get(link_id, Rect2())
