@tool
class_name ViewportEmptyStateHelper
extends RefCounted
# The getting-started empty state drawn over a sheet with no authored rows: one heading, one
# primary call to action, one de-emphasized tip. Extracted from event_sheet_viewport.gd to keep
# that file maintainable.
#
# draw_empty_state is invoked only from the viewport's _draw, so its three draw_string calls are
# proxied through _viewport (the owning CanvasItem) — CanvasItem.draw_* only works inside the
# owning node's _draw. is_sheet_visually_empty is a pure predicate over the viewport's flat rows.

var _viewport: Control = null

func init(viewport: Control) -> void:
	_viewport = viewport

## True when the sheet has no authored rows — either genuinely empty, or holding only the
## trailing "+ Add event…" footer affordance(s). Drives the getting-started empty state so a
## brand-new sheet shows guidance instead of a lone footer row.
func is_sheet_visually_empty() -> bool:
	for entry: Dictionary in _viewport._flat_rows:
		var row_data: EventRowData = entry.get("row")
		if row_data != null and not _viewport._row_is_add_event_footer(row_data):
			return false
	return true

## Calm getting-started state for an empty sheet: one clear heading, one primary call to
## action, and a single de-emphasized tip — instead of a dense run-on of shortcuts that
## reads as clutter the moment a new user opens a sheet. Called from the viewport's _draw, so
## draw_string is proxied through _viewport (the owning CanvasItem).
func draw_empty_state(width: float) -> void:
	var font: Font = _viewport._get_font()
	var font_size: int = _viewport._get_font_size()
	var heading: String = "This event sheet is empty"
	var primary: String = "Double-click anywhere — or press E — to add your first event."
	var tip: String = "Tip: the picker understands plain language. Try typing \"every tick\"."
	if _viewport._sheet != null and _viewport._sheet.behavior_mode:
		heading = "Empty behavior sheet"
		primary = "Double-click anywhere — or press E — to add an event that drives the %s this attaches to." % _viewport._sheet.host_class
		# Keep the default plain-language picker tip — behavior sheets benefit from it just as much.
	var left: float = 18.0
	var max_w: float = max(width - 36.0, 1.0)
	var heading_size: int = EventSheetPalette.resolve_font_size(font_size, 0, 2)
	var line_gap: float = 8.0
	var y: float = 36.0 + float(heading_size)
	_viewport.draw_string(font, Vector2(left, y), heading, HORIZONTAL_ALIGNMENT_LEFT, max_w, heading_size, EventSheetPalette.TEXT_PRIMARY)
	y += float(font_size) + line_gap + 6.0
	_viewport.draw_string(font, Vector2(left, y), primary, HORIZONTAL_ALIGNMENT_LEFT, max_w, font_size, EventSheetPalette.TEXT_SECONDARY)
	y += float(font_size) + line_gap
	_viewport.draw_string(font, Vector2(left, y), tip, HORIZONTAL_ALIGNMENT_LEFT, max_w, EventSheetPalette.resolve_font_size(font_size, -1), EventSheetPalette.TEXT_MUTED)
