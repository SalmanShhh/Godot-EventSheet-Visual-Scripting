@tool
class_name EventSheetActiveTheme
extends RefCounted

## The one place editor chrome OUTSIDE the sheet canvas asks "what is the sheet painted with?".
##
## The renderer and the row builder reach the active EventSheetEditorStyle through the viewport, so
## they never needed this. The bars around the canvas cannot: the Object bar is a Tree in a panel, the
## status strip is a Label on the dock, the Manual is a separate dock with no reference to any sheet.
## Passing a style down every one of those constructors would mean a seam per panel and a rebuild per
## theme switch; instead the dock PUBLISHES the active style here whenever it changes, and a panel
## READS the tokens it needs at the moment it paints.
##
## Publishing is one-way and cheap. Nothing here loads a sheet, watches a signal, or keeps a node
## alive: it is a static handle on a resource the dock already owns. With nothing published (headless
## tests, a game build that shipped the addons folder) the getters hand back the bundled default
## style, so every caller can paint unconditionally and no call site needs a null branch.

static var _active: EventSheetEditorStyle = null
static var _fallback: EventSheetEditorStyle = null


## Called by the dock whenever the active sheet's theme changes (tab switch, preset pick, Theme
## Editor apply, a `.tres` edited on disk). Passing null goes back to the bundled default.
static func publish(style: EventSheetEditorStyle) -> void:
	_active = style


## The style the chrome should paint from - the published one, or the bundled default.
static func active() -> EventSheetEditorStyle:
	if _active != null:
		return _active
	if _fallback == null:
		_fallback = EventSheetEditorStyle.new()
	return _fallback


## The marks inside a sheet (chips, badges, tempo, guides, stripes, the refusal bubble).
static func reading() -> EventSheetReadingStyle:
	return active().get_reading_style()


## The bars around the sheet (Object bar, status strip, tab title).
static func chrome() -> EventSheetChromeStyle:
	return active().get_chrome_style()


## The docked Manual's pages.
static func manual() -> EventSheetManualStyle:
	return active().get_manual_style()
